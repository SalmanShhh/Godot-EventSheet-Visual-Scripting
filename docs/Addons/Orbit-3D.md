# Orbit 3D - Circling Motion in 3D, One Behavior Per Node

Orbit 3D is a Godot EventSheets behavior pack that sweeps a node around a center point every frame in a 3D scene. You attach an `Orbit3DBehavior` behavior to a `Node3D` - a moon, a shield drone, a spinning hazard - and that node starts circling. There is no manager and no target id to pass around: every Action and Expression targets the `Orbit3DBehavior` living on the node you drop it on. The behavior captures a center point (by default, wherever the node sits on its first frame), then each frame advances an internal angle by a speed and places the node on a circle around that center in the horizontal XZ plane. The height (Y) stays fixed at the center's height, so the node circles level like a moon over a planet. You set the circle size with a radius, reverse or freeze the sweep by changing the speed, and move the whole ring - including its height - by retargeting the center. All of it is drivable live from the sheet, so you can grow, shrink, retarget, and re-speed an orbit while the game runs.

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

- **Moons and satellites.** Attach it to a moon mesh, set a radius and speed, and it circles a planet with no path node and no animation track.
- **Shield drones around the player.** Give each guard drone its own behavior and retarget the center to the player's position so a ring of drones tracks the hero as they move.
- **Rotating 3D hazards.** A spike ball or swinging blade circles a fixed hub as a moving obstacle, driven by one speed value.
- **Orbiting pickups.** Coins or power-ups circle a beacon to draw the eye in a 3D level, then get pulled inward by shrinking the radius on collect.
- **Companion familiars.** A pet, orb, or drone hover-circles its owner, tightening or widening its ring as the situation changes.
- **Decorative rings and particles.** Motes, sparks, or ring segments circle an emitter node for a magic, sci-fi, or planetary-ring flourish.
- **Menu and title accents.** A 3D decoration slowly circles a logo mesh in the background of a title screen.
- **Circular patrol beats.** A sentry or camera drone walks a level circular path on a flat plane without a navigation setup.
- **Camera points of interest.** A target marker circles a scene so a follow camera slowly pans around an area.
- **Boss orbit attacks.** Minions or projectile nodes sweep a widening ring around a boss as the fight escalates.
- **Security cameras and spotlights.** A camera or light node circles a fixed post to sweep a room on a loop.
- **Solar-system and atom flourishes.** Several orbiters at different radii around one anchor read as planets or electrons circling a core.

---

## Core concepts

The behavior is small. Learn these ideas and everything in the ACE list is just a knob you turn.

**The node is the orbiter - there is no target id.** You attach one `Orbit3DBehavior` to each node that should circle. Every Action and Expression acts on the behavior of the node it is placed on, so nothing takes an "orbiter id" argument. One behavior, one circling node.

**The center is captured automatically, once.** On its very first frame the behavior reads the host node's current position and remembers it as the orbit center. So if you place a moon where you want its ring centered and set a radius, it orbits that spot with zero extra wiring. To orbit some other point - or to follow a moving anchor - call **Set Orbit 3D Center** with the coordinates you want.

**It circles in the flat XZ plane, and the height stays put.** Each frame the node is placed at `cos(angle)` along X and `sin(angle)` along Z, so it sweeps a level circle like a moon over a planet. The Y (height) is held at the center's Y and never changes on its own. To orbit at a different height, retarget the center with a new Y in **Set Orbit 3D Center**.

**Radius is the circle size.** The **radius** value is the distance from the center to the node - a bigger radius makes a wider ring. It is always a perfect circle in this pack (a single radius for both axes); set it to `0` and the node sits exactly on the center.

**Speed is degrees per second, and its sign is direction.** The **speed degrees** value drives how fast the angle sweeps. A positive value spins one way, a negative value spins the other, and `0` freezes the orbit in place while keeping the node parked on its ring.

**Set Orbit 3D Center moves the whole ring, height and all.** Because the center takes an X, Y, and Z, retargeting it both slides the circle across the ground and lifts or lowers the plane it sits on. Use it to anchor a moon to a planet, to follow a moving player, or to raise an orbit off the floor.

**Two ways to change the same knob.** Each tunable has a friendly value plus, because the pack exposes its properties, an auto-generated **Set**, **Add To**, and **Subtract From** action and a read-back expression per value (for example **Speed Degrees** and **Radius**). Use **Set** to write a value outright; use **Add To** and **Subtract From** to nudge or ramp a value smoothly over time; read the expression to react to the current value in a condition.

---

## Setup

**1. Attach the behavior.** Add an `Orbit3DBehavior` as a child node of the `Node3D` you want to circle (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in). The parent must be a `Node3D`; if it is not, the behavior prints a warning and does nothing. One behavior per orbiting node.

**2. Set the Inspector knobs (optional).** Select the behavior node and set the starting radius and speed. Both are also settable live from the sheet.

| Property | Default | What it does |
|---|---|---|
| `radius` | `3.0` | The distance from the center to the node (the circle size). |
| `speed_degrees` | `90.0` | Sweep speed in degrees per second. Negative reverses direction; `0` freezes. |

**3. Point it at a center and go.** The simplest orbit needs nothing but a radius and a speed, because the center auto-captures from the node's starting spot. Here is a moon circling wherever you placed it:

```
On Ready
  -> Moon | Orbit3DBehavior: Set Radius  5
  -> Moon | Orbit3DBehavior: Set Speed Degrees  45
```

And here is the same moon told to circle a specific planet instead of its own start position:

```
On Ready
  -> Moon | Orbit3DBehavior: Set Orbit 3D Center  Planet.position.x, Planet.position.y, Planet.position.z
  -> Moon | Orbit3DBehavior: Set Radius  5
  -> Moon | Orbit3DBehavior: Set Speed Degrees  45
```

A radius of `5` keeps a clean five-unit circle; a speed of `45` sweeps 45 degrees per second (a full loop every eight seconds).

---

## ACE reference

All ACEs live in the **Orbit 3D** category and target the `Orbit3DBehavior` behavior on the node they are placed on. There is no orbiter-id parameter anywhere. The pack ships one friendly verb and, because it exposes its properties, an auto-generated Set / Add To / Subtract From action and a read-back expression for each exported value.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Set Orbit 3D Center | `x` (float), `y` (float), `z` (float) | Orbits around the given point from now on (overrides the auto-captured center). The `y` sets the fixed height of the ring. |
| Set Radius | `value` (float) | Sets the circle radius directly (bigger = wider ring, 0 = sit on the center). |
| Add To Radius | `amount` (float) | Adds to the radius (grow the ring). |
| Subtract From Radius | `amount` (float) | Subtracts from the radius (tighten the ring). |
| Set Speed Degrees | `value` (float) | Sets the sweep speed directly, in degrees per second (negative reverses, 0 freezes). |
| Add To Speed Degrees | `amount` (float) | Adds to the sweep speed (accelerate the spin). |
| Subtract From Speed Degrees | `amount` (float) | Subtracts from the sweep speed (slow or reverse the spin). |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| (none) | - | This pack exposes no conditions; read a value with an expression (for example Speed Degrees or Radius) and compare it in an ordinary event condition. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Radius | (none) | float | The current circle radius. |
| Speed Degrees | (none) | float | The current sweep speed in degrees per second. |

### Triggers

| Trigger | Fires when |
|---|---|
| (none) | This pack exposes no triggers; drive it from your own events (On Ready, timers, stimuli). |

### Inspector properties

| Property | Type | Default |
|---|---|---|
| `radius` | float | `3.0` |
| `speed_degrees` | float | `90.0` |

---

## Use cases

Each example targets the `Orbit3DBehavior` on the named node. Set the radius and speed once in `On Ready`, and change them live from timers or stimuli when you want the orbit to react.

### 1. A moon circling a planet

Place the moon anywhere, then anchor its center to the planet and give it a radius and speed.

```
On Ready
  -> Moon | Orbit3DBehavior: Set Orbit 3D Center  Planet.position.x, Planet.position.y, Planet.position.z
  -> Moon | Orbit3DBehavior: Set Radius  8
  -> Moon | Orbit3DBehavior: Set Speed Degrees  30
```

A radius of `8` gives a wide ring; 30 degrees per second is a leisurely twelve-second loop.

### 2. Orbit wherever it starts, zero wiring

The center auto-captures on the first frame, so a decoration placed at its ring center just needs a radius and speed.

```
On Ready
  -> Charm | Orbit3DBehavior: Set Radius  2
  -> Charm | Orbit3DBehavior: Set Speed Degrees  90
```

You can also skip the sheet entirely for this one and set `radius` and `speed_degrees` on the Inspector.

### 3. Reverse the spin direction

A negative speed sweeps the other way. Flip a hazard's direction when a lever is pulled.

```
On Lever Pulled
  -> Blade | Orbit3DBehavior: Set Speed Degrees  -90
```

### 4. Freeze and resume an orbit

Speed `0` parks the node on its ring without moving it. Set a real speed again to resume.

```
On Time Stop
  -> Satellite | Orbit3DBehavior: Set Speed Degrees  0

On Time Resume
  -> Satellite | Orbit3DBehavior: Set Speed Degrees  60
```

### 5. Spin up over time

Ramp the speed each tick with Add To Speed Degrees for a hazard that starts slow and winds up faster.

```
Every 0.1 seconds
  Condition: Blade | Orbit3DBehavior  Speed Degrees  <  240
    -> Blade | Orbit3DBehavior: Add To Speed Degrees  6
```

The Speed Degrees expression gates the ramp so it stops climbing at 240 degrees per second.

### 6. Widen the orbit as a boss enrages

Grow the radius so an orbiting minion sweeps a bigger arc when the fight heats up.

```
On Boss Enrage
  -> Minion | Orbit3DBehavior: Add To Radius  4
  -> Minion | Orbit3DBehavior: Set Speed Degrees  120
```

### 7. Pull a pickup inward on collect

Shrink the radius to `0` so an orbiting coin spirals into its beacon when grabbed.

```
On Coin Collected
  -> Coin | Orbit3DBehavior: Set Radius  0
```

Setting the radius to zero puts the node exactly on its center point.

### 8. Shield drones that follow a moving player

The center does not auto-follow, so retarget it to the player's position every frame and the whole ring tracks the hero.

```
Every frame
  -> ShieldDrone | Orbit3DBehavior: Set Orbit 3D Center  Player.global_position.x, Player.global_position.y, Player.global_position.z
```

Attach the behavior to each drone; each one keeps its own place on the ring because its angle advances independently.

### 9. Raise the orbit off the floor

The center's Y is the ring's height. Retarget the center with a higher Y to lift a halo or drone above its anchor.

```
On Ready
  -> Halo | Orbit3DBehavior: Set Orbit 3D Center  Player.position.x, Player.position.y + 2.5, Player.position.z
  -> Halo | Orbit3DBehavior: Set Radius  1.5
  -> Halo | Orbit3DBehavior: Set Speed Degrees  120
```

### 10. A breathing orbit that pulses in and out

Alternate Add To and Subtract From on the radius to make an orb gently pulse toward and away from its center.

```
Every 1.0 seconds
  -> Orb | Orbit3DBehavior: Add To Radius  1

Every 1.0 seconds (offset 0.5)
  -> Orb | Orbit3DBehavior: Subtract From Radius  1
```

### 11. Retarget the orbit to a new anchor

Snap the center to a different object when the situation changes - for example a familiar that leaves the hero to circle an altar.

```
On Reach Altar
  -> Familiar | Orbit3DBehavior: Set Orbit 3D Center  Altar.position.x, Altar.position.y, Altar.position.z
  -> Familiar | Orbit3DBehavior: Set Radius  3
```

### 12. Sync an effect to the current orbit speed

Read the Speed Degrees expression to drive something else - here a trail effect that only shows once the orbit is spinning fast.

```
Every 0.2 seconds
  Condition: Comet | Orbit3DBehavior  Speed Degrees  >  150
    -> Comet: enable motion trail
  Else
    -> Comet: disable motion trail
```

### 13. Gradually slow an orbit to a stop

Bleed the speed down each tick with Subtract From Speed Degrees until it reaches zero, for a wind-down effect.

```
Every 0.1 seconds
  Condition: Fan | Orbit3DBehavior  Speed Degrees  >  0
    -> Fan | Orbit3DBehavior: Subtract From Speed Degrees  4
```

The Speed Degrees expression stops the bleed once the fan has coasted to a halt.

### 14. A ring of orbiters at different radii

Spawn several orbiters around one anchor and give each a different radius for a solar-system or nested-ring look.

```
On Spawn Planets
  -> Mercury | Orbit3DBehavior: Set Orbit 3D Center  Sun.position.x, Sun.position.y, Sun.position.z
  -> Mercury | Orbit3DBehavior: Set Radius  4
  -> Mercury | Orbit3DBehavior: Set Speed Degrees  90
  -> Earth | Orbit3DBehavior: Set Orbit 3D Center  Sun.position.x, Sun.position.y, Sun.position.z
  -> Earth | Orbit3DBehavior: Set Radius  7
  -> Earth | Orbit3DBehavior: Set Speed Degrees  45
```

Each planet shares the same center but its own radius and speed, so the inner one laps the outer one.

### 15. A black-hole spiral that speeds up as it falls

Combine a shrinking radius with a growing speed and snagged debris spirals inward faster and faster, like matter circling a drain.

```
On Debris Snagged
  -> Debris | Orbit3DBehavior: Set Orbit 3D Center  BlackHole.position.x, BlackHole.position.y, BlackHole.position.z

Every 0.1 seconds
  Condition: Debris | Orbit3DBehavior  Radius  >  0.5
    -> Debris | Orbit3DBehavior: Subtract From Radius  0.4
    -> Debris | Orbit3DBehavior: Add To Speed Degrees  20
```

Once the Radius expression reads 0.5 or less, remove the debris node - it has reached the center.

### Other use cases

**Planetarium diorama.** Nested orbiters at different radii and speeds around one sun read as a working solar-system exhibit.

**Torch-wisp lighting.** A light wisp circles the hero with the center raised on Y, throwing a moving halo around night-time exploration.

**Boss shield phases.** Guard drones widen their ring and speed up at each health phase, with the expressions gating how far the escalation goes.

**Derelict debris fields.** Junk circles wrecked ships at varied radii and lazy speeds, making empty space feel inhabited.

**Ritual altar climax.** Relics circle the altar during the chant and spiral inward as the ritual completes, landing on the center at the final word.

---

## Tips and common mistakes

- **The node is the orbiter - there is no target id.** Every Action and Expression acts on the `Orbit3DBehavior` of the node it is placed on. Attach one behavior per circling node; you never pass an orbiter id.
- **The center captures once, on the first frame.** The behavior remembers wherever the node sits on its first process frame as the center. If that spot is wrong, or you moved the node before it ran, call Set Orbit 3D Center to fix it. Do not rely on the auto-capture for a node that starts somewhere it should not orbit.
- **To orbit a moving anchor, retarget every frame.** The captured center is a fixed point; it does not chase a player or emitter on its own. Call Set Orbit 3D Center with the anchor's position each frame (or each tick) if the thing being orbited moves.
- **It circles in the flat XZ plane, and the height never changes on its own.** The node sweeps a level circle and stays at the center's Y. To orbit at a different height, retarget the center with a new Y; there is no separate height knob.
- **Speed is degrees per second, and the sign is the direction.** Positive and negative spin opposite ways; `0` freezes the node on its current ring without snapping it back to center. Use Add To and Subtract From Speed Degrees to ramp between them smoothly.
- **A radius of 0 parks the node on the center.** Shrinking the radius to zero places the node exactly on its center point rather than circling. Grow it back with Set Radius or Add To Radius to send it out onto a ring again.
- **Set Radius and the Radius expression are two ends of the same value.** Set Radius (and Add To / Subtract From Radius) write the circle size; the Radius expression reads it back so you can gate other events on how wide the ring currently is. The same pairing holds for Set Speed Degrees and the Speed Degrees expression.
- **The parent must be a Node3D.** The behavior circles its parent node's 3D position, so it needs a `Node3D` parent. A Node2D or plain Node parent makes it warn and do nothing; for 2D scenes, use the separate Orbit pack instead.
- **Set the radius and speed before the node needs them.** Do your Set Radius / Set Speed Degrees in On Ready (or right at spawn) so the very first loop already looks right, then change values live from timers or stimuli.
