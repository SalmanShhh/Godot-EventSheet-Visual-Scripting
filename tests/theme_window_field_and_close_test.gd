# Godot EventSheets - The Theme Editor window's legend, its light accent, its Theme field and its closing question.
#
# A line of quiet words says what the dashed box, the chain and the mark beside a swatch mean. Quick Style has
# an accent for each column and one accent still works. The Theme field lists every theme with a swatch, its
# folder and a tooltip, and one sentence under it says what the open theme is. Closing a window with changes
# asks over the window; Discard puts the file's colours back and closes it.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const FILES := preload("res://tests/theme_window_files_test.gd")
const P := "theme_window_field_and_close_test"
const STARTER := "res://addons/eventsheet/themes/editor_native_theme.tres"
const NORD := "res://demo/themes/nord_theme.tres"


static func run() -> bool:
	var ok: bool = true
	ok = _legend() and ok
	ok = _light_accent() and ok
	ok = _theme_field() and ok
	ok = _closing() and ok
	return ok


static func _legend() -> bool:
	var dock: Control = FILES.recorder_dock()
	var window: EventSheetThemeEditor = FILES.open_window(STARTER, dock)
	var legend: Node = window._detail_form.get_node_or_null("Legend")
	var words: Array[String] = []
	if legend != null:
		for label: Node in legend.find_children("*", "Label", true, false):
			words.append((label as Label).text)
	var ok: bool = SUPPORT.pins(P + ": the legend", [
		["the legend sits above the swatch list", legend != null and legend.get_index() == 0, true],
		["it names the dashed box, the chain and the mark", words.filter(func(word: String) -> bool: return word.length() > 1), ["worked out from the editor", "same colour in both", "hard to read on its row"]],
	])
	window._dialog.free()
	dock.free()
	return ok


static func _light_accent() -> bool:
	var dock: Control = FILES.recorder_dock()
	var path: String = FILES.theme_file("field_close_accent.tres", Color("#202020"))
	var window: EventSheetThemeEditor = FILES.open_window(path, dock)
	var light: GDScript = load("res://addons/eventsheet/theme/light_colors.gd")
	window._quick_accent.color = Color("#cc4433")
	window._quick_accent.color_changed.emit(Color("#cc4433"))
	var followed: Color = window._quick_light_accent.color
	window._quick_light_accent.color = Color("#2255aa")
	window._quick_accent.color = Color("#33cc44")
	window._quick_accent.color_changed.emit(Color("#33cc44"))
	var kept: Color = window._quick_light_accent.color
	window._generate_quick_style()
	var block: Resource = window._working_style.event_style
	var ok: bool = SUPPORT.pins(P + ": the light accent", [
		["a light accent not picked on its own moves with the dark one", followed, Color("#cc4433")],
		["a light accent that was picked stays", kept, Color("#2255aa")],
		["Generate gives the dark column the dark accent", block.get("group_accent_color"), Color("#33cc44")],
		["and the light column its own accent", light.entry_of(block, "group_accent_color"), Color("#2255aa")],
	])
	window._dialog.free()
	dock.free()
	return ok


static func _theme_field() -> bool:
	var dock: Control = FILES.recorder_dock()
	var window: EventSheetThemeEditor = FILES.open_window(NORD, dock)
	var field: OptionButton = window._theme_field
	var rows: Dictionary = {}
	var titles: Array[String] = []
	for index: int in range(field.item_count):
		if field.is_item_separator(index):
			titles.append(field.get_item_text(index))
		else:
			rows[str(field.get_item_metadata(index))] = index
	var nord: int = int(rows[NORD])
	var starter: int = int(rows[STARTER])
	var ok: bool = SUPPORT.pins(P + ": the Theme field", [
		["the groups are titled", titles.slice(0, 2), ["Follows the editor", "In this project"]],
		["the starters' title says to copy them", titles[titles.size() - 1], "Starters (copy to edit)"],
		["every theme carries a swatch", field.get_item_icon(nord) != null and field.get_item_icon(starter) != null, true],
		["an entry names the theme and its folder", field.get_item_text(nord), "Nord     demo/themes/"],
		["Match Editor has no folder", field.get_item_text(int(rows[""])), "Match Editor"],
		["a tooltip names the file", field.get_item_tooltip(starter).begins_with(STARTER), true],
		["the closed field names only the theme", field.text, "Nord"],
		["the sentence under it says a demo is saved as a copy", window._theme_note.text.contains("Save a Copy"), true],
	])
	var mine: String = FILES.theme_file("field_close_mine.tres", Color("#202020"))
	var own: EventSheetThemeEditor = FILES.open_window(mine, dock)
	ok = SUPPORT.check(P, "a theme of the project's own says Save writes it in place", own._theme_note.text.contains("Save writes it in place"), true) and ok
	window._dialog.free()
	own._dialog.free()
	dock.free()
	return ok


static func _closing() -> bool:
	var dock: Control = FILES.recorder_dock()
	var path: String = FILES.theme_file("field_close_closing.tres", Color("#202020"))
	var window: EventSheetThemeEditor = FILES.open_window(path, dock)
	FILES.edit(window, "row_background_color", Color("#3a1010"))
	window._dialog.show()
	window.request_close()
	var prompt: ConfirmationDialog = window._close_prompt
	var still: bool = window._dialog.visible
	prompt.custom_action.emit(&"small_prompt_danger")
	var ok: bool = SUPPORT.pins(P + ": closing with changes", [
		["the window is still up while the question is asked", still, true],
		["Discard closes the window", window._dialog.visible, false],
		["and the window holds no changes", window.is_changed(), false],
		["with the file's colour back in it", window._working_style.event_style.row_background_color, Color("#202020")],
	])
	if is_instance_valid(prompt):
		prompt.free()
	window._dialog.free()
	dock.free()
	return ok
