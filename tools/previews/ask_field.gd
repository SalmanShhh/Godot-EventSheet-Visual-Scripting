# Godot EventSheets - the Quick Add field answering (preview module).
#
# Rendered by tools/render_previews.gd. NOTHING in the list is composed here: a real dock is given a
# real sheet, the Doctor findings are recorded exactly as a real audit records them, and the list is
# whatever EventSheetAskField.entries() returns for the typed word - drawn with the completion
# popup's own `item_text`, and with its own headings disabled the way the popup disables them. So the
# picture cannot show a line, a label or an order the editor would not produce.
#
# What is drawn as a panel here is an OS-level popup window in the editor, which a screenshot of one
# window cannot contain.
@tool
extends RefCounted

const PREVIEW_NAME: String = "ask-field"
const PREVIEW_SIZE: Vector2i = Vector2i(760, 600)

## The word being typed - one that is a state's name, a row's words and a finding's subject at once,
## which is the whole reason the answers are grouped and labelled rather than piled up.
const TYPED: String = "chase"


static func build(host: Window) -> Control:
	var dock: EventSheetEditor = EventSheetEditor.new()
	dock._current_sheet = _sheet()
	dock._current_sheet_path = "res://enemy.gd"
	EventSheetCompletions.clear_cache()
	EventSheetProjectOutline.set_doctor_findings(_findings())
	var entries: Array[Dictionary] = dock._ask_field.entries(TYPED)
	EventSheetProjectOutline.clear_doctor_findings()
	dock.free()

	var column: VBoxContainer = EventSheetPopupUI.form_box()
	var field: LineEdit = LineEdit.new()
	field.text = TYPED
	field.caret_column = TYPED.length()
	column.add_child(EventSheetPopupUI.form_row("Quick add or find", field))
	column.add_child(_answer_list(entries))
	var card: PanelContainer = EventSheetPopupUI.titled_card("Enemy", column)
	var margined: MarginContainer = EventSheetPopupUI.margined(card)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined


## The list as the popup draws it: one row per entry, the value then the line that explains it, the
## headings unselectable, the first answer highlighted, and the keyboard model said underneath.
static func _answer_list(entries: Array[Dictionary]) -> Control:
	var list: ItemList = ItemList.new()
	list.custom_minimum_size = Vector2(0.0, 440.0)
	for entry: Dictionary in entries:
		var at: int = list.add_item(EventSheetCompletionPopup.item_text(entry))
		if EventSheetCompletionPopup.is_heading(entry):
			list.set_item_selectable(at, false)
			list.set_item_disabled(at, true)
	if list.item_count > 0:
		list.select(0)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.add_child(list)
	column.add_child(EventSheetPopupUI.hint_label(
		"Enter adds the row, as it always did. Down arrow reaches the answers; Enter goes there.", 460.0))
	return EventSheetPopupUI.panel_section(column)


## The object being read: a state machine, the rows that drive it, and the names it is built from.
static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Enemy"
	sheet.host_class = "CharacterBody2D"
	var states: EnumRow = EnumRow.new()
	states.enum_name = EventSheetStateFacts.ENUM_NAME
	states.members = PackedStringArray(["PATROL", "CHASE", "STAGGER"])
	sheet.events.append(states)
	var speed: LocalVariable = LocalVariable.new()
	speed.name = "chase_speed"
	speed.type_name = "float"
	sheet.events.append(speed)
	var announced: SignalRow = SignalRow.new()
	announced.signal_name = "gave_up"
	sheet.events.append(announced)
	for said: String in ["Chase the player while they are in sight",
			"Set chase_speed to 240", "Stop the chase when too far away"]:
		var event_row: EventRow = EventRow.new()
		event_row.event_uid = "preview-%s" % said.to_lower().replace(" ", "-")
		var action: ACEAction = ACEAction.new()
		action.ace_id = "SetProperty"
		action.params = {"value": said}
		event_row.actions.append(action)
		sheet.events.append(event_row)
	var published: EventFunction = EventFunction.new()
	published.function_name = "begin_chase"
	sheet.functions.append(published)
	return sheet


## What the last Doctor run said - recorded through the one store the Project bar and the inbox both
## read, so the finding in the list is the finding on the Doctor's own page.
static func _findings() -> Array:
	return [{
		"check": "state-unreachable",
		"path": "res://enemy.gd",
		"subject": "CHASE",
		"severity": "warning",
		"message": "Nothing leaves Chase once the player is out of sight.",
	}]
