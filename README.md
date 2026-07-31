# KlibGen-gt

KlibGen-gt is a Glamorous Toolkit / Pharo project with a reproducible,
source-controlled image build. Tonel files and build definitions are the source
of truth. Images are generated artifacts, and interactive images are writable
runs or explicitly saved snapshots.

The build follows
[`docs/klibgen-gt-reproducible-build-architecture-v0.1.md`](docs/klibgen-gt-reproducible-build-architecture-v0.1.md).
The staged implementation record is under [`docs/todo/`](docs/todo/).

## Quick Start

The host needs `bash`, `just`, `uv`, `jj`, `git`, `sha256sum`, and `unzip`.
The Linux desktop commands additionally use `xprop`, `xdotool`, and
ImageMagick's `import`; `just doctor` checks all of them.
Start by checking the selected context and resolved inputs:

```sh
just doctor default
just resolve default
just status default
```

Build and test the CLI project image, or open the GUI profile:

```sh
just build l06 default
just test default
just gui
```

`just gui` resumes the current saved GUI session for the `gui` context, or
creates a fresh writable run when no session is selected. `just gui-fresh`
explicitly bypasses the saved-session pointer. Both start the normal
`GlamorousToolkit --image ...` executable and open one GT window. Use `just
gui-context <context>` for an explicit alternative context.

The host-side coordinator is the Python project declared by `pyproject.toml`
and locked by `uv.lock`. Every Python-backed recipe uses `uv run`, which creates
or updates the ignored `.venv` before invoking the installed `klibgen-build`
entry point. The `justfile` keeps uv's cache under ignored `tmp/uv-cache`.
Process execution is implemented with Plumbum; add or update Python dependencies
with `uv add`/`uv lock`, not with an unmanaged `pip install`.

## Authoritative and Generated State

| Path | Role | Versioned? |
| --- | --- | --- |
| `src/` | Authoritative Tonel source and project baseline. | Yes, in the outer JJ repository. |
| `python/klibgen_build/` | Installable host-side build coordinator used through `uv run`. | Yes. |
| `build/layers/` | Stable L01-L07 definitions, scripts, contracts, and resources. | Yes. |
| `build/contexts/` | Committed build selections such as `default`, `gui`, and `patched`. | Yes. |
| `build/locks/` | Exact archive checksums and Git commit locks. | Yes. |
| `lepiter/`, `data/`, `docs/` | Documentation, fixtures, and architecture records. | Yes. |
| `export/` | Legacy/default-context Iceberg Git bridge used by compatibility commands. | No; it is a separate ignored Git repository. |
| `vendor/gt*` | Downloaded runtime and local GT sources/workspaces. | No. |
| `.klibgen/artifacts/` | Immutable canonical layer artifacts, keyed by platform, context, layer, and build key. | No. |
| `.klibgen/runs/` | Writable per-command or GUI image copies and their isolated host state. | No. |
| `.klibgen/snapshots/` | Immutable, resumable, non-canonical L06-tmp images. | No. |
| `.klibgen/contexts/`, `.klibgen/workspaces/`, `.klibgen/worktrees/` | Generated context definitions and their JJ/Git working areas. | No. |
| `artifacts/fresh-layered/` | Completely separate state root used by `just test-fresh`. | No. |
| `tmp/` | Project-local temporary snippets and validation files. | No. |

The outer repository uses JuJutsu. Do not use Git commands against its root.
Git is used for deliberately nested repositories and upstream Git worktrees.

## Layer Graph

The canonical chain is:

```text
L01 runtime
  -> L02 clean GT base image
  -> L03 GT patch selection
  -> L04 locked project dependencies
  -> L05 CLI or GUI setup
  -> L06 exact JJ project source
  -> L07 DEV distribution

L06 -> L06-tmp resumable snapshot (never an L07 parent)
```

Each layer key includes its definition, selected context data, parent key, lock
data, platform, relevant source identity, and coordinator implementation. A
matching successful artifact is reused. A changed ancestor key makes every
descendant stale. Publication is locked and atomic; failed attempts stay under
`.klibgen/tmp/attempt-*` with logs and a failed manifest, while an earlier
successful artifact remains unchanged.

`just status-json <context>` reports expected keys, current artifact paths,
available stale artifacts, runs, and snapshots. The human form is
`just status <context>`.

## How Project Code Is Loaded

The normal layered workflow does not load the shared `export/` checkout.
For L06 the coordinator:

1. Lets JJ snapshot the selected workspace revision.
2. Records its exact commit ID, change ID, workspace, changed paths, mutability,
   and conflicts.
3. Materializes `src/` from that exact commit into an isolated generated Git
   bridge.
4. Commits the bridge because Metacello `gitlocal://` reads committed Git data.
5. Loads the baseline `CI` group and runs the L06 contract in a copied image.
6. Removes the build bridge and publishes the image plus source mapping and
   manifest as an immutable artifact.

L04 loads Pharo-SQLite3 first from the locked upstream commit or from the
context's explicit Git worktree override. L06 then loads KlibGenGt. Network
access is needed when a locked source is not already cached by the runtime.

Any command that executes Smalltalk creates a writable run copy of canonical
L06. It gets its own image, generated bridge, `HOME`, XDG config/cache, logs,
and temporary directory. Successful headless runs are removed; failed runs and
GUI runs are retained for inspection.

## Creating and Selecting Images

Canonical images are created only when a requested layer is missing or stale:

```sh
just build l02 default
just build l06 default
just build l06 gui
just build l07 default
```

Downstream commands build their required ancestors automatically. `just
rebuild l06 default` performs a new isolated attempt for the same logical key;
it does not overwrite an already published artifact.

The context selects the runtime, GT patch, dependency override, setup profile,
project workspace, and distribution profile. Common committed contexts are:

| Context | Selection |
| --- | --- |
| `default` | Downloaded GT, baseline L03, locked SQLite, CLI L05/L06, DEV L07. |
| `gui` | Default inputs with GUI L05/L06. |
| `source-clean` | Locally source-built clean GT with CLI project layers. |
| `patched`, `patched-gui` | Local GT source build plus the declared headless WebView patch. |
| `sqlite-local` | Explicit local Pharo-SQLite3 Git worktree override. |
| `agentic` | Reserved AGENTIC profile; currently rejects execution. |
| `release` | Reserved RELEASE profile; currently rejects packaging because production constraints are not implemented. |

Select a context with the last recipe argument, for example `just test
patched`. `GT_RUNTIME=build-clean` and `GT_RUNTIME=build-patched` remain
compatibility selectors for `load`, `test`, `smoke`, `eval`, and `gui`; new
automation should name the context directly.

The pinned downloaded runtime is installed by `just bootstrap`. Local source
runtimes are prepared by `just bootstrap-build-clean` and
`just bootstrap-build-patched`.

## Recreating Images

Use a separate state root for a clean reconstruction without disturbing normal
artifacts or named contexts:

```sh
KLIBGEN_STATE_ROOT=artifacts/rebuild-check just build l07 default
```

The build starts at L01 and reconstructs every required image. `just
test-fresh` is the standard final gate: it deletes `artifacts/fresh-layered/`,
builds L01-L06 there from pinned inputs and the exact JJ source revision, and
runs the project suite in an isolated run image.

`just clean-runtime` is a legacy acquisition cleanup. It removes downloaded or
source-built runtime workspaces and legacy `artifacts/` contents, but it does
not manage `.klibgen/` named contexts. Use `just clean-runs <context>` for
stopped runs and `just gc` for unreferenced canonical artifacts and old failed
attempts.

## GUI Runs and Snapshots

```sh
just gui
```

With no current snapshot, this creates `.klibgen/runs/gui/<run-id>/`, binds
Iceberg to the run's generated bridge, installs an image-local session hook,
and launches the GUI sibling of the CLI runtime. The host's
`~/Documents/lepiter` is seeded once into the run's private HOME. HOME, XDG
config/data, the complete image bundle, bridge dirty state, and logs persist;
cache and tmp do not.

Saving and quitting automatically publishes an immutable schema-v2 L06-tmp
snapshot, verifies its component hashes, removes the source run, and advances
the context's current pointer. A later `just gui` directly copies and launches
that snapshot using its recorded runtime; it does not rebuild L06 or rerun
Metacello. The serialized `GtWorld` is retained, and Iceberg is rebound to the
new private bridge path at image startup. Current JJ/workspace divergence is
reported but never reloads or alters the saved session. Quit-without-save and
interrupted runs remain under `.klibgen/runs/` for recovery and do not change
the pointer.

After the GUI process stops:

```sh
just snapshot <run-id>
just resume <snapshot-id>
just discard <run-or-snapshot-id>
just gui-fresh [context]
just gui-snapshot <snapshot-id>
just snapshot-list [context]
just snapshot-current [context]
just snapshot-select <snapshot-id> [context]
just snapshot-clear [context]
```

Manual `snapshot` and `resume` remain available. A manual snapshot does not
become current unless selected explicitly. Selecting and clearing pointers
never deletes history, and snapshots are never considered by the L07 builder.

Promote only explicit packages from a run or snapshot:

```sh
just promote <run-or-snapshot-id> KlibGenGt-Core default
just promote <id> KlibGenGt-Core,KlibGenGt-Tests default
```

Promotion refuses a package with no bridge changes and refuses to overwrite a
package that changed in the authoritative JJ workspace since the run was
created. V1 promotion targets the root JJ workspace and `KlibGenGt-*` packages.
Review the resulting JJ working-copy change and rebuild L06 normally.

## Alternative Contexts

Create a generated context with a real JJ workspace:

```sh
just context-create issue-142 @ default
just doctor issue-142
just build l06 issue-142
```

Attach an upstream Git worktree at an exact revision:

```sh
just worktree-add issue-142 sqlite3 /path/to/Pharo-SQLite3 <commit>
just worktree-add issue-142 gt /path/to/gtoolkit <commit>
```

The worktree is detached and context-local. Its exact commit, dirty paths, and
dirty content digest affect the layer key. Remove clean worktrees and the JJ
workspace explicitly:

```sh
just worktree-remove issue-142 sqlite3
just context-remove issue-142
```

Context removal refuses active runs, snapshots, and attached worktrees. Builds,
runs, host state, logs, locks, and worktrees are separated by context. Artifact
publication also uses per-context/per-key file locks.

Pin a current artifact before retention cleanup when it must remain available:

```sh
just pin default l07 demo-build
just gc
just unpin demo-build
```

GC preserves artifacts selected by current contexts, snapshot parents, and
explicit pins.

## Commands

| Command | Effect |
| --- | --- |
| `just doctor [context]` | Validate tools, state root, JJ workspace, and configured Git worktrees. |
| `just resolve [context]` | Verify committed immutable locks; `resolve-update` explicitly updates movable resolutions. |
| `just status [context]` | Explain current, stale, and missing layers plus runs and snapshots. |
| `just build <layer> [context]` | Build/reuse the requested canonical layer and its ancestors. |
| `just load [context]` | Build and validate canonical L06 without making a persistent run. |
| `just test [context]` | Run `KlibGenGt-Tests` in an isolated L06 run. |
| `just test-fresh [context]` | Rebuild in the disposable fresh state root and run tests. |
| `just check-type-pragmas [context]` | Run `KGCheckTypePragmas` in an isolated run. |
| `just smoke [context]` | Verify the loaded project anchor and identity. |
| `just eval "..." [profile] [context]` | Evaluate one Smalltalk do-it in an isolated CLI run. |
| `just windows [title-regex]` | List visible managed windows with IDs, PIDs, geometry, titles, and process commands. |
| `just screenshot [title-regex]` | Capture one matching window under ignored `tmp/screenshots/`. |
| `just code-search`, `code-class`, `code-method` | Search loaded code or dump exact class and method definitions. |
| `just lepiter-search`, `lepiter-export` | Search loaded Lepiter databases or export a page as Markdown. |
| `just profile "<shell command>"` | Run a shell command with elapsed and child CPU timing. |
| `just gui` | Resume the current GUI snapshot, or create a fresh GUI run. |
| `just gui-context <context>` | Apply the same policy to an explicit context. |
| `just gui-fresh`, `gui-snapshot` | Bypass the pointer or launch one explicit snapshot. |
| `just snapshot-list`, `snapshot-current`, `snapshot-select`, `snapshot-clear` | Inspect and manage current GUI-session selection without deleting history. |
| `just build l07 default` | Produce the self-contained DEV launcher/image bundle and checksums. |
| `just snapshot`, `resume`, `discard`, `promote` | Manage non-canonical development state and selected source changes. |
| `just context-*`, `worktree-*` | Manage generated JJ workspaces and Git overrides. |
| `just clean-runs`, `pin`, `unpin`, `gc` | Manage retention without mutating canonical artifacts. |

## Host and Image Tools

The installed Python CLI is the complete interface; the `just` recipes above
are shortcuts for common calls. Host tools use a backend-neutral Python API.
The current backend supports Linux X11/XWayland sessions and reports a clear
error when `$DISPLAY` is unavailable.

```sh
uv run klibgen-build host windows list --json | jq '.data.windows[]'
uv run klibgen-build host windows wait --for present \
  --title-regex '^Glamorous Toolkit$' --timeout 15
uv run klibgen-build host windows screenshot \
  --title-regex '^Glamorous Toolkit$'
uv run klibgen-build host processes list --command-regex GlamorousToolkit
uv run klibgen-build host profile -- sleep 0.1
```

The direct `host profile -- COMMAND ...` form preserves an exact argument
vector. The convenience recipe accepts one quoted shell command, for example
`just profile "sleep 0.1"`.

Window selectors can combine `--id`, `--pid`, `--title-regex`, and
`--command-regex`. List and wait commands may return several clients; focus,
screenshot, and close require exactly one match and report candidates when a
selector is ambiguous. The X11 backend starts from the window manager's client
list, avoiding duplicate frame/decorator windows. Close activates the real
client, sends `Alt+F4`, and waits for it to disappear. Process termination is
available as `host processes terminate`, but requires an explicit `--pid`;
`--force` permits `SIGKILL` only after the graceful timeout.

Screenshots default to `tmp/screenshots/<timestamp>-<window-id>.png`; pass
`--output` to choose another path. Host profiling uses a monotonic wall clock
and POSIX child resource counters. It currently reports wall, user CPU, system
CPU, and exit status, not allocation or per-thread data. Without `--json`, the
child inherits stdout/stderr and the timing summary goes to stderr. With
`--json`, decoded child output and metrics are returned in one document.

Image tools create the same disposable L06 CLI runs as tests and eval. Python
passes a JSON request through the environment; `KGToolRunner` dispatches it in
`KlibGenGt-Tools`, and `STONJSON` writes exactly one UTF-8 JSON response. This
is JSON, a STON-supported representation, rather than general STON syntax, so
it is directly consumable by `jq`. Successful runs are deleted. Failed runs
are retained and their path is included in the error response.

```sh
uv run klibgen-build image code search KlibGenGt --kind all --json \
  | jq '.data.results[]'
uv run klibgen-build image code class KlibGenGt
uv run klibgen-build image code method KlibGenGt projectName --side class
uv run klibgen-build image lepiter search 'Class definition' --in text --json
uv run klibgen-build image lepiter export --uid PAGE_UID
uv run klibgen-build image eval --profile '10000 factorial digitSum' --json
```

Code search covers classes and methods and supports `--package` and `--limit`.
Class and method dump commands emit only Tonel definition/source text unless
`--json` is requested. Lepiter search covers every database loaded in the run
by default, including the copied local database and the GT Book. Repeat
`--database NAME` to restrict it. Results carry the database name, page UID,
title, and preview. Export accepts exactly one `--uid` or exact `--title` and
emits only Markdown in text mode; ambiguous titles fail with candidate UIDs.

Image eval also accepts `--file PATH` or `--stdin` instead of a positional
expression. Structured failures include the compile/runtime category,
exception class, message, bounded Smalltalk stack, and retained run path.
`--profile` uses `AndreasSystemProfiler` and adds its elapsed time, sample
count, and expandable text report.

## `just eval` Escaping

`just eval` builds/loads CLI L06 and uses `GT_EVAL` only between the recipe and
the Python coordinator. Python JSON-encodes the already parsed expression for
the image bridge; no shell reparses it. The image evaluates it with `Smalltalk
compiler evaluate:` and prints the result with `printString`. Compiler errors
and runtime exceptions fail with the structured diagnostics described above.

The expression must reach `just` as exactly one shell argument:

```sh
just eval "1 + 2"
just eval "'hello world'"
just eval "'can''t' size"
just eval "Dictionary new at: #answer put: 42; yourself"
just eval "| value | value := 40. value + 2"
```

This is invalid because the shell supplies three arguments:

```sh
just eval 1 + 2
```

The recipe applies `just`'s `quote()` to the already parsed argument, so quotes
and newlines that reach `just` are preserved. The caller's shell still expands
double-quoted `$`, backticks, command substitutions, backslashes, and double
quotes. Escape Smalltalk character literals in a double-quoted shell argument:

```sh
just eval "'A' first = \$A"
```

Shell single quotes protect `$` and backticks but cannot directly contain a
single quote. Bash/zsh ANSI-C quoting is convenient for short multiline code:

```sh
just eval $'| value |\nvalue := \'hello\'.\nvalue size'
```

For long or quote-heavy code, use an ignored file under `tmp/` and pass its
contents as one argument:

```sh
just eval "$(cat ./tmp/eval.st)"
```

Command substitution removes trailing newlines. The file must contain one
do-it accepted by `Smalltalk compiler evaluate:`, not a Tonel definition or a
general `.st` file-in. Image mutations disappear with the successful run;
external filesystem, database, or network side effects naturally persist.

## Legacy Export Compatibility

`just push-src-to-export` and `just pull-export-to-src` remain
default-context compatibility wrappers for direct use of the shared ignored
`export/` Iceberg repository. `push` mirrors `src/` into `export/src/` and
commits it because `gitlocal://` ignores an uncommitted working tree. `pull`
mirrors the export working tree back into authoritative `src/`.

The layered `build`, `test`, `eval`, and `gui` commands do not depend on this
shared bridge. They generate an exact-revision bridge per build or run, which
prevents one context from loading another context's source.
