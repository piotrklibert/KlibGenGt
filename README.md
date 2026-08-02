# KlibGen-GT

KlibGen-GT is a Glamorous Toolkit / Pharo project with a reproducible,
source-controlled recipe build and explicit session lifecycle. Tonel source,
recipes, and exact input locks are authoritative. Canonical images are immutable
artifacts; only the named GUI workspace retains a mutable image.

The normative design is
[`docs/klibgen-gt-recipe-session-architecture-v0.2.md`](docs/klibgen-gt-recipe-session-architecture-v0.2.md),
with implementation evidence indexed in
[`docs/klibgen-gt-recipe-session-implementation-plan-v0.2.md`](docs/klibgen-gt-recipe-session-implementation-plan-v0.2.md).

## Quick start

The host needs `bash`, `just`, `uv`, `jj`, `git`, `sha256sum`, and `unzip`.
Desktop operations additionally use X11 tools and ImageMagick; `just doctor`
reports missing requirements.

```sh
just doctor
just recipe-resolve cli
just build cli
just test
```

The first build acquires or reuses the runtime, constructs the GT base and
dependency checkpoints, loads the exact current JJ project source, and
atomically publishes a canonical project artifact. An unchanged invocation
reuses it without starting a VM. Editing ordinary project source invalidates
only the project-source and later steps.

Useful development commands are:

```sh
just eval '6 * 7'
just test-one KlibGenGtTest testProjectName
just check-type-pragmas
just test-fresh
just gui
```

Every headless command runs in a disposable session with private HOME/XDG,
changes, inputs, logs, and results. The image must emit matching ready and
completion records; successful and failed session images are removed while
bounded diagnostics are retained.

The Python coordinator is installed from `pyproject.toml` and locked by
`uv.lock`. Use `uv add` and `uv lock` for dependency changes. The `justfile`
keeps uv's cache under ignored `tmp/uv-cache`.

## Authoritative and generated state

| Path | Role | Versioned? |
| --- | --- | --- |
| `src/` | Authoritative Tonel source and project baseline. | Yes |
| `python/klibgen_build/` | Recipe, store, session, workspace, staging, inventory, and CLI services. | Yes |
| `build/v2/` | Image-side build/session scripts and contracts. | Yes |
| `build/locks/` | Exact external source and archive locks. | Yes |
| `build/schemas/v2/` | Named/versioned record schemas. | Yes |
| `lepiter/`, `data/`, `docs/` | Documentation and fixtures. | Yes |
| `.klibgen/v2/artifacts/` | Immutable, content-keyed checkpoints and project artifacts. | No |
| `.klibgen/v2/refs/` | Mutable target references to verified artifacts. | No |
| `.klibgen/v2/workspaces/gui-default/` | The single resumable GUI image and private host state. | No |
| `.klibgen/v2/staging/` | Named, reviewable source overlays. | No |
| `.klibgen/v2/status/`, `logs/` | Latest bounded operation status and diagnostics. | No |
| `.klibgen/v2/sessions/`, `tmp/`, `locks/` | Transient execution and coordination state. | No |
| `vendor/` | Downloaded/runtime dependencies and optional local GT builds. | No |
| `tmp/` | Project-local temporary validation output and uv cache. | No |

The outer repository uses JuJutsu. Git is used only for deliberately nested
source bridges and upstream worktrees.

## Recipes and artifacts

The standard recipe has semantic roles rather than numbered layers:

```text
runtime -> gt-base -> gt-patches -> build-support
        -> project-dependencies -> project-setup
        -> project-source -> project-finalization
```

```sh
just recipe-list
just recipe-resolve gui
just build gui
just status
just inventory
just build-map
```

Artifact keys include exact declared implementation and source inputs,
platform/ABI, parent identity, and serializable step configuration. Recipe,
target, and launch-preset names do not affect content keys. Publication is
per-key locked, atomic, read-only, and verified before references advance.
Failures preserve the previous usable artifact and retain diagnostics without
publishing partial image payloads.

`just build-map-png` renders ignored overview and full graph PNGs from the same
generic inventory graph. It has no fixed-column, run-history, or numbered-layer
assumptions.

## Source and session workflows

Read-only tools receive disabled source-change and persistence capabilities.
Agentic work uses a named staging area:

```sh
just staging-create experiment
just agentic experiment
just staging-list
just staging-promote experiment
```

A staging record tracks its exact base plus additions, modifications,
removals, and renames. Promotion is serialized, restricted to owned
`KlibGenGt-*` package paths, and rejects overlapping authoritative changes. A
successful promotion leaves reviewable uncommitted changes in the outer JJ
working copy; it never creates a JJ change or commit.

The GUI workflow is deliberately singular:

```sh
just gui                 # resume, or initialize if absent
just gui-fresh           # replace from the current canonical artifact
just workspace-status
just workspace-reset     # explicit destructive reset
```

The workspace is exclusively locked. Resume compares saved provenance with the
current canonical project key and displays a stale warning without rewriting
the image. Save, discard, and cancel are image-authored lifecycle outcomes.
Interactive exports pass through the source capability and conflict-checked
staging/promotion path.

## Structured image tools

Current image-side tools dispatch through `KGToolRegistry` while retaining the
schema-version-one response envelope:

```sh
just code-search KGBuildMap class
just code-class KGBuildMap
just code-method KGBuildMap initializeFromDictionary:
just lepiter-search session title
just lepiter-export <page-uid>
```

Evaluation, profiling, test, code, Lepiter, and build-map PNG operations
declare identifiers, versions, accepted inputs, frontend support,
and required capabilities. The filesystem UI connector is the default live-GUI
transport; TCP is available through the connector API for programmatic use.

## Inventory and retention

```sh
just inventory
just gc-dry-run
just gc-apply
```

Inventory schema `klibgen.inventory/2` covers recipes, resolved steps,
artifacts, refs, runtime bundles, workspace, staging, active sessions, statuses,
locks, and storage. GC roots artifacts from target refs, workspaces, staging,
active operations, and explicit pins. It may remove abandoned transient state,
unreferenced artifacts, and rotated diagnostics; it never removes a workspace
or staging area.

## Verification

Before finishing a change, run:

```sh
just test-build-tools
just check-type-pragmas
just test
just test-fresh
```

`just test-fresh` always materializes a disposable session from the verified
canonical artifact. For changes to build inputs, a stronger clean-root check is
to move `.klibgen/v2/` aside temporarily, run `just build cli`, then restore or
delete the disposable root after inspecting its manifests.

Do not commit images, changes files, caches, logs, generated artifacts, or
anything under `tmp/`.
