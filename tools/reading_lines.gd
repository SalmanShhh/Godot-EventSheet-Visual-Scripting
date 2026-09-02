# Godot EventSheets - A ROW'S READING AS ONE LINE, AND THE PATH THAT SHAPED IT (dev tool).
#
# The row builder turns a descriptor, a lifted line or a picked verb into the words a cell draws.
# Those words are DATA - a row's spans are what a reader sees - and until now nothing in the tree
# wrote them down, so a refactor of the two reading files could move a sentence in a corner of the
# vocabulary and no gate would say so. This module is that written-down form: one line per CELL,
# deterministic, sorted, escaped like the registry dumps beside it, with the path that shaped the
# reading as its last field.
#
# THE UNIT IS THE CELL, not the row. A row can hold a trigger, several conditions and several
# actions, and each of those is a separate reading with its own lane, its own object word and its own
# path through the builder. A row that is not an ACE row at all - a group head, a band, a comment, a
# variable - is one cell of lane `-`, because it is one reading too.
#
# THE PATH FIELD is the census class (below) plus the branch that answered, which is the whole point
# of the text: `template` says the generic assembly drew this cell out of the descriptor and nothing
# else was consulted; `grammar:AddVar` says the shared sentence grammar claimed it through that arm;
# `bespoke:_function_call_label` names the per-vocabulary branch that did. Wave-by-wave, the share of
# cells that say `template` is the share of the two reading files that is not re-saying what the
# descriptor already says.
#
# HOW A PATH IS DECIDED. By asking the real readers, never by reimplementing their decision tree:
# the grammar is asked whether it claims the row (`grammar_action_sentence` / its condition twin),
# the derived-property upgrade is asked whether it rewrote that claim, the handful of named branches
# are asked their own predicates, and what is left is the generic assembly. Beside every ACE cell the
# module also assembles the GENERIC reading of the same row - the descriptor's display template with
# the row's own values, and the object word `_object_label_for` gives it - so a bespoke cell can be
# asked the one question the census exists to answer: would the generic path have said the same
# thing? That comparison is made at the BASE level (before the row decorations - the hourglass, the
# note chip, the trailing comment - which every path wears alike), so it compares the two assemblies
# and not the dressing around them.
#
# NOTHING HERE IS A READER. Every answer comes from the shipped row builder through a live viewport,
# so a reading this module writes down is a reading the editor draws. It adds no seam to the two
# files it measures and it ships with nothing: its callers are `tools/reading_dump.gd`,
# `tools/reading_census.gd`, `tools/explain.gd` and their tests, which is why it lives in `tools/`
# and carries no `class_name`, exactly like `tools/registry_wording.gd` beside it.
@tool
extends RefCounted

## Bumped only when the LINE SHAPE changes, so a text kept beside an older tree cannot quietly report
## every reading as moved. Independent of the registry dumps' versions: this text changes for its own
## reasons.
const FORMAT_VERSION: int = 1

## The one line that is not a reading. Comment-led, so a diff can skip it without a special case.
const HEADER: String = "# eventsheets reading dump %d" % FORMAT_VERSION

## Between fields. A tab, because a reading is full of every other punctuation mark there is.
const SEPARATOR: String = "\t"

## The fields of a line, in order, named so a reader and a test spell them the same way.
const FIELDS: PackedStringArray = ["origin", "lane", "object", "segments", "path"]

## Between the segments of one cell. A middle dot with spaces, which no span text of the shipped
## vocabulary contains and which stays readable in a diff.
const SEGMENT_JOIN: String = " · "

## The lane a reading that is not an ACE cell carries. A single character, so the column stays a
## column.
const LANE_STRUCTURE: String = "-"


## The paths a cell's words can come down. The order is the order the builder asks them in, so the
## enum and the walk below cannot disagree about what outranks what.
enum Path {
	## The shared sentence grammar claimed the row (`EventSheetSentence`, reached through
	## `grammar_action_sentence` / `grammar_condition_sentence`). The branch names the `ace_id` arm
	## that routed it there, or `(pre-match)` for the hooks that run before the arm table.
	GRAMMAR,
	## A derived reading rewrote what the grammar claimed - the derived-property upgrade, or the
	## derived-call pieces a generic call reads through.
	DERIVED,
	## A named per-vocabulary branch in the row builder answered instead of the generic assembly.
	## The branch names the function.
	BESPOKE,
	## The generic assembly and nothing else: the descriptor's display template, the row's own
	## values, and the object word the descriptor's own facts give it.
	TEMPLATE,
	## A raw code row - the line stays the code it is, and there is no reading to attribute.
	VERBATIM,
	## Not an ACE cell at all: a head band, a group, a comment, a variable, a region fence. Counted
	## apart because it is chrome the vocabulary never enters.
	STRUCTURE,
}

## What each path is called in the written line, indexed by `Path` - a table rather than a word
## repeated beside each case, so the enum and its spelling cannot drift apart. The values are stable:
## the dump prints them, the census groups on them and a test pins them.
const PATH_NAMES: Array[String] = ["grammar", "derived", "bespoke", "template", "verbatim",
	"structure"]

## The branch written down when the grammar claimed a row before its `ace_id` arm table was reached -
## a behaviour shape, an orbit, a board trick, one of the ids read as the line it compiles to.
const BRANCH_PRE_MATCH: String = "(pre-match)"

## The branch written down when a bespoke path is the one that runs when the installed vocabulary has
## no descriptor for the row at all. Two of them, in the order the builder asks: the reading baked
## onto the row when it was applied, then the reflected member's own sentence.
const BRANCH_STORED: String = "_stored_reading"
const BRANCH_REFLECTED: String = "_reflected_member_sentence"

## The remaining named branches, each the function that answers instead of the generic assembly.
const BRANCH_FUNCTION_CALL: String = "_function_call_label"
const BRANCH_STATE_HEADER: String = "_is_state_header_condition"
const BRANCH_OWNER_LABEL: String = "_owner_label"
const BRANCH_TRIGGER_SENTENCE: String = "_trigger_sentence"

## The branch written down when the generic assembly was reached and something after it still moved
## the words - the input-event humanising and the reading-sentence pass the two formatters wrap every
## base text in. Named apart from the owner lenses because it moves the WORDS rather than the object.
const BRANCH_POST_PASS: String = "_reading_sentence"


## One cell's reading, as the dump writes it and the census counts it.
##
## `origin` is the stable key a line sorts by (a descriptor's provider and id for the builtin
## population, a script path and the cell's ordinal in the walk for a sheet). `segments` are the
## cell's spans in order, each already spelled with its role and style marks. `path` and `branch` are
## the classification; `generic` and `actual` are the two assemblies the derivability question
## compares, and are empty for everything that is not an ACE cell.
class Reading extends RefCounted:
	var origin: String = ""
	var lane: String = ""
	var object_label: String = ""
	var segments: PackedStringArray = PackedStringArray()
	var path: int = Path.STRUCTURE
	var branch: String = ""
	## The base text the row builder actually produced, before the row decorations.
	var actual: String = ""
	## The base text the generic assembly would have produced for the same row.
	var generic: String = ""
	## The object word the generic assembly would have given the same row.
	var generic_object: String = ""
	## The object word the row builder's own formatter settled on, which is not always the word the
	## span carries (a badge span carries none). The derivability question compares this one.
	var actual_object: String = ""
	## The verb this cell is about, `<provider>::<ace_id>`, or "" when it is not an ACE cell.
	var ace_key: String = ""
	## True once the two assemblies below have both been built for this cell. A cell nothing weighed
	## is not a cell the generic assembly reproduces: without this flag two empty strings would
	## compare equal and every unmeasured cell would count as free.
	var measured: bool = false
	## The condition, action or row this cell is a reading of.
	var resource: Resource = null
	## The row resource the cell sits on - the event, group, comment or variable the canvas drew.
	## What a caller holding a row and wanting its readings looks the cell up by.
	var owner: Resource = null

	## True when the generic assembly reproduces this cell exactly - the same base text under the
	## same object word. For a cell the generic assembly already drew this is trivially true; for a
	## bespoke or grammar cell it is the measurement: the branch that shaped it said nothing the
	## descriptor did not already say.
	func is_derivable() -> bool:
		return measured and actual == generic and actual_object == generic_object

	## The path and its branch as the dump's last field spells it.
	func path_text() -> String:
		var name: String = PATH_NAMES[path]
		return name if branch.is_empty() else "%s:%s" % [name, branch]


## One reading as its line. Pure over its argument, so a test pins the format without a viewport.
static func line_for(reading: Reading) -> String:
	var fields: PackedStringArray = PackedStringArray([
		EventForgeRegistryDump.escape_field(reading.origin),
		EventForgeRegistryDump.escape_field(reading.lane),
		EventForgeRegistryDump.escape_field(reading.object_label),
		EventForgeRegistryDump.escape_field(SEGMENT_JOIN.join(reading.segments)),
		EventForgeRegistryDump.escape_field(reading.path_text()),
	])
	return SEPARATOR.join(fields)


## A whole population as one text: the header, then every reading's line, sorted. Sorted rather than
## written in walk order for the reason every gate text here is: a run on NTFS and a run on ext4 have
## to print the same bytes, and an origin key is what makes two lines the same line across a change.
static func text(readings: Array) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for entry: Variant in readings:
		lines.append(line_for(entry as Reading))
	lines.sort()
	var out: PackedStringArray = PackedStringArray([HEADER])
	out.append_array(lines)
	return "\n".join(out) + "\n"


## True when a text was written by this format version - the one thing a comparison checks before it
## reports anything, because a shape change would otherwise read as "every reading moved".
static func is_current_format(dump_text: String) -> bool:
	return dump_text.begins_with(HEADER)


# ── the population ──────────────────────────────────────────────────────────────


## A viewport wired the way the canvas wires one, holding `sheet`. The caller frees it.
##
## Reading mode is on because the dump is about what a row SAYS, not about the authoring chrome
## around it, and read-only because nothing here may write a byte back to a sheet.
static func viewport_for(sheet: EventSheetResource) -> EventSheetViewport:
	sheet.read_only = true
	if sheet.editor_style == null:
		var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
		style.ensure_defaults()
		sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	return viewport


## Every reading one sheet produces, in walk order, keyed by `origin_prefix`.
##
## TWO PASSES, and they may not be interleaved. The first builds every row's spans; the second asks
## the builder the classification questions, which run the formatters again and set the one-shot
## pending values those formatters hand to the next span made. Classifying inside the walk would
## therefore let one cell's leftovers land on the next cell's spans, which is the one way an
## instrument could change the thing it measures.
static func readings_of_sheet(sheet: EventSheetResource, origin_prefix: String) -> Array:
	var viewport: EventSheetViewport = viewport_for(sheet)
	var rows: Array = []
	_walk_rows(viewport, viewport._root_rows, rows)
	var readings: Array = []
	for row_data: Variant in rows:
		readings.append_array(_cells_of_row(row_data as EventRowData))
	for index: int in range(readings.size()):
		var reading: Reading = readings[index] as Reading
		reading.origin = "%s::%04d" % [origin_prefix, index]
	_classify_all(viewport._row_builder, readings)
	viewport.free()
	return readings


## Every row of the tree, parents before children, spans built.
static func _walk_rows(viewport: EventSheetViewport, rows: Array, out: Array) -> void:
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		out.append(row_data)
		_walk_rows(viewport, row_data.children, out)


## One row's cells: consecutive spans that share a lane and an ACE index are one cell, because that
## is what the builder makes of one condition or one action - a grammar reading is several spans of
## one cell, and splitting them would report one reading as four.
static func _cells_of_row(row_data: EventRowData) -> Array:
	var cells: Array = []
	var current: Reading = null
	var current_key: String = "?none"
	for span: SemanticSpan in row_data.spans:
		var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
		var lane: String = str(metadata.get("lane", ""))
		if lane.is_empty():
			lane = LANE_STRUCTURE
		var key: String = "%s#%s#%s" % [lane, str(metadata.get("ace_index", "-")),
			str(metadata.get("kind", ""))]
		if current == null or key != current_key:
			current = Reading.new()
			current.lane = lane
			current.object_label = str(metadata.get("object_label", ""))
			current.path = Path.STRUCTURE
			current.resource = _cell_resource(row_data, lane,
				str(metadata.get("kind", "")), int(metadata.get("ace_index", -1)))
			current.owner = row_data.source_resource
			cells.append(current)
			current_key = key
		current.segments.append(_segment_text(span, metadata))
	return cells


## The resource one cell is a reading OF: the condition, the action or the trigger the row holds at
## that lane and index. Null for every span of an event row that is not one of those - the badge
## column, the Else chip, the divider - because those are chrome and not a reading of a verb.
##
## A cell of a row that is not an event at all keeps the row's own resource, which is what makes a
## group head, a comment and a variable one STRUCTURE reading each rather than nothing.
static func _cell_resource(row_data: EventRowData, lane: String, kind: String,
		index: int) -> Resource:
	var event_row: EventRow = row_data.source_resource as EventRow
	if event_row == null:
		return row_data.source_resource
	if kind == "trigger":
		if event_row.trigger != null:
			return event_row.trigger
		return event_row if not event_row.trigger_id.is_empty() else null
	if index < 0:
		return null
	if lane == "action" and kind == "action":
		return event_row.actions[index] as Resource if index < event_row.actions.size() else null
	if lane == "condition" and kind == "condition":
		return event_row.conditions[index] as Resource if index < event_row.conditions.size() else null
	return null


## One span as the segments field spells it: its role, the style marks that change what a reader
## sees, and the text. The marks are the ones a refactor could drop without touching a word - a chip
## that stopped being a chip is a moved pixel and has to move a line here too.
static func _segment_text(span: SemanticSpan, metadata: Dictionary) -> String:
	var marks: PackedStringArray = PackedStringArray([_span_type_name(span.type)])
	if bool(metadata.get("chip", false)):
		marks.append("chip")
	var kind: String = str(metadata.get("kind", ""))
	if not kind.is_empty():
		marks.append("kind=%s" % kind)
	var badge: String = str(metadata.get("badge_style", ""))
	if not badge.is_empty():
		marks.append("badge=%s" % badge)
	if not span.hoverable:
		marks.append("flat")
	return "%s=%s" % ["+".join(marks), span.text]


## A span type as its own name, from the enum rather than from a list written down twice.
static func _span_type_name(span_type: int) -> String:
	for key: Variant in SemanticSpan.SpanType.keys():
		if int(SemanticSpan.SpanType[key]) == span_type:
			return str(key).to_lower()
	return str(span_type)


# ── the classification ──────────────────────────────────────────────────────────


## Classifies every reading of one sheet, after all of its spans are built.
static func _classify_all(builder: ViewportRowBuilder, readings: Array) -> void:
	for entry: Variant in readings:
		classify(builder, entry as Reading)


## Fills one reading's `path`, `branch` and the two assemblies the derivability question compares.
##
## Every answer is asked of the shipped builder. The order is the order the builder asks in: the
## grammar first (and the derived upgrade over it), then the named branches, then what is left, which
## is the generic assembly by definition.
static func classify(builder: ViewportRowBuilder, reading: Reading) -> void:
	var resource: Resource = reading.resource
	if resource is RawCodeRow:
		reading.path = Path.VERBATIM
		return
	if resource is ACEAction:
		_classify_action(builder, reading, resource as ACEAction)
		return
	if resource is ACECondition:
		_classify_condition(builder, reading, resource as ACECondition)
		return
	if resource is EventRow:
		# The trigger cell of an event that names its trigger by id rather than by a condition
		# resource: its words come from `_trigger_sentence`, which is a branch of its own. Measured
		# like every other cell - the sentence beside what the descriptor's own template would have
		# said - so a trigger cannot walk into the derivable figure unweighed.
		var event_row: EventRow = resource as EventRow
		reading.path = Path.BESPOKE
		reading.branch = BRANCH_TRIGGER_SENTENCE
		reading.ace_key = "%s::%s" % [event_row.trigger_provider_id, event_row.trigger_id]
		reading.generic = _generic_text(builder, event_row.trigger_provider_id,
			event_row.trigger_id, event_row.trigger_params)
		reading.generic_object = builder._object_label_for(event_row.trigger_provider_id,
			event_row.trigger_id)
		reading.actual = builder._trigger_sentence(event_row)
		reading.actual_object = reading.object_label
		reading.measured = true
		return
	reading.path = Path.STRUCTURE


## An action cell's path.
static func _classify_action(builder: ViewportRowBuilder, reading: Reading,
		action: ACEAction) -> void:
	reading.ace_key = "%s::%s" % [action.provider_id, action.ace_id]
	var params: Dictionary = action.params if not action.params.is_empty() else action.parameters
	reading.generic = _generic_text(builder, action.provider_id, action.ace_id, params)
	reading.generic_object = builder._object_label_for(action.provider_id, action.ace_id)
	reading.actual = builder._format_action_descriptor_base(action)
	reading.actual_object = _settled_object(builder, reading)
	reading.measured = true
	var grammar: Dictionary = builder.grammar_action_sentence(action)
	if not grammar.is_empty():
		_grammar_path(builder, reading, grammar, action.ace_id)
		return
	if builder._is_function_call_action(action):
		reading.path = Path.BESPOKE
		reading.branch = BRANCH_FUNCTION_CALL
		return
	_settled_path(builder, reading, action, params)


## A condition cell's path.
static func _classify_condition(builder: ViewportRowBuilder, reading: Reading,
		condition: ACECondition) -> void:
	reading.ace_key = "%s::%s" % [condition.provider_id, condition.ace_id]
	var params: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
	reading.generic = _generic_text(builder, condition.provider_id, condition.ace_id, params)
	reading.generic_object = builder._object_label_for(condition.provider_id, condition.ace_id)
	reading.actual = builder._format_condition_descriptor_base(condition)
	reading.actual_object = _settled_object(builder, reading)
	reading.measured = true
	var grammar: Dictionary = builder.grammar_condition_sentence(condition)
	if not grammar.is_empty():
		_grammar_path(builder, reading, grammar, condition.ace_id)
		return
	if builder._is_state_header_condition(condition):
		reading.path = Path.BESPOKE
		reading.branch = BRANCH_STATE_HEADER
		return
	_settled_path(builder, reading, condition, params)


## The grammar's own answer, and whether a derived reading rewrote it. Asked of the same upgrade the
## formatters run, so a cell the derived layer owns is never counted as the grammar's.
static func _grammar_path(builder: ViewportRowBuilder, reading: Reading, grammar: Dictionary,
		ace_id: String) -> void:
	var upgraded: Dictionary = builder._upgraded_by_derived_property(grammar, true)
	reading.path = Path.DERIVED if _joined(upgraded) != _joined(grammar) else Path.GRAMMAR
	reading.branch = ace_id if _grammar_arm_ids().has(ace_id) else BRANCH_PRE_MATCH


## What is left once the grammar and the two named predicates have declined: the registry-free
## fallbacks when the vocabulary has no descriptor at all, an owner lens that moved the object word,
## a post-pass that moved the words, or the generic assembly itself.
static func _settled_path(builder: ViewportRowBuilder, reading: Reading, ace: Resource,
		params: Dictionary) -> void:
	if not _has_descriptor(builder, ace):
		var stored: String = builder._stored_reading(ace, params)
		reading.path = Path.BESPOKE
		reading.branch = BRANCH_STORED if not stored.is_empty() else BRANCH_REFLECTED
		return
	if reading.actual_object != reading.generic_object:
		reading.path = Path.BESPOKE
		reading.branch = BRANCH_OWNER_LABEL
		return
	if reading.actual != reading.generic:
		reading.path = Path.BESPOKE
		reading.branch = BRANCH_POST_PASS
		return
	reading.path = Path.TEMPLATE


## The object word the formatter settled on, by the rule the object column itself uses: the pending
## word when the row's own shape named one, and the ordinary provider or node reading otherwise. An
## EMPTY pending word is not a different object - it is the generic one - so comparing the raw
## pending value against the generic reading would report every ordinary row as bespoke.
static func _settled_object(builder: ViewportRowBuilder, reading: Reading) -> String:
	var pending: String = builder._pending_object_label
	return pending if not pending.is_empty() else reading.generic_object


## True when the installed vocabulary still has something to draw this row from - the built
## definition the registry generated, or the static descriptor behind it.
static func _has_descriptor(builder: ViewportRowBuilder, ace: Resource) -> bool:
	var provider: String = str(ace.get("provider_id"))
	var ace_id: String = str(ace.get("ace_id"))
	if builder._viewport._find_definition(provider, ace_id) != null:
		return true
	return ACERegistry.find_descriptor(provider, ace_id) != null


## The generic assembly for one row: the descriptor's display template with the row's OWN values.
## The row's own values, never the lens-rewritten copy, because rewriting them is itself one of the
## branches the census is measuring.
static func _generic_text(builder: ViewportRowBuilder, provider: String, ace_id: String,
		params: Dictionary) -> String:
	var definition: ACEDefinition = builder._viewport._find_definition(provider, ace_id)
	var descriptor: ACEDescriptor = null
	if definition == null:
		descriptor = ACERegistry.find_descriptor(provider, ace_id)
	if definition == null and descriptor == null:
		return ""
	return builder._format_display_translated(definition, descriptor, params)


## A grammar result's words, for comparing one against another.
static func _joined(sentence: Dictionary) -> String:
	var text_out: String = ""
	for segment: Variant in (sentence.get("segments", []) as Array):
		text_out += str((segment as Dictionary).get("text", ""))
	return "%s ▸ %s" % [str(sentence.get("object", "")), text_out]


## Every `ace_id` the row builder's grammar routers name in an arm of their own, read out of the
## file itself rather than kept as a second list to maintain. A row whose id is not one of these
## reached the grammar through one of the hooks that run before the arm table, which is a different
## fact about it and is written down as one.
static func _grammar_arm_ids() -> Dictionary:
	if not _arm_ids.is_empty():
		return _arm_ids
	_arm_ids = {"": true}
	for arm: Dictionary in arms_of(BUILDER_PATH):
		for identifier: String in PackedStringArray(arm.get("ids", PackedStringArray())):
			_arm_ids[identifier] = true
	return _arm_ids

static var _arm_ids: Dictionary = {}

## The reading file whose `ace_id` arms the branch names come from.
const BUILDER_PATH: String = "res://addons/eventsheet/editor/interaction/viewport_row_builder.gd"

## The grammar file beside it, measured by the census for the same reason.
const GRAMMAR_PATH: String = "res://addons/eventsheet/editor/interaction/sentence_grammar.gd"


## Every `match <something>ace_id:` arm one file holds, as {"ids", "line", "lines"} - the verbs the
## arm heads with, the 1-based line the head is on, and how many lines the arm holds, its head
## included. That last is what deleting the arm would save, which is the only reason it is counted.
##
## This is the per-vocabulary special-casing at the grain a deletion would actually work at: an arm
## is a BLOCK a maintainer removes whole, and its line count is what removing it saves. Read out of
## the source text because there is no runtime seam that would say the same thing - a match arm is
## not an object - and read once per process because the source does not change under a run.
static func arms_of(script_path: String, only_ace_id: bool = true) -> Array:
	var cache_key: String = "%s#%s" % [script_path, str(only_ace_id)]
	if _arms_cache.has(cache_key):
		return _arms_cache[cache_key] as Array
	var walked: Array = arms_in(FileAccess.get_file_as_string(script_path), only_ace_id)
	_arms_cache[cache_key] = walked
	return walked

static var _arms_cache: Dictionary = {}


## The same walk over a buffer, so a test pins the parser without a file. Pure over its argument.
static func arms_in(source: String, only_ace_id: bool = true) -> Array:
	var found: Array = []
	var lines: PackedStringArray = source.split("\n")
	var arm_indent: int = -1
	var open_arm: Dictionary = {}
	for index: int in range(lines.size()):
		var line: String = lines[index]
		var body: String = line.strip_edges()
		if body.is_empty() or body.begins_with("#"):
			continue
		var indent: int = line.length() - line.lstrip("\t").length()
		if arm_indent >= 0 and indent < arm_indent and not open_arm.is_empty():
			open_arm["lines"] = index - int(open_arm.get("line", index)) + 1
			found.append(open_arm)
			open_arm = {}
			arm_indent = -1
		var dispatches: bool = body.begins_with("match ") and body.ends_with(":")
		if dispatches and (not only_ace_id or body.ends_with("ace_id:")):
			arm_indent = indent + 1
			continue
		if arm_indent < 0 or indent != arm_indent or not body.ends_with(":"):
			continue
		if not open_arm.is_empty():
			open_arm["lines"] = index - int(open_arm.get("line", index)) + 1
			found.append(open_arm)
		open_arm = {"ids": _arm_ids_of(body), "line": index + 1, "lines": 1}
	if not open_arm.is_empty():
		open_arm["lines"] = lines.size() - int(open_arm.get("line", lines.size())) + 1
		found.append(open_arm)
	if only_ace_id:
		return found
	# The broad walk keeps only the arms that dispatch on a NAME. A match on a number or an enum is
	# structure rather than vocabulary, and counting those here would inflate the one figure this
	# exists to measure.
	var named: Array = []
	for arm: Variant in found:
		if not PackedStringArray((arm as Dictionary).get("ids", PackedStringArray())).is_empty():
			named.append(arm)
	return named


## The quoted ids one arm heads with. An arm headed `_:` names none, which is the fall-through and is
## reported as an arm with no ids rather than dropped.
static func _arm_ids_of(head: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var body: String = head.trim_suffix(":")
	for piece: String in body.split(","):
		var token: String = piece.strip_edges()
		if token.length() >= 2 and token.begins_with("\"") and token.ends_with("\""):
			found.append(token.substr(1, token.length() - 2))
	return found


# ── the builtin population ──────────────────────────────────────────────────────


## How many descriptor rows go into one throwaway sheet. The head bands and the per-sweep caches are
## derived by walking the whole sheet, so one sheet of every verb there is would pay that walk once
## per row of it. Batching keeps the population linear without changing a single reading: a row's
## words do not depend on how many rows sit beside it.
const BUILTIN_BATCH: int = 128

## The host class the throwaway sheets declare. A plain Node, because the reading a verb gets must
## not depend on a host chosen for it here - and because that is what an empty sheet starts as.
const BUILTIN_HOST: String = "Node"

## The class name the throwaway sheets declare, so the object word a row takes from its own script is
## the same word in every batch.
const BUILTIN_CLASS: String = "ReadingDumpHost"


## Every builtin descriptor's reading, filled with its own defaults, in each lane it can hold a row
## in: an action in the action lane, a condition in the condition lane, a trigger as the trigger cell
## AND as the inline trigger condition a row without a trigger id reads it as. Expressions are not
## rows and are skipped, which is said out loud in the census rather than left as a silent gap.
##
## The origin key is the lane and the verb, so a line keeps its identity across a vocabulary that
## grows: adding a verb adds a line and moves none.
static func builtin_readings() -> Array:
	var descriptors: Array[ACEDescriptor] = EventForgeBuiltinACEs.get_descriptors()
	var sortable: PackedStringArray = PackedStringArray()
	var by_key: Dictionary = {}
	for descriptor: ACEDescriptor in descriptors:
		if descriptor.ace_type == ACEDescriptor.ACEType.EXPRESSION:
			continue
		var key: String = "%s::%s" % [descriptor.provider_id, descriptor.ace_id]
		if by_key.has(key):
			continue
		by_key[key] = descriptor
		sortable.append(key)
	sortable.sort()
	var readings: Array = []
	var batch: PackedStringArray = PackedStringArray()
	for key: String in sortable:
		batch.append(key)
		if batch.size() >= BUILTIN_BATCH:
			readings.append_array(_batch_readings(batch, by_key))
			batch = PackedStringArray()
	if not batch.is_empty():
		readings.append_array(_batch_readings(batch, by_key))
	return readings


## One batch of descriptors as readings, through a throwaway sheet built the way the canvas builds
## one. Only the cells that are a reading OF the batch's own verbs are kept: the badge column and the
## blank-tick words a conditionless event carries are the same on every row here and say nothing
## about the vocabulary.
static func _batch_readings(keys: PackedStringArray, by_key: Dictionary) -> Array:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = BUILTIN_CLASS
	sheet.host_class = BUILTIN_HOST
	var lanes: Dictionary = {}
	for key: String in keys:
		var descriptor: ACEDescriptor = by_key[key] as ACEDescriptor
		var row: EventRow = EventRow.new()
		if descriptor.ace_type == ACEDescriptor.ACEType.TRIGGER:
			row.trigger_provider_id = descriptor.provider_id
			row.trigger_id = descriptor.ace_id
		elif descriptor.ace_type == ACEDescriptor.ACEType.CONDITION:
			var condition: ACECondition = ACECondition.new()
			condition.provider_id = descriptor.provider_id
			condition.ace_id = descriptor.ace_id
			condition.params = default_params(descriptor)
			row.conditions.append(condition)
		else:
			var action: ACEAction = ACEAction.new()
			action.provider_id = descriptor.provider_id
			action.ace_id = descriptor.ace_id
			action.params = default_params(descriptor)
			row.actions.append(action)
		sheet.events.append(row)
		lanes[key] = true
	var viewport: EventSheetViewport = viewport_for(sheet)
	var rows: Array = []
	_walk_rows(viewport, viewport._root_rows, rows)
	var kept: Array = []
	for row_data: Variant in rows:
		for cell: Variant in _cells_of_row(row_data as EventRowData):
			kept.append(cell)
	_classify_all(viewport._row_builder, kept)
	var readings: Array = []
	var seen: Dictionary = {}
	for entry: Variant in kept:
		var reading: Reading = entry as Reading
		if not lanes.has(reading.ace_key):
			continue
		var origin: String = "builtin::%s::%s" % [reading.lane, reading.ace_key]
		var repeat: int = int(seen.get(origin, 0))
		seen[origin] = repeat + 1
		reading.origin = origin if repeat == 0 else "%s#%d" % [origin, repeat]
		readings.append(reading)
	viewport.free()
	return readings


## One descriptor's parameters filled with its OWN defaults - what a row carries the moment it is
## dropped, which is the population the compile gate walks and the only filling that is a fact about
## the descriptor rather than a value this tool made up.
static func default_params(descriptor: ACEDescriptor) -> Dictionary:
	var filled: Dictionary = {}
	for parameter: ACEParam in descriptor.params:
		var key: String = parameter.id if not parameter.id.is_empty() else parameter.name
		if key.is_empty():
			continue
		filled[key] = parameter.get_initial_value()
	return filled


## Every `.gd` under a folder, sorted. Sorted rather than walked-and-written, so the text is the same
## on NTFS (near-alphabetical) and on ext4 (hash order).
static func scripts_under(root: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var pending: PackedStringArray = PackedStringArray([root])
	while not pending.is_empty():
		var directory_path: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		var directory: DirAccess = DirAccess.open(directory_path)
		if directory == null:
			continue
		for name: String in directory.get_directories():
			if not name.begins_with("."):
				pending.append(directory_path.path_join(name))
		for file_name: String in directory.get_files():
			var name: String = file_name.trim_suffix(".remap")
			if name.ends_with(".gd"):
				found.append(directory_path.path_join(name))
	found.sort()
	return found


## Every reading of every sheet under the given folders, opened the way the editor opens a `.gd`.
## A file the importer cannot open as a sheet contributes nothing and is counted by the caller.
static func folder_readings(folders: PackedStringArray, unreadable: PackedStringArray) -> Array:
	var readings: Array = []
	for folder: String in folders:
		var root: String = folder if folder.ends_with("/") else folder + "/"
		for path: String in scripts_under(root):
			var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
			if sheet == null:
				unreadable.append(path)
				continue
			readings.append_array(readings_of_sheet(sheet, path))
	return readings
