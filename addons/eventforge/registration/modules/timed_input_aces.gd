# EventForge module - Timed inputs (X28): input windows, mashes, prompts and graded timing.
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
	_mashing(descriptors)
	_prompts(descriptors)
	_rhythm(descriptors)
	return descriptors


## The window itself: open it, ask about it, close it. The flag and the deadline are two ordinary
## variables the sheet declares, which is what lets an opened script read back as these rows.
static func _windows(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "OpenInputWindow", "Open Input Window", ACEDescriptor.ACEType.ACTION, "{open_flag} = true\n{deadline} = %s + {seconds}{prompt}" % NOW, "", [F.make_param("open_flag", "String", "window_open", "Window flag", "The yes-no variable that says the window is open.", "variable_reference"), F.make_param("deadline", "String", "window_until", "Deadline", "The number variable that holds the moment it closes.", "variable_reference"), F.make_param("seconds", "String", "0.5", "Seconds", "How long the player has.", "expression"), F.make_param("prompt", "String", "", "Prompt", "The label that shows the player which control to press while the window is open. Leave it off and the window opens silently.", PROMPT_SHOW_HINT)], TIMED, "Open input window for {seconds} s")
		.described("Opens a window the player has a moment to answer. Measured on the engine clock, which keeps running while the game is paused.").featured())
	descriptors.append(F.make_descriptor("Core", "CloseInputWindow", "Close Input Window", ACEDescriptor.ACEType.ACTION, "{open_flag} = false{prompt}", "", [F.make_param("open_flag", "String", "window_open", "Window flag", "The yes-no variable that says the window is open.", "variable_reference"), F.make_param("prompt", "String", "", "Prompt", "The label the prompt was put on, cleared as the window shuts. Leave it off and nothing is cleared.", PROMPT_CLEAR_HINT)], TIMED, "Close input window")
		.described("Shuts the window whether or not the player answered - put it after the graded branches so one press cannot count twice."))
	descriptors.append(F.make_descriptor("Core", "PressedInInputWindow", "Pressed In The Window", ACEDescriptor.ACEType.CONDITION, "({open_flag} and event.is_action_pressed({action}) and {deadline} - %s > 0.0)" % NOW, "", [F.make_param("open_flag", "String", "window_open", "Window flag", "The yes-no variable that says the window is open.", "variable_reference"), F.make_param("action", "String", F.default_input_action(), "Control", "The control the window is waiting for.", "input_action", F.input_action_options()), F.make_param("deadline", "String", "window_until", "Deadline", "The number variable that holds the moment it closes.", "variable_reference")], TIMED, "{action} pressed in the window")
		.described("True when the control goes down while the window is still open, used inside an input event. Pair it with the grade to tell a perfect answer from a good one.").featured())
	descriptors.append(F.make_descriptor("Core", "InputWindowMissed", "Input Window Missed", ACEDescriptor.ACEType.CONDITION, "({open_flag} and %s >= {deadline})" % NOW, "", [F.make_param("open_flag", "String", "window_open", "Window flag", "The yes-no variable that says the window is open.", "variable_reference"), F.make_param("deadline", "String", "window_until", "Deadline", "The number variable that holds the moment it closes.", "variable_reference")], TIMED, "Input window missed")
		.described("True the moment an open window runs out with nothing pressed - the punish, the failed lockpick, the dropped finisher."))
	descriptors.append(F.make_descriptor("Core", "InputWindowGrade", "Window Grade", ACEDescriptor.ACEType.EXPRESSION, "(\"perfect\" if {deadline} - %s <= {perfect} else \"good\")" % NOW, "", [F.make_param("deadline", "String", "window_until", "Deadline", "The number variable that holds the moment it closes.", "variable_reference"), F.make_param("perfect", "String", "0.15", "Perfect cutoff", "Answers this close to the end count as perfect.", "expression")], TIMED, "window grade")
		.described("\"perfect\" for an answer inside the cutoff at the end of the window, \"good\" for any other answer in time - the word to hand a hit reaction or a score.").featured())
	descriptors.append(F.make_descriptor("Core", "InputWindowRemaining", "Window Time Left", ACEDescriptor.ACEType.EXPRESSION, "maxf({deadline} - %s, 0.0)" % NOW, "", [F.make_param("deadline", "String", "window_until", "Deadline", "The number variable that holds the moment it closes.", "variable_reference")], TIMED, "window time left")
		.described("Seconds left before the window closes, never below zero - the fill of the shrinking ring a QTE draws."))


## Mashing: N presses before a deadline, with the counter folded into the question rather than left
## as bookkeeping around it.
static func _mashing(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "StartMashCount", "Start Mash Count", ACEDescriptor.ACEType.ACTION, "{counter} = 0\n{started} = %s" % NOW, "", [F.make_param("counter", "String", "mash_count", "Counter", "The number variable counting the presses.", "variable_reference"), F.make_param("started", "String", "mash_started", "Started at", "The number variable holding when the mash began.", "variable_reference")], TIMED, "Start mash count")
		.described("Resets the press count and stamps the moment the mash began, so the question below can be asked about this attempt only."))
	descriptors.append(F.make_descriptor("Core", "CountMashPress", "Count Mash Press", ACEDescriptor.ACEType.ACTION, "{counter} += 1", "", [F.make_param("counter", "String", "mash_count", "Counter", "The number variable counting the presses.", "variable_reference")], TIMED, "Count mash press")
		.described("Adds one press to the mash. Put it under the control's own pressed event."))
	descriptors.append(F.make_descriptor("Core", "MashedInTime", "Mashed In Time", ACEDescriptor.ACEType.CONDITION, "({counter} >= {count} and %s - {started} <= {seconds})" % NOW, "", [F.make_param("counter", "String", "mash_count", "Counter", "The number variable counting the presses.", "variable_reference"), F.make_param("count", "String", "12", "Presses", "How many presses it takes.", "expression"), F.make_param("started", "String", "mash_started", "Started at", "The number variable holding when the mash began.", "variable_reference"), F.make_param("seconds", "String", "3.0", "Within seconds", "How long they have to do it in.", "expression")], TIMED, "Mashed x{count} in {seconds} s")
		.described("True once the presses arrive quickly enough - breaking free, cranking a winch, shaking off a grab.").featured())


## The prompt: the player has to know WHICH key, and the Input Map is the only thing that knows.
static func _prompts(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "InputPromptGlyph", "Prompt For Control", ACEDescriptor.ACEType.EXPRESSION, "(InputMap.action_get_events({action})[0].as_text() if not InputMap.action_get_events({action}).is_empty() else \"\")", "", [F.make_param("action", "String", F.default_input_action(), "Control", "The control to name.", "input_action", F.input_action_options())], TIMED, "prompt for {action}")
		.described("The readable name of the key or button a control is bound to right now (\"Space\", \"A button\"). Follows a rebind, because it asks the Input Map every time.").featured())
	descriptors.append(F.make_descriptor("Core", "ShowInputPrompt", "Show Prompt", ACEDescriptor.ACEType.ACTION, "{label}.text = InputMap.action_get_events({action})[0].as_text() if not InputMap.action_get_events({action}).is_empty() else \"\"", "", [F.make_param("label", "String", "$PromptLabel", "Label", "The label that shows the prompt.", "expression"), F.make_param("action", "String", F.default_input_action(), "Control", "The control to show.", "input_action", F.input_action_options())], TIMED, "Show prompt for {action}")
		.described("Puts the control's real key or button on a label, so the prompt is right on every keyboard and after every rebind.").featured())


## Rhythm grading: the same words, measured against a beat instead of a deadline.
static func _rhythm(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "BeatGrade", "Beat Grade", ACEDescriptor.ACEType.EXPRESSION, "(\"perfect\" if absf({pressed_at} - {beat_at}) <= {perfect} else \"good\")", "", [F.make_param("pressed_at", "String", NOW, "Pressed at", "The moment the player pressed.", "expression"), F.make_param("beat_at", "String", "0.0", "Beat at", "The moment the beat lands.", "expression"), F.make_param("perfect", "String", "0.05", "Perfect cutoff", "Presses this close to the beat count as perfect.", "expression")], TIMED, "beat grade")
		.described("Grades a press against the beat rather than against a window - the same two words, so one hit reaction serves both."))
	descriptors.append(F.make_descriptor("Core", "OffBeatBy", "Off The Beat By", ACEDescriptor.ACEType.EXPRESSION, "absf({pressed_at} - {beat_at})", "", [F.make_param("pressed_at", "String", NOW, "Pressed at", "The moment the player pressed.", "expression"), F.make_param("beat_at", "String", "0.0", "Beat at", "The moment the beat lands.", "expression")], TIMED, "off the beat by")
		.described("How far off the beat the press was, in seconds - the number a timing bar draws and a tuning screen shows."))


static func section_descriptions() -> Dictionary:
	return {
		TIMED: "Windows the player has a moment to answer, mashes, prompts and graded timing. Measured on the engine clock, which keeps running while the game is paused.",
	}
