# Godot EventSheets - the profiled run's numbers in the gutter (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The run is fed in through the REAL stream reader - the same windows of fires and stamps the running
# game sends - so what the picture shows is what the overlay does, not a mock of it.
@tool
extends RefCounted

const PREVIEW_NAME: String = "performance-gutter"
const PREVIEW_SIZE: Vector2i = Vector2i(1500, 300)


static func build(host: Window) -> Control:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	# Three rows and three answers: one that costs real milliseconds, one that is cheap, and one that
	# never ran at all - the three states a reader scans a margin for. Real vocabulary throughout, so
	# the rows read the way rows read.
	var dear: EventRow = _row("OnProcess", "SetLabelText", {"value": "score"})
	var cheap: EventRow = _row("OnReady", "SetLabelText", {"value": "\"Ready\""})
	var never: EventRow = _row("OnBodyEntered", "QueueFree", {})
	sheet.events.append(dear)
	sheet.events.append(cheap)
	sheet.events.append(never)

	EventSheetRunProfile.forget()
	_stream(dear.event_uid, 340, 2400)
	_stream(cheap.event_uid, 42, 120)
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.show_costs = true
	viewport.set_sheet(sheet)
	host.add_child(viewport)
	return viewport


## One event's fires and their stamps, handed to the trace exactly as the running game hands them
## over: a tally of fires, a microsecond reading beside each, and the frame ruler.
static func _stream(uid: String, fires: int, usec_each: int) -> void:
	var uids: PackedStringArray = PackedStringArray()
	var stamps: PackedInt64Array = PackedInt64Array()
	var markers: PackedInt32Array = PackedInt32Array()
	for index: int in range(fires):
		uids.append(uid)
		stamps.append(index * usec_each)
		markers.append(index)
	EventSheetTraceHitCounts.note_fired(uids)
	EventSheetTraceTimings.note_window(uids, stamps, markers, fires * usec_each)


static func _row(trigger_id: String, ace_id: String, params: Dictionary) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_id = trigger_id
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor != null:
		action.codegen_template = descriptor.codegen_template
	row.actions.append(action)
	return row
