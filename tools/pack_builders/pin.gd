# Pack builder - pin (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Pin: keeps the host stuck to another object - the event-sheet-parity "Pin to" behavior. Attach to
## any Node2D, call Pin To with the object to ride, and every physics frame the host copies that
## object's place, its angle, or both, offset by however far apart they were when the pin was made.
## Unpin lets go and the host keeps whatever place it had. The one-liner a hundred jam scripts write
## as `global_position = anchor.global_position + offset`, with the offset remembered for you.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "PinBehavior"
	sheet.class_description = "Sticks a Node2D to another object: every physics frame the host copies that object's position, its angle, or both, kept apart by the offset the pin was made with. Health bars over heads, a hat on a player, a turret on a tank, a shadow under a jumper - one action instead of a line of transform arithmetic."
	sheet.addon_category = "Pin"
	sheet.addon_tags = PackedStringArray(["movement", "attachment"])
	var about: CommentRow = CommentRow.new()
	about.text = "Pin behavior (event-sheet parity): the host rides another object. Pin To starts it and remembers how far apart the two were; Pin Mode chooses position, angle, or both; Unpin lets go. Rotate With Anchor turns the offset with the anchor, so a pinned hat swings round the head instead of hovering beside it. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# --- Designer knobs (tune in the Inspector) ---",
		"## What to copy from the object being ridden: its place, its angle, or both.",
		"@export_enum(\"position\", \"angle\", \"position and angle\") var pin_mode: String = \"position and angle\"",
		"## On: the offset turns with the anchor, so the host orbits it. Off: the offset stays axis-aligned.",
		"@export var rotate_with_anchor: bool = true",
		"## Master on/off - Unpin flips it, Pin To turns it back on.",
		"@export var pin_enabled: bool = true",
		"",
		"# --- Internal state ---",
		"# The object being ridden, and how far the host sat from it when the pin was made. The offset",
		"# is stored in the ANCHOR's own frame when rotate_with_anchor is on, which is what lets the",
		"# host swing round with it instead of sliding out of place the moment the anchor turns.",
		"var anchor: Node2D = null",
		"var pin_offset: Vector2 = Vector2.ZERO",
		"var pin_angle_offset: float = 0.0",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Pinned\")",
		"## @ace_description(\"True while the host is riding another object.\")",
		"func is_pinned() -> bool:",
		"\treturn pin_enabled and is_instance_valid(anchor)",
		"",
		"## @ace_expression",
		"## @ace_name(\"PinOffsetX\")",
		"## @ace_description(\"How far the host sits from its anchor along X, in pixels.\")",
		"func pin_offset_x() -> float:",
		"\treturn pin_offset.x",
		"",
		"## @ace_expression",
		"## @ace_name(\"PinOffsetY\")",
		"## @ace_description(\"How far the host sits from its anchor along Y, in pixels.\")",
		"func pin_offset_y() -> float:",
		"\treturn pin_offset.y",
		"",
		"## Chooses what the host copies from its anchor.",
		"## @ace_action",
		"## @ace_name(\"Set Pin Mode\")",
		"## @ace_param_options(mode position=Follow its place only, angle=Follow its angle only, position and angle=Follow both)",
		"func set_pin_mode(mode: String) -> void:",
		"\tif mode in [\"position\", \"angle\", \"position and angle\"]:",
		"\t\tpin_mode = mode"
	]))
	sheet.events.append(block)

	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if not pin_enabled or host == null or not is_instance_valid(anchor):",
		"\treturn",
		"if pin_mode != \"angle\":",
		"\t# The offset rides the anchor's own frame when asked to, so a turning anchor carries the",
		"\t# host round it; otherwise it stays the plain world-space gap the pin was made with.",
		"\tvar offset: Vector2 = pin_offset.rotated(anchor.global_rotation) if rotate_with_anchor else pin_offset",
		"\thost.global_position = anchor.global_position + offset",
		"if pin_mode != \"position\":",
		"\thost.global_rotation = anchor.global_rotation + pin_angle_offset"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	Lib.append_function(sheet, "pin_to", "Pin To", "Pin",
		"Sticks the host to an object, remembering how far apart the two are right now. From this frame on the host rides it.",
		[["target", "Node2D"]],
		"\n".join(PackedStringArray([
			"anchor = target",
			"pin_enabled = is_instance_valid(target)",
			"if not pin_enabled or host == null:",
			"\treturn",
			"var gap: Vector2 = host.global_position - target.global_position",
			"pin_offset = gap.rotated(-target.global_rotation) if rotate_with_anchor else gap",
			"pin_angle_offset = host.global_rotation - target.global_rotation"
		])))
	Lib.append_function(sheet, "pin_to_at", "Pin To At Offset", "Pin",
		"Sticks the host to an object at a chosen distance from it, in pixels, instead of wherever it happens to be standing.",
		[["target", "Node2D"], ["offset_x", "float"], ["offset_y", "float"]],
		"\n".join(PackedStringArray([
			"anchor = target",
			"pin_enabled = is_instance_valid(target)",
			"pin_offset = Vector2(offset_x, offset_y)",
			"pin_angle_offset = 0.0"
		])))
	Lib.append_function(sheet, "set_pin_offset", "Set Pin Offset", "Pin",
		"Moves the host to a new distance from the object it is riding, in pixels.",
		[["offset_x", "float"], ["offset_y", "float"]],
		"pin_offset = Vector2(offset_x, offset_y)")
	Lib.append_function(sheet, "unpin", "Unpin", "Pin",
		"Lets go. The host stays exactly where it was and moves on its own again.",
		[],
		"anchor = null\npin_enabled = false")

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.verb_sentences(sheet, {
		"pin_to": "Pin to [b]{target}[/b]",
		"unpin": "Unpin"
	})
	Lib.feature_verbs(sheet, ["pin_to", "unpin"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/pin/pin_behavior",
		"res://eventsheet_addons/pin/icon.svg")
