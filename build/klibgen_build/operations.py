from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path
from typing import Any

from .artifacts import build_l06
from .core import BuildPaths
from .runs import create_project_run


def compatibility_context(context_id: str, profile: str = "cli") -> str:
    runtime = os.environ.get("GT_RUNTIME")
    if runtime == "build-clean" and context_id == "default":
        return "source-clean"
    if runtime == "build-patched" and context_id in {"default", "gui"}:
        return "patched-gui" if profile == "gui" else "patched"
    return context_id


def _run_environment(run: dict[str, Any]) -> dict[str, str]:
    path = Path(run["runPath"])
    environment = os.environ.copy()
    environment.update({
        "HOME": str(path / "home"), "XDG_CONFIG_HOME": str(path / "config"),
        "XDG_CACHE_HOME": str(path / "cache"), "KLIBGEN_EXPORT_GIT": str(path / "export/.git"),
    })
    return environment


def execute(paths: BuildPaths, context_id: str, operation: str, expression: str | None = None,
            retain: bool = False) -> dict[str, Any]:
    context_id = compatibility_context(context_id)
    run = create_project_run(paths, context_id, "cli")
    run_path = Path(run["runPath"])
    scripts = {
        "test": "contract.st",
        "smoke": "smoke.st",
        "check-type-pragmas": "check-type-pragmas.st",
        "eval": "eval.st",
    }
    script = paths.root / "build/layers/l06-project-dev/tests" / scripts[operation]
    environment = _run_environment(run)
    if expression is not None:
        environment["GT_EVAL"] = expression
    command = [run["launcher"], str(run_path / "image/GlamorousToolkit.image"), "st", str(script)]
    process = subprocess.run(command, env=environment, capture_output=True, text=True)
    log = process.stdout + process.stderr
    (run_path / "logs" / f"{operation}.log").write_text(log, encoding="utf-8")
    result = {"schemaVersion": 1, "operation": operation, "contextId": context_id, "runId": run["runId"], "runPath": str(run_path), "exitCode": process.returncode, "output": log}
    if process.returncode == 0 and not retain:
        shutil.rmtree(run_path)
        result["runPath"] = None
    return result


def fresh_test(paths: BuildPaths, context_id: str) -> dict[str, Any]:
    allowed = (paths.root / "artifacts").resolve()
    if allowed not in paths.state.parents:
        raise ValueError("fresh testing requires KLIBGEN_STATE_ROOT below artifacts/")
    if paths.state.exists():
        shutil.rmtree(paths.state)
    return execute(paths, context_id, "test")


def launch_gui(paths: BuildPaths, context_id: str) -> int:
    context_id = compatibility_context(context_id, "gui")
    run = create_project_run(paths, context_id, "gui")
    run_path = Path(run["runPath"])
    environment = _run_environment(run)
    command = [run["launcher"], "--interactive", str(run_path / "image/GlamorousToolkit.image"), "st", str(paths.root / "build/layers/l06-project-dev/scripts/bind-run.st")]
    process = subprocess.Popen(command, env=environment)
    metadata_path = run_path / "run.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    metadata.update({"state": "running", "pid": process.pid, "command": command})
    metadata_path.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    try:
        exit_code = process.wait()
    except KeyboardInterrupt:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        exit_code = 130
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    metadata.update({"state": "stopped", "exitCode": exit_code})
    metadata_path.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return exit_code
