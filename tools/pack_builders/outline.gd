# Pack builder - outline (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Outline: the selection ring, the highlight, the "you can interact with this" border.
##
## Two dials, and the pack exists to make them one row apiece rather than two typed strings. The
## border is drawn INSIDE the node's own rectangle, because a canvas_item shader may only colour
## pixels the node already covers - so a sprite whose art runs to the edge of its image has no room
## for one. That is a property of the picture rather than of this pack, and the guide says so.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CanvasItem"
	sheet.custom_class_name = "OutlineBehavior"
	sheet.class_description = "Draws a coloured border around whatever the host's own alpha says its shape is - the selection ring, the highlight, the interactable marker. Outline turns it on with a colour and a thickness, No Outline turns it off, and the border follows the art rather than a rectangle. The shader is copied into your project when the pack is added."
	sheet.addon_category = "Outline"
	sheet.addon_tags = PackedStringArray(["effects", "shader", "ui", "visual"])
	sheet.ace_expose_all_mode = "node"

	var about: CommentRow = CommentRow.new()
	about.text = "Outline: put this under any 2D node or Control that wears the outline material, then Outline it in a colour and a thickness and No Outline to clear it. The border is drawn inside the node's own image, so give sprites a few transparent pixels of margin or the outline has nowhere to go. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var block: RawCodeRow = RawCodeRow.new()
	var lines: PackedStringArray = PackedStringArray([
		"## The two dials outline.gdshader declares, named once so a rename there is a one-line change",
		"## here.",
		"const COLOUR_DIAL: String = \"outline_color\"",
		"const WIDTH_DIAL: String = \"outline_width\"",
		""
	])
	lines.append_array(Lib.effect_material_lines("Outline", "outline.gdshader"))
	lines.append_array(PackedStringArray([
		"",
		"## Draws a border of the given colour and thickness. Thickness is in pixels of the host's own",
		"## image, so a sprite scaled up in the scene gets a border scaled up with it.",
		"## @ace_action",
		"## @ace_featured",
		"## @ace_name(\"Outline\")",
		"## @ace_display_template(\"Outline [b]{colour}[/b] at [b]{pixels}[/b] px\")",
		"func outline(colour: Color = Color.WHITE, pixels: float = 2.0) -> void:",
		"\t_set_dial(COLOUR_DIAL, colour)",
		"\t_set_dial(WIDTH_DIAL, maxf(pixels, 0.0))",
		"",
		"## Clears the border. The colour is left where it was, so the next Outline with no colour",
		"## given comes back the same as the last one.",
		"## @ace_action",
		"## @ace_name(\"No Outline\")",
		"func no_outline() -> void:",
		"\t_set_dial(WIDTH_DIAL, 0.0)",
		"",
		"## Fades the border in or out over a time rather than switching it, for a highlight that",
		"## breathes instead of blinking.",
		"## @ace_action",
		"## @ace_name(\"Fade Outline\")",
		"## @ace_display_template(\"Fade outline to [b]{pixels}[/b] px over [b]{seconds}[/b] s\")",
		"func fade_outline(pixels: float = 0.0, seconds: float = 0.25) -> void:",
		"\t_walk_dial(WIDTH_DIAL, maxf(pixels, 0.0), maxf(seconds, 0.0))",
		"",
		"## True while a border is being drawn.",
		"## @ace_condition",
		"## @ace_name(\"Is Outlined\")",
		"func is_outlined() -> bool:",
		"\treturn _dial(WIDTH_DIAL, 0.0) > 0.001"
	]))
	block.code = "\n".join(lines)
	sheet.events.append(block)

	return Lib.save_pack(sheet, "res://eventsheet_addons/outline/outline_behavior")
