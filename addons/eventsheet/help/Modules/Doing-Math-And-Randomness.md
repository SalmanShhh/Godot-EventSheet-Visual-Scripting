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
