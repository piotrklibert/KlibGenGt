from __future__ import annotations

import hashlib
import inspect
import json
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from .commands import CommandRunner
from .model import CachePolicy, CheckpointTaskGroup, ExecutionContext, Task, TaskGroup, TaskSequence
from .workspaces import Workspace


def _stable(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), default=repr)


@dataclass(frozen=True)
class BoundTask:
    path: str
    task: Task
    groups: tuple[tuple[str, TaskGroup], ...]


@dataclass(frozen=True)
class CheckpointBoundary:
    path: str
    leaf_count: int


@dataclass(frozen=True)
class ExecutionPlan:
    leaves: tuple[BoundTask, ...]
    checkpoints: tuple[CheckpointBoundary, ...]


@dataclass(frozen=True)
class ExecutionResult:
    generation: Path
    reused: bool
    restored_checkpoint: str | None
    executed: tuple[str, ...]


class Executor:
    def __init__(self, *, runner: CommandRunner | None = None):
        self.runner = runner or CommandRunner()

    def digest_path(self, path: Path) -> object:
        if not path.exists() and not path.is_symlink():
            return {"kind": "missing"}
        if path.is_symlink():
            return {"kind": "symlink", "target": str(path.readlink())}
        if path.is_file():
            return {"kind": "file", "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        records = []
        for candidate in sorted(path.rglob("*")):
            relative = candidate.relative_to(path).as_posix()
            if candidate.is_symlink():
                records.append((relative, "symlink", str(candidate.readlink())))
            elif candidate.is_file():
                records.append((relative, "file", hashlib.sha256(candidate.read_bytes()).hexdigest()))
        return {"kind": "directory", "entries": records}

    def implementation_key(self, task: Task) -> object:
        try:
            source = inspect.getsource(type(task))
        except (OSError, TypeError):
            source = f"{type(task).__module__}.{type(task).__qualname__}"
        return hashlib.sha256(source.encode()).hexdigest()

    def callable_key(self, function: Callable) -> object:
        try:
            source = inspect.getsource(function)
        except (OSError, TypeError):
            code = getattr(function, "__code__", None)
            source = repr((getattr(code, "co_code", None), getattr(code, "co_consts", None), getattr(function, "__defaults__", None)))
        return hashlib.sha256(source.encode() if isinstance(source, str) else repr(source).encode()).hexdigest()

    def bind(self, root: Task, *, root_name: str = "build") -> ExecutionPlan:
        leaves: list[BoundTask] = []
        checkpoints: list[CheckpointBoundary] = []
        active: set[int] = set()
        used: set[int] = set()

        def visit(task: Task, path: str, groups: tuple[tuple[str, TaskGroup], ...]) -> None:
            identity = id(task)
            if identity in active:
                raise ValueError(f"task graph cycle at {path}")
            if identity in used:
                raise ValueError(f"task object reused at {path}")
            used.add(identity)
            if isinstance(task, TaskGroup):
                active.add(identity)
                child_groups = groups + ((path, task),)
                for name, child in TaskSequence.from_value(task.steps()):
                    visit(child, f"{path}:{name}", child_groups)
                active.remove(identity)
                if isinstance(task, CheckpointTaskGroup):
                    checkpoints.append(CheckpointBoundary(path, len(leaves)))
            else:
                leaves.append(BoundTask(path, task, groups))

        visit(root, root_name, ())
        if not leaves:
            raise ValueError("task graph must contain at least one executable leaf")
        return ExecutionPlan(tuple(leaves), tuple(checkpoints))

    def fingerprint(self, bound: BoundTask, workspace: Workspace) -> str:
        context = ExecutionContext(self, workspace, bound.path)
        group_data = [
            {
                "path": path,
                "implementation": self.implementation_key(group),
                "parameters": group.parameters(),
                "children": [name for name, _task in TaskSequence.from_value(group.steps())],
            }
            for path, group in bound.groups
        ]
        value = {
            "path": bound.path,
            "implementation": bound.task.implementation_key(context),
            "parameters": bound.task.parameters(),
            "inputs": [item.fingerprint(context) for item in bound.task.inputs(context)],
            "groups": group_data,
        }
        return hashlib.sha256(_stable(value).encode()).hexdigest()

    def _outputs_valid(self, bound: BoundTask, workspace: Workspace) -> bool:
        context = ExecutionContext(self, workspace, bound.path)
        try:
            for output in bound.task.outputs(context):
                output.validate(context)
            return True
        except RuntimeError:
            return False

    def execute(self, root: Task, workspace: Workspace, *, root_name: str = "build") -> ExecutionResult:
        plan = self.bind(root, root_name=root_name)
        workspace.initialize()
        with workspace.worktree.build_lock():
            state = workspace.state()
            current = workspace.current_generation()
            if current is not None:
                source = current / "payload"
                if not workspace.work.exists() or not any(workspace.work.iterdir()):
                    if workspace.work.exists():
                        shutil.rmtree(workspace.work)
                    shutil.copytree(source, workspace.work, symlinks=True)

            fingerprints = {leaf.path: self.fingerprint(leaf, workspace) for leaf in plan.leaves}
            old = {path: value.get("fingerprint") for path, value in state.get("tasks", {}).items()}
            dirty = len(plan.leaves)
            for index, leaf in enumerate(plan.leaves):
                if (
                    leaf.task.cache_policy is CachePolicy.ALWAYS_RUN
                    or old.get(leaf.path) != fingerprints[leaf.path]
                    or not self._outputs_valid(leaf, workspace)
                ):
                    dirty = index
                    break

            if dirty == len(plan.leaves) and current is not None:
                return ExecutionResult(current, True, None, ())

            restored: str | None = None
            for boundary in reversed(plan.checkpoints):
                if boundary.leaf_count > dirty:
                    continue
                manifest = workspace.checkpoint_manifest(boundary.path)
                expected = {leaf.path: fingerprints[leaf.path] for leaf in plan.leaves[: boundary.leaf_count]}
                if manifest and manifest.get("fingerprints") == expected:
                    workspace.restore_checkpoint(boundary.path)
                    dirty = boundary.leaf_count
                    restored = boundary.path
                    break
            else:
                if workspace.work.exists():
                    shutil.rmtree(workspace.work)
                workspace.work.mkdir(parents=True)

            executed: list[str] = []
            try:
                for index, leaf in enumerate(plan.leaves[dirty:], start=dirty):
                    context = ExecutionContext(self, workspace, leaf.path)
                    leaf.task.run(context)
                    for output in leaf.task.outputs(context):
                        output.validate(context)
                    executed.append(leaf.path)
                    for boundary in plan.checkpoints:
                        if boundary.leaf_count == index + 1:
                            prefix = {item.path: fingerprints[item.path] for item in plan.leaves[: boundary.leaf_count]}
                            workspace.save_checkpoint(boundary.path, prefix)
            except Exception as error:
                state["lastFailure"] = {"task": plan.leaves[dirty + len(executed)].path, "error": repr(error)}
                workspace.write_state(state)
                raise

            tasks = {leaf.path: {"fingerprint": fingerprints[leaf.path]} for leaf in plan.leaves}
            generation = workspace.publish(fingerprints)
            workspace.write_state({"schema": "klibgen.v3.state/1", "tasks": tasks, "lastFailure": None})
            return ExecutionResult(generation, False, restored, tuple(executed))
