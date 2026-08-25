# Godot EventSheets - the completion popup riding a dialog field (preview module).
#
# Rendered by tools/render_previews.gd. The list, its entries and the line under it are built the
# way the real popup builds them - the entries come from the completion seam and each row is
# composed by the popup's own `item_text` - so the picture cannot drift from the behaviour. What is
# drawn as a panel here is an OS-level popup window in the editor, which a screenshot of one window
# cannot contain.
@tool
extends RefCounted

const PREVIEW_NAME: String = "completion-in-dialog"
const PREVIEW_SIZE: Vector2i = Vector2i(720, 420)


static func build(host: Window) -> Control:
	var sheet: EventSheetResource = _sheet()
	var fields: VBoxContainer = EventSheetPopupUI.form_box()
	var value: LineEdit = LineEdit.new()
	value.text = "health + ma"
	fields.add_child(EventSheetPopupUI.form_row("Value", value))
	fields.add_child(_suggestions(EventSheetCompletions.for_field(sheet,
		EventSheetCompletions.FIELD_EXPRESSION, "health + ma")))
	var strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip()
	strip.follow(value, "Value - a value",
		"A number, a variable, or an expression. In scope are Player's variables, the globals and the parameters this function takes.")
	strip.describe("Value - a value",
		"A number, a variable, or an expression. In scope are Player's variables, the globals and the parameters this function takes.")
	strip.set_reading("Player - Set hp to health + max(0, bonus)",
		"hp = health + max(0, bonus)")
	var column: VBoxContainer = EventSheetPopupUI.form_box()
	column.add_child(EventSheetPopupUI.panel_section(fields))
	column.add_child(strip)
	var card: PanelContainer = EventSheetPopupUI.titled_card("Player - Set hp", column)
	var margined: MarginContainer = EventSheetPopupUI.margined(card)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined


## The suggestion list as the popup draws it: one row per entry, the value then the line that
## explains it, and the keyboard model stated underneath.
static func _suggestions(entries: Array[Dictionary]) -> Control:
	var list: ItemList = ItemList.new()
	list.custom_minimum_size = Vector2(0.0, 132.0)
	for entry: Dictionary in entries:
		list.add_item(EventSheetCompletionPopup.item_text(entry))
	if list.item_count > 0:
		list.select(0)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.add_child(list)
	column.add_child(EventSheetPopupUI.hint_label(
		"Tab or Enter accepts, Escape keeps what you typed", 400.0))
	return EventSheetPopupUI.panel_section(column)


## A sheet with the variables, the function and the parameter the picture names.
static func _sheet() -> EventSheetResource:
	EventSheetCompletions.clear_cache()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Player"
	sheet.host_class = "Node2D"
	sheet.variables["hp"] = {"type": "int", "default": 100}
	sheet.variables["max_hp"] = {"type": "int", "default": 100}
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = "take_damage"
	var parameter: ACEParam = ACEParam.new()
	parameter.id = "amount"
	event_function.params.append(parameter)
	sheet.functions.append(event_function)
	return sheet
