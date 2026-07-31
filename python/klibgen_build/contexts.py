from __future__ import annotations

import copy
import json
import shutil
from pathlib import Path
from typing import Any

from .core import BuildPaths, load_context
from .runs import process_is_alive
from .processes import run_command


def generated_context_file(paths: BuildPaths, context_id: str) -> Path:
    return paths.state / "contexts" / f"{context_id}.json"


def list_contexts(paths: BuildPaths) -> dict[str, Any]:
    values = []
    files = list((paths.root / "build/contexts").glob("*.json"))
    files += list((paths.state / "contexts").glob("*.json"))
    for path in sorted(files, key=lambda item: item.stem):
        value = json.loads(path.read_text(encoding="utf-8"))
        values.append({"contextId": value["contextId"], "definition": str(path), "generated": paths.state in path.parents, "project": value["project"]})
    return {"schemaVersion": 1, "operation": "context-list", "contexts": values}


def create_context(paths: BuildPaths, context_id: str, revision: str, template_id: str) -> dict[str, Any]:
    if not context_id.replace("-", "").replace("_", "").isalnum():
        raise ValueError("context ID must contain only letters, digits, '-' or '_'")
    destination_file = generated_context_file(paths, context_id)
    if paths.context_file(context_id).is_file():
        raise ValueError(f"context already exists: {context_id}")
    template = copy.deepcopy(load_context(paths, template_id))
    workspace = paths.state / "workspaces" / context_id
    workspace.parent.mkdir(parents=True, exist_ok=True)
    run_command(["jj", "-R", paths.root, "workspace", "add", workspace, "--name", context_id, "-r", revision])
    template["contextId"] = context_id
    template["project"] = {"vcs": "jj", "workspace": str(workspace), "revision": "@"}
    destination_file.parent.mkdir(parents=True, exist_ok=True)
    destination_file.write_text(json.dumps(template, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return {"schemaVersion": 1, "operation": "context-create", "contextId": context_id, "workspace": str(workspace), "definition": str(destination_file)}


def remove_context(paths: BuildPaths, context_id: str) -> dict[str, Any]:
    context_file = generated_context_file(paths, context_id)
    if not context_file.is_file():
        raise ValueError("only generated contexts can be removed")
    for metadata_path in (paths.state / "runs" / context_id).glob("*/run.json"):
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        if process_is_alive(metadata.get("pid")):
            raise ValueError(f"context has active run {metadata['runId']}")
    if any((paths.state / "snapshots" / context_id).glob("*/snapshot.json")):
        raise ValueError("context has snapshots")
    if any((paths.state / "worktree-metadata" / context_id).glob("*.json")):
        raise ValueError("remove attached Git worktrees first")
    context = json.loads(context_file.read_text(encoding="utf-8"))
    workspace = Path(context["project"]["workspace"])
    changes = run_command(
        ["jj", "-R", str(workspace), "diff", "--summary", "-r", "@"],
    ).stdout
    if changes.strip():
        raise ValueError("JJ workspace has unpromoted file changes")
    run_command(["jj", "-R", paths.root, "workspace", "forget", context_id])
    if workspace.exists():
        shutil.rmtree(workspace)
    context_file.unlink()
    return {"schemaVersion": 1, "operation": "context-remove", "contextId": context_id, "removed": True}


def add_git_worktree(paths: BuildPaths, context_id: str, role: str, repository: str, revision: str) -> dict[str, Any]:
    if role not in {"gt", "sqlite3"}:
        raise ValueError("role must be 'gt' or 'sqlite3'")
    context_file = generated_context_file(paths, context_id)
    if not context_file.is_file():
        raise ValueError("Git worktrees can be attached only to generated contexts")
    metadata_file = paths.state / "worktree-metadata" / context_id / f"{role}.json"
    if metadata_file.exists():
        raise ValueError(f"context already has {role} worktree metadata")
    repository_path = Path(repository).resolve()
    worktree = paths.state / "worktrees" / context_id / role
    worktree.parent.mkdir(parents=True, exist_ok=True)
    run_command(["git", "-C", repository_path, "worktree", "add", "--detach", worktree, revision])
    commit = run_command(["git", "-C", worktree, "rev-parse", "HEAD"]).stdout.strip()
    context = json.loads(context_file.read_text(encoding="utf-8"))
    if role == "gt":
        context["layers"]["L03"] = {"variant": "klibgen", "worktree": str(worktree)}
    else:
        context["layers"]["L04"].setdefault("dependencyOverrides", {})["sqlite3"] = {"worktree": str(worktree)}
    context_file.write_text(json.dumps(context, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    metadata = {"schemaVersion": 1, "contextId": context_id, "role": role, "repository": str(repository_path), "worktree": str(worktree), "commit": commit}
    metadata_file.parent.mkdir(parents=True, exist_ok=True)
    metadata_file.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return {"schemaVersion": 1, "operation": "worktree-add"} | metadata


def remove_git_worktree(paths: BuildPaths, context_id: str, role: str) -> dict[str, Any]:
    metadata_file = paths.state / "worktree-metadata" / context_id / f"{role}.json"
    if not metadata_file.is_file():
        raise ValueError(f"no attached {role} worktree for context {context_id}")
    metadata = json.loads(metadata_file.read_text(encoding="utf-8"))
    status = run_command(["git", "-C", metadata["worktree"], "status", "--porcelain"]).stdout
    if status.strip():
        raise ValueError(f"{role} worktree is dirty")
    run_command(["git", "-C", metadata["repository"], "worktree", "remove", metadata["worktree"]])
    context_file = generated_context_file(paths, context_id)
    context = json.loads(context_file.read_text(encoding="utf-8"))
    if role == "gt":
        context["layers"]["L03"] = {"variant": "baseline"}
    else:
        context["layers"]["L04"].get("dependencyOverrides", {}).pop("sqlite3", None)
        if not context["layers"]["L04"].get("dependencyOverrides"):
            context["layers"]["L04"].pop("dependencyOverrides", None)
    context_file.write_text(json.dumps(context, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    metadata_file.unlink()
    return {"schemaVersion": 1, "operation": "worktree-remove", "contextId": context_id, "role": role, "removed": True}
