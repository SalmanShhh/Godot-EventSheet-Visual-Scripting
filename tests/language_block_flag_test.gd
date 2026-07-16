# EventForge - LANGUAGE blocks read slightly visually distinct from regular ACE events: rows that render a
# GDScript construct (a data-class holder, a methods-class, a host binding, a lifted switch case, a collapsed
# function) carry EventRowData.language_block, which the renderer draws as a quiet accent stripe + faint wash
# in the theme's `language_block_accent_color`. Pins: the flag on every built-in language block (headers AND
# their child rows), a regular ACE event NOT flagged, the theme token present on EventSheetEventStyle and set
# in every bundled preset, and the public EventSheets.mark_language_block chaining helper for custom blocks.
@tool
class_name LanguageBlockFlagTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── A sheet holding one of each language construct plus a REGULAR event ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var data_class: RawCodeRow = RawCodeRow.new()
	data_class.code = "class Stats:\n\tvar hp: int = 10"
	sheet.events.append(data_class)
	var methods_class: RawCodeRow = RawCodeRow.new()
	methods_class.code = "class Weapon:\n\tvar ammo: int = 6\n\tfunc fire() -> void:\n\t\tammo -= 1"
	sheet.events.append(methods_class)
	var regular: EventRow = EventRow.new()
	regular.trigger_provider_id = "Core"
	regular.trigger_id = "OnReady"
	var act: ACEAction = ACEAction.new()
	act.provider_id = "Core"
	act.ace_id = "QueueFree"
	regular.actions.append(act)
	sheet.events.append(regular)

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()

	var data_row: EventRowData = _row_with_uid_prefix(view, "data_class_Stats")
	ok = _check("the data-class block is flagged language_block", data_row != null and data_row.language_block, true) and ok
	if data_row != null and not data_row.children.is_empty():
		ok = _check("a data-class field row carries the flag too", data_row.children[0].language_block, true) and ok
	var methods_row: EventRowData = _row_with_uid_prefix(view, "methods_class_Weapon")
	ok = _check("the methods-class block is flagged language_block", methods_row != null and methods_row.language_block, true) and ok
	var regular_flagged: bool = false
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == regular:
			regular_flagged = row_data.language_block
	ok = _check("a regular ACE event is NOT flagged", regular_flagged, false) and ok

	# ── Switch/case rows carry the flag (built via _build_match_case_rows) ──
	var switch_sheet: EventSheetResource = EventSheetResource.new()
	switch_sheet.host_class = "Node"
	var switch_event: EventRow = EventRow.new()
	switch_event.trigger_provider_id = "Core"
	switch_event.trigger_id = "OnReady"
	var match_row: MatchRow = MatchRow.new()
	match_row.match_expression = "state"
	var match_case: MatchCase = MatchCase.new()
	match_case.pattern = "State.IDLE"
	var case_body: RawCodeRow = RawCodeRow.new()
	case_body.code = "rest()"
	match_case.events = [case_body]
	match_row.cases = [match_case] as Array[MatchCase]
	switch_event.actions.append(match_row)
	switch_sheet.events.append(switch_event)
	var dock2: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock2.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock2.setup(switch_sheet)
	var case_flagged: bool = false
	for entry: Dictionary in dock2._active_view().get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource is MatchRow:
			case_flagged = row_data.language_block
	ok = _check("a switch-case row is flagged language_block", case_flagged, true) and ok

	# ── The theme token exists, adapts, and every bundled preset sets it ──
	var style: EventSheetEventStyle = EventSheetEventStyle.new()
	ok = _check("the event style carries the language token (default = palette indigo)",
		style.language_block_accent_color, EventSheetPalette.COLOR_LANGUAGE_BLOCK) and ok
	var editor_style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	editor_style.ensure_defaults()
	EventSheetGodotTheme.apply(editor_style, Color("#252525"), Color("#1f1f1f"), Color("#1a1a1a"), Color("#569eff"), Color("#ced0d2"))
	ok = _check("a dark editor theme keeps the indigo as-is",
		editor_style.get_event_style().language_block_accent_color, EventSheetPalette.COLOR_LANGUAGE_BLOCK) and ok
	EventSheetGodotTheme.apply(editor_style, Color("#e8e8e8"), Color("#dcdcdc"), Color("#d0d0d0"), Color("#3d70b8"), Color("#222222"))
	ok = _check("a light editor theme darkens the indigo for contrast",
		editor_style.get_event_style().language_block_accent_color, EventSheetPalette.COLOR_LANGUAGE_BLOCK.darkened(0.3)) and ok
	var presets: Array[Dictionary] = EventSheetThemePresets.list_presets()
	ok = _check("bundled presets were discovered", presets.is_empty(), false) and ok
	var presets_with_token: int = 0
	for preset: Dictionary in presets:
		var loaded: EventSheetEditorStyle = ResourceLoader.load(str(preset.get("path"))) as EventSheetEditorStyle
		if loaded != null and loaded.get_event_style() != null \
				and loaded.get_event_style().language_block_accent_color != Color(EventSheetPalette.COLOR_LANGUAGE_BLOCK):
			presets_with_token += 1
	ok = _check("every bundled preset sets its own language accent (none left on the default)",
		presets_with_token, presets.size()) and ok

	# ── The public API helper chains ──
	var chained: EventRowData = EventSheets.mark_language_block(EventRowData.new())
	ok = _check("EventSheets.mark_language_block flags and returns the row",
		chained != null and chained.language_block, true) and ok
	ok = _check("mark_language_block tolerates null", EventSheets.mark_language_block(null) == null, true) and ok

	dock.free()
	dock2.free()
	return ok


static func _row_with_uid_prefix(view: EventSheetViewport, prefix: String) -> EventRowData:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and str(row_data.row_uid).begins_with(prefix):
			return row_data
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] language_block_flag_test: %s" % label)
		return true
	print("[FAIL] language_block_flag_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
