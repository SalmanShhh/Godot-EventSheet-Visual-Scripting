@tool
class_name ViewportRowBuilder
extends RefCounted
# The ROW-BUILDER layer: the "model → SemanticSpans" concern for the event sheet's virtualized
# viewport. Extracted from event_sheet_viewport.gd to keep that file maintainable. This subsystem
# owns HOW each row's SemanticSpans are built from the event / variable / group / comment model —
# the span-assembly pass (_build_event_spans + its line-count twin _count_event_lines), the per-ACE
# descriptor/format/classify helpers (_format_*_descriptor, _object_label_for, _is_trigger_condition,
# …), and the non-event row builders (_build_group_row / _build_comment_row / _build_variable_row / …).
# It reads the row model, styles, fonts, fold/disabled/breakpoint state, and the ACE registry through a
# back-reference to the viewport (`_viewport.`), and calls back into the viewport for the STAY concerns
# (the recursion dispatcher _build_row_from_resource, the element-style accessors, _find_definition).
#
# The LAYOUT (assigning span.rect / lane geometry) and the DRAWING stay on the viewport — this layer
# only produces the spans; the viewport's _get_or_build_row_layout positions them and the renderer
# paints them. Span construction must stay byte-identical to the pre-extraction code, so the bodies
# below were moved VERBATIM — only member access was rewritten to go through `_viewport.` (the span/
# descriptor logic itself is unchanged, including the `.merged(style_meta, false/true)` overwrite flags,
# the condition/action line-index accounting that _count_event_lines mirrors, and the same-object
# _ace_icon_cache / _value_regex caching).
#
# `_pending_display_bbcode` is PRIVATE to this layer: its writers (_format_condition_descriptor /
# _format_action_descriptor) set it on the line immediately before their _make_span call, and its sole
# reader (_make_span) consumes + clears it — all three live here, so the one-shot flag never needs to
# cross the viewport boundary on the real render path. (The viewport keeps a tiny same-named bridge var
# used ONLY by its _make_span delegate, so bbcode_and_pill_test — which pokes the flag then calls the
# delegate — needs no edit; the render path never touches that bridge.)
#
# `_value_ranges_for` + `_value_regex` are STATIC (pure text → ranges), so they stay unit-testable
# without a live viewport; the viewport keeps a static forwarder for any class-name caller.

var _viewport: Control = null

func init(viewport: Control) -> void:
	_viewport = viewport

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
		_make_span("class_name, host binding & annotations — %d lines" % line_total, SemanticSpan.SpanType.COMMENT, {
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
			label,
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

## The sheet's functions as visible rows — one foldable "Published verbs" section whose children are
## Define blocks, one per EventFunction. Functions live in `sheet.functions`, a SEPARATE array from
## `sheet.events`, so without this they never appear on the canvas at all: a behaviour pack's whole
## vocabulary (its actions/conditions/expressions) was invisible until you opened the Functions dialog.
## This is a pure READ view — it never writes to either array and never affects codegen — so the
## byte-exact round-trip of the underlying .gd is untouched. Folded by default with a fingerprint
## ("⚡2 · ?1 · ƒx3") so a pack still tells its vocabulary weight at a glance, like a collapsed group.
func _build_published_verbs_rows(sheet: EventSheetResource) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	if sheet == null or sheet.functions.is_empty():
		return rows
	var children: Array[EventRowData] = []
	var counts: Dictionary = {"action": 0, "condition": 0, "expression": 0, "internal": 0}
	for entry: Variant in sheet.functions:
		if not (entry is EventFunction):
			continue
		var event_function: EventFunction = entry as EventFunction
		var role: String = define_role_for(event_function)
		if event_function.expose_as_ace:
			counts[role] = int(counts[role]) + 1
		else:
			counts["internal"] = int(counts["internal"]) + 1
		children.append(_build_define_function_row(event_function, 1))
	if children.is_empty():
		return rows
	var header := EventRowData.new()
	header.indent = 0
	header.row_type = EventRowData.RowType.SECTION
	header.source_resource = null  # inert for selection/delete, like the add-event footer
	header.row_uid = "published_verbs_%d" % sheet.get_instance_id()
	header.children = children
	header.folded = bool(_viewport._fold_state.get(header.row_uid, true))
	var fingerprint_parts: PackedStringArray = PackedStringArray()
	if int(counts["action"]) > 0:
		fingerprint_parts.append("⚡%d" % int(counts["action"]))
	if int(counts["condition"]) > 0:
		fingerprint_parts.append("?%d" % int(counts["condition"]))
	if int(counts["expression"]) > 0:
		fingerprint_parts.append("ƒx%d" % int(counts["expression"]))
	if int(counts["internal"]) > 0:
		fingerprint_parts.append("%d internal" % int(counts["internal"]))
	header.spans = [
		_make_span("Published verbs", SemanticSpan.SpanType.KEYWORD, {
			"editable": false,
			"badge": true,
			"badge_style": "scope",
			"badge_bg": EventSheetPalette.COLOR_SETUP_BADGE_BG,
			"badge_fg": EventSheetPalette.COLOR_SECTION_BADGE_FG,
			"kind": "published_verbs",
			"line_index": 0
		}),
		_make_span(" · ".join(fingerprint_parts), SemanticSpan.SpanType.COMMENT, {
			"editable": false,
			"kind": "published_verbs",
			"text_color": Color(EventSheetPalette.TEXT_MUTED.r, EventSheetPalette.TEXT_MUTED.g, EventSheetPalette.TEXT_MUTED.b, 0.8)
		})
	]
	rows.append(header)
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

## One Define block: role badge in its ACE-role colour, the friendly published name, a `→ type`
## chip for value-returning verbs, the category chip, an "internal" chip when the function is NOT
## exposed as an ACE (a plain helper other sheets can't pick), and the muted real signature built
## by the COMPILER's own emitters — so what the row claims can never disagree with codegen.
func _build_define_function_row(event_function: EventFunction, indent: int) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = event_function
	row_data.row_uid = "define_fn_%d" % event_function.get_instance_id()
	row_data.disabled = not event_function.enabled
	var role: String = define_role_for(event_function)
	var badge_colors: Dictionary = {
		"action": [EventSheetPalette.COLOR_ACE_ACTION_BADGE_BG, EventSheetPalette.COLOR_ACE_ACTION_BADGE_FG],
		"condition": [EventSheetPalette.COLOR_ACE_CONDITION_BADGE_BG, EventSheetPalette.COLOR_ACE_CONDITION_BADGE_FG],
		"expression": [EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_BG, EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_FG],
	}
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
		}),
		_make_span(display_name, SemanticSpan.SpanType.OBJECT, {
			"kind": "define_function",
			"text_color": _viewport._get_event_style().object_label_color
		})
	]
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
	return row_data

## First Color(...) literal among an ACE's param values (null when none) — drives the
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
	var badge_text: String = kind.title if kind != null else "block"
	var summary_text: String = kind.summary(block) if kind != null else block.kind_id
	row_data.spans = [
		_make_span(
			badge_text,
			SemanticSpan.SpanType.KEYWORD,
			{"badge": true, "text_color": event_style.behavior_accent_color}
		),
		_make_span(
			summary_text,
			SemanticSpan.SpanType.VALUE,
			{"kind": "custom_block_row", "text_color": event_style.object_label_color}
		)
	]
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
	# "declare a trigger ACE" block, NOT raw scaffolding: it renders like a Variable row — a "trigger"
	# badge, the friendly ACE name, an optional category chip — with the underlying `signal …` declaration
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
## host-binding `_enter_tree` — the boilerplate every host-targeting behaviour pack emits to bind
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

## True Define-shell info for a RawCodeRow that is PURELY an `## @ace_*` annotation block — the
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
			return {}  # real code in the row — not a pure annotation shell
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

## A GDScript block row: verbatim code shown line-by-line, edited via the dock's code dialog
## (double-click), compiled at class level. The event-sheet-style "inline code" escape hatch.
## A row that is purely a published-verb annotation shell renders as ONE Define-style header line
## instead (role badge · friendly name · category chip) — a pure view over the same RawCodeRow, so
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
		row_data.line_count = 1
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
			_make_span("acts on the host node · get_parent() as %s" % host_class, SemanticSpan.SpanType.VALUE, {
				"editable": false,
				"kind": "raw_code",
				"line_index": 0,
				"text_color": EventSheetPalette.TEXT_MUTED
			})
		]
		return row_data
	var shell: Dictionary = define_shell_info(raw_row.code)
	if not shell.is_empty():
		row_data.line_count = 1  # visual collapse only — the underlying lines are all still there
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
	var code_lines: PackedStringArray = raw_row.code.split("\n")
	row_data.line_count = maxi(code_lines.size(), 1)
	# Type-aware styling: boilerplate reads dimmer + labelled "setup" so the eye skips it,
	# while real logic keeps the brighter "GDScript" badge + primary text. Same row, no codegen change.
	var is_scaffold: bool = _viewport.is_scaffolding_code(raw_row.code)
	var badge_label: String = "setup" if is_scaffold else "GDScript"
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
	# template"). Surface it as an inline amber badge — the actionable "why this stayed code" cue — in
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

## Builds a row for a variable placed directly in the event tree (movable like an event).
func _build_tree_variable_row(variable: LocalVariable, indent: int) -> EventRowData:
	return _build_variable_row(
		"tree",
		variable.name,
		variable.type_name,
		variable.default_value,
		indent,
		{
			"is_constant": variable.is_constant,
			"exported": variable.exported,
			# Inspector grouping (@export_group/@export_subgroup) recovered onto the variable on import —
			# shown as the "Group › Subgroup" chip, so a reopened grouped variable still reads as grouped.
			"group": str((variable.attributes as Dictionary).get("group", "")) if variable.exported and variable.attributes is Dictionary else "",
			"subgroup": str((variable.attributes as Dictionary).get("subgroup", "")) if variable.exported and variable.attributes is Dictionary else "",
			"source_resource": variable,
			"row_uid": "variable_tree_%d" % variable.get_instance_id()
		}
	)

## A group's chapter fingerprint: "N events · ⟳a · ➜b · ⌨c · ▶d · ⚠e" — its child events
## counted by trigger TEMPO class (reusing TriggerResolver.tempo_class_for) plus the RawCode (⚠) blocks
## inside, so a collapsed group still shows its weight + hotness. Recurses nested groups/sub-events.
## Static + pure → unit-testable; "" when the group holds no events or code.
static func group_fingerprint(group: EventGroup) -> String:
	if group == null:
		return ""
	var counts: Dictionary = {"events": 0, "every_tick": 0, "signal": 0, "input": 0, "once": 0, "raw": 0}
	_fingerprint_rows(group.events if not group.events.is_empty() else group.rows, counts)
	if int(counts["events"]) == 0 and int(counts["raw"]) == 0:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	parts.append("%d event%s" % [int(counts["events"]), "" if int(counts["events"]) == 1 else "s"])
	if int(counts["every_tick"]) > 0:
		parts.append("⟳%d" % int(counts["every_tick"]))
	if int(counts["signal"]) > 0:
		parts.append("➜%d" % int(counts["signal"]))
	if int(counts["input"]) > 0:
		parts.append("⌨%d" % int(counts["input"]))
	if int(counts["once"]) > 0:
		parts.append("▶%d" % int(counts["once"]))
	if int(counts["raw"]) > 0:
		parts.append("⚠%d" % int(counts["raw"]))
	return " · ".join(parts)

static func _fingerprint_rows(rows: Array, counts: Dictionary) -> void:
	for row: Variant in rows:
		if row is EventRow:
			var event_row: EventRow = row as EventRow
			counts["events"] = int(counts["events"]) + 1
			# Only triggered rows carry a tempo (sub-events / else rows are still events, just untimed).
			if not event_row.trigger_id.is_empty() or event_row.trigger != null:
				var tempo: String = TriggerResolver.tempo_class_for(event_row.trigger_id)
				counts[tempo] = int(counts.get(tempo, 0)) + 1
			for action: Variant in event_row.actions:
				if action is RawCodeRow and not (action as RawCodeRow).code.strip_edges().is_empty():
					counts["raw"] = int(counts["raw"]) + 1
			_fingerprint_rows(event_row.sub_events, counts)
		elif row is RawCodeRow:
			if not (row as RawCodeRow).code.strip_edges().is_empty():
				counts["raw"] = int(counts["raw"]) + 1
		elif row is EventGroup:
			var nested: EventGroup = row as EventGroup
			_fingerprint_rows(nested.events if not nested.events.is_empty() else nested.rows, counts)

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
	# already reads unmistakably as a group, so the old leading "Group" text badge was pure clutter —
	# the header is now just the inline-editable title (plus an optional description line).
	row_data.spans = [
		_make_span(
			_viewport._group_name(group),
			SemanticSpan.SpanType.OBJECT,
			{
				"editable": true,
				"edit_kind": "group_name",
				"group_title": true,
				"text_color": event_style.group_title_color
			}
		)
	]
	# Chapter fingerprint: a muted trailing span on the header line — child events by tempo
	# class + ⚠-code blocks — so a COLLAPSED group still tells you its weight + hotness (fold-all becomes
	# a real table of contents). Flows after the title on line 0, so it survives fold.
	var fingerprint: String = group_fingerprint(group)
	if not fingerprint.is_empty():
		row_data.spans.append(
			_make_span(
				fingerprint,
				SemanticSpan.SpanType.COMMENT,
				{
					"editable": false,
					"hoverable": false,
					"line_index": 0,
					"font_size_delta": -1,
					"text_color": EventSheetPalette.TEXT_MUTED
				}
			)
		)
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
	return row_data

func _build_global_variable_rows(sheet: EventSheetResource) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	if sheet == null:
		return rows
	var names: Array = sheet.variables.keys()
	# Ungrouped variables first (name-sorted), then each Inspector group as a contiguous block —
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
					# The Inspector group (@export_group) this exported var lands in — shown as a chip on the
					# row so it's obvious in the sheet which vars share an Inspector section. Only meaningful
					# for exported vars (the compiler emits @export_group for those).
					"group": str(var_attributes.get("group", "")) if is_exported else "",
					"subgroup": str(var_attributes.get("subgroup", "")) if is_exported else ""
				}
			)
		)
	return rows

## An exported global's Inspector group ("" when none/unexported) — the adjacency-sort key above.
static func _global_variable_group(sheet: EventSheetResource, var_name: String) -> String:
	var descriptor: Variant = sheet.variables.get(var_name, {})
	if not (descriptor is Dictionary):
		return ""
	if not bool((descriptor as Dictionary).get("exported", (descriptor as Dictionary).get("exposed", true))):
		return ""
	var attributes: Variant = (descriptor as Dictionary).get("attributes")
	return str((attributes as Dictionary).get("group", "")).strip_edges() if attributes is Dictionary else ""

## Runs of consecutive variable rows sharing one Inspector group — the bubbles the viewport outlines
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
		# The Inspector group rides in the row metadata (not just the chip) so the grouping gestures —
		# the drag-into-folder drop, the bubble outline, chip-rename — can read it without re-lookup.
		"variable_group": str(options.get("group", "")).strip_edges()
	}
	# No scope pill: it confused users. The "global"/"sheet" pill was already redundant (every sheet/class
	# variable is one), and the "local" pill on event-scoped vars read as noise too — scope is obvious from
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
	# so it reads at a glance which sheet variables share an Inspector group — the "group them in the sheet"
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

## Sets the tempo glyph + hue on a trigger-badge meta from the event's trigger_id, and returns the glyph.
## SIGNAL keeps the shipped green ➜ from the event style — the common case stays
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
	if event_row.else_mode == EventRow.ElseMode.ELSE:
		spans.append(
			_make_span(
				"Else",
				SemanticSpan.SpanType.KEYWORD,
				{
					"lane": "condition",
					"kind": "else_keyword",
					"badge": true,
					"hoverable": false,
					"line_index": condition_line_index
				}.merged(condition_style_meta, true)
			)
		)
		condition_line_index += 1
	elif event_row.else_mode == EventRow.ElseMode.ELIF:
		spans.append(
			_make_span(
				"Else If",
				SemanticSpan.SpanType.KEYWORD,
				{
					"lane": "condition",
					"kind": "else_keyword",
					"badge": true,
					"hoverable": false,
					"line_index": condition_line_index
				}.merged(condition_style_meta, true)
			)
		)
	if event_row.trigger != null:
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
	elif not event_row.trigger_id.is_empty():
		var trigger_id_badge_meta: Dictionary = _viewport.BADGE_TRIGGER_METADATA.duplicate(true)
		# Same tempo badge on the lifted / lifecycle path (trigger_id with no authored ACECondition) —
		# this is where On Physics Process etc. render, so the ⟳ hot-path glyph lands here too.
		var trigger_id_glyph: String = _apply_trigger_tempo(trigger_id_badge_meta, event_style, event_row.trigger_id)
		trigger_id_badge_meta["badge_extra_width"] = condition_style_meta.get("badge_extra_width", _viewport.BADGE_EXTRA_WIDTH)
		trigger_id_badge_meta["line_index"] = condition_line_index
		trigger_id_badge_meta["badge_style"] = "trigger"
		spans.append(_make_span(trigger_id_glyph, SemanticSpan.SpanType.KEYWORD, trigger_id_badge_meta))
		spans.append(
			_make_span(
				event_row.trigger_id,
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
	elif inline_trigger_condition_index >= 0 and inline_trigger_condition_index < event_row.conditions.size():
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
				"Every Tick",
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
							"swatch_color": _first_color_in_params(action_resource)
						}.merged(action_style_meta, true)
					)
				)
				action_line_index += 1
			elif action_resource is MatchRow:
				# match statement (the switch): header + branch lines as action cells
				# sharing one ace_index; double-click opens the match dialog.
				var match_resource: MatchRow = action_resource as MatchRow
				var match_lines: PackedStringArray = PackedStringArray(["match %s:" % match_resource.match_expression])
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
								"action_line": match_line_index,
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
								# (left stripe, continuous background) — per-line
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
								# lane reads like its sibling cells — comment text
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
			"+ Add action",
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
	# Condition lane.
	var condition_lines: int = 0
	if event_row.else_mode == EventRow.ElseMode.ELSE:
		condition_lines += 1
	var inline_trigger_index: int = _find_inline_trigger_condition_index(event_row)
	var has_trigger: bool = (
		event_row.trigger != null
		or not event_row.trigger_id.is_empty()
		or (inline_trigger_index >= 0 and inline_trigger_index < event_row.conditions.size())
	)
	if has_trigger:
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
	var max_condition_line: int = maxi(condition_lines - 1, 0)
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
			action_count += (action_resource as MatchRow).branches_text.split("\n").size() + 1
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
	# A call to a sheet Function is an abstraction you CREATED (e.g. via Extract to Function) — show it as
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

## A call to a sheet Function — the row IS an abstraction (a named verb), so the renderer marks it "ƒ"
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
	if generated_definition != null:
		return generated_definition.format_display(params_dict)
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
	if descriptor == null:
		return condition.ace_id
	return descriptor.format_display(params_dict)

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
	if generated_definition != null:
		return generated_definition.format_display(params_dict)
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(action.provider_id, action.ace_id)
	if descriptor == null:
		return action.ace_id
	return descriptor.format_display(params_dict)

# ── Row-as-sentence hover ───────────────────────────────────────────────────────────
const _SENTENCE_MAX_ACTIONS := 3
## Friendly lead phrases for the lifecycle trigger ids — the tempo triggers read as a cadence, not a
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

## The whole event read as ONE plain-English sentence for the hover tooltip — "When <trigger> — if <c1>
## and <c2> — do: <a1>, <a2> (+1 more)". Assembled EXCLUSIVELY from the same descriptor strings the cells
## draw (the _base formatters, which don't touch the bbcode render flag), so it can NEVER disagree with
## the row. In-flow RawCode actions have no descriptor, so they summarise honestly as "then N lines of
## code" — the sentence never invents prose for raw statements. "" when there is nothing to say.
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
	return " — ".join(clauses)

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
## tint can never disagree with the highlight. The trailing kind is additive — consumers that read only
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
# into a _make_span call) when the ACE's display TEMPLATE carries BBCode markup — i.e. the author opted into
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
			# The author's display TEMPLATE carried markup — parse to styled segments and draw the STRIPPED
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

## True when an ACE's display TEMPLATE (not the substituted text) carries BBCode markup — the author opted
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
	var cache_key: String = "%s::%s" % [provider_id, ace_id]
	if _ace_icon_cache.has(cache_key):
		return _ace_icon_cache[cache_key]
	var definition: ACEDefinition = _viewport._find_definition(provider_id, ace_id)
	if definition == null and not (provider_id.is_empty() or provider_id == "Core"):
		# Not cached: the registry refreshes in place (addons may not be loaded yet when
		# the first spans build), so a miss now can become a hit on the next rebuild.
		return null
	var icon: Texture2D = ACEPickerDialog.resolve_definition_icon(definition)
	if icon == null and (provider_id.is_empty() or provider_id == "Core"):
		icon = ACEPickerDialog.editor_icon("Tools")
	_ace_icon_cache[cache_key] = icon
	return icon
