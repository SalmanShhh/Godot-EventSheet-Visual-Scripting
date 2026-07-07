# Move To 3D - Glide a Node3D Through a Queue of Points

Move To 3D is a Godot EventSheets behavior pack for point-to-point movement in 3D. You attach a `MoveTo3DBehavior` node as a child of any `Node3D` - a drone, an elevator platform, a pickup, a camera rig - and that parent becomes the thing that moves. You hand it one or more `Vector3` targets and it glides the host straight toward each one at a steady speed, popping stops off a queue as it reaches them, and firing a trigger when the last stop is reached. There is no path id or agent id to pass around: every Action and the Trigger act on the behavior living on the node you drop it on. You set a destination with **Move To Position (3D)**, chain extra stops with **Add Waypoint (3D)**, cancel early with **Stop Moving (3D)**, and react in **On Arrived (3D)**. Tune the pace with a single `max_speed` Inspector knob instead of writing movement code.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Patrolling drones and guards.** Queue a loop of `Vector3` stops and let the drone walk the circuit, then re-issue the loop when On Arrived fires at the end.
- **Elevators and moving platforms.** A button press sends a platform to the next floor's position; another press sends it back. No tween code, no per-frame math.
- **Homing pickups and coins.** When the player gets near, tell the pickup to Move To Position at the player's spot so it drifts into the purse.
- **Camera rigs and framing marks.** Glide a camera pivot to a scripted vantage point for a reveal, then glide it back to the follow position.
- **Sliding doors and gates.** Move the door mesh to its open position, and on the way-back trigger send it home to seal.
- **Cutscene actor blocking.** March an actor along a short path of marks during a scripted beat and continue the scene when it lands.
- **Enemies advancing to attack positions.** Send a flyer to a firing spot, and start its attack the moment On Arrived reports it is in place.
- **Multi-stop delivery routes.** A courier or cargo lift threads several Add Waypoint stops in order and signals only once, at the final drop.
- **Puzzle platforms that pause at stations.** A platform rides to a station, waits for a switch, then rides to the next - one Move To Position per leg.
- **Return-to-home objects.** A turret head or crane arm that has wandered can be sent back to its rest position with a single call.
- **Space ships and vehicles on a lane.** Chain waypoints into a flight path so a ship banks from marker to marker along a set route.
- **Timed reveals and set dressing.** Slide a prop into frame on a stimulus and out again on the arrival trigger, no animation track required.

---

## Core concepts

The model is tiny. Four ideas cover the whole pack.

**The host is the thing that moves.** You attach a `MoveTo3DBehavior` as a child of a `Node3D`. That parent is the host. Every Action moves the host's `position`, and the arrival Trigger fires on the behavior. One behavior moves one host - a platform gets its own, a drone gets its own.

**A waypoint queue, not a single target.** Internally the behavior holds an ordered list of `Vector3` stops. Each frame, while it is moving, it slides the host straight toward the front stop at `max_speed`. When the host lands on that stop (within a hair, 0.05 units), the stop is popped and it starts toward the next one. This is what lets one call describe a whole path.

**Two ways to fill the queue - replace or append.** **Move To Position (3D)** clears the queue and puts a single point in it, so it means "go here now, forget everything else." **Add Waypoint (3D)** appends a point to the end, so it means "and then go here too." Start a path with Move To Position, then chain Add Waypoint calls to add stops. Both calls set the behavior moving.

**On Arrived fires once, at the final stop.** The Trigger **On Arrived (3D)** fires only when the queue empties - that is, when the host reaches the last remaining waypoint. It does not fire at each intermediate stop. **Stop Moving (3D)** clears the queue without firing it, so a cancel stays silent. That split - arrival signals, cancels do not - is what keeps your reactions clean.

A few details worth holding in your head: movement is a straight line with no pathfinding and no obstacle avoidance, and no turning - the host slides but does not rotate to face travel. The pace is `max_speed` units per second, read live every frame, so changing the knob mid-move takes effect at once. The behavior moves the host's local `position`, so the coordinates you pass are in the host's parent space - for a top-level Node3D that is world space; for a nested node they are relative to its parent.

---

## Setup

**1. Attach the behavior.** Add a `MoveTo3DBehavior` node as a child of the `Node3D` you want to move (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in as a child). The behavior grabs its parent as the host on entering the tree; if the parent is not a `Node3D` it warns and does nothing.

**2. Set the Inspector knob.** Select the behavior node and set how fast it should travel:

| Property | Default | What it does |
|---|---|---|
| `max_speed` | `5.0` | Units per second the host glides toward the current waypoint. Read live every frame, so changing it mid-move takes effect immediately. |

**3. Give it somewhere to go, then react on arrival.** Here is a complete first move - a drone flies to a point and lights up when it lands:

```
On Ready
  -> Drone | MoveTo3DBehavior: Move To Position (3D)  12, 0, -8

On Arrived (3D)
  -> Drone: play "landed" sound
  -> Drone: flash the beacon light
```

`Move To Position (3D)` seeds the queue with one stop and starts the glide; the host reaches `(12, 0, -8)` at `max_speed`, the queue empties, and `On Arrived (3D)` fires your reaction. To make it a path instead of a single hop, chain waypoints:

```
On Ready
  -> Drone | MoveTo3DBehavior: Move To Position (3D)  12, 0, -8
  -> Drone | MoveTo3DBehavior: Add Waypoint (3D)  12, 0, 8
  -> Drone | MoveTo3DBehavior: Add Waypoint (3D)  -6, 0, 8
```

Now the drone visits all three stops in order and fires `On Arrived (3D)` only once, when it reaches the last one.

---

## ACE reference

All ACEs live in the **Move To 3D** category and act on the `MoveTo3DBehavior` behavior of the node they are placed on. There is no path or agent id parameter anywhere.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Move To Position (3D) | `x` (float), `y` (float), `z` (float) | Replaces the queue with this single point and starts gliding toward it. Use it for "go here now, cancel any current path." |
| Add Waypoint (3D) | `x` (float), `y` (float), `z` (float) | Appends a stop to the end of the queue and keeps the host moving. Chain several after a Move To Position to build a path. |
| Stop Moving (3D) | (none) | Clears the queue and halts the host in place without firing On Arrived. Use it for cancels and interrupts. |

### Conditions

This pack defines no conditions of its own. Test movement state with your own event logic (for example, a variable you set in `On Arrived (3D)`), or read the host's `position` directly in a core Expression Is True condition.

| Condition | Parameters | Description |
|---|---|---|
| (none) | - | Move To 3D ships no conditions. |

### Expressions

This pack defines no expressions of its own. The host's own `position` is available through normal node access when you need to read where it is.

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| (none) | - | - | Move To 3D ships no expressions. |

### Triggers

| Trigger | Fires when |
|---|---|
| On Arrived (3D) | The host reaches the last waypoint and the queue empties. Fires once per completed move, not once per intermediate stop. Stop Moving (3D) does not fire it. |

### Inspector properties

| Property | Type | Default | What it does |
|---|---|---|---|
| `max_speed` | float | `5.0` | Units per second the host travels toward the current waypoint. |

---

## Use cases

Each example acts on the `MoveTo3DBehavior` of the named node. Coordinates are `Vector3` points in the host parent's space.

### 1. Send a drone to a single point

The simplest move. One call seeds one stop, and the arrival trigger tells you it landed.

```
On Ready
  -> Drone | MoveTo3DBehavior: Move To Position (3D)  20, 2, -5

On Arrived (3D)
  -> Drone: start hover idle
```

### 2. A looping patrol path

Chain stops with Add Waypoint, then re-issue the whole loop when it finishes so the drone circles forever.

```
On Ready
  -> Guard | MoveTo3DBehavior: Move To Position (3D)  -10, 0, -10
  -> Guard | MoveTo3DBehavior: Add Waypoint (3D)  10, 0, -10
  -> Guard | MoveTo3DBehavior: Add Waypoint (3D)  10, 0, 10
  -> Guard | MoveTo3DBehavior: Add Waypoint (3D)  -10, 0, 10

On Arrived (3D)
  -> Guard | MoveTo3DBehavior: Move To Position (3D)  -10, 0, -10
  -> Guard | MoveTo3DBehavior: Add Waypoint (3D)  10, 0, -10
  -> Guard | MoveTo3DBehavior: Add Waypoint (3D)  10, 0, 10
  -> Guard | MoveTo3DBehavior: Add Waypoint (3D)  -10, 0, 10
```

On Arrived fires only at the final corner, which is exactly when you want to restart the lap.

### 3. Ping-pong between two marks

A shuttle that bounces back and forth. Track which end it is heading to with a boolean and flip it each arrival.

```
On Ready
  -> Shuttle | MoveTo3DBehavior: Move To Position (3D)  0, 0, 15
  -> Set variable  going_far = true

On Arrived (3D)
  Condition: going_far  is true
    -> Shuttle | MoveTo3DBehavior: Move To Position (3D)  0, 0, -15
    -> Set variable  going_far = false
  Condition: going_far  is false
    -> Shuttle | MoveTo3DBehavior: Move To Position (3D)  0, 0, 15
    -> Set variable  going_far = true
```

Because Move To Position replaces the queue, each arrival cleanly reverses direction with no leftover stops.

### 4. An elevator called between floors

A button sends the platform up; another button sends it down. Move To Position replaces any in-progress trip, so a mid-ride recall just redirects it.

```
On "up" button pressed
  -> Platform | MoveTo3DBehavior: Move To Position (3D)  0, 12, 0

On "down" button pressed
  -> Platform | MoveTo3DBehavior: Move To Position (3D)  0, 0, 0

On Arrived (3D)
  -> Platform: play "ding" sound
  -> Platform: open the doors
```

### 5. A pickup that drifts to the player

When the player steps into the magnet radius, aim the pickup at the player's position so it glides into the purse.

```
On magnet area body entered (Player)
  -> Coin | MoveTo3DBehavior: Move To Position (3D)  Player.global_position.x, Player.global_position.y, Player.global_position.z

On Arrived (3D)
  -> add 1 to score
  -> Coin: queue_free()
```

### 6. Cancel a move on command

Stop Moving halts the host where it is without firing On Arrived, so an interrupt stays silent while a genuine arrival still signals.

```
On "halt" button pressed
  -> Drone | MoveTo3DBehavior: Stop Moving (3D)
  -> Drone: play "power down" sound

On Arrived (3D)
  -> Drone: play "arrived" chime
```

The chime only plays on a real arrival, never on a cancel - that is the point of Stop Moving not firing the trigger.

### 7. A camera rig that glides to a vantage point

On a reveal cue, send the camera pivot to a framing mark; when it lands, hold there and start the reveal.

```
On reveal cue
  -> CameraRig | MoveTo3DBehavior: Move To Position (3D)  8, 6, 8

On Arrived (3D)
  -> begin the reveal timeline
```

### 8. A sliding door that opens then reseals

Open the door by moving the panel aside; a timer or trigger later sends it home. Two Move To Position calls, one destination each.

```
On player near door
  -> DoorPanel | MoveTo3DBehavior: Move To Position (3D)  0, 4, 0

On player left door
  -> DoorPanel | MoveTo3DBehavior: Move To Position (3D)  0, 0, 0

On Arrived (3D)
  -> DoorPanel: play "latch" sound
```

### 9. A cutscene actor walking its marks

Queue a short blocked path for a scripted beat and let the scene continue when the actor reaches the final mark.

```
On cutscene beat start
  -> Actor | MoveTo3DBehavior: Move To Position (3D)  2, 0, 4
  -> Actor | MoveTo3DBehavior: Add Waypoint (3D)  5, 0, 4
  -> Actor | MoveTo3DBehavior: Add Waypoint (3D)  5, 0, 1

On Arrived (3D)
  -> advance to the next cutscene beat
```

Only the final mark fires On Arrived, so the scene advances exactly when the actor stops.

### 10. An enemy advancing to a firing position

Send a flyer to a firing spot and start its attack the instant it is in place.

```
On combat start
  -> Turret | MoveTo3DBehavior: Move To Position (3D)  0, 5, -12

On Arrived (3D)
  -> Turret: begin firing sequence
```

### 11. A multi-stop delivery route

A cargo lift threads several stations in order and reports only when it drops at the last one.

```
On dispatch
  -> Cargo | MoveTo3DBehavior: Move To Position (3D)  -8, 0, 0
  -> Cargo | MoveTo3DBehavior: Add Waypoint (3D)  0, 0, -8
  -> Cargo | MoveTo3DBehavior: Add Waypoint (3D)  8, 0, 0
  -> Cargo | MoveTo3DBehavior: Add Waypoint (3D)  8, 0, 8

On Arrived (3D)
  -> unload the cargo
  -> mark route complete
```

### 12. A puzzle platform that waits at each station

Instead of one long path, send the platform one leg at a time and let a switch trigger the next leg. Each leg fires its own On Arrived because the queue empties between calls.

```
On lever A pulled
  -> Platform | MoveTo3DBehavior: Move To Position (3D)  0, 0, 10

On lever B pulled
  -> Platform | MoveTo3DBehavior: Move To Position (3D)  0, 4, 10

On Arrived (3D)
  -> Platform: play "clunk" and lock in place
```

### 13. A slow drift versus a fast dash on the same node

`max_speed` is read live each frame, so set it right before you issue the move to pick the pace for that trip.

```
On stealth approach
  -> Sentry | MoveTo3DBehavior: set max_speed = 2.0
  -> Sentry | MoveTo3DBehavior: Move To Position (3D)  0, 0, -20

On alarm raised
  -> Sentry | MoveTo3DBehavior: set max_speed = 12.0
  -> Sentry | MoveTo3DBehavior: Move To Position (3D)  Player.global_position.x, 0, Player.global_position.z
```

Because `max_speed` is exposed by the behavior, you can set it from the sheet the same way you set any node property.

### 14. Return a strayed object home

A crane arm or camera that has moved off can be sent back to its rest position with one call, and you can confirm it docked on arrival.

```
On "reset" button pressed
  -> CraneArm | MoveTo3DBehavior: Move To Position (3D)  0, 8, 0

On Arrived (3D)
  -> CraneArm: play "docked" sound
```

---

## Tips and common mistakes

- **On Arrived (3D) fires only at the final stop.** When you chain several Add Waypoint stops, the trigger fires once, when the whole queue empties - not once per waypoint. If you need a reaction at an intermediate stop, issue that leg as its own Move To Position so the queue empties there and fires the trigger.
- **Move To Position replaces, Add Waypoint appends - order matters.** Move To Position clears the queue first, so calling it after building a path throws that path away. Build a path as one Move To Position followed by Add Waypoint calls, and never put a Move To Position in the middle of a path you are assembling.
- **Stop Moving (3D) is silent by design.** It clears the queue without firing On Arrived, so a cancel or interrupt never trips your arrival reactions. Use it for recalls and aborts; use Move To Position when you want to redirect and still get an arrival at the new spot.
- **Coordinates are in the host's parent space, not always world space.** The behavior moves the host's local `position`. For a top-level Node3D that is world space, but for a nested node the numbers are relative to its parent. If a move lands in the wrong place, check whether the host sits under a moving or offset parent.
- **It moves in a straight line with no pathfinding.** The host slides directly toward each point and will pass through walls or props in the way. Lay out waypoints that hug your intended route rather than expecting the behavior to route around obstacles.
- **The host slides but does not turn.** Move To 3D only translates the host; it never rotates it to face the travel direction. If you want the mesh to point where it is going, drive its rotation yourself in your own event logic.
- **max_speed is read live, so change it before the move.** The pace is sampled every frame, so setting `max_speed` mid-trip changes the current glide at once. Set it right before the Move To Position call when you want that trip at a specific speed.
- **The host must be a Node3D.** The behavior takes its parent as the host on entering the tree and warns if the parent is not a Node3D. Attach it directly under the 3D node you mean to move, not under a plain Node or a Control.
- **A stray Move To Position while moving reroutes instantly.** Since it replaces the whole queue, calling it during a trip abandons the remaining path and heads straight for the new point. That is handy for redirects, but it means an accidental call cancels a route you were partway through.
