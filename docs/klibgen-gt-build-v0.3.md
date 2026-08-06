# KlibGenGt build v0.3

## Status

This document records the final design direction for the KlibGenGt build coordinator and describes the executable v0.3 prototype added beside the existing v0.2 implementation.

v0.3 is intentionally project-specific. It is not intended to become a general build framework, a hermetic package manager, or a serializable workflow language. Its job is to describe and execute the relatively small number of operations needed to prepare a Glamorous Toolkit image for KlibGenGt, then launch that image under different policies.

The existing v0.2 commands remain the default. The v0.3 package is a migration scaffold that allows individual v0.2 operations to be wrapped and replaced incrementally.

## Conclusions

### Reproducibility is not a current objective

The coordinator should make builds understandable, incremental, isolated, and recoverable. It does not need to prove that an image can be recreated bit-for-bit on another host.

Pinned versions, checksums, and explicit inputs remain useful where they make a build predictable, but the system should not automatically capture every tool version, environment variable, VCS operation, or host fact. Such values participate in a task fingerprint only when the task declares them.

### The build description is executable object composition

There is no separate declarative frontend and no separate `Action`, `Step`, `Recipe`, and `Target` hierarchy. The core model is:

```text
Task
├── concrete project task
├── RunPython
├── RunCommand
├── RunInImage
├── RunInImageTest
└── TaskGroup
    └── CheckpointTaskGroup
```

A root `TaskGroup` is the recipe. A `Task` both describes and performs one operation. A `TaskGroup` returns ordered, named child objects. A `CheckpointTaskGroup` asks the executor to save the complete mutable build workspace after all descendants succeed.

The Python implementation may use arbitrary Python. The eventual Smalltalk rewrite should preserve this object model and execution semantics rather than consume a Python-generated JSON or TOML representation.

### JJ worktrees, build workspaces, and source areas are different things

The word *workspace* has accumulated several meanings. v0.3 uses these terms:

- **JJ worktree**: one independently checked-out source tree attached to the JJ repository. Managed experimental worktrees may be nested under `.worktrees/` so one agent can create and operate them without changing agent instances.
- **Build workspace**: one named incremental build state inside a JJ worktree. It owns the mutable construction tree, checkpoints, task state, published generations, and launch copies.
- **Source area** or **staging area**: one private Git repository loaded and exported through Iceberg. Writable images edit this repository instead of editing the JJ working copy directly.
- **Launch materialization**: the image tree used by one CLI or GUI launch.

One JJ worktree may contain multiple build workspaces and multiple source areas.

### A JJ worktree is not a safe live Smalltalk scratchpad

JJ snapshots the working copy at the start of most commands. Disabling automatic tracking of new paths does not prevent modifications to already tracked files from being snapshotted. Agents are expected to make partial edits and occasionally run the wrong command, so writable images should not use the authoritative JJ source tree as their Iceberg repository.

Managed nested worktrees are configured without first snapshotting them:

```sh
jj --ignore-working-copy workspace add \
    --name dependency-test \
    --revision @ \
    .worktrees/dependency-test

cd .worktrees/dependency-test
jj --ignore-working-copy config set --workspace \
    snapshot.auto-track 'none()'
```

Read-only automation should similarly use `jj --ignore-working-copy` whenever it does not intentionally want to snapshot filesystem state. These measures are defence in depth; the private source area is the primary editing boundary.

Current JJ documentation:

- <https://docs.jj-vcs.dev/latest/working-copy/>
- <https://docs.jj-vcs.dev/latest/cli-reference/>
- <https://docs.jj-vcs.dev/latest/config/>

### Iceberg-backed private Git repositories remain necessary

KlibGenGt must load source that may be present only in the filesystem, represented by a JJ revision rather than a Git commit, generated elsewhere, or edited live in an image. Metacello and Iceberg already provide the reliable Tonel import/export path.

Replacing them would require implementing package discovery, class and trait serialization, extension methods, package metadata, additions, removals, renames, change detection, and export reconciliation. v0.3 therefore retains the private Git staging concept and exposes it through a smaller `StagingAreaManager`.

The prototype initially wraps the v0.2 staging implementation through `LegacyStagingBackend`. Existing private Git/Iceberg areas remain usable while the coordinator is migrated.

### Source integration is reconciliation followed by `rsync`

The private Git repository is the merge boundary. `rsync` is the materialization tool.

The intended flow is:

```text
private Git/Iceberg history
    ↓
reconcile with current authoritative source
    ↓
validate the resulting Tonel tree
    ↓
rsync --archive --delete into worktree/src
    ↓
review ordinary filesystem changes with JJ
```

The v0.3 facade calls the backend's reconciliation operation, rejects paths outside owned KlibGenGt packages, previews the exact `rsync` changes, saves a rollback copy, applies the copy, runs an optional validator, and advances the staging area's imported base. It never invokes JJ during integration.

Conflicts remain ordinary Git conflicts in the private repository. They should be resolved with normal Git tools and then retried; no new conflict-file format or custom merge engine is introduced.

### One conservative lock covers repository-wide build mutations

All managed worktrees of one JJ repository share:

```text
<primary-worktree>/.klibgen/v3/shared/build.lock
```

The lock serializes managed worktree creation/removal, build workspace mutation, task execution, checkpoint replacement, generation publication, source integration, and shared acquisition-cache mutation.

It does not prevent an already-published generation from being launched or used. A default GUI can remain active while an experimental worktree waits for the build lock and constructs a new generation.

This is intentionally conservative. More granular locks should be introduced only after measurements show that parallel builds are valuable.

## Object model

### `Task`

A task has five extension points:

```python
class Task(ABC):
    cache_policy = CachePolicy.NORMAL

    def inputs(self, context) -> Iterable[TaskInput]: ...
    def outputs(self, context) -> Iterable[TaskOutput]: ...
    def parameters(self) -> Mapping[str, object]: ...
    def implementation_key(self, context) -> object: ...

    @abstractmethod
    def run(self, context) -> None: ...
```

Rules:

1. A task object is bound at one location in one execution plan. Reusing the same instance at multiple paths is rejected.
2. `parameters()` returns stable configuration that affects incremental reuse.
3. `inputs()` declare values or paths whose current state affects the task.
4. `outputs()` are checked immediately after successful execution and when deciding whether a prior result remains reusable.
5. Arbitrary Python remains legal through `run()` or `RunPython`.
6. Tasks may mutate only their selected build workspace and explicitly managed shared caches. The executor does not attempt process sandboxing.

The default implementation key hashes the concrete task class source. Raw callables use source or bytecode where available and may supply an explicit key.

### Inputs and outputs

The prototype includes:

- `PathInput(path, workspace_relative=False)`
- `ValueInput(name, value)`
- `PathOutput(path, kind="any" | "file" | "directory")`

Repository inputs are resolved below the JJ worktree. Workspace-relative inputs and all outputs are resolved below the mutable build tree. Escaping paths are rejected.

The first version deliberately omits Gradle-style providers, inferred dependencies, and typed output references. Tasks exchange durable values through named workspace files.

### `TaskSequence`

A group may return a mapping, an iterable of pairs, or a `TaskSequence`. Names are ordered, unique within the group, and may not contain `:`.

`TaskSequence` provides the project-specific composition operations needed for derived recipes:

- `replace`
- `insert_after`
- `through`

Normal subclassing is the recipe extension mechanism. There is no generic recipe-patching language.

### `TaskGroup`

A `TaskGroup` is an ordered composite. The executor calls `steps()` once while binding the graph and executes leaves depth-first in textual order.

There are no implicit edges, DAG scheduling, worker pools, priorities, or parallel task execution.

### `CheckpointTaskGroup`

A checkpoint group saves the complete mutable build workspace after all child leaves succeed. Its hierarchical task path is the checkpoint name.

Checkpoints are named slots rather than content-addressed immutable artifacts:

```text
.klibgen/v3/workspaces/default/checkpoints/
├── klibGenGt__installDeps/
│   ├── checkpoint.json
│   └── payload/
└── klibGenGt/
    ├── checkpoint.json
    └── payload/
```

Replacing a checkpoint replaces its slot. No global artifact garbage collector is needed.

### Escape hatches

`RunPython` directly supports the intended migration form:

```python
RunPython(
    lambda executor, workspace: do_something(workspace.work),
    implementation_key="do-something-v1",
)
```

`RunCommand` wraps a host command whose arguments, working directory, and environment may be static or derived from the execution context.

`RunInImage` runs a checked-in `.st` script using the runtime and image in the mutable build workspace. `RunInImageTest` is the semantic assertion-oriented form.

These classes allow v0.2 helpers and scripts to become tasks before they are rewritten into domain-specific classes.

## Executor semantics

### Binding

Before running anything, `Executor.bind()` converts the object tree into:

- an ordered sequence of leaf tasks;
- checkpoint boundaries expressed as leaf counts;
- hierarchical paths such as:

```text
klibGenGt:readConfig
klibGenGt:obtainRuntime
klibGenGt:installDeps:load
klibGenGt:installDeps:verifySqlite
```

Binding rejects cycles and task-object reuse.

Each leaf retains its enclosing groups. Group implementation, parameters, and ordered child names participate in descendant fingerprints. Changing group configuration or reordering children therefore invalidates the affected suffix.

### Fingerprints and prefix invalidation

A leaf fingerprint contains:

```text
task path
+ enclosing group descriptions
+ concrete task implementation key
+ task parameters
+ declared input fingerprints
```

The executor compares fingerprints in execution order. The first mismatching, `ALWAYS_RUN`, or output-invalid task invalidates that task and every later task.

This linear rule matches the physical reality of an image build: later steps mutate the result of earlier ones. A general DAG cache would add complexity without yielding independently executable branches.

### Checkpoint restoration

The executor selects the deepest checkpoint whose recorded prefix fingerprints still match the current plan. It restores that checkpoint and runs the remaining suffix.

If no checkpoint remains valid, it clears the mutable construction tree and starts from the first task.

### Publication and failure

After all tasks and output checks succeed, the executor copies the mutable tree into a new generation and atomically updates `current.json`:

```text
.klibgen/v3/workspaces/default/
├── work/
├── checkpoints/
├── generations/<id>/
│   ├── generation.json
│   └── payload/
├── state.json
└── current.json
```

Launches resolve the current generation once and continue to use that immutable path. A subsequent build does not modify an already-running GUI's source image.

If a task fails, the previous generation remains current. Failure metadata is retained in workspace state, and a later execution restores the previous generation or a newer valid checkpoint before retrying.

## Worktrees and workspaces

### Managed nested worktrees

`WorktreeManager` creates managed JJ worktrees beneath:

```text
<primary-worktree>/.worktrees/<name>/
```

`.worktrees/` is ignored by Git/JJ. The manager refuses to remove the primary worktree and performs create/remove operations under the shared build lock.

A nested worktree is appropriate for changes to:

- Python tasks or executor code;
- build scripts;
- dependency declarations;
- native dependency implementations;
- GT or VM patches;
- project source that must evolve independently from the primary tree.

### Named build workspaces

`WorkspaceManager` creates multiple build states inside one worktree:

```text
<worktree>/.klibgen/v3/workspaces/default/
<worktree>/.klibgen/v3/workspaces/instrumented/
<worktree>/.klibgen/v3/workspaces/dependency-test/
```

A second workspace is appropriate when the source tree is shared but build configuration, checkpoints, or launch use must remain separate.

A workspace may be explicitly seeded from another workspace. Seeding copies the published generation and available checkpoints; the destination owns the copies afterwards. This is not a global content-addressed cache.

## Launch profiles

The prototype defines three policies:

| Profile | Image materialization | Source writes | Lifetime |
| --- | --- | --- | --- |
| `cli` | shared published generation | disabled | process |
| `agentic` | ephemeral writable copy | private source area | process |
| `gui` | persistent writable copy | private source area | named launch |

The launch layer currently materializes image trees and records the policy. Process-specific GT session bootstrap can be migrated from v0.2 behind these profiles separately.

## Source areas and Iceberg

`StagingAreaManager` presents a private Git/Iceberg source area through a v0.3 API:

```python
areas = StagingAreaManager(worktree)
area = areas.ensure("agent")

with areas.lease(
    "agent",
    kind="agentic",
    owner="agent-1",
    pid=os.getpid(),
) as attached:
    launch_with_source_git(attached.source_git)

preview = areas.integrate("agent", dry_run=True)
result = areas.integrate("agent", validate=verify_tonel)
```

The private Git repository remains the source supplied to Iceberg. Exported image changes are committed there before host integration.

The initial backend delegates create/list/reconcile/change/lease operations to v0.2. This is intentional: v0.3 can replace the storage and Git-history implementation later without changing the task, worktree, workspace, or launch model.

## Example recipe

`python/klibgen_build/v3/examples.py` contains a mixed old/new recipe:

```python
class KlibGenGt(CheckpointTaskGroup):
    def steps(self):
        return OrderedDict(
            [
                ("readConfig", ReadConfig()),
                ("obtainRuntime", FetchPinnedGT()),
                ("fetchDependencies", FetchPinnedDependencies()),
                ("extractInitialImage", ExtractInitialImage()),
                ("patchGT", RunInImage(
                    script="scripts/patch-gt-headless-webview.st"
                )),
                ("installDeps", InstallDependencies()),
                ("prepareSourceArea", PrepareStagingArea("default")),
                ("sampleStep", RunPython(
                    lambda executor, workspace:
                        do_something(workspace.work),
                    implementation_key="sample-step-v1",
                )),
                ("remainingV02Scripts", TaskGroup(...)),
            ]
        )
```

The implemented examples demonstrate:

- reading the existing source-lock JSON into workspace metadata;
- reusing the current GT bootstrap script;
- acquiring locked Git dependency checkouts in a shared cache;
- wrapping v0.2 image extraction;
- running existing Smalltalk dependency, project-load, provenance, and contract scripts;
- preparing an Iceberg-compatible source area;
- arbitrary Python as a first-class task;
- checkpointing composite groups.

The example is deliberately not wired into the default `just build` yet. It is a migration scaffold: individual v0.2 branches can be replaced with concrete tasks and validated before the old coordinator is removed.

## Deliberate omissions

The v0.3 core does not provide:

- JSON, YAML, or TOML recipes;
- a serializable intermediate graph;
- separate action and task registries;
- arbitrary DAG scheduling;
- parallel task execution;
- remote or cross-worktree artifact caches;
- Gradle providers or lazy typed properties;
- inferred dependencies;
- decorators, metaclasses, or annotation-driven task declaration;
- task-level process sandboxing;
- automatic JJ commits, rebases, descriptions, or bookmarks;
- safe concurrent writers to one source area or one build workspace.

These omissions are part of the design. The core should grow only in response to a demonstrated KlibGenGt workflow that cannot be expressed clearly with the existing objects and escape hatches.

## Migration plan

1. Keep v0.2 operational and add the v0.3 package beside it.
2. Wrap existing Python helpers and `.st` scripts in raw tasks.
3. Run the focused host-side v0.3 tests without starting GT.
4. Add a v0.3 CLI/`just` entry point after the example root can build a complete image on the development host.
5. Replace raw tasks with domain tasks one operation at a time.
6. Move GUI, agentic, and read-only launches behind `LaunchProfile` materialization.
7. Continue using the legacy staging backend until the native Git source-area implementation has been validated in daily use.
8. Remove v0.2 artifact-store, reference, inventory-retention, custom promotion, and single-GUI-workspace machinery after workflow parity.
9. Translate the stable object model and task implementations to Smalltalk.
