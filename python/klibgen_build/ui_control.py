from __future__ import annotations

import json
import os
import re
import time
import uuid
from pathlib import Path
from typing import Any

from .core import BuildPaths
from .runs import process_is_alive


SCHEMA_VERSION = 1


def _metadata(path: Path) -> dict[str, Any]:
    return json.loads((path / "run.json").read_text(encoding="utf-8"))


def active_gui_runs(paths: BuildPaths, context_id: str = "gui") -> list[dict[str, Any]]:
    """Return live managed GUI runs in one context, including readiness."""
    root = paths.state / "runs" / context_id
    result: list[dict[str, Any]] = []
    if not root.is_dir():
        return result
    for run_path in sorted((item for item in root.iterdir() if item.is_dir()), key=lambda p: p.name):
        try:
            record = _metadata(run_path)
        except (OSError, json.JSONDecodeError):
            continue
        if record.get("profile") != "gui" or record.get("state") != "running":
            continue
        if not process_is_alive(record.get("pid")):
            continue
        ready_path = run_path / "tmp/ui-control/ready.json"
        ready = None
        if ready_path.is_file():
            try:
                ready = json.loads(ready_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                pass
        result.append(record | {"runPath": str(run_path), "ready": ready})
    return result


def select_gui_run(paths: BuildPaths, context_id: str = "gui", run_id: str | None = None) -> dict[str, Any]:
    runs = active_gui_runs(paths, context_id)
    if run_id is not None:
        matches = [item for item in runs if item.get("runId") == run_id]
        if not matches:
            raise ValueError(f"managed GUI run {run_id!r} is not active in context {context_id!r}")
    else:
        matches = runs
        if not matches:
            raise ValueError(f"no active managed GUI run in context {context_id!r}")
        if len(matches) != 1:
            ids = ", ".join(item["runId"] for item in matches)
            raise ValueError(f"multiple active managed GUI runs in context {context_id!r}; use --run ({ids})")
    selected = matches[0]
    ready = selected.get("ready")
    if not ready or ready.get("schemaVersion") != SCHEMA_VERSION or ready.get("runId") != selected["runId"]:
        raise ValueError(f"managed GUI run {selected['runId']!r} is active but UI control is not ready")
    return selected


def submit_ui_request(
    paths: BuildPaths, request: dict[str, Any], *, context_id: str = "gui",
    run_id: str | None = None, timeout: float = 10.0,
) -> dict[str, Any]:
    """Atomically submit one request and wait for its matching response."""
    run = select_gui_run(paths, context_id, run_id)
    run_path = Path(run["runPath"])
    spool = run_path / "tmp/ui-control"
    requests = spool / "requests"
    responses = spool / "responses"
    request_id = str(uuid.uuid4())
    deadline = time.monotonic() + timeout
    envelope = {
        "schemaVersion": SCHEMA_VERSION, "requestId": request_id,
        "runId": run["runId"], "operation": request["operation"],
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
            response.update({"contextId": context_id, "runPath": str(run_path)})
            return response
        if not process_is_alive(run.get("pid")):
            raise RuntimeError(f"managed GUI run {run['runId']!r} exited while handling request {request_id}")
        time.sleep(0.025)
    try:
        destination.unlink()
    except FileNotFoundError:
        pass
    raise TimeoutError(f"UI control request {request_id} exceeded {timeout:g}s")


def selector_request(args: Any) -> dict[str, Any]:
    result: dict[str, Any] = {}
    mapping = {
        "space": "space", "node": "node", "under": "under", "class_name": "class",
        "element_id": "elementId", "text": "text", "text_contains": "textContains",
        "text_regex": "textRegex", "visible": "visible", "enabled": "enabled",
        "focused": "focused",
    }
    for attribute, key in mapping.items():
        value = getattr(args, attribute, None)
        if value is not None:
            result[key] = value
    return result


def validate_regex_selector(request: dict[str, Any]) -> None:
    if "textRegex" in request:
        re.compile(request["textRegex"])
