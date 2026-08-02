import json
import os
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import patch

from klibgen_build.cli import parser
from klibgen_build.core import BuildPaths
from klibgen_build.ui_control import active_gui_runs, select_gui_run, submit_ui_request


ROOT = Path(__file__).resolve().parents[2]


class UiControlTest(unittest.TestCase):
    def setUp(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=ROOT / "tmp")
        self.addCleanup(self.temporary.cleanup)
        state = Path(self.temporary.name) / "state"
        self.paths = BuildPaths(ROOT, state)

    def run_record(self, run_id="one", *, state="running", ready=True, pid=123):
        run = self.paths.state / "runs/gui" / run_id
        (run / "tmp/ui-control/requests").mkdir(parents=True)
        (run / "tmp/ui-control/responses").mkdir()
        (run / "run.json").write_text(json.dumps({
            "schemaVersion": 2, "runId": run_id, "contextId": "gui",
            "profile": "gui", "state": state, "pid": pid,
        }))
        if ready:
            (run / "tmp/ui-control/ready.json").write_text(json.dumps({
                "schemaVersion": 1, "runId": run_id, "ready": True,
            }))
        return run

    @patch("klibgen_build.ui_control.process_is_alive", return_value=True)
    def test_discovery_filters_stopped_and_reports_readiness(self, _alive):
        self.run_record("live")
        self.run_record("stopped", state="stopped")
        runs = active_gui_runs(self.paths)
        self.assertEqual([item["runId"] for item in runs], ["live"])
        self.assertTrue(runs[0]["ready"]["ready"])

    @patch("klibgen_build.ui_control.process_is_alive", return_value=True)
    def test_selection_requires_unique_ready_run(self, _alive):
        self.run_record("one")
        self.assertEqual(select_gui_run(self.paths)["runId"], "one")
        self.run_record("two")
        with self.assertRaisesRegex(ValueError, "multiple active"):
            select_gui_run(self.paths)
        self.assertEqual(select_gui_run(self.paths, run_id="two")["runId"], "two")
        self.run_record("unready", ready=False)
        with self.assertRaisesRegex(ValueError, "not ready"):
            select_gui_run(self.paths, run_id="unready")

    @patch("klibgen_build.ui_control.process_is_alive", return_value=True)
    def test_atomic_submission_matches_response(self, _alive):
        run = self.run_record()
        seen = {}

        def server():
            request_dir = run / "tmp/ui-control/requests"
            deadline = time.monotonic() + 2
            while time.monotonic() < deadline:
                files = list(request_dir.glob("*.json"))
                if files:
                    request = json.loads(files[0].read_text())
                    seen.update(request)
                    response = {
                        "schemaVersion": 1, "requestId": request["requestId"],
                        "runId": "one", "operation": request["operation"],
                        "ok": True, "data": {"value": 42},
                    }
                    target = run / "tmp/ui-control/responses" / f"{request['requestId']}.json"
                    target.write_text(json.dumps(response))
                    return
                time.sleep(0.005)

        thread = threading.Thread(target=server)
        thread.start()
        response = submit_ui_request(self.paths, {"operation": "ui.query", "class": "BrButton"})
        thread.join()
        self.assertTrue(response["ok"])
        self.assertEqual(response["data"]["value"], 42)
        self.assertEqual(seen["runId"], "one")
        self.assertGreater(seen["deadlineUnixMs"], int(time.time() * 1000))

    @patch("klibgen_build.ui_control.process_is_alive", return_value=True)
    def test_submission_deadline_removes_unclaimed_request(self, _alive):
        run = self.run_record()
        with self.assertRaises(TimeoutError):
            submit_ui_request(self.paths, {"operation": "ui.spaces"}, timeout=0.03)
        self.assertEqual(list((run / "tmp/ui-control/requests").glob("*.json")), [])

    def test_cli_covers_selectors_actions_wait_batch_and_eval(self):
        parsed = parser().parse_args([
            "ui", "act", "drag", "--node", "node-7", "--dx", "3", "--dy", "4",
            "--text-regex", "Save.*", "--no-visible", "--run", "r1",
        ])
        self.assertEqual(parsed.ui_action, "act")
        self.assertEqual((parsed.dx, parsed.dy), (3, 4))
        self.assertFalse(parsed.visible)
        self.assertEqual(parser().parse_args(["ui", "wait", "focused", "--class", "BrEditor"]).state, "focused")
        self.assertTrue(parser().parse_args(["ui", "batch", "--stdin"]).stdin)
        self.assertEqual(parser().parse_args(["ui", "eval", "1 + 2"]).expression, "1 + 2")


if __name__ == "__main__":
    unittest.main()
