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

var _viewport: Control = null
# Per-build occurrence counters ("label" -> count) giving every paired region a STABLE
# fold key ("label#n") that survives sessions - row uids are instance-based and cannot
# (the persisted-folds layer keys on these instead). Reset by _pair_region_fences.
var _region_occurrences: Dictionary = {}


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
	row_data.spans = [
		_make_span("Class setup", SemanticSpan.SpanType.KEYWORD, {
			"editable": false,
			"badge": true,
			"badge_style": "scope",
			"badge_bg": EventSheetPalette.COLOR_SETUP_BADGE_BG,
			"badge_fg": EventSheetPalette.COLOR_SETUP_BADGE_FG,
			"kind": "scaffolding_strip",
			"line_index": 0
		}),
		_make_span("class_name, host binding & annotations - %d lines" % line_total, SemanticSpan.SpanType.COMMENT, {
			"editable": false,
			"kind": "scaffolding_strip",
			"text_color": Color(EventSheetPalette.TEXT_MUTED.r, EventSheetPalette.TEXT_MUTED.g, EventSheetPalette.TEXT_MUTED.b, 0.8)
		})
	]
	return row_data


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
func _build_published_verbs_rows(sheet: EventSheetResource) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	if sheet == null or sheet.functions.is_empty():
		return rows
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			rows.append(_build_define_function_row(entry as EventFunction, 0))
	return rows


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
	var base: Color = _viewport._get_event_style().object_label_color
	match role:
		"condition":
			return base.lerp(EventSheetPalette.COLOR_ACE_CONDITION_BADGE_FG, 0.55)
		"expression":
			return base.lerp(EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_FG, 0.55)
	return base.lerp(EventSheetPalette.COLOR_ACE_ACTION_BADGE_FG, 0.55)


## One Define block: role badge in its ACE-role colour, the friendly published name, a `→ type`
## chip for value-returning verbs, the category chip, an "internal" chip when the function is NOT
## exposed as an ACE (a plain helper other sheets can't pick), and the muted real signature built
## by the COMPILER's own emitters - so what the row claims can never disagree with codegen.
func _build_define_function_row(event_function: EventFunction, indent: int) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = event_function
	# Name-keyed uid (keeping the define_fn_ prefix every consumer matches) so an expanded body survives the
	# undo funnel's resource-replacement rebuild - an instance-id uid would reset the fold on every edit.
	var fold_key: String = event_function.function_name.strip_edges()
	row_data.row_uid = "define_fn_%s" % (fold_key if not fold_key.is_empty() else str(event_function.get_instance_id()))
	row_data.disabled = not event_function.enabled
	var role: String = define_role_for(event_function)
	var badge_colors: Dictionary = {
		"action": [EventSheetPalette.COLOR_ACE_ACTION_BADGE_BG, EventSheetPalette.COLOR_ACE_ACTION_BADGE_FG],
		"condition": [EventSheetPalette.COLOR_ACE_CONDITION_BADGE_BG, EventSheetPalette.COLOR_ACE_CONDITION_BADGE_FG],
		"expression": [EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_BG, EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_FG],
	}
	# The whole verb reads as a Construct-style event block tinted by its ACE kind: a faint wash of the
	# role's accent behind the row (drawn by the renderer's custom_color path) plus a left accent bar, so
	# Action / Condition / Expression are distinguishable at a glance, not only by the badge word.
	var role_accent: Color = (badge_colors[role] as Array)[1]
	row_data.custom_color = Color(role_accent.r, role_accent.g, role_accent.b, 0.16)
	var display_name: String = event_function.ace_display_name.strip_edges()
	if display_name.is_empty():
		display_name = event_function.function_name.capitalize()
	var spans: Array[SemanticSpan] = [
		_make_span(role.capitalize(), SemanticSpan.SpanType.KEYWORD, {
			"editable": false,
			"badge": true,
			"badge_style": "scope",
			"badge_bg": (badge_colors[role] as Array)[0],
			"badge_fg": (badge_colors[role] as Array)[1],
			"kind": "define_function"
		})
	]
	# The verb reads as an event-sheet line, not a raw signature: an authored @ace_display_template is
	# the whole sentence (its {param} slots filled with each parameter's label); otherwise the friendly
	# name plus a comma-joined slot list. The real `func ... -> Type` still follows as a muted code cue
	# below, so the row stays code-adjacent and can never disagree with what compiles.
	# Slight per-role tint on the verb name so an Action / Condition / Expression reads distinctly at a
	# glance among the inline verb rows (reinforces the role badge without a loud colour).
	var name_color: Color = _define_role_name_color(role)
	var authored_line: String = friendly_template_line(event_function)
	if not authored_line.is_empty():
		spans.append(_make_span(authored_line, SemanticSpan.SpanType.OBJECT, {
			"kind": "define_function",
			"text_color": name_color
		}))
	else:
		spans.append(_make_span(display_name, SemanticSpan.SpanType.OBJECT, {
			"kind": "define_function",
			"text_color": name_color
		}))
		var param_labels: String = friendly_param_labels(event_function)
		if not param_labels.is_empty():
			spans.append(_make_span(param_labels, SemanticSpan.SpanType.VALUE, {
				"editable": false,
				"kind": "define_function",
				"text_color": _viewport._get_event_style().value_highlight_color
			}))
	if role != "action":
		spans.append(_make_span("→ %s" % SheetCompiler._function_return_type_name(event_function), SemanticSpan.SpanType.KEYWORD, {
			"editable": false,
			"badge": true,
			"badge_style": "scope",
			"badge_bg": EventSheetPalette.COLOR_CHIP_BG,
			"badge_fg": EventSheetPalette.COLOR_CHIP_FG,
			"kind": "define_function"
		}))
	if not event_function.ace_category.strip_edges().is_empty():
		spans.append(_make_span(event_function.ace_category.strip_edges(), SemanticSpan.SpanType.KEYWORD, {
			"editable": false,
			"badge": true,
			"badge_style": "scope",
			"badge_bg": EventSheetPalette.COLOR_CAT_CHIP_BG,
			"badge_fg": EventSheetPalette.COLOR_CAT_CHIP_FG,
			"kind": "define_function"
		}))
	if not event_function.expose_as_ace:
		spans.append(_make_span("internal", SemanticSpan.SpanType.KEYWORD, {
			"editable": false,
			"badge": true,
			"badge_style": "scope",
			"badge_bg": EventSheetPalette.COLOR_CHIP_BG,
			"badge_fg": Color(EventSheetPalette.TEXT_MUTED.r, EventSheetPalette.TEXT_MUTED.g, EventSheetPalette.TEXT_MUTED.b, 0.9),
			"kind": "define_function"
		}))
	spans.append(_make_span(
		"func %s(%s) -> %s" % [
			event_function.function_name,
			SheetCompiler._emit_function_params(event_function),
			SheetCompiler._function_return_type_name(event_function)
		],
		SemanticSpan.SpanType.VALUE,
		{"editable": false, "kind": "define_function", "text_color": EventSheetPalette.TEXT_MUTED}
	))
	row_data.spans = spans
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
				if not body_editable:
					_make_row_inert(child_row)
				row_data.children.append(child_row)
	if not row_data.children.is_empty():
		row_data.folded = bool(_viewport._fold_state.get(row_data.row_uid, true))
	return row_data


## Strips a row and its whole subtree of its editing identity so it renders but is inert - no selection,
## drag, delete, or inline edit reaches it (every mutation path guards on source_resource being the row's
## kind, and the add-cell click guards on a non-null source). Used for a published verb's body rows: they
## display the function's conditions/actions/raw blocks for reading, but their resources live in
## event_function.events, not sheet.events, so any write would alias or corrupt the .gd. Read-only reveal.
func _make_row_inert(row_data: EventRowData) -> void:
	row_data.source_resource = null
	for child: EventRowData in row_data.children:
		_make_row_inert(child)


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
func _build_enum_row(enum_row: EnumRow, indent: int) -> EventRowData:
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = enum_row
	row_data.row_uid = "enum_%s_%d" % [str(enum_row.get_instance_id()), indent]
	row_data.disabled = not enum_row.enabled or bool(_viewport._row_disabled_state.get(row_data.row_uid, false))
	row_data.breakpoint_enabled = bool(_viewport._breakpoint_rows.get(row_data.row_uid, false))
	# The display text comes from the registered "enum" resource kind - the same summary
	# contract every Custom Block kind renders through.
	var enum_kind: EventSheetBlockKind = EventSheetBlockRegistry.kind_for(enum_row)
	row_data.spans = [
		_make_span(
			"enum",
			SemanticSpan.SpanType.KEYWORD,
			{"badge": true, "text_color": event_style.behavior_accent_color}
		),
		_make_span(
			enum_kind.summary_for(enum_row) if enum_kind != null else enum_row.enum_name,
			SemanticSpan.SpanType.VALUE,
			{"kind": "enum_row", "text_color": event_style.object_label_color}
		)
	]
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


## A signal row: rendered like a declaration ("signal  hit(damage: int)"); double-click
## opens the signal dialog.
func _build_signal_row(signal_row: SignalRow, indent: int) -> EventRowData:
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = signal_row
	row_data.row_uid = "signal_%s_%d" % [str(signal_row.get_instance_id()), indent]
	row_data.disabled = not signal_row.enabled or bool(_viewport._row_disabled_state.get(row_data.row_uid, false))
	row_data.breakpoint_enabled = bool(_viewport._breakpoint_rows.get(row_data.row_uid, false))
	# The declaration text comes from the registered "signal" resource kind - the same summary
	# contract every Custom Block kind renders through.
	var signal_kind: EventSheetBlockKind = EventSheetBlockRegistry.kind_for(signal_row)
	var declaration: String = signal_kind.summary_for(signal_row) if signal_kind != null else signal_row.signal_name
	# A trigger signal (a `## @ace_trigger` block folded onto the row on import) is a first-class
	# "declare a trigger ACE" block, NOT raw scaffolding: it renders like a Variable row - a "trigger"
	# badge, the friendly ACE name, an optional category chip - with the underlying `signal …` declaration
	# kept muted beside it so it's still obvious what emits. Double-click still opens the signal dialog.
	if signal_row.trigger:
		var trigger_title: String = signal_row.ace_name.strip_edges()
		if trigger_title.is_empty():
			trigger_title = signal_row.signal_name
		row_data.spans = [
			_make_span(
				"trigger",
				SemanticSpan.SpanType.KEYWORD,
				{"badge": true, "text_color": event_style.behavior_accent_color, "kind": "signal_row"}
			),
			_make_span(
				trigger_title,
				SemanticSpan.SpanType.OBJECT,
				{"kind": "signal_row", "text_color": event_style.object_label_color}
			)
		]
		# Picker category chip (@ace_category), styled like the Variable row's Inspector-group chip.
		if not signal_row.ace_category.strip_edges().is_empty():
			row_data.spans.append(
				_make_span(
					signal_row.ace_category.strip_edges(),
					SemanticSpan.SpanType.KEYWORD,
					{
						"badge": true,
						"badge_style": "scope",
						"badge_bg": EventSheetPalette.COLOR_CAT_CHIP_BG,
						"badge_fg": EventSheetPalette.COLOR_CAT_CHIP_FG,
						"kind": "signal_row"
					}
				)
			)
		row_data.spans.append(
			_make_span(
				"signal %s" % declaration,
				SemanticSpan.SpanType.VALUE,
				{"kind": "signal_row", "text_color": EventSheetPalette.TEXT_MUTED}
			)
		)
		return row_data
	row_data.spans = [
		_make_span(
			"signal",
			SemanticSpan.SpanType.KEYWORD,
			{"badge": true, "text_color": event_style.behavior_accent_color}
		),
		_make_span(
			declaration,
			SemanticSpan.SpanType.VALUE,
			{"kind": "signal_row", "text_color": event_style.object_label_color}
		)
	]
	return row_data


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
	var header_regex: RegEx = RegEx.new()
	if header_regex.compile("^func ([A-Za-z_][A-Za-z0-9_]*)\\((.*)\\)(?: -> (.+))?:$") != OK:
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
		row_data.spans = [
			_make_span("Host binding", SemanticSpan.SpanType.KEYWORD, {
				"editable": false,
				"badge": true,
				"badge_style": "scope",
				"badge_bg": EventSheetPalette.COLOR_SETUP_BADGE_BG,
				"badge_fg": EventSheetPalette.COLOR_SETUP_BADGE_FG,
				"kind": "raw_code",
				"line_index": 0
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
	var badge_label: String = "GDScript"
	var badge_fg: Color = EventSheetPalette.COLOR_SETUP_BADGE_FG if is_scaffold else EventSheetPalette.COLOR_CODE_BADGE_FG
	var line_fg: Color = EventSheetPalette.TEXT_MUTED if is_scaffold else EventSheetPalette.TEXT_PRIMARY
	var spans: Array[SemanticSpan] = []
	spans.append(_make_span(badge_label, SemanticSpan.SpanType.KEYWORD, {
		"editable": false,
		"badge": true,
		"badge_style": "scope",
		"badge_bg": EventSheetPalette.COLOR_CODE_BADGE_BG,
		"badge_fg": badge_fg,
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
	var data_class_name_str: String = str(model.get("class_name"))
	row_data.row_uid = "data_class_%s" % (data_class_name_str if not data_class_name_str.is_empty() else str(raw_row.get_instance_id()))
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
	var header_text: String = "class %s" % data_class_name_str
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
	var spans: Array[SemanticSpan] = [
		_make_span(str(field.get("name")), SemanticSpan.SpanType.OBJECT, {
			"lane": "condition",
			"editable": false,
			"kind": "data_class_field",
			"line_index": 0,
			"text_color": _viewport._get_event_style().object_label_color
		}.merged(condition_style, true)),
		_make_span(":", SemanticSpan.SpanType.OPERATOR, {"lane": "condition", "editable": false, "kind": "data_class_field", "line_index": 0}.merged(condition_style, true)),
		_make_span(str(field.get("type")), SemanticSpan.SpanType.VALUE, {
			"lane": "condition",
			"editable": false,
			"kind": "data_class_field",
			"line_index": 0,
			"text_color": EventSheetPalette.TEXT_MUTED
		}.merged(condition_style, true))
	]
	# Action cell: its default value (the editable part).
	if bool(field.get("has_default", false)):
		spans.append(_make_span("=", SemanticSpan.SpanType.OPERATOR, {"lane": "action", "editable": false, "kind": "data_class_field", "line_index": 0}.merged(action_style, true)))
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
	var class_name_str: String = str(model.get("class_name"))
	row_data.row_uid = "methods_class_%s" % (class_name_str if not class_name_str.is_empty() else str(raw_row.get_instance_id()))
	row_data.language_block = true  # a class declaration, not a regular ACE event - gets the language stripe
	row_data.disabled = not raw_row.enabled or bool(_viewport._row_disabled_state.get(row_data.row_uid, false))
	var body: Array = model.get("body", [])
	var condition_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_condition_style())
	var action_style: Dictionary = _viewport._build_element_style_metadata(_viewport._get_action_style())
	var event_style: EventSheetEventStyle = _viewport._get_event_style()
	var base: String = str(model.get("extends", ""))
	var header_text: String = "class %s" % class_name_str
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
	# Event-sheet-style per-group footer: always the group's last child, one level deeper.
	if _viewport.show_add_event_footers:
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
	return row_data


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
		for match_case: MatchCase in match_row.cases:
			if match_case == null:
				continue
			var body: PackedStringArray = _match_case_summary_lines(match_case.events)
			if body.is_empty():
				body = PackedStringArray(["pass"])
			var case_row: EventRowData = _build_condition_action_row(str(match_case.pattern).strip_edges(), body, indent, match_row)
			case_row.language_block = true  # a switch case - a language construct, not a regular ACE event
			rows.append(case_row)
	return rows


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
	row_data.spans.append(
		_make_span(
			_format_variable_value(default_value),
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
	if trigger_id.begins_with("signal:"):
		return "On %s" % trigger_id.trim_prefix("signal:").capitalize()
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


func _build_event_spans(event_row: EventRow) -> Array[SemanticSpan]:
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
					"line_index": condition_line_index
				}.merged(condition_style_meta, true)
			)
		)
		condition_line_index += 1
	if spans.is_empty() and event_row.else_mode != EventRow.ElseMode.ELSE:
		# An event with no conditions reads as "every tick"; render it as a real cell (not bare
		# text) so the condition lane still shows a clear, clickable empty event block.
		spans.append(
			_make_span(
				EventSheetL10n.translate("Every Tick"),
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
	var add_condition_color: Color = condition_style_meta.get("text_color", EventSheetPalette.COLOR_CONDITION)
	add_condition_color.a *= 0.55
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
				var match_lines: PackedStringArray = PackedStringArray(["match %s:" % match_resource.match_expression])
				# Structured cases render as their OWN condition/action child rows (built in
				# _build_event_row); this header stays one line. Only a raw-text match shows branches here.
				if not structured_match:
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
								"text_color": event_style.value_highlight_color
							}
						)
					)
			elif action_resource is RawCodeRow:
				# In-flow GDScript block: one action-lane cell per code line. All lines share
				# the block's ace_index, so click/drag/delete treat the block as one action.
				var inline_raw: RawCodeRow = action_resource as RawCodeRow
				var inline_lines: PackedStringArray = inline_raw.code.split("\n")
				var inline_total: int = maxi(inline_lines.size(), 1)
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
								"code_cell": true,
								"block_lines": inline_total,
								"block_line": inline_line_index,
								"line_index": action_line_index,
								"object_label": "GDScript" if inline_line_index == 0 else ""
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
							"# " + action_comment_lines[comment_line_index],
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
								"text_color": _viewport._get_event_style().comment_text_color
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
	var max_condition_line: int = maxi(condition_lines, 1)
	# Action lane: "+ Add" sits on its own line below the actions (and below the event comment
	# when present), so the lane spans action_count (+ comment) + 1 lines. In-flow GDScript
	# blocks occupy one line per code line.
	var action_count: int = 0
	for action_resource in event_row.actions:
		if action_resource is ACEAction:
			action_count += 1
		elif action_resource is RawCodeRow:
			action_count += maxi((action_resource as RawCodeRow).code.split("\n").size(), 1)
		elif action_resource is MatchRow:
			var match_resource: MatchRow = action_resource as MatchRow
			if not match_resource.cases.is_empty():
				action_count += 1  # just the `match expr:` header; each case is its own child row now
			else:
				action_count += match_resource.branches_text.split("\n").size() + 1
		elif action_resource is CommentRow:
			action_count += maxi((action_resource as CommentRow).text.split("\n").size(), 1)
	var max_action_line: int = action_count
	if not event_row.comment.is_empty():
		max_action_line = maxi(action_count, _viewport.COMMENT_DEFAULT_LINE_INDEX) + 1
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
		row_data.spans = _build_event_spans(row_data.source_resource as EventRow)


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
		var object_column_width: float = EventRowRenderer.object_column_width_for(_viewport._get_event_style(), str(metadata.get("lane", "")))
		if object_column_width > 0.0:
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
	_pending_display_bbcode = _display_template_has_markup(condition.provider_id, condition.ace_id)
	var base_text: String = _format_condition_descriptor_base(condition)
	var ace_note: String = str(condition.comment).strip_edges()
	if not ace_note.is_empty():
		return "%s   ⊳ %s" % [base_text, ace_note]
	return base_text


func _format_condition_descriptor_base(condition: ACECondition) -> String:
	var params_dict: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
	var generated_definition: ACEDefinition = _viewport._find_definition(condition.provider_id, condition.ace_id)
	var descriptor: ACEDescriptor = null if generated_definition != null else ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
	if generated_definition == null and descriptor == null:
		return condition.ace_id
	return _format_display_translated(generated_definition, descriptor, params_dict)


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
	_pending_display_bbcode = _display_template_has_markup(action.provider_id, action.ace_id)
	var base_text: String = _format_action_descriptor_base(action)
	var ace_note: String = str(action.comment).strip_edges()
	if not ace_note.is_empty():
		return "%s   ⊳ %s" % [base_text, ace_note]
	return base_text


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
		return action.ace_id
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
			# text, so the cell width / colour swatch / hit-test all align with what's shown. The author's
			# explicit styling supersedes the automatic value-highlight for this cell.
			span.metadata["bbcode_segments"] = EventSheetBBCodeLite.parse(text, Color.WHITE)
			span.text = EventSheetBBCodeLite.strip(text)
		else:
			var ranges: Array = _value_ranges_for(text)
			if not ranges.is_empty():
				span.metadata["value_ranges"] = ranges
	_pending_display_bbcode = false
	return span


## format_display, but the display TEMPLATE is translated FIRST (then {slots} substitute), so
## a pack-shipped translations.csv localises whole viewport sentences - "take {amount} damage"
## translates as one key and every row using it follows. Display-only: ids, params, and the
## compiled output never translate. Handles both shapes (registry ACEDefinition metadata
## templates and builtin ACEDescriptor display text); English or a missing key pass through,
## so this is byte-identical to format_display until a catalog provides the template.
func _format_display_translated(definition: ACEDefinition, descriptor: ACEDescriptor, params_dict: Dictionary) -> String:
	if definition != null:
		var template: String = EventSheetL10n.translate(str(definition.metadata.get("display_template", definition.display_name)))
		if template.is_empty():
			return EventSheetL10n.translate(definition.display_name)
		var output: String = template
		for index: int in range(definition.parameters.size()):
			var parameter: Variant = definition.parameters[index]
			if not (parameter is Dictionary):
				continue
			var key: String = str((parameter as Dictionary).get("id", ""))
			if key.is_empty():
				continue
			var fallback: Variant = (parameter as Dictionary).get("default_value", (parameter as Dictionary).get("default", ""))
			var value: Variant = params_dict.get(key, fallback)
			output = output.replace("{%d}" % index, str(value))
			output = output.replace("{%s}" % key, str(value))
		return output
	if descriptor == null:
		return ""
	var descriptor_template: String = EventSheetL10n.translate(descriptor.get_display_text())
	if descriptor_template.is_empty():
		return descriptor.ace_id
	var descriptor_output: String = descriptor_template
	for i: int in range(descriptor.params.size()):
		var param: ACEParam = descriptor.params[i]
		if param == null:
			continue
		var param_key: String = param.id if not param.id.is_empty() else param.name
		if param_key.is_empty():
			continue
		var param_value: Variant = params_dict.get(param_key, param.get_initial_value())
		descriptor_output = descriptor_output.replace("{%d}" % i, str(param_value))
		descriptor_output = descriptor_output.replace("{%s}" % param_key, str(param_value))
	return descriptor_output


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
		icon = ACEPickerDialog.category_header_icon(definition.category)
	if icon == null:
		icon = ACEPickerDialog.resolve_definition_icon(definition)
	if icon == null and is_core:
		icon = ACEPickerDialog.editor_icon("Tools")
	_ace_icon_cache[cache_key] = icon
	return icon
