from __future__ import annotations

import logging
from dataclasses import dataclass
from os import PathLike
from pathlib import Path
from typing import Mapping, Sequence

from plumbum import local
from plumbum.commands.processes import CommandNotFound, ProcessExecutionError
from plumbum.machines.local import PlumbumLocalPopen

from .logging_config import TRACE


CommandArgument = str | PathLike[str]
logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class CommandResult:
    returncode: int
    stdout: str
    stderr: str


def _command(arguments: Sequence[CommandArgument]):
    if not arguments:
        raise ValueError("command must not be empty")
    try:
        return local[str(arguments[0])][tuple(str(argument) for argument in arguments[1:])]
    except CommandNotFound as error:
        raise ValueError(f"command not found: {arguments[0]}") from error


def run_command(
    arguments: Sequence[CommandArgument],
    *,
    check: bool = True,
    cwd: Path | None = None,
    env: Mapping[str, str] | None = None,
) -> CommandResult:
    logger.debug("running process executable=%s arguments=%d cwd=%s", arguments[0] if arguments else None, max(0, len(arguments) - 1), cwd)
    logger.log(TRACE, "process arguments=%r", tuple(str(argument) for argument in arguments))
    returncode, stdout, stderr = _command(arguments).run(
        retcode=0 if check else None,
        cwd=str(cwd) if cwd is not None else None,
        env=dict(env) if env is not None else None,
    )
    logger.debug("process finished executable=%s exitCode=%d", arguments[0], returncode)
    return CommandResult(returncode, stdout, stderr)


def start_command(
    arguments: Sequence[CommandArgument],
    *,
    cwd: Path | None = None,
    env: Mapping[str, str] | None = None,
    capture_output: bool = False,
) -> PlumbumLocalPopen:
    logger.debug("starting process executable=%s arguments=%d cwd=%s capture=%s", arguments[0] if arguments else None, max(0, len(arguments) - 1), cwd, capture_output)
    logger.log(TRACE, "process arguments=%r", tuple(str(argument) for argument in arguments))
    streams = {} if capture_output else {"stdout": None, "stderr": None}
    process = _command(arguments).popen(
        cwd=str(cwd) if cwd is not None else None,
        env=dict(env) if env is not None else None,
        **streams,
    )
    logger.debug("process started executable=%s pid=%d", arguments[0], process.pid)
    return process


def decode_output(value: bytes | str | None) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return value


__all__ = [
    "CommandResult",
    "ProcessExecutionError",
    "decode_output",
    "run_command",
    "start_command",
]
