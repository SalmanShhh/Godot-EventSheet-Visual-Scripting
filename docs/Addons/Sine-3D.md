# Sine 3D - Oscillate a 3D Node, One Behavior Per Node

Sine 3D is a Godot EventSheets behavior pack for automatic wobble, bob, and sway in 3D. You attach a `Sine3DBehavior` to a `Node3D` - a floating pickup, a hovering platform, a swaying tree, a spinning coin - and that node starts oscillating on its own. Pick an axis (move along x, y, or z, or turn around the Y axis) and a wave shape (sine, triangle, sawtooth, reverse-sawtooth, or square), and the behavior nudges the host back and forth around wherever it started. It runs straight from the Inspector with no event rows at all, and you can also pause, retune, or restart it live from the sheet. This is a per-node behavior, not a global singleton: every Action and Expression targets the Sine 3D behavior living on the node you drop it on, so there is no target id to pass around. The host must be a `Node3D` (the behavior drives its parent's `position` and `rotation.y`).

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

- **Floating collectibles.** A coin, gem, or heart bobs gently up and down so it reads as pick-me-up loot without a single line of animation.
- **Hovering platforms and lifts.** A slow sine on the Y axis gives a platform a living, floaty hover that never drifts away from its spot.
- **Spinning pickups.** A sawtooth wave on rotation-y ramps the coin around and snaps back each cycle, so it looks like it is spinning in place.
- **Swaying trees and foliage.** A small, slow sine on rotation-y rocks a tree or bush back and forth like a breeze is passing through.
- **Bobbing water props.** Buoys, lily pads, and boats ride an idle up-and-down bob that sells the feel of water.
- **Idle breathing motion.** Give a statue, totem, or resting creature a barely-there Y wobble so the scene never feels frozen.
- **Wobbling display items.** A pedestal trophy or key item rocks on rotation-y to draw the eye to something important.
- **Drones and hovering enemies.** A patrolling drone gets a subtle vertical bob layered on top of whatever else moves it.
- **Signage and markers.** A floating quest marker or arrow bounces on Y so the player always spots it.
- **Jittery hazards.** A square wave on Y snaps a trap or alarm light between two positions for a mechanical, on-off shudder.
- **Desynced crowds of props.** A row of identical torches or lanterns each gets a different phase so they sway out of lockstep instead of moving as one.
- **Side-to-side drift.** A ghost, jellyfish, or cloud slides left and right on the X axis for a lazy, aimless float.

---

## Core concepts

The whole pack is one idea - a repeating wave added to where the node started - plus a handful of knobs. Learn these and you have all of it.

**The behavior swings the node around its starting spot.** On the very first frame it captures the host's current position and Y rotation as the base. From then on, each frame it adds a wave-driven offset on top of that base. The node never wanders off: it always returns through the point where it began, swinging to one side and back to the other.

**Movement picks the axis.** The `movement` knob decides what oscillates: `x`, `y`, or `z` slides the host along that world axis; `rotation-y` turns it around the vertical axis instead of moving it. One behavior drives one axis - stack two behaviors on a node if you want a bob and a spin at once.

**Magnitude is how far it swings.** The wave runs from -1 to +1, and `magnitude` scales it, so the host swings `magnitude` to each side of the base. The unit depends on the axis: for `x`, `y`, and `z` it is world units (a magnitude of 2 lifts the node 2 units up and 2 down); for `rotation-y` it is degrees (a magnitude of 15 rocks it 15 degrees each way).

**Period is how long one cycle takes.** The `period` knob is the number of seconds for one full trip - out, back, and around to the start. A bigger period is a slower, lazier motion; a smaller period is a quick flutter. The default of 4 is a calm, unhurried swing.

**Phase shifts where in the cycle it starts.** `phase_degrees` offsets the wave's starting point (360 degrees is one full cycle). It does not change the motion itself, only where in the loop the node is at time zero. Give a row of identical props different phases and they stop moving in lockstep.

**Wave picks the shape of the motion.** The `wave` knob chooses how the swing feels between its extremes:

- `sine` - a smooth, natural ease in and out at each end. The default, and the right pick for hover, bob, and sway.
- `triangle` - a constant-speed ramp up then down, with a sharp turn at each end. More mechanical than sine.
- `sawtooth` - ramps steadily to one extreme, then snaps back and repeats. On `rotation-y` this reads as a one-way continuous spin.
- `reverse-sawtooth` - the same ramp-and-snap, running the other direction.
- `square` - jumps straight between the two extremes with nothing in between - an instant, on-off shudder.

**Active is the master on/off.** With `active` on (the default) the behavior runs; turn it off and the node freezes exactly where it was, mid-swing. Turning it back on resumes from that same point in the cycle - it does not restart.

**Reset restarts and re-centers.** **Reset Sine 3D** sets the internal clock back to zero and re-captures the base from the host's current position and rotation. Use it after you teleport or reposition the node so the swing is centered on the new spot instead of the old one.

---

## Setup

**1. Attach the behavior.** Add a `Sine3DBehavior` as a child of the `Node3D` you want to animate (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in as a child). The behavior drives its parent, so the parent must be a `Node3D` - a `MeshInstance3D`, `CharacterBody3D`, `Area3D`, or any 3D node. One behavior per axis of motion.

**2. Set the Inspector knobs.** Select the behavior node and tune the feel:

| Property | Type | Default | What it does |
|---|---|---|---|
| `active` | bool | `true` | Master on/off. When off, the host is left exactly where it was. |
| `magnitude` | float | `2.0` | How far it swings from the base - world units for x/y/z, degrees for rotation-y. |
| `movement` | String (enum) | `y` | Which axis oscillates: `x`, `y`, `z`, or `rotation-y`. |
| `period` | float | `4.0` | Seconds for one full cycle. Bigger is slower. |
| `phase_degrees` | float | `0.0` | Phase offset in degrees - shifts where in the cycle it starts. |
| `wave` | String (enum) | `sine` | Wave shape: `sine`, `triangle`, `sawtooth`, `reverse-sawtooth`, or `square`. |

**3. Run it - and optionally react in the sheet.** With the knobs set, the node oscillates the moment the scene runs; many props need no event rows at all. When you do want to change it live, target the behavior in some event. Here is a complete first setup - a collectible that bobs on its own and stops the moment it is picked up:

```
On Ready
  -> Coin | Sine 3D: Set Magnitude  0.5
  -> Coin | Sine 3D: Set Period  2

On Coin collected
  -> Coin | Sine 3D: Set Sine 3D Active  false
```

The `On Ready` rows just override the Inspector defaults for a shorter, quicker bob; you could set those in the Inspector instead and skip them entirely. Set Sine 3D Active false freezes the coin the instant it is grabbed.

---

## ACE reference

All ACEs live in the **Sine 3D** category and target the `Sine3DBehavior` on the node they are placed on. Each generated action and expression carries an "On node" target that defaults to the behavior on that node, so you normally leave it as-is - there is no separate target id to manage.

Three actions come from the behavior's own methods (**Set Sine 3D Active**, **Set Phase**, **Reset Sine 3D**). Everything else - the **Set** / **Add To** / **Subtract From** actions and the read-back expressions - is generated automatically from the six exported Inspector properties, so you can read and retune every knob from the sheet at runtime.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Set Sine 3D Active | `is_active` (bool) | Pauses (`false`) or resumes (`true`) the oscillation. |
| Set Phase | `degrees` (float) | Sets the phase offset in degrees. |
| Reset Sine 3D | (none) | Restarts the wave from time zero and re-captures the base position and rotation. |
| Set Active | `value` (bool) | Turns the oscillation on or off - the same master switch as Set Sine 3D Active. |
| Set Movement | `value` (String) | Sets the axis: `x`, `y`, `z`, or `rotation-y`. |
| Set Magnitude | `value` (float) | Sets the swing amount (world units for x/y/z, degrees for rotation-y). |
| Add To Magnitude | `amount` (float) | Increases the swing amount. |
| Subtract From Magnitude | `amount` (float) | Decreases the swing amount. |
| Set Period | `value` (float) | Sets the seconds per full cycle. |
| Add To Period | `amount` (float) | Lengthens the cycle (slower motion). |
| Subtract From Period | `amount` (float) | Shortens the cycle (faster motion). |
| Set Phase Degrees | `value` (float) | Sets the phase offset in degrees - the same knob as Set Phase. |
| Add To Phase Degrees | `amount` (float) | Adds to the phase offset. |
| Subtract From Phase Degrees | `amount` (float) | Subtracts from the phase offset. |
| Set Wave | `value` (String) | Sets the wave shape: `sine`, `triangle`, `sawtooth`, `reverse-sawtooth`, or `square`. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| (none) | - | Sine 3D ships no dedicated conditions. Check its state by comparing the Active, Movement, Magnitude, Period, Phase Degrees, or Wave expressions in an "Expression is true" condition. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| Active | (none) | bool | Whether the oscillation is currently on. |
| Movement | (none) | String | The current axis (`x`, `y`, `z`, or `rotation-y`). |
| Magnitude | (none) | float | The current swing amount. |
| Period | (none) | float | The current seconds per cycle. |
| Phase Degrees | (none) | float | The current phase offset in degrees. |
| Wave | (none) | String | The current wave shape. |

### Triggers

| Trigger | Fires when |
|---|---|
| (none) | - | Sine 3D fires no triggers. It runs continuously in the background; react to gameplay with your own events and reach into the behavior from there. |

### Inspector properties

| Property | Type | Default | Range |
|---|---|---|---|
| `active` | bool | `true` | on / off |
| `magnitude` | float | `2.0` | any (world units for x/y/z, degrees for rotation-y) |
| `movement` | String | `y` | `x`, `y`, `z`, or `rotation-y` |
| `period` | float | `4.0` | any (seconds; larger is slower) |
| `phase_degrees` | float | `0.0` | any (degrees; 360 = one full cycle) |
| `wave` | String | `sine` | `sine`, `triangle`, `sawtooth`, `reverse-sawtooth`, or `square` |

---

## Use cases

Each example targets the `Sine3DBehavior` on the named node. Most props run entirely from the Inspector; reach into the sheet only when you want to change the motion live.

### 1. Floating collectible that bobs

The classic pick-me-up bob. A short magnitude and a quick period give a light, lively float on the default Y axis.

```
On Ready
  -> Coin | Sine 3D: Set Magnitude  0.4
  -> Coin | Sine 3D: Set Period  1.5
```

You could set `magnitude` and `period` in the Inspector instead and drop these rows entirely - the coin would bob the moment the scene runs.

### 2. Continuously spinning coin

A sawtooth wave on rotation-y ramps the coin around and snaps back each cycle, which reads as a smooth one-way spin. A magnitude of 180 sweeps a full turn.

```
On Ready
  -> Coin | Sine 3D: Set Movement  "rotation-y"
  -> Coin | Sine 3D: Set Wave  "sawtooth"
  -> Coin | Sine 3D: Set Magnitude  180
  -> Coin | Sine 3D: Set Period  1
```

Shorten the period for a faster spin; swap to `reverse-sawtooth` to spin the other way.

### 3. Hovering platform

A slow, smooth sine on Y gives a platform a floaty hover that always returns to its resting height.

```
On Ready
  -> Platform | Sine 3D: Set Magnitude  0.6
  -> Platform | Sine 3D: Set Period  3
```

The default `sine` wave eases in and out at the top and bottom, so the hover feels weighty rather than mechanical.

### 4. Swaying tree in the wind

A small, slow rock on rotation-y makes a tree or bush look like a breeze is passing through it.

```
On Ready
  -> Tree | Sine 3D: Set Movement  "rotation-y"
  -> Tree | Sine 3D: Set Magnitude  4
  -> Tree | Sine 3D: Set Period  5
```

Keep the magnitude tiny - 4 degrees is a gentle sway; larger values start to look like the whole trunk is spinning.

### 5. Bobbing buoy on water

A buoy or lily pad rides a lazy up-and-down bob that sells the feel of water without any physics.

```
On Ready
  -> Buoy | Sine 3D: Set Magnitude  0.3
  -> Buoy | Sine 3D: Set Period  2.5
```

### 6. Stop bobbing when collected

Freeze the motion the instant a pickup is grabbed, so it snaps to a stop before it vanishes.

```
On Coin collected
  -> Coin | Sine 3D: Set Sine 3D Active  false
  -> Coin: queue_free
```

Set Sine 3D Active false leaves the coin exactly where it was mid-swing; turning it back on later would resume from that same point.

### 7. Desync a row of identical props

Three torches with the same bob would move as one. Give each a different phase and they sway out of step.

```
On Ready
  -> TorchA | Sine 3D: Set Phase  0
  -> TorchB | Sine 3D: Set Phase  120
  -> TorchC | Sine 3D: Set Phase  240
```

Phase does not change the motion itself, only where in the cycle each torch starts, so the row ripples instead of pulsing together.

### 8. Speed up the bob when the player is near

An idle prop bobs slowly, then quickens as the player approaches, using Subtract From Period to shorten the cycle.

```
On Player entered ShrineZone
  -> Shrine | Sine 3D: Subtract From Period  1.5

On Player exited ShrineZone
  -> Shrine | Sine 3D: Add To Period  1.5
```

Because these nudge the same `period` knob, pair each Subtract with a matching Add so the calm speed comes back cleanly.

### 9. Grow the sway during a storm

A hanging sign rocks harder as a storm builds, then settles once it passes, by adding to and subtracting from the magnitude.

```
On Storm started
  -> Sign | Sine 3D: Add To Magnitude  10

On Storm ended
  -> Sign | Sine 3D: Subtract From Magnitude  10
```

### 10. Switch the feel from smooth to mechanical

An object hovers naturally until it powers on, then flips to a stiff, constant-speed triangle motion.

```
On Machine powered on
  -> Machine | Sine 3D: Set Wave  "triangle"

On Machine powered off
  -> Machine | Sine 3D: Set Wave  "sine"
```

Set Wave changes the shape live without touching the magnitude or period, so only the character of the motion changes.

### 11. Jittery hazard using the square wave

A trap plate or alarm light snaps between two positions with no in-between, for a mechanical on-off shudder.

```
On Trap armed
  -> Trap | Sine 3D: Set Wave  "square"
  -> Trap | Sine 3D: Set Magnitude  0.1
  -> Trap | Sine 3D: Set Period  0.3
```

A short period and small magnitude make it read as a fast jitter rather than a slow slide.

### 12. Wobbling display pedestal item

A key item on a pedestal rocks on rotation-y with a triangle wave to catch the eye.

```
On Ready
  -> RewardItem | Sine 3D: Set Movement  "rotation-y"
  -> RewardItem | Sine 3D: Set Wave  "triangle"
  -> RewardItem | Sine 3D: Set Magnitude  20
  -> RewardItem | Sine 3D: Set Period  2
```

### 13. Re-center after teleport

When a floating enemy blinks to a new spot, Reset Sine 3D re-captures the base so the bob is centered on the new position, not the old one.

```
On Ghost teleported
  -> Ghost: set global_position to WarpPoint.global_position
  -> Ghost | Sine 3D: Reset Sine 3D
```

Without the reset, the ghost would keep swinging around the point where it first spawned.

### 14. Change axis at runtime

A drifting spirit slides side to side normally, then switches to a vertical rise when it becomes alert.

```
On Ready
  -> Spirit | Sine 3D: Set Movement  "x"
  -> Spirit | Sine 3D: Set Magnitude  1

On Spirit alerted
  -> Spirit | Sine 3D: Set Movement  "y"
  -> Spirit | Sine 3D: Set Magnitude  2
```

### 15. Gentle side-to-side drift

A cloud or jellyfish slides lazily left and right on the X axis with a long, slow period.

```
On Ready
  -> Cloud | Sine 3D: Set Movement  "x"
  -> Cloud | Sine 3D: Set Magnitude  3
  -> Cloud | Sine 3D: Set Period  8
```

### Other use cases

**Quest marker over an NPC.** A floating exclamation mark above a quest giver bobs on the Y axis with a small magnitude and short period, so the player's eye finds it from across the map.

**Sleeping creature breathing.** A tiny, slow Y swing on a resting boss or campsite companion reads as chest-rise breathing, keeping a quiet scene alive with zero animation work.

**Carousel horses.** Each horse on a fairground ride gets the same Y bob with a different phase, so the row rises and falls in a rolling sequence instead of pumping in unison.

**Factory pistons.** A line of pistons uses the triangle wave on Y for constant-speed up-down strokes, phase-offset down the row, selling a working machine hall with one behavior per piston.

**Radar dish sweep.** A sawtooth wave on rotation-y turns a radar dish or scanner beacon steadily around and around, a continuous surveillance spin with nothing to script.

---

## Tips and common mistakes

- **The host must be a Node3D.** The behavior drives its parent's `position` and `rotation.y`, so attach it under a 3D node (MeshInstance3D, CharacterBody3D, Area3D, and so on). Under a non-Node3D parent it warns and does nothing.
- **It runs on its own - no rows required.** As soon as the scene runs, the node oscillates from the Inspector values. The actions are only for changing the motion live; a prop that never changes needs zero event rows.
- **Magnitude means different units per axis.** For `x`, `y`, and `z` it is world units; for `rotation-y` it is degrees. A magnitude of 2 lifts a node 2 units on `y`, but rocks it only 2 degrees on `rotation-y` - bump it up (15 to 20) for a visible sway, or all the way to 180 for a full turn.
- **It swings around wherever the node starts.** The base is captured on the first frame, so the starting spot is the center of the motion. If you move the node in code and want the swing centered on the new spot, call Reset Sine 3D to re-capture.
- **rotation-y oscillates, it does not spin - unless you pick the right wave.** With `sine`, `triangle`, or `square`, rotation-y rocks back and forth. For a one-direction continuous spin, use `sawtooth` (or `reverse-sawtooth`) so each cycle ramps around and snaps back.
- **Period is the whole cycle, not the half.** A period of 4 means 4 seconds for the full out-and-back trip. If a motion feels twice as slow or fast as you expected, remember the number covers the complete loop, not one leg of it.
- **Set Phase and Set Phase Degrees are the same knob.** Both write `phase_degrees`; pick whichever reads better in your sheet. Phase is the tool for desyncing identical props so a row of them does not move in lockstep.
- **Set Active and Set Sine 3D Active do the same thing.** Both toggle the master on/off. When you turn the motion off, the host is left exactly where it was, mid-swing, not snapped back to the base.
- **Turning it off does not reset it.** The internal clock pauses while inactive, so resuming continues from the same point in the cycle. If you want it to restart cleanly from the base, call Reset Sine 3D instead of (or alongside) turning it back on.
- **Stack behaviors for combined motion.** One behavior drives one axis. To bob and spin at the same time, add two `Sine3DBehavior` children - one on `y`, one on `rotation-y` - each with its own magnitude, period, and wave.
