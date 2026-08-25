# Godot EventSheets - the four shapes an event-sheet reader expects to find
# where real GDScript writes something else.
#
#   `and` never appears INSIDE a condition cell. Each top-level conjunct is a condition line of
#        the one event (the shape a lifted `if a and b:` already draws), and a top-level `or` is the
#        OR block. Pinned here for the reading the grammar INVENTS - a ternary's branch test - which
#        was the one place still spelling the word.
#   An `await` says which tick or which signal it waits for.
#   A lambda handed to `connect` reads as the trigger event it is, with the lambda's body as its
#        rows. At the top of `_ready` it LIFTS - it becomes that event, and re-emits as the
#        statement it was written as; anywhere else the connect line stays a statement and keeps a
#        muted note beside the same reading, so nothing is hidden either way.
#   A one-line `if` / `elif` / `else` lifts as the sub-event its indented twin does, and the
#        file it came from re-emits BYTE FOR BYTE - the one thing that must never be traded away.
#
# The fixture is a real file opened the way the dock opens one (import_external), not a hand-built
# sheet: every one of these shapes is about what happens to code somebody actually wrote.
@tool
class_name OneLineBlocksAndSignalRowsTest
extends RefCounted

const FIXTURE_PATH: String = "user://eventsheets_one_line_blocks_fixture.gd"
const FPS_PACK: String = "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"
const HEALTH_PACK: String = "res://eventsheet_addons/health/health_behavior.gd"

## Every shape under test, in one ordinary-looking script. Written to disk and opened, because the
## lifter reads FILES and a fixture built in memory cannot notice a byte that does not round-trip.
const FIXTURE_SOURCE: String = """@tool
class_name OneLineBlocksFixture
extends Node

var hp: int = 10
var seconds_left: int = 3
var host: Node = null


func _ready() -> void:
	$Timer.timeout.connect(func(): seconds_left -= 1)
	host.body_entered.connect(func(body):
		seconds_left += 1
		if seconds_left <= 0:
			$Timer.stop()
	)
	await get_tree().process_frame
	await get_tree().physics_frame
	await host.tree_exited
	await get_tree().create_timer(0.5).timeout
	host.renamed.connect(func(): $Timer.stop())


func guards() -> void:
	if host == null: return
	if hp <= 0: die()
	elif hp < 5: play("low")
	else: play("hurt")
	for i in 3:
		if i == 1: continue
		if i == 2: break
		print(i)


func wall_normal_x() -> float:
	return host.get_wall_normal().x if host != null and host.is_on_wall() else 0.0


func tier() -> String:
	return "gold" if hp > 100 or seconds_left > 9 else "bronze"


func die() -> void:
	pass


func play(_name: String) -> void:
	pass
"""


static func run() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _open_fixture()
	if sheet == null:
		return _check("the fixture opens as a sheet", false, true)
	# THE contract, first and loudest: opening this file and saving it untouched reproduces it.
	ok = _check("the fixture round-trips byte for byte",
		str(SheetCompiler.new().compile(sheet).get("output", "")), FIXTURE_SOURCE) and ok
	sheet.read_only = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()
	var rows: PackedStringArray = _readings(view)
	ok = _one_line_blocks(rows) and ok
	ok = _stacked_conditions(view, rows) and ok
	ok = _awaits(rows) and ok
	ok = _connected_lambdas(view, rows) and ok
	dock.free()
	ok = _shipped_packs() and ok
	return ok


## ── a one-line block draws the rows its indented twin draws ──────────────────────────────────
static func _one_line_blocks(rows: PackedStringArray) -> bool:
	var ok: bool = true
	ok = _check("a one-line guard clause is a sub-event, not a code cell",
		_reading_at(rows, "Stop event"), "host does not exist | Stop event") and ok
	ok = _check("a one-line if calls its verb",
		_reading_at(rows, "Call Die"), "OneLineBlocksFixture hp ≤ 0 | Call Die") and ok
	# `play("low")` is this file's OWN `play`, declared at the bottom of it, so the row says so. The
	# vocabulary has verbs spelled `play(…)` too and one of them used to claim the line, which read
	# as a confident sentence about a sound this script has never had.
	ok = _check("a one-line elif is an Else with its own condition",
		_reading_at(rows, "\"low\""), "Else > OneLineBlocksFixture hp < 5 | Call Play   name = \"low\"") and ok
	ok = _check("a one-line else is the plain Else",
		_reading_at(rows, "\"hurt\""), "Else | Call Play   name = \"hurt\"") and ok
	# `i == 1` is a COMPARISON, not an identity test. Is The Same Object's reverse template is the bare
	# `{a} == {b}`, so it used to claim every equality ever written and these two rows read "i is the
	# same object as 1" - a confident lie about a loop counter and a number.
	ok = _check("a one-line continue keeps its loop meaning",
		_reading_at(rows, "Next"),
		"i = 1 | Next") and ok
	ok = _check("a one-line break does too",
		_reading_at(rows, "Stop loop"),
		"i = 2 | Stop loop") and ok
	return ok


## ── conjuncts stack, an `or` is the OR block ─────────────────────────────────────────────────
static func _stacked_conditions(view: EventSheetViewport, rows: PackedStringArray) -> bool:
	var ok: bool = true
	ok = _check("a ternary's `and` test stacks as two condition lines",
		_reading_at(rows, "Return host's wall normal X"),
		"host exists > host Is by wall | Return host's wall normal X") and ok
	# The OR is ruled BETWEEN the two lines now, so neither of them carries a badge word.
	ok = _check("a ternary's `or` test is the OR block",
		_reading_at(rows, "Return \"gold\""), "hp > 100 > seconds left > 9 | Return \"gold\"") and ok
	ok = _check("no condition cell anywhere in the fixture spells `and`",
		_conjunction_cells(view), PackedStringArray()) and ok
	return ok


## ── an await names the tick or the signal ────────────────────────────────────────────────────
static func _awaits(rows: PackedStringArray) -> bool:
	var ok: bool = true
	var ready_row: String = _reading_at(rows, "Wait one tick")
	ok = _check("a frame await reads as one tick", ready_row.contains("⏳ Wait one tick"), true) and ok
	ok = _check("a physics-frame await reads as one physics tick",
		ready_row.contains("⏳ Wait one physics tick"), true) and ok
	ok = _check("an await on a signal reads as Wait for signal",
		ready_row.contains("⏳ Wait for signal host On Tree Exited"), true) and ok
	ok = _check("the timer await keeps its seconds sentence",
		ready_row.contains("⏳ Wait 0.5 seconds"), true) and ok
	ok = _check("a bare await expression is what the grammar names, nothing else",
		_await_reading("some_object.method()"), "") and ok
	return ok


## ── a connected lambda IS a trigger event ────────────────────────────────────────────────────
static func _connected_lambdas(view: EventSheetViewport, rows: PackedStringArray) -> bool:
	var ok: bool = true
	# A lambda at the top of `_ready` is LIFTED: it is the event, so it reads the way every other
	# trigger event reads - the trigger cell on the left, what it does on the right - rather than as
	# a view drawn over a line of code.
	ok = _check("the one-line lambda is the event, body and all",
		_reading_at(rows, "➜Timer On Timeout"),
		"➜Timer On Timeout | Subtract 1 from seconds left") and ok
	ok = _check("a multi-line lambda's trigger carries its payload chip",
		_reading_at(rows, "➜host On collision with"),
		"➜host On collision withbody | Add 1 to seconds left") and ok
	# The payload used to be crammed INSIDE the trigger cell ("On Hit   body"), because a chip after a
	# trigger cell drew as a sliver. It is now the same span a declared handler's trigger row draws,
	# so one event reads one way whether it was wired with a func or with a lambda.
	ok = _check("and that chip is the shared trigger-payload span, not words inside the cell",
		_span_kinds(view, "On collision with"), "|trigger|trigger_payload|action") and ok
	# Re-pinned this one: `$Timer.stop()` is the Timer behavior's own `Stop timer "Timer"` now,
	# where it used to fall through to the generic Object ▸ Verb reading and say only "Stop".
	ok = _check("and the branch in its body is a row under the same trigger",
		_reading_at(rows, "Stop timer"),
		"➜host On collision withbody > OneLineBlocksFixture seconds left ≤ 0 | Stop timer \"Timer\"") and ok
	# A lambda the lift cannot claim - one written after other setup, where emission could not put
	# the statement back - stays a statement, and the view still reads it as the event it is.
	ok = _check("a connect the lift cannot claim keeps a muted note naming what it wires",
		_has_reading(rows, "connects host On Renamed"), true) and ok
	ok = _check("and its lambda still draws the trigger it wires",
		_reading_at(rows, "➜host On Renamed"), "➜host On Renamed | ") and ok
	ok = _check("a connect handed a NAMED function is left exactly as it was",
		_connect_parts("timer.timeout.connect(_on_timeout)"), "") and ok
	ok = _check("a connect whose lambda body is empty is refused",
		_connect_parts("timer.timeout.connect(func(): )"), "") and ok
	ok = _check("an ordinary connect-with-lambda is claimed",
		_connect_parts("$Timer.timeout.connect(func(a, b): print(a))"), "Timer/On Timeout/a,b") and ok
	return ok


## ── the shipped packs, swept cell by cell ────────────────────────────────────────────────────
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
		var rows: PackedStringArray = _readings(view)
		ok = _check("no condition cell of %s spells `and`" % path.get_file(),
			_conjunction_cells(view), PackedStringArray()) and ok
		ok = _check("no action cell of %s spells an if/else" % path.get_file(),
			_branchy_cells(rows), PackedStringArray()) and ok
		dock.free()
	return ok


# ── Fixture + readers ───────────────────────────────────────────────────────────────────────


static func _open_fixture() -> EventSheetResource:
	var file: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.WRITE)
	if file == null:
		return null
	file.store_string(FIXTURE_SOURCE)
	file.close()
	return GDScriptImporter.new().import_external(FIXTURE_PATH)


## Every visible row as "condition lane | action lane". The condition lane joins its stacked cells
## with " > " in line order, because the pairing rule is exactly about a cell becoming several LINES.
static func _readings(view: EventSheetViewport) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	_walk(view, view._root_rows, out)
	return out


static func _walk(view: EventSheetViewport, rows: Array, into: PackedStringArray) -> void:
	for row_data: EventRowData in rows:
		view._ensure_event_spans(row_data)
		var lines: Dictionary = {}
		var order: Array[int] = []
		var right: String = ""
		for span: SemanticSpan in row_data.spans:
			if view._resolve_span_lane(span) != "condition":
				right += span.text
				continue
			var line_index: int = int(span.metadata.get("line_index", 0))
			if not lines.has(line_index):
				lines[line_index] = ""
				order.append(line_index)
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
		into.append("%s | %s" % [" > ".join(parts), right.strip_edges()])
		_walk(view, row_data.children, into)


## The span KINDS, in order, of the row whose trigger cell says `trigger_text` - the shape check that
## tells a chip beside the cell apart from words crammed inside it.
static func _span_kinds(view: EventSheetViewport, trigger_text: String) -> String:
	var found: PackedStringArray = PackedStringArray()
	_sweep_span_kinds(view, view._root_rows, trigger_text, found)
	return found[0] if not found.is_empty() else "no trigger cell saying \"%s\"" % trigger_text


static func _sweep_span_kinds(view: EventSheetViewport, rows: Array, trigger_text: String,
		found: PackedStringArray) -> void:
	for row_data: EventRowData in rows:
		view._ensure_event_spans(row_data)
		var kinds: PackedStringArray = PackedStringArray()
		var matched: bool = false
		for span: SemanticSpan in row_data.spans:
			kinds.append(str(span.metadata.get("kind", "")))
			if span.text == trigger_text and str(span.metadata.get("kind", "")) == "trigger":
				matched = true
		if matched and found.is_empty():
			found.append("|".join(kinds))
		_sweep_span_kinds(view, row_data.children, trigger_text, found)


static func _reading_at(readings: PackedStringArray, needle: String) -> String:
	for reading: String in readings:
		if reading.contains(needle):
			return reading
	return "no row containing \"%s\"" % needle


## Whether ANY row's reading says this. A `contains` against `_reading_at` cannot ask it: the miss
## message quotes the needle back, so such a check passed whether the row was there or not.
static func _has_reading(readings: PackedStringArray, needle: String) -> bool:
	for reading: String in readings:
		if reading.contains(needle):
			return true
	return false


## Condition cells that still spell a conjunction, swept span by span over the EVENT rows of a whole
## view - a variable's description and a comment also draw in the left lane, and prose is allowed the
## word. A parenthesised group is the ONE documented exception: a condition LINE cannot hold a nested
## OR block, so `a and (b or c)` stacks `a` and keeps the group whole rather than inventing a
## structure the source does not have.
static func _conjunction_cells(view: EventSheetViewport) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	_sweep_conditions(view, view._root_rows, found)
	return found


static func _sweep_conditions(view: EventSheetViewport, rows: Array, found: PackedStringArray) -> void:
	for row_data: EventRowData in rows:
		if row_data.row_type == EventRowData.RowType.EVENT:
			view._ensure_event_spans(row_data)
			for span: SemanticSpan in row_data.spans:
				if not (str(span.metadata.get("kind", "")) in ["condition", "trigger"]):
					continue
				if span.text.contains("(") or span.text.contains("func"):
					continue
				if span.text.contains(" and "):
					found.append(span.text)
		_sweep_conditions(view, row_data.children, found)


## Action cells that still read as a branch. `func(` is the documented exception - a lambda body is
## a scope of its own, so no one-cell sentence can honestly stand for it.
static func _branchy_cells(readings: PackedStringArray) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for reading: String in readings:
		var action_lane: String = reading.substr(reading.find(" | ") + 3)
		if action_lane.contains("func("):
			continue
		if action_lane.contains(" if ") and action_lane.contains(" else "):
			found.append(action_lane)
	return found


## The reading of one await expression as flat text, or "" when the grammar refuses it.
static func _await_reading(expression: String) -> String:
	var reading: Dictionary = ViewportRowBuilder.await_reading(expression, false)
	var text: String = ""
	for entry: Variant in (reading.get("segments", []) as Array):
		text += str((entry as Dictionary).get("text", ""))
	return text


## "object/trigger/args" for a connect statement the reader claims, "" when it refuses it.
static func _connect_parts(code: String) -> String:
	var parts: Dictionary = ViewportRowBuilder.connect_lambda_parts(code)
	if parts.is_empty():
		return ""
	return "%s/%s/%s" % [
		str(parts.get("object", "")), str(parts.get("trigger", "")),
		",".join(parts.get("args", PackedStringArray()))]


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] one_line_blocks_and_signal_rows_test: %s" % label)
		return true
	print("[FAIL] one_line_blocks_and_signal_rows_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
