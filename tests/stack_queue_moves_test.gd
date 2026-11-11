# Godot EventSheets - moving between two lists: Move back / front to, Move all to, Swap, and the
# Array dropdown that offers another object's arrays beside the sheet's own.
#
# Each row is plain Array code the lift reads straight back. Swap writes its temporary with an id the
# dock bakes at apply time, so two swaps in one event never collide; two typed arrays of different
# element types are refused in the parameters window with one line naming both types.
@tool
class_name StackQueueMovesTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const ROWS := preload("res://tests/stack_queue_rows_test.gd")
const NAME := "stack_queue_moves"

const FIXTURE_SCENE_SCRIPT: String = "res://tests/fixtures/stack_queue/table.gd"
const REFUSAL: String = "undo_stack is Array[Vector2i] and scores is Array[int], and a typed array only holds its own type."


static func run() -> bool:
	var ok: bool = true
	ok = _test_moves_and_swap() and ok
	ok = _test_other_objects_arrays() and ok
	ok = _test_the_swap_refusal() and ok
	return ok


static func _test_moves_and_swap() -> bool:
	var ok: bool = true
	ok = SUPPORT.check(NAME, "Move back writes append of pop_back",
		ROWS.compiled("ArrayMoveBack", {"var_name": "undo_stack", "to": "redo_stack"}).contains("\tredo_stack.append(undo_stack.pop_back())\n"), true) and ok
	ok = SUPPORT.check(NAME, "Move front writes append of pop_front",
		ROWS.compiled("ArrayMoveFront", {"var_name": "jobs", "to": "undo_stack"}).contains("\tundo_stack.append(jobs.pop_front())\n"), true) and ok
	ok = SUPPORT.check(NAME, "Move all appends the lot, then empties the first",
		ROWS.compiled("ArrayMoveAll", {"var_name": "redo_stack", "other": "undo_stack"}).contains("\tundo_stack.append_array(redo_stack)\n\tredo_stack.clear()\n"), true) and ok
	var swapped: String = ROWS.compiled("ArraySwap", {"var_name": "undo_stack", "other": "redo_stack"},
		"var __swap_k3f9 = {var_name}\n{var_name} = {other}\n{other} = __swap_k3f9")
	ok = SUPPORT.check(NAME, "Swap is three lines through a temporary",
		swapped.contains("\tvar __swap_k3f9 = undo_stack\n\tundo_stack = redo_stack\n\tredo_stack = __swap_k3f9\n"), true) and ok
	var generated: GDScript = GDScript.new()
	generated.source_code = swapped
	ok = SUPPORT.check(NAME, "a swap of two arrays parses", generated.reload(true), OK) and ok
	ok = SUPPORT.check(NAME, "Swap's template carries the id the dock bakes at apply time",
		ROWS._descriptor("ArraySwap").codegen_template.contains("__swap_{uid}"), true) and ok
	# Each spelling, written by hand, opens as its row and saves back as written.
	for case: Array in [
		["Move back", "\tredo_stack.append(undo_stack.pop_back())\n", "ArrayMoveBack"],
		["Move front", "\tredo_stack.append(jobs.pop_front())\n", "ArrayMoveFront"],
		["Move all", "\tredo_stack.append_array(undo_stack)\n\tundo_stack.clear()\n", "ArrayMoveAll"],
		["Swap", "\tvar __swap_k3f9 = undo_stack\n\tundo_stack = redo_stack\n\tredo_stack = __swap_k3f9\n", "ArraySwap"],
		["Swap with another object's list", "\tvar __swap := undo_stack\n\tundo_stack = $Enemy.undo_stack\n\t$Enemy.undo_stack = __swap\n", "ArraySwap"],
	]:
		var opened: Dictionary = ROWS.reopened(str(case[1]))
		ok = SUPPORT.check(NAME, "a hand-written %s opens as %s" % [case[0], case[2]], opened["ids"], PackedStringArray([case[2]])) and ok
		ok = SUPPORT.check(NAME, "...and saves back byte for byte (%s)" % case[0], opened["again"], opened["source"]) and ok
	# The shapes that differ stay as they are today.
	var plain_swap: Dictionary = ROWS.reopened("\tvar tmp := undo_stack\n\tundo_stack = redo_stack\n\tredo_stack = tmp\n")
	ok = SUPPORT.check(NAME, "a swap through any other temporary is not claimed", plain_swap["ids"].has("ArraySwap"), false) and ok
	ok = SUPPORT.check(NAME, "...and still saves back byte for byte", plain_swap["again"], plain_swap["source"]) and ok
	var lone: Dictionary = ROWS.reopened("\tredo_stack.append_array(undo_stack)\n")
	ok = SUPPORT.check(NAME, "an append_array with no clear is the Append Array row", lone["ids"], PackedStringArray(["ArrayAppendArray"])) and ok
	return ok


static func _test_other_objects_arrays() -> bool:
	var ok: bool = true
	EventSheetScriptMembers.clear_cache()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE_SCENE_SCRIPT)
	var expressions: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventSheetScriptMembers.other_arrays(sheet):
		expressions.append(str(entry["expression"]))
	ok = SUPPORT.check(NAME, "another object's typed arrays are offered by path", expressions.has("$Enemy.cards"), true) and ok
	ok = SUPPORT.check(NAME, "a scene-unique node is offered as %Name", expressions.has("%Deck.cards"), true) and ok
	ok = SUPPORT.check(NAME, "an untyped `= []` list is an array too", expressions.has("$Enemy.names"), true) and ok
	ok = SUPPORT.check(NAME, "a number is not an array", expressions.has("$Enemy.score"), false) and ok
	ok = SUPPORT.check(NAME, "a private list is not offered", expressions.has("$Enemy._hidden"), false) and ok
	ok = SUPPORT.check(NAME, "the sheet's own arrays are left to the sheet's own variables", expressions.has("draw_pile"), false) and ok
	ok = SUPPORT.check(NAME, "the declared type comes with it",
		EventSheetArrayTypes.declared_type(sheet, "$Enemy.cards"), "Array[int]") and ok
	# The parameters window's dropdown offers them after the sheet's own.
	sheet.variables = {"draw_pile": {"type": "Array[int]", "default": [], "exported": false}}
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	dialog._variable_names = PackedStringArray(["draw_pile"])
	var items: PackedStringArray = _items_of(dialog._create_variable_reference_field("var_name", "draw_pile", "variable_reference:Array"))
	ok = SUPPORT.check(NAME, "the Array dropdown lists the sheet's own first", items[0] if not items.is_empty() else "", "draw_pile") and ok
	ok = SUPPORT.check(NAME, "...then another object's arrays", items.has("$Enemy.cards") and items.has("%Deck.cards"), true) and ok
	var kept: PackedStringArray = _items_of(dialog._create_variable_reference_field("var_name", "$Gone.cards", "variable_reference:Array"))
	ok = SUPPORT.check(NAME, "a row that names an array the scene no longer proves keeps it", kept.has("$Gone.cards"), true) and ok
	var dictionaries: PackedStringArray = _items_of(dialog._create_variable_reference_field("var_name", "", "variable_reference:Dictionary"))
	ok = SUPPORT.check(NAME, "a Dictionary dropdown does not list them", dictionaries.has("$Enemy.cards"), false) and ok
	return ok


static func _items_of(field: Control) -> PackedStringArray:
	var items: PackedStringArray = PackedStringArray()
	if field is OptionButton:
		for index: int in (field as OptionButton).item_count:
			items.append((field as OptionButton).get_item_text(index))
	return items


static func _test_the_swap_refusal() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {
		"undo_stack": {"type": "Array[Vector2i]", "default": [], "exported": false},
		"scores": {"type": "Array[int]", "default": [], "exported": false},
		"more_scores": {"type": "Array[int]", "default": [], "exported": false},
		"anything": {"type": "Array", "default": [], "exported": false}
	}
	ok = SUPPORT.check(NAME, "two typed arrays of different element types are refused, naming both",
		EventSheetArrayTypes.swap_problem(sheet, "undo_stack", "scores"), REFUSAL) and ok
	ok = SUPPORT.check(NAME, "the same element type may trade places", EventSheetArrayTypes.swap_problem(sheet, "scores", "more_scores"), "") and ok
	ok = SUPPORT.check(NAME, "an untyped array on either side is the plain Array every row takes",
		EventSheetArrayTypes.swap_problem(sheet, "undo_stack", "anything"), "") and ok
	# The same answer in the parameters window: the second field wears the note and OK is refused.
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([] as Array[Object], true)
	dialog._definition = registry.find_definition("Core", "ArraySwap")
	var first: LineEdit = LineEdit.new()
	first.text = "undo_stack"
	var second: LineEdit = LineEdit.new()
	second.text = "scores"
	dialog._fields = {"var_name": first, "other": second}
	var note: Dictionary = dialog._swap_type_note()
	ok = SUPPORT.check(NAME, "the window names both types in one line", str(note.get("body", "")), REFUSAL) and ok
	ok = SUPPORT.check(NAME, "and it is an error, so OK is refused", str(note.get("level", "")), EventSheetParamFieldFactory.LEVEL_ERROR) and ok
	second.text = "undo_stack"
	ok = SUPPORT.check(NAME, "the same type clears it", dialog._swap_type_note().is_empty(), true) and ok
	first.free()
	second.free()
	return ok
