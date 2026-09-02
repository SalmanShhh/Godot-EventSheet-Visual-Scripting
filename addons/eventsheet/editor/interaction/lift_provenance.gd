# Godot EventSheets - WHAT ROW THIS LINE BECAME, and which reading layer would have claimed it.
#
# A hand-written line becomes a row through one of several vocabularies, and until now the only way
# to find out WHICH was to read the importer. The per-line reading beside this file
# (EventSheetLiftReading) answers the question the canvas asks - did anything name this line, and how
# plainly - which is the right answer for a panel and the wrong one for somebody about to change a
# table: it says "entry" where the interesting answer is "the lighting family's torch_brightness
# entry, and by the way the derived call layer would have said Light2D.set_energy".
#
# TWO QUESTIONS, ASKED SEPARATELY, BECAUSE THEY HAVE DIFFERENT ANSWERS.
#
# 1. THE CLAIM (row_claim). What row does the editor ACTUALLY turn this line into? That is not a
#    per-line question and cannot be answered by asking the line on its own: the importer reads a
#    file STRUCTURALLY. A class-level `var level_seconds: float = 0.0` is a variable row and never a
#    statement; a `connect` inside a bare `_ready` is a signal trigger and not a call; a line inside
#    a pack-emitted helper body is part of that helper. Asked as isolated statements those three
#    read as SetLocalVarTyped, CallMethod and AddVelocity - three confident wrong answers. So the
#    claim is asked of the row builder itself: reopen the file, re-emit it, and look the line up in
#    the source map the compiler hands back (EventSheetLineRowMapper). That answer is the editor's,
#    because it IS the editor's - the same import and the same emission a save performs.
#
#    It is gated on the round trip being LOSSLESS. Line N of the re-emission is line N of the file
#    only when the two are byte-identical, so a file that does not reproduce itself is told that
#    rather than answered by a line number that means something else.
#
#    THE GRAIN IS THE ROW THAT OWNS THE EMISSION, which for a line inside an event is the EVENT: the
#    source map is keyed per emitting resource, and an event emits the lines of every condition and
#    action under it. That is the same grain the editor works at - it is what clicking a generated
#    line selects - and the preview below says which verb of that event claimed the line.
#
# 2. THE PREVIEW (claims). Which reading layer would have claimed this line, asked layer by layer in
#    the order the importer asks them - which is the question somebody retiring a table entry
#    actually has, and stays useful exactly where the claim above says "no row": it names the
#    vocabulary that WOULD have spoken. Every layer that answers is reported:
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
#               twice would make one claim look like two. A family's CONDITION matchers are asked
#               only of a branch, because that is the only place the lifter asks them: asking them
#               of a statement reports a claim the editor would never make.
#   4. INDEX    the general reverse index over the descriptor templates.
#   5. CALL     the derived call reading - the receiver's class resolved and the method found on it
#               (EventSheetDerivedCalls), with the resolution named: self, node, declared, autoload
#               or class.
#   6. PROPERTY the derived property reading beside it (EventSheetDerivedProperties).
#   7. VERBATIM nothing claimed it, and it stays honest GDScript.
#
# Curated outranks derived, always: where a table claims a line the derived layers never run in the
# editor at all, and their line here is a preview of the fallback rather than a competing claim.
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

## The reading layers, in the order the importer asks them. The order is the enum's own, so the
## printed numbering and this file's walk cannot disagree about what comes before what.
enum Layer {
	TABLE,
	EXAMPLE,
	MATCHER,
	INDEX,
	CALL,
	PROPERTY,
	VERBATIM,
}

## What each layer is called in the printed answer, indexed by `Layer` - a table rather than a word
## written down beside each layer, so the enum and its spelling cannot drift apart. The values are
## stable: the command line prints them and a test pins them.
const LAYER_NAMES: Array[String] = ["table", "example", "matcher", "index", "call", "property",
	"verbatim"]

## How a claim question ended.
enum Row {
	## A row of the reopened sheet emits this line, and `detail` names it.
	NAMED,
	## The file reopens and re-emits itself byte for byte, but no live row's emission covers this
	## line - a blank line, or one of the lines the compiler writes for the file rather than for a
	## row (the `extends` head, a separating blank).
	NONE,
	## The file does not reproduce itself byte for byte, so line N of the re-emission is not line N
	## of the file and no line number can be trusted across the two.
	NOT_REPRODUCIBLE,
	## The importer could not open the text as a sheet at all.
	UNREADABLE,
}

## What a line nothing claims is told. The plainest sentence in the file, deliberately: general
## purpose includes the right to just be code.
const UNCLAIMED: String = "no layer claims this line - it stays verbatim"

## What a blank line is told. Counted by nobody and asked of nothing, said out loud so a mistyped
## line number reads as a mistyped line number rather than as a line no vocabulary wanted.
const BLANK: String = "a blank line - no layer is asked about one"

## What a line outside the file is told.
const OUT_OF_RANGE: String = "there is no such line in this file"

## What the three `Row` answers that are not a row are told.
const NO_ROW: String = "no row emits this line"
const NOT_LOSSLESS: String = "this file does not re-emit byte for byte, so no line number maps"
const NOT_A_SHEET: String = "this file does not open as a sheet"

## The path a buffer with no home of its own is compiled to while the round trip is checked. Nothing
## is written: the compiler only needs a path for the emission that depends on where a file lands.
const BUFFER_PATH: String = "res://event_sheet_provenance_buffer.gd"

## The properties a row is named by in the claim line, tried in this order and first non-empty one
## used. A row kind that names itself some other way falls back to its class, which is still an
## answer somebody can act on.
const NAMING_PROPERTIES: Array[String] = ["name", "title", "kind_id", "trigger_id"]


## One reading layer's answer for one line: the layer, the file or family a developer can go and
## open (empty where there is none), and the answer in words.
class Answer extends RefCounted:
	var layer: Layer
	var where: String
	var detail: String

	func _init(of_layer: Layer, in_file: String, says: String) -> void:
		layer = of_layer
		where = in_file
		detail = says

	## The printed line: the layer's place in the order, its name, the file a developer can open, and
	## the answer. A layer with no file to open leaves that column out rather than printing a gap
	## where a path would be.
	func line() -> String:
		var head: String = "  %d. %-8s" % [int(layer) + 1, EventSheetLiftProvenance.LAYER_NAMES[int(layer)]]
		if where.is_empty():
			return "%s %s" % [head, detail]
		return "%s %s  %s" % [head, where, detail]


## What row a line became, and why it is not one when it is not.
class RowClaim extends RefCounted:
	var kind: Row
	var detail: String

	func _init(of_kind: Row, says: String) -> void:
		kind = of_kind
		detail = says

	## The printed line, in the same two-space column the layer lines use.
	func line() -> String:
		return "  row      %s" % detail


## The row the editor turns this line into, asked of the row builder itself: the file is reopened the
## way opening a `.gd` reopens it, re-emitted the way saving it re-emits it, and the line looked up in
## the source map that emission produced. Structure included - a member declaration is a variable row
## and a connect inside a bare `_ready` is a signal trigger, neither of which the per-line layers
## below can see.
##
## `script_path` is the path the source came from. It matters twice: the readings that resolve a
## receiver against the project use it, and so does any emission that depends on where the file lands.
static func row_claim(source: String, number: int, script_path: String = "") -> RowClaim:
	var path: String = script_path if not script_path.is_empty() else BUFFER_PATH
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source, true,
		script_path)
	if sheet == null:
		return RowClaim.new(Row.UNREADABLE, NOT_A_SHEET)
	sheet.external_source_path = path
	var emitted: Dictionary = SheetCompiler.compile(sheet, path)
	if str(emitted.get("output", "")) != source:
		return RowClaim.new(Row.NOT_REPRODUCIBLE, NOT_LOSSLESS)
	var row: Resource = EventSheetLineRowMapper.resource_for_line(
		emitted.get("source_map", []) as Array, number)
	if row == null:
		return RowClaim.new(Row.NONE, NO_ROW)
	return RowClaim.new(Row.NAMED, _row_detail(row))


## Every layer that WOULD claim one line of one buffer, in provenance order. The list is never empty:
## a line nothing claims comes back as the one VERBATIM entry.
##
## This is the preview beside `row_claim`, not the claim itself - it asks the line as an isolated
## statement, which is how each layer is asked but not how the importer reads a file.
##
## `script_path` is the path the source came from, for the readings that resolve a receiver against
## the project (an Autoload, a class name, the host class of `self`).
static func claims(source: String, number: int, script_path: String = "") -> Array[Answer]:
	var found: Array[Answer] = []
	var lines: PackedStringArray = source.split("\n")
	if number < 1 or number > lines.size():
		found.append(Answer.new(Layer.VERBATIM, "", OUT_OF_RANGE))
		return found
	var statement: String = lines[number - 1].strip_edges()
	if statement.is_empty():
		found.append(Answer.new(Layer.VERBATIM, "", BLANK))
		return found
	var term: String = EventSheetLiftReading.asked_term(statement)
	var table: Answer = _table_answer(statement)
	if table != null:
		found.append(table)
	found.append_array(_matcher_answers(lines, number, statement, term, table))
	if found.is_empty():
		var index: Answer = _index_answer(statement, term)
		if index != null:
			found.append(index)
	found.append_array(_derived_answers(source, statement, script_path))
	if found.is_empty():
		found.append(Answer.new(Layer.VERBATIM, "", UNCLAIMED))
	return found


## The whole answer as the command line prints it and a test pins it: the line itself, then the row it
## became, then one line per layer that would have claimed it. Deterministic over the same tree: every
## walk under it is sorted or comes from a fixed list, and nothing here reads a clock, a machine path
## or a live count.
static func text(source: String, number: int, script_path: String = "") -> String:
	var lines: PackedStringArray = source.split("\n")
	var shown: String = ""
	if number >= 1 and number <= lines.size():
		shown = lines[number - 1].strip_edges()
	var out: PackedStringArray = PackedStringArray()
	out.append("%s:%d  %s" % [script_path if not script_path.is_empty() else "(buffer)", number, shown])
	out.append(row_claim(source, number, script_path).line())
	out.append("  read by:")
	for answer: Answer in claims(source, number, script_path):
		out.append(answer.line())
	return "\n".join(out)


# ── the layers ──────────────────────────────────────────────────────────────────


## Layers 1 and 2, which are one lookup: the table engine claims the line through the reading beside
## this file (so a branch is asked as its term and the packs are asked in their own order), and the
## entry that claimed it says which authoring route it came down. Null when no entry claims it.
static func _table_answer(statement: String) -> Answer:
	var claimed: Dictionary = EventSheetLiftReading.table_claim(statement)
	if claimed.is_empty():
		return null
	var family: String = str(claimed.get("family", ""))
	var entry_id: String = str(claimed.get("entry_id", ""))
	var by_example: bool = _origin_of(family, entry_id) == EventForgeLiftTable.ORIGIN_EXAMPLE
	return Answer.new(Layer.EXAMPLE if by_example else Layer.TABLE, "%s.gd" % family,
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
##
## The CONDITION methods are asked only where the line is a BRANCH, because that is the only place
## the lifter asks them (it reaches its condition-spelling seam from the branch path alone). A family
## whose condition matcher happens to accept a bare expression would otherwise be reported here as a
## claim the editor would never make.
static func _matcher_answers(lines: PackedStringArray, number: int, statement: String, term: String,
		table: Answer) -> Array[Answer]:
	var found: Array[Answer] = []
	var claimed_family: String = table.where if table != null else ""
	var is_branch: bool = term != statement
	for family: GDScript in EventSheetACELifter.SPELLING_FAMILIES:
		var name: String = family.resource_path.get_file()
		if name == claimed_family:
			continue
		for method: String in [EventSheetACELifter.ACTION_SPELLING_METHOD,
				EventSheetACELifter.CONDITION_SPELLING_METHOD,
				EventSheetACELifter.WHOLE_CONDITION_SPELLING_METHOD]:
			var asks_a_branch: bool = method != EventSheetACELifter.ACTION_SPELLING_METHOD
			if asks_a_branch and not is_branch:
				continue
			if not family.has_method(method):
				continue
			var hit: Dictionary = family.call(method, term if asks_a_branch else statement)
			if hit.is_empty():
				continue
			found.append(Answer.new(Layer.MATCHER, name, "%s -> %s" % [method,
				str(hit.get("ace_id", ""))]))
			break
	for family: GDScript in EventSheetACELifter.RUN_FAMILIES:
		if not family.has_method(EventSheetACELifter.RUN_SPELLING_METHOD):
			continue
		var run: Dictionary = family.call(EventSheetACELifter.RUN_SPELLING_METHOD, lines,
			number - 1, _indent_of(lines[number - 1]))
		if run.is_empty():
			continue
		found.append(Answer.new(Layer.MATCHER, family.resource_path.get_file(),
			"%s -> %s over %d lines" % [EventSheetACELifter.RUN_SPELLING_METHOD,
				str(run.get("ace_id", "")), int(run.get("consumed", 1))]))
	return found


## Layer 4: the general reverse index, asked as the whole lifter and only where nothing above
## answered - see the header. A statement is asked as an action and a branch as a condition, which is
## how the lifter itself asks them. Null when the index does not answer either.
static func _index_answer(statement: String, term: String) -> Answer:
	var as_condition: bool = term != statement
	var asked: String = term if as_condition else statement
	var row: Resource = EventSheetACELifter.lift_one_line(asked, as_condition)
	if row is ACEAction:
		return Answer.new(Layer.INDEX, "", "%s::%s" % [(row as ACEAction).provider_id,
			(row as ACEAction).ace_id])
	if row is ACECondition:
		return Answer.new(Layer.INDEX, "", "%s::%s" % [(row as ACECondition).provider_id,
			(row as ACECondition).ace_id])
	return null


## Layers 5 and 6: the derived readings, asked with the same three maps the row builder hoists for
## them - built here off the file's own sheet, through the readers that build them for the canvas, so
## a receiver resolves exactly as it would with the file open.
static func _derived_answers(source: String, statement: String,
		script_path: String) -> Array[Answer]:
	var found: Array[Answer] = []
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
		found.append(Answer.new(Layer.CALL, str(call.get("script_path", "")), "%s.%s (receiver: %s)"
			% [str(call.get("class", "")), str(call.get("method", "")), str(call.get("source", ""))]))
	var written: Dictionary = EventSheetDerivedProperties.derived_reading(
		EventSheetSentence.statement(statement, context), context, class_map, autoloads)
	if not written.is_empty():
		found.append(Answer.new(Layer.PROPERTY, str(written.get("script_path", "")),
			"%s.%s (receiver: %s)" % [str(written.get("class", "")),
				str(written.get("property", "")), str(written.get("source", ""))]))
	return found


# ── the pieces ──────────────────────────────────────────────────────────────────


## A claimed row as the claim line names it: what kind of row it is, then what it is called. An ACE
## row is named by the verb it carries, because that is the thing a developer goes and looks up;
## every other kind is named by the first of NAMING_PROPERTIES it fills in.
static func _row_detail(row: Resource) -> String:
	var script: Script = row.get_script() as Script
	var kind: String = str(script.get_global_name()) if script != null else row.get_class()
	if row is ACEAction:
		return "%s  %s::%s" % [kind, (row as ACEAction).provider_id, (row as ACEAction).ace_id]
	if row is ACECondition:
		return "%s  %s::%s" % [kind, (row as ACECondition).provider_id, (row as ACECondition).ace_id]
	for property: String in NAMING_PROPERTIES:
		var value: Variant = row.get(property)
		if value is String and not (value as String).is_empty():
			return "%s  %s" % [kind, str(value)]
	return kind


## How deep a line is indented, in tabs - what a run family means by depth, read off the line itself
## so a run is asked at the indentation it was written at.
static func _indent_of(line: String) -> int:
	var depth: int = 0
	while depth < line.length() and line[depth] == "\t":
		depth += 1
	return depth
