import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from build.klibgen_build.core import BuildPaths, canonical_json, digest_json, load_context, load_layers
from build.klibgen_build.sources import expected_lock, validate_lock
from build.klibgen_build.lifecycle import discard_run, resume_snapshot, snapshot_run


ROOT = Path(__file__).resolve().parents[2]


class CoreTest(unittest.TestCase):
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
        result = subprocess.run(
            [sys.executable, "-m", "build.klibgen_build", "status", "default", "--json"],
            cwd=ROOT / "docs",
            env=environment,
            check=True,
            capture_output=True,
            text=True,
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
            subprocess.run(["git", "init", "--initial-branch=master", str(bridge)], check=True, capture_output=True)
            subprocess.run(["git", "-C", str(bridge), "add", "src"], check=True)
            subprocess.run(["git", "-C", str(bridge), "-c", "user.name=Test", "-c", "user.email=test@localhost", "commit", "-m", "base"], check=True, capture_output=True)
            bridge_commit = subprocess.run(["git", "-C", str(bridge), "rev-parse", "HEAD"], check=True, capture_output=True, text=True).stdout.strip()
            metadata = {
                "schemaVersion": 1, "runId": run_id, "contextId": "default", "profile": "cli",
                "parentArtifact": "artifact", "parentBuildKey": "build-key", "projectCommitId": "project-commit",
                "projectChangeId": "project-change", "generatedBridgeCommit": bridge_commit, "state": "stopped",
                "launcher": "launcher",
            }
            (run / "run.json").write_text(json.dumps(metadata))

            snapshot = snapshot_run(paths, run_id)
            self.assertEqual(snapshot["parentL06BuildKey"], "build-key")
            resumed = resume_snapshot(paths, snapshot["snapshotId"])
            self.assertEqual(resumed["resumedFromSnapshot"], snapshot["snapshotId"])
            self.assertTrue((Path(resumed["runPath"]) / "image/GlamorousToolkit.image").is_file())
            self.assertTrue(discard_run(paths, resumed["runId"])["discarded"])


if __name__ == "__main__":
    unittest.main()
