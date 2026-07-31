from __future__ import annotations

from pathlib import Path
from typing import Any

from .core import BuildPaths
from .processes import run_command


def materialize_jj_source(paths: BuildPaths, identity: dict[str, Any], bridge: Path) -> str:
    revision = identity["commitId"]
    listing = run_command(
        ["jj", "-R", str(paths.root), "file", "list", "-r", revision, "src"],
    ).stdout.splitlines()
    for relative in listing:
        target = bridge / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        content = run_command(
            ["jj", "-R", str(paths.root), "file", "show", "-r", revision, relative],
        ).stdout
        target.write_text(content, encoding="utf-8")
    (bridge / ".project").write_text("{\n\t'srcDirectory' : 'src'\n}\n", encoding="utf-8")
    run_command(["git", "init", "--initial-branch=master", bridge])
    run_command(["git", "-C", bridge, "add", "src", ".project"])
    run_command([
        "git", "-C", str(bridge), "-c", "user.name=KlibGen Build",
        "-c", "user.email=build@localhost", "commit", "-m", f"Materialize JJ {revision}"
    ])
    return run_command(["git", "-C", bridge, "rev-parse", "HEAD"]).stdout.strip()
