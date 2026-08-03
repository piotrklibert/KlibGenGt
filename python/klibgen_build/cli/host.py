from __future__ import annotations

import time
from pathlib import Path
from typing import Any, Callable

import click

from . import cli
from .common import JSON_OPTION, POSITIVE_FLOAT, POSITIVE_INT, WINDOW_ID, _paths, _regex, _run
from ..host_tools import (
    WindowSelector, X11DesktopBackend, process_data, process_list, profile_command,
    require_one_window, select_windows, terminate_process, wait_for_processes,
    wait_for_windows, window_data,
)


@cli.group()
def host() -> None:
    """Inspect and control host windows/processes, or profile a command."""


@host.group()
def windows() -> None:
    """Inspect or act on X11 windows selected by composable filters."""


def window_options(function: Callable[..., Any]) -> Callable[..., Any]:
    options = [
        click.option("--id", "window_id", type=WINDOW_ID, metavar="INTEGER", help="Select an X11 window by decimal, octal, or hexadecimal ID."),
        click.option("--pid", type=POSITIVE_INT, help="Select windows owned by this positive process ID."),
        click.option("--title-regex", callback=_regex, metavar="REGEX", help="Select windows whose title matches this regular expression."),
        click.option("--command-regex", callback=_regex, metavar="REGEX", help="Select windows whose process command matches this regular expression."),
    ]
    for option in reversed(options):
        function = option(function)
    return function


def _window_selector(window_id: int | None, pid: int | None, title_regex: str | None, command_regex: str | None) -> WindowSelector:
    return WindowSelector(window_id, pid, title_regex, command_regex)


@windows.command("list")
@window_options
@JSON_OPTION
@click.pass_context
def windows_list(ctx: click.Context, as_json: bool, **selector: Any) -> None:
    """List every visible managed window matching all supplied selectors."""
    def operation() -> dict[str, Any]:
        values = select_windows(X11DesktopBackend().windows(), _window_selector(**selector))
        return {"schemaVersion": 1, "ok": True, "operation": "host.windows.list", "data": {"windows": window_data(values)}}
    _run(ctx, as_json, operation)


@windows.command("wait")
@window_options
@click.option("--for", "wait_for", type=click.Choice(("present", "absent")), required=True, help="Wait until matching windows are present or absent.")
@click.option("--timeout", type=POSITIVE_FLOAT, default=10.0, show_default=True, help="Maximum seconds to wait (must be positive).")
@JSON_OPTION
@click.pass_context
def windows_wait(ctx: click.Context, wait_for: str, timeout: float, as_json: bool, **selector: Any) -> None:
    """Wait for the selected window set to reach the requested state."""
    def operation() -> dict[str, Any]:
        values = wait_for_windows(X11DesktopBackend(), _window_selector(**selector), wait_for == "present", timeout)
        return {"schemaVersion": 1, "ok": True, "operation": "host.windows.wait", "data": {"windows": window_data(values)}}
    _run(ctx, as_json, operation)


def _one_window(operation_name: str, action: str, selector: dict[str, Any], output: Path | None = None, timeout: float = 10.0) -> dict[str, Any]:
    paths, backend = _paths(), X11DesktopBackend()
    window = require_one_window(backend, _window_selector(**selector))
    if action == "screenshot":
        target = output or paths.root / "tmp/screenshots" / f"{time.strftime('%Y%m%d-%H%M%S')}-{window.id_hex}.png"
        if not target.is_absolute():
            target = paths.root / target
        backend.screenshot(window, target)
        return {"schemaVersion": 1, "ok": True, "operation": operation_name, "data": {"path": str(target), "window": window_data([window])[0]}}
    if action == "focus":
        backend.focus(window)
    else:
        backend.close(window)
        wait_for_windows(backend, WindowSelector(window_id=window.id), False, timeout)
    return {"schemaVersion": 1, "ok": True, "operation": operation_name, "data": {"window": window_data([window])[0]}}


@windows.command("screenshot")
@window_options
@click.option("--output", type=click.Path(path_type=Path, dir_okay=False), metavar="PNG", help="Write the PNG to this path instead of tmp/screenshots.")
@JSON_OPTION
@click.pass_context
def windows_screenshot(ctx: click.Context, output: Path | None, as_json: bool, **selector: Any) -> None:
    """Capture exactly one selected window as a PNG file."""
    _run(ctx, as_json, lambda: _one_window("host.windows.screenshot", "screenshot", selector, output))


@windows.command("focus")
@window_options
@JSON_OPTION
@click.pass_context
def windows_focus(ctx: click.Context, as_json: bool, **selector: Any) -> None:
    """Focus exactly one selected window."""
    _run(ctx, as_json, lambda: _one_window("host.windows.focus", "focus", selector))


@windows.command("close")
@window_options
@click.option("--timeout", type=POSITIVE_FLOAT, default=10.0, show_default=True, help="Maximum seconds to wait for the window to close.")
@JSON_OPTION
@click.pass_context
def windows_close(ctx: click.Context, timeout: float, as_json: bool, **selector: Any) -> None:
    """Request that exactly one selected window close, then wait for it."""
    _run(ctx, as_json, lambda: _one_window("host.windows.close", "close", selector, timeout=timeout))


@host.group()
def processes() -> None:
    """Inspect, wait for, or terminate host processes."""


def process_options(regex: bool = True) -> Callable[[Callable[..., Any]], Callable[..., Any]]:
    def decorate(function: Callable[..., Any]) -> Callable[..., Any]:
        function = click.option("--pid", type=POSITIVE_INT, help="Select a positive process ID.")(function)
        if regex:
            function = click.option("--command-regex", callback=_regex, metavar="REGEX", help="Select process commands matching this regular expression.")(function)
        return function
    return decorate


@processes.command("list")
@process_options()
@JSON_OPTION
@click.pass_context
def processes_list(ctx: click.Context, pid: int | None, command_regex: str | None, as_json: bool) -> None:
    """List processes matching the optional PID and command filters."""
    _run(ctx, as_json, lambda: {"schemaVersion": 1, "ok": True, "operation": "host.processes.list", "data": {"processes": process_data(process_list(pid, command_regex))}})


@processes.command("wait")
@process_options()
@click.option("--for", "wait_for", type=click.Choice(("present", "absent")), required=True, help="Wait until matching processes are present or absent.")
@click.option("--timeout", type=POSITIVE_FLOAT, default=10.0, show_default=True, help="Maximum seconds to wait.")
@JSON_OPTION
@click.pass_context
def processes_wait(ctx: click.Context, pid: int | None, command_regex: str | None, wait_for: str, timeout: float, as_json: bool) -> None:
    """Wait for the selected process set to reach the requested state."""
    _run(ctx, as_json, lambda: {"schemaVersion": 1, "ok": True, "operation": "host.processes.wait", "data": {"processes": process_data(wait_for_processes(pid, command_regex, wait_for == "present", timeout))}})


@processes.command("terminate")
@process_options(regex=False)
@click.option("--timeout", type=POSITIVE_FLOAT, default=5.0, show_default=True, help="Seconds to allow graceful termination.")
@click.option("--force", is_flag=True, help="Kill the process if graceful termination times out.")
@JSON_OPTION
@click.pass_context
def processes_terminate(ctx: click.Context, pid: int | None, timeout: float, force: bool, as_json: bool) -> None:
    """Terminate the process selected by the required --pid option."""
    def operation() -> dict[str, Any]:
        if pid is None:
            raise ValueError("process termination requires --pid")
        return {"schemaVersion": 1, "ok": True, "operation": "host.processes.terminate", "data": terminate_process(pid, timeout, force)}
    _run(ctx, as_json, operation)


@host.command("profile", context_settings={"ignore_unknown_options": True})
@click.argument("profile_command", nargs=-1, type=click.UNPROCESSED)
@JSON_OPTION
@click.pass_context
def host_profile(ctx: click.Context, profile_command: tuple[str, ...], as_json: bool) -> None:
    """Profile COMMAND and preserve its arguments; use ``-- COMMAND`` for options."""
    def operation() -> dict[str, Any]:
        value = profile_command_fn(list(profile_command), capture=as_json)
        return {"schemaVersion": 1, "ok": True, "operation": "host.profile", "data": {key: item for key, item in value.items() if key != "metrics"}, "metrics": value["metrics"]}
    _run(ctx, as_json, operation)


# An alias avoids the command function shadowing the imported service.
profile_command_fn = profile_command


