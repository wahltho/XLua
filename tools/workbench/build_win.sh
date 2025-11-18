#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if ! command -v prlctl >/dev/null 2>&1; then
	echo "prlctl not found. Install Parallels CLI tools before running this script." >&2
	exit 1
fi

if [[ -z "${PARALLELS_VM:-}" ]]; then
	echo "Set PARALLELS_VM to the name of your Parallels VM (e.g. PARALLELS_VM='Windows 11')." >&2
	exit 1
fi

if [[ -z "${WIN_REPO_PATH:-}" ]]; then
	echo "Set WIN_REPO_PATH to the path of this repo inside the VM (e.g. WIN_REPO_PATH='\\\\Mac\\Home\\Documents\\Projects\\xlua\\xlua')." >&2
	exit 1
fi

MSBUILD_PATH="${MSBUILD_PATH:-C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\MSBuild\\Current\\Bin\\MSBuild.exe}"

ps_quote() {
	local str="${1//\'/\'\'}"
	printf "'%s'" "$str"
}

MSBUILD_PS=$(ps_quote "$MSBUILD_PATH")
REPO_PS=$(ps_quote "$WIN_REPO_PATH")

read -r -d '' POWERSHELL_BLOCK <<EOF || true
& {
    \$ErrorActionPreference = 'Stop'
    \$msbuild = ${MSBUILD_PS}
    \$repo = ${REPO_PS}

    if (-not (Test-Path \$msbuild)) {
        Write-Error "MSBuild not found at \$msbuild"
        exit 1
    }

    if (-not (Test-Path \$repo)) {
        Write-Error "Repository path not found: \$repo"
        exit 1
    }

    Push-Location \$repo
    & \$msbuild "xlua.vcxproj" "/m" "/p:Configuration=Release" "/p:Platform=x64"
    \$code = \$LASTEXITCODE
    Pop-Location
    exit \$code
}
EOF

echo "Building XLua in VM '${PARALLELS_VM}' (MSBuild: ${MSBUILD_PATH})..."
prlctl exec "${PARALLELS_VM}" -- powershell -NoProfile -NonInteractive -Command "$POWERSHELL_BLOCK"

WIN_OUTPUT_DIR="${REPO_ROOT}/Release/plugins/win_x64"
WIN_XPL="${WIN_OUTPUT_DIR}/xlua.xpl"
WIN_PDB="${WIN_OUTPUT_DIR}/xlua.pdb"

if [[ ! -f "${WIN_XPL}" ]]; then
	echo "Expected artifact not found at ${WIN_XPL}. Ensure the repo is shared into the VM." >&2
	exit 1
fi

mkdir -p "${REPO_ROOT}/jenkins/build_products"
cp "${WIN_XPL}" "${REPO_ROOT}/jenkins/build_products/xlua_win.xpl"
if [[ -f "${WIN_PDB}" ]]; then
	cp "${WIN_PDB}" "${REPO_ROOT}/jenkins/build_products/xlua_win.pdb"
fi

echo "Windows artifacts copied to jenkins/build_products/."
