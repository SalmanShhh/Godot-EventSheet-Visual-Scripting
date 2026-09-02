# EventForge - Compare With… / Loose Ends / Find Repeated Rows.
#
# Drives the REAL editor paths headlessly: the two-sided comparison over two compiled sides (with a
# copy-over that writes ordinary rows and an undo that restores the sheet byte-for-byte), the loose-
# ends index over a sheet carrying one of each unfinished state (and the proof that indexing them
# changes NOTHING about what the sheet compiles to - the panel is a place you go, never a layer over
# the rows), and the repeated-run scan plus its fix, which is the shipped extractor at the first site
# and a Call at the rest, in one undo step.
@tool
class_name CompareLooseRepeatsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SIDE_PATH := "user://eventforge_compare_test_side.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _run_compare() and ok
	ok = _run_loose_ends() and ok
	ok = _run_repeated_rows() and ok
	return ok


# ── #13 Compare With… ─────────────────────────────────────────────────────────────────────────
static func _run_compare() -> bool:
	var ok: bool = true
	var dock: EventSheetDock = _make_dock()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.events.append(_event("OnProcess", [_print_action("\"first\"")]))
	dock.setup(sheet)

	# The OTHER side is a real .gd on disk: this sheet's own compiled output, written once.
	SheetCompiler.compile(sheet, SIDE_PATH)
	var dialog: EventSheetCompareDialog = EventSheetCompareDialog.new()
	dialog.init(dock)
	var same: Dictionary = dialog.compare_with(SIDE_PATH)
	ok = _check("comparing a sheet against its own output is identical", bool(same.get("identical", false)), true) and ok

	# Retune the action: the comparison names exactly the row that differs, on BOTH sides.
	var event: EventRow = sheet.events[0] as EventRow
	(event.actions[0] as ACEAction).params = {"text": "\"second\""}
	var differs: Dictionary = dialog.compare_with(SIDE_PATH)
	ok = _check("a retuned row makes the sides differ", bool(differs.get("identical", true)), false) and ok
	var here_rows: Array = differs.get("here_rows", [])
	ok = _check("exactly one row differs here", here_rows.size(), 1) and ok
	ok = _check("…and it is EXACTLY the retuned event", (here_rows[0] as Dictionary).get("resource") == event, true) and ok
	ok = _check("the compared side names one row too", (differs.get("there_rows", []) as Array).size(), 1) and ok

	# Bring This Row Over writes an ORDINARY row, in one undo step that restores byte-for-byte.
	var before_output: String = _compiled(dock.get_current_sheet())
	var brought: bool = dialog.bring_row_over(0)
	ok = _check("the compared row is brought over", brought, true) and ok
	var after_sheet: EventSheetResource = dock.get_current_sheet()
	ok = _check("the sheet gained one top-level row", after_sheet.events.size(), 2) and ok
	ok = _check("…and it is an ordinary event row", after_sheet.events[1] is EventRow, true) and ok
	ok = _check("…carrying the compared side's line",
		_compiled(after_sheet).contains("print(\"first\")"), true) and ok
	ok = _check("…with a fresh row uid (never a duplicate of the row it came from)",
		(after_sheet.events[1] as EventRow).event_uid == (after_sheet.events[0] as EventRow).event_uid, false) and ok
	dock._on_undo_requested()
	ok = _check("undo restores the sheet byte-for-byte", _compiled(dock.get_current_sheet()), before_output) and ok

	# A copied row is not portable on its own. Two things travel with it, or it lands broken:
	# every nested event's uid is re-minted (a duplicate uid would make the trace and the hit-count
	# tally answer for two rows at once), and any sheet variable it reads that this sheet does not
	# declare is created here.
	var group: EventGroup = EventGroup.new()
	var nested: EventRow = _event("OnReady", [])
	nested.event_uid = "shared_uid"
	group.events.append(nested)
	dialog._refresh_event_uids(group)
	ok = _check("a group's nested events get fresh uids too",
		(group.events[0] as EventRow).event_uid == "shared_uid", false) and ok

	var needy: EventSheetResource = EventSheetResource.new()
	needy.host_class = "Node2D"
	needy.variables["combo_timer"] = {"type": "float", "default": 0.0}
	var reader: EventRow = _event("OnProcess", [])
	var uses: ACEAction = ACEAction.new()
	uses.provider_id = "Core"
	uses.ace_id = "SetVariable"
	uses.codegen_template = "{name} = {value}"
	uses.params = {"name": "combo_timer", "value": "1.0"}
	reader.actions.append(uses)
	needy.events.append(reader)
	var variable_dock: EventSheetDock = _make_dock()
	var bare: EventSheetResource = EventSheetResource.new()
	bare.host_class = "Node2D"
	variable_dock.setup(bare)
	var variable_dialog: EventSheetCompareDialog = EventSheetCompareDialog.new()
	variable_dialog.init(variable_dock)
	variable_dialog._other_sheet = needy
	variable_dialog._there_entries = [{"resource": reader}]
	ok = _check("the row that reads a variable comes over", variable_dialog.bring_row_over(0), true) and ok
	ok = _check("…and the variable it needs was created here",
		variable_dock.get_current_sheet().variables.has("combo_timer"), true) and ok
	variable_dock.free()

	# A difference that lives in a CONDITION belongs to the event that holds it. Walking only
	# sub-events and actions made the copy-over refuse an ordinary row with "that isn't a row".
	var owner_sheet: EventSheetResource = EventSheetResource.new()
	owner_sheet.host_class = "Node2D"
	var guarded: EventRow = _event("OnProcess", [])
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "TestCondition"
	condition.codegen_template = "score >= 100"
	guarded.conditions.append(condition)
	owner_sheet.events.append(guarded)
	ok = _check("a condition resolves to the event that owns it",
		EventSheetSheetDiff.top_level_owner(owner_sheet, condition) == guarded, true) and ok
	dock.free()
	return ok


# ── #16 Loose Ends ────────────────────────────────────────────────────────────────────────────
static func _run_loose_ends() -> bool:
	var ok: bool = true
	var dock: EventSheetDock = _make_dock()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"

	var todo: CommentRow = CommentRow.new()
	todo.text = "TODO: balance this drop rate"
	sheet.events.append(todo)
	var disabled: EventRow = _event("OnProcess", [_print_action("\"debug\"")])
	disabled.enabled = false
	sheet.events.append(disabled)
	var unfinished: EventRow = _event("OnReady", [])
	sheet.events.append(unfinished)
	var broken: EventRow = _event("OnProcess", [_print_action("\"kept\"")])
	broken.debug_break = true
	sheet.events.append(broken)
	var orphan: EventFunction = EventFunction.new()
	orphan.function_name = "never_called"
	orphan.expose_as_ace = true
	sheet.functions.append(orphan)
	dock.setup(sheet)

	var entries: Array = EventSheetLooseEndsPanel.loose_ends(sheet)
	ok = _check("the TODO comment is indexed", _labels_of(entries, "todo"), PackedStringArray(["TODO: balance this drop rate"])) and ok
	ok = _check("the disabled event is indexed", _labels_of(entries, "disabled"), PackedStringArray(["Event 1 is turned off"])) and ok
	ok = _check("the event with no actions is indexed", _labels_of(entries, "unfinished"), PackedStringArray(["Event 2 has conditions and no actions"])) and ok
	ok = _check("the breakpoint left on is indexed", _labels_of(entries, "breakpoint"), PackedStringArray(["Event 3 breaks into the debugger"])) and ok
	ok = _check("the verb nothing calls is indexed", _labels_of(entries, "orphan_verb"), PackedStringArray(["\"never_called\" is never called"])) and ok
	ok = _check("every entry points at a live row",
		entries.all(func(entry: Variant) -> bool: return (entry as Dictionary).get("resource") != null), true) and ok

	# A verb a row DOES call is not a loose end.
	var caller: ACEAction = ACEAction.new()
	caller.provider_id = "Core"
	caller.ace_id = "CallFunction"
	caller.codegen_template = "{function_name}({args})"
	caller.params = {"function_name": "never_called", "args": ""}
	(sheet.events[3] as EventRow).actions.append(caller)
	# Things that are NOT loose ends must stay off the index, or the reader learns to ignore it.
	var standing_note: CommentRow = CommentRow.new()
	standing_note.text = "Warning: this runs every frame"
	standing_note.style = CommentRow.CommentStyle.WARNING
	sheet.events.append(standing_note)
	var cleared: CommentRow = CommentRow.new()
	cleared.text = "no TODOs left here"
	sheet.events.append(cleared)
	var literal_code: RawCodeRow = RawCodeRow.new()
	literal_code.code = "print(\"XXX marks the spot\")"
	sheet.events.append(literal_code)
	var noted_code: RawCodeRow = RawCodeRow.new()
	noted_code.code = "var temp: int = 1  # HACK: temporary"
	sheet.events.append(noted_code)
	var wider: PackedStringArray = _labels_of(EventSheetLooseEndsPanel.loose_ends(sheet), "todo")
	ok = _check("a WARNING-styled standing note is not unfinished work",
		wider.has("Warning: this runs every frame"), false) and ok
	ok = _check("a marker inside a longer word is not a note to self", wider.has("no TODOs left here"), false) and ok
	ok = _check("a marker inside a string literal is data, not a note",
		wider.has("print(\"XXX marks the spot\")"), false) and ok
	ok = _check("a marker in a real code comment IS indexed",
		wider.has("var temp: int = 1  # HACK: temporary"), true) and ok
	sheet.events.resize(4)

	ok = _check("a verb that IS called drops off the list",
		_labels_of(EventSheetLooseEndsPanel.loose_ends(sheet), "orphan_verb").size(), 0) and ok

	# The panel is a place you GO: indexing changes nothing about the sheet or what it compiles to.
	var before_output: String = _compiled(sheet)
	var panel: EventSheetLooseEndsPanel = EventSheetLooseEndsPanel.new()
	panel.init(dock)
	var counted: int = panel.refresh()
	ok = _check("the panel lists what the walk found", counted > 0, true) and ok
	ok = _check("opening the index leaves the compiled sheet byte-identical", _compiled(dock.get_current_sheet()), before_output) and ok
	ok = _check("…and adds no chrome to any row", sheet.events.size(), 4) and ok
	dock.free()
	return ok


# ── #17 Find Repeated Rows ────────────────────────────────────────────────────────────────────
static func _run_repeated_rows() -> bool:
	var ok: bool = true
	var dock: EventSheetDock = _make_dock()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	for site: int in range(3):
		sheet.events.append(_event("OnProcess", [
			_print_action("\"hit\""), _print_action("\"shake\""), _print_action("\"unique %d\"" % site)]))
	dock.setup(sheet)

	var runs: Array = EventSheetRepeatedRows.repeated_runs(sheet)
	ok = _check("one repeated run is found", runs.size(), 1) and ok
	var run: Dictionary = runs[0]
	ok = _check("it is the two-row run", int(run.get("length", 0)), 2) and ok
	ok = _check("…at three sites", (run.get("occurrences", []) as Array).size(), 3) and ok
	ok = _check("…saving four rows", int(run.get("rows_saved", 0)), 4) and ok
	ok = _check("…needing no parameters", bool(run.get("needs_parameters", true)), false) and ok
	ok = _check("…and listing its actions", run.get("labels", PackedStringArray()), PackedStringArray(["print", "print"])) and ok

	var before_output: String = _compiled(sheet)
	var panel: EventSheetRepeatedRows = EventSheetRepeatedRows.new()
	panel.init(dock)
	ok = _check("the window lists the run", panel.refresh(), 1) and ok
	var made: bool = panel.make_verb(0, "Take A Hit")
	ok = _check("making a verb changes the sheet", made, true) and ok
	var after: EventSheetResource = dock.get_current_sheet()
	ok = _check("one function is defined", after.functions.size(), 1) and ok
	ok = _check("…holding the two repeated rows",
		((after.functions[0] as EventFunction).events[0] as EventRow).actions.size(), 2) and ok
	ok = _check("every site now calls it", _call_sites(after), 3) and ok
	ok = _check("…and each site kept its own remaining action",
		(after.events[0] as EventRow).actions.size(), 2) and ok
	dock._on_undo_requested()
	ok = _check("one undo restores the whole refactor byte-for-byte", _compiled(dock.get_current_sheet()), before_output) and ok

	# A run that leans on an event-local is SEEN but never offered as a one-click fix.
	var local_sheet: EventSheetResource = EventSheetResource.new()
	local_sheet.host_class = "Node2D"
	for site: int in range(2):
		var event: EventRow = _event("OnProcess", [_print_action("bonus"), _print_action("\"tail\"")])
		var local: LocalVariable = LocalVariable.new()
		local.name = "bonus"
		local.type_name = "int"
		event.local_variables.append(local)
		local_sheet.events.append(event)
	var local_runs: Array = EventSheetRepeatedRows.repeated_runs(local_sheet)
	ok = _check("the run that uses an event-local is still listed", local_runs.size(), 1) and ok
	ok = _check("…marked as needing parameters", bool((local_runs[0] as Dictionary).get("needs_parameters", false)), true) and ok
	dock.free()

	ok = _run_repeat_twice_in_one_event() and ok
	ok = _run_repeat_after_an_edit() and ok
	return ok


## TWO occurrences of one run inside ONE event. The scan only rejects overlapping spans, so this
## shape is reported - and replaying the pre-scan indices after the first extraction has already
## shortened that action list would delete rows the run never touched.
static func _run_repeat_twice_in_one_event() -> bool:
	var ok: bool = true
	var dock: EventSheetDock = _make_dock()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.events.append(_event("OnProcess", [
		_print_action("\"hit\""), _print_action("\"shake\""), _print_action("\"tail\""),
		_print_action("\"hit\""), _print_action("\"shake\"")]))
	dock.setup(sheet)
	var before_output: String = _compiled(sheet)

	var panel: EventSheetRepeatedRows = EventSheetRepeatedRows.new()
	panel.init(dock)
	ok = _check("the run repeated inside one event is found", panel.refresh(), 1) and ok
	ok = _check("making a verb from it succeeds", panel.make_verb(0, "Take A Hit"), true) and ok
	var after: EventSheetResource = dock.get_current_sheet()
	var event: EventRow = after.events[0] as EventRow
	ok = _check("the event keeps exactly three actions", event.actions.size(), 3) and ok
	ok = _check("both repeats became calls", _call_sites(after), 2) and ok
	ok = _check("the action between them survives untouched",
		_compiled(after).contains("print(\"tail\")"), true) and ok
	ok = _check("and nothing outside the run was deleted",
		_compiled(after).contains("print(\"hit\")") and _compiled(after).contains("print(\"shake\")"), true) and ok
	dock._on_undo_requested()
	ok = _check("one undo restores it byte-for-byte", _compiled(dock.get_current_sheet()), before_output) and ok
	dock.free()
	return ok


## A scan is a snapshot: the undo funnel replaces every resource on commit, so a sheet edited
## between the scan and the button leaves the listed rows orphaned. Rewriting THOSE would publish a
## verb with no call sites and leave every repeat in place, while reporting success.
static func _run_repeat_after_an_edit() -> bool:
	var ok: bool = true
	var dock: EventSheetDock = _make_dock()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	for site: int in range(2):
		sheet.events.append(_event("OnProcess", [
			_print_action("\"hit\""), _print_action("\"shake\""), _print_action("\"unique %d\"" % site)]))
	dock.setup(sheet)
	var panel: EventSheetRepeatedRows = EventSheetRepeatedRows.new()
	panel.init(dock)
	ok = _check("the scan finds the run", panel.refresh(), 1) and ok

	# An ordinary edit through the funnel - which is what replaces the resources under the scan.
	dock._perform_undoable_sheet_edit("Probe Edit", func() -> bool:
		dock._current_sheet.events.append(_event("OnReady", [_print_action("\"late\"")]))
		return true)
	var before_output: String = _compiled(dock.get_current_sheet())
	ok = _check("a stale run is refused, not applied", panel.make_verb(0, "Take A Hit"), false) and ok
	ok = _check("…and the sheet is untouched", _compiled(dock.get_current_sheet()), before_output) and ok
	ok = _check("…with no verb published", dock.get_current_sheet().functions.size(), 0) and ok
	dock.free()
	return ok


# ── helpers ───────────────────────────────────────────────────────────────────────────────────
static func _make_dock() -> EventSheetDock:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	return dock


static func _event(trigger_id: String, actions: Array) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger_id
	var typed: Array[Resource] = []
	for action: Variant in actions:
		typed.append(action as Resource)
	event.actions = typed
	return event


static func _print_action(text: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "print"
	action.codegen_template = "print({text})"
	action.params = {"text": text}
	return action


static func _compiled(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.compile(sheet, "user://eventforge_compare_test_probe.gd").get("output", ""))


static func _labels_of(entries: Array, kind: String) -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	for entry: Variant in entries:
		if str((entry as Dictionary).get("kind", "")) == kind:
			labels.append(str((entry as Dictionary).get("label", "")))
	return labels


static func _call_sites(sheet: EventSheetResource) -> int:
	var sites: int = 0
	for row: Variant in sheet.events:
		if not (row is EventRow):
			continue
		for action: Variant in (row as EventRow).actions:
			if action is ACEAction and (action as ACEAction).ace_id == "CallFunction":
				sites += 1
	return sites


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("compare_loose_repeats_test", label, actual, expected)
