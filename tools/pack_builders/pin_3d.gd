# Pack builder - pin_3d (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Pin 3D: the Pin behavior's twin for a Node3D host, mode for mode. It exists because pinning
## is the most-written relationship in a game and 3D had none of it: a health bar over a head, a
## weapon in a hand, a camera target that lags, a lantern on a rope all needed the same arithmetic
## written again in three axes.
##
## The one difference worth knowing is the SEAT. In 2D a named point is a Marker2D or a Bone2D; in
## 3D it is usually a BoneAttachment3D, which Godot already keeps glued to a Skeleton3D bone - so
## Pin To Point names that attachment and the skeleton does the hard half. Everything else - rope,
## bar, soft, spring, one axis at a time, size, path - is the 2D pack's meaning with a Vector3.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node3D"
	sheet.custom_class_name = "Pin3DBehavior"
	sheet.class_description = "Sticks a Node3D to another object: every physics frame the host copies that object's position, its angles, or both, kept apart by the offset the pin was made with. The mode picks HOW it follows - straight onto the place, on a rope that only pulls when taut, on a bar that holds its length, softly with a lag, or on a spring that overshoots and settles. Pin To Point rides a named child, which in 3D is usually the BoneAttachment3D a skeleton already keeps on a bone."
	sheet.addon_category = "Pin 3D"
	sheet.addon_tags = PackedStringArray(["movement", "attachment", "3d"])
	var about: CommentRow = CommentRow.new()
	about.text = "Pin 3D behavior: the host rides another Node3D. Pin To starts it and remembers how far apart the two were; Pin Mode chooses position, angles, both, rope, bar, soft, spring or size; Unpin lets go. Pin To Point rides a named child of the anchor - a BoneAttachment3D on a skeleton's hand, a Marker3D - and Pin To Path rides a point that travels a Path3D. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# --- Designer knobs (tune in the Inspector) ---",
		"## What to copy from the object being ridden, and how to travel to it. The first three are",
		"## the plain copies; rope, bar, soft and spring are the ways a follow can lag or be held at",
		"## a distance, and size copies the anchor's scale instead of its place.",
		"@export_enum(\"position\", \"angle\", \"position and angle\", \"rope\", \"bar\", \"soft\", \"spring\", \"size\") var pin_mode: String = \"position and angle\"",
		"## On: the offset turns with the anchor, so the host orbits it. Off: the offset stays",
		"## axis-aligned to the world.",
		"@export var rotate_with_anchor: bool = true",
		"## Master on/off - Unpin flips it, Pin To turns it back on.",
		"@export var pin_enabled: bool = true",
		"## How long the rope or the bar is, in world units. A rope is slack below this and pulls at",
		"## it; a bar holds the host at exactly this distance, every tick.",
		"@export var pin_length: float = 2.0",
		"## How quickly a soft pin closes the gap, per second. 10 catches up in about a tenth of a",
		"## second; 2 trails a long way behind, which is what makes a chase camera feel alive.",
		"@export var pin_speed: float = 10.0",
		"## Spring pull toward the anchor (higher = snappier) - the same pair of numbers the Spring",
		"## pack's own integrator takes, so a spring pin and a sprung number feel alike.",
		"@export var pin_stiffness: float = 170.0",
		"## 0 = oscillate forever, 1 = no overshoot.",
		"@export var pin_damping: float = 0.85",
		"## Which axes of the place follow. Y only pins a marker to a lift's height; X only or Z only",
		"## pin a rail-mounted thing to one line of the floor.",
		"@export_enum(\"all\", \"x only\", \"y only\", \"z only\") var pin_axes: String = \"all\"",
		"## Also copy the anchor's scale, whatever else the mode copies.",
		"@export var pin_follow_size: bool = false",
		"## The name of a child of the anchor to ride instead of the anchor itself. In 3D this is",
		"## usually a BoneAttachment3D - Godot keeps it on the skeleton's bone and the pin rides it,",
		"## so \"pin the sword to the hand\" is one name. Empty rides the anchor; a name that matches",
		"## nothing falls back to the anchor rather than dropping the pin.",
		"@export var pin_point: String = \"\"",
		"",
		"# --- Internal state ---",
		"# The object being ridden, and how far the host sat from it when the pin was made. The offset",
		"# is stored in the ANCHOR's own frame when rotate_with_anchor is on, which is what lets the",
		"# host swing round with it instead of sliding out of place the moment the anchor turns.",
		"var anchor: Node3D = null",
		"var pin_offset: Vector3 = Vector3.ZERO",
		"# The turn between the host and its seat, kept as a QUATERNION rather than as three Euler",
		"# numbers: adding Euler triples only composes rotations when both turns are about one shared",
		"# axis, and a sword on a rigged hand is exactly the case where they are not.",
		"var pin_turn_offset: Quaternion = Quaternion.IDENTITY",
		"# The spring mode's carried velocity - the one piece of state overshoot needs.",
		"var pin_velocity: Vector3 = Vector3.ZERO",
		"",
		"# The modes that copy a PLACE and the modes that copy an ANGLE, written out rather than",
		"# inferred, exactly as the 2D pack has them.",
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
		"\treturn host.global_position.distance_to(anchor.global_position) >= pin_length - 0.01",
		"",
		"## @ace_expression",
		"## @ace_name(\"PinOffsetX\")",
		"## @ace_description(\"How far the host sits from its anchor along X, in world units.\")",
		"func pin_offset_x() -> float:",
		"\treturn pin_offset.x",
		"",
		"## @ace_expression",
		"## @ace_name(\"PinOffsetY\")",
		"## @ace_description(\"How far the host sits from its anchor along Y, in world units.\")",
		"func pin_offset_y() -> float:",
		"\treturn pin_offset.y",
		"",
		"## @ace_expression",
		"## @ace_name(\"PinOffsetZ\")",
		"## @ace_description(\"How far the host sits from its anchor along Z, in world units.\")",
		"func pin_offset_z() -> float:",
		"\treturn pin_offset.z",
		"",
		"## @ace_expression",
		"## @ace_name(\"PinDistance\")",
		"## @ace_description(\"How far the host currently is from the object it rides, in world units.\")",
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
		"\tvar follower: PathFollow3D = anchor as PathFollow3D",
		"\treturn follower.progress_ratio if follower != null else 0.0",
		"",
		"## Chooses what the host copies from its anchor, and how it travels there.",
		"## @ace_action",
		"## @ace_name(\"Set Pin Mode\")",
		"## Option labels carry no commas on purpose - the picker splits the list on them, so a comma",
		"## inside a label would offer half a sentence as a ninth mode nothing answers to.",
		"## @ace_param_options(mode position=Follow its place only, angle=Follow its angles only, position and angle=Follow both, rope=Hang on a rope and pull only when taut, bar=Hold at exactly the length, soft=Follow with a lag, spring=Overshoot and settle, size=Copy its scale only)",
		# The mode is a WORD picked off the dropdown above, and a dropdown key is inserted into the
		# call verbatim - so the quotes belong in the TEMPLATE, never in the key (a quoted key does
		# not survive the annotation round trip). Without them a row picking Overshoot and settle
		# asked `set_pin_mode(spring)`, an undefined identifier, and the game did not parse.
		"## @ace_codegen_template(\"$Pin3DBehavior.set_pin_mode(\"{mode}\")\")",
		"func set_pin_mode(mode: String) -> void:",
		"\tif mode in [\"position\", \"angle\", \"position and angle\", \"rope\", \"bar\", \"soft\", \"spring\", \"size\"]:",
		"\t\tpin_mode = mode",
		"",
		"## Chooses which axes of the place follow: all of them, or one line of the world only.",
		"## @ace_action",
		"## @ace_name(\"Set Pin Axes\")",
		"## @ace_param_options(axes all=Follow all three axes, x only=Follow X only, y only=Follow the height only, z only=Follow Z only)",
		# Same rule as Set Pin Mode above: the picked word carries its quotes in the template, or
		# `x only` reaches the emitted file as two identifiers with a space between them.
		"## @ace_codegen_template(\"$Pin3DBehavior.set_pin_axes(\"{axes}\")\")",
		"func set_pin_axes(axes: String) -> void:",
		"\tif axes in [\"all\", \"x only\", \"y only\", \"z only\"]:",
		"\t\tpin_axes = axes",
		"",
		"# The node the host actually rides: the anchor, or the named point on it - in 3D usually the",
		"# BoneAttachment3D a skeleton keeps on a bone. The lookup is a RECURSIVE search of the",
		"# anchor's whole subtree, and a rig is exactly the deep tree that makes that expensive, so the",
		"# answer is remembered and searched for again only when it goes stale: a different anchor, a",
		"# different point name, or a seat that has been freed.",
		"var _seat: Node3D = null",
		"var _seat_of: Node3D = null",
		"var _seat_named: String = \"\"",
		"",
		"func _pin_seat() -> Node3D:",
		"\tif pin_point.is_empty():",
		"\t\treturn anchor",
		"\tif _seat_of == anchor and _seat_named == pin_point and is_instance_valid(_seat):",
		"\t\treturn _seat",
		"\tvar point: Node3D = anchor.find_child(pin_point, true, false) as Node3D",
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
		"func _pin_reach(current: Vector3, goal: Vector3, delta: float) -> Vector3:",
		"\tmatch pin_mode:",
		"\t\t\"rope\":",
		"\t\t\tvar slack: Vector3 = current - goal",
		"\t\t\treturn current if slack.length() <= pin_length else goal + slack.normalized() * pin_length",
		"\t\t\"bar\":",
		"\t\t\tvar arm: Vector3 = current - goal",
		"\t\t\tif arm.length() < 0.0001:",
		"\t\t\t\tarm = Vector3.RIGHT",
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
		"func _place_host(goal: Vector3, delta: float) -> void:",
		"\tvar placed: Vector3 = _pin_reach(host.global_position, goal, delta)",
		"\tmatch pin_axes:",
		"\t\t\"x only\":",
		"\t\t\thost.global_position.x = placed.x",
		"\t\t\"y only\":",
		"\t\t\thost.global_position.y = placed.y",
		"\t\t\"z only\":",
		"\t\t\thost.global_position.z = placed.z",
		"\t\t_:",
		"\t\t\thost.global_position = placed",
		"",
		"# Puts every mode knob back to its plain value. Each new pin starts from a clean sheet, or a",
		"# Pin X Position To followed later by a Pin To Rope would quietly give the rope one axis, and",
		"# a Pin Size To would keep copying an old anchor's scale forever.",
		"func _clear_pin_modes() -> void:",
		"\tpin_axes = \"all\"",
		"\tpin_follow_size = false",
		"\tpin_point = \"\"",
		"\tpin_velocity = Vector3.ZERO",
		"",
		"# Starts a pin in one of the distance/lag modes: the anchor's own place is the goal, so the",
		"# offset is cleared and the mode's length or speed does the work.",
		"func _begin_pin(target: Node3D, mode: String) -> void:",
		"\tanchor = target",
		"\tpin_enabled = is_instance_valid(target)",
		"\tpin_mode = mode",
		"\tpin_offset = Vector3.ZERO",
		"\tpin_turn_offset = Quaternion.IDENTITY",
		"\t_clear_pin_modes()",
		"\t# A pin has to copy its anchor every physics frame while it holds, so processing follows",
		"\t# the pin itself: on the moment there is something to ride, off again at Unpin.",
		"\tset_physics_process(pin_enabled)",
		"",
		"# Remembers the gap between the host and a seat, in the seat's own frame when asked to, and",
		"# the turn between the two as a quaternion so it composes correctly on every axis.",
		"func _remember_gap(seat: Node3D) -> void:",
		"\tvar gap: Vector3 = host.global_position - seat.global_position",
		"\tpin_offset = seat.global_transform.basis.inverse() * gap if rotate_with_anchor else gap",
		"\tpin_turn_offset = seat.global_basis.get_rotation_quaternion().inverse() \\",
		"\t\t* host.global_basis.get_rotation_quaternion()"
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
		"var seat: Node3D = _pin_seat()",
		"if seat == null:",
		"\treturn",
		"if pin_mode in PIN_PLACE_MODES:",
		"\t# The offset rides the anchor's own frame when asked to, so a turning anchor carries the",
		"\t# host round it; otherwise it stays the plain world-space gap the pin was made with.",
		"\tvar offset: Vector3 = seat.global_transform.basis * pin_offset if rotate_with_anchor else pin_offset",
		"\t_place_host(seat.global_position + offset, delta)",
		"if pin_mode in PIN_ANGLE_MODES:",
		"\t# Composed as quaternions, then written as a basis with the host's own scale kept - three",
		"\t# added Euler numbers would gimbal the moment the anchor turned about more than one axis.",
		"\tvar turn: Quaternion = seat.global_basis.get_rotation_quaternion() * pin_turn_offset",
		"\thost.global_basis = Basis(turn).scaled(host.scale)",
		"if pin_follow_size or pin_mode == \"size\":",
		"\thost.scale = seat.scale"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	Lib.append_function(sheet, "pin_to", "Pin To", "Pin 3D",
		"Sticks the host to an object, remembering how far apart the two are right now. From this frame on the host rides it. A pin follows at runtime and can let go; a child is structure and is destroyed with its parent - this is the first of those two.",
		[["target", "Node3D"]],
		"\n".join(PackedStringArray([
			"anchor = target",
			"pin_enabled = is_instance_valid(target)",
			"_clear_pin_modes()",
			"# The host rides something from this frame on, which is per-frame work; a target that",
			"# is already gone leaves the tick off rather than running it for nothing.",
			"set_physics_process(pin_enabled)",
			"if not pin_enabled or host == null:",
			"\treturn",
			"_remember_gap(target)"
		])))
	Lib.append_function(sheet, "pin_to_at", "Pin To At Offset", "Pin 3D",
		"Sticks the host to an object at a chosen distance from it, in world units, instead of wherever it happens to be standing.",
		[["target", "Node3D"], ["offset_x", "float"], ["offset_y", "float"], ["offset_z", "float"]],
		"\n".join(PackedStringArray([
			"anchor = target",
			"pin_enabled = is_instance_valid(target)",
			"pin_offset = Vector3(offset_x, offset_y, offset_z)",
			"pin_turn_offset = Quaternion.IDENTITY",
			"_clear_pin_modes()",
			"# The host rides something from this frame on, which is per-frame work; a target that",
			"# is already gone leaves the tick off rather than running it for nothing.",
			"set_physics_process(pin_enabled)"
		])))
	Lib.append_function(sheet, "set_pin_offset", "Set Pin Offset", "Pin 3D",
		"Moves the host to a new distance from the object it is riding, in world units.",
		[["offset_x", "float"], ["offset_y", "float"], ["offset_z", "float"]],
		"pin_offset = Vector3(offset_x, offset_y, offset_z)")
	Lib.append_function(sheet, "pin_rope", "Pin To Rope", "Pin 3D",
		"Hangs the host off an object on a rope of the given length. Inside that length it moves freely; past it the rope goes taut and pulls it back - a lantern on a pole, a leash, a wrecking ball.",
		[["target", "Node3D"], ["max_length", "float"]],
		"_begin_pin(target, \"rope\")\npin_length = maxf(max_length, 0.0)",
		"Pin to [i]{target}[/i] on a rope of [b]{max_length}[/b]")
	Lib.append_function(sheet, "pin_bar", "Pin To Bar", "Pin 3D",
		"Holds the host at exactly the given distance from an object, every tick, in whatever direction it already lies - a linked cart, a rigid arm, a carriage coupling.",
		[["target", "Node3D"], ["length", "float"]],
		"_begin_pin(target, \"bar\")\npin_length = maxf(length, 0.0)",
		"Pin to [i]{target}[/i] on a bar of [b]{length}[/b]")
	Lib.append_function(sheet, "pin_soft", "Pin To Softly", "Pin 3D",
		"Follows an object with a lag instead of snapping onto it. The speed is how much of the gap is closed each second - low numbers trail a long way behind, which is what makes a chase camera feel alive.",
		[["target", "Node3D"], ["speed", "float"]],
		"_begin_pin(target, \"soft\")\npin_speed = maxf(speed, 0.0)",
		"Pin to [i]{target}[/i] softly at [b]{speed}[/b]")
	Lib.append_function(sheet, "pin_spring", "Pin To With Spring", "Pin 3D",
		"Follows an object on a spring: it overshoots, wobbles and settles instead of arriving flat. Stiffness is the pull, damping is how fast the wobble dies (0 never settles, 1 never overshoots) - the same pair of numbers the Spring pack's own integrator takes.",
		[["target", "Node3D"], ["stiffness", "float"], ["damping", "float"]],
		"_begin_pin(target, \"spring\")\npin_stiffness = maxf(stiffness, 0.0)\npin_damping = clampf(damping, 0.0, 1.0)",
		"Pin to [i]{target}[/i] with a spring ([b]{stiffness}[/b], [b]{damping}[/b])")
	Lib.append_function(sheet, "pin_x_to", "Pin X Position To", "Pin 3D",
		"Follows an object along X and nothing else: the host keeps its own height and depth.",
		[["target", "Node3D"]],
		"_begin_pin(target, \"position\")\npin_axes = \"x only\"",
		"Pin X position to [i]{target}[/i]")
	Lib.append_function(sheet, "pin_y_to", "Pin Y Position To", "Pin 3D",
		"Follows an object's height and nothing else: the host keeps its own place on the floor. A marker that rides a lift, a water line.",
		[["target", "Node3D"]],
		"_begin_pin(target, \"position\")\npin_axes = \"y only\"",
		"Pin Y position to [i]{target}[/i]")
	Lib.append_function(sheet, "pin_z_to", "Pin Z Position To", "Pin 3D",
		"Follows an object along Z and nothing else: the host keeps its own X and height.",
		[["target", "Node3D"]],
		"_begin_pin(target, \"position\")\npin_axes = \"z only\"",
		"Pin Z position to [i]{target}[/i]")
	Lib.append_function(sheet, "pin_size_to", "Pin Size To", "Pin 3D",
		"Copies an object's scale and nothing else, so the host grows and shrinks with it - a shadow decal that swells as its owner lands, a selection ring around a resizing prop.",
		[["target", "Node3D"]],
		"_begin_pin(target, \"size\")\npin_follow_size = true",
		"Pin size to [i]{target}[/i]")
	Lib.append_function(sheet, "pin_to_point", "Pin To Point", "Pin 3D",
		"Rides a NAMED child of an object rather than the object itself - usually the BoneAttachment3D a skeleton keeps on a bone, so \"pin the sword to the hand\" is one name. The gap the two are standing at right now is remembered, exactly as Pin To does.",
		[["target", "Node3D"], ["point_name", "String"]],
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
			"var seat: Node3D = _pin_seat()",
			"if seat == null:",
			"\treturn",
			"_remember_gap(seat)"
		])),
		"Pin to [i]{target}[/i]'s [b]{point_name}[/b]")
	Lib.append_function(sheet, "pin_to_path", "Pin To Path", "Pin 3D",
		"Rides a point that travels a curve. Pass a PathFollow3D and the host rides that one; pass a Path3D and the pack makes the follower once and rides it. Set Path Progress then drives the host along the curve.",
		[["path_node", "Node3D"]],
		"\n".join(PackedStringArray([
			"var follower: PathFollow3D = path_node as PathFollow3D",
			"if follower == null:",
			"\tvar path: Path3D = path_node as Path3D",
			"\tif path == null:",
			"\t\treturn",
			"\tfollower = path.get_node_or_null(NodePath(\"PinPathFollow\")) as PathFollow3D",
			"\tif follower == null:",
			"\t\tfollower = PathFollow3D.new()",
			"\t\tfollower.name = \"PinPathFollow\"",
			"\t\tfollower.loop = true",
			"\t\tpath.add_child(follower)",
			"_begin_pin(follower, \"position\")",
			"pin_point = \"\""
		])),
		"Pin to [i]{path_node}[/i]'s path position")
	Lib.append_function(sheet, "set_path_progress", "Set Path Progress", "Pin 3D",
		"Moves a path pin along its curve, 0 at the start and 1 at the end. Does nothing when the pin is not riding a path.",
		[["ratio", "float"]],
		"\n".join(PackedStringArray([
			"if not is_instance_valid(anchor):",
			"\treturn",
			"var follower: PathFollow3D = anchor as PathFollow3D",
			"if follower != null:",
			"\tfollower.progress_ratio = clampf(ratio, 0.0, 1.0)"
		])))
	Lib.append_function(sheet, "unpin", "Unpin", "Pin 3D",
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
	return Lib.save_pack(sheet, "res://eventsheet_addons/pin_3d/pin_3d_behavior",
		"res://eventsheet_addons/pin_3d/icon.svg")
