# EventForge - render harness (dev tool) for label number scrubbing. Captures the ACE params
# dialog twice - before and after dragging the "Speed" LABEL 200 pixels to the right - and stacks
# the two into one image, so the value moving without a single keystroke is visible at a glance.
# Run NON-headless (headless cannot render):
#   godot --path . --script tools/render_number_scrub_preview.gd
@tool
extends SceneTree

const GAP: int = 14
const DRAG_PIXELS: float = 200.0

var _frames: int = 0
var _dialog: ACEParamsDialog = null
var _before: Image = null


func _init() -> void:
	root.title = "Number Scrubbing"
	root.size = Vector2i(680, 560)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_dialog = ACEParamsDialog.new()
		_dialog.init_dialog(root)
		var definition: ACEDefinition = ACEDefinition.new()
		definition.display_name = "Fire Bullet"
		definition.parameters = [
			{"id": "speed", "display_name": "Speed", "default_value": "250", "hint": "expression",
				"description": "Pixels per second the bullet travels."},
			{"id": "damage", "display_name": "Damage", "default_value": "10", "hint": "expression",
				"description": "Hit points removed on impact."},
			{"id": "spread", "display_name": "Spread", "default_value": "1.5", "hint": "expression",
				"description": "Random cone half-angle, in degrees."},
		]
		_dialog.open_with_values(definition, {}, {})
		return
	if _frames == 9:
		_before = _capture()
		_scrub_first_label()
		return
	if _frames < 16 or _before == null:
		return
	_save(_before, _capture())
	quit(0)


func _capture() -> Image:
	var image: Image = _dialog._dialog.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


## Drives the label's own input handler, so this exercises the shipped gesture rather than
## poking the field directly - if scrubbing regressed, the preview shows an unchanged value.
func _scrub_first_label() -> void:
	var label: Label = _first_param_label()
	if label == null:
		push_error("[preview] no param label found")
		quit(1)
		return
	var origin: Vector2 = label.get_global_rect().get_center()
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = origin
	label.gui_input.emit(press)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.global_position = origin + Vector2(DRAG_PIXELS, 0.0)
	label.gui_input.emit(motion)


func _first_param_label() -> Label:
	for row: Node in _dialog._form.get_children():
		if not (row is HBoxContainer):
			continue
		for child: Node in (row as HBoxContainer).get_children():
			if child is Label:
				return child as Label
	return null


func _save(before: Image, after: Image) -> void:
	var width: int = maxi(before.get_width(), after.get_width())
	var composed: Image = Image.create(width, before.get_height() + GAP + after.get_height(), false, Image.FORMAT_RGBA8)
	composed.fill(Color("#2b2b2b"))
	composed.blit_rect(before, Rect2i(Vector2i.ZERO, before.get_size()), Vector2i.ZERO)
	composed.blit_rect(after, Rect2i(Vector2i.ZERO, after.get_size()), Vector2i(0, before.get_height() + GAP))
	composed.save_png("res://docs/images/number-scrubbing.png")
	print("[preview] number scrubbing %dx%d (top: before, bottom: after a %dpx label drag)"
		% [composed.get_width(), composed.get_height(), int(DRAG_PIXELS)])
