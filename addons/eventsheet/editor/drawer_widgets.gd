# Godot EventSheets - reusable visual Controls for Tier 3 custom Inspector drawers.
#
# These are plain Controls (NOT EditorProperty), so the SAME widget is reused in two places: the Inspector
# drawers (attribute_drawers.gd wraps each in an EditorProperty and forwards edits) AND the Variable dialog's
# live "what the drawer looks like" preview. Each editable widget exposes a value getter/setter and a
# `value_changed` signal; display-only widgets just take a value. None of this ships in generated game code -
# the drawers are an editor-only nicety, so the parity covenant is untouched.
@tool
class_name EventSheetDrawerWidgets
extends RefCounted

## A shared, game-flavoured palette for the swatch-row drawer (and its preview).
const SWATCH_PRESETS: Array[Color] = [
	Color("#e6e6e6"), Color("#1a1a1a"), Color("#e23b3b"), Color("#f0883e"),
	Color("#f4d03f"), Color("#52c46a"), Color("#3aa6e0"), Color("#5566e0"),
	Color("#9b51e0"), Color("#e055a8"),
]


# ── Progress bar (int/float) ────────────────────────────────────────────────
## A read-and-write bar: click/drag along it to set the value within [min, max].
class DrawerProgressBar:
	extends Control
	signal value_changed(value: float)
	var min_value: float = 0.0
	var max_value: float = 100.0
	var editable: bool = true
	var _value: float = 0.0

	func _init(p_min: float = 0.0, p_max: float = 100.0) -> void:
		min_value = p_min
		max_value = p_max
		custom_minimum_size = Vector2(0.0, 18.0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = "Drag to set the value"

	func set_value(v: float) -> void:
		_value = clampf(v, min_value, max_value)
		queue_redraw()

	func get_value() -> float:
		return _value

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		draw_rect(Rect2(0.0, 0.0, w, h), Color(0.0, 0.0, 0.0, 0.28), true)
		var span: float = maxf(0.0001, max_value - min_value)
		var frac: float = clampf((_value - min_value) / span, 0.0, 1.0)
		if frac > 0.0:
			draw_rect(Rect2(0.0, 0.0, w * frac, h), Color(0.36, 0.66, 1.0, 0.92), true)
		draw_rect(Rect2(0.0, 0.0, w, h), Color(1.0, 1.0, 1.0, 0.12), false, 1.0)
		var font: Font = ThemeDB.fallback_font
		var rounded: float = roundf(_value)
		var label: String = str(int(rounded)) if absf(_value - rounded) < 0.001 else str(snappedf(_value, 0.01))
		draw_string(font, Vector2(6.0, h * 0.5 + 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(1, 1, 1, 0.9))

	func _gui_input(event: InputEvent) -> void:
		if not editable:
			return
		if _is_left_drag(event):
			var frac: float = clampf((event as InputEventMouse).position.x / maxf(1.0, size.x), 0.0, 1.0)
			set_value(min_value + frac * (max_value - min_value))
			value_changed.emit(_value)
			accept_event()

	static func _is_left_drag(event: InputEvent) -> bool:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		if event is InputEventMouseMotion:
			return ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		return false


# ── Vector2 direction dial ──────────────────────────────────────────────────
## A draggable dial: the handle's offset from centre IS the vector (Godot Y-down), scaled so a handle at the
## rim equals `max_magnitude`. Turns two number fields into one spatial control (velocity, direction, offset).
class DrawerVectorDial:
	extends Control
	signal value_changed(value: Vector2)
	var max_magnitude: float = 100.0
	var editable: bool = true
	var _value: Vector2 = Vector2.ZERO

	func _init(p_max: float = 100.0) -> void:
		max_magnitude = maxf(0.0001, p_max)
		custom_minimum_size = Vector2(124.0, 124.0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = "Drag the handle to set direction + magnitude"

	func set_value(v: Vector2) -> void:
		_value = v
		queue_redraw()

	func get_value() -> Vector2:
		return _value

	func _center() -> Vector2:
		return size * 0.5

	func _radius() -> float:
		return maxf(8.0, minf(size.x, size.y) * 0.5 - 12.0)

	func _draw() -> void:
		var c: Vector2 = _center()
		var r: float = _radius()
		draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.22), 1.5, true)
		draw_arc(c, r * 0.5, 0.0, TAU, 32, Color(1, 1, 1, 0.08), 1.0, true)
		draw_line(c - Vector2(r, 0.0), c + Vector2(r, 0.0), Color(1, 1, 1, 0.10), 1.0)
		draw_line(c - Vector2(0.0, r), c + Vector2(0.0, r), Color(1, 1, 1, 0.10), 1.0)
		var disp: Vector2 = (_value / max_magnitude) * r
		if disp.length() > r:
			disp = disp.normalized() * r
		var handle: Vector2 = c + disp
		draw_line(c, handle, Color(0.36, 0.66, 1.0, 0.9), 2.0, true)
		draw_circle(handle, 5.5, Color(0.45, 0.74, 1.0))
		draw_circle(c, 2.5, Color(1, 1, 1, 0.5))
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(4.0, size.y - 5.0), "(%s, %s)" % [snappedf(_value.x, 0.1), snappedf(_value.y, 0.1)], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(1, 1, 1, 0.7))

	func _gui_input(event: InputEvent) -> void:
		if not editable:
			return
		if DrawerProgressBar._is_left_drag(event):
			var off: Vector2 = (event as InputEventMouse).position - _center()
			var r: float = _radius()
			if off.length() > r:
				off = off.normalized() * r
			set_value((off / r) * max_magnitude)
			value_changed.emit(_value)
			accept_event()


# ── Colour swatch row ───────────────────────────────────────────────────────
## A row of palette presets plus a full picker - click a swatch (or pick) to set the colour fast.
class DrawerSwatchRow:
	extends HBoxContainer
	signal value_changed(value: Color)
	var editable: bool = true
	var _value: Color = Color.WHITE
	var _picker: ColorPickerButton = null

	func _init() -> void:
		add_theme_constant_override("separation", 3)
		for preset: Color in EventSheetDrawerWidgets.SWATCH_PRESETS:
			add_child(_make_swatch(preset))
		_picker = ColorPickerButton.new()
		_picker.custom_minimum_size = Vector2(38.0, 20.0)
		_picker.color = _value
		_picker.tooltip_text = "Custom colour…"
		_picker.color_changed.connect(_on_picked)
		add_child(_picker)

	func set_value(v: Color) -> void:
		_value = v
		if _picker != null:
			_picker.color = v

	func get_value() -> Color:
		return _value

	func _make_swatch(preset: Color) -> Button:
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(20.0, 20.0)
		b.tooltip_text = "#" + preset.to_html(false)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = preset
		sb.set_corner_radius_all(3)
		sb.set_border_width_all(1)
		sb.border_color = Color(1, 1, 1, 0.25)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.pressed.connect(func() -> void: _apply(preset))
		return b

	func _apply(c: Color) -> void:
		if not editable:
			return
		set_value(c)
		value_changed.emit(c)

	func _on_picked(c: Color) -> void:
		if not editable:
			return
		_value = c
		value_changed.emit(c)


# ── Texture / sprite preview ────────────────────────────────────────────────
## A read-friendly thumbnail of a Texture2D (or a texture path). Display-only: the EditorProperty wrapper
## adds the actual picker above it; the dialog preview just shows a placeholder frame.
class DrawerTexturePreview:
	extends Control
	var _texture: Texture2D = null

	func _init() -> void:
		custom_minimum_size = Vector2(72.0, 72.0)
		# Stay a compact, left-aligned thumbnail instead of stretching across the property row.
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_texture(t: Texture2D) -> void:
		_texture = t
		queue_redraw()

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		# checkerboard so transparent textures read clearly
		var cell: float = 8.0
		var rows: int = int(ceil(size.y / cell))
		var cols: int = int(ceil(size.x / cell))
		for ry: int in range(rows):
			for cx: int in range(cols):
				var shade: Color = Color(0.20, 0.20, 0.20, 1.0) if (ry + cx) % 2 == 0 else Color(0.28, 0.28, 0.28, 1.0)
				draw_rect(Rect2(cx * cell, ry * cell, cell, cell), shade, true)
		if _texture != null:
			var tsize: Vector2 = _texture.get_size()
			if tsize.x > 0.0 and tsize.y > 0.0:
				var scale: float = minf(size.x / tsize.x, size.y / tsize.y)
				var draw_size: Vector2 = tsize * scale
				draw_texture_rect(_texture, Rect2((size - draw_size) * 0.5, draw_size), false)
		else:
			var font: Font = ThemeDB.fallback_font
			draw_string(font, Vector2(4.0, size.y * 0.5 + 4.0), "(no texture)", HORIZONTAL_ALIGNMENT_CENTER, size.x - 8.0, 10, Color(1, 1, 1, 0.45))
		draw_rect(rect, Color(1, 1, 1, 0.18), false, 1.0)


# ── Curve preview ───────────────────────────────────────────────────────────
## Renders a Curve's shape inline (read-friendly). Display-only: the EditorProperty wrapper adds the resource
## picker; the dialog preview shows a sample ease curve so the user sees what the drawer does.
class DrawerCurvePreview:
	extends Control
	var _curve: Curve = null

	func _init() -> void:
		custom_minimum_size = Vector2(0.0, 56.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_curve(c: Curve) -> void:
		_curve = c
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		draw_rect(Rect2(0.0, 0.0, w, h), Color(0.0, 0.0, 0.0, 0.25), true)
		# baseline + midline
		draw_line(Vector2(0.0, h - 1.0), Vector2(w, h - 1.0), Color(1, 1, 1, 0.12), 1.0)
		draw_line(Vector2(0.0, h * 0.5), Vector2(w, h * 0.5), Color(1, 1, 1, 0.06), 1.0)
		var pad: float = 4.0
		var inner_h: float = h - pad * 2.0
		var samples: int = 48
		var points: PackedVector2Array = PackedVector2Array()
		for i: int in range(samples + 1):
			var t: float = float(i) / float(samples)
			var sampled: float = _curve.sample_baked(t) if _curve != null else _ease_sample(t)
			var y: float = pad + (1.0 - clampf(sampled, 0.0, 1.0)) * inner_h
			points.append(Vector2(t * w, y))
		if points.size() >= 2:
			draw_polyline(points, Color(0.45, 0.74, 1.0, 0.95), 1.8, true)
		draw_rect(Rect2(0.0, 0.0, w, h), Color(1, 1, 1, 0.14), false, 1.0)

	## A pleasant default ease (smoothstep) for the dialog preview when there's no real Curve yet.
	func _ease_sample(t: float) -> float:
		return t * t * (3.0 - 2.0 * t)
