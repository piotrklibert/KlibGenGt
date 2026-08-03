from __future__ import annotations

import json
import unittest
from pathlib import Path
from unittest.mock import patch

from click.testing import CliRunner

from klibgen_build.cli import cli
from klibgen_build.json_models import RefactoringRequestV1


class RefactoringCliTest(unittest.TestCase):
    def setUp(self):
        self.runner = CliRunner()
        self.response = {
            "schemaVersion": 1,
            "ok": True,
            "operation": "refactor.preview",
            "data": {"planId": "sha256:plan"},
        }

    def test_named_request_schema_preserves_extensible_adapter_fields(self):
        request = RefactoringRequestV1.model_validate({
            "schema": "klibgen.refactoring-request/1",
            "refactoring": "class.rename",
            "arguments": {"class": "Old", "newName": "New"},
            "adapterExtension": True,
        })
        self.assertEqual(request.to_wire()["adapterExtension"], True)
        self.assertEqual(request.schema_version, 1)

    def test_preview_maps_json_file_to_agentic_operation(self):
        with self.runner.isolated_filesystem():
            Path("request.json").write_text(json.dumps({
                "schema": "klibgen.refactoring-request/1",
                "refactoring": "class.rename",
                "arguments": {"class": "Old", "newName": "New"},
            }), encoding="utf-8")
            with patch("klibgen_build.cli.refactoring.execute_agentic_session",
                       return_value=self.response) as execute:
                result = self.runner.invoke(cli, [
                    "refactor", "preview", "work", "--file", "request.json", "--json",
                ])
        self.assertEqual(result.exit_code, 0, result.output)
        self.assertEqual(execute.call_args.args[1], "work")
        self.assertEqual(execute.call_args.args[2]["operation"], "refactor.preview")

    def test_apply_requires_and_maps_expected_plan(self):
        with self.runner.isolated_filesystem():
            Path("request.json").write_text(json.dumps({
                "schema": "klibgen.refactoring-request/1",
                "refactoring": "method.rename", "arguments": {},
            }), encoding="utf-8")
            missing = self.runner.invoke(cli, [
                "refactor", "apply", "work", "--file", "request.json",
            ])
            self.assertEqual(missing.exit_code, 2)
            with patch("klibgen_build.cli.refactoring.execute_agentic_session",
                       return_value=self.response) as execute:
                result = self.runner.invoke(cli, [
                    "refactor", "apply", "work", "--file", "request.json",
                    "--expect", "sha256:plan", "--json",
                ])
        self.assertEqual(result.exit_code, 0, result.output)
        request = execute.call_args.args[2]
        self.assertEqual(request["operation"], "refactor.apply")
        self.assertEqual(request["expect"], "sha256:plan")

    def test_request_source_is_exactly_one_file_or_stdin(self):
        missing = self.runner.invoke(cli, ["refactor", "preview", "work"])
        self.assertEqual(missing.exit_code, 2)
        with self.runner.isolated_filesystem():
            Path("request.json").write_text(
                '{"schema":"klibgen.refactoring-request/1"}', encoding="utf-8",
            )
            both = self.runner.invoke(
                cli,
                ["refactor", "preview", "work", "--file", "request.json", "--stdin"],
                input="{}",
            )
        self.assertEqual(both.exit_code, 2)


if __name__ == "__main__":
    unittest.main()
