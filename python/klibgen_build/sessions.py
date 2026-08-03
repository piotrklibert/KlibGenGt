from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
import uuid
from pathlib import Path
from typing import Any

from .canonical import _dependency_repository, build_canonical
from .core import BuildPaths
from .json_models import SessionCompletionV1, SessionReadyV1
from .processes import decode_output, run_command, start_command
from .source_requests import service_source_requests
from .store import atomic_json
from .staging import acquire_staging_lease, release_staging_lease, validate_staging_name
from .tonel_lint import lint_git_source
from .v2state import V2Paths


def _writable(root: Path) -> None:
    for path in (root, *root.rglob("*")):
        if not path.is_symlink():
            path.chmod(path.stat().st_mode | 0o200)


def _retain_diagnostics(v2: V2Paths, operation: str, session: Path) -> Path:
    root = v2.root / "logs" / "sessions" / operation.replace(".", "-")
    latest = root / "latest"
    if latest.exists():
        v2.remove_tree(latest)
    latest.mkdir(parents=True, exist_ok=True)
    for relative in ("session.json", "request.json", "ready.json", "completion.json", "result.json", "logs"):
        source = session / relative
        if source.is_dir():
            shutil.copytree(source, latest / relative)
        elif source.exists():
            shutil.copy2(source, latest / relative)
    return latest


def execute_session(
    paths: BuildPaths,
    request: dict[str, Any],
    timeout: float = 300,
    *,
    preset: str = "cli",
    staging_name: str | None = None,
) -> dict[str, Any]:
    build = build_canonical(paths, "cli")
    artifact = Path(build["artifacts"][-1]["path"])
    artifact_manifest = json.loads((artifact / "manifest.json").read_text(encoding="utf-8"))
    dependency_step = next(
        step for step in artifact_manifest["resolvedRecipe"]["steps"]
        if step["role"] == "project-dependencies"
    )
    project_key = build["outputKey"]
    v2 = V2Paths.for_build(paths)
    v2.initialize()
    session_id = str(uuid.uuid4())
    session = v2.root / "sessions" / session_id
    session.mkdir(parents=True)
    run_command(["cp", "-a", "--reflink=auto", artifact / "payload/image", session / "image"])
    _writable(session / "image")
    for name in ("home", "config", "cache", "data-home", "tmp", "logs"):
        (session / name).mkdir()
    (session / "data").symlink_to(paths.root / "data", target_is_directory=True)
    request_path = session / "request.json"
    ready_path = session / "ready.json"
    completion_path = session / "completion.json"
    result_path = session / "result.json"
    source_requests = session / "tmp/source-requests"
    source_responses = session / "tmp/source-responses"
    atomic_json(request_path, request)
    if preset not in {"cli", "agentic"}:
        raise ValueError(f"unsupported headless preset {preset!r}")
    source_changes = "staged" if preset == "agentic" else "disabled"
    inputs: dict[str, Any] = {}
    staging_record: dict[str, Any] | None = None
    if staging_name is not None:
        staging_name = validate_staging_name(staging_name)
        staging_record = acquire_staging_lease(
            paths, staging_name, "agentic", session_id, os.getpid(),
        )
        try:
            lint_git_source(paths, Path(staging_record["sourceGit"]), artifact)
        except Exception:
            release_staging_lease(paths, staging_name, session_id)
            raise
        inputs["sourceGit"] = staging_record["sourceGit"]
        inputs["stagingArea"] = staging_name
        inputs["stagingGeneration"] = staging_record.get("generation", 1)
    manifest = {
        "schema": "klibgen.session/1", "schemaVersion": 1,
        "sessionId": session_id, "projectKey": project_key, "recipe": "project",
        "preset": {"name": preset, "frontend": "headless", "sourceChanges": source_changes, "persistence": "discard"},
        "paths": {
            "request": str(request_path), "ready": str(ready_path),
            "completion": str(completion_path), "result": str(result_path),
            "sourceRequests": str(source_requests), "sourceResponses": str(source_responses),
        },
        "inputs": inputs,
    }
    manifest_path = session / "session.json"
    atomic_json(manifest_path, manifest)
    environment = os.environ.copy()
    environment.update({
        "HOME": str(session / "home"), "XDG_CONFIG_HOME": str(session / "config"),
        "XDG_CACHE_HOME": str(session / "cache"), "XDG_DATA_HOME": str(session / "data-home"),
        "TMPDIR": str(session / "tmp"), "KLIBGEN_SESSION_MANIFEST": str(manifest_path),
        "KLIBGEN_SQLITE_REPOSITORY": _dependency_repository(paths, dependency_step),
    })
    if staging_name is not None:
        environment["KLIBGEN_STAGING_GIT"] = inputs["sourceGit"]
    launcher = artifact / "payload/runtime/bin/GlamorousToolkit-cli"
    script = "run-agentic-session.st" if preset == "agentic" else "run-session.st"
    command = [launcher, session / "image/GlamorousToolkit.image", "st", paths.root / "build/v2/scripts" / script]
    started = time.monotonic()
    process = start_command(command, cwd=session, env=environment, capture_output=True)
    timed_out = False
    deadline = started + timeout
    while True:
        remaining = deadline - time.monotonic()
        try:
            stdout, stderr = process.communicate(timeout=max(0.01, min(0.05, remaining)))
            if staging_name is not None:
                service_source_requests(
                    paths, source_requests, source_responses,
                    session_id=session_id, staging_name=staging_name,
                )
            break
        except subprocess.TimeoutExpired:
            if staging_name is not None:
                service_source_requests(
                    paths, source_requests, source_responses,
                    session_id=session_id, staging_name=staging_name,
                )
            if remaining <= 0:
                timed_out = True
                process.kill()
                stdout, stderr = process.communicate()
                break
    wall = time.monotonic() - started
    (session / "logs/session.log").write_text(decode_output(stdout) + decode_output(stderr), encoding="utf-8")
    try:
        if timed_out:
            raise TimeoutError(f"session {session_id} exceeded {timeout} seconds")
        if not ready_path.is_file():
            raise RuntimeError("session exited without a readiness record")
        ready = SessionReadyV1.model_validate_json(ready_path.read_text(encoding="utf-8")).to_wire()
        if ready.get("sessionId") != session_id or ready.get("schema") != "klibgen.session-ready/1":
            raise RuntimeError("session readiness record does not match its manifest")
        if not completion_path.is_file():
            raise RuntimeError("session exited without an authoritative completion record")
        completion = SessionCompletionV1.model_validate_json(completion_path.read_text(encoding="utf-8")).to_wire()
        if completion.get("sessionId") != session_id or completion.get("schema") != "klibgen.session-completion/1":
            raise RuntimeError("session completion record does not match its manifest")
        response = json.loads(result_path.read_text(encoding="utf-8"))
        if bool(response.get("ok")) != bool(completion.get("ok")):
            raise RuntimeError("tool response and authoritative completion disagree")
        response["sessionId"] = session_id
        response["completion"] = completion
        response["metrics"] = response.get("metrics", {}) | {"hostWallSeconds": wall}
        if not response.get("ok") or process.returncode != 0:
            diagnostic = _retain_diagnostics(v2, request.get("operation", "unknown"), session)
            response["diagnosticPath"] = str(diagnostic)
        return response
    except Exception:
        _retain_diagnostics(v2, request.get("operation", "unknown"), session)
        raise
    finally:
        if staging_name is not None:
            release_staging_lease(paths, staging_name, session_id)
        v2.remove_tree(session)


def execute_agentic_session(paths: BuildPaths, name: str, request: dict[str, Any], timeout: float = 300) -> dict[str, Any]:
    return execute_session(paths, request, timeout, preset="agentic", staging_name=name)


__all__ = ["execute_agentic_session", "execute_session"]
