# Godot EventSheets - the flow vocabulary: waits that end two ways, outcome triggers,
# the retry loop, the two rate limits, and once-per-thing.
#
# Every verb here is pinned at the EMITTED line and then RUN, because each one's whole value is a
# behaviour a beginner otherwise writes wrong: a wait with no deadline, a failure nobody hears, a
# loop that burns its whole count, a search box that refilters on every keystroke, a Trigger Once
# inside a For Each that fires for the first item only.
#
# What the harness can and cannot reach: `run_tests.gd` has no SceneTree, so nothing here may call
# the real `get_tree()`. Where a wait has to POLL, the host is built with `get_tree()` rewritten to a
# stand-in object that carries a `process_frame` signal (the same rewrite the pack tests use), and
# the test drives the frames itself. That is what lets the joins be proven the only way that counts:
# by firing the signals and watching the wait resolve, rather than by inspecting the connection it
# left behind.
#
# Every name-keyed family here hex-encodes its name into the metadata key, because Object.set_meta
# REFUSES a key that is not a valid identifier and stores nothing at all. Each family is therefore
# also exercised with a name containing a SPACE - the case that used to fail silently.
@tool
class_name FlowVocabularyTest
extends RefCounted


static func run() -> bool:
	var passed: bool = true
	passed = _test_wait_until_succeeds_and_reads_back() and passed
	passed = _test_wait_until_polls_until_the_check_comes_true() and passed
	passed = _test_wait_until_times_out_and_reports_failure() and passed
	passed = _test_wait_for_all_of_joins_every_signal() and passed
	passed = _test_wait_for_all_of_times_out_and_lets_go() and passed
	passed = _test_wait_for_any_of_names_its_winner() and passed
	passed = _test_outcome_actions_emit_the_signal_payload() and passed
	passed = _test_outcome_actions_are_droppable_without_the_signal() and passed
	passed = _test_on_failure_of_trigger_compiles_connects_and_fires() and passed
	passed = _test_on_success_of_trigger_compiles_connects_and_fires() and passed
	passed = _test_retry_loop_stops_early_and_reports_exhaustion() and passed
	passed = _test_wait_before_next_try_grows_the_gap() and passed
	passed = _test_at_most_every_throttles() and passed
	passed = _test_poke_and_has_been_quiet() and passed
	passed = _test_only_once_per_thing() and passed
	passed = _test_names_with_spaces_survive_the_metadata_key() and passed
	return passed


# ── 1. The waits ─────────────────────────────────────────────────────────────────────────
## A check that is already true never reaches the await: the wait ends at once and stamps 1, which
## Wait Succeeded reads as true and Wait Timed Out as false.
static func _test_wait_until_succeeds_and_reads_back() -> bool:
	var descriptor: ACEDescriptor = _descriptor("WaitUntil")
	if descriptor == null:
		return _check("Wait Until is registered", false, true)
	var ok: bool = _check("Wait Until polls once a frame",
		descriptor.codegen_template.contains("await get_tree().process_frame"), true)
	ok = _check("Wait Until stamps its verdict in name-keyed metadata, hex-encoded",
		descriptor.codegen_template.contains("set_meta(&\"__ef_wait_\" + str({wait_name}).to_utf8_buffer().hex_encode(), 1 if __wait_ok_{uid} else 2)"), true) and ok
	var node: Node = _host(_body("run", _bake(descriptor, {
		"uid": "w", "wait_name": "\"load\"", "check": "ready_flag", "seconds": "5.0"
	}), "var ready_flag: bool = true"))
	if node == null:
		return _check("the Wait Until action compiles on a Node", false, true) and ok
	node.call("run")
	ok = _check("a check that is already true ends the wait as succeeded",
		int(node.get_meta(_key("__ef_wait_", "load"), 0)), 1) and ok
	ok = _check("Wait Succeeded reads that verdict back", _condition_says(node, "WaitSucceeded", {"wait_name": "\"load\""}), true) and ok
	ok = _check("Wait Timed Out reads false for the same wait", _condition_says(node, "WaitTimedOut", {"wait_name": "\"load\""}), false) and ok
	ok = _check("a wait that never ran is neither succeeded", _condition_says(node, "WaitSucceeded", {"wait_name": "\"never\""}), false) and ok
	ok = _check("a wait that never ran is neither timed out", _condition_says(node, "WaitTimedOut", {"wait_name": "\"never\""}), false) and ok
	node.free()
	return ok


## The polling loop itself, driven frame by frame: the wait must keep re-testing the check rather
## than reading it once, and a give-up time of 0 must wait forever rather than time out at once.
static func _test_wait_until_polls_until_the_check_comes_true() -> bool:
	var descriptor: ACEDescriptor = _descriptor("WaitUntil")
	if descriptor == null:
		return _check("Wait Until is registered", false, true)
	var node: Node = _host_with_tree(_body("run", _bake(descriptor, {
		"uid": "w", "wait_name": "\"load\"", "check": "ready_flag", "seconds": "0.0"
	}), "var ready_flag: bool = false"))
	var tree: Node = _fake_tree()
	if node == null or tree == null:
		return _check("the polling harness compiles", false, true)
	node.set("fake_tree", tree)
	node.call("run")
	var ok: bool = _check("a check that is false suspends the wait instead of ending it",
		node.has_meta(_key("__ef_wait_", "load")), false)
	tree.emit_signal("process_frame")
	tree.emit_signal("process_frame")
	ok = _check("frames alone do not end it while the check is still false",
		node.has_meta(_key("__ef_wait_", "load")), false) and ok
	ok = _check("and a give-up time of 0 has not timed it out either",
		_condition_says(node, "WaitTimedOut", {"wait_name": "\"load\""}), false) and ok
	node.set("ready_flag", true)
	tree.emit_signal("process_frame")
	ok = _check("the frame after the check comes true ends the wait as succeeded",
		int(node.get_meta(_key("__ef_wait_", "load"), 0)), 1) and ok
	node.free()
	tree.free()
	return ok


## The blurb's promise: the wait ships WITH a deadline, and the timeout also reports the failure on
## verb_failed so an event that never saw the wait can still handle it.
static func _test_wait_until_times_out_and_reports_failure() -> bool:
	var descriptor: ACEDescriptor = _descriptor("WaitUntil")
	if descriptor == null:
		return _check("Wait Until is registered", false, true)
	var node: Node = _host(_body("run", _bake(descriptor, {
		"uid": "w", "wait_name": "\"load\"", "check": "false", "seconds": "0.0001"
	}), "signal verb_failed(verb_id: String, reason: String)"))
	if node == null:
		return _check("the Wait Until action compiles with a declared verb_failed", false, true)
	var heard: Array = []
	node.connect("verb_failed", func(verb_id: String, reason: String) -> void: heard.append([verb_id, reason]))
	node.call("run")
	var ok: bool = _check("a check that never comes true times the wait out",
		int(node.get_meta(_key("__ef_wait_", "load"), 0)), 2)
	ok = _check("Wait Timed Out reads that verdict back", _condition_says(node, "WaitTimedOut", {"wait_name": "\"load\""}), true) and ok
	ok = _check("the timeout also raises verb_failed exactly once", heard.size(), 1) and ok
	if heard.size() == 1:
		ok = _check("the failure names the wait", str((heard[0] as Array)[0]), "load") and ok
		ok = _check("the failure carries the timeout as its reason",
			str((heard[0] as Array)[1]).begins_with("timed out after"), true) and ok
	node.free()
	return ok


## The join's central promise, run rather than inspected: TWO signals, connected up front, and the
## wait resolves only once BOTH have fired - the bug a hand-written chain of awaits always has.
static func _test_wait_for_all_of_joins_every_signal() -> bool:
	var descriptor: ACEDescriptor = _descriptor("WaitForAllOf")
	if descriptor == null:
		return _check("Wait For All Of is registered", false, true)
	var ok: bool = _check("the join connects every signal one-shot up front",
		descriptor.codegen_template.contains("CONNECT_ONE_SHOT"), true)
	var node: Node = _host_with_tree(_body_taking("run", "door: Node, camera: Node", _bake(descriptor, {
		"uid": "j", "wait_name": "\"gate\"", "signals": "[Signal(door, &\"opened\"), Signal(camera, &\"arrived\")]", "seconds": "0.0"
	}), ""))
	var tree: Node = _fake_tree()
	var door: Node = _emitter("signal opened(who: Node, at: float)")
	var camera: Node = _emitter("signal arrived")
	if node == null or tree == null or door == null or camera == null:
		return _check("the join harness compiles", false, true) and ok
	node.set("fake_tree", tree)
	node.call("run", door, camera)
	ok = _check("the join subscribed to the first signal", door.get_signal_connection_list("opened").size(), 1) and ok
	ok = _check("the join subscribed to the second signal", camera.get_signal_connection_list("arrived").size(), 1) and ok
	var listener: Callable = (door.get_signal_connection_list("opened")[0] as Dictionary)["callable"]
	ok = _check("the listener unbinds that signal's own two arguments", listener.get_unbound_arguments_count(), 2) and ok
	door.emit_signal("opened", null, 1.0)
	tree.emit_signal("process_frame")
	ok = _check("one signal of two does not end the join",
		node.has_meta(_key("__ef_wait_", "gate")), false) and ok
	camera.emit_signal("arrived")
	tree.emit_signal("process_frame")
	ok = _check("the join succeeds once every signal has fired",
		int(node.get_meta(_key("__ef_wait_", "gate"), 0)), 1) and ok
	ok = _check("Wait Succeeded reads that verdict back",
		_condition_says(node, "WaitSucceeded", {"wait_name": "\"gate\""}), true) and ok
	node.free()
	tree.free()
	door.free()
	camera.free()
	return ok


## An empty join succeeds at once; a join that gives up reports the failure AND drops the listeners
## it was still holding, so a signal that fires minutes later cannot run a callback into a dead wait.
static func _test_wait_for_all_of_times_out_and_lets_go() -> bool:
	var descriptor: ACEDescriptor = _descriptor("WaitForAllOf")
	if descriptor == null:
		return _check("Wait For All Of is registered", false, true)
	var members: String = "signal verb_failed(verb_id: String, reason: String)\nsignal door_opened(who: Node, at: float)"
	var empty_line: String = _bake(descriptor, {"uid": "j", "wait_name": "\"none\"", "signals": "[]", "seconds": "8.0"})
	var join_line: String = _bake(descriptor, {"uid": "k", "wait_name": "\"gate\"", "signals": "[door_opened]", "seconds": "0.0001"})
	var node: Node = _host(_body("run_empty", empty_line, members) + _body("run_join", join_line, ""))
	if node == null:
		return _check("the Wait For All Of action compiles on a Node", false, true)
	node.call("run_empty")
	var ok: bool = _check("a join over nothing succeeds at once", int(node.get_meta(_key("__ef_wait_", "none"), 0)), 1)
	var heard: Array = []
	node.connect("verb_failed", func(verb_id: String, _reason: String) -> void: heard.append(verb_id))
	node.call("run_join")
	ok = _check("a join whose signal never fires times out", int(node.get_meta(_key("__ef_wait_", "gate"), 0)), 2) and ok
	ok = _check("the join's timeout raises verb_failed under the join's name", heard, ["gate"]) and ok
	ok = _check("and it disconnects the listener it was still holding",
		node.get_signal_connection_list("door_opened").size(), 0) and ok
	node.emit_signal("door_opened", null, 1.0)
	ok = _check("so the signal firing afterwards changes nothing",
		int(node.get_meta(_key("__ef_wait_", "gate"), 0)), 2) and ok
	node.free()
	return ok


## The race, run for real. Both racers carry a signal with the SAME name, which is the ordinary case
## ($Player.died against $Boss.died): only the owner tells the winner apart, so First To Finish
## answers "Node.signal" and the loser's connection is dropped when the race ends.
static func _test_wait_for_any_of_names_its_winner() -> bool:
	var descriptor: ACEDescriptor = _descriptor("WaitForAnyOf")
	if descriptor == null:
		return _check("Wait For Any Of is registered", false, true)
	var ok: bool = _check("the winner is captured with its owner, not by the signal name alone",
		descriptor.codegen_template.contains("(__owner_{uid} as Node).name + \".\" if __owner_{uid} is Node else \"\""), true)
	var node: Node = _host_with_tree(_body_taking("run", "player: Node, boss: Node", _bake(descriptor, {
		"uid": "a", "wait_name": "\"race\"", "signals": "[Signal(player, &\"died\"), Signal(boss, &\"died\")]", "seconds": "0.0"
	}), ""))
	var tree: Node = _fake_tree()
	var player: Node = _emitter("signal died(cause: String)")
	var boss: Node = _emitter("signal died(cause: String)")
	if node == null or tree == null or player == null or boss == null:
		return _check("the race harness compiles", false, true) and ok
	player.name = "Player"
	boss.name = "Boss"
	node.set("fake_tree", tree)
	node.call("run", player, boss)
	ok = _check("both racers are subscribed up front",
		[player.get_signal_connection_list("died").size(), boss.get_signal_connection_list("died").size()], [1, 1]) and ok
	boss.emit_signal("died", "crushed")
	tree.emit_signal("process_frame")
	ok = _check("the race ends as succeeded once one racer fires",
		int(node.get_meta(_key("__ef_wait_", "race"), 0)), 1) and ok
	ok = _check("First To Finish names the winner by its owner and signal",
		_expression_value(node, "FirstToFinish", {"wait_name": "\"race\""}), "Boss.died") and ok
	ok = _check("the loser's listener is dropped when the race ends",
		player.get_signal_connection_list("died").size(), 0) and ok
	player.emit_signal("died", "too late")
	ok = _check("so a losing signal firing afterwards cannot rewrite the winner",
		_expression_value(node, "FirstToFinish", {"wait_name": "\"race\""}), "Boss.died") and ok
	node.free()
	tree.free()
	player.free()
	boss.free()
	return _test_wait_for_any_of_times_out() and ok


## A race nobody wins reads back as empty text and reports the failure.
static func _test_wait_for_any_of_times_out() -> bool:
	var descriptor: ACEDescriptor = _descriptor("WaitForAnyOf")
	if descriptor == null:
		return _check("Wait For Any Of is registered", false, true)
	var node: Node = _host(_body("run", _bake(descriptor, {
		"uid": "a", "wait_name": "\"race\"", "signals": "[boss_died]", "seconds": "0.0001"
	}), "signal boss_died"))
	if node == null:
		return _check("the Wait For Any Of action compiles on a Node", false, true)
	node.call("run")
	var ok: bool = _check("a race nobody wins times out", int(node.get_meta(_key("__ef_wait_", "race"), 0)), 2)
	ok = _check("First To Finish reads empty text after a timeout",
		_expression_value(node, "FirstToFinish", {"wait_name": "\"race\""}), "") and ok
	ok = _check("and the race lets go of its racers when it gives up",
		node.get_signal_connection_list("boss_died").size(), 0) and ok
	node.free()
	return ok


# ── 2. The outcome triggers ──────────────────────────────────────────────────────────────
## Report Failure / Report Success put the verb and the reason on the SIGNAL, so the handler reads
## them as its own arguments rather than fetching a stored last-failure.
static func _test_outcome_actions_emit_the_signal_payload() -> bool:
	var failure: ACEDescriptor = _descriptor("ReportFailure")
	var success: ACEDescriptor = _descriptor("ReportSuccess")
	if failure == null or success == null:
		return _check("Report Failure and Report Success are registered", false, true)
	var ok: bool = _check("Report Failure emits the verb and the reason",
		failure.codegen_template.contains("emit_signal(&\"verb_failed\", str({verb}), str({reason}))"), true)
	ok = _check("Report Success emits the verb", success.codegen_template.contains("emit_signal(&\"verb_succeeded\", str({verb}))"), true) and ok
	var members: String = "signal verb_failed(verb_id: String, reason: String)\nsignal verb_succeeded(verb_id: String)"
	var node: Node = _host(
		_body("fail", _bake(failure, {"verb": "\"save_game\"", "reason": "\"disk write refused\""}), members)
		+ _body("win", _bake(success, {"verb": "\"save_game\""}), ""))
	if node == null:
		return _check("the outcome actions compile on a Node", false, true) and ok
	var failures: Array = []
	var successes: Array = []
	node.connect("verb_failed", func(verb_id: String, reason: String) -> void: failures.append([verb_id, reason]))
	node.connect("verb_succeeded", func(verb_id: String) -> void: successes.append(verb_id))
	node.call("fail")
	node.call("win")
	ok = _check("the failure arrives with its verb and reason as arguments", failures, [["save_game", "disk write refused"]]) and ok
	ok = _check("the success arrives with its verb as an argument", successes, ["save_game"]) and ok
	node.free()
	return ok


## The has_signal guard is what makes the row always droppable: on a sheet that has not declared the
## outcome signals the action is a plain no-op instead of a runtime error.
static func _test_outcome_actions_are_droppable_without_the_signal() -> bool:
	var failure: ACEDescriptor = _descriptor("ReportFailure")
	if failure == null:
		return _check("Report Failure is registered", false, true)
	var ok: bool = _check("the emit is guarded by has_signal",
		failure.codegen_template.begins_with("if has_signal(&\"verb_failed\"):"), true)
	var node: Node = _host(_body("fail", _bake(failure, {"verb": "\"save_game\"", "reason": "\"nope\""}), ""))
	if node == null:
		return _check("Report Failure compiles on a sheet with no verb_failed signal", false, true) and ok
	node.call("fail")
	ok = _check("calling it on such a sheet does nothing at all", node.has_signal("verb_failed"), false) and ok
	node.free()
	return ok


## The whole trigger, end to end: a sheet that declares verb_failed and heads an event with On
## Failure Of emits the handler, connects it in _ready, and runs it with the signal's payload.
static func _test_on_failure_of_trigger_compiles_connects_and_fires() -> bool:
	var descriptor: ACEDescriptor = _descriptor("signal:verb_failed")
	if descriptor == null:
		return _check("On Failure Of is registered", false, true)
	var ok: bool = _check("On Failure Of is a trigger", descriptor.ace_type, ACEDescriptor.ACEType.TRIGGER)
	ok = _check("On Failure Of names the verb_failed signal", descriptor.signal_name, "verb_failed") and ok
	ok = _check("its captured payload is the signal's two arguments",
		[descriptor.params[0].id, descriptor.params[1].id], ["verb_id", "reason"]) and ok
	var output: String = _compile(_outcome_sheet("verb_failed", ["verb_id: String", "reason: String"]), "user://flow_on_failure_of.gd")
	ok = _check("the handler carries the payload as its arguments",
		output.contains("func _on_verb_failed(verb_id: String, reason: String) -> void:"), true) and ok
	ok = _check("the sheet connects the signal in _ready",
		output.contains("\tverb_failed.connect(_on_verb_failed)"), true) and ok
	ok = _check("the sheet declares the signal it listens to",
		output.contains("signal verb_failed(verb_id: String, reason: String)"), true) and ok
	var node: Node = _instantiate(output)
	if node == null:
		return _check("the compiled On Failure Of sheet instantiates", false, true) and ok
	node.call("_ready")
	node.emit_signal("verb_failed", "save_game", "disk full")
	ok = _check("the trigger ran with the reason from the payload", str(node.get("last_reason")), "disk full") and ok
	ok = _check("the trigger ran with the verb from the payload", str(node.get("last_verb")), "save_game") and ok
	node.free()
	return ok


## Its twin, which had no test at all: On Success Of carries only the verb, and the same
## declare-connect-fire path has to hold or the row is a picker entry that produces a broken sheet.
static func _test_on_success_of_trigger_compiles_connects_and_fires() -> bool:
	var descriptor: ACEDescriptor = _descriptor("signal:verb_succeeded")
	if descriptor == null:
		return _check("On Success Of is registered", false, true)
	var ok: bool = _check("On Success Of is a trigger", descriptor.ace_type, ACEDescriptor.ACEType.TRIGGER)
	ok = _check("On Success Of names the verb_succeeded signal", descriptor.signal_name, "verb_succeeded") and ok
	ok = _check("its captured payload is the verb alone", descriptor.params.size(), 1) and ok
	ok = _check("and that argument is the verb id", descriptor.params[0].id, "verb_id") and ok
	var output: String = _compile(_outcome_sheet("verb_succeeded", ["verb_id: String"]), "user://flow_on_success_of.gd")
	ok = _check("the handler carries the verb as its argument",
		output.contains("func _on_verb_succeeded(verb_id: String) -> void:"), true) and ok
	ok = _check("the sheet connects the signal in _ready",
		output.contains("\tverb_succeeded.connect(_on_verb_succeeded)"), true) and ok
	var node: Node = _instantiate(output)
	if node == null:
		return _check("the compiled On Success Of sheet instantiates", false, true) and ok
	node.call("_ready")
	node.emit_signal("verb_succeeded", "save_game")
	ok = _check("the trigger ran with the verb from the payload", str(node.get("last_verb")), "save_game") and ok
	node.free()
	return ok


# ── 3. Retry ─────────────────────────────────────────────────────────────────────────────
## The loop is a real looping condition; Stop Retrying ends it the moment the attempt works and
## records that it did, so Retries Exhausted below is false - and true when every try was burnt.
## The record is three-state on purpose: a retry that has NEVER run is not exhausted either.
static func _test_retry_loop_stops_early_and_reports_exhaustion() -> bool:
	var loop: ACEDescriptor = _descriptor("RetryUpTo")
	var stop: ACEDescriptor = _descriptor("StopRetrying")
	var exhausted: ACEDescriptor = _descriptor("RetriesExhausted")
	var attempt_number: ACEDescriptor = _descriptor("RetryAttemptNumber")
	if loop == null or stop == null or exhausted == null or attempt_number == null:
		return _check("the retry family is registered", false, true)
	var ok: bool = _check("Retry Up To N Times is a looping condition", loop.is_looping, true)
	ok = _check("its items arrive as the attempt iterator", loop.looping_iterator, "attempt") and ok
	ok = _check("it opens a named, three-state retry record", loop.codegen_template,
		"__retry_begin_{uid}(str({retry_name}), int({times}))") and ok
	ok = _check("Retry Attempt Number reads the loop's own variable", attempt_number.codegen_template, "({loop_var} + 1)") and ok
	ok = _check("and that variable is a cell, so a renamed loop still reads",
		attempt_number.params[0].id, "loop_var") and ok
	ok = _check("Stop Retrying records the stop as state 2", stop.codegen_template,
		"set_meta(&\"__ef_retry_\" + str({retry_name}).to_utf8_buffer().hex_encode(), 2)\nbreak") and ok
	var source: String = loop.member_template.replace("{uid}", "r") + "\n\n" \
		+ exhausted.member_template.replace("{uid}", "r") + "\n\n\n"
	var stop_lines: String = _bake(stop, {"retry_name": "\"save\""})
	var body: PackedStringArray = PackedStringArray()
	body.append("func run(succeed_on: int) -> Array:")
	body.append("\tvar tries: int = 0")
	body.append("\tvar reported: int = 0")
	body.append("\tfor attempt: int in %s:" % _bake(loop, {"uid": "r", "retry_name": "\"save\"", "times": "4"}))
	body.append("\t\ttries += 1")
	body.append("\t\treported = %s" % _bake(attempt_number, {"loop_var": "attempt"}))
	body.append("\t\tif tries >= succeed_on:")
	for line: String in stop_lines.split("\n"):
		body.append("\t\t\t%s" % line)
	body.append("\treturn [tries, reported, %s]" % _bake(exhausted, {"uid": "r", "retry_name": "\"save\""}))
	body.append("")
	body.append("")
	body.append("func ask_exhausted() -> bool:")
	body.append("\treturn %s" % _bake(exhausted, {"uid": "r", "retry_name": "\"save\""}))
	var node: Node = _host(source + "\n".join(body) + "\n")
	if node == null:
		return _check("the retry loop compiles on a Node", false, true) and ok
	ok = _check("a retry that has never run is not exhausted", bool(node.call("ask_exhausted")), false) and ok
	var early: Array = node.call("run", 2)
	ok = _check("the loop stops on the try that worked", early[0], 2) and ok
	ok = _check("Retry Attempt Number reported that try as the second", early[1], 2) and ok
	ok = _check("a retry that worked is not exhausted", early[2], false) and ok
	var gave_up: Array = node.call("run", 99)
	ok = _check("a retry that never works burns every try", gave_up[0], 4) and ok
	ok = _check("Retries Exhausted is true when no try worked", gave_up[2], true) and ok
	var again: Array = node.call("run", 1)
	ok = _check("reading exhaustion cleared the record, so the next run answers for itself", again[2], false) and ok
	ok = _check("and asking again after a successful run stays false", bool(node.call("ask_exhausted")), false) and ok
	node.free()
	return ok


## The backoff the blurb promises: the same wait every time at growth 1, doubling at growth 2.
static func _test_wait_before_next_try_grows_the_gap() -> bool:
	var descriptor: ACEDescriptor = _descriptor("WaitBeforeNextTry")
	if descriptor == null:
		return _check("Wait Before Next Try is registered", false, true)
	var ok: bool = _check("it suspends the event like Wait does",
		descriptor.codegen_template.begins_with("await get_tree().create_timer("), true)
	# The timer cannot run without a tree, so the DURATION it is handed is lifted out of the shipped
	# template and evaluated directly - the same expression, one call earlier.
	var duration: String = descriptor.codegen_template \
		.trim_prefix("await get_tree().create_timer(").trim_suffix(").timeout")
	var node: Node = _host("func gap(delay: float, growth: float, attempt: int) -> float:\n\treturn %s\n" \
		% duration.replace("{delay}", "delay").replace("{growth}", "growth").replace("{attempt}", "attempt"))
	if node == null:
		return _check("the backoff expression compiles on a Node", false, true) and ok
	ok = _check("the first try waits the plain delay", float(node.call("gap", 0.5, 2.0, 1)), 0.5) and ok
	ok = _check("growth 2 doubles the wait on the third try", float(node.call("gap", 0.5, 2.0, 3)), 2.0) and ok
	ok = _check("growth 1 keeps every gap the same", float(node.call("gap", 0.5, 1.0, 4)), 0.5) and ok
	node.free()
	return ok


# ── 4. The two rate limits ───────────────────────────────────────────────────────────────
## The leading edge: the first run passes, an immediate second is refused, and the window reopens
## once it has elapsed. It is hoisted to the end of the `and` chain like Trigger Once.
static func _test_at_most_every_throttles() -> bool:
	var descriptor: ACEDescriptor = _descriptor("AtMostEvery")
	if descriptor == null:
		return _check("At Most Every is registered", false, true)
	var ok: bool = _check("the window is only consumed once the row's other conditions held",
		descriptor.evaluate_last, true)
	var node: Node = _host("%s\n\n\nfunc ask(window: float) -> bool:\n\treturn %s\n" % [
		descriptor.member_template.replace("{uid}", "t"),
		_bake(descriptor, {"uid": "t", "seconds": "window"})])
	if node == null:
		return _check("the throttle helper compiles on a Node", false, true) and ok
	ok = _check("the first run passes", bool(node.call("ask", 5.0)), true) and ok
	ok = _check("an immediate second run is refused", bool(node.call("ask", 5.0)), false) and ok
	# A window of zero has genuinely elapsed by the next call, so the reopening is exercised by
	# elapsing it rather than by writing the timestamp the helper keeps.
	ok = _check("a window that has genuinely elapsed reopens", bool(node.call("ask", 0.0)), true) and ok
	node.free()
	return ok


## The trailing edge: a name that was never poked is never quiet, a poked one is quiet only once the
## gap has passed, and Clear Poke stops it firing again.
static func _test_poke_and_has_been_quiet() -> bool:
	var poke: ACEDescriptor = _descriptor("Poke")
	var clear: ACEDescriptor = _descriptor("ClearPoke")
	var quiet: ACEDescriptor = _descriptor("HasBeenQuiet")
	if poke == null or clear == null or quiet == null:
		return _check("the debounce family is registered", false, true)
	var ok: bool = _check("Poke stamps name-keyed node metadata, hex-encoded",
		poke.codegen_template, "set_meta(&\"__ef_poke_\" + str({poke_name}).to_utf8_buffer().hex_encode(), Time.get_ticks_msec())")
	var node: Node = _host(
		_body("poke", _bake(poke, {"poke_name": "\"search\""}), "")
		+ _body("clear", _bake(clear, {"poke_name": "\"search\""}), ""))
	if node == null:
		return _check("the debounce actions compile on a Node", false, true) and ok
	ok = _check("a name that was never poked is never quiet",
		_condition_says(node, "HasBeenQuiet", {"poke_name": "\"search\"", "seconds": "0.0"}), false) and ok
	node.call("poke")
	ok = _check("the poke landed under the hex-encoded name",
		node.has_meta(_key("__ef_poke_", "search")), true) and ok
	ok = _check("a poked name is quiet once no gap is required",
		_condition_says(node, "HasBeenQuiet", {"poke_name": "\"search\"", "seconds": "0.0"}), true) and ok
	ok = _check("it is not quiet yet while the gap is still running",
		_condition_says(node, "HasBeenQuiet", {"poke_name": "\"search\"", "seconds": "30.0"}), false) and ok
	node.call("clear")
	ok = _check("Clear Poke stops it firing again",
		_condition_says(node, "HasBeenQuiet", {"poke_name": "\"search\"", "seconds": "0.0"}), false) and ok
	node.free()
	return ok


# ── 5. Once per thing ────────────────────────────────────────────────────────────────────
## The bug this removes: inside a For Each, Trigger Once fires for the first item and never for the
## rest. Only Once Per Node fires once for EACH node, and Forget Once For re-arms it.
static func _test_only_once_per_thing() -> bool:
	var per_node: ACEDescriptor = _descriptor("OnlyOncePerNode")
	var per_name: ACEDescriptor = _descriptor("OnlyOncePerName")
	var per_load: ACEDescriptor = _descriptor("OnlyOnceThisSceneLoad")
	var forget: ACEDescriptor = _descriptor("ForgetOnceFor")
	if per_node == null or per_name == null or per_load == null or forget == null:
		return _check("the once-per-thing family is registered", false, true)
	var node: Node = _once_host(per_node, per_name, per_load, forget)
	if node == null:
		return _check("the once-per-thing helpers compile on a Node", false, true)
	var first: Node = Node.new()
	var second: Node = Node.new()
	var ok: bool = _check("the first pass over a node is true", bool(node.call("per_node", first, "init")), true)
	ok = _check("the second pass over the same node is false", bool(node.call("per_node", first, "init")), false) and ok
	ok = _check("a different node still gets its own first pass", bool(node.call("per_node", second, "init")), true) and ok
	ok = _check("the memory lives on the node itself, under the hex-encoded name",
		first.has_meta(_key("__ef_once_", "init")), true) and ok
	node.call("forget", first, "init")
	ok = _check("Forget Once For re-arms that node", bool(node.call("per_node", first, "init")), true) and ok
	ok = _check("a null node is never the first time", bool(node.call("per_node", null, "init")), false) and ok
	ok = _check("the first pass for a name is true", bool(node.call("per_name", "sword")), true) and ok
	ok = _check("the second pass for that name is false", bool(node.call("per_name", "sword")), false) and ok
	ok = _check("another name still gets its own first pass", bool(node.call("per_name", "shield")), true) and ok
	ok = _check("the first pass this scene load is true", bool(node.call("per_load", "welcome")), true) and ok
	ok = _check("the second pass this scene load is false", bool(node.call("per_load", "welcome")), false) and ok
	first.free()
	second.free()
	node.free()
	return ok


## The regression that no gate could see: Object.set_meta REFUSES a key that is not a valid
## identifier, so before the names were hex-encoded a memory called "first hit" stored NOTHING and
## the once-guard answered true forever - firing every single frame instead of once. Every
## name-keyed family in this vocabulary is therefore re-run here with a name containing a space.
static func _test_names_with_spaces_survive_the_metadata_key() -> bool:
	var per_node: ACEDescriptor = _descriptor("OnlyOncePerNode")
	var per_name: ACEDescriptor = _descriptor("OnlyOncePerName")
	var per_load: ACEDescriptor = _descriptor("OnlyOnceThisSceneLoad")
	var forget: ACEDescriptor = _descriptor("ForgetOnceFor")
	var poke: ACEDescriptor = _descriptor("Poke")
	var wait: ACEDescriptor = _descriptor("WaitUntil")
	if per_node == null or per_name == null or per_load == null or forget == null or poke == null or wait == null:
		return _check("the name-keyed families are registered", false, true)

	var once_host: Node = _once_host(per_node, per_name, per_load, forget)
	if once_host == null:
		return _check("the once-per-thing helpers compile on a Node", false, true)
	var target: Node = Node.new()
	var ok: bool = _check("a memory named with a space is true the first time",
		bool(once_host.call("per_node", target, "first hit")), true)
	ok = _check("and FALSE the second time, which is the whole promise",
		bool(once_host.call("per_node", target, "first hit")), false) and ok
	ok = _check("the memory really landed on the node", target.has_meta(_key("__ef_once_", "first hit")), true) and ok
	once_host.call("forget", target, "first hit")
	ok = _check("Forget Once For clears a spaced name too", bool(once_host.call("per_node", target, "first hit")), true) and ok
	ok = _check("Only Once Per Name is true once for a spaced name", bool(once_host.call("per_name", "found gold")), true) and ok
	ok = _check("and false afterwards", bool(once_host.call("per_name", "found gold")), false) and ok
	target.free()
	once_host.free()

	var poke_host: Node = _host(_body("poke", _bake(poke, {"poke_name": "\"search box\""}), ""))
	if poke_host == null:
		return _check("the poke action compiles on a Node", false, true) and ok
	poke_host.call("poke")
	ok = _check("a poke named with a space is recorded",
		poke_host.has_meta(_key("__ef_poke_", "search box")), true) and ok
	ok = _check("and Has Been Quiet For can see it",
		_condition_says(poke_host, "HasBeenQuiet", {"poke_name": "\"search box\"", "seconds": "0.0"}), true) and ok
	poke_host.free()

	var wait_host: Node = _host(_body("run", _bake(wait, {
		"uid": "w", "wait_name": "\"boss intro\"", "check": "false", "seconds": "0.0001"
	}), ""))
	if wait_host == null:
		return _check("the Wait Until action compiles on a Node", false, true) and ok
	wait_host.call("run")
	ok = _check("a wait named with a space records its timeout",
		int(wait_host.get_meta(_key("__ef_wait_", "boss intro"), 0)), 2) and ok
	ok = _check("so Wait Timed Out can run the recovery branch",
		_condition_says(wait_host, "WaitTimedOut", {"wait_name": "\"boss intro\""}), true) and ok
	wait_host.free()
	return ok


# ── Helpers ──────────────────────────────────────────────────────────────────────────────
## A host carrying all four once-per-thing helpers, with the memory name as a parameter so the same
## harness serves both the ordinary names and the ones with spaces in them.
static func _once_host(per_node: ACEDescriptor, per_name: ACEDescriptor, per_load: ACEDescriptor, forget: ACEDescriptor) -> Node:
	var members: PackedStringArray = PackedStringArray()
	members.append(per_node.member_template.replace("{uid}", "n"))
	members.append(per_name.member_template.replace("{uid}", "m"))
	members.append(per_load.member_template.replace("{uid}", "s"))
	var source: String = "\n\n".join(members) + "\n\n\n"
	source += "func per_node(who: Node, label: String) -> bool:\n\treturn %s\n\n\n" % _bake(per_node, {"uid": "n", "node": "who", "label": "label"})
	source += "func per_name(key: String) -> bool:\n\treturn %s\n\n\n" % _bake(per_name, {"uid": "m", "key": "key"})
	source += "func per_load(key: String) -> bool:\n\treturn %s\n\n\n" % _bake(per_load, {"uid": "s", "key": "key"})
	var forget_lines: String = _bake(forget, {"node": "who", "label": "label"})
	source += "func forget(who: Node, label: String) -> void:\n"
	for line: String in forget_lines.split("\n"):
		source += "\t%s\n" % line
	return _host(source)


## `<Node> / signal <name> / On <outcome> Of: remember the payload`.
static func _outcome_sheet(signal_name: String, params: Array) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var declaration: SignalRow = SignalRow.new()
	declaration.signal_name = signal_name
	declaration.params = PackedStringArray(params)
	sheet.events.append(declaration)
	sheet.events.append(_variable("last_verb", "String", ""))
	sheet.events.append(_variable("last_reason", "String", ""))
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "signal:%s" % signal_name
	row.trigger_args = ", ".join(PackedStringArray(params))
	row.actions.append(_raw_action("last_verb = verb_id"))
	if params.size() > 1:
		row.actions.append(_raw_action("last_reason = reason"))
	sheet.events.append(row)
	return sheet


static func _variable(variable_name: String, type_name: String, default_value: Variant) -> LocalVariable:
	var variable: LocalVariable = LocalVariable.new()
	variable.name = variable_name
	variable.type_name = type_name
	variable.default_value = default_value
	return variable


static func _raw_action(statement: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "RawCode"
	action.codegen_template = statement
	return action


static func _descriptor(ace_id: String) -> ACEDescriptor:
	return ACERegistry.find_descriptor("Core", ace_id)


## The metadata key a name-keyed family really writes: the prefix plus the name's bytes as hex,
## because Object.set_meta refuses anything that is not a valid identifier.
static func _key(prefix: String, name: String) -> StringName:
	return StringName(prefix + name.to_utf8_buffer().hex_encode())


## Substitutes a descriptor's template exactly as the dock's apply step does.
static func _bake(descriptor: ACEDescriptor, values: Dictionary) -> String:
	var output: String = descriptor.codegen_template
	for key: Variant in values.keys():
		output = output.replace("{%s}" % str(key), str(values[key]))
	return output


## A function whose body is one (possibly multi-line) emitted statement, plus optional class members.
static func _body(function_name: String, statement: String, members: String) -> String:
	return _body_taking(function_name, "", statement, members)


## The same, for a function that takes arguments the emitted statement refers to.
static func _body_taking(function_name: String, arguments: String, statement: String, members: String) -> String:
	var source: String = ""
	if not members.is_empty():
		source += members + "\n\n\n"
	source += "func %s(%s) -> void:\n" % [function_name, arguments]
	for line: String in statement.split("\n"):
		source += "\t%s\n" % line
	return source + "\n\n"


## Evaluates a CONDITION descriptor's shipped template against a live node.
static func _condition_says(node: Node, ace_id: String, values: Dictionary) -> bool:
	var probe: Node = _host("func ask(host: Node) -> bool:\n\treturn %s\n" \
		% _bake(_descriptor(ace_id), values).replace("get_meta(", "host.get_meta("))
	if probe == null:
		return false
	var answer: bool = bool(probe.call("ask", node))
	probe.free()
	return answer


## Evaluates an EXPRESSION descriptor's shipped template against a live node.
static func _expression_value(node: Node, ace_id: String, values: Dictionary) -> Variant:
	var probe: Node = _host("func read(host: Node) -> Variant:\n\treturn %s\n" \
		% _bake(_descriptor(ace_id), values).replace("get_meta(", "host.get_meta("))
	if probe == null:
		return null
	var answer: Variant = probe.call("read", node)
	probe.free()
	return answer


static func _compile(sheet: EventSheetResource, path: String) -> String:
	return str(SheetCompiler.compile(sheet, path).get("output", ""))


static func _host(source: String) -> Node:
	return _instantiate("extends Node\n\n\n" + source)


## A host whose get_tree() is a stand-in carrying a process_frame signal, so a polling wait really
## runs its loop. The rewrite is textual, exactly the way the pack tests reach the same seam.
static func _host_with_tree(source: String) -> Node:
	var text: String = ("extends Node\n\n\n" + source).replace("get_tree()", "_tree()")
	text += "\n\nvar fake_tree: Object = null\n\n\nfunc _tree() -> Object:\n\treturn fake_tree\n"
	return _instantiate(text)


static func _fake_tree() -> Node:
	return _instantiate("extends Node\n\nsignal process_frame\n")


## A bare node carrying one declared signal, so a wait can be raced against a real emission.
static func _emitter(declaration: String) -> Node:
	return _instantiate("extends Node\n\n%s\n" % declaration)


static func _instantiate(source: String) -> Node:
	var script: GDScript = GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		print("  compiled source failed to reload:\n%s" % source)
		return null
	var node: Node = Node.new()
	node.set_script(script)
	return node


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] flow_vocabulary_test: %s" % label)
		return true
	print("[FAIL] flow_vocabulary_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
