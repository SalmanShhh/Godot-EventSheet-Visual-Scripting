# Pack builder - wrap (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Wrap: Asteroids-style screen wrapping - once the host is FULLY outside one edge of the
## screen (or a custom rectangle) it teleports to the opposite edge, per axis. The
## event-sheet-parity Wrap behavior: attach and ships fly off the right and return on the left.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "WrapBehavior"
	sheet.addon_category = "Wrap"
	sheet.addon_tags = PackedStringArray(["movement", "screen"])
	var about: CommentRow = CommentRow.new()
	about.text = "Wrap behavior (event-sheet parity): once the host is FULLY outside an edge of the SCREEN (the camera's view) or a CUSTOM rectangle, it teleports to the opposite edge - Asteroids in one attach. Per-axis toggles; On Wrapped tells you which side it left. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# --- Designer knobs (tune in the Inspector) ---",
		"## What to wrap around: the camera's on-screen view, or the custom bounds rectangle.",
		"@export_enum(\"screen\", \"custom\") var wrap_space: String = \"screen\"",
		"## Wrap across the left/right edges.",
		"@export var wrap_horizontal: bool = true",
		"## Wrap across the top/bottom edges.",
		"@export var wrap_vertical: bool = true",
		"## Half the host's width in pixels - it must be FULLY off screen before wrapping.",
		"@export var half_width: float = 16.0",
		"## Half the host's height in pixels - it must be FULLY off screen before wrapping.",
		"@export var half_height: float = 16.0",
		"## Master on/off - Set Wrap Enabled flips it at runtime.",
		"@export var wrap_enabled: bool = true",
		"",
		"# --- Internal state ---",
		"# The custom rectangle (world space) used when wrap_space is \"custom\" - Rect2 cannot",
		"# emit from the variables dict, so it lives here; Set Custom Wrap Bounds writes it.",
		"var custom_bounds: Rect2 = Rect2(0.0, 0.0, 1152.0, 648.0)",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Wrapped\")",
		"signal wrapped(side: String)",
		"",
		"## The world-space rectangle being wrapped around: the camera's visible rect (the canvas",
		"## transform inverted maps screen space to world space) or the custom rectangle.",
		"## @ace_hidden",
		"func _wrap_rect() -> Rect2:",
		"\tif wrap_space == \"custom\":",
		"\t\treturn custom_bounds",
		"\tvar viewport: Viewport = host.get_viewport() if host != null else null",
		"\tif viewport == null:",
		"\t\treturn custom_bounds",
		"\treturn viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()",
		"",
		"## Switches what the host wraps around: the on-screen camera view, or the custom rectangle.",
		"## @ace_action",
		"## @ace_name(\"Set Wrap Space\")",
		"## @ace_param_options(space screen, custom)",
		"func set_wrap_space(space: String) -> void:",
		"\tif space in [\"screen\", \"custom\"]:",
		"\t\twrap_space = space"
	]))
	sheet.events.append(block)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if not wrap_enabled or host == null:",
		"\treturn",
		"var rect: Rect2 = _wrap_rect()",
		"var pos: Vector2 = host.global_position",
		"# Fully-outside test per side; re-enter at the opposite edge, still fully outside,",
		"# so a fast mover glides on instead of popping mid-screen.",
		"if wrap_horizontal:",
		"\tif pos.x - half_width > rect.end.x:",
		"\t\tpos.x = rect.position.x - half_width",
		"\t\thost.global_position = pos",
		"\t\twrapped.emit(\"right\")",
		"\telif pos.x + half_width < rect.position.x:",
		"\t\tpos.x = rect.end.x + half_width",
		"\t\thost.global_position = pos",
		"\t\twrapped.emit(\"left\")",
		"if wrap_vertical:",
		"\tif pos.y - half_height > rect.end.y:",
		"\t\tpos.y = rect.position.y - half_height",
		"\t\thost.global_position = pos",
		"\t\twrapped.emit(\"bottom\")",
		"\telif pos.y + half_height < rect.position.y:",
		"\t\tpos.y = rect.end.y + half_height",
		"\t\thost.global_position = pos",
		"\t\twrapped.emit(\"top\")"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	Lib.append_function(sheet, "set_wrap_enabled", "Set Wrap Enabled", "Wrap",
		"Turns wrapping on or off at runtime.",
		[["enabled", "bool"]],
		"wrap_enabled = enabled")
	Lib.append_function(sheet, "set_custom_wrap_bounds", "Set Custom Wrap Bounds", "Wrap",
		"Sets the custom rectangle (world-space pixels) and switches wrapping to it - your arena's edges.",
		[["x", "float"], ["y", "float"], ["width", "float"], ["height", "float"]],
		"custom_bounds = Rect2(x, y, width, height)\nwrap_space = \"custom\"")
	Lib.append_function(sheet, "set_wrap_axes", "Set Wrap Axes", "Wrap",
		"Chooses which axes wrap (horizontal: left/right edges, vertical: top/bottom).",
		[["horizontal", "bool"], ["vertical", "bool"]],
		"wrap_horizontal = horizontal\nwrap_vertical = vertical")
	Lib.append_function(sheet, "set_wrap_extents", "Set Wrap Extents", "Wrap",
		"Sets the host's half-size (half the sprite's width and height) used by the fully-outside test.",
		[["new_half_width", "float"], ["new_half_height", "float"]],
		"half_width = new_half_width\nhalf_height = new_half_height")

	return Lib.save_pack(sheet, "res://eventsheet_addons/wrap/wrap_behavior")
