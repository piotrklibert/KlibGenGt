from __future__ import annotations

import json
import tempfile
import threading
import unittest
from pathlib import Path

from klibgen_build.builder import build_resolved
from klibgen_build.core import BuildPaths
from klibgen_build.recipes import CLI_PRESET, Recipe, Step, StepImplementation, Target
from klibgen_build.resolution import resolve_recipe
from klibgen_build.store import ArtifactStore

ROOT = Path(__file__).resolve().parents[2]


class V2StoreTest(unittest.TestCase):
    def setUp(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=ROOT / "tmp")
        root = Path(self.temp.name)
        (root / "build/locks").mkdir(parents=True)
        (root / "build/locks/default.lock.json").write_text(json.dumps({
            "schema": "klibgen.source-lock/1", "schemaVersion": 1, "sources": [],
        }))
        self.paths = BuildPaths(root, root / ".klibgen")
        recipe = Recipe("fixture", (Step("fixture", StepImplementation("fixture-step", 1, None, "fixture-artifact"), checkpoint="artifact"),))
        self.resolved = resolve_recipe(self.paths, Target("fixture", recipe, CLI_PRESET))

    def tearDown(self):
        self.temp.cleanup()

    def test_build_publishes_verifies_and_reuses_one_global_artifact(self):
        calls = []
        def execute(step, payload):
            calls.append(step["role"])
            (payload / "value").write_text("complete")
        first = build_resolved(self.paths, self.resolved, execute)
        second = build_resolved(self.paths, self.resolved, execute)
        self.assertEqual(calls, ["fixture"])
        self.assertFalse(first["artifacts"][0]["reused"])
        self.assertTrue(second["artifacts"][0]["reused"])
        self.assertEqual(len(ArtifactStore(self.paths).artifacts()), 1)

    def test_failure_retains_status_but_removes_partial_workspace(self):
        def fail(step, payload):
            (payload / "partial.image").write_text("partial")
            (payload.parent / "logs").mkdir()
            (payload.parent / "logs/failure.log").write_text("diagnostic")
            raise RuntimeError("fixture failure")
        with self.assertRaisesRegex(RuntimeError, "fixture failure"):
            build_resolved(self.paths, self.resolved, fail)
        store = ArtifactStore(self.paths)
        status = json.loads((store.v2.root / "status" / f"{self.resolved['outputKey']}.json").read_text())
        self.assertEqual(status["state"], "failed")
        self.assertEqual((Path(status["diagnosticPath"]) / "logs/failure.log").read_text(), "diagnostic")
        self.assertEqual(list((store.v2.root / "tmp").iterdir()), [])
        self.assertEqual(store.artifacts(), [])

    def test_concurrent_builders_wait_and_reuse_the_single_publication(self):
        calls = []
        entered = threading.Event()
        release = threading.Event()
        results = []

        def execute(step, payload):
            calls.append(step["role"])
            entered.set()
            release.wait(timeout=5)
            (payload / "complete").write_text("one publication")

        def build():
            results.append(build_resolved(self.paths, self.resolved, execute))

        first = threading.Thread(target=build)
        second = threading.Thread(target=build)
        first.start()
        self.assertTrue(entered.wait(timeout=5))
        second.start()
        release.set()
        first.join(timeout=5)
        second.join(timeout=5)
        self.assertEqual(calls, ["fixture"])
        self.assertEqual(sorted(item["artifacts"][0]["reused"] for item in results), [False, True])
        artifact = Path(results[0]["artifacts"][0]["path"])
        self.assertFalse(bool((artifact / "payload/complete").stat().st_mode & 0o222))


if __name__ == "__main__":
    unittest.main()
