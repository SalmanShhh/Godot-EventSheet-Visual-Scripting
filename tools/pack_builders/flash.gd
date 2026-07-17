# Pack builder - flash (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## "Flash" behavior: toggles host visibility at an interval for a duration.
##
## Authored entirely as ACE rows - ZERO RawCode - the first bundled pack to prove the
## behaviour-as-ACEs path end to end. The signal is a
## trigger SignalRow; the tick is a gated On Process event with sub-events; the two exposed functions
## are ACE-action bodies. Node-scoped writes target the parent host via the {host.} / explicit-target
## idiom. Guarded by flash_pack_zero_rawcode_test.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CanvasItem"
	sheet.custom_class_name = "FlashBehavior"
	sheet.class_description = "Blinks the host node's visibility on and off for a duration, then snaps it back to fully visible and fires On Flash Finished. The classic damage-flicker and invincibility-frames effect, with a single interval knob you can change live."
	sheet.addon_category = "Flash"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"interval": {"type": "float", "default": 0.1, "exported": true, "description": "Seconds between visibility toggles - smaller values blink faster."},
		"remaining": {"type": "float", "default": 0.0, "exported": false},
		"accumulator": {"type": "float", "default": 0.0, "exported": false},
		"flashing": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Flash behavior (event-sheet-style): blinks the host's visibility for a duration, then restores it and fires On Flash Finished."
	sheet.events.append(about)

	# Trigger signal as a ROW (replaces the hand-written @ace_trigger GDScript block).
	var finished_signal: SignalRow = SignalRow.new()
	finished_signal.signal_name = "flash_finished"
	finished_signal.trigger = true
	finished_signal.ace_name = "On Flash Finished"
	finished_signal.ace_category = "Flash"
	sheet.events.append(finished_signal)

	# On Process: while flashing on a live host, blink at the interval and finish when the timer ends.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	tick.conditions.append(_cond("ExpressionIsTrue", {"expr": "flashing"}))
	tick.conditions.append(_cond("IsValid", {"target": "host"}))
	tick.actions.append(_action("AddVar", {"var_name": "remaining", "amount": "-delta"}))
	tick.actions.append(_action("AddVar", {"var_name": "accumulator", "amount": "delta"}))

	var blink: EventRow = EventRow.new()
	blink.conditions.append(_cond("CompareVar", {"var_name": "accumulator", "op": ">=", "value": "interval"}))
	blink.actions.append(_action("SetVar", {"var_name": "accumulator", "value": "0.0"}))
	blink.actions.append(_action("SetProperty", {"target": "host", "property": "visible", "value": "not host.visible"}))
	tick.sub_events.append(blink)

	var finish: EventRow = EventRow.new()
	finish.conditions.append(_cond("CompareVar", {"var_name": "remaining", "op": "<=", "value": "0.0"}))
	finish.actions.append(_action("SetVar", {"var_name": "flashing", "value": "false"}))
	finish.actions.append(_action("SetProperty", {"target": "host", "property": "visible", "value": "true"}))
	finish.actions.append(_action("EmitSignal", {"signal_name": "flash_finished", "args": ""}))
	tick.sub_events.append(finish)
	sheet.events.append(tick)

	# flash(seconds): start a flash burst.
	var flash: EventFunction = EventFunction.new()
	flash.function_name = "flash"
	flash.expose_as_ace = true
	flash.ace_display_name = "Flash"
	flash.ace_category = "Flash"
	flash.description = "Blinks the host for the given number of seconds."
	flash.params.append(_param("seconds", "float"))
	var flash_body: EventRow = EventRow.new()
	flash_body.actions.append(_action("SetVar", {"var_name": "remaining", "value": "seconds"}))
	flash_body.actions.append(_action("SetVar", {"var_name": "accumulator", "value": "0.0"}))
	flash_body.actions.append(_action("SetVar", {"var_name": "flashing", "value": "true"}))
	flash.events.append(flash_body)
	sheet.functions.append(flash)

	# stop_flash(): cancel and restore visibility.
	var stop_flash: EventFunction = EventFunction.new()
	stop_flash.function_name = "stop_flash"
	stop_flash.expose_as_ace = true
	stop_flash.ace_display_name = "Stop Flash"
	stop_flash.ace_category = "Flash"
	stop_flash.description = "Stops flashing and restores visibility."
	var stop_set: EventRow = EventRow.new()
	stop_set.actions.append(_action("SetVar", {"var_name": "flashing", "value": "false"}))
	stop_flash.events.append(stop_set)
	var stop_restore: EventRow = EventRow.new()
	stop_restore.conditions.append(_cond("IsValid", {"target": "host"}))
	stop_restore.actions.append(_action("SetProperty", {"target": "host", "property": "visible", "value": "true"}))
	stop_flash.events.append(stop_restore)
	sheet.functions.append(stop_flash)

	return Lib.save_pack(sheet, "res://eventsheet_addons/flash/flash_behavior")


## Builds a built-in Core ACE action row; the codegen template is resolved from the registry at
## compile time (no baked template needed for built-ins).
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
