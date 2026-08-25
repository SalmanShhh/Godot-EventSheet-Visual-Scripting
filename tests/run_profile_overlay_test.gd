# EventForge - the profiled run, read in the gutter (costs, counts, heat).
#
# One overlay reads two tallies and one file. What has to hold:
#   1. the join - the live run answers while it streams, the stored run answers afterwards, and
#      neither is ever mixed with the other,
#   2. the bands - a millisecond is amber, four are red, never firing is red, and firing many times
#      a frame is amber; a row with no measurable time says so instead of reading 0.00,
#   3. the gate - with both lenses off and with no run at all, the gutter is what it always was,
#   4. the file - a run written, forgotten in memory, and read back reports the same numbers, and
#      Clear really does delete it.
#
# Pure and static throughout: no viewport, no debug session, no display server.
@tool
class_name RunProfileOverlayTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	_cold()
	all_passed = _run_join() and all_passed
	all_passed = _run_bands() and all_passed
	all_passed = _run_gate() and all_passed
	all_passed = _run_file() and all_passed
	_cold()
	if all_passed:
		print("[PASS] run_profile_overlay_test: the join, the bands, the gate and the stored run")
	return all_passed


## Both tallies and the store emptied - what a fresh editor with no run looks like. Every case
## starts here, because these are process-wide statics and a leftover run answers the wrong question.
static func _cold() -> void:
	EventSheetRunProfile.forget()
	EventSheetRunProfile.forget_stored_for_test()


# ── 1. The join ───────────────────────────────────────────────────────────────────────────
static func _run_join() -> bool:
	var all_passed: bool = true
	_cold()
	all_passed = _check("nothing to show with no run", EventSheetRunProfile.has_numbers(), false) and all_passed
	all_passed = _check("and nothing to call it", EventSheetRunProfile.label(), "no run yet") and all_passed
	all_passed = _check("no tooltip either", EventSheetRunProfile.tooltip_for("aa", 4), "") and all_passed

	_stream_run()
	all_passed = _check("a streamed run has numbers", EventSheetRunProfile.has_numbers(), true) and all_passed
	all_passed = _check("and it is this one", EventSheetRunProfile.is_live(), true) and all_passed
	all_passed = _check("the label says so", EventSheetRunProfile.label(), "this run") and all_passed
	all_passed = _check("the count is the trace's", EventSheetRunProfile.calls_for("aa"), 4) and all_passed
	# 2000 usec over 4 measurable fires = 0.5 ms each.
	all_passed = _check("the cost is per fire, in milliseconds", EventSheetRunProfile.ms_for("aa"), 0.5) and all_passed
	all_passed = _check("a row nothing measured says so rather than zero",
		EventSheetRunProfile.ms_for("zz"), -1.0) and all_passed
	return all_passed


# ── 2. The bands ──────────────────────────────────────────────────────────────────────────
static func _run_bands() -> bool:
	var all_passed: bool = true
	_cold()
	# Four fires each, with different bills: half a millisecond, two, six, and one row that fired
	# four times without a single measurable gap.
	_charge("cheap", 500)
	_charge("middling", 2000)
	_charge("dear", 6000)
	EventSheetTraceHitCounts.note_fired(_repeat("cold", 4))
	all_passed = _check("half a millisecond is nothing to say",
		EventSheetRunProfile.cost_band("cheap"), EventSheetRunProfile.BAND_NONE) and all_passed
	all_passed = _check("two milliseconds is worth a glance",
		EventSheetRunProfile.cost_band("middling"), EventSheetRunProfile.BAND_WARM) and all_passed
	all_passed = _check("six is a quarter of the frame",
		EventSheetRunProfile.cost_band("dear"), EventSheetRunProfile.BAND_HOT) and all_passed
	all_passed = _check("an unmeasured row is not called cheap",
		EventSheetRunProfile.cost_band("cold"), EventSheetRunProfile.BAND_NONE) and all_passed

	# Absurd frequency: 200 fires over ten frames is twenty a frame; four fires over them is not.
	EventSheetTraceTimings.note_window(_repeat("busy", 200), _stamps(200, 10),
		PackedInt32Array([0, 20, 40, 60, 80, 100, 120, 140, 160, 180]), 2000)
	EventSheetTraceHitCounts.note_fired(_repeat("busy", 200))
	all_passed = _check("a row firing many times a frame is called out",
		EventSheetRunProfile.is_absurd("busy"), true) and all_passed
	all_passed = _check("and a row that fired four times is not",
		EventSheetRunProfile.is_absurd("cheap"), false) and all_passed

	# The chip: one number, whichever one was asked for.
	all_passed = _check("the count chip reads as a multiplier",
		EventSheetRunProfile.chip_text("cheap", false), "x4") and all_passed
	all_passed = _check("the cost chip reads as milliseconds",
		EventSheetRunProfile.chip_text("middling", true), "2.0") and all_passed
	all_passed = _check("asking for a cost nobody measured falls back to the count",
		EventSheetRunProfile.chip_text("cold", true), "x4") and all_passed
	all_passed = _check("the tooltip carries both numbers and the run",
		EventSheetRunProfile.tooltip_for("middling", 7),
		"Event 7: fired 4 times, 2.00 ms each (this run).") and all_passed
	return all_passed


# ── 3. The gate: off means nothing is drawn ───────────────────────────────────────────────
static func _run_gate() -> bool:
	var all_passed: bool = true
	_cold()
	_stream_run()
	all_passed = _check("both lenses off draws nothing",
		EventRowRenderer.hit_chip_uid(false, true, "aa"), "") and all_passed
	all_passed = _check("a lens on reports the row",
		EventRowRenderer.hit_chip_uid(true, true, "aa"), "aa") and all_passed
	all_passed = _check("a group bar never gets a chip",
		EventRowRenderer.hit_chip_uid(true, false, "aa"), "") and all_passed
	_cold()
	all_passed = _check("no run means no chip even with a lens on",
		EventRowRenderer.hit_chip_uid(true, true, "aa"), "") and all_passed
	var renderer: EventRowRenderer = EventRowRenderer.new()
	all_passed = _check("the renderer ships with the costs lens off", renderer.show_costs, false) and all_passed
	var viewport: EventSheetViewport = EventSheetViewport.new()
	all_passed = _check("the viewport ships with it off too", viewport.show_costs, false) and all_passed
	viewport.free()
	return all_passed


# ── 4. The file: a run survives the editor closing ────────────────────────────────────────
static func _run_file() -> bool:
	var all_passed: bool = true
	_cold()
	all_passed = _check("an empty run writes nothing", EventSheetRunProfile.save_run(), false) and all_passed
	_stream_run()
	all_passed = _check("a real run is written", EventSheetRunProfile.save_run(), true) and all_passed

	# What the next morning looks like: the statics gone, the file still there.
	EventSheetTraceHitCounts.reset()
	EventSheetTraceTimings.reset()
	EventSheetRunProfile.forget_stored_for_test()
	all_passed = _check("with the statics gone and nothing read, there is nothing to show",
		EventSheetRunProfile.has_numbers(), false) and all_passed
	EventSheetRunProfile.load_stored()
	all_passed = _check("the stored run comes back", EventSheetRunProfile.has_numbers(), true) and all_passed
	all_passed = _check("and knows it is not this one", EventSheetRunProfile.is_live(), false) and all_passed
	all_passed = _check("with the same count", EventSheetRunProfile.calls_for("aa"), 4) and all_passed
	all_passed = _check("and the same cost", EventSheetRunProfile.ms_for("aa"), 0.5) and all_passed
	all_passed = _check("a row it never saw is still unknown", EventSheetRunProfile.ms_for("qq"), -1.0) and all_passed
	all_passed = _check("the label names the stored run",
		EventSheetRunProfile.label().begins_with("last run"), true) and all_passed

	# Clear means the file too, or the word is a lie.
	EventSheetRunProfile.forget()
	all_passed = _check("clearing forgets the numbers", EventSheetRunProfile.has_numbers(), false) and all_passed
	all_passed = _check("and deletes the file",
		FileAccess.file_exists(EventSheetRunProfile.STORE_PATH), false) and all_passed
	return all_passed


## One streamed window, exactly as the generated code sends it: four fires of "aa" costing 500 usec
## each, over one frame. "zz" is counted by an older debug compile that streams fires without times,
## so it has a count and no cost - the case the readout must not dress up as zero.
static func _stream_run() -> void:
	EventSheetTraceHitCounts.note_fired(PackedStringArray(["aa", "aa", "aa", "aa"]))
	EventSheetTraceTimings.note_window(
		PackedStringArray(["aa", "aa", "aa", "aa"]),
		PackedInt64Array([0, 500, 1000, 1500]),
		PackedInt32Array([0]), 2000)
	EventSheetTraceHitCounts.note_fired(PackedStringArray(["zz"]))


## Charges one uid four fires of `usec_each`, counted AND timed, through the real window reader so
## the arithmetic under test is the arithmetic that runs.
static func _charge(uid: String, usec_each: int) -> void:
	var uids: PackedStringArray = _repeat(uid, 4)
	EventSheetTraceHitCounts.note_fired(uids)
	EventSheetTraceTimings.note_window(uids, _stamps(4, usec_each), PackedInt32Array([0]), 4 * usec_each)


static func _repeat(uid: String, times: int) -> PackedStringArray:
	var uids: PackedStringArray = PackedStringArray()
	for _index: int in range(times):
		uids.append(uid)
	return uids


static func _stamps(count: int, step: int) -> PackedInt64Array:
	var stamps: PackedInt64Array = PackedInt64Array()
	for index: int in range(count):
		stamps.append(index * step)
	return stamps


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] run_profile_overlay_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
