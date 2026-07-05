# EventForge - visual probe for the Tier 3 Inspector drawer widgets (dev tool, not shipped logic).
# Instantiates each reusable drawer Control (drawer_widgets.gd) with sample values and saves a PNG so the
# dial / bar / swatches / texture / curve can be eyeballed. Run NON-headless (needs a renderer):
#   godot --path . --script tools/render_drawer_widgets_preview.gd
@tool
extends SceneTree

var _frames: int = 0


func _init() -> void:
	root.title = "Tier 3 Drawer Widgets"
	root.size = Vector2i(560, 720)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2a2a2e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var pad: MarginContainer = MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_top", 18)
	pad.add_theme_constant_override("margin_right", 18)
	pad.add_theme_constant_override("margin_bottom", 18)
	root.add_child(pad)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	pad.add_child(col)

	# decor (header + info) above a property
	col.add_child(_heading("decor  -  # @inspector_header / # @inspector_info above a property"))
	col.add_child(EventSheetDrawerWidgets.build_header_label("Combat", "#e06666"))
	col.add_child(EventSheetDrawerWidgets.build_info_panel("Shared resource - edits affect every user."))

	# progress_bar
	col.add_child(_heading("progress_bar  -  int / float (drag to set)"))
	var bar: EventSheetDrawerWidgets.DrawerProgressBar = EventSheetDrawerWidgets.DrawerProgressBar.new(0.0, 100.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.set_value(65.0)
	col.add_child(bar)

	# min_max
	col.add_child(_heading("min_max  -  Vector2 range (x = low end, y = high end)"))
	var range_slider: EventSheetDrawerWidgets.DrawerMinMaxSlider = EventSheetDrawerWidgets.DrawerMinMaxSlider.new(0.0, 60.0)
	range_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_slider.set_value(Vector2(10.0, 40.0))
	col.add_child(range_slider)

	# vector_dial
	col.add_child(_heading("vector_dial  -  Vector2 direction + magnitude"))
	var dial: EventSheetDrawerWidgets.DrawerVectorDial = EventSheetDrawerWidgets.DrawerVectorDial.new(100.0)
	dial.set_value(Vector2(60.0, -40.0))
	col.add_child(dial)

	# swatch_row
	col.add_child(_heading("swatch_row  -  Color presets + picker"))
	var swatches: EventSheetDrawerWidgets.DrawerSwatchRow = EventSheetDrawerWidgets.DrawerSwatchRow.new()
	swatches.set_value(Color("#e23b3b"))
	col.add_child(swatches)

	# texture_preview
	col.add_child(_heading("texture_preview  -  Texture2D / path thumbnail"))
	var tex: EventSheetDrawerWidgets.DrawerTexturePreview = EventSheetDrawerWidgets.DrawerTexturePreview.new()
	tex.set_texture(_sample_texture())
	col.add_child(tex)

	# curve_editor
	col.add_child(_heading("curve_editor  -  inline Curve shape"))
	var curve_widget: EventSheetDrawerWidgets.DrawerCurvePreview = EventSheetDrawerWidgets.DrawerCurvePreview.new()
	curve_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	curve_widget.set_curve(_sample_curve())
	col.add_child(curve_widget)

	process_frame.connect(_on_frame)


func _heading(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9))
	label.add_theme_font_size_override("font_size", 12)
	return label


func _sample_texture() -> Texture2D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color("#3aa6e0"))
	gradient.set_color(1, Color("#9b51e0"))
	var grad_tex: GradientTexture2D = GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.width = 64
	grad_tex.height = 64
	grad_tex.fill_from = Vector2(0.0, 0.0)
	grad_tex.fill_to = Vector2(1.0, 1.0)
	return grad_tex


func _sample_curve() -> Curve:
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.45, 0.92))
	curve.add_point(Vector2(1.0, 0.35))
	curve.bake()
	return curve


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var image: Image = root.get_texture().get_image()
	var out_path: String = "res://_drawer_widgets_preview.png"
	image.save_png(out_path)
	print("[drawer_widgets_preview] saved %s (%dx%d)" % [out_path, image.get_width(), image.get_height()])
	quit(0)
