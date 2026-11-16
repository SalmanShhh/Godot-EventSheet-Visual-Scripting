# Godot EventSheets - Every colour in the Theme Editor has a dark swatch and a light one.
#
# The window previews the theme as a dark or a light editor draws it (the sheet itself always wears the side
# that matches Godot's editor), a light swatch writes the theme's light colour as a step of the window's own
# undo list, the chain gives light its own colour or sends it back to the dark one, a word colour that would
# read badly on its ground is marked with the ratio in the strip, Quick Style fills both columns at once, and a
# theme nobody gave a light colour saves with no light line at all.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const FILES := preload("res://tests/theme_window_files_test.gd")
const LIGHT_PATH := "res://addons/eventsheet/theme/light_colors.gd"
const P := "theme_window_light_test"
const STARTER := "res://addons/eventsheet/themes/editor_native_theme.tres"
const PALE := Color(0.91, 0.93, 0.92, 1.0)
const PAPER := Color(0.97, 0.98, 0.97, 1.0)


static func run() -> bool:
	var ok: bool = true
	ok = _preview_as() and ok
	ok = _a_light_swatch() and ok
	ok = _the_chain() and ok
	ok = _an_auto_swatch() and ok
	ok = _hard_to_read() and ok
	ok = _the_file() and ok
	ok = _quick_style_twice() and ok
	ok = _the_tick_and_the_words() and ok
	return ok


static func _light() -> GDScript:
	return load(LIGHT_PATH)


static func _row_of(window: EventSheetThemeEditor, block: Resource, token: String) -> Dictionary:
	for entry: Dictionary in window._light_side._rows:
		if entry["block"] == block and str(entry["token"]) == token:
			return entry
	return {}


## Picks a colour on a light swatch the way a user does.
static func _pick_light(window: EventSheetThemeEditor, block: Resource, token: String, colour: Color) -> void:
	var picker: ColorPickerButton = _row_of(window, block, token)["light"]
	picker.color = colour
	picker.color_changed.emit(colour)


static func _preview_as() -> bool:
	var dock: Control = FILES.recorder_dock()
	var path: String = FILES.theme_file("light_preview.tres", Color("#202020"))
	var theme: EventSheetEditorStyle = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetEditorStyle
	var dark_value: Color = theme.event_style.sheet_background_color
	_light().set_entry(theme.event_style, "sheet_background_color", PALE)
	ResourceSaver.save(theme, path)
	var window: EventSheetThemeEditor = FILES.open_window(path, dock)
	var dark_first: bool = window._light_side.preview_light
	var dark_ground: Color = window._preview_viewport.get_editor_style().event_style.sheet_background_color
	window._light_side.set_preview_light(true)
	var light_ground: Color = window._preview_viewport.get_editor_style().event_style.sheet_background_color
	var edits: int = window._edits.size()
	var ok: bool = SUPPORT.pins(P + ": Preview as", [
		["a window opens on the editor's own mode (dark with no editor)", dark_first, false],
		["the dark preview draws the colour the theme has always held", dark_ground, dark_value],
		["the light preview draws the light colour", light_ground, PALE],
		["switching the preview is not an edit", edits, 0],
		["and the title stays unchanged", window._dialog.title.contains("(changed)"), false],
	])
	window._dialog.free()
	dock.free()
	return ok


static func _a_light_swatch() -> bool:
	var dock: Control = FILES.recorder_dock()
	var path: String = FILES.theme_file("light_swatch.tres", Color("#202020"))
	var window: EventSheetThemeEditor = FILES.open_window(path, dock)
	var block: Resource = window._working_style.event_style
	_pick_light(window, block, "row_background_color", PAPER)
	var held: Variant = _light().entry_of(block, "row_background_color")
	var ok: bool = SUPPORT.pins(P + ": a light swatch", [
		["the pick becomes the theme's light colour", held, PAPER],
		["it is one step on the window's undo list", window._edits.size(), 1],
		["and the title says the window has changes", window._dialog.title.contains("(changed)"), true],
		["the dark colour is where it was", block.get("row_background_color"), Color("#202020")],
	])
	window.undo_edit()
	ok = SUPPORT.pins(P + ": undo of a light swatch", [
		["undo takes the light colour away", _light().entry_of(block, "row_background_color"), null],
		["the swatch is the dark colour again", (_row_of(window, block, "row_background_color")["light"] as ColorPickerButton).color, Color("#202020")],
	]) and ok
	window.redo_edit()
	ok = SUPPORT.check(P, "redo puts it back", _light().entry_of(block, "row_background_color"), PAPER) and ok
	window._dialog.free()
	dock.free()
	return ok


static func _the_chain() -> bool:
	var dock: Control = FILES.recorder_dock()
	var path: String = FILES.theme_file("light_chain.tres", Color("#202020"))
	var window: EventSheetThemeEditor = FILES.open_window(path, dock)
	var block: Resource = window._working_style.event_style
	var side: Dictionary = window._light_side.light_side(block, "row_background_color")
	var ok: bool = SUPPORT.pins(P + ": a theme with no light colour", [
		["a colour starts linked: the light side is the dark colour", side["linked"], true],
		["it holds no light colour", side["own"], false],
		["and its chain says so", (_row_of(window, block, "row_background_color")["link"] as Button).tooltip_text,
			"Same colour in dark and light: click to give light its own"],
	])
	window._light_side.toggle_link(block, "row_background_color")
	ok = SUPPORT.pins(P + ": the chain clicked once", [
		["light gets a colour of its own, starting from the dark one", _light().entry_of(block, "row_background_color"), Color("#202020")],
		["the chain now offers the way back", (_row_of(window, block, "row_background_color")["link"] as Button).tooltip_text,
			"Separate colours: click to use the dark colour in both"],
	]) and ok
	window._light_side.toggle_link(block, "row_background_color")
	ok = SUPPORT.check(P, "clicked again, the light colour is gone and the pair is linked", _light().entry_of(block, "row_background_color"), null) and ok
	window._dialog.free()
	dock.free()
	return ok


static func _an_auto_swatch() -> bool:
	var dock: Control = FILES.recorder_dock()
	var window: EventSheetThemeEditor = FILES.open_window(STARTER, dock)
	var block: Resource = window._working_style.event_style
	var side: Dictionary = window._light_side.light_side(block, "sheet_background_color")
	var picker: ColorPickerButton = _row_of(window, block, "sheet_background_color")["light"]
	var ok: bool = SUPPORT.pins(P + ": a theme that follows the editor", [
		["a colour the editor's greys change has an auto light side", side["linked"] == false and side["own"] == false, true],
		["the swatch is drawn dashed", picker.get("auto"), true],
		["and shows the colour a light editor would draw", picker.color, EventSheetEditorThemeDeriver.sheet_look(
			_light().without_entries(window._working_style), EventSheetEditorThemeDeriver.NATIVE_LIGHT_REFERENCE_BASE).event_style.sheet_background_color],
	])
	_pick_light(window, block, "sheet_background_color", PALE)
	ok = SUPPORT.check(P, "picking a colour ends the auto", picker.get("auto"), false) and ok
	window._dialog.free()
	dock.free()
	return ok


static func _hard_to_read() -> bool:
	var dock: Control = FILES.recorder_dock()
	var path: String = FILES.theme_file("light_contrast.tres", Color("#202020"))
	var window: EventSheetThemeEditor = FILES.open_window(path, dock)
	var block: Resource = window._working_style.event_style
	var row: Dictionary = _row_of(window, block, "comment_text_color")
	var calm: bool = not (_row_of(window, block, "object_label_color")["mark"] as Label).visible
	_pick_light(window, block, "comment_row_background_color", Color("#f6edc6"))
	_pick_light(window, block, "comment_text_color", Color("#e9ddb0"))
	window._light_side.set_preview_light(true)
	var sentence: String = window._light_side.contrast_sentence(block, "comment_text_color")
	var finding: Dictionary = window._light_side.finding(block, "comment_text_color", true)
	var ok: bool = SUPPORT.pins(P + ": a word colour on its ground", [
		["a colour that reads well carries no mark", calm, true],
		["a light colour that is too pale carries one", (row["mark"] as Label).visible, true],
		["the ratio is under the bar for words", float(finding["ratio"]) < 4.5, true],
		["the strip says the ratio, the ground and the side", sentence.begins_with("Contrast ") and sentence.contains(" : 1 on comment_row_background_color (Light); 4.5 : 1 reads comfortably."), true],
		["nothing stops a save", window.save_button_text().is_empty() or window.save() == OK, true],
	])
	window._dialog.free()
	dock.free()
	return ok


static func _the_file() -> bool:
	var dock: Control = FILES.recorder_dock()
	var path: String = FILES.theme_file("light_file.tres", Color("#202020"))
	var window: EventSheetThemeEditor = FILES.open_window(path, dock)
	FILES.edit(window, "row_background_color", Color("#301010"))
	window.save()
	var untouched: String = FileAccess.get_file_as_string(path)
	_pick_light(window, window._working_style.event_style, "row_background_color", PAPER)
	window.save()
	var reread: EventSheetEditorStyle = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetEditorStyle
	var ok: bool = SUPPORT.pins(P + ": the file", [
		["a theme nobody gave a light colour saves with no light line", untouched.contains("light_colors"), false],
		["a light colour is saved with the block it belongs to", _light().entry_of(reread.event_style, "row_background_color"), PAPER],
		["and the dark colour is still the one it has always been", reread.event_style.row_background_color, Color("#301010")],
		["the strip shows the light line a token writes", window._light_side.light_file_line(window._working_style.event_style, "row_background_color"),
			"light_colors[&\"row_background_color\"] = %s" % var_to_str(PAPER)],
	])
	window._dialog.free()
	dock.free()
	return ok


static func _quick_style_twice() -> bool:
	var dock: Control = FILES.recorder_dock()
	var path: String = FILES.theme_file("light_quick.tres", Color("#202020"))
	var window: EventSheetThemeEditor = FILES.open_window(path, dock)
	var block: Resource = window._working_style.event_style
	window._quick_base.color = Color("#1f2622")
	window._quick_light_base.color = Color("#e7eeea")
	window._quick_font.color = Color("#dce6e0")
	window._quick_light_font.color = Color("#14201a")
	window._generate_quick_style()
	var dark_after: Color = block.get("sheet_background_color")
	var light_after: Variant = _light().entry_of(block, "sheet_background_color")
	var ok: bool = SUPPORT.pins(P + ": Quick Style twice", [
		["Generate gives the dark column the dark base", dark_after, Color("#1f2622").darkened(0.25)],
		["and the light column the light base", light_after, Color("#e7eeea").darkened(0.25)],
		["the light group title is the light text colour", _light().entry_of(block, "group_title_color"), Color("#14201a")],
		["one Generate is one step on the undo list", window._edits.size(), 1],
	])
	window.undo_edit()
	ok = SUPPORT.pins(P + ": undo of Generate", [
		["undo brings the dark colour back", block.get("sheet_background_color") == dark_after, false],
		["and takes the light colours away again", _light().has_entries(window._working_style), false],
	]) and ok
	window.redo_edit()
	ok = SUPPORT.check(P, "redo puts both columns back", _light().entry_of(window._working_style.event_style, "sheet_background_color"), light_after) and ok
	window._dialog.free()
	dock.free()
	return ok


static func _the_tick_and_the_words() -> bool:
	var dock: Control = FILES.recorder_dock()
	var window: EventSheetThemeEditor = FILES.open_window(STARTER, dock)
	var found: bool = false
	for row: Node in window._detail_form.find_children("*", "HBoxContainer", true, false):
		if row.has_meta("token") and str(row.get_meta("token")) == "follow_editor_greys":
			found = (row.get_child(0) as Label).text == "Follow the editor in light" and row.get_child(1) is CheckBox
	var ok: bool = SUPPORT.pins(P + ": the tick that opts a theme in", [
		["the field that follows the editor is worded plainly", found, true],
		["a plain field keeps its capitalised name", EventSheetThemeEditor.token_label("row_background_color"), "Row Background Color"],
	])
	window._dialog.free()
	dock.free()
	return ok
