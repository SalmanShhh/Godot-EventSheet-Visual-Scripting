# EventForge — Reorder a condition/action by dragging (full viewport path)
#
# Drives the real press -> motion -> release drag on the viewport and asserts that dragging
# the top condition onto the lower half of the bottom condition reorders them (the insert
# position must be decided by the vertical cursor position, since cells stack vertically).
@tool
extends RefCounted
class_name ACEReorderDragTest

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
	var width: float = viewport.get_canvas_logical_width()
	viewport._get_or_build_row_layout(index, width, viewport._get_font(), viewport._get_font_size())
	var row_data: EventRowData = viewport._row_at(index)
	var a_rect: Rect2 = _cell_rect(row_data, 0)
	var b_rect: Rect2 = _cell_rect(row_data, 1)
	all_passed = _check("both condition cells laid out", a_rect.size.x > 0.0 and b_rect.size.x > 0.0, true) and all_passed
	all_passed = _check("cell B is below cell A", b_rect.position.y > a_rect.position.y, true) and all_passed

	# Drag A onto the lower half of B -> "after" -> [B, A].
	var start: Vector2 = a_rect.get_center()
	var drop: Vector2 = Vector2(b_rect.get_center().x, b_rect.position.y + b_rect.size.y * 0.8)
	viewport._handle_mouse_button(_button(start, true))
	all_passed = _check("ace drag started", not viewport._drag_ace_entries.is_empty(), true) and all_passed
	viewport._handle_mouse_motion(_motion(drop))
	all_passed = _check("insert mode resolves to 'after' for lower-half drop", viewport._drag_ace_insert_mode, "after") and all_passed
	viewport._handle_mouse_button(_button(drop, false))
	all_passed = _check("conditions reordered to [B, A] after drag", event.conditions[0] == cond_b and event.conditions[1] == cond_a, true) and all_passed

	editor.free()
	return all_passed

static func _cell_rect(row_data: EventRowData, ace_index: int) -> Rect2:
	for span in row_data.spans:
		if span == null or not (span.metadata is Dictionary):
			continue
		var meta: Dictionary = span.metadata
		if str(meta.get("kind", "")) == "condition" and int(meta.get("ace_index", -1)) == ace_index:
			return span.rect
	return Rect2()

static func _button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	return event

static func _motion(at: Vector2) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = at
	return event

static func _flat_index(viewport: EventSheetViewport, resource: Resource) -> int:
	var flat: Array[Dictionary] = viewport.get_flat_rows()
	for i in range(flat.size()):
		var row_data: EventRowData = flat[i].get("row")
		if row_data != null and row_data.source_resource == resource:
			return i
	return -1

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ace_reorder_drag_test: %s" % label)
		return true
	print("[FAIL] ace_reorder_drag_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
