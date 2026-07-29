# KlibGen-gt

KlibGen-gt is a Glamorous Toolkit / Pharo Smalltalk project scaffolded for
reproducible, source-controlled development. Smalltalk code is kept in Tonel
format under `src/`, while mutable Glamorous Toolkit runtimes live under
`vendor/` and are ignored by version control.

This project is another rewrite and as such, has to support multiple legacy
formats (or at least provide a migration path) used in previous versions of the
software.

The project is just starting out, and aims to test the capabilities of moldable
development paradigm as espoused by GToolkit.

## Files, Images, and State

There are three separate layers of project state. Keeping them distinct avoids
most confusion between image state and versioned source state.

| Path | Role | Versioned? |
| --- | --- | --- |
| `src/` | Canonical Tonel source for KlibGenGt and its baseline. | Yes, by the outer JuJutsu repository. |
| `lepiter/`, `data/`, `docs/` | Tracked documentation, fixtures, and other non-image project data. | Yes, subject to `.gitignore`. |
| `export/` | Iceberg-facing nested Git repository. Metacello loads its committed `master/src`, not `src/` directly and not an uncommitted export working tree. | No in the outer repository; it has its own ignored `.git/`. |
| `vendor/gt/` | Unpacked downloaded GT runtime, including `GlamorousToolkit.image`, launchers, changes files, and runtime-local Iceberg clones. | No. |
| `vendor/gt.zip` | Verified downloaded GT archive. It is also the seed used by `just test-fresh`. | No. |
| `vendor/gt-build/sources/{clean,patched}/` | Local GT source checkouts and patch branches used for source builds. | No; deliberately preserved across `just clean-runtime`. |
| `vendor/gt-build/workspaces/{clean,patched}/` | Complete source-built runtimes and their images. | No. |
| `gt-local/<runtime>/` | Separate `HOME`, XDG config, and XDG cache directories used while running each selected runtime. | No. |
| `artifacts/fresh-test/` | Runtime unpacked from `vendor/gt.zip` for the latest `just test-fresh` invocation. Replaced on every fresh test. | No. |
| `tmp/` | Project-local temporary files and longer `just eval` snippets. | No. |

Images, changes files, logs, caches, downloads, and generated artifacts are
disposable. Project code must be recoverable from `src/`; an image is never the
source of truth.

## Source Synchronization

The outer repository and the Iceberg repository intentionally use different
version-control systems:

```text
outer JJ repository:  src/
                         |
                just push-src-to-export
                         v
ignored nested Git:   export/src/ -> commit on export/master
                         |
              gitlocal://.../export/.git:master/src
                         v
selected GT image:    classes loaded into the running image
```

`just push-src-to-export` uses `rsync --delete` to make `export/src/` match
`src/`, stages the result, and creates a `Sync src to export` commit when there
are changes. The commit is required because `gitlocal://` reads committed Git
contents. Before pushing, make sure `export/` does not contain GUI/Iceberg work
that still needs to be pulled; pushing can overwrite it.

After editing through GT and committing/file-out through Iceberg, copy the
result back with:

```sh
just pull-export-to-src
```

This uses `rsync --delete` in the opposite direction. Review and commit the
result with `jj`. It does not create an outer JJ commit.

For direct filesystem development, the normal loop is:

```sh
# Edit files under src/ and tests under src/*-Tests.
just push-src-to-export
just test
```

`just check-type-pragmas` and `just test-fresh` already depend on
`push-src-to-export`. `just gui`, `just load`, `just test`, `just smoke`, and
`just eval` do not push automatically; they load the current committed export
revision.

## Project Loading

Every GUI or headless project-loading script uses the same sequence:

1. Locate `export/.git` and construct
   `gitlocal://<absolute-export-.git>:master/src`.
2. Remove a stale Iceberg registration for that local export path, if present.
3. Run Metacello `get` and then load the baseline's `CI` group, resolving
   repository conflicts in favor of incoming committed contents.
4. Let Metacello/Iceberg clone or update declared dependencies such as
   Pharo-SQLite3. A network connection can therefore be required during load.

The `CI` group currently includes all development packages and tests. Loading
places those classes in the running image process. It does not copy from
`src/`, and it does not make uncommitted `export/src/` changes visible.

Headless commands load the project into memory, perform their action, and exit;
they do not intentionally snapshot the selected runtime image. In particular,
`just load` validates that the project and dependencies load, then quits. It
does not create a new preloaded project image.

`just gui` runs the same load before opening the interactive GT UI. Interactive
image state can be changed or explicitly saved, but remains ignored and
disposable. Persist project code through Iceberg and pull it back to `src/`.

## Runtime Images

The pinned runtime metadata lives in `.tool-versions-or-lock/`:

- `gt-version`, `gt-linux-x86_64.url`, and `gt-linux-x86_64.sha256` select and
  verify the downloaded Linux x86_64 archive.
- `gt-installer-version`, `gt-installer-linux-x86_64.url`, and
  `gt-installer-linux-x86_64.sha256` pin the installer used for source builds.

Three runtime selectors are supported:

| `GT_RUNTIME` | Image | How it is created |
| --- | --- | --- |
| `download` (default) | `vendor/gt/GlamorousToolkit.image` | `just bootstrap` or `just bootstrap-download` downloads, verifies, and unpacks the pinned archive. A matching version-and-loader marker allows reuse; a mismatch reinstalls it. |
| `build-clean` | `vendor/gt-build/workspaces/clean/GlamorousToolkit.image` | `just bootstrap-build-clean` uses the pinned GT installer and local clean GT source checkouts. |
| `build-patched` | `vendor/gt-build/workspaces/patched/GlamorousToolkit.image` | `just bootstrap-build-patched` seeds patched sources from clean sources when needed, applies local patches, builds, patches the image, and snapshots it. |

Select a runtime per command:

```sh
GT_RUNTIME=download just gui
GT_RUNTIME=build-clean just test
GT_RUNTIME=build-patched just smoke
GT_RUNTIME=build-patched just eval "1 + 2"
```

`scripts/gt` automatically bootstraps a selected runtime when its launcher or
image is missing. An unknown selector fails with the allowed values. Each
selector gets independent config/cache state under `gt-local/<runtime>/`.

Source builds use the installer's current upstream source-build flow. Set
`GT_SOURCE_VERSION` only when creating a source workspace and an explicit
upstream version is needed:

```sh
GT_SOURCE_VERSION=<supported-version> just bootstrap-build-clean
```

An already complete workspace is reused, so changing `GT_SOURCE_VERSION` alone
does not rebuild it. `fetch-gt-sources-clean` and `fetch-gt-sources-patched`
only fetch all nested GT Git repositories; they do not merge, switch branches,
or rebuild the runtime.

The patched runtime changes WebView startup so GTK initialization is skipped in
headless mode. This removes the known `Failed to initialize GTK` warning from
that runtime's headless commands.

## Recreating Images

To remove disposable runtime state and rebuild from the pinned inputs:

```sh
just clean-runtime
just bootstrap
```

`clean-runtime` removes the downloaded runtime and archive, both source-built
workspaces, per-runtime `gt-local/` state, root-level Pharo artifacts, and the
contents of `artifacts/`. It preserves `src/`, `export/`, the outer repository,
`vendor/gt-build/sources/`, and the downloaded GT installer.

Recreate source-built images afterward with:

```sh
just bootstrap-build-clean
just bootstrap-build-patched
```

`just test-fresh` is different from selecting a runtime. It always:

1. Pushes `src/` to committed `export/master`.
2. Ensures the downloaded runtime/archive exists through `just bootstrap`.
3. Deletes and recreates `artifacts/fresh-test/`.
4. Unpacks a new runtime from `vendor/gt.zip`.
5. Uses isolated home/config/cache directories under `artifacts/fresh-test/`.
6. Loads the project and dependencies and runs the SUnit suite.

`GT_RUNTIME` does not affect `just test-fresh`; it always tests the downloaded
archive in a disposable directory. The extracted directory remains for
inspection after the run but is deleted at the start of the next fresh test.

## Commands

All common operations go through `just`:

| Command | Effect |
| --- | --- |
| `just bootstrap` | Alias for `bootstrap-download`. |
| `just bootstrap-download` | Ensure the pinned downloaded runtime is installed in `vendor/gt`. |
| `just bootstrap-build-clean` | Build/reuse the clean source runtime. |
| `just bootstrap-build-patched` | Build/reuse the patched source runtime. |
| `just fetch-gt-sources-clean` | Fetch every nested Git repository in the clean GT sources. |
| `just fetch-gt-sources-patched` | Fetch every nested Git repository in the patched GT sources. |
| `just push-src-to-export` | Mirror `src/` to `export/src/` and commit the nested Git repository. |
| `just pull-export-to-src` | Mirror the export working tree back to `src/`. |
| `just gui` | Load `CI` from committed export and launch interactive GT. |
| `just load` | Load `CI` headlessly and exit. |
| `just test` | Load `CI` in the selected existing runtime, run `KlibGenGt-Tests`, and exit nonzero on failure. Does not push first. |
| `just test-fresh` | Push, unpack a fresh downloaded runtime, load, and test. |
| `just check-type-pragmas` | Push, load, run `KGCheckTypePragmas`, and exit nonzero on invalid annotations. |
| `just smoke` | Load and verify the project anchor class/name. |
| `just eval "..."` | Load `CI`, compile one Smalltalk do-it, print its result with `printString`, and exit. |
| `just clean-runtime` | Delete disposable images, workspaces, caches, and artifacts as described above. |

## `just eval`

`just eval` loads the complete `CI` group before compiling the supplied code,
so project and dependency classes are available. The code is passed through the
`GT_EVAL` environment variable to `Smalltalk compiler evaluate:`. The returned
object is printed using `printString`. Compiler errors and runtime exceptions
make the command fail and print a Pharo stack.

The expression must be exactly one shell argument. This works:

```sh
just eval "1 + 2"
```

This does not, because the shell gives `just` three arguments and `just` starts
interpreting the extra words as recipe names:

```sh
just eval 1 + 2
```

The recipe uses `just`'s `quote()` function, so single quotes and newlines that
reach `just` are safely preserved when `GT_EVAL` is assigned. Normal Smalltalk
string literals therefore work without recipe-specific escaping:

```sh
just eval "'hello world'"
just eval "'can''t' size"
just eval "Dictionary new at: #answer put: 42; yourself"
just eval "| value | value := 40. value + 2"
```

The caller's shell still processes the argument before `just` sees it. With
double-quoted shell arguments, escape shell-sensitive `$`, backticks, command
substitution, backslashes where applicable, and literal double quotes. For
example, Smalltalk's character literal `$A` must escape the dollar from the
shell:

```sh
just eval "'A' first = \$A"
```

Shell single quotes protect `$` and backticks but cannot directly contain a
single quote, which makes them inconvenient for Smalltalk strings. Bash and zsh
ANSI-C quoting is useful for a short multiline do-it:

```sh
just eval $'| value |\nvalue := \'hello\'.\nvalue size'
```

For longer or quote-heavy code, put the do-it in ignored `tmp/` and pass its
contents as one double-quoted command-substitution result:

```sh
just eval "$(cat ./tmp/eval.st)"
```

Command substitution removes trailing newlines, which does not affect a normal
do-it. The file must contain code accepted by `Smalltalk compiler evaluate:`,
not a Tonel class definition or an arbitrary `.st` file-in. Temporary class or
method changes made by an eval exist only in that headless process unless the
code explicitly writes them elsewhere; filesystem/database/network side
effects naturally persist.

## Versioning

The outer project uses JuJutsu (`jj`). Do not run Git commands against the
project root. Git is used only inside deliberately nested repositories such as
`export/` and Iceberg dependency checkouts.
