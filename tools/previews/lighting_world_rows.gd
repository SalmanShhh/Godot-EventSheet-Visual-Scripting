# Godot EventSheets - L4/L6: darkness as a percentage, and the World object (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The sheet is a crypt somebody set the mood of by hand: a CanvasModulate darkened and eased darker,
# and the world's fog, ambient and glow written straight through the WorldEnvironment. Every row
# here was READ back out of that file and re-emits it byte for byte.
#
# Three things the picture is for. The rows say `Level ▸ Set darkness to 70%` while the file still
# holds `Color(0.3, 0.3, 0.36)` - the percentage is the reading, the colour is the row. The object
# column names the node rather than the class it is. And the `environment` band says which `.tres`
# the scene loads and how many OTHER scenes load the same one, which is the quiet version of the
# warning that a run-time write to it follows the player out of the room.
@tool
extends RefCounted

const PREVIEW_NAME: String = "lighting-world-rows"
const PREVIEW_SIZE: Vector2i = Vector2i(1440, 560)

const FIXTURE: String = "res://tests/fixtures/lighting_scene_crypt.gd"


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
