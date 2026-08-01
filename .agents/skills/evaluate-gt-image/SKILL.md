---
name: evaluate-gt-image
description: Evaluate diagnostic Smalltalk expressions or sampling profiles in a fresh isolated Glamorous Toolkit project image. Use for quick runtime checks, object inspection, API experiments, profiler reports, and one-off GT search-filter expressions that are not yet supported by a structured image tool.
---

# Evaluate a GT Image

Use evaluation for focused diagnostics, not as a substitute for a structured tool or source edit. Each invocation creates an isolated CLI run from the selected context; successful runs are removed and failed runs are retained for diagnosis.

## Evaluate expressions

Use `just` for a short expression:

```sh
just eval '40 + 2'
```

Use the image CLI when JSON, another context, a file, or stdin is needed:

```sh
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build image eval \
  'KlibGenGt projectName' --context default --json
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build image eval \
  --file ./tmp/diagnostic.st --context default --json
```

Provide exactly one of a positional expression, `--file`, or `--stdin`. Put temporary scripts under `./tmp/` and never track them.

The result is `printString`, not a general object serializer. Return a compact collection, dictionary, string, number, or boolean when the output will be consumed by an agent.

## Profile image behavior

```sh
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build image eval \
  '10000 factorial digitSum' --profile --context default --json
```

Profiling adds elapsed image time, sample count, and the textual `AndreasSystemProfiler` report. Use `$operate-gt-host` when profiling a shell command rather than Smalltalk execution.

## Diagnose SUnit failures

Prefer the structured test commands over temporary evaluation scripts:

```sh
just test-one KlibGenGtTest testProjectName default
just test-diagnose <run-id-or-attempt-id>
just test-one-json KlibGenGtTest testProjectName default
just test-diagnose-json <run-id-or-attempt-id>
```

`test-one` runs one selector in an isolated current project image. Failed runs
are retained and include `logs/test-results.json`. Project build contracts write
`contract-results.json` into retained attempts, which `test-diagnose` reads
without reopening a possibly partial image. Set `KLIBGEN_STATE_ROOT` to the
state root that produced the record when it is not `.klibgen`.

Use `image eval --file ./tmp/diagnostic.st` only when the structured test report
cannot answer the question, such as inspecting an unrelated runtime object or
experimenting with an image API.

## Apply safety and tool boundaries

- Prefer read-only expressions. Do not use evaluation to edit Tonel source, persist image state, or bypass the `src/` and `export/` workflow.
- Inspect an expression before running it. Arbitrary Smalltalk can access files, processes, and the network even though the image run itself is disposable.
- Use structured code or Lepiter tools whenever they cover the request.
- Use direct GT filter DSL only for one-off exploration; read `$search-gt-code` and its filter reference first.
- On failure, report the structured compile/runtime error and retained `runPath`. Do not assume partial image state should be reused.
