import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

from build.klibgen_build.core import BuildPaths, canonical_json, digest_json, load_context, load_layers
from build.klibgen_build.sources import expected_lock, validate_lock


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


if __name__ == "__main__":
    unittest.main()
