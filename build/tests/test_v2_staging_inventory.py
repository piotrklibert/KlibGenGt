from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from klibgen_build.core import BuildPaths, digest_json
from klibgen_build.inventory_v2 import garbage_collect
from klibgen_build.staging import create_staging, promote_staging, staging_changes, validate_staging_name
from klibgen_build.store import ArtifactStore, atomic_json


ROOT = Path(__file__).resolve().parents[2]


class V2StagingInventoryTest(unittest.TestCase):
    def setUp(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=ROOT / "tmp")
        root = Path(self.temp.name)
        (root / "src/KlibGenGt-Fixture").mkdir(parents=True)
        (root / "src/KlibGenGt-Fixture/One.class.st").write_text("one")
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
        promote_staging(self.paths, "work")
        self.assertEqual((self.paths.root / "src/KlibGenGt-Fixture/One.class.st").read_text(), "changed")
        self.assertEqual((self.paths.root / "src/KlibGenGt-Fixture/Added.class.st").read_text(), "added")

    def test_promotion_rejects_stale_overlapping_authoritative_change(self):
        self.create()
        relative = Path("KlibGenGt-Fixture/One.class.st")
        (self.paths.state / "v2/staging/work/overlay/src" / relative).write_text("staged")
        (self.paths.root / "src" / relative).write_text("authoritative")
        with self.assertRaisesRegex(ValueError, "conflicts"):
            promote_staging(self.paths, "work")
        record = json.loads((self.paths.state / "v2/staging/work/staging.json").read_text())
        self.assertEqual(record["state"], "conflicted")

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


if __name__ == "__main__":
    unittest.main()
