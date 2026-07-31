# Step 007: L04 dependencies

## TODO

- [x] Declare deterministic dependency order and verification actions.
- [x] Build SQLite3 from its lock into a dependency-only canonical image.
- [x] Record repository, package, load-order, and override metadata.
- [x] Support an explicit context-local Git worktree override.
- [x] Test default and forked dependency identities independently.

## Acceptance

SQLite examples work from L04 descendants, no moving revision remains, and
legacy/fresh tests pass.

## Rollback

The baseline remains directly loadable by compatibility commands; abandon the change.
