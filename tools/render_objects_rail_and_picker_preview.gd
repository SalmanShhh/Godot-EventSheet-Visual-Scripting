# EventForge - render harness (dev tool) for the OBJECT model: the Objects rail, the object popup,
# and the picker's Functions page. Opens tests/fixtures/objects_reading_fixture.gd the way the dock
# opens a .gd (a read-only preview) and shoots three images:
#   docs/images/objects-rail.png          - the sheet's rows beside the left rail's Objects section
#   docs/images/object-popup.png          - what a click on a row's object name opens
#   docs/images/picker-functions-page.png - the picker's object page for an opened .gd
# Each run also PRINTS what it drew, so it doubles as a text check: the image proves the look, the
# printout proves the words.
#
# Run NON-headless (headless runs cannot render, and have no editor theme to draw icons from):
#   godot --path . --script tools/render_objects_rail_and_picker_preview.gd
@tool
extends SceneTree

const FIXTURE_PATH := "res://tests/fixtures/objects_reading_fixture.gd"
## The picker page needs a file that DECLARES verbs; the objects fixture is about the objects a file
## uses, and declares none. Two fixtures, because the two images are about two different things.
const FUNCTIONS_FIXTURE_PATH := "res://tests/fixtures/picker_functions_fixture.gd"
const BASE_COLOR := Color("#252525")
const SCENE_NAME := "Player.tscn"
## Which object's popup is shot - the behaviour, because it is the entry that exercises every row
## the popup can answer with (a pack type, a node path, verbs, and both live buttons).
const POPUP_OBJECT := "Health"
const RAIL_WIDTH := 250.0

var _shots: Array[Image] = []
var _frames: int = 0
var _stage: int = 0
var _sheet: EventSheetResource = null
var _view: EventSheetViewport = null
var _rail: EventSheetObjectsPanel = null
var _overlay: Control = null
var _picker: ACEPickerDialog = null


func _init() -> void:
	root.title = "Objects rail, object popup, picker functions page"
	# Sized to fit the screen, NOT to the width the content would like: a window the display clamps
	# still LAYS OUT at the size it was asked for, so a generous request pushed the action lane -
	# the half of each row these images exist to show - past the edge of the captured pixels.
	root.size = Vector2i(1140, 640)
	# Dialogs and popups draw inside the window rather than as their own OS windows, which is the
	# only way a shot can contain one.
	root.gui_embed_subwindows = true
	var background: ColorRect = ColorRect.new()
	background.color = BASE_COLOR.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	_sheet = _open_fixture()
	_build_rail_stage()
	root.gui_disable_input = true
	process_frame.connect(_on_frame)


## The fixture as the dock opens it: a read-only preview, themed the way the editor themes a sheet.
func _open_fixture(path: String = FIXTURE_PATH) -> EventSheetResource:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	sheet.read_only = true
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(
		style, BASE_COLOR, BASE_COLOR.darkened(0.15), BASE_COLOR.darkened(0.25),
		Color("#569eff"), Color("#ced0d2")
	)
	# The object column is a user-draggable width. Set wide enough here that an autoload's "(global)"
	# note survives the elide, which is the whole point of the shot - at the stock width the note is
	# the first thing to go, and the row would look like it says nothing new.
	style.event_style.condition_object_column_width = 200
	style.event_style.action_object_column_width = 200
	sheet.editor_style = style
	return sheet


## Stage 1a - the rail on its own. The rail and the rows are shot SEPARATELY and composed side by
## side at the end, because the viewport divides its lanes across the width it is GIVEN: sharing the
## window with the rail pushed the action lane - the half of every row this image exists to show -
## off the right edge. Two shots, each laid out full width, one picture.
func _build_rail_stage() -> void:
	_rail = EventSheetObjectsPanel.new()
	_rail.position = Vector2(8.0, 8.0)
	_rail.size = Vector2(RAIL_WIDTH, 300.0)
	root.add_child(_rail)
	_rail.set_expanded(true)
	_rail.set_sheet(_sheet)
	print("[preview] Objects rail")
	for entry: Dictionary in _rail.entries():
		print("  rail: %s" % EventSheetObjectsPanel.entry_text(entry))


## Stage 1b - the rows, with the whole window to lay out in.
func _build_rows_stage() -> void:
	_clear_stage()
	_view = EventSheetViewport.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.set_ace_registry(EventSheetACERegistry.new())
	root.add_child(_view)
	_view.set_sheet(_sheet)
	_view.set_reading_mode(true)
	_print_rows()


## The rail shot and the rows shot, laid side by side - which is where they sit in the editor.
func _compose_rail_image() -> void:
	var rail: Image = _shots[0]
	var rows: Image = _shots[1]
	var height: int = maxi(rail.get_height(), rows.get_height())
	var canvas: Image = Image.create_empty(rail.get_width() + rows.get_width(), height, false, rows.get_format())
	canvas.fill(BASE_COLOR.darkened(0.4))
	canvas.blit_rect(rail, Rect2i(Vector2i.ZERO, rail.get_size()), Vector2i.ZERO)
	canvas.blit_rect(rows, Rect2i(Vector2i.ZERO, rows.get_size()), Vector2i(rail.get_width(), 0))
	canvas.save_png("res://docs/images/objects-rail.png")
	print("[preview] wrote res://docs/images/objects-rail.png (%dx%d)" % [canvas.get_width(), canvas.get_height()])


## Stage 2 - the object popup, built by the same static builder the live click uses, so the image
## cannot show a panel the editor would not.
func _build_popup_stage() -> void:
	_clear_stage()
	var entry: Dictionary = EventSheetObjectProperties.find_entry(_sheet, POPUP_OBJECT)
	var panel: Control = EventSheetObjectProperties.build_panel(
		entry, SCENE_NAME, EventSheetViewportReadingRows.object_class_map(_sheet),
		func() -> void: pass, func() -> void: pass, func() -> void: pass
	)
	var card: PanelContainer = PanelContainer.new()
	card.position = Vector2(60.0, 40.0)
	card.add_child(panel)
	root.add_child(card)
	_overlay = card
	print("[preview] object popup for %s" % POPUP_OBJECT)
	for row: Dictionary in EventSheetObjectProperties.property_rows(entry, SCENE_NAME):
		print("  popup: %s = %s" % [str(row.get("label", "")), str(row.get("value", ""))])
	print("  popup: Select in scene enabled = %s" % str(
		EventSheetObjectProperties.can_select_in_scene(entry, SCENE_NAME)))


## Stage 3 - the picker opened on the fixture, whose object page leads with the script's own
## functions. Built through the real dialog so the page is the one a user meets. The picker reads
## the open sheet off the node it hangs on (`get_current_sheet`), which in the editor is the dock -
## here it is the stand-in below, so no wiring is faked.
func _build_picker_stage() -> void:
	_clear_stage()
	var functions_sheet: EventSheetResource = _open_fixture(FUNCTIONS_FIXTURE_PATH)
	var host := PickerHost.new()
	host.sheet = functions_sheet
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	_picker = ACEPickerDialog.new()
	_picker.init_dialog(host, EventSheetACERegistry.new())
	_picker.open("new_event", false, null, {"object_first": true})
	print("[preview] picker object page")
	var content: Dictionary = ACEPickerDialog.functions_page_content(functions_sheet)
	print("  picker: %s   %s" % [str(content.get("title", "")), str(content.get("note", ""))])
	for record: Dictionary in (content.get("published", []) as Array):
		print("  picker published: %s" % str(record.get("label", "")))
	print("  picker: %s" % str(content.get("helpers_header", "")))
	for record: Dictionary in (content.get("helpers", []) as Array):
		print("  picker helper: %s" % str(record.get("label", "")))


## The one thing the picker asks its host for. Standing in for the dock so the page under test is
## built by the real dialog rather than by a copy of its logic.
class PickerHost:
	extends Control

	var sheet: EventSheetResource = null

	func get_current_sheet() -> EventSheetResource:
		return sheet


func _clear_stage() -> void:
	for child: Node in Array(root.get_children()):
		if child is ColorRect:
			continue
		root.remove_child(child)
		child.queue_free()
	_view = null
	_rail = null
	_overlay = null


func _on_frame() -> void:
	_frames += 1
	if _frames < 14:
		return
	_frames = 0
	match _stage:
		0:
			_shots.append(_shot(_rail))
			_build_rows_stage()
		1:
			_shots.append(_shot())
			_compose_rail_image()
			_build_popup_stage()
		2:
			# The popup is a small card on a big window - shot whole, it would be mostly empty canvas.
			_save("res://docs/images/object-popup.png", _overlay)
			_build_picker_stage()
		3:
			_save("res://docs/images/picker-functions-page.png")
			quit(0)
	_stage += 1


## The window shot, optionally trimmed to one control's drawn bounds. The window's backing image can
## be a different size from the window itself (the display scales it), so the crop is taken in the
## IMAGE's own coordinates rather than the control's.
func _shot(crop_to: Control = null) -> Image:
	var image: Image = root.get_texture().get_image()
	if crop_to == null:
		return image
	var scale: float = float(image.get_width()) / maxf(float(root.size.x), 1.0)
	var margin: float = 8.0
	var region := Rect2i(
		Vector2i((crop_to.position - Vector2(margin, margin)) * scale),
		Vector2i((crop_to.size + Vector2(margin, margin) * 2.0) * scale)
	)
	region = region.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	return image.get_region(region) if region.has_area() else image


func _save(path: String, crop_to: Control = null) -> void:
	var image: Image = _shot(crop_to)
	image.save_png(path)
	print("[preview] wrote %s (%dx%d)" % [path, image.get_width(), image.get_height()])


## What the rows actually READ as, so a run proves the words as well as the look.
func _print_rows() -> void:
	for entry: Variant in _view._flat_rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data == null:
			continue
		var cells: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
			var object_label: String = str(metadata.get("object_label", ""))
			cells.append(span.text if object_label.is_empty() else "%s ▸ %s" % [object_label, span.text])
		print("  row: %s" % " | ".join(cells).substr(0, 170))
