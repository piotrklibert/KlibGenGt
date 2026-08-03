from __future__ import annotations

import json
import os
import re
import time
import uuid
from pathlib import Path
from typing import Any

from .core import BuildPaths


SCHEMA_VERSION = 1


def process_is_alive(pid: int | None) -> bool:
    if not isinstance(pid, int) or pid < 2:
        return False
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def active_gui_sessions(paths: BuildPaths) -> list[dict[str, Any]]:
    """Return the active GUI workspace session, including readiness."""
    result: list[dict[str, Any]] = []
    workspace = paths.state / "v2/workspaces/gui-default"
    workspace_record = workspace / "workspace.json"
    if workspace_record.is_file():
        try:
            record = json.loads(workspace_record.read_text(encoding="utf-8"))
            session_id = record.get("sessionId")
            ready_path = workspace / "tmp/ui-control/ready.json"
            ready_record = json.loads(ready_path.read_text(encoding="utf-8")) if ready_path.is_file() else None
            if record.get("state") == "active" and session_id and (
                process_is_alive(record.get("pid")) or (ready_record and ready_record.get("sessionId") == session_id)
            ):
                ready = json.loads(ready_path.read_text(encoding="utf-8")) if ready_path.is_file() else None
                result.append({
                    "schemaVersion": 1, "sessionId": session_id, "state": "active",
                    "pid": record["pid"], "workspacePath": str(workspace), "ready": ready,
                    "workspace": "gui-default",
                })
        except (OSError, json.JSONDecodeError):
            pass
    return result


def select_gui_session(paths: BuildPaths, session_id: str | None = None) -> dict[str, Any]:
    sessions = active_gui_sessions(paths)
    if session_id is not None:
        matches = [item for item in sessions if item.get("sessionId") == session_id]
        if not matches:
            raise ValueError(f"GUI workspace session {session_id!r} is not active")
    else:
        matches = sessions
        if not matches:
            raise ValueError("no active GUI workspace session")
        if len(matches) != 1:
            ids = ", ".join(item["sessionId"] for item in matches)
            raise ValueError(f"multiple active GUI workspace sessions; use --session ({ids})")
    selected = matches[0]
    ready = selected.get("ready")
    if not ready or ready.get("schemaVersion") != SCHEMA_VERSION or ready.get("sessionId") != selected["sessionId"]:
        raise ValueError(f"GUI workspace session {selected['sessionId']!r} is active but UI control is not ready")
    return selected


def submit_ui_request(
    paths: BuildPaths, request: dict[str, Any], *,
    session_id: str | None = None, timeout: float = 10.0,
) -> dict[str, Any]:
    """Atomically submit one request and wait for its matching response."""
    session = select_gui_session(paths, session_id)
    workspace_path = Path(session["workspacePath"])
    spool = workspace_path / "tmp/ui-control"
    requests = spool / "requests"
    responses = spool / "responses"
    request_id = str(uuid.uuid4())
    deadline = time.monotonic() + timeout
    envelope = {
        "schemaVersion": SCHEMA_VERSION, "requestId": request_id,
        "sessionId": session["sessionId"], "operation": request["operation"],
        "deadlineUnixMs": int((time.time() + timeout) * 1000),
    } | {key: value for key, value in request.items() if key != "operation"}
    requests.mkdir(parents=True, exist_ok=True)
    responses.mkdir(parents=True, exist_ok=True)
    temporary = requests / f".{request_id}.tmp"
    destination = requests / f"{request_id}.json"
    temporary.write_text(json.dumps(envelope, separators=(",", ":")), encoding="utf-8")
    os.replace(temporary, destination)
    response_path = responses / f"{request_id}.json"
    while time.monotonic() < deadline:
        if response_path.is_file():
            response = json.loads(response_path.read_text(encoding="utf-8"))
            try:
                response_path.unlink()
            except FileNotFoundError:
                pass
            if response.get("requestId") != request_id:
                raise RuntimeError("UI control returned a mismatched response")
            response.update({"workspacePath": str(workspace_path)})
            return response
        workspace_ready = (workspace_path / "workspace.json").is_file() and (spool / "ready.json").is_file()
        if not process_is_alive(session.get("pid")) and not workspace_ready:
            raise RuntimeError(f"GUI workspace session {session['sessionId']!r} exited while handling request {request_id}")
        time.sleep(0.025)
    try:
        destination.unlink()
    except FileNotFoundError:
        pass
    raise TimeoutError(f"UI control request {request_id} exceeded {timeout:g}s")


def validate_regex_selector(request: dict[str, Any]) -> None:
    if "textRegex" in request:
        re.compile(request["textRegex"])
