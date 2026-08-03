from __future__ import annotations

from typing import Any

import click

from . import cli
from .common import ARTIFACT_KEY, JSON_OPTION, _paths, _run
from ..store import ArtifactStore


@cli.group()
def artifact() -> None:
    """List immutable artifacts or verify one exact store key."""


@artifact.command("list")
@JSON_OPTION
@click.pass_context
def artifact_list(ctx: click.Context, as_json: bool) -> None:
    """List artifacts currently present in the immutable store."""
    def operation() -> dict[str, Any]:
        store = ArtifactStore(_paths())
        return {"schema": "klibgen.artifact-list/1", "schemaVersion": 1, "operation": "artifact.list", "artifacts": store.artifacts()}
    _run(ctx, as_json, operation)


@artifact.command("verify")
@click.argument("key", type=ARTIFACT_KEY)
@JSON_OPTION
@click.pass_context
def artifact_verify(ctx: click.Context, key: str, as_json: bool) -> None:
    """Verify the unique immutable artifact identified by 64-hex KEY."""
    def operation() -> dict[str, Any]:
        store = ArtifactStore(_paths())
        matches = list((store.v2.root / "store").glob(f"*/*/{key}"))
        if len(matches) != 1:
            raise ValueError(f"expected one artifact for key {key!r}, found {len(matches)}")
        return {"schema": "klibgen.artifact-verification/1", "schemaVersion": 1, "operation": "artifact.verify", "path": str(matches[0]), "manifest": store.verify(matches[0]), "valid": True}
    _run(ctx, as_json, operation)


