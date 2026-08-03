from __future__ import annotations

import json
import logging
import os
import re
import socket
import time
import uuid
from pathlib import Path
from typing import Any, Protocol

from .core import BuildPaths


SCHEMA_VERSION = 1
MAX_TCP_RESPONSE_BYTES = 16 * 1024 * 1024
logger = logging.getLogger(__name__)


class UiControlConnector(Protocol):
    """Transport one complete schema-version-one UI control envelope."""

    def submit(self, envelope: dict[str, Any], *, timeout: float) -> dict[str, Any]: ...


class FileUiControlConnector:
    """Exchange UI control envelopes through one GUI workspace's atomic spool."""

    def __init__(self, session: dict[str, Any]):
        self.session = session
        self.workspace_path = Path(session["workspacePath"])

    def submit(self, envelope: dict[str, Any], *, timeout: float) -> dict[str, Any]:
        request_id = envelope["requestId"]
        spool = self.workspace_path / "tmp/ui-control"
        requests = spool / "requests"
        responses = spool / "responses"
        deadline = time.monotonic() + timeout
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
                response_path.unlink(missing_ok=True)
                return response
            workspace_ready = (
                (self.workspace_path / "workspace.json").is_file()
                and (spool / "ready.json").is_file()
            )
            if not process_is_alive(self.session.get("pid")) and not workspace_ready:
                raise RuntimeError(
                    f"GUI workspace session {self.session['sessionId']!r} exited "
                    f"while handling request {request_id}"
                )
            time.sleep(0.025)
        destination.unlink(missing_ok=True)
        raise TimeoutError(f"UI control request {request_id} exceeded {timeout:g}s")


class TcpUiControlConnector:
    """Internal loopback NDJSON transport for direct programmatic experiments."""

    def __init__(
        self, host: str, port: int, *,
        max_response_bytes: int = MAX_TCP_RESPONSE_BYTES,
    ):
        self.host = host
        self.port = port
        self.max_response_bytes = max_response_bytes
        self._socket: socket.socket | None = None
        self._stream: Any = None

    def __enter__(self) -> "TcpUiControlConnector":
        return self

    def __exit__(self, *_error: object) -> None:
        self.close()

    def close(self) -> None:
        if self._stream is not None:
            self._stream.close()
            self._stream = None
        if self._socket is not None:
            self._socket.close()
            self._socket = None

    def submit(self, envelope: dict[str, Any], *, timeout: float) -> dict[str, Any]:
        if self._socket is None:
            self._socket = socket.create_connection((self.host, self.port), timeout=timeout)
            self._stream = self._socket.makefile("rwb")
        self._socket.settimeout(timeout)
        payload = json.dumps(envelope, separators=(",", ":")).encode("utf-8") + b"\n"
        self._stream.write(payload)
        self._stream.flush()
        line = self._stream.readline(self.max_response_bytes + 1)
        if len(line) > self.max_response_bytes:
            raise RuntimeError(
                f"UI control TCP response exceeds {self.max_response_bytes} bytes"
            )
        if not line.endswith(b"\n"):
            raise RuntimeError("UI control TCP response is not newline terminated")
        try:
            response = json.loads(line.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise RuntimeError("UI control TCP response is invalid UTF-8 JSON") from error
        if not isinstance(response, dict):
            raise RuntimeError("UI control TCP response must be a JSON object")
        if response.get("requestId") != envelope.get("requestId"):
            raise RuntimeError("UI control TCP response has a mismatched request ID")
        return response


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
        except (OSError, json.JSONDecodeError) as error:
            logger.debug("ignored malformed GUI workspace state error=%s", error)
    logger.debug("discovered active GUI sessions count=%d", len(result))
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
    connector: UiControlConnector | None = None,
) -> dict[str, Any]:
    """Atomically submit one request and wait for its matching response."""
    session = select_gui_session(paths, session_id)
    workspace_path = Path(session["workspacePath"])
    request_id = str(uuid.uuid4())
    logger.debug("submitting UI request operation=%s request=%s session=%s", request["operation"], request_id, session["sessionId"])
    deadline = time.monotonic() + timeout
    envelope = {
        "schemaVersion": SCHEMA_VERSION, "requestId": request_id,
        "sessionId": session["sessionId"], "operation": request["operation"],
        "deadlineUnixMs": int((time.time() + timeout) * 1000),
    } | {key: value for key, value in request.items() if key != "operation"}
    transport = connector if connector is not None else FileUiControlConnector(session)
    try:
        response = transport.submit(envelope, timeout=max(0.0, deadline - time.monotonic()))
    except TimeoutError:
        logger.warning("UI request timed out operation=%s request=%s timeout=%s", request["operation"], request_id, timeout)
        raise
    if response.get("requestId") != request_id:
        raise RuntimeError("UI control returned a mismatched response")
    response.update({"workspacePath": str(workspace_path)})
    logger.debug("received UI response operation=%s request=%s ok=%s", request["operation"], request_id, response.get("ok"))
    return response


def validate_regex_selector(request: dict[str, Any]) -> None:
    if "textRegex" in request:
        re.compile(request["textRegex"])
