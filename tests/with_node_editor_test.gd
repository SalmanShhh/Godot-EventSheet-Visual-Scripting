# Godot EventSheets - "With node X:" scope, editor side (chip rendering + edit dialog).
#
# Compilation is covered by with_node_scope_test; this drives the EDITOR: a row with a with_node_target
# renders a "With node  X" chip in the condition lane, the line count accounts for it, and the dialog
# the chip / "Scope Actions To Node…" menu open writes the target back (and clears it to drop the scope).
@tool
class_name WithNodeEditorTest
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

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.with_node_target = "$Enemy"
	sheet.events.append(event)

	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()

	# Rendering: a "With node  $Enemy" chip in the condition lane, line counting in sync.
	var row_data: EventRowData = _row_for(viewport, event)
	all_passed = _check("the event row is rendered", row_data != null, true) and all_passed
	if row_data != null:
		viewport._ensure_event_spans(row_data)
		var chip_text: String = ""
		for span in row_data.spans:
			if str((span.metadata if span.metadata is Dictionary else {}).get("kind", "")) == "with_node":
				chip_text = span.text
		all_passed = _check("With-node scope renders a chip in the condition lane", chip_text, "With node  $Enemy") and all_passed
		all_passed = _check("line counting includes the scope row", viewport._count_event_lines(event), row_data.line_count) and all_passed

	# Dialog round-trip (no popup): the dialog the chip + "Scope Actions To Node…" menu open writes back.
	editor._comments._ensure_with_node_dialog()
	editor._comments._with_node_dialog_target = event
	editor._comments._with_node_target_edit.text = "$Boss"
	editor._comments._on_with_node_dialog_confirmed()
	all_passed = _check("dialog updates the scope target", event.with_node_target, "$Boss") and all_passed

	# Clearing the field drops the scope (the chip disappears, actions go back to the host).
	editor._comments._with_node_dialog_target = event
	editor._comments._with_node_target_edit.text = ""
	editor._comments._on_with_node_dialog_confirmed()
	all_passed = _check("clearing the target removes the scope", event.with_node_target, "") and all_passed
	all_passed = _check("a cleared row is no longer a With-node scope", event.is_with_node_scope(), false) and all_passed

	# Find/replace reaches into the scope target, so a renamed node/variable updates it (not a stale
	# silent reference). Mirrors the pick-filter expression handling.
	event.with_node_target = "$enemies_root"
	var counter: Dictionary = {"count": 0}
	editor._replace_in_rows([event], "enemies_root", "foes_root", counter)
	all_passed = _check("find/replace updates the scope target", event.with_node_target, "$foes_root") and all_passed
	all_passed = _check("find/replace counts the scope-target hit", int(counter.get("count", 0)) >= 1, true) and all_passed

	editor.free()
	return all_passed


## The rendered row whose source resource is `event` (robust against any leading header rows).
static func _row_for(viewport: EventSheetViewport, event: EventRow) -> EventRowData:
	for entry in viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == event:
			return row_data
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] with_node_editor_test: %s" % label)
		return true
	print("[FAIL] with_node_editor_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
