# EventForge — visual/size probe for the "Edit GDScript Block" popup (dev tool, not shipped logic).
# Reproduces the dialog the way double-clicking a GDScript block does, prints its launched size, and
# saves a PNG so the over-expansion (and its fix) can be inspected. Run NON-headless (needs a renderer):
#   godot --path . --script tools/render_code_dialog_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _dock: EventSheetDock = null


func _init() -> void:
	root.title = "Edit GDScript Block Preview"
	root.size = Vector2i(1100, 900)
	root.gui_embed_subwindows = true
	var background: ColorRect = ColorRect.new()
	background.color = Color("#252525")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	_dock = EventSheetEditor.new() as EventSheetDock
	_dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_dock)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_dock.setup(null)
		var row: RawCodeRow = RawCodeRow.new()
		row.code = "var damage := 10\nhost.take_damage(damage)\nprint(\"hit for \", damage)"
		_dock._on_viewport_raw_code_edit_requested(row, true)
		# Also size-check the other dialogs the balloon fix touched (no special state needed).
		_dock._comments._ensure_with_node_dialog()
		_dock._comments._with_node_dialog.popup_centered(Vector2i(460, 160))
		_dock._sheet_type._ensure_sheet_type_dialog()
		_dock._sheet_type._sheet_type_dialog.popup_centered(Vector2i(460, 300))
		_dock.show_welcome()  # extracted EventSheetWelcomeWindow (dock/welcome_window.gd)
		return
	if _frames < 10 or _dock == null or _dock._raw_code_dialog == null:
		return
	var dialog: Window = _dock._raw_code_dialog
	print("[code_dialog_dbg] raw_code.size=%s (target 680x460)" % str(dialog.size))
	print("[code_dialog_dbg] with_node.size=%s (target 460x160)" % str(_dock._comments._with_node_dialog.size))
	print("[code_dialog_dbg] sheet_type.size=%s (target 460x300)" % str(_dock._sheet_type._sheet_type_dialog.size))
	print("[code_dialog_dbg] welcome.size=%s (no target; sizes to content)" % str(_dock._welcome._welcome_window.size))
	var image: Image = dialog.get_texture().get_image()
	image.save_png("res://_code_dialog_preview.png")
	print("[code_dialog_preview] saved res://_code_dialog_preview.png (%dx%d)" % [image.get_width(), image.get_height()])
	quit(0)
