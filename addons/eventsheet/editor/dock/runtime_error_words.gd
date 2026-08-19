# EventSheet - EventSheetRuntimeErrorWords: a runtime error, re-said in the sheet's words.
#
# The engine reports a crash in the vocabulary of the thing that crashed: "Attempt to call function
# 'hit' in base 'null instance'". Every word of that is true and none of it is the reader's. The
# sheet already knows the other half - the source map says which row that line came from, and the
# row's own reading says what it was trying to do - so the same failure can be said once more, this
# time as the row said it:
#
#   player.gd · event 12 · Enemy ▸ Call Hit: target is empty (nothing was picked before this action)
#
# Three rules this file exists to keep:
#
#   1. The ORIGINAL IS NEVER HIDDEN. Godot's message is what a search engine, an issue tracker and
#      every other Godot user speak; a translation that swallowed it would strand the reader the
#      moment they needed help from outside this editor. It is one click away, always.
#   2. NOTHING IS INVENTED. A message this table does not recognise is passed through unchanged
#      rather than guessed at, and `translated` says which happened, so a caller can tell "we know
#      what this is" from "here is what Godot said".
#   3. The WHERE comes from the reading, never from a line number. A line number answers a question
#      about the generated file; the reader is looking at rows.
#
# Everything is static and pure over its inputs, so the suite pins the words without a debug run.
@tool
class_name EventSheetRuntimeErrorWords
extends RefCounted

## The failures worth re-saying, most specific needle first. Each entry is
## {key, needles, said, why, explain}:
##   key      the stable name of the cause - what a test and a caller address it by
##   needles  substrings of the engine's message, matched case-insensitively
##   said     the same failure in the sheet's words, as the row would have said it
##   why      the reason in one parenthesis, aimed at what the author did rather than at the engine
##   explain  the Manual page that answers the question the failure raises
##
## Frozen the way ace ids are: a key that has shipped is what callers and tests address, so a cause
## is deprecated rather than renamed.
const CAUSES: Array[Dictionary] = [
	{
		"key": "null_instance",
		"needles": ["in base 'null instance'", "on base: 'null instance'", "base 'Nil'",
			"null instance"],
		"said": "target is empty",
		"why": "nothing was picked before this action",
		"explain": "reference:glossary/pick",
	},
	{
		"key": "out_of_bounds",
		"needles": ["out of bounds", "index out of bounds", "out of size"],
		"said": "there is no item at that position",
		"why": "the list is shorter than the number this row asked for",
		"explain": "guide:GUIDE-WORKING-WITH-LISTS",
	},
	{
		"key": "nonexistent_function",
		"needles": ["nonexistent function", "invalid call. nonexistent function",
			"function not found"],
		"said": "this object has no such action",
		"why": "the object here is not the kind of object the row is about",
		"explain": "reference:glossary/object-type",
	},
	{
		"key": "division_by_zero",
		"needles": ["division by zero", "divide by zero", "modulo by zero"],
		"said": "divided by zero",
		"why": "the value this row divided by was 0 at that moment",
		"explain": "guide:GUIDE-WORKING-WITH-VALUES",
	},
	{
		"key": "invalid_index",
		"needles": ["invalid index", "invalid access to property or key",
			"invalid get index", "invalid set index", "nonexistent property"],
		"said": "there is no such name on this object",
		"why": "the row asked for something this object does not have",
		"explain": "reference:glossary/object-type",
	},
]

## What the button that opens Godot's own message says, and what it opens onto. Named here so the
## strip, the Output line and the suite all spell it once.
const GODOT_WORDS_LABEL := "Godot's words"

## The lead the Output panel line carries, so a reader scanning a busy Output can see at a glance
## that this line is the sheet talking about a row rather than the engine talking about a file.
const OUTPUT_LEAD := "Event sheet"


## One engine message -> {translated, key, said, why, explain, original}. `translated` is false for
## a message this table does not know, and then `said` IS the original: an unrecognised failure is
## repeated, never paraphrased.
static func translate(message: String) -> Dictionary:
	var original: String = message.strip_edges()
	var haystack: String = original.to_lower()
	for cause: Dictionary in CAUSES:
		for needle: Variant in (cause.get("needles", []) as Array):
			if not haystack.contains(str(needle).to_lower()):
				continue
			return {
				"translated": true,
				"key": str(cause.get("key", "")),
				"said": str(cause.get("said", "")),
				"why": str(cause.get("why", "")),
				"explain": str(cause.get("explain", "")),
				"original": original,
			}
	return {
		"translated": false,
		"key": "",
		"said": original,
		"why": "",
		"explain": "",
		"original": original,
	}


## The banner sentence: "<file> · event <n> · <reading>: <said> (<why>)". Every part is optional
## except the said half - a failure whose row could not be resolved still gets a sentence, it just
## has less of an address in front of it.
##
## `reading` is the row read back as one phrase (the same phrase a collapsed block shows), so the
## address is always the words on screen and never a line number.
static func sentence(script_path: String, event_number: int, reading: String,
		verdict: Dictionary) -> String:
	var address: PackedStringArray = PackedStringArray()
	var file_name: String = script_path.strip_edges().get_file()
	if not file_name.is_empty():
		address.append(file_name)
	if event_number > 0:
		address.append(EventSheetL10n.translate("event %d") % event_number)
	var row_reading: String = reading.strip_edges()
	if not row_reading.is_empty():
		address.append(row_reading)
	var said: String = str(verdict.get("said", "")).strip_edges()
	var why: String = str(verdict.get("why", "")).strip_edges()
	var tail: String = said if why.is_empty() else "%s (%s)" % [said, why]
	if address.is_empty():
		return tail
	return "%s: %s" % [" · ".join(address), tail]


## The whole report a caller acts on, in one call: the sentence, whether anything was recognised,
## the Manual page Explain opens, and Godot's own message kept beside it rather than behind it.
static func report(message: String, script_path: String, event_number: int,
		reading: String) -> Dictionary:
	var verdict: Dictionary = translate(message)
	verdict["sentence"] = sentence(script_path, event_number, reading, verdict)
	verdict["script_path"] = script_path.strip_edges()
	verdict["event_number"] = event_number
	verdict["reading"] = reading.strip_edges()
	return verdict


## The Output-panel line. Two lines on purpose: the sheet's sentence, then Godot's own words
## indented under it, so the reader who needs the engine's phrasing (to search for it, to paste it
## into an issue) never has to go and find it again.
static func output_lines(verdict: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s: %s" % [OUTPUT_LEAD, str(verdict.get("sentence", ""))])
	var original: String = str(verdict.get("original", "")).strip_edges()
	if not original.is_empty() and bool(verdict.get("translated", false)):
		lines.append("  %s: %s" % [GODOT_WORDS_LABEL, original])
	return lines


## Does this failure have a Manual page to open? False when the message was not recognised, which
## is exactly when an Explain button would be promising an answer nobody wrote.
static func can_explain(verdict: Dictionary) -> bool:
	return not str(verdict.get("explain", "")).strip_edges().is_empty()
