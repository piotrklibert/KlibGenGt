# KlibGen-GT recipe/session architecture: implementation plan

Version: 0.2 (proposed)

Companion specification:
`klibgen-gt-recipe-session-architecture-v0.2.md`

Historical baseline:
`klibgen-build-current-implementation.md`

## 1. Objective

Replace the current context/layer/run/snapshot implementation with a smaller
recipe/artifact/session system that:

- builds one shared canonical project image;
- retains only economically useful checkpoints;
- reuses runtime and native libraries instead of copying them into every run;
- represents CLI, agentic, GUI, and GUI tools as launch presets;
- gives Smalltalk explicit build/session provenance and capabilities;
- saves one mutable GUI workspace rather than a snapshot history;
- uses staging as durable agentic state;
- keeps latest structured diagnostics without complete failed images; and
- makes alternative VM/Pharo/GT/dependency configurations ordinary Python
  recipe replacements.

The implementation is complete when the v0.2 acceptance scenarios pass, the
normal `just` workflow uses v0.2, and the obsolete v0.1 machinery can be removed
without losing a required workflow.

## 2. Delivery strategy

### 2.1 Build a short-lived v2 path beside v1

Use `.klibgen/v2/` and versioned v2 schemas while implementing. Keep the current
commands operational long enough to compare behavior and recover from early v2
defects. Do not build a permanent compatibility abstraction spanning both
models.

The migration should be a sequence of vertical slices:

1. resolve a recipe;
2. build and reuse the canonical project artifact;
3. run one read-only tool without a full run copy;
4. support staging and promotion;
5. support GUI fresh/save/resume;
6. move build-map and inventory; and
7. cut over commands and delete v1-only state management.

### 2.2 Keep authoritative source unchanged

Do not migrate source ownership into images. Continue loading exact JJ source
and leaving promoted changes reviewable in the outer working copy.

### 2.3 Measure every storage-sensitive choice

Before committing to symlink, hardlink, reflink, or copy behavior, measure:

- apparent and allocated bytes;
- bytes written during build/start/save;
- cold and warm wall time;
- number and size of complete image files retained; and
- whether GT/VM/native lookup behavior remains correct.

### 2.4 Prefer deletion over adapters after cutover

Once a v2 workflow replaces a v1 workflow and its migration window has closed,
delete the old branch and tests. Do not preserve contexts, runs, attempts, and
snapshots as aliases for recipes, sessions, statuses, and workspaces.

## 3. Proposed code organization

The exact module split may be adjusted while implementing. The intended
responsibilities are:

| Module | Responsibility |
| --- | --- |
| `core.py` | repository discovery, canonical JSON/digests, common errors |
| `recipes.py` | immutable steps/recipes/targets/presets, replacement/truncation, defaults |
| `resolution.py` | locks, JJ/Git/worktree identities, platform/ABI facts, resolved recipes |
| `store.py` | v2 paths, artifact/status/reference records, atomic publication, verification |
| `builder.py` | generic step executor, build workspace, checkpoint policy, contracts |
| `sessions.py` | session manifests/views, process lifecycle, results, completion protocol |
| `staging.py` | staged overlays and conflict-checked source promotion |
| `workspaces.py` | GUI workspace fresh/resume/save/lock/staleness behavior |
| `tools.py` | host tool definitions, input producers, cold/warm dispatch |
| `inventory.py` | v2 inventory and storage accounting |
| `retention.py` | v2 liveness and bounded cleanup |
| `cli.py` | parsing and thin dispatch into the services above |

Reuse `processes.py`, `coordination.py`, `host_tools.py`, and relevant parts of
`ui_control.py` where their semantics still fit.

Likely v1 modules to remove or radically shrink after cutover:

- `artifacts.py` (fixed L01-L07 builders and context-qualified store);
- `contexts.py`;
- `runs.py`;
- snapshot/run portions of `lifecycle.py`;
- v1 graph logic in `inventory.py`;
- v1 reachability logic in `retention.py`; and
- profile/context branching in `operations.py` and `cli.py`.

Do not begin by renaming these concepts. Introduce the v2 domain types, route a
complete workflow through them, then delete the v1 implementations.

## 4. Proposed state and schema files

Add versioned schemas before producers depend on them:

```text
build/schemas/v2/
  artifact.schema.json
  build-status.schema.json
  resolved-recipe.schema.json
  session.schema.json
  completion.schema.json
  staging.schema.json
  workspace.schema.json
  inventory.schema.json
  tool-request.schema.json
  tool-response.schema.json
```

Checked-in Python defines default recipes and presets. A suggested location is
`build/recipes.py`, imported through a narrow loader that validates the returned
objects. Temporary alternatives may use an explicitly selected local recipe
module. Loading Python recipe code is trusted local configuration, not a data
deserialization format.

Generated state initially lives at:

```text
.klibgen/v2/
  store/
  refs/
  status/
  workspaces/
  staging/
  sessions/
  logs/
  locks/
  tmp/
```

## 5. Phase 0 — baseline, safety net, and measurements

### Purpose

Establish observable behavior and storage/startup baselines before changing the
engine.

### Work

1. Record the current repository revision and expected pinned GT/runtime inputs.
2. Make host tests runnable through one documented command.
3. Add a measurement helper that records:
   - command wall time;
   - apparent bytes and allocated blocks below the selected state root;
   - count/size of `.image`, `.changes`, and native-library files;
   - bytes written when the host exposes that metric; and
   - number of VM starts.
4. Capture representative v1 measurements for:
   - cold default build;
   - unchanged build;
   - one project-source edit and rebuild;
   - passing and failing `test-one`;
   - fresh GUI startup/save/close;
   - resumed GUI startup/close; and
   - cold build-map startup/close.
5. Add fixtures/fakes for filesystem publication and VM process protocols so
   host tests do not require a complete GT download for every case.
6. Preserve a manual recovery note for a selected v1 GUI snapshot during the
   transition.

### Files

- `build/tests/`
- a small measurement helper under `python/klibgen_build/` or `scripts/`
- `docs/` for the benchmark procedure/results when captured

### Exit criteria

- Existing host tests pass in the intended development environment.
- A baseline report can compare complete-image count, allocated storage, wall
  time, and VM starts for each scenario.
- No production behavior changes yet.

## 6. Phase 1 — recipe, target, and resolution model

### Purpose

Replace fixed L-number/context configuration with immutable Python composition
without building artifacts yet.

### Work

1. Implement immutable `Step`, `Recipe`, `LaunchPreset`, and `Target` values.
2. Implement and test:
   - `replace(role, step)`;
   - `drop_last(count)`;
   - `through(role)`;
   - `append(*steps)`;
   - role uniqueness;
   - adjacent input/output compatibility; and
   - deterministic serialization.
3. Define the standard roles:
   - `runtime`;
   - `pharo-gt`;
   - `gt-patches`;
   - `build-support`;
   - `project-dependencies`;
   - `project-setup`;
   - `project-source`; and
   - `project-finalize`.
4. Define `BASE`, `PROJECT`, and launch presets for CLI, agentic, GUI, and
   build-map.
5. Implement resolution of:
   - pinned archives;
   - Git commits;
   - JJ repository/tree identity;
   - clean and dirty worktrees;
   - platform/ABI facts; and
   - declared tool/environment inputs.
6. Implement step keys from only effective declared inputs.
7. Create a structured `recipe resolve` result showing every role, effective
   input, key, checkpoint decision, and replacement origin.
8. Add a lint/test that every step implementation declares the scripts,
   templates, and source paths that influence it.

### Design constraint

Do not use a package-wide Python digest. Each step implementation needs an
explicit version/digest boundary. Avoid depending only on function source text,
which can omit called helpers; use a declared implementation-input set plus a
small protocol version.

### Tests

- Same inputs under different recipe/target names produce the same keys.
- CLI, agentic, GUI, and build-map resolve one project key.
- Replacing `pharo-gt` changes it and all descendants, but not unrelated runtime
  inputs where the dependency graph permits reuse.
- Changing a project source fixture changes only `project-source` and
  descendants.
- Changing a build-support script invalidates `build-support` and descendants.
- Changing every effective stage script changes the responsible key.
- A dirty worktree identity changes when effective content changes.
- Replacement and truncation errors are precise and structured.

### Exit criteria

- Default and example alternative recipes resolve deterministically.
- The resolved-recipe schema validates all emitted records.
- No builder logic branches on CLI/GUI/AGENTIC profiles.

## 7. Phase 2 — v2 store, references, status, and publication

### Purpose

Create globally shared artifacts and diagnostics independent of recipe names.

### Work

1. Implement `BuildPathsV2` or update `BuildPaths` with explicit v2 paths.
2. Implement typed artifact locations by platform/ABI and key.
3. Implement per-key locks and atomic attempt-to-artifact publication.
4. Make published payloads read-only.
5. Implement manifest validation and inexpensive reuse verification.
6. Implement atomic recipe/target reference records.
7. Implement mutable per-step-key latest status records with bounded log
   rotation.
8. Ensure failure cleanup removes partial payloads while keeping:
   - previous successful artifact;
   - current reference;
   - structured failure result; and
   - logs/stack diagnostics.
9. Implement safe stale-temp cleanup under the v2 root.

### Reuse from v1

Adapt rather than copy blindly:

- `copy_reflink()` where a private image is genuinely required;
- `artifact_lock()` semantics, but key it globally;
- atomic publication logic from `_publish()`;
- retention coordination; and
- canonical JSON/digest helpers.

### Tests

- Two recipes publishing the same key converge on one directory.
- Concurrent builders result in one publication and one reused result.
- Publication interruption leaves no apparently successful artifact.
- A failed rebuild leaves the prior successful reference untouched.
- Reuse rejects malformed manifests, missing critical payloads, wrong keys, and
  incompatible platform/ABI.
- All deletion targets are proven below the selected v2 state root.

### Exit criteria

- A synthetic artifact can be built, failed, retried, reused, and garbage
  collected without context-qualified duplication.
- Repeated failures do not increase complete-image count.

## 8. Phase 3 — native/runtime bundle and link strategy

### Purpose

Store the approximately 340 MB GT native-library payload once and stop copying
it through images and sessions.

### Work

1. Inventory the downloaded GT bundle into:
   - VM/launchers;
   - native libraries;
   - `.sources` and immutable support data;
   - image-owned files; and
   - files that GT mutates at runtime.
2. Spike directory symlinks for native/runtime paths.
3. Where symlinks fail, test hardlinks with the required directory layout.
4. Use reflinks only for files proven writable or path-sensitive.
5. Keep read-only bind mounts out of the default path unless links cannot meet
   the correctness requirement.
6. Define additive native bundles for project libraries such as SQLite3.
7. Record the selected presentation strategy and source bundle key in artifact
   and session manifests.
8. Add an integrity check that a session cannot silently modify a canonical
   linked file.

### Required experiments

- Start the CLI VM from a view whose launchers/libraries are symlinked.
- Start the GUI launcher from the same view.
- Exercise FFI/native-library discovery used by current tests.
- Save a GUI workspace and confirm linked native files are unchanged.
- Measure startup and bytes written for symlink, hardlink, and reflink variants.

### Exit criteria

- One runtime/native artifact can serve multiple image artifacts and concurrent
  sessions.
- The chosen strategy works for CLI, GUI, and current SQLite3 examples.
- The benchmark identifies any files that still require private copies.

## 9. Phase 4 — checkpointed default build

### Purpose

Build the default runtime/base/dependency/project path through the generic
recipe executor.

### Work

1. Implement a generic build executor that:
   - resolves the nearest reusable checkpoint;
   - creates one private build workspace;
   - executes ordered steps until the next checkpoint;
   - records a result per step;
   - runs declared contracts;
   - publishes only the checkpoint payload; and
   - cleans the workspace on success or diagnosed failure.
2. Port runtime acquisition into the `runtime` step.
3. Port clean GT acquisition/construction into `pharo-gt`.
4. Port the actual default GT image patch into `gt-patches`, eliminating the
   current mismatch where a worktree affects provenance but is not generally
   loaded.
5. Install generic v2 image support in `build-support` and publish the base
   checkpoint.
6. Port SQLite3 and other pinned dependencies into
   `project-dependencies`.
7. Port stable setup into `project-setup` and publish the dependency/setup
   checkpoint according to measured policy.
8. Materialize exact JJ project source once, load it in `project-source`, and
   remove the temporary bridge before publication.
9. Run project contracts and install final provenance/session hooks in
   `project-finalize`; publish the canonical project checkpoint.
10. Keep distribution construction out of this phase.

### Image-support source decision

Before implementing `build-support`, choose one explicit source boundary:

- a small Tonel package under `build/` loaded independently of ordinary project
  source; or
- a dedicated package under `src/` whose digest is owned by the build-support
  step and excluded from the late project-source digest.

The first option keeps generic bootstrap code visibly separate. The second
integrates better with current GT development tools. In either case, editing
ordinary project packages must not invalidate the base image, while editing the
bootstrap package intentionally does.

### Tests

- Empty-root build publishes only configured checkpoints.
- Unchanged rebuild starts no VM and writes no image.
- Project edit reuses base and dependency/setup checkpoints.
- Dependency edit reuses base and rebuilds only dependency/setup and project.
- GT patch edit reuses runtime/clean input where possible and rebuilds the
  descendants.
- Contract failure preserves the old project artifact and latest diagnostics.
- In-image provenance matches host manifests byte-for-byte after normalization.
- All effective stage scripts are represented in keys.

### Exit criteria

- `PROJECT` builds and passes contracts from an empty v2 state root.
- CLI/agentic/GUI/build-map targets resolve the same project artifact.
- A source-only rebuild produces one new project image, not profile-specific
  copies.

## 10. Phase 5 — Smalltalk session protocol and capabilities

### Purpose

Make the image explicitly aware of build/session provenance and centralize
mutation/save policy.

### Candidate image-side classes

- `KGBuildProvenance`
- `KGSession`
- `KGSessionBootstrap`
- `KGOperationResult`
- `KGSourceChangesCapability` (protocol/abstract role)
- `KGDisabledSourceChanges`
- `KGStagedSourceChanges`
- `KGInteractiveSourceChanges`
- `KGImagePersistenceCapability`
- `KGDiscardImagePersistence`
- `KGWorkspaceImagePersistence`
- `KGToolRegistry`
- a small registered-tool protocol

Final names may change. All classes and public methods must follow repository
class-comment and type-pragma rules, and `KlibGenGt`'s class index must be
updated where applicable.

### Work

1. Define and validate `klibgen.session/1` and completion schemas.
2. Load static build provenance into each checkpoint image.
3. Implement one startup hook that reads the session manifest before tool or
   workbench dispatch.
4. Install source-change and image-persistence capability objects from the
   validated preset.
5. Implement structured denial for disabled operations.
6. Route existing export functionality through the capability instead of a
   boolean/profile check.
7. Make `KGExportButton` render disabled/unavailable when export is denied.
8. Add authoritative ready/completion record writing by atomic rename.
9. Define protocol errors for missing/incompatible manifests and completion
   records.
10. Keep compatibility emission of old GUI markers only until the v2 host no
    longer consumes them.

### Tests

- Build provenance survives save/resume unchanged.
- Session provenance changes on every fresh/resumed/tool launch.
- CLI direct export and button/indirect export both write nothing and return a
  structured denial.
- Agentic export writes only to its assigned staging area.
- GUI export uses only its assigned interactive capability.
- Disposable persistence denies save.
- Workspace persistence reports save/discard/cancel explicitly.
- Unknown schema/capability/entrypoint fails before tool execution.
- Completion records are atomically visible and session-ID matched.
- `just check-type-pragmas` and relevant SUnit tests pass from a fresh image.

### Exit criteria

- No KlibGen project-source mutation path relies on scattered `mode` checks.
- Python can distinguish orderly success/save/discard/cancel from crash without
  hashing the image or parsing `.changes` markers.

## 11. Phase 6 — lightweight headless sessions and latest diagnostics

### Purpose

Replace `create_project_run()` for CLI tools/tests with minimal disposable
session views.

### Work

1. Implement session ID, directory, manifest, path ownership, and cleanup.
2. Present the runtime/native bundle through the chosen link strategy.
3. Start from the canonical project image read-only when possible.
4. Provide only private `.changes`, HOME/XDG, tmp, inputs, logs, and result paths
   required by the operation.
5. Route `test`, `test-one`, `smoke`, `check-type-pragmas`, `eval`, code tools,
   and Lepiter tools through the generic session/bootstrap protocol.
6. Remove automatic JJ/Git source-bridge materialization from read-only sessions.
7. Store latest status per logical command/test selector; rotate only small
   logs/results.
8. Make `test-diagnose` address logical latest results (with an optional result
   ID), not retained run/attempt directories.
9. Allow multiple read-only sessions concurrently.
10. Add an opt-in `--preserve-workspace-on-failure` diagnostic escape hatch only
    if real debugging proves it necessary; keep it out of ordinary commands.

### Tests

- Passing and failing operations clean all complete image materializations.
- Failure exposes structured SUnit results and stack diagnostics.
- Repeated failure/pass cycles remain bounded in disk usage.
- Parallel sessions do not share writable paths or corrupt result records.
- No CLI session has a source bridge or enabled source capability.
- The canonical image and native bundle checksums remain unchanged.

### Exit criteria

- Normal CLI commands create no retained full run.
- Failure diagnosis is at least as useful as current structured diagnostics.
- The common test loop is faster or writes materially fewer bytes than v1.

## 12. Phase 7 — staging and conflict-checked promotion

### Purpose

Make source-form staging the durable state for agentic work and a safe boundary
for GUI exports.

### Work

1. Define staging identity, base project identity, package/path ownership,
   overlay layout, and status schema.
2. Create/list/reset named staging areas.
3. Load a staging overlay on top of the canonical project image without
   rebuilding the project checkpoint.
4. Export changed definitions/packages back into staging through
   `KGStagedSourceChanges`.
5. Adapt package validation and destination-divergence checks from
   `lifecycle.py`.
6. Serialize promotion and copy only owned packages/paths into authoritative
   source.
7. Record promotion results and leave the outer JJ working copy uncommitted for
   review.
8. Make conflicts non-destructive and actionable.
9. Support a long-lived agentic process as an optimization; make reconstruction
   from canonical image plus staging the correctness path.
10. Decide how interactive GUI export maps to staging plus host promotion while
    preserving the current one-action user experience.

### Tests

- Staged edits survive process restart without a saved image.
- Repeated staged test/refactor/export cycles do not rebuild canonical project.
- Promotion succeeds when authoritative source still matches the staging base.
- Promotion rejects same-package divergence and preserves both sides.
- Non-project package names and path traversal are rejected.
- CLI cannot name or write a staging target through the KlibGen API.
- GUI/agentic promotion events are session- and staging-ID matched.

### Exit criteria

- Agentic source editing is practical without a resumable image.
- Existing conflict-safety properties are preserved.
- GUI export remains explicit and usable.

## 13. Phase 8 — single GUI workspace and authoritative close protocol

### Purpose

Replace immutable GUI snapshots and writable runs with `gui-default`.

### Work

1. Define workspace metadata, backing project key, save generation, active PID,
   source/staging identity, and stale reasons.
2. Implement exclusive workspace locking.
3. Implement fresh initialization from the canonical project artifact using
   minimal private materialization and linked runtime/native data.
4. Implement ordinary resume directly from the mutable workspace.
5. Compare workspace provenance to current project/repository provenance and
   pass explicit stale information into `KGSession`.
6. Display a prominent in-image stale-provenance warning without auto-reloading
   code.
7. Integrate current close/save/discard/cancel hooks with
   `KGWorkspaceImagePersistence`.
8. Make Smalltalk write the authoritative completion/save record.
9. Implement atomic save with at most one temporary predecessor for crash
   safety; remove/replace it after success.
10. On abnormal exit, preserve the pre-existing/current workspace and bounded
    logs, but do not publish a snapshot or failed run.
11. Provide an explicit fresh/reset command with clear loss/recovery behavior.
12. Optionally provide a one-time import from the selected v1 snapshot after the
    native/path layout is verified.

### Tests

- Fresh GUI starts from current canonical project and records `fresh`.
- Save updates one workspace without increasing saved-image count.
- Resume records `resume` and preserves intended image state.
- Repository changes produce a stale warning but do not block resume.
- Explicit fresh replaces/reset the workspace safely.
- Save/discard/cancel and window-close paths produce correct completion records.
- Crash or forced termination produces abnormal diagnostics without a new full
  state copy.
- A second writer cannot open the same workspace.

### Exit criteria

- `just gui` resumes one saved workspace.
- `just gui-fresh` starts from the current project artifact.
- Snapshot list/select/current/refresh-generation machinery is unnecessary.

## 14. Phase 9 — registered tools and build-map cold path

### Purpose

Make GUI and headless tools easy to add and remove the build-map
prepare/save/restart cycle.

### Work

1. Implement `KGToolRegistry` and one registered-tool protocol.
2. Replace `KGToolRunner>>dispatch:request:` equality chains with registry
   lookup.
3. Convert existing code, test, eval, Lepiter, and build-map operations
   incrementally to registered entries.
4. Define host-side `Tool`/entrypoint values with input producers and required
   capabilities.
5. Pass input metadata through the session manifest: name, path/value, media
   type, schema, digest, access, and lifetime.
6. Refactor `KGBuildMapTool`:
   - remove class state used only across prepare/save/restart;
   - remove tool-specific `SessionManager` startup registration;
   - load inventory through `KGSession` inputs; and
   - open the model directly from the generic bootstrap.
7. Rewrite `launch_build_map()` as:
   - generate inventory;
   - create a disposable GUI session;
   - start GT once; and
   - dispatch `build-map`.
8. Remove `prepare-build-map.st` after no path uses it.
9. Route build-map PNG rendering through the same registry/input protocol.

### Tests

- Registering a new fixture tool requires no central dispatch edit.
- Duplicate/unknown registrations fail clearly.
- Input digest/schema/access validation occurs before open.
- Cold build-map starts one VM and creates no source bridge or saved image.
- Closing build-map leaves only bounded result/log data.
- PNG export uses explicit inputs and honors overwrite policy.
- Existing Mondrian/Phlow views remain functionally equivalent.

### Exit criteria

- Build-map cold startup is a one-process disposable session.
- `prepare-build-map.st` and its preparation save are gone.
- Tool authors have a documented minimal example.

## 15. Phase 10 — compatible-GUI tool reuse

### Purpose

Make GUI tools nearly instantaneous when the normal GUI is already running.

### Work

1. Extend `KGUiControlService` with a structured `tool.open` operation.
2. Advertise GUI compatibility data:
   - project artifact key;
   - build/session protocol version;
   - tool registry/version set; and
   - accepted input schema versions.
3. Have the host select exactly one compatible active GUI workspace process.
4. Publish tool inputs with a lifetime safe for asynchronous consumption.
5. Require an acknowledgement that inputs were opened/consumed before cleanup.
6. Open the tool in a new tab/window according to the registered tool policy.
7. Fall back to the phase-9 cold path when no compatible GUI is available.
8. Keep the transport local and reuse the existing filesystem-spool model unless
   measurement or correctness requires another IPC transport.

### Tests

- Compatible GUI receives `tool.open` and no new VM starts.
- Stale/incompatible GUI is skipped and cold start succeeds.
- Multiple candidates require deterministic selection or a clear ambiguity
  error.
- Input files are not removed before acknowledgement.
- Tool failure returns a structured response and leaves the GUI usable.

### Exit criteria

- `just build-map` uses warm reuse automatically when safe.
- Correctness does not depend on a GUI already running.

## 16. Phase 11 — v2 inventory, build map, and retention

### Purpose

Make the new system observable and keep disk use bounded by simple reachability.

### Work

1. Implement inventory schema v2 for:
   - recipes and resolved steps;
   - artifacts/checkpoints;
   - refs;
   - runtime/native bundles;
   - GUI workspace;
   - active sessions;
   - staging areas;
   - latest statuses;
   - locks/pins; and
   - known external vendor/worktree/cache storage.
2. Report apparent size, allocated blocks, file count, complete-image count, and
   component sizes. Clearly label reflink double-counting limitations.
3. Rewrite `KGBuildMap`/`KGBuildMapNode` to derive columns/order from recipe
   sequences and graph edges rather than L01-L07.
4. Remove visual assumptions about contexts, attempts, runs, snapshots, and
   pointers.
5. Implement liveness roots from refs, workspaces, active sessions/builds, and
   explicit pins.
6. Add grace-period cleanup for unreferenced alternative artifacts.
7. Delete abandoned partial workspaces/sessions and rotate bounded diagnostics.
8. Keep GUI workspaces and staging areas outside routine artifact deletion.
9. Make dry-run output exact and test it before destructive cleanup.
10. Include or at least point to vendor downloads/source builds so “total” does
    not silently omit major storage.

### Tests

- Shared artifact is counted once even when referenced by multiple targets.
- Active session/build prevents artifact deletion.
- Workspace backing artifact and explicit pins remain live.
- Old alternative artifact becomes collectible after grace/pin rules.
- Failed-session cleanup leaves status/log records but no image payload.
- Build-map renders variable-length and replaced recipes.
- Cleanup cannot escape the v2 root.

### Exit criteria

- Routine GC has a small explainable root set.
- Inventory accounts for every v2 complete image and native bundle.
- Repeated normal use remains bounded without aggressive prune.

## 17. Phase 12 — CLI/just cutover and v1 removal

### Purpose

Make v2 the only ordinary workflow and delete complexity that the new model no
longer needs.

### Work

1. Make v2 the default for build/test/eval/gui/tool commands.
2. Update `justfile`, `README.md`, and `AGENTS.md` to describe recipes, presets,
   staging, workspaces, and latest diagnostics.
3. Replace context-oriented arguments with recipe/target/preset selection.
4. Provide an explicit trusted Python recipe-module option for temporary
   alternatives.
5. Remove or retire commands for:
   - `clean-runs`;
   - snapshot create/list/current/select/clear/resume;
   - run discard;
   - GUI refresh generation clearing;
   - context create/remove;
   - context-attached worktree add/remove; and
   - aggressive prune categories that no longer exist.
6. Replace context worktree workflows with recipe-step constructors pointing to
   explicit existing worktrees. A convenience command MAY create a worktree,
   but it must return a recipe fragment rather than mutate a context object.
7. Remove the separate `artifacts/fresh-layered` path. Freshness becomes an
   explicit empty v2 state root or build verification option, not a second
   unmanaged architecture.
8. Remove v1 schemas/configs/code after final migration testing.
9. Keep the historical v0.1 spec and implementation report under `docs/`.
10. Add a short migration guide, including optional v1 snapshot import or manual
    fresh-start instructions.

### Exit criteria

- All advertised `just` commands use v2.
- No normal command reads/writes v1 contexts, runs, attempts, or snapshots.
- Search confirms removed object categories have no live production references.
- A clean clone can follow README instructions successfully.

## 18. Phase 13 — final validation and performance gate

### Functional acceptance

Run every acceptance scenario from the companion specification, including:

- cold and unchanged build;
- source-only rebuild;
- shared target project key;
- CLI mutation denial;
- staged agentic loop and conflict-checked promotion;
- GUI fresh/save/resume/stale warning;
- cold and warm build-map;
- parallel read-only tools;
- failed build preservation/cleanup;
- alternative GT recipe; and
- native bundle sharing.

### Required checks

- Host unit/integration suite.
- JSON Schema validation for all emitted v2 records.
- `just check-type-pragmas`.
- Smalltalk tests from a fresh canonical project image.
- Existing project tests, including SQLite3/FFI coverage.
- CLI JSON response compatibility for commands retained publicly.
- Forced termination tests for build, CLI session, GUI save, and promotion.
- Dry-run and applied GC tests in a disposable v2 root.

### Performance/storage gates

The final report MUST demonstrate:

1. An unchanged build starts no VM and rewrites no complete image.
2. CLI/test execution retains no private complete image after success or failure.
3. CLI, agentic, GUI, and build-map own one canonical project image, not four.
4. GT native libraries are stored once per selected bundle and linked into
   views/workspaces.
5. GUI save keeps one current workspace plus at most one transient recovery
   predecessor.
6. Cold build-map starts one VM; warm compatible-GUI build-map starts none.
7. Repeated failing tests do not grow complete-image count.
8. A project-source change rebuilds from the late project checkpoint path only.

Do not set an arbitrary percentage speed target before baseline hardware data
exists. Any regression in common-path wall time must be explained and justified
by a larger storage/correctness gain.

## 19. Test architecture

### 19.1 Pure host tests

Use temporary roots and fake steps/processes for:

- recipe composition and keys;
- schema serialization;
- store paths and publication;
- reference/status atomics;
- locking/concurrency;
- failure cleanup;
- staging conflict checks;
- workspace staleness;
- liveness/GC; and
- CLI argument/result schemas.

### 19.2 VM protocol fixture

Provide a small fake executable that can:

- read a session manifest;
- write ready/completion records;
- simulate success/failure/crash/timeouts;
- create staged outputs;
- delay for concurrency tests; and
- validate cleanup ordering.

This keeps most lifecycle tests fast and deterministic.

### 19.3 Fresh GT integration tests

Run a smaller mandatory suite against a real clean runtime for:

- build-support loading;
- static provenance;
- session bootstrap;
- source and persistence capabilities;
- registered tool dispatch;
- exact project loading;
- contract results;
- native/FFI lookup; and
- GUI close/save hooks where the environment supports a display.

### 19.4 Destructive-test isolation

All retention, reset, failed-publication, and workspace-replacement tests must
use an explicitly created disposable root. Tests must assert the resolved root
before deletion.

## 20. Migration map from current code

| Current mechanism | V0.2 destination |
| --- | --- |
| `build/contexts/*.json` | checked-in Python targets/recipes and optional local recipe modules |
| `build/layers/*/layer.json` | Python `Step` definitions plus explicit script/contract inputs |
| `artifacts.py::graph` | resolved recipe sequence/keys |
| `artifacts.py::build_l01`–`build_l07` | generic executor plus role-specific step implementations |
| context-qualified artifact path | global typed key store |
| `implementation_digest()` | per-step declared implementation inputs/version |
| `runs.py::create_project_run` | lightweight session view or GUI workspace |
| retained failed run/attempt | latest status + bounded logs/results |
| `fresh_test()` second state root | explicit clean v2 root/verification scenario |
| `lifecycle.py` snapshots | one `gui-default` workspace |
| GUI refresh generations | stale-provenance warning and explicit fresh |
| run-private export bridge | absent in CLI; staging in agentic/GUI |
| `promote_packages()` | staging-aware conflict-checked promotion |
| `_gui_save_evidence()` | Smalltalk completion/save record |
| `KGToolRunner` conditionals | `KGToolRegistry` |
| build-map preparation save | disposable registered GUI entrypoint |
| active GUI filesystem spool | retained and extended with compatible `tool.open` |
| v1 inventory graph | recipe/artifact/session/workspace/staging inventory |
| v1 `gc`/`prune` graph | ref/workspace/active-session liveness and simple bounds |

## 21. Risks and required spikes

### 21.1 Canonical image read-only execution

Risk: the VM or GT may require writable files adjacent to the image even when
no save is requested.

Mitigation: trace writes during a representative CLI run. Redirect `.changes`,
cache, HOME/XDG, and logs. If the image itself must be writable, reflink only
the minimal image files and still avoid runtime/native/source copies.

### 21.2 Native-library links

Risk: relative lookup, loader RPATH, packaging, or library self-update may break
directory symlinks or hardlinks.

Mitigation: phase-3 matrix with CLI, GUI, FFI, save, and distribution-like
layout before choosing the strategy.

### 21.3 Image-side support invalidating base

Risk: placing frequently edited project tooling in the base support package
would cause expensive base rebuilds.

Mitigation: establish a small stable bootstrap package/input boundary and keep
ordinary project tools in late project source.

### 21.4 Accurate step implementation keys

Risk: explicit declarations can omit a helper/script and recreate v1
under-invalidation.

Mitigation: implementation-input manifests, tests that mutate each declared
fixture, code-review checklist, and optional tracing/audit tooling. Favor a
coarse step-local digest over an unsound precise list; never return to one
global package digest.

### 21.5 Atomic GUI save

Risk: image save semantics may not support replacing a workspace directory as
one atomic operation.

Mitigation: design a file-level save protocol with an explicit in-progress
record and one predecessor; test process kill at each transition.

### 21.6 Staged overlay fidelity

Risk: loading Tonel overlays may leave deletions, renames, or package metadata
ambiguous.

Mitigation: staging schema must represent additions, modifications, removals,
and renames explicitly; test round trips and compare image definitions to staged
source before promotion.

### 21.7 Warm GUI compatibility

Risk: sending a tool to a stale saved GUI can display incorrect inventory or use
an incompatible class/protocol.

Mitigation: require exact project key and protocol/tool compatibility; otherwise
fall back to cold start.

### 21.8 Long dual-engine period

Risk: every fix must be implemented twice and developers keep using the v1
path, preventing deletion.

Mitigation: land vertical v2 slices, set an explicit cutover milestone, and do
not add new features to v1 unless required for data safety.

## 22. Recommended commit sequence

Keep commits reviewable and behaviorally coherent. A reasonable sequence is:

1. add v2 schemas, recipe values, resolution, and key tests;
2. add v2 paths/store/status/publication with fake-step tests;
3. add runtime/native bundle presentation and measurements;
4. build base/dependency/project checkpoints through v2;
5. add Smalltalk provenance/session/capability protocol;
6. move headless test/eval/tools to lightweight sessions;
7. add staging and promotion;
8. add GUI workspace lifecycle;
9. migrate registered tools and cold build-map;
10. add compatible-GUI tool reuse;
11. migrate inventory/retention/build-map views;
12. cut over CLI/just/docs and remove v1 machinery; and
13. add final benchmark/acceptance report and cleanup.

Each commit should include its host tests and, where applicable, Smalltalk
tests/contracts. Do not combine the first working v2 vertical slice with wholesale
v1 deletion.

## 23. Definition of done

The migration is done only when:

- the normative v0.2 invariants and acceptance scenarios pass;
- the default documented commands use v2;
- one canonical project image serves CLI, agentic, GUI, and build-map;
- project-source edits rebuild only late project steps;
- alternate VM/Pharo/GT recipes are demonstrated through step replacement;
- CLI KlibGen mutation is a structured no-op/denial;
- agentic durable state is staging, not a saved image;
- GUI owns one resumable workspace and reports stale provenance;
- Smalltalk is authoritative for orderly close/save completion;
- cold build-map uses one VM start and warm build-map can reuse a compatible GUI;
- failure loops and GUI saves do not cause unbounded complete-image growth;
- runtime/native libraries are shared using the measured safe link strategy;
- inventory and GC accurately reflect the new ownership model;
- v1 run/attempt/snapshot/context production code is removed; and
- the final storage/startup comparison is documented.
