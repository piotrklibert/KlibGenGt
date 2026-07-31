import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from klibgen_build.core import BuildPaths, canonical_json, digest_json, load_context, load_layers
from klibgen_build.sources import expected_lock, validate_lock
from klibgen_build.lifecycle import (
    clear_current_snapshot, current_snapshot_id, discard_run, list_snapshots,
    resume_snapshot, select_snapshot, snapshot_run,
)
from klibgen_build.operations import _gui_save_evidence, _run_environment, execute_image_tool, launch_gui
from klibgen_build.artifacts import build_l07, git_worktree_state, set_tree_writable
from klibgen_build.contexts import list_contexts
from klibgen_build.processes import run_command


ROOT = Path(__file__).resolve().parents[2]


class CoreTest(unittest.TestCase):
    def test_plumbum_adapter_captures_output_and_expected_failure(self):
        result = run_command(
            [sys.executable, "-c", "import sys; print('out'); print('err', file=sys.stderr); raise SystemExit(7)"],
            check=False,
        )
        self.assertEqual(result.returncode, 7)
        self.assertEqual(result.stdout, "out\n")
        self.assertEqual(result.stderr, "err\n")

    def test_plumbum_adapter_reports_missing_commands_without_a_traceback(self):
        with self.assertRaisesRegex(ValueError, "command not found"):
            run_command(["klibgen-command-that-does-not-exist"])

    def test_canonical_json_is_stable_and_compact(self):
        self.assertEqual(canonical_json({"b": 2, "a": 1}), '{"a":1,"b":2}')
        self.assertEqual(digest_json({"a": 1}), digest_json({"a": 1}))

    def test_default_context_and_layers_are_valid(self):
        paths = BuildPaths(ROOT, ROOT / ".klibgen-test")
        self.assertEqual(load_context(paths, "default")["contextId"], "default")
        self.assertEqual([item["layerId"] for item in load_layers(paths)], [f"L{i:02d}" for i in range(1, 8)])

    def test_status_json_is_independent_of_current_directory(self):
        environment = os.environ.copy()
        environment["PYTHONPATH"] = str(ROOT)
        result = run_command(
            [sys.executable, "-m", "klibgen_build", "status", "default", "--json"],
            cwd=ROOT / "docs",
            env=environment,
        )
        value = json.loads(result.stdout)
        self.assertEqual(value["contextId"], "default")
        self.assertEqual(len(value["layers"]), 7)

    def test_committed_lock_matches_pins_and_uses_immutable_ids(self):
        paths = BuildPaths(ROOT, ROOT / ".klibgen-test")
        lock = json.loads((ROOT / "build/locks/default.lock.json").read_text())
        validate_lock(lock)
        sqlite = next(item for item in lock["sources"] if item["sourceId"] == "sqlite3")
        self.assertEqual(lock, expected_lock(paths, sqlite["resolved"]["commit"]))

    def test_snapshot_resume_and_discard_preserve_provenance(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            state = Path(temporary)
            paths = BuildPaths(ROOT, state)
            run_id = "source-run"
            run = state / "runs/default" / run_id
            (run / "image").mkdir(parents=True)
            (run / "image/GlamorousToolkit.image").write_bytes(b"image")
            (run / "logs").mkdir()
            bridge = run / "export"
            (bridge / "src/KlibGenGt-Core").mkdir(parents=True)
            (bridge / "src/KlibGenGt-Core/package.st").write_text("Package { #name : #'KlibGenGt-Core' }\n")
            run_command(["git", "init", "--initial-branch=master", bridge])
            run_command(["git", "-C", bridge, "add", "src"])
            run_command(["git", "-C", bridge, "-c", "user.name=Test", "-c", "user.email=test@localhost", "commit", "-m", "base"])
            bridge_commit = run_command(["git", "-C", bridge, "rev-parse", "HEAD"]).stdout.strip()
            metadata = {
                "schemaVersion": 1, "runId": run_id, "contextId": "default", "profile": "cli",
                "parentArtifact": "artifact", "parentBuildKey": "build-key", "projectCommitId": "project-commit",
                "projectChangeId": "project-change", "generatedBridgeCommit": bridge_commit, "state": "stopped",
                "launcher": "launcher",
            }
            (run / "run.json").write_text(json.dumps(metadata))

            snapshot = snapshot_run(paths, run_id)
            self.assertEqual(snapshot["schemaVersion"], 2)
            self.assertEqual(snapshot["parentL06BuildKey"], "build-key")
            resumed = resume_snapshot(paths, snapshot["snapshotId"])
            self.assertEqual(resumed["resumedFromSnapshot"], snapshot["snapshotId"])
            self.assertTrue((Path(resumed["runPath"]) / "image/GlamorousToolkit.image").is_file())
            self.assertTrue(discard_run(paths, resumed["runId"])["discarded"])
            self.assertEqual(discard_run(paths, snapshot["snapshotId"])["recordKind"], "snapshot")

    def test_l07_rejects_gui_and_unimplemented_release_profiles(self):
        paths = BuildPaths(ROOT, ROOT / ".klibgen-test")
        with self.assertRaisesRegex(ValueError, "canonical L06 CLI"):
            build_l07(paths, "gui")
        with self.assertRaisesRegex(ValueError, "not production-ready"):
            build_l07(paths, "release")

    def test_context_listing_includes_committed_defaults(self):
        paths = BuildPaths(ROOT, ROOT / ".klibgen-test")
        identifiers = {item["contextId"] for item in list_contexts(paths)["contexts"]}
        self.assertTrue({"default", "gui", "sqlite-local", "release"}.issubset(identifiers))

    def test_dirty_git_worktree_digest_tracks_content_not_only_paths(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            repository = Path(temporary)
            run_command(["git", "init", "--initial-branch=main", repository])
            source = repository / "source.st"
            source.write_text("first\n")
            run_command(["git", "-C", repository, "add", "source.st"])
            run_command(["git", "-C", repository, "-c", "user.name=Test", "-c", "user.email=test@localhost", "commit", "-m", "base"])
            source.write_text("second\n")
            first = git_worktree_state(repository)["dirtyContentSha256"]
            source.write_text("third\n")
            second = git_worktree_state(repository)["dirtyContentSha256"]
            self.assertNotEqual(first, second)

    def test_read_only_artifact_tree_can_be_made_disposable(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            root = Path(temporary) / "artifact"
            root.mkdir()
            file = root / "manifest.json"
            file.write_text("{}\n")
            set_tree_writable(root, False)
            set_tree_writable(root, True)
            file.unlink()
            root.rmdir()

    def test_gui_preparation_then_uses_the_normal_gui_launcher(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            root = Path(temporary)
            paths = BuildPaths(root, root / ".klibgen")
            run_path = root / "run"
            (run_path / "image").mkdir(parents=True)
            (run_path / "logs").mkdir()
            cli_launcher = root / "runtime/bin/GlamorousToolkit-cli"
            gui_launcher = cli_launcher.with_name("GlamorousToolkit")
            gui_launcher.parent.mkdir(parents=True)
            gui_launcher.touch()
            image = run_path / "image/GlamorousToolkit.image"
            image.touch()
            source_home = root / "source-home"
            source_database = source_home / "Documents/lepiter/default"
            source_database.mkdir(parents=True)
            (source_database / "page.lepiter").write_text("page")
            run = {
                "runId": "gui-run", "runPath": str(run_path),
                "launcher": str(cli_launcher),
            }
            process = MagicMock()
            process.pid = 123
            process.wait.return_value = 0

            with (
                patch("klibgen_build.operations.create_project_run", return_value=run),
                patch("klibgen_build.operations.run_command", return_value=SimpleNamespace(returncode=0, stdout="prepared", stderr="")) as prepare,
                patch("klibgen_build.operations.start_command", return_value=process) as launch,
                patch("klibgen_build.operations.write_run_metadata"),
                patch.dict(os.environ, {"HOME": str(source_home)}),
            ):
                self.assertEqual(launch_gui(paths, "gui"), 0)

            prepare_command = prepare.call_args.args[0]
            self.assertEqual(prepare_command[:2], [str(cli_launcher), str(image)])
            self.assertNotIn("--interactive", prepare_command)
            self.assertEqual(
                (run_path / "home/Documents/lepiter/default/page.lepiter").read_text(),
                "page",
            )
            launch.assert_called_once_with(
                [str(gui_launcher), "--image", str(image)],
                env=prepare.call_args.kwargs["env"],
            )

    def test_gui_current_snapshot_resumes_without_build_or_preparation(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            root = Path(temporary)
            paths = BuildPaths(root, root / ".klibgen")
            snapshot = paths.state / "snapshots/gui/saved"
            snapshot.mkdir(parents=True)
            (snapshot / "snapshot.json").write_text(json.dumps({"snapshotId": "saved", "contextId": "gui"}))
            pointer = paths.state / "state/gui/gui.json"
            pointer.parent.mkdir(parents=True)
            pointer.write_text(json.dumps({"snapshotId": "saved", "contextId": "gui"}))
            run_path = paths.state / "runs/gui/resumed"
            (run_path / "image").mkdir(parents=True)
            (run_path / "logs").mkdir()
            image = run_path / "image/GlamorousToolkit.image"
            image.write_bytes(b"saved")
            gui_launcher = root / "runtime/GlamorousToolkit"
            gui_launcher.parent.mkdir(parents=True)
            gui_launcher.touch()
            run = {
                "runId": "resumed", "runPath": str(run_path),
                "launcher": str(gui_launcher.with_name("GlamorousToolkit-cli")),
                "sourceDivergence": {"diverged": False},
            }
            process = MagicMock()
            process.pid = 123
            process.wait.return_value = 0
            with (
                patch("klibgen_build.operations.create_project_run") as create,
                patch("klibgen_build.operations.resume_snapshot", return_value=run) as resume,
                patch("klibgen_build.operations.run_command") as prepare,
                patch("klibgen_build.operations.start_command", return_value=process),
                patch("klibgen_build.operations.write_run_metadata"),
            ):
                self.assertEqual(launch_gui(paths, "gui"), 0)
            create.assert_not_called()
            prepare.assert_not_called()
            resume.assert_called_once_with(paths, "saved")

    def test_gui_startup_quits_when_the_world_closes(self):
        startup = (ROOT / "build/layers/l06-project-dev/scripts/bind-run.st").read_text()
        self.assertIn("world removeShutdownListener; addShutdownListener.", startup)
        self.assertIn("mode = ''resumed''", startup)
        self.assertIn("staleWorld ~~ world ifTrue: [ staleWorld close ]", startup)
        self.assertIn("ifFalse: [ GtWorld defaultWorld ifNil: [ GtWorld openDefault ] ]", startup)

    def test_gui_environment_is_allowlisted_and_records_private_paths(self):
        run = {"runId": "run", "runPath": "/managed/run"}
        with patch.dict(os.environ, {"DISPLAY": ":9", "XAUTHORITY": "/run/auth", "SECRET_TOKEN": "secret", "HTTPS_PROXY": "credential"}, clear=True):
            environment = _run_environment(run, "resumed")
        self.assertEqual(environment["DISPLAY"], ":9")
        self.assertEqual(environment["XAUTHORITY"], "/run/auth")
        self.assertNotIn("SECRET_TOKEN", environment)
        self.assertEqual(environment["HOME"], "/managed/run/home")
        self.assertEqual(environment["XDG_DATA_HOME"], "/managed/run/data")
        self.assertEqual(environment["TMPDIR"], "/managed/run/tmp")
        self.assertEqual(environment["KLIBGEN_GUI_START_MODE"], "resumed")

    def test_save_evidence_requires_a_record_and_changed_image(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            run = Path(temporary)
            (run / "image").mkdir()
            (run / "logs").mkdir()
            image = run / "image/GlamorousToolkit.image"
            changes = run / "image/GlamorousToolkit.changes"
            image.write_bytes(b"before")
            changes.write_bytes(b"old")
            before_hash = __import__("hashlib").sha256(b"before").hexdigest()
            offset = changes.stat().st_size
            image.write_bytes(b"after")
            changes.write_bytes(b"old\n----SNAPSHOT----\n----QUIT/NOSAVE----\n")
            evidence = _gui_save_evidence(run, before_hash, offset)
            self.assertTrue(evidence["successfulSave"])
            self.assertEqual(evidence["snapshotRecordCount"], 1)
            self.assertEqual(evidence["quitWithoutSaveRecordCount"], 1)

    def test_save_and_quit_record_is_successful_save_evidence(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            run = Path(temporary)
            (run / "image").mkdir()
            (run / "logs").mkdir()
            image = run / "image/GlamorousToolkit.image"
            changes = run / "image/GlamorousToolkit.changes"
            image.write_bytes(b"before")
            changes.write_bytes(b"old")
            before_hash = __import__("hashlib").sha256(b"before").hexdigest()
            offset = changes.stat().st_size
            image.write_bytes(b"after")
            changes.write_bytes(b"old\n----QUIT----\n")
            evidence = _gui_save_evidence(run, before_hash, offset)
            self.assertTrue(evidence["successfulSave"])
            self.assertEqual(evidence["quitRecordCount"], 1)

    def test_snapshot_captures_private_state_selects_atomically_and_cleans_run(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            state = Path(temporary)
            paths = BuildPaths(ROOT, state)
            run = state / "runs/gui/saved-run"
            for name in ("image", "export", "home", "config", "data", "cache", "logs", "tmp"):
                (run / name).mkdir(parents=True)
            (run / "image/GlamorousToolkit.image").write_bytes(b"saved")
            (run / "home/page.lepiter").write_text("page")
            (run / "config/settings").write_text("settings")
            (run / "data/index").write_text("index")
            (run / "cache/disposable").write_text("cache")
            (run / "tmp/disposable").write_text("tmp")
            metadata = {
                "schemaVersion": 2, "runId": "saved-run", "contextId": "gui", "profile": "gui",
                "parentArtifact": "l06", "parentBuildKey": "l06-key", "runtimeArtifact": "l01",
                "runtimeBuildKey": "l01-key", "projectCommitId": "commit", "projectChangeId": "change",
                "generatedBridgeCommit": "bridge", "state": "stopped", "launcher": "launcher",
            }
            (run / "run.json").write_text(json.dumps(metadata))
            result = snapshot_run(paths, "saved-run", make_current=True, remove_source=True)
            snapshot = Path(result["snapshotPath"])
            self.assertFalse(run.exists())
            self.assertEqual(current_snapshot_id(paths, "gui"), result["snapshotId"])
            self.assertTrue((snapshot / "home/page.lepiter").is_file())
            self.assertFalse((snapshot / "cache").exists())
            self.assertFalse((snapshot / "tmp").exists())
            self.assertEqual({item["path"] for item in result["components"]}, {"image", "export", "home", "config", "data", "logs"})
            set_tree_writable(snapshot, True)

    def test_snapshot_pointer_management_retains_history(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            state = Path(temporary)
            paths = BuildPaths(ROOT, state)
            snapshot = state / "snapshots/gui/one"
            snapshot.mkdir(parents=True)
            (snapshot / "snapshot.json").write_text(json.dumps({
                "schemaVersion": 2, "snapshotId": "one", "contextId": "gui",
                "createdAt": "now", "classification": "L06-tmp-resumable-noncanonical",
            }))
            select_snapshot(paths, "gui", "one")
            self.assertTrue(list_snapshots(paths, "gui")["snapshots"][0]["current"])
            self.assertTrue(clear_current_snapshot(paths, "gui")["cleared"])
            self.assertTrue(snapshot.exists())

    def test_image_tool_bridge_uses_json_and_removes_successful_run(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            root = Path(temporary)
            paths = BuildPaths(root, root / ".klibgen")
            run_path = root / "run"
            (run_path / "image").mkdir(parents=True)
            (run_path / "logs").mkdir()
            run = {
                "runId": "tool-run", "runPath": str(run_path),
                "launcher": str(root / "GlamorousToolkit-cli"),
            }
            process = MagicMock()
            process.pid = 123
            process.returncode = 0
            process.communicate.return_value = (
                b'{"schemaVersion":1,"ok":true,"operation":"eval","data":{"result":"42"}}\n',
                b"diagnostic\n",
            )

            with (
                patch("klibgen_build.operations.create_project_run", return_value=run),
                patch("klibgen_build.operations.start_command", return_value=process) as start,
                patch("klibgen_build.operations.write_run_metadata"),
            ):
                result = execute_image_tool(
                    paths, "default", {"operation": "eval", "expression": "40 + 2"}
                )

            request = json.loads(start.call_args.kwargs["env"]["KLIBGEN_TOOL_REQUEST"])
            self.assertEqual(request["expression"], "40 + 2")
            self.assertTrue(result["ok"])
            self.assertIsNone(result["runPath"])
            self.assertFalse(run_path.exists())

    def test_image_tool_bridge_retains_structured_failure(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            root = Path(temporary)
            paths = BuildPaths(root, root / ".klibgen")
            run_path = root / "run"
            (run_path / "image").mkdir(parents=True)
            (run_path / "logs").mkdir()
            run = {"runId": "tool-run", "runPath": str(run_path), "launcher": "launcher"}
            process = MagicMock()
            process.pid = 123
            process.returncode = 1
            process.communicate.return_value = (
                b'{"schemaVersion":1,"ok":false,"operation":"eval","error":{"class":"ZeroDivide","message":"division by zero"}}\n',
                b"image diagnostic\n",
            )

            with (
                patch("klibgen_build.operations.create_project_run", return_value=run),
                patch("klibgen_build.operations.start_command", return_value=process),
                patch("klibgen_build.operations.write_run_metadata"),
            ):
                result = execute_image_tool(paths, "default", {"operation": "eval"})

            self.assertFalse(result["ok"])
            self.assertEqual(result["runPath"], str(run_path))
            self.assertIn("image diagnostic", result["error"]["stderr"])
            self.assertTrue(run_path.exists())


if __name__ == "__main__":
    unittest.main()
