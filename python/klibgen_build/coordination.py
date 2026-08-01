from __future__ import annotations

import fcntl
import threading
from contextlib import contextmanager
from functools import wraps
from pathlib import Path
from typing import Any, Callable, Iterator, TypeVar

from .core import BuildPaths


_local = threading.local()
_Result = TypeVar("_Result")


@contextmanager
def retention_lock(paths: BuildPaths, *, exclusive: bool = False) -> Iterator[None]:
    """Coordinate cache readers/builders with destructive retention operations."""
    lock_path = paths.state / "state/locks/retention.lock"
    resolved = lock_path.resolve()
    locks: dict[Path, tuple[Any, int, bool]] = getattr(_local, "locks", {})
    _local.locks = locks
    existing = locks.get(resolved)
    if existing is not None:
        stream, depth, held_exclusive = existing
        if exclusive and not held_exclusive:
            raise RuntimeError("cannot upgrade a shared retention lock")
        locks[resolved] = (stream, depth + 1, held_exclusive)
        try:
            yield
        finally:
            stream, depth, held_exclusive = locks[resolved]
            locks[resolved] = (stream, depth - 1, held_exclusive)
        return

    lock_path.parent.mkdir(parents=True, exist_ok=True)
    stream = lock_path.open("w")
    try:
        fcntl.flock(stream, fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH)
        locks[resolved] = (stream, 1, exclusive)
        yield
    finally:
        locks.pop(resolved, None)
        stream.close()


def with_shared_retention_lock(function: Callable[..., _Result]) -> Callable[..., _Result]:
    """Wrap a function whose first argument is a BuildPaths instance."""
    @wraps(function)
    def wrapped(paths: BuildPaths, *args: Any, **kwargs: Any) -> _Result:
        with retention_lock(paths):
            return function(paths, *args, **kwargs)

    return wrapped
