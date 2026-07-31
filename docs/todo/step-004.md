# Step 004: L01/L02 acquisition

## TODO

- [x] Publish an L01 runtime inventory from the pinned GT archive.
- [x] Publish downloaded and source-clean L02 image bundles.
- [x] Generate manifests, checksums, version metadata, and startup logs.
- [x] Test launcher/plugin availability, evaluation, GT packages, and absence of project packages.
- [x] Retain bootstrap recipes as compatibility wrappers.

## Acceptance

Both L02 variants satisfy the common contract from empty generated state and
all legacy/fresh tests pass.

## Rollback

Compatibility wrappers remain usable; abandon the change and delete ignored artifacts.
