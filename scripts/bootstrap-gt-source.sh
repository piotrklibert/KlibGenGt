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

build_root="$(shared_vendor_root "${repo_root}")/gt-build"
sources_root="${build_root}/sources"
workspaces_root="${build_root}/workspaces"
sources_dir="${sources_root}/${mode}"
workspace="${workspaces_root}/${mode}"
launcher="${workspace}/bin/GlamorousToolkit"
cli_launcher="${workspace}/bin/GlamorousToolkit-cli"
image="${workspace}/GlamorousToolkit.image"
installer="${build_root}/tools/gt-installer"
source_version="${GT_SOURCE_VERSION:-}"

if [[ -x "${launcher}" && -x "${cli_launcher}" && -f "${image}" ]]; then
    echo "Source-built GT ${mode} runtime already exists at ${workspace}."
    exit 0
fi

"${repo_root}/scripts/bootstrap-gt-installer.sh"

mkdir -p "${sources_root}" "${workspaces_root}"

if [[ "${mode}" == "patched" ]]; then
    clean_sources="${sources_root}/clean"
    if [[ ! -d "${clean_sources}" || -z "$(find "${clean_sources}" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        echo "Clean GT sources are missing; building clean GT first."
        "${repo_root}/scripts/bootstrap-gt-source.sh" clean
    fi

    if [[ ! -d "${sources_dir}" || -z "$(find "${sources_dir}" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        echo "Seeding patched GT sources from clean sources."
        rm -rf "${sources_dir}"
        mkdir -p "${sources_dir}"
        cp -a "${clean_sources}/." "${sources_dir}/"
    fi

    "${repo_root}/scripts/patch-gt-headless-webview-source.sh" "${sources_dir}"
else
    mkdir -p "${sources_dir}"
fi

echo "Building ${mode} GT runtime in ${workspace}"
build_args=(
    --verbose
    --workspace "${workspace}"
    local-build
)

if [[ -n "${source_version}" ]]; then
    build_args+=(--version "${source_version}")
fi

build_args+=(
    --app-version latest-release
    --loader cloner
    --iceberg-location "${sources_dir}"
    --no-gt-world
    --overwrite
)

"${installer}" "${build_args[@]}"

if [[ ! -x "${launcher}" || ! -x "${cli_launcher}" || ! -f "${image}" ]]; then
    echo "GT source build finished, but expected runtime files are missing in ${workspace}." >&2
    exit 1
fi

if [[ "${mode}" == "patched" ]]; then
    echo "Applying headless WebView startup patch to patched GT image."
    mkdir -p "${repo_root}/gt-local/build-patched/home" "${repo_root}/gt-local/build-patched/config" "${repo_root}/gt-local/build-patched/cache"
    HOME="${repo_root}/gt-local/build-patched/home" \
    XDG_CONFIG_HOME="${repo_root}/gt-local/build-patched/config" \
    XDG_CACHE_HOME="${repo_root}/gt-local/build-patched/cache" \
        "${cli_launcher}" "${image}" st "${repo_root}/scripts/patch-gt-headless-webview.st"
fi

echo "Source-built GT ${mode} runtime is ready at ${workspace}."
