# Pack builder - home_leash (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Home & Leash behavior: the guard-post pattern. The host Node2D remembers a home point, you ask
## whether it has wandered too far from it (in whichever distance metric your game measures in),
## and Return Home walks it back one step at a time, firing On Arrived Home when it lands.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "HomeLeashBehavior"
	sheet.class_description = "Keeps the host Node2D on a leash around a home point. Set Home Here plants the post, Is Beyond Home branches when the host has wandered too far (straight line, one axis, grid steps, or king moves), and Return Home walks it back and fires On Arrived Home. The guard, the shopkeeper, and the patrolling enemy that gives up the chase."
	sheet.addon_category = "Home & Leash"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"_has_home": {"type": "bool", "default": false, "exported": false},
		"_home": {"type": "Vector2", "default": Vector2.ZERO, "exported": false},
		"_returning": {"type": "bool", "default": false, "exported": false},
		"capture_on_ready": {"type": "bool", "default": true, "exported": true, "description": "Plant home where the host starts, so the leash works before you set one by hand."}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "Home & Leash behavior: one home point per host. Is Beyond Home branches on the leash length in five distance metrics; Return Home walks the host back one step per call and fires On Arrived Home."
	sheet.events.append(about)

	var arrived_signal: SignalRow = SignalRow.new()
	arrived_signal.signal_name = "arrived_home"
	arrived_signal.trigger = true
	arrived_signal.ace_name = "On Arrived Home"
	arrived_signal.ace_category = "Home & Leash"
	sheet.events.append(arrived_signal)

	# The lazy capture: a host that has never planted a home treats wherever it stands the first
	# time it is asked as home, so the leash can never measure against the world origin by accident.
	# Hidden from the picker - it is plumbing, not a verb.
	var helper: RawCodeRow = RawCodeRow.new()
	helper.code = "\n".join(PackedStringArray([
		"## @ace_hidden",
		"func _ensure_home() -> void:",
		"\tif _has_home or host == null:",
		"\t\treturn",
		"\t_home = host.global_position",
		"\t_has_home = true"
	]))
	sheet.events.append(helper)

	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var on_ready_body: RawCodeRow = RawCodeRow.new()
	on_ready_body.code = "\n".join(PackedStringArray([
		"if capture_on_ready:",
		"\t_ensure_home()"
	]))
	on_ready.actions.append(on_ready_body)
	sheet.events.append(on_ready)

	Lib.append_function(sheet, "set_home_here", "Set Home Here", "Home & Leash",
		"Plants home on the spot the host is standing on right now.",
		[], "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"_home = host.global_position",
		"_has_home = true"
	])), "Set home [b]here[/b]")

	Lib.append_function(sheet, "set_home_at", "Set Home At", "Home & Leash",
		"Plants home on any point in the world, without moving the host.",
		[["point", "Vector2"]], "\n".join(PackedStringArray([
		"_home = point",
		"_has_home = true"
	])), "Set home at [b]{point}[/b]")

	# How far from home, YOUR way. A grid game does not measure in pixels-as-the-crow-flies, and a
	# side-scroller usually only cares about the horizontal drift - so the metric is a parameter and
	# the function branches on it. This is the clean home for that choice: one match, five answers,
	# and every other verb in the pack asks this one function.
	Lib.number(sheet, "distance_from_home", "Distance From Home", "Home & Leash",
		"How far the host is from its home point, measured the way you pick: straight line, one axis only, grid steps (across plus down), or king moves (the larger of the two).",
		[["metric", "int"]], "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn 0.0",
		"_ensure_home()",
		"var offset: Vector2 = host.global_position - _home",
		"match metric:",
		"\t1:",
		"\t\treturn absf(offset.x)",
		"\t2:",
		"\t\treturn absf(offset.y)",
		"\t3:",
		"\t\treturn absf(offset.x) + absf(offset.y)",
		"\t4:",
		"\t\treturn maxf(absf(offset.x), absf(offset.y))",
		"return offset.length()"
	])), TYPE_FLOAT)
	_param_options(sheet, "metric", _METRICS)

	Lib.condition(sheet, "is_beyond_home", "Is Beyond Home", "Home & Leash",
		"True while the host has wandered further than this from home, in the distance metric you pick.",
		[["distance", "float"], ["metric", "int"]],
		"return distance_from_home(metric) > distance")
	_param_options(sheet, "metric", _METRICS)

	# Return Home takes ONE step per call, so it belongs under a per-frame trigger (On Every Tick).
	# delta is an explicit parameter rather than a get_process_delta_time() call: that keeps the step
	# honest under a physics tick, a slow-motion tick, or a hand-stepped test.
	Lib.append_function(sheet, "return_home", "Return Home", "Home & Leash",
		"Walks the host one step back toward home - run it under a per-frame trigger and pass that trigger's delta. Fires On Arrived Home once, on the step that lands (within a pixel of home), not on every frame the host sits there.",
		[["speed", "float"], ["delta", "float"]], "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"_ensure_home()",
		"host.global_position = host.global_position.move_toward(_home, maxf(speed, 0.0) * delta)",
		"if host.global_position.distance_to(_home) < 1.0:",
		"\t# Edge-triggered: only the step that ARRIVES emits, so a host parked at home does not",
		"\t# re-fire the trigger every frame.",
		"\tif _returning:",
		"\t\t_returning = false",
		"\t\tarrived_home.emit()",
		"\treturn",
		"_returning = true"
	])), "Walk home at [b]{speed}[/b]")

	Lib.feature_verbs(sheet, ["is_beyond_home", "return_home"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/home_leash/home_leash_behavior")


# The five ways to measure a leash, as a labeled dropdown (value=Label) on every metric parameter.
const _METRICS := ["0=Straight line", "1=Horizontal only", "2=Vertical only", "3=Grid steps", "4=King moves"]


## Sets the dropdown options[] on the last-appended ACE's parameter (a picker instead of free text).
static func _param_options(sheet: EventSheetResource, param_id: String, choices: Array) -> void:
	var typed: Array[String] = []
	for choice: Variant in choices:
		typed.append(str(choice))
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = typed
