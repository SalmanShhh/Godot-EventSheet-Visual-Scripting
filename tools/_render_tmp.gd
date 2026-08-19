@tool
extends SceneTree

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	root.title = "Effects, tilemaps and the camera"
	root.size = Vector2i(1200, 900)
	var modern_base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(1184, 884)
	root.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)
	var handle: FileAccess = FileAccess.open("user://effects_tilemap_camera_preview.gd", FileAccess.WRITE)
	handle.store_string(EffectsTilemapCameraReadingTest.SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(
		"user://effects_tilemap_camera_preview.gd")
	sheet.read_only = true
	var modern_style := EventSheetEditorStyle.new()
	modern_style.ensure_defaults()
	EventSheetGodotTheme.apply(modern_style, modern_base, modern_base.darkened(0.15),
		modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = modern_style
	_viewport.set_sheet(sheet)
	_viewport.set_reading_mode(true)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 12:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/pattern-effects-tilemap-camera.png")
	print("[preview] %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
