# EventForge - render harness (dev tool) for the REFACTOR gestures. Produces three PNGs:
#
#   docs/images/refactor-row-menu.png          the row menu's Refactor ▸ submenu, on a real sheet
#   docs/images/duplicate-as-variant.png       the Duplicate as Variant… dialog, preview pane filled
#   docs/images/snippet-blanks.png             Insert Snippet…'s fill-in form for a snippet with blanks
#
# These are the parts no headless run can answer. The suite pins the transforms, the refusals and
# the menu labels; what it cannot see is whether a disabled item still READS as an offer with its
# reason attached, whether the preview pane is tall enough to show the rows a variant will produce
# before you commit to them, and whether a form built from a snippet's own blanks looks like a form
# rather than a wall of fields.
#
# Run NON-headless (headless cannot render):
#   godot --path . --script tools/render_refactor_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _stage: int = 0
var _editor: EventSheetEditor = null
var _dialog: Window = null


func _init() -> void:
	root.title = "Refactor gestures"
	root.size = Vector2i(1000, 760)
	# Dialogs and popup menus are Windows; embedding them is what puts them in the screenshot.
	root.gui_embed_subwindows = true
	var background: ColorRect = ColorRect.new()
	background.color = Color("#2b2b2b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	process_frame.connect(_on_frame)


func _print_action(message: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "ConsoleLog"
	action.codegen_template = "print({message})"
	action.params = {"message": message}
	return action


func _demo_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables["p1_jumps"] = {"type": "int", "default": 0}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var jump: ACEAction = ACEAction.new()
	jump.provider_id = "Core"
	jump.ace_id = "SetProperty"
	jump.codegen_template = "{target}.{property} = {value}"
	jump.params = {"target": "$Player1", "property": "velocity_y", "value": "p1_jumps"}
	event.actions.append(jump)
	event.actions.append(_print_action("\"jumped\""))
	sheet.events.append(event)
	return sheet


func _snippet_text() -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnBodyEntered"
	var play: ACEAction = ACEAction.new()
	play.provider_id = "Core"
	play.ace_id = "SetProperty"
	play.codegen_template = "{target}.{property} = {value}"
	play.params = {"target": "{{blank:Pickup Node|$Coin}}", "property": "stream", "value": "{{blank:Sound|\"coin.ogg\"}}"}
	event.actions.append(play)
	event.actions.append(_print_action("{{blank:Amount|10}}"))
	sheet.events.append(event)
	return EventSheetSnippet.serialize_rows([event], sheet)


func _on_frame() -> void:
	_frames += 1
	if _stage == 0 and _frames == 2:
		_editor = EventSheetEditor.new()
		_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(_editor)
		_editor.setup(_demo_sheet())
		_stage = 1
		return
	if _stage == 1 and _frames == 10:
		var event: EventRow = _editor._current_sheet.events[0] as EventRow
		var row_data: EventRowData = EventRowData.new()
		row_data.source_resource = event
		_editor._context_row = row_data
		_editor._context_menus._build_row_context_menu(row_data)
		_editor._row_context_menu.popup(Rect2i(Vector2i(60, 180), Vector2i.ONE))
		var submenu: PopupMenu = _editor._row_context_menu.get_node_or_null(EventSheetRefactorMenu.SUBMENU_NAME) as PopupMenu
		submenu.reset_size()
		submenu.popup(Rect2i(Vector2i(300, 470), Vector2i.ONE))
		_stage = 2
		return
	if _stage == 2 and _frames == 20:
		_save("refactor-row-menu")
		_editor._row_context_menu.hide()
		(_editor._row_context_menu.get_node_or_null(EventSheetRefactorMenu.SUBMENU_NAME) as PopupMenu).hide()
		_stage = 3
		return
	if _stage == 3 and _frames == 24:
		var rows: Array = [_editor._current_sheet.events[0]]
		var variant: EventSheetDuplicateVariantDialog = EventSheetDuplicateVariantDialog.open_for(_editor, rows)
		variant._object_fields[0]["edit"].text = "$Player2"
		variant._variable_fields[0]["edit"].text = "p2_jumps"
		variant.refresh_preview()
		variant.size = Vector2i(620, 560)
		variant.position = Vector2i(180, 90)
		_dialog = variant
		_stage = 4
		return
	if _stage == 4 and _frames == 34:
		_save("duplicate-as-variant")
		_dialog.hide()
		_stage = 5
		return
	if _stage == 5 and _frames == 38:
		var blanks: EventSheetSnippetBlanksDialog = EventSheetSnippetBlanksDialog.open_for(_editor, "Pickup", _snippet_text())
		blanks.size = Vector2i(520, 340)
		blanks.position = Vector2i(230, 190)
		_dialog = blanks
		_stage = 6
		return
	if _stage == 6 and _frames == 48:
		_save("snippet-blanks")
		_stage = 7
		return
	if _stage == 7 and _frames == 52:
		quit(0)


func _save(image_name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png("res://docs/images/%s.png" % image_name)
	print("[preview] %s %dx%d" % [image_name, image.get_width(), image.get_height()])
