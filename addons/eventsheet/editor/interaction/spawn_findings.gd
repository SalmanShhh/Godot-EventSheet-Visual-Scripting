# Godot EventSheets - the four crashes a spawning sheet earns, found by reading the sheet.
#
# Spawning is three lines of Godot and none of them is hard. What IS hard is the four ways those
# three lines go wrong, every one of which is silent in the editor and loud at run time:
#
#   added while physics is busy - a node parented inside a collision or physics callback. Godot
#                                 refuses to add a child while the physics server is flushing its
#                                 queries, and the error names a line nobody was looking at.
#   a reference that may be gone - a node kept in a variable across frames and then touched without
#                                 asking whether it is still there. Godot's "previously freed" error.
#   the scene that spawns itself - a scene whose own sheet spawns that same scene, with nothing in
#                                 the way. Two become four, four become eight, and the editor is
#                                 fine with all of it.
#   freed, and still booked      - a row that destroys a node, and a later row in the SAME event that
#                                 hangs a timer or a tween off the node it just destroyed.
#
# NOTHING IS STORED. Every finding is derived from the rows, so a fixed sheet stops reporting with
# nothing to clean up. A sheet that never spawns and never destroys gets no findings at all - the
# cheap word gate below is what keeps a project that does neither exactly as it was. The gate holds
# the maybe-freed rule too, and deliberately: a node kept in a variable is a hazard in a sheet that
# is in the business of putting things into the world and taking them out again, and a note under
# every sheet that merely holds a node is the kind a reader learns to scroll past.
#
# THE RULES ARE READ OFF THE EMITTED LINE, not off a list of ace_ids, which is why a pack's own
# spawn verb is caught by the same rule and no table has to learn about it. The one place ace_ids
# ARE named is where a row has a DEFERRED TWIN to swap to - a repair cannot be derived, only offered.
#
# The same list feeds both surfaces: the note rows under the offending row, and the Doctor's
# Spawning section. One wording, one rule, two places to read it.
#
# PURE + STATIC: no viewport, no dialog, no display server, so every word is pinned headless.
@tool
class_name EventSheetSpawnFindings
extends RefCounted

## The four findings, by id. Frozen: the note rows, the Doctor and the tests address one by these.
const KIND_ADDED_DURING_PHYSICS := "added-during-physics"
const KIND_MAYBE_FREED := "maybe-freed-reference"
const KIND_SPAWNS_ITSELF := "spawns-itself"
const KIND_FREED_STILL_BOOKED := "freed-still-booked"

## The one-click repairs a note offers. "" on a finding whose repair is a decision rather than a
## step - a scene that spawns itself is a design question, and no rewrite can answer it.
const FIX_DEFER_THE_ADD := "defer_the_add"
const FIX_GUARD_IT := "guard_it"
const FIX_REMOVE_LAST := "remove_last"

## Where a finding's note hangs. Every one of these is about a row inside an event, so they all
## anchor at the event - the same anchor the networking notes use for the same reason.
const ANCHOR_EVENT := "event"

## The triggers that run while the physics server is flushing. Godot's own answer for all of them is
## the same - defer the parenting - so they are one list rather than four rules. `_physics_process`
## is here beside the collision callbacks because the flush is what the tick IS.
const PHYSICS_TRIGGER_IDS: PackedStringArray = [
	"OnPhysicsProcess", "OnBodyEntered", "OnBodyExited", "OnAreaEntered", "OnAreaExited",
]

## The parenting call, as it is spelled in the line a row compiles to, and the spelling that is
## already safe. A line holding the second is a line that has already been deferred - by the author,
## by the deferred spawn row, or by this check's own repair - and is never reported twice.
const ADD_CHILD_CALL := "add_child("
const DEFERRED_ADD := "call_deferred(\"add_child\""

## The rows with a deferred twin, and the twin. This is the ONE table in the file, and it exists
## because a repair is an offer rather than a derivation: swapping a spawn row for the spelling
## beside it needs somebody to have said which spelling that is. Both sides take the same
## parameters, which is what makes the swap one click and nothing else.
const DEFERRED_TWIN: Dictionary = {
	"SpawnNewCopy": "SpawnNewCopyDeferred",
}

## The calls that book something to happen LATER against a node - the second half of the fourth
## finding. Read as substrings of the emitted line, so a pack's own delayed verb counts too.
const BOOKING_CALLS: PackedStringArray = [
	"create_timer(", "create_tween(", "tween_property(", "tween_callback(", "start(",
]

## What a row writes when it takes a node OUT of the world, as the line spells it. `queue_free` is
## the whole of it: Godot has one answer and every destroy row in the language writes it.
const FREEING_CALL := "queue_free"

## The question that stands a maybe-freed reference down, in the two spellings that exist. The same
## pair the compiler's removal guard reads, because a sheet that asked the question has asked it
## whichever row it used.
const ASKING_ACE_IDS: PackedStringArray = ["IsValidInstance", "IsStillHere"]

## The row the "guard it" repair adds, and the parameter that names what it asks about. Named here
## so the finding, the repair and the test all spell the guard the same way.
const GUARD_ACE_ID := "IsStillHere"
const GUARD_PARAM := "object"

## The trigger that runs as a copy is created - the one moment a spawn row is reached by the very
## act of spawning, which is what turns a spawn of this scene into a loop rather than into a game.
const CREATED_TRIGGER_ID := "OnReady"

## The rows that already carry their own guard, so a note about them would be a note about a line the
## compiler is about to write anyway. The three destroy verbs, which is exactly the set the removal
## guard protects.
const SELF_GUARDING_ACE_IDS: PackedStringArray = ["DestroyNow", "DestroyAfterSeconds", "FadeOutAndDestroy"]

## The words a sheet has to say before any of this is asked of it. A sheet that neither parents a
## node nor frees one cannot earn a single finding here, and a project full of them should not pay
## to have that proved row by row.
const GATE_WORDS: PackedStringArray = ["add_child", "instantiate(", "queue_free"]


## Every finding this sheet earns, in the order the rules run. `scene_path` is the scene this sheet's
## script is attached to, which only the third rule needs - a sheet nobody passed one for simply
## never earns that finding, rather than earning a guess.
static func findings(sheet: EventSheetResource, scene_path: String = "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null:
		return found
	var rows: Array[Dictionary] = row_contexts(sheet)
	if not _says_any_of_the_words(rows):
		return found
	_added_during_physics(rows, found)
	_maybe_freed_reference(sheet, rows, found)
	_spawns_itself(rows, scene_path, found)
	_freed_but_still_booked(rows, found)
	return found


## The findings anchored at one event row - what the canvas hangs under it. Matched by IDENTITY, so
## the caller never has to name a row that has no name.
static func for_event(found: Array[Dictionary], event_row: EventRow) -> Array[Dictionary]:
	var mine: Array[Dictionary] = []
	if event_row == null:
		return mine
	for entry: Dictionary in found:
		if str(entry.get("anchor", "")) == ANCHOR_EVENT and entry.get("event") == event_row:
			mine.append(entry)
	return mine


## Every action of the sheet with the facts a rule needs about WHERE it sits: the event it is in, the
## trigger that reaches it, the slot it occupies in its lane, and whether anything above it has
## already asked whether its object is still there. ONE walk, four rules - a second walk would be a
## second answer to the same question.
static func row_contexts(sheet: EventSheetResource) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if sheet == null:
		return rows
	_walk(sheet.events, "", {}, false, rows)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk(event_function.events, "", {}, false, rows)
	return rows


## The line one row compiles to: the baked template when it has one (a lifted spelling, an addon
## ACE), the registry's otherwise, and the verbatim code of a block that never lifted. The same order
## the compiler resolves in, so a rule can never read a different line than the one that gets
## emitted.
##
## AND THE ROW'S OWN CHOICES ARE COLLAPSED FIRST. A template may carry a branch per answer to a
## dropdown - a formation row writes its copies in now or on the next idle moment, and both spellings
## sit in the one template with marks around them. Reading the template with the marks still in it
## sees BOTH branches, so a row set to the safe answer would be reported for the parenting the other
## branch writes and never emits. Collapsing is what the compiler does with the same row's values a
## moment later, through the same call, so this reads the line that really gets written.
static func emitted_lines(entry: Variant) -> String:
	if entry is RawCodeRow:
		return (entry as RawCodeRow).code
	var ace: Resource = entry as Resource
	if ace == null:
		return ""
	var template: String = str(ace.get("codegen_template"))
	if template.strip_edges().is_empty():
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor(
			str(ace.get("provider_id")), str(ace.get("ace_id")))
		if descriptor == null:
			return ""
		template = descriptor.codegen_template
	return ActionCodegen.collapse_optional_segments(template, _params_of(ace))


## True when a line parents a node WITHOUT deferring it. Anchored on the call rather than on the
## start of the line, because the parent is an expression: `self.add_child(x)`, `layer.add_child(x)`
## and a bare `add_child(x)` are all the same call and all the same refusal.
static func parents_a_node(line_text: String) -> bool:
	for line: String in line_text.split("\n"):
		var text: String = line.strip_edges()
		if text.begins_with("#") or text.contains(DEFERRED_ADD):
			continue
		if text.contains(ADD_CHILD_CALL):
			return true
	return false


## The same line with the parenting deferred - the exact text the repair writes. `add_child(x)`
## becomes `call_deferred("add_child", x)`, which is Godot's own spelling for "do this the moment the
## physics server is finished". Lines that were already deferred come back untouched, so applying the
## repair twice writes nothing the second time.
static func deferred_spelling(line_text: String) -> String:
	var written: PackedStringArray = PackedStringArray()
	for line: String in line_text.split("\n"):
		written.append(_defer_one_line(line))
	return "\n".join(written)


# -- The four rules ------------------------------------------------------------------------------


## A node parented inside a callback that runs while the physics server is flushing. Godot refuses
## the add and prints an error naming a line the author was not looking at; the deferred spelling is
## the whole of the answer, and it is one click away.
static func _added_during_physics(rows: Array[Dictionary], found: Array[Dictionary]) -> void:
	var seen: Dictionary = {}
	for context: Dictionary in rows:
		if not PHYSICS_TRIGGER_IDS.has(str(context.get("trigger", ""))):
			continue
		if not parents_a_node(str(context.get("lines", ""))):
			continue
		var event_row: EventRow = context.get("event") as EventRow
		if seen.has(event_row):
			continue
		seen[event_row] = true
		var twin: String = str(DEFERRED_TWIN.get(str(context.get("ace_id", "")), ""))
		# A verbatim block is about nothing the sheet named, so the event it sits in IS the subject -
		# which is what keeps two of these in one file two findings rather than one.
		var subject: String = str(context.get("subject", ""))
		if subject.is_empty():
			subject = str(event_row.event_uid) if event_row != null else ""
		# The repair is offered only where there IS one: a verbatim line this can respell, or a row
		# with the deferred spelling standing beside it. A frozen row that parents a node and has no
		# twin gets the sentence and no button, because a button that cannot do anything is worse
		# than none - the sentence still says exactly what to reach for.
		var verbatim: bool = context.get("row") is RawCodeRow
		found.append(_finding(KIND_ADDED_DURING_PHYSICS, "warning", event_row, subject,
			EventSheetL10n.translate("This adds a node to the tree while the physics server is busy, and Godot refuses it. Add it on the next idle moment instead."),
			FIX_DEFER_THE_ADD if verbatim or not twin.is_empty() else "",
			EventSheetL10n.translate("Add it on the next idle moment") if verbatim \
				else EventSheetL10n.translate("Use the safe spawn row"),
			context))


## A node kept in a variable across frames, touched by a row that never asks whether it is still
## there. The compiler's removal guard already writes the question for the three removal rows, so
## those are left alone here; every OTHER row reaching into the same name is the gap.
static func _maybe_freed_reference(sheet: EventSheetResource, rows: Array[Dictionary],
		found: Array[Dictionary]) -> void:
	var stored: Dictionary = (EventForgeRemovalGuard.facts(sheet).get("stored", {}) as Dictionary)
	if stored.is_empty():
		return
	# NARROWED TO WHAT THE SHEET ITSELF SAYS CAN GO. A node in a variable is only a dangling reference
	# waiting to happen if something removes it, and the sheet that removes it is the one that knows.
	# Without this the rule fires on every held node in the project - a behaviour's own parent, a
	# layer it made itself, an overlay nothing can reach - and a note under all of them is a note the
	# reader learns to scroll past, which is worse than no note.
	var removable: Dictionary = _names_this_sheet_frees(rows, stored)
	if removable.is_empty():
		return
	var seen: Dictionary = {}
	for context: Dictionary in rows:
		if SELF_GUARDING_ACE_IDS.has(str(context.get("ace_id", ""))):
			continue
		var asked: Dictionary = context.get("asked", {})
		for name_text: String in _names_reached_into(context, removable):
			if asked.has(name_text) or seen.has(name_text):
				continue
			seen[name_text] = true
			found.append(_finding(KIND_MAYBE_FREED, "warning", context.get("event") as EventRow,
				name_text,
				EventSheetL10n.translate("%s is kept between frames, and anything could have destroyed it by now. Ask whether it is still here before reaching into it.") % name_text,
				FIX_GUARD_IT, EventSheetL10n.translate("Guard it"), context))


## A scene whose own sheet spawns that same scene, with nothing in the way. The copy runs the same
## sheet, spawns another, and the count doubles every time the event is reached - which is a hang
## rather than an error, and so has no line to point at afterwards.
##
## REACHABILITY, not text matching: only a spawn row that is reached UNCONDITIONALLY when the copy is
## created counts. A spawn under a condition is a game (a boss that splits when it is hit); a spawn
## under `_ready` with nothing asked is the loop.
static func _spawns_itself(rows: Array[Dictionary], scene_path: String,
		found: Array[Dictionary]) -> void:
	var own_scene: String = scene_path.strip_edges()
	if own_scene.is_empty():
		return
	for context: Dictionary in rows:
		if not bool(context.get("action", false)) or bool(context.get("conditioned", false)):
			continue
		if str(context.get("trigger", "")) != CREATED_TRIGGER_ID:
			continue
		if not _names_scene(str(context.get("scene", "")), own_scene):
			continue
		found.append(_finding(KIND_SPAWNS_ITSELF, "error", context.get("event") as EventRow,
			own_scene.get_file(),
			EventSheetL10n.translate("This spawns the scene it is already running in, every time a copy is created, with nothing in the way. Each copy makes another one."),
			"", "", context))
		return


## A row that destroys a node, and a later row in the SAME event that books a timer or a tween against
## the very node it destroyed. The destroy lands at the end of the frame, so the booking is made
## against something that is on its way out - and the wait wakes up into nothing, or into an error.
static func _freed_but_still_booked(rows: Array[Dictionary], found: Array[Dictionary]) -> void:
	var freed_in_event: Dictionary = {}
	for context: Dictionary in rows:
		var event_row: EventRow = context.get("event") as EventRow
		if event_row == null or not bool(context.get("action", false)):
			continue
		var lines: String = str(context.get("lines", ""))
		var subject: String = str(context.get("subject", ""))
		if subject.is_empty():
			continue
		var key: String = "%s|%s" % [str(event_row.event_uid), subject]
		var books: bool = _books_something_later(lines)
		# A row that books a wait AND frees at the end of it - "destroy after two seconds", "fade out
		# then destroy" - is a BOOKING, not a destroy. It is the row this rule is looking for on the
		# far side of a removal, and reading it as the removal instead is what would make the rule
		# miss the commonest spelling of the bug it is about.
		if lines.contains(FREEING_CALL) and not books:
			# Recorded rather than reported: what matters is what comes AFTER it, and the walk is in
			# row order, so anything already seen was already safe.
			if not freed_in_event.has(key):
				freed_in_event[key] = context
			continue
		if not books or not freed_in_event.has(key):
			continue
		var removal: Dictionary = freed_in_event[key]
		found.append(_finding(KIND_FREED_STILL_BOOKED, "warning", event_row, subject,
			EventSheetL10n.translate("%s is destroyed earlier in this event, and this row books a wait against it. Move the destroy below this row, or destroy it after a delay instead.") % subject,
			FIX_REMOVE_LAST, EventSheetL10n.translate("Move the destroy last"), removal))
		freed_in_event.erase(key)


# -- What one row says --------------------------------------------------------------------------


## The stored names this sheet takes out of the world somewhere - the ones a reference to can really
## be dangling by the time another row reads it. A removal row names its object outright; a verbatim
## block says `name.queue_free()` in its own text, and both are read the same way.
static func _names_this_sheet_frees(rows: Array[Dictionary], stored: Dictionary) -> Dictionary:
	var removable: Dictionary = {}
	for context: Dictionary in rows:
		var lines: String = str(context.get("lines", ""))
		if not lines.contains(FREEING_CALL):
			continue
		var subject: String = str(context.get("subject", ""))
		if stored.has(subject):
			removable[subject] = true
		for name_key: Variant in stored.keys():
			if _line_reaches_into(lines, str(name_key)):
				removable[str(name_key)] = true
	return removable


## The stored names one row reaches INTO: a parameter holding exactly that name, or a line naming it
## with a member access after it. Bare names only - `self`, a node path and a call all answer for
## themselves every time they are read, which is the same boundary the removal guard draws.
static func _names_reached_into(context: Dictionary, stored: Dictionary) -> PackedStringArray:
	var reached: PackedStringArray = PackedStringArray()
	var params: Dictionary = context.get("params", {})
	for value: Variant in params.values():
		var text: String = str(value).strip_edges()
		if stored.has(text) and not reached.has(text):
			reached.append(text)
	for name_key: Variant in stored.keys():
		var name_text: String = str(name_key)
		if reached.has(name_text):
			continue
		# The lines a PICKED row compiles to still hold their placeholders, so the name is found in
		# the parameter above rather than here. This second pass is for a verbatim block, whose text
		# is the final text and holds no parameters at all.
		if _line_reaches_into(str(context.get("lines", "")), name_text):
			reached.append(name_text)
	return reached


## True when a line reaches into a bare name - `boss.hide()`, `boss.position = x`. A name inside a
## longer identifier is not a mention of it, which is what the boundary tests are for.
static func _line_reaches_into(line_text: String, name_text: String) -> bool:
	var needle: String = name_text + "."
	var at: int = line_text.find(needle)
	while at >= 0:
		if at == 0 or not _is_identifier_character(line_text[at - 1]):
			return true
		at = line_text.find(needle, at + 1)
	return false


static func _is_identifier_character(character: String) -> bool:
	return character == "_" or character.is_valid_identifier() or character.is_valid_int()


## True when a line hangs something on a wait against the object the row is about.
static func _books_something_later(line_text: String) -> bool:
	for call_name: String in BOOKING_CALLS:
		if line_text.contains(call_name):
			return true
	return false


## True when a row's scene expression names this scene: a `load("res://x.tscn")` or a `preload` of
## that path, or a declared constant whose name is the scene's file stem. Both spellings are what a
## sheet really holds, and neither is a guess.
static func _names_scene(scene_expression: String, scene_path: String) -> bool:
	var expression: String = scene_expression.strip_edges()
	if expression.is_empty():
		return false
	if expression.contains(scene_path):
		return true
	var stem: String = scene_path.get_file().get_basename()
	return not stem.is_empty() and expression == stem.to_pascal_case()


## True when anything in this sheet says one of the words the whole file is about.
static func _says_any_of_the_words(rows: Array[Dictionary]) -> bool:
	for context: Dictionary in rows:
		var lines: String = str(context.get("lines", ""))
		for word: String in GATE_WORDS:
			if lines.contains(word):
				return true
	return false


## One line with its parenting deferred, or the line unchanged when it parents nothing.
static func _defer_one_line(line: String) -> String:
	var text: String = line.strip_edges()
	if text.begins_with("#") or text.contains(DEFERRED_ADD) or not text.contains(ADD_CHILD_CALL):
		return line
	var opening: int = line.find(ADD_CHILD_CALL)
	var closing: int = line.rfind(")")
	if closing <= opening:
		return line
	var argument: String = line.substr(opening + ADD_CHILD_CALL.length(),
		closing - opening - ADD_CHILD_CALL.length()).strip_edges()
	if argument.is_empty():
		return line
	return "%s%s, %s)%s" % [line.substr(0, opening), DEFERRED_ADD, argument,
		line.substr(closing + 1)]


## The receipt one repair leaves: the line as it was, and the line as it now is. Shown rather than
## summarised, because a tool that rewrites somebody's code owes them the two lines side by side -
## and because the whole of this repair IS the difference between them.
## Not translated, and deliberately: both sides are lines of GDScript and the arrow between them is
## punctuation, so there is nothing here for a catalog to hold.
static func respell_receipt(before: String, after: String) -> String:
	return "%s -> %s" % [before.strip_edges(), after.strip_edges()]


## One finding, with every key its two readers address filled in. `lane`, `index` and `event` are how
## a repair finds the row again after the undo funnel has replaced the resources it was holding.
static func _finding(kind: String, severity: String, event_row: EventRow, subject: String,
		message: String, fix: String, fix_label: String, context: Dictionary) -> Dictionary:
	return {
		"kind": kind, "severity": severity, "anchor": ANCHOR_EVENT, "event": event_row,
		"subject": subject, "message": message, "fix": fix, "fix_label": fix_label,
		"lane": "action" if bool(context.get("action", false)) else "condition",
		"index": int(context.get("index", -1)),
		"to": str(DEFERRED_TWIN.get(str(context.get("ace_id", "")), "")),
	}


## Walks every row of a sheet once, recording for each action the trigger that reaches it, the names
## its event (or an enclosing one) has already asked about, and whether anything is asked at all.
## Recursive because a spawn row in a sub-event is still a row of the file - and because a sub-event
## runs inside its parent's `if`, which is what makes the parent's question its own.
static func _walk(items: Array, trigger_id: String, asked: Dictionary, conditioned: bool,
		into: Array[Dictionary]) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk(EventSheetGroupFacts.children(item as EventGroup), trigger_id, asked, conditioned,
				into)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		# The row's OWN trigger when it declares one; the enclosing event's otherwise. A sub-event has
		# no trigger of its own and runs inside its parent's handler, which is what makes the parent's
		# callback its callback - and the reason the resolver's every-tick default is not asked for
		# here, because that default would answer for a nested row as if it were a top-level one.
		var reached_by: String = event_row.trigger_id.strip_edges()
		if reached_by.is_empty():
			reached_by = trigger_id
		var mine: Dictionary = asked.merged(EventForgeRemovalGuard.asked_names(event_row), true)
		var gated: bool = conditioned or not event_row.conditions.is_empty()
		for is_action: bool in [false, true]:
			var lane: Array = event_row.actions if is_action else event_row.conditions
			for index: int in range(lane.size()):
				var entry: Variant = lane[index]
				if not (entry is Resource):
					continue
				into.append({
					"event": event_row, "row": entry as Resource, "action": is_action,
					"index": index, "trigger": reached_by, "asked": mine,
					"conditioned": gated,
					"ace_id": str((entry as Resource).get("ace_id")),
					"params": _params_of(entry as Resource),
					"lines": emitted_lines(entry),
					"scene": str(_params_of(entry as Resource).get("scene", "")),
					"subject": _subject_of(entry as Resource),
				})
		_walk(event_row.sub_events, reached_by, mine, gated, into)


## The object one row is ABOUT, as the sheet spells it: the name it removes, the name it minted, or
## the node it parents. "" for a row that is about nothing in particular, which is most of them.
static func _subject_of(ace: Resource) -> String:
	var params: Dictionary = _params_of(ace)
	for key: String in ["object", "name", "node"]:
		var value: String = str(params.get(key, "")).strip_edges()
		if value.is_valid_identifier() and value != "self":
			return value
	return ""


## A row's params, under either spelling (the early alias field is still read everywhere else). A
## RawCode block has none at all, which is the honest answer for verbatim text.
static func _params_of(ace: Resource) -> Dictionary:
	if ace == null:
		return {}
	var params: Variant = ace.get("params")
	if params is Dictionary and not (params as Dictionary).is_empty():
		return params as Dictionary
	var alias: Variant = ace.get("parameters")
	return alias as Dictionary if alias is Dictionary else {}
