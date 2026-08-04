from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from klibgen_build.canonical import _dependency_environment
from klibgen_build.core import BuildPaths
from klibgen_build.measurements import storage_metrics
from klibgen_build.processes import CommandResult
from klibgen_build.v2state import V2Paths


ROOT = Path(__file__).resolve().parents[2]


class V2BaselineTest(unittest.TestCase):
    def setUp(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=ROOT / "tmp")
        self.root = Path(self.temporary.name)

    def tearDown(self):
        self.temporary.cleanup()

    def test_v2_paths_are_initialized_and_deletion_is_strictly_owned(self):
        paths = V2Paths.for_build(BuildPaths(ROOT, self.root / ".klibgen"))
        paths.initialize()
        victim = paths.root / "tmp/victim"
        victim.mkdir()
        (victim / "immutable").write_text("published")
        (victim / "immutable").chmod(0o444)
        victim.chmod(0o555)
        paths.remove_tree(victim)
        self.assertFalse(victim.exists())
        with self.assertRaisesRegex(ValueError, "root itself"):
            paths.remove_tree(paths.root)
        with self.assertRaisesRegex(ValueError, "outside"):
            paths.remove_tree(self.root / "unowned")

    def test_secondary_jj_workspace_uses_primary_vendor_cache_but_local_state(self):
        primary = self.root / "primary"
        secondary = self.root / "secondary"
        (primary / ".jj/repo").mkdir(parents=True)
        (primary / "src").mkdir()
        (primary / "justfile").write_text("")
        (secondary / ".jj").mkdir(parents=True)
        (secondary / "src").mkdir()
        (secondary / "justfile").write_text("")
        (secondary / ".jj/repo").write_text(str(primary / ".jj/repo"))

        paths = BuildPaths(secondary, secondary / ".klibgen")

        self.assertEqual(paths.vendor, primary / "vendor")
        self.assertEqual(paths.state, secondary / ".klibgen")

        shell = subprocess.run(
            [
                "bash", "-c", 'source "$1"; shared_vendor_root "$2"', "fixture",
                str(ROOT / "scripts/utils.sh"), str(secondary),
            ],
            check=True, capture_output=True, text=True,
        )
        self.assertEqual(Path(shell.stdout.strip()), primary / "vendor")

    def test_explicit_vendor_root_overrides_jj_workspace_discovery(self):
        paths = BuildPaths(self.root, self.root / ".klibgen")
        with patch.dict(os.environ, {"KLIBGEN_VENDOR_ROOT": "cache/vendor"}):
            self.assertEqual(paths.vendor, (self.root / "cache/vendor").resolve())

    def test_dependency_environment_uses_pinned_local_checkout_layouts(self):
        commits = {"sqlite3": "a" * 40, "neojson": "b" * 40, "jsonschema": "c" * 40}
        for source_id in commits:
            (self.root / f"vendor/gt-build/dependencies/{source_id}/.git").mkdir(parents=True)
        step = {"resolvedConfiguration": {"sources": [
            {
                "sourceId": source_id,
                "source": f"https://example.invalid/{source_id}.git",
                "resolved": {"commit": commit},
            }
            for source_id, commit in commits.items()
        ]}}

        def revision(arguments, **_kwargs):
            source_id = Path(arguments[2]).name
            return CommandResult(0, commits[source_id] + "\n", "")

        with patch("klibgen_build.canonical.run_command", side_effect=revision):
            environment = _dependency_environment(
                BuildPaths(self.root, self.root / ".klibgen"), step,
            )

        self.assertEqual(
            environment["KLIBGEN_SQLITE_REPOSITORY"],
            f"gitlocal://{self.root}/vendor/gt-build/dependencies/sqlite3/.git:{commits['sqlite3']}/src",
        )
        self.assertEqual(
            environment["KLIBGEN_NEOJSON_REPOSITORY"],
            f"gitlocal://{self.root}/vendor/gt-build/dependencies/neojson/.git:{commits['neojson']}/repository",
        )
        self.assertEqual(
            environment["KLIBGEN_JSONSCHEMA_REPOSITORY"],
            f"gitlocal://{self.root}/vendor/gt-build/dependencies/jsonschema/.git:{commits['jsonschema']}/source",
        )

    def test_storage_measurement_counts_images_and_allocated_bytes(self):
        (self.root / "one.image").write_bytes(b"image")
        (self.root / "lib.so").write_bytes(b"native")
        metrics = storage_metrics(self.root)
        self.assertEqual(metrics["files"][".image"]["count"], 1)
        self.assertEqual(metrics["files"][".so"]["count"], 1)
        self.assertGreaterEqual(metrics["allocatedBytes"], metrics["logicalBytes"])

    def test_fake_vm_emits_ready_and_authoritative_completion(self):
        session = self.root / "session"
        manifest_path = session / "session.json"
        manifest_path.parent.mkdir()
        manifest_path.write_text(json.dumps({
            "schema": "klibgen.session/1",
            "sessionId": "fixture-one",
            "paths": {
                "ready": str(session / "ready.json"),
                "completion": str(session / "completion.json"),
            },
            "fixture": {"outcome": "discarded"},
        }))
        completed = subprocess.run(
            [sys.executable, str(ROOT / "build/tests/fixtures/fake_vm.py"), str(manifest_path)],
            check=False,
        )
        self.assertEqual(completed.returncode, 0)
        self.assertTrue(json.loads((session / "ready.json").read_text())["ready"])
        self.assertEqual(json.loads((session / "completion.json").read_text())["state"], "discarded")

    def test_fake_vm_crash_has_ready_but_no_completion(self):
        session = self.root / "crash"
        session.mkdir()
        manifest_path = session / "session.json"
        manifest_path.write_text(json.dumps({
            "schema": "klibgen.session/1", "sessionId": "fixture-crash",
            "paths": {"ready": str(session / "ready.json"), "completion": str(session / "completion.json")},
            "fixture": {"outcome": "crash"},
        }))
        completed = subprocess.run(
            [sys.executable, str(ROOT / "build/tests/fixtures/fake_vm.py"), str(manifest_path)],
            check=False,
        )
        self.assertEqual(completed.returncode, 70)
        self.assertTrue((session / "ready.json").is_file())
        self.assertFalse((session / "completion.json").exists())


if __name__ == "__main__":
    unittest.main()
