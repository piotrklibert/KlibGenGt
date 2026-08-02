#!/usr/bin/env python3
"""Manifest-driven fake image process for v0.2 lifecycle host tests."""

from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path


def atomic_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: fake_vm.py SESSION_MANIFEST", file=sys.stderr)
        return 64
    manifest = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
    if manifest.get("schema") != "klibgen.session/1":
        print("unsupported session manifest", file=sys.stderr)
        return 65
    paths = manifest["paths"]
    outcome = manifest.get("fixture", {}).get("outcome", "succeeded")
    delay = float(manifest.get("fixture", {}).get("delaySeconds", 0))
    if outcome != "crash-before-ready":
        atomic_json(Path(paths["ready"]), {
            "schema": "klibgen.session-ready/1", "sessionId": manifest["sessionId"], "ready": True,
        })
    if delay:
        time.sleep(delay)
    if outcome in {"crash", "crash-before-ready"}:
        return 70
    if outcome == "timeout":
        time.sleep(float(manifest.get("fixture", {}).get("timeoutSeconds", 60)))
        return 71
    state = "failed" if outcome == "failed" else outcome
    atomic_json(Path(paths["completion"]), {
        "schema": "klibgen.session-completion/1",
        "sessionId": manifest["sessionId"],
        "state": state,
        "ok": state in {"succeeded", "saved", "discarded"},
    })
    return 1 if state == "failed" else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
