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


# ── Inspector decor (header label / info panel) ─────────────────────────────
## Built from the `# @inspector_header` / `# @inspector_info` decor comments the compiler emits above a
## variable. Display-only Controls, reused by the Inspector plugin (above the real property) and by the
## render harness, so the two can't diverge.


## An accent-coloured section label with breathing room above, so the section reads as a visual break.
static func build_header_label(text: String, accent: String) -> Control:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(accent) if not accent.is_empty() else Color(0.85, 0.88, 0.95))
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 2)
	margin.add_child(label)
	return margin


## A quiet, wrapping note panel - the place for "this resource is shared - edits affect every user".
static func build_info_panel(text: String) -> Control:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.42, 0.6, 0.22)
	style.border_color = Color(0.36, 0.66, 1.0, 0.5)
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.96))
	panel.add_child(label)
	return panel


## The `# @inspector_required` badge: a warning row that WATCHES the property and shows only while
## the value is unset (null resource, empty String/NodePath) - assign one and it vanishes. The poll
## runs a few times a second in the editor only; parity untouched.
class RequiredBadge:
	extends Label
	var _target: Object = null
	var _property: String = ""
	var _poll_accumulator: float = 0.0

	func _init(target: Object = null, property: String = "") -> void:
		_target = target
		_property = property
		text = "⚠ Required - assign a value"
		add_theme_font_size_override("font_size", 11)
		add_theme_color_override("font_color", Color("#e06666"))
		_refresh()

	func _process(delta: float) -> void:
		_poll_accumulator += delta
		if _poll_accumulator < 0.25:
			return
		_poll_accumulator = 0.0
		_refresh()

	func _refresh() -> void:
		# A target-less badge is a mock (the preview card shows the warning's look); a real one
		# tracks its property and hides the moment a value is assigned.
		visible = _target == null or is_value_missing(_target.get(_property))

	static func is_value_missing(value: Variant) -> bool:
		if value == null:
			return true
		if value is String:
			return (value as String).strip_edges().is_empty()
		if value is NodePath:
			return (value as NodePath).is_empty()
		return false


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


# ── Vector2 min-max range slider ────────────────────────────────────────────
## Two handles on one track: the Vector2's x is the low end, y the high end - one control for "a range",
## not two disconnected number fields (spawn intervals, damage ranges, zoom bounds). Drag the nearer
## handle; the pair can meet but never cross.
class DrawerMinMaxSlider:
	extends Control
	signal value_changed(value: Vector2)
	var min_value: float = 0.0
	var max_value: float = 100.0
	var editable: bool = true
	var _value: Vector2 = Vector2.ZERO
	var _dragging_high: bool = false

	func _init(p_min: float = 0.0, p_max: float = 100.0) -> void:
		min_value = p_min
		max_value = p_max
		_value = Vector2(p_min, p_max)
		custom_minimum_size = Vector2(0.0, 18.0)
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = "Drag either handle to set the low / high end"

	func set_value(v: Vector2) -> void:
		var low: float = clampf(minf(v.x, v.y), min_value, max_value)
		var high: float = clampf(maxf(v.x, v.y), min_value, max_value)
		_value = Vector2(low, high)
		queue_redraw()

	func get_value() -> Vector2:
		return _value

	func _frac(v: float) -> float:
		return clampf((v - min_value) / maxf(0.0001, max_value - min_value), 0.0, 1.0)

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var track_y: float = h * 0.5
		draw_rect(Rect2(0.0, track_y - 2.0, w, 4.0), Color(0.0, 0.0, 0.0, 0.32), true)
		var x_low: float = _frac(_value.x) * w
		var x_high: float = _frac(_value.y) * w
		draw_rect(Rect2(x_low, track_y - 2.0, maxf(0.0, x_high - x_low), 4.0), Color(0.36, 0.66, 1.0, 0.92), true)
		for x: float in [x_low, x_high]:
			draw_circle(Vector2(x, track_y), 5.0, Color(0.86, 0.9, 0.97))
			draw_circle(Vector2(x, track_y), 5.0, Color(0.2, 0.28, 0.4), false, 1.0)
		# Value labels ride WITH their handles (clamped to the widget), so they read as the pair's
		# current values - at the edges they would read as the track's fixed bounds instead.
		var font: Font = ThemeDB.fallback_font
		var low_label: String = _bound_label(_value.x)
		var low_width: float = font.get_string_size(low_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10).x
		draw_string(font, Vector2(clampf(x_low - low_width * 0.5, 0.0, w - low_width), track_y - 7.0), low_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(1, 1, 1, 0.75))
		var high_label: String = _bound_label(_value.y)
		var high_width: float = font.get_string_size(high_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10).x
		if absf(x_high - x_low) > (low_width + high_width) * 0.5 + 4.0:
			draw_string(font, Vector2(clampf(x_high - high_width * 0.5, 0.0, w - high_width), track_y - 7.0), high_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(1, 1, 1, 0.75))

	static func _bound_label(v: float) -> String:
		return str(int(roundf(v))) if absf(v - roundf(v)) < 0.001 else str(snappedf(v, 0.01))

	func _gui_input(event: InputEvent) -> void:
		if not editable:
			return
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var x: float = (event as InputEventMouseButton).position.x
			# Grab whichever handle is nearer; ties (overlapping pair) take the high one so a collapsed
			# range can always be re-opened by dragging right.
			_dragging_high = absf(x - _frac(_value.y) * size.x) <= absf(x - _frac(_value.x) * size.x)
			_drag_to(x)
			accept_event()
		elif event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_drag_to((event as InputEventMouseMotion).position.x)
			accept_event()

	func _drag_to(x: float) -> void:
		var v: float = min_value + clampf(x / maxf(1.0, size.x), 0.0, 1.0) * (max_value - min_value)
		if _dragging_high:
			_value.y = clampf(v, _value.x, max_value)
		else:
			_value.x = clampf(v, min_value, _value.y)
		queue_redraw()
		value_changed.emit(_value)


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
