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

Visual Studio runs inside Parallels. Build steps:

1. Share the repository into the VM (`\\Mac\Home\Documents\Projects\xlua` or a
   dedicated drive).
2. Open the `xLua.sln`/`.vcxproj` in Visual Studio 2022 (Desktop C++ workload
   installed).
3. Build via MSBuild:
   ```
   "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" ^
       xlua.vcxproj /p:Configuration=Release /p:Platform=x64
   ```
4. artifacts will appear under `Release/plugins/win_x64`.

If you prefer driving this from the Mac side, create a Parallels shared folder
and call MSBuild via `prlctl exec <vm> -- <command>` or expose the VM over SSH.
