@tool
class_name EventSheetPatternReadings
extends RefCounted

# The SHEET-WIDE facts behind the pattern readings, and the one walk that claims them.
#
# A pattern is a shape several lines make together, so no single line can decide it. `cooldown -=
# delta` is arithmetic until somewhere else in the file asks whether `cooldown` has reached zero;
# `pool.pop_back()` is a list step until an `is_empty()` guard and an `instantiate()` fallback stand
# beside it. Those questions are answered ONCE per rebuild here, handed to the sentence grammar as
# ordinary context keys, and claimed in the pattern registry on the event that owns them.
#
# Everything here reads the sheet and answers questions. Nothing here edits a row, and nothing a
# reading decides may change what is emitted: the file is untouched and the byte round-trip cannot
# move. Every function is static and takes the sheet, so a test can pin a fact without a viewport.

## The words a per-frame delta is written in. Only these four: a variable that happens to shrink by
## some other number every tick is a subtraction, and calling it a countdown would be a guess.
const DELTA_WORDS: PackedStringArray = [
	"delta", "_delta", "get_process_delta_time()", "get_physics_process_delta_time()"
]

## The clamped spellings of the same countdown, as {call name: how the row says it stays above zero}.
const CLAMPED_COUNTDOWNS: Dictionary = {
	"max": "never below 0", "maxf": "never below 0", "move_toward": "never below 0"
}

## The list steps that TAKE something out of a pool, in the order a pool is usually drained.
const POOL_TAKE_METHODS: PackedStringArray = ["pop_back", "pop_front"]

## The steps a returned object is put to sleep with, and the one that puts it back. Any subset of the
## sleep steps in any order counts: which of them a project uses is a matter of what its objects do.
const POOL_SLEEP_METHODS: PackedStringArray = [
	"hide", "set_process", "set_physics_process", "set_process_input", "set_deferred"
]

## The step that returns the object to the list it came from.
const POOL_RETURN_METHODS: PackedStringArray = ["push_back", "push_front", "append"]


## Everything the sentence grammar needs to know about the patterns THIS sheet writes, merged into
## the row builder's sentence context once per rebuild:
##
##   "countdown_variables" {name: how it stays above zero, "" for a plain `-= delta`}
##   "pool_variables"      {name: true}   - the lists used as object pools
##
## Takes the file's lines rather than the sheet, so nothing here has to know what a sheet is: the
## caller already walks the rows once for the other fact maps and hands the same lines to all of them.
static func facts(lines: PackedStringArray) -> Dictionary:
	return {
		"countdown_variables": countdown_variables(lines),
		"pool_variables": pool_variables(lines)
	}


## S4. The numbers this file uses as countdowns: counted DOWN by a per-frame delta somewhere and
## compared against zero somewhere else. Both halves are required, so an ordinary subtraction stays a
## subtraction and a number merely compared to zero stays a comparison.
##
## The value is the note the Count down row shows: "" for a bare `x -= delta`, "never below 0" for
## the clamped spellings, which is the one thing those add and the one thing a reader wants told.
static func countdown_variables(lines: PackedStringArray) -> Dictionary:
	var counted: Dictionary = {}
	var compared: Dictionary = {}
	for line: String in lines:
		var text: String = line.strip_edges()
		if text.is_empty():
			continue
		var down: Dictionary = countdown_step(text)
		if not down.is_empty():
			var name_text: String = str(down.get("name", ""))
			# The clamped spelling wins when a file uses both: it is the stronger statement, and it is
			# the one whose note a reader needs.
			if not counted.has(name_text) or str(counted[name_text]).is_empty():
				counted[name_text] = str(down.get("note", ""))
		for zero_name: String in _zero_comparisons(text):
			compared[zero_name] = true
	var out: Dictionary = {}
	for name_text: String in counted:
		if compared.has(name_text):
			out[name_text] = counted[name_text]
	return out


## S4. The countdown step a line IS, as {name, note}, or {} when the line is not one. The three
## spellings a jam script writes:
##
##   cooldown -= delta                            {name: "cooldown", note: ""}
##   invincible_for = max(0.0, invincible_for - delta)   {name: ..., note: "never below 0"}
##   fuse = move_toward(fuse, 0, delta)                  {name: ..., note: "never below 0"}
static func countdown_step(line: String) -> Dictionary:
	var text: String = line.strip_edges()
	var minus_at: int = EventSheetSentence.top_level_index(text, " -= ")
	if minus_at > 0:
		var target: String = text.substr(0, minus_at).strip_edges()
		var amount: String = text.substr(minus_at + 4).strip_edges()
		if EventSheetSentence.is_identifier(target) and is_delta_value(amount):
			return {"name": target, "note": ""}
	var equals_at: int = EventSheetSentence.top_level_index(text, " = ")
	if equals_at <= 0:
		return {}
	var name_text: String = text.substr(0, equals_at).strip_edges()
	var value: String = text.substr(equals_at + 3).strip_edges()
	if not EventSheetSentence.is_identifier(name_text):
		return {}
	var call: Dictionary = EventSheetSentence.call_parts(value)
	if call.is_empty() or not str(call.get("target", "")).is_empty():
		return {}
	var head: String = str(call.get("method", ""))
	if not CLAMPED_COUNTDOWNS.has(head):
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if head == "move_toward":
		if args.size() != 3 or args[0].strip_edges() != name_text or not _is_zero(args[1]) \
				or not is_delta_value(args[2]):
			return {}
		return {"name": name_text, "note": str(CLAMPED_COUNTDOWNS[head])}
	if args.size() != 2 or not _is_zero(args[0]):
		return {}
	if not _is_delta_subtraction(args[1], name_text):
		return {}
	return {"name": name_text, "note": str(CLAMPED_COUNTDOWNS[head])}


## True when a value is the per-frame delta under one of its four names.
static func is_delta_value(value: String) -> bool:
	return DELTA_WORDS.has(value.strip_edges())


## True when a value is `<name> - <delta>`, the inner half of a clamped countdown.
static func _is_delta_subtraction(value: String, name_text: String) -> bool:
	var text: String = value.strip_edges()
	var minus_at: int = EventSheetSentence.top_level_index(text, " - ")
	if minus_at <= 0:
		return false
	return text.substr(0, minus_at).strip_edges() == name_text and is_delta_value(text.substr(minus_at + 3))


## True for the two spellings of zero a clamp is written with.
static func _is_zero(value: String) -> bool:
	var text: String = value.strip_edges()
	return text == "0" or text == "0.0"


## S4. Every identifier a line compares against zero - `cooldown <= 0`, `fuse > 0`, `hp == 0`. Only a
## bare identifier on the left counts: `stats["hp"] > 0` asks about a table entry, which is a
## different sentence with a different name.
static func _zero_comparisons(line: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for operator: String in [" <= ", " >= ", " == ", " < ", " > "]:
		var search_from: int = 0
		while true:
			var at: int = line.find(operator, search_from)
			if at < 0:
				break
			search_from = at + operator.length()
			if not _is_zero(_leading_number(line.substr(at + operator.length()))):
				continue
			var left: String = _trailing_identifier(line.substr(0, at))
			if not left.is_empty() and not found.has(left):
				found.append(left)
	return found


## The number a piece of text STARTS with, or "" when it starts with anything else. What the right
## side of `fuse <= 0:` is once the `if`'s colon and whatever follows the comparison are set aside.
static func _leading_number(text: String) -> String:
	var trimmed: String = text.strip_edges()
	var length: int = 0
	while length < trimmed.length() and (trimmed[length] == "." or (trimmed[length] >= "0" and trimmed[length] <= "9")):
		length += 1
	return trimmed.substr(0, length)


## The identifier a piece of text ENDS in, or "" when it ends in anything else (a call, an index, a
## member read). What decides whether a comparison is about a plain variable of this file.
static func _trailing_identifier(text: String) -> String:
	var trimmed: String = text.strip_edges()
	var start: int = trimmed.length()
	while start > 0 and _is_word_character(trimmed[start - 1]):
		start -= 1
	if start >= trimmed.length():
		return ""
	if start > 0 and (trimmed[start - 1] == "." or trimmed[start - 1] == "\"" or trimmed[start - 1] == "'"):
		return ""
	var word: String = trimmed.substr(start)
	return word if EventSheetSentence.is_identifier(word) else ""


static func _is_word_character(character: String) -> bool:
	return character == "_" or character.is_valid_identifier() or (character >= "0" and character <= "9")


## S2. The lists this file uses as object pools: drained through `pop_back()` / `pop_front()` behind
## an `is_empty()` guard with an `instantiate()` fallback, and refilled with `push_back()`. The guard
## is what makes it a pool rather than a queue, so it is required.
static func pool_variables(lines: PackedStringArray) -> Dictionary:
	var pools: Dictionary = {}
	for line: String in lines:
		var taken: Dictionary = pool_take_parts(line.strip_edges())
		if not taken.is_empty():
			pools[str(taken.get("pool", ""))] = true
	return pools


## S2. The pooled-Create line, as {pool, scene, alias} or {} when the line is not one:
##
##   var b = pool.pop_back() if not pool.is_empty() else BULLET.instantiate()
##   var b = BULLET.instantiate() if pool.is_empty() else pool.pop_back()
##
## Both orders of the ternary are read, because both are written. The declaration keyword is
## optional so a plain re-assignment to an existing variable reads the same.
static func pool_take_parts(line: String) -> Dictionary:
	var text: String = line.strip_edges()
	for keyword: String in ["var ", "const "]:
		if text.begins_with(keyword):
			text = text.substr(keyword.length()).strip_edges()
	var alias: String = ""
	var value: String = ""
	for separator: String in [" := ", " = "]:
		var at: int = EventSheetSentence.top_level_index(text, separator)
		if at <= 0:
			continue
		alias = text.substr(0, at).strip_edges()
		var colon_at: int = alias.find(":")
		if colon_at >= 0:
			alias = alias.substr(0, colon_at).strip_edges()
		value = text.substr(at + separator.length()).strip_edges()
		break
	if alias.is_empty() or value.is_empty() or not EventSheetSentence.is_identifier(alias):
		return {}
	var branches: Array = EventSheetSentence.value_branches(value)
	if branches.size() != 2:
		return {}
	var when_true: String = str((branches[0] as Dictionary).get("code", "")).strip_edges()
	var test: String = str((branches[0] as Dictionary).get("condition", "")).strip_edges()
	var when_false: String = str((branches[1] as Dictionary).get("code", "")).strip_edges()
	if test.is_empty():
		return {}
	var negated: bool = test.begins_with("not ")
	if negated:
		test = test.substr(4).strip_edges()
	var pool_name: String = _empty_test_pool(test)
	if pool_name.is_empty():
		return {}
	# `not pool.is_empty()` takes from the pool when the test holds; a bare `pool.is_empty()` makes a
	# new one instead, so the two halves swap.
	var take_text: String = when_true if negated else when_false
	var make_text: String = when_false if negated else when_true
	if _pool_take_of(take_text) != pool_name:
		return {}
	var scene: String = _instantiated_source(make_text)
	if scene.is_empty():
		return {}
	return {"pool": pool_name, "scene": scene, "alias": alias}


## The list a `pool.is_empty()` asks about, or "" for anything else.
static func _empty_test_pool(text: String) -> String:
	if not text.ends_with(".is_empty()"):
		return ""
	var name_text: String = text.substr(0, text.length() - 11).strip_edges()
	return name_text if EventSheetSentence.is_identifier(name_text) else ""


## The list a `pool.pop_back()` drains, or "" for anything else.
static func _pool_take_of(text: String) -> String:
	for method: String in POOL_TAKE_METHODS:
		var suffix: String = ".%s()" % method
		if not text.ends_with(suffix):
			continue
		var name_text: String = text.substr(0, text.length() - suffix.length()).strip_edges()
		return name_text if EventSheetSentence.is_identifier(name_text) else ""
	return ""


## The scene a `BULLET.instantiate()` makes, or "" for anything else.
static func _instantiated_source(text: String) -> String:
	if not text.ends_with(".instantiate()"):
		return ""
	var source: String = text.substr(0, text.length() - 14).strip_edges()
	return source if EventSheetSentence.is_identifier(source) else ""


## S2. The step a line is in a Return-to-pool run, as {kind, object, pool} or {}:
##   "sleep"  b.hide() / b.set_process(false) / b.set_physics_process(false)
##   "return" pool.push_back(b)
static func pool_return_step(line: String, pools: Dictionary) -> Dictionary:
	var text: String = line.strip_edges()
	var call: Dictionary = EventSheetSentence.call_parts(text)
	if call.is_empty():
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	var receiver: String = str(call.get("target", "")).strip_edges()
	var method: String = str(call.get("method", "")).strip_edges()
	if not EventSheetSentence.is_identifier(receiver):
		return {}
	if POOL_RETURN_METHODS.has(method) and args.size() == 1 and pools.has(receiver):
		return {"kind": "return", "object": args[0].strip_edges(), "pool": receiver}
	if not POOL_SLEEP_METHODS.has(method):
		return {}
	if method == "hide" and args.is_empty():
		return {"kind": "sleep", "object": receiver, "pool": ""}
	if method == "set_deferred" and args.size() == 2:
		return {"kind": "sleep", "object": receiver, "pool": ""}
	if args.size() == 1 and args[0].strip_edges() == "false":
		return {"kind": "sleep", "object": receiver, "pool": ""}
	return {}
