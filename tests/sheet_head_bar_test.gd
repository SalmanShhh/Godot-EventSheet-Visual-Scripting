@tool
class_name SheetHeadBarTest
extends RefCounted

# Pins the frame a sheet opens in: ONE head bar, its hover cards, and nothing else between the tabs
# and the rows.
#
# The user's carousel used to open under a title strip, a head card ("CarouselOfJuice - Custom Node ·
# extends Node2D · @ 4 knobs"), a blue banner with Edit Events and Open in Godot Script Editor, and a
# status bar repeating the banner. Now:
#
#   1. the look a new user gets (the editor-matched default) paints the head bar a flat grey a step
#      off the canvas;
#   2. the card behind a word says that word's card and its doors answer as head actions;
#   3. the dock shows no title strip, no identity band and no banner over an opened file - a file a
#      merge has left blocked keeps its banner, the one state that may say so at the head - and the
#      status bar names the file and nothing more;
#   4. the two doors of the name card are in the Sheet menu as well;
#   5. a `.tres` sheet opens on the same head bar; a sheet that lives only in memory has no file to
#      name and opens without one.
#
# Each pin is a VALUE, and each fails on the tree before the change.

const SUPPORT := preload("res://tests/support.gd")
const P := "sheet_head_bar_test"
const CAROUSEL := "res://demo/showcase/carousel/showcase_carousel.gd"
const HEAD_CARD_PATH := "res://addons/eventsheet/editor/interaction/sheet_head_card.gd"
const TRES_PATH := "user://sheet_head_bar_test_sheet.tres"


static func run() -> bool:
	var ok: bool = true
	ok = _the_default_look() and ok
	ok = _the_card() and ok
	ok = _the_frame() and ok
	ok = _a_saved_sheet_opens_on_the_bar() and ok
	return ok


## The editor-matched look, in a dark and a light editor: a grey head bar lighter (dark) or darker
## (light) than the canvas as it is seen, and opaque.
static func _the_default_look() -> bool:
	var dark: EventSheetEventStyle = _matched(Color("#252525"), Color("#d2d2d2"))
	var light: EventSheetEventStyle = _matched(Color("#e0e0e0"), Color("#0f0f0f"))
	var dark_canvas: Color = Color("#252525").blend(Color(0.0, 0.0, 0.0, 0.3))
	var light_canvas: Color = Color("#e0e0e0").blend(Color(0.0, 0.0, 0.0, 0.3))
	var derived: EventSheetEventStyle = EventSheetEditorThemeDeriver.derive(Color("#252525"), Color("#3a72b0")).event_style
	return SUPPORT.pins(P, [
		["its head bar is opaque grey", [dark.head_bar_color.a, is_equal_approx(dark.head_bar_color.r, dark.head_bar_color.b)],
			[1.0, true]],
		["a step lighter than a dark canvas", dark.head_bar_color.get_luminance() > dark_canvas.get_luminance(), true],
		["a step darker than a light canvas", light.head_bar_color.get_luminance() < light_canvas.get_luminance(), true],
		["and the derived default's is grey too, never the accent",
			[derived.head_bar_color.a, is_equal_approx(derived.head_bar_color.r, derived.head_bar_color.b)], [1.0, true]],
	])


static func _matched(base: Color, font: Color) -> EventSheetEventStyle:
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	return EventSheetGodotTheme.apply(style, base, base.darkened(0.1), Color(0.0, 0.0, 0.0, 0.3),
		Color("#3a72b0"), font).event_style


## The behaviours count's card on the carousel: its words, and its door answering as a head action.
static func _the_card() -> bool:
	var rows: Array = _rows_of(CAROUSEL)
	var card_words: Dictionary = {}
	for span: SemanticSpan in (rows[0] as EventRowData).spans:
		var card: Variant = (span.metadata as Dictionary).get("head_card") if span.metadata is Dictionary else null
		if card is Dictionary and str((card as Dictionary).get("id", "")) == "behaviours":
			card_words = card
	var card_view: Control = load(HEAD_CARD_PATH).new()
	var pressed: Array = []
	card_view.connect("door_pressed", func(action: String) -> void: pressed.append(action))
	card_view.call("hover_word", card_words, Rect2(0.0, 0.0, 80.0, 20.0), true)
	var shown: String = str(card_view.call("shown_text"))
	var door_found: bool = bool(card_view.call("press_door", "Add behaviour…"))
	var closed: bool = not card_view.visible
	card_view.free()
	return SUPPORT.pins(P, [
		["the behaviours card says the kinds, why they are not rows, and offers Add behaviour…", shown,
			"Behaviours on this object\nSpring 10 · Tween 10 · Flash 2 · Juice · Scenes · Blend Modes · Screen FX · Sine 8. They are child nodes in the scene, not lines of this file, so they are listed here rather than as rows.\n[Add behaviour…]"],
		["its door answers as a head action, and the card closes", [door_found, pressed, closed],
			[true, ["add_behaviour"], true]],
	])


## The dock around an opened file: no title strip, no identity band, no banner, the file's name on
## the status bar - and a blocked file's banner, which stays.
static func _the_frame() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	dock._load_sheet_from_path(CAROUSEL)
	var frame: Array = [dock._title_strip.visible, dock._identity_banner.visible, dock._preview_banner.visible]
	var status: String = dock._status_label.text
	var sheet_menu: PopupMenu = dock.find_child("EventSheetSheetMenu", true, false) as PopupMenu
	var doors: Array = []
	for id: int in [24, 25]:
		var at: int = sheet_menu.get_item_index(id) if sheet_menu != null else -1
		doors.append(sheet_menu.get_item_text(at) if at >= 0 else "")
	dock._current_sheet.conflict_marker_lines = PackedInt32Array([3])
	dock._preview_glue._refresh_preview_banner()
	var blocked_banner: bool = dock._preview_banner.visible
	dock._current_sheet.conflict_marker_lines = PackedInt32Array()
	dock._preview_glue._refresh_preview_banner()
	var unblocked: bool = dock._preview_banner.visible
	dock._head_actions.handle("show_in_filesystem")
	var shown_status: String = dock._status_label.text
	dock.free()
	return SUPPORT.pins(P, [
		["no title strip, no identity band, no banner over an opened file", frame, [false, false, false]],
		["the status bar names the file and nothing more", status, "showcase_carousel.gd"],
		["the Sheet menu carries the name card's two doors", doors, ["Open in Script Editor", "Show in FileSystem"]],
		["a file a merge has left blocked keeps its banner, and only while it is blocked",
			[blocked_banner, unblocked], [true, false]],
		["Show in FileSystem answers for the file", shown_status, "showcase_carousel.gd - shown in the FileSystem dock."],
	])


## A sheet saved as a `.tres` has no head lines of its own and still opens on the bar; one that lives
## only in memory has no file to name.
static func _a_saved_sheet_opens_on_the_bar() -> bool:
	var saved: EventSheetResource = EventSheetResource.new()
	saved.take_over_path(TRES_PATH)
	var in_memory: EventSheetResource = EventSheetResource.new()
	var saved_rows: Array = _rows_of_sheet(saved)
	var memory_rows: Array = _rows_of_sheet(in_memory)
	return SUPPORT.pins(P, [
		["a .tres sheet opens on the head bar, named by its file",
			_words_of(saved_rows[0]) if not saved_rows.is_empty() else "",
			"◆ sheet_head_bar_test_sheet.tres Script · extends Node"],
		["a sheet only in memory opens without one", memory_rows.is_empty() or not
			str((memory_rows[0] as EventRowData).row_uid).begins_with("sheet_head_bar_"), true],
	])


static func _rows_of(path: String) -> Array:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	sheet.read_only = true
	return _rows_of_sheet(sheet)


static func _rows_of_sheet(sheet: EventSheetResource) -> Array:
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	var rows: Array = viewport._root_rows.duplicate()
	viewport.free()
	return rows


static func _words_of(row_data: EventRowData) -> String:
	var words: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		if not span.text.strip_edges().is_empty():
			words.append(span.text.strip_edges())
	return " ".join(words)
