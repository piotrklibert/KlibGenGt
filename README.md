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

## Runtime

Do not commit GT images, changes files, logs, caches, downloads, local GT source
checkouts, or generated artifacts. The image is disposable project state; this
project's source of truth lives in VCS under `src/`.

The pinned runtime metadata lives in `.tool-versions-or-lock/`:

- `gt-version` records the intended downloaded GT release.
- `gt-linux-x86_64.url` contains the Linux x86_64 GT zip URL. Fill this with
  the matching asset URL from the GT download or GitHub release page when
  updating the runtime.
- `gt-linux-x86_64.sha256` contains the SHA256 for that exact zip. Fill this
  with the checksum shown on the release page. `just bootstrap` verifies it
  before unpacking.
- `gt-installer-version`, `gt-installer-linux-x86_64.url`, and
  `gt-installer-linux-x86_64.sha256` pin the GT installer used for local source
  builds.

The default runtime is the downloaded release in `vendor/gt`. For local GT
development, source-built runtimes live under `vendor/gt-build/`:

- `vendor/gt-build/workspaces/clean` is built from unmodified GT sources.
- `vendor/gt-build/workspaces/patched` is built from local patched GT sources.
- `vendor/gt-build/sources/patched` is intentionally preserved by
  `just clean-runtime` so local GT patch branches can be updated or merged later.

## Commands

All common operations go through `just`:

```sh
just bootstrap
just bootstrap-download
just bootstrap-build-clean
just bootstrap-build-patched
just push-src-to-export
just pull-export-to-src
just gui
just load
just test
just smoke
just eval "1 + 2"
just clean-runtime
```

`just bootstrap` and `just bootstrap-download` download and unpack GT into
`vendor/gt`. `just gui` launches the full GT UI. The `load`, `test`, `smoke`,
and `eval` tasks run headlessly through `./scripts/gt --headless`.

GT and Iceberg edit code through the ignored nested Git repository in
`export/`. The JJ-versioned source of truth remains `src/`. Before opening GT
after editing files directly, run `just push-src-to-export` to mirror `src/`
into `export/src/`. After saving changes from GT/Iceberg into `export/src/`,
run `just pull-export-to-src` to mirror them back into `src/`. These sync tasks
use `rsync` and do not create Git commits inside `export/`.

Select a runtime with `GT_RUNTIME`:

```sh
GT_RUNTIME=download just smoke
GT_RUNTIME=build-clean just smoke
GT_RUNTIME=build-patched just smoke
GT_RUNTIME=build-patched just gui
```

The `build-patched` runtime applies the local GT WebView startup patch that
skips GTK initialization in headless mode, removing the specific
`Failed to initialize GTK` warning from headless runs of that local image.
Source builds use the GT installer's current upstream source-build flow by
default so local changes can be merged forward. Set `GT_SOURCE_VERSION` when you
need to force a specific GT source version and the upstream build supports it.

### Versioning

This project use JuJutsu (`jj`) as VCS - don't try to use git on it.
