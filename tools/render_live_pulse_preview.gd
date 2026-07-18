# EventForge - render harness (dev tool) for the live execution pulse: three events frozen
# at different pulse intensities (just fired / mid-fade / almost gone), so the fading cyan
# stripe + wash can be eyeballed as the gradient a debug run paints. Run NON-headless:
#   godot --path . --script tools/render_live_pulse_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _make_event(uid: String, trigger: String, text: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.event_uid = uid
	row.trigger_provider_id = "Core"
	row.trigger_id = trigger
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.codegen_template = "print({value})"
	action.params = {"value": "\"%s\"" % text}
	row.actions.append(action)
	return row


func _init() -> void:
	root.title = "Live Pulse"
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
	sheet.events.append(_make_event("aa", "OnProcess", "firing right now"))
	sheet.events.append(_make_event("bb", "OnReady", "fired a moment ago"))
	sheet.events.append(_make_event("cc", "OnBodyEntered", "almost faded"))
	_viewport.set_sheet(sheet)
	# Freeze a mid-fade moment: full glow, half, almost gone. set_process(false) holds it.
	_viewport.set_fired_events(PackedStringArray(["aa", "bb", "cc"]))
	_viewport._fired_uids.clear()
	_viewport._fired_intensity["aa"] = 1.0
	_viewport._fired_intensity["bb"] = 0.5
	_viewport._fired_intensity["cc"] = 0.15
	_viewport._apply_firing_to_rows()
	_viewport.set_process(false)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/live-pulse.png")
	print("[preview] live pulse %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
