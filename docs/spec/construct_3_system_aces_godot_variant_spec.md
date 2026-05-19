# Construct 3 System ACEs — Godot 4 Variant Spec

**Status:** Spec / planning document — implementation is partially scaffolded; full runtime backing is deferred.  
**Last updated:** 2026-05-19  
**Purpose:** Translate Construct 3's built-in `System` object Actions, Conditions, and Expressions into an equivalent Godot-native vocabulary usable by EventForge.

---

## Overview

Construct 3 ships a `System` pseudo-object with a large set of built-in ACEs that cover:

| Category | Examples |
|---|---|
| Control flow | `Wait`, `Stop`, `Restart` |
| Variables | `Set`, `Add`, `Subtract` global/local variables |
| Groups | Enable / disable event groups |
| Timing | `Wait X seconds` (async coroutine) |
| Object operations | `Create`, `Destroy`, `Set layer`, `Move to top/bottom` |
| Saving / loading | `Save`, `Load`, snapshot states |
| Miscellaneous | `Set locale`, `Go to layout`, `Trigger event` |

In Godot/EventForge the equivalent is a first-class `System` ACE provider that is always present, requires no explicit node reference, and maps cleanly to GDScript/Godot runtime calls.

---

## Godot-Native System ACE Provider

**Provider ID:** `system`

The provider is registered by default in `EventSheetACERegistry` and does not require a node to be exposed to the sheet. It is the first entry listed in the ACE picker.

---

## Actions

### Control flow

| ACE ID | Display | Godot equivalent | Parameters |
|---|---|---|---|
| `wait` | Wait **{seconds}** seconds | `await get_tree().create_timer(seconds).timeout` | `seconds: float` |
| `stop` | Stop all events | (reserved — stops interpreter loop for current frame) | — |
| `restart_events` | Restart event processing | (reserved) | — |

### Variables (global sheet variables)

| ACE ID | Display | Godot equivalent | Parameters |
|---|---|---|---|
| `set_variable` | Set **{variable}** to **{value}** | `_sheet_vars[variable] = value` | `variable: String`, `value: Variant` |
| `add_to_variable` | Add **{value}** to **{variable}** | `_sheet_vars[variable] += value` | `variable: String`, `value: Variant` |
| `subtract_from_variable` | Subtract **{value}** from **{variable}** | `_sheet_vars[variable] -= value` | `variable: String`, `value: Variant` |

### Groups

| ACE ID | Display | Godot equivalent | Parameters |
|---|---|---|---|
| `enable_group` | Enable group **{group}** | sets `EventGroup.enabled = true` | `group: String` (group UID or name) |
| `disable_group` | Disable group **{group}** | sets `EventGroup.enabled = false` | `group: String` |
| `toggle_group` | Toggle group **{group}** | flips `EventGroup.enabled` | `group: String` |

### Debug & Output

| ACE ID | Display | Godot equivalent | Parameters |
|---|---|---|---|
| `log` | Log **{message}** | `print(message)` | `message: String` |
| `log_warning` | Log warning **{message}** | `push_warning(message)` | `message: String` |
| `log_error` | Log error **{message}** | `push_error(message)` | `message: String` |

### Scene / Node

| ACE ID | Display | Godot equivalent | Parameters |
|---|---|---|---|
| `change_scene` | Go to scene **{path}** | `get_tree().change_scene_to_file(path)` | `path: String` |
| `quit` | Quit game | `get_tree().quit()` | `exit_code: int = 0` |
| `pause` | Pause game | `get_tree().paused = true` | — |
| `unpause` | Unpause game | `get_tree().paused = false` | — |

---

## Conditions

### Timing / comparison

| ACE ID | Display | Godot equivalent | Parameters |
|---|---|---|---|
| `every_tick` | Every tick | always true (default empty event) | — |
| `every_n_seconds` | Every **{seconds}** seconds | timer-backed; ticks when cumulative time % seconds crosses boundary | `seconds: float` |
| `elapsed_time_gt` | Time elapsed > **{seconds}** | `Time.get_ticks_msec() / 1000.0 > seconds` | `seconds: float` |

### Variables

| ACE ID | Display | Godot equivalent | Parameters |
|---|---|---|---|
| `variable_eq` | **{variable}** equals **{value}** | `_sheet_vars[variable] == value` | `variable: String`, `value: Variant` |
| `variable_ne` | **{variable}** not equal **{value}** | `_sheet_vars[variable] != value` | `variable: String`, `value: Variant` |
| `variable_gt` | **{variable}** > **{value}** | `_sheet_vars[variable] > value` | `variable: String`, `value: Variant` |
| `variable_lt` | **{variable}** < **{value}** | `_sheet_vars[variable] < value` | `variable: String`, `value: Variant` |

### Groups

| ACE ID | Display | Godot equivalent | Parameters |
|---|---|---|---|
| `group_enabled` | Group **{group}** is enabled | checks `EventGroup.enabled` | `group: String` |

### Scene

| ACE ID | Display | Godot equivalent | Parameters |
|---|---|---|---|
| `is_paused` | Game is paused | `get_tree().paused` | — |

### Input (convenience wrappers)

| ACE ID | Display | Godot equivalent | Parameters |
|---|---|---|---|
| `key_pressed` | Key **{key}** pressed | `Input.is_key_pressed(key)` | `key: int` (Key enum) |
| `action_pressed` | Action **{action}** pressed | `Input.is_action_pressed(action)` | `action: String` |
| `action_just_pressed` | Action **{action}** just pressed | `Input.is_action_just_pressed(action)` | `action: String` |
| `action_just_released` | Action **{action}** just released | `Input.is_action_just_released(action)` | `action: String` |

---

## Expressions

| ACE ID | Return type | Display | Godot equivalent | Parameters |
|---|---|---|---|---|
| `time` | `float` | `time` | `Time.get_ticks_msec() / 1000.0` | — |
| `dt` | `float` | `dt` | `delta` (current frame delta) | — |
| `random` | `float` | `random(min, max)` | `randf_range(min, max)` | `min: float`, `max: float` |
| `random_int` | `int` | `random_int(min, max)` | `randi_range(min, max)` | `min: int`, `max: int` |
| `choose` | `Variant` | `choose(a, b, ...)` | picks one value at random | variadic `values: Array` |
| `round` | `float` | `round(x)` | `roundf(x)` | `x: float` |
| `floor` | `float` | `floor(x)` | `floorf(x)` | `x: float` |
| `ceil` | `float` | `ceil(x)` | `ceilf(x)` | `x: float` |
| `abs` | `float` | `abs(x)` | `absf(x)` | `x: float` |
| `min` | `float` | `min(a, b)` | `minf(a, b)` | `a: float`, `b: float` |
| `max` | `float` | `max(a, b)` | `maxf(a, b)` | `a: float`, `b: float` |
| `clamp` | `float` | `clamp(x, lo, hi)` | `clampf(x, lo, hi)` | `x, lo, hi: float` |
| `lerp` | `float` | `lerp(from, to, t)` | `lerpf(from, to, t)` | `from, to, t: float` |
| `distance` | `float` | `distance(x1,y1, x2,y2)` | `Vector2(x1,y1).distance_to(Vector2(x2,y2))` | `x1,y1,x2,y2: float` |
| `angle` | `float` | `angle(x1,y1, x2,y2)` | `Vector2(x2-x1,y2-y1).angle()` | `x1,y1,x2,y2: float` |
| `variable` | `Variant` | `variable(name)` | `_sheet_vars[name]` | `name: String` |
| `str` | `String` | `str(x)` | `str(x)` | `x: Variant` |
| `int` | `int` | `int(x)` | `int(x)` | `x: Variant` |
| `float` | `float` | `float(x)` | `float(x)` | `x: Variant` |

---

## Implementation Plan

### Phase 1 — Spec (this document) ✅
Document the full vocabulary and Godot mapping. Merge into `docs/spec/`.

### Phase 2 — ACEDefinitions scaffold (next PR)
Create `addons/eventsheet/system_aces/system_ace_definitions.gd` that exposes an
`Array[ACEDefinition]` for each group above. Wire into `EventSheetACERegistry` as
the built-in provider so the ACE picker always shows `System` as the first category.

### Phase 3 — Runtime interpreter (deferred)
The EventSheet compiler/runner will call these ACEs via the `SystemACERuntime`
singleton. Coroutine actions (`wait`) use `await` inside the compiled script. This
phase is out of scope until the compiler pipeline is implemented.

---

## Differences from Construct 3

| Topic | Construct 3 | Godot variant |
|---|---|---|
| Group enable/disable | Runtime only | Stored on `EventGroup.enabled`; reflected at edit time |
| Wait | Coroutine expression | `await` in compiled GDScript |
| Save/Load | Built-in snapshot | Not planned — project-level save is handled by the game |
| Layout change | `Go to layout` | `change_scene_to_file` |
| Object creation | `Create object at x,y` | `instantiate()` + `add_child()` — complex, requires typed node support |

---

## Notes for Future Implementors

- Keep provider ID exactly `"system"` — the ACE picker sorts providers alphabetically and `"system"` will appear near the end of the list; consider adding a `priority: int` field to `ACEDefinition` so it can be pinned to the top.
- The `variable(name)` expression should resolve against the sheet's variable store at runtime, not the GDScript local scope.
- Input conditions should be pure reads from Godot's `Input` singleton, with no frame-level buffering unless the sheet runner exposes that abstraction.
- For the `wait` action, the sheet runner must be coroutine-aware; a simple `while` loop interpreter cannot support it without `await`.
