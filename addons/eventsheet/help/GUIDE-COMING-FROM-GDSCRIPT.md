# Coming from GDScript

You already know Godot. You open a `.gd` file as a sheet, and it says **Destroy** where you wrote
`queue_free()`, **Every tick** where you wrote `_process`, and **Wait for** where you wrote `await`.
Nothing has been rewritten - the file on disk is byte for byte the file you saved - but the words on
screen are the sheet's, and this page is the dictionary for them.

It is the mirror of the glossary for people arriving from another event-sheet editor: same idea,
opposite direction. Every entry below names the Godot word you know, the word this editor reads it
as, and where to go to see the two side by side.

> The full machine-generated list - every call, property and idiom the reading recognises, with the
> row it maps to - is **Manual ▸ Dictionary: GDScript to events**. This page is the short version: the
> two dozen words that account for most of the confusion.

## The words

| You wrote | The sheet reads it | Where to look |
| --- | --- | --- |
| `queue_free()` | Destroy / Queue Free | the object's own actions |
| `_process(delta)` | Every tick | the event's own condition lane |
| `_physics_process(delta)` | Every physics tick | the event's own condition lane |
| `_ready()` | On start of layout | triggers |
| `_input(event)` | the input conditions (Key Is Down, On Control Pressed) | Keyboard, Mouse, Gamepad |
| `signal` | trigger | Triggers on any object's page |
| `emit_signal(...)` / `x.emit()` | Emit Signal | Signals |
| `connect(...)` | Connect Signal | Signals |
| `await` | Wait for | System |
| `await get_tree().create_timer(t).timeout` | Wait `t` seconds | System |
| `match` | a chain of Else-if conditions, one case per sub-event | conditions |
| `match state:` on this object's own state | one row per arm, each reading **Is in Patrol** - the enum + variable + `match` machine every tutorial writes opens as the states vocabulary, and a `state = State.CHASE` inside an arm reads **Go to Chase**. The arm's body stays verbatim, so the whole `match` saves back byte for byte | Object State |
| `enum State { … }` + `var state: State` | the **states** band on the sheet head: `Patrol · Chase · Stagger - starts in Patrol` | the sheet head |
| `state = State.CHASE` (and `self.state = …`) | Go to Chase | Object State |
| `state == State.PATROL`, `previous_state == State.CHASE` | Is in Patrol, Was in Chase | Object State |
| `state == State.X and (Time.get_ticks_msec() - state_entered_msec) / 1000.0 > 2.0` | Is in X for over 2s - one row, not a row plus a wall of arithmetic | Object State |
| `func _on_state_changed(from_state, to_state)` | On leaving X / On entering X, leaving first - when the handler's `from_state` arms sit above its `to_state` arms, which is the order they run in | Object State |
| `extends` | family / base class (the word follows View ▸ Familiar Words) | the Object bar |
| `class_name` | the object's own name in the Object bar | the Object bar |
| `@export var` | Instance variable · Inspector | Object properties |
| `var` inside a function | Local variable, then a Set row | System |
| `const` | Constant | System |
| `add_to_group("x")` | Add To Group (Add to family with Familiar Words on) | Groups |
| `is_in_group("x")` | Is In Group | Groups |
| `get_tree().change_scene_to_file(...)` | Go To Layout | Scene |
| `instantiate()` + `add_child(...)` | Create object | Nodes |
| `is_on_floor()` | Is On Floor | General Conditions |
| `is_on_wall()` | Is By Wall | Collisions |
| `rotation_degrees` | angle | Object properties |
| `create_tween().tween_property(...)` | Tween Property | Tween |
| `set_process(false)` | Set Node Per-Frame Processing | Nodes: Activation |
| `print(...)` | Log | Debug |
| `x = clampf(x, a, b)` | Keep `x` between `a` and `b` | Math & Random |
| `x = lerp(x, to, 0.1)` | Move `x` toward `to` by 10% each tick | Math & Random |
| `x = wrapf(x, a, b)` | Wrap `x` around `a`..`b` | Math & Random |
| `y = remap(x, …)` | Rescale `x` from one range into another | Math & Random |
| `position += transform.x * s * delta` | Move forward `s`/s - its own facing | Movement |
| `global_position += Vector2.RIGHT * s * delta` | Move right `s`/s - the world's way | Movement |
| `global_position += -basis.z * s * delta` | Move forward at `s` (3D) | 3D: Move & Turn |
| `(p - c).rotated(...)` | Turn around `c` at a rate | Movement |
| `rotate_toward(...)` | Face a target at a top speed | Movement |
| `deg_to_rad(45)` | an angle field holding 45 - degrees is what a plain number means | any angle field |
| `PI/4` | an angle field holding PI/4, which stays radians and says so | any angle field |

## Three things that surprise people

**An angle is degrees unless it says otherwise.** There is no unit to pick anywhere in the
editor: type 45 and it means 45 degrees, and the code says `deg_to_rad(45)` because that is what
the property wants. Radians are not locked out - type `PI/4`, or say the unit out loud (`1.2 rad`),
and the field keeps what you meant with exactly the one conversion that makes it true. Whichever
way it was written, the ROW shows which unit it means, so the sentence and the code cannot quietly
disagree. A project that thinks in radians can flip what a bare number means with the
`eventsheets/angles/default_unit` setting; that changes what gets written from then on and never
re-reads a value already stored.

**A sheet row is one statement.** The reading is never denser than the code: one action per row, one
event per idea. A `var speed = 200.0` inside a function is a Local variable row followed by
`System ▸ Set speed to 200.0`, not a single cell with an assignment in it. If you count rows and
count statements, the numbers match.

**The condition lane is the `if`.** An event's left lane holds what has to be true; its right lane
holds what then happens. A sub-event is a nested `if`, an Else row is the `else`, and an event with
nothing in its condition lane runs every tick - which is exactly what a bare block of statements in
`_process` does.

**A boolean reads as a sentence.** `if alive:` is the condition `alive is true`, and `if not muted:`
is `muted is false`. The variable is still the variable; only the way it is spelled changed.

## Seeing the GDScript for any row

Three ways, all of them one click:

- **Show GDScript** on a row's page in the Manual prints exactly the code that row writes.
- **View ▸ GDScript Panel** shows the whole sheet's generated code beside the sheet, live.
- **Right-click a row ▸ Explain This Row** answers "what does this actually do" in one card, with
  the code under it.

## Finding a row by the call you know

The picker searches the code as well as the words. Type `queue_free` into **Add action** and Queue
Free answers with `queue_free()` written beside its name; `add_child` finds Add Child;
`tween_property` finds Tween Property; `is_on_floor` finds Is On Floor. The Manual's search box
answers the same way: type a Godot call and the glossary results say what it is called here.

## Your own code is vocabulary too

Nothing here asks you to stop writing GDScript. A class of your own appears in the picker with zero
setup - its methods are actions, its yes-or-no methods are conditions, its signals are triggers, and
its `@export`s are Object properties. A function you already wrote can be renamed for the sheet
without touching your source. The full story is in
[Using EventSheets with Your Existing Code](GUIDE-USING-WITH-EXISTING-CODE.md).
