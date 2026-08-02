from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import time
from pathlib import Path
from typing import Any

from .canonical import build_canonical
from .core import BuildPaths, platform_id
from .host_tools import (
    WindowSelector, X11DesktopBackend, process_data, process_list, profile_command,
    require_one_window, select_windows, terminate_process, wait_for_processes,
    wait_for_windows, window_data,
)
from .inventory_v2 import garbage_collect, inventory
from .json_models import validate_named_record
from .processes import ProcessExecutionError
from .registered_tools import export_build_map_pngs
from .resolution import recipe_catalog, resolve_target
from .sessions import execute_agentic_session, execute_session
from .staging import create_staging, list_staging, promote_staging, reset_staging
from .store import ArtifactStore
from .tonel_export import DEFAULT_PACKAGE, export_tonel
from .ui_control import active_gui_sessions, selector_request, submit_ui_request, validate_regex_selector
from .v2state import V2Paths
from .workspaces import launch_gui_workspace, reset_workspace, workspace_status


def _add_window_selector(command: argparse.ArgumentParser) -> None:
    command.add_argument("--id", dest="window_id", type=lambda value: int(value, 0))
    command.add_argument("--pid", type=int)
    command.add_argument("--title-regex")
    command.add_argument("--command-regex")


def _host_parser(subparsers: argparse._SubParsersAction) -> None:
    host = subparsers.add_parser("host")
    areas = host.add_subparsers(dest="host_area", required=True)
    windows = areas.add_parser("windows")
    commands = windows.add_subparsers(dest="host_action", required=True)
    for name in ("list", "wait", "screenshot", "focus", "close"):
        command = commands.add_parser(name)
        _add_window_selector(command)
        command.add_argument("--json", action="store_true")
        if name == "wait":
            command.add_argument("--for", dest="wait_for", choices=("present", "absent"), required=True)
            command.add_argument("--timeout", type=float, default=10.0)
        elif name == "screenshot":
            command.add_argument("--output", type=Path)
        elif name == "close":
            command.add_argument("--timeout", type=float, default=10.0)
    processes = areas.add_parser("processes")
    commands = processes.add_subparsers(dest="host_action", required=True)
    for name in ("list", "wait", "terminate"):
        command = commands.add_parser(name)
        command.add_argument("--pid", type=int)
        if name != "terminate":
            command.add_argument("--command-regex")
        command.add_argument("--json", action="store_true")
        if name == "wait":
            command.add_argument("--for", dest="wait_for", choices=("present", "absent"), required=True)
            command.add_argument("--timeout", type=float, default=10.0)
        elif name == "terminate":
            command.add_argument("--timeout", type=float, default=5.0)
            command.add_argument("--force", action="store_true")
    profile = areas.add_parser("profile")
    profile.add_argument("--json", action="store_true")
    profile.add_argument("profile_command", nargs=argparse.REMAINDER)


def _image_parser(subparsers: argparse._SubParsersAction) -> None:
    image = subparsers.add_parser("image")
    areas = image.add_subparsers(dest="image_area", required=True)
    code = areas.add_parser("code")
    commands = code.add_subparsers(dest="image_action", required=True)
    search = commands.add_parser("search")
    search.add_argument("query")
    search.add_argument("--kind", choices=("all", "class", "method"), default="all")
    search.add_argument("--package")
    search.add_argument("--limit", type=int, default=100)
    class_definition = commands.add_parser("class")
    class_definition.add_argument("class_name")
    method = commands.add_parser("method")
    method.add_argument("class_name")
    method.add_argument("selector")
    method.add_argument("--side", choices=("instance", "class"), default="instance")
    lepiter = areas.add_parser("lepiter")
    commands = lepiter.add_subparsers(dest="image_action", required=True)
    lepiter_search = commands.add_parser("search")
    lepiter_search.add_argument("query")
    lepiter_search.add_argument("--in", dest="search_in", choices=("text", "title"), default="text")
    lepiter_search.add_argument("--database", dest="databases", action="append", default=[])
    lepiter_search.add_argument("--limit", type=int, default=100)
    export = commands.add_parser("export")
    page = export.add_mutually_exclusive_group(required=True)
    page.add_argument("--uid")
    page.add_argument("--title")
    export.add_argument("--database", dest="databases", action="append", default=[])
    evaluation = areas.add_parser("eval")
    evaluation.add_argument("expression", nargs="?")
    source = evaluation.add_mutually_exclusive_group()
    source.add_argument("--file", type=Path)
    source.add_argument("--stdin", action="store_true")
    evaluation.add_argument("--profile", action="store_true")
    for command in (search, class_definition, method, lepiter_search, export, evaluation):
        command.add_argument("--json", action="store_true")


def _ui_parser(subparsers: argparse._SubParsersAction) -> None:
    ui = subparsers.add_parser("ui")
    commands = ui.add_subparsers(dest="ui_action", required=True)

    def common(command: argparse.ArgumentParser, selector: bool = False) -> None:
        command.add_argument("--session")
        command.add_argument("--timeout", type=float, default=10.0)
        command.add_argument("--json", action="store_true")
        if selector:
            command.add_argument("--space")
            command.add_argument("--node")
            command.add_argument("--under")
            command.add_argument("--class", dest="class_name")
            command.add_argument("--element-id")
            command.add_argument("--text")
            command.add_argument("--text-contains")
            command.add_argument("--text-regex")
            command.add_argument("--visible", action=argparse.BooleanOptionalAction)
            command.add_argument("--enabled", action=argparse.BooleanOptionalAction)
            command.add_argument("--focused", action=argparse.BooleanOptionalAction)

    for name in ("status", "spaces"):
        common(commands.add_parser(name))
    tree = commands.add_parser("tree")
    common(tree, True)
    tree.add_argument("--limit", type=int, default=5000)
    for name in ("query", "get"):
        common(commands.add_parser(name), True)
    act = commands.add_parser("act")
    common(act, True)
    act.add_argument("action", choices=("click", "double-click", "secondary-click", "hover", "focus", "type", "key-press", "shortcut", "scroll", "drag"))
    act.add_argument("--value")
    act.add_argument("--key")
    act.add_argument("--dx", type=float, default=0.0)
    act.add_argument("--dy", type=float, default=0.0)
    wait = commands.add_parser("wait")
    common(wait, True)
    wait.add_argument("state", choices=("exists", "absent", "visible", "hidden", "focused", "enabled", "text-equals", "text-contains"))
    wait.add_argument("--value")
    batch = commands.add_parser("batch")
    common(batch)
    source = batch.add_mutually_exclusive_group(required=True)
    source.add_argument("--file", type=Path)
    source.add_argument("--stdin", action="store_true")
    evaluation = commands.add_parser("eval")
    common(evaluation)
    evaluation.add_argument("expression", nargs="?")
    source = evaluation.add_mutually_exclusive_group()
    source.add_argument("--file", type=Path)
    source.add_argument("--stdin", action="store_true")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(prog="klibgen-build")
    commands = result.add_subparsers(dest="command", required=True)
    _host_parser(commands)
    _image_parser(commands)
    _ui_parser(commands)
    recipe = commands.add_parser("recipe")
    recipe_commands = recipe.add_subparsers(dest="action", required=True)
    recipe_commands.add_parser("list").add_argument("--json", action="store_true")
    resolve = recipe_commands.add_parser("resolve")
    resolve.add_argument("target")
    resolve.add_argument("--through")
    resolve.add_argument("--json", action="store_true")
    artifact = commands.add_parser("artifact")
    artifact_commands = artifact.add_subparsers(dest="action", required=True)
    artifact_commands.add_parser("list").add_argument("--json", action="store_true")
    verify = artifact_commands.add_parser("verify")
    verify.add_argument("key")
    verify.add_argument("--json", action="store_true")
    for name in ("doctor", "status", "inventory", "build-map"):
        commands.add_parser(name).add_argument("--json", action="store_true")
    build = commands.add_parser("build")
    build.add_argument("target", nargs="?", default="cli")
    build.add_argument("--through")
    build.add_argument("--json", action="store_true")
    test = commands.add_parser("test")
    test.add_argument("--fresh", action="store_true")
    test.add_argument("--json", action="store_true")
    test_one = commands.add_parser("test-one")
    test_one.add_argument("test_class")
    test_one.add_argument("selector")
    test_one.add_argument("--json", action="store_true")
    evaluation = commands.add_parser("eval")
    evaluation.add_argument("expression", nargs="?")
    evaluation.add_argument("--profile", action="store_true")
    evaluation.add_argument("--json", action="store_true")
    for name in ("load", "smoke", "check-type-pragmas"):
        commands.add_parser(name).add_argument("--json", action="store_true")
    gui = commands.add_parser("gui")
    gui.add_argument("--fresh", action="store_true")
    workspace = commands.add_parser("workspace")
    workspace_commands = workspace.add_subparsers(dest="action", required=True)
    workspace_commands.add_parser("status").add_argument("--json", action="store_true")
    reset = workspace_commands.add_parser("reset")
    reset.add_argument("--confirm", action="store_true")
    reset.add_argument("--json", action="store_true")
    staging = commands.add_parser("staging")
    staging_commands = staging.add_subparsers(dest="action", required=True)
    staging_commands.add_parser("list").add_argument("--json", action="store_true")
    for action in ("create", "reset", "promote"):
        command = staging_commands.add_parser(action)
        command.add_argument("name")
        command.add_argument("--json", action="store_true")
    agentic = commands.add_parser("agentic")
    agentic.add_argument("name")
    choice = agentic.add_mutually_exclusive_group()
    choice.add_argument("--eval")
    choice.add_argument("--test", action="store_true")
    agentic.add_argument("--json", action="store_true")
    gc = commands.add_parser("gc")
    mode = gc.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true")
    mode.add_argument("--apply", action="store_true")
    gc.add_argument("--json", action="store_true")
    png = commands.add_parser("build-map-png")
    png.add_argument("output", nargs="?", type=Path)
    png.add_argument("--force", action="store_true")
    png.add_argument("--json", action="store_true")
    models = commands.add_parser("models")
    model_commands = models.add_subparsers(dest="models_action", required=True)
    export = model_commands.add_parser("export-tonel")
    export.add_argument("--output", type=Path)
    export.add_argument("--check", action="store_true")
    return result


def _expression(args: argparse.Namespace) -> str:
    choices = sum((args.expression is not None, getattr(args, "file", None) is not None, getattr(args, "stdin", False)))
    if choices == 0 and args.command == "eval" and os.environ.get("GT_EVAL") is not None:
        return os.environ["GT_EVAL"]
    if choices != 1:
        raise ValueError("provide exactly one expression, --file, or --stdin")
    if getattr(args, "file", None) is not None:
        return args.file.read_text(encoding="utf-8")
    if getattr(args, "stdin", False):
        return sys.stdin.read()
    return args.expression


def _host(paths: BuildPaths, args: argparse.Namespace) -> dict[str, Any]:
    operation = "host.profile" if args.host_area == "profile" else f"host.{args.host_area}.{args.host_action}"
    if args.host_area == "windows":
        backend = X11DesktopBackend()
        selector = WindowSelector(args.window_id, args.pid, args.title_regex, args.command_regex)
        if args.host_action == "list":
            windows = select_windows(backend.windows(), selector)
            return {"schemaVersion": 1, "ok": True, "operation": operation, "data": {"windows": window_data(windows)}}
        if args.host_action == "wait":
            windows = wait_for_windows(backend, selector, args.wait_for == "present", args.timeout)
            return {"schemaVersion": 1, "ok": True, "operation": operation, "data": {"windows": window_data(windows)}}
        window = require_one_window(backend, selector)
        if args.host_action == "screenshot":
            output = args.output or paths.root / "tmp/screenshots" / f"{time.strftime('%Y%m%d-%H%M%S')}-{window.id_hex}.png"
            if not output.is_absolute():
                output = paths.root / output
            backend.screenshot(window, output)
            return {"schemaVersion": 1, "ok": True, "operation": operation, "data": {"path": str(output), "window": window_data([window])[0]}}
        if args.host_action == "focus":
            backend.focus(window)
        else:
            backend.close(window)
            wait_for_windows(backend, WindowSelector(window_id=window.id), False, args.timeout)
        return {"schemaVersion": 1, "ok": True, "operation": operation, "data": {"window": window_data([window])[0]}}
    if args.host_area == "processes":
        if args.host_action == "list":
            values = process_list(args.pid, args.command_regex)
            return {"schemaVersion": 1, "ok": True, "operation": operation, "data": {"processes": process_data(values)}}
        if args.host_action == "wait":
            values = wait_for_processes(args.pid, args.command_regex, args.wait_for == "present", args.timeout)
            return {"schemaVersion": 1, "ok": True, "operation": operation, "data": {"processes": process_data(values)}}
        if args.pid is None:
            raise ValueError("process termination requires --pid")
        return {"schemaVersion": 1, "ok": True, "operation": operation, "data": terminate_process(args.pid, args.timeout, args.force)}
    command = args.profile_command[1:] if args.profile_command and args.profile_command[0] == "--" else args.profile_command
    value = profile_command(command, capture=args.json)
    return {"schemaVersion": 1, "ok": True, "operation": operation, "data": {key: item for key, item in value.items() if key != "metrics"}, "metrics": value["metrics"]}


def _image(paths: BuildPaths, args: argparse.Namespace) -> dict[str, Any]:
    if args.image_area == "code":
        if args.image_action == "search":
            request = {"operation": "code.search", "query": args.query, "kind": args.kind, "limit": args.limit}
            if args.package is not None:
                request["package"] = args.package
        elif args.image_action == "class":
            request = {"operation": "code.class", "class": args.class_name}
        else:
            request = {"operation": "code.method", "class": args.class_name, "selector": args.selector, "side": args.side}
    elif args.image_area == "lepiter":
        if args.image_action == "search":
            request = {"operation": "lepiter.search", "query": args.query, "in": args.search_in, "databases": args.databases, "limit": args.limit}
        else:
            request = {"operation": "lepiter.export", "databases": args.databases}
            request["uid" if args.uid is not None else "title"] = args.uid or args.title
    else:
        request = {"operation": "eval", "expression": _expression(args), "profile": args.profile}
    return execute_session(paths, request)


def _ui(paths: BuildPaths, args: argparse.Namespace) -> dict[str, Any]:
    if args.ui_action == "status":
        sessions = active_gui_sessions(paths)
        if args.session:
            sessions = [session for session in sessions if session.get("sessionId") == args.session]
        return {"schemaVersion": 1, "ok": True, "operation": "ui.status", "data": {"sessions": sessions, "count": len(sessions)}}
    request: dict[str, Any] = {"operation": f"ui.{args.ui_action}"}
    if args.ui_action in {"tree", "query", "get", "act", "wait"}:
        request.update(selector_request(args))
        validate_regex_selector(request)
    if args.ui_action == "tree":
        request["limit"] = args.limit
    elif args.ui_action == "act":
        request.update({"action": args.action, "dx": args.dx, "dy": args.dy})
        if args.value is not None:
            request["value"] = args.value
        if args.key is not None:
            request["key"] = args.key
    elif args.ui_action == "wait":
        request["state"] = args.state
        if args.value is not None:
            request["value"] = args.value
    elif args.ui_action == "batch":
        value = json.loads(args.file.read_text(encoding="utf-8") if args.file else sys.stdin.read())
        request["steps"] = value.get("steps", value) if isinstance(value, dict) else value
    elif args.ui_action == "eval":
        request["expression"] = _expression(args)
    return submit_ui_request(paths, request, session_id=args.session, timeout=args.timeout)


def _doctor(paths: BuildPaths) -> dict[str, Any]:
    tools = [{"name": name, "path": shutil.which(name), "ok": shutil.which(name) is not None} for name in ("git", "jj", "uv", "unzip")]
    checks = [{"path": str(path), "ok": path.exists()} for path in (paths.root / "src", paths.root / "vendor/gt.zip", paths.root / "build/locks/default.lock.json")]
    return {"schema": "klibgen.doctor/1", "schemaVersion": 1, "operation": "doctor", "ok": all(item["ok"] for item in tools + checks), "platform": platform_id(), "stateRoot": str(V2Paths.for_build(paths).root), "tools": tools, "checks": checks}


def _status(paths: BuildPaths) -> dict[str, Any]:
    v2 = V2Paths.for_build(paths)
    statuses = [json.loads(path.read_text(encoding="utf-8")) for path in sorted((v2.root / "status").glob("*.json"))] if (v2.root / "status").is_dir() else []
    return {"schema": "klibgen.status-list/1", "schemaVersion": 1, "operation": "status", "statuses": statuses, "workspace": workspace_status(paths)}


def _result(paths: BuildPaths, args: argparse.Namespace) -> dict[str, Any] | int:
    if args.command == "models":
        output = args.output or paths.root / "src" / DEFAULT_PACKAGE
        if not output.is_absolute():
            output = paths.root / output
        drift = export_tonel(output, check=args.check)
        if args.check and drift:
            print("generated Tonel models are stale: " + ", ".join(drift), file=sys.stderr)
            return 1
        if args.check:
            print(f"generated Tonel models are current ({output})")
        else:
            print(f"generated Tonel JSON models in {output}")
        return 0
    if args.command == "host":
        return _host(paths, args)
    if args.command == "image":
        return _image(paths, args)
    if args.command == "ui":
        return _ui(paths, args)
    if args.command == "recipe":
        return recipe_catalog() if args.action == "list" else resolve_target(paths, args.target, args.through)
    if args.command == "artifact":
        store = ArtifactStore(paths)
        if args.action == "list":
            return {"schema": "klibgen.artifact-list/1", "schemaVersion": 1, "operation": "artifact.list", "artifacts": store.artifacts()}
        matches = list((store.v2.root / "store").glob(f"*/*/{args.key}"))
        if len(matches) != 1:
            raise ValueError(f"expected one artifact for key {args.key!r}, found {len(matches)}")
        return {"schema": "klibgen.artifact-verification/1", "schemaVersion": 1, "operation": "artifact.verify", "path": str(matches[0]), "manifest": store.verify(matches[0]), "valid": True}
    if args.command == "doctor":
        return _doctor(paths)
    if args.command == "status":
        return _status(paths)
    if args.command == "build":
        return build_canonical(paths, args.target, args.through)
    if args.command in {"test", "test-one"}:
        request = {"operation": "test.all"} if args.command == "test" else {"operation": "test.run", "class": args.test_class, "selector": args.selector}
        result = execute_session(paths, request)
        result["operation"] = args.command
        return result
    if args.command == "eval":
        result = execute_session(paths, {"operation": "eval", "expression": _expression(args), "profile": args.profile})
        result["operation"] = "eval"
        return result
    if args.command == "load":
        return build_canonical(paths, "cli") | {"operation": "load"}
    if args.command == "smoke":
        result = execute_session(paths, {"operation": "eval", "expression": "KlibGenGt projectName", "profile": False})
        result["operation"] = "smoke"
        return result
    if args.command == "check-type-pragmas":
        result = execute_session(paths, {"operation": "test.run", "class": "KGCheckTypePragmasTest", "selector": "testProjectTypeAnnotationsAreValid"})
        result["operation"] = "check-type-pragmas"
        return result
    if args.command == "gui":
        return launch_gui_workspace(paths, args.fresh)
    if args.command == "workspace":
        return workspace_status(paths) if args.action == "status" else reset_workspace(paths, args.confirm)
    if args.command == "staging":
        if args.action == "list":
            return list_staging(paths)
        return {"create": create_staging, "reset": reset_staging, "promote": promote_staging}[args.action](paths, args.name)
    if args.command == "agentic":
        request = {"operation": "test.all"} if args.test or args.eval is None else {"operation": "eval", "expression": args.eval, "profile": False}
        result = execute_agentic_session(paths, args.name, request)
        result["operation"] = "agentic"
        return result
    if args.command in {"inventory", "build-map"}:
        return inventory(paths)
    if args.command == "gc":
        return garbage_collect(paths, apply=args.apply)
    if args.command == "build-map-png":
        return export_build_map_pngs(paths, args.output, args.force)
    raise AssertionError(args.command)


def emit(result: dict[str, Any], as_json: bool) -> None:
    if "schema" in result:
        result = validate_named_record(result)
    if as_json:
        print(json.dumps(result, indent=2, sort_keys=True))
        return
    operation = result["operation"]
    if operation == "v2.recipe.list":
        for target in result["targets"]:
            print(f"{target['name']:12} recipe={target['recipe']} roles={','.join(target['roles'])}")
    elif operation == "v2.recipe.resolve":
        print(f"target: {result['target']} -> {result['outputKey']}")
        for step in result["steps"]:
            print(f"{step['role']:24} {step['checkpoint']:8} {step['outputKey']}")
    elif operation == "v2.build":
        for artifact in result["artifacts"]:
            print(f"{'reused' if artifact['reused'] else 'built ':6} {artifact['role']:24} {artifact['path']}")
    elif operation in {"test", "test-one", "check-type-pragmas", "agentic"}:
        report = result.get("data", {})
        print(f"Tests run: {report.get('runCount', 0)}, failures: {report.get('failureCount', 0)}, errors: {report.get('errorCount', 0)}")
    elif operation in {"eval", "smoke"}:
        print(result.get("data", {}).get("result", ""))
    elif operation == "inventory":
        print(f"inventory: {len(result['artifacts'])} artifacts, {len(result['references'])} refs, {len(result['workspaces'])} workspaces, {len(result['stagingAreas'])} staging areas")
        for artifact in result["artifacts"]:
            print(f"artifact {artifact.get('producingRole', '?'):24} {artifact.get('outputKey', '?')} {artifact['storage']['allocatedBytes']} allocated")
    elif operation == "gc":
        print(f"{result['mode']}: {len(result['remove'])} paths, {len(result['warnings'])} warnings")
        for item in result["remove"]:
            print(f"  {item['path']}")
    elif operation == "staging.list":
        for area in result["stagingAreas"]:
            print(f"{area['name']:20} {area['state']}")
    elif operation.startswith("staging."):
        print(f"{operation}: {result['path']}")
    elif operation == "status":
        print(f"workspace: {result['workspace'].get('workspace', {}).get('state', 'missing')}")
        for status in result["statuses"]:
            print(f"{status.get('state', '?'):10} {status.get('outputKey', '?')}")
    elif operation == "doctor":
        for item in result["tools"] + result["checks"]:
            print(f"{'ok' if item['ok'] else 'FAIL':4} {item.get('name', item.get('path'))}")
    elif operation.startswith("ui.") or operation.startswith("host."):
        if operation in {"host.windows.list", "host.windows.wait"}:
            for window in result["data"]["windows"]:
                pid = "-" if window["pid"] is None else str(window["pid"])
                geometry = f"{window['width']}x{window['height']}+{window['x']}+{window['y']}"
                print(f"{window['idHex']}\t{pid}\t{geometry}\t{window['title']}\t{window['command']}")
        else:
            print(json.dumps(result.get("data", result), indent=2, sort_keys=True))
    elif operation in {"code.class", "code.method", "lepiter.export"}:
        print(result["data"]["text"], end="")
    elif operation == "code.search":
        for item in result["data"]["results"]:
            print(json.dumps(item, sort_keys=True))
    elif operation == "lepiter.search":
        for item in result["data"]["results"]:
            print(f"{item['database']}\t{item['uid']}\t{item['title']}\t{item['preview']}")
    else:
        print(json.dumps(result, indent=2, sort_keys=True))


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    paths = BuildPaths.discover()
    try:
        value = _result(paths, args)
        if isinstance(value, int):
            return value
        emit(value, getattr(args, "json", False))
        return 0 if value.get("ok", True) else 1
    except (OSError, ValueError, RuntimeError, TimeoutError, ProcessExecutionError) as error:
        print(f"{args.command}: {error}", file=sys.stderr)
        return 2


__all__ = ["emit", "main", "parser"]
