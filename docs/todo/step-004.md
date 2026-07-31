# Step 004: L01/L02 acquisition

## TODO

- [ ] Publish an L01 runtime inventory from the pinned GT archive.
- [ ] Publish downloaded and source-clean L02 image bundles.
- [ ] Generate manifests, checksums, version metadata, and startup logs.
- [ ] Test launcher/plugin availability, evaluation, GT packages, and absence of project packages.
- [ ] Retain bootstrap recipes as compatibility wrappers.

## Acceptance

Both L02 variants satisfy the common contract from empty generated state and
all legacy/fresh tests pass.

## Rollback

Compatibility wrappers remain usable; abandon the change and delete ignored artifacts.
