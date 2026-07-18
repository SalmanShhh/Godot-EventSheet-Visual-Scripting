# EventForge - render harness (dev tool) for the live filter lens: a five-event sheet
# with the lens set to "health", so only the matching events remain visible. Run
# NON-headless:
#   godot --path . --script tools/render_filter_lens_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _make_event(trigger: String, value: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = trigger
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.codegen_template = "print({value})"
	action.params = {"value": value}
	row.actions.append(action)
	return row


func _init() -> void:
	root.title = "Filter Lens"
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
	sheet.events.append(_make_event("OnReady", "\"health restored\""))
	sheet.events.append(_make_event("OnProcess", "\"score ticks\""))
	sheet.events.append(_make_event("OnBodyEntered", "\"health damage\""))
	sheet.events.append(_make_event("OnTimeout", "\"spawn wave\""))
	sheet.events.append(_make_event("OnAreaEntered", "\"health pickup\""))
	_viewport.set_sheet(sheet)
	_viewport.set_lens("health")
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/filter-lens.png")
	print("[preview] filter lens %dx%d, hidden=%d" % [img.get_width(), img.get_height(), _viewport.lens_hidden_count()])
	quit(0)
