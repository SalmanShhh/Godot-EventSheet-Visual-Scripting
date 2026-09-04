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

## The compiler script, reached BY PATH instead of by class name. This file is on the editor BOOT
## path (the plugin registers the Inspector drawer plugin in _enter_tree, and add_inspector_plugin
## takes an instance, so this script really does load at every editor start). Naming a global class
## compiles that class's whole dependency subtree the moment the script loads, and the compiler's
## subtree costs hundreds of milliseconds - paid by every session, for the table drawer's three enum
## helpers, which only a designer editing a table cell ever calls. Loaded once on first use instead.
const SHEET_COMPILER_PATH: String = "res://addons/eventforge/compiler/sheet_compiler.gd"

## The public API script, reached BY PATH for the same boot-cost reason as the compiler above: only
## a toggle row that actually asks for provider-drawn icons ever needs the registry behind it.
const EVENTSHEETS_API_PATH: String = "res://addons/eventsheet/api/eventsheets.gd"

static var _compiler_script: Script = null
static var _api_script: Script = null

## A shared, game-flavoured palette for the swatch-row drawer (and its preview). Hex text on
## purpose: these are game-content choices a designer picks a colour FROM, not editor chrome a
## theme owns, so they stay literal - and as strings they stay out of the theme-token lint's way.
const SWATCH_PRESET_HTML: Array[String] = [
	"e6e6e6", "1a1a1a", "e23b3b", "f0883e", "f4d03f",
	"52c46a", "3aa6e0", "5566e0", "9b51e0", "e055a8",
]


# ── Inspector decor (header label / info panel) ─────────────────────────────
## Built from the `# @inspector_header` / `# @inspector_info` decor comments the compiler emits above a
## variable. Display-only Controls, reused by the Inspector plugin (above the real property) and by the
## render harness, so the two can't diverge.


## The compiler script, loaded on first use and cached for the session (see SHEET_COMPILER_PATH).
## The table drawer asks per cell, so the load must not repeat.
static func sheet_compiler() -> Script:
	if _compiler_script == null:
		_compiler_script = load(SHEET_COMPILER_PATH)
	return _compiler_script


## The public API script, loaded on first use and cached for the session (see EVENTSHEETS_API_PATH).
static func eventsheets_api() -> Script:
	if _api_script == null:
		_api_script = load(EVENTSHEETS_API_PATH)
	return _api_script


## The editor's own undo manager, or null when there is no editor around (a headless run, the
## Variable dialog's preview). Reached through the singleton by NAME rather than by naming an
## editor-only class, so this file still loads in a headless suite and in an exported game's tools.
static func editor_undo_redo() -> Object:
	if not Engine.has_singleton("EditorInterface"):
		return null
	var interface: Object = Engine.get_singleton("EditorInterface")
	if interface == null or not interface.has_method("get_editor_undo_redo"):
		return null
	return interface.call("get_editor_undo_redo")


## The unit families the unit drawer knows, each as an ordered list of unit ids whose FIRST entry
## is the family's base (every conversion goes through it). A unit outside these lists is a pack's
## own word: it is shown as a label and converts to nothing, so a custom list is never mangled.
##   length  px (a Godot 2D world unit IS one pixel), screen = one viewport width
##   angle   deg, turn (360 deg), rad
##   time    s, ms, frames (the project's physics tick rate)
##   level   dB, fraction (Godot's own linear/dB pair)
const UNIT_FAMILIES: Dictionary = {
	"length": ["px", "world", "screen"],
	"angle": ["deg", "turn", "rad"],
	"time": ["s", "ms", "frames"],
	"level": ["db", "fraction"],
}

## Short words for the dropdown - the same spelling a Godot suffix would use.
const UNIT_LABELS: Dictionary = {
	"px": "px", "world": "world", "screen": "screen",
	"deg": "deg", "turn": "turns", "rad": "rad",
	"s": "s", "ms": "ms", "frames": "frames",
	"db": "dB", "fraction": "fraction",
}

## The floor a zero (or negative) linear amplitude reads as in dB. Godot's own mixer bottoms out
## at -80 dB, and linear_to_db(0.0) is -inf, which no spin box can show.
const SILENCE_DB: float = -80.0


## The family a unit belongs to ("" for a pack's own word).
static func unit_family(unit: String) -> String:
	for family: String in UNIT_FAMILIES:
		if (UNIT_FAMILIES[family] as Array).has(unit):
			return family
	return ""


## The dropdown word for a unit - its own spelling when the drawer does not know it.
static func unit_label(unit: String) -> String:
	return str(UNIT_LABELS.get(unit, unit))


## A value expressed in `unit`, in its family's base unit.
static func unit_to_base(unit: String, value: float) -> float:
	match unit:
		"screen":
			return value * screen_unit_pixels()
		"turn":
			return value * 360.0
		"rad":
			return rad_to_deg(value)
		"ms":
			return value * 0.001
		"frames":
			return value / physics_rate()
		"fraction":
			return linear_to_db(value) if value > 0.0 else SILENCE_DB
	return value


## The inverse of unit_to_base: a base-unit value read back in `unit`.
static func unit_from_base(unit: String, value: float) -> float:
	match unit:
		"screen":
			return value / screen_unit_pixels()
		"turn":
			return value / 360.0
		"rad":
			return deg_to_rad(value)
		"ms":
			return value / 0.001
		"frames":
			return value * physics_rate()
		"fraction":
			return db_to_linear(value)
	return value


## `value` re-read in another unit. Units from different families (or a pack's own words) are labels
## only, so the number is handed back untouched rather than converted through a guess.
static func convert_unit(from_unit: String, to_unit: String, value: float) -> float:
	if from_unit == to_unit:
		return value
	var family: String = unit_family(from_unit)
	if family.is_empty() or family != unit_family(to_unit):
		return value
	return unit_from_base(to_unit, unit_to_base(from_unit, value))


## The project's physics tick rate - what one "frame" of the time family is worth.
static func physics_rate() -> float:
	var rate: float = float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))
	return rate if rate > 0.0 else 60.0


## The project's viewport width - what one "screen" of the length family is worth in pixels.
static func screen_unit_pixels() -> float:
	var width: float = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
	return width if width > 0.0 else 1152.0


## The picture for one toggle-row option, or null when there is none to draw.
##
## Two sources, told apart by the source text itself (no prefix to remember):
##   a PATH PATTERN holding "%s" - the option name in snake_case is substituted, so
##     "res://art/cap_%s.svg" with the option "Round" loads "res://art/cap_round.svg";
##   anything else is a PROVIDER NAME registered through EventSheets.register_toggle_icon_provider,
##     whose callable is handed (option, size) and returns the Texture2D it drew.
## A missing file or an unregistered name is not an error: the button keeps its word.
static func toggle_icon_for(source: String, option: String, icon_size: int = 24) -> Texture2D:
	var trimmed: String = source.strip_edges()
	if trimmed.is_empty() or option.strip_edges().is_empty():
		return null
	if trimmed.contains("%s"):
		var path: String = trimmed.replace("%s", option.strip_edges().to_snake_case())
		if not ResourceLoader.exists(path):
			return null
		return load(path) as Texture2D
	var provider: Callable = eventsheets_api().toggle_icon_provider_for(trimmed)
	if not provider.is_valid():
		return null
	var drawn: Variant = provider.call(option, icon_size)
	return drawn as Texture2D


## An accent-coloured section label with breathing room above, so the section reads as a visual break.
static func build_header_label(text: String, accent: String) -> Control:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(13))
	label.add_theme_color_override("font_color", Color(accent) if not accent.is_empty()
		else EventSheetActiveTheme.chrome().drawer_header_text_color)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 2)
	margin.add_child(label)
	return margin


## A quiet, wrapping note panel - the place for "this resource is shared - edits affect every user".
static func build_info_panel(text: String) -> Control:
	var chrome: EventSheetChromeStyle = EventSheetActiveTheme.chrome()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = chrome.drawer_info_background_color
	style.border_color = chrome.drawer_info_border_color
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
	label.add_theme_color_override("font_color", chrome.drawer_info_text_color)
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
		add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
		add_theme_color_override("font_color", EventSheetActiveTheme.chrome().drawer_required_color)
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
		var chrome: EventSheetChromeStyle = EventSheetActiveTheme.chrome()
		var ink: Color = chrome.drawer_ink_color
		var w: float = size.x
		var h: float = size.y
		draw_rect(Rect2(0.0, 0.0, w, h), chrome.drawer_well_color, true)
		var span: float = maxf(0.0001, max_value - min_value)
		var frac: float = clampf((_value - min_value) / span, 0.0, 1.0)
		if frac > 0.0:
			draw_rect(Rect2(0.0, 0.0, w * frac, h), chrome.drawer_accent_color, true)
		draw_rect(Rect2(0.0, 0.0, w, h), Color(ink.r, ink.g, ink.b, 0.12), false, 1.0)
		var font: Font = ThemeDB.fallback_font
		var rounded: float = roundf(_value)
		var label: String = str(int(rounded)) if absf(_value - rounded) < 0.001 else str(snappedf(_value, 0.01))
		draw_string(font, Vector2(6.0, h * 0.5 + 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, EventSheetPalette.scaled(11), Color(ink.r, ink.g, ink.b, 0.9))

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
		var chrome: EventSheetChromeStyle = EventSheetActiveTheme.chrome()
		var ink: Color = chrome.drawer_ink_color
		var label_color: Color = Color(ink.r, ink.g, ink.b, 0.75)
		var w: float = size.x
		var h: float = size.y
		var track_y: float = h * 0.5
		draw_rect(Rect2(0.0, track_y - 2.0, w, 4.0), chrome.drawer_well_color, true)
		var x_low: float = _frac(_value.x) * w
		var x_high: float = _frac(_value.y) * w
		draw_rect(Rect2(x_low, track_y - 2.0, maxf(0.0, x_high - x_low), 4.0), chrome.drawer_accent_color, true)
		for x: float in [x_low, x_high]:
			draw_circle(Vector2(x, track_y), 5.0, chrome.drawer_handle_color)
			draw_circle(Vector2(x, track_y), 5.0, chrome.drawer_handle_border_color, false, 1.0)
		# Value labels ride WITH their handles (clamped to the widget), so they read as the pair's
		# current values - at the edges they would read as the track's fixed bounds instead.
		var font: Font = ThemeDB.fallback_font
		var low_label: String = _bound_label(_value.x)
		var low_width: float = font.get_string_size(low_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, EventSheetPalette.scaled(10)).x
		draw_string(font, Vector2(clampf(x_low - low_width * 0.5, 0.0, w - low_width), track_y - 7.0), low_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, EventSheetPalette.scaled(10), label_color)
		var high_label: String = _bound_label(_value.y)
		var high_width: float = font.get_string_size(high_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, EventSheetPalette.scaled(10)).x
		if absf(x_high - x_low) > (low_width + high_width) * 0.5 + 4.0:
			draw_string(font, Vector2(clampf(x_high - high_width * 0.5, 0.0, w - high_width), track_y - 7.0), high_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, EventSheetPalette.scaled(10), label_color)

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
		add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
		add_theme_color_override("font_color", EventSheetActiveTheme.chrome().drawer_validate_color)
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
		add_theme_font_size_override("font_size", EventSheetPalette.scaled(11))
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

	## The picture on an icon button, in editor pixels before the HiDPI scale.
	const ICON_SIZE: int = 24
	## The segmented variant is for a HANDFUL of word options; past that the equal-width strip stops
	## being readable and the row falls back to ordinary buttons.
	const SEGMENTED_MIN: int = 2
	const SEGMENTED_MAX: int = 5

	var editable: bool = true
	var _options: PackedStringArray = PackedStringArray()
	var _value: String = ""
	var _buttons: Array[Button] = []

	func _init(options: PackedStringArray = PackedStringArray(), icon_source: String = "", segmented: bool = false) -> void:
		_options = options
		# Segmented = equal-width word buttons joined into one strip, so it reads as a single control.
		var strip: bool = segmented and _options.size() >= SEGMENTED_MIN and _options.size() <= SEGMENTED_MAX
		add_theme_constant_override("separation", 0 if strip else 2)
		for option: String in _options:
			var button: Button = Button.new()
			button.text = option
			button.toggle_mode = true
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if strip:
				button.clip_text = true
			# Asked for at the size the button SHOWS it at: a provider draws its picture to order, and
			# a 24 px one stretched into a scaled button is a blurred picture on a HiDPI screen.
			var icon: Texture2D = EventSheetDrawerWidgets.toggle_icon_for(icon_source, option, EventSheetPalette.scaled(ICON_SIZE))
			if icon != null:
				# The picture IS the choice; the word stays as the tooltip so hovering (and a screen
				# reader) still says which option this is.
				button.icon = icon
				button.tooltip_text = option
				button.text = ""
				button.expand_icon = true
				button.custom_minimum_size = Vector2(EventSheetPalette.scaled(ICON_SIZE + 8), EventSheetPalette.scaled(ICON_SIZE + 8))
			button.pressed.connect(_on_option_pressed.bind(option))
			add_child(button)
			_buttons.append(button)

	func set_value(v: String) -> void:
		_value = v
		# Compare against the OPTION, not the button's text: an icon button carries the word in its
		# tooltip and shows no text at all, so a text comparison would never light one up.
		for index: int in range(_buttons.size()):
			_buttons[index].set_pressed_no_signal(index < _options.size() and _options[index] == _value)
			_buttons[index].disabled = not editable

	func get_value() -> String:
		return _value

	func _on_option_pressed(option: String) -> void:
		if not editable:
			return
		set_value(option)
		value_changed.emit(_value)


# ── A number and its unit ────────────────────────────────────────────
## A float shown as a spin box with a unit dropdown at its right edge. THE CONTRACT: the value this
## widget holds and reports is always in the STORED unit the export named; the dropdown only changes
## which unit it is READ in. Switching from world units to pixels re-reads 2.0 as 2.0 px and emits
## nothing, so the file on disk - and the number the running game uses - never moves.
class DrawerUnitField:
	extends HBoxContainer
	## Emitted with the value in the STORED unit, never in the shown one.
	signal value_changed(value: float)

	var editable: bool = true
	var _units: PackedStringArray = PackedStringArray()
	var _store_unit: String = ""
	var _view_unit: String = ""
	var _stored: float = 0.0
	var _spin: SpinBox = null
	var _unit_option: OptionButton = null


	func _init(units: PackedStringArray = PackedStringArray(), store_unit: String = "") -> void:
		_units = units
		_store_unit = store_unit if units.has(store_unit) else (units[0] if not units.is_empty() else "")
		_view_unit = _store_unit
		add_theme_constant_override("separation", 2)
		_spin = SpinBox.new()
		_spin.step = 0.001
		_spin.allow_greater = true
		_spin.allow_lesser = true
		_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_spin.value_changed.connect(_on_spin_changed)
		add_child(_spin)
		_unit_option = OptionButton.new()
		for unit: String in _units:
			_unit_option.add_item(EventSheetDrawerWidgets.unit_label(unit))
			_unit_option.set_item_metadata(_unit_option.item_count - 1, unit)
		# A field built with no units at all is a plain number box: selecting an item that is not
		# there is an error, and an empty dropdown beside a number says nothing to anybody.
		if _unit_option.item_count > 0:
			_unit_option.select(max(Array(_units).find(_view_unit), 0))
			_unit_option.item_selected.connect(_on_unit_selected)
			add_child(_unit_option)


	## Sets the value IN THE STORED UNIT (what the property holds).
	func set_value(v: float) -> void:
		_stored = v
		_refresh_shown()


	## The value in the stored unit.
	func get_value() -> float:
		return _stored


	## The number as the spin box currently SHOWS it - the stored value read in the view unit.
	func get_shown_value() -> float:
		return _spin.value


	## The unit currently being read in - a view, not a fact about the value.
	func get_view_unit() -> String:
		return _view_unit


	## Reads the value in another unit. The stored value does not move and nothing is emitted;
	## this is the dropdown's whole effect.
	func set_view_unit(unit: String) -> void:
		var index: int = Array(_units).find(unit)
		if index < 0:
			return
		_view_unit = unit
		_unit_option.select(index)
		_refresh_shown()


	func set_editable(v: bool) -> void:
		editable = v
		_spin.editable = v
		_unit_option.disabled = not v


	func _refresh_shown() -> void:
		_spin.set_value_no_signal(EventSheetDrawerWidgets.convert_unit(_store_unit, _view_unit, _stored))


	func _on_spin_changed(shown: float) -> void:
		if not editable:
			return
		_stored = EventSheetDrawerWidgets.convert_unit(_view_unit, _store_unit, shown)
		value_changed.emit(_stored)


	func _on_unit_selected(index: int) -> void:
		_view_unit = str(_unit_option.get_item_metadata(index))
		# Only the reading changes. No value_changed here: emitting one would write the converted
		# number back onto the property and the "stored unit is fixed" promise would be a lie.
		_refresh_shown()


# ── Four corners in one number ───────────────────────────────
## A Vector4 read as four corners, clockwise from the top-left: x top-left, y top-right,
## z bottom-right, w bottom-left. Most of the time the four are one number, so that is what the
## widget shows - a single box, with a button that opens the four labelled boxes when they are not.
## The same shape is what margins and padding are, which is why the marker says "corners" and
## nothing about what for.
class DrawerCorners:
	extends VBoxContainer
	signal value_changed(value: Vector4)

	## The corner each box holds, in the order the boxes are laid out on screen (reading order),
	## paired with the component index, so the clockwise storage order is never guessed at.
	const CORNER_CELLS: Array = [["Top-left", 0], ["Top-right", 1], ["Bottom-left", 3], ["Bottom-right", 2]]

	var editable: bool = true
	var _value: Vector4 = Vector4.ZERO
	var _uniform_spin: SpinBox = null
	var _expand_button: Button = null
	var _corner_grid: GridContainer = null
	var _corner_spins: Array[SpinBox] = []


	func _init() -> void:
		add_theme_constant_override("separation", 3)
		var top_row: HBoxContainer = HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 2)
		_uniform_spin = SpinBox.new()
		_uniform_spin.step = 0.001
		_uniform_spin.allow_greater = true
		_uniform_spin.allow_lesser = true
		_uniform_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_uniform_spin.tooltip_text = "All four corners at once."
		_uniform_spin.value_changed.connect(_on_uniform_changed)
		top_row.add_child(_uniform_spin)
		_expand_button = Button.new()
		_expand_button.text = "⊞"
		_expand_button.toggle_mode = true
		_expand_button.tooltip_text = "Set each corner on its own."
		_expand_button.toggled.connect(_on_expand_toggled)
		top_row.add_child(_expand_button)
		add_child(top_row)
		_corner_grid = GridContainer.new()
		_corner_grid.columns = 2
		_corner_grid.visible = false
		for cell: Array in CORNER_CELLS:
			var cell_box: VBoxContainer = VBoxContainer.new()
			cell_box.add_theme_constant_override("separation", 0)
			var cell_label: Label = Label.new()
			cell_label.text = str(cell[0])
			cell_label.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
			cell_label.modulate.a = 0.65
			cell_box.add_child(cell_label)
			var cell_spin: SpinBox = SpinBox.new()
			cell_spin.step = 0.001
			cell_spin.allow_greater = true
			cell_spin.allow_lesser = true
			cell_spin.value_changed.connect(_on_corner_changed.bind(int(cell[1])))
			cell_box.add_child(cell_spin)
			_corner_grid.add_child(cell_box)
			_corner_spins.append(cell_spin)
		add_child(_corner_grid)


	## True when all four corners hold the same number - the case the single box is honest about.
	static func is_uniform(value: Vector4) -> bool:
		return is_equal_approx(value.x, value.y) and is_equal_approx(value.y, value.z) and is_equal_approx(value.z, value.w)


	## One number as all four corners.
	static func uniform(number: float) -> Vector4:
		return Vector4(number, number, number, number)


	func set_value(v: Vector4) -> void:
		_value = v
		# Four different corners open the four boxes by themselves: a single box showing one of them
		# would be a quiet lie about the other three.
		if not is_uniform(_value):
			_expand_button.set_pressed_no_signal(true)
			_corner_grid.visible = true
		_refresh_boxes()


	func get_value() -> Vector4:
		return _value


	## True while the four per-corner boxes are open.
	func is_expanded() -> bool:
		return _corner_grid.visible


	func set_editable(v: bool) -> void:
		editable = v
		_uniform_spin.editable = v
		_expand_button.disabled = not v
		for spin: SpinBox in _corner_spins:
			spin.editable = v


	func _refresh_boxes() -> void:
		_uniform_spin.set_value_no_signal(_value.x)
		for index: int in range(CORNER_CELLS.size()):
			_corner_spins[index].set_value_no_signal(_value[int(CORNER_CELLS[index][1])])


	func _on_expand_toggled(pressed: bool) -> void:
		_corner_grid.visible = pressed
		if not pressed:
			# Folding back to one number means one number: the top-left wins, which is the corner the
			# single box was showing all along.
			_commit(uniform(_value.x))


	func _on_uniform_changed(number: float) -> void:
		if not editable:
			return
		_commit(uniform(number))


	func _on_corner_changed(number: float, component: int) -> void:
		if not editable:
			return
		var next: Vector4 = _value
		next[component] = number
		_commit(next)


	func _commit(next: Vector4) -> void:
		if next.is_equal_approx(_value):
			return
		_value = next
		_refresh_boxes()
		value_changed.emit(_value)


# ── Two numbers kept in a ratio ───────────────────────────────
## The `# @inspector_link <a> <b>` equals button: two neighbouring numbers tied together. Pressing it
## remembers the ratio the two have at that moment; while it stays pressed, editing either one moves
## the other to keep that ratio. Nothing is written while it is not pressed, and the decor emits no
## code at all - a project without this plugin simply has two ordinary numbers.
## Target-less = mock (the preview card and the gallery tile).
class LinkToggle:
	extends HBoxContainer

	var _target: Object = null
	var _first: String = ""
	var _second: String = ""
	var _ratio: float = 1.0
	var _last_first: float = 0.0
	var _last_second: float = 0.0
	var _poll_accumulator: float = 0.0
	var _button: Button = null
	## The editor's undo manager, so a followed edit is one step a reader can take back. Settable,
	## so the suite can hand a plain UndoRedo in and count the steps.
	var undo_redo: Object = null


	func _init(target: Object = null, first_property: String = "", second_property: String = "") -> void:
		_target = target
		_first = first_property
		_second = second_property
		undo_redo = EventSheetDrawerWidgets.editor_undo_redo()
		add_theme_constant_override("separation", 4)
		_button = Button.new()
		_button.text = "="
		_button.toggle_mode = true
		_button.tooltip_text = "Keep %s and %s in the ratio they have now." % [_first, _second]
		_button.toggled.connect(_on_toggled)
		add_child(_button)
		var caption: Label = Label.new()
		caption.text = "linked to %s" % _second
		caption.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
		caption.modulate.a = 0.6
		add_child(caption)


	## The ratio to keep: what the follower is worth per unit of the leader. A leader of zero has no
	## ratio to read (every follower would be infinitely more), so the pair keeps a ratio of one.
	static func link_ratio(leader: float, follower: float) -> float:
		return 1.0 if is_zero_approx(leader) else follower / leader


	## The follower's new value for a leader that just moved.
	static func link_follow(ratio: float, leader: float) -> float:
		return leader * ratio


	## The leader's new value for a follower that just moved (the same tie, read the other way).
	static func link_lead(ratio: float, follower: float) -> float:
		return follower if is_zero_approx(ratio) else follower / ratio


	## A number written back in the type the property already holds. A whole-number property (a dash
	## count, a step count) REFUSES a float through `set`, so without this the follower of an int pair
	## never moves at all.
	static func matched_type(existing: Variant, value: float) -> Variant:
		return int(round(value)) if existing is int else value


	## The one undo step a followed edit writes: the leader lands where the reader put it and the
	## follower lands on its share, so a single Ctrl+Z puts BOTH numbers back where they were - and
	## the poll below, seeing the pair as it left it, does not immediately move the follower again.
	## The manager is taken duck-typed (the editor's manager in the editor, a plain UndoRedo in the
	## suite), and a null one answers false so the caller can write the follower directly.
	static func commit_link(undo_redo_manager: Object, target: Object, leader: String, leader_before: Variant,
			leader_after: Variant, follower: String, follower_before: Variant, follower_after: Variant) -> bool:
		if undo_redo_manager == null or target == null or leader.is_empty() or follower.is_empty():
			return false
		if follower_before == follower_after:
			return false
		undo_redo_manager.call("create_action", "Link %s and %s" % [leader, follower])
		undo_redo_manager.call("add_do_property", target, leader, leader_after)
		undo_redo_manager.call("add_do_property", target, follower, follower_after)
		undo_redo_manager.call("add_undo_property", target, leader, leader_before)
		undo_redo_manager.call("add_undo_property", target, follower, follower_before)
		undo_redo_manager.call("commit_action")
		return true


	## True while the two numbers are tied.
	func is_linked() -> bool:
		return _button.button_pressed


	func _on_toggled(pressed: bool) -> void:
		if not pressed or _target == null:
			return
		_last_first = float(_target.get(_first))
		_last_second = float(_target.get(_second))
		_ratio = link_ratio(_last_first, _last_second)


	func _process(delta: float) -> void:
		_poll_accumulator += delta
		if _poll_accumulator < 0.2:
			return
		_poll_accumulator = 0.0
		if _target == null or not _button.button_pressed:
			return
		var current_first: float = float(_target.get(_first))
		var current_second: float = float(_target.get(_second))
		# Whichever one the reader just moved is the leader for this tick; the other follows. The
		# pair moves as ONE undo step - through the editor's own manager, never behind its back, so
		# taking the edit back takes the follower back with it.
		var leader: String = ""
		var follower: String = ""
		var leader_before: float = 0.0
		var leader_after: float = 0.0
		var follower_before: float = 0.0
		var follower_after: float = 0.0
		if not is_equal_approx(current_first, _last_first):
			leader = _first
			leader_before = _last_first
			leader_after = current_first
			follower = _second
			follower_before = current_second
			follower_after = link_follow(_ratio, current_first)
		elif not is_equal_approx(current_second, _last_second):
			leader = _second
			leader_before = _last_second
			leader_after = current_second
			follower = _first
			follower_before = current_first
			follower_after = link_lead(_ratio, current_second)
		else:
			return
		var typed_follower: Variant = matched_type(_target.get(follower), follower_after)
		if not commit_link(undo_redo, _target, leader, matched_type(_target.get(leader), leader_before),
				matched_type(_target.get(leader), leader_after), follower,
				matched_type(_target.get(follower), follower_before), typed_follower):
			_target.set(follower, typed_follower)
		_last_first = float(_target.get(_first))
		_last_second = float(_target.get(_second))


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
				# The KEY, not the label - this value is persisted into the designer's .tres the
				# moment they click Add Row, and nothing downstream re-validates a stored cell.
				var options: Array = column.get("options", []) if column.get("options") is Array else []
				return EventSheetDrawerWidgets.sheet_compiler().table_enum_key(options[0]) if not options.is_empty() else ""
			"color":
				return "#ffffff"
		return ""

	func _rebuild() -> void:
		for stale: Node in _grid.get_children():
			stale.queue_free()
		_add_button.disabled = not editable
		var ink: Color = EventSheetActiveTheme.chrome().drawer_ink_color
		for column: Dictionary in _columns:
			var head: Label = Label.new()
			head.text = str(column.get("name")).capitalize()
			head.add_theme_font_size_override("font_size", EventSheetPalette.scaled(10))
			head.modulate = Color(ink.r, ink.g, ink.b, 0.8)
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
				# A fixed-choice cell: a dropdown of the column's options. The dropdown READS its
				# option's label and STORES its key, so a grid can offer ">= (at least)" while the
				# cell keeps the short token the runtime matches on. An unlabeled option is its own
				# label, so the stored value and the .tres bytes are unchanged for every existing grid.
				var options: Array = column.get("options", []) if column.get("options") is Array else []
				var choice: OptionButton = OptionButton.new()
				choice.disabled = not editable
				choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var current: String = str(row.get(column_name, ""))
				var selected_index: int = -1
				for i: int in range(options.size()):
					choice.add_item(EventSheetDrawerWidgets.sheet_compiler().table_enum_label(options[i]))
					if EventSheetDrawerWidgets.sheet_compiler().table_enum_key(options[i]) == current:
						selected_index = i
				# A legacy value outside the option list stays untouched (select nothing, don't coerce).
				choice.select(selected_index)
				choice.item_selected.connect(func(idx: int) -> void:
					if idx >= 0 and idx < options.size():
						row[column_name] = EventSheetDrawerWidgets.sheet_compiler().table_enum_key(options[idx])
						value_changed.emit(get_value()))
				return choice
			"color":
				# A visual swatch instead of a typed hex. The stored value stays a String
				# ("#rrggbb", or "#rrggbbaa" when translucent) so the .tres bytes are unchanged;
				# Color.from_string reads back both hex and legacy named colors like "white".
				var swatch: ColorPickerButton = ColorPickerButton.new()
				swatch.disabled = not editable
				swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				swatch.color = Color.from_string(str(row.get(column_name, "")), Color.WHITE)
				swatch.color_changed.connect(func(picked: Color) -> void:
					row[column_name] = "#" + picked.to_html(picked.a < 1.0)
					value_changed.emit(get_value()))
				return swatch
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
		var chrome: EventSheetChromeStyle = EventSheetActiveTheme.chrome()
		var ink: Color = chrome.drawer_ink_color
		var c: Vector2 = _center()
		var r: float = _radius()
		draw_arc(c, r, 0.0, TAU, 48, Color(ink.r, ink.g, ink.b, 0.22), 1.5, true)
		draw_arc(c, r * 0.5, 0.0, TAU, 32, Color(ink.r, ink.g, ink.b, 0.08), 1.0, true)
		draw_line(c - Vector2(r, 0.0), c + Vector2(r, 0.0), Color(ink.r, ink.g, ink.b, 0.10), 1.0)
		draw_line(c - Vector2(0.0, r), c + Vector2(0.0, r), Color(ink.r, ink.g, ink.b, 0.10), 1.0)
		var disp: Vector2 = (_value / max_magnitude) * r
		if disp.length() > r:
			disp = disp.normalized() * r
		var handle: Vector2 = c + disp
		draw_line(c, handle, chrome.drawer_accent_color, 2.0, true)
		draw_circle(handle, 5.5, chrome.drawer_accent_bright_color)
		draw_circle(c, 2.5, Color(ink.r, ink.g, ink.b, 0.5))
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(4.0, size.y - 5.0), "(%s, %s)" % [snappedf(_value.x, 0.1), snappedf(_value.y, 0.1)], HORIZONTAL_ALIGNMENT_LEFT, -1.0, EventSheetPalette.scaled(10), Color(ink.r, ink.g, ink.b, 0.7))

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
		for preset_html: String in EventSheetDrawerWidgets.SWATCH_PRESET_HTML:
			add_child(_make_swatch(Color.html(preset_html)))
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
		var ink: Color = EventSheetActiveTheme.chrome().drawer_ink_color
		sb.border_color = Color(ink.r, ink.g, ink.b, 0.25)
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
		var chrome: EventSheetChromeStyle = EventSheetActiveTheme.chrome()
		var ink: Color = chrome.drawer_ink_color
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		# checkerboard so transparent textures read clearly
		var cell: float = 8.0
		var rows: int = int(ceil(size.y / cell))
		var cols: int = int(ceil(size.x / cell))
		for ry: int in range(rows):
			for cx: int in range(cols):
				var shade: Color = chrome.drawer_checker_dark_color if (ry + cx) % 2 == 0 \
					else chrome.drawer_checker_light_color
				draw_rect(Rect2(cx * cell, ry * cell, cell, cell), shade, true)
		if _texture != null:
			var tsize: Vector2 = _texture.get_size()
			if tsize.x > 0.0 and tsize.y > 0.0:
				var scale: float = minf(size.x / tsize.x, size.y / tsize.y)
				var draw_size: Vector2 = tsize * scale
				draw_texture_rect(_texture, Rect2((size - draw_size) * 0.5, draw_size), false)
		else:
			var font: Font = ThemeDB.fallback_font
			draw_string(font, Vector2(4.0, size.y * 0.5 + 4.0), "(no texture)", HORIZONTAL_ALIGNMENT_CENTER, size.x - 8.0, EventSheetPalette.scaled(10), Color(ink.r, ink.g, ink.b, 0.45))
		draw_rect(rect, Color(ink.r, ink.g, ink.b, 0.18), false, 1.0)


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
		var chrome: EventSheetChromeStyle = EventSheetActiveTheme.chrome()
		var ink: Color = chrome.drawer_ink_color
		var w: float = size.x
		var h: float = size.y
		draw_rect(Rect2(0.0, 0.0, w, h), chrome.drawer_well_color, true)
		# baseline + midline
		draw_line(Vector2(0.0, h - 1.0), Vector2(w, h - 1.0), Color(ink.r, ink.g, ink.b, 0.12), 1.0)
		draw_line(Vector2(0.0, h * 0.5), Vector2(w, h * 0.5), Color(ink.r, ink.g, ink.b, 0.06), 1.0)
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
			draw_polyline(points, chrome.drawer_accent_bright_color, 1.8, true)
		draw_rect(Rect2(0.0, 0.0, w, h), Color(ink.r, ink.g, ink.b, 0.14), false, 1.0)

	## A pleasant default ease (smoothstep) for the dialog preview when there's no real Curve yet.
	func _ease_sample(t: float) -> float:
		return t * t * (3.0 - 2.0 * t)
