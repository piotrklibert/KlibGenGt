# Step 012: contexts, concurrency, and retention

## TODO

- [x] Manage project alternatives with JJ workspaces.
- [x] Manage GT/dependency alternatives with Git worktrees.
- [x] Isolate artifacts, runs, logs, ports, overrides, and host state by context.
- [x] Implement pins, `clean-runs`, and manifest-aware `gc`.
- [x] Exercise every V1 acceptance scenario and document final behavior.

## Acceptance

All seven specification acceptance scenarios pass, concurrent contexts do not
share mutable state, JSON status explains staleness, and clean/fresh gates pass.

## Rollback

Named workspaces/worktrees require explicit removal; artifacts remain ignored and removable.
