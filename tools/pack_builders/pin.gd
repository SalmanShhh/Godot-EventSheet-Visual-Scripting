# Pack builder - pin (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Pin: keeps the host stuck to another object - the event-sheet-parity "Pin to" behavior. Attach to
## any Node2D, call Pin To with the object to ride, and every physics frame the host copies that
## object's place, its angle, or both, offset by however far apart they were when the pin was made.
## Unpin lets go and the host keeps whatever place it had. The one-liner a hundred jam scripts write
## as `global_position = anchor.global_position + offset`, with the offset remembered for you.
##
## Grew the mode past position/angle/both into the shapes people write by hand around a pin:
## a ROPE that only pulls when it is taut, a BAR that holds its length, a SOFT follow that lags, a
## SPRING that overshoots and settles, one AXIS at a time, the anchor's SIZE, a named POINT on the
## anchor (a bone, a marker, a hand) and a moving point on a PATH. Every shipped id and template is
## untouched: the enum grew, the knobs are new, and the new modes arrived as their own rows.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "PinBehavior"
	sheet.class_description = "Sticks a Node2D to another object: every physics frame the host copies that object's position, its angle, or both, kept apart by the offset the pin was made with. Health bars over heads, a hat on a player, a turret on a tank, a shadow under a jumper - one action instead of a line of transform arithmetic. The mode picks HOW it follows: straight onto the place, on a rope that only pulls when taut, on a bar that holds its length, softly with a lag, or on a spring that overshoots and settles."
	sheet.addon_category = "Pin"
	sheet.addon_tags = PackedStringArray(["movement", "attachment"])
	var about: CommentRow = CommentRow.new()
	about.text = "Pin behavior (event-sheet parity): the host rides another object. Pin To starts it and remembers how far apart the two were; Pin Mode chooses position, angle, both, rope, bar, soft, spring or size; Unpin lets go. Rotate With Anchor turns the offset with the anchor, so a pinned hat swings round the head instead of hovering beside it. Pin To Point rides a named child of the anchor - a bone, a marker, a hand - and Pin To Path rides a point that travels a Path2D. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# --- Designer knobs (tune in the Inspector) ---",
		"## What to copy from the object being ridden, and how to travel to it. The first three are",
		"## the plain copies; rope, bar, soft and spring are the ways a follow can lag or be held at",
		"## a distance, and size copies the anchor's scale instead of its place.",
		"@export_enum(\"position\", \"angle\", \"position and angle\", \"rope\", \"bar\", \"soft\", \"spring\", \"size\") var pin_mode: String = \"position and angle\"",
		"## On: the offset turns with the anchor, so the host orbits it. Off: the offset stays axis-aligned.",
		"@export var rotate_with_anchor: bool = true",
		"## Master on/off - Unpin flips it, Pin To turns it back on.",
		"@export var pin_enabled: bool = true",
		"## How long the rope or the bar is, in pixels. A rope is slack below this and pulls at it; a",
		"## bar holds the host at exactly this distance, every tick.",
		"@export var pin_length: float = 80.0",
		"## How quickly a soft pin closes the gap, per second. 10 catches up in about a tenth of a",
		"## second; 2 trails a long way behind, which is what makes a follower feel alive.",
		"@export var pin_speed: float = 10.0",
		"## Spring pull toward the anchor (higher = snappier) - the same pair of numbers the Spring",
		"## pack's own integrator takes, so a spring pin and a sprung number feel alike.",
		"@export var pin_stiffness: float = 170.0",
		"## 0 = oscillate forever, 1 = no overshoot.",
		"@export var pin_damping: float = 0.85",
		"## Which axes of the place follow. X only pins a shadow to a walker's column; Y only pins a",
		"## side-bar to its height.",
		"@export_enum(\"both\", \"x only\", \"y only\") var pin_axes: String = \"both\"",
		"## Also copy the anchor's scale, whatever else the mode copies.",
		"@export var pin_follow_size: bool = false",
		"## The name of a child of the anchor to ride instead of the anchor itself - a Bone2D, a",
		"## Marker2D, the hand a weapon hangs off. Empty rides the anchor. A name that matches nothing",
		"## falls back to the anchor rather than dropping the pin.",
		"@export var pin_point: String = \"\"",
		"",
		"# --- Internal state ---",
		"# The object being ridden, and how far the host sat from it when the pin was made. The offset",
		"# is stored in the ANCHOR's own frame when rotate_with_anchor is on, which is what lets the",
		"# host swing round with it instead of sliding out of place the moment the anchor turns.",
		"var anchor: Node2D = null",
		"var pin_offset: Vector2 = Vector2.ZERO",
		"var pin_angle_offset: float = 0.0",
		"# The spring mode's carried velocity - the one piece of state overshoot needs.",
		"var pin_velocity: Vector2 = Vector2.ZERO",
		"",
		"# The modes that copy a PLACE and the modes that copy an ANGLE, written out rather than",
		"# inferred. The three shipped modes keep exactly the meaning they always had (\"position and",
		"# angle\" is in both lists, \"position\" only in the first, \"angle\" only in the second); the new",
		"# modes are all ways of travelling to a place, so they join the first list only.",
		"## @ace_hidden",
		"const PIN_PLACE_MODES: PackedStringArray = [",
		"\t\"position\", \"position and angle\", \"rope\", \"bar\", \"soft\", \"spring\"",
		"]",
		"## @ace_hidden",
		"const PIN_ANGLE_MODES: PackedStringArray = [\"angle\", \"position and angle\"]",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Pinned\")",
		"## @ace_description(\"True while the host is riding another object.\")",
		"func is_pinned() -> bool:",
		"\treturn pin_enabled and is_instance_valid(anchor)",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Taut\")",
		"## @ace_description(\"True while a rope or bar pin is stretched out to its full length - the frame a swing starts pulling. Always false in the other modes, which have no length to be stretched to.\")",
		"func is_taut() -> bool:",
		"\tif not pin_mode in [\"rope\", \"bar\"] or host == null or not is_instance_valid(anchor):",
		"\t\treturn false",
		"\treturn host.global_position.distance_to(anchor.global_position) >= pin_length - 0.5",
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
		"## @ace_expression",
		"## @ace_name(\"PinDistance\")",
		"## @ace_description(\"How far the host currently is from the object it rides, in pixels.\")",
		"func pin_distance() -> float:",
		"\tif host == null or not is_instance_valid(anchor):",
		"\t\treturn 0.0",
		"\treturn host.global_position.distance_to(anchor.global_position)",
		"",
		"## @ace_expression",
		"## @ace_name(\"PinPathProgress\")",
		"## @ace_description(\"How far along its path a path pin has travelled, 0 to 1. Zero when the pin is not riding a path.\")",
		"func pin_path_progress() -> float:",
		"\tif not is_instance_valid(anchor):",
		"\t\treturn 0.0",
		"\tvar follower: PathFollow2D = anchor as PathFollow2D",
		"\treturn follower.progress_ratio if follower != null else 0.0",
		"",
		"## Chooses what the host copies from its anchor, and how it travels there.",
		"## @ace_action",
		"## @ace_name(\"Set Pin Mode\")",
		"## Option labels carry no commas on purpose - the picker splits the list on them, so a comma",
		"## inside a label would offer half a sentence as a ninth mode nothing answers to.",
		"## @ace_param_options(mode position=Follow its place only, angle=Follow its angle only, position and angle=Follow both, rope=Hang on a rope and pull only when taut, bar=Hold at exactly the length, soft=Follow with a lag, spring=Overshoot and settle, size=Copy its scale only)",
		"func set_pin_mode(mode: String) -> void:",
		"\tif mode in [\"position\", \"angle\", \"position and angle\", \"rope\", \"bar\", \"soft\", \"spring\", \"size\"]:",
		"\t\tpin_mode = mode",
		"",
		"## Chooses which axes of the place follow: both of them, the column only, or the height only.",
		"## @ace_action",
		"## @ace_name(\"Set Pin Axes\")",
		"## @ace_param_options(axes both=Follow both axes, x only=Follow the column only, y only=Follow the height only)",
		"func set_pin_axes(axes: String) -> void:",
		"\tif axes in [\"both\", \"x only\", \"y only\"]:",
		"\t\tpin_axes = axes",
		"",
		"# The node the host actually rides: the anchor, or the named point on it. The lookup is a",
		"# RECURSIVE search of the anchor's whole subtree - fine once, far too much every physics",
		"# frame - so the answer is remembered and only searched for again when it goes stale: a",
		"# different anchor, a different point name, or a seat that has been freed. A skeleton that",
		"# re-parents its attachments therefore still cannot leave the pin holding a dead node.",
		"var _seat: Node2D = null",
		"var _seat_of: Node2D = null",
		"var _seat_named: String = \"\"",
		"",
		"func _pin_seat() -> Node2D:",
		"\tif pin_point.is_empty():",
		"\t\treturn anchor",
		"\tif _seat_of == anchor and _seat_named == pin_point and is_instance_valid(_seat):",
		"\t\treturn _seat",
		"\tvar point: Node2D = anchor.find_child(pin_point, true, false) as Node2D",
		"\tif point == null:",
		"\t\t# A name that matches nothing rides the anchor and is NOT remembered, so a rig that adds",
		"\t\t# the attachment later still gets picked up.",
		"\t\treturn anchor",
		"\t_seat = point",
		"\t_seat_of = anchor",
		"\t_seat_named = pin_point",
		"\treturn _seat",
		"",
		"# Where the host ends up this frame, for the mode it is in. The straight modes land on the",
		"# goal; a rope hangs free until the line is taut and is then pulled back onto it; a bar is held",
		"# at exactly its length in whatever direction the host already lies; soft closes a share of the",
		"# gap; spring carries a velocity, so it overshoots and settles.",
		"func _pin_reach(current: Vector2, goal: Vector2, delta: float) -> Vector2:",
		"\tmatch pin_mode:",
		"\t\t\"rope\":",
		"\t\t\tvar slack: Vector2 = current - goal",
		"\t\t\treturn current if slack.length() <= pin_length else goal + slack.normalized() * pin_length",
		"\t\t\"bar\":",
		"\t\t\tvar arm: Vector2 = current - goal",
		"\t\t\tif arm.length() < 0.0001:",
		"\t\t\t\tarm = Vector2.RIGHT",
		"\t\t\treturn goal + arm.normalized() * pin_length",
		"\t\t\"soft\":",
		"\t\t\treturn current.lerp(goal, clampf(pin_speed * delta, 0.0, 1.0))",
		"\t\t\"spring\":",
		"\t\t\tpin_velocity += (goal - current) * pin_stiffness * delta",
		"\t\t\tpin_velocity *= pow(1.0 - clampf(pin_damping, 0.0, 1.0), delta)",
		"\t\t\treturn current + pin_velocity * delta",
		"\treturn goal",
		"",
		"# Writes the reached place onto the host, one axis at a time when the pin is axis-locked.",
		"func _place_host(goal: Vector2, delta: float) -> void:",
		"\tvar placed: Vector2 = _pin_reach(host.global_position, goal, delta)",
		"\tif pin_axes == \"x only\":",
		"\t\thost.global_position.x = placed.x",
		"\telif pin_axes == \"y only\":",
		"\t\thost.global_position.y = placed.y",
		"\telse:",
		"\t\thost.global_position = placed",
		"",
		"# Puts every mode knob back to its plain value. Each new pin starts from a clean sheet, or a",
		"# Pin X Position To followed later by a Pin To Rope would quietly give the rope one axis, and",
		"# a Pin Size To would keep copying an old anchor's scale forever.",
		"func _clear_pin_modes() -> void:",
		"\tpin_axes = \"both\"",
		"\tpin_follow_size = false",
		"\tpin_point = \"\"",
		"\tpin_velocity = Vector2.ZERO",
		"",
		"# Starts a pin in one of the distance/lag modes: the anchor's own place is the goal, so the",
		"# offset is cleared and the mode's length or speed does the work.",
		"func _begin_pin(target: Node2D, mode: String) -> void:",
		"\tanchor = target",
		"\tpin_enabled = is_instance_valid(target)",
		"\tpin_mode = mode",
		"\tpin_offset = Vector2.ZERO",
		"\tpin_angle_offset = 0.0",
		"\t_clear_pin_modes()",
		"\t# A pin has to copy its anchor every physics frame while it holds, so processing follows",
		"\t# the pin itself: on the moment there is something to ride, off again at Unpin.",
		"\tset_physics_process(pin_enabled)"
	]))
	sheet.events.append(block)

	var ready_row: EventRow = EventRow.new()
	ready_row.trigger_provider_id = "Core"
	ready_row.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"# Nothing is being ridden until a Pin To row names something, and the tick can do no work",
		"# without an anchor - so a pin that has not been made yet costs nothing per physics frame.",
		"set_physics_process(is_pinned())"
	]))
	ready_row.actions.append(ready_body)
	sheet.events.append(ready_row)

	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if not pin_enabled or host == null or not is_instance_valid(anchor):",
		"\treturn",
		"var seat: Node2D = _pin_seat()",
		"if seat == null:",
		"\treturn",
		"if pin_mode in PIN_PLACE_MODES:",
		"\t# The offset rides the anchor's own frame when asked to, so a turning anchor carries the",
		"\t# host round it; otherwise it stays the plain world-space gap the pin was made with.",
		"\tvar offset: Vector2 = pin_offset.rotated(seat.global_rotation) if rotate_with_anchor else pin_offset",
		"\t_place_host(seat.global_position + offset, delta)",
		"if pin_mode in PIN_ANGLE_MODES:",
		"\thost.global_rotation = seat.global_rotation + pin_angle_offset",
		"if pin_follow_size or pin_mode == \"size\":",
		"\thost.scale = seat.scale"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	Lib.append_function(sheet, "pin_to", "Pin To", "Pin",
		"Sticks the host to an object, remembering how far apart the two are right now. From this frame on the host rides it. A pin follows at runtime and can let go; a child is structure and is destroyed with its parent - this is the first of those two.",
		[["target", "Node2D"]],
		"\n".join(PackedStringArray([
			"anchor = target",
			"pin_enabled = is_instance_valid(target)",
			"_clear_pin_modes()",
			"# The host rides something from this frame on, which is per-frame work; a target that",
			"# is already gone leaves the tick off rather than running it for nothing.",
			"set_physics_process(pin_enabled)",
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
			"pin_angle_offset = 0.0",
			"_clear_pin_modes()",
			"# The host rides something from this frame on, which is per-frame work; a target that",
			"# is already gone leaves the tick off rather than running it for nothing.",
			"set_physics_process(pin_enabled)"
		])))
	Lib.append_function(sheet, "set_pin_offset", "Set Pin Offset", "Pin",
		"Moves the host to a new distance from the object it is riding, in pixels.",
		[["offset_x", "float"], ["offset_y", "float"]],
		"pin_offset = Vector2(offset_x, offset_y)")
	Lib.append_function(sheet, "pin_rope", "Pin To Rope", "Pin",
		"Hangs the host off an object on a rope of the given length. Inside that length it moves freely; past it the rope goes taut and pulls it back - a lantern on a stick, a leash, a wrecking ball.",
		[["target", "Node2D"], ["max_length", "float"]],
		"_begin_pin(target, \"rope\")\npin_length = maxf(max_length, 0.0)",
		"Pin to [i]{target}[/i] on a rope of [b]{max_length}[/b]")
	Lib.append_function(sheet, "pin_bar", "Pin To Bar", "Pin",
		"Holds the host at exactly the given distance from an object, every tick, in whatever direction it already lies - a linked cart, a rigid arm, a carriage coupling.",
		[["target", "Node2D"], ["length", "float"]],
		"_begin_pin(target, \"bar\")\npin_length = maxf(length, 0.0)",
		"Pin to [i]{target}[/i] on a bar of [b]{length}[/b]")
	Lib.append_function(sheet, "pin_soft", "Pin To Softly", "Pin",
		"Follows an object with a lag instead of snapping onto it. The speed is how much of the gap is closed each second - low numbers trail a long way behind, which is what makes a camera target or a pet feel alive.",
		[["target", "Node2D"], ["speed", "float"]],
		"_begin_pin(target, \"soft\")\npin_speed = maxf(speed, 0.0)",
		"Pin to [i]{target}[/i] softly at [b]{speed}[/b]")
	Lib.append_function(sheet, "pin_spring", "Pin To With Spring", "Pin",
		"Follows an object on a spring: it overshoots, wobbles and settles instead of arriving flat. Stiffness is the pull, damping is how fast the wobble dies (0 never settles, 1 never overshoots) - the same pair of numbers the Spring pack's own integrator takes.",
		[["target", "Node2D"], ["stiffness", "float"], ["damping", "float"]],
		"_begin_pin(target, \"spring\")\npin_stiffness = maxf(stiffness, 0.0)\npin_damping = clampf(damping, 0.0, 1.0)",
		"Pin to [i]{target}[/i] with a spring ([b]{stiffness}[/b], [b]{damping}[/b])")
	Lib.append_function(sheet, "pin_x_to", "Pin X Position To", "Pin",
		"Follows an object's column and nothing else: the host keeps its own height. A shadow under a jumper, a rail-mounted turret.",
		[["target", "Node2D"]],
		"_begin_pin(target, \"position\")\npin_axes = \"x only\"",
		"Pin X position to [i]{target}[/i]")
	Lib.append_function(sheet, "pin_y_to", "Pin Y Position To", "Pin",
		"Follows an object's height and nothing else: the host keeps its own column. A side bar that rides a lift, a depth marker.",
		[["target", "Node2D"]],
		"_begin_pin(target, \"position\")\npin_axes = \"y only\"",
		"Pin Y position to [i]{target}[/i]")
	Lib.append_function(sheet, "pin_size_to", "Pin Size To", "Pin",
		"Copies an object's scale and nothing else, so the host grows and shrinks with it - a shadow that swells as its owner lands, a selection ring around a resizing token.",
		[["target", "Node2D"]],
		"_begin_pin(target, \"size\")\npin_follow_size = true",
		"Pin size to [i]{target}[/i]")
	Lib.append_function(sheet, "pin_to_point", "Pin To Point", "Pin",
		"Rides a NAMED child of an object rather than the object itself - a Bone2D, a Marker2D, the hand a weapon hangs off. The gap the two are standing at right now is remembered, exactly as Pin To does.",
		[["target", "Node2D"], ["point_name", "String"]],
		"\n".join(PackedStringArray([
			"anchor = target",
			"pin_enabled = is_instance_valid(target)",
			"_clear_pin_modes()",
			"pin_point = point_name",
			"pin_mode = \"position and angle\"",
			"# The host rides something from this frame on, which is per-frame work; a target that",
			"# is already gone leaves the tick off rather than running it for nothing.",
			"set_physics_process(pin_enabled)",
			"if not pin_enabled or host == null:",
			"\treturn",
			"var seat: Node2D = _pin_seat()",
			"if seat == null:",
			"\treturn",
			"var gap: Vector2 = host.global_position - seat.global_position",
			"pin_offset = gap.rotated(-seat.global_rotation) if rotate_with_anchor else gap",
			"pin_angle_offset = host.global_rotation - seat.global_rotation"
		])),
		"Pin to [i]{target}[/i]'s [b]{point_name}[/b]")
	Lib.append_function(sheet, "pin_to_path", "Pin To Path", "Pin",
		"Rides a point that travels a curve. Pass a PathFollow2D and the host rides that one; pass a Path2D and the pack makes the follower once and rides it. Set Path Progress then drives the host along the curve.",
		[["path_node", "Node2D"]],
		"\n".join(PackedStringArray([
			"var follower: PathFollow2D = path_node as PathFollow2D",
			"if follower == null:",
			"\tvar path: Path2D = path_node as Path2D",
			"\tif path == null:",
			"\t\treturn",
			"\tfollower = path.get_node_or_null(NodePath(\"PinPathFollow\")) as PathFollow2D",
			"\tif follower == null:",
			"\t\tfollower = PathFollow2D.new()",
			"\t\tfollower.name = \"PinPathFollow\"",
			"\t\tfollower.loop = true",
			"\t\tpath.add_child(follower)",
			"_begin_pin(follower, \"position\")",
			"pin_point = \"\""
		])),
		"Pin to [i]{path_node}[/i]'s path position")
	Lib.append_function(sheet, "set_path_progress", "Set Path Progress", "Pin",
		"Moves a path pin along its curve, 0 at the start and 1 at the end. Does nothing when the pin is not riding a path.",
		[["ratio", "float"]],
		"\n".join(PackedStringArray([
			"if not is_instance_valid(anchor):",
			"\treturn",
			"var follower: PathFollow2D = anchor as PathFollow2D",
			"if follower != null:",
			"\tfollower.progress_ratio = clampf(ratio, 0.0, 1.0)"
		])))
	Lib.append_function(sheet, "unpin", "Unpin", "Pin",
		"Lets go. The host stays exactly where it was and moves on its own again.",
		[],
		"\n".join(PackedStringArray([
			"anchor = null",
			"pin_enabled = false",
			"_clear_pin_modes()",
			"# Let go and the host moves on its own, so the copy-every-frame work is over - Pin To",
			"# turns processing back on. The host keeps the place it already had, written before this.",
			"set_physics_process(false)"
		])))

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.verb_sentences(sheet, {
		"pin_to": "Pin to [b]{target}[/b]",
		"unpin": "Unpin"
	})
	Lib.feature_verbs(sheet, ["pin_to", "unpin"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/pin/pin_behavior",
		"res://eventsheet_addons/pin/icon.svg")
