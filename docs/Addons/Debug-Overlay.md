# Debug Overlay

**Debug Overlay** is the `DebugOverlay` autoload singleton: the throwaway heads-up display every
project ends up hand-rolling, driven entirely from event rows. Watch a named value, draw a bar, mark
a world point, draw a ray, label a node. It paints on the **game**, which is where Print cannot help
you: the Output panel is invisible in fullscreen, absent on a phone or a console, and gone entirely
in the exported build a playtester is running.

Three properties keep it out of your way, and all three are enforced in the code it ships as. It is
**off until a row asks for it** (the drawing surface is created by the first row that calls it, so a project
with no Debug Overlay rows creates no node and draws nothing). It is **debug builds only** (the same
`OS.is_debug_build()` gate the builtin Log (Debug Builds Only) action uses, so an exported release
carries none of it). And it is **never on the sheet**: it draws over the running game, no row gains a
chip or a readout, and the editor canvas is not touched at all. Press the toggle key to hide it while
you play.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Reading it from expressions - the Self section](#reading-it-from-expressions---the-self-section)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this pack shines

- **Tuning movement feel** without alt-tabbing to read numbers in a console.
- **Debugging on a phone, a console, or a tester's exported build**, where no Output panel exists.
- **Visualizing AI**: targets, paths, detection cones, and per-enemy state, all at once.
- **Spatial bugs** where the position is the answer and a printed vector is not.
- **Live tuning with a designer behind you**, reading the same numbers you are.
- **Bug reports whose screenshots carry the state that caused them.**
- **Devlog and trailer footage** with the internals visible on screen.
- **A dozen enemies at once**, each carrying its own state as a floating label.
- **A throwaway bar** over a node while tuning damage, without touching the real health bar.
- **Proving a raycast is where you think it is**, which it usually is not.

## Core concepts

- **It is an autoload, so it is global.** Any sheet, any node, any scene calls the same overlay by
  name. There is nothing to attach and nothing to wire up.
- **A watch is keyed by name.** Watch Value with the same name refreshes the line rather than adding
  a second one, which is what makes it safe to call from an Every Frame row.
- **Marks, rays and labels are timed.** Each carries a number of seconds, ages itself out on the
  overlay's own tick, and disappears. Nothing accumulates forever.
- **World positions stay glued to the world.** Marks and rays are drawn through the viewport's canvas
  transform, so they sit where the thing is while the camera moves.
- **Label Above works in 2D and in 3D.** A Node2D or a Control uses its screen position; a Node3D is
  projected through the active Camera3D.
- **The overlay is one CanvasLayer at layer 128**, above everything your game draws, with mouse input
  ignored so it can never eat a click.
- **Hiding is not clearing.** Hide Overlay leaves every value recorded, so showing it again brings
  them straight back. Clear Overlay is the one that wipes.
- **On Overlay Toggled is a real signal** carrying whether the overlay is now shown, so a sheet can
  react to the toggle key like any other trigger.

## Setup

**Tools > Register Autoload** installs it once, under the name `DebugOverlay`. That is the whole
setup: the picker then grows a **Debug Overlay** section and its vocabulary drops into any sheet like any
other pack's. There is no **Tools > Attach to Selected Node** step, because it is a singleton rather
than a behavior.

Two properties are on the autoload node in the Inspector:

| Property | Default | What it does |
|----------|---------|--------------|
| `toggle_key` | `"F3"` | The key that shows and hides the overlay while the game runs, written by name (`F3`, `F1`, `Tab`, `Escape`). Leave it blank for no key at all. |
| `start_hidden` | `false` | Start with the overlay hidden. Rows still record; nothing is drawn until you press the toggle key. |

## ACE reference

### Actions

| Name | What it does | Ships as |
|------|--------------|----------|
| Watch Value | Shows name = value in the on-screen list, refreshed every time you set it. | `DebugOverlay.watch_value({watch_name}, {value})` |
| Clear Watch | Drops one named value from the on-screen list. | `DebugOverlay.clear_watch({watch_name})` |
| Show Bar | Draws a named meter filled to a fraction from 0 to 1, in the colour you pick. | `DebugOverlay.show_bar({bar_name}, {fraction}, {bar_color})` |
| Mark Point | Drops a labelled cross at a world position for a moment, so you can SEE where something happened. | `DebugOverlay.mark_point({at}, {mark_label}, {seconds})` |
| Draw Ray | Draws a line from a world position along a direction for a given length. | `DebugOverlay.draw_ray({origin}, {direction}, {length}, {ray_color}, {seconds})` |
| Label Above | Floats a line of text above a node for a moment. | `DebugOverlay.label_above({node}, {label_text}, {seconds})` |
| Show Overlay | Makes the overlay visible again after it was hidden. | `DebugOverlay.show_overlay()` |
| Hide Overlay | Hides the overlay without clearing anything. | `DebugOverlay.hide_overlay()` |
| Toggle Overlay | Flips the overlay between shown and hidden, the same thing the toggle key does. | `DebugOverlay.toggle_overlay()` |
| Clear Overlay | Wipes every watch, bar, mark, ray and label at once. | `DebugOverlay.clear_overlay()` |

### Conditions

| Name | What it does | Ships as |
|------|--------------|----------|
| Overlay Is Visible | True while the overlay is on screen. False in a release build, before any row has drawn to it, and while the toggle key has it hidden. | `DebugOverlay.is_overlay_visible()` |

### Triggers

| Name | Fires when | Payload |
|------|------------|---------|
| On Overlay Toggled | The overlay is shown or hidden, whether by a row or by the toggle key. | `shown` - whether the overlay is now visible |

The trigger only fires on a real change, so showing an already-visible overlay announces nothing and
a row under On Overlay Toggled never sees a repeat of the state it is already in.

## Reading it from expressions - the Self section

Type `self` in any ƒx field and the registered pack's entries insert as `$DebugOverlay.member`
chains, the same way every other pack exposes its innards. The one you will reach for is
`is_overlay_visible()`, so a HUD can dim itself while the debug display is up.

## Use cases

**1. A live watch window over the running game.** The single most common use: a value, updated every
frame, readable while you play in fullscreen.

```gdscript
extends Node


func _process(delta: float) -> void:
	DebugOverlay.watch_value("hp", player.health)
```

**2. Watch several values at once.** Each name is its own line, and calling the same name again
refreshes rather than duplicating, so an Every Frame row is exactly right here.

```gdscript
extends Node


func _process(delta: float) -> void:
	DebugOverlay.watch_value("hp", player.health)
	DebugOverlay.watch_value("state", current_state)
	DebugOverlay.watch_value("velocity", player.velocity)
```

**3. A stamina meter you never built any UI for.** Show Bar takes a fraction from 0 to 1 and a
colour, which is enough to see a curve you would never read as a number.

```gdscript
extends Node


func _process(delta: float) -> void:
	DebugOverlay.show_bar("stamina", stamina / 100.0, Color.LIME)
```

**4. See where a dash actually started.** Mark Point drops a cross in the world and fades it, so a
spatial bug stops being a printed vector you have to imagine.

```gdscript
extends Node


func _on_dash_started() -> void:
	DebugOverlay.mark_point(player.global_position, "dash start", 2.0)
```

**5. Show the aim vector while tuning it.** Draw Ray normalizes the direction for you, so the length
is the length in pixels no matter what you hand it.

```gdscript
extends Node


func _process(delta: float) -> void:
	DebugOverlay.draw_ray(player.global_position, aim_dir, 200.0, Color.YELLOW, 0.1)
```

**6. Debug a dozen enemies at once.** A label above each node is the fastest way to see a state
machine misbehave in a crowd, because each enemy carries its own answer.

```gdscript
extends Node


func _on_state_machine_on_state_changed() -> void:
	DebugOverlay.label_above(enemy, current_state, 1.5)
```

**7. Tune damage without touching the real health bar.** A throwaway bar over the enemy costs one
row and does not risk the UI you actually ship.

```gdscript
extends Node


func _process(delta: float) -> void:
	DebugOverlay.show_bar("boss hp", boss_health / boss_max_health, Color.ORANGE_RED)
```

**8. Make a detection cone visible while you tune it.** Two rays from the same origin are the cone,
and seeing it is the difference between guessing at the angle and setting it.

```gdscript
extends Node


func _process(delta: float) -> void:
	DebugOverlay.draw_ray(global_position, Vector2.RIGHT.rotated(rotation - 0.6), 300.0, Color.CYAN, 0.1)
	DebugOverlay.draw_ray(global_position, Vector2.RIGHT.rotated(rotation + 0.6), 300.0, Color.CYAN, 0.1)
```

**9. Watch a pathfinding graph while it runs.** Mark Point on each node of the chosen path turns an
A* result from a list of coordinates into something you can look at.

```gdscript
extends Node


func _on_path_ready() -> void:
	for point: Vector2 in current_path:
		DebugOverlay.mark_point(point, "", 1.0)
```

**10. Turn it on only when a tester asks.** Start hidden, then let the toggle key reveal it, so a
build you hand out is clean until someone presses the key.

```gdscript
extends Node


func _ready() -> void:
	DebugOverlay.hide_overlay()
```

**11. Put the toggle on a button for a playtester.** Toggle Overlay is an ordinary action, so a UI
button, a gamepad combo, or a cheat-code row all reach it.

```gdscript
extends Node


func _on_debug_button_pressed() -> void:
	DebugOverlay.toggle_overlay()
```

**12. Dim your own HUD while the overlay is up.** Overlay Is Visible is a condition, so the branch
lives in the left lane where it belongs.

```gdscript
extends Node


func _process(delta: float) -> void:
	if DebugOverlay.is_overlay_visible():
		hud.modulate.a = 0.35
```

**13. React to the toggle key as a trigger.** On Overlay Toggled carries whether the overlay is now
shown, so you can pause the game with it, or start recording, or anything else.

```gdscript
extends Node


func _on_debug_overlay_overlay_toggled(shown: bool) -> void:
	get_tree().paused = shown
```

**14. Wipe the evidence between levels.** Clear Overlay drops every watch, bar, mark, ray and label
in one row, so the next level starts from a blank screen.

```gdscript
extends Node


func _on_level_loaded() -> void:
	DebugOverlay.clear_overlay()
```

**15. Stop watching one value without wiping the rest.** Clear Watch takes a single name, and
clearing a name that was never watched is harmless.

```gdscript
extends Node


func _on_tuning_done() -> void:
	DebugOverlay.clear_watch("velocity")
```

**16. Put a performance measurement on screen instead of in the console.** The builtin stopwatch
actions record; the overlay is where you send the reading when the console is not visible.

```gdscript
extends Node


func _process(delta: float) -> void:
	DebugOverlay.watch_value("spawn ms", (float(((get_meta(&"__ef_spans", {}) as Dictionary).get("spawn wave", [0.0, 0, 0.0, 0.0]) as Array)[3])))
```

**17. Show the newest value of a trail.** A trail records silently; a watch is how you look at it
without leaving the game.

```gdscript
extends Node


func _process(delta: float) -> void:
	DebugOverlay.watch_value("vy", ([0] + ((get_meta(&"__ef_trails", {}) as Dictionary).get("vy", []) as Array)).back())
```

**18. Label a 3D node through the active camera.** Label Above projects a Node3D's position, so the
same row works in a 3D scene with no extra maths.

```gdscript
extends Node


func _process(delta: float) -> void:
	DebugOverlay.label_above(enemy_3d, enemy_3d.name, 0.2)
```

### Other use cases

**Show the spawn budget while an encounter runs.** A bar fed by the Encounter Timeline's remaining
beats turns "is this wave too long" into something you can see rather than count.

**Mark every pooled spawn and despawn.** Two Mark Point rows on the Object Pool triggers make pool
churn visible, which is how you find out a pool is thrashing instead of reusing.

**Draw the line-of-sight ray your AI is actually casting.** The Line Of Sight packs give you the
origin and direction; the overlay is what turns them into a picture while you tune the range.

**Leave a labelled cross wherever a save happens.** A mark on the Save System's success trigger tells
you at a glance whether autosave is firing where you meant it to.

**Keep a colour-coded bar per system while profiling.** One bar per subsystem, each fed by its own
Average Measured reading, is a poor man's profiler that works on the device with no tooling attached.

## Tips and common mistakes

- **Nothing appears until a row calls one of these actions.** That is deliberate: the drawing surface is built on
  the first call. If you registered the autoload and see nothing, you have not dropped a row yet.
- **Nothing appears in an exported release build either.** Every action and condition here is behind
  `OS.is_debug_build()`. Export with a debug template if you need the overlay in a build you hand out.
- **Overlay Is Visible is false before the first draw.** It answers "is there an overlay on screen
  right now", not "is the pack installed", so a startup row that checks it will get `false`.
- **Watch Value converts to text.** The value is stored as a string the moment you set it, so a
  Vector2 shows as `(12, 40)`. Format it yourself if you want fewer decimals.
- **Show Bar clamps to 0..1 when drawing.** A fraction of 2.0 draws a full bar rather than one
  running off the screen, so divide by your maximum before you pass it in.
- **A mark's seconds has a floor.** Passing 0 gives you a 50 ms flash rather than nothing at all, so
  a mark you drop every frame is always visible.
- **Draw Ray normalizes the direction.** Handing it a velocity vector is fine; the length parameter
  is the only thing that decides how long the line is.
- **Label Above needs the node to still exist.** A freed node's label is dropped on the next tick
  rather than crashing, but the label will vanish early if the node does.
- **The toggle key is a key NAME, not an input action.** `F3`, `Tab`, `Escape`. A name Godot does not
  recognise silently never matches, so check the spelling if the key does nothing.
- **Hiding is not clearing.** A hidden overlay is still recording, and showing it brings back
  everything, including values that are now several minutes stale. Clear Overlay is the reset.
- **It never draws on the event sheet.** The overlay is a CanvasLayer over the game. No row gains a
  chip, a tint or a readout, and nothing about the editor changes when the pack is installed.
