from __future__ import annotations

import hashlib
import json
import os
import platform
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any


def canonical_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=True, sort_keys=True, separators=(",", ":"))


def digest_json(value: Any) -> str:
    return hashlib.sha256(canonical_json(value).encode("utf-8")).hexdigest()


def read_json(path: Path) -> Any:
    with path.open(encoding="utf-8") as stream:
        return json.load(stream)


@dataclass(frozen=True)
class BuildPaths:
    root: Path
    state: Path

    @classmethod
    def discover(cls) -> "BuildPaths":
        working_directory = Path.cwd().resolve()
        root = next(
            (
                candidate
                for candidate in (working_directory, *working_directory.parents)
                if (candidate / "justfile").is_file() and (candidate / "build/layers").is_dir()
            ),
            Path(__file__).resolve().parents[2],
        )
        configured = os.environ.get("KLIBGEN_STATE_ROOT", ".klibgen")
        state = Path(configured)
        if not state.is_absolute():
            state = root / state
        return cls(root=root, state=state.resolve())

    def context_file(self, context: str) -> Path:
        committed = self.root / "build" / "contexts" / f"{context}.json"
        generated = self.state / "contexts" / f"{context}.json"
        return committed if committed.is_file() else generated

    def layer_files(self) -> list[Path]:
        return sorted((self.root / "build" / "layers").glob("l*/layer.json"))


def load_context(paths: BuildPaths, context: str) -> dict[str, Any]:
    path = paths.context_file(context)
    if not path.is_file():
        raise ValueError(f"unknown context {context!r}: {path}")
    value = read_json(path)
    required = {"schemaVersion", "contextId", "layers"}
    missing = sorted(required - value.keys())
    if missing:
        raise ValueError(f"context {context!r} is missing: {', '.join(missing)}")
    if value["contextId"] != context:
        raise ValueError(f"context ID {value['contextId']!r} does not match {context!r}")
    return value


def load_layers(paths: BuildPaths) -> list[dict[str, Any]]:
    layers = [read_json(path) for path in paths.layer_files()]
    ids = [layer.get("layerId") for layer in layers]
    if ids != [f"L{number:02d}" for number in range(1, 8)]:
        raise ValueError(f"expected stable layers L01-L07, got {ids}")
    return layers


def platform_id() -> str:
    return f"{platform.system().lower()}-{platform.machine().lower()}"


def command_status(name: str) -> dict[str, Any]:
    path = shutil.which(name)
    return {"name": name, "ok": path is not None, "path": path}
