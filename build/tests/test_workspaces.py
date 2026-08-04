from __future__ import annotations

import unittest
import tempfile
from pathlib import Path
from unittest.mock import patch

from klibgen_build.core import BuildPaths
from klibgen_build.processes import run_command
from klibgen_build.v2state import V2Paths
from klibgen_build.workspaces import (
    _current_source_for_build,
    _initialize,
    _staging_for_workspace,
    _workspace_start_mode,
)


class WorkspaceLifecycleTest(unittest.TestCase):
    def test_initialization_accepts_a_prune_preserved_lepiter_skeleton(self):
        root_parent = Path(__file__).resolve().parents[2] / "tmp"
        root_parent.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=root_parent) as directory:
            root = Path(directory)
            paths = BuildPaths(root, root / ".klibgen")
            v2 = V2Paths.for_build(paths)
            workspace = v2.root / "workspaces/gui-default"
            page = workspace / "home/Documents/lepiter/default/page.lepiter"
            page.parent.mkdir(parents=True)
            page.write_text('{"title":"Class definition string"}')
            artifact = root / "artifact"
            (artifact / "payload/image").mkdir(parents=True)
            (artifact / "payload/image/GlamorousToolkit.image").write_bytes(b"image")
            build = {"outputKey": "a" * 64, "artifacts": [{"path": str(artifact)}]}
            source = {
                "vcs": "jj", "commitId": "fixture", "changeId": "fixture",
                "treeDigest": "a" * 64, "paths": ["src"], "exclude": [],
            }
            staging = {
                "name": "gui-default", "sourceGit": str(root / "source/.git"),
                "generation": 1,
            }

            _initialize(paths, v2, workspace, build, source, staging)

            self.assertEqual(page.read_text(), '{"title":"Class definition string"}')
            self.assertTrue((workspace / "image/GlamorousToolkit.image").is_file())
            self.assertTrue((workspace / "workspace.json").is_file())

    def test_legacy_private_repository_migrates_without_removing_it(self):
        root_parent = Path(__file__).resolve().parents[2] / "tmp"
        root_parent.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=root_parent) as directory:
            root = Path(directory)
            legacy = root / ".klibgen/v2/workspaces/gui-default/source"
            (legacy / "src/KlibGenGt-Fixture").mkdir(parents=True)
            (legacy / ".project").write_text("{}")
            source = legacy / "src/KlibGenGt-Fixture/One.class.st"
            source.write_text("base")
            run_command(["git", "init", "--quiet", "--initial-branch=master", legacy])
            run_command(["git", "-C", legacy, "add", "."])
            run_command(["git", "-C", legacy, "-c", "user.name=Test", "-c", "user.email=test@localhost", "commit", "--quiet", "-m", "base"])
            source.write_text("overlay")
            run_command(["git", "-C", legacy, "add", "."])
            run_command(["git", "-C", legacy, "-c", "user.name=Test", "-c", "user.email=test@localhost", "commit", "--quiet", "-m", "overlay"])
            paths = BuildPaths(root, root / ".klibgen")
            existing = {
                "sourceGit": str(legacy / ".git"), "baseSource": {"treeDigest": "base"},
                "projectKey": "a" * 64,
            }
            staging = _staging_for_workspace(paths, root / ".klibgen/v2/workspaces/gui-default", existing, "gui-default")
            area = root / ".klibgen/v2/staging/gui-default"
            self.assertEqual((area / "base/src/KlibGenGt-Fixture/One.class.st").read_text(), "base")
            self.assertEqual((area / "overlay/src/KlibGenGt-Fixture/One.class.st").read_text(), "overlay")
            self.assertTrue(legacy.is_dir())
            self.assertEqual(staging["lastRebase"]["migration"], "workspace-private-git")

    def test_current_source_for_reused_build_uses_current_equivalent_revision(self):
        source = {
            "vcs": "jj", "commitId": "current-commit", "changeId": "current-change",
            "treeDigest": "same-tree", "paths": ["src"], "exclude": [],
        }
        resolved = {
            "outputKey": "a" * 64,
            "steps": [{
                "role": "project-source",
                "resolvedConfiguration": {"source": source},
            }],
        }
        paths = BuildPaths(Path("/fixture"), Path("/fixture/.klibgen"))
        with patch("klibgen_build.workspaces.resolve_target", return_value=resolved):
            self.assertEqual(
                _current_source_for_build(paths, {"outputKey": "a" * 64}),
                source,
            )

    def test_current_source_rejects_a_concurrent_project_change(self):
        paths = BuildPaths(Path("/fixture"), Path("/fixture/.klibgen"))
        with patch(
            "klibgen_build.workspaces.resolve_target",
            return_value={"outputKey": "b" * 64, "steps": []},
        ):
            with self.assertRaisesRegex(RuntimeError, "project source changed"):
                _current_source_for_build(paths, {"outputKey": "a" * 64})

    def test_new_discarded_and_abnormal_workspaces_start_fresh(self):
        self.assertEqual(_workspace_start_mode(True, {"state": "ready"}), "fresh")
        for state in ("ready", "active"):
            with self.subTest(state=state):
                self.assertEqual(
                    _workspace_start_mode(
                        False,
                        {
                            "state": state,
                            "lastCompletion": {"state": "discarded"},
                        },
                    ),
                    "fresh",
                )
        self.assertEqual(
            _workspace_start_mode(
                False,
                {
                    "state": "ready",
                    "lastCompletion": {"state": "abnormal"},
                },
            ),
            "fresh",
        )

    def test_only_a_saved_workspace_resumes(self):
        self.assertEqual(
            _workspace_start_mode(
                False,
                {
                    "state": "saved",
                    "lastCompletion": {"state": "saved"},
                },
            ),
            "resumed",
        )
        self.assertEqual(
            _workspace_start_mode(
                False,
                {
                    "state": "ready",
                    "lastCompletion": {"state": "saved"},
                },
            ),
            "fresh",
        )


if __name__ == "__main__":
    unittest.main()
