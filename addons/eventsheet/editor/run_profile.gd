# Godot EventSheets - the ONE reader behind every number the gutter shows.
#
# Two tallies already stream from a traced run: how many times each row fired (the hit counts) and
# how long each fire took (the timings). Both are statics that live and die with the editor session,
# which is fine while the game is running and useless the next morning - and "the numbers were gone
# when I came back" is exactly when a reader needs them.
#
# So this holds the join: the LIVE run while one is streaming, and the last run written to disk
# otherwise. Every overlay asks here and nowhere else, which is what keeps the two numbers agreeing
# and what makes the cost of the feature countable:
#
#   - the stored run is parsed ONCE per editor session (`load_stored`, called when a sheet opens),
#   - every question after that is one dictionary lookup, so the draw loop stays a draw loop,
#   - nothing is ever measured in the editor itself; these are last session's numbers, labelled.
#
# The thresholds are stated here rather than in the theme because they are FACTS about a frame, not
# taste: a frame at 60 fps is 16.7 ms, so a single row over 1 ms is worth a glance and one over 4 ms
# is a quarter of the budget. The colours those bands wear do come from the theme.
@tool
class_name EventSheetRunProfile
extends RefCounted

## Where the last run is kept between editor sessions. One file per project (it lives in the
## project's own user directory), holding one run - the last one.
const STORE_PATH := "user://eventsheets_last_run.cfg"

## A single fire costing more than this many milliseconds is worth a glance (amber); more than the
## second is a quarter of a 60 fps frame in one row (red).
const COST_WARM_MS := 1.0
const COST_HOT_MS := 4.0

## The cost bands, as the ids the renderer and the tests address.
const BAND_NONE := ""
const BAND_WARM := "warm"
const BAND_HOT := "hot"

## A trigger firing more often than this many times per frame is firing absurdly often - a "once per
## frame" row that fires four times a frame is wired to something it should not be. Below the
## minimum nothing is claimed: three fires in two frames is a rounding accident, not a pattern.
const ABSURD_FIRES_PER_FRAME := 2.0
const ABSURD_MINIMUM_FIRES := 60

## The last run read off disk: uid -> {calls, measured, usec}. Empty until `load_stored()` has run,
## deliberately: a reader that has never asked for the stored run must see exactly the live one, so
## a test and a fresh editor both start from nothing rather than from whatever is in user://.
static var _stored: Dictionary = {}
static var _stored_frames: int = 0
static var _stored_when: String = ""
static var _stored_loaded: bool = false


## True while a run - live or stored - has numbers to show. Every overlay gates on this: with no
## run at all, the gutter draws exactly what it always drew.
static func has_numbers() -> bool:
	return EventSheetTraceHitCounts.has_run() or not _stored.is_empty()


## True when the numbers are this session's rather than the file's. The label says which, and the
## Why panel and the overlays both need to know before they call anything "now".
static func is_live() -> bool:
	return EventSheetTraceHitCounts.has_run()


## What the numbers ARE, in the words the tooltip and the status line use.
static func label() -> String:
	if is_live():
		return "this run"
	if _stored.is_empty():
		return "no run yet"
	return "last run" if _stored_when.is_empty() else "last run, %s" % _stored_when


## WHEN the stored run was written, and "" when no run has been written at all. It is the identity
## of a completed run: a receipt taken before one and read after it compares two different numbers
## precisely because this string changed in between.
static func stored_when() -> String:
	return _stored_when


static func calls_for(uid: String) -> int:
	if is_live():
		return EventSheetTraceHitCounts.count_for(uid)
	return int((_stored.get(uid, {}) as Dictionary).get("calls", 0))


## Milliseconds one fire of this row cost, or -1.0 when nothing about it was measurable. A row that
## only ever fires last in its frame has calls and no time, and says "-" rather than "0.00".
static func ms_for(uid: String) -> float:
	if is_live():
		return EventSheetTraceTimings.ms_per_call(uid)
	var entry: Dictionary = _stored.get(uid, {})
	var measured: int = int(entry.get("measured", 0))
	if measured <= 0:
		return -1.0
	return float(entry.get("usec", 0)) / float(measured) / 1000.0


## Frames the run reported - the denominator of "how often does this fire".
static func frames() -> int:
	return EventSheetTraceTimings.frames() if is_live() else _stored_frames


## Which band a row's cost falls in. "" for a row with no measurable cost, which is not the same as
## a cheap one and is never painted as though it were.
static func cost_band(uid: String) -> String:
	var ms: float = ms_for(uid)
	if ms < 0.0:
		return BAND_NONE
	if ms >= COST_HOT_MS:
		return BAND_HOT
	if ms >= COST_WARM_MS:
		return BAND_WARM
	return BAND_NONE


## How many times this row fired per frame of the run. 0.0 when the run reported no frames.
static func fires_per_frame(uid: String) -> float:
	var frame_count: int = frames()
	if frame_count <= 0:
		return 0.0
	return float(calls_for(uid)) / float(frame_count)


## True when a row fires so much more often than once a frame that the wiring is the bug.
static func is_absurd(uid: String) -> bool:
	return calls_for(uid) >= ABSURD_MINIMUM_FIRES and fires_per_frame(uid) >= ABSURD_FIRES_PER_FRAME


## The gutter chip's text for one row. `costs` picks WHICH number is on the chip: milliseconds when
## the reader asked for costs and the row has one, the fire count otherwise. The gutter is 20px
## wide, so exactly one number fits and the other is one hover away.
static func chip_text(uid: String, costs: bool) -> String:
	if costs:
		var ms: float = ms_for(uid)
		if ms >= 0.0:
			return "%.1f" % ms if ms < 10.0 else "%d" % int(round(ms))
		# Asked for costs, has none: the fire count is the honest fallback, and "-" would waste the
		# only line the gutter has on saying nothing.
	var count: int = calls_for(uid)
	var compact: String = EventSheetTraceHitCounts.chip_text(count)
	return ("x" + compact) if count < 1000 else compact


## The hover answer for one row: the count, the cost and which run they came from, in one sentence.
## Empty when there is nothing to report, so the caller leaves the hover to whatever it was.
static func tooltip_for(uid: String, event_number: int = 0) -> String:
	if not has_numbers() or uid.is_empty():
		return ""
	var lead: String = "Event %d: " % event_number if event_number > 0 else ""
	var count: int = calls_for(uid)
	var run_words: String = " (%s)" % label()
	if count == 0:
		return lead + "never fired" + run_words + "."
	var parts: PackedStringArray = PackedStringArray()
	parts.append("fired %s time%s" % [EventSheetTraceHitCounts.format_count(count), "" if count == 1 else "s"])
	var ms: float = ms_for(uid)
	if ms >= 0.0:
		parts.append("%.2f ms each" % ms)
	if is_absurd(uid):
		parts.append("%.1f times a frame" % fires_per_frame(uid))
	return lead + ", ".join(parts) + run_words + "."


# ── The file: written when a run ends, read once when a sheet opens ────────────────────────
## Writes the LIVE run to disk, so tomorrow's editor opens the sheet already annotated. Called when
## a debug session ends; a session that streamed nothing writes nothing rather than replacing a real
## run with an empty one.
static func save_run() -> bool:
	if not EventSheetTraceHitCounts.has_run():
		return false
	var uids: PackedStringArray = PackedStringArray()
	var calls: PackedInt32Array = PackedInt32Array()
	var measured: PackedInt32Array = PackedInt32Array()
	var usec: PackedInt64Array = PackedInt64Array()
	# Every row the run COUNTED, not every row it timed: a row that only ever fires last in its frame
	# has no measurable time, and dropping it here would lose the fact that it fired at all.
	for uid: String in EventSheetTraceHitCounts.counted_uids():
		if uid.is_empty():
			continue
		uids.append(uid)
		calls.append(EventSheetTraceHitCounts.count_for(uid))
		measured.append(EventSheetTraceTimings.measured_calls_for(uid))
		usec.append(EventSheetTraceTimings.usec_for(uid))
	if uids.is_empty():
		return false
	var file: ConfigFile = ConfigFile.new()
	file.set_value("run", "uids", uids)
	file.set_value("run", "calls", calls)
	file.set_value("run", "measured", measured)
	file.set_value("run", "usec", usec)
	file.set_value("run", "frames", EventSheetTraceTimings.frames())
	file.set_value("run", "when", Time.get_datetime_string_from_system(false, true).replace("T", " "))
	if file.save(STORE_PATH) != OK:
		return false
	_adopt(uids, calls, measured, usec, EventSheetTraceTimings.frames(),
		str(file.get_value("run", "when", "")))
	return true


## Reads the stored run, ONCE per editor session. Called when a sheet opens: the join happens there
## and never again, so no draw and no keystroke ever touches the disk.
static func load_stored() -> void:
	if _stored_loaded:
		return
	_stored_loaded = true
	var file: ConfigFile = ConfigFile.new()
	if file.load(STORE_PATH) != OK:
		return
	_adopt(
		PackedStringArray(file.get_value("run", "uids", PackedStringArray())),
		PackedInt32Array(file.get_value("run", "calls", PackedInt32Array())),
		PackedInt32Array(file.get_value("run", "measured", PackedInt32Array())),
		PackedInt64Array(file.get_value("run", "usec", PackedInt64Array())),
		int(file.get_value("run", "frames", 0)),
		str(file.get_value("run", "when", "")))


## Four parallel arrays -> the lookup table the overlays read. Short arrays are tolerated (a file
## written by an older build) by reading only as far as all four go together.
static func _adopt(uids: PackedStringArray, calls: PackedInt32Array, measured: PackedInt32Array,
		usec: PackedInt64Array, frame_count: int, when: String) -> void:
	_stored.clear()
	var count: int = mini(mini(uids.size(), calls.size()), mini(measured.size(), usec.size()))
	for index: int in range(count):
		_stored[uids[index]] = {
			"calls": calls[index], "measured": measured[index], "usec": usec[index],
		}
	_stored_frames = frame_count
	_stored_when = when


## Forgets both runs and deletes the file - Clear measured costs. After this the gutter is back to
## event numbers, which is what "clear" has to mean or the word is a lie.
static func forget() -> void:
	EventSheetTraceHitCounts.reset()
	EventSheetTraceTimings.reset()
	_stored.clear()
	_stored_frames = 0
	_stored_when = ""
	_stored_loaded = true
	if FileAccess.file_exists(STORE_PATH):
		DirAccess.remove_absolute(STORE_PATH)


## A completed run, adopted directly. The seam a test needs to stand a run up without a debug
## session and, more to the point, to move the stored run's IDENTITY on: two runs a second apart
## carry the same stamp, and the receipts compare identities.
static func adopt_run_for_test(uid: String, calls: int, measured: int, usec: int, when: String) -> void:
	EventSheetTraceHitCounts.reset()
	EventSheetTraceTimings.reset()
	_adopt(PackedStringArray([uid]), PackedInt32Array([calls]), PackedInt32Array([measured]),
		PackedInt64Array([usec]), 1, when)
	_stored_loaded = true


## Drops what was read from disk WITHOUT touching the file - the reset a test needs between cases,
## and the only way back to "this session has never asked for the stored run".
static func forget_stored_for_test() -> void:
	_stored.clear()
	_stored_frames = 0
	_stored_when = ""
	_stored_loaded = false
