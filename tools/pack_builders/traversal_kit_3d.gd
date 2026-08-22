# Pack builder - traversal_kit_3d (one pack per file; run via tools/build_sample_behaviors.gd).
#
# The 3D twin of the Traversal Kit: the same words - ledge, wall, ladder, vault, crouch, water -
# on a CharacterBody3D, in metres, with +Y up. Like the 2D kit it never moves the body itself
# (no move_and_slide): it writes velocity and lets your mover - the FPS Controller, or your own
# rows - do the moving. It adds one verb the 2D kit has no use for: Float, the buoyancy push.
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody3D"
	sheet.custom_class_name = "TraversalKit3D"
	sheet.class_description = "Traversal moves for a CharacterBody3D in one drop: ledge grabs (the two-probe test, then Grab / Climb up / Drop), wall slides, wall jumps away from the wall, wall runs, ladders, vaults, crouching, swimming and buoyancy. It writes velocity and leaves the moving to your mover, so it stacks on top of the FPS Controller or your own rows."
	sheet.addon_category = "Traversal 3D"
	sheet.ace_expose_all_mode = "node"
	sheet.addon_tags = PackedStringArray(["movement", "traversal", "3d"])

	var about: CommentRow = CommentRow.new()
	about.text = "Traversal Kit 3D: attach under a CharacterBody3D that already has a mover. Test Is At A Ledge and call Grab Ledge, then Climb Up (with a duration for a mantle) or Drop. Slide Down Wall, Wall Jump and Wall Run build on the wall the body is touching. Mark a ladder Area3D with the ladder group and a water Area3D with the water group, then Climb Ladder, Swim and Float. This pack is an event sheet - extend it by editing it."
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
	return Lib.save_pack(sheet, "res://eventsheet_addons/traversal_kit_3d/traversal_kit_3d_behavior")


## The Inspector knobs, in metres, grouped the way the moves are.
static func _knob_lines() -> PackedStringArray:
	return PackedStringArray([
		"@export_group(\"Ledge\")",
		"## How far ahead the kit looks for a wall, in metres.",
		"@export var probe_distance: float = 0.6",
		"## Height above the feet where the forward probe must FIND a wall, in metres.",
		"@export var wall_probe_height: float = 1.0",
		"## Height above the feet where the second probe must find NOTHING - the gap over the lip that makes a wall a ledge.",
		"@export var grab_height: float = 1.9",
		"## How far below the lip the hands hold once grabbed, in metres.",
		"@export var hang_offset: float = 0.3",
		"## Upward velocity when Climb Up is called with no duration - the let-go-and-jump exit.",
		"@export var climb_jump_velocity: float = 4.5",
		"## How far forward a timed climb (a mantle) carries the body, in metres.",
		"@export var climb_forward: float = 0.8",
		"## How far up a timed climb carries the body, in metres.",
		"@export var climb_rise: float = 1.6",
		"## How long after a Drop the kit refuses to see a ledge again, in seconds - without it you re-grab the lip you just let go of.",
		"@export var regrab_delay: float = 0.3",
		"## Which physics layers the ledge, wall and vault probes can see.",
		"@export_flags_3d_physics var probe_mask: int = 1",
		"@export_group(\"Walls\")",
		"## Longest a single wall run may last, in seconds.",
		"@export var wall_run_max_time: float = 1.2",
		"## Downward pull the kit uses for its own vertical moves (wall running, swimming), in metres per second squared.",
		"@export var gravity: float = 9.8",
		"@export_group(\"Ladders & Vaults\")",
		"## Objects in this group count as ladders - mark a ladder Area3D with it.",
		"@export var ladder_group: String = \"ladder\"",
		"## Height above the feet where the vault probe must FIND the obstacle (knee height), in metres.",
		"@export var vault_probe_height: float = 0.3",
		"## Height above the feet that must be CLEAR for the obstacle to be vaultable (chest height), in metres.",
		"@export var vault_clear_height: float = 1.0",
		"## How far forward Vault Over carries the body, in metres.",
		"@export var vault_distance: float = 1.6",
		"## How much of its height the collider keeps while crouched.",
		"@export_range(0.1, 1.0, 0.05) var crouch_scale: float = 0.5",
		"@export_group(\"Water\")",
		"## Objects in this group count as water - mark a water Area3D with it.",
		"@export var water_group: String = \"water\"",
		"@export_group(\"\")",
		"## AI drive: read ai_climb_axis instead of the up/down controls (a sheet or an AI driver steers the climb).",
		"@export var ai_controlled: bool = false",
		"",
		"# The AI seam's persistent intent axis - a driver holds it like a held key.",
		"var ai_climb_axis: float = 0.0"
	])


## Triggers, internal state, and the shared plumbing every verb leans on.
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
		"var _facing_dir: Vector3 = Vector3.ZERO",
		"var _hanging: bool = false",
		"var _hang_point: Vector3 = Vector3.ZERO",
		"var _grab_lock: float = 0.0",
		"# Wall slide / wall run are stamped with the frame they happened on rather than a flag a",
		"# later pass clears: the row that TESTS them may sit above or below the row that calls",
		"# them, and a stamp reads true either way for exactly one frame.",
		"var _wall_slide_frame: int = -10",
		"var _wall_run_frame: int = -10",
		"var _wall_run_timer: float = 0.0",
		"var _wall_run_fall: float = 0.0",
		"var _crouching: bool = false",
		"var _crouch_shape: CollisionShape3D = null",
		"var _crouch_original: Shape3D = null",
		"var _crouch_original_position: Vector3 = Vector3.ZERO",
		"# A timed climb or vault: the kit owns the body until the clock runs out.",
		"var _move_time: float = 0.0",
		"var _move_left: float = 0.0",
		"var _move_from: Vector3 = Vector3.ZERO",
		"var _move_to: Vector3 = Vector3.ZERO",
		"var _move_kind: String = \"\"",
		"var _in_water: bool = false",
		"var _surface_y: float = 0.0",
		"",
		"# Which way the body is facing on the floor plane: the way it is moving, or the way it",
		"# is turned when it is standing still.",
		"## @ace_hidden",
		"func _forward() -> Vector3:",
		"\tif _facing_dir.length_squared() > 0.01:",
		"\t\treturn _facing_dir",
		"\tif host == null:",
		"\t\treturn Vector3.FORWARD",
		"\tvar turned: Vector3 = -host.global_transform.basis.z",
		"\tturned.y = 0.0",
		"\treturn turned.normalized() if turned.length_squared() > 0.001 else Vector3.FORWARD",
		"",
		"# Where the host's feet are, measured from its own point: half the height of its first",
		"# collider, so every height below means what it says whatever size the body is.",
		"## @ace_hidden",
		"func _feet_offset() -> float:",
		"\tvar holder: CollisionShape3D = _own_shape()",
		"\tif holder == null or holder.shape == null:",
		"\t\treturn 0.0",
		"\tif holder.shape is BoxShape3D:",
		"\t\treturn holder.position.y - (holder.shape as BoxShape3D).size.y * 0.5",
		"\tif holder.shape is CapsuleShape3D:",
		"\t\treturn holder.position.y - (holder.shape as CapsuleShape3D).height * 0.5",
		"\tif holder.shape is SphereShape3D:",
		"\t\treturn holder.position.y - (holder.shape as SphereShape3D).radius",
		"\treturn holder.position.y",
		"",
		"# One forward ray at a height above the feet. The two-probe ledge test is two of these:",
		"# the low one must hit and the high one must not.",
		"## @ace_hidden",
		"func _probe(height: float, reach: float) -> bool:",
		"\tif host == null or not host.is_inside_tree():",
		"\t\treturn false",
		"\tvar space: PhysicsDirectSpaceState3D = host.get_world_3d().direct_space_state",
		"\tvar from: Vector3 = host.global_position + Vector3(0.0, _feet_offset() + height, 0.0)",
		"\tvar query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + _forward() * reach, probe_mask)",
		"\tquery.exclude = [host.get_rid()]",
		"\treturn not space.intersect_ray(query).is_empty()",
		"",
		"# The marked-Area lookup shared by ladders and water: the first area in the group the",
		"# host is standing inside, or null.",
		"## @ace_hidden",
		"func _overlapping(group_name: String) -> Area3D:",
		"\tif host == null or not host.is_inside_tree() or group_name.is_empty():",
		"\t\treturn null",
		"\tfor node: Node in host.get_tree().get_nodes_in_group(group_name):",
		"\t\tvar area: Area3D = node as Area3D",
		"\t\tif area != null and area.monitoring and area.overlaps_body(host):",
		"\t\t\treturn area",
		"\treturn null",
		"",
		"# The water line: the top face of the marked area's first collision shape, so Is Above",
		"# The Surface and Float have something to measure against.",
		"## @ace_hidden",
		"func _surface_of(area: Area3D) -> float:",
		"\tif area == null:",
		"\t\treturn 0.0",
		"\tfor child: Node in area.get_children():",
		"\t\tvar holder: CollisionShape3D = child as CollisionShape3D",
		"\t\tif holder == null or holder.shape == null:",
		"\t\t\tcontinue",
		"\t\tvar centre: float = holder.global_position.y",
		"\t\tif holder.shape is BoxShape3D:",
		"\t\t\treturn centre + (holder.shape as BoxShape3D).size.y * 0.5",
		"\t\tif holder.shape is SphereShape3D:",
		"\t\t\treturn centre + (holder.shape as SphereShape3D).radius",
		"\t\tif holder.shape is CapsuleShape3D:",
		"\t\t\treturn centre + (holder.shape as CapsuleShape3D).height * 0.5",
		"\t\treturn centre",
		"\treturn area.global_position.y",
		"",
		"# The host's own collider - the one Crouch shrinks and Stand puts back.",
		"## @ace_hidden",
		"func _own_shape() -> CollisionShape3D:",
		"\tif host == null:",
		"\t\treturn null",
		"\tfor child: Node in host.get_children():",
		"\t\tvar holder: CollisionShape3D = child as CollisionShape3D",
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
		"\tvar area: Area3D = _overlapping(water_group)",
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
		"\tvar flat: Vector3 = Vector3(host.velocity.x, 0.0, host.velocity.z)",
		"\tif flat.length_squared() > 0.04:",
		"\t\t_facing_dir = flat.normalized()",
		"\tif _move_left > 0.0:",
		"\t\t_move_left = maxf(_move_left - delta, 0.0)",
		"\t\tvar travelled: float = 1.0 - (_move_left / maxf(_move_time, 0.0001))",
		"\t\thost.global_position = _move_from.lerp(_move_to, clampf(travelled, 0.0, 1.0))",
		"\t\thost.velocity = Vector3.ZERO",
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
		"\t\thost.velocity = Vector3.ZERO",
		"\tif not _recent(_wall_run_frame):",
		"\t\t_wall_run_timer = 0.0",
		"\t\t_wall_run_fall = 0.0",
		"\t_track_water()"
	])


## Y7 - the ledge verbs: the two-probe test, the grab, the two exits.
static func _append_ledge(sheet: EventSheetResource) -> void:
	Lib.condition(sheet, "is_at_a_ledge", "Is At A Ledge", "Traversal 3D",
		"True when the forward probe finds a wall at chest height and the higher probe finds nothing - a lip you could hang from. False while already hanging, and for a moment after a Drop so you do not re-grab the lip you just let go of.",
		[], "\n".join(PackedStringArray([
			"if _hanging or _grab_lock > 0.0:",
			"\treturn false",
			"return _probe(wall_probe_height, probe_distance) and not _probe(grab_height, probe_distance)"
		])))
	Lib.condition(sheet, "is_hanging", "Is Hanging", "Traversal 3D",
		"True while the host is hanging from a ledge it grabbed. The kit holds it exactly where it grabbed - gravity cannot pull it off.",
		[], "return _hanging")
	Lib.append_function(sheet, "grab_ledge", "Grab Ledge", "Traversal 3D",
		"Grabs the ledge in front: the host stops dead, holds the lip (a little below it, by Hang Offset) and fires On Ledge Grabbed. Ignored if it is already hanging.",
		[], "\n".join(PackedStringArray([
			"if host == null or _hanging:",
			"\treturn",
			"_hanging = true",
			"_hang_point = host.global_position - Vector3(0.0, hang_offset, 0.0)",
			"host.global_position = _hang_point",
			"host.velocity = Vector3.ZERO",
			"on_ledge_grabbed.emit()"
		])))
	Lib.append_function(sheet, "climb_up", "Climb Up", "Traversal 3D",
		"Leaves the ledge upward. With no duration it lets go and jumps (Climb Jump Velocity) - the quick exit. With a duration it is a mantle: the host is carried up and over the lip in that many seconds, with nothing else able to move it, and On Climbed fires when it lands on top.",
		[["duration", "float"]], "\n".join(PackedStringArray([
			"if host == null or not _hanging:",
			"\treturn",
			"_hanging = false",
			"if duration <= 0.0:",
			"\thost.velocity = Vector3(host.velocity.x, climb_jump_velocity, host.velocity.z)",
			"\ton_climbed.emit()",
			"\treturn",
			"_move_from = host.global_position",
			"_move_to = host.global_position + _forward() * climb_forward + Vector3(0.0, climb_rise, 0.0)",
			"_move_time = duration",
			"_move_left = duration",
			"_move_kind = \"climb\""
		])))
	_default(sheet, "duration", "0.0")
	Lib.append_function(sheet, "drop", "Drop", "Traversal 3D",
		"Lets go of the ledge and falls. The kit ignores the same lip for Regrab Delay seconds afterwards.",
		[], "\n".join(PackedStringArray([
			"if not _hanging:",
			"\treturn",
			"_hanging = false",
			"_grab_lock = regrab_delay",
			"if host != null:",
			"\thost.velocity = Vector3.ZERO"
		])))


## Y8 - the wall verbs, all three built on the wall the body is already touching.
static func _append_walls(sheet: EventSheetResource) -> void:
	Lib.condition(sheet, "is_wall_sliding", "Is Wall Sliding", "Traversal 3D",
		"True on the frames a Slide Down Wall actually slowed a fall.",
		[], "return _recent(_wall_slide_frame)")
	Lib.condition(sheet, "is_wall_running", "Is Wall Running", "Traversal 3D",
		"True on the frames a Wall Run is carrying the host along a wall (it stops on its own after Wall Run Max Time).",
		[], "return _recent(_wall_run_frame)")
	Lib.append_function(sheet, "slide_down_wall", "Slide Down Wall", "Traversal 3D",
		"Caps the fall while the host is pressed against a wall, so it slides instead of dropping. Does nothing when it is not on a wall or is still moving upward.",
		[["speed", "float"]], "\n".join(PackedStringArray([
			"if host == null or not host.is_on_wall() or host.velocity.y >= 0.0:",
			"\treturn",
			"host.velocity.y = maxf(host.velocity.y, -absf(speed))",
			"_wall_slide_frame = Engine.get_physics_frames()"
		])))
	_default(sheet, "speed", "1.5")
	Lib.append_function(sheet, "wall_jump", "Wall Jump", "Traversal 3D",
		"Jumps AWAY from the wall: the push goes along the wall's own normal, flattened to the floor plane, so the host always leaves the wall it was on, whichever side that was.",
		[["push", "float"], ["rise", "float"]], "\n".join(PackedStringArray([
			"if host == null or not host.is_on_wall():",
			"\treturn",
			"var away: Vector3 = host.get_wall_normal()",
			"away.y = 0.0",
			"if away.length_squared() < 0.001:",
			"\taway = -_forward()",
			"away = away.normalized()",
			"host.velocity = away * push + Vector3(0.0, absf(rise), 0.0)",
			"_facing_dir = away",
			"_wall_slide_frame = -10"
		])))
	_default(sheet, "push", "6.0")
	_default(sheet, "rise", "4.5")
	Lib.append_function(sheet, "wall_run", "Wall Run", "Traversal 3D",
		"Runs along the wall: gravity is replaced by the percentage you give, so the host barely sinks while it keeps up speed. It needs to be on a wall, off the floor, and moving at least Min Speed - and it gives out after Wall Run Max Time.",
		[["gravity_percent", "float"], ["min_speed", "float"]], "\n".join(PackedStringArray([
			"if host == null or host.is_on_floor() or not host.is_on_wall():",
			"\treturn",
			"if Vector3(host.velocity.x, 0.0, host.velocity.z).length() < min_speed or _wall_run_timer >= wall_run_max_time:",
			"\treturn",
			"var step: float = host.get_physics_process_delta_time()",
			"_wall_run_timer += step",
			"_wall_run_fall += gravity * (clampf(gravity_percent, 0.0, 100.0) / 100.0) * step",
			"host.velocity.y = -_wall_run_fall",
			"_wall_run_frame = Engine.get_physics_frames()"
		])))
	_default(sheet, "gravity_percent", "20.0")
	_default(sheet, "min_speed", "3.0")


## Y10 - the small verbs: ladders, vaults, crouching.
static func _append_ladders_and_vaults(sheet: EventSheetResource) -> void:
	Lib.condition(sheet, "is_on_ladder", "Is On Ladder", "Traversal 3D",
		"True while the host is standing inside an Area3D marked with the ladder group.",
		[], "return _overlapping(ladder_group) != null")
	Lib.append_function(sheet, "climb_ladder", "Climb Ladder", "Traversal 3D",
		"Drives the host up or down the ladder at this speed, from the up/down controls (or the AI axis). It writes the vertical speed outright, so gravity is off for as long as you keep calling it.",
		[["speed", "float"]], "\n".join(PackedStringArray([
			"if host == null or _overlapping(ladder_group) == null:",
			"\treturn",
			"var axis: float = ai_climb_axis if ai_controlled else Input.get_axis(&\"ui_down\", &\"ui_up\")",
			"host.velocity = Vector3(host.velocity.x, axis * speed, host.velocity.z)"
		])))
	_default(sheet, "speed", "2.5")
	Lib.condition(sheet, "is_at_vaultable", "Is At A Vaultable Obstacle", "Traversal 3D",
		"True when the forward probe finds something at knee height and nothing at chest height - a low obstacle you could throw yourself over.",
		[], "return _probe(vault_probe_height, probe_distance) and not _probe(vault_clear_height, probe_distance)")
	Lib.append_function(sheet, "vault_over", "Vault Over", "Traversal 3D",
		"Carries the host forward over the obstacle in this many seconds. Nothing else moves it while the vault runs, and On Vaulted fires on the far side.",
		[["duration", "float"]], "\n".join(PackedStringArray([
			"if host == null or _move_left > 0.0:",
			"\treturn",
			"_move_from = host.global_position",
			"_move_to = host.global_position + _forward() * vault_distance",
			"_move_time = maxf(duration, 0.0001)",
			"_move_left = _move_time",
			"_move_kind = \"vault\"",
			"host.velocity = Vector3.ZERO"
		])))
	_default(sheet, "duration", "0.4")
	Lib.condition(sheet, "is_crouching", "Is Crouching", "Traversal 3D",
		"True while the host is crouched (its collider is the short one).",
		[], "return _crouching")
	Lib.append_function(sheet, "crouch", "Crouch", "Traversal 3D",
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
			"var shrunk: Shape3D = _crouch_shape.shape.duplicate()",
			"if shrunk is BoxShape3D:",
			"\tvar box: BoxShape3D = shrunk as BoxShape3D",
			"\tvar lost: float = box.size.y * (1.0 - kept)",
			"\tbox.size = Vector3(box.size.x, box.size.y * kept, box.size.z)",
			"\t_crouch_shape.position = _crouch_original_position - Vector3(0.0, lost * 0.5, 0.0)",
			"elif shrunk is CapsuleShape3D:",
			"\tvar capsule: CapsuleShape3D = shrunk as CapsuleShape3D",
			"\tvar shed: float = capsule.height * (1.0 - kept)",
			"\tcapsule.height = maxf(capsule.height * kept, capsule.radius * 2.0)",
			"\t_crouch_shape.position = _crouch_original_position - Vector3(0.0, shed * 0.5, 0.0)",
			"_crouch_shape.shape = shrunk"
		])))
	Lib.append_function(sheet, "stand", "Stand", "Traversal 3D",
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


## Y11 - water: the marked area, the two triggers, swimming, and the buoyancy push.
static func _append_water(sheet: EventSheetResource) -> void:
	Lib.condition(sheet, "is_in_water", "Is In Water", "Traversal 3D",
		"True while the host is inside an Area3D marked with the water group.",
		[], "return _in_water")
	Lib.condition(sheet, "is_above_the_surface", "Is Above The Surface", "Traversal 3D",
		"True when the host's own point is above the water line of the area it is in - the test that lets a swimmer breathe, climb out, or hold at the top. Always true out of water.",
		[], "\n".join(PackedStringArray([
			"if host == null:",
			"\treturn false",
			"if not _in_water:",
			"\treturn true",
			"return host.global_position.y >= _surface_y"
		])))
	Lib.append_function(sheet, "swim", "Swim", "Traversal 3D",
		"Swimming instead of falling: only this percentage of the kit's gravity still pulls, and the host sheds this percentage of its speed every physics frame (10 is the classic 0.9 damping). Call it every tick while in water.",
		[["gravity_percent", "float"], ["drag", "float"]], "\n".join(PackedStringArray([
			"if host == null:",
			"\treturn",
			"var step: float = host.get_physics_process_delta_time()",
			"host.velocity.y -= gravity * (clampf(gravity_percent, 0.0, 100.0) / 100.0) * step",
			"host.velocity *= maxf(0.0, 1.0 - clampf(drag, 0.0, 100.0) / 100.0)"
		])))
	_default(sheet, "gravity_percent", "20.0")
	_default(sheet, "drag", "10.0")
	Lib.append_function(sheet, "float_in_water", "Float", "Traversal 3D",
		"Buoyancy: pushes the host upward in proportion to how deep under the surface it is, so it bobs up and settles at the water line instead of sinking. Call it every tick together with Swim.",
		[["buoyancy", "float"]], "\n".join(PackedStringArray([
			"if host == null or not _in_water:",
			"\treturn",
			"var step: float = host.get_physics_process_delta_time()",
			"host.velocity.y += buoyancy * maxf(_surface_y - host.global_position.y, 0.0) * step"
		])))
	_default(sheet, "buoyancy", "12.0")
	Lib.number(sheet, "water_depth", "Water Depth", "Traversal 3D",
		"How far below the water line the host is, in metres (0 out of water or at the surface).",
		[], "\n".join(PackedStringArray([
			"if host == null or not _in_water:",
			"\treturn 0.0",
			"return maxf(_surface_y - host.global_position.y, 0.0)"
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
		"swim": "[b]Swim[/b] (gravity [b]{gravity_percent}[/b]%, drag [b]{drag}[/b]%)",
		"float_in_water": "[b]Float[/b] with buoyancy [b]{buoyancy}[/b]"
	}


## Pre-fills the last-appended ACE's parameter default (authoring-time metadata only).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value
