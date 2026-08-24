# Godot EventSheets - L3: the flicker behaviour, opened as the sheet it is (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# Nothing is staged here: this is the shipped pack file opened the way a user opens it, so the
# picture is the pack. The four Inspector knobs are variable rows, the two verbs and the question are
# function rows, and the per-frame code is the event that runs every tick - the whole behaviour on
# one screen, editable, because a pack IS an event sheet.
@tool
extends RefCounted

const PREVIEW_NAME: String = "lighting-flicker-pack"
const PREVIEW_SIZE: Vector2i = Vector2i(1440, 700)

const PACK: String = "res://eventsheet_addons/light_flicker/light_flicker_behavior.gd"


static func build(host: Window) -> Control:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(PACK)
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
	# A preview is photographed, never pointed at, and set LAST because the canvas takes the mouse
	# back while it builds: without this, wherever the machine's cursor happens to rest decides
	# whether a tooltip covers half the picture.
	viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return viewport
