# Pack builder - wrap (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Wrap: Asteroids-style screen wrapping - once the host is FULLY outside one edge of the
## screen (or a custom rectangle) it teleports to the opposite edge, per axis. The
## event-sheet-parity Wrap behavior: attach and ships fly off the right and return on the left.
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("wrap", "Node2D", "WrapBehavior",
		"Asteroids-style screen wrapping: once the host is fully outside one edge of the screen (or a custom rectangle) it teleports to the opposite edge - fly off the right, glide in from the left. Per-axis toggles, world- or camera-space, and On Wrapped tells you which side was crossed.",
		{"behavior": true, "category": "Wrap", "tags": PackedStringArray(["movement", "screen"])})
	src.note("Wrap behavior (event-sheet parity): once the host is FULLY outside an edge of the SCREEN (the camera's view) or a CUSTOM rectangle, it teleports to the opposite edge - Asteroids in one attach. Per-axis toggles; On Wrapped tells you which side it left. This pack is an event sheet - extend it by editing it.")
	src.block("block_1")
	src.on_ready()
	src.on_physics_process()
	src.verb("set_wrap_enabled", "Set Wrap Enabled",
		"Turns wrapping on or off at runtime.",
		[["enabled", "bool"]])
	src.verb("set_custom_wrap_bounds", "Set Custom Wrap Bounds",
		"Sets the custom rectangle (world-space pixels) and switches wrapping to it - your arena's edges.",
		[["x", "float"], ["y", "float"], ["width", "float"], ["height", "float"]])
	src.verb("set_wrap_axes", "Set Wrap Axes",
		"Chooses which axes wrap (horizontal: left/right edges, vertical: top/bottom).",
		[["horizontal", "bool"], ["vertical", "bool"]])
	src.verb("set_wrap_extents", "Set Wrap Extents",
		"Sets the host's half-size (half the sprite's width and height) used by the fully-outside test.",
		[["new_half_width", "float"], ["new_half_height", "float"]])
	Lib.verb_sentences(src.sheet, {
		"set_wrap_enabled": "Set wrap to [b]{enabled}[/b]",
	})
	Lib.feature_verbs(src.sheet, ["set_wrap_enabled"])
	return Lib.publish(src, "res://eventsheet_addons/wrap/wrap_behavior")
