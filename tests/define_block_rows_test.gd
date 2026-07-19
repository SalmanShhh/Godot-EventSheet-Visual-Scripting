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
	ok = _check("a void action gives nothing back (no return chip)", _row_has_span_text(condition_row, "gives back yes/no") and not _row_has_span_text(action_row, "gives back"), true) and ok
	ok = _check("condition badge", _span_text(condition_row, 0), "Condition") and ok
	ok = _check("condition name falls back to the humanized function name", _span_text(condition_row, 1), "Is Dead") and ok
	ok = _check("condition reads its return in plain words (bool -> yes/no)", _row_has_span_text(condition_row, "gives back yes/no"), true) and ok
	ok = _check("expression reads its return in plain words (float -> number)", _row_has_span_text(expression_row, "gives back number"), true) and ok
	ok = _check("an un-exposed helper is marked internal", _row_has_span_text(internal_row, "internal"), true) and ok
	ok = _check("an exposed verb is NOT marked internal", _row_has_span_text(action_row, "internal"), false) and ok
	# The abstraction covenant: NO raw `func ... -> Type` signature leaks into the row - a reader with no
	# GDScript knowledge sees the verb and its inputs, never the code.
	ok = _check("no raw func signature leaks into the row",
		_row_has_span_text(action_row, "func take_damage"), false) and ok

	# ── The readable verb line: reads like an event-sheet action - the verb name plus first-class typed
	# parameter chips (`name : friendly-type`), no raw signature. An authored @ace_display_template fills
	# its slots with the friendly labels instead (a Define row shows the verb's shape, not call-site values).
	ok = _check("params render as first-class typed chips (name : friendly-type)",
		_row_has_span_text(action_row, "amount") and _row_has_span_text(action_row, " : number"), true) and ok
	ok = _check("params humanize the id (underscores open out)",
		ViewportRowBuilder.friendly_param_labels(_two_param_function()), "from x, to x") and ok
	# GDScript types read as plain words so a non-coder learns what each input is.
	ok = _check("String reads as text", ViewportRowBuilder.friendly_type_word("String"), "text") and ok
	ok = _check("int/float read as number", ViewportRowBuilder.friendly_type_word("int"), "number") and ok
	ok = _check("bool reads as yes/no", ViewportRowBuilder.friendly_type_word("bool"), "yes/no") and ok
	ok = _check("a node class passes through", ViewportRowBuilder.friendly_type_word("Sprite2D"), "Sprite2D") and ok
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

	# ── Phase 2 (slice 2a): on an AUTHORED sheet (no external_source_path, not read-only) a published verb's
	# body is LIVE and editable - the OPPOSITE of the opened pack above. The body rows keep their
	# source_resource (selectable / deletable / inline-editable), and _find_resource_location resolves them
	# into event_function.events, so an edit lands in the verb's own body, never aliased into sheet.events.
	var authored_sheet: EventSheetResource = EventSheetResource.new()
	authored_sheet.host_class = "Node2D"
	var editable_fn: EventFunction = _make_function("on_hit", TYPE_NIL, true, "On Hit", "Combat")
	var body_block: RawCodeRow = RawCodeRow.new()
	body_block.code = "print(\"ouch\")"
	editable_fn.events.append(body_block)
	authored_sheet.functions.append(editable_fn)

	var authored_dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	authored_dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	authored_dock.setup(authored_sheet)
	var authored_view: EventSheetViewport = authored_dock._active_view()
	var authored_define: EventRowData = _find_row_by_uid_prefix(authored_view, "define_fn_on_hit")
	ok = _check("the authored verb renders a Define row", authored_define != null, true) and ok
	var live_body: EventRowData = authored_define.children[0] if authored_define != null and not authored_define.children.is_empty() else null
	ok = _check("an AUTHORED sheet's verb body is LIVE (source_resource kept - editable)",
		live_body != null and live_body.source_resource != null, true) and ok

	# The live body row resolves into the FUNCTION'S events array (not sheet.events), so a delete / insert /
	# drag routed through the undo funnel edits the verb's body rather than the main event loop.
	var live_body_res: Resource = live_body.source_resource if live_body != null else null
	var located: Dictionary = authored_dock._find_resource_location(live_body_res)
	ok = _check("a live body row resolves via the function-body search (found, not in sheet.events)",
		not located.is_empty() and located.get("container", []) != authored_dock.get_current_sheet().events, true) and ok
	ok = _check("the resolved container is the verb's own body and holds the row",
		(located.get("container", []) as Array).has(live_body_res), true) and ok
	ok = _check("the body row is NOT aliased into sheet.events (main loop stays empty)",
		authored_dock.get_current_sheet().events.size(), 0) and ok

	# End-to-end: an undoable edit that locates the body row through the function-body search and removes it
	# lands in event_function.events - proven by re-fetching the verb BY NAME after the funnel commit (the
	# commit snapshot-duplicates the sheet, so the pre-edit reference is stale) and re-compiling: the body's
	# code vanishes from the output. This is exactly the mechanism delete / insert / drag rely on.
	var output_before: String = str(SheetCompiler.compile(authored_dock.get_current_sheet(), "").get("output", ""))
	ok = _check("the authored verb body compiles into the function (print present)",
		output_before.contains("print(\"ouch\")"), true) and ok
	var edit_ok: bool = authored_dock._perform_undoable_sheet_edit("Delete Verb Body Row", func() -> bool:
		var loc: Dictionary = authored_dock._find_resource_location(live_body_res)
		if loc.is_empty():
			return false
		(loc.get("container") as Array).remove_at(int(loc.get("index")))
		return true
	)
	ok = _check("the funnel accepts a body-row edit located via the function-body search", edit_ok, true) and ok
	var refetched_fn: EventFunction = _find_function_by_name(authored_dock.get_current_sheet(), "on_hit")
	ok = _check("re-fetched by name after the commit, the verb body lost the deleted row",
		refetched_fn != null and refetched_fn.events.is_empty(), true) and ok
	var output_after: String = str(SheetCompiler.compile(authored_dock.get_current_sheet(), "").get("output", ""))
	ok = _check("the deleted body row is gone from the recompiled output (round-trips)",
		output_after.contains("print(\"ouch\")"), false) and ok
	authored_dock.free()

	# ── Phase 2 (slice 2a) safety on the editable path: a verb body is one tree, the main event list another.
	# Adding an event with a verb HEADER selected grows THAT verb's body (even an empty one), never the main
	# loop; and a drag may reorder within a tree but is refused across trees (no main event into a verb body,
	# no body row aliased into sheet.events - which would emit unintended code / corrupt the round-trip).
	var guard_sheet: EventSheetResource = EventSheetResource.new()
	guard_sheet.host_class = "Node2D"
	var main_event: EventRow = EventRow.new()
	guard_sheet.events.append(main_event)
	var verb_with_body: EventFunction = _make_function("tick", TYPE_NIL, true, "Tick", "")
	var verb_body_block: RawCodeRow = RawCodeRow.new()
	verb_body_block.code = "pass"
	verb_with_body.events.append(verb_body_block)
	guard_sheet.functions.append(verb_with_body)
	guard_sheet.functions.append(_make_function("reset", TYPE_NIL, true, "Reset", ""))

	var guard_dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	guard_dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	guard_dock.setup(guard_sheet)
	var guard_view: EventSheetViewport = guard_dock._active_view()

	# F2: adding an event on the EMPTY verb's header lands in that verb's body, growing its first row -
	# not leaking into the main event loop.
	var live_empty_verb: EventFunction = _find_function_by_name(guard_dock.get_current_sheet(), "reset")
	var new_body_row: EventRow = EventRow.new()
	guard_dock._insert_row_below_selection(new_body_row, live_empty_verb)
	ok = _check("adding on an authored verb HEADER grows that verb's body (empty body's first row)",
		live_empty_verb != null and live_empty_verb.events.has(new_body_row), true) and ok
	ok = _check("the header-anchored add did NOT leak into the main event loop",
		guard_dock.get_current_sheet().events.has(new_body_row), false) and ok

	# F1: dragging the verb's live body row onto the main event row is refused (cross-tree), so the body row
	# stays in event_function.events and is never aliased into sheet.events.
	var live_verb: EventFunction = _find_function_by_name(guard_dock.get_current_sheet(), "tick")
	var live_verb_define: EventRowData = _find_row_by_uid_prefix(guard_view, "define_fn_tick")
	var body_row_data: EventRowData = live_verb_define.children[0] if live_verb_define != null and not live_verb_define.children.is_empty() else null
	var target_row_data: EventRowData = EventRowData.new()
	target_row_data.source_resource = guard_dock.get_current_sheet().events[0]
	if body_row_data != null:
		guard_dock._move_rows([body_row_data], target_row_data, "after", false)
	var dragged_res: Resource = body_row_data.source_resource if body_row_data != null else null
	ok = _check("a cross-tree drag (verb body -> main loop) is refused: body row stays in the verb",
		live_verb != null and live_verb.events.has(dragged_res), true) and ok
	ok = _check("the refused drag did NOT alias the body row into sheet.events",
		guard_dock.get_current_sheet().events.has(dragged_res), false) and ok
	guard_dock.free()

	return ok


## Finds an EventFunction by name in a live sheet - the re-fetch every body edit must do, since the undo
## funnel replaces the sheet (and its functions) with snapshot duplicates on commit, staling any held ref.
static func _find_function_by_name(sheet: EventSheetResource, fn_name: String) -> EventFunction:
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == fn_name:
			return entry as EventFunction
	return null


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
