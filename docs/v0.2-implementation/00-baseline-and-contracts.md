# Stage 00 — baseline and contracts

## 1. Goal and non-goals

Provide reproducible measurement, fake-process lifecycle coverage, and strict
v0.2 path ownership. This stage does not change any ordinary v0.1 command.

## 2. Prerequisites and starting state

The historical behavior and coupling inventory are in
`../klibgen-build-current-implementation.md`. Measurements use the current JJ
revision and committed `build/locks/default.lock.json`.

## 3. Public APIs, commands, and schemas

`V2Paths` owns only `.klibgen/v2/`. `klibgen.measurement/1` records wall time,
logical/allocated bytes, and image/changes/native counts. Existing image-tool
responses remain schema version 1.

## 4. Implementation work packages

- `measurements.py` provides storage and operation measurements.
- `v2state.py` initializes the v0.2 layout and guards deletion.
- `build/tests/fixtures/fake_vm.py` emits ready/completion/failure/crash/timeout
  lifecycle outcomes from `klibgen.session/1` fixture manifests.

## 5. State transitions, locking, cleanup, and failures

Deletion rejects the v0.2 root and every path outside it. Fake crashes omit
completion deliberately so host code can classify protocol failure.

## 6. Tests and acceptance scenarios

Run `just test-build-tools`. For a machine baseline, profile the scenarios below
with `klibgen-build host profile --json -- COMMAND` and record state-root storage
before and after using `storage_metrics`:

| Scenario | Command/front door | Required observations |
| --- | --- | --- |
| cold build | `just build l06 default` in empty disposable state | wall, VM starts, storage |
| unchanged build | repeat cold command | wall, zero rebuild VM starts |
| project-only | edit fixture project source, rebuild, restore | invalidated layers, VM starts |
| tests | passing and failing `just test-one` | retained failure state |
| GUI fresh/resume | `just gui-fresh`, then `just gui` | starts, complete images, save size |
| build map | `just build-map` | starts, preparation artifact/storage |

Machine-specific numeric results are intentionally not committed as universal
facts; reports should include hostname/platform, JJ commit, lock digest, command,
and timestamp so v0.1/v0.2 comparisons remain reproducible.

## 7. Exit criteria and handoff evidence

Host tests exercise all lifecycle record shapes without GT. The layout and
deletion contract are tested. The measurement procedure covers every required
scenario and produces named/versioned records.

## 8. V0.1 mechanisms retained or retired

All v0.1 contexts, layers, runs, snapshots, bridges, commands, and generated
state remain operational and untouched.
