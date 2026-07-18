# EventForge - render harness (dev tool) for the Inspector property drop: renders the Set
# Property action rows the drop gesture creates (target + property + current value baked),
# so the resulting sentence can be eyeballed. Run NON-headless:
#   godot --path . --script tools/render_property_drop_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _make_set_property(target: String, property_name: String, value: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetProperty"
	action.codegen_template = "{target}.{property} = {value}"
	action.params = {"target": target, "property": property_name, "value": value}
	return action


func _init() -> void:
	root.title = "Property Drop"
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
	sheet.host_class = "Node2D"
	var modern_style := EventSheetEditorStyle.new()
	modern_style.ensure_defaults()
	EventSheetGodotTheme.apply(modern_style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = modern_style

	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	row.actions.append(_make_set_property("$Sprite", "visible", "false"))
	row.actions.append(_make_set_property("%HealthBar", "modulate", "Color(1, 0.4, 0.4, 1)"))
	row.actions.append(_make_set_property("self", "position", "Vector2(0, 0)"))
	sheet.events.append(row)
	_viewport.set_sheet(sheet)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/property-drop.png")
	print("[preview] property drop %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
