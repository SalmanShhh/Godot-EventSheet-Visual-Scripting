# Godot EventSheets - how much of an opened file arrived as rows, and where the rest of it is.
#
# THE ONE NUMBER A READER WANTS ON OPENING a .gd as a sheet: what share of it reads as events, and a
# way to walk the parts that did not. The parts that did not are SCRIPT BLOCKS - the sheet's own name
# for embedded code - and they are exactly the lines the corpus gate counts when it asserts that
# almost nothing of a real hand-written file still renders as a wall of code.
#
# WHY THIS IS ONE SHARED STATIC AND NOT TWO COUNTERS. The chip on the Include bar and
# tests/handwritten_lift_gate_test.gd are answering the same question, and a second implementation of
# it would drift the moment either side learned a new row shape - the gate would keep passing while
# the chip told the reader a different number about the same file. So the walk lives here, both call
# it, and the test pins that the two agree.
#
# The walk mirrors the RENDERER's dispatch order, not how rows happen to be stored: a single
# statement draws as an ordinary action row and a literal entry as a chip, so neither is a script
# block even though both are stored as verbatim code. A gate (or a chip) that measured storage would
# go on reporting a clean file while the canvas filled up with code.
@tool
class_name EventSheetReadingCoverage
extends RefCounted


## The coverage of one sheet:
##   {"block_lines", "block_rows", "read_lines", "total_lines", "percent"}
## `block_lines` is the corpus gate's own measure; `block_rows` is how many separate script blocks
## those lines sit in (the number the chip shows, because it is the number of places to go); and
## `percent` is the share of lines that arrived as rows, floored - a file with even one script block
## left never rounds up to 100%, because "100% reads as events, 1 script block" is a sentence a
## reader would rightly call a lie.
static func measure(sheet: EventSheetResource) -> Dictionary:
	var tally: Dictionary = _new_tally()
	if sheet == null:
		return {"block_lines": 0, "block_rows": 0, "read_lines": 0, "total_lines": 0, "percent": 100}
	_walk(sheet.events, true, tally)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			_walk((function_entry as EventFunction).events, false, tally)
	var total: int = int(tally["total_lines"])
	var blocks: int = int(tally["block_lines"])
	var read: int = maxi(total - blocks, 0)
	var percent: int = 100
	if total > 0:
		percent = int(floor(100.0 * float(read) / float(total)))
	if int(tally["block_rows"]) > 0:
		percent = mini(percent, 99)
	return {
		"block_lines": blocks,
		"block_rows": int(tally["block_rows"]),
		"read_lines": read,
		"total_lines": total,
		"percent": percent
	}


## E1. The same census, filtered to the NETWORKING lines: {"read", "blocked", "total", "percent"}.
## The one number the owner of an existing multiplayer project wants on opening it - how much of what
## this script says about the network arrived as rows, and how much of it the sheet can only show
## them as code. Counted through the very same walk as `measure`, so the two can never disagree
## about what a row is; only the filter differs.
static func networking(sheet: EventSheetResource) -> Dictionary:
	if sheet == null:
		return {"read": 0, "blocked": 0, "total": 0, "percent": 100}
	var tally: Dictionary = _new_tally()
	_walk(sheet.events, true, tally, true)
	for function_entry: Variant in sheet.functions:
		var event_function: EventFunction = function_entry as EventFunction
		if event_function == null:
			continue
		# A function marked `@rpc` IS a networking line - the annotation is what makes it a message.
		for annotation: String in event_function.annotation_lines:
			if EventForgeMultiplayerLift.is_networking_line(annotation):
				tally["net_lines"] = int(tally["net_lines"]) + 1
				break
		_walk(event_function.events, false, tally, true)
	var total: int = int(tally["net_lines"])
	var blocked: int = int(tally["net_block_lines"])
	var percent: int = 100
	if total > 0:
		percent = int(floor(100.0 * float(total - blocked) / float(total)))
	return {"read": total - blocked, "blocked": blocked, "total": total, "percent": percent}


## E1. The networking count in words, for the head band and the Doctor's per-script line. "" when the
## script says nothing about the network at all, because "0 of 0" is a number with nothing in it.
static func networking_text(sheet: EventSheetResource) -> String:
	var coverage: Dictionary = networking(sheet)
	var total: int = int(coverage.get("total", 0))
	if total <= 0:
		return ""
	var read: int = int(coverage.get("read", 0))
	if read == total:
		return EventSheetL10n.translate("every networking line reads as a row - %d of %d") % [read, total]
	return EventSheetL10n.translate("%d of %d networking lines read as rows") % [read, total]


## The script blocks themselves, in file order - the walk targets the chip clicks through. Same
## dispatch as `measure`, so the chip's count and the list it walks can never disagree.
static func script_blocks(sheet: EventSheetResource) -> Array[RawCodeRow]:
	var found: Array[RawCodeRow] = []
	if sheet == null:
		return found
	_collect(sheet.events, true, found)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			_collect((function_entry as EventFunction).events, false, found)
	return found


## The chip's words. On a fully-lifted file it drops the number entirely and just says the good news;
## otherwise it says the share and how many places the rest of it is in.
static func chip_text(sheet: EventSheetResource) -> String:
	var coverage: Dictionary = measure(sheet)
	var blocks: int = int(coverage.get("block_rows", 0))
	if blocks <= 0:
		var patterns_only: String = pattern_chip_text(sheet)
		if patterns_only.is_empty():
			return EventSheetL10n.translate("reads as events")
		# The ▸ is the promise that a click goes somewhere, so it appears exactly when there is
		# something to walk - here, the ⟡ events the counts are about.
		return "%s%s ▸" % [EventSheetL10n.translate("reads as events"), patterns_only]
	var blocks_text: String = EventSheetL10n.translate("1 script block") if blocks == 1 \
		else EventSheetL10n.translate("%d script blocks") % blocks
	return "%d%% %s · %s%s ▸" % [int(coverage.get("percent", 0)),
		EventSheetL10n.translate("reads as events"), blocks_text, pattern_chip_text(sheet)]


## S25 - the two counts the chip grows once the readings have claimed something: how many DISTINCT
## patterns this file is made of, and how many of those a shipped behavior could take over. "" when
## nothing was claimed, because "0 patterns" is a number with nothing in it.
##
## Read straight off the claim registry, so the chip can only ever say what the ⟡ chips in the sheet
## already say - the count and the marks are the same fact counted once.
static func pattern_chip_text(sheet: EventSheetResource) -> String:
	# Counted over the MARKED patterns only, so the number matches the ⟡ chips a reader can go and
	# find: a pattern the sheet does not mark is one they would hunt for and never see.
	EventSheetViewportReadingRows.ensure_claims(sheet)
	var marked: Dictionary = {}
	var behaviors: Dictionary = {}
	for claim: Variant in EventSheetPatternFacts.claims(sheet):
		var pattern: String = str((claim as Dictionary).get("pattern", ""))
		if not EventSheetPatternVocabulary.is_marked(pattern):
			continue
		marked[pattern] = true
		# The ADOPTABLE half asks the vocabulary rather than the claim's own field, so the number is
		# the number of offers a reader will actually find: a reading that has not yet learned to
		# name the behavior still leaves the pattern's own default standing.
		if not EventSheetPatternVocabulary.adoptable_for(claim as Dictionary).is_empty():
			behaviors[pattern] = true
	var patterns: int = marked.size()
	if patterns <= 0:
		return ""
	var patterns_text: String = EventSheetL10n.translate("1 pattern") if patterns == 1 \
		else EventSheetL10n.translate("%d patterns") % patterns
	var adoptable: int = behaviors.size()
	if adoptable <= 0:
		return " · %s" % patterns_text
	return " · %s · %s" % [patterns_text, EventSheetL10n.translate("%d adoptable") % adoptable]


## The engine's own parse errors for this file, as the sheet's importer recorded them - [] when the
## file compiles. Read defensively off sheet METADATA rather than a property, so a sheet built by
## anything else (a test, the API) simply has none.
static func parse_errors(sheet: EventSheetResource) -> Array:
	if sheet == null or not sheet.has_meta("__parse_errors"):
		return []
	var recorded: Variant = sheet.get_meta("__parse_errors")
	return recorded if recorded is Array else []


## The red line the Include bar wears when the file does not compile: how many errors, and what that
## costs. "" when there are none.
static func parse_error_text(sheet: EventSheetResource) -> String:
	var errors: Array = parse_errors(sheet)
	if errors.is_empty():
		return ""
	var count_text: String = EventSheetL10n.translate("1 error") if errors.size() == 1 \
		else EventSheetL10n.translate("%d errors") % errors.size()
	return "%s - %s" % [count_text, EventSheetL10n.translate("the game will not run this script")]


## Lines that reach the plain GDScript-block rendering: the corpus gate's measure, kept here so the
## gate and the chip share one definition. `items` is a row list, `top_level` says whether it is the
## sheet's own root list (where the Class setup strip folds instead of drawing).
static func block_line_count(items: Array, top_level: bool) -> int:
	var tally: Dictionary = _new_tally()
	_walk(items, top_level, tally)
	return int(tally["block_lines"])


## The counters one walk fills. `net_*` stay at zero unless the caller asked for them.
static func _new_tally() -> Dictionary:
	return {"block_lines": 0, "block_rows": 0, "total_lines": 0, "net_lines": 0, "net_block_lines": 0}


## True when a verbatim row falls through every structured view the canvas offers it.
static func renders_as_block(raw: RawCodeRow, top_level: bool) -> bool:
	if raw == null:
		return false
	var code_lines: PackedStringArray = raw.code.split("\n")
	if ViewportRowBuilder.is_comment_only_block(code_lines) or ViewportRowBuilder.is_blank_block(code_lines):
		return false
	# A single statement renders as an ordinary action row, and a literal entry as an action chip -
	# neither is the code-block treatment, so neither counts here.
	if ViewportRowBuilder.is_literal_part(raw.code) or ViewportRowBuilder.is_single_statement(raw.code):
		return false
	if not ViewportRowBuilder.data_literal_info(raw.code).is_empty():
		return false
	if not ViewportRowBuilder.function_body_info(raw.code).is_empty():
		return false
	if not ViewportRowBuilder.define_shell_info(raw.code).is_empty():
		return false
	if top_level and EventSheetViewport.is_scaffolding_code(raw.code):
		return false
	return true


## The one walk both numbers come from. `total_lines` counts what a reader is looking at, one line
## per thing the file says: every non-blank line of a verbatim row, one per declaration, one per
## condition or action, one for the event line itself. It is a reading of the sheet rather than a
## re-read of the file, which is what keeps this cheap enough to run on every head build.
static func _walk(items: Array, top_level: bool, tally: Dictionary, networking_too: bool = false) -> void:
	for item: Variant in items:
		if item is RawCodeRow:
			var raw: RawCodeRow = item as RawCodeRow
			var lines: int = 0
			var networking_lines: int = 0
			for line: String in raw.code.split("\n"):
				if line.strip_edges().is_empty():
					continue
				lines += 1
				if networking_too and EventForgeMultiplayerLift.is_networking_line(line):
					networking_lines += 1
			tally["total_lines"] = int(tally["total_lines"]) + lines
			tally["net_lines"] = int(tally["net_lines"]) + networking_lines
			if renders_as_block(raw, top_level):
				tally["block_lines"] = int(tally["block_lines"]) + lines
				tally["block_rows"] = int(tally["block_rows"]) + 1
				tally["net_block_lines"] = int(tally["net_block_lines"]) + networking_lines
		elif item is EventRow:
			var event: EventRow = item as EventRow
			tally["total_lines"] = int(tally["total_lines"]) + 1 + event.conditions.size()
			if networking_too:
				if _multiplayer_vocabulary(event.trigger_provider_id, event.trigger_id):
					tally["net_lines"] = int(tally["net_lines"]) + 1
				for condition: Variant in event.conditions:
					if _networking_row(condition):
						tally["net_lines"] = int(tally["net_lines"]) + 1
			_walk(event.actions, false, tally, networking_too)
			_walk(event.sub_events, false, tally, networking_too)
		elif item is ACEAction:
			# Split out of the catch-all below only so the networking filter can ask what this row is
			# about; it counts as the one line it always counted as.
			tally["total_lines"] = int(tally["total_lines"]) + 1
			if networking_too and _networking_row(item):
				tally["net_lines"] = int(tally["net_lines"]) + 1
		elif item is EventFunction:
			tally["total_lines"] = int(tally["total_lines"]) + 1
			_walk((item as EventFunction).events, false, tally, networking_too)
		elif item is EventGroup:
			_walk((item as EventGroup).events, top_level, tally, networking_too)
		elif item is CommentRow:
			var comment_lines: int = 0
			for line: String in (item as CommentRow).text.split("\n"):
				if not line.strip_edges().is_empty():
					comment_lines += 1
			tally["total_lines"] = int(tally["total_lines"]) + maxi(comment_lines, 1)
		elif item != null:
			tally["total_lines"] = int(tally["total_lines"]) + 1


## E1. Whether a row is part of the networking story: it is filed under the Multiplayer object, or
## the LINE it compiles to answers the same question `is_networking_line` asks of a verbatim line. So
## a `peer.create_server(…)` the sheet could only claim as a Call Method row still counts against the
## number, and a row added to the Multiplayer object counts the moment it exists.
static func _networking_row(row: Variant) -> bool:
	if row is ACEAction:
		var action: ACEAction = row as ACEAction
		return _multiplayer_vocabulary(action.provider_id, action.ace_id) \
			or EventForgeMultiplayerLift.is_networking_line(ActionCodegen.generate_action(action))
	if row is ACECondition:
		var condition: ACECondition = row as ACECondition
		return _multiplayer_vocabulary(condition.provider_id, condition.ace_id) \
			or EventForgeMultiplayerLift.is_networking_line(ConditionCodegen.generate_condition(condition))
	return false


## E1. Whether an id belongs to the Multiplayer object. Asked of the registry rather than kept as a
## list here, and it is the only question a TRIGGER can be asked: a trigger names a signal, so there
## is no inline template to read.
static func _multiplayer_vocabulary(provider_id: String, ace_id: String) -> bool:
	if ace_id.is_empty():
		return false
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
	return descriptor != null and descriptor.category == EventForgeMultiplayerACEs.CATEGORY


static func _collect(items: Array, top_level: bool, found: Array[RawCodeRow]) -> void:
	for item: Variant in items:
		if item is RawCodeRow:
			if renders_as_block(item as RawCodeRow, top_level):
				found.append(item as RawCodeRow)
		elif item is EventRow:
			_collect((item as EventRow).actions, false, found)
			_collect((item as EventRow).sub_events, false, found)
		elif item is EventFunction:
			_collect((item as EventFunction).events, false, found)
		elif item is EventGroup:
			_collect((item as EventGroup).events, top_level, found)
