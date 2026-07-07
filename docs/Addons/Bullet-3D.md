# Bullet 3D - Straight-Line and Arcing Projectile Motion, One Behavior Per Node

Bullet 3D is a Godot EventSheets behavior pack that flies a node forward every frame. You attach a `Bullet3DBehavior` behavior to a `Node3D` - a laser bolt, a grenade, an arrow, a thrown rock - and that node becomes a projectile. There is no emitter to register and no bullet id to pass around: every Action and Expression targets the `Bullet3DBehavior` living on the node you drop it on. On its very first frame the behavior launches itself along the host's forward direction at a set speed, then each frame it moves the node by its velocity and lets gravity bend the path into an arc. You steer the feel with two knobs - speed and gravity - set them in the Inspector or change them live from the sheet, and relaunch, retarget, or freeze a shot while the game runs. It is a Godot-native take on the classic projectile behavior, rebuilt for 3D: because the node is the projectile, all the emitter and bullet-id plumbing is gone.

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

- **Straight laser bolts.** Set gravity to 0 and a high speed, and the shot flies dead straight along the barrel's facing with no path node and no physics body.
- **Lobbed grenades and arcs.** A positive gravity bends the flight into a natural arc, so a grenade rises, peaks, and drops without a tween.
- **Arrows and bolts that dip.** A modest gravity makes an arrow drop over distance, the way real archery reads.
- **Rockets and missiles.** A launcher fires a projectile straight out of its muzzle's forward direction, fast and flat.
- **Thrown items.** Rocks, knives, and potions pop out of a hand and fall to the ground on a believable curve.
- **Enemy spit and fireballs.** A turret or creature spits along wherever it is aimed, no per-shot maths.
- **Cannonballs and mortars.** A heavy gravity plus a chosen speed gives a slow, high, dropping arc for siege weapons.
- **Chest and pickup pops.** An item bursts out of a chest with a little speed and gravity so it settles nearby.
- **Anti-gravity orbs.** A negative gravity makes a bubble or spirit projectile float upward instead of falling.
- **Spread and shotgun patterns.** Spawn several nodes, each rotated a little, and every one launches along its own facing for an instant spread.
- **Redirectable seekers.** Re-aim the node toward a target each tick and relaunch, for a cheap homing-ish projectile with no steering code.
- **Physics-free debris.** Chunks, shells, and sparks fly and arc believably without the cost of a rigid body.

---

## Core concepts

The behavior is small. Learn these ideas and everything in the ACE list is just a knob you turn.

**The node is the projectile - there is no bullet id.** You attach one `Bullet3DBehavior` to each node that should fly. Every Action and Expression acts on the behavior of the node it is placed on, so nothing takes a "bullet id" or emitter argument. One behavior, one moving node.

**It launches itself on the first frame.** The moment the node enters the scene and runs its first process frame, the behavior launches along the host's forward direction at the current speed. So the common case - spawn a bullet aimed the right way and let it fly - needs zero rows: just set speed and gravity in the Inspector and spawn the node.

**Forward is the node's -Z direction.** In Godot 3D, a node's "forward" is the negative Z of its own basis. The behavior launches that way, so to aim a shot you rotate the node (point the barrel, the hand, the turret) and the bullet flies where it faces.

**Speed is how fast it travels.** The **speed** knob is units per second along the launch direction. It is read at launch time: raise it for a faster, flatter shot; lower it for a slow, floaty one.

**Gravity bends the path into an arc.** The **gravity** knob pulls the projectile's vertical velocity down a little every frame. `0` gives a dead-straight line (a laser); a positive value makes it rise and fall like a thrown object; a negative value makes it drift upward like a bubble. Gravity is read every frame, so changing it bends a shot that is already in the air.

**Two ways to change speed, and they take effect at different times.** The friendly **Set Bullet 3D Speed** re-scales the live velocity while keeping the current heading, so it changes a bullet that is already flying, right now. The auto-generated **Set Speed** (and **Add To Speed** / **Subtract From Speed**) write the speed field, which is only read the next time the shot launches - so they set the speed for the next **Launch Forward**, not for a bullet already mid-flight.

**Relaunching re-aims and re-fires.** **Launch Forward** points the velocity straight along the host's current facing at the current speed and marks the shot launched. Use it to fire a pooled bullet you have just repositioned and re-aimed, or to snap a flying shot back onto a fresh heading. A brand-new bullet already launches itself, so you only need Launch Forward to relaunch.

---

## Setup

**1. Attach the behavior.** Add a `Bullet3DBehavior` as a child node of the `Node3D` you want to fly (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in). The parent must be a `Node3D`; if it is not, the behavior prints a warning and does nothing. One behavior per projectile.

**2. Set the Inspector knobs (optional).** Select the behavior node and set the starting feel. Both are also settable live from the sheet.

| Property | Default | What it does |
|---|---|---|
| `speed` | `10.0` | Launch speed in units per second along the forward (-Z) direction. Read at launch. |
| `gravity` | `0.0` | Downward pull applied to vertical velocity each frame. `0` = straight line; positive = arcs down; negative = drifts up. |

**3. Spawn it and go.** Because the shot launches itself on the first frame, the minimal projectile needs nothing but a speed and a gravity. Here is a flat, fast bolt:

```
On Ready
  -> Bullet | Bullet3DBehavior: Set Speed  30
  -> Bullet | Bullet3DBehavior: Set Gravity  0
```

Setting these in `On Ready` writes them before the first process frame, so the automatic launch reads the new values. Aim the node (its rotation) before it spawns and the bolt flies that way. If you would rather fire on demand - for a pooled bullet you reposition and re-aim - call **Launch Forward** yourself instead of relying on the auto-launch.

---

## ACE reference

All ACEs live in the **Bullet 3D** category and target the `Bullet3DBehavior` behavior on the node they are placed on. There is no bullet-id parameter anywhere. The pack ships two friendly verbs (Launch Forward, Set Bullet 3D Speed) and, because it exposes its two properties, an auto-generated Set / Add To / Subtract From action and a read-back expression for each.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Launch Forward | (none) | (Re)launches along the host's current forward (-Z) direction at the current speed. A new bullet auto-launches, so use this to relaunch a repositioned or re-aimed shot. |
| Set Bullet 3D Speed | `value` (float) | Changes speed while keeping the current heading, applied to the live velocity right away - the way to re-speed a bullet already in flight. |
| Set Speed | `value` (float) | Writes the speed field directly. Read at launch time, so it sets the speed used by the next Launch Forward (not a bullet already flying). |
| Add To Speed | `amount` (float) | Adds to the speed field (used by the next launch). |
| Subtract From Speed | `amount` (float) | Subtracts from the speed field (used by the next launch). |
| Set Gravity | `value` (float) | Sets the gravity pull directly. Read every frame, so it bends a shot already in flight. |
| Add To Gravity | `amount` (float) | Adds to the gravity pull (steepen the arc), live. |
| Subtract From Gravity | `amount` (float) | Subtracts from the gravity pull (flatten or float the arc), live. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| (none) | - | This pack exposes no conditions; read a value with an expression (Speed or Gravity) and compare it in an ordinary event condition. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Speed | (none) | float | The current launch speed in units per second. |
| Gravity | (none) | float | The current gravity pull applied to the arc. |

### Triggers

| Trigger | Fires when |
|---|---|
| (none) | This pack exposes no triggers; drive it from your own events (On Ready, timers, fire buttons, collisions). |

### Inspector properties

| Property | Type | Default |
|---|---|---|
| `speed` | float | `10.0` |
| `gravity` | float | `0.0` |

Note: the behavior also tracks how far it has flown internally, but there is no expression to read that distance. For range-based despawn, measure the node's position against its start yourself.

---

## Use cases

Each example targets the `Bullet3DBehavior` on the named node. Set speed and gravity once in `On Ready` (or at spawn), and change them live from timers, fire buttons, or stimuli when you want the shot to react. The `On ...` events below are your own game events; this pack ships no triggers of its own.

### 1. A dead-straight laser bolt

Zero gravity and a high speed give a flat beam that flies exactly along the barrel's facing.

```
On Ready
  -> Bolt | Bullet3DBehavior: Set Speed  60
  -> Bolt | Bullet3DBehavior: Set Gravity  0
```

The shot auto-launches on its first frame, so aiming the node before spawn is all the wiring it needs.

### 2. A lobbed grenade with an arc

A moderate speed plus a positive gravity makes the grenade rise, peak, and drop like a real throw.

```
On Ready
  -> Grenade | Bullet3DBehavior: Set Speed  14
  -> Grenade | Bullet3DBehavior: Set Gravity  18
```

Tune the arc by trading speed against gravity: more speed reaches further, more gravity drops sooner.

### 3. Fire a pooled rocket on button press

Reposition and re-aim a reusable rocket node, then relaunch it along its new facing.

```
On Fire Pressed
  -> Rocket: move to Muzzle.global_position
  -> Rocket: aim at crosshair
  -> Rocket | Bullet3DBehavior: Launch Forward
```

Launch Forward re-reads the node's forward direction, so the shot leaves exactly where the muzzle is pointing.

### 4. A charge-up shot

Build speed while the fire button is held, then relaunch on release so the charged value is used.

```
While Fire Held
  -> Cannon | Bullet3DBehavior: Add To Speed  1

On Fire Released
  -> Cannon | Bullet3DBehavior: Launch Forward
```

Add To Speed writes the speed field; Launch Forward reads it, so the longer you hold, the faster it flies.

### 5. Bullet-time slow and restore

Re-scale every bullet's live velocity to a crawl on a time-stop, then back to full when time resumes. Set Bullet 3D Speed keeps each shot's heading while it slows.

```
On Time Slow
  -> Bullet | Bullet3DBehavior: Set Bullet 3D Speed  4

On Time Resume
  -> Bullet | Bullet3DBehavior: Set Bullet 3D Speed  60
```

Set Bullet 3D Speed (not Set Speed) is the right verb here because it changes bullets already in the air.

### 6. A heavy mortar with a steep drop

A big gravity and a chosen speed give a slow, high, dropping shell for siege weapons.

```
On Ready
  -> Shell | Bullet3DBehavior: Set Speed  20
  -> Shell | Bullet3DBehavior: Set Gravity  40
```

### 7. A floaty anti-gravity orb

A negative gravity flips the pull upward, so a bubble or spirit projectile drifts up instead of falling.

```
On Ready
  -> Orb | Bullet3DBehavior: Set Speed  8
  -> Orb | Bullet3DBehavior: Set Gravity  -6
```

### 8. An updraft zone that lightens the arc

Gravity is read every frame, so subtracting from it while a shot is inside a wind column flattens its fall live.

```
On Enter Updraft
  -> Arrow | Bullet3DBehavior: Subtract From Gravity  12

On Exit Updraft
  -> Arrow | Bullet3DBehavior: Add To Gravity  12
```

Because gravity changes take effect immediately, the arrow visibly floats through the column and drops again past it.

### 9. A redirectable seeker

Re-aim the node toward a target each tick and relaunch, for a cheap homing feel with no steering maths.

```
Every 0.2 seconds
  -> Missile: aim at Player.global_position
  -> Missile | Bullet3DBehavior: Launch Forward
```

Each Launch Forward snaps the velocity onto the missile's fresh facing, so it curves toward the player over time.

### 10. An accelerating rocket

Ramp the speed field and relaunch each tick so a rocket winds up faster in flight, capped by reading the Speed expression.

```
Every 0.1 seconds
  Condition: Rocket | Bullet3DBehavior  Speed  <  120
    -> Rocket | Bullet3DBehavior: Add To Speed  6
    -> Rocket | Bullet3DBehavior: Launch Forward
```

The Speed expression gates the ramp so it stops accelerating once it hits 120 units per second.

### 11. A shotgun spread from one behavior

Spawn several nodes, each rotated a little, and every one launches along its own facing for an instant fan of pellets.

```
On Shotgun Fired
  -> Pellet: spawn 5 copies, each rotated by spread_index * 8 degrees
  -> Pellet | Bullet3DBehavior: Set Speed  45
  -> Pellet | Bullet3DBehavior: Set Gravity  2
```

The spread comes entirely from each pellet's rotation; the behavior just flies each one forward.

### 12. Pop an item out of a chest

A little speed and gravity make a reward burst upward out of a chest and settle nearby.

```
On Chest Opened
  -> Reward: spawn at Chest.global_position
  -> Reward | Bullet3DBehavior: Set Speed  10
  -> Reward | Bullet3DBehavior: Set Gravity  22
```

### 13. Per-weapon muzzle velocity

The same behavior fires slow or fast depending on the weapon that spawned the shot - set the speed at spawn.

```
On Sniper Fired
  -> Round | Bullet3DBehavior: Set Speed  90
  -> Round | Bullet3DBehavior: Set Gravity  0

On Pistol Fired
  -> Round | Bullet3DBehavior: Set Speed  40
  -> Round | Bullet3DBehavior: Set Gravity  1
```

### 14. Freeze a shot in mid-air

Set Bullet 3D Speed to 0 stops the live velocity, so a bolt hangs in place during a time-stop (with gravity at 0 it stays put).

```
On Time Freeze
  -> Bolt | Bullet3DBehavior: Set Gravity  0
  -> Bolt | Bullet3DBehavior: Set Bullet 3D Speed  0

On Time Unfreeze
  -> Bolt | Bullet3DBehavior: Set Bullet 3D Speed  60
```

---

## Tips and common mistakes

- **The node is the projectile - there is no bullet id.** Every Action and Expression acts on the `Bullet3DBehavior` of the node it is placed on. Attach one behavior per flying node; you never pass a bullet or emitter id.
- **It launches itself on the first frame.** A freshly spawned bullet auto-launches along its facing at the current speed. You do not need Launch Forward for the common case - aim the node and spawn it. Launch Forward is for relaunching a pooled or re-aimed shot.
- **Aim by rotating the node.** Forward is the node's -Z direction. To change where a shot goes, rotate the node (the barrel, the hand, the turret) before it launches; the behavior flies whatever way the node faces.
- **Set values in On Ready so the auto-launch sees them.** `On Ready` runs before the first process frame, so a Set Speed there is picked up by the automatic launch. Set speed and gravity later than that and only the next Launch Forward will use the new speed.
- **Set Bullet 3D Speed changes a flying bullet; Set Speed does not.** Set Bullet 3D Speed re-scales the live velocity right now (keeping heading), so it re-speeds a shot already in the air. Set Speed, Add To Speed, and Subtract From Speed only write the speed field, which is read at launch - so they take effect on the next Launch Forward. Reach for the right one depending on whether the bullet is already flying.
- **Gravity is live; speed is read at launch.** Changing gravity (Set / Add To / Subtract From Gravity) bends a shot that is already in the air, immediately. Changing speed through the property actions waits for the next launch. This asymmetry is deliberate - lean on it.
- **Negative gravity floats, positive gravity drops, zero is a straight line.** Use `0` for lasers and beams, a positive value for thrown and lobbed shots, and a negative value for rising bubbles or spirits.
- **The parent must be a Node3D.** The behavior moves its parent's 3D position, so it needs a `Node3D` parent. A 2D or plain Node parent makes it warn and do nothing; for 2D scenes use the separate 2D Bullet pack instead.
- **There is no built-in distance readout or auto-despawn.** The behavior tracks distance internally but exposes no expression for it, and it never frees the node. Handle range limits and cleanup with your own events - compare the node's position to its start, or use a timer.
- **Relaunching resets the heading.** Launch Forward points the velocity straight along the node's current facing and clears any arc drop built up so far. That is exactly what you want for a re-aimed seeker, but if you only meant to change speed on a flying shot, use Set Bullet 3D Speed instead so the existing heading survives.
