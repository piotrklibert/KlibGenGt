# Agent Notes

This is a Glamorous Toolkit / Pharo Smalltalk project.

- Use `just` for project operations.

- Do not edit or commit files under `./vendor/` and `./private/`.

- Use `./tmp/` instead of `/tmp` for any temporary files; never track `./tmp/`
  in VCS.

- Local GT source builds and local GT patch branches live under ignored
  `vendor/gt-build/`.

- Do not commit images, changes files, caches, logs, or generated artifacts.

- Source changes go under `src/`. A GUI run uses its own ignored private Git
  bridge; committing `KlibGenGt-*` changes in Iceberg promotes those packages
  immediately into `src/` without creating a JJ commit.

- Review promoted GUI changes in the outer JJ working copy. The next ordinary
  `just gui` refreshes from current `@` after the current session is saved.
  `push-src-to-export` and `pull-export-to-src` are legacy compatibility
  commands for the shared ignored `export/` bridge, not the layered GUI flow.

- For Smalltalk TDD, add or edit tests in `src/*-Tests`, run `just test-fresh`,
  which pushes `src` into `export/` and runs the suite from a disposable GT
  image unpacked under `artifacts/`.
  
- Legacy post parsing work lives in `KlibGenGt-Core-LegacyHtml`. Keep the
  PetitParser2 grammar extensible: `KGHtmlParser` is the simplified HTML base,
  and legacy non-HTML constructs such as `--kod=...` belong in subclasses like
  `KGLegacyPostParser`.

- Kotlin parsing work lives in `KlibGenGt-Kotlin`. Keep the parser sample-driven:
  update `data/kotlin-samples/defined-types.fixture.json` from the committed
  `data/kotlin-samples/*.kt` files, add focused SUnit examples first, then make
  `KGKotlinParserTest>>#testSampleFilesMatchFixture` pass from a fresh image.
  The parser should extract declarations and skip function/property bodies
  structurally instead of parsing Kotlin expressions.

- Whenever adding, renaming, or removing classes in `KlibGenGt-*` packages,
  update the class comment of `KlibGenGt`. Keep it as a nested unordered list
  where every class item starts with `- {{gtClass:ClassName}}` so class names
  are clickable in GT, followed by a one-line description of the class role.
  
- Every class defined in `KlibGenGt-*` packages must have a class comment that
  documents its public API and slots. Slot entries should specify their type,
  protocol they belong to, and a short description of their role. Public/API
  method entries use `{{gtMethod:Class>>#selector}}` or `{{gtMethod:Class
  class>>#selector}}` markup plus a one-line summary after a newline. Omit
  private methods from the API list. Put longer method documentation in the
  method's initial comment instead of the class comment.
  
- Add documentation pragmas to every public method in `KlibGenGt-*` packages:
  - `<return: Type>` for the return type
  - `<arg: #argumentName type: Type>` for each argument.
  These pragmas are documentation for now; keep them accurate enough for a
  future gradual type checker. The type system will be a mixture between
  Gradualtalk and mypy. We will support `Any` as a dynamic type compatible with
  all other types. `Nothing` will be a bottom type. `nil` literal can be used as
  alias for `UndefinedObject`. We will also provide union types, and syntactic
  sugar for nullable (`(T | nil)`) types. 
  
- IMPORTANT: type syntax in both slot comments and method pragmas is literal
  symbol or literal array of the following form:
  - `#ClassName` - a single nominal type
  - `#(Type1 | Type2 | ...)` - a union of types
  - `#(Type1 (Type2 Type3))` - `#` is only needed once
  - `#(Type?)` - either a value of type or `nil`
  - `#(Type1<Type2>)` - parametric polymorphism
  - `#(Type1<Type2, Type3, ...>)` - parametric polymorphism, multiple parameters
    - parametric examples:
      - `#(Dictionary<KeyType, ValueType>)`
      - `#(Association<KeyType, ValueType>)` 
      - `#(OrderedCollection<(Number | String)>)`
      - `#(Array<(Array<String>)>)` 
    - note the need for both `<`, `>` and `(`, `)` for the nested type, if it's
      not a simple nominal type
  - `#(ArgumentType -> ReturnType)` - block type
  - `#(-> ReturnType)` - zero-argument block type
  - `#(ArgType1, ArgType2, ... -> ReturnType)` - multi-argument block type
  - `#(ArgType* -> ReturnType)` - equvalent to:
    `#((ArgType -> ReturnType) | (-> ReturnType))` - good for use with #cull:
  - NOTES:
    - a parametric type without a type parameter in angle brackets is equivalent
      to that type parameterized by `Any`
    - if you know a type of element in a collection, state it; prefer
      `Array<String>` to plain `Array`
    - in general, prefer explicit type parameters when possible to infer

- Always run `just check-type-pragmas` to use `KGCheckTypePragmas` to check the
  syntax of type annotations after adding or modifying them.
  
- Lepiter docs go under `lepiter/`.

- Use `just test` before finishing changes.

- Use `just eval "Smalltalk expression"` for quick checks.

- Use `GT_RUNTIME=build-patched just smoke` to verify local GT image patches.

- Use `just gui` only when a GUI is needed.

- When checking whether a GUI window opened, source `scripts/utils.sh` and call
  `opened_windows` before and after launching the GUI.

- Do not assume image state. Final validation for each task should be done from
  a fresh GT image.

- The project must load from a clean runtime.
