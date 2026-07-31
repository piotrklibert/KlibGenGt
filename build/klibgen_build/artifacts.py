from __future__ import annotations

import hashlib
import fcntl
import json
import os
import shutil
import subprocess
import uuid
import zipfile
from pathlib import Path
from typing import Any
from contextlib import contextmanager

from .core import BuildPaths, canonical_json, digest_json, load_context, load_layers, platform_id, read_json


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def implementation_digest(paths: BuildPaths) -> str:
    files = sorted((paths.root / "build" / "klibgen_build").glob("*.py"))
    files += sorted((paths.root / "build" / "layers").glob("l*/layer.json"))
    files += sorted((paths.root / "build" / "layers").glob("l*/tests/*"))
    files += sorted((paths.root / "scripts").glob("patch-gt-*"))
    value = [{"path": str(path.relative_to(paths.root)), "sha256": sha256_file(path)} for path in files]
    return digest_json(value)


def layer_key(paths: BuildPaths, context: dict[str, Any], definition: dict[str, Any], parent_key: str | None) -> str:
    lock = read_json(paths.root / "build" / "locks" / "default.lock.json")
    return digest_json({
        "schemaVersion": 1,
        "layer": definition,
        "selection": context["layers"].get(definition["layerId"], {}),
        "parentBuildKey": parent_key,
        "lock": lock,
        "platform": platform_id(),
        "implementation": implementation_digest(paths),
    })


def graph(paths: BuildPaths, context_id: str) -> list[dict[str, Any]]:
    context = load_context(paths, context_id)
    result = []
    parent_key = None
    for definition in load_layers(paths):
        key = layer_key(paths, context, definition, parent_key)
        artifact = paths.state / "artifacts" / platform_id() / context_id / definition["layerId"].lower() / key
        result.append({"definition": definition, "buildKey": key, "artifact": artifact, "parentKey": parent_key})
        parent_key = key
    return result


def runtime_source(paths: BuildPaths, context: dict[str, Any]) -> Path:
    variant = context["layers"]["L01"]["variant"]
    if variant == "downloaded":
        subprocess.run([str(paths.root / "scripts" / "bootstrap-gt.sh")], check=True)
        return paths.root / "vendor" / "gt"
    if variant == "local-build":
        subprocess.run([str(paths.root / "scripts" / "bootstrap-gt-source.sh"), "clean"], check=True)
        return paths.root / "vendor" / "gt-build" / "workspaces" / "clean"
    raise ValueError(f"unsupported L01 variant {variant!r}")


def copy_reflink(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["cp", "-a", "--reflink=auto", str(source), str(destination)], check=True)


@contextmanager
def artifact_lock(paths: BuildPaths, context_id: str, layer_id: str, key: str):
    lock_path = paths.state / "state" / "locks" / context_id / layer_id.lower() / f"{key}.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("w") as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        yield


def set_tree_writable(root: Path, writable: bool) -> None:
    for path in [root, *root.rglob("*")]:
        mode = path.stat().st_mode
        if writable:
            path.chmod(mode | 0o200)
        else:
            path.chmod(mode & ~0o222)


def materialize_clean_image(paths: BuildPaths, context: dict[str, Any], runtime: Path, destination: Path) -> None:
    destination.mkdir(parents=True)
    if context["layers"]["L02"]["variant"] == "release":
        archive = paths.root / "vendor" / "gt.zip"
        with zipfile.ZipFile(archive) as source:
            members = [name for name in source.namelist() if not name.endswith("/")]
            wanted = [name for name in members if Path(name).name in {"GlamorousToolkit.image", "GlamorousToolkit.changes"} or name.endswith(".sources")]
            for name in wanted:
                target = destination / Path(name).name
                with source.open(name) as input_stream, target.open("wb") as output_stream:
                    shutil.copyfileobj(input_stream, output_stream, length=1024 * 1024)
        if not (destination / "GlamorousToolkit.image").is_file():
            raise ValueError(f"verified GT archive has no image: {archive}")
        return
    copy_reflink(runtime / "GlamorousToolkit.image", destination / "GlamorousToolkit.image")
    copy_reflink(runtime / "GlamorousToolkit.changes", destination / "GlamorousToolkit.changes")
    sources = next(runtime.glob("*.sources"))
    copy_reflink(sources, destination / sources.name)


def _manifest(layer: dict[str, Any], context_id: str, key: str, parent: dict[str, Any] | None,
              inputs: list[dict[str, Any]], outputs: list[dict[str, Any]], tests: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "layerId": layer["layerId"],
        "layerName": layer["name"],
        "contextId": context_id,
        "buildKey": key,
        "status": "success",
        "parents": [] if parent is None else [{"layerId": parent["definition"]["layerId"], "buildKey": parent["buildKey"]}],
        "variant": layer.get("variants", layer.get("profiles", [])),
        "platform": platform_id(),
        "inputs": inputs,
        "outputs": outputs,
        "tests": tests,
        "dirty": False,
        "hostBound": False,
        "overrides": [],
    }


def _publish(attempt: Path, artifact: Path, manifest: dict[str, Any]) -> Path:
    (attempt / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    artifact.parent.mkdir(parents=True, exist_ok=True)
    if artifact.exists():
        shutil.rmtree(attempt)
        return artifact
    os.replace(attempt, artifact)
    set_tree_writable(artifact, False)
    return artifact


def build_base(paths: BuildPaths, context_id: str, target: str, force: bool = False) -> Path:
    normalized = target.upper() if target.upper().startswith("L") else target.upper().replace("L", "L")
    if normalized in {"L1", "L01"}:
        target_id = "L01"
    elif normalized in {"L2", "L02"}:
        target_id = "L02"
    else:
        raise ValueError("Step 004 supports only l01 and l02")
    context = load_context(paths, context_id)
    nodes = graph(paths, context_id)
    selected = nodes[: 1 if target_id == "L01" else 2]
    runtime = runtime_source(paths, context)
    built: Path | None = None
    for index, node in enumerate(selected):
        artifact = node["artifact"]
        if (artifact / "manifest.json").is_file() and not force:
            built = artifact
            continue
        with artifact_lock(paths, context_id, node["definition"]["layerId"], node["buildKey"]):
            if (artifact / "manifest.json").is_file() and not force:
                built = artifact
                continue
            attempt_id = str(uuid.uuid4())
            attempt = paths.state / "tmp" / f"attempt-{attempt_id}"
            attempt.mkdir(parents=True)
            if node["definition"]["layerId"] == "L01":
                copy_reflink(runtime / "bin", attempt / "runtime" / "bin")
                copy_reflink(runtime / "lib", attempt / "runtime" / "lib")
                outputs = []
                for relative in ("runtime/bin/GlamorousToolkit", "runtime/bin/GlamorousToolkit-cli"):
                    path = attempt / relative
                    outputs.append({"path": relative, "sha256": sha256_file(path), "executable": os.access(path, os.X_OK)})
                tests = [{"name": "launchers-present", "status": "passed"}]
            else:
                materialize_clean_image(paths, context, runtime, attempt / "image")
                home = attempt / "test-home"
                home.mkdir()
                (home / "config").mkdir()
                (home / "cache").mkdir()
                contract = paths.root / "build" / "layers" / "l02-gt-base" / "tests" / "contract.st"
                command = [str(selected[0]["artifact"] / "runtime/bin/GlamorousToolkit-cli"), str(attempt / "image/GlamorousToolkit.image"), "st", str(contract)]
                environment = os.environ.copy()
                environment.update({"HOME": str(home), "XDG_CONFIG_HOME": str(home / "config"), "XDG_CACHE_HOME": str(home / "cache")})
                process = subprocess.run(command, env=environment, capture_output=True, text=True)
                (attempt / "contract.log").write_text(process.stdout + process.stderr, encoding="utf-8")
                if process.returncode:
                    raise RuntimeError(f"L02 contract failed; retained attempt: {attempt}")
                shutil.rmtree(home)
                outputs = [{"path": "image/GlamorousToolkit.image", "sha256": sha256_file(attempt / "image/GlamorousToolkit.image")}]
                tests = [{"name": "l02-contract", "status": "passed", "log": "contract.log"}]
            parent = selected[index - 1] if index else None
            manifest = _manifest(node["definition"], context_id, node["buildKey"], parent,
                                 [{"runtimeSource": str(runtime), "selection": context["layers"][node["definition"]["layerId"]]}], outputs, tests)
            if force and artifact.exists():
                rebuild = paths.state / "logs" / "rebuilds" / context_id / node["definition"]["layerId"].lower() / node["buildKey"] / attempt_id
                rebuild.parent.mkdir(parents=True, exist_ok=True)
                (attempt / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
                os.replace(attempt, rebuild)
                built = artifact
            else:
                built = _publish(attempt, artifact, manifest)
    assert built is not None
    return built


def git_worktree_state(path: Path) -> dict[str, Any]:
    commit = subprocess.run(["git", "-C", str(path), "rev-parse", "HEAD"], check=True, capture_output=True, text=True).stdout.strip()
    status = subprocess.run(["git", "-C", str(path), "status", "--porcelain"], check=True, capture_output=True, text=True).stdout.splitlines()
    return {"vcs": "git", "worktree": str(path), "commit": commit, "dirty": bool(status), "changedPaths": status}


def build_l03(paths: BuildPaths, context_id: str, force: bool = False) -> Path:
    parent_artifact = build_base(paths, context_id, "l02", force=False)
    context = load_context(paths, context_id)
    node = graph(paths, context_id)[2]
    artifact = node["artifact"]
    if (artifact / "manifest.json").is_file() and not force:
        return artifact
    with artifact_lock(paths, context_id, "L03", node["buildKey"]):
        if (artifact / "manifest.json").is_file() and not force:
            return artifact
        attempt_id = str(uuid.uuid4())
        attempt = paths.state / "tmp" / f"attempt-{attempt_id}"
        attempt.mkdir(parents=True)
        copy_reflink(parent_artifact / "image", attempt / "image")
        set_tree_writable(attempt, True)
        selection = context["layers"]["L03"]
        variant = selection["variant"]
        sources: list[dict[str, Any]] = []
        if "worktree" in selection:
            worktree = (paths.root / selection["worktree"]).resolve()
            sources.append(git_worktree_state(worktree))
        runtime_artifact = graph(paths, context_id)[0]["artifact"]
        launcher = runtime_artifact / "runtime/bin/GlamorousToolkit-cli"
        home = attempt / "test-home"
        for name in ("", "config", "cache"):
            (home / name).mkdir(parents=True, exist_ok=True)
        environment = os.environ.copy()
        environment.update({"HOME": str(home), "XDG_CONFIG_HOME": str(home / "config"), "XDG_CACHE_HOME": str(home / "cache")})
        if variant == "klibgen":
            patch = paths.root / "scripts" / "patch-gt-headless-webview.st"
            process = subprocess.run([str(launcher), str(attempt / "image/GlamorousToolkit.image"), "st", str(patch)], env=environment, capture_output=True, text=True)
            (attempt / "patch.log").write_text(process.stdout + process.stderr, encoding="utf-8")
            if process.returncode:
                raise RuntimeError(f"L03 patch failed; retained attempt: {attempt}")
        contract = paths.root / "build/layers/l03-gt-patched/tests/contract.st"
        environment["KLIBGEN_EXPECT_GT_PATCH"] = "true" if variant == "klibgen" else "false"
        process = subprocess.run([str(launcher), str(attempt / "image/GlamorousToolkit.image"), "st", str(contract)], env=environment, capture_output=True, text=True)
        (attempt / "contract.log").write_text(process.stdout + process.stderr, encoding="utf-8")
        if process.returncode:
            raise RuntimeError(f"L03 contract failed; retained attempt: {attempt}")
        shutil.rmtree(home)
        output = {"path": "image/GlamorousToolkit.image", "sha256": sha256_file(attempt / "image/GlamorousToolkit.image")}
        parent_node = graph(paths, context_id)[1]
        manifest = _manifest(node["definition"], context_id, node["buildKey"], parent_node,
                             [{"selection": selection, "sources": sources, "patch": "scripts/patch-gt-headless-webview.st"}], [output],
                             [{"name": "l03-contract", "status": "passed", "log": "contract.log"}])
        manifest["dirty"] = any(source["dirty"] for source in sources)
        manifest["changedPackages"] = ["GToolkit-WebView"] if variant == "klibgen" else []
        if force and artifact.exists():
            retained = paths.state / "logs/rebuilds" / context_id / "l03" / node["buildKey"] / attempt_id
            retained.parent.mkdir(parents=True, exist_ok=True)
            (attempt / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            os.replace(attempt, retained)
            return artifact
        return _publish(attempt, artifact, manifest)


def build_artifact(paths: BuildPaths, context_id: str, target: str, force: bool = False) -> Path:
    target_id = target.lower().split("-")[0]
    if target_id in {"l1", "l01", "l2", "l02"}:
        return build_base(paths, context_id, target_id, force=force)
    if target_id in {"l3", "l03"}:
        return build_l03(paths, context_id, force=force)
    raise ValueError("implemented build targets are l01, l02, and l03")
