# Godot EventSheets - what a node WEARS, and who else wears it (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The sheet is the hand-written goblin the suite measures. Nothing on the head was authored: the
# `effect` band is one wearing node of `effect_scene_goblin.tscn` each, naming the material file, the
# shader at the end of the chain, and how many OTHER nodes of the project wear the same file - the
# count that turns one dial row into a whole tribe dissolving at once.
@tool
extends RefCounted

const PREVIEW_NAME: String = "effect-head-bands"
const PREVIEW_SIZE: Vector2i = Vector2i(1440, 420)

const FIXTURE: String = "res://tests/fixtures/effect_scene_goblin.gd"


static func build(host: Window) -> Control:
	# The count is a question about every scene in the project, and the editor answers it a slice per
	# frame. A picture has no frames to wait through, so the scan is finished here - which is also
	# what the Doctor does, and gets the same answer.
	EventSheetProjectShareIndex.clear_cache()
	EventSheetProjectShareIndex.build_now()
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
