# EventForge - render harness (dev tool) for the versioned Addon Pack banner chip: opens
# the identity banner over a published pack sheet so the "Addon Pack v1.0.0" chip can be
# eyeballed. Run NON-headless:
#   godot --path . --script tools/render_version_chip_preview.gd
@tool
extends SceneTree

var _frames: int = 0


func _init() -> void:
	root.size = Vector2i(900, 120)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#252525").darkened(0.2)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	# The banner reads its palette off a viewport; an invisible one supplies the style
	# accessors without painting its empty-state overlay over the shot (the known trap).
	var style_viewport: EventSheetViewport = EventSheetViewport.new()
	style_viewport.visible = false
	root.add_child(style_viewport)
	var banner: SheetIdentityBanner = SheetIdentityBanner.new()
	banner.setup(style_viewport)
	banner.position = Vector2(10, 30)
	banner.size = Vector2(880, 60)
	var pack_sheet: EventSheetResource = EventSheetResource.new()
	pack_sheet.behavior_mode = true
	pack_sheet.host_class = "Node"
	pack_sheet.custom_class_name = "StatForge"
	pack_sheet.class_description = "Real, modifiable stats for any node."
	pack_sheet.addon_version = "1.0.0"
	root.add_child(banner)
	banner.update_from_sheet(pack_sheet, "res://eventsheet_addons/stat_forge/stat_forge_behavior.gd")
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 6:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/pack-version-chip.png")
	print("[preview] version chip %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
