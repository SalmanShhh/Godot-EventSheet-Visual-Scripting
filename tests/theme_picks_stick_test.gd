# Godot EventSheets - A theme picked for a sheet stays picked.
#
# A theme picked on a script sheet survives closing and opening the script again, and the script is
# never marked changed for it (nothing about a theme is written into the script). A theme saved into
# the project's own themes folder is listed in the theme menu. Apply To Current Sheet stays out of the
# undo history, like every other theme switch. The same holds for a dragged lane split, a dragged
# object column and a Density pick on a script sheet: kept for the script, never marked changed.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "theme_picks_stick_test"
const DENSITY_PATH := "res://addons/eventsheet/themes/density/spacious_density.tres"
const THEME_PATH := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
const PROJECT_THEMES := "res://eventsheet_themes/"
const SCRIPT_TEXT := "extends Node\n\n\nfunc _ready() -> void:\n\tprint(\"ready\")\n"


static func run() -> bool:
	var ok: bool = true
	ok = _script_pick_survives_reopen() and ok
	ok = _script_numbers_survive_reopen() and ok
	ok = _menu_promise() and ok
	ok = _project_themes_listed() and ok
	ok = _apply_out_of_undo() and ok
	return ok


static func _dock(undo: RefCounted = null) -> EventSheetDock:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(undo if undo != null else EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	return dock


static func _script_pick_survives_reopen() -> bool:
	var SCRIPT_PATH: String = SUPPORT.own_path("theme_pick_probe_sheet.gd")
	var file: FileAccess = FileAccess.open(SCRIPT_PATH, FileAccess.WRITE)
	file.store_string(SCRIPT_TEXT)
	file.close()
	var first: EventSheetDock = _dock()
	first._load_sheet_from_path(SCRIPT_PATH)
	var picked: bool = first.load_theme_style_from_path(THEME_PATH)
	var ok: bool = SUPPORT.pins(P + ": script pick", [
		["the theme is picked", picked, true],
		["the script is not marked changed for a theme", first._dirty, false],
	])
	first.free()
	var second: EventSheetDock = _dock()
	second._load_sheet_from_path(SCRIPT_PATH)
	var style: EventSheetEditorStyle = second.get_current_sheet().editor_style
	ok = SUPPORT.check(P, "the script opens again wearing the theme picked for it",
		style.resource_path if style != null else "", THEME_PATH) and ok
	ok = SUPPORT.check(P, "and its bytes are untouched", FileAccess.get_file_as_string(SCRIPT_PATH), SCRIPT_TEXT) and ok
	second.use_default_theme()
	second.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRIPT_PATH))
	return ok


static func _menu_promise() -> bool:
	var menu_source: String = FileAccess.get_file_as_string("res://addons/eventsheet/editor/dock/menu_bar.gd")
	return SUPPORT.check(P, "the theme menu no longer says the pick is written into the file",
		menu_source.contains("Remembered on the sheet, so it travels with the file."), false)


static func _project_themes_listed() -> bool:
	return SUPPORT.check(P, "the project's own themes folder is one of the folders the menu lists",
		EventSheetThemePresets.THEME_DIRS.has(PROJECT_THEMES), true)


static func _apply_out_of_undo() -> bool:
	var undo: RefCounted = EventSheetEditorTest.FakeEditorUndoRedoManager.new()
	var dock: EventSheetDock = _dock(undo)
	var before: int = (undo.get("_undo_stack") as Array).size()
	var style: EventSheetEditorStyle = EventSheetEditorThemeDeriver.default_style().duplicate(true) as EventSheetEditorStyle
	style.event_style.row_background_color = Color("#5a1010")
	dock.apply_theme_style(style)
	var after: int = (undo.get("_undo_stack") as Array).size()
	var ok: bool = SUPPORT.pins(P + ": apply", [
		["Apply puts the theme on the sheet", dock.get_current_sheet().editor_style.event_style.row_background_color, Color("#5a1010")],
		["and leaves the undo history as it was", after, before],
	])
	dock.free()
	return ok


static func _script_numbers_survive_reopen() -> bool:
	var path: String = SUPPORT.own_path("theme_numbers_probe_sheet.gd")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(SCRIPT_TEXT)
	file.close()
	var first: EventSheetDock = _dock()
	first._load_sheet_from_path(path)
	first._on_viewport_lane_ratio_changed(0.31)
	first._on_viewport_object_column_width_changed("condition", 123)
	first._on_viewport_object_column_width_changed("action", 77)
	var ok: bool = SUPPORT.check(P, "dragging a lane or a column does not mark the script changed", first._dirty, false)
	first.free()
	var second: EventSheetDock = _dock()
	second._load_sheet_from_path(path)
	var style: EventSheetEditorStyle = second.get_current_sheet().editor_style
	var event_style: EventSheetEventStyle = style.get_event_style() if style != null else null
	ok = SUPPORT.pins(P + ": numbers", [
		["the lane split comes back", event_style.condition_lane_ratio if event_style != null else -1.0, 0.31],
		["the condition column comes back", event_style.condition_object_column_width if event_style != null else -1, 123],
		["the action column comes back", event_style.action_object_column_width if event_style != null else -1, 77],
	]) and ok
	var preset: Resource = load(DENSITY_PATH) if ResourceLoader.exists(DENSITY_PATH) else null
	if preset != null:
		second._theme_manager.apply_density_path(DENSITY_PATH)
		ok = SUPPORT.check(P, "a Density pick does not mark the script changed", second._dirty, false) and ok
		var again: EventSheetDock = _dock()
		again._load_sheet_from_path(path)
		var worn: EventSheetEditorStyle = again.get_current_sheet().editor_style
		ok = SUPPORT.check(P, "and the script opens again wearing that density",
			worn.get_event_style().minimum_row_height if worn != null else -1, (preset as EventSheetDensityStyle).row_height) and ok
		again.free()
	second.use_default_theme()
	second.free()
	var third: EventSheetDock = _dock()
	third._load_sheet_from_path(path)
	ok = SUPPORT.check(P, "Match Editor lets go of everything kept for the script", third.get_current_sheet().editor_style == null, true) and ok
	third.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return ok
