# EventForge - render harness (dev tool) for BBCode effects in rich-param cells: a Rich
# Print (print_rich) action whose message carries [b]/[color] renders the EFFECT in the
# sheet, while a plain Print keeps its tags verbatim. Run NON-headless:
#   godot --path . --script tools/render_rich_param_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _editor: EventSheetEditor = null


func _init() -> void:
	root.title = "Rich Param Cells"
	root.size = Vector2i(1000, 380)
	root.gui_embed_subwindows = true
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		var sheet: EventSheetResource = EventSheetResource.new()
		var event_row: EventRow = EventRow.new()
		event_row.trigger_provider_id = "Core"
		event_row.trigger_id = "OnReady"
		var rich: ACEAction = ACEAction.new()
		rich.provider_id = "Core"
		rich.ace_id = "ConsoleLog"
		rich.params = {"message": "\"[b]Wave 2[/b] [color=#e0b070]begins[/color]\"", "level": "print_rich"}
		event_row.actions.append(rich)
		var plain: ACEAction = ACEAction.new()
		plain.provider_id = "Core"
		plain.ace_id = "PushWarning"
		plain.codegen_template = "push_warning({message})"
		plain.params = {"message": "\"literal [b]tags[/b] stay\""}
		event_row.actions.append(plain)
		sheet.events.append(event_row)
		_editor = EventSheetEditor.new()
		root.add_child(_editor)
		_editor.setup(sheet)
		return
	if _frames < 12 or _editor == null:
		return
	var img: Image = root.get_texture().get_image()
	img.save_png("res://docs/images/rich-param-cells.png")
	print("[preview] rich param cells %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
