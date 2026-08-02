from __future__ import annotations

import fcntl
import json
import os
import shutil
import stat
import uuid
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

from .core import BuildPaths, digest_json, platform_id
from .json_models import parse_named_record, validate_named_record
from .v2state import V2Paths


def atomic_json(path: Path, value: dict[str, Any]) -> None:
    if "schema" in value:
        value = validate_named_record(value)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, path)


class ArtifactStore:
    def __init__(self, paths: BuildPaths):
        self.paths = paths
        self.v2 = V2Paths.for_build(paths)
        self.v2.initialize()

    def artifact(self, artifact_type: str, key: str) -> Path:
        if not artifact_type or "/" in artifact_type or len(key) != 64:
            raise ValueError("invalid artifact type or output key")
        return self.v2.root / "store" / artifact_type / platform_id() / key

    @contextmanager
    def key_lock(self, key: str) -> Iterator[None]:
        lock = self.v2.root / "locks" / "artifacts" / f"{key}.lock"
        lock.parent.mkdir(parents=True, exist_ok=True)
        with lock.open("w") as stream:
            fcntl.flock(stream, fcntl.LOCK_EX)
            yield

    def verify(self, artifact: Path) -> dict[str, Any]:
        manifest_path = artifact / "manifest.json"
        if not manifest_path.is_file():
            raise ValueError(f"artifact manifest is missing: {manifest_path}")
        manifest = parse_named_record(json.loads(manifest_path.read_text(encoding="utf-8"))).to_wire()
        if manifest.get("schema") != "klibgen.artifact/1":
            raise ValueError(f"unsupported artifact manifest: {manifest_path}")
        expected = self.artifact(manifest["artifactType"], manifest["outputKey"])
        if artifact.resolve() != expected.resolve():
            raise ValueError("artifact path does not match manifest type/platform/key")
        payload = artifact / "payload"
        records = []
        for path in sorted(payload.rglob("*")) if payload.is_dir() else []:
            if path.is_file() and not path.is_symlink():
                records.append([path.relative_to(payload).as_posix(), path.stat().st_size])
        if digest_json(records) != manifest["payloadShapeDigest"]:
            raise ValueError(f"artifact payload shape verification failed: {artifact}")
        return manifest

    def _make_read_only(self, target: Path) -> None:
        for path in sorted(target.rglob("*"), reverse=True):
            if not path.is_symlink():
                path.chmod(path.stat().st_mode & ~stat.S_IWUSR & ~stat.S_IWGRP & ~stat.S_IWOTH)
        target.chmod(target.stat().st_mode & ~stat.S_IWUSR & ~stat.S_IWGRP & ~stat.S_IWOTH)

    def publish_locked(self, workspace: Path, manifest: dict[str, Any]) -> tuple[Path, bool]:
        target = self.artifact(manifest["artifactType"], manifest["outputKey"])
        if target.exists():
            self.verify(target)
            shutil.rmtree(workspace, ignore_errors=True)
            return target, True
        payload = workspace / "payload"
        records = [
            [path.relative_to(payload).as_posix(), path.stat().st_size]
            for path in sorted(payload.rglob("*")) if path.is_file() and not path.is_symlink()
        ]
        manifest = dict(manifest) | {
            "schema": "klibgen.artifact/1", "schemaVersion": 1,
            "payloadShapeDigest": digest_json(records), "platform": platform_id(),
        }
        atomic_json(workspace / "manifest.json", manifest)
        target.parent.mkdir(parents=True, exist_ok=True)
        os.replace(workspace, target)
        self._make_read_only(target)
        return target, False

    def publish(self, workspace: Path, manifest: dict[str, Any]) -> tuple[Path, bool]:
        with self.key_lock(manifest["outputKey"]):
            return self.publish_locked(workspace, manifest)

    def write_reference(self, name: str, artifact_type: str, key: str) -> Path:
        if not name or "/" in name:
            raise ValueError(f"invalid reference name {name!r}")
        artifact = self.artifact(artifact_type, key)
        manifest = self.verify(artifact)
        path = self.v2.root / "refs" / f"{name}.json"
        atomic_json(path, {
            "schema": "klibgen.reference/1", "schemaVersion": 1, "name": name,
            "artifactType": artifact_type, "outputKey": key, "artifactPath": str(artifact),
            "producingRole": manifest["producingRole"],
        })
        return path

    def artifacts(self) -> list[dict[str, Any]]:
        values = []
        for manifest in sorted((self.v2.root / "store").glob("*/*/*/manifest.json")):
            try:
                value = self.verify(manifest.parent)
                values.append(value | {"path": str(manifest.parent), "valid": True})
            except (OSError, ValueError, json.JSONDecodeError) as error:
                values.append({"path": str(manifest.parent), "valid": False, "error": str(error)})
        return values


__all__ = ["ArtifactStore", "atomic_json"]
