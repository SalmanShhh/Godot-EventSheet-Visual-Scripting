# Raycasting And Overlaps In 2D

A raycast is the game-development question "what is over there?" - line of sight, a ledge probe, a hitscan
bullet, a ground check, a click on a unit. Godot answers it four different ways, and this vocabulary
reaches all four from a sheet with no GDScript:

1. **A RayCast2D node** - a persistent hairline ray the physics server updates for you every frame.
2. **A ShapeCast2D node** - the same idea with THICKNESS: a swept shape that reports EVERY object along
   its path, not just the first.
3. **One-off world queries** - cast from anywhere with no node at all, and point or shape queries that
   ask "what is here right now".
4. **Overlap queries** - what is at this point, inside this circle, inside this rectangle, under the
   mouse.

The 3D versions of every one of these live in the sibling guide **Raycasting And Overlaps In 3D**.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Reference tables](#reference-tables)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Ground and ledge probes** for a platformer, in front of and below the character.
- **Hitscan weapons** - a bullet that arrives instantly and leaves a spark on the wall.
- **Line of sight** - can this guard see the player through that crate?
- **Wall slides and bounces**, from the surface normal at the hit.
- **Click-to-select** in a 2D strategy or builder game.
- **Explosion radii and pickup magnets** - everything inside a circle, in one row.
- **Selection boxes** - everything inside a rectangle.
- **Anti-tunnelling movement** for fast objects, through a swept circle.
- **Melee arcs** - swing a ray around and ask what it touched.
- **Interaction prompts** - the nearest thing in front of the player, with its group checked.

## Core concepts

- **A node cast is continuous, a world query is a moment.** RayCast2D and ShapeCast2D update themselves
  every physics frame, so you just READ them. A world query fires when the row runs and answers about that
  instant.
- **Two shapes of row, deliberately.** The single-shot EXPRESSIONS (World Raycast Point, World Raycast
  Collider) read beautifully in one cell but RE-CAST the ray every time you use one - asking for the point
  and the collider costs two casts. The **Cast Ray Into (2D)** ACTION fires ONE cast and stores the result
  in a variable, which the **Ray Result ...** rows then read for free. Reach for Cast Ray Into whenever
  you want more than one fact about the same hit.
- **A hit result is a Dictionary, and empty means "nothing".** Cast Ray Into stores Godot's raw result.
  Ray Result Hit Something (2D) is `not result.is_empty()`; the readers each have a safe fallback, so
  reading a point off a clear ray gives `Vector2.ZERO` rather than an error.
- **The target of a raycast node is LOCAL.** Point RayCast At (2D) takes a position relative to the
  RayCast2D node itself, not a world position. `Vector2(0, 100)` points 100 pixels down from wherever the
  node is, whichever way it is rotated.
- **Masks decide what a cast can see.** Set RayCast Mask (2D) takes the whole mask as a number (each layer
  is a bit, so layers 1 and 3 are `1 + 4 = 5`); Set RayCast Mask Layer (2D) flips one layer without the
  arithmetic.
- **Areas are ignored by default.** A ray that "misses" a trigger zone is almost always a ray with
  `collide_with_areas` off. RayCast Detects Areas (2D) turns it on.
- **A shapecast has thickness and reports a LIST.** ShapeCast Hit Count (2D) tells you how many, and the
  ...At expressions read hit number 0, 1, 2. Its safe fraction is the distance it could travel before touching
  anything, from 0 to 1 - multiply the target by it to stop just short of a wall.
- **The node-scoped rows need the right host.** The RayCast2D vocabulary only appears on a `RayCast2D`
  sheet, the ShapeCast2D vocabulary on a `ShapeCast2D` sheet, and the world queries on a `Node2D`.

## Reference tables

The "Ships as" column is the exact code the row compiles to. Parameters appear in `{braces}`.

### The RayCast2D node

Scoped to a `RayCast2D` host.

| Name | What it does | Ships as |
|------|--------------|----------|
| RayCast Is Colliding (2D) | True when the RayCast2D is currently hitting something in its path. | `is_colliding()` |
| Force RayCast Update (2D) | Immediately re-checks the raycast this frame instead of waiting for physics. | `force_raycast_update()` |
| RayCast Collider (2D) | The node the raycast is currently hitting, or nothing if clear. | `get_collider()` |
| RayCast Hit Point (2D) | The world point where the raycast hit something. | `get_collision_point()` |
| RayCast Hit Normal (2D) | The surface direction at the raycast's hit point. | `get_collision_normal()` |
| RayCast Hit Shape Index (2D) | Which of the hit object's collision shapes was struck, as an index. | `get_collider_shape()` |
| RayCast Hits Group (2D) | True when the ray is hitting something in a group. | `(is_colliding() and get_collider() != null and get_collider().is_in_group({group}))` |
| RayCast Target (2D) | Where the ray currently reaches, relative to the raycast node. | `target_position` |
| Point RayCast At (2D) | Aims the ray and sets how far it reaches, in the node's own space. | `target_position = {reach}` |
| Enable RayCast (2D) | Turns the ray on or off. A disabled ray costs nothing and reports no hit. | `enabled = {on}` |
| Set RayCast Mask (2D) | Chooses which collision layers the ray can see, all at once. | `collision_mask = {mask}` |
| Set RayCast Mask Layer (2D) | Switches ONE collision layer on or off for the ray. | `set_collision_mask_value({layer}, {on})` |
| Ignore Node In RayCast (2D) | Makes the ray pass straight through one specific object. | `add_exception({node})` |
| Stop Ignoring Node In RayCast (2D) | Undoes Ignore Node In RayCast for one object. | `remove_exception({node})` |
| Clear RayCast Exceptions (2D) | Forgets every ignored object. | `clear_exceptions()` |
| RayCast Detects Areas (2D) | Lets the ray notice Area2D nodes (OFF by default in Godot). | `collide_with_areas = {on}` |
| RayCast Detects Bodies (2D) | Lets the ray notice solid physics bodies (on by default). | `collide_with_bodies = {on}` |
| RayCast Hits From Inside (2D) | Reports a hit even when the ray begins inside the shape. | `hit_from_inside = {on}` |
| RayCast Ignores Its Parent (2D) | Passes through the body the raycast hangs from (on by default). | `exclude_parent = {on}` |

### The ShapeCast2D node

Scoped to a `ShapeCast2D` host.

| Name | What it does | Ships as |
|------|--------------|----------|
| ShapeCast Is Colliding (2D) | True when the swept shape is touching anything along its path. | `is_colliding()` |
| Force ShapeCast Update (2D) | Re-runs the sweep immediately instead of waiting for the next physics frame. | `force_shapecast_update()` |
| Point ShapeCast At (2D) | Aims the sweep and sets its length, in the node's own space. | `target_position = {reach}` |
| Enable ShapeCast (2D) | Turns the sweep on or off. | `enabled = {on}` |
| ShapeCast Hit Count (2D) | How many objects the sweep is touching. | `get_collision_count()` |
| ShapeCast Collider At (2D) | One of the objects the sweep is touching, by position in the hit list. | `get_collider({index})` |
| ShapeCast Hit Point At (2D) | The world point where one of the sweep's hits touches. | `get_collision_point({index})` |
| ShapeCast Hit Normal At (2D) | The surface direction at one of the sweep's hits. | `get_collision_normal({index})` |
| ShapeCast Safe Fraction (2D) | How far along the sweep the shape can travel WITHOUT touching anything, 0 to 1. | `get_closest_collision_safe_fraction()` |
| ShapeCast Unsafe Fraction (2D) | How far along the sweep the shape is first touching something, 0 to 1. | `get_closest_collision_unsafe_fraction()` |
| Set ShapeCast Mask (2D) | Chooses which collision layers the sweep can see. | `collision_mask = {mask}` |
| Set ShapeCast Margin (2D) | Pads the swept shape slightly, for steadier contact along a surface. | `margin = {margin}` |
| Set ShapeCast Max Results (2D) | Caps how many objects one sweep will report. | `max_results = {max_results}` |
| Ignore Node In ShapeCast (2D) | Makes the sweep pass straight through one specific object. | `add_exception({node})` |
| Clear ShapeCast Exceptions (2D) | Forgets every ignored object. | `clear_exceptions()` |

### One-off world queries

Scoped to a `Node2D` host.

| Name | What it does | Ships as |
|------|--------------|----------|
| Cast Ray Into (2D) | Fires ONE ray and stores everything it learned in a variable. | builds a `PhysicsRayQueryParameters2D` from `{from}`, `{to}`, `{mask}`, `{exclude}`, sets `collide_with_areas = {hit_areas}`, then `{into} = get_world_2d().direct_space_state.intersect_ray(...)` |
| World Raycast Hits? (2D) | True when a ray drawn between two points hits any physics object. | `not get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create({from}, {to})).is_empty()` |
| World Raycast Point (2D) | Where a one-shot ray between two points strikes a surface. | the same query, `.get("position", Vector2.ZERO)` |
| World Raycast Collider (2D) | The object a one-shot ray between two points hits, or nothing. | the same query, `.get("collider", null)` |
| World Raycast Normal (2D) | The surface direction where a one-off ray hits, or a zero vector. | the same query, `.get("normal", Vector2.ZERO)` |
| Cast Circle Motion Into (2D) | How far a circle could travel before something stops it, as a fraction of the move. | builds a `CircleShape2D` of `{radius}` at `{from}`, sets `motion = {motion}` and `collision_mask = {mask}`, then stores `cast_motion(...)[0]` in `{into}` (1.0 when the path is clear) |

### Reading a stored cast result

Scoped to a `Node2D` host. `{result}` is the variable a Cast Ray Into filled.

| Name | What it does | Ships as |
|------|--------------|----------|
| Ray Result Hit Something (2D) | True when the stored cast found something. | `not {result}.is_empty()` |
| Ray Result Collider (2D) | The object the stored cast hit, or nothing. | `{result}.get("collider", null)` |
| Ray Result Point (2D) | Where in the world the stored cast struck. | `{result}.get("position", Vector2.ZERO)` |
| Ray Result Normal (2D) | Which way the surface faces at the hit. | `{result}.get("normal", Vector2.ZERO)` |
| Ray Result Shape Index (2D) | Which of the hit object's collision shapes was struck. | `{result}.get("shape", -1)` |
| Ray Result Is In Group (2D) | True when the stored cast hit something in a group, safe on a clear ray. | `({result}.get("collider", null) != null and {result}["collider"].is_in_group({group}))` |

### Overlap queries

Scoped to a `Node2D` host. Each one fills an Array variable with the objects it found.

| Name | What it does | Ships as |
|------|--------------|----------|
| Query Bodies At Point (2D) | Everything at one world point - like tapping the world with a finger. | a `PhysicsPointQueryParameters2D` at `{point}`, looping `intersect_point(..., {max_results})` and appending each `collider` to `{into}` |
| Query Bodies In Circle (2D) | Everything inside a circle - explosion radii, pickup magnets, proximity. | a `CircleShape2D` of `{radius}` at `{center}`, looping `intersect_shape(..., {max_results})` into `{into}` |
| Query Bodies In Rectangle (2D) | Everything inside a rectangle - selection boxes, damage zones, room checks. | a `RectangleShape2D` of `{size}` at `{center}`, looping `intersect_shape(..., {max_results})` into `{into}` |
| Query Bodies Under Mouse (2D) | Everything the cursor is over - click-to-select with no coordinate maths. | a `PhysicsPointQueryParameters2D` at `get_global_mouse_position()`, `collide_with_areas = {hit_areas}`, looping into `{into}` |

## Use cases

**1. A ground check.** Put a RayCast2D under the character pointing down, and read it.

```
Every tick
  Condition: RayCast Is Colliding (2D)
    -> set OnGround to true
  Else
    -> set OnGround to false
```

```gdscript
func _physics_process(_delta: float) -> void:
	on_ground = $GroundRay.is_colliding()
```

**2. A ledge probe that follows the facing direction.** The target is LOCAL, so flipping the sign flips
the probe.

```
Every tick
  -> Point RayCast At (2D)  Vector2(24 * facing, 0)
```

**3. Only see the terrain.** Layer 1 is terrain, so mask 1.

```
On Ready
  -> Set RayCast Mask (2D)  1
```

To add layer 3 without doing bit arithmetic, use Set RayCast Mask Layer (2D) with layer 3 and true.

**4. Make the ray notice a trigger zone.** This is the single most common "my ray does not work" fix.

```
On Ready
  -> RayCast Detects Areas (2D)  true
```

**5. Stop the gun's ray hitting the shooter.**

```
On Ready
  -> Ignore Node In RayCast (2D)  the player body
```

The `node` parameter must be a `CollisionObject2D` - a plain Node will not compile. RayCast Ignores Its
Parent (2D) already covers the common case of a ray parented to the body.

**6. "Did I shoot an enemy?" in one cell.**

```
Every tick
  Condition: RayCast Hits Group (2D)  "enemies"
    -> damage RayCast Collider (2D) by 10
```

**7. Tell a headshot from a body shot.** A body built from two collision shapes reports which one was hit.

```
Every tick
  Condition: RayCast Is Colliding (2D)
  Condition: RayCast Hit Shape Index (2D) = 0
    -> deal double damage
```

**8. Re-aim and read in the same frame.** A raycast node normally updates on the physics tick, so a row
that aims it and reads it immediately would read last frame's answer.

```
Every tick
  -> Point RayCast At (2D)  aim_direction * 400
  -> Force RayCast Update (2D)
  Condition: RayCast Is Colliding (2D)
    -> spawn a spark at RayCast Hit Point (2D)
```

**9. Bounce off a wall.** The normal is the surface direction, and `bounce` reflects around it.

```gdscript
func _on_wall_hit() -> void:
	velocity = velocity.bounce($Ray.get_collision_normal())
```

**10. Line of sight for a guard, with one cast and two questions.** Cast Ray Into fires once; the readers
are free.

```
Every tick
  -> Cast Ray Into (2D)  hit, from global_position, to player.global_position
  Condition: hit hit something
  Condition: hit is in "player"
    -> raise the alert
```

```gdscript
func _physics_process(_delta: float) -> void:
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 4294967295, [])
	query.collide_with_areas = false
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit["collider"].is_in_group("player"):
		alerted = true
```

**11. Ignore yourself in a one-off cast.** The `exclude` parameter takes an Array of physics RIDs.

```
On shoot
  -> Cast Ray Into (2D)  hit, from muzzle, to muzzle + aim * 900, ignore [get_rid()]
```

**12. A hitscan shot with an impact spark and a decal, from a single cast.**

```
On shoot
  -> Cast Ray Into (2D)  hit, from muzzle.global_position, to muzzle.global_position + aim * 900
  Condition: hit hit something
    -> spawn a spark at hit point
    -> rotate the decal to face hit normal
    -> damage hit collider
```

Using World Raycast Point, World Raycast Collider and World Raycast Normal here instead would cast the
same ray three times.

**13. A quick yes/no line check with no variable at all.** When one fact is genuinely all you need, the
single-shot condition is the tidier row.

```
Every tick
  Condition: World Raycast Hits? (2D)  from A.global_position, to B.global_position
    -> break the cable
```

**14. Click-to-select.** Query Bodies Under Mouse fills an Array with everything under the cursor.

```
On Input
  Condition: On Mouse Button Pressed (event)  MOUSE_BUTTON_LEFT
    -> Query Bodies Under Mouse (2D)  into picked
    -> For Each  unit  in  picked
      -> select unit
```

It detects areas by DEFAULT, which is usually right for clickable units built from Area2D.

**15. An explosion that damages everything nearby.**

```
On bomb exploded
  -> Query Bodies In Circle (2D)  into caught, center global_position, radius 120
  -> For Each  victim  in  caught
    -> damage victim by 40
```

**16. A drag-selection box.**

```
On selection finished
  -> Query Bodies In Rectangle (2D)  into chosen, center box_center, size box_size
  -> select every unit in chosen
```

**17. What is exactly here?** A pinprick query at a point, for a grid game checking one cell.

```
On place building
  -> Query Bodies At Point (2D)  into occupants, point snapped_cell_position
  Condition: occupants is empty
    -> place the building
```

Note that Query Bodies At Point (2D) has no detect-areas option; it reports bodies. Query Bodies Under
Mouse (2D) is the one with the areas switch.

**18. Stop a fast object tunnelling through a thin wall.** Cast Circle Motion Into gives the fraction of
the move that is clear.

```
Every tick
  -> Cast Circle Motion Into (2D)  travel, from global_position, motion velocity * delta, radius 8
  -> move by velocity * delta * travel
```

`travel` is 1.0 when the whole path is clear and 0.0 when something is touching already.

**19. A swept probe that reports EVERY object it passes.** A ShapeCast2D is the tool when a hairline ray
would slip between things.

```
Every tick
  Condition: ShapeCast Is Colliding (2D)
    -> set Count = ShapeCast Hit Count (2D)
    -> For Each index from 0 to Count - 1
      -> damage ShapeCast Collider At (2D)(index)
```

**20. Stop just short of the wall using the safe fraction.**

```
Every tick
  -> Point ShapeCast At (2D)  velocity * delta
  -> Force ShapeCast Update (2D)
  -> move by velocity * delta * ShapeCast Safe Fraction (2D)
```

Unsafe Fraction is the contact point instead - the difference between the two is the shape's thickness at
the moment of touch.

**21. Bound the cost of a sweep in a crowd.**

```
On Ready
  -> Set ShapeCast Max Results (2D)  8
  -> Set ShapeCast Margin (2D)  0.5
```

A small margin makes contact steadier while the shape slides along a surface.

**22. A melee arc.** Swing the ray around the character and check the group each step.

```
On attack
  -> For Each angle from -40 to 40 step 10
    -> Point RayCast At (2D)  Vector2(60, 0).rotated(deg_to_rad(angle))
    -> Force RayCast Update (2D)
    Condition: RayCast Hits Group (2D)  "enemies"
      -> damage RayCast Collider (2D)
```

### Other use cases

**Rope and grapple attachment.** Cast Ray Into towards the aim point and store the hit; Ray Result Point gives the anchor and Ray Result Collider tells you whether it was a moving platform or static geometry.

**Auto-aim cone.** Query Bodies In Circle around the player, then one Cast Ray Into per candidate to reject anything behind a wall, so the lock only ever picks a visible target.

**Footstep surface sounds.** A short downward ray each time the foot lands, with Ray Result Shape Index picking which of the tile body's shapes was struck, so grass and stone can share one collider.

**Camera occlusion fade.** Cast Ray Into from the camera to the player every few frames and fade whatever Ray Result Collider names, so props never hide the character.

**One-way platform validation.** Compare Ray Result Normal against straight up before allowing a landing, so the character only stands on surfaces that actually face upward.

## Tips and common mistakes

- **The raycast target is LOCAL, not a world position.** Point RayCast At (2D) with the player's global
  position will send the ray to a completely wrong place. Subtract the raycast's own position first, or
  think in offsets.
- **Areas are ignored unless you say otherwise.** RayCast Detects Areas (2D) and the `hit_areas` parameter
  on Cast Ray Into / Query Bodies Under Mouse exist because Godot's default is bodies only. A ray that
  "misses" a trigger is usually this.
- **A ray that STARTS inside a shape reports nothing.** That is Godot's default. RayCast Hits From Inside
  (2D) turns it on - the reason a ray fired from inside a wall reads as clear.
- **A raycast updates on the physics tick.** Aim it and read it in the same frame and you read the previous
  answer. Force RayCast Update (2D) (or Force ShapeCast Update (2D)) fixes it; it is the single most common
  cause of a "one frame late" bug.
- **The single-shot expressions re-cast every time.** World Raycast Point, World Raycast Collider and
  World Raycast Normal each fire their own ray. Three of them in one event is three casts of the same line.
  Use Cast Ray Into (2D) and the Ray Result readers when you want more than one fact.
- **An empty result is normal, not an error.** Ray Result Point on a clear ray returns `Vector2.ZERO`, and
  Ray Result Collider returns nothing. Check Ray Result Hit Something (2D) first, or Ray Result Is In
  Group (2D), which already guards against the nothing case.
- **The exception actions need a CollisionObject2D.** Ignore Node In RayCast (2D) and Ignore Node In
  ShapeCast (2D) will not compile with a plain Node; that is why the default is written
  `get_parent() as CollisionObject2D`.
- **A disabled cast always reports no hit.** Enable RayCast (2D) set to false is free, and it looks exactly
  like a clear path. If a ray "stopped working", check whether something turned it off.
- **Masks are bitfields.** Layer 1 is `1`, layer 2 is `2`, layer 3 is `4`. Set RayCast Mask Layer (2D)
  avoids the arithmetic entirely and is the safer row.
- **The overlap queries fill an Array, and Max Results caps it.** Thirty-two is the default. A blast that
  seems to miss the outer ring of a crowd may simply have run out of slots.
- **Cast Circle Motion Into answers with a FRACTION, not a distance.** Multiply the motion by it. It is
  1.0 when the whole move is clear, which is exactly what you want to multiply by when nothing is in
  the way.
- **A shapecast reports several hits, and index 0 is not "the closest".** Use ShapeCast Hit Count (2D) and
  read every index, or use Safe Fraction when the closest blocker is what you actually mean.
