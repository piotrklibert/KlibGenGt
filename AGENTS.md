# Agent Notes

This is a Glamorous Toolkit / Pharo Smalltalk project.

- Use `just` for project operations.
- Do not edit or commit files under `./vendor/` and `./private/`.
- Use `./tmp/` instead of `/tmp` for any temporary files; never track `./tmp/`
  in VCS.
- Local GT source builds and local GT patch branches live under ignored
  `vendor/gt-build/`.
- Do not commit images, changes files, caches, logs, or generated artifacts.
- Source changes go under `src/`; GT/Iceberg edits use the ignored nested Git
  repository in `export/`.
- Run `just push-src-to-export` before opening GT after filesystem edits.
- Run `just pull-export-to-src` after saving GUI/Iceberg changes that should
  become JJ-versioned source.
- Lepiter docs go under `lepiter/`.
- Use `just test` before finishing changes.
- Use `just eval "Smalltalk expression"` for quick checks.
- Use `GT_RUNTIME=build-patched just smoke` to verify local GT image patches.
- Use `just gui` only when a GUI is needed.
- When checking whether a GUI window opened, source `scripts/utils.sh` and call
  `opened_windows` before and after launching the GUI.
- Do not assume image state. Final validation for each task should be done from
  a fresh GT image.
- The project must load from a clean runtime.
