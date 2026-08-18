# EventForge - render harness (dev tool) for M23 on an EDITABLE sheet: a statement carrying a
# ternary draws as the sub-event pair a Construct sheet would show - the check on the left, the
# statement with that branch's value on the right, then Else - on a sheet you can author, with the
# pair selected so the whole-pair highlight is visible. Run NON-headless:
#   godot --path . --script tools/render_ternary_editable_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _editor: EventSheetEditor = null


func _init() -> void:
	root.title = "Ternary pair on an editable sheet"
	root.size = Vector2i(1080, 520)
	root.gui_embed_subwindows = true
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		var sheet: EventSheetResource = EventSheetResource.new()
		sheet.custom_class_name = "SprintController"
		sheet.events.append(_event(_raw("print(\"ready\")")))
		var branchy: EventRow = _event(_raw("speed = sprint_speed if sprint_held else walk_speed"))
		sheet.events.append(branchy)
		sheet.events.append(_event(_raw("tier = \"gold\" if score > 100 else \"silver\" if score > 50 else \"bronze\"")))
		_editor = EventSheetEditor.new()
		root.add_child(_editor)
		_editor.setup(sheet)
		var viewport: EventSheetViewport = _editor.get_viewport_control()
		viewport.select_resource(branchy)
		_editor._set_status("A ternary reads as a sub-event pair here too - one statement, selected as one.")
		return
	if _frames < 12 or _editor == null:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/ternary-editable.png")
	print("[preview] ternary editable %dx%d" % [img.get_width(), img.get_height()])
	quit(0)


func _event(action: Resource) -> EventRow:
	var event_row: EventRow = EventRow.new()
	event_row.trigger_provider_id = "Core"
	event_row.trigger_id = "OnReady"
	event_row.actions.append(action)
	return event_row


func _raw(code: String) -> RawCodeRow:
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = code
	raw.enabled = true
	return raw
