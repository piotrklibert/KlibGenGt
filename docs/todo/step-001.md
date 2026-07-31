# Step 001: specification and JuJutsu alignment

## Objective

Make the target architecture accurately describe the mixed JuJutsu/Git workflow
and establish decision-complete stage contracts.

## TODO

- [x] Define the project root as a colocated JJ repository operated through `jj`.
- [x] Define JJ commit IDs as canonical L06 source identity.
- [x] Reserve Git for Iceberg bridges, GT sources, and Git-backed dependencies.
- [x] Define `export/` as generated transport state rather than authoritative source.
- [x] Mark the older architecture roadmap as historical.
- [x] Create `docs/todo/step-001.md` through `step-012.md`.

## Acceptance

- `rg` finds no claim that the main project uses a Git worktree.
- `just test` and `just test-fresh` pass.
- README behavior remains unchanged.

## Rollback

Abandon this JJ change; it has no generated-state migration.
