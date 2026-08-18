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
	ok = _check("a lone ternary return replaces its row with the pair",
		_reading_at(rows, "Set return value to host's wall normal X"),
		"host exists and host is on wall | Set return value to host's wall normal X") and ok
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
	ok = _check("the chain's middle arm is its own condition row",
		_reading_at(rows, "Set tier to \"silver\""), "score > 50 | Set tier to \"silver\"") and ok
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


## Every visible row as "left lane | right lane", the two lanes joined from their spans.
static func _row_readings(view: EventSheetViewport) -> PackedStringArray:
	var readings: PackedStringArray = PackedStringArray()
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		view._ensure_event_spans(row_data)
		var left: String = ""
		var right: String = ""
		for span: SemanticSpan in row_data.spans:
			if view._resolve_span_lane(span) == "condition":
				left += span.text
			else:
				right += span.text
		readings.append("%s | %s" % [left.strip_edges(), right.strip_edges()])
	return readings


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


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ternary_sub_event_test: %s" % label)
		return true
	print("[FAIL] ternary_sub_event_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
