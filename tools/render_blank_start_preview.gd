# EventForge - render harness (dev tool) for the dock's STARTING sheet: it is now genuinely empty,
# so the getting-started empty state (heading + clickable CTAs + tip) is what a new user meets -
# instead of a fabricated health/score example they had to delete first. Run NON-headless:
#   godot --path . --script tools/render_blank_start_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	root.title = "Blank Start"
	root.size = Vector2i(1000, 460)
	var modern_base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	# The viewport must sit in a ScrollContainer, as it does in the real dock: its canvas width comes
	# from the scroll parent, and with no parent that lookup falls back to the viewport's OWN size -
	# which it then writes back, so the canvas runs away and the centered empty state lands off-frame.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(984, 444)
	root.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)

	# Exactly what the dock hands back on open now: EventSheetResource.new(), nothing seeded.
	var sheet: EventSheetResource = EventSheetResource.new()
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
	img.save_png("res://docs/images/blank-start.png")
	print("[preview] blank start %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
