# Godot EventSheets - the compiled shape of an object's states, and the lift back out of it.
#
# THE CANONICAL SHAPE is the whole of this file's subject. An object's state is a variable, so the
# machine compiles to the four lines a person writes by hand - an enum, a typed variable that
# announces its own change, the comparison, the assignment - and nothing else. That is pinned here as
# BYTES, because "reads as if written fresh" is not a thing a test can ask about a shape it does not
# have in front of it.
#
# And then both directions of the same promise:
#
#   OUT  a sheet authored with these rows emits exactly that shape;
#   IN   a file written in that shape - by this compiler, or by a person who never heard of it -
#        opens as those rows again, to the byte.
#
# Which together are IDENTITY: author, save, close, open, save again, and the file has not moved. The
# three fixtures beside this file are the in-direction measured on code nobody wrote for a test: two
# canonical machines spelled the two ways people spell them, and one deliberately non-canonical
# machine that must stay honest code and keep its bytes anyway.
@tool
class_name ObjectStateLiftTest
extends RefCounted

## The three hand-written machines, and what each is here to prove.
const PATROL: String = "res://tests/fixtures/handwritten_state_patrol.gd"
const ANNOUNCED: String = "res://tests/fixtures/handwritten_state_announced.gd"
const WOVEN: String = "res://tests/fixtures/handwritten_state_woven.gd"

## The states the authored sheet below declares, and the one it opens in.
const DECLARED: PackedStringArray = ["Patrol", "Chase", "Stagger"]
const STARTS_IN: String = "Patrol"

## What that sheet compiles to, to the byte. Every line of it is a line a person writes by hand: an
## enum, a signal, three variables, the setter that announces a change, and plain `if`s. There is no
## runtime, no base class and no registry anywhere in it, and this string is how that stays true.
const CANONICAL: String = """extends CharacterBody2D

enum State { PATROL, CHASE, STAGGER }

signal state_changed(from_state: int, to_state: int)

var state_entered_msec: int = 0
var previous_state: State = State.PATROL
var state: State = State.PATROL:
	set(value):
		if value == state:
			return
		var was: int = state
		previous_state = was
		state = value
		state_entered_msec = Time.get_ticks_msec()
		state_changed.emit(was, value)

func _ready() -> void:
	state_changed.connect(_on_state_changed)

func _process(delta: float) -> void:
	if state == State.PATROL:
		state = State.CHASE
	if state == State.STAGGER and (Time.get_ticks_msec() - state_entered_msec) / 1000.0 > 2.0:
		state = State.PATROL
	if previous_state == State.CHASE:
		state = State.STAGGER

func _on_state_changed(from_state: int, to_state: int) -> void:
	if from_state == State.STAGGER:
		state = State.PATROL
	if to_state == State.CHASE:
		state = State.PATROL
"""


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_canonical_shape() and ok
	ok = _test_authored_then_reopened_is_identity() and ok
	ok = _test_the_hand_written_machines() and ok
	ok = _test_the_readings() and ok
	ok = _test_a_non_canonical_handler_is_left_alone() and ok
	return ok


# ── OUT: what the machine compiles to ───────────────────────────────────────────────────────────
static func _test_the_canonical_shape() -> bool:
	var emitted: String = _body_of(_emit(_authored_sheet()))
	var ok: bool = _check("the machine compiles to the canonical shape", emitted, CANONICAL)
	if not ok:
		print("  --- emitted ---\n%s" % emitted)
	# Said again as the three things that must NOT be in it, so a failure names what went wrong
	# rather than handing a reader two walls of text to diff.
	ok = _check("nothing in it extends a base class of ours", emitted.contains("EventForge"), false) and ok
	ok = _check("nothing in it calls a runtime", emitted.contains("_eventforge"), false) and ok
	ok = _check("going to a state is one plain assignment",
		emitted.contains("\t\tstate = State.CHASE"), true) and ok
	return ok


# ── IN, from our own output: authored, saved, reopened, and unmoved ─────────────────────────────
static func _test_authored_then_reopened_is_identity() -> bool:
	var ok: bool = true
	var source: String = _emit(_authored_sheet())
	var reopened: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	ok = _check("reopening our own output gives the rows back", _reading_of(reopened.events),
		PackedStringArray([
			"OnProcess: InState PATROL -> GoToState CHASE",
			"OnProcess: InStateForOver STAGGER 2.0 -> GoToState PATROL",
			"OnProcess: WasInState CHASE -> GoToState STAGGER",
			"OnLeavingState STAGGER -> GoToState PATROL",
			"OnEnteringState CHASE -> GoToState PATROL"
		])) and ok
	reopened.external_source_path = "user://object_state_identity.gd"
	var again: String = str(SheetCompiler.compile(reopened, "user://object_state_identity.gd").get("output", ""))
	ok = _check("and saving it again moves no byte", again, source) and ok
	return ok


# ── IN, from somebody else's file ───────────────────────────────────────────────────────────────
static func _test_the_hand_written_machines() -> bool:
	var ok: bool = true
	for path: String in [PATROL, ANNOUNCED, WOVEN]:
		ok = _check("%s is present to be measured" % path.get_file(),
			FileAccess.file_exists(path), true) and ok
	# The byte promise, on all three at once - the assertion that must never be relaxed.
	var drifted: PackedStringArray = PackedStringArray()
	for path: String in [PATROL, ANNOUNCED, WOVEN]:
		if not FileAccess.file_exists(path):
			continue
		var source: String = FileAccess.get_file_as_string(path)
		if _emit(GDScriptImporter.new().import_external(path)) != source:
			drifted.append(path.get_file())
	ok = _check("every hand-written machine round-trips byte-identically",
		drifted, PackedStringArray()) and ok

	# The announced machine is the canonical shape spelled by hand, so every row of it comes back -
	# including the timed question (which the condition splitter would otherwise hand back as two
	# half-rows) and the `self.` spelling of going to a state.
	var announced: EventSheetResource = GDScriptImporter.new().import_external(ANNOUNCED)
	ok = _check("a hand-written canonical machine opens as the state rows", _reading_of(announced.events),
		PackedStringArray([
			"OnProcess: InState IDLE -> GoToState ALERT",
			"OnProcess: InStateForOver ALERT 1.5 -> GoToState HUNT",
			"OnProcess: WasInState HUNT -> GoToState IDLE",
			"OnLeavingState HUNT -> AudioStop",
			"OnEnteringState ALERT -> CallMethod"
		])) and ok

	# The woven one is not the canonical shape, and the honest answer is the one it gets: no state
	# triggers, no state conditions, and its bytes untouched (asserted above with the other two).
	var woven: EventSheetResource = GDScriptImporter.new().import_external(WOVEN)
	ok = _check("a non-canonical machine claims no state trigger",
		_triggers_of(woven.events), PackedStringArray(["OnProcess"])) and ok
	return ok


# ── The reading a match arm gets ────────────────────────────────────────────────────────────────
static func _test_the_readings() -> bool:
	var ok: bool = true
	var patrol: EventSheetResource = GDScriptImporter.new().import_external(PATROL)
	var machine: MatchRow = _first_match(patrol.events)
	ok = _check("the tutorial machine opens as a match on the state variable",
		machine != null and EventSheetStateFacts.is_state_subject(machine.match_expression), true) and ok
	if machine != null:
		var arms: PackedStringArray = PackedStringArray()
		for arm: MatchCase in machine.cases:
			arms.append(EventSheetStateFacts.arm_reading(arm.pattern))
		ok = _check("and every arm of it reads as the Is in row it means", arms,
			PackedStringArray(["Is in Patrol", "Is in Chase", "Is in Stagger"])) and ok
	# The lines INSIDE an arm are kept verbatim so the match re-emits to the byte, so the only thing
	# that can be done for them is to read them as what they are.
	ok = _check("a state assignment inside an arm reads as the Go to row it means",
		EventSheetStateFacts.statement_reading("\t\t\tstate = State.CHASE"), "Go to Chase") and ok
	ok = _check("and an ordinary line in an arm is not claimed",
		EventSheetStateFacts.statement_reading("\t\t\tvelocity.x = speed"), "") and ok
	ok = _check("the catch-all arm keeps its own pattern", EventSheetStateFacts.arm_reading("_"), "") and ok
	ok = _check("and so does a binding arm", EventSheetStateFacts.arm_reading("var pending"), "") and ok
	return ok


# ── The order that makes a handler adoptable, and the one that does not ─────────────────────────
static func _test_a_non_canonical_handler_is_left_alone() -> bool:
	# The compiler emits every leaving arm before every entering arm, always. A hand-written handler
	# that runs them the other way round is somebody else's function that happens to share a name, and
	# adopting it would silently reorder their code - so it keeps the rows the general lift gave it.
	var source: String = """extends Node

signal state_changed(from_state: int, to_state: int)

enum State { IDLE, BUSY }

var state_entered_msec: int = 0
var previous_state: State = State.IDLE
var state: State = State.IDLE:
	set(value):
		if value == state:
			return
		var was: int = state
		previous_state = was
		state = value
		state_entered_msec = Time.get_ticks_msec()
		state_changed.emit(was, value)

func _ready() -> void:
	state_changed.connect(_on_state_changed)

func _on_state_changed(from_state: int, to_state: int) -> void:
	if to_state == State.BUSY:
		set_process(true)
	if from_state == State.BUSY:
		set_process(false)
"""
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var ok: bool = _check("an entering-before-leaving handler is not adopted",
		_triggers_of(sheet.events), PackedStringArray(["signal:state_changed", "signal:state_changed"]))
	sheet.external_source_path = "user://object_state_order.gd"
	var again: String = str(SheetCompiler.compile(sheet, "user://object_state_order.gd").get("output", ""))
	ok = _check("and it keeps its bytes", again, source) and ok
	return ok


# ── The pieces ──────────────────────────────────────────────────────────────────────────────────
## The sheet an author builds through the states band and the Object State rows: three states, the
## three questions and the two change triggers, in the order the picker would have added them.
static func _authored_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	EventSheetStatesDialog.write(sheet, DECLARED, STARTS_IN)
	sheet.events.append(_event("OnProcess", {},
		[_ace("InState", {"state": "PATROL"}, true)], [_ace("GoToState", {"state": "CHASE"}, false)]))
	sheet.events.append(_event("OnProcess", {},
		[_ace("InStateForOver", {"state": "STAGGER", "seconds": "2.0"}, true)],
		[_ace("GoToState", {"state": "PATROL"}, false)]))
	sheet.events.append(_event("OnProcess", {},
		[_ace("WasInState", {"state": "CHASE"}, true)], [_ace("GoToState", {"state": "STAGGER"}, false)]))
	sheet.events.append(_event("OnLeavingState", {"state": "STAGGER"}, [],
		[_ace("GoToState", {"state": "PATROL"}, false)]))
	sheet.events.append(_event("OnEnteringState", {"state": "CHASE"}, [],
		[_ace("GoToState", {"state": "PATROL"}, false)]))
	return sheet


static func _event(trigger_id: String, trigger_params: Dictionary, conditions: Array,
		actions: Array) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = trigger_id
	row.trigger_params = trigger_params
	for condition: Variant in conditions:
		row.conditions.append(condition as ACECondition)
	for action: Variant in actions:
		row.actions.append(action as Resource)
	return row


## One row of the vocabulary, with its template taken off the shipped descriptor - the same bake the
## dock does at apply time, so what this test compiles is what an authored sheet compiles.
static func _ace(ace_id: String, params: Dictionary, is_condition: bool) -> Resource:
	var template: String = ""
	for descriptor: ACEDescriptor in EventForgeObjectStateACEs.get_descriptors():
		if descriptor.ace_id == ace_id:
			template = descriptor.codegen_template
	if is_condition:
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = "Core"
		condition.ace_id = ace_id
		condition.params = params
		condition.codegen_template = template
		return condition
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	action.codegen_template = template
	return action


static func _emit(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.compile(sheet, "user://object_state_shape.gd").get("output", ""))


## The same output with the compiler's own three-line "regenerated on every compile" header taken
## off. The header is a fact about the file, not about the machine, and it names a path - so the
## shape is pinned from `extends` down and the header is left to the tests that are about it.
static func _body_of(emitted: String) -> String:
	var at: int = emitted.find("extends ")
	return emitted if at < 0 else emitted.substr(at)


## Every event row of a sheet as one line each: the trigger it answers, the questions it asks and the
## steps it takes. Values, not counts - a reading that changed says which row and how.
static func _reading_of(items: Array) -> PackedStringArray:
	var read: PackedStringArray = PackedStringArray()
	for item: Variant in items:
		var row: EventRow = item as EventRow
		if row == null or row.trigger_id.is_empty():
			continue
		var head: String = row.trigger_id
		if row.trigger_params.has("state"):
			head += " %s" % str(row.trigger_params["state"])
		var asked: PackedStringArray = PackedStringArray()
		for condition: ACECondition in row.conditions:
			asked.append(_said(condition.ace_id, condition.params))
		var done: PackedStringArray = PackedStringArray()
		for action: Variant in row.actions:
			if action is ACEAction:
				done.append(_said((action as ACEAction).ace_id, (action as ACEAction).params))
		var head_and_questions: String = head if asked.is_empty() else "%s: %s" % [head, " + ".join(asked)]
		read.append("%s -> %s" % [head_and_questions, " + ".join(done)])
	return read


## One row said in its own id and the values that matter to this test - the state, and the seconds
## when it has them. Nothing else, so an unrelated parameter cannot break a pin.
static func _said(ace_id: String, params: Dictionary) -> String:
	var said: String = ace_id
	if params.has("state"):
		said += " %s" % str(params["state"])
	if params.has("seconds"):
		said += " %s" % str(params["seconds"])
	return said


static func _triggers_of(items: Array) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for item: Variant in items:
		var row: EventRow = item as EventRow
		if row != null and not row.trigger_id.is_empty():
			found.append(row.trigger_id)
	return found


static func _first_match(items: Array) -> MatchRow:
	for item: Variant in items:
		var row: EventRow = item as EventRow
		if row == null:
			continue
		for action: Variant in row.actions:
			if action is MatchRow:
				return action as MatchRow
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] object_state_lift_test: %s" % label)
		return true
	print("[FAIL] object_state_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
