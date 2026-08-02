# Stage 03A — headless sessions

## 1. Goal and non-goals

Run lightweight read-only tools/tests from the canonical artifact; staging and
GUI workspaces are excluded.

## 2. Prerequisites and starting state

Requires Phase 2 lifecycle, capability, and registry protocols.

## 3. Public APIs, commands, and schemas

Add v2 test, test-one, eval, image, and diagnose commands over session manifests
and matching ready/completion schemas.

## 4. Implementation work packages

Create private changes/HOME/XDG/tmp/input/log/result paths, link shared runtime,
install disabled capabilities, and select direct-image or minimal reflink use.

## 5. State transitions, locking, cleanup, and failures

Require matching records, clean complete materializations on every outcome, and
retain only bounded latest diagnostics.

## 6. Tests and acceptance scenarios

Cover concurrency, forced termination, timeout, mismatched records, export/save
denial, no source bridge, cleanup, and diagnostic rotation.

## 7. Exit criteria and handoff evidence

Read-only sessions share runtime/native data and never retain complete images.

## 8. V0.1 mechanisms retained or retired

V0.1 test/eval/image commands remain default until cutover.
