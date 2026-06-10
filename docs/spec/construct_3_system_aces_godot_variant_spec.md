# Construct 3 System ACEs — Godot Variant Spec

> **Reference design study.** Implementation status lives in `docs/SPEC.md` §3 and the
> builtin registry (`addons/eventforge/registration/builtin_aces.gd`); the practical
> C3→Godot vocabulary map for users is `docs/C3-MIGRATION-GUIDE.md`.

This document defines the Godot-native equivalent of Construct 3's built-in **System** object ACEs
(Actions, Conditions, Expressions). These form the control-flow, variable, timing, and utility
vocabulary that every EventSheet-based game needs before adding any custom plugin ACEs.

---

## Background

In Construct 3 the **System** object is always available and exposes:
- **System Conditions** — wait-for-signal, comparing values, loop/group flow
- **System Actions** — set variables, create/destroy objects, control groups, wait/delay
- **System Expressions** — math, string, time, conversion utilities

This spec translates those categories into Godot-idiomatic equivalents that work within the
EventForge ACE registry (`EventSheetACERegistry`, `ACEDefinition`, `ACECondition`, `ACEAction`).

---

## Provider ID

All System ACEs should register under:
```
provider_id = "System"
```

---

## System Conditions

| C3 Condition | Godot Variant | Notes |
|---|---|---|
| `Is group active` | `GroupActive` | Check if a named EventGroup is enabled |
| `Trigger once while true` | `TriggerOnce` | Edge-detect: fires exactly once per true→false cycle |
| `Compare variable` | `CompareVar` | Compare a sheet/local variable to a value |
| `Compare two values` | `Compare` | Compare any two expressions |
| `Is between values` | `Between` | Check if value is in `[min, max]` range |
| `Is NaN` | `IsNaN` | Check for float not-a-number |
| `For each (object)` | `ForEach` | Iterate over a typed object list |
| `While` | `While` | Loop while condition is true (with iteration cap) |
| `Else` | (native) | Built in via `EventRow.else_mode` |
| `Else if` | (native) | Built in via `EventRow.else_mode` |

### Condition Parameter Schema (examples)

```gdscript
# CompareVar
parameters = [
    ACEParameter.new("var_name", ACEParameter.Type.STRING, "Variable name"),
    ACEParameter.new("operator", ACEParameter.Type.COMBO, "Operator",
        {"options": ["==", "!=", "<", "<=", ">", ">="]}),
    ACEParameter.new("value", ACEParameter.Type.EXPRESSION, "Value")
]
```

---

## System Actions

| C3 Action | Godot Variant | Notes |
|---|---|---|
| `Set variable` | `SetVar` | Assign a value to a global/local variable |
| `Add to variable` | `AddToVar` | In-place add to a numeric variable |
| `Subtract from variable` | `SubVar` | In-place subtract |
| `Toggle boolean variable` | `ToggleVar` | Flip bool variable |
| `Set group enabled` | `SetGroup` | Enable/disable a named EventGroup |
| `Stop loop` | `StopLoop` | Break out of the innermost `For each` or `While` block |
| `Set timer` | `SetTimer` | Schedule a named timer (seconds) |
| `Create object` | `CreateObject` | Instantiate a Godot scene by path |
| `Destroy object` | `DestroyObject` | Queue free a Godot object |
| `Wait` | `Wait` | Suspend current event chain for N seconds (async) |
| `Set canvas background` | `SetBackground` | Change scene background color |
| `Go to layout` | `GoToScene` | Change to a different Godot scene |
| `Load next layout` | `NextScene` | Advance to the next scene in a defined sequence |
| `Restart layout` | `RestartScene` | Reload the current scene |
| `Quit game` | `QuitGame` | `get_tree().quit()` |
| `Save state` | `SaveState` | Serialize current variable/object state snapshot |
| `Load state` | `LoadState` | Restore a previously saved state snapshot |
| `Reset global variables` | `ResetGlobals` | Restore all global variables to defaults |
| `Comment` | (native) | Built in via `CommentRow` |

---

## System Expressions

| C3 Expression | Godot Variant | Return Type | Notes |
|---|---|---|---|
| `time` | `Time` | `float` | Seconds since scene started |
| `wallclocktime` | `WallClock` | `float` | Seconds since Unix epoch |
| `random(min, max)` | `Random` | `float` | Uniform random in `[min, max)` |
| `choose(a, b, ...)` | `Choose` | `Variant` | Randomly select one argument |
| `round(x)` | `Round` | `float` | Round to nearest integer |
| `floor(x)` | `Floor` | `float` | Floor |
| `ceil(x)` | `Ceil` | `float` | Ceiling |
| `abs(x)` | `Abs` | `float` | Absolute value |
| `min(a, b)` | `Min` | `float` | Minimum of two values |
| `max(a, b)` | `Max` | `float` | Maximum of two values |
| `clamp(x, lo, hi)` | `Clamp` | `float` | Clamp to range |
| `lerp(a, b, t)` | `Lerp` | `float` | Linear interpolate |
| `sin(x)` | `Sin` | `float` | Sine (radians) |
| `cos(x)` | `Cos` | `float` | Cosine (radians) |
| `distance(x1,y1,x2,y2)` | `Distance` | `float` | 2-D Euclidean distance |
| `angle(x1,y1,x2,y2)` | `Angle` | `float` | 2-D angle in degrees |
| `str(x)` | `Str` | `String` | Convert value to string |
| `int(x)` | `Int` | `int` | Convert to integer |
| `float(x)` | `Float` | `float` | Convert to float |
| `len(s)` | `Len` | `int` | String or array length |
| `substr(s, start, len)` | `Substr` | `String` | Substring |
| `lowercase(s)` | `Lower` | `String` | Lowercase |
| `uppercase(s)` | `Upper` | `String` | Uppercase |
| `newline` | `Newline` | `String` | `"\n"` |
| `undefined` | `Null` | `Variant` | `null` |

---

## Runtime / Compiler Notes

### Variable Semantics
- Global variables live in `EventSheetResource.variables` (Dictionary, keyed by name).
- Local variables live in `EventRow.local_variables` (Array of `LocalVariable`).
- At runtime the bridge (`EventForgeBridge`) should expose `get_var(name)` and
  `set_var(name, value)` that resolve local scope before global.

### Timer Semantics
- Named timers are managed per-bridge instance.
- `SetTimer(name, seconds)` schedules a one-shot callback that fires a sheet-level
  signal (`timer_elapsed(name)`), which any condition can listen for.

### Async / Wait
- `Wait` requires coroutine support in the runtime bridge.
- The compiler should emit `await get_tree().create_timer(seconds).timeout` in
  generated GDScript, or schedule an equivalent deferred callback.

### Group Enable / Disable
- `SetGroup(name, enabled)` sets `EventGroup.enabled = enabled` on a named group.
  At runtime the EventSheet engine skips all rows where `enabled == false`.

---

## Implementation Priority (suggested)

| Priority | ACEs |
|---|---|
| P0 (MVP) | `SetVar`, `AddToVar`, `CompareVar`, `Compare`, `TriggerOnce` |
| P1 | `SetGroup`, `StopLoop`, `While`, `ForEach`, `GroupActive` |
| P2 | `SetTimer`, `Wait`, `QuitGame`, `GoToScene` |
| P3 | `SaveState`, `LoadState`, `ResetGlobals`, expressions |

---

## See Also

- `docs/spec/gdevelop_c3_eventsheet_uiux_spec.md` — UI/UX interaction model reference
- `addons/eventsheet/editor/event_sheet_viewport.gd` — main viewport rendering
- `addons/eventforge/runtime/eventforge_bridge.gd` — runtime bridge stubs
- `addons/eventsheet/resources/ace_definition.gd` — ACEDefinition resource
- `AGENTS.md` — codebase conventions and future LLM guidance
