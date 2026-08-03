"""Typed wire records for the named KlibGen v0.2 JSON protocols.

The models deliberately describe the wire representation: Python attribute names
are snake_case, aliases are the existing camelCase keys, and serialization keeps
the schema versions and optional-field presence of the input record.
"""

from __future__ import annotations

from typing import Any, ClassVar, Literal

from pydantic import BaseModel, ConfigDict, Field, JsonValue, ValidationError


class WireModel(BaseModel):
    """Immutable model with the compatibility policy used by extensible records."""

    model_config = ConfigDict(
        frozen=True,
        extra="allow",
        populate_by_name=True,
        validate_default=True,
    )
    schema_name: ClassVar[str | None] = None
    smalltalk_name: ClassVar[str]

    def to_wire(self) -> dict[str, JsonValue]:
        return self.model_dump(mode="json", by_alias=True, exclude_unset=True)


class ClosedWireModel(WireModel):
    """Wire model for records whose protocol rejects unknown fields."""

    model_config = ConfigDict(
        frozen=True,
        extra="forbid",
        populate_by_name=True,
        validate_default=True,
    )


class ErrorRecord(ClosedWireModel):
    smalltalk_name = "KGJsonErrorRecord"
    error_class: str = Field(alias="class")
    message: str


class StorageRecord(ClosedWireModel):
    smalltalk_name = "KGJsonStorageRecord"
    logical_bytes: int = Field(alias="logicalBytes", ge=0)
    allocated_bytes: int = Field(alias="allocatedBytes", ge=0)
    file_count: int = Field(alias="fileCount", ge=0)


class PathStorageRecord(ClosedWireModel):
    smalltalk_name = "KGJsonPathStorageRecord"
    path: str
    storage: StorageRecord


class StepImplementationRecord(ClosedWireModel):
    smalltalk_name = "KGJsonStepImplementationRecord"
    identifier: str
    version: int = Field(ge=1)
    input_type: str | None = Field(alias="inputType")
    output_type: str = Field(alias="outputType")
    inputs: tuple[str, ...]


class PathDigestFileRecord(WireModel):
    smalltalk_name = "KGJsonPathDigestFileRecord"
    path: str
    kind: str
    target: str | None = None
    mode: int | None = None
    sha256: str | None = None


class PathDigestRecord(ClosedWireModel):
    smalltalk_name = "KGJsonPathDigestRecord"
    digest: str
    files: tuple[PathDigestFileRecord, ...]


class LaunchPresetRecord(WireModel):
    smalltalk_name = "KGJsonLaunchPresetRecord"
    name: str
    frontend: str
    source_changes: str = Field(alias="sourceChanges")
    persistence: str
    entrypoint: str | None = None
    inputs: tuple[str, ...] | None = None
    start_mode: str | None = Field(default=None, alias="startMode")


class ResolvedStepRecord(WireModel):
    smalltalk_name = "KGJsonResolvedStepRecord"
    role: str
    implementation: StepImplementationRecord
    implementation_inputs: PathDigestRecord = Field(alias="implementationInputs")
    resolved_configuration: dict[str, JsonValue] = Field(alias="resolvedConfiguration")
    parent_output_key: str | None = Field(alias="parentOutputKey")
    step_key: str = Field(alias="stepKey")
    output_key: str = Field(alias="outputKey")
    checkpoint: Literal["none", "artifact"]
    origin: str


class ResolvedRecipeV1(WireModel):
    schema_name = "klibgen.resolved-recipe/1"
    smalltalk_name = "KGResolvedRecipeV1"
    schema_: Literal["klibgen.resolved-recipe/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    operation: str
    target: str
    recipe: str
    preset: LaunchPresetRecord
    steps: tuple[ResolvedStepRecord, ...]
    output_key: str = Field(alias="outputKey")


class RecipeCatalogTargetRecord(ClosedWireModel):
    smalltalk_name = "KGJsonRecipeCatalogTargetRecord"
    name: str
    recipe: str
    preset: LaunchPresetRecord
    roles: tuple[str, ...]


class RecipeCatalogV1(ClosedWireModel):
    schema_name = "klibgen.recipe-catalog/1"
    smalltalk_name = "KGRecipeCatalogV1"
    schema_: Literal["klibgen.recipe-catalog/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    operation: str
    targets: tuple[RecipeCatalogTargetRecord, ...]


class SourceLockV1(WireModel):
    schema_name = "klibgen.source-lock/1"
    smalltalk_name = "KGSourceLockV1"
    schema_: Literal["klibgen.source-lock/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    sources: tuple[dict[str, JsonValue], ...]


class ArtifactV1(WireModel):
    schema_name = "klibgen.artifact/1"
    smalltalk_name = "KGArtifactV1"
    schema_: Literal["klibgen.artifact/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    artifact_type: str = Field(alias="artifactType")
    output_key: str = Field(alias="outputKey")
    producing_role: str = Field(alias="producingRole")
    payload_shape_digest: str = Field(alias="payloadShapeDigest")
    platform: str | None = None
    resolved_recipe: ResolvedRecipeV1 | dict[str, JsonValue] | None = Field(default=None, alias="resolvedRecipe")
    path: str | None = None
    valid: bool | None = None
    storage: StorageRecord | None = None


class InvalidArtifactRecord(WireModel):
    smalltalk_name = "KGJsonInvalidArtifactRecord"
    path: str
    valid: Literal[False]
    error: str
    storage: StorageRecord | None = None


class ArtifactListV1(ClosedWireModel):
    schema_name = "klibgen.artifact-list/1"
    smalltalk_name = "KGArtifactListV1"
    schema_: Literal["klibgen.artifact-list/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    operation: str
    artifacts: tuple[ArtifactV1 | InvalidArtifactRecord, ...]


class ArtifactVerificationV1(ClosedWireModel):
    schema_name = "klibgen.artifact-verification/1"
    smalltalk_name = "KGArtifactVerificationV1"
    schema_: Literal["klibgen.artifact-verification/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    operation: str
    path: str
    manifest: ArtifactV1
    valid: Literal[True]


class PublishedArtifactRecord(ClosedWireModel):
    smalltalk_name = "KGJsonPublishedArtifactRecord"
    role: str
    path: str
    reused: bool


class BuildResultV1(ClosedWireModel):
    schema_name = "klibgen.build-result/1"
    smalltalk_name = "KGBuildResultV1"
    schema_: Literal["klibgen.build-result/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    operation: str
    target: str
    output_key: str = Field(alias="outputKey")
    artifacts: tuple[PublishedArtifactRecord, ...]
    reference: str | None = None


class BuildStatusV1(WireModel):
    schema_name = "klibgen.build-status/1"
    smalltalk_name = "KGBuildStatusV1"
    schema_: Literal["klibgen.build-status/1"] = Field(alias="schema")
    schema_version: Literal[1] | None = Field(default=None, alias="schemaVersion")
    state: Literal["building", "succeeded", "failed"]
    output_key: str = Field(alias="outputKey")
    role: str | None = None
    artifact_path: str | None = Field(default=None, alias="artifactPath")
    error: ErrorRecord | None = None
    failed_at: float | None = Field(default=None, alias="failedAt")
    diagnostic_path: str | None = Field(default=None, alias="diagnosticPath")
    path: str | None = None
    storage: StorageRecord | None = None


class ReferenceV1(WireModel):
    schema_name = "klibgen.reference/1"
    smalltalk_name = "KGReferenceV1"
    schema_: Literal["klibgen.reference/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    name: str
    artifact_type: str = Field(alias="artifactType")
    output_key: str = Field(alias="outputKey")
    artifact_path: str = Field(alias="artifactPath")
    producing_role: str = Field(alias="producingRole")
    path: str | None = None
    storage: StorageRecord | None = None


class SessionPathsRecord(WireModel):
    smalltalk_name = "KGJsonSessionPathsRecord"
    request: str | None = None
    ready: str | None = None
    completion: str
    result: str | None = None
    event_journal: str | None = Field(default=None, alias="eventJournal")
    source_requests: str | None = Field(default=None, alias="sourceRequests")
    source_responses: str | None = Field(default=None, alias="sourceResponses")


class SessionV1(WireModel):
    schema_name = "klibgen.session/1"
    smalltalk_name = "KGSessionV1"
    schema_: Literal["klibgen.session/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    session_id: str = Field(alias="sessionId")
    project_key: str = Field(alias="projectKey")
    recipe: str | None = None
    preset: LaunchPresetRecord
    paths: SessionPathsRecord
    inputs: dict[str, JsonValue] = Field(default_factory=dict)
    pid: int | None = None
    path: str | None = None
    storage: StorageRecord | None = None


class SessionReadyV1(ClosedWireModel):
    schema_name = "klibgen.session-ready/1"
    smalltalk_name = "KGSessionReadyV1"
    schema_: Literal["klibgen.session-ready/1"] = Field(alias="schema")
    schema_version: Literal[1] | None = Field(default=None, alias="schemaVersion")
    session_id: str = Field(alias="sessionId")
    ready: Literal[True]


class SessionCompletionV1(ClosedWireModel):
    schema_name = "klibgen.session-completion/1"
    smalltalk_name = "KGSessionCompletionV1"
    schema_: Literal["klibgen.session-completion/1"] = Field(alias="schema")
    schema_version: Literal[1] | None = Field(default=None, alias="schemaVersion")
    session_id: str = Field(alias="sessionId")
    state: Literal["succeeded", "failed", "saved", "discarded", "cancelled", "abnormal"]
    ok: bool
    exit_code: int | None = Field(default=None, alias="exitCode")
    error: ErrorRecord | None = None
    source_change_count: int | None = Field(default=None, alias="sourceChangeCount", ge=0)


class WorkspaceV1(WireModel):
    schema_name = "klibgen.workspace/1"
    smalltalk_name = "KGWorkspaceV1"
    schema_: Literal["klibgen.workspace/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    name: str
    state: Literal["ready", "active", "saved"]
    project_key: str = Field(alias="projectKey")
    artifact_path: str = Field(alias="artifactPath")
    base_source: dict[str, JsonValue] = Field(alias="baseSource")
    source_git: str = Field(alias="sourceGit")
    last_completion: SessionCompletionV1 | None = Field(alias="lastCompletion")
    pid: int | None = None
    session_id: str | None = Field(default=None, alias="sessionId")
    staging_area: str | None = Field(default=None, alias="stagingArea")
    staging_generation: int | None = Field(default=None, alias="stagingGeneration", ge=1)
    path: str | None = None
    storage: StorageRecord | None = None


class WorkspaceStatusV1(ClosedWireModel):
    schema_name = "klibgen.workspace-status/1"
    smalltalk_name = "KGWorkspaceStatusV1"
    schema_: Literal["klibgen.workspace-status/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    operation: str
    exists: bool
    name: str | None = None
    workspace: WorkspaceV1 | None = None
    path: str | None = None


class WorkspaceResetV1(ClosedWireModel):
    schema_name = "klibgen.workspace-reset/1"
    smalltalk_name = "KGWorkspaceResetV1"
    schema_: Literal["klibgen.workspace-reset/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    operation: str
    name: str
    removed: bool


class RenameRecord(ClosedWireModel):
    smalltalk_name = "KGJsonRenameRecord"
    source: str = Field(alias="from")
    target: str = Field(alias="to")


class StagingChangesRecord(ClosedWireModel):
    smalltalk_name = "KGJsonStagingChangesRecord"
    additions: tuple[str, ...]
    modifications: tuple[str, ...]
    removals: tuple[str, ...]
    renames: tuple[RenameRecord, ...]
    prohibited: tuple[str, ...]


class PromotionRecord(WireModel):
    smalltalk_name = "KGJsonPromotionRecord"
    ok: bool
    conflicts: tuple[str, ...] | None = None
    changes: StagingChangesRecord | None = None


class StagingV1(WireModel):
    schema_name = "klibgen.staging/1"
    smalltalk_name = "KGStagingV1"
    schema_: Literal["klibgen.staging/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    name: str
    state: Literal["ready", "conflicted", "promoted"]
    base_source: dict[str, JsonValue] = Field(alias="baseSource")
    project_key: str = Field(alias="projectKey")
    source_git: str = Field(alias="sourceGit")
    promotion: PromotionRecord | None
    generation: int | None = Field(default=None, ge=1)
    head_commit: str | None = Field(default=None, alias="headCommit")
    lease: dict[str, JsonValue] | None = None
    last_rebase: dict[str, JsonValue] | None = Field(default=None, alias="lastRebase")
    last_promotion: dict[str, JsonValue] | None = Field(default=None, alias="lastPromotion")
    path: str | None = None
    changes: StagingChangesRecord | None = None
    storage: StorageRecord | None = None


class StagingListV1(ClosedWireModel):
    schema_name = "klibgen.staging-list/1"
    smalltalk_name = "KGStagingListV1"
    schema_: Literal["klibgen.staging-list/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    operation: str
    staging_areas: tuple[StagingV1, ...] = Field(alias="stagingAreas")


class StagingResultV1(ClosedWireModel):
    schema_name = "klibgen.staging-result/1"
    smalltalk_name = "KGStagingResultV1"
    schema_: Literal["klibgen.staging-result/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    operation: str
    staging: StagingV1
    path: str
    changes: StagingChangesRecord | None = None


class MalformedRecord(ClosedWireModel):
    smalltalk_name = "KGJsonMalformedRecord"
    path: str
    malformed: Literal[True]
    error: str


class InventoryRecipeRecord(ClosedWireModel):
    smalltalk_name = "KGJsonInventoryRecipeRecord"
    name: str
    roles: tuple[str, ...]


class InventoryStepRecord(ClosedWireModel):
    smalltalk_name = "KGJsonInventoryStepRecord"
    role: str
    output_key: str = Field(alias="outputKey")
    checkpoint: Literal["none", "artifact"]


class InventoryTargetRecord(ClosedWireModel):
    smalltalk_name = "KGJsonInventoryTargetRecord"
    name: str
    output_key: str = Field(alias="outputKey")
    steps: tuple[InventoryStepRecord, ...]


class InventoryNodeRecord(WireModel):
    smalltalk_name = "KGJsonInventoryNodeRecord"
    id: str
    kind: Literal["target", "step", "artifact", "reference", "workspace", "staging"]
    label: str
    status: str
    characteristics: dict[str, JsonValue]
    logical_bytes: int = Field(alias="logicalBytes", ge=0)
    allocated_bytes: int = Field(alias="allocatedBytes", ge=0)
    file_count: int = Field(alias="fileCount", ge=0)
    path: str | None = None


class InventoryEdgeRecord(ClosedWireModel):
    smalltalk_name = "KGJsonInventoryEdgeRecord"
    id: str
    kind: str
    source: str
    target: str
    characteristics: dict[str, JsonValue]


class InventoryV2(ClosedWireModel):
    schema_name = "klibgen.inventory/2"
    smalltalk_name = "KGInventoryV2"
    schema_: Literal["klibgen.inventory/2"] = Field(alias="schema")
    schema_version: Literal[2] = Field(alias="schemaVersion")
    operation: Literal["inventory"]
    generated_at: str = Field(alias="generatedAt")
    nodes: tuple[InventoryNodeRecord, ...]
    edges: tuple[InventoryEdgeRecord, ...]
    warnings: tuple[str, ...]
    state_root: str = Field(alias="stateRoot")
    recipes: tuple[InventoryRecipeRecord, ...]
    targets: tuple[InventoryTargetRecord, ...]
    artifacts: tuple[ArtifactV1 | InvalidArtifactRecord, ...]
    references: tuple[ReferenceV1 | MalformedRecord, ...]
    workspaces: tuple[WorkspaceV1 | MalformedRecord, ...]
    staging_areas: tuple[StagingV1 | MalformedRecord, ...] = Field(alias="stagingAreas")
    active_sessions: tuple[SessionV1 | MalformedRecord, ...] = Field(alias="activeSessions")
    statuses: tuple[BuildStatusV1 | MalformedRecord, ...]
    locks: tuple[str, ...]
    storage: StorageRecord


class GcPlanV1(ClosedWireModel):
    schema_name = "klibgen.gc-plan/1"
    smalltalk_name = "KGGcPlanV1"
    schema_: Literal["klibgen.gc-plan/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    operation: Literal["gc"]
    mode: Literal["apply", "dry-run"]
    roots: tuple[str, ...]
    remove: tuple[PathStorageRecord, ...]
    warnings: tuple[str, ...]
    applied: bool


class ToolCheckRecord(ClosedWireModel):
    smalltalk_name = "KGJsonToolCheckRecord"
    ok: bool
    name: str | None = None
    path: str | None = None


class DoctorV1(ClosedWireModel):
    schema_name = "klibgen.doctor/1"
    smalltalk_name = "KGDoctorV1"
    schema_: Literal["klibgen.doctor/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    operation: Literal["doctor"]
    ok: bool
    platform: str
    state_root: str = Field(alias="stateRoot")
    tools: tuple[ToolCheckRecord, ...]
    checks: tuple[ToolCheckRecord, ...]


class StatusListV1(ClosedWireModel):
    schema_name = "klibgen.status-list/1"
    smalltalk_name = "KGStatusListV1"
    schema_: Literal["klibgen.status-list/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    operation: Literal["status"]
    statuses: tuple[BuildStatusV1, ...]
    workspace: WorkspaceStatusV1


class SuffixStorageRecord(ClosedWireModel):
    smalltalk_name = "KGJsonSuffixStorageRecord"
    count: int = Field(ge=0)
    logical_bytes: int = Field(alias="logicalBytes", ge=0)


class MeasurementStorageRecord(ClosedWireModel):
    smalltalk_name = "KGJsonMeasurementStorageRecord"
    logical_bytes: int = Field(alias="logicalBytes", ge=0)
    allocated_bytes: int = Field(alias="allocatedBytes", ge=0)
    files: dict[str, SuffixStorageRecord]


class MeasurementV1(ClosedWireModel):
    schema_name = "klibgen.measurement/1"
    smalltalk_name = "KGMeasurementV1"
    schema_: Literal["klibgen.measurement/1"] = Field(alias="schema")
    schema_version: Literal[1] = Field(alias="schemaVersion")
    operation: str
    exit_code: int = Field(alias="exitCode")
    wall_seconds: float = Field(alias="wallSeconds", ge=0)
    before: MeasurementStorageRecord
    after: MeasurementStorageRecord
    logical_byte_delta: int = Field(alias="logicalByteDelta")
    allocated_byte_delta: int = Field(alias="allocatedByteDelta")


NAMED_MODELS: tuple[type[WireModel], ...] = (
    ArtifactV1,
    ArtifactListV1,
    ArtifactVerificationV1,
    BuildResultV1,
    BuildStatusV1,
    DoctorV1,
    GcPlanV1,
    InventoryV2,
    MeasurementV1,
    RecipeCatalogV1,
    ReferenceV1,
    ResolvedRecipeV1,
    SessionV1,
    SessionReadyV1,
    SessionCompletionV1,
    SourceLockV1,
    StagingV1,
    StagingListV1,
    StagingResultV1,
    StatusListV1,
    WorkspaceV1,
    WorkspaceResetV1,
    WorkspaceStatusV1,
)

MODEL_BY_SCHEMA: dict[str, type[WireModel]] = {}
for _model in NAMED_MODELS:
    if _model.schema_name in MODEL_BY_SCHEMA:
        raise RuntimeError(f"duplicate JSON schema registration {_model.schema_name}")
    MODEL_BY_SCHEMA[_model.schema_name] = _model


def parse_named_record(value: dict[str, Any]) -> WireModel:
    """Validate and answer a model selected by the record's named schema."""

    schema = value.get("schema")
    if not isinstance(schema, str) or schema not in MODEL_BY_SCHEMA:
        raise ValueError(f"unknown named KlibGen JSON schema {schema!r}")
    return MODEL_BY_SCHEMA[schema].model_validate(value)


def validate_named_record(value: dict[str, Any]) -> dict[str, JsonValue]:
    """Validate a named record and return its compatibility-preserving wire form."""

    return parse_named_record(value).to_wire()


def validation_message(error: ValidationError) -> str:
    """Return a stable compact explanation suitable for inventory warnings."""

    first = error.errors(include_url=False)[0]
    location = ".".join(str(item) for item in first["loc"])
    return f"{location}: {first['msg']}" if location else str(first["msg"])


ALL_MODELS: tuple[type[WireModel], ...] = tuple(
    sorted(
        {
            candidate
            for candidate in WireModel.__subclasses__()
            for candidate in (candidate, *candidate.__subclasses__())
            if candidate not in {ClosedWireModel}
        },
        key=lambda model: model.smalltalk_name,
    )
)


__all__ = [
    "ALL_MODELS",
    "MODEL_BY_SCHEMA",
    "NAMED_MODELS",
    "InventoryV2",
    "SessionV1",
    "WireModel",
    "parse_named_record",
    "validate_named_record",
    "validation_message",
]
