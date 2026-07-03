# EventForge — Tree-placed variables (movable / insertable like events)
#
# Variables can be placed directly in the event tree as LocalVariable resources: they render
# as variable rows, can be inserted below a row via the context menu, move with the normal
# row drag, and compile to class-level declarations honouring the export/const flags.
@tool
class_name TreeVariableTest
extends RefCounted


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


static func run() -> bool:
	var all_passed: bool = true

	# Compile: a tree variable emits a class-level declaration honouring its flags.
	var sheet: EventSheetResource = EventSheetResource.new()
	var tree_var: LocalVariable = LocalVariable.new()
	tree_var.name = "ammo"
	tree_var.type_name = "int"
	tree_var.default_value = 30
	tree_var.exported = true
	sheet.events.append(tree_var)
	all_passed = _check("exported tree var compiles to @export var",
		_compile(sheet).contains("@export var ammo: int = 30"), true) and all_passed
	tree_var.exported = false
	var private_output: String = _compile(sheet)
	all_passed = _check("private tree var compiles to plain var",
		private_output.contains("var ammo: int = 30") and not private_output.contains("@export var ammo"), true) and all_passed
	tree_var.is_constant = true
	all_passed = _check("constant tree var compiles to const",
		_compile(sheet).contains("const ammo: int = 30"), true) and all_passed

	# Render: a tree variable shows up as a SECTION (variable) row whose source is the resource.
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var render_sheet: EventSheetResource = EventSheetResource.new()
	var rendered_var: LocalVariable = LocalVariable.new()
	rendered_var.name = "score"
	rendered_var.type_name = "int"
	render_sheet.events.append(rendered_var)
	viewport.set_sheet(render_sheet)
	var rendered: bool = false
	for entry in viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == rendered_var and row_data.row_type == EventRowData.RowType.SECTION:
			rendered = true
	all_passed = _check("tree variable renders as a movable section row", rendered, true) and all_passed
	viewport.free()

	# Insert-below: the context-menu flow drops a variable directly after the chosen row.
	var editor: EventSheetEditor = EventSheetEditor.new()
	var edit_sheet: EventSheetResource = EventSheetResource.new()
	var anchor_event: EventRow = EventRow.new()
	anchor_event.trigger_id = "on_tick"
	edit_sheet.events.append(anchor_event)
	editor.setup(edit_sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._on_variable_dialog_confirmed("hp", "int", 100, "tree", {"insert_below": anchor_event}, false, true)
	all_passed = _check("variable inserted directly below the anchor row",
		edit_sheet.events.size() == 2 and edit_sheet.events[1] is LocalVariable and (edit_sheet.events[1] as LocalVariable).name == "hp", true) and all_passed

	# Edit-in-place updates the existing resource (name/default/export) without adding a row.
	var inserted_var: LocalVariable = edit_sheet.events[1] as LocalVariable
	editor._on_variable_dialog_confirmed("hp_max", "int", 200, "tree", {"editing": true, "variable_resource": inserted_var}, false, false)
	all_passed = _check("tree variable edited in place (no new row)",
		edit_sheet.events.size() == 2 and inserted_var.name == "hp_max" and inserted_var.default_value == 200 and not inserted_var.exported, true) and all_passed
	editor.free()

	return all_passed


static func _compile(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.compile(sheet, "user://eventforge_tree_var.gd").get("output", ""))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] tree_variable_test: %s" % label)
		return true
	print("[FAIL] tree_variable_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
