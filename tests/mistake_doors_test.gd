# Godot EventSheets - every door on a mistake check, walked on a real dock.
#
# A door is a step the reader could take by hand, taken for them through the one undo funnel. Each pin
# presses the door on the row that earned it and reads what the sheet then compiles to: the mistake is
# gone, the file is plain GDScript Godot loads, and it opens back byte for byte. The doors that only open
# something (a dialog, a row) are pinned by what they ask the dock to do.
@tool
class_name MistakeDoorsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const ROWS := preload("res://tests/mistake_rows_test.gd")
const TEST_NAME: String = "mistake_doors"
const LEVEL := "res://tests/fixtures/mistake_rows_level.gd"

const SOURCE := "extends Node2D\n\nsignal hit(damage: int)\nsignal shout(word: String)\n\nvar lives: int = 3\nvar score: int = 0\nvar health: int = 3\n\n\nfunc go() -> void:\n\thit.emit()\n\n\nfunc too_many() -> void:\n\tshout.emit(\"a\", 2)\n\n\nfunc spawn_it() -> void:\n\tload(\"res://tests/fixtures/mistake_bos.gd\")\n\n\nfunc grind() -> void:\n\twhile lives > 0:\n\t\tscore += 1\n\n\nfunc zero() -> void:\n\tscore = score / 0\n\n\nfunc hides() -> void:\n\tvar health: int = 0\n\thealth += 10\n"


static func run() -> bool:
	ROWS._put_the_fixture_back()
	var ok: bool = true
	ok = _emit_doors() and ok
	ok = _path_door() and ok
	ok = _while_doors() and ok
	ok = _stop_after_on_a_triggered_event() and ok
	ok = _handler_doors() and ok
	ok = _local_doors() and ok
	ok = _zero_door() and ok
	ok = _trigger_lane_door() and ok
	ok = _a_door_pressed_after_an_edit_finds_the_live_row() and ok
	ok = _a_local_is_not_a_member_the_node_lacks() and ok
	ok = _a_wrong_kind_on_the_row() and ok
	ok = _a_written_sheet_offers_its_variables() and ok
	ROWS._put_the_fixture_back()
	ok = _doctor_offers() and ok
	ROWS._put_the_fixture_back()
	return ok


static func _dock(source: String = SOURCE) -> EventSheetDock:
	EventSheetMistakeFindings.clear_cache()
	var sheet: EventSheetResource = SUPPORT.reopen(source, true, LEVEL)
	sheet.external_source_path = LEVEL
	return ROWS._dock_of(sheet)


static func _labels(row: EventRowData) -> Array:
	var labels: Array = []
	if row == null or row.attention_findings.is_empty():
		return labels
	var finding: Dictionary = row.attention_findings[0]
	for key: String in ["fix_label", "second_fix_label", "third_fix_label"]:
		if not str(finding.get(key, "")).is_empty():
			labels.append(str(finding[key]))
	return labels


## The sheet as it now compiles, and whether Godot loads that text.
static func _compiled(dock: EventSheetDock) -> String:
	return SUPPORT.compile_output(dock._current_sheet, "")


static func _loads(source: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload(true) == OK


static func _kinds(dock: EventSheetDock) -> Array:
	var kinds: Array = []
	for finding: Dictionary in EventSheetMistakeFindings.findings(dock._current_sheet, LEVEL):
		kinds.append(finding["kind"])
	return kinds


static func _press(dock: EventSheetDock, kind: String, which: int) -> void:
	var row: EventRowData = ROWS._stamped(dock, kind)
	dock._update_row_help_strip(row)
	match which:
		0:
			dock.apply_selected_row_fix()
		1:
			dock.apply_selected_row_second_fix()
		2:
			dock.apply_selected_row_third_fix()


static func _emit_doors() -> bool:
	var dock: EventSheetDock = _dock()
	var missing: EventRowData = ROWS._stamped(dock, "signal-emit-value-count")
	var labels: Array = _labels(missing)
	_press(dock, "signal-emit-value-count", 0)
	var compiled: String = _compiled(dock)
	var left: EventRowData = ROWS._stamped(dock, "signal-emit-value-count")
	var extra_labels: Array = _labels(left)
	_press(dock, "signal-emit-value-count", 0)
	var after_extra: String = _compiled(dock)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a missing value offers to add it, and the signal's own row", labels, ["Add damage", "Open the signal"]],
		["the value is the type's plain empty one, since nothing here is called damage", compiled.contains("hit.emit(0)"), true],
		["an extra value offers to remove it", extra_labels, ["Remove the extra value", "Open the signal"]],
		["and removes only that", after_extra.contains("shout.emit(\"a\")"), true],
		["both findings are gone", _kinds(dock).has("signal-emit-value-count"), false],
	])
	dock.free()
	var named: EventSheetDock = _dock("extends Node2D\n\nsignal hit(damage: int)\n\n\nfunc go(damage: int) -> void:\n\thit.emit()\n")
	_press(named, "signal-emit-value-count", 0)
	ok = SUPPORT.pins(TEST_NAME, [["a name in scope is what it sends", _compiled(named).contains("hit.emit(damage)"), true]]) and ok
	var opened: EventSheetDock = _dock()
	_press(opened, "signal-emit-value-count", 1)
	var selected: EventRowData = opened._viewport._row_at(opened._viewport._selected_row_index)
	ok = SUPPORT.pins(TEST_NAME, [["Open the signal goes to its declaring row", selected != null and selected.source_resource is SignalRow, true]]) and ok
	opened.free()
	named.free()
	return ok


static func _path_door() -> bool:
	var dock: EventSheetDock = _dock()
	var row: EventRowData = ROWS._stamped(dock, "path-not-in-project")
	var labels: Array = _labels(row)
	_press(dock, "path-not-in-project", 0)
	var compiled: String = _compiled(dock)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a missing file offers its closest and a picker", labels, ["Use res://tests/fixtures/mistake_boss.gd", "Pick a file..."]],
		["the door writes the closest file", compiled.contains("load(\"res://tests/fixtures/mistake_boss.gd\")"), true],
		["the finding is gone", _kinds(dock).has("path-not-in-project"), false],
	])
	dock.free()
	var preload_dock: EventSheetDock = _dock("extends Node2D\n\nconst BOSS := preload(\"res://tests/fixtures/mistake_bos.gd\")\nvar what = load(\"res://tests/fixtures/mistake_bos.gd\")\n")
	var found: Array[Dictionary] = EventSheetMistakeFindings.findings(preload_dock._current_sheet, LEVEL)
	var door: Dictionary = {}
	for finding: Dictionary in found:
		if finding["kind"] == "path-not-in-project":
			door = finding
			break
	var has_door: bool = str(door.get("fix_label", "")).begins_with("Use ")
	EventSheetMistakeFixes.apply(preload_dock, door, "fix")
	var after: String = _compiled(preload_dock)
	ok = SUPPORT.pins(TEST_NAME, [
		["a row that declares the path has the door too", has_door, true],
		["and the door writes it there", after.contains("mistake_boss.gd"), true],
	]) and ok
	preload_dock.free()
	return ok


static func _while_doors() -> bool:
	var ok: bool = true
	var dock: EventSheetDock = _dock()
	var labels: Array = _labels(ROWS._stamped(dock, "while-never-ends"))
	_press(dock, "while-never-ends", 0)
	var added: String = _compiled(dock)
	ok = SUPPORT.pins(TEST_NAME, [
		["the three doors the board names, in its order", labels, ["Add: Subtract 1 from lives", "Stop after 1000 rounds", "Make it an If"]],
		["the change is a row inside the loop", added.contains("\twhile lives > 0:\n\t\tscore += 1\n\t\tlives -= 1"), true],
		["which ends the finding", _kinds(dock).has("while-never-ends"), false],
	]) and ok
	dock.free()
	var made_if: EventSheetDock = _dock()
	_press(made_if, "while-never-ends", 2)
	var if_text: String = _compiled(made_if)
	ok = SUPPORT.pins(TEST_NAME, [
		["Make it an If writes an if", if_text.contains("\tif lives > 0:\n\t\tscore += 1"), true],
		["and no loop is left", if_text.contains("while lives"), false],
		["and the finding is gone", _kinds(made_if).has("while-never-ends"), false],
	]) and ok
	made_if.free()
	var rising: EventSheetDock = _dock("extends Node2D\n\nvar lives: int = 3\nvar score: int = 0\n\n\nfunc grind() -> void:\n\twhile lives < 9:\n\t\tscore += 1\n")
	ok = SUPPORT.pins(TEST_NAME, [["a loop that climbs offers to add", _labels(ROWS._stamped(rising, "while-never-ends"))[0], "Add: Add 1 to lives"]]) and ok
	rising.free()
	ok = SUPPORT.pins(TEST_NAME, [
		["a method of the node itself can change what the loop reads", EventSheetMistakeFindings.loop_cannot_end("position.x < 9.0", "move_and_slide()", {}, "CharacterBody2D"), false],
		["so can any call under a host Godot does not know", EventSheetMistakeFindings.loop_cannot_end("lives > 0", "take_damage()", {}, "ProjectHero"), false],
		["a language function cannot", EventSheetMistakeFindings.loop_cannot_end("lives > 0", "print(lives)", {}, "ProjectHero"), true],
		["nor a call on another node", EventSheetMistakeFindings.loop_cannot_end("lives > 0", "$Score.hide()", {}, "Node2D"), true],
	]) and ok
	var flagged: EventSheetDock = _dock("extends Node2D\n\nvar running: bool = true\nvar score: int = 0\n\n\nfunc grind() -> void:\n\twhile running:\n\t\tscore += 1\n")
	ok = SUPPORT.pins(TEST_NAME, [["a condition with no number has no change door", _labels(ROWS._stamped(flagged, "while-never-ends")), ["Stop after 1000 rounds", "Make it an If"]]]) and ok
	flagged.free()
	return ok


## An event with a trigger and a condition has no line above its loop, so the guard opens one: the
## trigger and the conditions stay, the counter is their first action, the loop and its body become the
## sub-event under it.
static func _stop_after_on_a_triggered_event() -> bool:
	var dock: EventSheetDock = _dock("extends Node2D\n\nsignal game_over\n\nvar lives: int = 3\nvar score: int = 0\nvar armed: bool = true\n")
	var sheet: EventSheetResource = dock._current_sheet
	var event_row: EventRow = EventRow.new()
	event_row.event_uid = "guarded"
	event_row.trigger_id = "signal:game_over"
	var gate: ACECondition = ACECondition.new()
	gate.provider_id = "Core"
	gate.ace_id = "ExpressionIsTrue"
	gate.params = {"expr": "armed"}
	event_row.conditions.append(gate)
	var loop: PickFilter = PickFilter.new()
	loop.collection_kind = PickFilter.CollectionKind.WHILE
	loop.collection_value = "lives > 0"
	event_row.pick_filters.append(loop)
	var step: ACEAction = ACEAction.new()
	step.provider_id = "Core"
	step.ace_id = "AddVar"
	step.params = {"var_name": "score", "amount": "1"}
	event_row.actions.append(step)
	sheet.events.append(event_row)
	dock._refresh_after_edit()
	var found: Array[Dictionary] = EventSheetMistakeFindings.findings(sheet, LEVEL)
	var door: Dictionary = {}
	for finding: Dictionary in found:
		if finding["kind"] == "while-never-ends":
			door = finding
	var door_offered: bool = str(door.get("second_fix_label", "")) == "Stop after 1000 rounds"
	EventSheetMistakeFixes.apply(dock, door, "second_fix")
	var text: String = _compiled(dock)
	var shape: bool = text.contains("\tif armed:\n\t\tvar rounds := 0\n\t\twhile lives > 0 and rounds < 1000:\n\t\t\trounds += 1\n\t\t\tscore += 1")
	var result: bool = SUPPORT.pins(TEST_NAME, [
		["the door is offered on an event with a trigger and a condition", door_offered, true],
		["the counter stands before the loop, inside the condition", shape, true],
		["Godot loads it", _loads(text), true],
		["it opens back byte for byte", SUPPORT.reemit(text, "user://mistake_doors_guard.gd"), text],
		["the finding is gone", _kinds(dock).has("while-never-ends"), false],
	])
	if not shape:
		print(text)
	dock.free()
	return result


static func _handler_doors() -> bool:
	var dock: EventSheetDock = _dock("extends Node2D\n\nsignal hit(damage: int)\n\nvar health: int = 3\n")
	var sheet: EventSheetResource = dock._current_sheet
	var handler: EventRow = EventRow.new()
	handler.event_uid = "handler"
	handler.trigger_id = "signal:hit"
	handler.trigger_args = "damage, source"
	var step: ACEAction = ACEAction.new()
	step.provider_id = "Core"
	step.ace_id = "SubtractVar"
	step.params = {"var_name": "health", "amount": "damage"}
	handler.actions.append(step)
	sheet.events.append(handler)
	dock._refresh_after_edit()
	var labels: Array = _labels(ROWS._stamped(dock, "signal-handler-value-count"))
	_press(dock, "signal-handler-value-count", 0)
	var live: EventRow = sheet.events[sheet.events.size() - 1] as EventRow
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a handler that takes one too many offers both ways out", labels, ["Drop source", "Add source to the signal"]],
		["Drop takes it off the handler", (dock._current_sheet.events[dock._current_sheet.events.size() - 1] as EventRow).trigger_args, "damage"],
		["the finding is gone", _kinds(dock).has("signal-handler-value-count"), false],
		["the live event is what changed", live != null, true],
	])
	dock.free()
	var widen: EventSheetDock = _dock("extends Node2D\n\nsignal hit(damage: int)\n")
	var handler_two: EventRow = EventRow.new()
	handler_two.event_uid = "handler2"
	handler_two.trigger_id = "signal:hit"
	handler_two.trigger_args = "damage, source: Node"
	widen._current_sheet.events.append(handler_two)
	widen._refresh_after_edit()
	_press(widen, "signal-handler-value-count", 1)
	var declared: PackedStringArray = PackedStringArray()
	for entry: Variant in widen._current_sheet.events:
		if entry is SignalRow:
			declared = (entry as SignalRow).params
	ok = SUPPORT.pins(TEST_NAME, [
		["Add to the signal writes the parameter as the handler spells it", Array(declared), ["damage: int", "source: Node"]],
		["and the handler is fine now", _kinds(widen).has("signal-handler-value-count"), false],
	]) and ok
	widen.free()
	var used: EventSheetDock = _dock("extends Node2D\n\nsignal hit(damage: int)\n\nvar health: int = 3\n")
	var handler_used: EventRow = EventRow.new()
	handler_used.event_uid = "handler3"
	handler_used.trigger_id = "signal:hit"
	handler_used.trigger_args = "damage, source"
	var reads: ACEAction = ACEAction.new()
	reads.provider_id = "Core"
	reads.ace_id = "SubtractVar"
	reads.params = {"var_name": "health", "amount": "source.power"}
	handler_used.actions.append(reads)
	used._current_sheet.events.append(handler_used)
	used._refresh_after_edit()
	ok = SUPPORT.pins(TEST_NAME, [["a value the body reads is not offered for dropping", _labels(ROWS._stamped(used, "signal-handler-value-count")), ["Add source to the signal"]]]) and ok
	used.free()
	return ok


static func _local_doors() -> bool:
	var dock: EventSheetDock = _dock()
	var labels: Array = _labels(ROWS._stamped(dock, "local-hides-variable"))
	_press(dock, "local-hides-variable", 0)
	var renamed: String = _compiled(dock)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["the two doors the board names", labels, ["Rename the local to round_health", "Remove the local (use the sheet's health)"]],
		["Rename follows every use in the event", renamed.contains("\tvar round_health: int = 0\n\tround_health += 10"), true],
		["and leaves the sheet's own variable", renamed.contains("var health: int = 3"), true],
		["the finding is gone", _kinds(dock).has("local-hides-variable"), false],
	])
	dock.free()
	var removing: EventSheetDock = _dock()
	_press(removing, "local-hides-variable", 1)
	var removed: String = _compiled(removing)
	ok = SUPPORT.pins(TEST_NAME, [
		["Remove leaves the uses on the sheet's variable", removed.contains("func hides() -> void:\n\thealth += 10"), true],
		["and Godot loads the sheet that is left, the door's own part of it", removed.contains("var health: int = 0"), false],
	]) and ok
	removing.free()
	var taken: EventSheetDock = _dock("extends Node2D\n\nvar health: int = 3\nvar round_health: int = 1\n\n\nfunc hides() -> void:\n\tvar health: int = 0\n\thealth += 10\n")
	ok = SUPPORT.pins(TEST_NAME, [["a name already taken is not offered", _labels(ROWS._stamped(taken, "local-hides-variable"))[0], "Rename the local to round_health_2"]]) and ok
	taken.free()
	var parameter: EventSheetDock = _dock("extends Node2D\n\nsignal hit(amount: int)\n")
	var handler: EventRow = EventRow.new()
	handler.event_uid = "shadow"
	handler.trigger_id = "signal:hit"
	handler.trigger_args = "amount"
	var local: LocalVariable = LocalVariable.new()
	local.name = "amount"
	local.type_name = "int"
	local.default_value = 0
	handler.local_variables.append(local)
	parameter._current_sheet.events.append(handler)
	parameter._refresh_after_edit()
	ok = SUPPORT.pins(TEST_NAME, [["a local named like the value its trigger hands it is the parse error it is", _kinds(parameter).has("local-hides-parameter"), true]]) and ok
	parameter.free()
	return ok


static func _zero_door() -> bool:
	var dock: EventSheetDock = _dock()
	var result: bool = SUPPORT.pins(TEST_NAME, [
		["a division by a literal zero offers the value", _labels(ROWS._stamped(dock, "divide-by-literal-zero")), ["Open the value"]],
	])
	dock.free()
	return result


## A control named by the trigger lives in the event's trigger parameters: the door must reach them.
static func _trigger_lane_door() -> bool:
	var dock: EventSheetDock = _dock("extends Node2D\n\n\nfunc _unhandled_input(event: InputEvent) -> void:\n\tif event.is_action_pressed(\"ui_lef\"):\n\t\tprint(1)\n")
	var kinds_before: Array = _kinds(dock)
	_press(dock, "input-action-not-in-map", 0)
	var text: String = _compiled(dock)
	var result: bool = SUPPORT.pins(TEST_NAME, [
		["the misspelt control is found", kinds_before.has("input-action-not-in-map"), true],
		["Use writes the right name", text.contains("\"ui_left\""), true],
		["and the finding is gone", _kinds(dock).has("input-action-not-in-map"), false],
	])
	dock.free()
	return result


## A hand-written `amount = 2` on a local reads like a verb's "set amount"; it asks the node for nothing.
static func _a_local_is_not_a_member_the_node_lacks() -> bool:
	var sheet: EventSheetResource = SUPPORT.reopen("extends Node\n\n\nfunc grow(level: int) -> float:\n\tvar amount: float = 1.0\n\tamount = amount * level\n\treturn amount\n", true, LEVEL)
	sheet.external_source_path = LEVEL
	var kinds: Array = []
	for finding: Dictionary in EventSheetMistakeFindings.findings(sheet, LEVEL):
		kinds.append(finding["kind"])
	return SUPPORT.pins(TEST_NAME, [["the local is not called a member of the node", kinds.has("wrong-node-type"), false]])


## The funnel replaces every resource with a snapshot copy, so a finding read before an edit holds rows
## nobody is looking at any more. A door pressed then must find the live row, not write to a ghost.
static func _a_door_pressed_after_an_edit_finds_the_live_row() -> bool:
	var dock: EventSheetDock = _dock()
	var row: EventRowData = ROWS._stamped(dock, "group-nothing-is-in")
	var stale: Dictionary = {}
	for finding: Dictionary in EventSheetMistakeFindings.findings(dock._current_sheet, LEVEL):
		if finding["kind"] == "signal-emit-value-count":
			stale = finding
			break
	dock._perform_undoable_sheet_edit("Unrelated", func() -> bool:
		dock._current_sheet.variables["unrelated"] = {"type": "int", "default": 0}
		return true)
	# The funnel commits its snapshot through the undo manager; force the same replacement a real commit makes.
	dock._current_sheet = dock._current_sheet.duplicate(true)
	dock._refresh_after_edit()
	var done: bool = EventSheetMistakeFixes.apply(dock, stale, "fix")
	var result: bool = SUPPORT.pins(TEST_NAME, [
		["no row of this source is about a group", row == null, true],
		["the door reports it did something", done, true],
		["the live sheet is the one that changed", _compiled(dock).contains("hit.emit(0)"), true],
	])
	dock.free()
	return result


## The check the field runs, asked of every row: the row wears red, the strip has the sentence and Godot's own
## words, the Doctor has the entry, and a right value says nothing at all.
static func _a_wrong_kind_on_the_row() -> bool:
	var source: String = "extends Node2D\n\nvar score: int = 0\nvar speed: float = 1.0\nvar label_text: String = \"\"\n\n\nfunc heal(amount: int) -> void:\n\tscore += amount\n\n\nfunc fine() -> void:\n\tscore = 3\n\tspeed = score * 2\n\tlabel_text = str(score)\n\theal(1)\n\n\nfunc wrong() -> void:\n\tscore = \"10\"\n\n\nfunc wrong_count() -> void:\n\theal(1, 2)\n"
	var dock: EventSheetDock = _dock(source)
	var kinds: Array = []
	var subjects: Array = []
	var words: String = ""
	for finding: Dictionary in EventSheetMistakeFindings.findings(dock._current_sheet, LEVEL):
		kinds.append(finding["kind"])
		if finding["kind"] == EventSheetMistakeFindings.KIND_WRONG_KIND:
			subjects.append(finding["subject"])
			if words.is_empty():
				words = str(finding["message"]) + "|" + str(finding.get("original", ""))
	var row: EventRowData = ROWS._stamped(dock, EventSheetMistakeFindings.KIND_WRONG_KIND)
	var red: bool = row != null and row.attention_severe
	var labels: Array = _labels(row)
	dock._update_row_help_strip(row)
	var hover: String = dock._row_help_label.tooltip_text
	_press(dock, EventSheetMistakeFindings.KIND_WRONG_KIND, 0)
	var after: String = _compiled(dock)
	var after_subjects: Array = []
	for finding: Dictionary in EventSheetMistakeFindings.findings(dock._current_sheet, LEVEL):
		if finding["kind"] == EventSheetMistakeFindings.KIND_WRONG_KIND:
			after_subjects.append(finding["subject"])
	var filed: Array[Dictionary] = EventSheetMistakeChecksDoctor.script_findings(LEVEL,
		EventSheetMistakeFindings.findings(dock._current_sheet, LEVEL), EventSheetResource.margin_numbers(dock._current_sheet))
	var doctor_check: bool = false
	for finding: Dictionary in filed:
		doctor_check = doctor_check or str(finding["check"]) == "value-of-the-wrong-kind"
	var result: bool = SUPPORT.pins(TEST_NAME, [
		["only the two wrong lines are found", subjects, ["score = \"10\"", "heal(1, 2)"]],
		["the sentence is the field's, and Godot's words are kept", words, "score holds a whole number. \"10\" is text. Write a number, or an expression that gives a number.|Cannot assign a value of type \"String\" as \"int\"."],
		["the row is red", red, true],
		["the board's three doors", labels, ["Use 10", "Open the parameters", "Go to score"]],
		["Godot's words are on the strip's hover", hover.contains("Cannot assign a value of type"), true],
		["the door writes the value", after.contains("\tscore = 10\n"), true],
		["and that row stops saying it, at once", after_subjects, ["heal(1, 2)"]],
		["the Doctor has the entry", doctor_check, true],
	])
	dock.free()
	return result


## A sheet opened from a .gd holds its variables as rows. The parameters dialog asks this for its Variable
## dropdown: empty, it read "No variables available" and refused every Set value on the sheet.
static func _a_written_sheet_offers_its_variables() -> bool:
	var dock: EventSheetDock = _dock("extends Node2D\n\nvar score: int = 0\nvar lives: int = 3\n")
	var names: PackedStringArray = dock._variables._collect_sheet_variable_names()
	dock.free()
	return SUPPORT.pins(TEST_NAME, [["the dialog's list holds the variable rows", Array(names), ["lives", "score"]]])


static func _doctor_offers() -> bool:
	EventSheetProjectDoctor.clear_project_scripts()
	var report: Array[Dictionary] = EventSheetMistakeChecksDoctor.report(PackedStringArray(["res://tests/fixtures/mistake_script.gd"]))
	var loop: Dictionary = {}
	for finding: Dictionary in report:
		if str(finding["check"]) == "while-never-ends":
			loop = finding
	var offered: Array = []
	for offer: Dictionary in EventSheetQuickFixes.fixes_for(loop):
		offered.append(offer["label"])
	var chips: Array = []
	for offer: Dictionary in EventSheetProjectDoctorPanel.offers_for(loop):
		chips.append(offer["id"])
	var result: bool = SUPPORT.pins(TEST_NAME, [
		["the Doctor offers the row's own doors", offered, ["Add: Subtract 1 from lives", "Stop after 1000 rounds", "Make it an If"]],
		["and Show row", chips.has("show_row"), true],
	])
	# The Doctor's own finding about a missing control now carries the row that names it.
	var fixture: String = "res://tests/fixtures/mistake_rows_level.gd"
	var file: FileAccess = FileAccess.open(fixture, FileAccess.WRITE)
	file.store_string("extends Node2D\n\n\nfunc _process(delta: float) -> void:\n\tif Input.is_action_pressed(\"ui_lef\"):\n\t\tprint(1)\n")
	file.close()
	EventSheetProjectDoctor.clear_project_scripts()
	var mine: Dictionary = {}
	EventSheetProjectDoctor._address_missing_control(fixture, PackedStringArray(["ui_lef"]), mine)
	result = SUPPORT.pins(TEST_NAME, [
		["the missing control is addressed to its row", int(mine.get("event", 0)) > 0, true],
		["and offers the near name first", str(mine.get("to", "")), "ui_left"],
	]) and result
	return result
