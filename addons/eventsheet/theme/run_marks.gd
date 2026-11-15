# Godot EventSheets - the colours of what a run draws on the sheet: the count chip and the number beside it
# in the margin, and the live value badge on a row.
#
# They come from the theme's own colours (the margin number's, the finding amber, the error stripe, the firing
# stripe) and are moved until the words read at 4.5 to 1 on the ground they are drawn on, so a light sheet and
# a dark one both read, and no colour of its own is added to the theme file.
#
# DELIBERATELY NO `class_name`: the renderer loads it by path when a run is drawing, so the first open of the
# workspace does not compile it.
@tool
extends RefCounted

const READABLE_INK_PATH := "res://addons/eventsheet/theme/readable_ink.gd"
const RESTING_FILL_ALPHA: float = 0.12
const LOUD_FILL_ALPHA: float = 0.18
const BORDER_ALPHA: float = 0.34
const RAIL_ALPHA: float = 0.45


## The look of one row's count chip and margin number for the run so far. `resting` is the margin number's
## own colour and `ground` the margin's fill. Returns {fill, border, text, rail, cold}: `text` is the ink for
## the chip and the number, `cold` is true for a row that has not fired once (it also gets the rail).
static func marks_for(hit_uid: String, resting: Color, reading: EventSheetReadingStyle, warning: Color, ground: Color) -> Dictionary:
	var calls: int = EventSheetRunProfile.calls_for(hit_uid)
	var band: String = EventSheetRunProfile.cost_band(hit_uid)
	var hue: Color = resting
	var loud: bool = true
	var cold: bool = false
	if calls == 0:
		hue = reading.error_stripe_color
		cold = true
	elif band == EventSheetRunProfile.BAND_HOT:
		hue = reading.error_stripe_color
	elif band == EventSheetRunProfile.BAND_WARM or EventSheetTraceHitCounts.is_hot(hit_uid) or EventSheetRunProfile.is_absurd(hit_uid):
		hue = warning
	else:
		loud = false
	var fill_alpha: float = 0.0 if cold else (LOUD_FILL_ALPHA if loud else RESTING_FILL_ALPHA)
	var floor: Color = Color(ground, 1.0).lerp(Color(hue, 1.0), fill_alpha)
	var ink: Script = load(READABLE_INK_PATH)
	return {
		"fill": Color(hue, fill_alpha),
		"border": Color(hue, BORDER_ALPHA),
		"text": ink.move(Color(hue, 1.0), [floor, ground]),
		"rail": Color(hue, RAIL_ALPHA),
		"cold": cold,
	}


## The live-value badge's ink: the firing stripe's colour moved until it reads on the row.
static func live_ink(reading: EventSheetReadingStyle, row_ground: Color) -> Color:
	return load(READABLE_INK_PATH).move(Color(reading.firing_stripe_color, 1.0), [row_ground])


## A comment's words on a band of its own colour: the theme's comment ink, moved until it reads on that band.
## A comment with no colour of its own (a clear `band`) keeps the theme's ink as it is.
static func comment_ink(ink: Color, band: Color) -> Color:
	if band.a <= 0.01:
		return ink
	# Opaque: a faded ink would read less than the colour moved for.
	return load(READABLE_INK_PATH).move(Color(ink, 1.0), [Color(band, 1.0)])
