# KlibGen-gt

KlibGen-gt is a Glamorous Toolkit / Pharo Smalltalk project scaffolded for
reproducible, source-controlled development. Smalltalk code is kept in Tonel
format under `src/`, while the mutable Glamorous Toolkit runtime is downloaded
locally into `vendor/gt` and ignored by version control.

This project is another rewrite and as such, has to support multiple legacy
formats (or at least provide a migration path) used in previous versions of the
software.

The project is just starting out, and aims to test the capabilities of moldable
development paradigm as espoused by GToolkit.

## Runtime

Do not commit GT images, changes files, logs, caches, downloads, or generated
artifacts. The image is disposable project state; the source of truth lives in
VCS under `src/`.

The pinned runtime metadata lives in `.tool-versions-or-lock/`:

- `gt-version` records the intended GT release.
- `gt-linux-x86_64.url` contains the Linux x86_64 GT zip URL. Fill this with
  the matching asset URL from the GT download or GitHub release page when
  updating the runtime.
- `gt-linux-x86_64.sha256` contains the SHA256 for that exact zip. Fill this
  with the checksum shown on the release page. `just bootstrap` verifies it
  before unpacking.

## Commands

All common operations go through `just`:

```sh
just bootstrap
just gui
just load
just test
just smoke
just eval "1 + 2"
just clean-runtime
```

`just bootstrap` downloads and unpacks GT into `vendor/gt`. `just gui` launches
the full GT UI. The `load`, `test`, `smoke`, and `eval` tasks run headlessly
through `./scripts/gt --headless`.

### Versioning

This project use JuJutsu (`jj`) as VCS - don't try to use git on it.
