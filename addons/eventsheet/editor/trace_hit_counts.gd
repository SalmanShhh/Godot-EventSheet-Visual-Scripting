# Godot EventSheets - Event Trace hit counts (the debugger LENS, never a layer)
#
# The Event Trace already streams which event uids fired: the generated code appends one entry
# per fire to `__eventsheets_fired` and flushes the whole buffer every 0.25s, so the payload
# carries REPEATS - it is a tally, not a set. The editor used to dedupe it into a highlight and
# throw the numbers away. This store keeps them: uid -> times fired since the run started.
#
# Nothing here is on by default and nothing here is program text. The counts are only ever drawn
# when View > Row Hit Counts is ticked (it ships unticked), or read one at a time through the
# gutter's hover tooltip. With the toggle off, a sheet is pixel-identical to a sheet compiled
# without the trace, which is the whole point: a beginner is never asked to ignore something.
#
# Statics, deliberately: the counts belong to the RUN, not to a tab, a pane or a window, so every
# view of every sheet reads the same tally and a closed dock does not lose it.
@tool
class_name EventSheetTraceHitCounts
extends RefCounted

## event uid -> times fired since the last reset.
static var _counts: Dictionary = {}
## True once a traced run has streamed at least one window (even an EMPTY one - an empty window
## still proves the game is running, which is exactly what makes "x0, never fired" trustworthy).
static var _has_run: bool = false
## The largest count in the current run, kept incrementally so the heat test is O(1) per row in
## the draw loop (a max() over the whole dictionary per row is the lookup the draw rule forbids).
static var _max_count: int = 0

## A row is HOT when it carries at least this share of the busiest row's count. Half is the
## honest line: a per-frame row and a once-per-second row differ by orders of magnitude, so
## anything near the top of the run really is the hot path.
const HOT_SHARE := 0.5
## …and never below this, so a run where the busiest row fired twice paints nothing warm.
const HOT_MINIMUM := 5


## One streamed window -> the tally. Duplicates in `uids` are real fires, so they all count.
static func note_fired(uids: PackedStringArray) -> void:
	_has_run = true
	for uid: String in uids:
		if uid.is_empty():
			continue
		var next_count: int = int(_counts.get(uid, 0)) + 1
		_counts[uid] = next_count
		if next_count > _max_count:
			_max_count = next_count


## Forgets the run (a new debug session, or Tools > Reset Hit Counts). After this the gutter
## shows nothing at all until a window arrives - an unknown count is never drawn as zero.
static func reset() -> void:
	_counts.clear()
	_has_run = false
	_max_count = 0


## True while there is a run to report on. Every readout is gated on this: with no run, the
## gutter and the tooltip stay silent rather than guessing.
static func has_run() -> bool:
	return _has_run


static func count_for(uid: String) -> int:
	return int(_counts.get(uid, 0))


static func max_count() -> int:
	return _max_count


## The busiest rows of the run. Not "fired a lot" in the absolute - hot is relative to whatever
## this run's busiest row did, so the tint means the same thing in a menu sheet and a bullet-hell.
static func is_hot(uid: String) -> bool:
	var count: int = count_for(uid)
	return count >= HOT_MINIMUM and count >= int(ceil(float(_max_count) * HOT_SHARE))


## The gutter chip's text. The gutter is 20px wide, so the chip is a GLANCE, not a readout:
## exact up to 999, then thousands, and the precise number is one hover away in the tooltip.
static func chip_text(count: int) -> String:
	if count < 0:
		return ""
	if count < 1000:
		return str(count)
	if count < 100000:
		return "%dk" % int(count / 1000.0)
	return "99k+"


## 1431 -> "1,431". The tooltip is where the exact number lives, and a five-digit run counter
## with no grouping is a number nobody reads at a glance.
static func format_count(count: int) -> String:
	var digits: String = str(absi(count))
	var grouped: String = ""
	var seen: int = 0
	for index: int in range(digits.length() - 1, -1, -1):
		grouped = digits[index] + grouped
		seen += 1
		if seen % 3 == 0 and index > 0:
			grouped = "," + grouped
	return ("-" if count < 0 else "") + grouped


## The hover answer for one event number: the whole feature, for a reader who turned nothing on.
## Empty when there is no run to report - the caller then leaves the hover to whatever it was.
static func tooltip_for(uid: String, event_number: int = 0) -> String:
	if not _has_run or uid.is_empty():
		return ""
	var lead: String = "Event %d: " % event_number if event_number > 0 else ""
	var count: int = count_for(uid)
	if count == 0:
		return lead + "never fired since Run."
	if count == 1:
		return lead + "fired once since Run."
	return lead + "fired %s times since Run%s." % [format_count(count), " - hot" if is_hot(uid) else ""]


## The run as text, newest tally first - the "Copy Trace Report" payload and what the test reads
## instead of a screenshot. One line per row that has a count, plus the never-fired roll call the
## caller passes in (uid -> event number), because the interesting rows are the missing ones.
static func as_text(event_numbers: Dictionary = {}) -> String:
	if not _has_run:
		return "No traced run yet. Tools > Event Trace (live highlight), then run the game."
	var ordered: Array = _counts.keys()
	ordered.sort_custom(func(left: Variant, right: Variant) -> bool:
		return int(_counts[left]) > int(_counts[right]))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Event trace - %d row(s) fired, busiest %s." % [_counts.size(), format_count(_max_count)])
	for uid: Variant in ordered:
		var number: int = int(event_numbers.get(uid, 0))
		lines.append("  %s x%s%s" % [
			("event %d" % number) if number > 0 else str(uid),
			format_count(int(_counts[uid])),
			" (hot)" if is_hot(str(uid)) else "",
		])
	for uid: Variant in event_numbers.keys():
		if not _counts.has(uid):
			lines.append("  event %d x0 (never fired)" % int(event_numbers[uid]))
	return "\n".join(lines)
