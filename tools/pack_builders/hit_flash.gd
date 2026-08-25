# Pack builder - hit_flash (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Hit Flash: the white-out every action game uses for "that landed", as a shader rather than as a
## modulate blink.
##
## The difference matters and is the reason this pack exists beside the shipped Flash verb. Modulate
## MULTIPLIES, so a dark sprite flashed white stays dark and a black one does not move at all. This
## mixes the sprite's own pixels towards the colour instead, so every sprite whites out the same
## amount whatever it was painted. The shipped modulate Flash stays exactly where it was: it needs no
## material, which is what makes it the right answer for a node that has none.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CanvasItem"
	sheet.custom_class_name = "HitFlashBehavior"
	sheet.class_description = "Washes the host's own pixels towards a colour and back, which is the classic hit reaction. Unlike a modulate blink it works on dark sprites too, because it replaces colour rather than multiplying it. Flash takes the colour and how long the wash lasts; the shader file is copied into your project when the pack is added, so the edge cases are yours to tune."
	sheet.addon_category = "Hit Flash"
	sheet.addon_tags = PackedStringArray(["effects", "shader", "juice", "visual"])
	sheet.ace_expose_all_mode = "node"

	var about: CommentRow = CommentRow.new()
	about.text = "Hit Flash: put this under any 2D node or Control that wears the hit_flash material and Flash whites it out for a moment. The dials (flash_color, flash_amount) live in hit_flash.gdshader, which is copied into your project when the pack is added - open it and change what a hit looks like. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var block: RawCodeRow = RawCodeRow.new()
	var lines: PackedStringArray = PackedStringArray([
		"## The name the two dials go by in hit_flash.gdshader. Named once here so a rename in the",
		"## shader file is a one-line change in this one.",
		"const COLOUR_DIAL: String = \"flash_color\"",
		"const AMOUNT_DIAL: String = \"flash_amount\"",
		""
	])
	lines.append_array(Lib.effect_material_lines("Hit Flash", "hit_flash.gdshader"))
	lines.append_array(PackedStringArray([
		"",
		"## Washes the host towards a colour and lets it drain back over the given time. A second",
		"## flash while one is running restarts it rather than stacking, so a fast string of hits",
		"## reads as one bright thing rather than as a stuck white square.",
		"## @ace_action",
		"## @ace_featured",
		"## @ace_name(\"Flash\")",
		"## @ace_display_template(\"Flash [b]{colour}[/b] for [b]{seconds}[/b] s\")",
		"func flash(colour: Color = Color.WHITE, seconds: float = 0.15) -> void:",
		"\t_set_dial(COLOUR_DIAL, colour)",
		"\t_set_dial(AMOUNT_DIAL, 1.0)",
		"\t_walk_dial(AMOUNT_DIAL, 0.0, maxf(seconds, 0.0))",
		"",
		"## Ends the wash now, whatever was left of it. The row for an interruption: the hit was",
		"## cancelled, the enemy died mid-flash, the scene is moving on.",
		"## @ace_action",
		"## @ace_name(\"Stop Flashing\")",
		"func stop_flashing() -> void:",
		"\t_set_dial(AMOUNT_DIAL, 0.0)",
		"",
		"## True while any of the wash is still showing.",
		"## @ace_condition",
		"## @ace_name(\"Is Flashing\")",
		"func is_flashing() -> bool:",
		"\treturn _dial(AMOUNT_DIAL, 0.0) > 0.001"
	]))
	block.code = "\n".join(lines)
	sheet.events.append(block)

	return Lib.save_pack(sheet, "res://eventsheet_addons/hit_flash/hit_flash_behavior")
