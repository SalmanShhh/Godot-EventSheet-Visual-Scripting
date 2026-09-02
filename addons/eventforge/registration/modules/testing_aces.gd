# EventForge module - Testing vocabulary (a sheet that makes claims and reports pass/fail).
#
# The verbs a Test sheet is written in: On Test Start (the trigger the runner raises), Assert That /
# Assert Equal (record a claim with a readable message), Expect Signal (a claim about something that
# has to happen within a deadline), Watch For Signal plus the two conditions that read what happened
# (succeeded / timed out - the deadline is never hidden in a trigger head), Pass Test / Fail Test,
# and Load Scene Under Test / Scene Under Test so a test has something to make claims about.
#
# WHERE THE RESULTS LIVE. Every record writes onto the test node's OWN metadata: the report is
# `set_meta(&"__ef_test_report", ...)`, an Array of [name, passed, message] triples, and a finished
# test sets `__ef_test_finished`. That is plain `Object.set_meta` - no runtime, no autoload, no
# plugin reference - so a compiled test script is ordinary GDScript that any runner (the headless
# tools/run_test_sheets.gd, the editor's Run Tests panel, a CI step, or a scene you press Play on)
# can read back by asking the node for its meta. A failing claim ALSO push_error()s, so a test
# played by hand still says what broke in the Output panel without any runner at all.
#
# The watch keys hex-encode the signal name exactly the way the shipped Wait family keys its waits,
# so "watch died" and "watch landed" never collide and the two reading conditions find their own.
@tool
class_name EventForgeTestingACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Testing"

## The meta key the report accumulates under. Read by tools/run_test_sheets.gd and the editor panel.
const REPORT_META := "__ef_test_report"
## Set by Pass Test / Fail Test: the runner stops waiting on a test that has said it is done.
const FINISHED_META := "__ef_test_finished"
## How many rows are SUSPENDED on a deadline right now (Expect Signal / Watch For Signal). A runner
## may not treat a test as finished while this is above zero: a row awaiting its signal records
## nothing for the whole wait, which otherwise reads exactly like a test with nothing left to say.
const PENDING_META := "__ef_test_pending"
## Prefix of the per-signal watch key ("waiting" 0 / "fired" 1 / "timed out" 2).
const WATCH_META_PREFIX := "__ef_watch_"
## Prefix of the per-name key a loaded scene-under-test is remembered under.
const SCENE_META_PREFIX := "__ef_scene_"
## The frame a replay counts from - the frame the first frame-addressed row ran on.
const REPLAY_FRAME_ZERO_META := "__ef_replay_frame0"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── The trigger the runner raises (backed by the sheet's own test_started signal) ──
	descriptors.append(F.trig("OnTestStart", "On Test Start", "test_started", CAT, "On test start ([b]test_name[/b])", "Runs when a test runner starts this test sheet. A Test sheet declares signal test_started(test_name: String) and the runner emits it, so the test's name arrives as a parameter you can use in messages.").featured())

	# ── Claims (each records one line of the report) ──
	descriptors.append(F.act("AssertThat", "Assert That", _assert_that_template(), CAT, "assert [b]{named}[/b]: [b]{claim}[/b]", "Records a pass when the check is true and a failure when it is not, under the name you give it. The failure message says what the check was, so the report can be read without opening the sheet.").param("named", "\"gravity pulls down\"", "Named", "What this check is called in the report - write it as the claim, so a failure reads like a sentence.", "expression").param("claim", "true", "Is True", "The check that has to be true. Anything that reads as a yes/no.", "expression").featured())
	descriptors.append(F.act("AssertEqual", "Assert Equal", _assert_equal_template(), CAT, "assert [b]{named}[/b]: [b]{actual}[/b] equals [b]{expected}[/b]", "Records a pass when the two values are equal. The failure message carries BOTH values (\"expected 3, got 2\") - the one fact a failing equality check always needs.").param("named", "\"score after one pickup\"", "Named", "What this check is called in the report.", "expression").param("actual", "0", "Got", "The value your game produced.", "expression").param("expected", "0", "Expected", "The value it should be.", "expression"))
	descriptors.append(F.act("ExpectSignal", "Expect Signal", _expect_signal_template(), CAT, "expect [b]{signal_name}[/b] on [b]{target}[/b] within [b]{seconds}[/b]s - [b]{named}[/b]", "Waits for a signal and records the verdict itself: a pass when it fires in time, a failure saying \"expected within 2.00s, never fired\" when it does not. Use Watch For Signal instead when the test should decide what each outcome means.").param("named", "\"death fires on zero hp\"", "Named", "What this check is called in the report.", "expression").param("signal_name", "\"tree_exited\"", "Signal", "The name of the signal that has to fire.", "expression").param("target", "self", "On", "The node that should emit it.", "expression").param("seconds", "2.0", "Within", "How long to give it, in seconds.", "expression"))

	# ── Verdicts a test states outright ──
	descriptors.append(F.act("PassTest", "Pass Test", _record_template("{named}", "true", "\"\"") + "\nset_meta(&\"%s\", true)" % FINISHED_META, CAT, "pass test [b]{named}[/b]", "Records a pass under this name and marks the test finished, so a runner stops waiting on it and moves to the next one.").param("named", "\"death fires on zero hp\"", "Named", "What passed, as it should read in the report.", "expression"))
	descriptors.append(F.act("FailTest", "Fail Test", _fail_test_template(), CAT, "fail test [b]{named}[/b] - [b]{reason}[/b]", "Records a failure with its reason and marks the test finished. The reason is what the report prints beside the name.").param("named", "\"death fires on zero hp\"", "Named", "What failed, as it should read in the report.", "expression").param("reason", "\"expected within 2.00s, never fired\"", "Because", "Why it failed, in plain words. A test that cannot say why it failed is the one thing a test may not be.", "expression"))

	# ── The watch and the two conditions that read it ──
	descriptors.append(F.act("WatchForSignal", "Watch For Signal", _watch_for_signal_template(), CAT, "watch for [b]{signal_name}[/b] on [b]{target}[/b] for [b]{seconds}[/b]s", "Waits until the signal fires or the time runs out, then records which happened. It states no verdict of its own: the next rows read it with Watch For Signal Succeeded / Watch For Signal Timed Out and decide what each outcome means.").param("signal_name", "\"tree_exited\"", "Signal", "The name of the signal to watch for.", "expression").param("target", "self", "On", "The node to watch.", "expression").param("seconds", "2.0", "For", "How long to watch, in seconds.", "expression"))
	descriptors.append(F.cond("WatchForSignalSucceeded", "Watch For Signal Succeeded", _watch_state_template("1"), CAT, "watch for [b]{signal_name}[/b] succeeded", "True when the matching Watch For Signal row saw its signal fire before the time ran out.").param("signal_name", "\"tree_exited\"", "Signal", "The signal name the Watch For Signal row used.", "expression"))
	descriptors.append(F.cond("WatchForSignalTimedOut", "Watch For Signal Timed Out", _watch_state_template("2"), CAT, "watch for [b]{signal_name}[/b] timed out", "True when the matching Watch For Signal row ran out of time without the signal firing - the outcome a test has to be able to name.").param("signal_name", "\"tree_exited\"", "Signal", "The signal name the Watch For Signal row used.", "expression"))

	# ── Something to make claims about ──
	descriptors.append(F.act("LoadSceneUnderTest", "Load Scene Under Test", _load_scene_template(), CAT, "load scene [b]{scene_path}[/b] as [b]{as_name}[/b]", "Instantiates a scene, adds it under the test node so it really runs, and remembers it under a short name. A missing scene is recorded as a failure rather than crashing the test.").param("scene_path", "\"res://scene.tscn\"", "Scene", "The scene this test exercises.", "scene_path").param("as_name", "\"P\"", "As", "A short name to address it by on later rows.", "expression").featured())
	descriptors.append(F.expr("SceneUnderTest", "Scene Under Test", _scene_under_test_template(), CAT, "scene [b]{as_name}[/b]", "The node a Load Scene Under Test row loaded under this name, so later rows can read its position, call its methods, or watch its signals.").param("as_name", "\"P\"", "Named", "The short name the Load Scene Under Test row gave it.", "expression"))

	# ── Frame-addressed rows: what a recorded play is written in ──
	# A replay is a list of "this happened at this frame", so the frame is part of the row rather
	# than a wait somebody has to remember to put in front of it. Frame 0 is the frame the FIRST of
	# these rows ran on, recorded on the test node itself, so a replay says the same thing no matter
	# how long the engine had been up when the runner reached it.
	descriptors.append(F.act("WaitUntilFrame", "Wait Until Frame", _wait_until_frame_template(), CAT, "wait until frame [b]{frame}[/b]", "Holds the test until the given frame of the run, so the rows after it happen at a time a recording can reproduce exactly.").param("frame", "60", "Frame", "Which frame of this test to wait for. Frame 0 is the first frame a frame-addressed row ran on.", "expression"))
	descriptors.append(F.act("SimulateControlPressedAtFrame", "Simulate Control Pressed At Frame", _at_frame_template("Input.action_press({action})"), CAT, "simulate control [b]{action}[/b] pressed at frame [b]{frame}[/b]", "Presses a control at a named frame of the run - one row of a recorded play.").param_built(F.make_param("action", "String", F.default_input_action(), "Control", "The control to press.", "input_action", F.input_action_options())).param("frame", "0", "At frame", "Which frame of this test to press it on.", "expression"))
	descriptors.append(F.act("SimulateControlReleasedAtFrame", "Simulate Control Released At Frame", _at_frame_template("Input.action_release({action})"), CAT, "simulate control [b]{action}[/b] released at frame [b]{frame}[/b]", "Lets a control go at a named frame of the run - one row of a recorded play.").param_built(F.make_param("action", "String", F.default_input_action(), "Control", "The control to let go.", "input_action", F.input_action_options())).param("frame", "0", "At frame", "Which frame of this test to let it go on.", "expression"))
	descriptors.append(F.act("ExpectAtFrame", "Expect At Frame", _expect_at_frame_template(), CAT, "expect [b]{actual}[/b] = [b]{expected}[/b] at frame [b]{frame}[/b]", "A checkpoint in a recorded play: waits for the frame, then records a pass or a failure that names the frame it drifted on.").param("named", "\"hp after the fall\"", "Named", "What this checkpoint is called in the report.", "expression").param("actual", "0", "Got", "The value to read at that frame.", "expression").param("expected", "0", "Expected", "The value it should be by then.", "expression").param("frame", "60", "At frame", "Which frame of this test to check on.", "expression"))

	return descriptors


## Picker blurb for the section header, so the group explains itself before a single row is dropped.
static func section_descriptions() -> Dictionary:
	return {
		CAT: "Claims a Test sheet makes and the verdicts it records. A test runner starts the sheet (On Test Start), the rows assert things, and the report - name, passed, message - is read back off the test node.",
	}


## The one line every record shares: append [name, passed, message] to the report meta. Written as a
## single expression (no temp var) so it can be dropped into any branch of a bigger template without
## dragging a declaration along, and so two records in one row can never collide on a variable name.
static func _record_template(name_expression: String, passed_expression: String, message_expression: String) -> String:
	return "set_meta(&\"%s\", (get_meta(&\"%s\", []) as Array) + [[str(%s), %s, str(%s)]])" % [
		REPORT_META, REPORT_META, name_expression, passed_expression, message_expression]


## Assert That. The claim is evaluated ONCE into a local - a claim is allowed to be a call with a
## cost (or a side effect), and evaluating it a second time for the push_error would be a different
## check than the one that was recorded.
static func _assert_that_template() -> String:
	return "\n".join(PackedStringArray([
		"var __assert_ok_{uid}: bool = bool({claim})",
		_record_template("{named}", "__assert_ok_{uid}", "\"\" if __assert_ok_{uid} else \"expected true, got false\""),
		"if not __assert_ok_{uid}:",
		"\tpush_error(\"[test] FAIL %s - expected true, got false\" % str({named}))",
	]))


static func _assert_equal_template() -> String:
	return "\n".join(PackedStringArray([
		"var __assert_got_{uid}: Variant = {actual}",
		"var __assert_want_{uid}: Variant = {expected}",
		"var __assert_ok_{uid}: bool = __assert_got_{uid} == __assert_want_{uid}",
		"var __assert_why_{uid}: String = \"\" if __assert_ok_{uid} else \"expected %s, got %s\" % [str(__assert_want_{uid}), str(__assert_got_{uid})]",
		_record_template("{named}", "__assert_ok_{uid}", "__assert_why_{uid}"),
		"if not __assert_ok_{uid}:",
		"\tpush_error(\"[test] FAIL %s - %s\" % [str({named}), __assert_why_{uid}])",
	]))


static func _fail_test_template() -> String:
	return "\n".join(PackedStringArray([
		_record_template("{named}", "false", "{reason}"),
		"set_meta(&\"%s\", true)" % FINISHED_META,
		"push_error(\"[test] FAIL %s - %s\" % [str({named}), str({reason})])",
	]))


## The shared signal wait. Godot connects a callable ONLY when its argument count matches the
## signal's, and a test may watch a signal of any shape, so the arity is read off the object's own
## signal list and the zero-argument callable is unbind()ed to match - the same trick the shipped
## Wait For All Of join uses. The poll loop (rather than a bare await) is what makes the deadline
## real: awaiting the signal alone would hang forever on the very failure a test exists to catch.
static func _watch_lines(prefix: String, result_lines: PackedStringArray) -> String:
	var lines: PackedStringArray = PackedStringArray([
		# Raised before the wait and lowered after it, in BOTH branches, so a runner can tell "this
		# test is still waiting" apart from "this test has stopped saying anything".
		"set_meta(&\"%s\", int(get_meta(&\"%s\", 0)) + 1)" % [PENDING_META, PENDING_META],
		"var %s_target_{uid}: Object = {target}" % prefix,
		"var %s_hit_{uid}: Array[bool] = [false]" % prefix,
		"if %s_target_{uid} != null and %s_target_{uid}.has_signal({signal_name}):" % [prefix, prefix],
		"\tvar %s_arity_{uid}: int = 0" % prefix,
		"\tfor %s_info_{uid}: Dictionary in %s_target_{uid}.get_signal_list():" % [prefix, prefix],
		"\t\tif str(%s_info_{uid}.get(\"name\", \"\")) == str({signal_name}):" % prefix,
		"\t\t\t%s_arity_{uid} = (%s_info_{uid}.get(\"args\", []) as Array).size()" % [prefix, prefix],
		"\tvar %s_cb_{uid}: Callable = func() -> void: %s_hit_{uid}[0] = true" % [prefix, prefix],
		"\tif %s_arity_{uid} > 0:" % prefix,
		"\t\t%s_cb_{uid} = %s_cb_{uid}.unbind(%s_arity_{uid})" % [prefix, prefix, prefix],
		"\t%s_target_{uid}.connect({signal_name}, %s_cb_{uid}, CONNECT_ONE_SHOT)" % [prefix, prefix],
		"\tvar %s_end_{uid}: int = Time.get_ticks_msec() + int(maxf(float({seconds}), 0.0) * 1000.0)" % prefix,
		"\twhile not %s_hit_{uid}[0] and Time.get_ticks_msec() < %s_end_{uid}:" % [prefix, prefix],
		"\t\tawait get_tree().process_frame",
		"\tif %s_target_{uid}.is_connected({signal_name}, %s_cb_{uid}):" % [prefix, prefix],
		"\t\t%s_target_{uid}.disconnect({signal_name}, %s_cb_{uid})" % [prefix, prefix],
		"else:",
		"\tpush_warning(\"[test] nothing here emits %s - the watch can only time out.\" % str({signal_name}))",
		"set_meta(&\"%s\", maxi(int(get_meta(&\"%s\", 0)) - 1, 0))" % [PENDING_META, PENDING_META],
	])
	lines.append_array(result_lines)
	return "\n".join(lines)


static func _watch_for_signal_template() -> String:
	return _watch_lines("__watch", PackedStringArray([
		"set_meta(&\"%s\" + str({signal_name}).to_utf8_buffer().hex_encode(), 1 if __watch_hit_{uid}[0] else 2)" % WATCH_META_PREFIX,
	]))


static func _watch_state_template(state: String) -> String:
	return "int(get_meta(&\"%s\" + str({signal_name}).to_utf8_buffer().hex_encode(), 0)) == %s" % [WATCH_META_PREFIX, state]


static func _expect_signal_template() -> String:
	return _watch_lines("__expect", PackedStringArray([
		"var __expect_why_{uid}: String = \"\" if __expect_hit_{uid}[0] else \"expected within %.2fs, never fired\" % maxf(float({seconds}), 0.0)",
		_record_template("{named}", "__expect_hit_{uid}[0]", "__expect_why_{uid}"),
		"if not __expect_hit_{uid}[0]:",
		"\tpush_error(\"[test] FAIL %s - %s\" % [str({named}), __expect_why_{uid}])",
	]))


## Load Scene Under Test. A missing scene is a RECORDED FAILURE, not a crash and not silence: the
## report names the path that resolved to nothing, which is the whole answer to "why did every later
## claim fail?". The instance is parented to the test node so it enters the tree and really runs.
static func _load_scene_template() -> String:
	return "\n".join(PackedStringArray([
		"var __under_{uid}: PackedScene = (load({scene_path}) as PackedScene) if ResourceLoader.exists({scene_path}) else null",
		"if __under_{uid} == null:",
		"\t" + _record_template("{as_name}", "false", "\"no scene at \" + str({scene_path})"),
		"\tpush_error(\"[test] FAIL %s - no scene at %s\" % [str({as_name}), str({scene_path})])",
		"else:",
		"\tvar __under_node_{uid}: Node = __under_{uid}.instantiate()",
		"\tadd_child(__under_node_{uid})",
		"\tset_meta(&\"%s\" + str({as_name}).to_utf8_buffer().hex_encode(), __under_node_{uid})" % SCENE_META_PREFIX,
	]))


## The frame clock a replay is addressed in. Frame 0 is auto-vivified by the FIRST frame-addressed
## row rather than by a setup row somebody could forget: a recording that lost its zero would replay
## against the engine's uptime, which is a different run every time.
static func _frame_clock_lines() -> PackedStringArray:
	return PackedStringArray([
		"if not has_meta(&\"%s\"):" % REPLAY_FRAME_ZERO_META,
		"\tset_meta(&\"%s\", Engine.get_frames_drawn())" % REPLAY_FRAME_ZERO_META,
		# Raised across the wait for the same reason the signal watches raise it: a row that is
		# waiting records nothing, which otherwise reads exactly like a test with nothing left to say.
		"set_meta(&\"%s\", int(get_meta(&\"%s\", 0)) + 1)" % [PENDING_META, PENDING_META],
		"while Engine.get_frames_drawn() - int(get_meta(&\"%s\", 0)) < int({frame}):" % REPLAY_FRAME_ZERO_META,
		"\tawait get_tree().process_frame",
		"set_meta(&\"%s\", maxi(int(get_meta(&\"%s\", 0)) - 1, 0))" % [PENDING_META, PENDING_META],
	])


static func _wait_until_frame_template() -> String:
	return "\n".join(_frame_clock_lines())


## One line of a replay: hold for the frame, then do the thing.
static func _at_frame_template(line: String) -> String:
	var lines: PackedStringArray = _frame_clock_lines()
	lines.append(line)
	return "\n".join(lines)


## A checkpoint: hold for the frame, then record the comparison with the FRAME in the failure
## message. "expected 90, got 74" is not enough to reproduce a drift; "at frame 300" is.
static func _expect_at_frame_template() -> String:
	var lines: PackedStringArray = _frame_clock_lines()
	lines.append_array(PackedStringArray([
		"var __at_got_{uid}: Variant = {actual}",
		"var __at_want_{uid}: Variant = {expected}",
		"var __at_ok_{uid}: bool = __at_got_{uid} == __at_want_{uid}",
		"var __at_why_{uid}: String = \"\" if __at_ok_{uid} else \"at frame %s expected %s, got %s\" % [str({frame}), str(__at_want_{uid}), str(__at_got_{uid})]",
		_record_template("{named}", "__at_ok_{uid}", "__at_why_{uid}"),
		"if not __at_ok_{uid}:",
		"\tpush_error(\"[test] FAIL %s - %s\" % [str({named}), __at_why_{uid}])",
	]))
	return "\n".join(lines)


static func _scene_under_test_template() -> String:
	return "(get_meta(&\"%s\" + str({as_name}).to_utf8_buffer().hex_encode(), null) as Node)" % SCENE_META_PREFIX
