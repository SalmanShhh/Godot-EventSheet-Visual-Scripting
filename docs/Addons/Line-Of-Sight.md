# Line Of Sight - Can This Node Actually See That?

Line Of Sight is a Godot EventSheets behavior pack that answers one honest question - "from where I am standing and facing, is there a clear view to that spot?" - with a real physics raycast, not a guess. You attach a `LOSBehavior` behavior to a `Node2D` (an enemy, a guard, a turret, a camera) and that node becomes a sensor. Every Condition and Expression tests from that node's own position, facing, and range: it checks distance against `sight_range`, checks whether the target sits inside the `cone_of_view_degrees` fan around the node's rotation, then fires a raycast on the `collision_mask` layers to make sure no wall is in the way. There is no "sensor id" to pass around - every ACE targets the `LOSBehavior` living on the node you drop it on. It is a per-node behavior, so one enemy gets one pair of eyes.

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

- **Enemy spotting.** A patrolling enemy only chases once it can genuinely see the player - not when the player is merely close, and not through a wall.
- **Stealth and cover.** The player is safe the instant they break the enemy's line of sight, so ducking behind a crate does exactly what a beginner expects.
- **Cone-of-vision guards.** Give a guard a narrow forward cone so you can sneak up from behind, then widen it when the guard turns to look around.
- **Auto-targeting turrets.** A turret picks the nearest enemy it can actually see and ignores ones hiding behind pillars, using one expression.
- **Line-of-fire checks.** Before a ranged attacker shoots, confirm nothing solid stands between the muzzle and the target so shots do not sail into a wall.
- **Security cameras.** Rotate a camera node in a sweep and ping an alarm only while the intruder is inside its view fan and unobstructed.
- **Companion awareness.** A follower notices the nearest visible ally to heal or the nearest visible foe to engage, without seeing through terrain.
- **Fog reveal and minimap pings.** Light up a map marker or reveal an area only when a scout has a real, unblocked view of it.
- **Alert-state vision changes.** On alarm, boost sight range and open the cone to a full circle so a searching guard sees more than a calm one.
- **Day/night and lighting.** Shrink sight range in the dark or when a light is off, and restore it when the room lights up.
- **See-through-glass powers.** Swap the blocking layers so a special vision mode can see through windows, smoke, or fences that normally break sight.
- **Sniper and scope buffs.** Add to the sight range while a scope is raised so a marksman spots targets an ordinary soldier would miss.

---

## Core concepts

The model is small. Learn these five ideas and every ACE in the pack falls into place.

**The node is the sensor.** You attach a `LOSBehavior` to a `Node2D`, and from then on every Condition and Expression on that node reads from *its* position and *its* rotation. There is no sensor id or observer argument to thread through calls. One enemy, one pair of eyes. If you want two viewpoints on one character (say a head and a periscope), that is two nodes, each with its own behavior.

**Line of sight is a raycast that must hit nothing.** "Can I see that point?" is answered by casting a straight ray from the node to the target and checking whether it hits any physics body on the `collision_mask` layers. If the ray reaches the target without hitting anything on those layers, the view is clear. This is why the pack needs your obstacles to be real physics bodies (a `StaticBody2D` wall, a `TileMap` with collision) on the layers you point `collision_mask` at.

**Sight has three gates, and all three must pass.** `Has Line Of Sight To` only returns true when the target is (1) within `sight_range` distance, (2) inside the `cone_of_view_degrees` fan measured around the node's `rotation`, and (3) not blocked by anything on `collision_mask`. Any one of them failing means "cannot see." That is how "too far", "behind me", and "behind a wall" all become a plain false with no if-tree of your own.

**The cone is measured from the node's facing.** `cone_of_view_degrees` is the total width of the view fan, centered on the node's `rotation`. A value of `360` means the node sees all the way around (the cone check is skipped). A value of `90` means the node sees 45 degrees to each side of wherever it is pointing. If you use a cone under 360, you must actually rotate the node so its facing points where you want it to look. At `rotation` 0 a node faces right (the +X direction).

**Two flavors of the question.** `Has Line Of Sight To` is the full "can this node see that spot" test - range, cone, and raycast together, always measured from this node. `Has LOS Between` is the raw obstacle check: is a straight ray between *any two* world points unblocked? It ignores range and cone entirely, so it is the tool for "is the line from this muzzle to that target clear" or "can these two spots see each other" without involving where the sensor node stands. And `Nearest Visible In Group` is the targeting primitive: it runs the full `Has Line Of Sight To` test against every member of a group and hands you the closest one that actually passes.

---

## Setup

**1. Attach the behavior.** Add a `LOSBehavior` behavior as a child of the `Node2D` that should see (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in as a child). The behavior grabs its parent as the host, so the parent must be a `Node2D` or a node that extends it (`CharacterBody2D`, `Sprite2D`, `Area2D`, and so on all qualify).

**2. Set the Inspector knobs.** Select the behavior node and tune the eyes:

| Property | Default | What it does |
|---|---|---|
| `sight_range` | `400.0` | Maximum distance in pixels the node can see. Past this, `Has Line Of Sight To` is false. |
| `cone_of_view_degrees` | `360.0` | Total width of the view fan in degrees, centered on the node's rotation. `360` sees all around; `90` is a narrow forward cone. |
| `collision_mask` | `1` | The physics layers that block sight, as a bitmask. Put your walls and obstacles on these layers. |

**3. Give it something to be blocked by.** Line of sight is only meaningful if there are obstacles. Make sure your walls are physics bodies on a layer that `collision_mask` includes. A world with no colliders on those layers means every target in range and in the cone is always visible.

**4. Ask the question in your events.** This behavior does not run on its own or fire triggers - you check its Conditions and read its Expressions from your own events (`On Ready`, a timer, `On Process`, or any stimulus). Here is a complete first sensor - an enemy that chases the player only when it truly sees them:

```
Every 0.2 seconds
  Condition: Enemy | Line Of Sight  Has Line Of Sight To  Player.global_position
    -> Enemy: move toward Player.global_position
    -> Enemy: set state = "chase"
  Else
    -> Enemy: set state = "patrol"
```

Because the check is a real raycast, the enemy drops back to patrol the moment the player slips behind a wall or steps out of range, with no extra bookkeeping from you.

---

## ACE reference

All ACEs live in the **Line Of Sight** category and target the `LOSBehavior` behavior on the node they are placed on. There is no sensor-id parameter anywhere.

The Actions and the plain-value Expressions below are generated automatically from the three exported properties (`sight_range`, `cone_of_view_degrees`, `collision_mask`), so you can read or change the eyes at runtime from the sheet.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Set Sight Range | `value` (float) | Sets the maximum view distance in pixels. |
| Add To Sight Range | `amount` (float) | Increases the view distance by `amount` pixels. |
| Subtract From Sight Range | `amount` (float) | Decreases the view distance by `amount` pixels. |
| Set Cone Of View Degrees | `value` (float) | Sets the view-fan width in degrees (360 = all around, cone check off). |
| Add To Cone Of View Degrees | `amount` (float) | Widens the view fan by `amount` degrees. |
| Subtract From Cone Of View Degrees | `amount` (float) | Narrows the view fan by `amount` degrees. |
| Set Collision Mask | `value` (int) | Sets which physics layers block sight, as a bitmask. |
| Add To Collision Mask | `amount` (int) | Adds layers to the blocking bitmask. |
| Subtract From Collision Mask | `amount` (int) | Removes layers from the blocking bitmask. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Has Line Of Sight To | `point` (Vector2) | True when this node can genuinely see the world position: within `sight_range`, inside the `cone_of_view_degrees` fan around its rotation, and with no blocker on `collision_mask` in the way. The everyday "can I see it" check. |
| Has LOS Between | `from_point` (Vector2), `to_point` (Vector2) | True when nothing on `collision_mask` blocks a straight ray from one world position to another. Ignores range and cone entirely - a pure "is the line clear" test between any two spots. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Nearest Visible In Group | `group` (String) | Node2D | The closest member of the named group this node can actually see (range + cone + raycast), skipping members that are blocked. Returns `null` when none are visible. The targeting primitive for auto-attack and auto-follow AI. |
| Sight Range | (none) | float | The current maximum view distance in pixels. |
| Cone Of View Degrees | (none) | float | The current view-fan width in degrees. |
| Collision Mask | (none) | int | The current blocking-layer bitmask. |

### Triggers

| Trigger | Fires when |
|---|---|
| (none) | This behavior publishes no triggers. It answers questions and computes values that you check inside your own events - a timer, `On Process`, `On Ready`, or any stimulus you already have. |

### Inspector properties

| Property | Type | Default | What it does |
|---|---|---|---|
| `sight_range` | float | `400.0` | Maximum view distance in pixels. |
| `cone_of_view_degrees` | float | `360.0` | View-fan width in degrees, centered on the node's rotation. 360 = all around. |
| `collision_mask` | int | `1` | Physics layers that block sight, as a bitmask. |

---

## Use cases

Each example targets the `LOSBehavior` behavior on the named node. Check the conditions and read the expressions from your own events - a timer, `On Process`, or a stimulus.

### 1. Enemy chases only what it can see

The bread and butter: pursue the player when there is a real, unblocked view, otherwise fall back to patrol. The wall check is free because it is a raycast.

```
Every 0.2 seconds
  Condition: Enemy | Line Of Sight  Has Line Of Sight To  Player.global_position
    -> Enemy: move toward Player.global_position
  Else
    -> Enemy: patrol
```

### 2. Guard raises the alarm on first sight

Trip the alarm the moment a guard actually sees the intruder. Guard the reaction with your own "already alerted" flag so it fires once.

```
Every 0.25 seconds
  Condition: Guard | Line Of Sight  Has Line Of Sight To  Player.global_position
  Condition: Guard.alerted  ==  false
    -> Guard: set alerted = true
    -> AlarmManager: trigger alarm
    -> Guard: play "!" alert popup
```

### 3. Turret auto-targets the nearest visible enemy

Let the turret find its own target. `Nearest Visible In Group` scans the group, skips anyone behind cover, and hands back the closest one it can see - or null when the coast is clear.

```
Every 0.1 seconds
  -> Turret: set target = Turret | Line Of Sight  Nearest Visible In Group  "enemies"
  Condition: Turret.target  !=  null
    -> Turret: aim at Turret.target.global_position
    -> Turret: fire
```

### 4. Do not shoot into a wall

Before a ranged attacker fires, confirm the line from its muzzle to the target is clear. `Has LOS Between` checks any two points, so it is perfect for a line-of-fire test independent of where the sensor stands.

```
On Attack Pressed
  Condition: Shooter | Line Of Sight  Has LOS Between  Shooter.muzzle_position, Enemy.global_position
    -> Shooter: fire projectile at Enemy.global_position
  Else
    -> Shooter: reposition for a clear shot
```

### 5. Stealth - the player is safe out of sight

Flip the check around. When no guard can see the player, the player is hidden, so you can drop suspicion or allow a stealth takedown prompt.

```
Every 0.2 seconds
  Condition: Guard | Line Of Sight  Has Line Of Sight To  Player.global_position  [inverted]
    -> Player: set hidden = true
    -> HUD: show "hidden" eye icon dimmed
  Else
    -> Player: set hidden = false
    -> HUD: show "spotted" eye icon
```

### 6. A narrow forward cone you can sneak behind

Give a guard a 90-degree cone so it only sees what is in front of it. Rotate the guard toward its patrol heading and you can slip up from behind.

```
On Ready
  -> Guard | Line Of Sight: Set Cone Of View Degrees  90

Every 0.2 seconds
  Condition: Guard | Line Of Sight  Has Line Of Sight To  Player.global_position
    -> Guard: turn to face Player and give chase
```

### 7. Alert state opens the eyes

A calm guard uses a tight cone and short range. On alarm, widen the cone to a full circle and extend the range so a searching guard is genuinely harder to hide from.

```
On Alarm Raised
  -> Guard | Line Of Sight: Set Cone Of View Degrees  360
  -> Guard | Line Of Sight: Set Sight Range  700

On Alarm Cleared
  -> Guard | Line Of Sight: Set Cone Of View Degrees  90
  -> Guard | Line Of Sight: Set Sight Range  400
```

### 8. Darkness shortens sight

When the lights go out, shrink how far the enemy can see. Restore it when the room lights up again.

```
On Lights Off
  -> Enemy | Line Of Sight: Set Sight Range  150

On Lights On
  -> Enemy | Line Of Sight: Set Sight Range  400
```

### 9. Scope buff extends range

Raising a scope lets a marksman spot targets a normal soldier would miss. Add to the range while aiming, subtract it back when the scope drops.

```
On Scope Raised
  -> Sniper | Line Of Sight: Add To Sight Range  600

On Scope Lowered
  -> Sniper | Line Of Sight: Subtract From Sight Range  600
```

### 10. X-ray vision that sees through walls

A special vision power that ignores the wall layer. Swap `collision_mask` to a layer nothing sits on (or 0) so the raycast never hits an obstacle, then restore it.

```
On XRay Activated
  -> Scout | Line Of Sight: Set Collision Mask  0

On XRay Expired
  -> Scout | Line Of Sight: Set Collision Mask  1
```

### 11. Security camera sweep with an alarm

Rotate a camera node back and forth in your own tween or event, and ping the alarm only while the intruder is inside its narrow fan and unobstructed.

```
On Ready
  -> Camera | Line Of Sight: Set Cone Of View Degrees  60

Every 0.15 seconds
  Condition: Camera | Line Of Sight  Has Line Of Sight To  Player.global_position
    -> SecurityRoom: flash "INTRUDER" and start countdown
```

### 12. Reveal the map only where a scout can truly see

Fog and minimap markers should light up on a real view, not just proximity. Read the nearest visible objective and reveal it.

```
Every 0.3 seconds
  -> Scout: set spotted = Scout | Line Of Sight  Nearest Visible In Group  "objectives"
  Condition: Scout.spotted  !=  null
    -> Minimap: reveal marker at Scout.spotted.global_position
```

### 13. Companion picks the nearest visible foe to fight

A follower engages what it can actually see instead of charging blindly at something behind a wall.

```
Every 0.2 seconds
  -> Companion: set foe = Companion | Line Of Sight  Nearest Visible In Group  "enemies"
  Condition: Companion.foe  !=  null
    -> Companion: attack Companion.foe
  Else
    -> Companion: return to Player
```

### 14. Two-point ambush check between cover spots

Use `Has LOS Between` to decide whether an enemy at one cover point can be seen from another before it commits to peeking out.

```
On Consider Peek
  Condition: Enemy | Line Of Sight  Has LOS Between  Enemy.cover_spot, Enemy.peek_spot
    -> Enemy: mark peek_spot as exposed, choose another
  Else
    -> Enemy: move to peek_spot and take the shot
```

### 15. First-sight bark, once per encounter

Play a "There you are!" line the first time an enemy sees the player, and reset it when sight is lost so the next encounter barks again.

```
Every 0.25 seconds
  Condition: Enemy | Line Of Sight  Has Line Of Sight To  Player.global_position
    Condition: Enemy.barked  ==  false
      -> Enemy: play "spotted" voice line
      -> Enemy: set barked = true
  Else
    -> Enemy: set barked = false
```

### Other use cases

**Freeze-when-watched enemy.** Give the player a sensor and only let the ghost or statue creep forward while the player does *not* have line of sight to it - the classic "it moves when you look away" monster is one inverted condition.

**Crime witness NPCs.** When something scandalous happens, check which NPCs have line of sight to the spot; only those witnesses run to report it, so hiding a misdeed behind a wall genuinely works.

**Tension music.** Switch to the combat or stealth-danger track while any enemy can see the player and relax it once every sensor loses sight, driving the whole audio mood from checks you are already running.

**Hiding in foliage.** Put bushes and tall grass on a sight-blocking layer so crouching into cover truly breaks enemy vision, and let a special hunter swap its collision mask to ignore foliage for a scarier pursuer.

**Hide-and-seek party mode.** Seekers tag any player they can genuinely see with Nearest Visible In Group, so winning is about real cover and corners rather than distance circles.

---

## Tips and common mistakes

- **The node is the sensor - there is no sensor id.** Every Condition and Expression acts on the `LOSBehavior` of the node it is placed on, measured from that node's own position and rotation. One behavior, one viewpoint. If you need two viewpoints, use two nodes.
- **The host must be a Node2D.** The behavior reads the parent's `global_position`, `rotation`, and 2D physics world. Attach it under a `Node2D` (or a child class like `CharacterBody2D` or `Area2D`); a plain `Node` parent will log a warning and the checks will not work.
- **Put obstacles on the collision_mask layers, or sight is never blocked.** Line of sight is a raycast that must hit *nothing* on `collision_mask`. If your walls are not physics bodies on those layers, every target in range and in the cone reads as visible. This is the number-one reason "it always sees me through walls."
- **Do not put targets on the blocking layer.** The ray runs from the node to the target point. If the target has a collider on a layer inside `collision_mask`, the ray can hit the target's own body and report "blocked." Keep walls and characters on separate layers, and point `collision_mask` only at the wall layers.
- **A cone under 360 needs the node to actually face somewhere.** `cone_of_view_degrees` is measured around the node's `rotation`. If you set a 90-degree cone but never rotate the node, it stares fixedly along its starting facing. Rotate the node toward its heading, or keep the cone at 360 for all-around vision.
- **Has LOS Between skips range and cone on purpose.** It is a pure obstacle check between two arbitrary points, so it will happily report a clear line across the whole level. Use it for line-of-fire and spot-to-spot checks; use `Has Line Of Sight To` when you want the sensor's own range and cone to matter.
- **Nearest Visible In Group can return null - check for it.** When no group member is visible, the expression hands back `null`. Guard the result with a "not null" condition before you read `.global_position` off it, or you will touch a null.
- **Sight range is in pixels, cone is in degrees.** They are easy to mix up. `sight_range` 400 is a distance; `cone_of_view_degrees` 90 is an angle. Setting a range of 90 makes a nearly blind enemy, and setting a cone of 400 just behaves like 360.
- **Check on a timer, not every single frame, unless you need to.** A raycast per node per frame adds up with a big crowd. An `Every 0.2 seconds` check feels instant to the player and is far cheaper than `On Process`. Reserve per-frame checks for the handful of sensors that truly need them.
- **Nothing fires automatically - you drive the checks.** This behavior has no triggers. It will not tell you "I just saw the player"; you ask it, in your own event, whenever you care. Pair it with a flag (like the first-sight bark example) when you want an edge, not a continuous state.
