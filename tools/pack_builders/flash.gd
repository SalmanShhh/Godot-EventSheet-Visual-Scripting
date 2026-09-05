# Pack builder - flash (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## "Flash" behavior: toggles host visibility at an interval for a duration.
##
## The flash half is authored as ACE rows - the first bundled pack to prove the behaviour-as-ACEs
## path end to end. The signal is a trigger SignalRow; the tick is a gated On Process event with
## sub-events; the two exposed functions are ACE-action bodies. Node-scoped writes target the parent
## host via the {host.} / explicit-target idiom.
##
## The BLINK half below is written as code, because a pattern is a little state machine over a file's
## phases and rows would spell it as twenty of them.
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
		"flashing": {"type": "bool", "default": false, "exported": false},
		"blink_pattern": {"type": "Resource", "default": null, "exported": false},
		"blink_index": {"type": "int", "default": 0, "exported": false},
		"blink_left": {"type": "int", "default": 0, "exported": false},
		"blink_shown": {"type": "bool", "default": true, "exported": false},
		"blink_timer": {"type": "float", "default": 0.0, "exported": false},
		"blink_limit": {"type": "float", "default": 0.0, "exported": false},
		"blinking": {"type": "bool", "default": false, "exported": false}
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

	# A host is authored not flashing, and a host that is not flashing has nothing to blink:
	# processing starts off, so a behavior no row ever flashes costs nothing per frame.
	var ready_row: EventRow = EventRow.new()
	ready_row.trigger_provider_id = "Core"
	ready_row.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "set_process(false)"
	ready_row.actions.append(ready_body)
	sheet.events.append(ready_row)

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
	# A strobe is a medical problem rather than a taste, so a player who has asked for no flashing
	# gets a fade of the same rhythm instead of the blink: the host stays visible and its alpha
	# steps between full and faint. The setting is plain metadata on Engine, so any project can set
	# it with one row and a project that never asks gets exactly the blink it always had.
	var toggle: RawCodeRow = RawCodeRow.new()
	toggle.code = "
".join(PackedStringArray([
		"if bool(Engine.get_meta(\"no_flashing\", false)):",
		"	host.visible = true",
		"	host.modulate.a = 1.0 if host.modulate.a < 0.7 else 0.35",
		"else:",
		"	host.visible = not host.visible"
	]))
	blink.actions.append(toggle)
	tick.sub_events.append(blink)

	var finish: EventRow = EventRow.new()
	finish.conditions.append(_cond("CompareVar", {"var_name": "remaining", "op": "<=", "value": "0.0"}))
	finish.actions.append(_action("SetVar", {"var_name": "flashing", "value": "false"}))
	finish.actions.append(_action("SetProperty", {"target": "host", "property": "visible", "value": "true"}))
	# Whichever of the two the burst used, the host is handed back at full opacity.
	var restore_alpha: RawCodeRow = RawCodeRow.new()
	restore_alpha.code = "host.modulate.a = 1.0"
	finish.actions.append(restore_alpha)
	# A burst that has run out is finished, not merely quiet - stop paying for the tick until
	# Flash asks for another one. It goes off BEFORE the trigger fires, so a row that starts a
	# fresh flash from On Flash Finished turns processing back on and is not switched off again.
	var finish_idle: RawCodeRow = RawCodeRow.new()
	finish_idle.code = "set_process(false)"
	finish.actions.append(finish_idle)
	finish.actions.append(_action("EmitSignal", {"signal_name": "flash_finished", "args": ""}))
	tick.sub_events.append(finish)
	sheet.events.append(tick)

	# The blink's own half: the pattern player, and the tick that runs it. It sits AFTER the flash's
	# tick on purpose - a flash that ends gives the frame up with set_process(false), and the row
	# below takes it straight back when a blink is still going.
	var blink_block: RawCodeRow = RawCodeRow.new()
	blink_block.code = "\n".join(_blink_lines())
	sheet.events.append(blink_block)
	var blink_tick: EventRow = EventRow.new()
	blink_tick.trigger_provider_id = "Core"
	blink_tick.trigger_id = "OnProcess"
	blink_tick.conditions.append(_cond("ExpressionIsTrue", {"expr": "blinking"}))
	var blink_step: RawCodeRow = RawCodeRow.new()
	blink_step.code = "_blink_step(delta)"
	blink_tick.actions.append(blink_step)
	sheet.events.append(blink_tick)

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
	# A blinking host needs the frame it blinks in; the burst's own last tick and Stop Flash
	# turn processing back off.
	var flash_tick: RawCodeRow = RawCodeRow.new()
	flash_tick.code = "set_process(true)"
	flash_body.actions.append(flash_tick)
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
	# A host that is not blinking costs nothing per frame; Flash turns processing back on.
	var stop_idle: RawCodeRow = RawCodeRow.new()
	stop_idle.code = "set_process(false)"
	stop_set.actions.append(stop_idle)
	stop_flash.events.append(stop_set)
	var stop_restore: EventRow = EventRow.new()
	stop_restore.conditions.append(_cond("IsValid", {"target": "host"}))
	stop_restore.actions.append(_action("SetProperty", {"target": "host", "property": "visible", "value": "true"}))
	stop_flash.events.append(stop_restore)
	sheet.functions.append(stop_flash)

	# --- Blink patterns: the rhythm is a file the game owns ---
	Lib.append_function(sheet, "blink", "Blink", "Flash", "Plays a blink pattern on the host: a BlinkPatternResource file of phases, each one \"on for this long, off for that long, this many times\". A player who has asked for no flashing gets the same pattern held to a floor and faded instead of hidden, so a pattern can never strobe.",
		[["pattern", "Resource", "The BlinkPatternResource file to play. It is your file: draw the rhythm once in the Inspector and share it between everything that blinks that way."],
			["seconds", "float", "Stop after this long, whatever the pattern is doing. 0 plays the pattern out to its last phase."]],
		"if pattern == null:\n\treturn\nblink_pattern = pattern\nblink_index = 0\nblink_left = _blink_repeats()\nblink_shown = true\nblink_timer = _blink_hold(_blink_phase_number(\"on\", 0.08))\nblink_limit = maxf(seconds, 0.0)\nblinking = not _blink_phases().is_empty()\n_blink_apply()\nif blinking:\n\t# A blinking host needs the frame it blinks in; the pattern's own end turns it back off.\n\tset_process(true)",
		"Blink [b]{pattern}[/b] for [b]{seconds}[/b] s")
	Lib.append_function(sheet, "stop_blink", "Stop Blink", "Flash", "Ends the blink now and hands the host back fully visible, wherever in the pattern it had got to.",
		[],
		"_blink_end()")
	Lib.condition(sheet, "is_blinking", "Is Blinking", "Flash", "Whether a blink pattern is playing on this host right now.",
		[],
		"return blinking")
	Lib.number(sheet, "blink_phase", "Blink Phase", "Flash", "Which phase of the pattern is playing, counting from 1. 0 when nothing is blinking - so a row can tell the fast winks from the slow ones that follow them.",
		[],
		"if not blinking:\n\treturn 0\nreturn blink_index + 1", TYPE_INT)
	if not Lib.save_pack(sheet, "res://eventsheet_addons/flash/flash_behavior"):
		return false
	# One starter pattern ships beside the pack so a first Blink row has something to point at on the
	# day it is written. It is an ordinary file: retune it, rename it, duplicate it into the rhythm
	# this game actually wants, or delete it. Nothing in the pack names it.
	return Lib.ship_files("flash", "res://eventsheet_addons/flash/flash_behavior",
		PackedStringArray(["tres"]))


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


## The BLINK half of the pack: the little state machine a pattern file is played by.
##
## A pattern is a list of phases, and a phase is on seconds, off seconds and a count. The player
## walks them in order: each flip spends the timer, each off part spends one of the phase's repeats,
## and a phase out of repeats hands over to the next. Nothing here knows any pattern - the file is
## the game's, and the one that ships beside the pack is a starter to edit or throw away.
static func _blink_lines() -> PackedStringArray:
	return PackedStringArray([
		"# --- Blink patterns: a rhythm the game owns, played on the host ---",
		"",
		"## The project-wide answer to \"this player has asked for no flashing\", the same plain Engine",
		"## meta every other flashing thing here reads, so one row sets it for the whole game.",
		"const BLINK_NO_FLASHING_META: StringName = &\"no_flashing\"",
		"",
		"## No part of a blink may be shorter than this once no flashing has been asked for: the pattern",
		"## still plays, at a rate nobody can be hurt by. A strobe is a medical problem rather than a",
		"## taste, which is why the ceiling is held here instead of trusted to each pattern file.",
		"const BLINK_FLOOR_SECONDS: float = 0.4",
		"",
		"## Whether the player has asked for no flashing at all.",
		"func _blink_reduced() -> bool:",
		"\treturn bool(Engine.get_meta(BLINK_NO_FLASHING_META, false))",
		"",
		"## How long one part of a phase really lasts: what the file says, floored so a pattern advances",
		"## even when its numbers are shorter than a frame, and floored much harder for a player who has",
		"## asked for no flashing.",
		"func _blink_hold(seconds: float) -> float:",
		"\tif _blink_reduced():",
		"\t\treturn maxf(seconds, BLINK_FLOOR_SECONDS)",
		"\treturn maxf(seconds, 0.01)",
		"",
		"## The phases of the pattern in flight, or nothing at all when the file is missing or empty.",
		"func _blink_phases() -> Array:",
		"\tif blink_pattern == null:",
		"\t\treturn []",
		"\tvar listed: Variant = blink_pattern.get(\"phases\")",
		"\tif listed is Array:",
		"\t\treturn listed",
		"\treturn []",
		"",
		"## One number out of the phase now playing, with the fallback a file that left it out gets.",
		"func _blink_phase_number(key: String, fallback: float) -> float:",
		"\tvar phases: Array = _blink_phases()",
		"\tif blink_index < 0 or blink_index >= phases.size():",
		"\t\treturn fallback",
		"\tvar phase: Dictionary = phases[blink_index]",
		"\treturn float(phase.get(key, fallback))",
		"",
		"## How many times the phase now playing repeats. Always at least once: a phase nobody plays is",
		"## a phase nobody can see, and a file that says 0 meant one.",
		"func _blink_repeats() -> int:",
		"\treturn maxi(int(_blink_phase_number(\"count\", 1.0)), 1)",
		"",
		"## The host, as the blink wants it this instant.",
		"func _blink_apply() -> void:",
		"\tif host == null:",
		"\t\treturn",
		"\tif _blink_reduced():",
		"\t\t# The same answer the flash above gives: the host stays where the eye can find it and",
		"\t\t# steps between full and faint instead of disappearing.",
		"\t\thost.visible = true",
		"\t\thost.modulate.a = 1.0 if blink_shown else 0.35",
		"\telse:",
		"\t\thost.visible = blink_shown",
		"",
		"## The end of a blink, however it came: the host is handed back whole.",
		"func _blink_end() -> void:",
		"\tblinking = false",
		"\tblink_index = 0",
		"\tblink_left = 0",
		"\tblink_shown = true",
		"\tif host != null:",
		"\t\thost.visible = true",
		"\t\thost.modulate.a = 1.0",
		"\t# A blink that is over costs nothing per frame - and a flash that is still running keeps its",
		"\t# own tick, which is why this asks rather than simply switching processing off.",
		"\tset_process(flashing)",
		"",
		"## One frame of a blink. The timer runs down, and every time it runs out the host flips: an on",
		"## part becomes an off part, an off part spends one of the phase's repeats, and a phase with no",
		"## repeats left hands over to the next one. A while rather than an if, so a pattern whose parts",
		"## are shorter than a frame still advances instead of drifting behind.",
		"func _blink_step(delta: float) -> void:",
		"\tif not blinking:",
		"\t\treturn",
		"\tif blink_limit > 0.0:",
		"\t\tblink_limit -= delta",
		"\t\tif blink_limit <= 0.0:",
		"\t\t\t_blink_end()",
		"\t\t\treturn",
		"\tblink_timer -= delta",
		"\twhile blinking and blink_timer <= 0.0:",
		"\t\tif blink_shown:",
		"\t\t\tblink_shown = false",
		"\t\t\tblink_timer += _blink_hold(_blink_phase_number(\"off\", 0.08))",
		"\t\telse:",
		"\t\t\tblink_left -= 1",
		"\t\t\tif blink_left <= 0:",
		"\t\t\t\tblink_index += 1",
		"\t\t\t\tif blink_index >= _blink_phases().size():",
		"\t\t\t\t\t_blink_end()",
		"\t\t\t\t\treturn",
		"\t\t\t\tblink_left = _blink_repeats()",
		"\t\t\tblink_shown = true",
		"\t\t\tblink_timer += _blink_hold(_blink_phase_number(\"on\", 0.08))",
		"\t\t_blink_apply()",
		"\t# A blink owns this frame even when a flash that ended in the same one has just given it up.",
		"\tset_process(true)"
	])
