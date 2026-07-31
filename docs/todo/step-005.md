# Step 005: canonical image lifecycle

## TODO

- [ ] Build in isolated attempts under a per-key `flock`.
- [ ] Copy parent bundles with reflink-auto and never hard-link mutable images.
- [ ] Save, stop, test, checksum, and atomically publish artifacts.
- [ ] Create writable run copies with independent HOME/XDG state.
- [ ] Retain successful artifacts when forced builds fail.

## Acceptance

Canonical mutation, failure recovery, repeated-key reuse, and concurrent-key
tests pass along with legacy/fresh tests.

## Rollback

No compatibility command depends on the new builder yet; abandon the change.
