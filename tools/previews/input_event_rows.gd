# Godot EventSheets - the input handler's own questions, before and after (preview module).
#
# Rendered by tools/render_previews.gd. Two sheets, one picture, the SAME four lines of hand-written
# GDScript in both:
#
#   ABOVE, the reading as it stood. Every one of the four questions arrived as Expression Is True -
#     the catch-all, which is true and says nothing. It is built here as rows rather than imported,
#     because the importer no longer produces it; what it is built as is exactly what the importer
#     used to hand back, which is why the sentence in each cell is the raw expression.
#   BELOW, the same file opened today: four curated sentences, each naming the action out of the
#     project's own Input Map, with the handler around them unchanged.
#
# The file itself is untouched either way - this is a reading, and the bytes are gated elsewhere.
@tool
extends RefCounted

const PREVIEW_NAME: String = "input-event-rows"
const PREVIEW_SIZE: Vector2i = Vector2i(1180, 900)

## Its own staging name, and hashed after the write: a fixed path shared with another harness can
## silently import the PREVIOUS run's file, and every symptom of that points at the reader instead.
const SOURCE_PATH: String = "user://preview_input_event_rows.gd"

const SOURCE: String = """extends Node


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		print("jump")
	if event.is_action_pressed(&"ui_down", true):
		print("scroll")
	if event.is_action_released("fire"):
		print("let go")
	if event.is_action("aim"):
		print("aim")
"""

## The four expressions as the catch-all held them - one Expression Is True per question, with the
## step each one ran, so the two panes are the same file line for line.
const BEFORE_QUESTIONS: Array[Array] = [
	["event.is_action_pressed(\"jump\")", "\"jump\""],
	["event.is_action_pressed(&\"ui_down\", true)", "\"scroll\""],
	["event.is_action_released(\"fire\")", "\"let go\""],
	["event.is_action(\"aim\")", "\"aim\""]
]


static func build(host: Window) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.add_child(EventSheetPopupUI.titled_card(
		"Before: four questions, one row - Expression Is True, with a derived reading where the"
		+ " grammar had words and the raw line where it did not",
		_sheet_view(_before_sheet(), 380.0)))
	column.add_child(EventSheetPopupUI.titled_card(
		"After: four curated rows, each naming its action out of the project's own Input Map",
		_sheet_view(_after_sheet(), 380.0)))
	var margined: MarginContainer = EventSheetPopupUI.margined(column)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined


## The file, opened as it opens today.
static func _after_sheet() -> EventSheetResource:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	return GDScriptImporter.new().import_external(SOURCE_PATH)


## The same four questions as the catch-all held them. Built rather than imported, because the
## importer no longer hands this back - and building it is the only honest way to photograph a
## reading that has been replaced.
static func _before_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	for asked: Array in BEFORE_QUESTIONS:
		var event: EventRow = EventRow.new()
		event.trigger_id = "OnUnhandledInput"
		event.trigger_provider_id = "Core"
		var question: ACECondition = ACECondition.new()
		question.provider_id = "Core"
		question.ace_id = "ExpressionIsTrue"
		question.params = {"expr": str(asked[0])}
		event.conditions.append(question)
		var step: ACEAction = ACEAction.new()
		step.provider_id = "Core"
		step.ace_id = "PrintLog"
		step.params = {"message": str(asked[1])}
		event.actions.append(step)
		sheet.events.append(event)
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
	var frame: Control = Control.new()
	frame.custom_minimum_size = Vector2(0.0, height)
	frame.clip_contents = true
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(viewport)
	return frame
