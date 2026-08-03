from __future__ import annotations

import hashlib
import logging
import os
import platform
import shutil
from pathlib import Path, PurePosixPath
from typing import Any, Iterable, Mapping

from .core import BuildPaths, digest_json, read_json
from .json_models import SourceLockV1, validate_named_record
from .processes import run_command
from .recipes import DEFAULT_TARGETS, Recipe, Target, json_value


RESOLVED_RECIPE_SCHEMA = "klibgen.resolved-recipe/1"
SOURCE_LOCK_SCHEMA = "klibgen.source-lock/1"
logger = logging.getLogger(__name__)


def validate_lock(value: dict[str, Any]) -> None:
    try:
        SourceLockV1.model_validate(value)
    except ValueError as error:
        raise ValueError(f"lock must use {SOURCE_LOCK_SCHEMA} with schemaVersion 1 and a sources array") from error
    if value.get("schema") != SOURCE_LOCK_SCHEMA or value.get("schemaVersion") != 1 or not isinstance(value.get("sources"), list):
        raise ValueError(f"lock must use {SOURCE_LOCK_SCHEMA} with schemaVersion 1 and a sources array")
    for source in value["sources"]:
        if source.get("sourceType") == "git":
            commit = source.get("resolved", {}).get("commit", "")
            if len(commit) != 40 or any(character not in "0123456789abcdef" for character in commit):
                raise ValueError(f"Git source {source.get('sourceId')} is not locked to a full commit")
        if source.get("sourceType") == "archive":
            checksum = source.get("integrity", {}).get("sha256", "")
            if len(checksum) != 64 or any(character not in "0123456789abcdef" for character in checksum):
                raise ValueError(f"archive source {source.get('sourceId')} lacks a SHA-256 lock")


def _digest_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _relative(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def digest_paths(root: Path, paths: Iterable[str], exclude: Iterable[str] = ()) -> dict[str, Any]:
    """Digest declared repository files without following symlinks."""
    root = root.resolve()
    exclusions = tuple(PurePosixPath(value) for value in exclude)

    def excluded(relative: str) -> bool:
        candidate = PurePosixPath(relative)
        return any(candidate == prefix or prefix in candidate.parents for prefix in exclusions)

    records: list[dict[str, Any]] = []
    for declared in sorted(set(paths)):
        target = (root / declared).resolve()
        try:
            target.relative_to(root)
        except ValueError as error:
            raise ValueError(f"declared input escapes repository: {declared!r}") from error
        if not target.exists() and not target.is_symlink():
            records.append({"path": declared, "kind": "missing"})
            continue
        candidates = [target] if not target.is_dir() else sorted(target.rglob("*"))
        for candidate in candidates:
            relative = _relative(candidate, root)
            if excluded(relative) or candidate.is_dir():
                continue
            if candidate.is_symlink():
                records.append({"path": relative, "kind": "symlink", "target": os.readlink(candidate)})
            elif candidate.is_file():
                records.append({
                    "path": relative,
                    "kind": "file",
                    "mode": candidate.stat(follow_symlinks=False).st_mode & 0o777,
                    "sha256": _digest_file(candidate),
                })
    result = {"digest": digest_json(records), "files": records}
    logger.debug("digested declared paths root=%s files=%d digest=%s", root, len(records), result["digest"])
    return result


def git_worktree_identity(path: Path) -> dict[str, Any]:
    repository = path.resolve()
    head = run_command(["git", "rev-parse", "HEAD"], cwd=repository).stdout.strip()
    tree = run_command(["git", "rev-parse", "HEAD^{tree}"], cwd=repository).stdout.strip()
    status = run_command(
        ["git", "status", "--porcelain=v1", "--untracked-files=all"], cwd=repository
    ).stdout.splitlines()
    effective = digest_paths(repository, ["."], exclude=[".git"])
    return {
        "vcs": "git",
        "commit": head,
        "tree": tree,
        "dirty": bool(status),
        "dirtyDigest": effective["digest"] if status else None,
        "changedPaths": status,
    }


def jj_tree_identity(root: Path, paths: Iterable[str], exclude: Iterable[str]) -> dict[str, Any]:
    selected_paths = tuple(paths)
    excluded_paths = tuple(exclude)
    for attempt in range(3):
        revision = read_jj_revision(root)
        content = digest_paths(root, selected_paths, excluded_paths)
        if read_jj_revision(root) == revision:
            logger.debug("captured JJ source identity attempt=%d commit=%s digest=%s", attempt + 1, revision["commitId"], content["digest"])
            return {
                "vcs": "jj",
                "commitId": revision["commitId"],
                "changeId": revision["changeId"],
                "treeDigest": content["digest"],
                "paths": sorted(set(selected_paths)),
                "exclude": sorted(set(excluded_paths)),
            }
    raise ValueError("JJ working-copy revision changed repeatedly while capturing source")


def read_jj_revision(root: Path) -> dict[str, str]:
    template = 'commit_id ++ "\\n" ++ change_id ++ "\\n"'
    lines = run_command(["jj", "log", "-r", "@", "--no-graph", "-T", template], cwd=root).stdout.splitlines()
    if len(lines) != 2:
        raise ValueError("could not resolve current JJ commit/change identity")
    return {"commitId": lines[0], "changeId": lines[1]}


def _tool_identity(name: str) -> dict[str, Any]:
    executable = shutil.which(name)
    if executable is None:
        return {"name": name, "available": False}
    result = run_command([executable, "--version"], check=False)
    version = (result.stdout or result.stderr).splitlines()
    return {"name": name, "available": True, "path": executable, "version": version[0] if version else ""}


def _lock_sources(paths: BuildPaths) -> dict[str, dict[str, Any]]:
    lock = read_json(paths.root / "build/locks/default.lock.json")
    validate_lock(lock)
    return {source["sourceId"]: source for source in lock["sources"]}


def _resolve_config(paths: BuildPaths, config: Mapping[str, Any]) -> dict[str, Any]:
    resolved = json_value(config)
    locks = _lock_sources(paths)
    if "sourceLocks" in resolved:
        requested = resolved.pop("sourceLocks")
        missing = sorted(set(requested) - locks.keys())
        if missing:
            raise ValueError(f"unknown locked sources: {', '.join(missing)}")
        resolved["sources"] = [locks[source] for source in requested]
    if resolved.pop("platform", False):
        resolved["platform"] = {
            "os": platform.system().lower(),
            "architecture": platform.machine().lower(),
            "abi": platform.machine().lower(),
        }
    if "jjTree" in resolved:
        selection = resolved.pop("jjTree")
        resolved["source"] = jj_tree_identity(
            paths.root, selection["paths"], selection.get("exclude", [])
        )
    if "sourcePaths" in resolved:
        selected_paths = resolved.pop("sourcePaths")
        resolved["sourcePaths"] = digest_paths(paths.root, selected_paths)
    if "gitWorktree" in resolved:
        selected_path = Path(resolved.pop("gitWorktree"))
        if not selected_path.is_absolute():
            selected_path = paths.root / selected_path
        resolved["gitWorktree"] = git_worktree_identity(selected_path)
    if "environment" in resolved:
        names = resolved.pop("environment")
        resolved["environment"] = {name: os.environ.get(name) for name in names}
    if "tools" in resolved:
        names = resolved.pop("tools")
        resolved["tools"] = [_tool_identity(name) for name in names]
    return resolved


def _key_configuration(resolved: Mapping[str, Any]) -> dict[str, Any]:
    """Return effective construction inputs without VCS-only provenance."""
    key_configuration = dict(resolved)
    source = key_configuration.get("source")
    if isinstance(source, dict) and source.get("vcs") == "jj":
        key_configuration["source"] = {"treeDigest": source["treeDigest"]}
    return key_configuration


def resolve_recipe(paths: BuildPaths, target: Target, recipe: Recipe | None = None) -> dict[str, Any]:
    selected = recipe or target.recipe
    logger.debug("resolving recipe target=%s recipe=%s steps=%d", target.name, selected.name, len(selected.steps))
    parent_key: str | None = None
    steps: list[dict[str, Any]] = []
    for step in selected.steps:
        implementation_inputs = digest_paths(paths.root, step.implementation.inputs)
        resolved_config = _resolve_config(paths, step.config)
        key_material = {
            "parentOutputKey": parent_key,
            "implementation": {
                "identifier": step.implementation.identifier,
                "version": step.implementation.version,
                "inputsDigest": implementation_inputs["digest"],
            },
            "configuration": _key_configuration(resolved_config),
        }
        output_key = digest_json(key_material)
        steps.append({
            "role": step.role,
            "implementation": step.implementation.as_dict(),
            "implementationInputs": implementation_inputs,
            "resolvedConfiguration": resolved_config,
            "parentOutputKey": parent_key,
            "stepKey": output_key,
            "outputKey": output_key,
            "checkpoint": step.checkpoint,
            "origin": step.origin,
        })
        parent_key = output_key
    return validate_named_record({
        "schema": RESOLVED_RECIPE_SCHEMA,
        "schemaVersion": 1,
        "operation": "v2.recipe.resolve",
        "target": target.name,
        "recipe": selected.name,
        "preset": target.preset.as_dict(),
        "steps": steps,
        "outputKey": parent_key,
    })


def resolve_target(paths: BuildPaths, name: str, through: str | None = None) -> dict[str, Any]:
    logger.debug("resolving target name=%s through=%s", name, through)
    try:
        target = DEFAULT_TARGETS[name]
    except KeyError as error:
        raise ValueError(
            f"unknown v0.2 target {name!r}; choose from {', '.join(sorted(DEFAULT_TARGETS))}"
        ) from error
    recipe = target.recipe.through(through) if through is not None else target.recipe
    return resolve_recipe(paths, target, recipe)


def recipe_catalog() -> dict[str, Any]:
    return validate_named_record({
        "schema": "klibgen.recipe-catalog/1",
        "schemaVersion": 1,
        "operation": "v2.recipe.list",
        "targets": [
            {
                "name": target.name,
                "recipe": target.recipe.name,
                "preset": target.preset.as_dict(),
                "roles": [step.role for step in target.recipe.steps],
            }
            for target in sorted(DEFAULT_TARGETS.values(), key=lambda item: item.name)
        ],
    })


__all__ = [
    "RESOLVED_RECIPE_SCHEMA", "digest_paths", "git_worktree_identity", "jj_tree_identity",
    "recipe_catalog", "resolve_recipe", "resolve_target",
]
