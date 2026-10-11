# Godot EventSheets - the strip laid out as words, and the open tab's edge
#
# View > Text labels lays the resting strip out as words: Sheet, Save, the Undo and Redo arrows, Add
# Event as the one filled button, Add Condition, Add Action, the Find field ("Find", 180 px) pushed to
# the right edge and a Sentences menu holding the variable-row dial and Words. The play button rests
# only on the full strip there. Nothing is added or removed - the same controls are shown, hidden and
# re-faced - so every key, id and handler holds.
#
# Pinned here as values:
#   1. Nobody chose and the theme says nothing: the icon-led strip, untouched.
#   2. A sheet wearing the Editor Native starter opens on text labels, in this order and with these
#      faces, and its open tab wears the starter's accent edge as a two-pixel top border.
#   3. The reader's own choice wins over the theme, and taking text labels off puts back exactly
#      the faces the strip was built with.
#   4. A theme with a clear edge leaves the tab bar's own style alone.
#   5. Sentences offers the three variable-row modes, ticked on the live one, then Words.
@tool
class_name ToolbarTextLabelsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "toolbar_text_labels_test"
const STARTER_PATH := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_PATH := "res://addons/eventsheet/themes/classic_sheet_theme.tres"

## The resting strip as the icon-led layout shows it, and as the Text labels layout shows it.
const ICON_ROW := [
	"EventSheetMenu", "EventSheetSaveButton", "EventSheetUndoButton", "EventSheetRedoButton",
	"EventSheetPlaySlot", "EventSheetQuickAdd", "EventSheetMomentSegment",
	"EventSheetToolbarExpander",
]
const TEXT_ROW := [
	"EventSheetMenu", "EventSheetSaveButton", "EventSheetUndoButton", "EventSheetRedoButton",
	"EventSheetAddSeparator", "Add Event", "Add Condition", "Add Action",
	"EventSheetFindSpacer", "EventSheetQuickAdd", "EventSheetMomentSegment",
	"EventSheetSentencesMenu", "EventSheetToolbarExpander",
]


static func run() -> bool:
	var ok: bool = true
	ok = _test_nobody_chose_and_the_theme_is_quiet() and ok
	ok = _test_the_starter_opens_on_words() and ok
	ok = _test_the_readers_choice_wins() and ok
	ok = _test_a_clear_edge_leaves_the_tab_alone() and ok
	ok = _test_the_sentences_menu() and ok
	EventSheetActiveTheme.publish(null)
	return ok


static func _test_nobody_chose_and_the_theme_is_quiet() -> bool:
	EventSheetActiveTheme.publish(null)
	var editor: EventSheetEditor = _editor(null)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["the starter file asks for text labels",
			(load(STARTER_PATH) as EventSheetEditorStyle).toolbar_text_labels, true],
		["Classic Sheet does not", (load(CLASSIC_PATH) as EventSheetEditorStyle).toolbar_text_labels, false],
		["with no theme the strip is icon-led", editor._menu_bar.text_labels(), false],
		["and rests exactly as it did", _visible_row(editor), _as_strings(ICON_ROW)],
		["the Menu keeps its own face", _button(editor, "EventSheetMenu").text, "☰ Menu"],
		["the open tab keeps the editor's own style",
			editor._tab_bar.has_theme_stylebox_override("tab_selected"), false],
	])
	editor.free()
	return ok


static func _test_the_starter_opens_on_words() -> bool:
	var editor: EventSheetEditor = _editor(load(STARTER_PATH) as EventSheetEditorStyle)
	var add_event: Button = _button(editor, "Add Event")
	var add_condition: Button = _button(editor, "Add Condition")
	var save: Button = _button(editor, "EventSheetSaveButton")
	var edge: StyleBoxFlat = editor._tab_bar.get_theme_stylebox("tab_selected") as StyleBoxFlat
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a sheet wearing Editor Native opens on text labels", editor._menu_bar.text_labels(), true],
		["the strip reads as words, in this order", _visible_row(editor), _as_strings(TEXT_ROW)],
		["the Menu reads Sheet", _button(editor, "EventSheetMenu").text, "Sheet ▾"],
		["but is still the Menu to anything that names it",
			editor._toolbar_control_label(_button(editor, "EventSheetMenu")), "☰ Menu"],
		["Save says its name", save.text, "Save"],
		["and wears no icon", save.icon, null],
		["Add Event is the one filled button", add_event.flat, false],
		["Add Condition is flat", add_condition.flat, true],
		["Add Condition wears no icon", add_condition.icon, null],
		["the play button rests on the full strip only",
			(editor._toolbar.find_child("EventSheetPlaySlot", false, false) as Control).visible, false],
		["the Find field reads Find", editor._quick_add_edit.placeholder_text, "Find"],
		["at the design's width", editor._quick_add_edit.custom_minimum_size.x,
			float(EventSheetPalette.scaled(EventSheetMenuBar.FIND_FIELD_WIDTH))],
		["the Find field is pushed to the right edge",
			(editor._toolbar.find_child("EventSheetFindSpacer", false, false) as Control).size_flags_horizontal,
			Control.SIZE_EXPAND_FILL],
		["the View menu ticks Text labels", editor._view_popup.is_item_checked(
			editor._view_popup.get_item_index(EventSheetMenuBar.TEXT_LABELS_VIEW_ID)), true],
		["the open tab wears an edge", edge != null, true],
		["two pixels along the top", edge.border_width_top if edge != null else -1,
			EventSheetPalette.scaled(2)],
		["and nowhere else", [edge.border_width_left, edge.border_width_right, edge.border_width_bottom]
			if edge != null else [], [0, 0, 0]],
		["in the starter's accent", edge.border_color if edge != null else Color(),
			EventSheetActiveTheme.chrome().active_tab_edge_color],
		["which is the design's blue", EventSheetActiveTheme.chrome().active_tab_edge_color,
			Color("#3a79bb")],
	])
	editor.free()
	return ok


static func _test_the_readers_choice_wins() -> bool:
	var editor: EventSheetEditor = _editor(load(STARTER_PATH) as EventSheetEditorStyle)
	editor._menu_bar.set_text_labels(false)
	# A theme republish (a tab switch, a theme edit) must not take the reader's choice back.
	editor._menu_bar.apply_theme_chrome()
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["the reader's icons win over the starter", editor._menu_bar.text_labels(), false],
		["the strip rests icon-led again", _visible_row(editor), _as_strings(ICON_ROW)],
		["the Menu has its own face back", _button(editor, "EventSheetMenu").text, "☰ Menu"],
		["Add Event is the editor's button again", _button(editor, "Add Event").flat, false],
		["the field has its own face back", editor._quick_add_edit.placeholder_text,
			"Quick add or find…  (e.g. heal 5, or Chase)"],
		["and its own width", editor._quick_add_edit.custom_minimum_size.x, 240.0],
		["and the View tick follows", editor._view_popup.is_item_checked(
			editor._view_popup.get_item_index(EventSheetMenuBar.TEXT_LABELS_VIEW_ID)), false],
	])
	editor._menu_bar.set_text_labels(true)
	EventSheetActiveTheme.publish(null)
	editor._menu_bar.apply_theme_chrome()
	ok = SUPPORT.pins(TEST_NAME, [
		["and the reader's words win over a quiet theme", editor._menu_bar.text_labels(), true],
		["Save still says its name", _button(editor, "EventSheetSaveButton").text, "Save"],
	]) and ok
	editor.free()
	return ok


static func _test_a_clear_edge_leaves_the_tab_alone() -> bool:
	var editor: EventSheetEditor = _editor(load(STARTER_PATH) as EventSheetEditorStyle)
	var had_edge: bool = editor._tab_bar.has_theme_stylebox_override("tab_selected")
	# Every bundled theme now draws the edge in its own accent, so the clear case is a Classic Sheet
	# whose designer cleared it.
	var cleared: EventSheetEditorStyle = (load(CLASSIC_PATH) as EventSheetEditorStyle).duplicate(true)
	cleared.get_chrome_style().active_tab_edge_color = Color(0.0, 0.0, 0.0, 0.0)
	EventSheetActiveTheme.publish(cleared)
	editor._menu_bar.apply_theme_chrome()
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["the starter put an edge on the tab", had_edge, true],
		["a theme that states the edge clear",
			EventSheetActiveTheme.chrome().active_tab_edge_color, Color(0.0, 0.0, 0.0, 0.0)],
		["so the tab's own style comes back", editor._tab_bar.has_theme_stylebox_override("tab_selected"), false],
		["and the strip goes back to icons", editor._menu_bar.text_labels(), false],
	])
	editor.free()
	return ok


static func _test_the_sentences_menu() -> bool:
	EventSheetActiveTheme.publish(null)
	var editor: EventSheetEditor = _editor(null)
	var sentences: MenuButton = editor._toolbar.find_child("EventSheetSentencesMenu", false, false) as MenuButton
	var popup: PopupMenu = sentences.get_popup()
	editor._menu_bar._fill_sentences_menu(popup)
	var items: PackedStringArray = PackedStringArray()
	for index: int in popup.item_count:
		items.append("%s|%d|%s" % [popup.get_item_text(index), popup.get_item_id(index),
			str(popup.is_item_checked(index))])
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["Sentences rests hidden on the icon-led strip", sentences.visible, false],
		["Tab reaches it", sentences.focus_mode, Control.FOCUS_ALL],
		["it offers the variable-row dial, ticked on the live mode, then Words", items,
			PackedStringArray(["Variable rows|-1|false", "sentence|0|false", "both|1|true",
				"code|2|false", "|-1|false", "Words…|%d|false" % EventSheetMenuBar.SENTENCES_WORDS_ID])],
	])
	popup.id_pressed.emit(EventSheetCodeEcho.VIEW_SENTENCE)
	ok = SUPPORT.pins(TEST_NAME, [
		["picking a mode turns the same dial View > Variable rows turns", editor.variable_row_view(),
			EventSheetCodeEcho.VIEW_SENTENCE],
	]) and ok
	editor.free()
	return ok


## The names of the strip's visible children, in order - a button that has no name of its own is
## read by the words it was built with.
static func _visible_row(editor: EventSheetEditor) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for child: Node in editor._toolbar.get_children():
		if not (child as Control).visible:
			continue
		var shown: String = str(child.name)
		if shown.begins_with("@") and child is Button:
			shown = editor._toolbar_control_label(child as Button)
		names.append(shown)
	return names


## A strip button by node name, or by the words it was built with.
static func _button(editor: EventSheetEditor, wanted: String) -> Button:
	for child: Node in editor._toolbar.get_children():
		if not (child is Button):
			continue
		if str(child.name) == wanted or editor._toolbar_control_label(child as Button) == wanted:
			return child as Button
	return null


static func _as_strings(values: Array) -> PackedStringArray:
	var typed: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		typed.append(str(value))
	return typed


static func _editor(theme: EventSheetEditorStyle) -> EventSheetEditor:
	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.editor_style = theme
	editor.setup(sheet)
	return editor
