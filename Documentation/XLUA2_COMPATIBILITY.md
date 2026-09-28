# XLua Runtime Compatibility

## X-Plane Version Requirement

| Runtime | Channel | Required X-Plane version |
| --- | --- | --- |
| Optimized XLua 1.3.7r5 | Stable | Use this runtime with X-Plane 12.4.3 |
| Optimized XLua 2.0.0b1-opt4 | Beta | X-Plane 12.4.4 or newer |

XLua 2 uses X-Plane SDK functions introduced with X-Plane 12.4.4. The
optimized XLua 2 Beta therefore does not load on X-Plane 12.4.3. Selecting the
Beta channel in the Maintenance Toolkit does not bypass this simulator
requirement.

XLua 2 remains a prerelease even on a compatible X-Plane version. Users who
prefer the established runtime, or who remain on X-Plane 12.4.3, should select
the Stable channel and use XLua 1.3.7r5.

## Symptom on X-Plane 12.4.3

On Windows, `Log.txt` may report the XLua binary with:

```text
Error Code = 127 : The specified procedure could not be found.
```

This means that XLua 2 did not load. The aircraft's Lua scripts consequently
do not run and do not create their datarefs. Missing-dataref messages from
FMOD, AFCBridge, BFC_Throttle, or other integrations can then appear as
downstream symptoms; they do not show that those components caused the XLua
loader failure.

## Recovery

Close X-Plane and restore the Stable XLua 1 runtime from the Maintenance
Toolkit or from the XLua 1.3.7r5 release backup. Do not leave XLua 1 and XLua 2
binaries side by side. Keep the aircraft-owned `plugins/xlua/scripts` tree
unchanged.

When reporting a Beta problem, include the X-Plane version, XLua release,
operating system, aircraft version, and the relevant section of `Log.txt`.
