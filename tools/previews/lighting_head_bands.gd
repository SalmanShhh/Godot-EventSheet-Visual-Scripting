# Godot EventSheets - L4: what the attached scene says about a sheet's lighting (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The sheet is the hand-written lit room the suite measures. Nothing on the head was authored: the
# `lit by` band is one light of `lighting_scene_room.tscn` each, and the `shadows` band counts the
# occluders whose mask can actually block them - the fact that decides whether the shadows a reader
# turned on will ever appear.
@tool
extends RefCounted

const PREVIEW_NAME: String = "lighting-head-bands"
const PREVIEW_SIZE: Vector2i = Vector2i(1440, 460)

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
