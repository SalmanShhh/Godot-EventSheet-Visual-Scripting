# Godot EventSheets - the Collide With Layer dialog, with the layer picker open (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The field and its words are read off the SHIPPED descriptor rather than retyped here, so the
# picture cannot drift from the row. What is drawn as a list panel under the Layer field is an
# OS-level popup window in the editor, which a screenshot of one window cannot contain.
#
# The picture needs a project that HAS named its layers, and this repository has not - so the names
# are written IN MEMORY for this throwaway render process. Nothing is saved: the write is
# `set_setting` with no `save()`, so project.godot is untouched.
@tool
extends RefCounted

const PREVIEW_NAME: String = "layer-picker-dialog"
const PREVIEW_SIZE: Vector2i = Vector2i(940, 660)

## The row this dialog belongs to, and the module it is declared in.
const ACE_ID: String = "CollideWithLayer"
const MODULE: String = "res://addons/eventforge/registration/modules/collision_aces.gd"

## The layer names the picture is taken against, and the layer the row points at.
const SHOWN_NAMES: Array = ["World", "Enemies", "Player", "Pickups"]
const SHOWN_LAYER: int = 2

## The layer the door in the picture is about: the first one past the named ones, which is what an
## unnamed layer looks like when the project has already named others.
const UNNAMED_LAYER: int = 5

## And the layer a row can also point at: an expression the author wrote, which the field must hand
## back exactly as it found it.
const EXPRESSION_LAYER: String = "wall_layer"


static func build(host: Window) -> Control:
	_write_layer_names()
	var descriptor: ACEDescriptor = _descriptor()
	var layer: ACEParam = _param(descriptor, "layer")
	var fields: VBoxContainer = EventSheetPopupUI.form_box()
	var button: Button = Button.new()
	button.text = EventForgePhysicsLayers.words_for(SHOWN_LAYER,
		EventForgePhysicsLayers.DIMENSION_2D)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_child(EventSheetPopupUI.form_row(layer.get_param_name(), button))
	fields.add_child(_layer_list())
	fields.add_child(_naming_door())
	fields.add_child(_expression_row())
	var strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip()
	strip.describe(layer.get_param_name(), layer.get_param_description())
	# The echo: what the row will write. The NUMBER is what lands in the file - the name is the
	# reading - and the picture says so rather than asking anybody to take it on trust.
	strip.set_reading("Collide with Enemies",
		"set_collision_mask_value(%d, true)" % SHOWN_LAYER)
	var column: VBoxContainer = EventSheetPopupUI.form_box()
	column.add_child(EventSheetPopupUI.panel_section(fields))
	column.add_child(strip)
	var card: PanelContainer = EventSheetPopupUI.titled_card(descriptor.display_name, column)
	var margined: MarginContainer = EventSheetPopupUI.margined(card)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined


## The open picker: the project's own layers, named ones by their name with the number beside them
## and the rest by their number, exactly as the field lists them.
static func _layer_list() -> Control:
	var list: ItemList = ItemList.new()
	list.custom_minimum_size = Vector2(0.0, 190.0)
	for layer: Dictionary in EventForgePhysicsLayers.listed_layers(
			EventForgePhysicsLayers.DIMENSION_2D, SHOWN_LAYER):
		var number: int = int(layer["number"])
		list.add_item("%d  %s" % [number, str(layer["name"])] if bool(layer["named"]) \
			else "Layer %d" % number)
		if number == SHOWN_LAYER:
			list.select(list.item_count - 1)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.add_child(list)
	column.add_child(EventSheetPopupUI.hint_label(
		"The row stores the layer's number - the name is how it reads it back", 460.0))
	return EventSheetPopupUI.panel_section(column)


## The door an UNNAMED layer opens: a name field and the button that writes it into Project
## Settings, with the receipt that write leaves said underneath.
static func _naming_door() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text = "Name for layer %d" % UNNAMED_LAYER
	edit.text = "Hazards"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	var name_it: Button = Button.new()
	name_it.text = "Name it…"
	row.add_child(name_it)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.add_child(EventSheetPopupUI.form_row("Layer %d" % UNNAMED_LAYER, row))
	# The receipt read off the reader that writes it, so the picture cannot say a sentence the door
	# does not: the settings line as it was, and as it now is.
	column.add_child(EventSheetPopupUI.hint_label("%s. Undo puts the number back."
		% EventForgePhysicsLayers.receipt(UNNAMED_LAYER,
			EventForgePhysicsLayers.DIMENSION_2D, "Hazards"), 460.0))
	return EventSheetPopupUI.panel_section(column)


## The third state of the same field, and the one nobody expects to need a picture: the row was
## written with an EXPRESSION in the layer slot. The field shows it as itself and hands it back
## untouched, so opening a row and pressing OK cannot rewrite somebody's code to layer 1.
static func _expression_row() -> Control:
	var button: Button = Button.new()
	button.text = EXPRESSION_LAYER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.add_child(EventSheetPopupUI.form_row("Layer", button))
	column.add_child(EventSheetPopupUI.hint_label(
		"A layer written as an expression reads as itself, and comes back out exactly as it went in",
		460.0))
	return EventSheetPopupUI.panel_section(column)


## The layer names this picture is taken against, written in memory only.
static func _write_layer_names() -> void:
	for index: int in SHOWN_NAMES.size():
		ProjectSettings.set_setting(EventForgePhysicsLayers.setting_path(index + 1,
			EventForgePhysicsLayers.DIMENSION_2D), str(SHOWN_NAMES[index]))


static func _descriptor() -> ACEDescriptor:
	for descriptor: ACEDescriptor in load(MODULE).get_descriptors():
		if str(descriptor.ace_id) == ACE_ID:
			return descriptor
	return ACEDescriptor.new()


static func _param(descriptor: ACEDescriptor, param_id: String) -> ACEParam:
	for parameter: ACEParam in descriptor.params:
		if str(parameter.id) == param_id:
			return parameter
	return ACEParam.new()
