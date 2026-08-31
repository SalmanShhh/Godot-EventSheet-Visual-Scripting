# Godot EventSheets - the state TRAIL: what this object's machine has just done, said as sentences.
#
# The states band says what the object IS. The trail says what it DID, in the sheet's own grammar and
# in the past tense:
#
#     12.1 s · On hit fired - went from Chase to Stagger
#     12.4 s · On hit fired - re-entered Stagger
#
# It reads DOWN, oldest first, exactly the way a sheet reads. There is no timeline, no scrubber and
# no replay here, and there is deliberately no picture: a state is a variable, so its history is a
# list of sentences about a variable, which is the shape every reader of this plugin already knows.
#
# NOTHING NEW GOES OVER THE WIRE. The running game already flushes two messages every 0.25 s - the
# Live Values frame (which carries `state` and `state_seconds` for a sheet that declares states) and,
# with the Event Trace armed, the tally of event uids that fired. This store is the editor's own
# reading of those two, and the game is not asked for one extra byte. A run with the trace off still
# builds a trail; it simply cannot name the row that did it, and then it does not pretend to.
#
# HOW A TRANSITION IS SEEN, and there are exactly two shapes of it:
#
#   the state changed    this frame's `state` is not the last frame's. That is a move, from one to
#                        the other, and both names are the game's own.
#   the hold restarted   this frame's `state` is the same and `state_seconds` went BACKWARDS. The
#                        only thing that puts that clock back is `state_entered_msec` being set
#                        again, so the object was put into the state it was already in.
#
# WHY THE MOMENT IS A COUNT OF FRAMES. Nothing in the values message carries a time, so a moment
# here is the editor's own count of the frames this copy of the game has reported, multiplied by the
# cadence it reports them at - one every 0.25 s. That is accurate to a quarter of a second and to
# nothing finer, and a message the engine drops or coalesces shifts every stamp after it earlier
# without the trail being able to tell. Both halves of that are said on the tab rather than implied,
# because a stamp that looked exact would be a stamp somebody trusted to order two things inside one
# frame, which it cannot do.
#
# ONE RING PER MACHINE, and a machine is one running copy of the game: keyed exactly the way the live
# value chips are keyed ("" for a lone run, the feature tag for each window when a run is two games).
# Bounded, because a trail is the RECENT past - an unbounded one is a log file, and a log file is the
# thing this feature exists so nobody has to read.
#
# AND WHAT THE KEY CANNOT SAY: the values channel carries one unqualified `state` per running copy of
# the game, with no node and no script attached to it. So a game whose scene holds two enemies, or
# one enemy and one door, sends both under that one name and the last one written in a frame is the
# one this ring sees. The trail therefore describes ONE running object; with several stateful objects
# alive at once it interleaves them, and a Patrol beside a Chase reads as a move between them. That
# boundary is stated on the tab and in the guide, because it is not one the store can detect - the
# message simply does not say who sent it.
#
# THE DOORS BELONG TO THE SHEET THEY WERE READ FROM. A line's cause is found in whatever sheet was in
# front when the frame arrived, so each entry carries that sheet's own name and the tab offers the
# door only while that sheet is still the one in front. Switching tabs mid-run therefore drops the
# doors on the lines that were read against the other document rather than silently re-pointing them
# at rows of an object they were never about.
#
# THE RUN OWNS IT. The ring is emptied when a new debug session opens, exactly where the trace hit
# counts and timings are emptied, because those three are one tally of one run. Stopping the game
# leaves the trail standing so it can be read - which is when it is read - and the next Run wipes it.
#
# STATIC + PURE: no viewport, no dialog, no display server, and no sheet is reachable from here. The
# rows a sentence names arrive as a plain Dictionary the caller built (EventSheetStateFacts.trail_rows),
# so every word below is pinned headless.
@tool
class_name EventSheetStateTrail
extends RefCounted

## How many transitions one machine keeps. A trail is the recent past: enough to hold the last few
## seconds of a machine that is thrashing, and far short of a log.
const RING_LIMIT: int = 40

## How far the hold has to go BACKWARDS before it counts as a restart rather than as float noise.
## A real hold only ever grows, and it grows by the cadence, so anything below this is not a drop.
const RESTART_MARGIN: float = 0.05

## The pattern kinds, frozen: the tab and the tests address one by these.
const PATTERN_RE_ENTERED: String = "the-hold-restarted"
const PATTERN_TWICE_IN_A_FRAME: String = "twice-in-one-frame"

## Where the caller says its row index came FROM - the sheet that was in front when this frame
## arrived. Carried on the index the caller hands in, and stamped onto every line written from it.
const HOME_KEY: String = "home"

## instance -> Array[Dictionary], oldest first.
static var _rings: Dictionary = {}
## instance -> the last frame's {state, seconds}, which is what the next frame is compared against.
static var _last: Dictionary = {}
## instance -> how many frames that copy of the game has reported, which IS the run clock.
static var _frames_seen: Dictionary = {}
## The fires of the last streamed trace window: uid -> {fires, most_in_one_frame}. Held only until
## the next window replaces it - it exists to answer "what fired just before this change".
static var _pending_fires: Dictionary = {}
## The transition written a moment ago that is still waiting for its window of fires, as
## {instance, to}. The running game sends its values frame FIRST and the fires of the same flush
## right after it, so a change of state is seen a message before the row that caused it. Empty
## whenever nothing is waiting, which is every frame of a run with the Event Trace switched off.
static var _awaiting: Dictionary = {}
## True once a frame carrying a state has arrived. An empty trail under a run ("nothing has changed
## state yet") and no run at all look identical, and only one of them is worth a table.
static var _has_run: bool = false


## One streamed trace window -> what fired in it, and how often within a single game frame. `markers`
## is the fire-count at the top of each frame, which is the only thing that can tell two fires in one
## frame from two fires in two frames.
##
## This is also where a line gets the row's NAME. The change of state arrived one message earlier in
## the same flush, so the entry written then is still waiting: if exactly one row that can go to that
## state fired in this window, that row is named on the line and its fire count is carried with it.
## Anything less certain than "exactly one" names nothing, because a trail that guessed would be a
## trail that has to be checked.
static func note_fired(uids: PackedStringArray, markers: PackedInt32Array,
		rows: Dictionary = {}) -> void:
	_pending_fires = window_fires(uids, markers)
	if _awaiting.is_empty():
		return
	var instance: String = str(_awaiting.get("instance", ""))
	var member: String = str(_awaiting.get("to", ""))
	_awaiting = {}
	var ring: Array = _rings.get(instance, [])
	if ring.is_empty():
		return
	var named: Dictionary = _fired_cause(member, rows)
	if not named.is_empty():
		(ring[ring.size() - 1] as Dictionary).merge(named, true)


## The fire tally of one window, per uid: how many times it fired, and the most times it fired inside
## any ONE frame of that window. Pure, so the frame ruler's meaning is pinned without a debug session.
static func window_fires(uids: PackedStringArray, markers: PackedInt32Array) -> Dictionary:
	var totals: Dictionary = {}
	var per_frame: Dictionary = {}
	var next_marker: int = 0
	for index: int in range(uids.size()):
		# A marker AT this index opens a new frame, so the within-a-frame tally starts over.
		while next_marker < markers.size() and markers[next_marker] <= index:
			next_marker += 1
			per_frame.clear()
		var uid: String = uids[index]
		if uid.is_empty():
			continue
		var in_this_frame: int = int(per_frame.get(uid, 0)) + 1
		per_frame[uid] = in_this_frame
		var seen: Dictionary = totals.get(uid, {"fires": 0, "most_in_one_frame": 0})
		seen["fires"] = int(seen["fires"]) + 1
		seen["most_in_one_frame"] = maxi(int(seen["most_in_one_frame"]), in_this_frame)
		totals[uid] = seen
	return totals


## One streamed values frame -> the trail. `rows` is what the sheet says about its own states
## (EventSheetStateFacts.trail_rows): which rows can move the object where, and which rows answer a
## change. Passed in rather than read here, because nothing in this file may reach a sheet.
##
## A frame WITHOUT the state entry forgets that instance rather than leaving it standing: an object
## with no states says nothing, and a stale "went to Chase" over a game that no longer has states is
## the one reading worse than none.
static func note_frame(values: Dictionary, instance: String = "", rows: Dictionary = {}) -> void:
	# A line waits exactly one message for its name. This frame opens the next flush, so whatever was
	# still waiting is never going to be named - which is what a run with the Event Trace off is.
	_awaiting = {}
	if not values.has(EventSheetStateWatch.STATE_KEY):
		_rings.erase(instance)
		_last.erase(instance)
		_frames_seen.erase(instance)
		return
	# A lone run and a labelled one never mix, the same rule the value chips and the band follow: a
	# frame with no label replaces every labelled one and the other way round, so a second run cannot
	# leave a sentence naming a window from the first.
	var keys: Array = _last.keys()
	var was_labelled: bool = not keys.is_empty() and not str(keys[0]).is_empty()
	if was_labelled != (not instance.is_empty()):
		clear()
	_has_run = true
	var member: String = str(values[EventSheetStateWatch.STATE_KEY]).strip_edges()
	var seconds: float = float(values.get(EventSheetStateWatch.SECONDS_KEY, 0.0))
	var frames: int = int(_frames_seen.get(instance, 0))
	_frames_seen[instance] = frames + 1
	var before: Variant = _last.get(instance)
	_last[instance] = {"state": member, "seconds": seconds}
	if not (before is Dictionary):
		return  # the first frame is where the object already was, not somewhere it went
	var was: String = str((before as Dictionary).get("state", ""))
	var held: float = float((before as Dictionary).get("seconds", 0.0))
	var re_entered: bool = member == was and seconds < held - RESTART_MARGIN
	if member == was and not re_entered:
		return
	var entry: Dictionary = {
		"instance": instance,
		"at": float(frames) * EventSheetStateWatch.CADENCE_SECONDS,
		"from": was,
		"to": member,
		"re_entered": re_entered,
		# The sheet this line's cause was looked up in. Held so the tab can tell a door it may still
		# offer from one that was read against a document the reader has since navigated away from.
		"home": str(rows.get(HOME_KEY, "")),
	}
	entry.merge(_standing_door(member, rows))
	var ring: Array = _rings.get(instance, [])
	ring.append(entry)
	while ring.size() > RING_LIMIT:
		ring.remove_at(0)
	_rings[instance] = ring
	# The fires of this same flush land in the very next message, so the line waits that long for the
	# name of the row that did it. Only for a LONE run: the fired-events message says which uids fired
	# and not which window they fired in, so with two copies of the game running, naming one of them
	# would be a coin toss dressed as a fact. Those lines say what happened and claim no cause.
	if instance.is_empty():
		_awaiting = {"instance": instance, "to": member}


## The door a line opens before - and possibly without - the trace naming anything, because a line a
## reader cannot follow is half a line. In order:
##
##   the one row that can      this sheet has exactly one Go to for this state, so that IS the row,
##                             whether or not anything watched it fire. Not NAMED on the line: the
##                             sentence only says "X fired" about a fire the run reported.
##   the row that answers it   otherwise the On entering row for this state, which is where a reader
##                             asking "and what happened when it got here" wants to land.
static func _standing_door(member: String, rows: Dictionary) -> Dictionary:
	var candidates: Array = []
	for entry: Variant in (rows.get("causes", []) as Array):
		if str((entry as Dictionary).get("to", "")) == member:
			candidates.append(entry)
	var door: String = ""
	if candidates.size() == 1:
		door = str((candidates[0] as Dictionary).get("uid", ""))
	else:
		var entering: Dictionary = rows.get("entering", {})
		if entering.has(member):
			door = str((entering[member] as Dictionary).get("uid", ""))
	return {"cause_uid": door, "cause_text": "", "same_frame_fires": 0}


## The row the RUN saw go to this state, when there is exactly one of them, with how many times it
## fired inside a single game frame. {} for "not exactly one", which is the answer whenever the trace
## is off, nothing recognised fired, or two different rows could both have done it.
static func _fired_cause(member: String, rows: Dictionary) -> Dictionary:
	var fired: Array = []
	for entry: Variant in (rows.get("causes", []) as Array):
		var cause: Dictionary = entry
		if str(cause.get("to", "")) == member and _pending_fires.has(str(cause.get("uid", ""))):
			fired.append(cause)
	if fired.size() != 1:
		return {}
	var uid: String = str((fired[0] as Dictionary).get("uid", ""))
	return {
		"cause_uid": uid,
		"cause_text": str((fired[0] as Dictionary).get("text", "")),
		"same_frame_fires": int((_pending_fires[uid] as Dictionary).get("most_in_one_frame", 0)),
	}


## A new Run empties the trail. Called where the trace hit counts and timings are reset, because the
## three of them are one tally of one run; stopping the game does NOT call this, so a finished run
## can still be read - which is when it is read.
static func clear() -> void:
	_rings.clear()
	_last.clear()
	_frames_seen.clear()
	_pending_fires.clear()
	_awaiting.clear()
	_has_run = false


## True once a run has reported a state at all. Everything the tab draws is gated on this: with no
## run it says what to switch on, never an empty table that looks like "nothing ever happened".
static func has_run() -> bool:
	return _has_run


## One machine's trail, oldest first.
static func entries(instance: String = "") -> Array:
	return (_rings.get(instance, []) as Array).duplicate()


## Every machine's trail as one list, in reading order: by the moment first, and by the window's own
## tag second, so two copies of a game interleave the same way twice.
##
## Compared EXACTLY, not approximately. A moment here is a frame count times a constant, so two
## moments are either the same number or a whole cadence apart and there is nothing to be tolerant
## about - and an approximate comparison is not transitive, which makes the comparator not a strict
## weak ordering and lets the sort produce a different interleave for the same ring. "Two copies of a
## game interleave the same way twice" is the claim, so the comparator has to be able to keep it.
static func all_entries() -> Array:
	var out: Array = []
	for instance: Variant in _rings:
		out.append_array(_rings[instance] as Array)
	out.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if float(left["at"]) != float(right["at"]):
			return float(left["at"]) < float(right["at"])
		return str(left["instance"]) < str(right["instance"]))
	return out


## One entry as the past-tense line the tab shows: "12.1 s · On hit fired - went from Chase to
## Stagger". The row is named only when the run saw it fire; otherwise the line says what happened
## and leaves the cause unclaimed, which is the honest half of what is known.
static func sentence(entry: Dictionary) -> String:
	var moment: String = "%s s" % EventSheetStateWatch.seconds_text(float(entry.get("at", 0.0)))
	var instance: String = str(entry.get("instance", ""))
	if not instance.is_empty():
		moment = "%s · %s" % [instance, moment]
	var into: String = EventSheetStateFacts.word_for(str(entry.get("to", "")))
	var moved: String = EventSheetL10n.translate("re-entered %s") % into
	if not bool(entry.get("re_entered", false)):
		moved = EventSheetL10n.translate("went from %s to %s") % [
			EventSheetStateFacts.word_for(str(entry.get("from", ""))), into]
	var named: String = str(entry.get("cause_text", "")).strip_edges()
	if named.is_empty():
		return "%s · %s" % [moment, moved]
	return "%s · %s - %s" % [moment, EventSheetL10n.translate("%s fired") % named, moved]


## The pattern notes of the whole run, across every machine.
static func notes(rows: Dictionary = {}) -> Array[Dictionary]:
	return notes_for(all_entries(), rows)


## What the trail SAYS, stated in words and never guessed at. Both notes are read from the ring alone
## - no second stream, no heuristic and no probability - and each one names the rows it is about, so
## the reader lands on the sheet rather than on a description of the sheet.
##
##   the hold restarted        the object was put into the state it was already in, so the clock the
##                             timed row compares went back to 0. That row is now counting again from
##                             nothing, and On leaving never ran, because the object never left.
##   twice in one frame        the row that caused the change fired more than once inside a single
##                             game frame. Only the first of those changed anything: the state
##                             variable's setter returns early when the value it is handed is the one
##                             it already holds.
##
## One note per pattern per state, however many times it happened, with the count said rather than
## the note repeated - a note printed forty times is a note nobody reads.
static func notes_for(ring: Array, rows: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var seen: Dictionary = {}
	for item: Variant in ring:
		var entry: Dictionary = item
		var note: Dictionary = _note_for(entry, rows)
		if note.is_empty():
			continue
		var key: String = "%s/%s" % [str(note["kind"]), str(entry.get("to", ""))]
		if seen.has(key):
			var standing: Dictionary = found[int(seen[key])]
			standing["count"] = int(standing["count"]) + 1
			continue
		note["count"] = 1
		seen[key] = found.size()
		found.append(note)
	for note: Dictionary in found:
		note["text"] = _with_count(str(note["text"]), int(note["count"]))
	return found


## The one note an entry raises, or {} for an entry that raises none - which is most of them, and
## deliberately: a trail that annotated every line would be a trail with nothing to point at.
static func _note_for(entry: Dictionary, rows: Dictionary) -> Dictionary:
	var member: String = str(entry.get("to", ""))
	var word: String = EventSheetStateFacts.word_for(member)
	var timed: Dictionary = (rows.get("timed", {}) as Dictionary).get(member, {})
	var leaving: Dictionary = (rows.get("leaving", {}) as Dictionary).get(member, {})
	var entering: Dictionary = (rows.get("entering", {}) as Dictionary).get(member, {})
	if bool(entry.get("re_entered", false)):
		# Only worth saying when a row is actually waiting on that clock: without a timed row, a hold
		# going back to 0 changed nothing a reader can see, and a note about it is noise.
		if timed.is_empty():
			return {}
		if leaving.is_empty():
			return {
				"kind": PATTERN_RE_ENTERED,
				"uid": str(timed.get("uid", "")),
				"text": EventSheetL10n.translate("Re-entering %s restarted its hold, so %s starts counting from 0 again.") % [word, str(timed.get("text", ""))],
			}
		return {
			"kind": PATTERN_RE_ENTERED,
			"uid": str(timed.get("uid", "")),
			"text": EventSheetL10n.translate("Re-entering %s restarted its hold, so %s starts counting from 0 again - and %s never ran, because the object never left.") % [word, str(timed.get("text", "")), str(leaving.get("text", ""))],
		}
	var fires: int = int(entry.get("same_frame_fires", 0))
	var named: String = str(entry.get("cause_text", "")).strip_edges()
	if fires < 2 or named.is_empty():
		return {}
	if entering.is_empty():
		return {
			"kind": PATTERN_TWICE_IN_A_FRAME,
			"uid": str(entry.get("cause_uid", "")),
			"text": EventSheetL10n.translate("%s fired %d times in one frame and the state changed once: going to %s while already there does nothing.") % [named, fires, word],
		}
	return {
		"kind": PATTERN_TWICE_IN_A_FRAME,
		"uid": str(entry.get("cause_uid", "")),
		"text": EventSheetL10n.translate("%s fired %d times in one frame and the state changed once: going to %s while already there does nothing, so %s ran once.") % [named, fires, word, str(entering.get("text", ""))],
	}


## A pattern that happened once says itself; a pattern that happened again says how often, because
## "the stagger timer restarted" and "the stagger timer restarted eleven times" are two different
## bugs and only the second one explains why the row never came true.
static func _with_count(text: String, count: int) -> String:
	if count < 2:
		return text
	return "%s %s" % [text, EventSheetL10n.translate("This happened %d times in this run.") % count]
