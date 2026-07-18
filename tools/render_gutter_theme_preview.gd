# EventForge - render harness (dev tool) for the themeable gutter: retints the gutter
# background + number text through the style tokens (what the Theme Editor now edits) and
# screenshots the sheet, proving the gutter follows the theme. Run NON-headless:
#   godot --path . --script tools/render_gutter_theme_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _editor: EventSheetEditor = null


func _init() -> void:
	root.title = "Themed Gutter"
	root.size = Vector2i(1000, 420)
	root.gui_embed_subwindows = true
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		var sheet: EventSheetResource = EventSheetResource.new()
		for trigger_id: String in ["OnReady", "OnProcess", "OnTimeout"]:
			var event_row: EventRow = EventRow.new()
			event_row.trigger_provider_id = "Core"
			event_row.trigger_id = trigger_id
			sheet.events.append(event_row)
		_editor = EventSheetEditor.new()
		root.add_child(_editor)
		_editor.setup(sheet)
		var viewport: EventSheetViewport = _editor.get_viewport_control()
		var style: EventSheetEditorStyle = viewport.get_editor_style()
		style.event_style.gutter_background_color = Color("#232a3c")
		style.event_style.gutter_text_color = Color("#e0b070")
		viewport.queue_redraw()
		_editor._set_status("Gutter tokens retinted via the theme (Theme Editor > gutter_background_color / gutter_text_color).")
		return
	if _frames < 12 or _editor == null:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/themed-gutter.png")
	print("[preview] themed gutter %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
