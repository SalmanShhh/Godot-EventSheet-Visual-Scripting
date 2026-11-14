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


## A section heading drawn the way Godot draws a subgroup: a quiet panel with the name in the bold
## label colour, with a little room above so the section reads as a break. The colour a heading line
## carries stays in the file and is not drawn, so the heading looks like every other.
static func build_header_label(text: String, _accent: String) -> Control:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", EventSheetLookStyle.bold_font())
	label.add_theme_color_override("font_color", EventSheetLookStyle.ink())
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", EventSheetLookStyle.panel_box())
	panel.add_child(label)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", int(EventSheetLookStyle.px(6.0)))
	margin.add_child(panel)
	return margin


## A quiet, wrapping grey line - the place for "this resource is shared - edits affect every user".
## No box and no outline: the words sit under their field in the editor's own font.
static func build_info_panel(text: String) -> Control:
	return EventSheetLookStyle.message_line(text, EventSheetLookStyle.Tone.NOTE)


## A line for a row of the Inspector that holds only a note: an EditorProperty with no label, so its
## content lands in the value column at the Inspector's own split, directly under the field it is about.
## The row hides when its content hides (a required note vanishes once the value is set).
class NoteRow:
	extends EditorProperty
	var _content: Control = null
	## The words in the label column; empty for a note that sits under its field with none.
	var _row_label: String = ""

	func _init(content: Control = null, row_label: String = "") -> void:
		_content = content
		_row_label = row_label
		selectable = false
		read_only = true
		if _content != null:
			add_child(_content)
			_content.visibility_changed.connect(_follow_content)
			_follow_content()

	func _follow_content() -> void:
		visible = _content == null or _content.visible

	## The property this row is tied to once the Inspector has built it: none. The Inspector ties a row to the
	## property it sits beside, and a row tied to a property shows that property's revert arrow (or, when the
	## row is read-only to hide the arrow, dims its label as Godot dims a worked-out value). Tied to nothing
	## it shows neither: no arrow, and a label like its neighbours'.
	static func detached_property() -> StringName:
		return &""

	func _notification(what: int) -> void:
		# The Inspector hands every editor its label after _init; this row keeps none.
		if what == NOTIFICATION_READY:
			label = _row_label
			selectable = false
			read_only = true
			_detach.call_deferred()

	## Read-only first, which is what keeps the revert arrow off while the Inspector builds the row; then
	## tied to nothing, so the arrow is never worked out again, and then the label is let read like the
	## ones around it.
	func _detach() -> void:
		set_object_and_property(get_edited_object(), detached_property())
		read_only = false
		queue_redraw()


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
		text = "▲ " + EventSheetL10n.translate("Required. Assign a value.")
		autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_theme_color_override("font_color", EventSheetLookStyle.tone_colour(EventSheetLookStyle.Tone.ERROR))
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
## A read-and-write bar: click/drag along it to set the value within [min, max]. Godot's own
## ProgressBar draws the bar, so it has the height, corner and colours of the fields around it; the
## reading over it says the value and the top of the range ("60 / 100").
class DrawerProgressBar:
	extends Control
	signal value_changed(value: float)
	var min_value: float = 0.0
	var max_value: float = 100.0
	var editable: bool = true
	var _value: float = 0.0
	var _bar: ProgressBar = null
	var _reading: Label = null

	func _init(p_min: float = 0.0, p_max: float = 100.0) -> void:
		min_value = p_min
		max_value = p_max
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = EventSheetL10n.translate("Drag to set the value")
		_bar = ProgressBar.new()
		_bar.show_percentage = false
		_bar.min_value = p_min
		_bar.max_value = p_max
		_bar.step = 0.0
		_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar.add_theme_stylebox_override("fill", EventSheetLookStyle.accent_fill())
		_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_bar)
		_reading = Label.new()
		_reading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_reading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_reading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_reading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_reading.add_theme_color_override("font_color", EventSheetLookStyle.ink())
		_outline_reading()
		add_child(_reading)
		_show()

	func _get_minimum_size() -> Vector2:
		var bar_size: Vector2 = _bar.get_combined_minimum_size() if _bar != null else Vector2.ZERO
		return Vector2(bar_size.x, maxf(bar_size.y, EventSheetLookStyle.field_height()))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED and _reading != null:
			_bar.add_theme_stylebox_override("fill", EventSheetLookStyle.accent_fill())
			_reading.add_theme_color_override("font_color", EventSheetLookStyle.ink())
			_outline_reading()
			update_minimum_size()

	## The reading is outlined in the editor's base colour, so it stays legible over the fill and over the empty part alike.
	func _outline_reading() -> void:
		_reading.add_theme_color_override("font_outline_color", EventSheetLookStyle.base_colour())
		_reading.add_theme_constant_override("outline_size", int(EventSheetLookStyle.px(3.0)))

	func set_value(v: float) -> void:
		_value = clampf(v, min_value, max_value)
		_show()

	func get_value() -> float:
		return _value

	func _show() -> void:
		_bar.value = _value
		_reading.text = "%s / %s" % [_number_text(_value), _number_text(max_value)]

	static func _number_text(number: float) -> String:
		var rounded: float = roundf(number)
		return str(int(rounded)) if absf(number - rounded) < 0.001 else str(snappedf(number, 0.01))

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
## A range as two number fields with a track between them: the Vector2's x is the low end, y the high
## end. Type in either field or drag either handle on the track; the pair can meet but never cross.
## The track is grey, the picked span is filled, the handles sit on the ends of the fill, and the ends
## of the whole range are written small under it. When the value column cannot hold the fields and the
## track on one line, the fields go on a line of their own and the track under them.
class DrawerMinMaxSlider:
	extends Container
	signal value_changed(value: Vector2)
	var min_value: float = 0.0
	var max_value: float = 100.0
	var editable: bool = true
	var _value: Vector2 = Vector2.ZERO
	var _low: Range = null
	var _high: Range = null
	var _track: MinMaxTrack = null
	## How many lines the parts sit on now: 1 (field, track, field), 2 (two fields, then the track)
	## or 3 (one part to a line).
	var _lines: int = 1

	func _init(p_min: float = 0.0, p_max: float = 100.0) -> void:
		min_value = p_min
		max_value = p_max
		_value = Vector2(p_min, p_max)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tooltip_text = EventSheetL10n.translate("Drag either handle to set the low / high end")
		_low = _make_field()
		_low.value_changed.connect(_on_low_typed)
		add_child(_low)
		_track = MinMaxTrack.new(p_min, p_max)
		_track.tooltip_text = tooltip_text
		_track.dragged.connect(_on_track_dragged)
		add_child(_track)
		_high = _make_field()
		_high.value_changed.connect(_on_high_typed)
		add_child(_high)
		_show()

	func _make_field() -> Range:
		var field: Range = EventSheetLookStyle.number_field("", EventSheetLookStyle.NO_COLOUR, false)
		EventSheetLookStyle.open_number_field(field, 0.01)
		field.allow_greater = false
		field.allow_lesser = false
		field.min_value = min_value
		field.max_value = max_value
		field.custom_minimum_size.x = _field_width()
		return field

	## Room for the longest value the range can hold, whole.
	func _field_width() -> float:
		var widest: String = ""
		for edge: float in [min_value, max_value]:
			var text: String = MinMaxTrack.bound_label(edge)
			if text.length() > widest.length():
				widest = text
		return EventSheetLookStyle.text_room(widest + ".0")

	func set_value(v: Vector2) -> void:
		var low: float = clampf(minf(v.x, v.y), min_value, max_value)
		var high: float = clampf(maxf(v.x, v.y), min_value, max_value)
		_value = Vector2(low, high)
		_show()

	func get_value() -> Vector2:
		return _value

	func set_editable(v: bool) -> void:
		editable = v
		EventSheetLookStyle.set_number_field_locked(_low, not v)
		EventSheetLookStyle.set_number_field_locked(_high, not v)
		_track.editable = v

	func _show() -> void:
		_low.set_value_no_signal(_value.x)
		_high.set_value_no_signal(_value.y)
		_track.set_value(_value)

	func _on_low_typed(typed: float) -> void:
		if not editable:
			return
		_value.x = clampf(typed, min_value, _value.y)
		_commit()

	func _on_high_typed(typed: float) -> void:
		if not editable:
			return
		_value.y = clampf(typed, _value.x, max_value)
		_commit()

	func _on_track_dragged(next: Vector2) -> void:
		if not editable:
			return
		_value = next
		_commit()

	func _commit() -> void:
		_show()
		value_changed.emit(_value)

	func _gap() -> float:
		return EventSheetLookStyle.px(4.0)

	func _lines_for(width: float) -> int:
		var field_width: float = _field_width()
		if width <= 0.0 or width >= field_width * 2.0 + EventSheetLookStyle.px(MinMaxTrack.MIN_WIDTH) + _gap() * 2.0:
			return 1
		if width >= field_width * 2.0 + _gap():
			return 2
		return 3

	func _get_minimum_size() -> Vector2:
		if _track == null:
			return Vector2.ZERO
		var field_height: float = EventSheetLookStyle.field_height()
		var track_height: float = _track.get_combined_minimum_size().y
		var height: float = track_height
		if _lines == 2:
			height = field_height + _gap() + track_height
		elif _lines == 3:
			height = field_height * 2.0 + _gap() * 2.0 + track_height
		return Vector2(_field_width(), height)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			_arrange()
		elif what == NOTIFICATION_THEME_CHANGED and _low != null:
			_low.custom_minimum_size.x = _field_width()
			_high.custom_minimum_size.x = _field_width()
			update_minimum_size()

	func _arrange() -> void:
		var wanted: int = _lines_for(size.x)
		if wanted != _lines:
			_lines = wanted
			update_minimum_size()
		var field_height: float = EventSheetLookStyle.field_height()
		var track_height: float = _track.get_combined_minimum_size().y
		var field_width: float = _field_width()
		var gap: float = _gap()
		if _lines == 1:
			fit_child_in_rect(_low, Rect2(0.0, 0.0, field_width, field_height))
			fit_child_in_rect(_high, Rect2(size.x - field_width, 0.0, field_width, field_height))
			fit_child_in_rect(_track, Rect2(field_width + gap, 0.0, size.x - field_width * 2.0 - gap * 2.0, track_height))
		elif _lines == 2:
			var half: float = (size.x - gap) * 0.5
			fit_child_in_rect(_low, Rect2(0.0, 0.0, half, field_height))
			fit_child_in_rect(_high, Rect2(half + gap, 0.0, half, field_height))
			fit_child_in_rect(_track, Rect2(0.0, field_height + gap, size.x, track_height))
		else:
			fit_child_in_rect(_low, Rect2(0.0, 0.0, size.x, field_height))
			fit_child_in_rect(_high, Rect2(0.0, field_height + gap, size.x, field_height))
			fit_child_in_rect(_track, Rect2(0.0, field_height * 2.0 + gap * 2.0, size.x, track_height))


## The drawn part of a min-max pair: a grey groove, the picked span filled, a handle on each end of the
## fill, and the two ends of the whole range written small under it. The groove and the handles are
## the editor's own slider pieces.
class MinMaxTrack:
	extends Control
	## Emitted with the new pair while a handle is dragged.
	signal dragged(value: Vector2)
	## The narrowest the track may be, at 1x.
	const MIN_WIDTH: float = 80.0
	## The ends of the whole range are written this much smaller than the editor's text.
	const END_TEXT_SCALE: float = 0.85
	var min_value: float = 0.0
	var max_value: float = 100.0
	var editable: bool = true
	var _value: Vector2 = Vector2.ZERO
	var _dragging_high: bool = false
	var _held: bool = false

	func _init(p_min: float = 0.0, p_max: float = 100.0) -> void:
		min_value = p_min
		max_value = p_max
		mouse_filter = Control.MOUSE_FILTER_STOP

	static func bound_label(v: float) -> String:
		return str(int(roundf(v))) if absf(v - roundf(v)) < 0.001 else str(snappedf(v, 0.01))

	func set_value(v: Vector2) -> void:
		_value = v
		queue_redraw()

	func _end_font_size() -> int:
		return maxi(1, int(roundf(EventSheetLookStyle.font_size() * END_TEXT_SCALE)))

	## The row the groove and handles sit on is as tall as a field; the ends are written under it.
	func _get_minimum_size() -> Vector2:
		var text_height: float = EventSheetLookStyle.font().get_height(_end_font_size())
		return Vector2(EventSheetLookStyle.px(MIN_WIDTH), EventSheetLookStyle.field_height() + text_height)

	func _handle_icon() -> Texture2D:
		return EventSheetLookStyle.typed_icon(&"grabber_highlight" if _held else &"grabber", &"HSlider")

	## How far in from each side the groove starts, so a handle at either end stays inside the track.
	func _pad() -> float:
		var picture: Texture2D = EventSheetLookStyle.typed_icon(&"grabber", &"HSlider")
		return picture.get_width() * 0.5 if picture != null else EventSheetLookStyle.px(6.0)

	func _x_of(v: float) -> float:
		var pad: float = _pad()
		var frac: float = clampf((v - min_value) / maxf(0.0001, max_value - min_value), 0.0, 1.0)
		return pad + frac * maxf(0.0, size.x - pad * 2.0)

	func _draw() -> void:
		var centre_y: float = EventSheetLookStyle.field_height() * 0.5
		var pad: float = _pad()
		var groove: StyleBox = EventSheetLookStyle.typed_box(&"slider", &"HSlider")
		var fill: StyleBox = EventSheetLookStyle.typed_box(&"grabber_area", &"HSlider")
		var groove_height: float = groove.get_minimum_size().y if groove != null else EventSheetLookStyle.px(4.0)
		groove_height = maxf(groove_height, EventSheetLookStyle.px(4.0))
		var whole: Rect2 = Rect2(pad, centre_y - groove_height * 0.5, maxf(0.0, size.x - pad * 2.0), groove_height)
		var x_low: float = _x_of(_value.x)
		var x_high: float = _x_of(_value.y)
		var span: Rect2 = Rect2(x_low, whole.position.y, maxf(0.0, x_high - x_low), groove_height)
		if groove != null:
			draw_style_box(groove, whole)
		else:
			draw_rect(whole, EventSheetLookStyle.rest())
		if fill != null:
			draw_style_box(EventSheetLookStyle.accent_box(fill), span)
		else:
			draw_rect(span, EventSheetLookStyle.accent())
		var handle: Texture2D = _handle_icon()
		for x: float in [x_low, x_high]:
			if handle != null:
				draw_texture(handle, Vector2(x, centre_y) - handle.get_size() * 0.5)
			else:
				draw_circle(Vector2(x, centre_y), EventSheetLookStyle.px(6.0), EventSheetLookStyle.ink())
		var font: Font = EventSheetLookStyle.font()
		var font_size: int = _end_font_size()
		var baseline: float = EventSheetLookStyle.field_height() + font.get_ascent(font_size)
		var quiet: Color = EventSheetLookStyle.quiet()
		draw_string(font, Vector2(pad, baseline), bound_label(min_value), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, quiet)
		var high_text: String = bound_label(max_value)
		var high_width: float = font.get_string_size(high_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		draw_string(font, Vector2(size.x - pad - high_width, baseline), high_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, quiet)

	func _gui_input(event: InputEvent) -> void:
		if not editable:
			return
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_held = (event as InputEventMouseButton).pressed
			queue_redraw()
			if _held:
				var x: float = (event as InputEventMouseButton).position.x
				# Grab whichever handle is nearer; ties (overlapping pair) take the high one so a collapsed
				# range can always be re-opened by dragging right.
				_dragging_high = absf(x - _x_of(_value.y)) <= absf(x - _x_of(_value.x))
				_drag_to(x)
			accept_event()
		elif event is InputEventMouseMotion and _held and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_drag_to((event as InputEventMouseMotion).position.x)
			accept_event()

	func _drag_to(x: float) -> void:
		var pad: float = _pad()
		var frac: float = clampf((x - pad) / maxf(1.0, size.x - pad * 2.0), 0.0, 1.0)
		var v: float = min_value + frac * (max_value - min_value)
		var next: Vector2 = _value
		if _dragging_high:
			next.y = clampf(v, _value.x, max_value)
		else:
			next.x = clampf(v, min_value, _value.y)
		_value = next
		queue_redraw()
		dragged.emit(next)


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
		text = "▲ " + (EventSheetL10n.translate("validated by %s() while you edit") % _function if not _function.is_empty()
			else EventSheetL10n.translate("validated by a sheet function while you edit"))
		autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_theme_color_override("font_color", EventSheetLookStyle.tone_colour(EventSheetLookStyle.Tone.WARNING))
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
			text = "▲ %s" % message.strip_edges()

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
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		theme_type_variation = "InspectorActionButton"
		icon = EventSheetLookStyle.icon(&"Reload")
		if _target == null:
			return  # mock: enabled-looking, wired to nothing
		if not _can_run():
			disabled = true
			tooltip_text = EventSheetL10n.translate("Needs a @tool sheet with a %s() function to run in the editor.") % _function
		else:
			tooltip_text = EventSheetL10n.translate("Calls %s() on this object.") % _function
		pressed.connect(_on_pressed)

	func _on_pressed() -> void:
		if _can_run():
			_target.call(_function)

	func _can_run() -> bool:
		if _target == null or not _target.has_method(_function):
			return false
		var script: Script = _target.get_script() as Script
		return script != null and script.is_tool()


# ── Groups as tabs ───────────────────────────────────────────────────────────
## The `# @inspector_tabs` strip: one tab per @export_group of the object. Picking one remembers it
## and asks the Inspector to rebuild, which then leaves the other groups' fields out. Target-less =
## mock (a render harness), wired to nothing.
class GroupTabs:
	extends TabBar
	const OBJECT_DECOR_PATH: String = "res://addons/eventsheet/editor/inspector/object_decor.gd"
	var _target: Object = null

	func _init(target: Object = null, groups: PackedStringArray = PackedStringArray(), chosen: String = "") -> void:
		_target = target
		clip_tabs = false
		for group: String in groups:
			add_tab(group)
		var chosen_index: int = Array(groups).find(chosen)
		current_tab = chosen_index if chosen_index >= 0 else 0
		tab_changed.connect(_on_tab_changed)
		if _target != null:
			ready.connect(_tidy_sections, CONNECT_DEFERRED)

	func _on_tab_changed(index: int) -> void:
		if _target == null:
			return
		load(OBJECT_DECOR_PATH).choose_tab(_target, get_tab_title(index))
		_target.notify_property_list_changed()

	## Godot draws a heading for every group before any plugin is asked about its fields, so the
	## groups whose tab is not picked are left as empty headings: those are hidden. A heading is empty
	## only when nothing at all was drawn under it - a heading holding another plugin's own controls
	## (or this one's notes) stays. The picked group's heading opens if it is folded, since its tab
	## already says which group is showing.
	func _tidy_sections() -> void:
		var inspector: Node = get_parent()
		while inspector != null and not (inspector is EditorInspector):
			inspector = inspector.get_parent()
		if inspector == null:
			return
		var folded: Array[Control] = []
		for section: Node in inspector.find_children("*", "", true, false):
			if section.get_class() != "EditorInspectorSection" or not (section is Control):
				continue
			var editors: Array[Node] = section.find_children("*", "EditorProperty", true, false)
			if holds_nothing(section):
				(section as Control).hide()
			elif tab_count > 0 and not editors.is_empty() and not (editors[0] as Control).is_visible_in_tree() \
					and _holds_picked_group(editors):
				folded.append(section as Control)
		if folded.is_empty():
			return
		# Opened once laid out, so a click (where one is needed) lands on the heading.
		await get_tree().process_frame
		for section: Control in folded:
			if is_instance_valid(section) and section.is_visible_in_tree():
				# The heading's own unfold, which Godot remembers as a person's click; a version
				# without it gets that click.
				if section.has_method("unfold"):
					section.call("unfold")
				else:
					_click_heading(section)

	## True when nothing was drawn under a heading: no field, no control of any plugin - only the
	## containers that would have held them, and the headings of subgroups as empty as itself.
	static func holds_nothing(section: Node) -> bool:
		for child: Node in section.find_children("*", "Control", true, false):
			if not (child is Container) and child.get_class() != "EditorInspectorSection":
				return false
		return true

	func _holds_picked_group(editors: Array[Node]) -> bool:
		var decor: Dictionary = load(OBJECT_DECOR_PATH).for_object(_target)
		var group_of: Dictionary = decor.get("group_of", {})
		var picked: String = get_tab_title(current_tab)
		for editor: Node in editors:
			if str(group_of.get(str((editor as EditorProperty).get_edited_property()), "")) == picked:
				return true
		return false

	## A heading opens on a click, the way a person opens it, so Godot remembers it open as usual.
	## Only for a Godot whose heading has no unfold() a script can call.
	func _click_heading(section: Control) -> void:
		var at: Vector2 = section.get_global_transform_with_canvas().origin + Vector2(section.size.x * 0.5, 6.0)
		for pressed: bool in [true, false]:
			var click: InputEventMouseButton = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			click.position = at
			click.global_position = at
			section.get_viewport().push_input(click)


# ── Choices a function gives ─────────────────────────────────────────────────
## The `# @inspector_choices <function>` dropdown: the words a function of the script returns, as a
## described dropdown. The function may return a list of words, or a Dictionary of word -> the
## sentence that describes it. A value the list no longer holds stays shown, marked, never replaced.
class ChoicesField:
	extends OptionButton
	signal value_changed(word: String)
	const POPUP_UI_PATH: String = "res://addons/eventsheet/editor/popup_ui.gd"
	var _function: String = ""
	var _words: PackedStringArray = PackedStringArray()
	## The [choices, current] the list was last filled with.
	var _offered: Array = []

	func _init(choices_function: String = "") -> void:
		_function = choices_function
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		load(POPUP_UI_PATH).described_option(self)
		item_selected.connect(func(index: int) -> void: value_changed.emit(_words[index]))

	## True when the function can run in the editor: the object's script is a @tool script that has it.
	static func can_ask(target: Object, choices_function: String) -> bool:
		if target == null or choices_function.is_empty() or not target.has_method(choices_function):
			return false
		var script: Script = target.get_script() as Script
		return script != null and script.is_tool()

	## The function's answer as [[word, description], ...], in its own order. Anything that is not a
	## list or a Dictionary is no choices at all.
	static func read_choices(answer: Variant) -> Array:
		var choices: Array = []
		if answer is Dictionary:
			for word: Variant in (answer as Dictionary):
				choices.append([str(word), str((answer as Dictionary)[word])])
		elif answer is Array or answer is PackedStringArray:
			for word: Variant in answer:
				choices.append([str(word), ""])
		return choices

	## Fills the dropdown from the function and selects `current`.
	func show_choices(target: Object, current: String) -> void:
		var choices: Array = read_choices(target.call(_function)) if can_ask(target, _function) else []
		# The Inspector refreshes often; refilling an unchanged list would close it while it is open.
		var offered: Array = [choices, current]
		if offered == _offered:
			return
		_offered = offered
		clear()
		_words = PackedStringArray()
		var popup_ui: GDScript = load(POPUP_UI_PATH)
		for choice: Array in choices:
			_words.append(str(choice[0]))
			popup_ui.add_described_item(self, str(choice[0]), str(choice[1]))
		if not _words.has(current):
			_words.append(current)
			popup_ui.add_described_item(self, current, EventSheetL10n.translate("Not one of the words %s() gives.") % _function)
		select(Array(_words).find(current))
		popup_ui.follow_description(self)


# ── String toggle-button row ─────────────────────────────────────────────────
## A String's fixed choices as one joined strip of toggle buttons - every option visible at a glance,
## one click to switch (a dropdown hides the alternatives behind a click). The pressed button IS the
## value, filled with the editor's accent; a value outside the set leaves nothing pressed (never
## clobbered). An option with a picture keeps its word beside it, so a picture that is missing can
## never leave a blank square. The strip wraps to a second line rather than cut a word short.
class DrawerToggleRow:
	extends HFlowContainer
	signal value_changed(value: String)

	## What the marker's `segmented` tail used to ask for: equal-width buttons. The strip is always
	## joined now, so the tail only decides whether the buttons share one width.
	var equal_widths: bool = false
	var editable: bool = true
	var _options: PackedStringArray = PackedStringArray()
	var _value: String = ""
	var _buttons: Array[Button] = []

	func _init(options: PackedStringArray = PackedStringArray(), icon_source: String = "", segmented: bool = false) -> void:
		_options = options
		equal_widths = segmented
		add_theme_constant_override("h_separation", 0)
		add_theme_constant_override("v_separation", 0)
		var picture_size: int = maxi(1, int(EventSheetLookStyle.field_height() * 0.75))
		for index: int in _options.size():
			var option: String = _options[index]
			var button: Button = Button.new()
			button.text = option
			button.toggle_mode = true
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size.y = EventSheetLookStyle.field_height()
			# Asked for at the size the button SHOWS it at: a provider draws its picture to order, and
			# a picture stretched into a scaled button is a blurred picture on a HiDPI screen.
			var icon: Texture2D = EventSheetDrawerWidgets.toggle_icon_for(icon_source, option, picture_size)
			if icon != null:
				button.icon = icon
				button.tooltip_text = option
			button.pressed.connect(_on_option_pressed.bind(option))
			_buttons.append(button)
		EventSheetLookStyle.joined_strip(_buttons, self)
		for index: int in _buttons.size():
			var button: Button = _buttons[index]
			var option: String = _options[index]
			# The chosen word is written bold, which is wider; reserve that room so no word is ever cut.
			var bold_extra: float = EventSheetLookStyle.bold_font().get_string_size(option, HORIZONTAL_ALIGNMENT_LEFT, -1.0, EventSheetLookStyle.font_size()).x - EventSheetLookStyle.font().get_string_size(option, HORIZONTAL_ALIGNMENT_LEFT, -1.0, EventSheetLookStyle.font_size()).x
			button.custom_minimum_size.x = button.get_combined_minimum_size().x + maxf(0.0, bold_extra)
		if equal_widths:
			var widest: float = 0.0
			for button: Button in _buttons:
				widest = maxf(widest, button.get_combined_minimum_size().x)
			for button: Button in _buttons:
				button.custom_minimum_size.x = widest

	func set_value(v: String) -> void:
		_value = v
		# Compare against the OPTION, not the button's text: a button with a picture may carry more than
		# its word, so a text comparison would be the wrong question.
		for index: int in range(_buttons.size()):
			var chosen: bool = index < _options.size() and _options[index] == _value
			_buttons[index].set_pressed_no_signal(chosen)
			_buttons[index].disabled = not editable
			if chosen:
				_buttons[index].add_theme_font_override("font", EventSheetLookStyle.bold_font())
			else:
				_buttons[index].remove_theme_font_override("font")

	func get_value() -> String:
		return _value

	## The widest the strip needs to show every word whole on one line.
	func width_for_one_line() -> float:
		var total: float = 0.0
		for button: Button in _buttons:
			total += button.get_combined_minimum_size().x
		return total

	func _on_option_pressed(option: String) -> void:
		if not editable:
			return
		set_value(option)
		value_changed.emit(_value)


# ── A number and its unit ────────────────────────────────────────────
## A float shown as a number field with a unit dropdown joined to its right edge. THE CONTRACT: the
## value this widget holds and reports is always in the STORED unit the export named; the dropdown only
## changes which unit it is READ in. Switching from world units to pixels re-reads 2.0 as 2.0 px and
## emits nothing, so the file on disk - and the number the running game uses - never moves.
class DrawerUnitField:
	extends HBoxContainer
	## Emitted with the value in the STORED unit, never in the shown one.
	signal value_changed(value: float)

	var editable: bool = true
	var _units: PackedStringArray = PackedStringArray()
	var _store_unit: String = ""
	var _view_unit: String = ""
	var _stored: float = 0.0
	var _spin: Range = null
	var _unit_option: OptionButton = null


	func _init(units: PackedStringArray = PackedStringArray(), store_unit: String = "") -> void:
		_units = units
		_store_unit = store_unit if units.has(store_unit) else (units[0] if not units.is_empty() else "")
		_view_unit = _store_unit
		add_theme_constant_override("separation", 0)
		_spin = EventSheetLookStyle.number_field("", EventSheetLookStyle.NO_COLOUR, false)
		EventSheetLookStyle.open_number_field(_spin)
		_spin.custom_minimum_size.x = EventSheetLookStyle.text_room("-1000.000")
		EventSheetLookStyle.join_field(_spin, true, false)
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
			EventSheetLookStyle.join_button(_unit_option, false, true)
			add_child(_unit_option)


	## Sets the value IN THE STORED UNIT (what the property holds).
	func set_value(v: float) -> void:
		_stored = v
		_refresh_shown()


	## The value in the stored unit.
	func get_value() -> float:
		return _stored


	## The number as the field currently SHOWS it - the stored value read in the view unit.
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
		EventSheetLookStyle.set_number_field_locked(_spin, not v)
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


# ── Four corners ─────────────────────────────────────────────
## A Vector4 read as four corners, clockwise from the top-left: x top-left, y top-right,
## z bottom-right, w bottom-left. Four number fields, two to a line, each marked with the corner it
## sets, and a link button that keeps the four the same while it is down. The same shape is what
## margins and padding are, which is why the marker says "corners" and nothing about what for.
class DrawerCorners:
	extends VBoxContainer
	signal value_changed(value: Vector4)

	## The corner each field holds, in the order the fields are laid out on screen (reading order),
	## paired with the component index, so the clockwise storage order is never guessed at.
	const CORNER_CELLS: Array = [["Top-left", 0], ["Top-right", 1], ["Bottom-left", 3], ["Bottom-right", 2]]
	## The mark in front of each field, by component: the corner it sets.
	const CORNER_MARKS: Dictionary = {0: "◜", 1: "◝", 3: "◟", 2: "◞"}

	var editable: bool = true
	var _value: Vector4 = Vector4.ZERO
	var _linked: bool = true
	var _fields: Array[Range] = []
	var _link_button: Button = null
	var _spacer: Control = null
	var _lines: Array[BoxContainer] = []
	var _head: HBoxContainer = null


	func _init() -> void:
		_head = HBoxContainer.new()
		_head.visible = false
		add_child(_head)
		var corner_words: Dictionary = {0: EventSheetL10n.translate("Top-left"), 1: EventSheetL10n.translate("Top-right"), 3: EventSheetL10n.translate("Bottom-left"),
			2: EventSheetL10n.translate("Bottom-right")}
		for line_index: int in 2:
			var line: BoxContainer = BoxContainer.new()
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for cell_index: int in 2:
				var cell: Array = CORNER_CELLS[line_index * 2 + cell_index]
				var field: Range = EventSheetLookStyle.number_field(str(CORNER_MARKS[int(cell[1])]), EventSheetLookStyle.ink(), false)
				EventSheetLookStyle.open_number_field(field)
				field.tooltip_text = str(corner_words.get(cell[1], cell[0]))
				field.value_changed.connect(_on_corner_changed.bind(int(cell[1])))
				line.add_child(field)
				_fields.append(field)
			_lines.append(line)
			add_child(line)
		_link_button = EventSheetLookStyle.icon_button(&"Instance", "∞", EventSheetL10n.translate("Keep the four corners the same."))
		_link_button.flat = false
		_link_button.toggle_mode = true
		_link_button.button_pressed = true
		_link_button.toggled.connect(_on_link_toggled)
		_lines[0].add_child(_link_button)
		_spacer = Control.new()
		_spacer.custom_minimum_size = _link_button.get_combined_minimum_size()
		_lines[1].add_child(_spacer)
		custom_minimum_size.x = EventSheetLookStyle.number_field_min_width()
		_restyle_link()


	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
			_arrange()


	## Two fields to a line while the value column has room for two whole fields and the link; one
	## to a line when it does not, so no number is ever cut short. The link is an icon-sized button
	## at the end of the first line of fields at every width: beside the second field when two sit
	## to a line, beside the first when they stack.
	func _arrange() -> void:
		var room_needed: float = EventSheetLookStyle.number_field_min_width() * 2.0 + _link_button.get_combined_minimum_size().x + EventSheetLookStyle.px(6.0)
		var stacked: bool = size.x > 0.0 and size.x < room_needed
		for line: BoxContainer in _lines:
			line.vertical = stacked
		_spacer.visible = not stacked
		var first: Range = _fields[0]
		var first_home: Node = _head if stacked else _lines[0]
		var link_home: Node = _head if stacked else _lines[0]
		_head.visible = stacked
		if first.get_parent() != first_home:
			first.reparent(first_home, false)
			first_home.move_child(first, 0)
		if _link_button.get_parent() != link_home:
			_link_button.reparent(link_home, false)
		_link_button.size_flags_horizontal = Control.SIZE_SHRINK_END if stacked else Control.SIZE_FILL
		if stacked:
			first.size_flags_horizontal = Control.SIZE_EXPAND_FILL


	## Where the first field and the link sit while the fields stack: one line of its own.
	func head_holds_link() -> bool:
		return _link_button.get_parent() == _head


	## Whether the link button is on the same line as the first field.
	func link_beside_first_field() -> bool:
		return _link_button.get_parent() == _fields[0].get_parent()


	## True when all four corners hold the same number - the case the link is honest about.
	static func is_uniform(value: Vector4) -> bool:
		return is_equal_approx(value.x, value.y) and is_equal_approx(value.y, value.z) and is_equal_approx(value.z, value.w)


	## One number as all four corners.
	static func uniform(number: float) -> Vector4:
		return Vector4(number, number, number, number)


	func set_value(v: Vector4) -> void:
		_value = v
		# Four different corners come up unlinked by themselves: a link that says the four are the
		# same while they are not would be a quiet lie.
		if not is_uniform(_value) and _linked:
			_linked = false
			_link_button.set_pressed_no_signal(false)
			_restyle_link()
		_refresh_fields()


	func get_value() -> Vector4:
		return _value


	## True while the link is down: an edit to one corner writes all four.
	func is_linked() -> bool:
		return _linked


	func set_editable(v: bool) -> void:
		editable = v
		_link_button.disabled = not v
		for field: Range in _fields:
			EventSheetLookStyle.set_number_field_locked(field, not v)


	func _refresh_fields() -> void:
		for index: int in range(CORNER_CELLS.size()):
			_fields[index].set_value_no_signal(_value[int(CORNER_CELLS[index][1])])


	func _restyle_link() -> void:
		var picture: Texture2D = EventSheetLookStyle.icon(&"Instance" if _linked else &"Unlinked")
		if picture != null:
			_link_button.icon = picture
		else:
			_link_button.text = "∞" if _linked else "∘"


	func _on_link_toggled(pressed: bool) -> void:
		_linked = pressed
		_restyle_link()
		if pressed:
			# Linking means one number: the top-left wins, which is the corner read first.
			_commit(uniform(_value.x))


	func _on_corner_changed(number: float, component: int) -> void:
		if not editable:
			return
		if _linked:
			_commit(uniform(number))
			return
		var next: Vector4 = _value
		next[component] = number
		_commit(next)


	func _commit(next: Vector4) -> void:
		if next.is_equal_approx(_value):
			return
		_value = next
		_refresh_fields()
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


	## `inline` draws only the button, as Godot's own link icon, for a pair that already shares one row.
	func _init(target: Object = null, first_property: String = "", second_property: String = "", inline: bool = false) -> void:
		_target = target
		_first = first_property
		_second = second_property
		undo_redo = EventSheetDrawerWidgets.editor_undo_redo()
		add_theme_constant_override("separation", 4)
		_button = Button.new()
		_button.text = "="
		_button.toggle_mode = true
		_button.tooltip_text = EventSheetL10n.translate("Keep %s and %s in the ratio they have now.") % [_first, _second]
		_button.toggled.connect(_on_toggled)
		add_child(_button)
		if inline:
			_button.flat = true
			_restyle_inline(false)
			_button.toggled.connect(_restyle_inline)
			return
		var caption: Label = Label.new()
		caption.text = EventSheetL10n.translate("linked to %s") % _second
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


	## Whether the follower is already where the tie would put it. Two floats a hair apart are the
	## same number for this purpose - writing that hair would be an undo step nobody made - while
	## anything else (a whole-number pair, most of all) compares exactly.
	static func same_value(before: Variant, after: Variant) -> bool:
		if before is float and after is float:
			return is_equal_approx(before, after)
		return before == after


	## The name of the step this edit should JOIN rather than follow: the one the Inspector has just
	## committed for the leader's own edit. It is asked of the manager instead of spelled here,
	## because the editor names that step in its own words (and its own language). A name that does
	## not end in the leader's own is some other edit entirely, so it is refused and the follower
	## writes a step of its own - which is what a suite's bare UndoRedo, holding no action at all,
	## also gets.
	static func merge_target_name(undo_redo_manager: Object, target: Object, leader: String) -> String:
		if undo_redo_manager == null or leader.is_empty():
			return ""
		var current: String = ""
		if undo_redo_manager.has_method("get_current_action_name"):
			current = str(undo_redo_manager.call("get_current_action_name"))
		elif undo_redo_manager.has_method("get_object_history_id") and undo_redo_manager.has_method("get_history_undo_redo"):
			# The editor's manager keeps one history per object; the plain UndoRedo inside it is the
			# one that knows what it last committed.
			var history: Object = undo_redo_manager.call("get_history_undo_redo",
				int(undo_redo_manager.call("get_object_history_id", target)))
			if history != null:
				current = str(history.call("get_current_action_name"))
		return current if current.ends_with(leader) else ""


	## The one undo step a followed edit writes: the leader lands where the reader put it and the
	## follower lands on its share, so a single Ctrl+Z puts BOTH numbers back where they were - and
	## the poll below, seeing the pair as it left it, does not immediately move the follower again.
	## It is ONE step because it MERGES into the step the Inspector just wrote for the leader: a
	## gesture the reader made once must not be two entries in the history, with Ctrl+Y bringing the
	## leader back on its own. Where there is nothing to merge into, the follower names its own step.
	## The manager is taken duck-typed (the editor's manager in the editor, a plain UndoRedo in the
	## suite), and a null one answers false so the caller can write the follower directly.
	static func commit_link(undo_redo_manager: Object, target: Object, leader: String, leader_before: Variant,
			leader_after: Variant, follower: String, follower_before: Variant, follower_after: Variant) -> bool:
		if undo_redo_manager == null or target == null or leader.is_empty() or follower.is_empty():
			return false
		if same_value(follower_before, follower_after):
			return false
		var joined: String = merge_target_name(undo_redo_manager, target, leader)
		# MERGE_ALL, never MERGE_ENDS: the ends mode DROPS the undo operations of the action being
		# merged in, and the follower's undo operation is the whole point of the merge.
		undo_redo_manager.call("create_action",
			joined if not joined.is_empty() else EventSheetL10n.translate("Link %s and %s") % [leader, follower], UndoRedo.MERGE_ALL)
		undo_redo_manager.call("add_do_property", target, leader, leader_after)
		undo_redo_manager.call("add_do_property", target, follower, follower_after)
		undo_redo_manager.call("add_undo_property", target, leader, leader_before)
		undo_redo_manager.call("add_undo_property", target, follower, follower_before)
		undo_redo_manager.call("commit_action")
		return true


	## True while the two numbers are tied.
	func is_linked() -> bool:
		return _button.button_pressed


	## The inline button shows the editor's linked or unlinked icon.
	func _restyle_inline(linked: bool) -> void:
		var picture: Texture2D = EventSheetLookStyle.icon(&"Instance" if linked else &"Unlinked")
		if picture != null:
			_button.icon = picture
			_button.text = ""
		else:
			_button.text = "∞" if linked else "∘"


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
##
## A long list is READ through a view: a search box, a click on a column's name to sort by it
## (number columns as numbers), and pages of PAGE_SIZE rows. The view only chooses which stored rows
## are drawn and in what order - `get_value()` is always the list in the order the file keeps it,
## so searching or sorting never writes anything. A cell left empty is drawn quietly amber, and its
## hover says which column of which row is missing.
class DrawerTable:
	extends VBoxContainer
	signal value_changed(value: Array)
	## Rows drawn at once; a list longer than this gets the search box and the pages.
	const PAGE_SIZE: int = 8
	## The sort key of the leading "#" column: the order the file keeps.
	const STORED_ORDER: String = "#"
	## The width, unscaled, from which a share cell draws its bar as well as its percent.
	const ROOMY_WIDTH: float = 440.0
	## The most room, unscaled, a text cell asks for on the strength of its content alone.
	const TEXT_CELL_CAP: float = 140.0
	## One row's share: a bar and its percent.
	const SHARE_CELL: GDScript = preload("res://addons/eventsheet/editor/inspector/share_cell.gd")
	var editable: bool = true
	## The number column each row's share is worked out from; "" draws no share column.
	var weight_column: String = ""
	var _columns: Array = []
	var _value: Array = []
	var _grid: GridContainer = null
	var _add_button: Button = null
	var _total_label: Label = null
	## The share cell of each drawn row, as [cell, stored index], repainted when a weight changes.
	var _share_cells: Array = []
	## The "share" heading; it goes with the share cells while the table is too narrow for them.
	var _share_head: Label = null
	var _search: LineEdit = null
	var _pager: HBoxContainer = null
	var _page_label: Label = null
	var _previous_button: Button = null
	var _next_button: Button = null
	var _missing_label: Label = null
	var _open_link: LinkButton = null
	## Opens the file this list lives in as a table; the link shows only while it is set.
	var open_table: Callable = Callable()
	var _query: String = ""
	var _sort_column: String = ""
	var _descending: bool = false
	var _page: int = 0
	## Each drawn cell's [control, row, column, stored index], so a fill or an emptying repaints its
	## own cell without rebuilding the grid (which would take the focus from the cell being typed in).
	var _cell_marks: Array = []

	func _init(columns: Array = []) -> void:
		for column: Variant in columns:
			if column is Dictionary and not str((column as Dictionary).get("name", "")).is_empty():
				_columns.append(column)
		_search = LineEdit.new()
		_search.placeholder_text = EventSheetL10n.translate("Search the rows")
		_search.clear_button_enabled = true
		_search.text_changed.connect(search)
		add_child(_search)
		_grid = GridContainer.new()
		_grid.columns = _columns.size() + 2  # drag grip + cells + remove
		add_child(_grid)
		_pager = HBoxContainer.new()
		_previous_button = Button.new()
		_previous_button.text = "‹"
		_previous_button.tooltip_text = EventSheetL10n.translate("The page before")
		_previous_button.pressed.connect(func() -> void: turn_page(-1))
		_pager.add_child(_previous_button)
		_page_label = Label.new()
		_pager.add_child(_page_label)
		_next_button = Button.new()
		_next_button.text = "›"
		_next_button.tooltip_text = EventSheetL10n.translate("The page after")
		_next_button.pressed.connect(func() -> void: turn_page(1))
		_pager.add_child(_next_button)
		var gap: Control = Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pager.add_child(gap)
		_missing_label = Label.new()
		_pager.add_child(_missing_label)
		_open_link = LinkButton.new()
		_open_link.text = EventSheetL10n.translate("Open as a table")
		_open_link.tooltip_text = EventSheetL10n.translate("Opens this file as a table, one column per field.")
		_open_link.pressed.connect(func() -> void: open_table.call())
		_pager.add_child(_open_link)
		add_child(_pager)
		var add_line: HBoxContainer = HBoxContainer.new()
		_add_button = Button.new()
		var add_picture: Texture2D = EventSheetLookStyle.icon(&"Add")
		_add_button.text = EventSheetL10n.translate("Add row") if add_picture != null else "+ " + EventSheetL10n.translate("Add row")
		_add_button.icon = add_picture
		_add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_add_button.pressed.connect(_on_add_row)
		add_line.add_child(_add_button)
		_total_label = Label.new()
		_total_label.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
		_total_label.visible = false
		add_line.add_child(_total_label)
		add_child(add_line)
		# Any cell edit can fill or empty a cell, so the count under the grid follows every change.
		value_changed.connect(func(_rows: Array) -> void: _refresh_missing())
		_rebuild()

	func set_value(rows: Array) -> void:
		_value = []
		for row: Variant in rows:
			if row is Dictionary:
				_value.append((row as Dictionary).duplicate())
		_rebuild()

	func get_value() -> Array:
		return _value.duplicate(true)

	## Turns the share column on for `column` (a number column), or off with "".
	func set_weight_column(column: String) -> void:
		weight_column = column if is_number_column(_columns, column) else ""
		_rebuild()

	## Keeps only the rows with `text` in any cell, back on the first page.
	func search(text: String) -> void:
		_query = text
		_page = 0
		_rebuild()

	## Sorts the view by one column, the way a click on its name does: the same column again flips
	## the direction, a new number column starts with the biggest first, a new text column from A.
	## STORED_ORDER goes back to the order the file keeps.
	func sort_by(column_name: String) -> void:
		if column_name == STORED_ORDER:
			_sort_column = ""
			_descending = false
		elif column_name == _sort_column:
			_descending = not _descending
		else:
			_sort_column = column_name
			_descending = is_number_column(_columns, column_name)
		_page = 0
		_rebuild()

	func turn_page(step: int) -> void:
		_page = int(_view().get("page", 0)) + step
		_rebuild()

	## The stored indices of the rows drawn now, in the order they are drawn.
	func shown_rows() -> Array:
		return _view().get("rows", [])

	func _view() -> Dictionary:
		return view_of(_value, _columns, _query, _sort_column, _descending, _page, PAGE_SIZE)

	## What a view of `rows` shows: {rows: the stored indices on this page in drawn order, matched:
	## how many rows the search kept, page: the page drawn (clamped), pages}. Pure, so a test pins
	## what the grid draws for a search, a sort and a page without building one.
	static func view_of(rows: Array, columns: Array, query: String, sort_column: String, descending: bool,
			page: int, page_size: int) -> Dictionary:
		var needle: String = query.strip_edges().to_lower()
		var kept: Array = []
		for index: int in range(rows.size()):
			if needle.is_empty() or _row_matches(rows[index], columns, needle):
				kept.append(index)
		if not sort_column.is_empty():
			var numeric: bool = is_number_column(columns, sort_column)
			kept.sort_custom(func(a: int, b: int) -> bool:
				var order: int = _compare_cells(_cell(rows[a], sort_column), _cell(rows[b], sort_column), numeric)
				if order == 0:
					return a < b  # equal cells keep the file's order, so one sort always draws the same
				return order > 0 if descending else order < 0)
		var per_page: int = maxi(1, page_size)
		var pages: int = maxi(1, ceili(float(kept.size()) / float(per_page)))
		var shown_page: int = clampi(page, 0, pages - 1)
		return {"rows": kept.slice(shown_page * per_page, shown_page * per_page + per_page), "matched": kept.size(),
			"page": shown_page, "pages": pages}

	## "Rows 1-8 of 23" for a view, or "No row matches" when the search kept none.
	static func page_text(view: Dictionary, page_size: int) -> String:
		var matched: int = int(view.get("matched", 0))
		if matched == 0:
			return EventSheetL10n.translate("No row matches")
		var first: int = int(view.get("page", 0)) * page_size + 1
		return EventSheetL10n.translate("Rows %d-%d of %d") % [first, mini(matched, first + page_size - 1), matched]

	static func is_number_column(columns: Array, column_name: String) -> bool:
		for column: Variant in columns:
			if column is Dictionary and str((column as Dictionary).get("name", "")) == column_name:
				return str((column as Dictionary).get("type", "")) in ["int", "float"]
		return false

	## True when a cell holds nothing: a text, picture, colour or choice cell that is blank, or any
	## cell the row does not have at all. A number or a checkbox always holds something.
	static func is_empty_cell(row: Variant, column: Dictionary) -> bool:
		var value: Variant = _cell(row, str(column.get("name", "")))
		if value == null:
			return true
		if str(column.get("type", "String")) in ["int", "float", "bool"]:
			return false
		return str(value).strip_edges().is_empty()

	## How many rows have at least one empty cell.
	static func rows_with_empty_cells(rows: Array, columns: Array) -> int:
		var count: int = 0
		for row: Variant in rows:
			for column: Variant in columns:
				if column is Dictionary and is_empty_cell(row, column as Dictionary):
					count += 1
					break
		return count

	## The hover of an empty cell: which column of which row is missing, then what the column is for.
	static func empty_cell_hint(column: Dictionary, row_index: int) -> String:
		var hint: String = EventSheetL10n.translate("%s is empty in row %d.") % [str(column.get("name", "")), row_index]
		var about: String = str(column.get("about", "")).strip_edges()
		return hint if about.is_empty() else "%s\n%s" % [hint, about]

	static func _row_matches(row: Variant, columns: Array, needle: String) -> bool:
		for column: Variant in columns:
			var value: Variant = _cell(row, str((column as Dictionary).get("name", ""))) if column is Dictionary else null
			if value != null and str(value).to_lower().contains(needle):
				return true
		return false

	static func _cell(row: Variant, column_name: String) -> Variant:
		return (row as Dictionary).get(column_name) if row is Dictionary else null

	static func _compare_cells(a: Variant, b: Variant, numeric: bool) -> int:
		if numeric:
			var x: float = float(a) if a != null else 0.0
			var y: float = float(b) if b != null else 0.0
			return 0 if x == y else (-1 if x < y else 1)
		return str(a if a != null else "").naturalnocasecmp_to(str(b if b != null else ""))

	func _on_add_row() -> void:
		var fresh: Dictionary = {}
		for column: Dictionary in _columns:
			fresh[str(column.get("name"))] = _default_for(column)
		_value.append(fresh)
		# The new row is the last one the file keeps, so the file's order shows it on the last page.
		if _sort_column.is_empty() and _query.strip_edges().is_empty():
			_page = _value.size()
		_rebuild()
		value_changed.emit(get_value())

	## The starting cell value for a fresh row: the column's own Default when it has one that fits its
	## kind, else by kind - an enum column seeds its FIRST choice so a new row is valid immediately, and
	## everything else keeps its zero-ish value.
	static func _default_for(column: Dictionary) -> Variant:
		var written: String = str(column.get("default", "")).strip_edges()
		match str(column.get("type", "String")):
			"int":
				return written.to_int() if written.is_valid_int() else 0
			"float":
				return written.to_float() if written.is_valid_float() else 0.0
			"bool":
				return written == "true"
			"enum":
				# The KEY, not the label - this value is persisted into the designer's .tres the
				# moment they click Add Row, and nothing downstream re-validates a stored cell.
				var options: Array = column.get("options", []) if column.get("options") is Array else []
				var keys: Array = options.map(func(option: Variant) -> String:
					return EventSheetDrawerWidgets.sheet_compiler().table_enum_key(option))
				return written if keys.has(written) else (keys[0] if not keys.is_empty() else "")
			"color":
				return written if not written.is_empty() else "#ffffff"
		return written

	func _rebuild() -> void:
		for stale: Node in _grid.get_children():
			_grid.remove_child(stale)
			stale.queue_free()
		_cell_marks.clear()
		_share_cells.clear()
		_add_button.disabled = not editable
		_share_head = null
		_grid.columns = _grid_columns(is_roomy(size.x))
		_grid.add_child(_header(STORED_ORDER, EventSheetL10n.translate("Back to the order the file keeps")))
		for column: Dictionary in _columns:
			# The column's name exactly as the code writes it; its Description, when it has one, on hover.
			var about: String = str(column.get("about", ""))
			_grid.add_child(_header(str(column.get("name")),
				about if not about.is_empty() else EventSheetL10n.translate("Sort by %s") % str(column.get("name"))))
		if not weight_column.is_empty():
			var share_head: Label = Label.new()
			share_head.text = EventSheetL10n.translate("share")
			share_head.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
			share_head.visible = is_roomy(size.x)
			_share_head = share_head
			_grid.add_child(share_head)
		_grid.add_child(Control.new())
		var view: Dictionary = _view()
		_page = int(view.get("page", 0))
		for shown: Variant in view.get("rows", []):
			var row_index: int = int(shown)
			var row: Dictionary = _value[row_index]
			_grid.add_child(_grip(row_index))
			for column: Dictionary in _columns:
				var cell: Control = _make_cell(row, column)
				_cell_marks.append([cell, row, column, row_index])
				_grid.add_child(cell)
			if not weight_column.is_empty():
				var share_cell: Control = SHARE_CELL.new()
				share_cell.call("set_roomy", is_roomy(size.x))
				share_cell.visible = is_roomy(size.x)
				_share_cells.append([share_cell, row_index])
				_grid.add_child(share_cell)
			var remove_button: Button = EventSheetLookStyle.icon_button(&"Remove", "✕", EventSheetL10n.translate("Remove this row"))
			remove_button.disabled = not editable
			remove_button.pressed.connect(_on_remove.bind(row_index))
			_grid.add_child(remove_button)
		# The search and the pages are for long lists; a short grid stays the plain grid it was.
		var long_list: bool = _value.size() > PAGE_SIZE or not _query.is_empty()
		_search.visible = long_list
		for page_part: Control in [_previous_button, _page_label, _next_button]:
			page_part.visible = long_list
		_page_label.text = page_text(view, PAGE_SIZE)
		_previous_button.disabled = _page <= 0
		_next_button.disabled = _page >= int(view.get("pages", 1)) - 1
		_open_link.visible = open_table.is_valid()
		_missing_label.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
		_refresh_missing()

	## A column's name as a flat button: a click sorts by it, and the sorted column carries its arrow.
	func _header(column_name: String, hover: String) -> Button:
		var head: Button = Button.new()
		head.flat = true
		head.text = column_name
		if column_name == _sort_column:
			head.text += " ▼" if _descending else " ▲"
		head.tooltip_text = hover
		head.alignment = HORIZONTAL_ALIGNMENT_LEFT
		head.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
		head.pressed.connect(sort_by.bind(column_name))
		return head

	## Whether rows may be moved now: a sorted or searched view does not draw the row above or below,
	## so a move there would pass a row the reader cannot see; moving waits for the file's own, whole order.
	func can_move_rows() -> bool:
		return editable and _sort_column.is_empty() and _query.strip_edges().is_empty()

	## The handle at the start of a row: drag it onto another row's handle to move the row there. A
	## right click offers the same move one place up or down, for the keyboard and for a long list.
	func _grip(row_index: int) -> Button:
		var grip: Button = Button.new()
		grip.flat = true
		grip.focus_mode = Control.FOCUS_NONE
		var picture: Texture2D = EventSheetLookStyle.icon(&"TripleBar")
		if picture != null:
			grip.icon = picture
		else:
			grip.text = "≡"
		grip.tooltip_text = EventSheetL10n.translate("Drag to move this row.")
		grip.disabled = not can_move_rows()
		grip.mouse_default_cursor_shape = Control.CURSOR_DRAG
		grip.set_drag_forwarding(
			func(_at: Vector2) -> Variant:
				if not can_move_rows():
					return null
				var preview: Label = Label.new()
				preview.text = str(row_index)
				grip.set_drag_preview(preview)
				return {"type": "eventsheet_table_row", "from": row_index, "owner": get_instance_id()},
			func(_at: Vector2, data: Variant) -> bool:
				return can_move_rows() and data is Dictionary and str(data.get("type", "")) == "eventsheet_table_row" \
					and int(data.get("owner", 0)) == get_instance_id() and int(data.get("from", -1)) != row_index,
			func(_at: Vector2, data: Variant) -> void:
				move_row(int((data as Dictionary).get("from", -1)), row_index))
		grip.gui_input.connect(_on_grip_input.bind(grip, row_index))
		return grip

	func _on_grip_input(event: InputEvent, grip: Button, row_index: int) -> void:
		if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed \
				or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_RIGHT or not can_move_rows():
			return
		var menu: PopupMenu = PopupMenu.new()
		menu.add_item(EventSheetL10n.translate("Move this row up"), 0)
		menu.add_item(EventSheetL10n.translate("Move this row down"), 1)
		menu.set_item_disabled(0, row_index <= 0)
		menu.set_item_disabled(1, row_index >= _value.size() - 1)
		menu.id_pressed.connect(func(id: int) -> void: move_row(row_index, row_index - 1 if id == 0 else row_index + 1))
		menu.popup_hide.connect(menu.queue_free)
		grip.add_child(menu)
		EventSheetWindowPlacement.popup_at(menu, Vector2i(grip.get_screen_position() + (event as InputEventMouseButton).position))

	## Moves the row at `from` so it sits at `to`, the other rows closing up or making room.
	func move_row(from: int, to: int) -> void:
		if from < 0 or from >= _value.size() or to < 0 or to >= _value.size() or from == to:
			return
		var moved: Dictionary = _value[from]
		_value.remove_at(from)
		_value.insert(to, moved)
		_rebuild()
		value_changed.emit(get_value())

	## Paints every drawn empty cell quietly amber with its hover, and counts the rows that have one.
	func _refresh_missing() -> void:
		for mark: Variant in _cell_marks:
			var entry: Array = mark
			var cell: Control = entry[0]
			if is_instance_valid(cell):
				var empty: bool = is_empty_cell(entry[1], entry[2])
				_paint_empty(cell, empty, empty_cell_hint(entry[2], int(entry[3])) if empty else "")
		var missing: int = rows_with_empty_cells(_value, _columns)
		_missing_label.text = "" if missing == 0 else (EventSheetL10n.translate("1 row has an empty cell") if missing == 1
			else EventSheetL10n.translate("%d rows have an empty cell") % missing)
		_missing_label.visible = missing > 0
		_refresh_shares()
		# The bar under the grid shows while it has anything to say: the pages, the count or the link.
		_pager.visible = _page_label.visible or _missing_label.visible or _open_link.visible

	## Repaints every drawn row's share and the total, from the weights as they stand now.
	func _refresh_shares() -> void:
		var weighted: bool = not weight_column.is_empty()
		_total_label.visible = weighted
		if not weighted:
			return
		var math: GDScript = load("res://addons/eventsheet/editor/inspector/weight_math.gd")
		var shares: PackedFloat64Array = math.shares(_value, weight_column)
		for entry: Variant in _share_cells:
			var pair: Array = entry
			if is_instance_valid(pair[0]) and int(pair[1]) < shares.size():
				(pair[0] as Control).call("set_share", shares[int(pair[1])])
		_total_label.text = total_text(float(math.total(_value, weight_column)))

	## The widest a number column's cell will be, as text to measure: nines as long as the longest value the
	## column holds, with one more for a sign, and never fewer than four.
	static func widest_cell(rows: Array, column_name: String) -> String:
		var longest: int = 3
		for row: Variant in rows:
			var value: Variant = _cell(row, column_name)
			if value != null:
				longest = maxi(longest, str(snappedf(float(value), 0.01)).length())
		return "9".repeat(longest + 1)

	## The room a text column's cell asks for: its longest entry whole, never more than TEXT_CELL_CAP.
	static func text_cell_room(rows: Array, column_name: String) -> float:
		var widest: float = 0.0
		for row: Variant in rows:
			var value: Variant = _cell(row, column_name)
			if value != null:
				widest = maxf(widest, EventSheetLookStyle.text_room_plain(str(value)))
		return minf(widest, EventSheetLookStyle.px(TEXT_CELL_CAP))

	## True when a table this wide has room to spare for the bar in each share cell.
	static func is_roomy(width: float) -> bool:
		return width >= EventSheetLookStyle.px(ROOMY_WIDTH)

	func _notification(what: int) -> void:
		if what != NOTIFICATION_RESIZED:
			return
		_apply_roomy(is_roomy(size.x))

	## The grid's column count: the grip, the cells, the share column only while there is room, the remove button.
	func _grid_columns(roomy: bool) -> int:
		return _columns.size() + (3 if not weight_column.is_empty() and roomy else 2)

	## Shows the share column (and its bar) when the table is roomy and takes it away when it is not, so the
	## text columns keep every pixel a narrow table has; the "Chances" line above already says every share.
	func _apply_roomy(roomy: bool) -> void:
		if _grid == null:
			return
		_grid.columns = _grid_columns(roomy)
		if is_instance_valid(_share_head):
			_share_head.visible = roomy
		for entry: Variant in _share_cells:
			var cell: Object = (entry as Array)[0]
			if is_instance_valid(cell):
				cell.call("set_roomy", roomy)
				(cell as Control).visible = roomy

	## "Total weight 80" for the sum of the weights, whole when it is whole.
	static func total_text(total: float) -> String:
		var rounded: float = roundf(total)
		var number: String = str(int(rounded)) if absf(total - rounded) < 0.001 else str(snappedf(total, 0.01))
		return EventSheetL10n.translate("Total weight %s") % number

	## The field a cell is typed or picked in: the cell itself, or the text box inside a picture cell.
	static func _cell_field(cell: Control) -> Control:
		if cell is LineEdit or cell is BaseButton:
			return cell
		for child: Node in cell.get_children():
			if child is LineEdit:
				return child as Control
		return cell

	static func _paint_empty(cell: Control, empty: bool, hint: String) -> void:
		var field: Control = _cell_field(cell)
		if not field.has_meta("own_tooltip"):
			field.set_meta("own_tooltip", field.tooltip_text)
		field.tooltip_text = hint if empty else str(field.get_meta("own_tooltip"))
		if not empty:
			field.remove_theme_stylebox_override("normal")
			return
		var amber: Color = EventSheetPalette.COLOR_HEALTH_WARN
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(amber.r, amber.g, amber.b, 0.14)
		style.border_color = Color(amber.r, amber.g, amber.b, 0.55)
		style.set_border_width_all(1)
		style.set_corner_radius_all(2)
		style.set_content_margin_all(EventSheetPalette.scaled_f(4.0))
		field.add_theme_stylebox_override("normal", style)

	func _make_cell(row: Dictionary, column: Dictionary) -> Control:
		var column_name: String = str(column.get("name"))
		var column_type: String = str(column.get("type", "String"))
		match column_type:
			"int", "float":
				var spin: Range = EventSheetLookStyle.number_field("", EventSheetLookStyle.NO_COLOUR, false)
				EventSheetLookStyle.open_number_field(spin, 1.0 if column_type == "int" else 0.01)
				# A number takes the room its widest value needs; the text columns share what is left.
				spin.custom_minimum_size.x = EventSheetLookStyle.text_room(widest_cell(_value, column_name))
				spin.size_flags_horizontal = Control.SIZE_FILL
				spin.set_value_no_signal(float(row.get(column_name, 0)))
				EventSheetLookStyle.set_number_field_locked(spin, not editable)
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
			"texture":
				return _texture_cell(row, column_name)
		var edit: LineEdit = LineEdit.new()
		edit.text = str(row.get(column_name, ""))
		edit.editable = editable
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# A text cell asks for the room its longest entry in this column needs, up to a cap, so a narrow
		# table never cuts "common" to "commo" while another column keeps room it does not use.
		edit.custom_minimum_size.x = text_cell_room(_value, column_name)
		edit.text_changed.connect(func(text: String) -> void:
			row[column_name] = text
			value_changed.emit(get_value()))
		return edit

	## A picture cell: its res:// path, typed or dragged in from the FileSystem dock, with the picture
	## beside it. The row keeps the path as text, which the game turns into the picture with load().
	func _texture_cell(row: Dictionary, column_name: String) -> Control:
		var cell: HBoxContainer = HBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var preview: TextureRect = TextureRect.new()
		preview.custom_minimum_size = Vector2.ONE * EventSheetPalette.scaled_f(20.0)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.add_child(preview)
		var edit: LineEdit = LineEdit.new()
		edit.text = str(row.get(column_name, ""))
		edit.placeholder_text = "res://"
		edit.tooltip_text = EventSheetL10n.translate("A picture's path - type it, or drag the picture here from the FileSystem dock.")
		edit.editable = editable
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(edit)
		var show: Callable = func(path: String) -> void:
			preview.texture = load(path) as Texture2D if path.begins_with("res://") and ResourceLoader.exists(path) else null
		show.call(edit.text)
		edit.text_changed.connect(func(text: String) -> void:
			row[column_name] = text
			show.call(text)
			value_changed.emit(get_value()))
		edit.set_drag_forwarding(Callable(), func(_at: Vector2, data: Variant) -> bool:
			return editable and data is Dictionary and str(data.get("type", "")) == "files" and (data.get("files", []) as Array).size() == 1,
			func(_at: Vector2, data: Variant) -> void:
				edit.text = str(data["files"][0])
				edit.text_changed.emit(edit.text))
		return cell

	func _on_move_up(row_index: int) -> void:
		move_row(row_index, row_index - 1)

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
		custom_minimum_size = Vector2(0.0, EventSheetLookStyle.px(EventSheetLookStyle.DIAL_HEIGHT))
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = EventSheetL10n.translate("Drag the handle to set direction + magnitude")

	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED:
			custom_minimum_size = Vector2(0.0, EventSheetLookStyle.px(EventSheetLookStyle.DIAL_HEIGHT))
			queue_redraw()

	func set_value(v: Vector2) -> void:
		_value = v
		queue_redraw()

	func get_value() -> Vector2:
		return _value

	func _radius() -> float:
		return minf(EventSheetLookStyle.px(EventSheetLookStyle.DIAL_RING) * 0.5, maxf(8.0, size.y * 0.5 - EventSheetLookStyle.px(8.0)))

	## The middle of the ring: it sits a little below the top edge, and the reach label sits under it.
	func _center() -> Vector2:
		return Vector2(size.x * 0.5, EventSheetLookStyle.px(8.0) + _radius())

	func _draw() -> void:
		draw_style_box(EventSheetLookStyle.field_box(), Rect2(Vector2.ZERO, size))
		var quiet: Color = EventSheetLookStyle.quiet()
		var accent: Color = EventSheetLookStyle.accent()
		var c: Vector2 = _center()
		var r: float = _radius()
		draw_arc(c, r, 0.0, TAU, 48, quiet, 1.0, true)
		var disp: Vector2 = (_value / max_magnitude) * r
		if disp.length() > r:
			disp = disp.normalized() * r
		var handle: Vector2 = c + disp
		draw_line(c, handle, accent, EventSheetLookStyle.px(EventSheetLookStyle.LINE_WIDTH), true)
		draw_circle(handle, EventSheetLookStyle.px(EventSheetLookStyle.DIAL_HANDLE) * 0.5, accent)
		var font: Font = EventSheetLookStyle.font()
		var font_size: int = EventSheetLookStyle.font_size()
		var label: String = EventSheetL10n.translate("reach %s") % _reach_text()
		var baseline: float = size.y - EventSheetLookStyle.px(3.0) - font.get_descent(font_size)
		draw_string(font, Vector2(0.0, baseline), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, quiet)

	func _reach_text() -> String:
		return str(int(max_magnitude)) if is_equal_approx(max_magnitude, roundf(max_magnitude)) else str(snappedf(max_magnitude, 0.01))

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
## A row of palette presets plus a full picker - click a swatch (or pick) to set the colour fast. The
## swatches fill the value column at the height of a field, wrapping to a second line when the column
## is too narrow for them to stay clickable; the chosen one carries a tick.
class DrawerSwatchRow:
	extends GridContainer
	signal value_changed(value: Color)
	## The narrowest one swatch may be, at 1x.
	const SWATCH_WIDTH: float = 16.0
	var editable: bool = true
	var _value: Color = Color.WHITE
	var _picker: ColorPickerButton = null
	var _swatches: Array[Button] = []
	var _presets: Array[Color] = []

	func _init() -> void:
		columns = EventSheetDrawerWidgets.SWATCH_PRESET_HTML.size() + 1
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for preset_html: String in EventSheetDrawerWidgets.SWATCH_PRESET_HTML:
			var preset: Color = Color.html(preset_html)
			_presets.append(preset)
			var swatch: Button = _make_swatch(preset)
			_swatches.append(swatch)
			add_child(swatch)
		_picker = ColorPickerButton.new()
		_picker.custom_minimum_size = Vector2(0.0, EventSheetLookStyle.field_height())
		for state: String in ["normal", "hover", "pressed"]:
			_picker.add_theme_stylebox_override(state, _picker_box())
		_picker.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_picker.color = _value
		_picker.tooltip_text = EventSheetL10n.translate("Custom colour…")
		_picker.color_changed.connect(_on_picked)
		add_child(_picker)
		custom_minimum_size.x = EventSheetLookStyle.px(SWATCH_WIDTH)
		_show_tick()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			# As many to a line as keep each one a real click target; the rest wrap.
			var fit: int = maxi(1, int(size.x / EventSheetLookStyle.px(SWATCH_WIDTH)))
			columns = mini(fit, EventSheetDrawerWidgets.SWATCH_PRESET_HTML.size() + 1)

	## The width at which every swatch stays a real click target on one line.
	func width_for_one_line() -> float:
		return EventSheetLookStyle.px(SWATCH_WIDTH) * float(EventSheetDrawerWidgets.SWATCH_PRESET_HTML.size() + 1)

	func set_value(v: Color) -> void:
		_value = v
		if _picker != null:
			_picker.color = v
		_show_tick()

	func get_value() -> Color:
		return _value

	## The swatch whose preset is the colour now, or -1 when it is none of them (a picked colour).
	func chosen_index() -> int:
		for index: int in _presets.size():
			if _presets[index].is_equal_approx(_value):
				return index
		return -1

	## The box the custom-colour button wears: the editor's field box with a thin margin, so the colour it
	## shows has room to be seen at a swatch's width.
	func _picker_box() -> StyleBox:
		var box: StyleBox = EventSheetLookStyle.field_box()
		box.set_content_margin_all(EventSheetLookStyle.px(2.0))
		return box

	func _make_swatch(preset: Color) -> Button:
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(0.0, EventSheetLookStyle.field_height())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "#" + preset.to_html(false)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sb: StyleBoxFlat = EventSheetLookStyle.field_box() as StyleBoxFlat
		if sb == null:
			sb = StyleBoxFlat.new()
		sb.bg_color = preset
		# A swatch close to the field colour gets a neutral hairline so it never vanishes into it.
		if EventSheetLookStyle.contrast_ratio(Color(preset, 1.0), EventSheetLookStyle.field_fill()) < 1.6:
			sb.set_border_width_all(1)
			sb.border_color = EventSheetLookStyle.rest()
		sb.content_margin_left = 0.0
		sb.content_margin_right = 0.0
		for state: String in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, sb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(func() -> void: _apply(preset))
		return b

	## Puts the tick on the chosen swatch: the editor's own check mark, in whichever of dark and light
	## reads better on that swatch.
	func _show_tick() -> void:
		var chosen: int = chosen_index()
		for index: int in _swatches.size():
			var swatch: Button = _swatches[index]
			swatch.icon = null
			swatch.text = ""
			if index != chosen:
				continue
			var tick: Color = EventSheetLookStyle.ink_over(_presets[index])
			for item: String in ["font_color", "font_hover_color", "font_pressed_color"]:
				swatch.add_theme_color_override(item, tick)
			swatch.text = "✓"
			swatch.add_theme_font_override("font", EventSheetLookStyle.bold_font())

	func _apply(c: Color) -> void:
		if not editable:
			return
		set_value(c)
		value_changed.emit(c)

	func _on_picked(c: Color) -> void:
		if not editable:
			return
		_value = c
		_show_tick()
		value_changed.emit(c)


# ── Texture / sprite preview ────────────────────────────────────────────────
## A read-friendly picture of a Texture2D (or a texture path): the picture centred on the checkerboard
## Godot uses for transparency, large enough to judge, with its size in pixels under it. Display-only:
## the picker sits above it in the Inspector, and the dialog preview just shows a placeholder frame.
class DrawerTexturePreview:
	extends VBoxContainer
	var _texture: Texture2D = null
	var _picture: TexturePicture = null
	var _size_line: Label = null

	func _init() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_picture = TexturePicture.new()
		add_child(_picture)
		_size_line = Label.new()
		_size_line.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
		add_child(_size_line)
		set_texture(null)

	func set_texture(t: Texture2D) -> void:
		_texture = t
		_picture.set_texture(t)
		_size_line.text = "" if t == null else "%d x %d px" % [t.get_width(), t.get_height()]
		_size_line.visible = t != null

	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED and _size_line != null:
			_size_line.add_theme_color_override("font_color", EventSheetLookStyle.quiet())


## The framed picture of a texture preview: a checkerboard panel with the picture centred on it.
class TexturePicture:
	extends Control
	var _texture: Texture2D = null

	func _init() -> void:
		custom_minimum_size = Vector2(0.0, EventSheetLookStyle.px(EventSheetLookStyle.PICTURE_HEIGHT))
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_texture(t: Texture2D) -> void:
		_texture = t
		queue_redraw()

	func _draw() -> void:
		var frame: Rect2 = Rect2(Vector2.ZERO, size)
		var box: StyleBox = EventSheetLookStyle.field_box()
		draw_style_box(box, frame)
		var inner: Rect2 = frame.grow(-1.0)
		var checker: Texture2D = EventSheetLookStyle.icon(&"Checkerboard")
		if checker != null:
			draw_texture_rect(checker, inner, true)
		else:
			var chrome: EventSheetChromeStyle = EventSheetActiveTheme.chrome()
			var cell: float = EventSheetLookStyle.px(8.0)
			for row: int in int(ceil(inner.size.y / cell)):
				for column: int in int(ceil(inner.size.x / cell)):
					var shade: Color = chrome.drawer_checker_dark_color if (row + column) % 2 == 0 else chrome.drawer_checker_light_color
					var piece: Rect2 = Rect2(inner.position + Vector2(column, row) * cell, Vector2(cell, cell)).intersection(inner)
					draw_rect(piece, shade, true)
		if _texture != null:
			var natural: Vector2 = _texture.get_size()
			if natural.x > 0.0 and natural.y > 0.0:
				var room: Rect2 = inner.grow(-EventSheetLookStyle.px(6.0))
				var scale: float = minf(room.size.x / natural.x, room.size.y / natural.y)
				var shown: Vector2 = natural * scale
				draw_texture_rect(_texture, Rect2(room.position + (room.size - shown) * 0.5, shown), false)
		else:
			var font: Font = EventSheetLookStyle.font()
			var font_size: int = EventSheetLookStyle.font_size()
			var word: String = EventSheetL10n.translate("(no texture)")
			draw_string(font, Vector2(0.0, (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5), word, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, EventSheetLookStyle.quiet())


# ── Curve preview ───────────────────────────────────────────────────────────
## Renders a Curve's shape inline: a field-coloured panel with a half-way grid, the curve as a line in
## the accent, and the 0 and 1 of its range marked. A click asks to open the curve in Godot's own curve
## editor, exactly as a click on the slot does. With no curve in the slot it says "empty" and draws nothing.
class DrawerCurvePreview:
	extends Control
	## A click on the picture: the look hands the curve to the Inspector so Godot's curve editor opens.
	signal pressed
	var _curve: Curve = null

	func _init() -> void:
		custom_minimum_size = Vector2(0.0, EventSheetLookStyle.px(EventSheetLookStyle.CURVE_HEIGHT))
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_curve(c: Curve) -> void:
		_curve = c
		tooltip_text = EventSheetL10n.translate("Click to open the curve editor.") if c != null and mouse_filter == Control.MOUSE_FILTER_STOP else ""
		queue_redraw()

	## Lets a click on the picture raise `pressed`; a card keeps the picture a plain display.
	func make_clickable() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		set_curve(_curve)

	func _gui_input(event: InputEvent) -> void:
		if _curve != null and event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()

	func _draw() -> void:
		var frame: Rect2 = Rect2(Vector2.ZERO, size)
		draw_style_box(EventSheetLookStyle.field_box(), frame)
		var quiet: Color = EventSheetLookStyle.quiet()
		var font: Font = EventSheetLookStyle.font()
		var font_size: int = EventSheetLookStyle.font_size()
		# An empty slot draws nothing but the word "empty": a sample curve here would read as a curve
		# that exists.
		if _curve == null:
			var word: String = EventSheetL10n.translate("empty")
			var word_width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
			draw_string(font, Vector2((size.x - word_width) * 0.5, (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5), word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, quiet)
			return
		var rest: Color = EventSheetLookStyle.rest()
		draw_line(Vector2(0.0, size.y * 0.5), Vector2(size.x, size.y * 0.5), rest, 1.0)
		draw_line(Vector2(size.x * 0.5, 0.0), Vector2(size.x * 0.5, size.y), rest, 1.0)
		var inset: float = EventSheetLookStyle.px(6.0)
		var inner_w: float = maxf(1.0, size.x - inset * 2.0)
		var inner_h: float = maxf(1.0, size.y - inset * 2.0)
		var samples: int = 48
		var points: PackedVector2Array = PackedVector2Array()
		for i: int in range(samples + 1):
			var t: float = float(i) / float(samples)
			var y: float = inset + (1.0 - clampf(_curve.sample_baked(t), 0.0, 1.0)) * inner_h
			points.append(Vector2(inset + t * inner_w, y))
		draw_polyline(points, EventSheetLookStyle.accent(), EventSheetLookStyle.px(EventSheetLookStyle.LINE_WIDTH), true)
		draw_string(font, Vector2(EventSheetLookStyle.px(5.0), EventSheetLookStyle.px(3.0) + font.get_ascent(font_size)), "1", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, quiet)
		draw_string(font, Vector2(EventSheetLookStyle.px(5.0), size.y - EventSheetLookStyle.px(3.0) - font.get_descent(font_size)), "0", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, quiet)


## A word picked from the list a function of the script gives: a described dropdown. The file stores
## the plain word, so events and exported games read it as they always did.
class ChoicesProperty:
	extends EditorProperty
	var _field: Control

	func _init(function_name: String) -> void:
		_field = ChoicesField.new(function_name)
		_field.connect("value_changed", _on_changed)
		add_child(_field)
		add_focusable(_field)

	func _on_changed(word: String) -> void:
		var is_name: bool = typeof(get_edited_object().get(get_edited_property())) == TYPE_STRING_NAME
		emit_changed(get_edited_property(), StringName(word) if is_name else word)

	func _update_property() -> void:
		_field.call("show_choices", get_edited_object(), str(get_edited_object().get(get_edited_property())))


## Two numbers on one line - min and max, width and height - each with its own name, as the pair
## reads in the file. One label sits on the left, as for any other property, and each field carries its
## own name inside it. Each edit is written to its own property, so undo takes back the one that moved.
class SideBySideProperty:
	extends EditorProperty
	const SIZE_NOTES: GDScript = preload("res://addons/eventsheet/editor/inspector/size_notes.gd")
	var _names: PackedStringArray = PackedStringArray()
	var _shared_label: String = ""
	var _spins: Array[Range] = []
	## The two things the row wraps: each field with whatever travels beside it.
	var _units: Array[HBoxContainer] = []
	## The words each field carries inside it.
	var _inner: Array = []
	var _row: HFlowContainer = null
	var _linked: bool = false
	var _link: Control = null
	var _notes: Control = null
	var _notes_margin: MarginContainer = null
	## True for a pair that is a texture's width and height: the label ends in "Size" and an "x" sits between.
	var _texture: bool = false

	## `linked` puts the ratio button inside the row; `texture` and `sizes` put the common sizes and the
	## cost under it.
	func _init(first: String, second: String, linked: bool = false, texture: bool = false, sizes: PackedInt32Array = PackedInt32Array()) -> void:
		_names = PackedStringArray([first, second])
		_linked = linked
		_texture = texture
		var parts: Dictionary = name_parts(first, second)
		_shared_label = (EventSheetL10n.translate("%s Size") % str(parts["label"])) if texture else str(parts["label"])
		var inner: Array = parts["inner"]
		_inner = inner
		var row: HFlowContainer = HFlowContainer.new()
		_row = row
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if texture:
			_notes = SIZE_NOTES.new(sizes)
			_notes.connect("size_picked", _on_size_picked)
			_notes_margin = MarginContainer.new()
			_notes_margin.add_theme_constant_override("margin_top", int(EventSheetLookStyle.px(3.0)))
			_notes_margin.add_child(_notes)
		for index: int in _names.size():
			var property_name: String = _names[index]
			var spin: Range = EventSheetLookStyle.number_field(str(inner[index]), EventSheetLookStyle.quiet(), false)
			spin.custom_minimum_size.x = EventSheetLookStyle.text_room_plain("%s 9999" % str(inner[index]))
			EventSheetLookStyle.open_number_field(spin, 0.001)
			spin.tooltip_text = property_name
			spin.value_changed.connect(_on_changed.bind(property_name))
			var unit: HBoxContainer = wrap_unit(spin)
			row.add_child(unit)
			_units.append(unit)
			add_focusable(spin)
			_spins.append(spin)
			if texture and index == 0:
				var times: Label = Label.new()
				times.text = "x"
				times.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
				unit.add_child(times)
		add_child(row)
		draw_background = false
		if _notes_margin != null:
			add_child(_notes_margin)
			set_bottom_editor(_notes_margin)
			sort_children.connect(_align_notes)
			draw.connect(_align_notes)

	## The widest a field's number will be, as text to measure: nines as long as the longest of the range's
	## limits and the number it holds now (a sign counts when the number can go below zero). A field is
	## as wide as that needs, so a pair does not ask the Inspector for more room than its numbers use.
	static func widest_number(declared: Dictionary, value: float, is_int: bool) -> String:
		var longest: int = maxi(4, str(int(absf(value))).length())
		var signed: bool = value < 0.0
		if not declared.is_empty():
			longest = maxi(longest, str(int(absf(float(declared["max"])))).length())
			longest = maxi(longest, str(int(absf(float(declared["min"])))).length())
			signed = signed or float(declared["min"]) < 0.0
		return ("-" if signed else "") + "9".repeat(longest) + ("" if is_int else ".9")

	## One thing the row wraps: a field, with whatever travels beside it (the "x" after the width, the link
	## after the height) added to the unit later. The row wraps whole units, so a lone "x" or a lone link
	## never lands on a line by itself: side by side while the Inspector has room, one unit under the
	## other when it truly has not.
	static func wrap_unit(field: Control) -> HBoxContainer:
		var unit: HBoxContainer = HBoxContainer.new()
		unit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unit.add_child(field)
		return unit

	## The range an @export_range property declares, as {min, max, step, or_greater, or_less}, or {} for a
	## property with none. Read from the object's own property list, so a pair never loses its clamp.
	static func range_of(object: Object, property: String) -> Dictionary:
		if object == null:
			return {}
		for info: Dictionary in object.get_property_list():
			if str(info.get("name", "")) != property or int(info.get("hint", PROPERTY_HINT_NONE)) != PROPERTY_HINT_RANGE:
				continue
			return range_spec(str(info.get("hint_string", "")))
		return {}

	## "1,2048,1,or_greater" -> {min: 1.0, max: 2048.0, step: 1.0, or_greater: true, or_less: false}.
	static func range_spec(hint_string: String) -> Dictionary:
		var parts: PackedStringArray = hint_string.split(",")
		var spec: Dictionary = {"min": 0.0, "max": 100.0, "step": 0.0, "or_greater": false, "or_less": false}
		if parts.size() > 0 and parts[0].strip_edges().is_valid_float():
			spec["min"] = parts[0].strip_edges().to_float()
		if parts.size() > 1 and parts[1].strip_edges().is_valid_float():
			spec["max"] = parts[1].strip_edges().to_float()
		if parts.size() > 2 and parts[2].strip_edges().is_valid_float():
			spec["step"] = parts[2].strip_edges().to_float()
		for flag: String in parts:
			spec["or_greater"] = bool(spec["or_greater"]) or flag.strip_edges() == "or_greater"
			spec["or_less"] = bool(spec["or_less"]) or flag.strip_edges() == "or_less"
		return spec

	## Gives a spin the limits its property declares. A spin with none stays open, as an unranged number is.
	static func apply_range(spin: Range, spec: Dictionary, is_int: bool) -> void:
		if spec.is_empty():
			return
		spin.min_value = float(spec["min"])
		spin.max_value = float(spec["max"])
		spin.allow_greater = bool(spec["or_greater"])
		spin.allow_lesser = bool(spec["or_less"])
		spin.step = float(spec["step"]) if float(spec["step"]) > 0.0 else (1.0 if is_int else 0.001)

	func _align_notes() -> void:
		# The sizes and the cost start where the fields do: the label column's width in from the left.
		var left: int = EventSheetInspectorLook.under_field_margin(size.x, _row.size.x)
		if _notes_margin.get_theme_constant("margin_left") != left:
			_notes_margin.add_theme_constant_override("margin_left", left)

	## One click on a size writes both numbers as one undo step.
	func _on_size_picked(picked: int) -> void:
		var object: Object = get_edited_object()
		if object == null:
			return
		var manager: Object = EventSheetDrawerWidgets.editor_undo_redo()
		if manager == null:
			for property_name: String in _names:
				object.set(property_name, picked)
			_update_property()
			return
		manager.call("create_action", EventSheetL10n.translate("Set both to %d.") % picked)
		for property_name: String in _names:
			manager.call("add_do_property", object, property_name, picked)
			manager.call("add_undo_property", object, property_name, object.get(property_name))
		manager.call("commit_action")

	## The label the pair shares and the words each field carries inside it. `margin_left` and
	## `margin_right` are "Margin" with "left" and "right" inside; names with nothing in common keep
	## the first name as the label and their full names inside the fields.
	static func name_parts(first: String, second: String) -> Dictionary:
		var common: int = 0
		while common < first.length() and common < second.length() and first[common] == second[common]:
			common += 1
		var prefix_end: int = first.substr(0, common).rfind("_") + 1
		if prefix_end > 0 and prefix_end < first.length() and prefix_end < second.length():
			return {"label": first.substr(0, prefix_end - 1).capitalize(), "inner": [first.substr(prefix_end), second.substr(prefix_end)]}
		var tail: int = 0
		while tail < first.length() and tail < second.length() and first[first.length() - 1 - tail] == second[second.length() - 1 - tail]:
			tail += 1
		var tail_text: String = first.substr(first.length() - tail)
		var suffix_start: int = tail_text.find("_")
		if suffix_start >= 0 and suffix_start + 1 < tail_text.length() and first.length() - tail + suffix_start > 0 and second.length() - tail + suffix_start > 0:
			var cut: int = tail - suffix_start
			return {"label": tail_text.substr(suffix_start + 1).capitalize(),
				"inner": [first.substr(0, first.length() - cut), second.substr(0, second.length() - cut)]}
		return {"label": first.capitalize(), "inner": [first, second]}

	func _on_changed(value: float, property_name: String) -> void:
		var is_int: bool = typeof(get_edited_object().get(property_name)) == TYPE_INT
		emit_changed(property_name, int(round(value)) if is_int else value)

	func _notification(what: int) -> void:
		# The Inspector hands every editor its own label after _init; here it is the pair's shared one.
		if what == NOTIFICATION_READY:
			draw_label = true
			label = _shared_label

	func _update_property() -> void:
		if _linked and _link == null:
			_link = LinkToggle.new(get_edited_object(), _names[0], _names[1], true)
			_units[_units.size() - 1].add_child(_link)
			add_focusable(_link.get_child(0))
		for index: int in _names.size():
			var value: Variant = get_edited_object().get(_names[index])
			var is_int: bool = typeof(value) == TYPE_INT
			var declared: Dictionary = range_of(get_edited_object(), _names[index])
			_spins[index].step = 1.0 if is_int else 0.001
			_spins[index].rounded = is_int
			apply_range(_spins[index], declared, is_int)
			_spins[index].set_value_no_signal(float(value))
			_spins[index].custom_minimum_size.x = EventSheetLookStyle.text_room_plain("%s %s" % [_inner[index], widest_number(declared, float(value), is_int)])
			EventSheetLookStyle.set_number_field_locked(_spins[index], read_only)
		if _notes != null:
			_notes.call("show_pair", int(get_edited_object().get(_names[0])), int(get_edited_object().get(_names[1])))
