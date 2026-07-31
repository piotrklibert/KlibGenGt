import json
import os
import sys
import unittest
import tempfile
from pathlib import Path
from unittest.mock import patch

from klibgen_build.host_tools import (
    CommandResult,
    WindowInfo,
    WindowSelector,
    X11DesktopBackend,
    profile_command,
    require_one_window,
    select_windows,
    wait_for_windows,
    terminate_process,
)
from klibgen_build.processes import run_command


ROOT = Path(__file__).resolve().parents[2]


class FakeDesktop:
    def __init__(self, snapshots):
        self.snapshots = list(snapshots)
        self.index = 0
        self.actions = []

    def windows(self):
        value = self.snapshots[min(self.index, len(self.snapshots) - 1)]
        self.index += 1
        return value

    def screenshot(self, window, output):
        self.actions.append(("screenshot", window.id, output))

    def focus(self, window):
        self.actions.append(("focus", window.id))

    def close(self, window):
        self.actions.append(("close", window.id))


def window(identifier, title="Glamorous Toolkit", pid=42, command="/opt/gt/GlamorousToolkit"):
    return WindowInfo(identifier, hex(identifier), title, pid, command, 10, 20, 800, 600)


class HostToolsTest(unittest.TestCase):
    def test_window_selectors_compose_and_ambiguity_is_rejected(self):
        windows = [window(1), window(2, "Terminal", 43, "/usr/bin/xterm")]
        selected = select_windows(
            windows,
            WindowSelector(pid=42, title_regex="^Glamorous", command_regex="GlamorousToolkit$"),
        )
        self.assertEqual([item.id for item in selected], [1])
        with self.assertRaisesRegex(ValueError, "ambiguous"):
            require_one_window(FakeDesktop([windows]), WindowSelector())

    def test_window_wait_handles_appearance_and_disappearance(self):
        target = window(1)
        appeared = wait_for_windows(
            FakeDesktop([[], [target]]), WindowSelector(title_regex="Toolkit"), True, 0.2
        )
        self.assertEqual(appeared, [target])
        disappeared = wait_for_windows(
            FakeDesktop([[target], []]), WindowSelector(window_id=1), False, 0.2
        )
        self.assertEqual(disappeared, [])

    def test_x11_backend_uses_managed_clients_and_skips_hidden_windows(self):
        calls = []

        def runner(arguments, check=False):
            calls.append(arguments)
            if arguments[:2] == ["xprop", "-root"]:
                return CommandResult(0, "_NET_CLIENT_LIST_STACKING(WINDOW): window id # 0x1, 0x2, 0x1\n", "")
            if arguments[:3] == ["xprop", "-id", "0x1"]:
                return CommandResult(0, "_NET_WM_STATE(ATOM) =\n_NET_WM_PID(CARDINAL) = 42\n", "")
            if arguments[:3] == ["xprop", "-id", "0x2"]:
                return CommandResult(0, "_NET_WM_STATE(ATOM) = _NET_WM_STATE_HIDDEN\n_NET_WM_PID(CARDINAL) = 43\n", "")
            if arguments[:2] == ["xdotool", "getwindowname"]:
                return CommandResult(0, "Glamorous Toolkit\n", "")
            if arguments[:2] == ["xdotool", "getwindowgeometry"]:
                return CommandResult(0, "WINDOW=1\nX=10\nY=20\nWIDTH=800\nHEIGHT=600\n", "")
            raise AssertionError(arguments)

        with patch.dict(os.environ, {"DISPLAY": ":99"}):
            backend = X11DesktopBackend(runner)
            with patch("klibgen_build.host_tools._process_command", return_value="gt --image image"):
                windows = backend.windows()
        self.assertEqual(len(windows), 1)
        self.assertEqual(windows[0].id_hex, "0x1")
        self.assertEqual(sum(call[:3] == ["xprop", "-id", "0x1"] for call in calls), 1)

    def test_normal_close_focuses_then_sends_alt_f4(self):
        calls = []

        def runner(arguments, check=False):
            calls.append(arguments)
            return CommandResult(0, "", "")

        with patch.dict(os.environ, {"DISPLAY": ":99"}):
            backend = X11DesktopBackend(runner)
            backend.close(window(1))
        self.assertEqual(calls[0], ["xdotool", "windowactivate", "--sync", "0x1"])
        self.assertEqual(calls[1], ["xdotool", "key", "--window", "0x1", "alt+F4"])

    def test_screenshot_creates_parent_and_validates_output(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "tmp") as temporary:
            output = Path(temporary) / "nested/capture.png"

            def runner(arguments, check=False):
                if arguments[0] == "import":
                    Path(arguments[-1]).write_bytes(b"png")
                return CommandResult(0, "", "")

            with patch.dict(os.environ, {"DISPLAY": ":99"}):
                X11DesktopBackend(runner).screenshot(window(1), output)
            self.assertEqual(output.read_bytes(), b"png")

    def test_process_termination_refuses_the_cli_pid(self):
        with self.assertRaisesRegex(ValueError, "CLI process"):
            terminate_process(os.getpid(), timeout=0, force=False)

    def test_host_profiler_reports_timing_and_preserves_exit_code(self):
        result = profile_command(
            [sys.executable, "-c", "import sys; print('out'); print('err', file=sys.stderr); raise SystemExit(3)"],
            capture=True,
        )
        self.assertEqual(result["exitCode"], 3)
        self.assertEqual(result["stdout"], "out\n")
        self.assertEqual(result["stderr"], "err\n")
        self.assertGreater(result["metrics"]["wallTimeNs"], 0)

    def test_host_cli_json_is_jq_compatible(self):
        environment = os.environ.copy()
        environment["PYTHONPATH"] = str(ROOT / "python")
        result = run_command(
            [sys.executable, "-m", "klibgen_build", "host", "processes", "list", "--pid", str(os.getpid()), "--json"],
            cwd=ROOT,
            env=environment,
        )
        value = json.loads(result.stdout)
        self.assertEqual(value["operation"], "host.processes.list")
        self.assertEqual(value["data"]["processes"][0]["pid"], os.getpid())


if __name__ == "__main__":
    unittest.main()
