# Godot EventSheets - the translator's handoff, as data.
#
# Everything the Translation Studio does that is NOT a widget: find every player-facing string the
# game emits, write them into one translator CSV, read a returned one back, say which languages are
# covered, and name the keys nobody says any more. Pure static functions over text and files, so the
# suite drives exactly what the window's buttons drive.
#
# THE CORPUS IS THE EMITTED CODE, NOT THE SHEETS. A sheet compiles to plain GDScript, and that is
# where `tr("Ready")` actually lives - so the sweep reads scripts (and the .tres data assets Godot's
# own POT generation structurally cannot see, because it only scans scripts). Listing sheets instead
# would find only the `.tres` ones while `.gd` is the default sheet format.
#
# WHAT COUNTS AS A KEY. `tr("x")`, `tr("x", "ctx")` and `tr_n("one", "many", n)` - each with the
# `atr` twins the editor uses. The params dialog's own unwrap rule deliberately refuses the
# context-carrying form (only the plain literal round-trips into its text field), so a scanner built
# on that rule alone would silently skip every context-carrying key; this one parses the call.
#
# THE CSV IS GODOT'S OWN. One row per key, one column per locale, first column "keys" - the shape
# Godot's importer turns into a .translation on drop, with no further ceremony. The codec is
# EventSheetGridCSV's, so the translator's file and the designer's grid file escape identically by
# construction and can never disagree about a comma inside a sentence.
#
# MERGING NEVER CLOBBERS. Re-extracting keeps every filled cell that is already there and only adds
# the keys that are new, because the file a translator sent back is the one thing this must never
# overwrite.
@tool
class_name EventSheetTranslationScan
extends RefCounted

## The first column of a Godot translation CSV. Its header is a label, not a locale.
const KEY_COLUMN := "keys"
## The source-language column. Seeded from the key itself (sentences ARE the keys here), so a
## translator always has a source sentence to work from.
const SOURCE_COLUMN := "en"
## Provenance for the translator: where the key is said, and the row note beside it.
const NOTES_COLUMN := "notes"
## Columns that are not languages - skipped by coverage, never treated as a locale.
const NON_LOCALE_COLUMNS: Array[String] = [KEY_COLUMN, NOTES_COLUMN]
## The translating calls the sweep recognises, longest first so `tr_n` is never read as `tr`.
const TRANSLATE_CALLS: Array[String] = ["tr_n", "atr_n", "tr", "atr"]

# ── Scanning source text ─────────────────────────────────────────────────────


## Every translatable key a GDScript source says, in the order it says them:
## [{"key", "context", "plural", "line"}]. A `#` comment is not code, so a commented-out row
## contributes nothing; a literal that is not a translating call's argument is not a key.
static func keys_in(source: String) -> Array:
	var found: Array = []
	var line_number: int = 1
	var index: int = 0
	var length: int = source.length()
	while index < length:
		var character: String = source[index]
		if character == "\n":
			line_number += 1
			index += 1
			continue
		if character == "#":
			# The rest of the line is a comment - the note harvester reads those, the key sweep does not.
			var newline: int = source.find("\n", index)
			index = length if newline == -1 else newline
			continue
		if character == "\"":
			# A literal that is NOT a call argument (a path, a node name, an unmarked string): step
			# over it whole, so a `tr(` spelled inside a string can never be mistaken for a call.
			var skipped: Dictionary = _literal_at(source, index)
			line_number += int(skipped.get("newlines", 0))
			index = int(skipped.get("end", index + 1))
			continue
		var call: Dictionary = _translate_call_at(source, index)
		if call.is_empty():
			index += 1
			continue
		var parsed: Dictionary = _parse_call_arguments(source, int(call.get("end", index)), str(call.get("name", "")))
		if not parsed.is_empty():
			parsed["line"] = line_number
			found.append(parsed)
			line_number += int(parsed.get("newlines", 0))
			parsed.erase("newlines")
			index = int(parsed.get("end", index + 1))
			parsed.erase("end")
			continue
		index = int(call.get("end", index + 1))
	return found


## A translating call starting exactly at `index`, or {}. The character before must not be part of
## an identifier, so `attr(` and `mutr(` are not calls - but `"text".tr(` is (a method call whose
## first argument is not a literal simply yields no key).
static func _translate_call_at(source: String, index: int) -> Dictionary:
	if index > 0:
		var previous: String = source[index - 1]
		if previous == "_" or previous.is_valid_identifier() or (previous >= "0" and previous <= "9"):
			return {}
	for name: String in TRANSLATE_CALLS:
		var end: int = index + name.length()
		if source.substr(index, name.length()) != name:
			continue
		# The next non-space character must open the argument list, or this is just an identifier.
		var cursor: int = end
		while cursor < source.length() and (source[cursor] == " " or source[cursor] == "\t"):
			cursor += 1
		if cursor < source.length() and source[cursor] == "(":
			return {"name": name, "end": cursor + 1}
	return {}


## The arguments of a translating call whose "(" has just been consumed: the key, plus the plural
## form for `tr_n` and the context for the two-argument `tr`. A first argument that is not a plain
## literal (a variable, a format expression) is undecidable and contributes nothing.
static func _parse_call_arguments(source: String, index: int, call_name: String) -> Dictionary:
	var cursor: int = _skip_spaces(source, index)
	var first: Dictionary = _literal_at(source, cursor)
	if not bool(first.get("ok", false)):
		return {}
	var newlines: int = int(first.get("newlines", 0))
	var entry: Dictionary = {"key": str(first.get("text", "")), "context": "", "plural": "",
		"end": int(first.get("end", cursor)), "newlines": newlines}
	cursor = _skip_spaces(source, int(first.get("end", cursor)))
	if cursor >= source.length() or source[cursor] != ",":
		return entry
	cursor = _skip_spaces(source, cursor + 1)
	var second: Dictionary = _literal_at(source, cursor)
	if not bool(second.get("ok", false)):
		return entry
	entry["end"] = int(second.get("end", cursor))
	entry["newlines"] = newlines + int(second.get("newlines", 0))
	# tr_n's second literal is the plural form (a key in its own right); tr's is a context, which
	# scopes the SAME key rather than adding another one.
	if call_name.ends_with("_n"):
		entry["plural"] = str(second.get("text", ""))
	else:
		entry["context"] = str(second.get("text", ""))
	return entry


static func _skip_spaces(source: String, index: int) -> int:
	var cursor: int = index
	while cursor < source.length() and (source[cursor] == " " or source[cursor] == "\t"):
		cursor += 1
	return cursor


## One double-quoted GDScript literal starting at `index`: {ok, text, end, newlines}. Escapes are
## resolved (\" \\ \n \t), so the key stored is the string the game really looks up.
static func _literal_at(source: String, index: int) -> Dictionary:
	if index >= source.length() or source[index] != "\"":
		return {"ok": false, "end": index, "newlines": 0}
	var text: String = ""
	var cursor: int = index + 1
	var newlines: int = 0
	while cursor < source.length():
		var character: String = source[cursor]
		if character == "\\" and cursor + 1 < source.length():
			var escaped: String = source[cursor + 1]
			match escaped:
				"n":
					text += "\n"
				"t":
					text += "\t"
				"\"":
					text += "\""
				"\\":
					text += "\\"
				_:
					text += escaped
			cursor += 2
			continue
		if character == "\"":
			return {"ok": true, "text": text, "end": cursor + 1, "newlines": newlines}
		if character == "\n":
			# An unterminated literal is a syntax error, not a key: stop at the line end rather than
			# swallowing the rest of the file.
			return {"ok": false, "end": cursor, "newlines": newlines}
		text += character
		cursor += 1
	return {"ok": false, "end": cursor, "newlines": newlines}


## The note a translator gets for free: the `#` comment line(s) immediately above the key's line.
## A sheet's row note compiles to exactly that comment, so the context travels without anyone
## writing it twice. Returns "" when the line above is code.
static func note_above(source: String, line_number: int) -> String:
	var lines: PackedStringArray = source.replace("\r\n", "\n").split("\n")
	var collected: PackedStringArray = PackedStringArray()
	var cursor: int = line_number - 2
	while cursor >= 0 and cursor < lines.size():
		var line: String = lines[cursor].strip_edges()
		if not line.begins_with("#"):
			break
		collected.insert(0, line.trim_prefix("#").trim_prefix("#").strip_edges())
		cursor -= 1
	return " ".join(collected)

# ── Scanning the project ─────────────────────────────────────────────────────


## Every key the scripts under `root` emit, with where each one is said:
## [{"key", "context", "plural", "path", "line", "note"}]. Duplicates are kept - the caller folds
## them, and the fold is what makes the note read "said in three places".
static func scan_scripts(root: String) -> Array:
	var discovered: Array = []
	for path: String in files_under(root, ["gd"]):
		var source: String = FileAccess.get_file_as_string(path)
		if source.is_empty():
			continue
		for entry: Variant in keys_in(source):
			var record: Dictionary = entry as Dictionary
			record["path"] = path
			record["note"] = note_above(source, int(record.get("line", 1)))
			discovered.append(record)
	return discovered


## The words Godot's POT generation cannot see: a data asset's own text. Two ways in, both
## decidable - a `tr("…")` written into a stored expression string, and the cells of any grid
## column the resource declares as a `key` column (the data-asset key convention). A project
## with neither simply contributes nothing.
static func scan_data_assets(root: String) -> Array:
	var discovered: Array = []
	for path: String in files_under(root, ["tres"]):
		var text: String = FileAccess.get_file_as_string(path)
		for entry: Variant in _keys_in_stored_strings(text):
			var record: Dictionary = entry as Dictionary
			record["path"] = path
			record["line"] = 0
			record["note"] = "in %s" % path.get_file()
			discovered.append(record)
		discovered.append_array(_key_column_cells(path))
	return discovered


## A `tr("…")` written into a STORED string. A .tres holds every value as a quoted literal with its
## own quotes escaped, so the plain source sweep steps over the whole thing and finds nothing - the
## call only becomes visible once the literal is unescaped, which is exactly what `_literal_at`
## already does. Verified against a real saved resource rather than assumed.
static func _keys_in_stored_strings(text: String) -> Array:
	var found: Array = []
	var index: int = 0
	while index < text.length():
		if text[index] != "\"":
			index += 1
			continue
		var literal: Dictionary = _literal_at(text, index)
		var next: int = maxi(int(literal.get("end", index)), index + 1)
		if bool(literal.get("ok", false)) and str(literal.get("text", "")).contains("tr("):
			found.append_array(keys_in(str(literal.get("text", ""))))
		index = next
	return found


## The cells of every `key`-typed grid column on a data asset - the item names, quest titles and
## storylet prose that live as rows rather than as code.
static func _key_column_cells(path: String) -> Array:
	var found: Array = []
	if not ResourceLoader.exists(path):
		return found
	var resource: Resource = load(path)
	if resource == null:
		return found
	for property: Dictionary in resource.get_property_list():
		var property_name: String = str(property.get("name", ""))
		if int(property.get("type", TYPE_NIL)) != TYPE_ARRAY:
			continue
		var columns: Array = EventSheetGridCSV.columns_from_resource(resource, property_name)
		if columns.is_empty():
			continue
		var rows: Variant = resource.get(property_name)
		if not (rows is Array):
			continue
		for column: Variant in columns:
			if str((column as Dictionary).get("type", "")) != "key":
				continue
			var column_name: String = str((column as Dictionary).get("name", ""))
			for row: Variant in (rows as Array):
				if not (row is Dictionary):
					continue
				var cell: String = EventSheetGridCSV.cell_text((row as Dictionary).get(column_name, ""))
				if cell.strip_edges().is_empty():
					continue
				found.append({"key": cell, "context": "", "plural": "", "line": 0, "path": path,
					"note": "%s column of %s" % [column_name, path.get_file()]})
	return found


## Every file under `root` with one of `extensions`, skipping the plugin's own code, the bundled
## behaviour packs and Godot's import cache: a plugin string is not the user's game, a shipped pack
## carries its own translations.csv beside it, and .godot holds copies of everything.
static func files_under(root: String, extensions: Array) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	# The trailing slash is trimmed so a path never doubles it - but "res://" trims to "res:", which
	# DirAccess cannot open, so the project root would silently scan to nothing. Put the slashes back
	# for exactly that case (any scheme root: "res://", "user://").
	var start: String = root.rstrip("/")
	if start.ends_with(":"):
		start = "%s//" % start
	var pending: Array[String] = [start]
	while not pending.is_empty():
		var directory_path: String = pending.pop_back()
		var directory: DirAccess = DirAccess.open(directory_path)
		if directory == null:
			continue
		for name: String in directory.get_directories():
			if name.begins_with(".") or name == "addons" or name == "eventsheet_addons":
				continue
			pending.append("%s/%s" % [directory_path, name])
		for name: String in directory.get_files():
			if extensions.has(name.get_extension().to_lower()):
				found.append("%s/%s" % [directory_path, name])
	found.sort()
	return found

# ── The catalog file ─────────────────────────────────────────────────────────


## A translator CSV read into {ok, message, locales, rows, by_key}. `rows` are the file's records in
## file order; `by_key` indexes them. Reading uses the grid codec, so a sentence with a comma in it
## survives the trip both ways.
static func read_catalog(csv_path: String, separator: String = ",") -> Dictionary:
	if not FileAccess.file_exists(csv_path):
		return {"ok": false, "message": "There is no catalog at %s yet." % csv_path,
			"locales": PackedStringArray(), "rows": [], "by_key": {}}
	var text: String = FileAccess.get_file_as_string(csv_path)
	if text.strip_edges().is_empty():
		return {"ok": false, "message": "%s is empty - a translation CSV needs a first line naming the columns." % csv_path,
			"locales": PackedStringArray(), "rows": [], "by_key": {}}
	var records: Array = EventSheetGridCSV.parse_records(text, separator)
	var header: PackedStringArray = EventSheetGridCSV.split_cells(
		text.replace("\r\n", "\n").replace("\r", "\n").split("\n", false)[0], separator)
	var columns: PackedStringArray = PackedStringArray()
	for cell: String in header:
		var name: String = cell.strip_edges()
		if not name.is_empty() and not columns.has(name):
			columns.append(name)
	var by_key: Dictionary = {}
	var rows: Array = []
	for record: Variant in records:
		var row: Dictionary = record as Dictionary
		var key: String = str(row.get(KEY_COLUMN, "")).strip_edges()
		if key.is_empty() or by_key.has(key):
			continue
		by_key[key] = row
		rows.append(row)
	return {"ok": true, "message": "Read %d key(s) from %s." % [rows.size(), csv_path],
		"locales": locales_of(columns), "columns": columns, "rows": rows, "by_key": by_key}


## The language columns of a header: everything that is not the key column or the notes column.
## "en" IS a language here (it holds the source sentence a translator works from).
static func locales_of(columns: PackedStringArray) -> PackedStringArray:
	var locales: PackedStringArray = PackedStringArray()
	for column: String in columns:
		if NON_LOCALE_COLUMNS.has(column) or column.strip_edges().is_empty():
			continue
		locales.append(column)
	return locales


## The whole extraction: sweep `root`, fold the keys, merge with the catalog already there, and
## write it back. Filled cells are kept exactly as they were - the returned file is never clobbered,
## which is the only reason this is safe to run on a schedule.
static func extract(root: String, csv_path: String, include_notes: bool = true, separator: String = ",") -> Dictionary:
	var discovered: Array = scan_scripts(root)
	discovered.append_array(scan_data_assets(root))
	var folded: Dictionary = fold(discovered)
	var keys: PackedStringArray = PackedStringArray()
	var notes: Dictionary = {}
	for key: Variant in folded.keys():
		keys.append(str(key))
		notes[str(key)] = str((folded[key] as Dictionary).get("note", ""))
	return merge_keys(csv_path, keys, notes, include_notes, separator)


## Merging a set of keys INTO the catalog already at `csv_path`, which is the only write shape this
## file has: every filled cell stays exactly as it was, every language column the file already
## carries is carried on, and a key the caller no longer names keeps its row rather than being
## deleted (the orphan report names those instead - throwing away a paid translation on a guess is
## unforgivable). Shared by the whole-project sweep and by the grid's "Export Text for Translation",
## because a plain write would silently delete a translator's finished columns the second time it
## ran. `notes` is key -> provenance line, written only when `include_notes` is on.
static func merge_keys(csv_path: String, keys: PackedStringArray, notes: Dictionary = {}, include_notes: bool = true, separator: String = ",") -> Dictionary:
	var wanted: Dictionary = {}
	for key: String in keys:
		wanted[key] = true
	var existing: Dictionary = read_catalog(csv_path, separator)
	var existing_rows: Array = existing.get("rows", [])
	var by_key: Dictionary = existing.get("by_key", {})
	var columns: PackedStringArray = existing.get("columns", PackedStringArray([KEY_COLUMN, SOURCE_COLUMN]))
	if columns.is_empty():
		columns = PackedStringArray([KEY_COLUMN, SOURCE_COLUMN])
	if not columns.has(KEY_COLUMN):
		columns.insert(0, KEY_COLUMN)
	if not columns.has(SOURCE_COLUMN):
		columns.insert(1, SOURCE_COLUMN)
	if include_notes and not columns.has(NOTES_COLUMN):
		columns.append(NOTES_COLUMN)
	var rows: Array = []
	var added: int = 0
	var written: Dictionary = {}
	for key_text: String in keys:
		if key_text.is_empty() or written.has(key_text):
			continue
		written[key_text] = true
		var row: Dictionary = {}
		if by_key.has(key_text) and by_key[key_text] is Dictionary:
			row = by_key[key_text]
		else:
			added += 1
		var merged: Dictionary = {}
		for column: String in columns:
			merged[column] = str(row.get(column, ""))
		merged[KEY_COLUMN] = key_text
		if str(merged.get(SOURCE_COLUMN, "")).is_empty():
			merged[SOURCE_COLUMN] = key_text
		if include_notes:
			merged[NOTES_COLUMN] = str(notes.get(key_text, ""))
		rows.append(merged)
	# A key the sweep no longer finds keeps its row rather than being deleted: a string built at
	# runtime is undecidable, and throwing away a paid translation on a guess is unforgivable.
	# The orphan report names them instead.
	var kept_missing: int = 0
	for row: Variant in existing_rows:
		var stale_key: String = str((row as Dictionary).get(KEY_COLUMN, "")).strip_edges()
		if stale_key.is_empty() or wanted.has(stale_key):
			continue
		var carried: Dictionary = {}
		for column: String in columns:
			carried[column] = str((row as Dictionary).get(column, ""))
		rows.append(carried)
		kept_missing += 1
	var column_specs: Array = []
	for column: String in columns:
		column_specs.append({"name": column, "type": "String"})
	var outcome: Dictionary = EventSheetGridCSV.write_csv(csv_path, rows, column_specs, separator)
	if not bool(outcome.get("ok", false)):
		return outcome
	return {"ok": true, "keys": rows.size(), "added": added, "kept": kept_missing,
		"message": "%d key(s) in %s - %d new, %d already translated and kept%s." % [rows.size(), csv_path,
			added, rows.size() - added, ", %d no script says any more" % kept_missing if kept_missing > 0 else ""]}


## Folds repeated sightings of one key into a single entry, whose note names every place it is said
## (up to three, then a count) - which is the context a translator is actually missing.
static func fold(discovered: Array) -> Dictionary:
	var folded: Dictionary = {}
	for entry: Variant in discovered:
		var record: Dictionary = entry as Dictionary
		var key: String = str(record.get("key", ""))
		if key.is_empty():
			continue
		if not folded.has(key):
			folded[key] = {"key": key, "sites": [], "note": ""}
		(folded[key].get("sites") as Array).append(record)
		var plural: String = str(record.get("plural", ""))
		if not plural.is_empty():
			folded[key]["plural"] = plural
			if not folded.has(plural):
				folded[plural] = {"key": plural, "sites": [record], "note": ""}
	for key: Variant in folded.keys():
		folded[key]["note"] = _note_for_sites((folded[key].get("sites", []) as Array))
	return folded


static func _note_for_sites(sites: Array) -> String:
	var places: PackedStringArray = PackedStringArray()
	var written: PackedStringArray = PackedStringArray()
	for entry: Variant in sites:
		var record: Dictionary = entry as Dictionary
		var line: int = int(record.get("line", 0))
		var place: String = "%s:%d" % [str(record.get("path", "")).get_file(), line] if line > 0 \
			else str(record.get("note", str(record.get("path", "")).get_file()))
		if not places.has(place):
			places.append(place)
		var note: String = str(record.get("note", ""))
		if not note.is_empty() and not written.has(note) and line > 0:
			written.append(note)
		var context: String = str(record.get("context", ""))
		if not context.is_empty() and not written.has("context: %s" % context):
			written.append("context: %s" % context)
	var where: String = ", ".join(places) if places.size() <= 3 \
		else "%s and %d more" % [", ".join(PackedStringArray(Array(places).slice(0, 3))), places.size() - 3]
	if written.is_empty():
		return where
	return "%s - %s" % [where, " ".join(written)]

# ── Coverage, import, orphans ────────────────────────────────────────────────


## Per-language coverage: [{locale, total, covered, missing, missing_keys}]. The sentence the
## dialog shows ("142 keys, 138 covered, 4 missing in ja") is built from this, never from a guess.
static func coverage(csv_path: String, separator: String = ",") -> Array:
	var catalog: Dictionary = read_catalog(csv_path, separator)
	var report: Array = []
	var rows: Array = catalog.get("rows", [])
	for locale: String in (catalog.get("locales", PackedStringArray()) as PackedStringArray):
		var covered: int = 0
		var missing_keys: PackedStringArray = PackedStringArray()
		for row: Variant in rows:
			if str((row as Dictionary).get(locale, "")).strip_edges().is_empty():
				missing_keys.append(str((row as Dictionary).get(KEY_COLUMN, "")))
			else:
				covered += 1
		report.append({"locale": locale, "total": rows.size(), "covered": covered,
			"missing": missing_keys.size(), "missing_keys": missing_keys})
	return report


## One coverage line in words, the way every other outcome in these dialogs reads.
static func coverage_sentence(entry: Dictionary) -> String:
	var missing: int = int(entry.get("missing", 0))
	if missing == 0:
		return "%s: %d key(s), all covered." % [str(entry.get("locale", "")), int(entry.get("total", 0))]
	return "%s: %d key(s), %d covered, %d missing." % [str(entry.get("locale", "")),
		int(entry.get("total", 0)), int(entry.get("covered", 0)), missing]


## Reads a returned CSV back into the master catalog: every cell the translator filled lands, every
## cell they left blank leaves what was already there alone, and a language the master never had
## becomes a new column. Keys the master does not know are reported, not invented.
static func import_catalog(returned_csv: String, target_csv: String, separator: String = ",") -> Dictionary:
	var returned: Dictionary = read_catalog(returned_csv, separator)
	if not bool(returned.get("ok", false)):
		return returned
	var target: Dictionary = read_catalog(target_csv, separator)
	if not bool(target.get("ok", false)):
		return target
	var columns: PackedStringArray = target.get("columns", PackedStringArray())
	for locale: String in (returned.get("locales", PackedStringArray()) as PackedStringArray):
		if not columns.has(locale):
			columns.append(locale)
	var by_key: Dictionary = target.get("by_key", {})
	var filled: int = 0
	var unknown: PackedStringArray = PackedStringArray()
	for row: Variant in (returned.get("rows", []) as Array):
		var record: Dictionary = row as Dictionary
		var key: String = str(record.get(KEY_COLUMN, "")).strip_edges()
		if not by_key.has(key):
			unknown.append(key)
			continue
		var master: Dictionary = by_key[key]
		for locale: String in (returned.get("locales", PackedStringArray()) as PackedStringArray):
			var value: String = str(record.get(locale, ""))
			if value.strip_edges().is_empty() or str(master.get(locale, "")) == value:
				continue
			master[locale] = value
			filled += 1
		by_key[key] = master
	var rows: Array = []
	for row: Variant in (target.get("rows", []) as Array):
		var record: Dictionary = row as Dictionary
		var merged: Dictionary = by_key.get(str(record.get(KEY_COLUMN, "")), record)
		var out: Dictionary = {}
		for column: String in columns:
			out[column] = str(merged.get(column, ""))
		rows.append(out)
	var column_specs: Array = []
	for column: String in columns:
		column_specs.append({"name": column, "type": "String"})
	var written: Dictionary = EventSheetGridCSV.write_csv(target_csv, rows, column_specs, separator)
	if not bool(written.get("ok", false)):
		return written
	var unknown_note: String = "" if unknown.is_empty() \
		else " %d key(s) in that file are in no script - %s." % [unknown.size(), ", ".join(unknown)]
	return {"ok": true, "filled": filled, "unknown": unknown,
		"message": "Merged %s into %s - %d cell(s) filled.%s" % [returned_csv.get_file(), target_csv, filled, unknown_note]}


## Keys the catalog holds that NO script emits any more - a renamed string, or a deleted feature.
## The honest limitation lives in the message the caller writes: a key built at runtime is
## undecidable, so this is a report to read, never a delete to run.
static func orphans(csv_path: String, root: String, separator: String = ",") -> PackedStringArray:
	var catalog: Dictionary = read_catalog(csv_path, separator)
	var live: Dictionary = {}
	for entry: Variant in scan_scripts(root):
		live[str((entry as Dictionary).get("key", ""))] = true
		var plural: String = str((entry as Dictionary).get("plural", ""))
		if not plural.is_empty():
			live[plural] = true
	for entry: Variant in scan_data_assets(root):
		live[str((entry as Dictionary).get("key", ""))] = true
	var found: PackedStringArray = PackedStringArray()
	for row: Variant in (catalog.get("rows", []) as Array):
		var key: String = str((row as Dictionary).get(KEY_COLUMN, "")).strip_edges()
		if not key.is_empty() and not live.has(key):
			found.append(key)
	return found

# ── The source string IS the key: renaming it ────────────────────────────────


## What renaming a key would touch, before anything is touched: {"files": [{path, locales}],
## "blocked": String}. A rename onto a key the catalog ALREADY holds is refused rather than merged -
## two sentences would silently become one, and one translator's work would vanish.
static func rename_plan(old_key: String, new_key: String, csv_paths: PackedStringArray, separator: String = ",") -> Dictionary:
	if old_key.is_empty() or new_key.is_empty():
		return {"files": [], "blocked": "A key needs text on both sides of the rename."}
	if old_key == new_key:
		return {"files": [], "blocked": "That is the same key."}
	var files: Array = []
	for path: String in csv_paths:
		var catalog: Dictionary = read_catalog(path, separator)
		if not bool(catalog.get("ok", false)):
			continue
		var by_key: Dictionary = catalog.get("by_key", {})
		if not by_key.has(old_key):
			continue
		if by_key.has(new_key):
			return {"files": [], "blocked": "%s already holds \"%s\" - renaming onto it would merge two sentences into one." % [path, new_key]}
		var translated: PackedStringArray = PackedStringArray()
		for locale: String in (catalog.get("locales", PackedStringArray()) as PackedStringArray):
			if not str((by_key[old_key] as Dictionary).get(locale, "")).strip_edges().is_empty():
				translated.append(locale)
		files.append({"path": path, "locales": translated})
	return {"files": files, "blocked": ""}


## The sentence the offer shows: how many catalogs hold this key and in which languages.
static func rename_sentence(plan: Dictionary, old_key: String) -> String:
	var blocked: String = str(plan.get("blocked", ""))
	if not blocked.is_empty():
		return blocked
	var files: Array = plan.get("files", [])
	if files.is_empty():
		return "No catalog holds \"%s\" - nothing to update." % old_key
	var locales: PackedStringArray = PackedStringArray()
	for entry: Variant in files:
		for locale: String in ((entry as Dictionary).get("locales", PackedStringArray()) as PackedStringArray):
			if locale != SOURCE_COLUMN and not locales.has(locale):
				locales.append(locale)
	if locales.is_empty():
		return "%d catalog(s) hold \"%s\", untranslated so far. Update the key in all of them?" % [files.size(), old_key]
	return "%d catalog(s) hold \"%s\" (%s). Update the key in all of them?" % [files.size(), old_key, ", ".join(locales)]


## Performs the rename the plan describes: the key cell, and the source column when it still holds
## the old sentence (sentences ARE the keys, so the source text moves with the key). Returns the
## paths really rewritten.
static func apply_rename(old_key: String, new_key: String, plan: Dictionary, separator: String = ",") -> Dictionary:
	if not str(plan.get("blocked", "")).is_empty():
		return {"ok": false, "message": str(plan.get("blocked", "")), "paths": PackedStringArray()}
	var rewritten: PackedStringArray = PackedStringArray()
	for entry: Variant in (plan.get("files", []) as Array):
		var path: String = str((entry as Dictionary).get("path", ""))
		var catalog: Dictionary = read_catalog(path, separator)
		if not bool(catalog.get("ok", false)):
			continue
		var columns: PackedStringArray = catalog.get("columns", PackedStringArray())
		var rows: Array = []
		var changed: bool = false
		for row: Variant in (catalog.get("rows", []) as Array):
			var record: Dictionary = (row as Dictionary).duplicate()
			if str(record.get(KEY_COLUMN, "")).strip_edges() == old_key:
				record[KEY_COLUMN] = new_key
				if str(record.get(SOURCE_COLUMN, "")) == old_key:
					record[SOURCE_COLUMN] = new_key
				changed = true
			var out: Dictionary = {}
			for column: String in columns:
				out[column] = str(record.get(column, ""))
			rows.append(out)
		if not changed:
			continue
		var column_specs: Array = []
		for column: String in columns:
			column_specs.append({"name": column, "type": "String"})
		if bool(EventSheetGridCSV.write_csv(path, rows, column_specs, separator).get("ok", false)):
			rewritten.append(path)
	if rewritten.is_empty():
		return {"ok": false, "message": "No catalog was rewritten - is \"%s\" still in one?" % old_key, "paths": rewritten}
	return {"ok": true, "paths": rewritten,
		"message": "Renamed \"%s\" to \"%s\" in %s - every translation of it followed." % [old_key, new_key, ", ".join(rewritten)]}
