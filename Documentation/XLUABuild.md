# XLua Build Chain

This document mirrors the internal Jenkins matrix so you can reproduce all
three platform builds locally. The approach follows the pattern from the
BetterPushback (BPB) cross-build guide: keep host-side setup minimal,
delegate Linux/Windows specifics to dedicated environments, and ensure all
artifacts land in a predictable staging directory.

## Common Layout & Artifacts

* Work from the repository root (`~/Documents/Projects/xlua/xlua` in this
  setup).
* The platform selector is the `PLATFORM` environment variable consumed by
  `jenkins/build.sh` (`APL`, `IBM`, or `LIN`). See `jenkins/build.sh` for the
  exact command lines per platform (`xcodebuild`/`make`/`MSBuild`) and the
  expected inputs like `WANT_CODESIGN` or `MSVC_ROOT`.
* Each run writes its deliverable into `jenkins/build_products/` via
  `jenkins/archive.sh`, matching the Jenkins artifacts:
  * `jenkins/build_products/xlua_mac.xpl` (fat binary, arm64 + x86_64)
  * `jenkins/build_products/xlua_lin.xpl`
  * `jenkins/build_products/xlua_win.xpl` (keep `xlua_win.pdb` for symbols)
* The ready-to-package plugin layout lives under `deploy/` (init.lua, scripts,
  and per-platform folders). Mirror the `.xpl` files from
  `jenkins/build_products/` into `deploy/{mac_x64,lin_x64,win_x64}/xlua.xpl`
  before zipping.

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
   `jenkins/build.sh`). The first run needs write access to
   `~/Library/Developer/Xcode/DerivedData/` – grant Terminal/`xcodebuild`
   Full Disk Access if macOS complains. Codesigning is disabled by default, so
   the archive step simply produces `xlua_mac.xpl` (universal binary) under
   `jenkins/build_products/`.

This is the native equivalent of BPB’s mac build section: everything stays on
the host except optional notarization, so no containers are involved.

## Linux (LIN)

Reference: `tools/workbench/build_linux.sh`, `Makefile`, `jenkins/build.sh`
(`LIN` case).

1. Install Podman on macOS (or Docker if you swap the container runtime) and
   run `podman machine init && podman machine start` once, similar to spinning
   up the `bpb-cross` Docker VM described in the BPB guide.
2. Ensure you have enough disk/bandwidth inside the VM: the first run pulls
   `ubuntu:22.04` and installs `build-essential`, `cmake`, `ninja-build`, and
   `pkg-config`.
3. Execute `./tools/workbench/build_linux.sh`. The wrapper:
   * Mounts the repo into `/work` inside the container.
   * Sets `PLATFORM=LIN` and runs `./jenkins/build.sh`.
   * Calls the root `Makefile` (`make clean && make`) to produce
     `build/xlua/64/lin.xpl`, then copies it into
     `jenkins/build_products/xlua_lin.xpl`.

This reproduces the Docker-based cross-build workflow from BPB without having
to maintain host-side toolchains. Set `LINUX_BUILD_IMAGE` if you need a
different base image (e.g., matching the deployment distro).

## Windows (IBM)

Reference: `tools/workbench/README.md`, `jenkins/build.sh` (`IBM` case),
`xlua.vcxproj`.

1. Provision a Windows 11 VM (Parallels recommended) and install Visual
   Studio 2022 with the Desktop C++ workload. Share the repo into the VM (e.g.,
   `\\Mac\Home\Documents\Projects\xlua\xlua`) so `Release\plugins\win_x64\`
   maps back to macOS.
2. Either open `xlua.vcxproj` in the IDE (retarget the platform toolset to
   `v143` unless you explicitly install the VS 2019/v142 tools) or run MSBuild
   directly:
   ```
   "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" ^
       xlua.vcxproj /m /p:Configuration=Release /p:Platform=x64
   ```
   The `tools/workbench/build_win.sh` helper can call this via `prlctl exec`
   if the VM auto-logs in and Parallels has the necessary macOS automation
   permissions (`PARALLELS_VM`, `WIN_REPO_PATH`, optional `MSBUILD_PATH`). In
   practice it’s often quicker to run MSBuild directly from inside the VM.
3. The Release build writes `xlua.xpl` and `xlua.pdb` to
   `Release\plugins\win_x64\`. Copy them into
   `jenkins/build_products/{xlua_win.xpl,xlua_win.pdb}` before mirroring the
   `.xpl` into `deploy/win_x64/`.

## Suggested Workflow

1. Sync sources (optionally mirror off iCloud to dodge `xcodebuild`/Docker
   lockups) and ensure `LuaJIT-2.1.0` is present.
2. Build macOS first. If macOS blocks DerivedData writes, grant Terminal/Xcode
   Full Disk Access. Once `jenkins/build_products/xlua_mac.xpl` exists, copy it
   to `deploy/mac_x64/xlua.xpl`.
3. Build Linux inside Podman/Docker (prefer a Linux/amd64 image). The wrapper
   already installs toolchains, so after it finishes copy the new
   `xlua_lin.xpl` into `deploy/lin_x64/`.
4. Build Windows in the VM (either via the helper script or manually in
   PowerShell). Retarget to toolset v143 or install the v142 tools first, then
   copy `Release\plugins\win_x64\xlua.xpl` to both
   `jenkins/build_products/` and `deploy/win_x64/`. Keep `xlua_win.pdb` if you
   want symbols.
5. Zip `deploy/` (init.lua, scripts, and the three platform folders) or copy
   it into your aircraft repository for release.

With this setup, all three platforms reuse the same `jenkins/build.sh` entry
point, just like the BPB guide funnels every build through its Docker image.
