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
