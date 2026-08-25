# Pack builder - wave (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Wave: rippling the DRAWING of a node without moving the node.
##
## That distinction is the whole point. Shaking a node's position moves its collision shape with it,
## so a rippling water tile becomes a rippling floor and a dizzy screen becomes a player who cannot
## be hit. This pushes the texture lookup instead: the picture ripples, the world does not move, and
## nothing in physics ever hears about it.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CanvasItem"
	sheet.custom_class_name = "WaveBehavior"
	sheet.class_description = "Ripples the host's picture from side to side in a travelling wave - water, heat haze, a flag, a dizzy spell. Only the drawing moves: positions, collisions and physics are untouched, so a rippling tile is still a flat floor. Wave eases the ripple in, Settle eases it out, and the crest count and speed are dials in the shader file copied into your project."
	sheet.addon_category = "Wave"
	sheet.addon_tags = PackedStringArray(["effects", "shader", "juice", "visual"])
	sheet.ace_expose_all_mode = "node"

	var about: CommentRow = CommentRow.new()
	about.text = "Wave: put this under any 2D node or Control that wears the wave material. Wave eases a ripple in to the strength you name, Settle eases it back out. Only the picture moves - collisions and positions are untouched. The crest count and travel speed (wave_length, wave_speed) live in wave.gdshader, copied into your project when the pack is added. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var block: RawCodeRow = RawCodeRow.new()
	var lines: PackedStringArray = PackedStringArray([
		"## The dial wave.gdshader pushes along, named once so a rename there is a one-line change",
		"## here. It is a share of the picture's width, so 0.03 is a three-percent sway.",
		"const PUSH_DIAL: String = \"wave_strength\"",
		""
	])
	lines.append_array(Lib.effect_material_lines("Wave", "wave.gdshader"))
	lines.append_array(PackedStringArray([
		"",
		"## Eases the ripple in to the given strength. Strength is a share of the picture's width:",
		"## 0.01 is a shimmer, 0.05 is water, 0.15 is a hallucination.",
		"## @ace_action",
		"## @ace_featured",
		"## @ace_name(\"Wave\")",
		"## @ace_display_template(\"Wave at [b]{strength}[/b] over [b]{seconds}[/b] s\")",
		"func wave(strength: float = 0.03, seconds: float = 0.4) -> void:",
		"\t_walk_dial(PUSH_DIAL, maxf(strength, 0.0), maxf(seconds, 0.0))",
		"",
		"## Eases the ripple back out to still. A ripple stopped instantly snaps the picture sideways,",
		"## which is why this takes a time rather than a switch.",
		"## @ace_action",
		"## @ace_name(\"Settle\")",
		"## @ace_display_template(\"Settle over [b]{seconds}[/b] s\")",
		"func settle(seconds: float = 0.4) -> void:",
		"\t_walk_dial(PUSH_DIAL, 0.0, maxf(seconds, 0.0))",
		"",
		"## True while the picture is still moving.",
		"## @ace_condition",
		"## @ace_name(\"Is Waving\")",
		"func is_waving() -> bool:",
		"\treturn _dial(PUSH_DIAL, 0.0) > 0.0005",
		"",
		"## How hard the ripple is pushing right now, as a share of the picture's width.",
		"## @ace_expression",
		"## @ace_name(\"Wave Strength\")",
		"func wave_strength() -> float:",
		"\treturn _dial(PUSH_DIAL, 0.0)"
	]))
	block.code = "\n".join(lines)
	sheet.events.append(block)

	return Lib.save_pack(sheet, "res://eventsheet_addons/wave/wave_behavior")
