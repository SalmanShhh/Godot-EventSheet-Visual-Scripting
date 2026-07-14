# EventForge - Define-block rendering: the sheet's functions (its verbs) appear on the canvas as INLINE
# role-tinted Define rows, one per EventFunction, at root level (no "Published verbs" section wrapper) - so
# a sheet reads top-to-bottom like a code file. Functions live in sheet.functions, a SEPARATE array from
# sheet.events, so before this view a behaviour pack's whole vocabulary was invisible outside the Functions
# dialog. Pins: the role classification (void=Action / bool=Condition / typed=Expression, mirroring the ACE
# Studio cards), the badge/chip spans, the compiler-bound signature line, the inline-at-root layout, and -
# covenant-critical - that the view is a pure READ (opening a real pack still round-trips byte-identically).
@tool
class_name DefineBlockRowsTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── A sheet with one verb of each kind + one internal helper ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.functions.append(_make_function("take_damage", TYPE_NIL, true, "Take Damage", "Health"))
	sheet.functions.append(_make_function("is_dead", TYPE_BOOL, true, "", ""))
	sheet.functions.append(_make_function("health_percent", TYPE_FLOAT, true, "Health %", ""))
	sheet.functions.append(_make_function("recalc_cache", TYPE_NIL, false, "", ""))

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()

	# ── Inline: one Define row per function, at root level, NOT hidden behind a section header ──
	var define_rows: Array[EventRowData] = _find_rows_by_uid_prefix(view, "define_fn_")
	ok = _check("one inline Define row per function", define_rows.size(), 4) and ok
	ok = _check("no 'Published verbs' section wrapper remains",
		_find_row_by_uid_prefix(view, "published_verbs_") == null, true) and ok
	ok = _check("the inline verb rows sit at root indent",
		define_rows[0].indent if define_rows.size() > 0 else -1, 0) and ok
	ok = _check("the verbs render in sheet order (take_damage first)",
		_span_text(define_rows[0] if define_rows.size() > 0 else null, 1), "Take Damage") and ok

	# ── Role classification mirrors the ACE Studio cards ──
	ok = _check("void → action", ViewportRowBuilder.define_role_for(_make_function("f", TYPE_NIL, true, "", "")), "action") and ok
	ok = _check("bool → condition", ViewportRowBuilder.define_role_for(_make_function("f", TYPE_BOOL, true, "", "")), "condition") and ok
	ok = _check("float → expression", ViewportRowBuilder.define_role_for(_make_function("f", TYPE_FLOAT, true, "", "")), "expression") and ok

	# ── The Define rows themselves, in sheet order ──
	var action_row: EventRowData = define_rows[0] if define_rows.size() > 0 else null
	var condition_row: EventRowData = define_rows[1] if define_rows.size() > 1 else null
	var expression_row: EventRowData = define_rows[2] if define_rows.size() > 2 else null
	var internal_row: EventRowData = define_rows[3] if define_rows.size() > 3 else null
	ok = _check("action badge", _span_text(action_row, 0), "Action") and ok
	ok = _check("display name prefers @ace_name", _span_text(action_row, 1), "Take Damage") and ok
	ok = _check("category chip rides along", _row_has_span_text(action_row, "Health"), true) and ok
	ok = _check("an action has NO return chip", _row_has_span_text(action_row, "→ void"), false) and ok
	ok = _check("condition badge", _span_text(condition_row, 0), "Condition") and ok
	ok = _check("condition name falls back to the humanized function name", _span_text(condition_row, 1), "Is Dead") and ok
	ok = _check("condition carries the → bool chip", _row_has_span_text(condition_row, "→ bool"), true) and ok
	ok = _check("expression carries its typed chip", _row_has_span_text(expression_row, "→ float"), true) and ok
	ok = _check("an un-exposed helper is marked internal", _row_has_span_text(internal_row, "internal"), true) and ok
	ok = _check("an exposed verb is NOT marked internal", _row_has_span_text(action_row, "internal"), false) and ok
	ok = _check("the signature line is the compiler's own emission",
		_row_has_span_text(action_row, "func take_damage(amount: float) -> void"), true) and ok

	# ── The readable verb line: reads like an event-sheet action, with the real signature kept as a
	# muted code cue below. Auto-derives the friendly param labels; an authored @ace_display_template
	# fills its slots with those labels (a Define row shows the verb's shape, not call-site values).
	ok = _check("the auto verb line lists the friendly param labels next to the name",
		_row_has_span_text(action_row, "amount"), true) and ok
	ok = _check("params humanize the id (underscores open out)",
		ViewportRowBuilder.friendly_param_labels(_two_param_function()), "from x, to x") and ok
	var templated: EventFunction = _make_function("draw_line", TYPE_NIL, true, "Draw Line", "")
	templated.params[0].id = "from_x"
	templated.display_template = "Line to {from_x}"
	ok = _check("an authored template fills its slots with param labels",
		ViewportRowBuilder.friendly_template_line(templated), "Line to from x") and ok
	ok = _check("no template yields an empty authored line (auto path used)",
		ViewportRowBuilder.friendly_template_line(_make_function("f", TYPE_NIL, true, "", "")), "") and ok

	# ── A function-less sheet grows no verb rows ──
	var empty_dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	empty_dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	empty_dock.setup(EventSheetResource.new())
	ok = _check("no functions → no verb rows", _find_row_by_uid_prefix(empty_dock._active_view(), "define_fn_") == null, true) and ok
	empty_dock.free()

	# ── Covenant: the view is a pure read - opening a REAL pack still round-trips byte-identically.
	# Since the per-function shell-lift, an opened pack's verbs arrive as REAL EventFunctions, so its
	# verbs render inline too - one Define row per lifted function.
	var pack_path: String = "res://eventsheet_addons/health/health_behavior.gd"
	var source: String = (FileAccess.open(pack_path, FileAccess.READ)).get_as_text()
	dock._load_sheet_from_path(pack_path)  # the real user open path (verify-lift included)
	var opened: EventSheetResource = dock.get_current_sheet()
	ok = _check("an opened pack lifts real functions", opened.functions.size() > 20, true) and ok
	var pack_rows: Array[EventRowData] = _find_rows_by_uid_prefix(dock._active_view(), "define_fn_")
	ok = _check("the pack shows its verbs inline - one row per lifted function",
		pack_rows.size(), opened.functions.size()) and ok
	var reemitted: String = str(SheetCompiler.compile(opened, pack_path).get("output", ""))
	ok = _check("round-trip stays byte-identical with the view built (drift=0)", reemitted == source, true) and ok

	# ── Phase 1: a verb's BODY renders as foldable child rows, and every body row is INERT (source_resource
	# nulled over the subtree) so no selection / drag / delete / inline edit can reach it. Their resources
	# live in event_function.events, NOT sheet.events - the read-only gate that keeps the covenant.
	var body_roots: Array = []
	for header_row: EventRowData in pack_rows:
		body_roots.append_array(header_row.children)
	var body_check: Array = _count_and_check_inert(body_roots)
	var body_rows_built: int = int(body_check[0])
	var all_body_inert: bool = bool(body_check[1])
	ok = _check("lifted functions render their body as child rows", body_rows_built > 0, true) and ok
	ok = _check("every function-body row is inert (source nulled - no drag/delete/edit reaches it)", all_body_inert, true) and ok
	# Anti-aliasing at the MODEL level: a function's body resources are never also in sheet.events, so a
	# body row can never be moved/emitted into the sheet (the exact corruption the gate + _move_rows fix stop).
	var body_leaked: bool = false
	for entry: Variant in opened.functions:
		if entry is EventFunction:
			for body_res: Variant in (entry as EventFunction).events:
				if opened.events.has(body_res):
					body_leaked = true
	ok = _check("function-body resources are NOT aliased into sheet.events", body_leaked, false) and ok
	# Expanding every body is still a pure read: unfold all verb headers, rebuild, re-emit byte-identically.
	var pack_view: EventSheetViewport = dock._active_view()
	for header_row: EventRowData in pack_rows:
		if not header_row.children.is_empty():
			pack_view._fold_state[header_row.row_uid] = false
	pack_view.set_sheet(opened)
	var reemitted_expanded: String = str(SheetCompiler.compile(dock.get_current_sheet(), pack_path).get("output", ""))
	ok = _check("expanding every function body is still read-only (byte-identical)", reemitted_expanded == source, true) and ok

	dock.free()
	return ok


## Returns [count, all_inert] over the whole subtree rooted at `rows` - every function-body row and its
## descendants must be inert (source_resource == null) so no selection / drag / delete / inline edit
## reaches them; a reveal that leaves one editable is caught.
static func _count_and_check_inert(rows: Array) -> Array:
	var count: int = 0
	var inert: bool = true
	for entry: Variant in rows:
		var row_data: EventRowData = entry
		if row_data == null:
			continue
		count += 1
		if row_data.source_resource != null:
			inert = false
		var sub: Array = _count_and_check_inert(row_data.children)
		count += int(sub[0])
		if not bool(sub[1]):
			inert = false
	return [count, inert]


static func _make_function(fn_name: String, return_type: int, exposed: bool, display: String, category: String) -> EventFunction:
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = fn_name
	event_function.return_type = return_type
	event_function.expose_as_ace = exposed
	event_function.ace_display_name = display
	event_function.ace_category = category
	var param: ACEParam = ACEParam.new()
	param.id = "amount"
	param.type_name = "float"
	event_function.params.append(param)
	return event_function


static func _two_param_function() -> EventFunction:
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = "draw"
	for pid: String in ["from_x", "to_x"]:
		var param: ACEParam = ACEParam.new()
		param.id = pid
		param.type_name = "float"
		event_function.params.append(param)
	return event_function


static func _find_row_by_uid_prefix(view: EventSheetViewport, prefix: String) -> EventRowData:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.row_uid.begins_with(prefix):
			return row_data
	return null


static func _find_rows_by_uid_prefix(view: EventSheetViewport, prefix: String) -> Array[EventRowData]:
	var found: Array[EventRowData] = []
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.row_uid.begins_with(prefix):
			found.append(row_data)
	return found


static func _span_text(row_data: EventRowData, index: int) -> String:
	if row_data == null or index >= row_data.spans.size():
		return ""
	return str(row_data.spans[index].text)


static func _row_has_span_text(row_data: EventRowData, needle: String) -> bool:
	if row_data == null:
		return false
	for span: SemanticSpan in row_data.spans:
		if str(span.text) == needle:
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] define_block_rows_test: %s" % label)
		return true
	print("[FAIL] define_block_rows_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
