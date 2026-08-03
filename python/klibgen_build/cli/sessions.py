from __future__ import annotations

from pathlib import Path
from typing import Any

import click

from . import cli
from .common import JSON_OPTION, ROLE, TARGET, _expression, _paths, _run
from ..canonical import build_canonical
from ..sessions import execute_agentic_session, execute_session
from ..tonel_lint import lint_authoritative_source
from ..workspaces import launch_gui_workspace


@cli.command("build")
@click.argument("target", type=TARGET, default="cli", required=False)
@click.option("--through", type=ROLE, help="Build only through this publication role.")
@JSON_OPTION
@click.pass_context
def build(ctx: click.Context, target: str, through: str | None, as_json: bool) -> None:
    """Build TARGET (default: cli), publishing verified immutable artifacts."""
    _run(ctx, as_json, lambda: build_canonical(_paths(), target, through))


@cli.command("test")
@click.option("--fresh", is_flag=True, help="Explicitly request a fresh disposable test session.")
@JSON_OPTION
@click.pass_context
def test(ctx: click.Context, fresh: bool, as_json: bool) -> None:
    """Run the complete Smalltalk suite in a disposable project session."""
    def operation() -> dict[str, Any]:
        result = execute_session(_paths(), {"operation": "test.all"})
        result["operation"] = "test"
        return result
    _run(ctx, as_json, operation)


@cli.command("test-one")
@click.argument("test_class", metavar="TEST_CLASS")
@click.argument("selector", metavar="SELECTOR")
@JSON_OPTION
@click.pass_context
def test_one(ctx: click.Context, test_class: str, selector: str, as_json: bool) -> None:
    """Run SELECTOR from TEST_CLASS in a disposable project session."""
    def operation() -> dict[str, Any]:
        result = execute_session(_paths(), {"operation": "test.run", "class": test_class, "selector": selector})
        result["operation"] = "test-one"
        return result
    _run(ctx, as_json, operation)


@cli.command("eval")
@click.argument("expression", required=False)
@click.option("--file", type=click.Path(path_type=Path, exists=True, file_okay=True, dir_okay=False, readable=True), help="Read the expression from this file.")
@click.option("--stdin", is_flag=True, help="Read the expression from standard input.")
@click.option("--profile", is_flag=True, help="Collect image-side evaluation profile metrics.")
@JSON_OPTION
@click.pass_context
def evaluate(ctx: click.Context, expression: str | None, file: Path | None, stdin: bool, profile: bool, as_json: bool) -> None:
    """Evaluate EXPRESSION, --file, --stdin, or GT_EVAL in a fresh image."""
    def operation() -> dict[str, Any]:
        result = execute_session(_paths(), {"operation": "eval", "expression": _expression(expression, file, stdin, allow_environment=True), "profile": profile})
        result["operation"] = "eval"
        return result
    _run(ctx, as_json, operation)


def session_command(name: str, help_text: str, request: dict[str, Any], result_operation: str) -> None:
    @cli.command(name, help=help_text)
    @JSON_OPTION
    @click.pass_context
    def command(ctx: click.Context, as_json: bool) -> None:
        def operation() -> dict[str, Any]:
            result = execute_session(_paths(), request)
            result["operation"] = result_operation
            return result
        _run(ctx, as_json, operation)


@cli.command("load")
@JSON_OPTION
@click.pass_context
def load(ctx: click.Context, as_json: bool) -> None:
    """Build the canonical CLI target and label the result as a load operation."""
    _run(ctx, as_json, lambda: build_canonical(_paths(), "cli") | {"operation": "load"})


@cli.command("lint-source")
@JSON_OPTION
@click.pass_context
def lint_source(ctx: click.Context, as_json: bool) -> None:
    """Reject `.st` source that the pinned Tonel exporter would rewrite."""
    _run(ctx, as_json, lambda: lint_authoritative_source(_paths()))


session_command("smoke", "Check that the project loads and answers its name in a fresh image.", {"operation": "eval", "expression": "KlibGenGt projectName", "profile": False}, "smoke")
session_command("check-type-pragmas", "Validate all project documentation type pragmas in a fresh image.", {"operation": "test.run", "class": "KGCheckTypePragmasTest", "selector": "testProjectTypeAnnotationsAreValid"}, "check-type-pragmas")


@cli.command("gui")
@click.option("--fresh", is_flag=True, help="Replace the saved GUI workspace from the current canonical artifact.")
@click.option("--staging", "staging_name", default="gui-default", show_default=True, help="Attach the GUI to named source staging area NAME.")
@click.pass_context
def gui(ctx: click.Context, fresh: bool, staging_name: str) -> None:
    """Resume the single saved GUI workspace, or initialize it when absent."""
    def operation() -> dict[str, Any]:
        exit_code = launch_gui_workspace(_paths(), fresh, staging_name)
        return {"operation": "gui", "ok": exit_code == 0, "exitCode": exit_code}
    _run(ctx, False, operation)


@cli.command("agentic")
@click.argument("name", metavar="NAME")
@click.option("--eval", "expression", help="Evaluate this expression in staging area NAME.")
@click.option("--test", is_flag=True, help="Run the complete test suite in staging area NAME.")
@JSON_OPTION
@click.pass_context
def agentic(ctx: click.Context, name: str, expression: str | None, test: bool, as_json: bool) -> None:
    """Run tests by default, or --eval, in named staging area NAME."""
    def operation() -> dict[str, Any]:
        if expression is not None and test:
            raise ValueError("--eval and --test are mutually exclusive")
        request = {"operation": "eval", "expression": expression, "profile": False} if expression is not None else {"operation": "test.all"}
        result = execute_agentic_session(_paths(), name, request)
        result["operation"] = "agentic"
        return result
    _run(ctx, as_json, operation)
