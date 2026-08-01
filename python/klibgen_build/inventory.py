from __future__ import annotations

import json
import os
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .artifacts import graph
from .coordination import retention_lock
from .core import BuildPaths, read_json
from .runs import process_is_alive


def _now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _identifier(kind: str, value: str) -> str:
    return f"{kind}:{value}"


def _path_identifier(kind: str, path: Path, root: Path) -> str:
    try:
        value = path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        value = str(path.resolve())
    return _identifier(kind, value)


def _size(path: Path, *, components: bool = True) -> dict[str, Any]:
    logical = allocated = files = 0
    warnings: list[str] = []

    def visit(item: Path) -> tuple[int, int, int]:
        item_logical = item_allocated = item_files = 0
        try:
            stat = item.lstat()
        except (FileNotFoundError, PermissionError, OSError) as error:
            warnings.append(f"could not stat {item}: {error}")
            return 0, 0, 0
        if item.is_symlink() or item.is_file():
            return stat.st_size, getattr(stat, "st_blocks", 0) * 512, 1
        if not item.is_dir():
            return 0, 0, 0
        try:
            children = sorted(item.iterdir(), key=lambda each: each.name)
        except (FileNotFoundError, PermissionError, OSError) as error:
            warnings.append(f"could not list {item}: {error}")
            return 0, 0, 0
        for child in children:
            child_logical, child_allocated, child_files = visit(child)
            item_logical += child_logical
            item_allocated += child_allocated
            item_files += child_files
        return item_logical, item_allocated, item_files

    component_records = []
    if path.is_dir() and not path.is_symlink() and components:
        try:
            children = sorted(path.iterdir(), key=lambda each: each.name)
        except (FileNotFoundError, PermissionError, OSError) as error:
            warnings.append(f"could not list {path}: {error}")
            children = []
        for child in children:
            child_logical, child_allocated, child_files = visit(child)
            logical += child_logical
            allocated += child_allocated
            files += child_files
            component_records.append({
                "name": child.name,
                "path": str(child.resolve()),
                "logicalBytes": child_logical,
                "allocatedBytes": child_allocated,
                "fileCount": child_files,
            })
    else:
        logical, allocated, files = visit(path)
    return {
        "logicalBytes": logical,
        "allocatedBytes": allocated,
        "fileCount": files,
        "components": sorted(
            component_records,
            key=lambda each: (-each["allocatedBytes"], -each["logicalBytes"], each["name"]),
        ),
        "warnings": warnings,
    }


def _safe_json(path: Path, warnings: list[str]) -> dict[str, Any] | None:
    try:
        value = read_json(path)
        if not isinstance(value, dict):
            raise ValueError("expected a JSON object")
        return value
    except (OSError, ValueError, json.JSONDecodeError) as error:
        warnings.append(f"could not read {path}: {error}")
        return None


class InventoryBuilder:
    def __init__(self, paths: BuildPaths):
        self.paths = paths
        self.nodes: dict[str, dict[str, Any]] = {}
        self.edges: dict[str, dict[str, Any]] = {}
        self.warnings: list[str] = []
        self.current_artifacts: set[Path] = set()

    def add_node(
        self, node_id: str, kind: str, label: str, path: Path | None, status: str,
        *, context_id: str | None = None, layer_id: str | None = None,
        characteristics: dict[str, Any] | None = None, aggregate: bool = False,
    ) -> dict[str, Any]:
        record = {
            "id": node_id,
            "kind": kind,
            "label": label,
            "path": str(path.resolve()) if path is not None else None,
            "status": status,
            "contextId": context_id,
            "layerId": layer_id,
            "logicalBytes": 0,
            "allocatedBytes": 0,
            "fileCount": 0,
            "components": [],
            "characteristics": characteristics or {},
            "aggregate": aggregate,
        }
        if path is not None and (path.exists() or path.is_symlink()):
            size = _size(path)
            self.warnings.extend(size.pop("warnings"))
            record.update(size)
        self.nodes[node_id] = record
        return record

    def add_edge(
        self, kind: str, source: str, target: str, characteristics: dict[str, Any] | None = None,
    ) -> None:
        if source not in self.nodes:
            self.add_node(source, "missing-reference", source, None, "missing")
        if target not in self.nodes:
            self.add_node(target, "missing-reference", target, None, "missing")
        edge_id = f"{kind}:{source}->{target}"
        self.edges[edge_id] = {
            "id": edge_id,
            "kind": kind,
            "source": source,
            "target": target,
            "characteristics": characteristics or {},
        }

    def definitions(self) -> None:
        layer_ids: list[str] = []
        for definition_file in self.paths.layer_files():
            definition = _safe_json(definition_file, self.warnings)
            layer_id = definition.get("layerId", definition_file.parent.name.upper()) if definition else definition_file.parent.name.upper()
            layer_ids.append(layer_id)
            self.add_node(
                _identifier("layer", layer_id), "layer", layer_id,
                definition_file.parent, "defined" if definition else "malformed",
                layer_id=layer_id, characteristics=definition or {"definition": str(definition_file)},
            )
        for parent, child in zip(layer_ids, layer_ids[1:]):
            self.add_edge("layer-parent", _identifier("layer", parent), _identifier("layer", child))

        context_files = sorted(
            list((self.paths.root / "build/contexts").glob("*.json"))
            + list((self.paths.state / "contexts").glob("*.json"))
        )
        for context_file in context_files:
            context_id = context_file.stem
            value = _safe_json(context_file, self.warnings)
            context_node = _identifier("context", context_id)
            expected: dict[str, Path] = {}
            error_text = None
            try:
                expected = {
                    item["definition"]["layerId"]: item["artifact"].resolve()
                    for item in graph(self.paths, context_id)
                }
                self.current_artifacts.update(
                    path for path in expected.values() if (path / "manifest.json").is_file()
                )
            except (OSError, RuntimeError, ValueError) as error:
                error_text = str(error)
                self.warnings.append(f"context {context_id} could not be resolved: {error}")
            characteristics = dict(value or {})
            characteristics.update({
                "definition": str(context_file.resolve()),
                "generated": self.paths.state in context_file.resolve().parents,
                "resolutionError": error_text,
                "expectedArtifacts": {key: str(path) for key, path in expected.items()},
            })
            self.add_node(
                context_node, "context", context_id, context_file,
                "resolved" if value and error_text is None else ("unresolved" if value else "malformed"),
                context_id=context_id, characteristics=characteristics,
            )
            selections = (value or {}).get("layers", {})
            for layer_id in layer_ids:
                self.add_edge(
                    "context-layer", context_node, _identifier("layer", layer_id),
                    selections.get(layer_id, {}),
                )

        for lock_file in sorted((self.paths.root / "build/locks").glob("*.json")):
            context_id = lock_file.name.removesuffix(".lock.json")
            value = _safe_json(lock_file, self.warnings)
            lock_id = _path_identifier("lock", lock_file, self.paths.root)
            self.add_node(
                lock_id, "lock", lock_file.name, lock_file,
                "valid" if value else "malformed", context_id=context_id,
                characteristics=value or {},
            )
            context_node = _identifier("context", context_id)
            if context_node in self.nodes:
                self.add_edge("context-lock", context_node, lock_id)

        for name in ("schemas", "tests"):
            support = self.paths.root / "build" / name
            if support.exists():
                self.add_node(
                    _identifier("build-support", name), "build-support", name,
                    support, "defined", aggregate=True,
                )

    def artifacts(self) -> None:
        root = self.paths.state / "artifacts"
        for artifact in sorted(path for path in root.glob("*/*/l*/*") if path.is_dir()):
            manifest_file = artifact / "manifest.json"
            manifest = _safe_json(manifest_file, self.warnings) if manifest_file.is_file() else None
            relative = artifact.relative_to(root)
            platform, context_id, layer_name, build_key = relative.parts
            layer_id = layer_name.upper()
            node_id = _path_identifier("artifact", artifact, self.paths.state)
            status = "current" if artifact.resolve() in self.current_artifacts else (
                "stale" if manifest else "orphaned"
            )
            self.add_node(
                node_id, "artifact", f"{layer_id} {build_key[:10]}", artifact, status,
                context_id=context_id, layer_id=layer_id,
                characteristics=(manifest or {}) | {
                    "platform": platform, "buildKey": build_key,
                    "manifestStatus": (manifest or {}).get("status"),
                },
            )
            self.add_edge("artifact-layer", _identifier("layer", layer_id), node_id)
            context_node = _identifier("context", context_id)
            if context_node in self.nodes:
                self.add_edge("context-artifact", context_node, node_id, {"current": status == "current"})
            for parent in (manifest or {}).get("parents", []):
                parent_path = root / platform / context_id / parent["layerId"].lower() / parent["buildKey"]
                self.add_edge(
                    "artifact-parent", _path_identifier("artifact", parent_path, self.paths.state), node_id,
                )

    def _record_directories(self, glob: str, kind: str, id_key: str) -> None:
        for metadata_file in sorted(self.paths.state.glob(glob)):
            path = metadata_file.parent
            value = _safe_json(metadata_file, self.warnings)
            identifier = (value or {}).get(id_key, path.name)
            context_id = (value or {}).get("contextId", path.parent.name)
            if kind == "run":
                active = process_is_alive((value or {}).get("pid")) or process_is_alive((value or {}).get("coordinatorPid"))
                status = "active" if active else (value or {}).get("state", "stopped")
            elif kind == "snapshot":
                pointer = self.paths.state / "state/gui" / f"{context_id}.json"
                selected = _safe_json(pointer, []) if pointer.is_file() else None
                status = "current" if selected and selected.get("snapshotId") == identifier else "saved"
            else:
                status = "valid" if value else "malformed"
            node_id = _path_identifier(kind, path, self.paths.state)
            self.add_node(
                node_id, kind, str(identifier), path, status,
                context_id=context_id, characteristics=value or {"metadata": str(metadata_file)},
            )
            if kind == "run":
                references = ("parentArtifact", "runtimeArtifact")
            else:
                references = ("parentL06Artifact", "parentL01Artifact")
            for reference in references:
                if (value or {}).get(reference):
                    artifact = Path(value[reference])
                    self.add_edge(
                        "artifact-materializes", _path_identifier("artifact", artifact, self.paths.state), node_id,
                        {"reference": reference},
                    )

    def records(self) -> None:
        self._record_directories("runs/*/*/run.json", "run", "runId")
        self._record_directories("snapshots/*/*/snapshot.json", "snapshot", "snapshotId")

        for pointer_file in sorted((self.paths.state / "state/gui").glob("*.json")):
            value = _safe_json(pointer_file, self.warnings)
            context_id = pointer_file.stem
            snapshot_id = (value or {}).get("snapshotId")
            snapshot_path = self.paths.state / "snapshots" / context_id / str(snapshot_id)
            valid = bool(snapshot_id and (snapshot_path / "snapshot.json").is_file())
            node_id = _path_identifier("snapshot-pointer", pointer_file, self.paths.state)
            self.add_node(
                node_id, "snapshot-pointer", f"{context_id} current snapshot", pointer_file,
                "valid" if valid else "broken", context_id=context_id,
                characteristics=value or {},
            )
            if snapshot_id:
                self.add_edge(
                    "pointer-snapshot", node_id,
                    _path_identifier("snapshot", snapshot_path, self.paths.state),
                )

        for pin_file in sorted((self.paths.state / "state/pins").glob("*.json")):
            value = _safe_json(pin_file, self.warnings)
            artifact_value = (value or {}).get("artifactPath")
            artifact_path = Path(artifact_value) if artifact_value else None
            valid = bool(value and artifact_path is not None and artifact_path.is_dir())
            node_id = _path_identifier("pin", pin_file, self.paths.state)
            self.add_node(
                node_id, "pin", (value or {}).get("pin", pin_file.stem), pin_file,
                "valid" if valid else "broken", context_id=(value or {}).get("contextId"),
                layer_id=(value or {}).get("layerId"), characteristics=value or {},
            )
            if value and value.get("artifactPath"):
                self.add_edge(
                    "pin-artifact", node_id,
                    _path_identifier("artifact", Path(value["artifactPath"]), self.paths.state),
                )

        for attempt in sorted(path for path in (self.paths.state / "tmp").glob("attempt-*") if path.is_dir()):
            manifest_file = attempt / "manifest.json"
            manifest = _safe_json(manifest_file, self.warnings) if manifest_file.is_file() else None
            node_id = _path_identifier("attempt", attempt, self.paths.state)
            status = (manifest or {}).get("status", "in-progress") if manifest else "in-progress"
            self.add_node(
                node_id, "attempt", attempt.name, attempt, status,
                context_id=(manifest or {}).get("contextId"), layer_id=(manifest or {}).get("layerId"),
                characteristics=manifest or {},
            )
            if (manifest or {}).get("layerId"):
                self.add_edge("attempt-layer", _identifier("layer", manifest["layerId"]), node_id)

        for generated in sorted((self.paths.state / "contexts").glob("*.json")):
            context_node = _identifier("context", generated.stem)
            for kind, location in (
                ("workspace", self.paths.state / "workspaces" / generated.stem),
                ("worktree", self.paths.state / "worktrees" / generated.stem),
            ):
                if location.exists():
                    node_id = _path_identifier(kind, location, self.paths.state)
                    self.add_node(node_id, kind, location.name, location, "present", context_id=generated.stem)
                    self.add_edge(f"context-{kind}", context_node, node_id)

        for refresh_file in sorted((self.paths.state / "state/gui-refresh").glob("*.json")):
            value = _safe_json(refresh_file, self.warnings)
            context_id = refresh_file.stem
            node_id = _path_identifier("gui-refresh", refresh_file, self.paths.state)
            self.add_node(
                node_id, "gui-refresh", f"{context_id} refresh", refresh_file,
                (value or {}).get("state", "malformed"), context_id=context_id,
                characteristics=value or {},
            )
            if _identifier("context", context_id) in self.nodes:
                self.add_edge("context-gui-refresh", _identifier("context", context_id), node_id)

        rebuilds = self.paths.state / "logs/rebuilds"
        if rebuilds.exists():
            self.add_node(
                _path_identifier("rebuild-log", rebuilds, self.paths.state), "rebuild-log",
                "rebuild logs", rebuilds, "diagnostic", aggregate=True,
            )
        for relative in ("cache", "locks", "state/locks", "logs", "tmp", "worktree-metadata"):
            auxiliary = self.paths.state / relative
            if auxiliary.exists():
                self.add_node(
                    _path_identifier("auxiliary-storage", auxiliary, self.paths.state),
                    "auxiliary-storage", relative, auxiliary, "present", aggregate=True,
                )

    def build(self) -> dict[str, Any]:
        started = time.perf_counter_ns()
        self.definitions()
        self.artifacts()
        self.records()
        state_size = _size(self.paths.state, components=False)
        repository_build_size = _size(self.paths.root / "build", components=False)
        self.warnings.extend(state_size.pop("warnings"))
        self.warnings.extend(repository_build_size.pop("warnings"))
        nodes = sorted(self.nodes.values(), key=lambda each: each["id"])
        edges = sorted(self.edges.values(), key=lambda each: each["id"])
        kinds = Counter(node["kind"] for node in nodes if not node["aggregate"])
        statuses = Counter(node["status"] for node in nodes if not node["aggregate"])
        return {
            "schemaVersion": 1,
            "operation": "build-map-inventory",
            "generatedAt": _now(),
            "repositoryRoot": str(self.paths.root),
            "stateRoot": str(self.paths.state),
            "metrics": {
                "scanTimeNs": time.perf_counter_ns() - started,
                "nodeCount": len(nodes),
                "edgeCount": len(edges),
                "kinds": dict(sorted(kinds.items())),
                "statuses": dict(sorted(statuses.items())),
                "stateRoot": state_size,
                "committedBuild": repository_build_size,
                "sizeWarning": "Allocated bytes double-count reflink-shared extents and are not exclusive reclaimable space.",
            },
            "nodes": nodes,
            "edges": edges,
            "warnings": sorted(set(self.warnings)),
        }


def build_inventory(paths: BuildPaths) -> dict[str, Any]:
    # A shared retention lock prevents GC/prune from removing canonical paths while
    # the read-only scan runs. Active images may still grow; such races are warnings.
    with retention_lock(paths):
        return InventoryBuilder(paths).build()


def write_inventory(paths: BuildPaths, output: Path) -> dict[str, Any]:
    inventory = build_inventory(paths)
    output = output if output.is_absolute() else paths.root / output
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + f".{os.getpid()}.tmp")
    temporary.write_text(json.dumps(inventory, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(output)
    return inventory | {"outputPath": str(output.resolve())}
