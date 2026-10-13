# Godot EventSheets - the Find References window: activating a result lands on the ROW it names.
#
# Each result carries the row the hit sits on (and the line that row emits at), so a double-click
# selects that row - not just the top of the sheet it lives in.
@tool
class_name FindReferencesPanelTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


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
	var ok: bool = true
	# Spelled in two halves so this file never contains the whole word the project scan looks for.
	var symbol: String = "zq_refs" + "_probe_target"
	var sheet: EventSheetResource = EventSheetResource.new()
	for text: String in ["first note", "second note", "uses %s here" % symbol]:
		var comment: CommentRow = CommentRow.new()
		comment.text = text
		sheet.events.append(comment)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._current_sheet_path = "user://find_references_panel_probe.tres"
	var view: EventSheetViewport = editor.get_viewport_control()
	view._select_row(0, -1)

	var panel: EventSheetFindReferencesPanel = editor._find_refs
	panel.open()
	panel._find_refs_edit.text = symbol
	panel._run_find_references()
	var hit: TreeItem = panel._find_refs_tree.get_root().get_first_child()
	ok = _check("the first result is in the open sheet", hit.get_metadata(0), "user://find_references_panel_probe.tres") and ok
	ok = _check("the result names the row it sits on", hit.get_metadata(1), editor._current_sheet.events[2]) and ok
	hit.select(0)
	panel._on_find_reference_activated()
	ok = _check("activating the result selects that row", view.get_selected_context().get("source_resource", null),
		editor._current_sheet.events[2]) and ok
	editor.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("find_references_panel_test", label, actual, expected)
