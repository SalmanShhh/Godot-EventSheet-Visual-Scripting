# Godot EventSheets - the picker's shelf for the signals a project's own scripts declare (preview).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The claim is that a signal somebody wrote years ago is an event waiting to be picked: one folder
# per scripted node of the open scene (and one per Autoload), holding that script's declared signals
# with their parameters and the `##` line above the declaration as the description. Picking one lands
# the event wired - the emitter, the name and the argument signature are all answered.
#
# The scene is the corpus room the suite measures: a Hero node wearing a hand-written player script
# that declares `died` and `health_changed(current)`.
@tool
extends RefCounted

const PREVIEW_NAME: String = "interop-signal-shelf"
const PREVIEW_SIZE: Vector2i = Vector2i(820, 300)

const FIXTURE: String = "res://tests/fixtures/interop_corpus/room.gd"


static func build(host: Window) -> Control:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = FIXTURE
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var tree: Tree = Tree.new()
	tree.hide_root = true
	tree.columns = 2
	tree.custom_minimum_size = Vector2(0.0, 220.0)
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fill(tree, ACEPickerDialog.scene_signal_definitions(sheet, registry))
	var card: Control = EventSheetPopupUI.titled_card("Add event   Room.tscn", tree)
	var margined: MarginContainer = EventSheetPopupUI.margined(card)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined


## The shelf as the picker files it: one folder per emitting object, named with the node and the
## script it wears, with its declared signals under it and each one's own description beside it.
static func _fill(tree: Tree, offered: Array[ACEDefinition]) -> void:
	var root: TreeItem = tree.create_item()
	var folders: Dictionary = {}
	for definition: ACEDefinition in offered:
		var key: String = ACEPickerDialog.scene_lighting_group_key(definition)
		if not folders.has(key):
			var folder: TreeItem = tree.create_item(root)
			folder.set_text(0, key)
			folder.set_selectable(0, false)
			folder.set_custom_color(0, ACEPickerDialog.GROUP_COLOR_NODE_TYPE)
			folders[key] = folder
		var item: TreeItem = tree.create_item(folders[key] as TreeItem)
		item.set_text(0, definition.display_name)
		item.set_text(1, definition.description)
