# Godot EventSheets - a lit event, as the canvas draws it (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The sheet is the hand-written lit room the suite measures: not one byte of it was written for the
# plugin, and every row here was READ back out of it. The light is in the object column, the word is
# in the sentence, and the property that light really has is in the echo at the right edge.
@tool
extends RefCounted

const PREVIEW_NAME: String = "lighting-rows"
const PREVIEW_SIZE: Vector2i = Vector2i(1440, 400)

const FIXTURE: String = "res://tests/fixtures/lighting_scene_room.gd"


static func build(host: Window) -> Control:
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
