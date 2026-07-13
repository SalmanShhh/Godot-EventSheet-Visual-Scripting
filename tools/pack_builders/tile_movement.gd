# Pack builder - tile_movement (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Tile Movement behavior (event-sheet parity)
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "TileMovementBehavior"
	sheet.addon_category = "Tile Movement"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"tile_size": {"type": "float", "default": 64.0, "exported": true, "description": "Pixel size of one grid tile - each step moves the host this many pixels."},
		"move_time": {"type": "float", "default": 0.15, "exported": true, "description": "Seconds to slide across one tile."},
		"default_controls": {"type": "bool", "default": true, "exported": true, "description": "When on, the arrow keys step the host one tile at a time."},
		"ai_controlled": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "AI drive: read ai_move_x/ai_move_y instead of the arrow keys (a sheet or AI driver flips this on to steer)."}},
		"ai_move_x": {"type": "float", "default": 0.0, "exported": false},
		"ai_move_y": {"type": "float", "default": 0.0, "exported": false},
		"moving": {"type": "bool", "default": false, "exported": false},
		"from_x": {"type": "float", "default": 0.0, "exported": false},
		"from_y": {"type": "float", "default": 0.0, "exported": false},
		"to_x": {"type": "float", "default": 0.0, "exported": false},
		"to_y": {"type": "float", "default": 0.0, "exported": false},
		"progress": {"type": "float", "default": 0.0, "exported": false},
		"pending_x": {"type": "float", "default": 0.0, "exported": false},
		"pending_y": {"type": "float", "default": 0.0, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Tile Movement behavior (event-sheet parity): grid-locked stepping (arrow keys or Simulate Step); grid-space helpers convert between tiles and pixels. Fires On Step Finished per tile."
	sheet.events.append(about)
	var signal_block: RawCodeRow = RawCodeRow.new()
	signal_block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Step Finished\")",
		"signal step_finished"
	]))
	sheet.events.append(signal_block)
	var extra_block_0: RawCodeRow = RawCodeRow.new()
	extra_block_0.code = "\n".join(PackedStringArray([
		"## @ace_hidden",
		"func to_grid(pixel: Vector2) -> Vector2i:",
		"\treturn Vector2i(roundi(pixel.x / tile_size), roundi(pixel.y / tile_size))",
		"",
		"## @ace_hidden",
		"func from_grid(tile: Vector2i) -> Vector2:",
		"\treturn Vector2(tile) * tile_size"
	]))
	sheet.events.append(extra_block_0)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"if moving:",
		"\tprogress += delta / move_time",
		"\tif progress >= 1.0:",
		"\t\thost.position = Vector2(to_x, to_y)",
		"\t\tmoving = false",
		"\t\tstep_finished.emit()",
		"\telse:",
		"\t\thost.position = Vector2(from_x, from_y).lerp(Vector2(to_x, to_y), progress)",
		"\treturn",
		"var step := Vector2(pending_x, pending_y)",
		"pending_x = 0.0",
		"pending_y = 0.0",
		"# The AI seam: a driver holds ai_move_x/ai_move_y like held keys - consumed one grid",
		"# step per completed step; off (the default) the keyboard read below is untouched.",
		"if step == Vector2.ZERO and ai_controlled:",
		"\tstep = Vector2(ai_move_x, ai_move_y)",
		"if step == Vector2.ZERO and default_controls and not ai_controlled:",
		"\tstep = Vector2(Input.get_axis(&\"ui_left\", &\"ui_right\"), Input.get_axis(&\"ui_up\", &\"ui_down\"))",
		"if step.x != 0.0:",
		"\tstep.y = 0.0",
		"if step != Vector2.ZERO:",
		"\tfrom_x = host.position.x",
		"\tfrom_y = host.position.y",
		"\tto_x = from_x + signf(step.x) * tile_size",
		"\tto_y = from_y + signf(step.y) * tile_size",
		"\tprogress = 0.0",
		"\tmoving = true"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var simulate_step_fn: EventFunction = EventFunction.new()
	simulate_step_fn.function_name = "simulate_step"
	simulate_step_fn.expose_as_ace = true
	simulate_step_fn.ace_display_name = "Simulate Step"
	simulate_step_fn.ace_category = "Tile Movement"
	simulate_step_fn.description = "Steps one tile in a direction: left, right, up or down (simulate control)."
	var simulate_step_fn_direction: ACEParam = ACEParam.new()
	simulate_step_fn_direction.id = "direction"
	simulate_step_fn_direction.type_name = "String"
	simulate_step_fn.params.append(simulate_step_fn_direction)
	var simulate_step_fn_body: RawCodeRow = RawCodeRow.new()
	simulate_step_fn_body.code = "\n".join(PackedStringArray([
		"if direction == \"left\":",
		"\tpending_x = -1.0",
		"elif direction == \"right\":",
		"\tpending_x = 1.0",
		"elif direction == \"up\":",
		"\tpending_y = -1.0",
		"elif direction == \"down\":",
		"\tpending_y = 1.0"
	]))
	simulate_step_fn.events.append(simulate_step_fn_body)
	sheet.functions.append(simulate_step_fn)
	_param_options(sheet, "direction", ["left", "right", "up", "down"])

	var teleport_to_tile_fn: EventFunction = EventFunction.new()
	teleport_to_tile_fn.function_name = "teleport_to_tile"
	teleport_to_tile_fn.expose_as_ace = true
	teleport_to_tile_fn.ace_display_name = "Teleport To Tile"
	teleport_to_tile_fn.ace_category = "Tile Movement"
	teleport_to_tile_fn.description = "Snaps to a tile coordinate instantly."
	var teleport_to_tile_fn_tile_x: ACEParam = ACEParam.new()
	teleport_to_tile_fn_tile_x.id = "tile_x"
	teleport_to_tile_fn_tile_x.type_name = "float"
	teleport_to_tile_fn.params.append(teleport_to_tile_fn_tile_x)
	var teleport_to_tile_fn_tile_y: ACEParam = ACEParam.new()
	teleport_to_tile_fn_tile_y.id = "tile_y"
	teleport_to_tile_fn_tile_y.type_name = "float"
	teleport_to_tile_fn.params.append(teleport_to_tile_fn_tile_y)
	var teleport_to_tile_fn_body: RawCodeRow = RawCodeRow.new()
	teleport_to_tile_fn_body.code = "\n".join(PackedStringArray([
		"if host != null:",
		"\thost.position = Vector2(tile_x, tile_y) * tile_size",
		"moving = false"
	]))
	teleport_to_tile_fn.events.append(teleport_to_tile_fn_body)
	sheet.functions.append(teleport_to_tile_fn)

	return Lib.save_pack(sheet, "res://eventsheet_addons/tile_movement/tile_movement_behavior")


## Sets the dropdown options[] on the last-appended ACE's parameter (append_function only sets id+type),
## so e.g. direction becomes a left/right/up/down picker instead of a free-text field.
static func _param_options(sheet: EventSheetResource, param_id: String, choices: Array) -> void:
	var typed: Array[String] = []
	for choice: Variant in choices:
		typed.append(str(choice))
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = typed
