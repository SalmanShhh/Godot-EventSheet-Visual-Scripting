# EventForge - render harness (dev tool) for Select All Events Using This: a sheet where
# three of five events share a Print action; the matching walk + multi-select run and the
# selection is screenshotted. Run NON-headless:
#   godot --path . --script tools/render_select_all_matching_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _editor: EventSheetEditor = null


func _make_event(trigger_id: String, ace_id: String, message: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = trigger_id
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.codegen_template = "print({message})"
	action.params = {"message": message}
	row.actions.append(action)
	return row


func _init() -> void:
	root.title = "Select All Matching"
	root.size = Vector2i(1000, 520)
	root.gui_embed_subwindows = true
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		var sheet: EventSheetResource = EventSheetResource.new()
		sheet.events.append(_make_event("OnReady", "ConsoleLog", "\"game started\""))
		sheet.events.append(_make_event("OnProcess", "PushWarning", "\"low health\""))
		sheet.events.append(_make_event("OnTimeout", "ConsoleLog", "\"wave spawns\""))
		sheet.events.append(_make_event("OnBodyEntered", "PushWarning", "\"hit taken\""))
		sheet.events.append(_make_event("OnAreaEntered", "ConsoleLog", "\"pickup\""))
		_editor = EventSheetEditor.new()
		root.add_child(_editor)
		_editor.setup(sheet)
		var matches: Array = EventSheetACEApply.matching_event_rows(sheet.events, "Core", "ConsoleLog")
		_editor.get_viewport_control().select_resources(matches)
		_editor._set_status("Selected %d event(s) using Log." % matches.size())
		return
	if _frames < 12 or _editor == null:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/select-all-matching.png")
	print("[preview] select all matching %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
