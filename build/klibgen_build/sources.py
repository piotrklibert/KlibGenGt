from __future__ import annotations

import hashlib
import json
import platform
import subprocess
from pathlib import Path
from typing import Any

from .core import BuildPaths, read_json


SQLITE_SOURCE = "https://github.com/pharo-rdbms/Pharo-SQLite3.git"


def _pin(paths: BuildPaths, name: str) -> str:
    return (paths.root / ".tool-versions-or-lock" / name).read_text(encoding="utf-8").strip()


def resolve_git_head(source: str, branch: str) -> str:
    result = subprocess.run(
        ["git", "ls-remote", source, f"refs/heads/{branch}"],
        check=True,
        capture_output=True,
        text=True,
    )
    line = result.stdout.strip().splitlines()
    if len(line) != 1:
        raise ValueError(f"could not resolve {source} branch {branch}")
    commit = line[0].split()[0]
    if len(commit) != 40:
        raise ValueError(f"invalid Git commit returned for {source}: {commit}")
    return commit


def jj_identity(paths: BuildPaths, revision: str = "@") -> dict[str, Any]:
    result = subprocess.run(
        ["jj", "-R", str(paths.root), "log", "-r", revision, "--no-graph", "-T", "json(self)"],
        check=True,
        capture_output=True,
        text=True,
    )
    value = json.loads(result.stdout)
    summary = subprocess.run(
        ["jj", "-R", str(paths.root), "diff", "--summary", "-r", revision],
        check=True,
        capture_output=True,
        text=True,
    )
    return {
        "vcs": "jj",
        "revision": revision,
        "commitId": value["commit_id"],
        "changeId": value["change_id"],
        "parents": value["parents"],
        "bookmarks": value.get("bookmarks", []),
        "mutable": revision == "@",
        "changedPaths": [line for line in summary.stdout.splitlines() if line],
    }


def expected_lock(paths: BuildPaths, sqlite_commit: str) -> dict[str, Any]:
    gt_version = _pin(paths, "gt-version")
    installer_version = _pin(paths, "gt-installer-version")
    return {
        "schemaVersion": 1,
        "contextId": "default",
        "sources": [
            {
                "sourceId": "gt-release",
                "sourceType": "archive",
                "requested": {"version": gt_version},
                "resolved": {"url": _pin(paths, "gt-linux-x86_64.url")},
                "integrity": {"sha256": _pin(paths, "gt-linux-x86_64.sha256")},
            },
            {
                "sourceId": "gt-installer",
                "sourceType": "archive",
                "requested": {"version": installer_version},
                "resolved": {"url": _pin(paths, "gt-installer-linux-x86_64.url")},
                "integrity": {"sha256": _pin(paths, "gt-installer-linux-x86_64.sha256")},
            },
            {
                "sourceId": "sqlite3",
                "sourceType": "git",
                "source": SQLITE_SOURCE,
                "requested": {"branch": "master"},
                "resolved": {"commit": sqlite_commit},
                "integrity": {"treeHash": sqlite_commit},
            },
        ],
    }


def validate_lock(value: dict[str, Any]) -> None:
    if value.get("schemaVersion") != 1 or not isinstance(value.get("sources"), list):
        raise ValueError("lock must have schemaVersion 1 and a sources array")
    for source in value["sources"]:
        if source.get("sourceType") == "git":
            commit = source.get("resolved", {}).get("commit", "")
            if len(commit) != 40 or any(character not in "0123456789abcdef" for character in commit):
                raise ValueError(f"Git source {source.get('sourceId')} is not locked to a full commit")
        if source.get("sourceType") == "archive":
            checksum = source.get("integrity", {}).get("sha256", "")
            if len(checksum) != 64 or any(character not in "0123456789abcdef" for character in checksum):
                raise ValueError(f"archive source {source.get('sourceId')} lacks a SHA-256 lock")


def host_facts() -> dict[str, str]:
    return {"os": platform.system().lower(), "architecture": platform.machine().lower(), "python": platform.python_version()}
