# Move To - Glide a Node to a Point, One Behavior Per Node

Move To is a Godot EventSheets behavior pack for smooth point-to-point movement. You attach a `MoveToBehavior` to a `Node2D` - a sprite, an enemy, a pickup, a cursor token - and that node gains a small waypoint engine. Hand it a point with **Move To Position** and it glides there at a steady speed; queue up several stops with **Add Waypoint** and it walks the route in order; call **Stop Moving** to cancel. When the last stop is reached it fires the **On Arrived** trigger your sheet reacts to. This is a per-node behavior, not a global singleton: every Action, Expression, and Trigger targets the Move To behavior living on the node you drop it on, so there is no target id to pass around. The host must be a `Node2D` (the behavior moves its parent's `position`).

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

- **Point-and-click movement.** Read the clicked spot and call Move To Position - the character strolls there without you writing any per-frame math.
- **Patrol routes.** Queue a handful of stops with Add Waypoint and let the guard walk the loop; re-arm it on On Arrived for an endless patrol.
- **Homing pickups.** A coin or gem flies to the player when collected - just Move To Position the player's spot.
- **Enemies taking a firing position.** Send an enemy to a spot, and on On Arrived start its attack, so movement and combat stay cleanly separated.
- **Cutscene blocking.** Walk actors onto their marks; the On Arrived trigger is your cue to advance the next beat of the scene.
- **Moving platforms and lifts.** Two waypoints and an On Arrived that flips direction gives you a ping-pong platform with no timers.
- **Tower-defense creeps.** Feed a lane's corner points as waypoints and the creep follows the path; On Arrived at the last stop means "reached the base."
- **Courier and delivery NPCs.** Chain shop, road, and doorstep stops with Add Waypoint, then hand off the package on arrival.
- **Formation and regroup moves.** Give each unit its slot with Move To Position and they all slide into place at the same tuneable speed.
- **Facing the travel direction.** Turn on Rotate Toward Motion and arrows, torpedoes, or fish automatically point where they are heading.
- **Return-to-spawn idling.** When an enemy loses the player, Move To Position its spawn point and it wanders home.

---

## Core concepts

The whole pack is one idea - a queue of points the node walks through - plus a couple of knobs. Learn these and you have all of it.

**The waypoint queue is the state.** The behavior keeps an ordered list of points (the waypoints). Each frame, while it is moving, it slides the host toward the first point in the list. When the host gets within half a pixel of that point, the point is popped off and the node heads for the next one. When the list empties, movement stops and **On Arrived** fires.

**Move To Position replaces the queue.** Calling **Move To Position** throws away whatever route was queued and sets a single destination, then starts moving. Use it for "go here now" - a click target, a new chase point, a fresh order that overrides the old one.

**Add Waypoint appends to the queue.** Calling **Add Waypoint** adds a stop to the end of the list without clearing what is already there, and starts moving if it was stopped. Chain several Add Waypoint calls to lay down a multi-stop route in order. The node visits them first-in, first-out.

**Movement is a steady glide, not a tween.** Every frame the host moves toward the current target by `max_speed` pixels, scaled by frame time. There is no easing and no arrival slowdown - it travels at a constant speed and stops on the spot. Faster or slower is just a bigger or smaller `max_speed`.

**On Arrived means the queue emptied.** The trigger fires once, at the moment the final waypoint is reached and the list runs dry. It does not fire for each intermediate stop, and it does not fire when you cancel with **Stop Moving**. That makes On Arrived a clean "the whole trip is done" signal.

**Stop Moving is a silent cancel.** **Stop Moving** clears the queue and halts the node without firing On Arrived. Use it when an order is interrupted (the target died, the player took control) and you do not want the arrival logic to run.

**Rotate Toward Motion turns the node to face travel.** With the `rotate_toward_motion` knob on, the behavior sets the host's `rotation` to point along its direction of travel every frame it moves. Leave it off for top-down sprites that should not spin; turn it on for arrows, ships, or anything that should nose into its heading.

**Speed and facing are live.** Both Inspector knobs are also readable and writable at runtime. Read the current values with the **Max Speed** and **Rotate Toward Motion** expressions, and change them on the fly with **Set Max Speed** (or nudge it with **Add To Max Speed** / **Subtract From Max Speed**) and **Set Rotate Toward Motion** - handy for speed boosts, slow fields, or toggling facing mid-game.

---

## Setup

**1. Attach the behavior.** Add a `MoveToBehavior` as a child of the `Node2D` you want to move (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in as a child). The behavior moves its parent, so the parent must be a `Node2D` - a `Sprite2D`, `CharacterBody2D`, `Area2D`, or any 2D node. One behavior per moving node.

**2. Set the Inspector knobs.** Select the behavior node and tune the feel:

| Property | Type | Default | What it does |
|---|---|---|---|
| `max_speed` | float | `200.0` | Travel speed in pixels per second. Bigger is faster; it is a constant glide with no easing. |
| `rotate_toward_motion` | bool | `false` | When on, rotates the host every frame to face its direction of travel. Leave off for sprites that should not spin. |

**3. Send it somewhere and react on arrival.** Give the node a destination in some event, then react to On Arrived. Here is a complete first setup - a hero that walks to wherever you click and plays an idle animation when it gets there:

```
On Left Mouse Button pressed
  -> Hero | Move To: Move To Position  get_global_mouse_position().x, get_global_mouse_position().y

On Arrived (Hero | Move To)
  -> Hero: play "idle" animation
```

Move To Position replaces any route in progress, so each fresh click redirects the hero immediately. On Arrived fires once, when the hero reaches the clicked point.

---

## ACE reference

All ACEs live in the **Move To** category and target the `MoveToBehavior` on the node they are placed on. Each has an "On node" target that defaults to the behavior on that node, so you normally leave it as-is - there is no separate target id to manage.

The **Set Max Speed**, **Add To Max Speed**, **Subtract From Max Speed**, and **Set Rotate Toward Motion** actions, and the **Max Speed** and **Rotate Toward Motion** expressions, are generated automatically from the two exported Inspector properties - they let you read and change those knobs from the sheet at runtime.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Move To Position | `x` (float), `y` (float) | Replaces the queue and glides toward the point. |
| Add Waypoint | `x` (float), `y` (float) | Appends a stop to the queue (waypoints). |
| Stop Moving | (none) | Clears the queue without firing On Arrived. |
| Set Max Speed | `value` (float) | Sets the travel speed in pixels per second. |
| Add To Max Speed | `amount` (float) | Increases the travel speed by an amount. |
| Subtract From Max Speed | `amount` (float) | Decreases the travel speed by an amount. |
| Set Rotate Toward Motion | `value` (bool) | Turns face-the-travel-direction on or off. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| (none) | - | Move To ships no dedicated conditions. Gate on movement by reacting to the On Arrived trigger, or compare the Max Speed / Rotate Toward Motion expressions in an "Expression is true" condition. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Max Speed | (none) | float | The current travel speed in pixels per second. |
| Rotate Toward Motion | (none) | bool | Whether the behavior is rotating the host to face travel. |

### Triggers

| Trigger | Fires when |
|---|---|
| On Arrived | The host reaches the final waypoint and the queue empties. It does not fire for intermediate stops, and it does not fire after Stop Moving. |

---

## Use cases

Each example targets the `MoveToBehavior` on the named node. Send a destination in some event, then react to On Arrived where the trip matters.

### 1. Click to move

The node walks to wherever the player clicks. Move To Position replaces the queue, so every new click redirects it at once.

```
On Left Mouse Button pressed
  -> Hero | Move To: Move To Position  get_global_mouse_position().x, get_global_mouse_position().y
```

### 2. Two-point patrol loop

A guard paces between two marks forever. On Arrived sends it back to the other end.

```
On Ready
  -> Guard | Move To: Move To Position  PointA.global_position.x, PointA.global_position.y
  -> set Guard.going_to_b = true

On Arrived (Guard | Move To)
  Condition: Guard.going_to_b  is true
    -> Guard | Move To: Move To Position  PointB.global_position.x, PointB.global_position.y
    -> set Guard.going_to_b = false
  Else
    -> Guard | Move To: Move To Position  PointA.global_position.x, PointA.global_position.y
    -> set Guard.going_to_b = true
```

### 3. Multi-stop route with Add Waypoint

Lay a whole path down at once. Add Waypoint appends each stop, and the node visits them in order.

```
On Ready
  -> Courier | Move To: Add Waypoint  Shop.global_position.x, Shop.global_position.y
  -> Courier | Move To: Add Waypoint  Road.global_position.x, Road.global_position.y
  -> Courier | Move To: Add Waypoint  Door.global_position.x, Door.global_position.y

On Arrived (Courier | Move To)
  -> Courier: deliver package
```

On Arrived fires only after the last stop, so the delivery runs once at the doorstep.

### 4. Pickup flies to the player

A collected coin homes in on the player's current spot.

```
On Coin body_entered (body is Player)
  -> Coin | Move To: Move To Position  Player.global_position.x, Player.global_position.y

On Arrived (Coin | Move To)
  -> add 1 to Score
  -> Coin: queue_free
```

### 5. Enemy advances to a firing position, then attacks

Keep movement and combat separate: send the enemy to a spot, and let On Arrived kick off the attack.

```
On Enemy spotted player
  -> Enemy | Move To: Move To Position  FirePost.global_position.x, FirePost.global_position.y

On Arrived (Enemy | Move To)
  -> Enemy: start shooting
```

### 6. Cutscene actor walks on stage

Blocking made simple. Walk the actor to a mark, and use On Arrived as the cue for the next line.

```
On Cutscene Start
  -> Actor | Move To: Move To Position  StageMark.global_position.x, StageMark.global_position.y

On Arrived (Actor | Move To)
  -> Dialogue: show next line
```

### 7. Cancel the move on command

The player presses a stop key and the unit halts where it stands. Stop Moving clears the queue and does not fire On Arrived, so no arrival logic runs.

```
On Stop key pressed
  -> Unit | Move To: Stop Moving
  -> Unit: play "idle" animation
```

### 8. Ping-pong moving platform

A lift bounces between top and bottom marks. Two waypoints and an On Arrived that flips the target.

```
On Ready
  -> Lift | Move To: Move To Position  Top.global_position.x, Top.global_position.y
  -> set Lift.at_top_target = true

On Arrived (Lift | Move To)
  Condition: Lift.at_top_target  is true
    -> Lift | Move To: Move To Position  Bottom.global_position.x, Bottom.global_position.y
    -> set Lift.at_top_target = false
  Else
    -> Lift | Move To: Move To Position  Top.global_position.x, Top.global_position.y
    -> set Lift.at_top_target = true
```

### 9. Arrow that faces its travel

Turn on facing so a fired arrow or torpedo noses into its heading as it flies.

```
On Ready
  -> Arrow | Move To: Set Rotate Toward Motion  true
  -> Arrow | Move To: Move To Position  Target.global_position.x, Target.global_position.y

On Arrived (Arrow | Move To)
  -> Arrow: stick into target
```

You can also set `rotate_toward_motion` to on in the Inspector instead of the first action.

### 10. Speed boost pad

Stepping on a pad makes the unit travel faster; leaving it restores the base speed. Set Max Speed writes the value directly.

```
On Unit entered SpeedPad
  -> Unit | Move To: Set Max Speed  400

On Unit exited SpeedPad
  -> Unit | Move To: Set Max Speed  200
```

### 11. Slow field that nudges speed down

A mud field shaves speed off temporarily using Subtract From Max Speed, then adds it back on exit.

```
On Unit entered MudField
  -> Unit | Move To: Subtract From Max Speed  120

On Unit exited MudField
  -> Unit | Move To: Add To Max Speed  120
```

Because these nudge the same knob, pair each Subtract with a matching Add so the base speed comes back cleanly.

### 12. Tower-defense creep along a lane

Feed the lane's corner points as waypoints and the creep walks the path. On Arrived at the last one means it reached the base.

```
On Creep spawned
  -> Creep | Move To: Add Waypoint  Corner1.global_position.x, Corner1.global_position.y
  -> Creep | Move To: Add Waypoint  Corner2.global_position.x, Corner2.global_position.y
  -> Creep | Move To: Add Waypoint  Base.global_position.x, Base.global_position.y

On Arrived (Creep | Move To)
  -> subtract 1 from PlayerLives
  -> Creep: queue_free
```

### 13. Formation regroup

Order a squad to slide into fixed slots at a shared, tuneable speed. Each unit gets its own Move To Position.

```
On Regroup pressed
  -> UnitA | Move To: Move To Position  SlotA.global_position.x, SlotA.global_position.y
  -> UnitB | Move To: Move To Position  SlotB.global_position.x, SlotB.global_position.y
  -> UnitC | Move To: Move To Position  SlotC.global_position.x, SlotC.global_position.y
```

### 14. Return to spawn when the player is lost

An enemy that loses track of the player wanders home to its spawn point.

```
On Enemy lost player
  -> Enemy | Move To: Move To Position  Enemy.spawn_point.x, Enemy.spawn_point.y

On Arrived (Enemy | Move To)
  -> Enemy: resume idle patrol
```

### 15. Add a detour stop mid-trip

While a courier is en route, an extra errand appends to the tail of its queue without disturbing the current leg.

```
On Errand requested
  -> Courier | Move To: Add Waypoint  Errand.global_position.x, Errand.global_position.y
```

Add Waypoint keeps the in-progress route intact and tacks the new stop on at the end, so On Arrived still fires only once, after the final destination.

### Other use cases

**Card dealing.** Each dealt card glides from the deck position to its hand slot with Move To Position, and On Arrived flips it face up, giving a card game its table feel with no tween chains.

**Conga-line followers.** Every few ticks each follower calls Move To Position on the spot of the character ahead, so rescued critters or party members trail the leader in a loose line.

**Ambient wanderers.** A fish, butterfly, or villager picks a random nearby point, glides there, and On Arrived picks the next one - an endless idle wander from two rows.

**Tutorial pointer.** A floating hand glides to whatever button or pickup the tutorial wants noticed next, arriving exactly when the hint text appears.

**Telegraphed boss slam.** The boss glides to a marked target tile at a readable speed, and On Arrived detonates the shockwave, so the wind-up and the payoff stay cleanly separated.

---

## Tips and common mistakes

- **The host must be a Node2D.** The behavior moves its parent's `position`, so attach it under a 2D node (Sprite2D, CharacterBody2D, Area2D, and so on). Under a non-Node2D parent it warns and does nothing.
- **Move To Position replaces, Add Waypoint appends.** Reach for Move To Position when a new order should override the old route ("go here now"), and Add Waypoint when you are building or extending a path. Mixing them up is the usual reason a route gets wiped or a stop lands in the wrong place.
- **On Arrived fires once, at the end of the queue.** It does not fire for each intermediate waypoint. If you need to react at every stop, use single-point Move To Position calls chained through On Arrived rather than one big Add Waypoint route.
- **Stop Moving is silent by design.** It clears the queue without firing On Arrived, so any logic you hung on arrival will not run. That is exactly what you want for an interrupted order - but if you were relying on On Arrived to clean up, do that cleanup in the same event as Stop Moving.
- **It is a constant glide, not an easing tween.** Speed is flat from start to finish with a hard stop on the point. If you want acceleration or a soft landing, that is a job for a tween behavior; Move To trades easing for dead-simple, predictable pathing.
- **Speed is in pixels per second.** `max_speed` of 200 crosses 200 pixels each second. If a node feels glued in place, its speed is probably too low for the distance; if it teleports, it is too high.
- **Rotate Toward Motion spins the whole node.** With it on, the host's `rotation` follows the travel direction every moving frame. For a top-down character whose art should stay upright, leave it off (the default) and rotate a child sprite yourself instead.
- **Feed points, not nodes.** Move To Position and Add Waypoint take an `x` and a `y`. Pass a target's `global_position.x` and `global_position.y` (evaluated when you call the action) - the node then heads for that fixed point, it does not keep chasing a moving target on its own.
- **To chase a moving target, re-issue the order.** Because the destination is a fixed point, call Move To Position again on a timer (or when the target moves) to keep the pursuer tracking a live target.
- **Speed changes are live but shared.** Set Max Speed, Add To Max Speed, and Subtract From Max Speed all edit the one `max_speed` knob. When you use them for temporary fields or pads, pair each change with its exact opposite on exit so the base speed returns to where it started.
