## @ace_tags(movement, traversal, platformer)
## @ace_category("Traversal")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/traversal_kit/icon.svg")
class_name TraversalKit
extends Node
## Traversal moves for a CharacterBody2D in one drop: ledge grabs (the two-probe test, then Grab / Climb up / Drop), wall slides, wall jumps away from the wall, wall runs, ladders, vaults, crouching and swimming. It writes velocity and leaves the moving to your mover, so it stacks on top of Platformer movement or your own rows.

## The node this behavior acts on (its parent). Required host: CharacterBody2D.
var host: CharacterBody2D = null

func _enter_tree() -> void:
	host = get_parent() as CharacterBody2D
	if host == null:
		push_warning("TraversalKit behavior requires a CharacterBody2D parent.")

## @ace_trigger
## @ace_name("On Ledge Grabbed")
signal on_ledge_grabbed
## @ace_trigger
## @ace_name("On Climbed")
signal on_climbed
## @ace_trigger
## @ace_name("On Vaulted")
signal on_vaulted
## @ace_trigger
## @ace_name("On Entered Water")
signal on_entered_water
## @ace_trigger
## @ace_name("On Left Water")
signal on_left_water

@export_group("Ledge")
## How far ahead the kit looks for a wall, in pixels.
@export var probe_distance: float = 20.0
## Height above the feet where the forward probe must FIND a wall, in pixels.
@export var wall_probe_height: float = 18.0
## Height above the feet where the second probe must find NOTHING - the gap over the lip that makes a wall a ledge.
@export var grab_height: float = 34.0
## How far below the lip the hands hold once grabbed, in pixels.
@export var hang_offset: float = 6.0
## Upward velocity when Climb Up is called with no duration - the let-go-and-jump exit (negative is up).
@export var climb_jump_velocity: float = -420.0
## How far forward a timed climb (a mantle) carries the body, in pixels.
@export var climb_forward: float = 26.0
## How far up a timed climb carries the body, in pixels.
@export var climb_rise: float = 40.0
## How long after a Drop the kit refuses to see a ledge again, in seconds - without it you re-grab the lip you just let go of.
@export var regrab_delay: float = 0.3
## Which physics layers the ledge, wall and vault probes can see.
@export_flags_2d_physics var probe_mask: int = 1
@export_group("Walls")
## Longest a single wall run may last, in seconds.
@export var wall_run_max_time: float = 1.2
## Downward pull the kit uses for its own vertical moves (wall running, swimming), in pixels per second squared.
@export var gravity: float = 980.0
@export_group("Ladders & Vaults")
## Objects in this group count as ladders - mark a ladder Area2D with it.
@export var ladder_group: String = "ladder"
## Height above the feet where the vault probe must FIND the obstacle (knee height), in pixels.
@export var vault_probe_height: float = 6.0
## Height above the feet that must be CLEAR for the obstacle to be vaultable (chest height), in pixels.
@export var vault_clear_height: float = 34.0
## How far forward Vault Over carries the body, in pixels.
@export var vault_distance: float = 52.0
## How much of its height the collider keeps while crouched.
@export_range(0.1, 1.0, 0.05) var crouch_scale: float = 0.5
@export_group("Water")
## Objects in this group count as water - mark a water Area2D with it.
@export var water_group: String = "water"
@export_group("")
## AI drive: read ai_climb_axis instead of the up/down controls (a sheet or an AI driver steers the climb).
@export var ai_controlled: bool = false

# The AI seam's persistent intent axis - a driver holds it like a held key.
var ai_climb_axis: float = 0.0

# --- Internal state ---
var _facing: int = 1
var _hanging: bool = false
var _hang_point: Vector2 = Vector2.ZERO
var _grab_lock: float = 0.0
# Wall slide / wall run are stamped with the frame they happened on rather than a flag a
# later pass clears: the row that TESTS them may sit above or below the row that calls
# them, and a stamp reads true either way for exactly one frame.
var _wall_slide_frame: int = -10
var _wall_run_frame: int = -10
var _wall_run_timer: float = 0.0
var _wall_run_fall: float = 0.0
var _crouching: bool = false
var _crouch_shape: CollisionShape2D = null
var _crouch_original: Shape2D = null
var _crouch_original_position: Vector2 = Vector2.ZERO
# A timed climb or vault: the kit owns the body until the clock runs out.
var _move_time: float = 0.0
var _move_left: float = 0.0
var _move_from: Vector2 = Vector2.ZERO
var _move_to: Vector2 = Vector2.ZERO
var _move_kind: String = ""
var _in_water: bool = false
var _surface_y: float = 0.0
# The marked-Area lookup shared by ladders and water: the first area in the group the
# host is standing inside, or null.
## @ace_hidden
func _overlapping(group_name: String) -> Area2D:
	if host == null or not host.is_inside_tree() or group_name.is_empty():
		return null
	for node: Node in host.get_tree().get_nodes_in_group(group_name):
		var area: Area2D = node as Area2D
		if area != null and area.monitoring and area.overlaps_body(host):
			return area
	return null
# The host's own collider - the one Crouch shrinks and Stand puts back.
## @ace_hidden
func _own_shape() -> CollisionShape2D:
	if host == null:
		return null
	for child: Node in host.get_children():
		var holder: CollisionShape2D = child as CollisionShape2D
		if holder != null:
			return holder
	return null

func _physics_process(delta: float) -> void:
	_traverse(delta)

## @ace_condition
## @ace_name("Is At A Ledge")
## @ace_category("Traversal")
## @ace_description("True when the forward probe finds a wall at chest height and the higher probe finds nothing - a lip you could hang from. False while already hanging, and for a moment after a Drop so you do not re-grab the lip you just let go of.")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.is_at_a_ledge()")
func is_at_a_ledge() -> bool:
	if _hanging or _grab_lock > 0.0:
		return false
	return _probe(wall_probe_height, probe_distance) and not _probe(grab_height, probe_distance)

## @ace_condition
## @ace_name("Is Hanging")
## @ace_category("Traversal")
## @ace_description("True while the host is hanging from a ledge it grabbed. The kit holds it exactly where it grabbed - gravity cannot pull it off.")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.is_hanging()")
func is_hanging() -> bool:
	return _hanging

## @ace_action
## @ace_featured
## @ace_name("Grab Ledge")
## @ace_category("Traversal")
## @ace_description("Grabs the ledge in front: the host stops dead, holds the lip (a little below it, by Hang Offset) and fires On Ledge Grabbed. Ignored if it is already hanging.")
## @ace_display_template("[b]Grab[/b] the ledge")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.grab_ledge()")
func grab_ledge() -> void:
	if host == null or _hanging:
		return
	_hanging = true
	_hang_point = host.global_position + Vector2(0.0, hang_offset)
	host.global_position = _hang_point
	host.velocity = Vector2.ZERO
	on_ledge_grabbed.emit()

## @ace_action
## @ace_name("Climb Up")
## @ace_category("Traversal")
## @ace_description("Leaves the ledge upward. With no duration it lets go and jumps (Climb Jump Velocity) - the quick platformer exit. With a duration it is a mantle: the host is carried up and over the lip in that many seconds, with nothing else able to move it, and On Climbed fires when it lands on top.")
## @ace_display_template("[b]Climb up[/b] over [b]{duration}[/b] s")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.climb_up({duration})")
func climb_up(duration: float) -> void:
	if host == null or not _hanging:
		return
	_hanging = false
	if duration <= 0.0:
		host.velocity = Vector2(host.velocity.x, climb_jump_velocity)
		on_climbed.emit()
		return
	_move_from = host.global_position
	_move_to = host.global_position + Vector2(float(_facing) * climb_forward, -climb_rise)
	_move_time = duration
	_move_left = duration
	_move_kind = "climb"

## @ace_action
## @ace_name("Drop")
## @ace_category("Traversal")
## @ace_description("Lets go of the ledge and falls. The kit ignores the same lip for Regrab Delay seconds afterwards.")
## @ace_display_template("[b]Drop[/b] from the ledge")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.drop()")
func drop() -> void:
	if not _hanging:
		return
	_hanging = false
	_grab_lock = regrab_delay
	if host != null:
		host.velocity = Vector2.ZERO

## @ace_condition
## @ace_name("Is Wall Sliding")
## @ace_category("Traversal")
## @ace_description("True on the frames a Slide Down Wall actually slowed a fall.")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.is_wall_sliding()")
func is_wall_sliding() -> bool:
	return _recent(_wall_slide_frame)

## @ace_condition
## @ace_name("Is Wall Running")
## @ace_category("Traversal")
## @ace_description("True on the frames a Wall Run is carrying the host along a wall (it stops on its own after Wall Run Max Time).")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.is_wall_running()")
func is_wall_running() -> bool:
	return _recent(_wall_run_frame)

## @ace_action
## @ace_name("Slide Down Wall")
## @ace_category("Traversal")
## @ace_description("Caps the fall while the host is pressed against a wall, so it slides instead of dropping. Does nothing when it is not on a wall or is still moving upward.")
## @ace_display_template("[b]Slide[/b] down the wall at [b]{speed}[/b]")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.slide_down_wall({speed})")
func slide_down_wall(speed: float) -> void:
	if host == null or not host.is_on_wall() or host.velocity.y <= 0.0:
		return
	host.velocity.y = minf(host.velocity.y, speed)
	_wall_slide_frame = Engine.get_physics_frames()

## @ace_action
## @ace_featured
## @ace_name("Wall Jump")
## @ace_category("Traversal")
## @ace_description("Jumps AWAY from the wall: the push goes along the wall's own normal, so the host always leaves the wall it was on, whichever side that was.")
## @ace_display_template("[b]Wall jump[/b] away (push [b]{push}[/b], up [b]{rise}[/b])")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.wall_jump({push}, {rise})")
func wall_jump(push: float, rise: float) -> void:
	if host == null or not host.is_on_wall():
		return
	var away: float = signf(host.get_wall_normal().x)
	if is_zero_approx(away):
		away = -float(_facing)
	host.velocity = Vector2(away * push, -absf(rise))
	_facing = 1 if away > 0.0 else -1
	_wall_slide_frame = -10

## @ace_action
## @ace_name("Wall Run")
## @ace_category("Traversal")
## @ace_description("Runs along the wall: gravity is replaced by the percentage you give, so the host barely sinks while it keeps up speed. It needs to be on a wall, off the floor, and moving at least Min Speed - and it gives out after Wall Run Max Time.")
## @ace_display_template("[b]Wall run[/b] along the wall (gravity [b]{gravity_percent}[/b]%)")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.wall_run({gravity_percent}, {min_speed})")
func wall_run(gravity_percent: float, min_speed: float) -> void:
	if host == null or host.is_on_floor() or not host.is_on_wall():
		return
	if absf(host.velocity.x) < min_speed or _wall_run_timer >= wall_run_max_time:
		return
	var step: float = host.get_physics_process_delta_time()
	_wall_run_timer += step
	_wall_run_fall += gravity * (clampf(gravity_percent, 0.0, 100.0) / 100.0) * step
	host.velocity.y = _wall_run_fall
	_wall_run_frame = Engine.get_physics_frames()

## @ace_condition
## @ace_name("Is On Ladder")
## @ace_category("Traversal")
## @ace_description("True while the host is standing inside an Area2D marked with the ladder group.")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.is_on_ladder()")
func is_on_ladder() -> bool:
	return _overlapping(ladder_group) != null

## @ace_action
## @ace_name("Climb Ladder")
## @ace_category("Traversal")
## @ace_description("Drives the host up or down the ladder at this speed, from the up/down controls (or the AI axis). It writes the vertical speed outright, so gravity is off for as long as you keep calling it.")
## @ace_display_template("[b]Climb[/b] the ladder at [b]{speed}[/b]")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.climb_ladder({speed})")
func climb_ladder(speed: float) -> void:
	if host == null or _overlapping(ladder_group) == null:
		return
	var axis: float = ai_climb_axis if ai_controlled else Input.get_axis(&"ui_down", &"ui_up")
	host.velocity = Vector2(host.velocity.x, -axis * speed)

## @ace_condition
## @ace_name("Is At A Vaultable Obstacle")
## @ace_category("Traversal")
## @ace_description("True when the forward probe finds something at knee height and nothing at chest height - a low obstacle you could throw yourself over.")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.is_at_vaultable()")
func is_at_vaultable() -> bool:
	return _probe(vault_probe_height, probe_distance) and not _probe(vault_clear_height, probe_distance)

## @ace_action
## @ace_name("Vault Over")
## @ace_category("Traversal")
## @ace_description("Carries the host forward over the obstacle in this many seconds. Nothing else moves it while the vault runs, and On Vaulted fires on the far side.")
## @ace_display_template("[b]Vault over[/b] in [b]{duration}[/b] s")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.vault_over({duration})")
func vault_over(duration: float) -> void:
	if host == null or _move_left > 0.0:
		return
	_move_from = host.global_position
	_move_to = host.global_position + Vector2(float(_facing) * vault_distance, 0.0)
	_move_time = maxf(duration, 0.0001)
	_move_left = _move_time
	_move_kind = "vault"
	host.velocity = Vector2.ZERO

## @ace_condition
## @ace_name("Is Crouching")
## @ace_category("Traversal")
## @ace_description("True while the host is crouched (its collider is the short one).")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.is_crouching()")
func is_crouching() -> bool:
	return _crouching

## @ace_action
## @ace_name("Crouch")
## @ace_category("Traversal")
## @ace_description("Crouches: the host's first collision shape is swapped for a copy scaled to Crouch Scale, kept standing on the same feet. The original is put back by Stand, so the shape in your scene is never edited.")
## @ace_display_template("[b]Crouch[/b]")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.crouch()")
func crouch() -> void:
	if host == null or _crouching:
		return
	_crouching = true
	_crouch_shape = _own_shape()
	if _crouch_shape == null or _crouch_shape.shape == null:
		return
	_crouch_original = _crouch_shape.shape
	_crouch_original_position = _crouch_shape.position
	var kept: float = clampf(crouch_scale, 0.1, 1.0)
	var shrunk: Shape2D = _crouch_shape.shape.duplicate()
	if shrunk is RectangleShape2D:
		var box: RectangleShape2D = shrunk as RectangleShape2D
		var lost: float = box.size.y * (1.0 - kept)
		box.size = Vector2(box.size.x, box.size.y * kept)
		_crouch_shape.position = _crouch_original_position + Vector2(0.0, lost * 0.5)
	elif shrunk is CapsuleShape2D:
		var capsule: CapsuleShape2D = shrunk as CapsuleShape2D
		var shed: float = capsule.height * (1.0 - kept)
		capsule.height = maxf(capsule.height * kept, capsule.radius * 2.0)
		_crouch_shape.position = _crouch_original_position + Vector2(0.0, shed * 0.5)
	_crouch_shape.shape = shrunk

## @ace_action
## @ace_name("Stand")
## @ace_category("Traversal")
## @ace_description("Stands back up and puts the original collision shape back exactly as it was.")
## @ace_display_template("[b]Stand[/b] up")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.stand()")
func stand() -> void:
	if not _crouching:
		return
	_crouching = false
	if _crouch_shape != null and _crouch_original != null:
		_crouch_shape.shape = _crouch_original
		_crouch_shape.position = _crouch_original_position
	_crouch_original = null

## @ace_condition
## @ace_name("Is In Water")
## @ace_category("Traversal")
## @ace_description("True while the host is inside an Area2D marked with the water group.")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.is_in_water()")
func is_in_water() -> bool:
	return _in_water

## @ace_condition
## @ace_name("Is Above The Surface")
## @ace_category("Traversal")
## @ace_description("True when the host's own point is above the water line of the area it is in - the test that lets a swimmer breathe, jump out, or hold a boat at the top. Always true out of water.")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.is_above_the_surface()")
func is_above_the_surface() -> bool:
	if host == null:
		return false
	if not _in_water:
		return true
	return host.global_position.y <= _surface_y

## @ace_action
## @ace_featured
## @ace_name("Swim")
## @ace_category("Traversal")
## @ace_description("Swimming instead of falling: only this percentage of the kit's gravity still pulls, and the host sheds this percentage of its speed every physics frame (10 is the classic 0.9 damping). Call it every tick while in water.")
## @ace_display_template("[b]Swim[/b] (gravity [b]{gravity_percent}[/b]%, drag [b]{drag}[/b]%)")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.swim({gravity_percent}, {drag})")
func swim(gravity_percent: float, drag: float) -> void:
	if host == null:
		return
	var step: float = host.get_physics_process_delta_time()
	host.velocity.y += gravity * (clampf(gravity_percent, 0.0, 100.0) / 100.0) * step
	host.velocity *= maxf(0.0, 1.0 - clampf(drag, 0.0, 100.0) / 100.0)

## @ace_expression
## @ace_name("Water Depth")
## @ace_category("Traversal")
## @ace_description("How far below the water line the host is, in pixels (0 out of water or at the surface).")
## @ace_icon("res://eventsheet_addons/traversal_kit/icon.svg")
## @ace_codegen_template("$TraversalKit.water_depth()")
func water_depth() -> float:
	if host == null or not _in_water:
		return 0.0
	return maxf(host.global_position.y - _surface_y, 0.0)

## @ace_hidden
func _feet_offset() -> float:
	# Where the host's feet are, measured from its own point: half the height of its first
	# collider, so every height below means what it says whatever size the body is.
	var holder: CollisionShape2D = _own_shape()
	if holder == null or holder.shape == null:
		return 0.0
	if holder.shape is RectangleShape2D:
		return holder.position.y + (holder.shape as RectangleShape2D).size.y * 0.5
	if holder.shape is CapsuleShape2D:
		return holder.position.y + (holder.shape as CapsuleShape2D).height * 0.5
	if holder.shape is CircleShape2D:
		return holder.position.y + (holder.shape as CircleShape2D).radius
	return holder.position.y

## @ace_hidden
func _probe(height: float, reach: float) -> bool:
	# One forward ray at a height above the feet. The two-probe ledge test is two of these:
	# the low one must hit and the high one must not.
	if host == null or not host.is_inside_tree():
		return false
	var space: PhysicsDirectSpaceState2D = host.get_world_2d().direct_space_state
	var from: Vector2 = host.global_position + Vector2(0.0, _feet_offset() - height)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, from + Vector2(float(_facing) * reach, 0.0), probe_mask)
	query.exclude = [host.get_rid()]
	return not space.intersect_ray(query).is_empty()

## @ace_hidden
func _surface_of(area: Area2D) -> float:
	# The water line: the top edge of the marked area's first collision shape, so Is Above
	# The Surface has something to compare against.
	if area == null:
		return 0.0
	for child: Node in area.get_children():
		var holder: CollisionShape2D = child as CollisionShape2D
		if holder == null or holder.shape == null:
			continue
		var centre: float = holder.global_position.y
		if holder.shape is RectangleShape2D:
			return centre - (holder.shape as RectangleShape2D).size.y * 0.5
		if holder.shape is CircleShape2D:
			return centre - (holder.shape as CircleShape2D).radius
		if holder.shape is CapsuleShape2D:
			return centre - (holder.shape as CapsuleShape2D).height * 0.5
		return centre
	return area.global_position.y

## @ace_hidden
func _recent(stamp: int) -> bool:
	# True for the frame a stamped move happened on and the one after it.
	return stamp >= 0 and Engine.get_physics_frames() - stamp <= 1

## @ace_hidden
func _track_water() -> void:
	# Water bookkeeping: entering and leaving a marked area fire the two triggers, and the
	# surface is measured once on the way in.
	var area: Area2D = _overlapping(water_group)
	if area != null and not _in_water:
		_in_water = true
		_surface_y = _surface_of(area)
		on_entered_water.emit()
	elif area == null and _in_water:
		_in_water = false
		on_left_water.emit()

## @ace_hidden
func _traverse(delta: float) -> void:
	# The per-frame keeper: facing, the timed climb/vault, the hang hold, the wall-run
	# budget and the water watch. Every verb above is called FROM the sheet; this only
	# keeps what they started honest.
	if host == null:
		return
	_grab_lock = maxf(_grab_lock - delta, 0.0)
	if not is_zero_approx(host.velocity.x):
		_facing = 1 if host.velocity.x > 0.0 else -1
	if _move_left > 0.0:
		_move_left = maxf(_move_left - delta, 0.0)
		var travelled: float = 1.0 - (_move_left / maxf(_move_time, 0.0001))
		host.global_position = _move_from.lerp(_move_to, clampf(travelled, 0.0, 1.0))
		host.velocity = Vector2.ZERO
		if _move_left <= 0.0:
			host.global_position = _move_to
			if _move_kind == "climb":
				on_climbed.emit()
			elif _move_kind == "vault":
				on_vaulted.emit()
			_move_kind = ""
		return
	if _hanging:
		host.global_position = _hang_point
		host.velocity = Vector2.ZERO
	if not _recent(_wall_run_frame):
		_wall_run_timer = 0.0
		_wall_run_fall = 0.0
	_track_water()

# Traversal Kit: attach under a CharacterBody2D that already has a mover. Test Is At A Ledge and call Grab Ledge, then Climb Up (with a duration for a mantle) or Drop. Slide Down Wall, Wall Jump and Wall Run build on the wall the body is touching. Mark a ladder Area2D with the ladder group and a water Area2D with the water group, then Climb Ladder and Swim. This pack is an event sheet - extend it by editing it.
