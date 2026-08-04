from __future__ import annotations

import json
import shutil
from pathlib import Path
from typing import Any, Callable

import click

from . import cli
from .common import JSON_OPTION, _paths, _run
from ..core import BuildPaths, platform_id
from ..inventory_v2 import garbage_collect, inventory, prune
from ..registered_tools import export_build_map_pngs
from ..v2state import V2Paths
from ..workspaces import workspace_status


def _doctor(paths: BuildPaths) -> dict[str, Any]:
    tools = [{"name": name, "path": shutil.which(name), "ok": shutil.which(name) is not None} for name in ("git", "jj", "uv", "unzip")]
    checks = [{"path": str(path), "ok": path.exists()} for path in (paths.root / "src", paths.vendor / "gt.zip", paths.root / "build/locks/default.lock.json")]
    return {"schema": "klibgen.doctor/1", "schemaVersion": 1, "operation": "doctor", "ok": all(item["ok"] for item in tools + checks), "platform": platform_id(), "stateRoot": str(V2Paths.for_build(paths).root), "tools": tools, "checks": checks}


def _status(paths: BuildPaths) -> dict[str, Any]:
    v2 = V2Paths.for_build(paths)
    statuses = [json.loads(path.read_text(encoding="utf-8")) for path in sorted((v2.root / "status").glob("*.json"))] if (v2.root / "status").is_dir() else []
    return {"schema": "klibgen.status-list/1", "schemaVersion": 1, "operation": "status", "statuses": statuses, "workspace": workspace_status(paths)}


def simple_result(name: str, help_text: str, operation: Callable[[], dict[str, Any]]) -> None:
    @cli.command(name, help=help_text)
    @JSON_OPTION
    @click.pass_context
    def command(ctx: click.Context, as_json: bool) -> None:
        _run(ctx, as_json, operation)


simple_result("doctor", "Check required host tools and committed project inputs.", lambda: _doctor(_paths()))
simple_result("status", "Report retained operation status and the named workspace state.", lambda: _status(_paths()))
simple_result("inventory", "Inventory recipes, storage, references, sessions, and mutable state.", lambda: inventory(_paths()))
simple_result("build-map", "Emit the complete structured build and storage relationship map.", lambda: inventory(_paths()))

@cli.command("gc")
@click.option("--dry-run", is_flag=True, help="Report removable paths without changing state (default).")
@click.option("--apply", is_flag=True, help="Remove only unrooted and abandoned state identified by GC.")
@JSON_OPTION
@click.pass_context
def gc(ctx: click.Context, dry_run: bool, apply: bool, as_json: bool) -> None:
    """Review garbage by default, or remove it with --apply."""
    def operation() -> dict[str, Any]:
        if dry_run and apply:
            raise ValueError("--dry-run and --apply are mutually exclusive")
        return garbage_collect(_paths(), apply=apply)
    _run(ctx, as_json, operation)


@cli.command("prune")
@JSON_OPTION
@click.pass_context
def prune_command(ctx: click.Context, as_json: bool) -> None:
    """Delete all generated state under the project-local .klibgen directory."""
    _run(ctx, as_json, lambda: prune(_paths()))


@cli.command("build-map-png")
@click.argument("output", required=False, type=click.Path(path_type=Path, file_okay=False), metavar="OUTPUT_DIR")
@click.option("--force", is_flag=True, help="Overwrite existing generated PNG exports.")
@JSON_OPTION
@click.pass_context
def build_map_png(ctx: click.Context, output: Path | None, force: bool, as_json: bool) -> None:
    """Render overview and full-graph PNG files in OUTPUT_DIR."""
    _run(ctx, as_json, lambda: export_build_map_pngs(_paths(), output, force))
