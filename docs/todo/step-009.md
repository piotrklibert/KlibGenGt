# Step 009: L06 project source and command cutover

## TODO

- [ ] Resolve and archive an exact JJ workspace commit.
- [ ] Create a context-local generated Iceberg Git bridge from that archive.
- [ ] Load and test project packages without persisting stale absolute bindings.
- [ ] Rebind each writable run to its own export bridge.
- [ ] Cut compatible load/test/fresh/gui/eval/smoke/type commands over after parity tests.

## Acceptance

Project changes alter L06/L07 keys, canonical parents remain unchanged, all
compatibility commands pass, and a clean L06 CLI/GUI build succeeds.

## Rollback

Revert the wrapper switch to the legacy scripts; existing runtime directories remain intact.
