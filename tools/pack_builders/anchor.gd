# Pack builder - anchor (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Anchor: where a Control sits when the window changes size. Godot spells it as four numbers
## between 0 and 1 plus four margins; an event sheet spells it as a corner - "anchor to top right",
## "anchor to full rect" - which is what an author actually means. The pack keeps the corner it was
## last anchored to, so a row can ask about it and a resize can re-apply it.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Control"
	sheet.custom_class_name = "AnchorBehavior"
	sheet.class_description = "Where a Control sits when the window changes size, said as a corner rather than as four numbers: anchor to top right, to the centre, to the full rect. Margins are set in pixels from the corner it is anchored to, the corner it is on can be asked about, and On Anchored fires whenever it moves."
	sheet.addon_category = "Anchor"
	sheet.addon_tags = PackedStringArray(["ui", "layout"])
	var about: CommentRow = CommentRow.new()
	about.text = "Anchor behavior: pin this Control to a corner, an edge or the whole rectangle of its parent, in one action. Anchor To Preset does the placing, Set Margins nudges it in pixels, Is Anchored To asks where it sits, and On Anchored fires when it moves. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# --- Designer knobs (tune in the Inspector) ---",
		"## The corner this Control is anchored to. Anchor To Preset writes it; the host is",
		"## placed there again whenever its parent resizes.",
		"@export_enum(\"top left\", \"top right\", \"bottom left\", \"bottom right\", \"centre\", \"full rect\", \"top edge\", \"bottom edge\", \"left edge\", \"right edge\") var anchored_to: String = \"top left\"",
		"## Keep the host's current size when it is anchored, instead of letting the preset",
		"## stretch it. Off is Godot's own behaviour for the wide presets.",
		"@export var keep_size: bool = true",
		"## Re-apply the anchor whenever the parent changes size. Off pins it once and leaves it.",
		"@export var follow_resizes: bool = true",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Anchored\")",
		"signal anchored(corner: String)",
		"",
		"## The Godot preset each corner word stands for. The words are the row's; the numbers are",
		"## the engine's, and this table is the one place the two meet.",
		"## @ace_hidden",
		"const CORNER_PRESETS: Dictionary = {",
		"\t\"top left\": Control.PRESET_TOP_LEFT,",
		"\t\"top right\": Control.PRESET_TOP_RIGHT,",
		"\t\"bottom left\": Control.PRESET_BOTTOM_LEFT,",
		"\t\"bottom right\": Control.PRESET_BOTTOM_RIGHT,",
		"\t\"centre\": Control.PRESET_CENTER,",
		"\t\"full rect\": Control.PRESET_FULL_RECT,",
		"\t\"top edge\": Control.PRESET_TOP_WIDE,",
		"\t\"bottom edge\": Control.PRESET_BOTTOM_WIDE,",
		"\t\"left edge\": Control.PRESET_LEFT_WIDE,",
		"\t\"right edge\": Control.PRESET_RIGHT_WIDE",
		"}",
		"",
		"## Puts the host on a corner, an edge or the whole rectangle of its parent - the one",
		"## action this behavior exists for.",
		"## @ace_action",
		"## @ace_name(\"Anchor To\")",
		"## @ace_param_options(corner top left=The top-left corner, top right=The top-right corner, bottom left=The bottom-left corner, bottom right=The bottom-right corner, centre=The middle, full rect=The whole parent, top edge=Across the top, bottom edge=Across the bottom, left edge=Down the left, right edge=Down the right)",
		"func anchor_to(corner: String) -> void:",
		"\tif host == null or not CORNER_PRESETS.has(corner):",
		"\t\treturn",
		"\tanchored_to = corner",
		"\tvar mode: int = Control.PRESET_MODE_KEEP_SIZE if keep_size else Control.PRESET_MODE_MINSIZE",
		"\thost.set_anchors_and_offsets_preset(CORNER_PRESETS[corner], mode)",
		"\tanchored.emit(corner)",
		"",
		"## True while the host is anchored to the given corner - what a row asks before moving it",
		"## somewhere else.",
		"## @ace_condition",
		"## @ace_name(\"Is Anchored To\")",
		"func is_anchored_to(corner: String) -> bool:",
		"\treturn anchored_to == corner",
		"",
		"## The corner the host is anchored to right now, as its word - what a row shows or compares.",
		"## @ace_expression",
		"## @ace_name(\"Anchored Corner\")",
		"func anchored_corner() -> String:",
		"\treturn anchored_to"
	]))
	sheet.events.append(block)
	var ready_row: EventRow = EventRow.new()
	ready_row.trigger_provider_id = "Core"
	ready_row.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"anchor_to(anchored_to)",
		"# A Control is placed by its PARENT, so the parent is what has to be listened to. Without",
		"# this the anchor is a one-off and a resized window leaves the host where it started.",
		"if follow_resizes and host.get_parent() is Control:",
		"\thost.get_parent().resized.connect(func() -> void: anchor_to(anchored_to))"
	]))
	ready_row.actions.append(ready_body)
	sheet.events.append(ready_row)

	Lib.append_function(sheet, "set_margins", "Set Margins", "Anchor",
		"Sets the gap in pixels between the host and the corner it is anchored to - left, top, right, bottom.",
		[["left", "float"], ["top", "float"], ["right", "float"], ["bottom", "float"]],
		"if host == null:\n\treturn\nhost.offset_left = left\nhost.offset_top = top\nhost.offset_right = right\nhost.offset_bottom = bottom")
	Lib.append_function(sheet, "set_keep_size", "Set Keep Size", "Anchor",
		"Whether anchoring keeps the host's current size instead of letting the corner stretch it.",
		[["enabled", "bool"]],
		"keep_size = enabled")
	Lib.append_function(sheet, "set_follow_resizes", "Set Follow Resizes", "Anchor",
		"Whether the host is placed again every time its parent changes size.",
		[["enabled", "bool"]],
		"follow_resizes = enabled")
	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.verb_sentences(sheet, {
		"set_margins": "Set margins [b]{left}[/b], [b]{top}[/b], [b]{right}[/b], [b]{bottom}[/b]",
	})
	Lib.feature_verbs(sheet, ["set_margins"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/anchor/anchor_behavior")
