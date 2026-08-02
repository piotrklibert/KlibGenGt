# Stage 04B — registered GUI tools

## 1. Goal and non-goals

Launch any registered GUI tool through explicit inputs, reusing one compatible
GUI when available.

## 2. Prerequisites and starting state

Requires the registry/connectors and v2 inventory/session lifecycle.

## 3. Public APIs, commands, and schemas

Define generic host tool launch/input-consumption acknowledgement. Build-map and
PNG export become registrations rather than launch special cases.

## 4. Implementation work packages

Validate/digest inputs, negotiate one active GUI via `tool.open`, await input
acknowledgement, and fall back to a one-start disposable GUI.

## 5. State transitions, locking, cleanup, and failures

Ambiguous/incompatible GUIs fall back deterministically. Cold sessions discard
image state and keep bounded result/log state only.

## 6. Tests and acceptance scenarios

Measure cold one-VM/no-preparation-save and warm zero-VM behavior; test ack
timeouts, connector incompatibility, input mismatch, and fallback cleanup.

## 7. Exit criteria and handoff evidence

Build-map PNG uses generic registry dispatch with explicit inventory input;
filesystem is the default live-GUI connector and TCP is API/test-only. Generic
warm `tool.open` negotiation and the disposable GUI fallback remain a bounded
follow-up; textual build-map inspection and one-session PNG export are usable.

## 8. V0.1 mechanisms retained or retired

Remove tool-specific prepare/save/restart launchers after cold/warm acceptance.
