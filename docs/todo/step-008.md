# Step 008: L05 setup profiles

## TODO

- [x] Build distinct CLI and GUI setup artifacts; add an explicit AGENTIC placeholder.
- [x] Add a build-owned Smalltalk manifest metadata API backed by canonical JSON.
- [x] Separate committed, generated, machine-local, and runtime configuration.
- [x] Test CLI/GUI capabilities, evaluation, path independence, and manifest queries.

## Acceptance

CLI and GUI satisfy their declared contracts from fresh parent copies and all
legacy/fresh tests pass.

## Rollback

No existing command uses L05 by default yet; abandon the change.
