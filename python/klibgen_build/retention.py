from __future__ import annotations

import json
import shutil
from collections import Counter
from pathlib import Path
from typing import Any

from .artifacts import graph, set_tree_writable
from .coordination import retention_lock, with_shared_retention_lock
from .core import BuildPaths
from .runs import process_is_alive


@with_shared_retention_lock
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


@with_shared_retention_lock
def unpin_artifact(paths: BuildPaths, name: str) -> dict[str, Any]:
    path = paths.state / "state/pins" / f"{name}.json"
    if not path.is_file():
        raise ValueError(f"unknown pin {name!r}")
    path.unlink()
    return {"schemaVersion": 1, "operation": "unpin", "pin": name, "removed": True}


def _logical_size(path: Path) -> int:
    if not path.exists() and not path.is_symlink():
        return 0
    if path.is_file() or path.is_symlink():
        return path.lstat().st_size
    total = 0
    for item in path.rglob("*"):
        try:
            if item.is_file() or item.is_symlink():
                total += item.lstat().st_size
        except FileNotFoundError:
            continue
    return total


def _entry(kind: str, path: Path, reason: str, **details: Any) -> dict[str, Any]:
    return {
        "kind": kind,
        "path": str(path.resolve()),
        "reason": reason,
        "logicalBytes": _logical_size(path),
    } | details


def _artifact_paths(paths: BuildPaths, context_id: str | None = None) -> list[Path]:
    pattern = f"*/{context_id}/l*/*" if context_id else "*/*/l*/*"
    return sorted(path.resolve() for path in (paths.state / "artifacts").glob(pattern) if path.is_dir())


def _within_artifacts(paths: BuildPaths, artifact: Path) -> Path:
    resolved = artifact.resolve()
    try:
        resolved.relative_to((paths.state / "artifacts").resolve())
    except ValueError as error:
        raise ValueError(f"retention reference is outside the artifact store: {artifact}") from error
    return resolved


def _active_run(metadata: dict[str, Any]) -> bool:
    return process_is_alive(metadata.get("pid")) or process_is_alive(metadata.get("coordinatorPid"))


def _plan(paths: BuildPaths, operation: str) -> dict[str, Any]:
    if operation not in {"gc", "prune"}:
        raise ValueError(f"unknown retention operation {operation!r}")
    preserved: dict[Path, dict[str, Any]] = {}
    candidates: dict[Path, dict[str, Any]] = {}
    skipped_contexts: list[str] = []

    def preserve(kind: str, path: Path, reason: str, **details: Any) -> None:
        resolved = path.resolve()
        if resolved not in preserved:
            preserved[resolved] = _entry(kind, resolved, reason, **details)

    def candidate(kind: str, path: Path, reason: str, **details: Any) -> None:
        resolved = path.resolve()
        if resolved not in preserved and resolved not in candidates:
            candidates[resolved] = _entry(kind, resolved, reason, **details)

    def preserve_ancestors(artifact: Path, reason: str) -> None:
        artifact = _within_artifacts(paths, artifact)
        manifest_path = artifact / "manifest.json"
        if not manifest_path.is_file():
            return
        preserve("artifact", artifact, reason)
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        for parent in manifest.get("parents", []):
            parent_path = (
                paths.state / "artifacts" / manifest["platform"] / manifest["contextId"] /
                parent["layerId"].lower() / parent["buildKey"]
            )
            preserve_ancestors(parent_path, reason)

    if operation == "gc":
        context_files = sorted(
            list((paths.root / "build/contexts").glob("*.json")) +
            list((paths.state / "contexts").glob("*.json"))
        )
        for context_id in sorted({path.stem for path in context_files}):
            try:
                for node in graph(paths, context_id):
                    if (node["artifact"] / "manifest.json").is_file():
                        preserve("artifact", node["artifact"], "current-context-artifact", contextId=context_id)
            except (OSError, RuntimeError, ValueError):
                skipped_contexts.append(context_id)
                for artifact in _artifact_paths(paths, context_id):
                    preserve("artifact", artifact, "unresolved-context-protection", contextId=context_id)
        for snapshot_file in sorted((paths.state / "snapshots").glob("*/*/snapshot.json")):
            value = json.loads(snapshot_file.read_text(encoding="utf-8"))
            preserve_ancestors(Path(value["parentL06Artifact"]), "snapshot-ancestry")
            if value.get("parentL01Artifact"):
                preserve_ancestors(Path(value["parentL01Artifact"]), "snapshot-ancestry")
    else:
        for context_id in ("default", "gui"):
            try:
                nodes = graph(paths, context_id)
            except (OSError, RuntimeError, ValueError) as error:
                raise ValueError(f"cannot resolve required prune context {context_id!r}: {error}") from error
            for node in nodes:
                if (node["artifact"] / "manifest.json").is_file():
                    preserve("artifact", node["artifact"], "prune-current-artifact", contextId=context_id)

    for pin_file in sorted((paths.state / "state/pins").glob("*.json")):
        value = json.loads(pin_file.read_text(encoding="utf-8"))
        artifact = _within_artifacts(paths, Path(value["artifactPath"]))
        if not (artifact / "manifest.json").is_file():
            raise ValueError(f"pin {value.get('pin', pin_file.stem)!r} references a missing artifact: {artifact}")
        preserve("artifact", artifact, "explicit-pin", pin=value.get("pin", pin_file.stem))

    known_runs: set[Path] = set()
    for metadata_path in sorted((paths.state / "runs").glob("*/*/run.json")):
        run_path = metadata_path.parent.resolve()
        known_runs.add(run_path)
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        if _active_run(metadata):
            preserve("run", run_path, "active-run", runId=metadata.get("runId"))
            for key in ("parentArtifact", "runtimeArtifact"):
                if metadata.get(key):
                    preserve_ancestors(Path(metadata[key]), "active-run-ancestry")
        elif operation == "prune":
            candidate("run", run_path, "inactive-run", runId=metadata.get("runId"))
    if operation == "prune":
        for run_path in sorted(path.resolve() for path in (paths.state / "runs").glob("*/*") if path.is_dir()):
            if run_path not in known_runs:
                candidate("run", run_path, "orphaned-run-without-metadata")

    for artifact in _artifact_paths(paths):
        candidate("artifact", artifact, "unreferenced-artifact" if operation == "gc" else "not-current-default-or-gui")

    attempts = sorted(
        (path.resolve() for path in (paths.state / "tmp").glob("attempt-*") if path.is_dir()),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    keep_attempts = 3 if operation == "gc" else 0
    for index, attempt in enumerate(attempts):
        if index < keep_attempts:
            preserve("attempt", attempt, "recent-attempt-diagnostic")
        else:
            candidate("attempt", attempt, "old-attempt-diagnostic" if operation == "gc" else "prune-all-attempts")

    if operation == "prune":
        for snapshot_path in sorted(path.resolve() for path in (paths.state / "snapshots").glob("*/*") if path.is_dir()):
            candidate("snapshot", snapshot_path, "prune-all-snapshots")
        for pointer in sorted((paths.state / "state/gui").glob("*.json")):
            candidate("snapshot-pointer", pointer, "snapshot-selection-removed")
        rebuild_root = paths.state / "logs/rebuilds"
        if rebuild_root.exists():
            candidate("rebuild-log", rebuild_root, "prune-all-rebuild-logs")

    candidate_entries = sorted(candidates.values(), key=lambda item: (item["kind"], item["path"]))
    retained_entries = sorted(preserved.values(), key=lambda item: (item["kind"], item["path"]))
    counts = Counter(item["kind"] for item in candidate_entries)
    retained_counts = Counter(item["kind"] for item in retained_entries)
    return {
        "schemaVersion": 1,
        "operation": operation,
        "stateRoot": str(paths.state),
        "candidates": candidate_entries,
        "retained": retained_entries,
        "candidateCounts": dict(sorted(counts.items())),
        "retainedCounts": dict(sorted(retained_counts.items())),
        "estimatedLogicalBytes": sum(item["logicalBytes"] for item in candidate_entries),
        "skippedContexts": sorted(set(skipped_contexts)),
    }


def retention_plan(paths: BuildPaths, operation: str) -> dict[str, Any]:
    return _plan(paths, operation) | {"dryRun": True, "removed": [], "removedCounts": {}}


def _remove(path: Path) -> None:
    if path.is_dir() and not path.is_symlink():
        set_tree_writable(path, True)
        shutil.rmtree(path)
    else:
        path.unlink(missing_ok=True)


def _remove_empty_cache_directories(paths: BuildPaths) -> None:
    roots = [paths.state / name for name in ("artifacts", "runs", "snapshots", "tmp", "logs/rebuilds")]
    for root in roots:
        if not root.is_dir():
            continue
        directories = sorted((item for item in root.rglob("*") if item.is_dir()), key=lambda item: len(item.parts), reverse=True)
        for directory in directories:
            try:
                directory.rmdir()
            except OSError:
                pass


def apply_retention(paths: BuildPaths, operation: str) -> dict[str, Any]:
    with retention_lock(paths, exclusive=True):
        plan = _plan(paths, operation)
        removed = []
        state_root = paths.state.resolve()
        ordered = sorted(plan["candidates"], key=lambda item: len(Path(item["path"]).parts), reverse=True)
        for entry in ordered:
            try:
                Path(entry["path"]).relative_to(state_root)
            except ValueError as error:
                raise ValueError(f"refusing to remove path outside state root: {entry['path']}") from error
        for entry in ordered:
            path = Path(entry["path"])
            _remove(path)
            removed.append(entry)
        _remove_empty_cache_directories(paths)
        removed_counts = Counter(item["kind"] for item in removed)
        return plan | {"dryRun": False, "removed": removed, "removedCounts": dict(sorted(removed_counts.items()))}


def garbage_collect(paths: BuildPaths, dry_run: bool = False) -> dict[str, Any]:
    result = retention_plan(paths, "gc") if dry_run else apply_retention(paths, "gc")
    result["removedArtifacts"] = [item["path"] for item in result["removed"] if item["kind"] == "artifact"]
    result["removedAttempts"] = [item["path"] for item in result["removed"] if item["kind"] == "attempt"]
    result["preservedCount"] = len(result["retained"])
    return result


def prune(paths: BuildPaths, dry_run: bool = False) -> dict[str, Any]:
    return retention_plan(paths, "prune") if dry_run else apply_retention(paths, "prune")
