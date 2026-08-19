# Raycasting And Overlaps In 3D

Every 3D game asks "what is over there?" - what the gun is pointing at, whether the enemy can see you,
what the cursor is hovering, what the explosion caught, whether the character has floor under its feet.
This is the 3D casting vocabulary, and it reaches all five ways Godot answers that question without a line
of GDScript:

1. **A RayCast3D node** - a persistent hairline ray the physics server updates every frame.
2. **A ShapeCast3D node** - the same idea with THICKNESS: a swept shape that reports EVERY object along
   its path, and the standard fix for a bullet that tunnels through a thin wall.
3. **One-off world queries** - cast from anywhere, no node required.
4. **Camera picking** - the screen-to-world ray under the mouse, which is the whole of click-to-select.
5. **Volume queries** - what is at this point, inside this sphere, inside this box.

The 2D versions of all of this live in the sibling guide **Raycasting And Overlaps In 2D**. The two 3D
mouse-ray halves (Mouse Ray Origin, Mouse Ray Direction) are documented in **Reading Keyboard, Mouse And
Gamepad**; the camera-picking vocabulary here does the same job in one row.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Hitscan weapons** - an instant bullet with a spark and a decal at the impact.
- **Enemy line of sight** through level geometry.
- **Click-to-select and click-to-move** in a strategy, builder or point-and-click game.
- **Interaction prompts** - "Press E to open" for whatever the camera is looking at.
- **Ground and step checks** for a character controller.
- **Explosion radii and proximity triggers** through a sphere query.
- **Room and zone volumes** through a box query.
- **Anti-tunnelling movement** for fast objects, through a swept sphere.
- **Decal alignment** - lay a bullet hole flat against the surface it hit.
- **Per-face surface data** - which triangle of the terrain mesh the foot landed on.

## Core concepts

- **A node cast is continuous, a world query is a moment.** RayCast3D and ShapeCast3D update themselves on
  the physics tick, so you just READ them. A world query answers about the instant its row runs.
- **Two shapes of row, deliberately.** The single-shot EXPRESSIONS (World Raycast Point, Mouse Ray
  Collider) read well in one cell but RE-CAST the ray each time they are used - asking for the point and
  the collider costs two casts. The **Cast Ray Into (3D)** and **Cast Ray From Mouse Into (3D)** ACTIONS
  fire ONE cast and store the result in a variable, which the **Ray Result ...** rows then read for free.
- **A hit result is a Dictionary, and empty means "nothing".** Ray Result Hit Something (3D) is
  `not result.is_empty()`. Every reader has a safe fallback, so reading a point off a clear ray gives
  `Vector3.ZERO` rather than an error.
- **The target of a raycast node is LOCAL.** Point RayCast At (3D) takes a position relative to the
  RayCast3D node, not a world position. `Vector3(0, 0, -10)` points 10 metres FORWARD, because -Z is
  forward in Godot.
- **Masks decide what a cast can see.** Set RayCast Mask (3D) takes the whole mask as a number (each layer
  is a bit, so layers 1 and 3 are `1 + 4 = 5`); Set RayCast Mask Layer (3D) flips one layer without the
  arithmetic.
- **Areas are ignored by default.** A ray that "misses" a trigger volume is almost always a ray with
  `collide_with_areas` off. RayCast Detects Areas (3D), and the `hit_areas` parameter on the one-off casts,
  turn it on.
- **3D has two options 2D does not.** RayCast Hits Back Faces (3D) decides whether the inside surface of
  concave level geometry counts, and RayCast Hit Face Index (3D) / Ray Result Face Index (3D) name the
  exact triangle of a concave mesh that was struck.
- **Camera picking needs an active Camera3D.** Every mouse-ray row projects through the viewport's current
  camera. With no current camera they fail at runtime.
- **The node-scoped rows need the right host.** The RayCast3D vocabulary only appears on a `RayCast3D`
  sheet, the ShapeCast3D vocabulary on a `ShapeCast3D` sheet, and the world and picking queries on a
  `Node3D`.

## Reference tables

The "Ships as" column is the exact code the row compiles to. Parameters appear in `{braces}`.

### The RayCast3D node

Scoped to a `RayCast3D` host.

| Name | What it does | Ships as |
|------|--------------|----------|
| RayCast Is Colliding (3D) | True when a RayCast3D is currently hitting something in front of it. | `is_colliding()` |
| Force RayCast Update (3D) | Forces a recheck immediately instead of waiting for the next frame. | `force_raycast_update()` |
| RayCast Collider (3D) | The object a RayCast3D is currently hitting. | `get_collider()` |
| RayCast Hit Point (3D) | The exact world point where a RayCast3D hits something. | `get_collision_point()` |
| RayCast Hit Normal (3D) | The surface direction at the point a RayCast3D hits. | `get_collision_normal()` |
| RayCast Hit Shape Index (3D) | Which of the hit object's collision shapes was struck, as an index. | `get_collider_shape()` |
| RayCast Hit Face Index (3D) | Which triangle of a concave mesh the ray hit (-1 for other shapes). | `get_collision_face_index()` |
| RayCast Hits Group (3D) | True when the ray is hitting something in a group. | `(is_colliding() and get_collider() != null and get_collider().is_in_group({group}))` |
| RayCast Target (3D) | Where the ray currently reaches, relative to the raycast node. | `target_position` |
| Point RayCast At (3D) | Aims the ray and sets how far it reaches, in the node's own space. | `target_position = {reach}` |
| Enable RayCast (3D) | Turns the ray on or off. A disabled ray costs nothing and reports no hit. | `enabled = {on}` |
| Set RayCast Mask (3D) | Chooses which collision layers the ray can see, all at once. | `collision_mask = {mask}` |
| Set RayCast Mask Layer (3D) | Switches ONE collision layer on or off for the ray. | `set_collision_mask_value({layer}, {on})` |
| Ignore Node In RayCast (3D) | Makes the ray pass straight through one specific object. | `add_exception({node})` |
| Stop Ignoring Node In RayCast (3D) | Undoes Ignore Node In RayCast for one object. | `remove_exception({node})` |
| Clear RayCast Exceptions (3D) | Forgets every ignored object. | `clear_exceptions()` |
| RayCast Detects Areas (3D) | Lets the ray notice Area3D nodes (OFF by default in Godot). | `collide_with_areas = {on}` |
| RayCast Detects Bodies (3D) | Lets the ray notice solid physics bodies (on by default). | `collide_with_bodies = {on}` |
| RayCast Hits From Inside (3D) | Reports a hit even when the ray begins inside the shape. | `hit_from_inside = {on}` |
| RayCast Hits Back Faces (3D) | Decides whether the ray hits a surface from behind. | `hit_back_faces = {on}` |
| RayCast Ignores Its Parent (3D) | Passes through the body the raycast hangs from (on by default). | `exclude_parent = {on}` |

### The ShapeCast3D node

Scoped to a `ShapeCast3D` host.

| Name | What it does | Ships as |
|------|--------------|----------|
| ShapeCast Is Colliding (3D) | True when the swept shape is touching anything along its path. | `is_colliding()` |
| Force ShapeCast Update (3D) | Re-runs the sweep immediately instead of waiting for the next physics frame. | `force_shapecast_update()` |
| Point ShapeCast At (3D) | Aims the sweep and sets its length, in the node's own space. | `target_position = {reach}` |
| Enable ShapeCast (3D) | Turns the sweep on or off. | `enabled = {on}` |
| ShapeCast Hit Count (3D) | How many objects the sweep is touching. | `get_collision_count()` |
| ShapeCast Collider At (3D) | One of the objects the sweep is touching, by position in the hit list. | `get_collider({index})` |
| ShapeCast Hit Point At (3D) | The world point where one of the sweep's hits touches. | `get_collision_point({index})` |
| ShapeCast Hit Normal At (3D) | The surface direction at one of the sweep's hits. | `get_collision_normal({index})` |
| ShapeCast Safe Fraction (3D) | How far along the sweep the shape can travel WITHOUT touching anything, 0 to 1. | `get_closest_collision_safe_fraction()` |
| ShapeCast Unsafe Fraction (3D) | How far along the sweep the shape is first touching something, 0 to 1. | `get_closest_collision_unsafe_fraction()` |
| Set ShapeCast Mask (3D) | Chooses which collision layers the sweep can see. | `collision_mask = {mask}` |
| Set ShapeCast Margin (3D) | Pads the swept shape slightly, for steadier contact along a surface. | `margin = {margin}` |
| Set ShapeCast Max Results (3D) | Caps how many objects one sweep will report. | `max_results = {max_results}` |
| Ignore Node In ShapeCast (3D) | Makes the sweep pass straight through one specific object. | `add_exception({node})` |
| Clear ShapeCast Exceptions (3D) | Forgets every ignored object. | `clear_exceptions()` |

### One-off world queries

Scoped to a `Node3D` host.

| Name | What it does | Ships as |
|------|--------------|----------|
| Cast Ray Into (3D) | Fires ONE ray and stores everything it learned in a variable. | builds a `PhysicsRayQueryParameters3D` from `{from}`, `{to}`, `{mask}`, `{exclude}`, sets `collide_with_areas = {hit_areas}`, then `{into} = get_world_3d().direct_space_state.intersect_ray(...)` |
| World Raycast Hits? (3D) | True when a ray cast between two points hits anything in the 3D world. | `not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create({from}, {to})).is_empty()` |
| World Raycast Point (3D) | Where a ray between two points first hits something. | the same query, `.get("position", Vector3.ZERO)` |
| World Raycast Collider (3D) | The object a one-off ray hits, or nothing when the path is clear. | the same query, `.get("collider", null)` |
| World Raycast Normal (3D) | The surface direction where a one-off ray hits, or a zero vector. | the same query, `.get("normal", Vector3.ZERO)` |
| Cast Sphere Motion Into (3D) | How far a sphere could travel before something stops it, as a fraction of the move. | builds a `SphereShape3D` of `{radius}` at `{from}`, sets `motion = {motion}` and `collision_mask = {mask}`, then stores `cast_motion(...)[0]` in `{into}` (1.0 when the path is clear) |

### Camera picking

Scoped to a `Node3D` host. All four need an active Camera3D.

| Name | What it does | Ships as |
|------|--------------|----------|
| Cast Ray From Mouse Into (3D) | Shoots a ray from the camera through the cursor and stores what it finds. | projects `{distance}` metres from `get_viewport().get_camera_3d()` through the mouse position, builds a `PhysicsRayQueryParameters3D` with `{mask}` and `{exclude}`, sets `collide_with_areas = {hit_areas}`, then `{into} = ...intersect_ray(...)` |
| Mouse Ray Hits Something (3D) | True when the cursor is over something solid. | the same projection inline, `not ....is_empty()` |
| Mouse Ray Collider (3D) | The object under the cursor, or nothing over empty space. | the same projection inline, `.get("collider", null)` |
| Mouse Ray Point (3D) | The world point the cursor is pointing at. | the same projection inline, `.get("position", Vector3.ZERO)` |

### Reading a stored cast result

Scoped to a `Node3D` host. `{result}` is the variable a Cast Ray Into or Cast Ray From Mouse Into filled.

| Name | What it does | Ships as |
|------|--------------|----------|
| Ray Result Hit Something (3D) | True when the stored cast found something. | `not {result}.is_empty()` |
| Ray Result Collider (3D) | The object the stored cast hit, or nothing. | `{result}.get("collider", null)` |
| Ray Result Point (3D) | Where in the world the stored cast struck. | `{result}.get("position", Vector3.ZERO)` |
| Ray Result Normal (3D) | Which way the surface faces at the hit. | `{result}.get("normal", Vector3.ZERO)` |
| Ray Result Shape Index (3D) | Which of the hit object's collision shapes was struck. | `{result}.get("shape", -1)` |
| Ray Result Face Index (3D) | Which triangle of a concave mesh was hit (-1 for other shapes). | `{result}.get("face_index", -1)` |
| Ray Result Is In Group (3D) | True when the stored cast hit something in a group, safe on a clear ray. | `({result}.get("collider", null) != null and {result}["collider"].is_in_group({group}))` |

### Volume queries

Scoped to a `Node3D` host. Each one fills an Array variable with the objects it found.

| Name | What it does | Ships as |
|------|--------------|----------|
| Query Bodies At Point (3D) | Everything at one world point - like tapping the world with a finger. | a `PhysicsPointQueryParameters3D` at `{point}` with `collide_with_areas = {hit_areas}`, looping `intersect_point(..., {max_results})` and appending each `collider` to `{into}` |
| Query Bodies In Sphere (3D) | Everything inside a sphere - explosion radii, pickup magnets, proximity checks. | a `SphereShape3D` of `{radius}` at `{center}` with `{mask}`, looping `intersect_shape(..., {max_results})` into `{into}` |
| Query Bodies In Box (3D) | Everything inside a box - room triggers, blast zones, selection volumes. | a `BoxShape3D` of `{size}` at `{center}` with `{mask}`, looping `intersect_shape(..., {max_results})` into `{into}` |

## Use cases

**1. A ground check under a character.** Put a RayCast3D under the body pointing down, and read it.

```
Every tick
  Condition: RayCast Is Colliding (3D)
    -> set Grounded to true
  Else
    -> set Grounded to false
```

```gdscript
func _physics_process(_delta: float) -> void:
	grounded = $GroundRay.is_colliding()
```

**2. Aim the interaction ray forward.** -Z is forward, so a positive reach would point behind you.

```
On Ready
  -> Point RayCast At (3D)  Vector3(0, 0, -3)
```

**3. "Press E to open" for whatever the ray is on.**

```
Every tick
  Condition: RayCast Hits Group (3D)  "interactable"
    -> show the prompt for RayCast Collider (3D)
  Else
    -> hide the prompt
```

**4. Only see the world geometry.** Layer 1 is level geometry, so mask 1.

```
On Ready
  -> Set RayCast Mask (3D)  1
```

To also see layer 4 without doing bit arithmetic, add a Set RayCast Mask Layer (3D) row for layer 4, true.

**5. Make the ray notice a trigger volume.** This is the most common "my ray does not work" fix.

```
On Ready
  -> RayCast Detects Areas (3D)  true
```

**6. Stop the gun's ray hitting the shooter.**

```
On Ready
  -> Ignore Node In RayCast (3D)  the player body
```

The node must be a `CollisionObject3D` - a plain Node will not compile. RayCast Ignores Its Parent (3D)
already covers a ray parented to the body.

**7. See the inside of a room built from a concave mesh.** Concave collision has no thickness, so a ray
from inside the room hits its walls from behind.

```
On Ready
  -> RayCast Hits Back Faces (3D)  true
```

**8. Read per-face surface data for footsteps.** A concave terrain mesh reports which triangle was hit.

```
Every tick
  Condition: RayCast Is Colliding (3D)
    -> look up the footstep sound for RayCast Hit Face Index (3D)
```

It returns -1 on any shape that is not a concave mesh, so treat -1 as "use the default sound".

**9. Re-aim and read in the same frame.** A raycast node updates on the physics tick, so a row that aims
and reads immediately would read last frame's answer.

```
Every tick
  -> Point RayCast At (3D)  aim_local * 50
  -> Force RayCast Update (3D)
  Condition: RayCast Is Colliding (3D)
    -> spawn an impact at RayCast Hit Point (3D)
```

**10. A hitscan shot with an impact, a decal and damage, from ONE cast.**

```
On shoot
  -> Cast Ray Into (3D)  hit, from muzzle.global_position, to muzzle.global_position - camera_forward * 200
  Condition: hit hit something
    -> spawn a spark at hit point
    -> align the decal to hit normal
    -> damage hit collider
```

```gdscript
func shoot() -> void:
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + aim * 200.0, 4294967295, [get_rid()])
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		spawn_impact(hit["position"], hit["normal"])
```

Using World Raycast Point, World Raycast Collider and World Raycast Normal here instead would cast the
same ray three times.

**11. Line of sight for an enemy, with one cast and two questions.**

```
Every tick
  -> Cast Ray Into (3D)  sight, from eyes.global_position, to player.global_position, ignore [get_rid()]
  Condition: sight hit something
  Condition: sight is in "player"
    -> chase the player
```

**12. Tell a headshot from a body shot.**

```
On shoot
  -> Cast Ray Into (3D)  hit, from muzzle, to muzzle + aim * 200
  Condition: hit hit something
  Condition: hit shape index = 0
    -> deal triple damage
```

**13. A quick yes/no line check.** When one fact is genuinely all you need, the single-shot condition is
the tidier row.

```
Every tick
  Condition: World Raycast Hits? (3D)  from turret.global_position, to target.global_position
    -> hold fire
```

**14. Click-to-select, in one row.** Cast Ray From Mouse Into does the camera projection for you.

```
On Input
  Condition: On Mouse Button Pressed (event)  MOUSE_BUTTON_LEFT
    -> Cast Ray From Mouse Into (3D)  picked, distance 1000
    Condition: picked hit something
      -> select picked collider
```

**15. Click-to-move.** Mouse Ray Point gives the ground position the cursor is over.

```
On Input
  Condition: On Mouse Button Pressed (event)  MOUSE_BUTTON_RIGHT
    -> set the agent's target to Mouse Ray Point (3D)(1000)
```

**16. A build ghost that follows the cursor.**

```
Every tick
  Condition: Mouse Ray Hits Something (3D)  1000
    -> move the ghost to Mouse Ray Point (3D)(1000)
    -> show the ghost
  Else
    -> hide the ghost
```

Mouse Ray Hits Something and Mouse Ray Point each cast their own ray. Two rows is two casts per frame -
acceptable for a ghost, but Cast Ray From Mouse Into is one cast if you want both facts.

**17. Hover highlight.**

```
Every tick
  -> set Hovered = Mouse Ray Collider (3D)(1000)
  Condition: Hovered is not nothing
    -> outline Hovered
```

**18. An explosion that damages everything nearby.**

```
On grenade exploded
  -> Query Bodies In Sphere (3D)  into caught, center global_position, radius 6
  -> For Each  victim  in  caught
    -> damage victim by 80
```

**19. A room trigger without an Area3D.**

```
Every second
  -> Query Bodies In Box (3D)  into occupants, center room_center, size Vector3(12, 4, 12)
  Condition: occupants is not empty
    -> light the room
```

**20. What is exactly here?** A pinprick query, for a grid or voxel game checking one cell.

```
On place block
  -> Query Bodies At Point (3D)  into occupants, point snapped_cell
  Condition: occupants is empty
    -> place the block
```

**21. Stop a fast object tunnelling through a thin wall.** Cast Sphere Motion Into gives the fraction of
the move that is clear.

```
Every tick
  -> Cast Sphere Motion Into (3D)  travel, from global_position, motion velocity * delta, radius 0.25
  -> move by velocity * delta * travel
```

`travel` is 1.0 when the whole path is clear and 0.0 when something is touching already.

**22. A swept probe that reports EVERY object it passes.** A ShapeCast3D is the tool when a hairline ray
would slip past something.

```
Every tick
  Condition: ShapeCast Is Colliding (3D)
    -> set Count = ShapeCast Hit Count (3D)
    -> For Each index from 0 to Count - 1
      -> damage ShapeCast Collider At (3D)(index)
```

**23. Stop just short of the wall using the safe fraction.**

```
Every tick
  -> Point ShapeCast At (3D)  velocity * delta
  -> Force ShapeCast Update (3D)
  -> move by velocity * delta * ShapeCast Safe Fraction (3D)
```

Unsafe Fraction is the contact point instead; the gap between the two is the shape's thickness at touch.

**24. Bound the cost of a sweep in a crowd.**

```
On Ready
  -> Set ShapeCast Max Results (3D)  8
  -> Set ShapeCast Margin (3D)  0.02
```

Margin is in METRES in 3D, so 0.02 is two centimetres - a shapecast margin copied from a 2D sheet will be
enormous.

### Other use cases

**Camera occlusion.** Cast Ray Into from the camera to the player every few frames and fade whatever Ray Result Collider names, so pillars never hide the character.

**Cover detection for AI.** Query Bodies In Sphere around a threatened enemy, then one Cast Ray Into per candidate position to find which ones actually break line of sight.

**Grapple and zipline anchors.** Cast Ray From Mouse Into to pick the anchor and store the hit, so Ray Result Point gives the attach position and Ray Result Normal gives the swing plane.

**Step-up detection.** A short forward ray at ankle height and a second one at knee height: blocked low and clear high means a step the character can climb instead of a wall.

**Surface-typed decals.** Ray Result Face Index on a concave terrain mesh chooses between mud, stone and grass decals without a collider per material.

## Tips and common mistakes

- **-Z is forward.** Point RayCast At (3D) with `Vector3(0, 0, 10)` points the ray BACKWARDS. The default
  `Vector3(0, 0, -10)` is 10 metres forward, and it is the shape most 3D casting bugs take.
- **The raycast target is LOCAL, not a world position.** Handing it a global position sends the ray
  somewhere else entirely. Think in offsets, or subtract the raycast's own position first.
- **Areas are ignored unless you say otherwise.** RayCast Detects Areas (3D), and the `hit_areas` parameter
  on Cast Ray Into / Cast Ray From Mouse Into / Query Bodies At Point, exist because Godot's default is
  bodies only.
- **A ray that STARTS inside a shape reports nothing** by default. RayCast Hits From Inside (3D) turns it
  on, and it is why a ray fired from inside geometry reads as clear.
- **Concave meshes have no back.** If a room built from a concave mesh reads as empty from the inside,
  RayCast Hits Back Faces (3D) is the switch.
- **A raycast updates on the physics tick.** Aim it and read it in the same frame and you read the previous
  answer. Force RayCast Update (3D) or Force ShapeCast Update (3D) is the fix, and this is the most common
  "one frame late" bug.
- **The single-shot expressions re-cast every time.** World Raycast Point, World Raycast Collider, World
  Raycast Normal, Mouse Ray Hits Something, Mouse Ray Collider and Mouse Ray Point each fire their own ray.
  Three of them in an event is three casts of the same line. Use Cast Ray Into (3D) or Cast Ray From Mouse
  Into (3D) and read the stored result.
- **An empty result is normal, not an error.** Ray Result Point on a clear ray returns `Vector3.ZERO` and
  Ray Result Collider returns nothing. Check Ray Result Hit Something (3D) first, or use Ray Result Is In
  Group (3D), which already guards the nothing case.
- **Camera picking needs a current Camera3D.** Every mouse-ray row projects through
  `get_viewport().get_camera_3d()`. In a scene with no current camera, or before one becomes current, it
  fails at runtime.
- **Distance is a real limit.** The picking rows default to 1000 metres. A large open world can exceed it,
  and a small scene wastes nothing by lowering it.
- **The exception actions need a CollisionObject3D.** Ignore Node In RayCast (3D) and Ignore Node In
  ShapeCast (3D) will not compile with a plain Node, which is why the default reads
  `get_parent() as CollisionObject3D`.
- **A disabled cast always reports no hit.** Enable RayCast (3D) set to false looks exactly like a clear
  path. If a ray "stopped working", check whether something switched it off.
- **Masks are bitfields.** Layer 1 is `1`, layer 2 is `2`, layer 3 is `4`. Set RayCast Mask Layer (3D)
  avoids the arithmetic and is the safer row.
- **The volume queries fill an Array, and Max Results caps it.** Thirty-two is the default; a blast that
  seems to miss the outer ring of a crowd may simply have run out of slots.
- **Cast Sphere Motion Into answers with a FRACTION, not a distance.** Multiply the motion by it - it is
  1.0 when the whole move is clear.
- **A shapecast reports several hits, and index 0 is not "the closest".** Read every index up to ShapeCast
  Hit Count (3D), or use Safe Fraction when the nearest blocker is what you actually mean.
- **Units are metres, not pixels.** A radius of 64 copied from a 2D sheet is a 64-metre sphere.
