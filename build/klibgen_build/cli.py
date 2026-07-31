from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

from .core import BuildPaths, command_status, digest_json, load_context, load_layers, platform_id


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
    for definition in load_layers(paths):
        layer_id = definition["layerId"]
        inputs = {"definition": definition, "context": context["layers"].get(layer_id, {}), "parent": parent_key}
        expected = digest_json(inputs)
        artifact = paths.state / "artifacts" / platform_id() / context_id / layer_id.lower() / expected
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
    print(f"context: {result['contextId']}")
    for layer in result["layers"]:
        print(f"{layer['layerId']} {layer['state']:7} {layer['name']} ({layer['expectedBuildKey'][:12]})")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(prog="klibgen-build")
    subparsers = result.add_subparsers(dest="command", required=True)
    for name in ("doctor", "status"):
        command = subparsers.add_parser(name)
        command.add_argument("context", nargs="?", default="default")
        command.add_argument("--json", action="store_true")
    return result


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    paths = BuildPaths.discover()
    try:
        result = doctor(paths, args.context) if args.command == "doctor" else status(paths, args.context)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"{args.command}[{args.context}]: {error}", file=sys.stderr)
        return 2
    emit(result, args.json)
    return 0 if result.get("ok", True) else 1
