from __future__ import annotations

import json
from collections import OrderedDict

from .model import (
    CheckpointTaskGroup,
    ExecutionContext,
    PathInput,
    PathOutput,
    RunInImage,
    RunInImageTest,
    RunPython,
    Task,
    TaskGroup,
)
from .staging import StagingAreaManager


class ReadConfig(Task):
    """Package the existing source-lock file as durable workspace metadata."""

    def inputs(self, context: ExecutionContext):
        del context
        return (PathInput("build/locks/default.lock.json"),)

    def outputs(self, context: ExecutionContext):
        del context
        return (PathOutput("metadata/config.json", "file"),)

    def run(self, context: ExecutionContext) -> None:
        source = context.repository / "build/locks/default.lock.json"
        value = json.loads(source.read_text(encoding="utf-8"))
        target = context.work / "metadata/config.json"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


class FetchPinnedGT(Task):
    """Reuse the current bootstrap script and shared acquisition cache."""

    def inputs(self, context: ExecutionContext):
        del context
        return (PathInput("scripts/bootstrap-gt.sh"), PathInput("build/locks/default.lock.json"))

    def outputs(self, context: ExecutionContext):
        del context
        return (PathOutput("runtime", "directory"),)

    def run(self, context: ExecutionContext) -> None:
        environment = {"KLIBGEN_VENDOR_ROOT": str(context.workspace.worktree.shared_root / "vendor")}
        context.executor.runner.run(
            [context.repository / "scripts/bootstrap-gt.sh"],
            cwd=context.repository,
            env=__import__("os").environ | environment,
        )
        runtime = context.workspace.worktree.shared_root / "vendor/gt"
        target = context.work / "runtime"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.symlink_to(runtime, target_is_directory=True)


class FetchPinnedDependencies(Task):
    """Acquire locked Git dependencies into the repository-shared source cache."""

    def inputs(self, context: ExecutionContext):
        del context
        return (PathInput("build/locks/default.lock.json"),)

    def outputs(self, context: ExecutionContext):
        del context
        return (PathOutput("metadata/dependencies.json", "file"),)

    def run(self, context: ExecutionContext) -> None:
        lock = json.loads((context.work / "metadata/config.json").read_text(encoding="utf-8"))
        source_root = context.workspace.worktree.shared_root / "sources"
        records = []
        for source in lock.get("sources", []):
            if source.get("sourceType") != "git":
                continue
            source_id = source["sourceId"]
            commit = source["resolved"]["commit"]
            checkout = source_root / source_id
            if not checkout.exists():
                context.executor.runner.run(["git", "clone", "--no-checkout", source["source"], checkout])
            context.executor.runner.run(["git", "-C", checkout, "fetch", "origin", commit])
            context.executor.runner.run(["git", "-C", checkout, "checkout", "--detach", commit])
            records.append({"id": source_id, "commit": commit, "path": str(checkout)})
        target = context.work / "metadata/dependencies.json"
        target.write_text(json.dumps(records, indent=2, sort_keys=True) + "\n", encoding="utf-8")


class ExtractInitialImage(Task):
    """Wrap the v0.2 clean-image extractor during migration."""

    def outputs(self, context: ExecutionContext):
        del context
        return (PathOutput("image/GlamorousToolkit.image", "file"),)

    def run(self, context: ExecutionContext) -> None:
        from klibgen_build.canonical import _extract_clean_image
        from klibgen_build.core import BuildPaths

        paths = BuildPaths(context.repository, context.repository / ".klibgen")
        image = context.work / "image"
        image.mkdir(parents=True, exist_ok=True)
        _extract_clean_image(paths, image)


class PrepareStagingArea(Task):
    def __init__(self, name: str):
        self.name = name

    def parameters(self):
        return {"name": self.name}

    def outputs(self, context: ExecutionContext):
        del context
        return (PathOutput("metadata/source-area.json", "file"),)

    def run(self, context: ExecutionContext) -> None:
        area = StagingAreaManager(context.workspace.worktree).ensure(self.name)
        target = context.work / "metadata/source-area.json"
        target.write_text(
            json.dumps({"name": area.name, "sourceGit": str(area.source_git)}, indent=2) + "\n",
            encoding="utf-8",
        )


class InstallDependencies(CheckpointTaskGroup):
    def steps(self):
        return OrderedDict(
            [
                ("load", RunInImage(script="build/v2/scripts/load-project-dependencies.st")),
                (
                    "verifySqlite",
                    RunInImageTest(script="build/v2/tests/project-dependencies-contract.st"),
                ),
            ]
        )


class KlibGenGt(CheckpointTaskGroup):
    """Mixed raw/domain recipe used to migrate v0.2 one task at a time."""

    def __init__(self, source_area: str = "default"):
        super().__init__()
        self.source_area = source_area

    def parameters(self):
        return {"sourceArea": self.source_area}

    def steps(self):
        return OrderedDict(
            [
                ("readConfig", ReadConfig()),
                ("obtainRuntime", FetchPinnedGT()),
                ("fetchDependencies", FetchPinnedDependencies()),
                ("extractInitialImage", ExtractInitialImage()),
                ("patchGT", RunInImage(script="scripts/patch-gt-headless-webview.st")),
                ("installDeps", InstallDependencies()),
                ("prepareSourceArea", PrepareStagingArea(self.source_area)),
                (
                    "sampleStep",
                    RunPython(
                        lambda _executor, workspace: (workspace.work / "metadata/sample.txt").write_text("sample\n"),
                        outputs=(PathOutput("metadata/sample.txt", "file"),),
                        implementation_key="sample-step-v1",
                    ),
                ),
                (
                    "remainingV02Scripts",
                    TaskGroup(
                        OrderedDict(
                            [
                                ("loadProject", RunInImage(script="build/v2/scripts/load-project-source.st")),
                                ("provenance", RunInImage(script="build/v2/scripts/install-provenance.st")),
                                ("contract", RunInImageTest(script="build/v2/tests/project-contract.st")),
                            ]
                        )
                    ),
                ),
            ]
        )
