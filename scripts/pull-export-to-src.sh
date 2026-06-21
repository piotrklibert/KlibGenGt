#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
src_dir="${repo_root}/src"
export_dir="${repo_root}/export"
export_src_dir="${export_dir}/src"

if [[ ! -d "${export_dir}/.git" ]]; then
    echo "Export directory is not a Git repository: ${export_dir}" >&2
    exit 1
fi

if [[ ! -d "${export_src_dir}" ]]; then
    echo "Export source directory is missing: ${export_src_dir}" >&2
    exit 1
fi

if [[ ! -f "${export_dir}/.project" ]]; then
    echo "Export repository is missing .project: ${export_dir}/.project" >&2
    exit 1
fi

if [[ ! -d "${src_dir}" ]]; then
    echo "Source directory is missing: ${src_dir}" >&2
    exit 1
fi

rsync -a --delete "${export_src_dir}/" "${src_dir}/"

echo "Copied export/src/ to src/."
git -C "${export_dir}" status --short
