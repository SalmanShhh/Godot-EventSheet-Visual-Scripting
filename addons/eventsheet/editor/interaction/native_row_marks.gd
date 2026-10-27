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

## How far a selection frame's value steps from the selected gutter's (selection_frame_color).
const SELECTION_FRAME_STEP := 1.3
## A comment note's lead, in unscaled pixels: the 12 px grip, an 8 px gap, the 14 px bubble and the
## 8 px gap before the words - the design's note row.
const COMMENT_NOTE_GRIP := 12
const COMMENT_NOTE_GAP := 8
const COMMENT_NOTE_LEAD := 42
## The note card inside an action lane: 6 px in from the cell's sides, 4 px of its own padding.
const COMMENT_NOTE_CARD_SIDE := 6
const COMMENT_NOTE_CARD_PAD := 4

## The object labels that draw a glyph of their own in place of their category icon: System, and
## the input devices an event sheet treats as objects. Always DRAWN, in the object ink: Godot ships
## no gear, and its device icons are class icons in their own colours, so one drawn family is what
## lets the catch-all objects read alike on every row.
const OBJECT_GLYPH_SYSTEM := "system"
const OBJECT_GLYPH_KEYBOARD := "keyboard"
const OBJECT_GLYPH_MOUSE := "mouse"
const OBJECT_GLYPH_GAMEPAD := "gamepad"
const OBJECT_GLYPH_TOUCH := "touch"
## The lines of a function head: the head itself, each parameter, and a local variable. A span names
## one of these in its `object_glyph` metadata, because what such a line acts on is not an object
## with a class of its own.
const OBJECT_GLYPH_FUNCTION := "function"
const OBJECT_GLYPH_PARAMETER := "parameter"
const OBJECT_GLYPH_LOCAL := "local"
## Each head glyph's own ink, [on a dark sheet, on a light sheet]: the function amber, a parameter
## blue and a local green, so the three kinds of line tell apart down the column.
const HEAD_GLYPH_INKS: Dictionary = {
	OBJECT_GLYPH_FUNCTION: EventSheetPalette.COLOR_GLYPH_FUNCTION,
	OBJECT_GLYPH_PARAMETER: EventSheetPalette.COLOR_GLYPH_PARAMETER,
	OBJECT_GLYPH_LOCAL: EventSheetPalette.COLOR_GLYPH_LOCAL,
}
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
## The note cards' styleboxes, one per fill/border pair, so a note is not a new allocation per frame.
static var _note_box_cache: Dictionary = {}


## The trigger kind of an event row, or "" when it draws no trigger icon. Classified the way the
## tempo badge is (TriggerResolver.tempo_class_for), with the physics tick told apart from the
## process tick and an engine notification told apart from a signal.
static func trigger_kind(row_data: EventRowData) -> String:
	if row_data == null or row_data.row_type != EventRowData.RowType.EVENT:
		return ""
	return trigger_kind_for_event(row_data.source_resource as EventRow)


## The kind for an event resource itself - what trigger_kind answers for the row it is drawn on.
static func trigger_kind_for_event(event_row: EventRow) -> String:
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
## With `first_line_height` above zero (a theme that draws the icon in the number gutter) the icon is
## centred on the event's first line instead, beside a number drawn on that line too.
static func trigger_icon_rect(row_rect: Rect2, indent: int, indent_width: int,
		first_line_height: float = 0.0) -> Rect2:
	var slot_x: float = row_rect.position.x + EventSheetPalette.ROW_HORIZONTAL_PADDING \
		+ float(EventSheetPalette.GUTTER_WIDTH) + float(indent * indent_width)
	var centre_y: float = row_rect.position.y + row_rect.size.y * 0.5
	if first_line_height > 0.0:
		centre_y = row_rect.position.y + minf(first_line_height, row_rect.size.y) * 0.5
	var inset: float = (TRIGGER_ICON_SLOT - TRIGGER_ICON_SIZE) * 0.5
	return Rect2(slot_x + inset, centre_y - TRIGGER_ICON_SIZE * 0.5, TRIGGER_ICON_SIZE, TRIGGER_ICON_SIZE)


## The number gutter of an event drawn the way a theme with the trigger icon in the gutter draws it:
## one margin column from the left edge across the icon's slot, so the number and the icon read as
## one gutter. A nested event keeps the plain gutter, so the indent guides between keep their place.
static func gutter_band_rect(gutter_rect: Rect2, row_rect: Rect2, indent: int, indent_width: int) -> Rect2:
	if indent > 0:
		return gutter_rect
	var slot_end: float = row_rect.position.x + EventSheetPalette.ROW_HORIZONTAL_PADDING \
		+ float(EventSheetPalette.GUTTER_WIDTH) + float(indent * indent_width) + TRIGGER_ICON_SLOT
	return Rect2(gutter_rect.position, Vector2(maxf(slot_end - gutter_rect.position.x, gutter_rect.size.x),
		gutter_rect.size.y))


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


## What a condition line's mark slot shows: a green arrow on a trigger line, a red cross on an
## inverted condition, nothing on any other line. Read off the badge span the row builder put at the
## head of the line. A per-frame or repeating event is not a trigger (it runs whenever the sheet
## runs, as a plain condition does), so its slot stays empty, and a state machine's case is a plain
## check of the state.
const KIND_MARK_TRIGGER := "trigger"
const KIND_MARK_INVERTED := "inverted"
## The badge glyphs that stand for a line with no kind mark.
const UNMARKED_BADGE_GLYPHS: PackedStringArray = ["⟳", "◆"]
## The rows whose badge leads a DECLARATION, not a line that fires: an enum's list of states, a
## moment, a pack's include bar. Nothing happens on them, so they carry no arrow.
const UNMARKED_BADGE_KINDS: PackedStringArray = ["enum_row", "moment_row", "pack_include"]


## The kind mark the badge span with `metadata` and `glyph` draws, or "" for an empty slot.
static func kind_mark_for(metadata: Dictionary, glyph: String) -> String:
	match str(metadata.get("badge_style", "")):
		"negated":
			return KIND_MARK_INVERTED
		"trigger":
			if str(metadata.get("tempo", "")) == TriggerResolver.TEMPO_EVERY_TICK or UNMARKED_BADGE_GLYPHS.has(glyph) \
					or UNMARKED_BADGE_KINDS.has(str(metadata.get("kind", ""))):
				return ""
			return KIND_MARK_TRIGGER
	return ""


## Paints one kind mark centred in `rect`: the arrow points right at the line's object icon, the
## cross is the two strokes of an X. Both are drawn on a 16-unit square at a 2-unit stroke.
static func draw_kind_mark(control: CanvasItem, rect: Rect2, mark: String, color: Color) -> void:
	var stroke: float = maxf(rect.size.x / 16.0 * 2.0, 1.0)
	match mark:
		KIND_MARK_TRIGGER:
			control.draw_line(_at(rect, 2.0, 8.0), _at(rect, 12.5, 8.0), color, stroke, true)
			control.draw_polyline(PackedVector2Array([
				_at(rect, 8.5, 4.0), _at(rect, 12.5, 8.0), _at(rect, 8.5, 12.0)]), color, stroke, true)
		KIND_MARK_INVERTED:
			control.draw_line(_at(rect, 4.0, 4.0), _at(rect, 12.0, 12.0), color, stroke, true)
			control.draw_line(_at(rect, 12.0, 4.0), _at(rect, 4.0, 12.0), color, stroke, true)


## The square a kind mark is painted in, centred in its badge cell and never wider than the cell.
static func kind_mark_rect(badge_rect: Rect2) -> Rect2:
	var side: float = minf(badge_rect.size.x, badge_rect.size.y) * 0.75
	return Rect2(badge_rect.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))


## The ink that reads on `fill`: white on a dark or saturated fill (the design's selected blue), a
## near-black on a pale one. What a selected gutter's number and trigger icon are drawn in.
static func ink_on(fill: Color) -> Color:
	return NativeVariableMarks.contrast_ink(fill, SELECTED_INK_LUMINANCE)


## Where a selected event's filled margin continues past the 20 px gutter: from the gutter's edge
## across the trigger icon's slot for an event at the left edge, so the number and the icon sit on
## one fill. A nested event under `continuous` (a theme that marks a selection by its gutter and frame
## alone) fills the same one shape, from the gutter's edge over its indent to the end of the slot, so
## the group's rails never split the number from the icon; otherwise only the slot itself, and only
## when an icon is drawn in it, so the indent guides between keep their place. An empty rect means
## nothing more is filled.
static func selected_slot_rect(gutter_rect: Rect2, row_rect: Rect2, indent: int, indent_width: int,
		has_icon: bool, continuous: bool = false) -> Rect2:
	var slot_x: float = row_rect.position.x + EventSheetPalette.ROW_HORIZONTAL_PADDING \
		+ float(EventSheetPalette.GUTTER_WIDTH) + float(indent * indent_width)
	if indent <= 0 or continuous:
		return Rect2(gutter_rect.end.x, row_rect.position.y, slot_x + TRIGGER_ICON_SLOT - gutter_rect.end.x,
			row_rect.size.y)
	if not has_icon:
		return Rect2()
	return Rect2(slot_x, row_rect.position.y, TRIGGER_ICON_SLOT, row_rect.size.y)


## The frame round a selected event under selection_as_outline: the selected gutter's own hue and
## saturation, a step brighter on a dark gutter and a step deeper on a light one, so the frame and
## the filled margin read as one mark (the design pairs #2c5d87 with #3a72b0 the same way).
static func selection_frame_color(gutter_fill: Color) -> Color:
	var value: float = gutter_fill.v * SELECTION_FRAME_STEP if gutter_fill.v < 0.6 \
		else gutter_fill.v / SELECTION_FRAME_STEP
	return Color.from_hsv(gutter_fill.h, gutter_fill.s, clampf(value, 0.0, 1.0), 1.0)


## The room a comment note's lead takes before its words: the drag grip, the speech-bubble mark and
## the gaps after each. One number, read by the layout (the wrap width), the row builder (the lead
## span) and the painter, so the words land where the room was left for them.
static func comment_note_lead_width() -> float:
	return EventSheetPalette.scaled(COMMENT_NOTE_LEAD)


## Where a note's words start inside an action-lane cell: past the card's side inset, the card's own
## 4 px padding and the lead.
static func comment_note_text_inset() -> float:
	return float(EventSheetPalette.scaled(COMMENT_NOTE_CARD_SIDE + COMMENT_NOTE_CARD_PAD)) + comment_note_lead_width()


## Paints a note's card inside an action-lane cell, and its lead at the card's left on the first
## line: the comment fill, the comment border, the design's 3 px corners.
static func draw_comment_note_card(control: CanvasItem, cell: Rect2, first_line_center_y: float,
		fill: Color, border: Color, ink: Color) -> void:
	var card: Rect2 = comment_note_card_rect(cell)
	var key: String = "%s:%s:%d" % [fill.to_html(), border.to_html(), EventSheetPalette.scaled(3)]
	var box: StyleBoxFlat = _note_box_cache.get(key)
	if box == null:
		if _note_box_cache.size() > 16:
			_note_box_cache.clear()
		box = StyleBoxFlat.new()
		box.bg_color = fill
		box.border_color = border
		box.set_border_width_all(1 if border.a > 0.01 else 0)
		box.set_corner_radius_all(EventSheetPalette.scaled(3))
		_note_box_cache[key] = box
	control.draw_style_box(box, card)
	draw_comment_note_lead(control, card.position.x + EventSheetPalette.scaled(COMMENT_NOTE_CARD_PAD),
		first_line_center_y, ink)


## Paints a comment note's lead -the two-column, three-row drag grip and the speech bubble - from
## `x`, centred on `center_y`, in the note's own ink. Paint only: the lead's room is reserved by the
## caller, and the grip's drag is the row's own.
static func draw_comment_note_lead(control: CanvasItem, x: float, center_y: float, ink: Color) -> void:
	var dot: float = EventSheetPalette.scaled(3)
	var step: float = dot + EventSheetPalette.scaled(3)
	var grip_ink: Color = Color(ink, ink.a * 0.6)
	for column: int in range(2):
		for line: int in range(3):
			var dot_x: float = x + float(column) * step
			var dot_y: float = center_y + float(line - 1) * step - dot * 0.5
			control.draw_rect(Rect2(dot_x, dot_y, dot, dot), grip_ink, true)
	var bubble_side: float = EventSheetPalette.scaled(14)
	var bubble_x: float = x + EventSheetPalette.scaled(COMMENT_NOTE_GRIP + COMMENT_NOTE_GAP)
	var bubble := Rect2(bubble_x, center_y - bubble_side * 0.5, bubble_side, bubble_side)
	var stroke: float = maxf(_units(bubble, 1.4), 1.0)
	var outline: PackedVector2Array = PackedVector2Array([
		_at(bubble, 2.5, 3.0), _at(bubble, 13.5, 3.0), _at(bubble, 13.5, 10.5), _at(bubble, 7.5, 10.5),
		_at(bubble, 4.5, 13.0), _at(bubble, 4.5, 10.5), _at(bubble, 2.5, 10.5), _at(bubble, 2.5, 3.0),
	])
	control.draw_polyline(outline, ink, stroke, true)


## The note's card inside an event's action lane: inset from the cell the way the design sets it
## (6 px at the sides, 2 px above, 4 px below), filled in the comment colour and edged in its border.
static func comment_note_card_rect(cell: Rect2) -> Rect2:
	var side: float = EventSheetPalette.scaled(COMMENT_NOTE_CARD_SIDE)
	var top: float = EventSheetPalette.scaled(2)
	var bottom: float = EventSheetPalette.scaled(4)
	return Rect2(cell.position.x + side, cell.position.y + top,
		maxf(cell.size.x - side * 2.0, 1.0), maxf(cell.size.y - top - bottom, 1.0))


## The glyph an object label draws in place of its icon, or "" for one that keeps its icon.
static func object_glyph_for(object_label: String) -> String:
	return str(OBJECT_GLYPHS.get(object_label, ""))


## The glyph a line's span asks for: its own `object_glyph` (a function head's lines), else the one
## its object label draws (System, the input devices), else "".
static func line_glyph_for(metadata: Dictionary) -> String:
	var own: String = str(metadata.get("object_glyph", ""))
	return own if not own.is_empty() else object_glyph_for(str(metadata.get("object_label", "")))


## The ink a glyph is painted in on a line whose words are `ink`: a head glyph's own colour for the
## sheet's hand, else the words' own ink a little quieter (the System gear is furniture).
static func glyph_ink(glyph: String, ink: Color) -> Color:
	if HEAD_GLYPH_INKS.has(glyph):
		return (HEAD_GLYPH_INKS[glyph] as Array)[0 if ink.get_luminance() > 0.5 else 1]
	return Color(ink, ink.a * 0.8)


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
		OBJECT_GLYPH_FUNCTION:
			control.draw_polyline(PackedVector2Array([_at(rect, 11.0, 2.5), _at(rect, 9.4, 2.7),
				_at(rect, 8.4, 3.6), _at(rect, 8.0, 6.0), _at(rect, 8.0, 14.0)]), color, stroke, true)
			control.draw_line(_at(rect, 5.0, 7.0), _at(rect, 11.0, 7.0), color, stroke, true)
		OBJECT_GLYPH_PARAMETER:
			control.draw_polyline(PackedVector2Array([_at(rect, 5.0, 3.0), _at(rect, 3.0, 3.0),
				_at(rect, 3.0, 13.0), _at(rect, 5.0, 13.0)]), color, stroke, true)
			control.draw_polyline(PackedVector2Array([_at(rect, 11.0, 3.0), _at(rect, 13.0, 3.0),
				_at(rect, 13.0, 13.0), _at(rect, 11.0, 13.0)]), color, stroke, true)
			control.draw_line(_at(rect, 8.0, 7.2), _at(rect, 8.0, 8.8), color, stroke, true)
		OBJECT_GLYPH_LOCAL:
			control.draw_rect(Rect2(_at(rect, 2.5, 2.5), Vector2(_units(rect, 11.0), _units(rect, 11.0))), color, false, stroke)
			control.draw_line(_at(rect, 6.0, 6.0), _at(rect, 10.0, 10.0), color, stroke, true)
			control.draw_line(_at(rect, 10.0, 6.0), _at(rect, 6.0, 10.0), color, stroke, true)
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
	var icon: Texture2D = EventSheetACEIcons.editor_icon(icon_name)
	if icon != null:
		_editor_icon_cache[icon_name] = icon
	return icon
