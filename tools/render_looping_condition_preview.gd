# EventForge - render harness (dev tool) for looping conditions: renders a sheet whose event
# was built the way applying StatForge's "For Each Buff" does (a pick filter over the pack
# call, iterator from @ace_looping), so the loop lane + per-item actions can be eyeballed.
# Run NON-headless:
#   godot --path . --script tools/render_looping_condition_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	root.title = "Looping Condition"
	root.size = Vector2i(1000, 420)
	var modern_base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(984, 404)
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

	# The row "For Each Buff" produces: a per-frame trigger + the looping pick filter.
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	var pick: PickFilter = PickFilter.new()
	pick.collection_kind = PickFilter.CollectionKind.EXPRESSION
	pick.collection_value = "__eventsheet_provider_StatForge.each_buff()"
	pick.iterator_name = "buff_id"
	row.pick_filters.append(pick)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.codegen_template = "print({value})"
	action.params = {"value": "buff_id"}
	row.actions.append(action)
	sheet.events.append(row)
	_viewport.set_sheet(sheet)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/looping-condition.png")
	print("[preview] looping condition %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
