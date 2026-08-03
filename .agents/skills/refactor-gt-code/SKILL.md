---
name: refactor-gt-code
description: Discover, preview, and safely apply structural refactorings to KlibGenGt Pharo/Smalltalk code through a named staging area. Use when a task calls for renaming or moving classes, methods, instance variables, or parameters; adding or removing parameters; extracting a method; performing a repeated AST transformation; or when ordinary text edits would risk missing senders, implementors, or syntax structure. Check the supported catalog before doing a structural refactor even if direct Tonel editing looks possible.
---

# Refactor GT Code

## Overview

Use the image's Refactoring Browser APIs through the repository's bounded request interface. Preview is disposable and reports semantic changes, exact exported Tonel, warnings, staging provenance, and a content-bound plan ID; apply recomputes that plan and exports only when the expected ID still matches.

## Workflow

1. Read `AGENTS.md` and choose an existing named staging area, or create a task-specific one with `just staging-create NAME`.
2. Run `just refactor-catalog`. Run `just refactor-describe ID` for likely adapters. Never guess an adapter contract.
3. For method-sensitive work, retrieve exact current source and its SHA-256 through code search. Method extraction requires `expectedMethodHash`.
4. Write the structured JSON request under ignored `./tmp/`. Keep its scope as narrow as possible.
5. Run `just refactor-applicable NAME REQUEST` when selecting among operations, then `just refactor-preview NAME REQUEST`.
6. Inspect all semantic records, exact `tonelChanges`, impact counts, warnings, unsafe features, and staging identity. A surprising caller, class, or file means stop and narrow or revise the request.
7. If the preview reports warnings, add only the reviewed warning IDs to `acknowledgedWarnings` and preview again.
8. Apply with `just refactor-apply NAME REQUEST PLAN_ID`. The exact plan ID is mandatory; a changed source/staging generation or changed output forces a new preview.
9. Test in a fresh agentic image attached to the staging area. Promotion remains a separate explicit operation after review.

## Request Shape

Start with this envelope and fill arguments from `describe`:

```json
{
  "schema": "klibgen.refactoring-request/1",
  "refactoring": "method.rename",
  "arguments": {
    "class": "KGExample",
    "side": "instance",
    "selector": "oldName",
    "newSelector": "newName"
  },
  "limits": { "maxChanges": 100 }
}
```

The stable adapters currently cover class, method, and instance-variable renames; method move and extraction; parameter add, remove, and rename; and bounded AST rewrites. The live catalog is authoritative.

## AST Rewrites

Use `rewrite.ast` only for a genuinely structural repeated transform. Always specify `scope.methods`, `scope.classes`, or project-owned `scope.packages`; prefer exact methods. Set conservative `maxMethods`, `maxMatches`, and `maxChanges` limits.

Plain metavariable patterns are the default. AST pattern blocks execute Smalltalk during matching and therefore require explicit `"allowPatternBlocks": true`; the preview reports `ast-pattern-blocks` in `unsafeFeatures`. Review the block itself, the bounded scope, and all resulting Tonel before applying.

## Safety and Fallback

- Never use `refactor.apply` without a freshly reviewed preview and exact `planId`.
- Do not apply a preview produced for another staging identity.
- Do not treat warnings as blanket approvals; acknowledge exact IDs only.
- Do not promote automatically. Review staging and run the task's tests first.
- If the catalog does not support the transformation, use the normal named-staging source workflow, edit Tonel carefully, then run `just lint-source`, `just check-type-pragmas`, and fresh-image tests. Mention that no supported refactoring matched.
- Refactoring applies only to `KlibGenGt-*` packages. Do not broaden AST scope to framework or dependency packages.
