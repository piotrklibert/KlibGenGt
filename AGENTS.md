# Agent Notes

This is a Glamorous Toolkit / Pharo Smalltalk project.

- Use `just` for project operations.

- Do not edit or commit files under `./vendor/` and `./private/`.

- Use `./tmp/` instead of `/tmp` for any temporary files; never track `./tmp/`
  in VCS.

- Local GT source builds and local GT patch branches live under ignored
  `vendor/gt-build/`.

- Do not commit images, changes files, caches, logs, or generated artifacts.

- Source changes go under `src/`; GT/Iceberg edits use the ignored nested Git
  repository in `export/`.

- Run `just push-src-to-export` before opening GT after filesystem edits.

- `just push-src-to-export` commits the ignored `export/` Git repository,
  because Metacello `gitlocal://` loads committed Git contents rather than the
  export working tree.

- Run `just pull-export-to-src` after saving GUI/Iceberg changes that should
  become JJ-versioned source. Ask the user what do to if `export/` contain
  changes not pulled into `src/`.

- For Smalltalk TDD, add or edit tests in `src/*-Tests`, run `just test-fresh`,
  which pushes `src` into `export/` and runs the suite from a disposable GT
  image unpacked under `artifacts/`.
  
- Legacy post parsing work lives in `KlibGenGt-Core-LegacyHtml`. Keep the
  PetitParser2 grammar extensible: `KGHtmlParser` is the simplified HTML base,
  and legacy non-HTML constructs such as `--kod=...` belong in subclasses like
  `KGLegacyPostParser`.

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
  future gradual type checker.
  
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
