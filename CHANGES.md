# XLua Changes (Performance + Stability)

This tracks the runtime optimizations and controls added while profiling XLua
for script-heavy aircraft (e.g., Zibo).

## 1.3.7r1
* Clear the command lookup cache on shutdown/reload to avoid stale handles after script reloads (fixes default commands breaking post-reload).
* Keep JIT opt-in controls: dataref `xlua/jit_enabled` (default off) and command `xlua/jit_toggle` to flip JIT at runtime without touching scripts.

## 1.3.7b1
* Added JIT runtime toggle: new dataref `xlua/jit_enabled` (default 0) plus command to flip it in-flight for testing.
* Logging and command toggles remain opt-in (no script changes required).

## 1.3.6r1
* Reload guard: skip reloading modules when the scripts directory mtimes have not changed.
* Added logging toggle dataref `xlua/logging_enabled` (default on) and command `xlua/logging_toggle` to reduce noise without repacking scripts.

## 1.3.5r1
* Command lookup caching and cache-invalidate to cut per-command overhead.
* Dataref type/dimension caching for arrays to avoid repeated XP SDK queries.
* Safer logging (snprintf usage) and small handler micro-optimizations.

## Earlier performance changes

### Module Loading & Ordering
* Batch `XPLMGetDirectoryContents` and write a `.xlua_manifest` cache; reuse on reload unless `scripts/` changes.
* Check for `module/module.lua` before instantiating; skip missing folders with a single warning.
* Instantiate modules alphabetically for a stable load order.

### Hook Discovery & Call Reduction
* Each module records whether it implements `before_physics`, `after_physics`,
  or `after_replay`.
* Flight loops only invoke modules that flagged those hooks, removing two
  redundant Lua calls per frame for modules that never use the callbacks.

### Logging Improvements
* Deduplicate repeated log lines into “Previous message repeated N times”
  summaries to cut spam on Windows/macOS.
* Flush the deduplicated queue when the plugin stops so the final summary is
  written.
