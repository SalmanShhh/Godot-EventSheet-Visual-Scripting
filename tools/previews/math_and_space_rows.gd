# Godot EventSheets - the maths and the moves, opened from somebody's own file (preview module).
#
# Rendered by tools/render_previews.gd. Nothing here was authored in the editor: the fixture is a
# hand-written `_process` full of `clampf`, `lerp`, `wrapf`, a `transform.x` move, a world-space move
# and a `rotate_toward`, and every line of it opens as the row that says what it does - with the call
# itself in the echo at the right edge, which is the whole claim of this family.
#
# The head above the rows is the same file's scene, read: the arm this script is on sits inside a
# body scaled twice, so its own 10 is the world's 20, and the two shapes elsewhere in the scene that
# a scale is about to surprise say so before the game runs.
@tool
extends RefCounted

const PREVIEW_NAME: String = "math-and-space-rows"
const PREVIEW_SIZE: Vector2i = Vector2i(1440, 520)

const FIXTURE: String = "res://tests/fixtures/space_scene_arena.gd"


static func build(host: Window) -> Control:
	EventSheetSceneLightingFacts.clear_cache()
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
