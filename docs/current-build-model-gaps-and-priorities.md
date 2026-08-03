# Important gaps and friction

## 1. Resolved: JJ identity caused content-equivalent rebuilds

**Status:** Resolved by using the effective selected-tree digest as artifact
key material while retaining JJ commit/change IDs as provenance. The remainder
of this section records the original problem and rationale.

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

## 2. Resolved: GUI export lacked an end-to-end promotion workflow

**Status:** Resolved by attaching the GUI to `gui-default` (or `gui --staging
NAME`), keeping Export and Promote as separate actions, and servicing promotion
through the same lease-validated host staging service used by agentic work.

The former workspace-private Git bridge is migrated automatically and retained
until an explicit workspace reset.

## 3. Resolved: staging base and canonical image could diverge

**Status:** Resolved by automatic file-level three-way rebase before attachment
and promotion. Conflict-free current source is incorporated into the overlay;
overlapping changes preserve the original staging trees, mark the area
conflicted, and refuse execution.

The remainder of this section records the former failure mode.

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
- clean saved GUI images reconcile changed staging generations automatically;
  dirty images intentionally refuse handoff
- no multiple-writer GUI or staging support
- no completed release/distribution pipeline

# Recommended order of work

I would tackle the next work in this order:

1. **Improve stale-state reporting.**  
   Source identity now uses effective tree content for artifact reuse and retains JJ IDs as provenance. Make `status` explicitly compare resolved, referenced, workspace, and staging identities.

2. **Extend source workflow ergonomics.**
   The named-staging integrity path is complete; add richer conflict inspection
   and guided resolution if daily use shows it is needed.

3. **Expose derived recipes as a supported user feature.**  
   Add a small committed or local recipe-definition format plus CLI support for replacements, local worktrees, truncation, target/preset selection, and non-default refs.

4. **Strengthen verification and diagnostics.**  
   Content-hash artifacts or critical payload families, verify runtime symlink targets, add `diagnose`, rotate build diagnostics, and provide source-oriented test errors.

5. **Finish generic tool hosting.**  
   Add tool discovery/run commands, compatible-GUI negotiation, and warm `tool.open`.

6. **Optimize physical storage and concurrency.**  
   Share native/source payloads explicitly, measure reflink fallback behavior, and add bounded parallel session execution if actual workloads justify it.

If the immediate priority is daily developer experience, items 1 and 2 offer the
largest return. If the immediate goal is experimenting with patched
GT/Pharo/dependency stacks, item 3 should move to the front—but I would still
fix the JJ identity issue first because it affects every subsequent measurement
and cache result.
