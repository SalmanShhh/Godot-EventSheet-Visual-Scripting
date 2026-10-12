# Godot EventSheets - pause requests: Ask To Pause, Stop Asking To Pause and Pause Requested By,
# beside Pause The Game, Set Game Paused and Is Game Paused.
#
# Seven promises, in the order they matter:
#   1. THE ROWS. Each one's id, kind, name, page, fields, template and reading, pinned as text, and
#      the pause rows beside them unchanged character for character.
#   2. WHAT THE FILE SAYS. A sheet holding all three compiles to one exact file: the shared set
#      declared once beside the class, the two-line requests, and the function the set comes from.
#   3. ONE SET FOR THE WHOLE GAME. Two separately loaded scripts count into the same set, so one
#      reason stopping does not unpause a game another reason still holds paused.
#   4. WHAT COMES BACK. The compiled file and a hand-written one reopen as the three rows - never as
#      a Set Paused - and re-emit byte for byte; a lone pause line keeps the row it always had.
#   5. THE READINGS, as the canvas draws them - and the question does not read as a frozen node.
#   6. THE GAME'S MODES go through the requests: entering a mode asks or stops asking for "mode",
#      and a sheet that still holds the old Set Game Paused policy reads back the same.
#   7. THE FAMILIAR NAMES find them.
@tool
class_name PauseRequestsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "pause_requests_test"


static func run() -> bool:
	# The set lives on the Engine for the life of the process, so it is cleared before and after - a
	# test that left a request behind would hand the next one a game that thinks it is paused.
	_clear_shared_set()
	var ok: bool = _the_rows()
	ok = _what_the_file_says() and ok
	ok = _one_set_for_the_whole_game() and ok
	ok = _what_comes_back() and ok
	ok = _the_readings() and ok
	ok = _the_game_modes() and ok
	ok = _the_familiar_names() and ok
	_clear_shared_set()
	return ok


static func _the_rows() -> bool:
	return SUPPORT.pins(P, [
		["Ask To Pause", _row_text("AskToPause"),
			"action|Ask To Pause|Scene|reason|_pause_requests[&{reason}] = true\nget_tree().paused = true|Ask the game to pause for {reason}"],
		["Stop Asking To Pause", _row_text("StopAskingToPause"),
			"action|Stop Asking To Pause|Scene|reason|_pause_requests.erase(&{reason})\nget_tree().paused = not _pause_requests.is_empty()|Stop asking the game to pause for {reason}"],
		["Pause Requested By", _row_text("PauseRequestedBy"),
			"condition|Pause Requested By|Scene|reason|_pause_requests.has(&{reason})|A pause is requested by {reason}"],
		["the reason starts as a name in quotes", _default("AskToPause", "reason"), "\"inventory\""],
		# The rows beside them, as they shipped.
		["Pause The Game", _row_text("PauseGame"), "action|Pause The Game|Scene||get_tree().paused = true|Pause the game"],
		["Unpause", _row_text("UnpauseGame"), "action|Unpause|Scene||get_tree().paused = false|Unpause"],
		["Set Game Paused", _row_text("SetPaused"), "action|Set Game Paused|Scene|paused|get_tree().paused = {paused}|Set paused to {paused}"],
		["Is Game Paused", _row_text("IsPaused"), "condition|Is Game Paused|Scene||get_tree().paused|Game is paused"],
		["the frozen-node question keeps its own name",
			_row_text("NodeIsPausedByGame").get_slice("|", 1), "Node Is Frozen By The Game Pause"],
	])


## The sheet every block below compiles: one event asking, then stopping, then asking a question.
const COMPILED: String = "extends Node\n\nstatic var _pause_requests: Dictionary = __eventsheets_pause_requests()\n\nfunc _ready() -> void:\n\t_pause_requests[&\"inventory\"] = true\n\tget_tree().paused = true\n\t_pause_requests.erase(&\"inventory\")\n\tget_tree().paused = not _pause_requests.is_empty()\n\tif _pause_requests.has(&\"dialogue\"):\n\t\tprint(\"still\")\n\nstatic func __eventsheets_pause_requests() -> Dictionary:\n\tif not Engine.has_meta(&\"pause_requests\"):\n\t\tEngine.set_meta(&\"pause_requests\", {})\n\treturn Engine.get_meta(&\"pause_requests\")\n"


static func _what_the_file_says() -> bool:
	var rows: Array = []
	var output: String = _compiled()
	rows.append(["the whole file", output, COMPILED])
	var parsed: GDScript = GDScript.new()
	parsed.source_code = output
	rows.append(["it parses", parsed.reload(), OK])
	var twice: String = str(SheetCompiler.compile(_sheet([_action("AskToPause", {}), _action("AskToPause", {"reason": "\"menu\""})]),
		"user://pause_requests_twice.gd", true).get("output", ""))
	rows.append(["two rows still declare the set once", [twice.count("static var _pause_requests"), twice.count("static func __eventsheets_pause_requests(")], [1, 1]])
	var plain: String = str(SheetCompiler.compile(_sheet([_action("PauseGame", {})]), "user://pause_requests_plain.gd", true).get("output", ""))
	rows.append(["a file that only pauses gains nothing", plain.contains("_pause_requests"), false])
	var verbatim: RawCodeRow = RawCodeRow.new()
	verbatim.code = "print(_pause_requests)"
	var kept: EventSheetResource = _sheet([])
	kept.events.append(verbatim)
	rows.append(["a read inside a verbatim block is not a row asking",
		str(SheetCompiler.compile(kept, "user://pause_requests_verbatim.gd", true).get("output", "")).contains("static var _pause_requests"), false])
	return SUPPORT.pins(P, rows)


## Two scripts, loaded separately, each with its own copy of the set's declaration: what one asks,
## the other sees. The tree's switch is a plain member here, because a test has no running tree.
static func _one_set_for_the_whole_game() -> bool:
	var rows: Array = []
	var inventory: Object = _runner()
	var dialogue: Object = _runner()
	if inventory == null or dialogue == null:
		return SUPPORT.check(P, "both runners load", [inventory != null, dialogue != null], [true, true])
	inventory.call("ask", "inventory")
	rows.append(["the inventory asks, and the game pauses", inventory.get("paused"), true])
	dialogue.call("ask", "dialogue")
	rows.append(["the dialogue script sees the inventory's request", dialogue.call("requested", "inventory"), true])
	inventory.call("stop", "inventory")
	rows.append(["the inventory stops asking, and the dialogue still holds it paused", inventory.get("paused"), true])
	rows.append(["the inventory's request is gone", [inventory.call("requested", "inventory"), dialogue.call("requested", "inventory")], [false, false]])
	rows.append(["the dialogue's is not", inventory.call("requested", "dialogue"), true])
	dialogue.call("stop", "dialogue")
	rows.append(["the last one to stop asking unpauses it", dialogue.get("paused"), false])
	rows.append(["and the set is empty", (Engine.get_meta(&"pause_requests", {}) as Dictionary).is_empty(), true])
	return SUPPORT.pins(P, rows)


static func _what_comes_back() -> bool:
	var rows: Array = []
	rows.append(["the compiled file's events reopen as the three rows", _lifted_ids(COMPILED, false),
		PackedStringArray(["AskToPause", "StopAskingToPause", "PauseRequestedBy", "PrintLog"])])
	rows.append(["and re-emits byte for byte", SUPPORT.reemit(COMPILED, "user://pause_requests_roundtrip.gd"), COMPILED])
	var typed: String = "extends Node\n\nvar _pause_requests := {}\n\nfunc _on_inventory_opened() -> void:\n\t_pause_requests[&\"inventory\"] = true\n\tget_tree().paused = true\n\nfunc _on_inventory_closed() -> void:\n\t_pause_requests.erase(&\"inventory\")\n\tget_tree().paused = not _pause_requests.is_empty()\n"
	var typed_ids: PackedStringArray = _lifted_ids(typed)
	rows.append(["the pair typed by hand reads as the requests, never as Set Paused",
		[typed_ids.has("AskToPause"), typed_ids.has("StopAskingToPause"), typed_ids.has("PauseGame"), typed_ids.has("SetPaused")],
		[true, true, false, false]])
	rows.append(["and re-emits byte for byte, its own declaration left as it was", SUPPORT.reemit(typed, "user://pause_requests_typed.gd"), typed])
	var lone: String = "extends Node\n\nfunc _ready() -> void:\n\tget_tree().paused = true\n"
	rows.append(["a lone pause keeps the row it always had", _lifted_ids(lone), PackedStringArray(["PauseGame"])])
	rows.append(["and re-emits byte for byte", SUPPORT.reemit(lone, "user://pause_requests_lone.gd"), lone])
	return SUPPORT.pins(P, rows)


static func _the_readings() -> bool:
	var sheet: EventSheetResource = SUPPORT.reopen(COMPILED)
	if sheet == null:
		return SUPPORT.check(P, "the compiled file reopens", false, true)
	sheet.read_only = true
	var readings: PackedStringArray = _readings_of(sheet)
	return SUPPORT.pins(P, [
		["asking reads as the request", _holding(readings, "Ask the game"), "Ask the game to pause for \"inventory\""],
		["stopping reads as taking it back", _holding(readings, "Stop asking"), "Stop asking the game to pause for \"inventory\""],
		["the question reads as a question about the request", _holding(readings, "requested by"), "A pause is requested by \"dialogue\""],
		["and nothing reads as a frozen node", _holding(readings, "rozen"), ""],
		["no line reads as the plain switch", [_holding(readings, "Pause the game"), _holding(readings, "Set paused")], ["", ""]],
	])


static func _the_game_modes() -> bool:
	var rows: Array = []
	var sheet: EventSheetResource = EventSheetResource.new()
	EventSheetModesDialog.write(sheet, PackedStringArray(["Playing", "Paused"]), "Playing",
		{"Paused": {"physics": false, "mouse": true}})
	rows.append(["entering Paused asks for \"mode\"", _policy_rows(sheet, "Paused"),
		["AskToPause {\"reason\":\"\\\"mode\\\"\"}", "MouseCursorVisible {}"]])
	rows.append(["entering Playing stops asking for \"mode\"", _policy_rows(sheet, "Playing"),
		["StopAskingToPause {\"reason\":\"\\\"mode\\\"\"}", "MouseCursorVisible {}"]])
	rows.append(["the policy reads back as it was written", EventSheetModesDialog.read_policy(sheet),
		{"Playing": {"physics": true, "mouse": true}, "Paused": {"physics": false, "mouse": true}}])
	var output: String = SUPPORT.compile_output(sheet, "user://pause_requests_modes.gd")
	rows.append(["the mode change goes through the requests",
		[output.contains("\t\t_pause_requests[&\"mode\"] = true\n\t\tget_tree().paused = true\n"),
			output.contains("\t\t_pause_requests.erase(&\"mode\")\n\t\tget_tree().paused = not _pause_requests.is_empty()\n"),
			output.contains("get_tree().paused = false"), output.contains("static var _pause_requests: Dictionary")],
		[true, true, false, true]])
	var parsed: GDScript = GDScript.new()
	parsed.source_code = output
	rows.append(["and the file parses", parsed.reload(), OK])
	rows.append(["and reopens as the requests", [_lifted_ids(output).has("AskToPause"), _lifted_ids(output).has("StopAskingToPause")], [true, true]])
	rows.append(["byte for byte", SUPPORT.reemit(output, "user://pause_requests_modes_roundtrip.gd"), output])
	# A sheet saved when the dialog still wrote Set Game Paused: read back as the same policy, and the
	# next write replaces the switch with the request rather than writing both.
	var older: EventSheetResource = EventSheetResource.new()
	EventSheetModesDialog.write(older, PackedStringArray(["Playing", "Paused"]), "Playing",
		{"Paused": {"physics": false, "mouse": true}})
	for word: String in ["Playing", "Paused"]:
		var event_row: EventRow = _policy_event(older, word)
		if event_row != null and not event_row.actions.is_empty():
			var legacy: ACEAction = _action("SetPaused", {"paused": "true" if word == "Paused" else "false"})
			event_row.actions[0] = legacy
	rows.append(["the old Set Game Paused policy reads back the same", EventSheetModesDialog.read_policy(older),
		{"Playing": {"physics": true, "mouse": true}, "Paused": {"physics": false, "mouse": true}}])
	EventSheetModesDialog.write(older, PackedStringArray(["Playing", "Paused"]), "Playing", EventSheetModesDialog.read_policy(older))
	rows.append(["and is replaced by the request on the next write", _policy_rows(older, "Paused"),
		["AskToPause {\"reason\":\"\\\"mode\\\"\"}", "MouseCursorVisible {}"]])
	# The same old line opened from a `.gd` reads as Pause The Game and Unpause: the same policy again.
	for word: String in ["Playing", "Paused"]:
		var event_row: EventRow = _policy_event(older, word)
		if event_row != null and not event_row.actions.is_empty():
			event_row.actions[0] = _action("PauseGame" if word == "Paused" else "UnpauseGame", {})
	rows.append(["opened from a file, Pause The Game and Unpause read back the same", EventSheetModesDialog.read_policy(older),
		{"Playing": {"physics": true, "mouse": true}, "Paused": {"physics": false, "mouse": true}}])
	EventSheetModesDialog.write(older, PackedStringArray(["Playing", "Paused"]), "Playing", EventSheetModesDialog.read_policy(older))
	rows.append(["and are replaced by the requests too", [_policy_rows(older, "Playing"), _policy_rows(older, "Paused")],
		[["StopAskingToPause {\"reason\":\"\\\"mode\\\"\"}", "MouseCursorVisible {}"], ["AskToPause {\"reason\":\"\\\"mode\\\"\"}", "MouseCursorVisible {}"]]])
	return SUPPORT.pins(P, rows)


static func _the_familiar_names() -> bool:
	return SUPPORT.pins(P, [
		["Time.timeScale", ACEPickerDialog.foreign_query_matches("Time.timeScale"),
			{"PauseGame": "Time.timeScale", "AskToPause": "Time.timeScale"}],
		["Pause Counter", ACEPickerDialog.foreign_query_matches("pause counter"),
			{"AskToPause": "Pause Counter", "StopAskingToPause": "Pause Counter", "PauseRequestedBy": "Pause Counter"}],
		["Request Pause", ACEPickerDialog.foreign_query_matches("request pause"), {"AskToPause": "Request Pause"}],
		["Release Pause", ACEPickerDialog.foreign_query_matches("release pause"), {"StopAskingToPause": "Release Pause"}],
		["Is Pause Requested", ACEPickerDialog.foreign_query_matches("is pause requested"), {"PauseRequestedBy": "Is Pause Requested"}],
	])


# ── helpers ──────────────────────────────────────────────────────────────────────────────────


static func _clear_shared_set() -> void:
	if Engine.has_meta(&"pause_requests"):
		Engine.remove_meta(&"pause_requests")


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


## A template with the given values and every other field on its default.
static func _filled(ace_id: String, values: Dictionary) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	var filled: Dictionary = {}
	for parameter: ACEParam in descriptor.params:
		filled[str(parameter.id)] = str(parameter.default_value)
	filled.merge(values, true)
	return ActionCodegen._apply_template(descriptor.codegen_template, filled)


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


static func _sheet(actions: Array) -> EventSheetResource:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	for action: Variant in actions:
		event.actions.append(action)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(event)
	return sheet


## The sheet the file above is: ask, stop, and a sub-event asking the question.
static func _compiled() -> String:
	var sheet: EventSheetResource = _sheet([_action("AskToPause", {}), _action("StopAskingToPause", {})])
	var question: ACECondition = ACECondition.new()
	question.provider_id = "Core"
	question.ace_id = "PauseRequestedBy"
	question.codegen_template = ACERegistry.find_descriptor("Core", "PauseRequestedBy").codegen_template
	question.params = {"reason": "\"dialogue\""}
	var inner: EventRow = EventRow.new()
	inner.conditions.append(question)
	inner.actions.append(_action("PrintLog", {"message": "\"still\""}))
	(sheet.events[0] as EventRow).sub_events.append(inner)
	return str(SheetCompiler.compile(sheet, "user://pause_requests.gd", true).get("output", ""))


## A script that asks, stops and asks the question through the rows' own lines, with the set declared
## and made exactly as the compiled file declares and makes it. The tree's switch is the member
## `paused`, the one word swapped, because a test runs before any tree exists.
static func _runner() -> Object:
	var asking: String = _filled("AskToPause", {"reason": "\"__R__\""}).replace("get_tree().paused", "paused").replace("&\"__R__\"", "StringName(reason)")
	var stopping: String = _filled("StopAskingToPause", {"reason": "\"__R__\""}).replace("get_tree().paused", "paused").replace("&\"__R__\"", "StringName(reason)")
	var asked: String = _filled("PauseRequestedBy", {"reason": "\"__R__\""}).replace("&\"__R__\"", "StringName(reason)")
	var declared: PackedStringArray = PackedStringArray()
	var inside_helper: bool = false
	for line: String in COMPILED.split("\n"):
		if line.begins_with("static var _pause_requests"):
			declared.append(line)
		elif line.begins_with("static func __eventsheets_pause_requests("):
			inside_helper = true
			declared.append(line)
		elif inside_helper and line.begins_with("\t"):
			declared.append(line)
		else:
			inside_helper = false
	var source: String = "extends RefCounted\n\nvar paused: bool = false\n%s\n\n\nfunc ask(reason: String) -> void:\n\t%s\n\n\nfunc stop(reason: String) -> void:\n\t%s\n\n\nfunc requested(reason: String) -> bool:\n\treturn %s\n" % [
		"\n".join(declared), asking.replace("\n", "\n\t"), stopping.replace("\n", "\n\t"), asked]
	var script: GDScript = GDScript.new()
	script.source_code = source
	if script.reload() != OK or not script.can_instantiate():
		return null
	return script.new()


static func _policy_event(sheet: EventSheetResource, word: String) -> EventRow:
	var member: String = EventSheetModeFacts.member_for(word)
	for entry: Variant in sheet.events:
		var event_row: EventRow = entry as EventRow
		if event_row != null and event_row.trigger_id == EventSheetModeFacts.ENTERING_TRIGGER_ID \
				and str(event_row.trigger_params.get(EventSheetModeFacts.MODE_PARAM, "")) == member:
			return event_row
	return null


## A mode's On entering rows as "ace_id params", in order.
static func _policy_rows(sheet: EventSheetResource, word: String) -> Array:
	var said: Array = []
	var event_row: EventRow = _policy_event(sheet, word)
	if event_row == null:
		return said
	for action: Variant in event_row.actions:
		if action is ACEAction:
			said.append("%s %s" % [(action as ACEAction).ace_id, JSON.stringify((action as ACEAction).params)])
	return said


## The ace_ids every condition and action of a reopened source lifted to, walking sub-events and the
## bodies of the file's own functions too.
static func _lifted_ids(source: String, with_functions: bool = true) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var reopened: EventSheetResource = SUPPORT.reopen(source)
	if reopened != null:
		for item: Variant in reopened.events:
			_collect_ids(item, found)
		for function: Variant in reopened.functions if with_functions else []:
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


## Every cell of every row, through a real viewport - the same walk the reading dump makes.
static func _readings_of(sheet: EventSheetResource) -> PackedStringArray:
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var out: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		for span: SemanticSpan in row_data.spans:
			var text: String = span.text.strip_edges()
			if not text.is_empty():
				out.append(text)
	viewport.free()
	return out


static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


## The first reading holding this text, or "" - so a pin names the sentence rather than a position.
static func _holding(readings: PackedStringArray, wanted: String) -> String:
	for text: String in readings:
		if text.contains(wanted):
			return text
	return ""
