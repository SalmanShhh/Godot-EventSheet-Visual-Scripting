# Godot EventSheets - the picker's "Lights in this scene" shelf (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The shelf is the whole of L1's claim about picking: a reader arrives asking "which of MY lights",
# and the answer is one folder, one sub-folder per light saying what kind it is and whether it casts
# shadows, and inside it exactly the verbs that light's class answers to.
#
# The sheet is the lit-room fixture the suite already measures, so the picture and the test are about
# the same three lights.
@tool
extends RefCounted

const PREVIEW_NAME: String = "lighting-picker-shelf"
const PREVIEW_SIZE: Vector2i = Vector2i(760, 560)

const FIXTURE: String = "res://tests/fixtures/lighting_scene_room.gd"


static func build(host: Window) -> Control:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = FIXTURE
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var tree: Tree = Tree.new()
	tree.hide_root = true
	tree.custom_minimum_size = Vector2(0.0, 440.0)
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fill(tree, ACEPickerDialog.light_row_definitions(sheet, registry))
	var card: Control = EventSheetPopupUI.titled_card(
		"%s   %s" % [ACEPickerDialog.LIGHTS_GROUP, "Room.tscn"], tree)
	var margined: MarginContainer = EventSheetPopupUI.margined(card)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined


## The shelf as the picker files it: one folder per light (the group key the picker computes), the
## verbs under it in the order the vocabulary offers them.
static func _fill(tree: Tree, offered: Array[ACEDefinition]) -> void:
	var root: TreeItem = tree.create_item()
	var folders: Dictionary = {}
	for definition: ACEDefinition in offered:
		var key: String = ACEPickerDialog.light_group_key(definition)
		if not folders.has(key):
			var folder: TreeItem = tree.create_item(root)
			folder.set_text(0, key.get_slice(ACEPickerDialog.SUBCATEGORY_SEPARATOR, 1))
			folder.set_selectable(0, false)
			folder.set_custom_color(0, ACEPickerDialog.GROUP_COLOR_NODE_TYPE)
			folders[key] = folder
		var item: TreeItem = tree.create_item(folders[key] as TreeItem)
		item.set_text(0, "%s      %s" % [definition.display_name, _echo(definition)])


## The line the row will write, with the light already in it - the same echo the params dialog puts
## on its help strip, and the place a reader sees the property their own light really has.
static func _echo(definition: ACEDefinition) -> String:
	var target: String = str(definition.metadata.get(ACEPickerDialog.LIGHT_TARGET_META, ""))
	var template: String = str(definition.metadata.get("codegen_template", ""))
	return template.replace("{target.}", "%s." % target).replace("{target}", target)
