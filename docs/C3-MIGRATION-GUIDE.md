# Construct 3 → Godot EventSheets Migration Guide

A working map from C3 concepts and vocabulary to their Godot EventSheets equivalents.
The golden rule: **everything compiles to plain GDScript** — when this table doesn't
cover something, the GDScript way *is* the EventSheets way (drop a GDScript block in the
event flow, or write the expression directly — `ƒx` fields are plain GDScript).

## Concepts

| Construct 3 | Godot EventSheets |
|---|---|
| Event sheet | Event sheet (`.tres`), attached to a host node class; compiles to a `.gd` script |
| Object type | Godot node class (CharacterBody2D, Area2D, Timer…) — ACEs group under it |
| Behavior (Platform, 8Direction…) | **Behavior sheet** → attachable Node component with a typed `host` accessor (samples: PlatformerMovement, EightDirectionMovement) |
| Plugin / addon (JSON manifests) | **Zero-config addon**: a script in `res://eventsheet_addons/` with `@ace_*` annotations — no manifests |
| Instance variables | Sheet variables (typed; exported ones appear in the Inspector per instance) |
| Local/temp variables | Variables placed inside the event flow → function locals |
| Global variables | Sheet variables on a shared/autoload sheet, or any autoload — plain GDScript rules |
| Groups | Groups (collapsible, nestable, with local variables) |
| Comments (colored) | Comments — multiline, per-comment colors, attachable into an event's actions |
| Sub-events | Sub-events (compile nested under the parent's conditions) |
| Else | Else / Else-If events (compile to `elif` / `else`) |
| Families | No direct equivalent — use Godot groups/class inheritance (`get_tree().get_nodes_in_group()`), or a behavior shared across nodes |
| Layouts | Scenes |
| Layers | CanvasLayers / scene tree order |
| The expression language | **GDScript** — there is no separate language to learn |
| Scripting (JS blocks) | GDScript blocks: class-level or in-flow inside events, with lint + completion |
| Functions (event sheets) | Sheet functions — callable as actions, optionally **exposed as ACEs** project-wide |
| Timer behavior | Timer node + `On Timeout` trigger |
| Tween behavior | Godot's built-in tweens via a GDScript block (`create_tween()…`) |

## Common System vocabulary

| Construct 3 | Godot EventSheets / generated GDScript |
|---|---|
| Every tick | `On Process` trigger (`_process(delta)`) |
| On start of layout | `On Ready` trigger (`_ready()`) |
| Compare variable | Expression condition, e.g. `health < 50` (plain GDScript) |
| Set variable / Add to | `Set Variable` / `Add To Variable` actions, or `health += 10` in ƒx |
| On collision / overlap | `On Body Entered` / `On Area Entered` (Area2D) — connections are generated |
| Destroy | `Queue Free` |
| Set position / angle | `Set Position` / `Set Rotation` (Node2D) |
| Simulate control (Platform) | PlatformerMovement behavior ACEs (`Jump`, `Set Move Speed`) |
| Wait | An `await`-flagged action, or `await get_tree().create_timer(1.0).timeout` in a block |
| Pick by comparison / For each | No picking system (Godot has no object lists per type) — iterate in a GDScript block: `for enemy in get_tree().get_nodes_in_group("enemies"):` |
| random(a, b) | `randf_range(a, b)` / `randi_range(a, b)` |
| dt | `delta` |
| lerp(a, b, x) | `lerp(a, b, x)` |
| clamp / min / max / abs | Same names in GDScript |

The picker's search understands C3 phrasing ("every tick", "on created", "spawn"…) via
synonym aliases, so type what you know and the Godot equivalent surfaces.

## Habits that transfer directly

- Double-click empty space to add an event; right-click for context actions.
- Drag conditions/actions to reorder; drag events onto events to nest sub-events.
- Copy/paste works across projects (snippet text on the system clipboard) — and **pasting
  plain GDScript converts to events automatically** when it contains trigger functions.
- Behaviors are added to objects (here: child nodes via the Create Node dialog) and
  configured per-instance in the Inspector.

## Habits to relearn (the Godot way is better here)

- **There is no runtime**: your sheet *is* GDScript after compiling. Read the generated
  script in the GDScript panel — selection highlights both ways. Performance equals
  hand-written code (a tested contract).
- **No object picking**: Godot addresses nodes explicitly (paths, groups, signals). Most
  C3 "pick" logic becomes a `for` loop block or a signal connection.
- **Scenes replace layouts** and instancing replaces "create object by name" — spawn via
  `preload("res://enemy.tscn").instantiate()` in a block or action.
