# EventForge - a hand-written state machine, read back as the object's own states.
#
# THE CANONICAL SHAPE. An object whose author wrote its states by hand wrote this, and the compiler
# writes exactly the same thing, which is why the two meet in the middle:
#
#     enum State { PATROL, CHASE, STAGGER }
#     var state: State = State.PATROL
#     ...
#     state = State.CHASE                                    # Go to Chase
#     if state == State.PATROL:                              # Is in Patrol
#     if previous_state == State.CHASE:                      # Was in Chase
#
# Three of those four lines are claimed by the general reverse index already, on the strength of the
# Object State descriptors' own templates - there is nothing for a table to add and this file
# deliberately does not add one. What is claimed HERE is what that index cannot reach:
#
#   THE TIMED QUESTION, claimed WHOLE. `state == State.STAGGER and (Time.get_ticks_msec() -
#   state_entered_msec) / 1000.0 > 2.0` reads to the condition splitter as two unrelated questions -
#   "is in Stagger" AND some arithmetic - and two rows that separately mean half a sentence are worse
#   than one. Claimed whole it is the row that wrote it: Is in Stagger for over 2s. Without this, a
#   sheet that AUTHORED that row and reopened its own file would not get the row back, which is the
#   one thing an authored-then-reopened file must never do.
#
#   THE `self.` SPELLINGS. `self.state = State.CHASE` is the same step as `state = State.CHASE` and a
#   great many hand-written machines write it that way, usually because the file also has a `state`
#   parameter somewhere. The general index does not claim it (the descriptor's template has no
#   receiver), so it used to read as a plain property set. The author's own spelling rides back out
#   untouched, because the matched line is what gets baked onto the row.
#
# AND THE CHANGE HANDLER, which is not a table entry at all because it is a whole function rather
# than a statement: see `adopt_change_handler` at the foot of this file.
#
# THE SAME MACHINE ONE LEVEL UP is the game's mode (`_on_mode_changed`, `enum Mode`, `var mode`), and
# the same machine in its older form is the State Machine behaviour pack's String state. Both are
# frozen and both keep working; this file is about the object's own enum and touches neither.
@tool
class_name EventForgeStateLift
extends RefCounted

## The Object State vocabulary, read for the templates the entries below are built from rather than
## copied beside them. By path, like every other constant the lifter holds, so the importer never
## waits on the editor's class cache.
const ObjectStateACEs := preload("res://addons/eventforge/registration/modules/object_state_aces.gd")

## The declarations this family recognises, spelled once. They are the frozen names the states band
## writes and a hand-written machine already uses; a machine that spells them differently is somebody
## else's design and is left alone (see `adopt_change_handler`).
const ENUM_NAME: String = "State"
const STATE_VARIABLE: String = "state"
const CHANGED_SIGNAL: String = "state_changed"

## One enum member, as the author may have spelled it.
const MEMBER: String = "[A-Za-z_][A-Za-z0-9_]*"

## The two arguments the shared `_on_state_changed(from_state, to_state)` handler is handed - what we
## left, and what we are entering. Written by the compiler and by hand in exactly this form.
const LEFT_ARGUMENT: String = "from_state"
const ENTERED_ARGUMENT: String = "to_state"

## The trigger each of those two arguments means a row is about, and the parameter naming the state.
const LEAVING_TRIGGER_ID: String = "OnLeavingState"
const ENTERING_TRIGGER_ID: String = "OnEnteringState"
const STATE_PARAM: String = "state"

## The row a lifted change-handler arm arrives as before it is adopted: one comparison of one of the
## handler's arguments against one member of the enum.
const COMPARISON_ACE_ID: String = "CompareVar"

static var _conditions: Array[Dictionary] = []
static var _actions: Array[Dictionary] = []


## The whole `if` expression, when it is the timed question. Asked before the splitter for the reason
## the file header gives: both halves together are one row, and separately they are two half-rows.
static func match_whole_condition(line: String) -> Dictionary:
	var text: String = line.strip_edges()
	if not text.contains("state_entered_msec"):
		return {}
	return EventForgeLiftTable.match_line(condition_entries(), text)


## One TERM of a condition - the `self.` spelling of Is in, which the general index has no template
## for. Everything else this vocabulary asks is claimed by that index already.
static func match_condition(term: String) -> Dictionary:
	var text: String = term.strip_edges()
	if not text.begins_with("self."):
		return {}
	return EventForgeLiftTable.match_line(condition_entries(), text)


## One statement - the `self.` spelling of Go to, for the same reason.
static func match_line(line: String) -> Dictionary:
	var text: String = line.strip_edges()
	if not text.begins_with("self."):
		return {}
	return EventForgeLiftTable.match_line(action_entries(), text)


## Every entry, for the harness and the validator. Both halves under the one name the scan looks for -
## an entry that exists in one place and is tested from another is the one way an entry ships untested.
static func lift_entries() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	all.append_array(condition_entries())
	all.append_array(action_entries())
	return all


## The questions, built once for the life of the session: they run over every `if` of every opened
## file, and the table compiles each pattern once.
static func condition_entries() -> Array[Dictionary]:
	if not _conditions.is_empty():
		return _conditions
	_conditions = [
		_entry("in_state_for_over", "InStateForOver",
			"^%s == %s\\.(?<state>%s) and \\(Time\\.get_ticks_msec\\(\\) - state_entered_msec\\) / 1000\\.0 > (?<seconds>.+)$"
				% [STATE_VARIABLE, ENUM_NAME, MEMBER],
			["state", "seconds"], {"state": "STAGGER", "seconds": "2.0"}),
		_entry("in_state_on_self", "InState",
			"^self\\.%s == %s\\.(?<state>%s)$" % [STATE_VARIABLE, ENUM_NAME, MEMBER],
			["state"], {"state": "PATROL"}, "self.")
	]
	# THE WAIT IS ONE EXPRESSION, NOT THE REST OF THE LINE. The tail is greedy on purpose - a wait may
	# be `stagger_time * 2` and a pattern that stopped at the first space would not claim it - but the
	# claim is asked before the condition splitter, so without this a third term rides in with it:
	# `... > 2.0 and hp > 0` became ONE row reading "Is in Stagger for over 2.0 and hp > 0s", and an
	# `or` became a single AND-condition where the file said OR. The bytes still round-tripped, which
	# is exactly why nothing caught it - until somebody edited that cell and the emitted boolean
	# structure changed wholesale. A compound line is left to the splitter, which turns it back into
	# the terms it is made of.
	_conditions[0]["guard"] = func(captured: Dictionary) -> bool:
		return not joins_another_term(str(captured.get("seconds", "")))
	return _conditions


## True when this expression is really an expression AND something else - it carries a top-level
## `and` or `or`. Bracketed and quoted text is skipped, because `(a and b)` and `"and"` are one
## value, and a wait may legitimately be either.
static func joins_another_term(expression: String) -> bool:
	var depth: int = 0
	var quote: String = ""
	var word: String = ""
	var text: String = expression + " "
	for index: int in range(text.length()):
		var character: String = text[index]
		if not quote.is_empty():
			if character == quote and (index == 0 or text[index - 1] != "\\"):
				quote = ""
			continue
		if character == "\"" or character == "'":
			quote = character
			continue
		if character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		if character.is_valid_identifier() or character.is_valid_int():
			word += character
			continue
		if depth == 0 and (word == "and" or word == "or"):
			return true
		word = ""
	return false


## And the one verb: going to a state, written onto `self`.
static func action_entries() -> Array[Dictionary]:
	if not _actions.is_empty():
		return _actions
	_actions = [
		_entry("go_to_state_on_self", "GoToState",
			"^self\\.%s = %s\\.(?<state>%s)$" % [STATE_VARIABLE, ENUM_NAME, MEMBER],
			["state"], {"state": "CHASE"}, "self.")
	]
	return _actions


## One entry, with its canonical spelling DERIVED from the descriptor whose template the compiler
## emits rather than written down a second time beside it. Two spellings of one template is how a
## table quietly stops recognising the rows its own sheet writes: the descriptor changes, the copy
## does not, and the entry goes on matching a line nothing emits any more.
##
## `receiver` is the prefix a spelling puts in front of the member operation ("self." or nothing).
## An entry whose descriptor cannot be found REFUSES rather than guesses - the validator turns that
## sentence into a failing suite naming the entry, which is the only honest answer when the thing an
## entry is derived from is not there.
static func _entry(id: String, ace_id: String, pattern: String, params: Array[String],
		slots: Dictionary, receiver: String = "") -> Dictionary:
	var template: String = _template_of(ace_id)
	if template.is_empty():
		return {"id": id, "error": "no Object State descriptor named %s to take a spelling from" % ace_id}
	return {
		"id": id,
		"ace_id": ace_id,
		"pattern": pattern,
		"params": params,
		"shape": receiver + template,
		"slots": slots
	}


## The codegen template of one Object State descriptor, or "" when there is none by that id.
static func _template_of(ace_id: String) -> String:
	for descriptor: ACEDescriptor in ObjectStateACEs.get_descriptors():
		if descriptor.ace_id == ace_id:
			return descriptor.codegen_template
	return ""


# ── The change handler ──────────────────────────────────────────────────────────────────────────
## `_on_state_changed(from_state, to_state)` is not a statement, so it is not a table entry: it is a
## whole function, and it arrives from the general lift as a run of signal-handler rows, each holding
## one comparison of one of the handler's two arguments -
##
##     func _on_state_changed(from_state: int, to_state: int) -> void:
##         if from_state == State.STAGGER:      # a row: the state_changed handler, comparing from_state
##             ...
##         if to_state == State.CHASE:          # another row, comparing to_state
##             ...
##
## which is honest but says the mechanism instead of the meaning. Adopted, they are the two rows that
## wrote them: On leaving Stagger, and On entering Chase.
##
## THE ORDER IS THE GATE. The compiler emits every leaving arm before every entering arm, always,
## because the room is emptied before the next one is filled - so a handler that reads leaving-then-
## entering is the canonical shape and re-emits to the byte, and one that interleaves them is somebody
## else's function that happens to share a name. This adopts the first and leaves the second exactly
## as it found it, which is what "a non-canonical shape stays honest code" means here.
##
## Returns the rows it changed, each with what it changed them from, so a caller that finds the bytes
## moved can put them back. The caller's byte gate is the second half of this promise: this function
## decides what CAN be adopted, and the compile decides whether it was right.
static func adopt_change_handler(sheet: EventSheetResource) -> Array[Dictionary]:
	var undo: Array[Dictionary] = []
	if sheet == null:
		return undo
	var arms: Array[EventRow] = _change_handler_arms(sheet.events)
	if arms.is_empty():
		return undo
	var seen_entering: bool = false
	for row: EventRow in arms:
		var argument: String = str((row.conditions[0] as ACECondition).params.get("var_name", ""))
		if argument == ENTERED_ARGUMENT:
			seen_entering = true
		elif seen_entering:
			# A leaving arm AFTER an entering one: this function does not run in the order the
			# compiler writes, so adopting it would move bytes. Left whole, and nothing is adopted.
			return _restore(undo)
	for row: EventRow in arms:
		var comparison: ACECondition = row.conditions[0]
		var argument: String = str(comparison.params.get("var_name", ""))
		var member: String = str(comparison.params.get("value", "")).strip_edges() \
			.trim_prefix("%s." % ENUM_NAME)
		var kept: Array[ACECondition] = row.conditions.duplicate()
		undo.append({
			"row": row, "trigger_id": row.trigger_id, "provider": row.trigger_provider_id,
			"params": row.trigger_params.duplicate(), "conditions": kept
		})
		row.trigger_provider_id = "Core"
		row.trigger_id = ENTERING_TRIGGER_ID if argument == ENTERED_ARGUMENT else LEAVING_TRIGGER_ID
		row.trigger_params = {STATE_PARAM: member}
		row.conditions = [] as Array[ACECondition]
	return undo


## Puts every adopted row back exactly as it was found. Called by the caller's byte gate, and by the
## order check above when it decides nothing may be adopted at all.
static func _restore(undo: Array[Dictionary]) -> Array[Dictionary]:
	for record: Dictionary in undo:
		var row: EventRow = record["row"] as EventRow
		row.trigger_id = str(record["trigger_id"])
		row.trigger_provider_id = str(record["provider"])
		row.trigger_params = (record["params"] as Dictionary).duplicate()
		var kept: Array[ACECondition] = record["conditions"]
		row.conditions = kept
	return []


## Public undo, for a caller whose byte gate refused what was adopted.
static func restore(undo: Array[Dictionary]) -> void:
	_restore(undo)


## The rows of a lifted `_on_state_changed`, or empty when this sheet has none in the adoptable
## shape. Every row of the run must be one comparison of one of the handler's arguments against one
## member of the enum and nothing else: a row carrying a second condition is asking something the two
## triggers cannot say, and one arm that cannot be adopted means none of them are (the handler emits
## as a whole, so half of it in trigger rows and half in the signal rows would emit twice).
static func _change_handler_arms(events: Array) -> Array[EventRow]:
	var arms: Array[EventRow] = []
	for entry: Variant in events:
		var row: EventRow = entry as EventRow
		if row == null or not row.trigger_id.begins_with("signal:"):
			continue
		if row.trigger_id.substr(7) != CHANGED_SIGNAL:
			continue
		if row.conditions.size() != 1:
			return []
		var comparison: ACECondition = row.conditions[0]
		if comparison.ace_id != COMPARISON_ACE_ID or comparison.negated or not comparison.enabled:
			return []
		var argument: String = str(comparison.params.get("var_name", ""))
		if not (argument == LEFT_ARGUMENT or argument == ENTERED_ARGUMENT):
			return []
		if str(comparison.params.get("op", "")) != "==":
			return []
		if not str(comparison.params.get("value", "")).strip_edges().begins_with("%s." % ENUM_NAME):
			return []
		arms.append(row)
	return arms
