# Stage 03B — staging and promotion

## 1. Goal and non-goals

Make named source overlays the durable output of agentic work; no saved agentic
images are retained.

## 2. Prerequisites and starting state

Requires Stage 03A sessions and Stage 02C staged-source capability.

## 3. Public APIs, commands, and schemas

Add staging list/create/reset/promote and agentic commands plus a named/versioned
staging manifest.

## 4. Implementation work packages

Represent additions/modifications/removals/renames, base identity, package
ownership, overlay loading/export, and conflict-checked host promotion.

## 5. State transitions, locking, cleanup, and failures

Promotion is serialized, base-checked, path/package restricted, and atomic per
validated plan. Conflicts preserve staging and report without partial promotion.

## 6. Tests and acceptance scenarios

Cover every change kind, stale base, overlap, rename conflicts, prohibited paths,
concurrent promotion, retry, and reviewable uncommitted repository output.

## 7. Exit criteria and handoff evidence

Agentic work survives process loss as source-form staging and promotes safely.

## 8. V0.1 mechanisms retained or retired

Retire v0.1 agentic source bridges only after equivalent staging acceptance.
