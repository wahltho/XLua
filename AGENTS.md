# AGENTS.md

Context for XLua performance and stability work in this repo.

## Project
- Repo root contains the XLua plugin under `xlua/`.
- Main plugin sources live in `xlua/src/`.
- Change history and release notes are in `CHANGES.md`.

## Version
- `xlua/src/xlua.cpp` defines VERSION "1.3.7r1".

## Performance and stability changes (summary)
- Module manifest cache: `scripts/.xlua_manifest` reused unless the `scripts/` mtime changes; modules load in alphabetical order; missing `module.lua` is skipped with a single warning. `xlua/src/xlua.cpp`.
- Reload guard: skip reload if `scripts` dir mtime, `init.lua` mtime, and newest module script mtime are unchanged. `xlua/src/xlua.cpp`.
- Hook detection: modules capture callouts at load; flight loops call only modules that implement `before_physics`, `after_physics`, `after_replay`. `xlua/src/module.cpp`, `xlua/src/module.h`, `xlua/src/xlua.cpp`.
- Command lookup cache: `xlua_find_cmd` uses `unordered_map` and is cleared on `xlua_cmd_cleanup` to avoid stale handles after reload. `xlua/src/xpcommands.cpp`.
- Dataref caching: cache dataref types and array dimensions; array dims fetched once via XPLMGetDatavf/vi. `xlua/src/xpdatarefs.cpp`.
- Logging: de-duplicate repeated lines, emit a summary every 64 repeats, flush on shutdown. `xlua/src/xpfuncs.cpp`, `xlua/src/xlua.cpp`.
- JIT runtime toggle: dataref `xlua/jit_enabled` and command `xlua/jit_toggle`, default off; apply to all modules and flush on enable. `xlua/src/xpfuncs.cpp`, `xlua/src/xlua.cpp`.

## Runtime toggles
- Logging:
  - Dataref `xlua/logging_enabled` (default 1)
  - Command `xlua/logging_toggle`
- JIT:
  - Dataref `xlua/jit_enabled` (default 0)
  - Command `xlua/jit_toggle`

## Key entry points
- Plugin lifecycle, reload logic, module discovery: `xlua/src/xlua.cpp`.
- Module load and callout capture: `xlua/src/module.cpp`, `xlua/src/module.h`.
- Datarefs: `xlua/src/xpdatarefs.cpp`, `xlua/src/xpdatarefs.h`.
- Commands: `xlua/src/xpcommands.cpp`, `xlua/src/xpcommands.h`.
- Logging helpers: `xlua/src/xpfuncs.cpp`, `xlua/src/log.h`.
