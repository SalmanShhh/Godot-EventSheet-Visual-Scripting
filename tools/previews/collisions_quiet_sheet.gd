# Godot EventSheets - the quiet sheet law, photographed twice (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# Two sheets, side by side, with the SAME rows in both: the same trigger, the same question, the same
# action. The only difference is in the scenes behind them - one node's mask covers the layer the
# enemies sit on and the other's does not.
#
# The left one is the whole of what the sheet says about a finding: a quiet amber stripe down the row
# and nothing else. No note row, no icon, no inline sentence. The right one is what a sheet with
# nothing wrong looks like, which is what it always looked like. The words that belong to the amber
# row are read in the Doctor's inbox and in the help strip under the row once it is selected.
@tool
extends RefCounted

const PREVIEW_NAME: String = "collisions-quiet-sheet"
const PREVIEW_SIZE: Vector2i = Vector2i(1500, 560)

const TROUBLED: String = "res://tests/fixtures/collision_scene_gate.gd"
const CLEAN: String = "res://tests/fixtures/collision_scene_door.gd"

const LAYER_SETTINGS: Array = [
	["layer_names/2d_physics/layer_1", "World"],
	["layer_names/2d_physics/layer_2", "Doors"],
	["layer_names/2d_physics/layer_3", "Enemies"],
]


static func build(host: Window) -> Control:
	for entry: Array in LAYER_SETTINGS:
		ProjectSettings.set_setting(str(entry[0]), str(entry[1]))
	EventSheetSceneCollisionFacts.clear_cache()
	# Stacked rather than side by side: a sheet is a wide thing, and two of them in one row would
	# wrap every cell - which would make the picture about the wrapping instead of about the stripe.
	var pair: VBoxContainer = VBoxContainer.new()
	pair.add_theme_constant_override("separation", 16)
	pair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pair.add_child(_sheet_card("The scene cannot reach this trigger", TROUBLED))
	pair.add_child(_sheet_card("The same rows, over a scene that can", CLEAN))
	host.add_child(pair)
	return pair


## One sheet under a title, opened read-only the way the head's own previews open theirs.
static func _sheet_card(title: String, script_path: String) -> Control:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(script_path)
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	# A fixed height each, inside a plain Control rather than straight into the card: the canvas asks
	# a container for as much room as it can get, and the first one asking would take all of it and
	# leave the second unpainted. A plain Control does not pass its child's appetite upwards.
	var window: Control = Control.new()
	window.custom_minimum_size = Vector2(0.0, 190.0)
	window.clip_contents = true
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(viewport)
	var card: PanelContainer = EventSheetPopupUI.titled_card(title, window)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return card
