from __future__ import annotations

import fcntl
import json
import os
import shutil
import time
import uuid
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

from .canonical import _dependency_repository, build_canonical
from .core import BuildPaths
from .json_models import StagingV1, WorkspaceV1, validate_named_record
from .processes import run_command, start_command
from .source_requests import service_source_requests
from .resolution import resolve_target
from .staging import (
    acquire_staging_lease,
    create_staging,
    migrate_staging,
    release_staging_lease,
    validate_staging_name,
)
from .store import atomic_json
from .v2state import V2Paths


WORKSPACE_NAME = "gui-default"


def _workspace_start_mode(initialized: bool, record: dict[str, Any]) -> str:
    """Present only an orderly saved image as a resumed GUI workspace."""
    if initialized:
        return "fresh"
    completion = record.get("lastCompletion") or {}
    if record.get("state") == "saved" and completion.get("state") == "saved":
        return "resumed"
    return "fresh"


@contextmanager
def workspace_lock(v2: V2Paths) -> Iterator[None]:
    path = v2.root / "locks/workspaces/gui-default.lock"
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w") as stream:
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise RuntimeError("GUI workspace gui-default is already active") from error
        yield


def _current_source_for_build(paths: BuildPaths, build: dict[str, Any]) -> dict[str, Any]:
    resolved = resolve_target(paths, "gui")
    if resolved["outputKey"] != build["outputKey"]:
        raise RuntimeError("project source changed while initializing the GUI workspace; retry")
    source_step = next(step for step in resolved["steps"] if step["role"] == "project-source")
    return source_step["resolvedConfiguration"]["source"]


def _initialize(
    paths: BuildPaths,
    v2: V2Paths,
    workspace: Path,
    build: dict[str, Any],
    source: dict[str, Any],
    staging: dict[str, Any],
) -> dict[str, Any]:
    artifact = Path(build["artifacts"][-1]["path"])
    workspace.mkdir(parents=True)
    run_command(["cp", "-a", "--reflink=auto", artifact / "payload/image", workspace / "image"])
    for path in (workspace / "image", *(workspace / "image").rglob("*")):
        if not path.is_symlink():
            path.chmod(path.stat().st_mode | 0o200)
    for name in ("home", "config", "cache", "data-home", "tmp", "logs"):
        (workspace / name).mkdir()
    record = {
        "schema": "klibgen.workspace/1", "schemaVersion": 1, "name": WORKSPACE_NAME,
        "state": "ready", "projectKey": build["outputKey"], "artifactPath": str(artifact),
        "baseSource": source,
        "sourceGit": staging["sourceGit"], "lastCompletion": None,
        "stagingArea": staging["name"],
        "stagingGeneration": staging.get("generation", 1),
    }
    atomic_json(workspace / "workspace.json", record)
    return record


def workspace_status(paths: BuildPaths) -> dict[str, Any]:
    workspace = V2Paths.for_build(paths).root / "workspaces" / WORKSPACE_NAME
    if not (workspace / "workspace.json").is_file():
        return validate_named_record({"schema": "klibgen.workspace-status/1", "schemaVersion": 1, "operation": "v2.workspace.status", "exists": False, "name": WORKSPACE_NAME})
    value = WorkspaceV1.model_validate_json((workspace / "workspace.json").read_text(encoding="utf-8")).to_wire()
    return validate_named_record({"schema": "klibgen.workspace-status/1", "schemaVersion": 1, "operation": "v2.workspace.status", "exists": True, "workspace": value, "path": str(workspace)})


def reset_workspace(paths: BuildPaths, confirmed: bool) -> dict[str, Any]:
    if not confirmed:
        raise ValueError("workspace reset requires --confirm")
    v2 = V2Paths.for_build(paths)
    workspace = v2.root / "workspaces" / WORKSPACE_NAME
    with workspace_lock(v2):
        if (workspace / "workspace.json").is_file():
            record = json.loads((workspace / "workspace.json").read_text(encoding="utf-8"))
            if record.get("stagingArea"):
                release_staging_lease(paths, record["stagingArea"], WORKSPACE_NAME)
        if workspace.exists():
            v2.remove_tree(workspace)
    return validate_named_record({"schema": "klibgen.workspace-reset/1", "schemaVersion": 1, "operation": "v2.workspace.reset", "name": WORKSPACE_NAME, "removed": True})


def _staging_for_workspace(
    paths: BuildPaths,
    workspace: Path,
    existing: dict[str, Any] | None,
    staging_name: str,
) -> dict[str, Any]:
    manifest = V2Paths.for_build(paths).root / "staging" / staging_name / "staging.json"
    if manifest.is_file():
        return StagingV1.model_validate_json(manifest.read_text(encoding="utf-8")).to_wire()
    if existing is not None and existing.get("sourceGit"):
        legacy_repository = Path(existing["sourceGit"]).parent
        if legacy_repository.is_dir():
            return migrate_staging(
                paths, staging_name, legacy_repository,
                existing["baseSource"], existing["projectKey"],
            )
    return create_staging(paths, staging_name)["staging"]


def launch_gui_workspace(
    paths: BuildPaths,
    fresh: bool = False,
    staging_name: str = "gui-default",
) -> int:
    staging_name = validate_staging_name(staging_name)
    build = build_canonical(paths, "gui")
    artifact = Path(build["artifacts"][-1]["path"])
    artifact_manifest = json.loads((artifact / "manifest.json").read_text(encoding="utf-8"))
    dependency_step = next(step for step in artifact_manifest["resolvedRecipe"]["steps"] if step["role"] == "project-dependencies")
    v2 = V2Paths.for_build(paths)
    v2.initialize()
    workspace = v2.root / "workspaces" / WORKSPACE_NAME
    with workspace_lock(v2):
        if fresh and workspace.exists():
            old_record_path = workspace / "workspace.json"
            if old_record_path.is_file():
                old_record = json.loads(old_record_path.read_text(encoding="utf-8"))
                if old_record.get("stagingArea"):
                    release_staging_lease(paths, old_record["stagingArea"], WORKSPACE_NAME)
            v2.remove_tree(workspace)
        initialized = not (workspace / "workspace.json").is_file()
        existing = None if initialized else WorkspaceV1.model_validate_json(
            (workspace / "workspace.json").read_text(encoding="utf-8")
        ).to_wire()
        if existing and existing.get("stagingArea") not in {None, staging_name}:
            raise ValueError("switching a saved GUI workspace to another staging area requires --fresh")
        staging = _staging_for_workspace(paths, workspace, existing, staging_name)
        record = (
            _initialize(
                paths, v2, workspace, build,
                _current_source_for_build(paths, build), staging,
            )
            if initialized
            else existing
        )
        if record.get("state") == "active" and not Path(f"/proc/{record.get('pid', -1)}").exists():
            record["state"] = "ready"
            record.pop("pid", None)
            record.pop("sessionId", None)
            atomic_json(workspace / "workspace.json", record)
        stale = record["projectKey"] != build["outputKey"]
        if stale:
            print(f"warning: GUI workspace is based on {record['projectKey']}, current project is {build['outputKey']}", file=os.sys.stderr)
        session_id = str(uuid.uuid4())
        staging = acquire_staging_lease(
            paths, staging_name, "gui", WORKSPACE_NAME, os.getpid(),
            session_id=session_id,
        )
        completion = workspace / "completion.json"
        completion.unlink(missing_ok=True)
        event_journal = workspace / "logs" / f"events-{session_id}.jsonl"
        source_requests = workspace / "tmp/source-requests" / session_id
        source_responses = workspace / "tmp/source-responses" / session_id
        manifest = {
            "schema": "klibgen.session/1", "schemaVersion": 1, "sessionId": session_id,
            "projectKey": record["projectKey"], "recipe": "project",
            "preset": {"name": "gui", "frontend": "gui", "sourceChanges": "interactive", "persistence": "workspace", "startMode": _workspace_start_mode(initialized, record)},
            "paths": {
                "completion": str(completion), "eventJournal": str(event_journal),
                "sourceRequests": str(source_requests),
                "sourceResponses": str(source_responses),
            },
            "inputs": {
                "sourceGit": staging["sourceGit"], "stagingArea": staging_name,
                "stagingGeneration": staging.get("generation", 1),
            },
        }
        session_manifest = workspace / "session.json"
        atomic_json(session_manifest, manifest)
        environment = os.environ.copy()
        environment.update({
            "HOME": str(workspace / "home"), "XDG_CONFIG_HOME": str(workspace / "config"),
            "XDG_CACHE_HOME": str(workspace / "cache"), "XDG_DATA_HOME": str(workspace / "data-home"),
            "TMPDIR": str(workspace / "tmp"), "KLIBGEN_SESSION_MANIFEST": str(session_manifest),
            "KLIBGEN_SQLITE_REPOSITORY": _dependency_repository(paths, dependency_step),
        })
        cli = artifact / "payload/runtime/bin/GlamorousToolkit-cli"
        image = workspace / "image/GlamorousToolkit.image"
        loaded_generation = record.get("stagingGeneration")
        current_generation = staging.get("generation", 1)
        last_completion = record.get("lastCompletion") or {}
        pending_changes = (
            last_completion.get("sourceChangeCount", 0)
            if last_completion.get("state") == "saved" else 0
        )
        if not initialized and loaded_generation != current_generation and pending_changes:
            release_staging_lease(
                paths, staging_name, session_id, source_change_count=pending_changes,
            )
            raise RuntimeError(
                "GUI workspace has unexported source changes and cannot reload a changed staging generation"
            )
        if initialized or loaded_generation != current_generation:
            result = run_command([cli, image, "st", paths.root / "build/v2/scripts/bind-workspace.st"], check=False, cwd=workspace, env=environment)
            (workspace / "logs/bind.log").write_text(result.stdout + result.stderr, encoding="utf-8")
            if result.returncode:
                release_staging_lease(paths, staging_name, session_id)
                raise RuntimeError(f"GUI workspace binding failed; log: {workspace / 'logs/bind.log'}")
            record["stagingGeneration"] = current_generation
            record["sourceGit"] = staging["sourceGit"]
            record["stagingArea"] = staging_name
        gui = artifact / "payload/runtime/bin/GlamorousToolkit"
        try:
            process = start_command([gui, "--image", image], cwd=workspace, env=environment)
        except Exception:
            release_staging_lease(paths, staging_name, session_id)
            raise
        record["state"] = "active"
        record["pid"] = process.pid
        record["sessionId"] = session_id
        atomic_json(workspace / "workspace.json", record)
        try:
            while process.poll() is None:
                service_source_requests(
                    paths, source_requests, source_responses,
                    session_id=session_id, staging_name=staging_name,
                )
                time.sleep(0.05)
            service_source_requests(
                paths, source_requests, source_responses,
                session_id=session_id, staging_name=staging_name,
            )
        except Exception:
            release_staging_lease(paths, staging_name, session_id)
            raise
        exit_code = process.returncode
        if not completion.is_file():
            record["state"] = "ready"
            record["lastCompletion"] = {
                "schema": "klibgen.session-completion/1", "sessionId": session_id,
                "state": "abnormal", "ok": False, "exitCode": exit_code,
            }
            record.pop("pid", None)
            record.pop("sessionId", None)
            atomic_json(workspace / "workspace.json", record)
            release_staging_lease(paths, staging_name, session_id)
            raise RuntimeError(f"GUI workspace exited without authoritative completion; logs: {workspace / 'logs'}")
        completed = json.loads(completion.read_text(encoding="utf-8"))
        if completed.get("sessionId") != session_id:
            release_staging_lease(paths, staging_name, session_id)
            raise RuntimeError("GUI workspace completion does not match the active session")
        record["lastCompletion"] = completed
        record["state"] = "saved" if completed["state"] == "saved" else "ready"
        record.pop("pid", None)
        record.pop("sessionId", None)
        atomic_json(workspace / "workspace.json", record)
        release_staging_lease(
            paths, staging_name, session_id,
            source_change_count=(
                completed.get("sourceChangeCount", 0)
                if completed.get("state") == "saved" else 0
            ),
        )
        return exit_code


__all__ = ["WORKSPACE_NAME", "launch_gui_workspace", "reset_workspace", "workspace_status"]
