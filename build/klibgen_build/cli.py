from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

from .core import BuildPaths, command_status, digest_json, load_context, load_layers, platform_id
from .sources import expected_lock, host_facts, jj_identity, resolve_git_head, validate_lock
from .artifacts import build_artifact, build_l06, graph
from .runs import clean_runs, create_project_run, create_run
from .operations import compatibility_context, execute, fresh_test, launch_gui


def doctor(paths: BuildPaths, context_id: str) -> dict[str, Any]:
    context = load_context(paths, context_id)
    tools = [command_status(name) for name in ("bash", "jj", "git", "just", "python3", "sha256sum", "unzip")]
    required = [paths.root / "justfile", paths.root / "src", paths.root / "export" / ".git"]
    checks = [{"kind": "path", "path": str(path), "ok": path.exists()} for path in required]
    state_parent = paths.state.parent
    writable = os.access(state_parent, os.W_OK)
    checks.append({"kind": "state-parent", "path": str(state_parent), "ok": writable})
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
        layers.append({
            "layerId": layer_id,
            "name": definition["name"],
            "expectedBuildKey": expected,
            "artifactPath": str(artifact),
            "state": "current" if current else "missing",
            "reason": None if current else "matching successful artifact is absent",
        })
        parent_key = expected
    return {
        "schemaVersion": 1,
        "operation": "status",
        "contextId": context_id,
        "platform": platform_id(),
        "stateRoot": str(paths.state),
        "layers": layers,
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
        "projectSource": jj_identity(paths, context["project"]["revision"]),
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
    if result["operation"] == "build":
        print(f"{result['target']}[{result['contextId']}]: {result['artifactPath']}")
        return
    if result["operation"] == "run":
        print(f"run {result['runId']}: {result['runPath']}")
        return
    if result["operation"] == "clean-runs":
        print(f"removed {result['removed']} run(s) for {result['contextId']}")
        return
    if result["operation"] in {"test", "smoke", "check-type-pragmas", "eval"}:
        print(result["output"], end="")
        return
    if result["operation"] == "load":
        print(f"L06[{result['contextId']}] loaded and verified: {result['artifactPath']}")
        return
    print(f"context: {result['contextId']}")
    for layer in result["layers"]:
        print(f"{layer['layerId']} {layer['state']:7} {layer['name']} ({layer['expectedBuildKey'][:12]})")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(prog="klibgen-build")
    subparsers = result.add_subparsers(dest="command", required=True)
    for name in ("doctor", "status", "resolve", "build", "run", "clean-runs", "load", "test", "smoke", "check-type-pragmas", "eval", "launch"):
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
        else:
            command.add_argument("context", nargs="?", default="default")
        command.add_argument("--json", action="store_true")
        if name == "resolve":
            command.add_argument("--update", action="store_true")
        if name == "test":
            command.add_argument("--fresh", action="store_true")
    return result


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    paths = BuildPaths.discover()
    try:
        if args.command == "doctor":
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
            result = execute(paths, args.context, "eval", expression=expression)
        else:
            return launch_gui(paths, args.context)
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as error:
        print(f"{args.command}[{args.context}]: {error}", file=sys.stderr)
        return 2
    emit(result, args.json)
    return result.get("exitCode", 0) if result.get("ok", True) else 1
