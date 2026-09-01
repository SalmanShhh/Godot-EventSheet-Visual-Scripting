# EventForge - render harness (dev tool) for ADDING IN THE SHEET. Two pictures out of one run:
#
#   docs/images/sheet-corner-links.png   a sheet with the two corner links in place
#   docs/images/add-cascade-keys.png     the Menu open on Add, every key printed beside its item
#
# Run NON-headless (a headless run cannot render, and the popup needs embedded subwindows):
#   godot --path . --script tools/render_sheet_corner_links_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _editor: EventSheetEditor = null


func _init() -> void:
	root.title = "Adding In The Sheet"
	root.size = Vector2i(1040, 560)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


## A small, ordinary sheet - the links are on EVERY sheet, so the picture shows them over rows
## rather than over the getting-started state, where a reader might read them as part of it.
func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	for entry: Array in [["score", "1"], ["combo", "2"]]:
		var event_row: EventRow = EventRow.new()
		event_row.trigger_provider_id = "Core"
		event_row.trigger_id = "OnProcess"
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Core"
		action.ace_id = "AddVar"
		action.codegen_template = "{var_name} += {amount}"
		action.params = {"var_name": str(entry[0]), "amount": str(entry[1])}
		event_row.actions.append(action)
		sheet.events.append(event_row)
	return sheet


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_editor = EventSheetEditor.new()
		root.add_child(_editor)
		_editor.setup(_sheet())
		_editor._menu_bar.set_full_toolbar(false)
		return
	if _frames == 8:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/sheet-corner-links.png")
		print("[preview] sheet corner links %dx%d" % [image.get_width(), image.get_height()])
		# And the Add cascade, opened on the Menu button so the picture shows where it now lives as
		# well as what it says.
		var menu: MenuButton = _editor._toolbar.find_child("EventSheetMenu", true, false) as MenuButton
		var popup: PopupMenu = menu.get_popup()
		popup.position = Vector2i(menu.get_screen_position() + Vector2(0.0, 30.0))
		popup.reset_size()
		popup.popup()
		var add_popup: PopupMenu = popup.find_child("EventSheetAddMenu", true, false) as PopupMenu
		add_popup.position = Vector2i(popup.position + Vector2i(int(popup.size.x) - 8, 24))
		add_popup.reset_size()
		add_popup.popup()
		return
	if _frames < 14 or _editor == null:
		return
	var cascade: Image = root.get_texture().get_image()
	cascade.save_png("res://docs/images/add-cascade-keys.png")
	print("[preview] add cascade with keys %dx%d" % [cascade.get_width(), cascade.get_height()])
	quit(0)
