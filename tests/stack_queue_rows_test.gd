# Godot EventSheets - the stack and queue rows (Pop back into, Pop front into, Move, Swap, For each
# popped, Push back keeping the last N), what each writes, and that each opens again from the
# hand-written GDScript it writes.
#
# A stack pushes and pops at the back, a queue pushes at the back and pops at the front. Every row is a
# plain Array call; the lift reads the same call back as the row, gated by byte-exact re-emission.
@tool
class_name StackQueueRowsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "stack_queue_rows"

const HEAD := "extends Node\n\nvar undo_stack: Array[Vector2i] = []\nvar redo_stack: Array[Vector2i] = []\nvar jobs: Array = []\n\n\nfunc _ready() -> void:\n"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_pop_rows() and ok
	ok = _test_the_pop_rows_lift() and ok
	ok = _test_the_picker_groups() and ok
	ok = _test_the_fallback() and ok
	return ok


## A sheet holding one On Ready event with the given action, compiled. `template` bakes the template
## onto the row the way the dock does at apply time; blank leaves the descriptor's own to be used.
static func compiled(ace_id: String, params: Dictionary, template: String = "") -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {
		"undo_stack": {"type": "Array[Vector2i]", "default": [], "exported": false},
		"redo_stack": {"type": "Array[Vector2i]", "default": [], "exported": false},
		"jobs": {"type": "Array", "default": [], "exported": false}
	}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.codegen_template = template
	action.params = params
	event.actions.append(action)
	sheet.events.append(event)
	return SUPPORT.compile_output(sheet, "user://%s_compiled.gd" % NAME)


static func _test_the_fallback() -> bool:
	var ok: bool = true
	# Blank: the plain pop (and the description says to guard it). Filled: safe on its own.
	var plain: String = compiled("ArrayPopBackInto", {"var_name": "undo_stack", "name": "last", "fallback": ""})
	ok = SUPPORT.check(NAME, "a blank If Empty writes the plain pop", plain.contains("\tvar last = undo_stack.pop_back()\n"), true) and ok
	var safe: String = compiled("ArrayPopBackInto", {"var_name": "undo_stack", "name": "last", "fallback": "Vector2i(-1, -1)"})
	ok = SUPPORT.check(NAME, "a filled If Empty carries its own fallback",
		safe.contains("\tvar last = undo_stack.pop_back() if not undo_stack.is_empty() else Vector2i(-1, -1)\n"), true) and ok
	var queue: String = compiled("ArrayPopFrontInto", {"var_name": "jobs", "name": "job", "fallback": "null"})
	ok = SUPPORT.check(NAME, "the front pop takes the same field",
		queue.contains("\tvar job = jobs.pop_front() if not jobs.is_empty() else null\n"), true) and ok
	# A row saved before the field existed has no value for it and still writes the plain pop.
	var old_row: String = compiled("ArrayPopBackInto", {"var_name": "undo_stack", "name": "last"})
	ok = SUPPORT.check(NAME, "a row saved without the field writes the plain pop", old_row.contains("\tvar last = undo_stack.pop_back()\n"), true) and ok
	# Both spellings open as the row, and save back as written.
	var with_fallback: Dictionary = reopened("\tvar last = undo_stack.pop_back() if not undo_stack.is_empty() else Vector2i(-1, -1)\n\tprint(last)\n")
	ok = SUPPORT.check(NAME, "a guarded one-line pop opens as Pop back into", with_fallback["ids"].has("ArrayPopBackInto"), true) and ok
	ok = SUPPORT.check(NAME, "...with its fallback read", _first_param(with_fallback["sheet"], "fallback"), "Vector2i(-1, -1)") and ok
	ok = SUPPORT.check(NAME, "...and saves back byte for byte", with_fallback["again"], with_fallback["source"]) and ok
	# The pooled spawn keeps its own reading: a fallback that builds a scene is not claimed here.
	var pooled: Dictionary = reopened("\tvar b = jobs.pop_back() if not jobs.is_empty() else load(\"res://x.tscn\").instantiate()\n\tprint(b)\n")
	ok = SUPPORT.check(NAME, "a pop whose fallback builds a scene is left to its own reading", pooled["ids"].has("ArrayPopBackInto"), false) and ok
	# The expression twins: Back and Front, or a fallback. The old rows are untouched.
	ok = SUPPORT.check(NAME, "First Item is the row it always was", _descriptor("ArrayFront").codegen_template, "{var_name}.front()") and ok
	ok = SUPPORT.check(NAME, "Last Item is the row it always was", _descriptor("ArrayBack").codegen_template, "{var_name}.back()") and ok
	var front: String = ActionCodegen._apply_template(_descriptor("ArrayFrontOr").codegen_template, {"var_name": "jobs", "fallback": "null"})
	ok = SUPPORT.check(NAME, "First Item (or a fallback) guards the read", front, "(jobs.front() if not jobs.is_empty() else null)") and ok
	var back: String = ActionCodegen._apply_template(_descriptor("ArrayBackOr").codegen_template, {"var_name": "undo_stack", "fallback": "Vector2i.ZERO"})
	ok = SUPPORT.check(NAME, "Last Item (or a fallback) guards the read", back, "(undo_stack.back() if not undo_stack.is_empty() else Vector2i.ZERO)") and ok
	return ok


## One value of the first pop or move row a sheet holds, or "" when there is none.
static func _first_param(sheet: EventSheetResource, param_id: String) -> String:
	var found: Array = []
	_find_action(sheet.events, found)
	return "" if found.is_empty() else str((found[0] as ACEAction).params.get(param_id, ""))


static func _find_action(entries: Array, found: Array) -> void:
	for entry: Variant in entries:
		if entry is EventRow:
			for action: Variant in (entry as EventRow).actions:
				if action is ACEAction and str((action as ACEAction).ace_id).begins_with("Array"):
					found.append(action)
			_find_action((entry as EventRow).sub_events, found)
		elif entry is EventGroup:
			_find_action((entry as EventGroup).events, found)


## The ace ids of every action in a sheet's events, nested rows included.
static func ace_ids(sheet: EventSheetResource) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	_collect(sheet.events, found)
	return found


static func _collect(entries: Array, found: PackedStringArray) -> void:
	for entry: Variant in entries:
		if entry is EventRow:
			for action: Variant in (entry as EventRow).actions:
				if action is ACEAction:
					found.append((action as ACEAction).ace_id)
			_collect((entry as EventRow).sub_events, found)
		elif entry is EventGroup:
			_collect((entry as EventGroup).events, found)


## The sheet a source reopens as and the bytes it writes again, so one call answers both questions.
static func reopened(body: String) -> Dictionary:
	var source: String = HEAD + body
	var sheet: EventSheetResource = SUPPORT.reopen(source)
	return {"source": source, "ids": ace_ids(sheet), "again": SUPPORT.reemit(source, "user://%s.gd" % NAME), "sheet": sheet}


static func _descriptor(ace_id: String) -> ACEDescriptor:
	return ACERegistry.find_descriptor("Core", ace_id)


static func _test_the_pop_rows() -> bool:
	var ok: bool = true
	for pair: Array in [["ArrayPopBackInto", "var {name} = {var_name}.pop_back(){?fallback} if not {var_name}.is_empty() else {fallback}{/fallback}"], ["ArrayPopFrontInto", "var {name} = {var_name}.pop_front(){?fallback} if not {var_name}.is_empty() else {fallback}{/fallback}"]]:
		var descriptor: ACEDescriptor = _descriptor(str(pair[0]))
		ok = SUPPORT.check(NAME, "%s exists" % pair[0], descriptor != null, true) and ok
		if descriptor == null:
			continue
		ok = SUPPORT.check(NAME, "%s writes the plain Array call" % pair[0], descriptor.codegen_template, pair[1]) and ok
		ok = SUPPORT.check(NAME, "%s is an action in the Array page" % pair[0],
			[descriptor.ace_type, descriptor.category], [ACEDescriptor.ACEType.ACTION, "Variables: Array"]) and ok
		ok = SUPPORT.check(NAME, "%s says to guard it with Is empty, inverted" % pair[0],
			descriptor.description.contains("Array Is Empty, inverted"), true) and ok
	# Push back is the row it always was.
	ok = SUPPORT.check(NAME, "Push back is unchanged", _descriptor("ArrayAppend").codegen_template, "{var_name}.append({value})") and ok
	return ok


static func _test_the_pop_rows_lift() -> bool:
	var ok: bool = true
	var back: Dictionary = reopened("\tvar last = undo_stack.pop_back()\n\tprint(last)\n")
	ok = SUPPORT.check(NAME, "a hand-written pop back opens as Pop back into", back["ids"].has("ArrayPopBackInto"), true) and ok
	ok = SUPPORT.check(NAME, "...and saves back byte for byte", back["again"], back["source"]) and ok
	var front: Dictionary = reopened("\tvar job = jobs.pop_front()\n\tprint(job)\n")
	ok = SUPPORT.check(NAME, "a hand-written pop front opens as Pop front into", front["ids"].has("ArrayPopFrontInto"), true) and ok
	ok = SUPPORT.check(NAME, "...and saves back byte for byte (front)", front["again"], front["source"]) and ok
	return ok


static func _test_the_picker_groups() -> bool:
	var ok: bool = true
	var shelves: Array[Dictionary] = ACEPickerDialog.stack_queue_shelves()
	ok = SUPPORT.check(NAME, "two groups, Stack then Queue",
		[str(shelves[0]["group"]), str(shelves[1]["group"])], ["Variables: Array: Stack", "Variables: Array: Queue"]) and ok
	ok = SUPPORT.check(NAME, "a stack is push back, pop back into, back",
		Array(shelves[0]["aces"]), ["ArrayAppend", "ArrayPopBackInto", "ArrayBack", "ArrayBackOr"]) and ok
	ok = SUPPORT.check(NAME, "a queue is push back, pop front into, front",
		Array(shelves[1]["aces"]), ["ArrayAppend", "ArrayPopFrontInto", "ArrayFront", "ArrayFrontOr"]) and ok
	ok = SUPPORT.check(NAME, "the Stack group says what a stack is",
		EventSheetSectionInfo.description_for("Variables: Array: Stack"), "A stack pushes and pops at the back: last in, first out.") and ok
	ok = SUPPORT.check(NAME, "the Queue group says what a queue is",
		EventSheetSectionInfo.description_for("Variables: Array: Queue"), "A queue pushes at the back and pops at the front: first in, first out.") and ok
	ok = SUPPORT.check(NAME, "a group nests inside the Array folder",
		Array(ACEPickerDialog.split_subcategory("Variables: Array: Stack")), ["Variables", "Array: Stack"]) and ok
	return ok
