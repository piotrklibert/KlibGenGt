# Stage 02A — session kernel

## 1. Goal and non-goals

Install explicit image-side session provenance, capabilities, and authoritative
lifecycle records; tool migration is deferred.

## 2. Prerequisites and starting state

Requires canonical images with `KGBuildProvenance` from Stage 01C.

## 3. Public APIs, commands, and schemas

Define `klibgen.session/1`, ready/completion records, `KGSession`, bootstrap,
operation-result, source/persistence capability, and entrypoint protocols.

## 4. Implementation work packages

Load immutable session state early, validate project key/paths, install disabled
capabilities, write ready atomically, dispatch, and write completion atomically.

## 5. State transitions, locking, cleanup, and failures

Smalltalk owns succeeded/failed/saved/discarded/cancelled. Missing, duplicate, or
mismatched completion is a host-visible protocol failure.

## 6. Tests and acceptance scenarios

Fresh-image SUnit plus fake-host tests cover validation, key mismatch, atomic
records, orderly outcomes, crashes, and timeouts.

## 7. Exit criteria and handoff evidence

Every orderly process result is evidenced by matching image-authored completion.

## 8. V0.1 mechanisms retained or retired

Current tool dispatch remains temporarily; new sessions do not depend on v0.1
run identity.
