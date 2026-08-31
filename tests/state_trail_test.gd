# EventForge - THE STATE TRAIL: what the machine just did, as sentences, read out of the two
# messages the running game was already sending.
#
# The band says what the object IS; the trail says what it DID. This file pins the whole of it, and
# every pin is a VALUE rather than a count:
#
#   THE MOMENT IS THE REPORT CLOCK    a line is stamped at the game's own cadence and at nothing
#                                     finer, so the Nth frame is at N quarter-seconds and the editor
#                                     never invents a moment between two of them.
#   TWO SHAPES OF TRANSITION          the state changed, or the hold went backwards while the state
#                                     stayed - the second being the only thing a re-entry looks like
#                                     from outside the game.
#   THE ROW IS NAMED, OR IT IS NOT    "On Hit fired" is said only about a fire the run reported, and
#                                     an ambiguous window names nothing at all. The DOOR is a
#                                     separate question and falls down a stated ladder, because a
#                                     line a reader cannot follow is half a line.
#   THE NOTES COME OUT OF THE RING    both patterns are read from the trail alone - no second
#                                     stream, no heuristic - and each one names the rows it is about.
#   IT READS DOWN                     a list of sentences and nothing else: no timeline, no scrubber,
#                                     no replay, no picture. Swept as a property of the source.
@tool
class_name StateTrailTest
extends RefCounted

## The machine the fixture sheet declares.
const DECLARED: PackedStringArray = ["Patrol", "Chase", "Stagger"]
const STARTS_IN: String = "Patrol"

## The uids the fixture rows carry, so a pin can say which row it means.
const HIT_ROW: String = "row-hit"
const CALM_ROW: String = "row-calm"
const SPOT_ROW: String = "row-spot"
const LEAVING_ROW: String = "row-leaving-stagger"
const ENTERING_ROW: String = "row-entering-stagger"

## The file this feature is, swept for every shape the trail refuses to be. A trail is a list of
## sentences: anything that draws a picture of a machine, scrubs a timeline or replays a run is a
## different feature, and none of them may appear here even by name.
const OWN_FILE: String = "res://addons/eventsheet/editor/state_trail.gd"
const REFUSED_SHAPES: PackedStringArray = [
	"CanvasLayer", "Window.new(", "GraphEdit", "GraphNode", "Curve2D", "draw_line", "draw_polyline",
	"HSlider", "Tween", "AnimationPlayer", "add_child(",
]


static func run() -> bool:
	# A store belonging to the RUN, so a suite sharing one process starts from nothing and leaves
	# nothing behind.
	EventSheetStateTrail.clear()
	var ok: bool = true
	ok = _test_the_frame_ruler() and ok
	ok = _test_what_counts_as_a_transition() and ok
	ok = _test_the_run_clock() and ok
	ok = _test_the_sentences() and ok
	ok = _test_the_row_is_named_only_when_it_fired() and ok
	ok = _test_the_patterns() and ok
	ok = _test_the_ring_is_bounded() and ok
	ok = _test_the_run_owns_it() and ok
	ok = _test_two_copies_never_mix() and ok
	ok = _test_the_index_reads_the_sheet() and ok
	ok = _test_it_reads_down_and_draws_nothing() and ok
	EventSheetStateTrail.clear()
	return ok


# -- The frame ruler ------------------------------------------------------------------------------
## The markers are what tell two fires in one frame from two fires in two frames, and that
## distinction is the whole of the second pattern note.
static func _test_the_frame_ruler() -> bool:
	# One window, two frames: frame 1 fires hit, hit; frame 2 fires hit.
	var twice: Dictionary = EventSheetStateTrail.window_fires(
		PackedStringArray([HIT_ROW, HIT_ROW, HIT_ROW]), PackedInt32Array([0, 2]))
	var ok: bool = _check("every fire of the window is counted",
		int((twice[HIT_ROW] as Dictionary)["fires"]), 3)
	ok = _check("and the most it managed inside ONE frame is counted apart",
		int((twice[HIT_ROW] as Dictionary)["most_in_one_frame"]), 2) and ok
	# The same three fires spread one to a frame are three ordinary fires and no pattern at all.
	var spread: Dictionary = EventSheetStateTrail.window_fires(
		PackedStringArray([HIT_ROW, HIT_ROW, HIT_ROW]), PackedInt32Array([0, 1, 2]))
	ok = _check("three fires in three frames are never two in one",
		int((spread[HIT_ROW] as Dictionary)["most_in_one_frame"]), 1) and ok
	# A window with no ruler at all (an older debug compile) is one frame, which is the honest read.
	var unruled: Dictionary = EventSheetStateTrail.window_fires(
		PackedStringArray([HIT_ROW, HIT_ROW]), PackedInt32Array())
	ok = _check("a window with no ruler is read as the one frame it says it is",
		int((unruled[HIT_ROW] as Dictionary)["most_in_one_frame"]), 2) and ok
	ok = _check("and an empty window says nothing about anything",
		EventSheetStateTrail.window_fires(PackedStringArray(), PackedInt32Array()), {}) and ok
	return ok


# -- What the editor can see from outside the game -------------------------------------------------
static func _test_what_counts_as_a_transition() -> bool:
	EventSheetStateTrail.clear()
	var rows: Dictionary = EventSheetStateFacts.trail_rows(_authored_sheet())
	_frame("PATROL", 0.5, rows)
	var ok: bool = _check("the first frame is where the object already was, not somewhere it went",
		EventSheetStateTrail.entries().size(), 0)
	_frame("PATROL", 0.75, rows)
	ok = _check("a hold that simply grows is not a transition",
		EventSheetStateTrail.entries().size(), 0) and ok
	_frame("CHASE", 0.1, rows)
	ok = _check("a different state is a move", _last().get("from"), "PATROL") and ok
	ok = _check("and it says where it went", _last().get("to"), "CHASE") and ok
	ok = _check("and a move is not a re-entry", _last().get("re_entered"), false) and ok
	_frame("CHASE", 0.02, rows)
	ok = _check("the same state with the hold gone BACKWARDS is a re-entry",
		_last().get("re_entered"), true) and ok
	ok = _check("which came from and went to the very same state",
		"%s -> %s" % [str(_last().get("from")), str(_last().get("to"))], "CHASE -> CHASE") and ok
	ok = _check("and that is four frames and two lines",
		EventSheetStateTrail.entries().size(), 2) and ok
	EventSheetStateTrail.clear()
	return ok


# -- The moment is the game's own report clock -----------------------------------------------------
static func _test_the_run_clock() -> bool:
	EventSheetStateTrail.clear()
	var rows: Dictionary = EventSheetStateFacts.trail_rows(_authored_sheet())
	for index: int in range(8):
		_frame("PATROL", 0.25 * float(index), rows)
	_frame("CHASE", 0.0, rows)
	var ok: bool = _check("the ninth frame is eight quarter-seconds into the run",
		float(_last().get("at")), 8.0 * EventSheetStateWatch.CADENCE_SECONDS)
	ok = _check("said the way the band says its seconds",
		EventSheetStateWatch.seconds_text(float(_last().get("at"))), "2") and ok
	EventSheetStateTrail.clear()
	return ok


# -- The sentences ---------------------------------------------------------------------------------
static func _test_the_sentences() -> bool:
	var ok: bool = _check("a named move is the whole line",
		EventSheetStateTrail.sentence({"at": 12.1, "from": "CHASE", "to": "STAGGER",
			"cause_text": "On Hit"}),
		"12.1 s · On Hit fired - went from Chase to Stagger")
	ok = _check("an unnamed move says what happened and claims no cause",
		EventSheetStateTrail.sentence({"at": 12.1, "from": "CHASE", "to": "STAGGER"}),
		"12.1 s · went from Chase to Stagger") and ok
	ok = _check("a re-entry says so rather than saying it went where it already was",
		EventSheetStateTrail.sentence({"at": 12.4, "from": "STAGGER", "to": "STAGGER",
			"re_entered": true, "cause_text": "On Hit"}),
		"12.4 s · On Hit fired - re-entered Stagger") and ok
	ok = _check("a whole second keeps no trailing zero, exactly as the band does",
		EventSheetStateTrail.sentence({"at": 3.0, "from": "PATROL", "to": "CHASE"}),
		"3 s · went from Patrol to Chase") and ok
	ok = _check("and while a run is two games each line says which window it is",
		EventSheetStateTrail.sentence({"at": 1.5, "from": "PATROL", "to": "CHASE",
			"instance": "host"}),
		"host · 1.5 s · went from Patrol to Chase") and ok
	# A member spelled with an underscore reads as the word the whole plugin says it with.
	ok = _check("a state is said as the word the band and the dropdown say",
		EventSheetStateTrail.sentence({"at": 0.0, "from": "CHASE", "to": "GAVE_UP"}),
		"0 s · went from Chase to Gave Up") and ok
	return ok


# -- Named only about a fire the run actually reported ---------------------------------------------
static func _test_the_row_is_named_only_when_it_fired() -> bool:
	var rows: Dictionary = EventSheetStateFacts.trail_rows(_authored_sheet())

	# The game sends its values frame first and the fires of the same flush right after it, so the
	# line is written unnamed and named one message later.
	EventSheetStateTrail.clear()
	_frame("PATROL", 0.5, rows)
	_frame("STAGGER", 0.02, rows)
	var ok: bool = _check("the line is written before the fires of its own flush arrive",
		str(_last().get("cause_text")), "")
	EventSheetStateTrail.note_fired(PackedStringArray([HIT_ROW]), PackedInt32Array([0]), rows)
	ok = _check("and the window that lands next names the row that did it",
		str(_last().get("cause_text")), "On Hit") and ok
	ok = _check("and that row is the door the line opens",
		str(_last().get("cause_uid")), HIT_ROW) and ok

	# With the Event Trace switched off no window ever arrives, so nothing is named - and the line
	# still has a door, because this sheet has exactly one row that can go to Stagger.
	EventSheetStateTrail.clear()
	_frame("PATROL", 0.5, rows)
	_frame("STAGGER", 0.02, rows)
	_frame("STAGGER", 0.27, rows)
	ok = _check("with no trace the line names nobody", str(_last().get("cause_text")), "") and ok
	ok = _check("and still opens on the one row that can go there",
		str(_last().get("cause_uid")), HIT_ROW) and ok

	# Two rows that can both go to a state, and a window in which both fired: nothing is named,
	# because a trail that guessed would be a trail that has to be checked.
	EventSheetStateTrail.clear()
	var ambiguous: Dictionary = EventSheetStateFacts.trail_rows(_two_ways_in_sheet())
	_frame("PATROL", 0.5, ambiguous)
	_frame("STAGGER", 0.02, ambiguous)
	EventSheetStateTrail.note_fired(PackedStringArray([HIT_ROW, SPOT_ROW]),
		PackedInt32Array([0]), ambiguous)
	ok = _check("two rows that could both have done it name neither",
		str(_last().get("cause_text")), "") and ok
	ok = _check("and the door falls back to the row that ANSWERS the change",
		str(_last().get("cause_uid")), ENTERING_ROW) and ok
	EventSheetStateTrail.clear()
	return ok


# -- The two patterns, read out of the ring and nothing else ---------------------------------------
static func _test_the_patterns() -> bool:
	var rows: Dictionary = EventSheetStateFacts.trail_rows(_authored_sheet())

	# A re-entry while a timed row is waiting on that very state.
	var re_entry: Array = [{"at": 1.0, "from": "STAGGER", "to": "STAGGER", "re_entered": true,
		"cause_text": "On Hit", "cause_uid": HIT_ROW, "same_frame_fires": 1}]
	var notes: Array[Dictionary] = EventSheetStateTrail.notes_for(re_entry, rows)
	var ok: bool = _check("a re-entry that restarts a waiting row is worth saying",
		str(notes[0].get("text", "")),
		"Re-entering Stagger restarted its hold, so Is in Stagger for over 6s starts counting from 0 again - and On leaving Stagger never ran, because the object never left.")
	ok = _check("and it lands the reader on the row that is now counting again",
		str(notes[0].get("uid", "")), CALM_ROW) and ok
	ok = _check("filed under the kind the tab addresses it by",
		str(notes[0].get("kind", "")), EventSheetStateTrail.PATTERN_RE_ENTERED) and ok

	# The same trail, three times over: one note, with how often it happened - a note printed three
	# times is a note nobody reads, and "eleven times" is the half that explains the bug.
	var repeated: Array = [re_entry[0], re_entry[0], re_entry[0]]
	var counted: Array[Dictionary] = EventSheetStateTrail.notes_for(repeated, rows)
	ok = _check("a pattern that repeats is said once", counted.size(), 1) and ok
	ok = _check("with how often it happened on the end of it",
		str(counted[0].get("text", "")).ends_with("This happened 3 times in this run."), true) and ok

	# Nothing waiting on that state: the hold going back to 0 changed nothing a reader can see.
	var quiet: Array[Dictionary] = EventSheetStateTrail.notes_for(
		[{"at": 1.0, "from": "CHASE", "to": "CHASE", "re_entered": true}], rows)
	ok = _check("a re-entry no row is waiting on raises no note", quiet.size(), 0) and ok

	# The row that caused a real move fired twice inside one game frame.
	var twice: Array = [{"at": 2.0, "from": "PATROL", "to": "STAGGER", "re_entered": false,
		"cause_text": "On Hit", "cause_uid": HIT_ROW, "same_frame_fires": 2}]
	var doubled: Array[Dictionary] = EventSheetStateTrail.notes_for(twice, rows)
	ok = _check("a row that fired twice in one frame is said in words",
		str(doubled[0].get("text", "")),
		"On Hit fired 2 times in one frame and the state changed once: going to Stagger while already there does nothing, so On entering Stagger ran once.") and ok
	ok = _check("and the line lands on the row that fired",
		str(doubled[0].get("uid", "")), HIT_ROW) and ok
	ok = _check("filed under its own kind",
		str(doubled[0].get("kind", "")), EventSheetStateTrail.PATTERN_TWICE_IN_A_FRAME) and ok

	# One fire is one fire, and a fire nothing named is not a pattern anybody can be pointed at.
	ok = _check("one fire in a frame is not a pattern",
		EventSheetStateTrail.notes_for([{"at": 2.0, "from": "PATROL", "to": "STAGGER",
			"cause_text": "On Hit", "same_frame_fires": 1}], rows).size(), 0) and ok
	ok = _check("and an unnamed row cannot be said to have fired twice",
		EventSheetStateTrail.notes_for([{"at": 2.0, "from": "PATROL", "to": "STAGGER",
			"cause_text": "", "same_frame_fires": 4}], rows).size(), 0) and ok

	# A sheet with no On entering / On leaving row still gets a note - it simply names the one row
	# it can name rather than inventing a second.
	var bare: Dictionary = EventSheetStateFacts.trail_rows(_timed_only_sheet())
	ok = _check("with no On leaving row the note says the half it knows",
		str(EventSheetStateTrail.notes_for(re_entry, bare)[0].get("text", "")),
		"Re-entering Stagger restarted its hold, so Is in Stagger for over 6s starts counting from 0 again.") and ok
	ok = _check("and with no On entering row so does the other one",
		str(EventSheetStateTrail.notes_for(twice, bare)[0].get("text", "")),
		"On Hit fired 2 times in one frame and the state changed once: going to Stagger while already there does nothing.") and ok
	ok = _check("an empty trail points at nothing",
		EventSheetStateTrail.notes_for([], rows).size(), 0) and ok
	return ok


# -- Bounded, because a trail is the recent past and not a log -------------------------------------
static func _test_the_ring_is_bounded() -> bool:
	EventSheetStateTrail.clear()
	var rows: Dictionary = EventSheetStateFacts.trail_rows(_authored_sheet())
	_frame("PATROL", 0.0, rows)
	var walk: PackedStringArray = PackedStringArray(["CHASE", "PATROL"])
	for index: int in range(EventSheetStateTrail.RING_LIMIT + 12):
		_frame(walk[index % 2], 0.0, rows)
	var ok: bool = _check("the ring holds exactly what it says it holds",
		EventSheetStateTrail.entries().size(), EventSheetStateTrail.RING_LIMIT)
	# The OLDEST are the ones dropped, so the trail is always the recent past.
	ok = _check("and what it kept is the end of the run, not the start of it",
		float(_last().get("at")),
		float(EventSheetStateTrail.RING_LIMIT + 12) * EventSheetStateWatch.CADENCE_SECONDS) and ok
	EventSheetStateTrail.clear()
	return ok


# -- The run owns it ------------------------------------------------------------------------------
static func _test_the_run_owns_it() -> bool:
	EventSheetStateTrail.clear()
	var rows: Dictionary = EventSheetStateFacts.trail_rows(_authored_sheet())
	var ok: bool = _check("with no run there is nothing to report",
		EventSheetStateTrail.has_run(), false)
	_frame("PATROL", 0.0, rows)
	ok = _check("a frame carrying a state IS a run", EventSheetStateTrail.has_run(), true) and ok
	ok = _check("and a run that has not changed state yet is not an empty table",
		EventSheetStateTrail.entries().size(), 0) and ok
	_frame("CHASE", 0.0, rows)
	ok = _check("a change of state is a line", EventSheetStateTrail.entries().size(), 1) and ok
	# A frame with no state at all: this object has none, and a line about one would be a lie.
	EventSheetStateTrail.note_frame({"score": 10}, "", rows)
	ok = _check("a frame carrying no state forgets what it was saying",
		EventSheetStateTrail.entries().size(), 0) and ok
	EventSheetStateTrail.clear()
	ok = _check("and a new Run empties it", EventSheetStateTrail.has_run(), false) and ok
	ok = _check("down to the last line", EventSheetStateTrail.all_entries().size(), 0) and ok
	return ok


# -- Two copies of one game never mix --------------------------------------------------------------
static func _test_two_copies_never_mix() -> bool:
	EventSheetStateTrail.clear()
	var rows: Dictionary = EventSheetStateFacts.trail_rows(_authored_sheet())
	for tag: String in ["host", "client"]:
		for _repeat: int in range(2):
			EventSheetStateTrail.note_frame({"state": "PATROL", "state_seconds": 0.0}, tag, rows)
	EventSheetStateTrail.note_frame({"state": "CHASE", "state_seconds": 0.0}, "host", rows)
	EventSheetStateTrail.note_frame({"state": "STAGGER", "state_seconds": 0.0}, "client", rows)
	var ok: bool = _check("each window keeps its own trail",
		"%d/%d" % [EventSheetStateTrail.entries("host").size(),
			EventSheetStateTrail.entries("client").size()], "1/1")
	ok = _check("and the two read as one list, in the order they happened",
		EventSheetStateTrail.sentence(EventSheetStateTrail.all_entries()[0] as Dictionary),
		"client · 0.5 s · went from Patrol to Stagger") and ok
	# The fired-events message says WHICH rows fired and not which window they fired in, so a
	# labelled run names nobody rather than tossing a coin between two games.
	EventSheetStateTrail.note_fired(PackedStringArray([HIT_ROW]), PackedInt32Array([0]), rows)
	ok = _check("and a row is never named to the wrong copy of the game",
		str((EventSheetStateTrail.entries("client")[0] as Dictionary).get("cause_text")), "") and ok
	# A lone run arriving after a labelled one replaces it entirely - the rule the value chips follow.
	EventSheetStateTrail.note_frame({"state": "PATROL", "state_seconds": 0.0}, "", rows)
	ok = _check("a lone run and a labelled one never stand together",
		EventSheetStateTrail.all_entries().size(), 0) and ok
	EventSheetStateTrail.clear()
	return ok


# -- The index the sentences are written from ------------------------------------------------------
static func _test_the_index_reads_the_sheet() -> bool:
	var rows: Dictionary = EventSheetStateFacts.trail_rows(_authored_sheet())
	var causes: Array = rows["causes"]
	var going: PackedStringArray = PackedStringArray()
	for entry: Variant in causes:
		going.append("%s->%s" % [str((entry as Dictionary)["uid"]),
			str((entry as Dictionary)["to"])])
	# Sorted, because a list read in encounter order is a value that moves when nothing meaningful did.
	going.sort()
	var ok: bool = _check("every row that can move the object is indexed, with where it moves it",
		going, PackedStringArray(["row-calm->PATROL", "row-hit->STAGGER", "row-spot->CHASE"]))
	ok = _check("and each is said as the trigger it hangs off",
		str((causes[0] as Dictionary)["text"]), "On Hit") and ok
	ok = _check("the timed question is indexed with BOTH its answers filled in",
		str(((rows["timed"] as Dictionary)["STAGGER"] as Dictionary)["text"]),
		"Is in Stagger for over 6s") and ok
	ok = _check("the row that answers a leaving is indexed by the state it leaves",
		str(((rows["leaving"] as Dictionary)["STAGGER"] as Dictionary)["uid"]), LEAVING_ROW) and ok
	ok = _check("and the row that answers an entering, by the state it enters",
		str(((rows["entering"] as Dictionary)["STAGGER"] as Dictionary)["text"]),
		"On entering Stagger") and ok
	# An object with no states declared has no index at all, and neither has nothing.
	var stateless: EventSheetResource = EventSheetResource.new()
	stateless.host_class = "Node"
	ok = _check("an object with no states indexes nothing",
		(EventSheetStateFacts.trail_rows(stateless)["causes"] as Array).size(), 0) and ok
	ok = _check("and neither does no sheet at all",
		(EventSheetStateFacts.trail_rows(null)["timed"] as Dictionary).size(), 0) and ok
	return ok


# -- It reads down, and it draws nothing ------------------------------------------------------------
static func _test_it_reads_down_and_draws_nothing() -> bool:
	var source: String = FileAccess.get_file_as_string(OWN_FILE)
	var ok: bool = _check("the trail is there to be read", source.is_empty(), false)
	var named: PackedStringArray = PackedStringArray()
	for shape: String in REFUSED_SHAPES:
		if source.contains(shape):
			named.append(shape)
	ok = _check("and it is a list of sentences and nothing else", named,
		PackedStringArray()) and ok
	# Strictly read-only: no sheet, no row and no resource is reachable from it, which is what makes
	# "the debugger never edits the document" a property of the code rather than a promise about it.
	var reaches: PackedStringArray = PackedStringArray()
	for word: String in ["EventSheetResource", "EventRow", "ACECondition", "ACEAction",
			"ResourceSaver", "FileAccess"]:
		if source.contains(word):
			reaches.append(word)
	ok = _check("and it cannot reach a sheet at all", reaches, PackedStringArray()) and ok
	# The tab is where the words live, so the empty state and the hint are the tab's own.
	ok = _check("the Trail tab sits beside the Profile tab, which reads the same run",
		",".join(EventSheetDebuggerWindow.TAB_TITLES),
		"Inspect,Watch,Profile,Trail,Breakpoints") and ok
	ok = _check("and says what to switch on before a run has reported anything",
		str(EventSheetDebuggerWindow.EMPTY_STATES.get("Trail", "")).is_empty(), false) and ok
	return ok


# -- Fixtures ---------------------------------------------------------------------------------------
## The staged machine: an enemy that patrols, spots you, is hit into a stagger, and calms down after
## six seconds - with both triggers that answer the stagger.
static func _authored_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	EventSheetStatesDialog.write(sheet, DECLARED, STARTS_IN)
	var hit: EventRow = _event(HIT_ROW, "signal:hit", {})
	hit.actions.append(_action("GoToState", {"state": "STAGGER"}))
	sheet.events.append(hit)
	var calm: EventRow = _event(CALM_ROW, "OnProcess", {})
	calm.conditions.append(_condition("InStateForOver", {"state": "STAGGER", "seconds": "6"}))
	calm.actions.append(_action("GoToState", {"state": "PATROL"}))
	sheet.events.append(calm)
	var spot: EventRow = _event(SPOT_ROW, "OnProcess", {})
	spot.conditions.append(_condition("InState", {"state": "PATROL"}))
	spot.actions.append(_action("GoToState", {"state": "CHASE"}))
	sheet.events.append(spot)
	sheet.events.append(_event(LEAVING_ROW, "OnLeavingState", {"state": "STAGGER"}))
	sheet.events.append(_event(ENTERING_ROW, "OnEnteringState", {"state": "STAGGER"}))
	return sheet


## The same machine with a SECOND way into the stagger, which is what makes a window ambiguous.
static func _two_ways_in_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = _authored_sheet()
	var also: EventRow = _event(SPOT_ROW, "OnProcess", {})
	also.actions.append(_action("GoToState", {"state": "STAGGER"}))
	sheet.events.append(also)
	return sheet


## A machine with the timed question and neither trigger, so a note has only one row to name.
static func _timed_only_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	EventSheetStatesDialog.write(sheet, DECLARED, STARTS_IN)
	var calm: EventRow = _event(CALM_ROW, "OnProcess", {})
	calm.conditions.append(_condition("InStateForOver", {"state": "STAGGER", "seconds": "6"}))
	sheet.events.append(calm)
	return sheet


static func _event(uid: String, trigger_id: String, trigger_params: Dictionary) -> EventRow:
	var row: EventRow = EventRow.new()
	row.event_uid = uid
	row.trigger_provider_id = "Core"
	row.trigger_id = trigger_id
	row.trigger_params = trigger_params
	return row


static func _condition(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	return condition


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


## One streamed values frame for the lone run, shaped exactly as the running game sends it.
static func _frame(member: String, seconds: float, rows: Dictionary) -> void:
	EventSheetStateTrail.note_frame({
		EventSheetStateWatch.STATE_KEY: member,
		EventSheetStateWatch.SECONDS_KEY: seconds,
	}, "", rows)


static func _last() -> Dictionary:
	var ring: Array = EventSheetStateTrail.entries()
	return {} if ring.is_empty() else ring[ring.size() - 1] as Dictionary


static func _check(label: String, got: Variant, expected: Variant) -> bool:
	if _same(got, expected):
		print("[PASS] state_trail_test: %s" % label)
		return true
	print("[FAIL] state_trail_test: %s\n  expected: %s\n  got:      %s" % [label, expected, got])
	return false


## Compared as text for everything that is not already the same value, so a PackedStringArray and an
## Array of the same words do not fail for being two spellings of one answer.
static func _same(got: Variant, expected: Variant) -> bool:
	if got == expected:
		return true
	return typeof(got) != typeof(expected) and str(got) == str(expected)
