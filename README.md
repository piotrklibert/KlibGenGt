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
just lint-source
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

## Command-line interface

`klibgen-build` is a nested Click CLI. Run `klibgen-build --help` and then the
`--help` of any group or leaf for its arguments, validated choices, ranges,
defaults, state changes, and failure policy.

The implementation is a `python/klibgen_build/cli/` package: command groups
live in subsystem modules, while `common.py` owns shared validation, error
translation, and result formatting. The package root exports only `cli`,
`main`, and `emit` as its public CLI API.

The command tree is:

```text
klibgen-build
├── host windows … | processes … | profile -- COMMAND
├── image code … | lepiter … | eval
├── ui status | spaces | tree | query | get | act | wait | batch | eval
├── recipe list | resolve
├── artifact list | verify
├── workspace status | reset
├── staging list | create | rebase | reset | promote
├── models export-tonel
└── doctor | status | build | test | test-one | eval | load | smoke | lint-source
    | check-type-pragmas | gui | agentic | inventory | build-map
    | build-map-png | gc
```

Options such as `--json` remain local to each command. `test --fresh` always
uses a disposable session; `gui --fresh` deliberately replaces the saved GUI
workspace, while `workspace reset` requires `--confirm`. UI selectors compose:
all supplied selectors must match, and node-specific actions require a unique
match. Boolean selectors are tri-state (`--visible`, `--no-visible`, or
unspecified). Repeat `--database` to search multiple Lepiter databases. Use
`host profile -- COMMAND` when the profiled command has options so all remaining
arguments pass through unchanged.

Successful results exit 0, structured results with `ok: false` exit 1, and
usage, validation, filesystem, process, timeout, or protocol failures exit 2.

Python build services use one stderr-only logging policy. The default `INFO`
level reports only major build, session, staging, GUI, lint, and maintenance
lifecycle events. Override it for an individual invocation before the command:

```sh
uv run klibgen-build --log-level DEBUG staging rebase experiment
uv run klibgen-build --log-level TRACE build cli
KLIBGEN_LOG_LEVEL=WARNING just test
```

Supported levels are `TRACE`, `DEBUG`, `INFO`, `WARNING`, `ERROR`, and
`CRITICAL`. DEBUG includes decisions, paths, process counts, and identifiers;
TRACE additionally includes full subprocess argument vectors and should be
used carefully. Logs never enter stdout, so `--json` output remains directly
parseable.

## Authoritative and generated state

| Path | Role | Versioned? |
| --- | --- | --- |
| `src/` | Authoritative Tonel source and project baseline. | Yes |
| `src/KlibGenGt-JsonModels/` | Tracked Tonel records generated from the Pydantic wire-model catalog. | Yes |
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
uv run klibgen-build staging rebase experiment
just staging-promote experiment
```

A staging record tracks its exact base, Git head, generation, exclusive lease,
and additions, modifications, removals, and renames. Attachment and explicit
`staging rebase` perform a file-level three-way rebase onto current `src/`;
conflicts preserve the original overlay and refuse execution. Promotion is
serialized, atomically applied, restricted to owned `KlibGenGt-*` package
paths, and leaves reviewable uncommitted changes in the outer JJ working copy.
It never creates a JJ change or commit.

Structural Smalltalk changes can use the image's curated Refactoring Browser
adapters instead of text editing:

```sh
just refactor-catalog
just refactor-describe method.rename
just refactor-applicable experiment ./tmp/refactor.json
just refactor-preview experiment ./tmp/refactor.json
just refactor-apply experiment ./tmp/refactor.json sha256:THE_REVIEWED_PLAN
```

Requests use the extensible `klibgen.refactoring-request/1` JSON record. The
stable catalog covers class, method, instance-variable, and parameter renames;
method move and extraction; parameter addition/removal; and bounded AST
rewrites. Preview runs in a disposable agentic image and returns semantic
changes, exact before/after Tonel, warnings, impact counts, staging provenance,
and a deterministic plan ID. Apply recomputes everything and exports only if
that exact ID still matches. AST pattern blocks are disabled unless the request
sets `allowPatternBlocks: true`, remain project-scoped and bounded, and are
reported as an unsafe feature for explicit review. Promotion is still a
separate operation.

`just lint-source` round-trips every authoritative `.st` file through the
pinned image's Tonel writer and requires an exact byte match. The same gate runs
inside canonical project-source construction and after staging rebase before a
GUI or agentic image is attached. It checks Tonel serialization only: method
bodies are not pretty-printed. A failure leaves source and staging unchanged
and reports the paths and bounded unified diffs that Export would introduce.

The GUI workflow is deliberately singular:

```sh
just gui                 # resume, or initialize if absent
uv run klibgen-build gui --staging experiment  # explicit sequential handoff
just gui-fresh           # replace from the current canonical artifact
just workspace-status
just workspace-reset     # explicit destructive reset
```

The workspace is exclusively locked and uses `gui-default` staging unless
`--staging NAME` is selected; switching a saved workspace requires `--fresh`.
Agentic and GUI processes may attach to one area sequentially, never
concurrently. A clean saved image reloads a newer staging generation on resume;
an image with unexported changes reserves the area until those changes are
exported or discarded. Export commits only to staging. Promote is a separate
explicit GUI action serviced by the host through a session-scoped request
spool. Save, discard, and cancel remain image-authored lifecycle outcomes.

## Structured image tools

Current image-side tools dispatch through `KGToolRegistry` while retaining the
schema-version-one response envelope:

```sh
just code-search KGBuildMap class
just code-class KGBuildMap
just code-method KGBuildMap initializeFromInventory:
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

## JSON models

Named v0.2 build records are defined as frozen Pydantic models in
`python/klibgen_build/json_models.py`. Regenerate the equivalent immutable
Smalltalk records after changing that catalog, and verify that tracked Tonel is
current:

```sh
just generate-json-models
just check-json-models
```

The exporter owns only files carrying its generated marker and the marked JSON
model subsection of the `KlibGenGt` class index. Handwritten Tonel in the same
package is preserved.

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

Do not commit images, changes files, caches, logs, generated runtime artifacts,
or anything under `tmp/`. Generated Tonel JSON models are tracked source and
must be committed with their Pydantic definitions.
