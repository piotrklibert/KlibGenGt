from __future__ import annotations

import logging
import shutil
import time
import uuid
from pathlib import Path
from typing import Any, Callable

from .core import BuildPaths
from .json_models import validate_named_record
from .processes import run_command
from .store import ArtifactStore, atomic_json


StepExecutor = Callable[[dict[str, Any], Path], None]
logger = logging.getLogger(__name__)


def build_resolved(paths: BuildPaths, resolved: dict[str, Any], executor: StepExecutor) -> dict[str, Any]:
    logger.info("building target=%s outputKey=%s", resolved["target"], resolved["outputKey"])
    store = ArtifactStore(paths)
    published = []
    segment: list[dict[str, Any]] = []
    previous_artifact: Path | None = None
    for step in resolved["steps"]:
        segment.append(step)
        if step["checkpoint"] != "artifact":
            continue
        artifact_type = step["implementation"]["outputType"]
        target = store.artifact(artifact_type, step["outputKey"])
        status_path = store.v2.root / "status" / f"{step['outputKey']}.json"
        with store.key_lock(step["outputKey"]):
            if target.exists():
                logger.debug("reusing artifact role=%s key=%s", step["role"], step["outputKey"])
                store.verify(target)
                published.append({"role": step["role"], "path": str(target), "reused": True})
                previous_artifact = target
                segment = []
                continue
            workspace = store.v2.root / "tmp" / f"build-{uuid.uuid4().hex}"
            logger.info("building artifact role=%s key=%s", step["role"], step["outputKey"])
            workspace.mkdir(parents=True)
            if previous_artifact is None:
                (workspace / "payload").mkdir()
            else:
                run_command([
                    "cp", "-a", "--reflink=auto",
                    previous_artifact / "payload", workspace / "payload",
                ])
            atomic_json(status_path, {"schema": "klibgen.build-status/1", "state": "building", "outputKey": step["outputKey"], "role": step["role"]})
            try:
                for segment_step in segment:
                    executor(segment_step, workspace / "payload")
                manifest = {
                    "artifactType": artifact_type, "outputKey": step["outputKey"],
                    "producingRole": step["role"], "resolvedRecipe": resolved,
                }
                target, _ = store.publish_locked(workspace, manifest)
                logger.info("published artifact role=%s path=%s", step["role"], target)
                atomic_json(status_path, {"schema": "klibgen.build-status/1", "state": "succeeded", "outputKey": step["outputKey"], "artifactPath": str(target)})
                published.append({"role": step["role"], "path": str(target), "reused": False})
                previous_artifact = target
                segment = []
            except Exception as error:
                diagnostic = store.v2.root / "logs" / "builds" / step["outputKey"] / uuid.uuid4().hex
                source_logs = workspace / "logs"
                diagnostic.mkdir(parents=True, exist_ok=True)
                if source_logs.is_dir():
                    shutil.copytree(source_logs, diagnostic / "logs")
                for record in workspace.glob("*.json"):
                    shutil.copy2(record, diagnostic / record.name)
                shutil.rmtree(workspace, ignore_errors=True)
                atomic_json(status_path, {"schema": "klibgen.build-status/1", "state": "failed", "outputKey": step["outputKey"], "error": {"class": type(error).__name__, "message": str(error)}, "failedAt": time.time(), "diagnosticPath": str(diagnostic)})
                logger.error("artifact build failed role=%s diagnostic=%s error=%s", step["role"], diagnostic, error)
                logger.debug("artifact build exception role=%s", step["role"], exc_info=True)
                raise
    logger.info("build complete target=%s artifacts=%d", resolved["target"], len(published))
    return validate_named_record({"schema": "klibgen.build-result/1", "schemaVersion": 1, "operation": "v2.build", "target": resolved["target"], "outputKey": resolved["outputKey"], "artifacts": published})


__all__ = ["StepExecutor", "build_resolved"]
