from __future__ import annotations

import os
import time
from pathlib import Path
from typing import Any, Callable

from .json_models import validate_named_record


TRACKED_SUFFIXES = {".image", ".changes", ".so", ".dylib", ".dll"}


def storage_metrics(root: Path) -> dict[str, Any]:
    logical = allocated = 0
    counts = {suffix: {"count": 0, "logicalBytes": 0} for suffix in sorted(TRACKED_SUFFIXES)}
    if not root.exists():
        return {"logicalBytes": 0, "allocatedBytes": 0, "files": counts}
    for directory, names, files in os.walk(root, followlinks=False):
        base = Path(directory)
        names[:] = [name for name in names if not (base / name).is_symlink()]
        for name in files:
            path = base / name
            stat = path.lstat()
            logical += stat.st_size
            allocated += getattr(stat, "st_blocks", 0) * 512
            if path.suffix.lower() in counts:
                counts[path.suffix.lower()]["count"] += 1
                counts[path.suffix.lower()]["logicalBytes"] += stat.st_size
    return {"logicalBytes": logical, "allocatedBytes": allocated, "files": counts}


def measure(operation: str, state_root: Path, action: Callable[[], int]) -> dict[str, Any]:
    before = storage_metrics(state_root)
    started = time.monotonic()
    exit_code = action()
    elapsed = time.monotonic() - started
    after = storage_metrics(state_root)
    return validate_named_record({
        "schema": "klibgen.measurement/1",
        "schemaVersion": 1,
        "operation": operation,
        "exitCode": exit_code,
        "wallSeconds": elapsed,
        "before": before,
        "after": after,
        "logicalByteDelta": after["logicalBytes"] - before["logicalBytes"],
        "allocatedByteDelta": after["allocatedBytes"] - before["allocatedBytes"],
    })


__all__ = ["measure", "storage_metrics"]
