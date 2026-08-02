from __future__ import annotations

import fcntl
import hashlib
import json
import shutil
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

from .core import BuildPaths
from .json_models import StagingV1, validate_named_record
from .processes import run_command
from .resolution import resolve_target
from .store import atomic_json
from .v2state import V2Paths


def validate_staging_name(name: str) -> str:
    if not name or not name.replace("-", "").replace("_", "").isalnum() or name[0] in "-_":
        raise ValueError(f"invalid staging name {name!r}")
    return name


def _files(root: Path) -> dict[str, str]:
    if not root.is_dir():
        return {}
    return {
        path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(root.rglob("*"))
        if path.is_file() and ".git" not in path.parts
    }


def _owned(relative: str) -> bool:
    parts = Path(relative).parts
    return len(parts) >= 2 and parts[0].startswith("KlibGenGt-")


@contextmanager
def _lock(v2: V2Paths, name: str) -> Iterator[None]:
    path = v2.root / "locks/staging" / f"{name}.lock"
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w") as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        yield


def _path(paths: BuildPaths, name: str) -> Path:
    return V2Paths.for_build(paths).root / "staging" / validate_staging_name(name)


def _record(area: Path) -> dict[str, Any]:
    manifest = area / "staging.json"
    if not manifest.is_file():
        raise ValueError(f"unknown staging area {area.name!r}")
    return StagingV1.model_validate_json(manifest.read_text(encoding="utf-8")).to_wire()


def create_staging(paths: BuildPaths, name: str) -> dict[str, Any]:
    v2 = V2Paths.for_build(paths)
    v2.initialize()
    area = _path(paths, name)
    with _lock(v2, name):
        if area.exists():
            raise ValueError(f"staging area {name!r} already exists")
        resolved = resolve_target(paths, "agentic")
        source = next(step for step in resolved["steps"] if step["role"] == "project-source")["resolvedConfiguration"]["source"]
        (area / "base").mkdir(parents=True)
        shutil.copytree(paths.root / "src", area / "base/src")
        shutil.copytree(paths.root / "src", area / "overlay/src")
        (area / "overlay/.project").write_text("{\n\t'srcDirectory' : 'src'\n}\n", encoding="utf-8")
        run_command(["git", "init", "--quiet", "--initial-branch=master", area / "overlay"])
        run_command(["git", "-C", area / "overlay", "add", ".project", "src"])
        run_command([
            "git", "-C", area / "overlay", "-c", "user.name=KlibGen Staging",
            "-c", "user.email=staging@localhost", "commit", "--quiet", "-m",
            "Initialize staging area",
        ])
        value = {
            "schema": "klibgen.staging/1", "schemaVersion": 1, "name": name,
            "state": "ready", "baseSource": source, "projectKey": resolved["outputKey"],
            "sourceGit": str(area / "overlay/.git"), "promotion": None,
        }
        atomic_json(area / "staging.json", value)
    return validate_named_record({"schema": "klibgen.staging-result/1", "schemaVersion": 1, "operation": "staging.create", "staging": value, "path": str(area)})


def staging_changes(paths: BuildPaths, name: str) -> dict[str, Any]:
    area = _path(paths, name)
    base, overlay = _files(area / "base/src"), _files(area / "overlay/src")
    additions = sorted(path for path in overlay.keys() - base.keys())
    removals = sorted(path for path in base.keys() - overlay.keys())
    renames = []
    for old in tuple(removals):
        matches = [new for new in additions if base[old] == overlay[new]]
        if matches:
            new = matches[0]
            renames.append({"from": old, "to": new})
            removals.remove(old)
            additions.remove(new)
    modifications = sorted(path for path in base.keys() & overlay.keys() if base[path] != overlay[path])
    changed_paths = additions + removals + modifications + [path for rename in renames for path in rename.values()]
    prohibited = sorted(path for path in changed_paths if not _owned(path))
    return {"additions": additions, "modifications": modifications, "removals": removals, "renames": renames, "prohibited": prohibited}


def list_staging(paths: BuildPaths) -> dict[str, Any]:
    v2 = V2Paths.for_build(paths)
    values = []
    if (v2.root / "staging").is_dir():
        for manifest in sorted((v2.root / "staging").glob("*/staging.json")):
            value = json.loads(manifest.read_text(encoding="utf-8"))
            values.append(value | {"path": str(manifest.parent), "changes": staging_changes(paths, value["name"])})
    return validate_named_record({"schema": "klibgen.staging-list/1", "schemaVersion": 1, "operation": "staging.list", "stagingAreas": values})


def reset_staging(paths: BuildPaths, name: str) -> dict[str, Any]:
    v2 = V2Paths.for_build(paths)
    area = _path(paths, name)
    with _lock(v2, name):
        _record(area)
        v2.remove_tree(area)
    return create_staging(paths, name) | {"operation": "staging.reset"}


def promote_staging(paths: BuildPaths, name: str) -> dict[str, Any]:
    v2 = V2Paths.for_build(paths)
    area = _path(paths, name)
    promotion_lock = v2.root / "locks/staging/promotion.lock"
    promotion_lock.parent.mkdir(parents=True, exist_ok=True)
    with promotion_lock.open("w") as promotion_stream, _lock(v2, name):
        fcntl.flock(promotion_stream, fcntl.LOCK_EX)
        record = _record(area)
        changes = staging_changes(paths, name)
        if changes["prohibited"]:
            raise ValueError("staging contains paths outside owned KlibGenGt packages: " + ", ".join(changes["prohibited"]))
        base = _files(area / "base/src")
        overlay = _files(area / "overlay/src")
        current = _files(paths.root / "src")
        renamed_from = [rename["from"] for rename in changes["renames"]]
        renamed_to = [rename["to"] for rename in changes["renames"]]
        changed = changes["additions"] + changes["modifications"] + changes["removals"] + renamed_from + renamed_to
        conflicts = sorted(path for path in changed if current.get(path) != base.get(path) and current.get(path) != overlay.get(path))
        if conflicts:
            record["state"] = "conflicted"
            record["promotion"] = {"ok": False, "conflicts": conflicts}
            atomic_json(area / "staging.json", record)
            raise ValueError("staging promotion conflicts with authoritative source: " + ", ".join(conflicts))
        for relative in changes["additions"] + changes["modifications"] + renamed_to:
            destination = paths.root / "src" / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(area / "overlay/src" / relative, destination)
        for relative in changes["removals"] + renamed_from:
            destination = paths.root / "src" / relative
            destination.unlink(missing_ok=True)
        record["state"] = "promoted"
        record["promotion"] = {"ok": True, "changes": changes}
        atomic_json(area / "staging.json", record)
    return validate_named_record({"schema": "klibgen.staging-result/1", "schemaVersion": 1, "operation": "staging.promote", "staging": record, "changes": changes, "path": str(area)})


__all__ = ["create_staging", "list_staging", "promote_staging", "reset_staging", "staging_changes", "validate_staging_name"]
