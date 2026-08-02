from __future__ import annotations

import unittest

from klibgen_build.workspaces import _workspace_start_mode


class WorkspaceLifecycleTest(unittest.TestCase):
    def test_new_discarded_and_abnormal_workspaces_start_fresh(self):
        self.assertEqual(_workspace_start_mode(True, {"state": "ready"}), "fresh")
        for state in ("ready", "active"):
            with self.subTest(state=state):
                self.assertEqual(
                    _workspace_start_mode(
                        False,
                        {
                            "state": state,
                            "lastCompletion": {"state": "discarded"},
                        },
                    ),
                    "fresh",
                )
        self.assertEqual(
            _workspace_start_mode(
                False,
                {
                    "state": "ready",
                    "lastCompletion": {"state": "abnormal"},
                },
            ),
            "fresh",
        )

    def test_only_a_saved_workspace_resumes(self):
        self.assertEqual(
            _workspace_start_mode(
                False,
                {
                    "state": "saved",
                    "lastCompletion": {"state": "saved"},
                },
            ),
            "resumed",
        )
        self.assertEqual(
            _workspace_start_mode(
                False,
                {
                    "state": "ready",
                    "lastCompletion": {"state": "saved"},
                },
            ),
            "fresh",
        )


if __name__ == "__main__":
    unittest.main()
