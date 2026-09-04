# EventForge - render harness (dev tool) for the two doors user content comes in through. Two
# pictures in one run: the drop event on its own, and the ask with the two answers it ends in, each
# as a WHOLE event so the trigger, its chip and the rows under it are in one picture. Run
# NON-headless:
#   godot --path . --script tools/render_user_content_doors_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _editor: EventSheetEditor = null


func _init() -> void:
	root.title = "The Two Doors"
	root.gui_embed_subwindows = true
	# Wide enough for the condition lane to hold a trigger's words AND the payload chip beside them.
	# At the project's own window size the lane gives the chip its room out of the cell, and the
	# words are what is left out - which makes a picture of a row nobody can read.
	DisplayServer.window_set_size(Vector2i(1600, 760))
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_editor = EventSheetEditor.new()
		root.add_child(_editor)
		_editor.setup(_drop_sheet())
		_editor._set_status("The window's own drop, as an event. Desktop only.")
		return
	if _editor == null:
		return
	if _frames == 16:
		_save("user-content-drop")
		_editor.setup(_ask_sheet())
		_editor._set_status("An ask has no return value: the answer is one of two events.")
		return
	if _frames == 30:
		_save("user-content-ask")
		quit(0)


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png("res://docs/images/%s.png" % name)
	print("[preview] %s %dx%d" % [name, image.get_width(), image.get_height()])


## The drop door: one event, the paths riding in as a chip.
func _drop_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "AvatarPicker"
	sheet.host_class = "Node"
	var dropped: EventRow = _event("OnFilesDropped")
	dropped.actions.append(_action("SetVar", {"var_name": "avatar",
		"value": _template("LoadImageFile", {"path": "files[0]", "fallback": ""})}))
	sheet.events.append(dropped)
	return sheet


## The ask door: the question, and the two events it can end in.
func _ask_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "AvatarPicker"
	sheet.host_class = "Node"
	var asking: EventRow = _event("OnButtonPressed")
	asking.trigger_source_path = "ChooseButton"
	asking.actions.append(_action("AskForAFileToOpen",
		{"filters": "PackedStringArray([\"*.png;Images\"])"}))
	sheet.events.append(asking)

	var chosen: EventRow = _event("OnFileChosen")
	chosen.actions.append(_action("SetVar", {"var_name": "avatar",
		"value": _template("LoadImageFile", {"path": "path", "fallback": ""})}))
	sheet.events.append(chosen)

	var cancelled: EventRow = _event("OnAskCancelled")
	cancelled.actions.append(_action("SetProperty", {"target": "$StatusLabel", "property": "text",
		"value": "\"Kept the old picture.\""}))
	sheet.events.append(cancelled)
	return sheet


func _event(trigger_id: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = trigger_id
	return row


func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	action.codegen_template = _descriptor_template(ace_id)
	return action


## One verb's shipped template with these values baked in - what the row would hold after the picker.
func _template(ace_id: String, params: Dictionary) -> String:
	return ActionCodegen._apply_template(_descriptor_template(ace_id), params)


func _descriptor_template(ace_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	return "" if descriptor == null else descriptor.codegen_template
