# Step 007: L04 dependencies

## TODO

- [ ] Declare deterministic dependency order and verification actions.
- [ ] Build SQLite3 from its lock into a dependency-only canonical image.
- [ ] Record repository, package, load-order, and override metadata.
- [ ] Support an explicit context-local Git worktree override.
- [ ] Test default and forked dependency identities independently.

## Acceptance

SQLite examples work from L04 descendants, no moving revision remains, and
legacy/fresh tests pass.

## Rollback

The baseline remains directly loadable by compatibility commands; abandon the change.
