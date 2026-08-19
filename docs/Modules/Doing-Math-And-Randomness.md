# Doing Math And Randomness

Every number verb the plugin ships, in one place. These are **builtin** verbs - they need no addon, no
autoload and no setup. Open the picker on any sheet and they are already there, under **Math & Random**,
**Helpers** and **Procedural**.

Almost all of them are expressions: values you drop into a parameter cell rather than rows of their own.
"Set Health to Clamp(health - 10, 0, 100)" is one action row whose Value cell holds a Clamp. A handful
are conditions (Is Equal (approx), Is Within Angle, Seeded Chance) and three are actions
(Seed Random, Randomize Seed, Set Random Seed).

Each one compiles to a plain Godot call - `clampf`, `lerpf`, `randi_range`, `hash` - with no plugin
runtime behind it. What you read in the **Ships as** column is character-for-character what lands in
your `.gd` file.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Verb reference](#verb-reference)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Keeping a value in bounds** - health, ammo, a volume slider, a camera zoom.
- **Smooth motion** - a camera that eases behind the player, a turret that swings round instead of
  snapping.
- **Bars and meters** - one expression turns "37 of 120 health" into the 0-to-1 number a bar wants.
- **Aiming and facing** - the angle from here to there, and whether something is roughly pointing at you.
- **Grids** - snapping to tile centres, and speaking distances in tiles rather than pixels.
- **Random rolls** - loot, damage spread, spawn timing, dialogue variation.
- **Repeatable randomness** - daily challenges and replays that come out the same every time.
- **Editor-time generation** - stateless seeded values that work inside an Editor Tool sheet, where a
  game-time autoload does not exist yet.
- **Guarding maths on loaded data** - checking that a value out of a save or a JSON payload really is a
  number before doing arithmetic on it.

## Core concepts

- **Expressions go in cells, not in rows.** Clamp, Lerp, Random and their kin are values. You reach them
  from the ƒx picker on any parameter cell, and they nest: the Value of a Clamp can itself be a Lerp.
- **Degrees or radians, pick deliberately.** Godot works in radians. The verbs whose names say
  *(degrees)* - Sin (degrees), Cos (degrees), Tan (degrees) - convert for you, and Is Within Angle and
  Is Clockwise From take degrees throughout. Everything else in the angle family (Angle Toward, Angle Of
  (atan2), Angle Difference, Rotate Toward (angle), Lerp Angle, Sine, Cosine, Tangent, Arc Tangent (y, x))
  speaks radians. Degrees To Radians and Radians To Degrees are the bridge.
- **Whole numbers have their own clamp and wrap.** Clamp and Clamp (float) return a decimal, which
  truncates or type-errors on the way back into an `int` variable. Clamp (int) and Wrap (int) keep the
  result a clean whole number - use those for score, health, ammo and menu indexes.
- **Two names, two modules, one idea.** Absolute Value, Square Root, Power, Degrees To Radians and
  Radians To Degrees each ship twice: once in **Math & Random** and once in **Helpers**. They differ only
  in which Godot function they emit (`absf` versus `abs`, `pow({base}, {exponent})` versus
  `pow({base}, {exp})`). Either is correct; the Math & Random one is the float-typed reading.
- **Randomness has three flavours.** Live randomness (Random, Random Integer, Choose) draws from Godot's
  global generator. Seeding it (Seed Random, Set Random Seed, Randomize Seed) makes a whole run
  repeatable. And the **Procedural** family (Seeded Value, Seeded Int, Seeded Pick, Seeded Sign, Seeded
  Chance) is stateless: a seed plus an index always gives the same answer, with no generator state at
  all, which is what makes it usable in the editor.
- **Progress Of is the inverse_lerp nobody finds.** Turning "current, empty, full" into 0-to-1 is the
  single most common number job in a game, and it already ships clamped.

## Verb reference

### Ranges, blending and curves

| Verb | What it does | Ships as |
|------|--------------|----------|
| Clamp | Keeps a value within a min and max, clipping anything outside the range. | `clampf({value}, {min}, {max})` |
| Clamp (float) | The same clamp, named as the decimal-typed one for ƒx expressions. | `clampf({value}, {min}, {max})` |
| Clamp (int) | Keeps a whole number within a min and max - use this, not the float clamp, for scores, health and ammo. | `clampi({value}, {min}, {max})` |
| Lerp | Blends between two values by a 0-to-1 weight. | `lerpf({from}, {to}, {weight})` |
| Inverse Lerp | Where a value sits within a range, as a 0-to-1 fraction. | `inverse_lerp({from}, {to}, {value})` |
| Smoothstep | Eases a value between two edges with an S-curve instead of a straight line. | `smoothstep({from}, {to}, {value})` |
| Smooth Lerp | Lerp, but the weight is eased with an S-curve first, so motion starts and ends gently. | `lerpf({from}, {to}, smoothstep(0.0, 1.0, {weight}))` |
| Ease | Bends a 0-to-1 value along an easing curve (above 1 eases in, below 1 eases out). | `ease({value}, {curve})` |
| Move Toward | Nudges a value toward a target by a limited step. | `move_toward({from}, {to}, {amount})` |
| Remap Range | Rescales a number from one range into another, e.g. 0-100 onto 0-1. | `remap({value}, {in_min}, {in_max}, {out_min}, {out_max})` |
| Wrap | Wraps a decimal value to stay in a range, looping past the edges. | `wrapf({value}, {min}, {max})` |
| Wrap (int) | Wraps a whole number around a range - cycling a menu or inventory index past the ends. | `wrapi({value}, {min}, {max})` |
| Ping-Pong | Bounces a value back and forth between 0 and a length. | `pingpong({value}, {length})` |
| Snap To Step | Rounds a value to the nearest step, for grids. | `snappedf({value}, {step})` |
| Snapped | The same snap, in the Helpers section. | `snappedf({value}, {step})` |
| Progress Of | How far a value has come through a range, as 0 to 1, already clamped. | `clampf(inverse_lerp({from}, {to}, {value}), 0.0, 1.0)` |
| Percent Of | The same reading as 0 to 100, the number you show as text. | `(clampf(inverse_lerp({from}, {to}, {value}), 0.0, 1.0) * 100.0)` |
| Ramped | A value that drifts over time and stops at a limit - see [the note below](#the-ramped-value). | a clamped drift from **Start**, by **Per Minute**, bounded by **Limit** |
| Tiles | A distance in tiles, sized by the `eventforge/tile_size` project setting (default 16). | `({count} * float(ProjectSettings.get_setting("eventforge/tile_size", 16.0)))` |

#### The Ramped value

Ramped is the difficulty curve as a number. Its full emitted form is long because it reads the clock and
clamps in one expression:

```gdscript
clampf(2.0 + -0.3 * (float(Time.get_ticks_msec()) / 60000.0 - float(get_meta(&"__ramp_zero", 0.0))), minf(2.0, 0.5), maxf(2.0, 0.5))
```

The three parameters are **Start** (the value at minute zero), **Per Minute** (drift per minute; negative
ramps down) and **Limit** (the value it never passes). Minutes are counted from whenever the **Start Ramp
Clock** action last ran on this node - call it when the run actually begins, not in the menus, or minutes
count from engine start.

### Angles

| Verb | What it does | Ships as |
|------|--------------|----------|
| Angle Toward | The angle from this node's position toward a target position (radians). Node2D only. | `position.angle_to_point({to})` |
| Angle Of (atan2) | The angle of the direction (x, y), correct in all four quadrants. | `atan2({y}, {x})` |
| Arc Tangent (y, x) | The same reading, in the Helpers section. | `atan2({y}, {x})` |
| Angle Difference | The shortest signed turn from one angle to another, in radians. | `angle_difference({from}, {to})` |
| Rotate Toward (angle) | Steps an angle toward a target by a limited amount, for smooth turning. | `rotate_toward({from}, {to}, {delta})` |
| Lerp Angle | Blends two angles by a 0-to-1 weight, taking the shortest path. | `lerp_angle({from}, {to}, {weight})` |
| Degrees To Radians | Converts degrees into the radians Godot uses. | `deg_to_rad({degrees})` |
| Radians To Degrees | Converts radians back into readable degrees. | `rad_to_deg({radians})` |
| Sin (degrees) | The sine of an angle given in degrees. | `sin(deg_to_rad({degrees}))` |
| Cos (degrees) | The cosine of an angle given in degrees. | `cos(deg_to_rad({degrees}))` |
| Tan (degrees) | The tangent of an angle given in degrees. | `tan(deg_to_rad({degrees}))` |
| Sine | The sine of an angle in radians. | `sin({value})` |
| Cosine | The cosine of an angle in radians. | `cos({value})` |
| Tangent | The tangent of an angle in radians. | `tan({value})` |
| Is Within Angle | **Condition.** True when two angles are close, taking wrap-around into account (350 is within 20 of 10). Degrees. | `absf(rad_to_deg(angle_difference(deg_to_rad({angle}), deg_to_rad({target})))) <= {within}` |
| Is Clockwise From | **Condition.** True when the shortest turn from the reference angle to this one is clockwise. Degrees. | `angle_difference(deg_to_rad({from}), deg_to_rad({angle})) >= 0.0` |
| Is Between Angles | **Condition.** True when an angle falls inside a window of directions - a firing arc, a sight cone. Degrees. | `(wrapf({angle}, 0.0, 360.0) >= {low} and wrapf({angle}, 0.0, 360.0) <= {high})` |
| Chance | **Condition.** True for the given share of the times it is asked - 30% is true roughly three times in ten. | `randf() < {percent} / 100.0` |

### Plain arithmetic

| Verb | What it does | Ships as |
|------|--------------|----------|
| Absolute Value | The number without its sign: abs(-5) is 5. Two versions ship. | `absf({value})` (Math & Random) / `abs({value})` (Helpers) |
| Square Root | The square root of a number. Two versions ship. | `sqrt({value})` |
| Power | A number raised to a power: 2 ^ 8 is 256. Two versions ship. | `pow({base}, {exponent})` / `pow({base}, {exp})` |
| Exponential | e raised to a power, the natural growth curve. | `exp({value})` |
| Pi | The circle constant 3.14159… | `PI` |
| Min | Whichever of two numbers is smaller. | `min({a}, {b})` |
| Max | Whichever of two numbers is larger. | `max({a}, {b})` |
| Round | Rounds to the nearest whole number. | `round({value})` |
| Floor | Rounds down to the nearest whole number. | `floor({value})` |
| Ceil | Rounds up to the nearest whole number. | `ceil({value})` |
| Sign | -1, 0 or 1, telling whether a number is negative, zero or positive. | `sign({value})` |
| Float Modulo | The remainder after dividing one decimal number by another. | `fmod({a}, {b})` |
| Positive Modulo | A modulo result that stays positive, for wrapping indexes. | `posmod({a}, {b})` |
| To Integer | The value as a whole number: int("42") is 42, int(3.9) is 3. | `int({value})` |
| To Decimal | The value as a decimal number: float("3.5") is 3.5. | `float({value})` |
| Distance To | The distance in pixels from this node to a target position. Node2D only. | `position.distance_to({to})` |
| Is Equal (approx) | **Condition.** True when two numbers are nearly equal, ignoring floating-point dust. | `is_equal_approx({a}, {b})` |
| Is Zero (approx) | **Condition.** True when a value is essentially zero. | `is_zero_approx({value})` |
| Value Is A Number | **Condition.** True when the value really holds a number - guard loaded data before maths. | `(typeof({value}) == TYPE_FLOAT or typeof({value}) == TYPE_INT)` |
| Is NaN | **Condition.** True when a calculation broke and produced not-a-number. | `is_nan({value})` |

### Randomness

| Verb | What it does | Ships as |
|------|--------------|----------|
| Random | A random decimal between two bounds. | `randf_range({from}, {to})` |
| Random Integer | A random whole number between two bounds, both included. | `randi_range({from}, {to})` |
| Choose | Picks one value at random from a comma-separated list. | `[{values}].pick_random()` |
| Seed Random | **Action.** Sets the random seed so the same number gives a repeatable sequence. | `seed({value})` |
| Set Random Seed | **Action.** The same, with the seed converted from any value. | `seed(int({seed}))` |
| Randomize Seed | **Action.** Reseeds from the clock so each playthrough differs. | `randomize()` |

### Procedural (stateless, editor-safe)

Every one takes a **Seed** (any text) and an **Index** (which value in the sequence). The same pair always
gives the same answer, with no generator state anywhere - so these work inside an Editor Tool sheet and
while filling a Custom Resource, as well as at runtime.

| Verb | What it does | Ships as |
|------|--------------|----------|
| Seeded Value | A stable pseudo-random decimal in 0 to 1 (excluding 1) for a seed and an index. | `(float(absi(hash(str({seed}) + "#" + str({index}))) % 1000000) / 1000000.0)` |
| Seeded Int | A stable pseudo-random whole number between Min and Max, inclusive. | `({minimum} + absi(hash(str({seed}) + "#" + str({index}))) % maxi({maximum} - {minimum} + 1, 1))` |
| Seeded Pick | A stable pseudo-random element of an array (nothing at all if the array is empty). | `(({options} as Array)[absi(hash(str({seed}) + "#" + str({index}))) % maxi(({options} as Array).size(), 1)] if not ({options} as Array).is_empty() else null)` |
| Seeded Sign | A stable -1 or +1 for a seed and an index. | `(1 if (absi(hash(str({seed}) + "#" + str({index}))) % 2) == 0 else -1)` |
| Seeded Chance | **Condition.** True for a stable share of seed and index pairs (0 to 100). | `((float(absi(hash(str({seed}) + "#" + str({index}))) % 1000000) / 1000000.0) * 100.0 < {percent})` |

### Random points in a shape

Scalar randomness answers "how much". These answer "where". Every one is AREA-correct: the obvious
spelling (a random angle plus a random radius) crowds points at the centre, because the outer rings of a
circle hold more area than the inner ones, and the weighting that undoes that is baked in here so nobody
has to remember it.

| Verb | What it does | Ships as |
|------|--------------|----------|
| Random Point In Circle | An evenly spread random point inside a circle. | `({center} + Vector2.RIGHT.rotated(randf() * TAU) * (sqrt(randf()) * {radius}))` |
| Random Point On Circle | A random point exactly on the rim, never inside it. | `({center} + Vector2.RIGHT.rotated(randf() * TAU) * {radius})` |
| Random Point In Ring | A random point in the doughnut between two radii - the off-screen spawner. | `({center} + Vector2.RIGHT.rotated(randf() * TAU) * sqrt(lerpf({inner_radius} * {inner_radius}, {outer_radius} * {outer_radius}, randf())))` |
| Random Point In Rectangle | A random point inside an axis-aligned rectangle. | `({top_left} + Vector2(randf() * {size}.x, randf() * {size}.y))` |
| Random Point In Cone | A random point inside a wedge - shotgun spread, cone attacks. Degrees in. | `({center} + Vector2.RIGHT.rotated(deg_to_rad({facing_degrees}) + randf_range(...)) * (sqrt(randf()) * {radius}))` |
| Random Point Around | Scatter around a node already in the scene, between two radii. | `({node}.global_position + Vector2.RIGHT.rotated(randf() * TAU) * sqrt(lerpf(...)))` |
| Random Direction (2D) | A random unit direction. Always exactly one unit long. | `Vector2.RIGHT.rotated(randf() * TAU)` |
| Random Direction (3D) | A random unit direction, evenly spread over the whole sphere. | `Vector3.UP.rotated(Vector3.RIGHT, acos(randf_range(-1.0, 1.0))).rotated(Vector3.UP, randf() * TAU)` |
| Random Point In Sphere | An evenly spread random point inside a 3D sphere. | the direction above times `pow(randf(), 1.0 / 3.0) * {radius}` |
| Random Point In Box | A random point inside an axis-aligned 3D box. Size is the FULL box. | `({center} + Vector3(randf_range(-1.0, 1.0) * {size}.x, ...) * 0.5)` |
| Random Point On Screen Edge | A random WORLD position on the border of what the camera can see. | a perimeter roll over the visible world rect |
| Jitter | Nudges a number, vector or colour by a random amount up to the size you give. | `({value} + {amount} * randf_range(-1.0, 1.0))` |

### Grid maths (no TileMap required)

Cell coordinates used to exist only if you owned a TileMapLayer, because **Local To Map** is its method.
Build grids, inventory grids, puzzle boards, chunk keys and tower placement all reason in cells with no
tilemap in sight. **Cell Distance** carries the same five-geometry dropdown as **Is Within Distance
(choose metric)**, so there is one spelling of "how is distance counted" in the whole plugin.

| Verb | What it does | Ships as |
|------|--------------|----------|
| Cell Of Point | Which grid cell a world position falls in. Negatives land in negative cells. | `Vector2i(floori({point}.x / maxf({cell_size}, 0.001)), floori({point}.y / maxf({cell_size}, 0.001)))` |
| Center Of Cell | The world position at the middle of a cell - the exact partner of Cell Of Point. | `(Vector2({cell}) * {cell_size} + Vector2({cell_size}, {cell_size}) * 0.5)` |
| Snap Point To Grid | The nearest grid intersection to a loose position. | `{point}.snapped(Vector2({cell_size}, {cell_size}))` |
| Snap Point To Grid (3D) | The same on a 3D grid - voxels, modular level pieces. | `{point}.snapped(Vector3({cell_size}, {cell_size}, {cell_size}))` |
| Cell Distance | How far apart two cells are, with the five-geometry dropdown. | an indexed array of the five measures |
| Neighbours Of Cell | The cells touching a cell: four sides, eight with diagonals, or six axial hex. | an indexed array of the three neighbourhoods |
| Cells In Line | Every cell a straight line passes through, in order, both ends included. | a `range().map()` walk between the two cells |
| Cells In Radius | Every cell within a step radius, as a list. | a row-reduce filtered by the shape |
| Cells In Rectangle | Every cell in a rectangular block, row by row. | a row-reduce over the block |
| Is Cell In Bounds | **Condition.** True while a cell is on the board. | `({cell}.x >= 0 and {cell}.y >= 0 and {cell}.x < {size}.x and {cell}.y < {size}.y)` |
| For Each Cell In Radius | **Looping condition.** Runs the event's actions once per cell in range, under the name `cell`. | the same walk as Cells In Radius, as a pick filter |

### Falloff and radial force

Distance-weighted strength is the single most reused number in game code. The plugin could already
COLLECT everything in a blast - **Query Bodies In Circle**, **In Sphere** - and then every body took
identical damage, because nothing said "less the further away".

| Verb | What it does | Ships as |
|------|--------------|----------|
| Falloff At Distance | 1 at the centre, 0 at the edge, with a Linear / Sharp (squared) / Smooth profile. Past the radius it is 0. | an indexed array of the three profiles |
| Strength Toward | The same falloff between THIS node and another one, without spelling out either position. | `(clampf(1.0 - global_position.distance_to({node}.global_position) / maxf({radius}, 0.001), 0.0, 1.0))` |
| Apply Radial Impulse | **Action.** Throws this physics body away from a blast, weaker the further it was. | a uid-named blast local, then `apply_impulse(...)` |
| Push Group Away From | **Action.** Shoves every member of a group away from a point - the mirror of Pull Group Toward. | a guarded walk over `get_nodes_in_group` |
| Is Within Cone Of | **Condition.** True while a point sits inside a facing wedge - guard vision, melee arcs. | a range test and an `angle_difference` test |


## Use cases

**1. Health that cannot go below zero or above full.**

```
On player hit
  -> Set Health to Clamp (int)  health - 10, 0, max_health
```

which lands as:

```gdscript
health = clampi(health - 10, 0, max_health)
```

Use **Clamp (int)** here rather than plain Clamp: `clampf` returns a decimal, and storing that back into a
whole-number Health either truncates or errors.

**2. A camera that eases behind the player instead of snapping.**

```
Every tick
  -> Set Camera X to Smooth Lerp  camera_x, player_x, 0.15
```

```gdscript
camera_x = lerpf(camera_x, player_x, smoothstep(0.0, 1.0, 0.15))
```

**Lerp** on its own is a straight blend; **Smooth Lerp** eases the weight first, so the follow starts and
ends gently.

**3. A health bar from one expression.**

```
Every tick
  -> Set HealthBar scale.x to Progress Of  health, 0, max_health
```

```gdscript
health_bar.scale.x = clampf(inverse_lerp(0, max_health, health), 0.0, 1.0)
```

**Progress Of** is already clamped, so overheal or negative health cannot push the bar past its ends. For
a text readout use **Percent Of** instead and you get 0 to 100.

**4. Snap a dragged object to a 32-pixel grid.**

```
On drag released
  -> Set Position to Vector2( Snap To Step (mouse_x, 32) , Snap To Step (mouse_y, 32) )
```

```gdscript
position = Vector2(snappedf(mouse_x, 32), snappedf(mouse_y, 32))
```

**5. Aim a turret at the player.**

```
Every tick
  -> Set Rotation to Angle Toward  player.global_position
```

```gdscript
rotation = position.angle_to_point(player.global_position)
```

**Angle Toward** is Node2D-only and reads from this node's own `position`. When you have a raw direction
rather than a target point, use **Angle Of (atan2)** on its x and y instead.

**6. Turn toward that aim gradually rather than instantly.**

```
Every tick
  -> Set Rotation to Rotate Toward (angle)  rotation, target_angle, 0.05
```

```gdscript
rotation = rotate_toward(rotation, target_angle, 0.05)
```

**Rotate Toward (angle)** takes a fixed step; **Lerp Angle** takes a 0-to-1 weight instead. Both take the
shortest path round the circle, which is the part a hand-written subtraction gets wrong.

**7. A pickup that bobs.**

```
Every tick
  -> Set Position Y to base_y + Sin (degrees) ( Game Time * 180 ) * 8
```

```gdscript
position.y = base_y + sin(deg_to_rad((Time.get_ticks_msec() / 1000.0) * 180)) * 8
```

**Sin (degrees)** saves the conversion; **Ping-Pong** is the alternative when you want a linear
back-and-forth rather than a wave.

**8. Cycle a menu selection past both ends.**

```
On ui_down pressed
  -> Set Selected to Wrap (int)  selected + 1, 0, item_count
```

```gdscript
selected = wrapi(selected + 1, 0, item_count)
```

The Max of **Wrap (int)** is exclusive, so `0, item_count` covers exactly the valid indexes and pressing
down on the last item returns to the first.

**9. Turn a health fraction into a shake amount.**

```
Every tick
  -> Set Shake to Remap Range  health, 0, max_health, 12.0, 0.0
```

```gdscript
shake = remap(health, 0, max_health, 12.0, 0.0)
```

Note the output range running backwards: **Remap Range** happily inverts, so full health gives no shake
and no health gives the most.

**10. Ease a fade the way a designer means it.**

```
Every tick
  -> Set Alpha to Ease  fade_progress, 2.0
```

```gdscript
alpha = ease(fade_progress, 2.0)
```

A **Curve** above 1 eases in, below 1 eases out. **Smoothstep** is the fixed S-curve version when you do
not want a knob.

**11. Drain a meter at a fixed rate per frame.**

```
Every tick
  -> Set Stamina to Move Toward  stamina, 0.0, 30.0 * delta
```

```gdscript
stamina = move_toward(stamina, 0.0, 30.0 * delta)
```

**Move Toward** never overshoots, so the meter lands exactly on 0 rather than tipping negative.

**12. Never test a decimal with "equals".**

```
Every tick
  Condition: Is Zero (approx)  velocity.x
    -> play the idle animation
```

```gdscript
if is_zero_approx(velocity.x):
```

Any arithmetic leaves a tiny remainder, so `velocity.x == 0` is a coin flip. **Is Zero (approx)** and
**Is Equal (approx)** are what you actually meant.

**13. A damage roll with variety.**

```
On hit landed
  -> Set Damage to Random Integer  8, 12
  -> Set Crit Multiplier to Choose  1, 1, 1, 2
```

```gdscript
damage = randi_range(8, 12)
crit_multiplier = [1, 1, 1, 2].pick_random()
```

**Choose** takes a comma-separated list, and repeating an entry is how you weight it: three ones and a
two is a one-in-four crit.

**14. A daily challenge everybody plays identically.**

```
On Ready
  -> Set Random Seed  day_number
  -> generate the level
```

```gdscript
seed(int(day_number))
```

**Set Random Seed** and **Seed Random** both pin the global generator; **Randomize Seed** puts it back to
clock-based randomness for a normal run. Do not leave a seed pinned by accident - everything random in
the whole game replays after it.

**15. Generate map content in the editor, before the game runs.**

```
For each tile index
  -> Set Tile to Seeded Pick  ["grass", "sand", "rock"], "world_1", tile_index
```

```gdscript
tile = (["grass", "sand", "rock"] as Array)[absi(hash(str("world_1") + "#" + str(tile_index))) % maxi((["grass", "sand", "rock"] as Array).size(), 1)] if not (["grass", "sand", "rock"] as Array).is_empty() else null
```

The **Procedural** family holds no state, so it works inside an Editor Tool sheet and while filling a
Custom Resource - places where a game-time random generator does not exist. Change nothing and the same
world comes back every time you open the project.

**16. A treasure chance that is decided by the tile, not by the moment.**

```
For each room index
  Condition: Seeded Chance  15.0, "world_1_loot", room_index
    -> place a chest
```

```gdscript
if ((float(absi(hash(str("world_1_loot") + "#" + str(room_index))) % 1000000) / 1000000.0) * 100.0 < 15.0):
```

Because the answer comes from the seed and the index alone, re-walking the same rooms gives the same
chests - no "save the layout" bookkeeping.

**17. A spawner that speeds up as the run goes on.**

```
On run started
  -> Start Ramp Clock

Every Ramped (2.0, -0.3, 0.5) seconds
  -> spawn an enemy
```

**Ramped** starts at 2 seconds, loses 0.3 seconds per minute and never drops below 0.5. **Start Ramp
Clock** marks minute zero on this node - without it, minutes are counted from engine start and the run
begins mid-curve.

**18. Speak distances in tiles.**

```
On enemy tick
  Condition: Is Within Distance  global_position, player.global_position, Tiles(3)
    -> start chasing
```

```gdscript
if global_position.distance_to(player.global_position) <= (3 * float(ProjectSettings.get_setting("eventforge/tile_size", 16.0))):
```

Set `eventforge/tile_size` once in Project Settings and every distance in the game can be written the way
a grid game thinks. (Is Within Distance itself is a comparison verb - see the Comparing Values guide.)

**19. Guard maths on a loaded value.**

```
On save loaded
  Condition: Value Is A Number  save["gold"]
    -> Set Gold to To Integer  save["gold"]
  Else
    -> Set Gold to 0
```

```gdscript
if (typeof(save["gold"]) == TYPE_FLOAT or typeof(save["gold"]) == TYPE_INT):
	gold = int(save["gold"])
else:
	gold = 0
```

**Value Is A Number** asks the question before **To Integer** answers it. Without the guard, text or a
missing key becomes a silent zero.

**20. Catch a broken calculation.**

```
Every tick
  Condition: Is NaN  ratio
    -> Set Ratio to 0.0
    -> log "ratio went NaN"
```

```gdscript
if is_nan(ratio):
```

Dividing zero by zero produces not-a-number, and a NaN spreads silently through everything it touches -
including comparisons, which all read false. **Is NaN** is the only way to see it.

**21. A facing cone for a guard.**

```
Every tick
  Condition: Is Within Angle  Radians To Degrees(rotation), 45.0, Radians To Degrees(angle_to_player)
    -> the guard notices the player
```

```gdscript
if absf(rad_to_deg(angle_difference(deg_to_rad(rad_to_deg(rotation)), deg_to_rad(rad_to_deg(angle_to_player))))) <= 45.0:
```

**Is Within Angle** works in degrees and handles wrap-around, so 350 really is within 20 of 10.
**Is Clockwise From** answers which side of the reference the angle sits on, for a "turn left or right"
decision.

**22. A spawn ring that never drops an enemy in your lap.**

The off-screen spawner in one expression. The inner radius keeps enemies from appearing on top of the
player; the outer one keeps them from appearing so far away they never arrive.

```gdscript
extends Node2D


func _on_spawn_timer() -> void:
	$Enemy.global_position = ($Player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * sqrt(lerpf(500.0 * 500.0, 800.0 * 800.0, randf())))
```

**23. Shotgun spread that does not bunch.**

Repeat is a loop ROW, in the condition lane like every other loop, and the eight pellets are its actions.

```
On Shot Fired
  Loops: Repeat  8  times
    -> Object Pool: Spawn  "pellet"  at  Muzzle.global_position
    -> Bullet: Set Angle Of Motion  Vector Angle ( Random Point In Cone ( Vector2.ZERO, Facing Degrees, 14, 1 ) )
```

**24. Blood splats scattered around a hit.**

Random Point Around takes the NODE, not its position, so the scatter follows whatever it is anchored to
as that thing moves.

```gdscript
extends Node2D


func _on_damaged(amount: int) -> void:
	$Splat.global_position = (global_position + Vector2.RIGHT.rotated(randf() * TAU) * sqrt(lerpf(0.0 * 0.0, 24.0 * 24.0, randf())))
```

**25. Loot scattered across a room.**

```gdscript
extends Node2D


func _on_chest_opened() -> void:
	$Coin.global_position = (Vector2(100, 100) + Vector2(randf() * Vector2(400, 240).x, randf() * Vector2(400, 240).y))
```

**26. Debris flying out of a 3D explosion.**

The naive "three random numbers" version of a 3D direction crowds the corners of a cube, so shrapnel
comes out in eight clumps. This one is even over the whole sphere.

```gdscript
extends Node3D


func _on_exploded() -> void:
	$Chunk.linear_velocity = Vector3.UP.rotated(Vector3.RIGHT, acos(randf_range(-1.0, 1.0))).rotated(Vector3.UP, randf() * TAU) * 12.0
```

**27. Wildlife wandering into the frame.**

Random Point On Screen Edge answers in WORLD coordinates on the border of what the camera can see, so a
bird enters from whichever side happens to be facing the player.

```
Every 4 to 9 seconds
  -> Object Pool: Spawn  "bird"  at  Random Point On Screen Edge
```

**28. Footstep pitch variation.**

One Jitter is the difference between a footstep loop that sounds like a machine and one that sounds like
a person.

```gdscript
extends Node


func _on_step() -> void:
	$Footstep.pitch_scale = (1.0 + 0.08 * randf_range(-1.0, 1.0))
```

**29. A wander target around home.**

```gdscript
extends Node2D


func _on_idle_timer() -> void:
	$MoveTo.move_to_position((global_position + Vector2.RIGHT.rotated(randf() * TAU) * (sqrt(randf()) * 200.0)))
```

**30. Trees scattered over a 3D chunk.**

```gdscript
extends Node3D


func _ready() -> void:
	for index in 40:
		var tree = $TreeScene.duplicate()
		tree.position = (Vector3.ZERO + Vector3(randf_range(-1.0, 1.0) * Vector3(64, 0, 64).x, randf_range(-1.0, 1.0) * Vector3(64, 0, 64).y, randf_range(-1.0, 1.0) * Vector3(64, 0, 64).z) * 0.5)
		add_child(tree)
```

**31. Which cell did the player click?**

```
On Mouse Button Pressed
  -> Variables: Set value  hover_cell,  Cell Of Point ( Mouse Position (world), 64 )
```

**32. A build ghost that snaps to the grid.**

Center Of Cell is the exact partner of Cell Of Point, so the pair round-trips: the cell you read back
from a position always centres on a position in that same cell.

```gdscript
extends Node2D


func _process(delta: float) -> void:
	$BuildGhost.global_position = (Vector2(Vector2i(floori(get_global_mouse_position().x / maxf(64.0, 0.001)), floori(get_global_mouse_position().y / maxf(64.0, 0.001)))) * 64.0 + Vector2(64.0, 64.0) * 0.5)
```

**33. Refusing a build that falls off the board.**

Counting starts at 0,0 in the top-left, so a 20 by 12 board's last cell is 19,11 - the mistake this
condition exists to stop.

```
Math: Is Cell In Bounds  ( hover_cell, Vector2i ( 20, 12 ) )
  Collections: Dictionary does not have key  ( occupied, hover_cell )
    -> Nodes: Show  BuildGhost
```

**34. A tower's range preview.**

For Each Cell In Radius is a real looping condition, so it lands in the loop lane with frame spreading
and round-trip behaving exactly like the built-in For Each. Its items arrive under the name `cell`.

```
Loops: For Each Cell In Radius  ( hover_cell, 2 )
  -> Drawing: Draw Rect  Center Of Cell ( cell, 64 ), 64, 64, Color ( 1, 0.4, 0.2, 0.25 )
```

**35. Flood fill on a puzzle board.**

Neighbours Of Cell is the whole of a flood fill's geometry. Pick four sides for a match-three, eight for
a minesweeper, six for a hex strategy board.

```
Loops: For Each  ( Neighbours Of Cell ( start_cell, 4 sides ) )
  Math: Is Cell In Bounds  ( item, board_size )
    -> Collections: Push Back  item  to  frontier
```

**36. A laser's tile path.**

```
On Fire Laser
  Loops: For Each  ( Cells In Line ( turret_cell, target_cell ) )
    -> Collections: Set Key  scorched,  item,  true
```

**37. Stamping a room into a dungeon.**

```
On Room Placed
  Loops: For Each  ( Cells In Rectangle ( room_corner, room_size ) )
    -> Tilemap: Set Cell  item,  floor_tile
```

**38. Explosion damage that respects distance.**

Falloff At Distance reads 0 past the radius, so it is safe to multiply straight into damage - a body the
query caught at the very edge takes nothing rather than a suspicious sliver.

```
On Exploded
  -> Collisions: Query Bodies In Circle (2D)  into hits,  radius 240
  Loops: For Each  ( hits )
    -> Health: Take Damage  ( 60 * Falloff At Distance ( global_position, item.global_position, 240, Smooth ) )  on item
```

**39. Screen shake off the SAME number as the damage.**

Reading one falloff for the damage, the shake and the sound is what makes an explosion feel like one
event rather than four unrelated ones.

```gdscript
extends Node2D


func _on_exploded() -> void:
	$Juice.shake(0.8 * ([clampf(1.0 - global_position.distance_to($Camera.global_position) / maxf(900.0, 0.001), 0.0, 1.0), clampf(1.0 - global_position.distance_to($Camera.global_position) / maxf(900.0, 0.001), 0.0, 1.0) * clampf(1.0 - global_position.distance_to($Camera.global_position) / maxf(900.0, 0.001), 0.0, 1.0), smoothstep(0.0, 1.0, clampf(1.0 - global_position.distance_to($Camera.global_position) / maxf(900.0, 0.001), 0.0, 1.0))][1]))
```

**40. Barrels and crates flung by a blast.**

Apply Radial Impulse goes on the BODY, so the blast only has to say where it happened.

```
On Blast Caught Me
  -> Movement: Apply Radial Impulse  blast_point,  900,  240
```

**41. A shockwave that parts a crowd.**

Push Group Away From is the mirror of the shipped Pull Group Toward: same walk, same radius guard,
opposite direction and a falloff on the strength.

```
On Dash Started
  -> Movement: Push Group Away From  "enemies",  global_position,  240,  60
```

**42. A guard who notices you faster the closer you are.**

Is Within Cone Of is the cheap pre-check to put in front of an expensive raycast: if the player is not in
the wedge at all, there is nothing to trace.

```
Math: Is Within Cone Of  ( Guard.global_position, Guard Facing, Player.global_position, 70, 600 )
  -> Variables: Add  ( 2 * Strength Toward ( Player, 600 ) )  to  suspicion
```

### Other use cases

**Screen-shake decay.** Feed the shake amount through Move Toward with a per-second step so it always
settles to exactly zero, then multiply a Random offset by it for the actual jitter.

**A stamina bar that flashes when low.** Percent Of gives the readout, Is Between Values gates the flash,
and Ping-Pong on Game Time drives the alpha without a tween or a timer.

**Isometric depth sorting.** Snap To Step on the y position quantises rows, and Positive Modulo keeps a
wrapped depth index positive whatever the sign of the input.

**Procedural name generation for NPCs.** Seeded Pick over a syllable list with the NPC's spawn index as
the Index gives every villager a stable name that survives a reload without being saved anywhere.

**A pity timer on loot.** Ramped raises the drop chance minute by minute up to a hard Limit, and Start
Ramp Clock resets the curve every time something actually drops.

## Tips and common mistakes

- **Random angle plus random radius is a bug, not a shortcut.** It puts half the points inside the inner
  half-radius, which holds a quarter of the area, so scatter visibly clumps at the centre. Every shape
  verb here already does the sqrt (2D) or cube-root (3D) weighting that fixes it.
- **Jitter's amount must be the same KIND of value as the thing it nudges.** A number for a number, a
  Vector2 for a position, a Color for a tint. It also uses one random roll for the whole value, so a
  jittered position moves along a line rather than into a disc - Random Point In Circle is the verb for a
  disc.
- **Cells count from 0,0 in the top-left.** A 20 by 12 board's last cell is 19,11, which is what Is Cell
  In Bounds is checking and the off-by-one it is there to stop.
- **Cell Of Point floors, Snap Point To Grid rounds.** The first answers "which cell is this in" and the
  second "which intersection is nearest", and they disagree by half a cell on purpose.
- **A negative position lands in a negative cell**, not in cell 0. That is what a grid extending left and
  up needs, and it is why `int()` truncation is the wrong tool here.
- **The cell-size slot is just a number.** Type `Tiles(1)` in it to read your project's own
  `eventforge/tile_size` setting instead of repeating 64 in every row.
- **Neighbours Of Cell's hex option is AXIAL**, the six neighbours of an axial hex coordinate. An offset
  hex board (where every other row is shifted) needs its own row-parity handling, which is exactly why
  axial is the coordinate system worth storing.
- **Falloff At Distance is a 0-to-1 multiplier, not a damage number.** Multiply it into the damage, the
  shake, the volume and the knockback - reading ONE falloff for all of them is what makes a blast feel
  like a single event.
- **For a hand-drawn blast profile, feed it into Sample Curve.** Falloff At Distance produces the 0-to-1
  value; the curve shapes it, and a designer draws the shape in the Inspector.
- **Push Group Away From moves positions, not velocities.** It is a shove, not an impulse - for physics
  bodies that should tumble, Apply Radial Impulse on the body is the honest verb.

- **Clamp and Wrap come in two flavours, and picking the wrong one is silent.** `clampf` and `wrapf`
  return decimals. Assigning one to a whole-number variable truncates it or trips the type checker. For
  score, health, ammo and any index, reach for **Clamp (int)** and **Wrap (int)**.
- **Wrap (int)'s Max is exclusive, Clamp (int)'s Max is inclusive.** Cycling a 5-item menu is
  `Wrap (int)(i + 1, 0, 5)`, not `0, 4`. Clamping health to a hundred really is `0, 100`.
- **Radians unless the name says degrees.** Mixing the two is the commonest angle bug here. Angle Toward
  and Angle Of (atan2) hand back radians; Is Within Angle and Is Clockwise From want degrees; Sin/Cos/Tan
  (degrees) take degrees while Sine/Cosine/Tangent take radians.
- **Angle Toward and Distance To are Node2D verbs and read this node's own `position`.** They are not
  general two-point helpers. For two arbitrary points use Distance Between or Direction To from the
  vector vocabulary, or Is Within Distance as a condition.
- **Never compare decimals with `=`.** Use Is Equal (approx) and Is Zero (approx). This is not
  fussiness - after any arithmetic at all, two numbers that "should" be equal usually are not.
- **A seed stays pinned.** Seed Random and Set Random Seed change the whole game's randomness from that
  point on, not just the next roll. Call Randomize Seed when you want ordinary randomness back.
- **The Procedural verbs are not affected by seeding at all.** They hash the Seed text and the Index
  directly, so Randomize Seed does nothing to them. That is the point: they are for content that must be
  identical every time, including in the editor.
- **Seeded Pick returns nothing at all for an empty list.** Guard the list before you use the result, or
  the first thing you read off it errors.
- **Ramped counts minutes from engine start until Start Ramp Clock runs.** A curve tuned for a fresh run
  will already be halfway down if the player spent two minutes in the menus. Call Start Ramp Clock the
  moment the run actually begins.
- **Tiles reads a project setting, so it is zero-cost but global.** `eventforge/tile_size` defaults to
  16. If your game has two tile sizes, Tiles can only speak for one of them.
- **Choose takes a comma-separated list, not an array variable.** It emits `[{values}].pick_random()`, so
  the cell holds `1, 2, 3` and the brackets are added for you. To pick from an array variable you already
  have, use Pick Random from the list vocabulary instead.
- **Value Is A Number keeps a zero.** A loaded `0` is a real number and passes the guard, which is right -
  a score of zero is a value, not a missing one.
