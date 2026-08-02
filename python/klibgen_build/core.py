from __future__ import annotations

import hashlib
import json
import os
import platform
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
                if (candidate / "justfile").is_file() and (candidate / "src").is_dir()
            ),
            Path(__file__).resolve().parents[2],
        )
        configured = os.environ.get("KLIBGEN_STATE_ROOT", ".klibgen")
        state = Path(configured)
        if not state.is_absolute():
            state = root / state
        return cls(root=root, state=state.resolve())

def platform_id() -> str:
    return f"{platform.system().lower()}-{platform.machine().lower()}"
