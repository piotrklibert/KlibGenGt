# Stage 02B — tool registry and migration

## 1. Goal and non-goals

Move every current image tool to deterministic registry dispatch; full mutable
capabilities and connectors follow in 02C.

## 2. Prerequisites and starting state

Requires Stage 02A session/entrypoint protocols.

## 3. Public APIs, commands, and schemas

Registrations declare identifier/version, accepted input/request schema,
frontends, and capabilities. Responses retain schema version 1.

## 4. Implementation work packages

Migrate evaluation/profile, tests, code, Lepiter, PNG export, and build-map open.
Make `KGToolRunner` use lookup and `KGBuildMapTool` consume session inputs.

## 5. State transitions, locking, cleanup, and failures

Duplicate and unknown registrations fail deterministically before tool work.

## 6. Tests and acceptance scenarios

Test complete registration inventory, schema/capability rejection, each migrated
operation, duplicates, unknown identifiers, and response compatibility.

## 7. Exit criteria and handoff evidence

No current tool uses an operation equality chain or prepared class state.

## 8. V0.1 mechanisms retained or retired

Remove tool-specific `SessionManager` registration and environment-only build-map
inventory paths; retain v0.1 host launchers until Phase 4.
