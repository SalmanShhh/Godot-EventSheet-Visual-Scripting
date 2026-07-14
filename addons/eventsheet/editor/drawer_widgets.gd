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


## The `# @inspector_validate <function>` badge: calls the edited object's validator (a function
## returning a warning String, "" = valid) a few times a second and shows the returned message
## while it is non-empty. Runs only when the script actually executes in the editor (a @tool
## sheet); otherwise it stays silent - never a false alarm. Target-less = mock (the preview card).
class ValidateBadge:
	extends Label
	var _target: Object = null
	var _function: String = ""
	var _poll_accumulator: float = 0.0

	func _init(target: Object = null, validate_function: String = "") -> void:
		_target = target
		_function = validate_function
		text = "⚠ validated by %s() while you edit" % (_function if not _function.is_empty() else "a sheet function")
		autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_theme_font_size_override("font_size", 11)
		add_theme_color_override("font_color", Color("#f0883e"))
		_refresh()

	func _process(delta: float) -> void:
		_poll_accumulator += delta
		if _poll_accumulator < 0.25:
			return
		_poll_accumulator = 0.0
		_refresh()

	func _refresh() -> void:
		if _target == null:
			visible = true  # mock: show the badge's look
			return
		if not _can_run_validator():
			visible = false
			return
		var message: String = str(_target.call(_function))
		visible = not message.strip_edges().is_empty()
		if visible:
			text = "⚠ %s" % message.strip_edges()

	func _can_run_validator() -> bool:
		if not _target.has_method(_function):
			return false
		var script: Script = _target.get_script() as Script
		return script != null and script.is_tool()


## The `# @inspector_action <function> <Label>` field button: a small button rendered with the
## property that calls the edited object's function on click (reroll_stats, refresh_preview).
## Enabled only when the function can actually run in-editor (a @tool sheet); otherwise it stays
## disabled with the reason in its tooltip. Target-less = mock (the preview card).
class ActionButton:
	extends Button
	var _target: Object = null
	var _function: String = ""

	func _init(target: Object = null, action_function: String = "", label: String = "") -> void:
		_target = target
		_function = action_function
		text = label if not label.is_empty() else _function.capitalize()
		add_theme_font_size_override("font_size", 11)
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if _target == null:
			return  # mock: enabled-looking, wired to nothing
		if not _can_run():
			disabled = true
			tooltip_text = "Needs a @tool sheet with a %s() function to run in the editor." % _function
		else:
			tooltip_text = "Calls %s() on this object." % _function
		pressed.connect(_on_pressed)

	func _on_pressed() -> void:
		if _can_run():
			_target.call(_function)

	func _can_run() -> bool:
		if _target == null or not _target.has_method(_function):
			return false
		var script: Script = _target.get_script() as Script
		return script != null and script.is_tool()


# ── String toggle-button row ─────────────────────────────────────────────────
## A String's fixed choices as one row of toggle buttons - every option visible at a glance,
## one click to switch (a dropdown hides the alternatives behind a click). The pressed button
## IS the value; a value outside the set leaves nothing pressed (never clobbered).
class DrawerToggleRow:
	extends HBoxContainer
	signal value_changed(value: String)
	var editable: bool = true
	var _options: PackedStringArray = PackedStringArray()
	var _value: String = ""
	var _buttons: Array[Button] = []

	func _init(options: PackedStringArray = PackedStringArray()) -> void:
		_options = options
		add_theme_constant_override("separation", 2)
		for option: String in _options:
			var button: Button = Button.new()
			button.text = option
			button.toggle_mode = true
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(_on_option_pressed.bind(option))
			add_child(button)
			_buttons.append(button)

	func set_value(v: String) -> void:
		_value = v
		for button: Button in _buttons:
			button.set_pressed_no_signal(button.text == _value)
			button.disabled = not editable

	func get_value() -> String:
		return _value

	func _on_option_pressed(option: String) -> void:
		if not editable:
			return
		set_value(option)
		value_changed.emit(_value)


# ── Array-of-Dictionary table grid ───────────────────────────────────────────
## An Array[Dictionary] edited as a GRID: one row per element, one typed cell editor per column
## (text / number / checkbox), with add / remove / move-up controls. Columns come from the
## variable's table schema ({name, type} entries); values live in plain Dictionaries, so the
## generated game code needs nothing but the Array itself.
class DrawerTable:
	extends VBoxContainer
	signal value_changed(value: Array)
	var editable: bool = true
	var _columns: Array = []
	var _value: Array = []
	var _grid: GridContainer = null
	var _add_button: Button = null

	func _init(columns: Array = []) -> void:
		for column: Variant in columns:
			if column is Dictionary and not str((column as Dictionary).get("name", "")).is_empty():
				_columns.append(column)
		add_theme_constant_override("separation", 2)
		_grid = GridContainer.new()
		_grid.columns = _columns.size() + 2  # cells + move-up + remove
		_grid.add_theme_constant_override("h_separation", 4)
		_grid.add_theme_constant_override("v_separation", 2)
		add_child(_grid)
		_add_button = Button.new()
		_add_button.text = "+ Add row"
		_add_button.pressed.connect(_on_add_row)
		add_child(_add_button)
		_rebuild()

	func set_value(rows: Array) -> void:
		_value = []
		for row: Variant in rows:
			if row is Dictionary:
				_value.append((row as Dictionary).duplicate())
		_rebuild()

	func get_value() -> Array:
		return _value.duplicate(true)

	func _on_add_row() -> void:
		var fresh: Dictionary = {}
		for column: Dictionary in _columns:
			fresh[str(column.get("name"))] = _default_for(column)
		_value.append(fresh)
		_rebuild()
		value_changed.emit(get_value())

	## The starting cell value for a fresh row, by column type. An enum column seeds its FIRST choice
	## so a new row is valid immediately; everything else keeps its zero-ish default.
	static func _default_for(column: Dictionary) -> Variant:
		match str(column.get("type", "String")):
			"int":
				return 0
			"float":
				return 0.0
			"bool":
				return false
			"enum":
				var options: Array = column.get("options", []) if column.get("options") is Array else []
				return str(options[0]) if not options.is_empty() else ""
		return ""

	func _rebuild() -> void:
		for stale: Node in _grid.get_children():
			stale.queue_free()
		_add_button.disabled = not editable
		for column: Dictionary in _columns:
			var head: Label = Label.new()
			head.text = str(column.get("name")).capitalize()
			head.add_theme_font_size_override("font_size", 10)
			head.modulate = Color(0.72, 0.76, 0.84)
			_grid.add_child(head)
		_grid.add_child(Control.new())
		_grid.add_child(Control.new())
		for row_index: int in range(_value.size()):
			var row: Dictionary = _value[row_index]
			for column: Dictionary in _columns:
				_grid.add_child(_make_cell(row, column))
			var up_button: Button = Button.new()
			up_button.text = "▲"
			up_button.tooltip_text = "Move this row up"
			up_button.disabled = not editable or row_index == 0
			up_button.pressed.connect(_on_move_up.bind(row_index))
			_grid.add_child(up_button)
			var remove_button: Button = Button.new()
			remove_button.text = "✕"
			remove_button.tooltip_text = "Remove this row"
			remove_button.disabled = not editable
			remove_button.pressed.connect(_on_remove.bind(row_index))
			_grid.add_child(remove_button)

	func _make_cell(row: Dictionary, column: Dictionary) -> Control:
		var column_name: String = str(column.get("name"))
		var column_type: String = str(column.get("type", "String"))
		match column_type:
			"int", "float":
				var spin: SpinBox = SpinBox.new()
				spin.allow_greater = true
				spin.allow_lesser = true
				spin.step = 1.0 if column_type == "int" else 0.01
				spin.value = float(row.get(column_name, 0))
				spin.editable = editable
				spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				spin.value_changed.connect(func(v: float) -> void:
					row[column_name] = int(v) if column_type == "int" else v
					value_changed.emit(get_value()))
				return spin
			"bool":
				var check: CheckBox = CheckBox.new()
				check.button_pressed = bool(row.get(column_name, false))
				check.disabled = not editable
				check.toggled.connect(func(pressed: bool) -> void:
					row[column_name] = pressed
					value_changed.emit(get_value()))
				return check
			"enum":
				# A fixed-choice cell: a dropdown of the column's options. The stored value stays the
				# plain String choice, so the Array-of-Dictionary shape and .tres bytes are unchanged.
				var options: Array = column.get("options", []) if column.get("options") is Array else []
				var choice: OptionButton = OptionButton.new()
				choice.disabled = not editable
				choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var current: String = str(row.get(column_name, ""))
				var selected_index: int = -1
				for i: int in range(options.size()):
					choice.add_item(str(options[i]))
					if str(options[i]) == current:
						selected_index = i
				# A legacy value outside the option list stays untouched (select nothing, don't coerce).
				choice.select(selected_index)
				choice.item_selected.connect(func(idx: int) -> void:
					if idx >= 0 and idx < options.size():
						row[column_name] = str(options[idx])
						value_changed.emit(get_value()))
				return choice
		var edit: LineEdit = LineEdit.new()
		edit.text = str(row.get(column_name, ""))
		edit.editable = editable
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text_changed.connect(func(text: String) -> void:
			row[column_name] = text
			value_changed.emit(get_value()))
		return edit

	func _on_move_up(row_index: int) -> void:
		if row_index <= 0 or row_index >= _value.size():
			return
		var moved: Dictionary = _value[row_index]
		_value.remove_at(row_index)
		_value.insert(row_index - 1, moved)
		_rebuild()
		value_changed.emit(get_value())

	func _on_remove(row_index: int) -> void:
		if row_index < 0 or row_index >= _value.size():
			return
		_value.remove_at(row_index)
		_rebuild()
		value_changed.emit(get_value())


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
