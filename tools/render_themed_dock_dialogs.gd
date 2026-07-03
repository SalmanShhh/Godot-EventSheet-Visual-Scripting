# EventForge — render harness (dev tool) for the themed event_sheet_dock popups. Builds the dock
# and opens the Welcome, Sheet Type, and Pick dialogs (now grouped into EventSheetPopupUI titled
# cards) so the look + sizing can be eyeballed. Run NON-headless:
#   godot --path . --script tools/render_themed_dock_dialogs.gd
@tool
extends SceneTree


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass

var _frames: int = 0
var _ed: EventSheetEditor = null


func _init() -> void:
	root.title = "Themed Dock Dialogs"
	root.size = Vector2i(720, 640)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _save(window: Window, name: String) -> void:
	var img: Image = window.get_texture().get_image()
	img.save_png("res://_themed_%s.png" % name)
	print("[themed] %s %dx%d" % [name, img.get_width(), img.get_height()])
	window.hide()


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_ed = EventSheetEditor.new()
		root.add_child(_ed)
		_ed.setup(EventSheetResource.new())
		_ed.set_undo_redo_manager(NoopUndoManager.new())
		_ed.show_welcome()  # builds + pops the extracted EventSheetWelcomeWindow
		return
	if _frames == 8:
		_save(_ed._welcome._welcome_window, "welcome")
		_ed._sheet_type._ensure_sheet_type_dialog()
		_ed._sheet_type._sheet_type_dialog.popup_centered(Vector2i(460, 300))
		return
	if _frames == 14:
		_save(_ed._sheet_type._sheet_type_dialog, "sheet_type")
		_ed._pick._ensure_pick_dialog()
		_ed._pick._pick_dialog.popup_centered(Vector2i(520, 300))
		return
	if _frames == 20:
		_save(_ed._pick._pick_dialog, "pick")
		quit(0)
