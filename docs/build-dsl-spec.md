- what are our answers to the following workflows:

  1. Adding an external dependency. SQlite3 is a good sample case: it requires a
     native .so (which I think isn't captured in the manifest?). Let's imagine
     that we depend on our own package that is developed concurrently and
     contains Rust-written bindings to an external .so and src/ with Smalltalk
     code... How do we add this dependency, including checkout, building, and
     possible OS-wide package installation?

  2. Updating the GT version. 

## What SQLite means today

  The SQLite integration currently works like this:

  locked Pharo-SQLite3 commit
          ↓
  pre-existing checkout under vendor/gt-build
          ↓
  Metacello loads Core into the GT image
          ↓
  dependency contract calls the system SQLite .so
          ↓
  image checkpoint is published
          ↓
  project source and its SUnit tests are loaded

  Specifically:

  - The Pharo-SQLite3 repository and exact commit are recorded in build/locks/default.lock.json:20.
  - The project-dependencies recipe step includes that lock as key material in python/klibgen_build/recipes.py:270.
  - The builder expects an already-existing checkout at vendor/gt-build/dependencies/sqlite3 and verifies only that its HEAD is the locked commit in python/klibgen_build/canonical.py:97. It does not clone it.
  - Metacello loads the Core group from that checkout in build/v2/scripts/load-project-dependencies.st:1.
  - The dependency contract checks that the classes exist, asks the native library for its version, and opens an in-memory database in build/v2/tests/project-dependencies-contract.st:1.
  - The next step, project-setup, is the actual artifact checkpoint. Thus a dependency failure prevents publication.
  - The final project build runs the whole project test suite via build/v2/tests/project-contract.st:1, including the SQLite examples.

  Your suspicion about the .so is correct. The resolved recipe captures the Pharo-SQLite3 source lock, but not the SQLite native library. On this machine:

  libraryPath    /usr/lib64/libsqlite3.so.0
  libraryVersion 3.47.2

  The canonical artifact contains the image and a symlink to the local vendor/gt runtime. It does not contain libsqlite3.so.0. So the existing contract proves:

  > This image can use SQLite on the machine performing the build.

  It does not prove:

  > This artifact carries the tested SQLite binary and can use it on another machine.

  I also ran KGSQLite3ExamplesTest>>testLibraryDiagnostics against the current canonical artifact; it passed.

  ## Your Rust-backed dependency

  Suppose our-bindings contains:

  Cargo.toml
  Cargo.lock
  rust-src/
  src/                 # Tonel Smalltalk packages

  and produces libour_bindings.so, which itself uses another external .so.

  The current recipe abstraction can represent such a transformation, but the implementation cannot do it without extension. A robust dependency step would need to:

  1. Resolve the dependency source.

     For released builds, lock a Git commit. For concurrent development, resolve a local worktree including dirty file contents—not just HEAD.

  2. Acquire the source.

     Clone/fetch the locked commit into an immutable source cache. Today SQLite requires this cache to have been populated manually.

  3. Provision or verify build prerequisites.

     Check the Rust toolchain, target triple, C compiler/linker, pkg-config, headers, and external ABI. Their identities must enter the step key.

  4. Run the native build.

     For example, run cargo build --locked --release, preferably with a controlled target directory and explicit target triple.

  5. Collect native outputs.

     Copy libour_bindings.so and every non-system runtime library it needs into something like:

     payload/native/linux-x86_64/

     Prefer an $ORIGIN-relative RUNPATH so the binding does not depend on checkout paths.

  6. Load the Smalltalk source.

     Load the dependency’s baseline from the same resolved checkout, then configure its FFI library resolver to use the artifact’s native directory.

  7. Emit dependency provenance.

     Record source identity, Cargo lock digest, toolchain, target, build command/implementation version, output hashes, and external library identities.

  8. Run a dependency contract before publishing the checkpoint.

  At session materialization time, payload/native would need to be linked or copied into the disposable session and exposed through a stable path. Currently sessions copy only the image while invoking the runtime
  through the artifact, so this native presentation mechanism does not yet exist.

  ## Concurrent local development

  The resolver already has an internal gitWorktree identity facility that can include dirty content. However, the public recipes are hard-coded, and there is no supported CLI workflow for replacing SQLite—or
  another dependency—with a local worktree. This is explicitly identified as a current gap in docs/current-build-model-gaps-and-priorities.md:67.

  The desirable interface would be conceptually:

  default dependency:
    source = locked Git commit

  local development override:
    source = ../our-bindings
    identity = commit + dirty content digest
    publishRef = experimental/native-bindings

  That would give concurrent development fast invalidation:

  - Smalltalk-only change → reload dependency image layer.
  - Rust source or Cargo.lock change → rebuild native library and descendants.
  - Main project source change → reuse the dependency checkpoint.
  - Unchanged effective trees → reuse all relevant artifacts.

  The local override should publish to a separate reference so experiments do not advance default-project.

  ## OS-wide package installation

  OS-wide installation does not fit safely inside the current artifact model. Running apt install or equivalent during an image build changes the host outside the content-addressed artifact, may require
  privilege, and cannot be undone or reconstructed from the artifact.

  There are three reasonable policies:

  1. Bundled native dependencies — preferred for distribution

     Build or copy the required .so files into the artifact. Treat normal glibc/platform libraries as the only external ABI.

  2. Container/environment artifact

     Install packages into a pinned OCI image, Nix closure, or comparable environment. The environment digest becomes the runtime input. The present Dockerfile is not integrated with the v2 artifact graph.

  3. Host prerequisite

     Declare package/library requirements, make doctor verify them, and fail with an installation instruction. Record the discovered library path/version in provenance. This is workable for development, but the
     resulting image artifact is explicitly host-dependent.

  I would keep package installation as a separate provisioning action. The build should verify requirements, not silently mutate the OS.

  ## Testing the complete result

  A suitable test pyramid would be:

  1. Native build contract

     Verify expected .so files exist, output hashes match the native manifest, RUNPATH is relocatable, and no undeclared libraries appear in DT_NEEDED.

  2. Dependency-image contract

     Before publishing the dependency checkpoint:
      - assert binding classes exist;
      - load the bundled library by its artifact-relative path;
      - call a version/ABI function;
      - exercise one real operation;
      - assert the project itself is not loaded yet.

  3. Final project contract

     Load project source on top of that checkpoint and run project tests that exercise the binding end-to-end. This corresponds to the existing SQLite SUnit coverage.

  4. Artifact membership verification

     Check that the native manifest and .so files are inside the published payload and hash their contents. Current ArtifactStore.verify() only validates filenames and sizes, not file content; see python/
     klibgen_build/store.py:35.

  5. Clean environment test

     Build using an isolated state root:

     KLIBGEN_STATE_ROOT=tmp/native-proof just build cli
     KLIBGEN_STATE_ROOT=tmp/native-proof just test-fresh

     Then run the resulting artifact in a minimal container with no dependency checkout and, for bundled mode, no OS-wide copy of the external library. That is the decisive portability test.

  So the underlying linear checkpoint model is a good fit, but the generic dependency protocol envisioned in docs/ARCHITECTURE.md:167 remains largely a design rather than an implementation. SQLite is currently a
  useful hard-coded prototype of the Smalltalk-loading and runtime-contract portions; source acquisition, Rust compilation, native payloads, host provisioning, local overrides, and strong artifact verification
  are the missing pieces.

