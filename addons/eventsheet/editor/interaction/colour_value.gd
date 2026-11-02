# Godot EventSheets - the one reader and writer of a colour value.
#
# A colour in a sheet is text: a variable's default, an action's parameter, a condition's operand. It can be
# written a dozen ways (`Color(1, 0.5, 0)`, `Color("#ff8000")`, `Color.ORANGE`, `Color8(255, 128, 0)`,
# `Color.from_hsv(...)`, ...) and every one of them is the same question: what colour is that, how does the
# row say it, and what text does a pick write back. This file answers all three, for the rows, the
# variables, the picker and the dialog alike, so a colour is never named three different ways.
#
# Three rules hold everywhere:
#   - A pick moves the colour and no other byte: the call, the argument count, the hex length and its
#     case, the "#" are all kept (`write_back`).
#   - What the row SAYS is a reading (`read_as`): it changes the words drawn, never the text stored.
#   - A value the editor cannot work out without running the game (a variable, a node's property, a
#     call) has no colour here, and is never guessed at (`classify` says "runtime").
@tool
class_name EventSheetColourValue
extends RefCounted

## The ways a value may be written.
const FORM_RGB := "rgb"
const FORM_HEX_CALL := "hex_call"
const FORM_NAME_CALL := "name_call"
const FORM_CONSTANT := "constant"
const FORM_HTML := "html"
const FORM_HEX_INT := "hex_int"
const FORM_COLOR8 := "color8"
const FORM_RGBA8 := "rgba8"
const FORM_HSV := "hsv"
const FORM_OKHSL := "okhsl"
const FORM_BASE_ALPHA := "base_alpha"
const FORM_BARE_HEX := "bare_hex"
const FORM_BARE_NAME := "bare_name"
const FORM_FOLDED := "folded"

## The picker's modes, as the words the sheet keeps them under.
const MODE_RGB := "rgb"
const MODE_HSV := "hsv"
const MODE_OKHSL := "okhsl"

## What a value is, for the check that a Color slot holds a colour.
const KIND_COLOUR := "colour"
const KIND_RUNTIME := "runtime"
const KIND_WRONG := "wrong"
const KIND_EMPTY := "empty"

## The ways the sheet may be asked to read colours (the project setting's values).
const READ_WRITTEN := "As written"
const READ_HEX := "Hex"
const READ_RGB255 := "RGB 0-255"
const READ_RGB1 := "RGB 0-1"
const READ_HSV := "HSV"
const READ_NAME := "Name"
const READ_CHOICES: PackedStringArray = ["As written", "Hex", "RGB 0-255", "RGB 0-1", "HSV", "Name"]

const SETTING_NAME := "eventsheets/editor/colour_values_read_as"

## Every constant of Godot's Color. The colour of each is asked of the engine (never typed here), and a
## name this engine does not know is simply left out of the table.
const CONSTANT_NAMES: PackedStringArray = [
	"ALICE_BLUE", "ANTIQUE_WHITE", "AQUA", "AQUAMARINE", "AZURE", "BEIGE", "BISQUE", "BLACK", "BLANCHED_ALMOND",
	"BLUE", "BLUE_VIOLET", "BROWN", "BURLYWOOD", "CADET_BLUE", "CHARTREUSE", "CHOCOLATE", "CORAL",
	"CORNFLOWER_BLUE", "CORNSILK", "CRIMSON", "CYAN", "DARK_BLUE", "DARK_CYAN", "DARK_GOLDENROD", "DARK_GRAY",
	"DARK_GREEN", "DARK_KHAKI", "DARK_MAGENTA", "DARK_OLIVE_GREEN", "DARK_ORANGE", "DARK_ORCHID", "DARK_RED",
	"DARK_SALMON", "DARK_SEA_GREEN", "DARK_SLATE_BLUE", "DARK_SLATE_GRAY", "DARK_TURQUOISE", "DARK_VIOLET",
	"DEEP_PINK", "DEEP_SKY_BLUE", "DIM_GRAY", "DODGER_BLUE", "FIREBRICK", "FLORAL_WHITE", "FOREST_GREEN",
	"FUCHSIA", "GAINSBORO", "GHOST_WHITE", "GOLD", "GOLDENROD", "GRAY", "GREEN", "GREEN_YELLOW", "HONEYDEW",
	"HOT_PINK", "INDIAN_RED", "INDIGO", "IVORY", "KHAKI", "LAVENDER", "LAVENDER_BLUSH", "LAWN_GREEN",
	"LEMON_CHIFFON", "LIGHT_BLUE", "LIGHT_CORAL", "LIGHT_CYAN", "LIGHT_GOLDENROD", "LIGHT_GRAY", "LIGHT_GREEN",
	"LIGHT_PINK", "LIGHT_SALMON", "LIGHT_SEA_GREEN", "LIGHT_SKY_BLUE", "LIGHT_SLATE_GRAY", "LIGHT_STEEL_BLUE",
	"LIGHT_YELLOW", "LIME", "LIME_GREEN", "LINEN", "MAGENTA", "MAROON", "MEDIUM_AQUAMARINE", "MEDIUM_BLUE",
	"MEDIUM_ORCHID", "MEDIUM_PURPLE", "MEDIUM_SEA_GREEN", "MEDIUM_SLATE_BLUE", "MEDIUM_SPRING_GREEN",
	"MEDIUM_TURQUOISE", "MEDIUM_VIOLET_RED", "MIDNIGHT_BLUE", "MINT_CREAM", "MISTY_ROSE", "MOCCASIN",
	"NAVAJO_WHITE", "NAVY_BLUE", "OLD_LACE", "OLIVE", "OLIVE_DRAB", "ORANGE", "ORANGE_RED", "ORCHID",
	"PALE_GOLDENROD", "PALE_GREEN", "PALE_TURQUOISE", "PALE_VIOLET_RED", "PAPAYA_WHIP", "PEACH_PUFF", "PERU",
	"PINK", "PLUM", "POWDER_BLUE", "PURPLE", "REBECCA_PURPLE", "RED", "ROSY_BROWN", "ROYAL_BLUE",
	"SADDLE_BROWN", "SALMON", "SANDY_BROWN", "SEA_GREEN", "SEASHELL", "SIENNA", "SILVER", "SKY_BLUE",
	"SLATE_BLUE", "SLATE_GRAY", "SNOW", "SPRING_GREEN", "STEEL_BLUE", "TAN", "TEAL", "THISTLE", "TOMATO",
	"TRANSPARENT", "TURQUOISE", "VIOLET", "WEB_GRAY", "WEB_GREEN", "WEB_MAROON", "WEB_PURPLE", "WHEAT",
	"WHITE", "WHITE_SMOKE", "YELLOW", "YELLOW_GREEN",
]

## Constants that repeat another one's colour. They read and fold like any other, but a colour is never
## NAMED by one of these when the table is searched backwards.
const ALIAS_NAMES: PackedStringArray = ["AQUA", "FUCHSIA"]

## The words a value that folds from constants may use. Anything else is worked out while the game runs.
const FOLD_WORDS: PackedStringArray = ["Color", "lerp", "darkened", "lightened", "inverted", "blend", "from_hsv",
	"from_rgba8", "from_ok_hsl", "html", "true", "false"]

static var _by_compact: Dictionary = {}
static var _constant_colours: Dictionary = {}
static var _by_value: Dictionary = {}
static var _table_built: bool = false


## Builds the name tables once. A constant's colour comes from the engine through its string reader.
static func _build_tables() -> void:
	if _table_built:
		return
	_table_built = true
	var dark := Color(0.0, 0.0, 0.0, 0.0)
	var light := Color(1.0, 1.0, 1.0, 1.0)
	for constant_name: String in CONSTANT_NAMES:
		var compact: String = constant_name.replace("_", "").to_lower()
		var found: Color = Color.from_string(compact, dark)
		# A word the engine does not know falls back to the default it is handed, so two opposite defaults
		# disagree exactly when the word is not a colour.
		if found != Color.from_string(compact, light):
			continue
		_by_compact[compact] = constant_name
		_constant_colours[constant_name] = found
		if ALIAS_NAMES.has(constant_name):
			continue
		var key: int = _pack(found)
		if not _by_value.has(key):
			_by_value[key] = constant_name


## A colour as one integer, 8 bits a channel - the precision a name or a hex can tell apart.
static func _pack(colour: Color) -> int:
	return (roundi(clampf(colour.r, 0.0, 1.0) * 255.0) << 24) | (roundi(clampf(colour.g, 0.0, 1.0) * 255.0) << 16) \
		| (roundi(clampf(colour.b, 0.0, 1.0) * 255.0) << 8) | roundi(clampf(colour.a, 0.0, 1.0) * 255.0)


## The words of a reading or a copy form, in the editor's language. Each is spelled out as a literal so the
## translation harvest finds it.
static func label_words(label: String) -> String:
	match label:
		"As written":
			return EventSheetL10n.translate("As written")
		"Hex":
			return EventSheetL10n.translate("Hex")
		"RGB 0-255":
			return EventSheetL10n.translate("RGB 0-255")
		"RGB 0-1":
			return EventSheetL10n.translate("RGB 0-1")
		"HSV":
			return EventSheetL10n.translate("HSV")
		"Name":
			return EventSheetL10n.translate("Name")
		"Godot code":
			return EventSheetL10n.translate("Godot code")
	return label


## The CONSTANT_NAME a word means ("orange", "dodger_blue", "DodgerBlue" all find DODGER_BLUE), or "".
static func constant_for_word(word: String) -> String:
	_build_tables()
	var compact: String = word.strip_edges().replace("_", "").replace(" ", "").to_lower()
	return str(_by_compact.get(compact, ""))


## The colour of a CONSTANT_NAME, or null.
static func constant_colour(constant_name: String) -> Variant:
	_build_tables()
	return _constant_colours.get(constant_name.to_upper())


## The CONSTANT_NAME a colour is exactly (8 bits a channel), "" when it has no name.
static func name_of(colour: Color) -> String:
	_build_tables()
	return str(_by_value.get(_pack(colour), ""))


## Whether the sheet already knows every name in the table (a test reads this).
static func constant_count() -> int:
	_build_tables()
	return _constant_colours.size()


## What the value in a Color slot is: a colour, something only the running game knows, text that is not a
## colour at all, or nothing.
static func classify(text: String) -> String:
	var t: String = text.strip_edges()
	if t.is_empty():
		return KIND_EMPTY
	if bool(parse(t).get("ok", false)):
		return KIND_COLOUR
	if _looks_wrong(t):
		return KIND_WRONG
	return KIND_RUNTIME


## A literal of some other type: a plain string, a number, a boolean, null, a vector, a list.
static func _looks_wrong(t: String) -> bool:
	if t == "true" or t == "false" or t == "null":
		return true
	if t.is_valid_float() or t.is_valid_int() or t.is_valid_hex_number(true):
		return true
	if (t.begins_with("\"") and t.ends_with("\"") and t.length() >= 2) or (t.begins_with("'") and t.ends_with("'") and t.length() >= 2):
		return true
	if t.begins_with("[") or t.begins_with("{"):
		return true
	for other: String in ["Vector2", "Vector3", "Vector4", "Rect2", "Transform", "Basis", "Quaternion", "Plane", "String", "StringName", "NodePath", "Array", "Dictionary"]:
		if t.begins_with(other + "(") or t.begins_with(other + "i("):
			return true
	return false


## Reads a value. Always a dictionary; `ok` says whether it is a colour the editor can work out without
## running anything. The other keys describe how it was written, which is what the write-back keeps.
static func parse(text: String) -> Dictionary:
	var info: Dictionary = _parse(text)
	if bool(info.get("ok", false)):
		info["source_text"] = text.strip_edges()
	return info


static func _parse(text: String) -> Dictionary:
	_build_tables()
	var t: String = text.strip_edges()
	if t.is_empty():
		return {"ok": false}
	if t.begins_with("Color.") and not t.contains("("):
		var constant_name: String = t.trim_prefix("Color.")
		if _constant_colours.has(constant_name):
			return _result(FORM_CONSTANT, _constant_colours[constant_name], {"name": constant_name, "word": constant_name.to_lower()})
		return {"ok": false}
	if t.begins_with("#"):
		return _parse_hex_text(t, FORM_BARE_HEX, "")
	if t.is_valid_identifier():
		var bare: String = constant_for_word(t)
		if not bare.is_empty():
			return _result(FORM_BARE_NAME, _constant_colours[bare], {"name": bare, "word": t})
		return {"ok": false}
	var call: Dictionary = _split_call(t)
	if not call.is_empty():
		var parsed: Dictionary = _parse_call(str(call["callee"]), call["args"] as Array, t)
		if bool(parsed.get("ok", false)):
			return parsed
	return _fold(t)


static func _result(form: String, colour: Color, extra: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"ok": true, "form": form, "color": colour, "args": 0, "alpha_args": false,
		"mode": MODE_RGB, "folded": false, "editable": true, "deprecated": false,
		"overbright": maxf(colour.r, maxf(colour.g, colour.b)) > 1.0 + 1.0e-6}
	out.merge(extra, true)
	return out


## `callee(args)` split into the callee and the top-level comma-separated arguments, {} when `t` is not
## exactly one call.
static func _split_call(t: String) -> Dictionary:
	var open: int = t.find("(")
	if open <= 0 or not t.ends_with(")"):
		return {}
	var callee: String = t.substr(0, open).strip_edges()
	if not (callee.begins_with("Color") and (callee.replace(".", "").replace("_", "").is_valid_identifier())):
		return {}
	var depth: int = 0
	var quote: String = ""
	var args: Array = []
	var start: int = open + 1
	for index: int in range(open, t.length()):
		var character: String = t[index]
		if not quote.is_empty():
			if character == quote:
				quote = ""
			continue
		if character == "\"" or character == "'":
			quote = character
		elif character == "(":
			depth += 1
		elif character == ")":
			depth -= 1
			if depth == 0:
				if index != t.length() - 1:
					return {}
				var last: String = t.substr(start, index - start).strip_edges()
				if not last.is_empty() or not args.is_empty():
					args.append(last)
				return {"callee": callee, "args": args}
		elif character == "," and depth == 1:
			args.append(t.substr(start, index - start).strip_edges())
			start = index + 1
	return {}


## The inside of a quoted literal and its quote character, or ["", ""] when `arg` is not one.
static func _unquote(arg: String) -> Array:
	if arg.length() >= 2 and (arg[0] == "\"" or arg[0] == "'") and arg[arg.length() - 1] == arg[0]:
		return [arg.substr(1, arg.length() - 2), arg[0]]
	return ["", ""]


static func _numbers(args: Array) -> Variant:
	var out: Array = []
	for arg: Variant in args:
		var piece: String = str(arg).strip_edges()
		if not piece.is_valid_float():
			return null
		out.append(float(piece))
	return out


static func _parse_call(callee: String, args: Array, source: String) -> Dictionary:
	match callee:
		"Color":
			if args.size() == 1:
				var quoted: Array = _unquote(str(args[0]))
				if str(quoted[1]).is_empty():
					return {"ok": false}
				var inner: String = str(quoted[0])
				var hex: Dictionary = _parse_hex_text(inner, FORM_HEX_CALL, str(quoted[1]))
				if bool(hex.get("ok", false)):
					return hex
				var word: String = constant_for_word(inner)
				if not word.is_empty() and not inner.begins_with("#"):
					return _result(FORM_NAME_CALL, _constant_colours[word], {"name": word, "word": inner, "quote": str(quoted[1])})
				return {"ok": false}
			if args.size() == 2:
				var base: Dictionary = parse(str(args[0]))
				var alpha_text: String = str(args[1]).strip_edges()
				if not bool(base.get("ok", false)) or bool(base.get("folded", false)) or not alpha_text.is_valid_float():
					return {"ok": false}
				var base_colour: Color = base["color"]
				var with_alpha := Color(base_colour.r, base_colour.g, base_colour.b, float(alpha_text))
				return _result(FORM_BASE_ALPHA, with_alpha, {"base": base, "args": 2, "alpha_args": true})
			var numbers: Variant = _numbers(args)
			if numbers == null or (numbers as Array).size() < 3 or (numbers as Array).size() > 4:
				return {"ok": false}
			var channels: Array = numbers
			return _result(FORM_RGB, Color(channels[0], channels[1], channels[2], channels[3] if channels.size() > 3 else 1.0),
				{"args": channels.size(), "alpha_args": channels.size() > 3})
		"Color.html":
			if args.size() != 1:
				return {"ok": false}
			var html_quoted: Array = _unquote(str(args[0]))
			if str(html_quoted[1]).is_empty():
				return {"ok": false}
			return _parse_hex_text(str(html_quoted[0]), FORM_HTML, str(html_quoted[1]))
		"Color.hex":
			if args.size() != 1:
				return {"ok": false}
			var literal: String = str(args[0]).strip_edges()
			if not (literal.begins_with("0x") or literal.begins_with("0X")) or not literal.is_valid_hex_number(true):
				return {"ok": false}
			var packed: int = literal.hex_to_int()
			var hex_colour := Color.hex(packed)
			var digits: String = literal.substr(2)
			return _result(FORM_HEX_INT, hex_colour, {"digits": digits.length(), "upper": _is_upper_hex(digits), "prefix": literal.substr(0, 2)})
		"Color8", "Color.from_rgba8":
			var eight: Variant = _numbers(args)
			if eight == null or (eight as Array).size() < 3 or (eight as Array).size() > 4:
				return {"ok": false}
			var parts: Array = eight
			var colour8 := Color8(int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3]) if parts.size() > 3 else 255)
			return _result(FORM_COLOR8 if callee == "Color8" else FORM_RGBA8, colour8,
				{"args": parts.size(), "alpha_args": parts.size() > 3, "deprecated": callee == "Color8"})
		"Color.from_hsv":
			var hsv: Variant = _numbers(args)
			if hsv == null or (hsv as Array).size() < 3 or (hsv as Array).size() > 4:
				return {"ok": false}
			var hv: Array = hsv
			return _result(FORM_HSV, Color.from_hsv(hv[0], hv[1], hv[2], hv[3] if hv.size() > 3 else 1.0),
				{"args": hv.size(), "alpha_args": hv.size() > 3, "mode": MODE_HSV})
		"Color.from_ok_hsl":
			var okhsl: Variant = _numbers(args)
			if okhsl == null or (okhsl as Array).size() < 3 or (okhsl as Array).size() > 4:
				return {"ok": false}
			var ov: Array = okhsl
			return _result(FORM_OKHSL, Color.from_ok_hsl(ov[0], ov[1], ov[2], ov[3] if ov.size() > 3 else 1.0),
				{"args": ov.size(), "alpha_args": ov.size() > 3, "mode": MODE_OKHSL})
	return {"ok": false}


## A hex string - `#ff8000`, `ff8000`, `#ff800080` - kept as typed (its "#", its length, its case).
static func _parse_hex_text(inner: String, form: String, quote: String) -> Dictionary:
	var digits: String = inner.trim_prefix("#")
	if not (digits.length() == 3 or digits.length() == 4 or digits.length() == 6 or digits.length() == 8):
		return {"ok": false}
	if not digits.is_valid_hex_number(false) or not Color.html_is_valid(inner):
		return {"ok": false}
	return _result(form, Color.html(inner), {"digits": digits.length(), "hash": inner.begins_with("#"),
		"upper": _is_upper_hex(digits), "word": inner, "quote": quote, "alpha_args": digits.length() == 4 or digits.length() == 8})


## True when the letters in a run of hex digits were typed in capitals (digits alone count as lower case).
static func _is_upper_hex(digits: String) -> bool:
	var has_upper: bool = false
	for character: String in digits:
		if character >= "a" and character <= "f":
			return false
		if character >= "A" and character <= "F":
			has_upper = true
	return has_upper


## A value made of constants and a few colour methods, worked out by the editor: `Color.RED.lerp(Color.BLUE,
## 0.5)`. Anything that names a variable, a node or a call outside the list is left to the game.
static func _fold(t: String) -> Dictionary:
	if not t.contains("Color") and not t.begins_with("lerp("):
		return {"ok": false}
	# Words outside the string literals must all be in the list (or be a colour constant after `Color.`).
	var bare: String = ""
	var quote: String = ""
	for character: String in t:
		if not quote.is_empty():
			if character == quote:
				quote = ""
			continue
		if character == "\"" or character == "'":
			quote = character
			bare += " "
			continue
		bare += character
	if not quote.is_empty():
		return {"ok": false}
	var words := RegEx.new()
	words.compile("[A-Za-z_][A-Za-z0-9_]*")
	var previous_end: int = 0
	var expression_text: String = t
	for found: RegExMatch in words.search_all(bare):
		var word: String = found.get_string()
		var is_constant: bool = _constant_colours.has(word) and found.get_start() >= 6 \
			and bare.substr(found.get_start() - 6, 6) == "Color."
		if not FOLD_WORDS.has(word) and not is_constant:
			return {"ok": false}
		previous_end = found.get_end()
	if previous_end == 0:
		return {"ok": false}
	# Constants become the constructors the expression engine reads.
	for constant_name: String in _constant_colours:
		var colour: Color = _constant_colours[constant_name]
		expression_text = _replace_constant(expression_text, constant_name,
			"Color(%s, %s, %s, %s)" % [colour.r, colour.g, colour.b, colour.a])
	var expression := Expression.new()
	if expression.parse(expression_text) != OK:
		return {"ok": false}
	var value: Variant = expression.execute([], null, false)
	if expression.has_execute_failed() or not (value is Color):
		return {"ok": false}
	return _result(FORM_FOLDED, value as Color, {"folded": true, "editable": false})


## Replaces the whole word `Color.NAME` (never `Color.NAME_LIGHT`) with `replacement`.
static func _replace_constant(source: String, constant_name: String, replacement: String) -> String:
	var needle: String = "Color." + constant_name
	var at: int = source.find(needle)
	if at == -1:
		return source
	var out: String = ""
	var cursor: int = 0
	while at != -1:
		var after: int = at + needle.length()
		var next_character: String = source[after] if after < source.length() else ""
		var is_word_end: bool = next_character.is_empty() or not (next_character == "_" or next_character.is_valid_identifier() or next_character.is_valid_int())
		out += source.substr(cursor, at - cursor)
		out += replacement if is_word_end else needle
		cursor = after
		at = source.find(needle, cursor)
	return out + source.substr(cursor)


# ---------------------------------------------------------------------------------------------------
# What the square shows
# ---------------------------------------------------------------------------------------------------


## The colour the square is filled with: each channel held to 0..1 (an overbright one is marked, not
## shown), the alpha kept so the checkerboard can show through.
static func square_colour(colour: Color) -> Color:
	return Color(clampf(colour.r, 0.0, 1.0), clampf(colour.g, 0.0, 1.0), clampf(colour.b, 0.0, 1.0), clampf(colour.a, 0.0, 1.0))


# ---------------------------------------------------------------------------------------------------
# Reading: the words a row says
# ---------------------------------------------------------------------------------------------------


## The reading the project asks for (the setting), "As written" when unset or unknown.
static func project_reading() -> String:
	var chosen: String = str(ProjectSettings.get_setting(SETTING_NAME, READ_WRITTEN))
	return chosen if READ_CHOICES.has(chosen) else READ_WRITTEN


## The words a colour value reads as under `reading`, "" when `text` is not a colour the editor can read.
## `alpha_slot` false is a slot with no alpha (an @export_color_no_alpha): alpha is never read there.
## A form that cannot say the colour (hex and 0-255 stop at 1, a name needs a name) falls back: a name to
## the hex, anything else to the value as it was written.
static func read_as(text: String, reading: String = READ_WRITTEN, alpha_slot: bool = true) -> String:
	var info: Dictionary = parse(text)
	if not bool(info.get("ok", false)):
		return ""
	return read_info(info, text.strip_edges(), reading, alpha_slot)


static func read_info(info: Dictionary, source: String, reading: String, alpha_slot: bool = true) -> String:
	var written: String = written_words(info, source)
	if reading == READ_WRITTEN or not READ_CHOICES.has(reading):
		return written
	var colour: Color = info["color"]
	var see_through: bool = alpha_slot and colour.a < 1.0 - 1.0e-6
	var overbright: bool = bool(info.get("overbright", false))
	match reading:
		READ_HEX:
			if overbright:
				return written
			return hex_text(colour, see_through)
		READ_RGB255:
			if overbright:
				return written
			var eight: PackedStringArray = [str(roundi(colour.r * 255.0)), str(roundi(colour.g * 255.0)), str(roundi(colour.b * 255.0))]
			if see_through:
				eight.append(str(roundi(colour.a * 255.0)))
			return ", ".join(eight)
		READ_RGB1:
			var unit: PackedStringArray = [number_text(colour.r), number_text(colour.g), number_text(colour.b)]
			if see_through:
				unit.append(number_text(colour.a))
			return ", ".join(unit)
		READ_HSV:
			var hsv: Array = hsv_of(colour)
			var words: String = "H %d  S %d  V %d" % [roundi(hsv[0] * 360.0), roundi(hsv[1] * 100.0), roundi(hsv[2] * 100.0)]
			if see_through:
				words += "  A %d" % roundi(colour.a * 100.0)
			return words
		READ_NAME:
			if overbright:
				return written
			var found: String = str(info.get("name", ""))
			if found.is_empty():
				found = name_of(colour)
			if not found.is_empty():
				return found.to_lower() if info.get("form") == FORM_CONSTANT or info.get("form") == FORM_BARE_NAME \
					else (str(info.get("word", "")) if not str(info.get("word", "")).is_empty() and info.get("form") == FORM_NAME_CALL else found.to_lower())
			return hex_text(colour, see_through)
	return written


## The value in the form it was typed, the call around a hex or a name dropped: `Color("#ff8000")` reads
## `#ff8000`, `Color.ORANGE` reads `orange`. Every other form reads exactly as written.
static func written_words(info: Dictionary, source: String) -> String:
	match str(info.get("form", "")):
		FORM_CONSTANT:
			return str(info.get("name", "")).to_lower()
		FORM_NAME_CALL, FORM_BARE_NAME, FORM_HEX_CALL, FORM_HTML, FORM_BARE_HEX:
			return str(info.get("word", source))
	return source


## `#RRGGBB`, or `#RRGGBBAA` when `with_alpha` - capitals, the way the Inspector writes it.
static func hex_text(colour: Color, with_alpha: bool = false) -> String:
	return "#" + colour.to_html(with_alpha).to_upper()


## A channel as a short number: three decimals at most, no trailing zeros, `1` for 1.
static func number_text(value: float) -> String:
	var text: String = String.num(value, 3)
	if text.contains("."):
		while text.ends_with("0"):
			text = text.substr(0, text.length() - 1)
		if text.ends_with("."):
			text = text.substr(0, text.length() - 1)
	if text == "-0" or text.is_empty():
		return "0"
	return text


## Hue (0..1), saturation, value of a colour whose brightest channel may be above 1.
static func hsv_of(colour: Color) -> Array:
	var top: float = maxf(colour.r, maxf(colour.g, colour.b))
	var bottom: float = minf(colour.r, minf(colour.g, colour.b))
	var spread: float = top - bottom
	var hue: float = 0.0
	if spread > 1.0e-9:
		if is_equal_approx(top, colour.r):
			hue = fposmod((colour.g - colour.b) / spread, 6.0)
		elif is_equal_approx(top, colour.g):
			hue = (colour.b - colour.r) / spread + 2.0
		else:
			hue = (colour.r - colour.g) / spread + 4.0
		hue /= 6.0
	var saturation: float = spread / top if top > 1.0e-9 else 0.0
	return [hue, saturation, top]


## Which mode the picker opens in for a value, under the reading the project asked for.
static func picker_mode(info: Dictionary, reading: String = READ_WRITTEN) -> String:
	if bool(info.get("overbright", false)):
		return MODE_RGB
	if reading == READ_HSV:
		return MODE_HSV
	if reading != READ_WRITTEN and READ_CHOICES.has(reading):
		return MODE_RGB
	return str(info.get("mode", MODE_RGB))


# ---------------------------------------------------------------------------------------------------
# Writing: a pick, in the form it was typed
# ---------------------------------------------------------------------------------------------------


## The text that replaces `source` for the pick `colour`: the same call, the same argument count, the same
## hex length and case. Returns {text, note}. `note` is the sentence the hover and the picker say when the
## form had to change (a named colour picked to an unnamed one is written as hex, never silently).
## `alpha_slot` false never writes an alpha.
static func write_back(source: String, colour: Color, alpha_slot: bool = true) -> Dictionary:
	var info: Dictionary = parse(source)
	var picked: Color = colour if alpha_slot else Color(colour.r, colour.g, colour.b, 1.0)
	if not bool(info.get("ok", false)) or not bool(info.get("editable", true)):
		return {"text": "Color(\"%s\")" % hex_digits(picked, picked.a < 1.0 - 1.0e-6 and alpha_slot, false, true), "note": "", "switched": false}
	var see_through: bool = alpha_slot and picked.a < 1.0 - 1.0e-6
	match str(info["form"]):
		FORM_RGB:
			var rgb: PackedStringArray = [number_text(picked.r), number_text(picked.g), number_text(picked.b)]
			if alpha_slot and (int(info["args"]) >= 4 or see_through):
				rgb.append(number_text(picked.a))
			return _wrote("Color(%s)" % ", ".join(rgb))
		FORM_HEX_CALL:
			var quote: String = str(info.get("quote", "\""))
			return _wrote("Color(%s%s%s)" % [quote, _hex_like(info, picked, alpha_slot), quote])
		FORM_HTML:
			var html_quote: String = str(info.get("quote", "\""))
			return _wrote("Color.html(%s%s%s)" % [html_quote, _hex_like(info, picked, alpha_slot), html_quote])
		FORM_BARE_HEX:
			return _wrote("Color(\"%s\")" % hex_digits(picked, see_through or (int(info.get("digits", 6)) == 8 and alpha_slot), true, false))
		FORM_HEX_INT:
			var digit_count: int = 8 if (int(info.get("digits", 8)) == 8 or see_through) and alpha_slot else 6
			var packed: String = picked.to_html(digit_count == 8)
			packed = packed.to_upper() if bool(info.get("upper", false)) else packed
			return _wrote("Color.hex(%s%s)" % [str(info.get("prefix", "0x")), packed])
		FORM_CONSTANT:
			var named: String = name_of(Color(picked.r, picked.g, picked.b, picked.a))
			if not named.is_empty() and not _overbright(picked):
				return _wrote("Color.%s" % named)
			var was: String = "Color.%s" % str(info.get("name", ""))
			var spelled: String = hex_digits(picked, see_through, true, false)
			return {"text": "Color(\"%s\")" % spelled, "switched": true,
				"note": EventSheetL10n.translate("was %s: %s has no name, written as hex") % [was, spelled]}
		FORM_BARE_NAME, FORM_NAME_CALL:
			var word_quote: String = str(info.get("quote", "\""))
			var picked_name: String = name_of(picked)
			if not picked_name.is_empty() and not _overbright(picked):
				return _wrote("Color(%s%s%s)" % [word_quote, _name_like(info, picked_name), word_quote])
			var typed: String = str(info.get("word", ""))
			var as_hex: String = hex_digits(picked, see_through, true, false)
			return {"text": "Color(\"%s\")" % as_hex, "switched": true,
				"note": EventSheetL10n.translate("was %s: %s has no name, written as hex") % [typed, as_hex]}
		FORM_COLOR8, FORM_RGBA8:
			var prefix: String = "Color8(" if str(info["form"]) == FORM_COLOR8 else "Color.from_rgba8("
			var bytes: PackedStringArray = [str(roundi(clampf(picked.r, 0.0, 1.0) * 255.0)), str(roundi(clampf(picked.g, 0.0, 1.0) * 255.0)),
				str(roundi(clampf(picked.b, 0.0, 1.0) * 255.0))]
			if alpha_slot and (int(info["args"]) >= 4 or see_through):
				bytes.append(str(roundi(clampf(picked.a, 0.0, 1.0) * 255.0)))
			return _wrote("%s%s)" % [prefix, ", ".join(bytes)])
		FORM_HSV:
			var hsv: Array = hsv_of(picked)
			var parts: PackedStringArray = [number_text(hsv[0]), number_text(hsv[1]), number_text(hsv[2])]
			if alpha_slot and (int(info["args"]) >= 4 or see_through):
				parts.append(number_text(picked.a))
			return _wrote("Color.from_hsv(%s)" % ", ".join(parts))
		FORM_OKHSL:
			var ok_parts: PackedStringArray = [number_text(picked.ok_hsl_h), number_text(picked.ok_hsl_s), number_text(picked.ok_hsl_l)]
			if alpha_slot and (int(info["args"]) >= 4 or see_through):
				ok_parts.append(number_text(picked.a))
			return _wrote("Color.from_ok_hsl(%s)" % ", ".join(ok_parts))
		FORM_BASE_ALPHA:
			var opaque := Color(picked.r, picked.g, picked.b, 1.0)
			var inner: Dictionary = write_back(_base_source(info), opaque, false)
			# A written-out hex or word rides as the bare string: Color("#3399ff", 0.5) is the real constructor.
			var base_text: String = str(inner["text"])
			if base_text.begins_with("Color(") and base_text.ends_with(")") and (base_text.contains("(\"") or base_text.contains("('")):
				base_text = base_text.trim_prefix("Color(").trim_suffix(")")
			return {"text": "Color(%s, %s)" % [base_text, number_text(picked.a)], "note": str(inner.get("note", "")),
				"switched": bool(inner.get("switched", false))}
	return _wrote("Color(%s, %s, %s)" % [number_text(picked.r), number_text(picked.g), number_text(picked.b)])


static func _wrote(text: String) -> Dictionary:
	return {"text": text, "note": "", "switched": false}


## The first argument of a Color(base, alpha) value, as it was written.
static func _base_source(info: Dictionary) -> String:
	var base: Dictionary = info["base"]
	return str(base.get("source_text", ""))


static func _overbright(colour: Color) -> bool:
	return maxf(colour.r, maxf(colour.g, colour.b)) > 1.0 + 1.0e-6


## The hex digits of a pick in the length, case and "#" the typed hex used. Six digits grow to eight only
## for a see-through pick; eight stay eight.
static func _hex_like(info: Dictionary, picked: Color, alpha_slot: bool) -> String:
	var digit_count: int = int(info.get("digits", 6))
	var see_through: bool = alpha_slot and picked.a < 1.0 - 1.0e-6
	var eight: bool = alpha_slot and (digit_count == 8 or digit_count == 4 or see_through)
	return hex_digits(picked, eight, bool(info.get("hash", true)), bool(info.get("upper", false)))


static func hex_digits(colour: Color, with_alpha: bool, with_hash: bool, upper: bool) -> String:
	var digits: String = colour.to_html(with_alpha)
	if upper:
		digits = digits.to_upper()
	return ("#" if with_hash else "") + digits


## A constant's word in the case the source word was typed in ("orange", "Orange", "ORANGE"), keeping an
## underscore only if one was typed.
static func _name_like(info: Dictionary, constant_name: String) -> String:
	var typed: String = str(info.get("word", ""))
	var word: String = constant_name.to_lower() if typed.contains("_") else constant_name.replace("_", "").to_lower()
	if typed.length() > 1 and typed == typed.to_upper():
		return word.to_upper()
	if not typed.is_empty() and typed[0] == typed[0].to_upper() and typed[0] != typed[0].to_lower():
		return word.capitalize().replace(" ", "") if not typed.contains("_") else word.capitalize().replace(" ", "_")
	return word


## A value typed bare into a Color slot - `#ff8000`, `orange` - written as a Color call so the emitted line
## is valid; every other value is returned as typed.
static func normalise_slot_text(text: String) -> String:
	var info: Dictionary = parse(text)
	if not bool(info.get("ok", false)):
		return text
	match str(info["form"]):
		FORM_BARE_HEX, FORM_BARE_NAME:
			return "Color(\"%s\")" % text.strip_edges()
	return text


# ---------------------------------------------------------------------------------------------------
# Copy As
# ---------------------------------------------------------------------------------------------------


## The forms the right-click menu can copy a colour in, each with the exact text it copies: [label, text]
## pairs, in the menu's order. A form that cannot say the colour is left out.
static func copy_forms(text: String, alpha_slot: bool = true) -> Array:
	var info: Dictionary = parse(text)
	if not bool(info.get("ok", false)):
		return []
	var source: String = text.strip_edges()
	var colour: Color = info["color"]
	var see_through: bool = alpha_slot and colour.a < 1.0 - 1.0e-6
	var overbright: bool = bool(info.get("overbright", false))
	var forms: Array = [["As written", source]]
	if not overbright:
		forms.append(["Hex", hex_text(colour, see_through)])
		var eight: PackedStringArray = [str(roundi(colour.r * 255.0)), str(roundi(colour.g * 255.0)), str(roundi(colour.b * 255.0))]
		if see_through:
			eight.append(str(roundi(colour.a * 255.0)))
		forms.append(["RGB 0-255", ", ".join(eight)])
	var unit: PackedStringArray = [number_text(colour.r), number_text(colour.g), number_text(colour.b)]
	if see_through:
		unit.append(number_text(colour.a))
	forms.append(["RGB 0-1", ", ".join(unit)])
	forms.append(["HSV", read_info(info, source, READ_HSV, alpha_slot)])
	var named: String = str(info.get("name", "")) if not overbright else ""
	if named.is_empty() and not overbright:
		named = name_of(colour)
	if not named.is_empty():
		forms.append(["Name", named.to_lower()])
	forms.append(["Godot code", "Color(%s)" % ", ".join(unit)])
	return forms


# ---------------------------------------------------------------------------------------------------
# The hover card
# ---------------------------------------------------------------------------------------------------


## What hovering a colour's square says: {text, code}. `text` is the plain words (what the colour is, and
## anything the reader should know about its form); `code` is the value as the file holds it.
static func hover_card(text: String, alpha_slot: bool = true, switched_note: String = "") -> Dictionary:
	var source: String = text.strip_edges()
	var info: Dictionary = parse(source)
	if not bool(info.get("ok", false)):
		return {}
	var colour: Color = info["color"]
	var lines: PackedStringArray = []
	var see_through: bool = alpha_slot and colour.a < 1.0 - 1.0e-6
	if bool(info.get("overbright", false)):
		var channel: String = "red" if is_equal_approx(maxf(colour.r, maxf(colour.g, colour.b)), colour.r) else \
			("green" if is_equal_approx(maxf(colour.g, colour.b), colour.g) else "blue")
		lines.append(EventSheetL10n.translate("Brighter than the screen can show: %s is %s. Drawn here at full %s; in the game it is extra bright where glow or HDR is on.") \
			% [EventSheetL10n.translate(channel), number_text(maxf(colour.r, maxf(colour.g, colour.b))), EventSheetL10n.translate(channel)])
	elif bool(info.get("folded", false)):
		lines.append(EventSheetL10n.translate("Worked out from constants: %s. Picking a colour here would replace the whole expression, so the click opens the parameters dialog instead of the picker.") % hex_text(colour, see_through))
	elif see_through:
		lines.append(EventSheetL10n.translate("%d%% see-through. The checkerboard behind the square is what shows through.") % roundi((1.0 - colour.a) * 100.0))
	elif not str(info.get("name", "")).is_empty() and str(info["form"]) in [FORM_CONSTANT, FORM_NAME_CALL, FORM_BARE_NAME]:
		lines.append(EventSheetL10n.translate("Godot's named colour %s, %s.") % [str(info["name"]), hex_text(colour).to_lower()])
	else:
		lines.append(hex_text(colour, see_through))
	if bool(info.get("deprecated", false)):
		lines.append(EventSheetL10n.translate("Color8 is deprecated in Godot 4.7: Color.from_rgba8 replaces it. It is kept as you typed it."))
	if not switched_note.is_empty():
		lines.append(switched_note.substr(0, 1).to_upper() + switched_note.substr(1) + ".")
	var code: String = source
	if see_through and not bool(info.get("folded", false)):
		code += "  ·  " + hex_text(colour, true).to_lower()
	return {"text": " ".join(lines), "code": code}


## The words of a value only the running game knows. `start_text` is the colour the variable starts as
## (Color slot holding a variable whose default is a constant), "" when there is none.
static func runtime_card(text: String, start_text: String = "") -> Dictionary:
	var words: String = EventSheetL10n.translate("Worked out while the game runs: this is not a constant, so it can change.")
	if not start_text.is_empty():
		words = EventSheetL10n.translate("Worked out while the game runs: %s is a variable and can change. It starts as %s.") % [text.strip_edges(), start_text]
	return {"text": words, "code": text.strip_edges()}


## The accepted forms, as the field note of a Color slot says them.
static func accepted_forms_note() -> String:
	return EventSheetL10n.translate("Accepted: #ff8000 or ff8000, a name (orange), Color(1, 0.5, 0) or Color(1, 0.5, 0, 0.5), Color(\"#ff8000\"), Color.ORANGE, Color8 / Color.from_rgba8 (0-255), Color.from_hsv, Color.from_ok_hsl, or an expression that gives a Color.")


## The words in the help strip for a Color slot that holds text that is not a colour.
static func wrong_type_words(slot_label: String, text: String) -> String:
	return EventSheetL10n.translate("%s expects a Color. %s is a piece of text, not a colour. Write #ff8000, orange, Color(1, 0.5, 0) or Color.ORANGE, or click the value to pick one.") \
		% [slot_label, text.strip_edges()]
