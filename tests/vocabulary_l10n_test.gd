# Godot EventSheets - the bundled editor translations cover the shipped vocabulary.
#
# The l10n sweep is the step a vocabulary wave forgets, because nothing breaks when it is skipped:
# EventSheetL10n.translate falls back to its English argument, so an untranslated verb looks fine in
# English and silently stays English in all eight bundled languages. This test is that gate.
#
# What it proves, in the order the failures actually happen:
#   1. LOCKSTEP. Every file under addons/eventsheet/translations/ carries the SAME keys in the SAME
#      order, and every language cell is filled (TEMPLATE.csv is the ready-to-fill copy, so its
#      second column is empty BY DESIGN and is checked for keys only).
#   2. COVERAGE. Every user-facing string of the value/text/table/resource wave - display name,
#      description, category, display template, parameter label, parameter description and dropdown
#      option label - is a key in every bundled language.
#   3. IT ACTUALLY TRANSLATES. A handful of strings are switched through and their exact translated
#      VALUE is pinned, so a catalog that loads but resolves nothing would still fail.
#   4. THE MENUS. Every label a context menu shows is keyed in every bundled language. A wave that
#      adds vocabulary usually remembers the CSVs; a wave that adds a MENU COMMAND forgets, and the
#      new item is then the one English line in an otherwise translated menu. Read straight out of
#      dock/context_menus.gd, so a command added tomorrow is swept the moment it is declared.
#
# Coverage is checked against the CSV KEY SET rather than against translate()'s output, and that is
# load-bearing: a translation may legitimately equal its English source ("JSON" in every language,
# "Code" in German and French), so a "translated != English" test would report those as missing and
# would ALSO pass for a key whose cell was filled with the English text by accident. Key presence is
# the question; the value pins in step 3 are what prove the catalog is live.
#
# Modules are loaded BY PATH, never by class_name, so the test does not depend on the editor class
# cache having been regenerated for a newly added module.
@tool
class_name VocabularyL10nTest
extends RefCounted

const TRANSLATIONS_DIR := "res://addons/eventsheet/translations"
const TEMPLATE_FILE := "TEMPLATE.csv"

## The bundled languages. English is the source, so it is not a file.
const LOCALES: Array[String] = ["de", "es", "fr", "it", "ja", "ko", "ru", "zh_CN"]

## Modules whose WHOLE descriptor set shipped in this wave.
const NEW_MODULES: Array[String] = [
	"res://addons/eventforge/registration/modules/clipboard_aces.gd",
	"res://addons/eventforge/registration/modules/resource_aces.gd",
	"res://addons/eventforge/registration/modules/table_aces.gd",
	"res://addons/eventforge/registration/modules/text_extract_aces.gd",
	"res://addons/eventforge/registration/modules/text_format_aces.gd",
	"res://addons/eventforge/registration/modules/spatial_aces.gd",
	# The reading waves that followed: the game shapes every project writes by hand, the words for
	# authoring an editor plugin, the 3D move/turn/face/place vocabulary, and the cursor-and-canvas
	# words. Each of these modules is WHOLLY new, so the whole module is owed and swept.
	"res://addons/eventforge/registration/modules/game_mechanics_aces.gd",
	"res://addons/eventforge/registration/modules/editor_author_aces.gd",
	"res://addons/eventforge/registration/modules/spatial_words_aces.gd",
	"res://addons/eventforge/registration/modules/cursor_canvas_aces.gd",
]

## Modules that already shipped and GAINED verbs in this wave: only the named ids are swept, so the
## test says what this wave owes rather than retro-failing on vocabulary that predates it.
const EXTENDED_MODULES: Dictionary = {
	"res://addons/eventforge/registration/modules/comparison_aces.gd": [
		"TextIsANumber", "TextIsAWholeNumber", "ContainsAnyOf", "ContainsAllOf", "ContainsNoneOf",
		"NumberFromText", "WholeNumberFromText", "IsNothing", "HasSomething",
	],
	"res://addons/eventforge/registration/modules/collection_aces.gd": [
		"NumberOr", "TextOr", "ListOr", "RecordOr", "ValueOr", "PartOf", "SetPartOf",
		# The flow wave: waits that can end two ways, retries, and the race.
		"WaitUntil", "WaitForAllOf", "WaitForAnyOf", "WaitSucceeded", "WaitTimedOut",
		"FirstToFinish", "RetryUpTo", "RetryAttemptNumber", "StopRetrying", "RetriesExhausted",
		"WaitBeforeNextTry",
	],
	# The flow/diagnostics wave: trails, measurements and the frame-budget conditions.
	"res://addons/eventforge/registration/modules/dev_aces.gd": [
		"RememberInTrail", "TrailValues", "TrailLowest", "TrailHighest", "TrailAverage",
		"TrailNewest", "TrailLength", "LogTrail", "SaveTrailCsv", "ClearTrail",
		"FrameOverBudget", "FpsBelowFor", "StartMeasuring", "StopMeasuring", "MeasuredLast",
		"MeasuredAverage", "MeasuredPeak", "LogMeasurements", "ClearMeasurements",
	],
	# The flow wave: the service registry, the capability loop and the deferral verbs.
	"res://addons/eventforge/registration/modules/node_aces.gd": [
		"RegisterAsService", "ServiceNamed", "HasService", "ForEachNodeThatCan",
		"DoAfterFrame", "CallLater", "SetPropertyDeferred", "OnceThisFrame",
		# The hierarchy wave: parenting, the two follow-flag escape hatches, and the child picks.
		"RemoveChild", "HierarchyAddChild", "HierarchyRemoveFromParent", "SetIgnoreParentMovement",
		"CopyPlaceTo", "StopCopyingPlace", "ForEachChildOf", "MoveChild", "QueueFreeNode",
	],
	# The hierarchy wave's two triggers, and the element-input trigger that shipped beside them.
	"res://addons/eventforge/registration/modules/core_aces.gd": [
		"OnControlInput", "OnChildEnteredTree", "OnChildExitingTree",
	],
	# The data wave: watched data files and the data-folder validation verbs.
	"res://addons/eventforge/registration/modules/resource_aces.gd": [
		"WatchDataFile", "ReloadDataAsset", "signal:data_file_changed",
		"DataFolderProblems", "DataFolderIsValid", "ValidateDataFolder",
	],
	# The flow wave: named spawns, the success/failure report seam and the once-per-thing guards.
	"res://addons/eventforge/registration/modules/system_aces.gd": [
		"SpawnSceneAs", "TheSpawned", "SpawnIsAlive", "signal:scene_spawned",
		"signal:verb_failed", "signal:verb_succeeded", "ReportFailure", "ReportSuccess",
		"AtMostEvery", "Poke", "ClearPoke", "HasBeenQuiet", "OnlyOncePerNode",
		"OnlyOncePerName", "OnlyOnceThisSceneLoad", "ForgetOnceFor",
	],
	# W6 - the two rows that build a menu and answer the item that was chosen out of it.
	"res://addons/eventforge/registration/modules/editor_object_aces.gd": [
		"MenuAddItem", "OnMenuItemChosen",
	],
	# Y2 / Y3 - the combo wave: the slice of a clip a move may be cancelled in, the per-object
	# freeze, and the two ways an animation tells the game when something happens.
	"res://addons/eventforge/registration/modules/animation_player_aces.gd": [
		"AnimationIsBetween", "PauseAnimationFor",
		"OnAnimationFrame", "SpriteAnimationFrameIs", "OnAnimationEvent",
	],
	# Y2 - the press remembered for a moment so an input made slightly too early still lands,
	# in seconds and in the frame-counted spelling beside it.
	"res://addons/eventforge/registration/modules/timed_input_aces.gd": [
		"BufferInput", "IsInputBuffered", "ConsumeBufferedInput",
		"BufferInputFrames", "IsInputBufferedFrames", "ConsumeBufferedInputFrames",
	],
}

## One pinned translation per language, chosen from a string whose translation differs from its
## English source in every one of them - the proof that the catalog is loaded and resolving.
const PINNED: Dictionary = {
	"de": "Freigabecode für",
	"es": "Código para compartir de",
	"fr": "Code de partage pour",
	"it": "Codice di condivisione per",
	"ja": "共有コード",
	"ko": "공유 코드",
	"ru": "Код обмена для",
	"zh_CN": "分享码",
}

const PINNED_KEY := "Share Code For"

## Where the editor's context-menu commands are declared, and the calls that declare one.
const CONTEXT_MENUS_FILE := "res://addons/eventsheet/editor/dock/context_menus.gd"
const MENU_ITEM_PATTERN := "add_(?:item|check_item|radio_check_item|submenu_item|icon_item)\\(\"([^\"]+)\""


static func run() -> bool:
	var passed: bool = true
	passed = _test_files_are_in_lockstep() and passed
	passed = _test_every_language_cell_is_filled() and passed
	passed = _test_wave_vocabulary_has_keys() and passed
	passed = _test_menu_commands_have_keys() and passed
	passed = _test_the_catalog_actually_translates() and passed
	return passed


# ── 1. Lockstep ──


static func _test_files_are_in_lockstep() -> bool:
	var passed: bool = true
	var reference: PackedStringArray = _read_keys(TEMPLATE_FILE)
	passed = _check("TEMPLATE.csv carries keys", reference.is_empty(), false) and passed
	for locale: String in LOCALES:
		var keys: PackedStringArray = _read_keys("%s.csv" % locale)
		var drift: String = _first_difference(reference, keys)
		passed = _check("%s.csv matches TEMPLATE key for key" % locale, drift, "") and passed
	return passed


## The first place two key lists disagree, as a sentence - a diff a maintainer can act on, rather
## than a count that only says "something moved".
static func _first_difference(expected: PackedStringArray, actual: PackedStringArray) -> String:
	for index: int in mini(expected.size(), actual.size()):
		if expected[index] != actual[index]:
			return "row %d is \"%s\", expected \"%s\"" % [index + 1, actual[index], expected[index]]
	if expected.size() != actual.size():
		return "has %d keys, expected %d" % [actual.size(), expected.size()]
	return ""


# ── 2. No blank cells ──


static func _test_every_language_cell_is_filled() -> bool:
	var passed: bool = true
	for locale: String in LOCALES:
		var blanks: PackedStringArray = PackedStringArray()
		for row: PackedStringArray in _read_rows("%s.csv" % locale):
			if row.size() < 2 or row[1].strip_edges().is_empty():
				blanks.append(row[0])
		if not blanks.is_empty():
			print("  %s.csv blank cells: %s" % [locale, ", ".join(blanks)])
		passed = _check("%s.csv has no blank cells" % locale, blanks.size(), 0) and passed
	return passed


# ── 3. Coverage ──


static func _test_wave_vocabulary_has_keys() -> bool:
	var strings: PackedStringArray = _wave_strings()
	var passed: bool = _check("the wave contributes strings to sweep", strings.is_empty(), false)
	for locale: String in LOCALES:
		var keys: Dictionary = {}
		for key: String in _read_keys("%s.csv" % locale):
			keys[key] = true
		var missing: PackedStringArray = PackedStringArray()
		for text: String in strings:
			if not keys.has(text):
				missing.append(text)
		if not missing.is_empty():
			print("  %s.csv is missing %d wave strings, first: \"%s\"" % [locale, missing.size(), missing[0]])
		passed = _check("%s.csv covers the wave vocabulary" % locale, missing.size(), 0) and passed
	return passed


## Every string of the wave that reaches a user: the seven roles the editor routes through the
## translation layer. Ids, templates and hints never translate and are not collected.
static func _wave_strings() -> PackedStringArray:
	var seen: Dictionary = {}
	var strings: PackedStringArray = PackedStringArray()
	for path: String in NEW_MODULES:
		_collect(path, PackedStringArray(), seen, strings)
	for path: Variant in EXTENDED_MODULES:
		_collect(str(path), PackedStringArray(EXTENDED_MODULES[path]), seen, strings)
	return strings


## `only_ids` empty means every descriptor in the module qualifies.
static func _collect(path: String, only_ids: PackedStringArray, seen: Dictionary, strings: PackedStringArray) -> void:
	var script: GDScript = load(path)
	if script == null:
		return
	for descriptor: ACEDescriptor in script.get_descriptors():
		if not only_ids.is_empty() and not only_ids.has(descriptor.ace_id):
			continue
		_add(descriptor.display_name, seen, strings)
		_add(descriptor.description, seen, strings)
		_add(descriptor.category, seen, strings)
		_add(descriptor.get_display_text(), seen, strings)
		for parameter: ACEParam in descriptor.params:
			if parameter == null:
				continue
			_add(parameter.get_param_name(), seen, strings)
			_add(parameter.get_param_description(), seen, strings)
			for option: Variant in parameter.options:
				if option is Dictionary:
					_add(str((option as Dictionary).get("label", "")), seen, strings)


static func _add(text: String, seen: Dictionary, strings: PackedStringArray) -> void:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty() or seen.has(trimmed):
		return
	seen[trimmed] = true
	strings.append(trimmed)


# ── 4. Menu commands ──


static func _test_menu_commands_have_keys() -> bool:
	var labels: PackedStringArray = _menu_labels()
	var passed: bool = _check("context_menus.gd declares menu labels", labels.is_empty(), false)
	for locale: String in LOCALES:
		var keys: Dictionary = {}
		for key: String in _read_keys("%s.csv" % locale):
			keys[key] = true
		var missing: PackedStringArray = PackedStringArray()
		for label: String in labels:
			if not keys.has(label):
				missing.append(label)
		if not missing.is_empty():
			print("  %s.csv is missing %d menu label(s): %s" % [locale, missing.size(), ", ".join(missing)])
		passed = _check("%s.csv covers every context-menu command" % locale, missing.size(), 0) and passed
	return passed


## Every literal label the context menus put in front of a user. PopupMenu item text is
## auto-translated through the plugin's translation domain, so a label with no CSV key renders in
## English inside an otherwise translated menu - the failure this reads the source to prevent.
static func _menu_labels() -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	var source: String = FileAccess.get_file_as_string(CONTEXT_MENUS_FILE)
	if source.is_empty():
		return labels
	var pattern: RegEx = RegEx.create_from_string(MENU_ITEM_PATTERN)
	if pattern == null:
		return labels
	for found: RegExMatch in pattern.search_all(source):
		var label: String = found.get_string(1)
		if not labels.has(label):
			labels.append(label)
	return labels


# ── 5. The catalog is live ──


static func _test_the_catalog_actually_translates() -> bool:
	var passed: bool = true
	EventSheetL10n.rescan()
	for locale: String in LOCALES:
		EventSheetL10n.set_locale(locale)
		passed = _check("%s translates a wave verb" % locale,
			EventSheetL10n.translate(PINNED_KEY), str(PINNED[locale])) and passed
	# The catalogs are static session state: leave English behind for the rest of the suite.
	EventSheetL10n.set_locale("en")
	EventSheetL10n.rescan()
	passed = _check("English is restored", EventSheetL10n.translate(PINNED_KEY), PINNED_KEY) and passed
	return passed


# ── Reading the CSVs ──


static func _read_rows(file_name: String) -> Array:
	var rows: Array = []
	var file: FileAccess = FileAccess.open("%s/%s" % [TRANSLATIONS_DIR, file_name], FileAccess.READ)
	if file == null:
		return rows
	var header: bool = true
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		if header:
			header = false
			continue
		rows.append(row)
	file.close()
	return rows


static func _read_keys(file_name: String) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for row: PackedStringArray in _read_rows(file_name):
		keys.append(row[0])
	return keys


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] vocabulary_l10n_test: %s" % label)
		return true
	print("[FAIL] vocabulary_l10n_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
