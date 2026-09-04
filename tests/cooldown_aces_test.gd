# Godot EventSheets - the named clocks: cooldowns, countdowns and stopwatches.
#
# WHAT THIS TEST CAN SEE, and what it cannot. run_tests.gd works inside SceneTree._init, where
# Engine.get_main_loop() is still null, so there is no live tree and nothing here waits for a real
# second to pass. What it does instead is the honest version of the same question: it builds a
# SceneTree of its own purely as a factory for real SceneTreeTimers, hands the emitted lines a
# stand-in tree that records what each row asked for, and then STEPS EACH TIMER BY HAND by writing
# its time_left. Every number below is therefore pinned as a value at a moment the test chose - the
# instant a cooldown is started, half way through it, at exactly zero - rather than sampled from a
# clock that may or may not have advanced.
#
# THE THREE THINGS IT ASKS:
#   1. WHAT THE ROWS ARE. Every shipped descriptor of this module, pinned as one text: id, kind,
#      name, category and fields. A row renamed, retyped or given a new field moves that text.
#      Beside it, the three FROZEN cooldown rows in system_aces are pinned unchanged, because this
#      module stands beside them rather than replacing them.
#   2. WHAT THE LINES DO. The emitted template of every non-trigger row is compiled into a throwaway
#      host and RUN: started, stepped, reduced, cleared, paused, resumed, lapped. The clock choice is
#      read off the arguments the row really passed to create_timer, which is the only place the
#      difference between game time and realtime lives.
#   3. WHAT COMES BACK. A hand-written line of each kind is opened as a sheet: the two conditions read
#      back as their own rows, the multi-statement actions stay honest verbatim blocks, and every one
#      of those files re-emits byte for byte.
@tool
class_name CooldownACEsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const MODULE := preload("res://addons/eventforge/registration/modules/cooldown_aces.gd")

const P := "cooldown_aces_test"

## The argument names the harness binds each row parameter to when it turns a template into a
## method. `name` is deliberately not one of them: a host that is a RefCounted has no `name`, and a
## reader of the generated harness should never have to wonder whether it does.
const ARGUMENTS: Dictionary = {
	"name": "label", "seconds": "seconds", "clock": "clock", "at_second": "at_second"
}

## The span Start Stopwatch counts down from, so the test says the same day the module does rather
## than a number copied out of it.
const DAY: float = 86400.0


## A SceneTree that is only ever a factory. It is never run, never given a scene and never stepped -
## it exists because SceneTreeTimer cannot be constructed any other way, and every timer it hands
## out is stepped by this test writing time_left rather than by any clock.
class TreeSpy:
	extends RefCounted

	var inner: SceneTree = null
	var calls: Array = []

	func _init() -> void:
		inner = SceneTree.new()

	## The call the emitted rows make. Both booleans are recorded because they ARE the clock choice:
	## game time is false and false, realtime is true and true.
	func create_timer(seconds: float, process_always: bool, process_in_physics: bool,
			ignore_time_scale: bool) -> SceneTreeTimer:
		calls.append([snappedf(seconds, 0.0001), process_always, process_in_physics, ignore_time_scale])
		return inner.create_timer(seconds, process_always, process_in_physics, ignore_time_scale)

	func release() -> void:
		calls.clear()
		if inner != null:
			inner.free()
			inner = null


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _the_words() and all_passed
	all_passed = _the_frozen_rows_beside_them() and all_passed
	all_passed = _cooldowns_run() and all_passed
	all_passed = _the_clock_choice() and all_passed
	all_passed = _countdowns_run() and all_passed
	all_passed = _stopwatches_run() and all_passed
	all_passed = _the_ready_signal() and all_passed
	all_passed = _what_comes_back() and all_passed
	return all_passed


## THE ROWS THEMSELVES. One text for the whole module, so a row that is renamed, retyped, refiled or
## given another field is a difference a reader can see in one line rather than a count that moved.
static func _the_words() -> bool:
	var written: PackedStringArray = PackedStringArray()
	for descriptor: ACEDescriptor in MODULE.get_descriptors():
		var fields: PackedStringArray = PackedStringArray()
		for parameter: ACEParam in descriptor.params:
			fields.append(str(parameter.id))
		written.append("%s|%s|%s|%s|%s" % [descriptor.ace_id, _kind_of(descriptor),
			descriptor.display_name, descriptor.category, ",".join(fields)])
	written.sort()
	return SUPPORT.pin_value(P, "the module's rows, as one text", "\n".join(written), "\n".join(PackedStringArray([
		"ClearCooldown|action|Clear Cooldown|Time|name",
		"CooldownFraction|expression|Cooldown Fraction|Time|name",
		"CooldownSecondsLeft|expression|Cooldown Seconds Left|Time|name",
		"CountdownIsRunning|condition|Countdown Is Running|Time|name",
		"CountdownSecondsLeft|expression|Countdown Seconds Left|Time|name",
		"CountdownText|expression|Countdown Text|Time|name",
		"IsOffCooldown|condition|Is Off Cooldown|Time|name",
		"LapSeconds|expression|Lap Seconds|Time|name",
		"LapText|expression|Lap Text|Time|name",
		"PauseCountdown|action|Pause Countdown|Time|name",
		"PutOnCooldown|action|Put On Cooldown|Time|name,seconds,clock",
		"RecordLap|action|Record Lap|Time|name",
		"ReduceCooldownBy|action|Reduce Cooldown By|Time|name,seconds",
		"ResumeCountdown|action|Resume Countdown|Time|name",
		"ScheduleAt|action|Schedule At|Time|name,at_second",
		"StartCountdown|action|Start Countdown|Time|name,seconds,clock",
		"StartStopwatch|action|Start Stopwatch|Time|name,clock",
		"StopwatchSeconds|expression|Stopwatch Seconds|Time|name",
		"StopwatchText|expression|Stopwatch Text|Time|name",
		"signal:cooldown_ready|trigger|On Cooldown Ready|Time|cooldown_name",
		"signal:countdown_finished|trigger|On Countdown Finished|Time|countdown_name"
	])))


## THE THREE ROWS THIS MODULE STANDS BESIDE. system_aces has shipped Start Cooldown, Cooldown Is
## Ready and Cooldown Time Left since long before this file existed; they keep a millisecond stamp
## in metadata and are realtime whatever the game does. Their templates are a compatibility
## covenant, so they are pinned here character for character: this module adds a pausable family
## next to them and changes nothing about them.
static func _the_frozen_rows_beside_them() -> bool:
	var rows: Array = []
	rows.append(["Start Cooldown still writes its millisecond stamp",
		_shipped_template("StartCooldown"),
		"set_meta(&\"__ef_cool_\" + str({name}), Time.get_ticks_msec() + int(maxf({seconds}, 0.0) * 1000.0))"])
	rows.append(["Cooldown Is Ready still reads it",
		_shipped_template("CooldownReady"),
		"Time.get_ticks_msec() >= int(get_meta(&\"__ef_cool_\" + str({name}), 0))"])
	rows.append(["Cooldown Time Left still subtracts it",
		_shipped_template("CooldownTimeLeft"),
		"(maxf(0.0, float(int(get_meta(&\"__ef_cool_\" + str({name}), 0)) - Time.get_ticks_msec()) / 1000.0))"])
	rows.append(["and the two families keep their own metadata keys apart",
		_shipped_template("StartCooldown").contains("__ef_cooldown_"), false])
	return SUPPORT.pins(P, rows)


## COOLDOWNS, stepped by hand. A cooldown nobody started is ready; a fresh one is not; half way
## through it reads half; at exactly zero it is ready again.
static func _cooldowns_run() -> bool:
	var spy: TreeSpy = TreeSpy.new()
	var host: Object = _host(spy)
	var rows: Array = []

	rows.append(["a cooldown nobody started is off cooldown", host.call("is_off_cooldown", "dash"), true])
	rows.append(["and has no seconds left", _seconds(host, "cooldown_seconds_left", "dash"), 0.0])
	rows.append(["and reads as fully recharged", _seconds(host, "cooldown_fraction", "dash"), 1.0])

	host.call("put_on_cooldown", "dash", 0.8, false)
	rows.append(["the instant it is started it is not off cooldown", host.call("is_off_cooldown", "dash"), false])
	rows.append(["it has its whole length left", _seconds(host, "cooldown_seconds_left", "dash"), 0.8])
	rows.append(["and has recharged none of it", _seconds(host, "cooldown_fraction", "dash"), 0.0])

	_step(host, "__ef_cooldown_dash", 0.4)
	rows.append(["stepped half way it has half left", _seconds(host, "cooldown_seconds_left", "dash"), 0.4])
	rows.append(["and reads half recharged", _seconds(host, "cooldown_fraction", "dash"), 0.5])
	rows.append(["and is still not off cooldown", host.call("is_off_cooldown", "dash"), false])

	_step(host, "__ef_cooldown_dash", 0.001)
	rows.append(["a thousandth short of the end it is still running", host.call("is_off_cooldown", "dash"), false])
	_step(host, "__ef_cooldown_dash", 0.0)
	rows.append(["at exactly zero it is off cooldown", host.call("is_off_cooldown", "dash"), true])
	rows.append(["and reads fully recharged", _seconds(host, "cooldown_fraction", "dash"), 1.0])

	# Reduce Cooldown By: what a cooldown-reduction stat or a refunding hit does.
	host.call("put_on_cooldown", "dash", 0.8, false)
	host.call("reduce_cooldown_by", "dash", 0.3)
	rows.append(["reducing by three tenths leaves half a second",
		_seconds(host, "cooldown_seconds_left", "dash"), 0.5])
	host.call("reduce_cooldown_by", "dash", 2.0)
	rows.append(["reducing past the end stops at zero",
		_seconds(host, "cooldown_seconds_left", "dash"), 0.0])
	rows.append(["and the cooldown is off", host.call("is_off_cooldown", "dash"), true])

	# Clear Cooldown: the reset a new round or a respawn wants.
	host.call("put_on_cooldown", "dash", 5.0, false)
	rows.append(["a long cooldown is running before it is cleared", host.call("is_off_cooldown", "dash"), false])
	host.call("clear_cooldown", "dash")
	rows.append(["clearing it finishes it at once", host.call("is_off_cooldown", "dash"), true])
	rows.append(["with nothing left to wait", _seconds(host, "cooldown_seconds_left", "dash"), 0.0])

	# Two names are two cooldowns, which is the whole reason the rows take one.
	host.call("put_on_cooldown", "dash", 1.0, false)
	rows.append(["a second name is a second cooldown", host.call("is_off_cooldown", "heal"), true])
	rows.append(["and the first one is untouched", host.call("is_off_cooldown", "dash"), false])

	spy.release()
	return SUPPORT.pins(P, rows)


## THE CLOCK CHOICE, read where it actually lives: the two booleans the row hands Godot's own timer.
## Game time is `process_always` off and `ignore_time_scale` off, which is what makes a pause menu
## and a slow-motion moment hold the cooldown. Realtime is both on.
static func _the_clock_choice() -> bool:
	var spy: TreeSpy = TreeSpy.new()
	var host: Object = _host(spy)
	var rows: Array = []

	host.call("put_on_cooldown", "dash", 0.8, false)
	rows.append(["a game-time cooldown is held by a pause and slowed by slow motion",
		spy.calls[0], [0.8, false, false, false]])
	host.call("put_on_cooldown", "menu", 0.8, true)
	rows.append(["a realtime cooldown keeps going through both",
		spy.calls[1], [0.8, true, false, true]])
	host.call("start_countdown", "round", 90.0, false)
	rows.append(["a countdown makes the same choice the same way",
		spy.calls[2], [90.0, false, false, false]])
	host.call("start_stopwatch", "run", false)
	rows.append(["and a stopwatch counts a whole day down on the game clock",
		spy.calls[3], [DAY, false, false, false]])

	# Schedule At is the absolute form: a moment already past finishes immediately rather than
	# waiting a negative number of seconds.
	host.call("schedule_at", "wave_two", 0.0)
	rows.append(["a scheduled moment already past waits no time at all",
		spy.calls[4][0], 0.0])

	spy.release()
	return SUPPORT.pins(P, rows)


## COUNTDOWNS: the number, the text, the pause, and the clock a resume remembers.
static func _countdowns_run() -> bool:
	var spy: TreeSpy = TreeSpy.new()
	var host: Object = _host(spy)
	var rows: Array = []

	rows.append(["a countdown nobody started is not running", host.call("countdown_is_running", "round"), false])
	rows.append(["and reads zero", _seconds(host, "countdown_seconds_left", "round"), 0.0])
	rows.append(["and shows a zeroed clock", host.call("countdown_text", "round"), "00:00"])

	host.call("start_countdown", "round", 90.0, false)
	rows.append(["a started countdown is running", host.call("countdown_is_running", "round"), true])
	rows.append(["with its whole length left", _seconds(host, "countdown_seconds_left", "round"), 90.0])
	rows.append(["shown as minutes and seconds", host.call("countdown_text", "round"), "01:30"])

	_step(host, "__ef_countdown_round", 83.0)
	rows.append(["stepped on, the text follows it", host.call("countdown_text", "round"), "01:23"])

	host.call("pause_countdown", "round")
	rows.append(["a paused countdown is not running", host.call("countdown_is_running", "round"), false])
	rows.append(["but still reads the seconds it was holding",
		_seconds(host, "countdown_seconds_left", "round"), 83.0])
	rows.append(["and the label keeps the frozen number", host.call("countdown_text", "round"), "01:23"])

	host.call("resume_countdown", "round")
	rows.append(["resuming starts it again", host.call("countdown_is_running", "round"), true])
	rows.append(["from where it was held", _seconds(host, "countdown_seconds_left", "round"), 83.0])
	rows.append(["on the clock it was started with", spy.calls[spy.calls.size() - 1],
		[83.0, false, false, false]])

	# A realtime countdown remembers its own clock across a pause, which is the whole reason the
	# choice is written down beside it rather than asked for again on the resume row.
	host.call("start_countdown", "menu", 10.0, true)
	host.call("pause_countdown", "menu")
	host.call("resume_countdown", "menu")
	rows.append(["a realtime countdown resumes realtime", spy.calls[spy.calls.size() - 1],
		[10.0, true, false, true]])

	# A countdown that reached zero is finished, not running - and resuming does not revive it.
	_step(host, "__ef_countdown_round", 0.0)
	rows.append(["a countdown at zero has stopped running", host.call("countdown_is_running", "round"), false])
	host.call("resume_countdown", "round")
	rows.append(["and resuming a finished countdown leaves it finished",
		host.call("countdown_is_running", "round"), false])

	spy.release()
	return SUPPORT.pins(P, rows)


## STOPWATCHES: counting up by counting a day down, and the split a lap is.
static func _stopwatches_run() -> bool:
	var spy: TreeSpy = TreeSpy.new()
	var host: Object = _host(spy)
	var rows: Array = []

	rows.append(["a stopwatch nobody started reads zero", _seconds(host, "stopwatch_seconds", "run"), 0.0])
	rows.append(["and shows a zeroed clock", host.call("stopwatch_text", "run"), "00:00"])

	host.call("start_stopwatch", "run", false)
	rows.append(["a started stopwatch reads zero too", _seconds(host, "stopwatch_seconds", "run"), 0.0])

	_step(host, "__ef_stopwatch_run", DAY - 5.0)
	rows.append(["five seconds in, it reads five", _seconds(host, "stopwatch_seconds", "run"), 5.0])
	rows.append(["and has no lap yet", _seconds(host, "lap_seconds", "run"), 0.0])

	host.call("record_lap", "run")
	rows.append(["the first lap is the whole run so far", _seconds(host, "lap_seconds", "run"), 5.0])

	_step(host, "__ef_stopwatch_run", DAY - 12.0)
	host.call("record_lap", "run")
	rows.append(["the second lap is the time since the first", _seconds(host, "lap_seconds", "run"), 7.0])
	rows.append(["shown as minutes and seconds", host.call("lap_text", "run"), "00:07"])
	rows.append(["while the run itself keeps counting", _seconds(host, "stopwatch_seconds", "run"), 12.0])
	rows.append(["and shows its own text", host.call("stopwatch_text", "run"), "00:12"])

	_step(host, "__ef_stopwatch_run", DAY - 90.0)
	rows.append(["past a minute the text rolls over", host.call("stopwatch_text", "run"), "01:30"])

	# Restarting clears the laps as well as the clock, so a second run never inherits the first.
	host.call("start_stopwatch", "run", false)
	rows.append(["restarting puts the clock back to zero", _seconds(host, "stopwatch_seconds", "run"), 0.0])
	rows.append(["and clears the last lap with it", _seconds(host, "lap_seconds", "run"), 0.0])

	spy.release()
	return SUPPORT.pins(P, rows)


## THE TRIGGER. On Cooldown Ready is a real signal: the starting row connects the timer's own
## timeout to it when the sheet declares it. There is no running tree here to fire that timeout, so
## the test asks the two halves it can ask - that exactly one connection was made, and that calling
## what was connected emits the sheet's signal carrying the cooldown's name.
static func _the_ready_signal() -> bool:
	var spy: TreeSpy = TreeSpy.new()
	var host: Object = _host(spy)
	var heard: Array = []
	host.connect("cooldown_ready", func(cooldown_name: String) -> void: heard.append(cooldown_name))
	host.connect("countdown_finished", func(countdown_name: String) -> void: heard.append(countdown_name))

	host.call("put_on_cooldown", "dash", 0.8, false)
	var timer: SceneTreeTimer = host.get_meta("__ef_cooldown_dash", 0.0) as SceneTreeTimer
	var rows: Array = []
	rows.append(["the started cooldown connected its timer once", timer.timeout.get_connections().size(), 1])
	for connection: Dictionary in timer.timeout.get_connections():
		(connection["callable"] as Callable).call()
	rows.append(["and what it connected announces the cooldown by name", heard.duplicate(), ["dash"]])

	host.call("start_countdown", "round", 90.0, false)
	var countdown: SceneTreeTimer = host.get_meta("__ef_countdown_round", 0.0) as SceneTreeTimer
	for connection: Dictionary in countdown.timeout.get_connections():
		(connection["callable"] as Callable).call()
	rows.append(["and a countdown announces itself the same way", heard.duplicate(), ["dash", "round"]])

	spy.release()
	return SUPPORT.pins(P, rows)


## WHAT COMES BACK when somebody writes these lines by hand. The two conditions are one expression
## each, so they read back as their own rows; the actions are runs of statements, which the reading
## keeps as honest verbatim blocks rather than guessing at. Both files re-emit byte for byte, which
## is the contract that matters either way.
static func _what_comes_back() -> bool:
	var rows: Array = []
	var ready_source: String = _file_around("\tif %s:\n\t\tdash()\n" % _filled("IsOffCooldown"))
	rows.append(["a hand-written off-cooldown test reads back as the row",
		_lifted_condition_ids(ready_source), PackedStringArray(["IsOffCooldown"])])
	rows.append(["and the file re-emits byte for byte",
		SUPPORT.reemit(ready_source, "user://cooldown_aces_ready_roundtrip.gd"), ready_source])

	var running_source: String = _file_around("\tif %s:\n\t\ttick()\n" % _filled("CountdownIsRunning"))
	rows.append(["a hand-written countdown-running test reads back as its row",
		_lifted_condition_ids(running_source), PackedStringArray(["CountdownIsRunning"])])
	rows.append(["and that file re-emits byte for byte",
		SUPPORT.reemit(running_source, "user://cooldown_aces_running_roundtrip.gd"), running_source])

	# The multi-statement rows: no cooldown row claims a whole run of statements, so a hand-written
	# start is read for what its lines plainly are - the signal guard becomes the general "expression
	# is true" condition every `if` reads as, and the four lines come back unmangled. That is the
	# degrade the contract asks for, and the byte compare below is what makes it safe.
	var started_source: String = _file_around(_indented(_filled("PutOnCooldown")))
	rows.append(["a hand-written start is never mistaken for a cooldown row",
		_lifted_condition_ids(started_source), PackedStringArray(["ExpressionIsTrue"])])
	rows.append(["and it too re-emits byte for byte",
		SUPPORT.reemit(started_source, "user://cooldown_aces_start_roundtrip.gd"), started_source])

	var lap_source: String = _file_around(_indented(_filled("RecordLap")))
	rows.append(["and so does a hand-written lap",
		SUPPORT.reemit(lap_source, "user://cooldown_aces_lap_roundtrip.gd"), lap_source])
	return SUPPORT.pins(P, rows)


## One descriptor's template with every field on its own default, which is the line a row writes the
## moment it is dropped.
static func _filled(ace_id: String) -> String:
	for descriptor: ACEDescriptor in MODULE.get_descriptors():
		if descriptor.ace_id != ace_id:
			continue
		var values: Dictionary = {"uid": "0"}
		for parameter: ACEParam in descriptor.params:
			values[str(parameter.id)] = str(parameter.default_value)
		return ActionCodegen._apply_template(descriptor.codegen_template, values)
	return ""


## A block of statements at one tab, the way a function body holds them.
static func _indented(statements: String) -> String:
	var written: PackedStringArray = PackedStringArray()
	for line: String in statements.split("\n"):
		written.append("\t%s" % line)
	return "%s\n" % "\n".join(written)


## The smallest hand-written file a statement can live in.
static func _file_around(body: String) -> String:
	return "extends Node\n\n\nfunc _ready() -> void:\n%s" % body


## The ace_ids of every condition a reopened source lifted, in order.
static func _lifted_condition_ids(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var reopened: EventSheetResource = SUPPORT.reopen(source)
	if reopened == null:
		return found
	for item: Variant in reopened.events:
		if not (item is EventRow):
			continue
		for entry: Variant in (item as EventRow).conditions:
			if entry is ACECondition:
				found.append(str((entry as ACECondition).ace_id))
	return found


## One shipped template, straight off the registry, so a pin reads what the plugin really ships
## rather than what a module file was authored with.
static func _shipped_template(ace_id: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	return "" if descriptor == null else str(descriptor.codegen_template)


## A row's answer as a number a pin can compare: rounded to a ten-thousandth, so a value that came
## back through a float32 property is still the number the row promised.
static func _seconds(host: Object, method: String, label: String) -> float:
	return snappedf(float(host.call(method, label)), 0.0001)


## Steps one named clock by hand: the timer in metadata is told how much of it is left. This is the
## whole reason the test needs no running tree.
static func _step(host: Object, meta_key: String, time_left: float) -> void:
	var held: Variant = host.get_meta(meta_key, 0.0)
	if held is SceneTreeTimer:
		(held as SceneTreeTimer).time_left = time_left


## The word a descriptor's kind is written with in the pinned text.
static func _kind_of(descriptor: ACEDescriptor) -> String:
	match descriptor.ace_type:
		ACEDescriptor.ACEType.ACTION:
			return "action"
		ACEDescriptor.ACEType.CONDITION:
			return "condition"
		ACEDescriptor.ACEType.EXPRESSION:
			return "expression"
		_:
			return "trigger"


## The throwaway host every behaviour pin runs against: one method per non-trigger row, built out of
## the SHIPPED template with its fields bound to the method's own arguments, plus the two signals a
## sheet would declare with Signal rows. It is a RefCounted rather than a Node so it can answer
## get_tree() with the stand-in above; every other call the templates make (set_meta, get_meta,
## has_signal, emit_signal) is an Object's own.
static func _host(spy: TreeSpy) -> Object:
	var script: GDScript = GDScript.new()
	script.source_code = _host_source()
	script.reload()
	var host: Object = script.new()
	host.set("tree", spy)
	return host


static func _host_source() -> String:
	var lines: PackedStringArray = PackedStringArray([
		"extends RefCounted", "", "",
		"signal cooldown_ready(cooldown_name: String)",
		"signal countdown_finished(countdown_name: String)", "",
		"var tree: Variant = null", "", "",
		"func get_tree() -> Variant:", "\treturn tree", ""
	])
	var uid: int = 0
	for descriptor: ACEDescriptor in MODULE.get_descriptors():
		if descriptor.ace_type == ACEDescriptor.ACEType.TRIGGER:
			continue
		uid += 1
		var values: Dictionary = {"uid": str(uid)}
		var arguments: PackedStringArray = PackedStringArray()
		for parameter: ACEParam in descriptor.params:
			var argument: String = str(ARGUMENTS.get(str(parameter.id), str(parameter.id)))
			values[str(parameter.id)] = argument
			arguments.append("%s: %s" % [argument, _argument_type(str(parameter.id))])
		var body: String = ActionCodegen._apply_template(descriptor.codegen_template, values)
		var returns: bool = descriptor.ace_type != ACEDescriptor.ACEType.ACTION
		lines.append("")
		lines.append("func %s(%s) -> Variant:" % [_method_name(descriptor.ace_id), ", ".join(arguments)])
		for line: String in body.split("\n"):
			lines.append("\t%s%s" % ["return " if returns else "", line])
		if not returns:
			lines.append("\treturn null")
	return "%s\n" % "\n".join(lines)


## The type each bound argument is declared with, so the generated host is typed GDScript like
## everything else the plugin writes.
static func _argument_type(param_id: String) -> String:
	match param_id:
		"name":
			return "String"
		"clock":
			return "bool"
		_:
			return "float"


## An ace_id as a method name: PutOnCooldown becomes put_on_cooldown.
static func _method_name(ace_id: String) -> String:
	var written: String = ""
	for index in range(ace_id.length()):
		var letter: String = ace_id[index]
		if letter == letter.to_upper() and letter != letter.to_lower() and index > 0:
			written += "_"
		written += letter.to_lower()
	return written
