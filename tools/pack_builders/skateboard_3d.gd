# Pack builder - skateboard_3d (one pack per file; run via tools/build_sample_behaviors.gd).
#
# The 3D twin of the Skateboard pack, on a CharacterBody3D. Same words, same order, one surface
# instead of one floor: rolling projects gravity onto the surface normal, the board is kept flat
# on it, and leaving a near-vertical transition is announced as its own moment so a halfpipe lip
# is a thing a sheet can answer rather than a number nobody can name.
#
# What this pack deliberately does NOT own, because it already ships elsewhere and composing is
# the point: the trick INPUTS (a combo pack turns an input sequence into one named event), the
# animation the trick plays (an animation tree travels to a state), the wipeout (the physics rows
# throw a body around), and the camera (an orbit behaviour rides behind the skater). This pack
# supplies the moments those hang off - On Ollie, On Launched Off The Lip, On Landed Clean,
# On Bailed - and the rows that move the board.
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody3D"
	sheet.custom_class_name = "Skateboard3DMovement"
	sheet.class_description = "Momentum movement for a CharacterBody3D on a board: Push nudges you toward the top speed along the way the board faces and you keep it, Roll With The Slope projects gravity onto the surface normal so bowls and quarterpipes work, Align The Board To The Surface keeps it flat on ramps, and leaving a near-vertical transition fires On Launched Off The Lip. Tricks are turns in the air judged on touchdown by the board's up against the surface normal, grinds snap to any Path3D, and a trick chain multiplies everything landed without touching down."
	sheet.addon_category = "Skateboard 3D"
	sheet.ace_expose_all_mode = "node"
	sheet.addon_tags = PackedStringArray(["movement", "skateboard", "momentum", "grind", "3d"])
	# Declaration order IS the order the members are emitted in, so these are listed in the
	# order the shipped pack reads (exported tuning and internal state interleaved).
	sheet.variables = {
		"_balance": {"type": "float", "default": 0.0, "exported": false},
		"_balancing": {"type": "bool", "default": false, "exported": false},
		"_banked_score": {"type": "float", "default": 0.0, "exported": false},
		"_chain_multiplier": {"type": "int", "default": 1, "exported": false},
		"_chain_score": {"type": "float", "default": 0.0, "exported": false},
		"_grind_direction": {"type": "float", "default": 1.0, "exported": false},
		"_grinding": {"type": "bool", "default": false, "exported": false},
		"_manual": {"type": "bool", "default": false, "exported": false},
		"_rail_offset": {"type": "float", "default": 0.0, "exported": false},
		"_spin_turns": {"type": "float", "default": 0.0, "exported": false},
		"_was_on_floor": {"type": "bool", "default": false, "exported": false},
		"_zip_speed": {"type": "float", "default": 0.0, "exported": false},
		"_zipline": {"type": "bool", "default": false, "exported": false},
		"align_speed": {"type": "float", "default": 12.0, "exported": true,
			"attributes": {"tooltip": "How quickly the board swings flat onto the surface it is on. Higher is snappier, lower reads as suspension."}},
		"balance_drift": {"type": "float", "default": 0.8, "exported": true,
			"attributes": {"tooltip": "How fast balance slides toward the edge per second while you are balancing. 0 is a free ride."}},
		"balance_steer": {"type": "float", "default": 1.6, "exported": true,
			"attributes": {"tooltip": "How hard one full steer pushes balance back toward the middle, per second."}},
		"balance_warn": {"type": "float", "default": 0.6, "exported": true,
			"attributes": {"tooltip": "How far out balance has to be before Is Losing Balance says yes. 1 is the bail.", "range": {"min": "0", "max": "1", "step": "0.05"}}},
		"friction": {"type": "float", "default": 1.4, "exported": true,
			"attributes": {"tooltip": "Rolling friction on the ground (m/s²). Low, because a board coasts."}},
		"gravity": {"type": "float", "default": 24.0, "exported": true,
			"attributes": {"tooltip": "Downward acceleration (m/s²). Roll With The Slope projects this onto the surface."}},
		"grind_speed": {"type": "float", "default": 10.0, "exported": true,
			"attributes": {"tooltip": "Default speed along a rail (m/s) when a grind is not keeping your momentum."}},
		"hop_off_speed": {"type": "float", "default": 4.5, "exported": true,
			"attributes": {"tooltip": "Upward speed a hop off a rail gives you (m/s)."}},
		"landing_tolerance_degrees": {"type": "float", "default": 25.0, "exported": true,
			"attributes": {"tooltip": "How far the board's up may be off the surface normal and still land clean. Wider is friendlier.", "range": {"min": "1", "max": "90", "step": "1"}}},
		"lip_angle_degrees": {"type": "float", "default": 55.0, "exported": true,
			"attributes": {"tooltip": "How steep a surface has to be for leaving it to count as a lip launch rather than an ordinary drop off an edge.", "range": {"min": "10", "max": "89", "step": "1"}}},
		"lip_boost": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "Extra upward speed a lip launch adds on top of the speed the transition already gave you (m/s). Leave at 0 for honest physics."}},
		"max_fall_speed": {"type": "float", "default": 40.0, "exported": true,
			"attributes": {"tooltip": "Terminal velocity - gravity never pulls you down faster than this."}},
		"max_speed": {"type": "float", "default": 18.0, "exported": true,
			"attributes": {"tooltip": "The fastest a push will take you (m/s). A slope can still carry you past it."}},
		"ollie_speed": {"type": "float", "default": 6.0, "exported": true,
			"attributes": {"tooltip": "Upward speed an ollie gives you (m/s)."}},
		"push_speed": {"type": "float", "default": 2.0, "exported": true,
			"attributes": {"tooltip": "How much speed one push adds toward the top speed (m/s). A board keeps it - there is no per-tick acceleration here."}},
		"rail_snap_distance": {"type": "float", "default": 0.6, "exported": true,
			"attributes": {"tooltip": "How close to the rail's line the board has to be for Is Near Rail to say yes (m)."}},
		"slope_grip": {"type": "float", "default": 1.0, "exported": true,
			"attributes": {"tooltip": "How much of gravity the surface hands you. 1 is a real ramp, above 1 exaggerates it, 0 makes hills flat.", "range": {"min": "0", "max": "3", "step": "0.05"}}},
		"trick_spin_rate": {"type": "float", "default": 1.0, "exported": true,
			"attributes": {"tooltip": "Default turns per second a Spin or Flip trick turns at."}}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "Skateboard 3D movement: attach under a CharacterBody3D. Push to gain speed and keep it, Roll With The Slope and Align The Board To The Surface every tick so bowls and quarterpipes work, Ollie to leave the ground, Spin or Flip in the air, and let the landing decide between On Landed Clean and On Bailed. Grinds snap to any Path3D."
	sheet.events.append(about)

	sheet.events.append(_declarations())
	sheet.events.append(_tick())
	_append_board_verbs(sheet)
	_append_trick_verbs(sheet)
	_append_chain_verbs(sheet)
	_append_grind_verbs(sheet)

	Lib.feature_verbs(sheet, ["push", "ollie", "roll_with_slope"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/skateboard_3d/skateboard_3d_behavior")


## Triggers, conditions, expressions and the private kernels, as one annotated class-level block.
static func _declarations() -> RawCodeRow:
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Ollie\")",
		"## @ace_category(\"Skateboard 3D\")",
		"## @ace_description(\"Fires the moment an ollie leaves the ground.\")",
		"signal ollied",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Launched Off The Lip\")",
		"## @ace_category(\"Skateboard 3D\")",
		"## @ace_description(\"Fires when the board leaves a surface steeper than the lip angle - the top of a quarterpipe or a bowl transition - rather than simply dropping off a ledge. The speed the transition built is already carrying the board up when this runs, and the board is squared to the lip it left.\")",
		"signal launched_off_the_lip",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Landed Clean\")",
		"## @ace_category(\"Skateboard 3D\")",
		"## @ace_description(\"Fires on touching down with the board's up within the landing tolerance of the surface normal. The board is squared to the surface before this runs.\")",
		"signal landed_clean",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Bailed\")",
		"## @ace_category(\"Skateboard 3D\")",
		"## @ace_description(\"Fires when a landing came in too crooked, balance ran out, or Bail was called. The trick chain is already dropped when this runs - hang the wipeout on it.\")",
		"signal bailed",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Trick Done\")",
		"## @ace_category(\"Skateboard 3D\")",
		"## @ace_description(\"Fires each time a trick is added to the chain, with the trick's name and what it scored after the multiplier.\")",
		"signal trick_done(trick: String, points: float)",
		"",
		"# The rail this board is riding, and the surface it last stood on. The surface is kept",
		"# because the lip test only has an answer the frame AFTER the board has left it.",
		"var _rail: Node3D = null",
		"var _last_surface: Vector3 = Vector3.UP",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Rolling\")",
		"## @ace_category(\"Skateboard 3D\")",
		"## @ace_description(\"True while the board is on the ground and actually moving.\")",
		"func is_rolling() -> bool:",
		"\treturn host != null and host.is_on_floor() and Vector3(host.velocity.x, 0.0, host.velocity.z).length() > 0.05",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Airborne\")",
		"## @ace_category(\"Skateboard 3D\")",
		"## @ace_description(\"True while the board is off the ground and not on a rail - the window every trick lives in.\")",
		"func is_airborne() -> bool:",
		"\treturn host != null and not host.is_on_floor() and not _grinding",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is In A Manual\")",
		"## @ace_category(\"Skateboard 3D\")",
		"## @ace_description(\"True while the board is riding on its back wheels.\")",
		"func is_in_a_manual() -> bool:",
		"\treturn _manual",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Losing Balance\")",
		"## @ace_category(\"Skateboard 3D\")",
		"## @ace_description(\"True while balance has drifted past the warning mark and has not been steered back. This is the row a HUD needle flashes on.\")",
		"func is_losing_balance() -> bool:",
		"\treturn _balancing and absf(_balance) >= balance_warn",
		"",
		"## @ace_expression",
		"## @ace_name(\"Balance\")",
		"## @ace_category(\"Skateboard 3D\")",
		"## @ace_description(\"Where balance sits, from -1 (fallen one way) through 0 (dead centre) to 1 (fallen the other). A needle reads this straight.\")",
		"func balance() -> float:",
		"\treturn _balance",
		"",
		"## @ace_expression",
		"## @ace_name(\"Chain Score\")",
		"## @ace_category(\"Skateboard 3D\")",
		"## @ace_description(\"What the chain running right now is worth. Banking it moves this into the total and resets it.\")",
		"func chain_score() -> float:",
		"\treturn _chain_score",
		"",
		"## @ace_expression",
		"## @ace_name(\"Multiplier\")",
		"## @ace_category(\"Skateboard 3D\")",
		"## @ace_description(\"What the next trick in the chain will be multiplied by. Starts at 1 and climbs by one per trick.\")",
		"func multiplier() -> int:",
		"\treturn _chain_multiplier",
		"",
		"## @ace_expression",
		"## @ace_name(\"Banked Score\")",
		"## @ace_category(\"Skateboard 3D\")",
		"## @ace_description(\"Everything banked so far this run. A dropped chain never reaches it.\")",
		"func banked_score() -> float:",
		"\treturn _banked_score",
		"",
		"## @ace_expression",
		"## @ace_name(\"Spin Turns\")",
		"## @ace_category(\"Skateboard 3D\")",
		"## @ace_description(\"How many whole turns the board has spun since it left the ground - what a 540 is counted with.\")",
		"func spin_turns() -> float:",
		"\treturn _spin_turns",
		"",
		"## @ace_expression",
		"## @ace_name(\"Surface Normal\")",
		"## @ace_category(\"Skateboard 3D\")",
		"## @ace_description(\"The way the surface under the board faces, or the way the last one faced while the board is in the air. This is what the landing is judged against.\")",
		"func surface_normal() -> Vector3:",
		"\tif host != null and host.is_on_floor():",
		"\t\treturn host.get_floor_normal()",
		"\treturn _last_surface",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Grinding\")",
		"## @ace_category(\"Grind 3D\")",
		"## @ace_description(\"True while the board is locked to a rail and riding it.\")",
		"func is_grinding() -> bool:",
		"\treturn _grinding",
		"",
		"## @ace_condition",
		"## @ace_name(\"Has Reached The End\")",
		"## @ace_category(\"Grind 3D\")",
		"## @ace_description(\"True when the ride has run off either end of the rail's curve. Pair it with Hop Off so the board leaves under its own momentum.\")",
		"func has_reached_the_end() -> bool:",
		"\tif not _grinding or _rail == null:",
		"\t\treturn false",
		"\tvar curve: Curve3D = _rail_curve()",
		"\tif curve == null:",
		"\t\treturn true",
		"\treturn _rail_offset <= 0.0 or _rail_offset >= curve.get_baked_length()",
		"",
		"# The rail's curve, or null when the remembered rail is gone, is not a Path3D, or carries",
		"# a curve too short to sample. Every grind row goes through this, so a rail deleted mid-ride",
		"# stops the grind instead of faulting.",
		"## @ace_hidden",
		"func _rail_curve() -> Curve3D:",
		"\tif _rail == null or not is_instance_valid(_rail) or not _rail is Path3D:",
		"\t\treturn null",
		"\tvar curve: Curve3D = (_rail as Path3D).curve",
		"\tif curve == null or curve.point_count < 2:",
		"\t\treturn null",
		"\treturn curve",
		"",
		"# The point on a rail nearest the host, in world space, plus the offset along the curve",
		"# that produced it. This closest-offset snap is the whole of what \"near a rail\" means.",
		"## @ace_hidden",
		"func _closest_on_rail(path: Node3D) -> Dictionary:",
		"\tif host == null or path == null or not is_instance_valid(path) or not path is Path3D:",
		"\t\treturn {}",
		"\tvar curve: Curve3D = (path as Path3D).curve",
		"\tif curve == null or curve.point_count < 2:",
		"\t\treturn {}",
		"\tvar offset: float = curve.get_closest_offset(path.to_local(host.global_position))",
		"\treturn {\"offset\": offset, \"point\": path.to_global(curve.sample_baked(offset))}",
		"",
		"# The board squared onto a surface: its up becomes the surface normal and it keeps facing",
		"# the way it was already pointing, flattened onto that surface.",
		"## @ace_hidden",
		"func _surface_basis(up: Vector3) -> Basis:",
		"\tvar squared: Vector3 = up.normalized() if not up.is_zero_approx() else Vector3.UP",
		"\tvar basis: Basis = host.global_transform.basis",
		"\tvar back: Vector3 = basis.z - squared * basis.z.dot(squared)",
		"\tif back.is_zero_approx():",
		"\t\tback = Vector3.BACK - squared * Vector3.BACK.dot(squared)",
		"\tif back.is_zero_approx():",
		"\t\treturn basis",
		"\tback = back.normalized()",
		"\treturn Basis(squared.cross(back).normalized(), squared, back)",
		"",
		"# Snap flat, with no easing - what a clean landing and a lip launch both do.",
		"## @ace_hidden",
		"func _square_up(up: Vector3) -> void:",
		"\tif host == null:",
		"\t\treturn",
		"\tvar xform: Transform3D = host.global_transform",
		"\txform.basis = _surface_basis(up).orthonormalized()",
		"\thost.global_transform = xform",
		"",
		"# Touching down: the board's up against the surface normal. Square enough and the board",
		"# snaps flat and the landing counts; anything crookeder is a bail. This is the ONE place a",
		"# landing is judged, so the tick's automatic touchdown and a hand-called Land The Trick can",
		"# never disagree.",
		"## @ace_hidden",
		"func _judge_landing() -> void:",
		"\tif host == null:",
		"\t\treturn",
		"\tvar up: Vector3 = surface_normal()",
		"\tvar off_by: float = rad_to_deg(host.global_transform.basis.y.angle_to(up))",
		"\t# You cannot bail a trick you never did. A board that touched down without a turn in the",
		"\t# air is simply rolling again, however steep the surface it landed on - which is what keeps",
		"\t# a beginner dropping into a bowl from wiping out on arrival.",
		"\tif is_zero_approx(_spin_turns) or off_by <= landing_tolerance_degrees:",
		"\t\t_square_up(up)",
		"\t\t_spin_turns = 0.0",
		"\t\tlanded_clean.emit()",
		"\telse:",
		"\t\tbail()"
	]))
	return block


## The pack's own tick: gravity and terminal velocity, rolling friction, the lip launch, the
## touchdown edge that judges a landing, the balance drift, and the move.
static func _tick() -> EventRow:
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var body: RawCodeRow = RawCodeRow.new()
	body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"if _grinding:",
		"\t# A grind owns the position outright, so gravity, friction and the touchdown edge all",
		"\t# stand down until Hop Off or a bail hands the board back.",
		"\t_was_on_floor = false",
		"else:",
		"\tvar on_floor: bool = host.is_on_floor()",
		"\tif on_floor:",
		"\t\t_last_surface = host.get_floor_normal()",
		"\t\tvar flat: Vector3 = Vector3(host.velocity.x, 0.0, host.velocity.z)",
		"\t\tflat = flat.move_toward(Vector3.ZERO, friction * delta)",
		"\t\thost.velocity = Vector3(flat.x, host.velocity.y, flat.z)",
		"\telse:",
		"\t\thost.velocity.y = maxf(host.velocity.y - gravity * delta, -max_fall_speed)",
		"\tif on_floor and not _was_on_floor:",
		"\t\t_judge_landing()",
		"\telif _was_on_floor and not on_floor:",
		"\t\t# Leaving a transition steeper than the lip angle is a launch, not a fall off a kerb:",
		"\t\t# the speed the ramp already built keeps carrying the board up, and it stays square",
		"\t\t# with the lip it left rather than snapping level.",
		"\t\tif rad_to_deg(_last_surface.angle_to(Vector3.UP)) >= lip_angle_degrees:",
		"\t\t\thost.velocity.y += lip_boost",
		"\t\t\t_square_up(_last_surface)",
		"\t\t\t_spin_turns = 0.0",
		"\t\t\tlaunched_off_the_lip.emit()",
		"\t_was_on_floor = on_floor",
		"if _balancing:",
		"\t# Balance never sits still: it leans further the way it is already going, which is what",
		"\t# makes a long manual a held breath rather than a free ride.",
		"\tvar lean: float = 1.0 if _balance >= 0.0 else -1.0",
		"\t_balance = clampf(_balance + lean * balance_drift * delta, -1.5, 1.5)",
		"\tif absf(_balance) >= 1.0:",
		"\t\tbail()",
		"if not _grinding:",
		"\thost.move_and_slide()"
	]))
	tick.actions.append(body)
	return tick


## The board itself: the momentum verbs.
static func _append_board_verbs(sheet: EventSheetResource) -> void:
	Lib.append_function(sheet, "push", "Push", "Skateboard 3D",
		"One kick: nudges the board toward its top speed along the way it is facing, and the board keeps it. Unlike a character controller's acceleration this is a one-shot gain, so pushing twice is faster than pushing once.",
		[["amount", "float"]],
		"\n".join(PackedStringArray([
			"if host == null:",
			"\treturn",
			"var forward: Vector3 = -host.global_transform.basis.z",
			"forward.y = 0.0",
			"if forward.is_zero_approx():",
			"\tforward = Vector3.FORWARD",
			"forward = forward.normalized()",
			"var flat: Vector3 = Vector3(host.velocity.x, 0.0, host.velocity.z)",
			"flat = flat.move_toward(forward * max_speed, amount)",
			"host.velocity = Vector3(flat.x, host.velocity.y, flat.z)"
		])),
		"Push toward [b]max speed[/b] by [b]{amount}[/b]")

	Lib.append_function(sheet, "roll_with_slope", "Roll With The Slope", "Skateboard 3D",
		"Projects gravity onto the surface the board is standing on, so a downhill gains speed and an uphill loses it. This one row is what makes ramps, bowls and quarterpipes work - call it every physics tick while on the floor.",
		[],
		"\n".join(PackedStringArray([
			"if host == null or not host.is_on_floor():",
			"\treturn",
			"var normal: Vector3 = host.get_floor_normal()",
			"if normal.is_zero_approx():",
			"\treturn",
			"var down_slope: Vector3 = Vector3.DOWN - normal * Vector3.DOWN.dot(normal)",
			"host.velocity += down_slope * gravity * slope_grip * get_physics_process_delta_time()"
		])),
		"Roll with the slope [i]gravity along the surface[/i]")

	Lib.append_function(sheet, "align_board_to_surface", "Align The Board To The Surface", "Skateboard 3D",
		"Swings the board flat onto whatever it is standing on, at the align speed, keeping the way it was facing. Off the ground it settles back level, so a drop lands on its wheels rather than on the shape of the last ramp.",
		[],
		"\n".join(PackedStringArray([
			"if host == null:",
			"\treturn",
			"var up: Vector3 = host.get_floor_normal() if host.is_on_floor() else Vector3.UP",
			"var xform: Transform3D = host.global_transform",
			"var weight: float = clampf(align_speed * get_physics_process_delta_time(), 0.0, 1.0)",
			"xform.basis = xform.basis.orthonormalized().slerp(_surface_basis(up).orthonormalized(), weight)",
			"host.global_transform = xform"
		])),
		"Align the board to the [b]surface[/b]")

	Lib.append_function(sheet, "ollie", "Ollie", "Skateboard 3D",
		"Pops the board off the ground at the given speed and starts a fresh spin count, then fires On Ollie. Whatever ground speed the board had, it keeps.",
		[["strength", "float"]],
		"\n".join(PackedStringArray([
			"if host == null:",
			"\treturn",
			"host.velocity.y = strength",
			"_spin_turns = 0.0",
			"_manual = false",
			"ollied.emit()"
		])),
		"[b]Ollie[/b] at [b]{strength}[/b]")

	Lib.append_function(sheet, "manual", "Manual", "Skateboard 3D",
		"Tips the board onto its back wheels and starts the balance meter drifting. Hold it with Steer The Balance; let it reach an edge and the board bails.",
		[],
		"\n".join(PackedStringArray([
			"_manual = true",
			"start_balancing(balance_drift)"
		])),
		"Ride a [b]manual[/b]")

	Lib.append_function(sheet, "stop_manual", "Stop The Manual", "Skateboard 3D",
		"Sets the board back down on all four wheels and stops the balance meter. Nothing is scored and nothing is lost - use Bank Chain first if the manual was worth points.",
		[],
		"\n".join(PackedStringArray([
			"_manual = false",
			"_balancing = false",
			"_balance = 0.0"
		])),
		"[b]Stop[/b] the manual")

	Lib.append_function(sheet, "brake", "Brake", "Skateboard 3D",
		"Drags speed off the board toward a standstill, by the given amount this call. Foot down.",
		[["amount", "float"]],
		"\n".join(PackedStringArray([
			"if host == null:",
			"\treturn",
			"var flat: Vector3 = Vector3(host.velocity.x, 0.0, host.velocity.z)",
			"flat = flat.move_toward(Vector3.ZERO, amount)",
			"host.velocity = Vector3(flat.x, host.velocity.y, flat.z)"
		])),
		"[b]Brake[/b] by [b]{amount}[/b]")

	Lib.append_function(sheet, "reverse", "Reverse", "Skateboard 3D",
		"Turns the board around and rolls the way it came, keeping the speed it had. A fakie out of a bowl is this row.",
		[],
		"\n".join(PackedStringArray([
			"if host == null:",
			"\treturn",
			"host.velocity = Vector3(-host.velocity.x, host.velocity.y, -host.velocity.z)",
			"host.rotate_y(PI)"
		])),
		"[b]Reverse[/b] the roll")


## Tricks: the air rows and the landing they are judged by.
static func _append_trick_verbs(sheet: EventSheetResource) -> void:
	Lib.append_function(sheet, "spin_trick", "Spin Trick", "Skateboard 3D",
		"Turns the board about its own up through the air at the given turns per second and counts the turns as it goes - the shove-it half of a trick. Nothing happens on the ground.",
		[["turns", "float"]],
		"\n".join(PackedStringArray([
			"if host == null or host.is_on_floor() or _grinding:",
			"\treturn",
			"var step: float = turns * TAU * get_physics_process_delta_time()",
			"host.rotate_object_local(Vector3.UP, step)",
			"_spin_turns += absf(step) / TAU"
		])),
		"[b]Spin[/b] [b]{turns}[/b] turn per second")

	Lib.append_function(sheet, "flip_trick", "Flip Trick", "Skateboard 3D",
		"Rolls the board about its own length through the air at the given turns per second - the kickflip half of a trick. Nothing happens on the ground.",
		[["turns", "float"]],
		"\n".join(PackedStringArray([
			"if host == null or host.is_on_floor() or _grinding:",
			"\treturn",
			"var step: float = turns * TAU * get_physics_process_delta_time()",
			"host.rotate_object_local(Vector3.BACK, step)",
			"_spin_turns += absf(step) / TAU"
		])),
		"[b]Flip[/b] [b]{turns}[/b] turn per second")

	Lib.append_function(sheet, "land_trick", "Land The Trick", "Skateboard 3D",
		"Judges the landing now instead of waiting for the board to touch down: the board's up within the tolerance of the surface normal snaps it flat and fires On Landed Clean, crookeder than that bails. The tick calls this for you on every touchdown, so you only need it to end a grind or a scripted landing.",
		[],
		"_judge_landing()",
		"[b]Land[/b] the trick")

	Lib.append_function(sheet, "bail", "Bail", "Skateboard 3D",
		"Wipes out: the manual, the grind and the balance meter all stop, the trick chain is dropped, and On Bailed fires. Hang the ragdoll, the stumble animation, or the checkpoint respawn on that trigger - this pack deliberately does not own the wipeout.",
		[],
		"\n".join(PackedStringArray([
			"_manual = false",
			"_grinding = false",
			"_zipline = false",
			"_rail = null",
			"_balancing = false",
			"_balance = 0.0",
			"_spin_turns = 0.0",
			"drop_chain()",
			"bailed.emit()"
		])),
		"[b]Bail[/b]")


## The chain and the balance meter - the scoring half, useful anywhere a run of moves should be
## worth more than the moves apart.
static func _append_chain_verbs(sheet: EventSheetResource) -> void:
	Lib.append_function(sheet, "add_to_chain", "Add To Chain", "Skateboard 3D",
		"Scores a trick into the chain running right now: the points are multiplied by the current multiplier, then the multiplier climbs by one. Fires On Trick Done with the name and what it actually scored. Nothing is safe until the chain is banked.",
		[["trick", "String"], ["points", "float"]],
		"\n".join(PackedStringArray([
			"var scored: float = points * float(_chain_multiplier)",
			"_chain_score += scored",
			"_chain_multiplier += 1",
			"trick_done.emit(trick, scored)"
		])),
		"Add trick [b]{trick}[/b] to the chain for [b]{points}[/b]")

	Lib.append_function(sheet, "bank_chain", "Bank Chain", "Skateboard 3D",
		"Cashes the chain in: everything it is worth moves into the banked total and the multiplier goes back to one. This is the clean landing's reward.",
		[],
		"\n".join(PackedStringArray([
			"_banked_score += _chain_score",
			"_chain_score = 0.0",
			"_chain_multiplier = 1"
		])),
		"[b]Bank[/b] the chain")

	Lib.append_function(sheet, "drop_chain", "Drop Chain", "Skateboard 3D",
		"Throws the running chain away and puts the multiplier back to one. The banked total is untouched - this is what a bail costs you.",
		[],
		"\n".join(PackedStringArray([
			"_chain_score = 0.0",
			"_chain_multiplier = 1"
		])),
		"[b]Drop[/b] the chain")

	Lib.append_function(sheet, "start_balancing", "Start Balancing", "Skateboard 3D",
		"Puts the balance meter at dead centre and starts it drifting at the given speed per second. Steer it back with Steer The Balance; let it reach either edge and the board bails.",
		[["drift", "float"]],
		"\n".join(PackedStringArray([
			"balance_drift = drift",
			"_balance = 0.0",
			"_balancing = true"
		])),
		"[b]Start balancing[/b], drifting at [b]{drift}[/b]")

	Lib.append_function(sheet, "steer_balance", "Steer The Balance", "Skateboard 3D",
		"Pushes balance back toward the middle by the steer strength times this amount. Feed it the left/right axis: -1 leans one way, 1 the other, 0 lets the drift have it.",
		[["amount", "float"]],
		"\n".join(PackedStringArray([
			"if not _balancing:",
			"\treturn",
			"_balance = clampf(_balance - amount * balance_steer * get_physics_process_delta_time(), -1.5, 1.5)"
		])),
		"[b]Steer[/b] the balance by [b]{amount}[/b]")


## The rail words, on Path3D. The same snap-to-a-curve-and-ride shape as the 2D pack's, so a
## traversal pack adopts these rows by reference instead of minting a second spelling.
static func _append_grind_verbs(sheet: EventSheetResource) -> void:
	var near: EventFunction = Lib.exposed_function("is_near_rail", "Is Near Rail", "Grind 3D",
		"True when the board is within the given distance of the nearest point on the rail's curve. This is the whole of what \"near a rail\" means - the closest offset on the curve, and how far off it you are.",
		[["rail", "Node3D"], ["distance", "float"]],
		"\n".join(PackedStringArray([
			"var found: Dictionary = _closest_on_rail(rail)",
			"if found.is_empty():",
			"\treturn false",
			"return host.global_position.distance_to(found[\"point\"]) < distance"
		])))
	near.return_type = TYPE_BOOL
	near.display_template = "Is near rail [i]{rail}[/i] within [b]{distance}[/b]"
	sheet.functions.append(near)

	Lib.append_function(sheet, "start_grinding", "Start Grinding", "Grind 3D",
		"Locks the board onto the rail at the nearest point on its curve and starts riding, in whichever direction the board was already travelling. The balance meter starts with it, so a long rail is a held breath.",
		[["rail", "Node3D"]],
		"\n".join(PackedStringArray([
			"var found: Dictionary = _closest_on_rail(rail)",
			"if found.is_empty():",
			"\treturn",
			"var curve: Curve3D = (rail as Path3D).curve",
			"var offset: float = float(found[\"offset\"])",
			"var ahead: Vector3 = rail.to_global(curve.sample_baked(minf(offset + 0.2, curve.get_baked_length())))",
			"_rail = rail",
			"_rail_offset = offset",
			"_grind_direction = 1.0 if host.velocity.dot(ahead - found[\"point\"]) >= 0.0 else -1.0",
			"_grinding = true",
			"_zipline = false",
			"host.global_position = found[\"point\"]",
			"start_balancing(balance_drift)"
		])),
		"[b]Start grinding[/b] [i]{rail}[/i]")

	Lib.append_function(sheet, "grind_along_rail", "Grind Along Rail", "Grind 3D",
		"Rides one tick further along the rail and puts the board on the curve, facing the way the rail runs. Keep Momentum rides at whatever speed the board arrived with instead of the given speed - a fast approach is a fast grind.",
		[["speed", "float"], ["keep_momentum", "bool"]],
		"\n".join(PackedStringArray([
			"if host == null or not _grinding:",
			"\treturn",
			"var curve: Curve3D = _rail_curve()",
			"if curve == null:",
			"\thop_off(0.0)",
			"\treturn",
			"var travel: float = speed",
			"if keep_momentum:",
			"\ttravel = maxf(host.velocity.length(), 0.1)",
			"if _zipline:",
			"\ttravel = _zip_speed",
			"var length: float = curve.get_baked_length()",
			"_rail_offset = clampf(_rail_offset + travel * _grind_direction * get_physics_process_delta_time(), 0.0, length)",
			"var here: Vector3 = _rail.to_global(curve.sample_baked(_rail_offset))",
			"var ahead: Vector3 = _rail.to_global(curve.sample_baked(clampf(_rail_offset + 0.2 * _grind_direction, 0.0, length)))",
			"var along: Vector3 = ahead - here",
			"if not along.is_zero_approx():",
			"\thost.velocity = along.normalized() * travel",
			"\thost.look_at(here + along.normalized(), Vector3.UP)",
			"\tif _zipline:",
			"\t\t# A zipline is a rail you do not push along: the line's own slope feeds it, so the",
			"\t\t# steeper the run the faster you go.",
			"\t\t_zip_speed = minf(_zip_speed + gravity * absf(along.normalized().y) * get_physics_process_delta_time(), max_fall_speed)",
			"host.global_position = here"
		])),
		"[b]Grind[/b] along the rail at [b]{speed}[/b]")

	Lib.append_function(sheet, "hop_off", "Hop Off", "Grind 3D",
		"Lets the rail go and gives the board an upward kick, keeping whatever speed the grind had built along the line. The balance meter stops with it.",
		[["hop", "float"]],
		"\n".join(PackedStringArray([
			"_grinding = false",
			"_zipline = false",
			"_rail = null",
			"_balancing = false",
			"_balance = 0.0",
			"if host == null:",
			"\treturn",
			"host.velocity.y += hop",
			"_was_on_floor = false"
		])),
		"[b]Hop off[/b] the rail at [b]{hop}[/b]")

	Lib.append_function(sheet, "ride_zipline", "Ride Zipline", "Grind 3D",
		"The same lock-on as a grind, but the line's slope drives the speed instead of a knob: a steep zipline accelerates, a level one coasts. Hop Off ends it exactly the same way.",
		[["rail", "Node3D"]],
		"\n".join(PackedStringArray([
			"start_grinding(rail)",
			"if not _grinding:",
			"\treturn",
			"_zipline = true",
			"_zip_speed = maxf(host.velocity.length(), 1.0)"
		])),
		"[b]Ride[/b] the zipline [i]{rail}[/i]")
