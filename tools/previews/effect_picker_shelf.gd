# Godot EventSheets - the picker's shelves for the shader materials of one scene (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The shelves are the whole of the claim: a reader arrives asking "which of MY effects", so the
# answer is one sub-folder per node of the attached scene that wears a shader material, named with
# the shader it runs, holding one entry per dial that shader declares - with the node and the dial
# already answered. Beside each entry is the line it will write, which is where a reader sees that
# the name in the row is the name in the file.
#
# The sheet is the boss fixture the suite already measures, which wears one saved material and one
# the scene keeps inside itself, so the picture and the test are about the same two nodes.
@tool
extends RefCounted

const PREVIEW_NAME: String = "effect-picker-shelf"
const PREVIEW_SIZE: Vector2i = Vector2i(880, 720)

const FIXTURE: String = "res://tests/fixtures/effect_scene_boss.gd"


static func build(host: Window) -> Control:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = FIXTURE
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var tree: Tree = Tree.new()
	tree.hide_root = true
	tree.custom_minimum_size = Vector2(0.0, 640.0)
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fill(tree, ACEPickerDialog.effect_dial_definitions(sheet, registry))
	var card: Control = EventSheetPopupUI.titled_card("Add action   Boss.tscn", tree)
	var margined: MarginContainer = EventSheetPopupUI.margined(card)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined


## The shelves as the picker files them: one folder per wearing node, named by the whole group key
## the picker computes, with the dials under it in the order the shader declares them.
static func _fill(tree: Tree, offered: Array[ACEDefinition]) -> void:
	var root: TreeItem = tree.create_item()
	var folders: Dictionary = {}
	for definition: ACEDefinition in offered:
		var key: String = ACEPickerDialog.effect_group_key(definition, true)
		if not folders.has(key):
			var folder: TreeItem = tree.create_item(root)
			folder.set_text(0, key)
			folder.set_selectable(0, false)
			folder.set_custom_color(0, ACEPickerDialog.GROUP_COLOR_NODE_TYPE)
			folders[key] = folder
		var item: TreeItem = tree.create_item(folders[key] as TreeItem)
		item.set_text(0, "%s      %s" % [definition.display_name, _echo(definition)])


## The line the row will write, with the node and the dial already in it - the place a reader sees
## that the name the sheet says is the name the shader declares.
static func _echo(definition: ACEDefinition) -> String:
	var target: String = str(definition.metadata.get(ACEPickerDialog.SCENE_TARGET_META, ""))
	var dial: String = str((definition.metadata.get(ACEPickerDialog.SCENE_PREFILL_META, {}) \
		as Dictionary).get(EventForgeEffectDialACEs.DIAL_PARAM, ""))
	return str(definition.metadata.get("codegen_template", "")) \
		.replace("{target.}", "" if target == EventSheetSceneLights.SELF_REFERENCE else "%s." % target) \
		.replace("{target}", target).replace("{%s}" % EventForgeEffectDialACEs.DIAL_PARAM, dial)
