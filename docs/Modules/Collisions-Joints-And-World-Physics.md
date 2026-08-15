# Collisions, Joints And World Physics

These are the builtin verbs for **what touched what, and the world it happens in**. Three questions,
three families:

- **What did I just hit?** After a character body moves, the engine already knows whether it ended up
  against a wall, a ceiling or a slope, and what it bumped into. **Is On Wall**, **Wall Normal**,
  **Last Slide Collider** and friends read those results instead of you re-deriving them.
- **What is overlapping me?** An Area asks **Overlaps Body**, **Has Overlapping Areas**, or hands you
  the whole list with **Overlapping Bodies**. Layers and masks decide who is even allowed to notice
  whom, and a collision shape can be switched off mid-game.
- **What are the rules of this world?** Gravity strength, gravity direction, and whether physics is
  running at all are world-level knobs, plus the profiling numbers a performance HUD reads.

Every verb here compiles to one plain Godot call. There is no plugin runtime under any of it: a row
that reads "Is on wall" ships as `is_on_wall()`, and that is the whole implementation.

## Table of Contents

1. [Where this shines](#where-this-shines)
2. [Core concepts](#core-concepts)
3. [Verb reference](#verb-reference)
4. [Use cases](#use-cases)
5. [Tips and common mistakes](#tips-and-common-mistakes)

## Where this shines

- **Wall jumps and wall slides** - Is On Wall plus Wall Normal is the whole mechanic.
- **Slope-aware movement** - Floor Normal tells you which way the ground is leaning.
- **Bounce and ricochet** - Last Slide Normal reflects a projectile off whatever it just clipped.
- **Damage on contact** - Last Slide Collider names the node the body ran into.
- **Trigger volumes** - Has Overlapping Bodies is the "someone is standing here" check.
- **Area-of-effect hits** - Overlapping Bodies gives every target inside a blast at once.
- **Ghost and phase power-ups** - flip one mask bit and the player stops noticing enemies.
- **One-way doors and shutters** - Enable / Disable Collision Shape, safely, mid-physics.
- **Ropes, chains and breakable links** - joint verbs wire bodies together and snap them apart.
- **Low-gravity levels, water sections, gravity-flip puzzles** - one row changes the whole world.
- **Photo mode and cutscene freezes** - stop the physics space while rendering keeps running.
- **A performance HUD** - active bodies, collision pairs and islands, straight from the server.

## Core concepts

- **Slide results are answers about the LAST move.** Is On Wall, Is On Ceiling, Wall Normal, Floor
  Normal, Slide Collision Count, Last Slide Collider and Last Slide Normal all read what the engine
  recorded during the character body's most recent move. Ask them AFTER the move in the same physics
  step, not before it, and not from a per-frame event that never moves anything.
- **A normal is a direction, not a position.** Wall Normal points away from the surface the body is
  touching. That is why wall jumps are "push along the wall normal": it already faces out of the wall.
- **Overlap questions are about right now.** An Area answers Overlaps Body, Overlaps Area, Has
  Overlapping Bodies and Has Overlapping Areas from its current overlap set, so they are conditions
  you can ask any frame. The list forms (Overlapping Bodies, Overlapping Areas) hand you an array to
  loop with For Each.
- **Layer is where you sit, mask is what you notice.** Set Collision Layer Bit puts this object on a
  layer for others to see. Set Collision Mask Bit decides which layers THIS object scans. They are two
  different questions that people constantly mix up, which is why they are two different verbs.
- **A shape is switched off deferred.** Enable Collision Shape and Disable Collision Shape use
  `set_deferred`, so calling them from inside a collision callback is safe. That deferral means the
  change lands at the end of the frame, not on the next line.
- **A joint is two node paths and some tuning.** Set Joint Body A and Set Joint Body B name the two
  bodies; Break Joint clears the second one, which is exactly how a rope snaps.
- **World physics is a property of the SPACE, not of a node.** Set World Gravity and Set World Gravity
  Direction reach the current viewport's world and change it for every rigid body at once. Character
  bodies driven by a movement pack keep their own gravity number, so they will not react.
- **Pausing the space is not pausing the game.** Set Physics Active freezes every body while scripts,
  animation and rendering carry on. Pausing the scene tree is a different tool.

## Verb reference

`{host.}` in a template is the host prefix: on a sheet whose host IS the node it disappears, and on a
sheet that targets another node it becomes that node plus a dot. Node-scoped verbs are filed in the
picker under the node type in the last column.

### Slide results, after Move And Slide (CharacterBody2D)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Is On Wall | True when this 2D character is pressing against a wall | `{host.}is_on_wall()` |
| Is On Ceiling | True when this 2D character is touching a ceiling above | `{host.}is_on_ceiling()` |
| Wall Normal | The direction the touched wall is facing | `{host.}get_wall_normal()` |
| Floor Normal | The direction the floor is facing, useful on slopes | `{host.}get_floor_normal()` |
| Slide Collision Count | How many things the character hit during its last move | `get_slide_collision_count()` |
| Last Slide Collider | The node the character bumped into last, or nothing | `(get_last_slide_collision().get_collider() if get_slide_collision_count() > 0 else null)` |
| Last Slide Normal | The surface direction from the last collision | `(get_last_slide_collision().get_normal() if get_slide_collision_count() > 0 else Vector2.ZERO)` |

### Slide results in 3D (CharacterBody3D)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Is On Wall (3D) | True when this 3D character is pressing against a wall | `{host.}is_on_wall()` |
| Is On Ceiling (3D) | True when this 3D character is touching a ceiling above | `{host.}is_on_ceiling()` |
| Wall Normal (3D) | The direction of the wall a 3D body bumped into | `{host.}get_wall_normal()` |
| Floor Normal (3D) | The slope direction of the floor a 3D body stands on | `{host.}get_floor_normal()` |

### Overlap tests and lists (Area2D)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Overlaps Body | True when this Area2D overlaps the given physics body | `overlaps_body({body})` |
| Overlaps Area | True when this Area2D overlaps the given other area | `overlaps_area({area})` |
| Has Overlapping Bodies | True when this Area2D overlaps any physics body | `has_overlapping_bodies()` |
| Has Overlapping Areas | True when this Area2D overlaps any other area | `has_overlapping_areas()` |
| Overlapping Bodies | The list of physics bodies currently inside this Area2D | `get_overlapping_bodies()` |
| Overlapping Areas | The list of areas currently overlapping this Area2D | `get_overlapping_areas()` |
| Get Monitoring | Whether the area is currently watching for overlaps | `monitoring` |

### Overlap in 3D (Area3D)

| Verb | What it does | Ships as |
|------|--------------|----------|
| Has Overlapping Bodies (3D) | True when this 3D Area overlaps at least one body | `has_overlapping_bodies()` |
| Overlapping Bodies (3D) | The list of physics bodies inside this 3D Area | `get_overlapping_bodies()` |

### Layers, masks and shapes

| Verb | What it does | Ships as | On |
|------|--------------|----------|----|
| Set Collision Layer Bit | Turns a layer on or off - what this object sits on | `set_collision_layer_value({layer}, {enabled})` | CollisionObject2D |
| Set Collision Mask Bit | Turns a mask bit on or off - what this object detects | `set_collision_mask_value({mask}, {enabled})` | CollisionObject2D |
| Is On Collision Layer | True when this object occupies the given layer | `get_collision_layer_value({layer})` | CollisionObject2D |
| Enable Collision Shape | Switches this shape back on so it can collide again | `set_deferred(&"disabled", false)` | CollisionShape2D |
| Disable Collision Shape | Switches this shape off, safely | `set_deferred(&"disabled", true)` | CollisionShape2D |

`Layer` and `Mask` are numbers from 1 to 32. `Enabled` is a true / false dropdown.

### Joints

| Verb | What it does | Ships as | On |
|------|--------------|----------|----|
| Set Joint Body A | Sets the first physics body a joint connects to | `node_a = {target}` | Joint2D |
| Set Joint Body B | Sets the second physics body a joint connects to | `node_b = {target}` | Joint2D |
| Break Joint | Breaks a joint by clearing its second body | `node_b = NodePath("")` | Joint2D |
| Set Disable Collision | Whether the two linked bodies may collide with each other | `disable_collision = {disabled}` | Joint2D |
| Set Pin Softness | How springy a pin joint is - higher is looser | `softness = {softness}` | PinJoint2D |
| Set Spring Rest Length | The distance a spring joint tries to hold | `rest_length = {length}` | DampedSpringJoint2D |
| Set Spring Stiffness | How rigid the spring feels | `stiffness = {stiffness}` | DampedSpringJoint2D |
| Set Spring Damping | How quickly the spring stops bouncing | `damping = {damping}` | DampedSpringJoint2D |
| Set Joint Body A (3D) | The first 3D body a joint connects | `node_a = {target}` | Joint3D |
| Set Joint Body B (3D) | The second 3D body a joint connects | `node_b = {target}` | Joint3D |
| Break Joint (3D) | Snaps a 3D joint apart by clearing its second body | `node_b = NodePath("")` | Joint3D |

`Body A` and `Body B` take a NodePath expression, defaulting to `^"../BodyA"` and `^"../BodyB"`.

### World physics

| Verb | What it does | Ships as |
|------|--------------|----------|
| Set World Gravity (2D) | Changes the whole 2D world's gravity strength | `PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY, {gravity})` |
| Set World Gravity Direction (2D) | Points 2D gravity in a new direction | `PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, {direction})` |
| Set Physics Active (2D) | Pauses or resumes the whole 2D physics space | `PhysicsServer2D.space_set_active(get_viewport().find_world_2d().space, {active})` |
| Set World Gravity (3D) | Changes the whole 3D world's gravity strength | `PhysicsServer3D.area_set_param(get_viewport().find_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY, {gravity})` |
| Set World Gravity Direction (3D) | Points 3D gravity in a new direction | `PhysicsServer3D.area_set_param(get_viewport().find_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, {direction})` |
| Set Physics Active (3D) | Pauses or resumes the whole 3D physics space | `PhysicsServer3D.space_set_active(get_viewport().find_world_3d().space, {active})` |

Gravity defaults to `980.0` in 2D (pixels per second squared) and `9.8` in 3D (metres per second
squared). Direction defaults to `Vector2.DOWN` and `Vector3.DOWN`.

### The performance numbers

| Verb | What it does | Ships as |
|------|--------------|----------|
| Active Bodies (2D) | How many 2D bodies are awake and simulating | `PhysicsServer2D.get_process_info(PhysicsServer2D.INFO_ACTIVE_OBJECTS)` |
| Collision Pairs (2D) | How many 2D collision pairs are processed this step | `PhysicsServer2D.get_process_info(PhysicsServer2D.INFO_COLLISION_PAIRS)` |
| Physics Islands (2D) | How many independent groups of touching 2D bodies | `PhysicsServer2D.get_process_info(PhysicsServer2D.INFO_ISLAND_COUNT)` |
| Active Bodies (3D) | How many 3D bodies are awake and simulating | `PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS)` |
| Collision Pairs (3D) | How many 3D collision pairs are processed this step | `PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_COLLISION_PAIRS)` |
| Physics Islands (3D) | How many independent groups of touching 3D bodies | `PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ISLAND_COUNT)` |
| Physics Interpolation Fraction | How far between physics ticks this frame is, 0 to 1 | `Engine.get_physics_interpolation_fraction()` |

## Use cases

**1. A wall jump.** Move first, then ask, then push away from the wall along its normal.

```gdscript
func _physics_process(delta: float) -> void:
	move_and_slide()
	if is_on_wall() and Input.is_action_just_pressed(&"ui_accept"):
		velocity = get_wall_normal() * 420.0
		velocity.y = -380.0
```

The two rows are the condition **Is On Wall** and an action setting velocity from **Wall Normal**.

**2. A wall slide.** While the character is on a wall and falling, cap the fall speed.

```gdscript
func _physics_process(delta: float) -> void:
	move_and_slide()
	if is_on_wall() and velocity.y > 0.0:
		velocity.y = minf(velocity.y, 60.0)
```

**3. Bonk on the ceiling.** A jump that clips a ceiling should stop rising instead of hovering.

```gdscript
func _physics_process(delta: float) -> void:
	move_and_slide()
	if is_on_ceiling():
		velocity.y = 0.0
```

**4. Align a sprite to the slope.** Floor Normal points out of the ground, so its angle is the slope.

```gdscript
func _physics_process(delta: float) -> void:
	move_and_slide()
	if is_on_floor():
		$Sprite2D.rotation = get_floor_normal().angle() + PI / 2.0
```

**5. Damage whatever you ran into.** Last Slide Collider is null-safe when nothing was hit.

```gdscript
func _physics_process(delta: float) -> void:
	move_and_slide()
	if get_slide_collision_count() > 0:
		var hit = (get_last_slide_collision().get_collider() if get_slide_collision_count() > 0 else null)
		if hit != null and hit.has_method(&"take_damage"):
			hit.call(&"take_damage", 10)
```

**6. Bounce a projectile.** Reflect the velocity off Last Slide Normal.

```gdscript
func _physics_process(delta: float) -> void:
	move_and_slide()
	if get_slide_collision_count() > 0:
		velocity = velocity.bounce((get_last_slide_collision().get_normal() if get_slide_collision_count() > 0 else Vector2.ZERO))
```

**7. A crush check.** On wall AND on ceiling AND on floor in the same step usually means squashed.

```
Every physics frame
  Condition: Is On Wall
  Condition: Is On Ceiling
    -> kill the player
```

**8. A pressure plate.** The plate is an Area2D and only cares that SOMETHING is standing on it.

```gdscript
func _process(delta: float) -> void:
	if has_overlapping_bodies():
		$Sprite2D.frame = 1
	else:
		$Sprite2D.frame = 0
```

**9. Ask about one specific body.** Overlaps Body defaults to the first node in the `player` group, so
the row stands on its own with no scene path baked into it.

```gdscript
func _process(delta: float) -> void:
	if overlaps_body(get_tree().get_first_node_in_group("player")):
		$Prompt.show()
```

**10. An explosion that damages everyone inside.** Loop the list with For Each.

```gdscript
func _on_exploded() -> void:
	for body in get_overlapping_bodies():
		if body.has_method(&"take_damage"):
			body.call(&"take_damage", 40)
```

**11. Two trigger volumes that must agree.** Overlaps Area answers "is that other zone on top of me".

```
Every frame
  Condition: Area2D  Overlaps Area  get_tree().get_first_node_in_group("safe_zones")
    -> stop draining oxygen
```

**12. A ghost power-up.** Stop scanning the enemy layer, then put it back when the buff ends.

```gdscript
func _on_ghost_started() -> void:
	set_collision_mask_value(3, false)


func _on_ghost_ended() -> void:
	set_collision_mask_value(3, true)
```

**13. Drop through a platform.** Leave the player's own layer alone and clear the platform bit.

```gdscript
func _on_drop_pressed() -> void:
	set_collision_mask_value(2, false)
	await get_tree().create_timer(0.25).timeout
	set_collision_mask_value(2, true)
```

**14. Invulnerability frames without hiding anything.** Switch the hurtbox shape off and back on.

```gdscript
func _on_hit() -> void:
	$Hurtbox/CollisionShape2D.set_deferred(&"disabled", true)
	await get_tree().create_timer(1.0).timeout
	$Hurtbox/CollisionShape2D.set_deferred(&"disabled", false)
```

**15. A grappling hook that attaches and lets go.** Point body B at whatever was hit, then clear it.

```gdscript
func _on_hook_hit(target: Node) -> void:
	node_b = target.get_path()


func _on_hook_released() -> void:
	node_b = NodePath("")
```

**16. Tune a rope's feel.** Rest length is the distance it wants; stiffness is how hard it insists.

```gdscript
func _ready() -> void:
	rest_length = 120.0
	stiffness = 30.0
	damping = 2.5
```

**17. A low-gravity level.** One row at the start of the layout changes it for every rigid body.

```gdscript
func _ready() -> void:
	PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY, 260.0)
```

**18. A gravity-flip puzzle.** The direction is a normalized vector, so UP is the whole trick.

```gdscript
func _on_flip_pressed() -> void:
	PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, Vector2.UP)
```

**19. Photo mode.** Freeze the simulation while the camera and the UI keep running.

```gdscript
func _on_photo_mode_entered() -> void:
	PhysicsServer2D.space_set_active(get_viewport().find_world_2d().space, false)
```

**20. A physics performance HUD.** Three expressions in one label.

```gdscript
func _process(delta: float) -> void:
	$Debug.text = "bodies %d  pairs %d  islands %d" % [
		PhysicsServer2D.get_process_info(PhysicsServer2D.INFO_ACTIVE_OBJECTS),
		PhysicsServer2D.get_process_info(PhysicsServer2D.INFO_COLLISION_PAIRS),
		PhysicsServer2D.get_process_info(PhysicsServer2D.INFO_ISLAND_COUNT)
	]
```

**21. Smooth a visual that follows a physics body.** Physics Interpolation Fraction is how far the
current frame sits between the last physics tick and the next, from 0 to 1.

```gdscript
func _process(delta: float) -> void:
	$Trail.global_position = _previous.lerp(_current, Engine.get_physics_interpolation_fraction())
```

### Other use cases

**Ledge grab.** Is On Wall while falling, plus a small raycast above the hands, turns into a hang state that only needs one extra condition row on top of the wall-slide event.

**Conveyor belts.** Read Floor Normal to know which surface you are standing on, then add a constant push along its tangent so the player drifts while idle.

**Breakable chain bridges.** Give each plank a joint, and Break Joint on the one nearest the impact so the bridge collapses from the point of damage outward.

**Underwater sections.** Set World Gravity to a fraction of the project default when the swim area is entered and back to the default on exit, so every crate and barrel floats without any per-object work.

**Overlap-driven spawn safety.** Before dropping an enemy, ask the spawn point's Area2D for Has Overlapping Bodies and pick another point when it is occupied.

## Tips and common mistakes

- **Ask slide questions AFTER the move.** Is On Wall, Is On Ceiling and every Last Slide verb read the
  result of the character body's last move. Put them in the same physics event, below Move And Slide.
  In a per-frame event that never moves the body they report stale answers forever.
- **Slide Collision Count is the guard.** Last Slide Collider and Last Slide Normal already fall back
  to nothing and `Vector2.ZERO`, so they will not crash, but a `Vector2.ZERO` normal silently reflects
  a bounce into nowhere. Gate the event on Slide Collision Count greater than 0 when the answer
  matters.
- **`self` never overlaps itself.** Both Overlaps Body and Overlaps Area say so in their own parameter
  help. Pointing the row at the area it lives on always answers false.
- **Overlaps Body defaults to a GROUP lookup, on purpose.** The shipped default is
  `get_tree().get_first_node_in_group("player")` rather than a tree path, so the row keeps working
  when the scene is rearranged. Replace it with your own group name, not with a `$Path/To/Node`.
- **Layer and mask are not the same bit.** If your enemy stops being hit, check the mask on the thing
  doing the detecting, not the layer on the thing being detected. Is On Collision Layer only answers
  the layer half.
- **Disabling a shape is deferred.** The row uses `set_deferred`, so the shape is still solid for the
  rest of this frame. Do not disable a shape and then, on the next row, expect an overlap test to have
  changed its mind.
- **An Area with monitoring off answers nothing.** Get Monitoring exists precisely so you can tell
  "nothing is overlapping" apart from "this area stopped looking". Some pickup and respawn verbs turn
  monitoring off while the item is away.
- **Break Joint is one-way.** It clears body B; it does not remember what was there. Store the path
  yourself first if the joint has to be re-tied.
- **World gravity does not move a CharacterBody.** Character bodies apply gravity themselves, usually
  from a movement pack's own exported number. Set World Gravity changes rigid bodies. Change both if
  the level is meant to feel light for the player too.
- **Gravity direction must be normalized.** `Vector2.UP` and `Vector2.DOWN` already are. A hand-typed
  `Vector2(0, -3)` scales the strength as well as turning it, which reads as a bug in the direction
  verb.
- **The world-level verbs target the CURRENT viewport's world.** That is the case game events want,
  but it means a row that runs inside a SubViewport changes THAT world, not the main one.
- **Set Physics Active is not a pause menu.** Scripts, timers, input and animation keep running while
  the space is frozen. For a real pause use the game-pause verbs described in the scenes and pausing
  guide.
