# Godot EventSheets - The Theme Editor window is bound to the theme file it opened.
#
# Its title names the file and gains "(changed)" the moment a swatch moves, Ctrl+Z and Ctrl+Shift+Z step the
# swatches, Revert goes back to the file, and closing or switching with changes asks Save / Discard / Cancel.
# A theme field in the window switches the theme it edits without closing it.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "theme_window_files_test"
const STARTER := "res://addons/eventsheet/themes/editor_native_theme.tres"


static func run() -> bool:
	var ok: bool = true
	ok = _titles() and ok
	ok = _undo_and_revert() and ok
	ok = _buttons_by_kind() and ok
	ok = _close_question() and ok
	ok = _theme_field() and ok
	return ok


static func recorder_dock() -> Control:
	var recorder_script: GDScript = GDScript.new()
	recorder_script.source_code = "extends Control\nvar applied: int = 0\nvar loaded_path: String = \"\"\nvar last_text: String = \"\"\nfunc apply_theme_style(_style) -> void:\n\tapplied += 1\nfunc load_theme_style_from_path(path: String) -> bool:\n\tloaded_path = path\n\treturn true\nfunc _set_status(text: String, _is_error: bool = false) -> void:\n\tlast_text = text\n"
	recorder_script.reload()
	var recorder: Control = Control.new()
	recorder.set_script(recorder_script)
	return recorder


## A theme file of the test's own, written once and loaded the way a sheet loads it.
static func theme_file(file_name: String, row_colour: Color) -> String:
	var style: EventSheetEditorStyle = EventSheetThemeEditor.duplicate_style(null)
	style.event_style.row_background_color = row_colour
	var path: String = SUPPORT.own_path(file_name)
	ResourceSaver.save(style, path)
	return path


static func swatch(window: EventSheetThemeEditor, token_name: String) -> ColorPickerButton:
	for row: Node in window._detail_form.find_children("*", "HBoxContainer", true, false):
		if row.get_child_count() >= 2 and row.get_child(1) is ColorPickerButton and row.has_meta("token") and str(row.get_meta("token")) == token_name:
			return row.get_child(1) as ColorPickerButton
	return null


static func edit(window: EventSheetThemeEditor, token_name: String, colour: Color) -> void:
	var picker: ColorPickerButton = swatch(window, token_name)
	picker.color = colour
	picker.color_changed.emit(colour)


static func open_window(path: String, dock: Control) -> EventSheetThemeEditor:
	var window: EventSheetThemeEditor = EventSheetThemeEditor.new()
	var style: EventSheetEditorStyle = ResourceLoader.load(path) as EventSheetEditorStyle if not path.is_empty() else null
	window._prepare(dock, style)
	return window


static func _titles() -> bool:
	var dock: Control = recorder_dock()
	var path: String = theme_file("window_files_titles.tres", Color("#202020"))
	var window: EventSheetThemeEditor = open_window(path, dock)
	var named: String = window._dialog.title
	edit(window, "row_background_color", Color("#3a1010"))
	var changed: String = window._dialog.title
	var editor_window: EventSheetThemeEditor = open_window("", dock)
	var match_title: String = editor_window._dialog.title
	edit(editor_window, "row_background_color", Color("#3a1010"))
	var untitled: String = editor_window._dialog.title
	var ok: bool = SUPPORT.pins(P + ": titles", [
		["the title names the file", named, "Theme Editor - %s" % path.get_file()],
		["a moved swatch adds the changed mark", changed, "Theme Editor - %s (changed)" % path.get_file()],
		["Match Editor has no file and says so", match_title, "Theme Editor - Match Editor"],
		["a change to it makes an untitled theme", untitled, "Theme Editor - Untitled theme (changed)"],
	])
	window._dialog.free()
	editor_window._dialog.free()
	dock.free()
	return ok


static func _undo_and_revert() -> bool:
	var dock: Control = recorder_dock()
	var path: String = theme_file("window_files_undo.tres", Color("#202020"))
	var window: EventSheetThemeEditor = open_window(path, dock)
	var row: Color = window._working_style.event_style.row_background_color
	edit(window, "row_background_color", Color("#301010"))
	edit(window, "row_background_color", Color("#103010"))
	var ok: bool = SUPPORT.check(P, "two edits are on the window's own undo list", window._edits.size(), 2)
	window.undo_edit()
	ok = SUPPORT.check(P, "undo steps the last swatch back", window._working_style.event_style.row_background_color, Color("#301010")) and ok
	ok = SUPPORT.check(P, "and the swatch shows it", swatch(window, "row_background_color").color, Color("#301010")) and ok
	window.redo_edit()
	ok = SUPPORT.check(P, "redo puts it forward again", window._working_style.event_style.row_background_color, Color("#103010")) and ok
	window.undo_edit()
	window.undo_edit()
	ok = SUPPORT.pins(P + ": undone all", [
		["undoing every step restores the colour", window._working_style.event_style.row_background_color, row],
		["and the title drops the changed mark", window._dialog.title.contains("(changed)"), false],
	]) and ok
	edit(window, "row_background_color", Color("#301010"))
	window.revert()
	ok = SUPPORT.pins(P + ": revert", [
		["Revert goes back to the file", window._working_style.event_style.row_background_color, row],
		["the title drops the changed mark", window._dialog.title.contains("(changed)"), false],
		["nothing is left to undo", window._edits.size(), 0],
	]) and ok
	window._dialog.free()
	dock.free()
	return ok


static func _buttons_by_kind() -> bool:
	var dock: Control = recorder_dock()
	var own: String = theme_file("window_files_buttons.tres", Color("#202020"))
	var project: EventSheetThemeEditor = open_window(own, dock)
	var starter: EventSheetThemeEditor = open_window(STARTER, dock)
	var native: EventSheetThemeEditor = open_window("", dock)
	var ok: bool = SUPPORT.pins(P + ": buttons", [
		["a theme of the project's own offers Save", project.save_button_text(), "Save"],
		["a starter offers Save a Copy instead", starter.save_button_text(), "Save a Copy…"],
		["Match Editor offers neither", native.save_button_text(), ""],
		["a project theme offers Save As", project._save_as_button.visible, true],
		["a starter does not offer Save As", starter._save_as_button.visible, false],
		["Match Editor offers Save As", native._save_as_button.visible, true],
	])
	for window: EventSheetThemeEditor in [project, starter, native]:
		window._dialog.free()
	dock.free()
	return ok


static func _close_question() -> bool:
	var dock: Control = recorder_dock()
	var path: String = theme_file("window_files_close.tres", Color("#202020"))
	var window: EventSheetThemeEditor = open_window(path, dock)
	var quiet: bool = window.request_close()
	edit(window, "row_background_color", Color("#3a1010"))
	var asked: bool = window.request_close()
	var prompt: ConfirmationDialog = window._close_prompt
	var ok: bool = SUPPORT.pins(P + ": close", [
		["closing a theme with no changes asks nothing", quiet, false],
		["closing a theme with changes asks", asked, true],
		["the question names the file", prompt != null and prompt.title.contains(path.get_file()), true],
		["it offers Save and Cancel beside Discard", [prompt.ok_button_text, prompt.cancel_button_text] if prompt != null else [], ["Save", "Cancel"]],
	])
	if prompt != null:
		prompt.free()
	window._dialog.free()
	dock.free()
	return ok


static func _theme_field() -> bool:
	var dock: Control = recorder_dock()
	var first: String = theme_file("window_files_first.tres", Color("#202020"))
	var second: String = theme_file("window_files_second.tres", Color("#404040"))
	var window: EventSheetThemeEditor = open_window(first, dock)
	var choices: Array[Dictionary] = window.theme_choices()
	var paths: Array[String] = []
	for choice: Dictionary in choices:
		paths.append(str(choice.get("path", "")))
	var ok: bool = SUPPORT.pins(P + ": field", [
		["the field offers Match Editor", paths.has(""), true],
		["and the starters", paths.has(STARTER), true],
		["and the project's themes folder is searched", EventSheetThemePresets.THEME_DIRS.has(EventSheetThemePresets.PROJECT_DIR), true],
	])
	var switched: bool = window.switch_to(second)
	ok = SUPPORT.pins(P + ": switch", [
		["an unchanged theme switches at once", switched, true],
		["the window now edits the second file", window._source_path, second],
		["and holds its colours", window._working_style.event_style.row_background_color, Color("#404040")],
	]) and ok
	edit(window, "row_background_color", Color("#3a1010"))
	var stayed: bool = window.switch_to(first)
	ok = SUPPORT.pins(P + ": switch with changes", [
		["a changed theme asks instead of switching", stayed, false],
		["the window still edits the second file", window._source_path, second],
		["and keeps the edit", window._working_style.event_style.row_background_color, Color("#3a1010")],
	]) and ok
	if window._close_prompt != null:
		window._close_prompt.free()
	window._dialog.free()
	dock.free()
	return ok
