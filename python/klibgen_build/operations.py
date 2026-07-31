from __future__ import annotations

import os
import json
import hashlib
import shutil
import sys
import time
from pathlib import Path
from typing import Any

from .artifacts import build_l06, set_tree_writable, sha256_file
from .core import BuildPaths
from .runs import create_project_run, write_run_metadata
from .lifecycle import current_snapshot_id, resume_snapshot, snapshot_run
from .sources import host_facts
from .processes import decode_output, run_command, start_command


def compatibility_context(context_id: str, profile: str = "cli") -> str:
    runtime = os.environ.get("GT_RUNTIME")
    if runtime == "build-clean" and context_id == "default":
        return "source-clean"
    if runtime == "build-patched" and context_id in {"default", "gui"}:
        return "patched-gui" if profile == "gui" else "patched"
    return context_id


PASSTHROUGH_ENVIRONMENT = {
    "PATH", "LANG", "LANGUAGE", "LC_ALL", "LC_CTYPE", "DISPLAY", "WAYLAND_DISPLAY",
    "DBUS_SESSION_BUS_ADDRESS", "XDG_RUNTIME_DIR", "XAUTHORITY", "SESSION_MANAGER", "SSH_AUTH_SOCK", "HTTP_PROXY", "HTTPS_PROXY",
    "NO_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "no_proxy", "all_proxy",
    "GDK_BACKEND", "GTK_THEME", "LIBGL_ALWAYS_SOFTWARE", "MESA_LOADER_DRIVER_OVERRIDE",
    "WGPU_BACKEND", "WGPU_POWER_PREF", "VK_ICD_FILENAMES",
}


def _run_environment(run: dict[str, Any], start_mode: str | None = None) -> dict[str, str]:
    path = Path(run["runPath"])
    environment = (
        os.environ.copy()
        if start_mode is None
        else {name: value for name, value in os.environ.items() if name in PASSTHROUGH_ENVIRONMENT}
    )
    environment.update({
        "HOME": str(path / "home"), "XDG_CONFIG_HOME": str(path / "config"),
        "XDG_DATA_HOME": str(path / "data"), "XDG_CACHE_HOME": str(path / "cache"),
        "TMPDIR": str(path / "tmp"), "KLIBGEN_EXPORT_GIT": str(path / "export/.git"),
        "KLIBGEN_GUI_EVENT_PATH": str(path / "logs/gui-events.jsonl"),
        "KLIBGEN_RUN_ID": run["runId"],
    })
    if start_mode is not None:
        environment["KLIBGEN_GUI_START_MODE"] = start_mode
    return environment


def _environment_record(environment: dict[str, str]) -> dict[str, Any]:
    sensitive = {name for name in environment if "PROXY" in name.upper() or name == "SSH_AUTH_SOCK"}
    return {
        "allowlist": sorted(PASSTHROUGH_ENVIRONMENT),
        "effective": {
            name: ({"sha256": hashlib.sha256(value.encode()).hexdigest(), "redacted": True} if name in sensitive else value)
            for name, value in sorted(environment.items())
        },
    }


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


def _gui_save_evidence(run_path: Path, before_hash: str, changes_offset: int) -> dict[str, Any]:
    image = run_path / "image/GlamorousToolkit.image"
    changes = run_path / "image/GlamorousToolkit.changes"
    changed_hash = sha256_file(image)
    appended = b""
    if changes.is_file():
        with changes.open("rb") as stream:
            stream.seek(min(changes_offset, changes.stat().st_size))
            appended = stream.read()
    text = appended.decode("utf-8", errors="replace")
    journal = run_path / "logs/gui-events.jsonl"
    journal_text = journal.read_text(encoding="utf-8", errors="replace") if journal.is_file() else ""
    snapshot_records = text.count("----SNAPSHOT----")
    quit_without_save_records = text.count("----QUIT/NOSAVE----")
    quit_records = text.count("----QUIT----")
    saved_events = sum(1 for line in journal_text.splitlines() if '"event":"saved"' in line.replace(" ", ""))
    return {
        "initialImageSha256": before_hash,
        "finalImageSha256": changed_hash,
        "imageChanged": changed_hash != before_hash,
        "changesInitialOffset": changes_offset,
        "changesFinalOffset": changes.stat().st_size if changes.is_file() else 0,
        "snapshotRecordCount": snapshot_records,
        "quitRecordCount": quit_records,
        "quitWithoutSaveRecordCount": quit_without_save_records,
        "savedEventCount": saved_events,
        "successfulSave": changed_hash != before_hash and (snapshot_records > 0 or quit_records > 0 or saved_events > 0),
    }


def launch_gui(
    paths: BuildPaths, context_id: str, *, fresh: bool = False,
    snapshot_id: str | None = None, advance_current: bool = True,
) -> int:
    context_id = compatibility_context(context_id, "gui")
    selected_snapshot = snapshot_id if snapshot_id is not None else (None if fresh else current_snapshot_id(paths, context_id))
    if selected_snapshot is None:
        run = create_project_run(paths, context_id, "gui")
        start_mode = "fresh"
    else:
        run = resume_snapshot(paths, selected_snapshot)
        start_mode = "resumed"
        divergence = run.get("sourceDivergence", {})
        if divergence.get("diverged"):
            print(
                f"warning: resuming saved GUI source unchanged despite {', '.join(divergence['reasons'])}",
                file=sys.stderr,
            )
    run_path = Path(run["runPath"])
    if start_mode == "fresh":
        _seed_gui_documents(run_path)
    environment = _run_environment(run, start_mode)
    image = str(run_path / "image/GlamorousToolkit.image")
    prepare_command = None
    logs = []
    if start_mode == "fresh":
        prepare_command = [run["launcher"], image, "st", str(paths.root / "build/layers/l06-project-dev/scripts/bind-run.st")]
        preparation = run_command(prepare_command, check=False, env=environment)
        (run_path / "logs/gui-prepare.log").write_text(preparation.stdout + preparation.stderr, encoding="utf-8")
        logs.append("logs/gui-prepare.log")
        if preparation.returncode:
            write_run_metadata(run_path, state="stopped", exitCode=preparation.returncode, prepareCommand=prepare_command, logs=logs)
            raise RuntimeError(f"GUI run preparation failed; retained run: {run_path}")
    gui_launcher = str(Path(run["launcher"]).with_name("GlamorousToolkit"))
    if not Path(gui_launcher).is_file():
        raise ValueError(f"GUI launcher is missing: {gui_launcher}")
    command = [gui_launcher, "--image", image]
    image_hash = sha256_file(Path(image))
    changes = run_path / "image/GlamorousToolkit.changes"
    changes_offset = changes.stat().st_size if changes.is_file() else 0
    process = start_command(command, env=environment)
    write_run_metadata(
        run_path, state="running", pid=process.pid, command=command,
        prepareCommand=prepare_command, runtimeArguments=command[1:],
        guiStartMode=start_mode, selectedSnapshotId=selected_snapshot,
        imageSha256AtLaunch=image_hash, changesOffsetAtLaunch=changes_offset,
        environment=_environment_record(environment), host=host_facts(), logs=logs,
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
    evidence = _gui_save_evidence(run_path, image_hash, changes_offset)
    write_run_metadata(run_path, state="stopped", exitCode=exit_code, saveEvidence=evidence)
    if evidence["successfulSave"]:
        try:
            snapshot_run(
                paths, run["runId"], make_current=advance_current,
                remove_source=True, save_evidence=evidence,
            )
        except Exception as error:
            raise RuntimeError(f"saved GUI session could not be published; retained run: {run_path}: {error}") from error
    return exit_code
