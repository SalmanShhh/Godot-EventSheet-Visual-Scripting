# Pack builder - traversal_kit (one pack per file; run via tools/build_sample_behaviors.gd).
#
# The traversal verbs a platformer grows AFTER jumping: ledge grabs, wall slides, wall jumps,
# wall runs, ladders, vaults, crouching and swimming - one CharacterBody2D behavior whose
# emitted code is the same shape a tutorial hands you, so a hand-written version and this pack
# read as the same event-sheet rows. It never moves the body itself (no move_and_slide): it
# writes velocity and lets whatever mover you already have - Platformer movement, or your own
# rows - do the moving.
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "TraversalKit"
	sheet.class_description = "Traversal moves for a CharacterBody2D in one drop: ledge grabs (the two-probe test, then Grab / Climb up / Drop), wall slides, wall jumps away from the wall, wall runs, ladders, vaults, crouching and swimming. It writes velocity and leaves the moving to your mover, so it stacks on top of Platformer movement or your own rows."
	sheet.addon_category = "Traversal"
	sheet.ace_expose_all_mode = "node"
	sheet.addon_tags = PackedStringArray(["movement", "traversal", "platformer"])

	var about: CommentRow = CommentRow.new()
	about.text = "Traversal Kit: attach under a CharacterBody2D that already has a mover. Test Is At A Ledge and call Grab Ledge, then Climb Up (with a duration for a mantle) or Drop. Slide Down Wall, Wall Jump and Wall Run build on the wall the body is touching. Mark a ladder Area2D with the ladder group and a water Area2D with the water group, then Climb Ladder and Swim. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var knobs: RawCodeRow = RawCodeRow.new()
	knobs.code = "\n".join(_knob_lines())
	sheet.events.append(knobs)

	var plumbing: RawCodeRow = RawCodeRow.new()
	plumbing.code = "\n".join(_plumbing_lines())
	sheet.events.append(plumbing)

	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "_traverse(delta)"
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	_append_ledge(sheet)
	_append_walls(sheet)
	_append_ladders_and_vaults(sheet)
	_append_water(sheet)

	Lib.verb_sentences(sheet, _sentences())
	Lib.feature_verbs(sheet, ["grab_ledge", "wall_jump", "swim"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/traversal_kit/traversal_kit_behavior")


## The Inspector knobs, grouped the way the moves are: Ledge, Walls, Ladders & Vaults, Water.
static func _knob_lines() -> PackedStringArray:
	return PackedStringArray([
		"@export_group(\"Ledge\")",
		"## How far ahead the kit looks for a wall, in pixels.",
		"@export var probe_distance: float = 20.0",
		"## Height above the feet where the forward probe must FIND a wall, in pixels.",
		"@export var wall_probe_height: float = 18.0",
		"## Height above the feet where the second probe must find NOTHING - the gap over the lip that makes a wall a ledge.",
		"@export var grab_height: float = 34.0",
		"## How far below the lip the hands hold once grabbed, in pixels.",
		"@export var hang_offset: float = 6.0",
		"## Upward velocity when Climb Up is called with no duration - the let-go-and-jump exit (negative is up).",
		"@export var climb_jump_velocity: float = -420.0",
		"## How far forward a timed climb (a mantle) carries the body, in pixels.",
		"@export var climb_forward: float = 26.0",
		"## How far up a timed climb carries the body, in pixels.",
		"@export var climb_rise: float = 40.0",
		"## How long after a Drop the kit refuses to see a ledge again, in seconds - without it you re-grab the lip you just let go of.",
		"@export var regrab_delay: float = 0.3",
		"## Which physics layers the ledge, wall and vault probes can see.",
		"@export_flags_2d_physics var probe_mask: int = 1",
		"@export_group(\"Walls\")",
		"## Longest a single wall run may last, in seconds.",
		"@export var wall_run_max_time: float = 1.2",
		"## Downward pull the kit uses for its own vertical moves (wall running, swimming), in pixels per second squared.",
		"@export var gravity: float = 980.0",
		"@export_group(\"Ladders & Vaults\")",
		"## Objects in this group count as ladders - mark a ladder Area2D with it.",
		"@export var ladder_group: String = \"ladder\"",
		"## Height above the feet where the vault probe must FIND the obstacle (knee height), in pixels.",
		"@export var vault_probe_height: float = 6.0",
		"## Height above the feet that must be CLEAR for the obstacle to be vaultable (chest height), in pixels.",
		"@export var vault_clear_height: float = 34.0",
		"## How far forward Vault Over carries the body, in pixels.",
		"@export var vault_distance: float = 52.0",
		"## How much of its height the collider keeps while crouched.",
		"@export_range(0.1, 1.0, 0.05) var crouch_scale: float = 0.5",
		"@export_group(\"Water\")",
		"## Objects in this group count as water - mark a water Area2D with it.",
		"@export var water_group: String = \"water\"",
		"@export_group(\"\")",
		"## AI drive: read ai_climb_axis instead of the up/down controls (a sheet or an AI driver steers the climb).",
		"@export var ai_controlled: bool = false",
		"",
		"# The AI seam's persistent intent axis - a driver holds it like a held key.",
		"var ai_climb_axis: float = 0.0"
	])


## Triggers, internal state, and the shared plumbing every verb leans on: the forward probe,
## the marked-Area lookup, the water line, and the per-frame tick.
static func _plumbing_lines() -> PackedStringArray:
	return PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Ledge Grabbed\")",
		"signal on_ledge_grabbed()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Climbed\")",
		"signal on_climbed()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Vaulted\")",
		"signal on_vaulted()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Entered Water\")",
		"signal on_entered_water()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Left Water\")",
		"signal on_left_water()",
		"",
		"# --- Internal state ---",
		"var _facing: int = 1",
		"var _hanging: bool = false",
		"var _hang_point: Vector2 = Vector2.ZERO",
		"var _grab_lock: float = 0.0",
		"# Wall slide / wall run are stamped with the frame they happened on rather than a flag a",
		"# later pass clears: the row that TESTS them may sit above or below the row that calls",
		"# them, and a stamp reads true either way for exactly one frame.",
		"var _wall_slide_frame: int = -10",
		"var _wall_run_frame: int = -10",
		"var _wall_run_timer: float = 0.0",
		"var _wall_run_fall: float = 0.0",
		"var _crouching: bool = false",
		"var _crouch_shape: CollisionShape2D = null",
		"var _crouch_original: Shape2D = null",
		"var _crouch_original_position: Vector2 = Vector2.ZERO",
		"# A timed climb or vault: the kit owns the body until the clock runs out.",
		"var _move_time: float = 0.0",
		"var _move_left: float = 0.0",
		"var _move_from: Vector2 = Vector2.ZERO",
		"var _move_to: Vector2 = Vector2.ZERO",
		"var _move_kind: String = \"\"",
		"var _in_water: bool = false",
		"var _surface_y: float = 0.0",
		"",
		"# Where the host's feet are, measured from its own point: half the height of its first",
		"# collider, so every height below means what it says whatever size the body is.",
		"## @ace_hidden",
		"func _feet_offset() -> float:",
		"\tvar holder: CollisionShape2D = _own_shape()",
		"\tif holder == null or holder.shape == null:",
		"\t\treturn 0.0",
		"\tif holder.shape is RectangleShape2D:",
		"\t\treturn holder.position.y + (holder.shape as RectangleShape2D).size.y * 0.5",
		"\tif holder.shape is CapsuleShape2D:",
		"\t\treturn holder.position.y + (holder.shape as CapsuleShape2D).height * 0.5",
		"\tif holder.shape is CircleShape2D:",
		"\t\treturn holder.position.y + (holder.shape as CircleShape2D).radius",
		"\treturn holder.position.y",
		"",
		"# One forward ray at a height above the feet. The two-probe ledge test is two of these:",
		"# the low one must hit and the high one must not.",
		"## @ace_hidden",
		"func _probe(height: float, reach: float) -> bool:",
		"\tif host == null or not host.is_inside_tree():",
		"\t\treturn false",
		"\tvar space: PhysicsDirectSpaceState2D = host.get_world_2d().direct_space_state",
		"\tvar from: Vector2 = host.global_position + Vector2(0.0, _feet_offset() - height)",
		"\tvar query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, from + Vector2(float(_facing) * reach, 0.0), probe_mask)",
		"\tquery.exclude = [host.get_rid()]",
		"\treturn not space.intersect_ray(query).is_empty()",
		"",
		"# The marked-Area lookup shared by ladders and water: the first area in the group the",
		"# host is standing inside, or null.",
		"## @ace_hidden",
		"func _overlapping(group_name: String) -> Area2D:",
		"\tif host == null or not host.is_inside_tree() or group_name.is_empty():",
		"\t\treturn null",
		"\tfor node: Node in host.get_tree().get_nodes_in_group(group_name):",
		"\t\tvar area: Area2D = node as Area2D",
		"\t\tif area != null and area.monitoring and area.overlaps_body(host):",
		"\t\t\treturn area",
		"\treturn null",
		"",
		"# The water line: the top edge of the marked area's first collision shape, so Is Above",
		"# The Surface has something to compare against.",
		"## @ace_hidden",
		"func _surface_of(area: Area2D) -> float:",
		"\tif area == null:",
		"\t\treturn 0.0",
		"\tfor child: Node in area.get_children():",
		"\t\tvar holder: CollisionShape2D = child as CollisionShape2D",
		"\t\tif holder == null or holder.shape == null:",
		"\t\t\tcontinue",
		"\t\tvar centre: float = holder.global_position.y",
		"\t\tif holder.shape is RectangleShape2D:",
		"\t\t\treturn centre - (holder.shape as RectangleShape2D).size.y * 0.5",
		"\t\tif holder.shape is CircleShape2D:",
		"\t\t\treturn centre - (holder.shape as CircleShape2D).radius",
		"\t\tif holder.shape is CapsuleShape2D:",
		"\t\t\treturn centre - (holder.shape as CapsuleShape2D).height * 0.5",
		"\t\treturn centre",
		"\treturn area.global_position.y",
		"",
		"# The host's own collider - the one Crouch shrinks and Stand puts back.",
		"## @ace_hidden",
		"func _own_shape() -> CollisionShape2D:",
		"\tif host == null:",
		"\t\treturn null",
		"\tfor child: Node in host.get_children():",
		"\t\tvar holder: CollisionShape2D = child as CollisionShape2D",
		"\t\tif holder != null:",
		"\t\t\treturn holder",
		"\treturn null",
		"",
		"# True for the frame a stamped move happened on and the one after it.",
		"## @ace_hidden",
		"func _recent(stamp: int) -> bool:",
		"\treturn stamp >= 0 and Engine.get_physics_frames() - stamp <= 1",
		"",
		"# Water bookkeeping: entering and leaving a marked area fire the two triggers, and the",
		"# surface is measured once on the way in.",
		"## @ace_hidden",
		"func _track_water() -> void:",
		"\tvar area: Area2D = _overlapping(water_group)",
		"\tif area != null and not _in_water:",
		"\t\t_in_water = true",
		"\t\t_surface_y = _surface_of(area)",
		"\t\ton_entered_water.emit()",
		"\telif area == null and _in_water:",
		"\t\t_in_water = false",
		"\t\ton_left_water.emit()",
		"",
		"# The per-frame keeper: facing, the timed climb/vault, the hang hold, the wall-run",
		"# budget and the water watch. Every verb above is called FROM the sheet; this only",
		"# keeps what they started honest.",
		"## @ace_hidden",
		"func _traverse(delta: float) -> void:",
		"\tif host == null:",
		"\t\treturn",
		"\t_grab_lock = maxf(_grab_lock - delta, 0.0)",
		"\tif not is_zero_approx(host.velocity.x):",
		"\t\t_facing = 1 if host.velocity.x > 0.0 else -1",
		"\tif _move_left > 0.0:",
		"\t\t_move_left = maxf(_move_left - delta, 0.0)",
		"\t\tvar travelled: float = 1.0 - (_move_left / maxf(_move_time, 0.0001))",
		"\t\thost.global_position = _move_from.lerp(_move_to, clampf(travelled, 0.0, 1.0))",
		"\t\thost.velocity = Vector2.ZERO",
		"\t\tif _move_left <= 0.0:",
		"\t\t\thost.global_position = _move_to",
		"\t\t\tif _move_kind == \"climb\":",
		"\t\t\t\ton_climbed.emit()",
		"\t\t\telif _move_kind == \"vault\":",
		"\t\t\t\ton_vaulted.emit()",
		"\t\t\t_move_kind = \"\"",
		"\t\treturn",
		"\tif _hanging:",
		"\t\thost.global_position = _hang_point",
		"\t\thost.velocity = Vector2.ZERO",
		"\tif not _recent(_wall_run_frame):",
		"\t\t_wall_run_timer = 0.0",
		"\t\t_wall_run_fall = 0.0",
		"\t_track_water()"
	])


## The ledge verbs: the two-probe test, the grab, the two exits.
static func _append_ledge(sheet: EventSheetResource) -> void:
	Lib.condition(sheet, "is_at_a_ledge", "Is At A Ledge", "Traversal",
		"True when the forward probe finds a wall at chest height and the higher probe finds nothing - a lip you could hang from. False while already hanging, and for a moment after a Drop so you do not re-grab the lip you just let go of.",
		[], "\n".join(PackedStringArray([
			"if _hanging or _grab_lock > 0.0:",
			"\treturn false",
			"return _probe(wall_probe_height, probe_distance) and not _probe(grab_height, probe_distance)"
		])))
	Lib.condition(sheet, "is_hanging", "Is Hanging", "Traversal",
		"True while the host is hanging from a ledge it grabbed. The kit holds it exactly where it grabbed - gravity cannot pull it off.",
		[], "return _hanging")
	Lib.append_function(sheet, "grab_ledge", "Grab Ledge", "Traversal",
		"Grabs the ledge in front: the host stops dead, holds the lip (a little below it, by Hang Offset) and fires On Ledge Grabbed. Ignored if it is already hanging.",
		[], "\n".join(PackedStringArray([
			"if host == null or _hanging:",
			"\treturn",
			"_hanging = true",
			"_hang_point = host.global_position + Vector2(0.0, hang_offset)",
			"host.global_position = _hang_point",
			"host.velocity = Vector2.ZERO",
			"on_ledge_grabbed.emit()"
		])))
	Lib.append_function(sheet, "climb_up", "Climb Up", "Traversal",
		"Leaves the ledge upward. With no duration it lets go and jumps (Climb Jump Velocity) - the quick platformer exit. With a duration it is a mantle: the host is carried up and over the lip in that many seconds, with nothing else able to move it, and On Climbed fires when it lands on top.",
		[["duration", "float"]], "\n".join(PackedStringArray([
			"if host == null or not _hanging:",
			"\treturn",
			"_hanging = false",
			"if duration <= 0.0:",
			"\thost.velocity = Vector2(host.velocity.x, climb_jump_velocity)",
			"\ton_climbed.emit()",
			"\treturn",
			"_move_from = host.global_position",
			"_move_to = host.global_position + Vector2(float(_facing) * climb_forward, -climb_rise)",
			"_move_time = duration",
			"_move_left = duration",
			"_move_kind = \"climb\""
		])))
	_default(sheet, "duration", "0.0")
	Lib.append_function(sheet, "drop", "Drop", "Traversal",
		"Lets go of the ledge and falls. The kit ignores the same lip for Regrab Delay seconds afterwards.",
		[], "\n".join(PackedStringArray([
			"if not _hanging:",
			"\treturn",
			"_hanging = false",
			"_grab_lock = regrab_delay",
			"if host != null:",
			"\thost.velocity = Vector2.ZERO"
		])))


## The wall verbs, all three built on the wall the body is already touching.
static func _append_walls(sheet: EventSheetResource) -> void:
	Lib.condition(sheet, "is_wall_sliding", "Is Wall Sliding", "Traversal",
		"True on the frames a Slide Down Wall actually slowed a fall.",
		[], "return _recent(_wall_slide_frame)")
	Lib.condition(sheet, "is_wall_running", "Is Wall Running", "Traversal",
		"True on the frames a Wall Run is carrying the host along a wall (it stops on its own after Wall Run Max Time).",
		[], "return _recent(_wall_run_frame)")
	Lib.append_function(sheet, "slide_down_wall", "Slide Down Wall", "Traversal",
		"Caps the fall while the host is pressed against a wall, so it slides instead of dropping. Does nothing when it is not on a wall or is still moving upward.",
		[["speed", "float"]], "\n".join(PackedStringArray([
			"if host == null or not host.is_on_wall() or host.velocity.y <= 0.0:",
			"\treturn",
			"host.velocity.y = minf(host.velocity.y, speed)",
			"_wall_slide_frame = Engine.get_physics_frames()"
		])))
	_default(sheet, "speed", "60.0")
	Lib.append_function(sheet, "wall_jump", "Wall Jump", "Traversal",
		"Jumps AWAY from the wall: the push goes along the wall's own normal, so the host always leaves the wall it was on, whichever side that was.",
		[["push", "float"], ["rise", "float"]], "\n".join(PackedStringArray([
			"if host == null or not host.is_on_wall():",
			"\treturn",
			"var away: float = signf(host.get_wall_normal().x)",
			"if is_zero_approx(away):",
			"\taway = -float(_facing)",
			"host.velocity = Vector2(away * push, -absf(rise))",
			"_facing = 1 if away > 0.0 else -1",
			"_wall_slide_frame = -10"
		])))
	_default(sheet, "push", "300.0")
	_default(sheet, "rise", "500.0")
	Lib.append_function(sheet, "wall_run", "Wall Run", "Traversal",
		"Runs along the wall: gravity is replaced by the percentage you give, so the host barely sinks while it keeps up speed. It needs to be on a wall, off the floor, and moving at least Min Speed - and it gives out after Wall Run Max Time.",
		[["gravity_percent", "float"], ["min_speed", "float"]], "\n".join(PackedStringArray([
			"if host == null or host.is_on_floor() or not host.is_on_wall():",
			"\treturn",
			"if absf(host.velocity.x) < min_speed or _wall_run_timer >= wall_run_max_time:",
			"\treturn",
			"var step: float = host.get_physics_process_delta_time()",
			"_wall_run_timer += step",
			"_wall_run_fall += gravity * (clampf(gravity_percent, 0.0, 100.0) / 100.0) * step",
			"host.velocity.y = _wall_run_fall",
			"_wall_run_frame = Engine.get_physics_frames()"
		])))
	_default(sheet, "gravity_percent", "20.0")
	_default(sheet, "min_speed", "120.0")


## The small verbs: ladders, vaults, crouching.
static func _append_ladders_and_vaults(sheet: EventSheetResource) -> void:
	Lib.condition(sheet, "is_on_ladder", "Is On Ladder", "Traversal",
		"True while the host is standing inside an Area2D marked with the ladder group.",
		[], "return _overlapping(ladder_group) != null")
	Lib.append_function(sheet, "climb_ladder", "Climb Ladder", "Traversal",
		"Drives the host up or down the ladder at this speed, from the up/down controls (or the AI axis). It writes the vertical speed outright, so gravity is off for as long as you keep calling it.",
		[["speed", "float"]], "\n".join(PackedStringArray([
			"if host == null or _overlapping(ladder_group) == null:",
			"\treturn",
			"var axis: float = ai_climb_axis if ai_controlled else Input.get_axis(&\"ui_down\", &\"ui_up\")",
			"host.velocity = Vector2(host.velocity.x, -axis * speed)"
		])))
	_default(sheet, "speed", "120.0")
	Lib.condition(sheet, "is_at_vaultable", "Is At A Vaultable Obstacle", "Traversal",
		"True when the forward probe finds something at knee height and nothing at chest height - a low obstacle you could throw yourself over.",
		[], "return _probe(vault_probe_height, probe_distance) and not _probe(vault_clear_height, probe_distance)")
	Lib.append_function(sheet, "vault_over", "Vault Over", "Traversal",
		"Carries the host forward over the obstacle in this many seconds. Nothing else moves it while the vault runs, and On Vaulted fires on the far side.",
		[["duration", "float"]], "\n".join(PackedStringArray([
			"if host == null or _move_left > 0.0:",
			"\treturn",
			"_move_from = host.global_position",
			"_move_to = host.global_position + Vector2(float(_facing) * vault_distance, 0.0)",
			"_move_time = maxf(duration, 0.0001)",
			"_move_left = _move_time",
			"_move_kind = \"vault\"",
			"host.velocity = Vector2.ZERO"
		])))
	_default(sheet, "duration", "0.4")
	Lib.condition(sheet, "is_crouching", "Is Crouching", "Traversal",
		"True while the host is crouched (its collider is the short one).",
		[], "return _crouching")
	Lib.append_function(sheet, "crouch", "Crouch", "Traversal",
		"Crouches: the host's first collision shape is swapped for a copy scaled to Crouch Scale, kept standing on the same feet. The original is put back by Stand, so the shape in your scene is never edited.",
		[], "\n".join(PackedStringArray([
			"if host == null or _crouching:",
			"\treturn",
			"_crouching = true",
			"_crouch_shape = _own_shape()",
			"if _crouch_shape == null or _crouch_shape.shape == null:",
			"\treturn",
			"_crouch_original = _crouch_shape.shape",
			"_crouch_original_position = _crouch_shape.position",
			"var kept: float = clampf(crouch_scale, 0.1, 1.0)",
			"var shrunk: Shape2D = _crouch_shape.shape.duplicate()",
			"if shrunk is RectangleShape2D:",
			"\tvar box: RectangleShape2D = shrunk as RectangleShape2D",
			"\tvar lost: float = box.size.y * (1.0 - kept)",
			"\tbox.size = Vector2(box.size.x, box.size.y * kept)",
			"\t_crouch_shape.position = _crouch_original_position + Vector2(0.0, lost * 0.5)",
			"elif shrunk is CapsuleShape2D:",
			"\tvar capsule: CapsuleShape2D = shrunk as CapsuleShape2D",
			"\tvar shed: float = capsule.height * (1.0 - kept)",
			"\tcapsule.height = maxf(capsule.height * kept, capsule.radius * 2.0)",
			"\t_crouch_shape.position = _crouch_original_position + Vector2(0.0, shed * 0.5)",
			"_crouch_shape.shape = shrunk"
		])))
	Lib.append_function(sheet, "stand", "Stand", "Traversal",
		"Stands back up and puts the original collision shape back exactly as it was.",
		[], "\n".join(PackedStringArray([
			"if not _crouching:",
			"\treturn",
			"_crouching = false",
			"if _crouch_shape != null and _crouch_original != null:",
			"\t_crouch_shape.shape = _crouch_original",
			"\t_crouch_shape.position = _crouch_original_position",
			"_crouch_original = null"
		])))


## Water: the marked area, the two triggers, and swimming.
static func _append_water(sheet: EventSheetResource) -> void:
	Lib.condition(sheet, "is_in_water", "Is In Water", "Traversal",
		"True while the host is inside an Area2D marked with the water group.",
		[], "return _in_water")
	Lib.condition(sheet, "is_above_the_surface", "Is Above The Surface", "Traversal",
		"True when the host's own point is above the water line of the area it is in - the test that lets a swimmer breathe, jump out, or hold a boat at the top. Always true out of water.",
		[], "\n".join(PackedStringArray([
			"if host == null:",
			"\treturn false",
			"if not _in_water:",
			"\treturn true",
			"return host.global_position.y <= _surface_y"
		])))
	Lib.append_function(sheet, "swim", "Swim", "Traversal",
		"Swimming instead of falling: only this percentage of the kit's gravity still pulls, and the host sheds this percentage of its speed every physics frame (10 is the classic 0.9 damping). Call it every tick while in water.",
		[["gravity_percent", "float"], ["drag", "float"]], "\n".join(PackedStringArray([
			"if host == null:",
			"\treturn",
			"var step: float = host.get_physics_process_delta_time()",
			"host.velocity.y += gravity * (clampf(gravity_percent, 0.0, 100.0) / 100.0) * step",
			"host.velocity *= maxf(0.0, 1.0 - clampf(drag, 0.0, 100.0) / 100.0)"
		])))
	_default(sheet, "gravity_percent", "20.0")
	_default(sheet, "drag", "10.0")
	Lib.number(sheet, "water_depth", "Water Depth", "Traversal",
		"How far below the water line the host is, in pixels (0 out of water or at the surface).",
		[], "\n".join(PackedStringArray([
			"if host == null or not _in_water:",
			"\treturn 0.0",
			"return maxf(host.global_position.y - _surface_y, 0.0)"
		])), TYPE_FLOAT)


## The row SENTENCES - what each verb reads as on the sheet.
static func _sentences() -> Dictionary:
	return {
		"grab_ledge": "[b]Grab[/b] the ledge",
		"climb_up": "[b]Climb up[/b] over [b]{duration}[/b] s",
		"drop": "[b]Drop[/b] from the ledge",
		"slide_down_wall": "[b]Slide[/b] down the wall at [b]{speed}[/b]",
		"wall_jump": "[b]Wall jump[/b] away (push [b]{push}[/b], up [b]{rise}[/b])",
		"wall_run": "[b]Wall run[/b] along the wall (gravity [b]{gravity_percent}[/b]%)",
		"climb_ladder": "[b]Climb[/b] the ladder at [b]{speed}[/b]",
		"vault_over": "[b]Vault over[/b] in [b]{duration}[/b] s",
		"crouch": "[b]Crouch[/b]",
		"stand": "[b]Stand[/b] up",
		"swim": "[b]Swim[/b] (gravity [b]{gravity_percent}[/b]%, drag [b]{drag}[/b]%)"
	}


## Pre-fills the last-appended ACE's parameter default (authoring-time metadata only).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value
