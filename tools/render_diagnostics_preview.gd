# EventForge — visual render harness for the "error → row" diagnostics marker (dev tool).
# Builds a sheet with a broken GDScript block, runs EventSheetDiagnostics, applies the markers
# and saves a PNG so the red row marker can be inspected. Run NON-headless:
#   godot --path . --script tools/render_diagnostics_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _viewport: EventSheetViewport = null

func _init() -> void:
	root.title = "EventForge Diagnostics Preview"
	root.size = Vector2i(1160, 420)
	var background: ColorRect = ColorRect.new()
	background.color = Color("#252525")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(1140, 404)
	root.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)

	var sheet: EventSheetResource = EventSheetResource.new()
	var ok_event: EventRow = EventRow.new()
	ok_event.trigger_provider_id = "Core"
	ok_event.trigger_id = "OnReady"
	var ok_block: RawCodeRow = RawCodeRow.new()
	ok_block.code = "var ready := true"
	ok_event.actions.append(ok_block)
	sheet.events.append(ok_event)
	var bad_block: RawCodeRow = RawCodeRow.new()
	bad_block.code = "this is not valid gdscript ((("
	sheet.events.append(bad_block)
	var good_tail: RawCodeRow = RawCodeRow.new()
	good_tail.code = "var tail := 1"
	sheet.events.append(good_tail)
	_viewport.set_sheet(sheet)
	_viewport.set_row_diagnostics(EventSheetDiagnostics.analyze(sheet, null))

	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frames += 1
	if _frames < 4:
		return
	var image: Image = root.get_texture().get_image()
	image.save_png("res://_diagnostics_preview.png")
	print("[diagnostics_preview] saved res://_diagnostics_preview.png (%dx%d)" % [image.get_width(), image.get_height()])
	quit(0)
