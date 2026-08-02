# Stage 05 — cutover and removal

## 1. Goal and non-goals

Make v0.2 ordinary and remove v0.1 production machinery. The normal cutover
does not interpret old state; this implementation pass additionally removed
the locally verified legacy generated artifacts at the user's request.

## 2. Prerequisites and starting state

All prior stage exits and normative acceptance scenarios must pass.

## 3. Public APIs, commands, and schemas

Promote v2 services to top-level CLI/`just` commands, then remove the temporary
namespace. Publish explicit GUI import or fresh-start migration guidance.

## 4. Implementation work packages

Update README, AGENTS, skills, recovery notes, and examples. Delete production
contexts/layers/runs/attempts/snapshots/refresh/fresh-test/tool-special cases and
their schemas/modules after live-reference search.

## 5. State transitions, locking, cleanup, and failures

Never interpret existing v0.1 state as current state. Cutover is atomic at the
front doors; rollback uses the pre-cutover revision, not dual engines. Legacy
deletion is an explicit maintenance action over exact audited paths.

## 6. Tests and acceptance scenarios

Run all normative scenarios, concurrency/termination, schema validation,
clean-root loading, disposable GC, FFI/native integrity, cold/warm measurements,
and final baseline comparison.

## 7. Exit criteria and handoff evidence

`just check-type-pragmas`, `just test-build-tools`, `just test`, and
`just test-fresh` pass; searches show no live production v0.1 references.

## 8. V0.1 mechanisms retained or retired

All production v0.1 machinery is retired. The audited local v0.1 artifacts,
runs, snapshots, contexts, attempts, fresh-test roots, and clean legacy export
bridge were removed. `.klibgen/` now contains only the current `v2/` root.
