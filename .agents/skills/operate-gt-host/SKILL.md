---
name: operate-gt-host
description: Inspect, wait for, capture, focus, or close local Glamorous Toolkit windows; inspect or terminate exact local processes; and profile shell commands. Use when a task requires host-side GT GUI evidence, window lifecycle checks, process diagnostics, or wall/CPU timing outside the image.
---

# Operate the GT Host

Resolve targets with read-only inspection before taking an action. Host window operations require an X11/XWayland `DISPLAY`; unsupported environments return a clear error.

## Inspect windows

Use project shortcuts for common GT window work:

```sh
just windows '^Glamorous Toolkit$'
just screenshot '^Glamorous Toolkit$'
```

Use the complete CLI to combine selectors or request JSON:

```sh
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build host windows list \
  --title-regex '^Glamorous Toolkit$' --command-regex 'GlamorousToolkit' --json
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build host windows wait \
  --for present --title-regex '^Glamorous Toolkit$' --timeout 15 --json
```

Selectors `--id`, `--pid`, `--title-regex`, and `--command-regex` compose. Listing and waiting may return several windows; screenshot, focus, and close require exactly one match.

Capture screenshots under the ignored project temporary directory:

```sh
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build host windows screenshot \
  --id 12345 --output tmp/screenshots/gt.png --json
```

## Control windows safely

List immediately before focus or close and use the narrowest stable selector. Closing focuses the selected client, sends `Alt+F4`, and waits for it to disappear.

```sh
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build host windows focus --id 12345 --json
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build host windows close \
  --id 12345 --timeout 10 --json
```

Do not close a window unless the user's task authorizes that state change. A GUI may contain unsaved image or Lepiter work.

## Inspect and terminate processes

```sh
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build host processes list \
  --command-regex '/[G]lamorousToolkit($| .*\.image)' --json
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build host processes wait \
  --for absent --pid 12345 --timeout 10 --json
```

Termination requires an exact positive PID. Re-read that PID immediately before acting. It sends `SIGTERM` first; use `--force` only when the user explicitly authorizes forced termination and graceful shutdown has timed out.

## Profile host commands

```sh
just profile 'sleep 0.1'
env UV_CACHE_DIR=./tmp/uv-cache uv run klibgen-build host profile --json -- sleep 0.1
```

The JSON form captures stdout/stderr and reports the child exit code plus wall, user CPU, and system CPU time. The direct form preserves the exact argument vector.
