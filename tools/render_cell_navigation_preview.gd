# EventForge - render harness (dev tool) for keyboard cell navigation: selects an event
# and Right-steps the cell focus onto its second action, screenshotting the focused-cell
# highlight. Run NON-headless:
#   godot --path . --script tools/render_cell_navigation_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _editor: EventSheetEditor = null


func _init() -> void:
	root.title = "Cell Navigation"
	root.size = Vector2i(1000, 420)
	root.gui_embed_subwindows = true
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		var sheet: EventSheetResource = EventSheetResource.new()
		var event_row: EventRow = EventRow.new()
		event_row.trigger_provider_id = "Core"
		event_row.trigger_id = "OnReady"
		for message: String in ["\"play music\"", "\"spawn player\"", "\"show HUD\""]:
			var action: ACEAction = ACEAction.new()
			action.provider_id = "Core"
			action.ace_id = "Print"
			action.codegen_template = "print({message})"
			action.params = {"message": message}
			event_row.actions.append(action)
		sheet.events.append(event_row)
		_editor = EventSheetEditor.new()
		root.add_child(_editor)
		_editor.setup(sheet)
		var viewport: EventSheetViewport = _editor.get_viewport_control()
		viewport.select_resource(event_row)
		viewport.step_cell_focus(1)
		viewport.step_cell_focus(1)
		viewport.step_cell_focus(1)
		_editor._set_status("Cell focus: Left/Right walk the cells, Enter edits, Esc returns to the row.")
		return
	if _frames < 12 or _editor == null:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/cell-navigation.png")
	print("[preview] cell navigation %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
