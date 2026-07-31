# Step 010: runs, snapshots, and promotion

## TODO

- [x] Track run IDs, PIDs, logs, runtime arguments, and allocated resources.
- [x] Implement snapshot, resume, discard, and clean-runs operations.
- [x] Record the L06 parent and JJ source revision in every snapshot.
- [x] Promote explicit packages only after source/destination conflict checks.
- [x] Keep push/pull recipes as default-context compatibility wrappers.

## Acceptance

Canonical images never change, snapshots resume, L07 ignores snapshots, promotion
updates only selected JJ workspace packages, and fresh tests pass.

## Rollback

Snapshots and runs are ignored disposable state; abandon the change.
