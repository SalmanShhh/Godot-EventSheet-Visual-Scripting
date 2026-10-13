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
#      names already read the same;
#   5. the search-only names - an API call or an action title a reader brings from another engine -
#      find the row that ships for them, pack verbs included, and are said back as they were written.

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = _every_phrase_names_a_shipped_verb()
	ok = _typed_phrases_find_their_verb() and ok
	ok = _a_found_row_says_the_phrase_back() and ok
	ok = _familiar_names_find_what_ships() and ok
	return ok


static func _every_phrase_names_a_shipped_verb() -> bool:
	var shipped: Dictionary = {}
	for descriptor: ACEDescriptor in ACERegistry.get_all_descriptors():
		shipped[str(descriptor.ace_id)] = true
	# The pack verbs the search-only names reach are read off their packs' own scripts, the same way
	# the picker's definitions are.
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	var flock: Node = load("res://eventsheet_addons/flock/flock_behavior.gd").new()
	var flock_3d: Node = load("res://eventsheet_addons/flock_3d/flock_3d_behavior.gd").new()
	registry.refresh_from_sources([load("res://eventsheet_addons/debug_overlay/debug_overlay_addon.gd").new(),
		flock, flock_3d], true)
	for definition: ACEDefinition in registry.get_all_definitions():
		if definition.provider_id in ["DebugOverlayAddon", "FlockBehavior", "Flock3DBehavior"]:
			shipped[str(definition.id)] = true
	flock.free()
	flock_3d.free()
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
		["the phrase is said on its own line", ACEPickerDialog.also_called_line("Change Scene", "go to layout"),
			"You may know it as go to layout from another engine - the word you typed and this verb are one row."],
		["nothing when the names already agree", ACEPickerDialog.also_called_line("Wait", "wait"), ""],
		["nothing when no phrase found it", ACEPickerDialog.also_called_line("Wait", ""), ""],
	])


static func _familiar_names_find_what_ships() -> bool:
	return SUPPORT.pins("foreign_search_words_test", [
		["WaitForSeconds", ACEPickerDialog.foreign_query_matches("WaitForSeconds"), {"Wait": "WaitForSeconds"}],
		["a random wait is Wait with Random in it", ACEPickerDialog.foreign_query_matches("random wait"),
			{"Wait": "Random Wait", "RandomRange": "Random Wait"}],
		["Random.Range", ACEPickerDialog.foreign_query_matches("Random.Range"),
			{"RandomRange": "Random.Range", "RandomInt": "Random.Range"}],
		["the longest phrase typed is the one said back", ACEPickerDialog.foreign_query_matches("get random child"),
			{"PickRandomInstance": "Get Random Child"}],
		["pick random instance", ACEPickerDialog.foreign_query_matches("pick random instance"),
			{"PickRandomInstance": "Pick random instance"}],
		["string.Format", ACEPickerDialog.foreign_query_matches("string.format"), {"TextFromPattern": "string.Format"}],
		["Build String", ACEPickerDialog.foreign_query_matches("build string"), {"TextFromPattern": "Build String"}],
		["magnitude", ACEPickerDialog.foreign_query_matches("magnitude"), {"VectorLength": "magnitude"}],
		["Get Speed", ACEPickerDialog.foreign_query_matches("get speed"),
			{"VectorLength": "Get Speed", "GetVelocity2D": "Get Speed", "GetVelocity3D": "Get Speed"}],
		["Debug.Log is the console line", ACEPickerDialog.foreign_query_matches("Debug.Log"), {"PrintLog": "Debug.Log"}],
		["a value on screen is the overlay's watch", ACEPickerDialog.foreign_query_matches("show a value on screen"),
			{"method:watch_value": "Show a value on screen"}],
		["Debug.DrawRay", ACEPickerDialog.foreign_query_matches("Debug.DrawRay"),
			{"method:draw_ray": "Debug.DrawRay", "method:draw_ray_3d": "Debug.DrawRay"}],
		["Draw Debug Ray", ACEPickerDialog.foreign_query_matches("draw debug ray"),
			{"method:draw_ray": "Draw Debug Ray", "method:draw_ray_3d": "Draw Debug Ray"}],
		["GetRange", ACEPickerDialog.foreign_query_matches("GetRange"), {"ArraySlice": "GetRange"}],
		["the line says the name as written", ACEPickerDialog.also_called_line("Wait",
			str(ACEPickerDialog.foreign_query_matches("waitforseconds").get("Wait", ""))),
			"You may know it as WaitForSeconds from another engine - the word you typed and this verb are one row."],
		["an importer phrase is still said as itself", EventSheetForeignACEMap.phrase_as_written("go to layout"),
			"go to layout"],
	])
