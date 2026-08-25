# EventForge - A local variable is visible from the event that declares it to the end of the
# body it was declared in, subtrees included - and nowhere else. A function body opens as a RUN of
# sibling events, so "the rest of the body" is what the scope has to mean; anything narrower would
# refuse a drop one row down, and anything wider would allow one into another function.
#
# Pins the model the sheet enforces with it: which names an event can see, which events a name
# reaches, and the one refusal a drag out of scope earns ("<name> is not visible here"). Pure reads
# of the sheet - nothing here writes to a file.
@tool
class_name LocalVariableScopeTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(
		"extends Node\n\n\nfunc _ready() -> void:\n\tvar dealt = 0\n\tif alive:\n\t\tdealt += 1\n\n\n"
		+ "func other() -> void:\n\tvar spare = 2\n\tprint(spare)\n")

	# ── What the sheet declares ──
	var declared: Dictionary = EventSheetLocalScope.declared_locals(sheet)
	ok = _check("the first body's local is declared", declared.has("dealt"), true) and ok
	ok = _check("the second body's local is declared", declared.has("spare"), true) and ok
	ok = _check("a member is not a local", declared.has("alive"), false) and ok

	# ── Which events a name reaches ──
	var declaring: EventRow = _event_with_action(sheet, "SetLocalVar", "dealt")
	var user: EventRow = _event_with_action(sheet, "AddVar", "dealt")
	var stranger: EventRow = _event_with_action(sheet, "SetLocalVar", "spare")
	ok = _check("the three probe events are found",
		declaring != null and user != null and stranger != null, true) and ok
	var reach: Dictionary = EventSheetLocalScope.scope_event_ids(sheet, "dealt")
	ok = _check("the declaring event is in the variable's reach",
		reach.has(declaring.get_instance_id()), true) and ok
	ok = _check("the rest of the same body is in the reach",
		reach.has(user.get_instance_id()), true) and ok
	ok = _check("another function's event is NOT in that reach",
		reach.has(stranger.get_instance_id()), false) and ok

	# ── What an event can see ──
	ok = _check("the declaring event sees its own local",
		EventSheetLocalScope.visible_locals(sheet, declaring).has("dealt"), true) and ok
	ok = _check("another function's event does not see it",
		EventSheetLocalScope.visible_locals(sheet, stranger).has("dealt"), false) and ok

	# ── The refusal ──
	var using_row: RawCodeRow = RawCodeRow.new()
	using_row.code = "\thp -= dealt"
	ok = _check("an action that uses the local is refused outside its scope",
		EventSheetLocalScope.out_of_scope_name(sheet, stranger, [using_row]), "dealt") and ok
	ok = _check("the same action is fine inside the scope",
		EventSheetLocalScope.out_of_scope_name(sheet, user, [using_row]), "") and ok
	var member_row: RawCodeRow = RawCodeRow.new()
	member_row.code = "\thp -= 1"
	ok = _check("an action that uses no local is never refused",
		EventSheetLocalScope.out_of_scope_name(sheet, stranger, [member_row]), "") and ok
	var picked: ACEAction = ACEAction.new()
	picked.ace_id = "SetVar"
	picked.params = {"var_name": "hp", "value": "dealt * 2"}
	ok = _check("a PICKED action is read through its parameters too",
		EventSheetLocalScope.out_of_scope_name(sheet, stranger, [picked]), "dealt") and ok

	# ── Moving the DECLARATION itself ──
	# A Local row dragged into another event moves the declaration, so the name it declares is not
	# held against it - what is held against it is a row left behind that still uses the name.
	var declaration_row: ACEAction = _action_of(declaring, "SetLocalVar", "dealt")
	ok = _check("the declaring row is found", declaration_row != null, true) and ok
	ok = _check("moving a declaration is not refused for the name it declares",
		EventSheetLocalScope.out_of_scope_name(sheet, stranger, [declaration_row]), "") and ok
	ok = _check("but it is refused while a row left behind still uses it",
		EventSheetLocalScope.stranded_name(sheet, stranger, [declaration_row]), "dealt") and ok
	ok = _check("moving it inside its own reach strands nothing",
		EventSheetLocalScope.stranded_name(sheet, declaring, [declaration_row]), "") and ok
	var fresh: ACEAction = ACEAction.new()
	fresh.ace_id = "SetLocalVar"
	fresh.params = {"name": "fresh", "value": "0"}
	ok = _check("a declaration nothing else uses may go anywhere",
		EventSheetLocalScope.stranded_name(sheet, stranger, [fresh]), "") and ok

	# ── The word test the highlight uses ──
	ok = _check("a whole word matches",
		EventSheetLocalScope.mentions_name("Subtract dealt from hp", "dealt"), true) and ok
	ok = _check("a name inside a longer identifier does not",
		EventSheetLocalScope.mentions_name("Set hp_bar to 1", "hp"), false) and ok
	ok = _check("a name inside a string does not",
		EventSheetLocalScope.mentions_name("Print \"dealt\"", "dealt"), false) and ok
	ok = _check("only the head of a member read counts",
		EventSheetLocalScope.mentions_name("t.finished", "finished"), false) and ok

	# ── The canvas: the drag is refused by name, and the hover finds the other uses ──
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()
	view._drag_ace_entries = [{"ace_resource": using_row}]
	var out_of_scope_row: EventRowData = _row_for(view, stranger)
	var in_scope_row: EventRowData = _row_for(view, user)
	ok = _check("the two probe rows are on the canvas",
		out_of_scope_row != null and in_scope_row != null, true) and ok
	var refused: Dictionary = view._validate_ace_drag_target(out_of_scope_row, "action")
	ok = _check("dropping out of scope is refused", refused.get("valid", true), false) and ok
	ok = _check("the refusal names the variable",
		str(refused.get("message", "")), "dealt is not visible here") and ok
	ok = _check("dropping inside the scope is allowed",
		view._validate_ace_drag_target(in_scope_row, "action").get("valid", false), true) and ok
	view._drag_ace_entries = []

	# Hovering the variable's name lights up its other uses, and only inside its own scope.
	# The name lives on the DECLARATION row the event owns - an event sheet declares its locals at the
	# top of the event, so that row, not the action lane, is where a cursor finds "dealt".
	var hover_row_index: int = _declaration_row_index(view, declaring)
	var hover_span_index: int = _span_index_with_text(view, hover_row_index, "dealt")
	ok = _check("the declaration row shows the variable's name", hover_span_index >= 0, true) and ok
	var matches: Dictionary = view._compute_hover_matches(hover_row_index, hover_span_index)
	ok = _check("the hovered row is one of the matches", matches.has(hover_row_index), true) and ok
	ok = _check("an event outside the scope never matches",
		matches.has(_row_index_for(view, stranger)), false) and ok
	ok = _check("the other use of the same local is a match too",
		matches.has(_row_index_for(view, user)), true) and ok
	ok = _check("hovering something that is not a local matches nothing",
		view._compute_hover_matches(hover_row_index, _span_index_with_text(view, hover_row_index, "Local number")).is_empty(),
		true) and ok
	dock.free()
	return ok


static func _row_for(view: EventSheetViewport, event_row: EventRow) -> EventRowData:
	var index: int = _row_index_for(view, event_row)
	return null if index < 0 else (view.get_flat_rows()[index].get("row") as EventRowData)


## The Local declaration row `event_row` owns - the row its `var` line reads as, at the top of the
## event - or -1 when the event declares nothing.
static func _declaration_row_index(view: EventSheetViewport, event_row: EventRow) -> int:
	var rows: Array = view.get_flat_rows()
	for index in rows.size():
		var row_data: EventRowData = (rows[index] as Dictionary).get("row")
		if row_data == null or row_data.source_resource != event_row:
			continue
		if row_data.row_uid.begins_with("local_declaration_"):
			return index
	return -1


static func _row_index_for(view: EventSheetViewport, event_row: EventRow) -> int:
	var rows: Array = view.get_flat_rows()
	for index in rows.size():
		var row_data: EventRowData = (rows[index] as Dictionary).get("row")
		if row_data != null and row_data.source_resource == event_row:
			return index
	return -1


## The first span of `row_index` whose text mentions `word` - what a cursor over that word hits.
static func _span_index_with_text(view: EventSheetViewport, row_index: int, word: String) -> int:
	if row_index < 0:
		return -1
	var row_data: EventRowData = view.get_flat_rows()[row_index].get("row")
	if row_data == null:
		return -1
	view._ensure_event_spans(row_data)
	for index in row_data.spans.size():
		if row_data.spans[index].text.strip_edges() == word:
			return index
	return -1


## The first event of the sheet holding an ACE action of `ace_id` that names `name`, or null.
## The action of `event_row` that is `ace_id` and names `name` - the very resource a drag of that row
## carries.
static func _action_of(event_row: EventRow, ace_id: String, name: String) -> ACEAction:
	if event_row == null:
		return null
	for action_entry: Variant in event_row.actions:
		if not (action_entry is ACEAction) or (action_entry as ACEAction).ace_id != ace_id:
			continue
		if str((action_entry as ACEAction).params.get("name", "")) == name:
			return action_entry as ACEAction
	return null


static func _event_with_action(sheet: EventSheetResource, ace_id: String, name: String) -> EventRow:
	var pending: Array = []
	pending.append_array(sheet.events)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			pending.append_array((function_entry as EventFunction).events)
	while not pending.is_empty():
		var entry: Variant = pending.pop_front()
		if not (entry is EventRow):
			continue
		var event_row: EventRow = entry as EventRow
		for action_entry: Variant in event_row.actions:
			if not (action_entry is ACEAction) or (action_entry as ACEAction).ace_id != ace_id:
				continue
			var params: Dictionary = (action_entry as ACEAction).params
			if str(params.get("name", "")) == name or str(params.get("var_name", "")) == name:
				return event_row
		pending.append_array(event_row.sub_events)
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] local_variable_scope_test: %s" % label)
		return true
	print("[FAIL] local_variable_scope_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
