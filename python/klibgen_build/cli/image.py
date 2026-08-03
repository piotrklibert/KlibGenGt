from __future__ import annotations

from pathlib import Path
from typing import Any

import click

from . import cli
from .common import JSON_OPTION, POSITIVE_INT, _expression, _paths, _run, source_options
from ..sessions import execute_session


@cli.group()
def image() -> None:
    """Run structured code, Lepiter, and evaluation tools in a fresh image."""


@image.group()
def code() -> None:
    """Search or retrieve source loaded in a fresh image."""


@code.command("search")
@click.argument("query")
@click.option("--kind", type=click.Choice(("all", "class", "method")), default="all", show_default=True, help="Limit the kind of code result.")
@click.option("--package", "package_name", metavar="PACKAGE", help="Limit results to this package.")
@click.option("--limit", type=POSITIVE_INT, default=100, show_default=True, help="Maximum number of results.")
@JSON_OPTION
@click.pass_context
def code_search(ctx: click.Context, query: str, kind: str, package_name: str | None, limit: int, as_json: bool) -> None:
    """Search loaded source for QUERY and return matching classes or methods."""
    request: dict[str, Any] = {"operation": "code.search", "query": query, "kind": kind, "limit": limit}
    if package_name is not None:
        request["package"] = package_name
    _run(ctx, as_json, lambda: execute_session(_paths(), request))


@code.command("class")
@click.argument("class_name", metavar="CLASS_NAME")
@JSON_OPTION
@click.pass_context
def code_class(ctx: click.Context, class_name: str, as_json: bool) -> None:
    """Print the definition of CLASS_NAME from a fresh image."""
    _run(ctx, as_json, lambda: execute_session(_paths(), {"operation": "code.class", "class": class_name}))


@code.command("method")
@click.argument("class_name", metavar="CLASS_NAME")
@click.argument("selector", metavar="SELECTOR")
@click.option("--side", type=click.Choice(("instance", "class")), default="instance", show_default=True, help="Choose the instance or class method side.")
@JSON_OPTION
@click.pass_context
def code_method(ctx: click.Context, class_name: str, selector: str, side: str, as_json: bool) -> None:
    """Print SELECTOR from CLASS_NAME on the selected method side."""
    _run(ctx, as_json, lambda: execute_session(_paths(), {"operation": "code.method", "class": class_name, "selector": selector, "side": side}))


@image.group()
def lepiter() -> None:
    """Search or export Lepiter pages loaded in a fresh image."""


@lepiter.command("search")
@click.argument("query")
@click.option("--in", "search_in", type=click.Choice(("text", "title")), default="text", show_default=True, help="Search page text or titles.")
@click.option("--database", "databases", multiple=True, metavar="DATABASE", help="Limit search to a database; repeat for more than one.")
@click.option("--limit", type=POSITIVE_INT, default=100, show_default=True, help="Maximum number of results.")
@JSON_OPTION
@click.pass_context
def lepiter_search(ctx: click.Context, query: str, search_in: str, databases: tuple[str, ...], limit: int, as_json: bool) -> None:
    """Search loaded Lepiter pages for QUERY."""
    request = {"operation": "lepiter.search", "query": query, "in": search_in, "databases": list(databases), "limit": limit}
    _run(ctx, as_json, lambda: execute_session(_paths(), request))


@lepiter.command("export")
@click.option("--uid", help="Export the page with this UID (exclusive with --title).")
@click.option("--title", help="Export the uniquely titled page (exclusive with --uid).")
@click.option("--database", "databases", multiple=True, metavar="DATABASE", help="Limit lookup to a database; repeat for more than one.")
@JSON_OPTION
@click.pass_context
def lepiter_export(ctx: click.Context, uid: str | None, title: str | None, databases: tuple[str, ...], as_json: bool) -> None:
    """Export one page selected by exactly one of --uid or --title."""
    def operation() -> dict[str, Any]:
        if (uid is None) == (title is None):
            raise ValueError("provide exactly one --uid or --title")
        request: dict[str, Any] = {"operation": "lepiter.export", "databases": list(databases), "uid" if uid is not None else "title": uid if uid is not None else title}
        return execute_session(_paths(), request)
    _run(ctx, as_json, operation)
@image.command("eval")
@click.argument("expression", required=False)
@source_options
@click.option("--profile", is_flag=True, help="Collect image-side evaluation profile metrics.")
@JSON_OPTION
@click.pass_context
def image_eval(ctx: click.Context, expression: str | None, file: Path | None, stdin: bool, profile: bool, as_json: bool) -> None:
    """Evaluate EXPRESSION, --file, or --stdin in a fresh image."""
    _run(ctx, as_json, lambda: execute_session(_paths(), {"operation": "eval", "expression": _expression(expression, file, stdin), "profile": profile}))


