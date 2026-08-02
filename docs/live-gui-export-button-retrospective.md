# Live GUI Export Button Retrospective and Follow-up Ideas

This note records the implementation context, difficulties, and potential
follow-up work for the project-owned `Export (NN)` Glamorous Toolkit toolbar
button. It is intended as a handoff for returning to this area later, rather
than as a claim that all of the improvements below should be implemented at
once.

## JJ revisions

The button implementation lives in the previous JJ revision:

- Change ID: `vtouquxrornrxlwszplvzwkunurlvkvp`
- Commit ID: `bfdbfc8041e13d7ee49dc388ec0a60748fb8fc32`
- Description: `Add live GUI Export button for KlibGenGt changes.`

The structured live GUI inspection and control interface used to test the
button is its parent revision:

- Change ID: `rkwwzurozkmmqssttynkxsuryplmmkly`
- Commit ID: `dd18bd502019af72bbc8fc61e560d4432275a0dd`
- Description: `Add Scripter-based live GUI inspection and control.`

This retrospective is being written in the current documentation revision:

- Change ID: `ypwnoquvmqywvtpknkpsquzusxwzzrou`
- Starting empty commit ID: `86a06c228cbf18073891762bb0c6febd5899d5d6`

The current working-copy commit ID is content-addressed and therefore changes
when this file is added or edited. Use the stable change ID to find the
documentation revision. The starting commit ID above identifies the empty
revision that existed immediately before this note was added; it is not
expected to remain the commit ID of the completed documentation revision.

Useful commands when resuming are:

```sh
jj show vtouquxr
jj diff -r vtouquxr-
jj log -r 'ypwnoquv | vtouquxr | rkwwzuro'
```

## What was implemented

The implementation is project-owned and is installed for both fresh and
resumed managed GUI images. Its important source locations are:

- `src/KlibGenGt-Tools/KGExportTool.class.st`: resolves the exact private
  export repository from `KLIBGEN_EXPORT_GIT`, counts modified
  `KlibGenGt-*` Iceberg packages, and commits the complete working-copy diff
  with a synthetic title.
- `src/KlibGenGt-Tools/KGExportButton.class.st`: implements the Bloc button,
  its `Export (NN)` label, enablement, system-announcement subscriptions,
  asynchronous export worker, and teardown.
- `src/KlibGenGt-Tools/GtWorldElement.extension.st`: contributes the button to
  the world toolbar through a project-owned `gtWorldAction` extension.
- `src/KlibGenGt-Tools/KGGuiSessionHooks.class.st`: installs the button during
  fresh and resumed startup and removes it during shutdown.
- `src/KlibGenGt-Tests/KGToolsTest.class.st`: contains the Scripter click test
  and idempotent world-installation test.
- `README.md` and the `KlibGenGt` class comment: document and index the public
  feature.

`KGExportTool>>#changeCount` counts modified Iceberg packages whose names start
with `KlibGenGt`. `KGExportTool>>#exportChanges` commits the repository's full
working-copy diff, using a title of the form:

```text
Export KlibGenGt changes (NN)
```

The tool configures a repository-local synthetic Git identity (`KlibGenGt
Export <export@localhost>`) before committing. It then announces
`IceRepositoryModified` and `IceCommited`; the existing managed-GUI host bridge
observes the latter and promotes the changed packages into `src/`.

The button has the Bloc ID `kgExportButton`, is disabled at a count of zero,
and exports on an owned background process so that Iceberg work does not block
the UI thread. It subscribes to concrete method, class, and package system
announcements and defers UI refreshes to the UI process. Removal from the scene
graph unsubscribes it and terminates an in-flight worker.

## Validation completed with the feature

The implementation revision was validated with:

- `just check-type-pragmas`: 727 documentation type annotations checked.
- `just test`: 55 tests, zero failures and zero errors.
- `just test-fresh`: 55 tests, zero failures and zero errors from a disposable
  fresh image after all source changes.

A live disposable GUI acceptance run also exercised the complete path:

1. A temporary `KlibGenGt-Tests` method made the button become enabled and
   display `Export (1)`.
2. The structured `klibgen-build ui` interface located the button by scene
   graph node rather than screen coordinates.
3. A Scripter-backed `ui act click` clicked that exact node.
4. The private export repository received a commit titled exactly
   `Export KlibGenGt changes (1)`.
5. The GUI emitted the `iceberg-committed` lifecycle event.
6. The host bridge promoted the package into the outer `src/` tree.
7. The button returned to the disabled `Export (0)` state.

The temporary acceptance method and Tonel ordering churn created by the test
commit were subsequently removed. A final clean fresh GUI automatically found
one attached, effectively visible, in-viewport `KGExportButton` on the actual
visible world, with the expected 88 by 24 bounds and disabled `Export (0)`
state. The disposable GUI was then shut down cleanly.

## Problems encountered

### The visible world was not reliably the default world

The most significant problem was that `GtWorld defaultWorld` temporarily
referred to a serialized stale world while a different `GtWorld` was actually
open and visible. The toolbar extension could install successfully on the
wrong world, so image-side checks looked plausible even though no button was
visible to the user.

The implemented workaround captures the startup world and schedules a
one-shot process. After one second it marks that captured world as the default,
enqueues button installation on its Bloc task queue, and requests a pulse.
This works, but the delay is a timing heuristic rather than a lifecycle
guarantee.

### There was no precise "visible world toolbar is ready" hook

Installation crossed image startup, world creation or resumption, toolbar
construction, Bloc attachment, task-queue execution, layout, and pulse
processing. No single hook represented the point at which the final visible
world and toolbar were ready for project extensions. This led to the delayed
process, explicit layout requests, and explicit pulse request in
`KGExportButton class>>#installOn:` and
`KGGuiSessionHooks class>>#scheduleExportButtonInstallationOn:`.

### Host process visibility differed inside the sandbox

Some early GUI diagnostics falsely reported that the managed image was
inactive. Sandboxed commands could not see the PID of a host-launched GT
process, while escalated host-side commands could. The coordinator therefore
received an observation limitation that looked like process death.

This was a test-environment and diagnostic problem, not a failure of the GT
image. Host-window and process checks needed to run with the permissions
described by the `operate-gt-host` workflow.

### The live integration test created broad Tonel churn

The full export path had to observe a real package modification and commit it
through Iceberg. Adding a disposable test method achieved that, but committing
the package rewrote method ordering across much of its Tonel source. The
resulting promotion contained unrelated-looking churn that had to be restored
carefully from the private bridge's pre-acceptance revision.

The final source was restored correctly, but using a production test package
as an integration fixture made the test unnecessarily risky and noisy.

### Git identity was an implicit prerequisite

Iceberg's commit path requires Git author identity. A disposable managed
repository cannot safely assume that a contributor has global Git identity
configured. The implementation therefore runs repository-local `git config`
for a synthetic name and email immediately before exporting.

This made the feature self-contained, but repository initialization would be a
cleaner owner for that invariant.

### Headless Bloc rendering exposed font measurement instability

The Scripter widget test intermittently encountered font-measurement behavior
when using the production label aptitude in a headless test image. The test
uses an icon aptitude to avoid depending on that rendering path while still
testing Scripter click behavior, label state, enablement, and model invocation.

This is a practical test workaround, but it means the headless test does not
exercise precisely the same aptitude as the live widget.

### Asynchronous state was inferred indirectly

The widget has several real states: idle with a count, exporting, success,
failure, and disposed. The current implementation mostly exposes these through
the label, enablement, presence of the worker process, and stderr on failure.
That is enough for the initial feature, but it makes precise diagnostics and
tests harder than an explicit state model would.

### Installation ownership spans several mechanisms

The feature is assembled through a world-action pragma, a toolbar rebuild,
startup hooks, a delayed process, system-announcement subscriptions, an export
worker, and shutdown cleanup. Each piece is reasonable in isolation, but there
is no central registry that says which project extension owns which resources
and how they must be disposed.

## Proposed improvements

### 1. Introduce an explicit managed GUI session and world

The highest-value improvement is to stop rediscovering the active world through
global state. A managed session object should record the exact world created or
resumed for the run and expose it to startup extensions and the UI-control
service, for example through `KGGuiSession current world`.

The startup path should establish the managed world synchronously and retain
its identity. `ui spaces` could then report whether each space is managed,
default, visible, or host-window-backed. This would eliminate the possibility
of a correctly installed extension living on a stale serialized world.

### 2. Add ordered GUI lifecycle phases

Provide explicit, idempotent phases such as:

```text
image loaded
session selected
world created or resumed
world attached
world toolbar constructed
project extensions installed
UI ready
shutdown beginning
```

Hooks should receive the managed session or world and be able to register a
teardown action. The export button could install at `world toolbar constructed`
without a one-second wait and automatically uninstall during shutdown.

### 3. Improve UI-control observability

Extend the structured UI interface so startup and wrong-world problems can be
diagnosed without live evaluation:

- Identify the managed and host-window-backed spaces in `ui spaces`.
- Report the managed world, default world, lifecycle phase, startup-hook state,
  and installed project extensions in `ui status`.
- Include application-level ownership, such as the corresponding `GtWorld`, in
  tree or node inspection.
- Add concise assertions for exactly one match, visible and enabled state,
  expected label, and managed-world ownership.
- Retain a bounded event log for attachment, visibility, enablement, focus,
  label changes, and startup-hook failures.
- Write startup and UI-service diagnostics into the managed run directory.

### 4. Distinguish dead, inaccessible, unready, and unresponsive images

The Python coordinator should not convert inability to inspect a PID into a
claim that the image is dead. Its run diagnosis should distinguish:

- PID definitely absent;
- PID present but inaccessible from the current namespace or permissions;
- image alive but the UI service not ready;
- readiness record present but requests timing out;
- image and service responsive.

Readiness-file heartbeats and an actual request/response probe are more useful
than PID visibility alone. Structured errors should explain the evidence used
to classify a run.

### 5. Extract an export service interface

Move repository policy behind a small project-owned service interface with
operations such as:

```text
eligibleModifiedPackages
changeCount
commitTitle
workingCopyDiff
export
```

The widget should only display service state and request an export. Useful
implementations would include the real Iceberg bridge, a recording or in-memory
backend for widget tests, and a disposable-repository backend for integration
tests.

This also makes explicit the currently subtle policy that the displayed count
is the number of modified `KlibGenGt-*` packages while the export commits the
complete managed repository diff.

### 6. Add a dedicated disposable export fixture

The one acceptance test that must traverse real Iceberg and promotion should
use a tiny fixture package and repository, not `KlibGenGt-Tests`. The harness
should:

- snapshot repository HEAD and dirty state before the test;
- make a deterministic change in the fixture package;
- export and verify the exact commit title and promoted path;
- fail if paths outside the fixture change;
- restore the fixture state with a project-owned, narrowly scoped operation;
- report the before and after revisions in structured diagnostics.

Deterministic Tonel serialization or comparison that ignores ordering-only
changes would further reduce integration-test noise.

### 7. Configure synthetic identity when the export repository is created

Managed export-repository setup should install and validate the local synthetic
Git identity once. The export action can then assume a documented repository
invariant. Repository health diagnostics should categorize identity, conflict,
detached repository, empty diff, and inaccessible repository failures rather
than returning only a general exception.

### 8. Add a deterministic headless Bloc test environment

Provide a standard test theme and known fonts for headless Bloc tests, plus a
helper that opens an element in a test space and waits until it is pulse-ready.
The export button test could then use the production label aptitude without
intermittent font measurement failures. A small rendering suite could run in
both headless and real-theme configurations.

### 9. Model widget state explicitly

Introduce a view model or state object representing at least:

```text
idle(count)
exporting(count)
succeeded
failed(error)
disposed
```

This would prevent duplicate exports, allow useful failure feedback in the
GUI, make teardown guarantees testable, and let `ui get` expose machine-readable
state rather than requiring clients to infer it from label and enablement.

### 10. Centralize project extension ownership

A project UI-extension registry could track an idempotence key, target world,
installed element, subscriptions, worker processes, and teardown block. This
would make installation and removal auditable and reusable for future
project-owned toolbar tools.

### 11. Add one end-to-end acceptance command

A command such as `just test-gui-export` should perform the safe disposable
workflow and emit a structured report containing:

- run ID and managed-world identity;
- pre-click count, label, and enablement;
- uniquely selected node handle;
- Scripter action result;
- resulting commit hash and title;
- emitted lifecycle event and promoted paths;
- final button state;
- shutdown result;
- any unexpected outer-working-copy changes.

The command should use the structured UI interface for image interaction and
the host workflow only for window lifecycle and optional screenshot evidence.

## Suggested priority

The first three follow-ups should be:

1. Introduce an explicit managed-session/world object.
2. Add a real `toolbar ready` or `project UI ready` lifecycle phase.
3. Build a dedicated disposable export fixture and end-to-end command.

Together these address the largest sources of timing uncertainty, weak
observability, and risky integration-test cleanup. The export service interface
and explicit widget state are natural next steps if the button acquires more
behavior or more project-owned GUI actions are added.

## Pickup checklist

When returning to this work:

1. Read this note and inspect `jj show vtouquxr`.
2. Re-read `KGGuiSessionHooks`, `KGExportButton`, `KGExportTool`, and the live UI
   service before changing startup behavior.
3. Use the repository-local `operate-gt-ui` workflow for coordinate-free GUI
   interaction and `operate-gt-host` only for window and process lifecycle
   evidence.
4. Test changes in a disposable package or repository; do not add an acceptance
   probe to a production package unless its promotion effects are explicitly
   controlled.
5. Check the outer JJ diff immediately after any live Iceberg export because
   promotion happens automatically.
6. Preserve all public type pragmas and class documentation, update the
   `KlibGenGt` class index if classes change, and run
   `just check-type-pragmas`.
7. Finish with `just test` and a final `just test-fresh` from a clean runtime.
8. Append the completed follow-up task to the active JJ change description;
   do not create a new change unless explicitly requested.
