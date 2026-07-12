# Pack builder - bound_to (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## BoundTo: keeps the host inside the screen or a custom rectangle - the event-sheet-parity
## "Bound to layout" behavior. Attach to any Node2D and it clamps every physics frame; choose
## whether the ORIGIN or the EDGES (origin + half-size) must stay inside. On Hit Bound fires
## once per press against each side, so bump sounds and screen flashes are one row.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "BoundToBehavior"
	sheet.addon_category = "Bound To"
	sheet.addon_tags = PackedStringArray(["movement", "screen"])
	var about: CommentRow = CommentRow.new()
	about.text = "Bound To behavior (event-sheet parity): keeps the host inside the SCREEN (the camera's view) or a CUSTOM rectangle, clamped every physics frame. Bound by edge (origin + half-size stays inside) or by origin alone. On Hit Bound fires once per press against each side. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# --- Designer knobs (tune in the Inspector) ---",
		"## What to stay inside: the camera's on-screen view, or the custom bounds rectangle.",
		"@export_enum(\"screen\", \"custom\") var bound_space: String = \"screen\"",
		"## On: the host's EDGES stay inside (origin + half-size). Off: only the origin is bound.",
		"@export var bound_by_edge: bool = true",
		"## Half the host's width in pixels (edge binding uses it; match your sprite).",
		"@export var half_width: float = 16.0",
		"## Half the host's height in pixels (edge binding uses it; match your sprite).",
		"@export var half_height: float = 16.0",
		"## Master on/off - Set Bound Enabled flips it at runtime.",
		"@export var bound_enabled: bool = true",
		"",
		"# --- Internal state ---",
		"# The custom rectangle (world space) used when bound_space is \"custom\" - Rect2 cannot",
		"# emit from the variables dict, so it lives here; Set Custom Bounds writes it.",
		"var custom_bounds: Rect2 = Rect2(0.0, 0.0, 1152.0, 648.0)",
		"var _pressed_sides: Dictionary = {}",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Hit Bound\")",
		"signal bound_hit(side: String)",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is At Bound\")",
		"## @ace_description(\"True while the host is pressed against a bound. side: left / right / top / bottom / any.\")",
		"## @ace_param_options(side left, right, top, bottom, any)",
		"func is_at_bound(side: String = \"any\") -> bool:",
		"\tif side == \"any\":",
		"\t\treturn not _pressed_sides.is_empty()",
		"\treturn _pressed_sides.has(side)",
		"",
		"## Switches what the host is kept inside: the on-screen camera view, or the custom rectangle.",
		"## @ace_action",
		"## @ace_name(\"Set Bound Space\")",
		"## @ace_param_options(space screen, custom)",
		"func set_bound_space(space: String) -> void:",
		"\tif space in [\"screen\", \"custom\"]:",
		"\t\tbound_space = space",
		"",
		"## The world-space rectangle being bound to: the camera's visible rect (the canvas",
		"## transform inverted maps screen space to world space) or the custom rectangle.",
		"## @ace_hidden",
		"func _bound_rect() -> Rect2:",
		"\tif bound_space == \"custom\":",
		"\t\treturn custom_bounds",
		"\tvar viewport: Viewport = host.get_viewport() if host != null else null",
		"\tif viewport == null:",
		"\t\treturn custom_bounds",
		"\treturn viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()"
	]))
	sheet.events.append(block)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if not bound_enabled or host == null:",
		"\treturn",
		"var rect: Rect2 = _bound_rect()",
		"var extent: Vector2 = Vector2(half_width, half_height) if bound_by_edge else Vector2.ZERO",
		"var low: Vector2 = rect.position + extent",
		"var high: Vector2 = rect.end - extent",
		"# A rect smaller than the host still clamps sanely (low may exceed high - order them).",
		"var pos: Vector2 = host.global_position",
		"var clamped: Vector2 = Vector2(clampf(pos.x, minf(low.x, high.x), maxf(low.x, high.x)), clampf(pos.y, minf(low.y, high.y), maxf(low.y, high.y)))",
		"# Edge-triggered per side: On Hit Bound fires once per press, re-arming on release.",
		"var now_pressed: Dictionary = {}",
		"if clamped.x > pos.x:",
		"\tnow_pressed[\"left\"] = true",
		"elif clamped.x < pos.x:",
		"\tnow_pressed[\"right\"] = true",
		"if clamped.y > pos.y:",
		"\tnow_pressed[\"top\"] = true",
		"elif clamped.y < pos.y:",
		"\tnow_pressed[\"bottom\"] = true",
		"for side in now_pressed:",
		"\tif not _pressed_sides.has(side):",
		"\t\tbound_hit.emit(str(side))",
		"_pressed_sides = now_pressed",
		"if clamped != pos:",
		"\thost.global_position = clamped"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	Lib.append_function(sheet, "set_bound_enabled", "Set Bound Enabled", "Bound To",
		"Turns the binding on or off at runtime (off = the host moves freely).",
		[["enabled", "bool"]],
		"bound_enabled = enabled\nif not enabled:\n\t_pressed_sides = {}")
	Lib.append_function(sheet, "set_custom_bounds", "Set Custom Bounds", "Bound To",
		"Sets the custom rectangle (world-space pixels) and switches the binding to it - your level's playable area.",
		[["x", "float"], ["y", "float"], ["width", "float"], ["height", "float"]],
		"custom_bounds = Rect2(x, y, width, height)\nbound_space = \"custom\"")
	Lib.append_function(sheet, "set_bound_extents", "Set Bound Extents", "Bound To",
		"Sets the host's half-size used by edge binding (half the sprite's width and height).",
		[["new_half_width", "float"], ["new_half_height", "float"]],
		"half_width = new_half_width\nhalf_height = new_half_height")

	return Lib.save_pack(sheet, "res://eventsheet_addons/bound_to/bound_to_behavior")
