#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PLUGIN_ROOT="${XLUA_PLUGIN_ROOT:-${WORKSPACE_ROOT}/xlua}"
IMAGE="${LINUX_BUILD_IMAGE:-docker.io/library/ubuntu:22.04}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-}"
PODMAN_MACHINE="${PODMAN_MACHINE:-podman-machine-default}"
XLUA_BUILD_ROOT="${XLUA_BUILD_ROOT:-${HOME}/dev/xlua}"

if [[ ! -f "${PLUGIN_ROOT}/jenkins/build.sh" ]]; then
	echo "Cannot find xlua plugin repo at ${PLUGIN_ROOT}. Set XLUA_PLUGIN_ROOT to override." >&2
	exit 1
fi

if [[ -z "${CONTAINER_RUNTIME}" ]]; then
	if command -v podman >/dev/null 2>&1; then
		if ! podman info >/dev/null 2>&1; then
			if podman machine inspect "${PODMAN_MACHINE}" >/dev/null 2>&1; then
				echo "Starting Podman machine ${PODMAN_MACHINE}..." >&2
				podman machine start "${PODMAN_MACHINE}" >/dev/null
			else
				echo "Starting default Podman machine..." >&2
				podman machine start >/dev/null
			fi
		fi

		if podman info >/dev/null 2>&1; then
			CONTAINER_RUNTIME="podman"
		fi
	fi

	if [[ -z "${CONTAINER_RUNTIME}" ]] && command -v docker >/dev/null 2>&1; then
		if docker info >/dev/null 2>&1; then
			CONTAINER_RUNTIME="docker"
		fi
	fi
fi

if [[ -z "${CONTAINER_RUNTIME}" ]]; then
	echo "No working container runtime found. Podman is unreachable and Docker is unavailable." >&2
	exit 1
fi

if ! command -v "${CONTAINER_RUNTIME}" >/dev/null 2>&1; then
	echo "Container runtime '${CONTAINER_RUNTIME}' is not installed." >&2
	exit 1
fi

PLATFORM_ARGS=()
HOST_ARCH="$(uname -m)"
if [[ "${HOST_ARCH}" == "arm64" || "${HOST_ARCH}" == "aarch64" ]]; then
	PLATFORM_ARGS=(--platform=linux/amd64)
fi

BUILD_CMD=$(cat <<'EOF'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y build-essential cmake ninja-build pkg-config
export PLATFORM=LIN
./jenkins/build.sh
EOF
)

cd "${PLUGIN_ROOT}"
mkdir -p "${XLUA_BUILD_ROOT}"
echo "Running Linux build inside ${IMAGE} via ${CONTAINER_RUNTIME} (build root: ${XLUA_BUILD_ROOT})..."
"${CONTAINER_RUNTIME}" run --rm \
	"${PLATFORM_ARGS[@]}" \
	-v "${PLUGIN_ROOT}:/work" \
	-v "${XLUA_BUILD_ROOT}:${XLUA_BUILD_ROOT}" \
	-e "XLUA_BUILD_ROOT=${XLUA_BUILD_ROOT}" \
	-w /work \
	"${IMAGE}" \
	bash -c "${BUILD_CMD}"
