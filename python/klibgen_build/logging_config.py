"""Central logging policy for build tools and CLI commands."""

from __future__ import annotations

import logging
import sys
from typing import Final, TextIO


TRACE: Final = 5
LEVEL_NAMES: Final = ("TRACE", "DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL")
_HANDLER_MARKER = "_klibgen_build_handler"


def _trace(self: logging.Logger, message: object, *args: object, **kwargs: object) -> None:
    if self.isEnabledFor(TRACE):
        self._log(TRACE, message, args, **kwargs)


def install_trace_level() -> None:
    """Install the package's more-detailed-than-DEBUG logging level once."""
    if logging.getLevelName(TRACE) != "TRACE":
        logging.addLevelName(TRACE, "TRACE")
    if not hasattr(logging.Logger, "trace"):
        setattr(logging.Logger, "trace", _trace)


def level_number(level: str | int) -> int:
    """Resolve a supported logging level name or numeric value."""
    install_trace_level()
    if isinstance(level, int):
        return level
    normalized = level.upper()
    if normalized not in LEVEL_NAMES:
        raise ValueError(f"unknown log level {level!r}; choose from {', '.join(LEVEL_NAMES)}")
    return TRACE if normalized == "TRACE" else int(getattr(logging, normalized))


def configure_logging(level: str | int = "INFO", *, stream: TextIO | None = None) -> logging.Logger:
    """Configure package logging without changing application-wide root logging."""
    package_logger = logging.getLogger("klibgen_build")
    for handler in tuple(package_logger.handlers):
        if getattr(handler, _HANDLER_MARKER, False):
            package_logger.removeHandler(handler)
            handler.close()
    handler = logging.StreamHandler(stream if stream is not None else sys.stderr)
    setattr(handler, _HANDLER_MARKER, True)
    handler.setFormatter(logging.Formatter("%(levelname)s %(name)s: %(message)s"))
    package_logger.addHandler(handler)
    package_logger.setLevel(level_number(level))
    package_logger.propagate = False
    return package_logger


install_trace_level()


__all__ = ["LEVEL_NAMES", "TRACE", "configure_logging", "install_trace_level", "level_number"]
