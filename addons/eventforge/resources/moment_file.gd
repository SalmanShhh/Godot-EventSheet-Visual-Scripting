# Godot EventSheets - the bridge between the two written-down homes of a moment.
#
# A moment can be written twice over: as a FILE (a resource holding a list of steps, each one a
# word plus how much, which extra word and how long) and as a BLOCK of rows in a sheet. This file
# is the one place that turns either into the other, so "Save Moment As File" and "Open Moment
# File As Block" are the same conversion read in two directions and cannot drift apart.
#
# THE ONE STATEMENT A STEP IS. A file's step is played by the Juice pack's `moment_step` row, so a
# block step that stands for one is a single statement calling it:
#
#     $JuiceBehavior.moment_step("shake", 0.4, "", 0.0, strength)
#
# That is why the round trip is exact rather than approximate: the block writes the call, the file
# holds the four values the call carries, and reading either back gives the other. The last
# argument is the coroutine's own `strength`, which is what makes a saved file scale the way the
# block it came from did.
#
# WHAT DOES NOT SURVIVE, said out loud rather than silently dropped. A file holds no timing - every
# step in it plays at once - and it holds no step that is not one of those ten words. So a block
# with a Then, a Hold or a Loop Back, or a step that spawns something or emits a signal, cannot be
# a file: `steps_of` returns those steps in `left_behind`, by their reading, for the door to show
# before anything is written. Nothing here writes a file or opens a dialog; it is arithmetic and
# text, which is what lets the suite pin it without an editor.
@tool
class_name EventSheetMomentFile
extends RefCounted

## The pack row a file's step is played by, and the whole vocabulary this bridge understands.
const STEP_CALL: String = "moment_step("

## The receiver a converted step is written against - the Juice behaviour on the same node, in the
## scene-unique spelling the pack's own rows compile to.
const DEFAULT_RECEIVER: String = "$JuiceBehavior"

## The block coroutine's strength parameter, which every converted step's last argument is, so a
## file saved out of a block goes on scaling with the strength the block was played at.
const STRENGTH_ARGUMENT: String = "strength"

## The keys one step of a file carries, in the order a file writes them.
const STEP_KEYS: PackedStringArray = ["amount", "effect", "seconds", "verb"]


## One step of a moment file as the statement that plays it. The one place the call is spelled.
static func statement_for(step: Dictionary, receiver: String = DEFAULT_RECEIVER) -> String:
	return "%s.%s%s, %s, %s, %s, %s)" % [
		receiver, STEP_CALL,
		_quoted(str(step.get("verb", ""))),
		_number(float(step.get("amount", 0.0))),
		_quoted(str(step.get("effect", ""))),
		_number(float(step.get("seconds", 0.0))),
		STRENGTH_ARGUMENT
	]


## The step one statement stands for, or an empty dictionary when the line is anything else. The
## reverse of statement_for, and deliberately strict: a call whose strength is not the block's own
## parameter, or whose words are not plain quoted text, is not a step a file can hold.
static func step_of_statement(line: String) -> Dictionary:
	var code: String = line.strip_edges()
	var opened: int = code.find(STEP_CALL)
	if opened < 0 or not code.ends_with(")"):
		return {}
	var head: String = code.substr(0, opened)
	if not (head.is_empty() or head.ends_with(".")):
		return {}
	var inside: String = code.substr(opened + STEP_CALL.length(), code.length() - opened - STEP_CALL.length() - 1)
	var parts: PackedStringArray = EventSheetBlockRegistry.split_params_top_level(inside)
	if parts.size() != 5:
		return {}
	if parts[4].strip_edges() != STRENGTH_ARGUMENT:
		return {}
	var verb: String = _unquoted(parts[0])
	var effect: String = _unquoted(parts[2])
	if verb.is_empty():
		return {}
	return {
		"amount": parts[1].strip_edges().to_float(),
		"effect": effect,
		"seconds": parts[3].strip_edges().to_float(),
		"verb": verb
	}


## A block as the steps a file would hold, plus the steps no file can hold.
##
## Returns {"steps": Array[Dictionary], "left_behind": PackedStringArray}. A step is carried when it
## starts with the moment (no Then, no Hold, no Loop Back - a file plays everything at once) and its
## one action is a `moment_step` call. Everything else is named in `left_behind` so the door can say
## what would be lost instead of losing it.
static func steps_of(block: MomentBlockRow) -> Dictionary:
	var steps: Array[Dictionary] = []
	var left_behind: PackedStringArray = PackedStringArray()
	if block == null:
		return {"steps": steps, "left_behind": left_behind}
	for entry: Dictionary in block.skeleton():
		var step: MomentStepRow = entry.get("step") as MomentStepRow
		if step == null:
			continue
		if not str(entry.get("wait", "")).is_empty() or bool(entry.get("closes_loop", false)) \
				or bool(entry.get("opens_loop", false)):
			left_behind.append(step.reading())
			continue
		var carried: Dictionary = _only_step_call(step)
		if carried.is_empty():
			left_behind.append(step.reading())
			continue
		steps.append(carried)
	return {"steps": steps, "left_behind": left_behind}


## A file's steps as a block: one step per entry, every one of them at the start, because that is
## what a file means. `moment_name` becomes the block's name and so the coroutine's.
static func block_of(moment_name: String, steps: Array,
		receiver: String = DEFAULT_RECEIVER) -> MomentBlockRow:
	var block: MomentBlockRow = MomentBlockRow.new()
	block.moment_name = _identifier(moment_name)
	for entry: Variant in steps:
		if not (entry is Dictionary):
			continue
		var step: MomentStepRow = MomentStepRow.new()
		var action: RawCodeRow = RawCodeRow.new()
		action.code = statement_for(entry as Dictionary, receiver)
		step.actions.append(action)
		block.steps.append(step)
	return block


## The step a block step stands for when its ONE action is a moment step call, else empty.
static func _only_step_call(step: MomentStepRow) -> Dictionary:
	if step == null or step.actions.size() != 1:
		return {}
	var raw: RawCodeRow = step.actions[0] as RawCodeRow
	if raw == null:
		return {}
	return step_of_statement(raw.code)


## A name as the identifier a coroutine can be called, so a file called "Boss Hit.tres" opens as a
## block that compiles. An empty answer is a name the block will refuse, which is what the door
## reports.
static func _identifier(word: String) -> String:
	var cleaned: String = ""
	var trimmed: String = word.strip_edges()
	for index: int in range(trimmed.length()):
		var character: String = trimmed[index]
		if character == " " or character == "-":
			cleaned += "_"
		elif character.is_valid_identifier():
			cleaned += character
		elif cleaned.is_empty():
			continue
		elif ("_" + character).is_valid_identifier():
			cleaned += character
	return cleaned


## A word as a GDScript string literal. A word carrying a quote of its own is refused rather than
## escaped: the ten step words and the post-effect names have none, and a silently mangled one
## would be a statement nobody wrote.
static func _quoted(word: String) -> String:
	if word.contains("\"") or word.contains("\\"):
		return "\"\""
	return "\"%s\"" % word


## The word inside a string literal, or "" when the argument is not one.
static func _unquoted(argument: String) -> String:
	var text: String = argument.strip_edges()
	if text.length() < 2 or not text.begins_with("\"") or not text.ends_with("\""):
		return ""
	return text.substr(1, text.length() - 2)


## A number as the emitted code spells it: a whole number keeps one decimal place so it reads as
## the float it is, and everything else keeps the digits it was given without a trailing tail.
static func _number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%.1f" % value
	return String.num(value, 4).rstrip("0")
