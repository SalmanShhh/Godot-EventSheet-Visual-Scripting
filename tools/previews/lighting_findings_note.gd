# Godot EventSheets - a lighting finding said under the row it is about (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The sheet is the hand-written crypt the suite measures, and nothing in the picture was authored for
# it: the rows were read out of the file, and the note under them was read out of the scene. The
# crypt's WorldEnvironment points at an environment `.tres` the swamp also loads, so every fog row
# below writes the mood of both rooms - which is what the note says, under the event that does it.
@tool
extends RefCounted

const PREVIEW_NAME: String = "lighting-findings-note"
const PREVIEW_SIZE: Vector2i = Vector2i(2200, 620)

const FIXTURE: String = "res://tests/fixtures/lighting_scene_crypt.gd"


static func build(host: Window) -> Control:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE)
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	host.add_child(viewport)
	return viewport
