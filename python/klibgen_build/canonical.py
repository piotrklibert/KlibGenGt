from __future__ import annotations

import json
import os
import shutil
import uuid
import zipfile
from pathlib import Path
from typing import Any, Iterable

from .builder import build_resolved
from .core import BuildPaths
from .processes import run_command
from .resolution import resolve_target
from .store import ArtifactStore
from .tonel_lint import verify_tonel_roundtrip


def _set_writable(root: Path) -> None:
    for path in (root, *root.rglob("*")):
        if not path.is_symlink():
            path.chmod(path.stat().st_mode | 0o200)


def _private_environment(workspace: Path, additions: dict[str, str] | None = None) -> dict[str, str]:
    home = workspace / "home"
    for relative in ("", "config", "cache", "data", "tmp"):
        (home / relative).mkdir(parents=True, exist_ok=True)
    environment = os.environ.copy()
    environment.update({
        "HOME": str(home), "XDG_CONFIG_HOME": str(home / "config"),
        "XDG_CACHE_HOME": str(home / "cache"), "XDG_DATA_HOME": str(home / "data"),
        "TMPDIR": str(home / "tmp"),
    })
    environment.update(additions or {})
    return environment


def _run_image(paths: BuildPaths, payload: Path, script: Path, name: str, additions: dict[str, str] | None = None) -> None:
    workspace = payload.parent
    logs = workspace / "logs"
    logs.mkdir(exist_ok=True)
    launcher = payload / "runtime/bin/GlamorousToolkit-cli"
    image = payload / "image/GlamorousToolkit.image"
    result = run_command(
        [launcher, image, "st", script], check=False, cwd=workspace,
        env=_private_environment(workspace, additions),
    )
    (logs / f"{name}.log").write_text(result.stdout + result.stderr, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"{name} failed; log: {logs / f'{name}.log'}")


def _extract_clean_image(paths: BuildPaths, destination: Path) -> None:
    archive = paths.root / "vendor/gt.zip"
    with zipfile.ZipFile(archive) as source:
        members = [name for name in source.namelist() if not name.endswith("/")]
        for name in members:
            basename = Path(name).name
            if basename not in {"GlamorousToolkit.image", "GlamorousToolkit.changes"} and not name.endswith(".sources") and "/gt-extra/" not in f"/{name}":
                continue
            relative = Path("gt-extra") / Path(name).relative_to(name.split("gt-extra/")[0] + "gt-extra") if "gt-extra/" in name else Path(basename)
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            with source.open(name) as input_stream, target.open("wb") as output_stream:
                shutil.copyfileobj(input_stream, output_stream, length=1024 * 1024)
    if not (destination / "GlamorousToolkit.image").is_file():
        raise RuntimeError(f"verified GT archive contains no image: {archive}")


def _git_bridge(paths: BuildPaths, workspace: Path, relative_paths: Iterable[str], revision: str | None = None) -> Path:
    bridge = workspace / f"source-{uuid.uuid4().hex}"
    selected = tuple(relative_paths)
    if revision is None:
        files = [
            path for relative in selected for path in (paths.root / relative).rglob("*")
            if path.is_file()
        ]
        for source in files:
            target = bridge / source.relative_to(paths.root)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    else:
        listing = run_command(["jj", "file", "list", "-r", revision, *selected], cwd=paths.root).stdout.splitlines()
        for relative in listing:
            target = bridge / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            content = run_command(["jj", "file", "show", "-r", revision, relative], cwd=paths.root).stdout
            target.write_text(content, encoding="utf-8")
    (bridge / ".project").write_text("{\n\t'srcDirectory' : 'src'\n}\n", encoding="utf-8")
    run_command(["git", "init", "--initial-branch=master", bridge])
    run_command(["git", "-C", bridge, "add", ".project", "src"])
    run_command(["git", "-C", bridge, "-c", "user.name=KlibGen Build", "-c", "user.email=build@localhost", "commit", "-m", "Materialize v0.2 source"])
    return bridge


def _dependency_repository(paths: BuildPaths, step: dict[str, Any]) -> str:
    source = next(item for item in step["resolvedConfiguration"]["sources"] if item["sourceId"] == "sqlite3")
    commit = source["resolved"]["commit"]
    worktree = paths.root / "vendor/gt-build/dependencies/sqlite3"
    if not (worktree / ".git").is_dir():
        raise RuntimeError(f"pinned SQLite source cache is missing: {worktree}; clone {source['source']} at {commit}")
    actual = run_command(["git", "-C", worktree, "rev-parse", "HEAD"]).stdout.strip()
    if actual != commit:
        raise RuntimeError(f"SQLite source cache is at {actual}, expected {commit}")
    return f"gitlocal://{worktree / '.git'}:{commit}/src"


class CanonicalExecutor:
    def __init__(self, paths: BuildPaths, resolved: dict[str, Any]):
        self.paths = paths
        self.resolved = resolved

    def __call__(self, step: dict[str, Any], payload: Path) -> None:
        role = step["role"]
        workspace = payload.parent
        if role == "runtime":
            run_command([self.paths.root / "scripts/bootstrap-gt.sh"])
            runtime = self.paths.root / "vendor/gt"
            (payload / "runtime").symlink_to(runtime, target_is_directory=True)
            return
        _set_writable(payload)
        if role == "pharo-gt":
            _extract_clean_image(self.paths, payload / "image")
        elif role == "gt-patches":
            _run_image(self.paths, payload, self.paths.root / "scripts/patch-gt-headless-webview.st", "gt-patches")
        elif role == "build-support":
            bridge = _git_bridge(self.paths, workspace, ("src/BaselineOfKlibGenGt", "src/KlibGenGt-BuildSupport"))
            _run_image(self.paths, payload, self.paths.root / "build/v2/scripts/load-build-support.st", "build-support", {"KLIBGEN_BUILD_SOURCE_GIT": str(bridge / ".git")})
            shutil.rmtree(bridge)
            _run_image(self.paths, payload, self.paths.root / "build/v2/tests/build-support-contract.st", "build-support-contract")
        elif role == "project-dependencies":
            repository = _dependency_repository(self.paths, step)
            _run_image(self.paths, payload, self.paths.root / "build/v2/scripts/load-project-dependencies.st", "project-dependencies", {"KLIBGEN_SQLITE_REPOSITORY": repository})
            _run_image(self.paths, payload, self.paths.root / "build/v2/tests/project-dependencies-contract.st", "project-dependencies-contract")
        elif role == "project-setup":
            return
        elif role == "project-source":
            revision = step["resolvedConfiguration"]["source"]["commitId"]
            bridge = _git_bridge(self.paths, workspace, ("src",), revision)
            exported = workspace / f"tonel-{uuid.uuid4().hex}/src"
            dependency_step = next(item for item in self.resolved["steps"] if item["role"] == "project-dependencies")
            try:
                _run_image(self.paths, payload, self.paths.root / "build/v2/scripts/load-project-source.st", "project-source", {"KLIBGEN_EXPORT_GIT": str(bridge / ".git"), "KLIBGEN_TONEL_OUTPUT": str(exported), "KLIBGEN_SQLITE_REPOSITORY": _dependency_repository(self.paths, dependency_step)})
                verify_tonel_roundtrip(bridge / "src", exported)
            finally:
                shutil.rmtree(bridge, ignore_errors=True)
                shutil.rmtree(exported.parent, ignore_errors=True)
        elif role == "project-finalize":
            manifest = workspace / "resolved-recipe.json"
            manifest.write_text(json.dumps(self.resolved, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            _run_image(self.paths, payload, self.paths.root / "build/v2/scripts/install-provenance.st", "project-provenance", {"KLIBGEN_BUILD_MANIFEST": str(manifest), "KLIBGEN_PROJECT_KEY": self.resolved["outputKey"]})
            results = workspace / "contract-results.json"
            (workspace / "data").symlink_to(self.paths.root / "data", target_is_directory=True)
            _run_image(self.paths, payload, self.paths.root / "build/v2/tests/project-contract.st", "project-contract", {"KLIBGEN_TEST_RESULTS_PATH": str(results)})
        else:
            raise ValueError(f"no canonical executor for role {role!r}")


def build_canonical(paths: BuildPaths, target: str, through: str | None = None) -> dict[str, Any]:
    resolved = resolve_target(paths, target, through)
    result = build_resolved(paths, resolved, CanonicalExecutor(paths, resolved))
    last = resolved["steps"][-1]
    artifact_type = last["implementation"]["outputType"]
    reference_name = "default-project" if last["role"] == "project-finalize" else f"default-{last['role']}"
    ArtifactStore(paths).write_reference(reference_name, artifact_type, last["outputKey"])
    return result | {"reference": reference_name}


__all__ = ["CanonicalExecutor", "build_canonical"]
