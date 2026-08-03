from __future__ import annotations

import click

from . import cli
from .common import JSON_OPTION, ROLE, TARGET, _paths, _run
from ..resolution import recipe_catalog, resolve_target


@cli.group()
def recipe() -> None:
    """List build recipes or resolve a target without building it."""


@recipe.command("list")
@JSON_OPTION
@click.pass_context
def recipe_list(ctx: click.Context, as_json: bool) -> None:
    """List all committed build targets, recipes, and roles."""
    _run(ctx, as_json, recipe_catalog)


@recipe.command("resolve")
@click.argument("target", type=TARGET)
@click.option("--through", type=ROLE, help="Stop resolution after this publication role.")
@JSON_OPTION
@click.pass_context
def recipe_resolve(ctx: click.Context, target: str, through: str | None, as_json: bool) -> None:
    """Resolve TARGET and print its content keys without publishing artifacts."""
    _run(ctx, as_json, lambda: resolve_target(_paths(), target, through))



