# Working With Vectors And Directions

**Working With Vectors And Directions** is the builtin **Variables: Vector** vocabulary plus the spatial
family that grew out of it: verbs that let a sheet build, measure, aim, turn, blend and cap positions and
directions without typing a single `.x` or writing the distance formula out by hand, and then two
families that put those directions to work - **screen and world** conversions in both directions, and the
verbs that CONSUME a surface normal (bounce, slide, depenetrate, face along motion, safe Look At and
lead-aim).

A Vector2 is a pair (a position, a velocity, a direction, a size); a Vector3 is a triple. Godot's own
methods already know how to measure and aim with them - this vocabulary just names those methods as
sentences, so *the distance between the player and the exit* is one cell instead of a square root.

The last two verbs, **Part Of** and **Set Part Of**, are the odd ones out and the ones you will
reach for most: they read and write ONE named component of a pair, a triple, a colour OR a record,
which is why they cover "zero the vertical speed on landing" and "fade only the see-through part of a
tint" with the same row.

Everything here compiles to plain Godot. There is no runtime and no plugin reference in the emitted
code: *the length of `velocity`* ships as `velocity.length()`.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Verb reference](#verb-reference)
4. [The named parts](#the-named-parts)
5. [Use cases](#use-cases)
6. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Aiming** - a bullet, a homing missile, an enemy that walks toward the player.
- **Range checks** - "is the player within 200 pixels", without a hand-written square root.
- **Speed limits** - cap a velocity's magnitude while keeping its direction.
- **Diagonal movement that is not faster** - normalize the input before scaling it.
- **Facing** - turn a sprite to match the direction it is travelling.
- **Field-of-view and "is it in front of me"** tests, from one dot product.
- **Smooth camera and follow motion** between two points.
- **Landing and wall logic** - zero one axis of a velocity and leave the other untouched.
- **Flattening a 3D direction** to the ground plane before using it.
- **Spread and recoil** - rotate a direction by a random angle.
- **Saved positions** that arrive as a `{"x": ..., "y": ...}` record and need one field read.

## Core concepts

- **These are expressions, except one.** Twelve of the thirteen are EXPRESSIONS - values you drop
  into a cell. Only **Set Part Of** is an action.
- **Nothing mutates.** `Normalized(velocity)` does not change `velocity`; it hands back a new value.
  Assign the result somewhere. Set Part Of is the only verb here that writes.
- **A direction is a vector of length 1.** Normalized and Direction To both produce one. Multiply it
  by a speed to get a velocity; that is the whole idiom.
- **Distance Between and Direction To are the two halves of "aim at".** One gives you how far, the
  other which way, from the same two points.
- **Angles here are RADIANS.** Vector Angle returns radians and Rotated takes radians. Godot's
  `rotation` property is radians too; `rotation_degrees` is not. The builtin degree-based trig verbs
  live in the general Math vocabulary.
- **Dot Product answers "how aligned".** For two unit vectors it is 1 when they point the same way, 0
  when they are at right angles, and -1 when they are opposed. That single number replaces most
  "is it in front of me" arithmetic.
- **Part Of works on more than vectors.** It emits a subscript with a quoted key, which Godot
  resolves as a component on Vector2, Vector3 and Color, and as a field on a Dictionary. One verb
  therefore reads `velocity["y"]`, `modulate["a"]` and `saved_position["x"]`.
- **Set Part Of targets a PROPERTY, not only a sheet variable.** Its first cell is an editable
  autocomplete over the host class, because the headline targets are a node's own members
  (`velocity`, `modulate`, `position`) that a variables dropdown cannot name at all.

## Verb reference

On the canvas these read as sentences with the values drawn in place: *the distance between
`position` and `target`*, *the Y (up / down) part of `velocity`*, *set the Y (up / down) part of
`velocity` to `0.0`*.

### Variables: Vector (build)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Make Vector2 | Builds a Vector2 from separate x and y numbers, for positions or directions. | `Vector2({x}, {y})` |
| Make Vector3 | Builds a 3D point or direction from X, Y and Z numbers. | `Vector3({x}, {y}, {z})` |

### Variables: Vector (measure)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Vector Length | How long a vector is - a velocity's speed, a displacement's size. | `{vector}.length()` |
| Distance Between | The straight-line distance between two points. | `{a}.distance_to({b})` |
| Vector Angle | A 2D vector's angle in radians, useful for facing direction. | `{vector}.angle()` |
| Dot Product | How aligned two vectors are: 1 same way, 0 perpendicular, -1 opposed (for unit vectors). | `{a}.dot({b})` |

### Variables: Vector (aim and shape)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Normalized | The vector shrunk to length 1, keeping only its direction. | `{vector}.normalized()` |
| Direction To | A unit vector pointing from one point toward another - the aiming verb. | `{a}.direction_to({b})` |
| Rotated | The vector turned by an angle in radians. | `{vector}.rotated({radians})` |
| Vector Lerp | A point blended between two vectors, great for smooth movement. | `{a}.lerp({b}, {weight})` |
| Clamp Length | The vector capped to a maximum magnitude, e.g. a speed limit. | `{vector}.limit_length({max_length})` |

### Variables: Vector (named parts)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Part Of | One named piece of a pair, a triple, a colour or a record - read as a sentence instead of a typed-in `.y`. | `({value})[{part}]` |
| Set Part Of | ACTION: changes one named part and leaves the rest alone. Writing a part a record does not have yet ADDS it. | `{var_name}[{part}] = {value}` |

### Screen and world (Math & Random)

The camera's own transform, named as sentences. **World Point To Screen** and **Screen Point To World**
are exact opposites, so the pair round-trips; everything else here is built on one of the two.

| Verb | What it does | Ships as |
|------|--------------|----------|
| World Point To Screen | Where a world point sits on screen right now, camera zoom and scroll included. | `(get_viewport().get_canvas_transform() * {world_point})` |
| Screen Point To World | The world position under a screen pixel - the exact opposite. | `(get_viewport().get_canvas_transform().affine_inverse() * {screen_point})` |
| Project To Screen (3D) | Where a 3D world point lands on screen. Reads 0,0 while there is no camera. | `(get_viewport().get_camera_3d().unproject_position({world_point}) if get_viewport().get_camera_3d() != null else Vector2.ZERO)` |
| Is Point On Screen | **Condition.** True while a world point is inside the visible view, plus a margin of slack. | `get_viewport().get_visible_rect().grow({margin}).has_point(get_viewport().get_canvas_transform() * {world_point})` |
| Is Behind Camera (3D) | **Condition.** True when a 3D point sits behind the camera plane, where its screen position is a mirrored lie. | `(get_viewport().get_camera_3d() == null or get_viewport().get_camera_3d().is_position_behind({world_point}))` |
| Screen Edge Position For | A screen position that follows a target while it is visible and sticks to the edge once it is not. | `((get_viewport().get_canvas_transform() * {world_point}).clamp(Vector2({margin}, {margin}), get_viewport().get_visible_rect().size - Vector2({margin}, {margin})))` |
| Marker Angle Toward | The rotation in degrees an on-screen arrow needs to point from the middle of the view at a world thing. | `rad_to_deg(((get_viewport().get_canvas_transform() * {world_point}) - get_viewport().get_visible_rect().size * 0.5).angle())` |
| Visible World Rect | The rectangle of the world the camera can currently see, in world coordinates. | `(get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect())` |
| Wrap Inside The View (3D) | **Action.** The Asteroids rule in 3D: off one side of the view, back on the other, at the same distance from the camera. | a camera-guarded `wrapf` of the projected position |

### Bounce, slide and aim (Movement)

The verbs that CONSUME a surface normal. Every hit trigger and every cast in the plugin hands one back -
**Ray Result Normal**, **Wall Normal**, **Floor Normal**, the Bullet pack's **On Bullet Hit** - and these
are the three lines a developer writes next.

| Verb | What it does | Ships as |
|------|--------------|----------|
| Bounce Off Surface | The velocity a moving thing has AFTER hitting a surface. 1 keeps all the speed, 0 is a dead stop. | `({velocity}.bounce({normal}.normalized()) * {bounciness})` |
| Slide Along Surface | The velocity left once the part pushing INTO a surface is removed - the wall slide. | `({velocity}.slide({normal}.normalized()))` |
| Angle Reflected | The heading in degrees a thing travels on after bouncing - feed it straight back to Set Angle Of Motion. | `rad_to_deg(Vector2.RIGHT.rotated(deg_to_rad({degrees})).bounce({normal}.normalized()).angle())` |
| Push Out Of Surface | A position just clear of a surface instead of exactly on it. | `({point} + {normal}.normalized() * {distance})` |
| Face Along Velocity | **Action.** Turns this node to point the way it is travelling, and leaves it alone while it is stopped. | `if {velocity}.length_squared() > 0.0001:` then `rotation = {velocity}.angle()` |
| Look At (safe up) | **Action.** Faces a 3D point without the crash plain Look At has when the target is directly overhead. | a guarded `look_at` that swaps the up vector |
| Look At (flat) | **Action.** Faces a 3D point around the up axis only, so a character never tips over to stare at feet. | a guarded `look_at` on a height-flattened target |
| Aim At Moving Target | Where to aim so a shot MEETS a moving target instead of trailing it. | `({target_position} + {target_velocity} * ({target_position}.distance_to({shooter_position}) / maxf({projectile_speed}, 0.001)) if {projectile_speed} > {target_velocity}.length() else {target_position})` |
| Launch Angle For Arc | The angle in degrees to fire something so it ARCS onto a target. Picks the flatter of the two arcs. | a discriminant-guarded `atan2` |
| Time To Reach | How many seconds something moving at a steady speed needs to cover a distance. | `({from_position}.distance_to({to_position}) / maxf({speed}, 0.001))` |


## The named parts

Part Of and Set Part Of share one dropdown. The row draws the readable label and emits the key:

| Label in the row | Emitted key | Lives on |
|------------------|-------------|----------|
| X (left / right) | `"x"` | Vector2, Vector3, a record with an `x` field |
| Y (up / down) | `"y"` | Vector2, Vector3, a record with a `y` field |
| Z (forward / back) | `"z"` | Vector3, a record with a `z` field |
| Red | `"r"` | Color |
| Green | `"g"` | Color |
| Blue | `"b"` | Color |
| Alpha (see-through) | `"a"` | Color |

Pick a part the value actually has. A record that might be MISSING the field is the builtin Get Key
(with default) verb's job instead, because that one takes a fallback and Part Of does not.

One honest consequence of the subscript form: `velocity["y"] = 0.0` is character-for-character what
the Set Key verb emits, so reopening a `.gd`-backed sheet lifts the row back as Set Key rather than
as Set Part Of. The code is byte-identical either way and the lossless round-trip is untouched - what
is lost on a reopen is the sentence. That is the deliberate trade for never mis-labelling somebody
else's `save["gold"] = 5`.

## Use cases

**1. Aim a projectile at the player.**

```
On enemy fires
  -> set bullet_direction = Direction To(self.position, player.position)
  -> set bullet.velocity = bullet_direction * 600.0
```

Direction To already returns length 1, so multiplying by the speed is the whole calculation.

**2. A range check with no square root written by hand.**

```
Every tick
  Condition: Distance Between(self.position, player.position) < 200.0
    -> start chasing
```

**3. Diagonal movement that is not faster than straight movement.**

```
Every tick
  -> set move_input = Make Vector2(Move Axis("move_left", "move_right"), Move Axis("move_up", "move_down"))
  -> set velocity = Normalized(move_input) * speed
```

Without Normalized, holding two directions at once gives a vector of length 1.41 and the player
sprints diagonally.

**4. A speed limit that keeps the direction.**

```
Every tick
  -> set velocity = Clamp Length(velocity, max_speed)
```

Clamp Length only shortens; a vector already inside the limit comes back untouched.

**5. Show the speed on a HUD.**

```
Every tick
  -> set SpeedLabel text = To Text(int(Vector Length(velocity)))
```

**6. Turn a sprite to face where it is going.**

```
Every tick
  Condition: Vector Length(velocity) > 1.0
    -> set self.rotation = Vector Angle(velocity)
```

`rotation` is radians, which is exactly what Vector Angle returns. Assigning to `rotation_degrees`
here would spin the sprite wildly.

**7. Shotgun spread from one direction.**

```
On fire pressed
  Repeat 5 times
    -> spawn a pellet with velocity = Rotated(aim_direction, randf_range(-0.15, 0.15)) * 900.0
```

Rotated takes radians, so 0.15 is roughly 8.6 degrees either side.

**8. Is the target in front of me?**

```
Every tick
  Condition: Dot Product(Normalized(facing), Direction To(self.position, target.position)) > 0.0
    -> the target is in front
```

Both arguments are unit vectors, so the dot product is the cosine of the angle between them.

**9. A cone of vision, not just a hemisphere.**

```
Every tick
  Condition: Dot Product(Normalized(facing), Direction To(self.position, player.position)) > 0.7
    -> the player is inside a roughly 90 degree cone
```

0.7 is about `cos(45 degrees)`, so the test covers 45 degrees either side. Raise the number to
narrow the cone.

**10. A camera that eases toward its target.**

```
Every tick
  -> set Camera.position = Vector Lerp(Camera.position, player.position, 0.1)
```

For a frame-rate independent version, the builtin Move Toward (smooth) action does the same easing
with a per-second speed instead of a per-frame weight.

**11. Zero the vertical speed on landing and keep the horizontal.**

```
On landed
  -> Set Part Of  velocity, Y (up / down), 0.0
```

It emits:

```gdscript
velocity["y"] = 0.0
```

This is the row that Part Of and Set Part Of exist for: touching one component without rebuilding the
whole vector from its pieces.

**12. The jump-or-fall test.**

```
Every tick
  Condition: Part Of(velocity, Y (up / down)) < 0.0
    -> play the rising animation
  Else
    -> play the falling animation
```

**13. Flatten a 3D direction to the ground plane.**

```
On chase step
  -> set chase_direction = Direction To(self.global_position, target.global_position)
  -> Set Part Of  chase_direction, Y (up / down), 0.0
  -> set chase_direction = Normalized(chase_direction)
```

Zeroing the Y and re-normalizing is how a ground enemy stops trying to walk upwards at a flying
target.

**14. Fade only the see-through part of a tint.**

```
Every tick
  -> Set Part Of  modulate, Alpha (see-through), fade_value
```

The same verb reaches a Color's named parts, so a fade needs no colour arithmetic at all.

**15. Read one field of a saved position record.**

```
On save loaded
  -> set spawn_x = Part Of(saved["spawn"], X (left / right))
```

A record saved as `{"x": 120, "y": 64}` reads with the same verb a Vector2 does, so a loaded position
needs no special case.

**16. Build a target point out of two loose numbers.**

```
On waypoint reached
  -> set next_target = Make Vector2(waypoint_x, waypoint_y)
```

**17. A 3D spawn point above the player.**

```
On drop pod called
  -> spawn "res://pod.tscn" at player.global_position + Make Vector3(0.0, 40.0, 0.0)
```

**18. Knockback away from the hit.**

```
On hit
  -> set velocity = Direction To(attacker.position, self.position) * knockback_force
```

Swapping the two arguments of Direction To is the whole difference between attract and repel.

**19. Nearest of two exits.**

```
On escape pressed
  Condition: Distance Between(player.position, ExitA.position) < Distance Between(player.position, ExitB.position)
    -> route the player to ExitA
  Else
    -> route the player to ExitB
```

**20. A nameplate that rides a moving boss.**

The whole reason World Point To Screen exists: the label lives on a CanvasLayer (so it is not blurred by
the camera's zoom) and is placed in screen coordinates every frame.

```gdscript
extends Node


func _process(delta: float) -> void:
	$BossNameplate.position = (get_viewport().get_canvas_transform() * $Boss.global_position) + Vector2(0, -70)
```

**21. An off-screen objective arrow.**

Three verbs and one condition: show the arrow only when the target is NOT visible, park it on the edge,
and turn it to point outward.

```gdscript
extends Node


func _process(delta: float) -> void:
	if not get_viewport().get_visible_rect().grow(0.0).has_point(get_viewport().get_canvas_transform() * $Enemy.global_position):
		$OffscreenArrow.show()
		$OffscreenArrow.position = ((get_viewport().get_canvas_transform() * $Enemy.global_position).clamp(Vector2(48.0, 48.0), get_viewport().get_visible_rect().size - Vector2(48.0, 48.0)))
		$OffscreenArrow.rotation_degrees = rad_to_deg(((get_viewport().get_canvas_transform() * $Enemy.global_position) - get_viewport().get_visible_rect().size * 0.5).angle())
```

**22. A nameplate over a 3D character.**

Check **Is Behind Camera (3D)** first. A point behind you still projects to a perfectly ordinary-looking
screen position - a mirrored one - which is why a 3D marker without this guard drifts around the screen
whenever you turn away from it.

```gdscript
extends Node


func _process(delta: float) -> void:
	if (get_viewport().get_camera_3d() == null or get_viewport().get_camera_3d().is_position_behind($Objective.global_position)):
		$WaypointPin.hide()
	else:
		$WaypointPin.show()
		$WaypointPin.position = (get_viewport().get_camera_3d().unproject_position($Objective.global_position) if get_viewport().get_camera_3d() != null else Vector2.ZERO)
```

**23. Click to place a tower.**

The mouse arrives in screen pixels and the world is somewhere else entirely once the camera has scrolled.
Screen Point To World is the whole conversion.

```gdscript
extends Node2D


func _on_click(at: Vector2) -> void:
	$BuildGhost.global_position = (get_viewport().get_canvas_transform().affine_inverse() * at)
```

**24. Spawn only where the player cannot watch it happen.**

```gdscript
extends Node2D


func _on_spawn_timer() -> void:
	if not get_viewport().get_visible_rect().grow(0.0).has_point(get_viewport().get_canvas_transform() * global_position):
		spawn_enemy()
```

**25. Cull decorations the camera has left behind.**

Is Point On Screen with a generous margin is the cheap half of a culling pass: things well outside the
view stop animating, and the margin keeps anything from popping at the edge.

```gdscript
extends Node2D


func _process(delta: float) -> void:
	set_process(get_viewport().get_visible_rect().grow(200.0).has_point(get_viewport().get_canvas_transform() * global_position))
```

**26. Sizing a minimap to what the camera can see.**

Visible World Rect is the same rectangle **Bound To** clamps against and **Wrap** wraps inside, only
readable - so a minimap viewport box, a spawn area or a fog-reveal circle can all be sized from it.

```gdscript
extends Node2D


func _process(delta: float) -> void:
	$MinimapBox.size = (get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()).size * 0.1
```

**27. A wrap-around 3D arena.**

The 3D twin of **Wrap Inside The Screen**: leave the right of the view, come back on the left, at the
same distance from the camera. One row under a per-frame trigger, with no bounds to maintain.

```
Every Frame
  -> Movement: Wrap Inside The View (3D)
```

**28. A bullet that ricochets instead of dying.**

The Bullet pack's **On Bullet Hit** already carries `collider`, `point` and `normal`. These two verbs are
the missing middle: reflect the heading, and park the bullet clear of the wall so the next frame's cast
does not start inside it.

```
On Bullet Hit  ( collider, point, normal )
  -> Bullet: Set Angle Of Motion  Angle Reflected ( Angle Of Motion, normal )
  -> Nodes: Set Position  Push Out Of Surface ( point, normal, 2 )
```

**29. A ball that loses energy on every bounce.**

```gdscript
extends CharacterBody2D


func _on_hit_wall(normal: Vector2) -> void:
	velocity = (velocity.bounce(normal.normalized()) * 0.65)
```

**30. Wall slide instead of sticking to the wall.**

Slide Along Surface keeps the part of the velocity that runs ALONG the wall, which is the difference
between a controller that grinds to a halt on a corner and one that skims past it.

```gdscript
extends CharacterBody2D


func _physics_process(delta: float) -> void:
	if is_on_wall():
		velocity = (velocity.slide(get_wall_normal().normalized()))
```

**31. Spawning something clear of a wall.**

A thing spawned exactly on a surface is a thing spawned INSIDE it as far as the next frame is concerned,
because a ray that starts on a shape does not report that shape.

```gdscript
extends Node2D


func _on_impact(point: Vector2, normal: Vector2) -> void:
	$Decal.global_position = (point + normal.normalized() * 2.0)
```

**32. An arrow that points where it is flying.**

Face Along Velocity leaves a stopped node alone, which is the whole reason to use it instead of assigning
the angle yourself: an arrow that lands does not snap back to facing right.

```
Every Frame
  -> Movement: Face Along Velocity  Get Velocity
```

**33. A turret that shoots where you WILL be.**

```gdscript
extends Node2D


func _on_fire() -> void:
	look_at(($Player.global_position + $Player.velocity * ($Player.global_position.distance_to(global_position) / maxf(900.0, 0.001)) if 900.0 > $Player.velocity.length() else $Player.global_position))
```

**34. A mortar that arcs onto a target.**

Launch Angle For Arc solves the angle from the distance, the height difference, the shell speed and
gravity - the four numbers you actually have. It picks the flatter of the two arcs; for the lobbed one,
subtract the answer from 90.

```gdscript
extends Node2D


func _on_fire() -> void:
	var pitch: float = (rad_to_deg(atan2(600.0 * 600.0 - sqrt(maxf(600.0 * 600.0 * 600.0 * 600.0 - 980.0 * (980.0 * 300.0 * 300.0 + 2.0 * 0.0 * 600.0 * 600.0), 0.0)), 980.0 * 300.0)) if 300.0 != 0.0 and 980.0 != 0.0 else 45.0)
	print("firing at %.1f degrees" % pitch)
```

**35. A warning that lands before the missile does.**

```gdscript
extends Node2D


func _on_launched() -> void:
	var seconds: float = (global_position.distance_to($Target.global_position) / maxf(300.0, 0.001))
	print("impact in %.1f seconds" % seconds)
```

**36. A 3D camera that can look straight up without crashing.**

This is a crash fix, not a nicety. Plain `look_at` throws the moment the target sits directly overhead or
underfoot, because the direction and the up vector are then parallel and no rotation can be built from
them. **Look At (safe up)** swaps the up vector at exactly that moment, and does nothing at all when the
target is where the node already stands.

```
Every Frame
  -> Movement: Look At (safe up)  Target.global_position
```

**37. An NPC that turns to face you without tipping over.**

```
On Player Nearby
  -> Movement: Look At (flat)  Player.global_position
```

**38. A radar blip that never leaves the dial.**

Screen Edge Position For with a large margin keeps every contact inside a ring rather than a rectangle's
worth of screen, and Marker Angle Toward turns each blip to point outward.

```gdscript
extends Node


func _process(delta: float) -> void:
	$RadarBlip.position = ((get_viewport().get_canvas_transform() * $Contact.global_position).clamp(Vector2(120.0, 120.0), get_viewport().get_visible_rect().size - Vector2(120.0, 120.0)))
```

### Other use cases

**Orbiting satellite.** Rotate a fixed offset vector a little every tick with Rotated and add it to
the parent's position, and a moon circles a planet with no trigonometry in the sheet.

**Steering blend.** Vector Lerp between a "chase" direction and a "flee" direction with a weight
driven by health gives a coward enemy that changes its mind smoothly rather than snapping.

**Drift and grip.** Dot Product between the car's facing and its velocity tells you how sideways it
is travelling, which is exactly the number a skid sound and a tyre-mark trail want.

**Minimap arrow.** Direction To from the player to the objective, fed through Vector Angle, points an
off-screen marker with two cells and no branching.

**Aim assist snap.** Clamp Length the difference between the raw aim vector and the ideal one, then
add it back, so the correction can never exceed the assist budget you set.

## Tips and common mistakes

- **Radians, not degrees.** Vector Angle returns radians and Rotated takes radians. Assigning a
  radian angle to `rotation_degrees` (or feeding degrees to Rotated) is the single most common bug
  here. Godot's `rotation` property is the radian one.
- **Normalizing a zero vector gives a zero vector**, not an error and not a direction. A row that
  reads "face where I am going" needs a speed check first, or the sprite snaps to angle 0 the moment
  the player stops.
- **Direction To between two identical points is also zero**, for the same reason.
- **Clamp Length only shortens.** It will not lengthen a vector to the maximum; a slow vector stays
  slow. Normalized-times-speed is the verb pair for "always exactly this fast".
- **Vector Angle is Vector2 only.** A Vector3 has no single angle, so there is no 3D version of it.
- **Dot Product is only "the cosine of the angle" for UNIT vectors.** With raw velocities the number
  is scaled by both lengths, so a cone test on un-normalized inputs silently changes threshold as the
  speed changes. Normalize both sides.
- **Mixing Vector2 and Vector3 in one verb errors.** Distance Between, Dot Product and Vector Lerp
  all need both arguments to be the same kind of vector.
- **Pick a part the value has.** Reading the Z part of a Vector2, or Red off a Vector3, is not a
  quiet zero - it fails. The dropdown offers all seven parts because one verb serves four shapes, not
  because every shape has all of them.
- **Set Part Of on a record ADDS a missing field** rather than failing. That is useful for building a
  record up, and it means a typo creates a new field instead of reporting one.
- **A record that might be missing the field is Get Key (with default)'s job.** Part Of takes no
  fallback, deliberately.
- **Reopening a `.gd` sheet lifts Set Part Of back as Set Key.** The emitted line is identical either
  way, so nothing breaks and no bytes change - but do not be surprised when the sentence comes back
  wearing the other verb's name.
- **`position` and `global_position` are different vectors.** Aiming with one and moving with the
  other is a bug that looks like drift, and it is invisible until the node is nested.
- **Screen space is not world space, and the difference is the camera.** A HUD node parented under the
  camera moves with it for free; a HUD node on a CanvasLayer does not, and needs World Point To Screen.
  Mixing the two is what makes a nameplate lag one frame behind its owner.
- **A 3D point behind the camera still projects to a number.** Project To Screen (3D) has no way to say
  "nowhere"; Is Behind Camera (3D) is how you ask. Every 3D marker needs that guard.
- **The screen verbs read the CURRENT camera.** During a scene change there may be none, which is why the
  3D pair read as zero and true rather than faulting - but it also means a marker placed on the first
  frame of a new scene may be placed against nothing. Place it under a per-frame trigger, not On Ready.
- **Angle Reflected is degrees in, degrees out**, to match Set Angle Of Motion and `rotation_degrees`.
  Bounce Off Surface and Slide Along Surface work in vectors instead, to match `velocity`.
- **A normal must point AWAY from the surface.** The ones the engine hands you always do; one you built
  yourself by subtracting two positions may not, and a flipped normal bounces things into the wall.
- **Bounce keeps the speed, Slide loses it.** Bounce Off Surface with bounciness 1 is a perfect
  ricochet; Slide Along Surface deliberately discards the part heading into the wall, so a head-on slide
  is a full stop. That is the correct answer for a wall slide and the wrong one for a pinball.
- **Park things clear of surfaces.** Push Out Of Surface exists because a ray starting exactly on a shape
  does not report that shape, so a bullet left touching a wall sails straight through it next frame.
- **Aim At Moving Target assumes the target keeps going.** It is a straight-line lead, which is right for
  a walking player and wrong for one who is about to jump. Re-evaluate it every frame rather than aiming
  once and committing.
- **These verbs hand back new values.** `Clamp Length(velocity, 400)` on its own line does nothing;
  the result has to be assigned back to `velocity`.
