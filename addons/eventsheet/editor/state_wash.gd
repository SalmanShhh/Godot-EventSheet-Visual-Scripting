# Godot EventSheets - the wash a state lays over a row, and over the cell plates that sit on it.
#
# A leaf, with no `class_name` and nothing it names: the row painter loads it by path the first time a row
# is firing, flagged or cannot run, so the first open of the editor never compiles it.
@tool
extends RefCounted


## On a pale sheet the lanes and cells sit on white, where a wash that reads on a dark sheet is barely a tint,
## so the same states are drawn from a deeper hue at a stronger strength there. Chosen by picture, with every
## word of the row keeping at least WASH_TEXT_CONTRAST against the washed cell.
const PALE_WASH_STRENGTH := 1.65
const PALE_WASH_DEPTH := 0.3
const WASH_TEXT_CONTRAST := 4.5


## True when the sheet's cells sit on a pale ground (a light theme).
static func is_pale_ground(event_style: EventSheetEventStyle) -> bool:
	if event_style == null:
		return false
	return event_style.sheet_background_color.blend(event_style.condition_lane_color).get_luminance() > 0.55


## The wash a state lays over a row: `hue` at `alpha`, and on a pale ground a deeper hue at a stronger strength,
## so the state reads over white cells as plainly as it does over dark ones.
static func wash_color(hue: Color, alpha: float, pale: bool) -> Color:
	if not pale:
		return Color(hue.r, hue.g, hue.b, alpha)
	var deeper: Color = hue.darkened(PALE_WASH_DEPTH)
	return Color(deeper.r, deeper.g, deeper.b, minf(alpha * PALE_WASH_STRENGTH, 0.6))


## A cell plate as it looks under the washes the row wears, each laid over the plate in turn: an opaque plate
## is painted after the row's wash, so it takes the tint itself.
static func under_washes(plate: Color, washes: Array[Color]) -> Color:
	var result: Color = plate
	for wash: Color in washes:
		var tinted: Color = Color(result, 1.0).lerp(Color(wash, 1.0), wash.a)
		result = Color(tinted, result.a)
	return result
