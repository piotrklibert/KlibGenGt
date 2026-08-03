from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from click.testing import CliRunner

from klibgen_build.cli import cli
from klibgen_build.core import BuildPaths
from klibgen_build.recipes import (
    BUILD_MAP_PRESET,
    CLI_PRESET,
    DEFAULT_TARGETS,
    PROJECT,
    Recipe,
    RecipeValidationError,
    Step,
    StepImplementation,
    Target,
)
from klibgen_build.resolution import digest_paths, git_worktree_identity, resolve_recipe


ROOT = Path(__file__).resolve().parents[2]


def implementation(identifier: str, input_type: str | None, output_type: str) -> StepImplementation:
    return StepImplementation(identifier, 1, input_type, output_type)


class RecipeModelTest(unittest.TestCase):
    def test_standard_recipe_and_targets_have_semantic_roles_and_one_project(self):
        expected = [
            "runtime", "pharo-gt", "gt-patches", "build-support",
            "project-dependencies", "project-setup", "project-source", "project-finalize",
        ]
        self.assertEqual([step.role for step in PROJECT.steps], expected)
        self.assertEqual(set(DEFAULT_TARGETS), {"cli", "agentic", "gui", "build-map"})
        self.assertTrue(all(target.recipe is PROJECT for target in DEFAULT_TARGETS.values()))

    def test_composition_returns_new_values_and_reports_precise_errors(self):
        replacement = Step(
            "pharo-gt",
            implementation("alternative-gt", "runtime-bundle", "image-workspace"),
            origin="local-replacement",
        )
        changed = PROJECT.replace("pharo-gt", replacement)
        self.assertIsNot(changed, PROJECT)
        self.assertIs(changed.steps[1], replacement)
        self.assertIsNot(PROJECT.steps[1], replacement)
        with self.assertRaisesRegex(RecipeValidationError, "unknown role 'missing'"):
            PROJECT.replace("missing", replacement)
        with self.assertRaisesRegex(RecipeValidationError, "does not match requested role"):
            PROJECT.replace("runtime", replacement)
        with self.assertRaisesRegex(RecipeValidationError, "not a publication boundary"):
            PROJECT.through("project-source")
        self.assertEqual(PROJECT.through("build-support").steps[-1].role, "build-support")
        self.assertEqual(PROJECT.drop_last(4).steps[-1].role, "build-support")

    def test_recipe_rejects_duplicate_roles_and_incompatible_adjacent_types(self):
        first = Step("first", implementation("first", None, "one"), checkpoint="artifact")
        duplicate = Step("first", implementation("duplicate", "one", "one"), checkpoint="artifact")
        with self.assertRaisesRegex(RecipeValidationError, "duplicate roles: first"):
            Recipe("bad", (first, duplicate))
        wrong = Step("second", implementation("second", "two", "three"), checkpoint="artifact")
        with self.assertRaisesRegex(RecipeValidationError, "expects input 'two', got 'one'"):
            Recipe("bad", (first, wrong))

    def test_recipe_rejects_mutable_or_non_serializable_configuration(self):
        with self.assertRaisesRegex(RecipeValidationError, "not JSON serializable"):
            Step("bad", implementation("bad", None, "thing"), {"path": Path("mutable")}, "artifact")

    def test_click_exposes_recipe_artifact_and_build_commands_at_top_level(self):
        runner = CliRunner()
        for arguments in (
            ["recipe", "list", "--help"],
            ["recipe", "resolve", "--help"],
            ["artifact", "verify", "--help"],
            ["status", "--help"],
            ["build", "--help"],
        ):
            result = runner.invoke(cli, arguments)
            self.assertEqual(result.exit_code, 0, result.output)
            self.assertTrue(result.output.strip())


class RecipeResolutionTest(unittest.TestCase):
    def setUp(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=ROOT / "tmp")
        self.root = Path(self.temporary.name)
        (self.root / "build/locks").mkdir(parents=True)
        (self.root / "build/locks/default.lock.json").write_text(json.dumps({
            "schema": "klibgen.source-lock/1", "schemaVersion": 1,
            "sources": [{
                "sourceId": "archive", "sourceType": "archive",
                "resolved": {"url": "https://example.invalid/archive.zip"},
                "integrity": {"sha256": "a" * 64},
            }],
        }))
        (self.root / "input.txt").write_text("one")
        self.paths = BuildPaths(self.root, self.root / ".klibgen")

    def tearDown(self):
        self.temporary.cleanup()

    def recipe(self, name: str = "recipe") -> Recipe:
        return Recipe(name, (
            Step(
                "runtime", StepImplementation("fixture-runtime", 1, None, "fixture", ("input.txt",)),
                {"sourceLocks": ["archive"]}, "artifact",
            ),
            Step("finish", StepImplementation("fixture-finish", 1, "fixture", "fixture"), {}, "artifact"),
        ))

    def test_names_and_presets_do_not_affect_keys(self):
        first = resolve_recipe(self.paths, Target("one", self.recipe("alpha"), CLI_PRESET))
        second = resolve_recipe(self.paths, Target("two", self.recipe("beta"), BUILD_MAP_PRESET))
        self.assertEqual(first["outputKey"], second["outputKey"])
        self.assertNotEqual(first["target"], second["target"])
        self.assertNotEqual(first["preset"], second["preset"])

    def test_declared_implementation_change_invalidates_step_and_descendants(self):
        before = resolve_recipe(self.paths, Target("one", self.recipe(), CLI_PRESET))
        (self.root / "input.txt").write_text("two")
        after = resolve_recipe(self.paths, Target("one", self.recipe(), CLI_PRESET))
        self.assertNotEqual(before["steps"][0]["stepKey"], after["steps"][0]["stepKey"])
        self.assertNotEqual(before["steps"][1]["stepKey"], after["steps"][1]["stepKey"])

    def test_replacement_preserves_upstream_key_and_invalidates_descendants(self):
        original = self.recipe()
        replacement = Step(
            "finish", StepImplementation("fixture-finish", 2, "fixture", "fixture"), {}, "artifact",
            origin="replacement",
        )
        before = resolve_recipe(self.paths, Target("one", original, CLI_PRESET))
        after = resolve_recipe(self.paths, Target("one", original.replace("finish", replacement), CLI_PRESET))
        self.assertEqual(before["steps"][0]["stepKey"], after["steps"][0]["stepKey"])
        self.assertNotEqual(before["steps"][1]["stepKey"], after["steps"][1]["stepKey"])

    def test_path_digest_is_stable_and_exclusions_are_effective(self):
        (self.root / "tree/excluded").mkdir(parents=True)
        (self.root / "tree/kept").write_text("kept")
        (self.root / "tree/excluded/value").write_text("first")
        before = digest_paths(self.root, ["tree"], ["tree/excluded"])
        (self.root / "tree/excluded/value").write_text("second")
        after = digest_paths(self.root, ["tree"], ["tree/excluded"])
        self.assertEqual(before["digest"], after["digest"])

    def test_explicit_source_paths_are_resolved_to_content_not_path_names(self):
        (self.root / "source").mkdir()
        (self.root / "source/value").write_text("one")
        recipe = Recipe("source-recipe", (
            Step(
                "source", StepImplementation("source-step", 1, None, "fixture"),
                {"sourcePaths": ["source"]}, "artifact",
            ),
        ))
        target = Target("source-target", recipe, CLI_PRESET)
        before = resolve_recipe(self.paths, target)
        (self.root / "source/value").write_text("two")
        after = resolve_recipe(self.paths, target)
        self.assertNotEqual(before["outputKey"], after["outputKey"])

    @unittest.skipUnless(subprocess.run(["git", "--version"], capture_output=True).returncode == 0, "git required")
    def test_dirty_git_identity_changes_with_effective_content(self):
        repository = self.root / "git-fixture"
        repository.mkdir()
        subprocess.run(["git", "init", "-q"], cwd=repository, check=True)
        subprocess.run(["git", "config", "user.email", "fixture@example.invalid"], cwd=repository, check=True)
        subprocess.run(["git", "config", "user.name", "Fixture"], cwd=repository, check=True)
        (repository / "tracked").write_text("base")
        subprocess.run(["git", "add", "tracked"], cwd=repository, check=True)
        subprocess.run(["git", "commit", "-qm", "base"], cwd=repository, check=True)
        (repository / "tracked").write_text("dirty-one")
        first = git_worktree_identity(repository)
        (repository / "tracked").write_text("dirty-two")
        second = git_worktree_identity(repository)
        self.assertTrue(first["dirty"])
        self.assertNotEqual(first["dirtyDigest"], second["dirtyDigest"])


if __name__ == "__main__":
    unittest.main()
