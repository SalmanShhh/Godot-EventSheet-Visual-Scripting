# EventForge — GDScript provenance (source map + side panel)
#
# The compiler emits a source map (resource instance id → 1-based generated line range);
# the dock's GDScript panel shows the generated script and highlights the selected row's
# lines. Headless-safe (the panel is plain Controls; nothing pops up).
@tool
extends RefCounted
class_name ProvenanceTest

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

	# Build a sheet exercising every mapped row kind.
	var sheet: EventSheetResource = EventSheetResource.new()
	var tree_var: LocalVariable = LocalVariable.new()
	tree_var.name = "ammo"
	tree_var.type_name = "int"
	tree_var.default_value = 3
	sheet.events.append(tree_var)
	var raw_block: RawCodeRow = RawCodeRow.new()
	raw_block.code = "signal reloaded"
	sheet.events.append(raw_block)
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "QueueFree"
	event.actions.append(action)
	sheet.events.append(event)
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = "reload"
	sheet.functions.append(event_function)

	var compile_result: Dictionary = SheetCompiler.compile(sheet, "user://eventforge_provenance.gd")
	var output_lines: PackedStringArray = str(compile_result.get("output", "")).split("\n")
	var source_map: Array = compile_result.get("source_map", [])
	all_passed = _check("compile returns a source map", not source_map.is_empty(), true) and all_passed

	var event_entry: Dictionary = _entry_for(source_map, event)
	all_passed = _check("event has a source-map entry", not event_entry.is_empty(), true) and all_passed
	if not event_entry.is_empty():
		var slice: String = _lines_slice(output_lines, event_entry)
		all_passed = _check("event range covers its generated action", slice.contains("queue_free()"), true) and all_passed
	var raw_entry: Dictionary = _entry_for(source_map, raw_block)
	all_passed = _check("raw block maps to its verbatim line",
		not raw_entry.is_empty() and _lines_slice(output_lines, raw_entry).contains("signal reloaded"), true) and all_passed
	var var_entry: Dictionary = _entry_for(source_map, tree_var)
	all_passed = _check("tree variable maps to its declaration",
		not var_entry.is_empty() and _lines_slice(output_lines, var_entry).contains("var ammo: int = 3"), true) and all_passed
	var function_entry: Dictionary = _entry_for(source_map, event_function)
	all_passed = _check("sheet function maps to its func block",
		not function_entry.is_empty() and _lines_slice(output_lines, function_entry).contains("func reload()"), true) and all_passed

	# Dock panel: toggle builds the split, shows compiled text, selection highlights lines.
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._toggle_code_panel()
	all_passed = _check("panel toggles visible", editor.is_code_panel_visible(), true) and all_passed
	all_passed = _check("panel shows the generated script", editor._code_edit.text.contains("func _process"), true) and all_passed
	all_passed = _check("viewport still reachable after split insertion", editor.get_viewport_control() != null, true) and all_passed

	var viewport: EventSheetViewport = editor.get_viewport_control()
	var event_index: int = -1
	var flat: Array[Dictionary] = viewport.get_flat_rows()
	for i in range(flat.size()):
		var row_data: EventRowData = flat[i].get("row")
		if row_data != null and row_data.source_resource == event:
			event_index = i
	viewport._select_from_click(event_index, -1, false)
	all_passed = _check("selecting the event highlights its generated lines",
		editor._code_panel_highlight.x >= 0 and editor._code_panel_highlight.y >= editor._code_panel_highlight.x, true) and all_passed
	var highlighted: String = ""
	for line in range(editor._code_panel_highlight.x, editor._code_panel_highlight.y + 1):
		highlighted += editor._code_edit.get_line(line) + "\n"
	all_passed = _check("highlighted panel lines contain the event's action", highlighted.contains("queue_free()"), true) and all_passed

	viewport.clear_selection()
	editor._update_code_panel_highlight()
	all_passed = _check("clearing selection clears the highlight", editor._code_panel_highlight, Vector2i(-1, -1)) and all_passed

	# Toggle off hides the panel.
	editor._toggle_code_panel()
	all_passed = _check("panel toggles hidden", editor.is_code_panel_visible(), false) and all_passed
	editor.free()

	return all_passed

static func _entry_for(source_map: Array, resource: Resource) -> Dictionary:
	var uid: String = str(resource.get_instance_id())
	for entry in source_map:
		if entry is Dictionary and str((entry as Dictionary).get("uid", "")) == uid:
			return entry
	return {}

static func _lines_slice(output_lines: PackedStringArray, entry: Dictionary) -> String:
	var start_line: int = int(entry.get("start", 0))
	var end_line: int = int(entry.get("end", 0))
	var slice: String = ""
	for line_number in range(start_line, end_line + 1):
		if line_number >= 1 and line_number <= output_lines.size():
			slice += output_lines[line_number - 1] + "\n"
	return slice

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] provenance_test: %s" % label)
		return true
	print("[FAIL] provenance_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
