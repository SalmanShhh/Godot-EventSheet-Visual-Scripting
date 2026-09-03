@tool
class_name ViewportRowBuilder
extends RefCounted
# The ROW-BUILDER layer: the "model → SemanticSpans" concern for the event sheet's virtualized
# viewport. Extracted from event_sheet_viewport.gd to keep that file maintainable. This subsystem
# owns HOW each row's SemanticSpans are built from the event / variable / group / comment model -
# the span-assembly pass (_build_event_spans + its line-count twin _count_event_lines), the per-ACE
# descriptor/format/classify helpers (_format_*_descriptor, _object_label_for, _is_trigger_condition,
# …), and the non-event row builders (_build_group_row / _build_comment_row / _build_variable_row / …).
# It reads the row model, styles, fonts, fold/disabled/breakpoint state, and the ACE registry through a
# back-reference to the viewport (`_viewport.`), and calls back into the viewport for the STAY concerns
# (the recursion dispatcher _build_row_from_resource, the element-style accessors, _find_definition).
#
# The LAYOUT (assigning span.rect / lane geometry) and the DRAWING stay on the viewport - this layer
# only produces the spans; the viewport's _get_or_build_row_layout positions them and the renderer
# paints them. Span construction must stay byte-identical to the pre-extraction code, so the bodies
# below were moved VERBATIM - only member access was rewritten to go through `_viewport.` (the span/
# descriptor logic itself is unchanged, including the `.merged(style_meta, false/true)` overwrite flags,
# the condition/action line-index accounting that _count_event_lines mirrors, and the same-object
# _ace_icon_cache / _value_regex caching).
#
# `_pending_display_bbcode` is PRIVATE to this layer: its writers (_format_condition_descriptor /
# _format_action_descriptor) set it on the line immediately before their _make_span call, and its sole
# reader (_make_span) consumes + clears it - all three live here, so the one-shot flag never needs to
# cross the viewport boundary on the real render path. (The viewport keeps a tiny same-named bridge var
# used ONLY by its _make_span delegate, so bbcode_and_pill_test - which pokes the flag then calls the
# delegate - needs no edit; the render path never touches that bridge.)
#
# `_value_ranges_for` + `_value_regex` are STATIC (pure text → ranges), so they stay unit-testable
# without a live viewport; the viewport keeps a static forwarder for any class-name caller.

## The alpha floor a published verb's header wash keeps in READING mode. Reading mode drops the
## "Action" / "Condition" / "Expression" word badge from the header (an event-sheet Function block
## carries its name and its inputs, nothing else), so the role tint becomes the ONLY kind cue and
## has to be visible even when the theme ships verb_row_tint_strength at 0.0 for the authoring look.
const VERB_KIND_TINT_ALPHA: float = 0.16

## The mark a call row wears when the function hands over to ITSELF. One constant, so the row,
## the hover help and the Manual's legend can never draw two different glyphs for the same fact.
const MARK_RECURSION := "↻"

## What an inverted condition wears in the badge column when there is no opposite operator to
## show instead. A word, because "not begins with" is the sentence, and one constant so the row, the
## text listing and the Manual can never teach two spellings of the same denial.
const NEGATED_MARK := "not"

## The marks a variable row wears, and the box they draw in. Both are 15px cues, never words:
## the outlined `x` says "this row declares something", the sliders mark says "and you can edit it in
## the Inspector". The width is fixed so the badge column stays a column at any font size.
const KIND_BADGE_WIDTH: float = 15.0
const INSPECTOR_BADGE_GLYPH := "⚙"

## The third mark a variable row can wear: this value is kept in step across the network. One
## glyph per mode, because the mark has to say WHICH mode without a word - the art behind each is a
## box with two bars in it, stroked solid, dotted or dashed.
const SYNC_BADGE_GLYPHS: Dictionary = {
	EventSheetSceneReplication.MODE_ALWAYS: "⚌",
	EventSheetSceneReplication.MODE_ON_CHANGE: "⚍",
	EventSheetSceneReplication.MODE_AT_SPAWN: "⚏",
}

## The head's band rows all share this uid prefix, so anything that has to find the head - the
## opened-pack reading, the fold guard, a test - asks one question instead of listing band kinds.
const HEAD_BAND_UID_PREFIX := "sheet_head_"

## The `@tool` band's switch, drawn as a mark in the badge column at the variable badge's width.
## A group head wears the same pair, because it is the same fact: this line is on, or it is not.
const HEAD_SWITCH_ON_GLYPH := "◍"
const HEAD_SWITCH_OFF_GLYPH := "◌"

## The marks a group head leads and ends with: the folder that says "this is structure" (the
## editor's own Folder texture draws over it when there is one), and the ring that says the group can
## be switched at runtime, which sits just before the switch it qualifies.
const GROUP_FOLDER_GLYPH := "▤"
const GROUP_TOGGLEABLE_GLYPH := "◎"

## How loud the echo of a line the file does NOT have yet is (an unticked `@tool`): quieter than a
## resting echo, so the band is findable without claiming the file says something it does not.
const HEAD_ECHO_GHOST_ALPHA: float = 0.3

## The closing fence is a TICK, not a row: its `#endregion` echo draws a size down and quieter
## than a resting echo, so "the region ends here" costs a sliver of canvas instead of a full row.
const REGION_CLOSER_FONT_DELTA: int = -2
const REGION_CLOSER_ECHO_ALPHA: float = 0.4

## The mark a DOCUMENTATION comment row leads with - the printer's paragraph sign, which is what the
## row is: a paragraph of the manual this sheet writes. A private note gets no mark, because the
## absence of one is the ordinary case.
const COMMENT_PARAGRAPH_GLYPH := "¶"

## How much of the comment ink a PRIVATE note keeps. It recedes rather than disappears: a note to
## yourself is still worth reading, it is just not the book.
const COMMENT_PRIVATE_ALPHA: float = 0.72

## How tall the closing tick is against an ordinary row, before the echo's own line height
## floors it. Slim enough to read as a rule with a label rather than as another row.
const REGION_CLOSER_HEIGHT_RATIO: float = 0.55

## The mark every note row leads with - the same warning glyph a line that would not lift wears,
## because every note means the same thing: look here, something about this row does not add up.
## The COLOUR is what separates a line that cannot work from one that only misbehaves.
const NOTE_MARK := "⚠"

## The families of finding the canvas reads about a row (the networking mistakes, the lighting ones,
## the dial a shader no longer declares). Names for the per-sweep cache below and the tag each
## stamped finding carries, never shown to anybody. EVERY family lives under the quiet sheet law: a
## finding puts its row into the quiet amber state and stops - no note row, no icon, no inline
## sentence - and the words live in the Doctor's inbox and in the help strip under the selected row,
## because a sheet is a place to read what the game does rather than a place to be told off in.
const FINDINGS_MULTIPLAYER := "multiplayer"
const FINDINGS_LIGHTING := "lighting"
const FINDINGS_EFFECTS := "effects"
const FINDINGS_PERFORMANCE := "performance"
const FINDINGS_SPAWNING := "spawning"
const FINDINGS_COLLISIONS := "collisions"
const FINDINGS_LAYERS := "layers"
const FINDINGS_SCENE_TRUST := "scene_trust"
const FINDINGS_TOOL_EDITS := "tool_edits"
const FINDINGS_MIGRATION := "migration"
const FINDINGS_RENAME := "rename"

var _viewport: Control = null
# The published verb whose body is being walked right now, or null at sheet level. Rows inside a
# CONDITION or EXPRESSION verb read their `return` as "Set return value to x" rather than "Stop event",
# and only the walk knows which verb owns the rows it is building.
var _current_verb_function: EventFunction = null
# The verb kind a lazily-built row carries with it, or -1 when the walk itself is the authority.
var _verb_kind_override: int = -1
# How many undo-step edits the walk is inside right now. A `return` in there is the ANSWER the
# funnel asked for ("did this change anything?"), never the "stop the event" a plain body's is.
var _answer_return_rows: int = 0
# The menu whose handler the walk is inside right now, "" at sheet level. A `match id:` arm says
# only a number; which MENU that number belongs to is a fact about the walk (the lambda it was handed
# to, or the function the connect line named), so it is stamped here exactly as the verb kind is.
var _current_menu_key: String = ""
# Per-build occurrence counters ("label" -> count) giving every paired region a STABLE
# fold key ("label#n") that survives sessions - row uids are instance-based and cannot
# (the persisted-folds layer keys on these instead). Reset by _pair_region_fences.
var _region_occurrences: Dictionary = {}
# The code echo's token colours for THIS sweep. Cleared with the other per-build caches, so a
# theme or Editor Settings change is picked up on the next rebuild and never mid-build.
var _code_echo_palette: Dictionary = {}
# What the removal guard knows about THIS sheet's names, for the guard line a removal row echoes.
# Derived once per sweep for the same reason the caches around it are: it walks every row of the
# sheet, and every removal row on the canvas wants one answer out of it.
var _removal_guard_facts: Dictionary = {}
# The `## @ace_group(...)` line the compiler writes for each group, {EventGroup: String}, asked
# of the compiler ONCE per sweep: the walk that slugs them is a whole-tree walk, and every head on
# the canvas wants one line out of it.
var _group_declaration_lines: Dictionary = {}
# The orphan-fence notes built in THIS sweep, so the fix label can be numbered once the flat
# list has its gutter numbers. Empty on every sheet whose fences all pair, which is nearly all.
var _region_fix_notes: Array[EventRowData] = []

## The mark on the chip that names a pattern. Its own glyph, so a reader learns "⟡ means this
## event is a known shape" once and then recognises it everywhere, the way ⟳ ➜ ƒ already work.
const PATTERN_CHIP_MARK := "⟡"

# Compiled once and shared: both of these run per row (or per action) on the paint path.
static var _await_loop_regex: RegEx = null
static var _super_call_regex: RegEx = null

# The rest of this file's matchers, likewise compiled once. Every one of these used to be built
# fresh inside the function that used it, and those functions run per row, per line, or per word of
# a rebuild - compiling the pattern was costing far more than matching it. Shared statics are safe
# here: a RegEx is read-only once compiled, and the row build runs on the main thread.
static var _word_regex: RegEx = null
static var _identifier_regex: RegEx = null
static var _host_bind_regex: RegEx = null
static var _func_header_regex: RegEx = null
static var _class_header_regex: RegEx = null
static var _class_extends_regex: RegEx = null
static var _class_var_default_regex: RegEx = null
static var _class_var_bare_regex: RegEx = null
static var _method_header_regex: RegEx = null
static var _timer_wait_regex: RegEx = null
static var _timer_one_shot_regex: RegEx = null
static var _event_cast_regex: RegEx = null

# Per-build occurrence counters for class-block row uids ("Stats" -> count). Class rows key
# their uids by class NAME (stable across the undo funnel's resource rebuild, so expand /
# disabled state survives edits) - but two blocks sharing a name then shared ONE uid, so
# selecting/toggling one silently mirrored onto the other. The counter suffixes repeats
# ("-2", "-3"); build order is stable, so a repeat maps to the same block next rebuild.
# Reset by the viewport at the top of every _build_rows_from_sheet sweep.
var _class_uid_counts: Dictionary = {}

# The sheet's variables and who owns each, keyed "entries" so an empty sheet still counts as
# derived. Asked once per condition and once per action, and answering it reads the autoloads'
# scripts off disk - so it is derived once per sweep and cleared beside the palette above.
var _variable_owner_catalog: Dictionary = {}

# The mistakes this sheet earns, by family, so a sheet with none still counts as derived.
# Asked once per event, once per variable and once per function, and answering one walks the whole
# sheet and the attached scene - so each is derived once per sweep and cleared beside the catalog
# above.
var _sheet_findings_cache: Dictionary = {}


## The uid scope for one class block: the class name for the first occurrence (uids unchanged
## for the common case), "-N"-suffixed for same-named repeats, instance-id fallback when the
## block has no name at all.
func _unique_class_scope(class_name_str: String, raw_row: RawCodeRow) -> String:
	var base: String = class_name_str if not class_name_str.is_empty() else str(raw_row.get_instance_id())
	var count: int = int(_class_uid_counts.get(base, 0)) + 1
	_class_uid_counts[base] = count
	return base if count == 1 else "%s-%d" % [base, count]


func init(viewport: Control) -> void:
	_viewport = viewport


# ── Region fence pairing (view layer only) ─────────────────────────────────────────────────────


## Pairs #region / #endregion fence rows into foldable ranges - VIEW LAYER ONLY.
## The sheet still stores flat fence rows (emission and the byte round-trip are
## untouched by construction); the rows between a matched pair become the opener's
## visual children, so the existing fold machinery (children + folded + the
## viewport's _flatten_row skip) collapses them for free. Stack-based, so regions
## nest inside regions and inside groups. Unbalanced fences never pair and stay
## flat rows - the region block kind's wart-not-error contract holds in the view.
func _pair_region_fences(rows: Array[EventRowData]) -> Array[EventRowData]:
	_region_occurrences.clear()
	_region_fix_notes.clear()
	return _pair_region_fences_walk(rows)


func _pair_region_fences_walk(rows: Array[EventRowData]) -> Array[EventRowData]:
	var output: Array[EventRowData] = []
	var stack: Array[Dictionary] = []
	for row_data: EventRowData in rows:
		# Pair inside pre-built child lists first (groups); a region row's own
		# children were assembled by an inner frame below, never re-walked.
		if not row_data.children.is_empty() and not _is_region_row(row_data):
			row_data.children = _pair_region_fences_walk(row_data.children)
		if _is_region_row(row_data) and not _region_row_is_end(row_data):
			stack.append({"opener": row_data, "collected": [] as Array[EventRowData]})
			continue
		if _is_region_row(row_data) and _region_row_is_end(row_data):
			if stack.is_empty():
				# A closer with nothing above it closes nothing. The file still compiles, so
				# the row stays flat and the note under it is amber, never red.
				_append_to_sink(output, stack, row_data)
				_append_to_sink(output, stack, _build_region_orphan_note_row(
					row_data, EventSheetRegionFacts.unopened_note(), ""
				))
				continue
			var frame: Dictionary = stack.pop_back()
			var opener: EventRowData = frame.get("opener")
			var collected: Array[EventRowData] = frame.get("collected")
			var region_children: Array[EventRowData] = []
			for collected_row: EventRowData in collected:
				_bump_indent(collected_row, 1)
				region_children.append(collected_row)
			# The closing fence rides as the LAST child: hidden while folded, still a real
			# selectable row (its CustomBlockRow is untouched) when open. Its only text is the
			# `#endregion` the file has - the tick that says the region ends here.
			_bump_indent(row_data, 1)
			region_children.append(row_data)
			opener.children = region_children
			# Session fold state (row-uid keyed) wins; the persisted layer (stable
			# label#occurrence keys) seeds the default so folds survive reopen.
			var opener_label: String = EventSheetRegionFacts.label(opener.source_resource)
			var occurrence: int = int(_region_occurrences.get(opener_label, 0))
			_region_occurrences[opener_label] = occurrence + 1
			var fold_key: String = "%s#%d" % [opener_label, occurrence]
			opener.set_meta("region_fold_key", fold_key)
			opener.folded = bool(_viewport._fold_state.get(opener.row_uid, bool(_viewport.persisted_region_folds.get(fold_key, false))))
			# Folded, the opener says how much it holds and echoes both fences, exactly the way
			# a script editor draws a folded region on one line. Re-dressed rather than appended to,
			# so open and folded are one description of the row instead of two.
			_apply_region_opener_spans(opener, _region_member_count_text(region_children))
			_append_to_sink(output, stack, opener)
			continue
		_append_to_sink(output, stack, row_data)
	# Unclosed openers unwind flat, in document order: the opener row, then
	# everything it had collected, exactly as they read in the source.
	for frame: Dictionary in stack:
		var unclosed: EventRowData = frame.get("opener")
		# The rule on a fence that never closes turns amber, so the wart is visible at a glance and
		# the note under it is the explanation rather than the only signal.
		unclosed.custom_color = _viewport._get_reading_style().lift_note_badge_foreground_color
		output.append(unclosed)
		# The note rides directly under the fence it is about, with the fix beside it. The
		# label names the row the closer would land after, which only the numbering pass knows, so
		# the note is recorded here and the number filled in once the rows have theirs.
		output.append(_build_region_orphan_note_row(
			unclosed,
			EventSheetRegionFacts.unclosed_note(unclosed.source_resource),
			_region_close_after_uid(frame.get("collected"))
		))
		output.append_array(frame.get("collected"))
	return output


func _append_to_sink(output: Array[EventRowData], stack: Array[Dictionary], row_data: EventRowData) -> void:
	if stack.is_empty():
		output.append(row_data)
	else:
		(stack[stack.size() - 1].get("collected") as Array[EventRowData]).append(row_data)


## The muted count a FOLDED region wears: how many EVENTS it holds when it holds any (the word
## structure is read for), else how many rows. The closing fence rides as the last child and is
## plumbing, so it is never counted.
func _region_member_count_text(region_children: Array[EventRowData]) -> String:
	var events: int = 0
	var rows: int = 0
	for index: int in range(maxi(region_children.size() - 1, 0)):
		rows += 1
		if region_children[index].row_type == EventRowData.RowType.EVENT:
			events += 1
	if events > 0:
		return EventSheetL10n.translate("%d event") % events if events == 1 \
			else EventSheetL10n.translate("%d events") % events
	return EventSheetL10n.translate("%d row") % rows if rows == 1 \
		else EventSheetL10n.translate("%d rows") % rows


# ── a region's own look ────────────────────────────────────────────────────────────────────────


## The fold mark, in the shape the script editor draws it: a dashed `#` box in the badge
## column, the name in the row's own ink, the description muted beside it, and the fence line
## echoed at the right edge. No folder, no chapter-bar height, no "end region" prose - a region is
## two lines of the file, and the row says exactly those two lines.
func _dress_region_fence_row(row_data: EventRowData, block: CustomBlockRow) -> void:
	row_data.row_type = EventRowData.RowType.REGION
	# The accent travels on the row so the renderer's wash, the dashed badge and the dashed rule
	# down the body all read the region's own colour without parsing its field three times.
	row_data.custom_color = _region_accent(block)
	if EventSheetRegionFacts.is_closing_fence(block):
		row_data.spans = [_code_echo_span(
			EventSheetRegionFacts.CLOSING_LINE,
			{
				"kind": "custom_block_row",
				"region_fence": "close",
				"font_size_delta": REGION_CLOSER_FONT_DELTA,
				"hover_note": EventSheetL10n.translate("Where this region ends.")
			},
			REGION_CLOSER_ECHO_ALPHA,
			false
		)]
		return
	_apply_region_opener_spans(row_data, "")


## The opening fence's spans, built from what the row knows right now. Called once while the row is
## made (open, no count yet) and again by the pairing pass once the fold state and the member count
## are known - one description of the row, never a second one bolted on.
func _apply_region_opener_spans(row_data: EventRowData, count_text: String) -> void:
	var block: CustomBlockRow = row_data.source_resource as CustomBlockRow
	if block == null:
		return
	var reading_style: EventSheetReadingStyle = _viewport._get_reading_style()
	var accent: Color = _region_accent(block)
	var spans: Array[SemanticSpan] = [_make_span(
		EventSheetRegionFacts.FENCE_GLYPH,
		SemanticSpan.SpanType.KEYWORD,
		{
			"kind": "custom_block_row",
			"region_badge": true,
			"badge": true,
			"badge_style": "outline",
			"badge_dashed": true,
			"badge_natural_width": true,
			"badge_fixed_width": KIND_BADGE_WIDTH,
			"line_index": 0,
			"badge_bg": accent,
			"badge_fg": accent
		}
	)]
	var words: Dictionary = _fold_mark_words(block, row_data.folded, count_text)
	var title: String = str(words["title"])
	spans.append(_make_span(
		title,
		SemanticSpan.SpanType.OBJECT,
		{
			"kind": "custom_block_row",
			"region_title": true,
			"editable": true,
			"edit_kind": "region_name",
			"line_index": 0,
			"text_color": reading_style.primary_text_color,
			"bbcode_segments": [{
				"text": title,
				"color": reading_style.primary_text_color,
				"bold": true,
				"italic": false
			}]
		}
	))
	# Open, the row carries the author's own description; folded, what it holds - the one thing
	# worth knowing before deciding whether to open it.
	var note: String = str(words["note"])
	if not note.is_empty():
		spans.append(_make_span(note, SemanticSpan.SpanType.COMMENT, {
			"kind": "custom_block_row",
			"region_note": true,
			"line_index": 0,
			"text_color": reading_style.muted_text_color
		}))
	spans.append(_code_echo_span(
		str(words["echo"]),
		{
			"kind": "custom_block_row",
			"region_fence": "open",
			"hover_note": EventSheetL10n.translate("The line this row writes. Click to open it in the code panel.")
		},
		EventSheetCodeEcho.REST_ALPHA,
		true
	))
	row_data.spans = spans
	row_data.line_count = 1


## The three things a fold-mark row says: the name it leads with, the muted line beside it, and the
## line of the file it echoes. The built-in fences answer from EventSheetRegionFacts - a label
## field, a description field, the fence line. ANY OTHER KIND that asked for this look through
## `row_style()` answers from the Custom Block API it already implements: its summary is the title
## and the last line it emits is the echo, so the fold-mark shape is reusable rather than region-
## only, and one place decides which of the two readings a row gets.
func _fold_mark_words(block: CustomBlockRow, folded: bool, count_text: String) -> Dictionary:
	if EventSheetRegionFacts.is_fence(block):
		return {
			"title": EventSheetRegionFacts.display_name(block),
			"note": count_text if folded else EventSheetRegionFacts.description(block),
			"echo": EventSheetRegionFacts.folded_echo(block) if folded else EventSheetRegionFacts.fence_line(block)
		}
	var kind: EventSheetBlockKind = EventSheetBlockRegistry.get_kind(block.kind_id)
	var emitted: PackedStringArray = kind.emit_lines(block) if kind != null else PackedStringArray()
	return {
		"title": kind.summary(block) if kind != null else block.kind_id,
		"note": count_text if folded else "",
		"echo": emitted[emitted.size() - 1] if not emitted.is_empty() else ""
	}


## The region's own colour; failing that the kind's own tint, and failing that the theme's behaviour
## accent. A kind that asked for this look tints its badge through `style()`, the very hook that
## tints a flat block row's - one answer about a kind's colour, whichever shape its rows take.
func _region_accent(block: CustomBlockRow) -> Color:
	var stored: String = EventSheetRegionFacts.accent_hex(block)
	if not stored.is_empty():
		return Color.html(stored)
	var kind: EventSheetBlockKind = EventSheetBlockRegistry.get_kind(block.kind_id)
	var styled: Dictionary = kind.style(block) if kind != null else {}
	return styled.get("accent", _viewport._get_event_style().behavior_accent_color)


# ── a fence with no partner ────────────────────────────────────────────────────────────────────


## The amber note under an unmatched fence: the problem in a sentence, and (for an opener) the
## fix that writes the missing `#endregion` after the last row before the next head. Amber, never
## red: an unbalanced fence is a readability wart and the file still compiles.
func _build_region_orphan_note_row(fence_row: EventRowData, message: String, close_after_uid: String) -> EventRowData:
	var note_row: EventRowData = _build_note_row(
		"region_orphan_%s" % str(fence_row.source_resource.get_instance_id()),
		fence_row.indent, "region_orphan", message,
		_viewport._get_reading_style().lift_note_badge_foreground_color, {},
		# The label is written once the rows are numbered - the number it names does not exist yet.
		{} if close_after_uid.is_empty() else {"label": "", "meta": {
			"region_fix": close_after_uid,
			"hover_note": EventSheetL10n.translate("Writes the missing #endregion there.")
		}})
	if not close_after_uid.is_empty():
		_region_fix_notes.append(note_row)
	return note_row


## THE note row, wherever the canvas grows one: the warning mark, the sentence, and - when there is
## an answer to offer - the fix at the right edge. Inert (no source_resource), so Delete and drag
## cannot reach a row through it.
##
## `kind` names the note's metadata family ("region_orphan", "variable_note"); every span carries it
## under "kind" and again as the key whose value says WHICH span this is ("mark" / "message" /
## "fix"), which is what the input dispatch and the tests address a note's parts by. `shared_meta`
## rides on all three spans (a fix that needs to know what it is fixing), `fix` is
## {"label", "meta"} or {} for a note with nothing to offer, and `ink` is the whole difference
## between red (this line cannot work) and amber (it compiles and only misbehaves).
func _build_note_row(row_uid: String, indent: int, kind: String, message: String, ink: Color,
		shared_meta: Dictionary, fix: Dictionary) -> EventRowData:
	var reading_style: EventSheetReadingStyle = _viewport._get_reading_style()
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = null
	row_data.row_uid = row_uid
	var base_meta: Dictionary = shared_meta.duplicate()
	base_meta["kind"] = kind
	base_meta["editable"] = false
	base_meta["line_index"] = 0
	row_data.spans = [
		_make_span(NOTE_MARK, SemanticSpan.SpanType.KEYWORD, base_meta.merged({
			"badge": true,
			"badge_style": "scope",
			kind: "mark",
			"badge_bg": reading_style.lift_note_badge_background_color,
			"badge_fg": ink
		}, true)),
		_make_span(message, SemanticSpan.SpanType.COMMENT, base_meta.merged({
			kind: "message", "text_color": ink
		}, true))
	]
	if fix.is_empty():
		return row_data
	var fix_meta: Dictionary = base_meta.merged(fix.get("meta", {}) as Dictionary, true)
	row_data.spans.append(_make_span(str(fix.get("label", "")), SemanticSpan.SpanType.VALUE,
		fix_meta.merged({
			kind: "fix",
			"align_right": true,
			"text_color": reading_style.primary_text_color
		}, true)))
	return row_data


## Which row the missing `#endregion` would land after: the last row before the next structural
## head (a group, or another fence) or the end of what the opener swallowed. "" when it swallowed
## nothing, in which case there is no row to close after and the note carries no fix.
func _region_close_after_uid(collected: Array[EventRowData]) -> String:
	var last_uid: String = ""
	for row_data: EventRowData in collected:
		if row_data.row_type == EventRowData.RowType.GROUP or _is_region_row(row_data):
			break
		last_uid = row_data.row_uid
	return last_uid


## Every note that names a GUTTER NUMBER, filled in once the flat list has been numbered - which is
## the only moment those numbers exist. The viewport calls this one function so a future note of the
## same shape has a place to go instead of a second call site to remember.
func apply_numbered_labels(numbered_rows: Array) -> void:
	apply_region_fix_labels(numbered_rows)
	apply_else_follows_labels(numbered_rows)


## The Else row says what it is the else OF: "neither of 9", the gutter number of the event its
## chain starts at. Idempotent - a fold re-flattens and re-numbers without rebuilding spans, so this
## runs again over the same rows and must only ever write the span that IS the note.
func apply_else_follows_labels(numbered_rows: Array) -> void:
	for index: int in range(numbered_rows.size()):
		var row_data: EventRowData = (numbered_rows[index] as Dictionary).get("row")
		if row_data == null or not (row_data.source_resource is EventRow):
			continue
		if (row_data.source_resource as EventRow).else_mode != EventRow.ElseMode.ELSE:
			continue
		for span: SemanticSpan in row_data.spans:
			if span.metadata is Dictionary and bool((span.metadata as Dictionary).get("else_follows", false)):
				span.text = else_follows_text(numbered_rows, index, row_data.indent)
				break


## The words an Else row's note carries, or "" when the event it follows is not on the canvas. The
## search walks BACKWARDS at the Else's own indent: a deeper row is inside the block above it, a
## shallower one means the block has been left, and the first sibling event that starts a chain
## (else_mode NONE) is the `if` this Else answers. Static and pure over the numbered rows.
static func else_follows_text(numbered_rows: Array, else_index: int, indent: int) -> String:
	for scan: int in range(else_index - 1, -1, -1):
		var row_data: EventRowData = (numbered_rows[scan] as Dictionary).get("row")
		if row_data == null or row_data.indent > indent:
			continue
		if row_data.indent < indent:
			return ""
		if not (row_data.source_resource is EventRow):
			continue
		if (row_data.source_resource as EventRow).else_mode != EventRow.ElseMode.NONE:
			continue
		if row_data.event_number <= 0:
			return ""
		return EventSheetL10n.translate("neither of {n}").replace("{n}", str(row_data.event_number))
	return ""


## The fix names the row it writes the fence after, and the number it names is the one in the
## gutter, which exists only once the flat list is numbered. Does nothing at all on a sheet with no
## unmatched fence - which is every healthy sheet.
func apply_region_fix_labels(numbered_rows: Array) -> void:
	if _region_fix_notes.is_empty():
		return
	var numbers: Dictionary = {}
	for entry: Variant in numbered_rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data != null:
			numbers[row_data.row_uid] = row_data.line_number
	for note_row: EventRowData in _region_fix_notes:
		if note_row.spans.is_empty():
			continue
		var fix_span: SemanticSpan = note_row.spans[note_row.spans.size() - 1]
		var fix_meta: Dictionary = fix_span.metadata if fix_span.metadata is Dictionary else {}
		# A re-flatten (a fold toggle) numbers the rows again without rebuilding them, so this can
		# run twice over the same note: only ever touch the span that IS the fix.
		if not fix_meta.has("region_fix"):
			continue
		var after_row: int = int(numbers.get(str(fix_meta["region_fix"]), 0))
		if after_row <= 0:
			# The row the fence would follow is not on the canvas (it is folded away inside
			# something): offer no button rather than one naming a row nobody can see.
			note_row.spans.remove_at(note_row.spans.size() - 1)
			continue
		fix_span.text = EventSheetRegionFacts.close_after_label(after_row)


func _is_region_row(row_data: EventRowData) -> bool:
	return row_data != null and row_data.source_resource is CustomBlockRow \
		and (row_data.source_resource as CustomBlockRow).kind_id == "region"


func _region_row_is_end(row_data: EventRowData) -> bool:
	return bool(((row_data.source_resource as CustomBlockRow).fields as Dictionary).get("is_end", false))


func _bump_indent(row_data: EventRowData, delta: int) -> void:
	row_data.indent += delta
	for child: EventRowData in row_data.children:
		_bump_indent(child, delta)

# ── Non-event row builders ──────────────────────────────────────────────────────────────────────


## The sheet's HEAD: one band per line of the file, in reading order, always visible.
##
## The leading run of class scaffolding an opened `.gd` carries (`class_name`, `extends`, `@icon`,
## `@tool`, the `##` description, a behaviour's host binding) used to fold into ONE crumb-trail
## strip - `▣ Node ▸ CharacterBody2D ▸ Player` - hidden by default, with the rest of the facts in a
## label/value dropdown behind it. It is now a STACK: one row per line, each with one fact, one
## control and one code echo, and nothing folds. A long head means a long file, which is information
## too.
##
## The band model is `EventSheetHeadBands` (pure + static); this only dresses it as rows. Diagnostics
## survive: a prelude block carrying a compile-error marker is appended after the stack as its own
## row rather than being swallowed, because problems are never hidden.
func build_head_band_rows(sheet: EventSheetResource, scaffold_rows: Array[EventRowData]) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	if sheet == null:
		return rows
	var prelude_lines: PackedStringArray = PackedStringArray()
	var description_source: Resource = null
	for child: EventRowData in scaffold_rows:
		if not (child.source_resource is RawCodeRow):
			continue
		var code: String = (child.source_resource as RawCodeRow).code
		prelude_lines.append(code)
		if description_source == null and _carries_class_description(code):
			description_source = child.source_resource
	var head_facts: Dictionary = EventSheetHeadBands.facts(sheet, "\n".join(prelude_lines))
	# "attach to a node" is a prompt, and a read-only preview asks nothing of the reader - it has no
	# gestures at all - so a previewed file is never told it is unattached.
	head_facts["attached"] = sheet.read_only \
		or _sheet_is_attached(sheet, str(head_facts.get("class_name", "")))
	# The half of the head that comes from the SCENE: what keeps this object in step, and which
	# spawner can make it. Read, never stored, so a project with no scenes gains no bands at all.
	head_facts.merge(EventSheetHeadBands.scene_facts(sheet), true)
	# And the two facts the head reads out of the ROWS rather than out of the file or the scene: how
	# many of them are written in a spelling the vocabulary has since replaced, and how many hold a
	# verb it no longer has at all. Counted here, said as one line, and said NOWHERE else - the rows
	# themselves stay exactly as they look, wearing at most the quiet amber state.
	head_facts["migration"] = EventForgeVocabularyRecord.band_facts(
		_rows_with_a_newer_spelling(sheet),
		EventSheetMigrationFindings.events_asking(_sheet_findings(FINDINGS_MIGRATION)))
	for band: Dictionary in EventSheetHeadBands.bands(head_facts):
		rows.append(_build_head_band_row(sheet, band, head_facts, description_source))
	var add_text: String = EventSheetHeadBands.add_row_text(head_facts)
	if not add_text.is_empty() and not sheet.read_only:
		rows.append(_build_head_add_row(sheet, add_text))
	for child: EventRowData in scaffold_rows:
		if not child.error_message.strip_edges().is_empty():
			child.indent = 0
			rows.append(child)
	return rows


## One band: the leader word of its line, the fact, its control, and the line itself echoed at the
## right edge. The name band leads with the class icon and a little more presence; the rest are slim.
func _build_head_band_row(sheet: EventSheetResource, band: Dictionary, head_facts: Dictionary,
		description_source: Resource) -> EventRowData:
	var kind: String = str(band["kind"])
	# A band about something outside this file names it after a colon, so one gesture carries
	# both which band was clicked and which node it was about (the way an edit kind does).
	var reference: String = str(band.get("reference", ""))
	var band_action: String = kind if reference.is_empty() else "%s:%s" % [kind, reference]
	var reading_style: EventSheetReadingStyle = _viewport._get_reading_style()
	var row_data := EventRowData.new()
	row_data.indent = 0
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = null
	row_data.row_uid = "%s%s%s_%d" % [HEAD_BAND_UID_PREFIX, kind, reference, sheet.get_instance_id()]
	row_data.folded = false
	var accent: Color = _viewport._get_event_style().behavior_accent_color
	var is_name_band: bool = kind == EventSheetHeadBands.BAND_NAME
	row_data.custom_color = Color(accent.r, accent.g, accent.b, 0.22 if is_name_band else 0.10)
	row_data.height_scale = 1.35 if is_name_band else 1.0
	var band_meta: Dictionary = {
		"editable": false,
		"kind": "head_band_%s" % kind,
		"head_band": kind,
		"line_index": 0
	}
	var spans: Array[SemanticSpan] = []
	if is_name_band:
		# The editor's own icon for the class this sheet extends - the same texture the Add Node
		# dialog draws.
		var extends_target: String = str(head_facts.get("extends", "")).strip_edges()
		spans.append(_head_band_icon_span(band_meta, EventSheetHeadBands.BAND_NAME,
			ACEPickerDialog.editor_icon(extends_target) if not extends_target.is_empty() else null,
			EventSheetL10n.translate("F2 renames this class everywhere.")))
	elif kind == EventSheetHeadBands.BAND_ICON:
		# The image the `@icon` annotation names, drawn at badge size: the picture and the way to
		# change it are the same thing.
		var icon_path: String = str(band["value"])
		spans.append(_head_band_icon_span(band_meta, EventSheetHeadBands.BAND_ICON,
			load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null,
			EventSheetL10n.translate("The class icon. Click to pick another image.")))
	elif band.get("switch", false):
		spans.append(_head_band_switch_span(band_meta, bool(band["switch_on"])))
	var leader: String = str(band["leader"])
	if not leader.is_empty():
		spans.append(_make_span(leader, SemanticSpan.SpanType.KEYWORD, band_meta.merged({
			"text_color": reading_style.muted_text_color
		}, true)))
	var value_text: String = str(band["value"])
	if not value_text.is_empty():
		# A band whose fact is a problem says so in the note colour, which is the colour the
		# same finding wears everywhere else on the canvas. Nothing else about the band changes:
		# it is still one fact, read from the scene, with the node it is about one click away.
		var value_colour: Color = reading_style.muted_text_color if bool(band["value_muted"]) \
			else reading_style.primary_text_color
		if bool(band.get("warning", false)):
			value_colour = reading_style.lift_note_badge_foreground_color
		var value_meta: Dictionary = band_meta.merged({"text_color": value_colour}, true)
		if is_name_band and not sheet.read_only:
			# The name IS the rename control: F2 or a double-click renames the class everywhere.
			value_meta["head_action"] = EventSheetHeadBands.BAND_NAME
			value_meta["hover_note"] = EventSheetL10n.translate("F2 renames this class everywhere.")
		if kind == EventSheetHeadBands.BAND_STATES:
			# The band gains a live half while a game runs, so it says here how often that half is
			# true. Stated on the band itself, because the number ticking in front of a reader is
			# where "how fresh is this" gets asked.
			value_meta["hover_note"] = EventSheetStateWatch.cadence_note()
		if bool(band["editable"]) and description_source is RawCodeRow and not sheet.read_only:
			# The `##` block edits in place, and the raw row it lives in travels in metadata so
			# the write goes through the byte-gated lift rather than through a second store.
			value_meta["editable"] = true
			value_meta["edit_kind"] = "sheet_description"
			value_meta["head_raw_row"] = description_source
			value_meta["hover_note"] = EventSheetL10n.translate("Writes the ## block · Enter commits.")
		spans.append(_make_span(value_text, SemanticSpan.SpanType.VALUE, value_meta))
	# The band's own words that ACT: the prompt a half-made sheet answers ("name it") and the control
	# that opens the gesture ("change…"). Both are the band's action, so both read the same way.
	for word: String in [str(band["prompt"]), str(band["control"])]:
		if word.is_empty() or sheet.read_only:
			continue
		spans.append(_make_span(word, SemanticSpan.SpanType.COMMENT, band_meta.merged({
			"head_action": band_action,
			"text_color": _viewport._get_event_style().behavior_accent_color
		}, true)))
	if is_name_band:
		# What this file is as a piece of TOOLING, and the buttons that run it: a test sheet and how
		# many checks it makes, a command tool that runs headless, a pack recipe and the behavior it
		# builds, Run now / Reload / Output for an editor script. Not lines of the file, so not bands
		# of their own - they ride the leading band, which is the sheet's identity bar.
		spans.append_array(_tool_file_chip_spans(sheet, str(sheet.external_source_path)))
		spans.append_array(_editor_tool_bar_spans(sheet))
		spans.append_array(_this_editor_bar_spans(sheet))
	_append_head_band_echo(spans, band_meta, str(band["echo"]), bool(band["echo_ghosted"]))
	row_data.spans = spans
	return row_data


## The badge on a band that HAS a picture - the class icon on the name band, the `@icon` image on
## the icon band. One shape, because clicking the picture is the way to change what it shows in
## both: only the image and the gesture behind it differ. A band whose picture cannot be loaded
## still draws its badge, so the gesture stays reachable.
func _head_band_icon_span(band_meta: Dictionary, action: String, art: Texture2D,
		hover_note: String) -> SemanticSpan:
	var reading_style: EventSheetReadingStyle = _viewport._get_reading_style()
	var badge_meta: Dictionary = band_meta.merged({
		"badge": true,
		"badge_style": "trigger",
		"badge_bg": reading_style.setup_badge_background_color,
		"badge_fg": reading_style.setup_badge_foreground_color,
		"head_action": action,
		"hover_note": hover_note
	}, true)
	if art != null:
		badge_meta["badge_icon"] = art
	return _make_span("▣", SemanticSpan.SpanType.KEYWORD, badge_meta)


## The `@tool` band's switch: a mark, never a word. Clicking it writes or removes the line.
func _head_band_switch_span(band_meta: Dictionary, switched_on: bool) -> SemanticSpan:
	var reading_style: EventSheetReadingStyle = _viewport._get_reading_style()
	return _make_span(
		HEAD_SWITCH_ON_GLYPH if switched_on else HEAD_SWITCH_OFF_GLYPH,
		SemanticSpan.SpanType.KEYWORD,
		band_meta.merged({
			"badge": true,
			"badge_style": "glyph",
			"badge_natural_width": true,
			"badge_fixed_width": KIND_BADGE_WIDTH,
			"head_action": EventSheetHeadBands.BAND_TOOL,
			"badge_bg": reading_style.plain_chip_background_color,
			"badge_fg": reading_style.primary_text_color if switched_on else reading_style.muted_text_color,
			"hover_note": EventSheetL10n.translate("Runs in the editor too.")
		}, true)
	)


## The band's own line, echoed at the right edge in the script editor's token colours - the same
## echo a variable row carries, so one grammar covers every declaration on the canvas. A line the
## sheet does not have yet (an unticked `@tool`) echoes ghosted, so the control stays findable
## without claiming the file says something it does not.
func _append_head_band_echo(spans: Array[SemanticSpan], band_meta: Dictionary,
		echo_line: String, ghosted: bool) -> void:
	if echo_line.strip_edges().is_empty():
		return
	spans.append(_code_echo_span(
		echo_line,
		band_meta.merged({
			"hover_note": EventSheetL10n.translate("The line this band stands for. Click to open it in the code panel.")
		}, true),
		HEAD_ECHO_GHOST_ALPHA if ghosted else EventSheetCodeEcho.REST_ALPHA,
		true
	))


## THE code echo: one line of the file, tokenised and coloured by the script editor's own theme,
## resting at a fraction of it. Every echo on the canvas - a head band's, a declaration's, a region
## fence's - is built here, so none of them can drift into formatting a line by hand. The palette is
## resolved ONCE per sweep: asking Editor Settings for eight colours per row is exactly the
## build-loop lookup this viewport does not do.
func _code_echo_span(echo_line: String, meta: Dictionary, alpha: float, align_right: bool) -> SemanticSpan:
	if _code_echo_palette.is_empty():
		_code_echo_palette = EventSheetCodeEcho.palette(
			_viewport._get_reading_style(), _viewport._get_event_style()
		)
	return _make_span(echo_line, SemanticSpan.SpanType.COMMENT, meta.merged({
		"editable": false,
		"code_echo": true,
		"align_right": align_right,
		"bbcode_segments": EventSheetCodeEcho.segments(echo_line, _code_echo_palette, alpha)
	}, true))


## The "+ add" row under the stack: the lines this sheet COULD have and does not, offered where the
## reader is already looking. Never autoload or host - those come from choosing a kind.
func _build_head_add_row(sheet: EventSheetResource, add_text: String) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = 0
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = null
	row_data.row_uid = "%sadd_%d" % [HEAD_BAND_UID_PREFIX, sheet.get_instance_id()]
	row_data.folded = false
	row_data.spans = [
		_make_span(add_text, SemanticSpan.SpanType.COMMENT, {
			"editable": false,
			"kind": "head_band_add",
			"head_band": "add",
			"head_action": "add",
			"line_index": 0,
			"text_color": _viewport._get_reading_style().muted_text_color
		})
	]
	return row_data


## True when a block of prelude code carries the file's own `##` prose (not just `## @ace_*`
## annotations) - the block a description edit has to rewrite. Asked of the band model's own line
## table, like the writer that rewrites the block, so the reader that finds the description's home
## and the writer that edits it can never pick different blocks.
func _carries_class_description(code: String) -> bool:
	for raw_line: String in code.split("\n"):
		if EventSheetHeadBands.line_is(raw_line.strip_edges(), EventSheetHeadBands.BAND_DESCRIPTION):
			return true
	return false


## Whether this sheet has already been placed - the one head fact no line of the file carries, and
## the only thing the "attach to a node" prompt waits on. A kind that places itself (an autoload, a
## behaviour, a data type, an editor tool), a class the project knows by name, and a file already on
## disk have all been answered; what is left is the sheet that was made a minute ago.
##
## Deliberately answered from what the sheet already knows and NEVER from a walk of the project's
## scenes: this runs inside the row build, and the head must not make a rebuild pay for a scan.
func _sheet_is_attached(sheet: EventSheetResource, declared_class: String) -> bool:
	if sheet == null or sheet.read_only:
		return true
	if sheet.autoload_mode or sheet.behavior_mode or sheet.tool_mode:
		return true
	if EventSheetScriptIntent.is_resource_host(sheet.host_class.strip_edges()):
		return true
	if not declared_class.strip_edges().is_empty():
		return true
	return not str(sheet.external_source_path).strip_edges().is_empty()


## A clickable footer row that appends a new event into owner_resource (a group or the
## sheet). source_resource stays null on purpose so selection/delete/drag paths (which act on
## the source resource) treat it as inert; the owner travels in span metadata instead.
func _build_add_event_footer_row(owner_resource: Resource, indent: int, label: String) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = null
	row_data.row_uid = "add_event_footer_%d" % (owner_resource.get_instance_id() if owner_resource != null else 0)
	row_data.folded = false
	row_data.spans = [
		_make_span(
			EventSheetL10n.translate(label),
			SemanticSpan.SpanType.COMMENT,
			{
				"kind": "add_event",
				"editable": false,
				"add_event_owner": owner_resource,
				"text_color": Color(_viewport._get_reading_style().muted_text_color.r, _viewport._get_reading_style().muted_text_color.g, _viewport._get_reading_style().muted_text_color.b, 0.8)
			}
		)
	]
	return row_data


## The sheet's verbs (its functions) as INLINE event-rows - one role-tinted Define row per EventFunction,
## at root level, so a sheet reads top-to-bottom like the function definitions in a code file. Functions
## live in `sheet.functions`, a SEPARATE array from `sheet.events`, so without this they never appear on
## the canvas at all: a behaviour pack's whole vocabulary was invisible until you opened the Functions
## dialog. This is a pure READ view - it never writes to either array and never affects codegen - so the
## byte-exact round-trip of the underlying .gd is untouched. (Formerly a folded "Published verbs" section;
## the verbs now read inline, role-tinted like any Action / Condition / Expression, rather than hiding
## behind a section header.)
## One verb as a block: its description caption (when it has one) welded to its Define row, so the
## pack author's own `## @ace_description` reads as the sentence above the verb it describes.
func build_verb_block_rows(event_function: EventFunction, indent: int) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	# In READING mode the caption is gone: an event-sheet Function block is its name and its inputs,
	# and the description is one of the things the ACE properties popup answers. (An unpublished
	# helper keeps its doc comment - in the header's right lane, where a reader expects it.)
	if not _verb_reading_mode():
		var note_row: EventRowData = _build_verb_note_row(event_function, define_role_for(event_function), indent)
		if note_row != null:
			rows.append(note_row)
	var head_row: EventRowData = _build_define_function_row(event_function, indent)
	rows.append(head_row)
	# An `@rpc` carrying an option Godot does not take cannot be read into words, so the row
	# shows the annotation itself and this note says which option stopped it. Amber, never red: the
	# file compiles, and it is only the message that will not travel.
	var message_note: String = EventSheetMessageFacts.unknown_note(
		EventSheetMessageFacts.annotation_of(event_function))
	if not message_note.is_empty():
		rows.append(_build_note_row(
			"message_note_%s" % event_function.function_name.strip_edges(), indent,
			"message_note", message_note,
			_viewport._get_reading_style().lift_note_badge_foreground_color, {}, {}))
	# A message anyone may send that writes a value every peer keeps in step, without ever
	# asking who sent it. It is about the MESSAGE, so the amber state sits on its head - the quiet
	# sheet law, at a function anchor: no note row, the words in the inbox and the strip.
	_stamp_attention(head_row, _tagged(FINDINGS_MULTIPLAYER,
		EventSheetMultiplayerFindings.for_subject(_sheet_findings(FINDINGS_MULTIPLAYER),
			EventSheetMultiplayerFindings.ANCHOR_FUNCTION,
			event_function.function_name.strip_edges())))
	return rows


## Every verb the events pass did NOT already splice in at its FunctionAnchorRow slot, in
## `sheet.functions` order. This mirrors the compiler's trailing-functions section, which skips the
## same anchored names, so the canvas and the emitted file list the vocabulary in one order.
func build_trailing_verb_rows(sheet: EventSheetResource) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	if sheet == null or sheet.functions.is_empty():
		return rows
	var anchored_names: Dictionary = {}
	for entry: Variant in sheet.events:
		if entry is FunctionAnchorRow:
			anchored_names[(entry as FunctionAnchorRow).function_name] = true
	for entry: Variant in sheet.functions:
		if entry is EventFunction and not anchored_names.has((entry as EventFunction).function_name):
			rows.append_array(build_verb_block_rows(entry as EventFunction, 0))
	return rows


## Gathers a read-only preview's UNPUBLISHED helpers under one foldable "Helpers" bar, placed after the
## last published verb and closed by default - the event-sheet reading, where a pack's vocabulary comes
## first and the functions it uses on itself sit in a group you open when you care. PURE VIEW: the rows
## are re-parented in the already-built list, so `sheet.functions`, `sheet.events` and the emitted file
## are untouched (exactly like the "Class setup" strip). Only in a read-only preview: on a sheet you are
## authoring, a helper is a row you may want to reach without opening a group first.
## Returns the root list to use (the same array, rebuilt) so the caller can assign it back.
func group_helper_verb_rows(rows: Array[EventRowData], sheet: EventSheetResource) -> Array[EventRowData]:
	if sheet == null or not sheet.read_only:
		return rows
	var helpers: Array[EventRowData] = []
	var kept: Array[EventRowData] = []
	var last_published: int = -1
	# A constructor that only stores the object it was handed says nothing a reader has to read:
	# the Include bar already says the class is made with that object. So it folds into the bar, and
	# the helper's functions start with the first one that does something.
	var folds_constructor: bool = EventSheetEditorSourceFacts.facts(_viewport._sheet as EventSheetResource) \
		.get("helper_of") is Dictionary
	# And the same rule for a test's `_check`: it is the harness the Check rows are DRAWN from,
	# the same eleven lines in every file in the folder, and the Include bar already says this is a
	# test sheet and how many checks it makes. Folded here rather than with the other head facts
	# because the trailing verbs are appended to the list after that pass has run.
	var folds_harness: bool = _folds_test_harness(sheet)
	for row_data: EventRowData in rows:
		var owner_function: EventFunction = row_data.source_resource as EventFunction
		if folds_constructor and owner_function != null and owner_function.function_name == "_init":
			continue
		if folds_harness and owner_function != null \
				and owner_function.function_name == EventSheetToolFiles.CHECK_HELPER:
			continue
		if owner_function != null and row_data.row_type == EventRowData.RowType.EVENT and not owner_function.expose_as_ace:
			_shift_row_indent(row_data, 1)
			helpers.append(row_data)
			continue
		kept.append(row_data)
		if owner_function != null and owner_function.expose_as_ace:
			last_published = kept.size() - 1
	if helpers.is_empty():
		return rows
	var bar: EventRowData = _build_helpers_group_row(sheet, helpers)
	var insert_at: int = last_published + 1 if last_published >= 0 else kept.size()
	kept.insert(insert_at, bar)
	return kept


## The "Helpers" bar itself: a synthetic SECTION row owning the helper blocks as children. Null source
## (nothing to select, drag or delete - it is a lens, not a resource) and closed by default, remembered
## per session through the shared fold state like every other block.
func _build_helpers_group_row(sheet: EventSheetResource, helpers: Array[EventRowData]) -> EventRowData:
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var row_data := EventRowData.new()
	row_data.indent = 0
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = null
	row_data.row_uid = "helpers_group_%d" % sheet.get_instance_id()
	row_data.children = helpers
	row_data.folded = bool(_viewport._fold_state.get(row_data.row_uid, true))
	row_data.spans = [
		_make_span(EventSheetL10n.translate("Helpers"), SemanticSpan.SpanType.OBJECT, {
			"editable": false,
			"kind": "helpers_group",
			"line_index": 0,
			"text_color": event_style.object_label_color
		}),
		_make_span(
			EventSheetL10n.translate("functions this pack uses inside itself - %d") % helpers.size(),
			SemanticSpan.SpanType.COMMENT,
			{
				"editable": false,
				"kind": "helpers_group",
				"line_index": 0,
				"text_color": _viewport._get_reading_style().muted_text_color
			}
		)
	]
	return row_data


## Moves a row and its whole subtree one level deeper (or shallower) - what re-parenting a built row
## under a synthetic bar costs, since indent is baked into each row at build time.
func _shift_row_indent(row_data: EventRowData, delta: int) -> void:
	row_data.indent = maxi(row_data.indent + delta, 0)
	for child: EventRowData in row_data.children:
		_shift_row_indent(child, delta)


## Re-collapses the verbs that turn out to live INSIDE something - a group, or a #region range paired
## after the rows were built. A verb at root stays open (its steps are the point); a nested one belongs
## to the block that encloses it, so it folds with that block instead of forcing it open. Run once over
## the finished root list, after the region fences are paired. A fold the user set by hand still wins.
func fold_nested_verb_rows(rows: Array[EventRowData], nested: bool = false) -> void:
	for row_data: EventRowData in rows:
		if nested and row_data.source_resource is EventFunction and not row_data.children.is_empty():
			row_data.folded = bool(_viewport._fold_state.get(row_data.row_uid, true))
		if not row_data.children.is_empty():
			fold_nested_verb_rows(row_data.children, true)


## THE HEAD OF AN OPENED PACK, in the event-sheet grammar. A read-only preview used to open on two and a
## half screens of prelude before its first rule: a Class setup bar, a `host` variable, a Host binding
## bar, every trigger as its own row, then 46 variable rows, then the pack's about text repeated at the
## end as a grey wall. An event sheet puts that same material in four shapes, and this is the lens that
## reads it back as them:
##   1. ONE Include bar carrying the pack's identity (the slot an event sheet uses for "Include: Sheet") -
##      the class-setup strip, the `host` variable and the Host binding bar fold INTO it.
##   2. The class description ONCE, as a comment bar right underneath (never again at the end).
##   3. Foldable group bars - Triggers, one per @export_group in FILE order, Settings for exported
##      knobs declared before any group, and Internal state for what the pack keeps to itself.
##   4. Variable rows in the reading shape (type word, name, value, description).
## PURE VIEW, like the Class setup strip and the Helpers bar: the already-built rows are re-parented
## (or rebuilt from the SAME LocalVariable resources) inside the list, so `sheet.events`, the resources
## and the emitted bytes are untouched. Read-only only - on a sheet you are authoring, every one of
## these rows is something you reach for, and hiding it behind a fold would cost more than it saves.
## Returns the root list to use (the caller assigns it back).
func build_read_only_head_rows(rows: Array[EventRowData], sheet: EventSheetResource) -> Array[EventRowData]:
	if sheet == null or not sheet.read_only or rows.is_empty():
		return rows
	# ────────────────────────────────────────────────────────────────────────────────────────────
	# Ahead of everything else, and whatever the rest of this head turns out to read as: on an editor
	# add-on the constant-answer virtuals have already been said on the Include bar as facts, so the
	# rows that would repeat them are dropped from the VIEW. Nothing is removed from the sheet - the
	# functions are still there, and still emitted, which is why this may only ever run read-only.
	rows = _fold_editor_plugin_facts(rows, sheet)
	var host_class: String = ""
	var identity_seen: bool = false
	# The band stack the file opens with. It IS the head, here as much as on an authored sheet,
	# so it is carried through rather than folded away and the Include bar keeps only what no band
	# says.
	var band_rows: Array[EventRowData] = []
	var triggers: Array[EventRowData] = []
	# [{variable: LocalVariable, group: String, description: String}] in FILE order.
	var knobs: Array = []
	var leftovers: Array[EventRowData] = []
	# A doc comment waiting to become the NEXT variable's description, and the row it came from - kept
	# so a comment nothing claims is shown rather than quietly swallowed.
	var pending_description: String = ""
	var pending_row: EventRowData = null
	# The @export_group in force: Godot's grouping runs until the NEXT group line, so the importer
	# records it on the FIRST knob of each run only - carry it forward or every group but its first
	# knob lands in the wrong bar.
	var current_group: String = ""
	var consumed: int = 0
	for index in range(rows.size()):
		var row_data: EventRowData = rows[index]
		var source: Resource = row_data.source_resource
		if row_data.row_uid.begins_with(HEAD_BAND_UID_PREFIX):
			identity_seen = true
			band_rows.append(row_data)
			consumed = index + 1
			continue
		if source is RawCodeRow:
			var code: String = (source as RawCodeRow).code
			var bound_class: String = host_binding_class(code)
			if not bound_class.is_empty():
				host_class = bound_class
				identity_seen = true
				consumed = index + 1
				continue
			var code_lines: PackedStringArray = code.split("\n")
			if is_blank_block(code_lines):
				consumed = index + 1
				continue
			if is_comment_only_block(code_lines):
				# A doc comment the importer could not absorb onto its variable (a multi-line one)
				# is still that variable's description - it belongs in the row below, not as a grey
				# line of its own. An ANNOTATION block says nothing to a reader and nothing to the
				# next row either, so it stays a visible row rather than being silently hidden.
				var comment_text: String = _head_comment_text(code_lines)
				if pending_row != null:
					leftovers.append(pending_row)
					pending_row = null
				if comment_text.is_empty():
					leftovers.append(row_data)
				else:
					pending_description = comment_text
					pending_row = row_data
				consumed = index + 1
				continue
			break
		if source is SignalRow:
			_shift_row_indent(row_data, 1)
			triggers.append(row_data)
			pending_description = ""
			if pending_row != null:
				leftovers.append(pending_row)
				pending_row = null
			consumed = index + 1
			continue
		# `const BULLET_SCENE := preload("res://bullet.tscn")` lifts to a `preload` block, not a
		# variable. It is still a name the file introduces, so it reads as an Object row in the head
		# rather than stopping it dead one line in.
		if source is CustomBlockRow and (source as CustomBlockRow).kind_id == "preload":
			var block_fields: Dictionary = (source as CustomBlockRow).fields
			var block_row: EventRowData = _build_preload_object_row(
				str(block_fields.get("name", "")),
				str(block_fields.get("path", "")),
				1,
				source,
				"preload_reading_%d" % source.get_instance_id()
			)
			if block_row == null:
				break
			knobs.append({"row": block_row, "group": "", "description": ""})
			pending_description = ""
			pending_row = null
			consumed = index + 1
			continue
		if source is LocalVariable:
			var variable: LocalVariable = source as LocalVariable
			# The `host` variable IS the host binding written as a member - one fact, said once, on
			# the include bar.
			if variable.name == "host" and not variable.exported:
				identity_seen = true
				if host_class.is_empty():
					host_class = variable.type_name
				pending_description = ""
				pending_row = null  # the `host` doc comment says what the include bar now says
				consumed = index + 1
				continue
			var attributes: Dictionary = variable.attributes if variable.attributes is Dictionary else {}
			if variable.exported:
				var declared_group: String = str(attributes.get("group", "")).strip_edges()
				if not declared_group.is_empty():
					current_group = declared_group
			var description: String = str(attributes.get("tooltip", "")).strip_edges()
			if description.is_empty():
				description = pending_description
			elif pending_row != null:
				leftovers.append(pending_row)  # the knob had its own sentence; this one belongs to nobody
			knobs.append({
				"variable": variable,
				"group": current_group if variable.exported else "",
				"description": description
			})
			pending_description = ""
			pending_row = null
			consumed = index + 1
			continue
		break
	if pending_row != null:
		leftovers.append(pending_row)
	# Nothing that reads as a pack head - leave the sheet exactly as it was built. An editor add-on is
	# the exception: what KIND of add-on it is has to be said, and the smallest ones (an Inspector
	# add-on is four callbacks and no members at all) declare neither a signal nor a knob to hang the
	# bar on. Their identity is the class they extend, which is a head fact on its own.
	var editor_addon: bool = EventSheetEditorPluginWords.is_editor_plugin_class(str(sheet.host_class).strip_edges())
	var publishes_vocabulary: bool = bool(EventSheetEditorSourceFacts.facts(sheet).get("vocabulary_module", false))
	if not identity_seen or (triggers.is_empty() and knobs.is_empty() and not editor_addon and not publishes_vocabulary):
		return rows
	# The bands first: an opened pack's head is the head of its FILE, one band per line, exactly
	# as an authored sheet's is. A file whose prelude was too slight to fold still gets them, built
	# from what the sheet knows, so identity is never the thing that goes missing.
	var head: Array[EventRowData] = band_rows.duplicate()
	if head.is_empty():
		head.append_array(build_head_band_rows(sheet, []))
	# …and then the bar, carrying only what no band states: what the file is as a PACKAGE (an addon,
	# its version, the class it behaves on), how much of it reads as events, and its receipts. A bar
	# left with nothing but its mark is not drawn at all.
	var include_bar: EventRowData = _build_pack_include_bar_row(sheet, host_class)
	if include_bar.spans.size() > 1:
		head.append(include_bar)
	# A script that extends ANOTHER SCRIPT of this project is including that sheet: everything
	# the base declares runs here too. That is a second bar under the identity one, naming the file
	# and offering to open it, rather than an inheritance keyword nobody outside the language knows.
	var base_include_row: EventRowData = _build_base_script_include_bar_row(sheet)
	if base_include_row != null:
		head.append(base_include_row)
	# The pack's own trailing about-comment, hoisted: at the END of a file it is a grey wall nobody
	# scrolls to, and at the top it is the sentence a reader came for. The `##` class description is
	# NOT repeated here - the description band above says it, once.
	var about_index: int = _pack_about_row_index(rows, consumed)
	if about_index >= 0:
		rows[about_index].indent = 0
		head.append(rows[about_index])
	if not triggers.is_empty():
		var fires_subtitle: String = EventSheetL10n.translate("this script fires - %d")
		if is_addon_pack(sheet):
			fires_subtitle = EventSheetL10n.translate("this pack fires - %d")
		elif is_autoload(sheet):
			fires_subtitle = EventSheetL10n.translate("this global fires - %d")
		head.append(_build_head_group_row(
			sheet,
			"pack_triggers",
			EventSheetL10n.translate("Triggers"),
			fires_subtitle % triggers.size(),
			triggers
		))
	head.append_array(_build_object_folder_rows(sheet))
	head.append_array(_build_input_actions_bar_rows(sheet))
	head.append_array(_build_global_variables_bar_rows(sheet))
	head.append_array(_build_knob_group_rows(sheet, knobs))
	head.append_array(leftovers)
	var output: Array[EventRowData] = []
	output.append_array(head)
	for tail_index in range(consumed, rows.size()):
		if tail_index == about_index:
			continue  # the about text reads at the TOP now; a second copy at the end is the grey wall
		output.append(rows[tail_index])
	return output


## The same row list without the rows that only restate a head fact, and with the file's
## shape claimed as the editor-plugin pattern it is. Returns `rows` untouched for every sheet that
## does not extend an editor plugin class, which is every game script.
func _fold_editor_plugin_facts(rows: Array[EventRowData], sheet: EventSheetResource) -> Array[EventRowData]:
	var host_class: String = str(sheet.host_class).strip_edges()
	if not EventSheetEditorPluginWords.is_editor_plugin_class(host_class):
		return rows
	# The one claim this reading makes, and it is about the whole file: what you are looking at is an
	# add-on to the editor, of this kind. Nothing to adopt - a plugin is not a shape a shipped
	# behavior could replace, it IS the plugin.
	EventSheetPatternFacts.claim(sheet, "editor_plugin", "editor_plugin_head", "editor_plugin_head",
		PackedStringArray(["extends %s" % host_class]),
		EventSheetL10n.translate(EventSheetEditorPluginWords.head_word_for(host_class)), "")
	var kept: Array[EventRowData] = []
	for row_data: EventRowData in rows:
		var source: Resource = row_data.source_resource
		if source is EventFunction and EventSheetEditorPluginWords.is_head_fact_callback(
				host_class, (source as EventFunction).function_name):
			continue
		kept.append(row_data)
	return kept


## True when this sheet is a TEST sheet, whose `_check` helper is the harness the Check rows are
## drawn from rather than anything the test does. False for every file that is not one, which is
## every game script - and for a test opened with no file behind it, since the folder a file lives in
## is half of what makes it a test.
func _folds_test_harness(sheet: EventSheetResource) -> bool:
	if sheet == null:
		return false
	var source_path: String = str(sheet.external_source_path).strip_edges()
	if source_path.is_empty():
		return false
	return EventSheetToolFiles.kind_of(EventSheetToolFiles.lines_of_sheet(sheet), source_path) \
		== EventSheetToolFiles.KIND_TEST_SHEET


## The prose of a comment-only block, "" when it carries only `## @ace_*` annotations (which say
## nothing to a reader) - what a stray doc comment above a variable contributes as its description.
func _head_comment_text(code_lines: PackedStringArray) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for line: String in code_lines:
		var stripped: String = line.strip_edges()
		if stripped.is_empty() or is_ace_annotation_line(stripped):
			continue
		parts.append(strip_comment_prefix(stripped).strip_edges())
	return " ".join(parts).strip_edges()


## What the opened file is as a PACKAGE, in the slot an event sheet uses for its "Include: Sheet"
## strip: `⇥ Addon Pack [v1.0.0] behaves on a [CharacterBody3D]  reads as events ▸`, and for any
## other script its receipts and coverage - `⇥ · player.gd · scene Player.tscn  96% reads as events ▸`.
##
## The file's own IDENTITY is not here: `class_name`, `extends`, `@tool` and an autoload's name
## are lines of the file, and the band stack above states each of them once, with its own echo and
## its own control. This bar says only what no line says - the version, the host it behaves on, how
## much of it read as events, which file it is - so nothing on the head is stated twice.
##
## Inert (null source) and wearing the same accent band + 1.5x presence the Class setup and Host
## binding bars wore, because it replaces both of them on a read-only preview.
func _build_pack_include_bar_row(sheet: EventSheetResource, host_class: String) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = 0
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = null
	row_data.row_uid = "pack_include_bar_%d" % sheet.get_instance_id()
	row_data.height_scale = 1.5
	var accent: Color = _viewport._get_event_style().behavior_accent_color
	row_data.custom_color = Color(accent.r, accent.g, accent.b, 0.22)
	var badge_meta: Dictionary = {
		"editable": false,
		"badge": true,
		"badge_style": "trigger",
		"badge_bg": _viewport._get_reading_style().setup_badge_background_color,
		"badge_fg": _viewport._get_reading_style().setup_badge_foreground_color,
		"kind": "pack_include",
		"line_index": 0
	}
	var icon_class: String = host_class if not host_class.is_empty() else sheet.host_class
	var identity_icon: Texture2D = ACEPickerDialog.editor_icon(icon_class) if not icon_class.is_empty() else null
	# An autoload is the project's GLOBAL, and the globe is the mark it already wears in the
	# Objects rail and in every other sheet's `Game (global) ▸ …` row. Its own class is beside the
	# point: what a reader needs is that this file is reachable from everywhere.
	if is_autoload(sheet):
		var globe: Texture2D = EventSheetViewportReadingRows.autoload_icon()
		if globe != null:
			identity_icon = globe
	if identity_icon != null:
		badge_meta["badge_icon"] = identity_icon
	var spans: Array[SemanticSpan] = [_make_span("⇥", SemanticSpan.SpanType.KEYWORD, badge_meta)]
	if is_autoload(sheet):
		# An autoload's NAME is the autoload band's, one line up, with the `project.godot` entry that
		# grants it echoed beside it; all this bar owes such a file is which file it is.
		spans = _append_include_receipts(spans, str(sheet.external_source_path), {})
	elif is_addon_pack(sheet):
		spans.append_array(_addon_pack_include_spans(sheet, host_class))
	else:
		spans.append_array(_script_include_spans(sheet))
	# What every shape of the bar ends with, in one place: how much of the file read as events, the
	# buttons a tool sheet is run from, and - only inside this plugin's own repo - the bar a file of
	# the RUNNING editor wears. Each is silent for the files it has nothing to say about.
	spans.append_array(_reading_coverage_spans(sheet))
	spans.append_array(_editor_tool_bar_spans(sheet))
	spans.append_array(_this_editor_bar_spans(sheet))
	row_data.spans = spans
	return row_data


## The Include bar of a behaviour PACK: what it is, which version, and the class it behaves on -
## `Addon Pack  v1.0.0  behaves on a  CharacterBody3D`. Its NAME is the name band's, one line up.
func _addon_pack_include_spans(sheet: EventSheetResource, host_class: String) -> Array[SemanticSpan]:
	var muted: Dictionary = {
		"editable": false, "kind": "pack_include", "line_index": 0,
		"text_color": _viewport._get_reading_style().muted_text_color
	}
	var spans: Array[SemanticSpan] = [_make_span(
		EventSheetL10n.translate("Addon Pack"),
		SemanticSpan.SpanType.VALUE,
		{"editable": false, "kind": "pack_include", "line_index": 0,
			"text_color": _viewport._get_reading_style().primary_text_color}
	)]
	var version: String = sheet.addon_version.strip_edges()
	if not version.is_empty():
		spans.append(_pack_include_chip("v%s" % version))
	if not host_class.is_empty():
		spans.append(_make_span(EventSheetL10n.translate("behaves on a"), SemanticSpan.SpanType.VALUE, muted))
		spans.append(_pack_include_chip(host_class))
	# A pack that ships editor tooling says so on its own bar: `adds 1 Tools menu item, 1 dock`.
	# Silent for the packs that add nothing, which is nearly all of them.
	var tools_summary: String = EventSheetEditorToolCensus.summary(EventSheetEditorToolCensus.from_sheet(sheet))
	if not tools_summary.is_empty():
		spans.append(_make_span(tools_summary, SemanticSpan.SpanType.VALUE, muted))
	return spans


## A tool sheet's own play button, on the bar where the writing happens. An editor script is
## otherwise run from the script editor's File > Run and a plugin from Project Settings, both of them
## a room away from the sheet; Run now / Reload / Output / Enable plugin close that loop. Every other
## kind of sheet gets nothing here - a Run now that cannot run is worse than no Run now at all.
func _editor_tool_bar_spans(sheet: EventSheetResource) -> Array[SemanticSpan]:
	var spans: Array[SemanticSpan] = []
	# A file of the RUNNING editor gets its own bar instead of this one. Both would otherwise
	# draw a Reload, and the two mean different things: one re-reads a tool you wrote, the other takes
	# the editor you are looking at off and on again.
	if EventSheetThisEditorBar.applies_to(sheet):
		return spans
	var script_path: String = sheet.external_source_path if sheet != null else ""
	for button: Dictionary in EventSheetEditorToolBar.buttons_for(sheet, script_path):
		spans.append(_make_span(str(button["text"]), SemanticSpan.SpanType.KEYWORD, {
			"editable": false,
			"badge": true,
			"badge_style": "scope",
			"badge_bg": _viewport._get_reading_style().plain_chip_background_color,
			"badge_fg": _viewport._get_reading_style().plain_chip_foreground_color,
			"kind": str(button["kind"]),
			"line_index": 0
		}))
	return spans


## The bar a file of the RUNNING editor wears: what it is, that it is read-only, the door
## out of that, and - on the one file that IS the plugin - Enabled, Reload, Output and plugin.cfg.
##
## Drawn nowhere but in the editor's own repo, so an installed plugin's sheets look exactly as they
## always have. The muted chips are words rather than buttons; the rest are clicked.
func _this_editor_bar_spans(sheet: EventSheetResource) -> Array[SemanticSpan]:
	var spans: Array[SemanticSpan] = []
	for button: Dictionary in EventSheetThisEditorBar.buttons_for(
			sheet, EventSheetThisEditorBar.is_plugin_enabled()):
		if bool(button.get("muted", false)):
			spans.append(_make_span(str(button["text"]), SemanticSpan.SpanType.COMMENT, {
				"editable": false, "kind": str(button["kind"]), "line_index": 0,
				"text_color": _viewport._get_reading_style().muted_text_color
			}))
			continue
		if bool(button.get("error", false)):
			spans.append(_make_span(str(button["text"]), SemanticSpan.SpanType.VALUE, {
				"editable": false, "kind": str(button["kind"]), "line_index": 0,
				"text_color": _viewport._get_reading_style().error_text_color
			}))
			continue
		spans.append(_make_span(str(button["text"]), SemanticSpan.SpanType.KEYWORD, {
			"editable": false,
			"badge": true,
			"badge_style": "scope",
			"badge_bg": _viewport._get_reading_style().plain_chip_background_color,
			"badge_fg": _viewport._get_reading_style().plain_chip_foreground_color,
			"kind": str(button["kind"]),
			"line_index": 0
		}))
	return spans


## The two things a reader wants to know about an opened file before reading a line of it: how
## much of it arrived as events, and whether it even compiles.
##
## The coverage chip (`96% reads as events · 3 script blocks ▸`) is measured by the SAME static the
## corpus gate measures with, so the chip and the test can never disagree about the same file; a
## click walks the script blocks one at a time. A fully-lifted file drops the number and just says
## `reads as events`. The error line is the ENGINE's own count, in red, saying what it costs - a
## script that does not parse does not run, and that is worth more than any styling.
func _reading_coverage_spans(sheet: EventSheetResource) -> Array[SemanticSpan]:
	var spans: Array[SemanticSpan] = []
	var errors: String = EventSheetReadingCoverage.parse_error_text(sheet)
	if not errors.is_empty():
		spans.append(_make_span(errors, SemanticSpan.SpanType.VALUE, {
			"editable": false, "kind": "pack_include", "line_index": 0,
			"text_color": _viewport._get_reading_style().error_text_color
		}))
	var coverage: String = EventSheetReadingCoverage.chip_text(sheet)
	if coverage.is_empty():
		return spans
	spans.append(_make_span(coverage, SemanticSpan.SpanType.KEYWORD, {
		"editable": false,
		"badge": true,
		"badge_style": "scope",
		"badge_bg": _viewport._get_reading_style().plain_chip_background_color,
		"badge_fg": _viewport._get_reading_style().plain_chip_foreground_color,
		"kind": "reading_coverage",
		"line_index": 0
	}))
	return spans


## TRUE when the opened file IS a project autoload. ProjectSettings is the single source of
## truth and the importer already reads it onto the sheet, so this is a read of what the project
## says rather than a guess from the file's shape.
static func is_autoload(sheet: EventSheetResource) -> bool:
	return sheet != null and not sheet.autoload_singleton_name().is_empty()


## The scene's own bar, at the top of a scene view: `⇥ Level1.tscn  a  Node2D  4 scripts`. Inert
## (there is nothing to edit on it) and wearing the same accent band a script's Include bar wears,
## because it is the same kind of thing one level up: the identity of what you are reading.
func build_scene_bar_row(sheet: EventSheetResource) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = 0
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = null
	row_data.row_uid = "scene_bar_%d" % sheet.get_instance_id()
	row_data.height_scale = 1.5
	var accent: Color = _viewport._get_event_style().behavior_accent_color
	row_data.custom_color = Color(accent.r, accent.g, accent.b, 0.22)
	var root_type: String = EventSheetSceneSheet.root_type_of(sheet)
	var badge_meta: Dictionary = {
		"editable": false,
		"badge": true,
		"badge_style": "trigger",
		"badge_bg": _viewport._get_reading_style().setup_badge_background_color,
		"badge_fg": _viewport._get_reading_style().setup_badge_foreground_color,
		"kind": "pack_include",
		"line_index": 0
	}
	var root_icon: Texture2D = ACEPickerDialog.editor_icon(root_type) if not root_type.is_empty() else null
	if root_icon != null:
		badge_meta["badge_icon"] = root_icon
	var spans: Array[SemanticSpan] = [_make_span("⇥", SemanticSpan.SpanType.KEYWORD, badge_meta)]
	spans.append(_make_span(EventSheetSceneSheet.scene_path_of(sheet).get_file(), SemanticSpan.SpanType.OBJECT, {
		"editable": false, "kind": "pack_include", "line_index": 0,
		"text_color": _viewport._get_event_style().object_label_color
	}))
	if not root_type.is_empty():
		spans.append(_make_span(EventSheetL10n.translate("a"), SemanticSpan.SpanType.VALUE, {
			"editable": false, "kind": "pack_include", "line_index": 0, "text_color": _viewport._get_reading_style().muted_text_color
		}))
		spans.append(_pack_include_chip(root_type))
	var scripts: int = EventSheetSceneSheet.members_of(sheet).size()
	spans.append(_make_span(EventSheetL10n.translate("{n} scripts").replace("{n}", str(scripts)),
		SemanticSpan.SpanType.COMMENT, {
			"editable": false, "kind": "pack_include", "line_index": 0, "text_color": _viewport._get_reading_style().muted_text_color
		}))
	row_data.spans = spans
	return row_data


## "Addon Pack" is a CLAIM, so only a file that actually is one makes it: a declared @ace_version, or a
## script living in the addon folder. Any other opened .gd is somebody's game script, and calling it a
## pack would teach a beginner the wrong word for what they are looking at.
static func is_addon_pack(sheet: EventSheetResource) -> bool:
	if sheet == null:
		return false
	return not sheet.addon_version.strip_edges().is_empty() \
		or str(sheet.external_source_path).begins_with("res://eventsheet_addons/")


## What an opened script is BEYOND its own first lines: the shape it plays in this project (a
## data type, a behavior, a store, a page of the vocabulary, an editor add-on and its constant facts),
## whatever it is as tooling, and the receipts - `⇥ data type · item.gd`, `⇥ · player.gd · scene
## Player.tscn`.
##
## The NAME and the class are not here: `class_name` and `extends` are lines of the file, and the
## band stack above states each of them once, with its own control and its own echo. What is left is
## what no line of the file says.
func _script_include_spans(sheet: EventSheetResource) -> Array[SemanticSpan]:
	var source_path: String = str(sheet.external_source_path)
	# Inside a scene view this bar is the OBJECT bar of the node carrying the script, so it says
	# what the scene tree says ("HUD a CanvasLayer") and skips the scene receipt: the whole sheet is
	# that one scene already. A node's NAME is a fact of the SCENE rather than a line of the script, so
	# this is the one shape that still leads with an identity. Double-click opens the script as its
	# own sheet.
	var object_bar: Dictionary = EventSheetSceneSheet.object_bar_of(sheet)
	if not object_bar.is_empty():
		return _scene_object_bar_spans(object_bar, _viewport._get_event_style())
	var base_class: String = sheet.host_class.strip_edges()
	var scene: Dictionary = scene_using_script(source_path) if not source_path.is_empty() else {}
	var spans: Array[SemanticSpan] = []
	# A script with no `class_name` is known by the NODE that runs it: "SpawnerPad" is what its
	# author calls this thing. That name is a fact of the SCENE rather than a line of the file, so it
	# is this bar's to say; a file that declares a class is named by its name band instead.
	var scene_name: String = str(scene.get("root_name", "")).strip_edges() \
		if sheet.custom_class_name.strip_edges().is_empty() else ""
	if not scene_name.is_empty():
		spans.append(_make_span(scene_name, SemanticSpan.SpanType.OBJECT, {
			"editable": false, "kind": "pack_include", "line_index": 0,
			"text_color": _viewport._get_event_style().object_label_color
		}))
	# ───────────────────────────────────────────────────────────────────────────────────────
	# A script that extends a Resource is not an object in the scene: it is a DATA TYPE, and every
	# .tres saved from it is one asset of that type. `extends Resource` is the line; this is the word
	# a designer would use for what that line makes.
	if EventSheetScriptIntent.is_resource_host(base_class):
		spans.append(_pack_include_chip(EventSheetL10n.translate("data type")))
		return _append_include_receipts(spans, source_path, {})
	# ─────────────────────────────────────────────────────────────────────────────────────
	# What this file IS to the editor it is part of, said instead of the class it happens to extend: a
	# behavior of the object it was made with, a store nothing is ever made of, or a page of the
	# vocabulary. All three replace "a RefCounted", which is the least useful true thing about them.
	var tool_shape: Array[SemanticSpan] = _tool_shape_spans(sheet)
	if not tool_shape.is_empty():
		spans.append_array(tool_shape)
		return _append_include_receipts(spans, source_path, {})
	# ─────────────────────────────────────────────────────────────────────────────────────
	# A script extending one of the editor's plugin classes states the questions with constant answers
	# as the facts they are: an EditorPlugin's name, its main screen and its icon are three lines of
	# code that say one thing each, and reading them as three events would be reading three lies.
	if EventSheetEditorPluginWords.is_editor_plugin_class(base_class):
		spans.append(_make_span(" · ".join(_editor_plugin_head_facts(sheet, base_class)),
			SemanticSpan.SpanType.COMMENT, {
				"editable": false, "kind": "pack_include", "line_index": 0,
				"text_color": _viewport._get_reading_style().muted_text_color
			}))
	# ── lens hook ──────────────────────────────────────────────────────────────────────────
	# What this file is as a piece of TOOLING, in the same chips: a test sheet and how many checks it
	# makes, a command tool that runs headless, a pack recipe and the behavior it builds. A recipe's
	# sheet-level property writes are FACTS about the pack, so they read here rather than as rows.
	spans.append_array(_tool_file_chip_spans(sheet, source_path))
	return _append_include_receipts(spans, source_path, scene)


## The muted receipts every shape of the bar ends with, as one span: which file this is, and the scene
## that runs it. One place, because "which file am I looking at" is the same question in all of them.
func _append_include_receipts(spans: Array[SemanticSpan], source_path: String,
		scene: Dictionary) -> Array[SemanticSpan]:
	var receipts: PackedStringArray = PackedStringArray()
	if not source_path.is_empty():
		receipts.append("· %s" % source_path.get_file())
	if not scene.is_empty():
		receipts.append("· %s %s" % [EventSheetL10n.translate("scene"), str(scene.get("scene_path", "")).get_file()])
	if receipts.is_empty():
		return spans
	spans.append(_make_span(" ".join(receipts), SemanticSpan.SpanType.COMMENT, {
		"editable": false, "kind": "pack_include", "line_index": 0,
		"text_color": _viewport._get_reading_style().muted_text_color
	}))
	return spans


## The facts an editor add-on's head bar states, in reading order: what kind of add-on it
## is, then whatever its constant-answer virtuals answer. `editor plugin · main screen "EventSheet"
## · icon eventsheet.svg` for a plugin that owns a workspace, and just `editor plugin` for one that
## does not - a main-screen line on a plugin with no main screen would be a fact it never claimed.
func _editor_plugin_head_facts(sheet: EventSheetResource, host_class: String) -> PackedStringArray:
	var facts: PackedStringArray = PackedStringArray([
		EventSheetL10n.translate(EventSheetEditorPluginWords.head_word_for(host_class))
	])
	match host_class:
		"EditorPlugin":
			if _constant_return_of(sheet, "_has_main_screen") == "true":
				var screen_name: String = _constant_return_of(sheet, "_get_plugin_name")
				if not screen_name.is_empty():
					facts.append("%s %s" % [EventSheetL10n.translate("main screen"), screen_name])
			var icon_file: String = _first_quoted_file(sheet, "_get_plugin_icon")
			if not icon_file.is_empty():
				facts.append("%s %s" % [EventSheetL10n.translate("icon"), icon_file])
		"EditorImportPlugin":
			var importer_name: String = _constant_return_of(sheet, "_get_visible_name")
			if importer_name.is_empty():
				importer_name = _constant_return_of(sheet, "_get_importer_name")
			if not importer_name.is_empty():
				facts.append("%s %s" % [EventSheetL10n.translate("named"), importer_name])
	# The receipt that says who registered this add-on with the editor, found by reading the plugins
	# of THIS project - never a guess, and silent when no file of this project registers it.
	var owner: String = EventSheetEditorPluginWords.added_by(str(sheet.custom_class_name).strip_edges())
	if not owner.is_empty():
		facts.append("%s %s ▸ %s" % [
			EventSheetL10n.translate("added by"), owner, EventSheetL10n.translate("On plugin enabled")
		])
	return facts


## The one value a constant-answer virtual answers with, as the file writes it (`"EventSheet"`,
## `true`) - "" when the sheet has no such function or its body does more than answer.
func _constant_return_of(sheet: EventSheetResource, function_name: String) -> String:
	# The one-line body of a constant-answer virtual lifts to a Return Value row inside an event, so
	# the answer is a parameter rather than a line of text - read it there first, and fall back to the
	# raw text below for a body the lifter left alone.
	for entry: Variant in _function_body_entries(sheet, function_name):
		var steps: Array = (entry as EventRow).actions if entry is EventRow else [entry]
		for step: Variant in steps:
			if not (step is ACEAction) or (step as ACEAction).ace_id != "ReturnValue":
				continue
			var params: Dictionary = (step as ACEAction).params
			if params.is_empty():
				params = (step as ACEAction).parameters
			return str(params.get("value", "")).strip_edges()
	for line: String in _function_body_lines(sheet, function_name):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("return "):
			return stripped.substr(7).strip_edges()
	return ""


## The FILE NAME of the first quoted res:// path a function names - what `_get_plugin_icon` is for,
## where the value is behind a `load()` and the folder it lives in is filing rather than a fact.
func _first_quoted_file(sheet: EventSheetResource, function_name: String) -> String:
	var searched: PackedStringArray = PackedStringArray([_constant_return_of(sheet, function_name)])
	searched.append_array(_function_body_lines(sheet, function_name))
	for line: String in searched:
		var at: int = line.find("\"res://")
		if at < 0:
			continue
		var rest: String = line.substr(at + 1)
		var close_at: int = rest.find("\"")
		if close_at > 0:
			return rest.substr(0, close_at).get_file()
	return ""


## One of the sheet's functions as its body lines, rebuilt in the same spelling every other reading
## is built from. Empty when the sheet declares no such function.
func _function_body_lines(sheet: EventSheetResource, function_name: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for body_entry: Variant in _function_body_entries(sheet, function_name):
		EventSheetViewportReadingRows.append_body_lines(body_entry, lines)
	return lines


## One of the sheet's functions as the resources its body is made of, in file order. Empty when the
## sheet declares no such function.
func _function_body_entries(sheet: EventSheetResource, function_name: String) -> Array:
	if sheet == null:
		return []
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == function_name:
			var body: Array = (entry as EventFunction).events
			return body if not body.is_empty() else (entry as EventFunction).rows
	return []


## The Include-bar chips a tooling file states about itself, plus - for a test that
## opens one - the fixture it reads, which double-click opens beside it. Empty for every other file.
func _tool_file_chip_spans(sheet: EventSheetResource, source_path: String) -> Array[SemanticSpan]:
	var spans: Array[SemanticSpan] = []
	var lines: PackedStringArray = EventSheetToolFiles.lines_of_sheet(sheet)
	var kind: String = EventSheetToolFiles.kind_of(lines, source_path)
	if kind.is_empty():
		return spans
	var head: Dictionary = EventSheetToolFiles.recipe_head(lines) if kind == EventSheetToolFiles.KIND_PACK_RECIPE else {}
	var check_count: int = EventSheetToolFiles.checks(lines).size() if kind == EventSheetToolFiles.KIND_TEST_SHEET else 0
	for chip: String in EventSheetToolFiles.head_chips(kind, check_count, head):
		spans.append(_pack_include_chip(chip))
	if kind == EventSheetToolFiles.KIND_PACK_RECIPE:
		var built: String = EventSheetEditorToolBar.built_pack_path(sheet)
		if not built.is_empty():
			spans.append(_make_span("%s %s" % [EventSheetL10n.translate("builds"), built.get_base_dir().trim_prefix("res://")],
				SemanticSpan.SpanType.COMMENT, {
					"editable": false, "kind": "pack_include", "line_index": 0,
					"text_color": _viewport._get_reading_style().muted_text_color
				}))
	if kind == EventSheetToolFiles.KIND_TEST_SHEET:
		var fixture: String = EventSheetToolFiles.fixture_path(lines)
		if not fixture.is_empty():
			# The fixture is an OBJECT this test opens, so it wears a chip and carries the path every
			# other openable include carries - double-click opens it beside the test.
			var fixture_span: SemanticSpan = _pack_include_chip(
				"%s: %s" % [EventSheetL10n.translate("fixture"), fixture.get_file()])
			fixture_span.metadata["include_path"] = fixture
			fixture_span.metadata["kind"] = "scene_object_open"
			spans.append(fixture_span)
	return spans


## One node's object bar inside a scene view: the node's own name, the class it is, the file its
## script lives in, and "(x3)" when the same script sits on more than one node of this scene. Every
## span carries the script path, so a double-click anywhere on the bar opens that file as its own
## sheet - which is where editing happens, because a scene view never writes anything.
func _scene_object_bar_spans(object_bar: Dictionary, event_style: EventSheetEventStyle) -> Array[SemanticSpan]:
	var script_path: String = str(object_bar.get("script_path", ""))
	var open_meta: Dictionary = {
		"editable": false,
		"kind": "scene_object_open",
		"include_path": script_path,
		"line_index": 0
	}
	var spans: Array[SemanticSpan] = []
	spans.append(_make_span(str(object_bar.get("node", "")), SemanticSpan.SpanType.OBJECT,
		open_meta.duplicate().merged({"text_color": event_style.object_label_color}, true)))
	var node_type: String = str(object_bar.get("type", ""))
	if not node_type.is_empty():
		spans.append(_make_span(EventSheetL10n.translate("a"), SemanticSpan.SpanType.VALUE,
			open_meta.duplicate().merged({"text_color": _viewport._get_reading_style().muted_text_color}, true)))
		spans.append(_make_span(node_type, SemanticSpan.SpanType.KEYWORD, open_meta.duplicate().merged({
			"badge": true,
			"badge_style": "scope",
			"badge_bg": _viewport._get_reading_style().plain_chip_background_color,
			"badge_fg": _viewport._get_reading_style().plain_chip_foreground_color
		}, true)))
	var receipt: String = "· %s" % script_path.get_file()
	var instances: int = int(object_bar.get("instances", 1))
	if instances > 1:
		receipt += " (x%d)" % instances
	spans.append(_make_span(receipt, SemanticSpan.SpanType.COMMENT,
		open_meta.duplicate().merged({"text_color": _viewport._get_reading_style().muted_text_color}, true)))
	return spans


## The project script a sheet EXTENDS, as a res:// path - "" when it extends an engine class (which
## is what the identity bar already says) or when the base cannot be found. Both spellings resolve:
## `extends "res://enemy.gd"` by its path, `extends Enemy` through the project's own class list.
static func base_script_path(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	var base: String = sheet.host_class.strip_edges()
	if base.is_empty():
		return ""
	if base.begins_with("\"") or base.begins_with("'"):
		var quoted: String = base.trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'")
		return quoted if quoted.begins_with("res://") else ""
	if ClassDB.class_exists(base):
		return ""
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == base:
			var path: String = str(entry.get("path", ""))
			# A .gd sheet's own file is never its base: a class list that has not caught up yet would
			# otherwise offer to open the file already open.
			return path if path != str(sheet.external_source_path) else ""
	return ""


## The second head bar: `⇥ Include <base.gd> - open as a sheet`. Null when the base is an engine
## class. Inert as a resource (a lens over the `extends` line, which stays exactly where it is); the
## chip carries the path so opening it goes through the same jump the rest of the canvas uses.
func _build_base_script_include_bar_row(sheet: EventSheetResource) -> EventRowData:
	var base_path: String = base_script_path(sheet)
	if base_path.is_empty():
		return null
	var row_data := EventRowData.new()
	row_data.indent = 0
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = null
	row_data.row_uid = "base_include_bar_%d" % sheet.get_instance_id()
	var accent: Color = _viewport._get_event_style().behavior_accent_color
	row_data.custom_color = Color(accent.r, accent.g, accent.b, 0.12)
	var open_meta: Dictionary = {
		"editable": false,
		"kind": "include_open",
		"include_path": base_path,
		"line_index": 0
	}
	var spans: Array[SemanticSpan] = [
		_make_span("⇥", SemanticSpan.SpanType.KEYWORD, open_meta.duplicate().merged({
			"badge": true,
			"badge_style": "scope",
			"badge_bg": _viewport._get_reading_style().setup_badge_background_color,
			"badge_fg": _viewport._get_reading_style().setup_badge_foreground_color
		}, true)),
		_make_span(EventSheetL10n.translate("Include"), SemanticSpan.SpanType.VALUE, open_meta.duplicate().merged({
			"text_color": _viewport._get_reading_style().primary_text_color
		}, true)),
		_make_span(base_path.get_file(), SemanticSpan.SpanType.KEYWORD, open_meta.duplicate().merged({
			"badge": true,
			"badge_style": "scope",
			"badge_bg": _viewport._get_reading_style().plain_chip_background_color,
			"badge_fg": _viewport._get_reading_style().plain_chip_foreground_color
		}, true)),
		_make_span(EventSheetL10n.translate("- open as a sheet"), SemanticSpan.SpanType.COMMENT,
			open_meta.duplicate().merged({"text_color": _viewport._get_reading_style().muted_text_color}, true))
	]
	row_data.spans = spans
	return row_data


## The middle of a TOOL script's Include bar - the one sentence that says what the
## file is to the editor it belongs to. Empty for every ordinary game script, which is why an
## ordinary project never sees any of these words.
##
## Each shape also CLAIMS itself, so the chip, the hover evidence and the Doctor read one registry
## rather than each re-deriving the same fact from the same file.
func _tool_shape_spans(sheet: EventSheetResource) -> Array[SemanticSpan]:
	var spans: Array[SemanticSpan] = []
	if sheet == null:
		return spans
	var facts: Dictionary = EventSheetEditorSourceFacts.facts(sheet)
	if facts.is_empty():
		return spans
	var bar_uid: String = "pack_include_bar_%d" % sheet.get_instance_id()
	var helper: Dictionary = facts.get("helper_of", {}) if facts.get("helper_of") is Dictionary else {}
	if not helper.is_empty():
		var object_name: String = str(helper.get("object", ""))
		var helper_file: String = str(helper.get("file", ""))
		spans.append(_include_muted_span(EventSheetL10n.translate("helper of")))
		spans.append(_make_span(object_name, SemanticSpan.SpanType.OBJECT, {
			"editable": false, "kind": "pack_include", "line_index": 0,
			"text_color": _viewport._get_event_style().object_label_color
		}))
		var made_with: String = EventSheetL10n.translate("made with the {object}") \
			.replace("{object}", object_name.to_lower())
		spans.append(_include_muted_span(
			"· %s" % made_with if helper_file.is_empty() else "(%s) · %s" % [helper_file, made_with]))
		EventSheetPatternFacts.claim(sheet, "helper_of", bar_uid, bar_uid,
			PackedStringArray([str(helper.get("member", ""))]),
			EventSheetL10n.translate("adds its own actions to {object}").replace("{object}", object_name))
		return spans
	if bool(facts.get("shared_store", false)):
		spans.append(_include_muted_span(EventSheetL10n.translate("shared store")))
		spans.append(_include_muted_span("· %s" % EventSheetL10n.translate("nothing of its own is ever made")))
		EventSheetPatternFacts.claim(sheet, "shared_store", bar_uid, bar_uid, PackedStringArray(),
			EventSheetL10n.translate("one store for the whole editor"))
		return spans
	if bool(facts.get("vocabulary_module", false)):
		var published: int = (facts.get("vocabulary_rows", []) as Array).size()
		spans.append(_include_muted_span(EventSheetL10n.translate("vocabulary module")))
		spans.append(_include_muted_span("· %s" % EventSheetL10n.translate("{n} rows published")
			.replace("{n}", str(published))))
		EventSheetPatternFacts.claim(sheet, "vocabulary_module", bar_uid, bar_uid, PackedStringArray(),
			EventSheetL10n.translate("publishes rows the picker offers"))
		return spans
	return spans


## One muted word of an Include bar - the tone every receipt on that bar is written in.
func _include_muted_span(text: String) -> SemanticSpan:
	return _make_span(text, SemanticSpan.SpanType.COMMENT, {
		"editable": false, "kind": "pack_include", "line_index": 0,
		"text_color": _viewport._get_reading_style().muted_text_color
	})


func _pack_include_chip(text: String) -> SemanticSpan:
	return _make_span(text, SemanticSpan.SpanType.KEYWORD, {
		"editable": false,
		"badge": true,
		"badge_style": "scope",
		"badge_bg": _viewport._get_reading_style().plain_chip_background_color,
		"badge_fg": _viewport._get_reading_style().plain_chip_foreground_color,
		"kind": "pack_include",
		"line_index": 0
	})


## Index of the pack's about text among the already-built rows - the class doc a pack repeats at the
## END of its file, which reads there as a grey wall nobody scrolls to. Only the LAST content row
## qualifies, and only when it is a paragraph rather than a note about the code above it.
func _pack_about_row_index(rows: Array[EventRowData], from_index: int) -> int:
	for index in range(rows.size() - 1, maxi(from_index, 0) - 1, -1):
		var row_data: EventRowData = rows[index]
		if row_data.source_resource is RawCodeRow and is_blank_block((row_data.source_resource as RawCodeRow).code.split("\n")):
			continue
		if row_data.row_type == EventRowData.RowType.COMMENT and row_data.source_resource is CommentRow \
				and (row_data.source_resource as CommentRow).text.strip_edges().length() >= 60:
			return index
		return -1
	return -1


## The two folders an event sheet's object carries, before its settings: the BEHAVIORS mounted on
## it and the FAMILIES it belongs to. Both are facts about the object rather than lines of the file, so
## they come from where Godot keeps them - pack nodes in the scene the script is the root of, and that
## root's persistent groups plus the file's own `add_to_group` lines.
##
## PURE VIEW, like every other head bar: null sources, folded by default, nothing added to `sheet.events`
## and nothing emitted, so an opened file still re-emits byte for byte. Empty folders are not built - an
## object with no behaviors should not grow a bar telling it so.
func _build_object_folder_rows(sheet: EventSheetResource) -> Array[EventRowData]:
	var bars: Array[EventRowData] = []
	var facts: Dictionary = EventSheetObjectFacts.sheet_object_facts(sheet)
	var behaviors: Array = facts.get("behaviors", []) if not facts.is_empty() else []
	# ───────────────────────────────────────────────────────────────────────────────────────────
	# A machine this file WRITES OUT is a behavior on the object exactly as a mounted pack node is,
	# so it is one ordinary line here - "FSM · Idle" - and the enum, the state variable and the
	# transition functions it stands for show on hover. Nothing else about the machine is added to
	# the canvas, because a behavior does not put its plumbing on a sheet.
	var written_machine: Array = _written_behaviors(sheet)
	if not written_machine.is_empty():
		behaviors = behaviors.duplicate()
		behaviors.append_array(written_machine)
	# The pin bar is read off the FILE, not off a scene, so it is worked out before the early exit:
	# a plain .gd with a pin in it has no scene facts at all and still has something to say.
	#
	# Its facts are worked out HERE rather than taken from `sentence_context()`, deliberately. The
	# head bars are built at the very start of a rebuild, and asking for the sentence context that
	# early builds and caches it before the walk has settled - which quietly changed what the ROWS
	# further down then read. A bar is not worth a reading, so it pays for its own answers, and a
	# one-pass look for a copied property keeps a sheet that pins nothing from paying at all.
	var pins: Array = []
	var pin_lines: PackedStringArray = EventSheetViewportReadingRows.ordered_code_lines(sheet)
	if _might_pin(pin_lines):
		var pin_facts: Dictionary = EventSheetBehaviorShapes.pin_facts(pin_lines)
		var declared_seats: Dictionary = EventSheetViewportReadingRows.pin_seat_map(sheet)
		if not declared_seats.is_empty():
			var seats: Dictionary = (pin_facts.get("pin_seats", {}) as Dictionary).duplicate()
			seats.merge(declared_seats, true)
			pin_facts["pin_seats"] = seats
		pins = EventSheetBehaviorShapes.pin_summaries(pin_lines, pin_facts)
	if behaviors.is_empty() and facts.is_empty() and pins.is_empty():
		return bars
	if not behaviors.is_empty():
		var names: PackedStringArray = PackedStringArray()
		var members: Array[EventRowData] = []
		for index in range(behaviors.size()):
			var behavior: Dictionary = behaviors[index]
			names.append(str(behavior.get("name", "")))
			members.append(_build_object_fact_row(
				sheet, "object_behavior_%d" % index,
				str(behavior.get("name", "")), _behavior_settings_text(behavior)))
		bars.append(_build_head_group_row(
			sheet, "object_behaviors", EventSheetL10n.translate("Behaviors"),
			"%s - %s" % [EventSheetL10n.translate("on this object"), " · ".join(names)],
			members))
	# ────────────────────────────────────────────────────────────────────────────────────────────
	# A RemoteTransform on this object drives a node that is NOT its child, which is the answer to
	# "why does that thing follow me" and lives nowhere a reader of the script would find it. So it
	# reads here, as the fact it is, with the parts it copies as tick chips.
	var followers: Array = facts.get("followers", []) as Array
	if not followers.is_empty():
		var follows: Array[EventRowData] = []
		var followed: PackedStringArray = PackedStringArray()
		for index in range(followers.size()):
			var follower: Dictionary = followers[index]
			var target: String = str(follower.get("target", ""))
			var says: String = EventSheetL10n.translate("copies its place to nothing yet")
			if not target.is_empty():
				says = "%s %s · %s" % [EventSheetL10n.translate("copies its place to"), target,
					str(follower.get("flags", ""))]
			followed.append(str(follower.get("node", "")))
			follows.append(_build_object_fact_row(
				sheet, "object_follower_%d" % index, str(follower.get("node", "")), says))
		bars.append(_build_head_group_row(
			sheet, "object_followers", EventSheetL10n.translate("Follows"),
			"%s - %s" % [EventSheetL10n.translate("places this object copies onto others"),
				" · ".join(followed)], follows))
	# ───────────────────────────────────────────────────────────────────────────────────────────
	# Pin or child? Both words ship, both mean "this goes where that goes", and which one is in use
	# decides what happens when the other object is destroyed - a pin follows at runtime and can let
	# go; a child is structure and is destroyed with its parent. So the object states which it uses,
	# here, beside the parenting, where a reader meets both at once. Derived from the file's own pin
	# lines through the same gates the rows use, so the bar can never announce a pin the canvas does
	# not show.
	if not pins.is_empty():
		var pin_rows: Array[EventRowData] = []
		var ridden: PackedStringArray = PackedStringArray()
		for index in range(pins.size()):
			var pin: Dictionary = pins[index]
			var pin_name: String = str(pin.get("name", ""))
			var modes: PackedStringArray = PackedStringArray()
			for mode: String in (pin.get("modes", PackedStringArray()) as PackedStringArray):
				modes.append(EventSheetL10n.translate(mode))
			ridden.append(pin_name)
			pin_rows.append(_build_object_fact_row(
				sheet, "object_pin_%d" % index, pin_name,
				"%s %s (%s)" % [EventSheetL10n.translate("pinned to"), pin_name,
					" · ".join(modes)]))
		bars.append(_build_head_group_row(
			sheet, "object_pins", EventSheetL10n.translate("Pins"),
			"%s - %s" % [EventSheetL10n.translate("what this object rides, and can let go of"),
				" · ".join(ridden)], pin_rows))
	var families: PackedStringArray = PackedStringArray(facts.get("families", PackedStringArray()))
	# ────────────────────────────────────────────────────────────────────────────────────────────
	# The inheritance set this object is part of: the scripts that extend its class, shown as the
	# members they are. The word the folder is called goes through the one helper, because a project
	# may have pinned "Base class" or "Kind" and it has to change in every place at once.
	var familiar: bool = _familiar_words_enabled()
	var inheritance: Array[EventRowData] = _inheritance_member_rows(sheet, families)
	if not families.is_empty() or not inheritance.is_empty():
		var family_rows: Array[EventRowData] = []
		for index in range(families.size()):
			family_rows.append(_build_object_fact_row(
				sheet, "object_family_%d" % index, families[index], ""))
		family_rows.append_array(inheritance)
		# The Godot word rides along ONCE, muted: a group IS the sheet's family, and a reader who knows
		# only Godot's half of that pair needs the bridge here and nowhere else.
		var summary: String = "%s - %s %s" % [
			EventSheetL10n.translate("this object belongs to"), ", ".join(families),
			EventSheetL10n.translate("(groups)")
		] if not families.is_empty() else EventSheetL10n.translate("what extends this object's class")
		bars.append(_build_head_group_row(
			sheet, "object_families", EventSheetFamilyFacts.plural(familiar), summary, family_rows))
	return bars


## The cheap look before the expensive one: every spelling of a pin copies a place, an angle or a
## size OFF another object, so a file with none of those on any line cannot be pinning and never pays
## for the grammar walk behind the Pins bar. One `contains` per line against a handful of literals,
## against ~eight parsers per line for the walk it stands in front of.
func _might_pin(lines: PackedStringArray) -> bool:
	for line: String in lines:
		if line.contains(".global_position") or line.contains(".position") \
				or line.contains(".transform.origin") or line.contains(".rotation") \
				or line.contains(".scale"):
			return true
	return false


## One row per script that extends this sheet's own class, plus, when a Godot group of the same
## name exists, whether the two agree - a ✓ when the group's members are the set's, and the stray
## named out loud when one of them is not. Empty when the sheet's class is nobody's base, which is
## the common case and must cost nothing.
func _inheritance_member_rows(sheet: EventSheetResource, groups: PackedStringArray) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	var base: String = sheet.custom_class_name.strip_edges()
	if base.is_empty():
		return rows
	var families: Dictionary = EventSheetFamilyFacts.project_families()
	if not families.has(base):
		return rows
	var members: PackedStringArray = (families[base] as Dictionary).get("members", PackedStringArray())
	for index in range(members.size()):
		rows.append(_build_object_fact_row(sheet, "object_extends_%d" % index, members[index],
			EventSheetL10n.translate("extends it")))
	# A group named after the base is the other half of the same idea, and the interesting answer is
	# whether the two lists are the same one.
	for group: String in groups:
		if group.to_lower() != base.to_lower():
			continue
		rows.append(_build_object_fact_row(sheet, "object_family_group", "\"%s\"" % group,
			"%s ✓" % EventSheetL10n.translate("the group has the same members")))
	return rows


## The "Global variables used here" folder: which of the project's globals this file reads or
## writes, and where they are declared. A global is declared once, on an autoload, and used
## everywhere; until this folder the only way to see which ones a file touched was to read it.
##
## PURE VIEW, like every other head bar: null sources, folded by default, nothing added to
## `sheet.events` and nothing emitted, so an opened file still re-emits byte for byte. A script that
## touches no global grows no folder, and neither does the autoload that DECLARES them (its own
## globals are already its head rows - listing them again as "used here" would say nothing).
func _build_global_variables_bar_rows(sheet: EventSheetResource) -> Array[EventRowData]:
	var bars: Array[EventRowData] = []
	if sheet == null or not sheet.autoload_singleton_name().is_empty():
		return bars
	var used: Array[Dictionary] = EventSheetGlobalVariables.used_here(sheet)
	if used.is_empty():
		return bars
	var declared_by_source: Dictionary = {}
	for entry: Dictionary in EventSheetGlobalVariables.autoload_sheets():
		declared_by_source[str(entry.get("name", ""))] = EventSheetGlobalVariables.declared_globals(
			str(entry.get("path", "")))
	var members: Array[EventRowData] = []
	for index in range(used.size()):
		var source: String = str(used[index].get("autoload", ""))
		var variable_name: String = str(used[index].get("name", ""))
		var declared: Array = declared_by_source.get(source, [])
		members.append(_build_object_fact_row(
			sheet, "global_variable_%d" % index, variable_name,
			_global_variable_detail(source, variable_name, declared)))
	bars.append(_build_head_group_row(
		sheet, "global_variables", EventSheetL10n.translate("Global variables used here"),
		EventSheetGlobalVariables.used_here_note(used), members))
	return bars


## One global's muted line in the folder: what it is declared as, and on which autoload. A global
## the autoload does not declare is the typo the reader wants told, the same way an unknown input
## action is - a name that resolves to nothing at runtime looks identical to one that works.
func _global_variable_detail(source: String, variable_name: String, declared: Array) -> String:
	for entry: Variant in declared:
		if str((entry as Dictionary).get("name", "")) != variable_name:
			continue
		var type_name: String = str((entry as Dictionary).get("type", "")).strip_edges()
		var word: String = friendly_type_word(type_name) if not type_name.is_empty() else ""
		var value: String = str((entry as Dictionary).get("value", "")).strip_edges()
		if word.is_empty():
			return "%s = %s · %s" % [variable_name, value, source]
		return "%s %s = %s · %s" % [word, variable_name, value, source]
	return EventSheetL10n.translate("not declared on %s") % source


## The Input Map bar: which controls this script uses, and what each one is bound to. The
## project-wide Input Map is what every input row in the file is really about, and until this bar a
## reader had to leave the sheet and open Project Settings to find out what "jump" was.
##
## PURE VIEW, like every other head bar: null sources, folded by default, nothing added to
## `sheet.events` and nothing emitted, so an opened file still re-emits byte for byte. A script that
## names no control grows no bar.
func _build_input_actions_bar_rows(sheet: EventSheetResource) -> Array[EventRowData]:
	var bars: Array[EventRowData] = []
	var actions: Array[Dictionary] = EventSheetInputMapFacts.actions_named_by(sheet)
	if actions.is_empty():
		return bars
	var names: PackedStringArray = PackedStringArray()
	var members: Array[EventRowData] = []
	for index in range(actions.size()):
		var facts: Dictionary = actions[index]
		var action_name: String = str(facts.get("name", ""))
		names.append(action_name)
		members.append(_build_object_fact_row(
			sheet, "input_action_%d" % index,
			action_name if bool(facts.get("known", false)) else "⚠ %s" % action_name,
			_input_action_detail(facts)))
	var uses: String = EventSheetL10n.translate("this script uses 1 action") if actions.size() == 1 \
		else EventSheetL10n.translate("this script uses %d actions") % actions.size()
	bars.append(_build_head_group_row(
		sheet, "input_actions", EventSheetL10n.translate("Input"),
		"%s - %s - %s" % [uses, ", ".join(names), EventSheetL10n.translate("Project ▸ Input Map")],
		members))
	return bars


## One control's muted line in the Input bar: what it is bound to, or what is wrong with it. An
## action the project does not have is the typo every beginner makes, and saying so here is cheaper
## than finding out at runtime that nothing happens.
func _input_action_detail(facts: Dictionary) -> String:
	if not bool(facts.get("known", false)):
		return EventSheetL10n.translate("not in the Input Map")
	var bindings: PackedStringArray = facts.get("bindings", PackedStringArray())
	if bindings.is_empty():
		return EventSheetL10n.translate("unbound")
	return " · ".join(bindings)


## One behavior's settings as the scene wrote them: `max hp = 50 · regen = 1`, "" when the scene left
## the pack on its defaults (which is worth saying by saying nothing).
## The behaviors this file WRITES OUT rather than mounts - today exactly one, the state machine an
## enum plus a variable of it is. Shaped like a scene-mounted behavior so the Behaviors folder cannot
## tell the two apart, which is the point: a hand-rolled machine and the shipped pack are one line
## each, with the same name and the same starting state.
func _written_behaviors(sheet: EventSheetResource) -> Array:
	if sheet == null:
		return []
	var machine: Dictionary = EventSheetStateMachineFacts.facts(
		EventSheetViewportReadingRows.ordered_code_lines(sheet))
	if machine.is_empty():
		return []
	return [{
		"name": EventSheetStateMachineFacts.head_line(machine),
		"node": "",
		"properties": [],
		"written": EventSheetStateMachineFacts.plumbing_note(machine)
	}]


func _behavior_settings_text(behavior: Dictionary) -> String:
	# A behavior the file writes out says so, and says with what: an event sheet's own behaviors
	# have settings, and this one has plumbing.
	var written: String = str(behavior.get("written", "")).strip_edges()
	if not written.is_empty():
		return written
	var parts: PackedStringArray = PackedStringArray()
	for entry: Variant in behavior.get("properties", []):
		var property: Dictionary = entry
		parts.append("%s = %s" % [str(property.get("name", "")), str(property.get("value", ""))])
	return " · ".join(parts)


## A leaf row inside one of the object folders: the thing's name, then what is set on it, muted.
func _build_object_fact_row(sheet: EventSheetResource, uid_suffix: String, title: String,
		detail: String) -> EventRowData:
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var row_data := EventRowData.new()
	row_data.indent = 1
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = null
	row_data.row_uid = "%s_%d" % [uid_suffix, sheet.get_instance_id()]
	var spans: Array[SemanticSpan] = [
		_make_span(title, SemanticSpan.SpanType.OBJECT, {
			"editable": false, "kind": "object_fact", "line_index": 0,
			"text_color": event_style.object_label_color
		})
	]
	if not detail.is_empty():
		spans.append(_make_span(detail, SemanticSpan.SpanType.COMMENT, {
			"editable": false, "kind": "object_fact", "line_index": 0,
			"text_color": _viewport._get_reading_style().muted_text_color
		}))
	row_data.spans = spans
	return row_data


## The pack's knobs as event-sheet setting folders: one bar per @export_group in FILE order, a Settings
## bar for exported knobs declared before any group, and Internal state for the rest.
func _build_knob_group_rows(sheet: EventSheetResource, knobs: Array) -> Array[EventRowData]:
	# On an autoload every one of these IS a global variable, exported or not: the whole point
	# of the singleton is that the rest of the project reads them. Splitting them into Settings and
	# Internal state would be drawing a line a reader of an event sheet has no use for, so they read
	# as the ONE folder the sheet already has a name for.
	if is_autoload(sheet):
		return _build_global_variables_folder(sheet, knobs)
	var order: PackedStringArray = PackedStringArray()
	var buckets: Dictionary = {}
	var internal: Array[EventRowData] = []
	# How many Inspector-editable rows already lead the one folder - the insert point that keeps them
	# first without re-sorting a list whose order is otherwise the file's.
	var exported_count: int = 0
	for entry: Variant in knobs:
		var record: Dictionary = entry as Dictionary
		var variable: LocalVariable = record.get("variable")
		# A prebuilt row (a `preload` block read as an Object) is never exported - it is something the
		# file keeps for itself, so it lands with the rest of the internal state, in file order.
		if variable == null:
			internal.append(record.get("row") as EventRowData)
			continue
		var row_data: EventRowData = _build_reading_variable_row(variable, str(record.get("description", "")), 1)
		var group_name: String = str(record.get("group", "")).strip_edges()
		if not variable.exported or group_name.is_empty():
			# One folder, not two. A variable is Inspector-editable or it is not, and the row
			# now says so with its own chip, so a Settings / Internal state split would only be
			# telling a reader twice what the chip already tells them once. The Inspector ones lead,
			# because those are the ones a designer came to look at.
			if variable.exported:
				internal.insert(exported_count, row_data)
				exported_count += 1
			else:
				internal.append(row_data)
			continue
		if not buckets.has(group_name):
			buckets[group_name] = [] as Array[EventRowData]
			order.append(group_name)
		(buckets[group_name] as Array[EventRowData]).append(row_data)
	var bars: Array[EventRowData] = []
	for group_name: String in order:
		var members: Array[EventRowData] = buckets[group_name]
		bars.append(_build_head_group_row(
			sheet,
			"pack_settings_%s" % group_name,
			group_name,
			(EventSheetL10n.translate("%d setting") if members.size() == 1 else EventSheetL10n.translate("%d settings")) % members.size(),
			members
		))
	if not internal.is_empty():
		var object_name: String = EventSheetViewportReadingRows.script_object_name(sheet)
		var subtitle: String = "%d" % internal.size() if object_name.is_empty() \
			else EventSheetL10n.translate("of %s") % object_name
		bars.append(_build_head_group_row(
			sheet,
			"pack_internal_state",
			EventSheetL10n.translate("Instance variables"),
			subtitle,
			internal
		))
	return bars


## An autoload's knobs as the sheet's ONE Global variables folder, in file order. Same rows,
## same reading; only the folders they live in change, because on a global there is nothing for a
## second folder to mean.
func _build_global_variables_folder(sheet: EventSheetResource, knobs: Array) -> Array[EventRowData]:
	var members: Array[EventRowData] = []
	for entry: Variant in knobs:
		var record: Dictionary = entry as Dictionary
		var variable: LocalVariable = record.get("variable")
		if variable == null:
			members.append(record.get("row") as EventRowData)
			continue
		members.append(_build_reading_variable_row(variable, str(record.get("description", "")), 1))
	if members.is_empty():
		return [] as Array[EventRowData]
	return [_build_head_group_row(
		sheet,
		"pack_global_variables",
		EventSheetL10n.translate("Global variables"),
		"%d" % members.size(),
		members
	)] as Array[EventRowData]


## One head bar: the event-group header look (folder icon, title, muted count), owning its rows as
## children so the existing fold machinery collapses them for free. Null source - a lens, not a
## resource. Folded by default on a read-only preview (the reading order is identity, then logic);
## an editable sheet would open them, because there the knobs are what you came to edit.
func _build_head_group_row(sheet: EventSheetResource, uid_suffix: String, title: String, subtitle: String,
		members: Array[EventRowData]) -> EventRowData:
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var row_data := EventRowData.new()
	row_data.indent = 0
	row_data.row_type = EventRowData.RowType.GROUP
	row_data.source_resource = null
	row_data.row_uid = "%s_%d" % [uid_suffix, sheet.get_instance_id()]
	row_data.children = members
	row_data.folded = bool(_viewport._fold_state.get(row_data.row_uid, sheet.read_only))
	row_data.spans = [
		_make_span(title, SemanticSpan.SpanType.OBJECT, {
			"editable": false,
			"kind": "pack_head_group",
			"line_index": 0,
			"object_icon": _folder_icon() if _viewport.show_object_icons else null,
			"text_color": event_style.group_title_color
		}),
		_make_span(subtitle, SemanticSpan.SpanType.COMMENT, {
			"editable": false,
			"kind": "pack_head_group",
			"line_index": 0,
			"text_color": _viewport._get_reading_style().muted_text_color
		})
	]
	return row_data


## A knob in the event-sheet reading: `[number] jump_velocity = 4.5  Upward velocity applied on a jump.`
## The type word leads as a chip (a reader learns WHAT it is, not that GDScript spells it `float`), and
## the @export / group chips are gone - the bar above the row carries the group, and everything inside
## a settings bar is exported by definition.
func _build_reading_variable_row(variable: LocalVariable, description: String, indent: int) -> EventRowData:
	# An @onready node reference is an OBJECT, not a value: it reads as an Object
	# declaration here too, so the head's variable list and the event tree agree.
	var object_row: EventRowData = _build_object_declaration_row(variable, indent)
	if object_row != null:
		return object_row
	# A preloaded scene / script / resource is an OBJECT too, whichever row shape carried it.
	var preload_path: String = preloaded_path(str(variable.default_value))
	if not preload_path.is_empty():
		var preload_row: EventRowData = _build_preload_object_row(
			variable.name, preload_path, indent, variable, "variable_reading_%d" % variable.get_instance_id()
		)
		if preload_row != null:
			return preload_row
	var reading_row: EventRowData = _build_variable_row(
		"tree",
		variable.name,
		variable.type_name,
		variable.default_value,
		indent,
		{
			"is_constant": variable.is_constant,
			"expression_default": variable.expression_default or variable.inferred_type or variable.onready,
			"is_static": variable.is_static,
			"source_resource": variable,
			"row_uid": "variable_reading_%d" % variable.get_instance_id(),
			"code_line": EventSheetCodeEcho.line_for(variable),
			"description": description,
			# The scope word that leads the row, and the Inspector chip that replaced the
			# Settings folder. Both are facts the variable already carries; nothing is re-parsed.
			"reading_scope": _member_scope_key(variable),
			"exported": variable.exported,
			"scope_note": _member_scope_note(variable),
			# The Inspector facts this knob carries: its range and step, its choices, the filter
			# on the file it picks, its colour. Read from what the importer already stored, so the row
			# says what the Inspector would say about the same variable.
			"facts": EventSheetSettingFacts.facts(variable)
		}
	)
	# A property's accessor events belong wherever the variable is listed, and the head's
	# Instance variables folder is where a reader goes to find out what a variable IS.
	_attach_property_accessors(reading_row, variable, indent)
	return reading_row


## The scope word a MEMBER variable of this sheet reads with: Constant, Static, Global on an
## autoload, Field on a Resource script, Instance otherwise.
func _member_scope_key(variable: LocalVariable) -> String:
	var sheet: EventSheetResource = _viewport._sheet
	# A hoisted Static local is a member of the class only because GDScript has nowhere narrower
	# to keep it; what it IS is the local of one event, and that is what the row says.
	if variable.static_local:
		return EventSheetVariableSentence.SCOPE_STATIC_LOCAL
	# The same declaration, read where there are no copies to share it between.
	if variable.is_static and not variable.is_constant and _is_shared_store():
		return EventSheetVariableSentence.SCOPE_SHARED
	return EventSheetVariableSentence.member_scope(
		variable.is_constant,
		variable.is_static,
		sheet != null and is_autoload(sheet),
		sheet != null and EventSheetVariableSentence.is_resource_host(sheet.host_class)
	)


## The one fact a scope adds that its word does not already say: a `static var` is ONE value for
## every copy of the object, which is the whole reason anybody reaches for it (and the whole way it
## surprises a reader who expected one per object). "" for every other scope.
func _member_scope_note(variable: LocalVariable) -> String:
	if not variable.is_static:
		return ""
	if _is_shared_store():
		return EventSheetL10n.translate("one for the whole editor")
	var object_name: String = EventSheetViewportReadingRows.script_object_name(_viewport._sheet)
	if object_name.is_empty():
		return EventSheetL10n.translate("shared by every copy")
	return EventSheetL10n.translate("shared by every %s") % object_name


## The EventFunction a FunctionAnchorRow names, or null when the sheet carries no such verb (the
## anchor then keeps its muted "defined here" stub).
static func find_function_by_name(sheet: EventSheetResource, function_name: String) -> EventFunction:
	if sheet == null:
		return null
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == function_name:
			return entry as EventFunction
	return null


## The verb's one-line description as a muted caption directly ABOVE its Define row - the
## `## @ace_description("…")` the pack author already wrote, which round-tripped through the compiler
## and the lifter without ever being drawn. Falls back to the first non-empty line of the ordinary `##`
## doc comment, so a plain documented helper reads too; null when the verb has neither.
## COMMENT is deliberate: it is the only row type the metrics measure for word wrap, so a full-sentence
## blurb wraps instead of clipping. source_resource stays null so no edit / drag / delete reaches it.
func _build_verb_note_row(event_function: EventFunction, role: String, indent: int) -> EventRowData:
	# The caption is the verb's DESCRIPTION (@ace_description). On a read-only view it falls back to the
	# doc comment's first line so a documented verb still reads; on an EDITABLE sheet the caption is the
	# only place to author @ace_description (the dialog no longer has a Description field), so it must
	# always be editable there - including for a verb that has a doc comment but no description yet. The
	# doc comment still shows (as the caption's starting text), so editing it just promotes that line to
	# the picker description; typing over it sets a distinct one.
	var description: String = event_function.description.strip_edges()
	var editable: bool = _verb_metadata_editable()
	var note: String = description
	if note.is_empty():
		for line: String in event_function.doc_comment.split("\n"):
			if not line.strip_edges().is_empty():
				note = line.strip_edges()
				break
	var placeholder: bool = note.is_empty()
	# Nothing to show and nowhere to add it (a read-only preview) - no caption at all.
	if placeholder and not editable:
		return null
	if placeholder:
		note = EventSheetL10n.translate("+ describe this function")
	var accent: Color = (_define_role_colors(role) as Array)[1]
	# The caption's band is a quieter echo of its verb's wash (70% of it), so the pair reads as one
	# block with the prose sitting behind the row it describes.
	var row_data: EventRowData = build_caption_row(
		note, indent, "verb_note_%s" % event_function.function_name.strip_edges(),
		Color(accent.r, accent.g, accent.b, _verb_tint_strength() * 0.7)
	)
	row_data.disabled = not event_function.enabled
	# Inline-edit the description on an authored sheet - double-click the caption. The caption is a
	# COMMENT row whose source is the EventFunction: the delete path already treats a function source as
	# non-locatable (it lives in sheet.functions), so the caption cannot be deleted, and a COMMENT row is
	# never a drag zone - so pointing it at the function is safe.
	if editable:
		row_data.source_resource = event_function
		var span: SemanticSpan = row_data.spans[0]
		var meta: Dictionary = span.metadata if span.metadata is Dictionary else {}
		meta["editable"] = true
		meta["edit_kind"] = "verb_description"
		if placeholder:
			meta["edit_placeholder"] = true
			meta["text_color"] = _viewport._get_reading_style().muted_text_color
		span.metadata = meta
	return row_data


## A muted, wrapping CAPTION row welded to the row directly below it - the "one line of prose above the
## thing it describes" pattern, which a published verb uses for its @ace_description. COMMENT is the row
## type on purpose: it is the only one the metrics measure for word wrap, so a full sentence wraps
## instead of clipping. source_resource stays null (there is no CommentRow behind it), so no edit / drag
## / delete reaches it, and attached_below welds it to its subject so the block gap opens ABOVE the pair.
func build_caption_row(text: String, indent: int, row_uid: String, accent: Color = Color(0, 0, 0, 0)) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.COMMENT
	row_data.source_resource = null
	row_data.row_uid = row_uid
	row_data.attached_below = true
	row_data.custom_color = accent
	row_data.spans = [
		_make_span(text, SemanticSpan.SpanType.COMMENT, {
			"editable": false,
			"kind": "caption",
			"text_color": _viewport._get_event_style().comment_text_color
		})
	]
	return row_data


## Appends a condition-style CELL to a row: a filled chip whose LABEL leads it (the bold lead a
## condition uses for its object) and whose TEXT says what the slot holds, stacked one per line down the
## condition lane. This is the grammar a published verb's parameters use, so any construct with named
## slots reads identically. `metadata` merges over the defaults - carry a `kind` and an index there so a
## click can route back to whatever the cell names. Returns the same row, so calls chain.
func append_field_cell(row_data: EventRowData, label: String, text: String, metadata: Dictionary = {}) -> EventRowData:
	if row_data == null:
		return row_data
	# Only derive the next free line when the caller has NOT already decided one - the verb-parameter
	# path passes an explicit line_index that would overwrite whatever this computed, so scanning every
	# existing span per cell was quadratic work thrown away.
	var next_line: int = 0
	if not metadata.has("line_index"):
		for span: SemanticSpan in row_data.spans:
			var existing: Dictionary = span.metadata if span.metadata is Dictionary else {}
			if str(existing.get("lane", "condition")) == "condition":
				next_line = maxi(next_line, int(existing.get("line_index", 0)) + 1)
	var cell_meta: Dictionary = {
		"lane": "condition",
		"kind": "field_cell",
		"chip": true,
		"line_index": next_line,
		"object_label": label
	}.merged(_viewport._build_element_style_metadata(_viewport._get_condition_style()), true)
	cell_meta.merge(metadata, true)
	row_data.spans.append(_make_span(text, SemanticSpan.SpanType.CONDITION, cell_meta))
	return row_data


## The [background, accent] pair a published verb's role paints with, from the PALETTE - the fallback
## used when there is no live style to read (a headless build, a null style). Kept static because the
## function dialog and other style-less callers use it directly.
static func define_role_badge_colors(role: String) -> Array:
	match role:
		"condition":
			return [EventSheetPalette.COLOR_ACE_CONDITION_BADGE_BG, EventSheetPalette.COLOR_ACE_CONDITION_BADGE_FG]
		"expression":
			return [EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_BG, EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_FG]
	return [EventSheetPalette.COLOR_ACE_ACTION_BADGE_BG, EventSheetPalette.COLOR_ACE_ACTION_BADGE_FG]


## The [background, accent] pair for a role, read from the LIVE THEME so a restyle reaches every
## surface the role drives (badge, verb name tint, row wash, accent bar, caption band). Falls back to
## the palette pair when no style is loaded.
func _define_role_colors(role: String) -> Array:
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	if event_style == null:
		return define_role_badge_colors(role)
	match role:
		"condition":
			return [event_style.ace_condition_badge_background_color, event_style.ace_condition_accent_color]
		"expression":
			return [event_style.ace_expression_badge_background_color, event_style.ace_expression_accent_color]
	return [event_style.ace_action_badge_background_color, event_style.ace_action_accent_color]


## How loud the role tint is, from the theme. Zero (the shipped default) means a published verb draws
## as an ordinary event row - no wash, no accent bar - which is the point: it IS an ordinary event row.
func _verb_tint_strength() -> float:
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	return event_style.verb_row_tint_strength if event_style != null else 0.0


## True when a verb's picker metadata (name, description, category) may be edited inline on its row -
## the same gate the "+ Add parameter" cell uses: any sheet that is not read-only. A read-only preview
## edits nothing, so it must not grow affordances it cannot honour.
func _verb_metadata_editable() -> bool:
	var sheet: EventSheetResource = _viewport._sheet
	return sheet != null and not sheet.read_only


## True when the sheet is being READ rather than authored: an opened .gd preview (read_only, the safe
## default when a pack opens as a sheet) or the Simple pill's Reading Mode lens. In that state a
## published verb draws as an event-sheet Function block - ƒ, its name, its inputs, nothing else - and its
## picker metadata lives one click away in the ACE properties popup instead of on the row. Pure view
## state: no resource, no emission and no fold is touched by it.
func _verb_reading_mode() -> bool:
	return bool(_viewport.is_reading_mode())


## True when this view must draw NO add-a-row scaffolding: a documentation figure (an illustration, so
## a "+ Add condition" is a click target that does nothing) or a READ-ONLY preview - a pack opened just
## to read, where every add affordance is an offer the view cannot honour. _count_event_lines mirrors
## this exactly, so the measured height matches the spans that actually get built.
func _scaffolding_suppressed() -> bool:
	if bool(_viewport.figure_mode):
		return true
	var sheet: EventSheetResource = _viewport._sheet
	return sheet != null and sheet.read_only


## True when a `##` line is one of the plugin's own `@ace_*` annotations. Those lines are METADATA -
## they already read as the verb's kind, name, category and description - so printing them as prose
## next to the row they configure is noise a reader has no way to interpret. Every surface
## that turns doc comments into captions filters through here.
static func is_ace_annotation_line(line: String) -> bool:
	return strip_comment_prefix(line).strip_edges().begins_with("@ace_")


## The first real sentence of a function's doc comment - the caption a helper wears in its RIGHT lane,
## because a doc comment is exactly how a reader takes in a function they did not write. Empty
## when the function is undocumented or documented only with `@ace_*` annotation lines.
static func helper_doc_line(event_function: EventFunction) -> String:
	for line: String in event_function.doc_comment.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty() or is_ace_annotation_line(trimmed):
			continue
		return strip_comment_prefix(trimmed).strip_edges()
	return ""


## The [background, foreground] pair the ACTION-lane chips paint with, from the theme.
func _verb_chip_colors() -> Array:
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	if event_style == null:
		return [_viewport._get_reading_style().plain_chip_background_color, _viewport._get_reading_style().plain_chip_foreground_color]
	return [event_style.verb_chip_background_color, event_style.verb_chip_foreground_color]


## Which verb kind a function publishes as, by its return type: void does something (Action),
## bool answers a question (Condition), any other value is handed out (Expression). This mirrors
## the ACE Studio's three cards, so the row badge always matches the card that would edit it.
static func define_role_for(event_function: EventFunction) -> String:
	if event_function.return_type == TYPE_NIL:
		return "action"
	if event_function.return_type == TYPE_BOOL:
		return "condition"
	return "expression"


## Humanizes one parameter for reading: an authored display name wins, else the id with underscores
## opened out ("from_x" -> "from x"). This is the label a published-verb row shows, not a value.
static func friendly_param_label(param: ACEParam) -> String:
	var label: String = param.get_param_name().strip_edges()
	if label.is_empty():
		label = param.id
	return label.replace("_", " ").strip_edges()


## What ONE parameter chip on a function's header says: its friendly label, plus the value a
## caller gets when it leaves the input out, plus the ellipsis that marks the one input which
## swallows however many values follow it.
##
## A default is part of the SIGNATURE, not decoration: `Heal [amount = 10]` is the difference between
## a verb a reader may call with nothing and one they may not, and it is the value the picker
## pre-fills. `null` reads as the sheet's word for nothing, because that is the word every other row
## on the sheet uses for it.
static func verb_param_chip_text(param: ACEParam) -> String:
	var label: String = friendly_param_label(param)
	if _is_varargs_param(param):
		return "%s …" % label
	var fallback: String = str(param.default_value).strip_edges()
	if fallback.is_empty():
		return label
	if fallback == "null":
		fallback = EventSheetL10n.translate("empty")
	return "%s = %s" % [label, fallback]


## True for the one parameter that stands for "and however many more" - a list-typed input the
## author named `args`. Godot has no varargs in a script function, and this is the shape every script
## that wants them writes, so it is the only one the ellipsis is claimed for.
static func _is_varargs_param(param: ACEParam) -> bool:
	return param.id.strip_edges() == "args" and param.type_name.strip_edges() == "Array"


## The auto verb line's parameter slice - each param's friendly label, comma-joined ("from x, from y,
## width, color"). Empty when the verb takes none. Falls back to the legacy `parameters` string alias
## when a lifted verb carries no ACEParam metadata.
static func friendly_param_labels(event_function: EventFunction) -> String:
	var labels: PackedStringArray = PackedStringArray()
	for param: Variant in event_function.params:
		if param is ACEParam:
			labels.append(friendly_param_label(param as ACEParam))
	if labels.is_empty():
		for legacy: String in event_function.parameters:
			labels.append(str(legacy).replace("_", " ").strip_edges())
	return ", ".join(labels)


## A parameter's declared type read as plain words, not a GDScript type name: "String" -> "text",
## "int"/"float" -> "number", "bool" -> "true/false", "Vector2"/"Vector3" -> "point", Node classes
## and anything else pass through. So a reader with no coding knowledge learns what each input IS.
##
## A bool reads "true/false" rather than "yes/no": those ARE the two words a sheet author types into
## the field and the two GDScript emits, so the row teaches the literal they will actually use. The
## other words stay plain, because "text" and "number" cost a reader nothing that "String" and "int"
## would give them.
## These words are DRAWN on the canvas, which auto-translation never reaches (it only touches Control
## properties), so each one resolves explicitly. A type name with no plain word passes through as-is -
## a class called HealthPool is the author's own noun and translating it would be wrong.
static func friendly_type_word(type_name: String) -> String:
	match type_name.strip_edges():
		"String", "StringName":
			return EventSheetL10n.translate("text")
		"float":
			return EventSheetL10n.translate("number")
		"int":
			# A declared `int` is the one number that REFUSES a fraction, and that is the whole
			# fact a reader needs about it. An undeclared `100` still reads "number": nothing in the
			# line said the author cared, and "whole number" would be putting words in their mouth.
			return EventSheetL10n.translate("whole number")
		"bool":
			return EventSheetL10n.translate("boolean")
		"Vector2", "Vector3", "Vector4":
			return EventSheetL10n.translate("vector")
		"Color":
			return EventSheetL10n.translate("color")
		"PackedScene":
			return EventSheetL10n.translate("scene")
		"Array":
			return EventSheetL10n.translate("list")
		"Dictionary":
			return EventSheetL10n.translate("table")
		"Callable":
			return EventSheetL10n.translate("function")
		"Signal":
			return EventSheetL10n.translate("signal")
		"", "Variant":
			return EventSheetL10n.translate("any")
		_:
			var bare_type: String = type_name.strip_edges()
			# A collection says WHAT IT HOLDS, because that is the whole question a reader has about
			# one: `Array[String]` is a list of text, `PackedVector2Array` a list of points. The
			# element word is the same vocabulary the rest of the row uses, pluralised, so the two
			# readings never drift apart. A Packed*Array is spelled as the Array it behaves like
			# first, so one rule covers both spellings.
			var element_type: String = _array_element_type(bare_type)
			if not element_type.is_empty():
				return EventSheetL10n.translate("list of %s") % _plural_type_word(element_type)
			if bare_type.begins_with("Array[") and bare_type.ends_with("]"):
				return EventSheetL10n.translate("list")
			# Every Node class is one word to a reader: a node. The specific class is what the picker
			# and the tooltip say; on a row it is the KIND of thing that matters. Derived from ClassDB
			# rather than a list, so a class the engine adds tomorrow reads right with no edit here.
			if ClassDB.class_exists(bare_type) and ClassDB.is_parent_class(bare_type, "Node"):
				return EventSheetL10n.translate("object")
			# A Resource subclass keeps its class name: `StatSheet` IS the noun the author chose, and
			# "resource" would tell a reader strictly less than the name already does.
			return bare_type


## The element type a collection type name holds ("Array[String]" / "PackedStringArray" -> "String"),
## or "" when the type is not a collection or holds no declared element type (a bare `Array`).
## Packed*Array is normalised to its Array[...] equivalent so both spellings read the same.
static func _array_element_type(type_name: String) -> String:
	match type_name:
		"PackedStringArray":
			return "String"
		"PackedInt32Array", "PackedInt64Array", "PackedByteArray":
			return "int"
		"PackedFloat32Array", "PackedFloat64Array":
			return "float"
		"PackedVector2Array":
			return "Vector2"
		"PackedVector3Array", "PackedVector4Array":
			return "Vector3"
		"PackedColorArray":
			return "Color"
	if type_name.begins_with("Array[") and type_name.ends_with("]"):
		return type_name.substr(6, type_name.length() - 7).strip_edges()
	return ""


## The plural of a friendly type word, for "list of …". Only the words a collection actually reads
## with are spelled out; anything else (a class name) is already the noun the author chose and is
## repeated as-is, because inventing an English plural for `StatSheet` would be a guess.
static func _plural_type_word(type_name: String) -> String:
	match type_name.strip_edges():
		"String", "StringName":
			return EventSheetL10n.translate("text")
		"int", "float":
			return EventSheetL10n.translate("numbers")
		"bool":
			return EventSheetL10n.translate("booleans")
		"Vector2", "Vector3", "Vector4":
			return EventSheetL10n.translate("vectors")
		"Color":
			return EventSheetL10n.translate("colors")
		"Dictionary":
			return EventSheetL10n.translate("tables")
		_:
			var bare_type: String = type_name.strip_edges()
			if ClassDB.class_exists(bare_type) and ClassDB.is_parent_class(bare_type, "Node"):
				return EventSheetL10n.translate("objects")
			return bare_type


## The return type read as plain words - the label the "gives back …" chip shows.
static func _friendly_return_type(event_function: EventFunction) -> String:
	return friendly_type_word(SheetCompiler._function_return_type_name(event_function))


## Appends first-class typed parameter spans to a Define row: each parameter as `name : friendly-type`
## (the variable-row grammar), so the row reads "Create Ability · id : text" rather than a raw
## `func create_ability(id: String)` signature. A ONE-input verb keeps its parameter inline on the verb's
## own line; two or more STACK one per line beneath it, so a six-input verb reads as a list instead of a
## sentence that runs off the row. An optional parameter also shows its ` = default`. Types come from
## ACEParam.type_name; a legacy lifted verb with only string parameter names shows the names alone.
## Returns the last condition-lane line index used, so the caller can size the row.
func _append_define_param_spans(spans: Array[SemanticSpan], event_function: EventFunction, verb_line: int) -> int:
	var value_color: Color = _viewport._get_event_style().value_highlight_color
	var typed_params: Array[ACEParam] = []
	for param: Variant in event_function.params:
		if param is ACEParam:
			typed_params.append(param as ACEParam)
	if typed_params.is_empty():
		# Legacy lifted verb (no ACEParam metadata): show the bare friendly names.
		var legacy_labels: String = friendly_param_labels(event_function)
		if not legacy_labels.is_empty():
			spans.append(_make_span(legacy_labels, SemanticSpan.SpanType.VALUE, {
				"editable": false, "kind": "define_function",
				"lane": "condition", "line_index": verb_line, "text_color": value_color
			}))
		return verb_line
	# Each parameter is its OWN cell, in the shared field-cell grammar (the same one a condition cell
	# uses): the parameter's name leads the chip, its text says what it accepts. Clicking one opens the
	# verb's editor focused on that parameter, exactly as clicking a condition opens its editor. Built
	# through the public append_field_cell primitive so the built-in path and an extension's path are
	# literally the same code.
	var cell_host := EventRowData.new()
	for index in range(typed_params.size()):
		var param: ACEParam = typed_params[index]
		var cell_text: String = _define_param_type_word(param)
		var default_text: String = param.gdscript_default.strip_edges()
		if not default_text.is_empty():
			cell_text += " = %s" % default_text
		append_field_cell(cell_host, friendly_param_label(param), cell_text, {
			"kind": "verb_param",
			"param_index": index,
			"line_index": verb_line + 1 + index
		})
	spans.append_array(cell_host.spans)
	return verb_line + typed_params.size()


## A parameter's type read as plain words. A param with a fixed option list reads as the CHOICES it
## accepts ("one of (fade, slide)") rather than the bare "text" its GDScript type would say, because
## the choices are what the caller actually needs to know.
static func _define_param_type_word(param: ACEParam) -> String:
	if not param.options.is_empty():
		var labels: PackedStringArray = PackedStringArray()
		for option: Variant in param.options:
			if option is Dictionary:
				var option_dict: Dictionary = option as Dictionary
				labels.append(str(option_dict.get("label", option_dict.get("key", ""))))
			else:
				labels.append(str(option))
		if not labels.is_empty():
			return "one of (%s)" % ", ".join(labels)
	return friendly_type_word(param.type_name)


## One chip on a Define row's ACTION lane (category, return, waits / static / internal / featured) - the
## same badge grammar the row's role badge uses, on the lane that reads as "and what do I get back?".
func _define_chip(text: String, background: Color, foreground: Color, line_index: int,
		kind: String = "define_function") -> SemanticSpan:
	return _make_span(text, SemanticSpan.SpanType.KEYWORD, {
		"editable": false,
		"badge": true,
		"badge_style": "scope",
		"badge_bg": background,
		"badge_fg": foreground,
		"kind": kind,
		"lane": "action",
		"line_index": line_index
	})


## An authored @ace_display_template with its {param_id} slots filled with the FRIENDLY LABELS (a
## Define row shows the verb's shape, not call-site values): "Draw line from ({from_x}, {from_y})" ->
## "Draw line from (from x, from y)". Empty when the verb has no display_template.
static func friendly_template_line(event_function: EventFunction) -> String:
	var template: String = event_function.display_template.strip_edges()
	if template.is_empty():
		return ""
	for param: Variant in event_function.params:
		if param is ACEParam:
			var ace_param: ACEParam = param as ACEParam
			template = template.replace("{%s}" % ace_param.id, friendly_param_label(ace_param))
	return template


## True when every non-blank line of a code block is a comment (# or ##). Such a block reads as a note,
## so it renders as a comment (no code badge, leading # dropped) instead of a GDScript block.
static func is_comment_only_block(code_lines: PackedStringArray) -> bool:
	var saw_comment: bool = false
	for line: String in code_lines:
		var stripped: String = line.strip_edges()
		if stripped.is_empty():
			continue
		if not stripped.begins_with("#"):
			return false
		saw_comment = true
	return saw_comment


## True when a code block is entirely blank lines - a round-trip spacing separator. It carries bytes
## (so it must not be dropped) but is not real code, so it renders as quiet empty space with NO
## "GDScript" badge, instead of an empty pill.
static func is_blank_block(code_lines: PackedStringArray) -> bool:
	for line: String in code_lines:
		if not line.strip_edges().is_empty():
			return false
	return true


## Drops the leading # / ## (and one following space) from a comment line for DISPLAY only - the row's
## raw code stays the serialization truth. "## On: the canvas..." -> "On: the canvas...".
static func strip_comment_prefix(line: String) -> String:
	var body: String = line.strip_edges()
	var hashes: int = 0
	while hashes < body.length() and body[hashes] == "#":
		hashes += 1
	body = body.substr(hashes)
	if body.begins_with(" "):
		body = body.substr(1)
	return body


## A subtle per-role tint for a published-verb name - the object label lerped toward the role's badge
## accent, so Action / Condition / Expression read distinctly without a loud colour.
func _define_role_name_color(role: String) -> Color:
	# The object label lerped toward the ROLE'S THEMED accent, so restyling a role moves its verb names
	# with its badge. The 0.55 strength stays a literal - it is a de-emphasis ratio against
	# object_label_color (itself a token), not a colour choice.
	return _viewport._get_event_style().object_label_color.lerp((_define_role_colors(role) as Array)[1], 0.55)


## One Define block, as a real two-lane event row rather than a spec-sheet line. The CONDITION lane
## carries what the verb IS - its role badge in the ACE-role colour, the friendly published name (or an
## authored display template), and its typed inputs. The ACTION lane carries what it HANDS BACK - the
## category chip, a "gives back <type>" chip for value-returning verbs, the async / static / internal /
## featured markers, and the step count that doubles as the fold affordance. The role badge is the only
## kind cue by default: a wash of the role accent plus a left accent bar is available behind the theme's
## verb_row_tint_strength, but it ships at 0.0, because tinting every verb turned a pack into a wall of
## coloured blocks. Pure READ view of sheet.functions - nothing here writes to the sheet.
func _build_define_function_row(event_function: EventFunction, indent: int) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.EVENT
	row_data.source_resource = event_function
	# Name-keyed uid (keeping the define_fn_ prefix every consumer matches) so an expanded body survives the
	# undo funnel's resource-replacement rebuild - an instance-id uid would reset the fold on every edit.
	var fold_key: String = event_function.function_name.strip_edges()
	row_data.row_uid = "define_fn_%s" % (fold_key if not fold_key.is_empty() else str(event_function.get_instance_id()))
	row_data.disabled = not event_function.enabled
	var role: String = define_role_for(event_function)
	var badge_colors: Array = _define_role_colors(role)
	# The whole verb reads as an event-sheet block tinted by its ACE kind: a wash of the role's
	# accent behind the row (drawn by the renderer, which takes its strength from this alpha) plus a left
	# accent bar, so Action / Condition / Expression are distinguishable at a glance, not only by the
	# badge word. The alpha IS the theme's verb_row_tint_strength - the renderer reads it back off
	# custom_color rather than keeping a second literal that could drift out of step with this one.
	var role_accent: Color = badge_colors[1]
	row_data.custom_color = Color(role_accent.r, role_accent.g, role_accent.b, _verb_tint_strength())
	var display_name: String = event_function.ace_display_name.strip_edges()
	if display_name.is_empty():
		display_name = event_function.function_name.capitalize()
	var chip_bg: Color = _verb_chip_colors()[0]
	var chip_fg: Color = _verb_chip_colors()[1]
	# The de-emphasised chips (static / internal) are the chip pair mixed toward its own background, so
	# they read as quieter WITHOUT a second theme token.
	var muted: Color = chip_fg.lerp(chip_bg, 0.45)
	# READING MODE: the verb reads as an event-sheet Function block - ƒ, its name, one chip per input, and
	# nothing else. Its kind survives as the header's wash (the role accent at VERB_KIND_TINT_ALPHA),
	# and every other property it has - category, description, what it gives back, whether it is
	# featured, the line it inserts - lives one click away in the ACE properties popup.
	if _verb_reading_mode():
		row_data.custom_color = Color(
			role_accent.r, role_accent.g, role_accent.b,
			maxf(_verb_tint_strength(), VERB_KIND_TINT_ALPHA)
		)
		row_data.spans = _build_verb_function_block_spans(event_function, role, display_name)
		_append_verb_body_rows(row_data, event_function, indent, display_name)
		row_data.line_count = 1
		# The name is a trigger cell now, so the body's first step belongs BESIDE it - the way every
		# other event puts "when this happens" on the left and "do this" on the right. Without the
		# merge the reading would carry the one empty condition cell in the whole sheet.
		_merge_first_body_step_into_header(row_data)
		# With something in the right lane the row is an ordinary two-lane event. Only a header that
		# ended up with an empty right lane (an empty body) keeps the whole row for its chips.
		row_data.full_width_lanes = not _has_action_lane_span(row_data.spans)
		return row_data
	var spans: Array[SemanticSpan] = [
		_make_span(EventSheetL10n.translate(role.capitalize()), SemanticSpan.SpanType.KEYWORD, {
			"editable": false,
			"badge": true,
			"badge_style": "scope",
			"badge_bg": badge_colors[0],
			"badge_fg": badge_colors[1],
			# The role WORD is the kind cue, so it keeps its measured width instead of snapping to the
			# narrow badge column a condition row's single-glyph badge uses - "Condition" would clip.
			"badge_natural_width": true,
			"kind": "define_function",
			"lane": "condition",
			"line_index": 0
		})
	]
	# One word says this function is not one the sheet CALLS: a `@rpc` function arrives,
	# sent by another peer, and a visibility filter is asked, per player, by a synchronizer. The word
	# leads the name the way a variable row's scope word leads its own.
	var role_word: String = _function_role_word(event_function)
	if not role_word.is_empty():
		spans.append(_make_span(role_word, SemanticSpan.SpanType.KEYWORD, {
			"editable": false,
			"kind": "define_function",
			"role_word": true,
			"lane": "condition",
			"line_index": 0,
			"natural_width": true,
			"text_color": _viewport._get_reading_style().muted_text_color
		}))
	# The verb reads as an event-sheet line, NOT a raw signature: an authored @ace_display_template is
	# the whole sentence (its {param} slots filled with each parameter's label); otherwise the friendly
	# name plus first-class typed parameter chips (`name : Type`, the same grammar a variable row uses).
	# There is deliberately no trailing `func ... -> Type` code cue - the whole point is that a reader with
	# no GDScript knowledge sees the abstraction (verb, its inputs, what it hands back), not the code.
	# Slight per-role tint on the verb name so an Action / Condition / Expression reads distinctly at a
	# glance among the inline verb rows (reinforces the role badge without a loud colour).
	var name_color: Color = _define_role_name_color(role)
	var authored_line: String = friendly_template_line(event_function)
	var condition_lines: int = 1
	if not authored_line.is_empty():
		spans.append(_make_span(authored_line, SemanticSpan.SpanType.OBJECT, {
			"kind": "define_function",
			"lane": "condition",
			"line_index": 0,
			"text_color": name_color
		}))
	else:
		# The name is the verb's DISPLAY NAME, edited inline (double-click) on an authored sheet - the
		# same field the old dialog's "Display name" box set. Clearing it falls the row and compiler back
		# to the function name. Not editable on a read-only preview, and not on an authored @ace_display_-
		# template line (that whole-sentence form is a GDScript concern), so only this plain branch opts in.
		var name_meta: Dictionary = {
			"kind": "define_function",
			"lane": "condition",
			"line_index": 0,
			"text_color": name_color
		}
		if _verb_metadata_editable():
			name_meta["editable"] = true
			name_meta["edit_kind"] = "verb_display_name"
		spans.append(_make_span(display_name, SemanticSpan.SpanType.OBJECT, name_meta))
		condition_lines = _append_define_param_spans(spans, event_function, 0) + 1
		# The mirror of "+ Add condition": adding an argument is the core authoring gesture on a verb, so
		# it lives on the row - and since the verb dialog no longer carries a parameter list, this IS the
		# way in. It must therefore appear wherever the dialog used to, which includes a .gd-backed sheet
		# (the default format, where external_source_path is always set). Only a read-only sheet is
		# excluded: it edits nothing, so it must not grow an affordance it cannot honour. Editing a
		# verb's SIGNATURE is not the same as editing an opened pack's body - the body stays a read view
		# behind its own per-function opt-in, while the signature has always been editable from here.
		var owning_sheet: EventSheetResource = _viewport._sheet
		if owning_sheet != null and not owning_sheet.read_only:
			var add_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
			var add_color: Color = add_style_meta.get("text_color", _viewport._get_condition_style().text_color)
			add_color.a *= 0.55
			spans.append(_make_span(
				EventSheetL10n.translate("+ Add parameter"),
				SemanticSpan.SpanType.CONDITION,
				{
					"editable": false,
					"kind": "verb_param_add",
					"lane": "condition",
					"line_index": condition_lines,
					"text_color": add_color
				}
			))
			condition_lines += 1
	# The ACTION lane answers "and what do I get back?": the value it hands over (a Condition answers a
	# question and an Expression yields a value, so the type shows as a "gives back Type" chip - a void
	# Action returns nothing and shows none), then the markers that change how it is CALLED (waits =
	# async) or who may call it (internal = not published as an ACE).
	if role != "action":
		spans.append(_define_chip(EventSheetL10n.translate("gives back %s") % _friendly_return_type(event_function), chip_bg, chip_fg, 0))
	if event_function.is_async:
		spans.append(_define_chip(EventSheetL10n.translate("waits"), chip_bg, chip_fg, 0))
	if event_function.is_static:
		# `static` is GDScript's word; the sheet's word for a function that belongs to the class
		# rather than to any one object is `shared`, and the define row says the same word the reading
		# does.
		spans.append(_define_chip(EventSheetL10n.translate("shared"), chip_bg, muted, 0))
	if not event_function.expose_as_ace:
		spans.append(_define_chip(EventSheetL10n.translate("internal"), chip_bg, muted, 0))
	if event_function.featured:
		spans.append(_define_chip(EventSheetL10n.translate("★ featured"), chip_bg, chip_fg, 0))
	# The picker CATEGORY as a muted, double-click-editable chip - the old dialog's "Picker category" box,
	# now on the row. Only for a PUBLISHED verb on an authored sheet (an unpublished helper has no picker
	# entry to file, and a read view must not offer an edit): an unset category shows a faint "+ category"
	# placeholder. Kept muted so a pack filing every verb under one word does not read as a wall of chips.
	if event_function.expose_as_ace and _verb_metadata_editable():
		var category: String = event_function.ace_category.strip_edges()
		var category_meta: Dictionary = {
			"editable": true,
			"badge": true,
			"badge_style": "scope",
			"badge_bg": chip_bg,
			"badge_fg": muted if category.is_empty() else chip_fg,
			"kind": "define_function",
			"edit_kind": "verb_category",
			"lane": "action",
			"line_index": 0
		}
		if category.is_empty():
			category_meta["edit_placeholder"] = true
		spans.append(_make_span(
			category if not category.is_empty() else EventSheetL10n.translate("+ category"),
			SemanticSpan.SpanType.KEYWORD, category_meta))
	_append_message_spans(spans, event_function)
	row_data.spans = spans
	_append_verb_body_rows(row_data, event_function, indent, display_name)
	row_data.line_count = maxi(condition_lines, 1)
	return row_data


## What the last headless run said about one Check row, or null when this test has not been run
## in this session (and the row is then marked with nothing at all).
func _check_row_verdict(check_label: String) -> Variant:
	if check_label.is_empty() or _viewport._sheet == null:
		return null
	return EventSheetEditorToolBar.check_verdict(_viewport._sheet.external_source_path, check_label)


## The sentence a function reads as when one of the project's ANIMATIONS calls it, "" when no
## animation does. The animation's own clip name rides in the sentence, because "which animation" is
## the first thing a reader of a hit frame wants and the script cannot say it.
##
## Only ever asked about a function whose name is spelled like a handler, so an ordinary sheet full of
## verbs never pays for the scan at all - and a sheet that IS full of handlers pays for it once.
func _animation_event_sentence(event_function: EventFunction) -> String:
	if event_function == null:
		return ""
	var name: String = event_function.function_name.strip_edges()
	if not name.begins_with("_on_"):
		return ""
	var tracks: Dictionary = EventSheetAnimationTrackFacts.by_method()
	if not tracks.has(name):
		return ""
	var track: Dictionary = tracks[name]
	var words: String = EventSheetAnimationTrackFacts.event_words(name)
	var clip: String = str(track.get("animation", "")).strip_edges()
	_note_pattern("sprite_animation", "%s -> %s" % [clip, name])
	# Translated HERE, where the pattern is still a pattern: what leaves this function is the finished
	# line, which the span builder then hands to the catalog again and gets back unchanged.
	if clip.is_empty():
		return EventSheetL10n.translate("On animation event {event}").replace(
			"{event}", "\"%s\"" % words)
	return EventSheetL10n.translate("On animation event {event} of {animation}").replace(
		"{event}", "\"%s\"" % words).replace("{animation}", "\"%s\"" % clip)


## Which object a function reads its trigger under. A test's `run` and a command tool's
## `_init` are what the file EXISTS to do and the runner calls them by name, so they belong to Test
## and to Command tool. Every other function is a helper this sheet calls, and stays under Functions.
func _verb_trigger_object(event_function: EventFunction) -> String:
	match _tool_file_entry_kind(event_function):
		EventSheetToolFiles.KIND_TEST_SHEET:
			return EventSheetL10n.translate(EventSheetToolFiles.OBJECT_TEST)
		EventSheetToolFiles.KIND_COMMAND_TOOL:
			return EventSheetL10n.translate(EventSheetToolFiles.OBJECT_COMMAND_TOOL)
	return EventSheetL10n.translate("Functions")


## The words after "On" for the same two entry points, and they are the same words: both files are
## RUN. A command tool's entry is spelled `_init` because that is when a main loop starts, and a
## test's is spelled `run` because that is what the runner calls - one thing, said once.
func _verb_trigger_name(event_function: EventFunction, display_name: String) -> String:
	if _tool_file_entry_kind(event_function).is_empty():
		return display_name
	return EventSheetL10n.translate("run")


## "" unless this function IS the open tooling file's entry point - the name and the file kind have to
## agree, so a test's own `_init` and a command tool's own `run` helper both stay under Functions.
func _tool_file_entry_kind(event_function: EventFunction) -> String:
	if event_function == null:
		return ""
	var kind: String = str(sentence_context().get("tool_file_kind", ""))
	var name: String = event_function.function_name.strip_edges()
	if kind == EventSheetToolFiles.KIND_TEST_SHEET and name == EventSheetToolFiles.TEST_ENTRY_NAME:
		return kind
	if kind == EventSheetToolFiles.KIND_COMMAND_TOOL and name == EventSheetToolFiles.COMMAND_ENTRY_NAME:
		return kind
	return ""


## True when any span of a row sits in the ACTION lane - i.e. the row's right half carries something.
static func _has_action_lane_span(spans: Array[SemanticSpan]) -> bool:
	for span: SemanticSpan in spans:
		if span != null and span.metadata is Dictionary and str((span.metadata as Dictionary).get("lane", "")) == "action":
			return true
	return false


## ƒ + the verb's DISPLAY NAME + one chip per input, and nothing else - the event-sheet Function block
## header a pack reads as in Reading mode. A display name written with the plugin's BBCode-lite
## (`Take [b]amount[/b] damage`) draws STYLED: the span carries the stripped text plus the parsed
## segments the renderer paints, so the tags themselves are never printed. An unpublished helper adds
## the one caption a reader takes a function in by - its doc comment - in the RIGHT lane, muted.
func _build_verb_function_block_spans(event_function: EventFunction, role: String, display_name: String) -> Array[SemanticSpan]:
	# ────────────────────────────────────────────────────────────────────────────────────────────
	# On a script that extends one of the editor's plugin classes, some of these functions are not
	# the author's verbs at all: they are the questions and the events the EDITOR calls, and reading
	# them as "ƒ On parse property" tells a reader nothing they can act on. Named here, keyed only
	# off the class the file extends and the function's own name - the reading changes, the sheet
	# does not.
	var editor_callback: Dictionary = EventSheetEditorPluginWords.callback_for(
		_editor_plugin_class(), event_function.function_name)
	if not editor_callback.is_empty():
		return _build_editor_callback_spans(event_function, str(editor_callback.get("text", "")))
	# ────────────────────────────────────────────────────────────────────────────────────────────
	# A function an ANIMATION calls is not a helper this sheet calls itself, it is an event: the
	# animation's method track names it, and the moment the play head reaches that key the engine
	# calls it. Nothing in the script says so - which is exactly why the sheet has to.
	var animation_event: String = _animation_event_sentence(event_function)
	if not animation_event.is_empty():
		return _build_editor_callback_spans(event_function, animation_event,
			EventSheetSentence.script_object(sentence_context()))
	var badge_colors: Array = _define_role_colors(role)
	var name_color: Color = _define_role_name_color(role)
	var spans: Array[SemanticSpan] = [
		_make_span("ƒ", SemanticSpan.SpanType.KEYWORD, {
			"editable": false,
			"badge": true,
			"badge_style": "scope",
			"badge_bg": badge_colors[0],
			"badge_fg": badge_colors[1],
			"kind": "define_function",
			"lane": "condition",
			"line_index": 0
		})
	]
	# The condition lane answers "when does this run?" on every other event; a function's answer is
	# "when it is called", so the name reads there as the trigger it is - Functions ▸ On <name>.
	var name_meta: Dictionary = {
		"editable": false,
		"kind": "define_function",
		"lane": "condition",
		"line_index": 0,
		"chip": true,
		# ── lens hook ─────────────────────────────────────────────────────────────────────────
		# A test's `run` and a command tool's `_init` are not helpers something else calls: they are
		# the one thing the file is FOR, and the runner calls them. So they read under the object
		# that runs them - Test ▸ On run, Command tool ▸ On run - rather than under Functions.
		"object_label": _verb_trigger_object(event_function),
		"text_color": name_color
	}
	var plain_name: String = _verb_trigger_name(event_function, display_name)
	if EventSheetBBCodeLite.has_markup(display_name):
		plain_name = EventSheetBBCodeLite.strip(display_name)
		name_meta["bbcode_segments"] = EventSheetBBCodeLite.parse(display_name, name_color)
	# A function marked `@rpc` is not one this peer calls: it ARRIVES, sent by another peer,
	# and a visibility filter is ASKED, once per player, by a synchronizer. So the word between "On"
	# and the name says which kind of arrival this head stands for.
	var arrival: String = EventSheetL10n.translate("On")
	if EventSheetMessageFacts.is_message(event_function):
		arrival = EventSheetL10n.translate("On message")
	elif not _visibility_filter_entry(event_function).is_empty():
		arrival = EventSheetL10n.translate("On asked")
	spans.append(_make_span("%s %s" % [arrival, plain_name],
		SemanticSpan.SpanType.OBJECT, name_meta))
	# The inputs, as an event sheet's own trigger payload chips - the names the call passes in, beside
	# the trigger that receives them. Their TYPES live in the properties popup, one click away.
	var chip_texts: PackedStringArray = PackedStringArray()
	for param: Variant in event_function.params:
		if param is ACEParam:
			chip_texts.append(verb_param_chip_text(param as ACEParam))
	if chip_texts.is_empty():
		for legacy: String in event_function.parameters:
			chip_texts.append(str(legacy).replace("_", " ").strip_edges())
	# A plain chip, not a field cell: an input chip belongs beside its verb, not in the row's shared
	# object column (which is sized for object names and would elide "enabled" to an ellipsis).
	var chip_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	for index in range(chip_texts.size()):
		spans.append(_make_span(chip_texts[index], SemanticSpan.SpanType.CONDITION, {
			"editable": false,
			"lane": "condition",
			"kind": "verb_param",
			"param_index": index,
			"chip": true,
			"line_index": 0
		}.merged(chip_style, true)))
	# The KIND stays a word, quietly, beside the name: a published condition or expression answers a
	# question rather than doing something, and the tint alone never said which. An action verb says
	# nothing extra - "do these" is what every other event already means.
	if event_function.expose_as_ace and role != "action":
		spans.append(_make_span(EventSheetL10n.translate(role), SemanticSpan.SpanType.COMMENT, {
			"editable": false,
			"kind": "define_function",
			"lane": "condition",
			"line_index": 0,
			"natural_width": true,
			"text_color": _viewport._get_reading_style().muted_text_color
		}))
	# ────────────────────────────────────────────────────────────────────────────────────────────
	# The two things about a function that change how it is CALLED, said on the header where the call
	# is decided rather than found out inside the body. A function that waits cannot be called and
	# left; a shared one belongs to the class rather than to any one object.
	if event_function.is_async:
		spans.append(_make_span("⏳ %s" % EventSheetL10n.translate("waits"),
			SemanticSpan.SpanType.CONDITION, {
				"editable": false,
				"kind": "verb_param",
				"chip": true,
				"line_index": 0
			}.merged(chip_style, true)))
	if event_function.is_static:
		spans.append(_make_span(EventSheetL10n.translate("shared"), SemanticSpan.SpanType.COMMENT, {
			"editable": false,
			"kind": "define_function",
			"lane": "condition",
			"line_index": 0,
			"natural_width": true,
			"text_color": _viewport._get_reading_style().muted_text_color
		}))
	# ────────────────────────────────────────────────────────────────────────────────────────────
	# A function whose rows alternate waiting and doing IS a sequence, and the header says so with how
	# long the whole run takes. Display only: the body is untouched, and the claim behind the chip is
	# what the pattern chips and Refactor read.
	var sequence_words: String = _wait_sequence_words(event_function)
	if not sequence_words.is_empty():
		spans.append(_make_span(sequence_words, SemanticSpan.SpanType.COMMENT, {
			"editable": false,
			"kind": "define_function",
			"lane": "condition",
			"line_index": 0,
			"natural_width": true,
			"text_color": _viewport._get_reading_style().muted_text_color
		}))
	if not event_function.expose_as_ace:
		var doc_line: String = helper_doc_line(event_function)
		if not doc_line.is_empty():
			spans.append(_make_span(doc_line, SemanticSpan.SpanType.COMMENT, {
				"editable": false,
				"kind": "define_function",
				"lane": "action",
				"line_index": 0,
				"text_color": _viewport._get_reading_style().muted_text_color
			}))
	var callers: String = called_by_words(event_function.function_name,
		str((_viewport._sheet as EventSheetResource).external_source_path) if _viewport._sheet != null else "")
	if not callers.is_empty():
		spans.append(_make_span(callers, SemanticSpan.SpanType.COMMENT, {
			"editable": false,
			"kind": "define_function",
			"lane": "action",
			"line_index": 0,
			"natural_width": true,
			"text_color": _viewport._get_reading_style().muted_text_color
		}))
	_append_message_spans(spans, event_function)
	return spans


## How many files the project has, so the band can name a few and count the rest rather than
## enumerating a hundred - the same rule every read-from-the-project band follows.
const CALLERS_NAMED: int = 3


## "called by combat.gd · boss_ai.gd" - who else in the project calls this function, off the one
## project index. "" when nobody does, and "" while the index is still counting: a band says a fact
## or says nothing, and the view is built again when the count lands.
##
## Matched BY NAME, which is what the index can honestly answer, so a rename reads this as the list
## to CHECK rather than as a list to act on. Static + pure over a name, so it is pinned headless.
static func called_by_words(function_name: String, own_script: String) -> String:
	if function_name.strip_edges().is_empty() or not EventSheetProjectShareIndex.request():
		return ""
	var callers: PackedStringArray = EventSheetProjectShareIndex.callers_of(function_name, own_script)
	if callers.is_empty():
		return ""
	var named: PackedStringArray = PackedStringArray()
	for index in range(mini(callers.size(), CALLERS_NAMED)):
		named.append(callers[index].get_file())
	var words: String = EventSheetL10n.translate("called by %s") % " · ".join(named)
	if callers.size() > CALLERS_NAMED:
		words += " · " + EventSheetL10n.translate("%d more") % (callers.size() - CALLERS_NAMED)
	return words


## What a MESSAGE says about itself at the right of its own row: the three `@rpc` choices in the
## sheet's words ("from anyone · also here · reliable"), then the annotation itself echoed in the
## script editor's own colours. An annotation carrying an option Godot does not take reads as no
## words at all - the echo IS the annotation, and guessing at what it meant would be worse than the
## line - and `build_verb_block_rows` puts the amber note naming that option under the row.
func _append_message_spans(spans: Array[SemanticSpan], event_function: EventFunction) -> void:
	var annotation: String = EventSheetMessageFacts.annotation_of(event_function)
	if annotation.is_empty():
		_append_visibility_filter_span(spans, event_function)
		return
	var mode_words: String = EventSheetMessageFacts.words(annotation)
	if not mode_words.is_empty() and EventSheetMessageFacts.unknown_note(annotation).is_empty():
		spans.append(_make_span(mode_words, SemanticSpan.SpanType.COMMENT, {
			"editable": false,
			"kind": "define_function",
			"message_words": true,
			"lane": "condition",
			"line_index": 0,
			"natural_width": true,
			"text_color": _viewport._get_reading_style().muted_text_color
		}))
	spans.append(_code_echo_span(annotation, {
		"kind": "define_function",
		"message_annotation": true,
		"hover_note": EventSheetL10n.translate("The line that makes this function a message. Click to open it in the code panel.")
	}, EventSheetCodeEcho.REST_ALPHA, true))


## The word a function row leads with when the sheet does not CALL this function - it is
## reached some other way, and the row says which. "" for an ordinary function, which is most of
## them. Both words are literals rather than a table lookup, so the translation gate can see them.
func _function_role_word(event_function: EventFunction) -> String:
	if EventSheetMessageFacts.is_message(event_function):
		return EventSheetL10n.translate("message")
	if not _visibility_filter_entry(event_function).is_empty():
		return EventSheetL10n.translate("visibility filter")
	return ""


## What the sheet's own rows say about this function being a visibility filter, or {} for every
## other function. One lookup for both halves of the mark - the word that leads the row, and the
## synchronizer named at the right of it.
func _visibility_filter_entry(event_function: EventFunction) -> Dictionary:
	if event_function == null:
		return {}
	return EventSheetSceneVerbs.filter_of(_viewport._sheet as EventSheetResource,
		event_function.function_name)


## Which synchronizer asks this function whether a player may see it, at the right of its own
## row - the other half of the "visibility filter" word. Nothing is written into the `.gd` for it:
## the fact IS the row that names the function, so a filter nobody asks stops saying it is one.
func _append_visibility_filter_span(spans: Array[SemanticSpan], event_function: EventFunction) -> void:
	var asked_by: String = str(_visibility_filter_entry(event_function).get("synchronizer", ""))
	if asked_by.is_empty():
		return
	spans.append(_make_span(EventSheetL10n.translate("for %s") % asked_by, SemanticSpan.SpanType.COMMENT, {
		"editable": false,
		"kind": "define_function",
		"role_words": true,
		"lane": "condition",
		"line_index": 0,
		"natural_width": true,
		"text_color": _viewport._get_reading_style().muted_text_color
	}))


## One editor callback as the event it is: the trigger arrow, the owning panel in the
## object column, and the sentence that says what the editor wants.
##
## Two shapes, chosen by the sentence itself. A sentence that NAMES the callback's parameters
## ("On property name of object") spells them inline and bold, because they are the subject of the
## question and a chip repeating them would print the same words twice. A sentence that names none
## ("On workspace shown") keeps them as the trigger payload chips every other event wears, which is
## how `visible` stays visible without the sentence having to mention it.
## `object_word` names the object the row files under; blank means the editor object this was first
## written for. The animation events borrow the whole shape - a badge, a sentence, the parameter
## chips - and differ only in whose event it is.
func _build_editor_callback_spans(event_function: EventFunction, sentence: String,
		object_word: String = "") -> Array[SemanticSpan]:
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var chip_bg: Color = _verb_chip_colors()[0]
	var spans: Array[SemanticSpan] = [
		_make_span("➜", SemanticSpan.SpanType.KEYWORD, {
			"editable": false,
			"badge": true,
			"badge_style": "trigger",
			"badge_bg": chip_bg,
			"badge_fg": event_style.behavior_accent_color,
			"kind": "define_function",
			"lane": "condition",
			"line_index": 0
		})
	]
	var names: PackedStringArray = _editor_callback_param_names(event_function)
	var marked_up: String = EventSheetL10n.translate(sentence)
	var named_any: bool = false
	for index: int in names.size():
		var slot: String = "{%d}" % index
		if marked_up.contains(slot):
			marked_up = marked_up.replace(slot, "[b]%s[/b]" % names[index])
			named_any = true
	var name_color: Color = event_style.object_label_color
	var name_meta: Dictionary = {
		"editable": false,
		"kind": "define_function",
		"lane": "condition",
		"line_index": 0,
		# The object column keeps the object's NAME as the sheet spells it, untranslated - the same
		# rule the Editor object has followed since it was introduced, so one sheet never shows two
		# spellings of the same object.
		"object_label": object_word if not object_word.is_empty() \
			else EventSheetEditorPluginWords.object_for(_editor_plugin_class()),
		"text_color": name_color
	}
	if EventSheetBBCodeLite.has_markup(marked_up):
		name_meta["bbcode_segments"] = EventSheetBBCodeLite.parse(marked_up, name_color)
	spans.append(_make_span(EventSheetBBCodeLite.strip(marked_up), SemanticSpan.SpanType.OBJECT, name_meta))
	if named_any:
		return spans
	var chip_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	for index: int in names.size():
		spans.append(_make_span(names[index], SemanticSpan.SpanType.CONDITION, {
			"editable": false,
			"lane": "condition",
			"kind": "verb_param",
			"param_index": index,
			"chip": true,
			"line_index": 0
		}.merged(chip_style, true)))
	return spans


## The callback's parameters under the names the FILE writes them with - `object`, `visible`,
## `paths`. Not the friendly labels a published verb's inputs wear: the sentence is the editor's
## question about that very argument, and a reader following it into the body will find the
## identifier, not a Title Case label.
func _editor_callback_param_names(event_function: EventFunction) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for param: Variant in event_function.params:
		if not (param is ACEParam):
			continue
		var bare: String = str((param as ACEParam).id).strip_edges()
		if bare.is_empty():
			bare = str((param as ACEParam).name).strip_edges()
		names.append(bare)
	if names.is_empty():
		for legacy: String in event_function.parameters:
			names.append(str(legacy).strip_edges())
	return names


## The `sequence · N s` chip a function of alternating waits and actions wears, or "" for every
## other function. The body's own lines are the only input, so the chip and the claim behind it can
## never say different things.
func _wait_sequence_words(event_function: EventFunction) -> String:
	if event_function == null:
		return ""
	var body: PackedStringArray = PackedStringArray()
	for entry: Variant in event_function.events:
		EventSheetViewportReadingRows.append_body_lines(entry, body)
	return EventSheetPatternReadings.wait_sequence_words(EventSheetPatternReadings.wait_sequence(body))


## The verb's BODY as foldable children, plus the fold seed and the "+ Add event" way in. Shared by
## both header forms so a Reading-mode block opens exactly like an authoring one.
func _append_verb_body_rows(row_data: EventRowData, event_function: EventFunction, indent: int, display_name: String) -> void:
	# Event-sheet expandable block: the function BODY renders as foldable children (its conditions,
	# actions, and raw GDScript blocks), built by the SAME dispatcher as sheet events, folding like a group.
	# On an AUTHORED sheet the body is LIVE - the child rows keep their source_resource so selection / drag /
	# delete / inline edit reach the verb's own conditions and actions (edits route to event_function.events
	# via _find_resource_location's function-body search). On an OPENED behaviour pack (or a read-only
	# preview) the body stays a pure READ instead: each child is made INERT (source_resource nulled over the
	# subtree) so no mutation can reach it and corrupt the .gd's byte round-trip - per-function opt-in
	# unlocks that later. Default-collapsed (folded seeded from _fold_state) preserves the header look.
	var body_editable: bool = _function_body_editable(event_function)
	var body_entries: Array = event_function.events if not event_function.events.is_empty() else event_function.rows
	# The body's rows read as the KIND of verb they belong to (a `return` inside a published condition
	# answers yes or no), and only the walk below knows which verb that is - so it is recorded here and
	# put back afterwards, leaving sheet-level rows on the plain action reading.
	var outer_verb: EventFunction = _current_verb_function
	_current_verb_function = event_function
	for body_entry: Variant in body_entries:
		if body_entry is Resource:
			var child_row: EventRowData = _viewport._build_row_from_resource(body_entry as Resource, indent + 1)
			if child_row != null:
				# Mark the subtree BEFORE any span build: a condition-less row inside a verb body must
				# read "Always" (it runs when the verb is called), not the sheet's "Every Tick".
				_mark_verb_body(child_row, _current_verb_kind(), _current_verb_function)
				# Runs HERE, before the body is made inert: the sub-event pair is derived from the
				# EventRow the row points at, and an inert row has already dropped that pointer.
				var body_rows: Array[EventRowData] = [child_row]
				body_rows = expand_ternary_rows(body_rows)
				for body_row: EventRowData in body_rows:
					if not body_editable:
						_make_row_inert(body_row)
					row_data.children.append(body_row)
	_current_verb_function = outer_verb
	# The way IN to a verb's body, mirroring a group's own footer. A freshly created verb has an empty
	# body, so without this there is nowhere to put its first event - and since a "run only when" guard
	# is just a condition on an event inside the verb, that first event is exactly what a guard needs.
	if body_editable:
		row_data.children.append(_build_add_event_footer_row(
			event_function, indent + 1,
			"+ Add event to '%s'…" % (display_name if not display_name.is_empty() else event_function.function_name)
		))
	if not row_data.children.is_empty():
		# A verb OPENS by default - its steps ARE the point, and a pack of collapsed rows reads as the spec
		# table this row set out to stop being. A fold the user set by hand still wins, and
		# fold_nested_verb_rows re-collapses a verb that turns out to sit inside a group or a #region,
		# where the enclosing block owns the fold.
		row_data.folded = bool(_viewport._fold_state.get(row_data.row_uid, false))


## Folds the body's FIRST step into the function's own row, so `Functions ▸ On Take Damage` reads with
## `Player ▸ Subtract amount from hp` beside it instead of above an empty condition cell. Only an INERT
## first step is folded in: an inert row has already dropped its resource (nothing addresses its
## actions any more), so moving its drawn spans is purely a reading. A first step that still owns its
## resource - an editable body, where clicking an action must reach that action - is left where it is,
## and the function keeps the header form it had. Its own sub-events move up with it, so the branch
## under the step still hangs off the step.
func _merge_first_body_step_into_header(row_data: EventRowData) -> void:
	if row_data.children.is_empty():
		return
	var first_step: EventRowData = row_data.children[0]
	if first_step == null or first_step.row_type != EventRowData.RowType.EVENT:
		return
	if first_step.source_resource != null:
		return  # a live body row: its actions must stay addressable where they are
	# The one row of a verb body whose words are needed at BUILD time rather than at draw time: they
	# are about to move into the header, so they have to exist. Every other body row stays lazy.
	_ensure_event_spans(first_step)
	var moved: Array[SemanticSpan] = []
	for span: SemanticSpan in first_step.spans:
		if span == null or not (span.metadata is Dictionary):
			return  # an un-mergeable step: leave the block exactly as it was
		if str((span.metadata as Dictionary).get("lane", "")) != "action":
			return  # the step asks a question of its own - it is a row, not this row's right half
		moved.append(span)
	if moved.is_empty():
		return
	row_data.spans.append_array(moved)
	row_data.line_count = maxi(row_data.line_count, first_step.line_count)
	row_data.children.remove_at(0)
	var reinserted: int = 0
	for grandchild: EventRowData in first_step.children:
		_shift_row_indent(grandchild, row_data.indent + 1 - grandchild.indent)
		row_data.children.insert(reinserted, grandchild)
		reinserted += 1


## Strips a row and its whole subtree of its editing identity so it renders but is inert - no selection,
## drag, delete, or inline edit reaches it (every mutation path guards on source_resource being the row's
## kind, and the add-cell click guards on a non-null source). Used for a published verb's body rows: they
## display the function's conditions/actions/raw blocks for reading, but their resources live in
## event_function.events, not sheet.events, so any write would alias or corrupt the .gd. Read-only reveal.
func _make_row_inert(row_data: EventRowData) -> void:
	# The resource moves to the READING pointer rather than being resolved into spans here. Event-row
	# spans are built lazily and the builder reads them off the row's resource, so simply nulling
	# would leave the row permanently blank - and building them all here instead cost a long file the
	# words of every row it has, on the open and again on every edit, for rows nobody had scrolled to.
	# Handing the span builder its own pointer keeps both promises: nothing that WRITES can find the
	# resource, and the words are still built the moment the row is laid out.
	row_data.reading_resource = row_data.source_resource
	# The ONE head that counts what the rows recognised - a read-only pack preview's Include bar,
	# which says how much of the file reads as events and how many shapes it claimed - is composed
	# while the rows are still being built, so on that sheet the rows have to have been read by then.
	# A pack is a bounded file and this is its preview. Every other opened file has no such bar and
	# stays lazy, which is the case worth being lazy for: a two-thousand-line script.
	if _viewport != null and _viewport._sheet != null and _viewport._sheet.read_only:
		_ensure_event_spans(row_data)
	row_data.source_resource = null
	for child: EventRowData in row_data.children:
		_make_row_inert(child)


## Flags a row and its whole subtree as living inside a published verb's body, so a condition-less
## event reads "Always" (it runs when the verb is called) instead of the sheet-level "Every Tick"
## (which is only true of the sheet's own events, since a sheet compiles into _process).
## The verb itself rides along beside its kind, because two readings need the function and not only
## what sort of function it is: a `return` inside one of the editor's own callbacks answers that
## callback's question, and a handler row's menu is the menu of the handler it sits in. Both used to
## read the verb the walk was inside; the words are built later than that walk now.
func _mark_verb_body(row_data: EventRowData, verb_kind: int = EventSheetSentence.VerbKind.ACTION,
		verb_function: EventFunction = null) -> void:
	row_data.in_verb_body = true
	row_data.verb_kind = verb_kind
	row_data.verb_function = verb_function
	for child: EventRowData in row_data.children:
		_mark_verb_body(child, verb_kind, verb_function)


## True when a published verb's body should render as LIVE, editable event rows. On an AUTHORED sheet (one
## not backed by an opened .gd - external_source_path empty) every verb body is editable. On an OPENED
## behaviour pack only a verb the user explicitly opted in (per function, via "Make Body Editable") is live;
## the rest stay a pure read (rows inert) so their .gd round-trips byte-identically - the sibling guarantee.
## A read-only preview, or a missing sheet reference, is always inert.
func _function_body_editable(event_function: EventFunction) -> bool:
	var sheet: EventSheetResource = _viewport._sheet
	if sheet == null or sheet.read_only:
		return false
	if sheet.external_source_path.strip_edges().is_empty():
		return true
	return _viewport.is_function_body_editable_opt_in(event_function.function_name)


## First Color(...) literal among an ACE's param values (null when none) - drives the
## little color swatch drawn after the condition/action text.
func _first_color_in_params(ace: Resource) -> Variant:
	var params: Variant = ace.get("params")
	if not (params is Dictionary):
		return null
	for key: Variant in (params as Dictionary).keys():
		var value: Variant = (params as Dictionary)[key]
		if value is String and (value as String).strip_edges().begins_with("Color("):
			var parsed: Variant = str_to_var((value as String).strip_edges())
			if parsed is Color:
				return parsed
	return null


## The one extra fact the Is in X for over Ns cell carries: how long that row is waiting for, as a
## plain number. While a game is running the editor draws the object's progress against it right
## after the cell ("3.2 of 6"), so the number is read off the row ONCE here rather than parsed in the
## draw loop. Empty for every other condition, and empty when the wait is an expression rather than a
## number - a computed wait shows no progress instead of a progress the editor invented.
##
## Static, because it reads the condition and nothing else: the rule is then pinned headless rather
## than only exercised through a canvas.
static func state_progress_metadata(condition: ACECondition) -> Dictionary:
	# An INVERTED row is not counting up to firing - it fires until the hold passes, and stops. "3.2
	# of 6" beside it would read as progress towards the opposite of what happens, so an inverted row
	# shows nothing, which is the same answer a computed wait gets and for the same reason.
	if condition == null or condition.ace_id != "InStateForOver" or condition.negated:
		return {}
	var written: String = str(condition.params.get("seconds", "")).strip_edges()
	if not written.is_valid_float():
		return {}
	return {ViewportLiveValuesHelper.STATE_PROGRESS_META: written.to_float()}


## An enum row: rendered like a variable declaration ("enum  State { IDLE, RUN }");
## double-click opens the enum dialog.
## The enum block, two states behind one fold arrow: CLOSED it reads as a sentence
## ("State is one of PATROL, CHASE or FLEE" - tinted words, no braces, no boxes), OPEN it lists
## one row per value with its number plus an Add value footer. Display-only: the EnumRow and its
## emission are untouched, and double-click anywhere (header, value, footer) opens the enum
## editor as before.
func _build_enum_row(enum_row: EnumRow, indent: int) -> EventRowData:
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = enum_row
	row_data.row_uid = "enum_%s_%d" % [str(enum_row.get_instance_id()), indent]
	row_data.disabled = not enum_row.enabled or bool(_viewport._row_disabled_state.get(row_data.row_uid, false))
	row_data.breakpoint_enabled = bool(_viewport._breakpoint_rows.get(row_data.row_uid, false))
	row_data.folded = bool(_viewport._fold_state.get(row_data.row_uid, true))
	# The enum block is an IDENTITY bar (it is the state list a state machine runs on): the same
	# 1.5x height + accent band the Class setup and Host binding bars wear. Event rows stay at
	# normal height - the presence belongs to the DEFINITION, not to every row that uses it.
	row_data.height_scale = 1.5
	row_data.custom_color = Color(event_style.behavior_accent_color.r, event_style.behavior_accent_color.g, event_style.behavior_accent_color.b, 0.22)
	var badge_meta: Dictionary = {
		"editable": false,
		"badge": true,
		"badge_style": "trigger",
		"badge_bg": event_style.behavior_accent_color.lerp(event_style.lane_divider_color, 0.45),
		"badge_fg": event_style.trigger_badge_foreground_color,
		"kind": "enum_row",
		"line_index": 0
	}
	var names: PackedStringArray = PackedStringArray()
	for member: String in enum_row.members:
		var eq: int = member.find("=")
		names.append(member.substr(0, eq).strip_edges() if eq > 0 else member.strip_edges())
	var spans: Array[SemanticSpan] = [
		_make_span("≡", SemanticSpan.SpanType.KEYWORD, badge_meta),
		_make_span(enum_row.enum_name, SemanticSpan.SpanType.VALUE, {"kind": "enum_row", "text_color": event_style.object_label_color})
	]
	if row_data.folded:
		# The sentence: up to five values spelled out, the rest counted - a long enum never
		# walls the sheet at rest.
		var spoken: int = mini(names.size(), 5)
		spans.append(_make_span(EventSheetL10n.translate("is one of"), SemanticSpan.SpanType.COMMENT, {"kind": "enum_row", "text_color": _viewport._get_reading_style().muted_text_color}))
		for name_index: int in range(spoken):
			if name_index > 0 and name_index == spoken - 1 and names.size() <= spoken:
				spans.append(_make_span(EventSheetL10n.translate("or"), SemanticSpan.SpanType.COMMENT, {"kind": "enum_row", "text_color": _viewport._get_reading_style().muted_text_color}))
			# The comma rides INSIDE the value span - spans are auto-spaced, and "PATROL ," is
			# exactly the boxed-fragment look the sentence exists to avoid.
			var needs_comma: bool = name_index < spoken - 1 and not (name_index == spoken - 2 and names.size() <= spoken)
			spans.append(_make_span(names[name_index] + ("," if needs_comma else ""), SemanticSpan.SpanType.VALUE, {"kind": "enum_row"}))
		if names.size() > spoken:
			spans.append(_make_span("%s %d %s" % [EventSheetL10n.translate("and"), names.size() - spoken, EventSheetL10n.translate("more")], SemanticSpan.SpanType.COMMENT, {"kind": "enum_row", "text_color": _viewport._get_reading_style().muted_text_color}))
	else:
		spans.append(_make_span("- %d %s" % [names.size(), EventSheetL10n.translate("values")], SemanticSpan.SpanType.COMMENT, {"kind": "enum_row", "text_color": _viewport._get_reading_style().muted_text_color}))
		var next_value: int = 0
		var member_index: int = 0
		for member: String in enum_row.members:
			var eq: int = member.find("=")
			var member_name: String = member.substr(0, eq).strip_edges() if eq > 0 else member.strip_edges()
			if eq > 0 and str(member.substr(eq + 1).strip_edges()).is_valid_int():
				next_value = int(member.substr(eq + 1).strip_edges())
			var entry := EventRowData.new()
			entry.indent = indent + 1
			entry.row_type = EventRowData.RowType.SECTION
			entry.source_resource = enum_row
			entry.row_uid = "enum_value_%s_%s" % [str(enum_row.get_instance_id()), member_name]
			# The first member is what an uninitialized variable of this enum holds - worth saying.
			var entry_note: String = "= %d" % next_value
			if member_index == 0:
				entry_note += " · %s" % EventSheetL10n.translate("default")
			entry.spans = [
				_make_span(member_name, SemanticSpan.SpanType.VALUE, {"kind": "enum_value", "line_index": 0}),
				_make_span(entry_note, SemanticSpan.SpanType.COMMENT, {"kind": "enum_value", "text_color": _viewport._get_reading_style().muted_text_color})
			]
			row_data.children.append(entry)
			next_value += 1
			member_index += 1
		# No "add" affordance on a read-only preview or a figure: it edits nothing there.
		if not _scaffolding_suppressed():
			var add_row := EventRowData.new()
			add_row.indent = indent + 1
			add_row.row_type = EventRowData.RowType.SECTION
			add_row.source_resource = enum_row
			add_row.row_uid = "enum_add_%s" % str(enum_row.get_instance_id())
			add_row.spans = [_make_span(EventSheetL10n.translate("+ Add value…"), SemanticSpan.SpanType.COMMENT, {"kind": "enum_add", "text_color": _viewport._get_reading_style().muted_text_color})]
			row_data.children.append(add_row)
	row_data.spans = spans
	return row_data


## A Custom Block API row: kind badge + the kind's one-line summary, both owned by the
## registered EventSheetBlockKind. A block whose kind is unregistered (its pack was removed)
## renders with a muted generic badge so the sheet stays readable; its emitted GDScript is
## plain code either way, so nothing else degrades.
func _build_custom_block_row(block: CustomBlockRow, indent: int) -> EventRowData:
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = block
	row_data.row_uid = "custom_block_%s_%d" % [str(block.get_instance_id()), indent]
	row_data.disabled = not block.enabled or bool(_viewport._row_disabled_state.get(row_data.row_uid, false))
	row_data.breakpoint_enabled = bool(_viewport._breakpoint_rows.get(row_data.row_uid, false))
	var kind: EventSheetBlockKind = EventSheetBlockRegistry.get_kind(block.kind_id)
	# A region asks for its own look through the Custom Block API rather than borrowing the
	# group bar's chrome: it is a FOLD MARK, the same thing the script editor draws, and it holds
	# none of what a group holds. Any registered kind can ask for the same shape.
	if kind != null and kind.row_style(block) == "region":
		_dress_region_fence_row(row_data, block)
		return row_data
	# First-class display: a kind may describe variable-style spans (name / operator / value /
	# keyword pills) and its rows read like the plugin's own variable rows - the built-in
	# preload kind ships through this hook, so it is load-bearing, not just an extension seam.
	var described: Array[Dictionary] = kind.display_spans(block) if kind != null else []
	if not described.is_empty():
		row_data.spans = []
		for span_descriptor: Dictionary in described:
			var span_text: String = str(span_descriptor.get("text", ""))
			match str(span_descriptor.get("role", "value")):
				"name":
					row_data.spans.append(_make_span(span_text, SemanticSpan.SpanType.OBJECT, {"kind": "custom_block_row"}))
				"operator":
					row_data.spans.append(_make_span(span_text, SemanticSpan.SpanType.OPERATOR, {"kind": "custom_block_row"}))
				"type":
					row_data.spans.append(_make_span(span_text, SemanticSpan.SpanType.VALUE, {"kind": "custom_block_row"}))
				"badge":
					var is_const_style: bool = str(span_descriptor.get("badge_style", "scope")) == "const"
					row_data.spans.append(_make_span(span_text, SemanticSpan.SpanType.KEYWORD, {
						"kind": "custom_block_row",
						"badge": true,
						"badge_style": "const" if is_const_style else "scope",
						"badge_bg": _viewport._get_reading_style().constant_badge_background_color if is_const_style else _viewport._get_reading_style().inspector_chip_background_color,
						"badge_fg": _viewport._get_reading_style().constant_badge_foreground_color if is_const_style else _viewport._get_reading_style().inspector_chip_foreground_color
					}))
				_:
					row_data.spans.append(_make_span(span_text, SemanticSpan.SpanType.VALUE, {"kind": "custom_block_row", "text_color": event_style.object_label_color}))
	else:
		var badge_text: String = kind.title if kind != null else "block"
		var summary_text: String = kind.summary(block) if kind != null else block.kind_id
		# Extension hooks: a kind may tint its badge (style) and flag bad fields live (validate).
		var kind_style: Dictionary = kind.style(block) if kind != null else {}
		var badge_color: Color = kind_style.get("accent", event_style.behavior_accent_color)
		row_data.spans = [
			_make_span(
				badge_text,
				SemanticSpan.SpanType.KEYWORD,
				{"badge": true, "text_color": badge_color}
			),
			_make_span(
				summary_text,
				SemanticSpan.SpanType.VALUE,
				{"kind": "custom_block_row", "text_color": event_style.object_label_color}
			)
		]
	var problem: String = kind.validate(block) if kind != null else ""
	if not problem.is_empty():
		row_data.spans.append(_make_span(
			"⚠ " + problem,
			SemanticSpan.SpanType.VALUE,
			{"kind": "custom_block_row", "text_color": _viewport._get_reading_style().error_text_color}
		))
	return row_data


## A mid-file lifted function's position marker: the function itself is a real EventFunction
## (edited via its Define block / the Functions panel); this row just shows WHERE it lives in
## the file, muted so it reads as structure rather than content.
func _build_function_anchor_row(anchor: FunctionAnchorRow, indent: int) -> EventRowData:
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = anchor
	row_data.row_uid = "fn_anchor_%s_%d" % [str(anchor.get_instance_id()), indent]
	row_data.spans = [
		_make_span(
			"ƒ",
			SemanticSpan.SpanType.KEYWORD,
			{"badge": true, "text_color": event_style.behavior_accent_color}
		),
		_make_span(
			"%s()  - defined here" % anchor.function_name,
			SemanticSpan.SpanType.VALUE,
			{"kind": "function_anchor_row", "text_color": event_style.object_label_color}
		)
	]
	return row_data


## A signal row, in the same two-lane grammar every other row uses. A trigger IS a condition - it is
## the thing on the LEFT that starts an event - so the condition lane carries what the trigger is (its
## kind badge, the friendly published name, and one cell per value it passes along, in the shared
## field-cell grammar); the action lane carries what a reader cannot see from the friendly name: the
## real signal identifier that game code connects to, or "internal" for a plain signal that publishes
## no trigger ACE at all. Deliberately no raw `signal name(damage: int)` declaration in either lane -
## the same reason a Define row dropped its `func … ->` cue: the row is the abstraction, and the code
## line lives in the hover for anyone who wants it. Double-click still opens the signal dialog.
func _build_signal_row(signal_row: SignalRow, indent: int) -> EventRowData:
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.EVENT
	row_data.source_resource = signal_row
	row_data.row_uid = "signal_%s_%d" % [str(signal_row.get_instance_id()), indent]
	row_data.disabled = not signal_row.enabled or bool(_viewport._row_disabled_state.get(row_data.row_uid, false))
	row_data.breakpoint_enabled = bool(_viewport._breakpoint_rows.get(row_data.row_uid, false))
	var chip_bg: Color = _verb_chip_colors()[0]
	var chip_fg: Color = _verb_chip_colors()[1]
	# A published trigger reads by its friendly @ace_name; a plain signal has only its own name.
	# EXCEPT in an opened plain script, where a declared signal IS that object's trigger - nothing
	# else fires it and nothing else listens - so it reads the way every other trigger in the editor
	# does: `On Died`, `On Picked Up Coin`, with its values as chips beside it. A PACK is different:
	# there, "published as an ACE" is a real distinction its author made, and the row keeps saying so.
	var script_trigger: bool = not signal_row.trigger and _reads_as_script_trigger()
	var title: String = signal_row.ace_name.strip_edges() if signal_row.trigger else ""
	if title.is_empty():
		title = "On %s" % signal_row.signal_name.capitalize() if script_trigger else signal_row.signal_name
	# The kind cue is a single glyph in the same narrow badge column every event row uses - the
	# fired-signal arrow for a published trigger, a dimmed one for an internal signal (the action
	# lane already spells out "emits X" vs "internal"). A word in a box here reads as a pill, and
	# pills lost that argument some time ago.
	var spans: Array[SemanticSpan] = [
		_make_span("➜", SemanticSpan.SpanType.KEYWORD, {
			"editable": false,
			"badge": true,
			"badge_style": "trigger",
			"badge_bg": chip_bg,
			"badge_fg": event_style.behavior_accent_color if signal_row.trigger or script_trigger else event_style.behavior_accent_color.lerp(chip_bg, 0.45),
			"kind": "signal_row",
			"lane": "condition",
			"line_index": 0
		}),
		_make_span(title, SemanticSpan.SpanType.OBJECT, {
			"kind": "signal_row",
			"lane": "condition",
			"line_index": 0,
			"text_color": event_style.object_label_color
		})
	]
	var condition_lines: int = _append_signal_param_spans(spans, signal_row, script_trigger) + 1
	# The ACTION lane answers "and what actually fires?". For a trigger that is the underlying signal
	# identifier - the friendly name hides it, but it is what game code connects to, and it is the one
	# fact a reader cannot recover from the left lane. A plain signal's name IS its identifier, so
	# repeating it would be noise; it says "internal" instead, the same word a Define row uses for a
	# verb that is not published as an ACE.
	# In an opened plain script there is no such distinction to draw: every signal the file declares is
	# a trigger of it, so "internal" said nothing except that this was not a pack - and the whole row
	# already says that. The lane stays empty rather than carrying a word with no other word to be.
	if signal_row.trigger:
		spans.append(_define_chip(EventSheetL10n.translate("emits %s") % signal_row.signal_name, chip_bg, chip_fg, 0, "signal_row"))
	elif not script_trigger:
		spans.append(_define_chip(EventSheetL10n.translate("internal"), chip_bg, chip_fg.lerp(chip_bg, 0.45), 0, "signal_row"))
	row_data.spans = spans
	row_data.line_count = maxi(condition_lines, 1)
	return row_data


## True when this view is showing an ORDINARY script somebody opened - not a behavior pack, and not a
## sheet being authored. That is the one case where a declared signal has no second reading to lose:
## the file is being READ, and what a reader wants to know is which events it fires.
func _reads_as_script_trigger() -> bool:
	var sheet: EventSheetResource = _viewport._sheet
	return sheet != null and sheet.read_only and not is_addon_pack(sheet)


## One cell per value the signal passes to whoever handles it, in the shared field-cell grammar (the
## same one a condition cell and a verb parameter use). SignalRow stores them as raw declaration text
## ("damage" or "damage: int"), so the type is split off and read as a plain word - a handler author
## needs to know a number is coming, not that GDScript spells it `int`. Returns the last line used.
##
## An opened script's trigger row takes the OTHER shape: the payload rides beside the trigger as chips,
## one per value, exactly as a lifted signal handler's row draws them - so `➜ On Hit  body` reads the
## same whether the row came from the signal declaration or from the handler that answers it.
func _append_signal_param_spans(spans: Array[SemanticSpan], signal_row: SignalRow, as_chips: bool = false) -> int:
	var line: int = 0
	var cell_host := EventRowData.new()
	for index in range(signal_row.params.size()):
		var declaration: String = str(signal_row.params[index]).strip_edges()
		if declaration.is_empty():
			continue
		var param_name: String = declaration
		var type_word: String = friendly_type_word("")
		var colon: int = declaration.find(":")
		if colon >= 0:
			param_name = declaration.substr(0, colon).strip_edges()
			type_word = friendly_type_word(declaration.substr(colon + 1).strip_edges())
		if as_chips:
			spans.append(_trigger_payload_span(param_name.replace("_", " "), index, 0))
			continue
		line += 1
		append_field_cell(cell_host, param_name, type_word, {
			"kind": "signal_row",
			"param_index": index,
			"line_index": line
		})
	spans.append_array(cell_host.spans)
	return line


## One payload chip beside a trigger cell - the value the event hands whoever answers it. THE shape,
## shared by the three rows that carry a payload (a lifted handler, a connected lambda, an opened
## script's signal declaration), so the same event reads identically wherever a reader meets it.
func _trigger_payload_span(chip_text: String, param_index: int, line_index: int) -> SemanticSpan:
	var condition_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	return _make_span(chip_text, SemanticSpan.SpanType.CONDITION, {
		"editable": false,
		"lane": "condition",
		"kind": "trigger_payload",
		"param_index": param_index,
		"chip": true,
		"hoverable": false,
		"line_index": line_index
	}.merged(condition_style_meta, true))


## The host class ("" when not a match) if a RawCodeRow is EXACTLY the compiler's generated
## host-binding `_enter_tree` - the boilerplate every host-targeting behaviour pack emits to bind
## `host = get_parent()`. It carries no authored logic (it's regenerated from the sheet's host), so
## rendering it as a 4-line GDScript block reads as noise; matched, the row collapses to one muted
## "Host binding · acts on <Class>" line instead. Strict exact-shape match so a hand-modified
## _enter_tree stays a real editable block. Static + pure → unit-testable without a viewport.
static func host_binding_class(code: String) -> String:
	var lines: PackedStringArray = code.split("\n")
	# Trim a single trailing blank the importer may keep on the block.
	while lines.size() > 0 and lines[lines.size() - 1].strip_edges().is_empty():
		lines.remove_at(lines.size() - 1)
	if lines.size() != 4:
		return ""
	if lines[0] != "func _enter_tree() -> void:":
		return ""
	if _host_bind_regex == null:
		_host_bind_regex = RegEx.new()
		if _host_bind_regex.compile("^\\thost = get_parent\\(\\) as ([A-Za-z_][A-Za-z0-9_]*)$") != OK:
			return ""
	var bind_match: RegExMatch = _host_bind_regex.search(lines[1])
	if bind_match == null:
		return ""
	if lines[2] != "\tif host == null:":
		return ""
	# The guard line: `\t\tpush_warning("<Label> behavior requires a <Class> parent.")`.
	if not (lines[3].begins_with("\t\tpush_warning(\"") and lines[3].rstrip(" ").ends_with("parent.\")")):
		return ""
	return bind_match.get_string(1)


## True Define-shell info for a RawCodeRow that is PURELY an `## @ace_*` annotation block - the
## published-verb header a pack author writes above each exposed func. Opened packs keep these as
## literal code rows (the shell-lift into EventFunctions is separate work), so without this a pack
## reads as a wall of 7-line annotation blocks. Returns {kind, name, category, line_count} when the
## row qualifies (only blank/`##` lines; one action/condition/expression marker; an @ace_name to show),
## else {}. Static + pure so the classifier is unit-testable without a viewport.
static func define_shell_info(code: String) -> Dictionary:
	var kind: String = ""
	var name: String = ""
	var category: String = ""
	var lines: PackedStringArray = code.split("\n")
	for raw_line: String in lines:
		var line: String = raw_line.strip_edges()
		if line.is_empty():
			continue
		if not line.begins_with("##"):
			return {}  # real code in the row - not a pure annotation shell
		if line.begins_with("## @ace_action"):
			kind = "action"
		elif line.begins_with("## @ace_condition"):
			kind = "condition"
		elif line.begins_with("## @ace_expression"):
			kind = "expression"
		elif line.begins_with("## @ace_name("):
			name = _annotation_string_arg(line)
		elif line.begins_with("## @ace_category("):
			category = _annotation_string_arg(line)
	if kind.is_empty() or name.is_empty():
		return {}
	return {"kind": kind, "name": name, "category": category, "line_count": lines.size()}


static func _annotation_string_arg(line: String) -> String:
	var open_quote: int = line.find("\"")
	var close_quote: int = line.rfind("\"")
	if open_quote < 0 or close_quote <= open_quote:
		return ""
	return line.substr(open_quote + 1, close_quote - open_quote - 1)


## Which lines sit INSIDE a triple-quoted string, so they are never mistaken for statements of
## their own. A multi-line string is one statement no matter how its content is indented, and its
## body routinely starts at column 0 - which read as a wall of separate statements.
static func _string_interior_mask(lines: PackedStringArray) -> PackedInt32Array:
	var mask: PackedInt32Array = PackedInt32Array()
	var inside: bool = false
	for line: String in lines:
		# A line INSIDE the string is not a statement of its own, and must never be a split point.
		mask.append(1 if inside else 0)
		if line.count("\"\"\"") % 2 == 1:
			inside = not inside
	return mask


## True when a verbatim row is a SINGLE statement - one line, or a header plus the lines it owns
## that the canvas cannot show any other way. A single statement is an action: it renders with
## the ordinary action chrome the rows around it use, rather than the GDScript code-cell
## treatment that exists for a wall of several statements. The row itself is unchanged, so the
## byte round-trip is untouched and double-click still opens the code editor.
## The net change in bracket depth a line makes, ignoring anything inside a string literal or
## after a `#` comment. A statement CONTINUES while brackets are open, so a wrapped call spanning
## several lines is one statement and reads as one row.
static func _bracket_delta(line: String) -> int:
	var depth: int = 0
	var quote: String = ""
	var index: int = 0
	while index < line.length():
		var character: String = line[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote:
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == "#":
			break
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		index += 1
	return depth


static func is_single_statement(code: String) -> bool:
	var lines: PackedStringArray = code.split("\n")
	# The row's OWN shallowest indent is the statement level: a row collected from inside an
	# unlifted `if` or `for` is entirely indented, and measuring from column 0 would find no
	# statement in it at all and render a single nested line as a wall of code.
	var base_indent: int = -1
	var indent_mask: PackedInt32Array = _string_interior_mask(lines)
	for scan_index: int in lines.size():
		if lines[scan_index].strip_edges().is_empty() or indent_mask[scan_index] == 1:
			continue
		var indent: int = lines[scan_index].length() - lines[scan_index].lstrip("\t ").length()
		base_indent = indent if base_indent < 0 else mini(base_indent, indent)
	if base_indent < 0:
		return false
	var interior: PackedInt32Array = _string_interior_mask(lines)
	var seen_statement: bool = false
	var open_brackets: int = 0
	for line_index: int in lines.size():
		var line: String = lines[line_index]
		var was_open: int = open_brackets
		if interior[line_index] == 0:
			open_brackets = maxi(open_brackets + _bracket_delta(line), 0)
		if line.strip_edges().is_empty() or interior[line_index] == 1 or was_open > 0:
			continue
		if line.length() - line.lstrip("\t ").length() > base_indent:
			continue  # a continuation of the statement above it
		if seen_statement:
			return false  # a second statement at this level - a block, not a statement
		seen_statement = true
	return seen_statement


## True when a one-line code row is part of a multi-line collection literal: its declaration head
## (`var waves := {`), one of its entries (indented), or the bracket that closes it. Those rows are
## data, not statements, so they render with ordinary action chrome instead of the GDScript code
## cell - the point of splitting a literal per line was to make the entries read and drag like any
## other action.
static func is_literal_part(code: String) -> bool:
	if code.contains("
"):
		return false
	var text: String = code.strip_edges()
	if text.is_empty():
		return false
	if code.begins_with("	"):
		return true
	if _is_closer_line(code):
		return true
	return text.ends_with("{") or text.ends_with("[")


## True when a line carries nothing but closing brackets - the `}` that ends a literal split into
## one action per line. It closes the statement above rather than starting one, so it wears no
## badge of its own.
static func _is_closer_line(line: String) -> bool:
	var text: String = line.strip_edges()
	if text.is_empty():
		return false
	for character: String in text:
		if not (character in "}]),"):
			return false
	return true


## The badge an in-body block wears: none for a pure comment note (it is already visibly a
## comment), the bracket for a collapsed collection literal, and the code badge otherwise.
static func _inline_block_label(is_note: bool, literal_info: Dictionary) -> String:
	if is_note:
		return ""
	if not literal_info.is_empty():
		return "{}" if str(literal_info.get("head", "")).ends_with("{") else "[]"
	return "GDScript"


## The collapsed view of a RawCodeRow that is EXACTLY one multi-line collection literal: a head
## line opening a `{` or `[` (`const RULES := {`, `var rows: Array[Dictionary] = [`, `return [`),
## entry lines indented under it, and a last line that only closes the bracket. Returns
## {head, close, entries, line_count} when it qualifies, else {}.
##
## A data literal is ONE VALUE, not a sequence of statements, so rendering it as fifteen lines of
## code makes a table of constants look like logic. Collapsed, it reads as the single thing it is
## and the rows around it become findable again. Pure view: the RawCodeRow is untouched, so the
## byte round-trip is unaffected and double-click still opens the code editor to see or change it.
##
## Deliberately NOT matched: a head ending in a bare `(`, which is a wrapped function CALL rather
## than a literal, and any block with a statement after the closing bracket. Static + pure, so the
## classifier is unit-testable without a viewport.
static func data_literal_info(code: String) -> Dictionary:
	var lines: PackedStringArray = code.split("
")
	while lines.size() > 0 and lines[lines.size() - 1].strip_edges().is_empty():
		lines.remove_at(lines.size() - 1)
	# Head, at least one entry, and a closing line - anything shorter already reads fine as code.
	if lines.size() < 3:
		return {}
	var head_index: int = -1
	for index: int in lines.size():
		if not lines[index].strip_edges().is_empty():
			head_index = index
			break
	# Only blank lines may precede the head: a comment above it is content of its own, and hiding
	# it inside a collapsed summary would lose the one line that explains the table.
	if head_index != 0:
		return {}
	var head: String = lines[0]
	var head_text: String = head.strip_edges()
	var opens: bool = false
	for opener: String in ["{", "[", "({", "(["]:
		if head_text.ends_with(opener):
			opens = true
	if not opens:
		return {}
	var base_indent: String = head.substr(0, head.length() - head.lstrip("	 ").length())
	var close_text: String = lines[lines.size() - 1].strip_edges()
	# The closing line must sit at the head's own indent and carry nothing but bracket characters.
	if lines[lines.size() - 1].substr(0, base_indent.length()) != base_indent:
		return {}
	if lines[lines.size() - 1].strip_edges() != lines[lines.size() - 1].substr(base_indent.length()):
		return {}
	if close_text.is_empty():
		return {}
	for character: String in close_text:
		if not (character in "}]),"):
			return {}
	# Every entry line must be indented DEEPER than the head, or the block holds more than the literal.
	var entry_indents: Array = []
	for index: int in range(1, lines.size() - 1):
		if lines[index].strip_edges().is_empty():
			continue
		var indent: String = lines[index].substr(0, lines[index].length() - lines[index].lstrip("	 ").length())
		if indent.length() <= base_indent.length() or not indent.begins_with(base_indent):
			return {}
		# A line that is only closing brackets belongs to a NESTED value, not to this literal - counting
		# it would report a dictionary of two keys as three entries.
		var entry_text: String = lines[index].strip_edges()
		var closer_only: bool = true
		for character: String in entry_text:
			if not (character in "}]),"):
				closer_only = false
				break
		entry_indents.append([indent.length(), closer_only])
	if entry_indents.is_empty():
		return {}
	# Count only the SHALLOWEST entry lines, so a nested dictionary reports its own entries rather
	# than every line of its children.
	var shallowest: int = int((entry_indents[0] as Array)[0])
	for entry: Variant in entry_indents:
		shallowest = mini(shallowest, int((entry as Array)[0]))
	var entries: int = 0
	for entry: Variant in entry_indents:
		if int((entry as Array)[0]) == shallowest and not bool((entry as Array)[1]):
			entries += 1
	return {"head": head_text, "close": close_text, "entries": entries, "line_count": lines.size()}


## A RawCodeRow that is ONE top-level function definition (a private helper the importer could not lift
## into an ACE, or any func body opened from a .gd) - the header line plus an indented body, nothing else
## at column 0. Returns {name, params, return_type, body_lines, line_count} so the row renders as a
## collapsed `ƒ name(params) -> Type` function row instead of a raw GDScript wall - a function reads as a
## function, not code. Pure view: the lines are unchanged, so double-click-to-edit and the byte round-trip
## are untouched. Static + pure so it is unit-testable without a viewport.
static func function_body_info(code: String) -> Dictionary:
	var lines: PackedStringArray = code.split("\n")
	var header_index: int = -1
	for i: int in range(lines.size()):
		if not lines[i].strip_edges().is_empty():
			header_index = i
			break
	if header_index < 0:
		return {}
	# `static func` reads as a function too. Without the optional prefix every static helper in a
	# hand-written file - and tool/utility scripts are mostly static - rendered as a raw GDScript
	# wall while its non-static neighbour beside it rendered as a tidy row.
	if _func_header_regex == null:
		_func_header_regex = RegEx.new()
		if _func_header_regex.compile("^(?:static )?func ([A-Za-z_][A-Za-z0-9_]*)\\((.*)\\)(?: -> (.+))?:$") != OK:
			return {}
	var header_match: RegExMatch = _func_header_regex.search(lines[header_index])
	if header_match == null:
		return {}
	# Every later non-blank line must be indented (the body); a second column-0 statement means this row
	# is more than one function and stays a plain block.
	var body_lines: int = 0
	for j: int in range(header_index + 1, lines.size()):
		if lines[j].strip_edges().is_empty():
			continue
		if not lines[j].begins_with("\t"):
			return {}
		body_lines += 1
	if body_lines == 0:
		return {}
	var return_type: String = header_match.get_string(3)
	return {
		"name": header_match.get_string(1),
		"params": header_match.get_string(2),
		"return_type": return_type if not return_type.is_empty() else "void",
		"body_lines": body_lines,
		"line_count": lines.size()
	}


## The event-sheet sentence a single GDScript statement reads as: `score += wave[1]` becomes
## "Add wave[1] to score", `host.call_deferred("queue_free")` becomes "Destroy (at end of frame)"
## under the object "host". Returns {indent, object, segments} - each segment {text, tone} with tone
## "plain" | "name" | "value" - or {} when no shape is recognised.
##
## A person reading a sheet is reading STEPS, and an operator glyph is the one part of a step that
## has to be decoded rather than read. Naming the operation removes that decode without hiding
## anything: the row is the same RawCodeRow, so double-click still opens the real code and the byte
## round-trip is untouched.
##
## The grammar itself lives in EventSheetSentence, because the ACE rows in the lane beside these
## read through the SAME producer - a shape must say one thing whether it was typed or picked.
## Kept here as a thin forwarder so the classifiers around it keep one import surface.
static func statement_sentence(code: String, context: Dictionary = {}) -> Dictionary:
	# A trailing `# note` is a note on this row, not part of the statement. Split off FIRST, so
	# every reading below sees the line the way it would without one, and handed back on the result so
	# the row can draw it where a sheet draws a note - at the end. The row itself is untouched.
	var split: PackedStringArray = EventSheetSentence.trailing_comment(code)
	var note: String = split[1]
	var body: String = split[0]
	# The awaits an event sheet has words for, ahead of the grammar - a hand-written `await` that no
	# ACE claimed (inside a lambda, inside a block that stayed code) reads the same as the lifted row
	# beside it. Every other await falls straight through and keeps its GDScript.
	var awaited: Dictionary = _raw_await_reading(body, context)
	var reading: Dictionary = awaited if not awaited.is_empty() else EventSheetSentence.statement(body, context)
	if not note.is_empty() and not reading.is_empty():
		reading = reading.duplicate()
		reading["note"] = note
	return reading


## The reading of a hand-written `await <expression>` line, indent and all, or {} when the shape
## is not one of the named ones.
static func _raw_await_reading(code: String, context: Dictionary = {}) -> Dictionary:
	var indent: int = 0
	while indent < code.length() and code[indent] == "\t":
		indent += 1
	var text: String = code.substr(indent).strip_edges()
	if not text.begins_with("await "):
		return {}
	var reading: Dictionary = await_reading(text.substr(6), true, context)
	if reading.is_empty():
		return {}
	reading["indent"] = indent
	return reading


## The Object / Verb / parameters split of a statement that is EXACTLY one call:
## `subgroup_item.set_text(0, str(x))` returns {indent, target "subgroup_item", verb "Set Text",
## args ["0", "str(x)"]}, and a call with no receiver reports the target "self". Returns {} for
## anything else.
##
## This is the shape every ACE row on the canvas already has - an object, a verb, and its
## parameters - so a lifted call that could not become a real ACE at least READS like one instead
## of standing out as code. The verb is the method with a single leading `_` trimmed and then
## capitalized, which is exactly how the project-vocabulary picker names reflected methods
## (`set_text` reads "Set Text"), so the same call looks the same wherever it is shown.
##
## Refused: a line with a top-level ` = ` (that is an assignment and belongs to statement_sentence),
## `await`/`return` prefixes, comments, multi-line rows, a target holding a space or a `(`
## (`foo().bar()` is a chain, not an object), and anything after the closing `)`. Static + pure.
static func call_parts(code: String) -> Dictionary:
	if code.contains("\n"):
		return {}
	var indent: int = code.length() - code.lstrip("\t").length()
	var text: String = code.strip_edges()
	if text.is_empty() or text.begins_with("#"):
		return {}
	if text.begins_with("await ") or text.begins_with("return ") or text == "return":
		return {}
	if _top_level_operator(text, " = ") >= 0:
		return {}
	if not text.ends_with(")"):
		return {}
	var open_at: int = _first_open_paren(text)
	if open_at <= 0:
		return {}
	# The argument list must run to the very END of the line: `foo(1) + 1` is an expression around a
	# call, and calling it "Foo(1)" would silently drop the arithmetic.
	if _closing_paren(text, open_at) != text.length() - 1:
		return {}
	var head: String = text.substr(0, open_at).strip_edges()
	var target: String = "self"
	var method: String = head
	var dot_at: int = head.rfind(".")
	if dot_at >= 0:
		target = head.substr(0, dot_at).strip_edges()
		method = head.substr(dot_at + 1).strip_edges()
	if not _is_simple_target(target) or not _is_identifier(method):
		return {}
	var inner: String = text.substr(open_at + 1, text.length() - open_at - 2)
	var args: PackedStringArray = PackedStringArray()
	for argument: String in EventSheetBlockRegistry.split_params_top_level(inner):
		args.append(argument.strip_edges())
	return {
		"indent": indent,
		"target": target,
		"verb": method.trim_prefix("_").capitalize(),
		"args": args
	}


## The leading identifier word of a line (`if`, `var`, `return`, or an assignment target's first
## word). Matching the WORD rather than a begins_with prefix is what keeps `elsewhere = 1` from
## reading as an `else` and being refused.
static func _leading_word(text: String) -> String:
	if _word_regex == null:
		_word_regex = RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*")
	var found: RegExMatch = _word_regex.search(text)
	return found.get_string(0) if found != null else ""


## True when `text` is a plain identifier - the only thing a "Let <name>" sentence may name.
static func _is_identifier(text: String) -> bool:
	if _identifier_regex == null:
		_identifier_regex = RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*$")
	return _identifier_regex.search(text) != null


## True when a left-hand side is a SIMPLE target: `hp`, `item.text`, `scores[0]`, `$HUD/Bar`,
## `%Unique`. A space or a `(` means something is being called, and no "Set X to Y" sentence can
## honestly describe assigning through a call.
static func _is_simple_target(text: String) -> bool:
	return not text.is_empty() and not text.contains(" ") and not text.contains("(")


## The index of the first `operator` at bracket/quote depth 0, or -1. A plain find() would split on
## the ` = ` inside `x = "a = b"` and produce a confidently wrong sentence.
static func _top_level_operator(text: String, operator: String) -> int:
	var depth: int = 0
	var quote: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote:
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		elif depth == 0 and text.substr(index, operator.length()) == operator:
			return index
		index += 1
	return -1


## The index of the first `(` outside any string literal, or -1 - where a call's head ends.
static func _first_open_paren(text: String) -> int:
	var quote: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote:
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == "(":
			return index
		index += 1
	return -1


## The index of the `)` that closes the `(` at `open_at`, or -1 when the line is unbalanced.
static func _closing_paren(text: String, open_at: int) -> int:
	var depth: int = 0
	var quote: String = ""
	var index: int = open_at
	while index < text.length():
		var character: String = text[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote:
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
			if depth == 0:
				return index
		index += 1
	return -1


## The class name ("" when not a match) if a RawCodeRow is EXACTLY a pure-data inner class: an optional
## leading prelude of blank/comment lines, then `class Name[ extends Base]:`, then a body of only typed
## fields (`var`/`const`/`@export`) and comments - no methods, no nested classes, no top-level code after
## it. This is the shape the compiler emits for a data holder (AbilityData and friends): it carries no
## logic, so it reads as a first-class "Data class" block (name chip + field rows) rather than a GDScript
## wall. A `func`, a second/nested class, or any dedented line rejects it (stays a real editable code block,
## so a method-bearing class never mis-lifts). Static + pure -> unit-testable without a viewport. See
## parse_data_class for the structured model and data_class_lifts for the byte-gate this feeds.
static func data_class_name(code: String) -> String:
	var lines: PackedStringArray = code.split("\n")
	var i: int = 0
	# Skip the leading prelude: blank lines and `#`/`##` comments (the class doc block).
	while i < lines.size():
		var stripped: String = lines[i].strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			i += 1
		else:
			break
	if i >= lines.size():
		return ""
	if _class_header_regex == null:
		_class_header_regex = RegEx.new()
		if _class_header_regex.compile("^class ([A-Za-z_][A-Za-z0-9_]*)(?: extends [A-Za-z_][A-Za-z0-9_.]*)?:$") != OK:
			return ""
	var header_match: RegExMatch = _class_header_regex.search(lines[i])
	if header_match == null:
		return ""
	i += 1
	# Every later non-blank line must be an indented field or comment. A dedented line (a second top-level
	# construct - func, class, or code) means this row is more than a lone data class, so it stays verbatim.
	var field_count: int = 0
	while i < lines.size():
		var body_line: String = lines[i]
		i += 1
		if body_line.strip_edges().is_empty():
			continue
		if not body_line.begins_with("\t"):
			return ""
		var inner: String = body_line.substr(1)  # one leading tab stripped for the keyword test
		if inner.begins_with("var ") or inner.begins_with("const ") or inner.begins_with("@export"):
			field_count += 1
		elif inner.begins_with("#"):
			pass  # a comment inside the class body - allowed, not counted as a field
		else:
			return ""  # a method, nested class, or any other statement - not a pure data class
	if field_count == 0:
		return ""  # an empty or comment-only class carries no editable fields; keep it verbatim
	return header_match.get_string(1)


## The class name ("" when not a match) if a RawCodeRow is a METHODS-bearing inner class: the same shape as
## data_class_name but the body may ALSO contain `func`/`static func` methods (and their deeper-indented
## bodies), and at least ONE method is required. Disjoint from data_class_name (which requires ZERO methods),
## so a class routes to exactly one recognizer. This feeds a pure-VIEW read-only class block (methods render
## as read-only chips) over an UNCHANGED RawCodeRow, so it is byte-safe by construction - the compiler never
## sees a structured nested class. A nested `class`, a dedent to column 0, or any other one-tab statement rejects.
static func methods_class_name(code: String) -> String:
	var lines: PackedStringArray = code.split("\n")
	var i: int = 0
	while i < lines.size():
		var stripped: String = lines[i].strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			i += 1
		else:
			break
	if i >= lines.size():
		return ""
	if _class_header_regex == null:
		_class_header_regex = RegEx.new()
		if _class_header_regex.compile("^class ([A-Za-z_][A-Za-z0-9_]*)(?: extends [A-Za-z_][A-Za-z0-9_.]*)?:$") != OK:
			return ""
	var header_match: RegExMatch = _class_header_regex.search(lines[i])
	if header_match == null:
		return ""
	i += 1
	var method_count: int = 0
	while i < lines.size():
		var body_line: String = lines[i]
		i += 1
		if body_line.strip_edges().is_empty():
			continue
		if not body_line.begins_with("\t"):
			return ""  # a dedent to column 0 - a second top-level construct, not this class
		var inner: String = body_line.substr(1)  # one leading tab stripped for the keyword test
		if inner.begins_with("func ") or inner.begins_with("static func "):
			method_count += 1
		elif inner.begins_with("\t"):
			continue  # a deeper-indented method / block body line - belongs to the method above
		elif inner.begins_with("var ") or inner.begins_with("const ") or inner.begins_with("@") or inner.begins_with("#"):
			pass  # a field, annotation, or comment member - allowed
		else:
			return ""  # a nested class header, bare code, or any other one-tab statement rejects
	if method_count == 0:
		return ""  # no method -> a pure-data class (or empty); not this recognizer
	return header_match.get_string(1)


## The structured, editable model of a pure-data inner class ({} when data_class_name rejects the code):
## { class_name, extends, prefix (verbatim lines before the header), header (verbatim class line), body }.
## `body` is one entry per body line: a canonical `\tvar name: Type[ = default]` becomes a structured field
## {kind:"field", name, type, default, has_default}; every other line (a comment, blank, const, @export, or
## a non-canonical var) is kept verbatim as {kind:"raw", text} so emit_data_class can reproduce it exactly.
## Static + pure so the model is unit-testable without a viewport.
static func parse_data_class(code: String) -> Dictionary:
	var class_name_str: String = data_class_name(code)
	if class_name_str.is_empty():
		return {}
	return _parse_class_body(code, class_name_str)


## The structured model of a methods-bearing inner class (see methods_class_name). Reuses the shared body
## parser: canonical `\tvar name: Type[ = default]` fields become {kind:"field"}, and every other line - the
## `\tfunc`/`\t\t` method lines, comments, @export - is kept verbatim as {kind:"raw"}, so emit_data_class
## reproduces the whole class (methods included) byte-for-byte. {} when methods_class_name rejects the code.
static func parse_methods_class(code: String) -> Dictionary:
	var class_name_str: String = methods_class_name(code)
	if class_name_str.is_empty():
		return {}
	return _parse_class_body(code, class_name_str)


## True only when a RawCodeRow is a methods-bearing class AND its structured model re-emits to the EXACT
## source (the view byte-gate). The render is a pure view over the unchanged RawCodeRow, so this only decides
## structured-vs-verbatim reading, never the emitted bytes.
static func methods_class_lifts(code: String) -> bool:
	var model: Dictionary = parse_methods_class(code)
	if model.is_empty():
		return false
	return emit_data_class(model) == code


## Shared body parser for a data class OR a methods class, given a pre-validated class name. Splits the
## verbatim prefix, the `class …:` header, and one body entry per line (structured fields, raw everything else).
static func _parse_class_body(code: String, class_name_str: String) -> Dictionary:
	var lines: PackedStringArray = code.split("\n")
	var i: int = 0
	var prefix: Array[String] = []
	while i < lines.size():
		var stripped: String = lines[i].strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			prefix.append(lines[i])
			i += 1
		else:
			break
	var header_line: String = lines[i]
	var extends_base: String = ""
	if _class_extends_regex == null:
		_class_extends_regex = RegEx.new()
		_class_extends_regex.compile("^class [A-Za-z_][A-Za-z0-9_]*(?: extends ([A-Za-z_][A-Za-z0-9_.]*))?:$")
	if _class_extends_regex.is_valid():
		var ext_match: RegExMatch = _class_extends_regex.search(header_line)
		if ext_match != null:
			extends_base = ext_match.get_string(1)
	i += 1
	if _class_var_default_regex == null:
		_class_var_default_regex = RegEx.new()
		_class_var_default_regex.compile("^\\tvar ([A-Za-z_][A-Za-z0-9_]*): (\\S.*?) = (.+)$")
	if _class_var_bare_regex == null:
		_class_var_bare_regex = RegEx.new()
		_class_var_bare_regex.compile("^\\tvar ([A-Za-z_][A-Za-z0-9_]*): (\\S.*)$")
	var with_default: RegEx = _class_var_default_regex
	var no_default: RegEx = _class_var_bare_regex
	var body: Array = []
	while i < lines.size():
		var line: String = lines[i]
		i += 1
		var field_match: RegExMatch = with_default.search(line)
		if field_match != null:
			body.append({
				"kind": "field",
				"name": field_match.get_string(1),
				"type": field_match.get_string(2),
				"default": field_match.get_string(3),
				"has_default": true
			})
			continue
		field_match = no_default.search(line)
		if field_match != null:
			body.append({
				"kind": "field",
				"name": field_match.get_string(1),
				"type": field_match.get_string(2),
				"default": "",
				"has_default": false
			})
			continue
		body.append({"kind": "raw", "text": line})
	return {
		"class_name": class_name_str,
		"extends": extends_base,
		"prefix": prefix,
		"header": header_line,
		"body": body
	}


## Re-emits a parse_data_class model back to GDScript text: the verbatim prefix, a reconstructed
## `class Name[ extends Base]:` header, then each body entry (a structured field rebuilt as
## `\tvar name: Type[ = default]`, a raw line passed through). Deterministic. data_class_lifts gates the
## round-trip: a class whose model does NOT reproduce its source byte-for-byte is never lifted.
static func emit_data_class(model: Dictionary) -> String:
	var out: PackedStringArray = PackedStringArray()
	for prefix_line: String in model.get("prefix", []):
		out.append(prefix_line)
	var base: String = str(model.get("extends", ""))
	if base.is_empty():
		out.append("class %s:" % str(model.get("class_name")))
	else:
		out.append("class %s extends %s:" % [str(model.get("class_name")), base])
	for entry: Dictionary in model.get("body", []):
		if str(entry.get("kind")) == "field":
			var line: String = "\tvar %s: %s" % [str(entry.get("name")), str(entry.get("type"))]
			if bool(entry.get("has_default", false)):
				line += " = %s" % str(entry.get("default"))
			out.append(line)
		else:
			out.append(str(entry.get("text")))
	return "\n".join(out)


## The byte-gate: true only when a RawCodeRow is a data class AND its structured model re-emits to the
## EXACT source. This is the covenant guard - a data class the model can reproduce lifts to an editable
## block; anything else (spacing quirks, defaults the field split cannot round-trip) stays a verbatim
## RawCodeRow. Static + pure so the gate is provable in a test the same way the compiler's is.
static func data_class_lifts(code: String) -> bool:
	var model: Dictionary = parse_data_class(code)
	if model.is_empty():
		return false
	return emit_data_class(model) == code


## Structured field ADD (the "add an action" gesture, for data classes): appends a canonical
## `\tvar name: Type[ = default]` to the class body and re-emits. "" when the code is not a
## LIFTING data class, the name is not a plain identifier, or a field with that name exists -
## the caller leaves the code untouched (degrade, never corrupt). Static + pure for tests.
static func data_class_add_field(code: String, field_name: String, field_type: String, default_value: String) -> String:
	if not data_class_lifts(code) or not field_name.is_valid_identifier() or field_type.strip_edges().is_empty():
		return ""
	var model: Dictionary = parse_data_class(code)
	for entry: Dictionary in model.get("body", []):
		if str(entry.get("kind")) == "field" and str(entry.get("name")) == field_name:
			return ""
	(model["body"] as Array).append({
		"kind": "field",
		"name": field_name,
		"type": field_type.strip_edges(),
		"default": default_value,
		"has_default": not default_value.is_empty()
	})
	return emit_data_class(model)


## Structured field REMOVE: drops the body entry at field_index (must be a field) and
## re-emits. "" when the code is not a lifting data class or the index is not a field.
static func data_class_remove_field(code: String, field_index: int) -> String:
	if not data_class_lifts(code):
		return ""
	var model: Dictionary = parse_data_class(code)
	var body: Array = model.get("body", [])
	if field_index < 0 or field_index >= body.size() or str((body[field_index] as Dictionary).get("kind")) != "field":
		return ""
	body.remove_at(field_index)
	return emit_data_class(model)


## A TOP-LEVEL structured collection declaration (a const table, a var default set): the same
## Declare treatment its in-body sibling gets - a header line, one single-cell line per entry,
## no bracket rows. Entries edit in place (edit_kind "decl_entry_line:-1:<entry>" - the -1 says
## the row's own resource IS the declaration), and the row menu offers Add/Edit/Remove Entry.
func _build_collection_decl_row(decl: CollectionDeclRow, indent: int) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = decl
	row_data.row_uid = "collection_decl_%d" % decl.get_instance_id()
	row_data.line_count = 1 + decl.entry_values.size()
	var decl_style: EventSheetEventStyle = _viewport._get_event_style()
	var spans: Array[SemanticSpan] = []
	spans.append(_make_span("Declare", SemanticSpan.SpanType.VALUE, {
		"editable": false,
		"kind": "collection_decl",
		"line_index": 0
	}))
	spans.append(_make_span(decl.variable_name(), SemanticSpan.SpanType.VALUE, {
		"editable": false,
		"kind": "collection_decl",
		"line_index": 0,
		"text_color": _viewport._get_reading_style().primary_text_color
	}))
	spans.append(_make_span("%s%s - %d %s" % ["const " if decl.is_constant() else "",
		"Dictionary" if decl.is_dictionary() else "Array", decl.entry_values.size(),
		"entry" if decl.entry_values.size() == 1 else "entries"],
		SemanticSpan.SpanType.VALUE, {
		"editable": false,
		"kind": "collection_decl",
		"line_index": 0,
		"text_color": decl_style.comment_text_color
	}))
	for entry_index: int in decl.entry_values.size():
		var entry_key: String = decl.entry_keys[entry_index] if entry_index < decl.entry_keys.size() else ""
		var entry_text: String = "        %s" % decl.entry_values[entry_index]
		if not entry_key.is_empty():
			entry_text = "        %s = %s" % [entry_key, decl.entry_values[entry_index]]
		spans.append(_make_span(entry_text, SemanticSpan.SpanType.VALUE, {
			"kind": "collection_decl",
			"decl_entry_index": entry_index,
			"editable": true,
			"edit_kind": "decl_entry_line:-1:%d" % entry_index,
			"line_index": entry_index + 1,
			"text_color": decl_style.value_highlight_color
		}))
	row_data.spans = spans
	return row_data


## A GDScript block row: verbatim code shown line-by-line, edited via the dock's code dialog
## (double-click), compiled at class level. The event-sheet-style "inline code" escape hatch.
## A row that is purely a published-verb annotation shell renders as ONE Define-style header line
## instead (role badge · friendly name · category chip) - a pure view over the same RawCodeRow, so
## editing (double-click opens the code dialog), selection, and the byte round-trip are untouched.
func _build_raw_code_row(raw_row: RawCodeRow, indent: int) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = raw_row
	row_data.row_uid = "raw_code_%d" % raw_row.get_instance_id()
	row_data.disabled = not raw_row.enabled or bool(_viewport._row_disabled_state.get(row_data.row_uid, false))
	# Host-binding boilerplate collapses to one muted "Host binding" line (pure view; the block's
	# lines are all still there and still edit/round-trip as before).
	var host_class: String = host_binding_class(raw_row.code)
	if not host_class.is_empty():
		# The generated `_enter_tree` host boilerplate reads as a first-class "Host binding" block: a badge,
		# the host CLASS as a distinct chip, and a muted cue. On an opened pack this prelude is verbatim .gd
		# (host is baked into the file), so the class stays read-only here - double-click opens the code
		# editor to change it (the RawCodeRow double-click at viewport_input.gd), keeping the byte round-trip.
		row_data.line_count = 1
		row_data.language_block = true  # generated host boilerplate - language structure, not an event
		# The same bar treatment the Class setup strip wears (band + 1.5x height + the host
		# class's own editor icon in the badge slot): these identity rows must never be mistaken
		# for a variable row - and the word pill is gone here too.
		row_data.height_scale = 1.5
		var host_accent: Color = _viewport._get_event_style().behavior_accent_color
		row_data.custom_color = Color(host_accent.r, host_accent.g, host_accent.b, 0.22)
		var host_badge_meta: Dictionary = {
			"editable": false,
			"badge": true,
			"badge_style": "trigger",
			"badge_bg": _viewport._get_reading_style().setup_badge_background_color,
			"badge_fg": _viewport._get_reading_style().setup_badge_foreground_color,
			"kind": "raw_code",
			"line_index": 0
		}
		var host_icon: Texture2D = ACEPickerDialog.editor_icon(host_class)
		if host_icon != null:
			host_badge_meta["badge_icon"] = host_icon
		row_data.spans = [
			_make_span("▣", SemanticSpan.SpanType.KEYWORD, host_badge_meta),
			_make_span(EventSheetL10n.translate("Host binding"), SemanticSpan.SpanType.VALUE, {
				"editable": false,
				"kind": "raw_code",
				"line_index": 0,
				"text_color": _viewport._get_reading_style().primary_text_color
			}),
			_make_span(host_class, SemanticSpan.SpanType.KEYWORD, {
				"editable": false,
				"badge": true,
				"badge_style": "scope",
				"badge_bg": _viewport._get_reading_style().plain_chip_background_color,
				"badge_fg": _viewport._get_reading_style().plain_chip_foreground_color,
				"kind": "raw_code",
				"line_index": 0
			}),
			_make_span("the node this behaviour is attached to · double-click to edit in code", SemanticSpan.SpanType.VALUE, {
				"editable": false,
				"kind": "raw_code",
				"line_index": 0,
				"text_color": _viewport._get_reading_style().muted_text_color
			})
		]
		return row_data
	var shell: Dictionary = define_shell_info(raw_row.code)
	if not shell.is_empty():
		row_data.line_count = 1  # visual collapse only - the underlying lines are all still there
		row_data.language_block = true  # a published-verb annotation shell - language structure
		# The kind badge takes the LIVE theme's role pair, the same one a published verb's own row
		# wears, so an Action shell and an Action verb are never two different ambers.
		var badge_colors: Dictionary = {
			"action": _define_role_colors("action"),
			"condition": _define_role_colors("condition"),
			"expression": _define_role_colors("expression"),
		}
		var kind: String = str(shell.get("kind"))
		var shell_spans: Array[SemanticSpan] = [
			_make_span(kind.capitalize(), SemanticSpan.SpanType.KEYWORD, {
				"editable": false,
				"badge": true,
				"badge_style": "scope",
				"badge_bg": (badge_colors[kind] as Array)[0],
				"badge_fg": (badge_colors[kind] as Array)[1],
				"kind": "raw_code",
				"line_index": 0
			}),
			_make_span(str(shell.get("name")), SemanticSpan.SpanType.OBJECT, {
				"editable": false,
				"kind": "raw_code",
				"line_index": 0,
				"text_color": _viewport._get_event_style().object_label_color
			})
		]
		if not str(shell.get("category")).is_empty():
			shell_spans.append(_make_span(str(shell.get("category")), SemanticSpan.SpanType.KEYWORD, {
				"editable": false,
				"badge": true,
				"badge_style": "scope",
				"badge_bg": _viewport._get_reading_style().category_chip_background_color,
				"badge_fg": _viewport._get_reading_style().category_chip_foreground_color,
				"kind": "raw_code",
				"line_index": 0
			}))
		shell_spans.append(_make_span("publishes the func below · %d annotation lines" % int(shell.get("line_count")), SemanticSpan.SpanType.VALUE, {
			"editable": false,
			"kind": "raw_code",
			"line_index": 0,
			"text_color": _viewport._get_reading_style().muted_text_color
		}))
		row_data.spans = shell_spans
		return row_data
	# A pure-data inner class (a `class X:` of only typed fields - AbilityData and friends) reads as a
	# first-class "Data class" block: a badge, the class name as a chip, and its fields as foldable child
	# rows (name : type = default), instead of a raw GDScript wall. Byte-gated: only a class whose structured
	# model re-emits to the exact source lifts (data_class_lifts); everything else stays a verbatim block, so
	# the .gd round-trip is never at risk. Phase 1 renders the fields read-only (inert child rows); editing
	# them in place is the next slice. Double-click still opens the code editor as the escape hatch.
	if data_class_lifts(raw_row.code):
		return _build_data_class_row(raw_row, indent)
	# A methods-bearing inner class (a `class X:` with methods, not just data) reads as a foldable, READ-ONLY
	# class block: the class in the condition cell, and its fields + a `ƒ name(params) -> Type` chip per method
	# as child rows, instead of a GDScript wall. Byte-gated (methods_class_lifts) and a pure view over the
	# unchanged RawCodeRow, so the .gd round-trip is never at risk; double-click opens the code editor.
	if methods_class_lifts(raw_row.code):
		return _build_methods_class_row(raw_row, indent)
	# A lone top-level function (a helper the importer could not lift) collapses to a `ƒ name(params) ->
	# Type` header + line count, so it reads as a FUNCTION, not a raw GDScript wall - the same view-only
	# collapse as host-binding and annotation shells above. Double-click still opens the code dialog.
	# A multi-line collection literal (a table of constants, a defaults dictionary) collapses to its
	# head line plus an entry count, so a value reads as one value instead of a wall of code. Pure
	# view over the unchanged row - double-click opens the code editor to read or edit the entries.
	var literal_info: Dictionary = data_literal_info(raw_row.code)
	if not literal_info.is_empty():
		row_data.line_count = 1
		row_data.language_block = true
		var literal_style: EventSheetEventStyle = _viewport._get_event_style()
		row_data.spans = [
			_make_span("{}" if str(literal_info.get("head")).ends_with("{") else "[]", SemanticSpan.SpanType.KEYWORD, {
				"editable": false,
				"badge": true,
				"badge_style": "scope",
				"badge_bg": _viewport._get_reading_style().code_badge_background_color,
				"badge_fg": _viewport._get_reading_style().code_badge_foreground_color,
				"kind": "raw_code",
				"line_index": 0
			}),
			_make_span("%s %s" % [str(literal_info.get("head")), str(literal_info.get("close"))],
				SemanticSpan.SpanType.OBJECT, {
					"editable": false,
					"kind": "raw_code",
					"line_index": 0,
					"text_color": _viewport._get_reading_style().primary_text_color
				}),
			_make_span("%d entries" % int(literal_info.get("entries", 0)), SemanticSpan.SpanType.COMMENT, {
				"editable": false,
				"kind": "raw_code",
				"line_index": 0,
				"text_color": literal_style.comment_text_color
			})
		]
		return row_data
	var function_info: Dictionary = function_body_info(raw_row.code)
	if not function_info.is_empty():
		row_data.line_count = 1
		row_data.language_block = true  # a collapsed function header - language structure, not an event
		# `while true: await get_tree().create_timer(x).timeout` is a beat, not a helper: the
		# function exists to run its body every x seconds. It reads as that beat, with the loop's own
		# lines as its content (the card opens to the exact GDScript, unchanged).
		var loop_seconds: String = await_loop_seconds(raw_row.code)
		if not loop_seconds.is_empty():
			row_data.spans = _await_loop_trigger_spans(loop_seconds)
			return row_data
		var function_spans: Array[SemanticSpan] = [
			_make_span("ƒ", SemanticSpan.SpanType.KEYWORD, {
				"editable": false,
				"badge": true,
				"badge_style": "scope",
				"badge_bg": _viewport._get_reading_style().code_badge_background_color,
				"badge_fg": _viewport._get_reading_style().code_badge_foreground_color,
				"kind": "raw_code",
				"line_index": 0
			}),
			_make_span("%s(%s)" % [str(function_info.get("name")), str(function_info.get("params"))], SemanticSpan.SpanType.OBJECT, {
				"editable": false,
				"kind": "raw_code",
				"line_index": 0,
				"text_color": _viewport._get_event_style().object_label_color
			})
		]
		if str(function_info.get("return_type")) != "void":
			function_spans.append(_make_span("→ %s" % str(function_info.get("return_type")), SemanticSpan.SpanType.KEYWORD, {
				"editable": false,
				"badge": true,
				"badge_style": "scope",
				"badge_bg": _viewport._get_reading_style().plain_chip_background_color,
				"badge_fg": _viewport._get_reading_style().plain_chip_foreground_color,
				"kind": "raw_code",
				"line_index": 0
			}))
		var body_line_count: int = int(function_info.get("body_lines"))
		function_spans.append(_make_span("function · %d line%s" % [body_line_count, "" if body_line_count == 1 else "s"], SemanticSpan.SpanType.VALUE, {
			"editable": false,
			"kind": "raw_code",
			"line_index": 0,
			"text_color": _viewport._get_reading_style().muted_text_color
		}))
		row_data.spans = function_spans
		return row_data
	var code_lines: PackedStringArray = raw_row.code.split("\n")
	row_data.line_count = maxi(code_lines.size(), 1)
	# A block that is ENTIRELY comment lines (## doc comments, # notes) reads as a comment, not code:
	# no code/"setup" badge, and the leading # is dropped from the display (we are already visibly a
	# comment). The raw code stays the serialization truth - these spans are display-only. A wholly BLANK
	# block (a round-trip spacing separator) takes the same badge-less path so it renders as quiet empty
	# space, never an empty "GDScript" pill.
	if is_comment_only_block(code_lines) or is_blank_block(code_lines):
		var comment_style: EventSheetEventStyle = _viewport._get_event_style()
		var note_spans: Array[SemanticSpan] = []
		for note_index in range(code_lines.size()):
			var shown: String = strip_comment_prefix(code_lines[note_index])
			note_spans.append(_make_span(
				shown if not shown.is_empty() else " ",
				SemanticSpan.SpanType.COMMENT,
				{"editable": false, "kind": "raw_code", "line_index": note_index, "text_color": comment_style.comment_text_color}
			))
		row_data.spans = note_spans
		return row_data
	# Type-aware styling: boilerplate reads dimmer (no label) while real logic keeps the brighter
	# "GDScript" badge + primary text. Same row, no codegen change.
	var is_scaffold: bool = _viewport.is_scaffolding_code(raw_row.code)
	var line_fg: Color = _viewport._get_reading_style().muted_text_color if is_scaffold else _viewport._get_reading_style().primary_text_color
	var spans: Array[SemanticSpan] = []
	# Scaffold blocks carry NO "GDScript" pill: they live under the Class setup dropdown, whose
	# facts already say what they are - the pill was pure noise there (and a word in a box). The
	# pill stays on REAL logic blocks only, where it marks the escape hatch.
	if not is_scaffold:
		spans.append(_make_span(EventSheetL10n.translate("Script block"), SemanticSpan.SpanType.KEYWORD, {
			"editable": false,
			"badge": true,
			"badge_style": "scope",
			"badge_bg": _viewport._get_reading_style().code_badge_background_color,
			"badge_fg": _viewport._get_reading_style().code_badge_foreground_color,
			"kind": "raw_code",
			"line_index": 0
		}))
	# The importer sets lift_note on a block it could NOT lift into structured rows ("no matching ACE
	# template"). Surface it as an inline amber badge - the actionable "why this stayed code" cue - in
	# addition to the hover tooltip, so a wall of blocks becomes a triage list at a glance.
	if not raw_row.lift_note.strip_edges().is_empty():
		spans.append(_make_span("⚠ code", SemanticSpan.SpanType.KEYWORD, {
			"editable": false,
			"badge": true,
			"badge_style": "scope",
			"badge_bg": _viewport._get_reading_style().lift_note_badge_background_color,
			"badge_fg": _viewport._get_reading_style().lift_note_badge_foreground_color,
			"kind": "lift_note",
			"line_index": 0
		}))
	# ── the folded code card ───────────────────────────────────────────────────────────────────
	# A block that could not lift is a wall of statements you did not ask to read. While READING a
	# sheet it costs one row - "code · 12 lines" - and opens in place to the exact GDScript; while
	# AUTHORING one the statement lines stay put, because those are what you edit. The fold rides
	# the CHILD-row mechanism the enum fold already uses, so the arrow, the click, the keyboard
	# fold and the fold memory all work here without a line of new interaction code.
	if _viewport.is_reading_mode() and code_lines.size() > 1:
		spans.append(_make_span(
			EventSheetViewportReadingRows.code_card_label(code_lines.size()),
			SemanticSpan.SpanType.VALUE,
			{"editable": false, "kind": "raw_code", "line_index": 0, "text_color": _viewport._get_reading_style().muted_text_color}
		))
		row_data.spans = spans
		row_data.line_count = 1
		row_data.folded = bool(_viewport._fold_state.get(
			row_data.row_uid,
			EventSheetViewportReadingRows.code_card_default_folded(true)
		))
		var opened := EventRowData.new()
		opened.indent = indent + 1
		opened.row_type = EventRowData.RowType.SECTION
		opened.source_resource = raw_row
		opened.row_uid = "%s_code" % row_data.row_uid
		opened.line_count = code_lines.size()
		opened.spans = _raw_code_line_spans(code_lines, line_fg)
		row_data.children = [opened]
		return row_data
	spans.append_array(_raw_code_line_spans(code_lines, line_fg))
	row_data.spans = spans
	return row_data


## The exact GDScript of a raw block, one span per source line. Shared by the ordinary authoring
## render and by what a code card opens to, so "the code" is literally the same rows either
## way and the two can never drift into showing different text.
func _raw_code_line_spans(code_lines: PackedStringArray, line_fg: Color) -> Array[SemanticSpan]:
	var line_spans: Array[SemanticSpan] = []
	for line_index: int in range(code_lines.size()):
		line_spans.append(_make_span(
			code_lines[line_index] if not code_lines[line_index].is_empty() else " ",
			SemanticSpan.SpanType.VALUE,
			{
				"editable": false,
				"kind": "raw_code",
				"line_index": line_index,
				"text_color": line_fg
			}
		))
	return line_spans


## Builds the foldable "Data class" block for a RawCodeRow that data_class_lifts recognises: a one-line
## header (badge · class-name chip · optional extends · field-count cue) whose children are the class's
## fields, each rendered as a `name : type = default` row like a variable. Double-clicking a field's name,
## type or default value edits it inline; the edit re-emits the class from its structured model through the
## undo funnel (deterministic, and - because the model reproduced the source byte-for-byte to lift in the
## first place - an edit changes ONLY the touched field's line, nothing else in the class). The header keeps
## its RawCodeRow as source_resource so double-click there opens the code editor (the escape hatch); the
## field rows stay inert (source null) for selection / drag / delete so only the value edit can change them.
## row_uid is class-name-keyed so an expanded block survives the undo funnel's resource rebuild.
func _build_data_class_row(raw_row: RawCodeRow, indent: int) -> EventRowData:
	var model: Dictionary = parse_data_class(raw_row.code)
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.EVENT  # reads like a regular event row (condition | action lanes), not a dimmed block
	row_data.source_resource = raw_row
	row_data.line_count = 1  # visual collapse only - the underlying lines are all still there
	var data_class_display_name: String = str(model.get("class_name"))
	# Uid scope, NOT the display name: same-named repeats get a "-2" suffix so their rows
	# never alias (selection/disabled state used to mirror between same-named classes).
	var data_class_name_str: String = _unique_class_scope(data_class_display_name, raw_row)
	row_data.row_uid = "data_class_%s" % data_class_name_str
	row_data.language_block = true  # a class declaration, not a regular ACE event - gets the language stripe
	row_data.disabled = not raw_row.enabled or bool(_viewport._row_disabled_state.get(row_data.row_uid, false))
	var body: Array = model.get("body", [])
	# Count what will render: every field plus every non-blank @export / const / comment line (all body
	# members show, so an @export- or const-only class never reads "0 fields" with its members hidden).
	# editable_count is the plain `var` fields whose default value can be double-clicked to edit.
	var member_count: int = 0
	var editable_count: int = 0
	for entry: Dictionary in body:
		if str(entry.get("kind")) == "field":
			member_count += 1
			editable_count += 1
		elif not str(entry.get("text")).strip_edges().is_empty():
			member_count += 1
	# The class header reads like a regular event row - no dimmed "Data class" pill: its declaration
	# (`class Name [extends Base]`) in the CONDITION cell, its field count in the ACTION cell, and its
	# fields as condition/action child rows below.
	var condition_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	var action_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_action_style())
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var base: String = str(model.get("extends", ""))
	# What a pure-data `class X:` IS, in the words a reader has for it: a data type this file
	# declares, whose fields are the rows below. "class" is GDScript's spelling of the same thing and
	# stays one double-click away, in the code the bar opens.
	var header_text: String = "%s %s" % [EventSheetL10n.translate("Data type"), data_class_display_name]
	if not base.is_empty():
		header_text += " %s %s" % [EventSheetL10n.translate("based on"), base]
	var header_spans: Array[SemanticSpan] = [
		_make_span(header_text, SemanticSpan.SpanType.OBJECT, {
			"lane": "condition",
			"editable": false,
			"kind": "raw_code",
			"line_index": 0,
			"text_color": event_style.object_label_color
		}.merged(condition_style, true))
	]
	var cue: String = "%d field%s" % [member_count, "" if member_count == 1 else "s"]
	if editable_count > 0:
		cue += " · double-click a default to edit"
	header_spans.append(_make_span(cue, SemanticSpan.SpanType.VALUE, {
		"lane": "action",
		"editable": false,
		"kind": "raw_code",
		"line_index": 0,
		"text_color": event_style.value_highlight_color
	}.merged(action_style, true)))
	row_data.spans = header_spans
	for body_index: int in range(body.size()):
		var entry: Dictionary = body[body_index]
		if str(entry.get("kind")) == "field":
			row_data.children.append(_build_data_class_field_row(raw_row, data_class_name_str, body_index, entry, indent + 1))
		elif not str(entry.get("text")).strip_edges().is_empty():
			# @export / const / comment members render verbatim and READ-ONLY (inert). Editing the default of
			# a plain `var` field is the editable path; these keep the block honest - no hidden declarations.
			row_data.children.append(_build_data_class_member_row(data_class_name_str, body_index, str(entry.get("text")), indent + 1))
	if not row_data.children.is_empty():
		row_data.folded = bool(_viewport._fold_state.get(row_data.row_uid, true))
	return row_data


## One field of a "Data class" block, mapped onto the sheet's condition/action model: the field IDENTITY
## (name : type) reads in the CONDITION cell, its DEFAULT in the ACTION cell (set it to X). ONLY the default
## is editable - double-clicking it carries {data_class_field_edit, part:"default", field_index, raw_row}
## that fires data_class_field_edit_requested -> the same inline editor an ACE param uses -> the commit
## re-emits the class through the undo funnel (see inline_param_editor.gd). Name and type are read-only on
## purpose: renaming or retyping a field would leave every use site in the .gd untouched and silently break
## it (needs whole-file reference awareness, a later slice). row_type EVENT gives the condition | action lane
## divider; source_resource stays null so selection / drag / delete skip it (spans editable:false keep the
## caret editor away too), and only the default-value gesture can change it. A per-field row_uid stops one
## blank uid from highlighting every field row together.
func _build_data_class_field_row(raw_row: RawCodeRow, class_name_str: String, field_index: int, field: Dictionary, indent: int) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.EVENT
	row_data.source_resource = null
	row_data.line_count = 1
	row_data.row_uid = "data_class_field_%s_%d" % [class_name_str, field_index]
	row_data.language_block = true  # a field of a class block - carries the language stripe like its header
	var condition_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	var action_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_action_style())
	# Condition cell: what the field IS (name : type).
	# Every span carries raw_row + field_index, so a right-click ANYWHERE on the field row
	# resolves the field for the context menu's Remove Field (not just on the default value).
	var spans: Array[SemanticSpan] = [
		_make_span(str(field.get("name")), SemanticSpan.SpanType.OBJECT, {
			"lane": "condition",
			"editable": false,
			"kind": "data_class_field",
			"field_index": field_index,
			"raw_row": raw_row,
			"line_index": 0,
			"text_color": _viewport._get_event_style().object_label_color
		}.merged(condition_style, true)),
		_make_span(":", SemanticSpan.SpanType.OPERATOR, {"lane": "condition", "editable": false, "kind": "data_class_field", "field_index": field_index, "raw_row": raw_row, "line_index": 0}.merged(condition_style, true)),
		_make_span(str(field.get("type")), SemanticSpan.SpanType.VALUE, {
			"lane": "condition",
			"editable": false,
			"kind": "data_class_field",
			"field_index": field_index,
			"raw_row": raw_row,
			"line_index": 0,
			"text_color": _viewport._get_reading_style().muted_text_color
		}.merged(condition_style, true))
	]
	# Action cell: its default value (the editable part).
	if bool(field.get("has_default", false)):
		spans.append(_make_span("=", SemanticSpan.SpanType.OPERATOR, {"lane": "action", "editable": false, "kind": "data_class_field", "field_index": field_index, "raw_row": raw_row, "line_index": 0}.merged(action_style, true)))
		spans.append(_make_span(str(field.get("default")), SemanticSpan.SpanType.VALUE, {
			"lane": "action",
			"editable": false,
			"kind": "data_class_field",
			"data_class_field_edit": true,
			"part": "default",
			"field_index": field_index,
			"raw_row": raw_row,
			"line_index": 0,
			"text_color": _viewport._get_event_style().value_highlight_color
		}.merged(action_style, true)))
	row_data.spans = spans
	return row_data


## An @export / const / comment member of a "Data class" block: shown verbatim and READ-ONLY (source null,
## no edit descriptor) in the CONDITION cell, so the expanded block reveals every declaration - not only
## plain `var` fields - while still reading on the condition/action model. Editing these in place is out of
## scope (an @export/const often carries Inspector/const semantics a one-line edit cannot honour); the
## double-click-header code editor remains the way to change them. A per-member row_uid keeps selection from
## highlighting siblings.
func _build_data_class_member_row(class_name_str: String, body_index: int, text: String, indent: int) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.EVENT
	row_data.source_resource = null
	row_data.line_count = 1
	row_data.row_uid = "data_class_member_%s_%d" % [class_name_str, body_index]
	row_data.language_block = true  # a member of a class block - carries the language stripe like its header
	var condition_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	row_data.spans = [
		_make_span(text.strip_edges(), SemanticSpan.SpanType.VALUE, {
			"lane": "condition",
			"editable": false,
			"kind": "data_class_field",
			"line_index": 0,
			"text_color": _viewport._get_reading_style().muted_text_color
		}.merged(condition_style, true))
	]
	return row_data


## A methods-bearing inner class (methods_class_name) rendered as a foldable, READ-ONLY block: the class in
## the condition cell, its field + method counts in the action cell, and each field (read-only) plus a
## `ƒ name(params) -> Type` chip per method as child rows. Pure view - the RawCodeRow stays the source
## (double-click opens the code editor), nothing is editable here, so the byte round-trip is untouched.
func _build_methods_class_row(raw_row: RawCodeRow, indent: int) -> EventRowData:
	var model: Dictionary = parse_methods_class(raw_row.code)
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.EVENT
	row_data.source_resource = raw_row
	row_data.line_count = 1
	var class_display_name: String = str(model.get("class_name"))
	# Uid scope, NOT the display name (same-named repeats suffix "-2" so rows never alias).
	var class_name_str: String = _unique_class_scope(class_display_name, raw_row)
	row_data.row_uid = "methods_class_%s" % class_name_str
	row_data.language_block = true  # a class declaration, not a regular ACE event - gets the language stripe
	row_data.disabled = not raw_row.enabled or bool(_viewport._row_disabled_state.get(row_data.row_uid, false))
	var body: Array = model.get("body", [])
	var condition_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	var action_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_action_style())
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var base: String = str(model.get("extends", ""))
	var header_text: String = "class %s" % class_display_name
	if not base.is_empty():
		header_text += " extends %s" % base
	var field_count: int = 0
	var method_count: int = 0
	for entry: Dictionary in body:
		if str(entry.get("kind")) == "field":
			field_count += 1
			continue
		var member_text: String = str(entry.get("text"))
		if member_text.begins_with("\tfunc ") or member_text.begins_with("\tstatic func "):
			method_count += 1
		elif member_text.begins_with("\t@export") or member_text.begins_with("\tconst "):
			field_count += 1  # a one-tab @export / const member also counts toward the field cue
	var header_spans: Array[SemanticSpan] = [
		_make_span(header_text, SemanticSpan.SpanType.OBJECT, {
			"lane": "condition", "editable": false, "kind": "raw_code", "line_index": 0,
			"text_color": event_style.object_label_color
		}.merged(condition_style, true))
	]
	var cue_parts: PackedStringArray = PackedStringArray()
	if field_count > 0:
		cue_parts.append("%d field%s" % [field_count, "" if field_count == 1 else "s"])
	cue_parts.append("%d method%s" % [method_count, "" if method_count == 1 else "s"])
	header_spans.append(_make_span(" · ".join(cue_parts), SemanticSpan.SpanType.VALUE, {
		"lane": "action", "editable": false, "kind": "raw_code", "line_index": 0,
		"text_color": event_style.value_highlight_color
	}.merged(action_style, true)))
	row_data.spans = header_spans
	# Walk the body, collapsing each method (its `\tfunc` header + deeper `\t\t` body lines) into ONE chip row.
	var child_index: int = 0
	var k: int = 0
	while k < body.size():
		var entry: Dictionary = body[k]
		if str(entry.get("kind")) == "field":
			var field_text: String = "var %s: %s" % [str(entry.get("name")), str(entry.get("type"))]
			if bool(entry.get("has_default", false)):
				field_text += " = %s" % str(entry.get("default"))
			row_data.children.append(_build_data_class_member_row(class_name_str, child_index, field_text, indent + 1))
			child_index += 1
			k += 1
			continue
		var text: String = str(entry.get("text"))
		if text.strip_edges().is_empty():
			k += 1
			continue
		if text.begins_with("\tfunc ") or text.begins_with("\tstatic func "):
			var method_lines: PackedStringArray = PackedStringArray([text.substr(1)])  # dedent one tab
			k += 1
			while k < body.size() and str(body[k].get("kind")) != "field":
				var next_text: String = str(body[k].get("text"))
				if next_text.strip_edges().is_empty() or next_text.begins_with("\t\t"):
					method_lines.append(next_text.substr(1) if next_text.begins_with("\t") else next_text)
					k += 1
				else:
					break  # a sibling one-tab member starts here
			row_data.children.append(_build_class_method_row(class_name_str, child_index, method_lines, indent + 1))
			child_index += 1
			continue
		# A one-tab comment or annotation member (a `## doc` or `@rpc` above a method).
		row_data.children.append(_build_data_class_member_row(class_name_str, child_index, text, indent + 1))
		child_index += 1
		k += 1
	if not row_data.children.is_empty():
		row_data.folded = bool(_viewport._fold_state.get(row_data.row_uid, true))
	return row_data


## One method of a methods-class block, collapsed to a read-only `ƒ name(params) -> Type` chip plus a
## body-line count. method_lines is the method dedented one tab (header at column 0). Read-only (source null);
## the block header's double-click opens the code editor to change the method.
func _build_class_method_row(class_name_str: String, child_index: int, method_lines: PackedStringArray, indent: int) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.EVENT
	row_data.source_resource = null
	row_data.line_count = 1
	row_data.row_uid = "methods_class_method_%s_%d" % [class_name_str, child_index]
	row_data.language_block = true  # a method chip of a class block - carries the language stripe
	if _method_header_regex == null:
		_method_header_regex = RegEx.new()
		_method_header_regex.compile("^(static )?func ([A-Za-z_][A-Za-z0-9_]*)\\((.*)\\)(?: -> (.+))?:$")
	var header_match: RegExMatch = _method_header_regex.search(method_lines[0])
	var label: String = method_lines[0].strip_edges()
	if header_match != null:
		var static_prefix: String = "static " if not header_match.get_string(1).is_empty() else ""
		var ret: String = header_match.get_string(4)
		label = "ƒ %s%s(%s) -> %s" % [static_prefix, header_match.get_string(2), header_match.get_string(3), ret if not ret.is_empty() else "void"]
	var body_line_count: int = 0
	for j: int in range(1, method_lines.size()):
		if not method_lines[j].strip_edges().is_empty():
			body_line_count += 1
	var condition_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	var action_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_action_style())
	var spans: Array[SemanticSpan] = [
		_make_span(label, SemanticSpan.SpanType.OBJECT, {
			"lane": "condition", "editable": false, "kind": "raw_code", "line_index": 0,
			"text_color": _viewport._get_event_style().object_label_color
		}.merged(condition_style, true))
	]
	if body_line_count > 0:
		spans.append(_make_span("%d line%s" % [body_line_count, "" if body_line_count == 1 else "s"], SemanticSpan.SpanType.VALUE, {
			"lane": "action", "editable": false, "kind": "raw_code", "line_index": 0,
			"text_color": _viewport._get_reading_style().muted_text_color
		}.merged(action_style, true)))
	row_data.spans = spans
	return row_data


## An `@onready var hp_bar: ProgressBar = %HpBar` read as an OBJECT declaration rather than
## as a value one: this is how an event sheet's object list is recovered from a script. The row says
## what the object is called, which node it is, and its class - with the class's own Godot icon,
## the same icon every later row using `hp_bar` as its object then shows.
##
## Reading mode only. While AUTHORING, the @onready variable row stays exactly as it was: it is
## the row the variable dialog edits, and re-shaping an editable row would be a lens with
## consequences. Returns null when the variable is not an object declaration.
func _build_object_declaration_row(variable: LocalVariable, indent: int) -> EventRowData:
	if not _viewport.is_reading_mode() or not EventSheetViewportReadingRows.is_object_declaration(variable):
		return null
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = variable
	row_data.row_uid = "variable_tree_%d" % variable.get_instance_id()
	row_data.line_count = 1
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	# ── lens hook ──────────────────────────────────────────────────────────────────────────────
	# A `get_node("A/B")` lookup names the same object `$A/B` does, so it reads as that reference -
	# and the `_or_null` spelling says, in the muted note, that the object may not be there.
	var declaration_value: Dictionary = EventSheetViewportReadingRows.object_declaration_value(variable)
	var node_reference: String = str(declaration_value.get("value", ""))
	var missing_note: String = str(declaration_value.get("note", ""))
	var declared_class: String = EventSheetViewportReadingRows.declared_class_of(variable)
	# The object's NAME is not humanized, even with the lens on: this row is where the object gets
	# its identity, and every later row refers to it by exactly this spelling. An event sheet shows an
	# object's name verbatim in its object list for the same reason.
	var shown_name: String = variable.name
	var spans: Array[SemanticSpan] = [
		_make_span(EventSheetL10n.translate("Object"), SemanticSpan.SpanType.KEYWORD, {
			"editable": false, "kind": "variable", "line_index": 0, "badge": true, "badge_style": "scope",
			"badge_bg": _viewport._get_reading_style().inspector_chip_background_color, "badge_fg": _viewport._get_reading_style().inspector_chip_foreground_color
		}),
		_make_span(shown_name, SemanticSpan.SpanType.OBJECT, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": event_style.object_label_color
		}),
		_make_span("=", SemanticSpan.SpanType.OPERATOR, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": _viewport._get_reading_style().muted_text_color
		}),
		_make_span(node_reference, SemanticSpan.SpanType.VALUE, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": event_style.value_highlight_color,
			"object_icon": _reading_class_icon_for(node_reference)
		})
	]
	if not declared_class.is_empty():
		spans.append(_make_span(declared_class, SemanticSpan.SpanType.COMMENT, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": _viewport._get_reading_style().muted_text_color
		}))
	if not missing_note.is_empty():
		spans.append(_make_span(missing_note, SemanticSpan.SpanType.COMMENT, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": _viewport._get_reading_style().muted_text_color
		}))
	row_data.spans = spans
	return row_data


## A preloaded scene, script or resource is an OBJECT, not a value: `bullet_scene` holding
## `preload("res://bullet.tscn")` reads `Object bullet_scene = Bullet  scene · bullet.tscn`, with the
## scene root's own class icon. The res:// path is punctuation to a reader; the THING at the end of it
## is what they are looking for, and the file name stays as the muted receipt. Returns null when the
## value is not a preload/load of a project path.
## Display-only: `source` and `row_uid` come from whatever row carried the preload (a lifted
## LocalVariable or a `preload` block), so selection and the byte round-trip are untouched.
func _build_preload_object_row(object_name: String, res_path: String, indent: int, source: Resource,
		row_uid: String) -> EventRowData:
	var resolved: Dictionary = resolve_res_object(res_path)
	if resolved.is_empty():
		return null
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = source
	row_data.row_uid = row_uid
	row_data.line_count = 1
	var icon_class: String = str(resolved.get("icon_class", ""))
	var icon: Texture2D = null
	if _viewport.show_object_icons and not icon_class.is_empty():
		icon = ACEPickerDialog.editor_icon(icon_class)
	row_data.spans = [
		_make_span(EventSheetL10n.translate("Object"), SemanticSpan.SpanType.KEYWORD, {
			"editable": false, "kind": "variable", "line_index": 0, "badge": true, "badge_style": "scope",
			"badge_bg": _viewport._get_reading_style().inspector_chip_background_color, "badge_fg": _viewport._get_reading_style().inspector_chip_foreground_color
		}),
		_make_span(object_name, SemanticSpan.SpanType.OBJECT, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": event_style.object_label_color
		}),
		_make_span("=", SemanticSpan.SpanType.OPERATOR, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": _viewport._get_reading_style().muted_text_color
		}),
		_make_span(str(resolved.get("name", "")), SemanticSpan.SpanType.VALUE, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": event_style.value_highlight_color,
			"object_icon": icon
		}),
		_make_span("%s · %s" % [str(resolved.get("kind_word", "")), res_path.get_file()], SemanticSpan.SpanType.COMMENT, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": _viewport._get_reading_style().muted_text_color
		})
	]
	return row_data


## The res:// path a `preload(...)` / `load(...)` expression names, "" when the text is not one.
static func preloaded_path(expression: String) -> String:
	if _preload_regex == null:
		_preload_regex = RegEx.new()
		_preload_regex.compile("^(?:preload|load)\\(\\s*\"(res://[^\"]+)\"\\s*\\)$")
	var found: RegExMatch = _preload_regex.search(expression.strip_edges())
	return found.get_string(1) if found != null else ""


static var _preload_regex: RegEx = null
static var _res_object_cache: Dictionary = {}


## What sits at the end of a res:// path, as {name, kind_word, icon_class} - the noun a reader wants
## instead of the path. A scene answers with its ROOT NODE (name and class, straight from the
## `[node ...]` line, which is the first node the file lists); a resource with the class it was saved
## as (its `script_class` when it has one, because that is the name the author gave it); a script with
## its `class_name`. Anything else keeps its file name, which is all a .png or a .ogg has to give.
## Returns {} for a path the project does not have, so the caller can fall back to the plain value.
## Parsed off DISK and cached per session - these files do not change while a sheet is open, and the
## reader would otherwise re-read them on every redraw.
static func resolve_res_object(res_path: String) -> Dictionary:
	if res_path.is_empty():
		return {}
	if _res_object_cache.has(res_path):
		return _res_object_cache[res_path]
	var resolved: Dictionary = {}
	if FileAccess.file_exists(res_path):
		match res_path.get_extension().to_lower():
			"tscn":
				resolved = _resolve_scene_object(res_path)
			"tres":
				resolved = _resolve_resource_object(res_path)
			"gd":
				resolved = _resolve_script_object(res_path)
			_:
				resolved = {
					"name": res_path.get_file().get_basename(),
					"kind_word": res_path.get_extension().to_lower(),
					"icon_class": ""
				}
	_res_object_cache[res_path] = resolved
	return resolved


static func _resolve_scene_object(res_path: String) -> Dictionary:
	var root: Dictionary = scene_root_of(res_path)
	if root.is_empty():
		return {}
	return {
		"name": str(root.get("name", "")),
		"kind_word": EventSheetL10n.translate("scene"),
		"icon_class": str(root.get("type", ""))
	}


static func _resolve_resource_object(res_path: String) -> Dictionary:
	var handle: FileAccess = FileAccess.open(res_path, FileAccess.READ)
	if handle == null:
		return {}
	var header: String = handle.get_line()
	handle.close()
	var script_class: String = _quoted_attribute(header, "script_class")
	var base_type: String = _quoted_attribute(header, "type")
	var shown: String = script_class if not script_class.is_empty() else base_type
	if shown.is_empty():
		shown = res_path.get_file().get_basename()
	return {"name": shown, "kind_word": EventSheetL10n.translate("resource"), "icon_class": base_type}


static func _resolve_script_object(res_path: String) -> Dictionary:
	var handle: FileAccess = FileAccess.open(res_path, FileAccess.READ)
	if handle == null:
		return {}
	var shown: String = ""
	var base_type: String = ""
	while not handle.eof_reached():
		var line: String = handle.get_line().strip_edges()
		if line.begins_with("class_name "):
			shown = line.substr("class_name ".length()).strip_edges()
		elif line.begins_with("extends "):
			base_type = line.substr("extends ".length()).strip_edges()
		elif line.begins_with("func ") or line.begins_with("var ") or line.begins_with("const "):
			break
	handle.close()
	if shown.is_empty():
		shown = res_path.get_file().get_basename()
	return {"name": shown, "kind_word": EventSheetL10n.translate("script"), "icon_class": base_type}


## The root node of a .tscn as {name, type}, read straight off the text: the FIRST `[node ...]` line
## is the root by the scene format's own rule. {} when the file cannot be read or lists no node. An
## instanced root (`instance=ExtResource(...)`) declares no type, so only the name comes back.
static func scene_root_of(scene_path: String) -> Dictionary:
	var handle: FileAccess = FileAccess.open(scene_path, FileAccess.READ)
	if handle == null:
		return {}
	while not handle.eof_reached():
		var line: String = handle.get_line()
		if not line.begins_with("[node "):
			continue
		handle.close()
		return {"name": _quoted_attribute(line, "name"), "type": _quoted_attribute(line, "type")}
	handle.close()
	return {}


## The value of a `key="value"` attribute inside one .tscn / .tres header line, "" when absent.
static func _quoted_attribute(line: String, key: String) -> String:
	var marker: String = "%s=\"" % key
	var start: int = line.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var end: int = line.find("\"", start)
	return line.substr(start, end - start) if end > start else ""


static var _script_scene_cache: Dictionary = {}
static var _script_scene_scanned: bool = false


## Drops the project-wide scene index, so the next question re-sweeps. The dock calls this when the
## editor's filesystem changes: a scene added, renamed, or re-parented to another script changes the
## answer, and an index kept for the whole session would go on naming the object it used to be.
static func clear_scene_script_index() -> void:
	_script_scene_cache.clear()
	_script_scene_scanned = false


## The scene a script is attached to as its ROOT, as {scene_path, root_name} - what lets a script with
## no `class_name` still be named after the object it drives. {} when no scene in the project uses it
## that way. Built by ONE sweep of the project's .tscn files (a scene names its scripts in the
## `[ext_resource]` lines at the very top, so only the head of each file is read) and kept until the
## filesystem changes, which is when the dock drops it.
static func scene_using_script(script_path: String) -> Dictionary:
	if not _script_scene_scanned:
		_script_scene_scanned = true
		_scan_scenes_for_scripts("res://")
	return _script_scene_cache.get(script_path, {})


static func _scan_scenes_for_scripts(directory_path: String) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	# Name order, always - the listing arrives in filesystem order (near-alphabetical on NTFS, hash
	# order on ext4), and when two scenes root the same script the FIRST one recorded names the
	# object, so an unsorted walk labels the same script differently on different platforms.
	var subdirectories: PackedStringArray = PackedStringArray()
	var scene_names: PackedStringArray = PackedStringArray()
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			if directory.current_is_dir():
				subdirectories.append(entry)
			elif entry.get_extension().to_lower() == "tscn":
				scene_names.append(entry)
		entry = directory.get_next()
	directory.list_dir_end()
	subdirectories.sort()
	scene_names.sort()
	for scene_name: String in scene_names:
		_record_scene_root_script(directory_path.path_join(scene_name))
	for subdirectory: String in subdirectories:
		_scan_scenes_for_scripts(directory_path.path_join(subdirectory))


## Records `script path -> {scene_path, root_name}` for one scene, when its ROOT node carries a
## script. Only the root counts: a script on a child says nothing about what the scene IS.
static func _record_scene_root_script(scene_path: String) -> void:
	var handle: FileAccess = FileAccess.open(scene_path, FileAccess.READ)
	if handle == null:
		return
	var script_ids: Dictionary = {}
	var root_name: String = ""
	var in_root: bool = false
	while not handle.eof_reached():
		var line: String = handle.get_line()
		if line.begins_with("[ext_resource "):
			if line.contains("type=\"Script\""):
				script_ids[_quoted_attribute(line, "id")] = _quoted_attribute(line, "path")
			continue
		if line.begins_with("[node "):
			if not root_name.is_empty():
				break  # past the root; a child's script is not this scene's identity
			root_name = _quoted_attribute(line, "name")
			in_root = true
			continue
		if not in_root or not line.begins_with("script = ExtResource("):
			continue
		var id_start: int = line.find("\"")
		var id_end: int = line.rfind("\"")
		if id_start < 0 or id_end <= id_start:
			break
		var script_id: String = line.substr(id_start + 1, id_end - id_start - 1)
		var script_path: String = str(script_ids.get(script_id, ""))
		if not script_path.is_empty() and not _script_scene_cache.has(script_path):
			_script_scene_cache[script_path] = {"scene_path": scene_path, "root_name": root_name}
		break
	handle.close()


## Builds a row for a variable placed directly in the event tree (movable like an event).
func _build_tree_variable_row(variable: LocalVariable, indent: int) -> EventRowData:
	# While reading, an @onready node reference is an OBJECT declaration, not a variable row.
	var object_row: EventRowData = _build_object_declaration_row(variable, indent)
	if object_row != null:
		return object_row
	var row_data: EventRowData = _build_variable_row(
		"tree",
		variable.name,
		variable.type_name,
		variable.default_value,
		indent,
		{
			"is_constant": variable.is_constant,
			"exported": variable.exported,
			# Inspector grouping (@export_group/@export_subgroup) recovered onto the variable on import -
			# shown as the "Group › Subgroup" chip, so a reopened grouped variable still reads as grouped.
			"group": str((variable.attributes as Dictionary).get("group", "")) if variable.exported and variable.attributes is Dictionary else "",
			"subgroup": str((variable.attributes as Dictionary).get("subgroup", "")) if variable.exported and variable.attributes is Dictionary else "",
			"expression_default": variable.expression_default or variable.inferred_type or variable.onready,
			"is_static": variable.is_static,
			"source_resource": variable,
			"row_uid": "variable_tree_%d" % variable.get_instance_id(),
			# The tree row reads exactly as the head's does: one shape, and a scope word
			# derived from where this sheet lives rather than from anything stored on the variable.
			"reading_scope": _member_scope_key(variable),
			# The `##` doc comment's first line, which is the sentence the Inspector shows as this
			# variable's tooltip - the rest of the block stays where it was written.
			"description": variable.description.strip_edges().get_slice("\n", 0).strip_edges(),
			"code_line": EventSheetCodeEcho.line_for(variable)
		}
	)
	# A PROPERTY (setter and/or getter): read it as a language block - the variable identity stays the row,
	# and each accessor folds under it as a condition/action child (`set(value)` / `get` in the condition
	# cell, its body lines as actions). Double-click the variable row still opens the Variable dialog.
	_attach_property_accessors(row_data, variable, indent)
	return row_data


## The accessor events (and the verbatim block they fall back to) hung under a variable row.
## Shared by the event tree and by the head's Instance variables folder, because a property is the
## same property wherever the sheet lists it - and a reader who opens the head to find out what `hp`
## IS should find its `On hp set` there too, not only down in the tree.
func _attach_property_accessors(row_data: EventRowData, variable: LocalVariable, indent: int) -> void:
	if row_data == null or variable == null or not variable.has_property_accessors():
		return
	var param: String = variable.setter_param.strip_edges() if not variable.setter_param.strip_edges().is_empty() else "value"
	# The OTHER spelling of a property names the functions instead of writing them inline. There is no
	# body under the declaration to read, so these rows say what there is to say - that setting this
	# value calls that function - and the function itself reads as the function it is, further down the
	# sheet, where it was written.
	if variable.has_named_accessors():
		row_data.children.append_array(_build_named_accessor_rows(variable, indent + 1, row_data.row_uid))
		row_data.folded = bool(_viewport._fold_state.get(row_data.row_uid, false))
		return
	# The accessors read as EVENTS first: a setter is a trigger, a getter an expression. Only
	# when a body does not lift cleanly do they fall back to the verbatim language block below.
	var read_rows: Array[EventRowData] = _build_property_accessor_reading(variable, param, indent + 1, row_data.row_uid)
	if not read_rows.is_empty():
		row_data.children.append_array(read_rows)
	else:
		row_data.language_block = true
		if not variable.setter_body.strip_edges().is_empty():
			row_data.children.append(_build_property_accessor_row(variable, "set(%s)" % param, variable.setter_body, indent + 1, "set"))
		if not variable.getter_body.strip_edges().is_empty():
			row_data.children.append(_build_property_accessor_row(variable, "get", variable.getter_body, indent + 1, "get"))
	row_data.folded = bool(_viewport._fold_state.get(row_data.row_uid, false))


## The sub-rows a NAMED property grows: one per accessor the declaration points at, saying which
## function runs and when. `set = _set_health` reads `➜ <Object> On health set  → _set_health`, the
## same trigger row an inline `set(value):` reads as, with the function's name where its body would
## have been.
##
## AND THE GETTER IS AN EXPRESSION, not a trigger - the same word the inline spelling two functions
## below already reads it as. A `set` block fires when the value is written, which is exactly an
## event; a `get` block is a function that gives a value back, which is an expression, and the
## grammar says an expression answers inside a value slot rather than being an event. Naming one
## spelling of that a trigger and the other an expression would show a reader the same idea in two
## grammatical categories in one opened file, since a file may write its properties either way.
##
## Nothing is inlined here on purpose. The function is written somewhere else in the file, it reads as
## itself where it was written, and copying its rows under the declaration would show the same code
## twice and leave a reader wondering which of the two they are allowed to edit.
##
## Pure view: the rows are inert, nothing addresses them, and the file's own text is untouched - the
## byte round-trip never sees this.
func _build_named_accessor_rows(variable: LocalVariable, indent: int,
		uid_base: String) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	var object_name: String = _script_object_name()
	if object_name.strip_edges().is_empty():
		object_name = EventSheetSentence.OBJECT_SYSTEM
	if not variable.setter_name.strip_edges().is_empty():
		rows.append(_build_named_accessor_row(variable, object_name, "set",
			variable.setter_name.strip_edges(), EventSheetL10n.translate("On %s set"), indent,
			uid_base))
	if not variable.getter_name.strip_edges().is_empty():
		rows.append(_build_named_getter_row(variable, object_name,
			variable.getter_name.strip_edges(), indent, uid_base))
	return rows


## The named getter's row: the SAME expression header the inline spelling reads with - the ƒ scope
## badge, the property's name and the muted word `expression` - with the function that gives the value
## on the right, where the inline spelling shows its body instead.
func _build_named_getter_row(variable: LocalVariable, object_name: String, function_name: String,
		indent: int, uid_base: String) -> EventRowData:
	var row := EventRowData.new()
	row.indent = indent
	row.row_type = EventRowData.RowType.EVENT
	row.row_uid = "property_named_get_%s" % uid_base
	row.line_count = 1
	var badge_colors: Array = _define_role_colors("expression")
	row.spans.append(_make_span("ƒ", SemanticSpan.SpanType.KEYWORD, {
		"editable": false,
		"badge": true,
		"badge_style": "scope",
		"badge_bg": badge_colors[0],
		"badge_fg": badge_colors[1],
		"lane": "condition",
		"line_index": 0
	}))
	row.spans.append(_make_span(variable.name.replace("_", " "), SemanticSpan.SpanType.OBJECT, {
		"editable": false,
		"kind": "property_getter",
		"lane": "condition",
		"line_index": 0,
		"chip": true,
		"object_label": object_name,
		"text_color": _define_role_name_color("expression")
	}))
	row.spans.append(_make_span(EventSheetL10n.translate("expression"), SemanticSpan.SpanType.COMMENT, {
		"editable": false,
		"lane": "condition",
		"line_index": 0,
		"natural_width": true,
		"text_color": _viewport._get_reading_style().muted_text_color
	}))
	var action_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_action_style())
	row.spans.append(_make_span(function_name, SemanticSpan.SpanType.ACTION, {
		"lane": "action",
		"kind": "property_accessor_function",
		"ace_index": 0,
		"editable": false,
		"hoverable": false,
		"line_index": 0,
		"object_label": object_name
	}.merged(action_style, true)))
	return row


## One named accessor's row: the trigger badge, the sentence, and the function it calls on a chip.
func _build_named_accessor_row(variable: LocalVariable, object_name: String, kind: String,
		function_name: String, sentence: String, indent: int, uid_base: String) -> EventRowData:
	var row := EventRowData.new()
	row.indent = indent
	row.row_type = EventRowData.RowType.EVENT
	row.row_uid = "property_named_%s_%s" % [kind, uid_base]
	row.line_count = 1
	var condition_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	var badge_meta: Dictionary = _viewport.BADGE_TRIGGER_METADATA.duplicate(true)
	var badge_glyph: String = _apply_trigger_tempo(badge_meta, _viewport._get_event_style(), "")
	badge_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)
	badge_meta["line_index"] = 0
	badge_meta["badge_style"] = "trigger"
	row.spans.append(_make_span(badge_glyph, SemanticSpan.SpanType.KEYWORD, badge_meta))
	row.spans.append(_make_span(sentence % variable.name.replace("_", " "),
		SemanticSpan.SpanType.CONDITION, {
			"lane": "condition",
			"kind": "trigger",
			"ace_index": -1,
			"chip": true,
			"editable": false,
			"hoverable": false,
			"line_index": 0,
			"object_label": object_name
		}.merged(condition_style_meta, true)))
	# The function goes in the RIGHT lane, where a thing that runs belongs - the trigger asks and the
	# action does, which is the sheet's whole grammar. It also gives the row a right half: a trigger
	# row with nothing on its right keeps the condition lane at its minimum, and the sentence is then
	# cut off after two characters.
	var action_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_action_style())
	row.spans.append(_make_span(function_name, SemanticSpan.SpanType.ACTION, {
		"lane": "action",
		"kind": "property_accessor_function",
		"ace_index": 0,
		"editable": false,
		"hoverable": false,
		"line_index": 0,
		"object_label": object_name
	}.merged(action_style, true)))
	return row


## A property's accessors, read as the events they are instead of as code under the variable row.
## A `set(v):` block is exactly a trigger - it fires when the value is set, with the new value as its
## payload - so it reads `➜ <Object> On <name> set` with a `v` chip and its body as ordinary action
## rows and sub-events. A `get:` block is a function that gives a value, so it reads as an expression
## block whose body ends in `System ▸ Set return value to …`. The variable row stays above them both.
##
## Pure view: the bodies are read through the SAME lift a declared handler's body goes through, the
## rows are inert (nothing addresses them, so nothing can write through them), and the file keeps its
## accessor text untouched - the byte round-trip never sees this. [] when either body does not lift,
## and the caller keeps the verbatim block it always had.
func _build_property_accessor_reading(variable: LocalVariable, param: String, indent: int,
		uid_base: String) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	var object_name: String = _script_object_name()
	if object_name.strip_edges().is_empty():
		object_name = EventSheetSentence.OBJECT_SYSTEM
	if not variable.setter_body.strip_edges().is_empty():
		var setter_row: EventRowData = _build_property_setter_row(variable, object_name, param, indent, uid_base)
		if setter_row == null:
			return []
		rows.append(setter_row)
	if not variable.getter_body.strip_edges().is_empty():
		var getter_row: EventRowData = _build_property_getter_row(variable, object_name, indent, uid_base)
		if getter_row == null:
			return []
		rows.append(getter_row)
	return rows


## The setter's trigger row: the ➜ badge, `<Object> On <name> set`, and one payload chip for the
## parameter the new value arrives in. Its first step folds into the row beside the trigger, the way
## every other trigger reading does. null when the body does not lift.
func _build_property_setter_row(variable: LocalVariable, object_name: String, param: String,
		indent: int, uid_base: String) -> EventRowData:
	var row := EventRowData.new()
	row.indent = indent
	row.row_type = EventRowData.RowType.EVENT
	row.row_uid = "property_setter_%s" % uid_base
	row.line_count = 1
	var condition_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	var badge_meta: Dictionary = _viewport.BADGE_TRIGGER_METADATA.duplicate(true)
	var badge_glyph: String = _apply_trigger_tempo(badge_meta, _viewport._get_event_style(), "")
	badge_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)
	badge_meta["line_index"] = 0
	badge_meta["badge_style"] = "trigger"
	row.spans.append(_make_span(badge_glyph, SemanticSpan.SpanType.KEYWORD, badge_meta))
	row.spans.append(_make_span(EventSheetL10n.translate("On %s set") % variable.name.replace("_", " "),
		SemanticSpan.SpanType.CONDITION, {
			"lane": "condition",
			"kind": "trigger",
			"ace_index": -1,
			"chip": true,
			"editable": false,
			"hoverable": false,
			"line_index": 0,
			"object_label": object_name
		}.merged(condition_style_meta, true)))
	row.spans.append(_trigger_payload_span(param.replace("_", " "), 0, 0))
	if not _append_property_body_rows(row, variable.setter_body, indent, row.row_uid,
			EventSheetSentence.VerbKind.ACTION):
		return null
	_merge_first_body_step_into_header(row)
	return row


## The getter's expression row: the ƒ badge, the property's name, and the muted kind word beside it -
## the same header an expression function reads with. Its body says `Set return value to …`, so the
## step is left where it is rather than folded into the header. null when the body does not lift.
func _build_property_getter_row(variable: LocalVariable, object_name: String, indent: int,
		uid_base: String) -> EventRowData:
	var row := EventRowData.new()
	row.indent = indent
	row.row_type = EventRowData.RowType.EVENT
	row.row_uid = "property_getter_%s" % uid_base
	row.line_count = 1
	var badge_colors: Array = _define_role_colors("expression")
	row.spans.append(_make_span("ƒ", SemanticSpan.SpanType.KEYWORD, {
		"editable": false,
		"badge": true,
		"badge_style": "scope",
		"badge_bg": badge_colors[0],
		"badge_fg": badge_colors[1],
		"lane": "condition",
		"line_index": 0
	}))
	row.spans.append(_make_span(variable.name.replace("_", " "), SemanticSpan.SpanType.OBJECT, {
		"editable": false,
		"kind": "property_getter",
		"lane": "condition",
		"line_index": 0,
		"chip": true,
		"object_label": object_name,
		"text_color": _define_role_name_color("expression")
	}))
	row.spans.append(_make_span(EventSheetL10n.translate("expression"), SemanticSpan.SpanType.COMMENT, {
		"editable": false,
		"lane": "condition",
		"line_index": 0,
		"natural_width": true,
		"text_color": _viewport._get_reading_style().muted_text_color
	}))
	if not _append_property_body_rows(row, variable.getter_body, indent, row.row_uid,
			EventSheetSentence.VerbKind.EXPRESSION):
		return null
	return row


## Lifts one accessor body into inert reading rows under `row`. False when a line does not lift, which
## is what sends the whole property back to its verbatim block - a half-read accessor would be a lie.
func _append_property_body_rows(row: EventRowData, body: String, indent: int, uid_base: String,
		verb_kind: int) -> bool:
	var body_lines: PackedStringArray = PackedStringArray()
	for line: String in body.split("\n"):
		body_lines.append(line)
	var lifted: Array = EventSheetACELifter.lift_body_rows(body_lines, _sheet_object_variable_names())
	if lifted.is_empty():
		return false
	var index: int = 0
	for body_event: Variant in lifted:
		if not (body_event is EventRow):
			return false
		var body_row: EventRowData = _build_event_row(body_event as EventRow, indent + 1)
		if body_row == null:
			return false
		# Marked BEFORE the spans are resolved: a `return` inside a getter answers with a value, and
		# only the verb kind recorded here tells the grammar to say "Set return value to".
		_mark_verb_body(body_row, verb_kind, _current_verb_function)
		_mark_property_reading(body_row, "%s_%d" % [uid_base, index])
		row.children.append(body_row)
		index += 1
	return true


## Stamps a lifted accessor body row (and everything under it) as a pure READING: its cells are
## resolved while the lifted stand-in is still what it points at, the offers to edit a row it does not
## have are dropped, and its resource is released so no mutation can reach the property's text.
func _mark_property_reading(row_data: EventRowData, uid: String) -> void:
	if row_data == null:
		return
	_ensure_event_spans(row_data)
	var kept: Array[SemanticSpan] = []
	var lines: int = 1
	for span: SemanticSpan in row_data.spans:
		if bool(span.metadata.get("placeholder", false)):
			continue
		if str(span.metadata.get("kind", "")) in ["add_action", "add_condition"]:
			continue
		kept.append(span)
		lines = maxi(lines, int(span.metadata.get("line_index", 0)) + 1)
	row_data.spans = kept
	row_data.line_count = lines
	row_data.source_resource = null
	row_data.row_uid = uid
	for child_index in range(row_data.children.size()):
		_mark_property_reading(row_data.children[child_index], "%s_%d" % [uid, child_index])


## One accessor of a property variable (`set(value)` / `get`) as a read-only condition/action row: the
## accessor header in the CONDITION cell, its body lines as ACTION cells. source_resource stays null so
## select/drag/delete skip it; the parent variable row's double-click edits the property in the dialog.
func _build_property_accessor_row(variable: LocalVariable, header: String, body: String, indent: int, accessor: String) -> EventRowData:
	var body_lines: PackedStringArray = PackedStringArray()
	for line: String in body.split("\n"):
		body_lines.append(line)
	var row: EventRowData = _build_condition_action_row(header, body_lines, indent, null)
	row.language_block = true
	row.row_uid = "property_accessor_%s_%d" % [accessor, variable.get_instance_id()]
	return row


## The folder icon prefixing every group title: the editor theme's Folder texture when the editor is
## live, else a tiny generated folder shape (cached) - so the file-manager cue survives harnesses,
## exports, and headless runs where EditorInterface is absent.
static var _folder_icon_cache: Texture2D = null


static func _folder_icon() -> Texture2D:
	if _folder_icon_cache != null:
		return _folder_icon_cache
	var themed: Texture2D = ACEPickerDialog.editor_icon("Folder")
	if themed != null:
		_folder_icon_cache = themed
		return themed
	var image: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var folder_tone: Color = Color("#e8c06a")
	image.fill_rect(Rect2i(1, 3, 7, 3), folder_tone)
	image.fill_rect(Rect2i(1, 5, 14, 9), folder_tone)
	_folder_icon_cache = ImageTexture.create_from_image(image)
	return _folder_icon_cache


func _build_group_row(group: EventGroup, indent: int) -> EventRowData:
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.GROUP
	row_data.source_resource = group
	row_data.row_uid = group.group_uid if not group.group_uid.is_empty() else "group_%s" % indent
	row_data.folded = bool(_viewport._fold_state.get(row_data.row_uid, group.is_collapsed()))
	row_data.debug_state = str(_viewport._debug_rows.get(row_data.row_uid, ""))
	row_data.disabled = not group.enabled or bool(_viewport._row_disabled_state.get(row_data.row_uid, false))
	row_data.breakpoint_enabled = bool(_viewport._breakpoint_rows.get(row_data.row_uid, false))
	# The head reads in ONE line: a folder mark in the badge column, the title, the description
	# muted right beside it (still inline-editable), then what the group holds and its switch at the
	# right edge. The body wears a bracket in the group's colour instead of pushing its rows sideways,
	# so the head is the only place a group takes vertical room. Headless the folder icon resolves
	# null and the mark simply does not draw.
	var reading_style: EventSheetReadingStyle = _viewport._get_reading_style()
	var spans: Array[SemanticSpan] = []
	spans.append(_group_folder_span(reading_style))
	spans.append(
		_make_span(
			EventSheetGroupFacts.display_name(group),
			SemanticSpan.SpanType.OBJECT,
			{
				"editable": true,
				"edit_kind": "group_name",
				"group_title": true,
				"text_color": event_style.group_title_color
			}
		)
	)
	# The description sits on the SAME line now: a group's one-line summary belongs beside its name,
	# the way a variable's does, and a folded head keeps it rather than hiding the very sentence that
	# says whether the fold is worth opening.
	if not group.description.strip_edges().is_empty():
		spans.append(
			_make_span(
				group.description,
				SemanticSpan.SpanType.COMMENT,
				{
					"editable": true,
					"edit_kind": "group_description",
					"line_index": 0,
					"text_color": event_style.comment_text_color
				}
			)
		)
	# Who runs this group, as ONE muted word beside the name. Everyone says nothing: the head
	# carries the exception, so a sheet that never hosts anything looks exactly as it did.
	var runs_on: String = EventSheetGroupFacts.runs_on_word(group)
	if not runs_on.is_empty():
		spans.append(
			_make_span(
				runs_on,
				SemanticSpan.SpanType.COMMENT,
				{
					"line_index": 0,
					"group_runs_on": true,
					"text_color": reading_style.muted_text_color,
					"hover_note": EventSheetL10n.translate("Who runs the events in this group - right-click the head to change it.")
				}
			)
		)
	# And which MODE of the game it runs in, the same way and for the same reason: one muted word,
	# said only when the answer is not "every one of them".
	var runs_in: String = EventSheetGroupFacts.runs_in_word(group)
	if not runs_in.is_empty():
		spans.append(
			_make_span(
				runs_in,
				SemanticSpan.SpanType.COMMENT,
				{
					"line_index": 0,
					"group_runs_in": true,
					"text_color": reading_style.muted_text_color,
					"hover_note": EventSheetL10n.translate("The events in this group run only while the game is in this mode - right-click the head to change it.")
				}
			)
		)
	# The line this head IS, echoed in the script editor's own colours. It opens the
	# right-anchored run rather than closing it, so the counts and the switch stay flush with the
	# edge where the pinned copy of this head also draws them.
	_append_head_band_echo(spans, {"group_echo": true}, _group_declaration_line(group), false)
	spans.append_array(_group_head_status_spans(group, row_data.folded, reading_style))
	row_data.spans = spans
	# The group's own locals are rows at the TOP of its body: they are declarations, and a
	# declaration reads where it is declared. The echo is the member the compiler really writes.
	for local_row: EventRowData in _build_group_local_rows(group, indent + 1):
		row_data.children.append(local_row)
	for child in _viewport._group_children(group):
		var child_row: EventRowData = _viewport._build_row_from_resource(child, indent + 1)
		if child_row != null:
			row_data.children.append(child_row)
	# Event-sheet-style per-group footer: always the group's last child, one level deeper. A read-only
	# preview grows none: nothing can be added to it.
	if _viewport.show_add_event_footers and not _scaffolding_suppressed():
		row_data.children.append(
			_build_add_event_footer_row(group, indent + 1, "+ Add event to '%s'…" % EventSheetGroupFacts.display_name(group))
		)
	return row_data


## The `## @ace_group(...)` line the compiler writes for this group, asked of the compiler's own
## emitter so the head can never claim a line the file does not have. "" for a group the open sheet
## does not hold (a preview's, a function's), which simply draws no echo.
func _group_declaration_line(group: EventGroup) -> String:
	if group == null or _viewport == null or _viewport._sheet == null:
		return ""
	if not _group_declaration_lines.has("lines"):
		_group_declaration_lines["lines"] = SheetCompiler.group_declaration_lines(_viewport._sheet.events)
	return str((_group_declaration_lines["lines"] as Dictionary).get(group, ""))


## The folder mark a group head leads with: the file-manager idiom, in the badge column every other
## declaration row uses, so title text starts at the same x whatever the row is.
func _group_folder_span(reading_style: EventSheetReadingStyle) -> SemanticSpan:
	var badge_meta: Dictionary = {
		"badge": true,
		"badge_style": "glyph",
		"badge_natural_width": true,
		"badge_fixed_width": KIND_BADGE_WIDTH,
		"line_index": 0,
		"badge_bg": reading_style.plain_chip_background_color,
		"badge_fg": reading_style.primary_text_color
	}
	var folder: Texture2D = _folder_icon() if _viewport.show_object_icons else null
	if folder != null:
		badge_meta["badge_icon"] = folder
	return _make_span(GROUP_FOLDER_GLYPH, SemanticSpan.SpanType.KEYWORD, badge_meta)


## What the head says at its right edge: what the group holds (plus, when it is folded, the objects
## inside it), the ring that means "and it can be switched at runtime", and the switch itself. All
## three are right-anchored, so they stay a column no matter how long the title and description are.
func _group_head_status_spans(group: EventGroup, folded: bool,
		reading_style: EventSheetReadingStyle) -> Array[SemanticSpan]:
	var status: Array[SemanticSpan] = []
	var counts: String = EventSheetGroupFacts.counts_text(
		group, _group_object_labels(group) if folded else PackedStringArray()
	)
	if not counts.is_empty():
		status.append(_make_span(counts, SemanticSpan.SpanType.COMMENT, {
			"align_right": true,
			"line_index": 0,
			"group_counts": true,
			"text_color": reading_style.muted_text_color,
			"hover_note": EventSheetL10n.translate("What this group holds.")
		}))
	if group.runtime_toggleable:
		status.append(_make_span(GROUP_TOGGLEABLE_GLYPH, SemanticSpan.SpanType.KEYWORD, {
			"badge": true,
			"badge_style": "glyph",
			"badge_natural_width": true,
			"badge_fixed_width": KIND_BADGE_WIDTH,
			"align_right": true,
			"line_index": 0,
			"group_action": "toggleable",
			"badge_bg": reading_style.plain_chip_background_color,
			"badge_fg": reading_style.muted_text_color,
			"hover_note": EventSheetL10n.translate("Can be switched at runtime - Set group active / Group is active.")
		}))
	status.append(_make_span(
		HEAD_SWITCH_ON_GLYPH if group.enabled else HEAD_SWITCH_OFF_GLYPH,
		SemanticSpan.SpanType.KEYWORD,
		{
			"badge": true,
			"badge_style": "glyph",
			"badge_natural_width": true,
			"badge_fixed_width": KIND_BADGE_WIDTH,
			"align_right": true,
			"line_index": 0,
			"group_action": "enabled",
			"badge_bg": reading_style.plain_chip_background_color,
			"badge_fg": reading_style.primary_text_color if group.enabled else reading_style.muted_text_color,
			"hover_note": EventSheetL10n.translate("Active on start.") if group.enabled \
				else EventSheetL10n.translate("Off - this group and its rows compile out.")
		}
	))
	return status


## The distinct object names the rows inside a group act on, in the order they first appear - read
## off the ROWS' own descriptors rather than off their spans, so a folded group never has to build
## the spans it is not drawing.
func _group_object_labels(group: EventGroup) -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	_collect_group_object_labels(EventSheetGroupFacts.children(group), labels, seen)
	return labels


func _collect_group_object_labels(rows: Array, labels: PackedStringArray, seen: Dictionary) -> void:
	for entry: Variant in rows:
		if labels.size() > EventSheetGroupFacts.FOLDED_OBJECT_LIMIT:
			return
		if entry is EventGroup:
			_collect_group_object_labels(EventSheetGroupFacts.children(entry as EventGroup), labels, seen)
			continue
		var event_row: EventRow = entry as EventRow
		if event_row == null:
			continue
		if not event_row.trigger_id.strip_edges().is_empty():
			_note_object_label(_object_label_for(event_row.trigger_provider_id, event_row.trigger_id), labels, seen)
		for condition: Variant in event_row.conditions:
			if condition is ACECondition:
				_note_object_label(_object_label_for((condition as ACECondition).provider_id, (condition as ACECondition).ace_id), labels, seen)
		for action: Variant in event_row.actions:
			if action is ACEAction:
				_note_object_label(_object_label_for((action as ACEAction).provider_id, (action as ACEAction).ace_id), labels, seen)


func _note_object_label(label: String, labels: PackedStringArray, seen: Dictionary) -> void:
	var trimmed: String = label.strip_edges()
	if trimmed.is_empty() or seen.has(trimmed):
		return
	seen[trimmed] = true
	labels.append(trimmed)


## A group's `local_variables` as Local rows, first inside the bracket. Same shape as an event's
## own locals - one variable sentence for every declaration on the canvas - and the same echo, which
## is the plain `var` line the compiler emits under the group's "group locals" header.
func _build_group_local_rows(group: EventGroup, indent: int) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	if group == null:
		return rows
	for entry: Variant in group.local_variables:
		if not (entry is LocalVariable):
			continue
		var descriptor: LocalVariable = entry as LocalVariable
		rows.append(
			_build_variable_row(
				"local",
				descriptor.name,
				descriptor.type_name,
				descriptor.default_value,
				indent,
				{
					"is_constant": descriptor.is_constant,
					"variable_index": rows.size(),
					"source_resource": group,
					"row_uid": "variable_group_%s_%d" % [group.group_uid, rows.size()],
					"reading_scope": EventSheetVariableSentence.SCOPE_LOCAL,
					"expression_default": descriptor.expression_default or descriptor.inferred_type,
					"description": descriptor.description.strip_edges().get_slice("\n", 0).strip_edges(),
					"code_line": EventSheetCodeEcho.line_for(descriptor)
				}
			)
		)
	return rows


func _build_comment_row(comment_row: CommentRow, indent: int) -> EventRowData:
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.COMMENT
	row_data.source_resource = comment_row
	row_data.row_uid = "comment_%s_%d" % [str(comment_row.get_instance_id()), indent]
	row_data.folded = false
	row_data.debug_state = str(_viewport._debug_rows.get(row_data.row_uid, ""))
	row_data.disabled = not comment_row.enabled or bool(_viewport._row_disabled_state.get(row_data.row_uid, false))
	row_data.breakpoint_enabled = bool(_viewport._breakpoint_rows.get(row_data.row_uid, false))
	row_data.custom_color = comment_row.custom_color
	# Multiline comments render one span per text line (same per-line model as GDScript
	# blocks); the row height follows line_count.
	var comment_lines: PackedStringArray = comment_row.text.split("\n") if not comment_row.text.is_empty() else PackedStringArray(["Comment"])
	row_data.line_count = comment_lines.size()
	# The two spellings GDScript itself has, drawn as two looks. A `##` row is DOCUMENTATION - the
	# engine renders it and the manual sets it as prose - so it reads at full strength and leads with
	# a paragraph mark. A `#` row is a private note that never leaves this sheet, so it recedes to the
	# same ink at a fraction of it. Only the LOOK differs: both rows write exactly the marker they
	# carry, and the echo beside them says which.
	var documentation: bool = comment_row.is_documentation()
	var line_color: Color = event_style.comment_text_color
	if not documentation:
		line_color = Color(line_color, line_color.a * COMMENT_PRIVATE_ALPHA)
	var comment_spans: Array[SemanticSpan] = []
	if documentation:
		comment_spans.append(_make_span(COMMENT_PARAGRAPH_GLYPH, SemanticSpan.SpanType.KEYWORD, {
			"kind": "comment_row",
			"badge": true,
			"badge_style": "outline",
			"badge_natural_width": true,
			"line_index": 0,
			"badge_bg": event_style.comment_text_color,
			"badge_fg": event_style.comment_text_color,
			"hover_note": EventSheetL10n.translate("Shows in the manual.")
		}))
	var door_table: Dictionary = EventSheetCommentDoors.table_for(_viewport._sheet)
	for line_index in range(comment_lines.size()):
		var line_metadata: Dictionary = {
			"editable": true,
			"edit_kind": "comment_text",
			"line_index": line_index,
			"text_color": line_color
		}
		# BBCode-lite ([b]/[i]/[color=…]): segments shape the pixels; the RAW text stays
		# the editing/serialization truth (no data loss on edit/copy).
		var reading_line: String = comment_lines[line_index]
		if EventSheetBBCodeLite.has_markup(comment_lines[line_index]):
			line_metadata["bbcode_segments"] = EventSheetBBCodeLite.parse(comment_lines[line_index], line_color)
			# The doors are offsets into what is DRAWN, and a marked-up line draws its stripped text
			# through the segment run - so that is the string they are found in.
			reading_line = EventSheetBBCodeLite.strip(comment_lines[line_index])
		_note_comment_doors(line_metadata, reading_line, door_table)
		comment_spans.append(
			_make_span(
				comment_lines[line_index],
				SemanticSpan.SpanType.COMMENT,
				line_metadata
			)
		)
	# The echo of the line this row actually writes, asked of the row itself so it cannot disagree
	# with what emission puts in the file - the whole point of the checkbox is that the echo restyles
	# with the row and stays true either way.
	if not comment_row.text.strip_edges().is_empty():
		comment_spans.append(_code_echo_span(
			comment_row.echo_line(0),
			{
				"kind": "comment_row",
				"line_index": 0,
				"hover_note": EventSheetL10n.translate("The line this row writes.")
			},
			EventSheetCodeEcho.REST_ALPHA,
			true
		))
	row_data.spans = comment_spans
	return row_data


## Stamps the doors of one comment line onto the span metadata it will be drawn from, and does
## nothing at all for a line that names nothing the project can prove. `door_text` is the string the
## offsets index - what the renderer DRAWS, which is the raw line for a plain note and the stripped
## line for a marked-up one - so the underline and the click can never be measured against a
## different string from the one on screen.
func _note_comment_doors(line_metadata: Dictionary, drawn_text: String, door_table: Dictionary) -> void:
	var doors: Array[Dictionary] = EventSheetCommentDoors.doors_in(drawn_text, door_table)
	if doors.is_empty():
		return
	line_metadata["doors"] = doors
	line_metadata["door_text"] = drawn_text


func _build_event_row(event_row: EventRow, indent: int) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.EVENT
	row_data.source_resource = event_row
	row_data.row_uid = event_row.event_uid if not event_row.event_uid.is_empty() else "event_%s_%d" % [str(event_row.get_instance_id()), indent]
	row_data.folded = bool(_viewport._fold_state.get(row_data.row_uid, false))
	row_data.debug_state = str(_viewport._debug_rows.get(row_data.row_uid, ""))
	row_data.disabled = not event_row.enabled or bool(_viewport._row_disabled_state.get(row_data.row_uid, false))
	row_data.breakpoint_enabled = bool(_viewport._breakpoint_rows.get(row_data.row_uid, false))
	# THE QUIET SHEET LAW, in one line: a finding about this row - any family's - sets the amber
	# state and writes nothing into the sheet. No note row is built for a finding on purpose - the
	# sentence is read in the Doctor's inbox and in the help strip once the row is selected, and a
	# sheet with nothing wrong grows nothing at all.
	_stamp_attention(row_data, _findings_about(event_row))
	# And the one other thing a row can say about itself: that the verb written in it has a newer
	# spelling. That is not a finding and wears no colour - the row is not wrong and compiles exactly
	# as it always did - so it stamps a muted hintline the help strip reads once the row is selected,
	# and nothing whatsoever in the sheet.
	_stamp_successor_hint(row_data, event_row)
	# Event-row spans are the expensive part of building a sheet, so they are built
	# lazily via _ensure_event_spans() only when a row is laid out/hit-tested. The
	# line count (which drives row height/metrics) is computed cheaply up front so
	# the whole sheet can be flattened and measured without building any spans.
	row_data.line_count = _count_event_lines(event_row)
	for local_variable_row in _build_local_variable_rows(event_row, indent + 1):
		row_data.children.append(local_variable_row)
	# A name that is not a variable, and a verb handed the wrong kind of one, said UNDER the
	# event that has the problem rather than in a panel somewhere else. Built here so the note sits
	# above the sub-events, which is where the reader is already looking.
	for note_row: EventRowData in _build_variable_note_rows(event_row, row_data.row_uid, indent + 1):
		row_data.children.append(note_row)
	# The receipt of an optimiser fix already applied to this row, ONLY while the costs lens is on:
	# a reader who just changed something wants the answer to "did that work" where they changed it.
	# A receipt is a note, not a finding - the findings themselves are in the amber stamp above.
	for note_row: EventRowData in _build_receipt_note_rows(event_row, row_data.row_uid, indent + 1):
		row_data.children.append(note_row)
	# A `var` line inside the body declares a local of this event, so it reads at the top of the
	# event beside the ones the sheet itself owns, in file order among them.
	for promoted_row: EventRowData in _build_promoted_local_rows(event_row, indent + 1):
		row_data.children.append(promoted_row)
	# The edit handed to the undo funnel hangs under the step it belongs to, which is where the
	# file writes it: one undoable step, and the lines it is made of below it.
	for edit_row: EventRowData in _build_undo_step_rows(event_row, row_data.row_uid, indent + 1):
		row_data.children.append(edit_row)
	# A lambda handed to `connect` IS a trigger event; an event sheet has no lambdas, only triggers.
	# Its reading sits with the actions (which is where the connect line sits) and above the real
	# sub-events, because that is the order the file runs in.
	for connect_row: EventRowData in _build_connect_lambda_rows(event_row, row_data.row_uid, indent + 1):
		row_data.children.append(connect_row)
	# A connect handed ANOTHER object's function is the same thought with the work already
	# written elsewhere: the trigger on the left, the call it makes on the right.
	for connect_call_row: EventRowData in _build_connect_call_rows(event_row, row_data.row_uid, indent + 1):
		row_data.children.append(connect_call_row)
	for child in event_row.sub_events:
		var child_row: EventRowData = _viewport._build_row_from_resource(child, indent + 1)
		if child_row != null:
			row_data.children.append(child_row)
	# A structured switch (a MatchRow with cases) maps onto the sheet's own model: each case renders as its
	# own condition/action child row (the pattern in the condition cell, the body in the action cells).
	for case_row: EventRowData in _build_match_case_rows(event_row, indent + 1):
		row_data.children.append(case_row)
	for timeline_row: EventRowData in _build_timeline_step_rows(event_row, indent + 1):
		row_data.children.append(timeline_row)
	return row_data


## The menu a `match` answers, or {} when it answers none. Three things have to be true: the walk
## is inside a menu's handler (a lambda handed to `id_pressed`, or a function that connect named),
## the file knows that menu, and the thing being matched is a bare name - the handler's own parameter.
## `match some.thing:` in a menu handler is a switch on something else and keeps its own reading.
func _menu_of_match(match_row: MatchRow, event_row: EventRow) -> Dictionary:
	if match_row == null:
		return {}
	var subject: String = str(match_row.match_expression).strip_edges()
	if subject.is_empty() or not EventSheetSentence.is_identifier(subject):
		return {}
	var key: String = _menu_context_key(event_row)
	return {} if key.is_empty() else EventSheetMenuFacts.menu_of(sentence_context(), key)


## Records that this event is a menu answering its items. Claimed here rather than through the
## pending-pattern funnel because a handler is a shape all by itself: a file may answer a menu built
## in another file, and then there is no add_item run on this sheet to hang the claim on.
func _claim_menu_pattern(event_row: EventRow, menu: Dictionary) -> void:
	var uid: String = event_row.event_uid if event_row != null else ""
	if uid.is_empty():
		return
	var vocabulary: Dictionary = PATTERN_VOCABULARY.get(EventSheetMenuFacts.PATTERN_ID, {})
	EventSheetPatternFacts.claim(_viewport._sheet, EventSheetMenuFacts.PATTERN_ID, uid, uid,
		PackedStringArray([str(menu.get("object", ""))]), str(vocabulary.get("words", "")))


## The menu whose handler the walk is inside. A handler arrives one of three ways, and every one
## of them names its menu somewhere the arm itself cannot see: a lambda says it on the connect line it
## was handed to (stamped for the length of that walk), a plain function says it on the connect line
## that named the function, and a handler the open already recognised as a signal trigger carries that
## very connect line on the event it became.
func _menu_context_key(event_row: EventRow) -> String:
	if not _current_menu_key.is_empty():
		return _current_menu_key
	if event_row != null:
		var connected: String = EventSheetMenuFacts.connected_menu_key(
			str(event_row.get_meta("__source_connect_line", "")))
		if not connected.is_empty():
			return connected
	if _current_verb_function == null:
		return ""
	return EventSheetMenuFacts.handler_menu(sentence_context(), _current_verb_function.function_name)


## The combo detector a `match` is asking on behalf of, as {list, separator, window, object} - or
## {} when the match is an ordinary switch. Three facts have to line up: the subject joins a list into
## one string, that list is one the FILE fills with pressed inputs inside a time window, and the
## window is that list's own. Nothing here looks at the arms; what the arms spell is their business.
func _combo_of_match(match_row: MatchRow) -> Dictionary:
	var context: Dictionary = sentence_context()
	var lists: Dictionary = context.get("combo_lists", {})
	if lists.is_empty():
		return {}
	var subject: Dictionary = EventSheetSentence.combo_match_subject(match_row.match_expression)
	var list_name: String = str(subject.get("list", ""))
	if list_name.is_empty() or not lists.has(list_name):
		return {}
	return {
		"list": list_name,
		"separator": str(subject.get("separator", ",")),
		"window": str((lists[list_name] as Dictionary).get("window", "")),
		"object": EventSheetSentence.script_object(context)
	}


## One arm of a combo match, in the condition lane as the TRIGGER it is: the move the inputs
## spell, with the window the player had to press them in as the muted note. The catch-all arm gets
## no spans at all, so a `_` keeps reading as the plain Else it is.
func _combo_arm_condition_spans(combo: Dictionary, pattern_text: String) -> Array[SemanticSpan]:
	var spans: Array[SemanticSpan] = []
	var words: Dictionary = EventSheetSentence.combo_arm_words(pattern_text,
		str(combo.get("separator", ",")), str(combo.get("window", "")))
	if words.is_empty():
		return spans
	var condition_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	var badge_meta: Dictionary = _viewport.BADGE_TRIGGER_METADATA.duplicate(true)
	badge_meta["badge_bg"] = _viewport._get_event_style().trigger_badge_background_color
	badge_meta["badge_fg"] = _viewport._get_event_style().trigger_badge_foreground_color
	badge_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)
	badge_meta["line_index"] = 0
	badge_meta["badge_style"] = "trigger"
	badge_meta["lane"] = "condition"
	spans.append(_make_span("➜", SemanticSpan.SpanType.KEYWORD, badge_meta))
	var arm_meta: Dictionary = {
		"lane": "condition",
		"kind": "trigger",
		"ace_index": -1,
		"chip": true,
		"editable": false,
		"line_index": 0,
		"object_label": str(combo.get("object", ""))
	}.merged(condition_style_meta, true)
	spans.append(_make_span(str(words.get("text", "")), SemanticSpan.SpanType.CONDITION, arm_meta))
	if not str(words.get("note", "")).is_empty():
		spans.append(_make_span(" %s" % str(words.get("note", "")), SemanticSpan.SpanType.VALUE,
			arm_meta.duplicate().merged({
				"text_color": _viewport._get_reading_style().muted_text_color,
				"object_label": "", "chip": false
			}, true)))
	return spans


## One `match` arm of a menu handler as the trigger it is: the ➜ badge, the menu in the object
## column, and `On <item> chosen` with the id resolved back to the words the user clicks. An id no
## item declared keeps the number and wears the warning colour - the branch is real, and nothing in
## the menu can ever reach it.
func _menu_arm_condition_spans(menu: Dictionary, pattern_text: String) -> Array[SemanticSpan]:
	var spans: Array[SemanticSpan] = []
	var words: Dictionary = EventSheetMenuFacts.arm_words(menu, pattern_text)
	if words.is_empty():
		return spans
	var condition_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	var badge_meta: Dictionary = _viewport.BADGE_TRIGGER_METADATA.duplicate(true)
	badge_meta["badge_bg"] = _viewport._get_event_style().trigger_badge_background_color
	badge_meta["badge_fg"] = _viewport._get_event_style().trigger_badge_foreground_color
	badge_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)
	badge_meta["line_index"] = 0
	badge_meta["badge_style"] = "trigger"
	badge_meta["lane"] = "condition"
	spans.append(_make_span("➜", SemanticSpan.SpanType.KEYWORD, badge_meta))
	var arm_meta: Dictionary = {
		"lane": "condition",
		"kind": "trigger",
		"ace_index": -1,
		"chip": true,
		"editable": false,
		"line_index": 0,
		"object_label": str(menu.get("object", ""))
	}.merged(condition_style_meta, true)
	if not bool(words.get("known", false)):
		arm_meta["text_color"] = EventSheetActiveTheme.chrome().object_bar_warning_color
	spans.append(_make_span(str(words.get("text", "")), SemanticSpan.SpanType.CONDITION, arm_meta))
	return spans


## One child row per beat of any Timeline in this event's actions: "at 0.5s" reads as the
## condition (the WHEN), the step's action as the action (the WHAT) - the schedule in the
## sheet's own two-lane grammar. Rows carry the TimelineRow for double-click routing.
func _build_timeline_step_rows(event_row: EventRow, indent: int) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	for action_item: Variant in event_row.actions:
		if not (action_item is TimelineRow):
			continue
		var timeline: TimelineRow = action_item as TimelineRow
		for step: TimelineStep in timeline.steps:
			if step == null or not step.enabled or step.action == null:
				continue
			var step_text: String = ""
			if step.action is ACEAction:
				step_text = _format_action_descriptor(step.action as ACEAction)
			elif step.action is RawCodeRow:
				step_text = _friendly_statement_text((step.action as RawCodeRow).code)
			elif step.action is CommentRow:
				step_text = "# " + (step.action as CommentRow).text
			var step_row: EventRowData = _build_condition_action_row(
				"%s %ss" % [EventSheetL10n.translate("at"), var_to_str(step.at)],
				PackedStringArray([step_text]),
				indent,
				timeline
			)
			step_row.language_block = true
			rows.append(step_row)
	return rows


## One condition/action child row per case of any structured MatchRow in this event's actions - the switch
## mapped onto the sheet: the case PATTERN reads as a condition, the case BODY as the actions to run. The row
## keeps the MatchRow as source_resource so double-click opens the switch editor; an empty case body is a
## single "pass" action.
func _build_match_case_rows(event_row: EventRow, indent: int) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	for action_item: Variant in event_row.actions:
		if not (action_item is MatchRow):
			continue
		var match_row: MatchRow = action_item as MatchRow
		if match_row.cases.is_empty():
			continue
		# A match whose SUBJECT is state-shaped (its trailing identifier says "state") reads in
		# the state-machine grammar: each case gets the ◆ badge in the icon column and the text
		# "State: <pattern leaf>" - the same reading an authored Is In State header gets, derived
		# from the code's own names rather than any pack. Other matches keep their pattern text.
		var state_shaped: bool = _is_state_shaped_subject(match_row.match_expression)
		# ...and the narrower question inside that one: is the subject THIS OBJECT's own state
		# variable, the enum the states band declares. That machine has rows of its own, so its arms
		# read as those rows rather than as pattern text.
		var own_state_match: bool = EventSheetStateFacts.is_state_subject(match_row.match_expression)
		# An event sheet has no switch. A reader of one knows if / else-if / else, so a
		# match on an ORDINARY value reads as that chain: the first case as its test, every later case as
		# an Else carrying its own test, `_` as a plain Else. Only shapes that MEAN "one of these values"
		# qualify; a pattern that binds a name or destructures an array is doing something an Else-if
		# cannot say, and keeps its pattern text.
		var else_if_chain: bool = not state_shaped and _match_reads_as_else_if(match_row)
		# A `match id:` inside a menu's handler is not a switch on a number, it is the menu
		# answering: every arm is the item the user picked. The menu is what the WALK knows (the
		# lambda the handler was handed to, or the function the connect line named), which is why the
		# key is stamped rather than read off this row.
		var menu: Dictionary = _menu_of_match(match_row, event_row)
		if not menu.is_empty():
			state_shaped = false
			else_if_chain = false
			_claim_menu_pattern(event_row, menu)
		# A `match ",".join(combo):` is not a switch on a string, it is the combo detector
		# answering: every arm is a move the player just spelled, so every arm is a trigger.
		var combo: Dictionary = _combo_of_match(match_row)
		if not combo.is_empty():
			state_shaped = false
			else_if_chain = false
		var chain_index: int = 0
		for match_case: MatchCase in match_row.cases:
			if match_case == null:
				continue
			# A case body splits by the condition/action covenant: a body-level `if` block IS a
			# condition, so it becomes a nested condition/action CHILD row (guard in the
			# condition cell); plain statements stay in the case's action lane, read as the same
			# sentences and Object ▸ Verb calls every other row gets.
			var body: PackedStringArray = PackedStringArray()
			var transition_children: Array[EventRowData] = []
			for case_item: Variant in match_case.events:
				if case_item is RawCodeRow:
					var case_lines: PackedStringArray = (case_item as RawCodeRow).code.split("\n")
					var guard_row: EventRowData = _transition_child_row(case_lines, indent + 1, match_row)
					if guard_row != null:
						transition_children.append(guard_row)
						continue
					for case_line: String in case_lines:
						# Emptying the buffer is the detector's own bookkeeping: the trigger head
						# above already stands for it, and repeating it as a step would tell a reader
						# the move clears the combo, which is backwards.
						if not combo.is_empty() \
								and case_line.strip_edges() == "%s.clear()" % str(combo.get("list", "")):
							continue
						# Inside an arm of the object's own machine, `state = State.CHASE` is the Go
						# to row - the same step it is anywhere else, and the only place it cannot
						# BE that row, because an arm's body is kept verbatim so the match re-emits
						# to the byte. So it is at least READ as the row it means.
						var stepped: String = "" if not own_state_match else EventSheetStateFacts.statement_reading(case_line)
						body.append(stepped if not stepped.is_empty() \
							else _friendly_statement_text(case_line, not combo.is_empty()))
				elif case_item is ACEAction:
					body.append(_format_action_descriptor(case_item as ACEAction))
				elif case_item is CommentRow:
					for comment_line: String in (case_item as CommentRow).text.split("\n"):
						body.append("# " + comment_line)
			if body.is_empty() and transition_children.is_empty():
				body = PackedStringArray(["pass"])
			elif body.is_empty():
				body = PackedStringArray([" "])
			var pattern_text: String = str(match_case.pattern).strip_edges()
			var case_label: String = pattern_text
			# THE OBJECT'S OWN STATES, said the way its rows say them. `match state:` with
			# `State.PATROL:` arms is the machine a hand-written object is written as and the one the
			# states band declares, so its arms read "Is in Patrol" - the Is In State row's own
			# sentence, fetched from that row rather than spelled again here. Every other
			# state-shaped subject (a String state, another object's machine) keeps the older
			# "State: <leaf>" reading it has always had.
			var own_state_arm: String = "" if not own_state_match else EventSheetStateFacts.arm_reading(pattern_text)
			if not own_state_arm.is_empty():
				case_label = own_state_arm
			elif state_shaped and pattern_text != "_":
				case_label = "%s: %s" % [EventSheetL10n.translate("State"), _pattern_leaf(pattern_text)]
			var chain_spans: Array[SemanticSpan] = []
			if not menu.is_empty():
				chain_spans = _menu_arm_condition_spans(menu, pattern_text)
			if not combo.is_empty():
				chain_spans = _combo_arm_condition_spans(combo, pattern_text)
				if not chain_spans.is_empty():
					_note_pattern("animation_combo", "%s: %s" % [match_row.match_expression, pattern_text])
			if else_if_chain:
				chain_spans = _match_else_if_condition_spans(match_row.match_expression, pattern_text, chain_index)
				chain_index += 1
			var case_row: EventRowData = _build_condition_action_row(case_label, body, indent, match_row, false, chain_spans)
			if not chain_spans.is_empty():
				# An Else-if's test sits on the SECOND condition line, under the Else chip, so the row is
				# two lines tall however few actions it carries.
				var chain_lines: int = 0
				for chain_span: SemanticSpan in chain_spans:
					chain_lines = maxi(chain_lines, int(chain_span.metadata.get("line_index", 0)) + 1)
				case_row.line_count = maxi(case_row.line_count, chain_lines)
			case_row.language_block = true  # a switch case - a language construct, not a regular ACE event
			for transition_child: EventRowData in transition_children:
				case_row.children.append(transition_child)
			if state_shaped and pattern_text != "_" and not case_row.spans.is_empty():
				var case_badge_meta: Dictionary = _viewport.BADGE_TRIGGER_METADATA.duplicate(true)
				case_badge_meta["badge_bg"] = _viewport._get_event_style().trigger_badge_background_color
				case_badge_meta["badge_fg"] = _viewport._get_event_style().trigger_badge_foreground_color
				case_badge_meta["line_index"] = 0
				case_badge_meta["badge_style"] = "trigger"
				case_badge_meta["lane"] = "condition"
				case_row.spans.insert(0, _make_span("◆", SemanticSpan.SpanType.KEYWORD, case_badge_meta))
			rows.append(case_row)
	return rows


# ── instantiate + add_child (+ the first position) is an event sheet's Create object ──────────────
# Godot spells spawning as three statements that only mean anything together; an event sheet spells
# it as one action, and a reader takes in the three as noise around the one thing that happened. So
# the run reads as `System ▸ Create object <Scene> at <P> (as b)` - the three lines stay exactly as
# they are in the file, on hover and under a double-click, and nothing about emission changes.


## The Create object runs in one action lane: {"leads": {index: {text, alias, line_count}}, "consumed":
## {index: true}}. A group is a local declaration (or assignment) of `<scene>.instantiate()`, the
## `add_child` / `add_sibling` that plants it, and - only when it comes straight after - the first
## line that puts it somewhere.
func _create_object_groups(actions: Array, locals: Array = []) -> Dictionary:
	var leads: Dictionary = {}
	var consumed: Dictionary = {}
	# Refreshed HERE, before anything reads it: the sentence below ADDS the new object's own name to the
	# class map, and a refresh triggered later (by the icon lookup on the very span being built) would
	# rebuild the map from the sheet and drop it again.
	_reset_lens_caches_if_stale()
	# The `var e = Scene.instantiate()` line reads as the event's own Local row rather than as an
	# action, so the alias and the scene it was made from are looked up there too. The Local row stays
	# where it is: what collapses is everything the file then DOES to the new object.
	var spawned: Dictionary = _spawned_locals(locals)
	var index: int = 0
	while index < actions.size():
		var spawn: Dictionary = _instantiate_action_parts(actions[index])
		var cursor: int = index + 1
		if spawn.is_empty():
			var alias_here: String = _spawn_member_alias(actions[index], spawned)
			if alias_here.is_empty():
				index += 1
				continue
			spawn = spawned[alias_here]
			cursor = index
		# ────────────────────────────────────────────────────────────────────────────────────────
		# The run is everything the file does to the new object before it does anything else: the
		# layer it is added to, where it is put, and the properties set on the way in. They are
		# written in whatever order the author liked - the plant often comes AFTER the position -
		# so the run is walked rather than counted, and it is only a Create object when the plant
		# is somewhere in it.
		var alias: String = str(spawn.get("alias", ""))
		var last: int = cursor - 1
		var layer: String = ""
		var planted: bool = false
		var position_text: String = ""
		var placement_word: String = ""
		var extras: PackedStringArray = PackedStringArray()
		while cursor < actions.size():
			var parent: String = _plant_parent(actions[cursor], alias)
			if parent.is_empty() and not _plant_placement_word(actions[cursor], alias).is_empty():
				# The sibling spellings - `add_sibling(b)` and `get_parent().add_child(b)` - plant the
				# object NEXT TO this node rather than inside a named layer, so the plant is recognised
				# and the row says the placement word instead of a layer.
				parent = "here"
			if not parent.is_empty() and not planted:
				planted = true
				placement_word = _plant_placement_word(actions[cursor], alias)
				layer = parent
				last = cursor
				cursor += 1
				continue
			var placement: String = _placement_value(actions[cursor], alias)
			if not placement.is_empty() and position_text.is_empty():
				position_text = placement
				last = cursor
				cursor += 1
				continue
			var extra: String = _created_property_words(actions[cursor], alias)
			if extra.is_empty():
				break
			extras.append(extra)
			last = cursor
			cursor += 1
		if not planted:
			index += 1
			continue
		var indices: Array[int] = []
		for member_index: int in range(index, last + 1):
			indices.append(member_index)
		leads[index] = {
			"text": _create_object_text(str(spawn.get("source", "")), alias, position_text,
				bool(spawn.get("copy", false)), bool(spawn.get("pooled", false)), layer, extras, placement_word),
			"alias": alias,
			"line_count": last - index + 1,
			"indices": indices,
			# The scene file this row instances, so the hover can show the tree it just made.
			"scene": _spawned_scene_path(str(spawn.get("source", ""))),
		}
		for consumed_index: int in range(index + 1, last + 1):
			consumed[consumed_index] = true
		index = last + 1
	return {"leads": leads, "consumed": consumed}


## The scene FILE a Create object row makes an instance of, "" when the row spawns something the
## sheet never named a file for. Both spellings are read: the expression written into the row
## (`preload("res://enemy.tscn")`) and the const the file usually holds it in, which the same scan the
## head's Objects folder is drawn from has already resolved.
func _spawned_scene_path(source: String) -> String:
	var direct: String = EventSheetObjectFacts.scene_path_in(source)
	if not direct.is_empty():
		return direct
	var declared: Dictionary = _lens_scene_vars.get(source.strip_edges(), {}) as Dictionary
	return str(declared.get("res_path", ""))


# ── the four limit_* lines a camera's bounds are written as read as ONE scroll-limits row ─────────
# Godot spells a camera's bounds as up to four property writes that only mean anything together; the
# sheet spells them as one action, and the reader takes in the run as the one thing that happened.
# The lines stay exactly as they are in the file - on hover, under a double-click and in the bytes
# that are saved - which is the same promise the Create object run above makes.


## The side each `limit_*` property names, in the order a scroll-limits row says them.
const SCROLL_LIMIT_SIDES: Dictionary = {
	"limit_left": "left", "limit_right": "right", "limit_top": "top", "limit_bottom": "bottom"
}


## The scroll-limit runs in one action lane, as {"leads": {index: {text, object, line_count, indices,
## note}}, "consumed": {index: true}}. A run is two or more ADJACENT limit writes on the same object,
## and it is only claimed when both horizontal sides are in it - "0 to 1920" is a sentence about the
## left and right edges, and a run that never names them has no such sentence.
func _scroll_limit_groups(actions: Array) -> Dictionary:
	var leads: Dictionary = {}
	var consumed: Dictionary = {}
	var index: int = 0
	while index < actions.size() - 1:
		var first: Dictionary = _scroll_limit_parts(actions[index])
		if first.is_empty():
			index += 1
			continue
		var owner_name: String = str(first.get("object", ""))
		var sides: Dictionary = {str(first.get("side", "")): str(first.get("value", ""))}
		var evidence: PackedStringArray = PackedStringArray([str(first.get("line", ""))])
		var last: int = index
		while last + 1 < actions.size():
			var next_part: Dictionary = _scroll_limit_parts(actions[last + 1])
			if next_part.is_empty() or str(next_part.get("object", "")) != owner_name:
				break
			if sides.has(str(next_part.get("side", ""))):
				break
			sides[str(next_part.get("side", ""))] = str(next_part.get("value", ""))
			evidence.append(str(next_part.get("line", "")))
			last += 1
		if last == index or not sides.has("left") or not sides.has("right"):
			index += 1
			continue
		var indices: Array[int] = []
		for member_index: int in range(index, last + 1):
			indices.append(member_index)
		leads[index] = {
			"text": EventSheetL10n.translate("Set scroll limits {left} to {right}") \
				.replace("{left}", str(sides["left"])).replace("{right}", str(sides["right"])),
			"note": _scroll_limit_note(sides),
			"object": owner_name,
			"evidence": evidence,
			"line_count": last - index + 1,
			"indices": indices
		}
		for consumed_index: int in range(index + 1, last + 1):
			consumed[consumed_index] = true
		index = last + 1
	return {"leads": leads, "consumed": consumed}


## Which edges a scroll-limits row actually set, said quietly after the sentence. The values of the
## vertical pair are one hover away on the row, which lists every line it stands for.
func _scroll_limit_note(sides: Dictionary) -> String:
	var named: PackedStringArray = PackedStringArray()
	for side: Variant in SCROLL_LIMIT_SIDES.values():
		if sides.has(str(side)):
			named.append(EventSheetL10n.translate(str(side)))
	return "(%s)" % ", ".join(named)


# ── the two runs whose lines only mean anything together ─────────────────────────────────────────
# A first-person script turns the body one way and the camera the other and then clamps the camera,
# and a music crossfade writes one fader up and the other down. Each is ONE thing that happened, and
# a reader takes the lines in as noise around it. The lines stay exactly as they are in the file - on
# hover, under a double-click and in the bytes that are saved - which is the promise the Create
# object and scroll-limits runs above make too.


## The mouse-look run in one action lane, as {"leads": {index: {text, note, object, evidence,
## line_count, indices}}, "consumed": {index: true}}. A run is a `rotate_y(...)` followed by a
## `<cam>.rotate_x(...)` and - only when it comes straight after - the clamp that keeps the camera
## from looking through the floor. Both turns are required: one on its own is a turn, not a look.
func _mouse_look_groups(actions: Array) -> Dictionary:
	var leads: Dictionary = {}
	var consumed: Dictionary = {}
	var index: int = 0
	while index < actions.size() - 1:
		var turn: Dictionary = EventSheetSentence.mouse_look_turn_parts(_group_line_text(actions[index]))
		var pitch: Dictionary = EventSheetSentence.mouse_look_pitch_parts(_group_line_text(actions[index + 1]))
		if turn.is_empty() or pitch.is_empty():
			index += 1
			continue
		# The same two lines driven by the GYROSCOPE are a gyro aim, not a mouse look. The two
		# runs are the same shape with a different hand on it, so the more specific one gets first
		# refusal and this pass steps over it rather than claiming both.
		if not EventSheetSentence.gyro_aim_turn_parts(
				_group_line_text(actions[index]), sentence_context()).is_empty():
			index += 1
			continue
		var last: int = index + 1
		var clamped: String = ""
		if last + 1 < actions.size():
			clamped = EventSheetSentence.mouse_look_clamp_limit(_group_line_text(actions[last + 1]),
				str(pitch.get("camera", "")))
			if not clamped.is_empty():
				last += 1
		var evidence: PackedStringArray = PackedStringArray()
		var indices: Array[int] = []
		for member_index: int in range(index, last + 1):
			evidence.append(_group_line_text(actions[member_index]))
			indices.append(member_index)
		leads[index] = {
			"text": EventSheetL10n.translate("Mouse look"),
			"note": EventSheetSentence.mouse_look_note(turn, pitch, clamped, sentence_context()),
			"object": EventSheetSentence.script_object(sentence_context()),
			"evidence": evidence,
			"line_count": last - index + 1,
			"indices": indices
		}
		for consumed_index: int in range(index + 1, last + 1):
			consumed[consumed_index] = true
		index = last + 1
	return {"leads": leads, "consumed": consumed}


# ── the two runs batch thirteen adds ─────────────────────────────────────────────────────────────
# A third-person script mixes the camera's own axes with the input, flattens the result, makes it one
# unit long and writes it into the velocity - five lines that only mean "move the way the camera is
# facing" together. A mesh's visible range is two writes that only mean a distance BAND together.
# Each is ONE thing that happened. The lines stay exactly as they are in the file - on hover, under a
# double-click and in the bytes that are saved - which is the promise every run above makes too.


## The camera-relative run in one action lane, as {"leads": {index: {text, note, object,
## evidence, line_count, indices}}, "consumed": {index: true}}.
##
## The camera and the direction are declared as LOCALS, above the lane, which is where the shape says
## what it is: `cam_basis` is a camera's basis and `dir` is that basis mixed with the input. The
## ACTIONS are the rest of it - the flatten, the normalize and the two velocity writes - and BOTH
## velocity writes are required: one axis on its own is a nudge, not locomotion.
func _camera_relative_move_groups(actions: Array, locals: Array) -> Dictionary:
	var leads: Dictionary = {}
	var consumed: Dictionary = {}
	var mix: Dictionary = _camera_relative_locals(actions, locals)
	if mix.is_empty():
		return {"leads": leads, "consumed": consumed}
	var direction: String = str(mix.get("direction", ""))
	var index: int = 0
	while index < actions.size() - 1:
		var last: int = index - 1
		var flattened: bool = false
		var speed: String = ""
		var axes: Dictionary = {}
		var step: int = index
		while step < actions.size():
			var line: String = _group_line_text(actions[step])
			if line.is_empty():
				break
			if EventSheetSentence.is_flatten_line(line, direction):
				flattened = true
			elif not EventSheetSentence.is_normalize_line(line, direction):
				var found: String = EventSheetSentence.velocity_step_speed(line, direction)
				# Every axis of the run has to move at ONE speed: two speeds are two sentences, and
				# a row that named only the first would hide the second.
				if found.is_empty() or (not speed.is_empty() and found != speed):
					break
				speed = found
				axes[line.get_slice(" = ", 0).strip_edges()] = true
			last = step
			step += 1
		if axes.size() < 2 or speed.is_empty():
			index += 1
			continue
		var evidence: PackedStringArray = PackedStringArray([
			str(mix.get("basis_line", "")), str(mix.get("mix_line", ""))])
		var indices: Array[int] = []
		for member_index: int in range(index, last + 1):
			evidence.append(_group_line_text(actions[member_index]))
			indices.append(member_index)
		var sentence: Dictionary = EventSheetSentence.camera_relative_move_sentence(
			EventSheetSentence.script_object(sentence_context()), str(mix.get("input", "")), speed,
			flattened, sentence_context())
		var text: String = ""
		for segment: Variant in (sentence.get("segments", []) as Array):
			text += str((segment as Dictionary).get("text", ""))
		leads[index] = {
			"text": text.strip_edges(),
			"note": "",
			"object": str(sentence.get("object", "")),
			"evidence": evidence,
			"line_count": last - index + 1,
			"indices": indices
		}
		for consumed_index: int in range(index + 1, last + 1):
			consumed[consumed_index] = true
		index = last + 1
	return {"leads": leads, "consumed": consumed}


## What the event's LOCALS say about a camera-relative run: which local holds a camera's basis,
## which one holds that basis mixed with the input, and which input vector drove the mix. {} when the
## event declares no such pair, which is what keeps the walk above from claiming anything.
##
## Both shapes a local arrives in are read. An opened .gd file's locals are Local Variable ACTIONS
## the canvas promotes to declaration rows; a sheet somebody authored carries them as LocalVariable
## resources on the event. The run must be recognised the same either way, or it would fire or not
## depending on which half of the file happened to lift - exactly the drift these runs prevent.
func _camera_relative_locals(actions: Array, locals: Array) -> Dictionary:
	var declared: Dictionary = {}
	var order: PackedStringArray = PackedStringArray()
	for entry: Variant in locals:
		var local: LocalVariable = entry as LocalVariable
		if local == null or local.name.strip_edges().is_empty():
			continue
		declared[local.name.strip_edges()] = str(local.default_value).strip_edges()
		order.append(local.name.strip_edges())
	for entry: Variant in actions:
		var action: ACEAction = entry as ACEAction
		if action == null or not action.enabled:
			continue
		var declaration: Dictionary = grammar_action_declaration(action)
		var name_text: String = str(declaration.get("name", "")).strip_edges()
		if name_text.is_empty() or declared.has(name_text):
			continue
		declared[name_text] = str(declaration.get("raw_value", "")).strip_edges()
		order.append(name_text)
	var bases: Dictionary = {}
	for name_text: String in order:
		if not EventSheetSentence.camera_basis_source(str(declared[name_text])).is_empty():
			bases[name_text] = true
	if bases.is_empty():
		return {}
	for name_text: String in order:
		for basis_name: Variant in bases:
			var input_name: String = EventSheetSentence.camera_basis_mix_input(
				str(declared[name_text]), str(basis_name))
			if input_name.is_empty():
				continue
			return {
				"direction": name_text,
				"input": input_name,
				"basis_line": "%s = %s" % [str(basis_name), str(declared[basis_name])],
				"mix_line": "%s = %s" % [name_text, str(declared[name_text])]
			}
	return {}


## The add_item runs in one action lane, in the same shape as the scroll limits above: a run of
## adjacent calls that put items into ONE menu. Ten `add_item` lines are not ten things that happened
## - they are one menu, and a reader wants to see the menu, in order, with its separators and its
## tick items where they are. The lines are untouched: this is a lens, so the file re-emits byte for
## byte, and every line the bar stands for is one hover away.
func _menu_item_groups(actions: Array) -> Dictionary:
	var leads: Dictionary = {}
	var consumed: Dictionary = {}
	var facts: Dictionary = sentence_context()
	if not (facts.get("menus", null) is Dictionary):
		return {"leads": leads, "consumed": consumed}
	var index: int = 0
	while index < actions.size() - 1:
		var first: Dictionary = _menu_item_parts(actions[index])
		if first.is_empty():
			index += 1
			continue
		var menu_key: String = str(first.get("menu", ""))
		var evidence: PackedStringArray = PackedStringArray([str(first.get("line", ""))])
		var last: int = index
		while last + 1 < actions.size():
			var next_part: Dictionary = _menu_item_parts(actions[last + 1])
			if next_part.is_empty() or str(next_part.get("menu", "")) != menu_key:
				break
			evidence.append(str(next_part.get("line", "")))
			last += 1
		var menu: Dictionary = EventSheetMenuFacts.menu_of(facts, menu_key)
		if last == index or menu.is_empty():
			index += 1
			continue
		var indices: Array[int] = []
		for member_index: int in range(index, last + 1):
			indices.append(member_index)
		var bar: Dictionary = EventSheetMenuFacts.bar_words(menu)
		leads[index] = {
			"text": str(bar.get("text", "")),
			"note": str(bar.get("note", "")),
			"object": str(menu.get("object", "")),
			"evidence": evidence,
			"line_count": last - index + 1,
			"indices": indices
		}
		for consumed_index: int in range(index + 1, last + 1):
			consumed[consumed_index] = true
		index = last + 1
	return {"leads": leads, "consumed": consumed}


## One line that puts something in a menu -> {menu, line}, or {} for anything else. Both
## spellings are read - the line as typed and the Call Method row the lifter files it as - so a run
## reads the same whichever way the open lifted it.
func _menu_item_parts(action_resource: Variant) -> Dictionary:
	var text: String = _group_line_text(action_resource)
	if text.is_empty():
		return {}
	var menu_key: String = EventSheetMenuFacts.item_menu_key(text)
	return {} if menu_key.is_empty() else {"menu": menu_key, "line": text}


## The visible-range runs in one action lane, in the same shape as the scroll limits above: two
## adjacent writes on ONE object, the near end and the far end, which only name a band together.
func _visible_range_groups(actions: Array) -> Dictionary:
	var leads: Dictionary = {}
	var consumed: Dictionary = {}
	var index: int = 0
	while index < actions.size() - 1:
		var near: Dictionary = _visible_range_parts(actions[index])
		var far: Dictionary = _visible_range_parts(actions[index + 1])
		if near.is_empty() or far.is_empty() \
				or str(near.get("object", "")) != str(far.get("object", "")) \
				or str(near.get("end", "")) != "begin" or str(far.get("end", "")) != "end":
			index += 1
			continue
		var sentence: Dictionary = EventSheetSentence.visibility_range_sentence(
			str(near.get("object", "")), str(near.get("value", "")), str(far.get("value", "")),
			sentence_context())
		var text: String = ""
		for segment: Variant in (sentence.get("segments", []) as Array):
			text += str((segment as Dictionary).get("text", ""))
		leads[index] = {
			"text": text.strip_edges(),
			"note": "",
			"object": str(near.get("object", "")),
			"evidence": PackedStringArray([str(near.get("line", "")), str(far.get("line", ""))]),
			"line_count": 2,
			"indices": [index, index + 1]
		}
		consumed[index + 1] = true
		index += 2
	return {"leads": leads, "consumed": consumed}


## One `rock.visibility_range_begin = 10` line -> {object, end, value, line}, or {} for anything
## else. Both spellings a write arrives in are read, exactly as the scroll limits are.
func _visible_range_parts(action_resource: Variant) -> Dictionary:
	var text: String = _group_line_text(action_resource)
	if text.is_empty():
		return {}
	var at: int = EventSheetSentence.top_level_index(text, " = ")
	if at < 0:
		return {}
	var target: String = text.substr(0, at).strip_edges()
	var value: String = text.substr(at + 3).strip_edges()
	if value.is_empty() or not EventSheetSentence.is_simple_target(target):
		return {}
	var bare: String = target.trim_prefix("self.")
	var dot_at: int = bare.rfind(".")
	var member: String = bare if dot_at < 0 else bare.substr(dot_at + 1)
	if member != "visibility_range_begin" and member != "visibility_range_end":
		return {}
	var owner_text: String = "" if dot_at < 0 else bare.substr(0, dot_at)
	var object_name: String = EventSheetSentence.call_object(owner_text, "", sentence_context())
	if not EventSheetSentence.class_is_geometry(
			EventSheetSentence.object_class_of(object_name, sentence_context())):
		return {}
	return {
		"object": object_name,
		"end": "begin" if member.ends_with("begin") else "end",
		"value": value,
		"line": text
	}


## The crossfade runs in one action lane, in the same shape. A run is two adjacent volume
## writes driven by ONE fraction - one fader by `1 - t` and the other by `t` - which is the whole of
## what a crossfade is. Two volumes set from unrelated values are two rows, and stay two rows.
func _crossfade_groups(actions: Array) -> Dictionary:
	var leads: Dictionary = {}
	var consumed: Dictionary = {}
	var index: int = 0
	while index < actions.size() - 1:
		var faded: Dictionary = EventSheetSentence.crossfade_parts(
			_group_line_text(actions[index]), _group_line_text(actions[index + 1]), sentence_context())
		if faded.is_empty():
			index += 1
			continue
		leads[index] = {
			"text": str(faded.get("text", "")),
			"note": "",
			"object": EventSheetSentence.OBJECT_SYSTEM,
			"evidence": PackedStringArray([_group_line_text(actions[index]),
				_group_line_text(actions[index + 1])]),
			"line_count": 2,
			"indices": [index, index + 1]
		}
		consumed[index + 1] = true
		index += 2
	return {"leads": leads, "consumed": consumed}


# ── the spellings a hierarchy move takes read as the ONE row they are ─────────────────────────────
#
# "Put this object under that one" has three spellings in Godot and one meaning: `reparent`, the
# `remove_child` + `add_child` pair, and - when the mover wanted the child to follow only SOME of its
# new parent's transform - a reparent with a RemoteTransform and a `top_level` beside it. A reader
# looking at any of them is looking at one thing that happened, so they read as one row, with the
# flags it was given said out loud and every line it stands for on the hover.
#
# The lines are untouched: this is a lens, exactly as the Create object and scroll-limits runs above
# are, so the file re-emits byte for byte whichever spelling it came in as.


## The four flags an Add child row carries, in the order the row says them, as
## member/word pairs. Godot's default for every one of them is ON, which is why a plain child needs
## no plumbing at all and a plain row shows no chips.
const HIERARCHY_FLAG_WORDS: Dictionary = {
	"update_position": "transform position",
	"update_rotation": "transform angle",
	"update_scale": "transform size",
	"destroy_with_parent": "destroy with parent"
}


## The run that CONFIGURES a Control a Local row just made: the property writes, the calls and
## the add_child that name it, from the line under the declaration onwards. Returned as
## {declaration index: {"name", "indices"}, "consumed": {index: true}} - the shape every run pass here
## uses - so the action lane drops them and the Local row draws them underneath instead.
##
## Building a dialog is the most repetitive code any tool file has, and read line by line it is twenty
## top-level rows saying one thing. Under the Local row it is a dialog and the rows that shape it.
##
## Gated on the DECLARATION: nothing is walked until an action declares a local whose value is a
## Control being made (`ConfirmationDialog.new()` and the rest of the sheet's Control nouns), which is
## the head predicate that keeps this off every other event in every other file.
##
## A `.connect(` line is deliberately NOT taken: the sheet already reads a wired-up signal as the
## trigger it is, with the call under it, and that reading lives on the event itself. The run steps
## over such a line and carries on, so the two readings share the statement list without either
## saying it twice.
func _control_setup_groups(event_row: EventRow) -> Dictionary:
	var runs: Dictionary = {}
	var consumed: Dictionary = {}
	if event_row == null or not event_promotes_locals(event_row):
		return {"runs": runs, "consumed": consumed}
	for action_index: int in event_row.actions.size():
		var name: String = _control_declared_name(event_row.actions[action_index])
		if name.is_empty():
			continue
		var indices: Array[int] = []
		var cursor: int = action_index + 1
		while cursor < event_row.actions.size():
			var line: String = _group_line_text(event_row.actions[cursor])
			if line.begins_with("%s." % name) and line.contains(".connect("):
				cursor += 1
				continue
			if not _configures_control(line, name):
				break
			indices.append(cursor)
			consumed[cursor] = true
			cursor += 1
		if not indices.is_empty():
			runs[action_index] = {"name": name, "indices": indices}
	return {"runs": runs, "consumed": consumed}


## The local ONE action declares as a newly made Control, or "" for every other action. This is
## the head predicate the whole regroup hangs off, so it must not cost a code generation per action:
## a lifted row is asked for its declaration directly (the same answer the Local rows are built from)
## and only a verbatim line is read as text. Nothing below here runs until this says yes.
func _control_declared_name(action_resource: Variant) -> String:
	var raw: RawCodeRow = action_resource as RawCodeRow
	if raw != null:
		if not raw.enabled or raw.code.contains("\n"):
			return ""
		return _declared_control_name(raw.code.strip_edges())
	var action: ACEAction = action_resource as ACEAction
	if action == null or not action.enabled:
		return ""
	if not (action.provider_id.is_empty() or action.provider_id == "Core"):
		return ""
	# The row's own parameters, read straight: the grammar's declaration reading would answer the
	# same thing, and would build a copy of the whole sentence context to do it - per action, on the
	# paint path, for every file whether or not it builds any UI at all.
	var params_dict: Dictionary = action.params if not action.params.is_empty() else action.parameters
	var made: String = str(params_dict.get("value", "")).strip_edges()
	if not made.ends_with(".new()"):
		return ""
	if EventSheetSentence.control_noun(made.substr(0, made.length() - 6)).is_empty():
		return ""
	var declared: String = str(params_dict.get("name", "")).strip_edges()
	return declared if EventSheetSentence.is_identifier(declared) else ""


## The local a verbatim LINE declares as a newly made Control, or "" for every other line. The sheet's
## own Control nouns decide: a local holding a `Timer.new()` is not a piece of UI and keeps its rows.
func _declared_control_name(line: String) -> String:
	if not line.begins_with("var ") or not line.ends_with(".new()"):
		return ""
	var assignment_at: int = EventSheetSentence.top_level_index(line, " = ")
	var separator: int = 3
	if assignment_at < 0:
		assignment_at = EventSheetSentence.top_level_index(line, " := ")
		separator = 4
	if assignment_at < 0:
		return ""
	var made: String = line.substr(assignment_at + separator).strip_edges()
	if EventSheetSentence.control_noun(made.substr(0, made.length() - 6)).is_empty():
		return ""
	var declared: String = line.substr(4, assignment_at - 4).strip_edges()
	var colon_at: int = declared.find(":")
	if colon_at > 0:
		declared = declared.substr(0, colon_at).strip_edges()
	return declared if EventSheetSentence.is_identifier(declared) else ""


## True when one line shapes the named Control rather than doing something else: a write or a call on
## it, or the line that puts it in the tree.
func _configures_control(line: String, name: String) -> bool:
	if line.is_empty():
		return false
	if line == "add_child(%s)" % name or line.ends_with(".add_child(%s)" % name):
		return true
	return line.begins_with("%s." % name)


## The lines a pack recipe uses to STATE what the pack is - its host class, its class name, its
## category, its tags, what it says about itself, and that it is a behavior at all - as
## {"consumed": {index: true}}. They are head facts on the bar above (which computes them from the
## file itself), so drawing them again as six Set rows says the same thing twice and buries the one
## thing the function actually does.
##
## Gated on the FILE: only a `static func build()` under a pack_builders folder that saves a pack is a
## recipe, so `sheet.host_class = ...` in a game script keeps the row it always had. Display only -
## the actions themselves are untouched, which is what keeps the recipe's byte round-trip exact.
func _recipe_head_groups(actions: Array) -> Dictionary:
	var consumed: Dictionary = {}
	if not _sheet_is_pack_recipe():
		return {"leads": {}, "consumed": consumed}
	for action_index: int in actions.size():
		if _is_recipe_head_line(_group_line_text(actions[action_index])):
			consumed[action_index] = true
	return {"leads": {}, "consumed": consumed}


## Whether the open sheet is a pack recipe, answered once per sheet. The kind is a whole-FILE
## fact that cannot change while the file is open, so a tab switch is the only thing that rebuilds it.
func _sheet_is_pack_recipe() -> bool:
	var sheet: Resource = _viewport._sheet if _viewport != null else null
	if sheet == _recipe_sheet_seen:
		return _recipe_sheet_is
	_recipe_sheet_seen = sheet
	_recipe_sheet_is = str(sentence_context().get("tool_file_kind", "")) \
		== EventSheetToolFiles.KIND_PACK_RECIPE
	return _recipe_sheet_is


## True when one line of a recipe states a head fact rather than doing something. The properties are
## the very list the bar reads, so a fact the bar stops showing starts drawing its row again rather
## than vanishing from both.
func _is_recipe_head_line(line: String) -> bool:
	if not line.begins_with("sheet."):
		return false
	for property: Variant in EventSheetToolFiles.RECIPE_HEAD_PROPERTIES:
		if line.begins_with("sheet.%s = " % str(property)):
			return true
	return false


## The hierarchy runs in one action lane, as {"leads": {index: {text, note, object,
## evidence, line_count, indices}}, "consumed": {index: true}}.
func _hierarchy_groups(actions: Array, event_uid: String = "") -> Dictionary:
	var leads: Dictionary = {}
	var consumed: Dictionary = {}
	var index: int = 0
	while index < actions.size():
		var run: Dictionary = _hierarchy_run_at(actions, index)
		if run.is_empty():
			index += 1
			continue
		var last: int = int(run.get("last", index))
		var evidence: PackedStringArray = PackedStringArray()
		var indices: Array[int] = []
		for member_index: int in range(index, last + 1):
			evidence.append(_group_line_text(actions[member_index]))
			indices.append(member_index)
		leads[index] = {
			"text": str(run.get("text", "")),
			"note": str(run.get("note", "")),
			"object": str(run.get("object", "")),
			"evidence": evidence,
			"line_count": last - index + 1,
			"indices": indices
		}
		# What the flags chip needs to reopen this run as ticks and write it back: which event
		# and which actions it stands for, how the move itself is spelled, and which flags are on
		# right now. Everything travels by VALUE - a resource captured here would describe a sheet
		# the next undoable edit has already replaced.
		var chip: Dictionary = run.get("flags_chip", {})
		if not chip.is_empty():
			chip["event_uid"] = event_uid
			chip["first_index"] = index
			chip["last_index"] = last
			leads[index]["flags_chip"] = chip
		for consumed_index: int in range(index + 1, last + 1):
			consumed[consumed_index] = true
		index = last + 1
	return {"leads": leads, "consumed": consumed}


## The gyro runs in one action lane, in the shape every run here has. Three shapes share the
## pass because they are one idea: the calibration line that stores a neutral point, the line that
## feeds a tilt into movement, and the two-line turn-and-pitch that is mouse look with the phone
## doing the turning. Each is claimed on the event that owns it and none of them moves a byte.
func _gyro_groups(actions: Array) -> Dictionary:
	var leads: Dictionary = {}
	var consumed: Dictionary = {}
	var index: int = 0
	while index < actions.size():
		var line: String = _group_line_text(actions[index])
		if line.is_empty():
			index += 1
			continue
		var turn: Dictionary = EventSheetSentence.gyro_aim_turn_parts(line, sentence_context())
		if not turn.is_empty() and index + 1 < actions.size():
			var pitch: Dictionary = EventSheetSentence.gyro_aim_pitch_parts(
				_group_line_text(actions[index + 1]), sentence_context(), str(turn.get("rate", "")))
			if not pitch.is_empty():
				leads[index] = {
					"text": EventSheetL10n.translate("Aim by gyro"),
					"note": EventSheetSentence.gyro_aim_note(),
					"object": EventSheetSentence.script_object(sentence_context()),
					"evidence": PackedStringArray([line, _group_line_text(actions[index + 1])]),
					"line_count": 2,
					"indices": [index, index + 1]
				}
				consumed[index + 1] = true
				index += 2
				continue
		var single: Dictionary = EventSheetSentence.tilt_steer_parts(line, sentence_context())
		var object_label: String = EventSheetSentence.script_object(sentence_context())
		if single.is_empty():
			single = EventSheetSentence.tilt_neutral_parts(line, sentence_context())
			object_label = EventSheetSentence.OBJECT_SYSTEM
		if not single.is_empty():
			leads[index] = {
				"text": str(single.get("text", "")),
				"note": str(single.get("note", "")),
				"object": object_label,
				"evidence": PackedStringArray([line]),
				"line_count": 1,
				"indices": [index]
			}
		index += 1
	return {"leads": leads, "consumed": consumed}


## The hierarchy run that STARTS at `index`, as {text, note, object, last}, or {} when
## nothing there is one. Only a run of more than one line is claimed: a lone `reparent` already reads
## as its own sentence through the shared grammar, and wrapping it here would say the same thing
## twice and cost the row its own chips.
func _hierarchy_run_at(actions: Array, index: int) -> Dictionary:
	if index + 1 >= actions.size():
		return {}
	var first: String = _group_line_text(actions[index])
	# This pass runs on every action of every event, and the overwhelmingly common answer is "this is
	# not a hierarchy move" - so it costs two substring searches before anything parses a line.
	if first.is_empty() or not (first.contains("reparent(") or first.contains("remove_child(")):
		return {}
	var context: Dictionary = sentence_context()
	# The remove-then-add pair, which is one move said in two lines.
	var paired: Dictionary = EventSheetSentence.remove_then_add_sentence(
		first, _group_line_text(actions[index + 1]), context)
	if not paired.is_empty():
		return {"text": _joined_segments(paired), "note": "",
			"object": str(paired.get("object", "")), "last": index + 1}
	# A reparent whose transform or lifetime flags were written out beneath it.
	var moved: Dictionary = EventSheetSentence.reparent_call_parts(first, context)
	if moved.is_empty():
		return {}
	var flags: Dictionary = {}
	var last: int = index
	var cursor: int = index + 1
	while cursor < actions.size():
		var flag: String = EventSheetSentence.hierarchy_flag_line(
			_group_line_text(actions[cursor]), str(moved.get("child_value", "")),
			str(moved.get("parent_value", "")))
		if flag.is_empty():
			break
		flags[flag] = true
		last = cursor
		cursor += 1
	# What makes this ONE row rather than a move followed by two other steps: an ordinary child already
	# inherits its parent's WHOLE transform, so a follower on its own changes nothing and a
	# `top_level` on its own turns every part off. Only the pair says "follow these parts and not
	# those", which is what a partial set of transform flags IS - and it is the only shape that may
	# swallow the lines beneath the move. Turning the lifetime flag off is its own honest case: the
	# handler that saves the child from being freed with its parent says that by itself.
	if not (flags.has("destroy_with_parent") or (flags.has("top_level") and flags.has("follower"))):
		return {}
	var sentence: Dictionary = EventSheetSentence.reparent_sentence(
		str(moved.get("child", "")), str(moved.get("parent_value", "")),
		str(moved.get("keep_place", "")), context)
	if sentence.is_empty():
		return {}
	_note_pattern("hierarchy", first)
	return {"text": _joined_segments(sentence), "note": _hierarchy_flag_note(flags),
		"object": str(sentence.get("object", "")), "last": last,
		"flags_chip": _hierarchy_flags_chip(actions, moved, flags, index, last)}


## The flags a hierarchy run was written with, as the ticks the dialog shows them as, beside the
## spelling of the move itself. The transform words are stated in the code only when they are OFF -
## Godot's default for every one of them is on - so a member the run never wrote is a ticked box.
func _hierarchy_flags_chip(actions: Array, moved: Dictionary, flags: Dictionary, first: int,
		last: int) -> Dictionary:
	var dimension: String = ""
	for member_index: int in range(first, last + 1):
		var line: String = _group_line_text(actions[member_index])
		if line.contains("RemoteTransform2D"):
			dimension = "2D"
		elif line.contains("RemoteTransform3D"):
			dimension = "3D"
	return {
		"child": str(moved.get("child", "")),
		"child_value": str(moved.get("child_value", "")),
		"parent_value": str(moved.get("parent_value", "")),
		"dimension": dimension,
		"flags": {
			"position": not flags.has("update_position"),
			"angle": not flags.has("update_rotation"),
			"size": not flags.has("update_scale"),
			"destroy": not flags.has("destroy_with_parent"),
			"keep_place": str(moved.get("keep_place", "")).strip_edges() != "false"
		}
	}


## The flag chips a hierarchy row wears - every flag the run turned OFF said with a ✗ and the
## rest with a ✓, so the row shows the whole set rather than only what changed. "" when the run set
## none of them, which is the plain child that needs no chips at all.
func _hierarchy_flag_note(flags: Dictionary) -> String:
	var chips: PackedStringArray = PackedStringArray()
	for member: String in HIERARCHY_FLAG_WORDS:
		chips.append("%s %s" % [EventSheetL10n.translate(str(HIERARCHY_FLAG_WORDS[member])),
			"✗" if flags.has(member) else "✓"])
	return " ".join(chips)


## The input-window pair in one action lane. A flag set true and the deadline beside it are one
## thing that happened - a window opened - and the file's own facts have to agree that this is the
## window they describe before the two lines read as one row.
func _input_window_groups(actions: Array) -> Dictionary:
	var leads: Dictionary = {}
	var consumed: Dictionary = {}
	var index: int = 0
	while index < actions.size() - 1:
		var first: String = _group_line_text(actions[index])
		var second: String = _group_line_text(actions[index + 1])
		# The prompt line, when there is one, is the third: the window OWNS it, so it belongs to the
		# row that opened the window rather than standing beside it as a stray label assignment.
		var third: String = _group_line_text(actions[index + 2]) if index + 2 < actions.size() else ""
		var opened: Dictionary = EventSheetSentence.input_window_parts(first, second,
			sentence_context(), third)
		if opened.is_empty():
			# The other half of the same promise: the flag going false with the prompt coming off
			# beneath it is one window shutting, not an assignment and a label edit.
			var closed: Dictionary = EventSheetSentence.input_window_close_parts(first, second,
				sentence_context())
			if closed.is_empty():
				index += 1
				continue
			leads[index] = {
				"text": str(closed.get("text", "")),
				"note": str(closed.get("note", "")),
				"object": EventSheetSentence.OBJECT_SYSTEM,
				"evidence": PackedStringArray([first, second]),
				"line_count": 2,
				"indices": [index, index + 1]
			}
			consumed[index + 1] = true
			index += 2
			continue
		var has_prompt: bool = not str(opened.get("prompt", "")).is_empty()
		var evidence: PackedStringArray = PackedStringArray([first, second])
		if has_prompt:
			evidence.append(third)
		leads[index] = {
			"text": str(opened.get("text", "")),
			"note": str(opened.get("note", "")),
			"object": EventSheetSentence.OBJECT_SYSTEM,
			"evidence": evidence,
			"line_count": 3 if has_prompt else 2,
			"indices": [index, index + 1, index + 2] if has_prompt else [index, index + 1]
		}
		consumed[index + 1] = true
		if has_prompt:
			consumed[index + 2] = true
		index += 3 if has_prompt else 2
	return {"leads": leads, "consumed": consumed}


## The two lines a rail ride is written as - the offset walked forward by a speed, and the body
## put on the point the curve bakes there - as the ONE row they are. Both halves or neither: an
## offset stepped without the position write beside it is arithmetic on a number, and a position
## write on its own is somebody placing an object on a path rather than riding it.
##
## Gated, like every reading in this shape, on the file's own grind facts: without a closest-offset
## snap and a baked sample somewhere in the same file there is nothing here to recognise.
func _grind_ride_groups(actions: Array) -> Dictionary:
	var leads: Dictionary = {}
	var consumed: Dictionary = {}
	var facts: Dictionary = sentence_context().get("grind", {})
	if facts.is_empty():
		return {"leads": leads, "consumed": consumed}
	var offset: String = str(facts.get("offset", ""))
	var rail: String = str(facts.get("rail", ""))
	var index: int = 0
	while index < actions.size() - 1:
		var first: String = _group_line_text(actions[index])
		var second: String = _group_line_text(actions[index + 1])
		var stepped: String = EventSheetSentence.grind_step_speed(first, offset)
		if stepped.is_empty() or not EventSheetSentence.is_grind_sample_write(second, rail, offset):
			index += 1
			continue
		leads[index] = {
			"text": EventSheetSentence.grind_ride_text(
				EventSheetSentence.expression_text(stepped, sentence_context())),
			"note": EventSheetSentence.grind_ride_note(rail),
			"object": EventSheetSentence.script_object(sentence_context()),
			"evidence": PackedStringArray([first, second]),
			"line_count": 2,
			"indices": [index, index + 1]
		}
		consumed[index + 1] = true
		index += 2
	return {"leads": leads, "consumed": consumed}


## The two three-line runs a combo game freezes with, each folded into the one row it is: the
## whole game stopped for a few frames (a hit-stop), and one animation player held still while
## everything else keeps running. Both are written as a stop, a REAL-TIME wait and a start, and the
## real-time flag on the wait is what tells them apart from an ordinary pause somebody forgot to
## undo - a wait measured on a stopped clock never ends.
func _freeze_time_groups(actions: Array) -> Dictionary:
	var leads: Dictionary = {}
	var consumed: Dictionary = {}
	# This pass runs on every event of every sheet, and the overwhelmingly common answer is
	# "nothing here freezes anything". Asking that question must not cost a codegen pass over the
	# event's actions, which is exactly what reading their lines back would be.
	if not _actions_might_freeze(actions):
		return {"leads": leads, "consumed": consumed}
	var context: Dictionary = sentence_context()
	var index: int = 0
	while index < actions.size() - 2:
		var first: String = _group_line_text(actions[index])
		# The overwhelmingly common answer is "these three lines are not a freeze", and it must cost a
		# substring test rather than three parses.
		if first.is_empty() or not (first.contains("time_scale") or first.contains("pause()")):
			index += 1
			continue
		var second: String = _group_line_text(actions[index + 1])
		var third: String = _group_line_text(actions[index + 2])
		var frozen: Dictionary = EventSheetSentence.freeze_time_parts(first, second, third, context)
		if frozen.is_empty():
			frozen = EventSheetSentence.animation_pause_parts(first, second, third, context)
		if frozen.is_empty():
			index += 1
			continue
		leads[index] = {
			"text": str(frozen.get("text", "")),
			"note": str(frozen.get("note", "")),
			"object": str(frozen.get("object", EventSheetSentence.OBJECT_SYSTEM)),
			"evidence": PackedStringArray([first, second, third]),
			"line_count": 3,
			"indices": [index, index + 1, index + 2]
		}
		consumed[index + 1] = true
		consumed[index + 2] = true
		# Both freezes are the same combo-game trick at two scales, so both claim the one pattern.
		_note_pattern("animation_combo", first)
		index += 3
	return {"leads": leads, "consumed": consumed}


## Could any of these actions be part of a freeze? A verbatim line that mentions the time scale or a
## pause, or a lifted row whose ID is one of the three a freeze is built from. Deliberately
## generous - it decides whether to LOOK, not what the run is - and deliberately free: it reads
## resources rather than compiling them.
const FREEZE_ACE_IDS: PackedStringArray = ["SetTimeScale", "PauseAnimation", "Wait",
	"PlayAnimation", "Hitstop", "PauseAnimationFor"]


func _actions_might_freeze(actions: Array) -> bool:
	if actions.size() < 3:
		return false
	for action_resource: Variant in actions:
		var raw: RawCodeRow = action_resource as RawCodeRow
		if raw != null:
			if raw.code.contains("time_scale") or raw.code.contains("pause()"):
				return true
			continue
		var action: ACEAction = action_resource as ACEAction
		if action != null and FREEZE_ACE_IDS.has(action.ace_id):
			return true
	return false


## Could any of these actions push something onto a list? Read off the resources rather than
## compiled from them, for the same reason the freeze pre-check is.
func _actions_might_push(actions: Array) -> bool:
	for action_resource: Variant in actions:
		var raw: RawCodeRow = action_resource as RawCodeRow
		if raw != null:
			if raw.code.contains(".append("):
				return true
			continue
		var action: ACEAction = action_resource as ACEAction
		if action != null and action.ace_id == "ArrayAppend":
			return true
	return false


## The pressed input pushed onto a combo buffer with the window stamped beneath it - two lines
## that are one thing the player did, in the Combo Box behaviour's own words.
func _combo_press_groups(actions: Array) -> Dictionary:
	var leads: Dictionary = {}
	var consumed: Dictionary = {}
	# Same discipline as the freeze above: the cheap question first. An event with nothing pushed
	# onto a list cannot be a combo press, and asking the sheet for its facts to find that out
	# would cost more than the answer is worth on the hundreds of events that are not one.
	if actions.size() < 2 or not _actions_might_push(actions):
		return {"leads": leads, "consumed": consumed}
	var context: Dictionary = sentence_context()
	if (context.get("combo_lists", {}) as Dictionary).is_empty():
		return {"leads": leads, "consumed": consumed}
	var index: int = 0
	while index < actions.size() - 1:
		var first: String = _group_line_text(actions[index])
		if first.is_empty() or not first.contains(".append("):
			index += 1
			continue
		var pressed: Dictionary = EventSheetSentence.combo_press_parts(first,
			_group_line_text(actions[index + 1]), context)
		if pressed.is_empty():
			index += 1
			continue
		leads[index] = {
			"text": str(pressed.get("text", "")),
			"note": str(pressed.get("note", "")),
			"object": EventSheetSentence.script_object(context),
			"evidence": PackedStringArray([first, _group_line_text(actions[index + 1])]),
			"line_count": 2,
			"indices": [index, index + 1]
		}
		consumed[index + 1] = true
		index += 2
	return {"leads": leads, "consumed": consumed}


## The one line an action stands for, whichever shape it took in the sheet: the verbatim text of a
## raw line, or the line a LIFTED row compiles back to. A half-lifted file is the normal case - the
## importer turns one line of a run into a row while the line beside it stays verbatim - so a run
## that could only see raw text would be recognised or not depending on how much happened to lift,
## which is exactly the drift these runs exist to prevent. "" for a disabled row or a multi-line one.
func _group_line_text(action_resource: Variant) -> String:
	var raw: RawCodeRow = action_resource as RawCodeRow
	if raw != null:
		return raw.code.strip_edges() if raw.enabled and not raw.code.contains("\n") else ""
	var action: ACEAction = action_resource as ACEAction
	if action == null or not action.enabled:
		return ""
	var compiled: String = ActionCodegen.generate_action(action)
	return compiled.strip_edges() if not compiled.contains("\n") else ""


## The condition pairs that are really ONE question, as {"leads": {index: {text, object}},
## "consumed": {index: true}}. The file writes `if data and data.get_custom_data("solid"):` - one
## question with a guard in front of it - and the importer files the two halves as two conditions,
## because that is what the `and` says. Putting them back together is a pure view: the conditions
## themselves are untouched, so the line re-emits exactly as it came in.
## The one thing a second condition must mention before the pair is worth reading as one question.
const JOINED_CONDITION_MARK := ".get_custom_data("

## The other thing a second condition can mention that makes the pair one question: an animation's
## play head. Two comparisons on it fence off a cancel window, and neither half means anything alone.
const ANIMATION_CLOCK_MARK := "current_animation_position"


func _joined_condition_groups(conditions: Array, joiner: String = " and ") -> Dictionary:
	var leads: Dictionary = {}
	var consumed: Dictionary = {}
	var context: Dictionary = sentence_context()
	# Two more runs whose halves mean nothing apart - a roll that is either won or
	# guaranteed, and a health threshold guarded by the phase the fight is in. Which files write one
	# is a whole-file fact already in hand, so the parse below only ever runs on a file that writes
	# one; every other sheet in the world still pays a substring search and nothing more.
	var writes_runs: bool = not (context.get("pity_rolls", {}) as Dictionary).is_empty() \
		or not (context.get("boss_phase_steps", {}) as Dictionary).is_empty()
	var index: int = 0
	while index < conditions.size() - 1:
		var first: String = _condition_expression_of(conditions[index])
		var second: String = _condition_expression_of(conditions[index + 1])
		# This pass runs on every event of every sheet, so the overwhelmingly common answer - "these
		# two questions are not one question" - must cost a substring search, not a parse.
		if first.is_empty() or second.is_empty() \
				or not (writes_runs or second.contains(JOINED_CONDITION_MARK)
					or second.contains(ANIMATION_CLOCK_MARK)):
			index += 1
			continue
		var run: String = "%s%s%s" % [first, joiner, second]
		# A floor and a ceiling on ONE animation's play head are not two questions, they are a
		# cancel window - the slice of a move another move is allowed to interrupt it in. Asked first
		# because the general grammar below would answer the pair as two comparisons and stop.
		var window: Dictionary = EventSheetSentence.animation_window_pieces(run, context)
		if not window.is_empty():
			var window_text: String = ""
			for window_piece: Variant in (window.get("pieces", []) as Array):
				window_text += str((window_piece as Array)[0])
			leads[index] = {"text": window_text.strip_edges(), "object": str(window.get("object", ""))}
			consumed[index + 1] = true
			_note_pattern(str(window.get("pattern", "")), run)
			index += 2
			continue
		var reading: Dictionary = EventSheetSentence.condition_pieces(run, context)
		if str(reading.get("pattern", "")).is_empty():
			index += 1
			continue
		var text: String = ""
		for piece: Variant in (reading.get("pieces", []) as Array):
			text += str((piece as Array)[0])
		leads[index] = {"text": text.strip_edges(), "object": str(reading.get("object", ""))}
		consumed[index + 1] = true
		_note_pattern(str(reading.get("pattern", "")), run)
		index += 2
	return {"leads": leads, "consumed": consumed}


## The plain expression an Expression Is True condition asks, "" for every other kind of condition -
## a joined reading may only ever be built from text the file itself wrote.
func _condition_expression_of(condition_resource: Variant) -> String:
	var condition: ACECondition = condition_resource as ACECondition
	if condition == null or not condition.enabled or condition.negated:
		return ""
	if not (condition.provider_id.is_empty() or condition.provider_id == "Core"):
		return ""
	var params_dict: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
	if condition.ace_id == "ExpressionIsTrue":
		return str(params_dict.get("expr", "")).strip_edges()
	# A comparison the importer filed as a Compare row is text the file wrote too - `phase == 1`
	# reached the sheet as a row rather than as an expression only because the lifter had a row for
	# it. Rebuilt in the file's own spelling, so a joined reading is still built from nothing but
	# what the author typed.
	if condition.ace_id == "CompareVar":
		var compared: String = str(params_dict.get("var_name", "")).strip_edges()
		var operator: String = str(params_dict.get("op", "")).strip_edges()
		var value: String = str(params_dict.get("value", "")).strip_edges()
		if compared.is_empty() or operator.is_empty() or value.is_empty():
			return ""
		return "%s %s %s" % [compared, operator, value]
	return ""


## The ONE cell a scroll-limit run reads as: the sentence, then the edges it set, said quietly. The
## span carries every line it stands for, so hover shows all of them and the row hides nothing; the
## RawCodeRows themselves are untouched, so double-click still opens the exact GDScript.
func _append_scroll_limit_spans(spans: Array, limits: Dictionary, action_index: int,
		line_index: int, action_style_meta: Dictionary) -> void:
	var base: Dictionary = {
		"lane": "action",
		"kind": "action",
		"ace_index": action_index,
		"ace_enabled": true,
		"chip": true,
		"raw_action": true,
		"code_cell": false,
		"line_index": line_index,
		"object_label": str(limits.get("object", ""))
	}
	# Only the SENTENCE carries the "stands for N lines" mark and the lines behind it; repeating them
	# on the note would draw the same chip twice on one row.
	spans.append(_make_span(str(limits.get("text", "")), SemanticSpan.SpanType.ACTION,
		base.duplicate().merged({
			"natural_width": true,
			"compiled_lines": int(limits.get("line_count", 1)),
			"create_object_indices": limits.get("indices", [])
		}, true).merged(action_style_meta, true)))
	# A run whose flags are EDITABLE offers the chip that reopens them as ticks, AHEAD of the
	# note: the note is what wraps to the cell's right edge, so a chip behind it would be laid out
	# past that edge, where nothing is painted. Only the hierarchy run offers one, and only while the
	# row is not read-only - everything else here is a lens over lines nobody may rewrite from a row.
	var flags_chip: Dictionary = limits.get("flags_chip", {})
	if not flags_chip.is_empty() and _viewport._sheet != null and not _viewport._sheet.read_only:
		spans.append(_make_span(" %s" % EventSheetL10n.translate("flags…"),
			SemanticSpan.SpanType.KEYWORD, base.duplicate().merged({
				"kind": "hierarchy_flags",
				"natural_width": true,
				"editable": false,
				"object_label": "",
				"text_color": _viewport._get_event_style().value_highlight_color,
				"hierarchy_flags": flags_chip
			}, true).merged(action_style_meta, false)))
	# The note carries no object label: the row already said whose camera this is. A run whose
	# sentence carries the whole of what happened has no note, and draws no empty span for one.
	if str(limits.get("note", "")).is_empty():
		return
	spans.append(_make_span(" %s" % str(limits.get("note", "")), SemanticSpan.SpanType.VALUE,
		base.duplicate().merged({
			"text_color": _viewport._get_reading_style().muted_text_color, "object_label": ""
		}, true).merged(action_style_meta, false)))


## One `camera.limit_left = 0` line -> {object, side, value}, or {} for anything else. Both spellings
## a bound arrives in are read: the line as typed, and the Set property row the lifter files it as -
## the run reads the same either way, which is the whole point of the shared grammar.
func _scroll_limit_parts(action_resource: Variant) -> Dictionary:
	var text: String = ""
	if action_resource is RawCodeRow and (action_resource as RawCodeRow).enabled:
		var code: String = (action_resource as RawCodeRow).code
		if code.contains("\n"):
			return {}
		text = code.strip_edges()
	elif action_resource is ACEAction and (action_resource as ACEAction).enabled:
		var action: ACEAction = action_resource as ACEAction
		if action.ace_id != "SetProperty":
			return {}
		var ace_params: Dictionary = action.params if not action.params.is_empty() else action.parameters
		text = "%s.%s = %s" % [str(ace_params.get("target", "")), str(ace_params.get("property", "")),
			str(ace_params.get("value", ""))]
	if text.is_empty():
		return {}
	var at: int = EventSheetSentence.top_level_index(text, " = ")
	if at < 0:
		return {}
	var target: String = text.substr(0, at).strip_edges()
	var value: String = text.substr(at + 3).strip_edges()
	if value.is_empty() or not EventSheetSentence.is_simple_target(target):
		return {}
	var bare: String = target.trim_prefix("self.")
	var dot_at: int = bare.rfind(".")
	var member: String = bare if dot_at < 0 else bare.substr(dot_at + 1)
	if not SCROLL_LIMIT_SIDES.has(member):
		return {}
	var owner_text: String = "" if dot_at < 0 else bare.substr(0, dot_at)
	return {
		"object": EventSheetSentence.call_object(owner_text, "", sentence_context()),
		"side": str(SCROLL_LIMIT_SIDES[member]),
		"value": EventSheetSentence.expression_text(value, sentence_context()),
		"line": text
	}


## `var b := bullet_scene.instantiate()` / `b = X.duplicate()` -> {alias, source, copy}, else {}.
func _instantiate_action_parts(action_resource: Variant) -> Dictionary:
	var action: ACEAction = action_resource as ACEAction
	if action == null or not action.enabled:
		return {}
	var params: Dictionary = action.params if not action.params.is_empty() else action.parameters
	var alias: String = str(params.get("name", params.get("var_name", ""))).strip_edges()
	var value: String = str(params.get("value", "")).strip_edges()
	if alias.is_empty() or not EventSheetSentence.is_identifier(alias):
		return {}
	for suffix: String in [".instantiate()", ".duplicate()"]:
		if not value.ends_with(suffix):
			continue
		var source: String = value.substr(0, value.length() - suffix.length()).strip_edges()
		if source.is_empty() or not _is_identifier_path(source):
			return {}
		return {"alias": alias, "source": source, "copy": suffix == ".duplicate()"}
	# ────────────────────────────────────────────────────────────────────────────────────────────
	# Taking a spare out of a pool and making a new one only when the pool is empty IS Create object -
	# pooling is how the object is got hold of, not a different thing to do with it. The row says so
	# with a `pooled` chip and keeps every line of the guard one hover away.
	var pooled: Dictionary = EventSheetPatternReadings.pool_take_parts("%s = %s" % [alias, value])
	if not pooled.is_empty():
		return {"alias": alias, "source": str(pooled.get("scene", "")), "copy": false, "pooled": true}
	return {}


## {alias: {alias, source, copy}} for every LOCAL of this event that was filled from a scene -
## the `var e = Scene.instantiate()` row an event sheet draws at the top of its event. Empty when the
## event declares no such local, which is what keeps the run below from claiming anything.
func _spawned_locals(locals: Array) -> Dictionary:
	var spawned: Dictionary = {}
	for entry: Variant in locals:
		var local: LocalVariable = entry as LocalVariable
		if local == null:
			continue
		var alias: String = local.name.strip_edges()
		var value: String = str(local.default_value).strip_edges()
		if alias.is_empty() or not EventSheetSentence.is_identifier(alias):
			continue
		for suffix: String in [".instantiate()", ".duplicate()"]:
			if not value.ends_with(suffix):
				continue
			var source: String = value.substr(0, value.length() - suffix.length()).strip_edges()
			if source.is_empty() or not _is_identifier_path(source):
				continue
			spawned[alias] = {"alias": alias, "source": source, "copy": suffix == ".duplicate()"}
	return spawned


## The spawned local an action is ABOUT - the plant, the placement or a property set on it - or
## "" when the action has nothing to do with one. What lets a run start at the first line after the
## Local row rather than at the declaration itself.
func _spawn_member_alias(action_resource: Variant, spawned: Dictionary) -> String:
	for alias: Variant in spawned:
		var name_text: String = str(alias)
		if not _plant_parent(action_resource, name_text).is_empty():
			return name_text
		if not _placement_value(action_resource, name_text).is_empty():
			return name_text
		if not _created_property_words(action_resource, name_text).is_empty():
			return name_text
	return ""


## WHERE the freshly made object was planted, as the event-sheet layer it went onto: the node an
## `$FX.add_child(b)` names, or "here" for a plant on the script's own node. "" when the action is not
## the plant at all, which is what the run above tests for.
func _plant_parent(action_resource: Variant, alias: String) -> String:
	var action: ACEAction = action_resource as ACEAction
	if action == null or not action.enabled or alias.is_empty():
		return ""
	var params: Dictionary = action.params if not action.params.is_empty() else action.parameters
	var planted: String = ""
	if action.ace_id.contains("AddChild") or action.ace_id.contains("AddSibling"):
		planted = str(params.get("node", params.get("child", ""))).strip_edges()
	elif action.ace_id == "CallMethod" and str(params.get("method", "")) in ["add_child", "add_sibling"]:
		# The importer files a plain `$FX.add_child(e)` as a call, so the run has to recognise it in
		# that spelling too - otherwise a Create object would collapse or not depending on which row
		# the line happened to lift to, which is the drift the shared reading exists to prevent.
		planted = str(params.get("args", "")).strip_edges()
	if planted != alias or alias.is_empty():
		return ""
	var parent: String = str(params.get("target", params.get("parent", ""))).strip_edges()
	if parent.is_empty() or parent == "self":
		return "here"
	return EventSheetSentence.object_of_reference(parent)


## A `b.angle = 90` that comes with the spawn, as the `angle = 90` chip the Create object row
## says it with. "" for anything that is not a property of the new object, which ends the run.
func _created_property_words(action_resource: Variant, alias: String) -> String:
	var action: ACEAction = action_resource as ACEAction
	if action == null or not action.enabled or alias.is_empty():
		return ""
	if not action.ace_id.contains("SetProperty"):
		return ""
	var params: Dictionary = action.params if not action.params.is_empty() else action.parameters
	if str(params.get("target", "")).strip_edges() != alias:
		return ""
	var property_name: String = str(params.get("property", "")).strip_edges()
	if property_name.is_empty():
		return ""
	return "%s = %s" % [property_name.replace("_", " "),
		_reading_sentence(EventSheetSentence.expression_text(str(params.get("value", ""))))]


## True when the action is the `add_child(b)` / `add_sibling(b)` (on this node or on a named parent)
## that puts the freshly made object into the tree.
func _plants_node(action_resource: Variant, alias: String) -> bool:
	return not _plant_placement_word(action_resource, alias).is_empty()


## WHERE the freshly made object was planted, in the sheet's words - "next to it" for a sibling
## (which `get_parent().add_child(b)` is, whatever it is spelled as) and "inside it" for a child of
## this node. "" when the action is not the plant at all.
##
## Both spellings count: the picked Add Child row, and the plain `get_parent().add_child(b)` line a
## hand-written script writes, which lifts to no ACE of its own. Only an EXACT one-argument call on
## the alias is claimed - a plant with extra arguments is doing something the row cannot say.
func _plant_placement_word(action_resource: Variant, alias: String) -> String:
	if alias.is_empty():
		return ""
	var action: ACEAction = action_resource as ACEAction
	if action != null:
		if not action.enabled:
			return ""
		var params: Dictionary = action.params if not action.params.is_empty() else action.parameters
		if action.ace_id.contains("AddSibling"):
			return "next to it" if str(params.get("node", params.get("child", ""))).strip_edges() == alias else ""
		if action.ace_id.contains("AddChild"):
			return "inside it" if str(params.get("node", params.get("child", ""))).strip_edges() == alias else ""
		if action.ace_id != "CallMethod":
			return ""
		return _plant_call_placement("%s.%s(%s)" % [str(params.get("target", "")),
			str(params.get("method", "")), str(params.get("args", ""))], alias)
	var raw: RawCodeRow = action_resource as RawCodeRow
	if raw == null or not raw.enabled:
		return ""
	return _plant_call_placement(raw.code.strip_edges(), alias)


## The placement word one CALL says, or "" when the line is not a plant of `alias`.
func _plant_call_placement(code: String, alias: String) -> String:
	var text: String = code.strip_edges()
	if text.contains("\n"):
		return ""
	for entry: Array in [["get_parent().add_child(", "next to it"], ["add_sibling(", "next to it"],
			["self.add_sibling(", "next to it"], ["add_child(", "inside it"], ["self.add_child(", "inside it"]]:
		var head: String = str(entry[0])
		if text.begins_with(head) and text == "%s%s)" % [head, alias]:
			return str(entry[1])
	return ""


## The value of a `b.global_position = P` / `b.position = P` that immediately follows, or "" when the
## next line is anything else. Only the FIRST placement joins the row: the ones after it are ordinary
## "set a property of the new object" actions, and an event sheet draws those separately too.
func _placement_value(action_resource: Variant, alias: String) -> String:
	var action: ACEAction = action_resource as ACEAction
	if action == null or not action.enabled or alias.is_empty():
		return ""
	if not action.ace_id.contains("SetProperty"):
		return ""
	var params: Dictionary = action.params if not action.params.is_empty() else action.parameters
	if str(params.get("target", "")).strip_edges() != alias:
		return ""
	var property_name: String = str(params.get("property", "")).strip_edges()
	if property_name != "global_position" and property_name != "position":
		return ""
	return str(params.get("value", "")).strip_edges()


## The sentence itself. The object created is named the way an event sheet names it - the scene's
## ROOT node - whenever the source is a preloaded scene this sheet declares; otherwise the variable's
## own name, which is the honest answer when nothing else is known.
func _create_object_text(source: String, alias: String, position_text: String, copy: bool,
		pooled: bool = false, layer: String = "", extras: PackedStringArray = PackedStringArray(),
		placement_word: String = "") -> String:
	var shown: String = source
	var resolved: Dictionary = _lens_scene_vars.get(source, {}) as Dictionary
	if not resolved.is_empty() and not str(resolved.get("name", "")).is_empty():
		shown = str(resolved.get("name", ""))
		# The new object answers to its local name for the rest of the event, and draws the scene root's
		# picture while it does - the event-sheet "picked new instance", spelled in Godot's own names.
		var icon_class: String = str(resolved.get("icon_class", ""))
		if not icon_class.is_empty() and not alias.is_empty():
			_lens_class_map[alias] = icon_class
	# Copying a node that is ALREADY in the scene is Clone object; Create object is for making one
	# out of a scene file. Two different things a reader means, so two different words - and the
	# clone says what it made and where it put it, which is the whole of what the two lines did.
	if copy:
		var clone_text: String = "%s %s" % [EventSheetL10n.translate("Clone object"), shown]
		var asides: PackedStringArray = PackedStringArray()
		if not alias.is_empty():
			asides.append("→ %s" % alias)
		if not placement_word.is_empty():
			asides.append(EventSheetL10n.translate(placement_word))
		if not position_text.is_empty():
			asides.append("%s %s" % [EventSheetL10n.translate("at"),
				_reading_sentence(EventSheetSentence.expression_text(position_text))])
		return clone_text if asides.is_empty() else "%s (%s)" % [clone_text, ", ".join(asides)]
	var text: String = "%s %s" % [EventSheetL10n.translate("Create object"), shown]
	# The node the object was added to IS the layer an event sheet makes things on, so the row
	# says which one. A plant on the script's own node adds nothing a reader does not already have.
	if not layer.is_empty() and layer != "here":
		text += " %s %s" % [EventSheetL10n.translate("on layer"), layer]
	if not position_text.is_empty():
		# Through the shared value lens, so the place a thing is made reads exactly as it would in any
		# other cell - `Vector2(10, 20)` is a point, and an event sheet writes a point as `(10, 20)`.
		text += " %s %s" % [EventSheetL10n.translate("at"), _reading_sentence(EventSheetSentence.expression_text(position_text))]
	if not alias.is_empty():
		text += " (%s %s)" % [EventSheetL10n.translate("as"), alias]
	# The chip is the whole difference a pool makes to this row: a spare is reused when one is
	# waiting, and a new object is made when none is.
	if pooled:
		text += " [%s]" % EventSheetL10n.translate("pooled")
	# The properties the file sets on the way in ride along as chips, because setting them is
	# part of making the thing rather than a separate step a reader has to follow.
	for extra: String in extras:
		text += "   %s" % extra
	return text


## Whether a `match` says nothing more than "which of these values is it?", which is the only
## thing an Else-if chain can say back. Every branch must be one or more PLAIN values; a pattern that
## binds (`var n`), destructures (`[a, b]` / `{"k": v}`), or tests a type keeps the switch reading,
## because rewriting it as `subject = pattern` would state something the code does not.
static func is_plain_match_pattern(pattern: String) -> bool:
	var text: String = pattern.strip_edges()
	if text.is_empty():
		return false
	if text == "_":
		return true
	for term: String in EventSheetSentence.split_top_level(text, ", "):
		var value: String = term.strip_edges()
		if value.is_empty():
			return false
		# A binding, a destructuring pattern, an open range, or anything with a call in it.
		if value.begins_with("var ") or value.begins_with("[") or value.begins_with("{") \
				or value.contains("(") or value.contains("..") or value == "..":
			return false
		if value.begins_with("\"") or value.begins_with("'"):
			continue
		if value.is_valid_float() or (value.begins_with("-") and value.substr(1).is_valid_float()):
			continue
		if value == "true" or value == "false" or value == "null":
			continue
		# A bare or dotted identifier - a constant, an enum member, a named value.
		if not _is_identifier_path(value):
			return false
	return true


## `State.PATROL` / `SPEED` - every dot-separated piece a plain identifier. A small local helper on
## purpose: the sentence grammar has the single-identifier test, and this is the one caller that needs
## the dotted form.
static func _is_identifier_path(text: String) -> bool:
	var pieces: PackedStringArray = text.split(".")
	if pieces.is_empty():
		return false
	for piece: String in pieces:
		if not EventSheetSentence.is_identifier(piece):
			return false
	return true


## True when EVERY case of a match is a plain-value branch and the default (if present) is last, which
## is what makes the whole thing readable as one if / else-if / else chain.
func _match_reads_as_else_if(match_row: MatchRow) -> bool:
	if match_row == null or match_row.cases.size() < 1:
		return false
	if match_row.match_expression.strip_edges().is_empty():
		return false
	var subject: String = match_row.match_expression.strip_edges()
	var context: Dictionary = sentence_context()
	for case_index: int in range(match_row.cases.size()):
		var match_case: MatchCase = match_row.cases[case_index]
		if match_case == null:
			return false
		# A pattern that BINDS a name, destructures a list or picks a table apart says something a
		# plain value cannot - and now has words of its own, so those arms join the chain too. Anything
		# neither reading claims still keeps the pattern text it was written as.
		if not ViewportRowBuilder.is_plain_match_pattern(match_case.pattern) \
				and EventSheetSentence.match_pattern_reading(subject, match_case.pattern, context).is_empty():
			return false
		# A `_` anywhere but last would mean the branches after it are dead; that is not a chain.
		if str(match_case.pattern).strip_edges() == "_" and case_index != match_row.cases.size() - 1:
			return false
	return true


## The condition cells of one Else-if arm: the Else chip alone for `_`, the bare test for the first
## case, and the Else chip ABOVE the test for every case after it - which is exactly how an event sheet
## draws an else-if, and exactly what a chained ternary already draws here. Several values in one
## pattern (`"a", "b":`) become the OR block, since that is what the branch means.
func _match_else_if_condition_spans(subject: String, pattern: String, chain_index: int) -> Array[SemanticSpan]:
	var spans: Array[SemanticSpan] = []
	var condition_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	var text: String = pattern.strip_edges()
	# A pattern that says something a plain value cannot draws its own sentence and its own chips.
	var pattern_reading: Dictionary = {} if ViewportRowBuilder.is_plain_match_pattern(text) \
		else EventSheetSentence.match_pattern_reading(subject, text, sentence_context())
	if not pattern_reading.is_empty():
		return _match_pattern_condition_spans(pattern_reading, chain_index, condition_style_meta)
	if chain_index > 0 or text == "_":
		spans.append(_make_span(EventSheetL10n.translate("Else"), SemanticSpan.SpanType.CONDITION, {
			"lane": "condition",
			"kind": "else_keyword",
			"chip": true,
			"hoverable": false,
			"line_index": 0,
			"object_label": _object_label_for("Core", "")
		}.merged(condition_style_meta, true)))
	if text == "_":
		return spans
	var tests: PackedStringArray = PackedStringArray()
	for term: String in EventSheetSentence.split_top_level(text, ", "):
		if not term.strip_edges().is_empty():
			tests.append("%s == %s" % [subject.strip_edges(), term.strip_edges()])
	if tests.is_empty():
		return spans
	# Routed through the shared conjunct/OR splitter so a multi-value branch draws the very same OR
	# block a hand-written `if a or b:` draws, tone lens and all.
	var carrier := EventRowData.new()
	_append_conjunct_condition_lines(carrier, " or ".join(tests), 1 if chain_index > 0 else 0, condition_style_meta)
	for carried: SemanticSpan in carrier.spans:
		_say_equals_once(carried)
		spans.append(carried)
	return spans


## The condition cells of one PATTERN arm: the Else chip when the arm takes whatever is left, the
## arm's own sentence otherwise, and the names it binds as chips after it. The chips sit on the same
## line as the sentence, because what the pattern pulled out is part of what the pattern says.
func _match_pattern_condition_spans(reading: Dictionary, chain_index: int,
		condition_style_meta: Dictionary) -> Array[SemanticSpan]:
	var spans: Array[SemanticSpan] = []
	var sentence: String = str(reading.get("text", ""))
	var is_else: bool = bool(reading.get("is_else", false))
	var line_index: int = 0
	if chain_index > 0 or is_else:
		spans.append(_make_span(EventSheetL10n.translate("Else"), SemanticSpan.SpanType.CONDITION, {
			"lane": "condition",
			"kind": "else_keyword",
			"chip": true,
			"hoverable": false,
			"line_index": 0,
			"object_label": _object_label_for("Core", "")
		}.merged(condition_style_meta, true)))
		# An Else-if's test sits on the SECOND condition line, under the Else chip, exactly as the
		# plain-value chain draws it.
		line_index = 0 if is_else else 1
	if not sentence.is_empty():
		spans.append(_make_span(sentence, SemanticSpan.SpanType.CONDITION, {
			"lane": "condition",
			"kind": "match_pattern",
			"editable": false,
			"line_index": line_index,
			"object_label": _object_label_for("Core", "")
		}.merged(condition_style_meta, true)))
	for chip_text: String in (reading.get("chips", PackedStringArray()) as PackedStringArray):
		spans.append(_make_span(chip_text, SemanticSpan.SpanType.CONDITION, {
			"lane": "condition",
			"kind": "match_binding",
			"editable": false,
			"chip": true,
			"hoverable": false,
			"line_index": line_index
		}.merged(condition_style_meta, true)))
	return spans


## An event sheet compares with a single `=`, and nobody typed the `==` in these cells: the reading
## built it, out of a match pattern that has no operator at all. So it is written the way an event
## sheet writes it. A comparison the user really did type is left exactly as typed, elsewhere and
## on purpose.
func _say_equals_once(span: SemanticSpan) -> void:
	span.text = span.text.replace(" == ", " = ")
	var segments: Array = span.metadata.get("bbcode_segments", []) as Array
	for segment: Variant in segments:
		var piece: Dictionary = segment as Dictionary
		if piece == null:
			continue
		piece["text"] = str(piece.get("text", "")).replace(" == ", " = ")


## The friendly one-line reading of a case-body statement: a sentence when the statement
## grammar knows it ("Set state to State.CHASE"), Object ▸ Verb for a call
## ("Patrol Step ( delta )"), the code text verbatim otherwise. Text-only, display-only.
## `with_file_facts` hands the grammar what the FILE knows - which variable is which class, which
## list is a combo buffer - so a line inside a branch reads with the same knowledge a line in an
## ordinary action lane does. Opt-in rather than the default because most branch bodies are read for
## their shape alone, and asking the sheet for its facts on every line of every branch of every
## switch is a cost nothing else there needs to pay.
func _friendly_statement_text(line: String, with_file_facts: bool = false) -> String:
	var text: String = line.strip_edges()
	var sentence: Dictionary = ViewportRowBuilder.statement_sentence(text,
		sentence_context() if with_file_facts else {})
	if not sentence.is_empty() and sentence.get("segments") is Array:
		var spoken: String = ""
		for segment: Variant in (sentence.get("segments") as Array):
			spoken += str((segment as Dictionary).get("text", ""))
		return spoken
	var call: Dictionary = ViewportRowBuilder.call_parts(text)
	if not call.is_empty():
		var call_target: String = str(call.get("target", ""))
		var lead: String = "" if call_target.is_empty() or call_target == "self" else "%s " % call_target
		var args_text: String = _joined_call_args(call)
		if args_text.strip_edges().is_empty():
			return "%s%s" % [lead, str(call.get("verb", ""))]
		return "%s%s ( %s )" % [lead, str(call.get("verb", "")), args_text]
	return text


## args arrives as one entry per argument - joined here, never stringified as an Array.
func _joined_call_args(call: Dictionary) -> String:
	var args_value: Variant = call.get("args", [])
	if args_value is Array or args_value is PackedStringArray:
		return ", ".join(PackedStringArray(args_value))
	return str(args_value)


## A guard's plain-language reading: a bare self-call humanizes to its verb the way every
## method name already does ("can_see_player()" reads "Can See Player" - a beginner should
## never meet parentheses in a condition cell). The computed-check cue is the ƒ SVG BADGE the
## caller adds in the icon column (the same ƒ collapsed functions wear, one symbol taught
## once), never inline text. A negated guard does NOT say the word "not" - the sentence is
## the positive one and the inversion is the `not` mark in the badge column, the same mark an inverted
## ACE condition has always worn, so one symbol means one thing everywhere on the sheet. Value
## comparisons ("hp < 20") keep their values. Display-only; the hover carries the code.
func _friendly_guard_text(guard: String) -> String:
	var text: String = str(EventSheetViewportLenses.strip_leading_not(guard.strip_edges()).get("text", ""))
	var friendly: String = text
	var call: Dictionary = ViewportRowBuilder.call_parts(text)
	if not call.is_empty() and (str(call.get("target", "")).is_empty() or str(call.get("target", "")) == "self"):
		var args_text: String = _joined_call_args(call)
		friendly = str(call.get("verb", "")) if args_text.strip_edges().is_empty() else "%s ( %s )" % [str(call.get("verb", "")), args_text]
	return friendly


## Whether a guard is inverted, so the caller can draw the mark the sentence no longer says.
## Split from _friendly_guard_text because the two answers go to different places: the words go
## in the condition cell, the inversion goes in the badge column beside it.
func _guard_is_negated(guard: String) -> bool:
	return bool(EventSheetViewportLenses.strip_leading_not(guard.strip_edges()).get("negated", false))


## A body-level `if <guard>:` block inside a match case IS a condition, so it renders as a
## nested condition/action CHILD row - the guard in the condition cell, its statements as the
## actions. Branching never sits in the action lane. Conservative recognition: one `if` header,
## every following line exactly one tab deeper, no elif/else - anything else stays inline text.
func _transition_child_row(case_lines: PackedStringArray, indent: int, match_row: MatchRow) -> EventRowData:
	if case_lines.size() < 2:
		return null
	var head: String = case_lines[0]
	if not head.begins_with("if ") or not head.ends_with(":"):
		return null
	var guard: String = head.substr(3, head.length() - 4).strip_edges()
	if guard.is_empty():
		return null
	var inner: PackedStringArray = PackedStringArray()
	# A guard INSIDE an arm of the object's own machine ends in a transition more often than not, so
	# the same Go to reading the arm's plain lines get applies here. Asked of the match's own subject,
	# because that is the only thing that says which machine these lines are about.
	var own_state: bool = EventSheetStateFacts.is_state_subject(match_row.match_expression)
	for line_index: int in range(1, case_lines.size()):
		if not case_lines[line_index].begins_with("\t"):
			return null
		var inner_line: String = case_lines[line_index].substr(1)
		if inner_line.begins_with("\t") or inner_line.begins_with("elif") or inner_line.begins_with("else"):
			return null
		var stepped: String = "" if not own_state else EventSheetStateFacts.statement_reading(inner_line)
		inner.append(stepped if not stepped.is_empty() else _friendly_statement_text(inner_line))
	var child: EventRowData = _build_condition_action_row(_friendly_guard_text(guard), inner, indent, match_row, _guard_is_negated(guard))
	child.language_block = true
	# A computed-check guard wears the ƒ SVG badge in the icon column - the reader learns at a
	# glance the value comes from a FUNCTION, not a bool variable, without meeting parentheses.
	if _guard_is_call(guard):
		var guard_badge_meta: Dictionary = _viewport.BADGE_TRIGGER_METADATA.duplicate(true)
		guard_badge_meta["badge_bg"] = _viewport._get_reading_style().code_badge_background_color
		guard_badge_meta["badge_fg"] = _viewport._get_reading_style().code_badge_foreground_color
		guard_badge_meta["badge_style"] = "trigger"
		guard_badge_meta["lane"] = "condition"
		guard_badge_meta["line_index"] = 0
		child.spans.insert(0, _make_span("ƒ", SemanticSpan.SpanType.KEYWORD, guard_badge_meta))
	return child


## Whether a guard's core (after any leading `not`) is a bare self-call - the shape that earns
## the ƒ computed-check badge.
func _guard_is_call(guard: String) -> bool:
	var text: String = guard.strip_edges()
	if text.begins_with("not "):
		text = text.substr(4).strip_edges()
	var call: Dictionary = ViewportRowBuilder.call_parts(text)
	return not call.is_empty() and (str(call.get("target", "")).is_empty() or str(call.get("target", "")) == "self")


## Whether a match subject is state-shaped: its trailing identifier (after any `.`/`(`) contains
## the word "state" - `state`, `current_state`, `machine.state`. Derived from the code's own
## naming; display-only.
func _is_state_shaped_subject(match_expression: String) -> bool:
	var subject: String = match_expression.strip_edges().to_lower()
	var last_dot: int = subject.rfind(".")
	if last_dot >= 0:
		subject = subject.substr(last_dot + 1)
	return subject.contains("state")


## The display leaf of a match pattern: `State.PATROL` -> `PATROL`, `"patrol"` -> `patrol`,
## anything else verbatim. Display-only - the pattern itself is untouched.
func _pattern_leaf(pattern_text: String) -> String:
	var leaf: String = pattern_text
	if leaf.length() >= 2 and leaf.begins_with("\"") and leaf.ends_with("\""):
		return leaf.substr(1, leaf.length() - 2)
	var last_dot: int = leaf.rfind(".")
	if last_dot >= 0 and last_dot < leaf.length() - 1:
		return leaf.substr(last_dot + 1)
	return leaf


## Builds a synthetic event-model row: a CONDITION cell (condition_text) on the left, ACTION cells
## (action_lines, one per line) on the right - the sheet's condition -> action idiom without an EventRow
## resource behind it. row_type EVENT gives it the lane divider; _ensure_event_spans keeps these pre-built
## spans. Reusable so any feature can render a construct as sheet-native events (the switch/case dogfoods it;
## exposed via EventSheets.build_condition_action_row for custom blocks). Non-interactive (spans editable:
## false); the caller sets source_resource for double-click routing.
## `negated` is for callers that already turned an inverted guard into its positive sentence
## (_friendly_guard_text does): they pass the inversion here so the mark still gets drawn. Callers
## handing over raw text can leave it false - the lens below finds a leading NOT on its own.
## `condition_spans`, when given, REPLACES the single condition cell this would otherwise draw - the
## Else-if chain hands over its own stacked Else + test lines, built by the same helpers a ternary
## chain uses, so both readings of "one of these branches runs" look identical on the sheet.
func _build_condition_action_row(condition_text: String, action_lines: PackedStringArray, indent: int, source: Resource, negated: bool = false,
		condition_spans: Array[SemanticSpan] = []) -> EventRowData:
	var row := EventRowData.new()
	row.indent = indent
	row.row_type = EventRowData.RowType.EVENT
	row.source_resource = source
	row.line_count = maxi(action_lines.size(), 1)
	var condition_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	var action_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_action_style())
	if not condition_spans.is_empty():
		row.spans = condition_spans.duplicate()
		for line_index: int in range(action_lines.size()):
			row.spans.append(_make_span(action_lines[line_index] if not action_lines[line_index].is_empty() else " ", SemanticSpan.SpanType.ACTION, {
				"lane": "action",
				"kind": "match_case",
				"editable": false,
				"line_index": line_index
			}.merged(action_style, true)))
		return row
	# A lifted `if not <cond>:` shows its inversion as the `not` mark in the badge column, exactly
	# as an inverted ACE condition does, and the sentence beside it is the POSITIVE one. Callers
	# that already stripped the negation pass plain text and nothing happens here.
	var inversion: Dictionary = EventSheetViewportLenses.strip_leading_not(condition_text)
	var shown_condition: String = str(inversion.get("text", condition_text))
	var spans: Array[SemanticSpan] = []
	if negated or bool(inversion.get("negated", false)):
		spans.append(_negated_badge_span(condition_style, 0))
	spans.append_array([
		_make_span(shown_condition if not shown_condition.is_empty() else " ", SemanticSpan.SpanType.CONDITION, {
			"lane": "condition",
			"kind": "match_case",
			"editable": false,
			"line_index": 0
		}.merged(condition_style, true))
	])
	for line_index: int in range(action_lines.size()):
		spans.append(_make_span(action_lines[line_index] if not action_lines[line_index].is_empty() else " ", SemanticSpan.SpanType.ACTION, {
			"lane": "action",
			"kind": "match_case",
			"editable": false,
			"line_index": line_index
		}.merged(action_style, true)))
	row.spans = spans
	return row


## The globals this sheet USES, as rows of its own at the top of it: `Global number Score = 0`
## with `from Game` trailing it and `Game.Score` echoed at the right edge, which is the form you
## would type here. A global is declared once, on an autoload, and read everywhere; until these rows
## the only way to see which ones a sheet touched was to read every parameter in it.
##
## The last of them carries the hairline that separates what this file BORROWS from what it declares.
## Editing one opens the autoload sheet - the declaration lives there, and that is the only place it
## can change.
##
## PURE VIEW: the rows are inert (null source), nothing is added to `sheet.events` and nothing is
## emitted, so an opened file still re-emits byte for byte. Empty on the autoload that DECLARES them
## (its own globals are already its rows) and on a read-only preview, whose head gathers the same
## list into one folder instead of listing it twice.
func build_globals_used_here_rows(sheet: EventSheetResource) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	if sheet == null or sheet.read_only or is_autoload(sheet):
		return rows
	for entry: Dictionary in EventSheetVariableOwners.global_entries(sheet):
		var owner_name: String = str(entry.get("owner", ""))
		var variable_name: String = str(entry.get("name", ""))
		rows.append(_build_variable_row(
			"used_global",
			variable_name,
			str(entry.get("type_name", "")),
			str(entry.get("value", "")),
			0,
			{
				"source_resource": null,
				"row_uid": "variable_used_global_%s_%s" % [owner_name, variable_name],
				"reading_scope": EventSheetVariableSentence.SCOPE_GLOBAL,
				# The declared value arrives as the autoload's own SOURCE TEXT, so it is shown
				# verbatim: quoting it would misread `Vector2.ZERO` as a string.
				"expression_default": true,
				"description": EventSheetL10n.translate("from %s") % owner_name,
				"code_line": EventSheetCodeEcho.reference_line(owner_name, variable_name),
				# Where the declaration actually lives - what the edit gesture opens, and what
				# Ctrl+Click already knows how to jump to.
				"declared_in": _autoload_script_path(owner_name)
			}
		))
	if not rows.is_empty():
		rows[rows.size() - 1].rule_below = true
	return rows


## The script an autoload is registered with, "" when the project has no such singleton.
func _autoload_script_path(autoload_name: String) -> String:
	for entry: Dictionary in EventSheetGlobalVariables.autoload_sheets():
		if str(entry.get("name", "")) == autoload_name:
			return str(entry.get("path", ""))
	return ""


func _build_global_variable_rows(sheet: EventSheetResource) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	if sheet == null:
		return rows
	# AUTHOR ORDER. The view no longer sorts these by name: the order in the dictionary is the
	# order they were written in, which is the order the drag gesture and Sort A-Z write back. A
	# reader who moved `hp` above `speed` finds it there the next time they look.
	var current_group: String = ""
	var group_members: Array[EventRowData] = []
	# Author order lets one Inspector group appear in two runs; each run is its own folder strip, so
	# the strips need their own uids or two of them would share a fold.
	var group_runs: Dictionary = {}
	for var_name: Variant in sheet.variables.keys():
		var descriptor: Dictionary = sheet.variables.get(var_name, {})
		var is_exported: bool = bool(descriptor.get("exported", descriptor.get("exposed", true)))
		var var_attributes: Dictionary = descriptor.get("attributes") if descriptor.get("attributes") is Dictionary else {}
		var row: EventRowData = _build_variable_row(
			"global",
			str(var_name),
			str(descriptor.get("type", "Variant")),
			descriptor.get("default", null),
			0,
			{
				"is_constant": bool(descriptor.get("const", descriptor.get("is_constant", false))),
				# Match the compiler default (exported unless explicitly false) so the Inspector mark
				# agrees with what actually emits as an Inspector-visible @export var.
				"exported": is_exported,
				# The Inspector group (@export_group) this exported var lands in. It is no longer a
				# chip per row - the folder strip below names it once over the whole run - but it
				# still rides in the row metadata, which is what the drag-into-folder gesture reads.
				"group": str(var_attributes.get("group", "")) if is_exported else "",
				"subgroup": str(var_attributes.get("subgroup", "")) if is_exported else "",
				"reading_scope": _sheet_variable_scope(sheet, descriptor),
				"description": str(descriptor.get("description", "")).strip_edges(),
				"code_line": EventSheetCodeEcho.line_for_descriptor(str(var_name), descriptor)
			}
		)
		var group_name: String = _global_variable_group(sheet, str(var_name))
		if group_name != current_group:
			_flush_variable_group(rows, sheet, current_group, group_members, group_runs)
			current_group = group_name
		var landing: Array[EventRowData] = rows if group_name.is_empty() else group_members
		landing.append(row)
		# "changed on the host, seen nowhere" is about the VALUE, so the amber state sits on the
		# line that declares it rather than on whichever event happened to change it - the quiet
		# sheet law, at a variable anchor: no note row, the words in the inbox and the strip.
		_stamp_attention(row, _tagged(FINDINGS_MULTIPLAYER,
			EventSheetMultiplayerFindings.for_subject(_sheet_findings(FINDINGS_MULTIPLAYER),
				EventSheetMultiplayerFindings.ANCHOR_VARIABLE, str(var_name))))
	_flush_variable_group(rows, sheet, current_group, group_members, group_runs)
	return rows


## The scope word a SHEET-LEVEL variable reads with, derived from where the sheet lives: an
## autoload's members are Global, a Resource script's are Fields, a `const` is a Constant, and
## everything else belongs to the object the sheet is.
func _sheet_variable_scope(sheet: EventSheetResource, descriptor: Dictionary) -> String:
	return EventSheetVariableSentence.member_scope(
		bool(descriptor.get("const", descriptor.get("is_constant", false))),
		bool(descriptor.get("static", false)),
		is_autoload(sheet),
		EventSheetVariableSentence.is_resource_host(sheet.host_class)
	)


## The Inspector section a folder strip names: the group, plus the subsection when every row in the
## run shares one - which is what the per-row "Group › Subgroup" chip used to say, said once.
func _folder_strip_label(group_name: String, members: Array[EventRowData]) -> String:
	var shared_subgroup: String = ""
	for index: int in members.size():
		var row: EventRowData = members[index]
		var metadata: Dictionary = row.spans[0].metadata if not row.spans.is_empty() \
			and row.spans[0].metadata is Dictionary else {}
		var subgroup: String = str(metadata.get("variable_subgroup", "")).strip_edges()
		if index == 0:
			shared_subgroup = subgroup
		elif subgroup != shared_subgroup:
			return group_name
	return group_name if shared_subgroup.is_empty() else "%s › %s" % [group_name, shared_subgroup]


## The Inspector group as the ONE thing on the variable list that folds: a slim strip naming the
## folder, with its rows as children so the existing fold arrow and the bubble outline both work, and
## the rows themselves left at the same indent as every other declaration. Rows are never pushed
## sideways by a bracket around them.
func _flush_variable_group(rows: Array[EventRowData], sheet: EventSheetResource, group_name: String,
		members: Array[EventRowData], group_runs: Dictionary,
		uid_prefix: String = "variable_group") -> void:
	if group_name.is_empty() or members.is_empty():
		members.clear()
		return
	var run_index: int = int(group_runs.get(group_name, 0))
	group_runs[group_name] = run_index + 1
	var strip := EventRowData.new()
	strip.indent = 0
	strip.row_type = EventRowData.RowType.SECTION
	strip.variable_row = true
	strip.source_resource = sheet
	strip.row_uid = "%s_%s_%d" % [uid_prefix, group_name, run_index]
	strip.children = members.duplicate()
	strip.folded = bool(_viewport._fold_state.get(strip.row_uid, false))
	strip.spans = [
		_make_span(
			_folder_strip_label(group_name, members),
			SemanticSpan.SpanType.KEYWORD,
			{
				"kind": "variable",
				"editable": false,
				"group_chip": true,
				"variable_group": group_name,
				"variable_scope": "global",
				"variable_name": "",
				"text_color": _viewport._get_reading_style().category_chip_foreground_color,
				"hover_note": EventSheetL10n.translate("An Inspector section. Double-click to rename it.")
			}
		)
	]
	rows.append(strip)
	members.clear()


## The same labelled, foldable strip over a run of consecutive MEMBER variables in an opened
## `.gd`. An `@export_group("Movement")` is one folder whether the sheet stores its variables in the
## dictionary or as rows of the event tree, so a reader meets one shape either way, and the rows keep
## their indent: a folder never pushes what it holds sideways.
##
## A pure view pass over the already-built list, run after the fence pairing and the read-only head
## (both of which walk a flat list of declarations and must not meet a strip in their place). Skipped
## on a read-only preview, whose head already gathers the same knobs into its own group bars.
func group_variable_rows_by_folder(rows: Array[EventRowData], sheet: EventSheetResource) -> Array[EventRowData]:
	if sheet == null or sheet.read_only:
		return rows
	var grouped: Array[EventRowData] = []
	var members: Array[EventRowData] = []
	var current_group: String = ""
	# The @export_group in force. Godot's grouping runs until the NEXT group line, and the importer
	# records it on the FIRST member of each run only - so it is carried forward here, or every
	# member but the first would land outside its own folder.
	var declared_group: String = ""
	# One folder can appear in two runs (a plain member splits it, or the file comes back to it), and
	# each run is its own strip - so the strips need their own uids or the two would share a fold.
	var group_runs: Dictionary = {}
	for row_data: EventRowData in rows:
		var variable: LocalVariable = row_data.source_resource as LocalVariable
		var is_member: bool = variable != null and row_data.variable_row and row_data.indent == 0
		if is_member:
			var declared: String = str((variable.attributes as Dictionary).get("group", "")).strip_edges() if variable.attributes is Dictionary else ""
			if not declared.is_empty():
				declared_group = declared
		elif not _is_spacing_row(row_data):
			# Past the declarations. A folder never leaps over the events below them - and a blank
			# line between two knobs is spacing the round trip keeps, not the end of a group.
			declared_group = ""
		var group_name: String = declared_group if is_member and variable.exported else ""
		if group_name != current_group:
			_flush_variable_group(grouped, sheet, current_group, members, group_runs, "variable_tree_group")
			current_group = group_name
		if group_name.is_empty():
			grouped.append(row_data)
		else:
			members.append(row_data)
	_flush_variable_group(grouped, sheet, current_group, members, group_runs, "variable_tree_group")
	return grouped


## True for a row that is only the blank line the round trip keeps between two declarations - spacing,
## which neither belongs to a folder nor ends one.
static func _is_spacing_row(row_data: EventRowData) -> bool:
	return row_data != null and row_data.source_resource is RawCodeRow and is_blank_block((row_data.source_resource as RawCodeRow).code.split("
"))


## An exported global's Inspector group ("" when none/unexported) - the adjacency-sort key above.
static func _global_variable_group(sheet: EventSheetResource, var_name: String) -> String:
	var descriptor: Variant = sheet.variables.get(var_name, {})
	if not (descriptor is Dictionary):
		return ""
	if not bool((descriptor as Dictionary).get("exported", (descriptor as Dictionary).get("exposed", true))):
		return ""
	var attributes: Variant = (descriptor as Dictionary).get("attributes")
	return str((attributes as Dictionary).get("group", "")).strip_edges() if attributes is Dictionary else ""


## Runs of consecutive variable rows sharing one Inspector group - the bubbles the viewport outlines
## around grouped variables so a folder reads as one visual unit. [{start, end, group}] over the flat
## row list (0-based inclusive indices). Static + pure → geometry is testable without a canvas.
static func variable_group_runs(flat_rows: Array) -> Array:
	var runs: Array = []
	var current_group: String = ""
	var run_start: int = -1
	for index: int in range(flat_rows.size() + 1):  # +1: a trailing sentinel closes the last run
		var group: String = ""
		if index < flat_rows.size():
			var row_data: EventRowData = (flat_rows[index] as Dictionary).get("row")
			if row_data != null and not row_data.spans.is_empty() and row_data.spans[0].metadata is Dictionary \
					and str((row_data.spans[0].metadata as Dictionary).get("kind", "")) == "variable":
				group = str((row_data.spans[0].metadata as Dictionary).get("variable_group", ""))
		if group == current_group and not group.is_empty():
			continue
		if not current_group.is_empty() and run_start >= 0:
			runs.append({"start": run_start, "end": index - 1, "group": current_group})
		current_group = group
		run_start = index if not group.is_empty() else -1
	return runs


## The notes under an event: a `variable_reference` naming something this sheet does not
## declare (red, with the nearest name as a one-click fix), and one handed a variable of the wrong
## kind (amber, with the verb that does fit). Both are readings of the ROWS - nothing is written, no
## resource is held, and an event with neither problem grows no rows at all.
##
## Red for the unknown name because the line cannot work; amber for the mismatch because it compiles
## and only misbehaves, which is a different thing to tell somebody.
func _build_variable_note_rows(event_row: EventRow, event_uid: String, indent: int) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	if event_row == null or _viewport._sheet == null:
		return rows
	var entries: Array[Dictionary] = _variable_owner_entries()
	if entries.is_empty():
		return rows
	var owner: String = EventSheetVariableOwners.owner_of_sheet(_viewport._sheet)
	var seen: Dictionary = {}
	for lane: String in ["condition", "action"]:
		var lane_rows: Array = event_row.conditions if lane == "condition" else event_row.actions
		for index: int in range(lane_rows.size()):
			var ace: Variant = lane_rows[index]
			if not (ace is Resource):
				continue
			var params: Dictionary = _ace_params_of(ace as Resource)
			if params.is_empty():
				continue
			var ace_id: String = str((ace as Resource).get("ace_id"))
			for name_text: String in _variable_reference_values(
					str((ace as Resource).get("provider_id")), ace_id, params):
				if seen.has(name_text) or not EventSheetIdentifierRules.is_valid(name_text):
					continue
				seen[name_text] = true
				var unknown: Dictionary = EventSheetVariableOwners.unknown_note(entries, name_text, owner)
				if not unknown.is_empty():
					var suggestion: String = str(unknown.get("suggestion", ""))
					rows.append(_build_variable_note_row(
						event_uid, indent, str(unknown.get("note", "")),
						"" if suggestion.is_empty() else EventSheetL10n.translate("Use %s") % suggestion,
						{"variable_note_name": name_text, "variable_note_to": suggestion,
							"variable_note_fix": "rename"}, true))
					continue
				var mismatch: Dictionary = variable_mismatch_note(
					EventSheetVariableOwners.find(entries, name_text), ace_id)
				if not mismatch.is_empty():
					# The fix swaps the verb for the one that fits, carrying what was typed
					# across to whatever the new verb calls it. The row it will rewrite is named by
					# its LANE and SLOT, never by holding the picked resource: the fix runs through
					# the undo funnel, and the funnel replaces resources as it commits.
					rows.append(_build_variable_note_row(
						event_uid, indent, str(mismatch.get("note", "")), str(mismatch.get("fix_label", "")),
						{"variable_note_name": name_text, "variable_note_to": str(mismatch.get("ace_id", "")),
							"variable_note_fix": "retarget", "variable_note_event": event_row,
							"variable_note_lane": lane, "variable_note_index": index}, false))
	return rows


## The amber note when a verb is handed the wrong kind of variable, and the verb that does fit:
## "nickname is text - Add to wants a number." {} when the pairing is fine, or when the variable's
## type says nothing. Static + pure, so the wording is pinned without a canvas.
static func variable_mismatch_note(entry: Dictionary, ace_id: String) -> Dictionary:
	if entry.is_empty():
		return {}
	var wants: String = str(EventSheetVariableOwners.VARIABLE_VERB_TAKES.get(ace_id, ""))
	if wants.is_empty():
		return {}
	var offered: Array[Dictionary] = []
	offered.append(entry)
	if not EventSheetVariableOwners.variables_for_verb(offered, ace_id).is_empty():
		return {}
	var type_word: String = str(entry.get("type_word", "")).strip_edges()
	if type_word.is_empty():
		return {}
	return {
		"note": EventSheetL10n.translate("%s is %s - %s wants a %s. %s fits.") % [
			str(entry.get("name", "")), type_word, _variable_verb_name(ace_id),
			EventSheetL10n.translate(wants), _variable_verb_name("SetVar")],
		"fix_label": EventSheetL10n.translate("Change to %s") % _variable_verb_name("SetVar"),
		"ace_id": "SetVar"
	}


## The display name of one of the variable verbs, for a note that names it. Read off the registry so
## a renamed verb is named right, with the id as the honest fallback.
static func _variable_verb_name(ace_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	return descriptor.display_name if descriptor != null else ace_id


## The parameters one picked row carries, whichever of the two fields it stored them in.
func _ace_params_of(ace: Resource) -> Dictionary:
	var params: Variant = ace.get("params")
	if params is Dictionary and not (params as Dictionary).is_empty():
		return params as Dictionary
	var parameters: Variant = ace.get("parameters")
	return parameters as Dictionary if parameters is Dictionary else {}


## The value of every `variable_reference` parameter one row carries, off the editor's own registry.
## The picking-apart is shared with the Doctor, which asks the shipped vocabulary the same question.
func _variable_reference_values(provider_id: String, ace_id: String, params: Dictionary) -> PackedStringArray:
	var definition: ACEDefinition = _viewport._find_definition(provider_id, ace_id)
	if definition == null:
		return PackedStringArray()
	return EventSheetVariableOwners.variable_reference_values(definition.parameters, params)


## One variable note, through the shared note row: red when the name cannot work at all, amber when
## the row compiles and only misbehaves - the two colours the sheet already uses for exactly that
## difference, so no new token is minted.
func _build_variable_note_row(event_uid: String, indent: int, message: String, fix_label: String,
		fix_meta: Dictionary, severe: bool) -> EventRowData:
	var reading_style: EventSheetReadingStyle = _viewport._get_reading_style()
	return _build_note_row(
		"variable_note_%s_%s" % [event_uid, str(fix_meta.get("variable_note_name", ""))],
		indent, "variable_note", message,
		reading_style.error_text_color if severe else reading_style.lift_note_badge_foreground_color,
		fix_meta, {} if fix_label.is_empty() else {"label": fix_label, "meta": {}})


## The mistakes one family reads out of this sheet, derived once per sweep and kept under
## its own name. Both families answer the same shape - a message, a subject, a one-click fix and the
## row it hangs under - which is why one cache and one note row serve them and a third is one leg.
func _sheet_findings(family: String) -> Array[Dictionary]:
	if not _sheet_findings_cache.has(family):
		var sheet: EventSheetResource = _viewport._sheet if _viewport != null else null
		match family:
			FINDINGS_PERFORMANCE:
				_sheet_findings_cache[family] = EventSheetPerformanceFindings.findings(sheet)
			FINDINGS_LIGHTING:
				_sheet_findings_cache[family] = EventSheetLightingFindings.findings(sheet)
			FINDINGS_EFFECTS:
				_sheet_findings_cache[family] = EventSheetEffectFindings.findings(sheet)
			FINDINGS_SPAWNING:
				# The scene this sheet's script runs in, which only the self-spawning rule needs. It
				# comes from the index the head's bands already read, so the canvas starts no scan of
				# its own to answer it.
				var scenes: PackedStringArray = EventSheetSceneReplication.scenes_using(
					str(sheet.external_source_path) if sheet != null else "")
				_sheet_findings_cache[family] = EventSheetSpawnFindings.findings(sheet,
					scenes[0] if scenes.size() > 0 else "")
			FINDINGS_COLLISIONS:
				# Asked of the SCRIPT rather than of the scene: the rules need the node this sheet's
				# file sits on, and the reader that answers that is the one the head's bands read.
				_sheet_findings_cache[family] = EventSheetCollisionFindings.findings(sheet,
					str(sheet.external_source_path) if sheet != null else "")
			FINDINGS_LAYERS:
				# The Doctor's Collision Layers section, asked of each row's own emitted lines
				# rather than of the project's files - same wording, same gates, per row.
				_sheet_findings_cache[family] = EventSheetLayerFindings.findings(sheet,
					str(sheet.external_source_path) if sheet != null else "")
			FINDINGS_TOOL_EDITS:
				# The Doctor's Tool edits section, asked of the rows of this one sheet rather than of
				# the project's files - same wording, same gates, per event. It answers with nothing
				# at all unless this is a tool sheet that works on the scene the editor has open.
				_sheet_findings_cache[family] = EventSheetUndoableFindings.findings(sheet,
					str(sheet.external_source_path) if sheet != null else "")
			FINDINGS_SCENE_TRUST:
				# The Doctor's Files section, asked of the rows of this one sheet rather than of the
				# project's files - same wording, same gates, per event. The file path is only the
				# label the sentence leads with.
				_sheet_findings_cache[family] = EventSheetSceneTrustFindings.findings(sheet,
					str(sheet.external_source_path) if sheet != null else "")
			FINDINGS_MIGRATION:
				# The rows whose verb the vocabulary no longer has. The corpus is the EDITOR'S OWN
				# live registry rather than a reflected catalogue: it is the vocabulary this session
				# is actually offering, it answers in constant time per row, and a sweep of a large
				# sheet must never reflect a hundred packs to find out that nothing is missing.
				_sheet_findings_cache[family] = EventSheetMigrationFindings.findings(sheet,
					str(sheet.external_source_path) if sheet != null else "",
					func(provider_id: String, ace_id: String) -> bool:
						return _viewport != null \
							and (_viewport._find_definition(provider_id, ace_id) != null
								or ACERegistry.find_descriptor(provider_id, ace_id) != null))
			FINDINGS_RENAME:
				# The rows a rename made somewhere else left pointing at nothing. The witness is
				# built from the sheet's own file and the scene that runs it, and it answers with
				# nothing at all unless one of those two files was saved while this session watched -
				# which is the whole evidence rule, asked once per sweep rather than per row.
				var own_script: String = str(sheet.external_source_path) if sheet != null else ""
				var scenes: PackedStringArray = EventSheetSceneConnections.scenes_using_script(
					own_script) if not own_script.is_empty() else PackedStringArray()
				_sheet_findings_cache[family] = EventSheetRenameFindings.findings(sheet, own_script,
					EventSheetRenameEvidence.witness_for(own_script,
						scenes[0] if scenes.size() > 0 else ""))
			_:
				_sheet_findings_cache[family] = EventSheetMultiplayerFindings.findings(sheet)
	return _sheet_findings_cache[family]


## Every family's findings about one event row, joined once - what the quiet amber state and the
## selected row's help strip both read, so the stripe, the strip and the Doctor's inbox line are the
## same finding under three roofs. Performance speaks only while the costs lens is on, which is the
## same rule its gutter chips live under: a sheet nobody asked about performance stays quiet.
func _findings_about(event_row: EventRow) -> Array[Dictionary]:
	var about: Array[Dictionary] = []
	about.append_array(_tagged(FINDINGS_MULTIPLAYER,
		EventSheetMultiplayerFindings.for_event(_sheet_findings(FINDINGS_MULTIPLAYER), event_row)))
	about.append_array(_tagged(FINDINGS_LIGHTING,
		EventSheetLightingFindings.for_event(_sheet_findings(FINDINGS_LIGHTING), event_row)))
	about.append_array(_tagged(FINDINGS_EFFECTS,
		EventSheetEffectFindings.for_event(_sheet_findings(FINDINGS_EFFECTS), event_row)))
	about.append_array(_tagged(FINDINGS_SPAWNING,
		EventSheetSpawnFindings.for_event(_sheet_findings(FINDINGS_SPAWNING), event_row)))
	if _viewport != null and bool(_viewport.get("show_costs")):
		about.append_array(_tagged(FINDINGS_PERFORMANCE,
			EventSheetPerformanceFindings.for_event(_sheet_findings(FINDINGS_PERFORMANCE), event_row)))
	about.append_array(_tagged(FINDINGS_COLLISIONS,
		EventSheetCollisionFindings.for_event(_sheet_findings(FINDINGS_COLLISIONS), event_row)))
	about.append_array(_tagged(FINDINGS_LAYERS,
		EventSheetLayerFindings.for_event(_sheet_findings(FINDINGS_LAYERS), event_row)))
	about.append_array(_tagged(FINDINGS_TOOL_EDITS,
		EventSheetUndoableFindings.for_event(_sheet_findings(FINDINGS_TOOL_EDITS), event_row)))
	about.append_array(_tagged(FINDINGS_SCENE_TRUST,
		EventSheetSceneTrustFindings.for_event(_sheet_findings(FINDINGS_SCENE_TRUST), event_row)))
	about.append_array(_tagged(FINDINGS_MIGRATION,
		EventSheetMigrationFindings.for_event(_sheet_findings(FINDINGS_MIGRATION), event_row)))
	about.append_array(_tagged(FINDINGS_RENAME,
		EventSheetRenameFindings.for_event(_sheet_findings(FINDINGS_RENAME), event_row)))
	return about


## The findings as the row will carry them: copies, each tagged with the family that said it, so the
## strip's one door knows which family's fix path to knock on. Copies rather than the cached dicts
## because the tag is the canvas's own note, not part of any family's finding shape.
func _tagged(family: String, found: Array[Dictionary]) -> Array[Dictionary]:
	var tagged: Array[Dictionary] = []
	for finding: Dictionary in found:
		var carried: Dictionary = finding.duplicate()
		carried["family"] = family
		tagged.append(carried)
	return tagged


## How many of a sheet's events hold a verb the vocabulary has since replaced - the whole of what the
## head's migration band says, and the only place in the sheet the fact appears at all.
##
## Counted over the rows themselves rather than remembered anywhere, which is what makes the band
## true in a project that has never carried the version record: the record only adds the "since"
## half. An event is counted ONCE however many superseded verbs it holds, because the band counts
## rows a reader would go and look at.
func _rows_with_a_newer_spelling(sheet: EventSheetResource) -> int:
	if sheet == null or _viewport == null:
		return 0
	var counted: int = _count_newer_spellings(sheet.events)
	for function: Variant in sheet.functions:
		if function != null and function.get("events") is Array:
			counted += _count_newer_spellings(function.get("events") as Array)
	return counted


## The same count over one run of rows, following groups and sub-events down.
func _count_newer_spellings(rows: Array) -> int:
	var counted: int = 0
	for row: Variant in rows:
		if row is EventRow:
			var event_row: EventRow = row
			if not _successor_hint_of(event_row).is_empty():
				counted += 1
			counted += _count_newer_spellings(event_row.sub_events)
		elif row != null and row.get("events") is Array:
			counted += _count_newer_spellings(row.get("events") as Array)
	return counted


## The muted "newer spelling: …" hintline, when a verb in this row has been superseded.
##
## THE FIRST verb of the row that has a forwarding address wins, in reading order (the trigger, then
## the conditions, then the actions) - a row rarely has two, and naming both in one muted line would
## turn a hint into a list. The address itself comes from the shipped vocabulary rather than from
## anything stored on the row, so a verb that gains a successor tomorrow is answered by every sheet
## already written without any of them being touched.
func _stamp_successor_hint(row_data: EventRowData, event_row: EventRow) -> void:
	row_data.successor_hint = _successor_hint_of(event_row)


## One event's hintline, or "" when every verb in it is the current spelling. The band's count and
## the strip's words are the same reading, asked once each, so they can never disagree about which
## rows have moved on.
func _successor_hint_of(event_row: EventRow) -> String:
	if event_row == null or _viewport == null:
		return ""
	for candidate: Array in _successor_candidates(event_row):
		var hint: String = _successor_hint_for(str(candidate[0]), str(candidate[1]))
		if not hint.is_empty():
			return hint
	return ""


## Every verb this row names, in reading order, as [provider_id, ace_id] pairs. The trigger leads
## because it leads the sentence.
func _successor_candidates(event_row: EventRow) -> Array[Array]:
	var named: Array[Array] = []
	if not event_row.trigger_id.strip_edges().is_empty():
		named.append([event_row.trigger_provider_id, event_row.trigger_id])
	for condition: Variant in event_row.conditions:
		if condition is ACECondition:
			named.append([(condition as ACECondition).provider_id, (condition as ACECondition).ace_id])
	for action: Variant in event_row.actions:
		if action is ACEAction:
			named.append([(action as ACEAction).provider_id, (action as ACEAction).ace_id])
	return named


## One verb's hintline, or "" when it has not been superseded. The successor is named by its DISPLAY
## NAME, not by its id: the reader is being told what to write, and what they would write is the row
## they would pick out of the picker.
##
## The chain is walked to its END through the editor's own registry - a verb superseded twice names
## the verb a reader should actually write today, not the one that briefly stood in between - and a
## chain that leaves the installed vocabulary, or comes back on itself, says nothing at all rather
## than sending anybody to an address nobody is at.
func _successor_hint_for(provider_id: String, ace_id: String) -> String:
	var here: ACEDefinition = _viewport._find_definition(provider_id, ace_id)
	if here == null or EventForgeSuccessors.map_of(here).is_empty():
		return ""
	var seen: Dictionary = {here.get_identifier(): true}
	var newest: ACEDefinition = null
	for _hop: int in range(EventForgeSuccessors.MAX_HOPS):
		var map: Dictionary = EventForgeSuccessors.map_of(here)
		if map.is_empty():
			break
		var next_key: String = str(map[EventForgeSuccessors.KEY_ID])
		if seen.has(next_key):
			return ""
		seen[next_key] = true
		var address: PackedStringArray = EventForgeSuccessors.split_key(next_key)
		var next_definition: ACEDefinition = _viewport._find_definition(address[0], address[1])
		if next_definition == null:
			return ""
		newest = next_definition
		here = next_definition
	if newest == null:
		return ""
	return EventSheetL10n.translate("newer spelling: %s") % EventSheetL10n.translate(newest.display_name)


## The quiet amber state, stamped. The note text is every finding's sentence joined the way the
## sheet joins facts elsewhere - the strip under the selected row reads it back verbatim.
func _stamp_attention(row_data: EventRowData, found: Array[Dictionary]) -> void:
	row_data.attention_findings = found
	var said: PackedStringArray = PackedStringArray()
	for finding: Dictionary in found:
		said.append(str(finding.get("message", "")))
	row_data.attention_note = " · ".join(said)


## The receipt of an optimiser fix already applied to this row, said under it - only while the costs
## lens is on. A receipt is the answer to "did that work", which is the one sentence a reader who
## just changed something is owed WHERE they changed it; the optimiser's FINDINGS, like every other
## family's, never hang a row and live in the amber state and the help strip instead.
func _build_receipt_note_rows(event_row: EventRow, uid: String, indent: int) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	if event_row == null or _viewport == null or not bool(_viewport.get("show_costs")):
		return rows
	var sheet: EventSheetResource = _viewport._sheet
	var sheet_path: String = "" if sheet == null else str(sheet.external_source_path)
	var receipt: String = EventSheetOptimiserReceipts.reading(sheet_path, event_row.event_uid)
	if not receipt.is_empty():
		rows.append(_build_variable_note_row(uid, indent, receipt,
			EventSheetL10n.translate("Put it back") if EventSheetOptimiserReceipts.disappointed(sheet_path, event_row.event_uid) else "",
			{"variable_note_fix": FIX_PUT_BACK, "variable_note_event": event_row,
				"variable_note_name": ""}, false))
	return rows


## The fix id the receipt note's button carries. It belongs to the optimiser, not to a family of
## findings, which is why it is named here beside the note that offers it.
const FIX_PUT_BACK := "put_the_fix_back"


func _build_local_variable_rows(event_row: EventRow, indent: int) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	if event_row == null:
		return rows
	for local_variable in event_row.local_variables:
		if not (local_variable is LocalVariable):
			continue
		var descriptor: LocalVariable = local_variable as LocalVariable
		rows.append(
			_build_variable_row(
				"local",
				descriptor.name,
				descriptor.type_name,
				descriptor.default_value,
				indent,
				{
					"is_constant": descriptor.is_constant,
					"owner_event": event_row,
					"variable_index": rows.size(),
					# An event's own local reads in the one shape too: Local leads, and the
					# echo is the `var` line the compiler writes for it. A Static local says so
					# in the same word, and its echo is the class member the declaration hoists to.
					"reading_scope": EventSheetVariableSentence.local_scope(descriptor.static_local),
					"expression_default": descriptor.expression_default or descriptor.inferred_type,
					"code_line": EventSheetCodeEcho.line_for(descriptor)
				}
			)
		)
	return rows


## The Local rows an event's own Local Variable ACTIONS read as. An event sheet declares a local
## at the TOP of the event that owns it, so a `var` line anywhere in the body draws there - in file
## order among the locals - while the work the line does stays in the action lane where it sits.
##
## Purely a reading: the row addresses the very action it came from (its own `ace_index` on an
## EventRow source, the same keying a ternary pair uses), so clicking, dragging and the row menu all
## reach that one statement, and the sheet, the emitted GDScript and the byte round-trip never move.
func _build_promoted_local_rows(event_row: EventRow, indent: int) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	if event_row == null or not event_promotes_locals(event_row):
		return rows
	# A local the camera-ray run already said is not a declaration of its own: the run reads
	# as ONE row in the action lane, and drawing its four locals above that row would say the same
	# thing twice - once as plumbing, which is exactly what the run exists to stop showing.
	var ray_groups: Dictionary = _cursor_ray_groups(event_row.actions)
	var ray_leads: Dictionary = ray_groups.get("leads", {})
	var ray_consumed: Dictionary = ray_groups.get("consumed", {})
	# And the same for a test's verdict local: the action lane does not draw it, so a Local row
	# above the gate would be the one place the folded bookkeeping came back.
	var verdict_consumed: Dictionary = _test_verdict_consumed(event_row)
	# Which Local rows have a configure run to draw under them.
	var setup_runs: Dictionary = _control_setup_groups(event_row).get("runs", {})
	for action_index in event_row.actions.size():
		if ray_leads.has(action_index) or ray_consumed.has(action_index):
			continue
		if verdict_consumed.has(action_index):
			continue
		var action: ACEAction = event_row.actions[action_index] as ACEAction
		if action == null:
			continue
		var promotion: Dictionary = local_declaration_promotion(action)
		if promotion.is_empty():
			continue
		var row_data := EventRowData.new()
		row_data.indent = indent
		row_data.row_type = EventRowData.RowType.SECTION
		row_data.source_resource = event_row
		row_data.row_uid = "local_declaration_%s_%d" % [
			event_row.event_uid if not event_row.event_uid.is_empty() else str(event_row.get_instance_id()),
			action_index
		]
		row_data.line_count = 1
		row_data.disabled = not action.enabled
		var built: Array = []
		append_local_declaration_spans(built, promotion.get("declaration", {}), {
			"lane": "action",
			"kind": "action",
			"ace_index": action_index,
			"ace_enabled": action.enabled,
			"line_index": 0
		}, {})
		var typed_spans: Array[SemanticSpan] = []
		for span: Variant in built:
			if span is SemanticSpan:
				typed_spans.append(span as SemanticSpan)
		row_data.spans = typed_spans
		# What the event did to the Control it just made hangs under the row that made it.
		_append_control_setup_rows(row_data, event_row, setup_runs.get(action_index, {}), indent + 1)
		rows.append(row_data)
	return rows


## The configure run as the rows under its Local row. Each line is built through the very same
## row builder every other statement goes through, so a `Set title to ...` under a dialog says exactly
## what it says anywhere else; the rows are inert, because they stand for statements the event itself
## still holds and the file is never touched.
func _append_control_setup_rows(row_data: EventRowData, event_row: EventRow, run: Dictionary,
		indent: int) -> void:
	if run.is_empty():
		return
	for member_index: int in (run.get("indices", []) as Array):
		var stand_in: EventRow = EventRow.new()
		stand_in.event_uid = "%s_setup%d" % [row_data.row_uid, member_index]
		stand_in.actions.append(event_row.actions[member_index])
		var member_row: EventRowData = _build_event_row(stand_in, indent)
		member_row.row_uid = stand_in.event_uid
		# A line that shapes a dialog runs when the dialog is made - "Always", never the sheet-level
		# "Every Tick", which is what a condition-less row means out at the top and never means here.
		_mark_verb_body(member_row, EventSheetSentence.VerbKind.ACTION, _current_verb_function)
		_ensure_subtree_spans(member_row)
		_make_row_inert(member_row)
		row_data.children.append(member_row)


func _build_variable_row(
	scope_label: String,
	var_name: String,
	type_name: String,
	default_value: Variant,
	indent: int,
	options: Dictionary = {}
) -> EventRowData:
	var row_data := EventRowData.new()
	var owner_event: EventRow = options.get("owner_event", null)
	var variable_index: int = int(options.get("variable_index", -1))
	var is_constant: bool = bool(options.get("is_constant", false))
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.variable_row = true
	var default_source: Resource = owner_event if scope_label == "local" else _viewport._sheet
	row_data.source_resource = options.get("source_resource", default_source)
	row_data.row_uid = str(options.get("row_uid", (
		"variable_local_%s_%d"
		% [owner_event.event_uid if owner_event != null else "none", variable_index]
		if scope_label == "local"
		else "variable_global_%s" % var_name
	)))
	row_data.folded = false
	var variable_meta := {
		"kind": "variable",
		"variable_scope": scope_label,
		"variable_name": var_name,
		"variable_index": variable_index,
		"is_constant": is_constant,
		# The Inspector group rides in the row metadata (not just the chip) so the grouping gestures -
		# the drag-into-folder drop, the bubble outline, chip-rename - can read it without re-lookup.
		"variable_group": str(options.get("group", "")).strip_edges(),
		"variable_subgroup": str(options.get("subgroup", "")).strip_edges()
	}
	# A row standing for a declaration in ANOTHER file carries that file, under the key the
	# navigation already reads: Ctrl+Click jumps there like any include, and the edit gesture opens
	# it, because a declaration can only change where it is written.
	var declared_in: String = str(options.get("declared_in", "")).strip_edges()
	if not declared_in.is_empty():
		variable_meta["include_path"] = declared_in
	# ONE shape for every variable row, authored or opened. The `name : Type` code grammar is
	# gone (it survives on the hover and in the code panel, where a declaration belongs): a row says
	# its SCOPE, then its TYPE in plain words, then the name - "Instance whole number hp = 100". Both
	# words are plain text, never pills; `const` and `static` fold INTO the scope word, and the one
	# Godot-only fact left is a small sliders mark saying the value is editable in the Inspector.
	# The Inspector facts (see EventSheetSettingFacts): a type word the hint settles ("combo",
	# "file", "folder", "flags", "node path"), a value the hint re-reads (an enum's LABEL, a 0-1 range
	# as a percent, a colour's word) and the muted note that says the limits or the choices.
	var facts: Dictionary = options.get("facts", {}) if options.get("facts") is Dictionary else {}
	var reading_style: EventSheetReadingStyle = _viewport._get_reading_style()
	# The type word a READER needs, which is not always the declared one: `const SPEED := 300.0`
	# declares nothing, so the word comes from the value.
	var type_word: String = _reading_type_word(
		type_name, default_value, bool(options.get("expression_default", false))
	)
	var hinted_type_word: String = str(facts.get("type_word", "")).strip_edges()
	if not hinted_type_word.is_empty():
		type_word = hinted_type_word
	# The scope word is DERIVED, never stored: the caller settles it from where the sheet lives
	# (an autoload says Global, a node script Instance, a Resource script Field), and a `const` or a
	# `static var` answers for itself even when nothing else did.
	var scope_word_key: String = str(options.get("reading_scope", ""))
	if scope_word_key.is_empty() and is_constant:
		scope_word_key = EventSheetVariableSentence.SCOPE_CONSTANT
	if scope_word_key.is_empty() and bool(options.get("is_static", false)):
		scope_word_key = EventSheetVariableSentence.SCOPE_SHARED if _is_shared_store() \
			else EventSheetVariableSentence.SCOPE_STATIC
	if scope_word_key.is_empty() and scope_label == "local":
		scope_word_key = EventSheetVariableSentence.SCOPE_LOCAL
	variable_meta["variable_scope_word"] = scope_word_key
	var display_name: String = str(facts.get("name_text", "")).strip_edges()
	if display_name.is_empty():
		display_name = var_name if not var_name.is_empty() else "(unnamed)"
	var code_line: String = str(options.get("code_line", ""))
	var view_mode: int = _variable_row_view()
	var code_only: bool = view_mode == EventSheetCodeEcho.VIEW_CODE and not code_line.is_empty()
	# What the SCENE says about this variable, asked once for the row: {} unless a
	# MultiplayerSynchronizer keeps it in step, which is every variable of every project with no
	# networking in it.
	var sync_entry: Dictionary = _sync_entry(scope_label, var_name, declared_in)
	# The kind cue: an outlined `x` in the badge column, so a declaration is unmistakable while
	# scrolling. A mark, never a word pill.
	row_data.spans = [
		_make_span(
			"x",
			SemanticSpan.SpanType.KEYWORD,
			variable_meta.merged({
				"editable": false,
				"badge": true,
				"badge_style": "outline",
				"badge_natural_width": true,
				"badge_fixed_width": KIND_BADGE_WIDTH,
				"variable_badge": true,
				"badge_bg": reading_style.variable_row_wash_color,
				"badge_fg": reading_style.variable_row_rule_color
			}, true)
		)
	]
	if not code_only:
		if not scope_word_key.is_empty():
			row_data.spans.append(
				_make_span(
					EventSheetVariableSentence.scope_word(scope_word_key),
					SemanticSpan.SpanType.KEYWORD,
					variable_meta.merged({
						"editable": false,
						"variable_scope_span": true,
						"text_color": reading_style.variable_row_rule_color,
						"hover_note": EventSheetVariableSentence.scope_note(scope_word_key)
					}, true)
				)
			)
		if not type_word.strip_edges().is_empty():
			row_data.spans.append(
				_make_span(
					type_word,
					SemanticSpan.SpanType.KEYWORD,
					variable_meta.merged({
						"editable": false,
						"variable_type_span": true,
						"text_color": reading_style.secondary_text_color
					}, true)
				)
			)
		# The name is what a reader came for, so it is the one bold word on the row - and its hover
		# keeps the declaration grammar (`hp : int`) for anyone who wants it.
		#
		# It is also the row's rename field: F2 opens it in place, with the count of what
		# committing will rewrite beside it. `edit_gesture` is what keeps it OUT of every other way
		# in - Enter still edits the value, and a double-click anywhere on the row still opens the
		# variable dialog, so the field belongs to the one key that means "rename this".
		row_data.spans.append(
			_make_span(
				display_name,
				SemanticSpan.SpanType.OBJECT,
				variable_meta.merged({
					"editable": declared_in.is_empty(),
					"edit_kind": "variable_rename",
					"edit_gesture": "rename",
					"variable_name_span": true,
					"bbcode_segments": [{
						"text": display_name,
						"color": _viewport._get_event_style().object_label_color,
						"bold": true,
						"italic": false
					}],
					"hover_note": "%s : %s" % [display_name, type_name if not type_name.is_empty() else "Variant"]
				}, true)
			)
		)
		# The one Godot-only fact a reader needs about a variable, as a mark rather than a word: this
		# value shows up in the Inspector. The Inspector GROUP is not a chip any more - the folder
		# strip above the run names it once.
		if bool(options.get("exported", false)):
			row_data.spans.append(
				_make_span(
					INSPECTOR_BADGE_GLYPH,
					SemanticSpan.SpanType.KEYWORD,
					variable_meta.merged({
						"editable": false,
						"badge": true,
						"badge_style": "glyph",
						"badge_natural_width": true,
						"badge_fixed_width": KIND_BADGE_WIDTH,
						"inspector_badge": true,
						"badge_bg": Color(0.0, 0.0, 0.0, 0.0),
						"badge_fg": reading_style.inspector_chip_foreground_color,
						"hover_note": EventSheetL10n.translate("Editable in the Inspector")
					}, true)
				)
			)
		# And the mark that says this value does not stay on this machine: a synchronizer in the
		# scene keeps it in step, in the mode the stroke spells. Nothing is written into the script
		# for it, so the mark appears and disappears with the .tscn and never with the .gd.
		if not sync_entry.is_empty():
			row_data.spans.append(
				_make_span(
					str(SYNC_BADGE_GLYPHS.get(str(sync_entry.get("mode", "")), "")),
					SemanticSpan.SpanType.KEYWORD,
					variable_meta.merged({
						"editable": false,
						"badge": true,
						"badge_style": "glyph",
						"badge_natural_width": true,
						"badge_fixed_width": KIND_BADGE_WIDTH,
						"sync_badge": true,
						"badge_bg": Color(0.0, 0.0, 0.0, 0.0),
						# The theme's own green-teal accent, dressed by every bundled preset: a mark
						# nobody themed would be the one cue on the row that ignores the theme.
						"badge_fg": _viewport._get_event_style().ace_condition_accent_color,
						"hover_note": EventSheetSceneReplication.mark_hover(sync_entry)
					}, true)
				)
			)
	# A setting with nothing to tune shows nothing to tune: an Inspector button's `= _bake` is
	# which function it calls, and the muted note beside it already says so in words.
	var hide_value: bool = code_only or bool(facts.get("hide_value", false))
	if not hide_value:
		row_data.spans.append(_make_span("=", SemanticSpan.SpanType.OPERATOR, variable_meta.merged({"editable": false}, true)))
	# An expression default (`State.PATROL`, `Vector2.ZERO`, a walrus var's verbatim `100`) is
	# CODE stored as text - quoting it would misread it as a string literal.
	var value_text: String = str(default_value) if bool(options.get("expression_default", false)) else _format_variable_value(default_value)
	value_text = _reading_value_text(value_text)
	# The hint re-reads the value itself where it knows better than the literal does: an enum's
	# number is really its label, a 0-1 range is really a percent, a colour is really a word.
	var hinted_value: String = str(facts.get("value_text", "")).strip_edges()
	if not hinted_value.is_empty():
		value_text = hinted_value
	# The value is the one cell of the row a click edits in place, with the type word beside it
	# as the guide rail. The type it must fit rides on the span so the inline editor can say so
	# without asking the sheet again.
	var value_meta: Dictionary = variable_meta.merged({
		# A borrowed declaration is not this file's to change: nothing on such a row edits here, so
		# the value is not a cell either - the row's one gesture is to open the file that declares it.
		"editable": not hide_value and declared_in.is_empty(),
		"edit_kind": "variable_value",
		"variable_value_span": declared_in.is_empty(),
		"variable_type_word": type_word,
		"variable_type_name": type_name,
		# A value another peer owns is not this machine's to set: the field still opens (the
		# INITIAL value is this file's, and every peer starts from it), with the note beside it
		# saying who the running game will take it from.
		"edit_note": EventSheetL10n.translate("set by the owner") if not sync_entry.is_empty() else ""
	}, true)
	# The swatch belongs beside the colour's WORD, not trailing the row: "tint = white [] #ffffff"
	# reads as one value with its picture, where the same swatch parked after the hex read as an
	# afterthought. The span reserves the swatch's room when it measures, so the muted hex that
	# follows keeps its first character.
	if facts.get("swatch") is Color:
		value_meta["swatch_color"] = facts["swatch"] as Color
	if not hide_value:
		row_data.spans.append(
			_make_span(value_text, SemanticSpan.SpanType.VALUE, value_meta)
		)
	# The limits and the choices, muted, straight after the value - the same slot the Inspector puts
	# them in, and ahead of the knob's own sentence so the fact reads before the prose.
	var hint_note: String = str(facts.get("note", "")).strip_edges() if not code_only else ""
	_append_variable_note(row_data, variable_meta, hint_note)
	# What the SCOPE adds that its word does not say on its own ("shared by every Player"), muted,
	# in the same slot the limits use - a fact about the variable, ahead of its prose.
	var is_static: bool = bool(options.get("is_static", false))
	# The rest of the sentence a shared value's note is the short form of.
	var shared_hover: String = EventSheetL10n.translate("One for the whole editor, kept between sheets.") \
		if _is_shared_store() else ""
	var scope_note: String = str(options.get("scope_note", "")).strip_edges() if not code_only else ""
	_append_variable_note(row_data, variable_meta, scope_note, shared_hover if is_static else "")
	# A static variable says who shares it: one value on the CLASS, so every object of this type reads
	# and writes the same one. Without the note "Static number spawned = 0" looks like an ordinary
	# variable that happens to wear an extra word. A head row already carries the note as its
	# scope_note (above), so it is only added here when nothing said it yet. In a class nothing
	# is ever made of, "shared by every X" names copies that do not exist; what the reader needs
	# there is that this ONE value is the editor's, and it outlives the sheet they are looking at.
	if is_static and scope_note.is_empty() and not code_only:
		_append_variable_note(row_data, variable_meta,
			EventSheetL10n.translate("one for the whole editor") if _is_shared_store() \
				else EventSheetL10n.translate("shared by every %s") % _static_owner_word(),
			shared_hover)
	# A constant the file itself says must never change wears that promise where a reader meets
	# it. The words come from the doc comment above the line, so nothing here decides what is frozen.
	if is_constant and not code_only and _frozen_constants().has(var_name):
		_append_variable_note(row_data, variable_meta, EventSheetL10n.translate("frozen"),
			EventSheetL10n.translate("Named elsewhere: add to it, never rename one."))
	# The knob's own sentence, muted, trailing the value - the `##` doc comment the Inspector shows as
	# its tooltip. A reader of an opened pack should never have to open the .gd to learn what a setting
	# does. Reading shape only; an authored row keeps the tooltip in the variable dialog.
	_append_variable_note(row_data, variable_meta,
		str(options.get("description", "")).strip_edges() if not code_only else "")
	_append_code_echo_span(row_data, variable_meta, code_line, view_mode)
	return row_data


## The scene's word about one variable of THIS sheet, {} when there is none. A local lives and
## dies inside its event and a borrowed declaration belongs to another file, so neither can be the
## property a synchronizer in this object's scene keeps in step.
func _sync_entry(scope_label: String, var_name: String, declared_in: String) -> Dictionary:
	if scope_label == "local" or not declared_in.is_empty() or _viewport == null or _viewport._sheet == null:
		return {}
	return EventSheetSceneReplication.entry_for(
		EventSheetSceneReplication.for_script(str(_viewport._sheet.external_source_path)).get("synced", []),
		var_name)


## A muted note trailing the sentence: the limits a hint sets, what a scope adds beyond its word, a
## frozen constant's promise, the knob's own `##` line. All the same slot and the same quiet voice,
## so all of them are appended the same way. An empty note appends nothing, which is what lets the
## caller compute one and hand it over without a guard of its own.
func _append_variable_note(row_data: EventRowData, variable_meta: Dictionary, note: String,
		hover_note: String = "") -> void:
	if note.strip_edges().is_empty():
		return
	row_data.spans.append(_make_span(note, SemanticSpan.SpanType.COMMENT, variable_meta.merged({
		"editable": false,
		"text_color": _viewport._get_reading_style().muted_text_color,
		"hover_note": hover_note
	}, true)))


## The View dial this sheet is being read at (sentence / both / code). A viewport that has not
## heard of the dial reads at the shipped default, so a preview render and a headless build both
## draw the sentence with its echo.
func _variable_row_view() -> int:
	if _viewport == null:
		return EventSheetCodeEcho.VIEW_BOTH
	return int(_viewport.variable_row_view)


## The code echo at the row's right edge: the exact line the compiler emits for this variable,
## coloured by the script editor's own token colours and resting at a fraction of them. Nothing here
## formats a declaration; the line arrives from the emitter, so the echo can never drift from the
## file. Silent in `sentence` mode, and full-strength in `code` mode, where the row IS the line.
func _append_code_echo_span(row_data: EventRowData, variable_meta: Dictionary, code_line: String,
		view_mode: int) -> void:
	if code_line.strip_edges().is_empty() or view_mode == EventSheetCodeEcho.VIEW_SENTENCE:
		return
	var full_strength: bool = view_mode == EventSheetCodeEcho.VIEW_CODE
	row_data.spans.append(_code_echo_span(
		code_line,
		variable_meta.merged({
			"hover_note": EventSheetL10n.translate("The line this row writes. Click to open it in the code panel.")
		}, true),
		1.0 if full_strength else EventSheetCodeEcho.REST_ALPHA,
		not full_strength
	))


## True when the opened file is a class nothing is ever made of - the shared stores an editor
## keeps its memory in. False for every ordinary script, which is what keeps these words out of a
## game project.
func _is_shared_store() -> bool:
	return bool(EventSheetEditorSourceFacts.facts(_viewport._sheet as EventSheetResource).get("shared_store", false))


## The constants this file says must never be renamed, {} when it says it about none.
func _frozen_constants() -> Dictionary:
	var facts: Variant = EventSheetEditorSourceFacts.facts(_viewport._sheet as EventSheetResource).get("frozen_constants")
	return facts if facts is Dictionary else {}


## What the sheet calls its own object, for the sentence a static variable ends with ("shared by
## every Player"). The same three fallbacks the Include bar names the script with - the class name
## its author gave it, else the scene root that carries it, else the file - so the two never
## disagree. "" when the sheet has no object to name, which is when the note is dropped rather than
## left half-said.
func _static_owner_word() -> String:
	var sheet: EventSheetResource = _viewport._sheet
	if sheet == null:
		return ""
	var object_name: String = sheet.custom_class_name.strip_edges()
	if object_name.is_empty():
		var source_path: String = str(sheet.external_source_path)
		if not source_path.is_empty():
			object_name = str(scene_using_script(source_path).get("root_name", ""))
			if object_name.is_empty():
				object_name = source_path.get_file().get_basename().capitalize()
	return object_name


## The type word a variable READS with, which is not always the one it declares. `const SPEED := 300.0`
## and `var mode := "idle"` declare no type at all, and "any" would tell a reader nothing the value in
## front of them does not already say - so an undeclared type is read off the literal instead. A
## declared type always wins, because the author said it on purpose.
static func _reading_type_word(type_name: String, default_value: Variant, expression_default: bool) -> String:
	var declared: String = type_name.strip_edges()
	if declared.is_empty() or declared == "Variant":
		var inferred: String = _inferred_type_word(default_value, expression_default)
		if not inferred.is_empty():
			return inferred
	return friendly_type_word(declared)


## The type word a literal gives away, "" when the value settles nothing. An expression default is
## stored as SOURCE TEXT (`300.0`, `"idle"`, `[]`), so the shapes are matched as written; a real
## Variant default is matched by its actual type.
static func _inferred_type_word(default_value: Variant, expression_default: bool) -> String:
	if not expression_default:
		match typeof(default_value):
			TYPE_STRING, TYPE_STRING_NAME:
				return friendly_type_word("String")
			TYPE_INT, TYPE_FLOAT:
				# An undeclared number reads "number" whichever literal it was: nothing in
				# `var hp := 100` says the author refused fractions, and "whole number" would.
				return friendly_type_word("float")
			TYPE_BOOL:
				return friendly_type_word("bool")
			TYPE_ARRAY:
				return friendly_type_word("Array")
			TYPE_DICTIONARY:
				return friendly_type_word("Dictionary")
		return ""
	var text: String = str(default_value).strip_edges()
	if text.is_empty():
		return ""
	if text == "true" or text == "false":
		return friendly_type_word("bool")
	if text.begins_with("\"") or text.begins_with("'"):
		return friendly_type_word("String")
	if text.begins_with("["):
		return friendly_type_word("Array")
	if text.begins_with("{"):
		return friendly_type_word("Dictionary")
	if text.is_valid_float():
		return friendly_type_word("float")
	# The two constructor spellings a reader meets constantly. `var tint := Color.WHITE` is a
	# colour and `var home := Vector2.ZERO` is a vector; reading either as "any" would tell them less
	# than the value in front of them already does.
	for constructed: String in ["Color", "Vector2", "Vector3", "Vector4"]:
		if text.begins_with("%s." % constructed) or text.begins_with("%s(" % constructed):
			return friendly_type_word(constructed)
	return ""


## A value in the reading shape. An empty collection reads `empty` - `[]` and `{}` are punctuation a
## reader has to decode, and "nothing in it yet" is the whole fact. A whole number written as a float
## (`300.0`, how GDScript spells a float constant) drops the tail it does not need; `4.5` keeps every
## digit it has.
static func _reading_value_text(value_text: String) -> String:
	var text: String = value_text.strip_edges()
	if text == "[]" or text == "{}" or text == "[  ]" or text == "{  }":
		return EventSheetL10n.translate("empty")
	if _trailing_zero_regex == null:
		_trailing_zero_regex = RegEx.new()
		_trailing_zero_regex.compile("^(-?\\d+)\\.0+$")
	var trimmed: RegExMatch = _trailing_zero_regex.search(text)
	if trimmed != null:
		return trimmed.get_string(1)
	return value_text


static var _trailing_zero_regex: RegEx = null

# ── Event-span assembly (the "model → SemanticSpans" pass) ───────────────────────────────────────


## Beginner-friendly display text for a raw trigger_id (the lifted / lifecycle path, which used
## to print the id verbatim - "signal:on_damaged"). The registered definition's display name
## wins ("On Damaged", including any @ace_name); an unresolved signal id still humanizes
## ("signal:door_opened" -> "On Door Opened"). Display-only: the stored trigger_id (frozen API)
## and the compiled output are untouched.
## A trigger row's words: its own sentence when the event has FILLED IN every slot of it, and its
## plain name otherwise. "On collision with {group}" is only a sentence once a group is chosen;
## until then, and for every trigger whose slots are payload the engine fills at run time (the
## body that entered, the report of what went wrong), there is nothing to put in them and the name
## is the honest reading. Derived from the descriptor rather than listed, so a trigger that grows a
## parameter tomorrow reads as its sentence the moment the parameter is filled.
func _trigger_sentence(event_row: EventRow) -> String:
	var name_words: String = _trigger_display_text(event_row.trigger_provider_id, event_row.trigger_id)
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(
		event_row.trigger_provider_id, event_row.trigger_id)
	if descriptor == null:
		return name_words
	var sentence: String = EventSheetL10n.translate(descriptor.get_display_text().strip_edges())
	if sentence.is_empty() or not sentence.contains("{"):
		return name_words
	for parameter: ACEParam in descriptor.params:
		var slot: String = "{%s}" % parameter.id
		if not sentence.contains(slot):
			continue
		var filled: String = str(event_row.trigger_params.get(parameter.id, "")).strip_edges()
		if filled.is_empty():
			return name_words
		sentence = sentence.replace(slot, _unquoted(filled))
	return name_words if sentence.contains("{") else sentence


## A quoted literal as a reader says it: `"enemies"` is the group Enemies, not a piece of code.
## Anything that is not a plain quoted string is left exactly as it was typed.
func _unquoted(text: String) -> String:
	var bare: String = text.lstrip("&")
	if bare.length() >= 2 and bare.begins_with("\"") and bare.ends_with("\""):
		return bare.substr(1, bare.length() - 2)
	return text


func _trigger_display_text(provider_id: String, trigger_id: String) -> String:
	var definition: ACEDefinition = _viewport._find_definition(provider_id, trigger_id)
	if definition != null and not definition.display_name.strip_edges().is_empty():
		return EventSheetL10n.translate(definition.display_name)
	# Same fallback the condition path uses: when no built definition exists yet, the static
	# descriptor registry still knows the friendly name ("Every Physics Tick", not
	# "OnPhysicsProcess") - without it a lifted trigger prints its raw id.
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, trigger_id)
	if descriptor != null and not descriptor.display_name.strip_edges().is_empty():
		return EventSheetL10n.translate(descriptor.display_name)
	if trigger_id.begins_with("signal:"):
		var signal_name: String = trigger_id.trim_prefix("signal:")
		# A form's own signals have object words in the sheet, exactly as its actions do: a text
		# field's change belongs to Text input, a list's pick to List. Display only - the stored
		# trigger_id is the frozen one, and a signal the table does not name reads as it always did.
		if CONTROL_TRIGGER_WORDS.has(signal_name):
			return EventSheetL10n.translate(str(CONTROL_TRIGGER_WORDS[signal_name]))
		# A signal already NAMED on_* must not read "On On ..." - strip the prefix first.
		return "On %s" % signal_name.trim_prefix("on_").capitalize()
	return trigger_id


## The Control signals a form is wired with, under the object word each one belongs to. Only
## signals that mean ONE thing on one kind of Control are here: `pressed` is every button's and is
## already a published trigger, so it is deliberately absent.
const CONTROL_TRIGGER_WORDS: Dictionary = {
	"text_changed": "Text input ▸ On text changed",
	"text_submitted": "Text input ▸ On submitted",
	"item_selected": "List ▸ On item selected",
	"file_selected": "File chooser ▸ On file chosen",
	"tab_changed": "Tabs ▸ On tab changed"
}


## Sets the tempo glyph + hue on a trigger-badge meta from the event's trigger_id, and returns the glyph.
## SIGNAL keeps the shipped green ➜ from the event style - the common case stays
## byte-identical; every-tick (⟳) / input (⌨) / once (▶) get their own fill so how OFTEN an event runs
## reads at a distance. Shared by both trigger-badge paths (authored ACECondition + lifted trigger_id).
# ── a trigger-shaped poll at the top of a tick handler IS the trigger ───────────────────────────
#
# This is how a beginner writes input in Godot: poll `is_action_just_pressed` inside `_process`. In an
# event sheet the same thing is a top-level trigger, so the row loses the "Every tick" words and its
# condition leads instead. Display only - the event, its resources and the emitted GDScript are the
# ones the file already holds, which is why this needs no reading-mode gate and no byte guard: it is
# one span fewer on a row that is otherwise untouched.
#
# Deliberately narrow. Only the EDGE polls count: `is_action_pressed` asks whether a key is HELD,
# which is a condition every tick and not a trigger, and reading it as one would say the event fires
# once when it fires continuously. An event doing anything of its own - a second condition, a loop, a
# local variable, an Else arm - keeps the tick reading, because there the handler really is a handler.

## The tick handlers whose single edge-poll condition reads as the trigger it is.
const INPUT_TRIGGER_TICKS: PackedStringArray = ["OnProcess", "OnPhysicsProcess"]
## The published conditions that ARE an edge, plus the two expressions a hand-written poll lifts to.
const INPUT_TRIGGER_ACES: PackedStringArray = ["IsActionJustPressed", "IsActionJustReleased"]
const INPUT_TRIGGER_CALLS: PackedStringArray = [
	"Input.is_action_just_pressed(", "Input.is_action_just_released("
]


## True when the connect line that wired this handler asked for a ONE-SHOT connection - the
## sheet's own Trigger once. Read off the verbatim line the lift kept, so nothing here can move a byte.
static func is_one_shot_handler(event_row: EventRow) -> bool:
	if event_row == null:
		return false
	return str(event_row.get_meta("__source_connect_line", "")).contains("CONNECT_ONE_SHOT")


## True when this event is a tick handler whose ONE condition is a just-pressed / just-released poll.
static func is_input_trigger_tick(event_row: EventRow) -> bool:
	if event_row == null or not INPUT_TRIGGER_TICKS.has(event_row.trigger_id):
		return false
	if event_row.trigger != null or event_row.conditions.size() != 1:
		return false
	if not event_row.local_variables.is_empty() or not event_row.pick_filters.is_empty():
		return false
	var condition: ACECondition = event_row.conditions[0] as ACECondition
	if condition == null or not condition.enabled:
		return false
	if INPUT_TRIGGER_ACES.has(condition.ace_id):
		return true
	if condition.ace_id != "ExpressionIsTrue":
		return false
	var params: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
	var expression: String = str(params.get("expr", "")).strip_edges()
	if not expression.ends_with(")"):
		return false
	for head: String in INPUT_TRIGGER_CALLS:
		if expression.begins_with(head):
			return true
	return false


func _apply_trigger_tempo(meta: Dictionary, event_style: EventSheetEventStyle, trigger_id: String) -> String:
	var tempo: String = TriggerResolver.tempo_class_for(trigger_id)
	meta["tempo"] = tempo
	match tempo:
		TriggerResolver.TEMPO_EVERY_TICK:
			meta["badge_bg"] = _viewport._get_reading_style().tempo_every_tick_background_color
			meta["badge_fg"] = _viewport._get_reading_style().tempo_every_tick_foreground_color
			return "⟳"
		TriggerResolver.TEMPO_INPUT:
			meta["badge_bg"] = _viewport._get_reading_style().tempo_input_background_color
			meta["badge_fg"] = _viewport._get_reading_style().tempo_input_foreground_color
			return "⌨"
		TriggerResolver.TEMPO_ONCE:
			meta["badge_bg"] = _viewport._get_reading_style().tempo_once_background_color
			meta["badge_fg"] = _viewport._get_reading_style().tempo_once_foreground_color
			return "▶"
		_:
			meta["badge_bg"] = event_style.trigger_badge_background_color
			meta["badge_fg"] = event_style.trigger_badge_foreground_color
			return "➜"


# ── "Every X seconds" over Godot's two spellings of it ──────────────────────────────────────────
#
# An event sheet's most-used trigger is `Every X seconds`. Godot writes the same thing twice: a repeating
# Timer node plus a `timeout` handler, or `while true: await get_tree().create_timer(x).timeout` with
# the work in the loop. Both read as the trigger here. DISPLAY ONLY - the file keeps its handler, its
# connect line and its loop, and the connect note still sits on the `_ready` row.
#
# Only a REPEATING timer qualifies. A `one_shot = true` anywhere in the file takes its node back out
# (that Timer keeps `On timeout`, which is what it does), and a Timer whose wait_time the script never
# sets is left alone rather than guessed at - a wrong number is worse than the plain reading.

## Timer node name -> the wait_time the file sets on it, cached per sheet instance the way the lens
## caches are (a rebuild on the same sheet reuses it; a reopened file rebuilds it).
var _repeat_timers: Dictionary = {}
var _repeat_timers_stamp: int = -1


func _repeating_timers() -> Dictionary:
	var sheet: EventSheetResource = _viewport._sheet
	var stamp: int = 0 if sheet == null else int(sheet.get_instance_id())
	if stamp == _repeat_timers_stamp:
		return _repeat_timers
	_repeat_timers_stamp = stamp
	_repeat_timers = {}
	if sheet == null:
		return _repeat_timers
	var statements: PackedStringArray = PackedStringArray()
	_collect_statement_text(sheet.events, statements)
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			_collect_statement_text((entry as EventFunction).events, statements)
	if _timer_wait_regex == null:
		_timer_wait_regex = RegEx.new()
		if _timer_wait_regex.compile("^([^\\s=]+)\\.wait_time\\s*=\\s*(.+)$") != OK:
			return _repeat_timers
	if _timer_one_shot_regex == null:
		_timer_one_shot_regex = RegEx.new()
		if _timer_one_shot_regex.compile("^([^\\s=]+)\\.one_shot\\s*=\\s*(true|false)$") != OK:
			return _repeat_timers
	var wait_regex: RegEx = _timer_wait_regex
	var one_shot_regex: RegEx = _timer_one_shot_regex
	var waits: Dictionary = {}
	var one_shot: Dictionary = {}
	for statement: String in statements:
		var text: String = statement.strip_edges()
		var wait_match: RegExMatch = wait_regex.search(text)
		if wait_match != null:
			waits[timer_node_name(wait_match.get_string(1))] = wait_match.get_string(2).strip_edges()
			continue
		var shot_match: RegExMatch = one_shot_regex.search(text)
		if shot_match != null and shot_match.get_string(2) == "true":
			one_shot[timer_node_name(shot_match.get_string(1))] = true
	for node_name: String in waits.keys():
		if not one_shot.has(node_name):
			_repeat_timers[node_name] = str(waits[node_name])
	return _repeat_timers


## The bare node NAME behind any of the spellings a script reaches a Timer with - `$SpawnTimer`,
## `%Spawn`, `get_node("Timers/Spawn")`, a plain member. "" when there is no name to read.
static func timer_node_name(reference: String) -> String:
	var text: String = reference.strip_edges()
	if text.begins_with("get_node(") and text.ends_with(")"):
		text = text.substr(9, text.length() - 10).strip_edges()
	text = text.lstrip("$%").strip_edges()
	text = text.trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'")
	if text.contains("/"):
		text = text.get_slice("/", text.get_slice_count("/") - 1)
	return text.strip_edges()


## Every statement the sheet holds, as source text - what the Timer scan reads. Recursive through
## events, sub-events and groups; an ACE contributes the line it compiles to, a verbatim block its
## own lines. Non-mutating.
func _collect_statement_text(rows: Array, into: PackedStringArray) -> void:
	for row: Variant in rows:
		if row is RawCodeRow:
			into.append_array((row as RawCodeRow).code.split("\n"))
		elif row is ACEAction:
			var generated: String = ActionCodegen.generate_action(row as ACEAction)
			if not generated.is_empty():
				into.append_array(generated.split("\n"))
		elif row is EventGroup:
			_collect_statement_text(_viewport._group_children(row as EventGroup), into)
		elif row is EventRow:
			var event_row: EventRow = row as EventRow
			_collect_statement_text(event_row.actions, into)
			_collect_statement_text(event_row.sub_events, into)


## What a lifted `timeout` handler READS as when its Timer repeats: {"seconds", "timer"}, else {}.
func _repeating_timer_reading(event_row: EventRow) -> Dictionary:
	if event_row == null or event_row.trigger_id != "OnTimeout":
		return {}
	var node_name: String = timer_node_name(event_row.trigger_source_path)
	if node_name.is_empty():
		return {}
	var seconds: String = str(_repeating_timers().get(node_name, ""))
	if seconds.is_empty():
		return {}
	return {"seconds": _trimmed_seconds(seconds), "timer": node_name}


## `2.0` reads as `2` - a row shows the number, not the float spelling. Anything that is not a
## plain number (an expression, a knob name) is left exactly as the file wrote it.
static func _trimmed_seconds(text: String) -> String:
	if not text.is_valid_float():
		return text
	var value: float = text.to_float()
	return str(int(value)) if is_equal_approx(value, float(int(value))) else text


## The seconds a function body loops on when it IS the await spelling of Every X seconds - a body
## whose first two statements are `while true:` and `await get_tree().create_timer(X).timeout`.
## "" for every other body, so nothing else is ever re-titled.
static func await_loop_seconds(code: String) -> String:
	var lines: PackedStringArray = code.split("\n")
	var header_index: int = -1
	for index: int in range(lines.size()):
		var text: String = lines[index].strip_edges()
		if text.is_empty():
			continue
		if not text.begins_with("func ") and not text.begins_with("static func "):
			return ""
		header_index = index
		break
	if header_index < 0:
		return ""
	var body: PackedStringArray = PackedStringArray()
	for index: int in range(header_index + 1, lines.size()):
		if not lines[index].strip_edges().is_empty():
			body.append(lines[index].strip_edges())
	if body.size() < 2 or body[0] != "while true:":
		return ""
	# Compiled once and shared: this runs for every function card the canvas paints.
	if _await_loop_regex == null:
		_await_loop_regex = RegEx.new()
		if _await_loop_regex.compile("^await get_tree\\(\\)\\.create_timer\\((.+)\\)\\.timeout$") != OK:
			return ""
	var await_match: RegExMatch = _await_loop_regex.search(body[1])
	if await_match == null:
		return ""
	return _trimmed_seconds(await_match.get_string(1).strip_edges())


# ── `super` reads as calling the included sheet ─────────────────────────────────────────────────


## The base script path, resolved once per sheet: the answer needs the project's class list, and a
## row asks for it once per `super` line.
var _base_script_path: String = ""
var _base_script_stamp: int = -1


func _cached_base_script_path() -> String:
	var sheet: EventSheetResource = _viewport._sheet
	var stamp: int = 0 if sheet == null else int(sheet.get_instance_id())
	if stamp != _base_script_stamp:
		_base_script_stamp = stamp
		_base_script_path = base_script_path(sheet)
	return _base_script_path


## What a `super` statement SAYS, as {"file", "verb", "args"} - or {} when the action is not one, or
## when the base is an engine class (there is no sheet to name, so the line keeps its own reading).
##
## `super._ready()` inside the On Ready handler says "run its On Ready", so the verb is left blank and
## the trigger's own name is used; `super.take_damage(x)` names the verb; a bare `super()` inside a
## function means the same function of the base.
func super_call_reading(action_resource: Variant, event_row: EventRow) -> Dictionary:
	var base_path: String = _cached_base_script_path()
	if base_path.is_empty():
		return {}
	var code: String = ""
	if action_resource is RawCodeRow:
		code = (action_resource as RawCodeRow).code.strip_edges()
	elif action_resource is ACEAction:
		code = ActionCodegen.generate_action(action_resource as ACEAction).strip_edges()
	if code.is_empty() or code.contains("\n") or not code.begins_with("super"):
		return {}
	# Compiled once and shared: this runs for every action of every row the canvas paints.
	if _super_call_regex == null:
		_super_call_regex = RegEx.new()
		if _super_call_regex.compile("^super(?:\\.([A-Za-z_][A-Za-z0-9_]*))?\\((.*)\\)$") != OK:
			return {}
	var call_match: RegExMatch = _super_call_regex.search(code)
	if call_match == null:
		return {}
	var method: String = call_match.get_string(1)
	var verb: String = ""
	var runs_trigger: String = ""
	if method.is_empty() or method.begins_with("_"):
		# A lifecycle name is the handler this row already sits in, so the row says which of the
		# include's handlers it runs rather than repeating an engine method name.
		runs_trigger = _trigger_display_text(event_row.trigger_provider_id, event_row.trigger_id) \
			if event_row != null and not event_row.trigger_id.is_empty() else ""
		if runs_trigger.is_empty():
			verb = method.capitalize() if not method.is_empty() else ""
	else:
		verb = method.capitalize()
	return {"file": base_path.get_file(), "verb": verb, "runs": runs_trigger, "args": call_match.get_string(2).strip_edges()}


## The action cell for a `super` call: `Include <file> ▸ run its On Ready` / `▸ Call Take Damage x`.
func _append_super_call_spans(spans: Array[SemanticSpan], reading: Dictionary, action_index: int,
		action_line_index: int, action_style_meta: Dictionary) -> void:
	var base_meta: Dictionary = {
		"lane": "action",
		"kind": "action",
		"ace_index": action_index,
		"ace_enabled": true,
		"chip": true,
		"code_cell": false,
		"natural_width": true,
		"line_index": action_line_index
	}
	spans.append(_make_span(EventSheetL10n.translate("Include"), SemanticSpan.SpanType.VALUE,
		base_meta.duplicate().merged({"text_color": _viewport._get_reading_style().muted_text_color}, true).merged(action_style_meta, false)))
	spans.append(_make_span(str(reading.get("file", "")), SemanticSpan.SpanType.KEYWORD,
		base_meta.duplicate().merged({
			"badge": true,
			"badge_style": "scope",
			"badge_bg": _viewport._get_reading_style().plain_chip_background_color,
			"badge_fg": _viewport._get_reading_style().plain_chip_foreground_color
		}, true).merged(action_style_meta, false)))
	var runs: String = str(reading.get("runs", ""))
	var tail: String = ""
	if not runs.is_empty():
		tail = "%s %s" % [EventSheetL10n.translate("▸ run its"), runs]
	else:
		tail = "%s %s" % [EventSheetL10n.translate("▸ Call"), str(reading.get("verb", ""))]
	var args: String = str(reading.get("args", ""))
	if not args.is_empty():
		tail = "%s  %s" % [tail, args]
	spans.append(_make_span(tail, SemanticSpan.SpanType.ACTION, base_meta.duplicate().merged({
		"natural_width": false,
		"text_color": _viewport._get_reading_style().primary_text_color
	}, true).merged(action_style_meta, false)))


# ── commented-out code reads as a switched-off row ──────────────────────────────────────────────


## The code behind an action-lane resource that is really a commented-out statement, "" otherwise.
## Both shapes a comment arrives in are read: the first-class CommentRow the body lift builds, and a
## one-line verbatim block that is nothing but a comment.
static func commented_out_code(action_resource: Variant) -> String:
	if action_resource is CommentRow:
		var note: CommentRow = action_resource as CommentRow
		return CommentRow.code_text(note.text) if note.enabled else ""
	if action_resource is RawCodeRow:
		var lines: PackedStringArray = (action_resource as RawCodeRow).code.split("\n")
		if lines.size() != 1:
			return ""
		var text: String = lines[0].strip_edges()
		if not text.begins_with("#") or text.begins_with("##"):
			return ""
		return CommentRow.code_text(text.trim_prefix("#").trim_prefix(" "))
	return ""


## The action-lane cell for a switched-off row: the sentence the code reads as when a sentence claims
## it, the code itself otherwise, followed by the muted "disabled" note. `ace_enabled` false is what
## draws the strike-through, and the row wash comes from the disabled look the sheet already has.
func _append_disabled_code_spans(spans: Array[SemanticSpan], code: String, action_index: int,
		action_line_index: int, action_style_meta: Dictionary) -> void:
	var disabled_meta: Dictionary = {
		"lane": "action",
		"kind": "action",
		"ace_index": action_index,
		"ace_enabled": false,
		"chip": true,
		"code_cell": false,
		"line_index": action_line_index
	}
	# The note leads the cell rather than trailing it: the sentence cell stretches to close the lane,
	# so a word placed after it is pushed off the edge on a narrow canvas - and the one word that says
	# this row does not run is the one word that must never be the one that gets cut.
	spans.append(_make_span(EventSheetL10n.translate("disabled"), SemanticSpan.SpanType.COMMENT,
		disabled_meta.duplicate().merged({
			"natural_width": true,
			# The NOTE is not the code: striking it through would say the word itself is switched off.
			"ace_enabled": true,
			"text_color": _viewport._get_reading_style().muted_text_color
		}, true).merged(action_style_meta, false)))
	# The stand-in is DISABLED, which is what the sentence builder reads to strike its cell through;
	# nothing is written to the sheet, the row it stands for is still the comment the file holds.
	var stand_in := RawCodeRow.new()
	stand_in.code = code
	stand_in.enabled = false
	if not _append_sentence_spans(spans, stand_in, action_index, action_line_index, action_style_meta):
		spans.append(_make_span(code, SemanticSpan.SpanType.VALUE,
			disabled_meta.duplicate().merged({"text_color": _viewport._get_reading_style().muted_text_color}, true).merged(action_style_meta, false)))


## The header spans of a function that IS an await beat: the repeating badge, the words, and the
## muted note saying the beat only runs while the loop does.
func _await_loop_trigger_spans(seconds: String) -> Array[SemanticSpan]:
	var badge_meta: Dictionary = _viewport.BADGE_TRIGGER_METADATA.duplicate(true)
	badge_meta["tempo"] = TriggerResolver.TEMPO_EVERY_TICK
	badge_meta["badge_bg"] = _viewport._get_reading_style().tempo_every_tick_background_color
	badge_meta["badge_fg"] = _viewport._get_reading_style().tempo_every_tick_foreground_color
	badge_meta["badge_style"] = "trigger"
	badge_meta["kind"] = "raw_code"
	badge_meta["line_index"] = 0
	return [
		_make_span("⟳", SemanticSpan.SpanType.KEYWORD, badge_meta),
		_make_span(EventSheetL10n.translate("System"), SemanticSpan.SpanType.OBJECT, {
			"editable": false,
			"kind": "raw_code",
			"line_index": 0,
			"text_color": _viewport._get_event_style().object_label_color
		}),
		_make_span(EventSheetL10n.translate("Every %s seconds") % seconds, SemanticSpan.SpanType.CONDITION, {
			"editable": false,
			"kind": "raw_code",
			"line_index": 0,
			"text_color": _viewport._get_reading_style().primary_text_color
		}),
		_make_span(EventSheetL10n.translate("(while running)"), SemanticSpan.SpanType.COMMENT, {
			"editable": false,
			"kind": "raw_code",
			"line_index": 0,
			"text_color": _viewport._get_reading_style().muted_text_color
		})
	]


## The lifecycle handlers whose top-level branches read as the input triggers a player would name.
## `_input_event` is one of them: a clickable body branches on the event exactly as the three
## whole-screen handlers do, and the only difference is that the input already landed on the object,
## which is what its branch reading says.
const INPUT_HANDLER_TRIGGERS: Array[String] = [
	"OnInput", "OnUnhandledInput", "OnUnhandledKeyInput", "OnInputEvent", "OnControlInput"
]

## The handlers whose input already landed on THIS object, so their branches say which object
## they landed on rather than reading as a press somewhere on the screen.
const SCOPED_INPUT_HANDLER_TRIGGERS: Array[String] = ["OnInputEvent", "OnControlInput"]


## The object a trigger row belongs to. A signal-backed trigger belongs to the NODE that emits it -
## "Hurtbox > On Body Entered", the way an event sheet names the object before the verb - so a connected
## handler reads as its source node rather than as the generic class the vocabulary filed it under.
## Falls back to the ordinary vocabulary label when the trigger names no source (a self-connection,
## a lifecycle handler).
func _handler_object_label(event_row: EventRow) -> String:
	var source_path: String = event_row.trigger_source_path.strip_edges()
	if not source_path.is_empty() and not source_path.begins_with("@") and not source_path.begins_with("autoload:"):
		return source_path.get_file() if source_path.contains("/") else source_path
	return _object_label_for(event_row.trigger_provider_id, event_row.trigger_id)


## The class picture of the node a SCENE-wired signal comes from. The scene said what class the
## emitter is when the connection was read, so this is a known answer rather than a guess; null for
## every other trigger, which keeps its vocabulary icon.
func _scene_trigger_icon(event_row: EventRow) -> Texture2D:
	if event_row == null or not _viewport.show_object_icons:
		return null
	var source_class: String = str(event_row.get_meta("__scene_source_class", ""))
	if source_class.is_empty():
		return null
	return ACEPickerDialog.editor_icon(source_class)


# ── Signals: who listens, and where it comes from ─────────────────────────────────────────────
# A signal row is half a sentence on its own: an emit says something was announced and stops, a
# handler says something was heard and stops. The other half lives in a different file every time,
# which is a question an event-sheet reader never has to ask, because there the wiring IS the sheet.
# So both halves are drawn as a muted note on the row, derived from ONE project-wide index
# (signal_fanout.gd) built once per session. Display-only: nothing here changes a row or a byte.


## The signal an action RAISES, "" for every other action.
static func emitted_signal_name(action: ACEAction) -> String:
	if action == null or not (action.provider_id.is_empty() or action.provider_id == "Core"):
		return ""
	if action.ace_id != "EmitSignal":
		return ""
	var params_dict: Dictionary = action.params if not action.params.is_empty() else action.parameters
	return str(params_dict.get("signal_name", "")).strip_edges().trim_prefix("\"").trim_suffix("\"")


## The signal a trigger id stands for, "" when the trigger is not signal-backed. Both spellings the
## lifter records resolve: a custom signal keeps its name behind `signal:`, a core one was mapped to
## a published trigger id and is mapped back through the same table.
static func signal_name_of_trigger(trigger_id: String) -> String:
	var declared: String = trigger_id.strip_edges()
	if declared.is_empty():
		return ""
	if declared.begins_with("signal:"):
		return declared.trim_prefix("signal:")
	for signal_name: String in EventSheetACELifter.CORE_SIGNAL_TRIGGERS:
		if str(EventSheetACELifter.CORE_SIGNAL_TRIGGERS[signal_name]) == declared:
			return signal_name
	return ""


## The muted `-> HUD, Level (2 listeners)` an emit wears. Nothing is appended when nothing in
## the project listens, because a note saying "nobody" on every internal signal is noise.
func _append_signal_fanout_span(spans: Array[SemanticSpan], action: ACEAction, action_index: int,
		line_index: int) -> void:
	var signal_name: String = emitted_signal_name(action)
	if signal_name.is_empty():
		return
	var note: String = EventSheetSignalFanout.listeners_note(signal_name)
	if note.is_empty():
		return
	spans.append(_make_span(note, SemanticSpan.SpanType.COMMENT,
		_fanout_metadata("action", action_index, line_index, signal_name, true)))


## THE GUARD, ON THE ROW. A removal row whose object may already be gone compiles inside
## `if is_instance_valid(<it>):`, and this is the span that says so: the exact line the file holds,
## echoed at the end of the row's own line in the script editor's token colours, exactly as a
## declaration row echoes its `var`. Nothing is hidden and nothing is paraphrased - a reader who
## does not want the guard can see it, and can see which name asked for it.
##
## The rule is the compiler's own (EventForgeRemovalGuard), asked here rather than re-derived, so
## the row can never claim a guard the file does not contain or miss one it does. Same line_index as
## the sentence, so the row does not grow a line and the lazy height measure stays exact.
func _append_removal_guard_span(spans: Array[SemanticSpan], action: ACEAction, event_row: EventRow,
		action_index: int, line_index: int) -> void:
	if action == null or not EventForgeRemovalGuard.GUARDED_ACE_IDS.has(action.ace_id):
		return
	if _removal_guard_facts.is_empty():
		_removal_guard_facts = EventForgeRemovalGuard.facts(_viewport._sheet)
	var guarded: String = EventForgeRemovalGuard.guard_expression(action, event_row, _removal_guard_facts)
	if guarded.is_empty():
		return
	spans.append(_code_echo_span(
		EventForgeRemovalGuard.guard_line(guarded),
		{
			"lane": "action",
			"kind": "action",
			"ace_index": action_index,
			"line_index": line_index,
			"natural_width": true,
			"hover_note": EventSheetL10n.translate("This name may already be gone, so the compiler writes this line above the row. Click to open it in the code panel.")
		},
		EventSheetCodeEcho.REST_ALPHA,
		true
	))


## The muted `<- emitted in player.gd: Take Damage` a handler wears.
func _append_signal_source_span(spans: Array[SemanticSpan], event_row: EventRow, line_index: int) -> void:
	if event_row == null:
		return
	var signal_name: String = signal_name_of_trigger(event_row.trigger_id)
	if signal_name.is_empty():
		return
	var note: String = EventSheetSignalFanout.raised_note(signal_name)
	if note.is_empty():
		return
	spans.append(_make_span(note, SemanticSpan.SpanType.COMMENT,
		_fanout_metadata("condition", 0, line_index, signal_name, false)))


## The metadata a fan-out note carries. `include_path` is what makes the note CLICK-TO-JUMP: the
## canvas already opens a span carrying one as a sheet, so the note reuses that seam rather than
## inventing a second way to travel.
func _fanout_metadata(lane: String, ace_index: int, line_index: int, signal_name: String,
		from_emit: bool) -> Dictionary:
	var target: Dictionary = EventSheetSignalFanout.jump_target(signal_name, from_emit)
	# Only a SCRIPT can be opened as a sheet - a connection recovered from a .tscn has nowhere for a
	# click to land, so that note stays a note.
	if str(target.get("path", "")).get_extension().to_lower() != "gd":
		target = {}
	return {
		"lane": lane,
		"kind": "include_open" if not target.is_empty() else "signal_fanout",
		"ace_index": ace_index,
		"line_index": line_index,
		"editable": false,
		"signal_name": signal_name,
		"include_path": str(target.get("path", "")),
		"text_color": _viewport._get_reading_style().muted_text_color
	}


## The payload chips for a signal-backed trigger: one per handler parameter, named the way the
## handler names it ("body: Node2D" -> "body"). Empty for every trigger that hands nothing over.
func _handler_payload_chips(event_row: EventRow) -> PackedStringArray:
	var chips: PackedStringArray = PackedStringArray()
	var args: String = event_row.trigger_args.strip_edges()
	if event_row.trigger_id.is_empty():
		return chips
	if args.is_empty():
		# A PICKED trigger records no argument list - only a lifted handler does. Its payload is
		# still knowable, because the resolver already says what signature the handler is emitted
		# with, so a row picked from the list shows the same chips a lifted one does instead of
		# leaving the reader to open the code. Signal-backed triggers only: a lifecycle argument
		# like `delta` is the engine talking to the function, not news the event hands anybody.
		var signature: Dictionary = TriggerResolver.resolve_trigger(event_row)
		if str(signature.get("signal_name", "")).is_empty():
			return chips
		args = str(signature.get("args", "")).strip_edges()
		if args.is_empty():
			return chips
	for argument: String in args.split(","):
		var name_part: String = argument.strip_edges().split(":")[0].split("=")[0].strip_edges()
		if not name_part.is_empty():
			chips.append(name_part.replace("_", " "))
	return _with_bound_values(event_row, chips)


## The payload chips with any BOUND VALUES written into them: `pressed.connect(_open.bind(3))` hands
## the handler a 3 that the signal never carried, and the row reads `slot = 3` rather than a bare
## `slot` a reader then has to go and look up.
##
## Godot appends bound values to the END of the handler's arguments, so the LAST ones are the bound
## ones - which is what makes this a pairing rather than a guess. The values are read off the connect
## line the lift kept verbatim, the same place the one-shot flag is read from: nothing extra is stored
## on the row, and nothing here can move a byte of what the file emits.
##
## A bind with more values than the handler declares is left alone. That handler does not run, and a
## row inventing chips for it would be saying the wiring is fine when it is not.
func _with_bound_values(event_row: EventRow, chips: PackedStringArray) -> PackedStringArray:
	var connect_line: String = str(event_row.get_meta("__source_connect_line", ""))
	if connect_line.is_empty() or not connect_line.contains(".bind("):
		return chips
	var values: PackedStringArray = EventSheetACELifter.bound_arguments(connect_line)
	if values.is_empty() or values.size() > chips.size():
		return chips
	var first: int = chips.size() - values.size()
	for index: int in range(values.size()):
		chips[first + index] = "%s = %s" % [chips[first + index], values[index]]
	return chips


## Builtin categories that are OBJECTS in the event-sheet grammar, not part of System - a row of theirs
## wears the device name in its object cell (Mouse, Keyboard, Gamepad, Touch).
## Adds Multiplayer to this list for the same reason: Godot's high-level networking is a thing a
## sheet TALKS TO - it sends it messages, it asks it who the host is - so its rows wear its name.
const INPUT_DEVICE_OBJECTS: Array[String] = ["Mouse", "Keyboard", "Gamepad", "Touch", "Multiplayer"]

## The editor is an object too - it is opened, it is drawn on, it is given docks and menu items,
## and it answers questions about what is selected. Its whole vocabulary is filed under one category,
## so a row of that category wears "Editor" in its object cell exactly as a Mouse row wears "Mouse".
const EDITOR_TOOLS_CATEGORY := "Editor Tools"
const EDITOR_OBJECT := "Editor"

## The Editor object's vocabulary now sits on PAGES ("Editor Tools: Panels & menus" and the
## rest), which the picker nests one level in. A page is still the Editor, so the object cell tests
## the prefix rather than the whole string.
const EDITOR_TOOLS_PAGE_PREFIX := "Editor Tools: "

## One page of the Editor's vocabulary is NOT the editor: a command tool is a program the
## Godot binary runs from the command line, with no editor open at all. Its rows therefore wear the
## same object a hand-written tools/*.gd already reads under - "Command tool ▸ Finish with code 1" -
## so a picked row and a typed line say one sentence. Keyed off the PAGE rather than a list of ace
## ids, because every row of that page is the command tool's and none of them is the editor's.
const COMMAND_TOOL_PAGE := "Editor Tools: Command tool"

## Another page of the Editor's vocabulary that is not the editor: the rows that build a MENU and
## answer the item that was chosen. A hand-written menu already reads under its own object ("Sheet
## menu ▸ On Save chosen"), so a picked row wears the same word rather than the Editor's, and a
## picked menu and a typed one say one sentence.
const MENU_PAGE := "Editor Tools: Menus"

## Two rows in the Editor's pages are not about the editor at all - they read and write THIS
## PROJECT's settings, which every person opening the project shares. An event sheet says that as its
## own object, so a reader can tell "your editor" from "this project" at a glance.
const PROJECT_OBJECT := "Project"
const PROJECT_ACE_IDS: PackedStringArray = ["SetProjectSetting", "SaveProjectSettings"]

## The window is an object too - it is resized, retitled, made fullscreen, and asked whether it
## is. An OVERRIDE list rather than the whole Game Window category, because that category also holds
## the frame cap and the render settings, which an event sheet says as System (the reading says the
## same: `Engine.max_fps` is a System row, `get_window().size` is a Window one). Every id here is one
## whose typed line the sentence grammar puts on the Window object, so a picked row and a
## hand-written line wear the same object label.
const WINDOW_OBJECT := "Window"
const WINDOW_ACE_IDS: PackedStringArray = [
	"WindowGoFullscreen", "WindowGoWindowed", "WindowGoExclusive", "WindowToggleFullscreen",
	"WindowSetSize", "WindowSetPosition", "WindowCenter", "WindowSetVSync",
	"WindowSetAlwaysOnTop", "WindowMinimize", "WindowMaximize", "WindowIsFullscreen",
	"SetWindowTitle"
]

## `event is <class>` -> the event-sheet module that owns the trigger the branch reads as.
const INPUT_EVENT_MODULES: Dictionary = {
	"InputEventMouseMotion": "Mouse",
	"InputEventMouseButton": "Mouse",
	"InputEventKey": "Keyboard",
	"InputEventScreenTouch": "Touch",
	"InputEventJoypadButton": "Gamepad",
}


## What an input handler's branch SAYS, as {"module", "sentence", "consumed"}, or {} when the branch
## is not one of the shapes below (which keeps today's reading, never a guessed one).
##
## An `_input` / `_unhandled_input` / `_unhandled_key_input` body branches on the event's TYPE, and
## that branch is exactly one event-sheet trigger: `event is InputEventMouseMotion` is Mouse > On
## mouse moved, `event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE` is
## Keyboard > On Escape pressed. Display only - the file still holds one handler with an if/elif chain.
##
## The reading matches ATOMS, not lines, which is what makes the two spellings of the same branch
## converge: a sheet-authored Keyboard trigger compiles to ONE parenthesized conjunction, while a
## hand-written handler splits the same test across separate conjuncts and casts each one
## (`(event as InputEventKey).pressed`). Both flatten to the same atom set here, so a sheet saved
## and reopened reads identically to the handler someone typed by hand.
func _input_branch_reading(event_row: EventRow) -> Dictionary:
	if event_row == null or not INPUT_HANDLER_TRIGGERS.has(event_row.trigger_id) or event_row.conditions.is_empty():
		return {}
	var atoms: Array = []
	var atom_counts: Dictionary = {}
	for condition_index in range(event_row.conditions.size()):
		var condition: ACECondition = event_row.conditions[condition_index]
		if condition == null:
			continue
		var pieces: PackedStringArray = _split_top_level_and(_strip_event_casts(SheetCompiler.condition_source_text(condition)))
		atom_counts[condition_index] = pieces.size()
		for piece: String in pieces:
			atoms.append({"text": piece, "index": condition_index, "used": false})
	var event_class: String = ""
	for atom: Dictionary in atoms:
		var tested: String = str(atom["text"]).trim_prefix("event is ")
		if tested != str(atom["text"]) and INPUT_EVENT_MODULES.has(tested):
			event_class = tested
			atom["used"] = true
			break
	if event_class.is_empty():
		return {}
	# 1 = the press edge, -1 = the release edge, 0 = the branch never said (so most shapes below
	# decline rather than guess which edge the reader is looking at).
	var edge: int = 0
	var button: String = ""
	var key: String = ""
	var device: String = ""
	for atom: Dictionary in atoms:
		if bool(atom["used"]):
			continue
		var text: String = str(atom["text"])
		if text == "event.pressed":
			edge = 1
		elif text == "not event.pressed":
			edge = -1
		elif text == "not event.echo" or text == "event.echo":
			pass  # the auto-repeat guard is plumbing, not part of the sentence
		elif text.begins_with("event.button_index == "):
			button = text.trim_prefix("event.button_index == ")
		elif text.begins_with("event.keycode == "):
			key = text.trim_prefix("event.keycode == ")
		elif text.begins_with("event.physical_keycode == "):
			key = text.trim_prefix("event.physical_keycode == ")
		elif text.begins_with("event.device == ") and event_class == "InputEventJoypadButton":
			# The device index IS the gamepad number, exactly as the Gamepad object counts them from 0.
			# Only on a gamepad branch: a keyboard has no number in the sheet, so `event.device == 1`
			# there stays the comparison it is rather than borrowing a word that means nothing.
			device = text.trim_prefix("event.device == ")
		else:
			continue
		atom["used"] = true
	var sentence: String = ""
	# A Control's own handler names the BUTTON, not the object: the object is said once, in the
	# scope that follows, and a canvas that answers three buttons would otherwise read as three
	# identical "On Viewport clicked" triggers.
	if event_row.trigger_id == "OnControlInput" and event_class == "InputEventMouseButton" \
			and edge > 0 and not button.is_empty() and not button.begins_with("MOUSE_BUTTON_WHEEL_"):
		sentence = EventSheetL10n.translate("On %s button clicked") % _mouse_button_word(button)
	else:
		sentence = _input_branch_sentence(event_class, edge, button, key, device,
			event_row.trigger_id == "OnInputEvent")
	if sentence.is_empty():
		return {}
	if SCOPED_INPUT_HANDLER_TRIGGERS.has(event_row.trigger_id) and event_row.trigger_id != "OnInputEvent":
		var scope_object: String = _script_object_name()
		if not scope_object.is_empty():
			sentence += " " + (EventSheetL10n.translate("(on %s)") % scope_object)
	# A condition drops off the lane only when the sentence absorbed ALL of its conjuncts; one that
	# carried an extra test (a captured-cursor check, a game-state guard) still reads on its own row.
	var used_per_condition: Dictionary = {}
	for atom: Dictionary in atoms:
		if bool(atom["used"]):
			used_per_condition[int(atom["index"])] = int(used_per_condition.get(atom["index"], 0)) + 1
	var consumed: Dictionary = {}
	for condition_index: Variant in used_per_condition.keys():
		if int(used_per_condition[condition_index]) == int(atom_counts.get(condition_index, -1)):
			consumed[int(condition_index)] = true
	return {"module": str(INPUT_EVENT_MODULES[event_class]), "sentence": sentence, "consumed": consumed}


## The one-line trigger sentence for a recognized branch ("" = not a shape we name).
func _input_branch_sentence(event_class: String, edge: int, button: String, key: String,
		device: String = "", on_this_object: bool = false) -> String:
	# The input already landed on this body, so a pressed-button branch of `_input_event` is
	# the sheet's own "On <object> clicked" rather than a bare button press somewhere on the screen.
	if on_this_object and event_class == "InputEventMouseButton" and edge > 0 \
			and not button.begins_with("MOUSE_BUTTON_WHEEL_"):
		var clicked_object: String = _script_object_name()
		if not clicked_object.is_empty():
			return EventSheetL10n.translate("On %s clicked") % clicked_object
	match event_class:
		"InputEventMouseMotion":
			return EventSheetL10n.translate("On mouse moved")
		"InputEventMouseButton":
			if button == "MOUSE_BUTTON_WHEEL_UP":
				return EventSheetL10n.translate("On mouse wheel up")
			if button == "MOUSE_BUTTON_WHEEL_DOWN":
				return EventSheetL10n.translate("On mouse wheel down")
			if edge == 0 or button.is_empty():
				return ""
			return EventSheetL10n.translate("On %s button pressed" if edge > 0 else "On %s button released") % _mouse_button_word(button)
		"InputEventKey":
			if edge == 0 or key.is_empty():
				return ""
			return EventSheetL10n.translate("On %s pressed" if edge > 0 else "On %s released") % _key_word(key)
		"InputEventScreenTouch":
			if edge == 0:
				return ""
			return EventSheetL10n.translate("On touch started" if edge > 0 else "On touch ended")
		"InputEventJoypadButton":
			if edge == 0 or button.is_empty():
				return ""
			var button_word: String = button.trim_prefix("JOY_BUTTON_").capitalize()
			# A branch that named a device says which gamepad, in the Gamepad object's own words.
			if not device.is_empty():
				return EventSheetL10n.translate(
					"On gamepad %s button %s pressed" if edge > 0 else "On gamepad %s button %s released"
				) % [device, button_word]
			return EventSheetL10n.translate("On button %s pressed" if edge > 0 else "On button %s released") % button_word
	return ""


## "MOUSE_BUTTON_LEFT" -> "left" (the word an event sheet puts in the sentence).
func _mouse_button_word(button: String) -> String:
	return button.trim_prefix("MOUSE_BUTTON_").to_lower().replace("_", " ")


## "KEY_ESCAPE" -> "Escape". A bare expression (a variable holding a keycode) reads verbatim.
func _key_word(key: String) -> String:
	if not key.begins_with("KEY_"):
		return key
	return key.trim_prefix("KEY_").capitalize()


## The event-sheet words for the pieces of an input event a row reads out: the mouse delta is
## `mouse's ΔX` / `ΔY`, and the static-typing casts around `event` are not part of any sentence.
## Applied to every row's text - `event.relative` and an `as InputEvent…` cast only ever appear
## inside an input handler, so there is nothing else for it to touch.
func _humanized_input_event_text(text: String) -> String:
	if not text.contains("event"):
		return text
	var humanized: String = _strip_event_casts(text)
	# Where the pointer was when the event arrived is the Mouse object's own expression - the
	# same value a picked row would print, so a typed handler and a dropped one read alike.
	humanized = humanized.replace("event.global_position", EventSheetL10n.translate("Mouse.Position"))
	humanized = humanized.replace("event.position", EventSheetL10n.translate("Mouse.Position"))
	humanized = humanized.replace("event.relative.x", EventSheetL10n.translate("mouse's ΔX"))
	humanized = humanized.replace("event.relative.y", EventSheetL10n.translate("mouse's ΔY"))
	return humanized.replace("event.relative", EventSheetL10n.translate("mouse's Δ"))


## `(event as InputEventKey).pressed` -> `event.pressed`. A cast is how GDScript keeps its static
## type checker happy; it says nothing a reader needs, so it never reaches a sentence.
func _strip_event_casts(text: String) -> String:
	if _event_cast_regex == null:
		_event_cast_regex = RegEx.create_from_string("\\(\\s*([A-Za-z_][A-Za-z0-9_]*)\\s+as\\s+InputEvent[A-Za-z]*\\s*\\)")
	return _event_cast_regex.sub(text, "$1", true)


## A boolean expression split on its TOP-LEVEL ` and ` conjuncts (outer parentheses peeled first),
## so one parenthesized condition and a run of separate ones flatten to the same list.
func _split_top_level_and(expression: String) -> PackedStringArray:
	var text: String = expression.strip_edges()
	while text.begins_with("(") and text.ends_with(")") and _wraps_whole_expression(text):
		text = text.substr(1, text.length() - 2).strip_edges()
	var pieces: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var quote: String = ""
	var start: int = 0
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote:
				quote = ""
			index += 1
			continue
		if character == "\"" or character == "'":
			quote = character
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		elif depth == 0 and text.substr(index, 5) == " and ":
			pieces.append(text.substr(start, index - start).strip_edges())
			index += 5
			start = index
			continue
		index += 1
	pieces.append(text.substr(start).strip_edges())
	var trimmed: PackedStringArray = PackedStringArray()
	for piece: String in pieces:
		var inner: String = piece
		while inner.begins_with("(") and inner.ends_with(")") and _wraps_whole_expression(inner):
			inner = inner.substr(1, inner.length() - 2).strip_edges()
		trimmed.append(inner)
	return trimmed


## True when the text's leading "(" is the one its trailing ")" closes - so peeling them keeps the
## expression whole (`(a) and (b)` is left alone, `(a and b)` is unwrapped).
func _wraps_whole_expression(text: String) -> bool:
	var depth: int = 0
	for index in range(text.length()):
		if text[index] == "(":
			depth += 1
		elif text[index] == ")":
			depth -= 1
			if depth == 0:
				return index == text.length() - 1
	return false


## `slice_from` / `slice_to` (half-open, -1 = to the end) and `hide_conditions` exist for the paired statement rows: a
## statement carrying a ternary splits its event into a row of the actions before it, the branch rows,
## and a continuation row - three views of ONE unchanged EventRow, each drawing its own slice.
## True when this row is one of the sheet's OWN events rather than a sub-event of another. A
## blank row means "runs every tick" only up here; under a parent, blank means "then, in order".
## `rows` is null on the outer call and the group's own list on a nested one - never an "empty means
## start over" default, which on a sheet holding an EMPTY group would recurse forever.
func _is_top_level_event(event_row: EventRow, rows: Variant = null) -> bool:
	var search: Array = []
	if rows is Array:
		search = rows as Array
	else:
		var sheet: EventSheetResource = _viewport._sheet
		if sheet == null or event_row == null:
			return false
		search = sheet.events
	for entry: Variant in search:
		if entry == event_row:
			return true
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			var members: Array = group.events if not group.events.is_empty() else group.rows
			if _is_top_level_event(event_row, members):
				return true
	return false


## What a top-level event whose tick carries no condition of its own says in the condition lane -
## {} when the row keeps its own trigger words, else {"note": String} ("" = say nothing at all). Also
## the one place the blank-event pattern is claimed, so the chip, the hover and the Doctor all read
## the same fact rather than each re-deriving it.
func _blank_tick_reading(event_row: EventRow) -> Dictionary:
	if event_row == null or not event_row.conditions.is_empty():
		return {}
	if event_row.else_mode != EventRow.ElseMode.NONE:
		return {}
	if event_row.trigger != null or not event_row.pick_filters.is_empty():
		return {}
	if not event_row.with_node_target.strip_edges().is_empty():
		return {}
	var reading: Dictionary = EventSheetViewportReadingRows.blank_tick_reading(
		event_row.trigger_id, false, _patterns_reading_on())
	if reading.is_empty():
		return {}
	if not _is_top_level_event(event_row):
		return {}
	var header: String = str(event_row.get_meta("__source_trigger_header", ""))
	if header.is_empty():
		var signature: Dictionary = TriggerResolver.resolve_trigger(event_row)
		header = "func %s(%s) -> %s:" % [
			str(signature.get("function_name", "_process")), str(signature.get("args", "")),
			str(signature.get("return_type", "void"))]
	EventSheetPatternFacts.claim(_viewport._sheet, "blank_event", event_row.event_uid,
		event_row.event_uid, PackedStringArray([header]),
		EventSheetL10n.translate(EventSheetViewportReadingRows.BLANK_EVENT_HOVER))
	return reading


## True when the sheet holds this event UNDER another one - which is what makes blank mean
## "follows its parent" rather than "every tick". Walks the sheet's own events and its functions'
## bodies, so a sub-event of a function reads the same as one on the canvas.
func _is_sub_event(event_row: EventRow, container: Variant = null, depth: int = 0) -> bool:
	if event_row == null or depth > 64:
		return false
	var search: Array = []
	if container is Array:
		search = container as Array
	else:
		var sheet: EventSheetResource = _viewport._sheet
		if sheet == null:
			return false
		search = sheet.events.duplicate()
		for entry: Variant in sheet.functions:
			if entry is EventFunction:
				search.append_array((entry as EventFunction).events)
	for entry: Variant in search:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			var members: Array = group.events if not group.events.is_empty() else group.rows
			if _is_sub_event(event_row, members, depth + 1):
				return true
			continue
		if not (entry is EventRow):
			continue
		var parent: EventRow = entry as EventRow
		for child: Variant in parent.sub_events:
			if child == event_row:
				return true
		if _is_sub_event(event_row, parent.sub_events, depth + 1):
			return true
	return false


## True when an event is a blank SUB-event - no condition, no trigger, no Else, under a parent.
## An event sheet's own rule for that shape is "follows its parent, in order", which is exactly what
## the compiler already emits (plain statements after the parent's block, no `if` at all), so the
## reading owes it an EMPTY condition lane rather than the "Every Tick" placeholder a top-level event
## earns. Claims the blank_event pattern on the row for the same reason the top-level reading does:
## the chip and the Explain panel both need to say which of the two blank rules this row is.
func _blank_sub_event(event_row: EventRow) -> bool:
	if event_row == null or not event_row.conditions.is_empty():
		return false
	if event_row.else_mode != EventRow.ElseMode.NONE:
		return false
	if event_row.trigger != null or not event_row.trigger_id.strip_edges().is_empty():
		return false
	if not event_row.pick_filters.is_empty() or not event_row.with_node_target.strip_edges().is_empty():
		return false
	# Under a parent IN THIS SHEET, and nowhere else: a row built outside a sheet (a preview, a test,
	# a figure) is not a sub-event of anything, and reading it as one would take the placeholder away
	# from the one row that still earns it.
	if _viewport == null or not _is_sub_event(event_row):
		return false
	EventSheetPatternFacts.claim(_viewport._sheet, "blank_event", event_row.event_uid,
		event_row.event_uid, PackedStringArray(),
		EventSheetL10n.translate(EventSheetViewportReadingRows.BLANK_SUB_EVENT_HOVER))
	return true


## The Patterns reading toggle: with it off, the tick triggers keep their explicit Every tick
## words. Defaults to on when the dock has not published a preference (tests, figure renders).
func _patterns_reading_on() -> bool:
	var dock: Variant = _viewport.get("_dock") if _viewport != null else null
	if dock == null or not (dock as Object).has_method("is_patterns_reading_on"):
		return true
	return bool((dock as Object).call("is_patterns_reading_on"))


func _build_event_spans(event_row: EventRow, in_verb_body: bool = false, slice_from: int = 0,
		slice_to: int = -1, hide_conditions: bool = false, slice_is_tail: bool = false) -> Array[SemanticSpan]:
	var spans: Array[SemanticSpan] = []
	if slice_from > 0 or slice_to >= 0 or hide_conditions:
		return _slice_event_spans(_build_event_spans(event_row, in_verb_body), event_row,
			slice_from, slice_to, hide_conditions, slice_is_tail)
	# Collected while the condition lines are built and read off by whoever owns the row (the
	# divider is drawn between two lines, so it belongs to the ROW, not to a span on either line).
	_pending_or_lines = PackedInt32Array()
	var condition_line_index: int = 0
	var action_line_index: int = 0
	var inline_trigger_condition_index: int = _find_inline_trigger_condition_index(event_row)
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var condition_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	var action_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_action_style())
	# An input handler's branch reads as the trigger it is - one event-sheet trigger row per branch,
	# in place of both the Else chip (a branch is its own trigger, not a continuation) and the
	# generic "On unhandled input event" cell. Pure lens; the emitted handler is untouched.
	var input_reading: Dictionary = _input_branch_reading(event_row)
	var input_consumed: Dictionary = input_reading.get("consumed", {})
	# An event that asks which state the object is in is a state machine's tick; it says so in
	# the pattern registry, which is where the chip, its hover and Adopt behavior read it.
	_claim_state_machine_pattern(event_row)
	if not input_reading.is_empty():
		var input_badge_meta: Dictionary = _viewport.BADGE_TRIGGER_METADATA.duplicate(true)
		var input_glyph: String = _apply_trigger_tempo(input_badge_meta, event_style, event_row.trigger_id)
		input_badge_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)
		input_badge_meta["line_index"] = condition_line_index
		input_badge_meta["badge_style"] = "trigger"
		spans.append(_make_span(input_glyph, SemanticSpan.SpanType.KEYWORD, input_badge_meta))
		spans.append(
			_make_span(
				str(input_reading.get("sentence", "")),
				SemanticSpan.SpanType.CONDITION,
				{
					"lane": "condition",
					"kind": "trigger",
					"ace_index": 0,
					"chip": true,
					"hoverable": false,
					"line_index": condition_line_index,
					"object_label": str(input_reading.get("module", ""))
				}.merged(condition_style_meta, true)
			)
		)
		condition_line_index += 1
	if input_reading.is_empty() and event_row.else_mode != EventRow.ElseMode.NONE:
		# The event-sheet Else reads as a CONDITION, exactly like the System Else does: a "System | Else"
		# chip heading the condition lane (an ELIF is the Else chip with its own conditions beneath). The
		# row's trigger stays structural (it is what chains the block into the same handler) but is NOT
		# re-drawn - an Else block never repeats its trigger. Canvas-drawn, so translated at build time.
		var else_text: String = EventSheetL10n.translate("Else" if event_row.else_mode == EventRow.ElseMode.ELSE else "Else If")
		spans.append(
			_make_span(
				else_text,
				SemanticSpan.SpanType.CONDITION,
				{
					"lane": "condition",
					"kind": "else_keyword",
					"chip": true,
					"hoverable": false,
					"line_index": condition_line_index,
					"object_label": _object_label_for("Core", "")
				}.merged(condition_style_meta, true)
			)
		)
		# And what it is the else OF. An Else three sub-events below its `if` is the classic
		# reading mistake, so the row names the event its chain starts at. Filled in AFTER the
		# viewport numbers the rows (apply_else_follows_labels), because that number does not exist
		# yet; a row whose head is folded away keeps the blank and says nothing.
		if event_row.else_mode == EventRow.ElseMode.ELSE:
			spans.append(
				_make_span(
					"",
					SemanticSpan.SpanType.COMMENT,
					{
						"lane": "condition",
						"kind": "else_follows",
						"else_follows": true,
						"hoverable": false,
						"natural_width": true,
						"line_index": condition_line_index
					}.merged(condition_style_meta, true)
				)
			)
		condition_line_index += 1
	if input_reading.is_empty() and event_row.else_mode == EventRow.ElseMode.NONE and event_row.trigger != null:
		var trigger_badge_meta: Dictionary = _viewport.BADGE_TRIGGER_METADATA.duplicate(true)
		# Tempo badge: the glyph + hue say HOW OFTEN this event runs, from trigger_id.
		var trigger_glyph: String = _apply_trigger_tempo(trigger_badge_meta, event_style, event_row.trigger_id)
		trigger_badge_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)
		trigger_badge_meta["line_index"] = condition_line_index
		trigger_badge_meta["badge_style"] = "trigger"
		spans.append(_make_span(trigger_glyph, SemanticSpan.SpanType.KEYWORD, trigger_badge_meta))
		spans.append(
			_make_span(
				_format_condition_descriptor(event_row.trigger),
				SemanticSpan.SpanType.CONDITION,
				{
					"lane": "condition",
					"kind": "trigger",
					"ace_index": 0,
					"ace_enabled": event_row.trigger.enabled,
					"chip": true,
					"line_index": condition_line_index,
					"object_label": _object_label_for(event_row.trigger.provider_id, event_row.trigger.ace_id),
					"object_icon": _object_icon_for(event_row.trigger.provider_id, event_row.trigger.ace_id)
				}.merged(condition_style_meta, true)
			)
		)
		condition_line_index += 1
	elif input_reading.is_empty() and event_row.else_mode == EventRow.ElseMode.NONE and is_input_trigger_tick(event_row):
		# ────────────────────────────────────────────────────────────────────────────────────────
		# A just-pressed / just-released poll at the top of a tick handler IS a trigger, and an event
		# sheet draws it as one - never as a check under Every tick. The tick words go away because
		# the condition below already says when the event runs; the badge stays, wearing the input
		# tempo, so the row still reads as the trigger it is. Nothing is added or removed here: this
		# is the SAME event row with one span fewer, so the file cannot move.
		var poll_badge_meta: Dictionary = _viewport.BADGE_TRIGGER_METADATA.duplicate(true)
		poll_badge_meta["tempo"] = TriggerResolver.TEMPO_INPUT
		poll_badge_meta["badge_bg"] = _viewport._get_reading_style().tempo_input_background_color
		poll_badge_meta["badge_fg"] = _viewport._get_reading_style().tempo_input_foreground_color
		poll_badge_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)
		poll_badge_meta["line_index"] = condition_line_index
		poll_badge_meta["badge_style"] = "trigger"
		spans.append(_make_span("⌨", SemanticSpan.SpanType.KEYWORD, poll_badge_meta))
	elif input_reading.is_empty() and event_row.else_mode == EventRow.ElseMode.NONE \
			and not _blank_tick_reading(event_row).is_empty():
		# ────────────────────────────────────────────────────────────────────────────────────────
		# A blank event at the top of a sheet runs every tick - that is what blank MEANS here, so an
		# every-frame handler with no condition of its own says nothing in the condition lane and the
		# empty lane is the reading (the hover and Explain say it in words). The physics tick keeps
		# one muted note, because blank alone cannot say WHICH tick. Display only: the row still
		# carries its trigger id and still compiles to exactly the handler it came from.
		var blank_note: String = str(_blank_tick_reading(event_row).get("note", ""))
		if not blank_note.is_empty():
			spans.append(_make_span(blank_note, SemanticSpan.SpanType.COMMENT, {
				"lane": "condition",
				"kind": "trigger",
				"ace_index": 0,
				"editable": false,
				"hoverable": false,
				"line_index": condition_line_index
			}.merged(condition_style_meta, true)))
		# Blank hides the tick words, never a fact a reader has to know: a per-frame event on a
		# tool sheet ALSO runs while the scene is being edited, so that chip survives the blank
		# reading and keeps its place on the line.
		if _ticks_in_the_editor(event_row):
			spans.append(_trigger_payload_span(
				EventSheetL10n.translate("in the editor too"), 0, condition_line_index))
		if not spans.is_empty():
			condition_line_index += 1
	elif input_reading.is_empty() and event_row.else_mode == EventRow.ElseMode.NONE and not event_row.trigger_id.is_empty():
		var trigger_id_badge_meta: Dictionary = _viewport.BADGE_TRIGGER_METADATA.duplicate(true)
		# Same tempo badge on the lifted / lifecycle path (trigger_id with no authored ACECondition) -
		# this is where On Physics Process etc. render, so the ⟳ hot-path glyph lands here too.
		var trigger_id_glyph: String = _apply_trigger_tempo(trigger_id_badge_meta, event_style, event_row.trigger_id)
		# A repeating Timer's handler runs on a beat, so it wears the repeating tempo rather than
		# the one-off signal arrow, and says the beat in the sheet's own words below.
		var timer_reading: Dictionary = _repeating_timer_reading(event_row)
		if not timer_reading.is_empty():
			trigger_id_glyph = "⟳"
			trigger_id_badge_meta["tempo"] = TriggerResolver.TEMPO_EVERY_TICK
			trigger_id_badge_meta["badge_bg"] = _viewport._get_reading_style().tempo_every_tick_background_color
			trigger_id_badge_meta["badge_fg"] = _viewport._get_reading_style().tempo_every_tick_foreground_color
		trigger_id_badge_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)
		trigger_id_badge_meta["line_index"] = condition_line_index
		trigger_id_badge_meta["badge_style"] = "trigger"
		spans.append(_make_span(trigger_id_glyph, SemanticSpan.SpanType.KEYWORD, trigger_id_badge_meta))
		var trigger_words: String = EventSheetViewportReadingRows.tick_trigger_words(
			event_row.trigger_id,
			_trigger_sentence(event_row)
		)
		var trigger_object: String = _handler_object_label(event_row)
		# ── lens hook ──────────────────────────────────────────────────────────────────────────
		# The lifecycle triggers in the sheet's own words, always on: the layout starting or an object
		# being created, the layout ending or an object being destroyed, a draw, and the notifications.
		var lifecycle_reading: Dictionary = EventSheetViewportReadingRows.lifecycle_trigger_reading(
			event_row.trigger_id, trigger_object,
			bool(sentence_context().get("scene_root", false)), _script_object_name())
		if not lifecycle_reading.is_empty():
			trigger_words = str(lifecycle_reading.get("text", trigger_words))
			trigger_object = str(lifecycle_reading.get("object", trigger_object))
		# ── lens hook ──────────────────────────────────────────────────────────────────────────
		# The cursor arriving at an object, and a gamepad being plugged in, are the Mouse's and the
		# Gamepad's news - not the news of whichever node Godot happens to file the signal under. The
		# object the cursor is over is the wired source when there is one, else the script's own.
		var cursor_object: String = trigger_object
		if event_row.trigger_source_path.strip_edges().is_empty() and not _script_object_name().is_empty():
			cursor_object = _script_object_name()
		var device_note: String = ""
		var device_reading: Dictionary = EventSheetViewportReadingRows.input_signal_trigger_reading(
			event_row.trigger_id, cursor_object)
		if not device_reading.is_empty():
			trigger_words = str(device_reading.get("text", trigger_words))
			trigger_object = str(device_reading.get("object", trigger_object))
			device_note = str(device_reading.get("note", ""))
		if not timer_reading.is_empty():
			# ONE cell, not a cell plus a note: a second span in the condition lane takes the object
			# cell for itself and leaves the row's object unsaid. The Timer's name is the receipt for
			# the beat, so it rides in the same words, in brackets.
			trigger_words = "%s (%s)" % [
				EventSheetL10n.translate("Every %s seconds") % str(timer_reading.get("seconds", "")),
				str(timer_reading.get("timer", ""))
			]
			# The beat belongs to System - it is a clock, not a node's own signal.
			trigger_object = EventSheetL10n.translate("System")
		spans.append(
			_make_span(
				# ── lens hook (tick triggers) ──────────────────────────────────────────────────
				# The event-sheet words for the two ticks; every other trigger keeps its own name.
				trigger_words,
				SemanticSpan.SpanType.CONDITION,
				{
					"lane": "condition",
					"kind": "trigger",
					"ace_index": 0,
					"chip": true,
					"line_index": condition_line_index,
					"object_label": trigger_object,
					# A handler the SCENE wired knows exactly which node emits and what class it
					# is, so that node's own picture leads the row instead of the generic trigger icon.
					"object_icon": _scene_trigger_icon(event_row) if _scene_trigger_icon(event_row) != null \
						else _object_icon_for(event_row.trigger_provider_id, event_row.trigger_id)
				}.merged(condition_style_meta, true)
			)
		)
		# A signal handler's PARAMETERS are the trigger's payload - the body that entered, the item
		# that was picked up. An event sheet shows them as chips beside the trigger, so a reader knows
		# what the event hands them without opening the code.
		var handler_payload: PackedStringArray = _handler_payload_chips(event_row)
		for payload_index in range(handler_payload.size()):
			spans.append(_trigger_payload_span(handler_payload[payload_index], payload_index, condition_line_index))
		# ────────────────────────────────────────────────────────────────────────────────────────
		# A one-shot connection fires ONCE, which is the sheet's own Trigger once - so it reads as
		# that, on a chip beside the trigger. Read off the connect line the lift kept verbatim, so
		# the file is untouched and the flag is re-emitted exactly as it was written.
		if is_one_shot_handler(event_row):
			spans.append(_trigger_payload_span(
				EventSheetL10n.translate("Trigger once"), handler_payload.size(), condition_line_index))
		# ────────────────────────────────────────────────────────────────────────────────────────
		# What `@tool` actually means, said on the row it surprises people on: a per-frame event on a
		# tool sheet ALSO runs while you are editing the scene, before the game exists. One chip, on
		# the tick triggers only, because that is the one tempo where "it is running right now" is
		# something a reader has to know.
		if _ticks_in_the_editor(event_row):
			spans.append(_trigger_payload_span(
				EventSheetL10n.translate("in the editor too"),
				handler_payload.size() + 1, condition_line_index))
		# Which edge of the cursor pair this handler is, on a chip beside the words the two
		# share, in the slot the payload chips use. Quiet, because the sentence is the same sentence
		# either way, and a chip rather than a bare note because this lane lays chips out.
		if not device_note.is_empty():
			spans.append(_trigger_payload_span(device_note, handler_payload.size() + 2, condition_line_index))
		# And last on the line, muted: where this signal is actually raised.
		_append_signal_source_span(spans, event_row, condition_line_index)
		condition_line_index += 1
	elif input_reading.is_empty() and event_row.else_mode == EventRow.ElseMode.NONE and inline_trigger_condition_index >= 0 and inline_trigger_condition_index < event_row.conditions.size():
		var inline_trigger: ACECondition = event_row.conditions[inline_trigger_condition_index]
		var inline_trigger_badge_meta: Dictionary = _viewport.BADGE_TRIGGER_METADATA.duplicate(true)
		inline_trigger_badge_meta["badge_bg"] = event_style.trigger_badge_background_color
		inline_trigger_badge_meta["badge_fg"] = event_style.trigger_badge_foreground_color
		inline_trigger_badge_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)
		inline_trigger_badge_meta["line_index"] = condition_line_index
		inline_trigger_badge_meta["badge_style"] = "trigger"
		spans.append(_make_span("➜", SemanticSpan.SpanType.KEYWORD, inline_trigger_badge_meta))
		spans.append(
			_make_span(
				_format_condition_descriptor(inline_trigger),
				SemanticSpan.SpanType.CONDITION,
				{
					"lane": "condition",
					"kind": "condition",
					"ace_index": inline_trigger_condition_index,
					"ace_enabled": inline_trigger.enabled,
					"chip": true,
					"line_index": condition_line_index,
					"rendered_as_trigger": true,
					"object_label": _object_label_for(inline_trigger.provider_id, inline_trigger.ace_id),
					"object_icon": _object_icon_for(inline_trigger.provider_id, inline_trigger.ace_id)
				}.merged(condition_style_meta, true)
			)
		)
		condition_line_index += 1
	# A guard and the question it guards are ONE question. The importer files them as two
	# conditions because the file joins them with `and`, so the pair is put back together here.
	var joined_conditions: Dictionary = _joined_condition_groups(event_row.conditions,
		" or " if event_row.condition_mode == EventRow.ConditionMode.OR else " and ")
	if not event_row.conditions.is_empty():
		var displayed_condition_indices: Array[int] = []
		for condition_index in range(event_row.conditions.size()):
			if condition_index == inline_trigger_condition_index or input_consumed.has(condition_index):
				continue
			if (joined_conditions.get("consumed", {}) as Dictionary).has(condition_index):
				continue
			displayed_condition_indices.append(condition_index)
		for display_index in range(displayed_condition_indices.size()):
			var condition_index: int = displayed_condition_indices[display_index]
			var condition: ACECondition = event_row.conditions[condition_index]
			if condition == null:
				continue
			var line_index: int = condition_line_index
			_append_condition_prefix_spans(
				spans,
				event_row,
				condition,
				condition_index,
				line_index,
				display_index,
				displayed_condition_indices.size()
			)
			# A state-header condition carries its ◆ in the BADGE column - the same slot trigger
			# and tempo icons use - never inline in the text (an icon glued into a sentence reads
			# as clutter next to rows whose icons sit in the column).
			if _is_state_header_condition(condition):
				var state_badge_meta: Dictionary = _viewport.BADGE_TRIGGER_METADATA.duplicate(true)
				state_badge_meta["badge_bg"] = event_style.trigger_badge_background_color
				state_badge_meta["badge_fg"] = event_style.trigger_badge_foreground_color
				state_badge_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)
				state_badge_meta["line_index"] = line_index
				state_badge_meta["badge_style"] = "trigger"
				spans.append(_make_span("◆", SemanticSpan.SpanType.KEYWORD, state_badge_meta))
			var joined_lead: Dictionary = (joined_conditions.get("leads", {}) as Dictionary).get(
				condition_index, {})
			var condition_text: String = str(joined_lead.get("text", "")) if not joined_lead.is_empty() \
				else _format_condition_descriptor(condition)
			var condition_owner: String = str(joined_lead.get("object", "")) if not joined_lead.is_empty() \
				else _object_label_or_pending(condition.provider_id, condition.ace_id)
			spans.append(
				_make_span(
					condition_text,
					SemanticSpan.SpanType.CONDITION,
					{
						"lane": "condition",
						"kind": "condition",
						"ace_index": condition_index,
						"ace_enabled": condition.enabled,
						"chip": true,
						"line_index": line_index,
						"object_label": condition_owner,
						"object_icon": _object_icon_for(condition.provider_id, condition.ace_id),
						"swatch_color": _first_color_in_params(condition)
					}.merged(condition_style_meta, true).merged(
						state_progress_metadata(condition), true)
				)
			)
			condition_line_index += 1
	# "With node X:" scope renders as a chip in the condition lane (it scopes the row's actions to a
	# node); double-click opens the target editor.
	if not event_row.with_node_target.strip_edges().is_empty():
		spans.append(
			_make_span(
				_format_with_node(event_row),
				SemanticSpan.SpanType.CONDITION,
				{
					"lane": "condition",
					"kind": "with_node",
					"chip": true,
					"line_index": condition_line_index
				}.merged(condition_style_meta, true)
			)
		)
		condition_line_index += 1
	# Pick filters render as "For each …" lines below the conditions (the picking rows);
	# double-click opens the pick-filter dialog.
	for pick_index in range(event_row.pick_filters.size()):
		var pick: PickFilter = event_row.pick_filters[pick_index] as PickFilter
		if pick == null or not pick.enabled:
			continue
		# ── lens hook (loop rows) ──────────────────────────────────────────────────────────────
		# One call: the loop's familiar words, and the object a For-each-child loop belongs to.
		# A filtered or limited pick says more than the loop words can carry, so it keeps its own text.
		var loop_reading: Dictionary = {}
		if pick.predicate_expression.strip_edges().is_empty() and pick.pick_first_n <= 0:
			var collection_words: String = _pick_collection_words(pick)
			# Only a plain count can be a ring, and only a ring needs its body read. Deciding
			# that from the HEAD keeps every other loop in the file free of a body walk.
			var loop_body: PackedStringArray = PackedStringArray()
			if EventSheetViewportReadingRows.ring_loop_possible(pick.iterator_name, collection_words):
				loop_body = _loop_body_lines(event_row)
			loop_reading = EventSheetViewportReadingRows.loop_words(
				pick.collection_kind, pick.iterator_name, collection_words, loop_body)
		var loop_object: String = str(loop_reading.get("object", ""))
		# What the loop is FOR rides in the head's own cell, after a "·": the condition lane is
		# one column wide, and a note in a span of its own is the half a reader never gets to see.
		var loop_text: String = str(loop_reading.get("text", ""))
		var loop_note: String = str(loop_reading.get("note", ""))
		if not loop_text.is_empty() and not loop_note.is_empty():
			loop_text = "%s · %s" % [loop_text, loop_note]
		# A pick that NARROWS says so: the family in the object column, "Pick where …" in the
		# cell, and what the filter keeps following as facts. Asked after the loop words because a
		# plain walk over everything is a For each and stays one.
		var pick_reading: Dictionary = _pick_filter_reading(pick)
		if not pick_reading.is_empty():
			loop_reading = pick_reading
			loop_text = str(pick_reading.get("text", ""))
			loop_object = str(pick_reading.get("object", ""))
		spans.append(
			_make_span(
				loop_text if not loop_reading.is_empty() else _format_pick_filter(pick),
				SemanticSpan.SpanType.CONDITION,
				{
					"lane": "condition",
					"kind": "pick_filter",
					"pick_index": pick_index,
					"chip": true,
					"line_index": condition_line_index,
					# Loops are System's, as in any event sheet - and the label puts the line in the
					# shared object sub-lane, so its text aligns with the cells above it.
					"object_label": loop_object if not loop_object.is_empty() else _object_label_for("Core", ""),
					"object_icon": _reading_class_icon_for(loop_object)
				}.merged(condition_style_meta, true)
			)
		)
		condition_line_index += 1
	# In a READ-ONLY preview a body-only row leaves its left cell blank, exactly as an event sheet
	# draws one: "Always" is a placeholder that invites a condition, and a view that accepts none
	# must not invite.
	var always_placeholder_suppressed: bool = in_verb_body and _scaffolding_suppressed()
	# A blank TOP-LEVEL event already says it runs every tick by saying nothing, so writing
	# "Every Tick" into its lane would be the reading talking over itself. The lane stays empty (the
	# hover says it in words); "+ Add condition" below is still the way in. Inside a verb body the
	# placeholder is "Always" and stays, because there it is the truth.
	if not in_verb_body and not _blank_tick_reading(event_row).is_empty():
		always_placeholder_suppressed = true
	# And a blank SUB-event is the other half of the same rule: it follows its parent, in order.
	# "Every Tick" under a parent would say the rows below run every frame, which is not what they do,
	# so the lane stays empty and the hover says what blank means here.
	if _blank_sub_event(event_row):
		always_placeholder_suppressed = true
	if spans.is_empty() and event_row.else_mode != EventRow.ElseMode.ELSE and not always_placeholder_suppressed:
		# An event with no conditions reads as "every tick"; render it as a real cell (not bare
		# text) so the condition lane still shows a clear, clickable empty event block.
		# INSIDE a published verb's body it reads "Always" instead: a sheet's own events run every
		# frame (a sheet compiles into _process), but a verb's body runs when the verb is CALLED, so
		# "Every Tick" would be a plain lie about when those steps happen.
		spans.append(
			_make_span(
				EventSheetL10n.translate("Always" if in_verb_body else "Every Tick"),
				SemanticSpan.SpanType.CONDITION,
				{
					"lane": "condition",
					"kind": "condition",
					"ace_index": -1,
					"chip": true,
					"placeholder": true,
					"line_index": 0
				}.merged(condition_style_meta, true)
			)
		)
	# Event-sheet-style faint "+ Add condition" affordance on its own line below the conditions -
	# the mirror of "+ Add action", because clicking in the condition lane IS the core
	# add-a-condition gesture. The renderer hides it at rest (revealed on hover/selection, or when
	# the event has no real conditions yet); it always stays in the layout model, and
	# _count_event_lines mirrors its line (maxi(...) keeps it below the Every Tick placeholder,
	# which sits at line 0 without advancing condition_line_index).
	# A FIGURE gets neither affordance: it is an illustration, so an "+ Add condition" line is a
	# click target that does nothing, and it reserves a whole empty line of height under every row.
	var add_condition_color: Color = condition_style_meta.get("text_color", _viewport._get_condition_style().text_color)
	add_condition_color.a *= 0.55
	if not _scaffolding_suppressed():
		spans.append(
			_make_span(
				EventSheetL10n.translate("+ Add condition"),
				SemanticSpan.SpanType.CONDITION,
				{
					"lane": "condition",
					"kind": "add_condition",
					"line_index": maxi(condition_line_index, 1),
					"text_color": add_condition_color,
					"font_size_delta": condition_style_meta.get("font_size_delta", 0)
				}
			)
		)
	if not event_row.actions.is_empty():
		# The instantiate + add_child (+ first position) run is an event sheet's single Create object.
		# Worked out once for the whole lane, because a group is recognised by what FOLLOWS its lead.
		var create_groups: Dictionary = _create_object_groups(
			event_row.actions, event_row.local_variables)
		# The run of limit_* writes a camera's bounds are spelled as is one scroll-limits row.
		var limit_groups: Dictionary = _scroll_limit_groups(event_row.actions)
		# The mouse-look trio and the two faders of a crossfade are one row each.
		var look_groups: Dictionary = _mouse_look_groups(event_row.actions)
		var fade_groups: Dictionary = _crossfade_groups(event_row.actions)
		# The four lines of camera-ray plumbing are ONE question, and read as one row.
		var ray_groups: Dictionary = _cursor_ray_groups(event_row.actions)
		# The camera-relative run and a mesh's visible-range band are one row each.
		var move_groups: Dictionary = _camera_relative_move_groups(
			event_row.actions, event_row.local_variables)
		var range_groups: Dictionary = _visible_range_groups(event_row.actions)
		# The remove-then-add pair, and a reparent whose follow-flags were written out
		# beneath it, are each one hierarchy row with every line they stand for on the hover.
		var hierarchy_runs: Dictionary = _hierarchy_groups(event_row.actions, event_row.event_uid)
		# A pack recipe's head facts are said once, on the bar.
		var recipe_head: Dictionary = _recipe_head_groups(event_row.actions)
		# The lines that shape a Control the event just made read under its Local row.
		var control_setup: Dictionary = _control_setup_groups(event_row)
		# The sensor shapes and the opened input window are one row each.
		var gyro_groups: Dictionary = _gyro_groups(event_row.actions)
		var window_groups: Dictionary = _input_window_groups(event_row.actions)
		# The offset walked forward and the body put on the curve are ONE ride, and read as one row.
		var ride_groups: Dictionary = _grind_ride_groups(event_row.actions)
		# The combo shapes: the pressed input with its window, and the two freezes.
		var press_groups: Dictionary = _combo_press_groups(event_row.actions)
		var freeze_groups: Dictionary = _freeze_time_groups(event_row.actions)
		# The run of add_item calls that builds a menu is ONE menu, and reads as one bar.
		var menu_groups: Dictionary = _menu_item_groups(event_row.actions)
		# A TODO / FIXME / HACK / NOTE line written directly above a step is a note ON that step.
		var task_notes: Dictionary = _task_note_groups(event_row.actions)
		# The run of rows a multi-line `{...}` / `[...]` used as a VALUE was split into is one
		# statement, so it reads as one row with the entries as chips and no orphan bracket line.
		var literal_groups: Dictionary = EventSheetValueLiteralRows.groups(event_row.actions)
		# A test's `var passed := true` is the harness's bookkeeping, and the Check rows are the
		# verdict it stands for.
		var verdict_consumed: Dictionary = _test_verdict_consumed(event_row)
		for action_index in range(event_row.actions.size()):
			var action_resource: Resource = event_row.actions[action_index]
			if bool(verdict_consumed.get(action_index, false)):
				continue
			if bool(task_notes.get("consumed", {}).get(action_index, false)):
				continue
			# An entry line or the closing bracket of a literal the lead row above already drew. Skipped
			# without advancing the line index, which is what turns the run into one row.
			if bool(literal_groups.get("consumed", {}).get(action_index, false)):
				continue
			# The same skip-without-advancing: a head fact draws no row at all, so the step below
			# it takes the line the fact would have had.
			if bool(recipe_head.get("consumed", {}).get(action_index, false)):
				continue
			# The same skip-without-advancing: the line is drawn under the Local row instead.
			if bool(control_setup.get("consumed", {}).get(action_index, false)):
				continue
			if (literal_groups.get("leads", {}) as Dictionary).has(action_index):
				_append_value_literal_spans(spans, (literal_groups["leads"] as Dictionary)[action_index],
					action_index, action_line_index, action_style_meta)
				action_line_index += 1
				continue
			# One-shot, read and cleared by whichever formatter draws this action - the same discipline
			# the object label and the grammar segments beside it already use.
			_pending_attached_note = str((task_notes.get("notes", {}) as Dictionary).get(action_index, ""))
			# A line the Create object row above already said. Skipped without advancing the line index,
			# which is what turns three lines into one row.
			if bool(create_groups.get("consumed", {}).get(action_index, false)):
				continue
			if bool(limit_groups.get("consumed", {}).get(action_index, false)):
				continue
			# The same skip-without-advancing, for the two runs batch ten added.
			if bool(look_groups.get("consumed", {}).get(action_index, false)) \
					or bool(fade_groups.get("consumed", {}).get(action_index, false)) \
					or bool(hierarchy_runs.get("consumed", {}).get(action_index, false)):
				continue
			# The same skip-without-advancing for the batch-thirteen runs.
			if bool(ray_groups.get("consumed", {}).get(action_index, false)) \
					or bool(move_groups.get("consumed", {}).get(action_index, false)) \
					or bool(range_groups.get("consumed", {}).get(action_index, false)) \
					or bool(gyro_groups.get("consumed", {}).get(action_index, false)) \
					or bool(window_groups.get("consumed", {}).get(action_index, false)) \
					or bool(ride_groups.get("consumed", {}).get(action_index, false)) \
					or bool(press_groups.get("consumed", {}).get(action_index, false)) \
					or bool(freeze_groups.get("consumed", {}).get(action_index, false)) \
					or bool(menu_groups.get("consumed", {}).get(action_index, false)):
				continue
			var run_lead: Dictionary = (look_groups["leads"] as Dictionary).get(action_index, {})
			var run_pattern: String = "fps_look"
			if run_lead.is_empty():
				run_lead = (fade_groups["leads"] as Dictionary).get(action_index, {})
				run_pattern = "sound"
			if run_lead.is_empty():
				run_lead = (ray_groups["leads"] as Dictionary).get(action_index, {})
				run_pattern = "cursor_ray"
			if run_lead.is_empty():
				run_lead = (move_groups["leads"] as Dictionary).get(action_index, {})
				run_pattern = "movement"
			if run_lead.is_empty():
				run_lead = (range_groups["leads"] as Dictionary).get(action_index, {})
				run_pattern = "lighting"
			if run_lead.is_empty():
				run_lead = (hierarchy_runs["leads"] as Dictionary).get(action_index, {})
				run_pattern = "hierarchy"
			# The same skip-without-advancing for batch thirteen's two runs.
			if run_lead.is_empty():
				run_lead = (gyro_groups["leads"] as Dictionary).get(action_index, {})
				run_pattern = "gyro_controls"
			if run_lead.is_empty():
				run_lead = (window_groups["leads"] as Dictionary).get(action_index, {})
				run_pattern = "qte"
			# The ride, as the one row the two lines add up to.
			if run_lead.is_empty():
				run_lead = (ride_groups["leads"] as Dictionary).get(action_index, {})
				run_pattern = "grind"
			# Batch fourteen's two runs. The freeze already claimed its own pattern inside
			# the group pass (it is the only run whose two shapes claim differently), so the arm here
			# only has to draw it.
			if run_lead.is_empty():
				run_lead = (press_groups["leads"] as Dictionary).get(action_index, {})
				run_pattern = "animation_combo"
			if run_lead.is_empty():
				run_lead = (freeze_groups["leads"] as Dictionary).get(action_index, {})
				run_pattern = "animation_combo"
			# The menu the run above built, as the one bar it is.
			if run_lead.is_empty():
				run_lead = (menu_groups["leads"] as Dictionary).get(action_index, {})
				run_pattern = EventSheetMenuFacts.PATTERN_ID
			if not run_lead.is_empty():
				_append_scroll_limit_spans(spans, run_lead, action_index, action_line_index,
					action_style_meta)
				for run_line: String in (run_lead.get("evidence", PackedStringArray()) as PackedStringArray):
					_note_pattern(run_pattern, run_line)
				action_line_index += 1
				continue
			if (limit_groups.get("leads", {}) as Dictionary).has(action_index):
				var limits: Dictionary = (limit_groups["leads"] as Dictionary)[action_index]
				_append_scroll_limit_spans(spans, limits, action_index, action_line_index,
					action_style_meta)
				for limit_line: String in (limits.get("evidence", PackedStringArray()) as PackedStringArray):
					_note_pattern("camera", limit_line)
				action_line_index += 1
				continue
			if (create_groups.get("leads", {}) as Dictionary).has(action_index):
				var create: Dictionary = (create_groups["leads"] as Dictionary)[action_index]
				spans.append(_make_span(str(create.get("text", "")), SemanticSpan.SpanType.ACTION, {
					"lane": "action",
					"kind": "action",
					"ace_index": action_index,
					"ace_enabled": true,
					"chip": true,
					"line_index": action_line_index,
					"object_label": _object_label_for("Core", ""),
					"object_icon": _reading_class_icon_for(str(create.get("alias", ""))),
					"compiled_lines": int(create.get("line_count", 1)),
					# The statements this ONE cell stands for. Hover shows all of them, so the row never
					# hides a line: it says what happened, and the file's own spelling is a pointer away.
					"create_object_indices": create.get("indices", []),
					# An instance is a ready-made hierarchy: the hover shows the tree this row
					# just made, so nobody has to open the .tscn to find out what is inside it.
					"create_object_scene": str(create.get("scene", ""))
				}.merged(action_style_meta, true)))
				action_line_index += 1
				continue
			# Whichever shape the line took (a Call Method row or a verbatim block), the line
			# that wires a lambda to a signal reads as a muted NOTE: the work it describes is drawn
			# below it as the trigger event it is. Nothing is hidden - the note names the object and
			# the signal, and double-click still opens the exact GDScript.
			var connect_parts: Dictionary = connect_lambda_parts(connect_statement_of(action_resource))
			if connect_parts.is_empty():
				# The wired-up call reads below as the trigger it is, so its line reads as the
				# same muted note the lambda's line already keeps.
				connect_parts = _connect_call_note(action_resource)
			if not connect_parts.is_empty():
				spans.append(_make_span(_connect_note_text(connect_parts), SemanticSpan.SpanType.VALUE, {
					"lane": "action",
					"kind": "action",
					"ace_index": action_index,
					"ace_enabled": true,
					"chip": true,
					"raw_action": action_resource is RawCodeRow,
					"code_cell": false,
					"line_index": action_line_index,
					"text_color": _viewport._get_reading_style().muted_text_color
				}.merged(action_style_meta, false)))
				action_line_index += 1
				continue
			# A comment whose text is a STATEMENT is not a note, it is a row somebody switched
			# off, which is the only way a .gd file has of recording that. It reads as the row it
			# would be, struck through and greyed the way a disabled row already is, with the muted
			# word saying so. Prose stays a comment. The file is untouched either way.
			# `super.take_damage(x)` is calling the INCLUDED sheet's verb, not an object named
			# `super`. It reads that way: the include, the file it names, and the verb.
			var super_call: Dictionary = super_call_reading(action_resource, event_row)
			if not super_call.is_empty():
				_append_super_call_spans(spans, super_call, action_index, action_line_index, action_style_meta)
				action_line_index += 1
				continue
			var commented_out: String = commented_out_code(action_resource)
			if not commented_out.is_empty():
				_append_disabled_code_spans(spans, commented_out, action_index, action_line_index, action_style_meta)
				action_line_index += 1
				continue
			if action_resource is ACEAction:
				# A Local Variable row is a DECLARATION, and an event sheet declares its locals at
				# the TOP of the event that owns them, so the declaration is drawn there (see
				# _build_promoted_local_rows) rather than in the action lane. What stays here is the work
				# the line does: nothing when the value is already a value, and the Set action that fills
				# the local in when it is not.
				var promotion: Dictionary = local_declaration_promotion(action_resource as ACEAction)
				if not event_promotes_locals(event_row):
					promotion = {}
				if not promotion.is_empty() and str(promotion.get("set_value", "")).is_empty():
					continue
				if promotion.is_empty():
					# A declaration the promotion leaves alone (a branching value, whose pair reading
					# draws it per arm) keeps the declaration row shape it always had.
					var local_declaration: Dictionary = grammar_action_declaration(action_resource as ACEAction)
					if not local_declaration.is_empty():
						append_local_declaration_spans(spans, local_declaration, {
							"lane": "action",
							"kind": "action",
							"ace_index": action_index,
							"ace_enabled": (action_resource as ACEAction).enabled,
							"line_index": action_line_index
						}, action_style_meta)
						action_line_index += 1
						continue
				spans.append(
					_make_span(
						_format_action_descriptor(action_resource as ACEAction),
						SemanticSpan.SpanType.ACTION,
						{
							"lane": "action",
							"kind": "action",
							"ace_index": action_index,
							"ace_enabled": (action_resource as ACEAction).enabled,
							"chip": true,
							"line_index": action_line_index,
							"object_label": _object_label_or_pending((action_resource as ACEAction).provider_id, (action_resource as ACEAction).ace_id),
							"object_icon": _object_icon_for((action_resource as ACEAction).provider_id, (action_resource as ACEAction).ace_id),
							"swatch_color": _first_color_in_params(action_resource),
							"compiled_lines": compiled_line_count(action_resource as ACEAction)
						}.merged(action_style_meta, true)
					)
				)
				_append_signal_fanout_span(spans, action_resource as ACEAction, action_index, action_line_index)
				_append_removal_guard_span(spans, action_resource as ACEAction, event_row, action_index, action_line_index)
				action_line_index += 1
			elif action_resource is MatchRow:
				# match statement (the switch): header + branch lines as action cells sharing one ace_index;
				# double-click opens the match dialog. A STRUCTURED MatchRow (its `cases` set) renders each
				# case as a `pattern:` line with its body summarised beneath (an action as its friendly text)
				# and the dialog edits those cases as first-class rows; a raw-text MatchRow shows its
				# branches_text and the dialog edits the text. Either way match_action drives the editor.
				var match_resource: MatchRow = action_resource as MatchRow
				var structured_match: bool = not match_resource.cases.is_empty()
				# A STRUCTURED match's header is a muted caption in plain words - `match state:`
				# is code where a reader expects meaning, and the case rows below already say it.
				# The raw-text form keeps its code lines (that IS its escape-hatch reading).
				var match_lines: PackedStringArray
				if structured_match:
					var enabled_cases: int = 0
					for counted_case: MatchCase in match_resource.cases:
						if counted_case != null and counted_case.enabled:
							enabled_cases += 1
					if _is_state_shaped_subject(match_resource.match_expression):
						match_lines = PackedStringArray(["%s · %d %s" % [EventSheetL10n.translate("decides by state"), enabled_cases, EventSheetL10n.translate("states below")]])
					else:
						match_lines = PackedStringArray(["%s %s · %d %s" % [EventSheetL10n.translate("decides by"), match_resource.match_expression, enabled_cases, EventSheetL10n.translate("branches below")]])
				else:
					match_lines = PackedStringArray(["match %s:" % match_resource.match_expression])
					for branch_line: String in match_resource.branches_text.split("\n"):
						match_lines.append("\t" + branch_line)
				for match_line_index in range(match_lines.size()):
					spans.append(
						_make_span(
							match_lines[match_line_index] if not match_lines[match_line_index].is_empty() else " ",
							SemanticSpan.SpanType.VALUE,
							{
								"lane": "action",
								"kind": "action",
								"ace_index": action_index,
								"match_action": true,
								# line_index stacks each match line on its own row (the action lane lays spans
								# out vertically by line_index); without it every branch overlapped at line 0.
								"line_index": match_line_index,
								# The structured caption reads as an explanation (muted), never as code.
								"text_color": _viewport._get_reading_style().muted_text_color if structured_match else event_style.value_highlight_color
							}
						)
					)
			elif action_resource is TimelineRow:
				# A Timeline's header is a muted caption; the beats render as child rows below
				# ("at 0.5s" in the condition cell, the action in the action cell).
				var timeline_resource: TimelineRow = action_resource as TimelineRow
				var timeline_beats: int = 0
				for timeline_step: TimelineStep in timeline_resource.steps:
					if timeline_step != null and timeline_step.enabled:
						timeline_beats += 1
				spans.append(
					_make_span(
						"%s · %d %s" % [EventSheetL10n.translate("timeline"), timeline_beats, EventSheetL10n.translate("steps")],
						SemanticSpan.SpanType.VALUE,
						{
							"lane": "action",
							"kind": "action",
							"ace_index": action_index,
							"line_index": 0,
							"text_color": _viewport._get_reading_style().muted_text_color
						}
					)
				)
			elif action_resource is CollectionDeclRow:
				# Option 1 of the collection-declaration work: ONE "Declare <name>" action row with each
				# entry on a single-cell line of its own - no bracket rows, and the same one-span cell
				# every other action uses, so the automatic value tinting reads `"calm" = 3` exactly like
				# `Set variable score to 0`. Double-clicking an entry edits the whole line in place
				# (edit_kind carries the action and entry index, since the span-edit signal passes no
				# metadata); the commit re-parses `key = value`, so either side can be changed.
				var decl: CollectionDeclRow = action_resource as CollectionDeclRow
				# The header reads as three CHIPS (Declare / name / type - count): the look the single-cell
				# pass lost and the user asked back. Only the last chip stretches to close the lane, so the
				# cell background still runs edge to edge; the entry lines below stay single cells.
				var decl_head_meta: Dictionary = {
					"lane": "action",
					"kind": "action",
					"ace_index": action_index,
					"ace_enabled": decl.enabled,
					"chip": true,
					"line_index": action_line_index
				}
				spans.append(_make_span("Declare", SemanticSpan.SpanType.VALUE,
					decl_head_meta.duplicate().merged({"natural_width": true}, true).merged(action_style_meta, false)))
				spans.append(_make_span(decl.variable_name(), SemanticSpan.SpanType.VALUE,
					decl_head_meta.duplicate().merged({"natural_width": true, "text_color": _viewport._get_reading_style().primary_text_color}, true).merged(action_style_meta, false)))
				spans.append(_make_span("%s - %d %s" % ["Dictionary" if decl.is_dictionary() else "Array",
					decl.entry_values.size(), "entry" if decl.entry_values.size() == 1 else "entries"],
					SemanticSpan.SpanType.VALUE,
					decl_head_meta.duplicate().merged({"text_color": _viewport._get_event_style().comment_text_color}, true).merged(action_style_meta, false)))
				action_line_index += 1
				for entry_index: int in decl.entry_values.size():
					var entry_key: String = decl.entry_keys[entry_index] if entry_index < decl.entry_keys.size() else ""
					var entry_text: String = "        %s" % decl.entry_values[entry_index]
					if not entry_key.is_empty():
						entry_text = "        %s = %s" % [entry_key, decl.entry_values[entry_index]]
					spans.append(_make_span(entry_text, SemanticSpan.SpanType.VALUE, {
						"lane": "action",
						"kind": "action",
						"ace_index": action_index,
						"ace_enabled": decl.enabled,
						"chip": true,
						"decl_entry_index": entry_index,
						"editable": true,
						"edit_kind": "decl_entry_line:%d:%d" % [action_index, entry_index],
						"line_index": action_line_index
					}.merged(action_style_meta, false)))
					action_line_index += 1
			elif action_resource is RawCodeRow:
				# In-flow GDScript block: one action-lane cell per code line. All lines share
				# the block's ace_index, so click/drag/delete treat the block as one action.
				var inline_raw: RawCodeRow = action_resource as RawCodeRow
				var inline_lines: PackedStringArray = inline_raw.code.split("\n")
				# A block that is ENTIRELY comments is a note, not code - the same treatment a top-level
				# comment block already gets, applied INSIDE a function body, where comments were the
				# single largest thing still rendering as a GDScript wall.
				var inline_is_note: bool = is_comment_only_block(inline_lines)
				# ...and a multi-line collection literal collapses to one summary cell, because it is one
				# value rather than a run of statements. Both are pure views over the unchanged row, so the
				# byte round-trip holds and double-click still opens the code editor.
				var inline_literal: Dictionary = data_literal_info(inline_raw.code)
				# A single INDENTED line is a continuation of the statement above it - an entry of the
				# literal that was just split into one action per line. Repeating the code badge down every
				# entry of a defaults table is noise, and the indentation already says what the row is.
				# Rows that are part of a collection literal read as data, so they wear ordinary action
				# chrome: no GDScript badge and no code cell. Splitting the literal per line was only
				# worth doing if the entries then look and behave like the actions around them.
				# ONE statement is one action, so it wears the ordinary action chrome the rows around it use.
				# The GDScript code cell exists to hold a WALL of several statements together; using it for a
				# single line made ordinary code look like an escape hatch instead of a step in the flow.
				# A statement carrying an inline lambda is CODE, not a step: the `func(...)` body is a
				# second scope with its own returns and its own branches, so no one-cell sentence can
				# honestly stand for it - and hoisting a branch out of it would move when that branch
				# runs. It keeps the GDScript code cell it came from.
				var inline_is_literal_part: bool = (
					is_literal_part(inline_raw.code) or is_single_statement(inline_raw.code)
				) and not inline_raw.code.contains("func(")
				if not inline_literal.is_empty():
					inline_lines = PackedStringArray(["%s %s   %d entries" % [
						str(inline_literal.get("head")), str(inline_literal.get("close")),
						int(inline_literal.get("entries", 0))]])
				var inline_total: int = maxi(inline_lines.size(), 1)
				# ONE statement also reads as a SENTENCE ("Add 1 to score") or as an Object/Verb/params chip
				# run, when a pure classifier claims the line - the same shape every ACE row on the canvas
				# already has. Zeroing the line total skips the per-line default below; the sentence occupies
				# the single line this row consumes, and the RawCodeRow itself is untouched.
				if not inline_is_note and inline_literal.is_empty() and is_single_statement(inline_raw.code):
					if _append_sentence_spans(spans, inline_raw, action_index, action_line_index, action_style_meta):
						inline_total = 0
						action_line_index += 1
				for inline_line_index in range(inline_total):
					var inline_text: String = inline_lines[inline_line_index] if inline_line_index < inline_lines.size() else " "
					spans.append(
						_make_span(
							inline_text if not inline_text.is_empty() else " ",
							SemanticSpan.SpanType.VALUE,
							{
								"lane": "action",
								"kind": "action",
								"ace_index": action_index,
								"ace_enabled": inline_raw.enabled,
								"chip": true,
								"raw_action": true,
								# The renderer merges block lines into ONE code cell
								# (left stripe, continuous background) - per-line
								# spans stay the layout/hit-test truth.
								"code_cell": not inline_is_literal_part,
								"block_lines": inline_total,
								"block_line": inline_line_index,
								"line_index": action_line_index,
								"text_color": _viewport._get_event_style().comment_text_color if inline_is_note else action_style_meta.get("text_color", _viewport._get_reading_style().primary_text_color),
								"object_label": "" if inline_is_literal_part else (_inline_block_label(inline_is_note, inline_literal) if inline_line_index == 0 else "")
							}.merged(action_style_meta, true)
						)
					)
					action_line_index += 1
			elif action_resource is CommentRow:
				# Action-cell comment (event-sheet parity: comments can live inside an event's
				# action flow; convertible back to a standalone comment row). One
				# comment-styled cell per text line, sharing the ace_index.
				var action_comment: CommentRow = action_resource as CommentRow
				var action_comment_lines: PackedStringArray = action_comment.text.split("\n") if not action_comment.text.is_empty() else PackedStringArray(["Comment"])
				# The OTHER kind of comment - the same CommentRow, read inside the event's action
				# flow - gets the same doors. A note is a note wherever it is written.
				var action_door_table: Dictionary = EventSheetCommentDoors.table_for(_viewport._sheet)
				for comment_line_index in range(action_comment_lines.size()):
					# Reading Mode drops the marker and draws the line italic, so what is DRAWN - and
					# therefore what the door offsets index - is the bare line there and the
					# "# "-prefixed one everywhere else.
					var action_comment_drawn: String = action_comment_lines[comment_line_index] if _viewport.is_reading_mode() else "# " + action_comment_lines[comment_line_index]
					var action_comment_doors: Dictionary = {}
					_note_comment_doors(action_comment_doors, action_comment_drawn, action_door_table)
					spans.append(
						_make_span(
						action_comment_drawn,
							SemanticSpan.SpanType.COMMENT,
							action_comment_doors.merged({
								"lane": "action",
								"kind": "action",
								"ace_index": action_index,
								"ace_enabled": action_comment.enabled,
								"chip": true,
								"action_comment": true,
								# Merged like GDScript blocks, and carrying the action
								# cell chrome (chip_bg etc.) so a comment in the action
								# lane reads like its sibling cells - comment text
								# color wins (merged with overwrite OFF).
								"block_lines": action_comment_lines.size(),
								"block_line": comment_line_index,
								"line_index": action_line_index,
							"text_color": _viewport._get_event_style().comment_text_color,
							# Reading Mode: the note reads as an italic CAPTION - intent first, mechanics under
							# it - and drops its # marker (the row is already visibly a comment). View state only.
							"bbcode_segments": EventSheetBBCodeLite.parse("[i]%s[/i]" % action_comment_lines[comment_line_index], _viewport._get_event_style().comment_text_color) if _viewport.is_reading_mode() else []
							}.merged(action_style_meta, false))
						)
					)
					action_line_index += 1
	# The event comment (if any) sits below the actions; "+ Add" sits at the bottom of the
	# action lane, LEFT-aligned so it always stays visible. It used to be pinned to the lane's
	# far-right edge, which scrolled off-screen unless the editor window was very wide.
	var add_action_line_index: int = action_line_index
	if not event_row.comment.is_empty():
		var comment_line_index: int = max(action_line_index, _viewport.COMMENT_DEFAULT_LINE_INDEX)
		spans.append(
			_make_span(
				event_row.comment,
				SemanticSpan.SpanType.COMMENT,
				{
					"editable": true,
					"edit_kind": "event_comment",
					"lane": "action",
					"chip": true,
					"line_index": comment_line_index
				}.merged(action_style_meta, true)
			)
		)
		add_action_line_index = comment_line_index + 1
	# Event-sheet-style faint "Add action" affordance on its own line below the actions.
	var add_action_color: Color = action_style_meta.get("text_color", _viewport._get_action_style().text_color)
	add_action_color.a *= 0.55
	if not _scaffolding_suppressed():
		spans.append(
			_make_span(
				EventSheetL10n.translate("+ Add action"),
				SemanticSpan.SpanType.ACTION,
				{
					"lane": "action",
					"kind": "add_action",
					"line_index": add_action_line_index,
					"text_color": add_action_color,
					"font_size_delta": action_style_meta.get("font_size_delta", 0)
				}
			)
		)
	spans.append_array(_pattern_chip_spans(event_row))
	return spans


## The ⟡ chip that names the PATTERN this event is, when a reading claimed one on it. It sits
## at the end of the FIRST condition line, after the trigger and its parameter chips, exactly where a
## note about the whole event belongs; rows that merely USE a pattern's words get nothing, because
## the claim names the one row that owns the shape.
##
## Everything here is read out of EventSheetPatternFacts - this draws claims, it never re-derives
## one - so an event only says "Cooldown" if the reading that recognised it said so first, with its
## evidence. Off when the Patterns lens is off, which is the doubter's switch back to the plain
## statement sentences underneath.
func _pattern_chip_spans(event_row: EventRow) -> Array[SemanticSpan]:
	var spans: Array[SemanticSpan] = []
	if event_row == null or not _viewport.patterns_lens_enabled():
		return spans
	var sheet: EventSheetResource = _viewport._sheet
	if sheet == null or event_row.event_uid.is_empty():
		return spans
	# Asked for rather than assumed: this pass and the file-level walk both claim, and nothing fixes
	# their order against every clear of the registry.
	EventSheetViewportReadingRows.ensure_claims(sheet)
	var reading_style: EventSheetReadingStyle = _viewport._get_reading_style()
	for claim: Variant in EventSheetPatternFacts.claims_for_row(sheet, event_row.event_uid):
		if not EventSheetPatternVocabulary.is_marked(str((claim as Dictionary).get("pattern", ""))):
			continue
		# THE CHIP SAYS THE PATTERN'S NAME, not the claim's own sentence. A claim's `words` is the one
		# line the hover shows ("counts cooldown down and asks whether it has run out"); a chip is a
		# NAME, and a whole clause on a row would be a second sentence competing with the row's own.
		var words: String = EventSheetPatternVocabulary.words(str((claim as Dictionary).get("pattern", "")))
		if words.is_empty():
			words = str((claim as Dictionary).get("words", ""))
		if words.is_empty():
			continue
		spans.append(_make_span("%s %s" % [PATTERN_CHIP_MARK, EventSheetL10n.translate(words)],
			SemanticSpan.SpanType.CONDITION, {
				"editable": false,
				"lane": "condition",
				"kind": "pattern_chip",
				"pattern": str((claim as Dictionary).get("pattern", "")),
				"chip": true,
				"hoverable": true,
				"line_index": 0,
				"natural_width": true,
				"chip_bg": reading_style.resolved_pattern_chip_background(),
				"text_color": reading_style.resolved_pattern_chip_foreground()
			}))
	return spans


## Cheaply computes how many stacked lines an event row occupies, mirroring the
## line-index accounting in _build_event_spans() WITHOUT building any spans. This lets
## the whole sheet be measured (row heights/metrics) without the expensive span pass.
## Invariant (covered by event_lazy_spans_test): equals max span line_index + 1.
func _count_event_lines(event_row: EventRow) -> int:
	if event_row == null:
		return 1
	# Condition lane. An else row leads with its "System | Else" condition chip INSTEAD of a trigger line
	# (an Else block never repeats its trigger) - the span pass renders exactly one of the two, so the
	# count mirrors that with a plain either/or.
	var condition_lines: int = 0
	# Mirrors the span pass exactly: a recognized input branch draws ONE trigger line in place of
	# both the Else chip and the generic trigger cell, and drops the conjuncts its sentence absorbed.
	var input_reading: Dictionary = _input_branch_reading(event_row)
	var input_consumed: Dictionary = input_reading.get("consumed", {})
	if input_reading.is_empty() and (event_row.else_mode == EventRow.ElseMode.ELSE or event_row.else_mode == EventRow.ElseMode.ELIF):
		condition_lines += 1
	var inline_trigger_index: int = _find_inline_trigger_condition_index(event_row)
	var has_trigger: bool = (
		event_row.trigger != null
		or not event_row.trigger_id.is_empty()
		or (inline_trigger_index >= 0 and inline_trigger_index < event_row.conditions.size())
	)
	if not input_reading.is_empty():
		condition_lines += 1
	elif has_trigger and event_row.else_mode == EventRow.ElseMode.NONE and not is_input_trigger_tick(event_row):
		# Mirrors the span pass here too: a tick handler whose one condition is an edge poll draws
		# the badge on the CONDITION's line rather than a tick line of its own, so it is one line
		# shorter. Any lazy measure reads this count, not the spans, so the two must agree exactly.
		condition_lines += 1
	for condition_index in range(event_row.conditions.size()):
		if condition_index == inline_trigger_index or input_consumed.has(condition_index):
			continue
		if event_row.conditions[condition_index] == null:
			continue
		condition_lines += 1
	if not event_row.with_node_target.strip_edges().is_empty():
		condition_lines += 1
	for pick_entry in event_row.pick_filters:
		if pick_entry is PickFilter and (pick_entry as PickFilter).enabled:
			condition_lines += 1
	# "+ Add condition" sits on its own line below the conditions, so the lane's last line index
	# equals the condition line count - except an empty lane, where the Every Tick placeholder
	# holds line 0 and the affordance takes line 1 (mirrors _build_event_spans exactly).
	# A FIGURE gets no "+ Add" affordance in either lane (_build_event_spans drops both), so its
	# last line is the last real one: condition_lines - 1, or 0 for the Every Tick placeholder.
	# Mirroring that here is what keeps the invariant above true in figure mode - and it is what
	# actually saves the empty line of height, since any lazy measure reads this and not the spans.
	var max_condition_line: int = maxi(condition_lines - 1, 0) if _scaffolding_suppressed() else maxi(condition_lines, 1)
	# Action lane: "+ Add" sits on its own line below the actions (and below the event comment
	# when present), so the lane spans action_count (+ comment) + 1 lines. In-flow GDScript
	# blocks occupy one line per code line.
	var action_count: int = 0
	# Mirrors the span pass: the run of rows one multi-line literal was split into draws ONE
	# line, and its entry and closing-bracket rows draw none.
	var literal_groups: Dictionary = EventSheetValueLiteralRows.groups(event_row.actions)
	var literal_consumed: Dictionary = literal_groups.get("consumed", {})
	var literal_leads: Dictionary = literal_groups.get("leads", {})
	# Mirrors the span pass too: a test's folded verdict local draws no line in either lane.
	var verdict_consumed: Dictionary = _test_verdict_consumed(event_row)
	# Mirrors the span pass: a pack recipe's head facts are said on the bar, so the lines that
	# state them draw no rows and cost the lane no height.
	var recipe_consumed: Dictionary = _recipe_head_groups(event_row.actions).get("consumed", {})
	# Mirrors the span pass: a line drawn under the Local row costs the action lane no height.
	var setup_consumed: Dictionary = _control_setup_groups(event_row).get("consumed", {})
	var literal_index: int = -1
	for action_resource in event_row.actions:
		literal_index += 1
		if bool(verdict_consumed.get(literal_index, false)):
			continue
		if bool(literal_consumed.get(literal_index, false)):
			continue
		if bool(recipe_consumed.get(literal_index, false)):
			continue
		if bool(setup_consumed.get(literal_index, false)):
			continue
		if literal_leads.has(literal_index):
			action_count += 1
			continue
		if action_resource is ACEAction:
			# Mirrors the span pass: a local whose value is already a value draws no action line at
			# all - its declaration is the row at the top of the event.
			var promotion: Dictionary = local_declaration_promotion(action_resource as ACEAction)
			if (not promotion.is_empty() and str(promotion.get("set_value", "")).is_empty()
					and event_promotes_locals(event_row)):
				continue
			action_count += 1
		elif action_resource is RawCodeRow:
			# A connected lambda collapses to ONE muted note line however many lines it spans,
			# because its body is drawn below as the trigger event it reads as.
			var raw_code: String = (action_resource as RawCodeRow).code
			if not connect_lambda_parts(connect_statement_of(action_resource)).is_empty():
				action_count += 1
			elif not _connect_call_note(action_resource).is_empty():
				# The wired-up call's line is one muted note too, for the same reason.
				action_count += 1
			else:
				action_count += maxi(raw_code.split("\n").size(), 1)
		elif action_resource is CollectionDeclRow:
			# Header line + one line per entry; the brackets never render, so they never count.
			action_count += 1 + (action_resource as CollectionDeclRow).entry_values.size()
		elif action_resource is MatchRow:
			var match_resource: MatchRow = action_resource as MatchRow
			if not match_resource.cases.is_empty():
				action_count += 1  # just the `match expr:` header; each case is its own child row now
			else:
				action_count += match_resource.branches_text.split("\n").size() + 1
		elif action_resource is CommentRow:
			action_count += maxi((action_resource as CommentRow).text.split("\n").size(), 1)
	var max_action_line: int = action_count - 1 if _scaffolding_suppressed() else action_count
	if not event_row.comment.is_empty():
		var comment_line: int = maxi(action_count, _viewport.COMMENT_DEFAULT_LINE_INDEX)
		max_action_line = comment_line if _scaffolding_suppressed() else comment_line + 1
	return maxi(max_condition_line, max_action_line) + 1


## Inside a `Set return value` cell: when the value is a call to one of THIS sheet's own
## functions, the cell names the Function the way the picker does - `Set return value to Can Stand Up`
## rather than `_can_stand_up()`. With arguments the Call wording stays, so the argument chips have a
## verb to hang off. A call to anything the sheet does not know falls straight through: a call to
## something unknown must never be dressed up as a project function.
func _named_return_sentence(sentence: Dictionary, returned: String) -> Dictionary:
	if sentence.is_empty():
		return sentence
	var replacement: Array = _return_value_function_pieces(returned)
	if replacement.is_empty():
		return sentence
	var expected: String = EventSheetSentence.expression_text(returned.strip_edges())
	var segments: Array = []
	var replaced: bool = false
	for entry: Variant in (sentence.get("segments", []) as Array):
		var segment: Dictionary = entry
		if not replaced and str(segment.get("tone", "")) == "value" and str(segment.get("text", "")) == expected:
			for piece: Variant in replacement:
				segments.append({"text": str((piece as Array)[0]), "tone": str((piece as Array)[1])})
			replaced = true
			continue
		segments.append(segment)
	if not replaced:
		return sentence
	var named: Dictionary = sentence.duplicate(true)
	named["segments"] = segments
	return named


## The pieces a known-function call reads as inside a return cell, or [] when the callee is not one
## of the sheet's own functions.
func _return_value_function_pieces(returned: String) -> Array:
	var sheet: EventSheetResource = _viewport._sheet
	if sheet == null:
		return []
	var text: String = returned.strip_edges()
	var call: Dictionary = EventSheetSentence.call_parts(text)
	if call.is_empty():
		return []
	var function_name: String = EventSheetViewportReadingRows.called_function_name(text)
	if function_name.is_empty():
		return []
	var event_function: EventFunction = find_function_by_name(sheet, function_name)
	if event_function == null:
		return []
	var display_name: String = EventSheetViewportLenses.function_display_name(
		function_name, event_function.ace_display_name)
	if display_name.strip_edges().is_empty():
		return []
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	if arguments.is_empty():
		return [[display_name, "name"]]
	var parameter_names: PackedStringArray = EventSheetViewportReadingRows.parameter_names_of(event_function)
	var pieces: Array = [[EventSheetL10n.translate("Call") + " ", "plain"], [display_name, "name"]]
	for index: int in arguments.size():
		var parameter_name: String = parameter_names[index] if index < parameter_names.size() else ""
		var value: String = arguments[index].strip_edges()
		if _viewport.humanize_names_enabled():
			value = EventSheetViewportLenses.humanize_expression(value, _export_knob_names())
		else:
			value = EventSheetViewportLenses.possessive_in_expression(value, false)
		pieces.append(["   ", "plain"])
		pieces.append([EventSheetViewportLenses.call_argument_chip(parameter_name, value, false), "value"])
	return pieces


# ── the undo funnel - one door, one step ───────────────────────────────────────────────────────


## The parts of an edit handed to the mutation funnel:
## {name, type_word, object, label, body} - the local that catches the answer, the object whose
## funnel it is, the words the step is called by, and the lines of the edit itself.
## {} for anything that is not that shape, which is every other block in the file.
##
## Shape-bound on purpose, exactly like the connected-lambda parse it sits beside: everything
## downstream is a reading, nothing is lifted, and the file keeps the lines it always had.
static func undo_step_parts(code: String) -> Dictionary:
	var lines: PackedStringArray = code.split("\n")
	if lines.size() < 2:
		return {}
	var first: String = lines[0].strip_edges()
	var name: String = ""
	var type_word: String = ""
	if first.begins_with("var "):
		var assign_at: int = first.find(" = ")
		if assign_at < 0:
			return {}
		var declared: String = first.substr(4, assign_at - 4).strip_edges()
		var colon_at: int = declared.find(":")
		name = (declared if colon_at < 0 else declared.substr(0, colon_at)).strip_edges()
		type_word = "" if colon_at < 0 else declared.substr(colon_at + 1).strip_edges()
		first = first.substr(assign_at + 3).strip_edges()
	# The funnel itself, or a thin forwarder that says "undoable" in its own name - the alias a
	# coordinator's door is usually reached through. Read off the head of the call rather than
	# through a call parse: the statement is deliberately unclosed here, the lambda's body being
	# the rest of the block.
	var open_at: int = first.find("(")
	if open_at <= 0 or not first.ends_with(":"):
		return {}
	var head: String = first.substr(0, open_at)
	var dot_at: int = head.rfind(".")
	if dot_at <= 0 or not EventSheetEditorSourceFacts.is_funnel_method(head.substr(dot_at + 1)):
		return {}
	var receiver: String = head.substr(0, dot_at).strip_edges()
	var arguments: String = first.substr(open_at + 1)
	var comma_at: int = arguments.find(",")
	if comma_at < 0:
		return {}
	var label: String = arguments.substr(0, comma_at).strip_edges()
	if not (label.begins_with("\"") or label.begins_with("'")):
		return {}
	if not arguments.substr(comma_at + 1).strip_edges().begins_with("func("):
		return {}
	var body: PackedStringArray = PackedStringArray()
	for index: int in range(1, lines.size()):
		var line: String = lines[index]
		var text: String = line.substr(1) if line.begins_with("\t") else line.strip_edges()
		if index == lines.size() - 1:
			# The funnel's own `)` closes on the edit's last line, where it is punctuation rather
			# than part of the step. Dropped only when it is the bracket that closes the call.
			if not text.ends_with(")"):
				return {}
			text = text.substr(0, text.length() - 1)
		if not text.strip_edges().is_empty():
			body.append(text)
	if body.is_empty():
		return {}
	return {
		"name": name,
		"type_word": type_word,
		"receiver": receiver,
		"label": label.substr(1, label.length() - 2),
		"body": body
	}


## The undo-step row's own cell: the local that catches the answer, the step's name in the words
## Undo will show, and the cue that what follows is the edit. Pure view - the RawCodeRow keeps every
## line it had, so the byte round-trip is untouched and a double-click still opens the statement.
func _append_undo_step_spans(spans: Array, parts: Dictionary, action_index: int, line_index: int,
		action_style_meta: Dictionary) -> void:
	var context: Dictionary = sentence_context()
	var object_name: String = EventSheetSentence.helper_object(str(parts.get("receiver", "")), context)
	if object_name.is_empty():
		object_name = EventSheetSentence.object_of_reference(str(parts.get("receiver", "")))
	var step_text: String = "%s ▸ %s \"%s\"" % [object_name,
		EventSheetL10n.translate("Edit sheet undoably"), str(parts.get("label", ""))]
	var base_meta: Dictionary = {
		"lane": "action",
		"kind": "action",
		"ace_index": action_index,
		"raw_action": true,
		"code_cell": false,
		"chip": true,
		"line_index": line_index
	}
	var type_word: String = friendly_type_word(str(parts.get("type_word", "")))
	spans.append(_make_span("%s %s" % [EventSheetL10n.translate("Local"), type_word],
		SemanticSpan.SpanType.VALUE, base_meta.duplicate().merged({
			"natural_width": true,
			"text_color": _viewport._get_event_style().object_label_color
		}, true).merged(action_style_meta, false)))
	spans.append(_make_span(str(parts.get("name", "")), SemanticSpan.SpanType.VALUE,
		base_meta.duplicate().merged({
			"natural_width": true,
			"text_color": _viewport._get_reading_style().primary_text_color
		}, true).merged(action_style_meta, false)))
	spans.append(_make_span("= %s" % step_text, SemanticSpan.SpanType.VALUE,
		base_meta.duplicate().merged({
			"natural_width": true,
			"text_color": _viewport._get_event_style().value_highlight_color
		}, true).merged(action_style_meta, false)))
	spans.append(_make_span(EventSheetL10n.translate("↓ the steps below are the edit"),
		SemanticSpan.SpanType.VALUE, base_meta.duplicate().merged({
			"text_color": _viewport._get_reading_style().muted_text_color
		}, true).merged(action_style_meta, false)))


## The edit itself, as the sub-events it is: every line of the callback read through the very
## same lift a declared function's body goes through, so a statement says the same thing wherever it
## was written. The rows are inert - they stand for one statement the file holds, which is untouched.
func _build_undo_step_rows(event_row: EventRow, anchor_base: String, indent: int) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	if event_row == null:
		return rows
	for action_index: int in event_row.actions.size():
		var raw: RawCodeRow = event_row.actions[action_index] as RawCodeRow
		if raw == null:
			continue
		var parts: Dictionary = undo_step_parts(raw.code)
		if parts.is_empty():
			continue
		# `return true` inside an edit is the ANSWER the funnel asked for ("did this change
		# anything?"), which is what the flag below turns on - for these rows only.
		_answer_return_rows += 1
		var built: int = 0
		for body_event: Variant in EventSheetACELifter.lift_body_rows(
				parts.get("body", PackedStringArray()), _sheet_object_variable_names()):
			if not (body_event is EventRow):
				continue
			var body_row: EventRowData = _build_event_row(body_event as EventRow, indent)
			body_row.row_uid = "%s_edit%d_%d" % [anchor_base, action_index, built]
			# A line of the edit runs when the edit runs - "Always", never the sheet's "Every Tick",
			# which is what a condition-less row means at sheet level and never means in here.
			_mark_verb_body(body_row, EventSheetSentence.VerbKind.ACTION, _current_verb_function)
			_ensure_subtree_spans(body_row)
			_make_row_inert(body_row)
			rows.append(body_row)
			built += 1
		_answer_return_rows -= 1
		var sheet: EventSheetResource = _viewport._sheet
		if sheet != null:
			EventSheetPatternFacts.claim(sheet, "undo_step", anchor_base, anchor_base,
				PackedStringArray([str(parts.get("label", ""))]),
				EventSheetL10n.translate("one undoable step, the edit under it"))
	return rows


## Builds a row's spans and its whole subtree's, now rather than on first paint - what a reading with
## a per-row fact of its own needs, because the lazy build runs long after the fact is gone.
func _ensure_subtree_spans(row_data: EventRowData) -> void:
	_ensure_event_spans(row_data)
	for child: EventRowData in row_data.children:
		_ensure_subtree_spans(child)


# ── a lambda connected to a signal reads as the trigger event it is ─────────────────────────────


## The GDScript a connect-a-lambda action stands for, whichever shape the open lifted it into: a
## verbatim block keeps its own text, and the generic Call Method row it usually becomes is put back
## together from its parameters. "" when the action is not a connect at all - which is the common
## case, and the reason this is a substring test before anything else.
static func connect_statement_of(action_resource: Variant) -> String:
	if action_resource is RawCodeRow:
		var code: String = (action_resource as RawCodeRow).code
		return code if code.contains(".connect(func(") else ""
	if not (action_resource is ACEAction):
		return ""
	var action: ACEAction = action_resource as ACEAction
	if action.ace_id != "CallMethod":
		return ""
	var params_dict: Dictionary = action.params if not action.params.is_empty() else action.parameters
	var method: String = str(params_dict.get("method", ""))
	var arguments: String = str(params_dict.get("args", ""))
	if not method.ends_with("connect") or not arguments.begins_with("func("):
		return ""
	return "%s.%s(%s)" % [str(params_dict.get("target", "")), method, arguments]


## "connects Timer On Timeout" - the muted note the connect line keeps, so the wiring is still
## written down where the file writes it even though the work reads as a trigger event below.
static func _connect_note_text(parts: Dictionary) -> String:
	return EventSheetL10n.translate("connects {object} {trigger}") \
		.replace("{object}", str(parts.get("object", ""))) \
		.replace("{trigger}", str(parts.get("trigger", "")))


## Splits `$Timer.timeout.connect(func(): seconds_left -= 1)` - and its multi-line twin - into
## {object, trigger, args, body}. Returns {} for anything else, including a connect that hands over a
## NAMED function: that already reads as the handler it is, in the place the function was declared.
##
## The parse is deliberately shape-bound rather than clever, because everything downstream of it is a
## reading: nothing is lifted, nothing is written, and the file keeps the one line it always had.
static func connect_lambda_parts(code: String) -> Dictionary:
	var marker: int = code.find(".connect(func(")
	if marker < 0:
		return {}
	var lines: PackedStringArray = code.split("\n")
	var first: String = lines[0]
	if first.find(".connect(func(") != marker:
		return {}  # the shape must OPEN the statement, not sit inside a later line
	var head: String = first.substr(0, marker).strip_edges()
	var dot_at: int = head.rfind(".")
	if dot_at <= 0:
		return {}
	var signal_bare: String = head.substr(dot_at + 1)
	if not EventSheetSentence.is_identifier(signal_bare):
		return {}
	var object_word: String = _await_object_word(head.substr(0, dot_at))
	if object_word.is_empty():
		return {}
	var params_open: int = marker + 13  # the "(" of `func(`
	var params_close: int = _matching_paren(first, params_open)
	if params_close < 0:
		return {}
	var params_text: String = first.substr(params_open + 1, params_close - params_open - 1)
	var after: String = first.substr(params_close + 1)
	var colon_at: int = after.find(":")
	if colon_at < 0:
		return {}
	var between: String = after.substr(0, colon_at).strip_edges()
	if not between.is_empty() and not between.begins_with("->"):
		return {}
	var body_lines: PackedStringArray = PackedStringArray()
	if lines.size() == 1:
		# One line: the body runs from the colon to the `)` that closes `connect(` itself.
		var connect_close: int = _matching_paren(first, marker + 8)
		var body_start: int = params_close + 1 + colon_at + 1
		if connect_close <= body_start:
			return {}
		var body: String = first.substr(body_start, connect_close - body_start).strip_edges()
		if body.is_empty():
			return {}
		body_lines.append(body)
	else:
		if not after.substr(colon_at + 1).strip_edges().is_empty():
			return {}
		# The `)` that closes `connect(` is written two ways, and both mean the same thing: on a line
		# of its own, or glued to the end of the last line of the body - which is how nearly every
		# hand-written connect in a real file spells it. A tail line is the last body line with that
		# one bracket taken off, and it is only taken off when the bracket really is the one that
		# closes the call.
		var last_line: String = lines[lines.size() - 1]
		var tail_line: String = ""
		if last_line.strip_edges() != ")":
			if _matching_paren(code, marker + 8) != code.length() - 1:
				return {}
			tail_line = last_line.substr(0, last_line.length() - 1)
			if tail_line.strip_edges().is_empty():
				return {}
		for line_index: int in range(1, lines.size() - 1):
			var body_line: String = lines[line_index]
			body_lines.append(body_line.substr(1) if body_line.begins_with("\t") else body_line.strip_edges())
		if not tail_line.is_empty():
			body_lines.append(tail_line.substr(1) if tail_line.begins_with("\t") else tail_line.strip_edges())
		if body_lines.is_empty():
			return {}
	var args: PackedStringArray = PackedStringArray()
	for parameter: String in params_text.split(","):
		var bare: String = parameter.strip_edges()
		if bare.is_empty():
			continue
		var type_at: int = bare.find(":")
		args.append((bare.substr(0, type_at) if type_at > 0 else bare).strip_edges())
	# ── lens hook ──────────────────────────────────────────────────────────────────────────────
	# A collision signal reads as the event-sheet trigger it is, exactly as a declared handler's does.
	var collision_words: String = EventSheetViewportReadingRows.collision_trigger_words(signal_bare)
	return {
		"object": object_word,
		"trigger": collision_words if not collision_words.is_empty() else "On %s" % signal_bare.capitalize(),
		"args": args,
		"body": body_lines
	}


## The index of the `)` closing the `(` at `open_at`, or -1. Quote-aware, so a bracket inside a
## string literal in an argument never closes the call.
static func _matching_paren(text: String, open_at: int) -> int:
	if open_at < 0 or open_at >= text.length() or text[open_at] != "(":
		return -1
	var depth: int = 0
	var in_string: bool = false
	var quote: String = ""
	var index: int = open_at
	while index < text.length():
		var character: String = text[index]
		if in_string:
			if character == "\\":
				index += 2
				continue
			if character == quote:
				in_string = false
			index += 1
			continue
		if character == "\"" or character == "'":
			in_string = true
			quote = character
		elif character == "(":
			depth += 1
		elif character == ")":
			depth -= 1
			if depth == 0:
				return index
		index += 1
	return -1


## The trigger event (plus its body rows) that each connected lambda in this event reads as. Pure
## view: the rows stand for the ONE connect statement the file holds, which is why they all carry its
## `ternary_anchor_uid` - selection, the arrow keys, drag and the gutter then treat the whole reading
## as that statement, exactly as they already do for a ternary pair.
func _build_connect_lambda_rows(event_row: EventRow, anchor_base: String, indent: int) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	if event_row == null:
		return rows
	for action_index in range(event_row.actions.size()):
		var parts: Dictionary = connect_lambda_parts(connect_statement_of(event_row.actions[action_index]))
		if parts.is_empty():
			continue
		var anchor: String = "%s_connect%d" % [anchor_base, action_index]
		var trigger_row: EventRowData = _build_connect_trigger_row(event_row, parts, anchor, indent, action_index)
		# Which menu a lambda answers is written on the CONNECT line, and nowhere inside the
		# lambda. Stamped for the length of the body walk, exactly as the verb kind is, and put back
		# afterwards so a lambda on anything else is untouched.
		var outer_menu: String = _current_menu_key
		_current_menu_key = EventSheetMenuFacts.connected_menu_key(
			connect_statement_of(event_row.actions[action_index]))
		# The body reads through the very same lift a declared handler's body goes through, so a
		# statement says the same thing whether it was written in a func or handed to connect.
		for body_event: Variant in EventSheetACELifter.lift_body_rows(
				parts.get("body", PackedStringArray()), _sheet_object_variable_names()):
			if not (body_event is EventRow):
				continue
			var body_row: EventRowData = _build_event_row(body_event as EventRow, indent + 1)
			_mark_connect_reading(body_row, event_row, anchor, action_index)
			trigger_row.children.append(body_row)
		_current_menu_key = outer_menu
		rows.append(trigger_row)
	return rows


## The sheet's variables that hold an OBJECT, handed to the lifter so a line in a lambda body reads
## the way the identical line in a declared handler does: `candidate == host` is an identity test,
## `i == 1` is a comparison, and only the declared type of `host` tells them apart.
func _sheet_object_variable_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var sheet: EventSheetResource = _viewport._sheet
	if sheet == null:
		return names
	for row: Variant in sheet.events:
		if not (row is LocalVariable):
			continue
		var type_name: String = (row as LocalVariable).type_name.strip_edges()
		if type_name.is_empty() or type_name in EventSheetACELifter.VALUE_TYPE_NAMES:
			continue
		names.append((row as LocalVariable).name)
	return names


## The lambda's parameter names - the payload the trigger hands its body.
static func payload_names(parts: Dictionary) -> PackedStringArray:
	return parts.get("args", PackedStringArray()) as PackedStringArray


## The trigger row itself: the ➜ badge, `<Object> On <Signal>`, and one chip per name the lambda gives
## what it is handed, so a reader knows what the event passes them without opening the code. The chips
## are the SHARED payload span a declared handler's trigger row uses - the same event has to read the
## same way whether it was wired with a func or with a lambda, and it used to read `On Hit   body`
## with the names crammed inside the trigger cell.
func _build_connect_trigger_row(event_row: EventRow, parts: Dictionary, anchor: String, indent: int,
		action_index: int) -> EventRowData:
	var trigger_row := EventRowData.new()
	trigger_row.indent = indent
	trigger_row.row_type = EventRowData.RowType.EVENT
	trigger_row.source_resource = event_row
	trigger_row.row_uid = "%s_trigger" % anchor
	trigger_row.ternary_view = true
	trigger_row.ternary_anchor_uid = anchor
	trigger_row.ternary_lead = true
	trigger_row.ternary_action_index = action_index
	trigger_row.line_count = 1
	var condition_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	var badge_meta: Dictionary = _viewport.BADGE_TRIGGER_METADATA.duplicate(true)
	var badge_glyph: String = _apply_trigger_tempo(badge_meta, _viewport._get_event_style(), "")
	badge_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)
	badge_meta["line_index"] = 0
	badge_meta["badge_style"] = "trigger"
	trigger_row.spans.append(_make_span(badge_glyph, SemanticSpan.SpanType.KEYWORD, badge_meta))
	# "trigger", not "condition": a trigger cell sizes to its words and leaves room for the payload
	# chips beside it, exactly as a declared handler's trigger row does.
	trigger_row.spans.append(_make_span(str(parts.get("trigger", "")), SemanticSpan.SpanType.CONDITION, {
		"lane": "condition",
		"kind": "trigger",
		"ace_index": -1,
		"chip": true,
		"editable": false,
		"hoverable": false,
		"line_index": 0,
		"object_label": str(parts.get("object", ""))
	}.merged(condition_style_meta, true)))
	var payload: PackedStringArray = payload_names(parts)
	for payload_index in range(payload.size()):
		trigger_row.spans.append(_trigger_payload_span(payload[payload_index].replace("_", " "), payload_index, 0))
	return trigger_row


## Stamps a lifted body row (and everything under it) as a READING of the connect statement: the
## resource it points at is the event the file holds, and the anchor uid is what makes the whole
## reading behave as that one statement rather than as rows of its own.
func _mark_connect_reading(row_data: EventRowData, event_row: EventRow, anchor: String,
		action_index: int) -> void:
	if row_data == null:
		return
	# Spans are normally built lazily FROM source_resource, and this row's source is about to become
	# the event the file holds rather than the lifted stand-in it was read from - so its cells are
	# built here, while the stand-in is still what it points at. A row that already has spans is
	# never rebuilt, which is exactly what keeps the reading and the routing from fighting.
	_ensure_event_spans(row_data)
	# A reading invites nothing: the "Every Tick" placeholder and the "+ Add" affordances are offers
	# to edit a row, and there is no row here to edit - only one connect statement, which is what a
	# double-click anywhere on this reading opens.
	var kept: Array[SemanticSpan] = []
	var lines: int = 1
	for span: SemanticSpan in row_data.spans:
		if bool(span.metadata.get("placeholder", false)):
			continue
		if str(span.metadata.get("kind", "")) in ["add_action", "add_condition"]:
			continue
		kept.append(span)
		lines = maxi(lines, int(span.metadata.get("line_index", 0)) + 1)
	row_data.spans = kept
	row_data.line_count = lines
	row_data.source_resource = event_row
	row_data.row_uid = "%s_%s" % [anchor, row_data.row_uid]
	row_data.ternary_view = true
	row_data.ternary_anchor_uid = anchor
	row_data.ternary_lead = false
	row_data.ternary_action_index = action_index
	for child: EventRowData in row_data.children:
		_mark_connect_reading(child, event_row, anchor, action_index)


# ── a signal wired to ANOTHER object's function reads as the trigger calling it ─────────────────
#
# `$Button.pressed.connect(player.reset)` and `$Timer.timeout.connect(spawner.spawn_wave.bind(3))`
# are the third way real code wires a signal, after a handler declared in this file and a lambda.
# The handler is not in this file at all, so there is nothing to lift - and the rows the thought
# deserves are ones the sheet already draws: the trigger event on the left, the call on the right,
# the bound values as ordinary parameter chips.
#
# A reading, like its two siblings: the file keeps its one line, that line keeps its muted note, and
# nothing here is ever emitted.


## The GDScript a connect-to-a-callable action stands for, whichever shape the open lifted it into.
## "" for a connect handed a lambda (that one reads as its own trigger with a body) and for a line
## that is not a connect at all - the substring test first, because that is the common case.
static func connect_call_statement_of(action_resource: Variant) -> String:
	if action_resource is RawCodeRow:
		var code: String = (action_resource as RawCodeRow).code
		if not code.contains(".connect(") or code.contains(".connect(func("):
			return ""
		return code
	if not (action_resource is ACEAction):
		return ""
	var action: ACEAction = action_resource as ACEAction
	if action.ace_id != "CallMethod":
		return ""
	var params_dict: Dictionary = action.params if not action.params.is_empty() else action.parameters
	var method: String = str(params_dict.get("method", ""))
	var arguments: String = str(params_dict.get("args", ""))
	if not method.ends_with("connect") or arguments.begins_with("func("):
		return ""
	return "%s.%s(%s)" % [str(params_dict.get("target", "")), method, arguments]


## Splits `$Timer.timeout.connect(spawner.spawn_wave.bind(3), CONNECT_ONE_SHOT)` into
## {object, trigger, target, method, args, one_shot}. {} for anything else - including a connect
## handed a bare function name of this file, which already reads as the trigger event it is where
## that function is written.
static func connect_call_parts(code: String) -> Dictionary:
	var text: String = code.strip_edges()
	if text.is_empty() or text.contains("\n"):
		return {}
	var marker: int = text.find(".connect(")
	if marker <= 0:
		return {}
	var head: String = text.substr(0, marker)
	var dot_at: int = head.rfind(".")
	if dot_at <= 0:
		return {}
	var signal_bare: String = head.substr(dot_at + 1)
	if not EventSheetSentence.is_identifier(signal_bare):
		return {}
	var object_word: String = _await_object_word(head.substr(0, dot_at))
	if object_word.is_empty():
		return {}
	var open_at: int = marker + 8  # the "(" of `.connect(`
	if _matching_paren(text, open_at) != text.length() - 1:
		return {}
	var arguments: PackedStringArray = split_top_level_arguments(
		text.substr(open_at + 1, text.length() - open_at - 2))
	if arguments.is_empty():
		return {}
	var callable_parts: Dictionary = connect_callable_parts(arguments[0])
	if callable_parts.is_empty():
		return {}
	var one_shot: bool = false
	for flag_index: int in range(1, arguments.size()):
		if arguments[flag_index].contains("CONNECT_ONE_SHOT"):
			one_shot = true
	var collision_words: String = EventSheetViewportReadingRows.collision_trigger_words(signal_bare)
	return {
		"object": object_word,
		"trigger": collision_words if not collision_words.is_empty() else "On %s" % signal_bare.capitalize(),
		"target": str(callable_parts.get("target", "")),
		"method": str(callable_parts.get("method", "")),
		"args": callable_parts.get("args", PackedStringArray()),
		"one_shot": one_shot
	}


## The callable handed to `connect`, as {target, method, args}: `player.reset`,
## `spawner.spawn_wave.bind(3)` and `Callable(spawner, "spawn_wave").bind(3)` all answer the same
## thing. {} for a lambda and for a bare name, which names a function of THIS file.
static func connect_callable_parts(expression: String) -> Dictionary:
	var text: String = expression.strip_edges()
	if text.is_empty() or text.begins_with("func("):
		return {}
	var bound: PackedStringArray = PackedStringArray()
	var bind_at: int = text.rfind(".bind(")
	if bind_at > 0:
		var bind_open: int = bind_at + 5
		if _matching_paren(text, bind_open) != text.length() - 1:
			return {}
		bound = split_top_level_arguments(text.substr(bind_open + 1, text.length() - bind_open - 2))
		text = text.substr(0, bind_at)
	if text.begins_with("Callable(") and text.ends_with(")"):
		var made: PackedStringArray = split_top_level_arguments(text.substr(9, text.length() - 10))
		if made.size() != 2:
			return {}
		var quoted: String = made[1].strip_edges().trim_prefix("&")
		if not (quoted.begins_with("\"") and quoted.ends_with("\"")):
			return {}
		var named: String = quoted.trim_prefix("\"").trim_suffix("\"")
		var made_target: String = _await_object_word(made[0])
		if made_target.is_empty() or not EventSheetSentence.is_identifier(named):
			return {}
		return {"target": made_target, "method": named, "args": bound}
	var method_at: int = text.rfind(".")
	if method_at <= 0:
		return {}
	var bare_method: String = text.substr(method_at + 1)
	if not EventSheetSentence.is_identifier(bare_method):
		return {}
	var target_word: String = _await_object_word(text.substr(0, method_at))
	if target_word.is_empty():
		return {}
	return {"target": target_word, "method": bare_method, "args": bound}


## An argument list split on its TOP-LEVEL commas, quote- and bracket-aware, so a bound string with a
## comma in it and a nested call both stay one argument.
static func split_top_level_arguments(text: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if text.strip_edges().is_empty():
		return out
	var depth: int = 0
	var in_string: bool = false
	var quote: String = ""
	var current: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if in_string:
			if character == "\\" and index + 1 < text.length():
				current += character + text[index + 1]
				index += 2
				continue
			if character == quote:
				in_string = false
		elif character == "\"" or character == "'":
			in_string = true
			quote = character
		elif character in ["(", "[", "{"]:
			depth += 1
		elif character in [")", "]", "}"]:
			depth -= 1
		elif character == "," and depth == 0:
			out.append(current.strip_edges())
			current = ""
			index += 1
			continue
		current += character
		index += 1
	out.append(current.strip_edges())
	return out


## "connects Button On Pressed" for a wired-up call, the same muted note a connected lambda's line
## keeps - the wiring stays written down where the file writes it.
func _connect_call_note(action_resource: Variant) -> Dictionary:
	if not _viewport.is_reading_mode():
		return {}
	return connect_call_parts(connect_call_statement_of(action_resource))


## One row per connect-to-a-callable in this event: the trigger event, with the call it makes in the
## action lane. Pure view - every row stands for the ONE connect statement the file holds, which is
## why it carries that statement's anchor uid.
func _build_connect_call_rows(event_row: EventRow, anchor_base: String, indent: int) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	if event_row == null or not _viewport.is_reading_mode():
		return rows
	for action_index in range(event_row.actions.size()):
		var parts: Dictionary = connect_call_parts(connect_call_statement_of(event_row.actions[action_index]))
		if parts.is_empty():
			continue
		var anchor: String = "%s_connectcall%d" % [anchor_base, action_index]
		rows.append(_build_connect_call_row(event_row, parts, anchor, indent, action_index))
	return rows


## The trigger event and the call it makes, on ONE row: the sheet's own two lanes say the whole
## thought. The bound values are ordinary parameter chips, named by the callee's own parameter names
## whenever the project or the engine declares them.
func _build_connect_call_row(event_row: EventRow, parts: Dictionary, anchor: String, indent: int,
		action_index: int) -> EventRowData:
	var trigger_parts: Dictionary = parts.duplicate()
	trigger_parts["args"] = PackedStringArray()
	var row_data: EventRowData = _build_connect_trigger_row(event_row, trigger_parts, anchor, indent, action_index)
	if bool(parts.get("one_shot", false)):
		# A one-shot connection fires once, which is the sheet's own Trigger once.
		row_data.spans.append(_trigger_payload_span(EventSheetL10n.translate("Trigger once"), 0, 0))
	var target_label: String = str(parts.get("target", ""))
	if target_label == "self":
		target_label = _script_object_name()
	var method_name: String = str(parts.get("method", ""))
	var parameter_names: PackedStringArray = EventSheetViewportReadingRows.project_method_parameter_names(
		EventSheetViewportReadingRows.class_of_object(target_label, _reading_class_map()), method_name)
	var pieces: Array = [
		[EventSheetL10n.translate("Call") + " ", "plain"],
		[EventSheetViewportLenses.function_display_name(method_name, ""), "name"]
	]
	var bound: PackedStringArray = parts.get("args", PackedStringArray()) as PackedStringArray
	for bound_index: int in range(bound.size()):
		var parameter_name: String = parameter_names[bound_index] if bound_index < parameter_names.size() else ""
		pieces.append(["   ", "plain"])
		pieces.append([EventSheetViewportLenses.call_argument_chip(
			parameter_name, bound[bound_index], _viewport.humanize_names_enabled()), "value"])
	var action_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_action_style())
	var sentence_text: String = ""
	var sentence_segments: Array[Dictionary] = []
	for piece: Array in pieces:
		var text: String = str(piece[0])
		sentence_text += text
		sentence_segments.append({
			"text": text,
			"color": _viewport._get_reading_style().primary_text_color if str(piece[1]) == "name" else null,
			"bold": str(piece[1]) == "name",
			"italic": false
		})
	row_data.spans.append(_make_span(sentence_text, SemanticSpan.SpanType.VALUE, {
		"lane": "action",
		"kind": "action",
		"ace_index": action_index,
		"ace_enabled": true,
		"chip": true,
		"editable": false,
		"code_cell": false,
		"line_index": 0,
		"object_label": target_label,
		"bbcode_segments": sentence_segments,
		"object_icon": _reading_class_icon_for(target_label)
	}.merged(action_style_meta, false)))
	return row_data


# ── a ternary reads as a sub-event pair, never a condition in an action cell ────────────────────


## Rewrites a list of sibling rows so a statement carrying a ternary reads the way an event sheet
## would show the same branch: the condition on the LEFT, the statement re-read on the RIGHT with that
## branch's value, then an `Else` row for the other one (an Else-if chain for a nested ternary).
##
## Recursive over children. A pure VIEW over unchanged resources: each row still points at the one
## statement the file holds, so hover shows the exact GDScript, double-click edits that line, and both
## emission and the byte round-trip are untouched. The rows a statement occupies DO change - which is
## why every row of a pair carries `ternary_anchor_uid`, the uid of the ONE statement row they all
## stand for. Selection, drag/drop, delete and the gutter key on it, so an EDITABLE sheet counts the
## pair once wherever it counts rows.
func expand_ternary_rows(rows: Array[EventRowData]) -> Array[EventRowData]:
	var out: Array[EventRowData] = []
	for row: EventRowData in rows:
		row.children = expand_ternary_rows(row.children)
		# Runs first: it REPLACES a loop row with the event its body reads as, and that event may
		# itself carry a ternary the pass below still has to see.
		var picked: Array[EventRowData] = _expand_picking_row(row)
		if not picked.is_empty():
			out.append_array(picked)
			continue
		out.append_array(_expand_ternary_row(row))
	return out


# ── a loop over a group with one `if` inside is event-sheet picking, and reads as one event ───────
#
# This is the event-sheet model: a condition on an object PICKS the instances, and the actions run
# on the ones it picked. Godot has no picking, so the same idea is spelled as a loop with an `if` in
# it - two rows for one thought. When the loop's ENTIRE body is that `if`, the pair reads as the one
# event it means: the loop's object with a muted note saying where the instances came from, the `if`
# as its condition, its body as the actions.
#
# A view over two unchanged rows. Both still sit in the sheet exactly as the file wrote them, so
# emission and the byte round-trip are untouched; every row produced carries the LOOP's uid as its
# statement uid, so selection, drag and the gutter address the whole reading as one. A body with any
# statement outside the `if` is not this shape and keeps the plain For-each + sub-event reading -
# there the loop really is doing something of its own.


## The rows a loop-with-one-`if` reads as, or [] when this row is not that shape.
func _expand_picking_row(row: EventRowData) -> Array[EventRowData]:
	if not _viewport.is_reading_mode() or row.ternary_view or not row.picking_object.is_empty():
		return []
	if row.row_type != EventRowData.RowType.EVENT or not (row.source_resource is EventRow):
		return []
	var loop: EventRow = row.source_resource as EventRow
	var words: Dictionary = _picking_words(loop)
	if words.is_empty() or row.children.is_empty() or row.children.size() != loop.sub_events.size():
		return []
	var shifted: Array[EventRowData] = []
	for child_index: int in range(row.children.size()):
		var child: EventRowData = row.children[child_index]
		if child.row_type != EventRowData.RowType.EVENT or not (child.source_resource is EventRow):
			return []
		if child.source_resource != loop.sub_events[child_index]:
			return []
		shifted.append(child)
	# The first sub-event must be the `if` itself, and the ones after it can ONLY be its own else / elif
	# arms. Two independent `if`s in a loop body are two conditions, not one - merging them would hoist
	# the second out of the loop it runs in, which is the one thing this reading must never say.
	if (shifted[0].source_resource as EventRow).conditions.is_empty():
		return []
	if (shifted[0].source_resource as EventRow).else_mode != EventRow.ElseMode.NONE:
		return []
	for arm_index: int in range(1, shifted.size()):
		if (shifted[arm_index].source_resource as EventRow).else_mode == EventRow.ElseMode.NONE:
			return []
	for shifted_index: int in range(shifted.size()):
		var moved: EventRowData = shifted[shifted_index]
		_shift_row_indent(moved, row.indent - moved.indent)
		moved.ternary_view = true
		moved.ternary_anchor_uid = row.row_uid
		moved.ternary_lead = shifted_index == 0
		moved.disabled = moved.disabled or row.disabled
	# Only the row that states the test wears the note: an Else arm has already been placed by it.
	shifted[0].picking_object = str(words.get("object", ""))
	shifted[0].picking_note = str(words.get("note", ""))
	shifted[0].spans.clear()
	return shifted


## Whether a loop is the picking shape, and the words for it: the object its body works on (the
## iterator's own name, which is what the body calls each instance) plus the muted note saying where
## the instances came from. {} for anything that is not one plain For-each over a list.
func _picking_words(loop: EventRow) -> Dictionary:
	if loop == null or not loop.conditions.is_empty() or not loop.actions.is_empty():
		return {}
	if not loop.local_variables.is_empty() or loop.sub_events.is_empty() or loop.pick_filters.size() != 1:
		return {}
	if not loop.trigger_id.is_empty() or loop.else_mode != EventRow.ElseMode.NONE:
		return {}
	var pick: PickFilter = loop.pick_filters[0]
	if pick == null or not pick.enabled or pick.iterator_name.strip_edges().is_empty():
		return {}
	# A filtered, ordered, capped, indexed or frame-spread loop is doing work of its own that the
	# merged row would not say; only a plain walk of a list reads as picking.
	if not pick.filter_conditions.is_empty() or not pick.predicate_expression.strip_edges().is_empty():
		return {}
	if not pick.order_by_expression.strip_edges().is_empty() or pick.pick_first_n != 0:
		return {}
	if not pick.index_name.strip_edges().is_empty() or pick.frame_spread_count != 0 or pick.frame_spread_budget_ms != 0.0:
		return {}
	# Repeat and While are counts and tests, not collections of instances - an event sheet spells those
	# with its own loop rows and never as picking.
	if pick.collection_kind == PickFilter.CollectionKind.REPEAT or pick.collection_kind == PickFilter.CollectionKind.WHILE:
		return {}
	var collection: String = pick.collection_value.strip_edges()
	if collection.is_empty():
		collection = pick.source_expression.strip_edges()
	var note: String = _picking_source_note(pick.collection_kind, collection)
	if note.is_empty():
		return {}
	return {"object": pick.iterator_name.strip_edges().capitalize(), "note": note}


## The muted note beside the picked object: which instances these are.
func _picking_source_note(collection_kind: int, collection: String) -> String:
	if collection_kind == PickFilter.CollectionKind.GROUP and not collection.is_empty():
		return "(%s %s)" % [EventSheetL10n.translate("group"), _quoted_group_name(collection)]
	var group_name: String = _group_name_in(collection)
	if not group_name.is_empty():
		return "(%s \"%s\")" % [EventSheetL10n.translate("group"), group_name]
	if collection == "get_children()":
		return "(%s)" % EventSheetL10n.translate("children")
	if collection.ends_with(".get_children()"):
		var owner_name: String = collection.substr(0, collection.length() - ".get_children()".length()).strip_edges()
		if _is_identifier_path(owner_name):
			return "(%s %s)" % [EventSheetL10n.translate("children of"), EventSheetSentence.object_of_reference(owner_name)]
	# Anything else has to be a NAMED list for this reading to be honest. `for i in 3:` is a count, and
	# an arbitrary expression is a computation - neither is a set of instances to pick from, and
	# labelling one "I (in 3)" says something the code never did.
	if _is_identifier_path(collection):
		return "(%s %s)" % [EventSheetL10n.translate("in"), EventSheetSentence.expression_text(collection)]
	return ""


## The group name inside `get_tree().get_nodes_in_group("enemies")`, or "" when the expression is
## anything else. Written out rather than pattern-matched loosely: a near-miss would label a list of
## something else as a group, which is worse than saying nothing.
static func _group_name_in(collection: String) -> String:
	var marker: String = "get_nodes_in_group(\""
	var start: int = collection.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var end: int = collection.find("\"", start)
	if end <= start or not collection.substr(end).begins_with("\")"):
		return ""
	return collection.substr(start, end - start)


## A GROUP pick stores its name either bare or already quoted; the note always shows it quoted.
static func _quoted_group_name(collection: String) -> String:
	var text: String = collection.strip_edges()
	if text.begins_with("\"") or text.begins_with("&\""):
		return text.trim_prefix("&")
	return "\"%s\"" % text


## `enemy's hp < 10` -> `hp < 10`, but ONLY when the possessive is the picked object's own name. A
## condition on some OTHER object inside the loop keeps its possessive, because there it is the thing
## that says which object is meant.
static func _strip_picked_possessive(text: String, picked_object: String) -> String:
	var at: int = text.find("'s ")
	if at <= 0:
		return text
	var owner_name: String = text.substr(0, at)
	if not EventSheetSentence.is_identifier(owner_name) or owner_name.capitalize() != picked_object:
		return text
	return text.substr(at + 3)


## The picked object and its note, written onto the first condition line once its spans exist.
## The cell keeps its own condition text; what changes is that it now reads as a condition ON an
## object, which is exactly what the loop around it was saying.
func _apply_picking_note(row_data: EventRowData) -> void:
	for span: SemanticSpan in row_data.spans:
		if str(span.metadata.get("lane", "")) != "condition" or int(span.metadata.get("line_index", 0)) != 0:
			continue
		if not str(span.metadata.get("kind", "")) in ["condition", "match_case"]:
			continue
		span.metadata["object_label"] = row_data.picking_object
		span.metadata["object_icon"] = _reading_class_icon_for(row_data.picking_object)
		var owned: String = _strip_picked_possessive(span.text, row_data.picking_object)
		if owned != span.text:
			# The object column already names the thing; "Enemy | enemy's hp < 10" says it twice, and
			# The event-sheet cell is just the property. Only the loop's OWN name is dropped.
			span.text = owned
			span.metadata.erase("bbcode_segments")
			span.metadata.erase("value_ranges")
		if not row_data.picking_note.is_empty():
			# The note is a receipt, not part of the test: muted, so the eye lands on the condition.
			# Written as segments because the styled runs behind the old text were measured against
			# offsets the note has just moved, and re-deriving those costs a re-read of the whole cell.
			span.metadata["bbcode_segments"] = [
				{"text": "%s " % row_data.picking_note, "color": _viewport._get_reading_style().muted_text_color, "bold": false, "italic": false},
				{"text": span.text, "color": null, "bold": false, "italic": false},
			]
			span.metadata.erase("value_ranges")
			span.text = "%s %s" % [row_data.picking_note, span.text]
		return


## One row's expansion: itself when nothing branches, else the actions before the branch, the branch
## rows, and - recursively, because a row may hold several branching statements - everything after.
func _expand_ternary_row(row: EventRowData) -> Array[EventRowData]:
	var single: Array[EventRowData] = [row]
	if row.row_type != EventRowData.RowType.EVENT or not (row.source_resource is EventRow):
		return single
	# An output of this pass would otherwise be branched again, forever.
	if row.ternary_view:
		return single
	var expanded: Array[EventRowData] = _expand_event_from(row, 0, row.indent, false)
	if expanded.size() == 1 and expanded[0] == row:
		return single
	# Exactly ONE row of a pair leads it: the head slice when it survived, otherwise the first branch
	# row. That row owns the event number, the breakpoint dot, the bookmark pennant and the trace hit
	# chip - the rest of the pair draws a bare gutter, because they are readings, not events.
	if not expanded.is_empty():
		expanded[0].ternary_lead = true
	return expanded


## The rows one event draws from `from_index` on. `hide_conditions` marks a CONTINUATION - the run of
## actions after a branch, whose conditions the row above already drew, and which an event sheet never
## repeats. Recursive, so a second branching statement further down the same event splits again.
func _expand_event_from(row: EventRowData, from_index: int, indent: int,
		hide_conditions: bool) -> Array[EventRowData]:
	var event_row: EventRow = row.source_resource as EventRow
	var continuation_uid: String = "%s_after%d" % [row.row_uid, from_index]
	var found: Dictionary = _first_ternary_action(event_row, from_index)
	if found.is_empty():
		if not hide_conditions and from_index == 0:
			return [row]
		var plain: EventRowData = _build_event_slice_row(row, from_index, -1, hide_conditions, continuation_uid)
		plain.indent = indent
		return [plain]
	var action_index: int = int(found.get("index", -1))
	var head_uid: String = row.row_uid if (not hide_conditions and from_index == 0) else continuation_uid
	# The branch as the event's FINAL action is the case that decides where the event's own comment
	# and "+ Add" affordances live: with no continuation to carry them they stay on the head, exactly
	# where they sat before the pair existed, rather than growing an empty row under every ternary.
	var branch_is_last: bool = action_index + 1 >= event_row.actions.size()
	var head: EventRowData = _build_event_slice_row(
		row, from_index, action_index, hide_conditions, head_uid, branch_is_last)
	head.indent = indent
	# The head vanishes only when it would draw NOTHING of its own - no conditions, no earlier
	# actions, no sub-events - which is exactly the one-line verb body (`ƒ Wall Normal X`) the pair
	# was designed for. Otherwise it survives and the branch rows become its sub-events, which is
	# both what an event sheet draws and what keeps the head's conditions gating them.
	var head_blank: bool = _slice_row_is_blank(head) and (hide_conditions or row.children.is_empty())
	var branch_indent: int = indent if head_blank else indent + 1
	var branch_rows: Array[EventRowData] = _build_ternary_branch_rows(
		row, action_index, found, branch_indent, str(action_index))
	if branch_rows.is_empty():
		# Nothing branched after all - the value looked like a pair and was not one, so the row goes
		# back unsplit. Built into a TYPED array one element at a time rather than returned as a
		# conditional literal: a conditional expression is an untyped Array whatever its arms hold, and
		# assigning one to the typed array the caller declares fails at RUNTIME - which leaves the caller
		# holding nothing and drops the whole event off the canvas without a word.
		var unsplit: Array[EventRowData] = []
		unsplit.append(row if (not hide_conditions and from_index == 0) else head)
		return unsplit
	var tail_rows: Array[EventRowData] = []
	if not branch_is_last:
		# Conditions, once hidden, stay hidden - an event sheet never repeats them further down the event.
		tail_rows = _expand_event_from(row, action_index + 1, branch_indent, true)
	elif head_blank and not _scaffolding_suppressed():
		# The one shape with nowhere left to put the scaffolding: a head that drew NOTHING (the one-line
		# verb body the pair was designed for) and no actions after the branch. An EDITABLE sheet grows a
		# bare continuation row under the pair, because otherwise this event could never be added to
		# again. Conditions are not hidden on it because a blank head means there were none to repeat.
		tail_rows = _expand_event_from(row, action_index + 1, branch_indent, false)
	if head_blank:
		var flattened: Array[EventRowData] = []
		flattened.append_array(branch_rows)
		flattened.append_array(tail_rows)
		return flattened
	var children: Array[EventRowData] = []
	children.append_array(branch_rows)
	children.append_array(tail_rows)
	if not hide_conditions:
		children.append_array(row.children)
	head.children = children
	return [head]


## The first action of `event_row` that carries a hoistable ternary, as {index, kind, param, text},
## or {} when none does. Both row shapes are asked the same question: a hand-written line through its
## own code (`kind` "code"), a lifted ACE through the PARAMETER whose value branches (`kind` "param")
## - so a ternary reads as the pair whether it was typed or picked.
func _first_ternary_action(event_row: EventRow, from_index: int = 0) -> Dictionary:
	for action_index in range(from_index, event_row.actions.size()):
		var action_resource: Variant = event_row.actions[action_index]
		if action_resource is RawCodeRow:
			var raw: RawCodeRow = action_resource as RawCodeRow
			# This pass now runs on EVERY sheet, editable ones included, so the overwhelmingly common
			# answer - "this line has no ternary" - must cost a substring search, not a parse.
			if not _may_branch(raw.code):
				continue
			if is_single_statement(raw.code) and not EventSheetSentence.ternary_branches(raw.code).is_empty():
				var code_found: Dictionary = {"index": action_index, "kind": "code", "param": "", "text": raw.code}
				if not _ternary_collapses(code_found):
					return code_found
			continue
		if not (action_resource is ACEAction):
			continue
		var action: ACEAction = action_resource as ACEAction
		var params_dict: Dictionary = action.params if not action.params.is_empty() else action.parameters
		for param_key: Variant in params_dict.keys():
			var value: String = str(params_dict[param_key])
			if not _may_branch(value):
				continue
			if EventSheetSentence.value_branches(value).is_empty():
				continue
			var param_found: Dictionary = {"index": action_index, "kind": "param", "param": str(param_key), "text": value}
			if _ternary_collapses(param_found):
				continue
			return param_found
	return {}


## The cheap "could this possibly branch" screen in front of the real grammar walk: a ternary is
## spelled `A if C else B`, so text without both words cannot be one. Pure substring work, run once
## per action per rebuild on every sheet in the editor. Deliberately looser than the grammar (it does
## not demand a space after `else`), because a false POSITIVE only costs the parse this saves, while a
## false negative would silently stop a real branch from reading as a pair.
func _may_branch(text: String) -> bool:
	return text.contains(" if ") and text.contains("else")


## A candidate whose arms come back empty, or whose ONE arm reproduces the value itself, has no
## branch a row could draw. It happens when the branch lives inside a bracketed group that is not
## itself a ternary - the arguments of a format list, say - so hoisting the group out of the value
## hands the whole value back unchanged; drawing that would put an Else under a row that never
## branches, and stepping into it would never end. Asked at the SCAN, not only at the split: a scan
## that stopped at such an action left every action after it undrawn, and a real pair later in the
## same event never split at all.
func _ternary_collapses(found: Dictionary) -> bool:
	var branches: Array = _ternary_arms(found)
	if branches.is_empty():
		return true
	var only_arm: String = str((branches[0] as Dictionary).get("code", ""))
	return branches.size() == 1 and only_arm == str(found.get("text", ""))


## The arms of one branching action - the statement's for a hand-written line, the parameter value's
## for a lifted row.
func _ternary_arms(found: Dictionary) -> Array:
	if str(found.get("kind", "")) == "param":
		return EventSheetSentence.value_branches(str(found.get("text", "")))
	return EventSheetSentence.ternary_branches(str(found.get("text", "")))


## The branch rows for one action: one per `A if C else B` arm, the last of them the `Else`. An arm
## whose text STILL carries a ternary (two independent ones in a line) nests its own pair beneath it
## rather than flattening, because that is where the second branch actually applies.
##
## Every arm AFTER the first is an else-if, and an event sheet spells an else-if as an Else event WITH a
## condition under it - two stacked condition cells on the one row. Drawing the arm's test alone would
## read as a sibling condition, i.e. as though both arms could fire.
func _build_ternary_branch_rows(row: EventRowData, action_index: int, found: Dictionary, indent: int,
		uid_path: String) -> Array[EventRowData]:
	if _ternary_collapses(found):
		return []
	var branches: Array = _ternary_arms(found)
	var rows: Array[EventRowData] = []
	for branch_index: int in branches.size():
		var branch: Dictionary = branches[branch_index]
		var branch_path: String = "%s_%d" % [uid_path, branch_index]
		var branch_row: EventRowData = _build_ternary_branch_row(
			row, indent, str(branch.get("condition", "")), branch_path, action_index, branch_index > 0)
		var arm: Dictionary = found.duplicate()
		arm["text"] = str(branch.get("code", ""))
		var nested: Array[EventRowData] = _build_ternary_branch_rows(
			row, action_index, arm, indent + 1, branch_path)
		if nested.is_empty():
			_append_branch_action_spans(branch_row, row, action_index, arm)
		else:
			branch_row.children.append_array(nested)
		rows.append(branch_row)
	return rows


## One branch row's shell plus its CONDITION cells - the branch test read through the grammar's
## condition path, or the plain `Else` chip on the last arm. `else_if` stacks an `Else` chip ABOVE
## that test on the same row, which is how an event sheet draws an else-if: one Else event carrying a
## condition, never two conditions that could both fire.
func _build_ternary_branch_row(row: EventRowData, indent: int, condition_text: String,
		uid_path: String, action_index: int, else_if: bool = false) -> EventRowData:
	var branch_row := EventRowData.new()
	branch_row.indent = indent
	branch_row.row_type = EventRowData.RowType.EVENT
	branch_row.source_resource = row.source_resource
	branch_row.row_uid = "%s_branch_%s" % [row.row_uid, uid_path]
	branch_row.disabled = row.disabled
	branch_row.in_verb_body = row.in_verb_body
	branch_row.verb_kind = row.verb_kind
	branch_row.ternary_view = true
	branch_row.ternary_anchor_uid = row.row_uid
	# The ONE line this whole pair reads. A double-click anywhere on the branch - the condition cell
	# and the plain Else included - opens that statement's own editor through it.
	branch_row.ternary_action_index = action_index
	branch_row.line_count = 1
	var condition_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	if condition_text.strip_edges().is_empty():
		branch_row.spans.append(_make_span(EventSheetL10n.translate("Else"), SemanticSpan.SpanType.CONDITION, {
			"lane": "condition",
			"kind": "else_keyword",
			"chip": true,
			"hoverable": false,
			"line_index": 0,
			"object_label": _object_label_for("Core", "")
		}.merged(condition_style_meta, true)))
		return branch_row
	# The else-if's first condition LINE is the Else chip itself; the arm's own test lands on the
	# second, exactly where an event's second condition sits. Same chip the final arm gets, so a chain
	# reads Else / Else / Else down its left edge with the tests that narrow each one beside them.
	var condition_line: int = 0
	if else_if:
		branch_row.spans.append(_make_span(EventSheetL10n.translate("Else"), SemanticSpan.SpanType.CONDITION, {
			"lane": "condition",
			"kind": "else_keyword",
			"chip": true,
			"hoverable": false,
			"line_index": 0,
			"object_label": _object_label_for("Core", "")
		}.merged(condition_style_meta, true)))
		condition_line = 1
		branch_row.line_count = 2
	_append_conjunct_condition_lines(branch_row, condition_text, condition_line, condition_style_meta)
	return branch_row


## The branch test as CONDITION LINES, never as one cell spelling `and`. An event sheet has no word
## for "and": each conjunct is a condition of the one event, stacked, and an `or` is the OR block. This
## is the same shape the lifted `if a and b:` already draws, applied to the readings the grammar
## invents, so a test says the same thing however the row got here. Precedence follows GDScript, where
## `or` binds loosest: a top-level ` or ` splits FIRST into OR-marked lines, and only a pure-AND test
## splits on ` and `. A mixed `a and (b or c)` therefore stacks `a` and keeps the parenthesised group
## whole on its own line - a line cannot hold a nested OR block, and inventing one would say something
## the source does not.
func _append_conjunct_condition_lines(branch_row: EventRowData, condition_text: String,
		first_line: int, condition_style_meta: Dictionary) -> void:
	# ── lens hook ──────────────────────────────────────────────────────────────────────────────
	# Some questions are ONE question written as two terms: a range (`x >= 0 and x <= width`), an
	# angle window, a pair of layout edges (`x < 0 or x > width`). The sheet has one condition for
	# each of those, so they are claimed BEFORE the run is split - after the split each half would
	# stack as its own comparison and say twice what the author asked once.
	var whole: Dictionary = EventSheetSentence.joined_condition(condition_text, sentence_context())
	if not whole.is_empty():
		var whole_pieces: Array = []
		for segment: Variant in (whole.get("segments", []) as Array):
			var whole_segment: Dictionary = segment
			whole_pieces.append([str(whole_segment.get("text", "")), str(whole_segment.get("tone", "plain"))])
		_append_one_condition_line(branch_row, str(whole.get("object", "")), whole_pieces,
			first_line, condition_style_meta)
		return
	var terms: PackedStringArray = EventSheetSentence.split_top_level(condition_text, " or ")
	var or_block: bool = terms.size() > 1
	if not or_block:
		terms = EventSheetSentence.split_top_level(condition_text, " and ")
	var line_index: int = first_line
	for term: String in terms:
		if term.strip_edges().is_empty():
			continue
		# The same "or" divider an authored OR event draws, so a lifted `a or b` and an OR block
		# the user built read alike. Above every line but the first: nothing sits above that one.
		if or_block and line_index > first_line:
			branch_row.or_condition_lines.append(line_index)
		# ── lens hook ──────────────────────────────────────────────────────────────────────────
		# A test written on an autoload's member belongs to that autoload: `Game.score > 100` reads
		# as the object `Game (global)` and the test `score > 100`, so the owner is visible in the
		# object column instead of buried in the sentence. The term is
		# re-attributed BEFORE the grammar reads it, so the grammar never sees a receiver it would
		# have to spell out possessively.
		var global_term: Dictionary = EventSheetViewportReadingRows.global_condition(term, _reading_autoloads())
		var read_term: String = str(global_term.get("text", term)) if not global_term.is_empty() else term
		var reading: Dictionary = EventSheetSentence.condition_pieces(read_term, sentence_context())
		# A question can be a pattern too - a tile's own data is asked in one condition.
		_note_pattern(str(reading.get("pattern", "")), term)
		var condition_object: String = str(global_term.get("object", "")) if not global_term.is_empty() \
			else str(reading.get("object", ""))
		_append_one_condition_line(branch_row, condition_object, reading.get("pieces", []) as Array,
			line_index, condition_style_meta, not global_term.is_empty())
		line_index += 1
	branch_row.line_count = maxi(branch_row.line_count, line_index)


## ONE condition line of a branch row, from the grammar's [[text, tone], ...] pieces. Shared by the
## conjunct path and the whole-run readings above it, so a line says the same thing and behaves the
## same way however the reading was claimed.
func _append_one_condition_line(branch_row: EventRowData, condition_object: String, pieces: Array,
		line_index: int, condition_style_meta: Dictionary, global_object: bool = false) -> void:
	var spelled: Array = EventSheetViewportLenses.apply_to_pieces(
		pieces, _viewport.humanize_names_enabled(), _export_knob_names())
	var condition_cell: Dictionary = _tone_segments(spelled)
	branch_row.spans.append(_make_span(str(condition_cell.get("text", "")), SemanticSpan.SpanType.CONDITION, {
		"lane": "condition",
		# "condition" is what makes the cell FILL its lane and wrap like every other condition cell
		# (the layout gates both on this kind) - so a long branch test grows the row instead of
		# clipping. There is no ACECondition behind it, so the index is -1 and the cell is inert:
		# nothing may index the event's condition list from a reading the grammar invented.
		"kind": "condition",
		"ace_index": -1,
		"chip": true,
		"editable": false,
		"hoverable": false,
		"line_index": line_index,
		"object_label": condition_object,
		"object_icon": EventSheetViewportReadingRows.autoload_icon() if global_object \
			and _viewport.show_object_icons else null,
		"bbcode_segments": condition_cell.get("segments", [])
	}.merged(condition_style_meta, true)))


## The branch's ACTION cell: the whole action re-read with this arm's value in place of the ternary,
## through the very same path the unbranched row uses - a hand-written line through the sentence
## layer, a lifted row through its own display descriptor - so the two readings cannot drift. The cell
## keeps the ORIGINAL action's index, which is what makes hover show the exact source line and
## double-click open that one statement.
func _append_branch_action_spans(branch_row: EventRowData, row: EventRowData, action_index: int,
		arm: Dictionary) -> void:
	var action_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_action_style())
	var event_row: EventRow = row.source_resource as EventRow
	var source_action: Variant = event_row.actions[action_index] if action_index < event_row.actions.size() else null
	var spans: Array = []
	var outer_kind: int = _verb_kind_override
	_verb_kind_override = row.verb_kind
	if str(arm.get("kind", "")) == "param" and source_action is ACEAction:
		_append_branch_ace_spans(spans, source_action as ACEAction, str(arm.get("param", "")),
			str(arm.get("text", "")), action_index, action_style_meta)
	else:
		var synthetic := RawCodeRow.new()
		synthetic.code = str(arm.get("text", ""))
		synthetic.enabled = true
		if not _append_sentence_spans(spans, synthetic, action_index, 0, action_style_meta):
			spans.append(_make_span(str(arm.get("text", "")).strip_edges(), SemanticSpan.SpanType.VALUE, {
				"lane": "action",
				"kind": "action",
				"ace_index": action_index,
				"chip": true,
				"code_cell": false,
				"line_index": 0
			}.merged(action_style_meta, false)))
		for span: SemanticSpan in spans:
			span.metadata["raw_action"] = source_action is RawCodeRow
	_verb_kind_override = outer_kind
	for span: SemanticSpan in spans:
		span.metadata["line_index"] = 0
		branch_row.spans.append(span)


## One lifted row re-rendered with a single parameter swapped for this arm's value, through the very
## same two shapes the unbranched row uses - a Local Variable row stays a DECLARATION, everything else
## reads as its display sentence. The copy is a DISPLAY copy and never leaves this function: the sheet
## still holds the one action the file wrote.
func _append_branch_ace_spans(spans: Array, action: ACEAction, param_key: String, value: String,
		action_index: int, action_style_meta: Dictionary) -> void:
	var branch_action: ACEAction = action.duplicate(true) as ACEAction
	if not branch_action.params.is_empty():
		branch_action.params[param_key] = value
	else:
		branch_action.parameters[param_key] = value
	var declaration: Dictionary = grammar_action_declaration(branch_action)
	if not declaration.is_empty():
		append_local_declaration_spans(spans, declaration, {
			"lane": "action",
			"kind": "action",
			"ace_index": action_index,
			"ace_enabled": action.enabled,
			"line_index": 0
		}, action_style_meta)
		return
	spans.append(_make_span(_format_action_descriptor(branch_action), SemanticSpan.SpanType.ACTION, {
		"lane": "action",
		"kind": "action",
		"ace_index": action_index,
		"ace_enabled": action.enabled,
		"chip": true,
		"line_index": 0,
		"object_label": _object_label_or_pending(action.provider_id, action.ace_id),
		"object_icon": _object_icon_for(action.provider_id, action.ace_id),
		"swatch_color": _first_color_in_params(action)
	}.merged(action_style_meta, true)))


## One slice of an event as its own row: same resource, same verb context, its own action range.
func _build_event_slice_row(row: EventRowData, slice_from: int, slice_to: int,
		hide_conditions: bool, uid: String, slice_is_tail: bool = false) -> EventRowData:
	var slice_row := EventRowData.new()
	slice_row.indent = row.indent
	slice_row.row_type = EventRowData.RowType.EVENT
	slice_row.source_resource = row.source_resource
	slice_row.row_uid = uid
	slice_row.disabled = row.disabled
	slice_row.in_verb_body = row.in_verb_body
	slice_row.verb_kind = row.verb_kind
	slice_row.language_block = row.language_block
	slice_row.error_message = row.error_message
	slice_row.attention_note = row.attention_note
	slice_row.attention_findings = row.attention_findings
	slice_row.successor_hint = row.successor_hint
	slice_row.ternary_view = true
	slice_row.ternary_anchor_uid = row.row_uid
	slice_row.action_slice_from = slice_from
	slice_row.action_slice_to = slice_to
	slice_row.conditions_hidden = hide_conditions
	slice_row.action_slice_tail = slice_is_tail
	var outer_kind: int = _verb_kind_override
	_verb_kind_override = row.verb_kind
	slice_row.spans = _build_event_spans(
		row.source_resource as EventRow, row.in_verb_body, slice_from, slice_to, hide_conditions,
		slice_is_tail)
	_verb_kind_override = outer_kind
	var lines: int = 1
	for span: SemanticSpan in slice_row.spans:
		lines = maxi(lines, int(span.metadata.get("line_index", 0)) + 1)
	slice_row.line_count = lines
	return slice_row


## True when a slice draws nothing a reader would see - the case where keeping the row would put an
## empty two-lane strip above the branch rows.
func _slice_row_is_blank(row: EventRowData) -> bool:
	for span: SemanticSpan in row.spans:
		if str(span.metadata.get("kind", "")) in ["add_action", "add_condition"]:
			continue
		if not span.text.strip_edges().is_empty():
			return false
	return true


## Tone pieces -> {text, segments}: the same tinting `_append_sentence_spans` gives a hand-written
## sentence, so a branch cell reads exactly like the line it was hoisted out of. Segments are built
## DIRECTLY (never through the BBCode parser), because condition text is full of square brackets.
func _tone_segments(pieces: Array) -> Dictionary:
	var text: String = ""
	var segments: Array[Dictionary] = []
	for piece: Variant in pieces:
		var pair: Array = piece
		var piece_text: String = str(pair[0])
		text += piece_text
		var tone_color: Variant = null
		var tone_bold: bool = false
		match str(pair[1]):
			"name":
				tone_color = _viewport._get_reading_style().primary_text_color
				tone_bold = true
			"value":
				tone_color = _viewport._get_event_style().value_highlight_color
			"object":
				tone_color = _viewport._get_event_style().object_label_color
			"muted":
				# A connective the sentence needs but the reader does not read ("then").
				tone_color = _viewport._get_reading_style().muted_text_color
		segments.append({"text": piece_text, "color": tone_color, "bold": tone_bold, "italic": false})
	return {"text": text, "segments": segments}


## One slice of an event's finished spans. Filtering the WHOLE build - rather than teaching the
## span pass to skip actions - is what keeps a sliced row's cells identical to the unsliced ones, down
## to the style metadata; only which cells survive, and which line each lands on, changes here.
func _slice_event_spans(spans: Array[SemanticSpan], event_row: EventRow, slice_from: int,
		slice_to: int, hide_conditions: bool, slice_is_tail: bool = false) -> Array[SemanticSpan]:
	var kept: Array[SemanticSpan] = []
	var used_lines: Array[int] = []
	for span: SemanticSpan in spans:
		var lane: String = _viewport._resolve_span_lane(span)
		if lane == "condition":
			if hide_conditions:
				continue
			kept.append(span)
			continue
		var ace_index: int = int(span.metadata.get("ace_index", -1))
		if ace_index < 0:
			# The event comment and the "+ Add action" affordance belong to the event as a whole, so
			# they ride the slice the reader's eye finishes the event on - the continuation after the
			# last branch, or the head itself when the branch was the event's final action.
			if not slice_is_tail and slice_to >= 0 and slice_to < event_row.actions.size():
				continue
		elif ace_index < slice_from or (slice_to >= 0 and ace_index >= slice_to):
			continue
		var line_index: int = int(span.metadata.get("line_index", 0))
		if not used_lines.has(line_index):
			used_lines.append(line_index)
		kept.append(span)
	used_lines.sort()
	var out: Array[SemanticSpan] = []
	for span: SemanticSpan in kept:
		if _viewport._resolve_span_lane(span) == "condition":
			out.append(span)
			continue
		var moved := SemanticSpan.new()
		moved.text = span.text
		moved.type = span.type
		moved.hoverable = span.hoverable
		moved.metadata = span.metadata.duplicate(true)
		moved.metadata["line_index"] = used_lines.find(int(span.metadata.get("line_index", 0)))
		out.append(moved)
	return out


## Builds an event row's spans on demand. Event-row spans are deferred (see
## _build_event_row) so large sheets load fast; this is called from the row layout
## choke point and selection paths before any span data is read. Idempotent: built
## spans are never empty (a "+ Add" span is always present), so is_empty() reliably
## means "not yet built".
func _ensure_event_spans(row_data: EventRowData) -> void:
	if row_data == null or row_data.row_type != EventRowData.RowType.EVENT:
		return
	if not row_data.spans.is_empty():
		return
	# An INERT row - a published verb's body, rendered for reading and addressable by nothing - has
	# given its editing pointer up and keeps a reading one. Taking it here is what lets those rows
	# stay lazy like every other: they used to have their words built the moment they were made
	# inert, which on a long file was every row of it whether anyone ever scrolled to it.
	var event: EventRow = row_data.source_resource as EventRow
	if event == null:
		event = row_data.reading_resource as EventRow
	if event != null:
		# Spans are built LAZILY, long after the walk that knew which published verb owns this row - so
		# the row carries the answer and puts it back for the duration of the build. Both halves of
		# it: the KIND (a `return` in a condition answers yes or no) and the verb itself (a `return`
		# in one of the editor's own callbacks answers that callback's question).
		var outer_kind: int = _verb_kind_override
		var outer_verb: EventFunction = _current_verb_function
		_verb_kind_override = row_data.verb_kind
		if row_data.verb_function is EventFunction:
			_current_verb_function = row_data.verb_function as EventFunction
		_pending_grammar_breakpoint = false
		_pending_patterns = {}
		row_data.spans = _build_event_spans(event, row_data.in_verb_body,
			row_data.action_slice_from, row_data.action_slice_to, row_data.conditions_hidden,
			row_data.action_slice_tail)
		row_data.spans = _split_function_reference_spans(row_data.spans)
		# Which condition lines carry an "or" above them. A sliced row hides its conditions, so
		# it keeps none: there is nothing left to divide.
		row_data.or_condition_lines = PackedInt32Array() if row_data.conditions_hidden else _pending_or_lines
		# The patterns those readings recognised, claimed on the event that OWNS them - the trigger,
		# function or tick the shape hangs off. Everything that talks about patterns reads the
		# registry; nothing re-derives them.
		_claim_pending_patterns(row_data)
		# A row holding a bare `breakpoint` wears the gutter dot. OR-ed in, never assigned, so a
		# user's own breakpoint on the same row is not cleared by a rebuild.
		if _pending_grammar_breakpoint:
			row_data.breakpoint_enabled = true
			_pending_grammar_breakpoint = false
		_verb_kind_override = outer_kind
		_current_verb_function = outer_verb
		if not row_data.picking_object.is_empty():
			_apply_picking_note(row_data)


## The ƒ chip a row ends with is a LINK: a function held as a value names a function this sheet
## declares, and a reader who sees its name wants to be at it. So the chip is split off the sentence
## into a span of its own carrying the raw name, which the click handler jumps to.
##
## Only a TRAILING chip is split - "Set open sheet to ƒ Open Sheet In Workspace" ends with the one
## thing being named - because splitting mid-sentence would reorder the runs a cell was measured
## with. Every other span comes back exactly as it went in, including a sentence that merely mentions
## a function somewhere in the middle.
func _split_function_reference_spans(spans: Array[SemanticSpan]) -> Array[SemanticSpan]:
	var context: Dictionary = sentence_context()
	if (context.get("function_params", {}) as Dictionary).is_empty():
		return spans
	var split: Array[SemanticSpan] = []
	for span: SemanticSpan in spans:
		var at: int = span.text.rfind(EventSheetSentence.FUNCTION_MARK)
		if at < 0 or str((span.metadata as Dictionary).get("kind", "")) == "function_ref":
			split.append(span)
			continue
		var chip_text: String = span.text.substr(at)
		var name: String = EventSheetSentence.function_reference_name(chip_text, context)
		if name.is_empty():
			split.append(span)
			continue
		var chip_meta: Dictionary = (span.metadata as Dictionary).duplicate(true)
		chip_meta["kind"] = "function_ref"
		chip_meta["name"] = name
		chip_meta["editable"] = false
		chip_meta["natural_width"] = true
		chip_meta["object_label"] = ""
		chip_meta["bbcode_segments"] = _segments_slice(span, at, span.text.length())
		if at > 0:
			var head_meta: Dictionary = (span.metadata as Dictionary).duplicate(true)
			# Both halves size to their own text: a head span that still filled the whole cell would
			# push the chip past the cell's right edge, where nothing is ever painted.
			head_meta["natural_width"] = true
			var head: SemanticSpan = _make_span(span.text.substr(0, at), span.type, head_meta)
			head.metadata["bbcode_segments"] = _segments_slice(span, 0, at)
			split.append(head)
			chip_meta.erase("compiled_lines")
			chip_meta.erase("create_object_indices")
		var chip: SemanticSpan = _make_span(chip_text, span.type, chip_meta)
		split.append(chip)
	return split


## The styled runs of a span between two character offsets, so a split cell keeps the very pixels it
## had. A span with no runs of its own answers with none, and is painted in its span type's colour
## exactly as it was before.
func _segments_slice(span: SemanticSpan, from: int, to: int) -> Array:
	var segments: Array = (span.metadata as Dictionary).get("bbcode_segments", []) as Array
	if segments.is_empty():
		return []
	var sliced: Array = []
	var cursor: int = 0
	for entry: Variant in segments:
		var segment: Dictionary = entry
		var text: String = str(segment.get("text", ""))
		var start: int = cursor
		cursor += text.length()
		var take_from: int = maxi(from, start)
		var take_to: int = mini(to, cursor)
		if take_to <= take_from:
			continue
		var part: Dictionary = segment.duplicate(true)
		part["text"] = text.substr(take_from - start, take_to - take_from)
		sliced.append(part)
	return sliced


func _append_condition_prefix_spans(
	spans: Array[SemanticSpan],
	event_row: EventRow,
	condition: ACECondition,
	condition_index: int,
	line_index: int,
	display_index: int,
	displayed_condition_count: int
) -> void:
	if event_row == null:
		return
	var condition_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	# Keep the primary badge column stable for trigger/invert/OR by rendering
	# negation first. When a line has both badges, the denial is placed in column 1
	# and OR follows in column 2.
	# A comparison with a clean opposite already reads as the opposite, so it wears no denial
	# mark: two marks for one fact is how a reader ends up unwrapping the row in their head.
	if (condition.negated and not _comparison_flips(condition)) or _condition_reads_negated(condition):
		spans.append(_negated_badge_span(condition_style_meta, line_index, condition_index))
	# The word "or" is drawn BETWEEN two conditions, not badged onto the second one: an event
	# sheet has no word for "and", so the only thing worth saying about a stack of questions is when
	# any one of them is enough. The first condition has nothing above it to divide from.
	if (
		event_row.condition_mode == EventRow.ConditionMode.OR
		and displayed_condition_count > 1
		and display_index > 0
	):
		_pending_or_lines.append(line_index)


## The inverted-condition mark: the word `not`, in the badge column, in the invert colour
## and with no plate behind it (themable via EventSheetEventStyle.invert_marker_color). ONE factory,
## because the mark has two producers - an ACE condition with its `negated` flag, and a lifted
## `if not <cond>:` whose sentence dropped the word - and they must draw the identical mark or the
## sheet teaches two symbols for one idea. It is a WORD rather than a glyph because this is the case
## with no opposite to show instead ("not begins with"), and a reader should not have to be taught a
## symbol to read the commonest thing a condition can say about itself.
func _negated_badge_span(condition_style_meta: Dictionary, line_index: int, condition_index: int = -1) -> SemanticSpan:
	var negated_meta: Dictionary = _viewport.BADGE_NEGATED_METADATA.duplicate(true)
	negated_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)
	negated_meta["condition_index"] = condition_index
	negated_meta["line_index"] = line_index
	negated_meta["badge_style"] = "negated"
	negated_meta["badge_bg"] = Color(0.0, 0.0, 0.0, 0.0)
	negated_meta["badge_fg"] = _viewport._get_event_style().invert_marker_color
	return _make_span(NEGATED_MARK, SemanticSpan.SpanType.KEYWORD, negated_meta)


func _measure_span_width(span: SemanticSpan, display_text: String, font: Font, font_size: int) -> float:
	if span == null:
		return 0.0
	var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
	var font_size_delta: int = int(metadata.get("font_size_delta", 0))
	var horizontal_padding: float = float(metadata.get("padding_x", 0.0))
	var draw_font_size: int = EventSheetPalette.resolve_font_size(font_size, font_size_delta)
	if bool(metadata.get("group_title", false)):
		# Group titles are drawn one size larger by the renderer; match it so the measured
		# box is wide enough and the name is not clipped.
		draw_font_size = EventSheetPalette.resolve_font_size(draw_font_size, 0, 1)
	var span_width: float = font.get_string_size(display_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x
	# A code echo is drawn segment by segment, and the per-segment advances do not add up to the
	# measurement of the whole string (kerning is lost at every seam). It has to reserve what the
	# renderer will actually advance, or the last characters of the declaration clip away.
	if bool(metadata.get("code_echo", false)):
		span_width = 0.0
		for segment: Variant in (metadata.get("bbcode_segments", []) as Array):
			span_width += font.get_string_size(
				str((segment as Dictionary).get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size
			).x
	var object_label: String = str(metadata.get("object_label", ""))
	if not object_label.is_empty():
		# Fixed object column (event-sheet sub-lane): the label occupies exactly the column width;
		# flow mode occupies the label's own width. Must mirror the renderer's advance.
		var measured_lane: String = str(metadata.get("lane", ""))
		var object_column_width: float = EventRowRenderer.object_column_width_for(_viewport._get_event_style(), measured_lane, _viewport.lane_width_for(measured_lane))
		if object_column_width > 0.0:
			# The layout stamps the aligned per-span column (the shared-separator rule); the
			# measured advance must match the DRAWN advance or natural chips lose text room.
			var measured_aligned: Variant = metadata.get("object_column_px")
			if measured_aligned is float and is_equal_approx(float(metadata.get("object_column_base", -1.0)), object_column_width):
				object_column_width = measured_aligned
			span_width += object_column_width
		else:
			span_width += font.get_string_size(object_label + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, draw_font_size).x
	if metadata.get("object_icon") is Texture2D:
		span_width += EventRowRenderer.OBJECT_ICON_ADVANCE
	if metadata.get("swatch_color") is Color:
		# The swatch draws just past the span's text, so the span has to OWN that room; without it
		# the next span starts under the swatch and loses its first character. Mirrors the
		# renderer's gap + box exactly, which is why the size lives in one place.
		span_width += EventRowRenderer.swatch_advance_for(draw_font_size)
	if bool(metadata.get("badge", false)):
		# A MARK badge states its box outright: its art is a drawn glyph, not text, so measuring the
		# font would size the cue by whichever fallback glyph happened to exist.
		var fixed_badge_width: float = float(metadata.get("badge_fixed_width", 0.0))
		if fixed_badge_width > 0.0:
			return fixed_badge_width
		span_width += max(float(metadata.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)), 0.0)
		span_width += horizontal_padding * 2.0
	elif bool(metadata.get("chip", false)):
		span_width += max(horizontal_padding * 2.0, _viewport.CHIP_EXTRA_WIDTH)
	return span_width

# ── Descriptor / format / classify (per-ACE display text + trigger/function classification) ───────


## Display text for a pick-filter row: "For each item in group \"enemies\" (first 3)".
## Chip text for a "With node X:" scope (the row's actions act on this node).
func _format_with_node(event_row: EventRow) -> String:
	return "With node  %s" % event_row.with_node_target.strip_edges()


## The expression a pick filter loops over, with the legacy spelling as the fallback. One helper so
## the loop's own text and its reading can never disagree about what the loop walks.
func _pick_collection_text(pick: PickFilter) -> String:
	var collection: String = pick.collection_value.strip_edges()
	return collection if not collection.is_empty() else pick.source_expression.strip_edges()


## The collection a loop walks, with the editor's own expressions named: a tool's
## `for n in EditorInterface.get_selection().get_selected_nodes()` is a For each over
## Editor.SelectedObjects, and reading it as the engine call spells out plumbing nobody wrote.
func _pick_collection_words(pick: PickFilter) -> String:
	return EventSheetSentence.editor_words(_pick_collection_text(pick))


## The lines a loop row RUNS, in file order - what lets the loop head say what the loop is for.
## The row's own actions, because that is where a ring loop's share-of-a-turn line is written; a
## sub-event under the loop is a loop of its own and answers for itself.
func _loop_body_lines(event_row: EventRow) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if event_row == null:
		return lines
	for action_entry: Variant in event_row.actions:
		EventSheetViewportReadingRows.append_body_lines(action_entry, lines)
	return lines


## True when this event runs every frame AND the sheet is a @tool script - the one combination
## where the event is already running while the reader looks at it. Static-ish by construction: it
## asks the sheet for its tool flag and the trigger for its tempo, so a test can pin the same answer
## the chip is drawn from.
func _ticks_in_the_editor(event_row: EventRow) -> bool:
	if event_row == null or _viewport == null or _viewport._sheet == null:
		return false
	if not bool(_viewport._sheet.get("tool_mode")):
		return false
	# The GAME ticks only. An Editor trigger already says it belongs to the editor in its own name, so
	# a chip there would repeat the row rather than add to it. A BLANK event counts: it runs every
	# tick, which is exactly the tempo this chip is about.
	return INPUT_TRIGGER_TICKS.has(TriggerResolver.effective_trigger_id(event_row))


## The pick sentence for a filter that narrows a family, or {} when this loop walks everything
## (which is a For each, and reads as one). Only a GROUP collection is a family: the group name IS
## the family name an event sheet puts in the object column, and there is nothing to name for a loop
## over an arbitrary expression.
func _pick_filter_reading(pick: PickFilter) -> Dictionary:
	if pick == null or pick.collection_kind != PickFilter.CollectionKind.GROUP:
		return {}
	return EventSheetViewportReadingRows.pick_words(_pick_collection_text(pick), _pick_test_text(pick),
		pick.order_by_expression, pick.order_descending, pick.pick_first_n)


## What a pick FILTERS on, as one line: the legacy predicate expression when the filter carries
## one, else its structured filter conditions joined the way they compile (AND or OR). Read through
## the same operator glyphs a condition row uses, so `hp < 10` looks the same wherever it is shown.
func _pick_test_text(pick: PickFilter) -> String:
	var predicate: String = pick.predicate_expression.strip_edges()
	if not predicate.is_empty():
		return EventSheetSentence.comparison_symbols(predicate)
	var terms: PackedStringArray = PackedStringArray()
	for entry: Variant in pick.filter_conditions:
		if not (entry is ACECondition) or not (entry as ACECondition).enabled:
			continue
		# An inverted comparison shows its opposite here too, exactly as it does on a condition row
		# and exactly as the filter compiles - one spelling of the same question everywhere.
		var reading: ACECondition = _comparison_flip_of(entry as ACECondition)
		var term: String = SheetCompiler.condition_source_text(reading).strip_edges()
		if term.is_empty():
			continue
		terms.append("%s %s" % [EventSheetL10n.translate("not"), term] if reading.negated else term)
	if terms.is_empty():
		return ""
	var joiner: String = " %s " % EventSheetL10n.translate("or" if pick.filter_mode == 1 else "and")
	return EventSheetSentence.comparison_symbols(joiner.join(terms))


func _format_pick_filter(pick: PickFilter) -> String:
	var iterator: String = pick.iterator_name.strip_edges()
	if iterator.is_empty():
		iterator = "item"
	var collection: String = _pick_collection_words(pick)
	# ── lens hook ──────────────────────────────────────────────────────────────────────────────
	# A loop over what an area is touching is the sheet's own "For each ... overlapping ..." row -
	# the same words the Is overlapping condition beside it uses, rather than the engine call that
	# hands the list back.
	var overlapped: String = EventSheetSentence.overlap_collection_source(collection)
	if not overlapped.is_empty():
		return "%s %s %s %s" % [EventSheetL10n.translate("For each"), iterator,
			EventSheetL10n.translate("overlapping"), overlapped]
	var source_text: String = collection
	match pick.collection_kind:
		PickFilter.CollectionKind.GROUP:
			source_text = "group \"%s\"" % collection
		PickFilter.CollectionKind.CHILDREN:
			source_text = "children"
		PickFilter.CollectionKind.REPEAT:
			return "Repeat %s times" % collection
		PickFilter.CollectionKind.WHILE:
			# ── lens hook ──────────────────────────────────────────────────────────────────
			# A folder walk is written as a `while` over a local that `get_next()` keeps filling,
			# and what the four lines MEAN together is one loop over the files in a folder. The
			# reading is gated on the file being a command tool AND on that local, so no other
			# `while` can be mistaken for it.
			var walked: Dictionary = EventSheetSentence.tool_file_condition(collection, sentence_context())
			if not walked.is_empty():
				var words: PackedStringArray = PackedStringArray()
				for segment: Variant in (walked.get("segments", []) as Array):
					words.append(str((segment as Dictionary).get("text", "")))
				return "".join(words).strip_edges()
			return "While %s" % collection
	var text: String = "For each %s in %s" % [iterator, source_text]
	if not pick.predicate_expression.strip_edges().is_empty():
		text += " where %s" % pick.predicate_expression.strip_edges()
	if pick.pick_first_n > 0:
		text += " (first %d)" % pick.pick_first_n
	return text


## Event-sheet-style object label shown before each condition/action (e.g. "System",
## "Sprite", "CharacterBody2D"). Core ACEs read as "System"; node-typed ACEs use the class.
func _object_label_for(provider_id: String, ace_id: String) -> String:
	# A call to a sheet Function is an abstraction you CREATED (e.g. via Extract to Function) - show it as
	# a named verb under a "ƒ" chip, not a generic "System" action, so the eye reads it as higher-level.
	if (provider_id.is_empty() or provider_id == "Core") and ace_id == "CallFunction":
		return "ƒ"
	var definition: ACEDefinition = _viewport._find_definition(provider_id, ace_id)
	if definition != null:
		var node_type: String = str(definition.metadata.get("node_type", "")).strip_edges()
		if not node_type.is_empty():
			return node_type
	if provider_id.is_empty() or provider_id == "Core":
		# An event sheet treats the input devices as OBJECTS, not as part of System: a captured-cursor
		# check reads "Mouse > mouse is captured", a key test "Keyboard > Key Space is down". The
		# builtin vocabulary already files these under exactly those categories, so the label is
		# read off the descriptor rather than kept as a second list to maintain.
		var input_descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
		if input_descriptor != null and INPUT_DEVICE_OBJECTS.has(input_descriptor.category):
			return input_descriptor.category
		if PROJECT_ACE_IDS.has(ace_id):
			return PROJECT_OBJECT
		if input_descriptor != null and str(input_descriptor.category) == COMMAND_TOOL_PAGE:
			return EventSheetToolFiles.OBJECT_COMMAND_TOOL
		if input_descriptor != null and str(input_descriptor.category) == MENU_PAGE:
			return EventSheetMenuFacts.OBJECT_WORD.capitalize()
		if input_descriptor != null and (input_descriptor.category == EDITOR_TOOLS_CATEGORY \
				or str(input_descriptor.category).begins_with(EDITOR_TOOLS_PAGE_PREFIX)):
			return EDITOR_OBJECT
		if WINDOW_ACE_IDS.has(ace_id):
			return WINDOW_OBJECT
		return "System"
	return provider_id


## A call to a sheet Function - the row IS an abstraction (a named verb), so the renderer marks it "ƒ"
## (see _object_label_for) and shows the verb's name instead of "Call name()".
func _is_function_call_action(action: ACEAction) -> bool:
	return action != null and (action.provider_id.is_empty() or action.provider_id == "Core") and action.ace_id == "CallFunction"


## The friendly verb name for a function-call action: the target Function's ace_display_name if it set one
## (e.g. "Apply Physics"), else its humanized name. Appends the argument list only when the call passes
## args, so a plain call reads as a clean verb while a parameterised one still reads fully.
func _function_call_label(action: ACEAction) -> String:
	var params_dict: Dictionary = action.params if not action.params.is_empty() else action.parameters
	var fn_name: String = str(params_dict.get("function_name", "")).strip_edges()
	if fn_name.is_empty():
		return ""
	var label: String = fn_name.capitalize()
	if _viewport._sheet != null:
		for function_entry: Variant in _viewport._sheet.functions:
			if function_entry is EventFunction and (function_entry as EventFunction).function_name == fn_name:
				var display: String = str((function_entry as EventFunction).ace_display_name).strip_edges()
				if not display.is_empty():
					label = display
				break
	var args: String = str(params_dict.get("args", "")).strip_edges()
	# ── lens hook (LIFTED call rows) ──────────────────────────────────────────────────────────
	# "Call Add Look   x = velocity X   y = velocity Y" instead of "Add Look(velocity.x,
	# velocity.y)": the argument labels come from the called function's OWN parameter names, so
	# the row says what each value means rather than making you open the function to find out.
	var called: EventFunction = find_function_by_name(_viewport._sheet, fn_name)
	if called != null:
		var call_pieces: Array = EventSheetViewportReadingRows.call_reading_pieces(
			label,
			_split_call_arguments(args),
			EventSheetViewportReadingRows.parameter_names_of(called),
			_viewport.humanize_names_enabled(),
			_export_knob_names()
		)
		if not call_pieces.is_empty():
			var text: String = ""
			# The object label ("Functions") is the object column's job, so the first piece - which
			# IS that label - is dropped here rather than repeated inside the sentence.
			for index: int in range(1, call_pieces.size()):
				text += str((call_pieces[index] as Array)[0])
			# A call that sits inside the very function it calls says so: the rows below are
			# these rows again, one level in, and that is the one thing a reader cannot see.
			if _function_body_holds(called, action):
				text += "   %s %s" % [MARK_RECURSION, EventSheetL10n.translate("itself")]
			return text.strip_edges()
	return "%s(%s)" % [label, args] if not args.is_empty() else label


## The argument list of a call row split on TOP-LEVEL commas, so a nested call or a vector
## literal ("Vector2(1, 2)") stays one argument instead of becoming two.
func _split_call_arguments(args: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if args.strip_edges().is_empty():
		return out
	var depth: int = 0
	var current: String = ""
	for index: int in range(args.length()):
		var character: String = args[index]
		if character in ["(", "[", "{"]:
			depth += 1
		elif character in [")", "]", "}"]:
			depth -= 1
		if character == "," and depth == 0:
			out.append(current.strip_edges())
			current = ""
			continue
		current += character
	out.append(current.strip_edges())
	return out


func _format_condition_descriptor(condition: ACECondition) -> String:
	# Rich-param styling arms here; TEMPLATE markup arms inside _format_display_translated,
	# where the template is RESOLVED - a locale whose catalog predates the markup translates
	# the plain sentence, and that plain result must not enter the styled branch.
	_pending_display_bbcode = _param_markup_applies(condition.provider_id, condition.ace_id, condition.params)
	# ── lens hook (LIFTED rows) ───────────────────────────────────────────────────────────────
	# The sentence-layer hook further down only covers code that stayed raw; a condition that
	# LIFTED into a real ACE gets its reading here, at the one place its display text is built.
	# Strips a leading NOT because the mark in the badge column says it instead (see
	# _condition_reads_negated, which asks the same question for the badge).
	var base_text: String = _reading_sentence(_humanized_input_event_text(str(EventSheetViewportLenses.strip_leading_not(
		_format_condition_descriptor_base(condition)
	).get("text", ""))))
	var ace_note: String = str(condition.comment).strip_edges()
	if not ace_note.is_empty():
		return "%s   ⊳ %s" % [base_text, ace_note]
	return base_text


## True when this condition is the state-header shape (an is_in_state verb carrying a non-empty
## state value) - the span builder badges it with the ◆ diamond in the trigger-icon column and
## the descriptor formats it as "State: <name>".
## The shipped behavior a hand-rolled state machine could be replaced by. The pattern chip and
## Adopt behavior read this off the claim rather than guessing from the row.
const STATE_MACHINE_PACK_ID: String = "StateMachineBehavior"


## An event that asks which state the object is in IS a state machine's tick, so it claims the
## pattern on itself - the state names it asks about are the evidence, and the shipped State Machine
## behavior is what a hand-rolled machine could become. Called once per event build; the registry
## keeps one claim per (pattern, row).
func _claim_state_machine_pattern(event_row: EventRow) -> void:
	if event_row == null or _viewport == null or _viewport._sheet == null:
		return
	var evidence: PackedStringArray = PackedStringArray()
	var ace_ids: PackedStringArray = PackedStringArray()
	for condition_entry: Variant in event_row.conditions:
		if not (condition_entry is ACECondition) or not _is_state_header_condition(condition_entry as ACECondition):
			continue
		var state_condition: ACECondition = condition_entry as ACECondition
		var state_params: Dictionary = state_condition.params if not state_condition.params.is_empty() else state_condition.parameters
		evidence.append("match state: %s" % str(state_params.get("state_name", "")).strip_edges())
		ace_ids.append(str(state_condition.ace_id))
	if evidence.is_empty():
		return
	EventSheetPatternFacts.claim(_viewport._sheet, "state_machine", event_row.event_uid,
		event_row.event_uid, evidence,
		EventSheetL10n.translate("one named state at a time, switched by Go to state"),
		STATE_MACHINE_PACK_ID, ace_ids)


func _is_state_header_condition(condition: ACECondition) -> bool:
	if condition == null or condition.ace_id != "method:is_in_state":
		return false
	var params_dict: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
	return not str(params_dict.get("state_name", "")).strip_edges().is_empty()


func _format_condition_descriptor_base(condition: ACECondition) -> String:
	# An inverted COMPARISON reads as its opposite - `hp > 0`, which is also what it compiles to
	# now - so the row says the question rather than a question wrapped in a denial. Done on a COPY
	# before anything downstream sees the params; the stored condition keeps its own spelling.
	condition = _comparison_flip_of(condition)
	var params_dict: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
	# An Is In State condition reads as a state header - "State: patrol", with the ◆ diamond
	# rendered as a BADGE by the span builder (the same column trigger icons use, never inline
	# text). Keyed on the method SHAPE (an is_in_state verb carrying a state_name param), not
	# on any one pack's name, so every state-machine-like behavior gets the reading for free.
	# The value shows verbatim minus quotes (state strings are case-sensitive - no prettifying).
	# Display-only: the stored row and the compiled call are untouched.
	# Same shared grammar the action lane uses: a condition whose shape an event sheet already has a
	# sentence for reads that sentence whether it was picked or typed. Cleared first for the same
	# reason the action lane clears: a text-only reading must not leave a label behind.
	_pending_object_label = ""
	_pending_grammar_segments = []
	# ── lens hook ──────────────────────────────────────────────────────────────────────────────
	# A test reaching through an autoload (`EventForgeBridge.score > 100`) is re-read as a test the
	# autoload owns: the singleton prefix comes off the values and moves to the object column, where
	# a reader looks for the owner. Everything downstream reads the rewritten COPY - the stored
	# parameters, and everything the row compiles to, are untouched - and both readings a condition
	# can take (the shared grammar, and a definition's own display template) go through it, because
	# which one a given row takes is not something this lens should have to know.
	var global_read: Dictionary = EventSheetViewportReadingRows.global_member_params(
		params_dict, _reading_autoloads())
	var global_owner: String = str(global_read.get("object", ""))
	# And when nothing reached through an autoload, the variable the row NAMES still has an
	# owner: "Player > hp ≤ 0" instead of "System > hp ≤ 0".
	if global_owner.is_empty():
		global_owner = _variable_owner_label(condition.provider_id, condition.ace_id, params_dict)
	# And a question asked OF A NODE belongs to that node: "Torch > Is on", not "Light2D > Is on";
	# "Aura > effect.glow > 0.5", not "CanvasItem > …".
	if global_owner.is_empty():
		global_owner = _lighting_owner_label(condition.provider_id, condition.ace_id, params_dict)
	var read_params: Dictionary = global_read.get("params", params_dict) if not global_read.is_empty() else params_dict
	var read_condition: ACECondition = condition
	if not global_read.is_empty():
		read_condition = condition.duplicate()
		read_condition.params = read_params
	# And on the left lane: a Compare Variable / Expression row whose question is one object's own
	# property reads the same derived way the typed comparison does.
	var grammar: Dictionary = _upgraded_by_derived_property(grammar_condition_sentence(read_condition), true)
	if not grammar.is_empty():
		grammar = _attributed_grammar(grammar, global_owner)
		_pending_object_label = str(grammar.get("object", ""))
		_pending_grammar_segments = grammar.get("segments", []) as Array
		return _joined_segments(grammar)
	_pending_object_label = global_owner
	if _is_state_header_condition(condition):
		# ────────────────────────────────────────────────────────────────────────────────────────
		# The words a state machine is asked in: "Current state is "Jump"". Anyone who has driven a
		# state-machine behavior in an event sheet reaches for exactly that phrase, and the shipped
		# State Machine pack now publishes it, so a hand-rolled machine and the behavior read alike.
		# A quoted name shows in quotes; an expression (`previous_state`) shows verbatim, because
		# quoting it would claim it was a literal name.
		var state_value: String = str(params_dict.get("state_name", "")).strip_edges()
		var quoted: bool = state_value.length() >= 2 and state_value.begins_with("\"") and state_value.ends_with("\"")
		if quoted:
			state_value = state_value.substr(1, state_value.length() - 2)
		return "%s %s" % [EventSheetL10n.translate("Current state is"),
			"\"%s\"" % state_value if quoted else state_value]
	var generated_definition: ACEDefinition = _viewport._find_definition(condition.provider_id, condition.ace_id)
	var descriptor: ACEDescriptor = null if generated_definition != null else ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
	if generated_definition == null and descriptor == null:
		# THE LAST STORED READING FIRST. A row whose verb the installed vocabulary no longer has
		# still says what it was written as, because the reading was baked onto the row when it was
		# applied. Nothing else in the sheet marks it: the quiet amber state and the selected row's
		# help strip carry that, and the row's own sentence stays exactly the sentence it was.
		var stored: String = _stored_reading(condition, read_params)
		if not stored.is_empty():
			return stored
		# Same registry-free reading the ACTION path gets: a reflected verb (method:<name>) must
		# still read as words when the registry has no definition to offer right now. Without
		# this a pack condition fell back to the raw id and the cell showed
		# "method:can_afford_entry" beside actions that read "Buy" - the id leaking into the one
		# lane a beginner reads first.
		return _reflected_member_sentence(condition.ace_id, read_params)
	return _format_display_translated(generated_definition, descriptor, read_params)


## One row's stored reading, filled with its own values - what a row whose verb the installed
## vocabulary no longer has says in the sheet. "" when the row has no stored reading, which is every
## row applied before the reading was baked and every row whose verb is still here.
##
## The filling itself lives with the findings module that the whole state belongs to, so the sheet,
## the receipt and the Doctor read one row's sentence exactly one way.
func _stored_reading(ace: Resource, params_dict: Dictionary) -> String:
	if ace == null:
		return ""
	return EventSheetMigrationFindings.reading_text(str(ace.get("display_text")), params_dict)


## A reflected `method:<name>` id as a readable sentence with the row's own values in call
## order ("Can Afford Entry ( slot_id )"). Shared by the condition and action fallbacks so
## both lanes read the same way when the registry has no definition; returns the id
## unchanged for anything that is not a reflected member.
func _reflected_member_sentence(ace_id: String, params_dict: Dictionary) -> String:
	if not ace_id.begins_with("method:"):
		return ace_id
	var shown: PackedStringArray = PackedStringArray()
	for param_key: Variant in params_dict.keys():
		if str(param_key) == "target":
			continue
		shown.append(str(params_dict[param_key]))
	var member_label: String = ace_id.trim_prefix("method:").trim_prefix("_").capitalize()
	return member_label if shown.is_empty() else "%s ( %s )" % [member_label, ", ".join(shown)]


func _find_inline_trigger_condition_index(event_row: EventRow) -> int:
	if event_row == null or event_row.trigger != null or not event_row.trigger_id.is_empty():
		return -1
	for condition_index in range(event_row.conditions.size()):
		var condition: ACECondition = event_row.conditions[condition_index]
		if _is_trigger_condition(condition):
			return condition_index
	return -1


func _is_trigger_condition(condition: ACECondition) -> bool:
	if condition == null:
		return false
	var generated_definition: ACEDefinition = _viewport._find_definition(condition.provider_id, condition.ace_id)
	if generated_definition != null:
		return generated_definition.ace_type == ACEDefinition.ACEType.TRIGGER
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
	return descriptor != null and descriptor.ace_type == ACEDescriptor.ACEType.TRIGGER


## How many GDScript lines this action's baked template compiles to - the compression a
## row performs. The renderer shows "→N" for N > 1, so abstraction is visible at a
## glance and plain 1:1 rows read as Extract-to-Function candidates. 0 = no template
## baked (nothing honest to claim).
static func compiled_line_count(action: ACEAction) -> int:
	if action == null:
		return 0
	var template: String = action.codegen_template.strip_edges()
	if template.is_empty():
		return 0
	return template.count("\n") + 1


## Friendly one-line summaries of a structured match case's action-lane body, for the switch read view: an
## ACEAction reads as its descriptor text (the same friendly sentence an action cell shows), a RawCodeRow as
## its verbatim code lines, a CommentRow as `# text`. Empty when the case has no body (the caller shows
## `pass`). Read-only rendering - it does not touch the resources.
func _match_case_summary_lines(events: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for item: Variant in events:
		if item is ACEAction:
			out.append(_format_action_descriptor(item as ACEAction))
		elif item is RawCodeRow:
			for code_line: String in (item as RawCodeRow).code.split("\n"):
				out.append(code_line)
		elif item is CommentRow:
			for comment_line: String in (item as CommentRow).text.split("\n"):
				out.append("# " + comment_line)
	return out


func _format_action_descriptor(action: ACEAction) -> String:
	# Same split as the condition formatter: rich-param styling arms here, template markup
	# arms where the template resolves (translation-fallback aware).
	_pending_display_bbcode = _param_markup_applies(action.provider_id, action.ace_id, action.params)
	# Lens hook for LIFTED action rows - the twin of the condition hook above.
	# Input-event words FIRST (casts stripped, `event.relative.x` -> mouse's ΔX), the name lens
	# after: the lens sees `(event as InputEventMouseMotion).relative.x` as a chain around a
	# cast and the cast stripper then hollowed the middle out ("eventrelative X").
	# A trailing `# note` rides into whichever param the lift put the end of the line in, where it
	# would otherwise read as part of the value ("Subtract 1  # ouch from hp"). Split off the params
	# this row is FORMATTED from - a throwaway copy, the row itself untouched - and drawn as the note
	# it is, at the end.
	var noted: Dictionary = _action_without_trailing_notes(action)
	var row_note: String = str(noted.get("note", ""))
	if not row_note.is_empty():
		action = noted.get("action", action) as ACEAction
	# ...and the note the comment line above this row left for it, when there was one.
	var attached: String = _take_attached_note()
	if not attached.is_empty():
		row_note = attached if row_note.is_empty() else "%s · %s" % [attached, row_note]
	var base_text: String = _reading_sentence(_humanized_input_event_text(_format_action_descriptor_base(action)))
	if not row_note.is_empty():
		base_text += "   💬 %s" % row_note
	# Awaiting actions wear an hourglass (the GDevelop async-action cue): everything after
	# this row in the SAME event waits for it, so the suspension point should be visible.
	if action_awaits(action):
		base_text = "⏳ " + base_text
	var ace_note: String = str(action.comment).strip_edges()
	if not ace_note.is_empty():
		return "%s   ⊳ %s" % [base_text, ace_note]
	return base_text


## The task notes an action lane carries, as {"consumed": {index: true}, "notes": {index: text}}.
##
## A comment written directly above a step, opening TODO / FIXME / HACK / NOTE, is about that step -
## it is the way a person writes a note on one action when the language has nowhere else to put it.
## So it reads as that step's note, exactly where a trailing `# note` reads. Every other comment line
## stays the comment row it has always been: a paragraph above a run of steps is about the run.
##
## Only a ONE-LINE comment immediately above a step qualifies, and only when the step below it can
## carry a note at all. The rows themselves are untouched, so the file still has both lines.
func _task_note_groups(actions: Array) -> Dictionary:
	var consumed: Dictionary = {}
	var notes: Dictionary = {}
	for index: int in range(actions.size() - 1):
		var comment: CommentRow = actions[index] as CommentRow
		if comment == null or not comment.enabled or comment.text.contains("\n"):
			continue
		if EventSheetSentence.task_note_marker(comment.text).is_empty():
			continue
		var carrier: Resource = actions[index + 1] as Resource
		if not (carrier is ACEAction or carrier is RawCodeRow):
			continue
		consumed[index] = true
		notes[index + 1] = comment.text.strip_edges().trim_prefix("#").strip_edges()
	return {"consumed": consumed, "notes": notes}


## The note the action lane attached to the row being formatted, taken and cleared. One-shot, the
## same discipline _pending_object_label uses: the loop writes it, the formatter reads it once.
func _take_attached_note() -> String:
	var note: String = _pending_attached_note
	_pending_attached_note = ""
	return note

## The note one action carries from the comment line above it, until the formatter draws it.
var _pending_attached_note: String = ""


## The row's params with any trailing `# note` split off them, as {"action", "note"} - or {} when
## no param carries one. The copy is for DISPLAY only and never reaches the sheet: the row keeps the
## exact text it was lifted from, so the note is still in the file and the bytes still come back.
##
## Only the LAST param may carry a note, because a trailing comment is the end of a line and only one
## param can hold the end of a line. Claiming it anywhere else would take a `#` out of the middle of
## somebody's value.
func _action_without_trailing_notes(action: ACEAction) -> Dictionary:
	if action == null:
		return {}
	var params_dict: Dictionary = action.params if not action.params.is_empty() else action.parameters
	if params_dict.is_empty():
		return {}
	var cleaned: Dictionary = {}
	var note: String = ""
	for key: Variant in params_dict:
		var value: Variant = params_dict[key]
		if not (value is String) or note != "":
			cleaned[key] = value
			continue
		var split: PackedStringArray = EventSheetSentence.trailing_comment(str(value))
		cleaned[key] = split[0]
		note = split[1]
	if note.is_empty():
		return {}
	var copy: ACEAction = action.duplicate()
	copy.params = cleaned
	return {"action": copy, "note": note}


## Whether an action suspends the handler: the awaited-call flags, an `await` anywhere in
## its baked template, or a builtin coroutine id (a lifted builtin action carries only its
## ace_id - the template re-resolves at compile time).
##
## THE ID LIST IS ONE OF THREE and they have to agree: the compiler's `_COROUTINE_ACE_IDS`
## decides whether the emitted handler is a coroutine, the Doctor's `COROUTINE_ACE_IDS`
## decides whether it warns about one under a per-frame trigger, and this one decides
## whether the canvas draws the hourglass. A row in two of them and not the third is a row
## that suspends without saying so, which is exactly how Save A Still landed here late.
static func action_awaits(action: ACEAction) -> bool:
	if action == null:
		return false
	if action.is_awaited or action.await_call:
		return true
	if ["Wait", "AwaitSignal", "AwaitNextFrame", "AwaitIfOverBudget", "ViewSaveStill"].has(action.ace_id):
		return true
	return action.codegen_template.contains("await ")


func _format_action_descriptor_base(action: ACEAction) -> String:
	# A row whose SHAPE has a settled event-sheet sentence reads through the shared grammar, so the
	# picked row and the hand-written line beside it say the same words. Both one-shots are cleared
	# FIRST: a formatter also runs for text-only readings (a match case's summary line), and a value
	# left behind there would land on whatever span is built next.
	_pending_object_label = ""
	_pending_grammar_segments = []
	# ── lens hook ──────────────────────────────────────────────────────────────────────────────
	# The same re-read the condition lane gets, on the same throwaway copy: a step reaching through
	# an autoload's member belongs to that autoload, not to System.
	var action_params: Dictionary = action.params if not action.params.is_empty() else action.parameters
	var global_read: Dictionary = EventSheetViewportReadingRows.global_member_params(
		action_params, _reading_autoloads())
	var global_owner: String = str(global_read.get("object", ""))
	# The same rule the condition lane takes: a step that changes a variable belongs to whoever
	# owns that variable, so "Player > Subtract 10 from health" leads with the object it changes.
	if global_owner.is_empty():
		global_owner = _variable_owner_label(action.provider_id, action.ace_id, action_params)
	# And the same rule again for a Send row: it is about the MESSAGE, so it belongs to the
	# object whose function that message is rather than to the Multiplayer object in general.
	if global_owner.is_empty():
		global_owner = _message_owner_label(action.provider_id, action.ace_id, action_params)
	# And again for a lighting row: the node IS the object, so "Torch > Set brightness to
	# 1.2" and "Level > Set darkness to 70%" rather than the class each happens to be. A lighting row
	# is also evidence of the LIGHTING pattern, exactly as the hand-written line it was read from
	# was - the row it opens as changed, what it is evidence of did not.
	if not _lighting_host_class(action.provider_id, action.ace_id).is_empty():
		_note_pattern(LIGHTING_PATTERN, ActionCodegen.generate_action(action))
	# And for an effect row, which asks the same question about a different family: the node wearing
	# the material is the object, so "Aura > Set effect.glow to 2" rather than the very general class
	# these rows are hosted on. No pattern is noted - an effect is a thing a game has, not a shape a
	# reader wrote out by hand and could be shown a shorter way of.
	if global_owner.is_empty():
		global_owner = _lighting_owner_label(action.provider_id, action.ace_id, action_params)
	var params_dict: Dictionary = global_read.get("params", action_params) if not global_read.is_empty() else action_params
	var read_action: ACEAction = action
	if not global_read.is_empty():
		read_action = action.duplicate()
		read_action.params = params_dict
	# The same derived property reading the typed line gets, on the PICKED row: the importer files an
	# ordinary `x.y = z` as a Set Property row through the statement catch-all, which is the lowest
	# specificity claim there is and not a curated one - so a Set Property row is this layer's
	# territory exactly as a Call Method row is the derived call layer's.
	var grammar: Dictionary = _upgraded_by_derived_property(grammar_action_sentence(read_action), true)
	if not grammar.is_empty():
		# A picked row is an instance of a pattern exactly as a typed line is, and the registry must
		# not care which way the row got onto the sheet. The row's code is generated only when there
		# IS a pattern to be evidence for, which is the rare case.
		var claimed_pattern: String = str(grammar.get("pattern", ""))
		if not claimed_pattern.is_empty():
			_note_pattern(claimed_pattern, ActionCodegen.generate_action(read_action))
		grammar = _attributed_grammar(grammar, global_owner)
		_pending_object_label = str(grammar.get("object", ""))
		_pending_grammar_segments = grammar.get("segments", []) as Array
		return _joined_segments(grammar)
	_pending_object_label = global_owner
	# Function calls read as the named verb (under the "ƒ" chip), not the raw "Call name()" template.
	if _is_function_call_action(action):
		var verb: String = _function_call_label(action)
		if not verb.is_empty():
			return verb
	var generated_definition: ACEDefinition = _viewport._find_definition(action.provider_id, action.ace_id)
	var descriptor: ACEDescriptor = null if generated_definition != null else ACERegistry.find_descriptor(action.provider_id, action.ace_id)
	if generated_definition == null and descriptor == null:
		# THE LAST STORED READING FIRST. A row whose verb the installed vocabulary no longer has
		# still says what it was written as, because the reading was baked onto the row when it was
		# applied. Nothing else in the sheet marks it: the quiet amber state and the selected row's
		# help strip carry that, and the row's own sentence stays exactly the sentence it was.
		var stored: String = _stored_reading(action, params_dict)
		if not stored.is_empty():
			return stored
		# A reflected verb (method:<name>) must read as its sentence even when the registry has no
		# definition to offer RIGHT NOW - reflected vocabulary is generated on demand, so a row can
		# outlive any given registry build. Rows never need the registry to compile (their template
		# is baked); with this, they no longer need it to READ either. `set_collapsed` -> the same
		# "Set Collapsed" the picker names it, with the row's own values in call order.
		return _reflected_member_sentence(action.ace_id, params_dict)
	return _format_display_translated(generated_definition, descriptor, params_dict)

# ── Row-as-sentence hover ───────────────────────────────────────────────────────────
const _SENTENCE_MAX_ACTIONS := 3
## Friendly lead phrases for the lifecycle trigger ids - the tempo triggers read as a cadence, not a
## method name. Signal-backed triggers fall back to the capitalized id ("OnBodyEntered" → "On Body
## Entered"); an authored ACECondition trigger uses its own descriptor.
const _FRIENDLY_TRIGGER := {
	"OnProcess": "every frame",
	"OnPhysicsProcess": "every physics tick",
	"OnPostTick": "after every frame",
	"OnPhysicsPostTick": "after every physics tick",
	"OnReady": "ready",
	"OnEditorRun": "run in the editor",
	"OnInput": "input arrives",
	"OnUnhandledInput": "unhandled input arrives",
	"OnUnhandledKeyInput": "unhandled key input arrives",
}


## The whole event read as ONE plain-English sentence for the hover tooltip - "When <trigger> - if <c1>
## and <c2> - do: <a1>, <a2> (+1 more)". Assembled EXCLUSIVELY from the same descriptor strings the cells
## draw (the _base formatters, which don't touch the bbcode render flag), so it can NEVER disagree with
## the row. In-flow RawCode actions have no descriptor, so they summarise honestly as "then N lines of
## code" - the sentence never invents prose for raw statements. "" when there is nothing to say.
func row_sentence(event_row: EventRow) -> String:
	if event_row == null:
		return ""
	var head: String = _sentence_head(event_row)
	var conditions_clause: String = _sentence_conditions(event_row)
	var actions_clause: String = _sentence_actions(event_row)
	var clauses: PackedStringArray = PackedStringArray()
	if not head.is_empty():
		if head == "Else if" and not conditions_clause.is_empty():
			clauses.append("%s %s" % [head, conditions_clause])
		elif not conditions_clause.is_empty():
			clauses.append(head)
			clauses.append("if %s" % conditions_clause)
		else:
			clauses.append(head)
	elif not conditions_clause.is_empty():
		clauses.append("If %s" % conditions_clause)
	if not actions_clause.is_empty():
		clauses.append(actions_clause)
	return " - ".join(clauses)


func _sentence_head(event_row: EventRow) -> String:
	if event_row.else_mode == EventRow.ElseMode.ELSE:
		return "Else"
	if event_row.else_mode == EventRow.ElseMode.ELIF:
		return "Else if"
	# A blank top-level event, and an every-frame handler carrying no condition of its own, are
	# the same event: the empty condition lane says it runs every tick, and the hover says so in words.
	if not _blank_tick_reading(event_row).is_empty():
		return EventSheetL10n.translate("Runs every tick")
	var trigger_text: String = _sentence_trigger(event_row)
	return "When %s" % trigger_text if not trigger_text.is_empty() else ""


func _sentence_trigger(event_row: EventRow) -> String:
	if event_row.trigger != null:
		return _format_condition_descriptor_base(event_row.trigger)
	if not event_row.trigger_id.is_empty():
		return str(_FRIENDLY_TRIGGER.get(event_row.trigger_id, event_row.trigger_id.capitalize()))
	var inline_index: int = _find_inline_trigger_condition_index(event_row)
	if inline_index >= 0 and inline_index < event_row.conditions.size():
		return _format_condition_descriptor_base(event_row.conditions[inline_index])
	return ""


func _sentence_conditions(event_row: EventRow) -> String:
	var inline_trigger_index: int = _find_inline_trigger_condition_index(event_row)
	var texts: PackedStringArray = PackedStringArray()
	for condition_index in range(event_row.conditions.size()):
		if condition_index == inline_trigger_index:
			continue  # the inline trigger reads as the head, not a condition
		var condition: ACECondition = event_row.conditions[condition_index]
		if condition == null:
			continue
		var text: String = _format_condition_descriptor_base(condition)
		if condition.negated:
			text = "not " + text
		texts.append(text)
	if texts.is_empty():
		return ""
	var joiner: String = " or " if event_row.condition_mode == EventRow.ConditionMode.OR else " and "
	return joiner.join(texts)


func _sentence_actions(event_row: EventRow) -> String:
	var descriptors: PackedStringArray = PackedStringArray()
	var raw_lines: int = 0
	for action_variant: Variant in event_row.actions:
		if action_variant is ACEAction:
			descriptors.append(_format_action_descriptor_base(action_variant as ACEAction))
		elif action_variant is RawCodeRow:
			var code: String = (action_variant as RawCodeRow).code.strip_edges()
			if not code.is_empty():
				raw_lines += code.split("\n").size()
	var shown: int = mini(descriptors.size(), _SENTENCE_MAX_ACTIONS)
	var pieces: PackedStringArray = PackedStringArray()
	for index: int in range(shown):
		pieces.append(descriptors[index])
	var body: String = ", ".join(pieces)
	var remaining: int = descriptors.size() - shown
	if remaining > 0:
		body += " (+%d more)" % remaining
	if raw_lines > 0:
		body += ("" if body.is_empty() else ", ") + "then %d %s of code" % [raw_lines, "line" if raw_lines == 1 else "lines"]
	return "do: %s" % body if not body.is_empty() else ""


func _format_variable_value(value: Variant) -> String:
	if value == null:
		return "null"
	if value is String:
		return '"%s"' % str(value)
	return str(value)

static var _value_regex: RegEx = null


## Ranges ([start, length, kind]) of parameter-like values inside ACE display text, so the renderer can
## highlight them event-sheet-style AND tint by TYPE: kind is "string" (quoted),
## "bool" (true/false), or "number". The three come straight from which regex alternate matched, so the
## tint can never disagree with the highlight. The trailing kind is additive - consumers that read only
## [start] / [length] (the value hit-test) are unaffected.
static func _value_ranges_for(text: String) -> Array:
	if _value_regex == null:
		_value_regex = RegEx.new()
		_value_regex.compile("\"[^\"]*\"|\\b-?\\d+(?:\\.\\d+)?\\b|\\b(?:true|false|True|False)\\b")
	var ranges: Array = []
	for regex_match in _value_regex.search_all(text):
		var matched: String = regex_match.get_string()
		var kind: String = "number"
		if matched.begins_with("\""):
			kind = "string"
		elif matched.to_lower() == "true" or matched.to_lower() == "false":
			kind = "bool"
		ranges.append([regex_match.get_start(), regex_match.get_end() - regex_match.get_start(), kind])
	return ranges

# One-shot flag set by _format_condition/action_descriptor (their ONLY callers each pass the result straight
# into a _make_span call) when the ACE's display TEMPLATE carries BBCode markup - i.e. the author opted into
# styling via @ace_display_template. _make_span consumes + clears it. Gating on the TEMPLATE (not the
# substituted text) is what stops a USER's param value or note that happens to contain [b]/[color] from being
# silently stripped/styled in the cell. PRIVATE to this layer: writers + reader all live here.
var _pending_display_bbcode: bool = false

# One-shot record from the LAST display substitution: {"text": the substituted sentence, "ranges":
# [[start, length], ...] marking where each parameter's value landed}. _make_span consumes + clears it
# to bold the substituted parameters (the event-sheet emphasis) - but only after re-finding the
# recorded text inside the span's final text, so a formatter suffix (an ACE note) or prefix (the
# await hourglass) shifts the ranges instead of mis-bolding, and any other post-processing degrades
# to no emphasis.
var _pending_param_ranges: Dictionary = {}

# The reading LEADS the last display substitution put into the sentence (`effect.` in front of a
# shader dial). _make_span consumes + clears them, marking where each landed so the renderer draws
# those characters in the muted ink. One-shot for the same reason the ranges above are: they belong
# to the row being built and to nothing after it.
var _pending_muted_leads: PackedStringArray = PackedStringArray()

# The effect rows' ids as a set, filled on first ask (see _names_its_node). Static because the answer
# is the same in every tab for the whole session - the vocabulary does not change under a running
# editor - and because this is asked once per row of every sheet.
static var _effect_ace_ids: Dictionary = {}

# Raised by _append_sentence_spans when a row holds a bare `breakpoint` statement, and consumed
# by _ensure_event_spans, which is the only place that knows which row the spans just built belong to.
# A pause point is marked ON the row here, so the row says it the way a user-set breakpoint says it
# rather than spelling the keyword out in the action cell. Display only: the statement in the file is
# untouched, and nothing about this reaches the view state a user's own breakpoints live in.
var _pending_grammar_breakpoint: bool = false
# Raised by _append_sentence_spans when the DERIVED layer claimed the statement it is reading, and
# consumed by the span it is about to build. Held for exactly one statement: the reading is a
# by-product of resolving the words, and carrying it on the span is what lets the hover show the
# method's own sentence and F1 open the engine's page for it without either of them resolving the
# call a second time.
var _pending_derived_call: Dictionary = {}
# The same fact for a row the IMPORTER filed as a Call Method - the shape most ordinary calls in a
# real file arrive as. Its own pending because the two paths build their spans in different places:
# a raw statement stamps its own span on the spot, and an ACE row's sentence is handed back up to
# `_make_span`, which is where this one is read (and cleared) beside the grammar tones it belongs to.
var _pending_derived_ace: Dictionary = {}
## How far a derived verb sits back from a curated one, as a blend towards the theme's muted text.
## Far enough that the two layers are distinguishable side by side in one glance, and near enough
## that a whole file of derived rows is still comfortably readable - a derived reading is real, and
## greying it out would say the opposite.
const DERIVED_TONE_BLEND: float = 0.4
# The condition lines an "or" divider is drawn above, filled during the span pass of the event
# currently being built and consumed by the caller that holds its EventRowData.
var _pending_or_lines: PackedInt32Array = PackedInt32Array()

# The patterns the readings just built recognised, as {pattern id: [the source lines that are its
# evidence]}. Filled by whatever reading claimed a shape while an event's spans were being built and
# emptied by _ensure_event_spans, which is the only place that knows which row the spans belong to -
# the same hand-off the breakpoint flag above uses, and for the same reason. Claiming here rather
# than in a pass of its own is what keeps a pattern chip free: the answer falls out of the reading
# that was going to run anyway, and a sheet nobody has scrolled to pays nothing.
var _pending_patterns: Dictionary = {}


## What each pattern is CALLED, and which sheet rows author it - the one line a chip prints and the
## vocabulary a reader is sent to when they ask "how would I write this in the sheet?". Keyed by the
## registry's own frozen pattern ids; a pattern with no entry still claims, it just says nothing
## extra. `adoptable` names the pack that could replace the hand-written shape, and is deliberately
## absent for the first three: no shipped behavior replaces a shader parameter, a tilemap cell or a
## camera limit, and offering one that does not fit would be worse than offering none.
const PATTERN_VOCABULARY: Dictionary = {
	"effects": {
		"words": "Effects",
		"ace_ids": ["Core/SetShaderParameter", "Core/SetShaderMaterial", "Core/ClearMaterial",
			"Core/TweenEffectParameter", "Core/GetShaderParameter"]
	},
	"tilemap": {
		"words": "Tilemap",
		"ace_ids": ["Core/TileMapSetCell", "Core/TileMapEraseCell", "Core/TileMapGetCellSourceId",
			"Core/TileMapLocalToMap", "Core/TileMapMapToLocal", "Core/TileMapTileHasCustomData"]
	},
	"camera": {
		"words": "Camera",
		"ace_ids": ["Core/MakeCameraCurrent", "Core/SetCameraZoom", "Core/SetCameraLimits",
			"Core/CameraScrollToward", "Core/SetCameraSmoothing"]
	},
	# The four families most small scripts are made of. Only game feel has a behavior that
	# replaces the hand-written shape outright, so only it carries an `adoptable`: the Juice pack does
	# every one of these five with state of its own.
	"sprite_animation": {
		"words": "Sprites and animation",
		"ace_ids": ["Core/SetFlipH", "Core/SetFlipV", "Core/SetSpriteFrame", "Core/SetAnimationSpeed",
			"Core/SetSpriteTexture", "Core/SetTreeParam", "Core/TravelToState", "Core/AnimationIsPlaying"]
	},
	# Which way a thing faces. Separate from the sprite family because it is NOT a sprite
	# fact: the same two words cover a body that mirrors its own children, a 3D model, a UI panel, the
	# camera's view, a tile and a path, and every one of them is a different line in the file.
	"facing": {
		"words": "Facing",
		"ace_ids": ["Core/SetMirroredObject", "Core/SetMirroredSpatial", "Core/TurnAround",
			"Core/FaceDirectionOfMovement", "Core/FaceObject", "Core/KeepUpright",
			"Core/IsMirroredObject", "Core/SetMirroredControl", "Core/MirrorTheView",
			"Core/SetTileFlipped", "Core/MirrorPath"]
	},
	"ui": {
		"words": "UI",
		"ace_ids": ["Core/GrabFocus", "Core/SetProgress", "Core/ShowDialogCentred", "Core/SetMasterVolume"]
	},
	"sound": {
		"words": "Sound",
		"ace_ids": ["Core/AudioSetStream", "Core/AudioSetPitch", "Core/AudioSetBus",
			"Core/AudioSetVolumeLevel", "Core/AudioSeek", "Core/AudioIsPlaying"]
	},
	"juice": {
		"words": "Game feel",
		"adoptable": "juice",
		"ace_ids": ["Core/CameraShakeOnce", "Core/Hitstop", "Core/BobY", "Core/FlashColour",
			"Core/EaseSizeBack"]
	},
	# ───────────────────────────────────────────────────────────────────────────────────────────
	# The hand-rolled behavior shapes. Every one of these DOES have a shipped pack behind it, so each
	# carries an `adoptable`: attaching the behavior is the first thing to offer, and the free
	# actions beside it are the second.
	"bullet": {
		"words": "Bullet movement written out by hand",
		"adoptable": "bullet",
		"ace_ids": ["Core/SetAngleOfMotion", "Core/StepAlongVelocity", "Core/AddVar",
			"Core/ApplyGravitySimple", "Core/BounceOffSolid", "Core/DistanceTo"]
	},
	# The acquire loop has no one-line free action to offer - the Weapon Kit is the whole answer -
	# so the turret's vocabulary here is the turn, which does.
	"turret": {
		"words": "A turret's target, turn and rate of fire",
		"adoptable": "weapon_kit",
		"ace_ids": ["Core/RotateToward"]
	},
	"move_to": {
		"words": "Gliding to a point until it arrives",
		"adoptable": "move_to",
		"ace_ids": ["Core/GlideToward", "Core/IsWithinDistance"]
	},
	"rotate": {
		"words": "A constant spin",
		"adoptable": "rotate",
		"ace_ids": ["Core/RotateClockwise"]
	},
	"wrap": {
		"words": "Wrapping around the layout edges",
		"adoptable": "wrap",
		"ace_ids": ["Core/WrapAroundLayoutX", "Core/WrapAroundLayoutY"]
	},
	"bound": {
		"words": "Held inside the layout edges",
		"adoptable": "bound_to",
		"ace_ids": ["Core/BoundToLayout"]
	},
	"pin": {
		"words": "One object's place copied from another's",
		"adoptable": "pin",
		"ace_ids": ["Core/PinToObject", "Core/PinAngleToObject", "Core/PinToObjectRope",
			"Core/PinToObjectBar"]
	},
	# A fade is a tween chain rather than one line, so the pack is the whole answer and there is no
	# single free action to name beside it.
	"fade": {
		"words": "Fading out, then destroyed",
		"adoptable": "fade",
		"ace_ids": []
	},
	# The long tail's four shapes. Two of them have a behavior that does the whole thing -
	# the FPS Controller owns the mouse-look block, and Run In Background owns the threads - so those
	# two carry an `adoptable` and the other two do not: an adoption nobody could take is a worse
	# offer than none.
	"ajax": {
		"words": "Web requests",
		"ace_ids": ["Core/AjaxRequest", "Core/AjaxPost", "Core/AjaxLastData"]
	},
	"lighting": {
		"words": "Lighting",
		"ace_ids": ["Core/SetLightEnergy", "Core/SetLightColour", "Core/SetLightEnabled",
			"Core/SetLightShadows", "Core/SetLayerTint", "Core/SetAmbientLight"]
	},
	"fps_look": {
		"words": "First-person look",
		"adoptable": "fps_controller",
		"ace_ids": ["Core/MouseLook", "Core/LookAt3D", "Core/ObjectForward"]
	},
	# Background work has no picker rows of its own on purpose: the Run In Background behavior does
	# the whole shape - the thread, the wait and the done signal - so the honest offer is the pack,
	# not a row that writes one third of it.
	"background": {
		"words": "Background work",
		"adoptable": "background_runner",
		"ace_ids": []
	},
	"picking": {
		"words": "Picking",
		"ace_ids": ["Core/PickNearest", "Core/PickFarthest", "Core/PickRandomInstance",
			"Core/PickWhere", "Core/PickTop", "Core/PickBottom", "Core/PickByUid"]
	},
	"layers": {
		"words": "Layers and Z order",
		"ace_ids": ["Core/SetZOrder", "Core/SetZOrderAbsolute", "Core/SetZOrderRelative",
			"Core/MoveToTopOfLayer", "Core/MoveToBottomOfLayer", "Core/MoveToLayer",
			"Core/SetLayerOrder", "Core/SetVisible", "Core/SetInvisible"]
	},
	"text": {
		"words": "Text",
		"ace_ids": ["Core/SetFontSize", "Core/SetFontColour", "Core/SetOutlineColour",
			"Core/SetFontFile", "Core/SetWordWrapOn", "Core/SetWordWrapOff", "Core/TranslatedText"]
	},
	"platform": {
		"words": "Browser and platform",
		"ace_ids": ["Core/GoToUrl", "Core/SetClipboard", "Core/RequestFullscreen",
			"Core/LeaveFullscreen", "Core/BrowserAlert", "Core/VibrateHandheld",
			"Core/IsPlatform", "Core/IsOnWebPlatform", "Core/IsOnMobilePlatform",
			"Core/IsOnDesktopPlatform"]
	},
	# The last three gaps. Only the path walk has a behavior that replaces the shape
	# outright, so only it carries an `adoptable`: a rigid body is what bodies ARE (the car pack is
	# offered separately, on the car shape alone), and the text words are free actions.
	"physics": {
		"words": "Physics",
		"ace_ids": ["Core/SetBodyMass", "Core/SetGravityScale", "Core/SetBodyFriction",
			"Core/SetBodyElasticity", "Core/ApplyTorqueImpulse2D", "Core/SetBodyImmovable",
			"Core/IsBodySleeping", "Core/SetLinearDamping", "Core/SetWorldGravity"]
	},
	"path": {
		"words": "Follow a Path",
		"adoptable": "follow_path",
		"ace_ids": ["Core/MoveAlongPathAt", "Core/PathReachedEnd", "Core/PathGoToStart",
			"Core/SetPathLooping", "Core/SetPathRotates"]
	},
	"text_format": {
		"words": "Text and patterns",
		"ace_ids": ["Core/SetTextPattern", "Core/MatchPattern", "Core/AllMatches",
			"Core/ReplaceMatches"]
	},
	# Painting a canvas by hand. Adoptable only on a Node2D host - the Drawing Canvas pack draws
	# onto a node's 2D canvas, so offering it on a Control would be an adoption that cannot happen.
	"custom_draw": {
		"words": "Painting the canvas by hand",
		"adoptable": "drawing_canvas",
		"ace_ids": ["Core/DrawLine", "Core/DrawRect", "Core/DrawCircle", "Core/DrawRing"]
	},
	# A window or dialog built in code, configured and opened.
	"dialog": {
		"words": "A dialog built in code",
		"ace_ids": []
	},
	# A menu whose items are declared once and answered by their ids.
	"menu": {
		"words": "A menu and the items it answers",
		"ace_ids": []
	},
	# The three tooling shapes. None is adoptable: a test, a command tool and a pack
	# recipe are things you WRITE, not behaviors a pack could take over, so the chip names the shape
	# and offers nothing to swap it for.
	"test_sheet": {
		"words": "Test sheet"
	},
	"command_tool": {
		"words": "Command tool"
	},
	"pack_recipe": {
		"words": "Pack recipe"
	},
	# The cursor's ray and the canvas measurements built on it. Neither has a pack to
	# adopt: both are FREE vocabulary - the shipped camera-picking words, the aimed-floor expressions
	# and the canvas distance - so what a hand-written run should become is a row, not an addon.
	"cursor_ray": {
		"words": "The object under the cursor",
		"ace_ids": ["Core/MouseRayCollider3D", "Core/MouseRayPoint3D", "Core/CastMouseRayInto3D",
			"Core/CursorIsOverObject3D", "Core/OnObjectClicked3D", "Core/MouseFloorPoint",
			"Core/MouseFloorObject", "Core/MouseFloorSlope", "Core/SlopeSteeperThan",
			"Core/ObjectUnderCursor2D", "Core/TileUnderCursor"]
	},
	"aim_assist": {
		"words": "Aim assist",
		"ace_ids": ["Core/PickNearestToCanvasPoint", "Core/VectorDistanceTo", "Core/IsBehindCamera3D",
			"Core/CanvasX2D", "Core/CanvasY2D", "Core/CanvasX3D", "Core/CanvasY3D"]
	},
	# Movement claims from the readings themselves (the camera-relative run, a fall) as well as
	# from the whole-file pattern walk. No `adoptable`: what could replace a hand-written movement
	# depends entirely on which one it is, and offering one pack for all of them would misfit most.
	"movement": {
		"words": "Movement",
		"ace_ids": ["Core/SetVelocity3D", "Core/MoveAndSlide3D", "Core/GetInputVector",
			"Core/MoveRelativeToCamera", "Core/IsOnFloor3D"]
	},
	# Batch thirteen's two new shapes. An orbit HAS a pack that does the whole thing, so it
	# offers one; world-space UI is a handful of settings on ordinary nodes, so the honest offer is
	# the rows themselves and no adoption.
	"orbit": {
		"words": "Orbiting - a camera or an object going round a centre",
		"adoptable": "orbit_3d",
		"ace_ids": ["Core/OrbitAtRadius", "Core/SetCameraDistance"]
	},
	"worldspace_ui": {
		"words": "UI that lives in the world",
		"ace_ids": ["Core/SetFaceTheCamera", "Core/SetShowThroughWalls", "Core/SetWorldSize",
			"Core/SetBarWidth", "Core/SendInputToSurface", "Core/SetSurfaceRedraw"]
	},
	# Only two of the six have a behavior that does the whole shape - the
	# FPS Controller owns gyro aim the way it owns mouse look, and the Touch Gestures pack owns swipes
	# and drawn shapes outright - so only those two carry an `adoptable`. A shot, a blast, a secrets
	# counter, an input window and an options screen are vocabulary, not a behaviour to attach.
	"gyro_controls": {
		"words": "Tilt steering and gyro aim",
		"adoptable": "fps_controller",
		"ace_ids": ["Core/TouchSetNeutralTilt", "Core/TouchSteerByTilt", "Core/TouchAimByGyro",
			"Core/TouchAcceleration", "Core/TouchRotationRate", "Core/TouchGravity"]
	},
	"swipe": {
		"words": "Swipes and drawn shapes",
		"adoptable": "touch_gestures",
		"ace_ids": []
	},
	"hitscan": {
		"words": "Shots, blasts and an arsenal",
		"ace_ids": ["Core/FireHitscan", "Core/ExplodeAt", "Core/SwitchToNextWeapon",
			"Core/SwitchToPreviousWeapon", "Core/CurrentWeapon"]
	},
	"secrets": {
		"words": "Secrets found",
		"ace_ids": ["Core/MarkSecretFound", "Core/SecretsFoundCount", "Core/SecretAlreadyFound"]
	},
	# A keycard is a name in a list and a door is a body that wants one. No `adoptable`: there is
	# no behaviour to attach for it and there should not be - what a hand-written keycard should
	# become is six rows and the Keycard Door starter, which is vocabulary, not an addon.
	"keys_doors": {
		"words": "Keys and the doors that want them",
		"ace_ids": ["Core/PickUpKey", "Core/HasKey", "Core/NeedsKey", "Core/KeysHeld",
			"Core/TryDoor", "Core/OpenDoor"]
	},
	"qte": {
		"words": "Timed input windows",
		"ace_ids": ["Core/OpenInputWindow", "Core/CloseInputWindow", "Core/PressedInInputWindow",
			"Core/InputWindowMissed", "Core/InputWindowGrade", "Core/MashedInTime",
			"Core/ShowInputPrompt"]
	},
	"accessibility_options": {
		"words": "An accessibility options screen",
		"ace_ids": ["Core/StartListeningForControl", "Core/RebindControlTo",
			"Core/TreatControlAsToggle", "Core/SetEffectStrength", "Core/SetNoFlashing",
			"Core/SetTextSizeScale", "Core/SetAimAssistRadius", "Core/SpeakText",
			"Core/PlaySoundWithCaption"]
	},
	"grind": {
		"words": "Riding a rail",
		"adoptable": "skateboard",
		"ace_ids": ["SkateboardMovement/is_near_rail", "SkateboardMovement/start_grinding",
			"SkateboardMovement/grind_along_rail", "SkateboardMovement/has_reached_the_end",
			"SkateboardMovement/hop_off", "SkateboardMovement/ride_zipline"]
	},
	"skateboard": {
		"words": "Momentum movement on a board",
		"adoptable": "skateboard",
		"ace_ids": ["SkateboardMovement/push", "SkateboardMovement/roll_with_slope",
			"SkateboardMovement/ollie", "SkateboardMovement/spin_trick",
			"SkateboardMovement/flip_trick", "SkateboardMovement/land_trick"]
	}
}

## The host classes the Drawing Canvas pack can actually be attached to. A `_draw` body on a
## Control paints the same way but has no pack to adopt, so the chip offers none.
const CUSTOM_DRAW_ADOPTABLE_HOSTS: PackedStringArray = ["Node2D", "Sprite2D", "Polygon2D", "Line2D"]


## Records that a reading recognised `pattern` on the line it was given. Called by the readings while
## an event's spans are built; the claim itself is made once the owning row is known.
func _note_pattern(pattern: String, evidence: String) -> void:
	if pattern.is_empty():
		return
	if not _pending_patterns.has(pattern):
		_pending_patterns[pattern] = PackedStringArray()
	var lines: PackedStringArray = _pending_patterns[pattern]
	var text: String = evidence.strip_edges()
	if not text.is_empty() and not lines.has(text):
		lines.append(text)
	_pending_patterns[pattern] = lines


## The pack a claim may offer to adopt, which for most patterns is whatever the vocabulary table
## says. Hand-drawing is the exception: is the same shape on any canvas, but only a 2D node has a
## pack that could take it over, so a `_draw` body on a Control claims the pattern and offers nothing.
func _pattern_adoptable(pattern: String, listed: String) -> String:
	if pattern != "custom_draw" or listed.is_empty():
		return listed
	var sheet: EventSheetResource = _viewport._sheet
	var host: String = "" if sheet == null else sheet.host_class.strip_edges()
	if host.is_empty() or not ClassDB.class_exists(host):
		return ""
	for adoptable_host: String in CUSTOM_DRAW_ADOPTABLE_HOSTS:
		if host == adoptable_host or ClassDB.is_parent_class(host, adoptable_host):
			return listed
	return ""


## Hands every pattern the readings just recognised to the registry, on the row that owns it.
func _claim_pending_patterns(row_data: EventRowData) -> void:
	if _pending_patterns.is_empty():
		return
	var sheet: EventSheetResource = _viewport._sheet
	for pattern: String in _pending_patterns:
		var vocabulary: Dictionary = PATTERN_VOCABULARY.get(pattern, {})
		var ace_ids: PackedStringArray = PackedStringArray()
		for ace_id: Variant in (vocabulary.get("ace_ids", []) as Array):
			ace_ids.append(str(ace_id))
		EventSheetPatternFacts.claim(sheet, pattern, row_data.row_uid, row_data.row_uid,
			_pending_patterns[pattern], str(vocabulary.get("words", "")),
			_pattern_adoptable(pattern, str(vocabulary.get("adoptable", ""))), ace_ids)
	_pending_patterns = {}


## Appends the flowing spans that make a single-statement raw row read as an event-sheet sentence
## ("Add 1 to score") or as an Object / Verb / parameters chip run, and returns true when it did.
## The caller then skips its per-line default for that action.
##
## Purely a VIEW: the RawCodeRow is unchanged, so emission and the byte round-trip cannot move. The
## spans carry `raw_action` and `code_cell: false` so selection, the row context menu, and
## double-click-opens-the-code-editor behave exactly as they do for any other raw row. Only the LAST
## span omits `natural_width`, so it stretches to close the action cell the way the Declare header
## does - without that, the cell background would stop mid-row.
## `literal` is the multi-line table or list this statement's value was written over, when the
## row is the LEAD of such a run. The statement then reads with the word `table` / `list` where the
## literal sat and the entries as chips after it; every other caller passes {} and nothing changes.
func _append_sentence_spans(spans: Array, raw: RawCodeRow, action_index: int, line_index: int, action_style_meta: Dictionary, literal: Dictionary = {}) -> bool:
	# Cleared on the way in, so a derived reading can never leak onto the NEXT statement through an
	# exit that returned before the span carrying it was built.
	_pending_derived_call = {}
	# An edit handed to the mutation funnel is ONE undoable step: the row names the step, and the
	# callback's own lines read as sub-events under it. Ahead of the sentence layer, which cannot see
	# a statement written across several lines at all.
	var undo_step: Dictionary = undo_step_parts(raw.code)
	if not undo_step.is_empty():
		_append_undo_step_spans(spans, undo_step, action_index, line_index, action_style_meta)
		return true
	var pieces: Array = []
	var indent: int = 0
	var object_label: String = ""
	var sentence: Dictionary = statement_sentence(raw.code, sentence_context())
	# ── lens hook ─────────────────────────────────────────────────────────────────────────────
	# THE DERIVED PROPERTY LAYER. Nothing curated claimed this property write or this question, so
	# the API is asked instead: where the sheet can know the receiver's class AND the class really
	# has that property, the row wears the plainer derived tone, carries the class it was read off,
	# and hovers with the property's own words. A reading no word map marked generic never reaches
	# it, which is what keeps a curated sentence outranking this one.
	sentence = _upgraded_by_derived_property(sentence, false)
	# ── lens hook ─────────────────────────────────────────────────────────────────────────────
	# A bare `breakpoint` reads as the mark it is: the row wears the gutter dot and says nothing.
	if bool(sentence.get("breakpoint", false)):
		_pending_grammar_breakpoint = true
	# The pattern registry, filled by the reading that just fired rather than by a second walk.
	_note_pattern(str(sentence.get("pattern", "")), raw.code)
	if EventSheetSentence.leading_word(raw.code.strip_edges()) == "return":
		sentence = _named_return_sentence(sentence, raw.code.strip_edges().substr(6))
	# A `var` line is a DECLARATION, not a step: it reads as the event-sheet local-variable row - a type
	# chip, the name, the starting value - rather than as an action wearing an object label.
	if str(sentence.get("kind", "")) == "declaration":
		append_local_declaration_spans(spans, sentence, {
			"lane": "action",
			"kind": "action",
			"ace_index": action_index,
			"ace_enabled": raw.enabled,
			"raw_action": true,
			"code_cell": false,
			"line_index": line_index
		}, action_style_meta, literal)
		return true
	if not sentence.is_empty():
		indent = int(sentence.get("indent", 0))
		object_label = str(sentence.get("object", ""))
		# ── lens hook ──────────────────────────────────────────────────────────────────────────
		# A Check row that has been RUN says so, in front of what it checks: ✓ when the last headless
		# run passed it, ✗ when it did not. A check that has never been run says nothing, which is the
		# truth. Display only - the mark comes from the run's output and never from the file.
		var verdict: Variant = _check_row_verdict(str(sentence.get("check_label", "")))
		if verdict != null:
			pieces.append(["✓ " if bool(verdict) else "✗ ", "plain"])
		for segment: Variant in (sentence.get("segments", []) as Array):
			var part: Dictionary = segment
			pieces.append([str(part.get("text", "")), str(part.get("tone", "plain"))])
	else:
		var call_info: Dictionary = call_parts(raw.code)
		if call_info.is_empty():
			return false
		indent = int(call_info.get("indent", 0))
		var args: PackedStringArray = call_info.get("args", PackedStringArray())
		# ── lens hook ──────────────────────────────────────────────────────────────────────────
		# Applied AFTER the sentence layer has resolved this row as a call: when the callee is one
		# of THIS sheet's functions, the row reads the event-sheet way ("Functions ▸ Call Add Look",
		# one argument per parameter name) instead of as a bare method call. A callee the sheet
		# does not know falls straight through to the ordinary reading below - a call to something
		# unknown must never be dressed up as a project function.
		var call_pieces: Array = _reading_call_pieces(raw.code, args)
		if not call_pieces.is_empty():
			pieces = call_pieces
		else:
			# ── lens hook ─────────────────────────────────────────────────────────────────────
			# THE DERIVED LAYER. Nothing curated claimed this line, so the API is asked instead:
			# when the sheet can KNOW the receiver's class - `self`, an @onready node, a typed
			# declaration, an Autoload, a class name - the method's own parameter names name the
			# chips and the method's own words ride on the row. Read in the PLAINER call style,
			# never the polished sentence's, so a reader always knows which layer they are looking
			# at. A receiver nothing can answer for is not guessed at; it falls through.
			var derived: Dictionary = EventSheetDerivedCalls.derived_pieces(
				raw.code, sentence_context(), _reading_class_map(), _reading_autoloads())
			# ── lens hook ─────────────────────────────────────────────────────────────────────
			# Any other call reads Object ▸ Verb chips - the verb in words, the arguments named by
			# the engine's own parameter names when the object's class is known, and no
			# parentheses anywhere. Only a line that is not one call at all keeps the old form.
			var generic: Dictionary = {} if not derived.is_empty() \
				else EventSheetViewportReadingRows.generic_call_pieces(
					raw.code, sentence_context(), _reading_class_map())
			if not derived.is_empty():
				object_label = str(derived.get("object", ""))
				pieces = derived.get("pieces", []) as Array
				_pending_derived_call = derived
			elif not generic.is_empty():
				object_label = str(generic.get("object", ""))
				pieces = generic.get("pieces", []) as Array
			else:
				pieces.append([str(call_info.get("target", "")) + "  ", "object"])
				pieces.append([str(call_info.get("verb", "")), "name"])
				if args.is_empty():
					pieces.append(["  ( )", "plain"])
				else:
					pieces.append(["  ( ", "plain"])
					for argument_index: int in args.size():
						if argument_index > 0:
							pieces.append([", ", "plain"])
						pieces.append([args[argument_index], "value"])
					pieces.append([" )", "plain"])
	if pieces.is_empty():
		return false
	# ── lens hook ──────────────────────────────────────────────────────────────────────────────
	# WHO this statement belongs to, decided once the sentence layer has said what it DOES. An
	# autoload gains its "(global)" note and a globe; a pack node under the script's own node hands
	# its rows to that object with the pack's name as the leading chip. Applied before the spelling
	# lens below so the lookup keys are still the names the file actually uses.
	var attribution: Dictionary = EventSheetViewportReadingRows.object_attribution(
		object_label, pieces, _script_object_name(), _reading_class_map(), _reading_autoloads())
	object_label = str(attribution.get("object", object_label))
	pieces = attribution.get("pieces", pieces) as Array
	var attributed_icon: Variant = attribution.get("icon")
	# ── lens hook ──────────────────────────────────────────────────────────────────────────────
	# When the sheet DECLARED what this receiver is, the object column says what it is rather than
	# what it was called: `_registry` reads `ACE registry`, with `registry` muted beside it. Applied
	# after the attribution above, so an autoload or a pack's own object still wins.
	var object_note: String = ""
	# ── lens hook ──────────────────────────────────────────────────────────────────────────────
	# The SECOND half of the derived layer's own look: the class the verb was read off, muted beside
	# the object. It says where a derived reading came from in the same breath as saying whose row it
	# is, which is what stops the plainer verb from reading as a row somebody forgot to finish.
	#
	# ON A DERIVED ROW IT IS THE ONLY THING BESIDE THE OBJECT, which is why the declaration lens below
	# is not asked at all here. That lens answers a different question - what a receiver IS rather
	# than what it was called - and for a class the project declared it MOVES the class into the
	# object column and leaves the variable's own name muted. Applied to a derived row that would
	# invert the layer's own mark: the muted word would be a variable name on the layer whose muted
	# word is supposed to be a class. One row, one answer, and the derived row's is the class.
	if not _pending_derived_call.is_empty():
		object_note = EventSheetDerivedCalls.muted_note(_pending_derived_call, object_label)
	else:
		var typed_object: Dictionary = EventSheetViewportReadingRows.typed_object_label(
			object_label, sentence_context(), _viewport.humanize_names_enabled())
		if not typed_object.is_empty():
			object_label = str(typed_object.get("label", object_label))
			object_note = str(typed_object.get("note", ""))
	# ── lens hook ──────────────────────────────────────────────────────────────────────────────
	# Applied to the sentence layer's OUTPUT, never inside it: the sentence layer decides what a
	# statement SAYS, this only decides how the names in it are SPELLED. Only "name" and "value"
	# pieces are touched (identifiers the builder already resolved), never a string literal and
	# never a connective word, and the row's hover still shows the exact GDScript.
	pieces = EventSheetViewportLenses.apply_to_pieces(pieces, _viewport.humanize_names_enabled(), _export_knob_names())
	# The row's own note, at the end of it, muted - which is where and how a sheet writes a note
	# about one step. Appended AFTER the spelling lens, because a note is prose somebody wrote and
	# nothing in it is a name for the lens to respell.
	var row_note: String = str(sentence.get("note", ""))
	var attached_note: String = _take_attached_note()
	if not attached_note.is_empty():
		row_note = attached_note if row_note.is_empty() else "%s · %s" % [attached_note, row_note]
	if not row_note.is_empty():
		pieces.append(["   💬 %s" % row_note, "muted"])
	# ── lens hook ──────────────────────────────────────────────────────────────────────────────
	# The object this statement acts on draws its Godot class icon, the way an event sheet shows
	# an object's picture in every cell it appears in. Resolved from the RAW pieces (before the
	# lens above respelled them) so the lookup keys stay the names the file actually uses.
	var sentence_icon: Texture2D = _reading_sentence_icon(sentence, raw.code)
	if attributed_icon is Texture2D and _viewport.show_object_icons:
		sentence_icon = attributed_icon as Texture2D
	# ── lens hook ──────────────────────────────────────────────────────────────────────────────
	# A statement whose VALUE is a thing in the scene draws that thing's picture beside it, not only
	# the subject's: `crate ▸ Set position to spawn_point` shows the marker's own icon on the marker.
	# The class is named by the sentence layer, which resolved it there anyway - this reads one key
	# off a Dictionary and bails, which is the whole cost on every other statement in the file.
	var value_icon_class: String = str(sentence.get("value_icon_class", ""))
	if not value_icon_class.is_empty() and literal.is_empty() and _viewport.show_object_icons:
		var value_icon: Texture2D = ACEPickerDialog.editor_icon(value_icon_class)
		if value_icon != null and _append_value_icon_sentence_spans(spans, pieces, indent,
				object_label, object_note, sentence_icon, value_icon, raw, action_index,
				line_index, action_style_meta):
			return true
	# ONE span, tinted by BBCode segments, so the sentence reads as a single continuous cell -
	# separate flowing spans each painted their own chip and the row read as a strip of boxes,
	# the exact fragmented look the entry rows were already reworked away from. Four spaces per
	# source tab keeps deeper statements visually nested like the code they came from.
	# The statement is written around a multi-line table or list: the sentence splits where the
	# literal sat, the word for it goes there, and the entries follow as chips.
	if not literal.is_empty():
		_append_literal_sentence_spans(spans, pieces, literal, indent, object_label, object_note,
			sentence_icon, raw, action_index, line_index, action_style_meta)
		return true
	var sentence_text: String = "    ".repeat(indent)
	# Segments are built DIRECTLY, never round-tripped through the BBCode parser: code text is
	# full of square brackets (`wave[1]`, `[]`), and a parser would eat them as tags - the first
	# render lost every array value exactly that way.
	var sentence_segments: Array[Dictionary] = _sentence_tone_segments(pieces, indent)
	for piece: Array in pieces:
		sentence_text += str(piece[0])
	spans.append(_make_span(sentence_text, SemanticSpan.SpanType.VALUE, {
		"lane": "action",
		"kind": "action",
		"ace_index": action_index,
		"ace_enabled": raw.enabled,
		"chip": true,
		"raw_action": true,
		"code_cell": false,
		"line_index": line_index,
		# The object column, exactly as an ACE row fills it: a variable belongs to System, a member
		# assignment to the node it is on. A declaration row names no object at all.
		"object_label": object_label,
		"object_note": object_note,
		"bbcode_segments": sentence_segments,
		"object_icon": sentence_icon
	}.merged(_derived_call_meta(), true).merged(action_style_meta, false)))
	return true


## What a DERIVED reading leaves on the span it just built, for the two surfaces that ask about it
## later: the hover, which shows the method's own words above the line, and F1, which opens the
## engine's page for the member. {} on every other row, so a curated sentence and an unclaimed line
## carry nothing extra at all.
##
## Consumed here rather than read again from the reading: resolving the call a second time to answer
## a hover would be the same work twice, on a file that may have thousands of statements in it.
func _derived_call_meta() -> Dictionary:
	if _pending_derived_call.is_empty():
		return {}
	var reading: Dictionary = _pending_derived_call
	_pending_derived_call = {}
	return derived_meta(reading)


## The same for a Call Method ROW, off its own pending. `_make_span` clears it.
func _derived_ace_meta() -> Dictionary:
	return derived_meta(_pending_derived_ace)


## A grammar reading with the DERIVED PROPERTY layer's answer applied, or the reading exactly as it
## came. A reading the grammar did not mark generic is handed straight back untouched, which is where
## "curated outranks derived" is actually enforced: a word map's sentence carries no mark, so this
## never even asks about it.
##
## `picked_row` says which of the two pendings the answer is left on, because the two paths build
## their spans in different places: a raw statement stamps its own span on the spot, and a picked
## row's sentence is handed back up to `_make_span`.
func _upgraded_by_derived_property(sentence: Dictionary, picked_row: bool) -> Dictionary:
	if str(sentence.get("generic", "")).is_empty():
		return sentence
	var derived: Dictionary = EventSheetDerivedProperties.derived_reading(
		sentence, sentence_context(), _reading_class_map(), _reading_autoloads())
	if derived.is_empty():
		return sentence
	var upgraded: Dictionary = sentence.duplicate()
	upgraded["segments"] = derived.get("segments", [])
	if picked_row:
		_pending_derived_ace = derived
	else:
		_pending_derived_call = derived
	return upgraded


## One derived reading as the keys a span carries. Static + pure, so a test reads exactly what a
## hover and F1 will be handed, and the two paths that stamp it cannot drift apart.
static func derived_meta(reading: Dictionary) -> Dictionary:
	if reading.is_empty():
		return {}
	return {
		"derived_call": true,
		"derived_class": str(reading.get("class", "")),
		"derived_method": str(reading.get("method", "")),
		# The property half of the same layer. Exactly one of these two is ever filled: a reading is
		# a verb read off the API or a property read off it, never both.
		"derived_property": str(reading.get("property", "")),
		"derived_doc": EventSheetDerivedCalls.hover_text(reading),
		"derived_doc_id": str(reading.get("doc_id", "")),
	}


## The statement split in two so the VALUE can wear its own picture: the sentence up to the value
## (carrying the subject's icon, its object label and its note), then the value itself with the class
## icon the sentence layer named, then whatever the sentence said after it. An icon draws at the
## START of the span it is on, which is exactly why the value needs a span of its own.
##
## False when the sentence has no value piece to split at, which is the caller's cue to keep the
## single-span reading it has today. Display only: every span carries the same row identity
## (`ace_index`, `line_index`, `raw_action`), so selection, editing and the emitted bytes are the
## statement's, untouched - the same shape the multi-line-literal split already uses.
func _append_value_icon_sentence_spans(spans: Array, pieces: Array, indent: int,
		object_label: String, object_note: String, sentence_icon: Texture2D, value_icon: Texture2D,
		raw: RawCodeRow, action_index: int, line_index: int, action_style_meta: Dictionary) -> bool:
	var value_at: int = -1
	for piece_index: int in pieces.size():
		if str((pieces[piece_index] as Array)[1]) == "value":
			value_at = piece_index
			break
	if value_at < 0:
		return false
	var head_pieces: Array = pieces.slice(0, value_at)
	var value_pieces: Array = pieces.slice(value_at, value_at + 1)
	var tail_pieces: Array = pieces.slice(value_at + 1)
	var base_meta: Dictionary = {
		"lane": "action",
		"kind": "action",
		"ace_index": action_index,
		"ace_enabled": raw.enabled,
		"chip": true,
		"raw_action": true,
		"code_cell": false,
		"line_index": line_index
	}
	var head_text: String = "    ".repeat(indent)
	for piece: Array in head_pieces:
		head_text += str(piece[0])
	spans.append(_make_span(head_text, SemanticSpan.SpanType.VALUE, base_meta.duplicate().merged({
		"natural_width": true,
		"object_label": object_label,
		"object_note": object_note,
		"bbcode_segments": _sentence_tone_segments(head_pieces, indent),
		"object_icon": sentence_icon
	}, true).merged(action_style_meta, false)))
	var value_meta: Dictionary = base_meta.duplicate().merged({
		"bbcode_segments": _sentence_tone_segments(value_pieces, 0),
		"object_icon": value_icon
	}, true)
	# The LAST span of a row fills the cell; every earlier one is as wide as its own words.
	if not tail_pieces.is_empty():
		value_meta["natural_width"] = true
	spans.append(_make_span(str((value_pieces[0] as Array)[0]), SemanticSpan.SpanType.VALUE,
		value_meta.merged(action_style_meta, false)))
	if tail_pieces.is_empty():
		return true
	var tail_text: String = ""
	for piece: Array in tail_pieces:
		tail_text += str(piece[0])
	spans.append(_make_span(tail_text, SemanticSpan.SpanType.VALUE, base_meta.duplicate().merged({
		"bbcode_segments": _sentence_tone_segments(tail_pieces, 0)
	}, true).merged(action_style_meta, false)))
	return true


## The sentence layer's [[text, tone], ...] as tinted BBCode segments. Built DIRECTLY, never
## round-tripped through the BBCode parser: code text is full of square brackets (`wave[1]`, `[]`)
## and a parser would eat them as tags - the first render lost every array value exactly that way.
func _sentence_tone_segments(pieces: Array, indent: int) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	if indent > 0:
		segments.append({"text": "    ".repeat(indent), "color": null, "bold": false, "italic": false})
	for piece: Array in pieces:
		var tone_color: Variant = null
		var tone_bold: bool = false
		match str(piece[1]):
			"name":
				tone_color = _viewport._get_reading_style().primary_text_color
				tone_bold = true
			"value":
				tone_color = _viewport._get_event_style().value_highlight_color
			"object":
				tone_color = _viewport._get_event_style().object_label_color
			"behaviour":
				# The pack's name between the object and its verb. Drawn in the object tint and
				# bold, so it reads as part of WHO acts rather than as part of what the verb says.
				tone_color = _viewport._get_event_style().object_label_color
				tone_bold = true
			"muted":
				# A connective the sentence needs but the reader does not read ("then").
				tone_color = _viewport._get_reading_style().muted_text_color
			EventSheetDerivedCalls.TONE_DERIVED:
				# THE DERIVED VERB, and the one place the two reading layers are told apart on the
				# canvas. A curated sentence's verb is the bold `name` above; this one is the same
				# words read off the API instead of written by a person, so it reads in the plainer
				# call style - unbolded, and a shade back towards the muted lead the object note
				# beside it wears. The moment a curated table claims the line the bold form takes
				# over, with the file untouched.
				tone_color = _viewport._get_reading_style().primary_text_color.lerp(
					_viewport._get_reading_style().muted_text_color, DERIVED_TONE_BLEND)
		segments.append({"text": str(piece[0]), "color": tone_color, "bold": tone_bold, "italic": false})
	return segments


## The lead row of a multi-line literal: the statement's own sentence up to where the literal
## sat, then the entry chips, then whatever the statement said after it (the `)` of the call it was
## an argument to). The chips are the point - `"span_index": _selected_span_index` reads
## `span index = selected span index` instead of being a line of code with no row of its own.
func _append_literal_sentence_spans(spans: Array, pieces: Array, literal: Dictionary, indent: int,
		object_label: String, object_note: String, sentence_icon: Texture2D, raw: RawCodeRow,
		action_index: int, line_index: int, action_style_meta: Dictionary) -> void:
	var head_pieces: Array = []
	var tail_pieces: Array = []
	var split_found: bool = false
	for piece: Variant in pieces:
		var entry: Array = piece
		var text: String = str(entry[0])
		if split_found or not text.contains(EventSheetValueLiteralRows.LITERAL_TOKEN):
			(tail_pieces if split_found else head_pieces).append(entry)
			continue
		split_found = true
		var at: int = text.find(EventSheetValueLiteralRows.LITERAL_TOKEN)
		if at > 0:
			head_pieces.append([text.substr(0, at), str(entry[1])])
		var after: String = text.substr(at + EventSheetValueLiteralRows.LITERAL_TOKEN.length())
		if not after.is_empty():
			tail_pieces.append([after, str(entry[1])])
	var base_meta: Dictionary = {
		"lane": "action",
		"kind": "action",
		"ace_index": action_index,
		"ace_enabled": raw.enabled,
		"chip": true,
		"raw_action": true,
		"code_cell": false,
		"line_index": line_index
	}
	var head_text: String = "    ".repeat(indent)
	for piece: Array in head_pieces:
		head_text += str(piece[0])
	spans.append(_make_span(head_text, SemanticSpan.SpanType.VALUE, base_meta.duplicate().merged({
		"natural_width": true,
		"object_label": object_label,
		"object_note": object_note,
		"bbcode_segments": _sentence_tone_segments(head_pieces, indent),
		"object_icon": sentence_icon
	}, true).merged(action_style_meta, false)))
	_append_literal_chip_spans(spans, literal, action_index, line_index, action_style_meta,
		tail_pieces.is_empty())
	if tail_pieces.is_empty():
		return
	var tail_text: String = ""
	for piece: Array in tail_pieces:
		tail_text += str(piece[0])
	spans.append(_make_span(tail_text, SemanticSpan.SpanType.VALUE, base_meta.duplicate().merged({
		"bbcode_segments": _sentence_tone_segments(tail_pieces, 0)
	}, true).merged(action_style_meta, false)))


## The word for the literal (`table` / `list`) and one chip per entry, folded to the first three
## with "… N more" when there are more - the whole thing is on the row's hover, so a folded row never
## hides a line. Each chip edits in place, rewriting the ONE source row its entry came from.
## `show_word` is off on a declaration row, whose type chip already says `Local table` - the word
## twice in one row is the row saying the same thing to itself.
func _append_literal_chip_spans(spans: Array, literal: Dictionary, action_index: int,
		line_index: int, action_style_meta: Dictionary, close_cell: bool, show_word: bool = true) -> void:
	var entries: Array = literal.get("entries", []) as Array
	var open_bracket: String = str(literal.get("open", "{"))
	var humanize: bool = _viewport.humanize_names_enabled()
	var full_text: String = EventSheetValueLiteralRows.full_text(entries, open_bracket, humanize)
	var base_meta: Dictionary = {
		"lane": "action",
		"kind": "action",
		"ace_index": action_index,
		"ace_enabled": true,
		"chip": true,
		"raw_action": true,
		"code_cell": false,
		"line_index": line_index,
		"hoverable": true,
		"literal_full_text": full_text
	}
	if show_word:
		spans.append(_make_span(EventSheetL10n.translate("table" if open_bracket == "{" else "list"),
			SemanticSpan.SpanType.VALUE, base_meta.duplicate().merged({
				"natural_width": true,
				"text_color": _viewport._get_event_style().object_label_color
			}, true).merged(action_style_meta, false)))
	var folded: bool = entries.size() > EventSheetValueLiteralRows.FOLD_AT
	var shown: int = EventSheetValueLiteralRows.FOLD_AT if folded else entries.size()
	for entry_index: int in shown:
		var entry: Dictionary = entries[entry_index] as Dictionary
		var last: bool = close_cell and not folded and entry_index == shown - 1
		var chip_meta: Dictionary = base_meta.duplicate()
		chip_meta["text_color"] = _viewport._get_event_style().value_highlight_color
		if not last:
			chip_meta["natural_width"] = true
		# A chip edits the one row its entry was lifted from, so a table written over ten lines is
		# ten independently editable values rather than one blob of code.
		if (entry.get("nested", []) as Array).is_empty():
			chip_meta["editable"] = true
			chip_meta["edit_kind"] = "literal_entry_line:%d:%d" % [action_index, int(entry.get("row", -1))]
			# The field opens on the FILE's own spelling, not on the reading: a chip that reads
			# `span index = 3` is written `"span_index": 3`, and editing the reading would quietly
			# turn a quoted key into a bare one.
			chip_meta["edit_text"] = EventSheetValueLiteralRows.chip_text(entry, false)
		spans.append(_make_span(EventSheetValueLiteralRows.chip_text(entry, humanize),
			SemanticSpan.SpanType.VALUE, chip_meta.merged(action_style_meta, false)))
	if not folded:
		return
	var more_meta: Dictionary = base_meta.duplicate()
	more_meta["text_color"] = _viewport._get_reading_style().muted_text_color
	if not close_cell:
		more_meta["natural_width"] = true
	spans.append(_make_span("… %s" % (EventSheetL10n.translate("%d more") % (entries.size() - shown)),
		SemanticSpan.SpanType.VALUE, more_meta.merged(action_style_meta, false)))


## The lead row of a literal run whose flattened statement no sentence claimed: the head line
## reads as itself and the chips still follow it, so the entries are named either way.
func _append_value_literal_spans(spans: Array, literal: Dictionary, action_index: int,
		line_index: int, action_style_meta: Dictionary) -> void:
	var synthetic := RawCodeRow.new()
	synthetic.code = str(literal.get("statement", ""))
	if _append_sentence_spans(spans, synthetic, action_index, line_index, action_style_meta, literal):
		return
	var head_text: String = synthetic.code.strip_edges().replace(
		EventSheetValueLiteralRows.LITERAL_TOKEN, "").strip_edges()
	if not head_text.is_empty():
		spans.append(_make_span(head_text, SemanticSpan.SpanType.VALUE, {
			"lane": "action",
			"kind": "action",
			"ace_index": action_index,
			"ace_enabled": true,
			"chip": true,
			"raw_action": true,
			"code_cell": false,
			"natural_width": true,
			"line_index": line_index
		}.merged(action_style_meta, false)))
	_append_literal_chip_spans(spans, literal, action_index, line_index, action_style_meta, true)


## The event-sheet local-variable row: a type-word chip, the name, and the starting value. Shared by the
## hand-written `var` line and by the Local Variable ACE, so a local reads the same however it got
## there. `base_meta` carries the row identity (which lane, which action index) and `style_meta` the
## cell chrome; the LAST span omits natural_width so the cell background closes the row.
## `literal` is the multi-line table or list the local was declared from, when there is one -
## the starting value is then the entry chips rather than one blob of text.
func append_local_declaration_spans(spans: Array, declaration: Dictionary, base_meta: Dictionary, style_meta: Dictionary, literal: Dictionary = {}) -> void:
	var indent_text: String = "    ".repeat(int(declaration.get("indent", 0)))
	var type_word: String = str(declaration.get("type_word", ""))
	# An untyped `var x := {` says nothing about what x is, but the literal it opens says
	# exactly what it is: the chip reads `Local table` / `Local list` rather than `Local value`.
	if not literal.is_empty() and type_word == EventSheetL10n.translate("value"):
		type_word = EventSheetL10n.translate("table" if str(literal.get("open", "{")) == "{" else "list")
	var chip_word: String = "%s %s" % [
		EventSheetL10n.translate("Local constant") if bool(declaration.get("is_constant", false)) else EventSheetL10n.translate("Local"),
		type_word
	]
	var chip_meta: Dictionary = base_meta.duplicate()
	chip_meta["chip"] = true
	chip_meta["natural_width"] = true
	chip_meta["text_color"] = _viewport._get_event_style().object_label_color
	spans.append(_make_span(indent_text + chip_word, SemanticSpan.SpanType.VALUE, chip_meta.merged(style_meta, false)))
	var name_meta: Dictionary = base_meta.duplicate()
	name_meta["chip"] = true
	name_meta["natural_width"] = true
	name_meta["text_color"] = _viewport._get_reading_style().primary_text_color
	spans.append(_make_span(str(declaration.get("name", "")), SemanticSpan.SpanType.VALUE, name_meta.merged(style_meta, false)))
	if not literal.is_empty():
		# The declared value IS the literal, so there is nothing to print between the name and the
		# entries: the chips are the starting value, one per line the file wrote it over.
		_append_literal_chip_spans(spans, literal, int(base_meta.get("ace_index", -1)),
			int(base_meta.get("line_index", 0)), style_meta, true, false)
		return
	var value_meta: Dictionary = base_meta.duplicate()
	value_meta["chip"] = true
	value_meta["text_color"] = _viewport._get_event_style().value_highlight_color
	spans.append(_make_span("= %s" % str(declaration.get("value", "")), SemanticSpan.SpanType.VALUE, value_meta.merged(style_meta, false)))
	# A `var x = 1  # note` carries its note the same way every other row does - at the end, muted -
	# rather than inside the value, where it read as part of the starting value.
	var declaration_note: String = str(declaration.get("note", ""))
	if declaration_note.is_empty():
		return
	var note_meta: Dictionary = base_meta.duplicate()
	note_meta["chip"] = true
	note_meta["natural_width"] = true
	note_meta["editable"] = false
	note_meta["text_color"] = _viewport._get_reading_style().muted_text_color
	spans.append(_make_span("💬 %s" % declaration_note, SemanticSpan.SpanType.COMMENT,
		note_meta.merged(style_meta, false)))


# One-shot object label recorded by a descriptor formatter when the row's shape names its own object
# (`host` for a destroy, `Keyboard` for an input check). Same one-shot discipline as
# _pending_display_bbcode: the formatter writes it, the span site consumes AND clears it, and the two
# always run back to back (the descriptor is the first argument of the _make_span call whose metadata
# reads the label).
var _pending_object_label: String = ""
# One-shot tone segments from the same reading, so a grammar-read ACE row is tinted exactly like the
# hand-written line beside it. Consumed and cleared by _make_span, and attached only when the text
# still matches - a formatter suffix (an ACE note) or prefix (the await hourglass) degrades to no
# tinting rather than to segments that no longer line up with the characters.
var _pending_grammar_segments: Array = []
# The sheet the cached sentence context was built for, so a tab switch rebuilds it.
var _sentence_context_sheet: Resource = null
var _sentence_context_cache: Dictionary = {}
# Whether the open sheet is a pack recipe, remembered per sheet. Asked once per EVENT in both
# the span pass and its line-count twin, and the answer is a fact about the FILE - so asking the
# sentence context each time (which duplicates the whole context dictionary) would put a copy of it
# on the paint path for every event in every ordinary game script, which is exactly what this is not.
var _recipe_sheet_seen: Resource = null
var _recipe_sheet_is: bool = false


## The behavior-shape reading of a ROW - whether the importer lifted a typed line
## into it or the picker wrote it. The row's params are put back into the line the row stands for and
## read through the shape grammar, which is the same text a user who never let the importer touch the
## file would have. {} when no shape claims it, and the row keeps the reading it already had.
func behavior_shape_action_sentence(ace_id: String, params_dict: Dictionary,
		context: Dictionary) -> Dictionary:
	var code: String = EventSheetBehaviorShapes.line_for(ace_id, params_dict)
	return {} if code.is_empty() else EventSheetBehaviorShapes.statement(code, context)


## The same for a CONDITION row.
func behavior_shape_condition_sentence(ace_id: String, params_dict: Dictionary,
		context: Dictionary) -> Dictionary:
	var code: String = EventSheetBehaviorShapes.line_for(ace_id, params_dict, true)
	return {} if code.is_empty() else EventSheetBehaviorShapes.condition(code, context)


## The rows batch thirteen added whose sentence is the SHARED one: each of
## them writes exactly the line its reading recognises, so the row is read by compiling it back and
## asking the grammar rather than by its own display template. That is what keeps a picked row and a
## typed line one sentence - the parity the two-way byte gate proves.
##
## Frozen alongside the ace ids themselves: adding a row here is what opts it into the shared
## sentence, and a row that is not here keeps its descriptor's words exactly as before.
const GRAMMAR_READ_ACE_IDS: PackedStringArray = [
	"OrbitAtRadius", "SetCameraDistance",
	"PlayOneShotAnimation",
	"AudioSetHearingDistance3D", "AudioSetLoudnessFalloff",
	"SetSeeThrough", "SetShadowsOff3D", "SetShadowsOn3D",
	"SetFog", "SetFogDensity", "SetFogColour", "SetGlow", "SetGlowStrength",
	"SetAmbientOcclusion", "SetSkyRotation",
	"SetFaceTheCamera", "SetFaceTheCameraUpright", "SetShowThroughWalls", "SetWorldSize",
	"SetBarWidth", "SendInputToSurface", "SetSurfaceRedraw"
]


## The shared-grammar reading of an ACE ACTION whose shape a hand-written line can also have, or {}
## when this row has no such twin. The point is symmetry: `Destroy`, `Signal On Jumped`, `Set hp to 0`
## must be one sentence, whether the row came out of the picker or out of the user's own .gd file.
## A reading's [text, tone] pieces as the {text, tone} segments a grammar sentence hands back. The
## two shapes say the same thing and both are read here; converting in one place keeps a caller from
## quietly growing a third.
static func _grammar_tone_segments(pieces: Array) -> Array:
	var segments: Array = []
	for piece: Variant in pieces:
		segments.append({"text": str((piece as Array)[0]), "tone": str((piece as Array)[1])})
	return segments


func grammar_action_sentence(action: ACEAction) -> Dictionary:
	if action == null or not (action.provider_id.is_empty() or action.provider_id == "Core"):
		return {}
	var params_dict: Dictionary = action.params if not action.params.is_empty() else action.parameters
	var context: Dictionary = sentence_context()
	# A local whose starting value has to be worked out reads as the two rows an event sheet
	# writes: the declaration at the top of the event, and - here - the Set that fills it in.
	var promotion: Dictionary = local_declaration_promotion(action)
	if not promotion.is_empty() and not str(promotion.get("set_value", "")).is_empty():
		var declaration: Dictionary = promotion.get("declaration", {})
		return EventSheetSentence.statement("%s = %s" % [
			str(declaration.get("name", "")), str(declaration.get("raw_value", ""))], context)
	# ── lens hook ──────────────────────────────────────────────────────────────────────────────
	# A line the importer claimed for a shipped row is still the behavior SHAPE it was, so the row
	# reads in that behavior's words - but only when the shape actually claims it. A row no shape
	# claims falls straight through to the reading it already had, which is why routing these three
	# ace ids here cannot move anything that does not belong to a projectile or a glide.
	# ───────────────────────────────────────────────────────────────────────────────────────────
	# A place written as a circle around somebody is an ORBIT, and it is asked before the shape
	# lookup below for the same reason the typed line asks it before the shapes: the importer files
	# `me = you.global_position + <offset>` as a Pin, and "pinned to you at an offset" is true of one
	# frame of an orbit and a plain lie about the rest of them.
	var shape_line: String = EventSheetBehaviorShapes.line_for(action.ace_id, params_dict)
	if not shape_line.is_empty():
		var circled: Dictionary = EventSheetSentence.orbit_placement_assignment_of(shape_line, context)
		if not circled.is_empty():
			return circled
	var shaped: Dictionary = behavior_shape_action_sentence(action.ace_id, params_dict, context)
	if not shaped.is_empty():
		return shaped
	# ── lens hook ──────────────────────────────────────────────────────────────────────────────
	# A board's push and its ollie are ordinary property writes, so the importer files them as
	# Set rows before any reading gets a look - and "Set velocity Y to -ollie speed" is a true
	# sentence about a line and says nothing at all about what the player just did. Re-reading the
	# line the row compiles to is what makes the picked row and the typed line say one thing. Safe
	# for every other project by construction: the reading is gated on this file having projected
	# gravity along the floor normal, or having ridden a curve by its closest offset.
	# The facts are checked BEFORE the line is generated: generating a row's code is not free, and
	# this runs for every action on every row of every sheet. A project with no board in it pays two
	# dictionary lookups and nothing else.
	if not (context.get("skate", {}) as Dictionary).is_empty() \
			or not (context.get("grind", {}) as Dictionary).is_empty():
		var board_line: String = ActionCodegen.generate_action(action)
		if not board_line.is_empty() and not board_line.contains("\n"):
			var board: Dictionary = EventSheetSentence.skate_statement(board_line.strip_edges(), context)
			if not board.is_empty():
				return board
	# ───────────────────────────────────────────────────────────────────────────────────────────
	# The batch-thirteen rows whose reading IS the grammar's reading of the line they compile to.
	# Routing them here rather than letting each keep its descriptor's display template is what makes
	# the promise hold in BOTH directions: the row a user drops from the picker and the line the same
	# user could have typed by hand say the one sentence, with the same object in front of it and the
	# same half-word after it. A row that compiles to more than one line is left alone - its own
	# display template is the only thing that can say what a multi-line row does.
	if Array(GRAMMAR_READ_ACE_IDS).has(action.ace_id):
		var compiled: String = ActionCodegen.generate_action(action)
		if not compiled.is_empty() and not compiled.contains("\n"):
			var read_as_typed: Dictionary = EventSheetSentence.statement(compiled.strip_edges(), context)
			if not read_as_typed.is_empty():
				return read_as_typed
	match action.ace_id:
		"SetVar":
			return EventSheetSentence.statement("%s = %s" % [
				str(params_dict.get("var_name", "")), str(params_dict.get("value", ""))], context)
		# Adding to TEXT puts the value on the end, which is the Append the Text module ships and
		# not the arithmetic "Add". Only the grammar can tell the two apart, because only it knows what
		# the sheet declared the variable to be.
		"AddVar":
			return EventSheetSentence.statement("%s += %s" % [
				str(params_dict.get("var_name", "")), str(params_dict.get("amount", ""))], context)
		"EmitSignal":
			return EventSheetSentence.signal_sentence(
				str(params_dict.get("signal_name", "")), str(params_dict.get("args", "")), context)
		"QueueFree":
			return EventSheetSentence.statement("queue_free()", context)
		# The importer claims `$Timer.start(2.0)` as this row, so the row has to say what the
		# typed line says - otherwise an opened file reads one way before the lift and another after
		# it. The node path IS the tag, and the mode comes off the file's own `one_shot` line.
		"StartTimer", "StopTimer":
			var timer_code: String = timer_ace_code(action.ace_id, params_dict)
			return {} if timer_code.is_empty() else EventSheetSentence.statement(timer_code, context)
		"CallMethod":
			# A generic call reads as one of the settled sentences when it has one
			# (`call_deferred("queue_free")` is a destroy) - and otherwise as the Object ▸ Verb
			# chips, which is exactly what the same call typed by hand now reads.
			var call_code: String = "%s.%s(%s)" % [
				str(params_dict.get("target", "")), str(params_dict.get("method", "")),
				str(params_dict.get("args", ""))]
			var settled: Dictionary = EventSheetSentence.statement(call_code, context)
			if not settled.is_empty():
				return settled
			# ── lens hook ──────────────────────────────────────────────────────────────────────
			# THE DERIVED LAYER, on the shape it matters most for. The importer files an ordinary
			# call as this row through the statement catch-all - the lowest-specificity claim there
			# is, and not a curated one - so a Call Method row IS the derived layer's territory:
			# where the sheet can know the receiver's class, the chips take the method's own
			# parameter names, the row carries the method's own words, and it reads in the plainer
			# derived style. A settled sentence above it still wins outright, which is the whole
			# ordering: curated first, derived second, the general reading last.
			var derived_call: Dictionary = EventSheetDerivedCalls.derived_pieces(
				call_code, context, _reading_class_map(), _reading_autoloads())
			if not derived_call.is_empty():
				_pending_derived_ace = derived_call
				return {"object": str(derived_call.get("object", "")),
					"segments": _grammar_tone_segments(derived_call.get("pieces", []) as Array)}
			var generic_call: Dictionary = EventSheetViewportReadingRows.generic_call_pieces(
				call_code, context, _reading_class_map())
			if generic_call.is_empty():
				return {}
			return {"object": str(generic_call.get("object", "")),
				"segments": _grammar_tone_segments(generic_call.get("pieces", []) as Array)}
		# ── lens hook (groups as families) ────────────────────────────────────────────────────
		# The picked group rows read the same words a typed `add_to_group(...)` /
		# `get_tree().call_group(...)` now reads, so the family vocabulary is one sentence either way.
		"AddToGroup":
			return EventSheetSentence.statement("%s.add_to_group(%s)" % [
				str(params_dict.get("target", "self")), str(params_dict.get("group", ""))], context)
		"RemoveFromGroup":
			return EventSheetSentence.statement("%s.remove_from_group(%s)" % [
				str(params_dict.get("target", "self")), str(params_dict.get("group", ""))], context)
		"CallGroup":
			return EventSheetSentence.statement("get_tree().call_group(%s, %s)" % [
				str(params_dict.get("group", "")), str(params_dict.get("method", ""))], context)
		"CallGroupWith":
			var group_args: String = str(params_dict.get("args", "")).strip_edges()
			var group_call: String = "get_tree().call_group(%s, %s%s)" % [
				str(params_dict.get("group", "")), str(params_dict.get("method", "")),
				"" if group_args.is_empty() else ", %s" % group_args]
			return EventSheetSentence.statement(group_call, context)
		"QueueFreeNode":
			return EventSheetSentence.statement("%s.queue_free()" % str(params_dict.get("target", "self")), context)
		# The importer claims a `RenderingServer.global_shader_parameter_set(...)` line as this
		# row, so the row has to say what the typed line says - otherwise an opened file reads one way
		# before the lift and another after it.
		"RenderingSetGlobalShaderParam":
			return EventSheetSentence.statement(
				"RenderingServer.global_shader_parameter_set(%s, %s)" % [
					str(params_dict.get("name", "")), str(params_dict.get("value", ""))], context)
		# ── lens hook (the hierarchy) ─────────────────────────────────────────────────────────────
		# The picked hierarchy rows read the words a hand-typed `item.reparent($Hand)` now reads, so
		# Add child is one sentence whether it was dropped from the picker or written by hand - and
		# the keep-its-place half never depends on which way the row got onto the sheet.
		# The importer claims every `x.reparent(y)` for this row, so without the same lens an opened
		# file would read a pick-up as a layer move. The grammar decides which of the two it is: the
		# layer words when the new parent IS a known drawing layer, the hierarchy's own otherwise.
		"MoveToLayer":
			var mover: String = str(params_dict.get("target", "")).strip_edges()
			return EventSheetSentence.statement("%sreparent(%s)" % [
				"" if mover.is_empty() else "%s." % mover,
				str(params_dict.get("layer", ""))], context)
		"HierarchyAddChild":
			var keep_place: String = str(params_dict.get("keep", "")).strip_edges()
			return EventSheetSentence.reparent_sentence(
				EventSheetSentence.object_of_reference(str(params_dict.get("child", ""))),
				str(params_dict.get("parent", "")), keep_place, context)
		"HierarchyRemoveFromParent", "ReparentNode":
			var moved: String = str(params_dict.get("child", "")).strip_edges()
			if moved.is_empty():
				moved = "self"
			return EventSheetSentence.statement("%s.reparent(%s)" % [moved,
				str(params_dict.get("new_parent", "get_tree().current_scene"))], context)
		"SetIgnoreParentMovement":
			return EventSheetSentence.statement("%s.top_level = %s" % [
				str(params_dict.get("target", "self")), str(params_dict.get("ignore", "true"))], context)
		"CopyPlaceTo":
			return EventSheetSentence.statement("%s.remote_path = NodePath(%s)" % [
				str(params_dict.get("follower", "")), str(params_dict.get("path", ""))], context)
		"StopCopyingPlace":
			return EventSheetSentence.statement("%s.remote_path = NodePath(\"\")" % str(
				params_dict.get("follower", "")), context)
		# A tint set from the tint itself is an EASE, and the grammar is the only place that can
		# see it: the row holds one value, and only the shape of that value says it eases. Every other
		# tint row keeps the descriptor's own words, which is why this returns {} unless it matches.
		"SetModulate":
			var tint_target: String = str(params_dict.get("target", "")).strip_edges()
			return EventSheetSentence.colour_ease_statement(
				EventSheetSentence.object_of_reference(tint_target) if not tint_target.is_empty()
					else EventSheetSentence.script_object(context),
				"modulate", str(params_dict.get("color", "")), context)
		# ── lens hook ─────────────────────────────────────────────────────────────────────────
		# Two rows whose words depend on something only the grammar can see. `erase` is spelled the
		# same on a list and on a table but means two different steps, and the lifter cannot tell
		# which; the grammar reads the sheet's own declared type and says "value" or "key". A process
		# mode written as a NUMBER is an enum member, and the grammar knows the engine's names for it.
		"DictDeleteKey":
			return EventSheetSentence.statement("%s.erase(%s)" % [
				str(params_dict.get("var_name", "")), str(params_dict.get("key", ""))], context)
		"NodeSetProcessMode":
			var mode_target: String = str(params_dict.get("target", "")).strip_edges()
			return EventSheetSentence.statement("%sprocess_mode = %s" % [
				"" if mode_target.is_empty() else "%s." % mode_target,
				str(params_dict.get("mode", ""))], context)
		"ChangeScene":
			return EventSheetSentence.statement(
				"get_tree().change_scene_to_file(%s)" % str(params_dict.get("path", "")), context)
		"ReturnEarly":
			return EventSheetSentence.return_sentence("", context)
		"ReturnValue":
			return _named_return_sentence(
				EventSheetSentence.return_sentence(str(params_dict.get("value", "")), context),
				str(params_dict.get("value", "")))
		# A node-scoped place setter names the node it moves - a loop variable, a local object -
		# so the row reads on THAT object, in the same words the typed `n.position = …` line reads.
		# Without this the row wore the vocabulary's class name ("Node2D") no matter which node it
		# actually set, which is the one thing the object column exists to answer.
		"SetPosition2D", "SetPosition3D":
			return EventSheetSentence.statement("%s.position = %s" % [
				_ace_target(params_dict), str(params_dict.get("pos", ""))], context)
		"SetProperty":
			return EventSheetSentence.statement("%s.%s = %s" % [
				str(params_dict.get("target", "")), str(params_dict.get("property", "")),
				str(params_dict.get("value", ""))], context)
		# ── lens hook ────────────────────────────────────────────────────────────────────────────
		# The importer files `$CollisionShape2D.disabled = true` under this row, and a collision shape
		# switched off is the object's Solid going away - the word a reader looks for on a platform
		# that opens. Only a COLLISION SHAPE is routed: on a real button this row keeps its own
		# sentence, which is the one a reader of a menu wants.
		"SetButtonDisabled":
			if not EventSheetSentence.is_collision_shape_reference(
					str(params_dict.get("target", "")), context):
				return {}
			return EventSheetSentence.statement("%s.disabled = %s" % [
				str(params_dict.get("target", "")), str(params_dict.get("disabled", ""))], context)
		"AddToProperty":
			return EventSheetSentence.statement("%s.%s += %s" % [
				str(params_dict.get("target", "")), str(params_dict.get("property", "")),
				str(params_dict.get("value", ""))], context)
		# ── lens hook (behaviour words on the picked rows too) ───────────────────────────────────
		# These are the rows a hand-written camera / emitter / collision line LIFTS to, so without
		# these five the reading would depend on whether the lifter happened to claim the line - the
		# one thing the shared grammar exists to prevent.
		"MakeCameraCurrent":
			return EventSheetSentence.statement("%s.make_current()" % _ace_target(params_dict), context)
		# ── lens hook ────────────────────────────────────────────────────────────────────────────
		# The rows a hand-written effect / tilemap / camera line LIFTS to. Without these the reading
		# would depend on whether the lifter happened to claim the line, which is the one thing the
		# shared grammar exists to prevent - and the pattern the reading claims would be lost with it.
		"SetShaderParameter":
			return EventSheetSentence.statement("%s.material.set_shader_parameter(%s, %s)" % [
				_ace_target(params_dict), str(params_dict.get("param", "")),
				str(params_dict.get("value", ""))], context)
		"SetShaderMaterial":
			return EventSheetSentence.statement("%s.material = %s" % [
				_ace_target(params_dict), str(params_dict.get("material", ""))], context)
		"ClearMaterial":
			return EventSheetSentence.statement("%s.material = null" % _ace_target(params_dict), context)
		"TweenEffectParameter":
			return EventSheetSentence.statement(
				"create_tween().tween_method(func(v): %s.material.set_shader_parameter(%s, v), %s, %s, %s)" % [
					_ace_target(params_dict), str(params_dict.get("param", "")),
					str(params_dict.get("from", "")), str(params_dict.get("to", "")),
					str(params_dict.get("seconds", ""))], context)
		# The tilemap rows rebuild the call from their parameters in order, which is exactly the line
		# the file holds - including the older node spelling, whose layer the lifter files as part of
		# the first parameter.
		"TileMapSetCell":
			return EventSheetSentence.statement("%s.set_cell(%s, %s, %s)" % [
				_ace_target(params_dict), str(params_dict.get("coords", "")),
				str(params_dict.get("source_id", "")), str(params_dict.get("atlas_coords", ""))], context)
		"TileMapEraseCell":
			return EventSheetSentence.statement("%s.erase_cell(%s)" % [
				_ace_target(params_dict), str(params_dict.get("coords", ""))], context)
		"SetCameraSmoothing":
			return EventSheetSentence.statement("%s.position_smoothing_enabled = %s" % [
				_ace_target(params_dict), str(params_dict.get("enabled", ""))], context)
		"CameraScrollToward":
			var camera_target: String = _ace_target(params_dict)
			return EventSheetSentence.statement(
				"%s.global_position = %s.global_position.lerp(%s.global_position, %s * get_process_delta_time())" % [
					camera_target, camera_target, str(params_dict.get("toward", "")),
					str(params_dict.get("rate", ""))], context)
		"SetCameraZoom":
			return EventSheetSentence.statement("%s.zoom = %s" % [
				_ace_target(params_dict), str(params_dict.get("zoom", ""))], context)
		"SetEmitting", "SetEmittingCPU":
			return EventSheetSentence.statement("%s.emitting = %s" % [
				_ace_target(params_dict), str(params_dict.get("emitting", ""))], context)
		"RestartParticles", "RestartParticlesCPU":
			return EventSheetSentence.statement("%s.restart()" % _ace_target(params_dict), context)
		"SetCollisionMaskBit":
			return EventSheetSentence.statement("%s.set_collision_mask_value(%s, %s)" % [
				_ace_target(params_dict), str(params_dict.get("mask", "")),
				str(params_dict.get("enabled", ""))], context)
		"SetCollisionLayerBit":
			return EventSheetSentence.statement("%s.set_collision_layer_value(%s, %s)" % [
				_ace_target(params_dict), str(params_dict.get("layer", "")),
				str(params_dict.get("enabled", ""))], context)
		# ── lens hook (the JSON object owns its two verbs) ───────────────────────────────────────
		"JsonParseToVar":
			return EventSheetSentence.statement("%s = JSON.parse_string(%s)" % [
				str(params_dict.get("var_name", "")), str(params_dict.get("text", ""))], context)
		# ── lens hook (the debug verbs) ──────────────────────────────────────────────────────────
		# The picked debug rows read the same words a typed `push_error(...)` / `assert(...)` now
		# reads, so the log vocabulary is one sentence whichever way the row got onto the sheet.
		"PushError":
			return EventSheetSentence.statement("push_error(%s)" % str(params_dict.get("message", "")), context)
		"PushWarning":
			return EventSheetSentence.statement("push_warning(%s)" % str(params_dict.get("message", "")), context)
		"PrintRich":
			return EventSheetSentence.statement("print_rich(%s)" % str(params_dict.get("value", "")), context)
		"Assert":
			return EventSheetSentence.statement("assert(%s, %s)" % [
				str(params_dict.get("condition", "")), str(params_dict.get("message", ""))], context)
		"CallFunction":
			# A receiver-less call the sheet has no verb of its own for. Only the settled shapes claim
			# it (the debug verbs among them); a call to one of THIS sheet's functions is not one of
			# them, so it falls straight through to its own Call reading.
			return EventSheetSentence.statement("%s(%s)" % [
				str(params_dict.get("function_name", "")), str(params_dict.get("args", ""))], context)
		"Breakpoint":
			# The picked pause row wears the same gutter mark the typed keyword does, and says as
			# little: the flag is raised here because this row never goes through the raw-line path.
			_pending_grammar_breakpoint = true
			return EventSheetSentence.statement("breakpoint", context)
		# ── lens hook ─────────────────────────────────────────────────────────────────────────
		# The picked rows whose hand-written twin now reads in the event-sheet verbs: an animation,
		# a sound, a visibility switch, an angle, a size, a property set by name. Each hands the
		# grammar the exact line the ACE compiles to, so the two readings cannot drift apart.
		"HideNode":
			return EventSheetSentence.statement("%s.hide()" % _ace_target(params_dict), context)
		"ShowNode":
			return EventSheetSentence.statement("%s.show()" % _ace_target(params_dict), context)
		"SetFlipH":
			return EventSheetSentence.statement("%s.flip_h = %s" % [
				_ace_target(params_dict), str(params_dict.get("flipped", ""))], context)
		# ── lens hook ────────────────────────────────────────────────────────────────────────
		# The facing rows. Set Flipped joins them here: it shipped without an arm, so the picked
		# row and the typed `flip_v = true` said the same thing by luck rather than by contract.
		# The host twins all hand over the same line their own host writes, so "Set mirrored" is
		# one sentence whether the reader picked it on a sprite, an image or a 3D billboard.
		"SetFlipV":
			return EventSheetSentence.statement("%s.flip_v = %s" % [
				_ace_target(params_dict), str(params_dict.get("flipped", ""))], context)
		"SetMirroredSprite2D", "SetMirroredSprite3D", "SetMirroredTextureRect":
			return EventSheetSentence.statement("%s.flip_h = %s" % [
				_ace_target(params_dict), str(params_dict.get("mirrored", ""))], context)
		"SetFlippedSprite3D", "SetFlippedTextureRect", "SetFlippedAnimatedSprite2D":
			return EventSheetSentence.statement("%s.flip_v = %s" % [
				_ace_target(params_dict), str(params_dict.get("flipped", ""))], context)
		"SetMirroredObject":
			return EventSheetSentence.statement("%s.scale.x = -1.0 if %s else 1.0" % [
				_ace_target(params_dict), str(params_dict.get("mirrored", ""))], context)
		"FaceObject":
			return EventSheetSentence.statement(
				"%s.scale.x = -1.0 if %s.global_position.x < global_position.x else 1.0" % [
				_ace_target(params_dict), str(params_dict.get("object", ""))], context)
		"KeepUpright":
			return EventSheetSentence.statement("%s.scale.x = signf(scale.x)" % [
				str(params_dict.get("target", "self"))], context)
		"TurnAround":
			return EventSheetSentence.statement("%s.rotate_y(PI)" % _ace_target(params_dict), context)
		"SetRotationDeg":
			return EventSheetSentence.statement("%s.rotation_degrees = %s" % [
				_ace_target(params_dict), str(params_dict.get("degrees", ""))], context)
		"SetScale3D":
			return EventSheetSentence.statement("%s.scale = %s" % [
				_ace_target(params_dict), str(params_dict.get("scale", ""))], context)
		"PlaySpriteAnimation":
			return EventSheetSentence.statement("%s.play(%s)" % [
				_ace_target(params_dict), str(params_dict.get("anim", ""))], context)
		"StopSpriteAnimation", "AudioStop":
			return EventSheetSentence.statement("%s.stop()" % _ace_target(params_dict), context)
		"AudioPlay":
			return EventSheetSentence.statement("%s.play(%s)" % [
				_ace_target(params_dict), str(params_dict.get("from", ""))], context)
		"LookAt3D":
			return EventSheetSentence.statement("look_at(%s)" % str(params_dict.get("target", "")), context)
		"SetTreeParam":
			return EventSheetSentence.statement("%s.set(%s, %s)" % [
				_ace_target(params_dict), str(params_dict.get("path", "")),
				str(params_dict.get("value", ""))], context)

		# ── lens hook ───────────────────────────────────────────────────────────────────────────
		# The rows a hand-written sprite, UI, sound or juice line LIFTS to. Without these the reading
		# would depend on whether the lifter happened to claim the line, which is the one thing the
		# shared grammar exists to prevent: each hands the grammar the exact line the ACE compiles to.
		"SetSpriteFrame":
			return EventSheetSentence.statement("%s.frame = %s" % [
				_ace_target(params_dict), str(params_dict.get("frame", ""))], context)
		"SetAnimationSpeed":
			return EventSheetSentence.statement("%s.speed_scale = %s" % [
				_ace_target(params_dict), str(params_dict.get("scale", ""))], context)
		"SetSpriteTexture":
			return EventSheetSentence.statement("%s.texture = load(%s)" % [
				_ace_target(params_dict), str(params_dict.get("path", ""))], context)
		"TravelToState":
			return EventSheetSentence.statement("%s.get(\"parameters/playback\").travel(%s)" % [
				_ace_target(params_dict), str(params_dict.get("state", ""))], context)
		"GrabFocus":
			return EventSheetSentence.statement("%s.grab_focus()" % _ace_target(params_dict), context)
		"ShowDialogCentred":
			return EventSheetSentence.statement("%s.popup_centered()" % _ace_target(params_dict), context)
		"SetMasterVolume":
			return EventSheetSentence.statement("AudioServer.set_bus_volume_db(0, linear_to_db(%s))"
				% str(params_dict.get("level", "")), context)
		"AudioSetStream":
			return EventSheetSentence.statement("%s.stream = load(%s)" % [
				_ace_target(params_dict), str(params_dict.get("path", ""))], context)
		"AudioSetPitch":
			return EventSheetSentence.statement("%s.pitch_scale = %s" % [
				_ace_target(params_dict), str(params_dict.get("pitch", ""))], context)
		"AudioSetBus":
			return EventSheetSentence.statement("%s.bus = %s" % [
				_ace_target(params_dict), str(params_dict.get("bus", ""))], context)
		"AudioSetVolume":
			return EventSheetSentence.statement("%s.volume_db = %s" % [
				_ace_target(params_dict), str(params_dict.get("db", ""))], context)
		"AudioSetVolumeLevel":
			return EventSheetSentence.statement("%s.volume_db = linear_to_db(%s)" % [
				_ace_target(params_dict), str(params_dict.get("level", ""))], context)
		"AudioSeek":
			return EventSheetSentence.statement("%s.seek(%s)" % [
				_ace_target(params_dict), str(params_dict.get("seconds", ""))], context)
		"SetCameraOffset":
			return EventSheetSentence.statement("%s.offset = %s" % [
				_ace_target(params_dict), str(params_dict.get("offset", ""))], context)
		"CameraShakeOnce":
			return EventSheetSentence.statement(
				"%s.offset = Vector2(randf_range(-%s, %s), randf_range(-%s, %s))" % [
					_ace_target(params_dict), str(params_dict.get("amount", "")),
					str(params_dict.get("amount", "")), str(params_dict.get("amount", "")),
					str(params_dict.get("amount", ""))], context)
		"BobY":
			return EventSheetSentence.statement("position.y = %s + sin(%s * %s) * %s" % [
				str(params_dict.get("base", "")), str(params_dict.get("time", "")),
				str(params_dict.get("frequency", "")), str(params_dict.get("magnitude", ""))], context)
		"EaseSizeBack":
			return EventSheetSentence.statement("scale = scale.lerp(Vector2.ONE, %s * delta)"
				% str(params_dict.get("rate", "")), context)
		"SubtractFromProperty":
			return EventSheetSentence.statement("%s.%s -= %s" % [
				str(params_dict.get("target", "self")), str(params_dict.get("property", "")),
				str(params_dict.get("value", ""))], context)
		# The three the Familiar Words glossary renames. Claimed ONLY while the glossary is on, so
		# with it off each row keeps the vocabulary's own wording, untouched.
		"ReloadScene":
			if not bool(context.get("familiar_words", false)):
				return {}
			return EventSheetSentence.statement("get_tree().reload_current_scene()", context)
		"SetPaused":
			if not bool(context.get("familiar_words", false)):
				return {}
			return EventSheetSentence.statement("get_tree().paused = %s" % str(params_dict.get("paused", "")), context)
		"SetTimeScale":
			if not bool(context.get("familiar_words", false)):
				return {}
			return EventSheetSentence.statement("Engine.time_scale = %s" % str(params_dict.get("scale", "")), context)
		# ── lens hook ────────────────────────────────────────────────────────────────────────────
		# The tick switches and the process mode, and the one-shot timer's "wait, then". Each is
		# rebuilt as the exact line it compiles to and handed to the same grammar the typed line goes
		# through, so a picked row and a hand-written one cannot say two different things.
		"NodeSetProcessing":
			return EventSheetSentence.statement("%s.set_process(%s)" % [
				_ace_target(params_dict), str(params_dict.get("on", ""))], context)
		"NodeSetPhysicsProcessing":
			return EventSheetSentence.statement("%s.set_physics_process(%s)" % [
				_ace_target(params_dict), str(params_dict.get("on", ""))], context)
		"NodeSetInputProcessing":
			return EventSheetSentence.statement("%s.set_process_input(%s)" % [
				_ace_target(params_dict), str(params_dict.get("on", ""))], context)
		"NodeSetUnhandledInputProcessing":
			return EventSheetSentence.statement("%s.set_process_unhandled_input(%s)" % [
				_ace_target(params_dict), str(params_dict.get("on", ""))], context)
		"NodeSetProcessMode":
			return EventSheetSentence.statement("%s.process_mode = %s" % [
				_ace_target(params_dict), str(params_dict.get("mode", ""))], context)
		"CallAfterDelay":
			return EventSheetSentence.statement("get_tree().create_timer(%s).timeout.connect(%s)" % [
				str(params_dict.get("seconds", "")), str(params_dict.get("callable", ""))], context)
		"CallLater":
			# This one's parameter is a STATEMENT, not a callable - the template wraps it in the lambda
			# itself, so the reading rebuilds the same wrapper before reading it.
			return EventSheetSentence.statement("get_tree().create_timer(%s).timeout.connect(func(): %s)" % [
				str(params_dict.get("seconds", "")), str(params_dict.get("do", ""))], context)
		"AwaitNextFrame":
			return await_reading("get_tree().process_frame", false, context)
		"AwaitSignal":
			return await_reading(str(params_dict.get("signal_expression", "")), false, context)
	# Deliberately NOT claimed: Wait. Its own display template already says the grammar's words
	# ("Wait {seconds} seconds") and the row wears the hourglass through the await chip, so leaving it
	# on the ordinary path keeps the parameter emphasis its substitution earns.
	return {}


## What an `await` says in event-sheet words. An event sheet has "Wait for signal" as a System
## action and counts ticks, so suspending on a signal reads as that action and suspending on a frame
## reads as the one tick it is. Returns {} for every other await (a timer wait already has its own
## "Wait N seconds" reading, and an await on a call keeps its GDScript) - a sentence must never paper
## over a suspension point it cannot name.
##
## `hourglass` is the RAW-line form: a lifted ACE row gets the ⏳ from the await chip the descriptor
## formatter adds, but a hand-written line has no chip, so the glyph belongs in the sentence.
##
## NOTE for merge: this lives here rather than in the sentence grammar only because the grammar file
## was being edited elsewhere at the time; its natural home is beside _await_statement().
static func await_reading(expression: String, hourglass: bool, context: Dictionary = {}) -> Dictionary:
	var text: String = expression.strip_edges()
	if text == "get_tree().process_frame":
		return _slot_sentence(EventSheetSentence.OBJECT_SYSTEM, "Wait one tick", {}, hourglass)
	if text == "get_tree().physics_frame":
		return _slot_sentence(EventSheetSentence.OBJECT_SYSTEM, "Wait one physics tick", {}, hourglass)
	# Waiting on a tween is waiting for the animation to end, which is the whole thought; the
	# local's name adds nothing a reader of the Tween rows above it does not already have.
	if text.ends_with(".finished") and EventSheetSentence.is_tween_local(
			text.substr(0, text.length() - 9), context):
		return _slot_sentence(EventSheetSentence.OBJECT_SYSTEM, "Wait for tween to finish", {}, hourglass)
	# A call anywhere in the expression is not a signal reference: `create_timer(x).timeout` is the
	# timer wait, which already reads as its own seconds sentence.
	if text.contains("(") or text.contains(")"):
		return {}
	var dot_at: int = text.rfind(".")
	if dot_at <= 0 or dot_at + 1 >= text.length():
		return {}
	var signal_bare: String = text.substr(dot_at + 1)
	if not EventSheetSentence.is_identifier(signal_bare):
		return {}
	var object_word: String = _await_object_word(text.substr(0, dot_at))
	if object_word.is_empty():
		return {}
	return _slot_sentence(EventSheetSentence.OBJECT_SYSTEM, "Wait for signal {object} {trigger}", {
		"object": [object_word, "name"],
		"trigger": ["On %s" % signal_bare.capitalize(), "name"]
	}, hourglass)


## The object half of an awaited signal reference as a reader names it: a node path by its last
## segment without the sigil (`$Head/Camera` -> "Camera"), anything else verbatim. "" when the text
## is not a plain reference, which is the caller's cue to leave the await as code.
static func _await_object_word(reference: String) -> String:
	var text: String = reference.strip_edges()
	if text.is_empty():
		return ""
	if text.begins_with("$") or text.begins_with("%"):
		text = text.substr(1)
		var slash_at: int = text.rfind("/")
		if slash_at >= 0:
			text = text.substr(slash_at + 1)
		return text.strip_edges().trim_prefix("\"").trim_suffix("\"")
	if text.contains(" ") or text.contains("["):
		return ""
	return text


## The grammar's own {slot} template fill, kept locally so a new reading can be added without
## reaching into the sentence file: each `{slot}` becomes its own toned segment, so a locale may
## reorder the sentence and the emphasis still lands on the values.
static func _slot_sentence(object_name: String, template: String, values: Dictionary,
		hourglass: bool = false) -> Dictionary:
	var rest: String = EventSheetL10n.translate(template)
	var segments: Array = []
	if hourglass:
		# The suspension glyph rides OUTSIDE the translated template, so a locale translates the
		# words alone and every reading of an await wears the same mark the await chip draws.
		segments.append({"text": "⏳ ", "tone": "plain"})
	var guard: int = 0
	while guard < 12:
		guard += 1
		var next_slot: String = ""
		var next_at: int = -1
		for slot: String in values.keys():
			var at: int = rest.find("{%s}" % slot)
			if at >= 0 and (next_at < 0 or at < next_at):
				next_at = at
				next_slot = slot
		if next_at < 0:
			break
		if next_at > 0:
			segments.append({"text": rest.substr(0, next_at), "tone": "plain"})
		var pair: Array = values[next_slot]
		segments.append({"text": str(pair[0]), "tone": str(pair[1])})
		rest = rest.substr(next_at + next_slot.length() + 2)
	if not rest.is_empty():
		segments.append({"text": rest, "tone": "plain"})
	return {"object": object_name, "segments": segments}


## The shared-grammar reading of an ACE CONDITION, or {} when the row has no hand-written twin.
func grammar_condition_sentence(condition: ACECondition) -> Dictionary:
	if condition == null or not (condition.provider_id.is_empty() or condition.provider_id == "Core"):
		return {}
	var params_dict: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
	var context: Dictionary = sentence_context()
	# A distance the importer claimed for the Is Farther Than row is still the projectile's own
	# question, when the file is a projectile. Every other row falls straight through.
	var shaped: Dictionary = behavior_shape_condition_sentence(condition.ace_id, params_dict, context)
	if not shaped.is_empty():
		return shaped
	match condition.ace_id:
		"ExpressionIsTrue":
			return EventSheetSentence.condition(str(params_dict.get("expr", "")), context)
		"IsSameObject":
			return EventSheetSentence.condition("%s == %s" % [
				str(params_dict.get("a", "")), str(params_dict.get("b", ""))], context)
		"CompareVar":
			# Only the null comparisons have an event-sheet sentence ("host does not exist"); every other
			# operator already reads as the comparison it is, so the grammar hands those straight back.
			return EventSheetSentence.condition("%s %s %s" % [
				str(params_dict.get("var_name", "")), str(params_dict.get("op", "==")),
				str(params_dict.get("value", ""))], context)
		# ── lens hook ────────────────────────────────────────────────────────────────────────────
		# The ground check reads on the OBJECT that is asking, with its offset through the shared value
		# lens - the same row a hand-written `test_move(transform, Vector2(0, 1))` reads as, so the
		# picked row and the typed line are one sentence.
		"IsOverlappingAtOffset":
			return EventSheetSentence.condition(
				"test_move(transform, %s)" % str(params_dict.get("offset", "")), context)
		# ── lens hook (the hierarchy's own question) ──────────────────────────────────────────────
		# "Does this object contain that one" is the word a reader uses about a tree out loud, and it
		# is what a typed `squad.is_ancestor_of(unit)` now reads as - so the picked row says it too.
		"IsAncestorOf":
			return EventSheetSentence.condition("%s.is_ancestor_of(%s)" % [
				str(params_dict.get("target", "self")), str(params_dict.get("node", ""))], context)
		# ── lens hook ────────────────────────────────────────────────────────────────────────────
		# A lookup in the table a file keeps unlocked skill ids in is the skill tree's own question,
		# and a row the importer lifted must ask it in the same words the typed line does. Every
		# other Has Key row falls straight through - the grammar refuses the moment the file keeps
		# no such table, which is every file that is not running a tree.
		"DictHasKey":
			return EventSheetSentence.skill_tree_condition("%s.has(%s)" % [
				str(params_dict.get("var_name", "")), str(params_dict.get("key", ""))], context)
		"IsActionPressed":
			return EventSheetSentence.input_action_sentence(str(params_dict.get("action", "")), false)
		"IsActionJustPressed":
			return EventSheetSentence.input_action_sentence(str(params_dict.get("action", "")), true)
		# ── lens hook ────────────────────────────────────────────────────────────────────────────
		# The release check and the file test read the same words their hand-written twins now read.
		"IsActionJustReleased":
			return EventSheetSentence.input_phase_sentence(str(params_dict.get("action", "")), false, false)
		"FileExists":
			return EventSheetSentence.condition(
				"FileAccess.file_exists(%s)" % str(params_dict.get("path", "")), context)
		# ── lens hook ────────────────────────────────────────────────────────────────────────────
		# "is in the editor" - one question, one sentence, whichever of Godot's two spellings the file
		# used and whether the row was typed or picked.
		"IsInEditor":
			return EventSheetSentence.condition("Engine.is_editor_hint()", context)
		# ── lens hook ────────────────────────────────────────────────────────────────────────────
		# The row a hand-written `x in y` lifts to, so both spellings ask the same question in words.
		"TextIsOneOf":
			return EventSheetSentence.condition("%s in %s" % [
				str(params_dict.get("text", "")), str(params_dict.get("options", ""))], context)
		# ── lens hook ────────────────────────────────────────────────────────────────────────────
		# The three text questions a hand-written line lifts to. Routed through the grammar rather
		# than reworded in the frozen display templates, which are a compatibility promise.
		"StringBeginsWith", "TextBeginsWith":
			return EventSheetSentence.condition("%s.begins_with(%s)" % [
				str(params_dict.get("text", "")), str(params_dict.get("prefix", ""))], context)
		"StringEndsWith":
			return EventSheetSentence.condition("%s.ends_with(%s)" % [
				str(params_dict.get("text", "")), str(params_dict.get("suffix", ""))], context)
		"StringContains":
			return EventSheetSentence.condition("%s.contains(%s)" % [
				str(params_dict.get("text", "")), str(params_dict.get("needle", ""))], context)
		# ── lens hook ────────────────────────────────────────────────────────────────────────────
		"MouseButtonDown":
			return EventSheetSentence.condition("Input.is_mouse_button_pressed(%s)" % str(
				params_dict.get("button", "")), context)
		# ── lens hook ─────────────────────────────────────────────────────────────────────────
		# The event-sheet Platform and collision questions, so a picked row and the same test typed by
		# hand ask it in the same words.
		"IsOnFloor", "IsOnFloor3D":
			return EventSheetSentence.condition("%s.is_on_floor()" % _ace_target(params_dict), context)
		"IsOnWall", "IsOnWall3D":
			return EventSheetSentence.condition("%s.is_on_wall()" % _ace_target(params_dict), context)
		"IsOnCeiling", "IsOnCeiling3D":
			return EventSheetSentence.condition("%s.is_on_ceiling()" % _ace_target(params_dict), context)
		"OverlapsBody", "OverlapsBody3D":
			return EventSheetSentence.condition("%s.overlaps_body(%s)" % [
				_ace_target(params_dict), str(params_dict.get("body", ""))], context)
		"OverlapsArea", "OverlapsArea3D":
			return EventSheetSentence.condition("%s.overlaps_area(%s)" % [
				_ace_target(params_dict), str(params_dict.get("area", ""))], context)
		"HasOverlappingBodies", "HasOverlappingBodies3D":
			return EventSheetSentence.condition("%s.has_overlapping_bodies()" % _ace_target(params_dict), context)
		"HasOverlappingAreas", "HasOverlappingAreas3D":
			return EventSheetSentence.condition("%s.has_overlapping_areas()" % _ace_target(params_dict), context)
		"ArrayIsEmpty", "DictIsEmpty":
			# An event sheet has no "is empty": emptiness IS a count of zero.
			return EventSheetSentence.condition("%s.is_empty()" % str(params_dict.get("var_name", "")), context)
		# ── lens hook ────────────────────────────────────────────────────────────────────────────
		# The batch-seven questions, so a row picked from the dialog and the same line typed by hand
		# say the same sentence. Each one hands the grammar the very code the row compiles to.
		"IsBetween":
			return EventSheetSentence.condition("%s <= %s and %s <= %s" % [
				str(params_dict.get("min", "")), str(params_dict.get("value", "")),
				str(params_dict.get("value", "")), str(params_dict.get("max", ""))], context)
		"IsAbout":
			return EventSheetSentence.condition("is_equal_approx(%s, %s)" % [
				str(params_dict.get("a", "")), str(params_dict.get("b", ""))], context)
		"IsZeroApprox":
			return EventSheetSentence.condition("is_zero_approx(%s)" % str(params_dict.get("value", "")), context)
		"IsWithinDistance":
			return EventSheetSentence.condition("%s.distance_to(%s) < %s" % [
				str(params_dict.get("a", "")), str(params_dict.get("b", "")),
				str(params_dict.get("distance", ""))], context)
		"IsInsideArea":
			return EventSheetSentence.condition("%s.has_point(%s)" % [
				str(params_dict.get("area", "")), str(params_dict.get("point", ""))], context)
		"IsOnScreen":
			return EventSheetSentence.condition("get_viewport_rect().has_point(%s)" % str(
				params_dict.get("point", "")), context)
		"IsOutsideLayout":
			return EventSheetSentence.outside_layout_reading("not get_viewport_rect().has_point(%s)" % str(
				params_dict.get("point", "")), context)
		"IsJumping", "IsFalling", "IsMoving", "IsJumping3D", "IsFalling3D", "IsMoving3D":
			return EventSheetSentence.condition("%s.%s" % [_ace_target(params_dict),
				_body_speed_test(condition.ace_id)], context)
		"IsNegative", "IsPositive":
			# Claimed ONLY for the shape an event sheet has a word for (a 2D body's vertical speed); every
			# other number keeps the vocabulary's own "is negative" reading.
			return EventSheetSentence.movement_words(str(params_dict.get("value", "")),
				"<" if condition.ace_id == "IsNegative" else ">", context)
	return {}


## The speed test one of the six body rows compiles to. The 3D rows ask the opposite sign of the
## vertical question, because Y grows upward there - and the grammar turns each back into the same
## word the 2D row reads, which is the whole point of asking it this way.
func _body_speed_test(ace_id: String) -> String:
	match ace_id:
		"IsJumping":
			return "velocity.y < 0"
		"IsFalling":
			return "velocity.y > 0"
		"IsJumping3D":
			return "velocity.y > 0"
		"IsFalling3D":
			return "velocity.y < 0"
	return "velocity.x != 0"


## The node a picked row acts on: the "On node" parameter a node-scoped ACE carries, or `self` for a
## host-scoped one, which is the object the compiled line acts on either way.
func _ace_target(params_dict: Dictionary) -> String:
	var target: String = str(params_dict.get("target", "")).strip_edges()
	return "self" if target.is_empty() else target


## The local-variable DECLARATION an ACE row reads as, or {} when it is not one of the Local Variable
## family. The family compiles to exactly the `var name: Type = value` line a user can also type, so
## both spellings land on one row shape.
func grammar_action_declaration(action: ACEAction) -> Dictionary:
	if action == null or not (action.provider_id.is_empty() or action.provider_id == "Core"):
		return {}
	var params_dict: Dictionary = action.params if not action.params.is_empty() else action.parameters
	var name_text: String = str(params_dict.get("name", ""))
	# A trailing `# note` is the row's note, not part of the starting value - split off here, and
	# handed to the declaration spans to draw at the end of the row where a sheet draws a note.
	var split: PackedStringArray = EventSheetSentence.trailing_comment(str(params_dict.get("value", "")))
	var value_text: String = split[0]
	var value_note: String = split[1]
	# The sheet's own context, so a starting value that names a place ("the direction from Player
	# to target") reads with the same object names every other row on this sheet uses.
	var context: Dictionary = sentence_context()
	var reading: Dictionary = _declaration_of(action.ace_id, name_text, value_text, params_dict, context)
	if reading.is_empty() or value_note.is_empty():
		return reading
	reading = reading.duplicate()
	reading["note"] = value_note
	return reading


## The declaration one Local Variable row spells, by its ace_id. Split out so the note handling above
## reads as the one thing it is rather than being repeated down six branches.
func _declaration_of(ace_id: String, name_text: String, value_text: String, params_dict: Dictionary,
		context: Dictionary) -> Dictionary:
	match ace_id:
		"SetLocalVar":
			return EventSheetSentence.declaration("var %s = %s" % [name_text, value_text], context)
		"SetLocalVarTyped":
			return EventSheetSentence.declaration("var %s: %s = %s" % [
				name_text, str(params_dict.get("var_type", "")), value_text], context)
		"SetLocalVarInferred":
			return EventSheetSentence.declaration("var %s := %s" % [name_text, value_text], context)
		"SetLocalConst":
			return EventSheetSentence.declaration("const %s = %s" % [name_text, value_text], context)
		"SetLocalConstTyped":
			return EventSheetSentence.declaration("const %s: %s = %s" % [
				name_text, str(params_dict.get("const_type", "")), value_text], context)
		"SetLocalConstInferred":
			return EventSheetSentence.declaration("const %s := %s" % [name_text, value_text], context)
	return {}


## True when this event's locals may read at the top of it. They may not when that would leave
## the event with NOTHING to draw - an event whose whole content is one `var` line has no question to
## ask and no other step to show, so lifting its declaration out would draw an empty band above the
## row that carries it. Such an event keeps the declaration in its own lane, exactly where it was.
func event_promotes_locals(event_row: EventRow) -> bool:
	if event_row == null:
		return false
	if (event_row.trigger != null or not event_row.trigger_id.is_empty()
			or not event_row.conditions.is_empty() or not event_row.pick_filters.is_empty()
			or not event_row.with_node_target.strip_edges().is_empty()):
		return true
	for action_resource: Variant in event_row.actions:
		if not (action_resource is ACEAction):
			return true
		var promotion: Dictionary = local_declaration_promotion(action_resource as ACEAction)
		if promotion.is_empty() or not str(promotion.get("set_value", "")).is_empty():
			return true
	return false


## How a Local Variable row reads as the sheet's own shape: the declaration the event owns,
## drawn at the top of that event, and the value the Set action beside it carries ("" when the
## declaration is a plain starting value and no action is needed). {} when the row is not one of the
## Local Variable family at all.
func local_declaration_promotion(action: ACEAction) -> Dictionary:
	var declaration: Dictionary = grammar_action_declaration(action)
	if declaration.is_empty():
		return {}
	# A value that BRANCHES is already read as the sub-event pair it is, which draws the
	# declaration itself once per arm. Promoting it too would say the same thing three times.
	var raw_value: String = str(declaration.get("raw_value", ""))
	if raw_value.contains(" if ") and raw_value.contains(" else "):
		return {}
	# The follower a hierarchy row writes out is plumbing the row already stands for, not a
	# value the reader introduced - promoting it would put a name nobody typed at the top of the
	# event, one line above the row that explains it.
	if str(declaration.get("name", "")).begins_with(EventSheetSentence.HIERARCHY_FOLLOWER_PREFIX):
		return {}
	var split: Dictionary = EventSheetSentence.declaration_rows(declaration)
	var promoted: Dictionary = declaration.duplicate(true)
	promoted["value"] = str(split.get("value", ""))
	return {"declaration": promoted, "set_value": str(split.get("set_value", ""))}


## The GDScript line a lifted Start Timer / Stop Timer row stands for, so the row reads through
## the SAME timer sentence a hand-written `$Timer.start(2.0)` reads through. "" when the row acts on
## the host rather than on a named node: a timer with no node path has no tag to name, and the row
## keeps the shipped format rather than inventing one.
static func timer_ace_code(ace_id: String, params_dict: Dictionary) -> String:
	var target: String = str(params_dict.get("target", "")).strip_edges()
	if target.is_empty():
		return ""
	if ace_id == "StopTimer":
		return "%s.stop()" % target
	var seconds: String = str(params_dict.get("time", "")).strip_edges()
	# `-1` is the descriptor's "use the Timer's own wait_time", which is the no-seconds sentence.
	if seconds.is_empty() or seconds == "-1":
		return "%s.start()" % target
	return "%s.start(%s)" % [target, seconds]


## One flat string from a grammar reading's segments - what a descriptor formatter must hand back.
func _joined_segments(sentence: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (sentence.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	return text


## The draw-ready segments of a grammar reading: names bold, values in the theme's value hue,
## connectives left to the cell's own colour. Built DIRECTLY, never through the BBCode parser - code
## text is full of square brackets (`wave[1]`) and a parser eats them as tags.
func grammar_bbcode_segments(pieces: Array) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	for piece: Variant in pieces:
		var part: Dictionary = piece
		var tone_color: Variant = null
		var tone_bold: bool = false
		match str(part.get("tone", "plain")):
			"name":
				tone_color = _viewport._get_reading_style().primary_text_color
				tone_bold = true
			"value":
				tone_color = _viewport._get_event_style().value_highlight_color
			"object":
				tone_color = _viewport._get_event_style().object_label_color
			"chip":
				# A class name or a behaviour name is a LABEL on the row, not a word in the
				# sentence, so it wears the object hue the object column uses for the same idea.
				tone_color = _viewport._get_event_style().object_label_color
				tone_bold = true
			"muted":
				# A connective the sentence needs but the reader does not read ("then").
				tone_color = _viewport._get_reading_style().muted_text_color
			EventSheetDerivedCalls.TONE_DERIVED:
				# The DERIVED verb, painted here exactly as the hand-written statement beside it
				# paints its own: read off the API rather than written by a person, so it keeps the
				# plainer call style instead of the curated sentence's bold name.
				tone_color = _viewport._get_reading_style().primary_text_color.lerp(
					_viewport._get_reading_style().muted_text_color, DERIVED_TONE_BLEND)
		segments.append({"text": str(part.get("text", "")), "color": tone_color, "bold": tone_bold, "italic": false})
	return segments


## The label an ACE row shows in its object column - the pending one when the row's shape named its
## own object, otherwise the ordinary provider/node reading.
func _object_label_or_pending(provider_id: String, ace_id: String) -> String:
	var pending: String = _pending_object_label
	_pending_object_label = ""
	var label: String = pending if not pending.is_empty() else _object_label_for(provider_id, ace_id)
	# ── lens hook ──────────────────────────────────────────────────────────────────────────────
	# The same reading a hand-written statement gets: a receiver the sheet declared a class for is
	# named by that class, with its own name muted beside it. Applied here because this is the ONE
	# place a picked row's object column is decided, so a lifted call and a picked row agree.
	_pending_object_note = ""
	var typed_object: Dictionary = EventSheetViewportReadingRows.typed_object_label(
		label, sentence_context(), _viewport.humanize_names_enabled())
	if typed_object.is_empty():
		return label
	_pending_object_note = str(typed_object.get("note", ""))
	return str(typed_object.get("label", label))


# The variable name shown muted beside the class an object column now names. One-shot, the same
# discipline _pending_object_label above uses: _object_label_or_pending writes it, _make_span reads
# and clears it, and the two always run back to back.
var _pending_object_note: String = ""


## What the grammar needs to know about THIS sheet: the class that owns its signals, and the
## published trigger name behind each declared signal, so `jumped.emit()` can read "Signal On Jumped"
## instead of naming the member. Cached per sheet - the signal declarations only change with an edit,
## which rebuilds the rows anyway.
func sentence_context() -> Dictionary:
	var sheet: Resource = _viewport._sheet if _viewport != null else null
	if sheet == _sentence_context_sheet and not _sentence_context_cache.is_empty():
		var reused: Dictionary = _sentence_context_cache.duplicate()
		reused["verb_kind"] = _current_verb_kind()
		reused["answer_shape"] = _current_answer_shape()
		# ── lens hook ─────────────────────────────────────────────────────────────────────────
		# The Familiar Words glossary is VIEW state, not sheet state, so it is stamped after the
		# per-sheet cache - flipping the toggle must change the reading without invalidating it.
		reused["familiar_words"] = _familiar_words_enabled()
		# Which edit the walk is inside is a fact about the WALK, not about the sheet, so it is
		# stamped after the per-sheet cache exactly as the verb kind above is.
		reused["answer_return"] = _answer_return_rows > 0
		return reused
	var context: Dictionary = {"self_object": EventSheetSentence.OBJECT_SYSTEM, "owner": "", "signals": {}}
	if sheet != null:
		# Only a class_name is an honest owner for a signal row. The host CLASS is the node the
		# behaviour is attached TO, which does not own the signal - naming it would send a reader
		# looking for a trigger on the wrong object, so a sheet without a class_name says System.
		context["owner"] = str(sheet.get("custom_class_name")).strip_edges()
		var declared: Dictionary = {}
		for entry: Variant in _sheet_signal_rows(sheet):
			var signal_row: SignalRow = entry
			var published: String = str(signal_row.ace_name).strip_edges()
			declared[signal_row.signal_name] = published if not published.is_empty() else signal_row.signal_name.capitalize()
		context["signals"] = declared
		# ── lens hook ──────────────────────────────────────────────────────────────────────────
		# What only something able to ASK can answer: the script's own object name, its engine
		# properties, and each signal's parameter names. Cached with the rest of the context.
		context.merge(EventSheetViewportReadingRows.sentence_context_extras(sheet as EventSheetResource), true)
		# ── lens hook ──────────────────────────────────────────────────────────────────────────
		# The class the file EXTENDS, when that class is one of the editor's own plugin classes. It
		# is the single fact every editor-plugin reading is keyed off: what the add_* verbs read as,
		# and which of this file's functions are the editor's questions rather than the author's.
		var extended: String = str(sheet.get("host_class")).strip_edges()
		if EventSheetEditorPluginWords.is_editor_plugin_class(extended):
			context["editor_plugin_class"] = extended
	_sentence_context_sheet = sheet
	_sentence_context_cache = context.duplicate()
	context["verb_kind"] = _current_verb_kind()
	context["answer_shape"] = _current_answer_shape()
	context["familiar_words"] = _familiar_words_enabled()
	context["answer_return"] = _answer_return_rows > 0
	return context


## Whether this view is reading in the familiar nouns (layout, time scale, layer). Off unless
## the user asked for it in View ▾, and never on for a headless build with no viewport.
func _familiar_words_enabled() -> bool:
	return _viewport != null and _viewport.familiar_words_enabled()


## Every SignalRow the sheet declares, wherever it sits in the row tree.
func _sheet_signal_rows(sheet: Resource) -> Array:
	var found: Array = []
	var events: Variant = sheet.get("events")
	if not (events is Array):
		return found
	for entry: Variant in (events as Array):
		if entry is SignalRow:
			found.append(entry)
	return found


## Which kind of verb body the rows being built belong to, so a `return` inside a published condition
## reads "Set return value to x" rather than "Stop event". ACTION whenever no published verb is walked.
func _current_verb_kind() -> int:
	if _verb_kind_override >= 0:
		return _verb_kind_override
	if _current_verb_function == null or not _current_verb_function.expose_as_ace:
		return EventSheetSentence.VerbKind.ACTION
	# The same split the vocabulary itself uses: a verb that gives back a yes/no IS a condition, a
	# verb that gives back anything else is an expression, and a verb that gives back nothing acts.
	var type_name: String = str(_current_verb_function.return_type_name).strip_edges()
	if _current_verb_function.return_type == TYPE_BOOL or type_name == "bool":
		return EventSheetSentence.VerbKind.CONDITION
	if _current_verb_function.return_type != TYPE_NIL or (not type_name.is_empty() and type_name != "void"):
		return EventSheetSentence.VerbKind.EXPRESSION
	return EventSheetSentence.VerbKind.ACTION


## The Answer shape a `return` in the function currently being walked takes - "" for every
## function that is not one of the editor's own callbacks, which is every function in a game script.
## Read from the same pair the header reads from (the class the file extends, and the function's own
## name), so the row that asks the question and the row that answers it can never disagree.
func _current_answer_shape() -> String:
	if _current_verb_function == null:
		return ""
	return EventSheetEditorPluginWords.answer_shape(
		_editor_plugin_class(), _current_verb_function.function_name)


## The editor plugin class the open sheet extends, "" when it extends anything else. One string
## lookup per ask; the sheet's host class is a field, not a walk.
func _editor_plugin_class() -> String:
	var sheet: Resource = _viewport._sheet if _viewport != null else null
	if sheet == null:
		return ""
	var extended: String = str(sheet.get("host_class")).strip_edges()
	return extended if EventSheetEditorPluginWords.is_editor_plugin_class(extended) else ""


# ── Reading lenses ───────────────────────────────────────────────────────
# The lenses themselves live in viewport_lenses.gd (text) and viewport_reading_rows.gd (rows).
# What lives HERE is only the per-rebuild caching: both need to ask the sheet a question whose
# answer is the same for every row in the pass, and asking it per span would walk the whole
# events array thousands of times on a large sheet. Cleared whenever the sheet identity changes.
var _lens_sheet_stamp: int = 0
var _lens_knob_names: Dictionary = {}
var _lens_class_map: Dictionary = {}
## Variable name -> the object a preloaded scene/script IS, as resolve_res_object answers it
## ({name, kind_word, icon_class}). `bullet_scene` is not what a reader calls the thing they
## spawn; the scene's root node is, and this is where Create object gets that name and its picture.
var _lens_scene_vars: Dictionary = {}
## Every registered autoload, so a row naming one can say it is a project-wide global.
var _lens_autoloads: Dictionary = {}


func _reset_lens_caches_if_stale() -> void:
	var sheet: EventSheetResource = _viewport._sheet
	var stamp: int = 0 if sheet == null else int(sheet.get_instance_id())
	if stamp == _lens_sheet_stamp:
		return
	_lens_sheet_stamp = stamp
	_lens_knob_names = EventSheetViewportReadingRows.export_knob_names(sheet)
	_lens_class_map = EventSheetViewportReadingRows.object_class_map(sheet)
	_lens_scene_vars = _scene_variable_map(sheet)
	# Walking ProjectSettings for the autoload list is the same answer for every row in a pass,
	# and asking it per object label walked a several-hundred-entry property list thousands of times
	# on a large sheet.
	_lens_autoloads = EventSheetViewportReadingRows.autoload_singletons()


## Every `var x = preload("res://...")` / `const X := preload(...)` of a sheet, resolved once per
## rebuild through the SAME cached scan the file's head uses to draw those declarations - the scan is
## keyed on the res:// path, so asking it again here costs a dictionary lookup and never re-reads a
## file.
func _scene_variable_map(sheet: EventSheetResource) -> Dictionary:
	var map: Dictionary = {}
	if sheet == null:
		return map
	for entry: Variant in sheet.events:
		var declared_name: String = ""
		var res_path: String = ""
		var variable: LocalVariable = entry as LocalVariable
		if variable != null:
			declared_name = variable.name
			res_path = ViewportRowBuilder.preloaded_path(str(variable.default_value))
		elif entry is CustomBlockRow and (entry as CustomBlockRow).kind_id == "preload":
			# `const ENEMY_SCENE := preload("res://enemy.tscn")` lifts to a preload BLOCK rather than a
			# variable, and a const is how most projects hold the thing they spawn.
			var fields: Dictionary = (entry as CustomBlockRow).fields
			declared_name = str(fields.get("name", ""))
			res_path = str(fields.get("path", ""))
		if declared_name.is_empty() or res_path.is_empty():
			continue
		var resolved: Dictionary = ViewportRowBuilder.resolve_res_object(res_path)
		if not resolved.is_empty():
			# The file itself rides along, so a row that MAKES one of these can show what is
			# inside it without resolving the name a second time.
			map[declared_name] = resolved.duplicate().merged({"res_path": res_path}, true)
	return map


## The sheet's @export knob names, so the lens can show those with Godot's Inspector
## capitalisation while ordinary variables read as plain lowercase words.
func _export_knob_names() -> Dictionary:
	_reset_lens_caches_if_stale()
	return _lens_knob_names


## The object-label to class-name map, so a row naming the pack's host, a $Node / %Node
## reference or an @onready node variable can draw that class's Godot icon.
## The object-label to class-name map itself, so a call's chips can be named by the engine's
## own parameter names for that class.
func _reading_class_map() -> Dictionary:
	_reset_lens_caches_if_stale()
	return _lens_class_map


## Every registered autoload, so a row naming one can say it is a project-wide global.
func _reading_autoloads() -> Dictionary:
	_reset_lens_caches_if_stale()
	return _lens_autoloads


## WHO a grammar-read row belongs to, applied to both lanes so a picked row and the hand-written
## line beside it are attributed the same way.
##
## `global_owner` is the autoload label recovered from the row's parameters, when the row reached
## through one; it wins outright, because a row that names `Game.score` belongs to Game whatever the
## grammar guessed. Otherwise the object the grammar named is offered to the attribution lens, which
## adds the "(global)" note to an autoload and hands a behaviour pack's rows back to the object the
## pack is mounted on, with the pack's name as the leading chip.
func _variable_owner_entries() -> Array[Dictionary]:
	if not _variable_owner_catalog.has("entries"):
		_variable_owner_catalog["entries"] = EventSheetVariableOwners.own_entries(
			_viewport._sheet if _viewport != null else null)
	return _variable_owner_catalog["entries"]


## The object column a variable row belongs in: an instance variable is the sheet's own object's,
## a global is its autoload's, and a local is System's - so "Player > Subtract 10 from health" reads
## as the object it changes rather than as machinery. "" when the row names no variable this sheet
## declares, which leaves the ordinary provider reading standing.
##
## Only a param the row's DEFINITION hints as a variable reference is consulted, and only a row the
## registry has a definition for at all: an expression that happens to mention `hp` is arithmetic,
## not ownership, and a line the reading layer recognised on its own already has an object rule of
## its own that says more than this one could.
## The object column a Send row belongs in: the object whose function the message IS. The rule,
## applied to a message - a row that sends one belongs to whoever declares it, the same way a row
## that changes a variable belongs to whoever owns the variable. "" for a message this sheet does not
## declare, which leaves the row its shipped Multiplayer label.
func _message_owner_label(provider_id: String, ace_id: String, params: Dictionary) -> String:
	if provider_id != EventSheetMessageFacts.PROVIDER:
		return ""
	if not EventSheetMessageFacts.SEND_ACE_IDS.has(ace_id):
		return ""
	var named: String = str(params.get("message", "")).strip_edges()
	if named.is_empty():
		return ""
	for entry: Dictionary in EventSheetMessageFacts.messages_in(_viewport._sheet as EventSheetResource):
		if str(entry.get("name", "")) == named:
			return _script_object_name()
	return ""


## The pattern name a light row is evidence of - the same one the reading claims for the
## hand-written line, so a lit file claims it whichever way its lines came in.
const LIGHTING_PATTERN := "lighting"


## The lighting class a verb is hosted on, or "" when it is not one of this vocabulary's
## verbs at all - any light, the CanvasModulate a layer's darkness sits on, or the WorldEnvironment
## the atmosphere rows write through. The same gate the lift asks before claiming a line, so a row
## and the statement it was read from agree about which nodes lighting speaks for. Read off
## whichever of the two the registry can answer with: a row never needs the registry to compile (its
## template is baked) and it must not need one to READ either, so a live editor answers from the
## definition and a bare viewport from the descriptor, and the question is the same for both.
func _lighting_host_class(provider_id: String, ace_id: String) -> String:
	var definition: ACEDefinition = _viewport._find_definition(provider_id, ace_id)
	var host: String = ""
	if definition != null:
		host = str(definition.metadata.get("node_type", ""))
	else:
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
		host = "" if descriptor == null else str(descriptor.node_type)
	return host if EventForgeLightingLift.addresses(host) else ""


## The object column a row aimed at a NODE belongs in: the node it names, not the class that node
## is - "Torch ▸ Set brightness", "Level ▸ Set darkness", "World ▸ Turn fog on", "Aura ▸ Set
## effect.glow". "" when the row acts on the sheet's own node (there is no other node to name), when
## the target is an expression rather than a node reference, or when the row is not one of the
## families whose subject IS the node it is aimed at.
func _lighting_owner_label(provider_id: String, ace_id: String, params: Dictionary) -> String:
	var aimed: String = str(params.get("target", "")).strip_edges()
	if aimed.is_empty() or aimed == "self" or not _names_its_node(provider_id, ace_id):
		return ""
	var named: String = EventSheetSceneLights.reference_key(aimed)
	return "" if named.is_empty() else named.get_slice("/", named.get_slice_count("/") - 1)


## True for a row whose object IS the node it is aimed at. Two families answer yes: the lighting
## ones, whose host class is itself a light or one of the two scene objects beside them, and the
## effect ones, whose host is the very general CanvasItem but whose subject is plainly the node
## wearing the material. Asked of the vocabulary that publishes them rather than of a list here, and
## kept for the session because the question is asked once per row of every sheet.
func _names_its_node(provider_id: String, ace_id: String) -> bool:
	if not _lighting_host_class(provider_id, ace_id).is_empty():
		return true
	if _effect_ace_ids.is_empty():
		for published: String in EventForgeEffectDialACEs.published_ace_ids():
			_effect_ace_ids[published] = true
	return _effect_ace_ids.has(ace_id)


func _variable_owner_label(provider_id: String, ace_id: String, params: Dictionary) -> String:
	if params.is_empty():
		return ""
	for name_text: String in _variable_reference_values(provider_id, ace_id, params):
		var owner: String = EventSheetVariableOwners.owner_for(_variable_owner_entries(), name_text)
		if not owner.is_empty():
			return owner
	return ""


func _attributed_grammar(grammar: Dictionary, global_owner: String) -> Dictionary:
	if not global_owner.is_empty():
		var owned: Dictionary = grammar.duplicate()
		owned["object"] = global_owner
		return owned
	var segments: Array = grammar.get("segments", []) as Array
	var pieces: Array = []
	for entry: Variant in segments:
		var segment: Dictionary = entry
		pieces.append([str(segment.get("text", "")), str(segment.get("tone", "plain"))])
	var attribution: Dictionary = EventSheetViewportReadingRows.object_attribution(
		str(grammar.get("object", "")), pieces, _script_object_name(),
		_reading_class_map(), _reading_autoloads())
	var attributed_pieces: Array = attribution.get("pieces", pieces) as Array
	if attributed_pieces.size() == pieces.size():
		var same: Dictionary = grammar.duplicate()
		same["object"] = str(attribution.get("object", grammar.get("object", "")))
		return same
	var rebuilt: Array = []
	for piece: Array in attributed_pieces:
		rebuilt.append({"text": str(piece[0]), "tone": str(piece[1])})
	return {"object": str(attribution.get("object", "")), "segments": rebuilt}


## The name the script's own object goes by, so a behaviour pack mounted under it can hand its
## rows back to it. Empty on a sheet with no object of its own, which is the attribution's cue to
## leave the reading alone.
func _script_object_name() -> String:
	return str(sentence_context().get("script_object", ""))


func _reading_class_icon_for(object_label: String) -> Texture2D:
	if not _viewport.show_object_icons:
		return null
	_reset_lens_caches_if_stale()
	return EventSheetViewportReadingRows.class_icon_for(object_label, _lens_class_map)


## Applied to a finished ACE display sentence. One function so every lifted-row lane -
## conditions, actions, triggers - reads the same way, and so the View toggle has a single switch
## to flip rather than one per lane.
func _reading_sentence(text: String) -> String:
	# ── lens hook ──────────────────────────────────────────────────────────────────────────────
	# `delta` reads `dt` whatever else is switched on: it is the number's event-sheet name, not a
	# respelling of somebody's variable, so it does not belong behind the humanized-names toggle.
	var with_dt: String = EventSheetViewportLenses.dt_words(text)
	# ── lens hook ──────────────────────────────────────────────────────────────────────────────
	# A named constant reads as the value it IS whatever else is switched on, for the same reason dt
	# does: `Vector2.ZERO` is not somebody's variable name, it is the point (0, 0). Applied here so a
	# row that reached the canvas through a display TEMPLATE reads it exactly as a typed line does.
	var with_constants: String = EventSheetSentence.constant_words(with_dt, sentence_context())
	if not _viewport.humanize_names_enabled():
		return with_constants
	return EventSheetViewportLenses.humanize_sentence(with_constants, _export_knob_names())


## Whether a lifted condition READS as inverted even though its `negated` flag is not set,
## which is the case for an expression condition lifted straight from `if not <cond>:`. The badge
## column asks this so the mark appears; _format_condition_descriptor strips the matching word so
## the two never both show.
func _condition_reads_negated(condition: ACECondition) -> bool:
	if condition == null:
		return false
	return bool(EventSheetViewportLenses.strip_leading_not(
		_format_condition_descriptor_base(condition)
	).get("negated", false))


## True when this inverted condition is a comparison with a clean opposite, so the row shows
## `hp > 0` (and the compiler emits it) instead of a mark over `hp ≤ 0`. The badge column asks so the
## denial mark stays off a row that already says the opposite in words.
func _comparison_flips(condition: ACECondition) -> bool:
	return condition != null and condition.negated and not _flipped_comparison_params(condition).is_empty()


## The condition a flippable inverted comparison READS as: the same ACE with the opposite
## operator and no inversion. Returns the condition itself, untouched, for everything else.
func _comparison_flip_of(condition: ACECondition) -> ACECondition:
	if condition == null or not condition.negated:
		return condition
	var flipped: Dictionary = _flipped_comparison_params(condition)
	if flipped.is_empty():
		return condition
	var reading: ACECondition = condition.duplicate()
	reading.params = flipped
	reading.parameters = flipped
	reading.negated = false
	return reading


## This condition's params with the comparison operator flipped, or {} when its template is not
## the plain `{a} {op} {b}` shape. The template is the baked one when the row carries it (custom and
## pack ACEs bake at apply time), else the descriptor's - the same order the compiler resolves in, so
## the row and the emitted line can never disagree about which comparisons flip.
func _flipped_comparison_params(condition: ACECondition) -> Dictionary:
	if condition == null:
		return {}
	var template: String = condition.codegen_template.strip_edges()
	if template.is_empty():
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
		if descriptor == null:
			return {}
		template = descriptor.codegen_template
	var params: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
	return EventForgeACEFactory.flipped_comparison_params(template, params)


## The class icon for the object a statement row acts on. The subject is the head of the
## statement: the assignment target for a `Set` sentence (`$Head.rotation.x` -> `$Head`), the
## receiver for a call (`host.move_and_slide()` -> `host`). Null whenever nothing is known, which
## is also what headless returns, so a headless render keeps the text-only look.
func _reading_sentence_icon(sentence: Dictionary, code: String) -> Texture2D:
	var subject: String = ""
	# ── lens hook ──────────────────────────────────────────────────────────────────────────────
	# The row's OBJECT is the subject whenever the sentence names one - an engine property of the
	# script's own object reads as `Player ▸ Set X to 100`, whose picture is Player's, not X's.
	var named_object: Texture2D = _reading_class_icon_for(str(sentence.get("object", "")))
	if named_object != null:
		return named_object
	if not sentence.is_empty():
		for segment: Variant in (sentence.get("segments", []) as Array):
			var part: Dictionary = segment
			if str(part.get("tone", "")) == "name":
				subject = str(part.get("text", ""))
				break
	else:
		subject = str(call_parts(code).get("target", ""))
	subject = subject.strip_edges()
	if subject.is_empty():
		return null
	var dot_at: int = subject.find(".")
	if dot_at > 0:
		subject = subject.substr(0, dot_at)
	return _reading_class_icon_for(subject)


## The "Functions ▸ Call Name" pieces for a hand-written call the sheet can attribute to one
## of its own functions, or [] when it cannot.
func _reading_call_pieces(code: String, arguments: PackedStringArray) -> Array:
	var sheet: EventSheetResource = _viewport._sheet
	if sheet == null:
		return []
	var function_name: String = EventSheetViewportReadingRows.called_function_name(code)
	if function_name.is_empty():
		return []
	var event_function: EventFunction = find_function_by_name(sheet, function_name)
	if event_function == null:
		return []
	var pieces: Array = EventSheetViewportReadingRows.call_reading_pieces(
		EventSheetViewportLenses.function_display_name(function_name, event_function.ace_display_name),
		arguments,
		EventSheetViewportReadingRows.parameter_names_of(event_function),
		_viewport.humanize_names_enabled(),
		_export_knob_names()
	)
	# A function that hands over to ITSELF is the one shape a reader has to be told about: the
	# rows below this one are the same rows again, one level in. Said on the call row, muted, because
	# that is the row where a reader would otherwise go looking for a second function.
	# The call is the function's OWN when the line sits in that function's body, which is a question
	# the row model can answer at span time - the walk that knew the enclosing verb is long over by
	# the time a row's spans are built.
	if not pieces.is_empty() and _function_body_holds_line(event_function, code):
		pieces.append(["   %s %s" % [MARK_RECURSION, EventSheetL10n.translate("itself")], "muted"])
	return pieces


## True when `action` is one of the rows of `event_function`'s own body - the lifted twin of
## the line test below, asked by identity because a lifted row IS the statement.
func _function_body_holds(event_function: EventFunction, action: Resource) -> bool:
	if event_function == null or action == null:
		return false
	var entries: Array = event_function.events if not event_function.events.is_empty() else event_function.rows
	return _entries_hold_action(entries, action, 0)


func _entries_hold_action(entries: Array, action: Resource, depth: int) -> bool:
	if depth > 32:
		return false
	for entry: Variant in entries:
		if entry == action:
			return true
		if entry is EventRow:
			var event_entry: EventRow = entry as EventRow
			if _entries_hold_action(event_entry.actions, action, depth + 1) \
					or _entries_hold_action(event_entry.sub_events, action, depth + 1):
				return true
	return false


## True when `code` is one of the lines of `event_function`'s own body.
func _function_body_holds_line(event_function: EventFunction, code: String) -> bool:
	var wanted: String = code.strip_edges()
	if wanted.is_empty():
		return false
	var entries: Array = event_function.events if not event_function.events.is_empty() else event_function.rows
	return _entries_hold_line(entries, wanted, 0)


## The same question, walked down the event tree. Depth-capped like every other walk here.
func _entries_hold_line(entries: Array, wanted: String, depth: int) -> bool:
	if depth > 32:
		return false
	for entry: Variant in entries:
		if entry is RawCodeRow:
			for line: String in (entry as RawCodeRow).code.split("\n"):
				if line.strip_edges() == wanted:
					return true
		elif entry is EventRow:
			var event_entry: EventRow = entry as EventRow
			if _entries_hold_line(event_entry.actions, wanted, depth + 1) \
					or _entries_hold_line(event_entry.sub_events, wanted, depth + 1):
				return true
	return false


func _make_span(text: String, span_type: int, metadata: Dictionary = {}) -> SemanticSpan:
	var span := SemanticSpan.new()
	span.text = text
	span.type = span_type
	span.metadata = metadata.duplicate(true)
	span.hoverable = bool(span.metadata.get("hoverable", true))
	# Precompute value-highlight ranges for condition/trigger/action text (single choke point;
	# build-time only, so the draw path stays cheap).
	if str(span.metadata.get("kind", "")) in ["condition", "trigger", "action"] and not text.is_empty():
		if _pending_display_bbcode:
			# The author's display TEMPLATE carried markup - parse to styled segments and draw the STRIPPED
			# text, so the cell width / colour swatch / hit-test all align with what's shown. The author
			# owns EMPHASIS in this cell (no automatic parameter bold), but the typed value TINTS still
			# apply: ranges computed on the stripped text colour any segment the author left colour-less.
			span.metadata["bbcode_segments"] = EventSheetBBCodeLite.parse(text, Color.WHITE)
			span.text = EventSheetBBCodeLite.strip(text)
			var stripped_ranges: Array = _value_ranges_for(span.text)
			if not stripped_ranges.is_empty():
				span.metadata["value_ranges"] = stripped_ranges
		else:
			var ranges: Array = merged_muted_leads(_value_ranges_for(text), text, _pending_muted_leads)
			if not ranges.is_empty():
				span.metadata["value_ranges"] = ranges
			# A row the shared grammar read carries ITS tones, so a picked row is tinted exactly like
			# the typed line beside it. Attached only while the text is still the grammar's own.
			if not _pending_grammar_segments.is_empty() and _joined_segments({"segments": _pending_grammar_segments}) == text:
				span.metadata["bbcode_segments"] = grammar_bbcode_segments(_pending_grammar_segments)
			var pending_text: String = str(_pending_param_ranges.get("text", ""))
			if not pending_text.is_empty() and not (_pending_param_ranges.get("ranges", []) as Array).is_empty():
				var at: int = text.find(pending_text)
				if at >= 0:
					var shifted: Array = []
					for entry: Variant in _pending_param_ranges.get("ranges", []):
						shifted.append([int(entry[0]) + at, int(entry[1])])
					span.metadata["param_ranges"] = shifted
	# The muted variable name that belongs to the object label this span was just given. Only
	# a span that actually carries a label takes it; the flag is cleared either way, so it can never
	# land on the next row.
	if not _pending_object_note.is_empty() and not str(span.metadata.get("object_label", "")).is_empty():
		span.metadata["object_note"] = _pending_object_note
	# What a DERIVED reading of a Call Method row leaves behind: the words for the hover, the page
	# for F1, and the class the verb was read off, which is the derived layer's own mark. It WINS over
	# the muted variable name the declaration lens leaves: on a derived row the muted word has to be a
	# class, or the one mark that tells the two layers apart at a glance says the opposite of what it
	# means. Skipped only where the object column is already that class in words, because saying it
	# twice is noise. Only the span carrying the sentence takes it, and the pending is cleared either
	# way so it can never land on the next row.
	if not _pending_derived_ace.is_empty():
		# Either lane: a derived VERB is always an action, and a derived PROPERTY is a Set row on the
		# right or the same object's question on the left, so the condition lane takes it too.
		var derived_lane: String = str(span.metadata.get("kind", ""))
		if (derived_lane == "action" or derived_lane == "condition") and not text.is_empty():
			span.metadata.merge(_derived_ace_meta(), true)
			var read_class: String = EventSheetDerivedCalls.muted_note(_pending_derived_ace,
				str(span.metadata.get("object_label", "")))
			if not read_class.is_empty():
				span.metadata["object_note"] = read_class
		_pending_derived_ace = {}
	_pending_object_note = ""
	_pending_display_bbcode = false
	_pending_param_ranges = {}
	_pending_grammar_segments = []
	_pending_muted_leads = PackedStringArray()
	return span


## `value_ranges` with every occurrence of a reading LEAD marked muted, in start order - which is the
## order the renderer walks them in, so a lead inserted out of order would silently drop the value
## after it. A lead never overlaps a value range: it is an identifier's prefix, and a value range is
## a number, a quoted string or a boolean. Static + pure, so the marking is pinned without a canvas.
static func merged_muted_leads(ranges: Array, text: String, leads: PackedStringArray) -> Array:
	if leads.is_empty():
		return ranges
	var marked: Array = ranges.duplicate()
	for lead: String in leads:
		var at: int = text.find(lead)
		while at >= 0:
			marked.append([at, lead.length(), "muted"])
			at = text.find(lead, at + lead.length())
	marked.sort_custom(func(left: Array, right: Array) -> bool: return int(left[0]) < int(right[0]))
	return marked


## format_display, but the display TEMPLATE is translated FIRST (then {slots} substitute), so
## a pack-shipped translations.csv localises whole viewport sentences - "take {amount} damage"
## translates as one key and every row using it follows. Display-only: ids, params, and the
## compiled output never translate. Handles both shapes (registry ACEDefinition metadata
## templates and builtin ACEDescriptor display text); English or a missing key pass through,
## so this is byte-identical to format_display until a catalog provides the template.
## One picked row's value in the words a person writes the number in - `300.0` as 300, `1e3` as
## 1000, a million with its thousands grouped. READING only, and deliberately so: the params dialog
## and the inline editor put the author's own GDScript back in front of them, so an editable sheet
## keeps showing exactly what it will emit and only a reading softens the spelling.
func _read_number_words(shown: String) -> String:
	return _read_colour_words(EventSheetSentence.number_lens(shown)) if _viewport.is_reading_mode() else shown


## One param value as the row shows it: through its declared READING LENS when it has one, and
## through the general number and colour readings when it does not. A lens is the param's own answer
## to "what does this value mean", so it stands INSTEAD of them rather than after them - a darkness
## colour would otherwise arrive as colour words and no longer look like a colour at all.
func _read_through_lens(lens: String, shown: String) -> String:
	if lens.strip_edges().is_empty():
		return _read_number_words(shown)
	var read: String = EventForgeValueLens.read(lens, shown)
	# A lens that puts a LEAD in front of its reading - `effect.` before a shader dial's name - says
	# what the name belongs to, which is a thing a reader needs once and then stops reading. So the
	# lead is noted here, where the only code that knows a lens ran is, and drawn quietly by the span.
	var lead: String = EventForgeValueLens.lead_of(lens)
	if not lead.is_empty() and read.begins_with(lead) and not _pending_muted_leads.has(lead):
		_pending_muted_leads.append(lead)
	return read


## A colour param reads as the colour a person would say - "red, 20% darker", "red at 50%
## opacity" - rather than as the Color call that built it. Only a value that IS a colour expression
## goes through the grammar: everything else is the author's own GDScript and stays exactly as typed.
func _read_colour_words(shown: String) -> String:
	var text: String = shown.strip_edges()
	if not (text.begins_with("Color(") or text.begins_with("Color.")):
		return shown
	var words: String = EventSheetSentence.expression_text(text, sentence_context())
	return words if not words.is_empty() else shown


func _format_display_translated(definition: ACEDefinition, descriptor: ACEDescriptor, params_dict: Dictionary) -> String:
	if definition != null:
		var template: String = _resolve_template(str(definition.metadata.get("display_template", definition.display_name)))
		if template.is_empty():
			return EventSheetL10n.translate(definition.display_name)
		var replacements: Array = []
		for index: int in range(definition.parameters.size()):
			var parameter: Variant = definition.parameters[index]
			if not (parameter is Dictionary):
				continue
			var key: String = str((parameter as Dictionary).get("id", ""))
			if key.is_empty():
				continue
			var fallback: Variant = (parameter as Dictionary).get("default_value", (parameter as Dictionary).get("default", ""))
			var value: Variant = params_dict.get(key, fallback)
			# Identity for every ordinary param; a dropdown that declared display_option_labels shows
			# the option's LABEL instead of the GDScript key it emits (`"y"` reads "Y (up / down)").
			# A shown LABEL is prose, so it goes through the catalog like the template around it -
			# the raw param value never does, because it is the author's own GDScript.
			var shown: String = _translated_option_label(ACEDefinition.display_value_for(parameter as Dictionary, value), str(value))
			# View ▸ Preview In Language: a globe-marked value renders in the previewed GAME locale
			# ("Jouer") instead of the literal tr("Play"). The identity when no preview is active, so
			# this is byte-identical to the row you author until someone asks to see another language.
			#
			# A value that IS a comparison operator renders as the glyph the row means - ≤ ≥ ≠,
			# and `=` for equality - the same spellings an opened script's readings already use. Only
			# the six operator tokens change; every other param value is the author's own GDScript.
			shown = EventSheetGameCatalog.preview_param(shown)
			shown = EventForgeACEFactory.comparison_glyph(shown)
			# A param that declares a READING LENS has its own answer for what its value means,
			# so the lens REPLACES the general readings rather than running after them: a stored
			# darkness colour says the percentage it makes, not the colour words the colour reading would find in it.
			# Applied here, on the canvas, because a lens is a derived reading and not a second
			# spelling - the row still stores and emits the author's own colour.
			shown = _read_through_lens(EventForgeValueLens.lens_of(parameter as Dictionary), shown)
			replacements.append(["{%d}" % index, shown])
			replacements.append(["{%s}" % key, shown])
		var substituted: Dictionary = substitute_display_tracking(template, replacements)
		_pending_param_ranges = substituted
		return str(substituted.get("text", ""))
	if descriptor == null:
		return ""
	var descriptor_template: String = _resolve_template(descriptor.get_display_text())
	if descriptor_template.is_empty():
		return descriptor.ace_id
	var descriptor_replacements: Array = []
	for i: int in range(descriptor.params.size()):
		var param: ACEParam = descriptor.params[i]
		if param == null:
			continue
		var param_key: String = param.id if not param.id.is_empty() else param.name
		if param_key.is_empty():
			continue
		var param_value: Variant = params_dict.get(param_key, param.get_initial_value())
		# The same reading lens the registry branch applies, so a builtin descriptor and the
		# registry's copy of it say the same sentence about the same row.
		var param_shown: String = _read_through_lens(param.display_lens,
			EventForgeACEFactory.comparison_glyph(EventSheetGameCatalog.preview_param(
				_translated_option_label(param.display_value(param_value), str(param_value)))))
		descriptor_replacements.append(["{%d}" % i, param_shown])
		descriptor_replacements.append(["{%s}" % param_key, param_shown])
	var descriptor_substituted: Dictionary = substitute_display_tracking(descriptor_template, descriptor_replacements)
	_pending_param_ranges = descriptor_substituted
	return str(descriptor_substituted.get("text", ""))


## Translates a display template, BBCode-aware. A marked-up template is its own translation
## key; when a locale's catalog predates the markup, the STRIPPED sentence is retried as the
## legacy key - a hit ships that locale's plain sentence (the automatic parameter emphasis
## still applies to it), so adding styling to a template never regresses a translation to
## English. Whatever resolves here also ARMS the styled branch when it carries markup - the
## one-shot rides to _make_span exactly like the rich-param arm in the descriptor formatters.
## A param cell's shown text, translated ONLY when it is an option label rather than the author's own
## value. `shown` differs from `raw` exactly when a dropdown declared display_option_labels and the
## value matched one of its options, so that difference is the test: prose written by this plugin
## goes through the catalog, a GDScript expression the author typed never does.
func _translated_option_label(shown: String, raw: String) -> String:
	return shown if shown == raw else EventSheetL10n.translate(shown)


func _resolve_template(raw_template: String) -> String:
	if raw_template.is_empty():
		return raw_template
	var translated: String = EventSheetL10n.translate(raw_template)
	if EventSheetBBCodeLite.has_markup(raw_template) and translated == raw_template:
		var plain: String = EventSheetBBCodeLite.strip(raw_template)
		var translated_plain: String = EventSheetL10n.translate(plain)
		if translated_plain != plain:
			translated = translated_plain
	if EventSheetBBCodeLite.has_markup(translated):
		_pending_display_bbcode = true
	return translated


## Substitutes display-template slots EXACTLY like the sequential String.replace chain above
## always did, while tracking where each substituted value landed in the final text - the
## ranges the renderer bolds (the event-sheet parameter emphasis). `replacements` is an ordered list
## of [token, value] pairs; every occurrence of each token substitutes (left to right,
## non-overlapping, like String.replace). Returns {"text": String, "ranges": [[start, length],
## ...] sorted}. A range a LATER substitution rewrites through is dropped - the degenerate
## case of a param value that itself contained a slot token. Static + pure.
static func substitute_display_tracking(template: String, replacements: Array) -> Dictionary:
	var text: String = template
	var ranges: Array = []
	for pair: Variant in replacements:
		if not (pair is Array) or (pair as Array).size() < 2:
			continue
		var token: String = str((pair as Array)[0])
		var value: String = str((pair as Array)[1])
		if token.is_empty() or not text.contains(token):
			continue
		var occurrences: Array = []
		var cursor: int = 0
		while true:
			var hit: int = text.find(token, cursor)
			if hit == -1:
				break
			occurrences.append(hit)
			cursor = hit + token.length()
		var diff: int = value.length() - token.length()
		var kept: Array = []
		for entry: Variant in ranges:
			var start: int = int((entry as Array)[0])
			var length: int = int((entry as Array)[1])
			var shift: int = 0
			var overlapped: bool = false
			for occurrence: Variant in occurrences:
				var occ: int = int(occurrence)
				if occ + token.length() <= start:
					shift += diff
				elif occ < start + length:
					overlapped = true
					break
			if not overlapped:
				kept.append([start + shift, length])
		ranges = kept
		if not value.is_empty():
			for index: int in range(occurrences.size()):
				ranges.append([int(occurrences[index]) + index * diff, value.length()])
		text = text.replace(token, value)
	ranges.sort_custom(func(a: Variant, b: Variant) -> bool: return int((a as Array)[0]) < int((b as Array)[0]))
	return {"text": text, "ranges": ranges}


## True when a RICH-TEXT ACE's param values carry BBCode. Rich capability is DECLARED by
## the ACE, never inferred: the descriptor's rich_text_when(param, value) (the ConsoleLog
## "As: Rich text" choice, carried into definition metadata by the adapter) or a
## bbcode_text-hinted param. No template sniffing - a template merely CONTAINING
## "print_rich" must not style foreign params (declare instead). A qualifying cell
## renders the markup's EFFECT (bold / color); every other string param keeps its
## brackets verbatim - `[b]` in a plain Print is data. Both lookup paths (definition,
## descriptor) normalize into the ONE shared rule below so they can never drift.
func _param_markup_applies(provider_id: String, ace_id: String, params: Dictionary) -> bool:
	var any_markup: bool = false
	for value: Variant in params.values():
		if EventSheetBBCodeLite.has_markup(str(value)):
			any_markup = true
			break
	if not any_markup:
		return false
	var definition: ACEDefinition = _viewport._find_definition(provider_id, ace_id)
	if definition != null:
		var definition_hints: PackedStringArray = PackedStringArray()
		for parameter: Variant in definition.parameters:
			if parameter is Dictionary:
				definition_hints.append(str((parameter as Dictionary).get("hint", "")))
		return _rich_capability_declared(str(definition.metadata.get("rich_when_param", "")), str(definition.metadata.get("rich_when_value", "")), definition_hints, params)
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
	if descriptor != null:
		var descriptor_hints: PackedStringArray = PackedStringArray()
		for param: ACEParam in descriptor.params:
			if param != null:
				descriptor_hints.append(param.hint)
		return _rich_capability_declared(descriptor.rich_when_param, descriptor.rich_when_value, descriptor_hints, params)
	return false


static func _rich_capability_declared(rich_param: String, rich_value: String, param_hints: PackedStringArray, params: Dictionary) -> bool:
	if not rich_param.is_empty() and str(params.get(rich_param, "")) == rich_value:
		return true
	return param_hints.has("bbcode_text")


## True when an ACE's display TEMPLATE (not the substituted text) carries BBCode markup - the author opted
## into styling via @ace_display_template. Built-in/custom descriptors resolve their template the same way
## format_display does.
func _display_template_has_markup(provider_id: String, ace_id: String) -> bool:
	var definition: ACEDefinition = _viewport._find_definition(provider_id, ace_id)
	if definition != null:
		return EventSheetBBCodeLite.has_markup(str(definition.metadata.get("display_template", definition.display_name)))
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
	return descriptor != null and EventSheetBBCodeLite.has_markup(descriptor.get_display_text())


func _get_variable_metadata_for_row(row_data: EventRowData) -> Dictionary:
	if row_data == null:
		return {}
	for span in row_data.spans:
		if span == null or not (span.metadata is Dictionary):
			continue
		var metadata: Dictionary = span.metadata as Dictionary
		if str(metadata.get("kind", "")) == "variable":
			return metadata.duplicate(true)
	return {}


func _resolve_span_lane(span: SemanticSpan) -> String:
	if span == null or not (span.metadata is Dictionary):
		return "condition"
	return str((span.metadata as Dictionary).get("lane", "condition"))

# Cache: "provider::ace" → Texture2D or null. Spans are rebuilt often; icon resolution
# (registry lookup + editor-theme/texture fetch) must not run per rebuild per span.
var _ace_icon_cache: Dictionary = {}


## Icon shown before an ACE's object label in row cells (event sheets show the object's icon next
## to its name everywhere). Resolution order matches the picker; Core/System falls back to
## the editor's Tools glyph. Null (headless / nothing matches) keeps the text-only look.
func _object_icon_for(provider_id: String, ace_id: String) -> Texture2D:
	if not _viewport.show_object_icons:
		return null  # user turned icons off; the cache stays warm for turning them back on
	var cache_key: String = "%s::%s" % [provider_id, ace_id]
	if _ace_icon_cache.has(cache_key):
		return _ace_icon_cache[cache_key]
	var definition: ACEDefinition = _viewport._find_definition(provider_id, ace_id)
	if definition == null and not (provider_id.is_empty() or provider_id == "Core"):
		# Not cached: the registry refreshes in place (addons may not be loaded yet when
		# the first spans build), so a miss now can become a hit on the next rebuild.
		return null
	var is_core: bool = provider_id.is_empty() or provider_id == "Core"
	var icon: Texture2D = null
	if is_core and definition != null:
		# Builtin rows: the ACE's module icon leads (Audio rows get the speaker, Math the die,
		# ..., same map as the picker's section headers), so resolve's kind-dot fallback only
		# shows where no module mapping exists. Headless keeps the old look (editor icons null).
		# The definition's own host is passed along so a category nobody listed still resolves:
		# an addon publishing "Turrets" on a Node2D gets the Node2D icon instead of a bare row.
		# host_class_of, not `.node_type`: an ACEDefinition has no such property (it keeps its host in
		# metadata), so reading it directly threw once for EVERY row drawn - invisible headless,
		# and it filled the Output dock the moment anyone opened a sheet in the real editor.
		icon = ACEPickerDialog.category_header_icon(definition.category, ACEPickerDialog.host_class_of(definition))
	if icon == null:
		icon = ACEPickerDialog.resolve_definition_icon(definition)
	if icon == null and is_core:
		icon = ACEPickerDialog.editor_icon("Tools")
	_ace_icon_cache[cache_key] = icon
	return icon


# ── Arrange by object / trigger / group (appended block - keep together) ───────────────────────
# The display-only re-grouping pass. It runs over the already-built root rows and re-emits them with
# one synthetic header per bucket, exactly the way group_helper_verb_rows gathers helpers - the same
# archetype, the same null source_resource, the same shared fold state. Nothing about the sheet
# moves: the events array, the emitted GDScript and the byte round-trip are untouched, and every
# event keeps its number because numbers are computed from sheet.events, not from this list.


## Re-groups the sheet's own event rows under one header per bucket. `mode` is an
## EventSheetArrangement mode; MODE_FILE_ORDER (and a null sheet) returns the rows untouched.
func arrange_rows(rows: Array[EventRowData], sheet: EventSheetResource, mode: int) -> Array[EventRowData]:
	if sheet == null or mode == EventSheetArrangement.MODE_FILE_ORDER:
		return rows
	var planned: Array = EventSheetArrangement.plan(rows, mode, EventSheetArrangement.self_object_of(sheet))
	if planned.is_empty():
		return rows
	var kept: Array[EventRowData] = []
	for row_data: EventRowData in rows:
		if EventSheetArrangement.is_arrangeable(row_data) or EventSheetArrangement.is_group_row(row_data):
			continue
		kept.append(row_data)
	var bucket_index: int = 0
	for bucket: Variant in planned:
		var entry: Dictionary = bucket
		var members: Array[EventRowData] = []
		for member: Variant in (entry.get("rows", []) as Array):
			var member_row: EventRowData = member as EventRowData
			if member_row == null:
				continue
			_shift_row_indent(member_row, 1 - member_row.indent)
			members.append(member_row)
		kept.append(_build_arrangement_header_row(sheet, mode, bucket_index,
			str(entry.get("header", "")), members))
		bucket_index += 1
	return kept


## One arrangement header: the head-folder archetype, titled with the bucket's own word and noting
## how many events read under it. Null source (nothing to select, drag or delete - it is a lens, not
## a resource) and its fold remembered per session through the shared fold state, keyed on a uid that
## carries the mode so switching arrangements never inherits another one's folds.
func _build_arrangement_header_row(sheet: EventSheetResource, mode: int, bucket_index: int,
		title: String, members: Array[EventRowData]) -> EventRowData:
	var subtitle: String = EventSheetL10n.translate("1 event")
	if members.size() != 1:
		subtitle = EventSheetL10n.translate("%d events") % members.size()
	var row_data: EventRowData = _build_head_group_row(sheet,
		"arrange_%s_%d" % [EventSheetArrangement.mode_id(mode), bucket_index],
		title, subtitle, members)
	row_data.folded = bool(_viewport._fold_state.get(row_data.row_uid, false))
	return row_data


# ── the camera-ray run, which is ONE question written as four lines ──────────────────────────────
#
# `project_ray_origin`, `project_ray_normal`, the query, `intersect_ray` - four lines that only mean
# anything together, and that every 3D game writes to answer "what is under the cursor?". They read
# as ONE row, in exactly the discipline the mouse-look and crossfade runs above use: the lines stay
# as the file wrote them (hover shows all of them, double-click opens the exact GDScript, the bytes
# saved are untouched), and only what the canvas SAYS about them changes.
#
# The run's own facts - how far it reaches, which layers it may see, what aimed it, and whether the
# branch under it clears what it found - come from the file's one walk (cursor_ray_facts), because
# no line of the run can answer any of them on its own.


## The camera-ray runs in one action lane, as {"leads": {index: {…}}, "consumed": {…}} -
## the same shape every other run grouper here answers in.
## The action indices a TEST sheet's verdict bookkeeping sits at - the `var passed := true` a
## file opens each of its gates with. Not something the test DOES: the Check rows under it are the
## verdict, and the Include bar already says this is a test sheet and how many checks it makes. Every
## other file, and every other local, comes back empty and draws exactly as it always did.
##
## Answers a plain {index: true} set, which is the `consumed` half of the run-grouper shape the lane
## already skips by - so the row is not drawn, the line index does not advance, and the height count
## agrees without a second rule.
func _test_verdict_consumed(event_row: EventRow) -> Dictionary:
	var consumed: Dictionary = {}
	if event_row == null:
		return consumed
	var context: Dictionary = sentence_context()
	if str(context.get("tool_file_kind", "")) != EventSheetToolFiles.KIND_TEST_SHEET:
		return consumed
	var accumulators: PackedStringArray = context.get("test_accumulators", PackedStringArray())
	if accumulators.is_empty():
		return consumed
	for action_index: int in event_row.actions.size():
		var action: ACEAction = event_row.actions[action_index] as ACEAction
		if action == null:
			continue
		var declaration: Dictionary = grammar_action_declaration(action)
		if declaration.is_empty():
			continue
		if not accumulators.has(str(declaration.get("name", ""))):
			continue
		# Only the exact `true` the verdict is opened with. A name that happens to match, holding
		# anything else, is an ordinary local and keeps its row.
		if str(declaration.get("raw_value", "")).strip_edges() != "true":
			continue
		consumed[action_index] = true
	return consumed


func _cursor_ray_groups(actions: Array) -> Dictionary:
	var leads: Dictionary = {}
	var consumed: Dictionary = {}
	var rays: Dictionary = sentence_context().get("cursor_rays", {})
	if rays.is_empty():
		return {"leads": leads, "consumed": consumed}
	var index: int = 0
	while index < actions.size() - 3:
		var last: int = _cursor_ray_run_end(actions, index)
		if last < 0:
			index += 1
			continue
		var hit_name: String = _cursor_ray_declared_name(_group_line_text(actions[last]))
		var facts: Dictionary = rays.get(hit_name, {})
		if facts.is_empty():
			index += 1
			continue
		# The reach, what aimed the ray and the mask come from THESE lines, never from the name: two
		# functions may both call their hit `hit`, and a note taken from the other one's run would be
		# exactly the confident lie this reading refuses. Only whether the branch under the run clears
		# what it found is a question these lines cannot answer, so only that comes from the file.
		var run_facts: Dictionary = _cursor_ray_run_facts(actions, index, last)
		var evidence: PackedStringArray = PackedStringArray()
		var indices: Array[int] = []
		for member_index: int in range(index, last + 1):
			evidence.append(_group_line_text(actions[member_index]))
			indices.append(member_index)
		var words: Dictionary = EventSheetSentence.cursor_ray_run_words(hit_name,
			str(run_facts.get("reach", "")), str(run_facts.get("aimed_at", "")),
			str(run_facts.get("mask", "")),
			EventSheetSentence.PHYSICS_DIMENSION_3D, sentence_context())
		var note: String = str(words.get("note", ""))
		if bool(facts.get("cleared", false)):
			var nothing: String = EventSheetL10n.translate("none when nothing is hit")
			note = "%s · %s" % [note, nothing] if not note.is_empty() else nothing
		leads[index] = {
			"text": str(words.get("text", "")),
			"note": note,
			"object": EventSheetSentence.OBJECT_SYSTEM,
			"evidence": evidence,
			"line_count": last - index + 1,
			"indices": indices
		}
		for consumed_index: int in range(index + 1, last + 1):
			consumed[consumed_index] = true
		index = last + 1
	return {"leads": leads, "consumed": consumed}


## The LAST action of a camera-ray run starting at `first`, or -1 when the lines there are
## not one. Every step is required: two halves of a ray with no query built from them are two
## ordinary declarations, and reading them as a question would be exactly the confident lie this
## grammar refuses. The mask line is the one optional member, because a ray restricted to the floor
## and one that sees everything are the same question asked with a filter.
func _cursor_ray_run_end(actions: Array, first: int) -> int:
	var origin: Dictionary = EventSheetSentence.cursor_ray_step_parts(
		_cursor_ray_declared_value(_group_line_text(actions[first])))
	if str(origin.get("step", "")) != "project_ray_origin":
		return -1
	var origin_name: String = _cursor_ray_declared_name(_group_line_text(actions[first]))
	if origin_name.is_empty():
		return -1
	var direction: Dictionary = EventSheetSentence.cursor_ray_step_parts(
		_cursor_ray_declared_value(_group_line_text(actions[first + 1])))
	if str(direction.get("step", "")) != "project_ray_normal":
		return -1
	if str(direction.get("point", "")) != str(origin.get("point", "")):
		return -1
	if str(direction.get("camera", "")) != str(origin.get("camera", "")):
		return -1
	var direction_name: String = _cursor_ray_declared_name(_group_line_text(actions[first + 1]))
	var query: Dictionary = EventSheetSentence.cursor_ray_step_parts(
		_cursor_ray_declared_value(_group_line_text(actions[first + 2])))
	if str(query.get("step", "")) != "query":
		return -1
	if EventSheetSentence.cursor_ray_reach(str(query.get("to", "")), origin_name, direction_name).is_empty():
		return -1
	var query_name: String = _cursor_ray_declared_name(_group_line_text(actions[first + 2]))
	if query_name.is_empty():
		return -1
	var cast_at: int = first + 3
	if _cursor_ray_mask_target(_group_line_text(actions[cast_at])) == query_name:
		cast_at += 1
	if cast_at >= actions.size():
		return -1
	var cast: Dictionary = EventSheetSentence.cursor_ray_step_parts(
		_cursor_ray_declared_value(_group_line_text(actions[cast_at])))
	if str(cast.get("step", "")) != "cast" or str(cast.get("query", "")) != query_name:
		return -1
	return cast_at


## The name a `var x := …` line declares, or "" when the line declares nothing.
func _cursor_ray_declared_name(text: String) -> String:
	var bare: String = text.strip_edges()
	if not bare.begins_with("var "):
		return ""
	for separator: String in [" := ", " = "]:
		var at: int = bare.find(separator)
		if at < 0:
			continue
		var name_text: String = bare.substr(4, at - 4).strip_edges()
		var colon_at: int = name_text.find(":")
		if colon_at >= 0:
			name_text = name_text.substr(0, colon_at).strip_edges()
		return name_text if EventSheetSentence.is_identifier(name_text) else ""
	return ""


## The value a `var x := …` line is declared from, or "" when the line declares nothing.
func _cursor_ray_declared_value(text: String) -> String:
	var bare: String = text.strip_edges()
	if not bare.begins_with("var "):
		return ""
	for separator: String in [" := ", " = "]:
		var at: int = bare.find(separator)
		if at >= 0:
			return bare.substr(at + separator.length()).strip_edges()
	return ""


## The query a `q.collision_mask = …` line restricts, "" when the line is not that write.
func _cursor_ray_mask_target(text: String) -> String:
	var at: int = text.strip_edges().find(".collision_mask = ")
	return "" if at <= 0 else text.strip_edges().substr(0, at).strip_edges()


## What THIS run says about itself: how far it reaches, which layers it may see, and the
## object whose canvas position aimed it ("" for the OS pointer). Read off the run's own lines so two
## same-named runs in one file can never borrow each other's numbers.
func _cursor_ray_run_facts(actions: Array, first: int, last: int) -> Dictionary:
	var origin: Dictionary = EventSheetSentence.cursor_ray_step_parts(
		_cursor_ray_declared_value(_group_line_text(actions[first])))
	var origin_name: String = _cursor_ray_declared_name(_group_line_text(actions[first]))
	var direction_name: String = _cursor_ray_declared_name(_group_line_text(actions[first + 1]))
	var query: Dictionary = EventSheetSentence.cursor_ray_step_parts(
		_cursor_ray_declared_value(_group_line_text(actions[first + 2])))
	var query_name: String = _cursor_ray_declared_name(_group_line_text(actions[first + 2]))
	var mask: String = ""
	for index: int in range(first + 3, last + 1):
		var line: String = _group_line_text(actions[index]).strip_edges()
		if _cursor_ray_mask_target(line) != query_name:
			continue
		mask = line.substr(line.find(".collision_mask = ") + 18).strip_edges()
	return {
		"reach": EventSheetSentence.cursor_ray_reach(str(query.get("to", "")), origin_name, direction_name),
		"aimed_at": EventSheetViewportReadingRows.cursor_aim_owner(str(origin.get("point", ""))),
		"mask": mask
	}
