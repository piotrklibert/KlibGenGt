from __future__ import annotations

import os
import re
import resource
import signal
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Protocol, Sequence

from .processes import CommandResult, decode_output, run_command, start_command


@dataclass(frozen=True)
class ProcessInfo:
    pid: int
    state: str
    command: str


@dataclass(frozen=True)
class WindowInfo:
    id: int
    id_hex: str
    title: str
    pid: int | None
    command: str
    x: int
    y: int
    width: int
    height: int


@dataclass(frozen=True)
class WindowSelector:
    window_id: int | None = None
    pid: int | None = None
    title_regex: str | None = None
    command_regex: str | None = None


class DesktopBackend(Protocol):
    def windows(self) -> list[WindowInfo]: ...

    def screenshot(self, window: WindowInfo, output: Path) -> None: ...

    def focus(self, window: WindowInfo) -> None: ...

    def close(self, window: WindowInfo) -> None: ...


def _process_command(pid: int) -> str:
    try:
        value = (Path("/proc") / str(pid) / "cmdline").read_bytes()
    except (FileNotFoundError, PermissionError, ProcessLookupError):
        return ""
    return " ".join(part.decode("utf-8", errors="replace") for part in value.split(b"\0") if part)


def process_list(pid: int | None = None, command_regex: str | None = None) -> list[ProcessInfo]:
    pattern = re.compile(command_regex) if command_regex else None
    candidates = [Path("/proc") / str(pid)] if pid is not None else Path("/proc").iterdir()
    result: list[ProcessInfo] = []
    for entry in candidates:
        if not entry.name.isdigit():
            continue
        process_pid = int(entry.name)
        command = _process_command(process_pid)
        if pattern is not None and pattern.search(command) is None:
            continue
        try:
            stat = (entry / "stat").read_text(encoding="utf-8", errors="replace")
            state = stat[stat.rfind(")") + 2 :].split(maxsplit=1)[0]
        except (FileNotFoundError, PermissionError, ProcessLookupError, IndexError):
            continue
        result.append(ProcessInfo(process_pid, state, command))
    return sorted(result, key=lambda each: each.pid)


class X11DesktopBackend:
    def __init__(self, runner: Callable[..., CommandResult] = run_command):
        if not os.environ.get("DISPLAY"):
            raise ValueError("an X11 DISPLAY is required for desktop operations")
        self._run = runner

    def windows(self) -> list[WindowInfo]:
        listing = self._run(["xprop", "-root", "_NET_CLIENT_LIST_STACKING"], check=False)
        if listing.returncode != 0:
            raise RuntimeError(listing.stderr.strip() or "cannot query the X11 client list")
        identifiers = [int(value, 16) for value in re.findall(r"0x[0-9a-fA-F]+", listing.stdout)]
        result: list[WindowInfo] = []
        for identifier in dict.fromkeys(identifiers):
            window = self._window(identifier)
            if window is not None:
                result.append(window)
        return result

    def _window(self, identifier: int) -> WindowInfo | None:
        target = hex(identifier)
        properties = self._run(
            ["xprop", "-id", target, "_NET_WM_STATE", "_NET_WM_PID"], check=False
        )
        if properties.returncode != 0 or "_NET_WM_STATE_HIDDEN" in properties.stdout:
            return None
        title = self._run(["xdotool", "getwindowname", target], check=False)
        geometry = self._run(["xdotool", "getwindowgeometry", "--shell", target], check=False)
        if title.returncode != 0 or geometry.returncode != 0:
            return None
        values = dict(re.findall(r"^(X|Y|WIDTH|HEIGHT)=(-?\d+)$", geometry.stdout, re.MULTILINE))
        if not {"X", "Y", "WIDTH", "HEIGHT"}.issubset(values):
            return None
        pid_match = re.search(r"_NET_WM_PID\(CARDINAL\) = (\d+)", properties.stdout)
        pid = int(pid_match.group(1)) if pid_match else None
        return WindowInfo(
            id=identifier,
            id_hex=target,
            title=title.stdout.rstrip("\n"),
            pid=pid,
            command=_process_command(pid) if pid is not None else "",
            x=int(values["X"]),
            y=int(values["Y"]),
            width=int(values["WIDTH"]),
            height=int(values["HEIGHT"]),
        )

    def screenshot(self, window: WindowInfo, output: Path) -> None:
        output.parent.mkdir(parents=True, exist_ok=True)
        captured = self._run(["import", "-window", window.id_hex, str(output)], check=False)
        if captured.returncode != 0:
            raise RuntimeError(captured.stderr.strip() or f"failed to capture window {window.id_hex}")
        if not output.is_file() or output.stat().st_size == 0:
            raise RuntimeError(f"screenshot was not created: {output}")

    def focus(self, window: WindowInfo) -> None:
        focused = self._run(["xdotool", "windowactivate", "--sync", window.id_hex], check=False)
        if focused.returncode != 0:
            raise RuntimeError(focused.stderr.strip() or f"failed to focus window {window.id_hex}")

    def close(self, window: WindowInfo) -> None:
        self.focus(window)
        closed = self._run(
            ["xdotool", "key", "--window", window.id_hex, "alt+F4"], check=False
        )
        if closed.returncode != 0:
            raise RuntimeError(closed.stderr.strip() or f"failed to close window {window.id_hex}")


def select_windows(windows: Sequence[WindowInfo], selector: WindowSelector) -> list[WindowInfo]:
    title = re.compile(selector.title_regex) if selector.title_regex else None
    command = re.compile(selector.command_regex) if selector.command_regex else None
    return [
        window
        for window in windows
        if (selector.window_id is None or window.id == selector.window_id)
        and (selector.pid is None or window.pid == selector.pid)
        and (title is None or title.search(window.title) is not None)
        and (command is None or command.search(window.command) is not None)
    ]


def require_one_window(backend: DesktopBackend, selector: WindowSelector) -> WindowInfo:
    matches = select_windows(backend.windows(), selector)
    if not matches:
        raise ValueError("no window matches the supplied selector")
    if len(matches) != 1:
        candidates = ", ".join(f"{item.id_hex} {item.title!r}" for item in matches)
        raise ValueError(f"window selector is ambiguous: {candidates}")
    return matches[0]


def wait_until(predicate: Callable[[], bool], timeout: float, interval: float = 0.1) -> bool:
    deadline = time.monotonic() + timeout
    while True:
        if predicate():
            return True
        if time.monotonic() >= deadline:
            return False
        time.sleep(interval)


def wait_for_windows(
    backend: DesktopBackend, selector: WindowSelector, present: bool, timeout: float
) -> list[WindowInfo]:
    matches: list[WindowInfo] = []

    def ready() -> bool:
        nonlocal matches
        matches = select_windows(backend.windows(), selector)
        return bool(matches) is present

    if not wait_until(ready, timeout):
        state = "appear" if present else "disappear"
        raise TimeoutError(f"timed out after {timeout:g}s waiting for matching windows to {state}")
    return matches


def wait_for_processes(
    pid: int | None, command_regex: str | None, present: bool, timeout: float
) -> list[ProcessInfo]:
    matches: list[ProcessInfo] = []

    def ready() -> bool:
        nonlocal matches
        matches = process_list(pid, command_regex)
        return bool(matches) is present

    if not wait_until(ready, timeout):
        state = "appear" if present else "disappear"
        raise TimeoutError(f"timed out after {timeout:g}s waiting for matching processes to {state}")
    return matches


def terminate_process(pid: int, timeout: float, force: bool) -> dict[str, object]:
    if pid <= 0:
        raise ValueError("PID must be a positive integer")
    if pid == os.getpid():
        raise ValueError("refusing to terminate the CLI process itself")
    if not process_list(pid=pid):
        raise ValueError(f"process {pid} does not exist")
    os.kill(pid, signal.SIGTERM)
    forced = False
    if not wait_until(lambda: not process_list(pid=pid), timeout):
        if not force:
            raise TimeoutError(f"process {pid} did not exit after SIGTERM within {timeout:g}s")
        os.kill(pid, signal.SIGKILL)
        forced = True
        if not wait_until(lambda: not process_list(pid=pid), timeout):
            raise TimeoutError(f"process {pid} did not exit after SIGKILL within {timeout:g}s")
    return {"pid": pid, "forced": forced}


def profile_command(command: Sequence[str], capture: bool) -> dict[str, object]:
    if not command:
        raise ValueError("profile requires a command after --")
    before = resource.getrusage(resource.RUSAGE_CHILDREN)
    started = time.perf_counter_ns()
    process = start_command(command, capture_output=capture)
    stdout, stderr = process.communicate()
    elapsed = time.perf_counter_ns() - started
    after = resource.getrusage(resource.RUSAGE_CHILDREN)
    return {
        "command": list(command),
        "exitCode": process.returncode,
        "stdout": decode_output(stdout),
        "stderr": decode_output(stderr),
        "metrics": {
            "wallTimeNs": elapsed,
            "userCpuTimeNs": round((after.ru_utime - before.ru_utime) * 1_000_000_000),
            "systemCpuTimeNs": round((after.ru_stime - before.ru_stime) * 1_000_000_000),
        },
    }


def window_data(windows: Sequence[WindowInfo]) -> list[dict[str, object]]:
    return [
        {
            "id": window.id,
            "idHex": window.id_hex,
            "title": window.title,
            "pid": window.pid,
            "command": window.command,
            "x": window.x,
            "y": window.y,
            "width": window.width,
            "height": window.height,
        }
        for window in windows
    ]


def process_data(processes: Sequence[ProcessInfo]) -> list[dict[str, object]]:
    return [
        {"pid": process.pid, "state": process.state, "command": process.command}
        for process in processes
    ]
