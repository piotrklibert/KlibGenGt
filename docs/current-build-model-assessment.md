# Current build model: assessment and implemented workflows

## Executive assessment

The v0.2 build model is substantially implemented and is a strong foundation.
Its central architecture—content-addressed recipes, immutable checkpoints,
disposable sessions, one mutable GUI workspace, capability-controlled source
changes, staging, provenance, inventory, and safe GC—is real rather than
aspirational.

The main weakness is no longer the core builder. It is the incomplete connection
between those concepts:

- Some workflows promised by the architecture are only available as Python
  APIs, not as practical CLI workflows.

  **Example:** `Recipe.replace`, `Recipe.append`, and `Recipe.through` are
  implemented in `python/klibgen_build/recipes.py`, while
  `python/klibgen_build/resolution.py::resolve_target` only selects names from
  the hard-coded `DEFAULT_TARGETS`. Recipe values are coordinator-owned,
  versioned source; there is no generated recipe registry under `.klibgen/v2/`.

- GUI export stops in a private Git bridge and does not reach authoritative
  `src/`.

  **Example:** the current workspace record names
  `.klibgen/v2/workspaces/gui-default/source/.git` as `sourceGit`.
  `KGInteractiveSourceChanges>>#exportChanges` commits there, and
  `KGGuiSessionHooks` records an `iceberg-committed` event. The bridge is
  generated workspace-owned state. Host promotion is implemented separately by
  `python/klibgen_build/staging.py::promote_staging`, which only accepts named
  areas under `.klibgen/v2/staging/`.

- Staging can silently run against a newer canonical artifact than its recorded
  base.

  **Example:** a `klibgen.staging/1` record owns a `projectKey`, but
  `python/klibgen_build/sessions.py::execute_session` obtains the current key
  from `build_canonical(paths, "cli")` and does not compare it with the staging
  record. `build/v2/scripts/run-agentic-session.st` then loads the staging Git
  repository with `onConflictUseIncoming`.

- JJ revision identity causes redundant project builds even when `src/`
  content is identical.

  **Example:** the current and previous project resolutions both recorded tree
  digest
  `7b1fffa2d752500854c13309525364c2c70a1d00847ca6e2c0b22fd46e882d55`,
  but different JJ commit/change IDs produced different output keys. The value
  is constructed by `resolution.py::jj_tree_identity`; source identity is
  coordinator-owned provenance captured from the outer JJ working copy.

- Status, diagnostics, retention, and artifact verification are less complete
  than the architecture suggests.

  **Example:** `.klibgen/v2/status/` currently contains one JSON file per
  historical step key, while `inventory_v2.py::garbage_collect` removes
  unrooted artifacts, sessions, and temporary paths but does not rotate status,
  lock, or build-log records. These are generated coordinator-owned diagnostics.

- The system is extensible internally, but still fairly closed at its
  user-facing boundaries.

  **Example:** `KGToolRegistry>>#installStandardTools` provides versioned image
  registrations, but the host has no generic `tool run IDENTIFIER` command.
  Each exposed operation is still wired through a command-specific Click leaf
  in `python/klibgen_build/cli/`.

My overall judgment is: the model is ready to support normal development, but
it needs a “workflow integrity and observability” pass before investing heavily
in more tools or alternative stacks.

## The implemented model

The normative design is
[`klibgen-gt-recipe-session-architecture-v0.2.md`](klibgen-gt-recipe-session-architecture-v0.2.md).
The concise operational overview is [`README.md`](../README.md).

The most important conceptual split is:

```text
Recipe                     Artifact                    Session
what should be built       immutable reusable result  temporary use of a result
```

A fourth category, a workspace, is an explicitly mutable and persistent
session.

## Authoritative versus generated state

Authoritative inputs are external to images:

- Tonel source under `src/`.

  **Example and structure:**
  `src/KlibGenGt-Session/KGSession.class.st` is one class definition and
  `src/KlibGenGt-Session/package.st` is its package record. These files are
  owned by the outer JJ repository; project builds read them through an exact
  temporary Git/Iceberg bridge created by `canonical.py::_git_bridge`.

- Recipes and coordinator code.

  **Example and structure:** `python/klibgen_build/recipes.py` defines frozen
  `StepImplementation`, `Step`, `Recipe`, `LaunchPreset`, and `Target` values.
  `PROJECT` is an ordered tuple of eight steps. This is versioned Python source
  owned by the repository.

- Build scripts and contracts.

  **Example and structure:** `build/v2/scripts/load-project-source.st` performs
  the source-loading transformation, while
  `build/v2/tests/project-contract.st` validates the final project image. Each
  declared script or contract is digested by `resolution.py::digest_paths` and
  therefore participates in the producing step key.

- Exact archive and Git locks.

  **Example and structure:** `build/locks/default.lock.json` is a
  `klibgen.source-lock/1` record. It pins GT release `v1.1.477` to SHA-256
  `784d30cb…64cd3`, the installer to SHA-256 `03a1aa4f…3bd93`, and SQLite to
  commit `44dee155…c4`. The lock is versioned repository-owned source; downloaded
  payloads under `vendor/` are generated caches.

- JJ working-copy source identity.

  **Example and structure:** a resolved `project-source` step contains
  `vcs`, `commitId`, `changeId`, `treeDigest`, selected `paths`, and `exclude`.
  `resolution.py::jj_tree_identity` captures the values; the outer repository
  owns the source, while the resolved value is copied into artifact provenance.

- Documentation, data, schemas, and fixtures.

  **Example and structure:** `docs/` contains human design records,
  `data/kotlin-samples/` contains committed parser inputs,
  `build/schemas/v2/` contains wire schemas, and `build/tests/fixtures/fake_vm.py`
  provides host-test lifecycle fixtures. All are versioned repository-owned
  inputs; only paths explicitly declared by a step affect that step's key.

Generated state lives under `.klibgen/v2/`:

- Immutable artifacts.

  **Example and structure:** the current final artifact is
  `.klibgen/v2/store/image-workspace/linux-x86_64/06cdfc29…/`. It owns a
  read-only `manifest.json` plus `payload/`; its manifest says
  `producingRole: project-finalize` and embeds the complete resolved recipe.
  `ArtifactStore.publish_locked` creates and publishes it.

- Mutable references to selected artifacts.

  **Example and structure:** `.klibgen/v2/refs/default-project.json` is a small
  `klibgen.reference/1` record containing `name`, `artifactType`, `outputKey`,
  `artifactPath`, and `producingRole`. The coordinator owns and atomically
  replaces it through `ArtifactStore.write_reference`.

- One GUI workspace.

  **Example and structure:** `.klibgen/v2/workspaces/gui-default/` owns a
  writable `image/`, private `home/`, XDG directories, logs, session records,
  and a private `source/.git` bridge. `workspace.json` is the authoritative host
  state record. `workspaces.py::launch_gui_workspace` owns its lifecycle.

- Staging overlays.

  **Example and structure:** a named area would live at
  `.klibgen/v2/staging/experiment/` with `base/src/`, `overlay/src/`,
  `overlay/.git`, and `staging.json`. No staging area exists in the current
  state. `staging.py::create_staging` owns creation.

- Disposable sessions.

  **Example and structure:** a running command owns
  `.klibgen/v2/sessions/<uuid>/` with `image/`, private host directories,
  `request.json`, `session.json`, `ready.json`, `completion.json`, and
  `result.json`. `sessions.py::execute_session` creates the directory and
  removes it in `finally`.

- Build status, logs, locks, and temporary files.

  **Example and structure:** `.klibgen/v2/status/<output-key>.json` records a
  build state, `.klibgen/v2/logs/builds/<key>/<attempt>/` retains extracted
  diagnostics, `.klibgen/v2/locks/artifacts/<key>.lock` coordinates publication,
  and `.klibgen/v2/tmp/build-<uuid>/` is a partial build workspace. These are all
  generated and coordinator-owned.

This correctly makes images derived state. A canonical image is not a source
repository.

## Recipe structure

The standard project recipe is:

```text
runtime                    checkpoint
  ↓
pharo-gt                   transformation
  ↓
gt-patches                 transformation
  ↓
build-support              checkpoint
  ↓
project-dependencies       transformation
  ↓
project-setup              checkpoint
  ↓
project-source             transformation
  ↓
project-finalize           checkpoint
```

The definitions are in `python/klibgen_build/recipes.py`. For example,
`RUNTIME_STEP` declares the GT lock files and `scripts/bootstrap-gt.sh`, while
`PROJECT_FINALIZE_STEP` declares provenance installation, the project contract,
and `data/kotlin-samples`.

Only economically useful boundaries publish complete artifacts:

- `runtime` publishes a `runtime-bundle`; the current key is `a86a460d…a484`.
  `CanonicalExecutor.__call__` runs `scripts/bootstrap-gt.sh` and presents
  `vendor/gt` in its payload.
- `build-support` publishes the first reusable image checkpoint; current key
  `3ec73265…a4cc` contains the build-support and baseline definitions loaded by
  `build/v2/scripts/load-build-support.st`.
- `project-setup` publishes the dependency/setup checkpoint; current key
  `07143231…658f` follows the pinned SQLite load and stable setup.
- `project-finalize` publishes the canonical project image; current key
  `06cdfc29…fa6b` installs provenance and runs final contracts.

Steps between checkpoints execute together on a writable materialization of the
previous checkpoint. This avoids storing an image for every conceptual step.
The segmentation and checkpoint loop are implemented by
`builder.py::build_resolved`.

There are two built-in recipes:

- `base` ends at `build-support`. It is the `BASE` value in `recipes.py` and is
  versioned coordinator source.
- `project` appends dependency, setup, source, and finalization steps. It is the
  `PROJECT` value and produces the canonical image used by all standard targets.

There are four built-in targets, all sharing the same `project` recipe:

| Target | Frontend | Source changes | Persistence | Entrypoint | Concrete implementation |
|---|---|---|---|---|---|
| `cli` | headless | disabled | discard | structured requests | `CLI_PRESET`; `execute_session`; `build/v2/scripts/run-session.st` |
| `agentic` | headless | staged | discard | agent tools | `AGENTIC_PRESET`; `execute_agentic_session`; `run-agentic-session.st` |
| `gui` | GUI | interactive | workspace | workbench | `GUI_PRESET`; `launch_gui_workspace`; `bind-workspace.st` |
| `build-map` | GUI | disabled | discard | build-map | `BUILD_MAP_PRESET`; `export_build_map_pngs`; `KGBuildMapTool` |

This is an important success: CLI, agentic, GUI, and build-map do not produce
four different canonical images. The current artifact manifest demonstrates
that the launch preset is provenance attached to one shared resolved project
key rather than a distinct payload family.

## Resolution and keys

Resolution is implemented in `python/klibgen_build/resolution.py`.

Each step key includes:

- Its parent output key. For example, the current `pharo-gt` record names
  runtime key `a86a460d…a484`; `resolve_recipe` carries `parent_key` forward.
- The implementation identifier and version. For example, runtime records
  `runtime-v2`, version `1`; the values are owned by each `StepImplementation`.
- Digests of declared implementation files. For example, the runtime manifest
  records SHA-256 for `scripts/bootstrap-gt.sh`; `digest_paths` computes it.
- Resolved step configuration. For example, `gt-patches` currently resolves to
  `{ "variant": "default" }`; `_resolve_config` normalizes the value.
- Locked external sources. For example, SQLite resolves to exact commit
  `44dee155…c4` from `build/locks/default.lock.json`; `_lock_sources` validates
  and supplies it.
- Platform identity where declared. For example, runtime records Linux,
  `x86_64`, and ABI `x86_64`; `_resolve_config` obtains these host facts.
- Selected repository source identity. For example, `project-source` records
  `paths: ["src"]` and excludes `src/KlibGenGt-BuildSupport`; `jj_tree_identity`
  owns the capture.

Target, recipe, and launch-preset names do not affect artifact identity. This is
implemented by `resolve_recipe`, whose key material contains only the parent,
implementation identity/input digest, and resolved configuration.

Downstream invalidation follows naturally from the parent key. Editing ordinary
project source therefore leaves runtime, GT, build-support, and dependency/setup
checkpoints reusable.

The model supports immutable composition in Python:

- Rename a recipe with `Recipe.renamed`; it reconstructs a validated immutable
  `Recipe` with the same steps.
- Replace a role with `Recipe.replace`; it validates role identity and adjacent
  input/output compatibility.
- Append steps with `Recipe.append`; `PROJECT` is constructed this way from
  `BASE`.
- Truncate at a checkpoint with `Recipe.through` or `drop_last`; a non-checkpoint
  role is rejected.
- Resolve a custom `Recipe` against a target by passing it to
  `resolution.py::resolve_recipe`.

That part is well tested internally in `build/tests/test_v2_recipes.py`.

## Artifact construction and publication

The builder is in `python/klibgen_build/builder.py`, with storage in
`python/klibgen_build/store.py`.

Implemented properties include:

- One lock per artifact key. For example,
  `.klibgen/v2/locks/artifacts/06cdfc29….lock` is opened and flocked by
  `ArtifactStore.key_lock`; the lock file is generated coordinator state.
- Waiting and reuse when another builder publishes the same key.
  `build_resolved` takes the key lock and verifies an existing target before
  marking the result `reused: true`.
- Writable build workspaces under the managed state root. They are created as
  `.klibgen/v2/tmp/build-<uuid>/` by `build_resolved` and owned only for the
  duration of the attempt.
- `cp --reflink=auto` from the previous checkpoint. The action is issued by
  `build_resolved` before executing the next checkpoint segment.
- Atomic directory publication. `ArtifactStore.publish_locked` writes the
  manifest and uses `os.replace(workspace, target)`.
- Read-only published artifact trees. `ArtifactStore._make_read_only` removes
  write bits after publication.
- Mutable references advanced only after successful publication.
  `canonical.py::build_canonical` calls `write_reference` after
  `build_resolved`; the current sample is `refs/default-project.json`.
- Preservation of prior usable artifacts on failure. The failing workspace is
  cleaned and the failure status updated without replacing the prior artifact
  or reference.
- Deletion of partial build workspaces after extracting diagnostics.
  `build_resolved` copies logs/JSON records to
  `.klibgen/v2/logs/builds/<key>/<attempt>/` and removes the workspace.

Each final artifact embeds the complete resolved recipe in its manifest, so it
carries build provenance rather than merely a hash. The current
`06cdfc29…/manifest.json` shows the schema, platform, producing role, payload
shape digest, launch preset, and every resolved step.

## Session model

Headless execution is in `python/klibgen_build/sessions.py`.

Every eval, test, code query, or Lepiter query:

1. Ensures the current canonical project artifact exists by calling
   `build_canonical(paths, "cli")`.
2. Creates `.klibgen/v2/sessions/<uuid>/` in `execute_session`.
3. Runs `cp -a --reflink=auto` from the artifact's `payload/image` into the
   session.
4. Creates private `home`, `config`, `cache`, `data-home`, `tmp`, and `logs`
   directories and points HOME/XDG/TMPDIR at them.
5. Writes a typed `klibgen.session/1` manifest with project key, preset,
   capabilities, paths, and inputs.
6. Starts `payload/runtime/bin/GlamorousToolkit-cli` with
   `build/v2/scripts/run-session.st` or `run-agentic-session.st`.
7. Requires `ready.json`; `KGSessionBootstrap class>>#runManifest:` authors it
   after validating the session and build provenance.
8. Requires `completion.json`; the same bootstrap authors success/failure and
   Python checks that it agrees with `result.json`.
9. Removes the complete session materialization in `execute_session`'s
   `finally` block.
10. Retains `.klibgen/v2/logs/sessions/<operation>/latest/` on failure through
    `_retain_diagnostics`.

The image does not merely exit and leave Python to guess what happened.
`KGSessionBootstrap` writes authoritative lifecycle records. The corresponding
image-side implementation is
`src/KlibGenGt-Session/KGSessionBootstrap.class.st`.

Manual concurrent invocations are structurally supported because sessions have
unique paths and share only immutable artifacts. There is no built-in parallel
eval/test orchestrator.

## Capability model

The image installs two explicit capabilities:

- Source changes, installed by
  `KGSessionBootstrap class>>#sourceChangesNamed:` from the session preset.
- Image persistence, installed by
  `KGSessionBootstrap class>>#persistenceNamed:` from the same manifest.

Source capability variants are:

- `KGDisabledSourceChanges`, used by CLI/read-only sessions; calls are denied
  without an authoritative source destination.
- `KGStagedSourceChanges`, used by agentic sessions; it inherits export into the
  staging Git repository named by `manifest.inputs.sourceGit`.
- `KGInteractiveSourceChanges`, used by the GUI; its `exportChanges` commits
  modified `KlibGenGt-*` packages into the workspace's private Git bridge.

Persistence variants are:

- `KGDiscardPersistence`, used by disposable sessions; `save` raises and
  `discard` reports the only valid policy.
- `KGWorkspacePersistence`, used by the GUI; `saveAndQuit` and
  `discardAndQuit` first write `klibgen.session-completion/1`, then ask the image
  to snapshot or quit without saving.

This is a sound design. Tools call the installed capability rather than
branching on “CLI mode” or “GUI mode.”

It is intentionally an accident-prevention architecture, not hostile-code
sandboxing. Reflective Smalltalk code can still access files and subprocesses
directly.

## Staging model

The host-side implementation is `python/klibgen_build/staging.py`.

A named staging area contains:

- An exact recorded project/source base in `staging.json` as `projectKey` and
  `baseSource`.
- A frozen base copy at `base/src/`, created from authoritative `src/`.
- A mutable Git-backed overlay at `overlay/src/` with repository metadata in
  `overlay/.git`.
- Additions computed by `staging_changes` as paths present only in the overlay.
- Modifications computed as differing SHA-256 values for paths present in both
  trees.
- Removals computed as paths present only in the base.
- Simple rename detection implemented by pairing an identical removed and
  added file digest.
- Promotion state and conflicts stored in the mutable `promotion` field of
  `staging.json`.

Promotion:

- Is explicitly requested through `klibgen-build staging promote NAME`, defined
  in `python/klibgen_build/cli/staging.py`.
- Is serialized globally by `.klibgen/v2/locks/staging/promotion.lock`.
- Locks the selected staging area through
  `.klibgen/v2/locks/staging/<name>.lock`.
- Restricts paths to `KlibGenGt-*` packages in `staging.py::_owned`.
- Compares base, overlay, and current authoritative source in
  `promote_staging` before any copy/delete action.
- Rejects overlapping changes by marking the staging record `conflicted` and
  reporting exact paths.
- Leaves uncommitted changes in the outer JJ working copy by copying/removing
  files directly under repository-owned `src/`.
- Never creates a JJ change or commit; no JJ mutation exists in
  `promote_staging`.

Agentic images are disposable; durable output is source-form staging.

## GUI workspace

The workspace implementation is `python/klibgen_build/workspaces.py`.

There is one named workspace: `gui-default`.

It supports:

- Initialization from a canonical artifact in `_initialize`, which reflinks or
  copies `payload/image` and constructs an exact source Git bridge.
- Exclusive locking while active through
  `.klibgen/v2/locks/workspaces/gui-default.lock` and `workspace_lock`.
- Resume when `workspace.json` records an orderly saved completion;
  `_workspace_start_mode` selects `resumed`.
- Explicit `--fresh` replacement in `launch_gui_workspace`, exposed by
  `python/klibgen_build/cli/sessions.py::gui`.
- Stale-project warnings by comparing `workspace.projectKey` with the current
  canonical build key. The current workspace has `4d0f0201…`, while the current
  reference has `06cdfc29…`.
- Private HOME/XDG/temp/log state under the workspace directory.
- Save, discard, and cancel semantics authored by `KGWorkspacePersistence` and
  the GUI shutdown prompt in `KGGuiSessionHooks`.
- Abnormal-exit detection when Python observes process termination without a
  matching completion record.
- No append-only snapshot history; the only retained mutable image is
  `workspaces/gui-default/image/`.

This singular workspace is intentional. Multiple named GUI workspaces are not
currently part of the model.

## Registered image tools and live GUI control

`KGToolRegistry` currently registers:

- Code search/class/method retrieval through `KGCodeSearchTool` operations
  `code.search`, `code.class`, and `code.method`.
- Lepiter search/export through `KGLepiterTool` operations `lepiter.search` and
  `lepiter.export`.
- Evaluation and profiling through `KGEvaluationTool` operation `eval`.
- Full and focused tests through `KGTestTool` operations `test.all` and
  `test.run`.
- Build-map PNG export through `KGBuildMapTool` operation `build-map.png`.

The registry eliminates image-side operation conditionals:
`KGToolRunner>>#dispatch:request:` looks up the registration and executes its
handler.

A live GUI also installs a coordinate-free scene control service supporting:

- Session/status inspection through host `ui status` and
  `ui_control.py::active_gui_sessions`.
- Spaces and instantiated scene trees through `ui.spaces` and `ui.tree`.
- Selectors by node, class, ID, text, visibility, enablement, and focus; the
  Click mapping is in `cli/ui.py::_selector` and the image evaluates it through
  `KGUiSceneGraph`.
- Query/get through `ui.query` and `ui.get`.
- Click, keyboard, scroll, and drag actions through `ui.act`.
- Waits through `ui.wait` with states such as `exists`, `visible`, and
  `text-equals`.
- Batches through `ui.batch`, which submits ordered JSON steps.
- Live evaluation through `ui.eval`, implemented by
  `KGUiControlService>>#evaluate:` in a background process with a deadline.

Filesystem spooling is the connected host transport. A loopback TCP connector
is implemented and tested image-side in `KGTcpUiControlConnector`, but is not
wired into the host workflow.

## Inventory and GC

Inventory and retention are in `python/klibgen_build/inventory_v2.py`.

Inventory includes:

- Built-in recipes and targets from `DEFAULT_RECIPES` and `DEFAULT_TARGETS`.
- Resolved step sequences produced by `resolve_target` for each target.
- Artifacts returned and verified by `ArtifactStore.artifacts`.
- References parsed from `.klibgen/v2/refs/*.json`.
- Workspace and staging records parsed from their named manifest files.
- Active sessions parsed from `.klibgen/v2/sessions/*/session.json`; the current
  inventory has none.
- Statuses parsed from `.klibgen/v2/status/*.json`.
- Locks listed from `.klibgen/v2/locks/**/*.lock`.
- Graph nodes and edges connecting targets, steps, artifacts, references,
  workspaces, and staging areas.
- State-root storage computed as logical bytes, allocated bytes, and file count
  by `inventory_v2.py::_size`.

GC roots artifacts through:

- References such as `refs/default-project.json`, currently pointing to
  `06cdfc29…`.
- GUI workspaces such as `gui-default`, currently retaining project artifact
  `4d0f0201…`.
- Staging records and their `projectKey`; none currently exist.
- Active session manifests and their `projectKey`; none currently exist.
- Manually created `.klibgen/v2/pins/*.json` records, although no pin-management
  CLI currently exists.

It removes unrooted artifacts, abandoned sessions, and temporary state, while
refusing deletion outside the managed v2 root. The path guard is implemented by
`V2Paths.remove_tree`; plan construction and application are implemented by
`inventory_v2.py::garbage_collect`.

## Typical workflows

| Workflow | Conceptual behavior | CLI | Implementation/example |
|---|---|---|---|
| Inspect prerequisites | Validate host tools and committed inputs | `just doctor` | `cli/maintenance.py::_doctor` checks executables, `src/`, `vendor/gt.zip`, and the default lock. |
| Understand construction | Resolve keys without building | `just recipe-list`, `just recipe-resolve cli` | `recipe_catalog` and `resolve_target`; output is `klibgen.resolved-recipe/1`. |
| Build current project | Reuse checkpoints and publish current final artifact | `just build cli` | `build_canonical` → `build_resolved` → `CanonicalExecutor`; current final key is `06cdfc29…`. |
| Normal edit/test loop | Edit `src/`; implicitly rebuild only changed late checkpoints; use disposable test image | `just test`, `just test-one …` | `cli/sessions.py` sends `test.all` or `test.run` through `execute_session`. |
| Evaluate code | Disposable read-only session | `just eval '…'` | Sends operation `eval`; image handler is `KGEvaluationTool`. |
| Validate annotations | Focused disposable test | `just check-type-pragmas` | Sends `KGCheckTypePragmasTest>>#testProjectTypeAnnotationsAreValid`. |
| Inspect loaded code/docs | Structured disposable tools | `just code-search`, `just code-class`, `just code-method`, `just lepiter-search` | Click leaves in `cli/image.py` map to `KGToolRegistry` operations. |
| Agentic experimentation | Load canonical image plus named source overlay; discard image afterward | `just staging-create NAME`, `just agentic NAME` | `create_staging`, `execute_agentic_session`, and `run-agentic-session.st`. |
| Promote agentic source | Conflict-check overlay against current `src/` | `just staging-promote NAME` | `staging.py::promote_staging`; destination ownership remains the outer JJ working copy. |
| Interactive development | Resume or create the single mutable workspace | `just gui` | `workspaces.py::launch_gui_workspace`; state is `workspaces/gui-default/`. |
| Reinitialize GUI | Replace workspace from current canonical artifact | `just gui-fresh` | `launch_gui_workspace(fresh=True)` removes and recreates the managed workspace. |
| Drive live GUI | Structured selector/action protocol | `klibgen-build ui …` | `ui_control.py::submit_ui_request` and `KGFileUiControlConnector`. |
| Inspect storage graph | Generate inventory or PNG graph | `just build-map`, `just build-map-png` | `inventory()` and `registered_tools.py::export_build_map_pngs`; image rendering is `KGBuildMapTool`. |
| Review retention | Show or delete unrooted generated state | `just gc-dry-run`, `just gc-apply` | `garbage_collect(apply=False/True)` produces and optionally applies `klibgen.gc-plan/1`. |
| Verify generated JSON models | Compare Pydantic catalog with tracked Tonel | `just check-json-models` | `tonel_export.py` owns marked generated files under `src/KlibGenGt-JsonModels/`. |

One minor CLI oddity: `test --fresh` does not select a meaningfully different
path. All tests are already disposable fresh sessions.

## Current live state

After the image-side inspection used to produce this assessment:

- 7 immutable artifacts. `just build-map` enumerates them from
  `.klibgen/v2/store/*/*/*/manifest.json`; they include one runtime, two
  build-support, two project-setup, and two project-finalize artifacts.
- 3 references. They are the coordinator-owned JSON files
  `default-build-support.json`, `default-project-setup.json`, and
  `default-project.json` under `.klibgen/v2/refs/`.
- 1 GUI workspace: `.klibgen/v2/workspaces/gui-default/`.
- 0 staging areas: `.klibgen/v2/staging/` is currently empty.
- 0 active sessions: `.klibgen/v2/sessions/` is currently empty.
- Approximately 3 GiB under `.klibgen/v2/store/`, measured with `du`; the
  immutable store is coordinator-owned generated state.
- Approximately 514 MiB in `.klibgen/v2/workspaces/`, almost entirely the
  writable `gui-default` workspace.
- `vendor/gt` is approximately 1.1 GiB, `vendor/gt.zip` approximately 237 MiB,
  and `vendor/gt-build` approximately 4.2 GiB. These are ignored acquisition and
  local-source-build caches owned outside the v2 store.

The current `default-project` reference points to project key
`06cdfc29d0e611eba70ceaada0286f788eb977edc88c2b822af9e9bd717efa6b`.
Its `klibgen.reference/1` record owns only the pointer; the payload is owned by
the corresponding immutable store directory.

The GUI workspace is based on older key
`4d0f020190e7d1f625adbd969897027b23b2cab13dc88e6ec193a1ea5d2ff1ed`
and will therefore produce a stale warning on resume. Its `workspace.json`
records state `ready` and last orderly outcome `discarded`.

Routine GC removed three unrooted project-finalize artifacts after verification.
A follow-up `garbage_collect(apply=False)` identifies zero removable paths and
zero warnings.

The source working copy remained clean during the assessment. Structured image
queries did materialize the current canonical artifact and advance the normal
project reference, because every image query goes through
`build_canonical(paths, "cli")`.
