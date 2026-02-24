# AGENTS.md

Context for XLua performance, stability, and build workflows in this repo.

## Repo Layout
- Root repo: `/Users/wahltho/Documents/Projects/xlua`
- XLua subrepo (actual plugin source): `/Users/wahltho/Documents/Projects/xlua/xlua`
- Main plugin sources: `xlua/src/`
- Build scripts: `xlua/jenkins/*.sh`
- Workbench wrappers: `tools/workbench/*`
- Release notes: `xlua/README.md` and root `CHANGES.md`
- Local build guide: `Documentation/XLUABuild.md`

## Two Git Repos (Not a Submodule)
- Root repo and `xlua/` are independent git repos.
- Always check both statuses when asked if "git is clean":
```
cd /Users/wahltho/Documents/Projects/xlua && git status
cd /Users/wahltho/Documents/Projects/xlua/xlua && git status
```
- Subrepo remote `origin` -> upstream `X-Plane/xlua`.
- Subrepo remote `wahltho` -> fork `wahltho/XLua`.
- Root repo has its own `origin` on branch `main`.

## Git Workflow Cheatsheet
- Show remotes in both repos:
```
git -C /Users/wahltho/Documents/Projects/xlua remote -v
git -C /Users/wahltho/Documents/Projects/xlua/xlua remote -v
```
- Update subrepo from upstream:
```
git -C /Users/wahltho/Documents/Projects/xlua/xlua fetch origin
git -C /Users/wahltho/Documents/Projects/xlua/xlua log --oneline HEAD..origin/master
```
- Push all repos (root + subrepo):
```
git -C /Users/wahltho/Documents/Projects/xlua push origin
git -C /Users/wahltho/Documents/Projects/xlua/xlua push wahltho
```

## Versioning and Release Notes
- Version define lives in `xlua/src/xlua.cpp` (currently `1.3.7r2`).
- Update `xlua/README.md` release notes for every bump.
- Optional: update root `CHANGES.md` with a summary.
- For rebuild-only releases, bump minimally (e.g., `0.0.1`).

## Performance and Stability Changes (Summary)
- Module manifest cache: `scripts/.xlua_manifest` reused unless `scripts/` mtime changes; modules load alphabetically; missing `module.lua` is skipped with a single warning. `xlua/src/xlua.cpp`.
- Reload guard: skip reload if `scripts` dir mtime, `init.lua` mtime, and newest module script mtime are unchanged. `xlua/src/xlua.cpp`.
- Hook detection: modules capture callouts at load; flight loops call only modules that implement `before_physics`, `after_physics`, `after_replay`. `xlua/src/module.cpp`, `xlua/src/module.h`, `xlua/src/xlua.cpp`.
- Command lookup cache: `xlua_find_cmd` uses `unordered_map` and is cleared on cleanup to avoid stale handles after reload. `xlua/src/xpcommands.cpp`.
- Dataref caching: cache dataref types and array dimensions; array dims fetched once via XPLMGetDatavf/vi. `xlua/src/xpdatarefs.cpp`.
- Logging: de-duplicate repeated lines, emit summary every 64 repeats, flush on shutdown. `xlua/src/xpfuncs.cpp`, `xlua/src/xlua.cpp`.
- JIT runtime toggle: dataref `xlua/jit_enabled` and command `xlua/jit_toggle`, default off; apply to all modules and flush on enable. `xlua/src/xpfuncs.cpp`, `xlua/src/xlua.cpp`.
- Memory corruption fix: module allocation now uses `sizeof(module_alloc_block)` instead of `MALLOC_CHUNK_SIZE`. `xlua/src/module.cpp`.

## Runtime Toggles
- Logging dataref: `xlua/logging_enabled` (default 1)
- Logging command: `xlua/logging_toggle`
- JIT dataref: `xlua/jit_enabled` (default 0)
- JIT command: `xlua/jit_toggle`

## Key Entry Points
- Plugin lifecycle, reload logic, module discovery: `xlua/src/xlua.cpp`
- Module load and callout capture: `xlua/src/module.cpp`, `xlua/src/module.h`
- Datarefs: `xlua/src/xpdatarefs.cpp`, `xlua/src/xpdatarefs.h`
- Commands: `xlua/src/xpcommands.cpp`, `xlua/src/xpcommands.h`
- Logging helpers: `xlua/src/xpfuncs.cpp`, `xlua/src/log.h`

## Build Overview
- Main entry point: `xlua/jenkins/build.sh` with `PLATFORM=APL|IBM|LIN`.
- Each run wipes `xlua/jenkins/build_products/` first.
- DerivedData path is `xlua/DerivedData` unless `DERIVED_DATA_PATH` is set.
- Codesigning: set `WANT_CODESIGN=YES` to use `build-tools/mac/notarization.sh`.
- Windows build in `jenkins/build.sh` uses `MSVC_ROOT` and MSBuild.
- Jenkins-style local driver: `xlua/jenkins_driver.sh` (flags: `--no_codesign`, `--no_unit_tests`).

## macOS Build (APL)
- Wrapper: `tools/workbench/build_mac.sh`.
- Requirements: Xcode + CLT, `XPLANE_SDK_ROOT` exported.
- Optional: `WANT_CODESIGN=YES` and `DERIVED_DATA_PATH`.
- Output: `xlua/jenkins/build_products/xlua_mac.xpl` (universal binary).
- Typical command:
```
export XPLANE_SDK_ROOT=/path/to/XPLANE_SDK
./tools/workbench/build_mac.sh
```

## Linux Build (LIN)
- Wrapper: `tools/workbench/build_linux.sh` (Podman + `ubuntu:22.04`).
- Override image with `LINUX_BUILD_IMAGE`.
- Apple Silicon needs `linux/amd64` containers to avoid `-m64` failures.
- Build uses `make clean && make`; output originates at `xlua/build/xlua/64/lin.xpl`.
- Output: `xlua/jenkins/build_products/xlua_lin.xpl`.

## Windows Build (IBM)
- Options: run manually in VM or `tools/workbench/build_win.sh` (Parallels).
- Requirements: Visual Studio 2022 (Desktop C++ workload).
- VM share path example: `\\Mac\Home\Documents\Projects\xlua\xlua`.
- Env vars for wrapper: `PARALLELS_VM`, `WIN_REPO_PATH`, optional `MSBUILD_PATH`.
- Manual PowerShell build command:
```
& "C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\MSBuild\\Current\\Bin\\MSBuild.exe" xlua.vcxproj /m /p:Configuration=Release /p:Platform=x64
```
- Output: `xlua/Release/plugins/win_x64/xlua.xpl` and `xlua/Release/plugins/win_x64/xlua.pdb`.

## Artifacts and Deploy
- Build outputs land in `xlua/jenkins/build_products/`:
- `xlua_mac.xpl`, `xlua_lin.xpl`, `xlua_win.xpl` (plus `xlua_win.pdb`).
- Deploy layout: `xlua/deploy/` contains `init.lua`, `scripts/`, and platform folders.
- Copy artifacts into:
- `xlua/deploy/mac_x64/xlua.xpl`
- `xlua/deploy/lin_x64/xlua.xpl`
- `xlua/deploy/win_x64/xlua.xpl`
- Keep `xlua_win.pdb` for symbols/debugging.
- One-liner copy from build_products to deploy:
```
cp xlua/jenkins/build_products/xlua_mac.xpl xlua/deploy/mac_x64/xlua.xpl
cp xlua/jenkins/build_products/xlua_lin.xpl xlua/deploy/lin_x64/xlua.xpl
cp xlua/jenkins/build_products/xlua_win.xpl xlua/deploy/win_x64/xlua.xpl
```

## Plugin Packaging and Script Layout
- The plugin folder in an aircraft should look like: `plugins/xlua/{mac_x64,lin_x64,win_x64}/xlua.xpl` plus `init.lua` and `scripts/`.
- `init.lua` is part of the plugin and should not be edited.
- Each module lives in its own folder under `scripts/` and the main Lua file must match the module name.
- Sub-folders under `scripts/` are not allowed; all modules must be direct children of `scripts/`.

## Dependencies and SDK
- X-Plane SDK lives under `xlua/SDK`.
- Windows libs: `xlua/SDK/Libraries/Win/XPLM_64.lib`, `XPWidgets_64.lib`.
- Lua libs: `xlua/lua_sdk/lua51.lib` (Windows) and `xlua/lua_sdk/libluajit.a` (Linux).
- LuaJIT source checkout: `xlua/LuaJIT-2.1.0`.
- Linux Makefile uses `-m64`, `exports.txt`, and links `libluajit.a` from `xlua/lua_sdk`.

## Troubleshooting
- PowerShell `Unexpected token` when running MSBuild with a quoted path: use the `&` call operator.
- Podman socket issues: `podman machine start` or use Docker as a fallback.
- Apple Silicon Linux build: force `linux/amd64` images when running containers.
- macOS build permission errors: grant Terminal/Xcode Full Disk Access for DerivedData.

## Upstream Sync and PR Workflow
- Fetch upstream: `git -C xlua fetch origin`.
- Compare commits: `git -C xlua log --oneline HEAD..origin/master` (or `origin/main`).
- Cherry-pick fixes: `git -C xlua cherry-pick <sha>`.
- Push fork: `git -C xlua push wahltho <branch>`.
- Open PR/MR from fork `wahltho/XLua` into upstream `X-Plane/xlua`.
