# Godot EventSheets - The globals a sheet USES, as rows at the top of it.
#
# A global is declared once, on an autoload, and read everywhere. Until these rows the only way to
# see which ones a sheet touched was to read every parameter in it: the declaration lived in another
# file and the sheet showed nothing at all. Now the sheet opens with one row per `Game.X` it names -
# `Global number Score = 0`, `from Game` trailing it, `Game.Score` echoed at the right edge, which is
# the form you would type here - and a hairline under the last of them separates what this file
# BORROWS from what it declares.
#
# The covenant this pins is that the rows are a READING: inert (no source resource), nothing added to
# `sheet.events`, nothing emitted, no cell that edits here - the declaration can only change where it
# is written, so the edit gesture carries the path of the file that declares it.
#
# VALUES are pinned, not counts: a count would still pass if the row said the wrong words.
@tool
class_name GlobalsUsedHereRowsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PROBE_SCRIPT := "user://eventforge_used_here_rows_probe.gd"
const PROBE_AUTOLOAD := "autoload/EventSheetsUsedHereGame"
const PROBE_NAME := "EventSheetsUsedHereGame"


static func run() -> bool:
	var ok: bool = true
	var handle: FileAccess = FileAccess.open(PROBE_SCRIPT, FileAccess.WRITE)
	handle.store_string("extends Node\n\nvar Score: int = 0\nvar Muted := false\nvar Lives := 3\n")
	handle.close()
	var had_setting: bool = ProjectSettings.has_setting(PROBE_AUTOLOAD)
	ProjectSettings.set_setting(PROBE_AUTOLOAD, "*" + PROBE_SCRIPT)

	var view: EventSheetViewport = _view(_sheet_using_globals())
	var rows: Array = view.get_flat_rows()
	var score_row: EventRowData = _row_at(rows, 0)
	ok = _check("the sheet opens on the global it uses, read as one sentence",
		_texts(score_row),
		"x | Global | whole number | Score | = | 0 | from %s | %s.Score" % [PROBE_NAME, PROBE_NAME]) and ok
	ok = _check("a second global reads the same way, with its own declared value",
		_texts(_row_at(rows, 1)),
		"x | Global | boolean | Muted | = | false | from %s | %s.Muted" % [PROBE_NAME, PROBE_NAME]) and ok
	ok = _check("the last of them closes the block with a hairline",
		"%s|%s|%s" % [_row_at(rows, 0).rule_below, _row_at(rows, 1).rule_below,
			_row_at(rows, 2).rule_below], "false|false|true") and ok
	# A PICKED row files the object and the property in separate cells, which is how `Game.Score = 0`
	# is stored once it has been through the picker - there is no `Game.Score` string anywhere in it.
	# `Lives := 3` declares no type, so the type word is the one its VALUE settles.
	ok = _check("a global named across two cells of one row is found too",
		_texts(_row_at(rows, 2)),
		"x | Global | number | Lives | = | 3 | from %s | %s.Lives" % [PROBE_NAME, PROBE_NAME]) and ok
	ok = _check("...and only the cells the autoload actually declares are read that way",
		_has_uid_prefix(rows, "variable_used_global_%s_hp" % PROBE_NAME), false) and ok
	ok = _check("the sheet's own variable follows, below the line",
		_texts(_row_at(rows, 3)), "x | Instance | whole number | hp | = | 100 | var hp: int = 100") and ok

	# ── The covenant: a reading, not a declaration ──
	ok = _check("the row is inert - nothing addresses it, so nothing can write through it",
		score_row.source_resource, null) and ok
	ok = _check("nothing was added to the sheet",
		_sheet_using_globals().events.size(), 2) and ok
	ok = _check("no cell of it edits here",
		_has_editable_span(score_row), false) and ok
	ok = _check("it carries the file that declares it, so editing opens that file",
		str(_meta(score_row).get("include_path", "")), PROBE_SCRIPT) and ok
	view.free()

	# ── Where the rows are NOT drawn ──
	var quiet: EventSheetResource = EventSheetResource.new()
	quiet.host_class = "Node2D"
	var quiet_view: EventSheetViewport = _view(quiet)
	ok = _check("a sheet that names no global grows no rows",
		_has_uid_prefix(quiet_view.get_flat_rows(), "variable_used_global_"), false) and ok
	quiet_view.free()

	var declaring: EventSheetResource = _sheet_using_globals()
	declaring.autoload_mode = true
	declaring.autoload_name = PROBE_NAME
	var declaring_view: EventSheetViewport = _view(declaring)
	ok = _check("the autoload that DECLARES them lists none - its own globals are already its rows",
		_has_uid_prefix(declaring_view.get_flat_rows(), "variable_used_global_"), false) and ok
	declaring_view.free()

	var preview: EventSheetResource = _sheet_using_globals()
	preview.read_only = true
	var preview_view: EventSheetViewport = _view(preview)
	ok = _check("a read-only preview lists none - its head gathers the same globals into one folder",
		_has_uid_prefix(preview_view.get_flat_rows(), "variable_used_global_"), false) and ok
	preview_view.free()

	if not had_setting:
		ProjectSettings.set_setting(PROBE_AUTOLOAD, null)
	return ok


## A sheet that declares `hp` and reads one global in an action parameter.
static func _sheet_using_globals() -> EventSheetResource:
	var sheet := EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "Player"
	sheet.variables["hp"] = {"type": "int", "default": 100, "exported": false}
	var event := EventRow.new()
	var action := ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Core/SetProperty"
	action.params = {"target": "%s.Score" % PROBE_NAME, "value": "10 if %s.Muted else 20" % PROBE_NAME}
	event.actions.append(action)
	sheet.events.append(event)
	# The picked shape: the object in one cell, the property in another, and two cells that must not
	# be read as globals - a number, and a variable this sheet declares itself.
	var picked_event := EventRow.new()
	var picked := ACEAction.new()
	picked.provider_id = "Core"
	picked.ace_id = "Core/SetProperty"
	picked.params = {"object": PROBE_NAME, "property": "Lives", "value": "3", "from": "hp"}
	picked_event.actions.append(picked)
	sheet.events.append(picked_event)
	return sheet


static func _view(sheet: EventSheetResource) -> EventSheetViewport:
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	return view


static func _row_at(rows: Array, index: int) -> EventRowData:
	return (rows[index] as Dictionary).get("row") if index < rows.size() else null


static func _texts(row_data: EventRowData) -> String:
	if row_data == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		parts.append(str(span.text))
	return " | ".join(parts)


static func _meta(row_data: EventRowData) -> Dictionary:
	if row_data == null or row_data.spans.is_empty() or not (row_data.spans[0].metadata is Dictionary):
		return {}
	return row_data.spans[0].metadata


static func _has_editable_span(row_data: EventRowData) -> bool:
	if row_data == null:
		return false
	for span: SemanticSpan in row_data.spans:
		if span.metadata is Dictionary and bool((span.metadata as Dictionary).get("editable", false)):
			return true
	return false


static func _has_uid_prefix(rows: Array, prefix: String) -> bool:
	for entry: Variant in rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data != null and row_data.row_uid.begins_with(prefix):
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("globals_used_here_rows_test", label, actual, expected)
