# Physics Car - Arcade Driving on a Real Physics Body

Physics Car is a Godot EventSheets behavior pack that turns a physics body into a drivable arcade car. You attach a `PhysicsCar` behavior to a **RigidBody2D** node, and that body becomes the car. The body itself IS Godot's physics body, so it keeps doing what it already does well: collisions, pushes, and impacts stay fully physical and cost you nothing to keep in sync. The behavior adds the driving on top - throttle, brake, and steering forces, lateral grip so the car does not slide sideways like a hockey puck, and drift detection. Every Action, Condition, Expression, and Trigger targets the `PhysicsCar` living on the node you drop it on. Drive it with the keyboard-style Simulate Control, feed it analog Set Throttle / Set Steer values, or hand it a target with Drive Toward Angle / Drive Toward Position and let it steer itself.

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

- **Top-down racing.** Give each racer a `PhysicsCar`, feed it the keyboard, and you have grip, coasting, and a real top speed without hand-writing the force math.
- **Drift games.** Slip angle, a drift threshold, and a momentary handbrake are built in, so tail-out corners and a drift score fall out of the pack instead of a physics rabbit hole.
- **AI chase cars.** Point Drive Toward Angle at the player each frame and the car turns to face them and accelerates - a pursuer that reads the track, not a waypoint puppet.
- **AI patrol and racing lines.** Drive Toward Position steers toward a waypoint and fires On Drive Target Reached when it arrives, so a patrol loop or a racing line is a short list of points.
- **Terrain handling.** Two runtime multipliers - surface grip and surface resistance - turn any zone into ice, mud, grass, or gravel without touching the car's tuning.
- **Twin-stick and top-down shooters with vehicles.** Set Throttle and Set Steer take analog stick values straight through, so a gamepad car feels smooth, not four-directional.
- **Bumper cars and demolition.** Because the body is a real RigidBody2D, cars shove each other physically, and On Collided plus Collision Force let you react to the hit.
- **Getaway and cop-chase scenes.** Mix a player car (keyboard) with AI cars (Drive Toward) in the same scene, all sharing one grip and drift model.
- **Boost-pad and hazard tracks.** Set Max Speed at runtime for boost strips and speed traps; Set Surface Grip for oil slicks and ice patches.
- **Off-road and rally.** Turn grip down and resistance up in the rough, so the car scrabbles for traction the way a rally car should.
- **Vehicle sections in a bigger game.** A driving minigame, an escape sequence, or a mount you hop into is one behavior on one node, not a separate movement system.

---

## Core concepts

The mental model is small. Learn these ideas and the rest of the pack is just knobs.

**The host is the RigidBody2D.** There is no separate physics component to add and keep in sync. The node you attach `PhysicsCar` to is Godot's own rigid body, and it keeps handling collisions, pushes, and impacts on its own. Every physics frame the behavior reads the body's motion, then applies drive, brake, coast, steering, and grip forces to it. Because it all goes through real forces and impulses, a crash into a wall behaves like a crash, not like a teleport.

**Input persists until you change it.** Set Throttle, Set Brake, and Set Steer set a value that stays put frame after frame until you set a new one or call Stop. Throttle runs -1 (full reverse) to 1 (full forward), brake runs 0 to 1, and steer runs -1 (full left) to 1 (full right). This is why a driving loop calls these every frame: you are continuously telling the car what you want, and releasing a key means writing 0 (or calling Stop), not just not pressing it.

**Simulate Control is the keyboard shortcut.** Instead of managing three values by hand, Simulate Control takes a `direction` of `up`, `down`, `left`, `right`, or `stop`. Pass `up` while the accelerate key is held (it sets full throttle), `left` or `right` while a steer key is held, and `stop` when no key is down (it clears throttle, steer, and brake). Call it every frame the key is down. It is the fastest way to a playable car.

**Drive Toward is the auto-steer for AI.** Two actions turn the car into a self-driver. Drive Toward Angle aims at a heading in degrees; Drive Toward Position aims at a world point. Both steer proportionally toward the target, apply the throttle you pass, and stop steering once the car faces within the `tolerance` you give. You call them every frame - each call recomputes the heading error and sets steering and throttle for that frame. Drive Toward Position also fires On Drive Target Reached when the car gets within the reach distance. Either action puts the car in a drive mode you can read back with Is Driving Toward Angle / Is Driving Toward Position; any manual Set Throttle / Set Steer or a Stop clears that mode.

**Lateral grip is what stops the ice-skating.** A real rigid body, given a sideways shove, keeps sliding sideways forever. Every frame the behavior cancels part of that sideways slide - that is grip. The `grip` knob (0 to 1) sets how much: near 1 the car is glued to its heading and corners cleanly, near 0 it slides like ice. This is the single most important feel knob.

**Slip angle and drift.** The car points one way and moves another; the angle between the two is the slip angle. When slip climbs past the `drift_threshold` (in degrees) and the car is moving fast enough, the behavior counts it as a drift: it fires On Drift Started, tracks Drift Duration in seconds, and fires On Drift Ended when the slide settles. The handbrake is the manual way to break traction: Enable Handbrake drops grip to `handbrake_grip` for that one frame so the back end steps out.

**Terrain is two multipliers.** You do not retune the car for mud. Set Surface Grip multiplies the base grip (0.2 for ice, 0.45 for mud, 1 for no change) and Set Surface Resistance multiplies the coasting drag (above 1 is sticky mud that slows you, below 1 is slick). Reset Surface puts both back to 1 when the car leaves the zone. Has Surface Override tells you a terrain effect is active.

**The Inspector knobs tune the feel.** Everything above has a default you set once on the node: `max_speed`, `acceleration`, `reverse_max_speed`, `reverse_acceleration`, `brake_force`, `coast_drag`, `steer_rate`, `speed_based_steering`, `min_steer_speed`, `grip`, `drift_threshold`, `handbrake_grip`, and `reach_distance`. Tune these and the car feels different without changing a single event row. See the [Inspector properties](#inspector-properties) table for what each one does.

---

## Setup

**1. Make the body.** Create a `RigidBody2D` node with a sprite and, importantly, a **CollisionShape2D** child. The collision shape is what makes it a physics body at all - without it the car has no size, cannot collide, and On Collided never fires.

**2. Attach the behavior.** Add the `PhysicsCar` behavior to that RigidBody2D (open the pack sheet and use Tools > Attach to Selected Node, or drop the pack node onto the body). The behavior wires the body's contact reporting on ready so collisions report back, and it drives the car every physics frame.

**3. Set the Inspector knobs.** Select the node and tune `max_speed`, `acceleration`, `grip`, and the rest to taste. The defaults are a sensible arcade feel to start from.

**4. Drive it.** Here is a complete first car - keyboard driving, where Simulate Control is paired with Stop when no key is down:

```
Every tick
  Condition: Keyboard  Key "up" is down
    -> Car | PhysicsCar: Simulate Control  "up"
  Condition: Keyboard  Key "left" is down
    -> Car | PhysicsCar: Simulate Control  "left"
  Condition: Keyboard  Key "right" is down
    -> Car | PhysicsCar: Simulate Control  "right"
  Condition: Keyboard  Key "down" is down
    -> Car | PhysicsCar: Simulate Control  "down"
  Condition: Keyboard  no arrow key is down
    -> Car | PhysicsCar: Simulate Control  "stop"
```

Each held key pushes one axis: `up` sets full throttle, `left` and `right` set steering. When nothing is held, `stop` releases everything so the car coasts to rest. Because input persists, the `stop` line is what returns the car to neutral - leave it out and the last steer value would hold forever.

---

## ACE reference

All ACEs live in the **Physics Car** category and target the `PhysicsCar` behavior on the node they are placed on. There is no car-id parameter anywhere - the node is the car.

### Actions

| Action | Parameters | Description |
|---|---|---|
| Set Throttle | `amount` (float) | Sets the throttle from -1 (full reverse) to 1 (full forward). Persists until you change it or call Stop. |
| Set Brake | `amount` (float) | Sets the brake from 0 (off) to 1 (full). Braking slows the car without reversing it. |
| Set Steer | `amount` (float) | Sets the steering from -1 (full left) to 1 (full right). Persists until you change it or call Stop. |
| Simulate Control | `direction` (String: `up` / `down` / `left` / `right` / `stop`) | The keyboard-style control: pass `up` / `down` / `left` / `right` while the key is held, or `stop` to release. Call it every frame the key is down (pair with Stop when no key is down). |
| Stop | (none) | Clears throttle, brake, and steer, and exits any Drive Toward mode. The car coasts to rest. |
| Enable Handbrake | (none) | Cuts the grip for this one physics frame, so the back end slides. Call it every frame you want the handbrake held. |
| Drive Toward Angle | `target_angle` (float), `throttle_amount` (float), `max_steer` (float), `tolerance` (float) | Auto-steers toward a heading (degrees) and applies throttle. Call it each frame; the car turns until it faces within the tolerance. Sets the Is Driving Toward Angle mode. |
| Drive Toward Position | `x` (float), `y` (float), `throttle_amount` (float), `max_steer` (float), `tolerance` (float) | Auto-steers toward a world position and applies throttle. Call it each frame (for example toward a waypoint). Fires On Drive Target Reached inside the reach distance. Sets the Is Driving Toward Position mode. |
| Teleport | `x` (float), `y` (float) | Moves the car to a position and clears its velocity and spin (for respawns and resets). |
| Set Max Speed | `value` (float) | Changes the top forward speed at runtime (for boosts or speed caps). |
| Set Grip | `value` (float) | Changes the base sideways grip at runtime (1 = glued, 0 = ice). |
| Set Surface Grip | `multiplier` (float) | Sets a terrain grip multiplier on top of the base grip (for example 0.2 on ice, 0.45 in mud). 1 = no change. |
| Set Surface Resistance | `multiplier` (float) | Sets a terrain drag multiplier (above 1 = sticky mud that slows you, below 1 = slick). 1 = no change. |
| Reset Surface | (none) | Restores both terrain multipliers to 1 (call it when the car leaves a terrain zone). |
| Set Reach Distance | `distance` (float) | Sets how close (pixels) a Drive Toward target must be to fire On Drive Target Reached. |

The Drive Toward actions default `throttle_amount` to 1.0, `max_steer` to 1.0, and `tolerance` to 5.0. Simulate Control defaults `direction` to `up`.

### Conditions

| Condition | Parameters | Description |
|---|---|---|
| Is Moving | (none) | Whether the car is above a small movement speed. |
| Is Reversing | (none) | Whether the car is moving backwards. |
| Is Drifting | (none) | Whether the slip angle is past the drift threshold. |
| Is Handbrake Active | (none) | Whether the handbrake was requested this physics frame. |
| Is At Max Speed | (none) | Whether the car has hit its forward speed cap. |
| Has Reached Drive Target | (none) | Whether the last Drive Toward Position target has been reached. |
| Has Surface Override | (none) | Whether a terrain grip or resistance multiplier is currently in effect. |
| Is Driving Toward Angle | (none) | Whether the car is in Drive Toward Angle mode. |
| Is Driving Toward Position | (none) | Whether the car is in Drive Toward Position mode. |

### Expressions

| Expression | Returns | Description |
|---|---|---|
| Speed | float | Current speed, in pixels per second. |
| Forward Speed | float | Speed along the way the car faces (negative when reversing). |
| Lateral Speed | float | Sideways slide speed (the part grip fights). |
| Angle Of Motion | float | The direction the car is actually moving, in degrees. |
| Slip Angle | float | Degrees between where the car points and where it moves. |
| Drift Duration | float | Seconds the current drift has lasted (or the final length inside On Drift Ended). |
| Throttle Input | float | The current throttle value (-1 to 1). |
| Brake Input | float | The current brake value (0 to 1). |
| Steer Input | float | The current steer value (-1 to 1). |
| Heading Error | float | Signed degrees a Drive Toward action still needs to turn. |
| Drive Target Distance | float | Distance to the current Drive Toward Position target (0 if none). |
| Effective Grip | float | The final grip after handbrake and terrain multipliers. |
| Surface Grip Multiplier | float | The active terrain grip multiplier. |
| Surface Resistance Multiplier | float | The active terrain drag multiplier. |
| Collision Force | float | Approximate impact speed of the latest collision (inside On Collided). |
| Collision Angle | float | Approximate impact direction in degrees (inside On Collided). |

### Triggers

| Trigger | Fires when |
|---|---|
| On Collided | The body hits something (its own physics contact). Read Collision Force and Collision Angle inside it. |
| On Drift Started | The slip angle climbs past the drift threshold while moving fast enough. |
| On Drift Ended | A drift settles back below the threshold. Drift Duration holds the final length here. |
| On Drive Target Reached | The car reaches a Drive Toward Position target inside the reach distance. |

### Inspector properties

| Property | Type | Default | What it does |
|---|---|---|---|
| `max_speed` | float | `400.0` | Top forward speed, in pixels per second. |
| `acceleration` | float | `1800.0` | Forward push strength (how hard the engine accelerates). |
| `reverse_max_speed` | float | `180.0` | Top reverse speed, in pixels per second. |
| `reverse_acceleration` | float | `900.0` | Reverse push strength. |
| `brake_force` | float | `2800.0` | Braking strength. |
| `coast_drag` | float | `0.4` | Coasting drag when you are off the throttle (higher = slows sooner). Range 0 to 4. |
| `steer_rate` | float | `3.2` | Turn rate at full steer and full speed, in radians per second. Range 0.5 to 12. |
| `speed_based_steering` | bool | `true` | Ease steering in with speed, so a near-stopped car barely turns. |
| `min_steer_speed` | float | `40.0` | Speed at which steering reaches full strength (with speed-based steering on). |
| `grip` | float | `0.78` | Sideways grip: how much side-slip is cancelled each step (1 = glued, 0 = ice). Range 0 to 1. |
| `drift_threshold` | float | `12.0` | Slip angle (degrees) that counts as a drift. Range 1 to 60. |
| `handbrake_grip` | float | `0.06` | Grip while the handbrake is held (low = easy to slide the back out). Range 0 to 1. |
| `reach_distance` | float | `16.0` | How close (pixels) a Drive Toward target must be to count as reached. |

---

## Use cases

Each example targets the `PhysicsCar` behavior on the named node (here, `Car`). Input actions belong in a per-frame loop; triggers get their own event.

### 1. Keyboard driving

The classic four-key car. Feed each held key to Simulate Control, and release everything with `stop` when nothing is pressed.

```
Every tick
  Condition: Keyboard  Key "up" is down
    -> Car | PhysicsCar: Simulate Control  "up"
  Condition: Keyboard  Key "left" is down
    -> Car | PhysicsCar: Simulate Control  "left"
  Condition: Keyboard  Key "right" is down
    -> Car | PhysicsCar: Simulate Control  "right"
  Condition: Keyboard  Key "down" is down
    -> Car | PhysicsCar: Simulate Control  "down"
  Condition: Keyboard  no arrow key is down
    -> Car | PhysicsCar: Simulate Control  "stop"
```

### 2. Analog stick driving

A gamepad car should feel smooth, not four-directional. Set Throttle and Set Steer clamp to -1..1, so you pipe raw analog values straight in.

```
Every tick
  -> Car | PhysicsCar: Set Throttle  Input.get_action_strength("accelerate") - Input.get_action_strength("reverse")
  -> Car | PhysicsCar: Set Steer  Input.get_axis("steer_left", "steer_right")
```

A half-pressed trigger gives half throttle; a light stick tilt gives a gentle turn.

### 3. AI waypoint follow

Point the car at the next waypoint each frame with Drive Toward Position, and advance the path when it arrives.

```
Every tick
  -> Car | PhysicsCar: Drive Toward Position  Waypoint.global_position.x, Waypoint.global_position.y, 0.8, 1, 6

Car On Drive Target Reached
  -> advance Path to its next point
  -> set Waypoint to Path.current_point
```

Throttle 0.8 keeps it from overshooting tight corners; tolerance 6 lets it call a corner "close enough" and settle onto the next leg.

### 4. Chase car aiming at the player

A pursuer that reads the track. Compute the angle from the car to the player each frame and hand it to Drive Toward Angle.

```
Every tick
  -> Car | PhysicsCar: Drive Toward Angle  rad_to_deg((Player.global_position - Car.global_position).angle()), 1, 1, 5
```

The car turns to face the player and floors it. Lower `throttle_amount` for a lazier tail; widen `tolerance` if it fishtails while chasing.

### 5. Handbrake drifting

The handbrake is momentary - it only cuts grip for the frame you call it, so hold it by calling Enable Handbrake every frame the button is down. Spawn smoke on the drift trigger.

```
Every tick
  Condition: Keyboard  Key "space" is down
    -> Car | PhysicsCar: Enable Handbrake

Car On Drift Started
  -> spawn tyre-smoke at Car.global_position
```

Yanking the handbrake mid-corner breaks the rear loose, slip crosses `drift_threshold`, and On Drift Started fires.

### 6. An ice patch

Terrain is a grip multiplier. Cut grip hard when the car enters the ice zone, and Reset Surface when it leaves.

```
Car On Area Entered  "IcePatch"
  -> Car | PhysicsCar: Set Surface Grip  0.2

Car On Area Exited  "IcePatch"
  -> Car | PhysicsCar: Reset Surface
```

At 0.2 the car keeps most of its sideways momentum, so it slides through the corner instead of gripping it.

### 7. Mud that grabs and slows

Mud both loses grip and adds drag. Combine a lower Set Surface Grip with a Set Surface Resistance above 1.

```
Car On Area Entered  "Mud"
  -> Car | PhysicsCar: Set Surface Grip  0.45
  -> Car | PhysicsCar: Set Surface Resistance  2.5

Car On Area Exited  "Mud"
  -> Car | PhysicsCar: Reset Surface
```

Resistance 2.5 makes the mud sap speed while grip 0.45 lets the tail wander, so the car wallows the way it should.

### 8. A drift-score meter

Read Slip Angle live while drifting for a HUD needle, and bank Drift Duration into the score when the drift ends.

```
Every tick
  Condition: Car | PhysicsCar  Is Drifting
    -> set DriftMeter.value to Car | PhysicsCar: Slip Angle

Car On Drift Ended
  -> add Car | PhysicsCar: Drift Duration * 100 to Score
```

Drift Duration reports the final length inside On Drift Ended, so a longer slide banks more points.

### 9. A boost pad

Raise the speed cap at runtime with Set Max Speed and give the car full throttle, then drop it back when the boost times out.

```
Car On Area Entered  "BoostPad"
  -> Car | PhysicsCar: Set Max Speed  700
  -> Car | PhysicsCar: Set Throttle  1
  -> start Timer "boost"  1.5

On Timer  "boost"
  -> Car | PhysicsCar: Set Max Speed  400
```

The car surges to 700 for 1.5 seconds, then the cap returns to its normal 400.

### 10. Reversing detection

Show reverse lights and a beep whenever the car is actually moving backwards, using the Is Reversing condition.

```
Every tick
  Condition: Car | PhysicsCar  Is Reversing
    -> show ReverseLights
    -> play "reverse-beep" (looping)
  Condition: Car | PhysicsCar  [Is Reversing]  is false
    -> hide ReverseLights
```

Is Reversing reads the car's true motion, so it stays off while the car rolls forward even with the reverse key tapped.

### 11. A respawn

Teleport clears velocity and spin as well as position, which is exactly what a respawn wants - the car appears at the checkpoint sitting still.

```
Keyboard On "r" pressed
  -> Car | PhysicsCar: Teleport  Checkpoint.global_position.x, Checkpoint.global_position.y

Car On Drive Target Reached
  -> set Checkpoint to Waypoint.global_position
```

Because Teleport zeroes the body's linear and angular velocity, the car does not carry its old momentum into the respawn.

### 12. A crash sound scaled by impact

On Collided fires from the body's own physics contact. Read Collision Force inside it to scale the sound so a light tap is quiet and a wall slam is loud.

```
Car On Collided
  Condition: Car | PhysicsCar  Collision Force  >  200
    -> play "crash" at volume Car | PhysicsCar: Collision Force / 400
```

Collision Force is the approximate impact speed, so a 350-pixels-per-second hit is louder than a 220 one, and taps under 200 make no sound at all.

### 13. Reaching a patrol waypoint

On Drive Target Reached is the clean hook for "I got there" - use it to pick the next point and immediately steer at it, so a patrol never stalls.

```
Car On Drive Target Reached
  -> pick the next PatrolPoint in the loop
  -> Car | PhysicsCar: Drive Toward Position  PatrolPoint.global_position.x, PatrolPoint.global_position.y, 0.7, 1, 6
```

Set Reach Distance up front if you want the car to call a point reached from further out - handy for wide, fast patrol loops.

---

## Tips and common mistakes

- **The host must be a RigidBody2D, not a CharacterBody2D.** The whole pack drives Godot's rigid body with real forces and impulses. On a CharacterBody2D (or any other node) there is nothing to push and the car will not move. If it sits still, check the node type first.
- **Keep a CollisionShape2D on the body.** Without a collision shape the RigidBody2D has no physical presence: it will not collide, will not react to impacts, and On Collided will never fire. It is the most common reason a "car" does nothing.
- **Call input actions every frame, and pair Simulate Control with Stop.** Throttle, brake, and steer persist until you change them, so releasing a key means writing the release, not just stopping the press. When no direction key is down, call Simulate Control `stop` (or Stop) that frame, or the last steer value will hold and the car will circle on its own.
- **Enable Handbrake is momentary.** It only cuts grip for the single physics frame you call it in. To hold the handbrake, call Enable Handbrake every frame the button is down - one call is a flick, not a hold.
- **Drive Toward actions set steering and throttle each frame.** They do not latch. Call Drive Toward Angle or Drive Toward Position every frame you want the car steering at the target; call it once and the car steers for exactly one frame, then coasts.
- **If AI steering wobbles, raise the tolerance or lower max_steer.** A car that oscillates around its heading is overcorrecting. A wider `tolerance` lets it settle sooner, and a lower `max_steer` softens each correction so it eases in instead of sawing back and forth.
- **grip is the feel dial: near 1 is glued, near 0 is ice.** Start at the default and nudge it. High grip gives clean, kart-like cornering; low grip gives a loose, slidey car. If corners feel like the car is on rails or on a frozen lake, this is the knob.
- **Terrain multipliers stack until you reset them.** Set Surface Grip and Set Surface Resistance stay in effect after the car leaves the zone. Always pair the enter event with a Reset Surface on exit (or set the multiplier back to 1), or the car will drag the ice with it onto dry road.
- **Read Collision Force and Collision Angle inside On Collided.** They describe the latest impact and are meant to be read the moment the collision fires. Reading them on an unrelated tick gives you a stale value from whenever the last crash happened.
- **Drift Duration is the final length inside On Drift Ended.** During a drift it counts up; the moment the drift ends it holds the total for that event, which is what you want to bank into a score. Read it in On Drift Ended, not a frame later.
