#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
source "${script_dir}/utils.sh"

vendor_dir="$(shared_vendor_root "${repo_root}")"
runtime_dir="${vendor_dir}/gt"
archive="${vendor_dir}/gt.zip"
launcher="${runtime_dir}/bin/GlamorousToolkit"
version_marker="${runtime_dir}/.klibgen-gt-version"
version_file="${repo_root}/.tool-versions-or-lock/gt-version"
url_file="${repo_root}/.tool-versions-or-lock/gt-linux-x86_64.url"
sha_file="${repo_root}/.tool-versions-or-lock/gt-linux-x86_64.sha256"

version="$(tr -d '[:space:]' < "${version_file}")"
runtime_id="${version}:gui-interactive-loader-v1"
url="$(tr -d '[:space:]' < "${url_file}")"
checksum="$(tr -d '[:space:]' < "${sha_file}")"

if [[ -x "${launcher}" && -f "${version_marker}" && "$(tr -d '[:space:]' < "${version_marker}")" == "${runtime_id}" ]]; then
    echo "Glamorous Toolkit runtime already exists at ${runtime_dir}."
    exit 0
fi

if [[ -x "${launcher}" ]]; then
    echo "Existing GT runtime does not match pinned version ${version}; reinstalling ${runtime_dir}."
fi

if [[ -z "${url}" || "${url}" == *PLACEHOLDER* || ! "${url}" =~ ^https?:// ]]; then
    echo "GT download URL is missing or still a placeholder in ${url_file}." >&2
    echo "Fill it with a Linux x86_64 Glamorous Toolkit zip URL." >&2
    exit 1
fi

if [[ ! "${checksum}" =~ ^[0-9a-fA-F]{64}$ ]]; then
    echo "GT SHA256 checksum is missing or still a placeholder in ${sha_file}." >&2
    echo "Fill it with the SHA256 value from the matching GT download page." >&2
    exit 1
fi

mkdir -p "${vendor_dir}"
echo "Downloading Glamorous Toolkit from ${url}"
curl -L "${url}" -o "${archive}"

echo "Verifying ${archive}"
printf '%s  %s\n' "${checksum}" "${archive}" | sha256sum -c -

echo "Unpacking Glamorous Toolkit into ${runtime_dir}"
rm -rf "${runtime_dir}" "${vendor_dir}/gt.unpack"
mkdir -p "${vendor_dir}/gt.unpack"
unzip -q "${archive}" -d "${vendor_dir}/gt.unpack"

if [[ -x "${vendor_dir}/gt.unpack/bin/GlamorousToolkit" ]]; then
    mv "${vendor_dir}/gt.unpack" "${runtime_dir}"
else
    top_level_dirs=("${vendor_dir}"/gt.unpack/*)
    if [[ ${#top_level_dirs[@]} -eq 1 && -x "${top_level_dirs[0]}/bin/GlamorousToolkit" ]]; then
        mv "${top_level_dirs[0]}" "${runtime_dir}"
        rmdir "${vendor_dir}/gt.unpack"
    else
        echo "Could not find bin/GlamorousToolkit in the unpacked archive." >&2
        rm -rf "${vendor_dir}/gt.unpack"
        exit 1
    fi
fi

printf '%s\n' "${runtime_id}" > "${version_marker}"
echo "Glamorous Toolkit runtime is ready at ${runtime_dir}."
