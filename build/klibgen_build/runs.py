from __future__ import annotations

import json
import shutil
import uuid
from pathlib import Path
from typing import Any

from .artifacts import build_base, copy_reflink, graph, set_tree_writable
from .core import BuildPaths


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
    }
    (run / "run.json").write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    for name in ("home", "config", "cache", "logs", "tmp"):
        (run / name).mkdir()
    return metadata | {"runPath": str(run)}


def clean_runs(paths: BuildPaths, context_id: str) -> int:
    root = paths.state / "runs" / context_id
    if not root.exists():
        return 0
    count = sum(1 for path in root.iterdir() if path.is_dir())
    shutil.rmtree(root)
    return count
