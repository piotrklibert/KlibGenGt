## KlibGen-gt layers - from runtime to project distribution

> **Historical document.** The normative implementation specification is
> `docs/klibgen-gt-reproducible-build-architecture-v0.1.md`. The staged migration
> is tracked under `docs/todo/`. Do not implement this older roadmap where it
> conflicts with those documents.

**TLDR**: KlibGen-GT is a reproducible project model for Smalltalk, layered on
top of GToolkit and Pharo, compensating in automation and tooling for the lack
of module and package systems, allowing for reproducible builds and seamless
setup for contributors while preserving benefits of interactive, moldable
development.


This project is written in Smalltalk, which means it has an additional dimension
that projects in many other languages do not have, namely: the ability to build
and distribute images. However, Smalltalk images are mutable, opaque artifacts
that cannot be easily processed with other tools. The goal of the architecture
described here is to have deterministic, fully-reproducible build process that
still uses Smalltalk's unique features; we want the project to be compatible
with CLI tools and agent-friendly, but we also want to leverage the development
and debugging tools provided by Smalltalk and (especially) GToolkit.

To achieve that, we will define a set of layers that form a stack: from Pharo VM,
to GT image, to GT fixes, to external dependencies, to dependencies fixes, to
project setup, to project development and testing, to final project deliverable.

We will set the system up in a way that will allow us to:

1. Easily replace layers with variants depending on needs. Strong isolation and
   deterministic builds are required.

2. Work at a top-most layer, but promiting the code to the appropriate layer's
   source. We need to know where each class and method comes from, so that we're
   able to automatically find the correct source set to export a fix/change to.
   
3. Automate rebuilding of all stale images, so that after fixing something in
   previous point we get it included immediately in all the layers above the one
   where the fix landed.

### Layers

#### Layers list

L01 - runtime
: VM + launcher
: variants: downloaded GT distribution, source-built GT tooling

L02 - gt-base
: clean GT image at a pinned version
: variants: numbered release, commit-based from GT repo

L03 - gt-patched
: GT image with your local GT patches applied
: variants: one per branch in a forked repo, see next section

L04 - project-deps
: project dependency image: external baselines, utility packages, shared dev
  tools
: variants: conceptually a single variant (see next section), but each
  dependency can be configured to either consume external repo or a local/forked
  clone of it

L05 - project-setup
: project profile image: startup config, Lepiter DB config, feature flags, agent
  helpers, paths
: variants: CLI, GUI, AGENTIC

L06 - project-dev
: project imported into an image from a worktree on disk
: variants: CLI, GUI, AGENTIC

L06-tmp - ephemeral project-dev save point
: the result of saving an image when closing GToolkit window
: holds state in the middle of a development task: open tabs, Lepiter pages,
  instantiated objects in Playground, uncommitted changes in Smalltalk code
: variants: always GUI

L07 - project-dist
: frozen distributable image with project code loaded, with startup hooks
  configured, and with launcher script for easily running the project
: variants: DEV, RELEASE

NOTE: files and directories related to a given layer should be prefixed with
that layer number and name, as in `l05-project-profile-cli-setup.st`.

NOTE: "uncommitted changes" - normally, we'd check before closing the image and
offer to commit all changes to disk, but sometimes it's not worth committing
broken state, so this should be overrideable.

#### Layer definition

Each layer has the following conceptual elements:

1. Parent: a layer that is below the current one in the stack.
   - NOTE: the first layer is the root and has no parent.
2. Inputs: a set of transformations to be applied on top of the parent layer,
   including fetching code, building tools, generating configs, etc.
3. Outputs: a set of artifacts along with metadata that can be consumed by
   descendant layers.
4. Variants: multiple possible ways of generating the layer OR multiple
   representations of a layer.
5. Tests: assertions on what functionality is available in a given layer, and
   sometimes how variants differ (if tracking the difference makes sense, eg.
   when it's a bugfix compared to baseline variant in L03).

Layers can be defined with a mixture of shell and Smalltalk scripts, static
resources, and configuration files. The `just`-based build system will connect
the variants to layers and layers to layers. 

NOTE: all the support scripts called from `justfile` should be placed in
`build/`; all the layer configuration to `build/layers/`.

NOTE: Both inputs (configuration) and outputs (manifests) of layers can have
metadata. Inputs are configured in JSON; layer manifests (paths, exact pinned
versions/commits, checksums, timestamps, etc.) are generated and output as both
JSON and Smalltalk classes; the latter are loaded into the image.

#### Variant details

There are two types of variants that layers can have: they're either
interchangeable, or introduce an (exlusive) alternative.

Layers L01 and L02 have interchangeable variants. No matter which variant is
used, all the later layers should behave identically. This means that we can
select the default variant in a configuration file or environment variable, and
only use the other variants when needed, for testing or debugging.

Layer L03 will consist of a fork of the main GT repository. Each local branch in
this forked repo will be a variant, and they will all (in principle) be
interchangeble. We will initially have two branches (and therefore variants):
`baseline` and `klibgen`. We will sync `baseline` with original repo HEAD of its
main branch, and we will keep our fixes and changes on the `klibgen` branch.
It's important to make creating new variants (along with all the further layers
based on them) easy, and they should also be isolated from each other: creating
a new variant should automatically build its following layers, and they should
all be built and stored separately from builds for other L03 variants.

Layer L04 and L05 will conceptually have variants based on branches of the
project's repo, but in practice we'll just make it have no variants. That way,
when checking out a branch, if there are changes on it compared to the previous
build, we rebuild everything from L04 onwards, and automatically use the new
images in all further actions. We don't need to isolate these variants: we
assume only one variant of this kind will ever be active at one time.

Layers L05 and L06 will have 3 variants: CLI, GUI, AGENTIC. All these variants
need to be available simultaneously, and they all need to be rebuild if anything
in the preceding layers changes. They need to be isolated, so that they can be
built in parallel and tested/operated on in parallel. Each variant should have
exactly the same setup (including command-line args handling) and contents of
the image, but CLI should not start a GUI. Both modes should allow easy eval of
expressions; in GUI mode eval, a flag can be passed to leave the window/image
running. AGENTIC is a special GUI image that allows external AI agents to easily
query the image state and perform actions inside the image from the outside.

Layer L07 has two variants: DEV, with verbose logging and without any stripping,
and RELEASE, with reduced logging verbosity and cleaned up image. Since the
project will be a CLI-only program to end users, we don't need to set up GUI and
AGENTIC variants for this layer.

NOTE: AGENTIC variant of L04 and L05 should be kept as a placeholder until a
proper implementation for communicating with agents is designed and implemented.

NOTE: RELEASE variant of L07 should be kept mostly as a placeholder (with the
mocked logging config) until a release is actually needed.

#### L04 - project dependencies

The project can depend on "st" (Smalltalk) or "host" (OS-global or local shared
libraries and tools) dependency types. They are all defined in layer L04
configuration.

Each dependency has a source, which can refer to external repo, distribution of
some type (a .zip file for example), or a local fork of the repo. 

Each dependency has an output, which consists of code, resources, and metadata.

Each dependency has an initializer and dumper:

initializer
: obtains the required components and stores them in a way that dumper knows of
: supports versioning and checksums, knows when to regenerate/rebuild/refetch

dumper
: copies or exports required artifacts, generates manifests, needed scripts,
  hooks, etc.
: creates a representation (dep-manifest) of a loaded dependency in the image

NOTE: these "dumper"s works on dependencies, not images; we only "dump" the
image for the layer after all dep-dumpers ran on all dependencies.

NOTE: an installed/loaded package is represented in 2 ways: as a JSON file among
outputs and as a class in Smalltalk image. They should always be quivalent, so
both need to be generated at the same time and always kept in sync.

For Smalltalk dependencies, Monticello/Iceberg should be used - appropriate
objects can be referenced directly in st-manifest data; some additional
Smalltalk scripts can be provided to fetch/clone and load the dependency source.
The dumped manifest should allow, at minimum, connecting the repository
(especially if locally forked) to the dependency (ie. so that finding the proper
file to update after an arbitrary class is modified is possible and fast).

For host dependencies, if required by Smalltalk dependency, they can be
installed and configured from Smalltalk; but the automation should also allow
shell scripts and other CLI tools.

Both kinds of dependencies should be configured using the same config file
format, should read inputs from and write outputs to known locations, and should
support the same features.

NOTE: we will build a GUI frontend to the system, in GToolkit.

NOTE: we should focus on defining a robust protocol for dependencies, so that it
can be implemented not just in shell and Smalltalk. We might need Python or Ruby
packages for some scripts in those languages launched from Smalltalk, in which
case `pip` and `gem` integration should be easy to add.

NOTE: For now, we assume sequential list of dependencies, manually ordered so
that prerequisite deps are loaded before the deps that need them. If we're using
a package manager that resolves and handles transitive dependencies, as long as
we don't need to fix (and therefore, locally fork) any of them, we can delegate
this to that package manager. However, the option to manually provide a
dependency and therefore override one that would be automatically found/loaded
has to always be present.


Below is the plan I’d give the agents. It assumes your agreed defaults:

```text
GT source/download mode:
  support both, default to pinned downloaded GT

GT patches:
  long-lived patch branch/worktree

Dependencies:
  support public and private/local dependency repos

GUI:
  agents may use it under Linux/X

Invalidation:
  strict manifest-based invalidation using Git commits + file checksums

Headless eval:
  uses a saved project-agent image for speed

GUI:
  uses saved project-dev image; warn if stale, do not rebuild automatically
```

The extra requirement is important: **agent automation must support both “outside-in” Codex CLI control and “inside-out” GT Moldable Agent Harness control**. GT’s book documents the Moldable Agent Harness as programmable, contextualized chats that can use GT views, examples, explanations, and tools; it also has pages on tool-augmented interaction, generating code/tools, searching code, changing Lepiter pages, and working with objects. ([gtoolkit book][1])

## Target architecture

The agent should implement a **layered image build system** plus a **running-image control interface**.

There are two execution modes:

```text
Batch mode:
  Codex CLI calls `just build`, `just test`, `just eval`, etc.
  These run GT/Pharo headlessly against saved images.

Interactive GUI mode:
  Codex CLI launches or attaches to a running GT GUI image under X.
  It can use xdotool for visual interaction.
  It can also send Smalltalk eval requests to the running image through IPC.
```

The layer graph should be:

```text
gt-base
  -> gt-patched
    -> deps
      -> profile-dev
        -> project-dev
      -> profile-agent
        -> project-agent
      -> profile-test
        -> project-test
      -> profile-dist
        -> project-dist
```

Where:

```text
gt-base:
  clean GT release/downloaded or source-built base image

gt-patched:
  gt-base plus local GT patches from worktrees/gt

deps:
  project dependencies loaded from pinned repos/baselines

profile-*:
  project-specific configuration modes

project-*:
  actual project source loaded on top
```

## Phase 0 — inspect existing repository

Agent task:

1. Inspect current repo layout.
2. Detect existing project name from `BaselineOf*` if present.
3. Keep existing working commands intact.
4. Preserve current `just bootstrap`, `just gui`, `just load`, `just test`, `just smoke`, `just eval`, `just clean-runtime` behavior where possible.
5. Add the layered system without breaking the simpler workflow.

Acceptance criteria:

```sh
just --list
just smoke
just test
```

still exist.

## Phase 1 — add layer directory structure

Create:

```text
layers/
  layers.toml
  profiles/
    dev.toml
    agent.toml
    test.toml
    dist.toml
  locks/
    gt.lock
    deps.lock
  manifests/
    .gitkeep

scripts/
  layers/
    common.sh
    build-layer.sh
    layer-status.sh
    write-manifest.py
    stale-layers.py

    build-gt-base.sh
    build-gt-patched.sh
    build-deps.sh
    build-profile.sh
    build-project.sh

    smalltalk/
      save-image.st
      load-gt-patches.st
      load-deps.st
      apply-profile.st
      load-project.st
      run-tests.st
      eval.st
      image-info.st
      changed-packages.st
      start-ipc-server.st

images/
  .gitkeep

worktrees/
  .gitkeep
```

Update `.gitignore`:

```gitignore
/images/*
!/images/.gitkeep

/worktrees/*
!/worktrees/.gitkeep

/layers/manifests/*
!/layers/manifests/.gitkeep
```

Do **not** ignore `layers/locks/*.lock`; those are source-controlled.

Acceptance criteria:

```sh
test -f layers/layers.toml
test -f layers/profiles/dev.toml
test -f scripts/layers/build-layer.sh
test -d images
test -d worktrees
```

## Phase 2 — define `layers.toml`

Create a readable, explicit config. Start with placeholders if exact GT source build is not implemented yet.

Example:

```toml
[project]
name = "MyGtProject"
baseline = "BaselineOfMyGtProject"
src = "src"

[gt]
mode = "download" # download | source
version = "v1.1.x"
download_root = "vendor/gt-upstream"

[repos.gt]
path = "worktrees/gt"
remote = "https://github.com/feenkcom/gtoolkit.git"
branch = "gt-patches/my-gt-project"

[repos.project]
path = "."
branch = "main"

[layer.gt-base]
kind = "gt-base"
parent = ""
output = "images/gt-base/GlamorousToolkit.image"

[layer.gt-patched]
kind = "gt-patched"
parent = "gt-base"
repo = "gt"
output = "images/gt-patched/GlamorousToolkit.image"

[layer.deps]
kind = "deps"
parent = "gt-patched"
output = "images/deps/GlamorousToolkit.image"

[layer.profile-dev]
kind = "profile"
parent = "deps"
profile = "layers/profiles/dev.toml"
output = "images/profile-dev/GlamorousToolkit.image"

[layer.profile-agent]
kind = "profile"
parent = "deps"
profile = "layers/profiles/agent.toml"
output = "images/profile-agent/GlamorousToolkit.image"

[layer.profile-test]
kind = "profile"
parent = "deps"
profile = "layers/profiles/test.toml"
output = "images/profile-test/GlamorousToolkit.image"

[layer.profile-dist]
kind = "profile"
parent = "deps"
profile = "layers/profiles/dist.toml"
output = "images/profile-dist/GlamorousToolkit.image"

[layer.project-dev]
kind = "project"
parent = "profile-dev"
profile = "dev"
output = "images/project-dev/GlamorousToolkit.image"

[layer.project-agent]
kind = "project"
parent = "profile-agent"
profile = "agent"
output = "images/project-agent/GlamorousToolkit.image"

[layer.project-test]
kind = "project"
parent = "profile-test"
profile = "test"
output = "images/project-test/GlamorousToolkit.image"

[layer.project-dist]
kind = "project"
parent = "profile-dist"
profile = "dist"
output = "images/project-dist/GlamorousToolkit.image"

[package_owners]
"BaselineOfMyGtProject" = "project"
"MyGtProject*" = "project"
"Gt*" = "gt"
"Bloc*" = "gt"
"Brick*" = "gt"
"Br*" = "gt"
```

Acceptance criteria:

```sh
python3 -c 'import tomllib; tomllib.load(open("layers/layers.toml","rb")); print("ok")'
```

## Phase 3 — implement manifest model

Each layer output directory should contain:

```text
images/<layer>/
  GlamorousToolkit.image
  GlamorousToolkit.changes
  manifest.json
```

Manifest fields:

```json
{
  "schema": 1,
  "layer": "project-agent",
  "parent": "profile-agent",
  "canonical": true,
  "created_at": "...",
  "builder": "...",
  "inputs": {
    "parent_manifest_sha256": "...",
    "layers_toml_sha256": "...",
    "profile_sha256": "...",
    "scripts_sha256": "..."
  },
  "repos": {
    "project": {
      "path": ".",
      "commit": "...",
      "branch": "...",
      "dirty": false
    },
    "gt": {
      "path": "worktrees/gt",
      "commit": "...",
      "branch": "...",
      "dirty": false
    }
  }
}
```

Implement:

```text
scripts/layers/write-manifest.py
scripts/layers/stale-layers.py
scripts/layers/layer-status.sh
```

Rules:

```text
A layer is stale if:
  parent manifest hash changed
  layers.toml changed in a relevant way
  its profile file changed
  relevant builder scripts changed
  relevant repo commit changed
  relevant repo is dirty and the layer requires canonical source
```

Acceptance criteria:

```sh
just layer-status
```

prints all known layers as one of:

```text
missing
fresh
stale
dirty-inputs
```

## Phase 4 — implement build orchestration

Add `just` tasks:

```just
layers:
    ./scripts/layers/list-layers.sh

layer-status:
    ./scripts/layers/layer-status.sh

build layer:
    ./scripts/layers/build-layer.sh {{layer}}

rebuild-from layer:
    ./scripts/layers/rebuild-from.sh {{layer}}

clean-images:
    rm -rf images/*
    touch images/.gitkeep
```

`build-layer.sh` should:

1. Read `layers.toml`.
2. Resolve parent.
3. Build parent first if missing/stale.
4. Copy parent image/changes to target directory.
5. Run the appropriate builder script.
6. Save image.
7. Write manifest.

Do not implement clever partial image mutation yet. Rebuild by copying parent image and running one stage script.

Acceptance criteria:

```sh
just layers
just layer-status
just build gt-base
just build project-agent
just layer-status
```

## Phase 5 — implement `gt-base`

`gt-base` should support two modes:

```text
download:
  use existing bootstrap/downloaded GT distribution

source:
  clone/build GT from source into worktrees/gt and produce a base image
```

For now, implement `download` completely and leave `source` as an explicit TODO with a clear error unless the agent can verify the exact GT source-build command locally.

GT’s own repository documents both normal downloads and source-install scripts, so this split is aligned with upstream: the source-install path is mainly useful when developing GT itself. ([gtoolkit book][2])

Acceptance criteria:

```sh
just build gt-base
test -f images/gt-base/GlamorousToolkit.image
test -f images/gt-base/manifest.json
```

## Phase 6 — implement `gt-patched`

Create:

```sh
just setup-gt-worktree
```

Behavior:

```text
If worktrees/gt does not exist:
  clone https://github.com/feenkcom/gtoolkit.git worktrees/gt
  checkout or create branch gt-patches/<project-name>

If it exists:
  print status and branch
```

`gt-patched` behavior:

```text
If no GT worktree is configured or no patches are present:
  copy gt-base to gt-patched and write manifest

If GT patch repo exists:
  load or apply GT patch packages from worktrees/gt
  save image
```

This may initially be conservative:

```text
v1:
  make layer exist
  record GT patch worktree commit
  do not attempt full GT source replacement unless verified

v2:
  load changed GT packages/baselines from worktrees/gt
```

Acceptance criteria:

```sh
just setup-gt-worktree
just build gt-patched
just layer-status
```

## Phase 7 — implement dependencies layer

Add `layers/locks/deps.lock`, probably TOML:

```toml
[[dependency]]
name = "SomeDependency"
baseline = "BaselineOfSomeDependency"
repository = "github://owner/repo:main/src"
groups = ["default"]
commit = ""
```

For now, allow an empty dependency list.

`load-deps.st` should:

1. Read dependency lock file, or receive generated Smalltalk from shell.
2. Load each dependency through Metacello.
3. Save image.

Acceptance criteria with empty deps:

```sh
just build deps
```

must work.

Acceptance criteria with a sample dependency, if one is added later:

```sh
just build deps
```

loads it and records the lock file hash in manifest.

## Phase 8 — implement profiles

Profiles should be source-controlled text files.

Example `layers/profiles/agent.toml`:

```toml
name = "agent"
gui = false
ipc = false
lepiter = false
startup = "minimal"
logging = "verbose"
```

Example `layers/profiles/dev.toml`:

```toml
name = "dev"
gui = true
ipc = true
lepiter = true
startup = "world"
logging = "normal"
```

Example `layers/profiles/test.toml`:

```toml
name = "test"
gui = false
ipc = false
lepiter = false
startup = "minimal"
logging = "test"
```

Example `layers/profiles/dist.toml`:

```toml
name = "dist"
gui = true
ipc = false
lepiter = true
startup = "application"
logging = "warn"
```

`apply-profile.st` can start simple:

```text
Set globals/environment values.
Install project startup config object.
Configure whether IPC service should autostart.
Configure whether Lepiter project DB should be registered.
```

Acceptance criteria:

```sh
just build profile-dev
just build profile-agent
just build profile-test
just build profile-dist
```

## Phase 9 — implement project layers

`project-*` layers load your project baseline from local `src/`.

Rules:

```text
project-dev:
  load default + examples + dev helpers
  IPC enabled
  GUI expected

project-agent:
  load agent group or CI group
  optimized for fast eval
  no GUI required

project-test:
  load tests
  used by just test

project-dist:
  load distributable group
  require canonical parents
```

The existing `BaselineOfMyGtProject` should get groups:

```smalltalk
#Dev
#Agent
#Tests
#Dist
#CI
```

If those groups do not exist, map them initially like this:

```text
Dev:
  default + Examples + Tests

Agent:
  CI

Tests:
  Tests

Dist:
  default

CI:
  Core + Examples + Tests
```

Acceptance criteria:

```sh
just build project-agent
just build project-dev
just build project-test
just build project-dist
```

## Phase 10 — preserve simple user commands

Update existing simple commands so they use the layer system:

```just
gui:
    ./scripts/layers/gui-layer.sh project-dev

test:
    ./scripts/layers/eval-layer.sh project-test "MyGtProjectTestRunner run"

eval expr:
    ./scripts/layers/eval-layer.sh project-agent '{{expr}}'

smoke:
    ./scripts/layers/eval-layer.sh project-agent "Smalltalk includesKey: #MyGtProject"
```

But keep compatibility with existing `scripts/gt --headless` if the layered path fails. Do not remove the old scripts until the new ones pass.

Desired behavior:

```text
just gui:
  opens saved project-dev image
  warns if stale
  does not auto-rebuild

just eval:
  builds project-agent if missing
  warns/rebuilds if stale, because agent eval should be deterministic

just test:
  builds project-test if missing/stale
  runs tests

just build project-dist:
  refuses if any parent is non-canonical
```

## Phase 11 — add running GUI control

This is the new part from your note.

Add tasks:

```just
gui-start:
    ./scripts/gui/start-gui.sh project-dev

gui-stop:
    ./scripts/gui/stop-gui.sh project-dev

gui-status:
    ./scripts/gui/status-gui.sh project-dev

gui-eval expr:
    ./scripts/gui/eval-running.sh project-dev '{{expr}}'

gui-screenshot:
    ./scripts/gui/screenshot.sh project-dev

gui-click x y:
    ./scripts/gui/click.sh {{x}} {{y}}

gui-type text:
    ./scripts/gui/type.sh '{{text}}'
```

Create:

```text
scripts/gui/
  start-gui.sh
  stop-gui.sh
  status-gui.sh
  eval-running.sh
  screenshot.sh
  click.sh
  type.sh
  focus.sh
```

Use X11 assumptions:

```text
DISPLAY must be set.
xdotool should be available.
import or maim/scrot can be used for screenshots if installed.
```

Do not make screenshot tooling mandatory at first. Detect available command.

Acceptance criteria:

```sh
just gui-start
just gui-status
just gui-eval "1 + 2"
just gui-screenshot
just gui-stop
```

## Phase 12 — implement IPC eval in running image

Do this before heavy xdotool automation. GUI clicking alone is fragile; the agent needs a Smalltalk-side view of the running image.

Create a project package, for example:

```text
MyGtProject-AgentControl
```

Classes:

```text
MyGtAgentControlServer
MyGtAgentControlRequest
MyGtAgentControlResponse
MyGtAgentControlSecurity
```

Start simple with a localhost-only HTTP server or Unix socket, depending on what is easiest in GT/Pharo.

Recommended v1 protocol:

```text
POST /eval
Content-Type: application/json

{
  "expression": "1 + 2",
  "print": true,
  "timeoutMs": 5000
}
```

Response:

```json
{
  "ok": true,
  "result": "3",
  "class": "SmallInteger",
  "durationMs": 12
}
```

For errors:

```json
{
  "ok": false,
  "error": "...",
  "stack": "..."
}
```

Security rules:

```text
Bind only to 127.0.0.1.
Require a token stored in artifacts/gui/project-dev.token.
Do not listen by default except in dev/agent-gui profile.
Never enable IPC in dist profile.
```

Add profile setting:

```toml
ipc = true
ipc_host = "127.0.0.1"
ipc_port_file = "artifacts/gui/project-dev.port"
ipc_token_file = "artifacts/gui/project-dev.token"
```

Add Smalltalk startup:

```text
When profile says ipc = true:
  start MyGtAgentControlServer
  write port/token metadata
```

Acceptance criteria:

```sh
just gui-start
just gui-eval "1 + 2"
```

returns:

```text
3
```

without launching a second image.

## Phase 13 — add GUI + IPC agent profile

Add new profile/layer pair:

```text
profile-agent-gui
project-agent-gui
```

Purpose:

```text
GUI enabled
IPC enabled
Lepiter enabled if useful
extra instrumentation enabled
used by Codex CLI when it needs both xdotool and Smalltalk eval
```

Extend graph:

```text
deps
  -> profile-agent-gui
    -> project-agent-gui
```

Add tasks:

```just
build-agent-gui:
    ./scripts/layers/build-layer.sh project-agent-gui

agent-gui:
    ./scripts/gui/start-gui.sh project-agent-gui

agent-gui-eval expr:
    ./scripts/gui/eval-running.sh project-agent-gui '{{expr}}'
```

This avoids overloading `project-dev`. Human dev and agent GUI sessions can be separate images.

Acceptance criteria:

```sh
just build project-agent-gui
just agent-gui
just agent-gui-eval "Smalltalk image imageName"
```

## Phase 14 — add xdotool helpers

The agent should have stable high-level commands instead of raw xdotool everywhere.

Implement:

```sh
scripts/gui/window-id.sh
scripts/gui/focus.sh
scripts/gui/key.sh
scripts/gui/type.sh
scripts/gui/click.sh
scripts/gui/screenshot.sh
```

Window detection should use:

```text
window title
process id
artifact file written by launcher
```

Store GUI process state:

```text
artifacts/gui/project-agent-gui.pid
artifacts/gui/project-agent-gui.window
artifacts/gui/project-agent-gui.port
artifacts/gui/project-agent-gui.token
```

Acceptance criteria:

```sh
just agent-gui
scripts/gui/focus.sh project-agent-gui
scripts/gui/key.sh project-agent-gui ctrl+l
scripts/gui/screenshot.sh project-agent-gui
```

## Phase 15 — add package ownership and change classification

Create:

```text
scripts/layers/smalltalk/changed-packages.st
scripts/layers/classify-changes.sh
```

Tasks:

```just
changed-packages:
    ./scripts/layers/changed-packages.sh project-dev

classify-changes:
    ./scripts/layers/classify-changes.sh project-dev
```

Output format:

```text
project:
  MyGtProject-Core
  MyGtProject-Tests

gt:
  GtInspector
  Bloc-Core

unknown:
  SomePackage
```

Use the `package_owners` section from `layers.toml`.

Acceptance criteria:

```sh
just changed-packages
just classify-changes
```

works against `project-dev` or `project-agent-gui`.

## Phase 16 — add commit helpers, but keep them conservative

Add:

```just
commit-layer owner:
    ./scripts/layers/commit-layer.sh {{owner}}
```

Supported owners:

```text
project
gt
deps later
```

For v1, `commit-layer` should **not auto-commit blindly**. It should:

1. Show classified changes.
2. Show target repo.
3. Export/save packages if needed.
4. Run `git status`.
5. Refuse to commit without a provided message.

Use:

```sh
just commit-layer project "message"
just commit-layer gt "message"
```

Acceptance criteria:

```sh
just classify-changes
just commit-layer project "Update project package"
```

commits only project-owned changes.

## Phase 17 — add rebuild-from-lower-layer workflow

Implement:

```sh
just rebuild-from gt-patched
just rebuild-from deps
just rebuild-from profile-agent-gui
```

Rules:

```text
Find selected layer.
Delete/rebuild that layer and all descendants.
Respect canonical/non-canonical manifest flags.
Stop on first failure.
Print final layer-status.
```

Acceptance criteria:

```sh
just rebuild-from deps
just layer-status
```

## Phase 18 — integrate Moldable Agent Harness later, but prepare hooks now

Do not try to fully wire GT’s Moldable Agent Harness in the first automation pass. But prepare a package and docs.

Create package:

```text
MyGtProject-AgentHarness
```

Create classes/placeholders:

```text
MyGtProjectAgentContext
MyGtProjectAgentTools
MyGtProjectAgentExplanations
MyGtProjectAgentScenarios
```

Create Lepiter page or markdown doc:

```text
lepiter/agent-harness.md
```

Document intended mapping:

```text
Codex CLI outside-in tools:
  just build
  just test
  just eval
  just agent-gui
  just agent-gui-eval
  xdotool helpers

GT inside-out tools:
  Moldable Agent Harness chats
  project-specific tools
  code search tools
  object inspection tools
  examples as executable context
```

The GT Moldable Agent Harness docs emphasize that chats can be contextualized with views, examples, explanations, and tools, and GT has official pages for generating code, generating LLM tools, searching code, changing Lepiter pages, and working with objects. ([gtoolkit book][3])

Acceptance criteria:

```text
There is a package/doc stub explaining how future GT-internal agents will expose project-specific tools.
No fake integration with external LLM APIs is required yet.
```

## Phase 19 — update AGENTS.md

Add a section:

```text
When working on this repository:

Default checks:
  just test

Fast Smalltalk check:
  just eval "1 + 2"

GUI session for agents:
  just agent-gui
  just agent-gui-eval "Smalltalk expression"
  scripts/gui/screenshot.sh project-agent-gui
  scripts/gui/key.sh project-agent-gui <key>
  scripts/gui/type.sh project-agent-gui "text"

Layer rules:
  Do not edit images directly as source of truth.
  If you modify project packages, commit them to the project repo.
  If you modify GT packages, commit them to worktrees/gt.
  After lower-layer changes, run just rebuild-from <layer>.

Never commit:
  images/
  vendor/
  artifacts/
  worktrees/
```

## Phase 20 — update README.md

Document:

```text
Layer model
Common commands
GUI agent mode
IPC eval
GT patch workflow
Rebuild-from workflow
Manifests and stale detection
Canonical vs promoted images
```

Include the main example workflow:

```sh
just build project-agent
just eval "MyGtProject name"
just agent-gui
just agent-gui-eval "Smalltalk image imageName"
just classify-changes
just commit-layer project "Implement parser example"
just rebuild-from project-agent
just test
```

And GT-fix workflow:

```sh
just agent-gui
# debug/edit GT in GUI
just classify-changes
just commit-layer gt "Fix GT issue encountered in project"
just rebuild-from gt-patched
just test
```

## Final task list for Codex CLI

Give the agent the work in this order:

```text
1. Add layer config, directories, ignores.
2. Add manifest generation and stale detection.
3. Add generic layer build orchestration.
4. Implement gt-base from existing downloaded GT setup.
5. Implement no-op/pass-through gt-patched layer plus GT worktree setup.
6. Implement deps layer with empty dependency lock support.
7. Implement profile layers.
8. Implement project-agent/project-test/project-dev/project-dist layers.
9. Rewire just tasks to use project-agent/project-test/project-dev.
10. Add project-agent-gui profile/layer.
11. Add GUI process scripts.
12. Add IPC eval server package and startup.
13. Add gui-eval command.
14. Add changed package/classification scripts.
15. Add conservative commit-layer helper.
16. Add rebuild-from command.
17. Add Moldable Agent Harness placeholder package/docs.
18. Update AGENTS.md and README.md.
19. Run just --list.
20. Run non-download checks that do not require placeholder GT URL.
21. If a real GT runtime is already present, run just build project-agent, just test, just agent-gui-eval "1 + 2".
```

## Minimal acceptance suite

Once implemented, this should work:

```sh
just --list
just layers
just layer-status
just build project-agent
just eval "1 + 2"
just test
just build project-agent-gui
just agent-gui
just agent-gui-eval "1 + 2"
just gui-screenshot
just classify-changes
```

The important design boundary is this:

```text
Codex CLI owns filesystem, Git, shell, rebuilds, and X11 automation.

GT owns live objects, views, examples, Lepiter pages, Moldable Agent Harness, and rich Smalltalk-side introspection.

The IPC bridge is the seam between them.
```

That gives agents real access to the GUI without making GUI automation the only control path.

[1]: https://book.gtoolkit.com/?utm_source=chatgpt.com "Glamorous Toolkit"
[2]: https://book.gtoolkit.com/moldable-agent-harness--guiding-chats-thro-cr0a1n6tq9o7gxif19nvybema?utm_source=chatgpt.com "Moldable Agent Harness: Guiding chats through ..."
[3]: https://book.gtoolkit.com/moldable-agent-harness--a-step-by-step-tut-bbu6tutrk7amb3bwvrw0c06jg?utm_source=chatgpt.com "Moldable Agent Harness: a step-by-step tutorial"
