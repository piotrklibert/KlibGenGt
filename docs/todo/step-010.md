# Step 010: runs, snapshots, and promotion

## TODO

- [ ] Track run IDs, PIDs, logs, runtime arguments, and allocated resources.
- [ ] Implement snapshot, resume, discard, and clean-runs operations.
- [ ] Record the L06 parent and JJ source revision in every snapshot.
- [ ] Promote explicit packages only after source/destination conflict checks.
- [ ] Keep push/pull recipes as default-context compatibility wrappers.

## Acceptance

Canonical images never change, snapshots resume, L07 ignores snapshots, promotion
updates only selected JJ workspace packages, and fresh tests pass.

## Rollback

Snapshots and runs are ignored disposable state; abandon the change.
