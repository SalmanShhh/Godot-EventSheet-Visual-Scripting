# EventForge — Collective enable/disable of a multi-selection
#
# Toggling enabled state acts on the whole current selection: selecting two conditions and
# toggling disables both; toggling again re-enables them.
@tool
class_name DisableSelectionTest
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
	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_id = "on_tick"
	var cond_a: ACECondition = ACECondition.new()
	cond_a.provider_id = "Core"
	cond_a.ace_id = "IsOnFloor"
	var cond_b: ACECondition = ACECondition.new()
	cond_b.provider_id = "Core"
	cond_b.ace_id = "Always"
	event.conditions.append(cond_a)
	event.conditions.append(cond_b)
	sheet.events.append(event)
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()

	var index: int = _flat_index(viewport, event)
	viewport._get_or_build_row_layout(index, viewport.get_canvas_logical_width(), viewport._get_font(), viewport._get_font_size())
	var row_data: EventRowData = viewport._row_at(index)
	var condition_spans: Array = []
	for s in range(row_data.spans.size()):
		var span: SemanticSpan = row_data.spans[s]
		if span != null and span.metadata is Dictionary and str((span.metadata as Dictionary).get("kind", "")) == "condition":
			condition_spans.append(s)
	all_passed = _check("found both condition spans", condition_spans.size(), 2) and all_passed

	# Multi-select both conditions, then toggle.
	viewport._select_from_click(index, int(condition_spans[0]), false)
	viewport._select_from_click(index, int(condition_spans[1]), true)
	editor._toggle_selected_enabled()
	all_passed = _check("both selected conditions disabled together", not cond_a.enabled and not cond_b.enabled, true) and all_passed
	editor._toggle_selected_enabled()
	all_passed = _check("toggling again re-enables both", cond_a.enabled and cond_b.enabled, true) and all_passed

	# A whole-event selection (no spans) disables the event itself.
	viewport.clear_selection()
	viewport._select_from_click(index, -1, false)
	editor._toggle_selected_enabled()
	all_passed = _check("whole-event selection disables the event", not event.enabled, true) and all_passed

	editor.free()
	return all_passed


static func _flat_index(viewport: EventSheetViewport, resource: Resource) -> int:
	var flat: Array[Dictionary] = viewport.get_flat_rows()
	for i in range(flat.size()):
		var row_data: EventRowData = flat[i].get("row")
		if row_data != null and row_data.source_resource == resource:
			return i
	return -1


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] disable_selection_test: %s" % label)
		return true
	print("[FAIL] disable_selection_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
