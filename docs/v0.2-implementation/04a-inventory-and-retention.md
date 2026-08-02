# Stage 04A — inventory and retention

## 1. Goal and non-goals

Describe and retain v0.2 graph/state without legacy layer/run/snapshot concepts.

## 2. Prerequisites and starting state

Requires artifacts, refs, sessions, staging, and workspace records from Phases
1–3.

## 3. Public APIs, commands, and schemas

Add v2 inventory and GC dry-run/apply commands with inventory schema v2.

## 4. Implementation work packages

Inventory recipes, resolved sequences, graph edges, artifacts, runtime bundles,
refs, workspace, staging, active sessions, statuses, locks, pins, and storage.
Refactor Smalltalk build-map layout to derive from sequences/edges.

## 5. State transitions, locking, cleanup, and failures

Retention roots are refs, workspace, staging, active operations, and pins. GC
uses a stable plan and strict owned-path deletion; malformed roots are protected.

## 6. Tests and acceptance scenarios

Cover graph/layout alternatives, broken records, symlinks, concurrent activity,
dry-run/apply equivalence, root preservation, diagnostic rotation, and disposable
root application.

## 7. Exit criteria and handoff evidence

Inventory contains no assumed contexts, L01–L07 columns, attempts, runs,
snapshots, or pointers; routine GC preserves all mutable roots.

## 8. V0.1 mechanisms retained or retired

V0.1 inventory/retention remains isolated for old commands until cutover.
