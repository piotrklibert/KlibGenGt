from __future__ import annotations

import fcntl
import json
import os
import shutil
import uuid
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

from .canonical import _dependency_repository, _git_bridge, build_canonical
from .core import BuildPaths
from .json_models import WorkspaceV1, validate_named_record
from .processes import run_command, start_command
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


def _initialize(paths: BuildPaths, v2: V2Paths, workspace: Path, build: dict[str, Any]) -> dict[str, Any]:
    artifact = Path(build["artifacts"][-1]["path"])
    workspace.mkdir(parents=True)
    run_command(["cp", "-a", "--reflink=auto", artifact / "payload/image", workspace / "image"])
    for path in (workspace / "image", *(workspace / "image").rglob("*")):
        if not path.is_symlink():
            path.chmod(path.stat().st_mode | 0o200)
    artifact_manifest = json.loads((artifact / "manifest.json").read_text(encoding="utf-8"))
    resolved = artifact_manifest["resolvedRecipe"]
    source_step = next(step for step in resolved["steps"] if step["role"] == "project-source")
    bridge = _git_bridge(paths, workspace, ("src",), source_step["resolvedConfiguration"]["source"]["commitId"])
    bridge.rename(workspace / "source")
    for name in ("home", "config", "cache", "data-home", "tmp", "logs"):
        (workspace / name).mkdir()
    record = {
        "schema": "klibgen.workspace/1", "schemaVersion": 1, "name": WORKSPACE_NAME,
        "state": "ready", "projectKey": build["outputKey"], "artifactPath": str(artifact),
        "baseSource": source_step["resolvedConfiguration"]["source"],
        "sourceGit": str(workspace / "source/.git"), "lastCompletion": None,
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
        if workspace.exists():
            v2.remove_tree(workspace)
    return validate_named_record({"schema": "klibgen.workspace-reset/1", "schemaVersion": 1, "operation": "v2.workspace.reset", "name": WORKSPACE_NAME, "removed": True})


def launch_gui_workspace(paths: BuildPaths, fresh: bool = False) -> int:
    build = build_canonical(paths, "gui")
    artifact = Path(build["artifacts"][-1]["path"])
    artifact_manifest = json.loads((artifact / "manifest.json").read_text(encoding="utf-8"))
    dependency_step = next(step for step in artifact_manifest["resolvedRecipe"]["steps"] if step["role"] == "project-dependencies")
    v2 = V2Paths.for_build(paths)
    v2.initialize()
    workspace = v2.root / "workspaces" / WORKSPACE_NAME
    with workspace_lock(v2):
        if fresh and workspace.exists():
            v2.remove_tree(workspace)
        initialized = not (workspace / "workspace.json").is_file()
        record = _initialize(paths, v2, workspace, build) if initialized else WorkspaceV1.model_validate_json((workspace / "workspace.json").read_text(encoding="utf-8")).to_wire()
        if record.get("state") == "active" and not Path(f"/proc/{record.get('pid', -1)}").exists():
            record["state"] = "ready"
            record.pop("pid", None)
            record.pop("sessionId", None)
            atomic_json(workspace / "workspace.json", record)
        stale = record["projectKey"] != build["outputKey"]
        if stale:
            print(f"warning: GUI workspace is based on {record['projectKey']}, current project is {build['outputKey']}", file=os.sys.stderr)
        session_id = str(uuid.uuid4())
        completion = workspace / "completion.json"
        completion.unlink(missing_ok=True)
        event_journal = workspace / "logs" / f"events-{session_id}.jsonl"
        manifest = {
            "schema": "klibgen.session/1", "schemaVersion": 1, "sessionId": session_id,
            "projectKey": record["projectKey"], "recipe": "project",
            "preset": {"name": "gui", "frontend": "gui", "sourceChanges": "interactive", "persistence": "workspace", "startMode": _workspace_start_mode(initialized, record)},
            "paths": {"completion": str(completion), "eventJournal": str(event_journal)},
            "inputs": {"sourceGit": record["sourceGit"]},
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
        if initialized:
            result = run_command([cli, image, "st", paths.root / "build/v2/scripts/bind-workspace.st"], check=False, cwd=workspace, env=environment)
            (workspace / "logs/bind.log").write_text(result.stdout + result.stderr, encoding="utf-8")
            if result.returncode:
                raise RuntimeError(f"GUI workspace binding failed; log: {workspace / 'logs/bind.log'}")
        gui = artifact / "payload/runtime/bin/GlamorousToolkit"
        process = start_command([gui, "--image", image], cwd=workspace, env=environment)
        record["state"] = "active"
        record["pid"] = process.pid
        record["sessionId"] = session_id
        atomic_json(workspace / "workspace.json", record)
        exit_code = process.wait()
        if not completion.is_file():
            record["state"] = "ready"
            record["lastCompletion"] = {
                "schema": "klibgen.session-completion/1", "sessionId": session_id,
                "state": "abnormal", "ok": False, "exitCode": exit_code,
            }
            record.pop("pid", None)
            record.pop("sessionId", None)
            atomic_json(workspace / "workspace.json", record)
            raise RuntimeError(f"GUI workspace exited without authoritative completion; logs: {workspace / 'logs'}")
        completed = json.loads(completion.read_text(encoding="utf-8"))
        if completed.get("sessionId") != session_id:
            raise RuntimeError("GUI workspace completion does not match the active session")
        record["lastCompletion"] = completed
        record["state"] = "saved" if completed["state"] == "saved" else "ready"
        record.pop("pid", None)
        record.pop("sessionId", None)
        atomic_json(workspace / "workspace.json", record)
        return exit_code


__all__ = ["WORKSPACE_NAME", "launch_gui_workspace", "reset_workspace", "workspace_status"]
