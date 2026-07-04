# EventForge - visual render harness for the live event-trace highlight (dev tool).
# Builds a sheet of events and marks some as "firing" (as a debug run would), saving a PNG so
# the cyan highlight can be inspected. Run NON-headless:
#   godot --path . --script tools/render_event_trace_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	root.title = "EventForge Event Trace Preview"
	root.size = Vector2i(1160, 360)
	var background: ColorRect = ColorRect.new()
	background.color = Color("#252525")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(1140, 344)
	root.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)

	var sheet: EventSheetResource = EventSheetResource.new()
	for i in range(3):
		var event: EventRow = EventRow.new()
		event.event_uid = "evt_%d" % i
		event.trigger_provider_id = "Core"
		event.trigger_id = "OnProcess"
		var block: RawCodeRow = RawCodeRow.new()
		block.code = "pass # event %d body" % i
		event.actions.append(block)
		sheet.events.append(event)
	_viewport.set_sheet(sheet)
	# As a debug run would: events 0 and 2 fired this frame, event 1 did not.
	_viewport.set_fired_events(PackedStringArray(["evt_0", "evt_2"]))

	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 4:
		return
	var image: Image = root.get_texture().get_image()
	image.save_png("res://_event_trace_preview.png")
	print("[event_trace_preview] saved res://_event_trace_preview.png (%dx%d)" % [image.get_width(), image.get_height()])
	quit(0)
