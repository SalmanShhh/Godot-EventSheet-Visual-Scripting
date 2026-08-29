# EventForge - the removal chains people wrote before this plugin existed.
#
# `queue_free()` on its own already opens as a row, and always did. What did not are the two CHAINS
# that put a wait in front of it, and they are in every project that has ever had a corpse fade out
# or a bullet clean itself up:
#
#     get_tree().create_timer(2.0).timeout.connect(queue_free)
#     $Ghost.create_tween().tween_property($Ghost, "modulate:a", 0.0, 0.5).finished.connect($Ghost.queue_free)
#
# Both are ONE statement, which is why they are table entries (see EventForgeLiftTable) rather than
# hand-written matchers: one pattern each, the captures the row shows, and the author's own spelling
# stored by construction so the file saves back byte for byte.
#
# WHY THE TIMER LINE TAKES A BLANK RECEIVER AND THE TWEEN LINE DOES NOT. The timer names the object
# ONCE, so the receiver is the optional-prefix idiom every node-scoped row uses and both spellings
# lift - `connect(queue_free)` on a node removing itself, `connect($Enemy.queue_free)` on a node
# removing another. The tween line names it THREE times, and the three have to agree for the line to
# be this row at all (a tween on one node that frees a different one is somebody else's line, and the
# guard below refuses it). Three mentions cannot each be an optional prefix of one capture, so this
# entry asks for the receiver to be written; a fade whose object is left implicit stays the plain
# statement it already was, which is the honest outcome for a spelling the row cannot reproduce.
#
# THE AUTHORED SPELLING IS THE AWAIT. Fade Out Then Remove writes the tween, waits for it and then
# removes - three lines, with the guard the wait needs written into them. The connect spelling above
# is the one-line form people write by hand, and it lifts to the same row carrying its own template,
# exactly as every other lifted spelling does.
@tool
class_name EventForgeRemovalLift
extends RefCounted

## The fragment a line must contain for any entry here to be worth trying - one word that rules out
## almost every statement in a project before a pattern is compiled at all.
const MARK: String = "queue_free"

## The property a fade walks and the value it walks it to, as pattern fragments. `0` and `0.0` are
## both written by hand and mean the same fade, so both are matched and each saves back as itself.
const FADE_PROPERTY: String = "\"modulate:a\""
const FADE_TARGET: String = "0(?:\\.0)?"

## What the row's object is when the line names no node: blank, which is what "this node" reads as on
## every node-scoped row in the plugin.
const BLANK_OBJECT: Dictionary = {"object": ""}

## Built once for the life of the session: these run on every statement of every opened file.
static var _entries: Array[Dictionary] = []


## The row one statement means, or {} when no spelling here claims it. `line` is a single statement,
## already dedented by the lifter.
static func match_line(line: String) -> Dictionary:
	var text: String = line.strip_edges()
	if not text.contains(MARK):
		return {}
	return EventForgeLiftTable.match_line(lift_entries(), text)


## Both removal chains, as table entries.
static func lift_entries() -> Array[Dictionary]:
	if _entries.is_empty():
		_entries = [_timer_entry(), _fade_entry()]
	return _entries


## `get_tree().create_timer(2.0).timeout.connect(queue_free)` - the wait-then-remove one-liner, with
## or without a named object.
static func _timer_entry() -> Dictionary:
	return {
		"id": "remove_after_timer",
		"ace_id": "RemoveAfterSeconds",
		"pattern": "^get_tree\\(\\)\\.create_timer\\((?<seconds>[^)]+)\\)\\.timeout\\.connect\\(%squeue_free\\)$"\
			% EventForgeLiftTable.receiver("object"),
		"params": ["object", "seconds"],
		"defaults": BLANK_OBJECT,
		"shape": "get_tree().create_timer({seconds}).timeout.connect(%squeue_free)"\
			% EventForgeLiftTable.optional_prefix_slot("object"),
		"slots": {"object": "$Enemy", "seconds": "2.0"}
	}


## `$Ghost.create_tween().tween_property($Ghost, "modulate:a", 0.0, 0.5).finished.connect($Ghost.queue_free)`
## - the fade-then-remove one-liner. The second and third mentions are matched under their own
## captures and left out of the params, so the guard can insist all three name the same object and
## the splice never has to reinstate them.
static func _fade_entry() -> Dictionary:
	return {
		"id": "fade_out_then_remove",
		"ace_id": "FadeOutAndRemove",
		"pattern": "^(?<object>%s)\\.create_tween\\(\\)\\.tween_property\\((?<faded>%s), %s, %s, (?<seconds>[^,)]+)\\)\\.finished\\.connect\\((?<freed>%s)\\.queue_free\\)$" % [
			EventForgeLiftTable.NODE_REFERENCE, EventForgeLiftTable.NODE_REFERENCE,
			FADE_PROPERTY, FADE_TARGET, EventForgeLiftTable.NODE_REFERENCE],
		"params": ["object", "seconds"],
		"guard": Callable(EventForgeRemovalLift, "_fades_what_it_frees"),
		"shape": "{object}.create_tween().tween_property({object}, \"modulate:a\", 0.0, {seconds}).finished.connect({object}.queue_free)",
		"slots": {"object": "$Ghost", "seconds": "0.5"}
	}


## True when all three mentions name the same object. A tween started on one node that fades a second
## and frees a third is a perfectly good line and it is not this row, so it keeps the reading it had.
static func _fades_what_it_frees(captures: Dictionary) -> bool:
	var object_name: String = str(captures.get("object", "")).strip_edges()
	return object_name == str(captures.get("faded", "")).strip_edges()\
		and object_name == str(captures.get("freed", "")).strip_edges()
