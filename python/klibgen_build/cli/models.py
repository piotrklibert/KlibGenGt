from __future__ import annotations

from pathlib import Path

import click

from . import cli
from .common import ERRORS, _paths
from ..tonel_export import DEFAULT_PACKAGE, export_tonel


@cli.group()
def models() -> None:
    """Generate or check source representations of public JSON models."""


@models.command("export-tonel")
@click.option("--output", type=click.Path(path_type=Path, file_okay=False), metavar="DIRECTORY", help="Tonel package output directory.")
@click.option("--check", is_flag=True, help="Report stale generated files without writing them.")
@click.pass_context
def models_export_tonel(ctx: click.Context, output: Path | None, check: bool) -> None:
    """Generate Tonel JSON models, or verify tracked output with --check."""
    try:
        paths = _paths()
        target = output or paths.root / "src" / DEFAULT_PACKAGE
        if not target.is_absolute():
            target = paths.root / target
        drift = export_tonel(target, check=check)
        if check and drift:
            click.echo("generated Tonel models are stale: " + ", ".join(drift), err=True)
            ctx.exit(1)
        if check:
            click.echo(f"generated Tonel models are current ({target})")
        else:
            click.echo(f"generated Tonel JSON models in {target}")
    except click.exceptions.Exit:
        raise
    except ERRORS as error:
        click.echo(f"{ctx.command_path}: {error}", err=True)
        ctx.exit(2)


