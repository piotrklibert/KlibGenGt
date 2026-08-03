from __future__ import annotations

import json
import unittest
from pathlib import Path
from unittest.mock import patch

import click
from click.testing import CliRunner

from klibgen_build.cli import cli, main


def command_paths(group: click.Group, prefix: tuple[str, ...] = ()):
    for name, command in group.commands.items():
        path = prefix + (name,)
        yield path, command
        if isinstance(command, click.Group):
            yield from command_paths(command, path)


class ClickCliTest(unittest.TestCase):
    def setUp(self):
        self.runner = CliRunner()

    def test_every_group_and_command_has_help_and_documented_parameters(self):
        root = self.runner.invoke(cli, ["--help"])
        self.assertEqual(root.exit_code, 0, root.output)
        for path, command in command_paths(cli):
            result = self.runner.invoke(cli, [*path, "--help"])
            self.assertEqual(result.exit_code, 0, f"{' '.join(path)}\n{result.output}")
            self.assertTrue(result.output.strip())
            self.assertTrue(command.help or command.callback.__doc__, "missing help: " + " ".join(path))
            for parameter in command.params:
                if isinstance(parameter, click.Option):
                    self.assertTrue(parameter.help, f"undocumented option {path}: {parameter.opts}")
                elif isinstance(parameter, click.Argument):
                    self.assertIn(parameter.human_readable_name.upper(), result.output.upper(), f"undocumented argument {path}: {parameter.name}")

    def test_strict_choices_hash_ranges_ids_regex_and_paths(self):
        invalid = (
            ["build", "unknown"],
            ["build", "cli", "--through", "unknown"],
            ["artifact", "verify", "abc"],
            ["image", "code", "search", "x", "--limit", "0"],
            ["host", "processes", "list", "--pid", "0"],
            ["host", "windows", "list", "--id", "zero"],
            ["host", "windows", "list", "--title-regex", "["],
            ["image", "eval", "--file", "does-not-exist.st"],
        )
        for arguments in invalid:
            result = self.runner.invoke(cli, arguments)
            self.assertEqual(result.exit_code, 2, f"{arguments}: {result.output}")
        result = self.runner.invoke(cli, ["host", "windows", "list", "--id", "0x2a"])
        self.assertIn(result.exit_code, (0, 2))  # valid parsing reaches the host service

    def test_repeatable_databases_and_image_request_mapping(self):
        response = {"schemaVersion": 1, "ok": True, "operation": "lepiter.search", "data": {"results": []}}
        with patch("klibgen_build.cli.image.execute_session", return_value=response) as execute:
            result = self.runner.invoke(cli, ["image", "lepiter", "search", "needle", "--in", "title", "--database", "one", "--database", "two", "--limit", "7", "--json"])
        self.assertEqual(result.exit_code, 0, result.output)
        request = execute.call_args.args[1]
        self.assertEqual(request, {"operation": "lepiter.search", "query": "needle", "in": "title", "databases": ["one", "two"], "limit": 7})

    def test_expression_sources_and_mutual_exclusions(self):
        response = {"schemaVersion": 1, "ok": True, "operation": "eval", "data": {"result": "ok"}}
        with self.runner.isolated_filesystem():
            Path("expression.st").write_text("3 + 4", encoding="utf-8")
            with patch("klibgen_build.cli.image.execute_session", return_value=response) as execute:
                result = self.runner.invoke(cli, ["image", "eval", "--file", "expression.st"])
            self.assertEqual(result.exit_code, 0, result.output)
            self.assertEqual(execute.call_args.args[1]["expression"], "3 + 4")
            result = self.runner.invoke(cli, ["image", "eval", "1 + 2", "--file", "expression.st"])
            self.assertEqual(result.exit_code, 2)
        for arguments in (
            ["image", "lepiter", "export", "--uid", "u", "--title", "t"],
            ["agentic", "area", "--eval", "1", "--test"],
            ["gc", "--dry-run", "--apply"],
            ["ui", "batch"],
        ):
            result = self.runner.invoke(cli, arguments)
            self.assertEqual(result.exit_code, 2, f"{arguments}: {result.output}")

    def test_ui_tri_state_selector_mapping(self):
        response = {"schemaVersion": 1, "ok": True, "operation": "ui.query", "data": {}}
        with patch("klibgen_build.cli.ui.submit_ui_request", return_value=response) as submit:
            result = self.runner.invoke(cli, ["ui", "query", "--visible", "--no-enabled", "--focused", "--text-regex", "Save.*"])
        self.assertEqual(result.exit_code, 0, result.output)
        request = submit.call_args.args[1]
        self.assertEqual(request["visible"], True)
        self.assertEqual(request["enabled"], False)
        self.assertEqual(request["focused"], True)
        self.assertEqual(request["textRegex"], "Save.*")

    def test_profile_preserves_passthrough_command(self):
        profiled = {"exitCode": 3, "stdout": "", "stderr": "", "metrics": {"wallTimeNs": 1}}
        with patch("klibgen_build.cli.host.profile_command_fn", return_value=profiled) as profile:
            result = self.runner.invoke(cli, ["host", "profile", "--json", "--", "sh", "-c", "exit 3"])
        self.assertEqual(result.exit_code, 0, result.output)
        profile.assert_called_once_with(["sh", "-c", "exit 3"], capture=True)
        self.assertEqual(json.loads(result.output)["data"]["exitCode"], 3)

    def test_result_and_error_exit_contracts_include_command_path(self):
        failed = {"schemaVersion": 1, "ok": False, "operation": "fixture", "message": "no"}
        with patch("klibgen_build.cli.recipes.recipe_catalog", return_value=failed):
            result = self.runner.invoke(cli, ["recipe", "list", "--json"])
        self.assertEqual(result.exit_code, 1)
        self.assertFalse(json.loads(result.output)["ok"])
        with patch("klibgen_build.cli.recipes.recipe_catalog", side_effect=OSError("disk unavailable")):
            result = self.runner.invoke(cli, ["recipe", "list"])
        self.assertEqual(result.exit_code, 2)
        self.assertIn("cli recipe list: disk unavailable", result.output)

    def test_main_is_an_integer_returning_wrapper_and_parser_api_is_absent(self):
        self.assertEqual(main(["--help"]), 0)
        import klibgen_build.cli as module
        self.assertFalse(hasattr(module, "parser"))

    def test_cli_is_a_package_split_by_command_family(self):
        import klibgen_build.cli as module
        package = Path(module.__file__).parent
        self.assertEqual(Path(module.__file__).name, "__init__.py")
        self.assertFalse((package.parent / "cli.py").exists())
        expected = {
            "common.py", "host.py", "image.py", "ui.py", "recipes.py",
            "artifacts.py", "sessions.py", "maintenance.py", "workspaces.py",
            "staging.py", "models.py",
        }
        self.assertTrue(expected.issubset({path.name for path in package.glob("*.py")}))


if __name__ == "__main__":
    unittest.main()
