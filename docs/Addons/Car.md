# Car - Top-Down Arcade Driving on a CharacterBody2D

Car is a Godot EventSheets behavior pack that turns a plain `CharacterBody2D` into a drivable top-down car. You attach a `CarBehavior` behavior to a **CharacterBody2D** node, and that node becomes the car. It drives itself from the arrow keys the moment you press play - accelerate and reverse on up/down, steer on left/right - so a car that grips, coasts, and drifts is one behavior on one node, with zero event rows required to make it move. On top of that, every handling knob (top speed, acceleration, coast-down, turn rate, grip, and drift sensitivity) is live: you read it back with an expression and change it at runtime with a Set / Add To / Subtract From action, which is how boost pads, ice patches, and damage models fall out of the pack. Every Action, Expression, and Trigger targets the `CarBehavior` living on the node you drop it on - there is no car-id to pass around, the node is the car.

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

- **Instant driving prototypes.** Drop the behavior on a body, press play, and the arrow keys already drive a car with grip and coasting - no movement code to write before you can feel it.
- **Top-down arcade racers.** Grip, a top speed, and a natural coast-down are built in, so a lap-based racer is a track, some checkpoints, and one behavior per car.
- **Drift games.** A grip blend and a drift threshold ship in the box, so tail-out corners and a drift score come from tuning `drift_recover` and reacting to On Drift Started, not a physics rabbit hole.
- **Getaway and chase scenes.** Give the player car the arrow keys and script obstacles around it; the handling is the same one model every vehicle shares.
- **Boats, hovercraft, and slidey vehicles.** Lower the grip and the car keeps sliding after the wheels point a new way, which reads exactly like a boat or a hovercraft on ice.
- **Karts and tanks.** Turn on Turn While Stopped and the car can pivot on the spot, so a tank or a nimble kart steers even at a standstill.
- **Runtime terrain handling.** Set Drift Recover on an ice patch, Subtract From Max Speed in the mud, and restore both on the way out - the same car handles differently per zone without a second movement system.
- **Boost pads and nitro.** Add To Max Speed and Add To Acceleration for a surge, then Subtract them back when the boost times out.
- **Damage models.** As the car takes hits, Subtract From Acceleration and Subtract From Steer Degrees so a beaten-up car accelerates and turns worse.
- **Skid marks and tyre smoke.** On Drift Started and On Drift Recovered bracket every slide, so a smoke puff or a skid trail is two events.
- **Difficulty and feel presets.** Pick an arcade or a sim feel at the start of a race by setting Drift Recover, Steer Degrees, and Max Speed once.
- **Mounts and vehicle sections.** A car you hop into for one level is a single behavior on one node, not a separate character controller.

---

## Core concepts

The mental model is small. Learn these ideas and the rest of the pack is just knobs.

**The host is the CharacterBody2D.** You attach `CarBehavior` to a `CharacterBody2D`, and that body IS the car. Every physics frame the behavior reads the arrow keys, updates the car's speed and heading, moves the body with Godot's own `move_and_slide`, and slides it along walls it hits. If the parent is not a `CharacterBody2D`, the behavior warns and does nothing - there is no body to drive.

**It drives from the arrow keys out of the box.** The behavior reads Godot's built-in input actions: `ui_up` accelerates forward, `ui_down` brakes and then reverses, and `ui_left` / `ui_right` steer. Those map to the arrow keys in every new Godot project, so a freshly attached car is already playable with no event rows. You only write events for the extras - drift reactions, boosts, terrain, resets.

**Speed builds and coasts.** Hold accelerate and `speed` climbs toward `max_speed` at the `acceleration` rate; hold reverse and it goes backward, capped at half the top speed. Let go and `deceleration` eases the speed back to zero, so the car rolls to a stop instead of dropping dead. Stop Car is the hard version: it kills all momentum at once.

**Steering turns the body.** `steer_degrees` is the turn rate in degrees per second at full lock. By default the turn eases in with speed, so a near-stopped car barely turns and a fast one turns hard, and the steering flips the right way when you reverse. Turn While Stopped overrides that so the car can pivot in place at a standstill.

**Grip versus drift is one knob.** Each physics frame the behavior blends the car's actual velocity toward the way it is pointing, and `drift_recover` is how much of that blend happens: near 1 the velocity snaps to the heading and the car feels glued and kart-like; low (the default is a loose 0.15) the velocity lags the heading and the car slides through corners. This is the single most important feel dial.

**Drift is detected and bracketed by triggers.** When the car is moving and the angle between where it points and where it actually moves passes `drift_angle_threshold` (in degrees), the behavior counts it as a drift and fires On Drift Started. When the slide settles back under the threshold and the car regrips, it fires On Drift Recovered. The pair is edge-triggered, so each fires exactly once per slide - perfect for starting and stopping a smoke effect or banking a score.

**Every knob is live.** All seven handling values are exported to the Inspector for a default, and exposed as ACEs for runtime. Read the current value with the matching expression (Max Speed, Acceleration, Drift Recover, and so on), and change it any time with Set (an absolute value), Add To (a relative bump), or Subtract From (a relative cut). That is how a boost pad, an ice patch, and a damage model all work without touching how the car is driven.

---

## Setup

**1. Make the body.** Create a `CharacterBody2D` node with a sprite and a **CollisionShape2D** child. The collision shape is what gives the car a size to slide along walls with; without it the car has no physical presence.

**2. Attach the behavior.** Add the `CarBehavior` behavior to that CharacterBody2D (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node onto the body). The behavior binds to its parent on ready and drives the car every physics frame.

**3. Set the Inspector knobs.** Select the node and tune `max_speed`, `acceleration`, `drift_recover`, and the rest to taste. The defaults are a loose, driftable arcade feel to start from.

**4. Press play.** The arrow keys already drive the car - up to accelerate, down to brake and reverse, left and right to steer. You add events only for the flavour. Here is a first sheet that reacts to drifting and gives you a panic brake:

```
Car On Drift Started
  -> Car: start tyre-smoke particles at Car.global_position

Car On Drift Recovered
  -> Car: stop tyre-smoke particles

Keyboard On "space" pressed
  -> Car | CarBehavior: Stop Car
```

The car drives itself; On Drift Started and On Drift Recovered bracket each slide so the smoke turns on and off with the drift, and the spacebar dumps all momentum for an instant stop.

---

## ACE reference

All ACEs live in the **Car** category and target the `CarBehavior` behavior on the node they are placed on. There is no car-id parameter anywhere - the node is the car. The handling actions and expressions are generated from the seven exported properties, so every knob has a read (an expression), an absolute write (Set), and two relative writes (Add To / Subtract From).

### Actions

| Action | Parameters | Description |
|---|---|---|
| Stop Car | (none) | Kills all momentum at once - zeroes the internal speed and the body's velocity. |
| Set Max Speed | `value` (float) | Sets the top forward speed in pixels per second (reverse tops out at half this). |
| Add To Max Speed | `amount` (float) | Raises the top forward speed by an amount (a boost). |
| Subtract From Max Speed | `amount` (float) | Lowers the top forward speed by an amount (a speed cap or slow zone). |
| Set Acceleration | `value` (float) | Sets how quickly speed ramps toward the top speed. |
| Add To Acceleration | `amount` (float) | Raises the acceleration. |
| Subtract From Acceleration | `amount` (float) | Lowers the acceleration (a sluggish or damaged engine). |
| Set Deceleration | `value` (float) | Sets how quickly the car coasts to a stop when off the throttle. |
| Add To Deceleration | `amount` (float) | Raises the coast-down rate (stops sooner). |
| Subtract From Deceleration | `amount` (float) | Lowers the coast-down rate (rolls further). |
| Set Steer Degrees | `value` (float) | Sets the turn rate in degrees per second at full lock. |
| Add To Steer Degrees | `amount` (float) | Raises the turn rate (sharper steering). |
| Subtract From Steer Degrees | `amount` (float) | Lowers the turn rate (heavier steering). |
| Set Drift Recover | `value` (float) | Sets the grip: 1 = velocity snaps to the heading (grippy), low = the car slides (drifty). |
| Add To Drift Recover | `amount` (float) | Raises grip toward 1 (grippier). |
| Subtract From Drift Recover | `amount` (float) | Lowers grip toward a slide (driftier). |
| Set Drift Angle Threshold | `value` (float) | Sets the slide angle in degrees that counts as a drift. |
| Add To Drift Angle Threshold | `amount` (float) | Raises the threshold (drifts are harder to trigger). |
| Subtract From Drift Angle Threshold | `amount` (float) | Lowers the threshold (drifts trigger sooner). |
| Set Turn While Stopped | `value` (bool) | Turns steering at a standstill on or off (on = the car can pivot in place). |

### Conditions

This pack ships no dedicated condition ACEs. Build a check by comparing one of the expressions below inside a normal condition, or branch inside the On Drift Started / On Drift Recovered triggers.

| Condition | Parameters | Description |
|---|---|---|
| (none) | - | Compare an expression (for example `Max Speed  <  400`) or react in the drift triggers instead. |

### Expressions

| Expression | Returns | Description |
|---|---|---|
| Max Speed | float | The current top forward speed, in pixels per second. |
| Acceleration | float | The current acceleration (how fast speed ramps up). |
| Deceleration | float | The current coast-down rate (how fast the car rolls to a stop). |
| Steer Degrees | float | The current turn rate, in degrees per second at full lock. |
| Drift Recover | float | The current grip (1 = grippy, low = drifty). |
| Drift Angle Threshold | float | The current slide angle, in degrees, that counts as a drift. |
| Turn While Stopped | bool | Whether steering at a standstill is enabled. |

### Triggers

| Trigger | Fires when |
|---|---|
| On Drift Started | The car is moving and its slide angle passes the drift threshold - the car breaks traction. |
| On Drift Recovered | A drift settles back under the threshold and the car regrips. |

### Inspector properties

Set these on the node for the default feel; each one also has the Set / Add To / Subtract From actions and a read expression above for runtime changes.

| Property | Type | Default | What it does |
|---|---|---|---|
| `max_speed` | float | `400.0` | Top forward speed, in pixels per second (reverse tops out at half). |
| `acceleration` | float | `300.0` | How fast speed ramps toward the top speed. |
| `deceleration` | float | `400.0` | How fast the car coasts to a stop off the throttle. |
| `steer_degrees` | float | `180.0` | Turn rate in degrees per second at full lock. |
| `drift_recover` | float | `0.15` | Grip: how much the velocity blends back to the heading each step (1 = grippy, low = drifty). |
| `drift_angle_threshold` | float | `15.0` | Slide angle in degrees that counts as a drift. |
| `turn_while_stopped` | bool | `false` | Allow steering while the car is standing still. |
| `ai_controlled` | bool | `false` | AI drive: read the held `ai_throttle_axis`/`ai_steer_axis` intents instead of the keyboard - a sheet or AI drives with the same drift physics (see docs/GUIDE-PLAYER-AND-AI-INPUT.md). |

---

## Use cases

Each example targets the `CarBehavior` behavior on the named node (here, `Car`). The car already drives from the arrow keys, so these events add the extras on top.

### 1. Tyre smoke on every drift

The drift triggers bracket each slide, so one event starts the smoke and one stops it - no per-frame slip checking.

```
Car On Drift Started
  -> Car: start tyre-smoke particles at Car.global_position

Car On Drift Recovered
  -> Car: stop tyre-smoke particles
```

Because the pair is edge-triggered, the smoke turns on the instant the car breaks traction and off the instant it regrips.

### 2. A panic brake

Stop Car kills all momentum at once, which is exactly what an instant handbrake or a crash-stop wants.

```
Keyboard On "space" pressed
  -> Car | CarBehavior: Stop Car
```

Unlike coasting, this zeroes both the internal speed and the body's velocity, so the car stops dead rather than rolling on.

### 3. A boost pad

Bump the top speed and acceleration when the car drives over a pad, then take the bump back off when the boost times out.

```
Car On Area Entered  "BoostPad"
  -> Car | CarBehavior: Add To Max Speed  300
  -> Car | CarBehavior: Add To Acceleration  400
  -> start Timer "boost"  1.5

On Timer  "boost"
  -> Car | CarBehavior: Subtract From Max Speed  300
  -> Car | CarBehavior: Subtract From Acceleration  400
```

Add To and Subtract From are a matched pair - undo the exact amount you added so the boost leaves no permanent change.

### 4. An ice patch

Drift Recover is the grip dial. Drop it hard on ice so the car keeps sliding after it points a new way, and restore it on the way out.

```
Car On Area Entered  "IcePatch"
  -> Car | CarBehavior: Set Drift Recover  0.03

Car On Area Exited  "IcePatch"
  -> Car | CarBehavior: Set Drift Recover  0.15
```

At 0.03 the velocity barely follows the heading, so the car skates through the corner instead of gripping it.

### 5. Mud that grabs and slows

Mud should cut the top speed and blunt the acceleration. Subtract both on entry and restore them on exit.

```
Car On Area Entered  "Mud"
  -> Car | CarBehavior: Subtract From Max Speed  200
  -> Car | CarBehavior: Subtract From Acceleration  150

Car On Area Exited  "Mud"
  -> Car | CarBehavior: Add To Max Speed  200
  -> Car | CarBehavior: Add To Acceleration  150
```

The car wallows through the mud at a lower cap, then springs back to its normal handling on dry road.

### 6. A drift-score meter

Bank points for every completed slide. Start a stopwatch on On Drift Started and cash it in on On Drift Recovered so longer drifts pay more.

```
Car On Drift Started
  -> reset Stopwatch to 0
  -> start Stopwatch

Car On Drift Recovered
  -> stop Stopwatch
  -> add Stopwatch.elapsed * 100 to Score
```

The edge-triggered pair means each drift is one clean start-to-finish window to time.

### 7. Tank-style pivot mode

Turn While Stopped lets the car steer at a standstill, so it can rotate on the spot like a tank or a nimble kart.

```
On Start of layout
  -> Car | CarBehavior: Set Turn While Stopped  true
```

With it on, holding a steer key while stopped rotates the body in place; leave it off (the default) and the car needs to be rolling to turn.

### 8. A damage model

A beaten-up car should handle worse. Each hit trims the acceleration and the turn rate, so damage is felt in the driving.

```
Car On Hit
  -> Car | CarBehavior: Subtract From Acceleration  40
  -> Car | CarBehavior: Subtract From Steer Degrees  15
```

Repair pickups do the reverse with Add To Acceleration and Add To Steer Degrees, restoring the crisp handling.

### 9. A nitro toggle

Hold the nitro key for a higher cap and sharper acceleration, and set both back to their normal values on release.

```
Keyboard On "shift" pressed
  -> Car | CarBehavior: Set Max Speed  650
  -> Car | CarBehavior: Set Acceleration  600

Keyboard On "shift" released
  -> Car | CarBehavior: Set Max Speed  400
  -> Car | CarBehavior: Set Acceleration  300
```

Using Set with fixed numbers here keeps the toggle exact no matter how many times it is pressed.

### 10. Difficulty presets at the start of a race

Pick an arcade or a sim feel once, before the flag drops, by setting the handling knobs together.

```
On Race Start
  Condition: Settings.mode  ==  "arcade"
    -> Car | CarBehavior: Set Drift Recover  0.4
    -> Car | CarBehavior: Set Steer Degrees  220
  Condition: Settings.mode  ==  "sim"
    -> Car | CarBehavior: Set Drift Recover  0.85
    -> Car | CarBehavior: Set Steer Degrees  140
```

Higher Drift Recover and a faster turn rate feel loose and forgiving; a grippier, slower-turning car feels weighty and precise.

### 11. Kill momentum before a cutscene

Stop Car before a scripted beat so the car is not drifting away while the camera cuts to the conversation.

```
On Cutscene Start
  -> Car | CarBehavior: Stop Car
  -> disable player input
```

Stopping the car first means the scripted shot starts from a clean, still frame.

### 12. Beginner drift assist

Lower the drift threshold so the car counts a smaller slide as a drift, making On Drift Started fire sooner for new players; raise it back for a stricter mode.

```
On Assist Enabled
  -> Car | CarBehavior: Set Drift Angle Threshold  8

On Assist Disabled
  -> Car | CarBehavior: Set Drift Angle Threshold  15
```

At a threshold of 8 degrees the tiniest tail slide already scores as a drift, so beginners feel the reward without needing perfect technique.

### 13. A slippery boss arena

Make one whole room ice by cutting grip when the car enters the arena and restoring it on the way out.

```
Car On Area Entered  "BossArena"
  -> Car | CarBehavior: Set Drift Recover  0.06

Car On Area Exited  "BossArena"
  -> Car | CarBehavior: Set Drift Recover  0.15
```

Low grip across the arena forces the player to plan every turn, which reads as a distinct handling challenge for the fight.

### 14. A HUD tuning readout

Show the live handling values on a debug HUD by reading the expressions each frame - handy while you dial in the feel.

```
Every tick
  -> set TopSpeedLabel.text to Car | CarBehavior: Max Speed
  -> set GripLabel.text to Car | CarBehavior: Drift Recover
```

Because the expressions read the current values (not the Inspector defaults), the labels update the instant a boost pad or an ice patch changes them.

### 15. Checkpoint respawn with a crash blink

Pair the car with the Flash pack for a clean water-hazard respawn: kill all momentum, teleport to the last checkpoint, and blink the car so the reset reads clearly.

```
Car On Area Entered  "Water"
  -> Car | CarBehavior: Stop Car
  -> Car: set global_position to LastCheckpoint.position
  -> Car | FlashBehavior: Flash  0.6
```

Stop Car before the teleport so no leftover velocity carries into the respawned car.

### Other use cases

**Racing drift trials.** A time-attack mode where only sliding scores: On Drift Started and On Drift Recovered bracket every slide, and the summed drift time decides the medal at the finish line.

**Demolition derby.** Every collision Subtracts From Acceleration and Steer Degrees, so battered cars visibly limp and wallow, and the last car that still handles wins the arena.

**Courier rush on mixed terrain.** A timed delivery route crosses mud, ice, and boost pads, each zone retuning Max Speed and Drift Recover on entry and restoring it on exit.

**Top-down tank level.** Turn While Stopped on plus a low Steer Degrees reads as tracked steering, so the same behavior drives a tank that pivots in place between shots.

**Rally school tutorial.** Lessons lower the Drift Angle Threshold so students trigger scored drifts early and feel the reward, then the exam raises it back for strict technique.

---

## Tips and common mistakes

- **The host must be a CharacterBody2D.** The pack drives Godot's kinematic body with `move_and_slide`. On any other node type there is nothing for the behavior to move, and it warns and sits idle. If the car does not move, check the parent node type first.
- **Keep a CollisionShape2D on the body.** Without a collision shape the CharacterBody2D has no size, so it will not slide along walls or register as solid. It is the most common reason a car passes straight through the level.
- **The arrow keys already drive it - do not rewire movement.** The behavior reads the built-in `ui_up` / `ui_down` / `ui_left` / `ui_right` actions itself, so the car is playable the moment it is attached. You write events for boosts, terrain, drift reactions, and resets, not for basic driving. If you want WASD too, add those keys to the same input actions in Project Settings rather than adding movement events.
- **The default feel is deliberately drifty.** `drift_recover` defaults to a low 0.15, so out of the box the car slides through corners. If you want tight, kart-like grip, raise Drift Recover toward 1 (in the Inspector or with Set Drift Recover); if you want a boat or an ice-racer, push it lower.
- **Match every Add To with a Subtract From (or use Set).** Add To and Subtract From are relative, so a boost that adds 300 to Max Speed must subtract exactly 300 to undo it. If a value drifts over time, you are adding and removing different amounts - switch to Set with fixed numbers when you want an exact, repeatable value like a nitro toggle.
- **Stop Car is a hard stop, not a brake.** It zeroes all momentum instantly. For a car that eases to rest, let go of the throttle and let `deceleration` coast it down; reach for Stop Car for crashes, respawns, and cutscene freezes.
- **The drift triggers are edge-triggered - use the pair.** On Drift Started fires once when the slide begins and On Drift Recovered once when it ends. Start an effect or a timer in the first and end it in the second; do not poll for a drift every frame, and do not expect On Drift Started to keep firing while the slide holds.
- **Turn While Stopped changes standstill steering, nothing else.** With it off (the default) the car needs speed to turn, which feels like a real car; turn it on for tanks and karts that pivot in place. It does not affect how the car turns while moving.
- **Reverse is capped at half the top speed.** Holding the down key backs the car up, but only to half of `max_speed`. That is intentional arcade feel - a car should not reverse as fast as it drives forward.
- **The drift threshold is in degrees.** Set Drift Angle Threshold and its Add To / Subtract From take a slide angle in degrees, not a speed. A smaller number makes drifts trigger on gentler slides (easier), a larger number demands a harder slide (stricter).
