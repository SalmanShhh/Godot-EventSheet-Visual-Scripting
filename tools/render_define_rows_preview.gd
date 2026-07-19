# EventForge - render harness (dev tool) for the Define function rows: opens the abilities pack as a
# sheet and screenshots its published-verb rows, so the C3-style reading (verb + typed param chips +
# "gives back" return, NO raw func signature) can be eyeballed. Run NON-headless:
#   godot --path . --script tools/render_define_rows_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	root.title = "Define Rows"
	root.size = Vector2i(1100, 360)
	var modern_base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(1084, 344)
	root.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)

	var sheet: EventSheetResource = GDScriptImporter.new().import_external("res://eventsheet_addons/abilities/abilities_behavior.gd")
	var modern_style := EventSheetEditorStyle.new()
	modern_style.ensure_defaults()
	EventSheetGodotTheme.apply(modern_style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = modern_style
	_viewport.set_sheet(sheet)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/define-rows.png")
	print("[preview] define rows %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
