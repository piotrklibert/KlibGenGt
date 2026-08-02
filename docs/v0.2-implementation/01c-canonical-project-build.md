# Stage 01C — canonical project build

## 1. Goal and non-goals

Port real construction to one canonical project artifact; sessions remain out of
scope.

## 2. Prerequisites and starting state

Requires generic Stage 01B checkpoint execution and publication.

## 3. Public APIs, commands, and schemas

The Stage 01B build command accepts standard targets/roles. Manifests add native
presentation strategy and stable build provenance.

## 4. Implementation work packages

Port runtime, GT, patches, build support, dependencies/setup, exact JJ source,
finalization, and contracts. Add early `KGBuildProvenance` support.

## 5. State transitions, locking, cleanup, and failures

Select symlink/hardlink/reflink/copy mechanically per payload family and verify
CLI, GUI, FFI, and save integrity before publication.

## 6. Tests and acceptance scenarios

Test clean root, unchanged zero-VM rebuild, project-only invalidation, shared
target project key, native integrity, and clean-runtime load.

## 7. Exit criteria and handoff evidence

Runtime, base, dependency/setup, and one project checkpoint build from empty v2
state; only one project image is published.

## 8. V0.1 mechanisms retained or retired

V0.1 remains operational/default; build-support is excluded from late source
identity.
