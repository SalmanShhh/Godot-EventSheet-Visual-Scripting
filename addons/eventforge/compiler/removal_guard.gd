# EventForge - the removal guard: the one rule that decides when a removal row is wrapped in
# `is_instance_valid(...)`, and the line it writes when it is.
#
# THE PROBLEM, in two lines of somebody's game:
#
#     var boss = Boss.instantiate()      # in one event
#     boss.queue_free()                  # in another, three frames later
#
# The second line is a crash the moment anything else removed the boss first, and it is the single
# commonest way a sheet meets Godot's "previously freed" error. The answer Godot itself gives is
# `is_instance_valid`, so that is what this writes:
#
#     if is_instance_valid(boss):
#         boss.queue_free()
#
# AND IT IS NEVER SILENT. The compiler emits the guard and the ROW SHOWS IT, as the exact line the
# file holds, echoed beside the sentence in the script editor's own colours. A reader who does not
# want it can see it, find it, and delete the thing that asked for it. A guard nobody can see would
# be magic, and magic in emitted code is the one thing this plugin does not do.
#
# THE RULE, stated once and applied nowhere else. A name is MAYBE-GONE when it outlives the line
# that set it, which is exactly one situation:
#
#   A STORED NODE REFERENCE. The sheet declares a variable whose type is a Node, so the value
#   survives from frame to frame and nothing about this event put it there.
#
# Everything else is left alone: `self` is never gone, a node path re-resolves every time it is
# read, a call answers for itself, and a literal is a literal.
#
# AND A COPY NAMED IN ANOTHER EVENT IS NOT ONE OF THEM, though it looks like the same problem. A
# spawn row's name is a LOCAL - `var boss = Boss.instantiate()` - scoped to the handler it was
# written in and, under a condition, to that `if`. A removal row in another event saying `boss` does
# not compile at all, guard or no guard: the file reads "Identifier "boss" not declared in the
# current scope", and wrapping it in `is_instance_valid(boss)` only adds a second line that cannot
# see the name either. The one shape where it DOES parse - two unconditioned events in the same
# handler - is a check between two lines of the same run, where it can only ever be true. So the
# guard says nothing about minted names: a rule whose every reachable case is either a broken file or
# a no-op, echoed on the row as protection, is worse than no rule.
#
# AND IT STANDS DOWN WHEN THE SHEET ALREADY ASKED. An event whose own condition (or an enclosing
# event's) is "Object Still Exists" / "Is Still Here" on the same name has already asked the
# question, so a second `if` inside the first would say it twice and, worse, would change the bytes
# of a file that was opened with the guard written by hand. The sheet's own guard wins; this one
# only fills a gap.
#
# WHICH ROWS. The three removal actions, and no others. A guard bolted onto every row in the
# language would rewrite every sheet that already exists, and the contract here is that emitted code
# does not change under anybody's feet. The condition below is not guarded because it IS the guard.
@tool
class_name EventForgeRemovalGuard
extends RefCounted

## The call the guard writes, and the whole of what it writes.
const GUARD_CALL: String = "is_instance_valid"

## The rows whose object this rule protects, each with the parameter that names it. Removal rows
## only: each of these reaches straight into the object on its first emitted line (a `queue_free`, a
## `create_timer(...).connect(<object>.queue_free)`, a `create_tween()` on it), and reaching into a
## freed object is the error this exists to stop.
const GUARDED_ACE_IDS: Dictionary = {
	"RemoveNow": "object",
	"RemoveAfterSeconds": "object",
	"FadeOutAndRemove": "object",
}

## The rows that ASK the question, with the parameter that names what they ask about. An event
## carrying one of these stands the guard down for that name. Both spellings are here because both
## exist: the shipped Object Still Exists row and the Is Still Here sentence beside it compile to the
## same call, so a sheet that used either has already asked.
const ASKING_ACE_IDS: Dictionary = {
	"IsValidInstance": "object",
	"IsStillHere": "object",
}


## What this sheet's names mean, gathered once per compile (and once per canvas sweep): {"stored":
## {name: true}, "asked": {event_uid: {name: true}}}. Handed to `guard_expression` for every row, so
## the walk over the sheet happens once rather than per action - and so the compiler and the row
## builder answer from ONE derivation rather than from two that can drift.
static func facts(sheet: EventSheetResource) -> Dictionary:
	var stored: Dictionary = {}
	var asked: Dictionary = {}
	if sheet == null:
		return {"stored": stored, "asked": asked}
	for key: Variant in sheet.variables.keys():
		var descriptor: Variant = sheet.variables[key]
		if descriptor is Dictionary and _is_node_type(str((descriptor as Dictionary).get("type", ""))):
			stored[str(key)] = true
	_collect(sheet.events, stored, asked, {})
	return {"stored": stored, "asked": asked}


## The expression a row must be guarded on, or "" when it must not be.
static func guard_expression(action: ACEAction, event_row: EventRow, sheet_facts: Dictionary) -> String:
	if action == null or not action.enabled or not GUARDED_ACE_IDS.has(action.ace_id):
		return ""
	var name: String = str(_params_of(action).get(str(GUARDED_ACE_IDS[action.ace_id]), "")).strip_edges()
	# Only a bare name can be maybe-gone in the sense this rule means. `self`, `$Path`, `%Unique`, a
	# call and a literal all answer for themselves every time the line runs.
	if not name.is_valid_identifier() or name == "self":
		return ""
	# The questions this row already sits inside: its own event's, and every enclosing event's, which
	# the walk below recorded against this event's uid.
	var inherited: Dictionary = (sheet_facts.get("asked", {}) as Dictionary).get(
		"" if event_row == null else event_row.event_uid, {})
	if inherited.has(name) or _event_asks_about(event_row, name):
		return ""
	return name if bool((sheet_facts.get("stored", {}) as Dictionary).get(name, false)) else ""


## The guard's line, at an indent: the exact text the file gets, and the exact text the row echoes.
static func guard_line(expression: String, indent: String = "") -> String:
	return "%sif %s(%s):" % [indent, GUARD_CALL, expression]


## The names an event ASKS about in its own condition cells.
static func asked_names(event_row: EventRow) -> Dictionary:
	var names: Dictionary = {}
	if event_row == null:
		return names
	for entry: Variant in event_row.conditions:
		var name: String = _asked_name(entry)
		if not name.is_empty():
			names[name] = true
	return names


# ── the pieces ──────────────────────────────────────────────────────────────────


## True when a declared type is a node - the only kind of stored value that can be freed out from
## under a sheet. "Object" counts: it is what a sheet writes when it holds something it cannot name a
## class for, and `is_instance_valid` is exactly the question for it.
static func _is_node_type(type_name: String) -> bool:
	var text: String = type_name.strip_edges()
	if text.is_empty() or not ClassDB.class_exists(text):
		return false
	return text == "Object" or ClassDB.is_parent_class(text, "Node")


## Walks every row of a sheet once, filling the stored-reference map and the per-event record of
## which names an ENCLOSING event has already asked about. Recursive because a variable can be
## declared in a sub-event and is still a name the file holds - and because a sub-event runs inside
## its parent's `if`, which is what makes the parent's question its own.
static func _collect(rows: Array, stored: Dictionary, asked: Dictionary,
		inherited: Dictionary) -> void:
	for entry: Variant in rows:
		if entry is LocalVariable:
			var declared: LocalVariable = entry as LocalVariable
			if not declared.name.strip_edges().is_empty() and _is_node_type(declared.type_name):
				stored[declared.name.strip_edges()] = true
			continue
		if not (entry is EventRow):
			continue
		var event_row: EventRow = entry as EventRow
		if not event_row.event_uid.is_empty() and not inherited.is_empty():
			asked[event_row.event_uid] = inherited
		_collect(event_row.sub_events, stored, asked,
			inherited.merged(asked_names(event_row), true))


## True when one of the event's own conditions already asks whether `name` is still here.
static func _event_asks_about(event_row: EventRow, name: String) -> bool:
	if event_row == null:
		return false
	for entry: Variant in event_row.conditions:
		if _asked_name(entry) == name:
			return true
	return false


## The name one condition asks about, or "". A NEGATED ask is not an ask: `not is_instance_valid(x)`
## is the branch where x is gone, and a removal inside it needs the guard more than anywhere else.
static func _asked_name(entry: Variant) -> String:
	var condition: ACECondition = entry as ACECondition
	if condition == null or not condition.enabled or condition.negated:
		return ""
	if not ASKING_ACE_IDS.has(condition.ace_id):
		return ""
	var params: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
	var name: String = str(params.get(str(ASKING_ACE_IDS[condition.ace_id]), "")).strip_edges()
	return name if name.is_valid_identifier() else ""


## An action's params, under either spelling (the early alias field is still read everywhere else).
static func _params_of(action: ACEAction) -> Dictionary:
	return action.params if not action.params.is_empty() else action.parameters
