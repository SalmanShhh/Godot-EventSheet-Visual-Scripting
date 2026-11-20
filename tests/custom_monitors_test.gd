# Godot EventSheets - your own numbers in the debugger's Monitors tab: Show In Monitors,
# Remove From Monitors, Is In Monitors and Custom Monitor Value.
#
# Four promises:
#   1. THE ROWS. Id, kind, name, page, fields, template and reading, pinned as text, with defaults
#      that stand on their own.
#   2. WHAT THE FILE SAYS. A sheet holding them compiles to one exact file that parses.
#   3. WHAT COMES BACK. The compiled file reopens as the same rows and re-emits byte for byte; a lone
#      hand-written `add_custom_monitor` line keeps the reading it has and still round-trips.
#   4. WHAT THE ENGINE DOES. In a process with a real tree: the number is read at each look, a name
#      shown twice is replaced without an engine error, and a node that leaves the game takes its
#      graph with it, so the Monitors tab is never asked for a number whose node is gone.
@tool
class_name CustomMonitorsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "custom_monitors_test"
const PROBE: String = "res://tests/custom_monitors_probe.gd"

## What the sheet built by `_compiled` writes.
const SHOWN: String = "extends Node\n\nfunc _ready() -> void:\n\tif Performance.has_custom_monitor(\"Game/Score\"):\n\t\tPerformance.remove_custom_monitor(\"Game/Score\")\n\tPerformance.add_custom_monitor(\"Game/Score\", func(): return score)\n\ttree_exiting.connect(func(): if Performance.has_custom_monitor(\"Game/Score\"): Performance.remove_custom_monitor(\"Game/Score\"))\n\tif Performance.has_custom_monitor(\"Game/Score\"):\n\t\tprint(Performance.get_custom_monitor(\"Game/Score\"))\n"


static func run() -> bool:
	var ok: bool = _the_rows()
	ok = _what_the_file_says() and ok
	ok = _what_comes_back() and ok
	ok = _what_the_engine_does() and ok
	return ok


static func _the_rows() -> bool:
	return SUPPORT.pins(P, [
		["Show In Monitors", _row_text("ShowInMonitors"),
			"action|Show In Monitors|Debug|name,value|if Performance.has_custom_monitor({name}):\n\tPerformance.remove_custom_monitor({name})\nPerformance.add_custom_monitor({name}, func(): return {value})\ntree_exiting.connect(func(): if Performance.has_custom_monitor({name}): Performance.remove_custom_monitor({name}))|Show [b]{value}[/b] in Monitors as [b]{name}[/b]"],
		["Remove From Monitors", _row_text("RemoveFromMonitors"),
			"action|Remove From Monitors|Debug|name|if Performance.has_custom_monitor({name}):\n\tPerformance.remove_custom_monitor({name})|Remove [b]{name}[/b] from Monitors"],
		["Is In Monitors", _row_text("IsInMonitors"),
			"condition|Is In Monitors|Debug|name|Performance.has_custom_monitor({name})|[b]{name}[/b] is in Monitors"],
		["Custom Monitor Value", _row_text("CustomMonitorValue"),
			"expression|Custom Monitor Value|Debug|name|Performance.get_custom_monitor({name})|monitor [b]{name}[/b] value"],
		["the name starts as a heading and a name", _default("ShowInMonitors", "name"), "\"Game/Enemies\""],
		["the number starts as something a plain node can answer", _default("ShowInMonitors", "value"),
			"get_tree().get_node_count_in_group(\"enemies\")"],
		["the rows beside them are unchanged", _row_text("MeasuredLast").get_slice("|", 1), "Last Measured (ms)"],
	])


static func _what_the_file_says() -> bool:
	var output: String = _compiled()
	var parsed: GDScript = GDScript.new()
	parsed.source_code = output.replace("extends Node\n", "extends Node\n\nvar score: int = 0\n")
	return SUPPORT.pins(P, [
		["the whole file", output.substr(output.find("extends Node")), SHOWN],
		["it parses", parsed.reload(), OK],
	])


static func _what_comes_back() -> bool:
	var lifted: PackedStringArray = _lifted_ids(SHOWN)
	var hand: String = "extends Node\n\nvar score: int = 0\n\nfunc _ready() -> void:\n\tPerformance.add_custom_monitor(\"Game/Score\", func(): return score)\n"
	var odd: String = "extends Node\n\nfunc _ready() -> void:\n\tif Performance.has_custom_monitor(\"Game/A\"):\n\t\tPerformance.remove_custom_monitor(\"Game/B\")\n"
	return SUPPORT.pins(P, [
		["the file's rows reopen as the rows that wrote it", lifted, PackedStringArray(["ShowInMonitors", "IsInMonitors", "PrintLog"])],
		["and re-emit byte for byte", SUPPORT.reemit(SHOWN, SUPPORT.own_path("custom_monitors_roundtrip.gd")), SHOWN],
		["a lone hand-written add is not the row, which also guards and cleans up", _lifted_ids(hand).has("ShowInMonitors"), false],
		["and re-emits byte for byte", SUPPORT.reemit(hand, SUPPORT.own_path("custom_monitors_hand.gd")), hand],
		["a guard over one name and a removal of another is not the row", _lifted_ids(odd).has("RemoveFromMonitors"), false],
		["and re-emits byte for byte", SUPPORT.reemit(odd, SUPPORT.own_path("custom_monitors_odd.gd")), odd],
	])


## The compiled file, run in a process of its own with a real tree: the probe prints its verdict and
## the engine's own errors would show in the same output, so none may.
static func _what_the_engine_does() -> bool:
	var script_path: String = SUPPORT.own_path("custom_monitors_shown.gd")
	var file: FileAccess = FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		return SUPPORT.check(P, "the compiled script can be written for the probe", false, true)
	file.store_string(_compiled().replace("extends Node\n", "extends Node\n\nvar score: int = 3\n"))
	file.close()
	var output: Array = []
	OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", PROBE, "--",
		ProjectSettings.globalize_path(script_path)]), output, true)
	var text: String = ""
	for chunk: Variant in output:
		text += "%s\n" % str(chunk)
	var checks: int = -1
	var fails: int = -1
	var errors: PackedStringArray = PackedStringArray()
	for line: String in text.split("\n"):
		if line.begins_with("monitors_probe checks="):
			var parts: PackedStringArray = line.trim_prefix("monitors_probe ").split(" ", false)
			checks = int(parts[0].trim_prefix("checks="))
			fails = int(parts[1].trim_prefix("fails="))
		elif line.begins_with("monitors_probe_fail "):
			print("  %s" % line)
		elif line.begins_with("ERROR:") or line.begins_with("SCRIPT ERROR:"):
			errors.append(line)
	if checks < 0:
		print("  the probe printed no result line; its output was:\n%s" % text)
	return SUPPORT.pins(P, [
		["the probe answered", checks > 0, true],
		["every check held", fails, 0],
		["and the engine printed no error while it ran", errors, PackedStringArray()],
	])


## One event on ready: show a number, and if it is there, print it back.
static func _compiled() -> String:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_action("ShowInMonitors", {"name": "\"Game/Score\"", "value": "score"}))
	var asked: EventRow = EventRow.new()
	asked.conditions.append(_condition("IsInMonitors", {"name": "\"Game/Score\""}))
	asked.actions.append(_action("Print", {"value": "Performance.get_custom_monitor(\"Game/Score\")"}))
	event.sub_events.append(asked)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(event)
	return SUPPORT.compile_output(sheet, SUPPORT.own_path("custom_monitors_compiled.gd"))


static func _row_text(ace_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor == null:
		return "missing"
	var fields: PackedStringArray = PackedStringArray()
	for parameter: ACEParam in descriptor.params:
		fields.append(str(parameter.id))
	var kind: String = "expression"
	if descriptor.ace_type == ACEDescriptor.ACEType.CONDITION:
		kind = "condition"
	elif descriptor.ace_type == ACEDescriptor.ACEType.ACTION:
		kind = "action"
	return "%s|%s|%s|%s|%s|%s" % [kind, descriptor.display_name, descriptor.category, ",".join(fields),
		descriptor.codegen_template, descriptor.display_text]


static func _default(ace_id: String, param_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor != null:
		for parameter: ACEParam in descriptor.params:
			if str(parameter.id) == param_id:
				return str(parameter.default_value)
	return "missing"


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	var filled: Dictionary = {}
	if descriptor != null:
		for parameter: ACEParam in descriptor.params:
			filled[str(parameter.id)] = str(parameter.default_value)
		action.codegen_template = descriptor.codegen_template
	filled.merge(params, true)
	action.params = filled
	return action


static func _condition(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	var filled: Dictionary = {}
	if descriptor != null:
		for parameter: ACEParam in descriptor.params:
			filled[str(parameter.id)] = str(parameter.default_value)
		condition.codegen_template = descriptor.codegen_template
	filled.merge(params, true)
	condition.params = filled
	return condition


## The ids of every condition and action the reopened file's events carry, in file order.
static func _lifted_ids(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var reopened: EventSheetResource = SUPPORT.reopen(source)
	if reopened != null:
		for item: Variant in reopened.events:
			_collect_ids(item, found)
		for function: Variant in reopened.functions:
			if function is EventFunction:
				for item: Variant in (function as EventFunction).events:
					_collect_ids(item, found)
	return found


static func _collect_ids(item: Variant, found: PackedStringArray) -> void:
	if item is EventGroup:
		for inner: Variant in (item as EventGroup).events:
			_collect_ids(inner, found)
		return
	if not (item is EventRow):
		return
	var row: EventRow = item as EventRow
	for condition: Variant in row.conditions:
		if condition is ACECondition:
			found.append(str((condition as ACECondition).ace_id))
	for action: Variant in row.actions:
		if action is ACEAction:
			found.append(str((action as ACEAction).ace_id))
	for sub: Variant in row.sub_events:
		_collect_ids(sub, found)
