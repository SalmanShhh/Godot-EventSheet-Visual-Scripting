# Godot EventSheets - an effect event, as the canvas draws it (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The sheet is the hand-written boss the suite measures: not one byte of it was written for the
# plugin, and every row here was READ back out of it. The node is in the object column, the dial's
# name is in the sentence behind the muted `effect.` lead that says what the name belongs to, and one
# row - the one naming a dial the shader does not declare - is still the free-string row it has
# always been, which is the contrast the picture is for.
@tool
extends RefCounted

const PREVIEW_NAME: String = "effect-rows"
const PREVIEW_SIZE: Vector2i = Vector2i(1440, 420)

const FIXTURE: String = "res://tests/fixtures/effect_scene_boss.gd"


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
