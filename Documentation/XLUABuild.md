# XLua Build Chain

This document mirrors the internal Jenkins matrix so you can reproduce all
three platform builds locally. The approach follows the pattern from the
BetterPushback (BPB) cross-build guide: keep host-side setup minimal,
delegate Linux/Windows specifics to dedicated environments, and ensure all
artifacts land in a predictable staging directory.

## Common Layout & Artifacts

* Work from the repository root (`~/Documents/Projects/xlua/xlua` in this
  setup).
* The root-level workbench wrappers under `tools/workbench/` automatically
  switch into the nested plugin repo `xlua/`. Override with
  `XLUA_PLUGIN_ROOT=/path/to/xlua` if needed.
* The platform selector is the `PLATFORM` environment variable consumed by
  `jenkins/build.sh` (`APL`, `IBM`, or `LIN`). See `jenkins/build.sh` for the
  exact command lines per platform (`xcodebuild`/`make`/`MSBuild`) and the
  expected inputs like `WANT_CODESIGN` or `MSVC_ROOT`.
* Temporary build working directories default to `~/dev/xlua` via
  `XLUA_BUILD_ROOT`. Override it if you want a different non-iCloud location.
  The wrappers keep generated intermediates under
  `${XLUA_BUILD_ROOT}/work/{mac,linux,windows}/`.
* Each run writes its deliverable into `jenkins/build_products/` via
  `jenkins/archive.sh`, matching the Jenkins artifacts:
  * `jenkins/build_products/xlua_mac.xpl` (fat binary, arm64 + x86_64)
  * `jenkins/build_products/xlua_lin.xpl`
  * `jenkins/build_products/xlua_win.xpl` (keep `xlua_win.pdb` for symbols)
* The ready-to-package plugin layout lives under `deploy/` (init.lua, scripts,
  and per-platform folders). Mirror the `.xpl` files from
  `jenkins/build_products/` into `deploy/{mac_x64,lin_x64,win_x64}/xlua.xpl`
  before zipping.

## Quick Start

From the root workspace (`~/Documents/Projects/xlua`):

```bash
# Optional; defaults to ~/dev/xlua.
export XLUA_BUILD_ROOT="$HOME/dev/xlua"

# macOS
export XPLANE_SDK_ROOT="$PWD/xlua/SDK"
./tools/workbench/build_mac.sh

# Linux
./tools/workbench/build_linux.sh
# or, if Podman is unhealthy on this host:
CONTAINER_RUNTIME=docker ./tools/workbench/build_linux.sh

# Windows
PARALLELS_VM="Windows 11" \
WIN_REPO_PATH="\\\\Mac\\Home\\Documents\\Projects\\xlua\\xlua" \
./tools/workbench/build_win.sh
```

All three wrappers switch into the nested plugin repo automatically and write
artifacts to `xlua/jenkins/build_products/`. Build intermediates stay under
`XLUA_BUILD_ROOT` instead of the iCloud-synced source tree.

## macOS (APL)

Reference: `tools/workbench/build_mac.sh`, `jenkins/build.sh` (`APL` case).

1. Install Xcode + Command Line Tools and accept the license (`xcodebuild
   -version` must work).
2. Export `XPLANE_SDK_ROOT` to point at your X-Plane SDK checkout (the wrapper
   script enforces this).
3. Optional: set `WANT_CODESIGN=YES` plus the notarization credentials required
   by `build-tools/mac/notarization.sh` if you want to reuse the production
   signing/notarization flow.
4. Run `./tools/workbench/build_mac.sh` (or set `PLATFORM=APL` and call
   `jenkins/build.sh`). `DerivedData`, the `.xcarchive`, and the optional
   notarization zip are written under `${XLUA_BUILD_ROOT}/work/mac/`.
   Codesigning is disabled by default, so the archive step simply produces
   `xlua_mac.xpl` (universal binary) under `jenkins/build_products/`.

Known-good wrapper invocation from the root workspace:

```bash
export XPLANE_SDK_ROOT="$PWD/xlua/SDK"
./tools/workbench/build_mac.sh
```

This is the native equivalent of BPB’s mac build section: everything stays on
the host except optional notarization, so no containers are involved.

## Linux (LIN)

Reference: `tools/workbench/build_linux.sh`, `Makefile`, `jenkins/build.sh`
(`LIN` case).

1. Install Podman or Docker on macOS. If you use Podman, run
   `podman machine init && podman machine start` once, similar to spinning up
   the `bpb-cross` Docker VM described in the BPB guide.
2. Ensure you have enough disk/bandwidth inside the VM: the first run pulls
   `ubuntu:22.04` and installs `build-essential`, `cmake`, `ninja-build`, and
   `pkg-config`.
3. Execute `./tools/workbench/build_linux.sh`. The wrapper:
   * Prefers a working Podman setup, but falls back to Docker when Podman is
     installed but unreachable.
   * Mounts the repo into `/work` inside the container.
   * Mounts `${XLUA_BUILD_ROOT}` into the container at the same absolute path.
   * Uses `--platform=linux/amd64` automatically on Apple Silicon.
   * Sets `PLATFORM=LIN` and runs `./jenkins/build.sh`.
   * Calls the root `Makefile` to produce
     `${XLUA_BUILD_ROOT}/work/linux/build/xlua/64/lin.xpl`, then copies it into
     `jenkins/build_products/xlua_lin.xpl`.

This reproduces the Docker-based cross-build workflow from BPB without having
to maintain host-side toolchains. Set `LINUX_BUILD_IMAGE` if you need a
different base image (e.g., matching the deployment distro).

Known-good wrapper invocations from the root workspace:

```bash
./tools/workbench/build_linux.sh

# Force Docker if Podman reports stale machine metadata but `podman info` fails.
CONTAINER_RUNTIME=docker ./tools/workbench/build_linux.sh
```

## Windows (IBM)

Reference: `tools/workbench/README.md`, `jenkins/build.sh` (`IBM` case),
`xlua.vcxproj`.

1. Provision a Windows 11 VM (Parallels recommended) and install Visual
   Studio 2022 with the Desktop C++ workload. Share the repo into the VM (e.g.,
   `\\Mac\Home\Documents\Projects\xlua\xlua`). The wrapper also writes MSBuild
   outputs to `\\Mac\Home\dev\xlua` by default, matching host-side
   `~/dev/xlua`.
2. Either open `xlua.vcxproj` in the IDE (retarget the platform toolset to
   `v143` unless you explicitly install the VS 2019/v142 tools) or run MSBuild
   directly:
   ```powershell
   $buildRoot = "Z:/dev/xlua"
   $outDir = $buildRoot + "/work/windows/Release/plugins/win_x64/"
   $intDir = $buildRoot + "/work/windows/Release/64/"
   & "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" `
       xlua.vcxproj /m /t:Clean /p:Configuration=Release /p:Platform=x64 `
       "/p:OutDir=$outDir" "/p:IntDir=$intDir"
   & "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" `
       xlua.vcxproj /m /t:Build /p:Configuration=Release /p:Platform=x64 `
       "/p:OutDir=$outDir" "/p:IntDir=$intDir"
   ```
   The `tools/workbench/build_win.sh` helper can call this via `prlctl exec`
   if the VM auto-logs in and Parallels has the necessary macOS automation
   permissions (`PARALLELS_VM`, `WIN_REPO_PATH`, optional `MSBUILD_PATH`).
   The default `WIN_BUILD_ROOT` is `Z:/dev/xlua`, matching the usual Parallels
   `Z:` mapping to `\\Mac\Home`. Set `WIN_BUILD_ROOT` if the VM sees the host
   build root at a different Windows path.
3. The Release build writes `xlua.xpl` and `xlua.pdb` to
   `${XLUA_BUILD_ROOT}/work/windows/Release/plugins/win_x64/`; the wrapper
   copies them into `jenkins/build_products/{xlua_win.xpl,xlua_win.pdb}`
   before mirroring the `.xpl` into `deploy/win_x64/`.

Known-good wrapper invocation from the root workspace:

```bash
PARALLELS_VM="Windows 11" \
WIN_REPO_PATH="\\\\Mac\\Home\\Documents\\Projects\\xlua\\xlua" \
./tools/workbench/build_win.sh
```

## Suggested Workflow

1. Keep sources in the iCloud-synced checkout, but keep `XLUA_BUILD_ROOT` on
   local disk and ensure `LuaJIT-2.1.0` is present.
2. Build macOS first. Once `jenkins/build_products/xlua_mac.xpl` exists, copy
   it to `deploy/mac_x64/xlua.xpl`.
3. Build Linux inside Podman/Docker (prefer a Linux/amd64 image). The wrapper
   already installs toolchains, so after it finishes copy the new
   `xlua_lin.xpl` into `deploy/lin_x64/`.
4. Build Windows in the VM (prefer the helper script when using the local
   build root). Retarget to toolset v143 or install the v142 tools first, then
   copy `xlua_win.xpl` from `jenkins/build_products/` to `deploy/win_x64/`.
   Keep `xlua_win.pdb` if you want symbols.
5. Zip `deploy/` (init.lua, scripts, and the three platform folders) or copy
   it into your aircraft repository for release.

With this setup, all three platforms reuse the same `jenkins/build.sh` entry
point, just like the BPB guide funnels every build through its Docker image.
