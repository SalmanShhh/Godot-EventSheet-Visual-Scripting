# Pack builder - slide_move (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## SlideMove: grid movement where a tap sends the character sliding until it slams into a wall - the
## feel of Tomb of the Mask. Attach it to a Node2D, give it a grid size and which physics layer counts
## as a wall, and press a direction (or let the arrow keys drive it): it finds the farthest open tile in
## that direction and glides there at a constant speed, snapping to the grid when it stops. Walls are
## found with a physics ray on the wall layer, so it works with a TileMap collision layer or plain
## StaticBody2D tiles. Distinct from the step-per-press Tile Movement behavior.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "SlideMove"
	sheet.addon_category = "Slide Movement"
	sheet.addon_tags = PackedStringArray(["grid", "movement"])
	var about: CommentRow = CommentRow.new()
	about.text = "SlideMove: attach to a Node2D for Tomb-of-the-Mask sliding - a tap sends it gliding across the grid until it hits a wall, then snaps to the tile. Set the grid size and the wall physics layer; arrow keys drive it by default, or call Slide. React with On Hit Wall. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# --- Designer knobs (tune the FEEL in the Inspector) ---",
		"## Tile size in pixels - the character snaps to this grid.",
		"@export var grid_size: float = 64.0",
		"## Slide speed in pixels per second.",
		"@export var slide_speed: float = 400.0",
		"## Which physics collision layer counts as a wall (a layer-bit mask).",
		"@export_flags_2d_physics var wall_mask: int = 1",
		"## Let the arrow keys / ui_* actions start a slide automatically.",
		"@export var default_controls: bool = true",
		"## Safety cap: the most tiles a single slide may cross (stops a runaway slide on an open map).",
		"@export_range(1, 512, 1) var max_slide_tiles: int = 64",
		"## AI drive: read ai_move_x/ai_move_y instead of the arrow keys (a sheet or AI driver flips this on to steer).",
		"@export var ai_controlled: bool = false",
		"",
		"# --- Internal state ---",
		"# The AI seam's persistent intent axes - a driver holds them like held keys.",
		"var ai_move_x: float = 0.0",
		"var ai_move_y: float = 0.0",
		"var _sliding: bool = false",
		"var _dir: Vector2 = Vector2.ZERO",
		"var _target: Vector2 = Vector2.ZERO",
		"var _dir_name: String = \"\"",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Slide Started\")",
		"signal on_slide_started()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Slide Stopped\")",
		"signal on_slide_stopped()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Hit Wall\")",
		"signal on_hit_wall()",
		"",
		"# Maps a direction word to a unit step (screen axes: down is +Y).",
		"func _dir_from(direction: String) -> Vector2:",
		"\tmatch direction:",
		"\t\t\"left\": return Vector2.LEFT",
		"\t\t\"right\": return Vector2.RIGHT",
		"\t\t\"up\": return Vector2.UP",
		"\t\t\"down\": return Vector2.DOWN",
		"\t\t_: return Vector2.ZERO",
		"",
		"# Snaps a world position to the nearest grid intersection.",
		"func _snap(point: Vector2) -> Vector2:",
		"\treturn Vector2(roundi(point.x / grid_size), roundi(point.y / grid_size)) * grid_size",
		"",
		"# The farthest open tile centre in a direction: steps tile by tile, casting a ray on the wall",
		"# layer, and stops at the last tile before a wall.",
		"func _scan_target(dir: Vector2) -> Vector2:",
		"\tvar body: Node2D = host as Node2D",
		"\tif body == null or not is_inside_tree():",
		"\t\treturn body.global_position if body != null else Vector2.ZERO",
		"\tvar space: PhysicsDirectSpaceState2D = get_viewport().get_world_2d().direct_space_state",
		"\tvar pos: Vector2 = _snap(body.global_position)",
		"\tfor _i: int in max_slide_tiles:",
		"\t\tvar query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(pos, pos + dir * grid_size, wall_mask)",
		"\t\tif body is CollisionObject2D:",
		"\t\t\tquery.exclude = [(body as CollisionObject2D).get_rid()]",
		"\t\tif not space.intersect_ray(query).is_empty():",
		"\t\t\tbreak",
		"\t\tpos += dir * grid_size",
		"\treturn pos",
		"",
		"# Per physics frame: glide toward the target, or (idle + default controls) read the arrow keys.",
		"func _move(delta: float) -> void:",
		"\tvar body: Node2D = host as Node2D",
		"\tif body == null:",
		"\t\treturn",
		"\tif _sliding:",
		"\t\tvar step: float = slide_speed * delta",
		"\t\tif body.global_position.distance_to(_target) <= step:",
		"\t\t\tbody.global_position = _target",
		"\t\t\t_sliding = false",
		"\t\t\ton_slide_stopped.emit()",
		"\t\t\ton_hit_wall.emit()",
		"\t\telse:",
		"\t\t\tbody.global_position += _dir * step",
		"\t\treturn",
		"\t# The AI seam: a driver holds ai_move_x/ai_move_y like held keys - the dominant",
		"\t# axis starts the slide (same one-direction-at-a-time rule as the keyboard).",
		"\tif ai_controlled:",
		"\t\tif ai_move_x < -0.5:",
		"\t\t\tslide(\"left\")",
		"\t\telif ai_move_x > 0.5:",
		"\t\t\tslide(\"right\")",
		"\t\telif ai_move_y < -0.5:",
		"\t\t\tslide(\"up\")",
		"\t\telif ai_move_y > 0.5:",
		"\t\t\tslide(\"down\")",
		"\telif default_controls:",
		"\t\tif Input.is_action_pressed(&\"ui_left\"):",
		"\t\t\tslide(\"left\")",
		"\t\telif Input.is_action_pressed(&\"ui_right\"):",
		"\t\t\tslide(\"right\")",
		"\t\telif Input.is_action_pressed(&\"ui_up\"):",
		"\t\t\tslide(\"up\")",
		"\t\telif Input.is_action_pressed(&\"ui_down\"):",
		"\t\t\tslide(\"down\")"
	]))
	sheet.events.append(block)
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "if host is Node2D:\n\t(host as Node2D).global_position = _snap((host as Node2D).global_position)"
	on_ready.actions.append(ready_body)
	sheet.events.append(on_ready)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "_move(delta)"
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	Lib.append_function(sheet, "slide", "Slide", "Slide Movement", "Starts a slide in a direction (left / right / up / down): the character glides until the tile ahead is a wall, then stops snapped to the grid. Ignored while already sliding; fires On Hit Wall immediately if the very next tile is a wall.",
		[["direction", "String"]],
		"if _sliding:\n\treturn\nvar dir: Vector2 = _dir_from(direction)\nif dir == Vector2.ZERO or host == null:\n\treturn\n_dir_name = direction\nvar target: Vector2 = _scan_target(dir)\nif target.distance_to(_snap((host as Node2D).global_position)) < grid_size * 0.5:\n\ton_hit_wall.emit()\n\treturn\n_dir = dir\n_target = target\n_sliding = true\non_slide_started.emit()")
	_param_options(sheet, "direction", ["left", "right", "up", "down"])
	_default(sheet, "direction", "left")
	Lib.append_function(sheet, "stop_slide", "Stop Slide", "Slide Movement", "Stops a slide immediately and snaps the character to the nearest tile.",
		[],
		"_sliding = false\nif host is Node2D:\n\t(host as Node2D).global_position = _snap((host as Node2D).global_position)")
	Lib.append_function(sheet, "snap_to_grid", "Snap To Grid", "Slide Movement", "Snaps the character to the nearest grid intersection right now.",
		[],
		"if host is Node2D:\n\t(host as Node2D).global_position = _snap((host as Node2D).global_position)")
	Lib.append_function(sheet, "teleport_to_tile", "Teleport To Tile", "Slide Movement", "Jumps instantly to a tile coordinate (multiplied by the grid size), cancelling any slide.",
		[["tile_x", "int"], ["tile_y", "int"]],
		"_sliding = false\nif host is Node2D:\n\t(host as Node2D).global_position = Vector2(tile_x, tile_y) * grid_size")
	Lib.append_function(sheet, "set_grid_size", "Set Grid Size", "Slide Movement", "Changes the tile size in pixels at runtime.",
		[["pixels", "float"]],
		"grid_size = maxf(pixels, 1.0)")

	_condition(sheet, "is_sliding", "Is Sliding", "Slide Movement", "Whether the character is mid-slide.", [],
		"return _sliding")
	_condition(sheet, "can_slide", "Can Slide", "Slide Movement", "Whether the tile next to the character in a direction is open (not a wall).", [["direction", "String"]],
		"var dir: Vector2 = _dir_from(direction)\nif dir == Vector2.ZERO or host == null:\n\treturn false\nreturn _scan_target(dir).distance_to(_snap((host as Node2D).global_position)) >= grid_size * 0.5")
	_param_options_last_condition(sheet, "direction", ["left", "right", "up", "down"])

	_expr(sheet, "slide_direction", "Slide Direction", "Slide Movement", "The direction of the current or last slide (\"left\" / \"right\" / \"up\" / \"down\").", [],
		"return _dir_name", TYPE_STRING)
	_expr(sheet, "tile_x", "Tile X", "Slide Movement", "The character's current column on the grid.", [],
		"return roundi((host as Node2D).global_position.x / grid_size) if host is Node2D else 0", TYPE_INT)
	_expr(sheet, "tile_y", "Tile Y", "Slide Movement", "The character's current row on the grid.", [],
		"return roundi((host as Node2D).global_position.y / grid_size) if host is Node2D else 0", TYPE_INT)

	return Lib.save_pack(sheet, "res://eventsheet_addons/slide_move/slide_move_behavior")


## Pre-fills the last-appended ACE's parameter default (authoring-time metadata only).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value


## Sets the dropdown options[] on the last-appended ACE's parameter.
static func _param_options(sheet: EventSheetResource, param_id: String, choices: Array) -> void:
	_apply_options(sheet.functions[sheet.functions.size() - 1], param_id, choices)


## Same, for the most recently appended condition (conditions are appended by _condition below).
static func _param_options_last_condition(sheet: EventSheetResource, param_id: String, choices: Array) -> void:
	_apply_options(sheet.functions[sheet.functions.size() - 1], param_id, choices)


static func _apply_options(fn: EventFunction, param_id: String, choices: Array) -> void:
	var typed: Array[String] = []
	for choice: Variant in choices:
		typed.append(str(choice))
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = typed


static func _condition(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = TYPE_BOOL
	sheet.functions.append(fn)


static func _expr(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String, ret: int) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = ret
	sheet.functions.append(fn)
