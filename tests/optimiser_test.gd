# EventForge - the optimiser: the six findings, the two repairs, and the receipt afterwards.
#
# A tool that rewrites somebody's rows has to be provably careful, so this pins the careful parts:
#   1. WHAT IT FINDS - the six shapes, and, just as importantly, the sheets it says nothing about
#      (a menu sheet, a signal-driven sheet, a sheet whose path comes from a variable),
#   2. WHAT IT WOULD CHANGE - the before/after line pair the confirm dialog shows, because a diff
#      the reader approves has to be the diff that happens,
#   3. WHAT IT DOES - the two repairs applied to a real sheet through the real dock, and put back,
#   4. THE RECEIPT - the three things a fix can turn out to have been, measured, never guessed.
@tool
class_name OptimiserTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	EventSheetRunProfile.forget()
	EventSheetOptimiserReceipts.forget_all_for_test()
	all_passed = _run_findings() and all_passed
	all_passed = _run_silence() and all_passed
	all_passed = _run_diff() and all_passed
	all_passed = _run_repairs() and all_passed
	all_passed = _run_receipts() and all_passed
	EventSheetRunProfile.forget()
	EventSheetOptimiserReceipts.forget_all_for_test()
	if all_passed:
		print("[PASS] optimiser_test: the six findings, the silence, the diff, both repairs and the receipt")
	return all_passed


# ── 1. What it finds ──────────────────────────────────────────────────────────────────────
static func _run_findings() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = _sheet([
		_tick_row([_action("{target}.value = 1", {"target": "get_node(\"UI/Bar\")"})]),
		_tick_row([_action("for __each in get_tree().get_nodes_in_group(\"coins\"):\n\tpass", {})]),
		_tick_row([_action("__gap = global_position.distance_to(target.global_position)", {})]),
		_tick_row([_action("for __i in range(2400):\n\tpass", {})]),
		_tick_row([_action("add_child(load(\"res://bullet.tscn\").instantiate())", {})]),
		_tick_row([_action("queue_free()", {})]),
		_tick_row([_action("{target}.text = str(score)", {"target": "$HUD/Score"})]),
	])
	var kinds: PackedStringArray = _kinds(EventSheetPerformanceFindings.findings(sheet))
	all_passed = _check("every shape is found once, in the order the rules run", kinds,
		PackedStringArray([
			EventSheetPerformanceFindings.KIND_CONSTANT_LOOKUP,
			EventSheetPerformanceFindings.KIND_CONSTANT_LOOKUP,
			EventSheetPerformanceFindings.KIND_FULL_SCAN,
			EventSheetPerformanceFindings.KIND_DISTANCE_ROOT,
			EventSheetPerformanceFindings.KIND_HEAVY_LOOP,
			EventSheetPerformanceFindings.KIND_SPAWN_CHURN,
			EventSheetPerformanceFindings.KIND_SAME_TEXT,
		])) and all_passed

	var found: Array[Dictionary] = EventSheetPerformanceFindings.findings(sheet)
	all_passed = _check("only the lookups are batched as safe",
		_kinds(EventSheetPerformanceFindings.safe(found)),
		PackedStringArray([EventSheetPerformanceFindings.KIND_CONSTANT_LOOKUP,
			EventSheetPerformanceFindings.KIND_CONSTANT_LOOKUP])) and all_passed
	all_passed = _check("the lookup names the path it would remember",
		str((found[0] as Dictionary).get("subject", "")), "UI/Bar") and all_passed
	all_passed = _check("and which parameter holds it",
		str((found[0] as Dictionary).get("param", "")), "target") and all_passed
	all_passed = _check("the heavy loop counts the turns",
		str((found[4] as Dictionary).get("subject", "")), "2400") and all_passed
	all_passed = _check("a finding on a row nobody measured carries no number",
		float((found[0] as Dictionary).get("measured_ms", 0.0)), -1.0) and all_passed

	# The readers the rules are built on, pinned on their own so a regex change is a named failure.
	all_passed = _check("a quoted path is read out of the line",
		EventSheetPerformanceFindings.constant_path_in("get_node(\"UI/Bar\").value = 1"), "UI/Bar") and all_passed
	all_passed = _check("and the dollar spelling too",
		EventSheetPerformanceFindings.constant_path_in("$HUD/Score.text = \"\""), "HUD/Score") and all_passed
	all_passed = _check("a path worked out at runtime is not a constant",
		EventSheetPerformanceFindings.constant_path_in("get_node(bar_path).value = 1"), "") and all_passed
	all_passed = _check("a literal loop count is read",
		EventSheetPerformanceFindings.literal_loop_count("for __i in range(2400):"), 2400) and all_passed
	all_passed = _check("a computed one is not guessed at",
		EventSheetPerformanceFindings.literal_loop_count("for __i in range(tiles):"), 0) and all_passed
	all_passed = _check("the remembered name is the path, in the sheet's own spelling",
		EventSheetPerformanceFindings.remembered_name("UI/Bar"), "ui_bar") and all_passed
	all_passed = _check("a unique-name path loses its marker",
		EventSheetPerformanceFindings.remembered_name("%HealthBar"), "health_bar") and all_passed
	return all_passed


# ── 2. What it says nothing about ─────────────────────────────────────────────────────────
static func _run_silence() -> bool:
	var all_passed: bool = true
	# A signal-driven sheet does the same things, and none of them every frame.
	var by_signal: EventSheetResource = _sheet([
		_row("OnSignal", [_action("{target}.value = 1", {"target": "get_node(\"UI/Bar\")"})]),
		_row("OnSignal", [_action("{target}.text = str(score)", {"target": "$HUD/Score"})]),
	])
	all_passed = _check("a sheet that only reacts to things earns nothing",
		EventSheetPerformanceFindings.findings(by_signal).size(), 0) and all_passed
	all_passed = _check("and a sheet with no rows at all earns nothing",
		EventSheetPerformanceFindings.findings(_sheet([])).size(), 0) and all_passed
	all_passed = _check("nor does a null sheet answer anything",
		EventSheetPerformanceFindings.findings(null).size(), 0) and all_passed
	# One row making an instance is not churn: churn is one row making and another freeing.
	var makes_only: EventSheetResource = _sheet([
		_tick_row([_action("add_child(load(\"res://bullet.tscn\").instantiate())", {})]),
	])
	all_passed = _check("making something without freeing anything is not churn",
		_kinds(EventSheetPerformanceFindings.findings(makes_only)), PackedStringArray()) and all_passed
	return all_passed


# ── 3. What it would change ───────────────────────────────────────────────────────────────
static func _run_diff() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = _sheet([
		_tick_row([_action("{target}.value = 1", {"target": "get_node(\"UI/Bar\")"})]),
		_tick_row([_action("for __each in get_tree().get_nodes_in_group(\"coins\"):\n\tpass", {})]),
	])
	var found: Array[Dictionary] = EventSheetPerformanceFindings.findings(sheet)
	var hoist: PackedStringArray = EventSheetOptimiseDialog.diff_lines(found[0])
	all_passed = _check("the line the row compiles to now",
		hoist[0], "get_node(\"UI/Bar\").value = 1") and all_passed
	all_passed = _check("and the line it would compile to after", hoist[1], "ui_bar.value = 1") and all_passed
	var timing: PackedStringArray = EventSheetOptimiseDialog.diff_lines(found[1])
	all_passed = _check("the timing fix says what it changes about the frequency",
		timing[1], "__every_… >= maxf(0.2, 0.001)") and all_passed
	all_passed = _check("with no measurement the dialog says so rather than showing a zero",
		EventSheetOptimiseDialog.cost_words(found[0]),
		"No profiled run has measured this row, so there is no number beside it yet.") and all_passed
	return all_passed


# ── 4. The two repairs, on a real sheet through the real dock ─────────────────────────────
static func _run_repairs() -> bool:
	var all_passed: bool = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var sheet: EventSheetResource = _sheet([
		_tick_row([_action("{target}.value = 1", {"target": "get_node(\"UI/Bar\")"})]),
		_tick_row([_action("for __each in get_tree().get_nodes_in_group(\"coins\"):\n\tpass", {})]),
	])
	sheet.host_class = "Node2D"
	sheet.external_source_path = "user://__eventsheets_optimiser_probe.gd"
	dock.setup(sheet)
	var found: Array[Dictionary] = dock._optimiser.findings()
	all_passed = _check("the dock reads the same two findings", found.size(), 2) and all_passed

	# The safe one: a declaration appears, and the row points at it.
	all_passed = _check("the lookup is hoisted", dock._optimiser.apply(found[0]), true) and all_passed
	var declared: LocalVariable = dock._current_sheet.events[0] as LocalVariable
	all_passed = _check("the declaration leads the sheet", declared != null, true) and all_passed
	if declared != null:
		all_passed = _check("named for its path", declared.name, "ui_bar") and all_passed
		all_passed = _check("resolved once, at ready time", declared.onready, true) and all_passed
		all_passed = _check("untyped, because the node's class is the scene's business",
			declared.type_name, "Variant") and all_passed
		all_passed = _check("and it looks the node up itself",
			str(declared.default_value), "get_node(\"UI/Bar\")") and all_passed
	all_passed = _check("the row now reads the remembered name",
		_first_action_line(dock._current_sheet), "ui_bar.value = 1") and all_passed
	all_passed = _check("and the finding is gone",
		_kinds(dock._optimiser.findings()).has(EventSheetPerformanceFindings.KIND_CONSTANT_LOOKUP), false) and all_passed

	# Put it back: the parameter returns, the declaration stays (something else may read it by now).
	var hoisted_row: EventRow = _first_event(dock._current_sheet)
	all_passed = _check("the fix can be put back", dock._optimiser.put_back(hoisted_row), true) and all_passed
	all_passed = _check("the row points at the path again",
		_first_action_line(dock._current_sheet), "get_node(\"UI/Bar\").value = 1") and all_passed
	all_passed = _check("the declaration is left where it is",
		(dock._current_sheet.events[0] as LocalVariable) != null, true) and all_passed

	# The timing one: the event keeps its trigger and gains the condition.
	var scans: Array[Dictionary] = dock._optimiser.findings()
	var timing: Dictionary = {}
	for finding: Dictionary in scans:
		if str(finding.get("fix", "")) == EventSheetPerformanceFindings.FIX_EVERY_N:
			timing = finding
	all_passed = _check("the scan is asked less often", dock._optimiser.apply(timing), true) and all_passed
	var scanning_row: EventRow = timing.get("event") as EventRow
	all_passed = _check("through a condition the author could have added themselves",
		str((scanning_row.conditions[0] as ACECondition).ace_id), "EveryXSeconds") and all_passed
	all_passed = _check("with the interval in plain sight",
		str((scanning_row.conditions[0] as ACECondition).params.get("seconds", "")), "0.2") and all_passed
	all_passed = _check("applying it twice adds nothing",
		dock._optimiser.apply(timing), false) and all_passed
	all_passed = _check("and it can be put back too",
		dock._optimiser.put_back(scanning_row), true) and all_passed
	all_passed = _check("leaving the event as it was", scanning_row.conditions.size(), 0) and all_passed

	# The batch: only the safe ones, all in one step.
	all_passed = _check("the batch applies the safe fixes", dock._optimiser.apply_safe(), 1) and all_passed
	all_passed = _check("and leaves the timing one alone",
		_kinds(dock._optimiser.findings()).has(EventSheetPerformanceFindings.KIND_FULL_SCAN), true) and all_passed
	dock.free()
	return all_passed


# ── 5. The receipt ────────────────────────────────────────────────────────────────────────
static func _run_receipts() -> bool:
	var all_passed: bool = true
	EventSheetRunProfile.forget()
	EventSheetOptimiserReceipts.forget_all_for_test()
	var path: String = "res://__probe_sheet.gd"

	# A fix applied with a run already on the books.
	_stored_run("aa", 4, 2400)
	EventSheetOptimiserReceipts.note_fix(path, "aa", EventSheetPerformanceFindings.KIND_CONSTANT_LOOKUP)
	all_passed = _check("before the next run the receipt says only that it was fixed",
		EventSheetOptimiserReceipts.reading(path, "aa"),
		"Fixed - run the game with the profiler to see whether it helped.") and all_passed
	all_passed = _check("and offers no way back it cannot justify",
		EventSheetOptimiserReceipts.disappointed(path, "aa"), false) and all_passed

	# The next run, and it helped.
	_stored_run("aa", 4, 300)
	all_passed = _check("the receipt is the measurement",
		EventSheetOptimiserReceipts.reading(path, "aa"), "Fixed: 2.40 -> 0.30 ms a fire.") and all_passed
	all_passed = _check("nothing to put back when it worked",
		EventSheetOptimiserReceipts.disappointed(path, "aa"), false) and all_passed

	# And the honest case: it did not.
	EventSheetOptimiserReceipts.forget(path, "aa")
	_stored_run("bb", 4, 2400)
	EventSheetOptimiserReceipts.note_fix(path, "bb", EventSheetPerformanceFindings.KIND_FULL_SCAN)
	_stored_run("bb", 4, 2500)
	all_passed = _check("a fix that did not help says so",
		EventSheetOptimiserReceipts.reading(path, "bb"),
		"This did not help: still 2.50 ms a fire. Put it back?") and all_passed
	all_passed = _check("and offers the way back",
		EventSheetOptimiserReceipts.disappointed(path, "bb"), true) and all_passed
	all_passed = _check("a row with no receipt says nothing at all",
		EventSheetOptimiserReceipts.reading(path, "zz"), "") and all_passed
	EventSheetOptimiserReceipts.forget_all_for_test()
	EventSheetRunProfile.forget()
	return all_passed


## A completed run with one row in it, each call a DIFFERENT run - two real runs a second apart
## would carry the same stamp, and what a receipt compares is the identity, not the numbers.
static func _stored_run(uid: String, fires: int, usec_each: int) -> void:
	EventSheetRunProfile.adopt_run_for_test(uid, fires, fires, fires * usec_each,
		"run %d" % Time.get_ticks_usec())


# ── The fixtures ──────────────────────────────────────────────────────────────────────────
static func _sheet(rows: Array) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	for row: Variant in rows:
		sheet.events.append(row)
	return sheet


static func _tick_row(actions: Array) -> EventRow:
	return _row("OnProcess", actions)


static func _row(trigger_id: String, actions: Array) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_id = trigger_id
	for action: Variant in actions:
		row.actions.append(action)
	return row


static func _action(template: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "TestAction"
	action.codegen_template = template
	action.params = params
	return action


static func _kinds(found: Array[Dictionary]) -> PackedStringArray:
	var kinds: PackedStringArray = PackedStringArray()
	for finding: Dictionary in found:
		kinds.append(str(finding.get("kind", "")))
	return kinds


static func _first_event(sheet: EventSheetResource) -> EventRow:
	for entry: Variant in sheet.events:
		if entry is EventRow:
			return entry as EventRow
	return null


static func _first_action_line(sheet: EventSheetResource) -> String:
	var row: EventRow = _first_event(sheet)
	if row == null or row.actions.is_empty():
		return ""
	return EventSheetLightingFindings.compiled_line(row.actions[0] as Resource)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] optimiser_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
