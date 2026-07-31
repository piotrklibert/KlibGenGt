# Step 003: resolution and immutable locks

## TODO

- [x] Implement archive, Git, and JJ source resolvers.
- [x] Commit the default external-input lock.
- [x] Pin SQLite3 to the resolved commit and verify baseline/lock agreement.
- [x] Capture declared host facts and reject unresolved canonical inputs.
- [x] Implement `just resolve` with check and explicit update modes.

## Acceptance

Repeated resolution is stable, moving selectors cannot enter a canonical
manifest, and legacy/fresh tests pass.

## Rollback

Restore the previous baseline selector and abandon the stage change.
