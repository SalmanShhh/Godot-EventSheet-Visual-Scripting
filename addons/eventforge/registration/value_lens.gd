# EventForge - the READING LENSES: a stored value, said the way a person would say it.
#
# Most parameters read as themselves: a number is a number and a node path is a node path. A few do
# not. Godot stores 2D darkness as a CanvasModulate colour, so `Color("26304d")` is exactly right
# and tells a reader nothing about how dark the cave feels - the sentence they want is "70% dark,
# tinted #26304d", and the VALUE has to stay the colour, because that is what the file holds and
# what a re-save must write back byte for byte.
#
# So a lens is a READING and never a value. A param opts in by naming one (`ACEParam.display_lens`);
# the canvas asks for it when it draws the row, and the params dialog and the code echo go on
# showing the author's own GDScript. Nothing here is ever emitted, and a lens that does not
# recognise its input hands it straight back rather than guessing at it.
#
# ADDING ONE: a name, a `static func` that reads it, and its leg in `read()` below - and the name is
# what a pack points a param of its own at.
@tool
class_name EventForgeValueLens
extends RefCounted

## L4. Godot's own darkness: a CanvasModulate multiplies everything under it by its colour, so how
## much LIGHT that colour carries is how much of the layer survives, and `1 - that` is how dark it
## reads. The light a colour carries is `Color.get_luminance()` - the engine's own weighting of the
## three channels, which is why `Color(0.3, 0.3, 0.36)` reads 70% dark rather than 64%: green is
## most of what an eye counts as brightness, and a reader is judging the picture, not the numbers.
const LENS_DARKNESS: String = "darkness"

## The same fact with the tint left off - for a row that already says what it is fading and only
## needs the number it is fading to.
const LENS_DARKNESS_PERCENT: String = "darkness_percent"


## One value as its lens reads it, or the value unchanged: for a param that named no lens, for a
## name that is not one, and for a value the lens cannot make sense of.
static func read(lens: String, value: String) -> String:
	match lens.strip_edges():
		LENS_DARKNESS:
			return darkness(value)
		LENS_DARKNESS_PERCENT:
			return darkness_percent(value)
	return value


## The lens a parameter declared, "" for the parameters that declared none. Takes the plain
## Dictionary the registry hands the canvas, so the row builder and the definition share one reading
## of the field.
static func lens_of(parameter_dict: Dictionary) -> String:
	return str(parameter_dict.get("display_lens", "")).strip_edges()


## `Color("26304d")` as "70%, tinted #26304d" - how dark the layer is, and what colour the dark is.
## The percentage is the reading and the colour is the row: a reader sees the fact they set out to
## set, and the file still holds the colour they will save.
static func darkness(value: String) -> String:
	var percent: String = darkness_percent(value)
	return value if percent == value else "%s, %s %s" % [percent,
		EventSheetL10n.translate("tinted"), hex_of(colour_of(value))]


## The same colour as "70%" alone: how much of the layer's light the tint takes away, asked of the
## engine's own `get_luminance()` so the reading and Godot agree about what "bright" means.
static func darkness_percent(value: String) -> String:
	if not is_colour(value):
		return value
	var lit: float = colour_of(value).get_luminance()
	return "%d%%" % int(round(clampf(1.0 - lit, 0.0, 1.0) * 100.0))


## True when a value was WRITTEN as a colour - `Color.RED`, `Color(1, 0.6, 0.2)`, `Color("#ff9b3c")`.
## `Color.from_hsv(...)` is a CALL rather than the colour word red, so it is not one: a swatch or a
## percentage for it would be a guess about arguments this cannot evaluate.
static func is_colour(value: String) -> bool:
	var text: String = value.strip_edges()
	if text.begins_with("Color.") and not text.contains("("):
		return true
	return text.begins_with("Color(")


## The colour a value holds, whichever way it was written: a `Color.RED` constant, a
## `Color(1, 1, 1, 1)` literal, a `Color("#ff0000")` string or a bare colour name. White for
## anything else, which only a caller that already asked `is_colour` can reach.
static func colour_of(value: String) -> Color:
	var text: String = value.strip_edges()
	if text.begins_with("Color."):
		return Color.from_string(text.trim_prefix("Color.").replace("_", "").to_lower(), Color.WHITE)
	if text.begins_with("Color("):
		var inside: String = text.trim_prefix("Color(").trim_suffix(")").strip_edges()
		if inside.begins_with("\"") or inside.begins_with("'"):
			return Color.from_string(inside.trim_prefix("\"").trim_suffix("\"") \
				.trim_prefix("'").trim_suffix("'"), Color.WHITE)
		var numbers: PackedStringArray = inside.split(",")
		if numbers.size() >= 3:
			return Color(float(numbers[0]), float(numbers[1]), float(numbers[2]),
				float(numbers[3]) if numbers.size() > 3 else 1.0)
	return Color.from_string(text, Color.WHITE)


## `#rrggbb`, or `#rrggbbaa` when the colour is not fully opaque - the spelling everybody pastes.
static func hex_of(colour: Color) -> String:
	return "#%s" % (colour.to_html(false) if is_equal_approx(colour.a, 1.0) else colour.to_html(true))
