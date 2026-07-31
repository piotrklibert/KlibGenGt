# Step 002: coordinator and state skeleton

## TODO

- [ ] Add a Python-stdlib coordinator behind `just`.
- [ ] Add context, lock, manifest, and summary schemas under `build/`.
- [ ] Add the committed default context and seven stable layer definitions.
- [ ] Add ignored `.klibgen/` state layout.
- [ ] Implement human and JSON `doctor` and `status` commands.
- [ ] Test canonical JSON, SHA-256 keys, schema checks, and path independence.

## Acceptance

Legacy commands remain unchanged; coordinator unit tests, `just doctor`,
`just status-json`, `just test`, and isolated fresh testing pass.

## Rollback

Abandon this JJ change and remove ignored `.klibgen/` state.
