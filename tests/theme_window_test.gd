# Godot EventSheets - The Theme Editor window does what it says.
#
# A second open edits the new theme (not the first one's leftovers), Reading Comfort never writes the
# unsaved workbench theme into the open sheet, Quick Style starts from the open theme, a row of the
# form reads in plain words while the strip keeps the exact file line, the swatches that drive nothing
# are not shown (and are not lost from a saved file), and the descriptions say what the UI says.
@tool
class_name ThemeWindowTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "theme_window_test"

## Swatches nothing in the editor reads. They stay in saved files; the form just does not show them.
const DEAD_TOKENS := [
	"group_badge_background_color", "group_badge_foreground_color",
	"pattern_chip_background_color", "pattern_chip_foreground_color",
	"minimap_band_text_color", "drawer_accent_bright_color", "drawer_handle_color",
	"drawer_info_background_color", "drawer_info_border_color", "drawer_info_text_color",
	"drawer_header_text_color",
]


static func run() -> bool:
	var ok: bool = true
	ok = _reopen() and ok
	ok = _reading_comfort() and ok
	ok = _quick_style_seed() and ok
	ok = _plain_labels() and ok
	ok = _dead_swatches() and ok
	ok = _descriptions() and ok
	ok = _menu_tick() and ok
	return ok


static func _menu_tick() -> bool:
	var paths: Array = ["", "res://a.tres", "res://b.tres"]
	return SUPPORT.pins(P, [
		["no theme on the sheet ticks Match Editor", EventSheetThemeManager.menu_index_for("", false, paths), 0],
		["a theme from a file ticks its entry", EventSheetThemeManager.menu_index_for("res://b.tres", true, paths), 2],
		["an applied copy with no file ticks nothing", EventSheetThemeManager.menu_index_for("", true, paths), -1],
	])


static func _recorder_dock() -> Control:
	var recorder_script: GDScript = GDScript.new()
	recorder_script.source_code = "extends Control\nvar applied: int = 0\nvar last_text: String = \"\"\nfunc apply_theme_style(_style) -> void:\n\tapplied += 1\nfunc _set_status(text: String, _is_error: bool = false) -> void:\n\tlast_text = text\n"
	recorder_script.reload()
	var recorder: Control = Control.new()
	recorder.set_script(recorder_script)
	return recorder


static func _picker_for(window: EventSheetThemeEditor, token_name: String) -> ColorPickerButton:
	for row: Node in window._detail_form.find_children("*", "HBoxContainer", true, false):
		if row.get_child_count() >= 2 and row.get_child(1) is ColorPickerButton and row.has_meta("token") and str(row.get_meta("token")) == token_name:
			return row.get_child(1) as ColorPickerButton
	return null


static func _reopen() -> bool:
	var window: EventSheetThemeEditor = EventSheetThemeEditor.new()
	var dock: Control = _recorder_dock()
	var first: EventSheetEditorStyle = EventSheetThemeEditor.duplicate_style(null)
	first.event_style.row_background_color = Color("#101010")
	var second: EventSheetEditorStyle = EventSheetThemeEditor.duplicate_style(null)
	second.event_style.row_background_color = Color("#202020")
	window._prepare(dock, first)
	var first_working: EventSheetEditorStyle = window._working_style
	window._note.say("something said in the first session", EventSheetPopupUI.TONE_OK)
	window._prepare(dock, second)
	var second_working: EventSheetEditorStyle = window._working_style
	var picker: ColorPickerButton = _picker_for(window, "row_background_color")
	var ok: bool = SUPPORT.check(P, "the second open finds the row colour swatch", picker != null, true)
	if picker != null:
		picker.color = Color("#303030")
		picker.color_changed.emit(picker.color)
	ok = SUPPORT.check(P, "an edit after the second open changes the second working theme", second_working.event_style.row_background_color, Color("#303030")) and ok
	ok = SUPPORT.check(P, "and leaves the first session's theme alone", first_working.event_style.row_background_color, Color("#101010")) and ok
	ok = SUPPORT.check(P, "the strip names the second theme's value", window._in_file.text.begins_with("row_background_color = Color(0.1882"), true) and ok
	ok = SUPPORT.check(P, "the opening note is said again", window._note.text, "Apply writes this look into the open sheet only") and ok
	window._dialog.free()
	dock.free()
	return ok


static func _reading_comfort() -> bool:
	var window: EventSheetThemeEditor = EventSheetThemeEditor.new()
	var dock: Control = _recorder_dock()
	window._prepare(dock, null)
	var was_on: bool = EventSheetAccessibility.dyslexia_friendly_text()
	var ok: bool = true
	for box: Node in window._dialog.find_children("*", "CheckBox", true, false):
		if (box as CheckBox).text == "Dyslexia-friendly text":
			(box as CheckBox).toggled.emit(not was_on)
	for edit: Node in window._dialog.find_children("*", "LineEdit", true, false):
		if (edit as LineEdit).placeholder_text.begins_with("res://"):
			(edit as LineEdit).text_submitted.emit("")
	ok = SUPPORT.check(P, "Reading Comfort leaves the open sheet's theme alone", dock.get("applied"), 0) and ok
	EventSheetAccessibility.set_dyslexia_friendly_text(was_on)
	window._dialog.free()
	dock.free()
	return ok


static func _quick_style_seed() -> bool:
	var window: EventSheetThemeEditor = EventSheetThemeEditor.new()
	var dock: Control = _recorder_dock()
	var light: EventSheetEditorStyle = EventSheetThemeEditor.duplicate_style(null)
	light.event_style.group_accent_color = Color("#2a6fd0")
	light.event_style.group_title_color = Color("#1a1a1a")
	light.event_style.row_background_color = Color("#d9d9d9")
	window._prepare(dock, light)
	var seeds: Dictionary = EventSheetThemeEditor.quick_style_seed(light)
	var ok: bool = SUPPORT.check(P, "Quick Style's accent starts from the open theme", window._quick_accent.color, Color("#2a6fd0"))
	ok = SUPPORT.check(P, "its text starts from the open theme", window._quick_font.color, Color("#1a1a1a")) and ok
	ok = SUPPORT.check(P, "its base is the open row colour lifted back one Generate step",
		window._quick_base.color.is_equal_approx(seeds["base"]) and window._quick_base.color.get_luminance() > Color("#d9d9d9").get_luminance(), true) and ok
	var dark: EventSheetEditorStyle = EventSheetThemeEditor.duplicate_style(null)
	dark.event_style.group_accent_color = Color("#ff8800")
	window._prepare(dock, dark)
	ok = SUPPORT.check(P, "and follows the theme of the next open", window._quick_accent.color, Color("#ff8800")) and ok
	window._dialog.free()
	dock.free()
	return ok


static func _plain_labels() -> bool:
	var window: EventSheetThemeEditor = EventSheetThemeEditor.new()
	var dock: Control = _recorder_dock()
	window._prepare(dock, null)
	var labels: Array[String] = []
	for spin_node: Node in window._detail_form.find_children("*", "SpinBox", true, false):
		labels.append((spin_node.get_parent().get_child(0) as Label).text)
	var ok: bool = SUPPORT.check(P, "a row reads in plain words, as Godot's Inspector spells a property",
		labels.has("Condition Lane Ratio") and not labels.has("condition_lane_ratio"), true)
	var spin: SpinBox = null
	for spin_node: Node in window._detail_form.find_children("*", "SpinBox", true, false):
		if (spin_node.get_parent().get_child(0) as Label).text == "Condition Lane Ratio":
			spin = spin_node as SpinBox
	if spin != null:
		spin.focus_entered.emit()
	ok = SUPPORT.check(P, "the strip still gives the exact field name and the file line",
		window._in_file.text.begins_with("condition_lane_ratio = ") and window._this_field.text.begins_with("condition_lane_ratio: "), true) and ok
	window._dialog.free()
	dock.free()
	return ok


static func _dead_swatches() -> bool:
	var shown: Array[String] = []
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	for sub: Resource in [style.event_style, style.reading_style, style.chrome_style]:
		for token: Dictionary in EventSheetThemeEditor.editable_tokens(sub):
			shown.append(str(token["name"]))
	var still_shown: Array[String] = []
	for dead: String in DEAD_TOKENS:
		if shown.has(dead):
			still_shown.append(dead)
	var ok: bool = SUPPORT.check(P, "no swatch that drives nothing is in the form", still_shown, [])
	style.event_style.group_badge_background_color = Color("#123456")
	style.chrome_style.drawer_handle_color = Color("#654321")
	var path: String = "user://theme_window_dead_swatches.tres"
	ResourceSaver.save(style, path)
	var back: EventSheetEditorStyle = load(path) as EventSheetEditorStyle
	ok = SUPPORT.check(P, "a hidden swatch is still saved and loaded",
		[back.event_style.group_badge_background_color, back.chrome_style.drawer_handle_color], [Color("#123456"), Color("#654321")]) and ok
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return ok


static func _descriptions() -> bool:
	var ok: bool = true
	for token_name: String in ["group_row_height", "group_background_color", "group_accent_color", "group_title_color", "group_corner_radius", "minimap_group_color", "minimap_band_color"]:
		var words: String = EventSheetThemeEditor._token_description(token_name)
		ok = SUPPORT.check(P, "%s says Section where the sheet does" % token_name, words.to_lower().contains("group"), false) and ok
	ok = SUPPORT.check(P, "the debugger accent names the tab it tints now",
		EventSheetThemeEditor._token_description("debugger_accent_color").contains("Profile"), false) and ok
	ok = SUPPORT.check(P, "the warning amber names every finding it marks",
		EventSheetThemeEditor._token_description("object_bar_warning_color").contains("finding"), true) and ok
	return ok
