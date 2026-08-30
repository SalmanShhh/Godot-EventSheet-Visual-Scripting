# Godot EventSheets - a lighting finding as the quiet amber state (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The sheet is the hand-written crypt the suite measures, and nothing in the picture was authored for
# it: the rows were read out of the file, and the finding behind the amber was read out of the scene.
# The crypt's WorldEnvironment points at an environment `.tres` the swamp also loads, so every fog
# row below writes the mood of both rooms - which is what puts the event that does it into the quiet
# amber state. No note row, no icon, no inline sentence: the words wait in the Doctor's inbox and in
# the help strip under the row once it is selected.
@tool
extends RefCounted

const PREVIEW_NAME: String = "lighting-quiet-sheet"
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
