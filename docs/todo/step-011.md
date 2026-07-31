# Step 011: L07 DEV distribution

## TODO

- [ ] Build L07 DEV only from canonical L06 CLI.
- [ ] Publish launcher, image bundle, manifest, version data, and checksums.
- [ ] Add startup and packaging smoke tests.
- [ ] Add a non-production RELEASE placeholder with strict source/override rejection.

## Acceptance

The DEV bundle runs outside its attempt directory and cannot be built from a
snapshot; all project and fresh tests pass.

## Rollback

Distribution output is ignored; abandon the change.
