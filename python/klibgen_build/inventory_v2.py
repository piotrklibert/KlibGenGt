from __future__ import annotations

import fcntl
import json
import logging
import shutil
import stat
import tempfile
from contextlib import ExitStack
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from pydantic import ValidationError

from .core import BuildPaths
from .json_models import parse_named_record, validate_named_record, validation_message
from .recipes import DEFAULT_RECIPES, DEFAULT_TARGETS
from .resolution import resolve_target
from .store import ArtifactStore
from .v2state import V2Paths


logger = logging.getLogger(__name__)


def _project_state_root(paths: BuildPaths) -> Path:
    state = paths.state.absolute()
    expected = paths.root.resolve() / ".klibgen"
    if state != expected:
        raise ValueError(
            f"refusing to prune anything except the project-local .klibgen root: {state}"
        )
    if state.is_symlink():
        raise ValueError(f"refusing to prune a symbolic-link state root: {state}")
    return state


def _make_tree_writable(root: Path) -> None:
    for target in (root, *root.rglob("*")):
        if target.is_symlink():
            continue
        mode = stat.S_IWUSR | (stat.S_IXUSR if target.is_dir() else 0)
        target.chmod(target.stat().st_mode | mode)


def _preserve_lepiter(paths: BuildPaths, state: Path) -> tuple[Path | None, list[Path]]:
    relative_roots = sorted(
        path.relative_to(state)
        for path in (state / "v2/workspaces").glob("*/home/Documents/lepiter")
        if path.is_dir() and not path.is_symlink()
    )
    if not relative_roots:
        return None, []
    temporary_parent = paths.root / "tmp"
    temporary_parent.mkdir(exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix="prune-lepiter-", dir=temporary_parent))
    for relative in relative_roots:
        source = state / relative
        target = backup / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source, target, symlinks=True)
    logger.info("preserved Lepiter trees before prune count=%d path=%s", len(relative_roots), backup)
    return backup, relative_roots


def _restore_lepiter(state: Path, backup: Path, relative_roots: list[Path]) -> None:
    for relative in relative_roots:
        source = backup / relative
        target = state / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(source, target)
    shutil.rmtree(backup)
    logger.info("restored Lepiter trees after prune count=%d", len(relative_roots))


def prune(paths: BuildPaths) -> dict[str, Any]:
    """Remove the complete project-local generated state after checking its locks."""
    state = _project_state_root(paths)
    if not state.exists():
        logger.info("build state is already absent path=%s", state)
        return {
            "operation": "prune", "path": str(state), "removed": False,
            "lockCount": 0, "storage": _size(state),
        }
    lock_paths = sorted((state / "v2/locks").rglob("*.lock"))
    logger.info("pruning complete build state path=%s locks=%d", state, len(lock_paths))
    before = _size(state)
    lepiter_backup: Path | None = None
    lepiter_roots: list[Path] = []
    with ExitStack() as streams:
        for lock_path in lock_paths:
            stream = streams.enter_context(lock_path.open("a"))
            try:
                fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as error:
                raise RuntimeError(
                    f"build state is active; lock is held: {lock_path}"
                ) from error
        lepiter_backup, lepiter_roots = _preserve_lepiter(paths, state)
        _make_tree_writable(state)
        shutil.rmtree(state)
        if lepiter_backup is not None:
            _restore_lepiter(state, lepiter_backup, lepiter_roots)
    logger.info(
        "pruned complete build state path=%s allocatedBytes=%d",
        state, before["allocatedBytes"],
    )
    return {
        "operation": "prune", "path": str(state), "removed": True,
        "lockCount": len(lock_paths), "preservedLepiterCount": len(lepiter_roots),
        "storage": before,
    }


def _size(path: Path) -> dict[str, int]:
    logical = allocated = files = 0
    if path.is_file():
        stat = path.stat()
        return {"logicalBytes": stat.st_size, "allocatedBytes": stat.st_blocks * 512, "fileCount": 1}
    for item in path.rglob("*") if path.is_dir() else ():
        if item.is_file() and not item.is_symlink():
            stat = item.stat()
            logical += stat.st_size
            allocated += stat.st_blocks * 512
            files += 1
    return {"logicalBytes": logical, "allocatedBytes": allocated, "fileCount": files}


def _records(root: Path, pattern: str) -> list[dict[str, Any]]:
    values = []
    for path in sorted(root.glob(pattern)) if root.is_dir() else ():
        try:
            record = json.loads(path.read_text(encoding="utf-8")) | {"path": str(path.parent), "storage": _size(path.parent)}
            values.append(parse_named_record(record).to_wire())
        except (OSError, json.JSONDecodeError, ValueError, ValidationError) as error:
            if isinstance(error, ValidationError):
                error = ValueError(validation_message(error))
            values.append({"path": str(path), "malformed": True, "error": str(error)})
    return values


def inventory(paths: BuildPaths) -> dict[str, Any]:
    logger.info("collecting build inventory")
    v2 = V2Paths.for_build(paths)
    v2.initialize()
    recipes = [{"name": recipe.name, "roles": [step.role for step in recipe.steps]} for recipe in DEFAULT_RECIPES.values()]
    targets = []
    for name in DEFAULT_TARGETS:
        resolved = resolve_target(paths, name)
        targets.append({"name": name, "outputKey": resolved["outputKey"], "steps": [
            {"role": step["role"], "outputKey": step["outputKey"], "checkpoint": step["checkpoint"]}
            for step in resolved["steps"]
        ]})
    artifacts = ArtifactStore(paths).artifacts()
    for artifact in artifacts:
        artifact["storage"] = _size(Path(artifact["path"]))
    references = _records(v2.root / "refs", "*.json")
    workspaces = _records(v2.root / "workspaces", "*/workspace.json")
    staging_areas = _records(v2.root / "staging", "*/staging.json")
    nodes: list[dict[str, Any]] = []
    edges: list[dict[str, Any]] = []
    for target in targets:
        target_id = f"target:{target['name']}"
        nodes.append({"id": target_id, "kind": "target", "label": target["name"], "status": "resolved", "characteristics": target, "logicalBytes": 0, "allocatedBytes": 0, "fileCount": 0})
        previous = target_id
        for index, step in enumerate(target["steps"]):
            step_id = f"step:{target['name']}:{index}:{step['outputKey']}"
            nodes.append({"id": step_id, "kind": "step", "label": step["role"], "status": "resolved", "characteristics": step, "logicalBytes": 0, "allocatedBytes": 0, "fileCount": 0})
            edges.append({"id": f"edge:{previous}:{step_id}", "kind": "recipe-sequence", "source": previous, "target": step_id, "characteristics": {}})
            previous = step_id
    for artifact in artifacts:
        artifact_id = f"artifact:{artifact.get('outputKey', Path(artifact['path']).name)}"
        storage = artifact["storage"]
        nodes.append({"id": artifact_id, "kind": "artifact", "label": f"{artifact.get('producingRole', 'invalid')} {Path(artifact['path']).name[:10]}", "status": "verified" if artifact.get("valid") else "invalid", "path": artifact["path"], "characteristics": artifact, **storage})
        for target in targets:
            for index, step in enumerate(target["steps"]):
                if step["outputKey"] == artifact.get("outputKey"):
                    step_id = f"step:{target['name']}:{index}:{step['outputKey']}"
                    edges.append({"id": f"edge:{step_id}:{artifact_id}", "kind": "step-artifact", "source": step_id, "target": artifact_id, "characteristics": {}})
    for reference in references:
        if reference.get("malformed"):
            continue
        node_id = f"reference:{reference['name']}"
        nodes.append({"id": node_id, "kind": "reference", "label": reference["name"], "status": "current", "characteristics": reference, "logicalBytes": 0, "allocatedBytes": 0, "fileCount": 1})
        edges.append({"id": f"edge:{node_id}", "kind": "reference-artifact", "source": node_id, "target": f"artifact:{reference['outputKey']}", "characteristics": {}})
    for kind, records in (("workspace", workspaces), ("staging", staging_areas)):
        for record in records:
            if record.get("malformed"):
                continue
            node_id = f"{kind}:{record['name']}"
            nodes.append({"id": node_id, "kind": kind, "label": record["name"], "status": record["state"], "path": record["path"], "characteristics": record, **record["storage"]})
            edges.append({"id": f"edge:{node_id}", "kind": f"{kind}-artifact", "source": node_id, "target": f"artifact:{record['projectKey']}", "characteristics": {}})
    result = validate_named_record({
        "schema": "klibgen.inventory/2", "schemaVersion": 2, "operation": "inventory",
        "generatedAt": datetime.now(timezone.utc).isoformat(), "nodes": nodes, "edges": edges, "warnings": [],
        "stateRoot": str(v2.root), "recipes": recipes, "targets": targets,
        "artifacts": artifacts,
        "references": references,
        "workspaces": workspaces,
        "stagingAreas": staging_areas,
        "activeSessions": _records(v2.root / "sessions", "*/session.json"),
        "statuses": _records(v2.root / "status", "*.json"),
        "locks": [str(path) for path in sorted((v2.root / "locks").rglob("*.lock"))],
        "storage": _size(v2.root),
    })
    logger.info("inventory complete artifacts=%d workspaces=%d stagingAreas=%d", len(artifacts), len(workspaces), len(staging_areas))
    return result


def _root_keys(v2: V2Paths) -> tuple[set[str], list[str]]:
    keys: set[str] = set()
    warnings: list[str] = []
    patterns = (
        (v2.root / "refs", "*.json", "outputKey"),
        (v2.root / "workspaces", "*/workspace.json", "projectKey"),
        (v2.root / "staging", "*/staging.json", "projectKey"),
        (v2.root / "sessions", "*/session.json", "projectKey"),
        (v2.root / "pins", "*.json", "outputKey"),
    )
    for root, pattern, field in patterns:
        for path in root.glob(pattern) if root.is_dir() else ():
            try:
                value = json.loads(path.read_text(encoding="utf-8"))
                key = value[field]
                if not isinstance(key, str) or len(key) != 64:
                    raise ValueError(f"invalid {field}")
                keys.add(key)
            except (OSError, KeyError, ValueError, json.JSONDecodeError) as error:
                warnings.append(f"protected malformed root {path}: {error}")
    return keys, warnings


def garbage_collect(paths: BuildPaths, apply: bool = False) -> dict[str, Any]:
    logger.info("planning garbage collection mode=%s", "apply" if apply else "dry-run")
    v2 = V2Paths.for_build(paths)
    v2.initialize()
    roots, warnings = _root_keys(v2)
    manifests: dict[str, dict[str, Any]] = {}
    for manifest_path in (v2.root / "store").glob("*/*/*/manifest.json"):
        try:
            value = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifests[value["outputKey"]] = value
        except (OSError, KeyError, json.JSONDecodeError) as error:
            warnings.append(f"protected malformed artifact {manifest_path.parent}: {error}")
    for key in tuple(roots):
        manifest = manifests.get(key)
        if manifest:
            roots.update(
                step["outputKey"] for step in manifest.get("resolvedRecipe", {}).get("steps", [])
                if step.get("checkpoint") == "artifact"
            )
    remove: list[Path] = []
    for artifact in (v2.root / "store").glob("*/*/*"):
        if artifact.is_dir() and artifact.name not in roots:
            remove.append(artifact)
    for session in (v2.root / "sessions").glob("*"):
        if session.is_dir():
            try:
                manifest = json.loads((session / "session.json").read_text(encoding="utf-8"))
                pid = manifest.get("pid")
                active = isinstance(pid, int) and pid > 1 and Path(f"/proc/{pid}").exists()
                if not active:
                    remove.append(session)
            except (OSError, json.JSONDecodeError):
                warnings.append(f"protected malformed session {session}")
    remove.extend(path for path in (v2.root / "tmp").glob("*") if path.exists())
    unique = sorted(set(remove), key=str)
    if apply and not warnings:
        for path in unique:
            v2.remove_tree(path)
        logger.info("garbage collection removed paths=%d", len(unique))
    elif apply and warnings:
        logger.warning("garbage collection withheld removals warnings=%d", len(warnings))
    elif warnings:
        logger.warning("garbage collection found protected malformed roots warnings=%d", len(warnings))
    return validate_named_record({
        "schema": "klibgen.gc-plan/1", "schemaVersion": 1, "operation": "gc",
        "mode": "apply" if apply else "dry-run", "roots": sorted(roots),
        "remove": [{"path": str(path), "storage": _size(path)} for path in unique],
        "warnings": warnings, "applied": bool(apply and not warnings),
    })


__all__ = ["garbage_collect", "inventory", "prune"]
