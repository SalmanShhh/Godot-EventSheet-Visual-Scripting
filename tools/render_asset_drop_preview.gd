# EventForge - render harness (dev tool) for canvas asset drops: builds the rows the drop
# handlers produce for each supported file type (scene spawn, sound play, image texture,
# JSON load, resource preload) THROUGH the EventSheets asset-drop seam, so the resulting
# sentences can be eyeballed. Run NON-headless:
#   godot --path . --script tools/render_asset_drop_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	root.title = "Asset Drop"
	root.size = Vector2i(1000, 360)
	var modern_base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(984, 344)
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

	# The exact rows the drop seam builds: a resource preloads (top-level declaration),
	# everything else joins one On Ready event as actions.
	sheet.events.append(_built("res://data/loot_table.tres"))
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	row.actions.append(_built("res://scenes/enemy.tscn"))
	row.actions.append(_built("res://sfx/explosion.ogg"))
	row.actions.append(_built("res://art/hero.png"))
	row.actions.append(_built("res://data/waves.json"))
	sheet.events.append(row)
	_viewport.set_sheet(sheet)
	process_frame.connect(_on_frame)


func _built(asset_path: String) -> Resource:
	return EventSheets.asset_drop_builder_for(asset_path.get_extension()).call(asset_path, null)


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/asset-drop.png")
	print("[preview] asset drop %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
