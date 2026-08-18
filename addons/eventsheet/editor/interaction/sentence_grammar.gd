@tool
class_name EventSheetSentence
extends RefCounted

# Construct-style row grammar for statements that have no ACE of their own.
#
# ONE producer, TWO callers. A row that says `host.velocity.x = speed` must read the same whether
# the user typed that line in a .gd file (a RawCodeRow the viewport lifts to a sentence) or dropped
# the matching ACE from the picker (an ACEAction whose display template the viewport substitutes).
# Both paths land here, so the two readings cannot drift apart: the viewport's raw path calls
# `statement()` / `condition()`, and its ACE path calls the same helpers with the row's params.
#
# The shape of every reading is Construct's own word order - OBJECT, then VERB, then the values:
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
## Input rows belong to Construct's Keyboard object, not to System.
const OBJECT_KEYBOARD := "Keyboard"

## Godot call shapes that have one settled Construct sentence. Curated on purpose: an entry is added
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
	"is_equal_approx": "{0} ≈ {1}"
}

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


## The Construct reading of ONE GDScript statement, or {} when no shape is recognised.
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
		return _with_indent(_await_statement(text), indent)
	# Control flow is a BRANCH, not a step, and it already renders as its own structure elsewhere.
	if keyword in ["if", "elif", "else", "for", "while", "match", "pass", "break", "continue"]:
		return {}
	if keyword == "return":
		return _with_indent(_return_statement(text, context), indent)
	if keyword == "var" or keyword == "const":
		return _with_indent(_declaration_statement(text, keyword), indent)
	var compound: Dictionary = _compound_statement(text, context)
	if not compound.is_empty():
		return _with_indent(compound, indent)
	var assignment: Dictionary = _assignment_statement(text, context)
	if not assignment.is_empty():
		return _with_indent(assignment, indent)
	return _with_indent(_call_statement(text, context), indent)


## The Construct reading of ONE boolean expression - the text of an `if`, or the expression an
## Expression Is True row carries. {} when nothing is recognised, so the caller keeps its own text.
static func condition(expression: String, context: Dictionary = {}) -> Dictionary:
	var text: String = expression.strip_edges()
	if text.is_empty():
		return {}
	var self_object: String = str(context.get("self_object", OBJECT_SYSTEM))
	# `if crouching:` - a bare flag is Construct's "is boolean set" condition.
	if is_identifier(text):
		return _sentence(self_object, "{name} is true", {"name": [text, "name"]})
	if text.begins_with("not ") and is_identifier(text.substr(4).strip_edges()):
		return _sentence(self_object, "{name} is false", {"name": [text.substr(4).strip_edges(), "name"]})
	var existence: Dictionary = _existence_condition(text)
	if not existence.is_empty():
		return existence
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


## The Construct reading of a condition that may be a RUN of conjuncts (M23): `host != null and
## host.is_on_wall()` reads `host exists and host is on wall`, each conjunct through `condition()`.
##
## Returns {"object", "pieces"} - `pieces` an array of [text, tone] the caller draws in order, and
## `object` the row's object label, filled only when every conjunct belongs to the SAME object (with
## more than one object in play the words go inline instead, the way a Construct cell names each).
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
	# way a Construct cell repeats the object picture in every condition it draws.
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
## Construct cell needs (`host.is_on_wall()` is an object and a question, not a line of code).
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
## a statement is a BRANCH, and a Construct sheet never puts a branch in an action cell - so the
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


## `Input.is_action_pressed("jump")` and its just-pressed sibling, as the Keyboard rows a Construct
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
	var declared: Dictionary = context.get("signals", {})
	var trigger: String = str(declared.get(bare, "")).strip_edges()
	if trigger.is_empty():
		trigger = bare.capitalize()
	if not trigger.begins_with("On "):
		trigger = "On %s" % trigger
	var owner: String = str(context.get("owner", "")).strip_edges()
	if owner.is_empty():
		owner = str(context.get("self_object", OBJECT_SYSTEM))
	var payload: String = arguments.strip_edges()
	if payload.is_empty():
		return _sentence(owner, "Signal {trigger}", {"trigger": [trigger, "name"]})
	return _sentence(owner, "Signal {trigger} {values}", {
		"trigger": [trigger, "name"],
		"values": [expression_text(payload), "value"]
	})


## The reading of a `return`, given the kind of verb whose body it sits in (M14). Construct's function
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


## A value expression with the Godot idioms replaced by their Construct reading and every type
## annotation dropped (M11 + M18). Returns the text unchanged when nothing is recognised.
static func expression_text(text: String) -> String:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return trimmed
	var without_cast: String = _drop_casts(trimmed)
	var rewritten: String = _rewrite_calls(without_cast)
	return _tidy_numbers(rewritten)


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


## `await get_tree().create_timer(0.5).timeout` - the one await with a settled sentence. Every other
## await keeps its code, because a sentence must never paper over a suspension point.
static func _await_statement(text: String) -> Dictionary:
	var body: String = text.substr(6).strip_edges()
	if not body.begins_with("get_tree().create_timer(") or not body.ends_with(").timeout"):
		return {}
	var inner: String = body.substr(24, body.length() - 24 - 9)
	if inner.strip_edges().is_empty():
		return {}
	return _sentence(OBJECT_SYSTEM, "⏳ Wait {seconds} seconds", {"seconds": [expression_text(inner), "value"]})


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
	return _sentence(str(split[0]), "Set {name} to {value}", {
		"name": [str(split[1]), "name"],
		"value": [expression_text(assigned), "value"]
	})


## The call shapes with a settled sentence: destroy, emit, change scene. Anything else is left to the
## caller's own Object / Verb / parameters rendering.
static func _call_statement(text: String, context: Dictionary) -> Dictionary:
	# Checked before the plain call split, because the receiver is itself a call: `get_tree()` is not
	# an object a sentence can name, but the scene switch behind it is one of Construct's own actions.
	const SCENE_HEAD := "get_tree().change_scene_to_file("
	if text.begins_with(SCENE_HEAD) and text.ends_with(")"):
		var scene_path: String = text.substr(SCENE_HEAD.length(), text.length() - SCENE_HEAD.length() - 1)
		if not scene_path.strip_edges().is_empty():
			# The path stays a quoted string, so a reader (and the name lens) sees content, not a name.
			return _sentence(OBJECT_SYSTEM, "Go to scene {path}", {"path": ["\"%s\"" % _unquote(scene_path), "value"]})
	var call: Dictionary = call_parts(text)
	if call.is_empty():
		return {}
	var target: String = str(call.get("target", ""))
	var method: String = str(call.get("method", ""))
	var args: PackedStringArray = call.get("args", PackedStringArray())
	var self_object: String = str(context.get("self_object", OBJECT_SYSTEM))
	var object_name: String = self_object if target.is_empty() or target == "self" else target
	if method == "queue_free" and args.is_empty():
		return _sentence(object_name, "Destroy", {})
	# `call_deferred("queue_free")` is the same destroy, one frame later - and the delay is the whole
	# reason a user reached for it, so the reading says so.
	if method == "call_deferred" and args.size() == 1 and _unquote(args[0]) == "queue_free":
		return _sentence(object_name, "Destroy (at end of frame)", {})
	if method == "emit":
		return signal_sentence(target, ", ".join(args), context)
	return {}


# ── Condition shapes ────────────────────────────────────────────────────────────


## `host == null` / `host != null` as Construct's own existence condition.
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


## `randf() < 0.3` as Construct's chance condition. Only a literal probability is claimed - a
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
	return {}


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


## The Construct reading of one call, or "" when the head is not in the curated table.
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
	# A no-argument `get_thing()` is a PROPERTY READ wearing a call's clothes: Construct shows the
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
## user typed, and Construct shows it as one ("jump" is down). Kept quoted, the name lens also
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
	var dot_at: int = target.find(".")
	if dot_at <= 0:
		return [self_object, target]
	var object_name: String = target.substr(0, dot_at)
	if object_name == "self":
		object_name = self_object
	return [object_name, target.substr(dot_at + 1)]


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
