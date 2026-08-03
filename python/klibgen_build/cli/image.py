from __future__ import annotations

from pathlib import Path
from typing import Any

import click

from . import cli
from .common import JSON_OPTION, POSITIVE_INT, _expression, _paths, _run, source_options
from ..sessions import execute_session


PACKAGE_SET_NAMES = (
    "default", "project", "direct", "transitive", "gt-framework",
    "pharo-core", "tests", "all",
)


def scope_options(function):
    """Add the common package-universe options to one code command."""
    function = click.option(
        "--exclude-package", "exclude_packages", multiple=True, metavar="PACKAGE",
        help="Exclude a package from the selected universe; repeat or comma-separate.",
    )(function)
    function = click.option(
        "--include-package", "include_packages", multiple=True, metavar="PACKAGE",
        help="Include a package in the selected universe; repeat or comma-separate.",
    )(function)
    function = click.option(
        "--package-set", type=click.Choice(PACKAGE_SET_NAMES),
        help="Select a named loaded-package universe.",
    )(function)
    return function


def _split_package_names(values: tuple[str, ...]) -> list[str]:
    return sorted({name.strip() for value in values for name in value.split(",") if name.strip()})


def _scope_request(
    package_set: str | None,
    include_packages: tuple[str, ...],
    exclude_packages: tuple[str, ...],
    package_name: str | None = None,
) -> dict[str, Any]:
    request: dict[str, Any] = {
        "includePackages": _split_package_names(include_packages),
        "excludePackages": _split_package_names(exclude_packages),
    }
    if package_set is not None:
        request["packageSet"] = package_set
    if package_name is not None:
        if package_set is not None or request["includePackages"] or request["excludePackages"]:
            raise click.UsageError(
                "--package cannot be combined with --package-set, "
                "--include-package, or --exclude-package"
            )
        request["package"] = package_name
    return request


@cli.group()
def image() -> None:
    """Run structured code, Lepiter, and evaluation tools in a fresh image."""


@image.group()
def code() -> None:
    """Search or retrieve source loaded in a fresh image."""


@code.command("search")
@click.argument("query")
@click.option("--kind", type=click.Choice(("all", "class", "method")), default="all", show_default=True, help="Limit the kind of code result.")
@click.option("--in", "search_in", type=click.Choice(("auto", "class-name", "selector", "source")), default="auto", show_default=True, help="Choose the searched code field.")
@click.option("--match", type=click.Choice(("substring", "exact", "regex")), default="substring", show_default=True, help="Choose the matching mode.")
@click.option("--package", "package_name", metavar="PACKAGE", help="Deprecated exact single-package scope.")
@click.option("--limit", type=POSITIVE_INT, default=100, show_default=True, help="Maximum number of results.")
@scope_options
@JSON_OPTION
@click.pass_context
def code_search(
    ctx: click.Context, query: str, kind: str, search_in: str, match: str,
    package_name: str | None, limit: int, package_set: str | None,
    include_packages: tuple[str, ...], exclude_packages: tuple[str, ...], as_json: bool,
) -> None:
    """Search loaded source for QUERY and return matching classes or methods."""
    request: dict[str, Any] = {
        "operation": "code.search", "query": query, "kind": kind,
        "in": search_in, "match": match, "limit": limit,
    } | _scope_request(package_set, include_packages, exclude_packages, package_name)
    _run(ctx, as_json, lambda: execute_session(_paths(), request))


@code.command("class")
@click.argument("class_name", metavar="CLASS_NAME")
@scope_options
@JSON_OPTION
@click.pass_context
def code_class(
    ctx: click.Context, class_name: str, package_set: str | None,
    include_packages: tuple[str, ...], exclude_packages: tuple[str, ...], as_json: bool,
) -> None:
    """Print the definition of CLASS_NAME from a fresh image."""
    request = {"operation": "code.class", "class": class_name} | _scope_request(
        package_set, include_packages, exclude_packages
    )
    _run(ctx, as_json, lambda: execute_session(_paths(), request))


@code.command("method")
@click.argument("class_name", metavar="CLASS_NAME")
@click.argument("selector", metavar="SELECTOR")
@click.option("--side", type=click.Choice(("instance", "class")), default="instance", show_default=True, help="Choose the instance or class method side.")
@scope_options
@JSON_OPTION
@click.pass_context
def code_method(
    ctx: click.Context, class_name: str, selector: str, side: str,
    package_set: str | None, include_packages: tuple[str, ...],
    exclude_packages: tuple[str, ...], as_json: bool,
) -> None:
    """Print SELECTOR from CLASS_NAME on the selected method side."""
    request = {
        "operation": "code.method", "class": class_name, "selector": selector, "side": side,
    } | _scope_request(package_set, include_packages, exclude_packages)
    _run(ctx, as_json, lambda: execute_session(_paths(), request))


@code.command("class-methods")
@click.argument("class_name", metavar="CLASS_NAME")
@click.option("--side", type=click.Choice(("both", "instance", "class")), default="both", show_default=True, help="Choose instance, class, or both method sides.")
@click.option("--protocol", help="Limit methods to an exact protocol name.")
@click.option("--include-inherited", is_flag=True, help="Include methods inherited from in-scope superclasses.")
@click.option("--include-extensions", is_flag=True, help="Include extension methods owned by in-scope packages.")
@click.option("--include-traits", is_flag=True, help="Include methods supplied by in-scope traits.")
@click.option("--limit", type=POSITIVE_INT, default=500, show_default=True, help="Maximum number of method records.")
@scope_options
@JSON_OPTION
@click.pass_context
def code_class_methods(
    ctx: click.Context, class_name: str, side: str, protocol: str | None,
    include_inherited: bool, include_extensions: bool, include_traits: bool, limit: int,
    package_set: str | None, include_packages: tuple[str, ...],
    exclude_packages: tuple[str, ...], as_json: bool,
) -> None:
    """Dump normalized methods of CLASS_NAME and optionally related methods."""
    request: dict[str, Any] = {
        "operation": "code.class-methods", "class": class_name, "side": side,
        "includeInherited": include_inherited, "includeExtensions": include_extensions,
        "includeTraits": include_traits, "limit": limit,
    } | _scope_request(package_set, include_packages, exclude_packages)
    if protocol is not None:
        request["protocol"] = protocol
    _run(ctx, as_json, lambda: execute_session(_paths(), request))


@code.command("class-info")
@click.argument("class_name", metavar="CLASS_NAME")
@scope_options
@JSON_OPTION
@click.pass_context
def code_class_info(
    ctx: click.Context, class_name: str, package_set: str | None,
    include_packages: tuple[str, ...], exclude_packages: tuple[str, ...], as_json: bool,
) -> None:
    """Describe one loaded class, including hierarchy and local state."""
    request = {"operation": "code.class-info", "class": class_name} | _scope_request(
        package_set, include_packages, exclude_packages
    )
    _run(ctx, as_json, lambda: execute_session(_paths(), request))


@code.command("package-info")
@click.argument("package_name", metavar="PACKAGE")
@scope_options
@JSON_OPTION
@click.pass_context
def code_package_info(
    ctx: click.Context, package_name: str, package_set: str | None,
    include_packages: tuple[str, ...], exclude_packages: tuple[str, ...], as_json: bool,
) -> None:
    """Describe one loaded package and its dependency relationships."""
    request = {"operation": "code.package-info", "packageName": package_name} | _scope_request(
        package_set, include_packages, exclude_packages
    )
    _run(ctx, as_json, lambda: execute_session(_paths(), request))


@code.command("package-sets")
@click.argument("set_name", required=False, type=click.Choice(PACKAGE_SET_NAMES))
@JSON_OPTION
@click.pass_context
def code_package_sets(ctx: click.Context, set_name: str | None, as_json: bool) -> None:
    """List named loaded-package universes, optionally resolving one SET_NAME."""
    request: dict[str, Any] = {"operation": "code.package-sets"}
    if set_name is not None:
        request["set"] = set_name
    _run(ctx, as_json, lambda: execute_session(_paths(), request))


@code.command("analyze")
@click.argument("class_name", metavar="CLASS_NAME")
@click.argument("selector", metavar="SELECTOR")
@click.option("--side", type=click.Choice(("instance", "class")), default="instance", show_default=True, help="Choose the instance or class method side.")
@click.option("--depth", type=click.IntRange(0, 5), default=1, show_default=True, help="Maximum recursive send-graph depth.")
@click.option("--max-methods", type=POSITIVE_INT, default=100, show_default=True, help="Maximum number of analyzed methods.")
@click.option("--max-candidates", type=POSITIVE_INT, default=20, show_default=True, help="Maximum candidate callees per send.")
@click.option("--max-source-chars", type=POSITIVE_INT, default=1_000_000, show_default=True, help="Maximum total source characters included in results.")
@click.option("--no-source", is_flag=True, help="Omit method source from AST analysis records.")
@scope_options
@JSON_OPTION
@click.pass_context
def code_analyze(
    ctx: click.Context, class_name: str, selector: str, side: str, depth: int,
    max_methods: int, max_candidates: int, max_source_chars: int, no_source: bool,
    package_set: str | None, include_packages: tuple[str, ...],
    exclude_packages: tuple[str, ...], as_json: bool,
) -> None:
    """Build a bounded AST summary and static send graph for one method."""
    request = {
        "operation": "code.analyze", "class": class_name, "selector": selector,
        "side": side, "depth": depth, "maxMethods": max_methods,
        "maxCandidates": max_candidates, "maxSourceChars": max_source_chars,
        "includeSource": not no_source,
    } | _scope_request(package_set, include_packages, exclude_packages)
    _run(ctx, as_json, lambda: execute_session(_paths(), request))


def _relationship_request(
    operation: str, selector: str, limit: int, package_set: str | None,
    include_packages: tuple[str, ...], exclude_packages: tuple[str, ...],
) -> dict[str, Any]:
    return {"operation": operation, "selector": selector, "limit": limit} | _scope_request(
        package_set, include_packages, exclude_packages
    )


@code.command("implementors")
@click.argument("selector")
@click.option("--limit", type=POSITIVE_INT, default=500, show_default=True, help="Maximum number of results.")
@scope_options
@JSON_OPTION
@click.pass_context
def code_implementors(ctx: click.Context, selector: str, limit: int, package_set: str | None, include_packages: tuple[str, ...], exclude_packages: tuple[str, ...], as_json: bool) -> None:
    """Find package-aware implementors of SELECTOR."""
    request = _relationship_request("code.implementors", selector, limit, package_set, include_packages, exclude_packages)
    _run(ctx, as_json, lambda: execute_session(_paths(), request))


@code.command("senders")
@click.argument("selector")
@click.option("--limit", type=POSITIVE_INT, default=500, show_default=True, help="Maximum number of results.")
@scope_options
@JSON_OPTION
@click.pass_context
def code_senders(ctx: click.Context, selector: str, limit: int, package_set: str | None, include_packages: tuple[str, ...], exclude_packages: tuple[str, ...], as_json: bool) -> None:
    """Find methods whose ASTs send SELECTOR."""
    request = _relationship_request("code.senders", selector, limit, package_set, include_packages, exclude_packages)
    _run(ctx, as_json, lambda: execute_session(_paths(), request))


@code.command("references")
@click.argument("value")
@click.option("--kind", type=click.Choice(("class", "global", "symbol", "string")), required=True, help="Choose the referenced object or literal kind.")
@click.option("--limit", type=POSITIVE_INT, default=500, show_default=True, help="Maximum number of results.")
@scope_options
@JSON_OPTION
@click.pass_context
def code_references(ctx: click.Context, value: str, kind: str, limit: int, package_set: str | None, include_packages: tuple[str, ...], exclude_packages: tuple[str, ...], as_json: bool) -> None:
    """Find package-aware references to VALUE of the selected literal kind."""
    request = {"operation": "code.references", "value": value, "kind": kind, "limit": limit} | _scope_request(package_set, include_packages, exclude_packages)
    _run(ctx, as_json, lambda: execute_session(_paths(), request))


@code.command("pragmas")
@click.argument("pragma")
@click.option("--limit", type=POSITIVE_INT, default=500, show_default=True, help="Maximum number of results.")
@scope_options
@JSON_OPTION
@click.pass_context
def code_pragmas(ctx: click.Context, pragma: str, limit: int, package_set: str | None, include_packages: tuple[str, ...], exclude_packages: tuple[str, ...], as_json: bool) -> None:
    """Find methods carrying the exact PRAGMA selector."""
    request = {"operation": "code.pragmas", "pragma": pragma, "limit": limit} | _scope_request(package_set, include_packages, exclude_packages)
    _run(ctx, as_json, lambda: execute_session(_paths(), request))


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
