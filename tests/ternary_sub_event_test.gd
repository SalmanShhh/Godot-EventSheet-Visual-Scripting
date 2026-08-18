# EventForge - M23: an `if ... else` INSIDE a statement reads as a sub-event pair, never as a
# condition sitting in an action cell (which is the one thing a Construct sheet never does).
#
# Three things are pinned here, all of them pure view state over unchanged statements:
#   1. the grammar's branch split, for every shape a ternary takes - a return, an assignment, a
#      member assignment, a local declaration, a ternary that is only PART of a larger value, a
#      nested chain, and the two it must REFUSE (a lambda body, a string that merely spells "if")
#   2. the rows a fixture sheet draws: condition on the left, the whole statement re-read on the
#      right, then the Else - by VALUE, not by count
#   3. the shipped FPS Controller and Health packs: no action-lane sentence anywhere still carries
#      an `if ... else`
#   4. the pair on an EDITABLE sheet, where it is not a picture but a thing you click: one statement
#      behind every row of it, so selection, the arrow keys, drag/drop, the double-click editors,
#      delete and undo all address the pair as the single statement it reads
#
# The one documented exception in (3) is a statement holding an inline `func(...)` lambda: its body
# is a scope of its own, so hoisting a branch out of it would move WHEN that branch runs. Such a row
# keeps its GDScript instead of posing as a sentence.
@tool
class_name TernarySubEventTest
extends RefCounted

const FPS_PACK: String = "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"
const HEALTH_PACK: String = "res://eventsheet_addons/health/health_behavior.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _grammar() and ok
	ok = _fixture_rows() and ok
	ok = _shipped_packs() and ok
	ok = _editable_sheet_rows() and ok
	return ok


## ── 1. the branch split, one case per shape ──────────────────────────────────────────────────
static func _grammar() -> bool:
	var ok: bool = true
	ok = _check("a return branches into its two arms",
		_branches("return host.get_wall_normal().x if host != null and host.is_on_wall() else 0.0"),
		"host != null and host.is_on_wall() => return host.get_wall_normal().x | (else) => return 0.0") and ok
	ok = _check("an assignment branches",
		_branches("speed = fast if sprinting else base"),
		"sprinting => speed = fast | (else) => speed = base") and ok
	ok = _check("a member assignment branches",
		_branches("self.head_base_y = head_node.position.y if head_node != null else 0.0"),
		"head_node != null => self.head_base_y = head_node.position.y | (else) => self.head_base_y = 0.0") and ok
	ok = _check("a local declaration branches",
		_branches("var pull := gravity_direction if gravity_direction != Vector3.ZERO else Vector3.DOWN"),
		"gravity_direction != Vector3.ZERO => var pull := gravity_direction | (else) => var pull := Vector3.DOWN") and ok
	ok = _check("a compound assignment branches",
		_branches("velocity += gravity * (scale if wall_riding else 1.0) * delta"),
		"wall_riding => velocity += gravity * scale * delta | (else) => velocity += gravity * 1.0 * delta") and ok
	# A branch that is only PART of the value: each arm is the WHOLE statement with that arm in
	# place, brackets and all - the empty pair the substitution would otherwise leave behind is gone.
	ok = _check("a sub-expression ternary hoists the whole statement",
		_branches("speed = move_speed * (sprint_multiplier if sprint_held else 1.0)"),
		"sprint_held => speed = move_speed * sprint_multiplier | (else) => speed = move_speed * 1.0") and ok
	ok = _check("a nested chain reads as Else-if arms",
		_branches("var v := a if c1 else b if c2 else d"),
		"c1 => var v := a | c2 => var v := b | (else) => var v := d") and ok
	ok = _check("a parenthesised nested chain reads the same",
		_branches("var v := a if c1 else (b if c2 else d)"),
		"c1 => var v := a | c2 => var v := b | (else) => var v := d") and ok
	# The refusals. A lambda body is a second scope, and a string is content, not code.
	ok = _check("a ternary inside a lambda is left alone",
		_branches("indexed.sort_custom(func(a, b): return a[1] < b[1] if a[1] != b[1] else a[2] < b[2])"),
		"") and ok
	ok = _check("an `if` spelled inside a string is not a branch",
		_branches("label = \"a if b else c\""), "") and ok
	ok = _check("a statement with no value never branches",
		_branches("queue_free()"), "") and ok
	ok = _check("a bare value branches too, for a lifted row's parameter",
		_value_branches("fast if sprinting else base"),
		"sprinting => fast | (else) => base") and ok
	# The condition lane reads each conjunct through the grammar, not as a line of code.
	ok = _check("a run of conjuncts reads as words",
		_condition("host != null and host.is_on_wall()"), "host exists and host is on wall") and ok
	ok = _check("one conjunct keeps the object column",
		_condition_object("head_node != null"), "head_node") and ok
	# A no-argument getter is a property read wearing a call's clothes.
	ok = _check("a no-argument getter reads as the property",
		EventSheetSentence.expression_text("host.get_wall_normal().x"), "host.wall_normal.x") and ok
	return ok


## ── 2. the rows one fixture sheet draws ──────────────────────────────────────────────────────
static func _fixture_rows() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _fixture_sheet()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()
	var rows: PackedStringArray = _row_readings(view)
	# M24: `and` never appears inside a condition cell - each conjunct is a condition LINE of the one
	# event, exactly as a lifted `if a and b:` already stacks them.
	ok = _check("a lone ternary return replaces its row with the pair",
		_reading_at(rows, "Set return value to host's wall normal X"),
		"host exists > host is on wall | Set return value to host's wall normal X") and ok
	ok = _check("the pair's second arm is the Else row",
		_reading_at(rows, "Set return value to 0"), "Else | Set return value to 0") and ok
	ok = _check("a sub-expression ternary re-reads the whole assignment",
		_reading_at(rows, "Set speed to move speed * sprint multiplier"),
		"sprint held is true | Set speed to move speed * sprint multiplier") and ok
	ok = _check("its Else keeps the statement too",
		_reading_at(rows, "Set speed to move speed * 1"), "Else | Set speed to move speed * 1") and ok
	# A chain nests no further: three arms, three sibling rows, the last of them the plain Else. The
	# values stay QUOTED, because a string is content the reader is looking at, not a name.
	ok = _check("a nested chain draws three arms",
		_reading_at(rows, "Set tier to \"gold\""), "score > 100 | Set tier to \"gold\"") and ok
	# The middle arm is an ELSE-IF, and Construct spells one as an Else event carrying a condition -
	# the Else chip on the row's first condition line, the arm's test on its second. Drawn as a bare
	# `score > 50` it would read as a sibling, i.e. as though both arms could fire.
	ok = _check("the chain's middle arm is an Else WITH its condition under it",
		_reading_at(rows, "Set tier to \"silver\""), "Else > score > 50 | Set tier to \"silver\"") and ok
	ok = _check("and it stacks as two condition lines on the one row",
		_line_count_at(view, "Set tier to \"silver\""), 2) and ok
	ok = _check("the chain ends on a plain Else",
		_reading_at(rows, "Set tier to \"bronze\""), "Else | Set tier to \"bronze\"") and ok
	ok = _check("no fixture row keeps an if/else in a sentence cell",
		_branchy_readings(rows), PackedStringArray()) and ok
	dock.free()
	return ok


## ── 3. the shipped packs, read exactly as the dock opens them ────────────────────────────────
static func _shipped_packs() -> bool:
	var ok: bool = true
	for path: String in [FPS_PACK, HEALTH_PACK]:
		var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
		if sheet == null:
			ok = _check("the pack opens: %s" % path.get_file(), false, true) and ok
			continue
		sheet.read_only = true
		var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
		dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
		dock.setup(sheet)
		var view: EventSheetViewport = dock._active_view()
		ok = _check("no action cell of %s reads an if/else" % path.get_file(),
			_branchy_action_cells(view), PackedStringArray()) and ok
		dock.free()
	return ok


## ── 4. the pair on an EDITABLE sheet ─────────────────────────────────────────────────────────
##
## The reading is the same one a preview shows; what is pinned here is that it stays ONE statement
## under the pointer. Everything keys on EventRowData.statement_uid(), so every case below is really
## the same assertion asked from a different gesture.
static func _editable_sheet_rows() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _editable_fixture()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var undo: EventSheetEditorTest.FakeEditorUndoRedoManager = EventSheetEditorTest.FakeEditorUndoRedoManager.new()
	dock.set_undo_redo_manager(undo)
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()
	# The sheet is authored, not read: no preview lock and no Reading lens anywhere in sight.
	ok = _check("the fixture really is an editable sheet",
		"%s/%s" % [str(sheet.read_only), str(view.is_reading_mode())], "false/false") and ok
	var rows: PackedStringArray = _row_readings(view)
	ok = _check("an editable sheet draws the pair too",
		_reading_at(rows, "Set speed to fast_speed"), "sprinting is true | Set speed to fast_speed") and ok
	ok = _check("and its Else",
		_reading_at(rows, "Set speed to base_speed"), "Else | Set speed to base_speed") and ok
	# A lifted row branches on the PARAMETER whose value carries the ternary, so the pair's condition
	# lane is where that shows; the action cell keeps reading through the ACE's own display descriptor.
	ok = _check("a lifted row's branching PARAMETER pairs the same way",
		_branch_conditions(view, sheet.events[3]), "wounded is true | Else") and ok
	ok = _check("no editable row keeps an if/else in a sentence cell",
		_branchy_readings(rows), PackedStringArray()) and ok

	# ── one statement behind every row of the pair ──
	var pair: Array[int] = _rows_for(view, sheet.events[1])
	ok = _check("the pair draws three rows over one statement", pair.size(), 3) and ok
	ok = _check("all three answer with the head's uid",
		_distinct_statement_uids(view, pair), _row_at(view, pair[0]).row_uid) and ok
	ok = _check("exactly one of them leads the pair (the gutter's owner)",
		_lead_flags(view, pair), "true/false/false") and ok
	ok = _check("only the leader is numbered - a reading is not an event",
		_event_numbers(view, pair), "2/0/0") and ok

	# ── selection: any row of the pair selects the ONE statement, and lights all three ──
	var selection_reports: PackedStringArray = PackedStringArray()
	for row_index: int in pair:
		view._select_from_click(row_index, -1, false)
		selection_reports.append(_selection_report(view, sheet.events[1], pair))
	ok = _check("clicking any row of the pair selects the one statement and lights the pair",
		" ".join(selection_reports), "1/same/3 1/same/3 1/same/3") and ok
	# One statement, one toggle: Ctrl+clicking a second row of the SAME pair takes the statement back
	# out of the selection, while Ctrl+clicking a different event adds a second entry - so a pair can
	# never contribute two rows to a multi-selection.
	view.clear_selection()
	view._select_from_click(pair[0], -1, true)
	view._select_from_click(pair[2], -1, true)
	ok = _check("Ctrl+clicking a second row of the same pair toggles the one statement back off",
		view.get_selected_rows().size(), 0) and ok
	view.clear_selection()
	view._select_from_click(pair[0], -1, true)
	view._select_from_click(_rows_for(view, sheet.events[2])[0], -1, true)
	ok = _check("a pair contributes exactly one entry to a multi-selection",
		view.get_selected_rows().size(), 2) and ok

	# ── the arrow keys step over the pair as the one row it reads as ──
	ok = _check("Down from the row above lands on the pair, not inside it",
		view.step_selection_index(pair[0] - 1, 1), pair[0]) and ok
	ok = _check("Down from the pair clears it in one press",
		view.step_selection_index(pair[0], 1), pair[2] + 1) and ok
	ok = _check("Up from the pair's last row clears it too",
		view.step_selection_index(pair[2], -1), pair[0] - 1) and ok

	# ── drag: any row of the pair drags the statement, and nothing drops between its rows ──
	view._begin_row_drag(pair[2])
	ok = _check("grabbing the Else row drags the statement", view._drag_row_index, pair[0]) and ok
	view._clear_row_drag()
	ok = _check("a drop BEFORE any row of the pair lands above the whole pair",
		_drop_target(view, pair[1], "before"), "%d/before" % pair[0]) and ok
	ok = _check("a drop INTO a branch row snaps below the whole pair",
		_drop_target(view, pair[1], "inside"), "%d/after" % pair[2]) and ok
	ok = _check("a drop AFTER a branch row lands below the whole pair",
		_drop_target(view, pair[1], "after"), "%d/after" % pair[2]) and ok
	ok = _check("dropping INTO the pair's own lead row still nests a sub-event",
		_drop_target(view, pair[0], "inside"), "%d/inside" % pair[0]) and ok

	# ── double-click: every row of the pair opens that ONE line ──
	var opened: Array = []
	view.raw_code_edit_requested.connect(func(resource: Resource, _inline: bool) -> void: opened.append(resource))
	view.ace_edit_requested.connect(func(_row: EventRowData, _span: int, metadata: Dictionary) -> void: opened.append(metadata))
	for row_index: int in [pair[1], pair[2]]:
		view.request_ternary_statement_edit(_row_at(view, row_index))
	ok = _check("both branch rows open the one statement the file holds",
		_opened_report(opened, sheet.events[1]), "same/same") and ok
	var lifted_pair: Array[int] = _rows_for(view, sheet.events[3])
	opened.clear()
	view.request_ternary_statement_edit(_row_at(view, lifted_pair[1]))
	ok = _check("a lifted row's pair opens the ACE editor on that action",
		_opened_metadata(opened), "action/0") and ok

	# ── scaffolding: no "+ Add" inside the pair; the event's own stays on its head ──
	ok = _check("the pair carries no add-a-row affordance, the event's head does",
		_scaffolding_report(view, pair), "head/none/none") and ok

	# ── delete + undo, with the compiled GDScript as the witness ──
	var before_output: String = _compiled(dock)
	view._select_from_click(pair[1], -1, false)
	dock._delete_selected_content()
	ok = _check("deleting from a branch row removes the ONE event it reads",
		_event_codes(dock), "print(\"start\") | print(\"between\") | Print") and ok
	undo.undo()
	dock._refresh_after_edit()
	ok = _check("undo restores the sheet byte-for-byte",
		_compiled(dock), before_output) and ok

	# ── a reorder through the drop path the pair's rows feed, then undo ──
	var moved_pair: Array[int] = _rows_for(view, dock._current_sheet.events[1])
	dock._on_row_drop_requested(
		_row_at(view, moved_pair[2]), _row_at(view, _rows_for(view, dock._current_sheet.events[2])[0]), "after", false)
	ok = _check("dragging the Else row moves the whole statement, once",
		_event_codes(dock), "print(\"start\") | print(\"between\") | speed = ... | Print") and ok
	undo.undo()
	dock._refresh_after_edit()
	ok = _check("and undo puts it back byte-for-byte", _compiled(dock), before_output) and ok
	dock.free()
	return ok


# ── Fixture ─────────────────────────────────────────────────────────────────────────────────


## One verb whose body is a lone ternary return, plus a plain event carrying the other two shapes.
static func _fixture_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody3D"
	sheet.custom_class_name = "TernaryFixture"
	sheet.external_source_path = "res://eventsheet_addons/ternary_fixture/ternary_fixture.gd"
	sheet.read_only = true
	var verb: EventFunction = EventFunction.new()
	verb.function_name = "wall_normal_x"
	verb.return_type = TYPE_FLOAT
	verb.expose_as_ace = true
	verb.ace_display_name = "Wall Normal X"
	var verb_body: EventRow = EventRow.new()
	verb_body.actions.append(_raw("return host.get_wall_normal().x if host != null and host.is_on_wall() else 0.0"))
	verb.events.append(verb_body)
	sheet.functions.append(verb)
	var event_row: EventRow = EventRow.new()
	event_row.actions.append(_raw("speed = move_speed * (sprint_multiplier if sprint_held else 1.0)"))
	event_row.actions.append(_raw("tier = \"gold\" if score > 100 else \"silver\" if score > 50 else \"bronze\""))
	sheet.events.append(event_row)
	return sheet


## Four events on an AUTHORED sheet: a plain one, a hand-written ternary, another plain one, and a
## lifted Print whose message PARAMETER branches - so both shapes of pair are under the pointer, with
## ordinary rows above and below them to drag past and step over.
static func _editable_fixture() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "TernaryEditableFixture"
	sheet.events.append(_event(_raw("print(\"start\")")))
	sheet.events.append(_event(_raw("speed = fast_speed if sprinting else base_speed")))
	sheet.events.append(_event(_raw("print(\"between\")")))
	var lifted: ACEAction = ACEAction.new()
	lifted.provider_id = "Core"
	lifted.ace_id = "Print"
	lifted.codegen_template = "print({message})"
	lifted.params = {"message": "\"hit\" if wounded else \"miss\""}
	sheet.events.append(_event(lifted))
	return sheet


static func _event(action: Resource) -> EventRow:
	var event_row: EventRow = EventRow.new()
	event_row.trigger_provider_id = "Core"
	event_row.trigger_id = "OnReady"
	event_row.actions.append(action)
	return event_row


static func _raw(code: String) -> RawCodeRow:
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = code
	raw.enabled = true
	return raw


# ── Readers ─────────────────────────────────────────────────────────────────────────────────


## "cond => code | cond => code | (else) => code" for one statement, or "" when it does not branch.
static func _branches(code: String) -> String:
	return _join_branches(EventSheetSentence.ternary_branches(code))


static func _value_branches(value: String) -> String:
	return _join_branches(EventSheetSentence.value_branches(value))


static func _join_branches(branches: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for entry: Variant in branches:
		var branch: Dictionary = entry
		var test: String = str(branch.get("condition", ""))
		parts.append("%s => %s" % ["(else)" if test.is_empty() else test, str(branch.get("code", ""))])
	return " | ".join(parts)


static func _condition(expression: String) -> String:
	var reading: Dictionary = EventSheetSentence.condition_pieces(expression)
	var text: String = ""
	for entry: Variant in (reading.get("pieces", []) as Array):
		text += str((entry as Array)[0])
	return text


static func _condition_object(expression: String) -> String:
	return str(EventSheetSentence.condition_pieces(expression).get("object", ""))


## Every visible row as "left lane | right lane", the two lanes joined from their spans. The
## condition lane is joined LINE BY LINE with " > ", because a row can stack several condition cells
## (an else-if is an Else chip with the arm's test under it) and a flat join would run them together.
static func _row_readings(view: EventSheetViewport) -> PackedStringArray:
	var readings: PackedStringArray = PackedStringArray()
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		readings.append("%s | %s" % [_condition_lane(view, row_data), _action_lane(view, row_data)])
	return readings


## The condition lane of one row, its stacked cells joined with " > " in line order.
static func _condition_lane(view: EventSheetViewport, row_data: EventRowData) -> String:
	view._ensure_event_spans(row_data)
	var lines: Dictionary = {}
	var order: Array[int] = []
	for span: SemanticSpan in row_data.spans:
		if view._resolve_span_lane(span) != "condition":
			continue
		var line_index: int = int(span.metadata.get("line_index", 0))
		if not lines.has(line_index):
			lines[line_index] = ""
			order.append(line_index)
		# The object column is part of what a cell SAYS ("host exists"), and a conjunct read on its
		# own line hoists its object into it - so a reading that dropped it could not tell the two
		# stacked lines of `host != null and host.is_on_wall()` apart from one another.
		# "System" is the label every objectless row wears, so it says nothing about this cell.
		var object_label: String = str(span.metadata.get("object_label", "")).strip_edges()
		if object_label == EventSheetSentence.OBJECT_SYSTEM:
			object_label = ""
		if not object_label.is_empty():
			lines[line_index] = str(lines[line_index]) + object_label + " "
		lines[line_index] = str(lines[line_index]) + span.text
	order.sort()
	var parts: PackedStringArray = PackedStringArray()
	for line_index: int in order:
		var text: String = str(lines[line_index]).strip_edges()
		if not text.is_empty():
			parts.append(text)
	return " > ".join(parts)


static func _action_lane(view: EventSheetViewport, row_data: EventRowData) -> String:
	view._ensure_event_spans(row_data)
	var right: String = ""
	for span: SemanticSpan in row_data.spans:
		if view._resolve_span_lane(span) != "condition":
			right += span.text
	return right.strip_edges()


## The one reading containing `needle`, or a message naming what was found instead - so a failure
## prints the row that IS there rather than a bare false.
static func _reading_at(readings: PackedStringArray, needle: String) -> String:
	for reading: String in readings:
		if reading.contains(needle):
			return reading
	return "no row containing \"%s\"" % needle


## Readings whose ACTION lane still spells a branch. `func(` is the documented exception.
static func _branchy_readings(readings: PackedStringArray) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for reading: String in readings:
		var action_lane: String = reading.substr(reading.find(" | ") + 3)
		if _reads_as_branch(action_lane):
			found.append(reading)
	return found


## The same sweep over a whole view, span by span, so a row hidden behind a fold is checked too.
static func _branchy_action_cells(view: EventSheetViewport) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	_sweep_rows(view, view._root_rows, found)
	return found


static func _sweep_rows(view: EventSheetViewport, rows: Array, found: PackedStringArray) -> void:
	for row_data: EventRowData in rows:
		view._ensure_event_spans(row_data)
		for span: SemanticSpan in row_data.spans:
			if view._resolve_span_lane(span) != "action":
				continue
			# A verbatim GDScript cell is the escape hatch: it is SHOWN as code, so it may hold
			# anything the file holds. Only a SENTENCE cell must never read as a branch.
			if bool(span.metadata.get("code_cell", false)):
				continue
			if _reads_as_branch(span.text):
				found.append(span.text)
		_sweep_rows(view, row_data.children, found)


static func _reads_as_branch(text: String) -> bool:
	if text.contains("func("):
		return false
	return text.contains(" if ") and text.contains(" else ")


# ── Readers for the editable-sheet section ──────────────────────────────────────────────────


## The stacked line count of the one row whose action lane contains `needle` - so "two condition
## cells on the SAME row" is pinned as the height it really reserves, not only as text.
static func _line_count_at(view: EventSheetViewport, needle: String) -> int:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and _action_lane(view, row_data).contains(needle):
			return row_data.line_count
	return -1


static func _row_at(view: EventSheetViewport, index: int) -> EventRowData:
	return (view.get_flat_rows()[index] as Dictionary).get("row")


## Every flat index whose row draws `resource` - one for an ordinary event, several for a pair.
static func _rows_for(view: EventSheetViewport, resource: Resource) -> Array[int]:
	var indices: Array[int] = []
	var flat_rows: Array = view.get_flat_rows()
	for index in range(flat_rows.size()):
		var row_data: EventRowData = (flat_rows[index] as Dictionary).get("row")
		if row_data != null and row_data.source_resource == resource:
			indices.append(index)
	return indices


## The one statement uid a run of rows answers with, or every distinct one joined - so a failure
## prints the split it found instead of a bare false.
static func _distinct_statement_uids(view: EventSheetViewport, indices: Array[int]) -> String:
	var seen: PackedStringArray = PackedStringArray()
	for index: int in indices:
		var statement: String = _row_at(view, index).statement_uid()
		if not seen.has(statement):
			seen.append(statement)
	return " | ".join(seen)


## The condition lane of a pair's BRANCH rows - the rows that read one statement's arms.
static func _branch_conditions(view: EventSheetViewport, resource: Resource) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for index: int in _rows_for(view, resource):
		var row_data: EventRowData = _row_at(view, index)
		if row_data.ternary_action_index < 0:
			continue
		parts.append(_condition_lane(view, row_data))
	return " | ".join(parts)


static func _lead_flags(view: EventSheetViewport, indices: Array[int]) -> String:
	var flags: PackedStringArray = PackedStringArray()
	for index: int in indices:
		flags.append(str(_row_at(view, index).ternary_lead))
	return "/".join(flags)


static func _event_numbers(view: EventSheetViewport, indices: Array[int]) -> String:
	var numbers: PackedStringArray = PackedStringArray()
	for index: int in indices:
		numbers.append(str(_row_at(view, index).event_number))
	return "/".join(numbers)


## "<selected rows>/<same resource?>/<rows lit>" for the current selection.
static func _selection_report(view: EventSheetViewport, expected: Resource, pair: Array[int]) -> String:
	var selected: Array[EventRowData] = view.get_selected_rows()
	var same: String = "same" if selected.size() == 1 and selected[0].source_resource == expected else "other"
	var lit: int = 0
	for index: int in pair:
		if _row_at(view, index).selected:
			lit += 1
	return "%d/%s/%d" % [selected.size(), same, lit]


static func _drop_target(view: EventSheetViewport, row_index: int, drop_mode: String) -> String:
	var resolved: Dictionary = view.normalize_row_drop_target(row_index, drop_mode)
	return "%d/%s" % [int(resolved.get("index", -1)), str(resolved.get("mode", ""))]


## "same" per opened editor whose payload is the event's one branching action.
static func _opened_report(opened: Array, event_row: EventRow) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for entry: Variant in opened:
		parts.append("same" if entry == event_row.actions[0] else "other")
	return "/".join(parts)


static func _opened_metadata(opened: Array) -> String:
	if opened.size() != 1 or not (opened[0] is Dictionary):
		return "nothing opened"
	var metadata: Dictionary = opened[0]
	return "%s/%d" % [str(metadata.get("kind", "")), int(metadata.get("ace_index", -1))]


## "head" where the event's own "+ Add" affordances live, "none" on a row that carries none.
static func _scaffolding_report(view: EventSheetViewport, indices: Array[int]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for index: int in indices:
		var row_data: EventRowData = _row_at(view, index)
		view._ensure_event_spans(row_data)
		var kinds: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			var kind: String = str(span.metadata.get("kind", ""))
			if kind in ["add_action", "add_condition"] and not kinds.has(kind):
				kinds.append(kind)
		parts.append("head" if kinds.size() == 2 else ("none" if kinds.is_empty() else "/".join(kinds)))
	return "/".join(parts)


## Each event of the live sheet as its first action's code (or the lifted ACE's id) - a shape the
## reorder and delete assertions can name by VALUE.
static func _event_codes(dock: EventSheetDock) -> String:
	var codes: PackedStringArray = PackedStringArray()
	for event_entry: Variant in dock._current_sheet.events:
		if not (event_entry is EventRow) or (event_entry as EventRow).actions.is_empty():
			continue
		var action: Variant = (event_entry as EventRow).actions[0]
		if action is RawCodeRow:
			var code: String = (action as RawCodeRow).code
			codes.append("speed = ..." if code.begins_with("speed") else code)
		elif action is ACEAction:
			codes.append((action as ACEAction).ace_id)
	return " | ".join(codes)


static func _compiled(dock: EventSheetDock) -> String:
	return str(SheetCompiler.new().compile(dock._current_sheet).get("output", ""))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ternary_sub_event_test: %s" % label)
		return true
	print("[FAIL] ternary_sub_event_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
