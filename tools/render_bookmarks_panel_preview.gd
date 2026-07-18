# EventForge - render harness (dev tool) for the C3-style Bookmarks panel: builds a sheet
# with a few bookmarked events, opens the panel, and screenshots it. Run NON-headless:
#   godot --path . --script tools/render_bookmarks_panel_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _editor: EventSheetEditor = null


func _make_event(trigger_id: String, message: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = trigger_id
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.codegen_template = "print({message})"
	action.params = {"message": message}
	row.actions.append(action)
	return row


func _init() -> void:
	root.title = "Bookmarks Panel"
	root.size = Vector2i(760, 560)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		var sheet: EventSheetResource = EventSheetResource.new()
		sheet.events.append(_make_event("OnReady", "\"game started\""))
		sheet.events.append(_make_event("OnProcess", "\"score ticks\""))
		sheet.events.append(_make_event("OnTimeout", "\"wave spawns\""))
		sheet.events.append(_make_event("OnBodyEntered", "\"hit taken\""))
		_editor = EventSheetEditor.new()
		root.add_child(_editor)
		_editor.setup(sheet)
		var viewport: EventSheetViewport = _editor.get_viewport_control()
		for index in [0, 2, 3]:
			viewport._select_row(index, -1)
			viewport.toggle_bookmark_selected()
		_editor._open_bookmarks_panel()
		return
	if _frames == 6:
		_editor._refresh_bookmarks_list()
		return
	if _frames < 16 or _editor == null:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/bookmarks-panel.png")
	print("[preview] bookmarks panel %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
