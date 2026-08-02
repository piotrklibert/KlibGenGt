# KlibGen-GT recipe/session v0.2 implementation index

The normative specification is
[`klibgen-gt-recipe-session-architecture-v0.2.md`](klibgen-gt-recipe-session-architecture-v0.2.md).
Stage documents record implementation detail and must defer to that specification.

## Macro-phase dependency graph

```text
00 -> 01A -> 01B -> 01C -> 02A -> 02B -> 02C
                                      |       |
                                      +-> 03A -> 03B -> 03C
                                                 |       |
                                                 +-> 04A -> 04B -> 05
```

## Stage status and delivered changes

| Stage | Status | Delivered or next evidence |
| --- | --- | --- |
| [00](v0.2-implementation/00-baseline-and-contracts.md) | implemented | path ownership, measurements, fake VM, and reproducible host baselines |
| [01A](v0.2-implementation/01a-recipe-resolution.md) | implemented | immutable recipes, exact declared-input resolution, schema, opt-in CLI, host tests |
| [01B](v0.2-implementation/01b-store-and-builder.md) | implemented | typed store, publication/status schemas, locking, reuse, concurrency, and failure cleanup |
| [01C](v0.2-implementation/01c-canonical-project-build.md) | implemented | canonical runtime/base/dependency/setup/project build and native presentation manifests |
| [02A](v0.2-implementation/02a-session-kernel.md) | implemented | image-side bootstrap, capabilities, ready/completion lifecycle, and provenance |
| [02B](v0.2-implementation/02b-tool-registry-and-migration.md) | implemented | registry dispatch and migration of every current image tool |
| [02C](v0.2-implementation/02c-capabilities-gui-and-connectors.md) | implemented | source/persistence variants, GUI lifecycle, filesystem and TCP connectors |
| [03A](v0.2-implementation/03a-headless-sessions.md) | implemented | lightweight disposable eval/test/image sessions |
| [03B](v0.2-implementation/03b-staging-and-promotion.md) | implemented | named overlays and serialized conflict-checked promotion |
| [03C](v0.2-implementation/03c-gui-workspace.md) | implemented | exclusive saved GUI workspace with fresh/resume/stale/save/discard lifecycle |
| [04A](v0.2-implementation/04a-inventory-and-retention.md) | implemented | inventory schema 2, generic build map, roots, and safe GC |
| [04B](v0.2-implementation/04b-registered-gui-tools.md) | usable subset | explicit-input registered build-map PNG export; generic warm `tool.open` remains a follow-up |
| [05](v0.2-implementation/05-cutover-and-removal.md) | implemented | top-level CLI/just cutover, production v0.1 deletion, generated-state cleanup, and final gates |

## Frozen cross-stage decisions

- `.klibgen/v2/` is the sole generated state root.
- `src/` remains authoritative; build support is early and excluded from late
  project-source invalidation.
- Artifact keys contain effective declared construction inputs, never recipe,
  target, preset, or frontend names.
- Exact manifests are authoritative; environment values only locate manifests
  and protocol endpoints.
- Smalltalk authors orderly lifecycle outcomes. Host absence/mismatch is a
  protocol failure. Failed operations retain bounded diagnostics, not images.
- Source mutation and persistence are capability protocols, not scattered mode
  branches.
- Filesystem is the default connector. TCP remains connector-API/test-only until
  separately wired.
- No compatibility abstraction spans the removed v0.1 engine and current engine.

## Schema and CLI compatibility policy

New records use named/versioned schema strings such as
`klibgen.resolved-recipe/1`; checked-in schemas live under `build/schemas/v2/`.
The current image-tool response envelope remains schema version 1. Recipe,
artifact, session, workspace, status, and inventory records have explicit named
schemas. Commands are top-level; the temporary `klibgen-build v2` namespace and
the old production parser have been removed.

## V0.2 acceptance-scenario matrix

| # | Scenario | Primary stage |
| --- | --- | --- |
| 1 | clean root builds runtime/base/dependency/project artifacts | 01C |
| 2 | failed build preserves prior artifact/ref | 01B |
| 3 | artifact identity ignores recipe/preset name | 01A |
| 4 | project edit invalidates late steps only | 01C |
| 5 | read-only session cannot export or save | 02C/03A |
| 6 | orderly lifecycle requires matching completion | 02A/03A |
| 7 | agentic changes survive as staging, not images | 03B |
| 8 | promotion detects base conflicts and is serialized | 03B |
| 9 | only GUI workspace retains mutable image state | 03C |
| 10 | GUI resumes and warns on stale provenance | 03C |
| 11 | GC preserves refs/workspace/staging/active operations | 04A |
| 12 | alternatives coexist without changing default refs | 01B/04A |
| 13 | concurrent read-only sessions share runtime/native data | 03A |
| 14 | registered tools use explicit input and generic dispatch | 02B/04B |
| 15 | cold GUI tool starts once; compatible warm tool starts zero VMs | 04B |
| 16 | clean-runtime loading and final v0.1 removal | 05 |

## Completion policy

Each stage is a separately reviewable unit and ends with focused tests plus
`just test`; Smalltalk stages also run `just check-type-pragmas` and fresh-image
validation. Do not create a new JJ change unless explicitly requested. Add one
line per completed task to the current JJ description.
