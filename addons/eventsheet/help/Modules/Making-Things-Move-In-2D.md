# Making Things Move In 2D

Almost every 2D game is a stack of moving things: a character that runs and jumps, a bullet that flies,
a coin that bobs, a turret that turns, an enemy that walks a path. This guide covers the builtin verbs
that move a 2D node - by hand, by velocity, by physics impulse, or by one of the ready-made motions -
and the readouts that tell you where things are and how fast they are going.

These verbs are builtin. Each one compiles to the exact native Godot call it names, with no plugin
runtime in the output, so the emitted script is the code you would have written yourself.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Verb reference](#verb-reference)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Platformer characters** - gravity, a jump, acceleration and braking, a floor check.
- **Top-down movement** where you set velocity from an input axis and slide along walls.
- **Bullets and projectiles** moved by a plain position offset every frame.
- **Physics props** - crates kicked by an impulse, thrusters pushed by a force, spinning debris.
- **Turrets and homing enemies** that turn toward a target at a believable speed.
- **Asteroids-style screen wrap**, in one row.
- **Idle motion** - a floating pickup, a breathing menu icon, a satellite orbiting a player.
- **Knockback** that decays honestly instead of snapping back.
- **Coin magnets** that vacuum a whole group toward the player.
- **Pathfinding AI** driven by a NavigationAgent2D, from four rows.

## Core concepts

- **There are three ways to move a node, and mixing them fights.** Write `position` directly (Node2D),
  set `velocity` and call **Move And Slide** (CharacterBody2D), or apply impulses and forces
  (RigidBody2D). Pick one per node. A RigidBody2D whose `position` you also write every frame will
  fight its own physics.
- **Velocity is a plan, Move And Slide executes it.** On a CharacterBody2D nothing moves until
  **Move And Slide** runs. Set velocity in as many rows as you like, then slide once, at the end, under
  **Every Physics Tick**.
- **Multiply by delta or the game changes with the frame rate.** Anything you add per frame - a
  position offset, a gravity pull, an acceleration - needs `delta`. **Get Delta** gives you the value;
  the gravity and acceleration verbs already take a **Delta** parameter that defaults to `delta`.
- **Component verbs beat vector algebra.** **Set Velocity X** and **Set Velocity Y** let horizontal and
  vertical motion be authored separately, which is exactly how a platformer thinks: input drives X,
  gravity and jumping drive Y.
- **The ready-made motions carry their own state.** **Bob Up And Down**, **Orbit Around** and
  **Push Away From** keep what they need in node metadata, so dropping the row anywhere just works with
  no exported variable and no `_ready` wiring.
- **`{host.}` in a template is the behaviour seam.** On a plain CharacterBody2D sheet it is empty and
  the line reads `velocity.y += ...`. Inside a behaviour pack it resolves to the host, so the same verb
  drives the node the behaviour is attached to. It is byte-stable either way.
- **Node-scoped verbs know their class.** A verb registered for CharacterBody2D only appears where a
  CharacterBody2D is in scope. If a verb you expect is missing from the picker, the host class is
  usually why.

## Verb reference

On the canvas these read as sentences, with the parameter values drawn in bold:

- Set velocity X to **direction * 200.0**
- Apply gravity **980.0** (max fall **1000.0**)
- turn toward **$Player** at **180.0** deg/s
- pull group **"coins"** toward me within **96.0** px at **400.0**/s

### General Actions - moving a node directly

| Verb | What it does | Ships as |
|------|--------------|----------|
| Set Position | Places a 2D node at an exact **Position**. | `position = {pos}` |
| Move By | Shifts a 2D node by an **Offset** from where it is. | `position += {offset}` |
| Set Rotation (Degrees) | Sets a 2D node's rotation in **Degrees**. | `rotation_degrees = {degrees}` |
| Move And Slide | Moves the character body using its velocity and slides along walls. | `{host.}move_and_slide()` |
| Set Velocity | Sets the character's full movement **Velocity** to a Vector2. | `{host.}velocity = {vel}` |
| Apply Central Impulse | Gives a rigid body an instant push - a kick or an explosion. | `apply_central_impulse({impulse})` |
| Apply Central Force | Applies a continuous push each physics frame, like steady thrust. | `apply_central_force({force})` |
| Apply Torque Impulse | Gives a rigid body an instant spin. | `apply_torque_impulse({torque})` |

### Movement - the velocity toolkit (CharacterBody2D)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Set Velocity X | Sets only the horizontal speed, leaving vertical motion untouched. | `{host.}velocity.x = {x}` |
| Set Velocity Y | Sets only the vertical speed (negative moves upward). | `{host.}velocity.y = {y}` |
| Add To Velocity | Adds an **Amount** (a Vector2) to the current velocity - nudges, knockback, boosts. | `{host.}velocity += {delta_v}` |
| Apply Gravity | Adds constant downward acceleration each frame. | `{host.}velocity.y += {gravity} * {delta_t}` |
| Apply Gravity (with terminal velocity) | The same pull, but never faster than **Max fall speed**. | `{host.}velocity.y = minf({host.}velocity.y + {gravity} * {delta_t}, {max_fall})` |
| Accelerate Velocity X Toward | Eases horizontal speed toward a **Target speed** at a **Rate** per second. | `{host.}velocity.x = move_toward({host.}velocity.x, {target_speed}, {rate} * {delta_t})` |
| Accelerate Velocity Y Toward | The same easing on the vertical axis. | `{host.}velocity.y = move_toward({host.}velocity.y, {target_speed}, {rate} * {delta_t})` |
| Velocity X | The current horizontal speed in pixels per second. | `{host.}velocity.x` |
| Velocity Y | The current vertical speed in pixels per second. | `{host.}velocity.y` |

### General Conditions

| Verb | What it does | Ships as |
|------|--------------|----------|
| Is On Floor | True when this 2D character body is standing on the ground. | `{host.}is_on_floor()` |

### Movement - the ready-made motions (Node2D)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Turn Toward | Aims this node at a **Target** node, turning at **Turn Speed** degrees per second. | `rotation = rotate_toward(rotation, ({target}.global_position - global_position).angle(), deg_to_rad(maxf({degrees_per_second}, 0.0)) * get_process_delta_time())` |
| Wrap Inside The Screen | The Asteroids rule: leave one edge, come back on the other. | a `{uid}` local holding `get_viewport_rect().size`, then a `wrapf` on each axis of `position` |
| Bob Up And Down | Floats the node **Height** pixels around its resting point, one full bob every **Period** seconds. | the resting `position.y` remembered in node metadata, plus a `sin` ride on top of it |
| Push Away From | Sets a knockback impulse away from a **Away From** node at a **Strength**. | `set_meta(&"__ef_push", (global_position - {source}.global_position).normalized() * maxf({strength}, 0.0))` |
| Apply Pushes | Spends that impulse and decays it by **Friction**, frame-rate independently. | a `{uid}` local reading the `__ef_push` meta, moving `position`, then writing back the `exp`-decayed remainder |
| Pull Group Toward | Pulls every member of a **Group** within **Within** pixels toward this node at **Speed**. | a `for` over `get_tree().get_nodes_in_group({group})` with a `move_toward` on each Node2D in range |
| Orbit Around | Circles this node around an **Around** node at a **Radius**, at **Speed** degrees per second. | the angle kept in node metadata, then `global_position = {center}.global_position + Vector2(cos(a), sin(a)) * radius` |
| Is Within Distance (of a node) | True when another node is closer than **Distance** pixels. | `global_position.distance_to({other}.global_position) <= maxf({distance}, 0.0)` |
| Is Within Distance (choose metric) | The same test with a **Measured As** dropdown: straight line, horizontal only, vertical only, grid steps, king moves. | an inline five-entry array of the measures, indexed by the chosen metric, compared against the distance |

### General Expressions - the readouts

| Verb | What it does | Ships as |
|------|--------------|----------|
| Get Position | The node's 2D position as a Vector2. | `position` |
| Get Velocity | The character body's current movement velocity. | `velocity` |
| Get Linear Velocity | The rigid body's current linear velocity from physics. | `linear_velocity` |
| Get Delta | The seconds since the last frame. | `delta` |

### Math & Random - two Node2D readouts worth knowing

| Verb | What it does | Ships as |
|------|--------------|----------|
| Distance To | The distance in pixels from this node to a **To** position. | `position.distance_to({to})` |
| Angle Toward | The angle from this node toward a **To** position. | `position.angle_to_point({to})` |

### Navigation (NavigationAgent2D)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Find Path To | Tells the agent to pathfind toward a **Target** world position. | `target_position = {position}` |
| Has Arrived | True once the agent has reached its destination. | `is_navigation_finished()` |
| Next Path Position | The next point along the path the agent should move toward. | `get_next_path_position()` |
| Distance To Target | How far the agent still is from its navigation target. | `distance_to_target()` |

## Use cases

**1. Teleport something to an exact spot.**

```
On respawn
  -> Set Position   Vector2(64, 300)
```

**2. Move a bullet by hand, every frame, frame-rate independently.**

```
Every Frame
  -> Move By   Vector2(600, 0) * delta
```

```gdscript
position += Vector2(600, 0) * delta
```

Drop the `* delta` and the bullet travels six hundred pixels per FRAME instead of per second, which is
different on every machine.

**3. The smallest complete platformer body.**

```
Every Physics Tick
  -> Apply Gravity   980.0
  -> Set Velocity X   Input.get_axis(&"ui_left", &"ui_right") * 200.0
  -> Move And Slide
```

Three rows: pull down, steer sideways, then execute. **Move And Slide** goes last, once.

**4. A jump that only works on the ground.**

```
Every Physics Tick
  Condition: Is On Floor
  Condition: On Action Just Pressed   "ui_accept"
    -> Set Velocity Y   -420.0
```

Negative Y is up. **Set Velocity Y** leaves the horizontal speed alone, so you keep your run momentum
through the jump.

**5. Cap the falling speed so a long drop stays readable.**

```
Every Physics Tick
  -> Apply Gravity (with terminal velocity)   gravity = 980.0, max fall = 700.0
```

**6. Acceleration and braking instead of instant top speed.**

```
Every Physics Tick
  -> Read Input Axis Into   direction  ( "ui_left" / "ui_right" )
  -> Accelerate Velocity X Toward   target speed = direction * 200.0, rate = 1500.0
  -> Move And Slide
```

When the player lets go, the target speed becomes 0 and the same row brakes at the same rate. One
number tunes both.

**7. Knockback, as the two rows it really is.**

```
On Body Entered ( body )
  -> Push Away From   away from = body, strength = 300.0

Every Frame
  -> Apply Pushes   friction = 8.0
```

The hit sets the impulse; the per-frame row spends it and decays it. The decay is the exponential
form, so it feels the same at 30 and 144 fps.

**8. Kick a crate with physics.**

```
On Body Entered ( body )
  -> Apply Central Impulse   Vector2(400, -200)
  -> Apply Torque Impulse   3.0
```

Impulses are for RigidBody2D. Do not also write its `position` - that fights the solver.

**9. Steady thrust on a physics ship.**

```
Every Physics Tick
  Condition: Is Action Pressed   "ui_up"
    -> Apply Central Force   Vector2(0, -600)
```

Forces are per-physics-frame and belong under **Every Physics Tick**; an impulse belongs on the event
that happened once.

**10. A turret that tracks the player at a real speed.**

```
Every Frame
  -> Turn Toward   target = $Player, turn speed = 180.0
```

For an instant snap, give it a huge turn speed rather than reaching for a different verb.

**11. Asteroids wrap.**

```
Every Frame
  -> Wrap Inside The Screen
```

**12. A pickup that hovers.**

```
Every Frame
  -> Bob Up And Down   height = 6.0, period = 2.0
```

The resting height is whatever the node had the first time the row ran, so the coin bobs around where
you placed it in the editor.

**13. A shield satellite.**

```
Every Frame
  -> Orbit Around   around = $Player, radius = 40.0, speed = 90.0
```

A negative **Speed** orbits the other way. The angle is kept in metadata rather than derived from the
clock, so changing the speed mid-run does not teleport the satellite around the ring.

**14. The coin magnet.**

```
Every Frame
  -> Pull Group Toward   group = "coins", within = 96.0, speed = 400.0
```

**15. A prompt that only shows when you are close enough.**

```
Every Frame
  Condition: Is Within Distance (of a node)   of = $Chest, distance = 48.0
    -> Show
```

**16. A platformer leash that only cares about horizontal distance.**

```
Every Frame
  Condition: Is Within Distance (choose metric)   of = $Player, distance = 300.0, measured as = Horizontal only
    -> Set Variable  chasing = true
```

The **Measured As** dropdown is what makes one condition fit a platformer, a roguelike (Grid steps) and
a strategy game (King moves) alike.

**17. Chase the player with real pathfinding.**

```
Every Physics Tick
  -> Find Path To   $Player.global_position
  Condition: Has Arrived  (inverted)
    -> Set Velocity   (Next Path Position() - global_position).normalized() * 150.0
    -> Move And Slide
```

**Find Path To** only sets the destination. The agent's **Next Path Position** is the point you
actually steer toward each tick.

**18. Stop when you get there.**

```
Every Physics Tick
  Condition: Has Arrived
    -> Set Velocity   Vector2(0, 0)
    -> Play Animation   "idle"
```

**19. A speed readout on the HUD.**

```
Every Frame
  -> Set Text   str(int(Get Velocity().length())) + " px/s"
```

**Get Velocity** hands back the whole Vector2; **Velocity X** and **Velocity Y** hand back one axis
each when that is all you need.

**20. Aim a sprite along the direction it is moving.**

```
Every Frame
  Condition: Expression Is True   velocity.length() > 1.0
    -> Set Rotation (Degrees)   rad_to_deg(velocity.angle())
```

### Other use cases

**Conveyor belts.** An Every Physics Tick event that adds a fixed Vector2 to velocity with Add To Velocity while a body is inside the belt's Area gives push without changing how the body is otherwise controlled.

**Dash with a cooldown.** Set Velocity X to a big number on the press, guarded by Cooldown Is Ready, and let Accelerate Velocity X Toward bleed it back down to walking speed on its own.

**Floating menu art.** Bob Up And Down on a title-screen icon costs one row and needs no AnimationPlayer, which keeps menu scenes free of animation assets.

**Boss arena leash.** Is Within Distance (choose metric) with Grid steps against the arena centre keeps a boss inside its room without invisible collision walls.

**Homing missiles.** Turn Toward for the steering plus Move By along the missile's own facing gives arcing pursuit from two rows, with the turn speed as the single difficulty dial.

## Tips and common mistakes

- **Nothing moves until Move And Slide runs.** Setting velocity is not movement on a CharacterBody2D.
  Call it once, last, under **Every Physics Tick**.
- **Do not mix movement styles on one node.** Position writes on a RigidBody2D, or impulses on a
  CharacterBody2D, produce motion that looks broken and is hard to debug. One node, one style.
- **Negative Y is up.** **Set Velocity Y** with `-420.0` jumps; `420.0` drives into the floor.
- **The Delta parameter expects a per-frame trigger.** **Apply Gravity**, both **Accelerate Velocity**
  verbs and the gravity-with-terminal form default their **Delta** to `delta`, which only exists inside
  **Every Frame** and **Every Physics Tick**. Under **On Ready** or a signal trigger, that default does
  not resolve to anything.
- **Physics belongs on the physics tick.** Gravity, velocity and **Apply Central Force** under
  **Every Frame** will jitter, because the physics step and the render frame do not line up.
- **Push Away From on its own does nothing visible.** It only records the impulse. **Apply Pushes**
  under a per-frame trigger is the half that moves the node, and both rows must be on the same node.
- **The ready-made motions want a per-frame trigger.** **Bob Up And Down**, **Orbit Around**,
  **Pull Group Toward**, **Turn Toward** and **Apply Pushes** all advance a little each call. Under a
  one-shot trigger they run once and appear to do nothing.
- **Wrap Inside The Screen and Apply Pushes are self-verbs.** Their templates open with a `var` line,
  which is what keeps them from gaining an "On node" target. They act on the node the sheet is on.
- **Turn Toward and the distance conditions need a node, not a position.** They read
  `{target}.global_position`, so handing them a raw Vector2 will not compile. The point-to-point
  distance lives with the Vector verbs instead.
- **Pull Group Toward skips non-Node2D members.** The row tests each member before moving it, so a
  plain Node accidentally added to the group is ignored rather than crashing - which also means a
  missing coin is usually a coin that is not a Node2D.
- **Find Path To needs baked navigation.** With no NavigationRegion2D in the scene the agent has
  nowhere to path, **Has Arrived** answers immediately, and the enemy stands still.
- **Set Rotation (Degrees) takes degrees, `velocity.angle()` returns radians.** Convert one way or the
  other; **Radians To Degrees** is the verb for it.
