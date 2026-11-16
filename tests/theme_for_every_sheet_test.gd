# Godot EventSheets - A project can name the theme every sheet wears by default.
#
# The setting is registered, so Project Settings shows it. A sheet that chose no theme wears the named
# one; a sheet that chose its own keeps it; with the setting empty (every project today) the look is
# exactly what it was. The Sheet theme menu has a ticked entry for it.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "theme_for_every_sheet_test"
const SETTING := "eventsheets/theme/default_theme"
const THEME_FILES := "res://addons/eventsheet/theme/theme_files.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _registered() and ok
	ok = _sheets_wear_it() and ok
	ok = _menu_entry() and ok
	return ok


static func _registered() -> bool:
	var found: Dictionary = {}
	for definition: Dictionary in EventSheetSettings.DEFINITIONS:
		if str(definition.get("name", "")) == SETTING:
			found = definition
	return SUPPORT.pins(P + ": setting", [
		["the project theme is a registered setting", found.is_empty(), false],
		["it holds a file name", found.get("type", -1), TYPE_STRING],
		["it is picked as a file", found.get("hint", -1), PROPERTY_HINT_FILE],
		["and is empty until a project chooses one", found.get("default", "x"), ""],
	])


static func _sheets_wear_it() -> bool:
	var window_files: GDScript = load("res://tests/theme_window_files_test.gd")
	var path: String = window_files.theme_file("every_sheet_theme.tres", Color("#3c1020"))
	var before: Variant = ProjectSettings.get_setting(SETTING, "")
	var base: Color = Color("#292929")
	var plain: Color = EventSheetEditorThemeDeriver.sheet_look(null, base).event_style.row_background_color
	ProjectSettings.set_setting(SETTING, path)
	var worn: EventSheetEditorStyle = EventSheetEditorThemeDeriver.sheet_look(null, base)
	var own: EventSheetEditorStyle = EventSheetThemeEditor.duplicate_style(null)
	own.event_style.row_background_color = Color("#102030")
	var chose: EventSheetEditorStyle = EventSheetEditorThemeDeriver.sheet_look(own, base)
	var bare: EventSheetEditorStyle = EventSheetEditorThemeDeriver.sheet_look(null, Color(0.0, 0.0, 0.0, 0.0))
	ProjectSettings.set_setting(SETTING, "res://no_such_theme_file.tres")
	var missing: Color = EventSheetEditorThemeDeriver.sheet_look(null, base).event_style.row_background_color
	ProjectSettings.set_setting(SETTING, before)
	var after: Color = EventSheetEditorThemeDeriver.sheet_look(null, base).event_style.row_background_color
	return SUPPORT.pins(P + ": look", [
		["a sheet with no theme wears the project's", worn.event_style.row_background_color.is_equal_approx(Color("#3c1020")) or worn.follow_editor_greys, true],
		["a sheet that chose its own keeps it", chose.event_style.row_background_color, Color("#102030")],
		["the same outside the editor", bare.event_style.row_background_color.is_equal_approx(Color("#3c1020")), true],
		["a name that is no theme file changes nothing", missing, plain],
		["cleared, the look is what it was", after, plain],
	])


static func _menu_entry() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	var manager: EventSheetThemeManager = dock._theme_manager
	var menu: PopupMenu = manager._theme_menu
	var ok: bool = SUPPORT.check(P, "the Sheet theme menu is built", menu != null, true)
	if menu == null:
		dock.free()
		return false
	var texts: PackedStringArray = PackedStringArray()
	for i: int in range(menu.item_count):
		texts.append(menu.get_item_text(i))
	ok = SUPPORT.check(P, "it offers Use For Every Sheet", texts.has("Use For Every Sheet"), true) and ok
	var window_files: GDScript = load("res://tests/theme_window_files_test.gd")
	var path: String = window_files.theme_file("every_sheet_menu.tres", Color("#3c1020"))
	var before: Variant = ProjectSettings.get_setting(SETTING, "")
	dock.load_theme_style_from_path(path)
	manager.use_for_every_sheet()
	ok = SUPPORT.check(P, "choosing it names the sheet's theme file as the project's", str(ProjectSettings.get_setting(SETTING, "")), path) and ok
	manager.use_for_every_sheet()
	ok = SUPPORT.check(P, "choosing it again takes it off", str(ProjectSettings.get_setting(SETTING, "")), "") and ok
	ProjectSettings.set_setting(SETTING, before)
	dock.use_default_theme()
	dock.free()
	return ok
