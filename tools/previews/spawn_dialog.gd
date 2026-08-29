# Godot EventSheets - the Spawn A Copy dialog, with the placement list open (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The fields and their labels are read off the SHIPPED descriptor rather than retyped here, so the
# picture cannot drift from the row: rename a parameter and this picture renames it too. What is
# drawn as a list panel under the At field is an OS-level popup window in the editor, which a
# screenshot of one window cannot contain.
@tool
extends RefCounted

const PREVIEW_NAME: String = "spawn-dialog"
const PREVIEW_SIZE: Vector2i = Vector2i(940, 700)

## The row this dialog belongs to, and the module it is declared in.
const ACE_ID: String = "SpawnNewCopy"
const MODULE: String = "res://addons/eventforge/registration/modules/spawn_aces.gd"

## What each field is showing. Keyed by parameter id so the values follow the descriptor's own order.
const SHOWN: Dictionary = {
	"scene": "Enemy",
	"name": "new_enemy",
	"at": "$SpawnPoint.global_position",
	"parent": "$Enemies",
}


static func build(host: Window) -> Control:
	var descriptor: ACEDescriptor = _descriptor()
	var fields: VBoxContainer = EventSheetPopupUI.form_box()
	var at_field: LineEdit = null
	for parameter: ACEParam in descriptor.params:
		var field: LineEdit = LineEdit.new()
		field.text = str(SHOWN.get(str(parameter.id), str(parameter.default_value)))
		fields.add_child(EventSheetPopupUI.form_row(parameter.get_param_name(), field))
		if str(parameter.id) == "at":
			at_field = field
			fields.add_child(_placement_list(parameter))
	var strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip()
	var at_param: ACEParam = _param(descriptor, "at")
	strip.describe(at_param.get_param_name(), at_param.get_param_description())
	if at_field != null:
		strip.follow(at_field, at_param.get_param_name(), at_param.get_param_description())
	# The echo: what the row will write. Three statements, so the reader can see that the name they
	# typed in Called is the variable the code declares.
	strip.set_reading("Spawn a copy of Enemy as new_enemy at $SpawnPoint.global_position, under $Enemies",
		"var new_enemy = Enemy.instantiate()\n$Enemies.add_child(new_enemy)\nnew_enemy.global_position = $SpawnPoint.global_position")
	var column: VBoxContainer = EventSheetPopupUI.form_box()
	column.add_child(EventSheetPopupUI.panel_section(fields))
	column.add_child(strip)
	var card: PanelContainer = EventSheetPopupUI.titled_card(descriptor.display_name, column)
	var margined: MarginContainer = EventSheetPopupUI.margined(card)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined


## The placement list the At field offers: the parameter's own suggestions, plus the expressions the
## placement words write. Built from the parameter rather than from a list typed here, so a starter
## added to the row turns up in the picture.
static func _placement_list(parameter: ACEParam) -> Control:
	var list: ItemList = ItemList.new()
	list.custom_minimum_size = Vector2(0.0, 186.0)
	for starter: String in parameter.autocomplete:
		list.add_item(starter)
	for placement: ACEDescriptor in _placement_descriptors():
		list.add_item(placement.display_name)
	if list.item_count > 1:
		list.select(1)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.add_child(list)
	column.add_child(EventSheetPopupUI.hint_label(
		"Any of these writes one expression into the field - it stays a field you can type in", 460.0))
	return EventSheetPopupUI.panel_section(column)


static func _descriptor() -> ACEDescriptor:
	for descriptor: ACEDescriptor in load(MODULE).get_descriptors():
		if str(descriptor.ace_id) == ACE_ID:
			return descriptor
	return ACEDescriptor.new()


## The four answers to "where", in the order the module declares them.
static func _placement_descriptors() -> Array[ACEDescriptor]:
	var found: Array[ACEDescriptor] = []
	for descriptor: ACEDescriptor in load(MODULE).get_descriptors():
		if descriptor.ace_type == ACEDescriptor.ACEType.EXPRESSION:
			found.append(descriptor)
	return found


static func _param(descriptor: ACEDescriptor, param_id: String) -> ACEParam:
	for parameter: ACEParam in descriptor.params:
		if str(parameter.id) == param_id:
			return parameter
	return ACEParam.new()
