from __future__ import annotations

import io
import json
import logging
import unittest
from unittest.mock import patch

from click.testing import CliRunner

from klibgen_build.cli import cli
from klibgen_build.logging_config import TRACE, configure_logging, level_number


class LoggingTest(unittest.TestCase):
    def test_configuration_defaults_to_info_and_supports_trace(self) -> None:
        stream = io.StringIO()
        logger = configure_logging(stream=stream)
        self.assertEqual(logger.level, logging.INFO)
        self.assertEqual(level_number("trace"), TRACE)
        child = logging.getLogger("klibgen_build.fixture")
        child.debug("hidden detail")
        child.info("important event")
        self.assertNotIn("hidden detail", stream.getvalue())
        self.assertIn("INFO klibgen_build.fixture: important event", stream.getvalue())

    def test_cli_level_override_keeps_json_stdout_parseable(self) -> None:
        runner = CliRunner()
        response = {"schema": "klibgen.recipe-catalog/1", "schemaVersion": 1,
                    "operation": "v2.recipe.list", "targets": []}
        with patch("klibgen_build.cli.recipes.recipe_catalog", return_value=response):
            result = runner.invoke(cli, ["--log-level", "DEBUG", "recipe", "list", "--json"])
        self.assertEqual(result.exit_code, 0, result.output)
        self.assertEqual(json.loads(result.stdout)["operation"], "v2.recipe.list")
        self.assertIn("DEBUG klibgen_build.cli.common", result.stderr)


if __name__ == "__main__":
    unittest.main()
