# Godot EventSheets - a property that names its accessors, before and after (preview module).
#
# Rendered by tools/render_previews.gd. The same hand-written declaration twice:
#
#   ABOVE, the reading as it stood. `set = _set_health,` and `get = _get_health` are not statements,
#     so nothing could lift them - and because they sit UNDER the `var` line, the declaration went
#     into the code block with them. Three lines of a variable, shown as code.
#   BELOW, the same three lines today: the variable is a row, and under it one sub-row per accessor
#     saying which function runs and when. The functions themselves are not copied here; they read as
#     the functions they are, further down the sheet, where they were written.
#
# The file is untouched either way - this is a reading, and the bytes are gated elsewhere.
@tool
extends RefCounted

const PREVIEW_NAME: String = "named-property-rows"
const PREVIEW_SIZE: Vector2i = Vector2i(1180, 800)

## Its own staging name, and written fresh each build: a fixed path shared with another harness can
## silently import the PREVIOUS run's file, and every symptom of that points at the reader instead.
const SOURCE_PATH: String = "user://preview_named_property_rows.gd"

const SOURCE: String = """extends Node

signal health_changed(amount: int)

var health: int = 100:
	set = _set_health,
	get = _get_health


func _set_health(value: int) -> void:
	health = clampi(value, 0, 100)
	health_changed.emit(health)


func _get_health() -> int:
	return health
"""

## The three lines as the block held them - the declaration dragged in by the two lines under it.
const BEFORE_BLOCK: String = "var health: int = 100:\n\tset = _set_health,\n\tget = _get_health"


static func build(host: Window) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.add_child(EventSheetPopupUI.titled_card(
		"Before: two lines that are not statements, taking the declaration down with them",
		_sheet_view(_before_sheet(), 170.0)))
	column.add_child(EventSheetPopupUI.titled_card(
		"After: the variable is a row, and each accessor says which function runs and when",
		_sheet_view(_after_sheet(), 420.0)))
	var margined: MarginContainer = EventSheetPopupUI.margined(column)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined


static func _after_sheet() -> EventSheetResource:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	return GDScriptImporter.new().import_external(SOURCE_PATH)


## The declaration as the code block held it. Built rather than imported, because the importer no
## longer hands this back - and building it is the only honest way to photograph a reading that has
## been replaced.
static func _before_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var block: RawCodeRow = RawCodeRow.new()
	block.code = BEFORE_BLOCK
	sheet.events.append(block)
	return sheet


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
	# The head's folders open FOLDED, which is right in the editor and wrong in a picture whose whole
	# subject is what hangs under the variable row.
	viewport.expand_all()
	var frame: Control = Control.new()
	frame.custom_minimum_size = Vector2(0.0, height)
	frame.clip_contents = true
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(viewport)
	return frame
