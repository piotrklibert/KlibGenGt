from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Any

from .core import BuildPaths, command_status, digest_json, load_context, load_layers, platform_id
from .sources import expected_lock, host_facts, jj_identity, resolve_git_head, validate_lock
from .artifacts import build_artifact, build_l06, graph
from .runs import clean_runs, create_project_run, create_run, process_is_alive
from .operations import compatibility_context, execute, execute_image_tool, fresh_test, launch_gui
from .lifecycle import (
    clear_current_snapshot, clear_gui_refresh, current_snapshot_id, discard_run, find_snapshot, gui_refresh, list_snapshots, promote_packages,
    resume_snapshot, select_snapshot, snapshot_current, snapshot_run,
)
from .contexts import add_git_worktree, create_context, list_contexts, remove_context, remove_git_worktree
from .retention import garbage_collect, pin_artifact, unpin_artifact
from .sources import project_workspace
from .processes import ProcessExecutionError
from .host_tools import (
    WindowSelector,
    X11DesktopBackend,
    process_data,
    process_list,
    profile_command,
    require_one_window,
    select_windows,
    terminate_process,
    wait_for_processes,
    wait_for_windows,
    window_data,
)


def doctor(paths: BuildPaths, context_id: str) -> dict[str, Any]:
    context = load_context(paths, context_id)
    tools = [command_status(name) for name in (
        "bash", "jj", "git", "just", "uv", "sha256sum", "unzip",
        "xprop", "xdotool", "import",
    )]
    required = [paths.root / "justfile", paths.root / "src", paths.root / "export" / ".git"]
    checks = [{"kind": "path", "path": str(path), "ok": path.exists()} for path in required]
    state_parent = paths.state.parent
    writable = os.access(state_parent, os.W_OK)
    checks.append({"kind": "state-parent", "path": str(state_parent), "ok": writable})
    workspace = project_workspace(paths, context["project"]["workspace"])
    checks.append({"kind": "jj-workspace", "path": str(workspace), "ok": (workspace / ".jj").exists()})
    try:
        identity = jj_identity(paths, context["project"]["revision"], context["project"]["workspace"])
        checks.append({"kind": "jj-conflicts", "path": str(workspace), "ok": not identity["conflicts"], "conflicts": identity["conflicts"]})
    except (OSError, RuntimeError, ValueError, ProcessExecutionError) as error:
        checks.append({"kind": "jj-identity", "path": str(workspace), "ok": False, "error": str(error)})
    for layer_id in ("L03", "L04"):
        selection = context["layers"].get(layer_id, {})
        worktrees = []
        if selection.get("worktree"):
            worktrees.append(selection["worktree"])
        worktrees += [item["worktree"] for item in selection.get("dependencyOverrides", {}).values() if item.get("worktree")]
        checks += [{"kind": "git-worktree", "path": str(Path(item)), "ok": (Path(item) / ".git").exists()} for item in worktrees]
    ok = all(item["ok"] for item in tools + checks)
    return {
        "schemaVersion": 1,
        "operation": "doctor",
        "contextId": context["contextId"],
        "platform": platform_id(),
        "stateRoot": str(paths.state),
        "ok": ok,
        "tools": tools,
        "checks": checks,
    }


def status(paths: BuildPaths, context_id: str) -> dict[str, Any]:
    context = load_context(paths, context_id)
    layers = []
    parent_key = None
    for node in graph(paths, context_id):
        definition = node["definition"]
        layer_id = definition["layerId"]
        expected = node["buildKey"]
        artifact = node["artifact"]
        current = (artifact / "manifest.json").is_file()
        available = sorted(str(path.parent) for path in artifact.parent.glob("*/manifest.json")) if artifact.parent.exists() else []
        state = "current" if current else ("stale" if available else "missing")
        layers.append({
            "layerId": layer_id,
            "name": definition["name"],
            "expectedBuildKey": expected,
            "artifactPath": str(artifact),
            "state": state,
            "reason": None if current else ("available artifacts have different build keys" if available else "no successful artifact has been built"),
            "availableArtifacts": available,
        })
        parent_key = expected
    runs_root = paths.state / "runs" / context_id
    snapshots_root = paths.state / "snapshots" / context_id
    runs = [json.loads(path.read_text(encoding="utf-8")) for path in sorted(runs_root.glob("*/run.json"))]
    for run in runs:
        run["active"] = process_is_alive(run.get("pid"))
    snapshots = [json.loads(path.read_text(encoding="utf-8")) for path in sorted(snapshots_root.glob("*/snapshot.json"))]
    current_gui_snapshot = current_snapshot_id(paths, context_id)
    return {
        "schemaVersion": 1,
        "operation": "status",
        "contextId": context_id,
        "platform": platform_id(),
        "stateRoot": str(paths.state),
        "layers": layers,
        "runs": runs,
        "snapshots": snapshots,
        "currentGuiSnapshotId": current_gui_snapshot,
        "guiRefresh": gui_refresh(paths, context_id),
    }


def build(paths: BuildPaths, context_id: str, target: str, force: bool = False) -> dict[str, Any]:
    artifact = build_artifact(paths, context_id, target, force=force)
    manifest = json.loads((artifact / "manifest.json").read_text(encoding="utf-8"))
    return {"schemaVersion": 1, "operation": "build", "contextId": context_id, "target": target, "forced": force, "artifactPath": str(artifact), "buildKey": manifest["buildKey"]}


def resolve(paths: BuildPaths, context_id: str, update: bool) -> dict[str, Any]:
    context = load_context(paths, context_id)
    lock_path = paths.root / "build" / "locks" / f"{context_id}.lock.json"
    current = json.loads(lock_path.read_text(encoding="utf-8"))
    validate_lock(current)
    sqlite = next(item for item in current["sources"] if item["sourceId"] == "sqlite3")
    commit = resolve_git_head(sqlite["source"], sqlite["requested"]["branch"]) if update else sqlite["resolved"]["commit"]
    wanted = expected_lock(paths, commit)
    if update:
        lock_path.write_text(json.dumps(wanted, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        current = wanted
    elif current != wanted:
        raise ValueError(f"lock is stale: run just resolve-update {context_id}")
    baseline = (paths.root / "src" / "BaselineOfKlibGenGt" / "BaselineOfKlibGenGt.class.st").read_text(encoding="utf-8")
    if commit not in baseline:
        raise ValueError(f"SQLite baseline does not use locked commit {commit}")
    return {
        "schemaVersion": 1,
        "operation": "resolve",
        "contextId": context["contextId"],
        "updated": update,
        "lockPath": str(lock_path),
        "host": host_facts(),
        "projectSource": jj_identity(paths, context["project"]["revision"], context["project"]["workspace"]),
        "sources": current["sources"],
    }


def emit(result: dict[str, Any], as_json: bool) -> None:
    if as_json:
        print(json.dumps(result, indent=2, sort_keys=True))
        return
    if result["operation"] == "doctor":
        print(f"context: {result['contextId']}")
        print(f"state:   {result['stateRoot']}")
        for item in result["tools"] + result["checks"]:
            label = item.get("name", item.get("path"))
            print(f"{'ok' if item['ok'] else 'FAIL':4} {label}")
        return
    if result["operation"] == "resolve":
        action = "updated" if result["updated"] else "verified"
        print(f"{action}: {result['lockPath']}")
        print(f"project JJ commit: {result['projectSource']['commitId']}")
        return
    if result["operation"] == "status":
        print(f"context: {result['contextId']}")
        for layer in result["layers"]:
            print(f"{layer['layerId']}: {layer['state']}")
        refresh = result.get("guiRefresh")
        if refresh is None:
            print("GUI refresh: none")
        else:
            print(
                f"GUI refresh: {refresh['state']} generation={refresh['generation']} "
                f"run={refresh['sourceRunId']} packages={','.join(refresh['packages'])}"
            )
            if refresh.get("failureDetails"):
                print(f"GUI refresh failure: {refresh['failureDetails'].get('message', 'unknown')}")
        return
    if result["operation"] == "build":
        print(f"{result['target']}[{result['contextId']}]: {result['artifactPath']}")
        return
    if result["operation"] == "run":
        print(f"run {result['runId']}: {result['runPath']}")
        return
    if result["operation"] == "clean-runs":
        print(f"removed {result['removed']} run(s) for {result['contextId']}")
        return
    if result["operation"] == "snapshot":
        print(f"snapshot {result['snapshotId']}: {result['snapshotPath']}")
        return
    if result["operation"] == "resume":
        print(f"resumed as run {result['runId']}: {result['runPath']}")
        return
    if result["operation"] == "snapshot-list":
        for snapshot in result["snapshots"]:
            print(f"{'*' if snapshot['current'] else ' '} {snapshot['snapshotId']} {snapshot['createdAt']} {snapshot['classification']}")
        return
    if result["operation"] == "snapshot-current":
        print(result["snapshotId"] or "none")
        return
    if result["operation"] in {"snapshot-select", "snapshot-clear"}:
        print(json.dumps(result, indent=2, sort_keys=True))
        return
    if result["operation"] == "gui-refresh-clear":
        print(json.dumps(result, indent=2, sort_keys=True))
        return
    if result["operation"] == "discard":
        print(f"discarded {result['recordKind']} {result['recordId']}")
        return
    if result["operation"] == "promote":
        print(f"promoted {', '.join(result['packages'])} from {result['sourceKind']} {result['sourceId']}")
        if result.get("guiRefreshRequested"):
            print("GUI refresh requested")
        return
    if result["operation"] == "context-list":
        for context in result["contexts"]:
            print(f"{context['contextId']:20} {'generated' if context['generated'] else 'committed':9} {context['project']['workspace']}")
        return
    if result["operation"] in {"context-create", "context-remove", "worktree-add", "worktree-remove", "pin", "unpin", "gc"}:
        print(json.dumps(result, indent=2, sort_keys=True))
        return
    if not result.get("ok", True):
        error = result.get("error", {})
        print(f"{error.get('class', 'Error')}: {error.get('message', 'operation failed')}", file=sys.stderr)
        for frame in error.get("stack", []):
            print(frame, file=sys.stderr)
        if result.get("runPath"):
            print(f"retained run: {result['runPath']}", file=sys.stderr)
        return
    if result["operation"] in {"test", "smoke", "check-type-pragmas", "eval"} and "output" in result:
        print(result["output"], end="")
        return
    if result["operation"] == "load":
        print(f"L06[{result['contextId']}] loaded and verified: {result['artifactPath']}")
        return
    if result["operation"] in {"host.windows.list", "host.windows.wait"}:
        for window in result["data"]["windows"]:
            pid = "-" if window["pid"] is None else str(window["pid"])
            geometry = f"{window['width']}x{window['height']}+{window['x']}+{window['y']}"
            print(f"{window['idHex']}\t{pid}\t{geometry}\t{window['title']}\t{window['command']}")
        return
    if result["operation"] in {"host.processes.list", "host.processes.wait"}:
        for process in result["data"]["processes"]:
            print(f"{process['pid']}\t{process['state']}\t{process['command']}")
        return
    if result["operation"] == "host.windows.screenshot":
        print(result["data"]["path"])
        return
    if result["operation"] in {"host.windows.focus", "host.windows.close", "host.processes.terminate"}:
        print(json.dumps(result["data"], sort_keys=True))
        return
    if result["operation"] == "host.profile":
        metrics = result["metrics"]
        print(
            f"profile: exit={result['data']['exitCode']} "
            f"wall={metrics['wallTimeNs'] / 1_000_000:.3f}ms "
            f"user={metrics['userCpuTimeNs'] / 1_000_000:.3f}ms "
            f"system={metrics['systemCpuTimeNs'] / 1_000_000:.3f}ms",
            file=sys.stderr,
        )
        return
    if result["operation"] == "code.search":
        for item in result["data"]["results"]:
            if item["kind"] == "class":
                print(f"class\t{item['class']}\t{item['package']}")
            else:
                print(f"method\t{item['class']}\t{item['side']}\t{item['selector']}\t{item['package']}")
        return
    if result["operation"] in {"code.class", "code.method", "lepiter.export"}:
        print(result["data"]["text"], end="")
        return
    if result["operation"] == "lepiter.search":
        for item in result["data"]["results"]:
            print(f"{item['database']}\t{item['uid']}\t{item['title']}\t{item['preview']}")
        return
    if result["operation"] == "eval":
        print(result["data"]["result"])
        profile = result["data"].get("profile")
        if profile:
            print(profile["report"], file=sys.stderr, end="")
        return
    print(f"context: {result['contextId']}")
    for layer in result["layers"]:
        print(f"{layer['layerId']} {layer['state']:7} {layer['name']} ({layer['expectedBuildKey'][:12]})")


def _add_window_selector(command: argparse.ArgumentParser) -> None:
    command.add_argument("--id", dest="window_id", type=lambda value: int(value, 0))
    command.add_argument("--pid", type=int)
    command.add_argument("--title-regex")
    command.add_argument("--command-regex")


def _host_parser(subparsers: argparse._SubParsersAction) -> None:
    host = subparsers.add_parser("host")
    areas = host.add_subparsers(dest="host_area", required=True)

    windows = areas.add_parser("windows")
    window_commands = windows.add_subparsers(dest="host_action", required=True)
    for name in ("list", "wait", "screenshot", "focus", "close"):
        command = window_commands.add_parser(name)
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
    process_commands = processes.add_subparsers(dest="host_action", required=True)
    for name in ("list", "wait", "terminate"):
        command = process_commands.add_parser(name)
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
    code_commands = code.add_subparsers(dest="image_action", required=True)
    search = code_commands.add_parser("search")
    search.add_argument("query")
    search.add_argument("--kind", choices=("all", "class", "method"), default="all")
    search.add_argument("--package")
    search.add_argument("--limit", type=int, default=100)
    class_definition = code_commands.add_parser("class")
    class_definition.add_argument("class_name")
    method = code_commands.add_parser("method")
    method.add_argument("class_name")
    method.add_argument("selector")
    method.add_argument("--side", choices=("instance", "class"), default="instance")

    lepiter = areas.add_parser("lepiter")
    lepiter_commands = lepiter.add_subparsers(dest="image_action", required=True)
    lepiter_search = lepiter_commands.add_parser("search")
    lepiter_search.add_argument("query")
    lepiter_search.add_argument("--in", dest="search_in", choices=("text", "title"), default="text")
    lepiter_search.add_argument("--database", dest="databases", action="append", default=[])
    lepiter_search.add_argument("--limit", type=int, default=100)
    export = lepiter_commands.add_parser("export")
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
        command.add_argument("--context", default="default")
        command.add_argument("--json", action="store_true")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(prog="klibgen-build")
    subparsers = result.add_subparsers(dest="command", required=True)
    _host_parser(subparsers)
    _image_parser(subparsers)
    for name in ("doctor", "status", "resolve", "build", "run", "clean-runs", "load", "test", "smoke", "check-type-pragmas", "eval", "launch", "gui-fresh", "gui-snapshot", "snapshot", "resume", "discard", "promote", "snapshot-list", "snapshot-current", "snapshot-select", "snapshot-clear", "gui-refresh-clear", "context-list", "context-create", "context-remove", "worktree-add", "worktree-remove", "pin", "unpin", "gc"):
        command = subparsers.add_parser(name)
        if name == "build":
            command.add_argument("target")
            command.add_argument("context", nargs="?", default="default")
            command.add_argument("--force", action="store_true")
        elif name == "run":
            command.add_argument("profile", nargs="?", default="base")
            command.add_argument("context", nargs="?", default="default")
        elif name == "eval":
            command.add_argument("profile", nargs="?", default="cli")
            command.add_argument("context", nargs="?", default="default")
        elif name == "launch":
            command.add_argument("profile", choices=("gui",))
            command.add_argument("context", nargs="?", default="gui")
        elif name == "gui-fresh":
            command.add_argument("context", nargs="?", default="gui")
        elif name == "gui-snapshot":
            command.add_argument("snapshot_id")
        elif name in {"snapshot-list", "snapshot-current", "snapshot-clear", "gui-refresh-clear"}:
            command.add_argument("context", nargs="?", default="gui")
        elif name == "snapshot-select":
            command.add_argument("snapshot_id")
            command.add_argument("context", nargs="?", default="gui")
        elif name in {"snapshot", "resume", "discard"}:
            command.add_argument("record_id")
        elif name == "promote":
            command.add_argument("source_id")
            command.add_argument("packages", help="comma-separated explicit package names")
            command.add_argument("context", nargs="?", default="default")
        elif name == "context-create":
            command.add_argument("context_id")
            command.add_argument("revision", nargs="?", default="@")
            command.add_argument("template", nargs="?", default="default")
        elif name == "context-remove":
            command.add_argument("context_id")
        elif name == "worktree-add":
            command.add_argument("context_id")
            command.add_argument("role")
            command.add_argument("repository")
            command.add_argument("revision", nargs="?", default="HEAD")
        elif name == "worktree-remove":
            command.add_argument("context_id")
            command.add_argument("role")
        elif name == "pin":
            command.add_argument("context")
            command.add_argument("layer")
            command.add_argument("name", nargs="?")
        elif name == "unpin":
            command.add_argument("name")
        elif name in {"context-list", "gc"}:
            pass
        else:
            command.add_argument("context", nargs="?", default="default")
        command.add_argument("--json", action="store_true")
        if name == "resolve":
            command.add_argument("--update", action="store_true")
        if name == "test":
            command.add_argument("--fresh", action="store_true")
    return result


def _window_selector(args: argparse.Namespace) -> WindowSelector:
    return WindowSelector(args.window_id, args.pid, args.title_regex, args.command_regex)


def _host_command(paths: BuildPaths, args: argparse.Namespace) -> dict[str, Any]:
    operation = (
        "host.profile"
        if args.host_area == "profile"
        else f"host.{args.host_area}.{args.host_action}"
    )
    if args.host_area == "windows":
        backend = X11DesktopBackend()
        selector = _window_selector(args)
        if args.host_action == "list":
            windows = select_windows(backend.windows(), selector)
            return {"schemaVersion": 1, "ok": True, "operation": operation, "data": {"windows": window_data(windows)}}
        if args.host_action == "wait":
            windows = wait_for_windows(backend, selector, args.wait_for == "present", args.timeout)
            return {"schemaVersion": 1, "ok": True, "operation": operation, "data": {"windows": window_data(windows)}}
        window = require_one_window(backend, selector)
        if args.host_action == "screenshot":
            output = args.output
            if output is None:
                stamp = time.strftime("%Y%m%d-%H%M%S")
                output = paths.root / "tmp/screenshots" / f"{stamp}-{window.id_hex}.png"
            elif not output.is_absolute():
                output = paths.root / output
            backend.screenshot(window, output)
            return {
                "schemaVersion": 1, "ok": True, "operation": operation,
                "data": {"path": str(output), "window": window_data([window])[0]},
            }
        if args.host_action == "focus":
            backend.focus(window)
        else:
            backend.close(window)
            wait_for_windows(backend, WindowSelector(window_id=window.id), False, args.timeout)
        return {
            "schemaVersion": 1, "ok": True, "operation": operation,
            "data": {"window": window_data([window])[0]},
        }

    if args.host_area == "processes":
        if args.host_action == "list":
            processes = process_list(args.pid, args.command_regex)
            return {"schemaVersion": 1, "ok": True, "operation": operation, "data": {"processes": process_data(processes)}}
        if args.host_action == "wait":
            processes = wait_for_processes(args.pid, args.command_regex, args.wait_for == "present", args.timeout)
            return {"schemaVersion": 1, "ok": True, "operation": operation, "data": {"processes": process_data(processes)}}
        if args.pid is None:
            raise ValueError("process termination requires --pid")
        data = terminate_process(args.pid, args.timeout, args.force)
        return {"schemaVersion": 1, "ok": True, "operation": operation, "data": data}

    command = args.profile_command
    if command and command[0] == "--":
        command = command[1:]
    profiled = profile_command(command, capture=args.json)
    return {
        "schemaVersion": 1, "ok": True, "operation": operation,
        "data": {key: value for key, value in profiled.items() if key != "metrics"},
        "metrics": profiled["metrics"],
    }


def _evaluation_expression(args: argparse.Namespace) -> str:
    choices = sum((args.expression is not None, args.file is not None, args.stdin))
    if choices != 1:
        raise ValueError("provide exactly one eval expression, --file, or --stdin")
    if args.file is not None:
        return args.file.read_text(encoding="utf-8")
    if args.stdin:
        return sys.stdin.read()
    return args.expression


def _image_command(paths: BuildPaths, args: argparse.Namespace) -> dict[str, Any]:
    if args.image_area == "code":
        if args.image_action == "search":
            request = {
                "operation": "code.search", "query": args.query, "kind": args.kind,
                "package": args.package, "limit": args.limit,
            }
            if args.package is None:
                request.pop("package")
        elif args.image_action == "class":
            request = {"operation": "code.class", "class": args.class_name}
        else:
            request = {
                "operation": "code.method", "class": args.class_name,
                "selector": args.selector, "side": args.side,
            }
    elif args.image_area == "lepiter":
        if args.image_action == "search":
            request = {
                "operation": "lepiter.search", "query": args.query, "in": args.search_in,
                "databases": args.databases, "limit": args.limit,
            }
        else:
            request = {
                "operation": "lepiter.export", "uid": args.uid, "title": args.title,
                "databases": args.databases,
            }
            if args.uid is None:
                request.pop("uid")
            if args.title is None:
                request.pop("title")
    else:
        request = {
            "operation": "eval", "expression": _evaluation_expression(args), "profile": args.profile,
        }
    return execute_image_tool(paths, args.context, request)


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    paths = BuildPaths.discover()
    try:
        if args.command == "host":
            result = _host_command(paths, args)
        elif args.command == "image":
            result = _image_command(paths, args)
        elif args.command == "doctor":
            result = doctor(paths, args.context)
        elif args.command == "status":
            result = status(paths, args.context)
        elif args.command == "resolve":
            result = resolve(paths, args.context, args.update)
        elif args.command == "build":
            result = build(paths, args.context, args.target, args.force)
        elif args.command == "run":
            selected = compatibility_context(args.context, args.profile.lower())
            creator = create_run if args.profile.lower() == "base" else create_project_run
            result = {"schemaVersion": 1, "operation": "run"} | creator(paths, selected, args.profile)
        elif args.command == "clean-runs":
            result = {"schemaVersion": 1, "operation": "clean-runs", "contextId": args.context, "removed": clean_runs(paths, args.context)}
        elif args.command == "load":
            selected = compatibility_context(args.context)
            artifact = build_l06(paths, selected)
            result = {"schemaVersion": 1, "operation": "load", "contextId": selected, "artifactPath": str(artifact)}
        elif args.command == "test":
            result = fresh_test(paths, args.context) if args.fresh else execute(paths, args.context, "test")
        elif args.command in {"smoke", "check-type-pragmas"}:
            result = execute(paths, args.context, args.command)
        elif args.command == "eval":
            if args.profile.lower() != "cli":
                raise ValueError("non-interactive eval currently supports only the cli profile")
            expression = os.environ.get("GT_EVAL")
            if expression is None:
                raise ValueError("GT_EVAL is missing")
            result = execute_image_tool(
                paths, args.context,
                {"operation": "eval", "expression": expression, "profile": False},
            )
        elif args.command == "snapshot":
            result = snapshot_run(paths, args.record_id)
        elif args.command == "resume":
            result = resume_snapshot(paths, args.record_id)
        elif args.command == "discard":
            result = discard_run(paths, args.record_id)
        elif args.command == "promote":
            packages = [item.strip() for item in args.packages.split(",") if item.strip()]
            result = promote_packages(paths, args.source_id, packages, args.context)
        elif args.command == "snapshot-list":
            result = list_snapshots(paths, args.context)
        elif args.command == "snapshot-current":
            result = snapshot_current(paths, args.context)
        elif args.command == "snapshot-select":
            result = select_snapshot(paths, args.context, args.snapshot_id)
        elif args.command == "snapshot-clear":
            result = clear_current_snapshot(paths, args.context)
        elif args.command == "gui-refresh-clear":
            result = clear_gui_refresh(paths, args.context)
        elif args.command == "context-list":
            result = list_contexts(paths)
        elif args.command == "context-create":
            result = create_context(paths, args.context_id, args.revision, args.template)
        elif args.command == "context-remove":
            result = remove_context(paths, args.context_id)
        elif args.command == "worktree-add":
            result = add_git_worktree(paths, args.context_id, args.role, args.repository, args.revision)
        elif args.command == "worktree-remove":
            result = remove_git_worktree(paths, args.context_id, args.role)
        elif args.command == "pin":
            result = pin_artifact(paths, args.context, args.layer, args.name)
        elif args.command == "unpin":
            result = unpin_artifact(paths, args.name)
        elif args.command == "gc":
            result = garbage_collect(paths)
        elif args.command == "gui-fresh":
            return launch_gui(paths, args.context, fresh=True)
        elif args.command == "gui-snapshot":
            snapshot_path = find_snapshot(paths, args.snapshot_id)
            snapshot = json.loads((snapshot_path / "snapshot.json").read_text(encoding="utf-8"))
            return launch_gui(paths, snapshot["contextId"], snapshot_id=args.snapshot_id, advance_current=False)
        else:
            return launch_gui(paths, args.context)
    except (OSError, RuntimeError, ValueError, TimeoutError, re.error, json.JSONDecodeError, ProcessExecutionError) as error:
        context = getattr(args, "context", "-")
        print(f"{args.command}[{context}]: {error}", file=sys.stderr)
        return 2
    emit(result, args.json)
    if result["operation"] == "host.profile":
        return int(result["data"]["exitCode"])
    return result.get("exitCode", 0) if result.get("ok", True) else 1
