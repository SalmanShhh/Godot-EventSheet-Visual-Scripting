# Orbit - Circle and Ellipse Motion Around a Point, One Behavior Per Node

Orbit is a Godot EventSheets behavior pack that sweeps a node around a center point every frame. You attach an `OrbitBehavior` behavior to a `Node2D` - a moon, a shield orb, a spinning hazard - and that node starts circling. There is no manager and no target id to pass around: every Action and Expression targets the `OrbitBehavior` living on the node you drop it on. The behavior captures a center point (by default, wherever the node sits on its first frame), then each frame advances an internal angle by a speed and places the node on a circle or ellipse around that center. You set the shape with a primary and secondary radius, tilt an ellipse with an offset angle, reverse or freeze the sweep by changing the speed, and optionally make the node face the direction it is travelling. All of it is drivable live from the sheet, so you can grow, shrink, retarget, and re-speed an orbit while the game runs.

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

- **Moons and planets.** Attach it to a moon, set a radius and speed, and it circles a planet with no path node and no tweening.
- **Shield orbs around the player.** Give each guard orb its own behavior and retarget the center to the player's position so a ring of orbs tracks the hero.
- **Rotating hazards.** A spike ball or saw blade circles a fixed hub as a moving obstacle, driven by one speed value.
- **Orbiting pickups.** Coins or power-ups circle a beacon to draw the eye, then get sucked inward by shrinking the radius on collect.
- **Bullet-hell rings.** Spawn a batch of orbiters around an emitter, each with a different offset angle, for an evenly spaced rotating ring.
- **Companion familiars.** A pet or drone hover-circles its owner, tightening or widening its ring as the situation changes.
- **Elliptical patrols.** A patrolling enemy walks an oval loop by giving the primary and secondary radius different values.
- **Atom and particle flourishes.** Electrons, sparks, or motes circle an emitter node for a decorative science or magic effect.
- **Menu and title accents.** A Node2D decoration slowly circles a logo in the background of a title screen.
- **Tilted decorative rings.** An offset angle skews an elliptical ring so it reads as a 3D-looking planetary ring in a flat 2D scene.
- **Homing-look projectiles.** With match rotation on, an arrow or ship sprite points along its curved path instead of staying flat.
- **Camera points of interest.** A target marker circles a scene so a follow camera slowly pans around an area.

---

## Core concepts

The behavior is small. Learn these ideas and everything in the ACE list is just a knob you turn.

**The node is the orbiter - there is no target id.** You attach one `OrbitBehavior` to each node that should circle. Every Action and Expression acts on the behavior of the node it is placed on, so nothing takes an "orbiter id" argument. One behavior, one circling node.

**The center is captured automatically, once.** On its very first frame the behavior reads the host node's current position and remembers it as the orbit center. So if you place a moon at the point you want it to circle and set a radius, it orbits that spot with zero extra wiring. To orbit some other point - or to follow a moving anchor - call **Set Orbit Center** with the coordinates you want.

**Circle or ellipse comes from two radii.** The **primary radius** is the horizontal reach; the **secondary radius** is the vertical reach. A secondary radius of `0` means "perfect circle" and the behavior uses the primary radius for both axes. Give them different non-zero values and you get an ellipse (an oval). Set both to `0` and the node sits exactly on the center.

**Speed is degrees per second, and its sign is direction.** The **speed degrees** value drives how fast the angle sweeps. A positive value spins one way, a negative value spins the other, and `0` freezes the orbit in place while keeping the node parked on its ring.

**The offset angle tilts an ellipse.** The **offset angle** rotates the whole ellipse around its center, so you can skew an oval to any diagonal. On a perfect circle it does nothing visible (a rotated circle is the same circle), so reach for it once your two radii differ.

**Match rotation faces the travel direction.** With **match rotation** on, the behavior turns the host to point along the direction it is moving each frame - handy for an arrow, ship, or fish that should nose into its curved path. With it off, the node keeps whatever rotation it already had.

**Two ways to change the same knob.** Each tunable has a friendly verb - **Set Orbit Center**, **Set Orbit Speed**, **Set Orbit Radii** - and, because the pack exposes its properties, an auto-generated **Set**, **Add To**, and **Subtract From** action plus a read-back expression per value (for example **Speed Degrees**). Use the friendly verbs to set a value outright; use **Add To** and **Subtract From** to nudge or ramp a value smoothly over time.

---

## Setup

**1. Attach the behavior.** Add an `OrbitBehavior` as a child node of the `Node2D` you want to circle (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in). The parent must be a `Node2D`; if it is not, the behavior prints a warning and does nothing. One behavior per orbiting node.

**2. Set the Inspector knobs (optional).** Select the behavior node and set the starting shape and feel. Every one of these is also settable live from the sheet.

| Property | Default | What it does |
|---|---|---|
| `primary_radius` | `100.0` | The horizontal reach of the orbit (and the whole circle radius when the secondary radius is 0). |
| `secondary_radius` | `0.0` | The vertical reach. `0` = perfect circle; any other value makes an ellipse. |
| `speed_degrees` | `90.0` | Sweep speed in degrees per second. Negative reverses direction; `0` freezes. |
| `offset_angle_degrees` | `0.0` | Tilts the ellipse around its center (no visible effect on a perfect circle). |
| `match_rotation` | `false` | When on, the node turns to face the direction it is travelling. |

**3. Point it at a center and go.** The simplest orbit needs nothing but a radius and a speed, because the center auto-captures from the node's starting spot. Here is a moon circling wherever you placed it:

```
On Ready
  -> Moon | OrbitBehavior: Set Orbit Radii  120, 0
  -> Moon | OrbitBehavior: Set Orbit Speed  60
```

And here is the same moon told to circle a specific planet instead of its own start position:

```
On Ready
  -> Moon | OrbitBehavior: Set Orbit Center  Planet.position.x, Planet.position.y
  -> Moon | OrbitBehavior: Set Orbit Radii  120, 0
  -> Moon | OrbitBehavior: Set Orbit Speed  60
```

Radii of `120, 0` make a circle of radius 120; a speed of `60` sweeps 60 degrees per second (a full loop every six seconds).

---

## ACE reference

All ACEs live in the **Orbit** category and target the `OrbitBehavior` behavior on the node they are placed on. There is no orbiter-id parameter anywhere. The pack ships three friendly verbs and, because it exposes its properties, an auto-generated Set / Add To / Subtract From action and a read-back expression for each exported value.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Set Orbit Center | `x` (float), `y` (float) | Orbits around the given point from now on (overrides the auto-captured center). |
| Set Orbit Speed | `degrees_per_second` (float) | Sets the sweep speed in degrees per second (negative reverses). |
| Set Orbit Radii | `primary` (float), `secondary` (float) | Sets both radii at once (secondary 0 = circle, otherwise an ellipse). |
| Set Primary Radius | `value` (float) | Sets the primary (horizontal) radius directly. |
| Add To Primary Radius | `amount` (float) | Adds to the primary radius (grow the ring). |
| Subtract From Primary Radius | `amount` (float) | Subtracts from the primary radius (tighten the ring). |
| Set Secondary Radius | `value` (float) | Sets the secondary (vertical) radius directly. |
| Add To Secondary Radius | `amount` (float) | Adds to the secondary radius. |
| Subtract From Secondary Radius | `amount` (float) | Subtracts from the secondary radius. |
| Set Speed Degrees | `value` (float) | Sets the sweep speed directly (same value as Set Orbit Speed). |
| Add To Speed Degrees | `amount` (float) | Adds to the sweep speed (accelerate the spin). |
| Subtract From Speed Degrees | `amount` (float) | Subtracts from the sweep speed (slow or reverse the spin). |
| Set Offset Angle Degrees | `value` (float) | Sets the ellipse tilt in degrees. |
| Add To Offset Angle Degrees | `amount` (float) | Adds to the ellipse tilt. |
| Subtract From Offset Angle Degrees | `amount` (float) | Subtracts from the ellipse tilt. |
| Set Match Rotation | `value` (bool) | Turns face-the-travel-direction on or off. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| (none) | - | This pack exposes no conditions; read a value with an expression (for example Speed Degrees) and compare it in an ordinary event condition. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Primary Radius | (none) | float | The current primary (horizontal) radius. |
| Secondary Radius | (none) | float | The current secondary (vertical) radius (0 means circle). |
| Speed Degrees | (none) | float | The current sweep speed in degrees per second. |
| Offset Angle Degrees | (none) | float | The current ellipse tilt in degrees. |
| Match Rotation | (none) | bool | Whether the node is facing its travel direction. |

### Triggers

| Trigger | Fires when |
|---|---|
| (none) | This pack exposes no triggers; drive it from your own events (On Ready, timers, stimuli). |

### Inspector properties

| Property | Type | Default |
|---|---|---|
| `primary_radius` | float | `100.0` |
| `secondary_radius` | float | `0.0` |
| `speed_degrees` | float | `90.0` |
| `offset_angle_degrees` | float | `0.0` |
| `match_rotation` | bool | `false` |

---

## Use cases

Each example targets the `OrbitBehavior` on the named node. Set the shape once in `On Ready`, and change it live from timers or stimuli when you want the orbit to react.

### 1. A moon circling a planet

Place the moon anywhere, then anchor its center to the planet and give it a radius and speed.

```
On Ready
  -> Moon | OrbitBehavior: Set Orbit Center  Planet.position.x, Planet.position.y
  -> Moon | OrbitBehavior: Set Orbit Radii  140, 0
  -> Moon | OrbitBehavior: Set Orbit Speed  45
```

A secondary radius of `0` keeps it a clean circle; 45 degrees per second is a leisurely eight-second loop.

### 2. An elliptical patrol loop

Give the two radii different values and the node walks an oval instead of a circle - a wider-than-tall patrol path for a guard.

```
On Ready
  -> Guard | OrbitBehavior: Set Orbit Radii  260, 120
  -> Guard | OrbitBehavior: Set Orbit Speed  30
```

### 3. Reverse the spin direction

A negative speed sweeps the other way. Flip a hazard's direction when a lever is pulled.

```
On Lever Pulled
  -> Blade | OrbitBehavior: Set Orbit Speed  -90
```

### 4. Freeze and resume an orbit

Speed `0` parks the node on its ring without moving it. Set a real speed again to resume.

```
On Time Stop
  -> Satellite | OrbitBehavior: Set Orbit Speed  0

On Time Resume
  -> Satellite | OrbitBehavior: Set Orbit Speed  60
```

### 5. Tilt an elliptical ring

An offset angle skews an oval so it reads like a slanted planetary ring. This only shows on an ellipse, so give the radii different values first.

```
On Ready
  -> Ring | OrbitBehavior: Set Orbit Radii  300, 90
  -> Ring | OrbitBehavior: Set Offset Angle Degrees  25
```

### 6. Spin up over time

Ramp the speed each frame with Add To Speed Degrees for a hazard that starts slow and winds up faster.

```
Every 0.1 seconds
  Condition: Blade | OrbitBehavior  Speed Degrees  <  240
    -> Blade | OrbitBehavior: Add To Speed Degrees  6
```

The Speed Degrees expression gates the ramp so it stops climbing at 240 degrees per second.

### 7. Widen the orbit as a boss enrages

Grow the primary radius so an orbiting minion sweeps a bigger arc when the fight heats up.

```
On Boss Enrage
  -> Minion | OrbitBehavior: Add To Primary Radius  80
  -> Minion | OrbitBehavior: Set Orbit Speed  120
```

### 8. Suck a pickup inward on collect

Shrink both radii to `0` so an orbiting coin spirals into its beacon when grabbed.

```
On Coin Collected
  -> Coin | OrbitBehavior: Set Orbit Radii  0, 0
```

Setting both radii to zero puts the node exactly on its center point.

### 9. Face the direction of travel

Turn match rotation on so an arrow or ship noses along its curved path instead of lying flat.

```
On Ready
  -> Arrow | OrbitBehavior: Set Orbit Radii  180, 180
  -> Arrow | OrbitBehavior: Set Orbit Speed  90
  -> Arrow | OrbitBehavior: Set Match Rotation  true
```

### 10. Shield orbs that follow a moving player

The center does not auto-follow, so retarget it to the player's position every frame and the whole ring tracks the hero.

```
Every frame
  -> ShieldOrb | OrbitBehavior: Set Orbit Center  Player.global_position.x, Player.global_position.y
```

Attach the behavior to each orb and give each a small offset angle so they space out around the ring.

### 11. A bullet-hell ring from one behavior per bullet

Spawn a batch of orbiters around an emitter and hand each a different offset angle so they form an evenly spaced rotating ring.

```
On Spawn Ring
  -> Bullet | OrbitBehavior: Set Orbit Center  Emitter.position.x, Emitter.position.y
  -> Bullet | OrbitBehavior: Set Orbit Radii  60, 60
  -> Bullet | OrbitBehavior: Set Offset Angle Degrees  Bullet.spawn_index * 45
  -> Bullet | OrbitBehavior: Set Orbit Speed  120
```

### 12. Breathing orbit that pulses in and out

Alternate Add To and Subtract From on the primary radius to make an orb gently pulse toward and away from its center.

```
Every 1.0 seconds
  -> Orb | OrbitBehavior: Add To Primary Radius  20

Every 1.0 seconds (offset 0.5)
  -> Orb | OrbitBehavior: Subtract From Primary Radius  20
```

### 13. Retarget the orbit to a new anchor

Snap the center to a different object when the situation changes - for example a familiar that leaves the hero to circle an altar.

```
On Reach Altar
  -> Familiar | OrbitBehavior: Set Orbit Center  Altar.position.x, Altar.position.y
  -> Familiar | OrbitBehavior: Set Orbit Radii  70, 70
```

### 14. Sync an effect to the current orbit speed

Read the Speed Degrees expression to drive something else - here a trail effect that only shows once the orbit is spinning fast.

```
Every 0.2 seconds
  Condition: Comet | OrbitBehavior  Speed Degrees  >  150
    -> Comet: enable motion trail
  Else
    -> Comet: disable motion trail
```

### 15. A telegraphed hazard escalation with Flash

Pair the orbit with the Flash pack for fair difficulty spikes: the saw blade blinks its warning first, and the exact frame the blink ends, the orbit steps up.

```
On Hazard Phase Up
  -> Saw | FlashBehavior: Flash  0.8

On Flash Finished
  -> Saw | OrbitBehavior: Add To Speed Degrees  90
  -> Saw | OrbitBehavior: Add To Primary Radius  40
```

Stepping both the speed and the primary radius makes the new sweep visibly bigger and faster the moment the warning ends.

### Other use cases

**Clockwork puzzle rooms.** Gears, hands, and platforms are all orbiters with linked speeds, and one lever reversing a subset re-times the whole room.

**Bullet-hell lattices.** Rings of shots at staggered offset angles weave overlapping rotating patterns from nothing but per-bullet knobs.

**Carnival vignette.** Carriages on a tall ellipse with match rotation on read as a Ferris wheel turning behind the midway.

**Koi pond ambience.** Fish drift on slow, tilted ellipses at different speeds so the pond feels alive without a single path node.

**Magic shield stance.** Guard orbs tighten their radius while blocking and fling outward with a fast radius grow as the counter-attack.

---

## Tips and common mistakes

- **The node is the orbiter - there is no target id.** Every Action and Expression acts on the `OrbitBehavior` of the node it is placed on. Attach one behavior per circling node; you never pass an orbiter id.
- **The center captures once, on the first frame.** The behavior remembers wherever the node sits on its first process frame as the center. If that spot is wrong, or you moved the node before it ran, call Set Orbit Center to fix it. Do not rely on the auto-capture for a node that starts somewhere it should not orbit.
- **To orbit a moving anchor, retarget every frame.** The captured center is a fixed point; it does not chase a player or emitter on its own. Call Set Orbit Center with the anchor's position each frame (or each tick) if the thing being orbited moves.
- **A secondary radius of 0 means circle, not "no vertical motion."** When the secondary radius is 0 the behavior uses the primary radius for both axes, giving a perfect circle. Set both radii to the same non-zero value for a circle of that size, or different values for an ellipse.
- **The offset angle only shows on an ellipse.** Tilting a perfect circle changes nothing you can see. Give the two radii different values first, then the offset angle skews the oval.
- **Speed is degrees per second, and the sign is the direction.** Positive and negative spin opposite ways; `0` freezes the node on its current ring without snapping it back to center. Use Add To and Subtract From Speed Degrees to ramp between them smoothly.
- **Match rotation owns the node's rotation.** While it is on, the behavior sets the host's rotation every frame to face its travel direction, so any rotation you set elsewhere gets overwritten. Turn it off if you want to control the facing yourself.
- **Set Orbit Speed and Set Speed Degrees do the same thing.** The friendly verbs (Set Orbit Speed, Set Orbit Radii, Set Orbit Center) and the auto-generated property actions (Set Speed Degrees, Set Primary Radius, and so on) write the same values. Use whichever reads more clearly; reach for Add To / Subtract From when you want to nudge rather than replace.
- **The parent must be a Node2D.** The behavior circles its parent node's position, so it needs a `Node2D` parent. A Control or plain Node parent makes it warn and do nothing; for 3D scenes, use the separate Orbit 3D pack instead.
- **Set the shape before the node needs it.** Do your Set Orbit Radii / Set Orbit Speed in On Ready (or right at spawn) so the very first loop already looks right, then change values live from timers or stimuli.
