@tool
class_name LookMarkerCorpusTest
extends RefCounted

# Godot EventSheets - the marker a look writes must never change, whichever way it is written.
#
# Markers already in people's scripts are a promise. A look that is now a FILE is written two ways: the
# structured attributes it always had (`drawer` and `range`), and the two attributes any file look has
# (`look` and `look_args`). For every shipped look that is a file, a generated corpus of argument sets
# proves the two spellings write the same bytes, that the line re-opens as a sheet and writes itself again
# unchanged, and that the importer keeps a legacy word on its legacy attributes. A look a project added
# (its marker word has no structured attributes) round-trips through `look` and `look_args` alone.
#
# The corpus is generated from a fixed seed, so a failure names the same argument set every time.

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "look_marker_corpus_test"
const SEED: int = 4172
const ROUNDS: int = 200


static func run() -> bool:
	var passed: bool = true
	passed = _progress_bar_is_written_the_same_two_ways() and passed
	passed = _the_other_shipped_looks_are_written_the_same_two_ways() and passed
	passed = _a_look_the_project_added_round_trips() and passed
	passed = _a_value_that_cannot_ride_a_marker_writes_nothing() and passed
	passed = _a_marker_naming_an_absent_look_survives_the_round_trip() and passed
	return passed


## The numbers a person might type into a bound: whole, negative, fractional, large, with a leading plus.
static func _number_text(generator: RandomNumberGenerator) -> String:
	match generator.randi_range(0, 5):
		0:
			return str(generator.randi_range(0, 500))
		1:
			return str(generator.randi_range(-500, 0))
		2:
			return String.num(generator.randf_range(-50.0, 50.0), 2)
		3:
			return str(generator.randi_range(1000, 99999))
		4:
			return "0"
	return "100"


static func _progress_bar_is_written_the_same_two_ways() -> bool:
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = SEED
	var different: Array = []
	var not_reopened: Array = []
	var not_stable: Array = []
	var moved_to_generic: Array = []
	for round: int in range(ROUNDS):
		var low: String = _number_text(generator)
		var high: String = _number_text(generator)
		var type_name: String = "int" if generator.randi_range(0, 1) == 0 else "float"
		var legacy: String = EventSheetCompiler._drawer_export_prefix({"drawer": "progress_bar", "range": {"min": low, "max": high}}, type_name)
		var generic: String = EventSheetCompiler._drawer_export_prefix({"look": "progress_bar", "look_args": [low, high]}, type_name)
		if legacy != generic:
			different.append([low, high, legacy, generic])
			continue
		var line: String = "%svar bar: %s = 5" % [legacy, type_name]
		var source: String = "extends Node2D\n\n%s\n" % line
		var reopened: EventSheetResource = SUPPORT.reopen(source)
		var variable: LocalVariable = _find(reopened, "bar")
		if variable == null:
			not_reopened.append([low, high])
			continue
		var attributes: Dictionary = variable.attributes if variable.attributes is Dictionary else {}
		# A legacy word comes back as the legacy attributes, never as the generic pair.
		if str(attributes.get("drawer", "")) != "progress_bar" or attributes.has("look"):
			moved_to_generic.append([low, high])
		if EventSheetCompiler._emit_tree_variable_line(variable) != line or SUPPORT.reemit(source, "user://look_marker_corpus_test.gd") != source:
			not_stable.append([low, high])
	return SUPPORT.pins(NAME, [
		["200 generated bounds: the two spellings write the same line", different, []],
		["200 generated bounds: every line reopens as a variable", not_reopened, []],
		["200 generated bounds: a legacy word stays on its legacy attributes", moved_to_generic, []],
		["200 generated bounds: reopened, the line is written again byte for byte", not_stable, []],
	])


## The shipped looks beyond the progress bar, each with the structured attributes it always had and the
## generic pair, over a generated corpus of arguments. A look with no arguments has one spelling to prove.
static func _the_other_shipped_looks_are_written_the_same_two_ways() -> bool:
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = SEED + 2
	var rows: Array = []
	var looks: Array = [
		{"word": "swatch_row", "type": "Color", "value": "Color(1, 1, 1, 1)", "args": func() -> Array: return []},
		{"word": "texture_preview", "type": "Texture2D", "value": "null", "args": func() -> Array: return []},
		{"word": "curve_editor", "type": "Curve", "value": "null", "args": func() -> Array: return []},
		{"word": "corners", "type": "Vector4", "value": "Vector4(0, 0, 0, 0)", "args": func() -> Array: return []},
		{"word": "vector_dial", "type": "Vector2", "value": "Vector2(0, 0)", "args": func() -> Array: return [_number_text(generator)]},
		{"word": "min_max", "type": "Vector2", "value": "Vector2(0, 0)", "args": func() -> Array: return [_number_text(generator), _number_text(generator)]},
		{"word": "table_row", "type": "int", "value": "0", "args": func() -> Array: return [_name_text(generator), _name_text(generator)]},
		{"word": "unit", "type": "float", "value": "0.0", "args": func() -> Array: return _unit_args(generator)},
		{"word": "toggle_row", "type": "String", "value": "\"\"", "args": func() -> Array: return _toggle_args(generator)},
		{"word": "table", "type": "Array", "value": "[]", "args": func() -> Array: return _table_args(generator)},
	]
	for look: Dictionary in looks:
		var word: String = str(look["word"])
		var different: Array = []
		var not_reopened: Array = []
		var moved_to_generic: Array = []
		var not_stable: Array = []
		for round: int in range(ROUNDS):
			var args: Array = (look["args"] as Callable).call()
			var legacy_attributes: Dictionary = {"drawer": word}
			match word:
				"vector_dial":
					legacy_attributes["range"] = {"min": "0", "max": args[0], "step": "1"}
				"min_max":
					legacy_attributes["range"] = {"min": args[0], "max": args[1], "step": "1"}
				"table_row":
					legacy_attributes["table_row_table"] = args[0]
					legacy_attributes["table_row_column"] = args[1]
				"unit":
					legacy_attributes["unit_kinds"] = args[0]
					legacy_attributes["unit_store"] = args[1]
				"toggle_row":
					legacy_attributes["toggle_options"] = args[0]
					legacy_attributes["toggle_segmented"] = args[1]
					legacy_attributes["toggle_icons"] = args[2]
				"table":
					legacy_attributes["table_columns"] = args[0]
			var legacy: String = EventSheetCompiler._drawer_export_prefix(legacy_attributes, str(look["type"]))
			var generic: String = EventSheetCompiler._drawer_export_prefix({"look": word, "look_args": _file_arguments(word, args)}, str(look["type"]))
			# An icon source holds colons of its own, which cannot ride the generic spelling: that look is
			# written by its structured attributes alone, and only their round trip is proven.
			if word == "toggle_row" and not str(args[2]).is_empty():
				generic = legacy
			if legacy != generic:
				different.append([args, legacy, generic])
				continue
			var line: String = "%svar thing: %s = %s" % [legacy, look["type"], look["value"]]
			var source: String = "extends Node2D\n\n%s\n" % line
			var variable: LocalVariable = _find(SUPPORT.reopen(source), "thing")
			if variable == null:
				not_reopened.append(args)
				continue
			var attributes: Dictionary = variable.attributes if variable.attributes is Dictionary else {}
			if str(attributes.get("drawer", "")) != word or attributes.has("look"):
				moved_to_generic.append(args)
			if EventSheetCompiler._emit_tree_variable_line(variable) != line or SUPPORT.reemit(source, "user://look_marker_corpus_test.gd") != source:
				not_stable.append(args)
		rows.append(["%s: the two spellings write the same line" % word, different, []])
		rows.append(["%s: every line reopens as a variable" % word, not_reopened, []])
		rows.append(["%s: a legacy word stays on its legacy attributes" % word, moved_to_generic, []])
		rows.append(["%s: reopened, the line is written again byte for byte" % word, not_stable, []])
	return SUPPORT.pins(NAME, rows)


## A name a person might give a table or a column: lower case, with digits and underscores.
static func _name_text(generator: RandomNumberGenerator) -> String:
	var words: Array = ["drops", "loot", "name", "title", "row_2", "item_names", "x1", "enemies"]
	return str(words[generator.randi_range(0, words.size() - 1)])


static func _a_look_the_project_added_round_trips() -> bool:
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = SEED + 1
	var words: Array = ["none", "number", "a_b", "x1", "Caption"]
	var lost: Array = []
	var unstable: Array = []
	var not_generic: Array = []
	for round: int in range(ROUNDS):
		var args: Array = [str(generator.randi_range(-20, 300)), words[generator.randi_range(0, words.size() - 1)],
			"true" if generator.randi_range(0, 1) == 1 else "false"]
		var attributes: Dictionary = {"look": "star_rating", "look_args": args}
		var line: String = EventSheetCompiler._drawer_export_prefix(attributes, "int") + "var stars: int = 3"
		var source: String = "extends Node2D\n\n%s\n" % line
		var variable: LocalVariable = _find(SUPPORT.reopen(source), "stars")
		if variable == null:
			lost.append(args)
			continue
		var back: Dictionary = variable.attributes if variable.attributes is Dictionary else {}
		if str(back.get("look", "")) != "star_rating" or back.get("look_args") != args or back.has("drawer"):
			not_generic.append([args, back])
		if EventSheetCompiler._emit_tree_variable_line(variable) != line or SUPPORT.reemit(source, "user://look_marker_corpus_test.gd") != source:
			unstable.append(args)
	return SUPPORT.pins(NAME, [
		["200 generated argument sets: every line reopens as a variable", lost, []],
		["200 generated argument sets: the look and its arguments come back as they were", not_generic, []],
		["200 generated argument sets: reopened, the line is written again byte for byte", unstable, []],
	])


static func _a_value_that_cannot_ride_a_marker_writes_nothing() -> bool:
	return SUPPORT.pins(NAME, [
		["a quote", EventSheetCompiler._drawer_export_prefix({"look": "star_rating", "look_args": ["a\"b"]}, "int"), ""],
		["a colon", EventSheetCompiler._drawer_export_prefix({"look": "star_rating", "look_args": ["a:b"]}, "int"), ""],
		["a line break", EventSheetCompiler._drawer_export_prefix({"look": "star_rating", "look_args": ["a\nb"]}, "int"), ""],
		["a name that is not an identifier", EventSheetCompiler._drawer_export_prefix({"look": "star-rating", "look_args": []}, "int"), ""],
		["no arguments at all", EventSheetCompiler._drawer_export_prefix({"look": "star_rating"}, "int"),
			"@export_custom(PROPERTY_HINT_NONE, \"eventsheet:star_rating\") "],
		["a variable with neither a drawer nor a look", EventSheetCompiler._drawer_export_prefix({}, "int"), ""],
	])


## A script that names a look this project does not have must survive opening and saving untouched:
## the importer carries the marker, and the compiler writes it back.
static func _a_marker_naming_an_absent_look_survives_the_round_trip() -> bool:
	var line: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:look_nobody_installed:1:two\") var odd: int = 4"
	var source: String = "extends Node2D\n\n%s\n" % line
	var variable: LocalVariable = _find(SUPPORT.reopen(source), "odd")
	var opened_as_a_block: bool = variable == null
	return SUPPORT.pins(NAME, [
		["it opens as a variable, not a verbatim block", opened_as_a_block, false],
		["it is saved untouched byte for byte", SUPPORT.reemit(source, "user://look_marker_corpus_test.gd"), source],
	])


static func _find(sheet: EventSheetResource, variable_name: String) -> LocalVariable:
	if sheet == null:
		return null
	for entry: Variant in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == variable_name:
			return entry as LocalVariable
	return null


## The words a unit list or a choice list is drawn from.
const WORDS: Array = ["px", "world", "screen", "s", "ms", "frames", "deg", "turn", "easy", "normal", "hard", "left", "right"]


## Units and the one that is stored: [kinds, store].
static func _unit_args(generator: RandomNumberGenerator) -> Array:
	var kinds: Array = []
	for count: int in range(generator.randi_range(1, 4)):
		var word: String = str(WORDS[generator.randi_range(0, WORDS.size() - 1)])
		if not kinds.has(word):
			kinds.append(word)
	return [kinds, kinds[generator.randi_range(0, kinds.size() - 1)]]


## Choices, whether the buttons are equal width, and an icon source ("" for none).
static func _toggle_args(generator: RandomNumberGenerator) -> Array:
	var options: Array = []
	for count: int in range(generator.randi_range(2, 4)):
		var word: String = str(WORDS[generator.randi_range(0, WORDS.size() - 1)])
		if not options.has(word):
			options.append(word)
	return [options, generator.randi_range(0, 1) == 1, "res://icons/%s.png" if generator.randi_range(0, 3) == 0 else ""]


## Table columns: a list of {name, type}.
static func _table_args(generator: RandomNumberGenerator) -> Array:
	var types: Array = ["String", "int", "float", "bool"]
	var columns: Array = []
	for count: int in range(generator.randi_range(1, 4)):
		columns.append({"name": "%s_%d" % [_name_text(generator), count], "type": types[generator.randi_range(0, types.size() - 1)]})
	return [columns]


## The arguments the generic spelling carries for a look whose structured attributes hold lists: the
## same text the marker writes after the look's name, one value per colon.
static func _file_arguments(word: String, args: Array) -> Array:
	match word:
		"unit":
			return ["kinds=%s,store=%s" % ["|".join(PackedStringArray(args[0])), args[1]]]
		"toggle_row":
			var written: Array = [",".join(PackedStringArray(args[0]))]
			if bool(args[1]):
				written.append("segmented")
			return written
		"table":
			var pairs: PackedStringArray = PackedStringArray()
			for column: Dictionary in args[0]:
				pairs.append("%s=%s" % [column["name"], column["type"]])
			return [",".join(pairs)]
	return args
