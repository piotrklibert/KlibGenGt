"""Verify that source already has the exact representation Tonel will export."""

from __future__ import annotations

import difflib
import json
import logging
import os
import shutil
import uuid
from pathlib import Path
from typing import Any

from .core import BuildPaths
from .processes import run_command


logger = logging.getLogger(__name__)


def _sources(root: Path) -> dict[str, bytes]:
    return {
        path.relative_to(root).as_posix(): path.read_bytes()
        for path in sorted(root.rglob("*.st"))
        if path.is_file()
    }


def tonel_drift(source_root: Path, exported_root: Path) -> list[dict[str, str]]:
    """Return exact `.st` differences introduced by a Tonel round trip."""
    source = _sources(source_root)
    exported = _sources(exported_root)
    drift: list[dict[str, str]] = []
    for relative in sorted(source.keys() | exported.keys()):
        before = source.get(relative)
        after = exported.get(relative)
        if before == after:
            continue
        if before is None:
            kind = "added-by-export"
        elif after is None:
            kind = "missing-from-export"
        else:
            kind = "changed-by-export"
        before_text = b"" if before is None else before
        after_text = b"" if after is None else after
        difference = "".join(difflib.unified_diff(
            before_text.decode("utf-8", errors="replace").splitlines(keepends=True),
            after_text.decode("utf-8", errors="replace").splitlines(keepends=True),
            fromfile=f"source/{relative}",
            tofile=f"tonel/{relative}",
            n=3,
        ))
        drift.append({"path": relative, "kind": kind, "diff": difference})
    return drift


def verify_tonel_roundtrip(source_root: Path, exported_root: Path) -> int:
    """Reject source whose exact bytes differ from the pinned Tonel export."""
    drift = tonel_drift(source_root, exported_root)
    if drift:
        logger.error("Tonel round trip changed files=%d source=%s", len(drift), source_root)
        paths = ", ".join(item["path"] for item in drift[:20])
        if len(drift) > 20:
            paths += f", ... and {len(drift) - 20} more files"
        details = "\n".join(item["diff"] for item in drift[:5] if item["diff"])
        suffix = "" if len(drift) <= 5 else f"\n... and {len(drift) - 5} more files"
        raise ValueError(
            "Tonel source is not canonical; an export would rewrite: " + paths
            + ("\n" + details if details else "") + suffix
        )
    count = len(_sources(source_root))
    logger.info("Tonel round trip is canonical files=%d", count)
    return count


def apply_tonel_roundtrip(
    source_root: Path,
    exported_root: Path,
    *,
    expected_source_root: Path | None = None,
) -> list[dict[str, str]]:
    """Apply exact exported `.st` additions, changes, and removals with rollback."""
    if expected_source_root is not None and _sources(source_root) != _sources(expected_source_root):
        raise RuntimeError("authoritative Tonel source changed while its fix was being prepared; retry")
    drift = tonel_drift(source_root, exported_root)
    originals = {
        item["path"]: (source_root / item["path"]).read_bytes()
        if (source_root / item["path"]).is_file() else None
        for item in drift
    }
    temporaries: list[Path] = []
    try:
        for item in drift:
            relative = item["path"]
            target = source_root / relative
            exported = exported_root / relative
            if item["kind"] == "missing-from-export":
                target.unlink()
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            temporary = target.with_name(f".{target.name}.{uuid.uuid4().hex}.tmp")
            temporaries.append(temporary)
            temporary.write_bytes(exported.read_bytes())
            os.replace(temporary, target)
    except Exception:
        logger.error("rolling back Tonel source fix source=%s", source_root)
        logger.debug("Tonel source fix exception", exc_info=True)
        for relative, contents in originals.items():
            target = source_root / relative
            if contents is None:
                target.unlink(missing_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(contents)
        raise
    finally:
        for temporary in temporaries:
            temporary.unlink(missing_ok=True)
    logger.info("applied canonical Tonel export files=%d source=%s", len(drift), source_root)
    return drift


def export_tonel_source(
    paths: BuildPaths, source_git: Path, artifact: Path, exported: Path,
) -> None:
    """Load and export one Git source tree with the pinned image and Tonel writer."""
    source_git = source_git.resolve()
    source_root = source_git.parent / "src"
    if not source_git.is_dir() or not source_root.is_dir():
        raise ValueError(f"Tonel lint source repository is missing: {source_git}")
    temporary_root = paths.root / "tmp" / f"tonel-lint-{uuid.uuid4().hex}"
    logger.debug("exporting Tonel for lint source=%s workspace=%s", source_root, temporary_root)
    payload = temporary_root / "payload"
    try:
        temporary_root.mkdir(parents=True)
        run_command(["cp", "-a", "--reflink=auto", artifact / "payload", payload])
        from .canonical import _dependency_environment, _run_image, _set_writable

        artifact_manifest = json.loads(
            (artifact / "manifest.json").read_text(encoding="utf-8")
        )
        dependency_step = next(
            step for step in artifact_manifest["resolvedRecipe"]["steps"]
            if step["role"] == "project-dependencies"
        )

        _set_writable(payload)
        try:
            environment = _dependency_environment(paths, dependency_step)
            environment.update({
                "KLIBGEN_EXPORT_GIT": str(source_git),
                "KLIBGEN_TONEL_OUTPUT": str(exported),
            })
            _run_image(
                paths, payload, paths.root / "build/v2/scripts/load-project-source.st",
                "source-lint", environment,
            )
        except RuntimeError as error:
            log = temporary_root / "logs/source-lint.log"
            detail = log.read_text(encoding="utf-8", errors="replace")[-8000:] if log.is_file() else str(error)
            raise RuntimeError("Tonel source load/export failed:\n" + detail) from error
    finally:
        shutil.rmtree(temporary_root, ignore_errors=True)


def lint_git_source(paths: BuildPaths, source_git: Path, artifact: Path) -> dict[str, Any]:
    """Round-trip one attached Git source tree in an isolated artifact copy."""
    source_git = source_git.resolve()
    source_root = source_git.parent / "src"
    exported = paths.root / "tmp" / f"tonel-output-{uuid.uuid4().hex}"
    logger.info("checking staged Tonel source repository=%s", source_git.parent.name)
    try:
        export_tonel_source(paths, source_git, artifact, exported)
        count = verify_tonel_roundtrip(source_root, exported)
        return {
            "schemaVersion": 1, "ok": True, "operation": "source.lint",
            "sourceGit": str(source_git), "fileCount": count,
        }
    finally:
        shutil.rmtree(exported, ignore_errors=True)


def lint_authoritative_source(paths: BuildPaths, *, fix: bool = False) -> dict[str, Any]:
    """Build through the source gate and report the checked authoritative tree."""
    from .canonical import _git_bridge, build_canonical

    logger.info("checking authoritative Tonel source fix=%s", fix)
    if fix:
        setup = build_canonical(paths, "cli", through="project-setup")
        artifact = Path(setup["artifacts"][-1]["path"])
        temporary = paths.root / "tmp" / f"tonel-fix-{uuid.uuid4().hex}"
        exported = temporary / "exported"
        bridge: Path | None = None
        try:
            temporary.mkdir(parents=True)
            bridge = _git_bridge(paths, temporary, ("src",))
            export_tonel_source(paths, bridge / ".git", artifact, exported)
            drift = apply_tonel_roundtrip(
                paths.root / "src", exported, expected_source_root=bridge / "src",
            )
            verify_tonel_roundtrip(paths.root / "src", exported)
        finally:
            shutil.rmtree(temporary, ignore_errors=True)
    else:
        drift = []
    build = build_canonical(paths, "cli")
    return {
        "schemaVersion": 1, "ok": True, "operation": "source.lint",
        "sourceRoot": str(paths.root / "src"),
        "fileCount": len(_sources(paths.root / "src")),
        "fixedFileCount": len(drift),
        "fixedPaths": [item["path"] for item in drift],
        "outputKey": build["outputKey"],
    }


__all__ = [
    "apply_tonel_roundtrip", "export_tonel_source", "lint_authoritative_source",
    "lint_git_source", "tonel_drift", "verify_tonel_roundtrip",
]
