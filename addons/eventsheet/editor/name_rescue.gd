# EventSheet - EventSheetNameRescue: an unknown name is an offer, never a dead end.
#
# Three small, pure answers that every "this name does not exist yet" surface shares:
#
#   near_names    the TYPO GUARD - the known names within two edits of what was typed, best first.
#                 Offered BEFORE any create offer, everywhere, so creation never mints a typo twin
#                 (a field saying "mx_hp" is offered max_hp first, and "declare mx_hp" only after).
#   guess_type_name  what type a brand-new name probably is, read from HOW the expression uses it -
#                 so the declaration dialog opens pre-filled instead of defaulting blind.
#   suggested_key    the reverse door for Input Map controls: "add jump, bound to Space?" - the
#                 handful of control names whose everyday binding is worth offering outright.
#
# Static and pure over strings, so every rule is pinned headlessly.
@tool
class_name EventSheetNameRescue
extends RefCounted

## Only names within this many edits are "near" - farther is a different word, and suggesting it
## would be noise wearing a fix's clothes.
const MAX_EDIT_DISTANCE := 2

## The everyday bindings offered when a control of this name is created from a row. An OVERRIDE
## list, not a mapping the code derives: these are conventions, and a name not listed here is
## simply created unbound, exactly as before.
const EVERYDAY_KEYS: Dictionary = {
	"jump": KEY_SPACE,
	"dash": KEY_SHIFT,
	"sprint": KEY_SHIFT,
	"run": KEY_SHIFT,
	"crouch": KEY_CTRL,
	"interact": KEY_E,
	"use": KEY_E,
	"pause": KEY_ESCAPE,
	"inventory": KEY_I,
	"map": KEY_M,
	"reload": KEY_R,
}


## The known names within two edits of `unknown`, nearest first (ties keep the caller's order).
## Empty when nothing is close enough - a caller then goes straight to its create offer.
static func near_names(unknown: String, known: PackedStringArray, limit: int = 3) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if unknown.strip_edges().length() < 2:
		return out
	var scored: Array[Dictionary] = []
	var lowered: String = unknown.to_lower()
	for index: int in range(known.size()):
		var candidate: String = known[index]
		if candidate.is_empty() or candidate == unknown:
			continue
		var distance: int = edit_distance(lowered, candidate.to_lower())
		if distance <= MAX_EDIT_DISTANCE:
			scored.append({"distance": distance, "index": index, "name": candidate})
	scored.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left["distance"]) != int(right["distance"]):
			return int(left["distance"]) < int(right["distance"])
		return int(left["index"]) < int(right["index"]))
	for entry: Dictionary in scored:
		out.append(str(entry["name"]))
		if out.size() >= limit:
			break
	return out


## What type a new name probably is, read from how the expression already uses it: the literal it
## is compared or combined with says more than any default. Answers a type NAME the declaration
## dialog speaks ("int" / "float" / "String" / "bool"), and "int" when the expression says nothing.
static func guess_type_name(expression: String, unknown: String) -> String:
	if unknown.strip_edges().is_empty():
		return "int"
	var position: int = expression.find(unknown)
	if position < 0:
		return "int"
	# The neighbourhood the name is used in - the operand on either side is what types it.
	var window: String = expression.substr(maxi(position - 24, 0),
		unknown.length() + 48).replace(unknown, " ")
	if RegEx.create_from_string("\"[^\"]*\"|'[^']*'").search(window) != null:
		return "String"
	if RegEx.create_from_string("\\b(true|false)\\b").search(window) != null:
		return "bool"
	if RegEx.create_from_string("\\d+\\.\\d+").search(window) != null:
		return "float"
	return "int"


## The everyday key for a new Input Map control, or KEY_NONE for a name convention has nothing to
## say about. Matched on the name's words so "player_jump" still means jump.
static func suggested_key(action_name: String) -> Key:
	var lowered: String = action_name.strip_edges().to_lower()
	if EVERYDAY_KEYS.has(lowered):
		return EVERYDAY_KEYS[lowered]
	for word: String in lowered.split("_"):
		if EVERYDAY_KEYS.has(word):
			return EVERYDAY_KEYS[word]
	return KEY_NONE


## Levenshtein distance over short identifier strings - shared here so every surface that says
## "near" means the same thing by it.
static func edit_distance(a: String, b: String) -> int:
	var n: int = a.length()
	var m: int = b.length()
	if n == 0:
		return m
	if m == 0:
		return n
	var previous: Array[int] = []
	for j: int in range(m + 1):
		previous.append(j)
	for i: int in range(1, n + 1):
		var current: Array[int] = [i]
		current.resize(m + 1)
		for j: int in range(1, m + 1):
			var cost: int = 0 if a[i - 1] == b[j - 1] else 1
			current[j] = min(min(previous[j] + 1, current[j - 1] + 1), previous[j - 1] + cost)
		previous = current
	return previous[m]
