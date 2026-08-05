from __future__ import annotations

import os
import shutil
import uuid
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterator, Protocol

from .commands import CommandRunner
from .workspaces import Worktree


@dataclass(frozen=True)
class StagingArea:
    name: str
    root: Path
    source_git: Path

    @property
    def source_root(self) -> Path:
        return self.source_git.parent / "src"


@dataclass(frozen=True)
class IntegrationResult:
    area: StagingArea
    preview: tuple[str, ...]
    applied: bool
    backup: Path | None = None


class StagingBackend(Protocol):
    def create(self, worktree: Worktree, name: str) -> StagingArea: ...
    def list(self, worktree: Worktree) -> tuple[StagingArea, ...]: ...
    def reconcile(self, worktree: Worktree, name: str) -> StagingArea: ...
    def changes(self, worktree: Worktree, name: str) -> dict: ...
    def accept_integrated(self, worktree: Worktree, name: str) -> StagingArea: ...
    def acquire(self, worktree: Worktree, name: str, *, kind: str, owner: str, pid: int) -> StagingArea: ...
    def release(self, worktree: Worktree, name: str, *, owner: str) -> None: ...


class LegacyStagingBackend:
    """Adapter for the v0.2 private Git/Iceberg staging implementation."""

    @staticmethod
    def _paths(worktree: Worktree):
        from klibgen_build.core import BuildPaths
        return BuildPaths(root=worktree.root, state=worktree.root / ".klibgen")

    @staticmethod
    def _area(record: dict) -> StagingArea:
        value = record.get("staging", record)
        root = Path(record.get("path", Path(value["sourceGit"]).parent.parent))
        return StagingArea(value["name"], root, Path(value["sourceGit"]))

    def create(self, worktree: Worktree, name: str) -> StagingArea:
        from klibgen_build.staging import create_staging
        return self._area(create_staging(self._paths(worktree), name))

    def list(self, worktree: Worktree) -> tuple[StagingArea, ...]:
        from klibgen_build.staging import list_staging
        return tuple(self._area(value) for value in list_staging(self._paths(worktree))["stagingAreas"])

    def reconcile(self, worktree: Worktree, name: str) -> StagingArea:
        from klibgen_build.staging import rebase_staging
        return self._area(rebase_staging(self._paths(worktree), name))

    def changes(self, worktree: Worktree, name: str) -> dict:
        from klibgen_build.staging import staging_changes
        return staging_changes(self._paths(worktree), name)

    def accept_integrated(self, worktree: Worktree, name: str) -> StagingArea:
        # Rebase after rsync observes that authoritative src now equals overlay and
        # advances the v0.2 imported base without a second copy into authoritative src.
        return self.reconcile(worktree, name)

    def acquire(self, worktree: Worktree, name: str, *, kind: str, owner: str, pid: int) -> StagingArea:
        from klibgen_build.staging import acquire_staging_lease
        record = acquire_staging_lease(self._paths(worktree), name, kind, owner, pid)
        return self._area(record)

    def release(self, worktree: Worktree, name: str, *, owner: str) -> None:
        from klibgen_build.staging import release_staging_lease
        release_staging_lease(self._paths(worktree), name, owner)


class RsyncSynchronizer:
    def __init__(self, runner: CommandRunner | None = None):
        self.runner = runner or CommandRunner()

    def preview(self, source: Path, destination: Path) -> tuple[str, ...]:
        destination.mkdir(parents=True, exist_ok=True)
        result = self.runner.run(
            ["rsync", "--archive", "--delete", "--itemize-changes", "--dry-run", f"{source}/", f"{destination}/"]
        )
        return tuple(line for line in result.stdout.splitlines() if line)

    def apply(self, source: Path, destination: Path) -> None:
        destination.mkdir(parents=True, exist_ok=True)
        self.runner.run(
            ["rsync", "--archive", "--delete", "--delay-updates", "--delete-delay", f"{source}/", f"{destination}/"]
        )


class StagingAreaManager:
    def __init__(
        self,
        worktree: Worktree,
        *,
        backend: StagingBackend | None = None,
        synchronizer: RsyncSynchronizer | None = None,
    ):
        self.worktree = worktree
        self.backend = backend or LegacyStagingBackend()
        self.synchronizer = synchronizer or RsyncSynchronizer(worktree.runner)

    def ensure(self, name: str) -> StagingArea:
        for area in self.backend.list(self.worktree):
            if area.name == name:
                return area
        return self.backend.create(self.worktree, name)

    def list(self) -> tuple[StagingArea, ...]:
        return self.backend.list(self.worktree)

    @contextmanager
    def lease(self, name: str, *, kind: str, owner: str, pid: int | None = None) -> Iterator[StagingArea]:
        area = self.backend.acquire(self.worktree, name, kind=kind, owner=owner, pid=pid or os.getpid())
        try:
            yield area
        finally:
            self.backend.release(self.worktree, name, owner=owner)

    def integrate(
        self,
        name: str,
        *,
        dry_run: bool = False,
        validate: Callable[[Path], None] | None = None,
    ) -> IntegrationResult:
        with self.worktree.build_lock():
            area = self.backend.reconcile(self.worktree, name)
            changes = self.backend.changes(self.worktree, name)
            prohibited = changes.get("prohibited", ())
            if prohibited:
                raise ValueError("staging contains paths outside owned packages: " + ", ".join(prohibited))
            destination = self.worktree.root / "src"
            preview = self.synchronizer.preview(area.source_root, destination)
            if dry_run:
                return IntegrationResult(area, preview, False)

            backup = self.worktree.root / ".klibgen/v3/integration-backups" / uuid.uuid4().hex
            if destination.exists():
                backup.parent.mkdir(parents=True, exist_ok=True)
                shutil.copytree(destination, backup, symlinks=True)
            try:
                self.synchronizer.apply(area.source_root, destination)
                if validate:
                    validate(destination)
                area = self.backend.accept_integrated(self.worktree, name)
            except Exception:
                if destination.exists():
                    shutil.rmtree(destination)
                if backup.exists():
                    shutil.copytree(backup, destination, symlinks=True)
                raise
            return IntegrationResult(area, preview, True, backup)
