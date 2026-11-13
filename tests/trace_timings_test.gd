# Godot EventSheets - the per-event timing model the row overlay and the stutter tip read.
# Pins the self-time model over a FIXTURE trace window: a fire is charged the time up to the next
# fire in its frame, a fire closed by the flush is charged to the flush, the last fire of a frame
# that has already ended is not guessed at, and an event nobody could measure reads as unknown.
@tool
class_name TraceTimingsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	# Two frames. Frame 1 fires a, b, c; frame 2 fires a, b. Stamps are microseconds.
	#   a: 1000 -> 1200 = 200          b: 1200 -> 1500 = 300      c: last of frame 1, unmeasured
	#   a: 20000 -> 20100 = 100        b: last of frame 2, closed by the flush at 20400 = 300
	EventSheetTraceTimings.reset()
	EventSheetTraceHitCounts.reset()
	var uids: PackedStringArray = PackedStringArray(["a", "b", "c", "a", "b"])
	EventSheetTraceHitCounts.note_fired(uids)
	EventSheetTraceTimings.note_window(uids,
		PackedInt64Array([1000, 1200, 1500, 20000, 20100]),
		PackedInt32Array([0, 3]), 20400)
	var ok: bool = SUPPORT.pins("trace_timings_test", [
		["a fire is charged the time up to the next fire in its frame", EventSheetTraceTimings.usec_for("a"), 300],
		["and a fire closed by the flush is charged to the flush", EventSheetTraceTimings.usec_for("b"), 600],
		["the last fire of a frame that has already ended is not guessed at", EventSheetTraceTimings.usec_for("c"), 0],
		["only the measurable fires are averaged over", EventSheetTraceTimings.measured_calls_for("a"), 2],
		["the per-fire time is the average of those", EventSheetTraceTimings.ms_per_call("a"), 0.15],
		["an event with no measurable fire reads as unknown, never as zero", EventSheetTraceTimings.ms_per_call("c"), -1.0],
		["the run's traced span is first stamp to flush", EventSheetTraceTimings.run_span_usec(), 19400],
		["the frame ruler counted both frames", EventSheetTraceTimings.frames(), 2],
	])
	EventSheetTraceTimings.reset()
	EventSheetTraceHitCounts.reset()
	ok = SUPPORT.check("trace_timings_test", "resetting forgets the run", EventSheetTraceTimings.has_run(), false) and ok
	# A window with no stamps at all (an older debug compile) degrades rather than erroring.
	EventSheetTraceTimings.note_window(PackedStringArray(["a"]), PackedInt64Array(), PackedInt32Array(), 0)
	ok = SUPPORT.check("trace_timings_test", "a window with no times still counts as a run", EventSheetTraceTimings.has_run(), true) and ok
	ok = SUPPORT.check("trace_timings_test", "and reports no time rather than a wrong one", EventSheetTraceTimings.usec_for("a"), 0) and ok
	EventSheetTraceTimings.reset()
	return ok
