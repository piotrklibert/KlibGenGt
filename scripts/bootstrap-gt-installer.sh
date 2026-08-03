#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
source "${script_dir}/utils.sh"

tools_dir="$(shared_vendor_root "${repo_root}")/gt-build/tools"
installer="${tools_dir}/gt-installer"
url_file="${repo_root}/.tool-versions-or-lock/gt-installer-linux-x86_64.url"
sha_file="${repo_root}/.tool-versions-or-lock/gt-installer-linux-x86_64.sha256"

url="$(tr -d '[:space:]' < "${url_file}")"
checksum="$(tr -d '[:space:]' < "${sha_file}")"

if [[ -z "${url}" || "${url}" == *PLACEHOLDER* || ! "${url}" =~ ^https?:// ]]; then
    echo "GT installer URL is missing or still a placeholder in ${url_file}." >&2
    exit 1
fi

if [[ ! "${checksum}" =~ ^[0-9a-fA-F]{64}$ ]]; then
    echo "GT installer SHA256 checksum is missing or still a placeholder in ${sha_file}." >&2
    exit 1
fi

if [[ -x "${installer}" ]] && printf '%s  %s\n' "${checksum}" "${installer}" | sha256sum -c --status -; then
    echo "GT installer already exists at ${installer}."
    exit 0
fi

mkdir -p "${tools_dir}"
tmp_installer="${installer}.tmp"
rm -f "${tmp_installer}"

echo "Downloading GT installer from ${url}"
curl -L "${url}" -o "${tmp_installer}"

echo "Verifying ${tmp_installer}"
printf '%s  %s\n' "${checksum}" "${tmp_installer}" | sha256sum -c -

chmod +x "${tmp_installer}"
mv "${tmp_installer}" "${installer}"

echo "GT installer is ready at ${installer}."
