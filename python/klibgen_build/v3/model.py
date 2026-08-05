from __future__ import annotations

import os
from abc import ABC, abstractmethod
from collections.abc import Callable, Iterable, Mapping, Sequence
from dataclasses import dataclass
from enum import Enum
from pathlib import Path, PurePosixPath
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from .executor import Executor
    from .workspaces import Workspace


class CachePolicy(Enum):
    NORMAL = "normal"
    ALWAYS_RUN = "always-run"


def _relative(value: str, label: str) -> Path:
    path = PurePosixPath(value)
    if not path.parts or path.is_absolute() or ".." in path.parts:
        raise ValueError(f"{label} must be a non-escaping relative path: {value!r}")
    return Path(*path.parts)


@dataclass(frozen=True)
class ExecutionContext:
    executor: Executor
    workspace: Workspace
    task_path: str

    @property
    def repository(self) -> Path:
        return self.workspace.worktree.root

    @property
    def work(self) -> Path:
        return self.workspace.work

    def scratch(self) -> Path:
        path = self.workspace.root / "tmp" / self.task_path.replace(":", "/")
        path.mkdir(parents=True, exist_ok=True)
        return path


class TaskInput(ABC):
    @abstractmethod
    def fingerprint(self, context: ExecutionContext) -> object: ...


@dataclass(frozen=True)
class PathInput(TaskInput):
    path: str
    workspace_relative: bool = False

    def __post_init__(self) -> None:
        _relative(self.path, "input")

    def fingerprint(self, context: ExecutionContext) -> object:
        root = context.work if self.workspace_relative else context.repository
        return context.executor.digest_path(root / _relative(self.path, "input"))


@dataclass(frozen=True)
class ValueInput(TaskInput):
    name: str
    value: object

    def fingerprint(self, context: ExecutionContext) -> object:
        del context
        return {"name": self.name, "value": self.value}


class TaskOutput(ABC):
    @abstractmethod
    def validate(self, context: ExecutionContext) -> None: ...


@dataclass(frozen=True)
class PathOutput(TaskOutput):
    path: str
    kind: str = "any"

    def __post_init__(self) -> None:
        _relative(self.path, "output")
        if self.kind not in {"any", "file", "directory"}:
            raise ValueError(f"invalid output kind: {self.kind!r}")

    def validate(self, context: ExecutionContext) -> None:
        target = context.work / _relative(self.path, "output")
        valid = target.exists() or target.is_symlink()
        if self.kind == "file":
            valid = target.is_file()
        elif self.kind == "directory":
            valid = target.is_dir()
        if not valid:
            raise RuntimeError(
                f"task {context.task_path!r} did not produce {self.kind} output {self.path!r}"
            )


class Task(ABC):
    cache_policy = CachePolicy.NORMAL

    def inputs(self, context: ExecutionContext) -> Iterable[TaskInput]:
        del context
        return ()

    def outputs(self, context: ExecutionContext) -> Iterable[TaskOutput]:
        del context
        return ()

    def parameters(self) -> Mapping[str, object]:
        return {}

    def implementation_key(self, context: ExecutionContext) -> object:
        return context.executor.implementation_key(self)

    @abstractmethod
    def run(self, context: ExecutionContext) -> None: ...


class TaskSequence(Sequence[tuple[str, Task]]):
    def __init__(self, entries: Mapping[str, Task] | Iterable[tuple[str, Task]] = ()):
        source = entries.items() if isinstance(entries, Mapping) else entries
        result: list[tuple[str, Task]] = []
        names: set[str] = set()
        for name, task in source:
            if not name or ":" in name or name in names:
                raise ValueError(f"invalid or duplicate task name: {name!r}")
            if not isinstance(task, Task):
                raise TypeError(f"{name!r} is not a Task")
            names.add(name)
            result.append((name, task))
        self._entries = tuple(result)

    @classmethod
    def from_value(cls, value: TaskSequence | Mapping[str, Task] | Iterable[tuple[str, Task]]) -> TaskSequence:
        return value if isinstance(value, cls) else cls(value)

    def __len__(self) -> int:
        return len(self._entries)

    def __getitem__(self, index):
        return self._entries[index]

    def replace(self, name: str, task: Task) -> TaskSequence:
        if name not in dict(self._entries):
            raise KeyError(name)
        return TaskSequence((current, task if current == name else value) for current, value in self)

    def insert_after(self, existing: str, name: str, task: Task) -> TaskSequence:
        result: list[tuple[str, Task]] = []
        for current, value in self:
            result.append((current, value))
            if current == existing:
                result.append((name, task))
        if existing not in dict(self._entries):
            raise KeyError(existing)
        return TaskSequence(result)

    def through(self, name: str) -> TaskSequence:
        result: list[tuple[str, Task]] = []
        for current, task in self:
            result.append((current, task))
            if current == name:
                return TaskSequence(result)
        raise KeyError(name)


class TaskGroup(Task):
    def __init__(self, entries: TaskSequence | Mapping[str, Task] | Iterable[tuple[str, Task]] | None = None):
        self._entries = None if entries is None else TaskSequence.from_value(entries)

    def steps(self) -> TaskSequence | Mapping[str, Task] | Iterable[tuple[str, Task]]:
        return self._entries or TaskSequence()

    def run(self, context: ExecutionContext) -> None:
        del context
        raise RuntimeError("TaskGroup execution is owned by Executor")


class CheckpointTaskGroup(TaskGroup):
    def checkpoint_name(self, context: ExecutionContext) -> str:
        return context.task_path


class RunPython(Task):
    def __init__(
        self,
        function: Callable[[Executor, Workspace], None],
        *,
        inputs: Iterable[TaskInput] = (),
        outputs: Iterable[TaskOutput] = (),
        parameters: Mapping[str, object] | None = None,
        implementation_key: object | None = None,
        always_run: bool = False,
    ):
        self.function = function
        self._inputs = tuple(inputs)
        self._outputs = tuple(outputs)
        self._parameters = dict(parameters or {})
        self._key = implementation_key
        if always_run:
            self.cache_policy = CachePolicy.ALWAYS_RUN

    def inputs(self, context: ExecutionContext) -> Iterable[TaskInput]:
        del context
        return self._inputs

    def outputs(self, context: ExecutionContext) -> Iterable[TaskOutput]:
        del context
        return self._outputs

    def parameters(self) -> Mapping[str, object]:
        return self._parameters

    def implementation_key(self, context: ExecutionContext) -> object:
        return self._key if self._key is not None else context.executor.callable_key(self.function)

    def run(self, context: ExecutionContext) -> None:
        self.function(context.executor, context.workspace)


class RunCommand(Task):
    def __init__(
        self,
        arguments: Sequence[str | os.PathLike[str]] | Callable[[ExecutionContext], Sequence[str | os.PathLike[str]]],
        *,
        cwd: Callable[[ExecutionContext], Path] | None = None,
        environment: Callable[[ExecutionContext], Mapping[str, str]] | None = None,
        inputs: Iterable[TaskInput] = (),
        outputs: Iterable[TaskOutput] = (),
    ):
        self.arguments = arguments
        self.cwd = cwd
        self.environment = environment
        self._inputs = tuple(inputs)
        self._outputs = tuple(outputs)

    def inputs(self, context: ExecutionContext) -> Iterable[TaskInput]:
        del context
        return self._inputs

    def outputs(self, context: ExecutionContext) -> Iterable[TaskOutput]:
        del context
        return self._outputs

    def parameters(self) -> Mapping[str, object]:
        return {"arguments": self.arguments if not callable(self.arguments) else repr(self.arguments)}

    def run(self, context: ExecutionContext) -> None:
        args = self.arguments(context) if callable(self.arguments) else self.arguments
        env = os.environ.copy()
        if self.environment:
            env.update(self.environment(context))
        context.executor.runner.run(args, cwd=self.cwd(context) if self.cwd else context.workspace.root, env=env)


class RunInImage(RunCommand):
    def __init__(self, *, script: str, environment: Callable[[ExecutionContext], Mapping[str, str]] | None = None):
        _relative(script, "Smalltalk script")
        super().__init__(
            lambda context: [
                context.work / "runtime/bin/GlamorousToolkit-cli",
                context.work / "image/GlamorousToolkit.image",
                "st",
                context.repository / script,
            ],
            environment=environment,
            inputs=(PathInput(script),),
        )
        self.script = script

    def parameters(self) -> Mapping[str, object]:
        return {"script": self.script}


class RunInImageTest(RunInImage):
    """Semantic alias for checked Smalltalk assertion scripts."""


def tasks(*entries: tuple[str, Task]) -> TaskSequence:
    return TaskSequence(entries)
