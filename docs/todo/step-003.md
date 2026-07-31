# Step 003: resolution and immutable locks

## TODO

- [ ] Implement archive, Git, and JJ source resolvers.
- [ ] Commit the default external-input lock.
- [ ] Pin SQLite3 to the resolved commit and verify baseline/lock agreement.
- [ ] Capture declared host facts and reject unresolved canonical inputs.
- [ ] Implement `just resolve` with check and explicit update modes.

## Acceptance

Repeated resolution is stable, moving selectors cannot enter a canonical
manifest, and legacy/fresh tests pass.

## Rollback

Restore the previous baseline selector and abandon the stage change.
