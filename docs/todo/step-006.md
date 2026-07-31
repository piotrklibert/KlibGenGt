# Step 006: L03 GT patches

## TODO

- [ ] Model `baseline` and `klibgen` L03 variants explicitly.
- [ ] Record all relevant GT Git commits and dirty paths.
- [ ] Include patch scripts and changed packages in the build key and manifest.
- [ ] Map `GT_RUNTIME=build-patched` through the L03 compatibility adapter.
- [ ] Test the headless WebView patch and downstream invalidation.

## Acceptance

Changing a declared patch changes L03 and descendant keys but not L01/L02 keys;
legacy/fresh tests pass.

## Rollback

The downloaded compatibility runtime remains available; abandon the change.
