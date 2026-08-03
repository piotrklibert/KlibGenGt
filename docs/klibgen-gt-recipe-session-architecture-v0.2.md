# KlibGen-GT recipe and session architecture

Version: 0.2 (proposed)

Status: implementation specification

Supersedes, for new implementation work,
`klibgen-gt-reproducible-build-architecture-v0.1.md`. The v0.1 document remains
useful as historical design rationale. The implementation being replaced is
described in `klibgen-build-current-implementation.md`.

## 1. Purpose

KlibGen-GT needs a fast, convenient way to construct and use an exact
VM/Pharo/Glamorous Toolkit/project environment while retaining the ability to
temporarily replace any part of that stack.

The first implementation proved the source/image split, exact project-source
loading, layer contracts, isolated publication, and conflict-checked source
promotion. It also made nearly every conceptual distinction own a complete
image bundle. Contexts, layers, runs, failed attempts, and GUI snapshots could
therefore multiply gigabytes of data during ordinary development.

This version changes the optimization target:

1. make the normal edit, test, inspect, and GUI loop fast;
2. create and retain very few complete image copies;
3. make the build model smaller and more composable;
4. preserve exact provenance and safe replacement of lower stack components;
5. provide useful diagnostics without retaining failed machine states; and
6. accept weaker isolation where stronger guarantees would materially increase
   complexity or storage churn.

The architecture distinguishes three things that v0.1 often represented with
the same filesystem object:

- a **recipe**, which describes construction;
- an **artifact**, which is a reusable immutable build result; and
- a **session**, which describes how an artifact is used now.

## 2. Normative language

The terms **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** are to
be interpreted as normative requirements.

Examples are illustrative unless they use normative language. Names of Python
classes, Smalltalk classes, commands, files, and JSON properties are proposed
API names; implementation may refine spelling without changing the specified
semantics.

## 3. Priorities and accepted compromises

When two requirements conflict, implementations SHOULD prefer them in this
order:

1. protect authoritative project source from accidental loss;
2. keep the common development path fast and understandable;
3. avoid unnecessary writes and retained copies of large files;
4. keep provenance and invalidation sound for declared inputs;
5. support temporary substitutions throughout the stack;
6. maximize isolation and historical recoverability.

The following compromises are intentional:

- CLI read-only behavior prevents accidental mutation through KlibGen APIs; it
  is not a security boundary against reflective Smalltalk code or subprocesses.
- Failed builds and tool runs retain diagnostics, not a resumable failed image.
- GUI has one current saved workspace, not an append-only saved-state history.
- A resumed GUI may be stale relative to the repository, provided the staleness
  is made explicit.
- Build reproducibility covers declared and captured inputs. V0.2 does not
  attempt hermetic OS/container builds by default.
- Alternative stack configurations may rebuild from the lowest changed step;
  the system is optimized for the default stack and project-level changes.

## 4. Goals

### 4.1 Fast common path

A normal project-source edit MUST reuse the runtime, Pharo/GT base, and stable
project-dependency checkpoints. It MUST create at most one new canonical
project image regardless of whether the result is later used by CLI, agentic,
or GUI sessions.

An unchanged read-only CLI operation SHOULD require no complete image copy. A
disposable GUI tool SHOULD require no preparation-and-save startup.

### 4.2 Composable stack substitutions

Recipes MUST support replacing a named step and truncating a recipe. It MUST be
possible to derive configurations such as:

- `base-Pharo15` from `base` by replacing the Pharo/GT acquisition step;
- `gui-GT-patched` from the normal GUI target by replacing the GT step;
- a recipe prefix that ends before project source is loaded; and
- a project image using a temporary dependency or VM worktree.

These alternatives MUST NOT require hard-coded branches in the central build
driver.

### 4.3 Shared immutable results

Identical step outputs MUST be shareable between all recipes and launch
presets. Recipe names, target names, and launch modes MUST NOT be part of an
artifact's storage identity unless they change an actual declared build input.

### 4.4 Explicit provenance and session state

Smalltalk code MUST be able to inspect:

- how the running image was built;
- which recipe and step keys produced it;
- which launch preset started it;
- whether the start was fresh or resumed;
- which capabilities are available; and
- which external inputs belong to the session.

### 4.5 Cheap tools

Headless and GUI tools MUST be expressible as registered entrypoints over the
canonical project image. Adding a tool SHOULD require an image-side entrypoint
and, when necessary, a host-side input producer—not a new image recipe or a new
central dispatch conditional.

### 4.6 Safe source workflows

Authoritative Smalltalk source MUST remain external to canonical images.
Exports and refactorings MUST pass through a session capability and MUST be
conflict-checked before promotion into authoritative `src/`.

### 4.7 Bounded routine retention

Routine development MUST NOT accumulate complete failed runs, failed build
attempts, forced-rebuild archives, or an unbounded GUI snapshot history.

## 5. Non-goals for v0.2

V0.2 does not require:

- hostile-code sandboxing;
- cross-platform OS-level read-only mounts;
- a declarative recipe language independent of Python;
- distributed or remote artifact storage;
- long-term binary artifact archival;
- automatic preservation of multiple GUI workspace generations;
- merging unexported GUI image changes with a changed staging generation;
- resumable agentic images;
- concurrent writers to the same GUI workspace or staging area;
- a general package manager replacing Metacello/Iceberg;
- a completed RELEASE distribution pipeline; or
- content-deduplicating the internal pages of multiple `.image` files.

## 6. Core principles

### 6.1 Recipes construct; sessions use

Frontend, permissions, tool entrypoint, persistence, and process reuse are
launch properties. They MUST NOT produce separate canonical images unless an
image transformation is genuinely required.

### 6.2 External source remains authoritative

The repository, locks, recipes, scripts, and selected external worktrees are
authoritative. Images are build products or explicitly mutable workspaces.

### 6.3 Storage identity follows content-producing inputs

An immutable artifact is addressed by its step output key. Two recipes that
resolve the same parent and the same step inputs refer to the same artifact.

### 6.4 Persistence is explicit

Only economically useful build boundaries and explicitly persistent workspaces
own durable image state. Diagnostic records do not imply image retention.

### 6.5 Capabilities replace mode conditionals

Code MUST request a mutating operation through a capability object. It SHOULD
NOT branch throughout the code on `mode = #cli` or similar global flags.

### 6.6 Smalltalk owns orderly image lifecycle

Smalltalk knows whether it saved, discarded, cancelled, or completed a tool.
It MUST report this explicitly. Python owns process orchestration, artifact
publication, and abnormal-termination handling; it MUST NOT infer orderly save
semantics from image hashes or `.changes` markers.

### 6.7 Failure replaces diagnostics, not successful artifacts

A failed attempt MUST leave the last successful artifact usable. It updates the
current failure/status record and removes its partial image after diagnostics
have been extracted.

### 6.8 Optimize the default stack

The default VM, Pharo, GT, dependency, and project recipes are the primary
workflow. Alternative stacks are easy to derive but need not be prebuilt or
kept live by routine retention.

## 7. System model

The normal construction stack is:

```text
runtime/native bundle
        ↓
Pharo + clean GT image
        ↓
optional GT patches + generic KlibGen build support
        ↓                     base checkpoint
project dependencies + stable setup
        ↓                     dependency checkpoint
project source load + project finalization/contracts
        ↓                     project checkpoint
```

`base` and `project` are named recipes or recipe prefixes. `cli`, `agentic`,
`gui`, and `build-map` are normally launch presets over the one canonical
project output:

| Preset | Frontend | Source changes | Image persistence | Entrypoint |
| --- | --- | --- | --- | --- |
| `cli` | headless | disabled | discard | structured request |
| `agentic` | headless or GUI | staged | discard | agent tools |
| `gui` | GUI | interactive | workspace | workbench |
| `build-map` | GUI | disabled | discard | `build-map` |

A user-facing target MAY pair a modified recipe with a preset. For example,
`gui-GT-patched` means “resolve the project recipe with a replacement GT step,
then launch the GUI preset.” The GUI distinction still does not change the
artifact key.

## 8. Terminology

### 8.1 Recipe

An immutable ordered sequence of named steps. A recipe can be copied with a
step replaced, appended, or truncated.

### 8.2 Step

A deterministic-as-practical transformation with declared inputs, key
material, validation, and output metadata. A step may publish a large artifact
checkpoint or only transform/validate a shared build workspace.

### 8.3 Step role

A stable semantic identifier such as `runtime`, `pharo-gt`, `gt-patches`,
`build-support`, `project-dependencies`, `project-setup`, `project-source`, or
`project-finalize`. Roles are used for replacement and inspection. They are not
array indices or legacy L-numbers.

### 8.4 Resolved recipe

A recipe whose moving inputs have been converted into exact revisions,
digests, paths, and platform facts. Its ordered steps and keys are serializable
for diagnostics and provenance.

### 8.5 Checkpoint

A durable immutable build output worth retaining for reuse. A step does not
automatically imply a checkpoint.

### 8.6 Artifact

A checkpoint payload plus its manifest, stored globally under an output key.
Artifact payloads include runtime/native bundles and image bundles.

### 8.7 Reference

A small mutable name-to-key record, such as the current successful output of
the default project recipe. References do not own or duplicate artifacts.

### 8.8 Launch preset

A named set of session properties: frontend, capabilities, persistence,
entrypoint, process policy, and input declarations.

### 8.9 Session

One invocation or one active process using a resolved artifact under a launch
preset. A session has a manifest, private transient paths, logs, and a
completion record. It need not have a private image copy.

### 8.10 Workspace

A named mutable saved image and associated private state. V0.2 requires one
ordinary GUI workspace, `gui-default`; additional explicitly named workspaces
MAY be supported.

### 8.11 Staging area

Durable source-form output produced by agentic or interactive tools before
conflict-checked promotion into authoritative source. It is not an image.

### 8.12 Build provenance

Static data embedded in a canonical image describing the inputs and steps that
constructed it.

### 8.13 Session provenance

Launch-time data describing how the current process is using an image.

## 9. Python recipe model

### 9.1 Representation

Recipes MUST be ordinary Python values in v0.2. A minimal conceptual API is:

```python
@dataclass(frozen=True)
class Step:
    role: str
    implementation: StepImplementation
    config: Mapping[str, object]
    checkpoint: CheckpointPolicy

@dataclass(frozen=True)
class Recipe:
    name: str
    steps: tuple[Step, ...]

    def replace(self, role: str, step: Step) -> "Recipe": ...
    def drop_last(self, count: int) -> "Recipe": ...
    def through(self, role: str) -> "Recipe": ...
    def append(self, *steps: Step) -> "Recipe": ...
```

The implementation MUST validate:

- recipe and step identifiers;
- uniqueness of replaceable roles within a recipe;
- input/output compatibility between adjacent steps;
- required checkpoint boundaries;
- serializability of resolved configuration; and
- absence of undeclared mutable path inputs.

Recipe operations MUST return new values. They MUST NOT mutate a global default
recipe in place.

### 9.2 Standard recipes

The repository SHOULD define these values:

```python
BASE = Recipe(...)
PROJECT = BASE.append(...)

DEFAULT_TARGETS = {
    "cli": Target(PROJECT, CLI_PRESET),
    "agentic": Target(PROJECT, AGENTIC_PRESET),
    "gui": Target(PROJECT, GUI_PRESET),
    "build-map": Target(PROJECT, BUILD_MAP_PRESET),
}
```

`BASE` ends after clean GT, optional default patches, and generic build/session
support. It does not contain project dependencies or project source.

`PROJECT` adds project dependencies, stable project setup, exact project source,
session hooks, and validation needed by all normal presets.

### 9.3 Standard step roles

The initial implementation SHOULD use these semantic roles:

| Role | Responsibility | Normal checkpoint |
| --- | --- | --- |
| `runtime` | VM launcher, native libraries, sources, immutable runtime data | native/runtime bundle |
| `pharo-gt` | acquire or build the selected Pharo/GT image | no separate final policy decision; participates in base |
| `gt-patches` | apply selected GT source/image patches | no, unless expensive enough to justify one |
| `build-support` | install generic provenance, session bootstrap, lifecycle support | base image |
| `project-dependencies` | load pinned third-party project dependencies | dependency image |
| `project-setup` | install stable project metadata/configuration | normally folded into dependency checkpoint |
| `project-source` | load exact authoritative or staged project source | no intermediate image |
| `project-finalize` | install project hooks, run contracts, publish provenance | project image |

The table is a default, not a fixed global layer enumeration. A replacement may
internally use more steps. Inventory and visualization MUST derive order from
the resolved recipe rather than assume `L01` through `L07`.

### 9.4 Alternative recipes

Examples:

```python
base_pharo15 = BASE.replace("pharo-gt", pharo15_gt_step)
project_pharo15 = PROJECT.replace("pharo-gt", pharo15_gt_step)
gui_gt_patched = Target(
    PROJECT.replace("gt-patches", gt_worktree_step("vendor/gt-build/patched")),
    GUI_PRESET,
)
without_project = PROJECT.drop_last(2)
```

A dirty worktree MAY be used as a step input. Its resolved identity MUST include
both the base revision and a deterministic digest of effective dirty content.
The manifest MUST mark the result dirty/host-bound where appropriate.

Temporary alternatives SHOULD be explicitly named or kept as local Python
values. They MUST NOT become roots for routine retention merely because they
can be resolved.

## 10. Keys, invalidation, and resolution

### 10.1 Step key

A step key MUST include only effective, declared construction inputs:

```text
parent output key, if any
step implementation identity/version
normalized resolved configuration
digests of declared scripts and files
resolved effective source identities or dirty-tree digests
relevant platform, VM ABI, and host facts
declared tool versions and environment values
```

It MUST NOT include:

- recipe name;
- launch preset;
- frontend;
- context/target name;
- paths whose contents and semantics are otherwise captured; or
- a digest of the entire Python package.

Resolved configuration MAY contain additional metadata needed to materialize
an input or explain its provenance. Such metadata MUST enter the step key only
when it can change the constructed output. In particular, a JJ project source
key MUST be derived from the effective selected-tree content. Its commit ID,
change ID, selector paths, and exclusions MUST remain recorded as provenance,
but MUST NOT produce distinct artifact keys when the effective selected tree is
identical.

Every executable script, Smalltalk script, template, schema, or Python function
whose behavior can change the output MUST be represented in that step's
implementation identity. V0.2 MUST eliminate both the global over-invalidation
and omitted-script under-invalidation documented for v0.1.

### 10.2 Output key

The first implementation MAY use the step key as the expected output key. If
post-build content verification is added, it MAY distinguish an input/build key
from a content output key. Manifests MUST state which scheme is used.

### 10.3 Downstream invalidation

Changing a step key invalidates that step and descendants only. Unrelated
recipes sharing unchanged prefix keys continue referring to the same artifacts.

Project-source changes normally invalidate `project-source` and
`project-finalize`. They MUST NOT invalidate runtime, GT, dependencies, or
stable setup unless one of those steps explicitly declares the changed file as
an input.

### 10.4 Resolution

Moving selectors—branches, release channels, installer URLs, or worktree
locations—MUST be resolved to exact revisions/digests before key computation.
Resolution MAY update a committed or generated lock only through an explicit
operation.

### 10.5 Reuse verification

Before reuse, the coordinator MUST validate at least:

- the manifest schema and status;
- the artifact key and type;
- required payload paths;
- recorded parent relationship; and
- inexpensive integrity checks for critical files.

Full payload hashing MAY be deferred or exposed as a separate verification
command when it would slow the common path materially.

## 11. Checkpoint and artifact model

### 11.1 Economically useful checkpoints

The default policy retains only:

1. the selected runtime/native bundle;
2. the clean supported base image;
3. the project dependency/stable setup image; and
4. the current canonical project image.

Several steps MAY execute in one private build workspace between checkpoints.
Each remains separately keyed and diagnosed, but it does not need to publish a
complete image.

The policy MAY omit either the standalone runtime reference or a separate
intermediate image if measurements show it is not economically useful. The base,
dependency, and project semantic boundaries MUST remain inspectable in the
resolved recipe even when two share one physical publication.

### 11.2 Global artifact store

Artifacts MUST be stored by type, platform/ABI, and key—not by recipe or
context. For example:

```text
.klibgen/v2/store/
  runtime/<platform>/<key>/
  image/<platform>/<key>/
```

An artifact directory MUST be published atomically and made read-only after
validation. A failed publisher MUST NOT replace or corrupt an existing
successful directory.

### 11.3 Runtime and native libraries

Large immutable native libraries MUST be stored once per runtime/native bundle.
Execution views SHOULD present them by:

1. symlinking an immutable directory when GT and the VM tolerate it;
2. hardlinking individual immutable files when path layout must be reproduced;
3. reflinking files that cannot safely be shared by ordinary links; and
4. using a read-only bind mount only when actual filesystem enforcement is
   needed and available.

The implementation MUST test GT's path lookup and packaging behavior before
choosing a strategy. Project-supplied native libraries, such as a bundled
SQLite3, SHOULD be a small additive content-addressed bundle rather than a copy
inside every image checkpoint.

No session may mutate a linked canonical native file. If a tool requires a
writable library path, that file MUST be privately materialized and recorded in
the session manifest.

### 11.4 Build workspace

A build uses one private temporary workspace from the nearest reusable parent
checkpoint through the next checkpoint. The workspace MAY contain a writable
image, changes file, source bridge, HOME/XDG directories, and logs.

On success, only the checkpoint payload, manifest, validation records, and
current bounded log are published. On failure, the partial image is removed
after diagnostics are written.

### 11.5 References

Named recipes and targets point to keys through small reference records. A
reference update MUST be atomic. Updating a reference does not copy an artifact.

## 12. Manifests and provenance

### 12.1 Artifact manifest

Every artifact MUST have a versioned manifest containing:

- schema identifier and version;
- artifact type, platform, and key;
- producing step role and implementation identity;
- parent artifact and step keys;
- resolved recipe prefix;
- exact VM, Pharo, GT, dependency, and project identities as applicable;
- declared configuration, file digests, environment inputs, and host facts;
- dirty/host-bound flags and reasons;
- payload inventory and critical checksums;
- contract/validation results;
- build timestamp and coordinator protocol version; and
- provenance payload installed into an image, if applicable.

### 12.2 In-image build provenance

The final base, dependency, and project images MUST contain a static provenance
object equivalent to:

```smalltalk
KGBuildProvenance current
    recipe;
    stepKeys;
    vmIdentity;
    pharoIdentity;
    gtIdentity;
    dependencyIdentities;
    projectIdentity;
    buildTimestamp;
    driverProtocolVersion
```

The in-image payload MUST be generated from the same normalized record used in
the host manifest. It MUST NOT be reconstructed from the current checkout at
runtime.

### 12.3 Session manifest

Before starting an image, the coordinator MUST write a versioned session
manifest containing at least:

```json
{
  "schema": "klibgen.session/1",
  "sessionId": "...",
  "target": "build-map",
  "recipe": "project",
  "projectArtifactKey": "...",
  "frontend": "gui",
  "startMode": "fresh",
  "sourceChanges": "disabled",
  "imagePersistence": "discard",
  "entrypoint": "build-map",
  "processPolicy": "auto",
  "workspace": null,
  "stagingArea": null,
  "inputs": {"stagingArea": null, "stagingGeneration": null},
  "paths": {"sourceRequests": null, "sourceResponses": null},
  "protocolVersion": 1
}
```

Paths MUST be explicit. The manifest MUST distinguish immutable presented paths,
private transient paths, durable workspace paths, and durable staging paths.
Writable sessions use session-scoped atomic source request/response spool paths.
The launcher services only bounded envelopes whose session ID, staging name,
lease, and operation match the active manifest.

### 12.4 Smalltalk session object

One generic startup hook MUST read and validate the session manifest. It
installs an immutable `KGSession` object before dispatching the entrypoint.

Conceptual API:

```smalltalk
KGSession current frontend.       "#gui"
KGSession current startMode.      "#fresh or #resume"
KGSession current entrypoint.     "#buildMap"
KGSession current sourceChanges.  "capability object"
KGSession current persistence.    "capability object"
KGSession current inputNamed: 'inventory'.
```

Unknown schema versions, missing mandatory paths, incompatible project keys, or
unknown capabilities MUST fail before a mutating entrypoint is run.

## 13. Launch presets and session axes

### 13.1 Orthogonal properties

A launch preset is the product of independent properties:

| Property | Initial values |
| --- | --- |
| frontend | `headless`, `gui` |
| source capability | `disabled`, `staged`, `interactive` |
| image persistence | `discard`, `workspace` |
| entrypoint | `workbench`, registered tool identifier, structured request |
| process policy | `new`, `reuse-compatible-gui`, `auto` |
| inputs | versioned session resources |

The coordinator SHOULD validate combinations declaratively. It SHOULD NOT grow
an operation-specific chain of `if profile == ...` branches.

### 13.2 CLI preset

CLI sessions use the canonical project image read-only, a private `.changes`
file if required, and private logs/tmp/HOME/XDG state. They receive no source
bridge and a disabled source-change capability.

Multiple CLI sessions MAY execute concurrently against the same artifact.

### 13.3 Agentic preset

Agentic sessions use the canonical project image and a named staging
area. Their durable state is source-form staging plus logs/results, not a saved
image.

An agentic process MAY remain alive for a development loop. If it exits or
crashes, the image state is disposable and MUST be reconstructible by loading
the canonical project artifact plus the staging overlay.

### 13.4 GUI preset

The normal GUI workbench owns a mutable workspace and attaches exclusively to a
named staging area (`gui-default` by default). Its source-change capability is
interactive and its persistence capability supports save, discard, and cancel.
The same area MAY pass sequentially between GUI and agentic contexts, but MUST
NOT have concurrent writers.

### 13.5 Disposable GUI-tool preset

A GUI frontend does not imply persistence. A read-only GUI tool such as the
build map uses the canonical image, disabled source changes, discard
persistence, a registered entrypoint, and explicit input resources.

## 14. Capability model

### 14.1 Source-change capability

All KlibGen operations that export, refactor, promote, or otherwise modify
project source MUST go through one installed capability interface. The
implementations are:

- `KGDisabledSourceChanges` for CLI and read-only tools;
- `KGStagingSourceChanges`, containing repository lookup, change counting,
  export, and host promotion requests; and
- `KGStagedSourceChanges` and `KGInteractiveSourceChanges` as compatibility
  subclasses selecting the common named-staging behavior.

Conceptual protocol:

```smalltalk
KGSession current sourceChanges
    exportChangedDefinitions: definitions
```

The disabled implementation MUST perform no write and return a structured
denial such as:

```smalltalk
KGOperationResult denied
    operation: #exportChangedDefinitions;
    reason: #readOnlySession
```

It SHOULD record the denied request in session diagnostics. UI controls SHOULD
also query capability availability and render themselves disabled, but the
capability remains the enforcement point for indirect invocations.

Exporters SHOULD NOT accept arbitrary authoritative destination paths in normal
operation. They receive their target from the capability.

### 14.1.1 Agentic refactoring protocol

Structural source changes SHOULD use a versioned curated adapter when one is
available. The image tool registry MUST expose read-only catalog and describe
operations, plus applicability, preview, and apply operations restricted to a
headless session with the named-staging source capability. Stable adapter IDs
are independent of the installed Refactoring Browser class names; the catalog
MAY additionally report unwrapped image refactoring classes as observed,
unsupported inventory.

Applicability and mutation requests use the extensible schema-v1 refactoring
record. Preview MUST execute only in a disposable image attached exclusively to
the requested staging area and MUST return:

- structured semantic changes and bounded exact before/after Tonel files;
- warnings with stable IDs and their acknowledgement state;
- explicit unsafe features;
- impact counts and the staging name, generation, and Git head; and
- a deterministic plan ID bound to the normalized request, adapter version,
  project artifact, staging identity, warnings, and exact Tonel result.

Apply MUST regenerate the complete plan, require the caller's exact expected
plan ID, and export through `KGStagingSourceChanges` only after equality is
established. It MUST NOT promote. A changed artifact, staging generation/head,
warning set, adapter version, or output therefore requires another preview.

AST rewriting uses `RBParseTreeRewriter` over an explicit bounded set of
methods, classes, or `KlibGenGt-*` packages. Executable AST pattern blocks are
disabled by default, require a request-level opt-in, and MUST appear in the
unsafe-feature result. Limits on traversed methods, transformed methods,
semantic changes, and serialized Tonel size MUST be enforced. No refactoring
adapter may target or persist changes outside project-owned packages.

### 14.2 Persistence capability

Image save/close behavior MUST similarly be represented by a capability:

- disposable sessions cannot publish or retain a saved image;
- workspaces can save atomically, discard, or cancel close; and
- entrypoints can ask what behavior is available without checking a global
  launch mode.

The disabled implementation SHOULD make save controls unavailable and return a
structured denial if invoked indirectly.

### 14.3 Threat model

Capabilities are an architectural guard against accidents and forgotten policy
checks. They do not prevent Smalltalk code from using reflection, finding the
repository, invoking filesystem APIs, replacing globals, or spawning `git`.
V0.2 MUST document this limitation and MUST NOT imply OS-level sandboxing.

## 15. Source capture, staging, and promotion

### 15.1 Canonical project loading

The project-source step MUST load source materialized from one exact repository
snapshot. For JJ, the resolved record MUST include the commit/change identity
used for exact materialization and provenance, together with a deterministic
digest of the effective selected tree. Artifact identity MUST use that tree
digest rather than commit/change identity, so metadata-only revision rewrites
reuse the same artifact.

The build bridge is temporary. It MUST NOT be copied into every later session.

After loading and before publication, the project-source step MUST export every
project `.st` definition with the pinned runtime's Tonel writer and compare the
result byte-for-byte with its input. Any difference is a build failure. This is
a serialization canonicality check, not a method-body pretty-printer. Named
staging attachment MUST run the same check after rebase and before launching a
GUI or agentic image, so an immediate Export without image-side edits is an
empty source diff.

### 15.2 Staging overlay

A staging area stores source-form changes, base identity, Git head, generation,
exclusive lease, changed-package metadata, rebase result, and promotion status.
Every attachment first reconciles a changed Git HEAD, then performs a file-level
three-way rebase across recorded base, overlay, and current authoritative
source. Unchanged staged paths adopt current source; unchanged authoritative
paths keep staged content; equal changes merge trivially. Overlapping
add/modify/delete/rename changes mark the area conflicted without rewriting its
base or overlay and prevent attachment and promotion.

One lease records context kind, session/workspace identifier, host PID, and
generation. A live or dirty-reserved lease rejects a second writer. An
abandoned PID lease MAY be recovered. A saved GUI with unexported source changes
retains a reservation until it exports or explicitly discards those changes.

Staging MUST NOT require rebuilding the canonical project image after every
experimental edit. Promotion into authoritative source is the event that makes
the next canonical project key change.

### 15.3 Promotion

Host-side promotion MUST:

- be explicit;
- be serialized;
- restrict paths/packages to configured project ownership;
- compare the staging base with current authoritative source;
- reject or report package/path conflicts rather than overwrite them;
- leave reviewable repository working-copy changes; and
- record the promoted staging identity and result.

Filesystem application MUST be prepared completely and rolled back on I/O
failure. After success the staging base advances to the promoted overlay without
rewriting the Git repository of an attached context. Promotion does not create
a JJ change or commit.

The existing package-scoped conflict checks are a foundation to retain. V0.2
does not require the coordinator to create a JJ commit automatically.

### 15.4 GUI export

The GUI MUST expose two distinct actions. **Export** commits image changes to
the attached staging Git repository. **Promote** sends a structured request to
the host, which validates session ID, staging name, lease, and operation before
performing conflict-checked authoritative promotion. A failed export
notification does not discard its Git commit; host status, attachment, rebase,
or promotion reconciles the changed HEAD into the staging record.

## 16. GUI workspace lifecycle

### 16.1 Layout and ownership

The default workspace conceptually contains:

```text
workspaces/gui-default/
  image/
  changes/
  home/
  config/
  data/
  session.json
  workspace.json
```

The writable Git repository lives under the named staging area, not under the
workspace. Workspace records include `stagingArea` and `stagingGeneration`.
The legacy schema-v1 private repository is migrated automatically into
`gui-default`; its original files remain until explicit workspace reset.

Runtime/native data SHOULD be linked from the immutable store rather than
copied into the workspace.

### 16.2 Fresh start

A fresh start initializes or replaces the workspace from the current canonical
project artifact. Replacement MUST be explicit through `--fresh` or an
equivalent command. If replacing a non-empty saved workspace can lose unsaved
state, the coordinator MUST require a clear confirmation or recoverable local
backup policy.

### 16.3 Resume

Ordinary `just gui` SHOULD resume `gui-default` when it exists. If its staging
generation changed and the saved image reports `sourceChangeCount = 0`, the
coordinator reloads the safe rebased overlay while preserving saved tools and
layout. If the image has unexported changes, handoff or reload MUST be refused.
Selecting a different staging name for an existing workspace requires
`--fresh`.

### 16.4 Save and close

The in-image close interaction chooses save, discard, or cancel. Smalltalk
performs the chosen operation and atomically writes a structured completion
record. Python waits for that record and the process exit.

One temporary predecessor MAY exist during atomic save or crash recovery, but
it is an implementation detail and MUST be replaced/removed after successful
save. It is not a public snapshot history.

### 16.5 Abnormal termination

If no valid completion record is produced, the coordinator records an abnormal
termination and preserves only the existing workspace state plus bounded logs.
It MUST NOT publish an additional immutable snapshot or full failed run.

## 17. Generic tool model

### 17.1 Registered entrypoints

The canonical project image MUST contain a generic session bootstrap and tool
registry. A tool is selected by a stable identifier and opened with validated
session inputs.

Conceptually:

```smalltalk
KGToolRegistry
    toolNamed: KGSession current entrypoint
    openWith: KGSession current inputs
```

Registration MAY use explicit registration, subclasses, or pragmas. Adding a
tool MUST NOT require another conditional in `KGToolRunner` or a tool-specific
image save/startup handler.

### 17.2 Session inputs

Each external input MUST declare:

- logical name;
- path or inline value;
- media type;
- schema/version where applicable;
- digest;
- access (`read-only` or `private-writable`); and
- lifetime/cleanup policy.

The host MAY generate inputs immediately before launch. The image MUST receive
them through `KGSession`, not undocumented environment variables or class-side
temporary state.

### 17.3 Cold disposable GUI startup

Cold start of a tool such as build-map is:

1. resolve the canonical project artifact;
2. generate and digest the inventory input;
3. create a lightweight session directory and manifest;
4. present the shared runtime/native bundle and canonical image;
5. start GT once;
6. bootstrap, validate, and dispatch the registered tool; and
7. exit without saving, retaining only the bounded result/log record.

There is no preparation VM, preparation save, source bridge, or complete
writable run.

### 17.4 Reuse of a compatible GUI

With `auto` or `reuse-compatible-gui`, the coordinator MAY submit a structured
`tool.open` request to an active GUI control service. Reuse is allowed only if
the service confirms compatible:

- project build key;
- session/tool protocol version;
- registered entrypoint version; and
- required input schemas/capabilities.

If no compatible GUI is active, launch falls back to the single-start cold path.
The command's correctness MUST NOT depend on a persistent tool host.

### 17.5 Build-map migration

The build-map itself remains an ordinary model with Phlow/Mondrian views. Its
inventory schema MUST stop assuming:

- literal `L01` through `L07` columns;
- contexts as artifact owners;
- retained run, attempt, and snapshot nodes; and
- context-qualified artifact paths.

The v2 inventory SHOULD include:

- recipe definitions and resolved step sequences;
- globally shared artifacts and recipe references;
- checkpoint and parent relationships;
- native/runtime bundles;
- the GUI workspace;
- active lightweight sessions;
- staging areas;
- last build/execution status records;
- explicit pins, if retained; and
- measured storage inside and outside the main store where practical.

Graph layout MUST derive order from recipe sequence and dependency edges.

## 18. Session execution views

A session view SHOULD contain only what the selected preset needs:

```text
sessions/<session-id>/
  runtime -> immutable runtime artifact
  lib -> immutable native bundle
  image -> canonical image or private writable materialization
  changes/
  home/
  config/
  cache/
  tmp/
  logs/
  inputs/
  session.json
  completion.json
```

Read-only CLI and disposable tools SHOULD use the canonical image without a
full copy when the VM permits. If Pharo path or save behavior requires a private
image, only the minimal writable image files SHOULD be reflinked/copied; runtime,
native libraries, sources, and immutable data remain linked.

Successful disposable sessions remove transient paths after their result and
logs are finalized. Failed sessions do the same after writing diagnostics.

## 19. Lifecycle protocol

### 19.1 Startup

1. Python resolves the recipe and artifact.
2. Python validates the artifact and preset.
3. Python creates private paths and writes `session.json` atomically.
4. Python starts the appropriate VM launcher with only documented environment
   variables pointing to the manifest and protocol paths.
5. `KGSessionBootstrap` reads the manifest, installs provenance/capabilities,
   and writes a `ready` record.
6. The bootstrap dispatches the workbench, tool, or structured request.

### 19.2 Completion

Smalltalk writes a structured completion record containing:

- session identifier;
- outcome (`succeeded`, `failed`, `saved`, `discarded`, `cancelled`);
- entrypoint/tool result location;
- save result where applicable;
- staging/export result where applicable;
- pending `sourceChangeCount` where source changes are enabled;
- timestamps; and
- protocol/schema version.

The record MUST be atomically published. Python combines it with process exit,
stdout/stderr, and resource diagnostics. A successful process exit without the
required completion record is an abnormal protocol failure.

### 19.3 No save inference

Python MUST NOT infer a save from:

- changed image hashes;
- `.changes` content;
- textual `SNAPSHOT` or `QUIT` markers; or
- process exit code alone.

These may remain diagnostic evidence during migration but are not lifecycle
authority.

## 20. Failures and diagnostics

### 20.1 Build status

For each step key, store a small mutable status record separate from immutable
artifacts:

```json
{
  "stepKey": "...",
  "usableArtifact": "...",
  "lastAttempt": {
    "status": "failed",
    "startedAt": "...",
    "finishedAt": "...",
    "exitCode": 1,
    "phase": "contract",
    "log": "...",
    "diagnostics": "..."
  }
}
```

A new attempt replaces `lastAttempt`. The implementation MAY keep a small
bounded rotated log history, but no log record owns a complete image.

### 20.2 Tool/test status

Each logical tool/test command records its latest structured result,
stdout/stderr, session description, and stack dump or debugger report when
available. Re-running updates the current diagnostic record.

The common “write a test, fail, debug, fix, pass” loop MUST not leave full failed
execution directories behind.

### 20.3 Partial cleanup

Cleanup happens after enough information has been extracted to diagnose the
failure. A debug flag MAY temporarily preserve a build workspace until the next
attempt or an explicit cleanup, but this MUST be opt-in, visibly storage-heavy,
and excluded from routine behavior.

## 21. Concurrency and locking

The coordinator MUST provide:

- one build/publication lock per artifact key;
- atomic artifact and reference publication;
- one exclusive lock per mutable GUI workspace;
- one exclusive writer lock per staging area;
- a promotion lock protecting authoritative source updates; and
- coordination preventing GC from deleting actively used artifacts.

Independent read-only CLI and disposable GUI sessions MAY execute in parallel
against one canonical image and native bundle.

A builder that finds another process building the same key SHOULD wait for and
reuse the published result. It SHOULD NOT create a second long-lived attempt.

## 22. Storage layout

The initial layout SHOULD be:

```text
.klibgen/v2/
  store/
    runtime/<platform>/<key>/
    image/<platform>/<key>/
  refs/
    recipes/
    targets/
  status/
    builds/
    tools/
  workspaces/
    gui-default/
  staging/
  sessions/
  logs/
  locks/
  tmp/
```

All deletion routines MUST resolve and validate that their target is below the
configured v2 state root. Store, workspace, staging, and transient session
ownership MUST be distinguishable without reverse-engineering directory names.

Vendor downloads and source-build worktrees MAY remain outside this root, but
inventory and cleanup reports MUST identify their paths and, where practical,
their size/retention status.

## 23. Retention and cleanup

Routine GC SHOULD retain:

- artifacts referenced by current default recipe/target refs;
- ancestors required by those artifacts;
- the artifact backing the current GUI workspace;
- artifacts used by active sessions/builds;
- explicit user pins; and
- a small configured number of recently used expensive checkpoints, if useful.

Routine GC SHOULD remove:

- unreferenced temporary alternative artifacts after a grace period;
- abandoned partial build workspaces;
- completed session directories after results/log extraction;
- obsolete rotated diagnostics beyond their bound; and
- failed attempt payloads.

The GUI workspace and staging areas are explicit mutable roots and MUST NOT be
removed by routine GC. Their status and size MUST be visible.

Forced rebuild MUST rebuild/verify the requested key without archiving the
previous complete artifact merely because the operation was forced. A valid
existing artifact remains usable until the replacement is successfully
published or verified.

## 24. Commands and user-facing workflows

The exact CLI syntax may evolve, but the coordinator MUST support:

- resolve and display a recipe/target;
- build a recipe through a named role or final checkpoint;
- derive/execute a locally defined replacement recipe;
- start CLI, agentic, GUI, and registered-tool sessions;
- start GUI fresh or resume the default workspace;
- inspect static build and current session provenance;
- list artifacts, refs, workspaces, staging areas, active sessions, and statuses;
- diagnose the latest failure for a build/tool/test;
- promote staged source with conflict checks;
- verify an artifact;
- inventory storage and relationships; and
- preview/apply routine GC.

Existing `just` commands SHOULD remain convenient front doors. In particular:

- `just test`, `just test-one`, `just eval`, and similar commands use the CLI
  preset;
- `just gui` resumes the default GUI workspace;
- `just gui-fresh` or an equivalent explicit option replaces it from canonical
  project state;
- `just build-map` uses warm compatible-GUI reuse or a disposable GUI tool; and
- source promotion/export remains an explicit visible operation.

Machine-facing commands MUST support structured JSON output and stable schema
versions.

## 25. Compatibility and migration rules

V0.2 state MUST live under a distinct schema/root such as `.klibgen/v2` during
migration. The implementation MUST NOT reinterpret v0.1 runs or snapshots as
v0.2 workspaces.

Migration MAY offer one explicit import of the selected v0.1 GUI snapshot into
`gui-default`. Otherwise, users rebuild canonical checkpoints and start fresh.

The following v0.1 concepts are removed from the v0.2 public model:

- context-owned immutable artifact trees;
- mandatory `L01`–`L07` identities;
- full writable run directories for each operation;
- retained failed runs and build attempts;
- append-only GUI snapshots and current-snapshot pointers;
- forced-rebuild image archives;
- separate CLI/GUI/agentic canonical images;
- special fresh-test state roots; and
- tool-specific prepare/save/restart launchers.

Useful v0.1 mechanisms to preserve or adapt include:

- exact JJ source capture;
- atomic read-only artifact publication;
- build and retention locks;
- contract scripts and structured results;
- package-scoped conflict-checked promotion;
- GUI event/control protocols;
- JSON command output;
- host-process diagnostics; and
- build inventory/visualization.

## 26. Required invariants

An implementation conforming to v0.2 MUST maintain these invariants:

1. Authoritative project source is outside canonical images.
2. No failed build replaces a successful artifact or recipe reference.
3. Artifact identity is independent of recipe/preset name when effective inputs
   are identical.
4. CLI, agentic, GUI, and build-map normally share one project artifact.
5. Project-source changes do not invalidate lower checkpoints.
6. Every effective transformation input is represented in its step key.
7. A read-only KlibGen source mutation returns a structured denial and writes
   no source.
8. Promotion into `src/` is explicit and conflict-checked.
9. Only a persistent workspace may retain mutable saved image state by default.
10. A disposable failure retains diagnostics, not a complete execution image.
11. Smalltalk emits authoritative orderly completion/save state.
12. GUI resume reloads a changed staging generation only from a clean exported
    image; unexported changes reserve the staging area and refuse handoff.
13. Read-only sessions may run concurrently without copying immutable runtime
    and native bundles.
14. Build-map and other tools dispatch through a generic registry and explicit
    inputs.
15. Cleanup never deletes outside the selected state root or an explicitly
    managed external cache/worktree.

## 27. Acceptance scenarios

### 27.1 Default cold build

From an empty v2 state root, building `project` constructs and validates the
runtime/native, base, dependency/setup, and project checkpoints. Manifests and
in-image provenance agree. A second build performs no image transformation.

### 27.2 JJ metadata-only rewrite

Changing only JJ metadata, including a working-copy description or change
boundary, preserves the project artifact key when the effective selected tree
is unchanged. The newly resolved commit and change IDs remain visible as
current source provenance, and an existing GUI workspace is not reported stale.

### 27.3 Project-source edit

After changing a file under authoritative project source, building `project`
reuses runtime, base, and dependency/setup artifacts. Only project-source and
project-finalize execute, and one new project image is published.

### 27.4 Shared launch presets

CLI, agentic, fresh GUI, and build-map resolve the same project artifact key.
No preset-specific canonical image appears in the store.

### 27.5 CLI denial

Direct and indirect calls to the KlibGen export API in a CLI session return
`readOnlySession`; authoritative source and staging remain unchanged. The
attempt is diagnosable.

### 27.6 Agentic iteration

An agent exports edits to staging, restarts or reuses its disposable process,
loads the overlay, and retests without rebuilding the canonical project image.
Promotion performs conflict checks and changes authoritative source only after
success.

### 27.7 GUI save/resume

Fresh GUI initializes `gui-default`. Save updates that workspace without
creating an immutable snapshot history. Ordinary `just gui` resumes it. If the
repository changed, the image opens with a stale-provenance warning.

### 27.8 Disposable build-map

With no compatible GUI running, build-map generates inventory and starts GT
once on the canonical image. It creates no source bridge and retains no image on
close. With a compatible GUI running, the tool opens through structured IPC
without a new VM.

### 27.9 Parallel read-only operations

Two tests and a build-map input generation can run concurrently against the
same project/runtime artifacts. Their transient paths and result records do not
collide.

### 27.10 Failed project rebuild

A broken project edit fails its contract. The previous project artifact remains
referenced and usable. The latest failure record points to logs/structured
diagnostics, and the partial image is removed.

### 27.11 Alternative GT

A local recipe replaces `gt-patches` or `pharo-gt` with a worktree-backed step.
The alternative builds from the lowest changed key and can launch any preset.
The default target and its artifacts remain unchanged until the default recipe
is explicitly updated.

### 27.12 Native bundle sharing

Multiple artifacts and concurrent sessions present one immutable GT native
library bundle through the selected link strategy. Inventory reports the bundle
once, and session cleanup does not delete it.

### 27.13 Failure-loop storage bound

Repeatedly failing and rerunning one test updates/rotates bounded diagnostics.
It does not create a sequence of retained full image/run directories.

## 28. Deferred decisions

Implementation may defer these without changing the architecture:

- whether `pharo-gt` merits a checkpoint separate from the final base image;
- symlink versus hardlink layout for each GT native-library family;
- whether a project dependency image and stable setup image should be physically
  separate after measurement;
- the exact tool-registration mechanism;
- the exact transport for warm `tool.open` requests;
- whether named GUI workspaces beyond `gui-default` are useful;
- the bounded diagnostic rotation count;
- cache grace periods and recent-artifact policy;
- importing one v0.1 snapshot; and
- RELEASE distribution construction.

These decisions MUST be informed by measured startup time, bytes written,
allocated storage, correctness, and implementation complexity—not by preserving
v0.1 object categories.
