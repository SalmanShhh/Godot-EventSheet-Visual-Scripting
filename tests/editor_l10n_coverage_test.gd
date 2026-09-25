# EventForge - the reader that decides what the editor asks to translate.
#
# EventSheetL10n.translate() falls back to its English key when nothing carries it, so a message
# that never reached the CSVs looks perfectly fine in English and stays English in every other
# language - a half-translated dialog nobody's suite ever notices. The sweep that closes that gap
# (every literal translate() argument has a TEMPLATE.csv row) is translation_harvest_test, and the
# locale files are held to the template, key for key and with no empty cell, by
# vocabulary_l10n_test. This file pins the one thing both lean on: the reader that turns a script
# into the keys it asks for.
#
# A call whose argument is COMPUTED (a variable, a joined string, a table lookup) cannot be read
# from here and is skipped - the sweep pins what it can see, which is every literal the UI says.
#
# THE READER ITSELF lives in tools/harvest_translations.gd, because the harvester that WRITES a
# missing row and the gate that FAILS on one have to agree, to the character, about what a literal
# is. Two copies of that reader would be two answers waiting to disagree. This file pins the
# reader's behaviour, one line per shape, so the shared reader cannot drift unnoticed.
@tool
class_name EditorL10nCoverageTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
## The shared translate()-literal reader.
const HARVEST := preload("res://tools/harvest_translations.gd")
const TEMPLATE_PATH := "res://addons/eventsheet/translations/TEMPLATE.csv"


static func run() -> bool:
	var ok: bool = true
	var template: Array = _csv_rows(TEMPLATE_PATH)
	var template_keys: Dictionary = {}
	for row: PackedStringArray in template:
		template_keys[row[0]] = true
	ok = _check("the template is there and full", template_keys.size() > 100, true) and ok
	ok = _test_the_reader() and ok
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
