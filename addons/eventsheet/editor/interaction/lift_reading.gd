@tool
class_name EventSheetLiftReading
extends RefCounted
# Godot EventSheets - WHAT CLAIMS THIS LINE, asked of a buffer instead of a project.
#
# Three places ask the same question about hand-written GDScript and used to answer it three ways:
# the head bar's chip says what share of an opened file reads as rows, the corpus gate pins that
# share per fixture file, and the workbench panel shows a developer, line by line, which recogniser
# claimed what. The share itself has exactly one implementation already
# (EventSheetReadingCoverage.measure), and this adds exactly one more on top of it - the per-line
# attribution - so a fourth caller never has to invent a second reading of the same file.
#
# THE TWO LAYERS ARE NAMED APART, because a reader must always know which one they are looking at:
#
#   LAYER_ENTRY   a lift-table entry claimed the line by name. The strongest claim there is: a
#                 family and an entry id, both of them things a developer can go and open.
#   LAYER_READING the line arrived as a row without a table entry naming it - the general reverse
#                 index, a declaration, a trigger, a note. Real, and plainer.
#   LAYER_CODE    nothing claimed it. It renders as a script block and stays honest GDScript,
#                 counted out loud rather than quietly rounded away.
#   LAYER_QUIET   a blank line. Counted by nobody, shown so the numbering stays the file's own.
#
# THE ROUND TRIP IS PART OF THE READING, not a separate check a caller has to remember: a reading
# carries the re-emitted bytes and the first line they differ on. A derived row IS the line it read,
# so byte-exactness is structural - which is exactly why it is worth proving on every buffer rather
# than trusting the shape of the mechanism.
#
# THE LAYER COUNTS AND THE PERCENTAGE ANSWER DIFFERENT QUESTIONS, and a caller showing both must say
# so. A layer is about NAMING - did any vocabulary claim this line. The percentage is about DRAWING -
# how much of the file the canvas shows as rows rather than as a wall of code. A file can draw
# entirely as rows (100%) and still have lines nothing names, because a verbatim row that the canvas
# has a plainer view for is still verbatim. Reported apart, never added together.
#
# Everything here is static and pure over the passed source, so the corpus gate runs it headless and
# the panel runs it on a scratch buffer with no file behind it.

## The four layers a line can be read at. Values are stable, they key the panel's own styling.
const LAYER_ENTRY: String = "entry"
const LAYER_READING: String = "reading"
const LAYER_CODE: String = "code"
const LAYER_QUIET: String = "quiet"

## What a line that nothing claims is called, in the one place both the panel and the gate read it
## from. It is deliberately the plainest sentence in the file: general purpose includes the right to
## just be code.
const STAYS_CODE: String = "stays code"

## WHERE A READING'S BYTES GO, and the reason this is not the file being read. `SheetCompiler.compile`
## does not only hand its output back: it WRITES it, to the output path it was given or, failing that,
## to the sheet's own source path. A reading that let it default would therefore save every buffer it
## measured back over the file it came from - which is invisible while a file round-trips
## byte-identically (the compiler skips a write whose bytes already match) and is exactly wrong the
## moment one does not: the gate would overwrite the fixture with the drifted bytes and pass on the
## next run, having repaired the evidence. So a reading always compiles to this scratch path, and the
## file behind the buffer is never opened for writing.
##
## It stays the sheet's `external_source_path` all the same - that is what puts it in the source map
## and switches the compiler onto the order-preserving path - so the only thing this changes is where
## the bytes land. Named plainly because the canvas shows the file name at the head of the sheet, and a
## buffer with no file behind it should say so rather than showing an internal scratch name.
const SCRATCH_PATH: String = "user://buffer.gd"


## The whole reading of one buffer:
##   {"sheet", "emitted", "identical", "diff", "coverage", "lines"}
## `diff` is {} when the re-emission is byte-identical, and {"line", "expected", "got"} on the first
## line where it is not. `lines` carries one entry per source line, in file order:
##   {"number", "text", "claim", "layer", "entry_id", "family"}
static func read(source: String, script_path: String = "", scratch_entries: Array = []) -> Dictionary:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source, true, script_path)
	var reading: Dictionary = {
		"sheet": sheet,
		"emitted": "",
		"identical": false,
		"diff": {},
		"coverage": EventSheetReadingCoverage.measure(sheet),
		"lines": [] as Array
	}
	if sheet == null:
		return reading
	# The field that switches the compiler onto the order-preserving external path - the one that
	# reproduces an untouched file byte for byte. import_external_source builds the rows but leaves
	# it unset (only opening a real file sets it), so a reading that forgot this line would compile
	# the buffer as a fresh sheet and call every file in the corpus drifted.
	if sheet.external_source_path.is_empty():
		sheet.external_source_path = script_path if not script_path.is_empty() else SCRATCH_PATH
	# The scratch path, never the file's own - see SCRATCH_PATH. A reading measures; it does not save.
	var compiled: Dictionary = SheetCompiler.compile(sheet, SCRATCH_PATH)
	var emitted: String = str(compiled.get("output", ""))
	reading["emitted"] = emitted
	reading["identical"] = emitted == source
	reading["diff"] = _first_difference(source, emitted)
	reading["lines"] = _claim_lines(source, sheet, compiled.get("source_map", []) as Array, scratch_entries)
	return reading


## The share of the buffer that reads as rows, as the ONE reader every other caller of that number
## already uses. Named here so the panel and the gate reach for coverage the same way they reach for
## the claims, without either of them growing a second opinion about what a row is.
static func percent(reading: Dictionary) -> int:
	return int((reading.get("coverage", {}) as Dictionary).get("percent", 0))


## How many lines each layer claimed: {"entry", "reading", "code", "quiet"}. The panel's tally strip,
## and the sentence a commit states a moved pin with.
static func layer_counts(reading: Dictionary) -> Dictionary:
	var counts: Dictionary = {LAYER_ENTRY: 0, LAYER_READING: 0, LAYER_CODE: 0, LAYER_QUIET: 0}
	for line: Variant in reading.get("lines", []) as Array:
		var layer: String = str((line as Dictionary).get("layer", LAYER_QUIET))
		counts[layer] = int(counts.get(layer, 0)) + 1
	return counts


## The claim on ONE statement, asked of the lift tables alone - no import, no compile. This is the
## cheap half of the reading, and it is what makes the panel's refresh a buffer-sized job rather than
## a project-sized one. {} when no table entry claims the line.
##
## `scratch_entries` are entries the caller derived itself (the panel's draft table); they are asked
## FIRST and come back marked as the scratch family they are, so a draft never looks like a shipped
## spelling.
static func table_claim(line: String, scratch_entries: Array = []) -> Dictionary:
	var text: String = _asked_term(line.strip_edges())
	if text.is_empty() or text.begins_with("#"):
		return {}
	if not scratch_entries.is_empty():
		# A REFUSED entry has no pattern, and an empty pattern matches every line - so a draft the
		# example engine could not answer would otherwise claim the whole buffer. Shipped families
		# never reach that state (the validator fails the suite on a refusal), but a draft typed into
		# the workbench does, which is exactly why the filter lives here rather than in the table.
		var usable: Array = []
		for entry: Variant in scratch_entries:
			if entry is Dictionary and not (entry as Dictionary).has(EventForgeLiftTable.REFUSAL_KEY):
				usable.append(entry)
		var drafted: Dictionary = EventForgeLiftTable.match_line(usable, text)
		if not drafted.is_empty():
			return {"family": "draft", "entry_id": str(drafted.get("entry_id", "")),
				"ace_id": str(drafted.get("ace_id", ""))}
	for path: Variant in _family_paths():
		var entries: Variant = _families().get(path, [])
		var claimed: Dictionary = EventForgeLiftTable.match_line(entries as Array, text)
		if claimed.is_empty():
			continue
		return {"family": str(path).get_file().trim_suffix(".gd"),
			"entry_id": str(claimed.get("entry_id", "")), "ace_id": str(claimed.get("ace_id", ""))}
	return {}


# ── the pieces ──────────────────────────────────────────────────────────────────


## The part of a line a lift table is actually asked about. For a statement that is the whole line;
## for a BRANCH it is the question inside it, because a condition family's entries are written to
## match the term (`event.is_action_pressed("jump")`) and never the branch that carries it.
##
## Without this a condition family could never show at the entry layer: its lines fell through to the
## general reading, which named them correctly and said nothing about WHICH vocabulary named them -
## so a family of questions looked, on the tally, exactly like a family nobody had written.
##
## Only the three heads the emitter itself writes, and only when the line ends in the colon that
## makes it a branch. A line beginning with the word "if" that is not a branch (there is no such
## statement in GDScript) cannot reach this, and a term is asked exactly as it was written.
static func _asked_term(text: String) -> String:
	if not text.ends_with(":"):
		return text
	for head: String in ["if ", "elif ", "while "]:
		if text.begins_with(head):
			return text.substr(head.length(), text.length() - head.length() - 1).strip_edges()
	return text


## One entry per source line, in this order and for this reason:
##
##   1. BLANK lines are nobody's.
##   2. Lines inside a SCRIPT BLOCK stay code. Asked before every claim, and asked of the shared
##      coverage walk rather than of the text, so this and the percentage can never disagree about
##      what a block is: a line the walk counts as code cannot show a claim here, whatever its
##      spelling would have matched had the lifter reached it.
##   3. A LIFT-TABLE entry - the specific claim, which names itself: a family and an id a developer
##      can go and open.
##   4. The ROW the statement became, named by its descriptor. This is the general reading, and it is
##      matched by re-emitting every row of the sheet and finding the line it wrote. That sounds
##      indirect and is in fact the only exact answer available: the compiler's source map stops at
##      the EVENT, so it can say which event a statement is in but never which action it is. The
##      round trip is byte-identical, so a row's emitted line IS a line of the buffer, and matching
##      them is a lookup rather than a guess.
##   5. Otherwise the row the source map points the line at - but only where the line is that row's
##      OWN first line (a function header, an event's trigger line, a declaration). A statement in
##      the middle of an event is not the trigger, and saying so would name the wrong thing.
static func _claim_lines(source: String, sheet: EventSheetResource, source_map: Array,
		scratch_entries: Array) -> Array:
	var lines: Array = []
	var block_lines: Dictionary = _block_lines(sheet, source_map)
	var row_lines: Dictionary = _row_lines(sheet)
	var source_lines: PackedStringArray = source.split("
")
	for index: int in range(source_lines.size()):
		var text: String = source_lines[index]
		var number: int = index + 1
		var entry: Dictionary = {"number": number, "text": text, "claim": "",
			"layer": LAYER_QUIET, "entry_id": "", "family": ""}
		if text.strip_edges().is_empty():
			lines.append(entry)
			continue
		if block_lines.has(number):
			entry["layer"] = LAYER_CODE
			entry["claim"] = STAYS_CODE
			lines.append(entry)
			continue
		var claimed: Dictionary = table_claim(text, scratch_entries)
		if not claimed.is_empty():
			entry["layer"] = LAYER_ENTRY
			entry["family"] = str(claimed.get("family", ""))
			entry["entry_id"] = str(claimed.get("entry_id", ""))
			entry["claim"] = "%s · %s" % [entry["family"], entry["entry_id"]]
			lines.append(entry)
			continue
		var named: String = _take_row_name(row_lines, text)
		if not named.is_empty():
			entry["layer"] = LAYER_READING
			entry["claim"] = named
			lines.append(entry)
			continue
		var own: Resource = _own_first_line(source_map, number, text)
		var read: Dictionary = _row_claim(own if own != null else
			EventSheetLineRowMapper.resource_for_line(source_map, number), sheet)
		entry["layer"] = str(read.get("layer", LAYER_READING))
		entry["claim"] = str(read.get("claim", "reads as a row"))
		lines.append(entry)
	return lines


## Every line number that sits inside a script block, as a set. The blocks come from the shared
## coverage walk (the same list the head bar's chip clicks through) and their line ranges from the
## compile that just produced the bytes, so the set is exactly the lines the percentage docked.
static func _block_lines(sheet: EventSheetResource, source_map: Array) -> Dictionary:
	var numbers: Dictionary = {}
	for block: RawCodeRow in EventSheetReadingCoverage.script_blocks(sheet):
		var span: Vector2i = EventSheetLineRowMapper.range_for_resource(source_map, block)
		if span.x <= 0:
			continue
		for number: int in range(span.x, span.y + 1):
			numbers[number] = true
	return numbers


## The map's row for a line, but only when the line is that row's OWN - its first line, or the `func`
## header of a function whose range starts at an annotation above it. Keeps a statement in the middle
## of an event from being attributed to the event's trigger.
static func _own_first_line(source_map: Array, number: int, text: String) -> Resource:
	var stripped: String = text.strip_edges()
	var header: bool = stripped.begins_with("func ") or stripped.begins_with("static func ")
	for map_entry: Variant in EventSheetLineRowMapper.entries_for_line(source_map, number):
		if int((map_entry as Dictionary).get("start", 0)) != number and not header:
			continue
		var row: Resource = instance_from_id(int(str((map_entry as Dictionary).get("uid", "0")))) as Resource
		if row != null:
			return row
	# A lifecycle handler's header is outside every range: the event the trigger became starts at the
	# first line of the BODY. So a `func` line nothing contains is answered by what follows it, which
	# is the event it opens.
	if header:
		for map_entry: Variant in EventSheetLineRowMapper.entries_for_line(source_map, number + 1):
			var below: Resource = instance_from_id(int(str((map_entry as Dictionary).get("uid", "0")))) as Resource
			if below is EventRow and not (below as EventRow).trigger_id.is_empty():
				return below
	return null


## Every line the sheet's ACE rows emit, as {stripped line: [names, in sheet order]}. A name is
## TAKEN when a source line uses it, so two identical statements are attributed to the two rows that
## wrote them rather than both to the first.
##
## A condition is registered under the three spellings the emitter can write it in - the bare
## expression and the two branch heads - because a condition IS the `if` line of its event.
static func _row_lines(sheet: EventSheetResource) -> Dictionary:
	var found: Dictionary = {}
	if sheet != null:
		_collect_row_lines(sheet.events, found)
		for function_entry: Variant in sheet.functions:
			if function_entry is EventFunction:
				_collect_row_lines((function_entry as EventFunction).events, found)
	return found


static func _collect_row_lines(items: Array, found: Dictionary) -> void:
	for item: Variant in items:
		if item is ACEAction:
			var action: ACEAction = item as ACEAction
			var name: String = _descriptor_name(action.provider_id, action.ace_id, "action")
			for line: String in ActionCodegen.generate_action(action).split("
"):
				_register_row_line(found, line, name)
		elif item is EventRow:
			var event: EventRow = item as EventRow
			for condition: Variant in event.conditions:
				if not (condition is ACECondition):
					continue
				var term: ACECondition = condition as ACECondition
				var name: String = _descriptor_name(term.provider_id, term.ace_id, "condition")
				var expression: String = ConditionCodegen.generate_condition(term)
				_register_row_line(found, expression, name)
				_register_row_line(found, "if %s:" % expression, name)
				_register_row_line(found, "elif %s:" % expression, name)
				# A loop's guard is the same condition said as a loop head - the While row's own
				# spelling - so the line reads as the row it is rather than as the event around it.
				_register_row_line(found, "while %s:" % expression, name)
			_collect_row_lines(event.actions, found)
			_collect_row_lines(event.sub_events, found)
		elif item is EventGroup:
			_collect_row_lines((item as EventGroup).events, found)
		elif item is EventFunction:
			_collect_row_lines((item as EventFunction).events, found)


static func _register_row_line(found: Dictionary, line: String, name: String) -> void:
	var key: String = line.strip_edges()
	if key.is_empty():
		return
	if not found.has(key):
		found[key] = [] as Array
	(found[key] as Array).append(name)


## The next unused row name for a line, or "" when no row wrote it.
static func _take_row_name(row_lines: Dictionary, text: String) -> String:
	var key: String = text.strip_edges()
	var names: Variant = row_lines.get(key, null)
	if not (names is Array) or (names as Array).is_empty():
		return ""
	var name: String = str((names as Array)[0])
	(names as Array).remove_at(0)
	return name


## What a ROW is, said plainly. Deliberately plainer words than an entry's family·id: the reader has
## to be able to tell a named entry from the general reading at a glance.
static func _row_claim(row: Resource, sheet: EventSheetResource) -> Dictionary:
	if row == null:
		return {"claim": "reads as a row", "layer": LAYER_READING}
	if row is RawCodeRow:
		# Verbatim, and nothing above named it: the sheet is showing this line as the code it is.
		# Two verbatim rows are NOT that, and are named instead of being lumped in with it - the
		# class setup strip at the top of every file, and a run of notes.
		var raw: RawCodeRow = row as RawCodeRow
		var code_lines: PackedStringArray = raw.code.split("
")
		if ViewportRowBuilder.is_comment_only_block(code_lines):
			return {"claim": "note", "layer": LAYER_READING}
		if sheet != null and sheet.events.has(raw) and EventSheetViewport.is_scaffolding_code(raw.code):
			return {"claim": "class setup", "layer": LAYER_READING}
		return {"claim": STAYS_CODE, "layer": LAYER_CODE}
	if row is ACEAction:
		return {"claim": _descriptor_name((row as ACEAction).provider_id, (row as ACEAction).ace_id,
			"action"), "layer": LAYER_READING}
	if row is ACECondition:
		return {"claim": _descriptor_name((row as ACECondition).provider_id,
			(row as ACECondition).ace_id, "condition"), "layer": LAYER_READING}
	if row is EventRow:
		var event: EventRow = row as EventRow
		# An event's own first line is its CONDITION when it has one - `while lives > 0:` is the While
		# row, not the trigger the loop happens to sit under. The trigger only answers for an event
		# that asks nothing, which is the handler itself.
		for condition: Variant in event.conditions:
			if condition is ACECondition:
				return {"claim": _descriptor_name((condition as ACECondition).provider_id,
					(condition as ACECondition).ace_id, "condition"), "layer": LAYER_READING}
		# A NESTED event inherits the handler's trigger id, so naming it by that trigger would print
		# "On Ready" against a line halfway down the body. Only the sheet's own top-level event is
		# the trigger; anything under it that asks nothing is a row without a better name.
		if event.trigger_id.is_empty() or sheet == null or not sheet.events.has(event):
			return {"claim": "reads as a row", "layer": LAYER_READING}
		return {"claim": _descriptor_name(event.trigger_provider_id, event.trigger_id, "trigger"),
			"layer": LAYER_READING}
	if row is EventFunction:
		return {"claim": "function %s" % (row as EventFunction).function_name, "layer": LAYER_READING}
	if row is LocalVariable:
		return {"claim": "declaration", "layer": LAYER_READING}
	if row is CommentRow:
		return {"claim": "note", "layer": LAYER_READING}
	return {"claim": "reads as a row", "layer": LAYER_READING}


## A descriptor's own words when the registry has it, and the id plus what kind of thing it is when
## it does not - never a blank cell, because a blank cell reads as "nothing claimed it".
static func _descriptor_name(provider_id: String, ace_id: String, kind: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
	if descriptor != null and not descriptor.display_name.is_empty():
		return descriptor.display_name
	return "%s (%s)" % [ace_id, kind]



## The first line the re-emission differs on, with both sides - {} when they are identical. The panel
## shows the exact bytes rather than "they differ", because a trailing space is the whole bug.
static func _first_difference(source: String, emitted: String) -> Dictionary:
	if source == emitted:
		return {}
	var left: PackedStringArray = source.split("\n")
	var right: PackedStringArray = emitted.split("\n")
	for index: int in range(maxi(left.size(), right.size())):
		# One side running out IS the difference (a buffer with no final newline is the common one), so
		# it is said in words rather than shown as an empty cell that looks like a blank line.
		var expected: String = left[index] if index < left.size() else "(the buffer ends here)"
		var got: String = right[index] if index < right.size() else "(the saved file ends here)"
		if expected != got:
			return {"line": index + 1, "expected": expected, "got": got}
	return {"line": 0, "expected": source, "got": emitted}


## The family tables, cached for the life of the session - the panel asks this per line of a buffer
## on every debounced refresh, and rescanning a folder per line is the only way to make a
## buffer-sized job feel like a project-sized one.
static var _family_cache: Dictionary = {}
static var _family_order: PackedStringArray = PackedStringArray()


static func _families() -> Dictionary:
	if _family_cache.is_empty():
		_family_cache = EventForgeLiftTable.families()
		var paths: PackedStringArray = PackedStringArray()
		for path: Variant in _family_cache.keys():
			paths.append(str(path))
		paths.sort()
		_family_order = paths
	return _family_cache


## Sorted, so the family a line is attributed to is the same on every machine.
static func _family_paths() -> PackedStringArray:
	_families()
	return _family_order


## Drops the family cache. The panel calls it when a draft is appended, so a developer who has just
## edited a real family file sees the new spelling without restarting the editor.
static func clear_cache() -> void:
	_family_cache = {}
	_family_order = PackedStringArray()
