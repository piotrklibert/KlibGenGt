from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

import click

from . import cli
from .common import JSON_OPTION, _paths, _run
from ..json_models import RefactoringRequestV1
from ..sessions import execute_agentic_session, execute_session


@cli.group()
def refactor() -> None:
    """Discover, preview, and apply structured Pharo refactorings."""


def _request(file: Path | None, stdin: bool) -> dict[str, Any]:
    if (file is None) == (not stdin):
        raise ValueError("provide exactly one --file or --stdin")
    text = file.read_text(encoding="utf-8") if file is not None else sys.stdin.read()
    value = json.loads(text)
    if not isinstance(value, dict):
        raise ValueError("refactoring request must be a JSON object")
    return RefactoringRequestV1.model_validate(value).to_wire()


def request_options(function):
    function = click.option(
        "--file", type=click.Path(path_type=Path, exists=True, file_okay=True,
                                  dir_okay=False, readable=True),
        help="Read the JSON refactoring request from this file.",
    )(function)
    function = click.option(
        "--stdin", is_flag=True, help="Read the JSON refactoring request from standard input.",
    )(function)
    return function


@refactor.command("catalog")
@JSON_OPTION
@click.pass_context
def refactor_catalog(ctx: click.Context, as_json: bool) -> None:
    """List supported adapters and observed image refactoring classes."""
    _run(ctx, as_json, lambda: execute_session(_paths(), {"operation": "refactor.catalog"}))


@refactor.command("describe")
@click.argument("refactoring_id", metavar="ID")
@JSON_OPTION
@click.pass_context
def refactor_describe(ctx: click.Context, refactoring_id: str, as_json: bool) -> None:
    """Describe the request contract for stable refactoring ID."""
    _run(ctx, as_json, lambda: execute_session(
        _paths(), {"operation": "refactor.describe", "refactoring": refactoring_id},
    ))


def staged_request(operation: str, name: str, file: Path | None, stdin: bool,
                   expect: str | None = None) -> dict[str, Any]:
    request = _request(file, stdin)
    request["operation"] = operation
    if expect is not None:
        request["expect"] = expect
    return execute_agentic_session(_paths(), name, request)


@refactor.command("applicable")
@click.argument("name", metavar="NAME")
@request_options
@JSON_OPTION
@click.pass_context
def refactor_applicable(ctx: click.Context, name: str, file: Path | None,
                        stdin: bool, as_json: bool) -> None:
    """Report candidate refactorings for a target in staging area NAME."""
    _run(ctx, as_json, lambda: staged_request("refactor.applicable", name, file, stdin))


@refactor.command("preview")
@click.argument("name", metavar="NAME")
@request_options
@JSON_OPTION
@click.pass_context
def refactor_preview(ctx: click.Context, name: str, file: Path | None,
                     stdin: bool, as_json: bool) -> None:
    """Preview exact semantic and Tonel changes in staging area NAME."""
    _run(ctx, as_json, lambda: staged_request("refactor.preview", name, file, stdin))


@refactor.command("apply")
@click.argument("name", metavar="NAME")
@request_options
@click.option("--expect", required=True, metavar="PLAN_ID",
              help="Require this exact plan identifier before exporting changes.")
@JSON_OPTION
@click.pass_context
def refactor_apply(ctx: click.Context, name: str, file: Path | None, stdin: bool,
                   expect: str, as_json: bool) -> None:
    """Apply an exactly previewed plan and export it to staging area NAME."""
    _run(ctx, as_json, lambda: staged_request(
        "refactor.apply", name, file, stdin, expect=expect,
    ))


__all__ = ["refactor", "staged_request"]
