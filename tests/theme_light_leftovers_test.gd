# Godot EventSheets - The small things the light-colours work left right.
#
# The Reading font field says what goes in it whole, the Shared Sheets window's list is headed with the same
# words as its title, the Sheet theme menu has a way back to the editor's own look while the project names a
# theme for every sheet, and a theme saved while the open sheet carries its own copy says that copy stays.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const FILES := preload("res://tests/theme_window_files_test.gd")
const CHOICES_PATH := "res://addons/eventsheet/theme/theme_choices.gd"
const P := "theme_light_leftovers_test"
const STARTER := "res://addons/eventsheet/themes/editor_native_theme.tres"
const NORD := "res://demo/themes/nord_theme.tres"


static func run() -> bool:
	var ok: bool = true
	ok = _reading_font_hint() and ok
	ok = _shared_sheets_heading() and ok
	ok = _the_way_back_to_the_editor() and ok
	return ok


## The words that say what the Reading font field takes sit on a line of their own, whole, above the short field.
static func _reading_font_hint() -> bool:
	var dock: Control = FILES.recorder_dock()
	var window: EventSheetThemeEditor = FILES.open_window(STARTER, dock)
	var hint: Label = null
	var field: LineEdit = null
	for node: Node in window._dialog.find_children("*", "Label", true, false):
		if (node as Label).text.begins_with("res://"):
			hint = node as Label
	for node: Node in window._dialog.find_children("*", "LineEdit", true, false):
		if (node as LineEdit).placeholder_text.begins_with("res://"):
			field = node as LineEdit
	var ok: bool = SUPPORT.pins(P + ": the Reading font field", [
		["its words are a wrapping line of their own", hint != null and hint.autowrap_mode != TextServer.AUTOWRAP_OFF, true],
		["and say the whole of it", hint.text if hint != null else "", "res://… .ttf or .otf - blank keeps the editor's own font"],
		["the field itself holds a short example, not the sentence", field.placeholder_text if field != null else "", "res://…"],
	])
	window._dialog.free()
	dock.free()
	return ok


## The list in the Shared Sheets window is headed with the same words as the window's title.
static func _shared_sheets_heading() -> bool:
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	editor.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	editor._includes.open()
	var window: Window = editor._includes._include_manager_window
	var heading: String = ""
	var old_heading: bool = false
	for node: Node in window.find_children("*", "Label", true, false):
		var text: String = (node as Label).text
		heading = text if text == "Shared Sheets" else heading
		old_heading = old_heading or text == "Included sheets"
	window.hide()
	editor.free()
	return SUPPORT.pins(P + ": the Shared Sheets window", [
		["the list is headed Shared Sheets", heading, "Shared Sheets"],
		["and no heading says Included sheets", old_heading, false],
	])


static func _the_way_back_to_the_editor() -> bool:
	var choices: GDScript = load(CHOICES_PATH)
	return SUPPORT.pins(P + ": the Sheet theme menu", [
		["with no project theme the starter keeps its own name", choices.entry_text("Editor Native", STARTER, ""), "Editor Native"],
		["with a project theme the starter is the way back to Match Editor", choices.entry_text("Editor Native", STARTER, NORD), "Match Editor"],
		["any other theme keeps its name either way", choices.entry_text("Nord", NORD, NORD), "Nord"],
	])
