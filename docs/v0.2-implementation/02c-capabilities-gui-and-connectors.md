# Stage 02C — capabilities, GUI, and connectors

## 1. Goal and non-goals

Centralize all mutation/persistence enforcement and adapt connector work; host
session workflows remain Phase 3.

## 2. Prerequisites and starting state

Requires the Stage 02A kernel and Stage 02B registry.

## 3. Public APIs, commands, and schemas

Add disabled/staged/interactive source capabilities, discard/workspace
persistence, connector compatibility advertisement, and structured `tool.open`.

## 4. Implementation work packages

Route export buttons/tools/hooks and save/close through capabilities. Transplant
JJ change `lrtvwumw`, using session identity and registry/input compatibility.

## 5. State transitions, locking, cleanup, and failures

Unavailable controls reflect capability state, while capabilities enforce all
indirect calls. Filesystem is installed/default; TCP stays API/test-only.

## 6. Tests and acceptance scenarios

Fresh-image tests cover export denial, staged/interactive routing,
save/discard/cancel, connector negotiation, and `tool.open`.

## 7. Exit criteria and handoff evidence

All public APIs have class docs/type pragmas, `KlibGenGt` indexes classes, and no
mutation/save policy depends on scattered mode checks.

## 8. V0.1 mechanisms retained or retired

Retire direct environment/export and GUI-save policy paths after capability tests.
