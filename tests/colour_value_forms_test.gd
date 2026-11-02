# Godot EventSheets - every way a colour is written: how it reads, and what a pick writes back.
#
# One table of typed form -> reading -> write-back, over the one reader (`EventSheetColourValue`). The
# rule it holds: a pick moves the colour and no other byte - same call, same argument count, same hex
# length, case and "#" - and a reading changes the words a row says and never the text it keeps.
@tool
class_name ColourValueFormsTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const NAME := "colour_value_forms_test"
const PICK := Color(0.2, 0.6, 1.0, 1.0)
const PICK_HALF := Color(0.2, 0.6, 1.0, 0.5)


static func run() -> bool:
	var ok: bool = true
	var rows: Array = []

	# Typed form -> [how it reads As written, what the pick #3399ff writes].
	var written: Dictionary = {
		"Color(1, 0.5, 0)": ["Color(1, 0.5, 0)", "Color(0.2, 0.6, 1)"],
		"Color(1, 0.5, 0, 0.5)": ["Color(1, 0.5, 0, 0.5)", "Color(0.2, 0.6, 1, 1)"],
		"Color(\"#ff8000\")": ["#ff8000", "Color(\"#3399ff\")"],
		"Color(\"#FF8000\")": ["#FF8000", "Color(\"#3399FF\")"],
		"Color(\"ff8000\")": ["ff8000", "Color(\"3399ff\")"],
		"Color(\"#ff800080\")": ["#ff800080", "Color(\"#3399ffff\")"],
		"Color.html(\"#ff8000\")": ["#ff8000", "Color.html(\"#3399ff\")"],
		"Color.ORANGE": ["orange", "Color(\"#3399ff\")"],
		"Color.DODGER_BLUE": ["dodger_blue", "Color(\"#3399ff\")"],
		"Color(\"orange\")": ["orange", "Color(\"#3399ff\")"],
		"Color8(255, 128, 0)": ["Color8(255, 128, 0)", "Color8(51, 153, 255)"],
		"Color.from_rgba8(255, 128, 0)": ["Color.from_rgba8(255, 128, 0)", "Color.from_rgba8(51, 153, 255)"],
		"Color.from_hsv(0.08, 1, 1)": ["Color.from_hsv(0.08, 1, 1)", "Color.from_hsv(0.583, 0.8, 1)"],
		"Color(Color.RED, 0.5)": ["Color(Color.RED, 0.5)", "Color(\"#3399ff\", 1)"],
		"Color.hex(0xff8000ff)": ["Color.hex(0xff8000ff)", "Color.hex(0x3399ffff)"],
		"#ff8000": ["#ff8000", "Color(\"#3399ff\")"],
		"orange": ["orange", "Color(\"#3399ff\")"],
	}
	for typed: String in written:
		var expected: Array = written[typed]
		rows.append(["%s reads as written" % typed, EventSheetColourValue.read_as(typed), expected[0]])
		rows.append(["%s writes %s" % [typed, "the pick"], str(EventSheetColourValue.write_back(typed, PICK)["text"]), expected[1]])

	# A named pick stays named, in the case it was typed.
	var dodger := Color(0.11764706, 0.5647059, 1.0, 1.0)
	rows.append(["a constant picked to a name stays a constant", str(EventSheetColourValue.write_back("Color.ORANGE", dodger)["text"]), "Color.DODGER_BLUE"])
	rows.append(["a name word picked to a name stays a word", str(EventSheetColourValue.write_back("Color(\"orange\")", dodger)["text"]), "Color(\"dodgerblue\")"])
	rows.append(["a capitalised word keeps its capital", str(EventSheetColourValue.write_back("Color(\"Orange\")", dodger)["text"]), "Color(\"Dodgerblue\")"])
	rows.append(["a named-to-unnamed switch says so", str(EventSheetColourValue.write_back("Color.ORANGE", PICK)["note"]).begins_with("was Color.ORANGE"), true])
	rows.append(["a hex pick never says so", str(EventSheetColourValue.write_back("Color(\"#ff8000\")", PICK)["note"]), ""])

	# Hex length: six grow to eight only for a see-through pick; eight stay eight.
	rows.append(["six digits grow for a see-through pick", str(EventSheetColourValue.write_back("Color(\"#ff8000\")", PICK_HALF)["text"]), "Color(\"#3399ff80\")"])
	rows.append(["three numbers gain a fourth for a see-through pick", str(EventSheetColourValue.write_back("Color(1, 0.5, 0)", PICK_HALF)["text"]), "Color(0.2, 0.6, 1, 0.5)"])
	rows.append(["Color8 gains a fourth for a see-through pick", str(EventSheetColourValue.write_back("Color8(255, 128, 0)", PICK_HALF)["text"]), "Color8(51, 153, 255, 128)"])
	rows.append(["a no-alpha slot never writes alpha", str(EventSheetColourValue.write_back("Color(1, 0.5, 0)", PICK_HALF, false)["text"]), "Color(0.2, 0.6, 1)"])
	rows.append(["a no-alpha slot keeps six hex digits", str(EventSheetColourValue.write_back("Color(\"#ff8000\")", PICK_HALF, false)["text"]), "Color(\"#3399ff\")"])
	rows.append(["a base and alpha keep their two arguments", str(EventSheetColourValue.write_back("Color(Color.RED, 0.5)", PICK_HALF)["text"]), "Color(\"#3399ff\", 0.5)"])
	rows.append(["a base that stays named", str(EventSheetColourValue.write_back("Color(Color.RED, 0.5)", Color(1, 0, 0, 0.25))["text"]), "Color(Color.RED, 0.25)"])

	# Overbright: numbers never clamped on the way back, the square clamped.
	rows.append(["overbright writes the numbers it was given", str(EventSheetColourValue.write_back("Color(2, 0.5, 0)", Color(2.4, 0.6, 0))["text"]), "Color(2.4, 0.6, 0)"])
	rows.append(["overbright is marked", bool(EventSheetColourValue.parse("Color(2, 0.5, 0)")["overbright"]), true])
	rows.append(["the square holds the channels at 1", EventSheetColourValue.square_colour(Color(2, 0.5, 0)), Color(1, 0.5, 0)])

	# Folding and run-time values.
	rows.append(["a lerp of constants folds", EventSheetColourValue.classify("Color.RED.lerp(Color.BLUE, 0.5)"), "colour"])
	rows.append(["a folded value is not editable by a pick", bool(EventSheetColourValue.parse("Color.RED.lerp(Color.BLUE, 0.5)")["editable"]), false])
	rows.append(["a variable is worked out while the game runs", EventSheetColourValue.classify("tint"), "runtime"])
	rows.append(["a node's property is worked out while the game runs", EventSheetColourValue.classify("other.modulate"), "runtime"])
	rows.append(["a lerp of variables is worked out while the game runs", EventSheetColourValue.classify("lerp(start_tint, end_tint, t)"), "runtime"])
	rows.append(["text that is not a colour", EventSheetColourValue.classify("\"orange-ish\""), "wrong"])
	rows.append(["a number is not a colour", EventSheetColourValue.classify("3"), "wrong"])
	rows.append(["a colour's name in quotes is a value Godot turns into a colour", EventSheetColourValue.classify("\"red\""), "runtime"])
	rows.append(["and so is a hex in quotes", EventSheetColourValue.classify("\"#ff8000\""), "runtime"])
	rows.append(["and a whole number in hex", EventSheetColourValue.classify("0xff8000ff"), "runtime"])
	rows.append(["an empty slot", EventSheetColourValue.classify("  "), "empty"])
	rows.append(["a bare hex typed in a slot is accepted", EventSheetColourValue.classify("#ff8000"), "colour"])
	rows.append(["a bare hex is written as a call", EventSheetColourValue.normalise_slot_text("#ff8000"), "Color(\"#ff8000\")"])
	rows.append(["a bare name is written as a call", EventSheetColourValue.normalise_slot_text("orange"), "Color(\"orange\")"])
	rows.append(["an expression is left alone", EventSheetColourValue.normalise_slot_text("other.modulate"), "other.modulate"])

	# The readings.
	var ghost: String = "Color(1, 1, 1, 0.5)"
	var lamp: String = "Color(2, 0.5, 0)"
	var reading_table: Array = [
		["Color(\"#ff8000\")", EventSheetColourValue.READ_HEX, "#FF8000"],
		["Color(\"#ff8000\")", EventSheetColourValue.READ_RGB255, "255, 128, 0"],
		["Color(\"#ff8000\")", EventSheetColourValue.READ_RGB1, "1, 0.502, 0"],
		["Color(\"#ff8000\")", EventSheetColourValue.READ_HSV, "H 30  S 100  V 100"],
		["Color(\"#ff8000\")", EventSheetColourValue.READ_NAME, "#FF8000"],
		[ghost, EventSheetColourValue.READ_HEX, "#FFFFFF80"],
		[ghost, EventSheetColourValue.READ_RGB255, "255, 255, 255, 128"],
		[ghost, EventSheetColourValue.READ_RGB1, "1, 1, 1, 0.5"],
		[ghost, EventSheetColourValue.READ_HSV, "H 0  S 0  V 100  A 50"],
		["Color.ORANGE", EventSheetColourValue.READ_HEX, "#FFA500"],
		["Color.ORANGE", EventSheetColourValue.READ_RGB255, "255, 165, 0"],
		["Color.ORANGE", EventSheetColourValue.READ_NAME, "orange"],
		[lamp, EventSheetColourValue.READ_HEX, "Color(2, 0.5, 0)"],
		[lamp, EventSheetColourValue.READ_RGB255, "Color(2, 0.5, 0)"],
		[lamp, EventSheetColourValue.READ_RGB1, "2, 0.5, 0"],
		[lamp, EventSheetColourValue.READ_HSV, "H 15  S 100  V 200"],
		[lamp, EventSheetColourValue.READ_NAME, "Color(2, 0.5, 0)"],
		["Color(0, 0, 0, 0.5)", EventSheetColourValue.READ_HEX, "#00000080"],
		["Color(0, 0, 0, 0.5)", EventSheetColourValue.READ_RGB255, "0, 0, 0, 128"],
		["lerp(start_tint, end_tint, t)", EventSheetColourValue.READ_HEX, ""],
	]
	for entry: Array in reading_table:
		rows.append(["%s read as %s" % [entry[0], entry[1]], EventSheetColourValue.read_as(str(entry[0]), str(entry[1])), entry[2]])
	rows.append(["a no-alpha slot never reads alpha", EventSheetColourValue.read_as(ghost, EventSheetColourValue.READ_HEX, false), "#FFFFFF"])
	rows.append(["a no-alpha slot never reads alpha in 0-255", EventSheetColourValue.read_as(ghost, EventSheetColourValue.READ_RGB255, false), "255, 255, 255"])

	# Every Godot constant is a named colour.
	rows.append(["the table names the whole constant list", EventSheetColourValue.constant_count(), EventSheetColourValue.CONSTANT_NAMES.size()])
	rows.append(["DODGER_BLUE is a word", EventSheetColourValue.constant_for_word("dodgerblue"), "DODGER_BLUE"])
	rows.append(["a colour with a name is found by value", EventSheetColourValue.name_of(Color.ORANGE), "ORANGE"])
	rows.append(["a colour without a name is not", EventSheetColourValue.name_of(PICK), ""])
	# The engine's own value of each constant, asked through a script that names them all.
	var lines: PackedStringArray = ["static func all() -> Dictionary:", "	return {"]
	for constant_name: String in EventSheetColourValue.CONSTANT_NAMES:
		lines.append("		\"%s\": Color.%s," % [constant_name, constant_name])
	lines.append("	}")
	var probe := GDScript.new()
	probe.source_code = "
".join(lines) + "
"
	var reloaded: int = probe.reload()
	rows.append(["the constant list parses as engine constants", reloaded, OK])
	if reloaded == OK:
		var engine_values: Dictionary = probe.call("all")
		for constant_name: String in EventSheetColourValue.CONSTANT_NAMES:
			rows.append(["Color.%s is the engine's colour" % constant_name, EventSheetColourValue.constant_colour(constant_name), engine_values[constant_name]])

	# Copy As: the exact text each option copies, and the forms that cannot say the colour left out.
	var copy_orange: Array = EventSheetColourValue.copy_forms("Color(\"#ff8000\")")
	rows.append(["Copy As labels for a hex colour", _labels(copy_orange), ["As written", "Hex", "RGB 0-255", "RGB 0-1", "HSV", "Godot code"]])
	rows.append(["Copy As hex", _text_of(copy_orange, "Hex"), "#FF8000"])
	rows.append(["Copy As godot code", _text_of(copy_orange, "Godot code"), "Color(1, 0.502, 0)"])
	rows.append(["Copy As written is the file's own spelling", _text_of(copy_orange, "As written"), "Color(\"#ff8000\")"])
	rows.append(["Copy As labels for a constant", _labels(EventSheetColourValue.copy_forms("Color.ORANGE")), ["As written", "Hex", "RGB 0-255", "RGB 0-1", "HSV", "Name", "Godot code"]])
	rows.append(["Copy As labels for an overbright colour", _labels(EventSheetColourValue.copy_forms(lamp)), ["As written", "RGB 0-1", "HSV", "Godot code"]])
	rows.append(["Copy As carries the alpha of a see-through colour", _text_of(EventSheetColourValue.copy_forms("Color(0, 0, 0, 0.5)"), "Hex"), "#00000080"])
	rows.append(["a run-time value copies nothing", EventSheetColourValue.copy_forms("other.modulate"), []])

	# The picker opens in the value's own mode.
	rows.append(["from_hsv opens HSV", EventSheetColourValue.picker_mode(EventSheetColourValue.parse("Color.from_hsv(0.08, 1, 1)")), "hsv"])
	rows.append(["from_ok_hsl opens OKHSL", EventSheetColourValue.picker_mode(EventSheetColourValue.parse("Color.from_ok_hsl(0.16, 1, 0.68)")), "okhsl"])
	rows.append(["an overbright value opens RGB", EventSheetColourValue.picker_mode(EventSheetColourValue.parse("Color.from_hsv(0.08, 1, 2)")), "rgb"])
	rows.append(["a reading of HSV opens HSV", EventSheetColourValue.picker_mode(EventSheetColourValue.parse("Color(1, 0.5, 0)"), "HSV"), "hsv"])
	rows.append(["a reading of Hex opens RGB", EventSheetColourValue.picker_mode(EventSheetColourValue.parse("Color.from_hsv(0.08, 1, 1)"), "Hex"), "rgb"])
	rows.append(["Color8 is marked deprecated", bool(EventSheetColourValue.parse("Color8(255, 128, 0)")["deprecated"]), true])

	ok = SUPPORT.pins(NAME, rows) and ok
	return ok


static func _labels(forms: Array) -> Array:
	var out: Array = []
	for entry: Variant in forms:
		out.append(str((entry as Array)[0]))
	return out


static func _text_of(forms: Array, label: String) -> String:
	for entry: Variant in forms:
		if str((entry as Array)[0]) == label:
			return str((entry as Array)[1])
	return ""
