# EventForge - render harness (dev tool) for THE RESTING TOOLBAR: the editor's top strip in both of
# its states. Two pictures out of one run:
#
#   docs/images/resting-toolbar-menu.png    the strip at rest, with the Menu open on its cascade
#   docs/images/resting-toolbar-expanded.png  the same strip with the chevron pressed
#
# Run NON-headless (a headless run cannot render, and the popup needs embedded subwindows):
#   godot --path . --script tools/render_resting_toolbar_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _editor: EventSheetEditor = null


func _init() -> void:
	root.title = "Resting Toolbar"
	root.size = Vector2i(1040, 520)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	var event_row: EventRow = EventRow.new()
	event_row.trigger_provider_id = "Core"
	event_row.trigger_id = "OnProcess"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "AddVar"
	action.codegen_template = "{var_name} += {amount}"
	action.params = {"var_name": "score", "amount": "1"}
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
	if _frames == 6:
		# The cascade, opened where the Menu button is, with the Sheet submenu shown beside it so the
		# picture says what "one Menu" means rather than only that there is one.
		var menu: MenuButton = _editor._toolbar.find_child("EventSheetMenu", true, false) as MenuButton
		var popup: PopupMenu = menu.get_popup()
		popup.position = Vector2i(menu.get_screen_position() + Vector2(0.0, 30.0))
		popup.reset_size()
		popup.popup()
		return
	if _frames == 10:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/resting-toolbar-menu.png")
		print("[preview] resting toolbar, menu open %dx%d" % [image.get_width(), image.get_height()])
		var menu: MenuButton = _editor._toolbar.find_child("EventSheetMenu", true, false) as MenuButton
		menu.get_popup().hide()
		_editor._menu_bar.set_full_toolbar(true)
		return
	if _frames < 16 or _editor == null:
		return
	var expanded: Image = root.get_texture().get_image()
	expanded.save_png("res://docs/images/resting-toolbar-expanded.png")
	print("[preview] toolbar expanded %dx%d" % [expanded.get_width(), expanded.get_height()])
	quit(0)
