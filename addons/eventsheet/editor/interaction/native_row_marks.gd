@tool
extends RefCounted
# Godot EventSheets - the small DRAWN marks of an event row: the trigger icon beside the event's
# number, the System and input device glyphs in the object column, the hairline after the object
# column, the grip on the hovered event's lane divider, and the word colour a variable name wears
# inside a condition or action sentence.
#
# Every mark here is PAINT ONLY. None of them is a span, none reserves width, none is measured and
# none is hit-tested as a cell - the virtualized canvas draws them on top of the geometry the row
# already has, so no span, no row height and no reading moves when they are switched on or off.
# Where a mark has a meaning a reader may not guess (the trigger icon), the meaning lives in the
# canvas tooltip, never in text inside the row.
#
# Static and stateless apart from two small caches (the editor icons, looked up once), so the
# renderer, the tooltip and the suite can all ask the same function the same question.

## The trigger kinds an icon is drawn for. An event with no trigger of its own (a sub-event, an
## Else block, a plain condition event) draws none.
const TRIGGER_READY := "ready"
const TRIGGER_TICK := "tick"
const TRIGGER_PHYSICS := "physics"
const TRIGGER_INPUT := "input"
const TRIGGER_SIGNAL := "signal"
const TRIGGER_OTHER := "other"

## The editor's own icon for a trigger kind, where Godot ships one that means exactly that (each
## name checked with has_icon in a running editor). A kind with no entry, or a run with no editor
## theme (headless, a measure), is drawn as a vector glyph instead. Input has none on purpose: the
## editor's `Keyboard` icon is a key-label badge, which at this size does not read as a keyboard.
const TRIGGER_EDITOR_ICONS: Dictionary = {
	TRIGGER_READY: "Play",
	TRIGGER_TICK: "Reload",
	TRIGGER_SIGNAL: "Signal",
	TRIGGER_OTHER: "Notification",
}

## The physics-step triggers: every tick, but the physics tick. Read off the id, because the tempo
## class the badge column uses folds both ticks into one.
const PHYSICS_TRIGGER_IDS: PackedStringArray = [
	"OnPhysicsProcess", "OnPhysicsPostTick", "OnLanded", "OnLanded3D", "OnLeftTheGround",
	"OnLeftTheGround3D",
]

## The side of a trigger icon, and the slot it is centred in: the 18 px every event row reserves
## between the margin and its condition lane (the old row-type glyph's place, kept so no geometry
## moved when that glyph went).
const TRIGGER_ICON_SIZE := 14.0
const TRIGGER_ICON_SLOT := 18.0

## The object labels that draw a glyph of their own in place of their category icon: System, and
## the input devices an event sheet treats as objects. Always DRAWN, in the object ink: Godot ships
## no gear, and its device icons are class icons in their own colours, so one drawn family is what
## lets the catch-all objects read alike on every row.
const OBJECT_GLYPH_SYSTEM := "system"
const OBJECT_GLYPH_KEYBOARD := "keyboard"
const OBJECT_GLYPH_MOUSE := "mouse"
const OBJECT_GLYPH_GAMEPAD := "gamepad"
const OBJECT_GLYPH_TOUCH := "touch"
const OBJECT_GLYPHS: Dictionary = {
	"System": OBJECT_GLYPH_SYSTEM,
	"Keyboard": OBJECT_GLYPH_KEYBOARD,
	"Mouse": OBJECT_GLYPH_MOUSE,
	"Gamepad": OBJECT_GLYPH_GAMEPAD,
	"Touch": OBJECT_GLYPH_TOUCH,
	"Input": OBJECT_GLYPH_KEYBOARD,
}

## How far the object hairline stays off the top and bottom of its cell, so it reads as a divider
## between the name and the sentence rather than as a cell border.
const HAIRLINE_INSET := 5.0

## The lane divider's grip: three dots, this far apart, on a divider at least this wide.
const GRIP_DOT_SPACING := 6.0
const GRIP_MIN_DIVIDER_WIDTH := 3.0

## The luminance under which a selected gutter's fill takes white ink rather than near-black.
const SELECTED_INK_LUMINANCE := 0.6
## The two contrast inks, chosen between here and on a variable row's tick box alike.
const NativeVariableMarks := preload("res://addons/eventsheet/editor/interaction/native_variable_marks.gd")

## The word-range kind a variable name inside a sentence is stamped with.
const WORD_VARIABLE := "variable"

static var _editor_icon_cache: Dictionary = {}


## The trigger kind of an event row, or "" when it draws no trigger icon. Classified the way the
## tempo badge is (TriggerResolver.tempo_class_for), with the physics tick told apart from the
## process tick and an engine notification told apart from a signal.
static func trigger_kind(row_data: EventRowData) -> String:
	if row_data == null or row_data.row_type != EventRowData.RowType.EVENT:
		return ""
	var event_row: EventRow = row_data.source_resource as EventRow
	if event_row == null or event_row.else_mode != EventRow.ElseMode.NONE:
		return ""
	if ViewportRowBuilder.is_input_trigger_tick(event_row):
		return TRIGGER_INPUT
	return trigger_kind_for_id(event_row.trigger_id)


## The kind for a bare trigger id - "" for an event with none.
static func trigger_kind_for_id(trigger_id: String) -> String:
	if trigger_id.is_empty():
		return ""
	match TriggerResolver.tempo_class_for(trigger_id):
		TriggerResolver.TEMPO_ONCE:
			return TRIGGER_READY
		TriggerResolver.TEMPO_INPUT:
			return TRIGGER_INPUT
		TriggerResolver.TEMPO_EVERY_TICK:
			return TRIGGER_PHYSICS if PHYSICS_TRIGGER_IDS.has(trigger_id) else TRIGGER_TICK
	if trigger_id.begins_with(TriggerResolver.NOTIFICATION_PREFIX):
		return TRIGGER_OTHER
	return TRIGGER_SIGNAL


## What a trigger icon means, for its hover.
static func trigger_tooltip(kind: String) -> String:
	match kind:
		TRIGGER_READY:
			return EventSheetL10n.translate("Runs once, when the node starts (On ready).")
		TRIGGER_TICK:
			return EventSheetL10n.translate("Runs every frame (Every tick).")
		TRIGGER_PHYSICS:
			return EventSheetL10n.translate("Runs every physics step (Every physics tick).")
		TRIGGER_INPUT:
			return EventSheetL10n.translate("Runs when input arrives - a key, a button, the mouse.")
		TRIGGER_SIGNAL:
			return EventSheetL10n.translate("Runs when a signal is emitted.")
		TRIGGER_OTHER:
			return EventSheetL10n.translate("Runs when the engine sends this notification.")
	return ""


## Where an event's trigger icon is drawn: centred in the slot every event row reserves right of
## its margin, at the height of the event number (which the margin centres on the row).
static func trigger_icon_rect(row_rect: Rect2, indent: int, indent_width: int) -> Rect2:
	var slot_x: float = row_rect.position.x + EventSheetPalette.ROW_HORIZONTAL_PADDING \
		+ float(EventSheetPalette.GUTTER_WIDTH) + float(indent * indent_width)
	var centre_y: float = row_rect.position.y + row_rect.size.y * 0.5
	var inset: float = (TRIGGER_ICON_SLOT - TRIGGER_ICON_SIZE) * 0.5
	return Rect2(slot_x + inset, centre_y - TRIGGER_ICON_SIZE * 0.5, TRIGGER_ICON_SIZE, TRIGGER_ICON_SIZE)


## Paints one trigger icon: the editor's own icon tinted `color` where Godot ships one for the kind,
## else the drawn glyph.
static func draw_trigger_icon(control: CanvasItem, rect: Rect2, kind: String, color: Color) -> void:
	var icon: Texture2D = _editor_icon(str(TRIGGER_EDITOR_ICONS.get(kind, "")))
	if icon != null:
		control.draw_texture_rect(icon, rect, false, color)
		return
	var stroke: float = maxf(rect.size.x / 16.0 * 1.4, 1.0)
	match kind:
		TRIGGER_READY:
			control.draw_colored_polygon(PackedVector2Array([
				_at(rect, 5.0, 3.5), _at(rect, 5.0, 12.5), _at(rect, 12.0, 8.0)]), color)
		TRIGGER_TICK:
			control.draw_arc(_at(rect, 8.0, 8.0), _units(rect, 5.0), 0.0, TAU - 0.8, 24, color, stroke, true)
			control.draw_polyline(PackedVector2Array([
				_at(rect, 13.0, 2.5), _at(rect, 13.0, 5.5), _at(rect, 10.0, 5.5)]), color, stroke, true)
		TRIGGER_PHYSICS:
			control.draw_arc(_at(rect, 8.0, 9.0), _units(rect, 4.5), 0.0, TAU, 24, color, stroke, true)
			control.draw_line(_at(rect, 8.0, 1.5), _at(rect, 8.0, 4.5), color, stroke, true)
			control.draw_polyline(PackedVector2Array([
				_at(rect, 6.0, 3.0), _at(rect, 8.0, 4.8), _at(rect, 10.0, 3.0)]), color, stroke, true)
		TRIGGER_INPUT:
			_draw_keyboard(control, rect, color, stroke)
		TRIGGER_SIGNAL:
			control.draw_circle(_at(rect, 4.0, 8.0), _units(rect, 1.8), color)
			control.draw_arc(_at(rect, 4.0, 8.0), _units(rect, 4.5), -0.85, 0.85, 12, color, stroke, true)
			control.draw_arc(_at(rect, 4.0, 8.0), _units(rect, 8.0), -0.75, 0.75, 16, color, stroke, true)
		TRIGGER_OTHER:
			control.draw_arc(_at(rect, 8.0, 8.0), _units(rect, 5.0), 0.0, TAU, 24, color, stroke, true)
			control.draw_circle(_at(rect, 8.0, 8.0), _units(rect, 1.6), color)


## The ink that reads on `fill`: white on a dark or saturated fill (the design's selected blue), a
## near-black on a pale one. What a selected gutter's number and trigger icon are drawn in.
static func ink_on(fill: Color) -> Color:
	return NativeVariableMarks.contrast_ink(fill, SELECTED_INK_LUMINANCE)


## Where a selected event's filled margin continues past the 20 px gutter: from the gutter's edge
## across the trigger icon's slot for an event at the left edge, so the number and the icon sit on
## one fill; for a nested event only the slot itself, and only when an icon is drawn in it, so the
## indent guides between keep their place. An empty rect means nothing more is filled.
static func selected_slot_rect(gutter_rect: Rect2, row_rect: Rect2, indent: int, indent_width: int,
		has_icon: bool) -> Rect2:
	var slot_x: float = row_rect.position.x + EventSheetPalette.ROW_HORIZONTAL_PADDING \
		+ float(EventSheetPalette.GUTTER_WIDTH) + float(indent * indent_width)
	if indent <= 0:
		return Rect2(gutter_rect.end.x, row_rect.position.y, slot_x + TRIGGER_ICON_SLOT - gutter_rect.end.x,
			row_rect.size.y)
	if not has_icon:
		return Rect2()
	return Rect2(slot_x, row_rect.position.y, TRIGGER_ICON_SLOT, row_rect.size.y)


## The glyph an object label draws in place of its icon, or "" for one that keeps its icon.
static func object_glyph_for(object_label: String) -> String:
	return str(OBJECT_GLYPHS.get(object_label, ""))


## Paints an object glyph inside the icon box `rect`.
static func draw_object_glyph(control: CanvasItem, rect: Rect2, glyph: String, color: Color) -> void:
	var stroke: float = maxf(rect.size.x / 16.0 * 1.3, 1.0)
	match glyph:
		OBJECT_GLYPH_SYSTEM:
			control.draw_arc(_at(rect, 8.0, 8.0), _units(rect, 2.2), 0.0, TAU, 16, color, stroke, true)
			for spoke: int in range(8):
				var angle: float = float(spoke) * TAU / 8.0
				var direction := Vector2(cos(angle), sin(angle))
				control.draw_line(_at(rect, 8.0, 8.0) + direction * _units(rect, 4.2),
					_at(rect, 8.0, 8.0) + direction * _units(rect, 6.2), color, stroke, true)
		OBJECT_GLYPH_MOUSE:
			control.draw_rect(Rect2(_at(rect, 4.5, 1.5), Vector2(_units(rect, 7.0), _units(rect, 13.0))), color, false, stroke)
			control.draw_line(_at(rect, 8.0, 1.5), _at(rect, 8.0, 6.0), color, stroke, true)
		OBJECT_GLYPH_GAMEPAD:
			control.draw_rect(Rect2(_at(rect, 1.5, 4.5), Vector2(_units(rect, 13.0), _units(rect, 7.5))), color, false, stroke)
			control.draw_line(_at(rect, 3.5, 8.25), _at(rect, 6.5, 8.25), color, stroke, true)
			control.draw_line(_at(rect, 5.0, 6.75), _at(rect, 5.0, 9.75), color, stroke, true)
			control.draw_circle(_at(rect, 10.5, 7.5), _units(rect, 0.9), color)
			control.draw_circle(_at(rect, 12.0, 9.2), _units(rect, 0.9), color)
		OBJECT_GLYPH_TOUCH:
			control.draw_circle(_at(rect, 8.0, 8.0), _units(rect, 2.0), color)
			control.draw_arc(_at(rect, 8.0, 8.0), _units(rect, 5.5), 0.0, TAU, 24, color, stroke, true)
		_:
			_draw_keyboard(control, rect, color, stroke)


## The hairline between an object column and the sentence after it, on the column's boundary.
## Inset from the cell's top and bottom on a cell tall enough to show it inset.
static func object_hairline_rect(cell_rect: Rect2, boundary_x: float) -> Rect2:
	var inset: float = HAIRLINE_INSET if cell_rect.size.y >= 4.0 * HAIRLINE_INSET else 1.0
	return Rect2(boundary_x - 3.0, cell_rect.position.y + inset, 1.0, maxf(cell_rect.size.y - inset * 2.0, 1.0))


## The centres of the three grip dots on a lane divider, or none when the divider is too narrow to
## hold them. Centred on the divider, the middle dot on its middle.
static func grip_dot_centres(divider_rect: Rect2) -> PackedVector2Array:
	var centres := PackedVector2Array()
	if divider_rect.size.x < GRIP_MIN_DIVIDER_WIDTH or divider_rect.size.y < GRIP_DOT_SPACING * 3.0:
		return centres
	var middle: Vector2 = divider_rect.get_center()
	for step: int in [-1, 0, 1]:
		centres.append(middle + Vector2(0.0, float(step) * GRIP_DOT_SPACING))
	return centres


## The dot's diameter on a divider of this width: three pixels where there is room, two on a
## narrow one.
static func grip_dot_size(divider_width: float) -> float:
	return clampf(divider_width - 4.0, 2.0, 3.0)


static func draw_grip(control: CanvasItem, divider_rect: Rect2, color: Color) -> void:
	var dot: float = grip_dot_size(divider_rect.size.x)
	for centre: Vector2 in grip_dot_centres(divider_rect):
		control.draw_rect(Rect2(centre - Vector2(dot, dot) * 0.5, Vector2(dot, dot)), color, true)


## The one pattern that finds a sheet's own variable names inside a sentence, in every spelling
## the sheet shows them in: as written, as the humanized-names lens reads them, and as the
## Inspector capitalises an exported one. Null when there is nothing to find. Names of one letter
## are left out - `x` would colour every axis in the sheet.
static func variable_names_regex(names: PackedStringArray) -> RegEx:
	var spellings: Dictionary = {}
	for raw_name: String in names:
		if raw_name.length() < 2 or not EventSheetViewportLenses.is_identifier(raw_name):
			continue
		spellings[raw_name] = true
		spellings[EventSheetViewportLenses.humanize_identifier(raw_name, false)] = true
		spellings[EventSheetViewportLenses.humanize_identifier(raw_name, true)] = true
	if spellings.is_empty():
		return null
	var ordered: Array = spellings.keys()
	# Longest first, so "open speed max" is found whole rather than as "open speed".
	ordered.sort_custom(func(a: Variant, b: Variant) -> bool:
		return str(a).length() > str(b).length() or (str(a).length() == str(b).length() and str(a) < str(b)))
	var regex := RegEx.new()
	regex.compile("(?<![A-Za-z0-9_])(?:%s)(?![A-Za-z0-9_])" % "|".join(PackedStringArray(ordered)))
	return regex if regex.is_valid() else null


## The [start, length, "variable"] ranges where `regex` finds a variable name in `text`. With
## `within` (the [start, length] runs where the row's parameters landed) only names inside one of
## them count - the words of the sentence itself are never a variable, whatever they spell.
static func variable_word_ranges(text: String, regex: RegEx, within: Array = []) -> Array:
	var ranges: Array = []
	if regex == null or text.is_empty():
		return ranges
	for found: RegExMatch in regex.search_all(text):
		var start: int = found.get_start()
		var length: int = found.get_end() - start
		if not within.is_empty() and not _inside_any(start, length, within):
			continue
		ranges.append([start, length, WORD_VARIABLE])
	return ranges


## The value ranges and the variable ranges as one ascending list the value painter can walk. A
## variable range that overlaps a value range is dropped: the value's own tint was there first.
static func merged_word_ranges(value_ranges: Array, word_ranges: Array) -> Array:
	if word_ranges.is_empty():
		return value_ranges
	var merged: Array = value_ranges.duplicate()
	for word: Variant in word_ranges:
		var word_start: int = int((word as Array)[0])
		var word_end: int = word_start + int((word as Array)[1])
		var overlaps: bool = false
		for value: Variant in value_ranges:
			if not (value is Array) or (value as Array).size() < 2:
				continue
			var value_start: int = int((value as Array)[0])
			if word_start < value_start + int((value as Array)[1]) and value_start < word_end:
				overlaps = true
				break
		if not overlaps:
			merged.append(word)
	merged.sort_custom(func(a: Variant, b: Variant) -> bool: return int((a as Array)[0]) < int((b as Array)[0]))
	return merged


static func _inside_any(start: int, length: int, runs: Array) -> bool:
	for run: Variant in runs:
		if not (run is Array) or (run as Array).size() < 2:
			continue
		var run_start: int = int((run as Array)[0])
		if start >= run_start and start + length <= run_start + int((run as Array)[1]):
			return true
	return false


static func _draw_keyboard(control: CanvasItem, rect: Rect2, color: Color, stroke: float) -> void:
	control.draw_rect(Rect2(_at(rect, 1.5, 4.0), Vector2(_units(rect, 13.0), _units(rect, 8.0))), color, false, stroke)
	for key_x: float in [4.0, 6.5, 9.0, 11.5]:
		control.draw_rect(Rect2(_at(rect, key_x - 0.6, 6.4), Vector2(_units(rect, 1.2), _units(rect, 1.2))), color, true)
	control.draw_line(_at(rect, 5.0, 9.5), _at(rect, 11.0, 9.5), color, stroke, true)


## A point of a glyph authored on a 16-unit square, placed inside `rect`.
static func _at(rect: Rect2, x: float, y: float) -> Vector2:
	return rect.position + Vector2(x, y) * (rect.size.x / 16.0)


static func _units(rect: Rect2, length: float) -> float:
	return length * rect.size.x / 16.0


static func _editor_icon(icon_name: String) -> Texture2D:
	if icon_name.is_empty():
		return null
	if _editor_icon_cache.has(icon_name):
		return _editor_icon_cache[icon_name]
	# Only a FOUND icon is kept: a miss before the editor theme exists must not stick for the session.
	var icon: Texture2D = ACEPickerDialog.editor_icon(icon_name)
	if icon != null:
		_editor_icon_cache[icon_name] = icon
	return icon
