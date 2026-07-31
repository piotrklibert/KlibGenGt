# Reproducible build migration

These files are executable stage contracts for implementing
`docs/klibgen-gt-reproducible-build-architecture-v0.1.md`.

Complete the steps in numeric order. Each step must remain one independently
described JuJutsu change. A step is done only after its checklist and acceptance
commands pass from an isolated generated-state root.

The README documents current behavior. The architecture specification documents
the target. Update both whenever a completed step changes either contract.

- [Step 001](step-001.md): specification and JuJutsu alignment
- [Step 002](step-002.md): coordinator and state skeleton
- [Step 003](step-003.md): resolution and immutable locks
- [Step 004](step-004.md): L01/L02 acquisition
- [Step 005](step-005.md): canonical image lifecycle
- [Step 006](step-006.md): L03 GT patches
- [Step 007](step-007.md): L04 dependencies
- [Step 008](step-008.md): L05 setup profiles
- [Step 009](step-009.md): L06 project source and command cutover
- [Step 010](step-010.md): runs, snapshots, and promotion
- [Step 011](step-011.md): L07 DEV distribution
- [Step 012](step-012.md): contexts, concurrency, and retention
