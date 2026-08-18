@tool
class_name EventSheetSentence
extends RefCounted

# Event-sheet row grammar for statements that have no ACE of their own.
#
# ONE producer, TWO callers. A row that says `host.velocity.x = speed` must read the same whether
# the user typed that line in a .gd file (a RawCodeRow the viewport lifts to a sentence) or dropped
# the matching ACE from the picker (an ACEAction whose display template the viewport substitutes).
# Both paths land here, so the two readings cannot drift apart: the viewport's raw path calls
# `statement()` / `condition()`, and its ACE path calls the same helpers with the row's params.
#
# The shape of every reading is the sheet's own word order - OBJECT, then VERB, then the values:
#
#     _jumps_left -= 1                 System ▸ Subtract 1 from _jumps_left
#     host.velocity.x = speed          host   ▸ Set velocity.x to speed
#     host.call_deferred("queue_free") host   ▸ Destroy (at end of frame)
#     jumped.emit()                    FPSController ▸ Signal On Jumped
#     if host == null:                 host   ▸ does not exist
#
# The object is returned SEPARATELY from the sentence (`{"object": "host"}`) because the canvas
# draws it in its own column, exactly as an ACE row's object label is drawn.
#
# Everything here is DISPLAY ONLY. No caller may use a result to decide what to emit: the row the
# sentence describes is untouched, so the byte round-trip and the compiled GDScript cannot move.
# Every function is static and pure (the one impurity is the translation catalog, which is a
# process-wide static too), so the whole grammar is unit-testable without a viewport.
#
# Strictness is the point: a sentence that is ALMOST right is worse than the code it replaced.
# A shape is claimed only when it is recognised exactly; anything else returns {} and the row keeps
# reading as the plain statement it is.

## The object a receiver-less statement belongs to, matching the picker's own word for Core rows.
const OBJECT_SYSTEM := "System"
## Input rows belong to the sheet's Keyboard object, not to System.
const OBJECT_KEYBOARD := "Keyboard"
## N9. An analogue read is a Gamepad question, and a button is a Mouse one. Same split the object
## bar draws, so a reader coming from another event-sheet tool looks for the row under the object
## they already associate with it.
const OBJECT_GAMEPAD := "Gamepad"
const OBJECT_MOUSE := "Mouse"
## N7. Saving, files and JSON belong to three objects of their own - Local Storage, JSON and AJAX.
## Hand-written ConfigFile / JSON / FileAccess code reads under the same three names, so the rows a
## reader already recognises are the rows they see here.
const OBJECT_STORAGE := "Storage"
const OBJECT_JSON := "JSON"
const OBJECT_FILE := "File"

## Godot call shapes that have one settled sentence. Curated on purpose: an entry is added
## only when one shape maps to exactly one reading. `{0}`.. are the call's arguments in order.
const EXPRESSION_IDIOMS: Dictionary = {
	"maxf": "max({0}, {1})",
	"maxi": "max({0}, {1})",
	"max": "max({0}, {1})",
	"minf": "min({0}, {1})",
	"mini": "min({0}, {1})",
	"min": "min({0}, {1})",
	"abs": "|{0}|",
	"absf": "|{0}|",
	"absi": "|{0}|",
	"deg_to_rad": "{0}°",
	"is_zero_approx": "{0} ≈ 0",
	"is_equal_approx": "{0} ≈ {1}",
	# M32. Each of these has exactly one the sheet sentence, and each matches the vocabulary's own
	# wording for the same thing, so a typed line and the picked ACE read alike.
	"randi_range": "random whole number {0} to {1}",
	"randf_range": "random number {0} to {1}",
	"rad_to_deg": "{0} in degrees",
	"snapped": "{0} snapped to {1}",
	"snappedf": "{0} snapped to {1}",
	"snappedi": "{0} snapped to {1}",
	"len": "{0}' count",
	# N6. A sheet spells a power with the caret a user types into an expression field.
	"pow": "{0} ^ {1}"
}

## M32. Idioms whose reading needs the RECEIVER as well as the arguments, keyed "receiver.method" for
## the ones that only make sense on one object (`Input.get_vector`) and bare for the ones that read the
## same on anything (`arr.size()`).
## The input-vector wording is the published Input Vector ACE's own sentence rather than the mockup's
## "direction from", so a typed `Input.get_vector(...)` and the picked row read the same words.
## N6 adds the sheet's own SYSTEM EXPRESSION names to the same table. These are deliberately NOT
## translated: `uppercase`, `left`, `mid`, `len`, `find`, `replace`, `trim` and `split` are the names a
## migrating user TYPES into an expression field, so they are identifiers rather than prose - exactly
## like `max` and `min` above. The few word-shaped ones (`starts with`, `contains`) follow the same
## rule the table already set with `direction from ... to ...`.
const RECEIVER_IDIOMS: Dictionary = {
	"size": "{receiver}' count",
	"direction_to": "direction from {receiver} to {0}",
	"Input.get_vector": "input vector {0}/{1}/{2}/{3}",
	"Input.get_axis": "axis {0}/{1}",
	# N6 - text in the sheet's system-expression names
	"to_upper": "uppercase({receiver})",
	"to_lower": "lowercase({receiver})",
	"length": "len({receiver})",
	"strip_edges": "trim({receiver})",
	"right": "right({receiver}, {0})",
	"find": "find({receiver}, {0})",
	"replace": "replace({receiver}, {0}, {1})",
	"split": "split({receiver}, {0})",
	"begins_with": "{receiver} starts with {0}",
	"ends_with": "{receiver} ends with {0}",
	"contains": "{receiver} contains {0}",
	# N7 - the JSON object's two verbs, and a file handle's whole contents
	"JSON.parse_string": "parsed {0}",
	"JSON.stringify": "{0} as text",
	"get_as_text": "{receiver}'s contents",
	# N9 - the analogue reads belong to the pad
	"Input.get_action_strength": "strength of {0}",
	"Input.get_action_raw_strength": "raw strength of {0}"
}

## M25. GDScript's global functions - the ones a receiver-less call may belong to. A call to anything
## NOT in this list is a call on the script's own object, so the two readings can never be confused.
## Curated rather than reflected because ClassDB has no entry for @GDScript / @GlobalScope.
const GLOBAL_FUNCTIONS: PackedStringArray = [
	"print", "printerr", "print_debug", "print_rich", "printraw", "prints", "printt",
	"push_error", "push_warning", "str", "int", "float", "bool", "len", "range", "typeof",
	"randi", "randf", "randi_range", "randf_range", "randfn", "randomize", "seed", "rand_from_seed",
	"abs", "absf", "absi", "sign", "signf", "signi", "min", "minf", "mini", "max", "maxf", "maxi",
	"clamp", "clampf", "clampi", "round", "roundf", "roundi", "floor", "floorf", "floori",
	"ceil", "ceilf", "ceili", "sqrt", "pow", "exp", "log", "fmod", "fposmod", "posmod",
	"sin", "cos", "tan", "asin", "acos", "atan", "atan2", "sinh", "cosh", "tanh",
	"lerp", "lerpf", "lerp_angle", "inverse_lerp", "remap", "move_toward", "rotate_toward",
	"deg_to_rad", "rad_to_deg", "snapped", "snappedf", "snappedi", "step_decimals",
	"wrap", "wrapf", "wrapi", "nearest_po2", "pingpong", "ease", "smoothstep", "cubic_interpolate",
	"is_equal_approx", "is_zero_approx", "is_nan", "is_inf", "is_finite", "is_instance_valid",
	"is_instance_id_valid", "instance_from_id", "hash", "weakref", "load", "preload",
	"var_to_str", "str_to_var", "bytes_to_var", "var_to_bytes", "type_convert", "type_string",
	"error_string", "rid_allocate_id", "rid_from_int64", "Color8"
]

## Vector constructors read as the plain tuple they build - the type word is in the row's chip, never
## in the middle of a sentence.
const VECTOR_CONSTRUCTORS: PackedStringArray = ["Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i"]

## Which kind of published verb a body belongs to, so a `return` reads as the outcome it is.
enum VerbKind {
	## An ordinary action body (or plain script): `return` means "stop here".
	ACTION,
	## A published condition: the verb answers yes or no.
	CONDITION,
	## A published expression: the verb gives a value back.
	EXPRESSION
}


## The reading of ONE GDScript statement, or {} when no shape is recognised.
##
## `context` may carry:
##   "self_object"  - the object a receiver-less statement belongs to (default "System")
##   "owner"        - the class that owns the sheet's signals, for `sig.emit()` rows
##   "signals"      - {signal_name: published trigger name}, from the sheet's @ace_name declarations
##   "verb_kind"    - a VerbKind, deciding how a `return` reads
##
## Returns {"indent", "object", "segments"} - each segment {text, tone} with tone
## "plain" | "name" | "value" - plus "kind": "declaration" and {"type_word", "name", "value"} when
## the line declares a local variable, which the canvas draws as a declaration row rather than a
## sentence.
static func statement(code: String, context: Dictionary = {}) -> Dictionary:
	if code.contains("\n"):
		return {}
	var indent: int = code.length() - code.lstrip("\t").length()
	var text: String = code.strip_edges()
	if text.is_empty() or text.begins_with("#"):
		return {}
	var keyword: String = leading_word(text)
	if keyword == "await":
		return _with_indent(_await_statement(text, context), indent)
	# M33. The sheet's own words for the two loop steps. Claimed only for the BARE keyword, so a
	# `break` that is part of something longer is not mistaken for the statement.
	if text == "break":
		return _with_indent(_sentence(OBJECT_SYSTEM, "Stop loop", {}), indent)
	if text == "continue":
		return _with_indent(_sentence(OBJECT_SYSTEM, "Next", {}), indent)
	# N11. A sheet marks a pause point ON the row, so a bare `breakpoint` says nothing in words: the
	# caller reads the flag and lights the sheet's own breakpoint dot. Display only - the statement in
	# the file is untouched, and the one blank segment keeps the row an ordinary row to select, hover
	# and open.
	if text == "breakpoint":
		return _with_indent({"object": "", "segments": [{"text": " ", "tone": "plain"}], "breakpoint": true}, indent)
	# Control flow is a BRANCH, not a step, and it already renders as its own structure elsewhere.
	if keyword in ["if", "elif", "else", "for", "while", "match", "pass", "break", "continue"]:
		return {}
	if keyword == "return":
		return _with_indent(_return_statement(text, context), indent)
	# N7. A file handle is OPENED, not declared: `var f = FileAccess.open(...)` is the sheet's own
	# "open the file" row, with the handle named after it rather than in front of it. Checked ahead of
	# the declaration reading, which would otherwise show the GDScript call as the local's value.
	var opened_file: Dictionary = _file_open_statement(text)
	if not opened_file.is_empty():
		return _with_indent(opened_file, indent)
	if keyword == "var" or keyword == "const":
		return _with_indent(_declaration_statement(text, keyword), indent)
	var compound: Dictionary = _compound_statement(text, context)
	if not compound.is_empty():
		return _with_indent(compound, indent)
	var assignment: Dictionary = _assignment_statement(text, context)
	if not assignment.is_empty():
		return _with_indent(assignment, indent)
	return _with_indent(_call_statement(text, context), indent)


## The reading of ONE boolean expression - the text of an `if`, or the expression an
## Expression Is True row carries. {} when nothing is recognised, so the caller keeps its own text.
static func condition(expression: String, context: Dictionary = {}) -> Dictionary:
	var text: String = expression.strip_edges()
	if text.is_empty():
		return {}
	var self_object: String = str(context.get("self_object", OBJECT_SYSTEM))
	# `if crouching:` - a bare flag is the sheet's "is boolean set" condition. An engine flag of the
	# script's own object (`visible`) belongs to that object instead (M25).
	if is_identifier(text):
		var flag_object: String = script_object(context) if is_engine_property(text, context) else self_object
		return _sentence(flag_object, "{name} is true", {"name": [text, "name"]})
	if text.begins_with("not ") and is_identifier(text.substr(4).strip_edges()):
		var bare_flag: String = text.substr(4).strip_edges()
		var negated_object: String = script_object(context) if is_engine_property(bare_flag, context) else self_object
		return _sentence(negated_object, "{name} is false", {"name": [bare_flag, "name"]})
	var group_test: Dictionary = _group_condition(text, context)
	if not group_test.is_empty():
		return group_test
	# ── N5 ──────────────────────────────────────────────────────────────────────────────────────
	# The four questions every gameplay script asks that still read as operators today: what an object
	# IS, what a table or a list HOLDS, and what an object HAS. Ahead of the comparison readings, none
	# of which can claim an `is` / `in` / `has_*` line anyway.
	var type_test: Dictionary = _type_condition(text, context)
	if not type_test.is_empty():
		return type_test
	var membership: Dictionary = _membership_condition(text)
	if not membership.is_empty():
		return membership
	var capability: Dictionary = _capability_condition(text, context)
	if not capability.is_empty():
		return capability
	var storage_test: Dictionary = _storage_condition(text)
	if not storage_test.is_empty():
		return storage_test
	var engine_test: Dictionary = _engine_property_condition(text, context)
	if not engine_test.is_empty():
		return engine_test
	var existence: Dictionary = _existence_condition(text)
	if not existence.is_empty():
		return existence
	var comparison: Dictionary = _comparison_condition(text)
	if not comparison.is_empty():
		return comparison
	var chance: Dictionary = _chance_condition(text)
	if not chance.is_empty():
		return chance
	var input_row: Dictionary = _input_condition(text)
	if not input_row.is_empty():
		return input_row
	# Nothing structural matched, but the expression itself may still hold an idiom
	# (`is_zero_approx(direction)`) or a type annotation this reading never shows.
	var rewritten: String = expression_text(text)
	if rewritten != text:
		return _sentence("", "{value}", {"value": [rewritten, "value"]})
	return {}


## The reading of a condition that may be a RUN of conjuncts (M23): `host != null and
## host.is_on_wall()` reads `host exists and host is on wall`, each conjunct through `condition()`.
##
## Returns {"object", "pieces"} - `pieces` an array of [text, tone] the caller draws in order, and
## `object` the row's object label, filled only when every conjunct belongs to the SAME object (with
## more than one object in play the words go inline instead, the way a sheet cell names each).
## Never {}: an expression nothing is recognised in still reads as itself.
static func condition_pieces(expression: String, context: Dictionary = {}) -> Dictionary:
	var text: String = expression.strip_edges()
	while text.begins_with("(") and closing_paren(text, 0) == text.length() - 1:
		text = text.substr(1, text.length() - 2).strip_edges()
	# One connective only. A mixed `a and b or c` has a precedence a flat run of words would misstate,
	# so it is left whole and reads as the expression it is.
	var connective: String = ""
	if top_level_index(text, " and ") >= 0 and top_level_index(text, " or ") < 0:
		connective = " and "
	elif top_level_index(text, " or ") >= 0 and top_level_index(text, " and ") < 0:
		connective = " or "
	var parts: PackedStringArray = split_top_level(text, connective) if not connective.is_empty() else PackedStringArray([text])
	var readings: Array = []
	for part: String in parts:
		readings.append(_condition_reading(part, context))
	# The object column can name ONE object. A run of conjuncts therefore says each object inline, the
	# way a sheet cell repeats the object picture in every condition it draws.
	var one_object: bool = readings.size() == 1
	var shared_object: String = str((readings[0] as Dictionary).get("object", "")) if one_object else ""
	var pieces: Array = []
	for index: int in readings.size():
		var reading: Dictionary = readings[index]
		if index > 0:
			pieces.append([" %s " % translate(connective.strip_edges()), "plain"])
		var object_name: String = str(reading.get("object", ""))
		if not one_object and not object_name.is_empty():
			pieces.append([object_name, "object"])
			pieces.append([" ", "plain"])
		for segment: Variant in (reading.get("segments", []) as Array):
			var part_segment: Dictionary = segment
			pieces.append([str(part_segment.get("text", "")), str(part_segment.get("tone", "plain"))])
	return {"object": shared_object if one_object else "", "pieces": pieces}


## One conjunct's reading: the ordinary condition path first, then the predicate-call fallback a
## sheet cell needs (`host.is_on_wall()` is an object and a question, not a line of code).
static func _condition_reading(part: String, context: Dictionary) -> Dictionary:
	var text: String = part.strip_edges()
	var negated: bool = false
	if text.begins_with("not ") and not is_identifier(text.substr(4).strip_edges()):
		negated = true
		text = text.substr(4).strip_edges()
	var reading: Dictionary = condition(text, context)
	if reading.is_empty():
		reading = _predicate_call_reading(text)
	if reading.is_empty():
		reading = {"object": "", "segments": [{"text": expression_text(text), "tone": "value"}]}
	if negated:
		var negated_segments: Array = [{"text": "%s " % translate("not"), "tone": "plain"}]
		negated_segments.append_array(reading.get("segments", []) as Array)
		reading = {"object": str(reading.get("object", "")), "segments": negated_segments}
	return reading


## `host.is_on_wall()` -> object `host`, sentence `is on wall`. Only a no-argument call whose verb
## already ASKS something (is/has/can) is claimed: a plain `host.update()` is a step, not a question,
## and reading it as one would be exactly the confident lie this grammar refuses.
static func _predicate_call_reading(text: String) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if call.is_empty():
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if not args.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	var is_question: bool = method.begins_with("is_") or method.begins_with("has_") or method.begins_with("can_")
	if not is_question:
		return {}
	return {
		"object": str(call.get("target", "")),
		"segments": [{"text": method.replace("_", " "), "tone": "plain"}]
	}


## The sub-event reading of a statement whose value carries a ternary (M23). A `if ... else` INSIDE
## a statement is a BRANCH, and an event sheet never puts a branch in an action cell - so the
## caller draws one row per branch: the condition on the left, the whole statement re-read on the
## right with that branch's value substituted, and a final `Else` row for the last one.
##
## Returns [] when there is nothing to hoist, else an array of {"condition", "code"} - `condition`
## empty on the final Else branch, `code` the ORIGINAL statement with the ternary replaced. Purely a
## reading: the caller keeps the one statement the file holds, so emission cannot move.
##
## Claimed only for statements that HAVE a value (a return, an assignment, a compound assignment, a
## local declaration) and only outside a lambda: hoisting a branch out of a `func(...)` body would
## move when it is evaluated, which is a different program.
static func ternary_branches(code: String) -> Array:
	if code.contains("\n"):
		return []
	var text: String = code.strip_edges()
	if text.is_empty() or text.begins_with("#") or text.contains("func("):
		return []
	var value_start: int = _value_offset(text)
	if value_start < 0:
		return []
	return _branches_in(text, value_start)


## The same reading for a bare VALUE rather than a whole statement - what a lifted ACE row carries in
## one of its parameters (`Add {delta_v} to velocity`). Each entry's "code" is the whole value with
## that arm substituted, so the caller re-renders its own row with the value swapped.
static func value_branches(value: String) -> Array:
	if value.contains("\n"):
		return []
	var text: String = value.strip_edges()
	if text.is_empty() or text.contains("func("):
		return []
	return _branches_in(text, 0)


## The arms of the ternary that lives in `text` at or after `value_start`, as {condition, code}.
static func _branches_in(text: String, value_start: int) -> Array:
	var span: Array = _ternary_span(text, value_start)
	if span.is_empty():
		return []
	var head: String = text.substr(0, int(span[0]))
	var tail: String = text.substr(int(span[1]))
	var branches: Array = []
	var remainder: String = text.substr(int(span[0]), int(span[1]) - int(span[0]))
	var guard: int = 0
	while guard < 8:
		guard += 1
		var peeled: String = remainder.strip_edges()
		while peeled.begins_with("(") and closing_paren(peeled, 0) == peeled.length() - 1:
			peeled = peeled.substr(1, peeled.length() - 2).strip_edges()
		var split: Array = _split_ternary(peeled)
		if split.is_empty():
			branches.append({"condition": "", "code": head + peeled + tail})
			return branches
		branches.append({"condition": str(split[1]), "code": head + str(split[0]) + tail})
		remainder = str(split[2])
	return []


## Top-level split of `text` on `connective`, quote- and bracket-aware. One entry when nothing splits.
static func split_top_level(text: String, connective: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var rest: String = text
	var guard: int = 0
	while guard < 32:
		guard += 1
		var at: int = top_level_index(rest, connective)
		if at < 0:
			break
		out.append(rest.substr(0, at).strip_edges())
		rest = rest.substr(at + connective.length())
	out.append(rest.strip_edges())
	return out


## Where a statement's VALUE begins, or -1 when the statement has no single value to branch on.
static func _value_offset(text: String) -> int:
	var keyword: String = leading_word(text)
	if keyword == "return":
		return 7 if text.length() > 7 else -1
	if keyword == "var" or keyword == "const":
		var rest_at: int = keyword.length() + 1
		var rest: String = text.substr(rest_at)
		var walrus_at: int = top_level_index(rest, " := ")
		var declared_at: int = top_level_index(rest, " = ")
		if walrus_at >= 0 and (declared_at < 0 or walrus_at < declared_at):
			return rest_at + walrus_at + 4
		if declared_at >= 0:
			return rest_at + declared_at + 3
		return -1
	for operator: String in [" = ", " += ", " -= ", " *= ", " /= "]:
		var at: int = top_level_index(text, operator)
		if at < 0:
			continue
		if not is_simple_target(text.substr(0, at).strip_edges()):
			return -1
		return at + operator.length()
	return -1


## The [start, end) of the ternary the caller must hoist, searching the value at `value_start` and
## then, when the value is not itself a ternary, the first bracketed group that holds one - the
## `move_speed * (fast if sprinting else 1.0)` shape, where the branch is only PART of the value.
## The span INCLUDES the brackets that wrap it, so substituting a branch leaves no empty pair behind.
static func _ternary_span(text: String, value_start: int) -> Array:
	var value: String = text.substr(value_start)
	if not _split_ternary(value.strip_edges()).is_empty():
		return [value_start, text.length()]
	var index: int = 0
	while index < value.length():
		var character: String = value[index]
		if character == "\"" or character == "'":
			index = _string_end(value, index) + 1
			continue
		if character != "(" and character != "[" and character != "{":
			index += 1
			continue
		var close_at: int = closing_paren(value, index)
		if close_at < 0:
			return []
		var inner: String = value.substr(index + 1, close_at - index - 1)
		if not _split_ternary(inner.strip_edges()).is_empty():
			return [value_start + index, value_start + close_at + 1]
		var nested: Array = _ternary_span(value.substr(index + 1, close_at - index - 1), 0)
		if not nested.is_empty():
			return [value_start + index + 1 + int(nested[0]), value_start + index + 1 + int(nested[1])]
		index = close_at + 1
	return []


## `A if C else B` split at its own top level, as [A, C, B]; [] when the text is not a ternary.
static func _split_ternary(text: String) -> Array:
	var if_at: int = top_level_index(text, " if ")
	if if_at <= 0:
		return []
	var tail: String = text.substr(if_at + 4)
	var else_at: int = top_level_index(tail, " else ")
	if else_at <= 0:
		return []
	var value_true: String = text.substr(0, if_at).strip_edges()
	var test: String = tail.substr(0, else_at).strip_edges()
	var value_false: String = tail.substr(else_at + 6).strip_edges()
	if value_true.is_empty() or test.is_empty() or value_false.is_empty():
		return []
	return [value_true, test, value_false]


## `Input.is_action_pressed("jump")` and its just-pressed sibling, as the Keyboard rows a the sheet
## user already knows. Shared by the raw path and by the two Core input ACEs, so both read alike.
static func input_action_sentence(action_value: String, just_pressed: bool) -> Dictionary:
	var shown: String = strip_action_name(action_value)
	if shown.is_empty():
		return {}
	if just_pressed:
		return _sentence(OBJECT_KEYBOARD, "On {action} pressed", {"action": [shown, "value"]})
	return _sentence(OBJECT_KEYBOARD, "{action} is down", {"action": [shown, "value"]})


## The reading of a signal emit: the PUBLISHED trigger name when the sheet declares one, so the row
## names the trigger a user sees in the picker rather than the snake_case member behind it.
static func signal_sentence(signal_name: String, arguments: String, context: Dictionary) -> Dictionary:
	var bare: String = signal_name.strip_edges()
	if not is_identifier(bare):
		return {}
	var trigger: String = trigger_name_of(bare, context)
	var owner: String = str(context.get("owner", "")).strip_edges()
	if owner.is_empty():
		owner = str(context.get("self_object", OBJECT_SYSTEM))
	var payload: String = arguments.strip_edges()
	if payload.is_empty():
		return _sentence(owner, "Signal {trigger}", {"trigger": [trigger, "name"]})
	# M28. The payload reads as one chip per declared parameter - "amount = 3" says what the value
	# MEANS, where a bare "3, attacker" makes a reader open the signal declaration to find out.
	var parameter_names: PackedStringArray = _signal_parameter_names(bare, context)
	if not parameter_names.is_empty():
		var values: PackedStringArray = _split_arguments(payload)
		var segments: Array = [{"text": "%s " % translate("Signal"), "tone": "plain"}, {"text": trigger, "tone": "name"}]
		for index: int in values.size():
			var chip: String = expression_text(values[index])
			if index < parameter_names.size():
				chip = "%s = %s" % [parameter_names[index], chip]
			segments.append({"text": "   ", "tone": "plain"})
			segments.append({"text": chip, "tone": "value"})
		return {"object": owner, "segments": segments}
	return _sentence(owner, "Signal {trigger} {values}", {
		"trigger": [trigger, "name"],
		"values": [expression_text(payload), "value"]
	})


## The declared parameter names of one of the sheet's signals, in order. Empty when the sheet does
## not declare that signal (or declares it without names), which is the cue to show plain values.
static func _signal_parameter_names(signal_name: String, context: Dictionary) -> PackedStringArray:
	var declared: Dictionary = context.get("signal_params", {})
	var names: Variant = declared.get(signal_name, PackedStringArray())
	if names is PackedStringArray:
		return names
	var out: PackedStringArray = PackedStringArray()
	if names is Array:
		for entry: Variant in (names as Array):
			out.append(str(entry))
	return out


## The reading of a `return`, given the kind of verb whose body it sits in (M14). A sheet's function
## block has exactly one action for handing a value back - `Set return value to X` - so a published
## CONDITION and a published EXPRESSION both read that, with `true` / `false` as themselves. An
## action's bare `return` is `Stop event` (the rest of the event does not run). Shared with the Core
## Return row so a picked row and a typed one read alike.
static func return_sentence(returned: String, context: Dictionary) -> Dictionary:
	var verb_kind: int = int(context.get("verb_kind", VerbKind.ACTION))
	var value: String = returned.strip_edges()
	if value.is_empty():
		return _sentence(str(context.get("self_object", OBJECT_SYSTEM)), "Stop event", {})
	var shown: String = expression_text(value)
	if verb_kind == VerbKind.CONDITION or verb_kind == VerbKind.EXPRESSION:
		return _sentence(str(context.get("self_object", OBJECT_SYSTEM)), "Set return value to {value}", {"value": [shown, "value"]})
	return _sentence(str(context.get("self_object", OBJECT_SYSTEM)), "Return {value}", {"value": [shown, "value"]})


## The declaration a `var name: Type = value` line reads as: a type word chip, the name, and the
## starting value - never the annotation itself (M18). {} when the line is not a declaration.
static func declaration(code: String) -> Dictionary:
	var text: String = code.strip_edges()
	var keyword: String = leading_word(text)
	if keyword != "var" and keyword != "const":
		return {}
	var parsed: Dictionary = _declaration_statement(text, keyword)
	return parsed


## A value expression with the Godot idioms replaced by their sheet reading and every type
## annotation dropped (M11 + M18). Returns the text unchanged when nothing is recognised.
static func expression_text(text: String) -> String:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return trimmed
	var without_cast: String = _drop_casts(trimmed)
	# M31 before the call rewriting: a join is decided by the WHOLE expression's shape (is any part of
	# it text?), which the innermost-first call pass would have already taken apart.
	# A whole value wrapped in `str(...)` is the same value: a sheet shows numbers in text without
	# a conversion, so the conversion is a GDScript chore rather than part of what the row says.
	var joined: String = _rewrite_format(_rewrite_dot_format(_string_call_value(without_cast)))
	joined = _rewrite_join(joined)
	var rewritten: String = _rewrite_calls(joined)
	rewritten = _rewrite_indexing(rewritten)
	# N5 last, so no earlier pass ever has to recognise a glyph it did not write.
	return comparison_symbols(_rewrite_delta(_tidy_numbers(rewritten)))


## N5. A sheet writes ≥, ≤ and ≠ where GDScript writes >=, <= and !=. A language needs the two-
## character spelling; a sheet row is only ever the question, so it says the question the way a reader
## means it. Quote-aware: a `>=` inside a string literal is content the user typed, not an operator.
static func comparison_symbols(text: String) -> String:
	if not (text.contains(">=") or text.contains("<=") or text.contains("!=")):
		return text
	var out: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if character == "\"" or character == "'":
			var quote_end: int = _string_end(text, index)
			out += text.substr(index, quote_end - index + 1)
			index = quote_end + 1
			continue
		match text.substr(index, 2):
			">=":
				out += "≥"
				index += 2
			"<=":
				out += "≤"
				index += 2
			"!=":
				out += "≠"
				index += 2
			_:
				out += character
				index += 1
	return out


## N6. `"{0}: {1}".format([a, b])` and the `%s` spelling of the same call, unrolled into the sheet's
## join. Claimed only when the WHOLE value is that one call on a literal pattern and every value it
## was handed is used exactly once - a half-unrolled format shows a reader a value in the wrong place.
static func _rewrite_dot_format(text: String) -> String:
	const HEAD := ".format("
	var trimmed: String = text.strip_edges()
	if not trimmed.ends_with(")") or not trimmed.contains(HEAD):
		return text
	var head_at: int = top_level_index(trimmed, HEAD)
	if head_at <= 0 or closing_paren(trimmed, head_at + HEAD.length() - 1) != trimmed.length() - 1:
		return text
	var pattern: String = trimmed.substr(0, head_at).strip_edges()
	if pattern.length() < 2 or not (pattern.begins_with("\"") and pattern.ends_with("\"")):
		return text
	var values_text: String = trimmed.substr(
		head_at + HEAD.length(), trimmed.length() - head_at - HEAD.length() - 1).strip_edges()
	if values_text.is_empty():
		return text
	var values: PackedStringArray = PackedStringArray([values_text])
	if values_text.begins_with("[") and values_text.ends_with("]"):
		values = _split_arguments(values_text.substr(1, values_text.length() - 2))
	var body: String = pattern.substr(1, pattern.length() - 2)
	# The printf spelling is the same unroll the `%` operator already does, so it is handed straight on
	# rather than written twice.
	if body.contains("%"):
		return _rewrite_format("%s %% %s" % [pattern, values_text])
	var slot_regex: RegEx = RegEx.create_from_string("\\{([0-9]+)\\}")
	if slot_regex == null:
		return text
	var pieces: PackedStringArray = PackedStringArray()
	var used: Dictionary = {}
	var cursor: int = 0
	for found: RegExMatch in slot_regex.search_all(body):
		var slot: int = found.get_string(1).to_int()
		if slot >= values.size():
			return text
		var literal: String = body.substr(cursor, found.get_start() - cursor)
		if not literal.is_empty():
			pieces.append("\"%s\"" % literal)
		pieces.append(values[slot])
		used[slot] = true
		cursor = found.get_end()
	if used.size() != values.size() or pieces.is_empty():
		return text
	var tail: String = body.substr(cursor)
	if not tail.is_empty():
		pieces.append("\"%s\"" % tail)
	return " & ".join(pieces)


## M27. `delta` is the sheet's `dt` - the same number under the name a sheet reader writes. Only
## the whole word is replaced, so `delta_v` and `_delta` keep their own names.
static func _rewrite_delta(text: String) -> String:
	if not text.contains("delta"):
		return text
	var regex: RegEx = RegEx.create_from_string("(?<![\\w.])delta(?![\\w])")
	if regex == null:
		return text
	return regex.sub(text, "dt", true)


## M31. `"a" + b` and `str(a) + " b"` read with the sheet's join. Claimed only when a part is plainly
## TEXT (a literal or a `str()` call): `x + y` on two numbers is arithmetic, and reading it as a join
## would be a confident lie.
static func _rewrite_join(text: String) -> String:
	if top_level_index(text, " + ") < 0:
		return text
	var parts: PackedStringArray = split_top_level(text, " + ")
	if parts.size() < 2:
		return text
	var has_text: bool = false
	for part: String in parts:
		if part.begins_with("\"") or part.begins_with("'") or _string_call_value(part) != part:
			has_text = true
	if not has_text:
		return text
	var spelled: PackedStringArray = PackedStringArray()
	for part: String in parts:
		spelled.append(_string_call_value(part))
	return " & ".join(spelled)


## The value inside a `str(x)` wrapper - a sheet joins values with text directly, so the conversion
## is a GDScript chore, not part of what the row says. Anything else comes back unchanged.
static func _string_call_value(part: String) -> String:
	var text: String = part.strip_edges()
	if not text.begins_with("str(") or not text.ends_with(")"):
		return text
	if closing_paren(text, 3) != text.length() - 1:
		return text
	var inner: String = text.substr(4, text.length() - 5).strip_edges()
	return inner if not inner.is_empty() and _split_arguments(inner).size() == 1 else text


## M31. `"Score: %d" % score` and `"%d / %d" % [a, b]` unrolled left to right into the same join.
## A format whose slots and values do not line up stays exactly as written - half an unroll would
## show a reader a number in the wrong place.
static func _rewrite_format(text: String) -> String:
	var at: int = top_level_index(text, " % ")
	if at < 0:
		return text
	var pattern: String = text.substr(0, at).strip_edges()
	var values_text: String = text.substr(at + 3).strip_edges()
	if not (pattern.begins_with("\"") and pattern.ends_with("\"")) or pattern.length() < 2:
		return text
	var values: PackedStringArray = PackedStringArray([values_text])
	if values_text.begins_with("[") and values_text.ends_with("]"):
		values = _split_arguments(values_text.substr(1, values_text.length() - 2))
	var body: String = pattern.substr(1, pattern.length() - 2)
	var slot_regex: RegEx = RegEx.create_from_string("%[-+ 0#]*[0-9]*(?:\\.[0-9]+)?[sdfxXvc%]")
	if slot_regex == null:
		return text
	var pieces: PackedStringArray = PackedStringArray()
	var cursor: int = 0
	var value_index: int = 0
	for found: RegExMatch in slot_regex.search_all(body):
		if found.get_string() == "%%":
			continue
		var literal: String = body.substr(cursor, found.get_start() - cursor)
		if not literal.is_empty():
			pieces.append("\"%s\"" % literal)
		if value_index >= values.size():
			return text
		pieces.append(values[value_index])
		value_index += 1
		cursor = found.get_end()
	if value_index != values.size() or pieces.is_empty():
		return text
	var tail: String = body.substr(cursor)
	if not tail.is_empty():
		pieces.append("\"%s\"" % tail)
	return " & ".join(pieces)


## M31. Indexing read the way a sheet reads a dictionary or an array: `inventory["potion"]` is
## `inventory's "potion"`, `items[0]` is `items' item 0`. Only a NAMED base is claimed - an index into
## a literal or a call result has no name to possess.
static func _rewrite_indexing(text: String) -> String:
	var out: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if character == "\"" or character == "'":
			var quote_end: int = _string_end(text, index)
			out += text.substr(index, quote_end - index + 1)
			index = quote_end + 1
			continue
		if character != "[":
			out += character
			index += 1
			continue
		var close_at: int = closing_paren(text, index)
		var base: String = _trailing_chain(out)
		if close_at < 0 or base.is_empty():
			out += character
			index += 1
			continue
		var key: String = _rewrite_indexing(text.substr(index + 1, close_at - index - 1)).strip_edges()
		if key.is_empty():
			out += text.substr(index, close_at - index + 1)
		elif key.begins_with("\"") or key.begins_with("'"):
			out += "'s %s" % key
		else:
			out += "' %s %s" % [translate("item"), key]
		index = close_at + 1
	return out


## The friendly type word for a declared type, matching the word the picker and the parameter chips
## use ("number", "text", "true/false"). An empty or inferred type reads "value".
static func type_word(type_name: String) -> String:
	var bare: String = type_name.strip_edges()
	if bare.is_empty():
		return translate("value")
	match bare:
		"int", "float":
			return translate("number")
		"String", "StringName":
			return translate("text")
		"bool":
			return translate("true/false")
		"Vector2", "Vector2i", "Vector3", "Vector3i":
			return translate("point")
		"Color":
			return translate("color")
		"Array":
			return translate("list")
		"Dictionary":
			return translate("table")
		"Variant":
			return translate("value")
	return bare


# ── Statement shapes ────────────────────────────────────────────────────────────


## The awaits with a settled sentence (M11 + M28): the timer wait, the two tick waits, and
## an await on a SIGNAL, which is the sheet's own "Wait for signal" action. Every other await keeps
## its code, because a sentence must never paper over a suspension point nobody can name.
static func _await_statement(text: String, context: Dictionary = {}) -> Dictionary:
	var body: String = text.substr(6).strip_edges()
	if body.begins_with("get_tree().create_timer(") and body.ends_with(").timeout"):
		var inner: String = body.substr(24, body.length() - 24 - 9)
		if inner.strip_edges().is_empty():
			return {}
		return _sentence(OBJECT_SYSTEM, "⏳ Wait {seconds} seconds", {"seconds": [expression_text(inner), "value"]})
	# M28. One frame of waiting is the sheet's tick, and which clock it is IS the one Godot fact
	# worth keeping - the two frames are different lengths.
	if body == "get_tree().process_frame":
		return _sentence(OBJECT_SYSTEM, "⏳ Wait one tick", {})
	if body == "get_tree().physics_frame":
		return _sentence(OBJECT_SYSTEM, "⏳ Wait one physics tick", {})
	return _await_signal_statement(body, context)


## M28. `await door.opened` / `await opened` as the sheet's Wait for signal, naming the object the
## signal lives on and the trigger it publishes as. Only a plain member read is claimed: an await on
## a CALL suspends on whatever that call returns, which no sentence can honestly name.
static func _await_signal_statement(body: String, context: Dictionary) -> Dictionary:
	if body.is_empty() or body.contains("(") or body.contains(" "):
		return {}
	# Only the MEMBER form is claimed (`await door.opened`). A bare `await something` names one
	# identifier, and an identifier alone does not say it is a signal - papering that over with a
	# sentence would hide a suspension point behind a guess.
	var dot_at: int = body.rfind(".")
	if dot_at <= 0:
		return {}
	var owner_name: String = body.substr(0, dot_at).strip_edges()
	var signal_name: String = body.substr(dot_at + 1).strip_edges()
	if not is_identifier(signal_name) or not is_simple_target(owner_name):
		return {}
	if owner_name == "self":
		owner_name = str(context.get("script_object", "")).strip_edges()
	var trigger: String = trigger_name_of(signal_name, context)
	if owner_name.is_empty():
		return _sentence(OBJECT_SYSTEM, "⏳ Wait for signal {trigger}", {"trigger": [trigger, "name"]})
	return _sentence(OBJECT_SYSTEM, "⏳ Wait for signal {owner} {trigger}", {
		"owner": [owner_name, "name"],
		"trigger": [trigger, "name"]
	})


## The published trigger name behind a signal member - the sheet's own @ace_name when it declares
## one, else the member read as words with the sheet's "On" in front.
static func trigger_name_of(signal_name: String, context: Dictionary) -> String:
	var declared: Dictionary = context.get("signals", {})
	var trigger: String = str(declared.get(signal_name, "")).strip_edges()
	if trigger.is_empty():
		trigger = signal_name.capitalize()
	if not trigger.begins_with("On "):
		trigger = "On %s" % trigger
	return trigger


static func _return_statement(text: String, context: Dictionary) -> Dictionary:
	if text == "return":
		return return_sentence("", context)
	return return_sentence(text.substr(7), context)


## `var name[: Type] = value`, `var name := value` and the `const` twins, as a declaration row.
static func _declaration_statement(text: String, keyword: String) -> Dictionary:
	var rest: String = text.substr(keyword.length() + 1)
	var walrus_at: int = top_level_index(rest, " := ")
	var equals_at: int = top_level_index(rest, " = ")
	var name_text: String = ""
	var value_text: String = ""
	if walrus_at >= 0 and (equals_at < 0 or walrus_at < equals_at):
		name_text = rest.substr(0, walrus_at).strip_edges()
		value_text = rest.substr(walrus_at + 4).strip_edges()
	elif equals_at >= 0:
		name_text = rest.substr(0, equals_at).strip_edges()
		value_text = rest.substr(equals_at + 3).strip_edges()
	else:
		return {}
	var declared_type: String = ""
	var colon_at: int = name_text.find(":")
	if colon_at >= 0:
		declared_type = name_text.substr(colon_at + 1).strip_edges()
		name_text = name_text.substr(0, colon_at).strip_edges()
	if value_text.is_empty() or not is_identifier(name_text):
		return {}
	# An inferred or annotation-free local still shows a type word, taken from the value when the
	# value says plainly what it is - a chip reading "value" on `var count := 0` helps nobody.
	if declared_type.is_empty():
		declared_type = _inferred_type(value_text)
	return {
		"kind": "declaration",
		"object": "",
		"is_constant": keyword == "const",
		"type_word": type_word(declared_type),
		"name": name_text,
		"value": expression_text(value_text),
		"segments": [
			{"text": "%s %s" % [translate("Local"), type_word(declared_type)], "tone": "plain"},
			{"text": " %s = " % name_text, "tone": "name"},
			{"text": expression_text(value_text), "tone": "value"}
		]
	}


## `hp -= 1` and friends - the arithmetic verb the operator IS. The spaced token is what keeps
## `x <= y` out: none of the comparisons contain " += " or " = ".
static func _compound_statement(text: String, context: Dictionary) -> Dictionary:
	for operator: String in [" += ", " -= ", " *= ", " /= "]:
		var operator_at: int = top_level_index(text, operator)
		if operator_at < 0:
			continue
		var target: String = text.substr(0, operator_at).strip_edges()
		var amount: String = text.substr(operator_at + operator.length()).strip_edges()
		if not is_simple_target(target) or amount.is_empty():
			return {}
		var split: Array = _split_object(target, context)
		var values: Dictionary = {
			"name": [str(split[1]), "name"],
			"value": [expression_text(amount), "value"]
		}
		match operator:
			" += ":
				return _sentence(str(split[0]), "Add {value} to {name}", values)
			" -= ":
				return _sentence(str(split[0]), "Subtract {value} from {name}", values)
			" *= ":
				return _sentence(str(split[0]), "Multiply {name} by {value}", values)
			_:
				return _sentence(str(split[0]), "Divide {name} by {value}", values)
	return {}


static func _assignment_statement(text: String, context: Dictionary) -> Dictionary:
	var assign_at: int = top_level_index(text, " = ")
	if assign_at < 0:
		return {}
	var target: String = text.substr(0, assign_at).strip_edges()
	var assigned: String = text.substr(assign_at + 3).strip_edges()
	if not is_simple_target(target) or assigned.is_empty():
		return {}
	var split: Array = _split_object(target, context)
	var object_name: String = str(split[0])
	# N8. A property every reader knows as a BEHAVIOUR knob - a body's velocity, a camera's zoom, a
	# particle emitter's switch - reads in that behaviour's words, decided by the object's known class.
	var behaviour: Dictionary = _behaviour_assignment(str(split[0]), str(split[1]), assigned, target, context)
	if not behaviour.is_empty():
		return behaviour
	# M32 / N7 / N9. The engine's services are filed as OBJECTS: reading the stick belongs to
	# Keyboard, saving belongs to Storage, parsing belongs to JSON - exactly as the picked rows do.
	if object_name == OBJECT_SYSTEM:
		var service: String = value_object(assigned)
		if not service.is_empty():
			object_name = service
	return _sentence(object_name, "Set {name} to {value}", {
		"name": [str(split[1]), "name"],
		"value": [expression_text(assigned), "value"]
	})


## N7/N9. The service object a VALUE comes from, or "" when it comes from nowhere in particular.
## Matched on the call as WRITTEN, before any rewriting, so the decision rests on the code rather than
## on words this grammar itself produced.
static func value_object(expression: String) -> String:
	var text: String = expression.strip_edges()
	if text.begins_with("JSON.parse_string(") or text.begins_with("JSON.stringify("):
		return OBJECT_JSON
	if text.begins_with("FileAccess."):
		return OBJECT_FILE
	if top_level_index(text, ".get_value(") > 0:
		return OBJECT_STORAGE
	if text.begins_with("Input.get_action_strength(") or text.begins_with("Input.get_action_raw_strength("):
		return OBJECT_GAMEPAD
	if text.begins_with("Input."):
		return OBJECT_KEYBOARD
	return ""


## The call shapes with a settled sentence: destroy, emit, change scene. Anything else is left to the
## caller's own Object / Verb / parameters rendering.
static func _call_statement(text: String, context: Dictionary) -> Dictionary:
	# Checked before the plain call split, because the receiver is itself a call: `get_tree()` is not
	# an object a sentence can name, but the scene switch behind it is one of the sheet's own actions.
	const SCENE_HEAD := "get_tree().change_scene_to_file("
	if text.begins_with(SCENE_HEAD) and text.ends_with(")"):
		var scene_path: String = text.substr(SCENE_HEAD.length(), text.length() - SCENE_HEAD.length() - 1)
		if not scene_path.strip_edges().is_empty():
			# The path stays a quoted string, so a reader (and the name lens) sees content, not a name.
			return _sentence(OBJECT_SYSTEM, "Go to scene {path}", {"path": ["\"%s\"" % _unquote(scene_path), "value"]})
	var group_call: Dictionary = _group_call_statement(text)
	if not group_call.is_empty():
		return group_call
	var tween: Dictionary = _tween_statement(text, context)
	if not tween.is_empty():
		return tween
	var call: Dictionary = call_parts(text)
	if call.is_empty():
		return {}
	var target: String = str(call.get("target", ""))
	var method: String = str(call.get("method", ""))
	var args: PackedStringArray = call.get("args", PackedStringArray())
	var self_object: String = str(context.get("self_object", OBJECT_SYSTEM))
	var object_name: String = self_object if target.is_empty() or target == "self" else target
	# M25/M26. `queue_free()` on ANY object is the sheet's Destroy, including the script's own object -
	# which is named, never `self`.
	if method == "queue_free" and args.is_empty():
		if target.is_empty() or target == "self":
			object_name = script_object(context)
		return _sentence(object_name, "Destroy", {})
	# M30. A group is the nearest thing Godot has to a sheet family, so joining one says so.
	if method == "add_to_group" and args.size() >= 1:
		if target.is_empty() or target == "self":
			object_name = script_object(context)
		return _sentence(object_name, "Add to group {group}", {"group": [_quoted(args[0]), "value"]})
	if method == "remove_from_group" and args.size() >= 1:
		if target.is_empty() or target == "self":
			object_name = script_object(context)
		return _sentence(object_name, "Remove from group {group}", {"group": [_quoted(args[0]), "value"]})
	# `call_deferred("queue_free")` is the same destroy, one frame later - and the delay is the whole
	# reason a user reached for it, so the reading says so.
	if method == "call_deferred" and args.size() == 1 and _unquote(args[0]) == "queue_free":
		return _sentence(object_name, "Destroy (at end of frame)", {})
	if method == "emit":
		return signal_sentence(target, ", ".join(args), context)
	# ── N7 / N8 / N11 ───────────────────────────────────────────────────────────────────────────
	# The three families of call that the sheet has settled rows for. Each is checked here, at the end
	# of the curated shapes, so an unrecognised call still falls through to M26's Object ▸ Verb chips.
	var storage_step: Dictionary = _storage_statement(target, method, args)
	if not storage_step.is_empty():
		return storage_step
	# A behaviour step on the script's OWN object belongs to that object by name, never to System: a
	# collision switch is something the node does, the way every other row about it reads.
	var acting_object: String = script_object(context) if target.is_empty() or target == "self" else object_name
	var behaviour_step: Dictionary = _behaviour_call(acting_object, method, args, target, context)
	if not behaviour_step.is_empty():
		return behaviour_step
	return _debug_statement(target, method, args)


## N11. The sheet's Browser ▸ Log is the debug verb everyone knows, and Godot's print family is the
## same three levels under different names. `print` itself is deliberately NOT claimed: it already
## reads "Print", which is the word on its own picked row.
static func _debug_statement(target: String, method: String, args: PackedStringArray) -> Dictionary:
	if not target.is_empty():
		return {}
	if args.size() == 1:
		match method:
			"push_error", "printerr":
				return _sentence(OBJECT_SYSTEM, "Log error {value}", {"value": [expression_text(args[0]), "value"]})
			"push_warning":
				return _sentence(OBJECT_SYSTEM, "Log warning {value}", {"value": [expression_text(args[0]), "value"]})
			"print_rich":
				return _sentence(OBJECT_SYSTEM, "Log {value}", {"value": [expression_text(args[0]), "value"]})
	if method != "assert" or args.is_empty() or args.size() > 2:
		return {}
	if args.size() == 1:
		return _sentence(OBJECT_SYSTEM, "Assert {condition}", {"condition": [expression_text(args[0]), "value"]})
	return _sentence(OBJECT_SYSTEM, "Assert {condition} {message}", {
		"condition": [expression_text(args[0]), "value"],
		"message": [expression_text(args[1]), "plain"]
	})


## N7. The ConfigFile and FileAccess STEPS, in the sheet's Local Storage / AJAX words.
##
## `save` and `load` are ordinary English and live on plenty of other classes, so they are claimed
## only for a literal path that plainly names a config file - which is the one spelling that says
## "this is storage" without asking what the receiver holds at run time.
static func _storage_statement(target: String, method: String, args: PackedStringArray) -> Dictionary:
	if target.is_empty():
		return {}
	if method == "set_value" and args.size() == 3:
		return _sentence(OBJECT_STORAGE, "Set item {key} to {value} (section {section})", {
			"key": [expression_text(args[1]), "value"],
			"value": [expression_text(args[2]), "value"],
			"section": [expression_text(args[0]), "plain"]
		})
	if method == "store_string" and args.size() == 1:
		return _sentence(object_of_reference(target), "Write {text}", {"text": [expression_text(args[0]), "value"]})
	if (method != "save" and method != "load") or args.size() != 1 or not _is_config_path(args[0]):
		return {}
	if method == "save":
		return _sentence(OBJECT_STORAGE, "Save {file}", {"file": [file_name_value(args[0]), "value"]})
	return _sentence(OBJECT_STORAGE, "Load {file}", {"file": [file_name_value(args[0]), "value"]})


## True when a value is a literal path to a settings file - the only argument a bare `save` / `load`
## may have and still be honestly readable as the sheet's storage.
static func _is_config_path(value: String) -> bool:
	if not _is_string_literal(value):
		return false
	var path: String = _unquote(value.strip_edges().trim_prefix("&")).to_lower()
	return path.ends_with(".cfg") or path.ends_with(".ini")


## N7. `var f = FileAccess.open("user://log.txt", FileAccess.WRITE)` as the sheet's own open-the-file
## row: the verb first, the file it names, which way it was opened, and the handle named after it all
## as the receipt it is. Returns {} for anything that is not exactly that assignment.
static func _file_open_statement(text: String) -> Dictionary:
	if not text.contains("FileAccess.open("):
		return {}
	var body: String = text
	for keyword: String in ["var ", "const "]:
		if body.begins_with(keyword):
			body = body.substr(keyword.length())
	var handle: String = ""
	for operator: String in [" := ", " = "]:
		var at: int = top_level_index(body, operator)
		if at <= 0:
			continue
		handle = body.substr(0, at).strip_edges()
		body = body.substr(at + operator.length()).strip_edges()
		break
	if handle.is_empty():
		return {}
	var colon_at: int = handle.find(":")
	if colon_at >= 0:
		handle = handle.substr(0, colon_at).strip_edges()
	if not is_identifier(handle) or not body.begins_with("FileAccess.open("):
		return {}
	var call: Dictionary = call_parts(body)
	if call.is_empty():
		return {}
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	if arguments.size() != 2:
		return {}
	var mode: String = arguments[1].strip_edges()
	# The three modes a reader cares about, said as the thing they are about to do with the file.
	var mode_word: String = ""
	if mode == "FileAccess.WRITE":
		mode_word = "Open {file} for writing (as {handle})"
	elif mode == "FileAccess.READ":
		mode_word = "Open {file} for reading (as {handle})"
	elif mode == "FileAccess.READ_WRITE":
		mode_word = "Open {file} for reading and writing (as {handle})"
	if mode_word.is_empty():
		return {}
	return _sentence(OBJECT_FILE, mode_word, {
		"file": [file_name_value(arguments[0]), "value"],
		"handle": [handle, "name"]
	})


## N8. What the sheet knows an object's class to be, or "" when it knows nothing. `object_classes` is
## handed in by the caller, because only the caller can ask the sheet; a label that is itself an engine
## class name (`$Camera2D` reads "Camera2D") resolves through ClassDB, which is the same answer.
## A guessed class would put behaviour words on the wrong object, so "" means the row keeps its code.
static func class_of(object_label: String, context: Dictionary) -> String:
	var bare: String = object_of_reference(object_label.strip_edges())
	if bare.is_empty():
		return ""
	# `self` is never a name a reader sees, and it is never a class either: it is whatever object this
	# script IS, which the sheet already knows by name.
	if bare == "self":
		bare = script_object(context)
	var classes: Dictionary = context.get("object_classes", {})
	for key: String in [object_label.strip_edges(), bare]:
		var found: String = str(classes.get(key, "")).strip_edges()
		if not found.is_empty():
			return found
	return bare if ClassDB.class_exists(bare) else ""


## N8. True when a known class is one of the families whose words this reading claims. Matched on the
## class NAME rather than through ClassDB inheritance so the 2D and 3D twins answer alike and a
## headless run (where no scene tree exists) reads exactly as the editor does.
static func _is_class_family(class_name_text: String, family: String) -> bool:
	if class_name_text.is_empty():
		return false
	match family:
		"body":
			return class_name_text.begins_with("RigidBody")
		"camera":
			return class_name_text.begins_with("Camera")
		"particles":
			return class_name_text.ends_with("Particles2D") or class_name_text.ends_with("Particles3D")
	return false


## N8. One behaviour reading: a sheet puts the behaviour's NAME on the row as a chip and then says
## the step in that behaviour's words, so a reader knows which of an object's behaviours is acting.
static func _behaviour_sentence(object_name: String, chip: String, template: String, values: Dictionary) -> Dictionary:
	var reading: Dictionary = _sentence(object_name, template, values)
	if chip.is_empty():
		return reading
	var segments: Array = [{"text": translate(chip), "tone": "chip"}, {"text": "  ", "tone": "plain"}]
	segments.append_array(reading.get("segments", []) as Array)
	return {"object": object_name, "segments": segments}


## N8. The behaviour words a CALL reads in. The collision-layer pair is not gated on a class: those two
## methods exist on exactly one thing in Godot, so the shape alone already says what the row does.
static func _behaviour_call(object_name: String, method: String, args: PackedStringArray,
		target: String, context: Dictionary) -> Dictionary:
	if (method == "set_collision_mask_value" or method == "set_collision_layer_value") and args.size() == 2:
		var switch: String = args[1].strip_edges()
		if switch != "true" and switch != "false":
			return {}
		return _sentence(object_name, "Set collision with layer {layer} {state}", {
			"layer": [expression_text(args[0]), "value"],
			"state": [translate("on") if switch == "true" else translate("off"), "name"]
		})
	var known_class: String = class_of(target if not target.is_empty() else object_name, context)
	if known_class.is_empty():
		return {}
	if args.size() == 1 and _is_class_family(known_class, "body"):
		match method:
			"apply_impulse", "apply_central_impulse":
				return _behaviour_sentence(object_name, "Physics", "Apply impulse {value}",
					{"value": [expression_text(args[0]), "value"]})
			"apply_force", "apply_central_force":
				return _behaviour_sentence(object_name, "Physics", "Apply force {value}",
					{"value": [expression_text(args[0]), "value"]})
		return {}
	if not args.is_empty():
		return {}
	if method == "make_current" and _is_class_family(known_class, "camera"):
		return _sentence(object_name, "Set as active camera", {})
	if method == "restart" and _is_class_family(known_class, "particles"):
		return _behaviour_sentence(object_name, "Particles", "Restart", {})
	return {}


## N8. The behaviour words a PROPERTY SET reads in - a body's velocity, a camera's zoom, an emitter's
## switch and the two collision knobs. Every one of these is gated on the object's KNOWN class except
## the collision pair, whose property names are unambiguous on their own.
static func _behaviour_assignment(object_name: String, member: String, assigned: String,
		target: String, context: Dictionary) -> Dictionary:
	var value: String = assigned.strip_edges()
	if (member == "collision_layer" or member == "collision_mask") and value == "0":
		return _sentence(object_name, "Set collisions {state}", {"state": [translate("off"), "name"]})
	var known_class: String = class_of(target.split(".", false)[0] if target.contains(".") else object_name, context)
	if known_class.is_empty():
		return {}
	if _is_class_family(known_class, "body"):
		if member == "linear_velocity":
			return _behaviour_sentence(object_name, "Physics", "Set velocity to {value}",
				{"value": [expression_text(value), "value"]})
		if member == "angular_velocity":
			return _behaviour_sentence(object_name, "Physics", "Set angular velocity to {value}",
				{"value": [expression_text(value), "value"]})
		return {}
	if member == "emitting" and _is_class_family(known_class, "particles"):
		if value == "true":
			return _behaviour_sentence(object_name, "Particles", "Start spraying", {})
		if value == "false":
			return _behaviour_sentence(object_name, "Particles", "Stop spraying", {})
		return {}
	if member == "zoom" and _is_class_family(known_class, "camera"):
		var percent: String = _zoom_percent(value)
		if percent.is_empty():
			return {}
		return _sentence(object_name, "Set zoom to {percent}", {"percent": [percent, "value"]})
	return {}


## N8. `Vector2(2, 2)` as the 200% a reader means by it. Only an EVEN zoom of two plain numbers is
## claimed: a camera squashed on one axis has no single percentage, and printing one would be a lie.
static func _zoom_percent(value: String) -> String:
	var text: String = value.strip_edges()
	if not text.begins_with("Vector2(") or not text.ends_with(")"):
		return ""
	var parts: PackedStringArray = _split_arguments(text.substr(8, text.length() - 9))
	if parts.size() != 2 or parts[0] != parts[1] or not parts[0].is_valid_float():
		return ""
	var shown: String = String.num(parts[0].to_float() * 100.0, 4).rstrip("0").rstrip(".")
	return "" if shown.is_empty() else "%s%%" % shown


## M30. `get_tree().call_group("enemies", "flee", extra)` - the group is the OBJECT the row acts on
## (a sheet family), the method is the verb, and anything after it is a value the call passes on.
static func _group_call_statement(text: String) -> Dictionary:
	const GROUP_HEAD := "get_tree().call_group("
	const DEFERRED_HEAD := "get_tree().call_group_flags("
	var head: String = ""
	if text.begins_with(GROUP_HEAD):
		head = GROUP_HEAD
	elif text.begins_with(DEFERRED_HEAD):
		head = DEFERRED_HEAD
	if head.is_empty() or not text.ends_with(")"):
		return {}
	var arguments: PackedStringArray = _split_arguments(text.substr(head.length(), text.length() - head.length() - 1))
	if head == DEFERRED_HEAD and not arguments.is_empty():
		# The flags word is a Godot scheduling detail, not part of what the step does.
		arguments = arguments.slice(1)
	if arguments.size() < 2:
		return {}
	# Both names must be LITERALS: a `call_group(group_var, method_var)` has no words a row could
	# honestly print, and inventing them is exactly the confident lie this grammar refuses.
	if not _is_string_literal(arguments[0]) or not _is_string_literal(arguments[1]):
		return {}
	var group_name: String = _unquote(arguments[0].strip_edges().trim_prefix("&"))
	var method: String = _unquote(arguments[1].strip_edges().trim_prefix("&"))
	if group_name.is_empty() or not is_identifier(method):
		return {}
	var object_label: String = "%s %s" % [group_name, translate("(group)")]
	var segments: Array = [
		{"text": "%s " % translate("Call"), "tone": "plain"},
		{"text": verb_words(method), "tone": "name"}
	]
	for index: int in range(2, arguments.size()):
		segments.append({"text": "   ", "tone": "plain"})
		segments.append({"text": expression_text(arguments[index]), "tone": "value"})
	return {"object": object_label, "segments": segments}


## M32. `create_tween().tween_property(host, "position", target, 0.3)` as the vocabulary's own Tween
## Property sentence, so the typed line and the picked ACE read the same words.
static func _tween_statement(text: String, context: Dictionary) -> Dictionary:
	const TWEEN_HEAD := "create_tween().tween_property("
	var body: String = text
	if body.begins_with("self."):
		body = body.substr(5)
	if not body.begins_with(TWEEN_HEAD) or not body.ends_with(")"):
		return {}
	var arguments: PackedStringArray = _split_arguments(body.substr(TWEEN_HEAD.length(), body.length() - TWEEN_HEAD.length() - 1))
	if arguments.size() < 4:
		return {}
	var object_name: String = arguments[0].strip_edges()
	if object_name == "self" or object_name.is_empty():
		object_name = script_object(context)
	return _sentence(object_name, "Tween {property} to {value} over {duration}s", {
		"property": [_unquote(arguments[1]), "name"],
		"value": [expression_text(arguments[2]), "value"],
		"duration": [expression_text(arguments[3]), "value"]
	})


## M25. The name of the object the script itself IS - its class_name, else the node or scene it sits
## on, else the file name. Never `self`, and never empty: a sheet that knows nothing about its own
## object still has System to fall back on, which is where a plain script variable lives anyway.
static func script_object(context: Dictionary) -> String:
	var named: String = str(context.get("script_object", "")).strip_edges()
	if not named.is_empty():
		return named
	return str(context.get("self_object", OBJECT_SYSTEM))


## A LITERAL shown as the quoted string it is, whatever spelling the code used (`&"boss"`, `'boss'`).
## A value that is not a literal comes back as itself: quoting `group_name` would show a reader a
## group actually called "group_name", which is not what the line does.
static func _quoted(value: String) -> String:
	var text: String = value.strip_edges().trim_prefix("&")
	if not (text.begins_with("\"") or text.begins_with("'")):
		return expression_text(text)
	return "\"%s\"" % _unquote(text)


## True when a value is a plain string literal - the only spelling a group or method NAME can have
## and still be readable as the name it is.
static func _is_string_literal(value: String) -> bool:
	var text: String = value.strip_edges().trim_prefix("&")
	return text.length() >= 2 and ((text.begins_with("\"") and text.ends_with("\"")) or (text.begins_with("'") and text.ends_with("'")))


## M26. A method name as the verb a reader says: `play` -> "Play", `take_damage` -> "Take damage",
## `set_text` -> "Set text to" (the value follows it), `get_x` -> "x" (a property read, not a step).
## Sentence case, not Title Case: a row is a sentence, and only its first word is capitalised.
static func verb_words(method: String) -> String:
	var bare: String = method.strip_edges()
	if bare.is_empty():
		return bare
	var words: PackedStringArray = bare.split("_", false)
	if words.is_empty():
		return bare
	var spelled: PackedStringArray = PackedStringArray()
	for index: int in words.size():
		spelled.append(words[index].capitalize().to_lower() if index > 0 else words[index].capitalize())
	var sentence: String = " ".join(spelled)
	if words[0] == "set" and words.size() > 1:
		return "%s %s" % [sentence, translate("to")]
	return sentence


## M25/M26. The reading of ANY method call the sheet has no verb of its own for: Object, then the
## verb in words, then one chip per argument - and never a pair of parentheses, because a the sheet
## row shows values, not a call.
##
## `parameter_names` are the engine's own names for the method's arguments when the object's class is
## known (a caller that knows nothing passes none, and the chips are plain values). Returns {} when
## the line is not exactly one call.
static func call_reading(text: String, context: Dictionary, parameter_names: PackedStringArray = PackedStringArray()) -> Dictionary:
	var call: Dictionary = call_parts(text.strip_edges())
	if call.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	var verb: String = verb_words(method)
	var segments: Array = [{"text": verb, "tone": "name"}]
	# A `set_x(v)` verb already ends in "to", so its one value follows the word rather than wearing a
	# name chip that would repeat what the verb just said.
	var value_follows_verb: bool = verb.ends_with(" %s" % translate("to")) and arguments.size() == 1
	for index: int in arguments.size():
		var chip: String = expression_text(arguments[index])
		if not value_follows_verb and index < parameter_names.size() and not parameter_names[index].is_empty():
			chip = "%s = %s" % [parameter_names[index], chip]
		segments.append({"text": " " if value_follows_verb else "   ", "tone": "plain"})
		segments.append({"text": chip, "tone": "value"})
	return {"object": call_object(str(call.get("target", "")), method, context), "segments": segments}


## M25/M26. Which object a call belongs to: a global function is System, a receiver-less or `self.`
## call is the script's own object, a `$Path/To/Node` reads by its last segment, and anything else is
## the receiver as written.
static func call_object(target: String, method: String, context: Dictionary) -> String:
	var receiver: String = target.strip_edges()
	if receiver.is_empty():
		return OBJECT_SYSTEM if GLOBAL_FUNCTIONS.has(method) else script_object(context)
	if receiver == "self":
		return script_object(context)
	return object_of_reference(receiver)


## The object label a node reference reads under: `$Path/To/Label` and `%HpBar` name their last
## segment, which is the name a reader sees in the scene tree. Anything else is its own label.
static func object_of_reference(reference: String) -> String:
	var text: String = reference.strip_edges()
	if not (text.begins_with("$") or text.begins_with("%")):
		return text
	var path: String = text.substr(1).strip_edges().trim_prefix("\"").trim_suffix("\"")
	var slash_at: int = path.rfind("/")
	if slash_at >= 0:
		path = path.substr(slash_at + 1)
	return path if not path.is_empty() else text


# ── Condition shapes ────────────────────────────────────────────────────────────


## `host == null` / `host != null` as the sheet's own existence condition.
static func _existence_condition(text: String) -> Dictionary:
	for operator: String in [" == ", " != "]:
		var at: int = top_level_index(text, operator)
		if at < 0:
			continue
		var left: String = text.substr(0, at).strip_edges()
		var right: String = text.substr(at + operator.length()).strip_edges()
		var subject: String = ""
		if right == "null":
			subject = left
		elif left == "null":
			subject = right
		if subject.is_empty() or not is_simple_target(subject):
			return {}
		if operator == " == ":
			return _sentence(subject, "does not exist", {})
		return _sentence(subject, "exists", {})
	return {}


## `i == 1` as the sheet's Compare: `i = 1`, and `hp != 3` as `hp ≠ 3`. GDScript doubles the sign
## because a language needs to tell assignment from a question; a sheet row is only ever the question,
## so the row says what a reader means by it. Equality ONLY - `<`, `>=` and the rest already read as
## themselves - and a `== null` never reaches here, because the existence reading claims it first.
## The row belongs to System, the way the sheet's own Compare condition does.
static func _comparison_condition(text: String) -> Dictionary:
	for operator: String in [" == ", " != "]:
		var at: int = top_level_index(text, operator)
		if at < 0:
			continue
		var left: String = text.substr(0, at).strip_edges()
		var right: String = text.substr(at + operator.length()).strip_edges()
		if left.is_empty() or right.is_empty():
			return {}
		# One comparison only: `a == b == c` is not a shape GDScript writes, and a run of them joined
		# by `and` was already split into terms before this ever saw a word of it.
		if top_level_index(right, operator) >= 0:
			return {}
		return {"object": OBJECT_SYSTEM, "segments": [
			{"text": expression_text(left), "tone": "value"},
			{"text": " %s " % ("=" if operator == " == " else "≠"), "tone": "plain"},
			{"text": expression_text(right), "tone": "value"}
		]}
	return {}


## M30. `enemy.is_in_group("boss")` as the family test it is, with the group named as the string the
## user typed. The object column names whoever is being asked.
static func _group_condition(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if call.is_empty() or str(call.get("method", "")) != "is_in_group":
		return {}
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	if arguments.size() != 1:
		return {}
	var target: String = str(call.get("target", "")).strip_edges()
	if target.is_empty() or target == "self":
		target = script_object(context)
	return _sentence(object_of_reference(target), "is in group {group}", {"group": [_quoted(arguments[0]), "value"]})


## N5. `body is Player` - the sheet's own type check, with the class drawn as the chip it is rather
## than left as a bare word in the middle of a sentence. Only `X is <ClassName>` is claimed: an
## `is not` (whose right-hand side is not a single identifier) refuses, and keeps its code.
static func _type_condition(text: String, context: Dictionary) -> Dictionary:
	var at: int = top_level_index(text, " is ")
	if at <= 0:
		return {}
	var subject: String = text.substr(0, at).strip_edges()
	var type_name: String = text.substr(at + 4).strip_edges()
	if not is_simple_target(subject) or not is_identifier(type_name):
		return {}
	if subject == "self":
		subject = script_object(context)
	return _sentence(object_of_reference(subject), "is a {type}", {"type": [type_name, "chip"]})


## N5. `in` asks three different questions in GDScript, and the sheet has a different row for each.
## Which one this line asks is decided by its SHAPE, never by a guess about what a name holds at run
## time: a LITERAL list on the right is the sheet's "is one of", a quoted key on the left is a table
## lookup, and anything else is a list being asked whether it contains a value.
static func _membership_condition(text: String) -> Dictionary:
	var at: int = top_level_index(text, " in ")
	if at <= 0:
		return {}
	var needle: String = text.substr(0, at).strip_edges()
	var haystack: String = text.substr(at + 4).strip_edges()
	if needle.is_empty() or haystack.is_empty():
		return {}
	if haystack.begins_with("[") and haystack.ends_with("]"):
		var entries: PackedStringArray = _split_arguments(haystack.substr(1, haystack.length() - 2))
		if entries.is_empty() or entries[0].is_empty():
			return {}
		var shown: PackedStringArray = PackedStringArray()
		for entry: String in entries:
			shown.append(expression_text(entry))
		return _sentence(OBJECT_SYSTEM, "{value} is one of {entries}", {
			"value": [expression_text(needle), "value"],
			"entries": [", ".join(shown), "value"]
		})
	if not is_simple_target(haystack):
		return {}
	if _is_string_literal(needle):
		return _sentence(OBJECT_SYSTEM, "{table} has key {key}", {
			"table": [haystack, "name"],
			"key": [_quoted(needle), "value"]
		})
	return _sentence(OBJECT_SYSTEM, "{list} contains {value}", {
		"list": [haystack, "name"],
		"value": [expression_text(needle), "value"]
	})


## N5. `obj.has_method("take_damage")` and `has_node("Sprite2D")` - a sheet asks whether an object
## HAS something, and names the thing it has the way the sheet names it everywhere else: a function
## under its display name, a child under its own object label. Only a LITERAL name is claimed - a
## `has_method(method_var)` has no words a row could honestly print.
static func _capability_condition(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if call.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	if method != "has_method" and method != "has_node":
		return {}
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	if arguments.size() != 1 or not _is_string_literal(arguments[0]):
		return {}
	var target: String = str(call.get("target", "")).strip_edges()
	if target.is_empty() or target == "self":
		target = script_object(context)
	var named: String = _unquote(arguments[0].strip_edges().trim_prefix("&"))
	if named.is_empty():
		return {}
	if method == "has_method":
		return _sentence(object_of_reference(target), "has function {verb}", {"verb": [function_words(named), "name"]})
	return _sentence(object_of_reference(target), "has child {child}", {"child": [named, "chip"]})


## N7. `cfg.has_section_key(section, key)` as the sheet's "storage has item". The section is a
## GDScript filing detail the Storage object already implies, so only the key is in the sentence.
static func _storage_condition(text: String) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if call.is_empty():
		return {}
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	if str(call.get("method", "")) == "has_section_key" and arguments.size() == 2:
		return _sentence(OBJECT_STORAGE, "has item {key}", {"key": [expression_text(arguments[1]), "value"]})
	if text.begins_with("FileAccess.file_exists(") and arguments.size() == 1:
		return _sentence(OBJECT_FILE, "{file} exists", {"file": [file_name_value(arguments[0]), "value"]})
	return {}


## N7. The FILE a path names, as the quoted word a reader recognises: `"user://saves/slot1.cfg"` is
## `"slot1.cfg"`. The directory is a Godot filing detail, and the Storage / File object already says
## where the sheet keeps things. A value that is not a literal path stays exactly as written.
static func file_name_value(path_value: String) -> String:
	if not _is_string_literal(path_value):
		return expression_text(path_value)
	var path: String = _unquote(path_value.strip_edges().trim_prefix("&"))
	var slash_at: int = path.rfind("/")
	if slash_at >= 0:
		path = path.substr(slash_at + 1)
	return "\"%s\"" % path


## A method name as the FUNCTION it is: Title Case, the way a published verb reads in the picker and
## in a Call row ("take_damage" -> "Take Damage"). Deliberately not `verb_words()`, which spells an
## unknown method as a sentence-case step; asking whether an object has a FUNCTION is asking about
## the named thing, so it reads under the name that thing would be published as.
static func function_words(method: String) -> String:
	var bare: String = method.strip_edges()
	while bare.begins_with("_"):
		bare = bare.substr(1)
	return bare.capitalize() if not bare.is_empty() else method.strip_edges()


## M25. `rotation > 1.5` - a comparison whose subject is an ENGINE property of the script's own
## object reads under that object, the way `Sprite > X > 100` does on a sheet.
static func _engine_property_condition(text: String, context: Dictionary) -> Dictionary:
	for operator: String in [" >= ", " <= ", " != ", " == ", " > ", " < "]:
		var at: int = top_level_index(text, operator)
		if at < 0:
			continue
		var subject: String = text.substr(0, at).strip_edges()
		var compared: String = text.substr(at + operator.length()).strip_edges()
		if compared.is_empty() or not is_simple_target(subject):
			return {}
		var head: String = subject.split(".", false)[0] if subject.contains(".") else subject
		if head == "self":
			head = subject.substr(5).split(".", false)[0]
		if not is_engine_property(head, context):
			return {}
		# Built directly rather than through a template: a comparison has no words to translate, and
		# the operator stays the symbol the user typed - spelled N5's way, which is the same question.
		return {"object": script_object(context), "segments": [
			{"text": engine_member_name(subject.trim_prefix("self.")), "tone": "name"},
			{"text": comparison_symbols(operator), "tone": "plain"},
			{"text": expression_text(compared), "tone": "value"}
		]}
	return {}


## `randf() < 0.3` as the sheet's chance condition. Only a literal probability is claimed - a
## computed one has no honest percentage to show.
static func _chance_condition(text: String) -> Dictionary:
	var at: int = top_level_index(text, " < ")
	if at < 0 or text.substr(0, at).strip_edges() != "randf()":
		return {}
	var probability: String = text.substr(at + 3).strip_edges()
	if not probability.is_valid_float():
		return {}
	var percent: float = probability.to_float() * 100.0
	var shown: String = String.num(percent, 4).rstrip("0").rstrip(".")
	if shown.is_empty():
		shown = "0"
	return _sentence(OBJECT_SYSTEM, "{percent}% chance", {"percent": [shown, "value"]})


static func _input_condition(text: String) -> Dictionary:
	for method: String in ["is_action_pressed", "is_action_just_pressed"]:
		var head: String = "Input.%s(" % method
		if not text.begins_with(head) or not text.ends_with(")"):
			continue
		var inner: String = text.substr(head.length(), text.length() - head.length() - 1)
		return input_action_sentence(inner, method == "is_action_just_pressed")
	# ── N9 ──────────────────────────────────────────────────────────────────────────────────────
	# The releases, the InputEvent spellings and the two raw device questions. An `event.` line asks
	# about the ONE event the handler was handed, which is a different question from the device's live
	# state, so the reading says which - the sheet's own distinction between a trigger and a check.
	var call: Dictionary = call_parts(text)
	if call.is_empty():
		return {}
	var target: String = str(call.get("target", "")).strip_edges()
	var method: String = str(call.get("method", ""))
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	if arguments.size() != 1:
		return {}
	if target == "Input" and method == "is_action_just_released":
		return input_phase_sentence(arguments[0], false, false)
	if target == "Input" and method == "is_key_pressed":
		return _key_sentence(OBJECT_KEYBOARD, "KEY_", arguments[0], "{key} is down")
	if target == "Input" and method == "is_mouse_button_pressed":
		return _key_sentence(OBJECT_MOUSE, "MOUSE_BUTTON_", arguments[0], "{key} button is down")
	# Any InputEvent variable spells these the same way, so the receiver is not pinned to one name.
	if not target.is_empty() and target != "Input" and is_identifier(target):
		if method == "is_action_pressed":
			return input_phase_sentence(arguments[0], true, true)
		if method == "is_action_released":
			return input_phase_sentence(arguments[0], false, true)
	return {}


## N9. `Input.is_action_just_released("jump")` and the two `event.is_action_*` spellings, as the
## Keyboard rows a sheet reader knows. `this_event` marks the InputEvent forms, which ask about the
## one event the handler was handed rather than about the device's live state.
static func input_phase_sentence(action_value: String, pressed: bool, this_event: bool) -> Dictionary:
	var shown: String = strip_action_name(action_value)
	if shown.is_empty():
		return {}
	# Four whole templates rather than one built by concatenation: a locale translates a SENTENCE, and
	# a key stitched together at run time is a key no CSV can ever hold.
	var template: String = "On {action} pressed" if pressed else "On {action} released"
	if this_event:
		template = "On {action} pressed (this event)" if pressed else "On {action} released (this event)"
	return _sentence(OBJECT_KEYBOARD, template, {"action": [shown, "value"]})


## N9. `KEY_X` / `MOUSE_BUTTON_LEFT` as the key or button a reader would say. Only a bare engine
## constant is claimed: a computed keycode has no letter to print.
static func _key_sentence(object_name: String, prefix: String, constant: String, template: String) -> Dictionary:
	var bare: String = constant.strip_edges()
	if not bare.begins_with(prefix) or not is_identifier(bare):
		return {}
	var named: String = bare.substr(prefix.length())
	if named.is_empty():
		return {}
	# A single letter or digit stays the character it is; a word key reads as the word ("SPACE" is
	# Space), and a mouse button reads in the lower case a sheet writes it in.
	var shown: String = named if named.length() == 1 else named.capitalize()
	if object_name == OBJECT_MOUSE:
		shown = shown.to_lower()
	return _sentence(object_name, template, {"key": [shown, "name"]})


# ── Expression rewriting (M11 + M18) ────────────────────────────────────────────


## Drops `as Type` casts, including the parenthesised `(x as Node2D)` spelling: a cast is a compiler
## instruction, never part of what the step DOES.
static func _drop_casts(text: String) -> String:
	var out: String = text
	var guard: int = 0
	while guard < 8:
		guard += 1
		var at: int = top_level_index(out, " as ")
		if at < 0:
			break
		var tail: String = out.substr(at + 4)
		var type_end: int = 0
		while type_end < tail.length() and (tail[type_end].is_valid_identifier() or tail[type_end] == "." or tail[type_end].is_valid_int()):
			type_end += 1
		if type_end == 0:
			break
		out = out.substr(0, at) + tail.substr(type_end)
	# `(x)` left behind by a dropped cast is noise: `(host as Node2D).position` reads `host.position`.
	while out.begins_with("(") and closing_paren(out, 0) == out.length() - 1:
		out = out.substr(1, out.length() - 2).strip_edges()
	return out


## Rewrites every recognised call in `text`, innermost first, leaving anything unrecognised alone.
static func _rewrite_calls(text: String) -> String:
	var out: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if character == "\"" or character == "'":
			var quote_end: int = _string_end(text, index)
			out += text.substr(index, quote_end - index + 1)
			index = quote_end + 1
			continue
		if character != "(":
			out += character
			index += 1
			continue
		var close_at: int = closing_paren(text, index)
		if close_at < 0:
			out += text.substr(index)
			break
		var inner: String = _rewrite_calls(text.substr(index + 1, close_at - index - 1))
		var head: String = _trailing_identifier(out)
		var arguments: PackedStringArray = _split_arguments(inner)
		# M32. The receiver-aware table first: `arr.size()` and `Input.get_vector(...)` say something
		# only the whole chain can say, and the head alone would read as a bare `size`.
		var chain: String = _trailing_chain(out)
		var receiver_reading: String = _receiver_idiom(chain, arguments)
		if not receiver_reading.is_empty():
			out = out.substr(0, out.length() - chain.length()) + receiver_reading
			index = close_at + 1
			continue
		var replacement: String = _idiom_for(head, arguments)
		if replacement.is_empty():
			# A bare group holding a cast - `(child as CollisionShape3D).shape` - loses both the cast
			# and the brackets that only existed to hold it.
			var uncast: String = _drop_casts(inner) if head.is_empty() else inner
			out += uncast if head.is_empty() and uncast != inner else "(" + inner + ")"
		else:
			out = out.substr(0, out.length() - head.length()) + replacement
		index = close_at + 1
	return out


## The reading of one call, or "" when the head is not in the curated table.
static func _idiom_for(head: String, arguments: PackedStringArray) -> String:
	if head.is_empty():
		return ""
	if VECTOR_CONSTRUCTORS.has(head):
		return "(%s)" % ", ".join(arguments)
	if head == "move_toward" and arguments.size() == 3:
		return _fill(translate("{from} moved toward {to} by {amount}"), {
			"from": arguments[0], "to": arguments[1], "amount": arguments[2]
		})
	if (head == "lerp" or head == "lerpf") and arguments.size() == 3:
		return "%s → %s %s %s" % [arguments[0], arguments[1], translate("at"), arguments[2]]
	if head in ["clamp", "clampf", "clampi"] and arguments.size() == 3:
		return _fill(translate("{value} kept between {low} and {high}"), {
			"value": arguments[0], "low": arguments[1], "high": arguments[2]
		})
	# A no-argument `get_thing()` is a PROPERTY READ wearing a call's clothes: a sheet shows the
	# property, so `host.get_wall_normal().x` reads `host.wall_normal.x` and the possessive lens can
	# then spell it `host's wall normal X`. Only the zero-argument form is claimed - `get_node(path)`
	# takes an argument and stays the call it is.
	if arguments.is_empty() and head.begins_with("get_") and head.length() > 4:
		return head.substr(4)
	if not EXPRESSION_IDIOMS.has(head):
		return ""
	var pattern: String = str(EXPRESSION_IDIOMS[head])
	var filled: String = pattern
	for argument_index: int in arguments.size():
		filled = filled.replace("{%d}" % argument_index, arguments[argument_index])
	# A shape whose slots were not all filled (a one-argument max) is not the shape it looked like.
	return "" if filled.contains("{") else filled


## `1.0` reads `1`: a trailing `.0` is a GDScript type cue, never part of the number a reader means.
static func _tidy_numbers(text: String) -> String:
	var regex: RegEx = RegEx.create_from_string("(?<![\\w.])(\\d+)\\.0(?![\\d\\w])")
	if regex == null:
		return text
	return regex.sub(text, "$1", true)


# ── Small scanners (shared with the viewport's own statement classifiers) ────────


## The leading identifier word of a line. Matching the WORD rather than a begins_with prefix is what
## keeps `elsewhere = 1` from reading as an `else`.
static func leading_word(text: String) -> String:
	var word_regex: RegEx = RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*")
	var found: RegExMatch = word_regex.search(text)
	return found.get_string(0) if found != null else ""


## True when `text` is a plain identifier - the only thing a declaration row may name.
static func is_identifier(text: String) -> bool:
	var identifier_regex: RegEx = RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*$")
	return identifier_regex.search(text) != null


## True when a left-hand side is a SIMPLE target: `hp`, `item.text`, `scores[0]`, `$HUD/Bar`.
## A space or a `(` means something is being called, and no "Set X to Y" can honestly describe
## assigning through a call.
static func is_simple_target(text: String) -> bool:
	return not text.is_empty() and not text.contains(" ") and not text.contains("(")


## The index of the first `operator` at bracket/quote depth 0, or -1. A plain find() would split on
## the ` = ` inside `x = "a = b"` and produce a confidently wrong sentence.
static func top_level_index(text: String, operator: String) -> int:
	var depth: int = 0
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if character == "\"" or character == "'":
			index = _string_end(text, index) + 1
			continue
		if character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		elif depth == 0 and text.substr(index, operator.length()) == operator:
			return index
		index += 1
	return -1


## The index of the `)` that closes the `(` at `open_at`, or -1 when the line is unbalanced.
static func closing_paren(text: String, open_at: int) -> int:
	var depth: int = 0
	var index: int = open_at
	while index < text.length():
		var character: String = text[index]
		if character == "\"" or character == "'":
			index = _string_end(text, index) + 1
			continue
		if character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
			if depth == 0:
				return index
		index += 1
	return -1


## The Object / verb / arguments split of a line that is EXACTLY one call. Returns
## {target, method, args} - target "" for a receiver-less call - or {} for anything else.
static func call_parts(text: String) -> Dictionary:
	if not text.ends_with(")"):
		return {}
	var open_at: int = _first_open_paren(text)
	if open_at <= 0:
		return {}
	if closing_paren(text, open_at) != text.length() - 1:
		return {}
	var head: String = text.substr(0, open_at).strip_edges()
	var target: String = ""
	var method: String = head
	var dot_at: int = head.rfind(".")
	if dot_at >= 0:
		target = head.substr(0, dot_at).strip_edges()
		method = head.substr(dot_at + 1).strip_edges()
	if not is_identifier(method):
		return {}
	var inner: String = text.substr(open_at + 1, text.length() - open_at - 2)
	return {"target": target, "method": method, "args": _split_arguments(inner)}


## The `&"action"` StringName prefix dropped, the QUOTES kept: an input action is a string the
## user typed, and a sheet shows it as one ("jump" is down). Kept quoted, the name lens also
## knows to leave it alone (it never rewrites inside a literal), so `ui_accept` stays `ui_accept`.
static func strip_action_name(value: String) -> String:
	var bare: String = _unquote(value.strip_edges().trim_prefix("&"))
	return "" if bare.is_empty() else "\"%s\"" % bare


## Editor-UI translation, kept in one place so every sentence word goes through the same door.
static func translate(text: String) -> String:
	return EventSheetL10n.translate(text)


# ── Internals ───────────────────────────────────────────────────────────────────


static func _with_indent(result: Dictionary, indent: int) -> Dictionary:
	if result.is_empty():
		return result
	result["indent"] = indent
	return result


## Builds the {object, segments} reading from a TRANSLATED template, so a locale can reorder the
## sentence without the tones drifting off their values: each `{slot}` becomes its own segment.
static func _sentence(object_name: String, template: String, values: Dictionary) -> Dictionary:
	var translated: String = translate(template)
	var segments: Array = []
	var rest: String = translated
	var guard: int = 0
	while guard < 12:
		guard += 1
		var next_slot: String = ""
		var next_at: int = -1
		for slot: String in values.keys():
			var at: int = rest.find("{%s}" % slot)
			if at >= 0 and (next_at < 0 or at < next_at):
				next_at = at
				next_slot = slot
		if next_at < 0:
			break
		if next_at > 0:
			segments.append({"text": rest.substr(0, next_at), "tone": "plain"})
		var pair: Array = values[next_slot]
		segments.append({"text": str(pair[0]), "tone": str(pair[1])})
		rest = rest.substr(next_at + next_slot.length() + 2)
	if not rest.is_empty():
		segments.append({"text": rest, "tone": "plain"})
	return {"object": object_name, "segments": segments}


## Fills `{slot}` markers in an already-translated pattern with plain text.
static func _fill(pattern: String, values: Dictionary) -> String:
	var out: String = pattern
	for slot: String in values.keys():
		out = out.replace("{%s}" % slot, str(values[slot]))
	return out


## Splits an assignment target into the object it belongs to and the member being set:
## `host.velocity.x` -> ["host", "velocity.x"], `_jumps_left` -> [self object, "_jumps_left"].
static func _split_object(target: String, context: Dictionary) -> Array:
	var self_object: String = str(context.get("self_object", OBJECT_SYSTEM))
	var text: String = target.strip_edges()
	# M25. `self.` is never a word a reader sees: the script's own object has a name.
	if text.begins_with("self."):
		text = text.substr(5)
	var dot_at: int = text.find(".")
	var head: String = text if dot_at <= 0 else text.substr(0, dot_at)
	# M25. An ENGINE property of the script's own object belongs to that object, exactly as the sheet
	# draws Sprite > Set X. A plain script variable is not one of these, and stays with System.
	if is_engine_property(head, context):
		return [script_object(context), engine_member_name(text)]
	if dot_at <= 0:
		return [self_object, text]
	var object_name: String = head
	if object_name == "self":
		object_name = script_object(context)
	return [object_name, text.substr(dot_at + 1)]


## M25. True when `name` is a property the ENGINE reports on the object this script is - the set is
## handed in by the caller (`engine_properties`), because only the caller can ask ClassDB.
static func is_engine_property(property_name: String, context: Dictionary) -> bool:
	var properties: Dictionary = context.get("engine_properties", {})
	return properties.has(property_name.strip_edges())


## M25. What an engine property chain is CALLED on the row: a sheet writes an object's place as X
## and Y, so `position.x` reads X. Everything else keeps its chain and the possessive lens spells it.
static func engine_member_name(chain: String) -> String:
	var parts: PackedStringArray = chain.split(".", false)
	if parts.size() == 2 and (parts[0] == "position" or parts[0] == "global_position"):
		var axis: String = parts[1].to_lower()
		if axis == "x" or axis == "y" or axis == "z":
			return axis.to_upper()
	return chain


## The type a value plainly declares, for a `:=` local. Only the unmistakable forms are claimed.
static func _inferred_type(value: String) -> String:
	var text: String = value.strip_edges()
	if text == "true" or text == "false":
		return "bool"
	if text.is_valid_int():
		return "int"
	if text.is_valid_float():
		return "float"
	if text.begins_with("\"") or text.begins_with("'"):
		return "String"
	if text.begins_with("["):
		return "Array"
	if text.begins_with("{"):
		return "Dictionary"
	for constructor: String in VECTOR_CONSTRUCTORS:
		if text.begins_with("%s(" % constructor) or text.begins_with("%s." % constructor):
			return constructor
	return ""


static func _unquote(text: String) -> String:
	var trimmed: String = text.strip_edges()
	if trimmed.length() >= 2 and (trimmed.begins_with("\"") and trimmed.ends_with("\"")):
		return trimmed.substr(1, trimmed.length() - 2)
	if trimmed.length() >= 2 and (trimmed.begins_with("'") and trimmed.ends_with("'")):
		return trimmed.substr(1, trimmed.length() - 2)
	return trimmed


## The index of the quote closing the string that OPENS at `start`, or the last index when it never
## closes. Escapes are honoured, so `"a\"b"` is one string.
static func _string_end(text: String, start: int) -> int:
	var quote: String = text[start]
	var index: int = start + 1
	while index < text.length():
		if text[index] == "\\":
			index += 2
			continue
		if text[index] == quote:
			return index
		index += 1
	return text.length() - 1


## The index of the first `(` outside any string literal, or -1.
static func _first_open_paren(text: String) -> int:
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if character == "\"" or character == "'":
			index = _string_end(text, index) + 1
			continue
		if character == "(":
			return index
		index += 1
	return -1


## The identifier immediately before the current position - a call's head, or "" when the `(` is a
## grouping bracket rather than a call.
static func _trailing_identifier(text: String) -> String:
	var index: int = text.length() - 1
	while index >= 0 and (text[index].is_valid_identifier() or text[index].is_valid_int()):
		index -= 1
	var head: String = text.substr(index + 1)
	return head if is_identifier(head) else ""


## The identifier CHAIN immediately before the current position ("Input.get_vector", "arr.size",
## "inventory"), or "" when nothing nameable precedes it. The chain is what a receiver idiom and the
## indexing lens both need: the head of a call is only half of what a reader is looking at.
static func _trailing_chain(text: String) -> String:
	var index: int = text.length() - 1
	while index >= 0 and (text[index].is_valid_identifier() or text[index].is_valid_int() or text[index] == "."):
		index -= 1
	var chain: String = text.substr(index + 1)
	while chain.ends_with("."):
		chain = chain.substr(0, chain.length() - 1)
	if chain.is_empty() or chain.begins_with("."):
		return ""
	for part: String in chain.split(".", false):
		if not is_identifier(part):
			return ""
	return chain


## M32. The reading of a call that needs its RECEIVER as well as its arguments - `arr.size()` is the
## array's count, `Input.get_vector(...)` is the input vector. "" when the chain is not one of these.
static func _receiver_idiom(chain: String, arguments: PackedStringArray) -> String:
	var dot_at: int = chain.rfind(".")
	if dot_at <= 0:
		return ""
	var receiver: String = chain.substr(0, dot_at)
	var method: String = chain.substr(dot_at + 1)
	# N6/N7. The two shapes whose reading depends on the ARGUMENTS rather than on the method alone:
	# `substr` is the sheet's left() from zero and its mid() anywhere else, and a config read says
	# whether it has a fallback. Everything else is one method, one pattern.
	var shaped: String = _shaped_receiver_idiom(receiver, method, arguments)
	if not shaped.is_empty():
		return shaped
	var pattern: String = str(RECEIVER_IDIOMS.get(chain, RECEIVER_IDIOMS.get(method, "")))
	if pattern.is_empty():
		return ""
	# The pattern must account for EVERY argument. Without this, `s.find(x, from)` would fill the one
	# slot `find(s, x)` has and silently drop the second argument - a reading that is almost right,
	# which is worse than the call it replaced.
	if _slot_count(pattern) != arguments.size():
		return ""
	var filled: String = pattern.replace("{receiver}", receiver)
	for index: int in arguments.size():
		filled = filled.replace("{%d}" % index, arguments[index])
	return "" if filled.contains("{") else filled


## How many `{N}` argument slots a pattern names, so an idiom can never quietly drop an argument.
static func _slot_count(pattern: String) -> int:
	var found: int = 0
	while pattern.contains("{%d}" % found):
		found += 1
	return found


## N6/N7. The receiver idioms whose reading is decided by the argument list.
static func _shaped_receiver_idiom(receiver: String, method: String, arguments: PackedStringArray) -> String:
	if method == "substr" and arguments.size() == 2:
		if arguments[0].strip_edges() == "0":
			return "left(%s, %s)" % [receiver, arguments[1]]
		return "mid(%s, %s, %s)" % [receiver, arguments[0], arguments[1]]
	# `cfg.get_value(section, key)` is the sheet's "read an item from storage"; the section is a
	# GDScript filing detail the Storage object already implies, so only the KEY is in the sentence.
	if method == "get_value" and arguments.size() == 2:
		return _fill(translate("item {key}"), {"key": arguments[1]})
	if method == "get_value" and arguments.size() == 3:
		return _fill(translate("item {key} (default {fallback})"), {"key": arguments[1], "fallback": arguments[2]})
	return ""


## Top-level comma split of an argument list; empty for an empty list.
static func _split_arguments(inner: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if inner.strip_edges().is_empty():
		return out
	var depth: int = 0
	var start: int = 0
	var index: int = 0
	while index < inner.length():
		var character: String = inner[index]
		if character == "\"" or character == "'":
			index = _string_end(inner, index) + 1
			continue
		if character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		elif character == "," and depth == 0:
			out.append(inner.substr(start, index - start).strip_edges())
			start = index + 1
		index += 1
	out.append(inner.substr(start).strip_edges())
	return out
