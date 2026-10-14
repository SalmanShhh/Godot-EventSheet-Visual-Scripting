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
	# The tab carries the same path, as a sheet opened from that file would.
	for tab: Dictionary in editor._open_tabs:
		tab["path"] = editor._current_sheet_path
	var view: EventSheetViewport = editor.get_viewport_control()
	view._select_row(0, -1)

	var panel: EventSheetFindReferencesPanel = editor._find_refs
	panel.open()
	panel._find_refs_edit.text = symbol
	var total: int = panel._run_find_references()
	var sheet_items: Array[TreeItem] = panel._find_refs_tree.get_root().get_children()
	# Only the open sheet is pinned: a compiled copy of it may sit in the project as well.
	var sheet_item: TreeItem = sheet_items.filter(func(item: TreeItem) -> bool:
		return item.get_metadata(0) == "user://find_references_panel_probe.tres")[0]
	var hit: TreeItem = sheet_item.get_first_child()
	ok = SUPPORT.pins("find_references_panel_test", [
		["the results group under the sheet they sit in", sheet_item.get_text(0), "find_references_panel_probe.tres"],
		["…which counts its uses", sheet_item.get_text(1), "1 reference(s)"],
		["the use itself sits under its sheet", hit.get_metadata(0), "user://find_references_panel_probe.tres"],
		["the count is said under the results", panel._find_refs_count.text,
			"%d reference(s) in %d sheet(s)" % [total, sheet_items.size()]],
		["the window is named after the symbol", panel._find_refs_window.title, "Find every use of %s" % symbol],
		["Go to Row waits for a pick", panel._find_refs_window.get_ok_button().disabled, true],
	]) and ok
	ok = _check("the result names the row it sits on", hit.get_metadata(1), editor._current_sheet.events[2]) and ok
	hit.select(0)
	ok = SUPPORT.pins("find_references_panel_test", [
		["picking a use wakes Go to Row", panel._find_refs_window.get_ok_button().disabled, false],
		["…and the strip names it", panel._find_refs_this_row.text, "comment ×1, in find_references_panel_probe.tres."],
	]) and ok
	panel._on_find_reference_activated()
	ok = _check("activating the result selects that row", view.get_selected_context().get("source_resource", null),
		editor._current_sheet.events[2]) and ok
	editor.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("find_references_panel_test", label, actual, expected)
