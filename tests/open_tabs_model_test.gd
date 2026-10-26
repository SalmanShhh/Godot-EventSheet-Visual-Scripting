@tool
class_name OpenTabsModelTest
extends RefCounted
# The open-tabs model on EventSheetDock (get_open_sheets_state + the recently-closed list), which
# the Start page's recent sheets and the Project bar read. Pins: the snapshot reports the open tabs,
# the active index and the dirty flags; recently closed excludes what is still open, dedups and moves
# to the front; re-selecting the active tab is a no-op; and the side panel stays put across a Split
# View toggle.


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
	var all_passed: bool = true

	# ── The model API on EventSheetDock: snapshot + recently-closed MRU ──
	var sheet_dock: EventSheetDock = EventSheetDock.new()
	var s1: EventSheetResource = EventSheetResource.new()
	var s2: EventSheetResource = EventSheetResource.new()
	sheet_dock._open_tabs = [
		{"sheet": s1, "path": "res://a.gd", "dirty": false},
		{"sheet": s2, "path": "res://b.gd", "dirty": true},
	]
	sheet_dock._active_tab_index = 1
	sheet_dock._remember_closed_path("res://a.gd")  # currently open -> must be excluded from recents
	sheet_dock._remember_closed_path("res://c.gd")  # truly closed -> should appear
	var state: Dictionary = sheet_dock.get_open_sheets_state()
	all_passed = _check("snapshot reports both open tabs", (state.get("open") as Array).size(), 2) and all_passed
	all_passed = _check("snapshot reports the active index", state.get("active"), 1) and all_passed
	all_passed = _check("a dirty tab is flagged", (state.get("open")[1] as Dictionary).get("dirty"), true) and all_passed
	all_passed = _check("recents exclude still-open sheets", state.get("recent"), ["res://c.gd"]) and all_passed

	# MRU: dedup + move-to-front + skip empty.
	sheet_dock._remember_closed_path("res://c.gd")  # re-close -> front, no duplicate
	sheet_dock._remember_closed_path("")            # nothing to reopen -> skipped
	all_passed = _check("recents dedup + move-to-front",
		sheet_dock._recent_closed_paths, ["res://c.gd", "res://a.gd"]) and all_passed

	# Re-selecting the already-active tab via the dock path must short-circuit before the reload
	# (which would clear the viewport and wipe undo history). Proxy: the activation body would
	# overwrite _current_sheet_path; the dock's early-return leaves it.
	sheet_dock._current_sheet_path = "SENTINEL"
	sheet_dock.activate_open_tab(1)  # tab 1 is already active
	all_passed = _check("re-selecting the active tab from the dock is a no-op (no reload)",
		sheet_dock._current_sheet_path, "SENTINEL") and all_passed
	sheet_dock.free()

	# ── Workspace integration: the side panel sits left of the viewport and survives Split View ──
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor.setup(EventSheetResource.new())
	var side_panel: Control = editor._workspace_body.get_child(0) as Control
	all_passed = _check("the side panel is the workspace body's left side", str(side_panel.name),
		"EventSheetLeftRail") and all_passed
	editor._multi_view._toggle_split_view()
	all_passed = _check("it stays put across a Split View toggle (viewport reparent is isolated)",
		str((editor._workspace_body.get_child(0) as Control).name), "EventSheetLeftRail") and all_passed
	editor._multi_view._toggle_split_view()  # close the split again
	editor.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("open_tabs_model_test", label, actual, expected)
