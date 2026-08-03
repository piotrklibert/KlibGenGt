from __future__ import annotations

import re
from collections.abc import Mapping
from dataclasses import dataclass, field
from types import MappingProxyType
from typing import Any


_IDENTIFIER = re.compile(r"^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$")


class RecipeValidationError(ValueError):
    """A precise error in an immutable recipe definition or composition."""


def _identifier(value: str, label: str) -> str:
    if not isinstance(value, str) or not _IDENTIFIER.fullmatch(value):
        raise RecipeValidationError(
            f"invalid {label} {value!r}: expected lowercase kebab-case"
        )
    return value


def _freeze(value: Any) -> Any:
    if isinstance(value, Mapping):
        return MappingProxyType({str(key): _freeze(item) for key, item in value.items()})
    if isinstance(value, (list, tuple)):
        return tuple(_freeze(item) for item in value)
    if isinstance(value, set):
        return tuple(sorted((_freeze(item) for item in value), key=repr))
    return value


def json_value(value: Any) -> Any:
    """Convert deeply frozen recipe data to deterministic JSON-compatible data."""
    if isinstance(value, Mapping):
        return {key: json_value(item) for key, item in sorted(value.items())}
    if isinstance(value, tuple):
        return [json_value(item) for item in value]
    if value is None or isinstance(value, (bool, int, float, str)):
        return value
    raise RecipeValidationError(
        f"configuration value {value!r} is not JSON serializable; paths must be declared inputs"
    )


@dataclass(frozen=True)
class StepImplementation:
    identifier: str
    version: int
    input_type: str | None
    output_type: str
    inputs: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        _identifier(self.identifier, "implementation identifier")
        if not isinstance(self.version, int) or isinstance(self.version, bool) or self.version < 1:
            raise RecipeValidationError("implementation version must be a positive integer")
        if self.input_type is not None:
            _identifier(self.input_type, "input type")
        _identifier(self.output_type, "output type")
        normalized = tuple(self.inputs)
        if len(set(normalized)) != len(normalized):
            raise RecipeValidationError(
                f"implementation {self.identifier!r} declares duplicate input paths"
            )
        object.__setattr__(self, "inputs", normalized)

    def as_dict(self) -> dict[str, Any]:
        return {
            "identifier": self.identifier,
            "version": self.version,
            "inputType": self.input_type,
            "outputType": self.output_type,
            "inputs": list(self.inputs),
        }


@dataclass(frozen=True)
class Step:
    role: str
    implementation: StepImplementation
    config: Mapping[str, Any] = field(default_factory=dict)
    checkpoint: str = "none"
    origin: str = "default"

    def __post_init__(self) -> None:
        _identifier(self.role, "step role")
        if self.checkpoint not in {"none", "artifact"}:
            raise RecipeValidationError(
                f"step {self.role!r} has invalid checkpoint policy {self.checkpoint!r}"
            )
        _identifier(self.origin, "step origin")
        frozen = _freeze(self.config)
        json_value(frozen)
        object.__setattr__(self, "config", frozen)

    def as_dict(self) -> dict[str, Any]:
        return {
            "role": self.role,
            "implementation": self.implementation.as_dict(),
            "config": json_value(self.config),
            "checkpoint": self.checkpoint,
            "origin": self.origin,
        }


@dataclass(frozen=True)
class Recipe:
    name: str
    steps: tuple[Step, ...]

    def __post_init__(self) -> None:
        _identifier(self.name, "recipe name")
        steps = tuple(self.steps)
        if not steps:
            raise RecipeValidationError(f"recipe {self.name!r} must contain at least one step")
        roles = [step.role for step in steps]
        duplicates = sorted({role for role in roles if roles.count(role) > 1})
        if duplicates:
            raise RecipeValidationError(
                f"recipe {self.name!r} contains duplicate roles: {', '.join(duplicates)}"
            )
        previous: Step | None = None
        for step in steps:
            expected = step.implementation.input_type
            actual = previous.implementation.output_type if previous is not None else None
            if expected != actual:
                raise RecipeValidationError(
                    f"step {step.role!r} expects input {expected!r}, got {actual!r}"
                )
            previous = step
        if steps[-1].checkpoint != "artifact":
            raise RecipeValidationError(
                f"recipe {self.name!r} must end at an artifact checkpoint"
            )
        object.__setattr__(self, "steps", steps)

    def renamed(self, name: str) -> "Recipe":
        return Recipe(name, self.steps)

    def replace(self, role: str, step: Step) -> "Recipe":
        matches = [index for index, current in enumerate(self.steps) if current.role == role]
        if not matches:
            raise RecipeValidationError(
                f"cannot replace unknown role {role!r} in recipe {self.name!r}"
            )
        if step.role != role:
            raise RecipeValidationError(
                f"replacement role {step.role!r} does not match requested role {role!r}"
            )
        values = list(self.steps)
        values[matches[0]] = step
        return Recipe(self.name, tuple(values))

    def append(self, *steps: Step, name: str | None = None) -> "Recipe":
        if not steps:
            raise RecipeValidationError("append requires at least one step")
        return Recipe(name or self.name, self.steps + tuple(steps))

    def drop_last(self, count: int, *, name: str | None = None) -> "Recipe":
        if not isinstance(count, int) or isinstance(count, bool) or count < 1:
            raise RecipeValidationError("drop_last count must be a positive integer")
        if count >= len(self.steps):
            raise RecipeValidationError(
                f"cannot drop {count} steps from {len(self.steps)}-step recipe {self.name!r}"
            )
        remaining = self.steps[:-count]
        if remaining[-1].checkpoint != "artifact":
            raise RecipeValidationError(
                f"dropping {count} steps leaves role {remaining[-1].role!r} without an artifact checkpoint"
            )
        return Recipe(name or self.name, remaining)

    def through(self, role: str, *, name: str | None = None) -> "Recipe":
        matches = [index for index, step in enumerate(self.steps) if step.role == role]
        if not matches:
            raise RecipeValidationError(
                f"cannot truncate recipe {self.name!r} through unknown role {role!r}"
            )
        selected = self.steps[: matches[0] + 1]
        if selected[-1].checkpoint != "artifact":
            raise RecipeValidationError(
                f"role {role!r} is not a publication boundary"
            )
        return Recipe(name or self.name, selected)

    def as_dict(self) -> dict[str, Any]:
        return {"name": self.name, "steps": [step.as_dict() for step in self.steps]}


@dataclass(frozen=True)
class LaunchPreset:
    name: str
    frontend: str
    source_changes: str
    persistence: str
    entrypoint: str
    inputs: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        for label, value in (
            ("preset name", self.name),
            ("frontend", self.frontend),
            ("source capability", self.source_changes),
            ("persistence capability", self.persistence),
            ("entrypoint", self.entrypoint),
        ):
            _identifier(value, label)
        object.__setattr__(self, "inputs", tuple(self.inputs))

    def as_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "frontend": self.frontend,
            "sourceChanges": self.source_changes,
            "persistence": self.persistence,
            "entrypoint": self.entrypoint,
            "inputs": list(self.inputs),
        }


@dataclass(frozen=True)
class Target:
    name: str
    recipe: Recipe
    preset: LaunchPreset

    def __post_init__(self) -> None:
        _identifier(self.name, "target name")


STANDARD_ROLES = (
    "runtime",
    "pharo-gt",
    "gt-patches",
    "build-support",
    "project-dependencies",
    "project-setup",
    "project-source",
    "project-finalize",
)


def _implementation(role: str, input_type: str | None, output_type: str, *inputs: str) -> StepImplementation:
    return StepImplementation(f"{role}-v2", 1, input_type, output_type, tuple(inputs))


RUNTIME_STEP = Step(
    "runtime",
    _implementation("runtime", None, "runtime-bundle", ".tool-versions-or-lock", "scripts/bootstrap-gt.sh"),
    {"sourceLocks": ["gt-release", "gt-installer"], "platform": True},
    "artifact",
)
PHARO_GT_STEP = Step(
    "pharo-gt",
    _implementation("pharo-gt", "runtime-bundle", "image-workspace", "scripts/bootstrap-gt.sh"),
    {"sourceLocks": ["gt-release"]},
)
GT_PATCHES_STEP = Step(
    "gt-patches",
    _implementation("gt-patches", "image-workspace", "image-workspace", "scripts/bootstrap-gt-source.sh"),
    {"variant": "default"},
)
BUILD_SUPPORT_STEP = Step(
    "build-support",
    _implementation("build-support", "image-workspace", "image-workspace", "build/v2/scripts/load-build-support.st", "build/v2/tests/build-support-contract.st"),
    {"sourcePaths": ["src/KlibGenGt-BuildSupport", "src/BaselineOfKlibGenGt"]},
    "artifact",
)
PROJECT_DEPENDENCIES_STEP = Step(
    "project-dependencies",
    _implementation("project-dependencies", "image-workspace", "image-workspace", "build/v2/scripts/load-project-dependencies.st", "build/v2/tests/project-dependencies-contract.st"),
    {"sourceLocks": ["sqlite3"]},
)
PROJECT_SETUP_STEP = Step(
    "project-setup",
    _implementation("project-setup", "image-workspace", "image-workspace"),
    checkpoint="artifact",
)
PROJECT_SOURCE_STEP = Step(
    "project-source",
    StepImplementation(
        "project-source-v2",
        2,
        "image-workspace",
        "image-workspace",
        ("build/v2/scripts/load-project-source.st",),
    ),
    {"jjTree": {"paths": ["src"], "exclude": ["src/KlibGenGt-BuildSupport"]}},
)
PROJECT_FINALIZE_STEP = Step(
    "project-finalize",
    _implementation("project-finalize", "image-workspace", "image-workspace", "build/v2/scripts/install-provenance.st", "build/v2/tests/project-contract.st", "data/kotlin-samples"),
    {"contracts": ["smoke", "type-pragmas"]},
    "artifact",
)

BASE = Recipe("base", (RUNTIME_STEP, PHARO_GT_STEP, GT_PATCHES_STEP, BUILD_SUPPORT_STEP))
PROJECT = BASE.append(
    PROJECT_DEPENDENCIES_STEP,
    PROJECT_SETUP_STEP,
    PROJECT_SOURCE_STEP,
    PROJECT_FINALIZE_STEP,
    name="project",
)

CLI_PRESET = LaunchPreset("cli", "headless", "disabled", "discard", "structured-request")
AGENTIC_PRESET = LaunchPreset("agentic", "headless", "staged", "discard", "agent-tools")
GUI_PRESET = LaunchPreset("gui", "gui", "interactive", "workspace", "workbench")
BUILD_MAP_PRESET = LaunchPreset("build-map", "gui", "disabled", "discard", "build-map", ("inventory",))

DEFAULT_RECIPES = {recipe.name: recipe for recipe in (BASE, PROJECT)}
DEFAULT_TARGETS = {
    name: Target(name, PROJECT, preset)
    for name, preset in {
        "cli": CLI_PRESET,
        "agentic": AGENTIC_PRESET,
        "gui": GUI_PRESET,
        "build-map": BUILD_MAP_PRESET,
    }.items()
}


__all__ = [
    "AGENTIC_PRESET", "BASE", "BUILD_MAP_PRESET", "CLI_PRESET", "DEFAULT_RECIPES",
    "DEFAULT_TARGETS", "GUI_PRESET", "LaunchPreset", "PROJECT", "Recipe",
    "RecipeValidationError", "STANDARD_ROLES", "Step", "StepImplementation", "Target",
    "json_value",
]
