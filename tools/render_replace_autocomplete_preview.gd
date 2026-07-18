# EventForge - render harness (dev tool) for the Replace Object References autocomplete:
# opens the dialog on a sheet whose rows use several node references and pops the To
# field's suggestion menu. Run NON-headless:
#   godot --path . --script tools/render_replace_autocomplete_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _editor: EventSheetEditor = null


func _set_prop(target: String, value: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetProperty"
	action.codegen_template = "{target}.{property} = {value}"
	action.params = {"target": target, "property": "visible", "value": value}
	return action


func _init() -> void:
	root.title = "Replace Autocomplete"
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
		var event_row: EventRow = EventRow.new()
		event_row.trigger_provider_id = "Core"
		event_row.trigger_id = "OnReady"
		event_row.actions.append(_set_prop("$Enemy", "true"))
		event_row.actions.append(_set_prop("%HealthBar", "false"))
		event_row.actions.append(_set_prop("$\"UI/Score Label\"", "true"))
		sheet.events.append(event_row)
		_editor = EventSheetEditor.new()
		root.add_child(_editor)
		_editor.setup(sheet)
		_editor.get_viewport_control().select_resource(event_row)
		_editor._open_replace_object_dialog()
		return
	if _frames == 6:
		for menu_button: Node in _editor._replace_object_dialog.find_children("", "MenuButton", true, false):
			var popup: PopupMenu = (menu_button as MenuButton).get_popup()
			popup.about_to_popup.emit()
			popup.position = Vector2i((menu_button as MenuButton).get_screen_position() + Vector2(-160.0, 30.0))
			popup.reset_size()
			popup.popup()
		return
	if _frames < 14 or _editor == null:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/replace-autocomplete.png")
	print("[preview] replace autocomplete %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
