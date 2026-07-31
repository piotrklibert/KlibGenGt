from __future__ import annotations

import json
import os
import shutil
import uuid
from pathlib import Path
from typing import Any

from .artifacts import copy_reflink, set_tree_writable, sha256_file, sha256_tree
from .core import BuildPaths, load_context, platform_id
from .runs import process_is_alive, utc_now
from .processes import run_command
from .sources import jj_identity, project_workspace


SNAPSHOT_COMPONENTS = ("image", "export", "home", "config", "data", "logs")


def _find_record(root: Path, record_id: str, metadata_name: str) -> Path:
    matches = list(root.glob(f"*/{record_id}/{metadata_name}"))
    if len(matches) != 1:
        raise ValueError(f"expected one {metadata_name} for {record_id!r}, found {len(matches)}")
    return matches[0].parent


def find_run(paths: BuildPaths, run_id: str) -> Path:
    return _find_record(paths.state / "runs", run_id, "run.json")


def find_snapshot(paths: BuildPaths, snapshot_id: str) -> Path:
    return _find_record(paths.state / "snapshots", snapshot_id, "snapshot.json")


def _bridge_changes(run_path: Path, metadata: dict[str, Any]) -> list[str]:
    bridge = run_path / "export"
    baseline = metadata.get("generatedBridgeCommit")
    if not (bridge / ".git").exists() or not baseline:
        return []
    result = run_command(["git", "-C", str(bridge), "diff", "--name-only", baseline, "--", "src"])
    return [line for line in result.stdout.splitlines() if line]


def _component_record(path: Path, policy: str) -> dict[str, Any]:
    files = [item for item in path.rglob("*") if item.is_file()]
    return {
        "path": path.name,
        "copyPolicy": policy,
        "sha256": sha256_tree(path),
        "fileCount": len(files),
        "byteCount": sum(item.stat().st_size for item in files),
    }


def _write_json_atomic(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4()}.tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def current_snapshot_id(paths: BuildPaths, context_id: str) -> str | None:
    pointer = paths.state / "state/gui" / f"{context_id}.json"
    if not pointer.is_file():
        return None
    value = json.loads(pointer.read_text(encoding="utf-8"))
    snapshot_id = value.get("snapshotId")
    if not snapshot_id:
        raise ValueError(f"invalid GUI snapshot pointer: {pointer}")
    snapshot = paths.state / "snapshots" / context_id / snapshot_id / "snapshot.json"
    if not snapshot.is_file():
        raise ValueError(f"GUI snapshot pointer references missing snapshot {snapshot_id}")
    return snapshot_id


def select_snapshot(paths: BuildPaths, context_id: str, snapshot_id: str) -> dict[str, Any]:
    snapshot_path = find_snapshot(paths, snapshot_id)
    snapshot = json.loads((snapshot_path / "snapshot.json").read_text(encoding="utf-8"))
    if snapshot["contextId"] != context_id:
        raise ValueError(f"snapshot {snapshot_id} belongs to context {snapshot['contextId']!r}")
    pointer = {
        "schemaVersion": 1,
        "contextId": context_id,
        "snapshotId": snapshot_id,
        "selectedAt": utc_now(),
    }
    _write_json_atomic(paths.state / "state/gui" / f"{context_id}.json", pointer)
    return {"schemaVersion": 1, "operation": "snapshot-select", **pointer}


def clear_current_snapshot(paths: BuildPaths, context_id: str) -> dict[str, Any]:
    pointer = paths.state / "state/gui" / f"{context_id}.json"
    previous = json.loads(pointer.read_text(encoding="utf-8")).get("snapshotId") if pointer.is_file() else None
    pointer.unlink(missing_ok=True)
    return {
        "schemaVersion": 1, "operation": "snapshot-clear", "contextId": context_id,
        "previousSnapshotId": previous, "cleared": previous is not None,
    }


def list_snapshots(paths: BuildPaths, context_id: str) -> dict[str, Any]:
    current = current_snapshot_id(paths, context_id)
    root = paths.state / "snapshots" / context_id
    snapshots = []
    for metadata_path in sorted(root.glob("*/snapshot.json")):
        value = json.loads(metadata_path.read_text(encoding="utf-8"))
        snapshots.append(value | {"current": value["snapshotId"] == current})
    return {
        "schemaVersion": 1, "operation": "snapshot-list", "contextId": context_id,
        "currentSnapshotId": current, "snapshots": snapshots,
    }


def snapshot_current(paths: BuildPaths, context_id: str) -> dict[str, Any]:
    snapshot_id = current_snapshot_id(paths, context_id)
    return {
        "schemaVersion": 1, "operation": "snapshot-current", "contextId": context_id,
        "snapshotId": snapshot_id,
    }


def snapshot_run(
    paths: BuildPaths, run_id: str, *, make_current: bool = False, remove_source: bool = False,
    save_evidence: dict[str, Any] | None = None,
) -> dict[str, Any]:
    run_path = find_run(paths, run_id)
    run = json.loads((run_path / "run.json").read_text(encoding="utf-8"))
    if process_is_alive(run.get("pid")):
        raise ValueError(f"run {run_id} is still active")
    snapshot_id = str(uuid.uuid4())
    snapshots_root = paths.state / "snapshots" / run["contextId"]
    destination = snapshots_root / snapshot_id
    attempt = snapshots_root / f".tmp-{snapshot_id}"
    attempt.mkdir(parents=True)
    try:
        components = []
        for name in SNAPSHOT_COMPONENTS:
            source = run_path / name
            if source.exists():
                copy_reflink(source, attempt / name)
                components.append(_component_record(attempt / name, "private-reflink-or-copy"))
        image = attempt / "image/GlamorousToolkit.image"
        if not image.is_file():
            raise ValueError(f"run {run_id} has no GUI image")
        changed_paths = _bridge_changes(run_path, run)
        created = utc_now()
        metadata = {
            "schemaVersion": 2,
            "snapshotId": snapshot_id,
            "contextId": run["contextId"],
            "profile": run["profile"],
            "parentL06Artifact": run["parentArtifact"],
            "parentL06BuildKey": run["parentBuildKey"],
            "parentL01Artifact": run.get("runtimeArtifact"),
            "parentL01BuildKey": run.get("runtimeBuildKey"),
            "runtimeProfile": run.get("runtimeProfile", platform_id()),
            "launcher": run.get("launcher"),
            "projectCommitId": run["projectCommitId"],
            "projectChangeId": run["projectChangeId"],
            "generatedBridgeCommit": run["generatedBridgeCommit"],
            "workspace": run.get("workspace", "."),
            "workspacePath": run.get("workspacePath"),
            "sourceRunId": run_id,
            "sourceDirtyRelativeToDisk": bool(changed_paths),
            "changedPaths": changed_paths,
            "createdAt": created,
            "lastSavedAt": created,
            "imageSha256": sha256_file(image),
            "components": components,
            "excludedComponents": ["cache", "tmp"],
            "environment": run.get("environment", {}),
            "host": run.get("host", {}),
            "saveEvidence": save_evidence or run.get("saveEvidence"),
            "externalState": "Files, databases, sockets, services, and network resources outside snapshot components are not captured.",
            "runMetadata": run,
            "classification": "L06-tmp-resumable-noncanonical",
        }
        (attempt / "snapshot.json").write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        for component in components:
            copied = attempt / component["path"]
            if sha256_tree(copied) != component["sha256"]:
                raise RuntimeError(f"snapshot verification failed for {component['path']}")
        set_tree_writable(attempt, False)
        snapshots_root.mkdir(parents=True, exist_ok=True)
        os.replace(attempt, destination)
        if make_current:
            select_snapshot(paths, run["contextId"], snapshot_id)
        if remove_source:
            set_tree_writable(run_path, True)
            shutil.rmtree(run_path)
    except Exception:
        if attempt.exists():
            set_tree_writable(attempt, True)
            shutil.rmtree(attempt)
        raise
    return metadata | {"snapshotPath": str(destination), "operation": "snapshot"}


def _source_divergence(paths: BuildPaths, snapshot: dict[str, Any]) -> dict[str, Any]:
    context = load_context(paths, snapshot["contextId"])
    current = jj_identity(paths, context["project"]["revision"], context["project"]["workspace"])
    recorded_workspace = snapshot.get("workspacePath")
    current_workspace = str(project_workspace(paths, context["project"]["workspace"]))
    reasons = []
    if current["commitId"] != snapshot.get("projectCommitId"):
        reasons.append("project commit changed")
    if recorded_workspace and recorded_workspace != current_workspace:
        reasons.append("workspace path changed")
    return {"diverged": bool(reasons), "reasons": reasons, "current": current, "workspacePath": current_workspace}


def resume_snapshot(paths: BuildPaths, snapshot_id: str) -> dict[str, Any]:
    snapshot_path = find_snapshot(paths, snapshot_id)
    snapshot = json.loads((snapshot_path / "snapshot.json").read_text(encoding="utf-8"))
    run_id = str(uuid.uuid4())
    run_path = paths.state / "runs" / snapshot["contextId"] / run_id
    run_path.mkdir(parents=True)
    for name in SNAPSHOT_COMPONENTS:
        source = snapshot_path / name
        if source.exists():
            copy_reflink(source, run_path / name)
    for name in ("home", "config", "data", "cache", "logs", "tmp"):
        (run_path / name).mkdir(exist_ok=True)
    original = snapshot.get("runMetadata", {})
    divergence = _source_divergence(paths, snapshot)
    metadata = original | {
        "schemaVersion": 2,
        "runId": run_id,
        "state": "created",
        "pid": None,
        "exitCode": None,
        "resumedFromSnapshot": snapshot_id,
        "guiStartMode": "resumed",
        "sourceDivergence": divergence,
        "createdAt": utc_now(),
        "updatedAt": utc_now(),
    }
    (run_path / "run.json").write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    set_tree_writable(run_path, True)
    return metadata | {"runPath": str(run_path), "operation": "resume"}


def discard_run(paths: BuildPaths, record_id: str) -> dict[str, Any]:
    try:
        record_path = find_run(paths, record_id)
        metadata = json.loads((record_path / "run.json").read_text(encoding="utf-8"))
        if process_is_alive(metadata.get("pid")):
            raise ValueError(f"run {record_id} is still active")
        kind = "run"
    except ValueError as error:
        if "still active" in str(error):
            raise
        record_path = find_snapshot(paths, record_id)
        kind = "snapshot"
        for pointer in (paths.state / "state/gui").glob("*.json"):
            value = json.loads(pointer.read_text(encoding="utf-8"))
            if value.get("snapshotId") == record_id:
                raise ValueError(f"snapshot {record_id} is current for context {value.get('contextId')!r}; clear or select another snapshot first")
    set_tree_writable(record_path, True)
    shutil.rmtree(record_path)
    return {"schemaVersion": 1, "operation": "discard", "recordId": record_id, "recordKind": kind, "discarded": True}


def promote_packages(paths: BuildPaths, source_id: str, packages: list[str], destination_context: str) -> dict[str, Any]:
    if not packages:
        raise ValueError("promotion requires at least one explicit package")
    try:
        source_path = find_run(paths, source_id)
        source_metadata = json.loads((source_path / "run.json").read_text(encoding="utf-8"))
        source_kind = "run"
    except ValueError:
        source_path = find_snapshot(paths, source_id)
        snapshot = json.loads((source_path / "snapshot.json").read_text(encoding="utf-8"))
        source_metadata = snapshot["runMetadata"]
        source_kind = "snapshot"
    context = load_context(paths, destination_context)
    if context["project"]["workspace"] != ".":
        raise ValueError("promotion currently supports only the root JJ workspace")
    if source_metadata["contextId"] != destination_context and destination_context != "default":
        raise ValueError("cross-context promotion requires destination 'default'")
    bridge = source_path / "export"
    baseline = source_metadata["projectCommitId"]
    selected: list[tuple[str, Path, Path]] = []
    for package in packages:
        if "/" in package or not package.startswith("KlibGenGt-"):
            raise ValueError(f"invalid project package name {package!r}")
        source = bridge / "src" / package
        destination = paths.root / "src" / package
        if not source.is_dir():
            raise ValueError(f"selected package is absent from bridge: {package}")
        changed = run_command(["git", "-C", str(bridge), "diff", "--quiet", source_metadata["generatedBridgeCommit"], "--", f"src/{package}"], check=False).returncode
        if changed == 0:
            raise ValueError(f"selected bridge package has no changes: {package}")
        if changed != 1:
            raise RuntimeError(f"could not compare bridge package {package}")
        conflict = run_command(["jj", "-R", str(paths.root), "diff", "--from", baseline, "--to", context["project"]["revision"], "--", f"src/{package}"]).stdout
        if conflict.strip():
            raise ValueError(f"authoritative package changed since run creation: {package}")
        selected.append((package, source, destination))
    for _, source, destination in selected:
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(source, destination)
    return {"schemaVersion": 1, "operation": "promote", "sourceId": source_id, "sourceKind": source_kind, "destinationContext": destination_context, "baselineProjectCommitId": baseline, "packages": packages}
