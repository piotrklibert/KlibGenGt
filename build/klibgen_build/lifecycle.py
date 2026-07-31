from __future__ import annotations

import json
import shutil
import subprocess
import uuid
from pathlib import Path
from typing import Any

from .artifacts import copy_reflink, set_tree_writable, sha256_file
from .core import BuildPaths, load_context
from .runs import process_is_alive, utc_now


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
    if not (bridge / ".git").exists():
        return []
    result = subprocess.run(
        ["git", "-C", str(bridge), "diff", "--name-only", metadata["generatedBridgeCommit"], "--", "src"],
        check=True, capture_output=True, text=True,
    )
    return [line for line in result.stdout.splitlines() if line]


def snapshot_run(paths: BuildPaths, run_id: str) -> dict[str, Any]:
    run_path = find_run(paths, run_id)
    run = json.loads((run_path / "run.json").read_text(encoding="utf-8"))
    if process_is_alive(run.get("pid")):
        raise ValueError(f"run {run_id} is still active")
    snapshot_id = str(uuid.uuid4())
    destination = paths.state / "snapshots" / run["contextId"] / snapshot_id
    destination.mkdir(parents=True)
    for name in ("image", "export", "logs"):
        source = run_path / name
        if source.exists():
            copy_reflink(source, destination / name)
    image = destination / "image/GlamorousToolkit.image"
    changed_paths = _bridge_changes(run_path, run)
    created = utc_now()
    metadata = {
        "schemaVersion": 1,
        "snapshotId": snapshot_id,
        "contextId": run["contextId"],
        "profile": run["profile"],
        "parentL06Artifact": run["parentArtifact"],
        "parentL06BuildKey": run["parentBuildKey"],
        "projectCommitId": run["projectCommitId"],
        "projectChangeId": run["projectChangeId"],
        "generatedBridgeCommit": run["generatedBridgeCommit"],
        "sourceRunId": run_id,
        "sourceDirtyRelativeToDisk": bool(changed_paths),
        "changedPaths": changed_paths,
        "createdAt": created,
        "lastSavedAt": created,
        "imageSha256": sha256_file(image),
        "runMetadata": run,
        "classification": "L06-tmp-resumable-noncanonical",
    }
    (destination / "snapshot.json").write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    set_tree_writable(destination, False)
    return metadata | {"snapshotPath": str(destination), "operation": "snapshot"}


def resume_snapshot(paths: BuildPaths, snapshot_id: str) -> dict[str, Any]:
    snapshot_path = find_snapshot(paths, snapshot_id)
    snapshot = json.loads((snapshot_path / "snapshot.json").read_text(encoding="utf-8"))
    run_id = str(uuid.uuid4())
    run_path = paths.state / "runs" / snapshot["contextId"] / run_id
    run_path.mkdir(parents=True)
    for name in ("image", "export", "logs"):
        source = snapshot_path / name
        if source.exists():
            copy_reflink(source, run_path / name)
    for name in ("home", "config", "cache", "logs", "tmp"):
        (run_path / name).mkdir(exist_ok=True)
    original = snapshot["runMetadata"]
    metadata = original | {
        "runId": run_id,
        "state": "created",
        "pid": None,
        "exitCode": None,
        "resumedFromSnapshot": snapshot_id,
        "createdAt": utc_now(),
        "updatedAt": utc_now(),
    }
    (run_path / "run.json").write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    set_tree_writable(run_path, True)
    return metadata | {"runPath": str(run_path), "operation": "resume"}


def discard_run(paths: BuildPaths, run_id: str) -> dict[str, Any]:
    run_path = find_run(paths, run_id)
    metadata = json.loads((run_path / "run.json").read_text(encoding="utf-8"))
    if process_is_alive(metadata.get("pid")):
        raise ValueError(f"run {run_id} is still active")
    shutil.rmtree(run_path)
    return {"schemaVersion": 1, "operation": "discard", "runId": run_id, "discarded": True}


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
        changed = subprocess.run(
            ["git", "-C", str(bridge), "diff", "--quiet", source_metadata["generatedBridgeCommit"], "--", f"src/{package}"],
        ).returncode
        if changed == 0:
            raise ValueError(f"selected bridge package has no changes: {package}")
        if changed != 1:
            raise RuntimeError(f"could not compare bridge package {package}")
        conflict = subprocess.run(
            ["jj", "-R", str(paths.root), "diff", "--from", baseline, "--to", context["project"]["revision"], "--", f"src/{package}"],
            check=True, capture_output=True, text=True,
        ).stdout
        if conflict.strip():
            raise ValueError(f"authoritative package changed since run creation: {package}")
        selected.append((package, source, destination))
    for _, source, destination in selected:
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(source, destination)
    return {
        "schemaVersion": 1,
        "operation": "promote",
        "sourceId": source_id,
        "sourceKind": source_kind,
        "destinationContext": destination_context,
        "baselineProjectCommitId": baseline,
        "packages": packages,
    }
