# Godot EventSheets - a class held by its MEMBERS, read as the structure it is.
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
#
#   ABOVE, a hand-written class carrying a multi-line enum, a signal, a field, a class nested inside
#     it and a method. Every one of those made the two older class readings refuse outright, so until
#     now the whole thing was a wall of GDScript. Here it is a fold, and each member reads as the row
#     it would be at TOP LEVEL - the five-line enum collapsing to one row is the clearest of them.
#   BELOW, the same class with one bare statement in its body. Nothing here can say what that line
#     means as a row, so the reading refuses the whole class and it stays honest, visible code. That
#     half of the picture is the point as much as the first one is.
#
# Not one byte moves either way: the reading is a pure view over the RawCodeRow the importer made,
# and the file re-emits exactly as it was written.
@tool
extends RefCounted

const PREVIEW_NAME: String = "member-held-class-rows"
const PREVIEW_SIZE: Vector2i = Vector2i(1080, 820)

## Its own staging names, written fresh each build: a fixed path shared with another harness can
## silently import the PREVIOUS run's file, and every symptom of that points at the reader instead.
const READ_PATH: String = "user://preview_member_held_class_read.gd"
const CODE_PATH: String = "user://preview_member_held_class_code.gd"

const READ_SOURCE: String = """extends Node

class Radio:
	enum Band {
		AM,
		FM = 4,
	}
	signal tuned(to: float)
	var band: int = 0
	class Preset:
		var label: String = ""
		var frequency: float = 88.5
	func tune(to: float) -> void:
		band = int(to)


var radio: Radio = Radio.new()
"""

const CODE_SOURCE: String = """extends Node

class Radio:
	signal tuned(to: float)
	var band: int = 0
	band = 1


var radio: Radio = Radio.new()
"""


static func build(host: Window) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.add_child(EventSheetPopupUI.titled_card(
		"A class held by its members: the enum, the signal, the nested class and the method as rows",
		_sheet_view(_sheet(READ_PATH, READ_SOURCE), 470.0)))
	column.add_child(EventSheetPopupUI.titled_card(
		"One line nothing can name as a row, and the whole class stays honest code",
		_sheet_view(_sheet(CODE_PATH, CODE_SOURCE), 230.0)))
	var margined: MarginContainer = EventSheetPopupUI.margined(column)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined


static func _sheet(path: String, source: String) -> EventSheetResource:
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(source)
	handle.close()
	return GDScriptImporter.new().import_external(path)


## One sheet as a read-only canvas of a fixed height - a canvas asks its container for every pixel it
## can get, and two of them in a column would leave the second with none.
static func _sheet_view(sheet: EventSheetResource, height: float) -> Control:
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	sheet.read_only = true
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	viewport.expand_all()
	var frame: Control = Control.new()
	frame.custom_minimum_size = Vector2(0.0, height)
	frame.clip_contents = true
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(viewport)
	return frame
