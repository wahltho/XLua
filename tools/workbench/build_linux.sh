#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
IMAGE="${LINUX_BUILD_IMAGE:-docker.io/library/ubuntu:22.04}"

if ! command -v podman >/dev/null 2>&1; then
	echo "podman not found. Install Podman (or set LINUX_BUILD_IMAGE to a Docker reference)." >&2
	exit 1
fi

if ! podman machine info >/dev/null 2>&1; then
	echo "Starting default Podman machine..." >&2
	podman machine start >/dev/null
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

cd "${REPO_ROOT}"
echo "Running Linux build inside ${IMAGE}..."
podman run --rm \
	-v "${REPO_ROOT}:/work" \
	-w /work \
	"${IMAGE}" \
	bash -c "${BUILD_CMD}"
