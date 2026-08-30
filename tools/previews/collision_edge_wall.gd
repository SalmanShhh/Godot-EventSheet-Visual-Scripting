# Godot EventSheets - a touch row on a scene that cannot touch (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
#
# The claim is the whole picture: the entries are still LISTED. A picker that hid what the project
# cannot do yet teaches nothing - the thing to fix is not on screen - so a touch row on a scene made
# of sprites greys instead, its reason says what is missing in the words of what the reader was
# trying to do, and the Add button becomes that fix. The reason and the button are read out of
# EventSheetPickerGates here exactly as the picker reads them, so the picture cannot say one thing
# while the editor says another.
@tool
extends RefCounted

const PREVIEW_NAME: String = "collision-edge-wall"
const PREVIEW_SIZE: Vector2i = Vector2i(900, 460)

## The colour the picker greys a gated entry with, and the amber it says the reason in.
const GATED_COLOR: Color = ACEPickerDialog.GROUP_COLOR_NEUTRAL
const REASON_COLOR: Color = Color("#e0b050")

## A scene of sprites: known, attached, and holding nothing that can touch anything.
const SCENE_CLASSES: Array[String] = ["Node2D", "Sprite2D", "Camera2D"]

## The rows the picture shows, as {id, node_type} - the four edge triggers of the touch family,
## which is what a reader is browsing when they meet this wall.
const ENTRIES: Array[Dictionary] = [
	{"id": "OnFirstOverlap", "node_type": "Area2D"},
	{"id": "OnLastOverlapEnded", "node_type": "Area2D"},
	{"id": "OnLanded", "node_type": "CharacterBody2D"},
	{"id": "OnLeftTheGround", "node_type": "CharacterBody2D"}
]


static func build(host: Window) -> Control:
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var context: Dictionary = {
		"is_behavior_sheet": false, "tool_gate_wired": false, "is_tool_sheet": false,
		"scene_known": true, "has_scene": true, "scene_classes": PackedStringArray(SCENE_CLASSES)
	}
	var tree: Tree = Tree.new()
	tree.hide_root = true
	tree.custom_minimum_size = Vector2(0.0, 300.0)
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var root: TreeItem = tree.create_item()
	var folder: TreeItem = tree.create_item(root)
	folder.set_text(0, "Collisions")
	folder.set_selectable(0, false)
	folder.set_custom_color(0, ACEPickerDialog.GROUP_COLOR_NODE_TYPE)
	var selected_fix: String = ""
	var selected_reason: String = ""
	for entry: Dictionary in ENTRIES:
		var definition: ACEDefinition = registry.find_definition("Core", str(entry["id"]))
		if definition == null:
			continue
		var gate: Dictionary = EventSheetPickerGates.gate_for(definition, context)
		var item: TreeItem = tree.create_item(folder)
		item.set_text(0, "%s      %s" % [definition.display_name,
			EventSheetPickerGates.reason_text(gate) if not gate.is_empty() else ""])
		if gate.is_empty():
			continue
		item.set_custom_color(0, GATED_COLOR)
		if selected_fix.is_empty():
			selected_fix = EventSheetPickerGates.fix_text(gate)
			selected_reason = EventSheetPickerGates.reason_text(gate)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.add_child(tree)
	var reason: RichTextLabel = RichTextLabel.new()
	reason.bbcode_enabled = true
	reason.fit_content = true
	reason.text = "[color=#%s]%s[/color]" % [REASON_COLOR.to_html(false), selected_reason]
	column.add_child(reason)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	var cancel: Button = Button.new()
	cancel.text = EventSheetL10n.translate("Cancel")
	buttons.add_child(cancel)
	# The Add button IS the fix while a gated entry is selected - one press adds the node through the
	# editor's own undo and carries straight on to the row the reader wanted.
	var add: Button = Button.new()
	add.text = selected_fix
	buttons.add_child(add)
	column.add_child(buttons)
	var card: Control = EventSheetPopupUI.titled_card("Add event   Player.tscn", column)
	var margined: MarginContainer = EventSheetPopupUI.margined(card)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined
