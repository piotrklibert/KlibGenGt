from __future__ import annotations

import json
import shutil
from pathlib import Path
from typing import Any

from .artifacts import graph, set_tree_writable
from .core import BuildPaths


def pin_artifact(paths: BuildPaths, context_id: str, layer_id: str, name: str | None = None) -> dict[str, Any]:
    normalized = layer_id.upper()
    node = next((item for item in graph(paths, context_id) if item["definition"]["layerId"] == normalized), None)
    if node is None or not (node["artifact"] / "manifest.json").is_file():
        raise ValueError(f"no current artifact for {normalized}[{context_id}]")
    pin_name = name or f"{context_id}-{normalized.lower()}"
    path = paths.state / "state/pins" / f"{pin_name}.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    value = {"schemaVersion": 1, "pin": pin_name, "contextId": context_id, "layerId": normalized, "artifactPath": str(node["artifact"]), "buildKey": node["buildKey"]}
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return {"operation": "pin"} | value


def unpin_artifact(paths: BuildPaths, name: str) -> dict[str, Any]:
    path = paths.state / "state/pins" / f"{name}.json"
    if not path.is_file():
        raise ValueError(f"unknown pin {name!r}")
    path.unlink()
    return {"schemaVersion": 1, "operation": "unpin", "pin": name, "removed": True}


def garbage_collect(paths: BuildPaths) -> dict[str, Any]:
    preserved: set[Path] = set()
    skipped_contexts: list[str] = []
    context_files = list((paths.root / "build/contexts").glob("*.json")) + list((paths.state / "contexts").glob("*.json"))
    for context_file in context_files:
        context_id = context_file.stem
        try:
            preserved.update(node["artifact"].resolve() for node in graph(paths, context_id) if (node["artifact"] / "manifest.json").is_file())
        except (OSError, RuntimeError, ValueError):
            skipped_contexts.append(context_id)
    def preserve_ancestors(artifact: Path) -> None:
        artifact = artifact.resolve()
        if artifact in preserved or not (artifact / "manifest.json").is_file():
            return
        preserved.add(artifact)
        manifest = json.loads((artifact / "manifest.json").read_text(encoding="utf-8"))
        for parent in manifest.get("parents", []):
            parent_path = (
                paths.state / "artifacts" / manifest["platform"] / manifest["contextId"] /
                parent["layerId"].lower() / parent["buildKey"]
            )
            preserve_ancestors(parent_path)

    for snapshot_file in (paths.state / "snapshots").glob("*/*/snapshot.json"):
        value = json.loads(snapshot_file.read_text(encoding="utf-8"))
        preserve_ancestors(Path(value["parentL06Artifact"]))
        if value.get("parentL01Artifact"):
            preserve_ancestors(Path(value["parentL01Artifact"]))
    for pin_file in (paths.state / "state/pins").glob("*.json"):
        value = json.loads(pin_file.read_text(encoding="utf-8"))
        preserved.add(Path(value["artifactPath"]).resolve())
    removed = []
    for manifest in (paths.state / "artifacts").glob("*/*/l*/*/manifest.json"):
        artifact = manifest.parent.resolve()
        if artifact in preserved:
            continue
        set_tree_writable(artifact, True)
        shutil.rmtree(artifact)
        removed.append(str(artifact))
    attempts = sorted((path for path in (paths.state / "tmp").glob("attempt-*") if path.is_dir()), key=lambda path: path.stat().st_mtime, reverse=True)
    removed_attempts = []
    for attempt in attempts[3:]:
        set_tree_writable(attempt, True)
        shutil.rmtree(attempt)
        removed_attempts.append(str(attempt))
    return {"schemaVersion": 1, "operation": "gc", "removedArtifacts": removed, "removedAttempts": removed_attempts, "preservedCount": len(preserved), "skippedContexts": sorted(set(skipped_contexts))}
