# Godot EventSheets — Paste GDScript as events
# Raw GDScript pasted into a sheet converts through the open-as-sheet pipeline: trigger
# functions ACE-lift into real events, declarations become variable rows, everything else
# stays verbatim GDScript blocks (lossless). Non-code clipboard text is left to the other
# paste paths.
@tool
extends RefCounted
class_name GDScriptPasteTest

class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass

const PASTED_SCRIPT := """var hp: int = 100

func _process(delta: float) -> void:
	if is_on_floor():
		queue_free()
"""

static func run() -> bool:
	var all_passed: bool = true
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var sheet: EventSheetResource = editor.get_current_sheet()

	# Non-code text falls through (other paste paths handle it).
	all_passed = _check("prose is not treated as GDScript", editor._paste_gdscript_text("hello there, this is not code"), false) and all_passed
	all_passed = _check("empty clipboard falls through", editor._paste_gdscript_text("   "), false) and all_passed

	# Real GDScript converts: variable row lifted, trigger function becomes a real event.
	all_passed = _check("GDScript paste converts", editor._paste_gdscript_text(PASTED_SCRIPT), true) and all_passed
	editor._refresh_after_edit()
	var lifted_event: EventRow = null
	var lifted_variable: LocalVariable = null
	for row in sheet.events:
		if row is EventRow:
			lifted_event = row
		elif row is LocalVariable:
			lifted_variable = row
	all_passed = _check("declaration lifts to a variable row", lifted_variable != null and lifted_variable.name == "hp", true) and all_passed
	all_passed = _check("trigger function lifts to an event", lifted_event != null and lifted_event.trigger_id == "OnProcess", true) and all_passed
	if lifted_event != null:
		all_passed = _check("condition reverse-matched", lifted_event.conditions.size() == 1 and lifted_event.conditions[0].ace_id == "IsOnFloor", true) and all_passed
		all_passed = _check("pasted event gets a fresh uid", lifted_event.event_uid.is_empty(), false) and all_passed

	# Statement-only code pastes as a verbatim block row (no trigger to convert).
	var statements_editor: EventSheetEditor = EventSheetEditor.new()
	statements_editor.setup(EventSheetResource.new())
	statements_editor.set_undo_redo_manager(NoopUndoManager.new())
	all_passed = _check("loose declarations still paste", statements_editor._paste_gdscript_text("var speed := 5.0\nvar jump := 2"), true) and all_passed
	statements_editor._refresh_after_edit()
	var block_rows: int = 0
	for row in statements_editor.get_current_sheet().events:
		if row is RawCodeRow or row is LocalVariable:
			block_rows += 1
	all_passed = _check("loose code lands as rows", block_rows > 0, true) and all_passed

	editor.free()
	statements_editor.free()
	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] gdscript_paste_test: %s" % label)
		return true
	print("[FAIL] gdscript_paste_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
