# Godot EventSheets - the Match window and the match on the sheet.
#
# A match is written as parameter rows (a Value, then one row per branch and Otherwise) and lands on
# the sheet as its event's "match state" plus one sub-event per branch - "state is IDLE", "Else" -
# each holding its own actions and its own Add action. Pins: the reading of a lifted match, the Add
# action door filling ONE branch, the window's rows read back from a match, Done adding a new match in
# one undo step, an edit keeping each branch's actions, the duplicate-value refusal, the per-state
# fill, and the file still re-emitting byte for byte.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const NAME := "match_window_test"
const SOURCE := "extends CharacterBody2D\n\nenum State { IDLE, RUN }\n\nvar state: State = State.IDLE\n\n\nfunc _physics_process(delta: float) -> void:\n\tmatch state:\n\t\tState.IDLE:\n\t\t\tvelocity.x = 0.0\n\t\tState.RUN:\n\t\t\tpass\n\t\t_:\n\t\t\tpass\n"


static func run() -> bool:
	var ok: bool = true
	ok = _test_sheet_reading() and ok
	ok = _test_window() and ok
	ok = _test_choices() and ok
	return ok


## What a branch offers, steered by what the Value holds: an enum's members (one nested in a group
## too), true / false for a bool, every enum's Enum.MEMBER when the Value is not a known variable.
static func _test_choices() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var group: EventGroup = EventGroup.new()
	group.group_name = "G"
	var mode_enum: EnumRow = EnumRow.new()
	mode_enum.enum_name = "Mode"
	mode_enum.members = PackedStringArray(["A", "B = 4"])
	group.events.append(mode_enum)
	sheet.events.append(group)
	for pair: Array in [["mode", "Mode"], ["flag", "bool"]]:
		var variable: LocalVariable = LocalVariable.new()
		variable.name = str(pair[0])
		variable.type_name = str(pair[1])
		sheet.events.append(variable)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var dialogs: EventSheetStructRowDialogs = dock._struct_rows
	dialogs._ensure_match_dialog()
	var match_row: MatchRow = MatchRow.new()
	match_row.match_expression = "mode"
	dialogs._populate_match_dialog(match_row)
	var answers: Array = [dialogs._match_pattern_choices()]
	dialogs._fill_cases_from_subject()
	dialogs._fill_cases_from_subject()
	answers.append(dialogs._match_case_rows.size())
	answers.append(dialogs._match_patterns())
	dialogs._match_expression_edit.text = "flag"
	answers.append(dialogs._match_pattern_choices())
	dialogs._match_expression_edit.text = "speed * 2"
	answers.append(dialogs._match_pattern_choices())
	dock.free()
	return SUPPORT.pins(NAME, [
		["an enum in a group offers its members, the = 4 dropped", answers[0], ["A", "B"]],
		["filling twice adds each member once", answers[1], 2],
		["the members are written with their enum's name", answers[2], PackedStringArray(["Mode.A", "Mode.B", "_"])],
		["a bool offers true and false", answers[3], ["true", "false"]],
		["any other Value offers every enum's members by their full names", answers[4], ["Mode.A", "Mode.B"]],
	])


static func _test_sheet_reading() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(SOURCE)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var head_texts: PackedStringArray = PackedStringArray()
	var tick_cells: Array = []
	var case_rows: Array[EventRowData] = []
	for entry: Dictionary in viewport.get_flat_rows():
		var row: EventRowData = entry.get("row")
		if row == null:
			continue
		if row.source_resource is EventRow:
			viewport._row_builder._ensure_event_spans(row)
			for span: SemanticSpan in row.spans:
				if str(span.metadata.get("kind", "")) == "match_head":
					head_texts.append(span.text)
				elif str(span.metadata.get("kind", "")) == "trigger":
					tick_cells.append([span.text, str(span.metadata.get("object_label", ""))])
		elif row.source_resource is MatchRow:
			case_rows.append(row)
	var case_reading: Array = []
	for case_row: EventRowData in case_rows:
		var words: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in case_row.spans:
			var object_label: String = str(span.metadata.get("object_label", "")) \
				if str(span.metadata.get("kind", "")) == "match_case" else ""
			words.append("%s:%s%s" % [str(span.metadata.get("kind", "")),
				"" if object_label.is_empty() else object_label + " | ", span.text])
		case_reading.append(" | ".join(words))
	var match_row: MatchRow = case_rows[0].source_resource as MatchRow if not case_rows.is_empty() else null
	var ok: bool = SUPPORT.pins(NAME, [
		["the match says itself beside the trigger", head_texts, PackedStringArray(["match state"])],
		# One sentence on one line, in every look: "System | Every tick (physics), match state".
		["the tick it runs on keeps its words and its object, so the line reads as one sentence",
			tick_cells, [["Every tick (physics),", "System"]]],
		# A branch's step reads as the same line reads in an event's action lane: the object it acts on
		# in the column, and the property as written - not "Set x to 0" with no object at all.
		["each branch is a sub-event holding its own actions, an empty one only its Add action", case_reading, [
			"condition:state is IDLE | match_case:CharacterBody2D | Set velocity.x to 0 | add_action:+ Add action",
			"condition:state is RUN | add_action:+ Add action",
			"else_keyword:Else | add_action:+ Add action"]],
		["a branch row knows its branch", case_rows.size() == 3 and case_rows[1].match_case == match_row.cases[1], true],
		["the opened file re-emits byte for byte", SUPPORT.reemit(SOURCE, "user://match_window_player.gd"), SOURCE],
	])
	# The Add action door fills that one branch; the `pass` that held its place gives way.
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "PrintLog"
	action.codegen_template = "print({message})"
	action.params = {"message": "\"run\""}
	EventSheetStructRowDialogs.append_case_action(match_row.cases[1], action)
	var compiled: String = str(SheetCompiler.compile(sheet, "user://match_window_out.gd").get("output", ""))
	ok = SUPPORT.check(NAME, "the action compiles inside its branch, in place of pass",
		compiled.contains("\t\tState.RUN:\n\t\t\tprint(\"run\")\n\t\t_:"), true) and ok
	# Every edit swaps in a snapshot copy of the match; the branch answers kept are one sweep's only.
	var host_event: EventRow = _first_event(editor)
	for _sweep: int in range(3):
		host_event.actions[0] = (host_event.actions[0] as MatchRow).duplicate(true)
		viewport.rebuild_rows()
	ok = SUPPORT.check(NAME, "three edits later only the live match's answer is kept",
		viewport._row_builder._branch_matches.size(), 1) and ok
	editor.free()
	return ok


static func _test_window() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(SOURCE)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var dialogs: EventSheetStructRowDialogs = dock._struct_rows
	dialogs._ensure_match_dialog()
	var event: EventRow = null
	for row: Variant in dock.get_current_sheet().events:
		if row is EventRow:
			event = row
	var lifted: MatchRow = event.actions[0] as MatchRow
	dialogs._populate_match_dialog(lifted)
	var shown: Array = []
	for entry: Dictionary in dialogs._match_case_rows:
		shown.append((entry["pattern"] as LineEdit).text)
	var ok: bool = SUPPORT.pins(NAME, [
		["the branches read back by their own names", shown, ["IDLE", "RUN"]],
		["the last _ is Otherwise", dialogs._match_otherwise.selected, 0],
		["a branch offers the Value's enum members", dialogs._match_pattern_choices(), ["IDLE", "RUN"]],
		["the strip shows the code", dialogs._match_strip.in_code_value.text, "match state: State.IDLE: …  State.RUN: …  _: pass"],
		["an edit says what Done does", dialogs._match_note.text, "Done updates the match: 3 branches, each keeping its actions."],
	])
	# An untouched Done is not an edit.
	dialogs._on_match_dialog_confirmed()
	ok = SUPPORT.check(NAME, "an untouched Done leaves the same match in place", event.actions[0] == lifted, true) and ok
	# A value matched twice is refused in the window, Done held.
	dialogs._populate_match_dialog(lifted)
	(dialogs._match_case_rows[1]["pattern"] as LineEdit).text = "IDLE"
	dialogs._refresh_match()
	ok = SUPPORT.pins(NAME, [
		["a value matched twice is refused", dialogs._match_note.text, "IDLE is matched twice - the second one could never run."],
		["...and Done waits", dialogs._match_dialog.get_ok_button().disabled, true],
	]) and ok
	# Renaming a branch keeps its actions.
	(dialogs._match_case_rows[1]["pattern"] as LineEdit).text = "RUN"
	(dialogs._match_case_rows[0]["pattern"] as LineEdit).text = "RUN"
	(dialogs._match_case_rows[1]["pattern"] as LineEdit).text = "IDLE"
	dialogs._refresh_match()
	dialogs._on_match_dialog_confirmed()
	var live: MatchRow = (_first_event(dock).actions[0]) as MatchRow
	ok = SUPPORT.pins(NAME, [
		["the swapped branches are written in their new order", [live.cases[0].pattern, live.cases[1].pattern, live.cases[2].pattern],
			["State.RUN", "State.IDLE", "_"]],
		["the branch that held an action keeps it under its new value", (live.cases[0].events[0] as RawCodeRow).code, "velocity.x = 0.0"],
	]) and ok
	# A new match: nothing lands until Done, then the match and its branches in one step.
	var host: EventRow = EventRow.new()
	host.trigger_provider_id = "Core"
	host.trigger_id = "OnProcess"
	dock.get_current_sheet().events.append(host)
	var fresh: MatchRow = MatchRow.new()
	dialogs.open_match_dialog(fresh, host)
	ok = SUPPORT.check(NAME, "a new match is not on the sheet before Done", host.actions.size(), 0) and ok
	dialogs._fill_cases_from_subject()
	dialogs._refresh_match()
	var filled: Array = []
	for entry: Dictionary in dialogs._match_case_rows:
		filled.append((entry["pattern"] as LineEdit).text)
	ok = SUPPORT.pins(NAME, [
		["One match per state fills the empty row with every state", filled, ["IDLE", "RUN"]],
		["a new match says what Done sets up", dialogs._match_note.text, "Done sets up 3 events on the sheet, ready for your actions."],
	]) and ok
	dialogs._on_match_dialog_confirmed()
	var added: MatchRow = _last_event(dock).actions[0] as MatchRow if not _last_event(dock).actions.is_empty() else null
	var patterns: Array = []
	if added != null:
		for match_case: MatchCase in added.cases:
			patterns.append(match_case.pattern)
	ok = SUPPORT.check(NAME, "Done adds the match with one branch per state and Else", patterns, ["State.IDLE", "State.RUN", "_"]) and ok
	dock.free()
	return ok


static func _first_event(dock: EventSheetDock) -> EventRow:
	for row: Variant in dock.get_current_sheet().events:
		if row is EventRow:
			return row
	return null


static func _last_event(dock: EventSheetDock) -> EventRow:
	var found: EventRow = null
	for row: Variant in dock.get_current_sheet().events:
		if row is EventRow:
			found = row
	return found
