#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PLUGIN_ROOT="${XLUA_PLUGIN_ROOT:-${WORKSPACE_ROOT}/xlua}"

if [[ ! -f "${PLUGIN_ROOT}/jenkins/build.sh" ]]; then
	echo "Cannot find xlua plugin repo at ${PLUGIN_ROOT}. Set XLUA_PLUGIN_ROOT to override." >&2
	exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
	echo "xcodebuild not found. Install Xcode and accept the license first." >&2
	exit 1
fi

export PLATFORM=APL
export WANT_CODESIGN="${WANT_CODESIGN:-NO}"
export XPLANE_SDK_ROOT="${XPLANE_SDK_ROOT:-}"

if [[ -z "${XPLANE_SDK_ROOT}" ]]; then
	echo "XPLANE_SDK_ROOT is not set. Export it before running this script." >&2
	exit 1
fi

cd "${PLUGIN_ROOT}"
echo "Building macOS plugin via jenkins/build.sh (codesign: ${WANT_CODESIGN})..."
./jenkins/build.sh
