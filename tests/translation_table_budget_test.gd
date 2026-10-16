# Godot EventSheets - what the translation table may cost on a catalog the size of a finished game.
#
# A generated 200,000-line catalog (a key, the English line, French and Japanese with gaps, and the
# note saying where it is said - about the size of four chapters of a long narrative game in one
# file) is opened, searched, filtered to Missing only, paged and edited, each against a budget. The
# values are pinned too, so a fast answer that is wrong still fails.
#
# EVERY BUDGET WAS MEASURED, three runs on a quiet machine, and is about three times the slowest of
# them: what this exists to catch is a change that makes the table ALGORITHMICALLY slower - parsing
# every row on open, splitting rows nobody looked at, scanning row by row to search - and that lands
# far outside the band rather than just inside it.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "translation_table_budget_test"
const TABLE_PATH := "res://addons/eventsheet/editor/translation_table.gd"
const CATALOG := "user://eventforge_table_budget.csv"
const LINES := 200000

## Reading the file and indexing where every row starts and ends - and nothing else. Measured 194,
## 213 and 218 ms.
const OPEN_BUDGET_MS: int = 700
## The first search, which lowers the text once for every later one. Measured 550, 559 and 566 ms.
const FIRST_SEARCH_BUDGET_MS: int = 1700
## A later search: hit to hit over the lowered text. Measured 85, 89 and 96 ms.
const SEARCH_BUDGET_MS: int = 300
## Missing only, the one question that reads every row, once per file. Every line here quotes its
## English (it holds a comma) and almost half have a gap, so about 85,000 of them take the
## quote-aware split - the worst case rather than the usual one. Measured 810, 943 and 1,051 ms.
const MISSING_BUDGET_MS: int = 3200
## A screen of forty rows split into cells, deep in the file. Measured 0, 1 and 1 ms; the budget is
## a floor a timer can resolve rather than three times nothing.
const PAGE_BUDGET_MS: int = 50
## One cell written and the 22 MB file saved, every other byte as it was. Measured 177, 189 and
## 222 ms, most of it the write.
const EDIT_BUDGET_MS: int = 700


static func run() -> bool:
	_write_catalog()
	var table: RefCounted = load(TABLE_PATH).new()
	# Warm the scripts the model reads through (the scanner and the codec), so the clock measures the
	# table and not the first compile of the files behind it.
	table.open("user://eventforge_table_budget_missing.csv")
	var started: int = Time.get_ticks_msec()
	var opened: Dictionary = table.open(CATALOG)
	var open_ms: int = Time.get_ticks_msec() - started
	started = Time.get_ticks_msec()
	var first_found: PackedInt32Array = table.rows_containing("INN_123456")
	var first_search_ms: int = Time.get_ticks_msec() - started
	started = Time.get_ticks_msec()
	var found: PackedInt32Array = table.rows_containing("room for 1999")
	var search_ms: int = Time.get_ticks_msec() - started
	started = Time.get_ticks_msec()
	var missing: PackedInt32Array = table.missing_rows()
	var missing_ms: int = Time.get_ticks_msec() - started
	var gaps: Dictionary = table.missing_by_language().duplicate()
	started = Time.get_ticks_msec()
	var page: PackedStringArray = PackedStringArray()
	for row: int in range(150000, 150040):
		page.append(table.cells(row)[2])
	var page_ms: int = Time.get_ticks_msec() - started
	started = Time.get_ticks_msec()
	table.set_cell(100000, "fr", "Une chambre, s'il vous plaît.")
	var edit_ms: int = Time.get_ticks_msec() - started
	print("  %s: open %d ms, first search %d ms, search %d ms, missing %d ms, page %d ms, edit %d ms" % [NAME,
		open_ms, first_search_ms, search_ms, missing_ms, page_ms, edit_ms])
	var reopened: RefCounted = load(TABLE_PATH).new()
	reopened.open(CATALOG)
	var all_passed: bool = SUPPORT.pins(NAME, [
		["every line is a row", int(opened.get("rows", 0)), LINES],
		["search finds the one key", first_found, PackedInt32Array([123456])],
		["and every line that says the words", found.size(), 111],
		["missing only: every line with a French or Japanese gap", missing.size(), 85715],
		["and how many lines each language still lacks", gaps, {"fr": 28572, "ja": 66667}],
		["a page deep in the file reads its own lines", page[0], "Ligne 150000 de l'aubergiste."],
		["the edit is on disk, and the line after it is untouched", [reopened.cell(100000, "fr"), reopened.key(100001)],
			["Une chambre, s'il vous plaît.", "INN_100001"]],
		["opening stays inside its budget", open_ms <= OPEN_BUDGET_MS, true],
		["the first search stays inside its budget", first_search_ms <= FIRST_SEARCH_BUDGET_MS, true],
		["a later search stays inside its budget", search_ms <= SEARCH_BUDGET_MS, true],
		["missing only stays inside its budget", missing_ms <= MISSING_BUDGET_MS, true],
		["a page stays inside its budget", page_ms <= PAGE_BUDGET_MS, true],
		["an edit stays inside its budget", edit_ms <= EDIT_BUDGET_MS, true],
	])
	DirAccess.remove_absolute(CATALOG)
	return all_passed


## Lines that read like a game's: French missing on every seventh, Japanese on every third.
static func _write_catalog() -> void:
	var lines: PackedStringArray = PackedStringArray(["keys,en,fr,ja,notes"])
	lines.resize(LINES + 1)
	for index: int in LINES:
		var french: String = "" if index % 7 == 0 else "Ligne %d de l'aubergiste." % index
		var japanese: String = "" if index % 3 == 0 else "宿屋の台詞 %d。" % index
		lines[index + 1] = "INN_%06d,\"Is there a room for %d, innkeeper?\",%s,%s,dialogue/chapter_03/inn.gd:%d" % [
			index, index, french, japanese, index + 1]
	var file: FileAccess = FileAccess.open(CATALOG, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
