# Stage 01A — recipe resolution

## 1. Goal and non-goals

Define immutable construction values and deterministic resolved keys. This stage
does not build or publish artifacts.

## 2. Prerequisites and starting state

Stage 00 path and schema conventions apply. Committed v0.1 locks provide exact
archive/Git inputs during migration.

## 3. Public APIs, commands, and schemas

`Step`, `StepImplementation`, `Recipe`, `LaunchPreset`, and `Target` are public
Python values. `BASE`, `PROJECT`, and four standard targets are built in.

```text
klibgen-build v2 recipe list [--json]
klibgen-build v2 recipe resolve TARGET [--through ROLE] [--json]
```

Resolution emits `klibgen.resolved-recipe/1`, described by
`build/schemas/v2/resolved-recipe.schema.json`.

## 4. Implementation work packages

`recipes.py` owns immutable composition and validation. `resolution.py` owns
declared path, archive/Git/JJ tree, platform, environment, script, and tool
identities. Each implementation declares its own paths and protocol version.

## 5. State transitions, locking, cleanup, and failures

Resolution is read-only and creates no v0.2 state. Unknown roles, incompatible
types, non-boundary truncation, unknown locks, escaping paths, and unserializable
mutable path objects fail precisely.

## 6. Tests and acceptance scenarios

Host tests prove immutable composition, role uniqueness, compatibility, name and
preset independence, upstream preservation, downstream invalidation, exclusions,
dirty Git content identity, CLI parsing, and deterministic real-repository output.

## 7. Exit criteria and handoff evidence

`just test-build-tools` passes. All standard targets share the project recipe and
resolve one project key; the human and JSON CLI forms work against the repository.

## 8. V0.1 mechanisms retained or retired

All v0.1 commands and state remain default. The opt-in parser is the sole
production integration point.
