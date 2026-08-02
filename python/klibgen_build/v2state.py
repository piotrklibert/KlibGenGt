from __future__ import annotations

import shutil
import stat
from dataclasses import dataclass
from pathlib import Path

from .core import BuildPaths


V2_DIRECTORIES = (
    "store", "refs", "status", "workspaces", "staging", "sessions", "logs", "locks", "tmp"
)


@dataclass(frozen=True)
class V2Paths:
    root: Path

    @classmethod
    def for_build(cls, paths: BuildPaths) -> "V2Paths":
        return cls((paths.state / "v2").resolve())

    def initialize(self) -> None:
        self.root.mkdir(parents=True, exist_ok=True)
        for name in V2_DIRECTORIES:
            (self.root / name).mkdir(exist_ok=True)

    def owned(self, path: Path) -> Path:
        candidate = path.resolve()
        if candidate == self.root:
            raise ValueError("refusing to operate on the v0.2 state root itself")
        try:
            candidate.relative_to(self.root)
        except ValueError as error:
            raise ValueError(f"path is outside the v0.2 state root: {candidate}") from error
        return candidate

    def remove_tree(self, path: Path) -> None:
        candidate = self.owned(path)
        if candidate.is_symlink() or candidate.is_file():
            candidate.unlink(missing_ok=True)
        elif candidate.exists():
            for target in (candidate, *candidate.rglob("*")):
                if not target.is_symlink():
                    mode = stat.S_IWUSR | (stat.S_IXUSR if target.is_dir() else 0)
                    target.chmod(target.stat().st_mode | mode)
            shutil.rmtree(candidate)


__all__ = ["V2_DIRECTORIES", "V2Paths"]
