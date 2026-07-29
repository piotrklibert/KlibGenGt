# KlibGen-GT reproducible layered build architecture

**Status:** Initial implementation specification  
**Version:** 0.1  
**Audience:** Human maintainers and coding agents implementing the first version  
**Scope:** Source code, repositories, versioning, images, layer construction, rebuilds, development snapshots, and build isolation

## 1. Purpose

KlibGen-GT is developed in Pharo/GToolkit and therefore operates in two related
but distinct worlds:

1. source-controlled files, repositories, configuration, scripts, and external
   tools on the host system;
2. mutable Smalltalk images containing executable code, development state,
   tools, configuration, and arbitrary live objects.

The live image is a major development advantage, but it is not by itself a
sufficient source-of-truth or reproducible build model. A saved image can contain
changes and state that are difficult to identify, compare, review, reproduce, or
process with external tools.

This specification defines a layered build system in which:

- source code, configuration, lock files, and explicit metadata are authoritative;
- images are produced from declared inputs;
- every reusable image has known provenance;
- changes can be introduced at any layer;
- changing a layer automatically invalidates and rebuilds downstream layers;
- development remains live and interactive;
- temporary forks and alternative builds are isolated;
- command-line tools and external agents can operate the system without relying
  on undocumented image state.

The first version is intentionally conservative. It does not attempt to add
namespaces, scoped extension methods, a new package system, or other language
extensions. Where Pharo/GToolkit does not provide sufficiently strong guarantees,
the first version adds explicit configuration, manifests, checks, and workflow
rules.

## 2. Normative language

The terms **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** describe
implementation requirements.

A requirement marked **TODO** is deliberately deferred. A requirement marked
**V1 simplification** describes behavior that is acceptable initially but is not
the intended final design.

## 3. Goals

The first implementation MUST provide the following properties.

### 3.1 Reproducible construction

A reusable layer artifact MUST be reconstructible from:

- its parent artifact;
- declared configuration;
- resolved and pinned source versions;
- declared build scripts and resources;
- relevant host-platform information;
- explicit local overrides, if any.

The first version targets **functional reproducibility**, not necessarily
byte-for-byte identical images. Given equivalent declared inputs on an equivalent
platform, a rebuilt artifact MUST satisfy the same layer contract and tests.

### 3.2 Explicit source of truth

The source of truth MUST be external to reusable images. It consists of:

- Git repositories and worktrees;
- committed Smalltalk source files;
- build scripts;
- layer configuration;
- dependency specifications;
- resolved lock files;
- generated manifests;
- declared patches and overrides.

A reusable image MUST NOT be treated as the only copy of a source change.

### 3.3 Layer-local intervention

A maintainer MUST be able to replace, patch, or locally rebuild any layer without
manually reconstructing all downstream images.

Examples include:

- using a locally built VM instead of a downloaded one;
- selecting a different GT base version;
- applying a temporary GT patch branch;
- replacing one project dependency with a local fork;
- changing project setup code;
- loading a project worktree with uncommitted changes;
- creating a temporary distribution from an alternative build context.

### 3.4 Automatic downstream rebuilding

When a layer becomes stale, all artifacts that depend on it MUST be considered
stale. Building any downstream target MUST first build or reuse a current artifact
for every required ancestor.

### 3.5 Isolation

Concurrent or alternative builds MUST NOT overwrite each other's canonical
artifacts, writable images, logs, manifests, Git worktrees, ports, or temporary
files.

### 3.6 Agent-friendly operation

The core workflow MUST be scriptable, non-interactive by default, observable
through logs and manifests, and usable from a clean shell without manually
opening GToolkit.

## 4. Non-goals for the first version

The following are explicitly outside the first implementation:

- adding language-level namespaces;
- replacing Pharo packages, Iceberg, Tonel, or Metacello;
- providing scoped extension-method semantics;
- automatically understanding every possible method override;
- supporting arbitrary build matrices efficiently;
- byte-identical image generation;
- sandboxing untrusted Smalltalk code;
- exposing evaluation or agent control interfaces to untrusted networks;
- fully reproducible cross-operating-system builds;
- automatic distributed builds;
- a polished GToolkit frontend;
- production-grade release image stripping.

These are possible future directions, not prerequisites for V1.

## 5. Core principles

### 5.1 Images are outputs, not primary source

Canonical layer images are build artifacts. They are generated from source and
configuration and MUST be replaceable by rebuilding them.

Interactive development images MAY be mutated. Any change intended to survive a
rebuild MUST be promoted to the appropriate source repository or configuration
layer.

### 5.2 Canonical artifacts are immutable

After a canonical layer artifact has passed its tests and has been published into
the artifact store, it MUST NOT be modified in place.

A runnable or editable image MUST be created as a writable copy of a canonical
artifact. Reflinks, copy-on-write filesystem copies, or normal copies MAY be used.

### 5.3 Mutable snapshots are explicitly non-reproducible

A saved GUI development image can preserve useful live state, but it is not a
canonical build artifact. Such an image MUST be classified as a resumable
snapshot and MUST NOT silently become an input to deterministic downstream
builds.

### 5.4 Exact versions beat moving names

Branches, tags, release names, and URLs are useful human-facing selectors.
Canonical build identity MUST use resolved immutable identifiers, such as:

- Git commit IDs;
- archive checksums;
- VM build identifiers;
- image checksums;
- dependency lock entries.

A branch name such as `main` or `klibgen` MUST NOT be sufficient by itself to
identify a built artifact.

### 5.5 Builds are graph operations

The layer numbering describes the main dependency order. The implementation
SHOULD model builds as a directed acyclic graph, even when the first version
constructs a mostly linear chain.

A layer MAY consume more than the previous image. It may also consume manifests,
source worktrees, generated resources, host tools, and lock files.

### 5.6 Hidden state is a defect

A successful build MUST NOT depend on:

- the currently checked-out branch of an unrelated shared working directory;
- manually installed image changes not represented in inputs;
- an undocumented environment variable;
- an interactive prompt;
- a process left running by an earlier build;
- mutable files in a shared cache addressed only by a friendly name.

When such a dependency is discovered, it MUST either be made explicit or be
reported as a build error.

## 6. Terminology

### 6.1 Layer definition

A committed description of how one logical layer is produced. It includes:

- layer identifier;
- declared parents;
- input configuration;
- scripts and Smalltalk setup code;
- output contract;
- tests;
- supported profiles or variants.

### 6.2 Layer artifact

An immutable output of building one layer with one resolved set of inputs.

A layer artifact normally contains:

- an image bundle, runtime bundle, or distribution bundle;
- a JSON manifest;
- checksums;
- logs or references to logs;
- test results;
- generated Smalltalk metadata to be loaded into descendant images.

### 6.3 Build context

A named, isolated selection of inputs and overrides across the layer graph.

Examples:

- `default`;
- `gt-klibgen`;
- `vm-gc-experiment`;
- `dep-cmark-local`;
- `issue-142-repro`.

A build context chooses source locations, variants, profiles, and local
overrides. Contexts are the V1 mechanism for supporting simultaneous alternative
builds.

### 6.4 Build key

A stable digest derived from all declared information that can affect a layer
artifact.

The build key determines whether an existing artifact can be reused.

### 6.5 Variant

A deliberate alternative within one layer. Variants can have different causes:

- **source variant**: different repository, commit, patch branch, or source build;
- **configuration profile**: CLI, GUI, or AGENTIC setup;
- **packaging profile**: DEV or RELEASE;
- **platform variant**: operating system, architecture, or VM ABI.

The implementation MAY use one generic variant mechanism, but manifests SHOULD
record the variant kind.

### 6.6 Lock file

A generated, committed or reviewable record resolving movable dependency
specifications to exact versions and checksums.

Configuration expresses desired inputs. A lock file expresses the exact inputs
selected for a build.

### 6.7 Manifest

A generated description of what was actually used and produced.

A manifest is not the same as a lock file:

- configuration says what is requested;
- a lock file says what exact external inputs were resolved;
- a manifest says what artifact was built from them and what it contains.

### 6.8 Promotion

The act of moving a change from a writable image or temporary worktree into the
authoritative source/configuration belonging to the correct layer.

### 6.9 Stale artifact

An artifact whose build key no longer matches the current resolved inputs, whose
parent artifact is stale, or whose required contract tests are no longer valid.

### 6.10 Canonical image

An immutable image stored as part of a successful layer artifact.

### 6.11 Run image

A writable copy of a canonical image created for one execution, evaluation,
test session, GUI session, or agent session.

### 6.12 Resumable snapshot

A saved writable development image containing state that is useful to resume but
is not guaranteed to be reproducible.

## 7. Main layer stack

The initial layer graph is:

```text
L01 runtime
  -> L02 gt-base
  -> L03 gt-patched
  -> L04 project-deps
  -> L05 project-setup
  -> L06 project-dev
  -> L07 project-dist

L06 project-dev
  -> L06-tmp resumable snapshot
```

`L06-tmp` is a side product of development and is not an ancestor of `L07`.

Layer identifiers MUST remain stable once manifests using them exist. Display
names MAY evolve.

Files committed specifically for a layer SHOULD use the layer identifier and
name, for example:

```text
build/layers/l05-project-setup/l05-project-setup-cli.st
```

## 8. Common layer contract

Every layer definition MUST declare the following.

### 8.1 Identity

- stable layer ID;
- human-readable name;
- layer schema version;
- implementation version or digest;
- parent layer IDs;
- supported variant/profile names.

### 8.2 Inputs

- parent artifact IDs or build keys;
- configuration files;
- lock files;
- source repositories and exact revisions;
- static resources;
- build scripts;
- relevant environment values;
- platform constraints;
- explicit context overrides.

### 8.3 Outputs

- canonical artifact location;
- artifact type;
- generated manifest;
- checksums;
- contract-test result;
- logs;
- generated in-image metadata, when applicable.

### 8.4 Tests

Each layer MUST define at least one smoke test. Tests SHOULD be divided into:

- startup tests;
- capability/contract tests;
- version/provenance checks;
- variant-difference checks;
- source cleanliness checks;
- downstream compatibility checks.

### 8.5 Mutation policy

Each layer MUST declare whether its artifact is:

- immutable and reusable;
- writable but disposable;
- a resumable snapshot;
- a final distribution.

Canonical outputs for L01-L07 MUST be immutable after publication.

### 8.6 Failure policy

A failed build MUST NOT replace a previously successful canonical artifact.

A failed build SHOULD retain:

- complete logs;
- resolved input data;
- temporary manifest;
- exit status;
- failing Smalltalk script or expression;
- partial image, when useful and safe;
- diagnostic transcript;
- process metadata.

Partial output MUST be stored outside the canonical artifact path.

## 9. Layer-specific requirements

## 9.1 L01 — runtime

### Purpose

Provide the VM, launcher, required VM plugins, and host-level runtime resources
needed to start the selected Pharo/GT image family.

### Supported source forms

V1 SHOULD support:

1. extraction from a pinned downloaded GT distribution;
2. use of a locally built runtime bundle.

Future versions MAY build the VM and launcher directly from source as a normal
build recipe.

### Inputs

- platform and architecture;
- download URL or local source/build path;
- exact archive checksum or source commit;
- runtime build configuration;
- required launcher scripts;
- required VM plugins;
- local context overrides.

### Outputs

- runtime bundle;
- launcher entry point;
- plugin inventory;
- runtime manifest;
- runtime checksum inventory.

If L01 is sourced from a full downloaded GT distribution, the layer MUST publish
only the runtime-related artifacts it owns. The clean base image belongs to L02.

### Contract tests

- launcher prints version information;
- VM can start a compatible minimal image;
- required plugins are present;
- headless invocation exits with the expected status;
- runtime bundle paths are self-consistent.

### Variants

- `downloaded`;
- `local-build`.

### TODO

- source-build automation;
- cross-platform runtime matrix;
- VM ABI compatibility declaration;
- automated plugin compatibility checks.

## 9.2 L02 — gt-base

### Purpose

Provide a clean, pinned GT image before local patches or project dependencies are
loaded.

### Inputs

- L01 runtime artifact;
- GT release archive or repository-based image source;
- exact release identifier and checksum, or exact source commit;
- base-image preparation script;
- compatibility policy.

### Outputs

- canonical clean GT image bundle;
- image checksum;
- GT/Pharo version metadata;
- source archive or source-file references required by the image;
- base-image manifest.

### Contract tests

- image starts headlessly with the selected L01 runtime;
- a trivial expression can be evaluated;
- expected GT core packages are present;
- no KlibGen project package is loaded;
- version metadata matches the resolved lock;
- the image can be copied and saved without corrupting the canonical artifact.

### Variants

- numbered GT release;
- commit-based GT image.

Variants called interchangeable MUST satisfy the same L02 contract. They are not
required to be byte-identical.

### TODO

- define exact GT release-to-commit mapping;
- define acceptable compatibility differences between release and commit builds;
- add a base-image normalization pass if required.

## 9.3 L03 — gt-patched

### Purpose

Apply local GT fixes and deliberate GT modifications on top of L02.

### Source model

The intended model is a fork of the relevant GT source repository or repositories.
Configured branches or worktrees provide alternative L03 source variants.

V1 MUST NOT automatically treat every local branch as a variant. Build contexts
MUST explicitly name the branch/worktree/commit to use.

The initially expected variants are:

- `baseline`: exact upstream-equivalent source;
- `klibgen`: local fixes and changes.

Both names are selectors. The manifest MUST record exact commits.

### Inputs

- L02 artifact;
- GT fork worktree;
- exact GT fork commit or dirty tree digest;
- patch/load script;
- patch declarations, if present;
- context override data.

### Outputs

- patched canonical GT image;
- list of changed/loaded GT packages;
- GT source worktree mapping;
- exact source revision;
- dirty-state declaration;
- L03 manifest.

### Contract tests

- all L02 contract tests still pass unless explicitly superseded;
- declared GT patches are present;
- no undeclared project package is loaded;
- source packages map to the configured GT repository/worktree;
- the patch set can be identified from the manifest;
- baseline and patched variants satisfy the common compatibility contract.

### Cleanliness policy

A normal reusable L03 artifact SHOULD be built from a clean worktree and exact
commit.

V1 MAY allow a dirty L03 worktree for temporary contexts. In that case:

- the artifact MUST be marked dirty;
- the build key MUST include a content digest of relevant dirty files;
- the manifest MUST record changed and untracked files;
- the artifact MUST NOT be used for a RELEASE distribution.

### TODO

- first-class patch collection model;
- upstream issue/commit links;
- automatic detection of overrides against baseline;
- removal checks for patches merged upstream;
- multiple GT repository support if GT source is not represented by one repo.

## 9.4 L04 — project-deps

### Purpose

Install and load project dependencies that are not the main project source.

Dependencies can be:

- **Smalltalk dependencies**: packages, baselines, tools, and shared libraries
  loaded into the image;
- **host dependencies**: shared libraries, executables, language runtimes, or
  generated resources used by Smalltalk code or build scripts.

### Dependency declaration

Each dependency MUST have:

- stable dependency ID;
- dependency kind;
- source specification;
- version constraint or selector;
- resolved lock entry;
- source location;
- expected outputs;
- ordered load/build actions;
- verification actions;
- optional local override;
- ownership mapping to a repository/worktree where applicable.

### Dependency phases

The common conceptual protocol is:

```text
resolve -> fetch -> prepare/build -> load/install -> verify -> manifest
```

A dependency MAY omit phases that do not apply.

The original `initializer` and `dumper` terminology MAY be retained in code, but
the implementation MUST distinguish at least:

- obtaining source;
- building/preparing source;
- loading/installing into the image or host environment;
- generating the dependency manifest;
- verifying the result.

### V1 ordering

Dependencies MAY be represented as a manually ordered sequence. The sequence MUST
be deterministic and recorded in the manifest.

Package managers MAY handle transitive dependencies, but the exact resolved
result MUST be locked when possible.

A manually supplied dependency override MUST take precedence over an
automatically resolved dependency when explicitly configured.

### Inputs

- L03 artifact;
- dependency configuration;
- dependency lock file;
- dependency source caches;
- local dependency worktrees;
- host toolchain information;
- load/build scripts.

### Outputs

- canonical project-dependency image;
- installed host artifacts owned by the build context;
- dependency manifest;
- package-to-repository/worktree mapping;
- exact dependency versions;
- checksums;
- generated Smalltalk manifest metadata.

### Contract tests

- every declared dependency is present at the resolved version;
- required host executables/libraries can be located;
- Smalltalk packages can be mapped to their configured source;
- no unresolved moving version remains in the manifest;
- dependency load order is recorded;
- a dependency overridden by a local fork is identified as such;
- the image starts after all dependencies are loaded.

### Shared caches

Downloaded archives and bare Git object stores MAY be shared across contexts only
when they are addressed and verified by immutable identifiers.

Editable worktrees, build directories, installed host artifacts, and image files
MUST NOT be shared mutably between contexts.

### TODO

- dependency DAG instead of manual ordering;
- offline locked builds;
- package-manager adapters for Python, Ruby, and other host tools;
- automatic transitive dependency inventory;
- license metadata;
- vulnerability and provenance attestations;
- GUI dependency editor.

## 9.5 L05 — project-setup

### Purpose

Apply KlibGen project-level configuration and development/runtime support that is
not the main project source itself.

Expected contents include:

- startup configuration;
- argument handling;
- path abstraction and path bindings;
- Lepiter database configuration;
- feature flags;
- logging defaults;
- evaluation helpers;
- test harness support;
- optional agent integration.

### Configuration classes

Configuration MUST be classified as one of:

1. **committed project configuration** — reproducible and version controlled;
2. **resolved/generated configuration** — generated from locks or lower manifests;
3. **machine-local configuration** — paths or settings specific to one host;
4. **runtime configuration** — supplied when launching a run image.

Machine-local and runtime configuration SHOULD be injected late. They SHOULD NOT
be permanently baked into canonical images when a placeholder or startup binding
can be used instead.

If an absolute path is embedded into a canonical image in V1, the manifest MUST
record it and mark the artifact as host-bound.

### Profiles

The planned profiles are:

- `CLI`;
- `GUI`;
- `AGENTIC`.

CLI and GUI MUST contain the same project setup and dependencies unless a
difference is explicitly declared. They may differ in startup behavior and
runtime services.

AGENTIC MAY contain additional trusted-local development services and tooling.
It is not required to be content-identical to GUI.

### V1 simplification

V1 MAY implement CLI and GUI as separate canonical images even if they differ
only in startup configuration.

A more efficient future version MAY produce one setup image plus profile-specific
launch configuration.

AGENTIC MAY initially be a placeholder profile that fails with a clear
“not implemented” diagnostic or aliases GUI without exposing an agent protocol.

### Inputs

- L04 artifact;
- committed setup code and resources;
- selected profile;
- generated lower-layer metadata;
- machine-local configuration;
- startup and evaluation configuration.

### Outputs

- canonical setup image per implemented profile;
- profile manifest;
- generated startup metadata;
- declared runtime interface;
- path-binding inventory.

### Contract tests

- CLI starts without opening a GUI;
- GUI starts the expected GT environment;
- both modes support scripted expression evaluation;
- profile differences match the declared profile contract;
- lower-layer manifests are queryable from the image;
- startup does not depend on an unrecorded current working directory;
- agent/eval endpoints bind only to trusted local interfaces by default.

### TODO

- one-image/multiple-launch-profile design;
- authenticated agent protocol;
- path virtualization;
- portable Lepiter database binding;
- startup-service registry.

## 9.6 L06 — project-dev

### Purpose

Load the main KlibGen project source from a selected Git worktree into an image
prepared by L05.

L06 is the main reproducible development layer.

### Source model

The project worktree is authoritative. The image contains a loaded executable
representation and development metadata.

The worktree mapping MUST be explicit in the context and manifest. No build may
silently use whichever branch happens to be checked out in an unrelated shared
clone.

### Inputs

- selected L05 profile artifact;
- project Git worktree;
- exact project commit or dirty tree digest;
- project baseline/load scripts;
- test configuration;
- local source override data.

### Outputs

- canonical project development image;
- project source revision;
- loaded package inventory;
- package-to-worktree mapping;
- test results;
- dirty-state declaration;
- L06 manifest.

### Dirty worktree policy

Development builds MAY use an uncommitted project worktree.

When dirty source is used:

- the manifest MUST mark the build dirty;
- the build key MUST include a digest of relevant tracked and untracked source;
- the manifest MUST list changed/untracked paths;
- rebuilding from the same worktree contents SHOULD select the same build key;
- RELEASE packaging MUST reject the artifact.

The implementation SHOULD avoid hashing irrelevant files such as logs, editor
state, and generated outputs. Relevant path rules MUST be explicit.

### Profiles

L06 initially supports:

- `CLI`;
- `GUI`;
- `AGENTIC`, subject to the L05 limitation.

### Contract tests

- all expected project packages are loaded;
- the image can map project packages to the selected worktree;
- project unit and integration smoke tests pass;
- CLI behavior is available in CLI and GUI profiles;
- GUI profile can open the development environment;
- source changes are not written into another context's worktree;
- no canonical parent image is modified.

### TODO

- package-level incremental rebuild;
- fine-grained source digesting;
- source-to-image synchronization service;
- automatic promotion assistant;
- independent project branch artifact matrix.

## 9.7 L06-tmp — resumable development snapshot

### Purpose

Preserve a writable GUI development session so it can be resumed later.

Possible preserved state includes:

- open tabs and windows;
- Lepiter pages;
- playground snippets;
- instantiated objects;
- debugger state;
- uncommitted Smalltalk changes;
- runtime configuration;
- temporary investigation state.

### Rules

L06-tmp is not a canonical layer in the deterministic chain.

A snapshot MUST record:

- the parent L06 artifact ID;
- the worktree and context used;
- creation and last-save timestamps;
- whether Smalltalk source is dirty relative to disk;
- whether the associated Git worktree is dirty;
- profile and runtime metadata;
- snapshot image checksum.

A snapshot MUST NOT be used as the source image for L07.

A snapshot MAY be:

- resumed;
- inspected;
- compared with its parent;
- used to export/promote code;
- deleted;
- archived manually.

### Close behavior

The GUI close workflow SHOULD inspect image-side code changes and offer:

1. export/promote changes to source;
2. save a resumable snapshot;
3. discard the writable run image;
4. cancel closing.

The workflow MAY allow saving a snapshot containing broken or unexported state.
It MUST label that state clearly.

### TODO

- robust image-to-source dirty comparison;
- snapshot browser;
- selective object-state serialization;
- automatic expiration and garbage collection;
- crash recovery.

## 9.8 L07 — project-dist

### Purpose

Produce a distributable image and launcher for end users.

The project is initially expected to be CLI-only for end users.

### Profiles

- `DEV`: verbose logging, development metadata retained, minimal cleanup;
- `RELEASE`: reduced logging, explicit cleanup, release versioning, and stricter
  input policy.

### Inputs

L07 MUST be built from reproducible source and canonical parent artifacts. It
MUST NOT be built from L06-tmp.

Inputs include:

- selected L06 CLI artifact;
- packaging profile;
- launcher templates;
- startup entry point;
- distribution metadata;
- release version information;
- cleanup/strip policy.

### Outputs

- distributable image;
- launcher script or executable wrapper;
- distribution manifest;
- checksums;
- version metadata;
- startup configuration;
- packaging test results.

### RELEASE constraints

RELEASE MUST require:

- clean project source;
- clean required patch/dependency worktrees;
- exact committed revisions;
- successful required tests;
- no undeclared local overrides;
- no host-bound absolute development paths;
- no enabled unauthenticated agent/eval service.

### V1 simplification

DEV packaging SHOULD be implemented first.

RELEASE MAY initially reuse DEV cleanup behavior while clearly identifying itself
as incomplete. It MUST NOT claim production hardening that has not been
implemented.

### TODO

- image stripping;
- removal of development tools;
- reproducible archive packaging;
- signing and attestations;
- platform-specific installers;
- release publication.

## 10. Repository and worktree model

## 10.1 Repository roles

The system may use the following repositories:

- the main KlibGen-GT project repository;
- one or more GT fork repositories;
- dependency repositories;
- VM/runtime repositories;
- generated or packaging repositories, if introduced later.

Every editable source input MUST have a declared repository role and context-local
worktree.

## 10.2 No implicit current checkout

Build scripts MUST NOT derive source identity from an unrelated developer clone's
current branch.

The source for each editable repository MUST be supplied as:

- an explicit worktree path;
- an exact commit;
- an optional branch name for display and update operations;
- dirty-state metadata.

## 10.3 V1 alternative-build strategy

The first version supports alternative builds by creating separate build
contexts and, where editable source differs, separate Git worktrees.

Example:

```text
context default
  project worktree: ../worktrees/project-default
  GT worktree:      ../worktrees/gt-klibgen
  cmark worktree:   absent; use locked upstream source

context cmark-debug
  project worktree: ../worktrees/project-cmark-debug
  GT worktree:      ../worktrees/gt-klibgen
  cmark worktree:   ../worktrees/cmark-debug
```

Two contexts MAY point to the same immutable commit checkout or shared bare Git
object store, but MUST NOT share a mutable worktree that either context may edit.

### V1 simplification

A context MAY select one active source alternative per layer. Efficiently
building a full Cartesian matrix is deferred.

### Future direction

A later implementation SHOULD model source alternatives as first-class graph
nodes and allow arbitrary combinations without manually creating complete
contexts.

## 10.4 Worktree lifecycle

The build system SHOULD provide operations to:

- create a context worktree from a branch or commit;
- list context worktrees;
- validate that configured worktrees exist;
- show dirty state;
- detach or remove unused worktrees safely;
- prevent deletion while a run image or build uses the worktree.

Worktree creation and deletion MUST use Git-supported operations rather than
manually copying `.git` metadata.

## 10.5 Shared source caches

Bare clones and fetched Git objects MAY be shared. They are caches, not editable
source locations.

Build correctness MUST NOT depend on the cache retaining a friendly branch name.
Exact commits and checksums remain authoritative.

## 11. Source ownership and image synchronization

## 11.1 V1 ownership unit

The first version uses the Pharo package plus its configured repository/worktree
mapping as the main source ownership unit.

This is intentionally narrower than a complete provenance model.

For every editable loaded package, the system SHOULD know:

- package name;
- owning repository ID;
- worktree path;
- expected Tonel/source directory;
- layer that introduced the package;
- whether the repository is writable in this context.

Extension methods remain owned by their Pharo package. Detailed override and
cross-package provenance analysis is deferred.

## 11.2 Loading source

Source MUST be loaded through declared scripts and package/repository mappings.
An image build MUST NOT rely on packages left over from an unrelated prior image
session.

A layer build SHOULD begin from a fresh writable copy of its parent canonical
image and apply only its declared transformations.

## 11.3 Exporting source

Any image-side source change intended to persist MUST be exported to the owning
worktree before the canonical layer can be rebuilt with that change.

V1 MAY use Iceberg/Tonel operations directly and MAY require explicit package
selection.

The export command MUST refuse to guess when:

- a package maps to multiple writable repositories;
- no writable repository is configured;
- the target worktree does not match the build context;
- exporting would overwrite conflicting disk changes.

## 11.4 Promotion between layers

A change belongs to the earliest layer whose authoritative inputs should contain
it.

Examples:

- VM source/build change -> L01;
- clean GT base selection/bootstrap change -> L02;
- local GT source patch -> L03;
- dependency source or version change -> L04;
- startup/configuration/helper change -> L05;
- main project source change -> L06;
- packaging-only change -> L07.

After promotion:

1. source/configuration is updated;
2. the affected layer becomes stale;
3. downstream layers become stale;
4. the requested target is rebuilt;
5. the old snapshot or run image remains non-canonical.

### V1 simplification

The first version MAY require the user or agent to choose the destination layer.
It MUST validate the choice against package/repository configuration where
possible.

### TODO

- automatic method/class provenance;
- patch-versus-extension classification;
- live image diff browser;
- one-command promote-and-rebuild workflow;
- conflict-aware selective export.

## 12. Configuration, locks, and manifests

## 12.1 Committed configuration

Human-authored configuration SHOULD live under:

```text
build/
  layers/
  contexts/
  schemas/
  scripts/
```

The root `justfile` MAY delegate to scripts under `build/`.

Generated state SHOULD NOT be mixed with committed build definitions.

## 12.2 Generated state directory

V1 SHOULD use a repository-local generated root such as:

```text
.klibgen/
  artifacts/
  cache/
  locks/
  logs/
  runs/
  snapshots/
  state/
  tmp/
  worktree-metadata/
```

The exact name is configurable, but the generated root MUST normally be ignored
by Git.

Lock files intended for review or long-term pinning MAY instead be committed
under `build/locks/`.

## 12.3 Context configuration

A context file identifies source selections and overrides. Conceptual example:

```json
{
  "schemaVersion": 1,
  "contextId": "cmark-debug",
  "layers": {
    "L01": {
      "variant": "downloaded"
    },
    "L02": {
      "variant": "release",
      "version": "pinned-by-lock"
    },
    "L03": {
      "variant": "klibgen",
      "worktree": "../worktrees/gt-klibgen"
    },
    "L04": {
      "dependencyOverrides": {
        "cmark-gfm": {
          "worktree": "../worktrees/cmark-debug"
        }
      }
    },
    "L05": {
      "profiles": ["CLI", "GUI"]
    },
    "L06": {
      "worktree": "../worktrees/project-cmark-debug"
    }
  }
}
```

Paths SHOULD be resolved relative to an explicit context base directory, not the
caller's current working directory.

## 12.4 Lock data

A lock entry SHOULD include:

```json
{
  "dependencyId": "example",
  "sourceType": "git",
  "source": "configured-source-id",
  "requested": {
    "branch": "main"
  },
  "resolved": {
    "commit": "0123456789abcdef"
  },
  "integrity": {
    "treeHash": "implementation-defined"
  }
}
```

Archive sources MUST include a cryptographic checksum.

## 12.5 Layer manifest

A layer manifest MUST include at least:

```json
{
  "schemaVersion": 1,
  "layerId": "L06",
  "layerName": "project-dev",
  "contextId": "default",
  "buildKey": "digest",
  "status": "success",
  "createdAt": "informational timestamp",
  "parents": [
    {
      "layerId": "L05",
      "artifactId": "artifact identifier",
      "buildKey": "parent digest"
    }
  ],
  "variant": {
    "name": "GUI",
    "kind": "configuration-profile"
  },
  "platform": {
    "os": "linux",
    "architecture": "x86_64"
  },
  "sources": [],
  "locks": [],
  "inputs": [],
  "outputs": [],
  "tests": [],
  "dirty": false,
  "hostBound": false,
  "overrides": []
}
```

Timestamps MUST NOT influence the build key unless time is intentionally a build
input.

## 12.6 In-image metadata

Layer manifests SHOULD be made queryable from descendant Smalltalk images.

V1 MAY generate Smalltalk classes or methods from JSON manifests. The JSON file
is the canonical interchange representation.

Generated Smalltalk metadata and JSON MUST be produced by the same build step and
MUST identify the same manifest digest.

The image-side representation SHOULD be replaceable and generated, not manually
edited.

### TODO

- choose between generated classes, immutable objects loaded from JSON, or both;
- manifest schema version migration;
- signatures/attestations;
- content-addressed artifact IDs.

## 13. Build keys and staleness

## 13.1 Build-key inputs

A layer build key MUST include digests or normalized values for:

- layer ID and schema version;
- layer implementation scripts/resources;
- parent artifact build keys;
- selected variant/profile;
- relevant context configuration;
- relevant lock entries;
- exact source commits;
- relevant dirty source contents;
- relevant host/platform facts;
- explicit environment inputs;
- declared overrides.

It MUST NOT include incidental information such as:

- log timestamps;
- temporary directory names;
- process IDs;
- output path chosen after the key is calculated;
- current shell directory, unless explicitly declared.

## 13.2 Relevant source paths

Each layer SHOULD declare which repository paths affect it.

Example target behavior:

- changes under VM source stale L01 and descendants;
- GT patch source changes stale L03 and descendants;
- dependency configuration changes stale L04 and descendants;
- project setup scripts stale L05 and descendants;
- project source changes stale L06 and L07;
- packaging scripts stale only L07.

### V1 simplification

V1 MAY conservatively hash a larger part of the main repository and rebuild more
layers than necessary. It MUST NOT rebuild fewer layers than required.

Any conservative rule MUST be documented so agents understand why apparently
unrelated changes trigger rebuilds.

## 13.3 Downstream invalidation

The artifact store does not need to mutate old manifests when a new build appears.
An artifact is current only when its build key matches the key calculated from
current resolved inputs.

When building target `T`:

1. calculate or resolve required ancestor keys;
2. reuse successful matching artifacts;
3. build the earliest missing/stale ancestor;
4. continue through the dependency graph;
5. test each produced layer before publishing it;
6. return the final target artifact.

## 13.4 Force rebuild

The CLI MUST support forcing a rebuild without pretending that inputs changed.

A forced rebuild SHOULD produce the same build key and replace nothing until the
new artifact succeeds. The artifact store MAY retain multiple build attempts
under one logical key.

## 13.5 Test invalidation

A change to a layer's contract tests or test harness MUST cause those tests to run
again.

The implementation MAY either:

- include test definitions in the artifact build key; or
- maintain a separate verification key/status.

V1 SHOULD prefer including required tests in the build key for simplicity.

## 14. Image lifecycle

## 14.1 Canonical build flow

An image-producing layer SHOULD follow this sequence:

1. resolve the parent canonical artifact;
2. create an isolated temporary build directory;
3. copy or reflink the parent image and changes file;
4. apply declared transformations headlessly where possible;
5. save the produced image into the temporary directory;
6. stop all build-owned processes;
7. run layer contract tests;
8. generate checksums and manifest;
9. atomically publish the completed artifact;
10. leave the parent and previous successful artifacts unchanged.

## 14.2 Image bundles

An image artifact MUST identify all files needed to run it, including as
applicable:

- `.image`;
- `.changes`;
- source files or source-file reference;
- runtime compatibility information;
- startup scripts;
- manifest;
- checksums;
- profile metadata.

The implementation MUST NOT assume that an `.image` file alone is a complete
artifact.

## 14.3 Writable run copies

Launching GUI, AGENTIC, interactive CLI, or ad hoc evaluation SHOULD create a
run directory:

```text
.klibgen/runs/<context>/<run-id>/
```

The run directory SHOULD contain:

- writable image bundle;
- parent artifact ID;
- PID file;
- logs;
- runtime arguments;
- allocated ports/sockets;
- temporary files;
- optional resulting snapshot metadata.

A normal run MUST NOT modify the canonical artifact.

## 14.4 Save behavior

Saving a run image does not publish a new canonical layer.

The user or agent MUST explicitly choose one of:

- discard;
- keep as a resumable snapshot;
- export/promote source changes and rebuild;
- invoke a dedicated experimental artifact-capture command.

The experimental capture path, if implemented, MUST mark the artifact
non-reproducible until its state has been externalized.

## 14.5 Image shutdown

Build and run commands SHOULD attempt graceful image shutdown and MUST detect
leftover processes they own.

A canonical build MUST fail rather than publish if its image process remains
running and may still mutate output files.

## 15. Variants, profiles, and alternative builds

## 15.1 Simultaneous profiles

CLI, GUI, and AGENTIC artifacts for the same context MUST have distinct artifact
and run paths.

They MAY be built in parallel if their parent artifacts are immutable and all
profile-specific temporary state is isolated.

## 15.2 Context isolation

The context ID MUST be included in generated paths, logs, and runtime metadata.

A context MUST NOT modify another context's:

- worktree;
- canonical artifact;
- run image;
- snapshot;
- lock override;
- local host dependency installation;
- port/socket allocation.

## 15.3 Layer overrides

Every layer SHOULD support a controlled override mechanism for at least:

- parent artifact selection;
- source worktree or archive;
- exact source revision;
- configuration file;
- lock entry;
- build script implementation;
- optional additional diagnostic/test step.

Overrides MUST be explicit in the context and included in the manifest and build
key.

The system MUST NOT silently apply files found in an informal “patches” directory
unless that directory is a declared layer input.

## 15.4 Temporary forks

A temporary fork can be represented in V1 by:

1. creating or selecting a fork repository;
2. creating a context-specific worktree;
3. recording the worktree and exact commit in context configuration;
4. building the affected layer and descendants;
5. optionally deleting the context after the experiment.

This applies conceptually to runtime source, GT source, dependencies, project
source, and packaging code.

### TODO

- first-class fork object;
- graph visualization of alternatives;
- sharing unchanged descendants across compatible contexts;
- context derivation/inheritance;
- automatic temporary worktree creation from an issue/branch name.

## 16. Command-line interface

The root `justfile` is the primary human-facing entry point in V1. Complex logic
SHOULD live in scripts under `build/`, not in large inline shell fragments.

Command names below are normative in purpose but not necessarily final in exact
spelling.

## 16.1 Required operations

### Diagnose

```text
just doctor [context]
```

Checks required host tools, paths, Git worktrees, runtime prerequisites, writable
directories, and obvious port/process conflicts.

### Resolve

```text
just resolve [context]
```

Resolves movable dependency/source selectors and writes or verifies lock data.

### Status

```text
just status [context]
```

Shows:

- selected variants;
- worktree commits and dirty state;
- current and expected build keys;
- stale layers;
- available canonical artifacts;
- active runs and snapshots.

A machine-readable JSON mode MUST be available.

### Build

```text
just build <layer-or-target> [context]
```

Builds missing/stale ancestors and the requested target.

Examples:

```text
just build l06-gui default
just build l07-dev cmark-debug
```

### Test

```text
just test <layer-or-target> [context]
```

Runs declared tests against the current matching artifact, building it first if
necessary.

### Run

```text
just run <profile> [context]
```

Creates and launches a writable run image.

### Evaluate

```text
just eval <profile> [context] -- <expression-or-script>
```

Evaluates code in an isolated run image or an explicitly selected existing run.

The default MUST be non-interactive and terminate after evaluation.

### Snapshot

```text
just snapshot <run-id>
```

Saves a run as L06-tmp metadata and image bundle.

### Promote

```text
just promote <run-id-or-snapshot> [destination]
```

Exports selected source/configuration changes to an authoritative worktree or
layer input.

V1 MAY support only package-level source promotion.

### Rebuild

```text
just rebuild <layer-or-target> [context]
```

Forces rebuilding while retaining the same logical input identity.

### Clean and garbage collect

```text
just clean-runs [context]
just gc
```

Removes disposable runs and unreferenced artifacts according to policy.

Canonical artifacts referenced by contexts, snapshots, or explicit pins MUST NOT
be removed.

## 16.2 CLI behavior

Commands MUST:

- be non-interactive unless an interactive flag is explicitly supplied;
- return meaningful exit codes;
- write human-readable logs;
- support JSON output for agents;
- identify the context and target in every error;
- avoid ANSI-only diagnostics when output is redirected;
- be idempotent where practical;
- never report success before tests and manifest publication complete.

## 16.3 Concurrency

Build operations MUST use locks around publication of the same artifact key.

Concurrent builds of independent artifacts SHOULD be allowed.

A second process requesting an artifact already being built MAY wait for the
first process or perform an isolated duplicate attempt. It MUST NOT write into
the same temporary directory.

## 17. Directory layout

Recommended committed layout:

```text
justfile

build/
  README.md
  schemas/
    context.schema.json
    lock.schema.json
    manifest.schema.json

  scripts/
    common/
    host/
    smalltalk/

  contexts/
    default.json
    examples/

  locks/
    default.lock.json

  layers/
    l01-runtime/
      layer.json
      scripts/
      resources/
      tests/

    l02-gt-base/
      layer.json
      scripts/
      resources/
      tests/

    l03-gt-patched/
      layer.json
      scripts/
      resources/
      tests/

    l04-project-deps/
      layer.json
      dependencies.json
      scripts/
      resources/
      tests/

    l05-project-setup/
      layer.json
      scripts/
      resources/
      tests/

    l06-project-dev/
      layer.json
      scripts/
      resources/
      tests/

    l07-project-dist/
      layer.json
      scripts/
      resources/
      tests/

src/
  MyProject-Core/
  ...
```

Recommended generated layout:

```text
.klibgen/
  artifacts/
    <platform>/
      <context>/
        <layer-id>/
          <build-key>/

  cache/
    archives/
    git/
    toolchains/

  locks/
  logs/
  runs/
  snapshots/
  state/
  tmp/
  worktree-metadata/
```

The artifact directory SHOULD be treated as implementation-owned. Humans and
agents SHOULD locate artifacts through manifests or CLI commands rather than
constructing paths manually.

## 18. Host environment and security assumptions

## 18.1 Host capture

Manifests SHOULD capture relevant host facts, including:

- operating system;
- architecture;
- runtime/VM version;
- paths to required executables;
- versions of required host tools;
- shared library resolution information when relevant;
- environment inputs explicitly declared by the layer.

The first version MAY be reproducible only within a compatible host class.

## 18.2 Environment variables

Only declared environment variables may influence a build key or build result.

Build scripts SHOULD start from a normalized environment and explicitly pass
allowed variables to child processes.

Secrets MUST NOT be written into manifests, logs, images, or lock files.

## 18.3 Evaluation and agent interfaces

Expression evaluation and AGENTIC interfaces are trusted-local development
features.

They MUST bind to loopback or local IPC by default and MUST NOT be enabled in
RELEASE artifacts.

Authentication and remote exposure are deferred.

## 19. Logging and diagnostics

Every build attempt SHOULD have a stable attempt ID and log directory.

Logs SHOULD distinguish:

- dependency resolution;
- host commands;
- Smalltalk startup;
- Smalltalk transcript;
- tests;
- manifest generation;
- publication.

A failed Smalltalk process SHOULD report:

- command line;
- image path;
- startup script;
- exit status or signal;
- last transcript output;
- timeout information;
- location of retained diagnostic files.

Machine-readable build events are a future direction, but V1 SHOULD at least
produce a summary JSON file.

## 20. Garbage collection and retention

The system will produce many large images. V1 MUST have an explicit retention
model.

Artifacts may be:

- referenced by a named context;
- referenced by a snapshot;
- pinned manually;
- current for a build key;
- unreferenced;
- failed/partial.

The garbage collector MUST preserve referenced and pinned artifacts.

V1 MAY retain only the newest successful attempt for each build key and a bounded
number of failed attempts.

Runs MAY be deleted aggressively after successful termination unless converted
to snapshots.

## 21. Implementation invariants

The following invariants MUST be tested.

1. A canonical image is never launched writable in place.
2. A layer artifact is published only after required tests succeed.
3. A manifest identifies exact parents and source revisions.
4. A branch name is never the sole source identity.
5. Dirty source used in a build is recorded and content-digested.
6. RELEASE rejects dirty or undeclared source.
7. L06-tmp is never used as the parent of L07.
8. Contexts do not share mutable worktrees or run images.
9. Changing an ancestor input changes the expected descendant build keys.
10. Reusing an artifact requires a matching build key and successful status.
11. Failed builds do not overwrite successful artifacts.
12. Generated Smalltalk manifest data identifies the same JSON manifest digest.
13. Evaluation and agent services are disabled in RELEASE.
14. Paths used by a build are resolved independently of the caller's current
    directory.
15. The build can explain why a layer is stale.

## 22. V1 acceptance scenarios

The first version is considered usable when the following scenarios work.

### 22.1 Clean default build

From a clean clone with documented host prerequisites:

1. resolve locks;
2. obtain/build L01;
3. obtain/build L02;
4. apply L03;
5. load L04;
6. build CLI and GUI L05/L06 artifacts;
7. run smoke tests;
8. produce L07 DEV;
9. inspect all manifests through CLI.

### 22.2 GT patch rebuild

After changing a file in the configured L03 GT worktree:

- L01 and L02 remain reusable;
- L03 receives a new expected build key;
- L04-L07 become stale;
- building L06 GUI rebuilds the required chain;
- the resulting manifest identifies the dirty tree or new commit.

### 22.3 Project source rebuild

After changing project source:

- the change is loaded from the configured project worktree;
- L06 and L07 become stale under the target fine-grained model;
- V1 MAY conservatively rebuild from L04 or L05 if declared;
- the CLI explains the chosen invalidation reason.

### 22.4 Dependency fork

A new context selects a local dependency fork/worktree:

- the default context remains untouched;
- the alternative L04 artifact has a different build key;
- downstream artifacts are stored separately;
- both contexts can be run simultaneously;
- manifests identify the dependency override.

### 22.5 Resumable GUI work

A GUI run is opened from L06:

- the canonical image is not changed;
- code and object state are modified;
- the run is saved as L06-tmp;
- the snapshot records its L06 parent;
- rebuilding L07 ignores the snapshot;
- selected code can later be promoted to the project worktree.

### 22.6 Failed build recovery

A layer build is made to fail:

- the previous successful artifact remains available;
- the failed attempt has logs and a temporary manifest;
- downstream publication does not occur;
- rerunning after the fix succeeds without manual cleanup of canonical output.

### 22.7 Concurrent contexts

Two contexts build or run different alternatives:

- no shared mutable image is used;
- no worktree is modified by the other context;
- logs and ports do not collide;
- successful artifacts remain independently addressable.

## 23. Recommended implementation order

### Phase 1 — filesystem and manifest skeleton

Implement:

- generated directory layout;
- context loading;
- manifest schema;
- build-attempt directories;
- artifact publication;
- checksum utilities;
- CLI JSON output conventions.

No Smalltalk image mutation is required yet.

### Phase 2 — L01/L02 acquisition

Implement:

- pinned GT distribution download;
- checksum verification;
- separation of runtime and base image;
- headless startup smoke test;
- L01/L02 manifests.

### Phase 3 — canonical image builder

Implement:

- parent image copying/reflinking;
- headless Smalltalk script execution;
- image save and shutdown;
- test execution;
- atomic publication;
- run-image creation.

### Phase 4 — L03 GT patches

Implement:

- explicit GT worktree mapping;
- clean/dirty source recording;
- patch loading;
- L03 contract tests;
- downstream invalidation.

### Phase 5 — L04 dependencies

Implement:

- ordered dependency configuration;
- Git/archive lock entries;
- Smalltalk dependency loading;
- host dependency hooks;
- dependency manifest generation.

### Phase 6 — L05/L06 profiles

Implement:

- CLI and GUI profile setup;
- project worktree loading;
- package-to-worktree mapping;
- project tests;
- run and eval commands.

### Phase 7 — snapshots and promotion

Implement:

- run metadata;
- L06-tmp snapshot creation;
- package-level dirty detection;
- explicit source export/promotion;
- safe GUI close workflow.

### Phase 8 — L07 DEV distribution

Implement:

- CLI startup entry point;
- DEV distribution bundle;
- launcher;
- distribution manifest;
- packaging smoke tests.

### Phase 9 — worktree contexts

Implement or harden:

- context creation;
- Git worktree management;
- dependency fork override;
- concurrent context isolation;
- artifact garbage collection.

## 24. Explicit TODO register

The implementation SHOULD maintain this section or a machine-readable equivalent.

### Provenance and source ownership

- TODO: method- and class-level provenance.
- TODO: automatic extension-method inventory.
- TODO: explicit override/patch collection model.
- TODO: automatic destination-layer suggestion.
- TODO: repository-aware code browser and driller views.

### Build graph

- TODO: replace conservative invalidation with exact per-layer path inputs.
- TODO: first-class DAG and variant graph.
- TODO: cross-context artifact sharing based on compatible build keys.
- TODO: remote/distributed builders.

### Dependencies

- TODO: dependency DAG and cycle diagnostics.
- TODO: offline locked builds.
- TODO: Python/Ruby/toolchain adapters.
- TODO: transitive host-library inventory.

### Images and state

- TODO: byte-level reproducibility investigation.
- TODO: image normalization.
- TODO: selective snapshot state.
- TODO: image-side dirty code diff.
- TODO: crash-resilient snapshot recovery.

### Profiles and agents

- TODO: stable AGENTIC protocol.
- TODO: authenticated IPC.
- TODO: one canonical image with multiple launch profiles.
- TODO: machine-readable live image inventory.

### Distribution

- TODO: RELEASE cleanup policy.
- TODO: development-tool stripping.
- TODO: signing and attestations.
- TODO: installers and release publication.

### User interface

- TODO: GT frontend for contexts, layers, manifests, stale state, and builds.
- TODO: graphical provenance browser.
- TODO: snapshot manager.
- TODO: build-log views and failure drill-down.

## 25. Open design decisions

The following decisions should be made during implementation and then recorded
here.

1. Exact manifest representation inside the image.
2. Hash algorithm and canonical JSON encoding.
3. Whether required tests are part of the artifact build key or separately keyed.
4. Exact artifact path and publication format.
5. Whether lock files are committed per context or generated locally by default.
6. How GT release archives map to exact source commits.
7. Which project paths affect L04, L05, L06, and L07 in V1.
8. How package-to-repository mappings are extracted from Iceberg and persisted.
9. Whether run images use reflinks, hard copies, or configurable strategies.
10. How GUI startup completion is detected reliably.
11. Which process/port registry mechanism is used.
12. How host dependencies are installed without leaking across contexts.
13. Exact clean/dirty rules for DEV and RELEASE.
14. How old artifacts and snapshots are retained.
15. Whether `just` invokes shell, Python, Smalltalk, or a small dedicated build
    coordinator for graph logic.

## 26. Design summary

KlibGen-GT uses Pharo/GToolkit as a live development environment while placing
reproducible construction under an explicit external build model.

The authoritative state is:

```text
source repositories
+ worktrees
+ configuration
+ locks
+ scripts
+ manifests
```

Reusable images are immutable outputs of that state.

Writable images are isolated run copies. Saved development images are resumable
snapshots, not canonical build inputs.

Every layer can be replaced or patched through a named build context. V1 uses
Git worktrees and context-specific artifact directories to isolate alternatives.
Changing a layer changes its build key and automatically invalidates downstream
artifacts.

The first version favors explicitness and conservative rebuilding over hidden
state and fragile incremental cleverness. More precise provenance, richer
variant graphs, automatic promotion, namespace-like facilities, and deeper GT
integration are deferred until the basic source/image/build contract is working
reliably.
