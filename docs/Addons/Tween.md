# Tween - One-Call Motion, Squash, Fade, and Spin

Tween is a Godot EventSheets behavior pack that wraps Godot's tween system in plain event-sheet rows. It is a per-node `TweenBehavior` you attach to a `Node2D` host - a sprite, a UI root, a pickup, a boss. You pick the *feel* once in the Inspector (a transition curve and an easing direction), then call a single action to animate the host: slide it to a spot, scale it, spin it, fade it, or tween any property by path. There is no tween object to build up call by call and no signal wiring - the behavior owns the tween, tells you when it finishes with a trigger, and stops it on command. It compiles down to a normal `create_tween()` under the hood, so the generated GDScript has zero plugin dependency.

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

- **Juicy spawn pops.** Start a pickup at zero scale and Tween Scale it up to 1, so items and enemies pop into the world instead of blinking on.
- **Menu and HUD slides.** Tween Position a panel from off-screen to its resting spot, and slide it back out when the menu closes.
- **Fade in and fade out.** Tween Alpha from 0 to 1 to reveal a sprite, or to 0 to dissolve it, then free it when the fade finishes.
- **Collectible spin and bob.** Tween Rotation a coin around, or nudge it up and down with Tween Position, for that "pick me up" shimmer.
- **Hit and hurt feedback.** Punch the scale up on damage, then let the On Tween Finished trigger settle it back to normal for a satisfying squash.
- **Button and icon hover states.** Grow a button with Tween Scale on hover and shrink it back on exit, no animation player needed.
- **Door, lever, and turret rotation.** Tween Rotation a hinged object to its open angle or aim a turret toward a target degrees value.
- **Springy, bouncy, elastic feel.** Switch the Inspector transition to `bounce`, `elastic`, `back`, or `spring` and every tween on that node inherits the character instantly.
- **Chained move sequences.** Kick off the next Tween Position inside On Tween Finished to walk a node through a path of waypoints.
- **Interruptible motion.** Stop Tweens the instant the player takes control back or the object dies, so nothing keeps drifting after it should have stopped.
- **Guarded re-triggers.** Check Is Tweening before starting a new animation so a mashed button does not restart the same motion mid-flight.
- **Any property, not just the built-ins.** Tween Property reaches any scalar on the host by path (like `modulate:r` or `position:x`) when the named actions do not cover it.

---

## Core concepts

The pack is small on purpose. Five ideas cover the whole thing.

**The node is the mover.** You attach one `TweenBehavior` to a `Node2D`, and every action targets that host node. There is no tween id to pass around and no "which node" argument - the behavior animates the node it lives on. The host must be a `Node2D` (or a subclass like `Sprite2D`, `CharacterBody2D`, or a `Control` wrapped under a `Node2D`); the behavior warns in the output if its parent is not one.

**Feel is set once, in the Inspector.** Two knobs shape how every tween moves: `transition` (the curve - `sine`, `bounce`, `elastic`, `back`, `spring`, and more) and `easing` (the direction the curve is applied - `in`, `out`, `in_out`, `out_in`). You set them on the behavior node and they apply to *all* tweens that node runs. To give one object two different feels, attach two behaviors or change the knob between calls.

**One action, one tween.** Each action - Tween Position, Tween Scale, Tween Rotation, Tween Alpha, Tween Property - starts a tween from the host's *current* value to the *target* you pass, over a duration in seconds. The values are absolute destinations, not offsets: Tween Position moves the host *to* `(x, y)`, Tween Rotation spins it *to* `degrees`. Fire the action and the behavior builds the tween, runs it, and cleans up.

**Duration 0 means "use the default."** Pass `0` for any `duration` and the behavior substitutes the `default_duration` Inspector value (0.3s out of the box). Pass a real number to override it for that one call. This keeps most rows short - one default that reads well everywhere, an explicit time only when a specific beat needs it.

**The behavior tracks the latest tween.** It remembers the most recent tween it started. Is Tweening tells you whether that tween is still running, Stop Tweens kills it in place (the host stays exactly where it stopped), and On Tween Finished fires when it reaches the end. Starting a new tween action makes *that* the tracked one. Because Tween Property takes a single number, aim it at a scalar sub-property (like `position:x` or `modulate:a`), not a whole vector.

---

## Setup

**1. Attach the behavior.** Add a `TweenBehavior` as a child node of the `Node2D` you want to animate (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node in as a child). One behavior per node you want to move.

**2. Set the Inspector knobs.** Select the behavior node and pick the feel:

| Property | Default | What it does |
|---|---|---|
| `default_duration` | `0.3` | Seconds used whenever a tween action is passed `0` for its duration. |
| `transition` | `sine` | The transition curve every tween uses: `linear`, `sine`, `quad`, `cubic`, `quart`, `quint`, `expo`, `circ`, `elastic`, `back`, `bounce`, `spring`. |
| `easing` | `out` | How the curve is applied: `in` (slow start), `out` (slow end), `in_out`, `out_in`. |

**3. Call an action, react to the finish.** A minimal first behavior - a chest that pops open and settles back:

```
On Ready
  -> Chest: set scale to (0, 0)
  -> Chest | Tween: Tween Scale  1.2, 0.25

On Tween Finished
  Condition: Chest | Tween  Is Tweening   [is NOT tweening]
    -> Chest | Tween: Tween Scale  1.0, 0.15
```

The chest starts flat, springs up to 1.2 scale, and On Tween Finished settles it to a normal 1.0 - a quick pop-and-settle. Set the Inspector `transition` to `back` or `elastic` to make the pop overshoot for extra bounce.

---

## ACE reference

All ACEs live in the **Tween** category and target the `TweenBehavior` on the node they are placed on. Every `duration` is in seconds, and passing `0` uses the `default_duration` Inspector value.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Tween Property | `property_path` (String), `final_value` (float), `duration` (float) | Tweens any host property to a value. Aim it at a scalar path like `position:x`, `modulate:a`, `rotation_degrees`, or `scale:x` - `final_value` is a single number. |
| Tween Position | `x` (float), `y` (float), `duration` (float) | Moves the host to the absolute point `(x, y)`. |
| Tween Scale | `amount` (float), `duration` (float) | Scales the host uniformly (both axes) to `amount`. |
| Tween Rotation | `degrees` (float), `duration` (float) | Rotates the host to the given absolute angle in degrees. |
| Tween Alpha | `alpha` (float), `duration` (float) | Fades the host's `modulate` alpha to `alpha` (clamped 0 - 1). |
| Stop Tweens | (none) | Kills the running tween; the host stays exactly where it is. |

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Tweening | (none) | Whether the behavior's tracked tween is currently running. |

### Expressions

| Expression | Parameters | Returns | Description |
|---|---|---|---|
| (none) | | | This pack publishes no authored expressions. Values you tween toward come from your own object properties and expressions. |

### Triggers

| Trigger | Fires when |
|---|---|
| On Tween Finished | The behavior's tween reaches the end of its run. |

### Inspector properties

| Property | Type | Default | Range / Options |
|---|---|---|---|
| `default_duration` | float | `0.3` | 0.01 - 10 (step 0.01) |
| `transition` | String | `sine` | `linear`, `sine`, `quad`, `cubic`, `quart`, `quint`, `expo`, `circ`, `elastic`, `back`, `bounce`, `spring` |
| `easing` | String | `out` | `in`, `out`, `in_out`, `out_in` |

### Inspector properties are ACEs too

Every property this pack exposes in the Inspector is also reachable from the picker, generated for you:
an expression named after the property reads it, a **Set ...** action writes it, and for number properties
**Add To ...** and **Subtract From ...** adjust it by an amount. They sit in the pack's own category
alongside the verbs above, so any knob you can set in the Inspector is also something a sheet can read and
change while the game runs.

---

## Use cases

Each example targets the `TweenBehavior` on the named node. Set the transition and easing in the Inspector, then call an action and react in On Tween Finished where a sequence needs it.

### 1. Pop a pickup in on spawn

Start the coin flat and scale it up so it pops into existence.

```
On Ready
  -> Coin: set scale to (0, 0)
  -> Coin | Tween: Tween Scale  1.0, 0.3
```

Set the Inspector `transition` to `back` so the pop overshoots slightly before settling.

### 2. Slide a menu panel in from off-screen

Move the panel from its hidden position to its resting spot.

```
On Menu Opened
  -> Panel | Tween: Tween Position  640, 360, 0.4
```

Because Tween Position takes an absolute target, place the panel off-screen first (or in the editor), then tween it to its on-screen coordinates.

### 3. Fade a sprite in

Start transparent and tween alpha up to fully opaque.

```
On Ready
  -> Ghost: set modulate alpha to 0
  -> Ghost | Tween: Tween Alpha  1.0, 0.5
```

### 4. Fade out, then free the node

Dissolve an enemy on death and remove it once the fade completes.

```
On Enemy Died
  -> Enemy | Tween: Tween Alpha  0.0, 0.6

On Tween Finished
  -> Enemy: queue_free()
```

On Tween Finished is the clean hook for "do this after the animation," so the node is not freed mid-fade.

### 5. Pop-and-settle hit feedback

Punch the scale up on damage, then let the finish trigger settle it back.

```
On Took Damage
  -> Player | Tween: Tween Scale  1.3, 0.08

On Tween Finished
  -> Player | Tween: Tween Scale  1.0, 0.12
```

The first tween overshoots big and fast; the second eases it home for a squash that reads even in a busy screen.

### 6. Grow a button on hover, shrink on exit

Two rows, two states, one behavior on the button.

```
On Button Mouse Entered
  -> Button | Tween: Tween Scale  1.15, 0.1

On Button Mouse Exited
  -> Button | Tween: Tween Scale  1.0, 0.1
```

Starting the second tween replaces the first, so a fast in-and-out never leaves the button stuck mid-grow.

### 7. Spin a collectible forever-ish

Rotate a gem to a large angle so it keeps turning, and re-fire on finish for a loop.

```
On Ready
  -> Gem | Tween: Tween Rotation  360, 1.0

On Tween Finished
  -> Gem: set rotation to 0
  -> Gem | Tween: Tween Rotation  360, 1.0
```

Snapping back to 0 before the next spin keeps the degrees value from climbing without bound. Set the Inspector `easing` to `in_out` for a smooth continuous turn, or `linear` for a constant one.

### 8. Open a door by rotating it

Swing a hinged door to its open angle.

```
On Door Interacted
  -> Door | Tween: Tween Rotation  -90, 0.5
```

Set the Inspector `transition` to `back` or `elastic` for a door that swings open with weight and a little bounce.

### 9. Chain a node through waypoints

Walk an object from point to point by starting the next move inside the finish trigger.

```
On Patrol Start
  -> Drone | Tween: Tween Position  200, 100, 1.0

On Tween Finished
  -> Drone | Tween: Tween Position  600, 100, 1.0
```

Each leg starts when the previous one ends. Store the next target on the object and read it in the trigger to walk a longer path.

### 10. Stop a tween when the player takes control

Cancel any drifting motion the instant input arrives, leaving the node where it stopped.

```
On Move Input Pressed
  -> Player | Tween: Stop Tweens
```

Stop Tweens kills the tracked tween in place, so an auto-move never fights the player's own input.

### 11. Guard against restarting a tween mid-flight

Only start the pulse if one is not already running, so a mashed button does not restart it.

```
On Attack Pressed
  Condition: Weapon | Tween  Is Tweening   [is NOT tweening]
    -> Weapon | Tween: Tween Scale  1.4, 0.1
```

Is Tweening lets a motion play out cleanly before it can be triggered again.

### 12. Wait for a fade before swapping scenes

Fade the screen out, and only transition once the fade is truly done.

```
On Exit Pressed
  -> Fader | Tween: Tween Alpha  0.0, 0.5

On Tween Finished
  -> change scene to "res://levels/hub.tscn"
```

Using the finish trigger instead of a fixed wait time keeps the swap perfectly synced to the fade, even if you retune the duration later.

### 13. Tween a single axis with Tween Property

Slide something horizontally without touching its y, by aiming Tween Property at `position:x`.

```
On Reveal Triggered
  -> Card | Tween: Tween Property  "position:x", 480, 0.3
```

Tween Property's value is one number, so target a scalar sub-property like `position:x`, `scale:y`, or `modulate:a` rather than a whole vector.

### 14. Tint a sprite by tweening a color channel

Flash a red danger tint by tweening the red channel of modulate.

```
On Warning Started
  -> Boss | Tween: Tween Property  "modulate:r", 1.0, 0.2

On Tween Finished
  -> Boss | Tween: Tween Property  "modulate:r", 0.5, 0.4
```

The named actions cover position, scale, rotation, and alpha; Tween Property reaches everything else on the host by path.

### 15. Quick default-duration nudges

Leave the duration at 0 to inherit the Inspector `default_duration`, so every small nudge shares one consistent timing.

```
On Selected
  -> Icon | Tween: Tween Scale  1.1, 0

On Deselected
  -> Icon | Tween: Tween Scale  1.0, 0
```

Passing `0` uses `default_duration` (0.3s by default). Retune the feel of every quick nudge from one Inspector knob instead of editing rows.

### Other use cases

**Card flip.** Tween Property squeezes `scale:x` to 0, the finish trigger swaps the card face, and a second tween opens it back to 1 - a full flip built from one scalar path.

**Prize wheel.** Tween Rotation with an `out` easing and a long duration sends the wheel spinning fast and coasting to a stop exactly on the winning angle you passed in.

**Elevator platform.** A lift Tween Positions between its floor marks, and On Tween Finished waits a beat before starting the return trip, so the ride has a natural pause at each stop.

**Ambient cloud drift.** Background clouds slowly Tween Position across the sky, and On Tween Finished teleports each one back to the far edge to start again, filling the scene with lazy motion.

**Damage vignette pulse.** A full-screen red overlay Tween Alphas up sharply when the player is hurt and fades back down, a readable "you got hit" flash that doubles as a low-health warning.

---

## Tips and common mistakes

- **The host must be a `Node2D`.** The behavior animates its parent and expects a `Node2D` (sprites, bodies, and most 2D objects qualify). If the parent is not one, the behavior warns and the tweens do nothing - attach it under a proper 2D node.
- **Targets are absolute, not relative.** Tween Position moves the host *to* `(x, y)` and Tween Rotation spins it *to* `degrees` - they are destinations, not offsets. To move "by" an amount, add the offset to the host's current value in the expression you pass.
- **Feel is shared across the whole behavior.** The `transition` and `easing` Inspector knobs apply to *every* tween that behavior runs. For two different feels on one object, attach two behaviors or change the knob between calls; there is no per-action curve override.
- **Duration 0 means default, not instant.** Passing `0` substitutes `default_duration` (0.3s). If you truly want a snap, set the value directly on the host instead of tweening, or pass a tiny duration like `0.01`.
- **Only the latest tween is tracked.** Is Tweening, Stop Tweens, and On Tween Finished all refer to the most recent tween the behavior started. Starting a new tween action makes that the tracked one, so guard rapid re-triggers with Is Tweening if overlap matters.
- **Tween Property needs a scalar path.** `final_value` is a single number, so aim Tween Property at a sub-property like `position:x`, `scale:y`, or `modulate:a` - not a whole `position` or `modulate`. Use Tween Position or Tween Scale when you want to move both axes at once.
- **Tween Alpha is clamped 0 - 1.** Values outside that range are pinned, so you cannot over-fade past invisible or past fully opaque. Tween the whole `modulate` channels separately with Tween Property if you need a tint beyond alpha.
- **Sequence with On Tween Finished, not a fixed wait.** When one motion must follow another, start the next action inside the finish trigger. It stays synced even after you change a duration, unlike a hard-coded wait timer.
- **Stop Tweens leaves the host in place.** It kills the motion where it is; it does not snap back to a start or end value. If you want a clean reset, set the host's value directly after stopping.
