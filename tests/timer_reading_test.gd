# EventForge - R9. A Timer NODE reads as the sheet's Timer behavior: `$Timer.start(2.0)` is
# `Start timer "Timer" for 2 seconds (once)`, `stop()` is `Stop timer "Timer"`, `is_stopped()` asks the
# behavior's own question, and `time_left` is its clock expression. The node's name is the tag and the
# object is the script's OWN object, because the timer belongs to it. A receiver that cannot prove a tag
# (a timer held in a variable) keeps its call reading rather than borrowing one. Display only - the file
# keeps its lines, so this pins the WORDS and the refusals.
@tool
class_name TimerReadingTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	var context: Dictionary = {
		"script_object": "Player", "self_object": "Player", "timer_modes": {"Timer": true, "Loop": false}
	}

	# ── The two verbs ──
	ok = _check("start with seconds", _statement("$Timer.start(2.0)", context),
		"Player ▸ Start timer \"Timer\" for 2 seconds (once)") and ok
	ok = _check("start with no seconds", _statement("%SpawnTimer.start()", context),
		"Player ▸ Start timer \"SpawnTimer\"") and ok
	ok = _check("a regular timer says so", _statement("$Loop.start(0.5)", context),
		"Player ▸ Start timer \"Loop\" for 0.5 seconds (regular)") and ok
	ok = _check("stop", _statement("$Timer.stop()", context), "Player ▸ Stop timer \"Timer\"") and ok

	# ── The question, worded the way a reader thinks about a timer ──
	ok = _check("the negated spelling reads positively", _condition("not $Timer.is_stopped()", context),
		"Player ▸ Is timer \"Timer\" running") and ok
	ok = _check("the bare spelling says stopped", _condition("$Timer.is_stopped()", context),
		"Player ▸ Is timer \"Timer\" stopped") and ok

	# ── The clock ──
	ok = _check("time_left is the behavior's expression",
		EventSheetSentence.expression_text("$Timer.time_left", context), "Timer.CurrentTime(\"Timer\")") and ok

	# ── Refusals: a receiver with no provable tag keeps its own reading ──
	ok = _check("a timer held in a variable is not given a tag",
		EventSheetSentence.timer_tag("spawn_timer"), "") and ok
	ok = _check("time_left on a variable is not rewritten",
		EventSheetSentence.timer_expression("spawn_timer.time_left"), "") and ok

	# ── The mode map is read off the file's own lines, and only from literal shapes ──
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(
		"extends Node\n\nfunc _ready() -> void:\n\t$Timer.one_shot = true\n\t$Loop.one_shot = false\n\t$Maybe.one_shot = wants_once\n")
	var modes: Dictionary = EventSheetViewportReadingRows.timer_mode_map(sheet)
	ok = _check("a literal true is once", modes.get("Timer", null), true) and ok
	ok = _check("a literal false is regular", modes.get("Loop", null), false) and ok
	ok = _check("a computed mode is not claimed", modes.has("Maybe"), false) and ok

	# ── The LIFTED row says the same thing the typed line says ──
	# The importer claims `$Timer.start(2.0)` as the shipped Start Timer action, so the row is routed
	# back through this sentence rather than through the descriptor's own format.
	ok = _check("a lifted Start Timer stands for the typed line",
		ViewportRowBuilder.timer_ace_code("StartTimer", {"target": "$Timer", "time": "2.0"}),
		"$Timer.start(2.0)") and ok
	ok = _check("a lifted Start Timer reads the timer sentence",
		_statement(ViewportRowBuilder.timer_ace_code("StartTimer", {"target": "$Timer", "time": "2.0"}), context),
		"Player ▸ Start timer \"Timer\" for 2 seconds (once)") and ok
	ok = _check("the descriptor's -1 is the no-seconds sentence",
		_statement(ViewportRowBuilder.timer_ace_code("StartTimer", {"target": "%SpawnTimer", "time": "-1"}), context),
		"Player ▸ Start timer \"SpawnTimer\"") and ok
	ok = _check("a lifted Stop Timer reads the timer sentence",
		_statement(ViewportRowBuilder.timer_ace_code("StopTimer", {"target": "$Timer"}), context),
		"Player ▸ Stop timer \"Timer\"") and ok
	ok = _check("a row acting on the host itself claims no tag",
		ViewportRowBuilder.timer_ace_code("StartTimer", {"time": "2.0"}), "") and ok
	return ok


static func _statement(code: String, context: Dictionary) -> String:
	return _read(EventSheetSentence.statement(code, context))


static func _condition(code: String, context: Dictionary) -> String:
	return _read(EventSheetSentence.condition(code, context))


static func _read(result: Dictionary) -> String:
	if result.is_empty():
		return "<none>"
	var out: String = "%s ▸ " % str(result.get("object", ""))
	for segment: Variant in result.get("segments", []):
		out += str((segment as Dictionary).get("text", ""))
	return out


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] timer_reading_test: %s" % label)
		return true
	print("[FAIL] timer_reading_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
