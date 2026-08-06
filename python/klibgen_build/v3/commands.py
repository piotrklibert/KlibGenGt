from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass
from os import PathLike
from pathlib import Path
from typing import Mapping, Sequence


CommandArgument = str | PathLike[str]


@dataclass(frozen=True)
class CommandResult:
    returncode: int
    stdout: str
    stderr: str


class CommandRunner:
    """Small subprocess facade shared by v0.3 tasks and workspace services."""

    def run(
        self,
        arguments: Sequence[CommandArgument],
        *,
        check: bool = True,
        cwd: Path | None = None,
        env: Mapping[str, str] | None = None,
    ) -> CommandResult:
        if not arguments:
            raise ValueError("command must not be empty")
        completed = subprocess.run(
            [os.fspath(argument) for argument in arguments],
            cwd=cwd,
            env=dict(env) if env is not None else None,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        result = CommandResult(completed.returncode, completed.stdout, completed.stderr)
        if check and result.returncode != 0:
            rendered = " ".join(os.fspath(argument) for argument in arguments)
            detail = result.stderr.strip() or result.stdout.strip()
            raise RuntimeError(
                f"command failed with exit code {result.returncode}: {rendered}"
                + (f"\n{detail}" if detail else "")
            )
        return result


__all__ = ["CommandArgument", "CommandResult", "CommandRunner"]
