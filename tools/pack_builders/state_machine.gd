# Pack builder — state_machine (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

## Minimal state machine, authored entirely as ACE rows (ZERO RawCode) — including the Is In State
## CONDITION, now a bool-returning sheet function (the three-way function expose: bool -> condition).
## On State Changed is a trigger SignalRow. See docs/internal/SPEC-behaviour-as-aces-parity.md.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "StateMachineBehavior"
	sheet.variables = {"state": {"type": "String", "default": "idle", "exported": true}}
	var about: CommentRow = CommentRow.new()
	about.text = "State machine behavior: Set State / Is In State from any sheet; On State Changed fires with (previous, next)."
	sheet.events.append(about)

	var changed_signal: SignalRow = SignalRow.new()
	changed_signal.signal_name = "state_changed"
	changed_signal.params = PackedStringArray(["previous: String", "next: String"])
	changed_signal.trigger = true
	changed_signal.ace_name = "On State Changed"
	changed_signal.ace_category = "State Machine"
	sheet.events.append(changed_signal)

	# Is In State — a bool function publishes as a CONDITION (three-way function expose).
	var is_in_state: EventFunction = EventFunction.new()
	is_in_state.function_name = "is_in_state"
	is_in_state.return_type = TYPE_BOOL
	is_in_state.expose_as_ace = true
	is_in_state.ace_display_name = "Is In State"
	is_in_state.ace_category = "State Machine"
	is_in_state.description = "True while the machine is in the given state."
	is_in_state.params.append(_param("state_name", "String"))
	var is_in_state_body: EventRow = EventRow.new()
	is_in_state_body.actions.append(_action("ReturnValue", {"value": "state == state_name"}))
	is_in_state.events.append(is_in_state_body)
	sheet.functions.append(is_in_state)

	# Set State — switch and fire On State Changed, but only on a real change.
	var set_state: EventFunction = EventFunction.new()
	set_state.function_name = "set_state"
	set_state.expose_as_ace = true
	set_state.ace_display_name = "Set State"
	set_state.ace_category = "State Machine"
	set_state.description = "Switches to the given state and fires On State Changed."
	set_state.params.append(_param("next", "String"))
	var set_state_body: EventRow = EventRow.new()
	set_state_body.conditions.append(_cond("ExpressionIsTrue", {"expr": "state != next"}))
	set_state_body.actions.append(_action("SetLocalVarTyped", {"name": "previous", "var_type": "String", "value": "state"}))
	set_state_body.actions.append(_action("SetVar", {"var_name": "state", "value": "next"}))
	set_state_body.actions.append(_action("EmitSignal", {"signal_name": "state_changed", "args": "previous, next"}))
	set_state.events.append(set_state_body)
	sheet.functions.append(set_state)

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
