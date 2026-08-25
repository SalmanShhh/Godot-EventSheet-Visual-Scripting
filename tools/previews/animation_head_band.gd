# Godot EventSheets - what this sheet can PLAY, read from the scene (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The sheet is the hand-written hero the suite measures, opened as it stands. Nothing on the head was
# authored: the `animations` band is one animation node of `animation_scene_hero.tscn` each, naming
# the clips THESE rows play with their lengths or their loop word, then counting the rest - the shape
# that keeps a character with a hundred and thirty-one clips down to one line.
@tool
extends RefCounted

const PREVIEW_NAME: String = "animation-head-band"
const PREVIEW_SIZE: Vector2i = Vector2i(1440, 380)

const FIXTURE: String = "res://tests/fixtures/animation_scene_hero.gd"


static func build(host: Window) -> Control:
	EventSheetSceneAnimations.clear_cache()
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
