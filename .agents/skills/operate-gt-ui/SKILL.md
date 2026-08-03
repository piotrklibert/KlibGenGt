---
name: operate-gt-ui
description: Inspect, uniquely select, act on, and wait for instantiated elements in a live Glamorous Toolkit GUI launched by this repository. Use for coordinate-free interaction with a managed `just gui` image, including hidden or offscreen Bloc nodes, text entry, shortcuts, scrolling, dragging, and live-image diagnostic evaluation.
---

# Operate GT UI

Drive the live Bloc scene through the GUI-workspace control service. Prefer this structured interface to screen coordinates.

## Follow the control loop

1. Confirm the ready GUI workspace with `klibgen-build ui status --json`.
2. Inspect with `ui spaces`, `ui tree`, or `ui query`. Narrow queries with `--space`, `--under`, `--depth`, `--class`, `--element-id`, text filters, and state filters. Depth is relative to the scene or `--under` root, which is depth 0; `--limit` independently caps node count.
3. Require a unique target before mutation. Reuse its `nodeId` with `--node`; handles remain valid only for the reported workspace session.
4. Act with `ui act ACTION`, then use `ui wait STATE` and re-inspect to verify the resulting focus, text, visibility, or hierarchy.
5. Use a batch for a bounded sequence whose later steps depend on earlier ones. Inspect the completed results and first-failure record.
6. If visual evidence matters, use `$operate-gt-host` after structured verification to capture the exact managed window.

Example:

```sh
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build ui query \
  --class BrButton --text Save --json
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build ui act click \
  --node node-42 --json
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build ui wait visible \
  --text-contains Saved --json
```

Use `ui eval EXPR|--file FILE|--stdin` only as an explicit diagnostic escape hatch in the live image. Keep ordinary interaction in inspect/query/action/wait operations, and never put eval in a batch.

## Respect boundaries

- Inspect all instantiated scene nodes by default, including hidden, gone, clipped, and offscreen elements. Virtualized items that have not been instantiated do not exist in the scene graph and cannot be selected.
- Use `$operate-gt-host` for window lifecycle, screenshots, process checks, or host profiling.
- Use `$evaluate-gt-image` for disposable diagnostics that must not affect the live GUI.
- Do not use external window-coordinate automation for element interaction when this service is available.
- Treat an ambiguous selector as evidence to narrow the query; do not guess among candidates.
