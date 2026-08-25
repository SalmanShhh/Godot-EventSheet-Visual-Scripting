# Godot EventSheets - a beginner-shaped script opened as a sheet (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The file is one of the corpus scripts the suite measures: untyped function heads, inferred
# variables, a button and a timer wired with connect lambdas. Every one of those used to leave the
# whole file as a wall of code. What the picture is showing is the two lifted lambdas as the trigger
# events they are, the helpers as functions, and "called by …" on the head of the ones something else
# in the project calls.
@tool
extends RefCounted

const PREVIEW_NAME: String = "interop-opened-script"
const PREVIEW_SIZE: Vector2i = Vector2i(1440, 460)

const FIXTURE: String = "res://tests/fixtures/interop_corpus/hud.gd"


static func build(host: Window) -> Control:
	# The caller facts come off the project index, and a band says nothing while it is still
	# counting - so a picture of one has to wait for it, exactly as the editor's own rebuild does.
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
