from __future__ import annotations

import logging
import uuid
from pathlib import Path
from typing import Any

from .core import BuildPaths
from .inventory_v2 import inventory
from .sessions import execute_session
from .store import atomic_json
from .v2state import V2Paths


logger = logging.getLogger(__name__)


def export_build_map_pngs(paths: BuildPaths, output: Path | None = None, force: bool = False) -> dict[str, Any]:
    v2 = V2Paths.for_build(paths)
    v2.initialize()
    input_path = v2.root / "tmp" / f"inventory-{uuid.uuid4()}.json"
    output_directory = (output or paths.root / "tmp/build-map").resolve()
    logger.info("exporting build map PNGs output=%s force=%s", output_directory, force)
    atomic_json(input_path, inventory(paths))
    try:
        result = execute_session(paths, {
            "operation": "build-map.png", "inventoryPath": str(input_path),
            "outputDirectory": str(output_directory), "force": force,
        })
        result["operation"] = "build-map-png"
        return result
    finally:
        input_path.unlink(missing_ok=True)


__all__ = ["export_build_map_pngs"]
