# GT search-filter escape hatch

Use these filters only when `klibgen-build image code` does not express the search. They are plain Pharo objects and can be composed before materializing `contents`.

These examples are adapted from the GT Book pages “Querying with GT search filters by example” (UID `5iztl0m2zpym86t35lxj1xovw`) and “Moldable Agent Harness: Searching code” (UID `8zds593bx3ukcbxiygwnagftg`). Re-export those pages with `$search-gt-lepiter` when more context is needed.

## Common filters

```smalltalk
#assert: gtReferences
```

Find methods referencing a class:

```smalltalk
BlElement gtReferences
```

Find implementors of a selector:

```smalltalk
#childrenDo: gtImplementors
```

Find methods carrying a pragma:

```smalltalk
#gtExample gtPragmas
```

Find methods defined by a class or package:

```smalltalk
BlElement gtMethodsInClass
'GToolkit-Pharo-Coder' asPackage gtMethodsInPackage
```

Find methods by source substring or class-name pattern:

```smalltalk
'assert:description:' gtSubstringLiteralMatch
#FilterExamples gtClassMatches
```

## Composition

Intersect, unite, or negate filters:

```smalltalk
BlElement gtMethodsInClass & #assert:description: gtReferences
#childrenDo: gtReferences | #children gtReferences
(SampleClass gtReferences) not
```

Use parentheses whenever selector precedence could make the composition unclear.

## Evaluate a bounded result

Materialize and bound the result in the image rather than printing an unbounded filter:

```sh
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build image eval \
  '| methods | methods := (#assert: gtReferences) contents. methods first: (20 min: methods size)' \
  --context default --json
```

For an intersection:

```sh
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build image eval \
  '| methods | methods := (BlElement gtMethodsInClass & #assert:description: gtReferences) contents. methods first: (20 min: methods size)' \
  --context default --json
```

Treat the printed result as exploratory output. If downstream code needs fields such as class, side, selector, protocol, or package, add the search to `KGCodeSearchTool` and return those fields as structured JSON.
