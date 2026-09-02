# EventForge - every string the editor asks to translate is actually translatable.
#
# EventSheetL10n.translate() falls back to its English key when nothing carries it, so a message
# that never reached the CSVs looks perfectly fine in English and stays English in every other
# language - a half-translated dialog nobody's suite ever notices. This gate closes that: it reads
# the plugin's own scripts, collects every translate() call whose argument IS a literal, and fails
# on any key TEMPLATE.csv does not carry. It then holds the shipped locales to the template: the
# same keys, in the same set, with no empty cell (an empty cell is an untranslated string wearing a
# translation's clothes).
#
# A call whose argument is COMPUTED (a variable, a joined string, a table lookup) cannot be read
# from here and is skipped - the gate pins what it can see, which is every literal the UI says.
#
# THE READER ITSELF lives in tools/harvest_translations.gd, because the harvester that WRITES a
# missing row and the gate that FAILS on one have to agree, to the character, about what a literal
# is. Two copies of that reader would be two answers waiting to disagree. This file still pins the
# reader's behaviour, one line per shape, so the shared reader cannot drift unnoticed.
@tool
class_name EditorL10nCoverageTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
## The shared translate()-literal reader, and the roots it sweeps.
const HARVEST := preload("res://tools/harvest_translations.gd")
const TRANSLATIONS_DIR := "res://addons/eventsheet/translations"
const TEMPLATE_PATH := "res://addons/eventsheet/translations/TEMPLATE.csv"
const SHIPPED_LOCALES: PackedStringArray = ["de", "es", "fr", "it", "ja", "ko", "ru", "zh_CN"]


static func run() -> bool:
	var ok: bool = true
	var template: Array = _csv_rows(TEMPLATE_PATH)
	var template_keys: Dictionary = {}
	for row: PackedStringArray in template:
		template_keys[row[0]] = true
	ok = _check("the template is there and full", template_keys.size() > 100, true) and ok
	ok = _test_the_reader() and ok
	ok = _test_literals_are_in_the_template(template_keys) and ok
	ok = _test_locales_match_the_template(template_keys) and ok
	return ok


## The reader itself, on one line of each shape it has to handle. A gate that cannot read its own
## input passes for the wrong reason, so this is pinned before anything is swept with it.
static func _test_the_reader() -> bool:
	var ok: bool = _check("a plain literal is a key",
		HARVEST.translated_keys("EventSheetL10n.translate(\"Copied %s.\") % name"),
		PackedStringArray(["Copied %s."]))
	ok = _check("both halves of a ternary are keys",
		HARVEST.translated_keys("EventSheetL10n.translate(\"Else\" if plain else \"Else If\")"),
		PackedStringArray(["Else", "Else If"])) and ok
	ok = _check("an alias of the same call is read the same way",
		HARVEST.translated_keys("EventSheetSentence.translate(\"the file's text\")"),
		PackedStringArray(["the file's text"])) and ok
	ok = _check("an escaped quote stays inside its key",
		HARVEST.translated_keys("EventSheetL10n.translate(\"say \\\"go\\\" now\")"),
		PackedStringArray(["say \"go\" now"])) and ok
	ok = _check("a computed argument is nobody's key",
		HARVEST.translated_keys("EventSheetL10n.translate(str(entry.get(\"display\", \"\")))"),
		PackedStringArray()) and ok
	ok = _check("and neither is a joined one",
		HARVEST.translated_keys("EventSheetL10n.translate(\"a \" + noun)"), PackedStringArray()) and ok
	return ok


## Every literal the editor asks to translate has a row in TEMPLATE.csv. The failure prints the
## strings themselves with the file each came from, because "3 keys missing" is not actionable.
static func _test_literals_are_in_the_template(template_keys: Dictionary) -> bool:
	var uncovered: PackedStringArray = PackedStringArray()
	var seen: int = 0
	for root: String in HARVEST.SCRIPT_ROOTS:
		for path: String in HARVEST.scripts_under(root):
			for key: String in HARVEST.translated_keys(FileAccess.get_file_as_string(path)):
				seen += 1
				if not template_keys.has(key):
					uncovered.append("%s  <- %s" % [key, path.get_file()])
	var ok: bool = _check("the sweep found the plugin's translated strings", seen > 300, true)
	return _check("every translated literal has a template row", uncovered, PackedStringArray()) and ok


## Each shipped locale carries the template's keys, all of them, none of them blank.
static func _test_locales_match_the_template(template_keys: Dictionary) -> bool:
	var ok: bool = true
	for locale: String in SHIPPED_LOCALES:
		var missing: PackedStringArray = PackedStringArray()
		var blank: PackedStringArray = PackedStringArray()
		var carried: Dictionary = {}
		for row: PackedStringArray in _csv_rows("%s/%s.csv" % [TRANSLATIONS_DIR, locale]):
			carried[row[0]] = true
			if row[0] == "keys":
				continue
			if row.size() < 2 or row[1].strip_edges().is_empty():
				blank.append(row[0])
		for key: String in template_keys:
			if not carried.has(key):
				missing.append(key)
		ok = _check("%s carries every template key" % locale, missing, PackedStringArray()) and ok
		ok = _check("%s leaves no cell empty" % locale, blank, PackedStringArray()) and ok
	return ok


static func _csv_rows(path: String) -> Array:
	var rows: Array = []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return rows
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() == 1 and line[0].is_empty():
			continue
		rows.append(line)
	return rows


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("editor_l10n_coverage_test", label, actual, expected)
