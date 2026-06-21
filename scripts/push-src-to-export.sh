#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
src_dir="${repo_root}/src"
export_dir="${repo_root}/export"
export_src_dir="${export_dir}/src"

if [[ ! -d "${src_dir}" ]]; then
    echo "Source directory is missing: ${src_dir}" >&2
    exit 1
fi

if [[ ! -d "${export_dir}/.git" ]]; then
    echo "Export directory is not a Git repository: ${export_dir}" >&2
    exit 1
fi

if [[ ! -f "${export_dir}/.project" ]]; then
    echo "Export repository is missing .project: ${export_dir}/.project" >&2
    exit 1
fi

if [[ ! -d "${export_src_dir}" ]]; then
    echo "Export source directory is missing: ${export_src_dir}" >&2
    exit 1
fi

rsync -a --delete "${src_dir}/" "${export_src_dir}/"

echo "Copied src/ to export/src/."
git -C "${export_dir}" add src

if git -C "${export_dir}" diff --cached --quiet; then
    echo "No export Git changes to commit."
else
    git -C "${export_dir}" commit -m "Sync src to export"
fi

git -C "${export_dir}" status --short
