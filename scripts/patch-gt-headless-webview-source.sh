#!/usr/bin/env bash
set -euo pipefail

sources_dir="${1:-}"

if [[ -z "${sources_dir}" ]]; then
    echo "Usage: $0 /path/to/gt/iceberg/sources" >&2
    exit 2
fi

if [[ ! -d "${sources_dir}" ]]; then
    echo "GT source directory does not exist: ${sources_dir}" >&2
    exit 1
fi

webview_file="$(find "${sources_dir}" -path '*/src/GToolkit-WebView/GtWebViewLibrary.class.st' -print -quit)"

if [[ -z "${webview_file}" ]]; then
    echo "Could not find GtWebViewLibrary.class.st under ${sources_dir}." >&2
    exit 1
fi

if grep -q 'Smalltalk isHeadless not' "${webview_file}"; then
    echo "Headless WebView startup patch is already present in ${webview_file}."
    exit 0
fi

old_method="$(cat <<'METHOD'
{ #category : #'system startup' }
GtWebViewLibrary class >> startUp: isANewSession [
	(isANewSession and: [ self hasModule ])
		ifTrue: [
			self initEnvLogger.
			self initGtk ]
]
METHOD
)"

new_method="$(cat <<'METHOD'
{ #category : #'system startup' }
GtWebViewLibrary class >> startUp: isANewSession [
	(isANewSession
		and: [ Smalltalk isHeadless not
		and: [ self hasModule ] ])
		ifTrue: [
			self initEnvLogger.
			self initGtk ]
]
METHOD
)"

if ! OLD_METHOD="${old_method}" NEW_METHOD="${new_method}" perl -0pi -e '
    BEGIN {
        $old = $ENV{"OLD_METHOD"};
        $new = $ENV{"NEW_METHOD"};
    }
    $count += s/\Q$old\E/$new/g;
    END {
        exit($count == 1 ? 0 : 2);
    }
' "${webview_file}"; then
    echo "Could not apply headless WebView startup patch to ${webview_file}." >&2
    echo "The method may have changed upstream; inspect GtWebViewLibrary class>>startUp:." >&2
    exit 1
fi

echo "Applied headless WebView startup patch to ${webview_file}."
