---
name: search-gt-code
description: Search classes and methods loaded in a fresh Glamorous Toolkit/Pharo image and retrieve exact class or method source. Use when investigating GT framework code, loaded project behavior, implementors, references, pragmas, or other image-side code relationships that filesystem search cannot reliably answer.
---

# Search GT Code

Use the structured image tools before constructing ad hoc Smalltalk queries. They run against a fresh project image and return bounded, machine-readable results.

## Choose the source of truth

- Use `rg` for the current repository text, especially uncommitted edits under `src/`.
- Use this skill for loaded Pharo entities, GT framework code, package metadata, and relationships computed by the image.
- Never edit generated image state or `vendor/` to make a source change. Make project source changes under `src/` and follow the repository workflow.

## Find candidates

Use the `just` shortcut for the common search:

```sh
just code-search 'KlibGenGt' all
just code-search 'projectName' method
```

Use the complete CLI for package restriction, limits, or JSON processing:

```sh
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build image code search 'projectName' \
  --kind method --package KlibGenGt-Core --limit 25 --json
```

Choose `--kind class`, `method`, or `all`. Treat search results as candidates; retrieve exact source before drawing conclusions.

## Retrieve exact source

```sh
just code-class KlibGenGt
just code-method KlibGenGt projectName class
```

The complete forms support JSON envelopes:

```sh
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build image code class KlibGenGt \
  --json
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build image code method KlibGenGt projectName \
  --side class --json
```

Specify `--side instance` or `--side class`; do not infer the side when the search result already reports it.

## Handle searches the tool does not cover

Read [references/gt-search-filters.md](references/gt-search-filters.md) when the request concerns implementors, references, pragmas, package/class membership, or composed GT filters.

Use direct filter evaluation only as an escape hatch for a one-off investigation. If a search is recurring, broadly useful, or needs stable machine-readable output, extend the structured tool instead:

1. Add a bounded JSON-compatible request/result contract to `KGCodeSearchTool` and register it in `KGToolRegistry`.
2. Expose the operation or flags through `klibgen-build image code`.
3. Add focused SUnit coverage and Python bridge/CLI coverage.
4. Update this skill and the user-facing command documentation.

Do not normalize repeated `image eval` snippets into workflow folklore; promote them into the tool.
