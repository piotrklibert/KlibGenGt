from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Callable

import click

from . import cli
from .common import JSON_OPTION, POSITIVE_FLOAT, POSITIVE_INT, _expression, _paths, _regex, _run, source_options
from ..ui_control import active_gui_sessions, submit_ui_request, validate_regex_selector


def _selector(**values: Any) -> dict[str, Any]:
    mapping = {
        "space": "space", "node": "node", "under": "under", "class_name": "class",
        "element_id": "elementId", "text": "text", "text_contains": "textContains",
        "text_regex": "textRegex", "visible": "visible", "enabled": "enabled",
        "focused": "focused",
    }
    return {wire: values[name] for name, wire in mapping.items() if values.get(name) is not None}


@cli.group()
def ui() -> None:
    """Inspect and control the active managed GUI through structured requests."""


def ui_common(selector: bool = False) -> Callable[[Callable[..., Any]], Callable[..., Any]]:
    def decorate(function: Callable[..., Any]) -> Callable[..., Any]:
        function = click.option("--session", metavar="SESSION_ID", help="Select a specific active GUI session.")(function)
        function = click.option("--timeout", type=POSITIVE_FLOAT, default=10.0, show_default=True, help="Maximum request time in seconds.")(function)
        function = JSON_OPTION(function)
        if selector:
            specs = [
                ("--space", {}), ("--node", {}), ("--under", {}), ("--class", {"dest": "class_name"}),
                ("--element-id", {}), ("--text", {}), ("--text-contains", {}),
                ("--text-regex", {"callback": _regex, "metavar": "REGEX"}),
                ("--visible/--no-visible", {"default": None}),
                ("--enabled/--no-enabled", {"default": None}),
                ("--focused/--no-focused", {"default": None}),
            ]
            helps = ["Select a space.", "Select an exact node ID.", "Restrict matches beneath this node.", "Match an element class.", "Match an element ID.", "Match exact text.", "Match contained text.", "Match text by regular expression.", "Require visible or hidden nodes.", "Require enabled or disabled nodes.", "Require focused or unfocused nodes."]
            for (declaration, extra), help_text in reversed(list(zip(specs, helps))):
                destination = extra.pop("dest", None)
                args = (declaration, destination) if destination else (declaration,)
                function = click.option(*args, help=help_text, **extra)(function)
        return function
    return decorate


def _ui_request(ctx: click.Context, operation: str, session: str | None, timeout: float, as_json: bool, request: dict[str, Any] | None = None) -> None:
    value = {"operation": operation} | (request or {})
    _run(ctx, as_json, lambda: submit_ui_request(_paths(), value, session_id=session, timeout=timeout))


@ui.command("status")
@ui_common()
@click.pass_context
def ui_status(ctx: click.Context, session: str | None, timeout: float, as_json: bool) -> None:
    """List active GUI sessions; --session filters the result."""
    def operation() -> dict[str, Any]:
        sessions = active_gui_sessions(_paths())
        if session:
            sessions = [item for item in sessions if item.get("sessionId") == session]
        return {"schemaVersion": 1, "ok": True, "operation": "ui.status", "data": {"sessions": sessions, "count": len(sessions)}}
    _run(ctx, as_json, operation)


@ui.command("spaces")
@ui_common()
@click.pass_context
def ui_spaces(ctx: click.Context, session: str | None, timeout: float, as_json: bool) -> None:
    """List spaces instantiated in the active GUI scene."""
    _ui_request(ctx, "ui.spaces", session, timeout, as_json)


def selector_values(values: dict[str, Any]) -> dict[str, Any]:
    names = {"space", "node", "under", "class_name", "element_id", "text", "text_contains", "text_regex", "visible", "enabled", "focused"}
    selected = {key: values.pop(key) for key in list(values) if key in names}
    request = _selector(**selected)
    validate_regex_selector(request)
    return request


@ui.command("tree")
@ui_common(selector=True)
@click.option("--limit", type=POSITIVE_INT, default=5000, show_default=True, help="Maximum number of instantiated nodes.")
@click.pass_context
def ui_tree(ctx: click.Context, limit: int, **values: Any) -> None:
    """Return an instantiated scene tree below the optional selector."""
    request = selector_values(values) | {"limit": limit}
    _ui_request(ctx, "ui.tree", values["session"], values["timeout"], values["as_json"], request)


def make_ui_selector_command(name: str) -> Callable[..., Any]:
    @ui.command(name)
    @ui_common(selector=True)
    @click.pass_context
    def command(ctx: click.Context, **values: Any) -> None:
        """Select instantiated nodes using the documented selector options."""
        request = selector_values(values)
        _ui_request(ctx, f"ui.{name}", values["session"], values["timeout"], values["as_json"], request)
    return command


ui_query = make_ui_selector_command("query")
ui_get = make_ui_selector_command("get")


@ui.command("act")
@click.argument("action", type=click.Choice(("click", "double-click", "secondary-click", "hover", "focus", "type", "key-press", "shortcut", "scroll", "drag")))
@ui_common(selector=True)
@click.option("--value", help="Text or action-specific value.")
@click.option("--key", help="Key name for keyboard actions.")
@click.option("--dx", type=float, default=0.0, show_default=True, help="Horizontal scroll or drag distance.")
@click.option("--dy", type=float, default=0.0, show_default=True, help="Vertical scroll or drag distance.")
@click.pass_context
def ui_act(ctx: click.Context, action: str, value: str | None, key: str | None, dx: float, dy: float, **values: Any) -> None:
    """Perform ACTION on the uniquely selected node."""
    request = selector_values(values) | {"action": action, "dx": dx, "dy": dy}
    if value is not None:
        request["value"] = value
    if key is not None:
        request["key"] = key
    _ui_request(ctx, "ui.act", values["session"], values["timeout"], values["as_json"], request)


@ui.command("wait")
@click.argument("state", type=click.Choice(("exists", "absent", "visible", "hidden", "focused", "enabled", "text-equals", "text-contains")))
@ui_common(selector=True)
@click.option("--value", help="Expected text for a text comparison state.")
@click.pass_context
def ui_wait(ctx: click.Context, state: str, value: str | None, **values: Any) -> None:
    """Wait for selected nodes to reach STATE."""
    request = selector_values(values) | {"state": state}
    if value is not None:
        request["value"] = value
    _ui_request(ctx, "ui.wait", values["session"], values["timeout"], values["as_json"], request)


@ui.command("batch")
@source_options
@ui_common()
@click.pass_context
def ui_batch(ctx: click.Context, file: Path | None, stdin: bool, session: str | None, timeout: float, as_json: bool) -> None:
    """Submit JSON steps from exactly one of --file or --stdin."""
    def operation() -> dict[str, Any]:
        if (file is None) == (not stdin):
            raise ValueError("provide exactly one --file or --stdin")
        value = json.loads(file.read_text(encoding="utf-8") if file else sys.stdin.read())
        steps = value.get("steps", value) if isinstance(value, dict) else value
        return submit_ui_request(_paths(), {"operation": "ui.batch", "steps": steps}, session_id=session, timeout=timeout)
    _run(ctx, as_json, operation)


@ui.command("eval")
@click.argument("expression", required=False)
@source_options
@ui_common()
@click.pass_context
def ui_eval(ctx: click.Context, expression: str | None, file: Path | None, stdin: bool, session: str | None, timeout: float, as_json: bool) -> None:
    """Evaluate EXPRESSION, --file, or --stdin in the active GUI image."""
    def operation() -> dict[str, Any]:
        request = {"operation": "ui.eval", "expression": _expression(expression, file, stdin)}
        return submit_ui_request(_paths(), request, session_id=session, timeout=timeout)
    _run(ctx, as_json, operation)


