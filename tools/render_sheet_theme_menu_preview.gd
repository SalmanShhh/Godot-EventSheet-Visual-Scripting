# EventForge - render harness (dev tool) for THE LODGERS' NEW HOMES: the two courtesies of the
# resting strip that a picture is the only honest proof of. Two pictures out of one run:
#
#   docs/images/view-sheet-theme-menu.png  View > Sheet theme open, the presets listed and the
#                                          sheet's own one ticked
#   docs/images/resting-toolbar-note.png   the status bar carrying the one-time resting note
#
# Run NON-headless (a headless run cannot render, and the popups need embedded subwindows):
#   godot --path . --script tools/render_sheet_theme_menu_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _editor: EventSheetEditor = null


func _init() -> void:
	root.title = "Sheet Theme"
	# The OS window carries the picture (root.get_texture() is the window's own viewport), so it is
	# the one that has to be tall enough for the View menu - setting root.size alone leaves the
	# window at the project's boot size and crops every row past it.
	root.size = Vector2i(1180, 1040)
	DisplayServer.window_set_size(Vector2i(1180, 1040))
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
		# The View menu, opened under the Menu button, with Sheet theme's own submenu beside it -
		# the picture has to show the presets and the tick, not only that the entry exists.
		var menu: MenuButton = _editor._toolbar.find_child("EventSheetMenu", true, false) as MenuButton
		var view_popup: PopupMenu = _editor._view_popup
		view_popup.reset_size()
		view_popup.popup()
		view_popup.position = Vector2i(menu.get_screen_position() + Vector2(0.0, 30.0))

		var theme_menu: PopupMenu = view_popup.find_child("EventSheetSheetThemeMenu", true, false) as PopupMenu
		_editor._populate_sheet_theme_menu()
		# Beside its own row: a PopupMenu answers no per-item rect, so the row's top is read off the
		# menu's own height divided by the items in it - which is exact, because every row here is
		# the same height and the separators are counted among them.
		var row: int = view_popup.get_item_index(EventSheetMenuBar.SHEET_THEME_VIEW_ID)
		# The View menu is taller than the screen, so it scrolls: bring its own row into view and
		# highlight it, then hang the submenu beside where it now sits.
		view_popup.set_focused_item(row)
		var row_height: float = float(view_popup.size.y) / float(maxi(view_popup.item_count, 1))
		theme_menu.position = Vector2i(view_popup.position
			+ Vector2i(int(view_popup.size.x) - 8, int(row_height * float(row))))
		theme_menu.reset_size()
		theme_menu.popup()
		return
	if _frames == 10:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/view-sheet-theme-menu.png")
		print("[preview] View > Sheet theme %dx%d" % [image.get_width(), image.get_height()])
		_editor._view_popup.find_child("EventSheetSheetThemeMenu", true, false).hide()
		_editor._view_popup.hide()
		_editor._menu_bar.announce_resting_strip(true)
		return
	if _frames < 16 or _editor == null:
		return
	var note: Image = root.get_texture().get_image()
	note.save_png("res://docs/images/resting-toolbar-note.png")
	print("[preview] the one-time note %dx%d" % [note.get_width(), note.get_height()])
	quit(0)
