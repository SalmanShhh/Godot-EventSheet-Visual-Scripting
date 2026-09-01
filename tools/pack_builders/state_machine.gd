# Pack builder - state_machine (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Minimal state machine, authored as ACE rows (the only RawCode is the unpublished save-state
## seam) - including the Current state is
## CONDITION, now a bool-returning sheet function (the three-way function expose: bool -> condition).
## On any state change is a trigger SignalRow.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "StateMachineBehavior"
	sheet.class_description = "Gives a node one named \"what am I doing right now\" state and a clean way to switch it. Go to state changes it, Current state is branches on it, and On any state change fires on every switch with the state you left and the state you entered."
	sheet.addon_category = "State Machine"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"_state_entered_ticks": {"type": "int", "default": 0, "exported": false},
		"previous_state": {"type": "String", "default": "", "exported": false},
		"state": {"type": "String", "default": "idle", "exported": true, "description": "The machine's current state name; change it with Go to state."}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "State machine behavior: Go to state / Current state is from any sheet; On any state change fires with (previous, next)."
	sheet.events.append(about)

	var changed_signal: SignalRow = SignalRow.new()
	changed_signal.signal_name = "state_changed"
	changed_signal.params = PackedStringArray(["previous: String", "next: String"])
	changed_signal.trigger = true
	changed_signal.ace_name = "On any state change"
	changed_signal.ace_category = "State Machine"
	sheet.events.append(changed_signal)

	# Current state is - a bool function publishes as a CONDITION (three-way function expose).
	var is_in_state: EventFunction = EventFunction.new()
	is_in_state.function_name = "is_in_state"
	is_in_state.return_type = TYPE_BOOL
	is_in_state.expose_as_ace = true
	is_in_state.ace_display_name = "Current state is"
	is_in_state.ace_category = "State Machine"
	is_in_state.description = "True while the machine is in the given state."
	# The newer spelling of this exact question is the object-state row Is in, which asks about the
	# object's own declared states instead of a string held in a child node. Same question, same
	# answer, one parameter renamed - so the address is worth carrying. The verb itself is frozen:
	# same id, same template, and every sheet already asking it compiles unchanged.
	is_in_state.successor_ace_id = "Core::InState"
	is_in_state.successor_param_renames = {"state_name": "state"}
	is_in_state.params.append(_param("state_name", "String"))
	var is_in_state_body: EventRow = EventRow.new()
	is_in_state_body.actions.append(_action("ReturnValue", {"value": "state == state_name"}))
	is_in_state.events.append(is_in_state_body)
	sheet.functions.append(is_in_state)

	# Go to state - switch and fire On any state change, but only on a real change.
	var set_state: EventFunction = EventFunction.new()
	set_state.function_name = "set_state"
	set_state.expose_as_ace = true
	set_state.ace_display_name = "Go to state"
	set_state.ace_category = "State Machine"
	set_state.description = "Switches to the given state and fires On any state change."
	# And the newer spelling of the switch is Go to state, whose announcement rides the state
	# variable's own setter rather than this function. One parameter renamed, nothing else to say.
	#
	# The other two published verbs deliberately carry NO address, because neither has one that is
	# honest: Time in state is an expression the object-state family has no twin for (its timed
	# question is a CONDITION, Is in X for over N seconds, which is a different shape), and On any
	# state change fires for every switch while On entering / On leaving each name one state - so
	# forwarding it would mean inventing a state the old row never named.
	set_state.successor_ace_id = "Core::GoToState"
	set_state.successor_param_renames = {"next": "state"}
	set_state.params.append(_param("next", "String"))
	var set_state_body: EventRow = EventRow.new()
	set_state_body.conditions.append(_cond("ExpressionIsTrue", {"expr": "state != next"}))
	set_state_body.actions.append(_action("SetLocalVarTyped", {"name": "previous", "var_type": "String", "value": "state"}))
	set_state_body.actions.append(_action("SetVar", {"var_name": "state", "value": "next"}))
	# Remember where we came from and when we arrived, so a sheet can read both without bookkeeping.
	set_state_body.actions.append(_action("SetVar", {"var_name": "previous_state", "value": "previous"}))
	set_state_body.actions.append(_action("SetVar", {"var_name": "_state_entered_ticks", "value": "Time.get_ticks_msec()"}))
	set_state_body.actions.append(_action("EmitSignal", {"signal_name": "state_changed", "args": "previous, next"}))
	set_state.events.append(set_state_body)
	sheet.functions.append(set_state)

	# Time in state - seconds since the last switch, from the clock stamped by Go to state.
	var time_in_state: EventFunction = EventFunction.new()
	time_in_state.function_name = "time_in_state"
	time_in_state.return_type = TYPE_FLOAT
	time_in_state.expose_as_ace = true
	time_in_state.ace_display_name = "Time in state"
	time_in_state.ace_category = "State Machine"
	time_in_state.description = "How many seconds the machine has been in its current state."
	var time_in_state_body: EventRow = EventRow.new()
	time_in_state_body.actions.append(_action("ReturnValue", {"value": "(float(Time.get_ticks_msec() - _state_entered_ticks) / 1000.0)"}))
	time_in_state.events.append(time_in_state_body)
	sheet.functions.append(time_in_state)

	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"# The parameter is named data (not state) so it never shadows the state member.",
		"# Loading assigns state directly - a restore must not fire On any state change.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"state\": state",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(data: Dictionary) -> void:",
		"\tif data.is_empty():",
		"\t\treturn",
		"\tstate = str(data.get(\"state\", \"idle\"))"
	]))
	sheet.events.append(persistence)

	return Lib.save_pack(sheet, "res://eventsheet_addons/state_machine/state_machine_behavior")


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
