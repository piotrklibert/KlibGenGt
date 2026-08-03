#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
source "${script_dir}/utils.sh"
mode="${1:-}"

case "${mode}" in
    clean|patched) ;;
    *)
        echo "Usage: $0 clean|patched" >&2
        exit 2
        ;;
esac

sources_dir="$(shared_vendor_root "${repo_root}")/gt-build/sources/${mode}"

if [[ ! -d "${sources_dir}" ]]; then
    echo "GT source directory does not exist: ${sources_dir}" >&2
    echo "Run ./scripts/bootstrap-gt-source.sh ${mode} first." >&2
    exit 1
fi

found=0
while IFS= read -r git_dir; do
    repo_dir="$(dirname "${git_dir}")"
    found=1
    echo "Fetching ${repo_dir#${sources_dir}/}"
    git -C "${repo_dir}" fetch --all --prune
done < <(find "${sources_dir}" -type d -name .git -prune | sort)

if [[ "${found}" -eq 0 ]]; then
    echo "No Git repositories found under ${sources_dir}." >&2
    exit 1
fi
