from __future__ import annotations

import fcntl
import hashlib
import json
import os
import shutil
import uuid
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator, Mapping

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


def _contents(root: Path) -> dict[str, bytes]:
    if not root.is_dir():
        return {}
    return {
        path.relative_to(root).as_posix(): path.read_bytes()
        for path in sorted(root.rglob("*"))
        if path.is_file() and ".git" not in path.parts
    }


def _files(root: Path) -> dict[str, str]:
    return {
        relative: hashlib.sha256(contents).hexdigest()
        for relative, contents in _contents(root).items()
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


def _source(paths: BuildPaths, target: str = "agentic") -> tuple[dict[str, Any], str]:
    resolved = resolve_target(paths, target)
    source = next(
        step for step in resolved["steps"] if step["role"] == "project-source"
    )["resolvedConfiguration"]["source"]
    return source, resolved["outputKey"]


def _git_head(area: Path) -> str:
    return run_command(["git", "-C", area / "overlay", "rev-parse", "HEAD"]).stdout.strip()


def _write_contents(root: Path, contents: Mapping[str, bytes]) -> None:
    root.mkdir(parents=True)
    for relative, value in contents.items():
        destination = root / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(value)


def _replace_trees(replacements: list[tuple[Path, Path]]) -> None:
    """Replace directories and restore every original if any rename fails."""
    transaction = uuid.uuid4().hex
    backups: list[tuple[Path, Path]] = []
    installed: list[Path] = []
    try:
        for destination, prepared in replacements:
            backup = destination.with_name(f".{destination.name}.{transaction}.backup")
            if destination.exists():
                os.replace(destination, backup)
                backups.append((destination, backup))
            os.replace(prepared, destination)
            installed.append(destination)
    except Exception:
        for destination in reversed(installed):
            if destination.exists():
                shutil.rmtree(destination)
        for destination, backup in reversed(backups):
            if backup.exists():
                os.replace(backup, destination)
        raise
    for _destination, backup in backups:
        shutil.rmtree(backup)


def _commit_overlay(area: Path, message: str) -> str:
    run_command(["git", "-C", area / "overlay", "add", "-A", ".project", "src"])
    status = run_command(["git", "-C", area / "overlay", "status", "--porcelain"]).stdout
    if status:
        run_command([
            "git", "-C", area / "overlay", "-c", "user.name=KlibGen Staging",
            "-c", "user.email=staging@localhost", "commit", "--quiet", "-m", message,
        ])
    return _git_head(area)


def _initial_record(
    name: str,
    area: Path,
    source: dict[str, Any],
    project_key: str,
    head: str,
) -> dict[str, Any]:
    return {
        "schema": "klibgen.staging/1", "schemaVersion": 1, "name": name,
        "state": "ready", "baseSource": source, "projectKey": project_key,
        "sourceGit": str(area / "overlay/.git"), "promotion": None,
        "generation": 1, "headCommit": head, "lease": None,
        "lastRebase": None, "lastPromotion": None,
    }


def create_staging(paths: BuildPaths, name: str) -> dict[str, Any]:
    v2 = V2Paths.for_build(paths)
    v2.initialize()
    area = _path(paths, name)
    with _lock(v2, name):
        if area.exists():
            raise ValueError(f"staging area {name!r} already exists")
        source, project_key = _source(paths)
        (area / "base").mkdir(parents=True)
        shutil.copytree(paths.root / "src", area / "base/src")
        shutil.copytree(paths.root / "src", area / "overlay/src")
        (area / "overlay/.project").write_text("{\n\t'srcDirectory' : 'src'\n}\n", encoding="utf-8")
        run_command(["git", "init", "--quiet", "--initial-branch=master", area / "overlay"])
        head = _commit_overlay(area, "Initialize staging area")
        value = _initial_record(name, area, source, project_key, head)
        atomic_json(area / "staging.json", value)
    return validate_named_record({
        "schema": "klibgen.staging-result/1", "schemaVersion": 1,
        "operation": "staging.create", "staging": value, "path": str(area),
    })


def migrate_staging(
    paths: BuildPaths,
    name: str,
    source_repository: Path,
    base_source: dict[str, Any],
    project_key: str,
) -> dict[str, Any]:
    """Import a legacy GUI Git repository without altering or removing it."""
    v2 = V2Paths.for_build(paths)
    v2.initialize()
    area = _path(paths, name)
    with _lock(v2, name):
        if area.exists():
            return _record(area)
        source_repository = source_repository.resolve()
        if not (source_repository / ".git").exists():
            raise ValueError(f"legacy GUI source repository is missing: {source_repository}")
        area.mkdir(parents=True)
        shutil.copytree(source_repository, area / "overlay", symlinks=True)
        root_commit = run_command([
            "git", "-C", source_repository, "rev-list", "--max-parents=0", "HEAD",
        ]).stdout.splitlines()[0]
        temporary = area / f".migration-{uuid.uuid4().hex}"
        run_command(["git", "clone", "--quiet", "--no-hardlinks", source_repository, temporary])
        try:
            run_command(["git", "-C", temporary, "checkout", "--quiet", root_commit])
            (area / "base").mkdir()
            shutil.copytree(temporary / "src", area / "base/src")
        finally:
            shutil.rmtree(temporary, ignore_errors=True)
        head = _git_head(area)
        value = _initial_record(name, area, base_source, project_key, head)
        value["lastRebase"] = {"ok": True, "migration": "workspace-private-git"}
        atomic_json(area / "staging.json", value)
        return value


def staging_changes(paths: BuildPaths, name: str) -> dict[str, Any]:
    area = _path(paths, name)
    base, overlay = _files(area / "base/src"), _files(area / "overlay/src")
    additions = sorted(overlay.keys() - base.keys())
    removals = sorted(base.keys() - overlay.keys())
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
    return {
        "additions": additions, "modifications": modifications,
        "removals": removals, "renames": renames, "prohibited": prohibited,
    }


def _merge_contents(
    base: Mapping[str, bytes], overlay: Mapping[str, bytes], current: Mapping[str, bytes],
) -> tuple[dict[str, bytes], list[str]]:
    result: dict[str, bytes] = {}
    conflicts: list[str] = []
    missing = object()
    for relative in sorted(base.keys() | overlay.keys() | current.keys()):
        old = base.get(relative, missing)
        staged = overlay.get(relative, missing)
        authoritative = current.get(relative, missing)
        if staged == old:
            selected = authoritative
        elif authoritative == old or staged == authoritative:
            selected = staged
        else:
            conflicts.append(relative)
            continue
        if selected is not missing:
            result[relative] = selected  # type: ignore[assignment]
    return result, conflicts


def _reconcile_head_locked(area: Path, record: dict[str, Any]) -> dict[str, Any]:
    head = _git_head(area)
    if record.get("headCommit") != head:
        record["headCommit"] = head
        record["generation"] = int(record.get("generation", 0)) + 1
        record["state"] = "ready"
        atomic_json(area / "staging.json", record)
    return record


def _rebase_locked(paths: BuildPaths, area: Path, record: dict[str, Any]) -> dict[str, Any]:
    record = _reconcile_head_locked(area, record)
    base = _contents(area / "base/src")
    overlay = _contents(area / "overlay/src")
    current = _contents(paths.root / "src")
    if base == current:
        if record.get("state") == "conflicted":
            record["state"] = "ready"
            record["lastRebase"] = {"ok": True, "conflicts": []}
            atomic_json(area / "staging.json", record)
        return record
    merged, conflicts = _merge_contents(base, overlay, current)
    if conflicts:
        record["state"] = "conflicted"
        record["lastRebase"] = {"ok": False, "conflicts": conflicts}
        atomic_json(area / "staging.json", record)
        return record
    source, project_key = _source(paths)
    prepared_base = area / f".base-{uuid.uuid4().hex}"
    prepared_overlay = area / f".overlay-{uuid.uuid4().hex}"
    _write_contents(prepared_base, current)
    _write_contents(prepared_overlay, merged)
    try:
        _replace_trees([
            (area / "base/src", prepared_base),
            (area / "overlay/src", prepared_overlay),
        ])
        head = _commit_overlay(area, "Rebase staging area onto canonical source")
    except Exception:
        shutil.rmtree(prepared_base, ignore_errors=True)
        shutil.rmtree(prepared_overlay, ignore_errors=True)
        rollback_base = area / f".base-rollback-{uuid.uuid4().hex}"
        rollback_overlay = area / f".overlay-rollback-{uuid.uuid4().hex}"
        _write_contents(rollback_base, base)
        _write_contents(rollback_overlay, overlay)
        _replace_trees([
            (area / "base/src", rollback_base),
            (area / "overlay/src", rollback_overlay),
        ])
        run_command(["git", "-C", area / "overlay", "reset", "--mixed", "HEAD"], check=False)
        raise
    record.update({
        "state": "ready", "baseSource": source, "projectKey": project_key,
        "headCommit": head, "generation": int(record.get("generation", 0)) + 1,
        "lastRebase": {"ok": True, "conflicts": []},
    })
    atomic_json(area / "staging.json", record)
    return record


def rebase_staging(paths: BuildPaths, name: str) -> dict[str, Any]:
    v2 = V2Paths.for_build(paths)
    area = _path(paths, name)
    with _lock(v2, name):
        record = _rebase_locked(paths, area, _record(area))
        if record["state"] == "conflicted":
            conflicts = record["lastRebase"]["conflicts"]
            raise ValueError("staging rebase conflicts with authoritative source: " + ", ".join(conflicts))
        changes = staging_changes(paths, name)
    return validate_named_record({
        "schema": "klibgen.staging-result/1", "schemaVersion": 1,
        "operation": "staging.rebase", "staging": record,
        "changes": changes, "path": str(area),
    })


def _pid_alive(pid: Any) -> bool:
    return isinstance(pid, int) and pid > 0 and Path(f"/proc/{pid}").exists()


def acquire_staging_lease(
    paths: BuildPaths,
    name: str,
    context_kind: str,
    context_id: str,
    pid: int,
    *,
    session_id: str | None = None,
) -> dict[str, Any]:
    v2 = V2Paths.for_build(paths)
    area = _path(paths, name)
    with _lock(v2, name):
        record = _record(area)
        lease = record.get("lease")
        same_context = lease and lease.get("contextKind") == context_kind and lease.get("contextId") == context_id
        if lease and not same_context and (lease.get("reserved") or _pid_alive(lease.get("pid"))):
            owner = f"{lease.get('contextKind')} {lease.get('contextId')}"
            raise RuntimeError(f"staging area {name!r} is exclusively owned by {owner}")
        if not (lease and same_context and lease.get("reserved")):
            record = _rebase_locked(paths, area, record)
        if record["state"] == "conflicted":
            raise ValueError(f"staging area {name!r} is conflicted; resolve or reset it before attachment")
        record["lease"] = {
            "contextKind": context_kind, "contextId": context_id, "pid": pid,
            "generation": record.get("generation", 1), "reserved": False,
            "sessionId": session_id or context_id,
        }
        atomic_json(area / "staging.json", record)
        return record


def validate_staging_lease(paths: BuildPaths, name: str, context_id: str) -> dict[str, Any]:
    area = _path(paths, name)
    record = _record(area)
    lease = record.get("lease")
    if not lease or lease.get("sessionId", lease.get("contextId")) != context_id:
        raise RuntimeError(f"session {context_id!r} does not own staging area {name!r}")
    return record


def release_staging_lease(
    paths: BuildPaths,
    name: str,
    context_id: str,
    *,
    source_change_count: int = 0,
) -> dict[str, Any]:
    v2 = V2Paths.for_build(paths)
    area = _path(paths, name)
    with _lock(v2, name):
        record = _reconcile_head_locked(area, _record(area))
        lease = record.get("lease")
        if lease and context_id in {lease.get("contextId"), lease.get("sessionId")}:
            if source_change_count:
                record["lease"] = lease | {
                    "pid": None, "reserved": True,
                    "sourceChangeCount": source_change_count,
                    "generation": record.get("generation", 1),
                }
            else:
                record["lease"] = None
            atomic_json(area / "staging.json", record)
        return record


def reconcile_staging(paths: BuildPaths, name: str, context_id: str | None = None) -> dict[str, Any]:
    v2 = V2Paths.for_build(paths)
    area = _path(paths, name)
    with _lock(v2, name):
        record = _record(area)
        if context_id is not None:
            lease = record.get("lease")
            if not lease or context_id not in {lease.get("contextId"), lease.get("sessionId")}:
                raise RuntimeError(f"session {context_id!r} does not own staging area {name!r}")
        return _reconcile_head_locked(area, record)


def list_staging(paths: BuildPaths) -> dict[str, Any]:
    v2 = V2Paths.for_build(paths)
    values = []
    if (v2.root / "staging").is_dir():
        for manifest in sorted((v2.root / "staging").glob("*/staging.json")):
            name = manifest.parent.name
            with _lock(v2, name):
                value = _reconcile_head_locked(manifest.parent, _record(manifest.parent))
            values.append(value | {"path": str(manifest.parent), "changes": staging_changes(paths, name)})
    return validate_named_record({
        "schema": "klibgen.staging-list/1", "schemaVersion": 1,
        "operation": "staging.list", "stagingAreas": values,
    })


def reset_staging(paths: BuildPaths, name: str) -> dict[str, Any]:
    v2 = V2Paths.for_build(paths)
    area = _path(paths, name)
    with _lock(v2, name):
        record = _record(area)
        lease = record.get("lease")
        if lease and (lease.get("reserved") or _pid_alive(lease.get("pid"))):
            raise RuntimeError(f"staging area {name!r} is leased and cannot be reset")
        v2.remove_tree(area)
    return create_staging(paths, name) | {"operation": "staging.reset"}


def _apply_authoritative_tree(paths: BuildPaths, contents: Mapping[str, bytes]) -> None:
    prepared = paths.root / f".src-promotion-{uuid.uuid4().hex}"
    _write_contents(prepared, contents)
    try:
        _replace_trees([(paths.root / "src", prepared)])
    finally:
        shutil.rmtree(prepared, ignore_errors=True)


def promote_staging(
    paths: BuildPaths,
    name: str,
    *,
    context_id: str | None = None,
) -> dict[str, Any]:
    v2 = V2Paths.for_build(paths)
    area = _path(paths, name)
    promotion_lock = v2.root / "locks/staging/promotion.lock"
    promotion_lock.parent.mkdir(parents=True, exist_ok=True)
    with promotion_lock.open("w") as promotion_stream, _lock(v2, name):
        fcntl.flock(promotion_stream, fcntl.LOCK_EX)
        record = _record(area)
        if context_id is not None:
            lease = record.get("lease")
            if not lease or context_id not in {lease.get("contextId"), lease.get("sessionId")}:
                raise RuntimeError(f"session {context_id!r} does not own staging area {name!r}")
        record = _rebase_locked(paths, area, record)
        if record["state"] == "conflicted":
            conflicts = record["lastRebase"]["conflicts"]
            raise ValueError("staging promotion conflicts with authoritative source: " + ", ".join(conflicts))
        changes = staging_changes(paths, name)
        if changes["prohibited"]:
            raise ValueError(
                "staging contains paths outside owned KlibGenGt packages: "
                + ", ".join(changes["prohibited"])
            )
        overlay = _contents(area / "overlay/src")
        authoritative_before = _contents(paths.root / "src")
        try:
            _apply_authoritative_tree(paths, overlay)
            source, project_key = _source(paths)
            prepared_base = area / f".base-{uuid.uuid4().hex}"
            _write_contents(prepared_base, overlay)
            _replace_trees([(area / "base/src", prepared_base)])
        except Exception as error:
            if _contents(paths.root / "src") != authoritative_before:
                _apply_authoritative_tree(paths, authoritative_before)
            record["lastPromotion"] = {"ok": False, "error": str(error)}
            atomic_json(area / "staging.json", record)
            raise
        promotion = {"ok": True, "changes": changes}
        record.update({
            "state": "promoted", "baseSource": source, "projectKey": project_key,
            "promotion": promotion, "lastPromotion": promotion,
        })
        atomic_json(area / "staging.json", record)
    return validate_named_record({
        "schema": "klibgen.staging-result/1", "schemaVersion": 1,
        "operation": "staging.promote", "staging": record,
        "changes": changes, "path": str(area),
    })


__all__ = [
    "acquire_staging_lease", "create_staging", "list_staging", "migrate_staging",
    "promote_staging", "rebase_staging", "reconcile_staging", "release_staging_lease",
    "reset_staging", "staging_changes", "validate_staging_lease", "validate_staging_name",
]
