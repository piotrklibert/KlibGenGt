from __future__ import annotations

import click

from .common import emit


@click.group()
def cli() -> None:
    """Build, inspect, test, and maintain KlibGen-GT project artifacts."""


# Import command families after defining the root group. Each module registers
# its own groups and leaves as an import side effect.
from . import artifacts as _artifacts  # noqa: E402,F401
from . import host as _host  # noqa: E402,F401
from . import image as _image  # noqa: E402,F401
from . import maintenance as _maintenance  # noqa: E402,F401
from . import models as _models  # noqa: E402,F401
from . import recipes as _recipes  # noqa: E402,F401
from . import refactoring as _refactoring  # noqa: E402,F401
from . import sessions as _sessions  # noqa: E402,F401
from . import staging as _staging  # noqa: E402,F401
from . import ui as _ui  # noqa: E402,F401
from . import workspaces as _workspaces  # noqa: E402,F401


def main(argv: list[str] | None = None) -> int:
    """Run the Click CLI with optional explicit arguments and return its exit code."""
    try:
        result = cli.main(args=argv, prog_name="klibgen-build", standalone_mode=False)
        return 0 if result is None else int(result)
    except click.ClickException as error:
        error.show()
        return error.exit_code
    except click.exceptions.Exit as error:
        return error.exit_code


__all__ = ["cli", "emit", "main"]
