# Stage 01B — store and generic builder

## 1. Goal and non-goals

Publish synthetic checkpoint artifacts safely; real default GT construction is
not required yet.

## 2. Prerequisites and starting state

Requires resolved Stage 01A step/output keys and Stage 00 owned paths.

## 3. Public APIs, commands, and schemas

Add artifact list/verify, build, and status beneath `klibgen-build v2`, plus
named artifact, status, ref, lock, and manifest schemas.

## 4. Implementation work packages

Implement typed global store paths, per-key locks, atomic publication,
verification, mutable latest status, build workspaces, and fake steps.

## 5. State transitions, locking, cleanup, and failures

Builders wait and reuse a winner. Publication renames a complete verified tree.
Failure retains bounded logs/status and removes partial image payloads.

## 6. Tests and acceptance scenarios

Cover concurrent same-key builds, crash points, corrupt manifests, stale locks,
read-only publication, prior-artifact preservation, and wait/reuse.

## 7. Exit criteria and handoff evidence

Synthetic recipes build and reuse checkpoints exhaustively without GT.

## 8. V0.1 mechanisms retained or retired

V0.1 artifacts/build commands remain default; no shared adapter is introduced.
