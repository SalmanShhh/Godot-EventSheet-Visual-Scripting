# Line Of Sight 3D - Can This Node See That, In 3D

Line Of Sight 3D is a Godot EventSheets behavior pack that answers one question fast: can this node see that point right now? You attach a `LOS3DBehavior` behavior to a `Node3D` - a guard, a turret, a camera, a creature - and that node becomes the eye. It casts a physics ray from the host to a target and reports back whether the view is clear, optionally gated by a sight range and a forward vision cone. There is no sensor id to pass around: every Condition and Expression acts on the behavior living on the node you drop it on. Use it to build vision cones, break-line-of-sight chases, auto-targeting towers, security alarms, and clear-shot checks, all without writing a raycast by hand.

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

- **Turret and sentry targeting.** A gun only fires when the target is genuinely visible, so it stops shooting the second the player ducks behind cover.
- **Stealth and vision cones.** Set a forward cone so a guard only spots you inside its field of view, and you can slip past behind its back.
- **Break-line-of-sight chases.** An enemy that loses you the moment you round a corner or drop behind a crate, instead of tracking you through walls.
- **Auto-attack towers and companions.** Lock onto the nearest enemy the node can actually see and ignore ones hidden behind geometry.
- **Security cameras and alarms.** Trip an alert the instant an intruder crosses into view, with the camera's range and cone doing the work.
- **Clear-shot and friendly-fire checks.** Confirm an unobstructed path between two points before you spawn a projectile, so allies do not eat the bullet.
- **Snipers and overwatch.** Long-range spotting that still respects cover, so a wall genuinely hides you from a distant shooter.
- **Peek-and-shoot cover AI.** An enemy that only exposes itself when it has a clean line, then tucks back when the view is blocked.
- **Fog-of-war and scouting.** Reveal the map only where a unit can see, so hidden corners stay dark until someone actually looks.
- **Detection and aggro.** Start a fight on real sight rather than raw distance, so enemies do not magically notice you through a floor.
- **Line-of-effect for abilities.** A beam or gaze attack that only lands when the path to the target is unobstructed.
- **Dynamic vision buffs and blinds.** A flare that extends sight range, or smoke that shrinks the cone, all by nudging the exported knobs at runtime.

---

## Core concepts

The pack is tiny and the mental model is short. Learn these ideas and the rest is just dropping rows.

**The node is the eye.** You add a `LOS3DBehavior` as a child of a `Node3D`, and that parent node is the host - the thing doing the seeing. Every check measures from the host's world position, and the vision cone points along the host's forward direction (its local -Z). There is no sensor argument to thread through calls: the condition acts on the behavior of the node it sits on.

**A raycast is the whole trick.** "Can I see that point?" is answered by casting a straight physics ray from the host to the point. If the ray reaches the point without hitting anything, the view is clear. If something is in the way, the view is blocked. That "something" is decided entirely by the collision mask (see below).

**Range gates how far it looks.** The `sight_range` knob caps the distance. A target beyond `sight_range` reads as not visible even if the path is wide open. This is the "it is too far to make out" limit.

**The cone gates where it looks.** The `cone_of_view_degrees` knob is the full field-of-view angle, centered on the host's forward. `360` sees all the way around (no cone). A smaller value carves out a cone: a point outside that wedge reads as not visible even if it is close and unobstructed. A `90` cone, for example, reaches 45 degrees to either side of forward. Rotate the host and the cone rotates with it.

**Two conditions, two jobs.** **Has Line Of Sight To** is the full check from the host: range, then cone, then the raycast, all in one. **Has LOS Between** is just the raycast between two arbitrary points you hand it - it ignores range and cone. Use the first for "can this node see that?"; use the second for "is the path between these two spots clear?" (a clear-shot test, a cover check, a line-of-effect gate).

**The collision mask is your definition of a wall.** The ray only stops on physics bodies whose layer is in `collision_mask`. Put your walls, floors, and solid props on those layers and they block sight. Anything not on a masked layer is invisible to the ray and never blocks. Crucially, the thing you are trying to *see* should not sit on a masked layer, or its own collider can register as the obstruction and it will report itself as blocked.

**Nearest Visible In Group is the targeting primitive.** Give it a group name and it scans every member, throws out the ones out of range, outside the cone, or behind cover, and returns the closest one that is genuinely visible. A nearer-but-blocked enemy cannot shadow a visible farther one. It returns null when nothing is in view. This is the one call an auto-attack AI needs to pick a target.

**Line of sight is polled, not pushed.** This pack ships no triggers. You ask the question when you want the answer: on a timer, every frame, or right after a stimulus like "player moved". Read the condition, then branch on it.

---

## Setup

**1. Attach the behavior.** Add a `LOS3DBehavior` behavior as a child node of the `Node3D` that should do the seeing (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in as a child). The behavior grabs its parent as the host on ready. One behavior per eye - each guard, turret, or camera gets its own.

**2. Set the Inspector knobs.** Select the behavior node and tune the sensor:

| Property | Default | What it does |
|---|---|---|
| `collision_mask` | `1` | The physics layers a sight ray tests against. Only bodies on these layers block the view. Put walls and terrain here, not the actors you want to see. |
| `cone_of_view_degrees` | `360.0` | The full field-of-view angle in degrees, centered on the host's forward (-Z). `360` sees all around; a smaller value makes a vision cone. Only Has Line Of Sight To uses it. |
| `sight_range` | `1000.0` | The maximum distance (world units) the host can see. A target farther than this reads as not visible. Only Has Line Of Sight To uses it. |

**3. Poll the condition and react.** There is nothing to register on ready - just ask the question on your loop. Here is a complete first sensor: a turret that fires only while it can see the player.

```
Every 0.1 seconds
  Condition: Turret | Line Of Sight 3D  Has Line Of Sight To  Player.global_position
    -> Turret: aim at Player.global_position
    -> Turret: fire
```

The moment the player steps behind a wall (or out of range, or out of the cone), Has Line Of Sight To returns false and the two actions stop running. No state to reset, no timer to clear.

---

## ACE reference

All ACEs live in the **Line Of Sight 3D** category and act on the `LOS3DBehavior` attached to the node they are placed on. There is no sensor id parameter anywhere - the node is the eye.

### Actions

These write to the sensor's exported knobs at runtime and are reflected from the `@export` properties. Each acts on the behavior of the node it is placed on.

| Action | Parameters | Description |
|---|---|---|
| Set Sight Range | `value` (float) | Sets how far the host can see, in world units. |
| Add To Sight Range | `amount` (float) | Increases the sight range by `amount`. |
| Subtract From Sight Range | `amount` (float) | Decreases the sight range by `amount`. |
| Set Cone Of View Degrees | `value` (float) | Sets the full field-of-view angle in degrees (360 = all around). |
| Add To Cone Of View Degrees | `amount` (float) | Widens the cone by `amount` degrees. |
| Subtract From Cone Of View Degrees | `amount` (float) | Narrows the cone by `amount` degrees. |
| Set Collision Mask | `value` (int) | Sets the physics layers that block sight (the bitmask value). |
| Add To Collision Mask | `amount` (int) | Adds to the collision mask value. |
| Subtract From Collision Mask | `amount` (int) | Subtracts from the collision mask value. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Has Line Of Sight To | `point` (Vector3) | True when the host can see that world point: it is within `sight_range`, inside the cone of view, and the ray from the host reaches it unobstructed. The full sensor check. |
| Has LOS Between | `from_point` (Vector3), `to_point` (Vector3) | True when a straight ray between the two world points hits nothing on the collision mask. Ignores range and cone - a pure path-is-clear test between any two spots. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Nearest Visible In Group | `group` (String) | Node3D | The closest node in that group the host can actually see (range + cone + ray), skipping occluded ones. Returns null when none are visible. The targeting primitive for auto-attack AI. |
| Sight Range | (none) | float | The current sight range value. |
| Cone Of View Degrees | (none) | float | The current cone of view, in degrees. |
| Collision Mask | (none) | int | The current collision mask value. |

### Triggers

| Trigger | Fires when |
|---|---|
| (none) | Line Of Sight 3D ships no triggers. Line of sight is a polled check: read Has Line Of Sight To (or Nearest Visible In Group) on a timer, every frame, or right after a stimulus, and branch on the result. |

### Inspector properties

| Property | Type | Default | What it controls |
|---|---|---|---|
| `collision_mask` | int | `1` | Which physics layers block a sight ray. Only bodies on these layers count as occluders. |
| `cone_of_view_degrees` | float | `360.0` | The full vision-cone angle in degrees around the host's forward. 360 disables the cone (see all around). |
| `sight_range` | float | `1000.0` | The maximum sight distance in world units. |

---

## Use cases

Each example acts on the `LOS3DBehavior` attached to the named node. Line of sight is polled, so check the condition (or read the expression) on a timer, every frame, or after a stimulus, and branch on it.

### 1. Turret only fires when it can see the player

The most basic sensor: no shots through walls. When the view is blocked, the fire action simply stops running.

```
Every 0.1 seconds
  Condition: Turret | Line Of Sight 3D  Has Line Of Sight To  Player.global_position
    -> Turret: aim at Player.global_position
    -> Turret: fire
```

### 2. Break-line-of-sight chase

An enemy chases only while it can see you; round a corner and it stops. Pair it with an else branch to search the last-known spot.

```
Every 0.2 seconds
  Condition: Enemy | Line Of Sight 3D  Has Line Of Sight To  Player.global_position
    -> Enemy: move toward Player.global_position
    -> Enemy: set last_seen = Player.global_position
  Else
    -> Enemy: move toward Enemy.last_seen
```

### 3. Stealth guard with a vision cone

Set `cone_of_view_degrees` to 90 in the Inspector so the guard only sees a forward wedge - stand behind it and you are invisible. Rotating the guard sweeps the cone.

```
Every 0.15 seconds
  Condition: Guard | Line Of Sight 3D  Has Line Of Sight To  Player.global_position
    -> Alarm: raise "spotted"
    -> Guard: turn to face Player.global_position
```

### 4. Auto-target the nearest visible enemy

A tower picks its target with one expression: the closest enemy it can actually see, ignoring ones behind cover. When nothing is visible the expression returns null, so guard the shot.

```
Every 0.25 seconds
  -> Tower: set target = Tower | Line Of Sight 3D: Nearest Visible In Group  "enemies"
  Condition: Tower.target  is valid
    -> Tower: aim at Tower.target.global_position
    -> Tower: fire
```

### 5. Security camera trips an alarm

A ceiling camera is just a `Node3D` with the behavior. Give it a long range and a narrow cone, and let it watch its arc.

```
Every 0.3 seconds
  Condition: Camera | Line Of Sight 3D  Has Line Of Sight To  Intruder.global_position
    -> Security: set alarm_active = true
    -> Camera: flash red light
```

### 6. Clear-shot check before spawning a projectile

Before an archer looses an arrow, confirm the path between the bow and the target is unobstructed with Has LOS Between - no range or cone involved, just the raycast.

```
On Attack Pressed
  Condition: Archer | Line Of Sight 3D  Has LOS Between  Archer.muzzle.global_position, Target.global_position
    -> Archer: spawn arrow toward Target.global_position
  Else
    -> Archer: play "no clear shot" grunt
```

### 7. Friendly-fire guard between two allies

Do not fire if a teammate is on the line. Cast Has LOS Between from the shooter to the enemy; if a wall or ally body on the mask is in the way, hold.

```
Every 0.2 seconds
  Condition: Soldier | Line Of Sight 3D  Has Line Of Sight To  Enemy.global_position
    Condition: Soldier | Line Of Sight 3D  Has LOS Between  Soldier.global_position, Enemy.global_position
      -> Soldier: fire at Enemy
```

### 8. Sniper overwatch that respects cover

A perched sniper watches a doorway across the map. A big `sight_range` lets it reach; the raycast still fails the instant the player is behind a pillar.

```
Every 0.1 seconds
  Condition: Sniper | Line Of Sight 3D  Has Line Of Sight To  Player.global_position
    -> Sniper: show laser dot on Player
    -> Sniper: charge shot
  Else
    -> Sniper: hide laser dot
```

### 9. Peek-and-shoot cover AI

An enemy stays tucked until it has a clean line, pops out to shoot, then hides again when the view breaks.

```
Every 0.15 seconds
  Condition: Grunt | Line Of Sight 3D  Has Line Of Sight To  Player.global_position
    -> Grunt: play "peek out"
    -> Grunt: fire at Player
  Else
    -> Grunt: play "take cover"
```

### 10. Fog-of-war reveal from a scout

A scout unit reveals only what it can genuinely see. Check the players group (or objectives) and unfog each visible one.

```
Every 0.5 seconds
  Condition: Scout | Line Of Sight 3D  Has Line Of Sight To  Objective.global_position
    -> Minimap: reveal Objective
```

### 11. Boss focuses the nearest player it can see

In co-op, the boss should target whoever is exposed, not whoever is closest through a wall. Nearest Visible In Group does exactly that.

```
Every 0.25 seconds
  -> Boss: set focus = Boss | Line Of Sight 3D: Nearest Visible In Group  "players"
  Condition: Boss.focus  is valid
    -> Boss: turn to face Boss.focus.global_position
    -> Boss: queue attack on Boss.focus
```

### 12. Flare extends vision, then fades

A dropped flare temporarily boosts how far a searchlight can see. Set Sight Range up when it ignites, subtract it back down as it dies.

```
On Flare Lit
  -> Searchlight | Line Of Sight 3D: Set Sight Range  2500

On Flare Burned Out
  -> Searchlight | Line Of Sight 3D: Set Sight Range  1000
```

### 13. Smoke grenade shrinks the cone

Smoke should blind a guard, not teleport it. Narrow the cone hard while the guard stands in smoke, and restore it after.

```
On Enter Smoke
  -> Guard | Line Of Sight 3D: Set Cone Of View Degrees  20

On Exit Smoke
  -> Guard | Line Of Sight 3D: Set Cone Of View Degrees  90
```

### 14. See-through-glass toggle by swapping the mask

Windows should block bullets but not sight. Put glass on its own physics layer and Subtract From Collision Mask when a sensor should see through it (or Add To it to make it opaque again).

```
On Power Cut
  -> Camera | Line Of Sight 3D: Subtract From Collision Mask  4

On Power Restored
  -> Camera | Line Of Sight 3D: Add To Collision Mask  4
```

### 15. Trap only springs on a clear line to its victim

A dart trap fires down a corridor, but only if nothing blocks the path between the emitter and whoever stepped on the plate.

```
On Pressure Plate Stepped
  Condition: Trap | Line Of Sight 3D  Has LOS Between  Trap.emitter.global_position, Stepper.global_position
    -> Trap: fire dart toward Stepper.global_position
```

### 16. Companion calls out the nearest threat it sees

A follower does not need combat logic to be useful - it just names the closest enemy in view so the player knows where to look.

```
Every 0.4 seconds
  -> Ally: set spotted = Ally | Line Of Sight 3D: Nearest Visible In Group  "enemies"
  Condition: Ally.spotted  is valid
    Condition: Ally.spotted  changed
      -> Ally: bark "Enemy over there!"
      -> HUD: ping Ally.spotted.global_position
```

---

## Tips and common mistakes

- **The node is the eye - there is no sensor id.** Every Condition and Expression acts on the `LOS3DBehavior` of the node it sits on. Drop it on the guard, and Has Line Of Sight To checks from that guard. One behavior per eye.
- **Keep the things you want to SEE off the collision mask.** The ray stops on the first body on a masked layer. If the target's own collider is on that layer, the ray can hit the target and report it as blocked - it hides from itself. Put walls, floors, and props on the mask; keep actors on separate layers.
- **Nearest Visible In Group can return null - always guard it.** When nothing is in view it hands back null. Wrap the shot or the aim in an "is valid" check before you read `.global_position`, or you will dereference nothing on a quiet frame.
- **Has Line Of Sight To uses range and cone; Has LOS Between does not.** Reach for Has Line Of Sight To for "can this node see that?" and Has LOS Between for a raw "is the straight path between these two points clear?" Mixing them up is why a clear-shot check "ignores" your sight range - Has LOS Between is supposed to.
- **The cone angle is the full width, not the half-angle.** `cone_of_view_degrees` of 90 reaches 45 degrees to each side of forward. Leave it at 360 for an all-around sensor (a camera on a swivel, a creature with eyes all round).
- **Poll it - there are no triggers.** Nothing fires when visibility changes. Read the condition on a timer, every frame, or on a stimulus. Match the poll rate to the need: 0.1s for a twitchy turret, 0.5s for ambient fog reveal, to keep raycasts cheap.
- **Sight range is squared cost at scale, so do not over-poll.** Each check is a physics raycast. Many sensors checking many targets every frame adds up - stagger their timers or widen the interval for distant, non-critical eyes.
- **Forward is the host's local -Z.** The cone points where the host faces. If a guard's cone seems aimed the wrong way, its model or node is rotated so -Z is not where you expect - orient the host, not the behavior.
- **Set the mask, do not fight it in events.** The cleanest setup is one collision mask that names your occluders. Reach for Set Collision Mask / Add / Subtract only for genuine runtime changes (see-through-glass, a wall that opens), not to paper over a mislayered scene.
