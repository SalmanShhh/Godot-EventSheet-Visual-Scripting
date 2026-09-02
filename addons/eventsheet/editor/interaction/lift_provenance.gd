# Godot EventSheets - WHAT CLAIMS THIS LINE, asked of every reading layer at once.
#
# A hand-written line becomes a row through one of several vocabularies, and until now the only way
# to find out WHICH was to read the importer. The per-line reading beside this file
# (EventSheetLiftReading) answers the question the canvas asks - did anything name this line, and how
# plainly - which is the right answer for a panel and the wrong one for somebody about to change a
# table: it says "entry" where the interesting answer is "the lighting family's torch_brightness
# entry, and by the way the derived call layer would have said Light2D.set_energy".
#
# So this asks every layer, in the order the importer asks them, and reports every one that answers:
#
#   1. TABLE    a lift-table entry whose pattern somebody wrote (EventForgeLiftTable).
#   2. EXAMPLE  a lift-table entry DERIVED from a marked example (EventForgeLiftExample) - a built-in
#               family written that way, or a pack's own @ace_lift_example spelling. The same engine,
#               a different authoring route, and the entry itself says which one it came down
#               (EventForgeLiftTable.origin_of).
#   3. MATCHER  a hand-written matcher family - the spellings that are several statements, or that
#               have to read the scene to be sure (EventSheetACELifter.SPELLING_FAMILIES and
#               RUN_FAMILIES). Reported only where the answer is NOT one of that family's own table
#               entries, because most families answer match_line by asking their table, and saying so
#               twice would make one claim look like two.
#   4. INDEX    the general reverse index over the descriptor templates.
#   5. CALL     the derived call reading - the receiver's class resolved and the method found on it
#               (EventSheetDerivedCalls), with the resolution named: self, node, declared, autoload
#               or class.
#   6. PROPERTY the derived property reading beside it (EventSheetDerivedProperties).
#   7. VERBATIM nothing claimed it, and it stays honest GDScript.
#
# THE FIRST ANSWER IS THE CLAIM. The layers below it are what the line WOULD have read as, which is
# the question somebody retiring a table entry actually has. Curated outranks derived, always: where
# a table claims a line the derived layers never run in the editor at all, and their line here is a
# preview of the fallback rather than a competing claim.
#
# THE ONE LAYER WITH NO ISOLATED SEAM is the reverse index. The lifter asks the matcher families
# before it and there is no way in today to ask the index alone, so it is asked as the whole lifter
# (EventSheetACELifter.lift_one_line) and reported only where no earlier layer answered - which is
# exactly the case where the lifter's answer IS the index's. Nothing is guessed and nothing is
# reimplemented: every answer here comes from the reader that actually produces it when a file opens.
#
# Everything is static and pure over the passed source, so the command line over it
# (tools/explain.gd) runs headless and a test can pin its sentences without a viewport.
@tool
class_name EventSheetLiftProvenance
extends RefCounted

## The layers, in the order the importer asks them. The values are stable: the command line prints
## them and a test pins them.
const LAYER_TABLE: String = "table"
const LAYER_EXAMPLE: String = "example"
const LAYER_MATCHER: String = "matcher"
const LAYER_INDEX: String = "index"
const LAYER_CALL: String = "call"
const LAYER_PROPERTY: String = "property"
const LAYER_VERBATIM: String = "verbatim"

## The provenance order itself, as one list, so the printed numbering and this file's walk cannot
## disagree about what comes before what.
const LAYER_ORDER: Array[String] = [LAYER_TABLE, LAYER_EXAMPLE, LAYER_MATCHER, LAYER_INDEX,
	LAYER_CALL, LAYER_PROPERTY, LAYER_VERBATIM]

## What a line nothing claims is told. The plainest sentence in the file, deliberately: general
## purpose includes the right to just be code.
const UNCLAIMED: String = "no layer claims this line - it stays verbatim"

## What a blank line is told. Counted by nobody and asked of nothing, said out loud so a mistyped
## line number reads as a mistyped line number rather than as a line no vocabulary wanted.
const BLANK: String = "a blank line - no layer is asked about one"

## What a line outside the file is told.
const OUT_OF_RANGE: String = "there is no such line in this file"


## Every layer that answers for one line of one buffer, in provenance order:
##   [{"order", "layer", "where", "detail"}]
## `order` is the layer's index in LAYER_ORDER, `where` the file or family a developer can go and
## open (empty where there is none), and `detail` the answer in words. The list is never empty: a
## line nothing claims comes back as the one VERBATIM entry.
##
## `script_path` is the path the source came from, for the readings that resolve a receiver against
## the project (an Autoload, a class name, the host class of `self`).
static func claims(source: String, number: int, script_path: String = "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var lines: PackedStringArray = source.split("\n")
	if number < 1 or number > lines.size():
		found.append(_answer(LAYER_VERBATIM, "", OUT_OF_RANGE))
		return found
	var statement: String = lines[number - 1].strip_edges()
	if statement.is_empty():
		found.append(_answer(LAYER_VERBATIM, "", BLANK))
		return found
	var term: String = EventSheetLiftReading.asked_term(statement)
	var table: Dictionary = _table_answer(statement)
	if not table.is_empty():
		found.append(table)
	found.append_array(_matcher_answers(lines, number, statement, term, table))
	if found.is_empty():
		var index: Dictionary = _index_answer(statement, term)
		if not index.is_empty():
			found.append(index)
	found.append_array(_derived_answers(source, statement, script_path))
	if found.is_empty():
		found.append(_answer(LAYER_VERBATIM, "", UNCLAIMED))
	return found


## The whole answer as the text the command line prints and a test pins - the line itself, then one
## line per layer that answers, numbered by its place in the provenance order. Deterministic over the
## same tree: every walk under it is sorted or comes from a fixed list, and nothing here reads a
## clock, a machine path or a live count.
static func text(source: String, number: int, script_path: String = "") -> String:
	var lines: PackedStringArray = source.split("\n")
	var shown: String = ""
	if number >= 1 and number <= lines.size():
		shown = lines[number - 1].strip_edges()
	var out: PackedStringArray = PackedStringArray()
	out.append("%s:%d  %s" % [script_path if not script_path.is_empty() else "(buffer)", number, shown])
	for answer: Dictionary in claims(source, number, script_path):
		out.append(line_of(answer))
	return "\n".join(out)


## One answer as its printed line: the layer's place in the order, its name, the file a developer can
## open, and the answer. A layer with no file to open leaves that column out rather than printing a
## gap where a path would be.
static func line_of(answer: Dictionary) -> String:
	var where: String = str(answer.get("where", ""))
	var head: String = "  %d. %-8s" % [int(answer.get("order", 0)) + 1, str(answer.get("layer", ""))]
	if where.is_empty():
		return "%s %s" % [head, str(answer.get("detail", ""))]
	return "%s %s  %s" % [head, where, str(answer.get("detail", ""))]


# ── the layers ──────────────────────────────────────────────────────────────────


## Layers 1 and 2, which are one lookup: the table engine claims the line through the reading beside
## this file (so a branch is asked as its term and the packs are asked in their own order), and the
## entry that claimed it says which authoring route it came down.
static func _table_answer(statement: String) -> Dictionary:
	var claimed: Dictionary = EventSheetLiftReading.table_claim(statement)
	if claimed.is_empty():
		return {}
	var family: String = str(claimed.get("family", ""))
	var entry_id: String = str(claimed.get("entry_id", ""))
	var by_example: bool = _origin_of(family, entry_id) == EventForgeLiftTable.ORIGIN_EXAMPLE
	return _answer(LAYER_EXAMPLE if by_example else LAYER_TABLE, "%s.gd" % family,
		"%s -> %s" % [entry_id, str(claimed.get("ace_id", ""))])


## How the entry that claimed a line was authored. Looked up by family file name and entry id across
## the built-in tables and the installed packs' - both walked sorted, so the answer is the same on
## every machine. ORIGIN_HAND when the entry cannot be found, which is the honest default: an entry
## nothing stamped is one somebody wrote.
static func _origin_of(family: String, entry_id: String) -> String:
	var tables: Dictionary = EventForgeLiftTable.families()
	tables.merge(EventForgePackSpellings.tables(), true)
	var paths: PackedStringArray = PackedStringArray()
	for path: Variant in tables.keys():
		paths.append(str(path))
	paths.sort()
	for path: String in paths:
		if path.get_file().trim_suffix(".gd") != family:
			continue
		for entry: Variant in tables[path] as Array:
			if str((entry as Dictionary).get("id", "")) == entry_id:
				return EventForgeLiftTable.origin_of(entry as Dictionary)
	return EventForgeLiftTable.ORIGIN_HAND


## Layer 3: the hand-written matcher families, asked in the lifter's own order through the lifter's
## own constants, so a family added there is asked here on the strength of existing.
##
## A family whose answer is one of its OWN table entries is not reported: that claim is layer 1 or 2,
## already said, and most families answer their single-line question by handing it to their table.
static func _matcher_answers(lines: PackedStringArray, number: int, statement: String, term: String,
		table: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var claimed_family: String = str(table.get("where", ""))
	for family: GDScript in EventSheetACELifter.SPELLING_FAMILIES:
		var name: String = family.resource_path.get_file()
		if name == claimed_family:
			continue
		for method: String in [EventSheetACELifter.ACTION_SPELLING_METHOD,
				EventSheetACELifter.CONDITION_SPELLING_METHOD,
				EventSheetACELifter.WHOLE_CONDITION_SPELLING_METHOD]:
			if not family.has_method(method):
				continue
			var asked: String = statement
			if method != EventSheetACELifter.ACTION_SPELLING_METHOD:
				asked = term
			var hit: Dictionary = family.call(method, asked)
			if hit.is_empty():
				continue
			found.append(_answer(LAYER_MATCHER, name, "%s -> %s" % [method,
				str(hit.get("ace_id", ""))]))
			break
	for family: GDScript in EventSheetACELifter.RUN_FAMILIES:
		if not family.has_method(EventSheetACELifter.RUN_SPELLING_METHOD):
			continue
		var run: Dictionary = family.call(EventSheetACELifter.RUN_SPELLING_METHOD, lines,
			number - 1, _indent_of(lines[number - 1]))
		if run.is_empty():
			continue
		found.append(_answer(LAYER_MATCHER, family.resource_path.get_file(),
			"%s -> %s over %d lines" % [EventSheetACELifter.RUN_SPELLING_METHOD,
				str(run.get("ace_id", "")), int(run.get("consumed", 1))]))
	return found


## Layer 4: the general reverse index, asked as the whole lifter and only where nothing above
## answered - see the header. A statement is asked as an action and a branch as a condition, which is
## how the lifter itself asks them.
static func _index_answer(statement: String, term: String) -> Dictionary:
	var as_condition: bool = term != statement
	var asked: String = term if as_condition else statement
	var row: Resource = EventSheetACELifter.lift_one_line(asked, as_condition)
	if row is ACEAction:
		return _answer(LAYER_INDEX, "", "%s::%s" % [(row as ACEAction).provider_id,
			(row as ACEAction).ace_id])
	if row is ACECondition:
		return _answer(LAYER_INDEX, "", "%s::%s" % [(row as ACECondition).provider_id,
			(row as ACECondition).ace_id])
	return {}


## Layers 5 and 6: the derived readings, asked with the same three maps the row builder hoists for
## them - built here off the file's own sheet, through the readers that build them for the canvas, so
## a receiver resolves exactly as it would with the file open.
static func _derived_answers(source: String, statement: String,
		script_path: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source, true,
		script_path)
	if sheet == null:
		return found
	var context: Dictionary = EventSheetViewportReadingRows.sentence_context_extras(sheet)
	var class_map: Dictionary = EventSheetViewportReadingRows.object_class_map(sheet)
	var autoloads: Dictionary = EventSheetViewportReadingRows.autoload_singletons()
	var call: Dictionary = EventSheetDerivedCalls.derived_pieces(statement, context, class_map,
		autoloads)
	if not call.is_empty():
		found.append(_answer(LAYER_CALL, str(call.get("script_path", "")), "%s.%s (receiver: %s)"
			% [str(call.get("class", "")), str(call.get("method", "")), str(call.get("source", ""))]))
	var written: Dictionary = EventSheetDerivedProperties.derived_reading(
		EventSheetSentence.statement(statement, context), context, class_map, autoloads)
	if not written.is_empty():
		found.append(_answer(LAYER_PROPERTY, str(written.get("script_path", "")),
			"%s.%s (receiver: %s)" % [str(written.get("class", "")),
				str(written.get("property", "")), str(written.get("source", ""))]))
	return found


# ── the pieces ──────────────────────────────────────────────────────────────────


## One answer, with its place in the provenance order filled in from LAYER_ORDER rather than written
## down beside each layer, so the numbering cannot drift from the walk.
static func _answer(layer: String, where: String, detail: String) -> Dictionary:
	return {"order": LAYER_ORDER.find(layer), "layer": layer, "where": where, "detail": detail}


## How deep a line is indented, in tabs - what a run family means by depth, read off the line itself
## so a run is asked at the indentation it was written at.
static func _indent_of(line: String) -> int:
	var depth: int = 0
	while depth < line.length() and line[depth] == "\t":
		depth += 1
	return depth
