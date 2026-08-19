# Godot EventSheets - the replay recorder: record a play, keep it as a test.
#
# Record on the Debug bar, play the game, Stop, "Save as Test Sheet…". What comes out is not a
# recording format: it is an ORDINARY Test sheet whose rows read
#
#   simulate control jump pressed at frame 12
#   simulate control jump released at frame 19
#   expect Player.hp = 90 at frame 300        (a checkpoint the reader adds)
#
# so it can be read, edited, diffed and reviewed like any other sheet, and replayed headlessly by
# the same runner that runs every other Test sheet. That is the whole point of recording into the
# sheet's own words rather than into a binary log: the cheapest regression net a small team has is
# one they can read.
#
# WHAT IS CAPTURED. Only what the game can be told to do again: the CONTROLS (the same seam the
# Simulate control rows drive), never raw device events. A mouse jiggle is not reproducible; "jump
# pressed on frame 12" is. Every entry carries the frame it happened on, counted from the frame
# recording started, which is exactly what the frame-addressed rows replay against.
#
# This file holds the recording and the writing, with no editor in it, so the panel, the headless
# replay and the tests all agree about what a recording is.
@tool
class_name EventSheetReplayRecorder
extends RefCounted

## What a recorded entry is: "pressed" / "released" for a control, "checkpoint" for one the reader
## added. Frozen - a saved recording is a plain sheet, but the panel's own list is keyed on these.
const PRESSED := "pressed"
const RELEASED := "released"
const CHECKPOINT := "checkpoint"

## Every entry, in the order it happened: {kind, action / named, frame, ...}.
var entries: Array[Dictionary] = []
## Whether Record is down.
var recording: bool = false
## The engine frame Record was pressed on - every entry's frame is counted from here.
var _frame_zero: int = 0


## ⏺ Record: start over. A second Record throws the previous take away rather than appending to it,
## because a take is one continuous play and two spliced ones replay as neither.
func start(at_frame: int) -> void:
	entries.clear()
	recording = true
	_frame_zero = at_frame


## ⏹ Stop. The take is kept, so Save as Test Sheet… still has something to write after stopping.
func stop() -> void:
	recording = false


## The frame an engine frame counts as inside this take.
func take_frame(engine_frame: int) -> int:
	return maxi(engine_frame - _frame_zero, 0)


## One control going down or coming up, at an engine frame. Ignored while not recording, so the
## panel never has to guard its own callback.
func record_control(action: String, pressed: bool, engine_frame: int) -> void:
	if not recording or action.strip_edges().is_empty():
		return
	entries.append({"kind": PRESSED if pressed else RELEASED, "action": action,
		"frame": take_frame(engine_frame)})


## An InputEvent the running game received, recorded as the CONTROLS it means. An event that maps to
## no control is dropped on purpose: a replay can only press controls, and silently recording
## something that will never be replayed is the one way a recording lies.
func record_input(event: InputEvent, engine_frame: int, actions: PackedStringArray) -> void:
	if not recording or event == null:
		return
	for action: String in actions:
		if not event.is_action(action):
			continue
		record_control(action, event.is_action_pressed(action), engine_frame)


## A checkpoint the reader adds: "Expect Player's hp = 90 at frame 300". Allowed after Stop, which
## is when a reader actually knows what they want to pin.
func add_checkpoint(named: String, actual: String, expected: String, frame: int) -> void:
	entries.append({"kind": CHECKPOINT, "named": named, "actual": actual, "expected": expected,
		"frame": maxi(frame, 0)})
	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("frame", 0)) < int(right.get("frame", 0)))


## How long the take is, in frames - what the panel shows and what a runner needs for its deadline.
func length_in_frames() -> int:
	var longest: int = 0
	for entry: Dictionary in entries:
		longest = maxi(longest, int(entry.get("frame", 0)))
	return longest


## The take read back in the sheet's own words, one line per row it will write. The panel's list and
## the saved sheet can never drift apart because both come from here.
func take_lines() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		out.append(entry_words(entry))
	return out


## One entry as the row it becomes.
static func entry_words(entry: Dictionary) -> String:
	var frame: int = int(entry.get("frame", 0))
	match str(entry.get("kind", "")):
		PRESSED:
			return "simulate control %s pressed at frame %d" % [str(entry.get("action", "")), frame]
		RELEASED:
			return "simulate control %s released at frame %d" % [str(entry.get("action", "")), frame]
		CHECKPOINT:
			return "expect %s = %s at frame %d" % [str(entry.get("actual", "")), str(entry.get("expected", "")), frame]
	return ""


## The take as a Test sheet, ready to save. One event - On test start - with the take's rows under
## it in frame order, which is what a replay is: a single run of things happening at named frames.
##
## `test_name` names both the sheet and the claim a checkpoint records under when the reader did not
## name it themselves.
func to_test_sheet(test_name: String) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.test_mode = true
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_id = "OnTestStart"
	event.trigger_provider_id = "Core"
	event.event_uid = "replay_%s" % test_name.to_snake_case()
	for entry: Dictionary in entries:
		var action_row: ACEAction = _entry_row(entry, test_name)
		if action_row != null:
			event.actions.append(action_row)
	sheet.events.append(event)
	return sheet


static func _entry_row(entry: Dictionary, test_name: String) -> ACEAction:
	var row: ACEAction = ACEAction.new()
	row.provider_id = "Core"
	var frame: String = str(int(entry.get("frame", 0)))
	match str(entry.get("kind", "")):
		PRESSED:
			row.ace_id = "SimulateControlPressedAtFrame"
			row.params = {"action": "\"%s\"" % str(entry.get("action", "")), "frame": frame}
		RELEASED:
			row.ace_id = "SimulateControlReleasedAtFrame"
			row.params = {"action": "\"%s\"" % str(entry.get("action", "")), "frame": frame}
		CHECKPOINT:
			row.ace_id = "ExpectAtFrame"
			var named: String = str(entry.get("named", ""))
			row.params = {
				"named": "\"%s\"" % (named if not named.strip_edges().is_empty() else test_name),
				"actual": str(entry.get("actual", "")),
				"expected": str(entry.get("expected", "")),
				"frame": frame,
			}
		_:
			return null
	return row


## What a failed checkpoint reads as in the Doctor: the frame it drifted on and the row that ran.
## Worded once here so a headless replay and the editor's panel say the same thing.
static func drift_message(claim_name: String, frame: int, event_words: String) -> String:
	if event_words.strip_edges().is_empty():
		return "Replay drifted at frame %d: %s." % [frame, claim_name]
	return "Replay drifted at frame %d: %s (after \"%s\")." % [frame, claim_name, event_words]


## The frame a runner's report line drifted on, read back out of the failure message the
## Expect At Frame row wrote ("at frame 300 expected 90, got 74"). -1 when the message is not one
## of ours, so a plain assertion failure is never dressed up as a replay drift.
static func frame_in_message(message: String) -> int:
	var marker: String = "at frame "
	var at: int = message.find(marker)
	if at < 0:
		return -1
	var digits: String = ""
	for index: int in range(at + marker.length(), message.length()):
		if not message[index].is_valid_int():
			break
		digits += message[index]
	return int(digits) if not digits.is_empty() else -1
