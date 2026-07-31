# Step 002: coordinator and state skeleton

## TODO

- [x] Add the uv-managed Python coordinator behind `just`.
- [x] Add context, lock, manifest, and summary schemas under `build/`.
- [x] Add the committed default context and seven stable layer definitions.
- [x] Add ignored `.klibgen/` state layout.
- [x] Implement human and JSON `doctor` and `status` commands.
- [x] Test canonical JSON, SHA-256 keys, schema checks, and path independence.

## Acceptance

Legacy commands remain unchanged; coordinator unit tests, `just doctor`,
`just status-json`, `just test`, and isolated fresh testing pass.

## Rollback

Abandon this JJ change and remove ignored `.klibgen/` state.
