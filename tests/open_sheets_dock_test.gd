@tool
class_name OpenSheetsDockTest
extends RefCounted
# The Open Sheets dock (open_sheets_dock.gd) + its EventSheetDock model API. Pins: the list
# renders open + recently-closed sheets, the filter narrows by name OR path, a click maps
# back to the right tab index / path via item metadata, and the model snapshot excludes
# still-open sheets from "recently closed" (so the dock never offers to "reopen" what's open).


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

	# ── The dock control: rendering, filter, metadata, signals ──
	var dock: EventSheetOpenSheetsDock = EventSheetOpenSheetsDock.new()
	var open: Array = [
		{"title": "Player", "path": "res://player.gd", "dirty": false},
		{"title": "Combat", "path": "res://systems/combat.gd", "dirty": true},
	]
	dock.set_state(open, 1, ["res://old_ui.gd"])
	var list: ItemList = dock._list
	# 2 open + a "Recently closed" header + 1 recent = 4 rows.
	all_passed = _check("renders open + recent rows", list.item_count, 4) and all_passed
	all_passed = _check("the active sheet is selected", list.is_selected(1), true) and all_passed
	all_passed = _check("an open row carries its tab index", _meta_index(list, 0), 0) and all_passed
	all_passed = _check("the recent header is not selectable", _first_unselectable_text(list), "Recently closed") and all_passed

	# Filter narrows by title OR path, case-insensitively.
	dock._filter.text = "COMBAT"
	dock._render()
	all_passed = _check("filter keeps only matching open rows", _count_kind(dock._list, "open"), 1) and all_passed
	dock._filter.text = "systems"  # path substring, not in any title
	dock._render()
	all_passed = _check("filter also matches on path", _count_kind(dock._list, "open"), 1) and all_passed
	dock._filter.text = ""
	dock._render()

	# A click forwards the right signal payload.
	var activated: Array = []
	var reopened: Array = []
	dock.activate_requested.connect(func(i: int) -> void: activated.append(i))
	dock.reopen_requested.connect(func(p: String) -> void: reopened.append(p))
	dock._on_item_chosen(_find_open_row(dock._list, 1))  # the Combat row
	all_passed = _check("clicking an open sheet switches to its tab", activated, [1]) and all_passed
	dock._on_item_chosen(_find_recent_row(dock._list))   # the recent row
	all_passed = _check("clicking a recent sheet reopens its path", reopened, ["res://old_ui.gd"]) and all_passed

	# Empty state.
	dock.set_state([], -1, [])
	all_passed = _check("empty state shows one non-selectable hint",
		dock._list.item_count == 1 and not dock._list.is_item_selectable(0), true) and all_passed
	dock.free()

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

	# ── Collapse to a strip + restore (the minimise affordance) ──
	var cdock: EventSheetOpenSheetsDock = EventSheetOpenSheetsDock.new()
	cdock.set_collapsed(true)
	all_passed = _check("collapse hides the body + shrinks the panel",
		not cdock._body.visible and cdock.is_collapsed() and cdock.custom_minimum_size.x < 60.0, true) and all_passed
	cdock.set_collapsed(false)
	all_passed = _check("expand restores the body + width",
		cdock._body.visible and not cdock.is_collapsed() and cdock.custom_minimum_size.x >= 120.0, true) and all_passed
	cdock.free()

	# ── Workspace integration: the panel mounts left of the viewport and survives Split View ──
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor.setup(EventSheetResource.new())
	# The panel now shares the left rail (a VBox) with the Anatomy panel — assert it lives inside
	# the workspace body's subtree, not that it is a DIRECT child (the rail wrapper is layout detail).
	all_passed = _check("panel is mounted inside the workspace body",
		editor._open_sheets_panel != null and editor._workspace_body.is_ancestor_of(editor._open_sheets_panel), true) and all_passed
	editor._toggle_split_view()
	all_passed = _check("panel stays put across a Split View toggle (viewport reparent is isolated)",
		editor._workspace_body.is_ancestor_of(editor._open_sheets_panel), true) and all_passed
	editor._toggle_split_view()  # close the split again
	editor.free()

	return all_passed


static func _meta(list: ItemList, row: int) -> Dictionary:
	var m: Variant = list.get_item_metadata(row)
	return m if typeof(m) == TYPE_DICTIONARY else {}


static func _meta_index(list: ItemList, row: int) -> int:
	return int(_meta(list, row).get("index", -1))


static func _count_kind(list: ItemList, kind: String) -> int:
	var n: int = 0
	for r in range(list.item_count):
		if str(_meta(list, r).get("kind", "")) == kind:
			n += 1
	return n


static func _find_open_row(list: ItemList, tab_index: int) -> int:
	for r in range(list.item_count):
		var m: Dictionary = _meta(list, r)
		if str(m.get("kind", "")) == "open" and int(m.get("index", -1)) == tab_index:
			return r
	return -1


static func _find_recent_row(list: ItemList) -> int:
	for r in range(list.item_count):
		if str(_meta(list, r).get("kind", "")) == "recent":
			return r
	return -1


static func _first_unselectable_text(list: ItemList) -> String:
	for r in range(list.item_count):
		if not list.is_item_selectable(r):
			return list.get_item_text(r)
	return ""


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] open_sheets_dock_test: %s" % label)
		return true
	print("[FAIL] open_sheets_dock_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
