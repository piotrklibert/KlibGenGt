# Agent Notes

This is a Glamorous Toolkit / Pharo Smalltalk project.

- Use `just` for project operations.
- Do not edit or commit files under `vendor/`.
- Do not commit images, changes files, caches, logs, or generated artifacts.
- Source changes go under `src/`.
- Lepiter docs go under `lepiter/`.
- Use `just test` before finishing changes.
- Use `just eval "Smalltalk expression"` for quick checks.
- Use `just gui` only when a GUI is needed.
- Do not assume image state. Final validation for each task should be done from a fresh GT image.
- The project must load from a clean runtime.
