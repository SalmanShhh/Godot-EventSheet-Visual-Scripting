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
	return ok


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
	for pair: Array in [["ArrayPopBackInto", "var {name} = {var_name}.pop_back()"], ["ArrayPopFrontInto", "var {name} = {var_name}.pop_front()"]]:
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
		Array(shelves[0]["aces"]), ["ArrayAppend", "ArrayPopBackInto", "ArrayBack"]) and ok
	ok = SUPPORT.check(NAME, "a queue is push back, pop front into, front",
		Array(shelves[1]["aces"]), ["ArrayAppend", "ArrayPopFrontInto", "ArrayFront"]) and ok
	ok = SUPPORT.check(NAME, "the Stack group says what a stack is",
		EventSheetSectionInfo.description_for("Variables: Array: Stack"), "A stack pushes and pops at the back: last in, first out.") and ok
	ok = SUPPORT.check(NAME, "the Queue group says what a queue is",
		EventSheetSectionInfo.description_for("Variables: Array: Queue"), "A queue pushes at the back and pops at the front: first in, first out.") and ok
	ok = SUPPORT.check(NAME, "a group nests inside the Array folder",
		Array(ACEPickerDialog.split_subcategory("Variables: Array: Stack")), ["Variables", "Array: Stack"]) and ok
	return ok
