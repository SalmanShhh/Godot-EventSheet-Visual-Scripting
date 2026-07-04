# EventForge - visual render harness (dev tool) for the dialog-theming pass. Builds the real
# Function dialog and Theme Editor (now grouped into EventSheetPopupUI titled cards) and saves a
# PNG of each, so the inset-card + accent-header look can be eyeballed. Run NON-headless:
#   godot --path . --script tools/render_themed_dialogs.gd
@tool
extends SceneTree

var _frames: int = 0
var _func_dialog: EventSheetFunctionDialog = null
var _theme_editor: EventSheetThemeEditor = null


func _init() -> void:
	root.title = "Themed Dialogs Preview"
	root.size = Vector2i(1120, 720)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _parent_if_orphan(window: Window) -> void:
	if window != null and window.get_parent() == null:
		root.add_child(window)


func _on_frame() -> void:
	_frames += 1
	# Function dialog: Params + Run-only-when as titled cards, Expose as an inset card.
	if _frames == 2:
		_func_dialog = EventSheetFunctionDialog.new()
		_func_dialog.set_taken_names_provider(func() -> PackedStringArray: return PackedStringArray())
		_func_dialog.init_dialog(root)
		_func_dialog.open()
		_func_dialog.add_param_row("damage")
		_func_dialog.add_guard_row("host.enabled")
		_func_dialog._expose_check.button_pressed = true
		_func_dialog._expose_card.visible = true
		return
	if _frames == 8 and _func_dialog != null:
		var img: Image = _func_dialog._dialog.get_texture().get_image()
		img.save_png("res://_themed_function_dialog.png")
		print("[themed] function dialog %dx%d" % [img.get_width(), img.get_height()])
		_func_dialog._dialog.hide()
		# Theme Editor: Quick Style + the four token sections as stacked titled cards.
		var holder: Control = Control.new()
		root.add_child(holder)
		_theme_editor = EventSheetThemeEditor.new()
		_theme_editor.open(holder, EventSheetEditorStyle.new())
		_parent_if_orphan(_theme_editor._dialog)
		return
	if _frames == 16 and _theme_editor != null:
		var img2: Image = _theme_editor._dialog.get_texture().get_image()
		img2.save_png("res://_themed_theme_editor.png")
		print("[themed] theme editor %dx%d" % [img2.get_width(), img2.get_height()])
		quit(0)
