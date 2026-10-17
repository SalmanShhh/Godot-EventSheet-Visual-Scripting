# EventForge - functions on the sheet: each EventFunction is drawn like any other event, at root level -
# its kind as a coloured word, "Function", "On <name>", a "returns <type>" chip, its tags and one line
# per parameter, its own actions in the action lane beside the head and the rest of its body as
# sub-events, numbered like events. Its description is not drawn: the name's hover shows it and a
# double-click on the name edits it. Functions live in sheet.functions, a SEPARATE array from
# sheet.events. Pins: the head's words and lanes, the parameter lines, the own-actions lane (live and
# read), the event numbers, the inline-at-root layout, and - covenant-critical - that the view is a pure
# READ (opening a real pack still round-trips byte-identically).
@tool
class_name DefineBlockRowsTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


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
		_span_text(define_rows[0] if define_rows.size() > 0 else null, 2), "On take_damage") and ok

	# ── The function drawn like any other event: its kind as a coloured word, "Function", "On <name>",
	# what it returns, its tags, one line per parameter ──
	var action_row: EventRowData = define_rows[0] if define_rows.size() > 0 else null
	var condition_row: EventRowData = define_rows[1] if define_rows.size() > 1 else null
	var expression_row: EventRowData = define_rows[2] if define_rows.size() > 2 else null
	var internal_row: EventRowData = define_rows[3] if define_rows.size() > 3 else null
	ok = SUPPORT.pins("define_block_rows_test", [
		["the head leads with its kind as a word", _span_text(action_row, 0), "Action"],
		["in its kind's colours, never a glyph", _span_meta(action_row, 0, "badge_fg"), Color("#cdefc0")],
		["the kind explains itself on hover", _span_meta(action_row, 0, "hover_note"), "Runs when an event calls it."],
		["a condition says Condition", _span_text(condition_row, 0), "Condition"],
		["an expression says Expression", _span_text(expression_row, 0), "Expression"],
		["then the Function word", _span_text(action_row, 1), "Function"],
		["the name reads On <name>, exactly as written", _span_text(action_row, 2), "On take_damage"],
		["a void function says nothing about what it returns", _row_has_span_text(action_row, "returns void"), false],
		["a condition returns bool", _row_has_span_text(condition_row, "returns bool"), true],
		["an expression returns its type", _row_has_span_text(expression_row, "returns float"), true],
		["the returns chip explains itself", _span_meta_of_kind(expression_row, "function_returns", "hover_note"), "This function hands back a float."],
		["a function in Add Action carries the tag", _row_has_span_text(action_row, "In Add Action"), true],
		["one that is not carries none", _row_has_span_text(internal_row, "In Add Action"), false],
		["the tag explains itself on hover", str(_span_meta_of_kind(action_row, "function_tag", "hover_note")).begins_with("Listed in Add Action"), true],
		["a parameter is its own line, as the code names it", _row_has_span_text(action_row, "float amount"), true],
		["led by a PARAM tag", _row_has_span_text(action_row, "PARAM"), true],
		["the parameter line carries its index, so a click knows which one to open", _span_meta_of_kind(action_row, "verb_param", "param_index"), 0],
		["the parameter explains itself on hover",
			ViewportRowBuilder.function_param_note(action_row.source_resource.params[0]) if action_row != null else "",
			"amount (float). Inside this function, use it like any variable. Every call has to give it a value."],
		["a parameter with a default says it", ViewportRowBuilder.function_param_line(_defaulted_param()), "int amount = 1"],
		["the whole head sits in the CONDITION lane", _lane_of_span_text(action_row, "float amount"), "condition"],
		["no raw func signature leaks into the row", _row_has_span_text(action_row, "func take_damage"), false],
		["no category chip on the row (the Properties bar holds it)", _row_has_span_text(action_row, "Health"), false],
		["a Define row is an EVENT row", action_row.row_type if action_row != null else -1, EventRowData.RowType.EVENT],
		["a verb row is never a drag handle", EventSheetViewport.is_event_drag_zone(action_row, -1), false],
	]) and ok
	# Role classification and the plain type words other surfaces still read with.
	ok = _check("void → action", ViewportRowBuilder.define_role_for(_make_function("f", TYPE_NIL, true, "", "")), "action") and ok
	ok = _check("bool → condition", ViewportRowBuilder.define_role_for(_make_function("f", TYPE_BOOL, true, "", "")), "condition") and ok
	ok = _check("float → expression", ViewportRowBuilder.define_role_for(_make_function("f", TYPE_FLOAT, true, "", "")), "expression") and ok
	ok = _check("params humanize the id (underscores open out)",
		ViewportRowBuilder.friendly_param_labels(_two_param_function()), "from x, to x") and ok
	ok = _check("String reads as text", ViewportRowBuilder.friendly_type_word("String"), "text") and ok
	ok = _check("a declared int is a whole number", ViewportRowBuilder.friendly_type_word("int"), "whole number") and ok
	var templated: EventFunction = _make_function("draw_line", TYPE_NIL, true, "Draw Line", "")
	templated.params[0].id = "from_x"
	templated.display_template = "Line to {from_x}"
	ok = _check("an authored template fills its slots with param labels",
		ViewportRowBuilder.friendly_template_line(templated), "Line to from x") and ok

	# ── The description lives INSIDE the head, under the name, and is edited there ──
	var described_sheet: EventSheetResource = EventSheetResource.new()
	described_sheet.host_class = "Node2D"
	var described_fn: EventFunction = _make_function("heal", TYPE_NIL, true, "Heal", "Health")
	described_fn.description = "Restores health, capped at the maximum."
	described_fn.is_async = true
	described_fn.is_static = true
	described_sheet.functions.append(described_fn)
	described_sheet.functions.append(_make_function("silent", TYPE_NIL, true, "Silent", ""))
	var documented_fn: EventFunction = _make_function("charge", TYPE_NIL, true, "Charge", "")
	documented_fn.doc_comment = "Builds up charge before releasing it\nfor a moment."
	described_sheet.functions.append(documented_fn)
	var described_dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	described_dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	described_dock.setup(described_sheet)
	var described_view: EventSheetViewport = described_dock._active_view()
	var heal_row: EventRowData = _find_row_by_uid_prefix(described_view, "define_fn_heal")
	var silent_row: EventRowData = _find_row_by_uid_prefix(described_view, "define_fn_silent")
	var charge_row: EventRowData = _find_row_by_uid_prefix(described_view, "define_fn_charge")
	ok = SUPPORT.pins("define_block_rows_test", [
		["no caption row above the function any more", _find_row_by_uid_prefix(described_view, "verb_note_"), null],
		["the description is not drawn on the row", _row_has_span_text(heal_row, "Restores health, capped at the maximum."), false],
		["hovering the name shows it, and how to edit it",
			_span_meta(heal_row, 2, "hover_note"),
			"heal\nRestores health, capped at the maximum.\nReads as: Heal\nDouble-click the name to edit the description."],
		["the name is the door to the description", _span_meta(heal_row, 2, "function_name"), true],
		["an undescribed function says so in the hover",
			str(_span_meta(silent_row, 2, "hover_note")).get_slice("\n", 1), "No description yet."],
		["a doc comment reads as one whole sentence",
			str(_span_meta(charge_row, 2, "hover_note")).get_slice("\n", 1), "Builds up charge before releasing it for a moment."],
		["a function that waits says so", _row_has_span_text(heal_row, "Waits"), true],
		["a shared one says so", _row_has_span_text(heal_row, "Shared"), true],
	]) and ok
	described_dock.free()
	# ── Ordering: the canvas mirrors the COMPILER - the sheet's events first, then its vocabulary. The old
	# view hoisted every verb above everything, so an opened pack read back-to-front against its own .gd.
	var order_sheet: EventSheetResource = EventSheetResource.new()
	order_sheet.host_class = "Node2D"
	var main_code: RawCodeRow = RawCodeRow.new()
	main_code.code = "print(\"main loop\")"
	order_sheet.events.append(main_code)
	order_sheet.functions.append(_make_function("later", TYPE_NIL, true, "Later", ""))
	var order_dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	order_dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	order_dock.setup(order_sheet)
	var order_view: EventSheetViewport = order_dock._active_view()
	ok = _check("a sheet's events come BEFORE its verbs, exactly as the compiler emits them",
		_flat_index_of(order_view, "define_fn_later") > 0, true) and ok
	order_dock.free()

	# ── A verb's body runs when the verb is CALLED, so a condition-less row inside it reads "Always".
	# The SAME row on the sheet itself still reads "Every Tick" (a sheet compiles into _process), which
	# is why the placeholder is context-dependent: "Every Tick" inside a function body is a plain lie
	# about when those steps run.
	var tick_sheet: EventSheetResource = EventSheetResource.new()
	tick_sheet.host_class = "Node2D"
	var sheet_level_event: EventRow = EventRow.new()
	tick_sheet.events.append(sheet_level_event)
	var body_verb: EventFunction = _make_function("do_it", TYPE_NIL, true, "Do It", "")
	var verb_body_event: EventRow = EventRow.new()
	body_verb.events.append(verb_body_event)
	tick_sheet.functions.append(body_verb)
	var tick_dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	tick_dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	tick_dock.setup(tick_sheet)
	var tick_view: EventSheetViewport = tick_dock._active_view()
	var verb_header: EventRowData = _find_row_by_uid_prefix(tick_view, "define_fn_do_it")
	var verb_body_row: EventRowData = verb_header.children[0] if verb_header != null and not verb_header.children.is_empty() else null
	if verb_body_row != null:
		tick_view._row_builder._ensure_event_spans(verb_body_row)
	ok = _check("a condition-less row with nothing in it INSIDE a verb body reads 'Always'",
		_row_has_span_text(verb_body_row, "Always"), true) and ok
	ok = _check("it never claims to run 'Every Tick' inside a verb body",
		_row_has_span_text(verb_body_row, "Every Tick"), false) and ok

	var sheet_event_row: EventRowData = _find_row_by_resource(tick_view, sheet_level_event)
	if sheet_event_row != null:
		tick_view._row_builder._ensure_event_spans(sheet_event_row)
	# On the SHEET the same row reads BLANK: an event with no condition of its own already
	# says it runs every tick by saying nothing, so the placeholder would talk over the reading.
	ok = _check("the SHEET's own condition-less event reads blank, not 'Every Tick'",
		_row_has_span_text(sheet_event_row, "Every Tick"), false) and ok
	tick_dock.free()

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
	# Counted through the whole tree: an opened pack is read-only, so its unpublished helpers are
	# re-parented under the closed "Helpers" bar and no longer appear in the flat (visible) row list.
	ok = _check("the pack shows its verbs inline - one row per lifted function",
		_count_define_rows_deep(dock._active_view()._root_rows), opened.functions.size()) and ok
	# A REAL pack's `## @ace_description(...)` blurbs reach the reader - but an opened pack is a READING
	# surface (read-only), where a verb draws as an event-sheet Function block and its description answers in
	# the ACE properties panel instead of as a caption row welded above the row.
	ok = _check("an opened pack draws no caption rows in Reading mode",
		_find_rows_by_uid_prefix(dock._active_view(), "verb_note_").size(), 0) and ok
	var described_verb: EventFunction = _first_described_function(opened)
	ok = _check("an opened pack surfaces the descriptions its author wrote, in the properties panel",
		described_verb != null and not _panel_description(described_verb, opened).is_empty(), true) and ok
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
	# Regression: a row is made inert by NULLING source_resource, but event-row spans are built LAZILY
	# and resolve FROM that resource - so nulling and forgetting left every body row drawing as a
	# blank band. Invisible while verb bodies defaulted to folded; obvious the moment they open. The
	# fix is a READING pointer the span builder uses and nothing that writes ever looks at, which is
	# also what lets these rows stay lazy: a long file must not pay for the words of rows nobody has
	# scrolled to. So the pin is that the words ARRIVE when the row is laid out, and that the pointer
	# they come from is there to be used.
	ok = _check("every function-body event row keeps the pointer its words are built from",
		_inert_rows_can_read(body_roots), true) and ok
	for body_root: Variant in body_roots:
		_ensure_spans_deep(dock._active_view(), body_root as EventRowData)
	ok = _check("and every one of them really renders once it is laid out",
		_event_rows_have_spans(body_roots), true) and ok
	# A verb at root OPENS by default - its steps are the point, and the fold hint is gone with it.
	ok = _check("a verb opens by default (no click needed to read what it does)",
		_first_with_children(pack_rows) != null and not _first_with_children(pack_rows).folded, true) and ok
	ok = _check("no 'double-click to open' hint is left on the row",
		_any_span_contains(pack_rows, "double-click"), false) and ok
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
	var located: Dictionary = authored_dock._ace_apply._find_resource_location(live_body_res)
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
		var loc: Dictionary = authored_dock._ace_apply._find_resource_location(live_body_res)
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
	guard_dock._ace_apply._insert_row_below_selection(new_body_row, live_empty_verb)
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
		guard_dock._ace_apply._move_rows([body_row_data], target_row_data, "after", false)
	var dragged_res: Resource = body_row_data.source_resource if body_row_data != null else null
	ok = _check("a cross-tree drag (verb body -> main loop) is refused: body row stays in the verb",
		live_verb != null and live_verb.events.has(dragged_res), true) and ok
	ok = _check("the refused drag did NOT alias the body row into sheet.events",
		guard_dock.get_current_sheet().events.has(dragged_res), false) and ok
	guard_dock.free()
	ok = _own_actions_beside_the_head() and ok
	ok = _function_heads_are_numbered() and ok
	ok = _branching_steps_beside_the_head() and ok
	ok = _description_editor() and ok
	return ok


## A function's own actions - its first, condition-less step - sit in the head's action lane instead of
## a separate "Always" row, on an authored sheet where they stay live: Add action on the head fills
## that step, and an action there resolves to the step's own action. A step that asks a question of
## its own stays a row.
static func _own_actions_beside_the_head() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var hurt: EventFunction = _make_function("hurt", TYPE_NIL, true, "", "")
	var step: EventRow = EventRow.new()
	var line: RawCodeRow = RawCodeRow.new()
	line.code = "health -= 1"
	step.actions.append(line)
	var guarded: EventRow = EventRow.new()
	guarded.conditions.append(ACECondition.new())
	hurt.events.append(step)
	hurt.events.append(guarded)
	sheet.functions.append(hurt)
	var asks: EventFunction = _make_function("asks", TYPE_NIL, true, "", "")
	var asking_step: EventRow = EventRow.new()
	asking_step.conditions.append(ACECondition.new())
	asking_step.actions.append(RawCodeRow.new())
	asks.events.append(asking_step)
	sheet.functions.append(asks)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()
	var head: EventRowData = _find_row_by_uid_prefix(view, "define_fn_hurt")
	var asks_head: EventRowData = _find_row_by_uid_prefix(view, "define_fn_asks")
	var live: EventFunction = _find_function_by_name(dock.get_current_sheet(), "hurt")
	var passed: bool = SUPPORT.pins("define_block_rows_test", [
		["the first step's action sits in the head's action lane", _has_action_span(head), true],
		["no 'Always' row is left under the head", _child_has_text(head, "Always"), false],
		["the guarded step stays the one sub-event", head.children.size() if head != null else -1, 2],
		["the data names the step the head draws", live.lane_event() == live.events[0], true],
		["an action on the head resolves to the step's own action",
			view._resolve_ace_resource(live, "action", 0) == (live.events[0] as EventRow).actions[0], true],
		["the view owns the step's actions through the head", view.ace_owner(live) == live.events[0], true],
		["a step with a condition of its own is not drawn beside the head", (asks.lane_event() == null), true],
		["so that function's head keeps an empty action lane", _has_action_span(asks_head), false],
	])
	dock.free()
	return passed


## A first step whose value branches (`return 1 if ready else 0`) reads as a pair, and the pair's own
## row is the step: it steps aside for the head, and the branch rows hang under the head unnumbered.
## The ⟡ chip naming the pattern a step's code is rides up with its actions (read off a shipped pack).
static func _branching_steps_beside_the_head() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var pick: EventFunction = _make_function("pick", TYPE_INT, true, "", "")
	var step: EventRow = EventRow.new()
	var line: RawCodeRow = RawCodeRow.new()
	line.code = "return 1 if ready else 0"
	step.actions.append(line)
	pick.events.append(step)
	sheet.functions.append(pick)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var head: EventRowData = _find_row_by_uid_prefix(dock._active_view(), "define_fn_pick")
	var first: EventRowData = head.children[0] if head != null and not head.children.is_empty() else null
	var pack: EventSheetResource = GDScriptImporter.new().import_external(
		"res://eventsheet_addons/advanced_random/advanced_random_addon.gd")
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(pack)
	var seeded: EventRowData = _find_row_by_uid_prefix(viewport, "define_fn_set_random_seed")
	var passed: bool = SUPPORT.pins("define_block_rows_test", [
		["no 'Always' row is left under a branching step's head", _child_has_text(head, "Always"), false],
		["the head's first sub-event is the branch", first.row_uid.contains("_branch_") if first != null else false, true],
		["the head wears the step's number", head.event_number if head != null else -1, 1],
		["the branch rows wear none", first.event_number if first != null else -1, 0],
		["the pattern chip rides up to the head", _row_has_span_text(seeded, "⟡ Seeded randomness and noise"), true],
		["so that head keeps no 'Always' row either", _child_has_text(seeded, "Always"), false],
	])
	viewport.free()
	dock.free()
	return passed


## A function head carries an event number like any event, counted where the sheet draws it, its own
## actions share it, and the rest of its body is numbered after it.
static func _function_heads_are_numbered() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var first: EventRow = EventRow.new()
	sheet.events.append(first)
	var hurt: EventFunction = _make_function("hurt", TYPE_NIL, true, "", "")
	var own: EventRow = EventRow.new()
	own.actions.append(RawCodeRow.new())
	var later: EventRow = EventRow.new()
	later.conditions.append(ACECondition.new())
	hurt.events.append(own)
	hurt.events.append(later)
	sheet.functions.append(hurt)
	var numbers: Dictionary = EventSheetResource.event_numbers(sheet.events, sheet.functions)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var head: EventRowData = _find_row_by_uid_prefix(dock._active_view(), "define_fn_hurt")
	var passed: bool = SUPPORT.pins("define_block_rows_test", [
		["the sheet's own event is 1", int(numbers.get(first.get_instance_id(), 0)), 1],
		["the function after it is 2", int(numbers.get(hurt.get_instance_id(), 0)), 2],
		["its own actions share the head's number", int(numbers.get(own.get_instance_id(), 0)), 2],
		["the next step of its body is 3", int(numbers.get(later.get_instance_id(), 0)), 3],
		["without the functions the sheet's numbers are what they were",
			EventSheetResource.event_numbers(sheet.events).size(), 1],
		["the head wears its number in the gutter", head.event_number if head != null else -1, 2],
		["Go to event 2 finds the function's own step",
			EventSheetViewport.event_by_number(sheet.events, 2, sheet.functions) == own, true],
	])
	dock.free()
	return passed


## The small window a double-click on the name opens: the description in a text box, and Save writes
## it as one undo step.
static func _description_editor() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var heal: EventFunction = _make_function("heal", TYPE_NIL, true, "", "")
	heal.description = "Restores health."
	sheet.functions.append(heal)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var dialog: ConfirmationDialog = load(EventSheetPropertiesBar.FUNCTION_INSPECTOR_PATH).open_description_editor(
		dock, _find_function_by_name(dock.get_current_sheet(), "heal"), Vector2.ZERO)
	var text: TextEdit = dialog.find_child("Description", true, false) as TextEdit
	var passed: bool = SUPPORT.pins("define_block_rows_test", [
		["the window is titled by the function", dialog.title, "Description of heal"],
		["it opens on the description", text.text if text != null else "", "Restores health."],
		["and saves with Save", dialog.ok_button_text, "Save"],
	])
	text.text = "Restores health, capped at the maximum."
	dialog.confirmed.emit()
	passed = SUPPORT.check("define_block_rows_test", "Save writes the description",
		_find_function_by_name(dock.get_current_sheet(), "heal").description,
		"Restores health, capped at the maximum.") and passed
	dialog.free()
	dock.free()
	return passed


static func _has_action_span(row_data: EventRowData) -> bool:
	if row_data == null:
		return false
	for span: SemanticSpan in row_data.spans:
		if span.metadata is Dictionary and str((span.metadata as Dictionary).get("lane", "")) == "action" \
				and str((span.metadata as Dictionary).get("kind", "")) != "add_action":
			return true
	return false


static func _child_has_text(row_data: EventRowData, needle: String) -> bool:
	if row_data == null:
		return false
	for child: EventRowData in row_data.children:
		if _row_has_span_text(child, needle):
			return true
	return false


## Define rows anywhere in the tree.
static func _count_define_rows_deep(rows: Array) -> int:
	var count: int = 0
	for entry: Variant in rows:
		var row_data: EventRowData = entry
		if row_data == null:
			continue
		if row_data.row_uid.begins_with("define_fn_"):
			count += 1
		count += _count_define_rows_deep(row_data.children)
	return count


## The first verb of an opened pack that carries an authored `## @ace_description(...)`.
static func _first_described_function(sheet: EventSheetResource) -> EventFunction:
	for entry: Variant in sheet.functions:
		if entry is EventFunction and not (entry as EventFunction).description.strip_edges().is_empty():
			return entry as EventFunction
	return null


## The Description the ACE properties panel answers with for one verb.
static func _panel_description(event_function: EventFunction, sheet: EventSheetResource) -> String:
	for row: Dictionary in EventSheetVerbProperties.property_rows(event_function, sheet):
		if str(row.get("label", "")) == "Description":
			return str(row.get("value", ""))
	return ""


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


## True when every EVENT row in the subtree has spans. A span-less event row draws as an empty band -
## exactly what nulling source_resource before the lazy span build used to produce. Only EVENT rows are
## checked: a blank-line separator block legitimately carries no spans.
## True when every inert EVENT row in the tree still holds the resource its words are built from.
## An inert row gives up `source_resource` so nothing can write to it; what it must NOT give up is
## the pointer the span builder reads, or it draws as a blank band the moment it is laid out.
static func _inert_rows_can_read(rows: Array) -> bool:
	for entry: Variant in rows:
		var row_data: EventRowData = entry
		if row_data == null:
			continue
		if row_data.row_type == EventRowData.RowType.EVENT \
				and row_data.source_resource == null and row_data.reading_resource == null:
			return false
		if not _inert_rows_can_read(row_data.children):
			return false
	return true


## Lays a row and its whole subtree out, the way scrolling to it would.
static func _ensure_spans_deep(view: EventSheetViewport, row_data: EventRowData) -> void:
	if row_data == null:
		return
	view._row_builder._ensure_event_spans(row_data)
	for child: EventRowData in row_data.children:
		_ensure_spans_deep(view, child)


static func _event_rows_have_spans(rows: Array) -> bool:
	for entry: Variant in rows:
		var row_data: EventRowData = entry
		if row_data == null:
			continue
		if row_data.row_type == EventRowData.RowType.EVENT and row_data.spans.is_empty():
			return false
		if not _event_rows_have_spans(row_data.children):
			return false
	return true


static func _first_with_children(rows: Array) -> EventRowData:
	for entry: Variant in rows:
		var row_data: EventRowData = entry
		if row_data != null and not row_data.children.is_empty():
			return row_data
	return null


static func _any_span_contains(rows: Array, needle: String) -> bool:
	for entry: Variant in rows:
		var row_data: EventRowData = entry
		if row_data == null:
			continue
		for span: SemanticSpan in row_data.spans:
			if str(span.text).contains(needle):
				return true
	return false


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


static func _defaulted_param() -> ACEParam:
	var param: ACEParam = ACEParam.new()
	param.id = "amount"
	param.type_name = "int"
	param.gdscript_default = "1"
	return param


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


static func _find_row_by_resource(view: EventSheetViewport, resource: Resource) -> EventRowData:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == resource:
			return row_data
	return null


static func _find_rows_by_uid_prefix(view: EventSheetViewport, prefix: String) -> Array[EventRowData]:
	var found: Array[EventRowData] = []
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.row_uid.begins_with(prefix):
			found.append(row_data)
	return found


## The lane a span lays out in ("condition" / "action") - the two-column model's whole point.
static func _span_lane(row_data: EventRowData, index: int) -> String:
	if row_data == null or index >= row_data.spans.size():
		return ""
	var metadata: Dictionary = row_data.spans[index].metadata if row_data.spans[index].metadata is Dictionary else {}
	return str(metadata.get("lane", "condition"))


## The lane of the first span whose text matches, or "" when the row carries no such span.
static func _lane_of_span_text(row_data: EventRowData, needle: String) -> String:
	if row_data == null:
		return ""
	for index in range(row_data.spans.size()):
		if str(row_data.spans[index].text) == needle:
			return _span_lane(row_data, index)
	return ""


## A metadata value off the first span of the given kind - how the param cells are inspected, since
## their identity lives in metadata (object_label / param_index), not in the drawn text.
static func _span_meta_of_kind(row_data: EventRowData, kind: String, key: String) -> Variant:
	if row_data == null:
		return null
	for span: SemanticSpan in row_data.spans:
		var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
		if str(metadata.get("kind", "")) == kind:
			return metadata.get(key, null)
	return null


static func _span_meta(row_data: EventRowData, index: int, key: String) -> Variant:
	if row_data == null or index >= row_data.spans.size():
		return null
	var metadata: Dictionary = row_data.spans[index].metadata if row_data.spans[index].metadata is Dictionary else {}
	return metadata.get(key, null)


## Flat (visual) index of the first row whose uid starts with `prefix`, or -1 - so a test can assert
## that one row sits directly above another, which is what "reads in source order" means on screen.
static func _flat_index_of(view: EventSheetViewport, prefix: String) -> int:
	var rows: Array = view.get_flat_rows()
	for index in range(rows.size()):
		var row_data: EventRowData = (rows[index] as Dictionary).get("row")
		if row_data != null and row_data.row_uid.begins_with(prefix):
			return index
	return -1


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


## The edit_kind of the span whose text matches, or "" - so a test can pin that a cell is inline-editable.
static func _span_edit_kind(row_data: EventRowData, needle: String) -> String:
	if row_data == null:
		return ""
	for span: SemanticSpan in row_data.spans:
		if str(span.text) == needle and span.metadata is Dictionary:
			return str((span.metadata as Dictionary).get("edit_kind", ""))
	return ""


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("define_block_rows_test", label, actual, expected)
