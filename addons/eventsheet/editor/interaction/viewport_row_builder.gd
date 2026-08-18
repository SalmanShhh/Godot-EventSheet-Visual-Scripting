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
## "Action" / "Condition" / "Expression" word badge from the header (a Construct Function block
## carries its name and its inputs, nothing else), so the role tint becomes the ONLY kind cue and
## has to be visible even when the theme ships verb_row_tint_strength at 0.0 for the authoring look.
const VERB_KIND_TINT_ALPHA: float = 0.16

var _viewport: Control = null
# The published verb whose body is being walked right now, or null at sheet level. Rows inside a
# CONDITION or EXPRESSION verb read their `return` as "Set return value to x" rather than "Stop event",
# and only the walk knows which verb owns the rows it is building.
var _current_verb_function: EventFunction = null
# The verb kind a lazily-built row carries with it, or -1 when the walk itself is the authority.
var _verb_kind_override: int = -1
# Per-build occurrence counters ("label" -> count) giving every paired region a STABLE
# fold key ("label#n") that survives sessions - row uids are instance-based and cannot
# (the persisted-folds layer keys on these instead). Reset by _pair_region_fences.
var _region_occurrences: Dictionary = {}
# Per-build occurrence counters for class-block row uids ("Stats" -> count). Class rows key
# their uids by class NAME (stable across the undo funnel's resource rebuild, so expand /
# disabled state survives edits) - but two blocks sharing a name then shared ONE uid, so
# selecting/toggling one silently mirrored onto the other. The counter suffixes repeats
# ("-2", "-3"); build order is stable, so a repeat maps to the same block next rebuild.
# Reset by the viewport at the top of every _build_rows_from_sheet sweep.
var _class_uid_counts: Dictionary = {}


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
				_append_to_sink(output, stack, row_data)
				continue
			var frame: Dictionary = stack.pop_back()
			var opener: EventRowData = frame.get("opener")
			var collected: Array[EventRowData] = frame.get("collected")
			var region_children: Array[EventRowData] = []
			for collected_row: EventRowData in collected:
				_bump_indent(collected_row, 1)
				region_children.append(collected_row)
			# The closing fence rides as the LAST child: hidden while folded, still
			# a real selectable row (its CustomBlockRow is untouched) when open.
			# Once its opener is known, its marker names the range it closes.
			_bump_indent(row_data, 1)
			var opener_label: String = str(((opener.source_resource as CustomBlockRow).fields as Dictionary).get("label", "")).strip_edges()
			if not opener_label.is_empty() and not row_data.spans.is_empty():
				row_data.spans[0].text = "end of %s" % opener_label
			region_children.append(row_data)
			opener.children = region_children
			# Session fold state (row-uid keyed) wins; the persisted layer (stable
			# label#occurrence keys) seeds the default so folds survive reopen.
			var occurrence: int = int(_region_occurrences.get(opener_label, 0))
			_region_occurrences[opener_label] = occurrence + 1
			var fold_key: String = "%s#%d" % [opener_label, occurrence]
			opener.set_meta("region_fold_key", fold_key)
			opener.folded = bool(_viewport._fold_state.get(opener.row_uid, bool(_viewport.persisted_region_folds.get(fold_key, false))))
			if opener.folded:
				var hidden_count: int = region_children.size() - 1
				opener.spans.append(_make_span(
					"· %d row%s hidden" % [hidden_count, "" if hidden_count == 1 else "s"],
					SemanticSpan.SpanType.VALUE,
					{"text_color": Color(EventSheetPalette.TEXT_MUTED.r, EventSheetPalette.TEXT_MUTED.g, EventSheetPalette.TEXT_MUTED.b, 0.75)}
				))
			_append_to_sink(output, stack, opener)
			continue
		_append_to_sink(output, stack, row_data)
	# Unclosed openers unwind flat, in document order: the opener row, then
	# everything it had collected, exactly as they read in the source.
	for frame: Dictionary in stack:
		output.append(frame.get("opener"))
		output.append_array(frame.get("collected"))
	return output


func _append_to_sink(output: Array[EventRowData], stack: Array[Dictionary], row_data: EventRowData) -> void:
	if stack.is_empty():
		output.append(row_data)
	else:
		(stack[stack.size() - 1].get("collected") as Array[EventRowData]).append(row_data)


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


func _build_scaffolding_strip_row(sheet: EventSheetResource, scaffold_rows: Array[EventRowData]) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = 0
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = null
	row_data.row_uid = "scaffolding_strip_%d" % sheet.get_instance_id()
	row_data.children = scaffold_rows
	row_data.folded = bool(_viewport._fold_state.get(row_data.row_uid, true))  # hidden by default
	var line_total: int = 0
	for child: EventRowData in scaffold_rows:
		line_total += child.line_count
	# The strip is the sheet's IDENTITY, read like Construct's Includes bar: closed, just the
	# inheritance breadcrumb (Node ▸ CharacterBody2D ▸ ExternalSample - the chain a beginner
	# learns from); open, the secondary facts as a label+value LIST (never crammed inline on the
	# bar), with the raw prelude lines as the last children, editable as before.
	var extends_target: String = ""
	var declared_class: String = ""
	var has_tool: bool = false
	for child: EventRowData in scaffold_rows:
		if not (child.source_resource is RawCodeRow):
			continue
		for scaffold_line: String in (child.source_resource as RawCodeRow).code.split("\n"):
			var trimmed: String = scaffold_line.strip_edges()
			if trimmed.begins_with("extends ") and extends_target.is_empty():
				extends_target = trimmed.trim_prefix("extends ").strip_edges()
			elif trimmed.begins_with("class_name ") and declared_class.is_empty():
				declared_class = trimmed.trim_prefix("class_name ").strip_edges()
			elif trimmed == "@tool":
				has_tool = true
	# The breadcrumb: Node ▸ <base> ▸ <this sheet>. The chain stays short on purpose - the full
	# ClassDB ladder (CanvasItem, CollisionObject2D, ...) is trivia; base and root are the lesson.
	var leaf_name: String = declared_class
	if leaf_name.is_empty() and sheet != null and not str(sheet.external_source_path).is_empty():
		leaf_name = str(sheet.external_source_path).get_file().get_basename()
	var crumbs: PackedStringArray = PackedStringArray()
	if not extends_target.is_empty() and extends_target != "Node" and not extends_target.begins_with("\""):
		crumbs.append("Node")
	if not extends_target.is_empty():
		crumbs.append(extends_target)
	var crumb_prefix: String = " ▸ ".join(crumbs)
	var badge_meta: Dictionary = {
		"editable": false,
		"badge": true,
		"badge_style": "trigger",
		"badge_bg": EventSheetPalette.COLOR_SETUP_BADGE_BG,
		"badge_fg": EventSheetPalette.COLOR_SETUP_BADGE_FG,
		"kind": "scaffolding_strip",
		"line_index": 0
	}
	var class_icon: Texture2D = ACEPickerDialog.editor_icon(extends_target) if not extends_target.is_empty() else null
	if class_icon != null:
		badge_meta["badge_icon"] = class_icon
	# The bar wears the accent as an Includes-strip band - the sheet's identity should read as
	# a BAR like a group header (and stand apart from every grey code row), not blend in.
	var strip_accent: Color = _viewport._get_event_style().behavior_accent_color
	row_data.custom_color = Color(strip_accent.r, strip_accent.g, strip_accent.b, 0.22)
	row_data.height_scale = 1.5
	var spans: Array[SemanticSpan] = [_make_span("▣", SemanticSpan.SpanType.KEYWORD, badge_meta)]
	if crumb_prefix.is_empty() and leaf_name.is_empty():
		spans.append(_make_span("class_name, host binding & annotations - %d lines" % line_total, SemanticSpan.SpanType.COMMENT, {
			"editable": false,
			"kind": "scaffolding_strip",
			"text_color": Color(EventSheetPalette.TEXT_MUTED.r, EventSheetPalette.TEXT_MUTED.g, EventSheetPalette.TEXT_MUTED.b, 0.8)
		}))
	else:
		if not crumb_prefix.is_empty():
			var crumb_text: String = crumb_prefix + (" ▸" if not leaf_name.is_empty() else "")
			spans.append(_make_span(crumb_text, SemanticSpan.SpanType.COMMENT, {"editable": false, "kind": "scaffolding_strip", "text_color": EventSheetPalette.TEXT_MUTED}))
		if not leaf_name.is_empty():
			spans.append(_make_span(leaf_name, SemanticSpan.SpanType.VALUE, {"editable": false, "kind": "scaffolding_strip", "text_color": EventSheetPalette.TEXT_PRIMARY}))
	row_data.spans = spans
	# The dropdown facts, prepended above the raw prelude children. Label + value per row; only
	# facts that exist get a row (no "@tool: no" noise).
	var facts: Array[EventRowData] = []
	if has_tool:
		facts.append(_build_setup_fact_row(EventSheetL10n.translate("Runs in editor"), "@tool", 0))
	var remembered_names: PackedStringArray = PackedStringArray()
	if sheet != null:
		for var_key: Variant in sheet.variables.keys():
			var descriptor: Variant = sheet.variables.get(var_key)
			if descriptor is Dictionary and (descriptor as Dictionary).get("attributes") is Dictionary \
					and bool(((descriptor as Dictionary).get("attributes") as Dictionary).get("remember", false)):
				remembered_names.append(str(var_key))
	if not remembered_names.is_empty():
		facts.append(_build_setup_fact_row(EventSheetL10n.translate("Remembered variables"), "%d ( %s )" % [remembered_names.size(), ", ".join(remembered_names)], 1))
	var setup_lines_fact: EventRowData = _build_setup_fact_row(EventSheetL10n.translate("Setup lines"), "%d · %s" % [line_total, EventSheetL10n.translate("double-click to edit in code")], 2)
	# The Setup lines row IS the door to the raw code: it carries the first prelude block as its
	# resource, so double-click opens the code dialog exactly as the old visible rows did.
	if not scaffold_rows.is_empty():
		setup_lines_fact.source_resource = scaffold_rows[0].source_resource
	facts.append(setup_lines_fact)
	# The dropdown shows FACTS, not code: a clean prelude line stays behind "double-click to
	# edit" (the mockup's whole point - no grey code wall inside the dropdown). A prelude row
	# carrying a diagnostic still surfaces, error marker and all - problems are never hidden.
	var all_children: Array[EventRowData] = []
	all_children.append_array(facts)
	for scaffold_child: EventRowData in scaffold_rows:
		if not scaffold_child.error_message.strip_edges().is_empty():
			all_children.append(scaffold_child)
	row_data.children = all_children
	return row_data


## One fact of the Class setup dropdown: a muted label and its value, inert (no source
## resource - selection, drag and delete all skip it, like the add-event footer).
func _build_setup_fact_row(label: String, value: String, fact_index: int) -> EventRowData:
	var row := EventRowData.new()
	row.indent = 1
	row.row_type = EventRowData.RowType.SECTION
	row.source_resource = null
	row.row_uid = "scaffold_fact_%d_%s" % [fact_index, label]
	row.spans = [
		_make_span(label, SemanticSpan.SpanType.COMMENT, {"editable": false, "kind": "scaffold_fact", "text_color": EventSheetPalette.TEXT_MUTED, "line_index": 0}),
		# The VALUE is the readable half - full-strength text, never the muted code grey.
		_make_span(value, SemanticSpan.SpanType.VALUE, {"editable": false, "kind": "scaffold_fact", "line_index": 0, "text_color": EventSheetPalette.TEXT_PRIMARY})
	]
	return row


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
				"text_color": Color(EventSheetPalette.TEXT_MUTED.r, EventSheetPalette.TEXT_MUTED.g, EventSheetPalette.TEXT_MUTED.b, 0.8)
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
	# In READING mode the caption is gone: a Construct Function block is its name and its inputs, and
	# the description is one of the things the ACE properties popup answers. (An unpublished helper
	# keeps its doc comment - in the header's right lane, where a Construct user reads it.)
	if not _verb_reading_mode():
		var note_row: EventRowData = _build_verb_note_row(event_function, define_role_for(event_function), indent)
		if note_row != null:
			rows.append(note_row)
	rows.append(_build_define_function_row(event_function, indent))
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
## last published verb and closed by default - the Construct reading, where a pack's vocabulary comes
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
	for row_data: EventRowData in rows:
		var owner_function: EventFunction = row_data.source_resource as EventFunction
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
				"text_color": EventSheetPalette.TEXT_MUTED
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


## THE HEAD OF AN OPENED PACK, in Construct grammar. A read-only preview used to open on two and a
## half screens of prelude before its first rule: a Class setup bar, a `host` variable, a Host binding
## bar, every trigger as its own row, then 46 variable rows, then the pack's about text repeated at the
## end as a grey wall. Construct puts that same material in four shapes, and this is the lens that
## reads it back as them:
##   1. ONE Include bar carrying the pack's identity (the slot Construct uses for "Include: Sheet") -
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
	var host_class: String = ""
	var identity_seen: bool = false
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
	# The file's own opening sentence when the importer recovered no class description (see below).
	var strip_about: String = ""
	for index in range(rows.size()):
		var row_data: EventRowData = rows[index]
		var source: Resource = row_data.source_resource
		if row_data.row_uid.begins_with("scaffolding_strip_"):
			identity_seen = true
			# A hand-written script writes its doc block ABOVE `class_name`, where the importer's
			# class-description rule (the block under `extends`) never sees it - so the sentence that
			# says what the file IS would fold into the strip and disappear with it. Kept here as the
			# comment bar's fallback, because the head is exactly where a reader looks for it.
			strip_about = _scaffolding_about_text(row_data)
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
		# M34 - `const BULLET_SCENE := preload("res://bullet.tscn")` lifts to a `preload` block, not a
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
	# Nothing that reads as a pack head - leave the sheet exactly as it was built.
	if not identity_seen or (triggers.is_empty() and knobs.is_empty()):
		return rows
	var head: Array[EventRowData] = [_build_pack_include_bar_row(sheet, host_class)]
	var about_index: int = _pack_about_row_index(rows, consumed)
	var about_row: EventRowData = rows[about_index] if about_index >= 0 else _build_pack_about_row(sheet, strip_about)
	if about_row != null:
		about_row.indent = 0
		head.append(about_row)
	if not triggers.is_empty():
		var fires_subtitle: String = EventSheetL10n.translate("this pack fires - %d") \
			if is_addon_pack(sheet) \
			else EventSheetL10n.translate("this script fires - %d")
		head.append(_build_head_group_row(
			sheet,
			"pack_triggers",
			EventSheetL10n.translate("Triggers"),
			fires_subtitle % triggers.size(),
			triggers
		))
	head.append_array(_build_knob_group_rows(sheet, knobs))
	head.append_array(leftovers)
	var output: Array[EventRowData] = []
	output.append_array(head)
	for tail_index in range(consumed, rows.size()):
		if tail_index == about_index:
			continue  # the about text reads at the TOP now; a second copy at the end is the grey wall
		output.append(rows[tail_index])
	return output


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


## The prose inside a folded Class setup strip - the `##` block a hand-written script opens with,
## which sits ABOVE `class_name` and so is never the importer's "class description". "" when the
## strip holds only code and annotations.
func _scaffolding_about_text(strip_row: EventRowData) -> String:
	for child: EventRowData in strip_row.children:
		if not (child.source_resource is RawCodeRow):
			continue
		var code_lines: PackedStringArray = (child.source_resource as RawCodeRow).code.split("\n")
		if not is_comment_only_block(code_lines):
			continue
		var prose: String = _head_comment_text(code_lines)
		if not prose.is_empty():
			return prose
	return ""


## The file's identity as ONE bar, in the slot Construct uses for its "Include: Sheet" strip. A pack
## introduces itself as one - `⇥ Addon Pack  [FPSController] [v1.0.0]  behaves on a  [CharacterBody3D]`
## - and any other opened script names the OBJECT it drives instead (M34):
## `⇥ [icon] Player  a  [CharacterBody2D]  · player.gd · scene Player.tscn`. Inert (null source) and
## wearing the same accent band + 1.5x presence the Class setup and Host binding bars wore, because it
## replaces all three of them on a read-only preview.
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
		"badge_bg": EventSheetPalette.COLOR_SETUP_BADGE_BG,
		"badge_fg": EventSheetPalette.COLOR_SETUP_BADGE_FG,
		"kind": "pack_include",
		"line_index": 0
	}
	var icon_class: String = host_class if not host_class.is_empty() else sheet.host_class
	var identity_icon: Texture2D = ACEPickerDialog.editor_icon(icon_class) if not icon_class.is_empty() else null
	if identity_icon != null:
		badge_meta["badge_icon"] = identity_icon
	var spans: Array[SemanticSpan] = [_make_span("⇥", SemanticSpan.SpanType.KEYWORD, badge_meta)]
	if not is_addon_pack(sheet):
		spans.append_array(_script_include_spans(sheet))
		row_data.spans = spans
		return row_data
	spans.append(_make_span(
		EventSheetL10n.translate("Addon Pack"),
		SemanticSpan.SpanType.VALUE,
		{"editable": false, "kind": "pack_include", "line_index": 0, "text_color": EventSheetPalette.TEXT_PRIMARY}
	))
	var pack_name: String = sheet.custom_class_name.strip_edges()
	if pack_name.is_empty():
		pack_name = str(sheet.external_source_path).get_file().get_basename()
	if not pack_name.is_empty():
		spans.append(_pack_include_chip(pack_name))
	var version: String = sheet.addon_version.strip_edges()
	if not version.is_empty():
		spans.append(_pack_include_chip("v%s" % version))
	if not host_class.is_empty():
		spans.append(_make_span(EventSheetL10n.translate("behaves on a"), SemanticSpan.SpanType.VALUE, {
			"editable": false, "kind": "pack_include", "line_index": 0, "text_color": EventSheetPalette.TEXT_MUTED
		}))
		spans.append(_pack_include_chip(host_class))
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


## M34 - the rest of a plain script's Include bar: the OBJECT it drives, the class it is, and the two
## receipts (its file, and the scene it is attached to) muted at the end.
##
## The name is the one a reader already uses for this thing: its `class_name` when it has one, else the
## ROOT NODE of the scene the script is attached to (a scene script rarely declares a class, and
## "Player" is what its author calls it), else the file name, which is the last thing left.
func _script_include_spans(sheet: EventSheetResource) -> Array[SemanticSpan]:
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var source_path: String = str(sheet.external_source_path)
	var scene: Dictionary = scene_using_script(source_path) if not source_path.is_empty() else {}
	var object_name: String = sheet.custom_class_name.strip_edges()
	if object_name.is_empty():
		object_name = str(scene.get("root_name", ""))
	if object_name.is_empty():
		object_name = source_path.get_file().get_basename()
	var spans: Array[SemanticSpan] = []
	if not object_name.is_empty():
		spans.append(_make_span(object_name, SemanticSpan.SpanType.OBJECT, {
			"editable": false, "kind": "pack_include", "line_index": 0,
			"text_color": event_style.object_label_color
		}))
	var base_class: String = sheet.host_class.strip_edges()
	if not base_class.is_empty() and base_class != object_name:
		spans.append(_make_span(EventSheetL10n.translate("a"), SemanticSpan.SpanType.VALUE, {
			"editable": false, "kind": "pack_include", "line_index": 0, "text_color": EventSheetPalette.TEXT_MUTED
		}))
		spans.append(_pack_include_chip(base_class))
	var receipts: PackedStringArray = PackedStringArray()
	if not source_path.is_empty():
		receipts.append("· %s" % source_path.get_file())
	if not scene.is_empty():
		receipts.append("· %s %s" % [EventSheetL10n.translate("scene"), str(scene.get("scene_path", "")).get_file()])
	if not receipts.is_empty():
		spans.append(_make_span(" ".join(receipts), SemanticSpan.SpanType.COMMENT, {
			"editable": false, "kind": "pack_include", "line_index": 0, "text_color": EventSheetPalette.TEXT_MUTED
		}))
	return spans


func _pack_include_chip(text: String) -> SemanticSpan:
	return _make_span(text, SemanticSpan.SpanType.KEYWORD, {
		"editable": false,
		"badge": true,
		"badge_style": "scope",
		"badge_bg": EventSheetPalette.COLOR_CHIP_BG,
		"badge_fg": EventSheetPalette.COLOR_CHIP_FG,
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


## The comment bar when the file keeps no trailing about-comment: the class description (the `##` block
## under `extends`) drawn in the comment-row look. Inert - it is a lens over sheet metadata, not a row
## the file actually carries.
func _build_pack_about_row(sheet: EventSheetResource, fallback_text: String = "") -> EventRowData:
	var description: String = sheet.class_description.strip_edges()
	if description.is_empty():
		description = fallback_text.strip_edges()
	if description.is_empty():
		return null
	var comment := CommentRow.new()
	comment.text = description
	var row_data: EventRowData = _build_comment_row(comment, 0)
	row_data.source_resource = null
	row_data.row_uid = "pack_about_%d" % sheet.get_instance_id()
	for span: SemanticSpan in row_data.spans:
		if span.metadata is Dictionary:
			(span.metadata as Dictionary)["editable"] = false
	return row_data


## The pack's knobs as Construct setting folders: one bar per @export_group in FILE order, a Settings
## bar for exported knobs declared before any group, and Internal state for the rest.
func _build_knob_group_rows(sheet: EventSheetResource, knobs: Array) -> Array[EventRowData]:
	var order: PackedStringArray = PackedStringArray()
	var buckets: Dictionary = {}
	var internal: Array[EventRowData] = []
	for entry: Variant in knobs:
		var record: Dictionary = entry as Dictionary
		var variable: LocalVariable = record.get("variable")
		# A prebuilt row (a `preload` block read as an Object) is never exported - it is something the
		# file keeps for itself, so it lands with the rest of the internal state, in file order.
		if variable == null:
			internal.append(record.get("row") as EventRowData)
			continue
		var row_data: EventRowData = _build_reading_variable_row(variable, str(record.get("description", "")), 1)
		if not variable.exported:
			internal.append(row_data)
			continue
		var group_name: String = str(record.get("group", "")).strip_edges()
		if group_name.is_empty():
			group_name = EventSheetL10n.translate("Settings")
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
		var internal_subtitle: String = EventSheetL10n.translate("values the pack keeps for itself - %d") \
			if is_addon_pack(sheet) \
			else EventSheetL10n.translate("values this script keeps for itself - %d")
		bars.append(_build_head_group_row(
			sheet,
			"pack_internal_state",
			EventSheetL10n.translate("Internal state"),
			internal_subtitle % internal.size(),
			internal
		))
	return bars


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
			"text_color": EventSheetPalette.TEXT_MUTED
		})
	]
	return row_data


## A knob in the Construct reading: `[number] jump_velocity = 4.5  Upward velocity applied on a jump.`
## The type word leads as a chip (a reader learns WHAT it is, not that GDScript spells it `float`), and
## the @export / group chips are gone - the bar above the row carries the group, and everything inside
## a settings bar is exported by definition.
func _build_reading_variable_row(variable: LocalVariable, description: String, indent: int) -> EventRowData:
	# M20 - an @onready node reference is an OBJECT, not a value: it reads as an Object
	# declaration here too, so the head's variable list and the event tree agree.
	var object_row: EventRowData = _build_object_declaration_row(variable, indent)
	if object_row != null:
		return object_row
	# M34 - a preloaded scene / script / resource is an OBJECT too, whichever row shape carried it.
	var preload_path: String = preloaded_path(str(variable.default_value))
	if not preload_path.is_empty():
		var preload_row: EventRowData = _build_preload_object_row(
			variable.name, preload_path, indent, variable, "variable_reading_%d" % variable.get_instance_id()
		)
		if preload_row != null:
			return preload_row
	return _build_variable_row(
		"tree",
		variable.name,
		variable.type_name,
		variable.default_value,
		indent,
		{
			"is_constant": variable.is_constant,
			"expression_default": variable.expression_default or variable.inferred_type or variable.onready,
			"source_resource": variable,
			"row_uid": "variable_reading_%d" % variable.get_instance_id(),
			"reading": true,
			"description": description
		}
	)


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
			meta["text_color"] = EventSheetPalette.TEXT_MUTED
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
## published verb draws as a Construct Function block - ƒ, its name, its inputs, nothing else - and its
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
## next to the row they configure is noise a Construct user has no way to interpret. Every surface
## that turns doc comments into captions filters through here.
static func is_ace_annotation_line(line: String) -> bool:
	return strip_comment_prefix(line).strip_edges().begins_with("@ace_")


## The first real sentence of a function's doc comment - the caption a helper wears in its RIGHT lane,
## because a doc comment is exactly how a Construct user reads a function they did not write. Empty
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
		return [EventSheetPalette.COLOR_CHIP_BG, EventSheetPalette.COLOR_CHIP_FG]
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
		"int", "float":
			return EventSheetL10n.translate("number")
		"bool":
			return EventSheetL10n.translate("true/false")
		"Vector2", "Vector3":
			return EventSheetL10n.translate("point")
		"Color":
			return EventSheetL10n.translate("color")
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
				return EventSheetL10n.translate("node")
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
			return EventSheetL10n.translate("true/false values")
		"Vector2", "Vector3", "Vector4":
			return EventSheetL10n.translate("points")
		"Color":
			return EventSheetL10n.translate("colors")
		"Dictionary":
			return EventSheetL10n.translate("tables")
		_:
			var bare_type: String = type_name.strip_edges()
			if ClassDB.class_exists(bare_type) and ClassDB.is_parent_class(bare_type, "Node"):
				return EventSheetL10n.translate("nodes")
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
	# The whole verb reads as a Construct-style event block tinted by its ACE kind: a wash of the role's
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
	# READING MODE: the verb reads as a Construct Function block - ƒ, its name, one chip per input, and
	# nothing else. Its kind survives as the header's wash (the role accent at VERB_KIND_TINT_ALPHA),
	# and every other property it has - category, description, what it gives back, whether it is
	# featured, the line it inserts - lives one click away in the ACE properties popup.
	if _verb_reading_mode():
		row_data.custom_color = Color(
			role_accent.r, role_accent.g, role_accent.b,
			maxf(_verb_tint_strength(), VERB_KIND_TINT_ALPHA)
		)
		row_data.spans = _build_verb_function_block_spans(event_function, role, display_name)
		# The header is the whole block: with nothing in the right lane, the input chips get the WHOLE
		# row instead of being squeezed into the condition track (at a narrow lane split, "y  number"
		# clipped to "y  numb"). A helper's doc caption does live in the right lane, so that header
		# keeps the two-lane split.
		row_data.full_width_lanes = not _has_action_lane_span(row_data.spans)
		_append_verb_body_rows(row_data, event_function, indent, display_name)
		row_data.line_count = 1
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
			var add_color: Color = add_style_meta.get("text_color", EventSheetPalette.COLOR_CONDITION)
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
		spans.append(_define_chip(EventSheetL10n.translate("static"), chip_bg, muted, 0))
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
	row_data.spans = spans
	_append_verb_body_rows(row_data, event_function, indent, display_name)
	row_data.line_count = maxi(condition_lines, 1)
	return row_data


## True when any span of a row sits in the ACTION lane - i.e. the row's right half carries something.
static func _has_action_lane_span(spans: Array[SemanticSpan]) -> bool:
	for span: SemanticSpan in spans:
		if span != null and span.metadata is Dictionary and str((span.metadata as Dictionary).get("lane", "")) == "action":
			return true
	return false


## ƒ + the verb's DISPLAY NAME + one chip per input, and nothing else - the Construct Function block
## header a pack reads as in Reading mode. A display name written with the plugin's BBCode-lite
## (`Take [b]amount[/b] damage`) draws STYLED: the span carries the stripped text plus the parsed
## segments the renderer paints, so the tags themselves are never printed. An unpublished helper adds
## the one caption a Construct user reads a function by - its doc comment - in the RIGHT lane, muted.
func _build_verb_function_block_spans(event_function: EventFunction, role: String, display_name: String) -> Array[SemanticSpan]:
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
	var name_meta: Dictionary = {
		"editable": false,
		"kind": "define_function",
		"lane": "condition",
		"line_index": 0,
		"text_color": name_color
	}
	var plain_name: String = display_name
	if EventSheetBBCodeLite.has_markup(display_name):
		plain_name = EventSheetBBCodeLite.strip(display_name)
		name_meta["bbcode_segments"] = EventSheetBBCodeLite.parse(display_name, name_color)
	spans.append(_make_span(plain_name, SemanticSpan.SpanType.OBJECT, name_meta))
	# The inputs, as Construct's own input chips - `enabled  true/false` - INLINE on the header line,
	# because the header is the whole block: a reader takes in the verb and what it needs in one look.
	var chip_texts: PackedStringArray = PackedStringArray()
	for param: Variant in event_function.params:
		if param is ACEParam:
			chip_texts.append("%s  %s" % [
				friendly_param_label(param as ACEParam),
				_define_param_type_word(param as ACEParam)
			])
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
	if not event_function.expose_as_ace:
		var doc_line: String = helper_doc_line(event_function)
		if not doc_line.is_empty():
			spans.append(_make_span(doc_line, SemanticSpan.SpanType.COMMENT, {
				"editable": false,
				"kind": "define_function",
				"lane": "action",
				"line_index": 0,
				"text_color": EventSheetPalette.TEXT_MUTED
			}))
	return spans


## The verb's BODY as foldable children, plus the fold seed and the "+ Add event" way in. Shared by
## both header forms so a Reading-mode block opens exactly like an authoring one.
func _append_verb_body_rows(row_data: EventRowData, event_function: EventFunction, indent: int, display_name: String) -> void:
	# Construct-style expandable block: the function BODY renders as foldable children (its conditions,
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
				_mark_verb_body(child_row, _current_verb_kind())
				# M23 runs HERE, before the body is made inert: the sub-event pair is derived from the
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


## Strips a row and its whole subtree of its editing identity so it renders but is inert - no selection,
## drag, delete, or inline edit reaches it (every mutation path guards on source_resource being the row's
## kind, and the add-cell click guards on a non-null source). Used for a published verb's body rows: they
## display the function's conditions/actions/raw blocks for reading, but their resources live in
## event_function.events, not sheet.events, so any write would alias or corrupt the .gd. Read-only reveal.
func _make_row_inert(row_data: EventRowData) -> void:
	# Resolve the spans BEFORE dropping the resource. Event-row spans are built LAZILY, and
	# _ensure_event_spans reads them off source_resource - so nulling first leaves the row permanently
	# blank. That went unseen only while verb bodies defaulted to folded and were never laid out.
	_ensure_event_spans(row_data)
	row_data.source_resource = null
	for child: EventRowData in row_data.children:
		_make_row_inert(child)


## Flags a row and its whole subtree as living inside a published verb's body, so a condition-less
## event reads "Always" (it runs when the verb is called) instead of the sheet-level "Every Tick"
## (which is only true of the sheet's own events, since a sheet compiles into _process).
func _mark_verb_body(row_data: EventRowData, verb_kind: int = EventSheetSentence.VerbKind.ACTION) -> void:
	row_data.in_verb_body = true
	row_data.verb_kind = verb_kind
	for child: EventRowData in row_data.children:
		_mark_verb_body(child, verb_kind)


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
		"badge_bg": event_style.behavior_accent_color.lerp(EventSheetPalette.COLOR_LANE_DIVIDER, 0.45),
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
		spans.append(_make_span(EventSheetL10n.translate("is one of"), SemanticSpan.SpanType.COMMENT, {"kind": "enum_row", "text_color": EventSheetPalette.TEXT_MUTED}))
		for name_index: int in range(spoken):
			if name_index > 0 and name_index == spoken - 1 and names.size() <= spoken:
				spans.append(_make_span(EventSheetL10n.translate("or"), SemanticSpan.SpanType.COMMENT, {"kind": "enum_row", "text_color": EventSheetPalette.TEXT_MUTED}))
			# The comma rides INSIDE the value span - spans are auto-spaced, and "PATROL ," is
			# exactly the boxed-fragment look the sentence exists to avoid.
			var needs_comma: bool = name_index < spoken - 1 and not (name_index == spoken - 2 and names.size() <= spoken)
			spans.append(_make_span(names[name_index] + ("," if needs_comma else ""), SemanticSpan.SpanType.VALUE, {"kind": "enum_row"}))
		if names.size() > spoken:
			spans.append(_make_span("%s %d %s" % [EventSheetL10n.translate("and"), names.size() - spoken, EventSheetL10n.translate("more")], SemanticSpan.SpanType.COMMENT, {"kind": "enum_row", "text_color": EventSheetPalette.TEXT_MUTED}))
	else:
		spans.append(_make_span("- %d %s" % [names.size(), EventSheetL10n.translate("values")], SemanticSpan.SpanType.COMMENT, {"kind": "enum_row", "text_color": EventSheetPalette.TEXT_MUTED}))
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
				_make_span(entry_note, SemanticSpan.SpanType.COMMENT, {"kind": "enum_value", "text_color": EventSheetPalette.TEXT_MUTED})
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
			add_row.spans = [_make_span(EventSheetL10n.translate("+ Add value…"), SemanticSpan.SpanType.COMMENT, {"kind": "enum_add", "text_color": EventSheetPalette.TEXT_MUTED})]
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
	# Regions carry NO kind pill: the fold arrow, the colored label, the bubble
	# outline, and the inline description already say what the row is. The label
	# wears the region's own color (shared with the bubble), defaulting to the
	# behavior accent so region headers always stand apart from comments.
	if block.kind_id == "region":
		var region_color: String = str(block.fields.get("color", "")).strip_edges()
		var accent: Color = Color.html(region_color) if Color.html_is_valid(region_color) else event_style.behavior_accent_color
		if bool(block.fields.get("is_end", false)):
			# The closing fence is plumbing: one dim marker line. The pairing pass
			# refines this to "end of <label>" once its opener is known.
			row_data.spans = [_make_span(
				"end region",
				SemanticSpan.SpanType.VALUE,
				{"kind": "custom_block_row", "text_color": Color(EventSheetPalette.TEXT_MUTED.r, EventSheetPalette.TEXT_MUTED.g, EventSheetPalette.TEXT_MUTED.b, 0.7)}
			)]
			return row_data
		var region_label: String = str(block.fields.get("label", "")).strip_edges()
		row_data.spans = [_make_span(
			region_label if not region_label.is_empty() else "(unnamed region)",
			SemanticSpan.SpanType.VALUE,
			{"kind": "custom_block_row", "text_color": accent}
		)]
		var region_description: String = str(block.fields.get("description", "")).strip_edges()
		if not region_description.is_empty():
			row_data.spans.append(_make_span(
				region_description,
				SemanticSpan.SpanType.VALUE,
				{"text_color": Color(EventSheetPalette.TEXT_SECONDARY.r, EventSheetPalette.TEXT_SECONDARY.g, EventSheetPalette.TEXT_SECONDARY.b, 0.8)}
			))
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
						"badge_bg": EventSheetPalette.COLOR_CONST_BADGE_BG if is_const_style else EventSheetPalette.COLOR_GROUP_CHIP_BG,
						"badge_fg": EventSheetPalette.COLOR_CONST_BADGE_FG if is_const_style else EventSheetPalette.COLOR_GROUP_CHIP_FG
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
			{"kind": "custom_block_row", "text_color": Color(0.88, 0.42, 0.42, 1.0)}
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
	var bind: RegEx = RegEx.new()
	if bind.compile("^\\thost = get_parent\\(\\) as ([A-Za-z_][A-Za-z0-9_]*)$") != OK:
		return ""
	var bind_match: RegExMatch = bind.search(lines[1])
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
	var header_regex: RegEx = RegEx.new()
	if header_regex.compile("^(?:static )?func ([A-Za-z_][A-Za-z0-9_]*)\\((.*)\\)(?: -> (.+))?:$") != OK:
		return {}
	var header_match: RegExMatch = header_regex.search(lines[header_index])
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


## The Construct-3 sentence a single GDScript statement reads as: `score += wave[1]` becomes
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
	# M28: the awaits Construct has words for, ahead of the grammar - a hand-written `await` that no
	# ACE claimed (inside a lambda, inside a block that stayed code) reads the same as the lifted row
	# beside it. Every other await falls straight through and keeps its GDScript.
	var awaited: Dictionary = _raw_await_reading(code)
	if not awaited.is_empty():
		return awaited
	return EventSheetSentence.statement(code, context)


## The M28 reading of a hand-written `await <expression>` line, indent and all, or {} when the shape
## is not one of the named ones.
static func _raw_await_reading(code: String) -> Dictionary:
	var indent: int = 0
	while indent < code.length() and code[indent] == "\t":
		indent += 1
	var text: String = code.substr(indent).strip_edges()
	if not text.begins_with("await "):
		return {}
	var reading: Dictionary = await_reading(text.substr(6), true)
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
	var word_regex: RegEx = RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*")
	var found: RegExMatch = word_regex.search(text)
	return found.get_string(0) if found != null else ""


## True when `text` is a plain identifier - the only thing a "Let <name>" sentence may name.
static func _is_identifier(text: String) -> bool:
	var identifier_regex: RegEx = RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*$")
	return identifier_regex.search(text) != null


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
	var header: RegEx = RegEx.new()
	if header.compile("^class ([A-Za-z_][A-Za-z0-9_]*)(?: extends [A-Za-z_][A-Za-z0-9_.]*)?:$") != OK:
		return ""
	var header_match: RegExMatch = header.search(lines[i])
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
	var header: RegEx = RegEx.new()
	if header.compile("^class ([A-Za-z_][A-Za-z0-9_]*)(?: extends [A-Za-z_][A-Za-z0-9_.]*)?:$") != OK:
		return ""
	var header_match: RegExMatch = header.search(lines[i])
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
	var ext: RegEx = RegEx.new()
	if ext.compile("^class [A-Za-z_][A-Za-z0-9_]*(?: extends ([A-Za-z_][A-Za-z0-9_.]*))?:$") == OK:
		var ext_match: RegExMatch = ext.search(header_line)
		if ext_match != null:
			extends_base = ext_match.get_string(1)
	i += 1
	var with_default: RegEx = RegEx.new()
	with_default.compile("^\\tvar ([A-Za-z_][A-Za-z0-9_]*): (\\S.*?) = (.+)$")
	var no_default: RegEx = RegEx.new()
	no_default.compile("^\\tvar ([A-Za-z_][A-Za-z0-9_]*): (\\S.*)$")
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
		"text_color": EventSheetPalette.TEXT_PRIMARY
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
			"badge_bg": EventSheetPalette.COLOR_SETUP_BADGE_BG,
			"badge_fg": EventSheetPalette.COLOR_SETUP_BADGE_FG,
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
				"text_color": EventSheetPalette.TEXT_PRIMARY
			}),
			_make_span(host_class, SemanticSpan.SpanType.KEYWORD, {
				"editable": false,
				"badge": true,
				"badge_style": "scope",
				"badge_bg": EventSheetPalette.COLOR_CHIP_BG,
				"badge_fg": EventSheetPalette.COLOR_CHIP_FG,
				"kind": "raw_code",
				"line_index": 0
			}),
			_make_span("the node this behaviour is attached to · double-click to edit in code", SemanticSpan.SpanType.VALUE, {
				"editable": false,
				"kind": "raw_code",
				"line_index": 0,
				"text_color": EventSheetPalette.TEXT_MUTED
			})
		]
		return row_data
	var shell: Dictionary = define_shell_info(raw_row.code)
	if not shell.is_empty():
		row_data.line_count = 1  # visual collapse only - the underlying lines are all still there
		row_data.language_block = true  # a published-verb annotation shell - language structure
		var badge_colors: Dictionary = {
			"action": [EventSheetPalette.COLOR_ACE_ACTION_BADGE_BG, EventSheetPalette.COLOR_ACE_ACTION_BADGE_FG],
			"condition": [EventSheetPalette.COLOR_ACE_CONDITION_BADGE_BG, EventSheetPalette.COLOR_ACE_CONDITION_BADGE_FG],
			"expression": [EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_BG, EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_FG],
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
				"badge_bg": EventSheetPalette.COLOR_CAT_CHIP_BG,
				"badge_fg": EventSheetPalette.COLOR_CAT_CHIP_FG,
				"kind": "raw_code",
				"line_index": 0
			}))
		shell_spans.append(_make_span("publishes the func below · %d annotation lines" % int(shell.get("line_count")), SemanticSpan.SpanType.VALUE, {
			"editable": false,
			"kind": "raw_code",
			"line_index": 0,
			"text_color": EventSheetPalette.TEXT_MUTED
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
				"badge_bg": EventSheetPalette.COLOR_CODE_BADGE_BG,
				"badge_fg": EventSheetPalette.COLOR_CODE_BADGE_FG,
				"kind": "raw_code",
				"line_index": 0
			}),
			_make_span("%s %s" % [str(literal_info.get("head")), str(literal_info.get("close"))],
				SemanticSpan.SpanType.OBJECT, {
					"editable": false,
					"kind": "raw_code",
					"line_index": 0,
					"text_color": EventSheetPalette.TEXT_PRIMARY
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
		var function_spans: Array[SemanticSpan] = [
			_make_span("ƒ", SemanticSpan.SpanType.KEYWORD, {
				"editable": false,
				"badge": true,
				"badge_style": "scope",
				"badge_bg": EventSheetPalette.COLOR_CODE_BADGE_BG,
				"badge_fg": EventSheetPalette.COLOR_CODE_BADGE_FG,
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
				"badge_bg": EventSheetPalette.COLOR_CHIP_BG,
				"badge_fg": EventSheetPalette.COLOR_CHIP_FG,
				"kind": "raw_code",
				"line_index": 0
			}))
		var body_line_count: int = int(function_info.get("body_lines"))
		function_spans.append(_make_span("function · %d line%s" % [body_line_count, "" if body_line_count == 1 else "s"], SemanticSpan.SpanType.VALUE, {
			"editable": false,
			"kind": "raw_code",
			"line_index": 0,
			"text_color": EventSheetPalette.TEXT_MUTED
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
	var line_fg: Color = EventSheetPalette.TEXT_MUTED if is_scaffold else EventSheetPalette.TEXT_PRIMARY
	var spans: Array[SemanticSpan] = []
	# Scaffold blocks carry NO "GDScript" pill: they live under the Class setup dropdown, whose
	# facts already say what they are - the pill was pure noise there (and a word in a box). The
	# pill stays on REAL logic blocks only, where it marks the escape hatch.
	if not is_scaffold:
		spans.append(_make_span("GDScript", SemanticSpan.SpanType.KEYWORD, {
			"editable": false,
			"badge": true,
			"badge_style": "scope",
			"badge_bg": EventSheetPalette.COLOR_CODE_BADGE_BG,
			"badge_fg": EventSheetPalette.COLOR_CODE_BADGE_FG,
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
			"badge_bg": EventSheetPalette.COLOR_LIFT_NOTE_BADGE_BG,
			"badge_fg": EventSheetPalette.COLOR_LIFT_NOTE_BADGE_FG,
			"kind": "lift_note",
			"line_index": 0
		}))
	# ── M17 - the folded code card ─────────────────────────────────────────────────────────────
	# A block that could not lift is a wall of statements you did not ask to read. While READING a
	# sheet it costs one row - "code · 12 lines" - and opens in place to the exact GDScript; while
	# AUTHORING one the statement lines stay put, because those are what you edit. The fold rides
	# the CHILD-row mechanism the enum fold already uses, so the arrow, the click, the keyboard
	# fold and the fold memory all work here without a line of new interaction code.
	if _viewport.is_reading_mode() and code_lines.size() > 1:
		spans.append(_make_span(
			EventSheetViewportReadingRows.code_card_label(code_lines.size()),
			SemanticSpan.SpanType.VALUE,
			{"editable": false, "kind": "raw_code", "line_index": 0, "text_color": EventSheetPalette.TEXT_MUTED}
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
## render and by what an M17 code card opens to, so "the code" is literally the same rows either
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
	var header_text: String = "class %s" % data_class_display_name
	if not base.is_empty():
		header_text += " extends %s" % base
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
			"text_color": EventSheetPalette.TEXT_MUTED
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
			"text_color": EventSheetPalette.TEXT_MUTED
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
	var header_regex: RegEx = RegEx.new()
	header_regex.compile("^(static )?func ([A-Za-z_][A-Za-z0-9_]*)\\((.*)\\)(?: -> (.+))?:$")
	var header_match: RegExMatch = header_regex.search(method_lines[0])
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
			"text_color": EventSheetPalette.TEXT_MUTED
		}.merged(action_style, true)))
	row_data.spans = spans
	return row_data


## M20 - an `@onready var hp_bar: ProgressBar = %HpBar` read as an OBJECT declaration rather than
## as a value one: this is how Construct's object list is recovered from a script. The row says
## what the object is called, which node it is, and its class - with the class's own Godot icon,
## the same icon every later row using `hp_bar` as its object then shows (M13).
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
	# ── M47 lens hook ──────────────────────────────────────────────────────────────────────────
	# A `get_node("A/B")` lookup names the same object `$A/B` does, so it reads as that reference -
	# and the `_or_null` spelling says, in the muted note, that the object may not be there.
	var declaration_value: Dictionary = EventSheetViewportReadingRows.object_declaration_value(variable)
	var node_reference: String = str(declaration_value.get("value", ""))
	var missing_note: String = str(declaration_value.get("note", ""))
	var declared_class: String = EventSheetViewportReadingRows.declared_class_of(variable)
	# The object's NAME is not humanized, even with the lens on: this row is where the object gets
	# its identity, and every later row refers to it by exactly this spelling. Construct shows an
	# object's name verbatim in its object list for the same reason.
	var shown_name: String = variable.name
	var spans: Array[SemanticSpan] = [
		_make_span(EventSheetL10n.translate("Object"), SemanticSpan.SpanType.KEYWORD, {
			"editable": false, "kind": "variable", "line_index": 0, "badge": true, "badge_style": "scope",
			"badge_bg": EventSheetPalette.COLOR_GROUP_CHIP_BG, "badge_fg": EventSheetPalette.COLOR_GROUP_CHIP_FG
		}),
		_make_span(shown_name, SemanticSpan.SpanType.OBJECT, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": event_style.object_label_color
		}),
		_make_span("=", SemanticSpan.SpanType.OPERATOR, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": EventSheetPalette.TEXT_MUTED
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
			"text_color": EventSheetPalette.TEXT_MUTED
		}))
	if not missing_note.is_empty():
		spans.append(_make_span(missing_note, SemanticSpan.SpanType.COMMENT, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": EventSheetPalette.TEXT_MUTED
		}))
	row_data.spans = spans
	return row_data


## M34 - a preloaded scene, script or resource is an OBJECT, not a value: `bullet_scene` holding
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
			"badge_bg": EventSheetPalette.COLOR_GROUP_CHIP_BG, "badge_fg": EventSheetPalette.COLOR_GROUP_CHIP_FG
		}),
		_make_span(object_name, SemanticSpan.SpanType.OBJECT, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": event_style.object_label_color
		}),
		_make_span("=", SemanticSpan.SpanType.OPERATOR, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": EventSheetPalette.TEXT_MUTED
		}),
		_make_span(str(resolved.get("name", "")), SemanticSpan.SpanType.VALUE, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": event_style.value_highlight_color,
			"object_icon": icon
		}),
		_make_span("%s · %s" % [str(resolved.get("kind_word", "")), res_path.get_file()], SemanticSpan.SpanType.COMMENT, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": EventSheetPalette.TEXT_MUTED
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


## The scene a script is attached to as its ROOT, as {scene_path, root_name} - what lets a script with
## no `class_name` still be named after the object it drives. {} when no scene in the project uses it
## that way. Built by ONE sweep of the project's .tscn files (a scene names its scripts in the
## `[ext_resource]` lines at the very top, so only the head of each file is read) and cached for the
## session, because the answer cannot change while the editor holds the file open.
static func scene_using_script(script_path: String) -> Dictionary:
	if not _script_scene_scanned:
		_script_scene_scanned = true
		_scan_scenes_for_scripts("res://")
	return _script_scene_cache.get(script_path, {})


static func _scan_scenes_for_scripts(directory_path: String) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var full_path: String = directory_path.path_join(entry)
		if directory.current_is_dir():
			_scan_scenes_for_scripts(full_path)
		elif entry.get_extension().to_lower() == "tscn":
			_record_scene_root_script(full_path)
		entry = directory.get_next()
	directory.list_dir_end()


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
	# M20 - while reading, an @onready node reference is an OBJECT declaration, not a variable row.
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
			"source_resource": variable,
			"row_uid": "variable_tree_%d" % variable.get_instance_id()
		}
	)
	# A PROPERTY (setter and/or getter): read it as a language block - the variable identity stays the row,
	# and each accessor folds under it as a condition/action child (`set(value)` / `get` in the condition
	# cell, its body lines as actions). Double-click the variable row still opens the Variable dialog.
	if variable.has_property_accessors():
		row_data.language_block = true
		var param: String = variable.setter_param.strip_edges() if not variable.setter_param.strip_edges().is_empty() else "value"
		if not variable.setter_body.strip_edges().is_empty():
			row_data.children.append(_build_property_accessor_row(variable, "set(%s)" % param, variable.setter_body, indent + 1, "set"))
		if not variable.getter_body.strip_edges().is_empty():
			row_data.children.append(_build_property_accessor_row(variable, "get", variable.getter_body, indent + 1, "get"))
		row_data.folded = bool(_viewport._fold_state.get(row_data.row_uid, false))
	return row_data


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
	# The group's distinctive chrome (accent bar + tinted background, drawn from row_type == GROUP)
	# already reads unmistakably as a group, so the old leading "Group" text badge was pure clutter -
	# the header is a FOLDER icon (the editor-theme Folder texture, the file-manager idiom) plus the
	# inline-editable title (and an optional description line). Headless the icon resolves null and
	# simply does not draw.
	row_data.spans = [
		_make_span(
			_viewport._group_name(group),
			SemanticSpan.SpanType.OBJECT,
			{
				"editable": true,
				"edit_kind": "group_name",
				"group_title": true,
				"object_icon": _folder_icon() if _viewport.show_object_icons else null,
				"text_color": event_style.group_title_color
			}
		)
	]
	# Event-sheet-style group description: a muted second line on the header, inline-editable.
	if not group.description.strip_edges().is_empty():
		row_data.line_count = 2
		row_data.spans.append(
			_make_span(
				group.description,
				SemanticSpan.SpanType.COMMENT,
				{
					"editable": true,
					"edit_kind": "group_description",
					"line_index": 1,
					"text_color": event_style.comment_text_color
				}
			)
		)
	for child in _viewport._group_children(group):
		var child_row: EventRowData = _viewport._build_row_from_resource(child, indent + 1)
		if child_row != null:
			row_data.children.append(child_row)
	# Event-sheet-style per-group footer: always the group's last child, one level deeper. A read-only
	# preview grows none: nothing can be added to it.
	if _viewport.show_add_event_footers and not _scaffolding_suppressed():
		row_data.children.append(
			_build_add_event_footer_row(group, indent + 1, "+ Add event to '%s'…" % _viewport._group_name(group))
		)
	return row_data


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
	var comment_spans: Array[SemanticSpan] = []
	for line_index in range(comment_lines.size()):
		var line_metadata: Dictionary = {
			"editable": true,
			"edit_kind": "comment_text",
			"line_index": line_index,
			"text_color": event_style.comment_text_color
		}
		# BBCode-lite ([b]/[i]/[color=…]): segments shape the pixels; the RAW text stays
		# the editing/serialization truth (no data loss on edit/copy).
		if EventSheetBBCodeLite.has_markup(comment_lines[line_index]):
			line_metadata["bbcode_segments"] = EventSheetBBCodeLite.parse(comment_lines[line_index], event_style.comment_text_color)
		comment_spans.append(
			_make_span(
				comment_lines[line_index],
				SemanticSpan.SpanType.COMMENT,
				line_metadata
			)
		)
	row_data.spans = comment_spans
	return row_data


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
	# Event-row spans are the expensive part of building a sheet, so they are built
	# lazily via _ensure_event_spans() only when a row is laid out/hit-tested. The
	# line count (which drives row height/metrics) is computed cheaply up front so
	# the whole sheet can be flattened and measured without building any spans.
	row_data.line_count = _count_event_lines(event_row)
	for local_variable_row in _build_local_variable_rows(event_row, indent + 1):
		row_data.children.append(local_variable_row)
	# M29 - a lambda handed to `connect` IS a trigger event; Construct has no lambdas, only triggers.
	# Its reading sits with the actions (which is where the connect line sits) and above the real
	# sub-events, because that is the order the file runs in.
	for connect_row: EventRowData in _build_connect_lambda_rows(event_row, row_data.row_uid, indent + 1):
		row_data.children.append(connect_row)
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
		# M37 - Construct has no switch. A reader of a Construct sheet knows if / else-if / else, so a
		# match on an ORDINARY value reads as that chain: the first case as its test, every later case as
		# an Else carrying its own test, `_` as a plain Else. Only shapes that MEAN "one of these values"
		# qualify; a pattern that binds a name or destructures an array is doing something an Else-if
		# cannot say, and keeps its pattern text.
		var else_if_chain: bool = not state_shaped and _match_reads_as_else_if(match_row)
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
						body.append(_friendly_statement_text(case_line))
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
			if state_shaped and pattern_text != "_":
				case_label = "%s: %s" % [EventSheetL10n.translate("State"), _pattern_leaf(pattern_text)]
			var chain_spans: Array[SemanticSpan] = []
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


# ── M39: instantiate + add_child (+ the first position) is Construct's Create object ──────────────
# Godot spells spawning as three statements that only mean anything together; Construct spells it as
# one action, and a Construct user reads the three as noise around the one thing that happened. So
# the run reads as `System ▸ Create object <Scene> at <P> (as b)` - the three lines stay exactly as
# they are in the file, on hover and under a double-click, and nothing about emission changes.


## The Create object runs in one action lane: {"leads": {index: {text, alias, line_count}}, "consumed":
## {index: true}}. A group is a local declaration (or assignment) of `<scene>.instantiate()`, the
## `add_child` / `add_sibling` that plants it, and - only when it comes straight after - the first
## line that puts it somewhere.
func _create_object_groups(actions: Array) -> Dictionary:
	var leads: Dictionary = {}
	var consumed: Dictionary = {}
	# Refreshed HERE, before anything reads it: the sentence below ADDS the new object's own name to the
	# class map, and a refresh triggered later (by the icon lookup on the very span being built) would
	# rebuild the map from the sheet and drop it again.
	_reset_lens_caches_if_stale()
	var index: int = 0
	while index < actions.size() - 1:
		var spawn: Dictionary = _instantiate_action_parts(actions[index])
		if spawn.is_empty() or not _plants_node(actions[index + 1], str(spawn.get("alias", ""))):
			index += 1
			continue
		var last: int = index + 1
		var position_text: String = ""
		if last + 1 < actions.size():
			position_text = _placement_value(actions[last + 1], str(spawn.get("alias", "")))
			if not position_text.is_empty():
				last += 1
		var indices: Array[int] = []
		for member_index: int in range(index, last + 1):
			indices.append(member_index)
		leads[index] = {
			"text": _create_object_text(str(spawn.get("source", "")), str(spawn.get("alias", "")),
				position_text, bool(spawn.get("copy", false))),
			"alias": str(spawn.get("alias", "")),
			"line_count": last - index + 1,
			"indices": indices,
		}
		for consumed_index: int in range(index + 1, last + 1):
			consumed[consumed_index] = true
		index = last + 1
	return {"leads": leads, "consumed": consumed}


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
	return {}


## True when the action is the `add_child(b)` / `add_sibling(b)` (on this node or on a named parent)
## that puts the freshly made object into the tree.
func _plants_node(action_resource: Variant, alias: String) -> bool:
	var action: ACEAction = action_resource as ACEAction
	if action == null or not action.enabled or alias.is_empty():
		return false
	if not (action.ace_id.contains("AddChild") or action.ace_id.contains("AddSibling")):
		return false
	var params: Dictionary = action.params if not action.params.is_empty() else action.parameters
	return str(params.get("node", params.get("child", ""))).strip_edges() == alias


## The value of a `b.global_position = P` / `b.position = P` that immediately follows, or "" when the
## next line is anything else. Only the FIRST placement joins the row: the ones after it are ordinary
## "set a property of the new object" actions, and Construct draws those separately too.
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


## The sentence itself. The object created is named the way a Construct user names it - the scene's
## ROOT node - whenever the source is a preloaded scene this sheet declares; otherwise the variable's
## own name, which is the honest answer when nothing else is known.
func _create_object_text(source: String, alias: String, position_text: String, copy: bool) -> String:
	var shown: String = source
	var resolved: Dictionary = _lens_scene_vars.get(source, {}) as Dictionary
	if not resolved.is_empty() and not str(resolved.get("name", "")).is_empty():
		shown = str(resolved.get("name", ""))
		# The new object answers to its local name for the rest of the event, and draws the scene root's
		# picture while it does - Construct's "picked new instance", spelled in Godot's own names.
		var icon_class: String = str(resolved.get("icon_class", ""))
		if not icon_class.is_empty() and not alias.is_empty():
			_lens_class_map[alias] = icon_class
	if copy:
		shown = "(%s %s)" % [EventSheetL10n.translate("copy of"), shown]
	var text: String = "%s %s" % [EventSheetL10n.translate("Create object"), shown]
	if not position_text.is_empty():
		# Through the shared value lens, so the place a thing is made reads exactly as it would in any
		# other cell - `Vector2(10, 20)` is a point, and Construct writes a point as `(10, 20)`.
		text += " %s %s" % [EventSheetL10n.translate("at"), _reading_sentence(EventSheetSentence.expression_text(position_text))]
	if not alias.is_empty():
		text += " (%s %s)" % [EventSheetL10n.translate("as"), alias]
	return text


## M37 - whether a `match` says nothing more than "which of these values is it?", which is the only
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
	for case_index: int in range(match_row.cases.size()):
		var match_case: MatchCase = match_row.cases[case_index]
		if match_case == null or not ViewportRowBuilder.is_plain_match_pattern(match_case.pattern):
			return false
		# A `_` anywhere but last would mean the branches after it are dead; that is not a chain.
		if str(match_case.pattern).strip_edges() == "_" and case_index != match_row.cases.size() - 1:
			return false
	return true


## The condition cells of one Else-if arm: the Else chip alone for `_`, the bare test for the first
## case, and the Else chip ABOVE the test for every case after it - which is exactly how Construct
## draws an else-if, and exactly what a chained ternary already draws here. Several values in one
## pattern (`"a", "b":`) become the OR block, since that is what the branch means.
func _match_else_if_condition_spans(subject: String, pattern: String, chain_index: int) -> Array[SemanticSpan]:
	var spans: Array[SemanticSpan] = []
	var condition_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	var text: String = pattern.strip_edges()
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


## Construct compares with a single `=`, and nobody typed the `==` in these cells: the reading built
## it, out of a match pattern that has no operator at all. So it is written the way Construct writes
## it. A comparison the user really did type is left exactly as typed, elsewhere and on purpose.
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
func _friendly_statement_text(line: String) -> String:
	var text: String = line.strip_edges()
	var sentence: Dictionary = ViewportRowBuilder.statement_sentence(text)
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
## once), never inline text. M12: a negated guard does NOT say the word "not" - the sentence is
## the positive one and the inversion is the red ✕ in the badge column, the same mark an inverted
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


## M12 - whether a guard is inverted, so the caller can draw the ✕ the sentence no longer says.
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
	for line_index: int in range(1, case_lines.size()):
		if not case_lines[line_index].begins_with("\t"):
			return null
		var inner_line: String = case_lines[line_index].substr(1)
		if inner_line.begins_with("\t") or inner_line.begins_with("elif") or inner_line.begins_with("else"):
			return null
		inner.append(_friendly_statement_text(inner_line))
	var child: EventRowData = _build_condition_action_row(_friendly_guard_text(guard), inner, indent, match_row, _guard_is_negated(guard))
	child.language_block = true
	# A computed-check guard wears the ƒ SVG badge in the icon column - the reader learns at a
	# glance the value comes from a FUNCTION, not a bool variable, without meeting parentheses.
	if _guard_is_call(guard):
		var guard_badge_meta: Dictionary = _viewport.BADGE_TRIGGER_METADATA.duplicate(true)
		guard_badge_meta["badge_bg"] = EventSheetPalette.COLOR_CODE_BADGE_BG
		guard_badge_meta["badge_fg"] = EventSheetPalette.COLOR_CODE_BADGE_FG
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
## (_friendly_guard_text does): they pass the inversion here so the ✕ still gets drawn. Callers
## handing over raw text can leave it false - the lens below finds a leading NOT on its own.
## `condition_spans`, when given, REPLACES the single condition cell this would otherwise draw - the
## M37 Else-if chain hands over its own stacked Else + test lines, built by the same helpers a ternary
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
	# M12 - a lifted `if not <cond>:` shows its inversion as the red ✕ in the badge column, exactly
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


func _build_global_variable_rows(sheet: EventSheetResource) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	if sheet == null:
		return rows
	var names: Array = sheet.variables.keys()
	# Ungrouped variables first (name-sorted), then each Inspector group as a contiguous block -
	# grouped variables must sit ADJACENT so the bubble outline can wrap them as one visual folder.
	# View-order only: the variables dictionary and the compiled output are untouched.
	names.sort_custom(func(a: Variant, b: Variant) -> bool:
		var group_a: String = _global_variable_group(sheet, str(a))
		var group_b: String = _global_variable_group(sheet, str(b))
		if group_a != group_b:
			if group_a.is_empty() or group_b.is_empty():
				return group_a.is_empty()  # ungrouped sorts first
			return group_a < group_b
		return str(a) < str(b))
	for var_name in names:
		var descriptor: Dictionary = sheet.variables.get(var_name, {})
		var is_exported: bool = bool(descriptor.get("exported", descriptor.get("exposed", true)))
		var var_attributes: Dictionary = descriptor.get("attributes") if descriptor.get("attributes") is Dictionary else {}
		rows.append(
			_build_variable_row(
				"global",
				str(var_name),
				str(descriptor.get("type", "Variant")),
				descriptor.get("default", null),
				0,
				{
					"is_constant": bool(descriptor.get("const", descriptor.get("is_constant", false))),
					# Match the compiler default (exported unless explicitly false) so the @export badge
					# agrees with what actually emits as an Inspector-visible @export var.
					"exported": is_exported,
					# The Inspector group (@export_group) this exported var lands in - shown as a chip on the
					# row so it's obvious in the sheet which vars share an Inspector section. Only meaningful
					# for exported vars (the compiler emits @export_group for those).
					"group": str(var_attributes.get("group", "")) if is_exported else "",
					"subgroup": str(var_attributes.get("subgroup", "")) if is_exported else ""
				}
			)
		)
	return rows


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
					"variable_index": rows.size()
				}
			)
		)
	return rows


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
		"variable_group": str(options.get("group", "")).strip_edges()
	}
	# No scope pill: it confused users. The "global"/"sheet" pill was already redundant (every sheet/class
	# variable is one), and the "local" pill on event-scoped vars read as noise too - scope is obvious from
	# the row's nesting under its event, and the @export badge carries the meaningful distinction
	# (Inspector-visible vs internal). So a variable row leads straight with its name.
	# READING SHAPE (an opened pack's head): the TYPE leads as a plain-word chip - "number", not
	# "float" - and the `name : Type` code grammar goes away, because a reader is being told what the
	# knob is, not how GDScript declares it. The @export and group chips are dropped by the caller's
	# options: inside a settings bar every knob is exported, and the bar names the group.
	var reading: bool = bool(options.get("reading", false))
	if reading:
		# The type word a READER needs, which is not always the declared one: `const SPEED := 300.0`
		# declares nothing, so the word comes from the value, and a constant says so in the chip
		# itself ("constant number") rather than wearing a separate `const` pill nobody reads as a
		# type.
		var reading_type_word: String = _reading_type_word(
			type_name, default_value, bool(options.get("expression_default", false))
		)
		if is_constant:
			reading_type_word = EventSheetL10n.translate("constant %s") % reading_type_word
		row_data.spans = [
			_make_span(
				reading_type_word,
				SemanticSpan.SpanType.KEYWORD,
				variable_meta.merged({
					"editable": false,
					"badge": true,
					"badge_style": "scope",
					"badge_bg": EventSheetPalette.COLOR_CHIP_BG,
					"badge_fg": EventSheetPalette.COLOR_CHIP_FG
				}, true)
			),
			_make_span(var_name if not var_name.is_empty() else "(unnamed)", SemanticSpan.SpanType.OBJECT, variable_meta.merged({"editable": false}, true))
		]
	else:
		row_data.spans = [
			_make_span(var_name if not var_name.is_empty() else "(unnamed)", SemanticSpan.SpanType.OBJECT, variable_meta.merged({"editable": false}, true)),
			_make_span(":", SemanticSpan.SpanType.OPERATOR, variable_meta.merged({"editable": false}, true)),
			_make_span(type_name if not type_name.is_empty() else "Variant", SemanticSpan.SpanType.VALUE, variable_meta.merged({"editable": false}, true))
		]
	if is_constant and not reading:
		row_data.spans.append(
			_make_span(
				"const",
				SemanticSpan.SpanType.KEYWORD,
				variable_meta.merged(
					{
						"editable": false,
						"badge": true,
						"badge_style": "const",
						"badge_bg": EventSheetPalette.COLOR_CONST_BADGE_BG,
						"badge_fg": EventSheetPalette.COLOR_CONST_BADGE_FG
					},
					true
				)
			)
		)
	# Inspector tag: a variable exposed via @export gets a blue "@export" pill, so it's obvious at a glance
	# while scrolling which sheet variables show up in the Godot Inspector vs. stay internal to the sheet.
	if bool(options.get("exported", false)):
		row_data.spans.append(
			_make_span(
				"@export",
				SemanticSpan.SpanType.KEYWORD,
				variable_meta.merged(
					{
						"editable": false,
						"badge": true,
						"badge_style": "scope",
						"badge_bg": EventSheetPalette.COLOR_GROUP_CHIP_BG,
						"badge_fg": EventSheetPalette.COLOR_GROUP_CHIP_FG
					},
					true
				)
			)
		)
	# Inspector group chip: an exported var with an @export_group shows its section name (e.g. "Combat"),
	# so it reads at a glance which sheet variables share an Inspector group - the "group them in the sheet"
	# half of the @export_group feature (the variable dialog's Inspector-group field sets it).
	var inspector_group: String = str(options.get("group", "")).strip_edges()
	if not inspector_group.is_empty():
		# A subgroup (@export_subgroup) reads as "Group › Subgroup" in the one chip, so deeply-tuned objects
		# show their nested Inspector section at a glance.
		var inspector_subgroup: String = str(options.get("subgroup", "")).strip_edges()
		var chip_text: String = inspector_group if inspector_subgroup.is_empty() else "%s › %s" % [inspector_group, inspector_subgroup]
		row_data.spans.append(
			_make_span(
				chip_text,
				SemanticSpan.SpanType.KEYWORD,
				variable_meta.merged(
					{
						"editable": false,
						"badge": true,
						"badge_style": "scope",
						"badge_bg": EventSheetPalette.COLOR_CAT_CHIP_BG,
						"badge_fg": EventSheetPalette.COLOR_CAT_CHIP_FG,
						# Marks THIS span as the group chip (variable_meta rides on every span of the
						# row, so the rename gesture needs to know it hit the chip, not the name).
						"group_chip": true
					},
					true
				)
			)
		)
	row_data.spans.append(_make_span("=", SemanticSpan.SpanType.OPERATOR, variable_meta.merged({"editable": false}, true)))
	# An expression default (`State.PATROL`, `Vector2.ZERO`, a walrus var's verbatim `100`) is
	# CODE stored as text - quoting it would misread it as a string literal.
	var value_text: String = str(default_value) if bool(options.get("expression_default", false)) else _format_variable_value(default_value)
	if reading:
		value_text = _reading_value_text(value_text)
	row_data.spans.append(
		_make_span(
			value_text,
			SemanticSpan.SpanType.VALUE,
			variable_meta.merged({"editable": false}, true)
		)
	)
	# The knob's own sentence, muted, trailing the value - the `##` doc comment the Inspector shows as
	# its tooltip. A reader of an opened pack should never have to open the .gd to learn what a setting
	# does. Reading shape only; an authored row keeps the tooltip in the variable dialog.
	var variable_description: String = str(options.get("description", "")).strip_edges()
	if not variable_description.is_empty():
		row_data.spans.append(
			_make_span(
				variable_description,
				SemanticSpan.SpanType.COMMENT,
				variable_meta.merged({"editable": false, "text_color": EventSheetPalette.TEXT_MUTED}, true)
			)
		)
	return row_data


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
				return friendly_type_word("int")
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
		# A signal already NAMED on_* must not read "On On ..." - strip the prefix first.
		return "On %s" % trigger_id.trim_prefix("signal:").trim_prefix("on_").capitalize()
	return trigger_id


## Sets the tempo glyph + hue on a trigger-badge meta from the event's trigger_id, and returns the glyph.
## SIGNAL keeps the shipped green ➜ from the event style - the common case stays
## byte-identical; every-tick (⟳) / input (⌨) / once (▶) get their own fill so how OFTEN an event runs
## reads at a distance. Shared by both trigger-badge paths (authored ACECondition + lifted trigger_id).
func _apply_trigger_tempo(meta: Dictionary, event_style: EventSheetEventStyle, trigger_id: String) -> String:
	var tempo: String = TriggerResolver.tempo_class_for(trigger_id)
	meta["tempo"] = tempo
	match tempo:
		TriggerResolver.TEMPO_EVERY_TICK:
			meta["badge_bg"] = EventSheetPalette.COLOR_TEMPO_EVERY_TICK_BG
			meta["badge_fg"] = EventSheetPalette.COLOR_TEMPO_EVERY_TICK_FG
			return "⟳"
		TriggerResolver.TEMPO_INPUT:
			meta["badge_bg"] = EventSheetPalette.COLOR_TEMPO_INPUT_BG
			meta["badge_fg"] = EventSheetPalette.COLOR_TEMPO_INPUT_FG
			return "⌨"
		TriggerResolver.TEMPO_ONCE:
			meta["badge_bg"] = EventSheetPalette.COLOR_TEMPO_ONCE_BG
			meta["badge_fg"] = EventSheetPalette.COLOR_TEMPO_ONCE_FG
			return "▶"
		_:
			meta["badge_bg"] = event_style.trigger_badge_background_color
			meta["badge_fg"] = event_style.trigger_badge_foreground_color
			return "➜"


## The lifecycle handlers whose top-level branches read as the input triggers a player would name.
const INPUT_HANDLER_TRIGGERS: Array[String] = ["OnInput", "OnUnhandledInput", "OnUnhandledKeyInput"]


## The object a trigger row belongs to. A signal-backed trigger belongs to the NODE that emits it -
## "Hurtbox > On Body Entered", the way Construct names the object before the verb - so a connected
## handler reads as its source node rather than as the generic class the vocabulary filed it under.
## Falls back to the ordinary vocabulary label when the trigger names no source (a self-connection,
## a lifecycle handler).
func _handler_object_label(event_row: EventRow) -> String:
	var source_path: String = event_row.trigger_source_path.strip_edges()
	if not source_path.is_empty() and not source_path.begins_with("@") and not source_path.begins_with("autoload:"):
		return source_path.get_file() if source_path.contains("/") else source_path
	return _object_label_for(event_row.trigger_provider_id, event_row.trigger_id)


## M42 - the class picture of the node a SCENE-wired signal comes from. The scene said what class the
## emitter is when the connection was read, so this is a known answer rather than a guess; null for
## every other trigger, which keeps its vocabulary icon.
func _scene_trigger_icon(event_row: EventRow) -> Texture2D:
	if event_row == null or not _viewport.show_object_icons:
		return null
	var source_class: String = str(event_row.get_meta("__scene_source_class", ""))
	if source_class.is_empty():
		return null
	return ACEPickerDialog.editor_icon(source_class)


## The payload chips for a signal-backed trigger: one per handler parameter, named the way the
## handler names it ("body: Node2D" -> "body"). Empty for every trigger that hands nothing over.
func _handler_payload_chips(event_row: EventRow) -> PackedStringArray:
	var chips: PackedStringArray = PackedStringArray()
	var args: String = event_row.trigger_args.strip_edges()
	if args.is_empty() or event_row.trigger_id.is_empty():
		return chips
	for argument: String in args.split(","):
		var name_part: String = argument.strip_edges().split(":")[0].split("=")[0].strip_edges()
		if not name_part.is_empty():
			chips.append(name_part.replace("_", " "))
	return chips


## Builtin categories that are OBJECTS in Construct's grammar, not part of System - a row of theirs
## wears the device name in its object cell (Mouse, Keyboard, Gamepad, Touch).
const INPUT_DEVICE_OBJECTS: Array[String] = ["Mouse", "Keyboard", "Gamepad", "Touch"]

## `event is <class>` -> the Construct module that owns the trigger the branch reads as.
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
## that branch is exactly one Construct trigger: `event is InputEventMouseMotion` is Mouse > On
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
		else:
			continue
		atom["used"] = true
	var sentence: String = _input_branch_sentence(event_class, edge, button, key)
	if sentence.is_empty():
		return {}
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
func _input_branch_sentence(event_class: String, edge: int, button: String, key: String) -> String:
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
			return EventSheetL10n.translate("On button %s pressed" if edge > 0 else "On button %s released") % button.trim_prefix("JOY_BUTTON_").capitalize()
	return ""


## "MOUSE_BUTTON_LEFT" -> "left" (the word Construct puts in the sentence).
func _mouse_button_word(button: String) -> String:
	return button.trim_prefix("MOUSE_BUTTON_").to_lower().replace("_", " ")


## "KEY_ESCAPE" -> "Escape". A bare expression (a variable holding a keycode) reads verbatim.
func _key_word(key: String) -> String:
	if not key.begins_with("KEY_"):
		return key
	return key.trim_prefix("KEY_").capitalize()


## Construct's own words for the pieces of an input event a row reads out: the mouse delta is
## `mouse's ΔX` / `ΔY`, and the static-typing casts around `event` are not part of any sentence.
## Applied to every row's text - `event.relative` and an `as InputEvent…` cast only ever appear
## inside an input handler, so there is nothing else for it to touch.
func _humanized_input_event_text(text: String) -> String:
	if not text.contains("event"):
		return text
	var humanized: String = _strip_event_casts(text)
	humanized = humanized.replace("event.relative.x", EventSheetL10n.translate("mouse's ΔX"))
	humanized = humanized.replace("event.relative.y", EventSheetL10n.translate("mouse's ΔY"))
	return humanized.replace("event.relative", EventSheetL10n.translate("mouse's Δ"))


## `(event as InputEventKey).pressed` -> `event.pressed`. A cast is how GDScript keeps its static
## type checker happy; it says nothing a reader needs, so it never reaches a sentence.
func _strip_event_casts(text: String) -> String:
	var cast_regex: RegEx = RegEx.create_from_string("\\(\\s*([A-Za-z_][A-Za-z0-9_]*)\\s+as\\s+InputEvent[A-Za-z]*\\s*\\)")
	return cast_regex.sub(text, "$1", true)


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


## `slice_from` / `slice_to` (half-open, -1 = to the end) and `hide_conditions` exist for M23: a
## statement carrying a ternary splits its event into a row of the actions before it, the branch rows,
## and a continuation row - three views of ONE unchanged EventRow, each drawing its own slice.
func _build_event_spans(event_row: EventRow, in_verb_body: bool = false, slice_from: int = 0,
		slice_to: int = -1, hide_conditions: bool = false, slice_is_tail: bool = false) -> Array[SemanticSpan]:
	var spans: Array[SemanticSpan] = []
	if slice_from > 0 or slice_to >= 0 or hide_conditions:
		return _slice_event_spans(_build_event_spans(event_row, in_verb_body), event_row,
			slice_from, slice_to, hide_conditions, slice_is_tail)
	var condition_line_index: int = 0
	var action_line_index: int = 0
	var inline_trigger_condition_index: int = _find_inline_trigger_condition_index(event_row)
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var condition_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	var action_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_action_style())
	# An input handler's branch reads as the trigger it is - one Construct trigger row per branch,
	# in place of both the Else chip (a branch is its own trigger, not a continuation) and the
	# generic "On unhandled input event" cell. Pure lens; the emitted handler is untouched.
	var input_reading: Dictionary = _input_branch_reading(event_row)
	var input_consumed: Dictionary = input_reading.get("consumed", {})
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
		# The event-sheet Else reads as a CONDITION, exactly like Construct's System Else: a "System | Else"
		# chip heading the condition lane (an ELIF is the Else chip with its own conditions beneath). The
		# row's trigger stays structural (it is what chains the block into the same handler) but is NOT
		# re-drawn - a C3 Else block never repeats its trigger. Canvas-drawn, so translated at build time.
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
	elif input_reading.is_empty() and event_row.else_mode == EventRow.ElseMode.NONE and not event_row.trigger_id.is_empty():
		var trigger_id_badge_meta: Dictionary = _viewport.BADGE_TRIGGER_METADATA.duplicate(true)
		# Same tempo badge on the lifted / lifecycle path (trigger_id with no authored ACECondition) -
		# this is where On Physics Process etc. render, so the ⟳ hot-path glyph lands here too.
		var trigger_id_glyph: String = _apply_trigger_tempo(trigger_id_badge_meta, event_style, event_row.trigger_id)
		trigger_id_badge_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)
		trigger_id_badge_meta["line_index"] = condition_line_index
		trigger_id_badge_meta["badge_style"] = "trigger"
		spans.append(_make_span(trigger_id_glyph, SemanticSpan.SpanType.KEYWORD, trigger_id_badge_meta))
		spans.append(
			_make_span(
				# ── M27 lens hook (tick triggers) ──────────────────────────────────────────────
				# Construct's words for the two ticks; every other trigger keeps its own name.
				EventSheetViewportReadingRows.tick_trigger_words(
					event_row.trigger_id,
					_trigger_display_text(event_row.trigger_provider_id, event_row.trigger_id)
				),
				SemanticSpan.SpanType.CONDITION,
				{
					"lane": "condition",
					"kind": "trigger",
					"ace_index": 0,
					"chip": true,
					"line_index": condition_line_index,
					"object_label": _handler_object_label(event_row),
					# M42 - a handler the SCENE wired knows exactly which node emits and what class it
					# is, so that node's own picture leads the row instead of the generic trigger icon.
					"object_icon": _scene_trigger_icon(event_row) if _scene_trigger_icon(event_row) != null \
						else _object_icon_for(event_row.trigger_provider_id, event_row.trigger_id)
				}.merged(condition_style_meta, true)
			)
		)
		# A signal handler's PARAMETERS are the trigger's payload - the body that entered, the item
		# that was picked up. Construct shows them as chips beside the trigger, so a reader knows
		# what the event hands them without opening the code.
		var handler_payload: PackedStringArray = _handler_payload_chips(event_row)
		for payload_index in range(handler_payload.size()):
			spans.append(_trigger_payload_span(handler_payload[payload_index], payload_index, condition_line_index))
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
	if not event_row.conditions.is_empty():
		var displayed_condition_indices: Array[int] = []
		for condition_index in range(event_row.conditions.size()):
			if condition_index == inline_trigger_condition_index or input_consumed.has(condition_index):
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
			spans.append(
				_make_span(
					_format_condition_descriptor(condition),
					SemanticSpan.SpanType.CONDITION,
					{
						"lane": "condition",
						"kind": "condition",
						"ace_index": condition_index,
						"ace_enabled": condition.enabled,
						"chip": true,
						"line_index": line_index,
						"object_label": _object_label_or_pending(condition.provider_id, condition.ace_id),
						"object_icon": _object_icon_for(condition.provider_id, condition.ace_id),
						"swatch_color": _first_color_in_params(condition)
					}.merged(condition_style_meta, true)
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
		# ── M33 lens hook (loop rows) ──────────────────────────────────────────────────────────
		# One call: the loop's Construct words, and the object a For-each-child loop belongs to.
		# A filtered or limited pick says more than the loop words can carry, so it keeps its own text.
		var loop_reading: Dictionary = {}
		if pick.predicate_expression.strip_edges().is_empty() and pick.pick_first_n <= 0:
			loop_reading = EventSheetViewportReadingRows.loop_words(
				pick.collection_kind, pick.iterator_name, _pick_collection_text(pick))
		var loop_object: String = str(loop_reading.get("object", ""))
		spans.append(
			_make_span(
				str(loop_reading.get("text", "")) if not loop_reading.is_empty() else _format_pick_filter(pick),
				SemanticSpan.SpanType.CONDITION,
				{
					"lane": "condition",
					"kind": "pick_filter",
					"pick_index": pick_index,
					"chip": true,
					"line_index": condition_line_index,
					# Loops are System's, like in Construct - and the label puts the line in the
					# shared object sub-lane, so its text aligns with the cells above it.
					"object_label": loop_object if not loop_object.is_empty() else _object_label_for("Core", ""),
					"object_icon": _reading_class_icon_for(loop_object)
				}.merged(condition_style_meta, true)
			)
		)
		condition_line_index += 1
	# In a READ-ONLY preview a body-only row leaves its left cell blank, exactly as Construct draws one:
	# "Always" is a placeholder that invites a condition, and a view that accepts none must not invite.
	var always_placeholder_suppressed: bool = in_verb_body and _scaffolding_suppressed()
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
	var add_condition_color: Color = condition_style_meta.get("text_color", EventSheetPalette.COLOR_CONDITION)
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
		# M39 - the instantiate + add_child (+ first position) run is Construct's single Create object.
		# Worked out once for the whole lane, because a group is recognised by what FOLLOWS its lead.
		var create_groups: Dictionary = _create_object_groups(event_row.actions)
		for action_index in range(event_row.actions.size()):
			var action_resource: Resource = event_row.actions[action_index]
			# A line the Create object row above already said. Skipped without advancing the line index,
			# which is what turns three lines into one row.
			if bool(create_groups.get("consumed", {}).get(action_index, false)):
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
					"create_object_indices": create.get("indices", [])
				}.merged(action_style_meta, true)))
				action_line_index += 1
				continue
			# M29 - whichever shape the line took (a Call Method row or a verbatim block), the line
			# that wires a lambda to a signal reads as a muted NOTE: the work it describes is drawn
			# below it as the trigger event it is. Nothing is hidden - the note names the object and
			# the signal, and double-click still opens the exact GDScript.
			var connect_parts: Dictionary = connect_lambda_parts(connect_statement_of(action_resource))
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
					"text_color": EventSheetPalette.TEXT_MUTED
				}.merged(action_style_meta, false)))
				action_line_index += 1
				continue
			if action_resource is ACEAction:
				# A Local Variable row is a DECLARATION, not a step - the same row shape a hand-written
				# `var` line gets, so a local reads alike whether it was picked or typed.
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
								"text_color": EventSheetPalette.TEXT_MUTED if structured_match else event_style.value_highlight_color
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
							"text_color": EventSheetPalette.TEXT_MUTED
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
					decl_head_meta.duplicate().merged({"natural_width": true, "text_color": EventSheetPalette.TEXT_PRIMARY}, true).merged(action_style_meta, false)))
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
								"text_color": _viewport._get_event_style().comment_text_color if inline_is_note else action_style_meta.get("text_color", EventSheetPalette.TEXT_PRIMARY),
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
				for comment_line_index in range(action_comment_lines.size()):
					spans.append(
						_make_span(
						action_comment_lines[comment_line_index] if _viewport.is_reading_mode() else "# " + action_comment_lines[comment_line_index],
							SemanticSpan.SpanType.COMMENT,
							{
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
							}.merged(action_style_meta, false)
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
	var add_action_color: Color = action_style_meta.get("text_color", EventSheetPalette.COLOR_ACTION)
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
	return spans


## Cheaply computes how many stacked lines an event row occupies, mirroring the
## line-index accounting in _build_event_spans() WITHOUT building any spans. This lets
## the whole sheet be measured (row heights/metrics) without the expensive span pass.
## Invariant (covered by event_lazy_spans_test): equals max span line_index + 1.
func _count_event_lines(event_row: EventRow) -> int:
	if event_row == null:
		return 1
	# Condition lane. An else row leads with its "System | Else" condition chip INSTEAD of a trigger line
	# (a C3 Else block never repeats its trigger) - the span pass renders exactly one of the two, so the
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
	elif has_trigger and event_row.else_mode == EventRow.ElseMode.NONE:
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
	for action_resource in event_row.actions:
		if action_resource is ACEAction:
			action_count += 1
		elif action_resource is RawCodeRow:
			# M29: a connected lambda collapses to ONE muted note line however many lines it spans,
			# because its body is drawn below as the trigger event it reads as.
			var raw_code: String = (action_resource as RawCodeRow).code
			if not connect_lambda_parts(connect_statement_of(action_resource)).is_empty():
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


## M16 inside a `Set return value` cell: when the value is a call to one of THIS sheet's own
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


# ── M29: a lambda connected to a signal reads as the trigger event it is ────────────────────────


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
		if lines[lines.size() - 1].strip_edges() != ")":
			return {}
		for line_index: int in range(1, lines.size() - 1):
			var body_line: String = lines[line_index]
			body_lines.append(body_line.substr(1) if body_line.begins_with("\t") else body_line.strip_edges())
		if body_lines.is_empty():
			return {}
	var args: PackedStringArray = PackedStringArray()
	for parameter: String in params_text.split(","):
		var bare: String = parameter.strip_edges()
		if bare.is_empty():
			continue
		var type_at: int = bare.find(":")
		args.append((bare.substr(0, type_at) if type_at > 0 else bare).strip_edges())
	# ── M41 lens hook ──────────────────────────────────────────────────────────────────────────
	# A collision signal reads as Construct's own trigger, exactly as a declared handler's does.
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
		# The body reads through the very same lift a declared handler's body goes through, so a
		# statement says the same thing whether it was written in a func or handed to connect.
		for body_event: Variant in EventSheetACELifter.lift_body_rows(
				parts.get("body", PackedStringArray()), _sheet_object_variable_names()):
			if not (body_event is EventRow):
				continue
			var body_row: EventRowData = _build_event_row(body_event as EventRow, indent + 1)
			_mark_connect_reading(body_row, event_row, anchor, action_index)
			trigger_row.children.append(body_row)
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


# ── M23: a ternary reads as a sub-event pair, never a condition in an action cell ───────────────


## Rewrites a list of sibling rows so a statement carrying a ternary reads the way a Construct sheet
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
		# M36 runs first: it REPLACES a loop row with the event its body reads as, and that event may
		# itself carry a ternary the pass below still has to see.
		var picked: Array[EventRowData] = _expand_picking_row(row)
		if not picked.is_empty():
			out.append_array(picked)
			continue
		out.append_array(_expand_ternary_row(row))
	return out


# ── M36: a loop over a group with one `if` inside is Construct's picking, and reads as one event ──
#
# This is Construct's whole model: a condition on an object PICKS the instances, and the actions run
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
	# Repeat and While are counts and tests, not collections of instances - Construct spells those
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


## M36 - the picked object and its note, written onto the first condition line once its spans exist.
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
			# Construct's cell is just the property. Only the loop's OWN name is dropped.
			span.text = owned
			span.metadata.erase("bbcode_segments")
			span.metadata.erase("value_ranges")
		if not row_data.picking_note.is_empty():
			# The note is a receipt, not part of the test: muted, so the eye lands on the condition.
			# Written as segments because the styled runs behind the old text were measured against
			# offsets the note has just moved, and re-deriving those costs a re-read of the whole cell.
			span.metadata["bbcode_segments"] = [
				{"text": "%s " % row_data.picking_note, "color": EventSheetPalette.TEXT_MUTED, "bold": false, "italic": false},
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
## actions after a branch, whose conditions the row above already drew, and which a C3 sheet never
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
	# both what Construct draws and what keeps the head's conditions gating them.
	var head_blank: bool = _slice_row_is_blank(head) and (hide_conditions or row.children.is_empty())
	var branch_indent: int = indent if head_blank else indent + 1
	var branch_rows: Array[EventRowData] = _build_ternary_branch_rows(
		row, action_index, found, branch_indent, str(action_index))
	if branch_rows.is_empty():
		return [row] if (not hide_conditions and from_index == 0) else [head]
	var tail_rows: Array[EventRowData] = []
	if not branch_is_last:
		# Conditions, once hidden, stay hidden - a C3 sheet never repeats them further down the same event.
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
				return {"index": action_index, "kind": "code", "param": "", "text": raw.code}
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
			return {"index": action_index, "kind": "param", "param": str(param_key), "text": value}
	return {}


## The cheap "could this possibly branch" screen in front of the real grammar walk: a ternary is
## spelled `A if C else B`, so text without both words cannot be one. Pure substring work, run once
## per action per rebuild on every sheet in the editor. Deliberately looser than the grammar (it does
## not demand a space after `else`), because a false POSITIVE only costs the parse this saves, while a
## false negative would silently stop a real branch from reading as a pair.
func _may_branch(text: String) -> bool:
	return text.contains(" if ") and text.contains("else")


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
## Every arm AFTER the first is an else-if, and Construct spells an else-if as an Else event WITH a
## condition under it - two stacked condition cells on the one row. Drawing the arm's test alone would
## read as a sibling condition, i.e. as though both arms could fire.
func _build_ternary_branch_rows(row: EventRowData, action_index: int, found: Dictionary, indent: int,
		uid_path: String) -> Array[EventRowData]:
	var branches: Array = _ternary_arms(found)
	if branches.is_empty():
		return []
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
## that test on the same row, which is how Construct draws an else-if: one Else event carrying a
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


## M24 - the branch test as CONDITION LINES, never as one cell spelling `and`. Construct has no word
## for "and": each conjunct is a condition of the one event, stacked, and an `or` is the OR block. This
## is the same shape the lifted `if a and b:` already draws, applied to the readings the grammar
## invents, so a test says the same thing however the row got here. Precedence follows GDScript, where
## `or` binds loosest: a top-level ` or ` splits FIRST into OR-marked lines, and only a pure-AND test
## splits on ` and `. A mixed `a and (b or c)` therefore stacks `a` and keeps the parenthesised group
## whole on its own line - a line cannot hold a nested OR block, and inventing one would say something
## the source does not.
func _append_conjunct_condition_lines(branch_row: EventRowData, condition_text: String,
		first_line: int, condition_style_meta: Dictionary) -> void:
	var terms: PackedStringArray = EventSheetSentence.split_top_level(condition_text, " or ")
	var or_block: bool = terms.size() > 1
	if not or_block:
		terms = EventSheetSentence.split_top_level(condition_text, " and ")
	var line_index: int = first_line
	for term: String in terms:
		if term.strip_edges().is_empty():
			continue
		if or_block:
			var or_meta: Dictionary = _viewport.BADGE_OR_METADATA.duplicate(true)
			or_meta["badge_bg"] = condition_style_meta.get("badge_bg", _viewport.BADGE_OR_METADATA.get("badge_bg"))
			or_meta["badge_fg"] = condition_style_meta.get("badge_fg", _viewport.BADGE_OR_METADATA.get("badge_fg"))
			or_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)
			or_meta["condition_index"] = -1
			or_meta["line_index"] = line_index
			or_meta["badge_style"] = "or"
			branch_row.spans.append(_make_span("OR", SemanticSpan.SpanType.KEYWORD, or_meta))
		var reading: Dictionary = EventSheetSentence.condition_pieces(term, sentence_context())
		var pieces: Array = EventSheetViewportLenses.apply_to_pieces(
			reading.get("pieces", []) as Array, _viewport.humanize_names_enabled(), _export_knob_names())
		var condition_cell: Dictionary = _tone_segments(pieces)
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
			"object_label": str(reading.get("object", "")),
			"bbcode_segments": condition_cell.get("segments", [])
		}.merged(condition_style_meta, true)))
		line_index += 1
	branch_row.line_count = maxi(branch_row.line_count, line_index)


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
				tone_color = EventSheetPalette.TEXT_PRIMARY
				tone_bold = true
			"value":
				tone_color = _viewport._get_event_style().value_highlight_color
			"object":
				tone_color = EventSheetPalette.COLOR_OBJECT
		segments.append({"text": piece_text, "color": tone_color, "bold": tone_bold, "italic": false})
	return {"text": text, "segments": segments}


## One slice of an event's finished spans (M23). Filtering the WHOLE build - rather than teaching the
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
	if row_data.source_resource is EventRow:
		# Spans are built LAZILY, long after the walk that knew which published verb owns this row - so
		# the row carries the answer and puts it back for the duration of the build.
		var outer_kind: int = _verb_kind_override
		_verb_kind_override = row_data.verb_kind
		row_data.spans = _build_event_spans(row_data.source_resource as EventRow, row_data.in_verb_body,
			row_data.action_slice_from, row_data.action_slice_to, row_data.conditions_hidden,
			row_data.action_slice_tail)
		_verb_kind_override = outer_kind
		if not row_data.picking_object.is_empty():
			_apply_picking_note(row_data)


func _append_condition_prefix_spans(
	spans: Array[SemanticSpan],
	event_row: EventRow,
	condition: ACECondition,
	condition_index: int,
	line_index: int,
	_display_index: int,
	displayed_condition_count: int
) -> void:
	if event_row == null:
		return
	var condition_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	# Keep the primary badge column stable for trigger/invert/OR by rendering
	# negation first. When a line has both badges, ✕ is placed in column 1
	# and OR follows in column 2.
	if condition.negated or _condition_reads_negated(condition):
		spans.append(_negated_badge_span(condition_style_meta, line_index, condition_index))
	if (
		event_row.condition_mode == EventRow.ConditionMode.OR
		and displayed_condition_count > 1
	):
		var or_meta: Dictionary = _viewport.BADGE_OR_METADATA.duplicate(true)
		or_meta["badge_bg"] = condition_style_meta.get("badge_bg", _viewport.BADGE_OR_METADATA.get("badge_bg"))
		or_meta["badge_fg"] = condition_style_meta.get("badge_fg", _viewport.BADGE_OR_METADATA.get("badge_fg"))
		or_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)
		or_meta["condition_index"] = condition_index
		or_meta["line_index"] = line_index
		or_meta["badge_style"] = "or"
		spans.append(_make_span("OR", SemanticSpan.SpanType.KEYWORD, or_meta))


## M12 - the inverted-condition mark: a bare red ✕ in the badge column, no circle behind it
## (themable via EventSheetEventStyle.invert_marker_color). ONE factory, because the mark now has
## two producers - an ACE condition with its `negated` flag, and a lifted `if not <cond>:` whose
## sentence dropped the word - and they must draw the identical glyph or the sheet teaches two
## symbols for one idea.
func _negated_badge_span(condition_style_meta: Dictionary, line_index: int, condition_index: int = -1) -> SemanticSpan:
	var negated_meta: Dictionary = _viewport.BADGE_NEGATED_METADATA.duplicate(true)
	negated_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)
	negated_meta["condition_index"] = condition_index
	negated_meta["line_index"] = line_index
	negated_meta["badge_style"] = "negated"
	negated_meta["badge_bg"] = Color(0.0, 0.0, 0.0, 0.0)
	negated_meta["badge_fg"] = _viewport._get_event_style().invert_marker_color
	return _make_span("✕", SemanticSpan.SpanType.KEYWORD, negated_meta)


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
	var object_label: String = str(metadata.get("object_label", ""))
	if not object_label.is_empty():
		# Fixed object column (C3 sub-lane): the label occupies exactly the column width;
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
	if bool(metadata.get("badge", false)):
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
## the loop's own text and its M33 reading can never disagree about what the loop walks.
func _pick_collection_text(pick: PickFilter) -> String:
	var collection: String = pick.collection_value.strip_edges()
	return collection if not collection.is_empty() else pick.source_expression.strip_edges()


func _format_pick_filter(pick: PickFilter) -> String:
	var iterator: String = pick.iterator_name.strip_edges()
	if iterator.is_empty():
		iterator = "item"
	var collection: String = pick.collection_value.strip_edges()
	if collection.is_empty():
		collection = pick.source_expression.strip_edges()
	var source_text: String = collection
	match pick.collection_kind:
		PickFilter.CollectionKind.GROUP:
			source_text = "group \"%s\"" % collection
		PickFilter.CollectionKind.CHILDREN:
			source_text = "children"
		PickFilter.CollectionKind.REPEAT:
			return "Repeat %s times" % collection
		PickFilter.CollectionKind.WHILE:
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
		# Construct treats the input devices as OBJECTS, not as part of System: a captured-cursor
		# check reads "Mouse > mouse is captured", a key test "Keyboard > Key Space is down". The
		# builtin vocabulary already files these under exactly those categories, so the label is
		# read off the descriptor rather than kept as a second list to maintain.
		var input_descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
		if input_descriptor != null and INPUT_DEVICE_OBJECTS.has(input_descriptor.category):
			return input_descriptor.category
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
	# ── M16 lens hook (LIFTED call rows) ──────────────────────────────────────────────────────
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
	# ── M9 / M10 / M12 lens hook (LIFTED rows) ────────────────────────────────────────────────
	# The sentence-layer hook further down only covers code that stayed raw; a condition that
	# LIFTED into a real ACE gets its reading here, at the one place its display text is built.
	# M12 strips a leading NOT because the ✕ in the badge column says it instead (see
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
func _is_state_header_condition(condition: ACECondition) -> bool:
	if condition == null or condition.ace_id != "method:is_in_state":
		return false
	var params_dict: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
	return not str(params_dict.get("state_name", "")).strip_edges().is_empty()


func _format_condition_descriptor_base(condition: ACECondition) -> String:
	var params_dict: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
	# An Is In State condition reads as a state header - "State: patrol", with the ◆ diamond
	# rendered as a BADGE by the span builder (the same column trigger icons use, never inline
	# text). Keyed on the method SHAPE (an is_in_state verb carrying a state_name param), not
	# on any one pack's name, so every state-machine-like behavior gets the reading for free.
	# The value shows verbatim minus quotes (state strings are case-sensitive - no prettifying).
	# Display-only: the stored row and the compiled call are untouched.
	# Same shared grammar the action lane uses: a condition whose shape Construct already has a
	# sentence for reads that sentence whether it was picked or typed. Cleared first for the same
	# reason the action lane clears: a text-only reading must not leave a label behind.
	_pending_object_label = ""
	_pending_grammar_segments = []
	var grammar: Dictionary = grammar_condition_sentence(condition)
	if not grammar.is_empty():
		_pending_object_label = str(grammar.get("object", ""))
		_pending_grammar_segments = grammar.get("segments", []) as Array
		return _joined_segments(grammar)
	if _is_state_header_condition(condition):
		var state_value: String = str(params_dict.get("state_name", "")).strip_edges()
		if state_value.length() >= 2 and state_value.begins_with("\"") and state_value.ends_with("\""):
			state_value = state_value.substr(1, state_value.length() - 2)
		return "%s: %s" % [EventSheetL10n.translate("State"), state_value]
	var generated_definition: ACEDefinition = _viewport._find_definition(condition.provider_id, condition.ace_id)
	var descriptor: ACEDescriptor = null if generated_definition != null else ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
	if generated_definition == null and descriptor == null:
		# Same registry-free reading the ACTION path gets: a reflected verb (method:<name>) must
		# still read as words when the registry has no definition to offer right now. Without
		# this a pack condition fell back to the raw id and the cell showed
		# "method:can_afford_entry" beside actions that read "Buy" - the id leaking into the one
		# lane a beginner reads first.
		return _reflected_member_sentence(condition.ace_id, params_dict)
	return _format_display_translated(generated_definition, descriptor, params_dict)


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
	# M9 / M10 lens hook for LIFTED action rows - the twin of the condition hook above.
	# Input-event words FIRST (casts stripped, `event.relative.x` -> mouse's ΔX), the name lens
	# after: the lens sees `(event as InputEventMouseMotion).relative.x` as a chain around a
	# cast and the cast stripper then hollowed the middle out ("eventrelative X").
	var base_text: String = _reading_sentence(_humanized_input_event_text(_format_action_descriptor_base(action)))
	# Awaiting actions wear an hourglass (the GDevelop async-action cue): everything after
	# this row in the SAME event waits for it, so the suspension point should be visible.
	if action_awaits(action):
		base_text = "⏳ " + base_text
	var ace_note: String = str(action.comment).strip_edges()
	if not ace_note.is_empty():
		return "%s   ⊳ %s" % [base_text, ace_note]
	return base_text


## Whether an action suspends the handler: the awaited-call flags, an `await` anywhere in
## its baked template, or a builtin coroutine id (a lifted builtin action carries only its
## ace_id - the template re-resolves at compile time).
static func action_awaits(action: ACEAction) -> bool:
	if action == null:
		return false
	if action.is_awaited or action.await_call:
		return true
	if ["Wait", "AwaitSignal", "AwaitNextFrame", "AwaitIfOverBudget"].has(action.ace_id):
		return true
	return action.codegen_template.contains("await ")


func _format_action_descriptor_base(action: ACEAction) -> String:
	# A row whose SHAPE has a settled Construct sentence reads through the shared grammar, so the
	# picked row and the hand-written line beside it say the same words. Both one-shots are cleared
	# FIRST: a formatter also runs for text-only readings (a match case's summary line), and a value
	# left behind there would land on whatever span is built next.
	_pending_object_label = ""
	_pending_grammar_segments = []
	var grammar: Dictionary = grammar_action_sentence(action)
	if not grammar.is_empty():
		_pending_object_label = str(grammar.get("object", ""))
		_pending_grammar_segments = grammar.get("segments", []) as Array
		return _joined_segments(grammar)
	# Function calls read as the named verb (under the "ƒ" chip), not the raw "Call name()" template.
	if _is_function_call_action(action):
		var verb: String = _function_call_label(action)
		if not verb.is_empty():
			return verb
	var params_dict: Dictionary = action.params if not action.params.is_empty() else action.parameters
	var generated_definition: ACEDefinition = _viewport._find_definition(action.provider_id, action.ace_id)
	var descriptor: ACEDescriptor = null if generated_definition != null else ACERegistry.find_descriptor(action.provider_id, action.ace_id)
	if generated_definition == null and descriptor == null:
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
# to bold the substituted parameters (the C3 emphasis) - but only after re-finding the recorded text
# inside the span's final text, so a formatter suffix (an ACE note) or prefix (the await hourglass)
# shifts the ranges instead of mis-bolding, and any other post-processing degrades to no emphasis.
var _pending_param_ranges: Dictionary = {}


## Appends the flowing spans that make a single-statement raw row read as a Construct-3 sentence
## ("Add 1 to score") or as an Object / Verb / parameters chip run, and returns true when it did.
## The caller then skips its per-line default for that action.
##
## Purely a VIEW: the RawCodeRow is unchanged, so emission and the byte round-trip cannot move. The
## spans carry `raw_action` and `code_cell: false` so selection, the row context menu, and
## double-click-opens-the-code-editor behave exactly as they do for any other raw row. Only the LAST
## span omits `natural_width`, so it stretches to close the action cell the way the Declare header
## does - without that, the cell background would stop mid-row.
func _append_sentence_spans(spans: Array, raw: RawCodeRow, action_index: int, line_index: int, action_style_meta: Dictionary) -> bool:
	var pieces: Array = []
	var indent: int = 0
	var object_label: String = ""
	var sentence: Dictionary = statement_sentence(raw.code, sentence_context())
	if EventSheetSentence.leading_word(raw.code.strip_edges()) == "return":
		sentence = _named_return_sentence(sentence, raw.code.strip_edges().substr(6))
	# A `var` line is a DECLARATION, not a step: it reads as Construct's own local-variable row - a type
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
		}, action_style_meta)
		return true
	if not sentence.is_empty():
		indent = int(sentence.get("indent", 0))
		object_label = str(sentence.get("object", ""))
		for segment: Variant in (sentence.get("segments", []) as Array):
			var part: Dictionary = segment
			pieces.append([str(part.get("text", "")), str(part.get("tone", "plain"))])
	else:
		var call_info: Dictionary = call_parts(raw.code)
		if call_info.is_empty():
			return false
		indent = int(call_info.get("indent", 0))
		var args: PackedStringArray = call_info.get("args", PackedStringArray())
		# ── M16 lens hook ──────────────────────────────────────────────────────────────────────
		# Applied AFTER the sentence layer has resolved this row as a call: when the callee is one
		# of THIS sheet's functions, the row reads Construct's way ("Functions ▸ Call Add Look",
		# one argument per parameter name) instead of as a bare method call. A callee the sheet
		# does not know falls straight through to the ordinary reading below - a call to something
		# unknown must never be dressed up as a project function.
		var call_pieces: Array = _reading_call_pieces(raw.code, args)
		if not call_pieces.is_empty():
			pieces = call_pieces
		else:
			# ── M25 / M26 lens hook ───────────────────────────────────────────────────────────
			# Any other call reads Object ▸ Verb chips - the verb in words, the arguments named by
			# the engine's own parameter names when the object's class is known, and no
			# parentheses anywhere. Only a line that is not one call at all keeps the old form.
			var generic: Dictionary = EventSheetViewportReadingRows.generic_call_pieces(
				raw.code, sentence_context(), _reading_class_map())
			if not generic.is_empty():
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
	# ── M9 / M10 lens hook ─────────────────────────────────────────────────────────────────────
	# Applied to the sentence layer's OUTPUT, never inside it: the sentence layer decides what a
	# statement SAYS, this only decides how the names in it are SPELLED. Only "name" and "value"
	# pieces are touched (identifiers the builder already resolved), never a string literal and
	# never a connective word, and the row's hover still shows the exact GDScript.
	pieces = EventSheetViewportLenses.apply_to_pieces(pieces, _viewport.humanize_names_enabled(), _export_knob_names())
	# ── M13 / M20 lens hook ────────────────────────────────────────────────────────────────────
	# The object this statement acts on draws its Godot class icon, the way an event sheet shows
	# an object's picture in every cell it appears in. Resolved from the RAW pieces (before the
	# lens above respelled them) so the lookup keys stay the names the file actually uses.
	var sentence_icon: Texture2D = _reading_sentence_icon(sentence, raw.code)
	# ONE span, tinted by BBCode segments, so the sentence reads as a single continuous cell -
	# separate flowing spans each painted their own chip and the row read as a strip of boxes,
	# the exact fragmented look the entry rows were already reworked away from. Four spaces per
	# source tab keeps deeper statements visually nested like the code they came from.
	var sentence_text: String = "    ".repeat(indent)
	# Segments are built DIRECTLY, never round-tripped through the BBCode parser: code text is
	# full of square brackets (`wave[1]`, `[]`), and a parser would eat them as tags - the first
	# render lost every array value exactly that way.
	var sentence_segments: Array[Dictionary] = []
	if indent > 0:
		sentence_segments.append({"text": "    ".repeat(indent), "color": null, "bold": false, "italic": false})
	for piece: Array in pieces:
		var text: String = str(piece[0])
		sentence_text += text
		var tone_color: Variant = null
		var tone_bold: bool = false
		match str(piece[1]):
			"name":
				tone_color = EventSheetPalette.TEXT_PRIMARY
				tone_bold = true
			"value":
				tone_color = _viewport._get_event_style().value_highlight_color
			"object":
				tone_color = EventSheetPalette.COLOR_OBJECT
		sentence_segments.append({"text": text, "color": tone_color, "bold": tone_bold, "italic": false})
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
		"bbcode_segments": sentence_segments,
		"object_icon": sentence_icon
	}.merged(action_style_meta, false)))
	return true


## Construct's local-variable row: a type-word chip, the name, and the starting value. Shared by the
## hand-written `var` line and by the Local Variable ACE, so a local reads the same however it got
## there. `base_meta` carries the row identity (which lane, which action index) and `style_meta` the
## cell chrome; the LAST span omits natural_width so the cell background closes the row.
func append_local_declaration_spans(spans: Array, declaration: Dictionary, base_meta: Dictionary, style_meta: Dictionary) -> void:
	var indent_text: String = "    ".repeat(int(declaration.get("indent", 0)))
	var chip_word: String = "%s %s" % [
		EventSheetL10n.translate("Local constant") if bool(declaration.get("is_constant", false)) else EventSheetL10n.translate("Local"),
		str(declaration.get("type_word", ""))
	]
	var chip_meta: Dictionary = base_meta.duplicate()
	chip_meta["chip"] = true
	chip_meta["natural_width"] = true
	chip_meta["text_color"] = _viewport._get_event_style().object_label_color
	spans.append(_make_span(indent_text + chip_word, SemanticSpan.SpanType.VALUE, chip_meta.merged(style_meta, false)))
	var name_meta: Dictionary = base_meta.duplicate()
	name_meta["chip"] = true
	name_meta["natural_width"] = true
	name_meta["text_color"] = EventSheetPalette.TEXT_PRIMARY
	spans.append(_make_span(str(declaration.get("name", "")), SemanticSpan.SpanType.VALUE, name_meta.merged(style_meta, false)))
	var value_meta: Dictionary = base_meta.duplicate()
	value_meta["chip"] = true
	value_meta["text_color"] = _viewport._get_event_style().value_highlight_color
	spans.append(_make_span("= %s" % str(declaration.get("value", "")), SemanticSpan.SpanType.VALUE, value_meta.merged(style_meta, false)))


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


## The shared-grammar reading of an ACE ACTION whose shape a hand-written line can also have, or {}
## when this row has no such twin. The point is symmetry: `Destroy`, `Signal On Jumped`, `Set hp to 0`
## must be one sentence, whether the row came out of the picker or out of the user's own .gd file.
func grammar_action_sentence(action: ACEAction) -> Dictionary:
	if action == null or not (action.provider_id.is_empty() or action.provider_id == "Core"):
		return {}
	var params_dict: Dictionary = action.params if not action.params.is_empty() else action.parameters
	var context: Dictionary = sentence_context()
	match action.ace_id:
		"SetVar":
			return EventSheetSentence.statement("%s = %s" % [
				str(params_dict.get("var_name", "")), str(params_dict.get("value", ""))], context)
		"EmitSignal":
			return EventSheetSentence.signal_sentence(
				str(params_dict.get("signal_name", "")), str(params_dict.get("args", "")), context)
		"QueueFree":
			return EventSheetSentence.statement("queue_free()", context)
		"CallMethod":
			# A generic call reads as one of the settled sentences when it has one
			# (`call_deferred("queue_free")` is a destroy) - and otherwise as M26's Object ▸ Verb
			# chips, which is exactly what the same call typed by hand now reads.
			var call_code: String = "%s.%s(%s)" % [
				str(params_dict.get("target", "")), str(params_dict.get("method", "")),
				str(params_dict.get("args", ""))]
			var settled: Dictionary = EventSheetSentence.statement(call_code, context)
			if not settled.is_empty():
				return settled
			var generic_call: Dictionary = EventSheetViewportReadingRows.generic_call_pieces(
				call_code, context, _reading_class_map())
			if generic_call.is_empty():
				return {}
			var call_segments: Array = []
			for piece: Variant in (generic_call.get("pieces", []) as Array):
				call_segments.append({"text": str((piece as Array)[0]), "tone": str((piece as Array)[1])})
			return {"object": str(generic_call.get("object", "")), "segments": call_segments}
		# ── M30 lens hook (groups as families) ────────────────────────────────────────────────
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
		"ChangeScene":
			return EventSheetSentence.statement(
				"get_tree().change_scene_to_file(%s)" % str(params_dict.get("path", "")), context)
		"ReturnEarly":
			return EventSheetSentence.return_sentence("", context)
		"ReturnValue":
			return _named_return_sentence(
				EventSheetSentence.return_sentence(str(params_dict.get("value", "")), context),
				str(params_dict.get("value", "")))
		"SetProperty":
			return EventSheetSentence.statement("%s.%s = %s" % [
				str(params_dict.get("target", "")), str(params_dict.get("property", "")),
				str(params_dict.get("value", ""))], context)
		"AddToProperty":
			return EventSheetSentence.statement("%s.%s += %s" % [
				str(params_dict.get("target", "")), str(params_dict.get("property", "")),
				str(params_dict.get("value", ""))], context)
		# ── M40 / M43 / M46 / M47 lens hook ───────────────────────────────────────────────────
		# The picked rows whose hand-written twin now reads in Construct's own verbs: an animation,
		# a sound, a visibility switch, an angle, a size, a property set by name. Each hands the
		# grammar the exact line the ACE compiles to, so the two readings cannot drift apart.
		"HideNode":
			return EventSheetSentence.statement("%s.hide()" % _ace_target(params_dict), context)
		"ShowNode":
			return EventSheetSentence.statement("%s.show()" % _ace_target(params_dict), context)
		"SetFlipH":
			return EventSheetSentence.statement("%s.flip_h = %s" % [
				_ace_target(params_dict), str(params_dict.get("flipped", ""))], context)
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
		"SubtractFromProperty":
			return EventSheetSentence.statement("%s.%s -= %s" % [
				str(params_dict.get("target", "self")), str(params_dict.get("property", "")),
				str(params_dict.get("value", ""))], context)
		# M46 - the three the Construct glossary renames. Claimed ONLY while the glossary is on, so
		# with it off each row keeps the vocabulary's own wording, untouched.
		"ReloadScene":
			if not bool(context.get("construct_words", false)):
				return {}
			return EventSheetSentence.statement("get_tree().reload_current_scene()", context)
		"SetPaused":
			if not bool(context.get("construct_words", false)):
				return {}
			return EventSheetSentence.statement("get_tree().paused = %s" % str(params_dict.get("paused", "")), context)
		"SetTimeScale":
			if not bool(context.get("construct_words", false)):
				return {}
			return EventSheetSentence.statement("Engine.time_scale = %s" % str(params_dict.get("scale", "")), context)
		"AwaitNextFrame":
			return await_reading("get_tree().process_frame", false)
		"AwaitSignal":
			return await_reading(str(params_dict.get("signal_expression", "")), false)
	# Deliberately NOT claimed: Wait. Its own display template already says the grammar's words
	# ("Wait {seconds} seconds") and the row wears the hourglass through the await chip, so leaving it
	# on the ordinary path keeps the parameter emphasis its substitution earns.
	return {}


## M28 - what an `await` says in Construct's words. Construct has "Wait for signal" as a System
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
static func await_reading(expression: String, hourglass: bool) -> Dictionary:
	var text: String = expression.strip_edges()
	if text == "get_tree().process_frame":
		return _slot_sentence(EventSheetSentence.OBJECT_SYSTEM, "Wait one tick", {}, hourglass)
	if text == "get_tree().physics_frame":
		return _slot_sentence(EventSheetSentence.OBJECT_SYSTEM, "Wait one physics tick", {}, hourglass)
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
	match condition.ace_id:
		"ExpressionIsTrue":
			return EventSheetSentence.condition(str(params_dict.get("expr", "")), context)
		"IsSameObject":
			return EventSheetSentence.condition("%s == %s" % [
				str(params_dict.get("a", "")), str(params_dict.get("b", ""))], context)
		"CompareVar":
			# Only the null comparisons have a Construct sentence ("host does not exist"); every other
			# operator already reads as the comparison it is, so the grammar hands those straight back.
			return EventSheetSentence.condition("%s %s %s" % [
				str(params_dict.get("var_name", "")), str(params_dict.get("op", "==")),
				str(params_dict.get("value", ""))], context)
		"IsActionPressed":
			return EventSheetSentence.input_action_sentence(str(params_dict.get("action", "")), false)
		"IsActionJustPressed":
			return EventSheetSentence.input_action_sentence(str(params_dict.get("action", "")), true)
		# ── M41 lens hook ─────────────────────────────────────────────────────────────────────
		# Construct's Platform and collision questions, so a picked row and the same test typed by
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
			# M44 - Construct has no "is empty": emptiness IS a count of zero.
			return EventSheetSentence.condition("%s.is_empty()" % str(params_dict.get("var_name", "")), context)
		"IsNegative", "IsPositive":
			# Claimed ONLY for the shape Construct has a word for (a 2D body's vertical speed); every
			# other number keeps the vocabulary's own "is negative" reading.
			return EventSheetSentence.movement_words(str(params_dict.get("value", "")),
				"<" if condition.ace_id == "IsNegative" else ">", context)
	return {}


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
	var value_text: String = str(params_dict.get("value", ""))
	match action.ace_id:
		"SetLocalVar":
			return EventSheetSentence.declaration("var %s = %s" % [name_text, value_text])
		"SetLocalVarTyped":
			return EventSheetSentence.declaration("var %s: %s = %s" % [
				name_text, str(params_dict.get("var_type", "")), value_text])
		"SetLocalVarInferred":
			return EventSheetSentence.declaration("var %s := %s" % [name_text, value_text])
		"SetLocalConst":
			return EventSheetSentence.declaration("const %s = %s" % [name_text, value_text])
		"SetLocalConstTyped":
			return EventSheetSentence.declaration("const %s: %s = %s" % [
				name_text, str(params_dict.get("const_type", "")), value_text])
		"SetLocalConstInferred":
			return EventSheetSentence.declaration("const %s := %s" % [name_text, value_text])
	return {}


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
				tone_color = EventSheetPalette.TEXT_PRIMARY
				tone_bold = true
			"value":
				tone_color = _viewport._get_event_style().value_highlight_color
			"object":
				tone_color = EventSheetPalette.COLOR_OBJECT
		segments.append({"text": str(part.get("text", "")), "color": tone_color, "bold": tone_bold, "italic": false})
	return segments


## The label an ACE row shows in its object column - the pending one when the row's shape named its
## own object, otherwise the ordinary provider/node reading.
func _object_label_or_pending(provider_id: String, ace_id: String) -> String:
	var pending: String = _pending_object_label
	_pending_object_label = ""
	return pending if not pending.is_empty() else _object_label_for(provider_id, ace_id)


## What the grammar needs to know about THIS sheet: the class that owns its signals, and the
## published trigger name behind each declared signal, so `jumped.emit()` can read "Signal On Jumped"
## instead of naming the member. Cached per sheet - the signal declarations only change with an edit,
## which rebuilds the rows anyway.
func sentence_context() -> Dictionary:
	var sheet: Resource = _viewport._sheet if _viewport != null else null
	if sheet == _sentence_context_sheet and not _sentence_context_cache.is_empty():
		var reused: Dictionary = _sentence_context_cache.duplicate()
		reused["verb_kind"] = _current_verb_kind()
		# ── M46 lens hook ─────────────────────────────────────────────────────────────────────
		# The Construct-words glossary is VIEW state, not sheet state, so it is stamped after the
		# per-sheet cache - flipping the toggle must change the reading without invalidating it.
		reused["construct_words"] = _construct_words_enabled()
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
		# ── M25 / M28 lens hook ────────────────────────────────────────────────────────────────
		# What only something able to ASK can answer: the script's own object name, its engine
		# properties, and each signal's parameter names. Cached with the rest of the context.
		context.merge(EventSheetViewportReadingRows.sentence_context_extras(sheet as EventSheetResource), true)
	_sentence_context_sheet = sheet
	_sentence_context_cache = context.duplicate()
	context["verb_kind"] = _current_verb_kind()
	context["construct_words"] = _construct_words_enabled()
	return context


## M46 - whether this view is reading in Construct's nouns (layout, time scale, layer). Off unless
## the user asked for it in View ▾, and never on for a headless build with no viewport.
func _construct_words_enabled() -> bool:
	return _viewport != null and _viewport.construct_words_enabled()


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


# ── Reading lenses (M9/M10/M13/M16/M20) ───────────────────────────────────────────────────────
# The lenses themselves live in viewport_lenses.gd (text) and viewport_reading_rows.gd (rows).
# What lives HERE is only the per-rebuild caching: both need to ask the sheet a question whose
# answer is the same for every row in the pass, and asking it per span would walk the whole
# events array thousands of times on a large sheet. Cleared whenever the sheet identity changes.
var _lens_sheet_stamp: int = 0
var _lens_knob_names: Dictionary = {}
var _lens_class_map: Dictionary = {}
## M39 - variable name -> the object a preloaded scene/script IS, as resolve_res_object answers it
## ({name, kind_word, icon_class}). `bullet_scene` is not what a Construct user calls the thing they
## spawn; the scene's root node is, and this is where Create object gets that name and its picture.
var _lens_scene_vars: Dictionary = {}


func _reset_lens_caches_if_stale() -> void:
	var sheet: EventSheetResource = _viewport._sheet
	var stamp: int = 0 if sheet == null else int(sheet.get_instance_id())
	if stamp == _lens_sheet_stamp:
		return
	_lens_sheet_stamp = stamp
	_lens_knob_names = EventSheetViewportReadingRows.export_knob_names(sheet)
	_lens_class_map = EventSheetViewportReadingRows.object_class_map(sheet)
	_lens_scene_vars = _scene_variable_map(sheet)


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
			map[declared_name] = resolved
	return map


## M9 - the sheet's @export knob names, so the lens can show those with Godot's Inspector
## capitalisation while ordinary variables read as plain lowercase words.
func _export_knob_names() -> Dictionary:
	_reset_lens_caches_if_stale()
	return _lens_knob_names


## M13/M20 - the object-label to class-name map, so a row naming the pack's host, a $Node / %Node
## reference or an @onready node variable can draw that class's Godot icon.
## M26 - the object-label to class-name map itself, so a call's chips can be named by the engine's
## own parameter names for that class.
func _reading_class_map() -> Dictionary:
	_reset_lens_caches_if_stale()
	return _lens_class_map


func _reading_class_icon_for(object_label: String) -> Texture2D:
	if not _viewport.show_object_icons:
		return null
	_reset_lens_caches_if_stale()
	return EventSheetViewportReadingRows.class_icon_for(object_label, _lens_class_map)


## M9/M10 applied to a finished ACE display sentence. One function so every lifted-row lane -
## conditions, actions, triggers - reads the same way, and so the View toggle has a single switch
## to flip rather than one per lane.
func _reading_sentence(text: String) -> String:
	# ── M27 lens hook ──────────────────────────────────────────────────────────────────────────
	# `delta` reads `dt` whatever else is switched on: it is the number's Construct name, not a
	# respelling of somebody's variable, so it does not belong behind the humanized-names toggle.
	var with_dt: String = EventSheetViewportLenses.dt_words(text)
	# ── M38 lens hook ──────────────────────────────────────────────────────────────────────────
	# A named constant reads as the value it IS whatever else is switched on, for the same reason dt
	# does: `Vector2.ZERO` is not somebody's variable name, it is the point (0, 0). Applied here so a
	# row that reached the canvas through a display TEMPLATE reads it exactly as a typed line does.
	var with_constants: String = EventSheetSentence.constant_words(with_dt, sentence_context())
	if not _viewport.humanize_names_enabled():
		return with_constants
	return EventSheetViewportLenses.humanize_sentence(with_constants, _export_knob_names())


## M12 - whether a lifted condition READS as inverted even though its `negated` flag is not set,
## which is the case for an expression condition lifted straight from `if not <cond>:`. The badge
## column asks this so the ✕ appears; _format_condition_descriptor strips the matching word so
## the two never both show.
func _condition_reads_negated(condition: ACECondition) -> bool:
	if condition == null:
		return false
	return bool(EventSheetViewportLenses.strip_leading_not(
		_format_condition_descriptor_base(condition)
	).get("negated", false))


## M13/M20 - the class icon for the object a statement row acts on. The subject is the head of the
## statement: the assignment target for a `Set` sentence (`$Head.rotation.x` -> `$Head`), the
## receiver for a call (`host.move_and_slide()` -> `host`). Null whenever nothing is known, which
## is also what headless returns, so a headless render keeps the text-only look.
func _reading_sentence_icon(sentence: Dictionary, code: String) -> Texture2D:
	var subject: String = ""
	# ── M25 lens hook ──────────────────────────────────────────────────────────────────────────
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


## M16 - the "Functions ▸ Call Name" pieces for a hand-written call the sheet can attribute to one
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
	return EventSheetViewportReadingRows.call_reading_pieces(
		EventSheetViewportLenses.function_display_name(function_name, event_function.ace_display_name),
		arguments,
		EventSheetViewportReadingRows.parameter_names_of(event_function),
		_viewport.humanize_names_enabled(),
		_export_knob_names()
	)


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
			var ranges: Array = _value_ranges_for(text)
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
	_pending_display_bbcode = false
	_pending_param_ranges = {}
	_pending_grammar_segments = []
	return span


## format_display, but the display TEMPLATE is translated FIRST (then {slots} substitute), so
## a pack-shipped translations.csv localises whole viewport sentences - "take {amount} damage"
## translates as one key and every row using it follows. Display-only: ids, params, and the
## compiled output never translate. Handles both shapes (registry ACEDefinition metadata
## templates and builtin ACEDescriptor display text); English or a missing key pass through,
## so this is byte-identical to format_display until a catalog provides the template.
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
			shown = EventSheetGameCatalog.preview_param(shown)
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
		var param_shown: String = EventSheetGameCatalog.preview_param(
			_translated_option_label(param.display_value(param_value), str(param_value)))
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
## ranges the renderer bolds (the C3 parameter emphasis). `replacements` is an ordered list
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
