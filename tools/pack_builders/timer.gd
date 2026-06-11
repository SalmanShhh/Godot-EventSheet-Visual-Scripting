# Pack builder — timer (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

## C3 "Timer" behavior: attach under any node; Start/Stop ACEs; "On Timer" trigger.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "TimerBehavior"
	sheet.variables = {
		"duration": {"type": "float", "default": 1.0, "exported": true},
		"repeating": {"type": "bool", "default": false, "exported": true},
		"remaining": {"type": "float", "default": 0.0, "exported": false},
		"running": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Timer behavior (C3-style): Start Timer / Stop Timer from any sheet; the On Timer trigger fires when it elapses (repeats when 'repeating')."
	sheet.events.append(about)
	var signal_block: RawCodeRow = RawCodeRow.new()
	signal_block.code = "## @ace_trigger\n## @ace_name(\"On Timer\")\n## @ace_category(\"Timer\")\nsignal timer_finished"
	sheet.events.append(signal_block)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var countdown: RawCodeRow = RawCodeRow.new()
	countdown.code = "\n".join(PackedStringArray([
		"if not running:",
		"\treturn",
		"remaining -= delta",
		"if remaining > 0.0:",
		"\treturn",
		"timer_finished.emit()",
		"if repeating:",
		"\tremaining = duration",
		"else:",
		"\trunning = false"
	]))
	tick.actions.append(countdown)
	sheet.events.append(tick)

	var start_timer: EventFunction = EventFunction.new()
	start_timer.function_name = "start_timer"
	start_timer.expose_as_ace = true
	start_timer.ace_display_name = "Start Timer"
	start_timer.ace_category = "Timer"
	start_timer.description = "Starts (or restarts) the countdown with the given duration."
	var seconds_param: ACEParam = ACEParam.new()
	seconds_param.id = "seconds"
	seconds_param.type_name = "float"
	start_timer.params.append(seconds_param)
	var start_body: RawCodeRow = RawCodeRow.new()
	start_body.code = "duration = seconds\nremaining = seconds\nrunning = true"
	start_timer.events.append(start_body)
	sheet.functions.append(start_timer)

	var stop_timer: EventFunction = EventFunction.new()
	stop_timer.function_name = "stop_timer"
	stop_timer.expose_as_ace = true
	stop_timer.ace_display_name = "Stop Timer"
	stop_timer.ace_category = "Timer"
	stop_timer.description = "Stops the countdown without firing On Timer."
	var stop_body: RawCodeRow = RawCodeRow.new()
	stop_body.code = "running = false"
	stop_timer.events.append(stop_body)
	sheet.functions.append(stop_timer)
	return Lib.save_pack(sheet, "res://eventsheet_addons/timer/timer_behavior")
