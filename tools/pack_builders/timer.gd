# Pack builder - timer (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## "Timer" behavior: attach under any node; Start/Stop ACEs; "On Timer" trigger.
## Authored entirely as ACE rows; the only RawCode is the unpublished save-state seam.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "TimerBehavior"
	sheet.addon_category = "Timer"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"duration": {"type": "float", "default": 1.0, "exported": true},
		"repeating": {"type": "bool", "default": false, "exported": true},
		"remaining": {"type": "float", "default": 0.0, "exported": false},
		"running": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Timer behavior (event-sheet-style): Start Timer / Stop Timer from any sheet; the On Timer trigger fires when it elapses (repeats when 'repeating')."
	sheet.events.append(about)

	var finished_signal: SignalRow = SignalRow.new()
	finished_signal.signal_name = "timer_finished"
	finished_signal.trigger = true
	finished_signal.ace_name = "On Timer"
	finished_signal.ace_category = "Timer"
	sheet.events.append(finished_signal)

	# On Process: while running, count down; when it elapses, fire On Timer and repeat or stop.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	tick.conditions.append(_cond("ExpressionIsTrue", {"expr": "running"}))
	tick.actions.append(_action("AddVar", {"var_name": "remaining", "amount": "-delta"}))

	var elapsed: EventRow = EventRow.new()
	elapsed.conditions.append(_cond("CompareVar", {"var_name": "remaining", "op": "<=", "value": "0.0"}))
	elapsed.actions.append(_action("EmitSignal", {"signal_name": "timer_finished", "args": ""}))
	var repeat: EventRow = EventRow.new()
	repeat.conditions.append(_cond("ExpressionIsTrue", {"expr": "repeating"}))
	repeat.actions.append(_action("SetVar", {"var_name": "remaining", "value": "duration"}))
	elapsed.sub_events.append(repeat)
	var no_repeat: EventRow = EventRow.new()
	no_repeat.else_mode = EventRow.ElseMode.ELSE
	no_repeat.actions.append(_action("SetVar", {"var_name": "running", "value": "false"}))
	elapsed.sub_events.append(no_repeat)
	tick.sub_events.append(elapsed)
	sheet.events.append(tick)

	# start_timer(seconds): start / restart the countdown.
	var start_timer: EventFunction = EventFunction.new()
	start_timer.function_name = "start_timer"
	start_timer.expose_as_ace = true
	start_timer.ace_display_name = "Start Timer"
	start_timer.ace_category = "Timer"
	start_timer.description = "Starts (or restarts) the countdown with the given duration."
	start_timer.params.append(_param("seconds", "float"))
	var start_body: EventRow = EventRow.new()
	start_body.actions.append(_action("SetVar", {"var_name": "duration", "value": "seconds"}))
	start_body.actions.append(_action("SetVar", {"var_name": "remaining", "value": "seconds"}))
	start_body.actions.append(_action("SetVar", {"var_name": "running", "value": "true"}))
	start_timer.events.append(start_body)
	sheet.functions.append(start_timer)

	# stop_timer(): cancel without firing On Timer.
	var stop_timer: EventFunction = EventFunction.new()
	stop_timer.function_name = "stop_timer"
	stop_timer.expose_as_ace = true
	stop_timer.ace_display_name = "Stop Timer"
	stop_timer.ace_category = "Timer"
	stop_timer.description = "Stops the countdown without firing On Timer."
	var stop_body: EventRow = EventRow.new()
	stop_body.actions.append(_action("SetVar", {"var_name": "running", "value": "false"}))
	stop_timer.events.append(stop_body)
	sheet.functions.append(stop_timer)

	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"remaining\": remaining,",
		"\t\t\"running\": running,",
		"\t\t\"duration\": duration,",
		"\t\t\"repeating\": repeating",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\tremaining = float(state.get(\"remaining\", 0.0))",
		"\trunning = bool(state.get(\"running\", false))",
		"\tduration = float(state.get(\"duration\", 1.0))",
		"\trepeating = bool(state.get(\"repeating\", false))"
	]))
	sheet.events.append(persistence)

	return Lib.save_pack(sheet, "res://eventsheet_addons/timer/timer_behavior")


## Built-in Core ACE rows; templates resolve from the registry at compile time (no baked template).
static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


static func _cond(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	return condition


static func _param(id: String, type_name: String) -> ACEParam:
	var param: ACEParam = ACEParam.new()
	param.id = id
	param.type_name = type_name
	return param
