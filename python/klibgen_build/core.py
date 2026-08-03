from __future__ import annotations

import hashlib
import json
import logging
import os
import platform
from dataclasses import dataclass
from pathlib import Path
from typing import Any


logger = logging.getLogger(__name__)


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

    @property
    def vendor(self) -> Path:
        """Return the acquisition cache shared by workspaces of one JJ repository."""
        configured = os.environ.get("KLIBGEN_VENDOR_ROOT")
        if configured:
            candidate = Path(configured)
            return (candidate if candidate.is_absolute() else self.root / candidate).resolve()

        repository_pointer = self.root / ".jj/repo"
        if repository_pointer.is_file():
            value = repository_pointer.read_text(encoding="utf-8").strip()
            if value:
                repository = Path(value)
                if not repository.is_absolute():
                    repository = repository_pointer.parent / repository
                repository = repository.resolve()
                if repository.name == "repo" and repository.parent.name == ".jj":
                    primary_root = repository.parent.parent
                    if (primary_root / "justfile").is_file() and (primary_root / "src").is_dir():
                        return primary_root / "vendor"
        return self.root / "vendor"

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
        result = cls(root=root, state=state.resolve())
        logger.debug("discovered build paths root=%s state=%s", result.root, result.state)
        return result

def platform_id() -> str:
    return f"{platform.system().lower()}-{platform.machine().lower()}"
