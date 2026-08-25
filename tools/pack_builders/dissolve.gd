# Pack builder - dissolve (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Dissolve: burning a sprite away along a noise field, and burning it back.
##
## The reason it is a pack rather than a row: a dissolve is a dial walked from 0 to 1 over a time,
## with something waiting at the end of it. The walk is one tween, the end is one signal, and the
## thing every project then hand-writes is the bookkeeping between them - which is what this is.
## Whether the node is FREED at the end is the game's decision and stays on the sheet, because a
## behaviour that deletes its own parent is a behaviour nobody can debug.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CanvasItem"
	sheet.custom_class_name = "DissolveBehavior"
	sheet.class_description = "Burns the host away along a noise field with a glowing edge, and burns it back. Dissolve walks the burn to gone over a number of seconds and fires On Dissolved when it arrives; Appear walks it back. The burn's blotch size, edge width and edge colour live in dissolve.gdshader, which is copied into your project when the pack is added."
	sheet.addon_category = "Dissolve"
	sheet.addon_tags = PackedStringArray(["effects", "shader", "juice", "visual"])
	sheet.ace_expose_all_mode = "node"

	var about: CommentRow = CommentRow.new()
	about.text = "Dissolve: put this under any 2D node or Control that wears the dissolve material. Dissolve burns it away over the seconds you give and fires On Dissolved at the end - the row that frees the boss, drops the loot or moves the scene on. Appear burns it back. The look (edge_color, edge_width, noise_scale) lives in dissolve.gdshader, copied into your project when the pack is added. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var finished: SignalRow = SignalRow.new()
	finished.signal_name = "dissolved"
	finished.trigger = true
	finished.ace_name = "On Dissolved"
	finished.ace_category = "Dissolve"
	sheet.events.append(finished)

	var block: RawCodeRow = RawCodeRow.new()
	var lines: PackedStringArray = PackedStringArray([
		"## The dial dissolve.gdshader burns along, named once so a rename there is a one-line change",
		"## here. 0 is whole, 1 is gone.",
		"const BURN_DIAL: String = \"dissolve\"",
		"",
		"## Hide the host once it has finished burning. A fully dissolved sprite draws nothing anyway,",
		"## so this saves the draw; turn it off when something else is going to fade it back in.",
		"@export var hide_when_gone: bool = true",
		""
	])
	lines.append_array(Lib.effect_material_lines("Dissolve", "dissolve.gdshader"))
	lines.append_array(PackedStringArray([
		"",
		"## Burns the host away over the given time and fires On Dissolved when there is nothing left.",
		"## No time at all burns it away on the spot, which is the row for a thing that pops out of",
		"## existence rather than fading.",
		"## @ace_action",
		"## @ace_featured",
		"## @ace_name(\"Dissolve\")",
		"## @ace_display_template(\"Dissolve over [b]{seconds}[/b] s\")",
		"func dissolve(seconds: float = 0.8) -> void:",
		"\tvar burn: Tween = _walk_dial(BURN_DIAL, 1.0, maxf(seconds, 0.0))",
		"\tif burn == null:",
		"\t\t_burnt_away()",
		"\t\treturn",
		"\tburn.finished.connect(_burnt_away)",
		"",
		"## Burns the host back in from nothing over the given time. The host is shown again first, so",
		"## the row works whether or not the last dissolve hid it.",
		"## @ace_action",
		"## @ace_name(\"Appear\")",
		"## @ace_display_template(\"Appear over [b]{seconds}[/b] s\")",
		"func appear(seconds: float = 0.8) -> void:",
		"\tif host != null:",
		"\t\thost.visible = true",
		"\t_walk_dial(BURN_DIAL, 0.0, maxf(seconds, 0.0))",
		"",
		"## True once the host has burned all the way away.",
		"## @ace_condition",
		"## @ace_name(\"Is Gone\")",
		"func is_gone() -> bool:",
		"\treturn _dial(BURN_DIAL, 0.0) >= 0.999",
		"",
		"## How much of the host has burned away, 0 to 1 - for a health bar that empties with the burn,",
		"## or a sound that follows it.",
		"## @ace_expression",
		"## @ace_name(\"Burnt Away\")",
		"func burnt_away() -> float:",
		"\treturn _dial(BURN_DIAL, 0.0)",
		"",
		"## The end of the burn: hide what is no longer drawing anything, then tell the sheet.",
		"func _burnt_away() -> void:",
		"\tif hide_when_gone and host != null:",
		"\t\thost.visible = false",
		"\tdissolved.emit()"
	]))
	block.code = "\n".join(lines)
	sheet.events.append(block)

	return Lib.save_pack(sheet, "res://eventsheet_addons/dissolve/dissolve_behavior")
