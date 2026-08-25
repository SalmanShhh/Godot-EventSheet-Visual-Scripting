# Godot EventSheets - the drawing-order words, as the canvas draws them (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The sheet is the hand-written crate the suite measures: nothing in it was written for the plugin,
# and every row here was READ back out of it. Which is the whole claim - `z_index = $Player.z_index +
# 1` is not a number a reader can act on, "Draw in front of Player" is, and the file still saves back
# byte for byte. The visibility layer reads by the project's own name for it where the project named
# one, and by its number where it did not.
@tool
extends RefCounted

const PREVIEW_NAME: String = "rendering-draw-order-rows"
const PREVIEW_SIZE: Vector2i = Vector2i(1440, 420)

const FIXTURE: String = "res://tests/fixtures/rendering_scene_crate.gd"


static func build(host: Window) -> Control:
	# The layer name is the project's, and this repository does not name its render layers - so the
	# picture names one the way a game would, for the length of the shot.
	ProjectSettings.set_setting("layer_names/2d_render/layer_2", "minimap")
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
