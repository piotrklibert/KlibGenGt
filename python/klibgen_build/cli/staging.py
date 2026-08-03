from __future__ import annotations

from typing import Any, Callable

import click

from . import cli
from .common import JSON_OPTION, _paths, _run
from ..core import BuildPaths
from ..staging import create_staging, list_staging, promote_staging, rebase_staging, reset_staging


@cli.group()
def staging() -> None:
    """Manage named, reviewable agentic source staging areas."""


@staging.command("list")
@JSON_OPTION
@click.pass_context
def staging_list(ctx: click.Context, as_json: bool) -> None:
    """List named staging areas and their lifecycle states."""
    _run(ctx, as_json, lambda: list_staging(_paths()))


def staging_mutation(name: str, help_text: str, service: Callable[[BuildPaths, str], dict[str, Any]]) -> None:
    @staging.command(name, help=help_text)
    @click.argument("name", metavar="NAME")
    @JSON_OPTION
    @click.pass_context
    def command(ctx: click.Context, name: str, as_json: bool) -> None:
        _run(ctx, as_json, lambda: service(_paths(), name))


staging_mutation("create", "Create a new staging area named NAME from canonical source.", create_staging)
staging_mutation("rebase", "Safely rebase staging area NAME onto canonical source.", rebase_staging)
staging_mutation("reset", "Reset staging area NAME to its recorded canonical base.", reset_staging)
staging_mutation("promote", "Promote conflict-free owned changes from staging area NAME.", promote_staging)


