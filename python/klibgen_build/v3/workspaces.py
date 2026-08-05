from __future__ import annotations

import fcntl
import json
import os
import shutil
import threading
import uuid
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator

from .commands import CommandRunner

_PROCESS_LOCKS: dict[Path, tuple[threading.RLock, int, object | None]] = {}
_PROCESS_LOCKS_GUARD = threading.Lock()


def _copy(source: Path, destination: Path) -> None:
    if destination.exists():
        shutil.rmtree(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, destination, symlinks=True)


def _write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, path)


@dataclass(frozen=True)
class Worktree:
    name: str
    root: Path
    primary_root: Path
    runner: CommandRunner = CommandRunner()

    @property
    def shared_root(self) -> Path:
        return self.primary_root / ".klibgen/v3/shared"

    @contextmanager
    def build_lock(self) -> Iterator[None]:
        path = self.shared_root / "build.lock"
        path.parent.mkdir(parents=True, exist_ok=True)
        with _PROCESS_LOCKS_GUARD:
            lock, count, stream = _PROCESS_LOCKS.get(path, (threading.RLock(), 0, None))
            _PROCESS_LOCKS[path] = (lock, count, stream)
        with lock:
            current_lock, count, stream = _PROCESS_LOCKS[path]
            if count == 0:
                stream = path.open("w")
                fcntl.flock(stream, fcntl.LOCK_EX)
            _PROCESS_LOCKS[path] = (current_lock, count + 1, stream)
            try:
                yield
            finally:
                current_lock, count, stream = _PROCESS_LOCKS[path]
                if count == 1:
                    assert stream is not None
                    fcntl.flock(stream, fcntl.LOCK_UN)
                    stream.close()
                    stream = None
                _PROCESS_LOCKS[path] = (current_lock, count - 1, stream)

    def workspace(self, name: str = "default") -> Workspace:
        return Workspace(name, self, self.root / ".klibgen/v3/workspaces" / name)


@dataclass(frozen=True)
class Workspace:
    name: str
    worktree: Worktree
    root: Path

    @property
    def work(self) -> Path:
        return self.root / "work"

    @property
    def state_path(self) -> Path:
        return self.root / "state.json"

    def initialize(self) -> None:
        self.work.mkdir(parents=True, exist_ok=True)
        _write_json(self.root / "workspace.json", {"schema": "klibgen.v3.workspace/1", "name": self.name})

    def state(self) -> dict:
        if not self.state_path.is_file():
            return {"schema": "klibgen.v3.state/1", "tasks": {}}
        return json.loads(self.state_path.read_text(encoding="utf-8"))

    def write_state(self, value: dict) -> None:
        _write_json(self.state_path, value)

    def checkpoint_path(self, name: str) -> Path:
        return self.root / "checkpoints" / name.replace(":", "__")

    def save_checkpoint(self, name: str, fingerprints: dict[str, str]) -> None:
        target = self.checkpoint_path(name)
        temporary = target.with_name(f".{target.name}.{uuid.uuid4().hex}")
        (temporary / "payload").parent.mkdir(parents=True, exist_ok=True)
        _copy(self.work, temporary / "payload")
        _write_json(temporary / "checkpoint.json", {"name": name, "fingerprints": fingerprints})
        if target.exists():
            shutil.rmtree(target)
        os.replace(temporary, target)

    def restore_checkpoint(self, name: str) -> None:
        _copy(self.checkpoint_path(name) / "payload", self.work)

    def checkpoint_manifest(self, name: str) -> dict | None:
        path = self.checkpoint_path(name) / "checkpoint.json"
        return json.loads(path.read_text(encoding="utf-8")) if path.is_file() else None

    def current_generation(self) -> Path | None:
        path = self.root / "current.json"
        if not path.is_file():
            return None
        return Path(json.loads(path.read_text(encoding="utf-8"))["path"])

    def publish(self, fingerprints: dict[str, str]) -> Path:
        generation = self.root / "generations" / uuid.uuid4().hex
        _copy(self.work, generation / "payload")
        _write_json(generation / "generation.json", {"fingerprints": fingerprints})
        _write_json(self.root / "current.json", {"path": str(generation)})
        return generation


class WorkspaceManager:
    def __init__(self, worktree: Worktree):
        self.worktree = worktree

    def create(self, name: str, *, seed: Workspace | None = None) -> Workspace:
        workspace = self.worktree.workspace(name)
        with self.worktree.build_lock():
            if workspace.root.exists():
                raise ValueError(f"workspace already exists: {name}")
            workspace.initialize()
            if seed is not None:
                if seed.current_generation() is not None:
                    _copy(seed.current_generation() / "payload", workspace.work)
                    workspace.publish({})
                for source in (seed.root / "checkpoints").glob("*") if (seed.root / "checkpoints").is_dir() else ():
                    _copy(source, workspace.root / "checkpoints" / source.name)
        return workspace

    def list(self) -> tuple[Workspace, ...]:
        root = self.worktree.root / ".klibgen/v3/workspaces"
        return tuple(self.worktree.workspace(path.name) for path in sorted(root.glob("*")) if path.is_dir()) if root.is_dir() else ()

    def remove(self, name: str) -> None:
        workspace = self.worktree.workspace(name)
        with self.worktree.build_lock():
            if workspace.root.exists():
                shutil.rmtree(workspace.root)


class WorktreeManager:
    def __init__(self, primary_root: Path, *, runner: CommandRunner | None = None):
        self.primary_root = primary_root.resolve()
        self.runner = runner or CommandRunner()

    @property
    def primary(self) -> Worktree:
        return Worktree("default", self.primary_root, self.primary_root, self.runner)

    def create(self, name: str, *, revision: str = "@") -> Worktree:
        destination = self.primary_root / ".worktrees" / name
        with self.primary.build_lock():
            self.runner.run(
                [
                    "jj", "--ignore-working-copy", "workspace", "add",
                    "--name", name, "--revision", revision, destination,
                ],
                cwd=self.primary_root,
            )
            self.runner.run(
                [
                    "jj", "--ignore-working-copy", "config", "set", "--workspace",
                    "snapshot.auto-track", "none()",
                ],
                cwd=destination,
            )
        return Worktree(name, destination, self.primary_root, self.runner)

    def list(self) -> tuple[Worktree, ...]:
        root = self.primary_root / ".worktrees"
        values = [self.primary]
        if root.is_dir():
            values.extend(Worktree(path.name, path, self.primary_root, self.runner) for path in sorted(root.iterdir()) if path.is_dir())
        return tuple(values)

    def remove(self, name: str) -> None:
        if name == "default":
            raise ValueError("cannot remove primary worktree")
        destination = self.primary_root / ".worktrees" / name
        with self.primary.build_lock():
            self.runner.run(["jj", "--ignore-working-copy", "workspace", "forget", name], cwd=self.primary_root)
            if destination.exists():
                shutil.rmtree(destination)


@dataclass(frozen=True)
class LaunchProfile:
    name: str
    writable: bool
    persistent: bool


READ_ONLY_CLI = LaunchProfile("cli", False, False)
AGENTIC_CLI = LaunchProfile("agentic", True, False)
WRITABLE_GUI = LaunchProfile("gui", True, True)


def materialize_launch(workspace: Workspace, profile: LaunchProfile) -> Path:
    generation = workspace.current_generation()
    if generation is None:
        raise RuntimeError(f"workspace {workspace.name!r} has no published generation")
    payload = generation / "payload"
    if not profile.writable:
        return payload
    root = workspace.root / "launches" / (profile.name if profile.persistent else uuid.uuid4().hex)
    _copy(payload, root)
    for path in (root, *root.rglob("*")):
        if not path.is_symlink():
            path.chmod(path.stat().st_mode | 0o200)
    return root
