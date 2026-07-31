from __future__ import annotations

import hashlib
import fcntl
import json
import os
import shutil
import subprocess
import uuid
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from contextlib import contextmanager

from .core import BuildPaths, canonical_json, digest_json, load_context, load_layers, platform_id, read_json
from .sources import jj_identity
from .bridge import materialize_jj_source


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
    source_state = None
    if definition["layerId"] == "L04":
        override = context["layers"].get("L04", {}).get("dependencyOverrides", {}).get("sqlite3")
        if override:
            source_state = git_worktree_state((paths.root / override["worktree"]).resolve())
    if definition["layerId"] in {"L06", "L07"}:
        source_state = jj_identity(paths, context["project"]["revision"])
    return digest_json({
        "schemaVersion": 1,
        "layer": definition,
        "selection": context["layers"].get(definition["layerId"], {}),
        "parentBuildKey": parent_key,
        "lock": lock,
        "platform": platform_id(),
        "implementation": implementation_digest(paths),
        "sourceState": source_state,
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
        "createdAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
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
    if target_id in {"l4", "l04"}:
        return build_l04(paths, context_id, force=force)
    if target_id in {"l5", "l05"}:
        return build_l05(paths, context_id, force=force)
    if target_id in {"l6", "l06"}:
        return build_l06(paths, context_id, force=force)
    if target_id in {"l7", "l07"}:
        return build_l07(paths, context_id, force=force)
    raise ValueError("implemented build targets are l01 through l07")


def build_l04(paths: BuildPaths, context_id: str, force: bool = False) -> Path:
    parent_artifact = build_l03(paths, context_id)
    context = load_context(paths, context_id)
    nodes = graph(paths, context_id)
    node = nodes[3]
    artifact = node["artifact"]
    if (artifact / "manifest.json").is_file() and not force:
        return artifact
    with artifact_lock(paths, context_id, "L04", node["buildKey"]):
        if (artifact / "manifest.json").is_file() and not force:
            return artifact
        attempt_id = str(uuid.uuid4())
        attempt = paths.state / "tmp" / f"attempt-{attempt_id}"
        attempt.mkdir(parents=True)
        copy_reflink(parent_artifact / "image", attempt / "image")
        set_tree_writable(attempt, True)
        selection = context["layers"]["L04"]
        lock = read_json(paths.root / "build/locks/default.lock.json")
        sqlite = next(source for source in lock["sources"] if source["sourceId"] == "sqlite3")
        override = selection.get("dependencyOverrides", {}).get("sqlite3")
        source_state = None
        if override:
            worktree = (paths.root / override["worktree"]).resolve()
            source_state = git_worktree_state(worktree)
            repository = f"gitlocal://{worktree / '.git'}:{source_state['commit']}/src"
        else:
            repository = f"github://pharo-rdbms/Pharo-SQLite3:{sqlite['resolved']['commit']}/src"
        runtime_artifact = nodes[0]["artifact"]
        launcher = runtime_artifact / "runtime/bin/GlamorousToolkit-cli"
        home = attempt / "test-home"
        for name in ("", "config", "cache"):
            (home / name).mkdir(parents=True, exist_ok=True)
        environment = os.environ.copy()
        environment.update({"HOME": str(home), "XDG_CONFIG_HOME": str(home / "config"), "XDG_CACHE_HOME": str(home / "cache"), "KLIBGEN_SQLITE_REPOSITORY": repository})
        loader = paths.root / "build/layers/l04-project-deps/scripts/load.st"
        process = subprocess.run([str(launcher), str(attempt / "image/GlamorousToolkit.image"), "st", str(loader)], env=environment, capture_output=True, text=True)
        (attempt / "load.log").write_text(process.stdout + process.stderr, encoding="utf-8")
        if process.returncode:
            raise RuntimeError(f"L04 dependency load failed; retained attempt: {attempt}")
        contract = paths.root / "build/layers/l04-project-deps/tests/contract.st"
        process = subprocess.run([str(launcher), str(attempt / "image/GlamorousToolkit.image"), "st", str(contract)], env=environment, capture_output=True, text=True)
        (attempt / "contract.log").write_text(process.stdout + process.stderr, encoding="utf-8")
        if process.returncode:
            raise RuntimeError(f"L04 contract failed; retained attempt: {attempt}")
        shutil.rmtree(home)
        output = {"path": "image/GlamorousToolkit.image", "sha256": sha256_file(attempt / "image/GlamorousToolkit.image")}
        manifest = _manifest(node["definition"], context_id, node["buildKey"], nodes[2],
                             [{"dependencyId": "sqlite3", "repository": repository, "lock": sqlite, "overrideState": source_state, "loadOrder": 1}],
                             [output], [{"name": "sqlite3-load", "status": "passed", "log": "load.log"}, {"name": "l04-contract", "status": "passed", "log": "contract.log"}])
        manifest["packageMappings"] = [{"packages": ["SQLite3-Core", "SQLite3-Pharo9", "SQLite3-Pharo10"], "repository": repository}]
        if force and artifact.exists():
            retained = paths.state / "logs/rebuilds" / context_id / "l04" / node["buildKey"] / attempt_id
            retained.parent.mkdir(parents=True, exist_ok=True)
            (attempt / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            os.replace(attempt, retained)
            return artifact
        return _publish(attempt, artifact, manifest)


def build_l05(paths: BuildPaths, context_id: str, force: bool = False) -> Path:
    parent_artifact = build_l04(paths, context_id)
    context = load_context(paths, context_id)
    nodes = graph(paths, context_id)
    node = nodes[4]
    artifact = node["artifact"]
    profile = context["layers"]["L05"]["profile"].upper()
    if profile == "AGENTIC":
        raise ValueError("L05 AGENTIC is a placeholder: no trusted-local agent protocol is implemented")
    if profile not in {"CLI", "GUI"}:
        raise ValueError(f"unsupported L05 profile {profile!r}")
    if (artifact / "manifest.json").is_file() and not force:
        return artifact
    with artifact_lock(paths, context_id, "L05", node["buildKey"]):
        if (artifact / "manifest.json").is_file() and not force:
            return artifact
        attempt_id = str(uuid.uuid4())
        attempt = paths.state / "tmp" / f"attempt-{attempt_id}"
        attempt.mkdir(parents=True)
        copy_reflink(parent_artifact / "image", attempt / "image")
        set_tree_writable(attempt, True)
        manifests = []
        for parent_node in nodes[:4]:
            manifests.append(read_json(parent_node["artifact"] / "manifest.json"))
        manifests_text = canonical_json(manifests)
        manifests_digest = hashlib.sha256(manifests_text.encode("utf-8")).hexdigest()
        metadata_file = attempt / "lower-manifests.json"
        metadata_file.write_text(manifests_text + "\n", encoding="utf-8")
        runtime_artifact = nodes[0]["artifact"]
        launcher = runtime_artifact / "runtime/bin/GlamorousToolkit-cli"
        home = attempt / "test-home"
        for name in ("", "config", "cache"):
            (home / name).mkdir(parents=True, exist_ok=True)
        environment = os.environ.copy()
        environment.update({
            "HOME": str(home), "XDG_CONFIG_HOME": str(home / "config"), "XDG_CACHE_HOME": str(home / "cache"),
            "KLIBGEN_MANIFESTS_FILE": str(metadata_file), "KLIBGEN_MANIFESTS_DIGEST": manifests_digest, "KLIBGEN_PROFILE": profile,
        })
        setup = paths.root / "build/layers/l05-project-setup/scripts/install-metadata.st"
        process = subprocess.run([str(launcher), str(attempt / "image/GlamorousToolkit.image"), "st", str(setup)], env=environment, capture_output=True, text=True)
        (attempt / "setup.log").write_text(process.stdout + process.stderr, encoding="utf-8")
        if process.returncode:
            raise RuntimeError(f"L05 setup failed; retained attempt: {attempt}")
        contract = paths.root / "build/layers/l05-project-setup/tests/contract.st"
        process = subprocess.run([str(launcher), str(attempt / "image/GlamorousToolkit.image"), "st", str(contract)], env=environment, capture_output=True, text=True)
        (attempt / "contract.log").write_text(process.stdout + process.stderr, encoding="utf-8")
        if process.returncode:
            raise RuntimeError(f"L05 contract failed; retained attempt: {attempt}")
        shutil.rmtree(home)
        output = {"path": "image/GlamorousToolkit.image", "sha256": sha256_file(attempt / "image/GlamorousToolkit.image")}
        manifest = _manifest(node["definition"], context_id, node["buildKey"], nodes[3],
                             [{"profile": profile, "lowerManifestDigest": manifests_digest}], [output],
                             [{"name": "l05-contract", "status": "passed", "log": "contract.log"}])
        manifest["variant"] = {"name": profile, "kind": "configuration-profile"}
        manifest["inImageMetadata"] = {"class": "KlibGenBuildMetadata", "digest": manifests_digest}
        if force and artifact.exists():
            retained = paths.state / "logs/rebuilds" / context_id / "l05" / node["buildKey"] / attempt_id
            retained.parent.mkdir(parents=True, exist_ok=True)
            (attempt / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            os.replace(attempt, retained)
            return artifact
        return _publish(attempt, artifact, manifest)


def build_l06(paths: BuildPaths, context_id: str, force: bool = False) -> Path:
    parent_artifact = build_l05(paths, context_id)
    context = load_context(paths, context_id)
    nodes = graph(paths, context_id)
    node = nodes[5]
    artifact = node["artifact"]
    profile = context["layers"]["L06"]["profile"].upper()
    if profile == "AGENTIC":
        raise ValueError("L06 AGENTIC is a placeholder: no trusted-local agent protocol is implemented")
    if (artifact / "manifest.json").is_file() and not force:
        return artifact
    with artifact_lock(paths, context_id, "L06", node["buildKey"]):
        if (artifact / "manifest.json").is_file() and not force:
            return artifact
        attempt_id = str(uuid.uuid4())
        attempt = paths.state / "tmp" / f"attempt-{attempt_id}"
        attempt.mkdir(parents=True)
        copy_reflink(parent_artifact / "image", attempt / "image")
        set_tree_writable(attempt, True)
        identity = jj_identity(paths, context["project"]["revision"])
        bridge = attempt / "export"
        bridge_commit = materialize_jj_source(paths, identity, bridge)
        runtime_artifact = nodes[0]["artifact"]
        launcher = runtime_artifact / "runtime/bin/GlamorousToolkit-cli"
        home = attempt / "test-home"
        for name in ("", "config", "cache"):
            (home / name).mkdir(parents=True, exist_ok=True)
        environment = os.environ.copy()
        environment.update({
            "HOME": str(home), "XDG_CONFIG_HOME": str(home / "config"), "XDG_CACHE_HOME": str(home / "cache"),
            "KLIBGEN_EXPORT_GIT": str(bridge / ".git"), "KLIBGEN_PROFILE": profile,
        })
        loader = paths.root / "build/layers/l06-project-dev/scripts/load.st"
        process = subprocess.run([str(launcher), str(attempt / "image/GlamorousToolkit.image"), "st", str(loader)], env=environment, capture_output=True, text=True)
        (attempt / "load.log").write_text(process.stdout + process.stderr, encoding="utf-8")
        if process.returncode:
            raise RuntimeError(f"L06 project load failed; retained attempt: {attempt}")
        contract = paths.root / "build/layers/l06-project-dev/tests/contract.st"
        process = subprocess.run([str(launcher), str(attempt / "image/GlamorousToolkit.image"), "st", str(contract)], env=environment, capture_output=True, text=True)
        (attempt / "contract.log").write_text(process.stdout + process.stderr, encoding="utf-8")
        if process.returncode:
            raise RuntimeError(f"L06 contract failed; retained attempt: {attempt}")
        shutil.rmtree(home)
        shutil.rmtree(bridge)
        (attempt / "source-mapping.json").write_text(json.dumps({
            "vcs": "jj", "workspace": context["project"]["workspace"], "revision": identity,
            "generatedBridgeCommit": bridge_commit, "tonelDirectory": "src",
        }, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        output = {"path": "image/GlamorousToolkit.image", "sha256": sha256_file(attempt / "image/GlamorousToolkit.image")}
        manifest = _manifest(node["definition"], context_id, node["buildKey"], nodes[4],
                             [{"projectSource": identity, "generatedBridgeCommit": bridge_commit, "profile": profile}], [output],
                             [{"name": "project-load", "status": "passed", "log": "load.log"}, {"name": "project-tests", "status": "passed", "log": "contract.log"}])
        manifest["variant"] = {"name": profile, "kind": "configuration-profile"}
        manifest["sources"] = [{"repositoryId": "project", "vcs": "jj", **identity}]
        manifest["dirty"] = False
        manifest["mutable"] = identity["mutable"]
        manifest["packageMapping"] = {"packages": "KlibGenGt-*", "generatedRunBridge": True, "authoritativeWorkspace": context["project"]["workspace"]}
        if force and artifact.exists():
            retained = paths.state / "logs/rebuilds" / context_id / "l06" / node["buildKey"] / attempt_id
            retained.parent.mkdir(parents=True, exist_ok=True)
            (attempt / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            os.replace(attempt, retained)
            return artifact
        return _publish(attempt, artifact, manifest)


def build_l07(paths: BuildPaths, context_id: str, force: bool = False) -> Path:
    context = load_context(paths, context_id)
    profile = context["layers"]["L07"]["profile"].upper()
    if profile == "RELEASE":
        raise ValueError("L07 RELEASE is not production-ready and rejects all builds")
    if profile != "DEV":
        raise ValueError(f"unsupported L07 profile {profile!r}")
    if context["layers"]["L06"]["profile"].upper() != "CLI":
        raise ValueError("L07 DEV must be built from a canonical L06 CLI artifact")
    parent_artifact = build_l06(paths, context_id)
    nodes = graph(paths, context_id)
    node = nodes[6]
    artifact = node["artifact"]
    if (artifact / "manifest.json").is_file() and not force:
        return artifact
    with artifact_lock(paths, context_id, "L07", node["buildKey"]):
        if (artifact / "manifest.json").is_file() and not force:
            return artifact
        attempt_id = str(uuid.uuid4())
        attempt = paths.state / "tmp" / f"attempt-{attempt_id}"
        bundle = attempt / "bundle"
        bundle.mkdir(parents=True)
        runtime_artifact = nodes[0]["artifact"]
        copy_reflink(runtime_artifact / "runtime/bin", bundle / "runtime/bin")
        copy_reflink(runtime_artifact / "runtime/lib", bundle / "runtime/lib")
        copy_reflink(parent_artifact / "image", bundle / "image")
        set_tree_writable(bundle, True)
        for generated in (bundle / "image/pharo-local", bundle / "image/gt-extra"):
            if generated.exists():
                shutil.rmtree(generated)
        launcher = bundle / "bin/klibgen-gt"
        launcher.parent.mkdir()
        launcher.write_text(
            "#!/usr/bin/env sh\n"
            "set -eu\n"
            "root=$(CDPATH= cd -- \"$(dirname -- \"$0\")/..\" && pwd)\n"
            "exec \"$root/runtime/bin/GlamorousToolkit-cli\" \"$root/image/GlamorousToolkit.image\" \"$@\"\n",
            encoding="utf-8",
        )
        launcher.chmod(0o755)
        parent_manifest = read_json(parent_artifact / "manifest.json")
        version = {
            "schemaVersion": 1,
            "distribution": "KlibGenGt",
            "profile": profile,
            "projectCommitId": parent_manifest["sources"][0]["commitId"],
            "projectChangeId": parent_manifest["sources"][0]["changeId"],
            "parentL06BuildKey": parent_manifest["buildKey"],
        }
        (bundle / "version.json").write_text(json.dumps(version, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        smoke = paths.root / "build/layers/l07-project-dist/tests/smoke.st"
        smoke_cwd = paths.root / "tmp"
        smoke_cwd.mkdir(exist_ok=True)
        environment = os.environ.copy()
        test_home = attempt / "test-home"
        for name in ("", "config", "cache"):
            (test_home / name).mkdir(parents=True, exist_ok=True)
        environment.update({"HOME": str(test_home), "XDG_CONFIG_HOME": str(test_home / "config"), "XDG_CACHE_HOME": str(test_home / "cache")})
        process = subprocess.run([str(launcher), "st", str(smoke)], cwd=smoke_cwd, env=environment, capture_output=True, text=True)
        (attempt / "startup-smoke.log").write_text(process.stdout + process.stderr, encoding="utf-8")
        if process.returncode:
            raise RuntimeError(f"L07 startup smoke failed; retained attempt: {attempt}")
        shutil.rmtree(test_home)
        checksum_entries = []
        for path in sorted(item for item in bundle.rglob("*") if item.is_file()):
            relative = path.relative_to(bundle).as_posix()
            checksum_entries.append((sha256_file(path), relative))
        checksum_file = bundle / "SHA256SUMS"
        checksum_file.write_text("".join(f"{digest}  {relative}\n" for digest, relative in checksum_entries), encoding="utf-8")
        outputs = [
            {"path": "bundle/bin/klibgen-gt", "sha256": sha256_file(launcher), "executable": True},
            {"path": "bundle/version.json", "sha256": sha256_file(bundle / "version.json")},
            {"path": "bundle/SHA256SUMS", "sha256": sha256_file(checksum_file)},
            {"path": "bundle/image/GlamorousToolkit.image", "sha256": sha256_file(bundle / "image/GlamorousToolkit.image")},
        ]
        manifest = _manifest(
            node["definition"], context_id, node["buildKey"], nodes[5],
            [{"parentL06Artifact": str(parent_artifact), "parentL06BuildKey": parent_manifest["buildKey"], "profile": profile}],
            outputs,
            [{"name": "distribution-startup", "status": "passed", "log": "startup-smoke.log", "workingDirectory": str(smoke_cwd)}],
        )
        manifest["variant"] = {"name": profile, "kind": "packaging-profile"}
        manifest["sources"] = parent_manifest["sources"]
        manifest["snapshotParent"] = False
        if force and artifact.exists():
            retained = paths.state / "logs/rebuilds" / context_id / "l07" / node["buildKey"] / attempt_id
            retained.parent.mkdir(parents=True, exist_ok=True)
            (attempt / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            os.replace(attempt, retained)
            return artifact
        return _publish(attempt, artifact, manifest)
