# Workbench Build Helpers

This directory contains small wrappers that mirror the Jenkins build matrix so
you can invoke the existing scripts from your workstation without repeating
setup steps.

## macOS (`build_mac.sh`)

```
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
```

Requirements:

* Podman installed on the Mac host.
* A Podman machine initialized (`podman machine init`/`start`). The script will
  try to start it if it is not running.
* Sufficient disk space/bandwidth for the container to `apt-get install`
  `build-essential`/`cmake`/`ninja-build`/`pkg-config` the first time it runs.

The wrapper mounts the repo into `/work` inside an `ubuntu:22.04` container and
invokes `jenkins/build.sh` with `PLATFORM=LIN`.

Set `LINUX_BUILD_IMAGE` to use a different base image.

## Windows

```
./tools/workbench/build_win.sh
```

Requirements:

* Parallels Desktop with the CLI tools (`prlctl`) available.
* Visual Studio 2022 (Desktop C++ workload) installed inside the VM.
* The repository shared into the VM, e.g. `\\Mac\Home\Documents\Projects\xlua\xlua`.

Environment variables:

* `PARALLELS_VM` – name of the VM (e.g. `Windows 11`).
* `WIN_REPO_PATH` – Windows path to the shared repo.
* Optional `MSBUILD_PATH` – override MSBuild location (defaults to the VS 2022
  Community path).

The script invokes MSBuild via `prlctl exec` and copies
`Release\plugins\win_x64\` artifacts into `jenkins/build_products/`.
