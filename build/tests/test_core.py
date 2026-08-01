import json
import os
import subprocess
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from klibgen_build.core import BuildPaths, canonical_json, digest_json, load_context, load_layers
from klibgen_build.sources import expected_lock, validate_lock
from klibgen_build.lifecycle import (
    acknowledge_gui_refresh, clear_current_snapshot, clear_gui_refresh, current_snapshot_id,
    discard_run, gui_refresh, list_snapshots, promote_gui_commits, promote_packages, resume_snapshot,
    select_snapshot, snapshot_run,
)
from klibgen_build.operations import (
    GuiEventConsumer, _gui_save_evidence, _run_environment, diagnose_test,
    execute_image_tool, execute_test_one, export_build_map_pngs, launch_build_map, launch_gui,
)
from klibgen_build.artifacts import build_l07, git_worktree_state, set_tree_writable
from klibgen_build.retention import garbage_collect, prune, retention_plan
from klibgen_build.coordination import retention_lock
from klibgen_build.cli import parser
from klibgen_build.contexts import list_contexts
from klibgen_build.processes import run_command
from klibgen_build.inventory import build_inventory


ROOT = Path(__file__).resolve().parents[2]


class CoreTest(unittest.TestCase):
    def _artifact(self, state: Path, context: str, layer: str, key: str, parents=None) -> Path:
        artifact = state / "artifacts/linux-x86_64" / context / layer.lower() / key
        artifact.mkdir(parents=True)
        manifest = {
            "schemaVersion": 1,
            "platform": "linux-x86_64",
            "contextId": context,
            "layerId": layer.upper(),
            "buildKey": key,
            "parents": parents or [],
        }
        (artifact / "manifest.json").write_text(json.dumps(manifest))
        (artifact / "payload").write_bytes(b"artifact")
        return artifact

    def _node(self, artifact: Path, layer: str, key: str) -> dict:
        return {"artifact": artifact, "buildKey": key, "definition": {"layerId": layer.upper()}}

    def test_gc_dry_run_is_non_mutating_and_apply_uses_same_candidates(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            state = Path(temporary)
            root = state / "repo"
            (root / "build/contexts").mkdir(parents=True)
            (root / "build/contexts/default.json").write_text("{}")
            paths = BuildPaths(root, state / "state")
            current = self._artifact(paths.state, "default", "l01", "current")
            stale = self._artifact(paths.state, "default", "l01", "stale")
            for index in range(5):
                attempt = paths.state / "tmp" / f"attempt-{index}"
                attempt.mkdir(parents=True)
                (attempt / "diagnostic.log").write_text(str(index))
                os.utime(attempt, (index + 1, index + 1))

            nodes = [self._node(current, "l01", "current")]
            with patch("klibgen_build.retention.graph", return_value=nodes):
                planned = garbage_collect(paths, dry_run=True)
            self.assertTrue(stale.exists())
            self.assertEqual(planned["candidateCounts"], {"artifact": 1, "attempt": 2})
            self.assertGreater(planned["estimatedLogicalBytes"], 0)

            with patch("klibgen_build.retention.graph", return_value=nodes):
                applied = garbage_collect(paths)
            self.assertEqual(
                {(item["kind"], item["path"]) for item in planned["candidates"]},
                {(item["kind"], item["path"]) for item in applied["candidates"]},
            )
            self.assertEqual(applied["removedCounts"], applied["candidateCounts"])
            self.assertTrue(current.exists())
            self.assertFalse(stale.exists())
            self.assertEqual(len(list((paths.state / "tmp").glob("attempt-*"))), 3)

    def test_gc_protects_all_artifacts_for_an_unresolved_context(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            state = Path(temporary)
            root = state / "repo"
            (root / "build/contexts").mkdir(parents=True)
            (root / "build/contexts/broken.json").write_text("{}")
            paths = BuildPaths(root, state / "state")
            artifact = self._artifact(paths.state, "broken", "l01", "only")
            with patch("klibgen_build.retention.graph", side_effect=ValueError("broken context")):
                result = retention_plan(paths, "gc")
            self.assertEqual(result["skippedContexts"], ["broken"])
            self.assertFalse(any(item["path"] == str(artifact.resolve()) for item in result["candidates"]))
            self.assertTrue(any(item["reason"] == "unresolved-context-protection" for item in result["retained"]))

    def test_prune_removes_clone_rebuild_state_and_preserves_live_work(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            state = Path(temporary)
            paths = BuildPaths(ROOT, state)
            default = self._artifact(state, "default", "l01", "default-current")
            gui = self._artifact(state, "gui", "l01", "gui-current")
            stale = self._artifact(state, "default", "l01", "stale")
            other = self._artifact(state, "acceptance", "l01", "other")
            pinned = self._artifact(state, "acceptance", "l02", "pinned")
            active_parent = self._artifact(state, "acceptance", "l03", "active-parent")
            (state / "state/pins").mkdir(parents=True)
            (state / "state/pins/keep.json").write_text(json.dumps({
                "pin": "keep", "artifactPath": str(pinned),
            }))

            active = state / "runs/acceptance/active"
            stopped = state / "runs/default/stopped"
            active.mkdir(parents=True)
            stopped.mkdir(parents=True)
            (active / "run.json").write_text(json.dumps({
                "runId": "active", "state": "running", "pid": 123,
                "parentArtifact": str(active_parent),
            }))
            (stopped / "run.json").write_text(json.dumps({"runId": "stopped", "state": "stopped", "pid": 456}))

            snapshot = state / "snapshots/gui/saved"
            snapshot.mkdir(parents=True)
            (snapshot / "snapshot.json").write_text(json.dumps({"snapshotId": "saved"}))
            (state / "state/gui").mkdir(parents=True)
            (state / "state/gui/gui.json").write_text(json.dumps({"snapshotId": "saved"}))
            (state / "state/gui-refresh").mkdir(parents=True)
            refresh = state / "state/gui-refresh/gui.json"
            refresh.write_text(json.dumps({"state": "pending"}))
            generated = state / "contexts/acceptance.json"
            generated.parent.mkdir(parents=True)
            generated.write_text("{}")
            worktree_marker = state / "worktrees/acceptance/marker"
            worktree_marker.parent.mkdir(parents=True)
            worktree_marker.write_text("keep")
            for name in ("one", "two"):
                attempt = state / "tmp" / f"attempt-{name}"
                attempt.mkdir(parents=True)
                (attempt / "log").write_text(name)
            rebuild = state / "logs/rebuilds/default/l01/key/id"
            rebuild.mkdir(parents=True)
            (rebuild / "contract.log").write_text("diagnostic")

            nodes = {
                "default": [self._node(default, "l01", "default-current")],
                "gui": [self._node(gui, "l01", "gui-current")],
            }
            with patch("klibgen_build.retention.graph", side_effect=lambda _, context: nodes[context]), \
                 patch("klibgen_build.retention.process_is_alive", side_effect=lambda pid: pid == 123):
                dry_run = prune(paths, dry_run=True)
                self.assertTrue(snapshot.exists())
                result = prune(paths)

            self.assertEqual(dry_run["candidateCounts"], result["candidateCounts"])
            self.assertEqual(result["removedCounts"], result["candidateCounts"])
            for retained in (default, gui, pinned, active_parent, active, refresh, generated, worktree_marker):
                self.assertTrue(retained.exists(), retained)
            for removed in (stale, other, stopped, snapshot, state / "state/gui/gui.json", state / "tmp/attempt-one", rebuild):
                self.assertFalse(removed.exists(), removed)
            self.assertIn("snapshot", result["candidateCounts"])
            self.assertIn("rebuild-log", result["candidateCounts"])

    def test_retention_cli_exposes_dry_run_for_gc_and_prune(self):
        self.assertTrue(parser().parse_args(["gc", "--dry-run"]).dry_run)
        self.assertTrue(parser().parse_args(["prune", "--dry-run", "--json"]).json)

    def test_build_inventory_connects_definitions_artifacts_runs_snapshots_and_pins(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            root = Path(temporary) / "repo"
            state = Path(temporary) / "state"
            layer = root / "build/layers/l01-runtime"
            layer.mkdir(parents=True)
            (layer / "layer.json").write_text(json.dumps({"layerId": "L01", "name": "runtime"}))
            contexts = root / "build/contexts"
            contexts.mkdir(parents=True)
            (contexts / "default.json").write_text(json.dumps({
                "schemaVersion": 1, "contextId": "default", "layers": {"L01": {"variant": "test"}},
            }))
            artifact = self._artifact(state, "default", "l01", "current")
            stale = self._artifact(state, "default", "l01", "stale")
            run = state / "runs/default/run-one"
            run.mkdir(parents=True)
            (run / "run.json").write_text(json.dumps({
                "runId": "run-one", "contextId": "default", "state": "stopped",
                "parentArtifact": str(artifact),
            }))
            snapshot = state / "snapshots/default/saved"
            snapshot.mkdir(parents=True)
            (snapshot / "snapshot.json").write_text(json.dumps({
                "snapshotId": "saved", "contextId": "default", "parentL06Artifact": str(artifact),
            }))
            (state / "state/gui").mkdir(parents=True)
            (state / "state/gui/default.json").write_text(json.dumps({
                "snapshotId": "saved", "contextId": "default",
            }))
            (state / "state/pins").mkdir(parents=True)
            (state / "state/pins/current.json").write_text(json.dumps({
                "pin": "current", "contextId": "default", "artifactPath": str(artifact),
            }))
            nodes = [self._node(artifact, "l01", "current")]
            with patch("klibgen_build.inventory.graph", return_value=nodes), \
                 patch("klibgen_build.inventory.process_is_alive", return_value=False):
                inventory = build_inventory(BuildPaths(root, state))
            by_path = {node["path"]: node for node in inventory["nodes"] if node["path"]}
            self.assertEqual(by_path[str(artifact.resolve())]["status"], "current")
            self.assertEqual(by_path[str(stale.resolve())]["status"], "stale")
            edge_kinds = {edge["kind"] for edge in inventory["edges"]}
            self.assertTrue({
                "context-layer", "context-artifact", "artifact-materializes", "pin-artifact", "pointer-snapshot",
            } <= edge_kinds)
            self.assertGreater(inventory["metrics"]["stateRoot"]["logicalBytes"], 0)
            self.assertIn("Allocated bytes double-count", inventory["metrics"]["sizeWarning"])

    def test_build_inventory_does_not_follow_symlinks_and_reports_broken_records(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            root = Path(temporary) / "repo"
            state = Path(temporary) / "state"
            (root / "build/layers").mkdir(parents=True)
            (root / "build/contexts").mkdir(parents=True)
            outside = Path(temporary) / "outside"
            outside.mkdir()
            (outside / "large").write_bytes(b"x" * 10000)
            cache = state / "cache"
            cache.mkdir(parents=True)
            (cache / "outside").symlink_to(outside, target_is_directory=True)
            (state / "state/pins").mkdir(parents=True)
            (state / "state/pins/broken.json").write_text(json.dumps({
                "pin": "broken", "artifactPath": str(state / "missing"),
            }))
            inventory = build_inventory(BuildPaths(root, state))
            cache_node = next(node for node in inventory["nodes"] if node["kind"] == "auxiliary-storage")
            self.assertLess(cache_node["logicalBytes"], 10000)
            pin = next(node for node in inventory["nodes"] if node["kind"] == "pin")
            self.assertEqual(pin["status"], "broken")
            self.assertTrue(any(node["kind"] == "missing-reference" for node in inventory["nodes"]))

    def test_build_map_cli_contracts_and_disposable_launch_cleanup(self):
        parsed = parser().parse_args(["build-map-png", "tmp/out", "default", "--force"])
        self.assertEqual(parsed.output_dir, "tmp/out")
        self.assertTrue(parsed.force)
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            state = Path(temporary) / "state"
            run_path = state / "runs/gui/tool"
            (run_path / "logs").mkdir(parents=True)
            (run_path / "image").mkdir()
            run = {"runId": "tool", "runPath": str(run_path), "launcher": str(state / "GlamorousToolkit-cli")}
            process = MagicMock()
            process.wait.return_value = 0
            process.poll.return_value = 0
            inventory = {"generatedAt": "now", "nodes": [], "edges": [], "warnings": []}
            with patch("klibgen_build.operations.build_l06"), \
                 patch("klibgen_build.operations.build_inventory", return_value=inventory), \
                 patch("klibgen_build.operations.create_project_run", return_value=run), \
                 patch("klibgen_build.operations.run_command", return_value=SimpleNamespace(returncode=0, stdout="", stderr="")), \
                 patch("klibgen_build.operations.start_command", return_value=process), \
                 patch("klibgen_build.operations.write_run_metadata"):
                result = launch_build_map(BuildPaths(ROOT, state))
            self.assertIsNone(result["runPath"])
            self.assertFalse(run_path.exists())

    def test_build_map_png_refuses_overwrite_before_image_execution(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            output = Path(temporary) / "map"
            output.mkdir()
            (output / "overview.png").write_bytes(b"png")
            with patch("klibgen_build.operations.build_l06"), \
                 patch("klibgen_build.operations.execute_image_tool") as execute:
                with self.assertRaisesRegex(ValueError, "refusing to overwrite"):
                    export_build_map_pngs(BuildPaths(ROOT, Path(temporary) / "state"), output)
            execute.assert_not_called()

    def test_exclusive_retention_waits_for_a_shared_build_lock(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            state = Path(temporary)
            code = (
                "import sys\n"
                "from pathlib import Path\n"
                "from klibgen_build.core import BuildPaths\n"
                "from klibgen_build.coordination import retention_lock\n"
                f"paths = BuildPaths(Path({str(ROOT)!r}), Path({str(state)!r}))\n"
                "with retention_lock(paths):\n"
                " print('ready', flush=True)\n"
                " sys.stdin.read(1)\n"
            )
            environment = os.environ.copy()
            environment["PYTHONPATH"] = str(ROOT / "python")
            child = subprocess.Popen(
                [sys.executable, "-c", code], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                text=True, env=environment,
            )
            acquired = threading.Event()
            try:
                self.assertEqual(child.stdout.readline().strip(), "ready")

                def acquire_exclusive():
                    with retention_lock(BuildPaths(ROOT, state), exclusive=True):
                        acquired.set()

                waiter = threading.Thread(target=acquire_exclusive, daemon=True)
                waiter.start()
                self.assertFalse(acquired.wait(0.1))
                child.stdin.write("x")
                child.stdin.flush()
                self.assertTrue(acquired.wait(2))
                waiter.join(2)
            finally:
                if child.poll() is None:
                    child.terminate()
                child.wait(timeout=2)
                child.stdin.close()
                child.stdout.close()

    def test_test_one_uses_structured_image_operation(self):
        paths = BuildPaths(ROOT, ROOT / ".klibgen-test")
        response = {
            "schemaVersion": 1, "ok": True, "operation": "test.run",
            "data": {"successful": True, "runCount": 1},
        }
        with patch("klibgen_build.operations.execute_image_tool", return_value=response) as execute:
            result = execute_test_one(paths, "default", "KlibGenGtTest", "testProjectName")
        execute.assert_called_once_with(paths, "default", {
            "operation": "test.run", "class": "KlibGenGtTest", "selector": "testProjectName",
        })
        self.assertEqual(result["operation"], "test-one")
        self.assertEqual(result["selector"], "testProjectName")

    def test_test_diagnose_reads_run_and_attempt_reports(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            state = Path(temporary)
            paths = BuildPaths(ROOT, state)
            report = {
                "schemaVersion": 1, "successful": False, "runCount": 1,
                "passedCount": 0, "failureCount": 1, "errorCount": 0,
                "skippedCount": 0, "tests": [],
            }
            run = state / "runs/default/run-id/logs"
            run.mkdir(parents=True)
            (run / "test-results.json").write_text(json.dumps(report))
            diagnosed_run = diagnose_test(paths, "run-id")
            self.assertEqual(diagnosed_run["recordKind"], "run")
            self.assertEqual(diagnosed_run["testResults"], report)

            attempt = state / "tmp/attempt-id"
            attempt.mkdir(parents=True)
            (attempt / "contract-results.json").write_text(json.dumps(report))
            diagnosed_attempt = diagnose_test(paths, "attempt-id")
            self.assertEqual(diagnosed_attempt["recordKind"], "attempt")
            self.assertTrue(diagnosed_attempt["ok"])

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
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            paths = BuildPaths(ROOT, Path(temporary))
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
        startup = (ROOT / "src/KlibGenGt-Tools/KGGuiSessionHooks.class.st").read_text()
        self.assertIn("world removeShutdownListener; addShutdownListener.", startup)
        self.assertIn("mode = 'resumed'", startup)
        self.assertIn("staleWorld ~~ world ifTrue: [ staleWorld close ]", startup)
        self.assertIn("ifFalse: [ GtWorld defaultWorld ifNil: [ GtWorld openDefault ] ]", startup)

    def _gui_promotion_fixture(self, temporary):
        root = Path(temporary)
        state = root / ".klibgen"
        paths = BuildPaths(root, state)
        for context in ("default", "gui"):
            context_path = root / f"build/contexts/{context}.json"
            context_path.parent.mkdir(parents=True, exist_ok=True)
            context_path.write_text(json.dumps({
                "schemaVersion": 1, "contextId": context,
                "project": {"workspace": ".", "revision": "@"}, "layers": {},
            }))
        package = root / "src/KlibGenGt-Core"
        package.mkdir(parents=True)
        (package / "package.st").write_text("base\n")
        run = state / "runs/gui/gui-run"
        bridge = run / "export"
        (bridge / "src/KlibGenGt-Core").mkdir(parents=True)
        (bridge / "src/KlibGenGt-Core/package.st").write_text("base\n")
        run_command(["git", "init", "--initial-branch=master", bridge])
        run_command(["git", "-C", bridge, "add", "src"])
        run_command(["git", "-C", bridge, "-c", "user.name=Test", "-c", "user.email=test@localhost", "commit", "-m", "base"])
        base = run_command(["git", "-C", bridge, "rev-parse", "HEAD"]).stdout.strip()
        metadata = {
            "schemaVersion": 2, "runId": "gui-run", "contextId": "gui", "profile": "gui",
            "projectCommitId": "outer-base", "generatedBridgeCommit": base,
        }
        (run / "run.json").write_text(json.dumps(metadata))
        return paths, run, bridge

    def _bridge_commit(self, bridge, message):
        run_command(["git", "-C", bridge, "add", "."])
        run_command(["git", "-C", bridge, "-c", "user.name=Test", "-c", "user.email=test@localhost", "commit", "-m", message])

    def test_automatic_gui_promotion_handles_repeated_and_coalesced_commits(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            paths, run, bridge = self._gui_promotion_fixture(temporary)
            source = bridge / "src/KlibGenGt-Core/package.st"
            source.write_text("first\n")
            self._bridge_commit(bridge, "first")
            with patch("klibgen_build.lifecycle._authoritative_package_changed", return_value=False):
                first = promote_gui_commits(paths, "gui-run")
            self.assertTrue(first["promoted"])
            self.assertEqual((paths.root / "src/KlibGenGt-Core/package.st").read_text(), "first\n")

            source.write_text("second\n")
            self._bridge_commit(bridge, "second")
            extra = bridge / "src/KlibGenGt-Tools"
            extra.mkdir()
            (extra / "package.st").write_text("tools\n")
            self._bridge_commit(bridge, "third")
            with patch("klibgen_build.lifecycle._authoritative_package_changed", return_value=False):
                repeated = promote_gui_commits(paths, "gui-run")
            self.assertEqual(repeated["packages"], ["KlibGenGt-Core", "KlibGenGt-Tools"])
            self.assertEqual((paths.root / "src/KlibGenGt-Core/package.st").read_text(), "second\n")
            self.assertTrue((paths.root / "src/KlibGenGt-Tools/package.st").is_file())
            self.assertEqual(gui_refresh(paths, "gui")["state"], "pending")

    def test_automatic_gui_promotion_ignores_nonproject_paths(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            paths, run, bridge = self._gui_promotion_fixture(temporary)
            (bridge / "README.md").write_text("ignored\n")
            self._bridge_commit(bridge, "docs")
            result = promote_gui_commits(paths, "gui-run")
            self.assertEqual(result["packages"], [])
            self.assertIsNone(gui_refresh(paths, "gui"))

    def test_automatic_gui_promotion_never_copies_uncommitted_followup_edits(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            paths, run, bridge = self._gui_promotion_fixture(temporary)
            source = bridge / "src/KlibGenGt-Core/package.st"
            source.write_text("committed\n")
            self._bridge_commit(bridge, "committed")
            source.write_text("uncommitted followup\n")
            with patch("klibgen_build.lifecycle._authoritative_package_changed", return_value=False):
                blocked = promote_gui_commits(paths, "gui-run")
            self.assertFalse(blocked["promoted"])
            self.assertIn("uncommitted changes", blocked["error"]["message"])
            self.assertEqual(
                (paths.root / "src/KlibGenGt-Core/package.st").read_text(), "base\n",
            )

    def test_manual_gui_promotion_requests_refresh_without_hiding_other_commits(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            paths, run, bridge = self._gui_promotion_fixture(temporary)
            (bridge / "src/KlibGenGt-Core/package.st").write_text("manual\n")
            tools = bridge / "src/KlibGenGt-Tools"
            tools.mkdir()
            (tools / "package.st").write_text("automatic later\n")
            self._bridge_commit(bridge, "both")
            with patch("klibgen_build.lifecycle._authoritative_package_changed", return_value=False):
                manual = promote_packages(paths, "gui-run", ["KlibGenGt-Core"], "default")
                automatic = promote_gui_commits(paths, "gui-run")
            self.assertTrue(manual["guiRefreshRequested"])
            self.assertEqual(
                automatic["packages"], ["KlibGenGt-Core", "KlibGenGt-Tools"],
            )
            self.assertTrue((paths.root / "src/KlibGenGt-Tools/package.st").is_file())

    def test_automatic_gui_promotion_blocks_concurrent_same_package_edit_and_retries(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            paths, run, bridge = self._gui_promotion_fixture(temporary)
            source = bridge / "src/KlibGenGt-Core/package.st"
            source.write_text("first\n")
            self._bridge_commit(bridge, "first")
            with patch("klibgen_build.lifecycle._authoritative_package_changed", return_value=False):
                promote_gui_commits(paths, "gui-run")
            promoted = paths.root / "src/KlibGenGt-Core/package.st"
            promoted.write_text("concurrent\n")
            source.write_text("second\n")
            self._bridge_commit(bridge, "second")
            blocked = promote_gui_commits(paths, "gui-run")
            self.assertFalse(blocked["promoted"])
            self.assertEqual(promoted.read_text(), "concurrent\n")
            self.assertEqual(gui_refresh(paths, "gui")["state"], "blocked")
            promoted.write_text("first\n")
            retried = promote_gui_commits(paths, "gui-run")
            self.assertTrue(retried["promoted"])
            self.assertEqual(promoted.read_text(), "second\n")

    def test_gui_event_consumer_tolerates_malformed_and_filters_repository(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            root = Path(temporary)
            paths = BuildPaths(root, root / ".klibgen")
            run_path = root / "run"
            (run_path / "logs").mkdir(parents=True)
            run = {"runId": "run", "runPath": str(run_path)}
            consumer = GuiEventConsumer(paths, run)
            journal = run_path / "logs/gui-events.jsonl"
            journal.write_text('{bad}\n' + json.dumps({"event": "iceberg-committed", "repositoryPath": str(root / "other")}) + "\n")
            with patch("klibgen_build.operations.promote_gui_commits") as promote:
                self.assertEqual(consumer.consume(), [])
            promote.assert_not_called()
            with journal.open("a") as stream:
                stream.write(json.dumps({"event": "iceberg-committed", "repositoryPath": str(run_path / "export")}) + "\n")
            with patch("klibgen_build.operations.promote_gui_commits", return_value={"promoted": True, "packages": ["KlibGenGt-Core"]}) as promote:
                self.assertEqual(len(consumer.consume()), 1)
            promote.assert_called_once_with(paths, "run")

    def test_gui_refresh_generation_acknowledgement_is_conditional(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            paths = BuildPaths(Path(temporary), Path(temporary) / ".klibgen")
            record = paths.state / "state/gui-refresh/gui.json"
            record.parent.mkdir(parents=True)
            record.write_text(json.dumps({"state": "pending", "generation": "new"}))
            self.assertFalse(acknowledge_gui_refresh(paths, "gui", "old"))
            self.assertTrue(record.exists())
            self.assertTrue(acknowledge_gui_refresh(paths, "gui", "new"))
            self.assertFalse(record.exists())

    def test_pending_gui_refresh_bypasses_current_snapshot(self):
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
            refresh = paths.state / "state/gui-refresh/gui.json"
            refresh.parent.mkdir(parents=True)
            refresh.write_text(json.dumps({
                "state": "pending", "generation": "generation", "sourceRunId": "old-run",
                "packages": ["KlibGenGt-Core"],
            }))
            run_path = root / "run"
            (run_path / "image").mkdir(parents=True)
            (run_path / "logs").mkdir()
            image = run_path / "image/GlamorousToolkit.image"
            image.write_bytes(b"image")
            cli_launcher = root / "runtime/GlamorousToolkit-cli"
            gui_launcher = cli_launcher.with_name("GlamorousToolkit")
            gui_launcher.parent.mkdir(parents=True)
            gui_launcher.touch()
            run = {"runId": "fresh", "runPath": str(run_path), "launcher": str(cli_launcher)}
            process = MagicMock(pid=123)
            process.wait.return_value = 0
            with (
                patch("klibgen_build.operations.create_project_run", return_value=run) as create,
                patch("klibgen_build.operations.resume_snapshot") as resume,
                patch("klibgen_build.operations.run_command", return_value=SimpleNamespace(returncode=0, stdout="", stderr="")),
                patch("klibgen_build.operations.start_command", return_value=process),
                patch("klibgen_build.operations.write_run_metadata"),
            ):
                self.assertEqual(launch_gui(paths, "gui"), 0)
            create.assert_called_once_with(paths, "gui", "gui")
            resume.assert_not_called()
            self.assertTrue(refresh.exists(), "quit without save must retain the generation")

    def test_blocked_gui_refresh_stops_only_ordinary_launch(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            root = Path(temporary)
            paths = BuildPaths(root, root / ".klibgen")
            refresh = paths.state / "state/gui-refresh/gui.json"
            refresh.parent.mkdir(parents=True)
            refresh.write_text(json.dumps({
                "state": "blocked", "generation": "generation", "sourceRunId": "source-run",
                "packages": ["KlibGenGt-Core"], "failureDetails": {"message": "concurrent edit"},
            }))
            with self.assertRaisesRegex(ValueError, "source-run.*KlibGenGt-Core.*concurrent edit"):
                launch_gui(paths, "gui")
            with patch("klibgen_build.operations.create_project_run", side_effect=RuntimeError("explicit launch reached build")):
                with self.assertRaisesRegex(RuntimeError, "explicit launch reached build"):
                    launch_gui(paths, "gui", fresh=True)
            self.assertTrue(refresh.exists())

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
