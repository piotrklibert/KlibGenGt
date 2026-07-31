from __future__ import annotations

import json
import os
import shutil
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .artifacts import build_base, build_l06, copy_reflink, graph, set_tree_writable
from .core import BuildPaths
from .bridge import materialize_jj_source


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def process_is_alive(pid: int | None) -> bool:
    if not pid:
        return False
    try:
        os.kill(pid, 0)
    except (OSError, ProcessLookupError):
        return False
    return True


def write_run_metadata(run_path: Path, **updates: Any) -> dict[str, Any]:
    metadata_path = run_path / "run.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    metadata.update(updates)
    metadata["updatedAt"] = utc_now()
    metadata_path.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return metadata


def create_run(paths: BuildPaths, context_id: str, profile: str) -> dict[str, Any]:
    if profile.lower() != "base":
        raise ValueError("Step 005 supports only the base profile")
    artifact = build_base(paths, context_id, "l02")
    run_id = str(uuid.uuid4())
    run = paths.state / "runs" / context_id / run_id
    run.mkdir(parents=True)
    copy_reflink(artifact / "image", run / "image")
    set_tree_writable(run, True)
    manifest = json.loads((artifact / "manifest.json").read_text(encoding="utf-8"))
    metadata = {
        "schemaVersion": 1,
        "runId": run_id,
        "contextId": context_id,
        "profile": profile,
        "parentArtifact": str(artifact),
        "parentBuildKey": manifest["buildKey"],
        "state": "created",
        "createdAt": utc_now(),
        "runtimeArguments": [],
        "allocatedResources": {"ports": [], "sockets": [], "temporaryDirectories": ["tmp"]},
        "logs": [],
    }
    (run / "run.json").write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    for name in ("home", "config", "cache", "logs", "tmp"):
        (run / name).mkdir()
    return metadata | {"runPath": str(run)}


def clean_runs(paths: BuildPaths, context_id: str) -> int:
    root = paths.state / "runs" / context_id
    if not root.exists():
        return 0
    count = 0
    for path in root.iterdir():
        if not path.is_dir():
            continue
        metadata_path = path / "run.json"
        metadata = json.loads(metadata_path.read_text(encoding="utf-8")) if metadata_path.is_file() else {}
        if process_is_alive(metadata.get("pid")):
            continue
        shutil.rmtree(path)
        count += 1
    if root.exists() and not any(root.iterdir()):
        root.rmdir()
    return count


def create_project_run(paths: BuildPaths, context_id: str, profile: str) -> dict[str, Any]:
    artifact = build_l06(paths, context_id)
    manifest = json.loads((artifact / "manifest.json").read_text(encoding="utf-8"))
    actual_profile = manifest["variant"]["name"].lower()
    if profile.lower() != actual_profile:
        raise ValueError(f"context {context_id!r} builds {actual_profile}, not {profile.lower()}")
    run_id = str(uuid.uuid4())
    run = paths.state / "runs" / context_id / run_id
    run.mkdir(parents=True)
    copy_reflink(artifact / "image", run / "image")
    set_tree_writable(run, True)
    identity = manifest["sources"][0]
    bridge_commit = materialize_jj_source(paths, identity, run / "export")
    nodes = graph(paths, context_id)
    metadata = {
        "schemaVersion": 1, "runId": run_id, "contextId": context_id, "profile": actual_profile,
        "parentArtifact": str(artifact), "parentBuildKey": manifest["buildKey"],
        "projectCommitId": identity["commitId"], "projectChangeId": identity["changeId"],
        "generatedBridgeCommit": bridge_commit, "state": "created",
        "launcher": str(nodes[0]["artifact"] / "runtime/bin/GlamorousToolkit-cli"),
        "createdAt": utc_now(), "runtimeArguments": [],
        "allocatedResources": {"ports": [], "sockets": [], "temporaryDirectories": ["tmp"]},
        "logs": [],
    }
    (run / "run.json").write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    for name in ("home", "config", "cache", "logs", "tmp"):
        (run / name).mkdir()
    return metadata | {"runPath": str(run)}
