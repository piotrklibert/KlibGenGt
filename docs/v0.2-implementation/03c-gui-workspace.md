# Stage 03C — GUI workspace

## 1. Goal and non-goals

Provide one exclusive mutable `gui-default` image with fresh/resume and explicit
save/discard/cancel; no snapshot history.

## 2. Prerequisites and starting state

Requires Stage 03B promotion and Stage 02C interactive/workspace capabilities.

## 3. Public APIs, commands, and schemas

Add v2 gui, gui --fresh, workspace status, and confirmed reset commands plus the
workspace manifest/completion schemas.

## 4. Implementation work packages

Initialize from canonical artifact, resume the saved image, compare provenance,
show stale warnings, and connect interactive staging/promotion.

## 5. State transitions, locking, cleanup, and failures

An exclusive workspace lock guards start/save/reset. Abnormal termination keeps
bounded diagnostics, not failed runs or snapshots. Cancel leaves state unchanged.

## 6. Tests and acceptance scenarios

Cover exclusivity, fresh/resume, stale warnings, save/discard/cancel, crash,
forced termination, reset confirmation, and promotion conflicts.

## 7. Exit criteria and handoff evidence

Exactly one ordinary mutable image exists and resume requires no rebuild/save
preparation.

## 8. V0.1 mechanisms retained or retired

V0.1 snapshots remain usable until Phase 5 but are not written by v0.2.
