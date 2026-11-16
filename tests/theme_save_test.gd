# Godot EventSheets - Save writes the theme file the Theme Editor opened, and never a shipped one.
#
# Save keeps the file it opened and every sheet wearing it repaints; Save As makes a new file and the
# window then edits it; a starter or a demo theme only ever offers a copy, so the plugin's own files stay
# as shipped. A second save of the same values gives the same text (Godot renumbers the blocks inside a
# file on every save, so the numbers are masked before two texts are compared).
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const FILES := preload("res://tests/theme_window_files_test.gd")
const THEME_FILES := "res://addons/eventsheet/theme/theme_files.gd"
const P := "theme_save_test"
const STARTER := "res://addons/eventsheet/themes/editor_native_theme.tres"
const DEMO := "res://demo/themes/nord_theme.tres"


static func run() -> bool:
	var ok: bool = true
	ok = _save_in_place() and ok
	ok = _shipped_files_stay() and ok
	ok = _save_as() and ok
	ok = _save_a_copy() and ok
	ok = _second_save_is_the_same() and ok
	ok = _failed_save_says_so() and ok
	return ok


## The file's text with every number Godot hands a block on each save taken out.
static func _masked(path: String) -> String:
	var text: String = FileAccess.get_file_as_string(path)
	for pattern: String in ["id=\"[^\"]*\"", "uid=\"[^\"]*\"", "Resource\\(\"[^\"]*\"\\)"]:
		var regex: RegEx = RegEx.new()
		regex.compile(pattern)
		text = regex.sub(text, "#", true)
	return text


static func _save_in_place() -> bool:
	var dock: Control = FILES.recorder_dock()
	var path: String = FILES.theme_file("theme_save_place.tres", Color("#202020"))
	var worn: EventSheetEditorStyle = ResourceLoader.load(path) as EventSheetEditorStyle
	var repaints: Array[int] = [0]
	worn.changed.connect(func() -> void: repaints[0] += 1)
	var window: EventSheetThemeEditor = FILES.open_window(path, dock)
	FILES.edit(window, "row_background_color", Color("#3a1010"))
	var result: Error = window.save()
	var reread: EventSheetEditorStyle = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetEditorStyle
	var ok: bool = SUPPORT.pins(P + ": save", [
		["Save writes the file", result, OK],
		["the file holds the edit", reread.event_style.row_background_color, Color("#3a1010")],
		["the style a sheet wears is changed in place", worn.event_style.row_background_color, Color("#3a1010")],
		["and says it changed, so every sheet wearing it repaints", repaints[0] >= 1, true],
		["the title drops the changed mark", window._dialog.title.contains("(changed)"), false],
		["the foot says what was saved", window._note.text, "Theme saved: %s" % path.get_file()],
	])
	window._dialog.free()
	dock.free()
	return ok


static func _shipped_files_stay() -> bool:
	var dock: Control = FILES.recorder_dock()
	var ok: bool = true
	for path: String in [STARTER, DEMO]:
		var before: String = FileAccess.get_file_as_string(path)
		var window: EventSheetThemeEditor = FILES.open_window(path, dock)
		FILES.edit(window, "row_background_color", Color("#3a1010"))
		var result: Error = window.save()
		ok = SUPPORT.pins(P + ": shipped " + path.get_file(), [
			["Save refuses a shipped theme", result != OK, true],
			["and the file is as shipped", FileAccess.get_file_as_string(path) == before, true],
		]) and ok
		window._dialog.free()
	dock.free()
	return ok


static func _save_as() -> bool:
	var dock: Control = FILES.recorder_dock()
	var path: String = FILES.theme_file("theme_save_as_source.tres", Color("#202020"))
	var target: String = SUPPORT.own_path("theme_save_as_target.tres")
	var window: EventSheetThemeEditor = FILES.open_window(path, dock)
	FILES.edit(window, "row_background_color", Color("#3a1010"))
	var result: Error = window.save_preset(target)
	var source_after: EventSheetEditorStyle = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetEditorStyle
	var ok: bool = SUPPORT.pins(P + ": save as", [
		["Save As writes the new file", result, OK],
		["the window then edits the new file", window._source_path, target],
		["and carries no changes", window._dialog.title, "Theme Editor - %s" % target.get_file()],
		["the file it came from is left as it was", source_after.event_style.row_background_color, Color("#202020")],
	])
	window._dialog.free()
	dock.free()
	return ok


static func _save_a_copy() -> bool:
	var dock: Control = FILES.recorder_dock()
	var before: String = FileAccess.get_file_as_string(STARTER)
	var window: EventSheetThemeEditor = FILES.open_window(STARTER, dock)
	FILES.edit(window, "row_background_color", Color("#3a1010"))
	var target: String = SUPPORT.own_path("theme_save_copy_target.tres")
	var result: Error = window.save_preset(target)
	var files: GDScript = load(THEME_FILES)
	var ok: bool = SUPPORT.pins(P + ": copy", [
		["the copy is written", result, OK],
		["the starter is as shipped", FileAccess.get_file_as_string(STARTER) == before, true],
		["the window then edits the copy", window._source_path, target],
		["the sheet is switched to the copy", dock.get("loaded_path"), target],
		["the suggested name drops the word theme and says copy", files.copy_name(STARTER), "editor_native_copy.tres"],
		["the copy goes to the project's themes folder", files.COPY_DIR, "res://eventsheet_themes/"],
	])
	window._dialog.free()
	dock.free()
	return ok


static func _second_save_is_the_same() -> bool:
	var dock: Control = FILES.recorder_dock()
	var path: String = FILES.theme_file("theme_save_twice.tres", Color("#202020"))
	var window: EventSheetThemeEditor = FILES.open_window(path, dock)
	FILES.edit(window, "row_background_color", Color("#3a1010"))
	window.save()
	var first: String = _masked(path)
	FILES.edit(window, "row_background_color", Color("#3a1010"))
	window.save()
	var second: String = _masked(path)
	var reread: EventSheetEditorStyle = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetEditorStyle
	var ok: bool = SUPPORT.pins(P + ": twice", [
		["a second save gives the same text, numbers masked", second == first, true],
		["and the same values", reread.event_style.row_background_color, Color("#3a1010")],
	])
	window._dialog.free()
	dock.free()
	return ok


static func _failed_save_says_so() -> bool:
	var dock: Control = FILES.recorder_dock()
	var window: EventSheetThemeEditor = FILES.open_window("", dock)
	var result: Error = window.save_preset("res://no_such_folder_for_themes/theme.tres")
	var ok: bool = SUPPORT.pins(P + ": failure", [
		["a file that cannot be written is an error", result != OK, true],
		["the foot says so", window._note.text.begins_with("Theme could not be saved: theme.tres"), true],
		["the window still edits what it did", window._source_path, ""],
	])
	window._dialog.free()
	dock.free()
	return ok
