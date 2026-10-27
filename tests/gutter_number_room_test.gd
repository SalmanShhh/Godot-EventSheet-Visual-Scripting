# EventSheet - an event's number in the margin is never cut to its first digit.
#
# A user's own script opened as a sheet passes ten events in a few lines, and an event that is
# more than one line tall draws its number in the middle of the margin. That middle position
# kept a 4px inset on both sides of a 20px margin, which left 12px: "10" and "11" were drawn as
# "1". These pins hold the place and the room the painter is given, measured with the font the
# editor falls back to, so a two-digit number always gets at least its own width.
@tool
class_name GutterNumberRoomTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "gutter_number_room_test"


static func run() -> bool:
	var gutter := Rect2(0.0, 0.0, float(EventSheetPalette.GUTTER_WIDTH), 64.0)
	var font: Font = ThemeDB.fallback_font
	var size: int = 13
	var one: float = font.get_string_size("4", HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var two: float = font.get_string_size("10", HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var ok: bool = true
	ok = SUPPORT.pins(NAME, [
		["a one-digit number keeps its 4px inset", _box(gutter, one, false).x, 4.0],
		["a two-digit number in the middle of a tall event has room for both digits",
			_box(gutter, two, false).y >= two, true],
		["a two-digit number ends against the margin's edge",
			snappedf(_box(gutter, two, false).x + two, 0.01), snappedf(gutter.size.x - EventRowRenderer.GUTTER_NUMBER_END_INSET, 0.01)],
		["beside the trigger icon it ends in the same place",
			snappedf(_box(gutter, two, true).x + two, 0.01), snappedf(gutter.size.x - EventRowRenderer.GUTTER_NUMBER_END_INSET, 0.01)],
		["a number wider than the whole margin starts 1px in",
			_box(gutter, gutter.size.x + 10.0, false).x, 1.0],
	]) and ok
	return ok


## The painter's answer, or a zero box when the renderer has no such helper - so a missing helper
## reads as a failed pin rather than a script error that prints no verdict.
static func _box(gutter: Rect2, width: float, right_aligned: bool) -> Vector2:
	var renderer := EventRowRenderer.new()
	if not renderer.has_method("gutter_number_box"):
		return Vector2.ZERO
	return renderer.call("gutter_number_box", gutter, width, right_aligned)
