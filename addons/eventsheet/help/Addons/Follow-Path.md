# Follow Path

**Follow Path** walks a node along a curve you drew. Godot's own **Path2D** is the tool an artist reaches
for first - click a few points, drag the handles, and the patrol route is a shape on screen rather than a
list of coordinates - and until this pack there was no way to reach it from an event sheet.

It is the curved sibling of the **Move To** pack. Move To glides through a queue of straight-line
waypoints; this one travels a drawn curve at a real speed, paced by arc length, so a tight corner never
speeds the traveller up. Once, Loop and Ping-pong cover the three things a route is ever asked to do, and
arrival is a trigger - **On Path Finished** - not something you poll for.

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Reading it from expressions - the Self section](#reading-it-from-expressions---the-self-section)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this pack shines

- **Patrol routes** an artist draws instead of a designer typing coordinates.
- **Tower-defence lanes** - creeps spawn from a pool, walk the lane, and hurt the base at the end.
- **Camera dollies** for cutscenes, menus and establishing shots.
- **Conveyors, elevators and moving platforms** that follow a shaped track.
- **Boss sweep patterns and scripted bullet paths** that curve instead of zig-zagging.
- **Progress readouts** - how far along the track a racer, a delivery or a lift has come.
- **Rail-shooter tracks** where the player rides a fixed route and only aims.

## Core concepts

- **The route is a Path2D node in your scene.** Draw it with Godot's own curve tool. The pack never
  creates one; it walks the one you point it at.
- **Speed is pixels per second ALONG the curve.** The pack advances an arc-length distance, not a
  fraction, so 120 means 120 whichever way the curve bends. This is the difference between a patrol that
  keeps a steady pace and one that races through corners.
- **Arrival is a signal.** A **Once** run fires **On Path Finished** the moment it reaches the end. A
  **Loop** or **Ping-pong** run has no end, so it never fires it.
- **Is At Path End answers a different question.** Not "did it just arrive" - the trigger answers that
  for free - but "is it parked at the end right now", which a row reached at any time may legitimately
  ask (a lift that should only open its doors while it is at the top).
- **The path verbs work with no run at all.** Point On Path At, Direction Along Path At, Path Length and
  Nearest Point On Path just read a curve. Use them to drive a camera, a marker or a preview ghost
  without moving the host anywhere.
- **The pack draws its route in the editor.** Select the host and the curve appears in the 2D viewport
  with a green dot at the start and an orange one at the end - so a route drawn backwards is obvious
  before you press play.

## Setup

1. Draw the route: add a **Path2D** to your scene and click out its curve.
2. **Tools > Attach to Selected Node** on the node that should travel, and pick **Follow Path**. (It
   attaches as a child; the host is its parent, and must be a **Node2D** or anything descended from one.)
3. In the Inspector, drag the Path2D onto **Route**, set **Travel Speed**, and pick a **Loop Mode**.
4. Either tick **Auto Start**, or add the row yourself:

```
On Ready
  -> Path: Follow Path  PatrolRoute, 120, Ping-pong
```

## ACE reference

### Actions

| Verb | Parameters | Notes |
|---|---|---|
| **Follow Path** | Path, Speed, Mode | Starts a run from the beginning of the route. Hands over a new route as well, so one host can walk several. |
| **Stop Following Path** | - | Halts where it stands WITHOUT firing On Path Finished. Follow Path restarts from the top. |

### Conditions

| Verb | Parameters | Notes |
|---|---|---|
| **Is Following Path** | - | True while it is actually travelling - the gate for a walk animation or a conveyor's hum. |
| **Is At Path End** | - | True while it is parked at the far end right now. For the MOMENT of arrival, use the trigger. |

### Expressions

| Verb | Parameters | Notes |
|---|---|---|
| **Progress Along Path** | - | How far the host has come, 0 at the start and 1 at the end. |
| **Point On Path At** | Path, Progress | The world point a fraction along a route. Moves nothing. |
| **Direction Along Path At** | Path, Progress | Which way the route heads there, as a direction one unit long. |
| **Path Length** | Path | How long the route is in pixels, measured along the curve. |
| **Nearest Point On Path** | Path, Point | The spot on the route closest to a world position. |

### Triggers

| Verb | Parameters | Notes |
|---|---|---|
| **On Path Finished** | - | Fires once when a **Once** run reaches the end. Loop and Ping-pong never fire it. |

### Inspector properties

| Property | Type | Default | What it does |
|---|---|---|---|
| `route` | Path2D | `<null>` | The drawn route. Follow Path can hand over a different one at runtime; this is the starting route, and the one the editor gizmo draws. |
| `travel_speed` | float | `120.0` | Pixels per second along the curve. |
| `loop_mode` | String | `once` | What happens at the end: `once`, `loop` or `pingpong`. |
| `rotate_to_face` | bool | `false` | When on, the host turns to face the direction it is travelling. |
| `auto_start` | bool | `false` | Start walking the route as soon as the scene runs, with no Follow Path row needed. |

## Reading it from expressions - the Self section

Type `self` in any ƒx field and **Self ▸ Behaviours** lists this pack's knobs and value verbs as
ready-to-insert chains once the behaviour is attached:

- `$PathFollowBehavior.travel_speed` inserts the **Travel Speed** knob straight into any expression
- `$PathFollowBehavior.progress_along_path()` inserts the progress reading, ready to drive a bar

## Use cases

**1. A guard that walks its beat forever.**

The simplest possible use: draw the beat, tick Ping-pong, and the guard walks it back and forth with no
rows at all beyond the start.

```
On Ready
  -> Path: Follow Path  Beat, 90, Ping-pong
```

**2. A tower-defence creep that hurts the base at the end of its lane.**

Arrival is the trigger, so the damage row is reached exactly once - no per-frame checking, and no risk of
hitting the base twice on a laggy frame.

```gdscript
extends Node2D


func _on_path_finished() -> void:
	get_tree().call_group("base", "take_damage", 1)
	queue_free()
```

**3. A patrol that hands over to a return route when it finishes.**

Follow Path inside On Path Finished chains routes together, which is how a two-leg patrol or a multi-stop
delivery run is built.

```
On Path Finished
  -> State Machine: Change State  "return"
  -> Path: Follow Path  ReturnRoute, 220, Once
```

**4. A camera dolly for a cutscene.**

Point On Path At moves nothing by itself, so the camera rides the curve under whatever timing you like -
a tween, a countdown, or a scrubbed cutscene timeline.

```gdscript
extends Camera2D


func _process(delta: float) -> void:
	global_position = $PathFollowBehavior.point_on_path_at($"../DollyTrack", clampf(shot_time / 4.0, 0.0, 1.0))
```

**5. A conveyor belt that can be switched off.**

Is Following Path is what a "the belt is running" sound or animation should be gated on, so the two can
never disagree.

```
On Power Cut
  -> Path: Stop Following Path
```

**6. A lift whose doors only open at the top.**

This is the Is At Path End question, not the arrival one: the row may be reached at any moment, and it
wants the state, not the edge.

```
Every Frame
  Condition: Path: Is At Path End
    Condition: Input: Action Just Pressed  "interact"
      -> Animation: Play Animation  "doors_open"
```

**7. A progress bar for a delivery run.**

```gdscript
extends Node2D


func _process(delta: float) -> void:
	$"../HUD/DeliveryBar".value = $PathFollowBehavior.progress_along_path() * 100.0
```

**8. A boss that sweeps the arena on a curve.**

Draw the sweep once, set Loop, and the pattern repeats forever without a state machine counting corners.

```
On Phase Started
  -> Path: Follow Path  SweepArc, 400, Loop
```

**9. An arrow, fish or car that points where the track is going.**

Tick **Rotate To Face** in the Inspector. The host turns along the curve automatically, including
backwards on the return leg of a Ping-pong run.

**10. Spacing a train of carts evenly along a track.**

Path Length divided by the number of carts gives the gap; Point On Path At places each one, with no
trigonometry and no manual coordinates.

```gdscript
extends Node2D


func _ready() -> void:
	for index in 5:
		var cart = $CartScene.duplicate()
		cart.global_position = $PathFollowBehavior.point_on_path_at($Track, float(index) / 5.0)
		add_child(cart)
```

**11. Snapping a dragged tower onto the lane.**

```gdscript
extends Node2D


func _on_drag_released() -> void:
	global_position = $PathFollowBehavior.nearest_point_on_path($Lane, get_global_mouse_position())
```

**12. Aiming a spawned thing down the track.**

Direction Along Path At hands back a direction one unit long, which is exactly what a velocity or a
Look At wants.

```gdscript
extends Node2D


func _on_spawned() -> void:
	rotation = $PathFollowBehavior.direction_along_path_at($Track, 0.0).angle()
```

**13. Timing a wave to the length of its lane.**

Path Length divided by the creep's speed is how many seconds the walk takes, which is the number an
encounter timeline needs to space its beats.

```gdscript
extends Node


func _ready() -> void:
	var seconds: float = $PathFollowBehavior.path_length($LaneA) / 120.0
	print("lane A takes %.1f seconds" % seconds)
```

**14. A moving platform that waits at each end.**

Once plus On Path Finished plus a Wait gives a platform that pauses, which Ping-pong alone does not.

```
On Path Finished
  -> System: Wait  1.5
  -> Path: Follow Path  PlatformTrack, 80, Once
```

**15. An elevator the player can call.**

Follow Path takes the route as a parameter, so calling the lift up and sending it down are the same verb
pointed at two different curves.

```
On Button Pressed
  -> Path: Follow Path  ShaftUp, 140, Once
```

**16. A homing missile that curves rather than turning on the spot.**

Draw the approach arc once and every missile that follows it looks hand-animated, at no per-frame cost.

**17. A coin arcing to the counter.**

A short curve from the pickup to the HUD corner, walked Once at a high speed, is the whole "coin flies to
the score" effect - and On Path Finished is where the score goes up.

```
On Path Finished
  -> Variables: Add  1  to  score
  -> Object Pool: Despawn  self
```

### Other use cases

**Rail shooter.** Put the camera on a Loop route and let the player only aim; the whole level's pacing
becomes a curve you can drag rather than a script you have to edit.

**Race position readout.** Give every racer the same route and sort them by Progress Along Path to get
"3rd of 8" with no checkpoint bookkeeping at all.

**Scripted bullet-hell arc.** Spawn each shot with Follow Path on a shared curve and a small delay
between them, and a hand-drawn ribbon of bullets sweeps the screen.

**Cable car and ski lift.** Ping-pong on a sagging curve with Rotate To Face gives the whole ride,
including the tilt at each end, from two Inspector knobs.

**Fish and bird ambience.** A dozen hosts on the same Loop route at slightly different speeds reads as a
shoal, and costs one curve.

## Tips and common mistakes

- **Point the Route at a Path2D, not at its parent.** The slot takes the Path2D node itself; a Node2D
  that merely contains one has no curve, and Follow Path quietly refuses to start.
- **A Path2D with fewer than two points has no length.** Follow Path refuses such a route rather than
  starting a run that could never move, so a host that will not budge is usually a route with one point.
- **Ping-pong and Loop never fire On Path Finished.** They have no end. If your arrival branch never
  runs, check the Loop Mode first.
- **Stop Following Path does not fire it either**, deliberately: cancelling is not arriving. Emit your
  own signal, or set a variable, if a cancelled run needs its own branch.
- **Follow Path always restarts from the beginning.** There is no "resume" - call it once and let the run
  proceed, or drive the position yourself with Point On Path At.
- **Speed is along the curve, not across the screen.** A route that doubles back covers a lot of length
  in a small area, so a "slow" speed can still look fast on screen. Path Length tells you what you are
  actually asking for.
- **The host must be a Node2D.** The behaviour warns in the console when its parent is not one, and does
  nothing rather than half-working.
- **Moving the Path2D moves the route.** Positions are read through the path node, so a route parented to
  a moving ship travels with the ship - which is either exactly what you wanted or a very confusing bug.
- **Rotate To Face turns the HOST, not the behaviour.** If your sprite is drawn facing up rather than
  right, rotate the sprite inside the host once instead of fighting the rotation every frame.
