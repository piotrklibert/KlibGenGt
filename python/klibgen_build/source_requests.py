from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .core import BuildPaths
from .staging import promote_staging, reconcile_staging, validate_staging_lease
from .store import atomic_json


MAX_SOURCE_REQUEST_BYTES = 64 * 1024
ALLOWED_SOURCE_OPERATIONS = {"source.status", "source.export", "source.promote"}


def service_source_requests(
    paths: BuildPaths,
    requests: Path,
    responses: Path,
    *,
    session_id: str,
    staging_name: str,
) -> int:
    """Service every complete source request currently visible in a session spool."""
    requests.mkdir(parents=True, exist_ok=True)
    responses.mkdir(parents=True, exist_ok=True)
    handled = 0
    for request_path in sorted(requests.glob("*.json")):
        response_path = responses / request_path.name
        if response_path.exists():
            request_path.unlink(missing_ok=True)
            continue
        request_id = request_path.stem
        try:
            if request_path.stat().st_size > MAX_SOURCE_REQUEST_BYTES:
                raise ValueError("source request exceeds the 64 KiB limit")
            request = json.loads(request_path.read_text(encoding="utf-8"))
            if request.get("sessionId") != session_id:
                raise ValueError("source request session ID does not match its launcher")
            if request.get("stagingArea") != staging_name:
                raise ValueError("source request staging name does not match its launcher")
            operation = request.get("operation")
            if operation not in ALLOWED_SOURCE_OPERATIONS:
                raise ValueError(f"source operation is not allowed: {operation!r}")
            validate_staging_lease(paths, staging_name, session_id)
            if operation == "source.promote":
                data = promote_staging(paths, staging_name, context_id=session_id)
            else:
                staging = reconcile_staging(paths, staging_name, context_id=session_id)
                data = {
                    "stagingArea": staging_name,
                    "generation": staging.get("generation"),
                    "headCommit": staging.get("headCommit"),
                }
            response: dict[str, Any] = {
                "schemaVersion": 1, "requestId": request_id,
                "sessionId": session_id, "operation": operation,
                "ok": True, "data": data,
            }
        except Exception as error:
            response = {
                "schemaVersion": 1, "requestId": request_id,
                "sessionId": session_id, "ok": False,
                "error": {"class": type(error).__name__, "message": str(error)},
            }
        atomic_json(response_path, response)
        request_path.unlink(missing_ok=True)
        handled += 1
    return handled


__all__ = ["ALLOWED_SOURCE_OPERATIONS", "MAX_SOURCE_REQUEST_BYTES", "service_source_requests"]
