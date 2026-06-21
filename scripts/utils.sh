#!/usr/bin/env bash

opened_windows() {
    xdotool search --onlyvisible --name '.*' 2>/dev/null |
        while IFS= read -r window_id; do
            window_name="$(xdotool getwindowname "${window_id}" 2>/dev/null || true)"
            printf '%s %s\n' "${window_id}" "${window_name}"
        done
}
