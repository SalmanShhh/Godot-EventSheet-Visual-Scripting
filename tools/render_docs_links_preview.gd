# EventForge - render harness (dev tool) for the Welcome window's documentation link, which now
# opens the guide in a browser at the installed version's tag instead of a res://docs/ path that
# does not exist in an installed project. Also prints the URL the button is wired to, so the
# rendered look and the live wiring are checked in one run. Run NON-headless:
#   godot --path . --script tools/render_docs_links_preview.gd
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
var _dock: EventSheetDock = null


func _init() -> void:
	root.title = "Documentation links"
	root.size = Vector2i(720, 700)
	# Dialogs are their own Windows; embedding them puts the popup inside the frame we capture.
	root.gui_embed_subwindows = true
	var background: ColorRect = ColorRect.new()
	background.color = Color("#2b2b2b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	print("[preview] migration guide -> %s" % EventSheets.doc_url("docs/GUIDE-MOVING-FROM-ANOTHER-EVENT-SHEET-EDITOR.md"))
	print("[preview] Quest pack guide -> %s" % EventSheets.doc_url(EventSheets.addon_guide_for_provider("QuestPackAddon")))
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_dock = EventSheetDock.new()
		root.add_child(_dock)
		_dock.setup(EventSheetResource.new())
		_dock.set_undo_redo_manager(NoopUndoManager.new())
		_dock.show_welcome()
		return
	if _frames == 10:
		var window: Window = _dock._welcome._welcome_window
		var image: Image = window.get_texture().get_image()
		image.save_png("res://docs/images/welcome-documentation-link.png")
		print("[preview] welcome %dx%d" % [image.get_width(), image.get_height()])
		quit(0)
