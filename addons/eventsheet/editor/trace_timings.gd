# Godot EventSheets - Event Trace timings (the Profile tab's numbers).
#
# The trace already streams WHICH events fired. This is WHEN. The generated code stamps one
# microsecond reading beside every fire it records, and marks - once per frame, at the top of
# _process - how many fires had happened by the start of that frame. Two arrays and a frame ruler,
# and the whole profile falls out of them.
#
# THE MODEL, and it is worth being exact about because a profiler that lies is worse than none:
# the fires arrive in the order they ran, so the time between one fire's stamp and the NEXT fire's
# stamp is the time the first event's body took, plus whatever was evaluated to reach the second.
# That is SELF TIME - a parent event that opens a sub-event is charged only for the part before its
# first child, which is exactly right. The last fire of a frame has no successor in that frame and
# is NOT measured: the frame ended somewhere after it and nobody recorded where, and a profiler
# that guessed at that gap would report the frame's idle time as an event's cost. The frame markers
# are what make that distinction possible at all - without them a 16 ms gap between two frames is
# indistinguishable from a 16 ms event.
#
# So every number here is honest and every number here is a SAMPLE: an event that only ever fires
# last in its frame is reported with its calls and no time, and says so rather than showing a zero.
#
# Statics, for the same reason the hit counts are static: the numbers belong to the RUN, not to a
# tab, a pane or a window, and a closed debugger must not lose them.
@tool
class_name EventSheetTraceTimings
extends RefCounted

## event uid -> total measured self time, in microseconds.
static var _usec: Dictionary = {}
## event uid -> how many of its fires were measurable (never more than its hit count).
static var _measured_calls: Dictionary = {}
## The first and last stamps of the run, so a share can be a share of the traced wall time rather
## than of some other number that happens to be handy.
static var _first_usec: int = -1
static var _last_usec: int = -1
## Frames the run has reported markers for. What "per frame" means here.
static var _frames: int = 0
static var _has_run: bool = false


## One streamed window -> the profile. `uids` is the fired tally (one entry per fire, in order),
## `stamps` the microsecond reading beside each of them, `markers` the fire-count at the top of
## each frame in the window, and `flush_usec` the moment the window was sent - which is what closes
## the last fire of the last frame.
##
## Tolerant of a short or absent `stamps` array: an older debug compile streams fires without
## times, and that must degrade to "calls, no times" rather than to an error mid-session.
static func note_window(uids: PackedStringArray, stamps: PackedInt64Array,
		markers: PackedInt32Array, flush_usec: int) -> void:
	_has_run = true
	_frames += markers.size()
	var count: int = mini(uids.size(), stamps.size())
	if count == 0:
		return
	if _first_usec < 0:
		_first_usec = stamps[0]
	_last_usec = maxi(_last_usec, flush_usec)
	for index: int in range(count):
		# Where does this fire's frame end? At the next frame marker after it, or at the flush.
		var frame_end: int = count
		for marker: int in markers:
			if marker > index:
				frame_end = mini(frame_end, marker)
				break
		var next_stamp: int = -1
		if index + 1 < frame_end:
			next_stamp = stamps[index + 1]
		elif frame_end >= count and flush_usec > 0:
			# The last fire of the LAST frame in the window: the flush is the only honest end for
			# it, and it really is in the same frame (the flush runs inside that _process).
			next_stamp = flush_usec
		if next_stamp < 0:
			continue  # last fire of a frame that has already ended - unmeasurable, never guessed
		var uid: String = uids[index]
		if uid.is_empty():
			continue
		_usec[uid] = int(_usec.get(uid, 0)) + maxi(next_stamp - stamps[index], 0)
		_measured_calls[uid] = int(_measured_calls.get(uid, 0)) + 1


## Forgets the run. Called wherever the hit counts are reset - they are two halves of one tally.
static func reset() -> void:
	_usec.clear()
	_measured_calls.clear()
	_first_usec = -1
	_last_usec = -1
	_frames = 0
	_has_run = false


static func has_run() -> bool:
	return _has_run


static func usec_for(uid: String) -> int:
	return int(_usec.get(uid, 0))


static func measured_calls_for(uid: String) -> int:
	return int(_measured_calls.get(uid, 0))


static func frames() -> int:
	return _frames


## The traced wall time of the run, in microseconds - the denominator every share is taken over.
## Zero until a second stamp arrives, and a share over zero is reported as zero rather than as
## infinity.
static func run_span_usec() -> int:
	if _first_usec < 0 or _last_usec <= _first_usec:
		return 0
	return _last_usec - _first_usec


## What one fire of this event costs, in milliseconds. -1.0 when nothing was measurable, which the
## caller shows as "-" rather than as 0.00.
static func ms_per_call(uid: String) -> float:
	var calls: int = measured_calls_for(uid)
	if calls <= 0:
		return -1.0
	return float(usec_for(uid)) / float(calls) / 1000.0


## This event's share of the run's traced wall time, 0.0 to 1.0.
static func share_of_run(uid: String) -> float:
	var span: int = run_span_usec()
	if span <= 0:
		return 0.0
	return clampf(float(usec_for(uid)) / float(span), 0.0, 1.0)


## The profile, busiest first: one row per event that fired, as
## {uid, event_number, calls, ms, share}. `event_numbers` maps uid -> the number the sheet shows,
## so the caller does not have to look each one up again; a uid the caller did not name still gets
## a row, because "something is eating the frame and it is not on this sheet" is worth seeing.
##
## `calls` is the HIT count (every fire), while `ms` is averaged over the measurable ones only -
## the two are deliberately different numbers and the tab says so.
static func rows(event_numbers: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for uid: Variant in _usec.keys():
		var key: String = str(uid)
		out.append({
			"uid": key,
			"event_number": int(event_numbers.get(key, 0)),
			"calls": EventSheetTraceHitCounts.count_for(key),
			"measured": measured_calls_for(key),
			"ms": ms_per_call(key),
			"share": share_of_run(key),
			"total_ms": float(usec_for(key)) / 1000.0,
		})
	out.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return float(left["total_ms"]) > float(right["total_ms"]))
	return out


## One profile row as the words the tab shows: "event 12 · 0.31 ms · 12% of the run · 480 fires".
## Pure over the row, so the suite pins the sentence without a debug session.
static func row_text(row: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var number: int = int(row.get("event_number", 0))
	parts.append(("event %d" % number) if number > 0 else str(row.get("uid", "")))
	var ms: float = float(row.get("ms", -1.0))
	parts.append("-" if ms < 0.0 else "%.2f ms" % ms)
	parts.append("%d%% of the run" % int(round(float(row.get("share", 0.0)) * 100.0)))
	var calls: int = int(row.get("calls", 0))
	parts.append("%s fire%s" % [EventSheetTraceHitCounts.format_count(calls),
		"" if calls == 1 else "s"])
	return " · ".join(parts)
