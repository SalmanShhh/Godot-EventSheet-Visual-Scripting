# EventForge - render harness (dev tool) for the async hourglass chip: renders an event
# whose action chain suspends (Wait between two Prints), so the ⏳ marker on the awaiting
# action can be eyeballed against unmarked neighbours. Run NON-headless:
#   godot --path . --script tools/render_async_chip_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	root.title = "Async Chip"
	root.size = Vector2i(1000, 300)
	var modern_base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(984, 284)
	root.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var modern_style := EventSheetEditorStyle.new()
	modern_style.ensure_defaults()
	EventSheetGodotTheme.apply(modern_style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = modern_style

	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	var before: ACEAction = ACEAction.new()
	before.provider_id = "Core"
	before.ace_id = "Print"
	before.codegen_template = "print({value})"
	before.params = {"value": "\"charging...\""}
	row.actions.append(before)
	var wait: ACEAction = ACEAction.new()
	wait.provider_id = "Core"
	wait.ace_id = "Wait"
	wait.params = {"seconds": "2.0"}
	row.actions.append(wait)
	var after: ACEAction = ACEAction.new()
	after.provider_id = "Core"
	after.ace_id = "Print"
	after.codegen_template = "print({value})"
	after.params = {"value": "\"fire!\""}
	row.actions.append(after)
	sheet.events.append(row)
	_viewport.set_sheet(sheet)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/async-chip.png")
	print("[preview] async chip %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
