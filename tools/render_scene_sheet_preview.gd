# EventForge - render harness (dev tool) for the two wiring readings: a scene opened as one sheet,
# and the rows a signal wired to another object's function reads as. Run NON-headless:
#   godot --path . --script tools/render_scene_sheet_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _stage: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	root.title = "Scene as a sheet"
	root.size = Vector2i(1100, 520)
	var modern_base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(1084, 504)
	root.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)
	_apply_sheet(EventSheetSceneSheet.build("res://tests/fixtures/opened_scene_level.tscn"))
	process_frame.connect(_on_frame)


func _apply_sheet(sheet: EventSheetResource) -> void:
	var modern_base := Color("#252525")
	var modern_style := EventSheetEditorStyle.new()
	modern_style.ensure_defaults()
	EventSheetGodotTheme.apply(modern_style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = modern_style
	_viewport.set_sheet(sheet)
	_viewport.set_reading_mode(true)


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var img: Image = root.get_texture().get_image()
	if _stage == 0:
		img.save_png("res://docs/images/scene-as-a-sheet.png")
		print("[preview] scene sheet %dx%d" % [img.get_width(), img.get_height()])
		_stage = 1
		_frames = 0
		var one: EventSheetResource = GDScriptImporter.new().import_external("res://tests/fixtures/opened_scene_level.gd")
		one.read_only = true
		_apply_sheet(one)
		return
	img.save_png("res://docs/images/wired-call-rows.png")
	print("[preview] wired call rows %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
