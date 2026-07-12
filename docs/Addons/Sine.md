# Sine - Wave-Driven Motion on Any Node2D

Sine is a Godot EventSheets behavior pack that makes a node oscillate. You attach a `SineBehavior` to a **Node2D** node, and that node starts riding a wave: bobbing up and down, pulsing bigger and smaller, swaying its angle, fading its opacity, or sliding back and forth. You pick one thing for the wave to drive with the `movement` knob, set how far it swings (`magnitude`), how long one full cycle takes (`period`), and what the wave looks like (`wave` - a smooth sine, a constant-speed triangle, a ramp, or a hard on/off square). Every Action and Expression targets the `SineBehavior` living on the node you drop it on. There is no timeline to author and no animation track to keyframe: you set a handful of values and the node moves forever, on its own, every frame. It is the fastest way to add the small, endless motion that makes a scene feel alive.

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

- **Floating pickups and collectibles.** A coin, gem, or heart that bobs gently up and down reads as "grab me" without a single animation frame. One behavior, `movement` set to vertical, and it hovers forever.
- **Pulsing UI.** A start button or "press any key" prompt that breathes bigger and smaller draws the eye. Set `movement` to size and it pulses on a loop with zero tweening.
- **Blinking hazards and warning lights.** A square wave on opacity gives a hard on/off blink - an alarm light, a damage flash zone, a "danger" sign that flips fully on and fully off.
- **Idle sway.** Trees, banners, foliage, hanging signs, and lanterns that rock a few degrees back and forth. A small `magnitude` on the angle mode makes a static sprite feel like it is in a breeze.
- **Patrolling platforms and moving hazards.** A triangle wave on horizontal or vertical gives a constant-speed back-and-forth platform or sawblade that never eases - predictable to time a jump against.
- **Hovering enemies and drones.** Give a flyer a vertical bob, and stagger a whole squad by setting each one's phase so the group ripples instead of moving in lockstep.
- **Breathing idle on logos and portraits.** A slow, subtle size wave on a title logo, a character portrait, or a menu panel keeps a still screen from feeling frozen.
- **See-saws and counterweights.** Two nodes on the same vertical wave, one with its phase pushed half a cycle, counter-move like a balance beam.
- **Ship and vehicle idle.** The forwards-backwards mode moves a node along the direction it faces, so a hovering ship or a boat drifts fore-and-aft on its own heading.
- **A general-purpose oscillator.** The value-only mode computes the wave but touches nothing - you read the raw value yourself to drive a light's energy, a shader value, an audio pitch, or anything else that wants a smooth loop.
- **HUD and screen-space juice.** Wobble a health icon, a combo counter, or a low-ammo warning without opening an animation editor.
- **Rhythmic telegraphs.** A boss part or a trap that pulses on a fixed beat: set the `period` to match your music or your attack cadence and it stays in time.

---

## Core concepts

The mental model is small. Learn these ideas and the rest of the pack is just knobs.

**The host is a Node2D, and the behavior drives one of its properties.** The node you attach `SineBehavior` to is the thing that moves. Every frame the behavior computes a wave value and writes it into exactly one property of that node - which property is chosen by `movement`. It never fights the rest of your game; it just nudges that one value.

**`movement` picks what the wave drives.** This is the most important choice. The options are:

- `horizontal` - slides the node left and right (adds to its x position, in pixels).
- `vertical` - bobs the node up and down (adds to its y position, in pixels).
- `forwards-backwards` - slides the node along the direction it faces (its rotation), in pixels. Good for a node that idles fore-and-aft on its own heading.
- `size` - pulses the node's scale. `magnitude` is read as a percent, so 8 swings the scale by about 8 percent, 100 swings it from zero to double.
- `angle` - rocks the node's rotation. `magnitude` is read as degrees, so 6 sways it plus or minus 6 degrees.
- `opacity` - fades the node's transparency. `magnitude` is read as percent points of alpha, so 50 swings the opacity by about half, 100 blinks it fully on and off (the result is clamped to a valid 0-to-1 range).
- `value-only` - computes the wave but drives nothing. You read the raw value yourself and do whatever you like with it.

**The wave swings around a captured base.** On its first frame the behavior remembers the node's current position, scale, angle, and opacity - that is the base, the center the wave oscillates around. A `magnitude` of 30 on vertical means the node rides 30 pixels above and below wherever it started. This is why you place the node where you want its resting spot and let the wave do the rest.

**`magnitude`, `period`, `phase`, and `wave` are the four dials.** `magnitude` is how far it swings, `period` is how many seconds one full cycle takes (a smaller period is a faster wobble), `phase_degrees` shifts where in the cycle the node starts (360 is a full cycle, 180 is halfway), and `wave` is the shape:

- `sine` - a smooth wave that eases at each end. The natural, organic default.
- `triangle` - a straight ramp up and a straight ramp down, so the node moves at constant speed and only turns around at the ends. Best for platforms you time jumps against.
- `sawtooth` - ramps up, then snaps back to the start. A repeating one-way sweep.
- `reverse-sawtooth` - ramps down, then snaps back up. The sawtooth going the other way.
- `square` - jumps straight to one extreme, holds, then jumps to the other. A hard on/off, perfect for a blink.

**Move the node? Re-capture the base.** The base is grabbed once, at the start. If your game later teleports the host to a new spot, the wave keeps swinging around the old center. Call **Update Initial State** after you move the host to re-center the wave on the node's new position (and current scale, angle, and opacity).

**`active` pauses and resumes; Reset Sine restarts.** Setting the behavior inactive freezes the node right where it is; setting it active again resumes from there. **Reset Sine** zeroes the wave's clock and re-captures the base, so the node restarts cleanly from the current state - handy on spawn or respawn.

**value-only mode and the raw wave value.** In value-only mode the behavior does all the wave math but writes to nothing. It stores the current wave output (a number that swings between -1 and 1) in a variable named `wave_value` on the behavior node. You read that variable directly - it is not a picker expression - to drive anything you want: `$Node/Sine.wave_value`. Multiply it by your own amount and feed it into a light, a shader, a pitch, or a custom property.

---

## Setup

**1. Attach the behavior.** Add a `SineBehavior` as a child of the Node2D you want to move (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node onto it). The behavior finds its parent Node2D as the host on ready and starts driving it. One behavior per node, and one node moves per behavior.

**2. Set the Inspector knobs (optional).** Select the behavior node and tune `movement`, `magnitude`, `period`, `phase_degrees`, and `wave`. The defaults (horizontal, magnitude 50, period 4, sine) already produce a visible slide, so with the behavior attached the node moves the moment you press play - you can author zero event rows and still get motion.

**2b. Preview it without pressing play.** Select the host node in the Scene dock and run
**Tools > Preview Behaviors on Selected Node** (also in the Command Palette). The node starts
oscillating right in the editor viewport, and every knob you tweak in the Inspector reshapes the
motion live - dial in the exact bob, sway, or pulse by eye. Run the command again (or select
another node) and the node snaps back exactly where it was; nothing about the scene is changed.

**3. Retune from the sheet if you like.** If you would rather set it up in events (or change it at runtime), here is a complete first mover - a coin that bobs up and down:

```
On Ready
  -> Coin | Sine: Set Movement  "vertical"
  -> Coin | Sine: Set Magnitude  10
  -> Coin | Sine: Set Period  1.2
```

The behavior captures the coin's starting position on its first frame, then rides 10 pixels above and below it, completing a full up-down cycle every 1.2 seconds. Change `movement` to size and it pulses instead; change `wave` to square and it snaps instead of gliding. Everything else in the pack is a variation on those three lines.

---

## ACE reference

All ACEs live in the **Sine** category and target the `SineBehavior` on the node they are placed on. There is no id parameter anywhere - the node is the mover. The six Set / Add To / Subtract From / read pairs (Movement, Wave, Period, Magnitude, Phase Degrees, Active) are generated automatically from the behavior's exported knobs, so every Inspector value is also readable and settable live from the sheet.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Set Sine Active | `is_active` (bool) | Pauses or resumes the oscillation. Inactive freezes the node where it is; active resumes from there. |
| Update Initial State | (none) | Re-captures the host's current position, scale, angle, and opacity as the wave's base. Call it after you move the host so the wave re-centers on the new spot. |
| Set Phase | `degrees` (float) | Sets the phase offset in degrees (360 is a full cycle, 180 is halfway). Shifts where in the cycle the node starts. |
| Reset Sine | (none) | Restarts the wave from the current state: zeroes the wave clock and re-captures the base. |
| Set Movement | `value` (String: `horizontal` / `vertical` / `forwards-backwards` / `size` / `angle` / `opacity` / `value-only`) | Chooses which property the wave drives. |
| Set Wave | `value` (String: `sine` / `triangle` / `sawtooth` / `reverse-sawtooth` / `square`) | Chooses the wave shape. |
| Set Period | `value` (float) | Sets the seconds for one full cycle (smaller is faster). |
| Add To Period | `amount` (float) | Adds to the current period (slows the wave down). |
| Subtract From Period | `amount` (float) | Subtracts from the current period (speeds the wave up). |
| Set Magnitude | `value` (float) | Sets how far the wave swings (pixels for the position modes, percent for size and opacity, degrees for angle). |
| Add To Magnitude | `amount` (float) | Grows the swing by an amount. |
| Subtract From Magnitude | `amount` (float) | Shrinks the swing by an amount. |
| Set Phase Degrees | `value` (float) | Sets the phase offset in degrees (the same value as Set Phase). |
| Add To Phase Degrees | `amount` (float) | Adds to the phase offset. |
| Subtract From Phase Degrees | `amount` (float) | Subtracts from the phase offset. |
| Set Active | `value` (bool) | Sets whether the oscillation runs (the same value as Set Sine Active). |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| (none) | - | This pack ships no dedicated conditions. To branch on whether the wave is running, use the **Active** expression in an expression condition (`Node \| Sine: Active is true`). |

### Expressions

| Expression | Returns | Description |
|---|---|---|
| Movement | String | The current movement mode (`horizontal`, `vertical`, `size`, and so on). |
| Wave | String | The current wave shape (`sine`, `triangle`, `square`, and so on). |
| Period | float | The current cycle length, in seconds. |
| Magnitude | float | The current swing amount. |
| Phase Degrees | float | The current phase offset, in degrees. |
| Active | bool | Whether the oscillation is running. |

The live wave output itself is not a picker expression. Read it straight off the behavior node's `wave_value` variable (`$Node/Sine.wave_value`); it swings between -1 and 1 every cycle. This is the value you use in value-only mode.

### Triggers

| Trigger | Fires when |
|---|---|
| (none) | This pack ships no triggers. The wave runs continuously on its own; drive your reactions off your existing events (On Ready, timers, input, collisions) or off the **Active** and other expressions. |

### Inspector properties

| Property | Type | Default | What it does |
|---|---|---|---|
| `active` | bool | `true` | Whether the oscillation runs. Turn it off to freeze the node in place. |
| `magnitude` | float | `50.0` | How far the wave swings: pixels for horizontal / vertical / forwards-backwards, percent for size and opacity, degrees for angle. |
| `movement` | String | `horizontal` | Which property the wave drives: `horizontal`, `vertical`, `forwards-backwards`, `size`, `angle`, `opacity`, or `value-only`. |
| `period` | float | `4.0` | Seconds for one full wave cycle. Smaller is a faster wobble. |
| `phase_degrees` | float | `0.0` | Where in the cycle the node starts, in degrees (360 is a full cycle, 180 is halfway). |
| `wave` | String | `sine` | The wave shape: `sine`, `triangle`, `sawtooth`, `reverse-sawtooth`, or `square`. |

---

## Use cases

Each example targets the `SineBehavior` on the named node. Because the wave runs on its own, most rows just configure it once in `On Ready` and then change it only when the game state changes.

### 1. A floating collectible

A coin that bobs so it reads as pickup-able. Set the vertical mode, a small swing, and a gentle period.

```
On Ready
  -> Coin | Sine: Set Movement  "vertical"
  -> Coin | Sine: Set Magnitude  12
  -> Coin | Sine: Set Period  1.5
```

The coin rides 12 pixels above and below wherever you placed it, one full bob every 1.5 seconds.

### 2. A pulsing menu button

A start button that breathes bigger and smaller pulls the eye. The size mode reads `magnitude` as a percent.

```
On Ready
  -> StartButton | Sine: Set Movement  "size"
  -> StartButton | Sine: Set Magnitude  8
  -> StartButton | Sine: Set Period  0.9
```

The button swells about 8 percent and shrinks back, a soft pulse under a second long.

### 3. A blinking warning light

A square wave on opacity gives a hard on/off blink, not a fade. A `magnitude` of 100 swings the alpha fully.

```
On Ready
  -> Alarm | Sine: Set Movement  "opacity"
  -> Alarm | Sine: Set Wave  "square"
  -> Alarm | Sine: Set Magnitude  100
  -> Alarm | Sine: Set Period  0.5
```

The light snaps fully on, holds, snaps off, twice a second. Swap the wave to sine for a smooth throb instead.

### 4. A swaying tree

A few degrees of angle sway makes a static sprite feel like it is in the wind. Keep the magnitude small and the period slow.

```
On Ready
  -> Tree | Sine: Set Movement  "angle"
  -> Tree | Sine: Set Magnitude  5
  -> Tree | Sine: Set Period  3
```

The tree rocks plus and minus 5 degrees over a lazy three-second cycle.

### 5. A constant-speed patrol platform

A triangle wave moves at a steady speed and only turns around at the ends, so a platform is easy to time a jump against. Horizontal mode with a wide magnitude.

```
On Ready
  -> Platform | Sine: Set Movement  "horizontal"
  -> Platform | Sine: Set Wave  "triangle"
  -> Platform | Sine: Set Magnitude  120
  -> Platform | Sine: Set Period  4
```

The platform slides 120 pixels each way at a constant pace, four seconds per round trip.

### 6. A rippling squad out of phase

Give a whole group the same vertical bob, but push each one's phase so they ripple instead of moving as one block. Set each drone's phase from its index.

```
On Ready
  -> Drone | Sine: Set Movement  "vertical"
  -> Drone | Sine: Set Magnitude  16
  -> Drone | Sine: Set Phase  Drone.squad_index * 45
```

Every drone is 45 degrees of the cycle behind the last, so a line of them rolls like a wave.

### 7. A see-saw pair

Two nodes on the same vertical wave, one shoved half a cycle, counter-move like a balance beam. Set the second one's phase to 180.

```
On Ready
  -> SeesawLeft | Sine: Set Movement  "vertical"
  -> SeesawLeft | Sine: Set Magnitude  20
  -> SeesawRight | Sine: Set Movement  "vertical"
  -> SeesawRight | Sine: Set Magnitude  20
  -> SeesawRight | Sine: Set Phase  180
```

When the left side rises, the right side falls, because they are exactly opposite in the cycle.

### 8. Re-center the wave after moving the host

The base is captured once. If you teleport the host, the wave keeps swinging around the old spot until you re-capture. Call Update Initial State right after the move.

```
On Enemy Teleported
  -> Enemy: move to the new arena position
  -> Enemy | Sine: Update Initial State
```

Now the enemy's hover re-centers on where it actually is, not where it spawned.

### 9. A charge-up that shakes harder over time

Grow the swing while a weapon charges by adding to the magnitude on a timer, then snap it back to zero when it fires.

```
Every 0.1 seconds
  Condition: Cannon  is charging
    -> Cannon | Sine: Set Movement  "horizontal"
    -> Cannon | Sine: Add To Magnitude  0.6

On Fire
  -> Cannon | Sine: Set Magnitude  0
```

The barrel jitters wider and wider as the charge builds, then goes still the instant it shoots.

### 10. Speed the wobble up when danger rises

A beacon that idles calmly, then throbs fast when an alarm trips. Set a short period and a bigger swing on the stimulus.

```
On Ready
  -> Beacon | Sine: Set Movement  "size"
  -> Beacon | Sine: Set Period  2.5

On Alarm Raised
  -> Beacon | Sine: Set Period  0.4
  -> Beacon | Sine: Set Magnitude  20
```

A short period is a fast pulse, so the beacon reads calm at rest and frantic under alarm.

### 11. A ship idling along its heading

The forwards-backwards mode moves the node along the way it faces, so a hovering ship drifts fore-and-aft on its own rotation rather than along the screen axes.

```
On Ready
  -> Ship | Sine: Set Movement  "forwards-backwards"
  -> Ship | Sine: Set Magnitude  14
  -> Ship | Sine: Set Period  2
```

Rotate the ship and the drift follows its nose, because the mode reads the host's angle.

### 12. A general oscillator in value-only mode

Value-only computes the wave but drives nothing, so you can steer a custom value with it. Read the behavior's `wave_value` (which swings between -1 and 1) and feed it into a light's energy every frame.

```
On Ready
  -> Lamp | Sine: Set Movement  "value-only"
  -> Lamp | Sine: Set Period  2

Every tick
  -> set Lamp.energy to 1.0 + $Lamp/Sine.wave_value * 0.3
```

The lamp's brightness now breathes between 0.7 and 1.3 on a two-second loop, entirely under your control.

### 13. Restart the wave cleanly on spawn

Reset Sine zeroes the wave clock and re-captures the base, so a pooled or respawned enemy starts its motion fresh from where it appears rather than mid-swing.

```
On Enemy Spawned
  -> Enemy: place at the spawn point
  -> Enemy | Sine: Reset Sine
```

Every enemy begins its hover at the same point in the cycle, from its own fresh center.

### 14. Freeze the motion while a menu is open

Pause the whole scene's idle wobble with Set Sine Active false, then resume it when play continues. The node holds wherever it was when frozen.

```
On Pause Menu Opened
  -> Banner | Sine: Set Sine Active  false

On Pause Menu Closed
  -> Banner | Sine: Set Sine Active  true
```

The banner stops mid-sway on pause and picks up exactly where it left off on resume.

### 15. Wind the motion down before freezing it

Cutting a sway off with Set Sine Active mid-swing can look abrupt. Shrink the swing to nothing first, then freeze, for a graceful stop.

```
Every 0.1 seconds
  Condition: Banner is powering down
    -> Banner | Sine: Subtract From Magnitude  2
  Condition: [Expression] Banner | Sine  Magnitude  <=  0
    -> Banner | Sine: Set Sine Active  false
```

Restore the swing with Set Magnitude when the banner powers back up, and Set Sine Active true resumes right where it froze.

### Other use cases

**Countdown urgency blink.** Pair with the Timer pack: when the round clock enters its final seconds, Set Period to something short so the warning lamp's opacity wave flips from a calm throb to a frantic blink.

**Low-health heartbeat.** Pair with the Health pack: pulse the HP bar with a size wave and Subtract From Period a little each time health drops, so the bar visibly races as danger grows.

**Phasing ghost.** A slow wave on opacity fades a spectral enemy in and out of visibility on a loop, and Set Sine Active false locks it solid the moment it is angered.

**Fishing bobber.** Give the float a vertical bob and call Update Initial State the instant the cast lands, so the wave re-centers on the splash point instead of the rod.

**Debris field.** Give every piece of floating wreckage the same vertical wave with a different Set Phase value so the water's surface rolls instead of lifting in one rigid sheet.

---

## Tips and common mistakes

- **The host must be a Node2D.** The behavior finds its parent as the host and reads and writes that node's position, scale, rotation, and opacity. On a plain Node or a Control it has nothing to move and warns instead. If nothing wobbles, check the parent's type first.
- **Place the node at its resting spot.** The wave swings around wherever the node starts, captured on the first frame. Position the node where you want the middle of the motion to be, not one of the extremes; the behavior handles the rest.
- **Move the host, then Update Initial State.** The base is grabbed once. If you teleport or reparent the node after it starts, the wave keeps oscillating around the old center. Call Update Initial State right after the move so it re-centers.
- **Know what `magnitude` means in each mode.** It is pixels for horizontal, vertical, and forwards-backwards; a percent for size and opacity; and degrees for angle. A magnitude of 50 is a big pixel slide but only a mild half-percent-ish nudge is far too small - so retune the number when you change the mode.
- **Keep `period` above a small positive value.** Period is the seconds per cycle, and the behavior guards against zero, but a period at or below zero collapses into an extremely fast, useless flutter. If you use Subtract From Period to speed a wave up, do not let it drop near zero - set a sensible floor.
- **`triangle` for platforms, `sine` for organic motion, `square` for blinks.** The wave shape changes the feel completely. A platform on sine eases and is hard to time; on triangle it moves at a constant speed. A blink wants square, not a fade. Pick the shape for the job.
- **Phase is how you stagger a group.** Identical waves with different `phase_degrees` values ripple instead of moving in lockstep. Use 180 for a see-saw pair, or spread a squad by setting each member's phase from its index.
- **There are two names for the same knob - either works.** Set Sine Active and Set Active both set whether the wave runs; Set Phase and Set Phase Degrees both set the phase offset. They are the friendly named action and the auto-generated property setter for the same value, so use whichever reads better in your sheet.
- **Tune the motion by eye, in the editor.** You do not need to press play to see a wobble: Tools > Preview Behaviors on Selected Node animates the host right in the viewport while you drag the Inspector knobs, and restores it exactly when you stop. Dial in magnitude and period there, then keep the values.
- **The wave never fires a trigger.** This pack has no triggers and no conditions of its own; the motion just runs. Drive your reactions off your existing events, and branch on state with the Active expression (`Node | Sine: Active is true`) when you need it.
- **value-only drives nothing until you read it.** In value-only mode the node will not move on its own - that is the point. Read `$Node/Sine.wave_value` (a number between -1 and 1) each frame and apply it yourself, or you will see no effect and wonder why.
