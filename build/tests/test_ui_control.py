import json
import os
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import patch

from click.testing import CliRunner

from klibgen_build.cli import cli
from klibgen_build.core import BuildPaths
from klibgen_build.ui_control import active_gui_sessions, select_gui_session, submit_ui_request


ROOT = Path(__file__).resolve().parents[2]


class UiControlTest(unittest.TestCase):
    def setUp(self):
        (ROOT / "tmp").mkdir(exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=ROOT / "tmp")
        self.addCleanup(self.temporary.cleanup)
        state = Path(self.temporary.name) / "state"
        self.paths = BuildPaths(ROOT, state)

    def session_record(self, session_id="one", *, state="active", ready=True, pid=123):
        workspace = self.paths.state / "v2/workspaces/gui-default"
        (workspace / "tmp/ui-control/requests").mkdir(parents=True, exist_ok=True)
        (workspace / "tmp/ui-control/responses").mkdir(exist_ok=True)
        (workspace / "workspace.json").write_text(json.dumps({
            "schema": "klibgen.workspace/1", "schemaVersion": 1,
            "name": "gui-default", "sessionId": session_id, "state": state, "pid": pid,
        }))
        if ready:
            (workspace / "tmp/ui-control/ready.json").write_text(json.dumps({
                "schemaVersion": 1, "sessionId": session_id, "ready": True,
            }))
        else:
            (workspace / "tmp/ui-control/ready.json").unlink(missing_ok=True)
        return workspace

    @patch("klibgen_build.ui_control.process_is_alive", return_value=True)
    def test_discovery_filters_stopped_and_reports_readiness(self, _alive):
        self.session_record("live")
        sessions = active_gui_sessions(self.paths)
        self.assertEqual([item["sessionId"] for item in sessions], ["live"])
        self.assertTrue(sessions[0]["ready"]["ready"])

    @patch("klibgen_build.ui_control.process_is_alive", return_value=True)
    def test_selection_requires_unique_ready_run(self, _alive):
        self.session_record("one")
        self.assertEqual(select_gui_session(self.paths)["sessionId"], "one")
        with self.assertRaisesRegex(ValueError, "not active"):
            select_gui_session(self.paths, session_id="two")
        self.session_record("unready", ready=False)
        with self.assertRaisesRegex(ValueError, "not ready"):
            select_gui_session(self.paths, session_id="unready")

    @patch("klibgen_build.ui_control.process_is_alive", return_value=True)
    def test_atomic_submission_matches_response(self, _alive):
        workspace = self.session_record()
        seen = {}

        def server():
            request_dir = workspace / "tmp/ui-control/requests"
            deadline = time.monotonic() + 2
            while time.monotonic() < deadline:
                files = list(request_dir.glob("*.json"))
                if files:
                    request = json.loads(files[0].read_text())
                    seen.update(request)
                    response = {
                        "schemaVersion": 1, "requestId": request["requestId"],
                        "sessionId": "one", "operation": request["operation"],
                        "ok": True, "data": {"value": 42},
                    }
                    target = workspace / "tmp/ui-control/responses" / f"{request['requestId']}.json"
                    target.write_text(json.dumps(response))
                    return
                time.sleep(0.005)

        thread = threading.Thread(target=server)
        thread.start()
        response = submit_ui_request(self.paths, {"operation": "ui.query", "class": "BrButton"})
        thread.join()
        self.assertTrue(response["ok"])
        self.assertEqual(response["data"]["value"], 42)
        self.assertEqual(seen["sessionId"], "one")
        self.assertGreater(seen["deadlineUnixMs"], int(time.time() * 1000))

    @patch("klibgen_build.ui_control.process_is_alive", return_value=True)
    def test_submission_deadline_removes_unclaimed_request(self, _alive):
        workspace = self.session_record()
        with self.assertRaises(TimeoutError):
            submit_ui_request(self.paths, {"operation": "ui.spaces"}, timeout=0.03)
        self.assertEqual(list((workspace / "tmp/ui-control/requests").glob("*.json")), [])

    def test_cli_covers_selectors_actions_wait_batch_and_eval(self):
        runner = CliRunner()
        response = {"schemaVersion": 1, "ok": True, "operation": "ui.act", "data": {}}
        with patch("klibgen_build.cli.ui.submit_ui_request", return_value=response) as submit:
            result = runner.invoke(cli, [
                "ui", "act", "drag", "--node", "node-7", "--dx", "3", "--dy", "4",
                "--text-regex", "Save.*", "--no-visible", "--session", "s1",
            ])
        self.assertEqual(result.exit_code, 0, result.output)
        request = submit.call_args.args[1]
        self.assertEqual((request["dx"], request["dy"]), (3, 4))
        self.assertFalse(request["visible"])
        self.assertEqual(request["textRegex"], "Save.*")
        for arguments in (["ui", "wait", "focused", "--help"], ["ui", "batch", "--help"], ["ui", "eval", "--help"]):
            result = runner.invoke(cli, arguments)
            self.assertEqual(result.exit_code, 0, result.output)


if __name__ == "__main__":
    unittest.main()
