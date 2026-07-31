from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Any

from .core import BuildPaths


def materialize_jj_source(paths: BuildPaths, identity: dict[str, Any], bridge: Path) -> str:
    revision = identity["commitId"]
    listing = subprocess.run(
        ["jj", "-R", str(paths.root), "file", "list", "-r", revision, "src"],
        check=True, capture_output=True, text=True,
    ).stdout.splitlines()
    for relative in listing:
        target = bridge / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        content = subprocess.run(
            ["jj", "-R", str(paths.root), "file", "show", "-r", revision, relative],
            check=True, capture_output=True,
        ).stdout
        target.write_bytes(content)
    (bridge / ".project").write_text("{\n\t'srcDirectory' : 'src'\n}\n", encoding="utf-8")
    subprocess.run(["git", "init", "--initial-branch=master", str(bridge)], check=True, capture_output=True)
    subprocess.run(["git", "-C", str(bridge), "add", "src", ".project"], check=True)
    subprocess.run([
        "git", "-C", str(bridge), "-c", "user.name=KlibGen Build",
        "-c", "user.email=build@localhost", "commit", "-m", f"Materialize JJ {revision}"
    ], check=True, capture_output=True)
    return subprocess.run(["git", "-C", str(bridge), "rev-parse", "HEAD"], check=True, capture_output=True, text=True).stdout.strip()
