# EventForge - the three editor seams: Change Type Everywhere, Grid to CSV and back, Paste Special.
#
# Each is driven through the REAL editor path (the dock, its undo funnel, the dialog objects the
# context menus open), not through a private helper, and each is asserted on the resulting SHEET or
# FILE state - plus the undo that must put it back.
#
#  1. Change Type Everywhere (variable menu): the declaration, the default and every value field
#     standing in an assignment/comparison with the variable retype in ONE undo step. Pinned: the
#     rewritten literals, the fields it must NOT touch (a Dictionary key beside the variable, an
#     unrelated row), the expression it refuses to guess at (reported, never rewritten), and undo.
#  2. Grid to CSV and back: the codec's quote/CRLF/short-row policy AGREES WITH THE RUNTIME table
#     verb (the shipped expression is compiled and run against the same bytes), the .tres round trip
#     lands on disk and reads back typed, and every failure answers in words - missing file,
#     unwritable path, a property that is not a grid.
#  3. Paste Special: the remap retargets object references and variable names, leaves the clipboard
#     snippet untouched (deep copy), reuses an existing sheet variable instead of overwriting it,
#     creates a missing one, and undo removes the pasted rows again.
@tool
class_name EditorSeamsTest
extends RefCounted

const GRID_RESOURCE_PATH := "user://eventforge_seams_loot.tres"
const GRID_CSV_PATH := "user://eventforge_seams_loot.csv"
const SHEET_CSV_PATH := "user://eventforge_seams_sheet.csv"
const MISSING_CSV_PATH := "user://eventforge_seams_nothing_here.csv"
const UNWRITABLE_CSV_PATH := "user://eventforge_seams_missing_dir/deep.csv"


## The editor's undo manager, as the EDITOR's own is shaped: the dock funnels edits through
## create_action / add_do_method / add_undo_method / commit_action, and the commit RUNS the do
## method - which is what replaces the sheet with a snapshot duplicate. A plain UndoRedo takes
## Callables instead of (object, method, arg), so it silently registers nothing; this stand-in
## keeps the test honest about what the editor actually does.
class RecordingUndoManager:
	extends RefCounted
	var _pending_do: Array = []
	var _pending_undo: Array = []
	var _stack: Array = []

	func create_action(_action_name: Variant = null) -> void:
		_pending_do = []
		_pending_undo = []

	func add_do_method(target: Variant = null, method: Variant = null, argument: Variant = null) -> void:
		_pending_do = [target, method, argument]

	func add_undo_method(target: Variant = null, method: Variant = null, argument: Variant = null) -> void:
		_pending_undo = [target, method, argument]

	func commit_action() -> void:
		_stack.append(_pending_undo)
		if _pending_do.size() == 3:
			(_pending_do[0] as Object).call(str(_pending_do[1]), _pending_do[2])

	func undo() -> void:
		if _stack.is_empty():
			return
		var entry: Array = _stack.pop_back()
		if entry.size() == 3:
			(entry[0] as Object).call(str(entry[1]), entry[2])

	func has_undo() -> bool:
		return not _stack.is_empty()

	func has_redo() -> bool:
		return false

	func clear_history() -> void:
		_stack.clear()


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _run_change_type() and all_passed
	all_passed = _run_grid_csv() and all_passed
	all_passed = _run_paste_special() and all_passed
	all_passed = _run_paste_special_refusals() and all_passed
	return all_passed


# ── 1. Change Type Everywhere ────────────────────────────────────────────────


static func _run_change_type() -> bool:
	var all_passed: bool = true
	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables["score"] = {"type": "String", "default": "0", "exported": true}
	var event: EventRow = EventRow.new()
	sheet.events.append(event)
	editor.set_undo_redo_manager(RecordingUndoManager.new())
	editor.setup(sheet)

	# Built through the dock's own bake path, so every template is the shipped one.
	var compare: ACECondition = editor._ace_apply._create_condition_from_definition(
		editor._find_definition("Core", "CompareVar"), {"var_name": "score", "op": "==", "value": "\"100\""})
	event.conditions.append(compare)
	var set_literal: ACEAction = editor._ace_apply._create_action_from_definition(
		editor._find_definition("Core", "SetVar"), {"var_name": "score", "value": "\"0\""})
	event.actions.append(set_literal)
	var set_expression: ACEAction = editor._ace_apply._create_action_from_definition(
		editor._find_definition("Core", "SetVar"), {"var_name": "score", "value": "Text To Int(score) + 10"})
	event.actions.append(set_expression)
	# A key sitting beside the variable in the SAME ace: `{var_name}[{key}] = {value}` puts no
	# operator between the variable and the key, so a retype must leave "tier" alone.
	var dict_write: ACEAction = editor._ace_apply._create_action_from_definition(
		editor._find_definition("Core", "DictSetKey"), {"var_name": "score", "key": "\"tier\"", "value": "\"1\""})
	event.actions.append(dict_write)
	var unrelated: ACEAction = editor._ace_apply._create_action_from_definition(
		editor._find_definition("Core", "ConsoleLog"), {"message": "\"100\"", "level": "print"})
	event.actions.append(unrelated)
	all_passed = _check("the compare template is the shipped one", compare.codegen_template, "{var_name} {op} {value}") and all_passed

	# ---- the menu really carries it, and really routes there ----
	var variable_menu: PopupMenu = editor._variable_context_menu
	var change_index: int = variable_menu.get_item_index(editor.VARIABLE_MENU_CHANGE_TYPE)
	all_passed = _check("the variable menu carries the command", variable_menu.get_item_text(change_index) if change_index >= 0 else "",
		"Change Type Everywhere…") and all_passed
	editor._variables._context_variable = {"name": "score", "scope": "global", "type": "String", "default": "0"}
	editor._variables._on_variable_context_menu_id_pressed(editor.VARIABLE_MENU_CHANGE_TYPE)
	all_passed = _check("clicking it opens the dialog on the clicked variable",
		editor._variable_retype_dialog._variable_name, "score") and all_passed

	# ---- the preview the dialog shows ----
	var dialog: EventSheetVariableRetypeDialog = editor._variable_retype_dialog
	dialog.open({"name": "score", "scope": "global", "type": "String", "default": "0"})
	# The REAL UI route to a numeric type is the dropdown, and int is only reachable through the
	# tick beside it - which is hidden until "Number" is picked. Driven exactly as a click does:
	# select the item, emit the signal the OptionButton emits, then tick the box.
	all_passed = _check("the tick is hidden while the type is Text", dialog._whole_numbers_check.visible, false) and all_passed
	var number_index: int = -1
	for index: int in range(dialog._type_option.item_count):
		if dialog._type_option.get_item_text(index) == "Number":
			number_index = index
	dialog._type_option.select(number_index)
	dialog._type_option.item_selected.emit(number_index)
	all_passed = _check("picking Number from the dropdown reveals the tick", dialog._whole_numbers_check.visible, true) and all_passed
	all_passed = _check("and without it the dropdown means float", dialog.selected_type(), "float") and all_passed
	dialog._whole_numbers_check.button_pressed = true
	all_passed = _check("the dropdown means int once Whole numbers is ticked", dialog.selected_type(), "int") and all_passed
	var lines: PackedStringArray = dialog.preview_lines()
	all_passed = _check("the preview leads with the declaration", lines[0] if not lines.is_empty() else "",
		"Declaration: score is String, becomes int") and all_passed
	all_passed = _check("the preview names the default change", Array(lines).has("Default: \"0\" becomes 0"), true) and all_passed
	all_passed = _check("the preview names the compared literal",
		Array(lines).has("Event 1 - Compare Variable value: \"100\" becomes 100"), true) and all_passed
	all_passed = _check("the preview says which row it will NOT touch",
		Array(lines).has("Event 1 - Set Variable value: Text To Int(score) + 10 left as written (it is an expression, not a plain value)"), true) and all_passed

	# ---- apply: one undo step, the whole sheet ----
	dialog.confirm()
	var live: EventSheetResource = editor._current_sheet
	all_passed = _check("the declaration retyped", str((live.variables["score"] as Dictionary).get("type", "")), "int") and all_passed
	all_passed = _check("the default came across as a number", (live.variables["score"] as Dictionary).get("default", null), 0) and all_passed
	var live_event: EventRow = live.events[0] as EventRow
	all_passed = _check("the compared literal lost its quotes",
		str((live_event.conditions[0] as ACECondition).params.get("value", "")), "100") and all_passed
	all_passed = _check("the assigned literal lost its quotes",
		str((live_event.actions[0] as ACEAction).params.get("value", "")), "0") and all_passed
	all_passed = _check("the expression is left exactly as written",
		str((live_event.actions[1] as ACEAction).params.get("value", "")), "Text To Int(score) + 10") and all_passed
	all_passed = _check("a dictionary KEY beside the variable is never retyped",
		str((live_event.actions[2] as ACEAction).params.get("key", "")), "\"tier\"") and all_passed
	all_passed = _check("a row that never names the variable is untouched",
		str((live_event.actions[3] as ACEAction).params.get("message", "")), "\"100\"") and all_passed

	# ---- undo: one step puts the whole refactor back ----
	editor._undo_redo_adapter.undo()
	var undone: EventSheetResource = editor._current_sheet
	all_passed = _check("undo restores the declared type", str((undone.variables["score"] as Dictionary).get("type", "")), "String") and all_passed
	all_passed = _check("undo restores the compared literal",
		str(((undone.events[0] as EventRow).conditions[0] as ACECondition).params.get("value", "")), "\"100\"") and all_passed

	# ---- the same refactor the other way: back to text, then to yes/no ----
	var text_report: Dictionary = EventSheetVariableRetype.plan(undone, "score", "String")
	all_passed = _check("planning String again reports no rewrite (it is already text)",
		(text_report.get("changes", []) as Array).size(), 0) and all_passed
	var bool_report: Dictionary = EventSheetVariableRetype.apply(undone, "score", "bool")
	all_passed = _check("a yes/no retype converts the compared literal",
		str(((undone.events[0] as EventRow).conditions[0] as ACECondition).params.get("value", "")), "true") and all_passed
	all_passed = _check("a yes/no retype reports the expression it left alone",
		(bool_report.get("reviews", []) as Array).size(), 1) and all_passed
	editor.free()
	all_passed = _run_change_type_targets_the_clicked_row() and all_passed
	all_passed = _run_change_type_leaves_property_names_alone() and all_passed
	return all_passed


## THE ambiguity a name alone cannot resolve: two events may each declare their own `i`, and a sheet
## variable may share a name with an event-local. Right-clicking one and retyping must change THAT
## declaration - the preview and the commit both.
static func _run_change_type_targets_the_clicked_row() -> bool:
	var all_passed: bool = true
	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables["count"] = {"type": "String", "default": "0", "exported": true}
	var first: EventRow = EventRow.new()
	first.local_variables.append(_local("count", "String", "a"))
	var second: EventRow = EventRow.new()
	second.local_variables.append(_local("count", "float", 1.5))
	sheet.events.append(first)
	sheet.events.append(second)
	editor.set_undo_redo_manager(RecordingUndoManager.new())
	editor.setup(sheet)

	# Right-clicking the SECOND event's own `count` - the third declaration of that name in the
	# sheet, behind the sheet variable and the first event's local.
	var clicked: Dictionary = {"name": "count", "scope": "local", "type": "float", "default": 1.5,
		"event_row": second, "index": 0}
	all_passed = _check("the clicked local is addressed by its own position",
		EventSheetVariableRetype.ordinal_of(editor._current_sheet, clicked), 2) and all_passed
	var dialog: EventSheetVariableRetypeDialog = editor._variable_retype_dialog
	dialog.open(clicked)
	dialog.select_type("bool")
	all_passed = _check("the preview describes the declaration that was clicked",
		dialog.preview_lines()[0] if not dialog.preview_lines().is_empty() else "",
		"Declaration: count is float, becomes bool") and all_passed
	dialog.confirm()
	var live: EventSheetResource = editor._current_sheet
	all_passed = _check("the clicked local really retyped",
		((live.events[1] as EventRow).local_variables[0] as LocalVariable).type_name, "bool") and all_passed
	all_passed = _check("the other event's same-named local is untouched",
		((live.events[0] as EventRow).local_variables[0] as LocalVariable).type_name, "String") and all_passed
	all_passed = _check("and so is the sheet variable that shares the name",
		str((live.variables["count"] as Dictionary).get("type", "")), "String") and all_passed

	# The sheet variable, clicked directly, is position 0 - and retyping it leaves the locals alone.
	var sheet_entry: Dictionary = {"name": "count", "scope": "global", "type": "String", "default": "0"}
	all_passed = _check("the sheet variable is the first declaration",
		EventSheetVariableRetype.ordinal_of(editor._current_sheet, sheet_entry), 0) and all_passed
	dialog.open(sheet_entry)
	dialog.select_type("int")
	dialog.confirm()
	all_passed = _check("retyping the sheet variable retypes the sheet variable",
		str((editor._current_sheet.variables["count"] as Dictionary).get("type", "")), "int") and all_passed
	all_passed = _check("and the event-local it shares a name with stays as it was",
		((editor._current_sheet.events[0] as EventRow).local_variables[0] as LocalVariable).type_name, "String") and all_passed
	editor.free()
	return all_passed


## A PROPERTY NAME that happens to be spelled like the variable is not the variable. Set Property's
## `{target}.{property} = {value}` puts them in an assignment, but `{property}` names a field on
## another object - retyping its value would assign an int to a node property that is a String.
static func _run_change_type_leaves_property_names_alone() -> bool:
	var all_passed: bool = true
	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables["health"] = {"type": "String", "default": "0", "exported": true}
	var event: EventRow = EventRow.new()
	sheet.events.append(event)
	editor.set_undo_redo_manager(RecordingUndoManager.new())
	editor.setup(sheet)
	var set_property: ACEAction = editor._ace_apply._create_action_from_definition(
		editor._find_definition("Core", "SetProperty"), {"target": "$Player", "property": "health", "value": "\"75\""})
	event.actions.append(set_property)
	all_passed = _check("the Set Property template is the shipped one",
		set_property.codegen_template, "{target}.{property} = {value}") and all_passed
	all_passed = _check("a member name is not a value slot for the variable",
		Array(EventSheetVariableRetype.value_params_for(set_property, "health")), []) and all_passed
	var report: Dictionary = EventSheetVariableRetype.apply(editor._current_sheet, "health", "int")
	all_passed = _check("so the retype touches no row here", (report.get("changes", []) as Array).size(), 0) and all_passed
	all_passed = _check("the node property keeps the string it was assigned",
		str(((editor._current_sheet.events[0] as EventRow).actions[0] as ACEAction).params.get("value", "")), "\"75\"") and all_passed
	# The real value slot still answers: Set Variable's own `{var_name} = {value}` is retyped.
	var set_variable: ACEAction = editor._ace_apply._create_action_from_definition(
		editor._find_definition("Core", "SetVar"), {"var_name": "health", "value": "\"75\""})
	all_passed = _check("but the variable's own value field still is one",
		Array(EventSheetVariableRetype.value_params_for(set_variable, "health")), ["value"]) and all_passed
	editor.free()
	return all_passed


static func _local(name: String, type_name: String, default_value: Variant) -> LocalVariable:
	var variable: LocalVariable = LocalVariable.new()
	variable.name = name
	variable.type_name = type_name
	variable.type = EventSheetVariableRetype.variant_type_for(type_name)
	variable.default_value = default_value
	return variable


# ── 2. Grid to CSV and back ──────────────────────────────────────────────────


static func _run_grid_csv() -> bool:
	var all_passed: bool = true
	var columns: Array = [{"name": "item", "type": "String"}, {"name": "weight", "type": "float"}, {"name": "tags", "type": "String"}]

	# ---- writing: a cell holding the separator is quoted, one holding a quote doubles it ----
	var written: String = EventSheetGridCSV.to_csv([
		{"item": "sword", "weight": 2.5, "tags": "melee,rare"},
		{"item": "12\" pipe", "weight": 1.0, "tags": ""}
	], columns)
	all_passed = _check("the CSV is header-first, quoted only where it must be", written,
		"item,weight,tags\nsword,2.5,\"melee,rare\"\n\"12\"\" pipe\",1,\n") and all_passed

	# ---- reading: the policy, and it AGREES WITH THE RUNTIME verb on the same bytes ----
	var tricky: String = "item,price,item\r\nsword,\"1,200\",dup\r\n\"12\"\" pipe\",5,\nshort\r\n"
	var records: Array = EventSheetGridCSV.parse_records(tricky)
	all_passed = _check("a quoted cell keeps the separator", str((records[0] as Dictionary).get("price", "")), "1,200") and all_passed
	all_passed = _check("a repeated column name keeps the FIRST column", str((records[0] as Dictionary).get("item", "")), "sword") and all_passed
	all_passed = _check("a doubled quote is one literal quote", str((records[1] as Dictionary).get("item", "")), "12\" pipe") and all_passed
	all_passed = _check("a short row fills the missing cell", str((records[2] as Dictionary).get("price", "")), "") and all_passed
	all_passed = _check("the editor reader answers exactly like the runtime table verb",
		records, _runtime_table_rows(tricky)) and all_passed
	var stray: Array = EventSheetGridCSV.parse_records("a,b\n1,12\" pipe\n")
	all_passed = _check("a line whose quotes do not pair up still splits into every column",
		str((stray[0] as Dictionary).get("b", "")), "12\" pipe") and all_passed

	# ---- the .tres round trip: it lands on disk, and reads back TYPED ----
	var table: LootTableResource = LootTableResource.new()
	table.entries = [{"item": "sword", "weight": 2.5, "tags": "melee"}, {"item": "gem", "weight": 0.5, "tags": "shiny"}]
	all_passed = _check("the fixture data asset saves", ResourceSaver.save(table, GRID_RESOURCE_PATH), OK) and all_passed
	var exported: Dictionary = EventSheetGridCSV.export_to_csv(GRID_RESOURCE_PATH, "entries", GRID_CSV_PATH)
	all_passed = _check("export reports what it wrote", str(exported.get("message", "")),
		"Wrote 2 row(s) to %s." % GRID_CSV_PATH) and all_passed
	all_passed = _check("the columns came from the resource's own table hint",
		FileAccess.get_file_as_string(GRID_CSV_PATH), "item,weight,tags\nsword,2.5,melee\ngem,0.5,shiny\n") and all_passed
	# A designer's edit: a changed weight, a new row, a column the grid has no room for.
	var edited: FileAccess = FileAccess.open(GRID_CSV_PATH, FileAccess.WRITE)
	edited.store_string("item,weight,tags,colour\nsword,9.5,melee,red\ngem,0.5,shiny,blue\nshield,3,armour,grey\n")
	edited.close()
	var imported: Dictionary = EventSheetGridCSV.import_from_csv(GRID_CSV_PATH, GRID_RESOURCE_PATH, "entries")
	all_passed = _check("import reports the read AND the save", str(imported.get("message", "")),
		"Read %s - 3 row(s), ignored colour (no such column in the grid). Saved %s." % [GRID_CSV_PATH, GRID_RESOURCE_PATH]) and all_passed
	var reloaded: LootTableResource = ResourceLoader.load(GRID_RESOURCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as LootTableResource
	all_passed = _check("the edited weight really reached the file on disk",
		(reloaded.entries[0] as Dictionary).get("weight", null), 9.5) and all_passed
	all_passed = _check("a whole number in a float column arrives as a float",
		(reloaded.entries[2] as Dictionary).get("weight", null), 3.0) and all_passed
	all_passed = _check("the new row landed", (reloaded.entries[2] as Dictionary).get("item", ""), "shield") and all_passed
	all_passed = _check("a column the grid has no room for is dropped, not stored",
		(reloaded.entries[0] as Dictionary).has("colour"), false) and all_passed

	# ---- every failure answers in words ----
	var missing: Dictionary = EventSheetGridCSV.import_from_csv(MISSING_CSV_PATH, GRID_RESOURCE_PATH, "entries")
	all_passed = _check("a missing CSV says so", str(missing.get("message", "")),
		"Could not read %s - there is no file at that path." % MISSING_CSV_PATH) and all_passed
	var not_a_grid: Dictionary = EventSheetGridCSV.export_to_csv(GRID_RESOURCE_PATH, "pity_tag", GRID_CSV_PATH)
	all_passed = _check("a property that is not a grid says so, and lists the ones that are",
		str(not_a_grid.get("message", "")), "\"pity_tag\" is not a grid on this resource. It has: entries.") and all_passed
	var unwritable: Dictionary = EventSheetGridCSV.export_to_csv(GRID_RESOURCE_PATH, "entries", UNWRITABLE_CSV_PATH)
	all_passed = _check("a write that fails names the error instead of looking like a success",
		str(unwritable.get("ok", true)), "false") and all_passed
	all_passed = _check("and the failure names the file",
		str(unwritable.get("message", "")).begins_with("Could not write %s - " % UNWRITABLE_CSV_PATH), true) and all_passed
	var no_asset: Dictionary = EventSheetGridCSV.export_to_csv("user://eventforge_seams_absent.tres", "entries", GRID_CSV_PATH)
	all_passed = _check("a data asset that is not there says so", str(no_asset.get("message", "")),
		"Could not load user://eventforge_seams_absent.tres - there is no data asset at that path.") and all_passed

	# ---- the dialog path: the sheet's OWN declared rows, imported through the undo funnel ----
	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.variables["drops"] = EventSheets.resource_grid(["item", "weight: float", "kind: coin|gem"])
	(sheet.variables["drops"] as Dictionary)["default"] = [{"item": "coin", "weight": 1.0, "kind": "coin"}]
	editor.set_undo_redo_manager(RecordingUndoManager.new())
	editor.setup(sheet)
	var entry: Dictionary = {"name": "drops", "scope": "global", "type": "Array",
		"attributes": (sheet.variables["drops"] as Dictionary).get("attributes", {})}
	all_passed = _check("a grid variable is recognised as one", EventSheetGridCSVDialog.is_grid_variable(entry), true) and all_passed
	all_passed = _check("a plain variable is not", EventSheetGridCSVDialog.is_grid_variable({"name": "score", "attributes": {}}), false) and all_passed
	# The two grid items are on the variable menu, live-gated: enabled on a grid, disabled with the
	# reason on anything else (there is no per-item visibility in a PopupMenu, so disabled it is).
	editor._variables._context_variable = {"name": "score", "scope": "global", "type": "int", "attributes": {}}
	editor._configure_context_menu(editor._variable_context_menu)
	var export_index: int = editor._variable_context_menu.get_item_index(editor.VARIABLE_MENU_GRID_EXPORT)
	all_passed = _check("the CSV command is disabled on a plain variable",
		editor._variable_context_menu.is_item_disabled(export_index), true) and all_passed
	editor._variables._context_variable = entry
	editor._configure_context_menu(editor._variable_context_menu)
	all_passed = _check("and enabled on a grid one",
		editor._variable_context_menu.is_item_disabled(export_index), false) and all_passed
	var grid_dialog: EventSheetGridCSVDialog = editor._grid_csv_dialog
	grid_dialog.open("export", entry)
	grid_dialog._csv_edit.text = SHEET_CSV_PATH
	grid_dialog._asset_edit.text = ""
	var sheet_export: Dictionary = grid_dialog.run()
	all_passed = _check("the sheet's own rows export", str(sheet_export.get("ok", false)), "true") and all_passed
	all_passed = _check("the declared columns become the header",
		FileAccess.get_file_as_string(SHEET_CSV_PATH), "item,weight,kind\ncoin,1,coin\n") and all_passed
	var designer: FileAccess = FileAccess.open(SHEET_CSV_PATH, FileAccess.WRITE)
	designer.store_string("item,weight,kind\ncoin,1,coin\nruby,4.5,gem\n")
	designer.close()
	grid_dialog.open("import", entry)
	grid_dialog._csv_edit.text = SHEET_CSV_PATH
	grid_dialog._asset_edit.text = ""
	grid_dialog.run()
	var live_rows: Array = (editor._current_sheet.variables["drops"] as Dictionary).get("default", [])
	all_passed = _check("the CSV became the sheet's declared rows", live_rows.size(), 2) and all_passed
	all_passed = _check("and the typed column arrived typed", (live_rows[1] as Dictionary).get("weight", null), 4.5) and all_passed
	editor._undo_redo_adapter.undo()
	all_passed = _check("undo puts the old rows back",
		((editor._current_sheet.variables["drops"] as Dictionary).get("default", []) as Array).size(), 1) and all_passed

	# Importing rows the sheet ALREADY declares is not an edit. Committing one would put a
	# do-nothing step on the undo stack, so the next Ctrl+Z appears to do nothing and the user's
	# real edit needs a second press.
	var settled: FileAccess = FileAccess.open(SHEET_CSV_PATH, FileAccess.WRITE)
	settled.store_string("item,weight,kind\ncoin,1,coin\n")
	settled.close()
	grid_dialog.open("import", entry)
	grid_dialog._csv_edit.text = SHEET_CSV_PATH
	grid_dialog._asset_edit.text = ""
	var no_op: Dictionary = grid_dialog.run()
	all_passed = _check("a no-op import is reported as one", str(no_op.get("message", "")).ends_with("Those are already the rows drops declares - nothing changed."), true) and all_passed
	all_passed = _check("and it is still a success, not an error", no_op.get("ok", false), true) and all_passed
	all_passed = _check("nothing was pushed onto the undo stack",
		editor._undo_redo_adapter.has_undo(), false) and all_passed
	all_passed = _check("the rows are of course unchanged",
		((editor._current_sheet.variables["drops"] as Dictionary).get("default", []) as Array).size(), 1) and all_passed

	# ONE dialog serves every grid on the menu, so opening it on a second variable must not leave
	# the first one's file in the form - that is how an export overwrites the wrong file while the
	# heading reads the right variable's name.
	editor._current_sheet.variables["prizes"] = EventSheets.resource_grid(["item", "weight: float"])
	var second_entry: Dictionary = {"name": "prizes", "scope": "global", "type": "Array",
		"attributes": (editor._current_sheet.variables["prizes"] as Dictionary).get("attributes", {})}
	grid_dialog.open("export", second_entry)
	all_passed = _check("the second grid gets its OWN default file", grid_dialog._csv_edit.text, "res://prizes.csv") and all_passed
	all_passed = _check("and no data asset left over from the first", grid_dialog._asset_edit.text, "") and all_passed
	all_passed = _check("the heading names the second grid", grid_dialog._grid_label.text, "prizes - columns: item, weight") and all_passed

	# The data-asset branch through the REAL button, with the resource's own property named in the
	# form: a .tres spells its grid `entries`, not after whatever sheet variable points at it.
	var asset: LootTableResource = LootTableResource.new()
	asset.entries = [{"item": "gem", "weight": 0.5, "tags": "shiny"}]
	all_passed = _check("the fixture asset saves again", ResourceSaver.save(asset, GRID_RESOURCE_PATH), OK) and all_passed
	grid_dialog.open("export", entry)
	grid_dialog._csv_edit.text = SHEET_CSV_PATH
	grid_dialog._asset_edit.text = GRID_RESOURCE_PATH
	all_passed = _check("the property field starts at the variable's name", grid_dialog._property_edit.text, "drops") and all_passed
	var mismatched: Dictionary = grid_dialog.run()
	all_passed = _check("and says so when the resource has no such grid", str(mismatched.get("message", "")),
		"\"drops\" is not a grid on this resource. It has: entries.") and all_passed
	grid_dialog._property_edit.text = "entries"
	var named: Dictionary = grid_dialog.run()
	all_passed = _check("naming the resource's own grid exports it", str(named.get("message", "")),
		"Wrote 1 row(s) to %s." % SHEET_CSV_PATH) and all_passed
	all_passed = _check("the asset's rows are what landed in the file",
		FileAccess.get_file_as_string(SHEET_CSV_PATH), "item,weight,tags\ngem,0.5,shiny\n") and all_passed
	editor.free()
	for path: String in [GRID_RESOURCE_PATH, GRID_CSV_PATH, SHEET_CSV_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return all_passed


## The SHIPPED runtime table expression, compiled and run over the same text - so the editor's
## reader is checked against the thing it promises to agree with, not against a copy of itself.
static func _runtime_table_rows(text: String) -> Array:
	var script: GDScript = GDScript.new()
	script.source_code = "extends RefCounted\n\n\nfunc parse(__source: String) -> Array:\n\treturn %s\n" % EventForgeTableACEs.table_expression("__source", "\",\"")
	script.reload()
	return script.new().parse(text)


# ── 3. Paste Special ─────────────────────────────────────────────────────────


static func _run_paste_special() -> bool:
	var all_passed: bool = true
	var editor: EventSheetEditor = EventSheetEditor.new()
	var source: EventSheetResource = EventSheetResource.new()
	source.variables["speed"] = {"type": "float", "default": 200.0, "exported": true}
	var event: EventRow = EventRow.new()
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "ExpressionIsTrue"
	condition.params = {"expression": "$Player.is_on_floor() and not $PlayerSpawner.busy"}
	event.conditions.append(condition)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetProperty"
	action.params = {"target": "$Player", "property": "velocity", "value": "speed"}
	event.actions.append(action)
	source.events.append(event)
	var snippet: Dictionary = EventSheetSnippet.deserialize(EventSheetSnippet.serialize_rows([event], source))
	var found: Dictionary = EventSheetPasteSpecial.targets(snippet)
	all_passed = _check("every object reference is offered", found.get("objects", []), ["$Player", "$PlayerSpawner"]) and all_passed
	all_passed = _check("so is every variable the snippet needs", found.get("variables", []), ["speed"]) and all_passed

	# ---- the remap: token-safe objects, renamed variable, untouched clipboard ----
	var remapped: Dictionary = EventSheetPasteSpecial.remap(snippet, {
		"objects": {"$Player": "$Enemy2"}, "variables": {"speed": "enemy_speed"}
	})
	var remapped_event: EventRow = remapped.get("rows", [])[0] as EventRow
	all_passed = _check("the retarget rewrote the reference and left its longer sibling alone",
		str((remapped_event.conditions[0] as ACECondition).params.get("expression", "")),
		"$Enemy2.is_on_floor() and not $PlayerSpawner.busy") and all_passed
	all_passed = _check("the variable reference renamed too",
		str((remapped_event.actions[0] as ACEAction).params.get("value", "")), "enemy_speed") and all_passed
	all_passed = _check("the declaration travelled under the new name",
		(remapped.get("required_variables", {}) as Dictionary).has("enemy_speed"), true) and all_passed
	all_passed = _check("the snippet on the clipboard is untouched (rows are deep copies)",
		str(((snippet.get("rows", [])[0] as EventRow).actions[0] as ACEAction).params.get("value", "")), "speed") and all_passed

	# ---- the dialog: create-missing vs reuse-existing, said in words ----
	var target: EventSheetResource = EventSheetResource.new()
	target.variables["enemy_speed"] = {"type": "float", "default": 42.0, "exported": true}
	editor.set_undo_redo_manager(RecordingUndoManager.new())
	editor.setup(target)
	editor._context_menus._build_row_more_submenu(true)
	var more_menu: PopupMenu = editor._row_more_submenu
	var paste_index: int = more_menu.get_item_index(editor.ROW_MENU_PASTE_SPECIAL)
	all_passed = _check("Paste Special sits in the row's More submenu",
		more_menu.get_item_text(paste_index) if paste_index >= 0 else "", "Paste Special…") and all_passed
	var dialog: EventSheetPasteSpecialDialog = editor._paste_special_dialog
	dialog.open(snippet)
	all_passed = _check("a name the sheet has reads as a reuse",
		EventSheetPasteSpecial.describe_variable_target(target, "enemy_speed"), "reuses this sheet's enemy_speed") and all_passed
	all_passed = _check("a name it lacks reads as a create",
		EventSheetPasteSpecial.describe_variable_target(target, "boss_speed"), "creates boss_speed") and all_passed
	dialog._object_fields[0]["edit"].text = "$Enemy2"
	dialog._variable_fields[0]["edit"].text = "enemy_speed"
	all_passed = _check("the fields describe the retarget", dialog.mapping(),
		{"objects": {"$Player": "$Enemy2", "$PlayerSpawner": "$PlayerSpawner"}, "variables": {"speed": "enemy_speed"}}) and all_passed
	all_passed = _check("the paste lands", dialog.confirm(), true) and all_passed
	var live: EventSheetResource = editor._current_sheet
	all_passed = _check("one row was pasted", live.events.size(), 1) and all_passed
	all_passed = _check("pointed at the new object",
		str(((live.events[0] as EventRow).actions[0] as ACEAction).params.get("target", "")), "$Enemy2") and all_passed
	all_passed = _check("an existing sheet variable is REUSED, never overwritten",
		(live.variables["enemy_speed"] as Dictionary).get("default", null), 42.0) and all_passed
	all_passed = _check("and the snippet's own name was not declared alongside it",
		live.variables.has("speed"), false) and all_passed
	editor._undo_redo_adapter.undo()
	all_passed = _check("undo removes the pasted rows", editor._current_sheet.events.size(), 0) and all_passed

	# ---- a missing target creates the variable instead ----
	var fresh: EventSheetResource = EventSheetResource.new()
	editor.setup(fresh)
	var second: EventSheetPasteSpecialDialog = EventSheetPasteSpecialDialog.new()
	second.init(editor)
	second.open(snippet)
	second._variable_fields[0]["edit"].text = "boss_speed"
	second.confirm()
	all_passed = _check("a name the sheet lacks is declared on paste",
		(editor._current_sheet.variables.get("boss_speed", {}) as Dictionary).get("default", null), 200.0) and all_passed
	editor.free()
	return all_passed


## Every retarget happens AT ONCE, and the ones that would corrupt the paste are refused out loud.
## Applying mappings one after another feeds each one's output to the next, which is how a SWAP
## collapses into one object and a rename onto a name the snippet already uses merges two
## declarations into one - both silent, both inside a single undo step.
static func _run_paste_special_refusals() -> bool:
	var all_passed: bool = true

	# ---- a swap is a swap ----
	var swap_sheet: EventSheetResource = EventSheetResource.new()
	var swap_event: EventRow = EventRow.new()
	var compare: ACECondition = ACECondition.new()
	compare.provider_id = "Core"
	compare.ace_id = "ExpressionIsTrue"
	compare.params = {"expression": "$Player.x > $Enemy.x"}
	swap_event.conditions.append(compare)
	swap_sheet.events.append(swap_event)
	var swap_snippet: Dictionary = EventSheetSnippet.deserialize(EventSheetSnippet.serialize_rows([swap_event], swap_sheet))
	var swapped: Dictionary = EventSheetPasteSpecial.remap(swap_snippet, {
		"objects": {"$Player": "$Enemy", "$Enemy": "$Player"}, "variables": {}
	})
	all_passed = _check("swapping two objects really swaps them",
		str(((swapped.get("rows", [])[0] as EventRow).conditions[0] as ACECondition).params.get("expression", "")),
		"$Enemy.x > $Player.x") and all_passed

	# ---- a rename onto a name the snippet already declares is refused, not merged ----
	var merge_sheet: EventSheetResource = EventSheetResource.new()
	merge_sheet.variables["speed"] = {"type": "float", "default": 200.0, "exported": true}
	merge_sheet.variables["enemy_speed"] = {"type": "float", "default": 90.0, "exported": true}
	var merge_event: EventRow = EventRow.new()
	var sum_row: ACECondition = ACECondition.new()
	sum_row.provider_id = "Core"
	sum_row.ace_id = "ExpressionIsTrue"
	sum_row.params = {"expression": "speed + enemy_speed > 0"}
	merge_event.conditions.append(sum_row)
	merge_sheet.events.append(merge_event)
	var merge_snippet: Dictionary = EventSheetSnippet.deserialize(EventSheetSnippet.serialize_rows([merge_event], merge_sheet))
	all_passed = _check("both variables travel with the snippet",
		(EventSheetPasteSpecial.targets(merge_snippet).get("variables", []) as Array), ["enemy_speed", "speed"]) and all_passed
	var merged: Dictionary = EventSheetPasteSpecial.remap(merge_snippet, {
		"objects": {}, "variables": {"speed": "enemy_speed"}
	})
	all_passed = _check("a name another copied variable holds is refused",
		str(((merged.get("rows", [])[0] as EventRow).conditions[0] as ACECondition).params.get("expression", "")),
		"speed + enemy_speed > 0") and all_passed
	all_passed = _check("so both declarations still arrive",
		(merged.get("required_variables", {}) as Dictionary).size(), 2) and all_passed
	all_passed = _check("and the dialog says so beside the field",
		EventSheetPasteSpecial.describe_variable_target(null, "enemy_speed", merge_snippet, "speed"),
		"another copied variable is already called enemy_speed - left as speed") and all_passed
	# The same rename onto a free name still works, and still reuses an existing sheet variable.
	var renamed: Dictionary = EventSheetPasteSpecial.remap(merge_snippet, {
		"objects": {}, "variables": {"speed": "hero_speed"}
	})
	all_passed = _check("a free name renames as it always did",
		str(((renamed.get("rows", [])[0] as EventRow).conditions[0] as ACECondition).params.get("expression", "")),
		"hero_speed + enemy_speed > 0") and all_passed

	# ---- an object target that is not something to point at is refused, not pasted verbatim ----
	var typo: Dictionary = EventSheetPasteSpecial.remap(swap_snippet, {
		"objects": {"$Player": "not a node!"}, "variables": {}
	})
	all_passed = _check("a typed-in typo never reaches the pasted row",
		str(((typo.get("rows", [])[0] as EventRow).conditions[0] as ACECondition).params.get("expression", "")),
		"$Player.x > $Enemy.x") and all_passed
	all_passed = _check("and the field says why",
		EventSheetPasteSpecial.describe_object_target("not a node!"),
		"not something to point at - try $Node, %Unique or self") and all_passed
	all_passed = _check("a scene-unique name is a fine target", EventSheetPasteSpecial.is_object_target("%Boss"), true) and all_passed
	all_passed = _check("so is a nested path", EventSheetPasteSpecial.is_object_target("$Enemies/Goblin"), true) and all_passed
	all_passed = _check("so is a variable holding a node", EventSheetPasteSpecial.is_object_target("enemy"), true) and all_passed
	all_passed = _check("so is self", EventSheetPasteSpecial.is_object_target("self"), true) and all_passed
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] editor_seams_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
