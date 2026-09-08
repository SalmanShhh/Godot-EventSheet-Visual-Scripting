# EventForge - a tab keeps its reading: what a switch between two open sheets costs.
#
# A switch used to be a full load - every row rebuilt through the reading layers, the vocabulary
# rebuilt from the addon folder, the undo log cleared, the code panel recompiled. Each pin below is
# one half of the new promise: a tab keeps what was built for it, and builds again only when the
# sheet changed in memory or on disk.
#
#  1. Switching between two unchanged tabs builds ZERO rows (the viewport's own build counter,
#     which is monotonic and never restored, so a kept reading cannot flatter it).
#  2. An edit rebuilds once, and the switch after it still builds nothing; a tab whose revision
#     moved while it was away rebuilds exactly once when it comes back.
#  3. A file that changed on disk behind a tab rebuilds it once and says so; an unchanged one says
#     nothing at all, because a switch is not a load.
#  4. The undo stack outlives a switch, and an undo of an edit made on another tab brings that tab
#     back and lands there rather than on the sheet in front of the reader.
#  5. The vocabulary is kept when the sources match: the registry is not rebuilt and the definition
#     objects on the other side of the switch are the same objects.
#  6. The code panel's output is kept against the same revision - a switch back shows it without
#     compiling, and an edit makes it stale.
#  7. Selection and scroll come back exactly as they were left.
@tool
class_name TabRetentionTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _run_switch_costs_nothing() and all_passed
	all_passed = _run_stamp_rebuilds() and all_passed
	all_passed = _run_undo_survives() and all_passed
	all_passed = _run_registry_kept() and all_passed
	all_passed = _run_code_panel_cached() and all_passed
	all_passed = _run_selection_and_scroll() and all_passed
	return all_passed


# ── 1. A switch between two unchanged tabs builds nothing ────────────────────


static func _run_switch_costs_nothing() -> bool:
	var all_passed: bool = true
	var dock: EventSheetDock = _dock()
	var first: EventSheetResource = _sheet("first")
	var second: EventSheetResource = _sheet("second")
	dock.setup(first)
	dock._open_sheet_in_tab(second, "")
	var viewport: EventSheetViewport = dock.get_viewport_control()
	var built_before: int = viewport.row_builds()
	dock._activate_tab(0)
	var row_count: int = viewport.get_total_row_count()
	dock._activate_tab(1)
	dock._activate_tab(0)
	all_passed = _check("four switches between two unchanged tabs build no rows",
		viewport.row_builds(), built_before) and all_passed
	all_passed = _check("the tab that came back is the one on screen",
		dock.get_current_sheet(), first) and all_passed
	all_passed = _check("its rows are still there",
		viewport.get_total_row_count(), row_count) and all_passed
	# And they are ITS rows: the lists a reading is kept in are emptied in place by the next
	# build, so a kept reading that shared one came back holding the other tab's rows.
	all_passed = _check("and they are this sheet's rows, not the other tab's",
		viewport.get_row_data(0).source_resource, first.events[0]) and all_passed
	dock._set_status("")
	dock._activate_tab(1)
	all_passed = _check("a switch says nothing - it is not a load",
		dock._status_label.text, "") and all_passed
	dock.free()
	return all_passed


# ── 2 and 3. What the stamp rebuilds, and what it says ───────────────────────


static func _run_stamp_rebuilds() -> bool:
	var all_passed: bool = true
	var dock: EventSheetDock = _dock()
	var first: EventSheetResource = _sheet("first")
	dock.setup(first)
	dock._open_sheet_in_tab(_sheet("second"), "")
	var viewport: EventSheetViewport = dock.get_viewport_control()
	dock._activate_tab(0)

	# An edit builds the rows once, and the switch away and back after it builds nothing more.
	var before_edit: int = viewport.row_builds()
	var edited: bool = dock._perform_undoable_sheet_edit("Add hp", func() -> bool:
		dock._current_sheet.variables["hp"] = {"type": "int", "default": "3"}
		return true)
	all_passed = _check("the edit went through the funnel", edited, true) and all_passed
	all_passed = _check("an edit rebuilds the rows once",
		viewport.row_builds(), before_edit + 1) and all_passed
	var after_edit: int = viewport.row_builds()
	dock._activate_tab(1)
	dock._activate_tab(0)
	all_passed = _check("the switch after an edit builds nothing",
		viewport.row_builds(), after_edit) and all_passed
	all_passed = _check("the edit is still on the sheet that came back",
		dock._current_sheet.variables.has("hp"), true) and all_passed

	# A tab whose sheet changed in memory while it was away rebuilds exactly once.
	dock._activate_tab(1)
	dock._open_tabs[0]["rev"] = int(dock._open_tabs[0].get("rev", 0)) + 1
	var before_stale: int = viewport.row_builds()
	dock._activate_tab(0)
	all_passed = _check("a revision that moved while the tab was away rebuilds once",
		viewport.row_builds(), before_stale + 1) and all_passed
	dock._activate_tab(1)
	dock._activate_tab(0)
	all_passed = _check("and only once - the rebuilt reading is kept in its turn",
		viewport.row_builds(), before_stale + 1) and all_passed

	# A file that changed on disk behind the tab rebuilds it once and says which it was.
	dock._activate_tab(1)
	dock._open_tabs[0]["view"]["built_disk"] = int(dock._open_tabs[0]["view"].get("built_disk", 0)) + 7
	var before_disk: int = viewport.row_builds()
	dock._set_status("")
	dock._activate_tab(0)
	all_passed = _check("a file changed on disk rebuilds the tab once",
		viewport.row_builds(), before_disk + 1) and all_passed
	all_passed = _check("and the status line says which it was",
		dock._status_label.text, "Reloaded: changed on disk") and all_passed
	dock.free()
	return all_passed


# ── 4. The undo stack outlives a switch ──────────────────────────────────────


static func _run_undo_survives() -> bool:
	var all_passed: bool = true
	var dock: EventSheetDock = _dock()
	dock.setup(_sheet("first"))
	dock._open_sheet_in_tab(_sheet("second"), "")
	dock._activate_tab(0)
	dock._perform_undoable_sheet_edit("Add hp", func() -> bool:
		dock._current_sheet.variables["hp"] = {"type": "int", "default": "3"}
		return true)
	dock._activate_tab(1)
	dock._activate_tab(0)
	all_passed = _check("the edit survives the round trip",
		dock._current_sheet.variables.has("hp"), true) and all_passed
	all_passed = _check("and so does the step that made it",
		dock._undo_redo_adapter.has_undo(), true) and all_passed
	dock._undo_redo_adapter.undo()
	all_passed = _check("undo after a switch takes the edit back",
		dock._current_sheet.variables.has("hp"), false) and all_passed

	# And an undo pressed on the OTHER tab lands where the edit was made, never over the sheet in
	# front of the reader.
	dock._perform_undoable_sheet_edit("Add mana", func() -> bool:
		dock._current_sheet.variables["mana"] = {"type": "int", "default": "5"}
		return true)
	dock._activate_tab(1)
	all_passed = _check("the other tab is the one on screen",
		dock._active_tab_index, 1) and all_passed
	dock._undo_redo_adapter.undo()
	all_passed = _check("an undo of another tab's edit brings that tab back",
		dock._active_tab_index, 0) and all_passed
	all_passed = _check("and takes the edit back there",
		dock._current_sheet.variables.has("mana"), false) and all_passed
	all_passed = _check("the tab it was pressed on is untouched",
		(dock._open_tabs[1].get("sheet") as EventSheetResource).variables.has("mana"), false) and all_passed
	dock.free()
	return all_passed


# ── 5. The vocabulary is kept when the sources match ─────────────────────────


static func _run_registry_kept() -> bool:
	var all_passed: bool = true
	var dock: EventSheetDock = _dock()
	dock.setup(_sheet("first"))
	dock._open_sheet_in_tab(_sheet("second"), "")
	var registry: EventSheetACERegistry = dock.get_ace_registry()
	var sample: ACEDefinition = _first_definition(registry)
	var builds_before: int = dock._tab_state.registry_builds()
	dock._activate_tab(0)
	dock._activate_tab(1)
	all_passed = _check("two switches with the same sources build no vocabulary",
		dock._tab_state.registry_builds(), builds_before) and all_passed
	all_passed = _check("the registry is the same object",
		dock.get_ace_registry(), registry) and all_passed
	all_passed = _check("and so is the definition it answers with",
		dock.get_ace_registry().find_definition(sample.provider_id, sample.id), sample) and all_passed

	# A sheet that lists a provider of its own is a different vocabulary, and says so.
	var sheet_with_provider: EventSheetResource = _sheet("third")
	sheet_with_provider.ace_provider_scripts = ["res://addons/eventsheet/runtime/demo_gameplay_actor.gd"]
	dock._open_sheet_in_tab(sheet_with_provider, "")
	all_passed = _check("a sheet with its own providers rebuilds the vocabulary",
		dock._tab_state.registry_builds(), builds_before + 1) and all_passed
	dock.free()
	return all_passed


# ── 6. The code panel's output is kept against the same revision ─────────────


static func _run_code_panel_cached() -> bool:
	var all_passed: bool = true
	var dock: EventSheetDock = _dock()
	dock.setup(_sheet("first"))
	dock._open_sheet_in_tab(_sheet("second"), "")
	dock._activate_tab(0)
	dock._toggle_code_panel()
	dock._refresh_code_panel()
	var shown: String = dock._code_edit.text
	all_passed = _check("the panel compiled something", shown.is_empty(), false) and all_passed
	all_passed = _check("and the tab kept that compile",
		str(dock._tab_state.cached_code().get("text", "")), shown) and all_passed
	dock._activate_tab(1)
	dock._activate_tab(0)
	all_passed = _check("the switch back shows the same output without compiling again",
		dock._code_edit.text, shown) and all_passed
	all_passed = _check("which is the kept one",
		str(dock._tab_state.cached_code().get("text", "")), shown) and all_passed
	var edited: bool = dock._perform_undoable_sheet_edit("Add hp", func() -> bool:
		dock._current_sheet.variables["hp"] = {"type": "int", "default": "3"}
		return true)
	all_passed = _check("the edit went through the funnel", edited, true) and all_passed
	all_passed = _check("an edit makes the kept output stale, so the panel compiles again",
		dock._code_edit.text.contains("hp"), true) and all_passed
	dock.free()
	return all_passed


# ── 7. Selection and scroll come back as they were ───────────────────────────


static func _run_selection_and_scroll() -> bool:
	var all_passed: bool = true
	var dock: EventSheetDock = _dock()
	var first: EventSheetResource = _sheet("first")
	dock.setup(first)
	dock._open_sheet_in_tab(_sheet("second"), "")
	dock._activate_tab(0)
	var viewport: EventSheetViewport = dock.get_viewport_control()
	var target: Resource = first.events[2] as Resource
	all_passed = _check("the row to select was found", viewport.select_resource(target), true) and all_passed
	var selected_index: int = viewport.get_selected_row_index()
	viewport.set_scroll_offset(24)
	var scroll_left_at: int = viewport.get_scroll_offset()
	dock._activate_tab(1)
	dock._activate_tab(0)
	all_passed = _check("the selection is the row it was left on",
		viewport.get_selected_context().get("source_resource", null), target) and all_passed
	all_passed = _check("at the same index",
		viewport.get_selected_row_index(), selected_index) and all_passed
	all_passed = _check("and the scroll is where it was left",
		viewport.get_scroll_offset(), scroll_left_at) and all_passed
	dock.free()
	return all_passed


# ── Fixtures ─────────────────────────────────────────────────────────────────


static func _dock() -> EventSheetDock:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	return dock


## A small sheet the canvas draws a row for per entry, so the selection pins have rows to land on.
static func _sheet(name_hint: String) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	for index: int in range(4):
		var comment: CommentRow = CommentRow.new()
		comment.text = "%s row %d" % [name_hint, index]
		sheet.events.append(comment)
	return sheet


## The definition the identity pin uses: the first the registry lists once they are sorted, so the
## walk names none of them by hand and cannot depend on registration order.
static func _first_definition(registry: EventSheetACERegistry) -> ACEDefinition:
	var by_key: Dictionary = {}
	var keys: Array[String] = []
	for definition: ACEDefinition in registry.get_all_definitions():
		if definition == null:
			continue
		var key: String = "%s.%s" % [definition.provider_id, definition.id]
		by_key[key] = definition
		keys.append(key)
	keys.sort()
	return by_key.get(keys[0]) if not keys.is_empty() else null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("tab_retention_test", label, actual, expected)
