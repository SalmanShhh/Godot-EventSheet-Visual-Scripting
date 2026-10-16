# Godot EventSheets - one translator catalog as a table that reads in pages.
#
# A finished narrative game carries hundreds of thousands of lines, and the catalog has to scroll,
# search and filter as if it held forty. So nothing here parses the whole file:
#
#   - The file is read ONCE as text, and the only walk over all of it is the native line index (the
#     start of every row). Opening 200,000 rows costs that index and nothing else.
#   - A row is split into cells only when somebody asks for it - the rows on screen - and a few
#     screens of those are remembered, so scrolling back is free.
#   - Search never visits a row that does not match: the engine's own find jumps from one hit to the
#     next across the whole text, and the line index says which row each hit is in.
#   - Missing only is the one question that needs every row, so it is answered once per file and
#     kept until the file changes.
#
# The cells are split by EventSheetGridCSV's own rule (a quoted cell keeps its separator), so this
# reads exactly what Extract and Import write. A line with no quote in it takes the engine's plain
# split, which is the same answer for that line and far cheaper.
#
# DELIBERATELY NO `class_name`: the Translation Studio loads it by path on first use, so neither an
# editor start nor the first sheet open pays for it.
@tool
extends RefCounted

const ReadingDoors := preload("res://addons/eventsheet/editor/interaction/reading_doors.gd")

## The ways the table can be filtered, as the toolbar names them.
const FILTER_ALL := "all"
const FILTER_MISSING := "missing"
const FILTER_PSEUDO := "pseudo"
## Split rows remembered at once. A screen shows about forty; this keeps a dozen screens.
const ROW_CACHE_LIMIT := 512

## The catalog this table reads, and the separator its cells are split on.
var path: String = ""
var separator: String = ","
## The header, as written.
var columns: PackedStringArray = PackedStringArray()
## The language columns a player can be offered: every header column that is not the key, the
## notes or a pseudo (test-only) language. The source column comes first.
var languages: PackedStringArray = PackedStringArray()

var _text: String = ""
## The text lowered once, on the first search, so later searches are a plain find.
var _lower: String = ""
## True when the file was written with Windows line endings, so a save writes them back the same.
var _crlf: bool = false
## Where each row starts and ends in `_text`. Blank lines are not rows, exactly as the codec reads
## them.
var _starts: PackedInt32Array = PackedInt32Array()
var _ends: PackedInt32Array = PackedInt32Array()
## row -> its cells, for the rows somebody looked at lately.
var _split: Dictionary = {}
## The rows Missing only shows, worked out on first use. Empty and not ready until then.
var _missing: PackedInt32Array = PackedInt32Array()
var _missing_ready: bool = false
## language -> how many lines it still has no text for, worked out with `_missing`.
var _gaps: Dictionary = {}


## Reads `csv_path` and indexes its rows. {ok, message, rows}. A missing or empty file is an empty
## table that says why, never an error dialog.
func open(csv_path: String, csv_separator: String = ",") -> Dictionary:
	path = csv_path
	separator = csv_separator
	_split.clear()
	_missing = PackedInt32Array()
	_missing_ready = false
	_lower = ""
	columns = PackedStringArray()
	languages = PackedStringArray()
	_text = FileAccess.get_file_as_string(csv_path) if FileAccess.file_exists(csv_path) else ""
	_crlf = _text.contains("\r\n")
	if _text.contains("\r"):
		_text = _text.replace("\r\n", "\n").replace("\r", "\n")
	var header_end: int = _text.find("\n")
	if header_end == -1:
		header_end = _text.length()
	var scan: Script = ReadingDoors.translation_scan()
	for name: String in ReadingDoors.grid_csv().split_cells(_text.substr(0, header_end), separator):
		columns.append(name.strip_edges())
	for name: String in scan.locales_of(columns):
		if not EventSheetGameCatalog.is_pseudo_locale(name):
			languages.append(name)
	if languages.has(scan.SOURCE_COLUMN):
		languages.remove_at(languages.find(scan.SOURCE_COLUMN))
		languages.insert(0, scan.SOURCE_COLUMN)
	var starts: PackedInt32Array = PackedInt32Array()
	var ends: PackedInt32Array = PackedInt32Array()
	var cursor: int = header_end + 1
	var length: int = _text.length()
	while cursor < length:
		var line_end: int = _text.find("\n", cursor)
		if line_end == -1:
			line_end = length
		if line_end > cursor:
			starts.append(cursor)
			ends.append(line_end)
		cursor = line_end + 1
	_starts = starts
	_ends = ends
	if _text.is_empty():
		return {"ok": false, "rows": 0, "message": "There is no catalog at %s yet." % csv_path}
	return {"ok": true, "rows": _starts.size(), "message": "Read %d line(s) from %s." % [_starts.size(), csv_path]}


func row_count() -> int:
	return _starts.size()


## One row's cells, lined up with `columns` (a short row is padded with blanks, as the codec does).
func cells(row: int) -> PackedStringArray:
	if _split.has(row):
		return _split[row]
	var split: PackedStringArray = _split_line(_line(row))
	split.resize(columns.size())
	if _split.size() >= ROW_CACHE_LIMIT:
		_split.clear()
	_split[row] = split
	return split


## One cell by its column name, or "" when the catalog has no such column.
func cell(row: int, column: String) -> String:
	var at: int = columns.find(column)
	return cells(row)[at] if at >= 0 and row >= 0 and row < _starts.size() else ""


## The key of a row: the text the game looks up.
func key(row: int) -> String:
	return cell(row, ReadingDoors.translation_scan().KEY_COLUMN)


## The rows a toolbar choice shows: {"every": true} when that is simply every row (so a million
## rows never become a million-entry list), otherwise {"every": false, "rows": PackedInt32Array}.
func shown(search: String, filter: String) -> Dictionary:
	var wanted: String = search.strip_edges()
	if wanted.is_empty() and filter != FILTER_MISSING:
		return {"every": true, "rows": PackedInt32Array()}
	if wanted.is_empty():
		return {"every": false, "rows": missing_rows()}
	var found: PackedInt32Array = rows_containing(wanted)
	if filter != FILTER_MISSING:
		return {"every": false, "rows": found}
	var both: PackedInt32Array = PackedInt32Array()
	var missing: PackedInt32Array = missing_rows()
	for row: int in found:
		var at: int = missing.bsearch(row)
		if at < missing.size() and missing[at] == row:
			both.append(row)
	return {"every": false, "rows": both}


## Every row whose text holds `needle`, ignoring case, in file order. Jumps hit to hit, so the cost
## follows the matches rather than the size of the file. The engine's own case-blind find compares a
## character at a time and is several times slower than a plain find over a lowered copy, so the
## first search lowers the text once (the engine maps case one character to one, so every offset
## still points into the same row) and every later search reuses it.
func rows_containing(needle: String) -> PackedInt32Array:
	var found: PackedInt32Array = PackedInt32Array()
	if needle.is_empty() or _starts.is_empty():
		return found
	if _lower.is_empty():
		_lower = _text.to_lower()
	var wanted: String = needle.to_lower()
	var from: int = _starts[0]
	while true:
		var at: int = _lower.find(wanted, from)
		if at == -1:
			break
		var row: int = _starts.bsearch(at, false) - 1
		found.append(row)
		if row + 1 >= _starts.size():
			break
		from = _starts[row + 1]
	return found


## Every row with a language still empty (the source column is the sentence itself, so it never
## counts). Answered once per file.
##
## Most lines of a catalog in progress are whole, and a whole line is recognisable without splitting
## it: no two separators side by side, none at the end, and at least as many separators as the header
## has gaps. Only a line that fails that look is split - which is what keeps this from paying the
## quote-aware split for every line of dialogue with a comma in it. (A quoted separator can make a
## hand-typed SHORT row look long enough; such a row still reads "missing" in the table, it is just
## not gathered here. Every catalog this plugin writes has every column on every row.)
func missing_rows() -> PackedInt32Array:
	if _missing_ready:
		return _missing
	var watched: PackedInt32Array = PackedInt32Array()
	for language: String in languages:
		if language != ReadingDoors.translation_scan().SOURCE_COLUMN:
			watched.append(columns.find(language))
	var gaps: int = columns.size() - 1
	var doubled: String = separator + separator
	var missing: PackedInt32Array = PackedInt32Array()
	var lacking: PackedInt32Array = PackedInt32Array()
	lacking.resize(watched.size())
	for row: int in (_starts.size() if not watched.is_empty() else 0):
		var line: String = _line(row)
		if not line.contains(doubled) and not line.ends_with(separator) and line.count(separator) >= gaps:
			continue
		var split: PackedStringArray = _split_line(line)
		var gapped: bool = false
		for index: int in watched.size():
			if watched[index] >= split.size() or split[watched[index]].strip_edges().is_empty():
				lacking[index] += 1
				gapped = true
		if gapped:
			missing.append(row)
	_gaps.clear()
	for index: int in watched.size():
		_gaps[columns[watched[index]]] = lacking[index]
	_missing = missing
	_missing_ready = true
	return _missing


## language -> how many lines still have no text in it, for every language but the source. The
## status line of Missing only reads this ("180,120 French, 372,456 Japanese").
func missing_by_language() -> Dictionary:
	missing_rows()
	return _gaps


## Writes one cell and saves the file. Only that row's line is rewritten in place; every other byte
## of the catalog stays exactly as it was, so a translator's file never churns in version control.
## A column the catalog does not have yet is refused - adding a language is its own step.
func set_cell(row: int, column: String, value: String) -> Dictionary:
	var at: int = columns.find(column)
	if at < 0 or row < 0 or row >= _starts.size():
		return {"ok": false, "message": "%s has no %s column for that line." % [path.get_file(), column]}
	var split: PackedStringArray = cells(row).duplicate()
	split[at] = value
	var escaped: PackedStringArray = PackedStringArray()
	for text: String in split:
		escaped.append(ReadingDoors.grid_csv().escape_cell(text, separator))
	var new_line: String = separator.join(escaped)
	var start: int = _starts[row]
	var after: int = _ends[row]
	_text = _text.substr(0, start) + new_line + _text.substr(after)
	if not _lower.is_empty():
		_lower = _lower.substr(0, start) + new_line.to_lower() + _lower.substr(after)
	var shift: int = new_line.length() - (after - start)
	_ends[row] += shift
	if shift != 0:
		for later: int in range(row + 1, _starts.size()):
			_starts[later] += shift
			_ends[later] += shift
	_split.erase(row)
	_missing = PackedInt32Array()
	_missing_ready = false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Could not write %s - %s." % [path, error_string(FileAccess.get_open_error())]}
	file.store_string(_text.replace("\n", "\r\n") if _crlf else _text)
	file.close()
	return {"ok": true, "message": "Saved the %s line for \"%s\" in %s." % [column, key(row), path.get_file()]}


## A line's cells. A line with no quote in it cannot hold a quoted separator, so the engine's plain
## split gives the codec's answer for it at a fraction of the cost.
func _split_line(line: String) -> PackedStringArray:
	if not line.contains("\""):
		return line.split(separator)
	return ReadingDoors.grid_csv().split_cells(line, separator)


func _line(row: int) -> String:
	return _text.substr(_starts[row], _ends[row] - _starts[row])
