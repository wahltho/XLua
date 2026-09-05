# Workbench Build Helpers

This directory contains small wrappers that mirror the Jenkins build matrix so
you can invoke the existing scripts from your workstation without repeating
setup steps. The wrappers operate on the nested plugin repo at `xlua/` by
default; set `XLUA_PLUGIN_ROOT` if your checkout lives elsewhere.

Common variables:

* `XLUA_PLUGIN_ROOT` – override the nested plugin repo path (defaults to
  `<workspace>/xlua`).
* `XLUA_BUILD_ROOT` – local build working directory (defaults to
  `~/dev/xlua`). Keep this outside iCloud-synced folders.

## macOS (`build_mac.sh`)

```
export XPLANE_SDK_ROOT="$PWD/xlua/SDK"
./tools/workbench/build_mac.sh
```

Requirements:

* Xcode installed (`xcodebuild -version` must work) and its license accepted.
* `XPLANE_SDK_ROOT` exported (the script checks for it).
* Optional `WANT_CODESIGN=YES` if you want to reuse the notarization flow from
  `jenkins/build.sh`.

## Linux (`build_linux.sh`)

```
./tools/workbench/build_linux.sh

# Force Docker if Podman is flaky:
CONTAINER_RUNTIME=docker ./tools/workbench/build_linux.sh
```

Requirements:

* Podman or Docker installed on the Mac host.
* If you use Podman, a machine initialized (`podman machine init`/`start`).
  The script prefers a working Podman setup, but falls back to Docker when
  Podman is unreachable.
* Sufficient disk space/bandwidth for the container to `apt-get install`
  `build-essential`/`cmake`/`ninja-build`/`pkg-config` the first time it runs.

The wrapper mounts the repo into `/work` inside an `ubuntu:22.04` container and
mounts `XLUA_BUILD_ROOT` at the same absolute path for generated intermediates.
It invokes `jenkins/build.sh` with `PLATFORM=LIN`. On Apple Silicon it
automatically uses `linux/amd64`.

Set `LINUX_BUILD_IMAGE` to use a different base image.
Set `CONTAINER_RUNTIME=podman` or `CONTAINER_RUNTIME=docker` to force a
specific runtime.

## Windows

```
PARALLELS_VM="Windows 11" \
WIN_REPO_PATH="\\\\Mac\\Home\\Documents\\Projects\\xlua\\xlua" \
./tools/workbench/build_win.sh
```

Requirements:

* Parallels Desktop with the CLI tools (`prlctl`) available.
* Visual Studio 2022 (Desktop C++ workload) installed inside the VM.
* The repository shared into the VM, e.g. `\\Mac\Home\Documents\Projects\xlua\xlua`.

Environment variables:

* `PARALLELS_VM` – name of the VM (e.g. `Windows 11`).
* `WIN_REPO_PATH` – Windows path to the shared repo.
* Optional `WIN_BUILD_ROOT` – Windows path to the host build root (defaults to
  `Z:/dev/xlua`, matching the usual Parallels `Z:` mapping to `\\Mac\Home`).
* Optional `MSBUILD_PATH` – override MSBuild location (defaults to the VS 2022
  Community path).

The script invokes MSBuild via `prlctl exec` and copies
`${XLUA_BUILD_ROOT}/work/windows/Release/plugins/win_x64/` artifacts into
`jenkins/build_products/`.
