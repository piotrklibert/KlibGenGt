from __future__ import annotations

import json
import tempfile
import unittest
from collections import OrderedDict
from pathlib import Path

from klibgen_build.v3 import (
    CheckpointTaskGroup,
    Executor,
    IntegrationResult,
    PathInput,
    PathOutput,
    RunPython,
    StagingArea,
    StagingAreaManager,
    Task,
    TaskGroup,
    TaskSequence,
    WorkspaceManager,
    Worktree,
)
from klibgen_build.v3.commands import CommandResult
from klibgen_build.v3.workspaces import AGENTIC_CLI, materialize_launch


class Write(Task):
    def __init__(self, name: str, calls: list[str], input_path: str | None = None):
        self.name = name
        self.calls = calls
        self.input_path = input_path

    def inputs(self, context):
        del context
        return () if self.input_path is None else (PathInput(self.input_path),)

    def outputs(self, context):
        del context
        return (PathOutput(f"outputs/{self.name}.txt", "file"),)

    def parameters(self):
        return {"name": self.name}

    def run(self, context):
        self.calls.append(self.name)
        target = context.work / f"outputs/{self.name}.txt"
        target.parent.mkdir(parents=True, exist_ok=True)
        value = (context.repository / self.input_path).read_text() if self.input_path else self.name
        target.write_text(value, encoding="utf-8")


class Build(CheckpointTaskGroup):
    def __init__(self, calls: list[str]):
        super().__init__()
        self.calls = calls

    def steps(self):
        return OrderedDict(
            [
                (
                    "base",
                    CheckpointTaskGroup(
                        OrderedDict(
                            [
                                ("first", Write("first", self.calls)),
                                ("second", Write("second", self.calls)),
                            ]
                        )
                    ),
                ),
                ("tail", Write("tail", self.calls, "input.txt")),
            ]
        )


class FakeRunner:
    def __init__(self):
        self.calls = []

    def run(self, arguments, **kwargs):
        self.calls.append((tuple(map(str, arguments)), kwargs.get("cwd")))
        return CommandResult(0, "", "")


class FakeBackend:
    def __init__(self, area: StagingArea):
        self.area = area
        self.accepted = 0

    def create(self, worktree, name):
        del worktree, name
        return self.area

    def list(self, worktree):
        del worktree
        return (self.area,)

    def reconcile(self, worktree, name):
        del worktree, name
        return self.area

    def changes(self, worktree, name):
        del worktree, name
        return {"prohibited": []}

    def accept_integrated(self, worktree, name):
        del worktree, name
        self.accepted += 1
        return self.area

    def acquire(self, worktree, name, *, kind, owner, pid):
        del worktree, name, kind, owner, pid
        return self.area

    def release(self, worktree, name, *, owner):
        del worktree, name, owner


class FakeSynchronizer:
    def preview(self, source, destination):
        del source, destination
        return (">f++++ file.st",)

    def apply(self, source, destination):
        destination.mkdir(parents=True, exist_ok=True)
        for candidate in source.rglob("*"):
            if candidate.is_file():
                target = destination / candidate.relative_to(source)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(candidate.read_bytes())


class V3BuildTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "repo"
        self.root.mkdir()
        (self.root / "input.txt").write_text("one", encoding="utf-8")
        self.worktree = Worktree("default", self.root, self.root)
        self.workspace = WorkspaceManager(self.worktree).create("default")

    def test_task_sequence_composition(self):
        calls = []
        sequence = TaskSequence([("a", Write("a", calls)), ("b", Write("b", calls))])
        changed = sequence.replace("b", Write("replacement", calls)).insert_after(
            "a", "middle", Write("middle", calls)
        )
        self.assertEqual([name for name, _ in changed], ["a", "middle", "b"])
        self.assertEqual([name for name, _ in changed.through("middle")], ["a", "middle"])

    def test_executor_reuses_and_restores_checkpoint(self):
        calls = []
        executor = Executor()
        first = executor.execute(Build(calls), self.workspace, root_name="klibGenGt")
        self.assertFalse(first.reused)
        self.assertEqual(calls, ["first", "second", "tail"])

        calls.clear()
        second = executor.execute(Build(calls), self.workspace, root_name="klibGenGt")
        self.assertTrue(second.reused)
        self.assertEqual(calls, [])

        calls.clear()
        (self.root / "input.txt").write_text("two", encoding="utf-8")
        third = executor.execute(Build(calls), self.workspace, root_name="klibGenGt")
        self.assertEqual(third.restored_checkpoint, "klibGenGt:base")
        self.assertEqual(calls, ["tail"])
        self.assertEqual((third.generation / "payload/outputs/tail.txt").read_text(), "two")

    def test_raw_python_and_writable_launch(self):
        task = TaskGroup(
            [("write", RunPython(
                lambda _executor, workspace: (workspace.work / "value.txt").write_text("ok"),
                outputs=(PathOutput("value.txt", "file"),),
                implementation_key="write-v1",
            ))]
        )
        Executor().execute(task, self.workspace)
        launch = materialize_launch(self.workspace, AGENTIC_CLI)
        self.assertEqual((launch / "value.txt").read_text(), "ok")
        self.assertNotEqual(launch, self.workspace.current_generation() / "payload")

    def test_staging_integration_uses_private_area_and_explicit_copy(self):
        area_root = self.root / ".klibgen/v2/staging/agent/overlay"
        source_root = area_root / "src/KlibGenGt-Core"
        source_root.mkdir(parents=True)
        (area_root / ".git").mkdir()
        (source_root / "Agent.class.st").write_text("agent", encoding="utf-8")
        area = StagingArea("agent", area_root.parent, area_root / ".git")
        backend = FakeBackend(area)
        manager = StagingAreaManager(
            self.worktree, backend=backend, synchronizer=FakeSynchronizer()
        )

        preview = manager.integrate("agent", dry_run=True)
        self.assertIsInstance(preview, IntegrationResult)
        self.assertFalse(preview.applied)
        result = manager.integrate("agent")
        self.assertTrue(result.applied)
        self.assertEqual((self.root / "src/KlibGenGt-Core/Agent.class.st").read_text(), "agent")
        self.assertEqual(backend.accepted, 1)


if __name__ == "__main__":
    unittest.main()
