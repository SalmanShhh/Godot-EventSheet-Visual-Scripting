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
@tool
class_name EditorL10nCoverageTest
extends RefCounted

## Every spelling of the call, matched by its tail. `EventSheetL10n.translate` reads the catalog;
## `EventSheetSentence.translate` and `EventSheets.translate` are one-line aliases of it, and a gate
## keyed to the first class name alone walked straight past them - ten of the row grammar's own
## words among them ("angle", "the file's text"). Nothing else in the plugin ends a call this way,
## so the tail covers an alias nobody has written yet for free.
const CALL := ".translate("
const SCRIPT_ROOT := "res://addons/eventsheet"
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
		translated_keys("EventSheetL10n.translate(\"Copied %s.\") % name"),
		PackedStringArray(["Copied %s."]))
	ok = _check("both halves of a ternary are keys",
		translated_keys("EventSheetL10n.translate(\"Else\" if plain else \"Else If\")"),
		PackedStringArray(["Else", "Else If"])) and ok
	ok = _check("an alias of the same call is read the same way",
		translated_keys("EventSheetSentence.translate(\"the file's text\")"),
		PackedStringArray(["the file's text"])) and ok
	ok = _check("an escaped quote stays inside its key",
		translated_keys("EventSheetL10n.translate(\"say \\\"go\\\" now\")"),
		PackedStringArray(["say \"go\" now"])) and ok
	ok = _check("a computed argument is nobody's key",
		translated_keys("EventSheetL10n.translate(str(entry.get(\"display\", \"\")))"),
		PackedStringArray()) and ok
	ok = _check("and neither is a joined one",
		translated_keys("EventSheetL10n.translate(\"a \" + noun)"), PackedStringArray()) and ok
	return ok


## Every literal the editor asks to translate has a row in TEMPLATE.csv. The failure prints the
## strings themselves with the file each came from, because "3 keys missing" is not actionable.
static func _test_literals_are_in_the_template(template_keys: Dictionary) -> bool:
	var uncovered: PackedStringArray = PackedStringArray()
	var seen: int = 0
	for path: String in _scripts_under(SCRIPT_ROOT):
		for key: String in translated_keys(FileAccess.get_file_as_string(path)):
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


## The keys one script asks to translate: the literal argument of every translate() call, plus both
## halves of a `translate("A" if x else "B")`. Computed arguments answer nothing, on purpose.
static func translated_keys(text: String) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	var at: int = text.find(CALL)
	while at >= 0:
		keys.append_array(_keys_in(_argument_region(text, at + CALL.length() - 1)))
		at = text.find(CALL, at + CALL.length())
	return keys


## The text between a call's parentheses, walked by bracket depth and skipping quoted text so a
## parenthesis inside a string cannot end the argument early.
static func _argument_region(text: String, open_at: int) -> String:
	var depth: int = 0
	var quote: String = ""
	var index: int = open_at
	while index < text.length():
		var glyph: String = text[index]
		if not quote.is_empty():
			if glyph == "\\":
				index += 1
			elif glyph == quote:
				quote = ""
		elif glyph == "\"" or glyph == "'":
			quote = glyph
		elif glyph == "(":
			depth += 1
		elif glyph == ")":
			depth -= 1
			if depth == 0:
				return text.substr(open_at + 1, index - open_at - 1)
		index += 1
	return ""


## The literals a translate() argument stands for, "" when the argument is computed rather than
## written out. A region that does not START with a quote is computed; so is one that joins or
## formats (`+` / `%`), because the key that reaches the catalog is then not in the file at all.
static func _keys_in(region: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var trimmed: String = region.strip_edges()
	if not trimmed.begins_with("\""):
		return found
	var index: int = 0
	var take: bool = true
	while index < trimmed.length():
		var glyph: String = trimmed[index]
		if glyph == "\"":
			index += 1
			var literal: String = ""
			while index < trimmed.length() and trimmed[index] != "\"":
				if trimmed[index] == "\\" and index + 1 < trimmed.length():
					literal += _unescaped(trimmed[index + 1])
					index += 2
					continue
				literal += trimmed[index]
				index += 1
			if take:
				found.append(literal)
				take = false
			index += 1
			continue
		if glyph == "+" or glyph == "%":
			return PackedStringArray()
		# The other arm of a ternary is a key of its own - both spellings reach the catalog.
		if trimmed.substr(index, 5) == "else ":
			take = true
			index += 5
			continue
		index += 1
	return found


static func _unescaped(marker: String) -> String:
	match marker:
		"n":
			return "\n"
		"t":
			return "\t"
		"\"":
			return "\""
		"\\":
			return "\\"
	return "\\" + marker


static func _scripts_under(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".gd"):
			found.append("%s/%s" % [dir_path, file_name])
	for sub_dir: String in DirAccess.get_directories_at(dir_path):
		found.append_array(_scripts_under("%s/%s" % [dir_path, sub_dir]))
	return found


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
	if actual == expected:
		print("[PASS] editor_l10n_coverage_test: %s" % label)
		return true
	print("[FAIL] editor_l10n_coverage_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
