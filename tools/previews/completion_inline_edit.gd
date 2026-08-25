# Godot EventSheets - the same completion popup inside a row (preview module).
#
# Rendered by tools/render_previews.gd. Double-clicking a value in a row opens a one-field editor at
# the mouse, and it now carries the popup the dialog carries: same list, same sources, same keys.
# The row above it is drawn from the sheet's own reading so the picture shows what is being edited.
@tool
extends RefCounted

const PREVIEW_NAME: String = "completion-inline-edit"
const PREVIEW_SIZE: Vector2i = Vector2i(620, 340)


static func build(host: Window) -> Control:
	var sheet: EventSheetResource = _sheet()
	var column: VBoxContainer = EventSheetPopupUI.form_box()
	column.add_child(_row_line())
	var editor: VBoxContainer = VBoxContainer.new()
	editor.add_theme_constant_override("separation", 2)
	var value: LineEdit = LineEdit.new()
	value.text = "max_"
	value.custom_minimum_size = Vector2(260.0, 0.0)
	editor.add_child(value)
	var list: ItemList = ItemList.new()
	list.custom_minimum_size = Vector2(0.0, 96.0)
	for entry: Dictionary in EventSheetCompletions.for_field(sheet,
			EventSheetCompletions.FIELD_EXPRESSION, "max_"):
		list.add_item(EventSheetCompletionPopup.item_text(entry))
	if list.item_count > 0:
		list.select(0)
	editor.add_child(list)
	editor.add_child(EventSheetPopupUI.hint_label(
		"Tab or Enter accepts, Escape keeps what you typed", 380.0))
	column.add_child(EventSheetPopupUI.panel_section(editor))
	var margined: MarginContainer = EventSheetPopupUI.margined(
		EventSheetPopupUI.titled_card("Editing a value in the row", column))
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined


## The row the edit is happening in, as the canvas reads it.
static func _row_line() -> Control:
	var line: Label = Label.new()
	line.text = "6    Boss - hp  <  max_"
	line.add_theme_font_size_override("font_size", EventSheetPalette.scaled(14))
	return EventSheetPopupUI.panel_section(line)


static func _sheet() -> EventSheetResource:
	EventSheetCompletions.clear_cache()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Boss"
	sheet.host_class = "Node2D"
	sheet.variables["hp"] = {"type": "int", "default": 100}
	sheet.variables["max_hp"] = {"type": "int", "default": 100}
	sheet.variables["max_rage"] = {"type": "float", "default": 1.0}
	return sheet
