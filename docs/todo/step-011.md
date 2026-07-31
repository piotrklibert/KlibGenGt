# Step 011: L07 DEV distribution

## TODO

- [x] Build L07 DEV only from canonical L06 CLI.
- [x] Publish launcher, image bundle, manifest, version data, and checksums.
- [x] Add startup and packaging smoke tests.
- [x] Add a non-production RELEASE placeholder that rejects all builds.

## Acceptance

The DEV bundle runs outside its attempt directory and cannot be built from a
snapshot; all project and fresh tests pass.

## Rollback

Distribution output is ignored; abandon the change.
