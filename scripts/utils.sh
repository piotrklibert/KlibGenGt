#!/usr/bin/env bash

shared_vendor_root() {
    local repo_root="$1"
    if [[ -n "${KLIBGEN_VENDOR_ROOT:-}" ]]; then
        if [[ "${KLIBGEN_VENDOR_ROOT}" == /* ]]; then
            printf '%s\n' "${KLIBGEN_VENDOR_ROOT}"
        else
            printf '%s\n' "$(cd "${repo_root}" && realpath -m "${KLIBGEN_VENDOR_ROOT}")"
        fi
        return
    fi

    local repository_pointer="${repo_root}/.jj/repo"
    if [[ -f "${repository_pointer}" ]]; then
        local repository
        repository="$(tr -d '\r\n' < "${repository_pointer}")"
        if [[ -n "${repository}" ]]; then
            if [[ "${repository}" != /* ]]; then
                repository="$(cd "$(dirname "${repository_pointer}")" && realpath -m "${repository}")"
            fi
            local primary_root
            primary_root="$(dirname "$(dirname "${repository}")")"
            if [[ "$(basename "${repository}")" == "repo" && "$(basename "$(dirname "${repository}")")" == ".jj" && -f "${primary_root}/justfile" && -d "${primary_root}/src" ]]; then
                printf '%s\n' "${primary_root}/vendor"
                return
            fi
        fi
    fi
    printf '%s\n' "${repo_root}/vendor"
}

opened_windows() {
    xdotool search --onlyvisible --name '.*' 2>/dev/null |
        while IFS= read -r window_id; do
            window_name="$(xdotool getwindowname "${window_id}" 2>/dev/null || true)"
            printf '%s %s\n' "${window_id}" "${window_name}"
        done
}
