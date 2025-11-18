# XLua Changes (Performance + Logging)

This summarizes the runtime changes we made while profiling XLua for scripted
aircraft (e.g., the Zibo mod).

## Module Loading & Ordering

* Directory enumeration now batches `XPLMGetDirectoryContents` calls and writes
  a `.xlua_manifest` cache. Subsequent reloads reuse the cached module list
  unless the `scripts/` directory changes.
* The loader checks for `module/module.lua` before instantiating and skips
  missing folders with a single warning instead of aborting.
* Modules are instantiated in alphabetical order to guarantee a stable load
  sequence regardless of host filesystem quirks.

## Hook Discovery & Call Reduction

* Each module records whether it actually implements `before_physics`,
  `after_physics`, or `after_replay`.
* The flight loops only invoke modules that flagged those hooks, removing two
  redundant Lua calls per frame for modules that never use the callbacks.

## Logging Improvements

* Added a simple deduplicator so repeated log lines collapse into “Previous
  message repeated N times” summaries, reducing log spam on Windows/macOS.
* Flush the deduplicated queue when the plugin stops to ensure the final
  summary makes it into the log.
