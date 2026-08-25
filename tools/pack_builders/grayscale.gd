# Pack builder - grayscale (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Grayscale: draining the colour out of one node, part of the way or all of it.
##
## The state that has no other spelling in Godot: a disabled button, a dead unit still on the board,
## a memory, a paused world behind a menu. Modulating towards grey darkens instead of draining, and
## darkening reads as "in shadow" rather than as "not part of this any more".
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CanvasItem"
	sheet.custom_class_name = "GrayscaleBehavior"
	sheet.class_description = "Drains the colour out of the host, all the way or part of the way, over a time you give. The state a disabled button, a dead unit or a remembered scene is in. The grey can be tinted - a cold blue reads as frozen, a brown as an old photograph - through the gray_tint dial in the shader file copied into your project."
	sheet.addon_category = "Grayscale"
	sheet.addon_tags = PackedStringArray(["effects", "shader", "ui", "visual"])
	sheet.ace_expose_all_mode = "node"

	var about: CommentRow = CommentRow.new()
	about.text = "Grayscale: put this under any 2D node or Control that wears the grayscale material. Grayscale drains its colour over a time, Recolour brings it back, and Grayness reads how far it has gone. The tint the grey takes lives in grayscale.gdshader, copied into your project when the pack is added. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var block: RawCodeRow = RawCodeRow.new()
	var lines: PackedStringArray = PackedStringArray([
		"## The dial grayscale.gdshader drains along, named once so a rename there is a one-line change",
		"## here. 0 is full colour, 1 is fully grey.",
		"const GREY_DIAL: String = \"grayscale\"",
		""
	])
	lines.append_array(Lib.effect_material_lines("Grayscale", "grayscale.gdshader"))
	lines.append_array(PackedStringArray([
		"",
		"## Drains the host's colour to the given amount over the given time. 1 is fully grey; a half",
		"## reads as faded rather than as dead, which is what a disabled-but-still-there control wants.",
		"## @ace_action",
		"## @ace_featured",
		"## @ace_name(\"Grayscale\")",
		"## @ace_display_template(\"Grayscale to [b]{amount}[/b] over [b]{seconds}[/b] s\")",
		"func grayscale(amount: float = 1.0, seconds: float = 0.25) -> void:",
		"\t_walk_dial(GREY_DIAL, clampf(amount, 0.0, 1.0), maxf(seconds, 0.0))",
		"",
		"## Brings the colour back over the given time.",
		"## @ace_action",
		"## @ace_name(\"Recolour\")",
		"## @ace_display_template(\"Recolour over [b]{seconds}[/b] s\")",
		"func recolour(seconds: float = 0.25) -> void:",
		"\t_walk_dial(GREY_DIAL, 0.0, maxf(seconds, 0.0))",
		"",
		"## True once more than half the colour has gone - the question a sheet asks about a unit that",
		"## has been taken out of play.",
		"## @ace_condition",
		"## @ace_name(\"Is Gray\")",
		"func is_gray() -> bool:",
		"\treturn _dial(GREY_DIAL, 0.0) > 0.5",
		"",
		"## How much colour has been drained, 0 to 1.",
		"## @ace_expression",
		"## @ace_name(\"Grayness\")",
		"func grayness() -> float:",
		"\treturn _dial(GREY_DIAL, 0.0)"
	]))
	block.code = "\n".join(lines)
	sheet.events.append(block)

	return Lib.save_pack(sheet, "res://eventsheet_addons/grayscale/grayscale_behavior")
