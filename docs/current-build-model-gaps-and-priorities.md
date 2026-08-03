# Important gaps and friction

## 1. JJ identity causes content-equivalent rebuilds

This is the clearest daily-workflow problem.

The current build and the previously referenced build have exactly the same selected `src/` tree digest:

```text
7b1fffa2d752500854c13309525364c2c70a1d00847ca6e2c0b22fd46e882d55
```

They nevertheless receive different keys because the current empty JJ change has different `changeId` and `commitId`.

Consequences:

- `jj new`, description changes, or equivalent revision-boundary operations can invalidate the project artifact without changing source.
- A new approximately 500 MiB final artifact may be published.
- The GUI reports stale provenance even when effective project source is identical.
- Normal image queries can unexpectedly trigger a rebuild.

The design currently treats JJ identity as both provenance and content-key material. I would separate them:

- Use effective selected-tree content as artifact key material.
- Preserve JJ change/commit IDs in the manifest as provenance.
- Optionally retain a strict mode when exact revision identity genuinely matters.

## 2. GUI export is not an end-to-end promotion workflow

The GUI export button commits changes into the workspace’s private Git repository and emits an `iceberg-committed` journal event.

The host launcher does not consume that event to create/promote a staging plan, and there is no `workspace promote` command. The existing `staging promote` service only accepts named areas under `.klibgen/v2/staging/`.

Therefore the README statement that interactive exports pass through the conflict-checked staging/promotion path is stronger than the implementation.

Today, a GUI export is durable inside the workspace bridge, but getting it into `src/` requires manual Git/source work.

## 3. Staging base and canonical image can diverge

An agentic session always builds the current canonical CLI artifact, but then loads the staging area’s entire Git repository over it.

There is no check that:

```text
staging.projectKey == session.projectKey
```

If authoritative source changed after staging creation:

- the agentic image starts from the new canonical artifact;
- the old full staging tree is loaded with incoming conflicts preferred;
- unrelated newer canonical definitions may be replaced in memory by old staging-base versions;
- tests can therefore run against a hybrid or unexpectedly stale source set.

Promotion later performs host-side conflict checks, but execution itself should either reject a stale staging base, rebase it, or load only the actual overlay delta.

## 4. Alternative stack recipes are internal APIs, not real workflows

`Recipe.replace`, `append`, and `through` exist, but the CLI only accepts four hard-coded targets from `DEFAULT_TARGETS`.

There is no supported way to say:

- use this local GT worktree
- replace `gt-patches`
- replace SQLite with another worktree
- define a temporary VM/runtime
- save a local recipe definition
- launch GUI or tests from that derived recipe
- build an alternative without advancing the default references

The bootstrap source-build commands populate `vendor/gt-build`, but they do not expose the composable v0.2 replacement-recipe workflow described by the architecture.

This is the largest gap if alternative-stack work is the immediate objective.

## 5. Artifact verification is weaker than “content verified”

`ArtifactStore.verify()` checks:

- manifest schema
- expected path
- the list of payload filenames and their sizes

It does not hash payload file contents. Same-size corruption would pass.

The runtime artifact is especially weak: its payload contains a symlink to mutable `vendor/gt`, while verification does not follow or hash that target. The runtime key is based on locks and bootstrap inputs, but reuse does not establish that the symlink target still matches those locks.

## 6. Diagnostics and status are difficult to use

The architecture calls for current, bounded, diagnosable failures. Current behavior is mixed:

- Session failures retain one `latest` directory per operation, which is good.
- Build failures use UUID directories and can accumulate multiple diagnostic records.
- There is no `diagnose` command.
- `status` returns every status file, not a focused current-target view.
- It does not clearly report current resolved key versus referenced key versus workspace key.
- The current state has 55 status files and 56 persistent lock files.
- GC does not rotate/remove build logs, statuses, or lock files.
- There is no Tonel source-line mapping for test failures.
- There is no debugger-facing CLI.

This is more an observability-product problem than a build correctness problem.

## 7. Inventory is only partly the promised global model

Inventory is useful, but incomplete:

- Active sessions, statuses, locks, and pins are not graph nodes.
- There is no explicit runtime-bundle collection separate from artifacts.
- Acquisition caches and `vendor/gt-build` are not included in storage totals.
- Pins are recognized by GC but have no create/list/remove CLI.
- Human `build-map` output mostly lists artifacts rather than explaining current/stale relationships.
- The Smalltalk side has typed wire records and `KGBuildMap`, but not full programmatic Recipe/Step/Artifact/Reference service objects.

## 8. Generic registered-tool execution is incomplete

The image registry is generic, but the host side still has command-specific Python entrypoints.

Missing pieces include:

- `tool list`
- `tool describe`
- generic `tool run IDENTIFIER`
- input-schema negotiation
- warm `tool.open` in a compatible active GUI
- cold GUI fallback for arbitrary GUI tools

Build-map PNG is the usable cold special case. Warm zero-VM reuse remains explicitly deferred.

## 9. Performance still depends heavily on reflinks

Every disposable session copies/reflinks the entire image directory. Every checkpoint materializes the previous payload similarly.

This is efficient on a copy-on-write filesystem, but expensive otherwise. Large `.sources` and native payloads appear repeatedly in artifacts and the workspace. There is no explicit shared-native/source presentation layer.

Manual parallel sessions are possible, but there is no bounded worker pool, parallel eval command, or scheduling/resource policy.

## 10. Some limits are intentional

These are not accidental omissions in v0.2:

- one GUI workspace
- no resumable agentic image
- no hostile-code sandbox
- no remote/distributed artifact store
- no hermetic OS/container build guarantee
- no long-term binary artifact archive
- no automatic reconciliation of a saved GUI with changed source
- no multiple-writer GUI or staging support
- no completed release/distribution pipeline

# Recommended order of work

I would tackle the next work in this order:

1. **Fix source identity and stale-state reporting.**  
   Make effective tree content determine project artifact reuse, retain JJ IDs as provenance, and make `status` explicitly compare resolved, referenced, workspace, and staging identities.

2. **Complete source workflow integrity.**  
   Add GUI export → named staging/import → conflict-checked promotion, and reject or explicitly rebase stale agentic staging before execution.

3. **Expose derived recipes as a supported user feature.**  
   Add a small committed or local recipe-definition format plus CLI support for replacements, local worktrees, truncation, target/preset selection, and non-default refs.

4. **Strengthen verification and diagnostics.**  
   Content-hash artifacts or critical payload families, verify runtime symlink targets, add `diagnose`, rotate build diagnostics, and provide source-oriented test errors.

5. **Finish generic tool hosting.**  
   Add tool discovery/run commands, compatible-GUI negotiation, and warm `tool.open`.

6. **Optimize physical storage and concurrency.**  
   Share native/source payloads explicitly, measure reflink fallback behavior, and add bounded parallel session execution if actual workloads justify it.

If the immediate priority is daily developer experience, items 1 and 2 offer the largest return. If the immediate goal is experimenting with patched GT/Pharo/dependency stacks, item 3 should move to the front—but I would still fix the JJ identity issue first because it affects every subsequent measurement and cache result.
