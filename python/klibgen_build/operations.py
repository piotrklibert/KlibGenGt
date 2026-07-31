from __future__ import annotations

import os
import json
import shutil
import time
from pathlib import Path
from typing import Any

from .artifacts import build_l06, set_tree_writable
from .core import BuildPaths
from .runs import create_project_run, write_run_metadata
from .processes import decode_output, run_command, start_command


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


def _seed_gui_documents(run_path: Path) -> None:
    source_home = Path(os.environ.get("HOME", str(Path.home())))
    source = source_home / "Documents/lepiter"
    destination = run_path / "home/Documents/lepiter"
    if source.is_dir() and not destination.exists():
        shutil.copytree(source, destination)


def execute_image_tool(
    paths: BuildPaths, context_id: str, request: dict[str, Any], retain: bool = False
) -> dict[str, Any]:
    context_id = compatibility_context(context_id)
    run = create_project_run(paths, context_id, "cli")
    run_path = Path(run["runPath"])
    _seed_gui_documents(run_path)
    environment = _run_environment(run)
    environment["KLIBGEN_TOOL_REQUEST"] = json.dumps(request, separators=(",", ":"))
    script = paths.root / "build/layers/l06-project-dev/scripts/run-tool.st"
    command = [run["launcher"], str(run_path / "image/GlamorousToolkit.image"), "st", str(script)]
    started = time.perf_counter_ns()
    process = start_command(command, env=environment, capture_output=True)
    write_run_metadata(run_path, state="running", pid=process.pid, command=command, runtimeArguments=command[1:])
    stdout_bytes, stderr_bytes = process.communicate()
    elapsed = time.perf_counter_ns() - started
    stdout = decode_output(stdout_bytes)
    stderr = decode_output(stderr_bytes)
    log = stdout + stderr
    (run_path / "logs/tool.log").write_text(log, encoding="utf-8")
    write_run_metadata(run_path, state="stopped", exitCode=process.returncode, logs=["logs/tool.log"])
    try:
        response = json.loads(stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError(
            f"image tool returned invalid JSON; retained run: {run_path}; "
            f"stdout={stdout[:500]!r}; stderr={stderr[:500]!r}"
        ) from error
    response.update({
        "contextId": context_id,
        "runId": run["runId"],
        "runPath": None,
        "metrics": response.get("metrics", {}) | {"hostWallTimeNs": elapsed},
    })
    if process.returncode != 0 or not response.get("ok", False):
        response["ok"] = False
        response["runPath"] = str(run_path)
        if stderr:
            response.setdefault("error", {})["stderr"] = stderr
    elif not retain:
        shutil.rmtree(run_path)
    else:
        response["runPath"] = str(run_path)
    return response


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
    process = start_command(command, env=environment, capture_output=True)
    write_run_metadata(run_path, state="running", pid=process.pid, command=command, runtimeArguments=command[1:])
    stdout, stderr = process.communicate()
    log = decode_output(stdout) + decode_output(stderr)
    (run_path / "logs" / f"{operation}.log").write_text(log, encoding="utf-8")
    write_run_metadata(run_path, state="stopped", exitCode=process.returncode, logs=[f"logs/{operation}.log"])
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
        set_tree_writable(paths.state, True)
        shutil.rmtree(paths.state)
    return execute(paths, context_id, "test")


def launch_gui(paths: BuildPaths, context_id: str) -> int:
    context_id = compatibility_context(context_id, "gui")
    run = create_project_run(paths, context_id, "gui")
    run_path = Path(run["runPath"])
    _seed_gui_documents(run_path)
    environment = _run_environment(run)
    image = str(run_path / "image/GlamorousToolkit.image")
    prepare_command = [run["launcher"], image, "st", str(paths.root / "build/layers/l06-project-dev/scripts/bind-run.st")]
    preparation = run_command(prepare_command, check=False, env=environment)
    (run_path / "logs/gui-prepare.log").write_text(preparation.stdout + preparation.stderr, encoding="utf-8")
    if preparation.returncode:
        write_run_metadata(
            run_path, state="stopped", exitCode=preparation.returncode,
            prepareCommand=prepare_command, logs=["logs/gui-prepare.log"],
        )
        raise RuntimeError(f"GUI run preparation failed; retained run: {run_path}")
    gui_launcher = str(Path(run["launcher"]).with_name("GlamorousToolkit"))
    if not Path(gui_launcher).is_file():
        raise ValueError(f"GUI launcher is missing: {gui_launcher}")
    command = [gui_launcher, "--image", image]
    process = start_command(command, env=environment)
    write_run_metadata(
        run_path, state="running", pid=process.pid, command=command,
        prepareCommand=prepare_command, runtimeArguments=command[1:],
        logs=["logs/gui-prepare.log"],
    )
    try:
        exit_code = process.wait()
    except KeyboardInterrupt:
        if process.poll() is None:
            process.terminate()
            deadline = time.monotonic() + 5
            while process.poll() is None and time.monotonic() < deadline:
                time.sleep(0.05)
            if process.poll() is None:
                process.kill()
            process.wait()
        exit_code = 130
    write_run_metadata(run_path, state="stopped", exitCode=exit_code)
    return exit_code
