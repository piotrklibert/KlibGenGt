from __future__ import annotations

import fcntl
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from klibgen_build.core import BuildPaths, digest_json
from klibgen_build.inventory_v2 import garbage_collect, prune
from klibgen_build.source_requests import service_source_requests
from klibgen_build.staging import (
    acquire_staging_lease,
    create_staging,
    promote_staging,
    rebase_staging,
    release_staging_lease,
    staging_changes,
    validate_staging_name,
)
from klibgen_build.store import ArtifactStore, atomic_json


ROOT = Path(__file__).resolve().parents[2]


class V2StagingInventoryTest(unittest.TestCase):
    def setUp(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=ROOT / "tmp")
        root = Path(self.temp.name)
        (root / "src/KlibGenGt-Fixture").mkdir(parents=True)
        (root / "src/KlibGenGt-Fixture/One.class.st").write_text("one")
        (root / "src/KlibGenGt-Fixture/Two.class.st").write_text("two")
        self.paths = BuildPaths(root, root / ".klibgen")
        self.resolved = {
            "outputKey": "a" * 64,
            "steps": [{
                "role": "project-source",
                "resolvedConfiguration": {"source": {"vcs": "jj", "commitId": "fixture", "treeDigest": "base"}},
            }],
        }

    def tearDown(self):
        self.temp.cleanup()

    def create(self, name="work"):
        with patch("klibgen_build.staging.resolve_target", return_value=self.resolved):
            return create_staging(self.paths, name)

    def resolved_as(self, digest="current"):
        return self.resolved | {
            "steps": [{
                "role": "project-source",
                "resolvedConfiguration": {"source": {
                    "vcs": "jj", "commitId": digest, "treeDigest": digest,
                }},
            }],
        }

    def test_staging_records_add_modify_remove_rename_and_promotes_reviewable_files(self):
        self.create()
        overlay = self.paths.state / "v2/staging/work/overlay/src/KlibGenGt-Fixture"
        (overlay / "One.class.st").write_text("changed")
        (overlay / "Added.class.st").write_text("added")
        (overlay / "RenameMe.class.st").write_text("rename")
        base = self.paths.state / "v2/staging/work/base/src/KlibGenGt-Fixture"
        (base / "RenameMe.class.st").write_text("rename")
        (overlay / "Gone.class.st").write_text("gone")
        (base / "Gone.class.st").write_text("gone")
        (overlay / "Gone.class.st").unlink()
        (overlay / "RenameMe.class.st").rename(overlay / "Renamed.class.st")
        changes = staging_changes(self.paths, "work")
        self.assertEqual(changes["modifications"], ["KlibGenGt-Fixture/One.class.st"])
        self.assertEqual(changes["additions"], ["KlibGenGt-Fixture/Added.class.st"])
        self.assertEqual(changes["removals"], ["KlibGenGt-Fixture/Gone.class.st"])
        self.assertEqual(changes["renames"], [{"from": "KlibGenGt-Fixture/RenameMe.class.st", "to": "KlibGenGt-Fixture/Renamed.class.st"}])
        with patch("klibgen_build.staging.resolve_target", return_value=self.resolved_as()):
            promote_staging(self.paths, "work")
        self.assertEqual((self.paths.root / "src/KlibGenGt-Fixture/One.class.st").read_text(), "changed")
        self.assertEqual((self.paths.root / "src/KlibGenGt-Fixture/Added.class.st").read_text(), "added")

    def test_promotion_rejects_stale_overlapping_authoritative_change(self):
        self.create()
        relative = Path("KlibGenGt-Fixture/One.class.st")
        (self.paths.state / "v2/staging/work/overlay/src" / relative).write_text("staged")
        (self.paths.root / "src" / relative).write_text("authoritative")
        with (
            patch("klibgen_build.staging.resolve_target", return_value=self.resolved_as()),
            self.assertRaisesRegex(ValueError, "conflicts"),
        ):
            promote_staging(self.paths, "work")
        record = json.loads((self.paths.state / "v2/staging/work/staging.json").read_text())
        self.assertEqual(record["state"], "conflicted")

    def test_three_way_rebase_adopts_authoritative_and_preserves_non_overlapping_staged_changes(self):
        self.create()
        area = self.paths.state / "v2/staging/work"
        (area / "overlay/src/KlibGenGt-Fixture/One.class.st").write_text("staged")
        (self.paths.root / "src/KlibGenGt-Fixture/Two.class.st").write_text("authoritative")
        with patch("klibgen_build.staging.resolve_target", return_value=self.resolved_as()):
            result = rebase_staging(self.paths, "work")
        self.assertEqual((area / "overlay/src/KlibGenGt-Fixture/One.class.st").read_text(), "staged")
        self.assertEqual((area / "overlay/src/KlibGenGt-Fixture/Two.class.st").read_text(), "authoritative")
        self.assertTrue(result["staging"]["lastRebase"]["ok"])
        self.assertEqual(result["staging"]["generation"], 2)

    def test_three_way_rebase_detects_modify_add_delete_and_rename_collisions_without_rewriting_overlay(self):
        cases = ("modify", "add", "delete", "rename")
        for index, case in enumerate(cases):
            name = f"conflict-{index}"
            self.create(name)
            area = self.paths.state / "v2/staging" / name
            relative = Path("KlibGenGt-Fixture/One.class.st")
            if case == "modify":
                (area / "overlay/src" / relative).write_text("staged")
                (self.paths.root / "src" / relative).write_text("current")
            elif case == "add":
                relative = Path("KlibGenGt-Fixture/Added.class.st")
                (area / "overlay/src" / relative).write_text("staged")
                (self.paths.root / "src" / relative).write_text("current")
            elif case == "delete":
                (area / "overlay/src" / relative).unlink()
                (self.paths.root / "src" / relative).write_text("current")
            else:
                relative = Path("KlibGenGt-Fixture/Renamed.class.st")
                (area / "overlay/src/KlibGenGt-Fixture/One.class.st").rename(area / "overlay/src" / relative)
                (self.paths.root / "src" / relative).write_text("current")
            before = (area / "overlay/src" / relative).read_bytes() if (area / "overlay/src" / relative).exists() else None
            with (
                patch("klibgen_build.staging.resolve_target", return_value=self.resolved_as(case)),
                self.assertRaisesRegex(ValueError, "conflicts"),
            ):
                rebase_staging(self.paths, name)
            after = (area / "overlay/src" / relative).read_bytes() if (area / "overlay/src" / relative).exists() else None
            self.assertEqual(after, before)
            self.assertEqual(json.loads((area / "staging.json").read_text())["state"], "conflicted")
            # Restore the shared authoritative fixture for the next subcase.
            (self.paths.root / "src/KlibGenGt-Fixture/One.class.st").write_text("one")
            (self.paths.root / "src/KlibGenGt-Fixture/Added.class.st").unlink(missing_ok=True)
            (self.paths.root / "src/KlibGenGt-Fixture/Renamed.class.st").unlink(missing_ok=True)

    def test_promotion_rejects_prohibited_paths_and_is_repeatable(self):
        self.create()
        outside = self.paths.state / "v2/staging/work/overlay/src/Foreign/Bad.class.st"
        outside.parent.mkdir()
        outside.write_text("bad")
        with self.assertRaisesRegex(ValueError, "outside owned"):
            promote_staging(self.paths, "work")
        outside.unlink()
        relative = Path("KlibGenGt-Fixture/One.class.st")
        (self.paths.state / "v2/staging/work/overlay/src" / relative).write_text("staged")
        with patch("klibgen_build.staging.resolve_target", return_value=self.resolved_as()):
            first = promote_staging(self.paths, "work")
            second = promote_staging(self.paths, "work")
        self.assertEqual(first["changes"]["modifications"], [relative.as_posix()])
        self.assertEqual(second["changes"]["modifications"], [])

    def test_promotion_preparation_failure_leaves_authoritative_source_unchanged(self):
        self.create()
        relative = Path("KlibGenGt-Fixture/One.class.st")
        (self.paths.state / "v2/staging/work/overlay/src" / relative).write_text("staged")
        before = (self.paths.root / "src" / relative).read_text()
        with (
            patch("klibgen_build.staging.resolve_target", return_value=self.resolved_as()),
            patch("klibgen_build.staging._write_contents", side_effect=OSError("disk full")),
            self.assertRaisesRegex(OSError, "disk full"),
        ):
            promote_staging(self.paths, "work")
        self.assertEqual((self.paths.root / "src" / relative).read_text(), before)

    def test_exclusive_lease_recovers_abandoned_pid_and_reserves_dirty_gui(self):
        self.create()
        with patch("klibgen_build.staging.resolve_target", return_value=self.resolved_as()):
            first = acquire_staging_lease(self.paths, "work", "agentic", "session-one", 999999)
        self.assertEqual(first["lease"]["contextId"], "session-one")
        with patch("klibgen_build.staging.resolve_target", return_value=self.resolved_as()):
            recovered = acquire_staging_lease(self.paths, "work", "gui", "gui-default", os.getpid(), session_id="gui-one")
        self.assertEqual(recovered["lease"]["sessionId"], "gui-one")
        release_staging_lease(self.paths, "work", "gui-one", source_change_count=2)
        with (
            patch("klibgen_build.staging.resolve_target", return_value=self.resolved_as()),
            self.assertRaisesRegex(RuntimeError, "exclusively owned"),
        ):
            acquire_staging_lease(self.paths, "work", "agentic", "session-two", os.getpid())
        with patch("klibgen_build.staging.resolve_target", return_value=self.resolved_as()):
            resumed = acquire_staging_lease(self.paths, "work", "gui", "gui-default", os.getpid(), session_id="gui-two")
        self.assertEqual(resumed["lease"]["sessionId"], "gui-two")

    def test_source_request_service_validates_lease_and_reconciles_export_head(self):
        self.create()
        with patch("klibgen_build.staging.resolve_target", return_value=self.resolved_as()):
            acquire_staging_lease(self.paths, "work", "agentic", "session", os.getpid())
        area = self.paths.state / "v2/staging/work"
        (area / "overlay/src/KlibGenGt-Fixture/One.class.st").write_text("exported")
        from klibgen_build.processes import run_command
        run_command(["git", "-C", area / "overlay", "add", "src"])
        run_command(["git", "-C", area / "overlay", "-c", "user.name=Test", "-c", "user.email=test@localhost", "commit", "--quiet", "-m", "export"])
        requests, responses = area / "requests", area / "responses"
        requests.mkdir()
        request = {"sessionId": "session", "stagingArea": "work", "operation": "source.export"}
        (requests / "request.json").write_text(json.dumps(request))
        self.assertEqual(service_source_requests(self.paths, requests, responses, session_id="session", staging_name="work"), 1)
        response = json.loads((responses / "request.json").read_text())
        self.assertTrue(response["ok"])
        self.assertEqual(response["data"]["generation"], 2)

    def test_staging_name_cannot_escape_the_owned_root(self):
        for name in ("", "../outside", "-option", "has/slash", "has space"):
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "invalid staging name"):
                validate_staging_name(name)
        self.assertEqual(validate_staging_name("issue_42-fix"), "issue_42-fix")

    def test_gc_keeps_reference_recipe_chain_and_removes_unrooted_artifact(self):
        store = ArtifactStore(self.paths)
        keys = ["1" * 64, "2" * 64, "3" * 64]
        for key in keys:
            artifact = store.artifact("fixture", key)
            (artifact / "payload").mkdir(parents=True)
            atomic_json(artifact / "manifest.json", {
                "schema": "klibgen.artifact/1", "schemaVersion": 1,
                "artifactType": "fixture", "outputKey": key, "producingRole": "fixture",
                "payloadShapeDigest": digest_json([]),
                "resolvedRecipe": {"steps": []},
            })
        final_manifest = json.loads((store.artifact("fixture", keys[1]) / "manifest.json").read_text())
        final_manifest["resolvedRecipe"] = {"steps": [{"outputKey": keys[0], "checkpoint": "artifact"}]}
        atomic_json(store.artifact("fixture", keys[1]) / "manifest.json", final_manifest)
        atomic_json(store.v2.root / "refs/default.json", {"outputKey": keys[1]})
        plan = garbage_collect(self.paths)
        removed = {Path(item["path"]).name for item in plan["remove"]}
        self.assertEqual(removed, {keys[2]})

    def test_prune_removes_complete_project_state_including_read_only_artifacts_and_locks(self):
        state = self.paths.state
        artifact = state / "v2/store/image-workspace/linux-x86_64" / ("1" * 64)
        artifact.mkdir(parents=True)
        payload = artifact / "payload.image"
        payload.write_bytes(b"image")
        payload.chmod(0o444)
        artifact.chmod(0o555)
        lock = state / "v2/locks/artifacts/example.lock"
        lock.parent.mkdir(parents=True)
        lock.write_text("")
        (state / "legacy/cache").mkdir(parents=True)
        (state / "legacy/cache/value").write_text("legacy")

        result = prune(self.paths)

        self.assertTrue(result["removed"])
        self.assertEqual(result["lockCount"], 1)
        self.assertGreater(result["storage"]["allocatedBytes"], 0)
        self.assertFalse(state.exists())
        self.assertTrue((self.paths.root / "src").is_dir())

        rebuilt_store = ArtifactStore(self.paths)
        rebuilt = rebuilt_store.artifact("fixture", "2" * 64)
        (rebuilt / "payload").mkdir(parents=True)
        self.assertTrue((state / "v2/store").is_dir())
        self.assertTrue(rebuilt.is_dir())

    def test_prune_refuses_non_project_local_or_symbolic_link_state_root(self):
        outside = self.paths.root / "state"
        with self.assertRaisesRegex(ValueError, "project-local .klibgen"):
            prune(BuildPaths(self.paths.root, outside))

        target = self.paths.root / "state-target"
        target.mkdir()
        self.paths.state.symlink_to(target, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "symbolic-link state root"):
            prune(self.paths)
        self.assertTrue(target.exists())

    def test_prune_preserves_workspace_lepiter_database_and_removes_its_other_state(self):
        workspace = self.paths.state / "v2/workspaces/gui-default"
        database = workspace / "home/Documents/lepiter/default"
        database.mkdir(parents=True)
        page = database / "page.lepiter"
        page.write_text('{"title":"Class definition string"}')
        (workspace / "image").mkdir()
        (workspace / "image/GlamorousToolkit.image").write_bytes(b"generated")
        (workspace / "workspace.json").write_text("generated")

        result = prune(self.paths)

        self.assertEqual(result["preservedLepiterCount"], 1)
        self.assertEqual(page.read_text(), '{"title":"Class definition string"}')
        self.assertFalse((workspace / "image").exists())
        self.assertFalse((workspace / "workspace.json").exists())

    def test_prune_refuses_while_an_existing_build_lock_is_held(self):
        lock = self.paths.state / "v2/locks/artifacts/example.lock"
        lock.parent.mkdir(parents=True)
        with lock.open("w") as stream:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            with self.assertRaisesRegex(RuntimeError, "lock is held"):
                prune(self.paths)
        self.assertTrue(self.paths.state.exists())


if __name__ == "__main__":
    unittest.main()
