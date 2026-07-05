#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

archive="${repo_root}/vendor/gt.zip"
fresh_root="${repo_root}/artifacts/fresh-test"
unpack_dir="${fresh_root}/gt.unpack"
runtime_dir="${fresh_root}/gt"

if [[ ! -f "${archive}" ]]; then
    "${repo_root}/scripts/bootstrap-gt.sh"
fi

if [[ ! -f "${archive}" ]]; then
    echo "GT archive is missing after bootstrap: ${archive}" >&2
    exit 1
fi

rm -rf "${fresh_root}"
mkdir -p "${unpack_dir}"

unzip -q "${archive}" -d "${unpack_dir}"

if [[ -x "${unpack_dir}/bin/GlamorousToolkit-cli" ]]; then
    mv "${unpack_dir}" "${runtime_dir}"
else
    top_level_dirs=("${unpack_dir}"/*)
    if [[ ${#top_level_dirs[@]} -eq 1 && -x "${top_level_dirs[0]}/bin/GlamorousToolkit-cli" ]]; then
        mv "${top_level_dirs[0]}" "${runtime_dir}"
        rmdir "${unpack_dir}"
    else
        echo "Could not find bin/GlamorousToolkit-cli in the unpacked archive." >&2
        exit 1
    fi
fi

cd "${repo_root}"

mkdir -p "${fresh_root}/home" "${fresh_root}/config" "${fresh_root}/cache"
export HOME="${fresh_root}/home"
export XDG_CONFIG_HOME="${fresh_root}/config"
export XDG_CACHE_HOME="${fresh_root}/cache"

exec "${runtime_dir}/bin/GlamorousToolkit-cli" \
    "${runtime_dir}/GlamorousToolkit.image" \
    st "${repo_root}/scripts/test.st"
