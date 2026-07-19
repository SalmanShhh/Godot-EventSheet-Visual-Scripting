# EventForge - render harness (dev tool) for the first-class Preload Resource row: a static
# (const preload) and a dynamic (var load) block rendered variable-style (name = path + mode
# pill) next to a real variable row for comparison. Run NON-headless:
#   godot --path . --script tools/render_preload_row_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	root.title = "Preload Row"
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

	sheet.variables = {"max_health": {"type": "int", "default": 100, "exported": true}}
	sheet.events.append(_reference("BossTheme", "res://music/boss.ogg", "preload"))
	sheet.events.append(_reference("arena_scene", "res://levels/arena.tscn", "load"))
	_viewport.set_sheet(sheet)
	process_frame.connect(_on_frame)


func _reference(reference_name: String, path: String, mode: String) -> CustomBlockRow:
	var block: CustomBlockRow = CustomBlockRow.new()
	block.kind_id = "preload"
	block.fields = {"name": reference_name, "path": path, "mode": mode}
	return block


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/preload-row.png")
	print("[preview] preload row %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
