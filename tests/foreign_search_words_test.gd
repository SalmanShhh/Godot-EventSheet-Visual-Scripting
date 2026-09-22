@tool
class_name ForeignSearchWordsTest
extends RefCounted

# EventForge - the picker answers to the names another event-sheet editor gives its verbs.
#
# The project importer already holds a table from that editor's row ids to this plugin's verbs, so
# a reader who types "go to layout" should land on the verb the importer would have written. The
# search reads that same table rather than a second list, and these pins keep the two joined:
#   1. every phrase the table yields names a verb that ships, so the search can never offer a dead
#      answer after a row is renamed or retired;
#   2. the phrases a reader actually types find the verb they mean, by id;
#   3. a stand-in row (one with no real equivalent) never becomes an answer;
#   4. a found row says the typed phrase back beside its own name, and says nothing when the two
#      names already read the same.

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = _every_phrase_names_a_shipped_verb()
	ok = _typed_phrases_find_their_verb() and ok
	ok = _a_found_row_says_the_phrase_back() and ok
	return ok


static func _every_phrase_names_a_shipped_verb() -> bool:
	var shipped: Dictionary = {}
	for descriptor: ACEDescriptor in ACERegistry.get_all_descriptors():
		shipped[str(descriptor.ace_id)] = true
	var missing: PackedStringArray = PackedStringArray()
	var phrases: Dictionary = EventSheetForeignACEMap.search_phrases()
	var sorted: Array = phrases.keys()
	sorted.sort()
	for phrase: Variant in sorted:
		for ace_id: Variant in phrases[phrase]:
			if not shipped.has(str(ace_id)):
				missing.append("%s -> %s" % [phrase, ace_id])
	return SUPPORT.pins("foreign_search_words_test", [
		["every phrase names a verb that ships", missing, PackedStringArray()],
		["the table yields phrases at all", phrases.has("go to layout"), true],
	])


static func _typed_phrases_find_their_verb() -> bool:
	return SUPPORT.pins("foreign_search_words_test", [
		["go to layout", ACEPickerDialog.foreign_query_matches("go to layout"), {"ChangeScene": "go to layout"}],
		["restart layout", ACEPickerDialog.foreign_query_matches("restart layout"), {"ReloadScene": "restart layout"}],
		["every x seconds", ACEPickerDialog.foreign_query_matches("every x seconds"), {"EveryXSeconds": "every x seconds"}],
		["create object", ACEPickerDialog.foreign_query_matches("create object"), {"SpawnScene": "create object"}],
		["compare two values", ACEPickerDialog.foreign_query_matches("compare two values"),
			{"CompareValues": "compare two values"}],
		["a stand-in row is never an answer", ACEPickerDialog.foreign_query_matches("set canvas size"), {}],
		["two letters is still typing", ACEPickerDialog.foreign_query_matches("go"), {}],
	])


static func _a_found_row_says_the_phrase_back() -> bool:
	return SUPPORT.pins("foreign_search_words_test", [
		["the phrase follows the name, quoted", ACEPickerDialog.foreign_name_note("Change Scene", "go to layout"),
			"Change Scene  ·  \"go to layout\""],
		["nothing when the names already agree", ACEPickerDialog.foreign_name_note("Wait", "wait"), "Wait"],
		["nothing when no phrase found it", ACEPickerDialog.foreign_name_note("Wait", ""), "Wait"],
	])
