from __future__ import annotations

import click

from . import cli
from .common import JSON_OPTION, _paths, _run
from ..workspaces import reset_workspace, workspace_status


@cli.group()
def workspace() -> None:
    """Inspect or explicitly reset the single named GUI workspace."""


@workspace.command("status")
@JSON_OPTION
@click.pass_context
def workspace_status_command(ctx: click.Context, as_json: bool) -> None:
    """Report saved workspace state and provenance without changing it."""
    _run(ctx, as_json, lambda: workspace_status(_paths()))


@workspace.command("reset")
@click.option("--confirm", is_flag=True, help="Confirm destructive replacement of the saved workspace.")
@JSON_OPTION
@click.pass_context
def workspace_reset(ctx: click.Context, confirm: bool, as_json: bool) -> None:
    """Reset the saved GUI workspace; requires explicit --confirm."""
    _run(ctx, as_json, lambda: reset_workspace(_paths(), confirm))



