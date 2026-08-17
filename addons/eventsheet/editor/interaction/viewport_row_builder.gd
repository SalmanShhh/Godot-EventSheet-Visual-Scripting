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
		"", "Variant":
			return EventSheetL10n.translate("any")
		_:
			# Every Node class is one word to a reader: a node. The specific class is what the picker
			# and the tooltip say; on a row it is the KIND of thing that matters. Derived from ClassDB
			# rather than a list, so a class the engine adds tomorrow reads right with no edit here.
			var bare_type: String = type_name.strip_edges()
			if ClassDB.class_exists(bare_type) and ClassDB.is_parent_class(bare_type, "Node"):
				return EventSheetL10n.translate("node")
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
	for body_entry: Variant in body_entries:
		if body_entry is Resource:
			var child_row: EventRowData = _viewport._build_row_from_resource(body_entry as Resource, indent + 1)
			if child_row != null:
				# Mark the subtree BEFORE any span build: a condition-less row inside a verb body must
				# read "Always" (it runs when the verb is called), not the sheet's "Every Tick".
				_mark_verb_body(child_row)
				if not body_editable:
					_make_row_inert(child_row)
				row_data.children.append(child_row)
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
func _mark_verb_body(row_data: EventRowData) -> void:
	row_data.in_verb_body = true
	for child: EventRowData in row_data.children:
		_mark_verb_body(child)


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
	var title: String = signal_row.ace_name.strip_edges() if signal_row.trigger else ""
	if title.is_empty():
		title = signal_row.signal_name
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
			"badge_fg": event_style.behavior_accent_color if signal_row.trigger else event_style.behavior_accent_color.lerp(chip_bg, 0.45),
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
	var condition_lines: int = _append_signal_param_spans(spans, signal_row) + 1
	# The ACTION lane answers "and what actually fires?". For a trigger that is the underlying signal
	# identifier - the friendly name hides it, but it is what game code connects to, and it is the one
	# fact a reader cannot recover from the left lane. A plain signal's name IS its identifier, so
	# repeating it would be noise; it says "internal" instead, the same word a Define row uses for a
	# verb that is not published as an ACE.
	if signal_row.trigger:
		spans.append(_define_chip(EventSheetL10n.translate("emits %s") % signal_row.signal_name, chip_bg, chip_fg, 0, "signal_row"))
	else:
		spans.append(_define_chip(EventSheetL10n.translate("internal"), chip_bg, chip_fg.lerp(chip_bg, 0.45), 0, "signal_row"))
	row_data.spans = spans
	row_data.line_count = maxi(condition_lines, 1)
	return row_data


## One cell per value the signal passes to whoever handles it, in the shared field-cell grammar (the
## same one a condition cell and a verb parameter use). SignalRow stores them as raw declaration text
## ("damage" or "damage: int"), so the type is split off and read as a plain word - a handler author
## needs to know a number is coming, not that GDScript spells it `int`. Returns the last line used.
func _append_signal_param_spans(spans: Array[SemanticSpan], signal_row: SignalRow) -> int:
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
		line += 1
		append_field_cell(cell_host, param_name, type_word, {
			"kind": "signal_row",
			"param_index": index,
			"line_index": line
		})
	spans.append_array(cell_host.spans)
	return line


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
## "Add wave[1] to score", `var label := wave[0]` becomes "Let label = wave[0]". Returns
## {indent, segments} - each segment {text, tone} with tone "plain" | "name" | "value" - or {} when
## the line is not one of the shapes below.
##
## A person reading a sheet is reading STEPS, and an operator glyph is the one part of a step that
## has to be decoded rather than read. Naming the operation removes that decode without hiding
## anything: the row is the same RawCodeRow, so double-click still opens the real code and the byte
## round-trip is untouched. The type annotation is deliberately dropped from the "Let" sentence -
## it is one hover away and it is never the point of the step.
##
## Strictness is the whole value here: a sentence that is ALMOST right is worse than the code it
## replaced. Only single-line statements are claimed, operators must be found at the TOP level
## (never inside a string or brackets) and in their SPACED form (so ` == `, ` != `, ` <= ` can not
## be mistaken for an assignment), and a left side with a space or a `(` in it is a call rather
## than a simple target and is refused. Static + pure, so it is unit-testable without a viewport.
static func statement_sentence(code: String) -> Dictionary:
	if code.contains("\n"):
		return {}
	var indent: int = code.length() - code.lstrip("\t").length()
	var text: String = code.strip_edges()
	if text.is_empty() or text.begins_with("#"):
		return {}
	var keyword: String = _leading_word(text)
	# Control flow is a BRANCH, not a step, and it already renders as its own structure elsewhere.
	# `await` hides a suspension point, which no sentence should ever paper over.
	if keyword in ["if", "elif", "else", "for", "while", "match", "pass", "break", "continue", "await"]:
		return {}
	if keyword == "return":
		if text == "return":
			return {"indent": indent, "segments": [{"text": "Return", "tone": "plain"}]}
		var returned: String = text.substr(7).strip_edges()
		if returned.is_empty():
			return {}
		return {"indent": indent, "segments": [
			{"text": "Return ", "tone": "plain"},
			{"text": returned, "tone": "value"}
		]}
	if keyword == "var":
		return _declaration_sentence(text, indent)
	# Compound assignment reads as the arithmetic verb it IS. The spaced token is what keeps
	# `x <= y` and friends out: none of them contain " += " and none of them contain " = ".
	for operator: String in [" += ", " -= ", " *= ", " /= "]:
		var operator_at: int = _top_level_operator(text, operator)
		if operator_at < 0:
			continue
		var compound_target: String = text.substr(0, operator_at).strip_edges()
		var amount: String = text.substr(operator_at + operator.length()).strip_edges()
		if not _is_simple_target(compound_target) or amount.is_empty():
			return {}
		match operator:
			" += ":
				return {"indent": indent, "segments": [
					{"text": "Add ", "tone": "plain"},
					{"text": amount, "tone": "value"},
					{"text": " to ", "tone": "plain"},
					{"text": compound_target, "tone": "name"}
				]}
			" -= ":
				return {"indent": indent, "segments": [
					{"text": "Subtract ", "tone": "plain"},
					{"text": amount, "tone": "value"},
					{"text": " from ", "tone": "plain"},
					{"text": compound_target, "tone": "name"}
				]}
			" *= ":
				return {"indent": indent, "segments": [
					{"text": "Multiply ", "tone": "plain"},
					{"text": compound_target, "tone": "name"},
					{"text": " by ", "tone": "plain"},
					{"text": amount, "tone": "value"}
				]}
			_:
				return {"indent": indent, "segments": [
					{"text": "Divide ", "tone": "plain"},
					{"text": compound_target, "tone": "name"},
					{"text": " by ", "tone": "plain"},
					{"text": amount, "tone": "value"}
				]}
	var assign_at: int = _top_level_operator(text, " = ")
	if assign_at < 0:
		return {}
	var assign_target: String = text.substr(0, assign_at).strip_edges()
	var assigned: String = text.substr(assign_at + 3).strip_edges()
	if not _is_simple_target(assign_target) or assigned.is_empty():
		return {}
	return {"indent": indent, "segments": [
		{"text": "Set ", "tone": "plain"},
		{"text": assign_target, "tone": "name"},
		{"text": " to ", "tone": "plain"},
		{"text": assigned, "tone": "value"}
	]}


## The "Let name = value" sentence for a `var` declaration, shared by both spellings (`var x = 1`,
## `var x := 1`, `var x: int = 1`). Split out so the shapes stay readable one beside the other.
static func _declaration_sentence(text: String, indent: int) -> Dictionary:
	var rest: String = text.substr(4)
	var walrus_at: int = _top_level_operator(rest, " := ")
	var equals_at: int = _top_level_operator(rest, " = ")
	var name_text: String = ""
	var value_text: String = ""
	if walrus_at >= 0 and (equals_at < 0 or walrus_at < equals_at):
		name_text = rest.substr(0, walrus_at).strip_edges()
		value_text = rest.substr(walrus_at + 4).strip_edges()
	elif equals_at >= 0:
		name_text = rest.substr(0, equals_at).strip_edges()
		value_text = rest.substr(equals_at + 3).strip_edges()
	else:
		return {}
	# `var label: String = x` names the variable "label": the declared type is one hover away in the
	# code, and showing it would put a compiler detail in the middle of an English sentence.
	var colon_at: int = name_text.find(":")
	if colon_at >= 0:
		name_text = name_text.substr(0, colon_at).strip_edges()
	if value_text.is_empty() or not _is_identifier(name_text):
		return {}
	return {"indent": indent, "segments": [
		{"text": "Let ", "tone": "plain"},
		{"text": name_text, "tone": "name"},
		{"text": " = ", "tone": "plain"},
		{"text": value_text, "tone": "value"}
	]}


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
	for line_index in range(code_lines.size()):
		spans.append(_make_span(
			code_lines[line_index] if not code_lines[line_index].is_empty() else " ",
			SemanticSpan.SpanType.VALUE,
			{
				"editable": false,
				"kind": "raw_code",
				"line_index": line_index,
				"text_color": line_fg
			}
		))
	row_data.spans = spans
	return row_data


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


## Builds a row for a variable placed directly in the event tree (movable like an event).
func _build_tree_variable_row(variable: LocalVariable, indent: int) -> EventRowData:
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
			var case_row: EventRowData = _build_condition_action_row(case_label, body, indent, match_row)
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
## once), never inline text. `not` reads as the word Not, and value comparisons ("hp < 20")
## keep their values. Display-only; the hover carries the code.
func _friendly_guard_text(guard: String) -> String:
	var text: String = guard.strip_edges()
	var negated: bool = text.begins_with("not ")
	if negated:
		text = text.substr(4).strip_edges()
	var friendly: String = text
	var call: Dictionary = ViewportRowBuilder.call_parts(text)
	if not call.is_empty() and (str(call.get("target", "")).is_empty() or str(call.get("target", "")) == "self"):
		var args_text: String = _joined_call_args(call)
		friendly = str(call.get("verb", "")) if args_text.strip_edges().is_empty() else "%s ( %s )" % [str(call.get("verb", "")), args_text]
	if negated:
		return "%s %s" % [EventSheetL10n.translate("Not"), friendly]
	return friendly


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
	var child: EventRowData = _build_condition_action_row(_friendly_guard_text(guard), inner, indent, match_row)
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
func _build_condition_action_row(condition_text: String, action_lines: PackedStringArray, indent: int, source: Resource) -> EventRowData:
	var row := EventRowData.new()
	row.indent = indent
	row.row_type = EventRowData.RowType.EVENT
	row.source_resource = source
	row.line_count = maxi(action_lines.size(), 1)
	var condition_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	var action_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_action_style())
	var spans: Array[SemanticSpan] = [
		_make_span(condition_text if not condition_text.is_empty() else " ", SemanticSpan.SpanType.CONDITION, {
			"lane": "condition",
			"kind": "match_case",
			"editable": false,
			"line_index": 0
		}.merged(condition_style, true))
	]
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
	row_data.spans = [
		_make_span(var_name if not var_name.is_empty() else "(unnamed)", SemanticSpan.SpanType.OBJECT, variable_meta.merged({"editable": false}, true)),
		_make_span(":", SemanticSpan.SpanType.OPERATOR, variable_meta.merged({"editable": false}, true)),
		_make_span(type_name if not type_name.is_empty() else "Variant", SemanticSpan.SpanType.VALUE, variable_meta.merged({"editable": false}, true))
	]
	if is_constant:
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
	row_data.spans.append(
		_make_span(
			value_text,
			SemanticSpan.SpanType.VALUE,
			variable_meta.merged({"editable": false}, true)
		)
	)
	return row_data

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


func _build_event_spans(event_row: EventRow, in_verb_body: bool = false) -> Array[SemanticSpan]:
	var spans: Array[SemanticSpan] = []
	var condition_line_index: int = 0
	var action_line_index: int = 0
	var inline_trigger_condition_index: int = _find_inline_trigger_condition_index(event_row)
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var condition_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	var action_style_meta: Dictionary = _viewport._build_element_style_metadata(_viewport._get_action_style())
	if event_row.else_mode != EventRow.ElseMode.NONE:
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
	if event_row.else_mode == EventRow.ElseMode.NONE and event_row.trigger != null:
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
	elif event_row.else_mode == EventRow.ElseMode.NONE and not event_row.trigger_id.is_empty():
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
				_trigger_display_text(event_row.trigger_provider_id, event_row.trigger_id),
				SemanticSpan.SpanType.CONDITION,
				{
					"lane": "condition",
					"kind": "trigger",
					"ace_index": 0,
					"chip": true,
					"line_index": condition_line_index,
					"object_label": _object_label_for(event_row.trigger_provider_id, event_row.trigger_id),
					"object_icon": _object_icon_for(event_row.trigger_provider_id, event_row.trigger_id)
				}.merged(condition_style_meta, true)
			)
		)
		condition_line_index += 1
	elif event_row.else_mode == EventRow.ElseMode.NONE and inline_trigger_condition_index >= 0 and inline_trigger_condition_index < event_row.conditions.size():
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
			if condition_index == inline_trigger_condition_index:
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
						"object_label": _object_label_for(condition.provider_id, condition.ace_id),
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
		spans.append(
			_make_span(
				_format_pick_filter(pick),
				SemanticSpan.SpanType.CONDITION,
				{
					"lane": "condition",
					"kind": "pick_filter",
					"pick_index": pick_index,
					"chip": true,
					"line_index": condition_line_index,
					# Loops are System's, like in Construct - and the label puts the line in the
					# shared object sub-lane, so its text aligns with the cells above it.
					"object_label": _object_label_for("Core", "")
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
		for action_index in range(event_row.actions.size()):
			var action_resource: Resource = event_row.actions[action_index]
			if action_resource is ACEAction:
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
							"object_label": _object_label_for((action_resource as ACEAction).provider_id, (action_resource as ACEAction).ace_id),
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
				var inline_is_literal_part: bool = is_literal_part(inline_raw.code) or is_single_statement(inline_raw.code)
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
	if event_row.else_mode == EventRow.ElseMode.ELSE or event_row.else_mode == EventRow.ElseMode.ELIF:
		condition_lines += 1
	var inline_trigger_index: int = _find_inline_trigger_condition_index(event_row)
	var has_trigger: bool = (
		event_row.trigger != null
		or not event_row.trigger_id.is_empty()
		or (inline_trigger_index >= 0 and inline_trigger_index < event_row.conditions.size())
	)
	if has_trigger and event_row.else_mode == EventRow.ElseMode.NONE:
		condition_lines += 1
	for condition_index in range(event_row.conditions.size()):
		if condition_index == inline_trigger_index:
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
			action_count += maxi((action_resource as RawCodeRow).code.split("\n").size(), 1)
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
		row_data.spans = _build_event_spans(row_data.source_resource as EventRow, row_data.in_verb_body)


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
	if condition.negated:
		var negated_meta: Dictionary = _viewport.BADGE_NEGATED_METADATA.duplicate(true)
		negated_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)
		negated_meta["condition_index"] = condition_index
		negated_meta["line_index"] = line_index
		negated_meta["badge_style"] = "negated"
		# Event-sheet-style inverted-condition marker: a bare red ✗ (the --invert-icon-color),
		# no circle behind it. Themable via EventSheetEventStyle.invert_marker_color.
		negated_meta["badge_bg"] = Color(0.0, 0.0, 0.0, 0.0)
		negated_meta["badge_fg"] = _viewport._get_event_style().invert_marker_color
		spans.append(_make_span("✕", SemanticSpan.SpanType.KEYWORD, negated_meta))
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
	return "%s(%s)" % [label, args] if not args.is_empty() else label


func _format_condition_descriptor(condition: ACECondition) -> String:
	# Rich-param styling arms here; TEMPLATE markup arms inside _format_display_translated,
	# where the template is RESOLVED - a locale whose catalog predates the markup translates
	# the plain sentence, and that plain result must not enter the styled branch.
	_pending_display_bbcode = _param_markup_applies(condition.provider_id, condition.ace_id, condition.params)
	var base_text: String = _format_condition_descriptor_base(condition)
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
	var base_text: String = _format_action_descriptor_base(action)
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
	var sentence: Dictionary = statement_sentence(raw.code)
	if not sentence.is_empty():
		indent = int(sentence.get("indent", 0))
		for segment: Variant in (sentence.get("segments", []) as Array):
			var part: Dictionary = segment
			pieces.append([str(part.get("text", "")), str(part.get("tone", "plain"))])
	else:
		var call_info: Dictionary = call_parts(raw.code)
		if call_info.is_empty():
			return false
		indent = int(call_info.get("indent", 0))
		pieces.append([str(call_info.get("target", "")) + "  ", "object"])
		pieces.append([str(call_info.get("verb", "")), "name"])
		var args: PackedStringArray = call_info.get("args", PackedStringArray())
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
		"bbcode_segments": sentence_segments
	}.merged(action_style_meta, false)))
	return true


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
