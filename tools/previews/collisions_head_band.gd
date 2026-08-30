# Godot EventSheets - who sees whom, said at the top of the sheet (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The point of the picture is that nothing on the head was authored: the collisions band is read back
# out of the `.tscn` the sheet's script is attached to, the layer names are the project's own, and
# the last third of the sentence is the Area's monitoring switch - three facts the person writing the
# row underneath has no other way of seeing.
#
# The fixture scenes are the ones the suite pins, so the picture and the test are about the same
# files; nothing is written anywhere.
@tool
extends RefCounted

const PREVIEW_NAME: String = "collisions-head-band"
const PREVIEW_SIZE: Vector2i = Vector2i(1500, 460)

## The gate: an Area watching one layer while the enemies of the fixture project sit on another.
const FIXTURE: String = "res://tests/fixtures/collision_scene_gate.gd"

## The layer names the picture is taken under, written for the length of the run and put back after.
const LAYER_SETTINGS: Array = [
	["layer_names/2d_physics/layer_1", "World"],
	["layer_names/2d_physics/layer_2", "Doors"],
	["layer_names/2d_physics/layer_3", "Enemies"],
]


static func build(host: Window) -> Control:
	for entry: Array in LAYER_SETTINGS:
		ProjectSettings.set_setting(str(entry[0]), str(entry[1]))
	EventSheetSceneCollisionFacts.clear_cache()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE)
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	host.add_child(viewport)
	return viewport
