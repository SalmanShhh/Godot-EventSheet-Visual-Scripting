# EventForge module - Timed inputs: input windows, mashes, prompts and graded timing.
#
# A dodge window, a finisher, a lockpick and a rhythm hit are all the same five words: open a window
# for a moment, ask whether the control was pressed while it was open, grade how close to the end it
# was, notice when it closed with nothing pressed, and show the player which key to press. The
# hand-written shape is a flag, a deadline and two branches, and these are that shape spelled once.
#
# The clock is `Time.get_ticks_msec()`, which is the engine's own and keeps counting while the game
# is paused - so a window opened before a pause closes during it. Every row here says so, and the
# reading of a hand-written window says which clock it is on too.
#
# Sequence QTEs (press the shown inputs in order) are the Combo Box behaviour's whole job, so nothing
# here re-speaks it: register the sequence there and let these rows open the window around it.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeTimedInputACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const TIMED := "Timed Input"

## The seconds-since-start clock every row here measures against, written the way an ordinary Godot
## script writes it. One constant so the open, the press test, the miss and the mash can never drift
## into measuring against two different clocks.
const NOW := "Time.get_ticks_msec() / 1000.0"

## The window OWNS the prompt: opening one puts the control's key on a label, closing one takes it
## off again, so a prompt can never outlive the moment it was asking about. Both rows carry the same
## optional Prompt parameter, whose value is the extra line itself - empty by default, which is why
## a window authored before this existed still writes the two lines it always wrote, byte for byte.
## The parameter hints name the two little editors that compose that line out of a label and a
## control, so the row never asks anybody to type code into it.
const PROMPT_SHOW_HINT := "input_prompt_show"
const PROMPT_CLEAR_HINT := "input_prompt_clear"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_windows(descriptors)
	_buffering(descriptors)
	_mashing(descriptors)
	_prompts(descriptors)
	_rhythm(descriptors)
	return descriptors


## Input buffering, the third timing trick a combo game writes.
##
## A window asks "was it pressed while I was listening"; a BUFFER asks the other way round - the
## player pressed a moment too early, and the game remembers the press for a moment so the move
## still comes out when it becomes legal. Fighters, platformers (the jump pressed just before
## landing) and rhythm games all lean on it, and everybody writes the same three lines.
##
## Counted in SECONDS by default, on the same clock as every other row in this module. A buffer
## written in frames is a different length of time on every machine that runs the game: six frames
## is 100 ms at 60 fps and 50 ms at 120 fps, so a fighter tuned on one monitor feels stiff on a
## faster one and forgiving on a slower one. Seconds are the same everywhere.
##
## The frame-counted rows are still here, spelled out as such, because a genre that thinks in frames
## has a real reason to: on a fixed physics tick the frame IS the moment the move becomes legal, and
## a six-frame buffer is a number that gets compared against a frame-data table. Pick the pair that
## matches how the game is tuned, and use one pair per buffer - the two clocks write the same
## variable and would read each other's numbers as nonsense.
##
## Either way the variable holds the moment the memory expires ON, so nothing has to be counted down
## every tick.
##
## Consuming spells the expiry as "a second ago" (or "one frame ago") rather than as a bare -1 ON
## PURPOSE. A template of `{input} = -1` is a longer literal than the general Set value row, so the
## reverse-lifter would prefer it - and every `hp = -1` in every project on earth would start reading
## as "consume hp". The clock spelling cannot be mistaken for anything else.
##
## Name the variable after the input it remembers - `punch_input`, `jump_input` - and an opened
## script reads the row back with the input's own name in it.
static func _buffering(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("BufferInput", "Buffer Input", "{input} = %s + {seconds}" % NOW, TIMED, "Buffer {input} for {seconds} s", "Remembers a press for a moment so an input made slightly too early still comes out - the jump pressed just before landing, the punch pressed during the last move. Put it under the control's own pressed event.").param("input", "punch_input", "Buffered input", "The number variable remembering the press. Name it after the input - punch_input, jump_input - and the row reads back with that name in it.", "variable_reference").param("seconds", "0.1", "Seconds", "How long the press stays remembered. A tenth of a second is about six frames at 60 fps, and stays that long on any machine.", "expression").featured())
	descriptors.append(F.cond("IsInputBuffered", "Is Input Buffered", "(%s <= {input})" % NOW, TIMED, "{input} is buffered", "True while a remembered press is still fresh. Ask it the moment the move becomes legal, and consume it in the same breath so one press cannot come out twice.").param("input", "punch_input", "Buffered input", "The number variable remembering the press.", "variable_reference").featured())
	descriptors.append(F.act("ConsumeBufferedInput", "Consume Buffered Input", "{input} = %s - 1.0" % NOW, TIMED, "Consume {input}", "Forgets the remembered press, so the move it let through cannot come out a second time. Put it directly under the move it started.").param("input", "punch_input", "Buffered input", "The number variable remembering the press.", "variable_reference"))
	descriptors.append(F.act("BufferInputFrames", "Buffer Input (Frames)", "{input} = Engine.get_physics_frames() + {frames}", TIMED, "Buffer {input} for {frames} frames", "The frame-counted buffer, for a game tuned against a frame-data table. Everything the seconds row does, measured in physics frames instead. Use the frame-counted condition and consume rows with it - do not mix the two clocks on one variable.").param("input", "punch_input", "Buffered input", "The number variable remembering the press. Name it after the input - punch_input, jump_input - and the row reads back with that name in it.", "variable_reference").param("frames", "6", "Frames", "How many physics frames the press stays remembered for. Physics frames, not drawn ones, so the count does not move with the frame rate - but it is still a different length of TIME on a project with a different physics tick.", "expression"))
	descriptors.append(F.cond("IsInputBufferedFrames", "Is Input Buffered (Frames)", "(Engine.get_physics_frames() <= {input})", TIMED, "{input} is buffered (frames)", "True while a frame-counted press is still fresh. Pair it with Buffer Input (Frames).").param("input", "punch_input", "Buffered input", "The number variable remembering the press.", "variable_reference"))
	descriptors.append(F.act("ConsumeBufferedInputFrames", "Consume Buffered Input (Frames)", "{input} = Engine.get_physics_frames() - 1", TIMED, "Consume {input} (frames)", "Forgets a frame-counted press. Pair it with Buffer Input (Frames).").param("input", "punch_input", "Buffered input", "The number variable remembering the press.", "variable_reference"))


## The window itself: open it, ask about it, close it. The flag and the deadline are two ordinary
## variables the sheet declares, which is what lets an opened script read back as these rows.
static func _windows(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("OpenInputWindow", "Open Input Window", "{open_flag} = true\n{deadline} = %s + {seconds}{prompt}" % NOW, TIMED, "Open input window for {seconds} s", "Opens a window the player has a moment to answer. Measured on the engine clock, which keeps running while the game is paused.").param("open_flag", "window_open", "Window flag", "The yes-no variable that says the window is open.", "variable_reference").param("deadline", "window_until", "Deadline", "The number variable that holds the moment it closes.", "variable_reference").param("seconds", "0.5", "Seconds", "How long the player has.", "expression").param("prompt", "", "Prompt", "The label that shows the player which control to press while the window is open. Leave it off and the window opens silently.", PROMPT_SHOW_HINT).featured())
	descriptors.append(F.act("CloseInputWindow", "Close Input Window", "{open_flag} = false{prompt}", TIMED, "Close input window", "Shuts the window whether or not the player answered - put it after the graded branches so one press cannot count twice.").param("open_flag", "window_open", "Window flag", "The yes-no variable that says the window is open.", "variable_reference").param("prompt", "", "Prompt", "The label the prompt was put on, cleared as the window shuts. Leave it off and nothing is cleared.", PROMPT_CLEAR_HINT))
	descriptors.append(F.cond("PressedInInputWindow", "Pressed In The Window", "({open_flag} and event.is_action_pressed({action}) and {deadline} - %s > 0.0)" % NOW, TIMED, "{action} pressed in the window", "True when the control goes down while the window is still open, used inside an input event. Pair it with the grade to tell a perfect answer from a good one.").param("open_flag", "window_open", "Window flag", "The yes-no variable that says the window is open.", "variable_reference").param_built(F.make_param("action", "String", F.default_input_action(), "Control", "The control the window is waiting for.", "input_action", F.input_action_options())).param("deadline", "window_until", "Deadline", "The number variable that holds the moment it closes.", "variable_reference").featured())
	descriptors.append(F.cond("InputWindowMissed", "Input Window Missed", "({open_flag} and %s >= {deadline})" % NOW, TIMED, "Input window missed", "True the moment an open window runs out with nothing pressed - the punish, the failed lockpick, the dropped finisher.").param("open_flag", "window_open", "Window flag", "The yes-no variable that says the window is open.", "variable_reference").param("deadline", "window_until", "Deadline", "The number variable that holds the moment it closes.", "variable_reference"))
	descriptors.append(F.expr("InputWindowGrade", "Window Grade", "(\"perfect\" if {deadline} - %s <= {perfect} else \"good\")" % NOW, TIMED, "window grade", "\"perfect\" for an answer inside the cutoff at the end of the window, \"good\" for any other answer in time - the word to hand a hit reaction or a score.").param("deadline", "window_until", "Deadline", "The number variable that holds the moment it closes.", "variable_reference").param("perfect", "0.15", "Perfect cutoff", "Answers this close to the end count as perfect.", "expression").featured())
	descriptors.append(F.expr("InputWindowRemaining", "Window Time Left", "maxf({deadline} - %s, 0.0)" % NOW, TIMED, "window time left", "Seconds left before the window closes, never below zero - the fill of the shrinking ring a QTE draws.").param("deadline", "window_until", "Deadline", "The number variable that holds the moment it closes.", "variable_reference"))


## Mashing: N presses before a deadline, with the counter folded into the question rather than left
## as bookkeeping around it.
static func _mashing(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("StartMashCount", "Start Mash Count", "{counter} = 0\n{started} = %s" % NOW, TIMED, "Start mash count", "Resets the press count and stamps the moment the mash began, so the question below can be asked about this attempt only.").param("counter", "mash_count", "Counter", "The number variable counting the presses.", "variable_reference").param("started", "mash_started", "Started at", "The number variable holding when the mash began.", "variable_reference"))
	descriptors.append(F.act("CountMashPress", "Count Mash Press", "{counter} += 1", TIMED, "Count mash press", "Adds one press to the mash. Put it under the control's own pressed event.").param("counter", "mash_count", "Counter", "The number variable counting the presses.", "variable_reference"))
	descriptors.append(F.cond("MashedInTime", "Mashed In Time", "({counter} >= {count} and %s - {started} <= {seconds})" % NOW, TIMED, "Mashed x{count} in {seconds} s", "True once the presses arrive quickly enough - breaking free, cranking a winch, shaking off a grab.").param("counter", "mash_count", "Counter", "The number variable counting the presses.", "variable_reference").param("count", "12", "Presses", "How many presses it takes.", "expression").param("started", "mash_started", "Started at", "The number variable holding when the mash began.", "variable_reference").param("seconds", "3.0", "Within seconds", "How long they have to do it in.", "expression").featured())


## The prompt: the player has to know WHICH key, and the Input Map is the only thing that knows.
static func _prompts(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.expr("InputPromptGlyph", "Prompt For Control", "(InputMap.action_get_events({action})[0].as_text() if not InputMap.action_get_events({action}).is_empty() else \"\")", TIMED, "prompt for {action}", "The readable name of the key or button a control is bound to right now (\"Space\", \"A button\"). Follows a rebind, because it asks the Input Map every time.").param_built(F.make_param("action", "String", F.default_input_action(), "Control", "The control to name.", "input_action", F.input_action_options())).featured())
	descriptors.append(F.act("ShowInputPrompt", "Show Prompt", "{label}.text = InputMap.action_get_events({action})[0].as_text() if not InputMap.action_get_events({action}).is_empty() else \"\"", TIMED, "Show prompt for {action}", "Puts the control's real key or button on a label, so the prompt is right on every keyboard and after every rebind.").param("label", "$PromptLabel", "Label", "The label that shows the prompt.", "expression").param_built(F.make_param("action", "String", F.default_input_action(), "Control", "The control to show.", "input_action", F.input_action_options())).featured())


## Rhythm grading: the same words, measured against a beat instead of a deadline.
static func _rhythm(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.expr("BeatGrade", "Beat Grade", "(\"perfect\" if absf({pressed_at} - {beat_at}) <= {perfect} else \"good\")", TIMED, "beat grade", "Grades a press against the beat rather than against a window - the same two words, so one hit reaction serves both.").param_typed("String", "pressed_at", NOW, "Pressed at", "The moment the player pressed.", "expression").param("beat_at", "0.0", "Beat at", "The moment the beat lands.", "expression").param("perfect", "0.05", "Perfect cutoff", "Presses this close to the beat count as perfect.", "expression"))
	descriptors.append(F.expr("OffBeatBy", "Off The Beat By", "absf({pressed_at} - {beat_at})", TIMED, "off the beat by", "How far off the beat the press was, in seconds - the number a timing bar draws and a tuning screen shows.").param_typed("String", "pressed_at", NOW, "Pressed at", "The moment the player pressed.", "expression").param("beat_at", "0.0", "Beat at", "The moment the beat lands.", "expression"))


static func section_descriptions() -> Dictionary:
	return {
		TIMED: "Windows the player has a moment to answer, mashes, prompts and graded timing. Measured on the engine clock, which keeps running while the game is paused.",
	}
