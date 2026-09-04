# EventForge module - NAMED CLOCKS: cooldowns, countdowns and stopwatches as words.
#
# A game asks four questions about time that a plain number cannot answer well: "am I allowed to
# dash yet", "how long until the door shuts", "show 01:23 counting down" and "how long did that
# take". Written by hand each of those is a float variable, a per-frame subtraction, a clamp, and a
# bug the day somebody opens the pause menu. These rows name the clock instead, and the engine holds
# it.
#
# THE STORE is node metadata, keyed by the name the row was given, so a clock started in one event
# is asked about in another (or in a different sheet on the same node) with no wiring between them.
# Nothing is hoisted, nothing is an autoload, and every row is a plain statement or a plain
# expression a reader can follow.
#
# THE CLOCK ITSELF is a SceneTreeTimer, which is Godot's own. That choice is the whole point of this
# module: a timer made with `process_always` off STOPS while the tree is paused and runs slower
# while Engine.time_scale is under one, so a cooldown started here is held by the pause menu and by
# a slow-motion moment without a single row saying so. The realtime choice on the row is the same
# timer made with `process_always` and `ignore_time_scale` on, for the menu countdown that must keep
# going while everything else is frozen. One dropdown, two words, no new concept.
#
# WHAT IS NOT HERE. system_aces ships Start Cooldown / Cooldown Is Ready / Cooldown Time Left, which
# keep a millisecond stamp in metadata and are therefore realtime whatever the game does. They are
# frozen and unchanged; a sheet already using them keeps working byte for byte. The rows here are
# the pausable family beside them, which is why they say Put On Cooldown and Is Off Cooldown rather
# than the same words twice. The Timer pack's three rows (a private clock on one node, with its own
# On Timer trigger) and the Abilities pack's ability cooldowns are likewise untouched.
#
# THE TWO TRIGGERS hang off signals the SHEET declares, exactly as On Scene Spawned does: add a
# Signal row for `cooldown_ready(cooldown_name: String)` or `countdown_finished(countdown_name:
# String)` and the starting rows connect the timer to it. Without the Signal row the sheet still
# compiles - the emitted line asks `has_signal` first - and nothing connects the event, which the
# Project Doctor already reports for this shape of trigger.
#
# ace_ids and codegen_templates are a compatibility covenant: frozen once shipped (deprecate, never
# rename).
@tool
class_name EventForgeCooldownACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")
const CAT := "Time"

## The metadata key each family keeps its clock under, written out in every template so the emitted
## line stays plain GDScript with nothing to look up. The name is a row parameter, so the key is
## built from it at runtime and two clocks called different things never meet.
const _CD_KEY: String = "\"__ef_cooldown_\" + str({name})"
const _CD_LEN_KEY: String = "\"__ef_cooldown_length_\" + str({name})"
const _CN_KEY: String = "\"__ef_countdown_\" + str({name})"
const _CN_CLOCK_KEY: String = "\"__ef_countdown_realtime_\" + str({name})"
const _SW_KEY: String = "\"__ef_stopwatch_\" + str({name})"
const _SW_LAP_KEY: String = "\"__ef_stopwatch_lap_\" + str({name})"
const _SW_MARK_KEY: String = "\"__ef_stopwatch_mark_\" + str({name})"

## The timer a starting row makes, in both clocks at once: the one dropdown answers `process_always`
## and `ignore_time_scale` together, because "keep going while the game is paused" and "ignore slow
## motion" are the same wish and splitting them into two fields would only invite the half-answer.
const _NEW_TIMER: String = "get_tree().create_timer(maxf({seconds}, 0.0), {clock}, false, {clock})"

## How long a stopwatch is allowed to run: one day, which no session reaches and which reads as a
## real number in the emitted line. A stopwatch counts UP by counting a very long timer DOWN, so
## the elapsed seconds are this span minus what is left, and a stopwatch nobody started reads zero
## because the span cancels itself out.
const _SW_SPAN: String = "86400.0"

## RETIRING THE CLOCK A ROW REPLACES. A SceneTreeTimer is held by the TREE rather than by the
## metadata this module writes it into, so a timer that is merely overwritten goes on running and
## goes on emitting: a restarted cooldown would announce itself twice, once at the abandoned clock's
## moment and once at its own, and a paused countdown would announce itself while it is held. Every
## row that replaces or parks a clock therefore takes the listeners off the old one and runs it out
## first. Two lines, and the trigger tells the truth.
const _RETIRE: String = "var __old_{uid}: Variant = get_meta(%s, 0.0)\nif __old_{uid} is SceneTreeTimer:\n\tfor __gone_{uid}: Dictionary in (__old_{uid} as SceneTreeTimer).timeout.get_connections():\n\t\t(__old_{uid} as SceneTreeTimer).timeout.disconnect(__gone_{uid}[\"callable\"])\n\t(__old_{uid} as SceneTreeTimer).time_left = 0.0\n"

## The seconds left on a cooldown: the timer's own, or zero when no cooldown of that name was ever
## started, which is why the first use of anything is always allowed.
const _CD_LEFT: String = "((get_meta(%s, 0.0) as SceneTreeTimer).time_left if get_meta(%s, 0.0) is SceneTreeTimer else 0.0)" % [_CD_KEY, _CD_KEY]

## The seconds left on a countdown. Three answers in one expression, because the metadata holds one
## of three things: a running timer, the float a Pause Countdown row parked there, or nothing at all
## for a countdown that was never started. The `0.0` default makes the last two the same branch.
const _CN_LEFT: String = "((get_meta(%s, 0.0) as SceneTreeTimer).time_left if get_meta(%s, 0.0) is SceneTreeTimer else float(get_meta(%s, 0.0)))" % [_CN_KEY, _CN_KEY, _CN_KEY]

## The seconds a stopwatch has been running: the span it was started with, minus what is left of it.
const _SW_DONE: String = "(%s - ((get_meta(%s, 0.0) as SceneTreeTimer).time_left if get_meta(%s, 0.0) is SceneTreeTimer else %s))" % [_SW_SPAN, _SW_KEY, _SW_KEY, _SW_SPAN]

## Minutes and seconds, the spelling the shipped As Clock Time row uses, over any seconds expression.
## Written here rather than reached for so the emitted line owes nothing to another row.
const _CLOCK_TEXT: String = "(\"%%02d:%%02d\" %% [int(maxf(%s, 0.0)) / 60, int(maxf(%s, 0.0)) %% 60])"


## The words in the picker. Four families, one store, one clock choice.
static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append_array(_cooldown_descriptors())
	descriptors.append_array(_countdown_descriptors())
	descriptors.append_array(_stopwatch_descriptors())
	return descriptors


## COOLDOWNS: "am I allowed to do this yet". Started by name, asked by name, and readable as a
## number or a fraction so a HUD ring can draw it without a variable of its own.
static func _cooldown_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.act("PutOnCooldown", "Put On Cooldown",
		"%s%s" % [_RETIRE % _CD_KEY, "var __cooldown_{uid}: SceneTreeTimer = %s\nif has_signal(&\"cooldown_ready\"): __cooldown_{uid}.timeout.connect(emit_signal.bind(&\"cooldown_ready\", {name}))\nset_meta(%s, __cooldown_{uid})\nset_meta(%s, maxf({seconds}, 0.0))" % [_NEW_TIMER, _CD_KEY, _CD_LEN_KEY]],
		CAT, "put [b]{name}[/b] on cooldown for [b]{seconds}[/b]s",
		"Starts (or restarts) a named cooldown. Ask it with Is Off Cooldown before the thing it guards, and the same name works from any event on this node. On game time the cooldown is held while the game is paused and runs slow while the game does, which is what a dash or a spell wants; pick realtime for a clock that must keep going through a pause menu. If the sheet declares a cooldown_ready(cooldown_name) signal, the On Cooldown Ready trigger fires the moment it finishes.")
		.param("name", "\"dash\"", "Named", "The cooldown's name. Every row using the same name is talking about the same cooldown.", "expression")
		.param("seconds", "0.8", "For Seconds", "How long the cooldown lasts.", "expression")
		.param_built(_clock_param())
		.featured())
	descriptors.append(F.cond("IsOffCooldown", "Is Off Cooldown",
		"(not (get_meta(%s, 0.0) is SceneTreeTimer) or %s <= 0.0)" % [_CD_KEY, _CD_LEFT],
		CAT, "[b]{name}[/b] is off cooldown",
		"True when the named cooldown has finished, so the action it guards may run. A cooldown nobody has started counts as finished, which is why the first press always works.")
		.param("name", "\"dash\"", "Named", "The cooldown's name, matching the Put On Cooldown row that started it.", "expression")
		.featured())
	descriptors.append(F.expr("CooldownSecondsLeft", "Cooldown Seconds Left", _CD_LEFT,
		CAT, "cooldown [b]{name}[/b] seconds left",
		"The seconds still to wait on a named cooldown, or zero when it is finished. The number a HUD label shows.")
		.param("name", "\"dash\"", "Named", "The cooldown's name.", "expression"))
	descriptors.append(F.expr("CooldownFraction", "Cooldown Fraction",
		"clampf(1.0 - %s / maxf(float(get_meta(%s, 1.0)), 0.001), 0.0, 1.0)" % [_CD_LEFT, _CD_LEN_KEY],
		CAT, "cooldown [b]{name}[/b] fraction",
		"How far a named cooldown has recharged, from 0 the instant it starts to 1 when it is ready. The value a radial bar or a fading icon is set to, with no maths on the row.")
		.param("name", "\"dash\"", "Named", "The cooldown's name.", "expression"))
	descriptors.append(F.act("ReduceCooldownBy", "Reduce Cooldown By",
		"var __cooldown_{uid}: Variant = get_meta(%s, 0.0)\nif __cooldown_{uid} is SceneTreeTimer: (__cooldown_{uid} as SceneTreeTimer).time_left = maxf((__cooldown_{uid} as SceneTreeTimer).time_left - maxf({seconds}, 0.0), 0.0)" % _CD_KEY,
		CAT, "reduce cooldown [b]{name}[/b] by [b]{seconds}[/b]s",
		"Takes seconds off a running cooldown, which is what a cooldown-reduction stat, a pickup or a hit that refunds part of an ability does. Reducing it past zero simply finishes it.")
		.param("name", "\"dash\"", "Named", "The cooldown's name.", "expression")
		.param("seconds", "0.2", "By Seconds", "How many seconds to take off.", "expression"))
	descriptors.append(F.act("ClearCooldown", "Clear Cooldown",
		"var __cooldown_{uid}: Variant = get_meta(%s, 0.0)\nif __cooldown_{uid} is SceneTreeTimer: (__cooldown_{uid} as SceneTreeTimer).time_left = 0.0" % _CD_KEY,
		CAT, "clear cooldown [b]{name}[/b]",
		"Finishes a named cooldown at once, so the thing it guards is available again. The reset a new round, a respawn or a debug key wants. On Cooldown Ready fires for it like any other finish.")
		.param("name", "\"dash\"", "Named", "The cooldown's name.", "expression"))
	descriptors.append(F.trig("signal:cooldown_ready", "On Cooldown Ready", "cooldown_ready",
		CAT, "On cooldown ready ( [b]{cooldown_name}[/b] )",
		"Runs the moment a named cooldown finishes, so a HUD icon lights up or a ready sound plays without asking every frame. The name arrives on the row as cooldown_name, so one event can answer for every cooldown. Needs a Signal row for cooldown_ready(cooldown_name: String) - without one the sheet still compiles, but nothing connects this event, so it never runs.")
		.param("cooldown_name", "", "Name", "Which cooldown finished, carried by the signal itself."))
	return descriptors


## COUNTDOWNS: "how long until". The same timer, said the other way round, plus the pause a round
## timer needs when the game opens a menu in the middle of it.
static func _countdown_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.act("StartCountdown", "Start Countdown",
		"%s%s" % [_RETIRE % _CN_KEY, "var __countdown_{uid}: SceneTreeTimer = %s\nif has_signal(&\"countdown_finished\"): __countdown_{uid}.timeout.connect(emit_signal.bind(&\"countdown_finished\", {name}))\nset_meta(%s, __countdown_{uid})\nset_meta(%s, {clock})" % [_NEW_TIMER, _CN_KEY, _CN_CLOCK_KEY]],
		CAT, "start countdown [b]{name}[/b] for [b]{seconds}[/b]s",
		"Starts a named countdown that a label can show and an event can react to. On game time it is held by the pause menu and slowed by slow motion, which is what a round timer wants; pick realtime for a menu clock that must keep going while the game is paused. Reaching zero fires On Countdown Finished when the sheet declares the signal.")
		.param("name", "\"round\"", "Named", "The countdown's name. Every row using the same name is talking about the same countdown.", "expression")
		.param("seconds", "90.0", "For Seconds", "How long the countdown runs.", "expression")
		.param_built(_clock_param())
		.featured())
	# THE ONE ROW THAT IS REALTIME WHATEVER THE DROPDOWN SAYS, and it has no dropdown for that
	# reason: the moment it is given is a reading of the Game Time expression, which is
	# Time.get_ticks_msec - a clock a pause and a slow-motion moment do not touch. A game-time timer
	# counted against a realtime moment would finish AFTER the second the row named, by however long
	# the game spent paused, so the wait is made on the same clock the moment was measured on.
	descriptors.append(F.act("ScheduleAt", "Schedule At",
		"%s%s" % [_RETIRE % _CN_KEY, "var __countdown_{uid}: SceneTreeTimer = get_tree().create_timer(maxf({at_second} - Time.get_ticks_msec() / 1000.0, 0.0), true, false, true)\nif has_signal(&\"countdown_finished\"): __countdown_{uid}.timeout.connect(emit_signal.bind(&\"countdown_finished\", {name}))\nset_meta(%s, __countdown_{uid})\nset_meta(%s, true)" % [_CN_KEY, _CN_CLOCK_KEY]],
		CAT, "schedule [b]{name}[/b] at second [b]{at_second}[/b]",
		"Starts a named countdown that finishes at a moment on the game's own clock rather than after a length of time. The moment is a number of seconds since the game started, which the Game Time expression gives, so a scripted event at the two minute mark is one row. A moment already past finishes immediately. It arrives as On Countdown Finished, like any other countdown.")
		.param("name", "\"wave_two\"", "Named", "The countdown's name.", "expression")
		.param("at_second", "120.0", "At Second", "The moment to finish at, in seconds since the game started - the same number the Game Time expression reads.", "expression"))
	descriptors.append(F.expr("CountdownSecondsLeft", "Countdown Seconds Left", _CN_LEFT,
		CAT, "countdown [b]{name}[/b] seconds left",
		"The seconds still to run on a named countdown, zero when it has finished or was never started, and the paused number while it is paused. The value a bar is set to.")
		.param("name", "\"round\"", "Named", "The countdown's name.", "expression"))
	descriptors.append(F.expr("CountdownText", "Countdown Text", _CLOCK_TEXT % [_CN_LEFT, _CN_LEFT],
		CAT, "countdown [b]{name}[/b] as text",
		"A named countdown as minutes and seconds, so 83 seconds left reads \"01:23\". The text a clock label is set to, with no formatting on the row. A countdown longer than an hour keeps counting in minutes rather than rolling over.")
		.param("name", "\"round\"", "Named", "The countdown's name.", "expression")
		.featured())
	descriptors.append(F.cond("CountdownIsRunning", "Countdown Is Running",
		"(get_meta(%s, 0.0) is SceneTreeTimer and %s > 0.0)" % [_CN_KEY, _CN_LEFT],
		CAT, "countdown [b]{name}[/b] is running",
		"True while a named countdown is counting down. A countdown that has finished, that is paused, or that was never started is not running.")
		.param("name", "\"round\"", "Named", "The countdown's name.", "expression"))
	descriptors.append(F.act("PauseCountdown", "Pause Countdown",
		"var __countdown_{uid}: Variant = get_meta(%s, 0.0)\nif __countdown_{uid} is SceneTreeTimer:\n\tset_meta(%s, (__countdown_{uid} as SceneTreeTimer).time_left)\n\tfor __gone_{uid}: Dictionary in (__countdown_{uid} as SceneTreeTimer).timeout.get_connections():\n\t\t(__countdown_{uid} as SceneTreeTimer).timeout.disconnect(__gone_{uid}[\"callable\"])\n\t(__countdown_{uid} as SceneTreeTimer).time_left = 0.0" % [_CN_KEY, _CN_KEY],
		CAT, "pause countdown [b]{name}[/b]",
		"Holds a named countdown where it is. The seconds left stay readable while it is held, so a label keeps showing the frozen number. Resume Countdown starts it again from there. This is the row for a countdown that must stop for a cutscene or a shop, rather than for the pause menu, which a game-time countdown already holds by itself.")
		.param("name", "\"round\"", "Named", "The countdown's name.", "expression"))
	descriptors.append(F.act("ResumeCountdown", "Resume Countdown",
		"var __countdown_{uid}: Variant = get_meta(%s, 0.0)\nif not (__countdown_{uid} is SceneTreeTimer) and float(__countdown_{uid}) > 0.0:\n\tvar __realtime_{uid}: bool = bool(get_meta(%s, false))\n\tvar __resumed_{uid}: SceneTreeTimer = get_tree().create_timer(float(__countdown_{uid}), __realtime_{uid}, false, __realtime_{uid})\n\tif has_signal(&\"countdown_finished\"): __resumed_{uid}.timeout.connect(emit_signal.bind(&\"countdown_finished\", {name}))\n\tset_meta(%s, __resumed_{uid})" % [_CN_KEY, _CN_CLOCK_KEY, _CN_KEY],
		CAT, "resume countdown [b]{name}[/b]",
		"Starts a paused countdown again from the seconds it was holding, on the same clock it was started with. A countdown that is already running, or that has finished, is left alone.")
		.param("name", "\"round\"", "Named", "The countdown's name.", "expression"))
	descriptors.append(F.trig("signal:countdown_finished", "On Countdown Finished", "countdown_finished",
		CAT, "On countdown finished ( [b]{countdown_name}[/b] )",
		"Runs the moment a named countdown reaches zero. The name arrives on the row as countdown_name, so one event can answer for every countdown and a condition under it can pick out one. Needs a Signal row for countdown_finished(countdown_name: String) - without one the sheet still compiles, but nothing connects this event, so it never runs.")
		.param("countdown_name", "", "Name", "Which countdown finished, carried by the signal itself."))
	return descriptors


## STOPWATCHES: "how long did that take". The same timer run the long way round, so a run timer and a
## lap split cost one row each instead of a variable and a subtraction.
static func _stopwatch_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append(F.act("StartStopwatch", "Start Stopwatch",
		"%s%s" % [_RETIRE % _SW_KEY, "set_meta(%s, get_tree().create_timer(%s, {clock}, false, {clock}))\nset_meta(%s, 0.0)\nset_meta(%s, 0.0)" % [_SW_KEY, _SW_SPAN, _SW_LAP_KEY, _SW_MARK_KEY]],
		CAT, "start stopwatch [b]{name}[/b]",
		"Starts (or restarts) a named stopwatch counting up from zero, and clears its laps. On game time it stops while the game is paused, which is what a speedrun clock wants; pick realtime to time the real seconds a player sat there. It runs for up to a day.")
		.param("name", "\"run\"", "Named", "The stopwatch's name. Every row using the same name is talking about the same stopwatch.", "expression")
		.param_built(_clock_param()))
	descriptors.append(F.act("RecordLap", "Record Lap",
		"set_meta(%s, %s - float(get_meta(%s, 0.0)))\nset_meta(%s, %s)" % [_SW_LAP_KEY, _SW_DONE, _SW_MARK_KEY, _SW_MARK_KEY, _SW_DONE],
		CAT, "record lap on stopwatch [b]{name}[/b]",
		"Marks a split on a named stopwatch: the time since the previous lap becomes the last lap, and the stopwatch keeps running. Stopwatch Text shows either the total or that last lap.")
		.param("name", "\"run\"", "Named", "The stopwatch's name.", "expression"))
	descriptors.append(F.expr("StopwatchSeconds", "Stopwatch Seconds", _SW_DONE,
		CAT, "stopwatch [b]{name}[/b] seconds",
		"How long a named stopwatch has been running, in seconds, or zero when it was never started. The number a best-time comparison uses.")
		.param("name", "\"run\"", "Named", "The stopwatch's name.", "expression"))
	descriptors.append(F.expr("StopwatchText", "Stopwatch Text", _CLOCK_TEXT % [_SW_DONE, _SW_DONE],
		CAT, "stopwatch [b]{name}[/b] as text",
		"A named stopwatch as minutes and seconds, so 83 seconds reads \"01:23\". The text a run-timer label is set to, with no formatting on the row.")
		.param("name", "\"run\"", "Named", "The stopwatch's name.", "expression")
		.featured())
	descriptors.append(F.expr("LapSeconds", "Lap Seconds", "float(get_meta(%s, 0.0))" % _SW_LAP_KEY,
		CAT, "stopwatch [b]{name}[/b] last lap seconds",
		"How long the last lap took, in seconds - the split the most recent Record Lap row marked. Zero until the first lap is recorded.")
		.param("name", "\"run\"", "Named", "The stopwatch's name.", "expression"))
	descriptors.append(F.expr("LapText", "Lap Text",
		_CLOCK_TEXT % ["float(get_meta(%s, 0.0))" % _SW_LAP_KEY, "float(get_meta(%s, 0.0))" % _SW_LAP_KEY],
		CAT, "stopwatch [b]{name}[/b] last lap as text",
		"The last lap on a named stopwatch as minutes and seconds. The text a split label is set to.")
		.param("name", "\"run\"", "Named", "The stopwatch's name.", "expression"))
	return descriptors


## The clock choice every starting row wears, built once so the three families cannot word it
## differently. The value IS the two booleans Godot's own timer takes, which is why the row can
## offer one word instead of two checkboxes.
static func _clock_param() -> ACEParam:
	return ACEParam.of("clock", "String", "false", "Clock",
		"Game time is held by a pause and slowed by slow motion; realtime keeps going through both.",
		"", [{"key": "false", "label": "game time"}, {"key": "true", "label": "realtime"}])
