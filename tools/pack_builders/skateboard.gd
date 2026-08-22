# Pack builder - skateboard (one pack per file; run via tools/build_sample_behaviors.gd).
#
# Skating is a DIFFERENT movement model from running, which is why it is its own pack rather
# than a corner of the platformer one. A platformer accelerates toward a top speed every tick
# and stops the moment you let go; a board keeps whatever it has, gains from the slope it is
# on, and only loses to friction. Everything else in the pack hangs off that: a push is a
# one-shot nudge toward the top speed, a halfpipe works because gravity is projected along the
# floor normal, tricks are rotation in the air with a landing test, and the score is a chain
# that multiplies while you never touch down.
#
# The rail words (Is Near Rail / Start Grinding / Grind Along Rail / Has Reached The End /
# Hop Off / Ride Zipline) live here under their own "Grind" category. They are a general
# snap-to-a-curve-and-ride shape - a rail, a zipline, a monorail - so a traversal pack adopts
# these rows by reference rather than minting a second spelling of them.
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "SkateboardMovement"
	sheet.class_description = "Momentum movement for a CharacterBody2D on a board: one Push nudges you toward the top speed and you keep it, Roll With The Slope projects gravity along the floor so halfpipes and ramps work, Ollie leaves the ground, Spin and Flip turn in the air, and touching down either lands clean or bails depending on how square the board is with the floor. Grinds snap to any Path2D rail and ride it, and a trick chain multiplies everything you land without touching down."
	sheet.addon_category = "Skateboard"
	sheet.ace_expose_all_mode = "node"
	sheet.addon_tags = PackedStringArray(["movement", "skateboard", "momentum", "grind"])
	sheet.variables = {
		# ── Tuning (Inspector) ───────────────────────────────────────────────────────
		"push_speed": {"type": "float", "default": 40.0, "exported": true,
			"attributes": {"tooltip": "How much speed one push adds toward the top speed (px/s). A board keeps it - there is no per-tick acceleration here."}},
		"max_speed": {"type": "float", "default": 600.0, "exported": true,
			"attributes": {"tooltip": "The fastest a push will take you (px/s). A slope can still carry you past it."}},
		"ollie_speed": {"type": "float", "default": 420.0, "exported": true,
			"attributes": {"tooltip": "Upward speed an ollie gives you (px/s)."}},
		"gravity": {"type": "float", "default": 980.0, "exported": true,
			"attributes": {"tooltip": "Downward acceleration (px/s²). Roll With The Slope projects this along the floor."}},
		"max_fall_speed": {"type": "float", "default": 1200.0, "exported": true,
			"attributes": {"tooltip": "Terminal velocity - gravity never pulls you down faster than this."}},
		"friction": {"type": "float", "default": 60.0, "exported": true,
			"attributes": {"tooltip": "Rolling friction on the ground (px/s²). Low, because a board coasts."}},
		"slope_grip": {"type": "float", "default": 1.0, "exported": true,
			"attributes": {"tooltip": "How much of gravity the slope hands you. 1 is a real ramp, above 1 exaggerates it, 0 makes hills flat.", "range": {"min": "0", "max": "3", "step": "0.05"}}},
		"align_speed": {"type": "float", "default": 12.0, "exported": true,
			"attributes": {"tooltip": "How quickly the board settles flat onto the slope it is rolling on, in radians per second. It only does this when no trick is turning, so a spin is never fought."}},
		"trick_spin_rate": {"type": "float", "default": 1.0, "exported": true,
			"attributes": {"tooltip": "Default turns per second a Spin or Flip trick turns at."}},
		"landing_tolerance_degrees": {"type": "float", "default": 25.0, "exported": true,
			"attributes": {"tooltip": "How far off square with the floor the board may be and still land clean. Wider is friendlier.", "range": {"min": "1", "max": "90", "step": "1"}}},
		"grind_speed": {"type": "float", "default": 320.0, "exported": true,
			"attributes": {"tooltip": "Default speed along a rail (px/s) when a grind is not keeping your momentum."}},
		"rail_snap_distance": {"type": "float", "default": 12.0, "exported": true,
			"attributes": {"tooltip": "How close to the rail's line the board has to be for Is Near Rail to say yes (px)."}},
		"hop_off_speed": {"type": "float", "default": 260.0, "exported": true,
			"attributes": {"tooltip": "Upward speed a hop off a rail gives you (px/s)."}},
		"balance_drift": {"type": "float", "default": 0.8, "exported": true,
			"attributes": {"tooltip": "How fast balance slides toward the edge per second while you are balancing. 0 is a free ride."}},
		"balance_steer": {"type": "float", "default": 1.6, "exported": true,
			"attributes": {"tooltip": "How hard one full steer pushes balance back toward the middle, per second."}},
		"balance_warn": {"type": "float", "default": 0.6, "exported": true,
			"attributes": {"tooltip": "How far out balance has to be before Is Losing Balance says yes. 1 is the bail.", "range": {"min": "0", "max": "1", "step": "0.05"}}},
		# ── Internal state (not exported) ────────────────────────────────────────────
		"_manual": {"type": "bool", "default": false, "exported": false},
		"_grinding": {"type": "bool", "default": false, "exported": false},
		"_zipline": {"type": "bool", "default": false, "exported": false},
		"_zip_speed": {"type": "float", "default": 0.0, "exported": false},
		"_rail_offset": {"type": "float", "default": 0.0, "exported": false},
		"_grind_direction": {"type": "float", "default": 1.0, "exported": false},
		"_balancing": {"type": "bool", "default": false, "exported": false},
		"_balance": {"type": "float", "default": 0.0, "exported": false},
		"_chain_score": {"type": "float", "default": 0.0, "exported": false},
		"_chain_multiplier": {"type": "int", "default": 1, "exported": false},
		"_banked_score": {"type": "float", "default": 0.0, "exported": false},
		"_spin_turns": {"type": "float", "default": 0.0, "exported": false},
		"_was_on_floor": {"type": "bool", "default": false, "exported": false}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "Skateboard movement: attach under a CharacterBody2D. Push to gain speed and keep it, Roll With The Slope every tick so ramps and halfpipes work, Ollie to leave the ground, Spin or Flip in the air, and let the landing decide between On Landed Clean and On Bailed. Grinds snap to any Path2D."
	sheet.events.append(about)

	sheet.events.append(_declarations())
	sheet.events.append(_tick())
	_append_board_verbs(sheet)
	_append_trick_verbs(sheet)
	_append_chain_verbs(sheet)
	_append_grind_verbs(sheet)

	Lib.feature_verbs(sheet, ["push", "ollie", "roll_with_slope"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/skateboard/skateboard_behavior")


## Triggers, conditions, expressions and the private kernels, as one annotated class-level block.
static func _declarations() -> RawCodeRow:
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Ollie\")",
		"## @ace_category(\"Skateboard\")",
		"## @ace_description(\"Fires the moment an ollie leaves the ground.\")",
		"signal ollied",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Landed Clean\")",
		"## @ace_category(\"Skateboard\")",
		"## @ace_description(\"Fires on touching down with the board within the landing tolerance of the floor. The board is squared up with the floor before this runs.\")",
		"signal landed_clean",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Bailed\")",
		"## @ace_category(\"Skateboard\")",
		"## @ace_description(\"Fires when a landing came in too crooked, balance ran out, or Bail was called. The trick chain is already dropped when this runs.\")",
		"signal bailed",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Trick Done\")",
		"## @ace_category(\"Skateboard\")",
		"## @ace_description(\"Fires each time a trick is added to the chain, with the trick's name and what it scored after the multiplier.\")",
		"signal trick_done(trick: String, points: float)",
		"",
		"# The rail this board is riding. Start Grinding remembers it so the riding rows do not",
		"# have to name it again, and Hop Off / a bail forget it.",
		"var _rail: Node2D = null",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Rolling\")",
		"## @ace_category(\"Skateboard\")",
		"## @ace_description(\"True while the board is on the ground and actually moving.\")",
		"func is_rolling() -> bool:",
		"\treturn host != null and host.is_on_floor() and absf(host.velocity.x) > 1.0",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Airborne\")",
		"## @ace_category(\"Skateboard\")",
		"## @ace_description(\"True while the board is off the ground and not on a rail - the window every trick lives in.\")",
		"func is_airborne() -> bool:",
		"\treturn host != null and not host.is_on_floor() and not _grinding",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is In A Manual\")",
		"## @ace_category(\"Skateboard\")",
		"## @ace_description(\"True while the board is riding on its back wheels.\")",
		"func is_in_a_manual() -> bool:",
		"\treturn _manual",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Losing Balance\")",
		"## @ace_category(\"Skateboard\")",
		"## @ace_description(\"True while balance has drifted past the warning mark and has not been steered back. This is the row a HUD needle flashes on.\")",
		"func is_losing_balance() -> bool:",
		"\treturn _balancing and absf(_balance) >= balance_warn",
		"",
		"## @ace_expression",
		"## @ace_name(\"Balance\")",
		"## @ace_category(\"Skateboard\")",
		"## @ace_description(\"Where balance sits, from -1 (fallen one way) through 0 (dead centre) to 1 (fallen the other). A needle reads this straight.\")",
		"func balance() -> float:",
		"\treturn _balance",
		"",
		"## @ace_expression",
		"## @ace_name(\"Chain Score\")",
		"## @ace_category(\"Skateboard\")",
		"## @ace_description(\"What the chain running right now is worth. Banking it moves this into the total and resets it.\")",
		"func chain_score() -> float:",
		"\treturn _chain_score",
		"",
		"## @ace_expression",
		"## @ace_name(\"Multiplier\")",
		"## @ace_category(\"Skateboard\")",
		"## @ace_description(\"What the next trick in the chain will be multiplied by. Starts at 1 and climbs by one per trick.\")",
		"func multiplier() -> int:",
		"\treturn _chain_multiplier",
		"",
		"## @ace_expression",
		"## @ace_name(\"Banked Score\")",
		"## @ace_category(\"Skateboard\")",
		"## @ace_description(\"Everything banked so far this run. A dropped chain never reaches it.\")",
		"func banked_score() -> float:",
		"\treturn _banked_score",
		"",
		"## @ace_expression",
		"## @ace_name(\"Spin Turns\")",
		"## @ace_category(\"Skateboard\")",
		"## @ace_description(\"How many whole turns the board has spun since it left the ground - what a 540 is counted with.\")",
		"func spin_turns() -> float:",
		"\treturn _spin_turns",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Grinding\")",
		"## @ace_category(\"Grind\")",
		"## @ace_description(\"True while the board is locked to a rail and riding it.\")",
		"func is_grinding() -> bool:",
		"\treturn _grinding",
		"",
		"## @ace_condition",
		"## @ace_name(\"Has Reached The End\")",
		"## @ace_category(\"Grind\")",
		"## @ace_description(\"True when the ride has run off either end of the rail's curve. Pair it with Hop Off so the board leaves under its own momentum.\")",
		"func has_reached_the_end() -> bool:",
		"\tif not _grinding or _rail == null:",
		"\t\treturn false",
		"\tvar curve: Curve2D = _rail_curve()",
		"\tif curve == null:",
		"\t\treturn true",
		"\treturn _rail_offset <= 0.0 or _rail_offset >= curve.get_baked_length()",
		"",
		"# The rail's curve, or null when the remembered rail is gone, is not a Path2D, or carries",
		"# a curve too short to sample. Every grind row goes through this, so a rail deleted mid-ride",
		"# stops the grind instead of faulting.",
		"## @ace_hidden",
		"func _rail_curve() -> Curve2D:",
		"\tif _rail == null or not is_instance_valid(_rail) or not _rail is Path2D:",
		"\t\treturn null",
		"\tvar curve: Curve2D = (_rail as Path2D).curve",
		"\tif curve == null or curve.point_count < 2:",
		"\t\treturn null",
		"\treturn curve",
		"",
		"# The point on a rail nearest the host, in world space, plus the offset along the curve",
		"# that produced it. This closest-offset snap is the whole of what \"near a rail\" means.",
		"## @ace_hidden",
		"func _closest_on_rail(path: Node2D) -> Dictionary:",
		"\tif host == null or path == null or not is_instance_valid(path) or not path is Path2D:",
		"\t\treturn {}",
		"\tvar curve: Curve2D = (path as Path2D).curve",
		"\tif curve == null or curve.point_count < 2:",
		"\t\treturn {}",
		"\tvar offset: float = curve.get_closest_offset(path.to_local(host.global_position))",
		"\treturn {\"offset\": offset, \"point\": path.to_global(curve.sample_baked(offset))}",
		"",
		"# The angle the board sits at when it is square with the floor it is standing on.",
		"## @ace_hidden",
		"func _floor_angle() -> float:",
		"\tif host == null:",
		"\t\treturn 0.0",
		"\tvar normal: Vector2 = host.get_floor_normal()",
		"\tif normal.is_zero_approx():",
		"\t\treturn 0.0",
		"\treturn normal.angle() + PI / 2.0",
		"",
		"# Touching down: square enough with the floor and the board snaps flat and the landing",
		"# counts; anything crookeder is a bail. This is the ONE place a landing is judged, so the",
		"# tick's automatic touchdown and a hand-called Land The Trick can never disagree.",
		"## @ace_hidden",
		"func _judge_landing() -> void:",
		"\tif host == null:",
		"\t\treturn",
		"\tvar square: float = _floor_angle()",
		"\tvar off_by: float = absf(rad_to_deg(angle_difference(host.rotation, square)))",
		"\t# You cannot bail a trick you never did. A board that touched down without a turn in the",
		"\t# air is simply rolling again, however steep the slope it landed on - which is what keeps a",
		"\t# beginner rolling down a bank from wiping out on arrival.",
		"\tif is_zero_approx(_spin_turns) or off_by <= landing_tolerance_degrees:",
		"\t\thost.rotation = square",
		"\t\t_spin_turns = 0.0",
		"\t\tlanded_clean.emit()",
		"\telse:",
		"\t\tbail()"
	]))
	return block


## The pack's own tick: gravity and terminal velocity, rolling friction, the touchdown edge that
## judges a landing, the balance drift, and the move. Everything a sheet says (Push, Ollie, Roll
## With The Slope, the tricks) writes velocity before this runs it.
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
		"\t\thost.velocity.x = move_toward(host.velocity.x, 0.0, friction * delta)",
		"\telse:",
		"\t\thost.velocity.y = minf(host.velocity.y + gravity * delta, max_fall_speed)",
		"\tif on_floor and not _was_on_floor:",
		"\t\t_judge_landing()",
		"\tif on_floor and is_zero_approx(_spin_turns):",
		"\t\t# Rolling settles the board flat onto whatever it is on, which is what makes leaving a",
		"\t\t# ramp leave it at the ramp's angle. Never while a trick is turning - the trick owns the",
		"\t\t# rotation until it is landed.",
		"\t\thost.rotation = rotate_toward(host.rotation, _floor_angle(), align_speed * delta)",
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
	Lib.append_function(sheet, "push", "Push", "Skateboard",
		"One kick: nudges the board toward its top speed in the direction it is already going, and the board keeps it. Unlike a platformer's acceleration this is a one-shot gain, so pushing twice is faster than pushing once and holding nothing is still fast.",
		[["amount", "float"]],
		"\n".join(PackedStringArray([
			"if host == null:",
			"\treturn",
			"var facing: float = signf(host.velocity.x)",
			"if is_zero_approx(facing):",
			"\tfacing = 1.0",
			"host.velocity.x = move_toward(host.velocity.x, max_speed * facing, amount)"
		])),
		"Push toward [b]max speed[/b] by [b]{amount}[/b]")

	Lib.append_function(sheet, "roll_with_slope", "Roll With The Slope", "Skateboard",
		"Projects gravity along the floor the board is standing on, so a downhill gains speed and an uphill loses it. This one row is what makes ramps, bowls and halfpipes work - call it every physics tick while on the floor.",
		[],
		"\n".join(PackedStringArray([
			"if host == null or not host.is_on_floor():",
			"\treturn",
			"host.velocity.x += host.get_floor_normal().x * gravity * slope_grip * get_physics_process_delta_time()"
		])),
		"Roll with the slope [i]gravity along the floor[/i]")

	Lib.append_function(sheet, "ollie", "Ollie", "Skateboard",
		"Pops the board off the ground at the given speed and starts a fresh spin count, then fires On Ollie. Whatever horizontal speed the board had, it keeps.",
		[["strength", "float"]],
		"\n".join(PackedStringArray([
			"if host == null:",
			"\treturn",
			"host.velocity.y = -strength",
			"_spin_turns = 0.0",
			"_manual = false",
			"ollied.emit()"
		])),
		"[b]Ollie[/b] at [b]{strength}[/b]")

	Lib.append_function(sheet, "manual", "Manual", "Skateboard",
		"Tips the board onto its back wheels and starts the balance meter drifting. Hold it with Steer The Balance; let it reach an edge and the board bails.",
		[],
		"\n".join(PackedStringArray([
			"_manual = true",
			"start_balancing(balance_drift)"
		])),
		"Ride a [b]manual[/b]")

	Lib.append_function(sheet, "stop_manual", "Stop The Manual", "Skateboard",
		"Sets the board back down on all four wheels and stops the balance meter. Nothing is scored and nothing is lost - use Bank The Chain first if the manual was worth points.",
		[],
		"\n".join(PackedStringArray([
			"_manual = false",
			"_balancing = false",
			"_balance = 0.0"
		])),
		"[b]Stop[/b] the manual")

	Lib.append_function(sheet, "brake", "Brake", "Skateboard",
		"Drags speed off the board toward a standstill, by the given amount this call. Foot down.",
		[["amount", "float"]],
		"\n".join(PackedStringArray([
			"if host == null:",
			"\treturn",
			"host.velocity.x = move_toward(host.velocity.x, 0.0, amount)"
		])),
		"[b]Brake[/b] by [b]{amount}[/b]")

	Lib.append_function(sheet, "reverse", "Reverse", "Skateboard",
		"Turns the board around and rolls the way it came, keeping the speed it had. A fakie out of a bowl is this row.",
		[],
		"\n".join(PackedStringArray([
			"if host == null:",
			"\treturn",
			"host.velocity.x = -host.velocity.x"
		])),
		"[b]Reverse[/b] the roll")


## Tricks: the air rows and the landing they are judged by.
static func _append_trick_verbs(sheet: EventSheetResource) -> void:
	Lib.append_function(sheet, "spin_trick", "Spin Trick", "Skateboard",
		"Turns the board through the air at the given turns per second and counts the turns as it goes. Nothing happens on the ground - a spin is an air row.",
		[["turns", "float"]],
		"\n".join(PackedStringArray([
			"if host == null or host.is_on_floor() or _grinding:",
			"\treturn",
			"var step: float = turns * TAU * get_physics_process_delta_time()",
			"host.rotation += step",
			"_spin_turns += absf(step) / TAU"
		])),
		"[b]Spin[/b] [b]{turns}[/b] turn per second")

	Lib.append_function(sheet, "flip_trick", "Flip Trick", "Skateboard",
		"The same turn the other way, so a sheet can tell a spin and a flip apart on the canvas and in the chain. Nothing happens on the ground.",
		[["turns", "float"]],
		"\n".join(PackedStringArray([
			"if host == null or host.is_on_floor() or _grinding:",
			"\treturn",
			"var step: float = turns * TAU * get_physics_process_delta_time()",
			"host.rotation -= step",
			"_spin_turns += absf(step) / TAU"
		])),
		"[b]Flip[/b] [b]{turns}[/b] turn per second")

	Lib.append_function(sheet, "land_trick", "Land The Trick", "Skateboard",
		"Judges the landing now instead of waiting for the board to touch down: square enough with the floor and it snaps flat and fires On Landed Clean, crookeder than the tolerance and it bails. The tick calls this for you on every touchdown, so you only need it to end a grind or a scripted landing.",
		[],
		"_judge_landing()",
		"[b]Land[/b] the trick")

	Lib.append_function(sheet, "bail", "Bail", "Skateboard",
		"Wipes out: the manual, the grind and the balance meter all stop, the trick chain is dropped, and On Bailed fires. This is where a ragdoll, a stumble animation, or a checkpoint respawn hangs.",
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
## worth more than the moves apart (a fighter's combo counts the same way).
static func _append_chain_verbs(sheet: EventSheetResource) -> void:
	Lib.append_function(sheet, "add_to_chain", "Add To Chain", "Skateboard",
		"Scores a trick into the chain running right now: the points are multiplied by the current multiplier, then the multiplier climbs by one. Fires On Trick Done with the name and what it actually scored. Nothing is safe until the chain is banked.",
		[["trick", "String"], ["points", "float"]],
		"\n".join(PackedStringArray([
			"var scored: float = points * float(_chain_multiplier)",
			"_chain_score += scored",
			"_chain_multiplier += 1",
			"trick_done.emit(trick, scored)"
		])),
		"Add trick [b]{trick}[/b] to the chain for [b]{points}[/b]")

	Lib.append_function(sheet, "bank_chain", "Bank Chain", "Skateboard",
		"Cashes the chain in: everything it is worth moves into the banked total and the multiplier goes back to one. This is the clean landing's reward.",
		[],
		"\n".join(PackedStringArray([
			"_banked_score += _chain_score",
			"_chain_score = 0.0",
			"_chain_multiplier = 1"
		])),
		"[b]Bank[/b] the chain")

	Lib.append_function(sheet, "drop_chain", "Drop Chain", "Skateboard",
		"Throws the running chain away and puts the multiplier back to one. The banked total is untouched - this is what a bail costs you.",
		[],
		"\n".join(PackedStringArray([
			"_chain_score = 0.0",
			"_chain_multiplier = 1"
		])),
		"[b]Drop[/b] the chain")

	Lib.append_function(sheet, "start_balancing", "Start Balancing", "Skateboard",
		"Puts the balance meter at dead centre and starts it drifting at the given speed per second. Steer it back with Steer The Balance; let it reach either edge and the board bails.",
		[["drift", "float"]],
		"\n".join(PackedStringArray([
			"balance_drift = drift",
			"_balance = 0.0",
			"_balancing = true"
		])),
		"[b]Start balancing[/b], drifting at [b]{drift}[/b]")

	Lib.append_function(sheet, "steer_balance", "Steer The Balance", "Skateboard",
		"Pushes balance back toward the middle by the steer strength times this amount. Feed it the left/right axis: -1 leans one way, 1 the other, 0 lets the drift have it.",
		[["amount", "float"]],
		"\n".join(PackedStringArray([
			"if not _balancing:",
			"\treturn",
			"_balance = clampf(_balance - amount * balance_steer * get_physics_process_delta_time(), -1.5, 1.5)"
		])),
		"[b]Steer[/b] the balance by [b]{amount}[/b]")


## The rail words. A general snap-to-a-curve-and-ride shape, under their own Grind category so a
## traversal pack can adopt these rows by reference instead of minting a second spelling.
static func _append_grind_verbs(sheet: EventSheetResource) -> void:
	var near: EventFunction = Lib.exposed_function("is_near_rail", "Is Near Rail", "Grind",
		"True when the board is within the given distance of the nearest point on the rail's curve. This is the whole of what \"near a rail\" means - the closest offset on the curve, and how far off it you are.",
		[["rail", "Node2D"], ["distance", "float"]],
		"\n".join(PackedStringArray([
			"var found: Dictionary = _closest_on_rail(rail)",
			"if found.is_empty():",
			"\treturn false",
			"return host.global_position.distance_to(found[\"point\"]) < distance"
		])))
	near.return_type = TYPE_BOOL
	near.display_template = "Is near rail [i]{rail}[/i] within [b]{distance}[/b] px"
	sheet.functions.append(near)

	Lib.append_function(sheet, "start_grinding", "Start Grinding", "Grind",
		"Locks the board onto the rail at the nearest point on its curve and starts riding, in whichever direction the board was already travelling. The balance meter starts with it, so a long rail is a held breath.",
		[["rail", "Node2D"]],
		"\n".join(PackedStringArray([
			"var found: Dictionary = _closest_on_rail(rail)",
			"if found.is_empty():",
			"\treturn",
			"_rail = rail",
			"_rail_offset = float(found[\"offset\"])",
			"_grind_direction = 1.0 if host.velocity.x >= 0.0 else -1.0",
			"_grinding = true",
			"_zipline = false",
			"host.global_position = found[\"point\"]",
			"start_balancing(balance_drift)"
		])),
		"[b]Start grinding[/b] [i]{rail}[/i]")

	Lib.append_function(sheet, "grind_along_rail", "Grind Along Rail", "Grind",
		"Rides one tick further along the rail and puts the board on the curve, facing the way the rail runs. Keep Momentum rides at whatever speed the board arrived with instead of the given speed - a fast approach is a fast grind.",
		[["speed", "float"], ["keep_momentum", "bool"]],
		"\n".join(PackedStringArray([
			"if host == null or not _grinding:",
			"\treturn",
			"var curve: Curve2D = _rail_curve()",
			"if curve == null:",
			"\thop_off(0.0)",
			"\treturn",
			"var travel: float = speed",
			"if keep_momentum:",
			"\ttravel = maxf(host.velocity.length(), 1.0)",
			"if _zipline:",
			"\ttravel = _zip_speed",
			"var length: float = curve.get_baked_length()",
			"_rail_offset = clampf(_rail_offset + travel * _grind_direction * get_physics_process_delta_time(), 0.0, length)",
			"var here: Vector2 = _rail.to_global(curve.sample_baked(_rail_offset))",
			"var ahead: Vector2 = _rail.to_global(curve.sample_baked(clampf(_rail_offset + 4.0 * _grind_direction, 0.0, length)))",
			"var along: Vector2 = ahead - here",
			"if not along.is_zero_approx():",
			"\thost.velocity = along.normalized() * travel",
			"\thost.rotation = along.angle()",
			"if _zipline:",
			"\t# A zipline is a rail you do not push along: the line's own slope feeds it, so the",
			"\t# steeper the run the faster you go.",
			"\t_zip_speed = minf(_zip_speed + gravity * absf(along.normalized().y) * get_physics_process_delta_time(), max_fall_speed)",
			"host.global_position = here"
		])),
		"[b]Grind[/b] along the rail at [b]{speed}[/b]")

	Lib.append_function(sheet, "hop_off", "Hop Off", "Grind",
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
			"host.velocity.y -= hop",
			"_was_on_floor = false"
		])),
		"[b]Hop off[/b] the rail at [b]{hop}[/b]")

	Lib.append_function(sheet, "ride_zipline", "Ride Zipline", "Grind",
		"The same lock-on as a grind, but the line's slope drives the speed instead of a knob: a steep zipline accelerates, a level one coasts. Hop Off ends it exactly the same way.",
		[["rail", "Node2D"]],
		"\n".join(PackedStringArray([
			"start_grinding(rail)",
			"if not _grinding:",
			"\treturn",
			"_zipline = true",
			"_zip_speed = maxf(host.velocity.length(), 20.0)"
		])),
		"[b]Ride[/b] the zipline [i]{rail}[/i]")
