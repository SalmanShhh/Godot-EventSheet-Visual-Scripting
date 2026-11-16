# Godot EventSheets - A theme's light colours are worn in a light editor, and only by a theme that holds some.
#
# The sheet wears the side that matches Godot's editor theme. A theme that holds no light colour and does not
# follow the editor's greys is drawn in a light editor exactly as in a dark one, so every theme saved before
# light colours existed looks as it did. A theme that holds light colours wears them on a light editor and
# never on a dark one; a token it gave none keeps its dark colour, or the editor-following value when the
# theme follows the editor's greys.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const LIGHT_PATH := "res://addons/eventsheet/theme/light_colors.gd"
const P := "theme_light_side_test"
const DARK_BASE := Color("#292929")
const LIGHT_BASE := Color("#e6e6e6")
const NORD := "res://demo/themes/nord_theme.tres"
const NATIVE := "res://addons/eventsheet/themes/editor_native_theme.tres"
const THEME_DIRS: Array[String] = ["res://addons/eventsheet/themes/", "res://demo/themes/"]
const PALE := Color(0.91, 0.93, 0.92, 1.0)
const PAPER := Color(0.97, 0.98, 0.97, 1.0)


static func run() -> bool:
	var ok: bool = true
	ok = _themes_that_hold_no_light_colour() and ok
	ok = _a_theme_with_light_colours() and ok
	ok = _a_theme_that_follows_the_editor() and ok
	ok = _the_sheet_is_re_seated() and ok
	return ok


static func _light() -> GDScript:
	return load(LIGHT_PATH)


static func _load(path: String) -> EventSheetEditorStyle:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetEditorStyle


## Every theme that ships holds no light colour, and the ones that do not follow the editor come back from
## the look function as the very resource they were, on a dark editor and on a light one.
static func _themes_that_hold_no_light_colour() -> bool:
	var holding: Array[String] = []
	var rebuilt: Array[String] = []
	for dir_path: String in THEME_DIRS:
		for file_name: String in DirAccess.get_files_at(dir_path):
			if not file_name.ends_with(".tres"):
				continue
			var theme: EventSheetEditorStyle = _load(dir_path.path_join(file_name))
			if _light().has_entries(theme):
				holding.append(file_name)
			if theme.follow_editor_greys:
				continue
			for base: Color in [DARK_BASE, LIGHT_BASE]:
				if EventSheetEditorThemeDeriver.sheet_look(theme, base) != theme:
					rebuilt.append("%s at %s" % [file_name, base.to_html(false)])
	var ok: bool = SUPPORT.check(P, "no shipped theme holds a light colour", holding, [])
	return SUPPORT.check(P, "a theme that holds none and does not follow is drawn as it is", rebuilt, []) and ok


static func _a_theme_with_light_colours() -> bool:
	var theme: EventSheetEditorStyle = _load(NORD)
	var dark_sheet: Color = theme.event_style.sheet_background_color
	var dark_row: Color = theme.event_style.row_background_color
	_light().set_entry(theme.event_style, "sheet_background_color", PALE)
	_light().set_entry(theme.event_style, "not_a_token_any_more", PAPER)
	var on_light: EventSheetEditorStyle = EventSheetEditorThemeDeriver.sheet_look(theme, LIGHT_BASE)
	var on_dark: EventSheetEditorStyle = EventSheetEditorThemeDeriver.sheet_look(theme, DARK_BASE)
	var outside: EventSheetEditorStyle = EventSheetEditorThemeDeriver.sheet_look(theme, Color(0.0, 0.0, 0.0, 0.0))
	return SUPPORT.pins(P + ": a theme with a light colour", [
		["a light editor draws the light colour", on_light.event_style.sheet_background_color, PALE],
		["a token it gave none keeps its dark colour", on_light.event_style.row_background_color, dark_row],
		["a dark editor draws the dark colour", on_dark.event_style.sheet_background_color, dark_sheet],
		["a dark editor gets the theme as it is", on_dark == theme, true],
		["outside the editor the theme is as saved", outside == theme, true],
		["the theme itself is not changed by being worn", theme.event_style.sheet_background_color, dark_sheet],
		["an entry for a token that is gone is left alone", on_light.event_style.get("not_a_token_any_more"), null],
	])


static func _a_theme_that_follows_the_editor() -> bool:
	var theme: EventSheetEditorStyle = _load(NATIVE)
	var plain: EventSheetEditorStyle = EventSheetEditorThemeDeriver.sheet_look(theme, LIGHT_BASE)
	_light().set_entry(theme.event_style, "row_background_color", PAPER)
	var worn: EventSheetEditorStyle = EventSheetEditorThemeDeriver.sheet_look(theme, LIGHT_BASE)
	return SUPPORT.pins(P + ": a theme that follows the editor", [
		["its own light colour wins over what the editor gives", worn.event_style.row_background_color, PAPER],
		["a token it gave none follows the editor as before", worn.event_style.sheet_background_color, plain.event_style.sheet_background_color],
	])


## A sheet is re-seated when the editor's theme changes if its theme can look different there: one that
## follows the editor, or one that holds a light colour.
static func _the_sheet_is_re_seated() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	var plain: EventSheetEditorStyle = _load(NORD)
	var holding: EventSheetEditorStyle = _load(NORD)
	_light().set_entry(holding.event_style, "sheet_background_color", PALE)
	var dock_script: GDScript = load("res://addons/eventsheet/editor/event_sheet_dock.gd")
	return SUPPORT.pins(P + ": a change of the editor's theme", [
		["leaves a plain theme alone", dock_script.reseats_on_editor_theme(sheet, plain), false],
		["re-seats a theme that holds a light colour", dock_script.reseats_on_editor_theme(sheet, holding), true],
		["re-seats a sheet with no theme", dock_script.reseats_on_editor_theme(sheet, null), true],
	])
