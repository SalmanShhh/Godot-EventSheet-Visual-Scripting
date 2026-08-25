# Wave - Ripple the Picture Without Moving the Node

Wave is a Godot EventSheets behavior pack for water, heat haze, flags and dizziness. You attach a
`WaveBehavior` under any 2D node or Control, the pack copies its shader into your project and puts the
material on that node, and then **Wave** eases a travelling ripple in to the strength you name and
**Settle** eases it back out.

The distinction that makes it worth a pack: shaking a node's position moves its collision shape with
it, so a rippling water tile becomes a rippling floor and a dizzy screen becomes a player who cannot
be hit. This pushes the texture lookup instead. The picture ripples, the world does not move, and
nothing in physics ever hears about it.

---

## Table of Contents

1. [Where this pack shines](#where-this-pack-shines)
2. [Core concepts](#core-concepts)
3. [Setup](#setup)
4. [ACE reference](#ace-reference)
5. [Reading it from expressions - the Self section](#reading-it-from-expressions---the-self-section)
6. [Use cases](#use-cases)
7. [Tips and common mistakes](#tips-and-common-mistakes)

---

## Where this pack shines

- **Water surfaces.** A tile or a sprite that reads as liquid without an animation.
- **Heat haze.** Over a fire, a desert, an engine.
- **Flags and banners.** A cloth ripple that costs one sprite.
- **Dizziness and poison.** The whole screen swaying when the player is hurt.
- **Underwater.** A gentle, slow ripple on everything below the surface line.
- **Portals and rifts.** A strong, fast ripple on the thing that is not quite real.
- **Dream and memory scenes.** A soft sway for the whole layer.
- **Damage feedback on UI.** A health bar that wobbles when it drops.
- **Glitch effects.** A very short, very strong wave on a single frame.
- **Reflections.** A mirrored sprite with a ripple reads as a puddle.

---

## Core concepts

**The node is the thing that ripples.** Attach a `WaveBehavior` as a child, and that parent is the
**host**. It must be a `CanvasItem` - any 2D node or UI Control.

**Only the drawing moves.** The shader offsets where the picture is sampled from. Positions,
collision shapes, raycasts and physics all stay exactly where they were.

**Strength is a share of the picture's width.** `0.01` is a shimmer, `0.05` is water, `0.15` is a
hallucination. That is why the numbers are small.

**The other two dials are the shape.** `wave_length` is how many crests fit down the picture, and
`wave_speed` is how fast they travel. Both are dials rather than verbs, because they say what the
ripple is rather than when it happens. `wave_speed` at 0 freezes the ripple where it stands.

**Settle takes a time.** A ripple stopped instantly snaps the picture sideways, which looks like a
bug. That is why the row asks for seconds rather than being a switch.

**Every node gets its own copy at run time.** A material is a Resource, so two nodes pointing at the
same `.tres` share it. The behavior duplicates it the first time it writes. `own_material` turns that
off when a whole layer of water should move as one body.

---

## Setup

**1. Add the pack to the node.** Right-click the object in the Object bar, **Add behavior**, Wave.
That adds the `WaveBehavior` child, copies `wave.gdshader` and `wave_material.tres` into
`res://effects/`, and puts the material on the node as an undoable scene edit.

**2. Set the knob (optional).**

| Property | Default | What it does |
|---|---|---|
| `own_material` | `true` | Take a private copy of the material before turning a dial. Turn it off when a whole layer should ripple as one. |

**3. Start it moving.**

```
On Level Started
  -> WaterTile | WaveBehavior: Wave at 0.04 over 1.0 s
```

---

## ACE reference

All rows target the `WaveBehavior` on the node they are placed on, through the **On node** parameter
every pack row carries (default `$WaveBehavior`).

### Actions

| Row | Parameters | What it does |
|---|---|---|
| **Wave** | `strength` (float, default `0.03`), `seconds` (float, default `0.4`) | Eases the ripple in to that strength over that time. |
| **Settle** | `seconds` (float, default `0.4`) | Eases the ripple back out to still. |
| **Set Own Material** | `value` (bool) | Turns the private-copy rule on or off. |

### Conditions

| Row | What it answers |
|---|---|
| **Is Waving** | True while the picture is still moving. |

### Expressions

| Row | What it reads |
|---|---|
| **Wave Strength** | How hard the ripple is pushing, as a share of the picture's width. |
| **Own Material** | Whether this behavior takes a private copy of the material. |

### The shader's own dials

| Dial | Type | Starts at | What it is |
|---|---|---|---|
| `wave_strength` | 0 to 0.2 | `0.0` | How far the ripple pushes, as a share of the width. |
| `wave_length` | 0.5 to 32 | `6.0` | How many crests fit down the picture. |
| `wave_speed` | 0 to 20 | `4.0` | How fast the crests travel. 0 freezes the ripple. |

---

## Reading it from expressions - the Self section

Type `self` into any ƒx field on a node carrying the pack and its members insert as `$WaveBehavior.`
chains: `$WaveBehavior.is_waving()` as a condition, `$WaveBehavior.wave_strength()` where a sound or a
camera should follow the sway.

The shape dials read and write through the picked dial rows: **Set** `effect.wave_speed` is the row
that turns calm water choppy.

---

## Use cases

Each example targets the `WaveBehavior` on the named node.

### 1. Water that is always moving

```
On Level Started
  -> WaterTile | WaveBehavior: Wave at 0.04 over 1.0 s
```

Ease it in over a second so the level does not open mid-ripple.

### 2. Choppy water in a storm

```
On Storm Started
  -> WaterTile | WaveBehavior: Set effect.wave_speed to 9.0
  -> WaterTile | WaveBehavior: Wave at 0.09 over 3.0 s
```

### 3. Heat haze over a fire

```
On Fire Lit
  -> HazeSprite | WaveBehavior: Set effect.wave_length to 18.0
  -> HazeSprite | WaveBehavior: Wave at 0.012 over 0.8 s
```

Many small crests and a tiny strength is what haze looks like.

### 4. A flag in the wind

```
On Ready
  -> Banner | WaveBehavior: Set effect.wave_length to 3.0
  -> Banner | WaveBehavior: Wave at 0.06 over 0.5 s
```

Few crests and a bigger push reads as cloth rather than as liquid.

### 5. Wind that rises and falls

```
Every 4 seconds
  -> Banner | WaveBehavior: Wave at randf_range(0.03, 0.09) over 2.0 s
```

### 6. Poison making the screen sway

```
On Poisoned
  -> ScreenLayer | WaveBehavior: Wave at 0.02 over 0.6 s
On Cured
  -> ScreenLayer | WaveBehavior: Settle over 1.2 s
```

### 7. Dizzy after a big hit

```
On Big Hit
  -> ScreenLayer | WaveBehavior: Wave at 0.05 over 0.1 s
  -> ScreenLayer | WaveBehavior: Settle over 1.5 s
```

Snap in, drift out. The two times are the whole feel of it.

### 8. Underwater section

```
On Entered Water
  -> WorldLayer | WaveBehavior: Set Own Material  false
  -> WorldLayer | WaveBehavior: Set effect.wave_speed to 1.5
  -> WorldLayer | WaveBehavior: Wave at 0.015 over 1.0 s
On Left Water
  -> WorldLayer | WaveBehavior: Settle over 0.6 s
```

Slow and shared, so the whole world sways as one body of water.

### 9. A portal that is not quite real

```
On Portal Opened
  -> Portal | WaveBehavior: Set effect.wave_speed to 14.0
  -> Portal | WaveBehavior: Wave at 0.12 over 0.4 s
```

### 10. A one-frame glitch

```
On Corruption Tick
  -> Screen | WaveBehavior: Wave at 0.18 over 0.0 s
  -> Wait 0.05 seconds
  -> Screen | WaveBehavior: Settle over 0.0 s
```

Zero seconds on both sides is a hard cut, which is exactly what a glitch is.

### 11. A health bar that wobbles when it drops

```
On Health Lost
  -> HealthBar | WaveBehavior: Wave at 0.03 over 0.05 s
  -> HealthBar | WaveBehavior: Settle over 0.5 s
```

### 12. Frozen water

```
On Freeze Spell
  -> WaterTile | WaveBehavior: Set effect.wave_speed to 0.0
```

Speed at 0 leaves the crests exactly where they are, which reads as ice rather than as still water.

### 13. Only settle what is actually moving

```
On Calm Cast
  For each WaterTile
    Condition: WaterTile | WaveBehavior: Is Waving
      -> WaterTile | WaveBehavior: Settle over 2.0 s
```

### 14. Sound that follows the sway

```
Every tick
  -> WaveSound: volume_db = linear_to_db(WaterTile | WaveBehavior: Wave Strength * 12.0)
```

### 15. A puddle reflection

```
On Ready
  -> ReflectionSprite | WaveBehavior: Set effect.wave_length to 10.0
  -> ReflectionSprite | WaveBehavior: Wave at 0.025 over 0.5 s
```

A mirrored copy of the sprite above, rippling gently, is the cheapest reflection there is.

### Other use cases

**Loading screens.** A logo with a very slow, very small wave reads as alive rather than as frozen,
which is worth a lot on a long load.

**Damage over time on a boss.** Strength tied to remaining health makes a boss visibly unstable as
the fight goes on, with no extra art.

**Text that speaks.** A dialogue label with a tiny wave while a character is talking, settled the
moment the line ends.

**Mirage in a desert.** A distant landmark sprite with a haze wave, settling as the player gets
close enough to see it plainly.

**Curtain and cloth props.** Set a low crest count and leave the wave running, and a static curtain
sprite becomes part of the scene.

---

## Tips and common mistakes

- **Nothing physical moves.** That is the point. If you want the node itself to shake, use a juice
  pack; this is for the picture only.
- **The numbers are small.** Strength is a share of the width, so `0.5` is not five times `0.1`, it
  is a broken picture. Stay under about `0.2`.
- **Always give Settle a time.** Snapping a ripple to zero jumps the picture sideways by however far
  it was pushed on that frame.
- **Speed 0 is a freeze, not a stop.** The crests stay where they are. Use Settle to remove them.
- **Edges hold rather than wrap.** A push that would read past the picture reads the edge instead, so
  a strong wave on a sprite with hard edges will smear them. Lower the strength or give the art
  margin.
- **Turn the private copy off for a whole body of water.** Tiles that share one material ripple in
  step, which is what makes them look like one surface.
- **A Control passes nothing down.** Put the behavior under the node that actually draws.
- **The shader file is yours after the first add.** Edits to `res://effects/wave.gdshader` survive
  updates, because nothing here ever overwrites a file that exists.
