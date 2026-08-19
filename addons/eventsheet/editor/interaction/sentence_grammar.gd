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
# The shape of every reading is the event-sheet word order - OBJECT, then VERB, then the values:
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
## Input rows belong to the event-sheet Keyboard object, not to System.
const OBJECT_KEYBOARD := "Keyboard"
## M45. The pointer is the event-sheet Mouse object, exactly as the stick is Keyboard's.
const OBJECT_MOUSE := "Mouse"
## M40. An AudioStreamPlayer row belongs to the one Audio object an event sheet files these under,
## whatever the player is called in the scene tree.
const OBJECT_AUDIO := "Audio"
## N9. An analogue read is a Gamepad question, and the pointer is already the Mouse object above.
## Same split the object bar draws, so a reader looks for the row under the object they associate
## with it.
const OBJECT_GAMEPAD := "Gamepad"
## N7. Saving, files and JSON belong to three objects of their own - Local Storage, JSON and AJAX.
## Hand-written ConfigFile / JSON / FileAccess code reads under the same three names, so the rows a
## reader already recognises are the rows they see here.
const OBJECT_STORAGE := "Storage"
const OBJECT_JSON := "JSON"
const OBJECT_FILE := "File"

## N8. The methods and properties that can carry behaviour words at all. Checked BEFORE the object's
## class is resolved, so an ordinary call or assignment - which is most of them - never pays for a
## class lookup it cannot use, and so the whole set of lines these words may claim reads in one place.
const BEHAVIOUR_METHODS: PackedStringArray = [
	"apply_impulse", "apply_central_impulse", "apply_force", "apply_central_force",
	"make_current", "restart"
]
const BEHAVIOUR_MEMBERS: PackedStringArray = [
	"linear_velocity", "angular_velocity", "emitting", "zoom"
]
## N8. The classes each behaviour's words belong to, resolved through ClassDB so the 2D and 3D twins
## and any subclass of them answer alike.
const BODY_CLASSES: PackedStringArray = ["RigidBody2D", "RigidBody3D"]
const CAMERA_CLASSES: PackedStringArray = ["Camera2D", "Camera3D"]
const PARTICLE_CLASSES: PackedStringArray = [
	"GPUParticles2D", "GPUParticles3D", "CPUParticles2D", "CPUParticles3D"
]

## M38. Vector constants read as the point they ARE - an event sheet writes (0, 0), never a namespaced
## name. `INF` keeps the infinity sign the bare constant reads as, in each axis.
const VECTOR2_CONSTANTS: Dictionary = {
	"ZERO": "(0, 0)", "ONE": "(1, 1)", "INF": "(∞, ∞)",
	"UP": "up", "DOWN": "down", "LEFT": "left", "RIGHT": "right"
}
const VECTOR3_CONSTANTS: Dictionary = {
	"ZERO": "(0, 0, 0)", "ONE": "(1, 1, 1)", "INF": "(∞, ∞, ∞)",
	"UP": "up", "DOWN": "down", "LEFT": "left", "RIGHT": "right",
	"FORWARD": "forward", "BACK": "back"
}
## M38. The bare constants with a symbol every reader knows. `NAN` deliberately stays `NAN`: it has
## no symbol a reader would recognise, and "not a number" is longer than the word it replaces.
const GLOBAL_CONSTANTS: Dictionary = {"PI": "π", "TAU": "τ", "INF": "∞"}

## M38. The types whose SCREAMING_CASE members are constants this lens may spell out.
const VECTOR2_TYPES: PackedStringArray = ["Vector2", "Vector2i"]
const VECTOR3_TYPES: PackedStringArray = ["Vector3", "Vector3i"]

## M40. The classes whose `play` / `stop` are the event-sheet animation verbs, and the ones whose
## are the event-sheet Audio object. Matched through ClassDB, so a subclass counts as its base.
const ANIMATION_CLASSES: PackedStringArray = ["AnimatedSprite2D", "AnimatedSprite3D", "AnimationPlayer"]
const AUDIO_CLASSES: PackedStringArray = ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]

## M43. An event-sheet object has an ANGLE, and its own place is just "position" - so a distance or an
## angle measured FROM the object's own place names only the other end.
const OWN_POSITION_NAMES: PackedStringArray = ["position", "global_position"]

## P6. An event sheet switches a whole group of events on and off; Godot switches an object's
## callbacks. The two are the same gesture, so the switch reads in the sheet's own activation words -
## the WHAT of each switch, with "activated" / "deactivated" after it.
const PROCESS_SWITCH_WORDS: Dictionary = {
	"set_process": "Every tick (draw)",
	"set_physics_process": "Every tick (physics)",
	"set_process_input": "input",
	"set_process_unhandled_input": "unhandled input",
	"set_process_unhandled_key_input": "unhandled key input"
}

## P6. `process_mode` in the sheet's words. An event sheet says whether a thing runs, always runs, or
## only runs while paused; these are Godot's five spellings of exactly that.
const PROCESS_MODE_WORDS: Dictionary = {
	"PROCESS_MODE_DISABLED": "disabled",
	"PROCESS_MODE_INHERIT": "enabled",
	"PROCESS_MODE_ALWAYS": "always active",
	"PROCESS_MODE_PAUSABLE": "pausable",
	"PROCESS_MODE_WHEN_PAUSED": "active only when paused"
}

## M43/M46. Members whose event-sheet word differs from Godot's. The Godot spelling stays one hover
## away, so the two vocabularies remain learnable side by side.
const MEMBER_WORDS: Dictionary = {
	"rotation_degrees": "angle",
	"rotation": "angle (radians)"
}

## Godot call shapes that have one settled event-sheet sentence. Curated on purpose: an entry is added
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
	# M32. Each of these has exactly one event-sheet sentence, and each matches the vocabulary's own
	# wording for the same thing, so a typed line and the picked ACE read alike.
	"randi_range": "random whole number {0} to {1}",
	"randf_range": "random number {0} to {1}",
	"rad_to_deg": "{0} in degrees",
	"snapped": "{0} snapped to {1}",
	"snappedf": "{0} snapped to {1}",
	"snappedi": "{0} snapped to {1}",
	"len": "{0}' count",
	# N6. A power is spelled with the caret a reader types into an expression field.
	"pow": "{0} ^ {1}"
}

## M32. Idioms whose reading needs the RECEIVER as well as the arguments, keyed "receiver.method" for
## the ones that only make sense on one object (`Input.get_vector`) and bare for the ones that read the
## same on anything (`arr.size()`).
## The input-vector wording is the published Input Vector ACE's own sentence rather than the mockup's
## "direction from", so a typed `Input.get_vector(...)` and the picked row read the same words.
const RECEIVER_IDIOMS: Dictionary = {
	"size": "{receiver}' count",
	"direction_to": "direction from {receiver} to {0}",
	"Input.get_vector": "input vector {0}/{1}/{2}/{3}",
	"Input.get_axis": "axis {0}/{1}",
	# M43. The vector words the Vectors module's own ACEs use, so a typed line and a picked row read
	# alike. The dot product keeps its mathematical sign, which is what a reader of the formula sees.
	"length": "length of {receiver}",
	"normalized": "{receiver}, normalized",
	"dot": "{receiver} · {0}",
	# M44. Emptiness IS a count in an event sheet - there is no "is empty" condition, only "count = 0".
	"is_empty": "{receiver}' count = 0",
	# ── N6 - text under the SYSTEM EXPRESSION names a reader types into a field ──────────────────
	# Deliberately NOT translated: `uppercase`, `left`, `mid`, `find`, `replace`, `trim` and `split`
	# are identifiers a reader types, exactly like `max` and `min` above. The few word-shaped ones
	# follow the rule the table already set with `direction from ... to ...`.
	# `length` is deliberately absent: M43 already reads it as "length of x", which is the honest
	# answer for a vector as well as for text, where a `len(...)` would have implied a count.
	"to_upper": "uppercase({receiver})",
	"to_lower": "lowercase({receiver})",
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

## M43. The measurements whose reading depends on WHERE they are measured from: `position.distance_to(b)`
## is the object's own distance to b, while `a.distance_to(b)` has two ends worth naming.
const MEASURED_IDIOMS: Dictionary = {
	"distance_to": ["distance to {0}", "distance from {receiver} to {0}"],
	"angle_to": ["angle to {0}", "angle from {receiver} to {0}"],
	"angle_to_point": ["angle to {0}", "angle from {receiver} to {0}"]
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


## The event-sheet reading of ONE GDScript statement, or {} when no shape is recognised.
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
	# M47. A `get_node("A/B")` lookup names the same object `$A/B` does, so the whole grammar below
	# sees the spelling it already understands.
	var text: String = node_lookup_text(code.strip_edges())
	if text.is_empty() or text.begins_with("#"):
		return {}
	var keyword: String = leading_word(text)
	if keyword == "await":
		return _with_indent(_await_statement(text, context), indent)
	# M33. The event-sheet words for the two loop steps. Claimed only for the BARE keyword, so a
	# `break` that is part of something longer is not mistaken for the statement.
	if text == "break":
		return _with_indent(_sentence(OBJECT_SYSTEM, "Stop loop", {}), indent)
	if text == "continue":
		return _with_indent(_sentence(OBJECT_SYSTEM, "Next", {}), indent)
	# N11. A pause point is marked ON the row, so a bare `breakpoint` says nothing in words: the caller
	# reads the flag and lights the sheet's own breakpoint dot. Display only - the statement in the file
	# is untouched, and the one blank segment keeps the row an ordinary row to select, hover and open.
	if text == "breakpoint":
		return _with_indent({"object": "", "segments": [{"text": " ", "tone": "plain"}], "breakpoint": true}, indent)
	# Control flow is a BRANCH, not a step, and it already renders as its own structure elsewhere.
	if keyword in ["if", "elif", "else", "for", "while", "match", "pass", "break", "continue"]:
		return {}
	if keyword == "return":
		return _with_indent(_return_statement(text, context), indent)
	# N7. A file handle is OPENED, not declared: `var f = FileAccess.open(...)` is the open-the-file row,
	# with the handle named after it rather than in front of it. Checked ahead of the declaration
	# reading, which would otherwise show the GDScript call as the local's value.
	var opened_file: Dictionary = _file_open_statement(text, context)
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


## The event-sheet reading of ONE boolean expression - the text of an `if`, or the expression an
## Expression Is True row carries. {} when nothing is recognised, so the caller keeps its own text.
static func condition(expression: String, context: Dictionary = {}) -> Dictionary:
	var text: String = node_lookup_text(expression.strip_edges())
	if text.is_empty():
		return {}
	var self_object: String = str(context.get("self_object", OBJECT_SYSTEM))
	# `if crouching:` - a bare flag is the event-sheet "is boolean set" condition. An engine flag of the
	# script's own object (`visible`) belongs to that object instead (M25).
	if is_identifier(text):
		var flag_object: String = script_object(context) if is_engine_property(text, context) else self_object
		return _sentence(flag_object, "{name} is true", {"name": [text, "name"]})
	if text.begins_with("not ") and is_identifier(text.substr(4).strip_edges()):
		var bare_flag: String = text.substr(4).strip_edges()
		var negated_object: String = script_object(context) if is_engine_property(bare_flag, context) else self_object
		return _sentence(negated_object, "{name} is false", {"name": [bare_flag, "name"]})
	# ── M41 / M44 / M47 ─────────────────────────────────────────────────────────────────────────
	# The event-sheet questions, before the general shapes: a body's movement state, an overlap, a
	# count, and a property read through `get("name")` all have one settled sentence each.
	var body_state: Dictionary = _body_state_condition(text, context)
	if not body_state.is_empty():
		return body_state
	var overlap: Dictionary = _overlap_condition(text, context)
	if not overlap.is_empty():
		return overlap
	var movement: Dictionary = _movement_condition(text, context)
	if not movement.is_empty():
		return movement
	var counted: Dictionary = _count_condition(text, context)
	if not counted.is_empty():
		return counted
	var property_test: Dictionary = _object_property_condition(text, context)
	if not property_test.is_empty():
		return property_test
	var group_test: Dictionary = _group_condition(text, context)
	if not group_test.is_empty():
		return group_test
	# ── N5 / N7 ─────────────────────────────────────────────────────────────────────────────────
	# The questions every gameplay script asks that still read as operators today: what an object IS,
	# what a table or a list HOLDS, what an object HAS, and what storage holds. Ahead of the comparison
	# readings, none of which can claim an `is` / `in` / `has_*` line anyway.
	var type_test: Dictionary = _type_condition(text, context)
	if not type_test.is_empty():
		return type_test
	var membership: Dictionary = _membership_condition(text, context)
	if not membership.is_empty():
		return membership
	var capability: Dictionary = _capability_condition(text, context)
	if not capability.is_empty():
		return capability
	var in_editor: Dictionary = _editor_condition(text)
	if not in_editor.is_empty():
		return in_editor
	var storage_test: Dictionary = _storage_condition(text, context)
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
	var rewritten: String = expression_text(text, context)
	if rewritten != text:
		return _sentence("", "{value}", {"value": [rewritten, "value"]})
	return {}


## The event-sheet reading of a condition that may be a RUN of conjuncts (M23): `host != null and
## host.is_on_wall()` reads `host exists and host is on wall`, each conjunct through `condition()`.
##
## Returns {"object", "pieces"} - `pieces` an array of [text, tone] the caller draws in order, and
## `object` the row's object label, filled only when every conjunct belongs to the SAME object (with
## more than one object in play the words go inline instead, the way an event-sheet cell names each).
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
	# way an event-sheet cell repeats the object picture in every condition it draws.
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


## One conjunct's reading: the ordinary condition path first, then the predicate-call fallback an
## event-sheet cell needs (`host.is_on_wall()` is an object and a question, not a line of code).
static func _condition_reading(part: String, context: Dictionary) -> Dictionary:
	var text: String = part.strip_edges()
	# M44. An event sheet has no "is not empty": the reading of a non-empty list is its count, and the
	# negation belongs INSIDE the comparison rather than as a mark on a count that reads "= 0".
	var not_empty: Dictionary = _not_empty_reading(text, context)
	if not not_empty.is_empty():
		return not_empty
	var negated: bool = false
	if text.begins_with("not ") and not is_identifier(text.substr(4).strip_edges()):
		negated = true
		text = text.substr(4).strip_edges()
	var reading: Dictionary = condition(text, context)
	if reading.is_empty():
		reading = _predicate_call_reading(text)
	if reading.is_empty():
		reading = {"object": "", "segments": [{"text": expression_text(text, context), "tone": "value"}]}
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


## `Input.is_action_pressed("jump")` and its just-pressed sibling, as the Keyboard rows a reader
## coming from another event-sheet editor already knows. Shared by the raw path and by the two Core
## input ACEs, so both read alike.
static func input_action_sentence(action_value: String, just_pressed: bool) -> Dictionary:
	var shown: String = strip_action_name(action_value)
	if shown.is_empty():
		return {}
	# Q8. The DEVICE the project bound the action to picks the object, so the object column tells the
	# truth about where the input comes from. An unbound or unknown action stays with Keyboard.
	var device: String = input_action_object(action_value)
	if just_pressed:
		return _sentence(device, "On {action} pressed", {"action": [shown, "value"]})
	return _sentence(device, "{action} is down", {"action": [shown, "value"]})


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
			var chip: String = expression_text(values[index], context)
			if index < parameter_names.size():
				chip = "%s = %s" % [parameter_names[index], chip]
			segments.append({"text": "   ", "tone": "plain"})
			segments.append({"text": chip, "tone": "value"})
		return {"object": owner, "segments": segments}
	return _sentence(owner, "Signal {trigger} {values}", {
		"trigger": [trigger, "name"],
		"values": [expression_text(payload, context), "value"]
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


## The reading of a `return`, given the kind of verb whose body it sits in (M14). The event-sheet function
## block has exactly one action for handing a value back - `Set return value to X` - so a published
## CONDITION and a published EXPRESSION both read that, with `true` / `false` as themselves. An
## action's bare `return` is `Stop event` (the rest of the event does not run). Shared with the Core
## Return row so a picked row and a typed one read alike.
static func return_sentence(returned: String, context: Dictionary) -> Dictionary:
	var verb_kind: int = int(context.get("verb_kind", VerbKind.ACTION))
	var value: String = returned.strip_edges()
	if value.is_empty():
		return _sentence(str(context.get("self_object", OBJECT_SYSTEM)), "Stop event", {})
	var shown: String = expression_text(value, context)
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


## A value expression with the Godot idioms replaced by their event-sheet reading and every type
## annotation dropped (M11 + M18). Returns the text unchanged when nothing is recognised.
static func expression_text(text: String, context: Dictionary = {}) -> String:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return trimmed
	var without_cast: String = _drop_casts(_system_words(node_lookup_text(trimmed)))
	# M31 before the call rewriting: a join is decided by the WHOLE expression's shape (is any part of
	# it text?), which the innermost-first call pass would have already taken apart.
	# A whole value wrapped in `str(...)` is the same value: an event sheet shows numbers in text without
	# a conversion, so the conversion is a GDScript chore rather than part of what the row says.
	var joined: String = _rewrite_format(_rewrite_dot_format(_string_call_value(without_cast)))
	joined = _rewrite_join(joined)
	var rewritten: String = _rewrite_calls(joined)
	rewritten = _rewrite_indexing(rewritten)
	# N5 last, so no earlier pass ever has to recognise a glyph it did not write.
	return comparison_symbols(constant_words(_rewrite_delta(_tidy_numbers(rewritten)), context))


## N5. The reader's sheet writes ≥, ≤ and ≠ where GDScript writes >=, <= and !=. A language needs the
## two-character spelling; a row is only ever the question, so it says the question the way a reader
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


## N6. `"{0}: {1}".format([a, b])` and the `%s` spelling of the same call, unrolled into the join.
## Claimed only when the WHOLE value is that one call on a literal pattern and every value it was
## handed is used exactly once - a half-unrolled format shows a reader a value in the wrong place.
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


## M45. The system values an event-sheet reader types by name - the viewport's size, the pointer, the
## clock, the frame rate. Whole-spelling replacements on purpose: each of these is one exact Godot
## phrase with one exact event-sheet word, and a looser match would rename somebody's own helper.
static func _system_words(text: String) -> String:
	var out: String = _group_count_words(text)
	if out.contains("get_viewport_rect()"):
		out = out.replace("get_viewport_rect().size.x", translate("viewport width"))
		out = out.replace("get_viewport_rect().size.y", translate("viewport height"))
	if out.contains("mouse_position"):
		out = out.replace("get_viewport().get_mouse_position()", translate("mouse position"))
		out = out.replace("get_global_mouse_position()", translate("mouse position"))
		out = out.replace("get_local_mouse_position()", translate("mouse position"))
	if out.contains("Time.get_ticks_msec()"):
		# The seconds form first: `/ 1000.0` is what makes the number the event-sheet `time`, and the bare
		# call is milliseconds, which is a different number and says so.
		out = out.replace("Time.get_ticks_msec() / 1000.0", translate("time"))
		out = out.replace("Time.get_ticks_msec() / 1000", translate("time"))
		out = out.replace("Time.get_ticks_msec()", translate("time in ms"))
	out = out.replace("Engine.get_frames_per_second()", translate("fps"))
	return editor_words(out)


## R30. The four things a tool script asks the EDITOR for, in the Editor object's own names. Whole
## spellings again, and deliberately dotted (`Editor.SelectedObjects`) because that is how an event
## sheet writes an object's expression - the same shape as `Mouse.X` or `System.Time`, so a reader who
## has met one has met all four. The names are identifiers a reader types into an expression field, so
## like `max` and `min` above they are NOT translated.
##
## Public because a loop row shows its collection WITHOUT the rest of the value lens (a loop over a
## group already reads as a group), and `for n in Editor.SelectedObjects` is the one line of a tool
## that must not read as engine plumbing.
static func editor_words(text: String) -> String:
	if not text.contains("Editor") and not text.contains("get_undo_redo()"):
		return text
	var out: String = text
	out = out.replace("EditorInterface.get_selection().get_selected_nodes()", "Editor.SelectedObjects")
	out = out.replace("EditorInterface.get_edited_scene_root()", "Editor.OpenLayout")
	out = out.replace("EditorInterface.get_editor_settings()", "Editor.Settings")
	out = out.replace("get_undo_redo()", "Editor.UndoHistory")
	return out


## M44. `get_tree().get_nodes_in_group("enemies").size()` is the instance count of a family:
## the group is the OBJECT and the count is what the row shows. Only a LITERAL group name is claimed -
## a variable group has no word a row could honestly print.
static func _group_count_words(text: String) -> String:
	const HEAD := "get_tree().get_nodes_in_group("
	var out: String = text
	var guard: int = 0
	while guard < 8:
		guard += 1
		var at: int = out.find(HEAD)
		if at < 0:
			return out
		var close_at: int = closing_paren(out, at + HEAD.length() - 1)
		if close_at < 0:
			return out
		var group_value: String = out.substr(at + HEAD.length(), close_at - at - HEAD.length())
		var tail: String = out.substr(close_at + 1)
		if not _is_string_literal(group_value) or not tail.begins_with(".size()"):
			return out
		out = "%s%s %s %s%s" % [out.substr(0, at), _unquote(group_value.strip_edges().trim_prefix("&")),
			translate("(group)"), translate("count"), tail.substr(".size()".length())]
	return out


## M47. `get_node("A/B")` and `get_node_or_null("A/B")` name a node exactly as `$A/B` does, so they
## read as the same object. Display only - the statement the file holds is untouched.
static func node_lookup_text(text: String) -> String:
	var out: String = text
	for head: String in ["get_node_or_null(", "get_node("]:
		var guard: int = 0
		while guard < 8:
			guard += 1
			var at: int = out.find(head)
			if at < 0:
				break
			var close_at: int = closing_paren(out, at + head.length() - 1)
			if close_at < 0:
				break
			var path_value: String = out.substr(at + head.length(), close_at - at - head.length())
			if not _is_string_literal(path_value):
				break
			var path: String = _unquote(path_value.strip_edges().trim_prefix("&"))
			if path.is_empty() or path.contains(" "):
				break
			out = "%s$%s%s" % [out.substr(0, at), path, out.substr(close_at + 1)]
	return out


## M38. Named constants as an event sheet writes them: no namespace, and a symbol where one exists.
##
##   State.PATROL   -> PATROL     (when the sheet declares that member exactly once)
##   Vector2.ZERO   -> (0, 0)
##   Vector3.UP     -> up
##   Color.RED      -> red
##   PI / TAU / INF -> π / τ / ∞
##
## Only SCREAMING_CASE members are touched - those are the constants - and only outside string
## literals. An enum member is claimed only when `context` says the sheet declares that enum and no
## other enum on the sheet has a member by the same name, because `Facing.LEFT` and `Wall.LEFT` in one
## file need their enum to stay readable.
static func constant_words(text: String, context: Dictionary = {}) -> String:
	if text.is_empty():
		return text
	var out: String = ""
	var token: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if character == "\"" or character == "'":
			out += _constant_token(token, context)
			token = ""
			var quote_end: int = _string_end(text, index)
			out += text.substr(index, quote_end - index + 1)
			index = quote_end + 1
			continue
		var is_token_character: bool = (
			character == "_"
			or character == "."
			or (character >= "a" and character <= "z")
			or (character >= "A" and character <= "Z")
			or (character >= "0" and character <= "9")
		)
		if is_token_character:
			token += character
		else:
			# A token followed by "(" is a CALL - `Color.from_hsv(...)` is not the colour word red.
			out += token if character == "(" else _constant_token(token, context)
			token = ""
			out += character
		index += 1
	return out + _constant_token(token, context)


## One token of constant_words: a `Type.MEMBER` constant, a bare `PI`, or the token untouched.
static func _constant_token(token: String, context: Dictionary) -> String:
	if token.is_empty():
		return token
	if not token.contains("."):
		return str(GLOBAL_CONSTANTS.get(token, token))
	var parts: PackedStringArray = token.split(".", false)
	if parts.size() != 2 or not is_identifier(parts[0]) or not is_identifier(parts[1]):
		return token
	var head: String = parts[0]
	var member: String = parts[1]
	# Constants are written in caps deliberately; anything else is a property read, not a constant.
	if member.to_upper() != member or member.to_lower() == member:
		return token
	if VECTOR2_TYPES.has(head) and VECTOR2_CONSTANTS.has(member):
		return str(VECTOR2_CONSTANTS[member])
	if VECTOR3_TYPES.has(head) and VECTOR3_CONSTANTS.has(member):
		return str(VECTOR3_CONSTANTS[member])
	if head == "Color":
		return member.to_lower().replace("_", " ")
	var enums: Dictionary = context.get("enum_members", {})
	if int(enums.get(member, 0)) == 1 and (context.get("enum_names", {}) as Dictionary).has(head):
		return member
	return token


## M27. `delta` is the per-frame delta the event-sheet grammar calls `dt` - the same number under the
## name a reader coming from another event-sheet editor writes. Only the whole word is replaced, so
## `delta_v` and `_delta` keep their own names.
static func _rewrite_delta(text: String) -> String:
	if not text.contains("delta"):
		return text
	var regex: RegEx = RegEx.create_from_string("(?<![\\w.])delta(?![\\w])")
	if regex == null:
		return text
	return regex.sub(text, "dt", true)


## M31. `"a" + b` and `str(a) + " b"` read with the event-sheet join. Claimed only when a part is plainly
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


## The value inside a `str(x)` wrapper - an event sheet joins values with text directly, so the
## conversion is a GDScript chore, not part of what the row says. Anything else comes back unchanged.
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


## M31. Indexing read the way an event sheet reads a dictionary or an array: `inventory["potion"]` is
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
		"Object":
			# R31. Not a value - a THING you go on to call actions on, which is the whole point of
			# saying so on the row that declares it.
			return translate("object")
	return bare


# ── Statement shapes ────────────────────────────────────────────────────────────


## The awaits with a settled event-sheet sentence (M11 + M28): the timer wait, the two tick waits, and
## an await on a SIGNAL, which is the event-sheet "Wait for signal" verb. Every other await keeps
## its code, because a sentence must never paper over a suspension point nobody can name.
static func _await_statement(text: String, context: Dictionary = {}) -> Dictionary:
	var body: String = text.substr(6).strip_edges()
	if body.begins_with("get_tree().create_timer(") and body.ends_with(").timeout"):
		var inner: String = body.substr(24, body.length() - 24 - 9)
		if inner.strip_edges().is_empty():
			return {}
		return _sentence(OBJECT_SYSTEM, "⏳ Wait {seconds} seconds", {"seconds": [expression_text(inner, context), "value"]})
	# M28. One frame of waiting is the event-sheet tick, and which clock it is IS the one Godot fact
	# worth keeping - the two frames are different lengths.
	if body == "get_tree().process_frame":
		return _sentence(OBJECT_SYSTEM, "⏳ Wait one tick", {})
	if body == "get_tree().physics_frame":
		return _sentence(OBJECT_SYSTEM, "⏳ Wait one physics tick", {})
	return _await_signal_statement(body, context)


## M28. `await door.opened` / `await opened` as the event-sheet Wait for signal verb, naming the object the
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
## one, else the member read as words with the event-sheet "On" in front.
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
			"value": [expression_text(amount, context), "value"]
		}
		match operator:
			" += ":
				# Q6. Text is not arithmetic: `label += "!"` puts the text ON THE END, which is the
				# Append the Text module already ships. Decided by the sheet's declared type first,
				# then by the value being a literal piece of text, so a number keeps "Add".
				if _declared_type_of(target, context) == "String" or _is_string_literal(amount):
					return _sentence(str(split[0]), "Append {value} to {name}", values)
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
	if assigned.is_empty():
		return {}
	# ── M40 / M46 ───────────────────────────────────────────────────────────────────────────────
	# The property writes an event sheet spells as its own verbs (visible, opacity, mirrored, size), and
	# the two globals its glossary renames. Checked before the plain Set, and before the simple-target
	# gate, because `get_tree().paused` is a settled sentence even though it assigns through a call.
	var engine_verb: Dictionary = _engine_verb_assignment(target, assigned, context)
	if not engine_verb.is_empty():
		return engine_verb
	if not is_simple_target(target):
		return {}
	var split: Array = _split_object(target, context)
	var object_name: String = str(split[0])
	# N8. A property every reader knows as a BEHAVIOUR knob - a body's velocity, a camera's zoom, an
	# emitter's switch - reads in that behaviour's words, decided by the object's known class.
	var behaviour: Dictionary = _behaviour_assignment(object_name, str(split[1]), assigned, target, context)
	if not behaviour.is_empty():
		return behaviour
	# M45. The pointer is the event-sheet Mouse object for the same reason the stick is Keyboard's.
	# Ahead of the service reading below, so the pointer keeps the object M45 gave it.
	if object_name == OBJECT_SYSTEM and _system_words(assigned) != assigned and assigned.contains("mouse_position"):
		object_name = OBJECT_MOUSE
	# M32 / N7 / N9. The engine's services are filed as OBJECTS: reading the stick belongs to Keyboard,
	# saving belongs to Storage, parsing belongs to JSON - exactly as the picked rows do.
	if object_name == OBJECT_SYSTEM:
		var service: String = value_object(assigned)
		if not service.is_empty():
			object_name = service
	# ── Q5 / Q11 ────────────────────────────────────────────────────────────────────────────────
	# The value's own words, when the SLOT says what kind of value it is: a 0..1 setting reads as a
	# percentage, and a number written where an enum is expected reads as the member it names. Both
	# are display only - the row still holds the number the file wrote.
	var shown_value: String = expression_text(assigned, context)
	if is_fraction_member(target, str(split[1]), context) and assigned.strip_edges().is_valid_float():
		shown_value = _percent_words(assigned, context)
	else:
		var member_name: String = enum_value_words(object_name, target, str(split[1]), assigned, context)
		if not member_name.is_empty():
			shown_value = member_name
	return _sentence(object_name, "Set {name} to {value}", {
		"name": [str(split[1]), "name"],
		"value": [shown_value, "value"]
	})


## M40/M46. The assignments an event sheet writes as a verb rather than as a property write, and the
## two Godot globals its glossary gives an event-sheet noun to. {} for everything else, which is the
## caller's cue to keep the plain "Set X to Y" it already reads.
##
##   visible = false        Player ▸ Set invisible          (a CanvasLayer ▸ Set layer invisible)
##   modulate.a = 0.5       Player ▸ Set opacity to 50%
##   flip_h = true          Sprite2D ▸ Set mirrored
##   scale = Vector2(2, 2)  Player ▸ Set size to 200%
##   get_tree().paused = true   System ▸ Set time scale to 0 (pause)   (Familiar Words only)
static func _engine_verb_assignment(target: String, assigned: String, context: Dictionary) -> Dictionary:
	var familiar_words: bool = bool(context.get("familiar_words", false))
	var bare_target: String = target.strip_edges().trim_prefix("self.")
	# M46. Godot pauses the tree; an event sheet sets the time scale, and 0 IS the pause.
	if familiar_words and bare_target == "get_tree().paused":
		if assigned == "true":
			return _sentence(OBJECT_SYSTEM, "Set time scale to 0 (pause)", {})
		if assigned == "false":
			return _sentence(OBJECT_SYSTEM, "Set time scale to 1", {})
		return {}
	if familiar_words and bare_target == "Engine.time_scale":
		return _sentence(OBJECT_SYSTEM, "Set time scale to {value}", {"value": [expression_text(assigned, context), "value"]})
	if not is_simple_target(bare_target):
		return {}
	var dot_at: int = bare_target.rfind(".")
	var member: String = bare_target if dot_at < 0 else bare_target.substr(dot_at + 1)
	var owner_text: String = "" if dot_at < 0 else bare_target.substr(0, dot_at)
	# `modulate.a` owns two segments, so the object is whatever precedes BOTH of them.
	var alpha_write: bool = (member == "a") and (owner_text == "modulate" or owner_text == "self_modulate"
		or owner_text.ends_with(".modulate") or owner_text.ends_with(".self_modulate"))
	if alpha_write:
		var alpha_dot: int = owner_text.rfind(".")
		owner_text = "" if alpha_dot < 0 else owner_text.substr(0, alpha_dot)
	var object_name: String = _receiver_object(owner_text, context)
	var object_class: String = object_class_of(object_name, context)
	if alpha_write:
		return _sentence(object_name, "Set opacity to {value}", {"value": [_percent_words(assigned, context), "value"]})
	match member:
		"visible":
			if assigned != "true" and assigned != "false":
				return {}
			var is_layer: bool = familiar_words and _class_is_any(object_class, PackedStringArray(["CanvasLayer"]))
			var layer_label: String = "%s %s" % [object_name, translate("(layer)")] if is_layer else object_name
			if is_layer:
				return _sentence(layer_label, "Set layer visible" if assigned == "true" else "Set layer invisible", {})
			return _sentence(object_name, "Set visible" if assigned == "true" else "Set invisible", {})
		"flip_h":
			if assigned != "true" and assigned != "false":
				return {}
			return _sentence(object_name, "Set mirrored" if assigned == "true" else "Set not mirrored", {})
		"flip_v":
			if assigned != "true" and assigned != "false":
				return {}
			return _sentence(object_name, "Set flipped" if assigned == "true" else "Set not flipped", {})
		"scale":
			var uniform: String = _uniform_scale_factor(assigned)
			if uniform.is_empty():
				return {}
			return _sentence(object_name, "Set size to {value}", {"value": [uniform, "value"]})
		"process_mode":
			# ── P6 ────────────────────────────────────────────────────────────────────────────
			# Whether an object runs at all is a SWITCH in an event sheet, not a property write, and
			# Godot's constant already names which of the five states it is. Both spellings resolve,
			# because a `@tool` script often writes the qualified one.
			var mode: String = assigned.strip_edges()
			var dot_in_mode: int = mode.rfind(".")
			if dot_in_mode >= 0:
				mode = mode.substr(dot_in_mode + 1)
			if not PROCESS_MODE_WORDS.has(mode):
				return {}
			return _sentence(object_name, "Set {mode}", {
				"mode": [translate(str(PROCESS_MODE_WORDS[mode])), "name"]})
	return {}


## M40. A fraction as the percentage an event sheet shows (`0.5` -> `50%`). A value that is not a plain
## number keeps its own reading - "opacity to hp / max_hp" is honest, "opacity to hp / max_hp%" is not.
static func _percent_words(value: String, context: Dictionary) -> String:
	var text: String = value.strip_edges()
	if not text.is_valid_float():
		return expression_text(text, context)
	var percent: float = text.to_float() * 100.0
	var shown: String = String.num(percent, 4).rstrip("0").rstrip(".")
	return "%s%%" % ("0" if shown.is_empty() else shown)


## M40. `Vector2(2, 2)` as the event-sheet size percentage, or "" when the scale is not the SAME on every
## axis - a non-uniform scale is two numbers, and one percentage would hide one of them.
static func _uniform_scale_factor(value: String) -> String:
	var text: String = value.strip_edges()
	var open_at: int = text.find("(")
	if open_at <= 0 or not text.ends_with(")"):
		return ""
	if not VECTOR_CONSTRUCTORS.has(text.substr(0, open_at)):
		return ""
	var axes: PackedStringArray = _split_arguments(text.substr(open_at + 1, text.length() - open_at - 2))
	if axes.is_empty():
		return ""
	for axis: String in axes:
		if not axis.strip_edges().is_valid_float() or axis.strip_edges() != axes[0].strip_edges():
			return ""
	return _percent_words(axes[0], {})


## The call shapes with a settled sentence: destroy, emit, change scene. Anything else is left to the
## caller's own Object / Verb / parameters rendering.
static func _call_statement(text: String, context: Dictionary) -> Dictionary:
	# Checked before the plain call split, because the receiver is itself a call: `get_tree()` is not
	# an object a sentence can name, but the scene switch behind it is a settled event-sheet action.
	const SCENE_HEAD := "get_tree().change_scene_to_file("
	if text.begins_with(SCENE_HEAD) and text.ends_with(")"):
		var scene_path: String = text.substr(SCENE_HEAD.length(), text.length() - SCENE_HEAD.length() - 1)
		if not scene_path.strip_edges().is_empty():
			# M46. An event sheet calls a scene a LAYOUT, and names it without its folder or its extension.
			if bool(context.get("familiar_words", false)):
				return _sentence(OBJECT_SYSTEM, "Go to layout {path}", {
					"path": ["\"%s\"" % _unquote(scene_path).get_file().get_basename(), "value"]})
			# The path stays a quoted string, so a reader (and the name lens) sees content, not a name.
			return _sentence(OBJECT_SYSTEM, "Go to scene {path}", {"path": ["\"%s\"" % _unquote(scene_path), "value"]})
	# M46. Godot reloads the current scene; an event sheet restarts the layout.
	if bool(context.get("familiar_words", false)) and text == "get_tree().reload_current_scene()":
		return _sentence(OBJECT_SYSTEM, "Restart layout", {})
	# ── P6 ──────────────────────────────────────────────────────────────────────────────────────
	# The one-shot timer and its callback, ahead of every other call shape: the receiver is itself a
	# call, so nothing below could name it, and the sheet already has the "wait, then" this line is.
	var wait_then: Dictionary = _wait_then_statement(text, context)
	if not wait_then.is_empty():
		return wait_then
	var group_call: Dictionary = _group_call_statement(text, context)
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
	# ── M40 / M43 / M47 ─────────────────────────────────────────────────────────────────────────
	# The calls an event sheet writes as one of its own verbs: an animation, a sound, a visibility switch,
	# an angle, and a property set by name.
	var engine_verb: Dictionary = _engine_verb_call(call, context)
	if not engine_verb.is_empty():
		return engine_verb
	# M25/M26. `queue_free()` on ANY object is the event-sheet Destroy verb, including the script's
	# own object - which is named, never `self`.
	if method == "queue_free" and args.is_empty():
		if target.is_empty() or target == "self":
			object_name = script_object(context)
		return _sentence(object_name, "Destroy", {})
	# M30. A group is the nearest thing Godot has to an event-sheet family, so joining one says so.
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
	# ── Q6 / Q7 ─────────────────────────────────────────────────────────────────────────────────
	# The list and table steps in the sheet's own verbs, and the deferred family - which reads as the
	# step it is with the delay said out loud, exactly as `queue_free()` already does above.
	var list_step: Dictionary = _list_statement(target, method, args, context)
	if not list_step.is_empty():
		return list_step
	var deferred_step: Dictionary = _deferred_statement(target, method, args, context)
	if not deferred_step.is_empty():
		return deferred_step
	# ── N7 / N8 / N11 ───────────────────────────────────────────────────────────────────────────
	# The three families of call with settled rows of their own. Checked here, at the end of the
	# curated shapes, so an unrecognised call still falls through to M26's Object ▸ Verb chips.
	var storage_step: Dictionary = _storage_statement(target, method, args, context)
	if not storage_step.is_empty():
		return storage_step
	# R31. The undo/redo dance, on the variable that holds the history. Checked before the generic
	# Object ▸ Verb fallback so "Add do step: set n's x to left" wins over "Add do property".
	var undo_step: Dictionary = _undo_statement(target, method, args, context)
	if not undo_step.is_empty():
		return undo_step
	# A behaviour step on the script's OWN object belongs to that object by name, never to System: a
	# collision switch is something the node does, the way every other row about it reads.
	var acting_object: String = script_object(context) if target.is_empty() or target == "self" else object_name
	var behaviour_step: Dictionary = _behaviour_call(acting_object, method, args, target, context)
	if not behaviour_step.is_empty():
		return behaviour_step
	return _debug_statement(target, method, args, context)


## P6. `get_tree().create_timer(2).timeout.connect(func(): explode())` is the "wait, then" a beginner
## writes, and an event sheet already has that shape: Wait N seconds as an action, with the steps after
## it running when the wait ends. So the row says the wait, then what follows it, with a muted "then"
## between - one row, nothing hidden, and the exact GDScript still on the hover.
##
## {} unless the whole line is that shape and the callback is one step this grammar can name; a line
## that only half fits keeps its code rather than reading as a wait that quietly loses its callback.
static func _wait_then_statement(text: String, context: Dictionary) -> Dictionary:
	const TIMER_HEAD := "get_tree().create_timer("
	const CONNECT_TAIL := ".timeout.connect("
	if not text.begins_with(TIMER_HEAD) or not text.ends_with(")"):
		return {}
	var seconds_close: int = closing_paren(text, TIMER_HEAD.length() - 1)
	if seconds_close < 0:
		return {}
	var seconds: String = text.substr(TIMER_HEAD.length(), seconds_close - TIMER_HEAD.length()).strip_edges()
	if seconds.is_empty() or not text.substr(seconds_close + 1).begins_with(CONNECT_TAIL):
		return {}
	var connect_open: int = seconds_close + CONNECT_TAIL.length()
	var connect_close: int = closing_paren(text, connect_open)
	if connect_close != text.length() - 1:
		return {}
	var handed: PackedStringArray = _split_arguments(
		text.substr(connect_open + 1, connect_close - connect_open - 1))
	if handed.is_empty():
		return {}
	var then_segments: Array = _wait_body_segments(handed[0].strip_edges(), context)
	if then_segments.is_empty():
		return {}
	var waiting: Dictionary = _sentence(OBJECT_SYSTEM, "⏳ Wait {seconds} seconds", {
		"seconds": [expression_text(seconds, context), "value"]})
	var segments: Array = waiting.get("segments", []) as Array
	segments.append({"text": " %s " % translate("then"), "tone": "muted"})
	segments.append_array(then_segments)
	return {"object": OBJECT_SYSTEM, "segments": segments}


## P6. What runs when the wait ends, read as the step it is: a lambda hands over its body, and a named
## function hands over the sheet's own Call verb. [] for anything else - a bound callable or a member
## reference is not one step that can be named, and the line then keeps its code.
static func _wait_body_segments(handed: String, context: Dictionary) -> Array:
	var body: String = handed
	if body.begins_with("func("):
		var params_close: int = closing_paren(body, 4)
		if params_close < 0:
			return []
		var after: String = body.substr(params_close + 1)
		var colon_at: int = after.find(":")
		if colon_at < 0:
			return []
		var between: String = after.substr(0, colon_at).strip_edges()
		if not between.is_empty() and not between.begins_with("->"):
			return []
		body = after.substr(colon_at + 1).strip_edges()
	if body.is_empty():
		return []
	# The step's OWN reading first, so a callback the grammar already has a sentence for keeps it
	# ("Destroy", "Set hp to 0") rather than being retold as a call to a function nobody wrote.
	var step: Dictionary = statement(body, context)
	if not step.is_empty():
		var owner: String = str(step.get("object", "")).strip_edges()
		var pieces: Array = []
		if not owner.is_empty() and owner != OBJECT_SYSTEM:
			pieces.append({"text": "%s  " % owner, "tone": "object"})
		pieces.append_array(step.get("segments", []) as Array)
		return pieces
	# Whatever is left is a name: a bare callable, or a call to one of the file's own functions. Both
	# are the sheet's Call row, exactly as the picker writes it.
	if is_identifier(body):
		return [
			{"text": "%s " % translate("Call"), "tone": "plain"},
			{"text": function_words(body), "tone": "name"}
		]
	var call: Dictionary = call_parts(body)
	if call.is_empty() or not str(call.get("target", "")).strip_edges().is_empty():
		return []
	var called: Array = [
		{"text": "%s " % translate("Call"), "tone": "plain"},
		{"text": function_words(str(call.get("method", ""))), "tone": "name"}
	]
	for value: String in (call.get("args", PackedStringArray()) as PackedStringArray):
		called.append({"text": "   ", "tone": "plain"})
		called.append({"text": expression_text(value, context), "tone": "value"})
	return called


## Q6. A list or table step in the sheet's own words, or {} when the call is not one. Claimed only on a
## BARE variable name: `items.append(x)` is a list step, `config.clear()` is a call on an object whose
## own verbs read better, and only a plain identifier can be the one the List module means.
##
##   items.append(x)            System ▸ Push back x to items
##   items.insert(2, x)         System ▸ Insert x at 2 in items
##   items.remove_at(0)         System ▸ Delete at 0 in items
##   items.erase(x)             System ▸ Delete value x from items
##   inventory.erase("potion")  System ▸ Delete key "potion" from inventory
##
## `erase` is the one shape the method name cannot settle - Array and Dictionary spell two different
## steps with it - so the sheet's own declared type decides, and a table says "key".
static func _list_statement(target: String, method: String, args: PackedStringArray,
		context: Dictionary) -> Dictionary:
	var receiver: String = target.strip_edges()
	if not is_identifier(receiver) or is_engine_property(receiver, context):
		return {}
	var split: Array = _split_object(receiver, context)
	var values: Dictionary = {"name": [str(split[1]), "name"]}
	if LIST_STEPS.has(method) and args.is_empty():
		return _sentence(str(split[0]), str(LIST_STEPS[method]), values)
	if LIST_STEPS.has(method) and args.size() == 1 and str(LIST_STEPS[method]).contains("{value}"):
		values["value"] = [expression_text(args[0], context), "value"]
		return _sentence(str(split[0]), str(LIST_STEPS[method]), values)
	if method == "insert" and args.size() == 2:
		values["value"] = [expression_text(args[1], context), "value"]
		values["index"] = [expression_text(args[0], context), "value"]
		return _sentence(str(split[0]), "Insert {value} at {index} in {name}", values)
	if method == "remove_at" and args.size() == 1:
		values["index"] = [expression_text(args[0], context), "value"]
		return _sentence(str(split[0]), "Delete at {index} in {name}", values)
	if method == "erase" and args.size() == 1:
		values["value"] = [expression_text(args[0], context), "value"]
		if LIST_TYPES.has(_declared_type_of(receiver, context)):
			return _sentence(str(split[0]), "Delete value {value} from {name}", values)
		return _sentence(str(split[0]), "Delete key {value} from {name}", values)
	return {}


## Q6/Q11. The type the SHEET declared for one of its own variables, or "" when it declared none. The
## caller hands the map in, because only something able to walk the sheet knows what it says.
static func _declared_type_of(variable_name: String, context: Dictionary) -> String:
	return str((context.get("variable_types", {}) as Dictionary).get(variable_name.strip_edges(), ""))


## Q7. The deferred family, read as the step it is with the delay said out loud - the same words
## `queue_free()` already reads in, because it is the same postponement.
##
##   host.call_deferred("reset")          host ▸ Call Reset (at end of frame)
##   host.set_deferred("visible", true)   host ▸ Set visible to true (at end of frame)
##   reset.call_deferred()                Player ▸ Call Reset (at end of frame)
static func _deferred_statement(target: String, method: String, args: PackedStringArray,
		context: Dictionary) -> Dictionary:
	var receiver: String = target.strip_edges()
	var object_name: String = script_object(context) if receiver.is_empty() or receiver == "self" else object_of_reference(receiver)
	if method == "call_deferred" and args.size() == 1 and _is_string_literal(args[0]):
		return _sentence(object_name, "Call {name} (at end of frame)",
			{"name": [verb_words(_unquote(args[0])), "name"]})
	if method == "set_deferred" and args.size() == 2 and _is_string_literal(args[0]):
		return _sentence(object_name, "Set {name} to {value} (at end of frame)", {
			"name": [engine_member_name(_unquote(args[0])), "name"],
			"value": [expression_text(args[1], context), "value"]
		})
	# `reset.call_deferred()` defers a CALLABLE - the receiver is the function, not an object, so the
	# row belongs to the script's own object the way a plain call to the same function does.
	if method == "call_deferred" and args.is_empty() and is_identifier(receiver):
		return _sentence(script_object(context), "Call {name} (at end of frame)",
			{"name": [verb_words(receiver), "name"]})
	return {}


## N11. The Log verb is the debug word everyone knows, and Godot's print family is the same three
## levels under different names. `print` itself is deliberately NOT claimed: it already reads "Print",
## which is the word on its own picked row.
static func _debug_statement(target: String, method: String, args: PackedStringArray,
		context: Dictionary) -> Dictionary:
	if not target.is_empty():
		return {}
	if args.size() == 1:
		match method:
			"push_error", "printerr":
				return _sentence(OBJECT_SYSTEM, "Log error {value}",
					{"value": [expression_text(args[0], context), "value"]})
			"push_warning":
				return _sentence(OBJECT_SYSTEM, "Log warning {value}",
					{"value": [expression_text(args[0], context), "value"]})
			"print_rich":
				return _sentence(OBJECT_SYSTEM, "Log {value}",
					{"value": [expression_text(args[0], context), "value"]})
	if method != "assert" or args.is_empty() or args.size() > 2:
		return {}
	if args.size() == 1:
		return _sentence(OBJECT_SYSTEM, "Assert {condition}",
			{"condition": [expression_text(args[0], context), "value"]})
	return _sentence(OBJECT_SYSTEM, "Assert {condition} {message}", {
		"condition": [expression_text(args[0], context), "value"],
		"message": [expression_text(args[1], context), "plain"]
	})


## N7. The ConfigFile and FileAccess STEPS, in the Local Storage / AJAX words.
##
## `save` and `load` are ordinary English and live on plenty of other classes, so they are claimed
## only for a literal path that plainly names a config file - which is the one spelling that says
## "this is storage" without asking what the receiver holds at run time.
static func _storage_statement(target: String, method: String, args: PackedStringArray,
		context: Dictionary) -> Dictionary:
	if target.is_empty():
		return {}
	if method == "set_value" and args.size() == 3:
		return _sentence(OBJECT_STORAGE, "Set item {key} to {value} (section {section})", {
			"key": [expression_text(args[1], context), "value"],
			"value": [expression_text(args[2], context), "value"],
			"section": [expression_text(args[0], context), "plain"]
		})
	if method == "store_string" and args.size() == 1:
		return _sentence(object_of_reference(target), "Write {text}",
			{"text": [expression_text(args[0], context), "value"]})
	if (method != "save" and method != "load") or args.size() != 1 or not _is_config_path(args[0]):
		return {}
	if method == "save":
		return _sentence(OBJECT_STORAGE, "Save {file}", {"file": [file_name_value(args[0], context), "value"]})
	return _sentence(OBJECT_STORAGE, "Load {file}", {"file": [file_name_value(args[0], context), "value"]})


## R31. The two spellings that hand a tool the editor's undo history. Both read as one thing, so a
## reader never has to know that `get_undo_redo()` (on a plugin) and the EditorInterface spelling
## (anywhere else) are the same object.
const UNDO_HISTORY_CALLS: PackedStringArray = [
	"get_undo_redo()", "EditorInterface.get_editor_undo_redo()"
]


## R31. Every step of the undo/redo dance, as an action ON the variable that holds the history -
## Object then Verb, exactly like every other row about an object. The history is an ordinary local
## object variable, so `ur` is the object cell and the step is the sentence; a reader who can read
## `Player ▸ Set position` can read `ur ▸ Add do step: set n's x to left` without learning anything new.
##
## Only these seven method names are claimed, and only with the argument counts the engine defines, so
## a user's own `commit_action()` on something else keeps its plain reading. The property PATH reads as
## its last segment (`"position:x"` is `x`): the rest is Godot's addressing, and the object is already
## named in the sentence. A method name reads as the sheet's word for that function (`_refresh` is
## `Refresh`), the same words a Call row uses.
static func _undo_statement(target: String, method: String, args: PackedStringArray,
		context: Dictionary) -> Dictionary:
	if target.is_empty() or not is_simple_target(target):
		return {}
	match method:
		"create_action":
			if args.size() >= 1:
				return _sentence(target, "Begin undoable action {name}",
					{"name": [_quoted(args[0]), "value"]})
		"commit_action":
			if args.size() <= 1:
				return _sentence(target, "Commit undoable action", {})
		"add_do_property", "add_undo_property":
			if args.size() == 3:
				var step: String = "Add do step: set {object}'s {member} to {value}" if method == "add_do_property" \
					else "Add undo step: set {object}'s {member} to {value}"
				return _sentence(target, step, {
					"object": [expression_text(args[0], context), "object"],
					"member": [_undo_member_word(args[1]), "name"],
					"value": [expression_text(args[2], context), "value"]
				})
		"add_do_method", "add_undo_method":
			if args.size() >= 2:
				var call_step: String = "Add do step: call {name}" if method == "add_do_method" \
					else "Add undo step: call {name}"
				return _sentence(target, call_step,
					{"name": [function_words(_unquote(args[1])), "name"]})
		"add_do_reference":
			if args.size() == 1:
				return _sentence(target, "Add do step: keep {object}",
					{"object": [expression_text(args[0], context), "object"]})
	return {}


## R31. The readable half of a property path an undo step addresses: `"position:x"` is `x`,
## `"modulate"` is `modulate`. Godot's `:` sub-path addressing is filing, not something the row says.
static func _undo_member_word(property_value: String) -> String:
	var bare: String = _unquote(property_value)
	var colon_at: int = bare.rfind(":")
	if colon_at >= 0:
		bare = bare.substr(colon_at + 1)
	return bare.strip_edges()


## True when a value is a literal path to a settings file - the only argument a bare `save` / `load`
## may have and still be honestly readable as storage.
static func _is_config_path(value: String) -> bool:
	if not _is_string_literal(value):
		return false
	var path: String = _unquote(value.strip_edges().trim_prefix("&")).to_lower()
	return path.ends_with(".cfg") or path.ends_with(".ini")


## N7. `var f = FileAccess.open("user://log.txt", FileAccess.WRITE)` as the open-the-file row: the verb
## first, the file it names, which way it was opened, and the handle named after it as the receipt it
## is. Returns {} for anything that is not exactly that assignment.
static func _file_open_statement(text: String, context: Dictionary) -> Dictionary:
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
	# The three modes a reader cares about, said as the thing they are about to do with the file.
	var mode_word: String = ""
	match arguments[1].strip_edges():
		"FileAccess.WRITE":
			mode_word = "Open {file} for writing (as {handle})"
		"FileAccess.READ":
			mode_word = "Open {file} for reading (as {handle})"
		"FileAccess.READ_WRITE":
			mode_word = "Open {file} for reading and writing (as {handle})"
	if mode_word.is_empty():
		return {}
	return _sentence(OBJECT_FILE, mode_word, {
		"file": [file_name_value(arguments[0], context), "value"],
		"handle": [handle, "name"]
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


## N8. One behaviour reading: the behaviour's NAME rides on the row as a chip and the step follows in
## that behaviour's words, so a reader knows which of an object's behaviours is acting.
static func _behaviour_sentence(object_name: String, chip: String, template: String,
		values: Dictionary) -> Dictionary:
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
		# Q8. The PROJECT named its layers, so the row says the name; a layer the project never named
		# keeps its number, which is all anyone could honestly call it.
		var layer_shown: String = expression_text(args[0], context)
		if args[0].strip_edges().is_valid_int():
			var layer_name: String = physics_layer_name(
				args[0].strip_edges().to_int(), physics_dimension_of(object_name, context))
			if not layer_name.is_empty():
				layer_shown = "\"%s\"" % layer_name
		return _sentence(object_name, "Set collision with layer {layer} {state}", {
			"layer": [layer_shown, "value"],
			"state": [translate("on") if switch == "true" else translate("off"), "name"]
		})
	if not BEHAVIOUR_METHODS.has(method):
		return {}
	var known_class: String = object_class_of(target if not target.is_empty() else object_name, context)
	if known_class.is_empty():
		return {}
	if args.size() == 1 and _class_is_any(known_class, BODY_CLASSES):
		match method:
			"apply_impulse", "apply_central_impulse":
				return _behaviour_sentence(object_name, "Physics", "Apply impulse {value}",
					{"value": [expression_text(args[0], context), "value"]})
			"apply_force", "apply_central_force":
				return _behaviour_sentence(object_name, "Physics", "Apply force {value}",
					{"value": [expression_text(args[0], context), "value"]})
		return {}
	if not args.is_empty():
		return {}
	if method == "make_current" and _class_is_any(known_class, CAMERA_CLASSES):
		return _sentence(object_name, "Set as active camera", {})
	if method == "restart" and _class_is_any(known_class, PARTICLE_CLASSES):
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
	# Q8. A mask written as a number is a set of the project's OWN layers, and their names are what a
	# reader can act on. A mask naming nothing the project named keeps the plain number reading.
	if (member == "collision_layer" or member == "collision_mask") and value.is_valid_int():
		var named_layers: String = physics_layer_words(
			value.to_int(), physics_dimension_of(object_name, context))
		if not named_layers.is_empty():
			var template: String = "Set collision layers to {layers}" if member == "collision_layer" else "Set collides with {layers}"
			return _sentence(object_name, template, {"layers": [named_layers, "value"]})
	if not BEHAVIOUR_MEMBERS.has(member):
		return {}
	var known_class: String = object_class_of(
		target.split(".", false)[0] if target.contains(".") else object_name, context)
	if known_class.is_empty():
		return {}
	if _class_is_any(known_class, BODY_CLASSES):
		if member == "linear_velocity":
			return _behaviour_sentence(object_name, "Physics", "Set velocity to {value}",
				{"value": [expression_text(value, context), "value"]})
		if member == "angular_velocity":
			return _behaviour_sentence(object_name, "Physics", "Set angular velocity to {value}",
				{"value": [expression_text(value, context), "value"]})
		return {}
	if member == "emitting" and _class_is_any(known_class, PARTICLE_CLASSES):
		if value == "true":
			return _behaviour_sentence(object_name, "Particles", "Start spraying", {})
		if value == "false":
			return _behaviour_sentence(object_name, "Particles", "Stop spraying", {})
		return {}
	if member == "zoom" and _class_is_any(known_class, CAMERA_CLASSES):
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


## M40/M43/M47. One call, read as the event-sheet verb it is - or {} when the call is not one of these,
## which keeps the ordinary Object ▸ Verb reading.
##
##   sprite.play("run")   AnimatedSprite2D ▸ Set animation to "run" (play)
##   sfx.play()           Audio ▸ Play
##   hide()               Player ▸ Set invisible
##   look_at(p)           Turret ▸ Set angle toward p
##   enemy.set("hp", 3)   enemy ▸ Set hp to 3
##
## The animation / audio split is decided by the object's CLASS, because `play` means two different
## things and only the class says which - an unknown class keeps the plain call reading.
static func _engine_verb_call(call: Dictionary, context: Dictionary) -> Dictionary:
	var method: String = str(call.get("method", ""))
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	var receiver: String = str(call.get("target", ""))
	var object_name: String = _receiver_object(receiver, context)
	var object_class: String = object_class_of(object_name, context)
	match method:
		"hide":
			if arguments.is_empty():
				return _sentence(object_name, "Set invisible", {})
		"show":
			if arguments.is_empty():
				return _sentence(object_name, "Set visible", {})
		"look_at":
			if arguments.size() >= 1:
				return _sentence(object_name, "Set angle toward {target}", {
					"target": [expression_text(arguments[0], context), "value"]})
		"set":
			if arguments.size() == 2 and _is_string_literal(arguments[0]) and is_identifier(_unquote(arguments[0])):
				return _sentence(object_name, "Set {name} to {value}", {
					"name": [_unquote(arguments[0]), "name"],
					"value": [expression_text(arguments[1], context), "value"]})
		"play":
			# P11. `play("run", 2.0)` hands over a SPEED as its second argument, and the engine's own
			# name for it is what makes the value legible - a bare "2" beside the clip name says nothing.
			if _class_is_any(object_class, ANIMATION_CLASSES) and arguments.size() >= 1 and arguments.size() <= 2:
				var played: Dictionary = _sentence(object_name, "Set animation to {name} (play)", {
					"name": [expression_text(arguments[0], context), "value"]})
				if arguments.size() == 2:
					var speed_chip: String = "%s = %s" % [translate("speed"), expression_text(arguments[1], context)]
					(played["segments"] as Array).append({"text": "   ", "tone": "plain"})
					(played["segments"] as Array).append({"text": speed_chip, "tone": "value"})
				return played
			if _class_is_any(object_class, AUDIO_CLASSES):
				return _sentence(OBJECT_AUDIO, "Play", {})
		"stop":
			if not arguments.is_empty():
				return {}
			if _class_is_any(object_class, ANIMATION_CLASSES):
				return _sentence(object_name, "Stop animation", {})
			if _class_is_any(object_class, AUDIO_CLASSES):
				return _sentence(OBJECT_AUDIO, "Stop", {})
		# ── P8 ──────────────────────────────────────────────────────────────────────────────────
		# The drawing verbs, in the words the Drawing Canvas pack already publishes them under, so a
		# `_draw` body reads the same whether the shapes were typed or dropped from that pack.
		"queue_redraw":
			if arguments.is_empty():
				return _sentence(object_name, "Redraw", {})
	var drawn: Dictionary = _draw_call(object_name, method, arguments, context)
	if not drawn.is_empty():
		return drawn
	# ── P6 ──────────────────────────────────────────────────────────────────────────────────────
	# Switching a callback on or off is the sheet's own group activation, said about a tick.
	var switched: Dictionary = _process_switch_call(object_name, method, arguments)
	if not switched.is_empty():
		return switched
	return {}


## P8. `draw_line(a, b, colour)` and its neighbours as the Drawing verbs. Claimed only at the argument
## counts a sentence can name honestly - a `draw_line` with a width behind the colour keeps its code,
## because a row that quietly drops an argument is worse than the line it replaced.
static func _draw_call(object_name: String, method: String, arguments: PackedStringArray,
		context: Dictionary) -> Dictionary:
	match method:
		"draw_line":
			if arguments.size() == 3:
				return _sentence(object_name, "Draw line {from} to {to}, {colour}", {
					"from": [expression_text(arguments[0], context), "value"],
					"to": [expression_text(arguments[1], context), "value"],
					"colour": [expression_text(arguments[2], context), "value"]})
		"draw_rect":
			if arguments.size() == 2:
				return _sentence(object_name, "Draw rectangle {rect}, {colour}", {
					"rect": [expression_text(arguments[0], context), "value"],
					"colour": [expression_text(arguments[1], context), "value"]})
		"draw_circle":
			if arguments.size() == 3:
				return _sentence(object_name, "Draw circle at {at}, radius {radius}, {colour}", {
					"at": [expression_text(arguments[0], context), "value"],
					"radius": [expression_text(arguments[1], context), "value"],
					"colour": [expression_text(arguments[2], context), "value"]})
		"draw_string":
			if arguments.size() >= 3:
				return _sentence(object_name, "Draw text {text} at {at}", {
					"text": [expression_text(arguments[2], context), "value"],
					"at": [expression_text(arguments[1], context), "value"]})
	return {}


## P6. `set_physics_process(false)` -> "Set Every tick (physics) deactivated". Only the two literals
## are claimed: `set_process(enabled)` switches to whatever that variable holds, and no sentence can
## say which of the two states a row is in without reading the value.
static func _process_switch_call(object_name: String, method: String,
		arguments: PackedStringArray) -> Dictionary:
	if not PROCESS_SWITCH_WORDS.has(method) or arguments.size() != 1:
		return {}
	var state: String = arguments[0].strip_edges()
	if state != "true" and state != "false":
		return {}
	return _sentence(object_name, "Set {what} {state}", {
		"what": [translate(str(PROCESS_SWITCH_WORDS[method])), "name"],
		"state": [translate("activated") if state == "true" else translate("deactivated"), "plain"]
	})


## M30. `get_tree().call_group("enemies", "flee", extra)` - the group is the OBJECT the row acts on
## (an event-sheet family), the method is the verb, and anything after it is a value the call passes on.
static func _group_call_statement(text: String, context: Dictionary = {}) -> Dictionary:
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
		segments.append({"text": expression_text(arguments[index], context), "tone": "value"})
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
		"value": [expression_text(arguments[2], context), "value"],
		"duration": [expression_text(arguments[3], context), "value"]
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
## verb in words, then one chip per argument - and never a pair of parentheses, because an
## event-sheet row shows values, not a call.
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
		var chip: String = expression_text(arguments[index], context)
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


## `host == null` / `host != null` as the event-sheet existence condition.
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


## `i == 1` as the event-sheet Compare verb: `i = 1`, and `hp != 3` as `hp ≠ 3`. GDScript doubles the sign
## because a language needs to tell assignment from a question; a sheet row is only ever the question,
## so the row says what a reader means by it. Equality ONLY - `<`, `>=` and the rest already read as
## themselves - and a `== null` never reaches here, because the existence reading claims it first.
## The row belongs to System, the way the event-sheet Compare verb does.
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


## N5. `body is Player` - the type check, with the class drawn as the chip it is rather than left as a
## bare word in the middle of a sentence. Only `X is <ClassName>` is claimed: an `is not` (whose
## right-hand side is not a single identifier) refuses, and keeps its code.
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


## N5. `in` asks three different questions in GDScript, and there is a different row for each. Which
## one this line asks is decided by its SHAPE, never by a guess about what a name holds at run time: a
## LITERAL list on the right is "is one of", a quoted key on the left is a table lookup, and anything
## else is a list being asked whether it contains a value.
static func _membership_condition(text: String, context: Dictionary) -> Dictionary:
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
			shown.append(expression_text(entry, context))
		return _sentence(OBJECT_SYSTEM, "{value} is one of {entries}", {
			"value": [expression_text(needle, context), "value"],
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
		"value": [expression_text(needle, context), "value"]
	})


## N5. `obj.has_method("take_damage")` and `has_node("Sprite2D")` - asking whether an object HAS
## something, naming the thing it has the way the sheet names it everywhere else: a function under its
## display name, a child under its own object label. Only a LITERAL name is claimed - a
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
		return _sentence(object_of_reference(target), "has function {verb}",
			{"verb": [function_words(named), "name"]})
	return _sentence(object_of_reference(target), "has child {child}", {"child": [named, "chip"]})


## P6. A `@tool` script asks whether it is running inside the editor rather than in the game, and both
## of Godot's spellings ask exactly that. One question, one sentence, so a reader never has to know
## that `OS.has_feature("editor")` and `Engine.is_editor_hint()` are the same thing.
static func _editor_condition(text: String) -> Dictionary:
	if text == "Engine.is_editor_hint()" or text == "OS.has_feature(\"editor\")":
		return _sentence(OBJECT_SYSTEM, "is in the editor", {})
	return {}


## N7. `cfg.has_section_key(section, key)` as the storage-has-item question, and the file test beside
## it. The section is a GDScript filing detail the Storage object already implies, so only the key is
## in the sentence.
static func _storage_condition(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if call.is_empty():
		return {}
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	if str(call.get("method", "")) == "has_section_key" and arguments.size() == 2:
		return _sentence(OBJECT_STORAGE, "has item {key}",
			{"key": [expression_text(arguments[1], context), "value"]})
	if text.begins_with("FileAccess.file_exists(") and arguments.size() == 1:
		return _sentence(OBJECT_FILE, "{file} exists",
			{"file": [file_name_value(arguments[0], context), "value"]})
	return {}


## N7. The FILE a path names, as the quoted word a reader recognises: `"user://saves/slot1.cfg"` is
## `"slot1.cfg"`. The directory is a Godot filing detail, and the Storage / File object already says
## where the sheet keeps things. A value that is not a literal path stays exactly as written.
static func file_name_value(path_value: String, context: Dictionary = {}) -> String:
	if not _is_string_literal(path_value):
		return expression_text(path_value, context)
	var path: String = _unquote(path_value.strip_edges().trim_prefix("&"))
	var slash_at: int = path.rfind("/")
	if slash_at >= 0:
		path = path.substr(slash_at + 1)
	return "\"%s\"" % path


## A method name as the FUNCTION it is: Title Case, the way a published verb reads in the picker and in
## a Call row ("take_damage" -> "Take Damage"). Deliberately not `verb_words()`, which spells an unknown
## method as a sentence-case step; asking whether an object has a FUNCTION is asking about the named
## thing, so it reads under the name that thing would be published as.
static func function_words(method: String) -> String:
	var bare: String = method.strip_edges()
	while bare.begins_with("_"):
		bare = bare.substr(1)
	return bare.capitalize() if not bare.is_empty() else method.strip_edges()


## M25. `rotation > 1.5` - a comparison whose subject is an ENGINE property of the script's own
## object reads under that object, the way `Sprite > X > 100` does in an event sheet.
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
			{"text": expression_text(compared, context), "tone": "value"}
		]}
	return {}


## M41. The movement questions an event-sheet Platform behaviour asks. `is_on_wall` and `is_on_ceiling`
## get the event-sheet words (a wall is beside you, a ceiling above you); `is_on_floor` already reads
## the same in both engines. The Godot phrase stays one hover away on the row.
const BODY_STATE_WORDS: Dictionary = {
	"is_on_floor": "Is on floor",
	"is_on_wall": "Is by wall",
	"is_on_ceiling": "Is by ceiling"
}


static func _body_state_condition(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if call.is_empty() or not (call.get("args", PackedStringArray()) as PackedStringArray).is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	if not BODY_STATE_WORDS.has(method):
		return {}
	return _sentence(_receiver_object(str(call.get("target", "")), context), str(BODY_STATE_WORDS[method]), {})


## M41. `hurtbox.overlaps_body(player)` and the "is anything touching me" pair, as the one event-sheet
## overlap condition. The reading names the other object, or says "something" when the test does not.
static func _overlap_condition(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if call.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	var object_name: String = _receiver_object(str(call.get("target", "")), context)
	if (method == "overlaps_body" or method == "overlaps_area") and arguments.size() == 1:
		return _sentence(object_name, "Is overlapping {other}", {"other": [expression_text(arguments[0], context), "value"]})
	if method in ["has_overlapping_bodies", "has_overlapping_areas"] and arguments.is_empty():
		return _sentence(object_name, "Is overlapping something", {})
	return {}


## M41. `velocity.y < 0` is the event-sheet "Is jumping" - but ONLY on a 2D body, where Y grows downward.
## In 3D the same test means the opposite, so the reading is refused there and the comparison stands.
static func _movement_condition(text: String, context: Dictionary) -> Dictionary:
	for operator: String in [" < ", " > "]:
		var at: int = top_level_index(text, operator)
		if at < 0:
			continue
		if text.substr(at + operator.length()).strip_edges() != "0":
			return {}
		var subject: String = text.substr(0, at).strip_edges().trim_prefix("self.")
		if not subject.ends_with("velocity.y"):
			return {}
		var owner_name: String = subject.substr(0, maxi(subject.length() - "velocity.y".length() - 1, 0))
		if object_class_of(_receiver_object(owner_name, context), context) != "CharacterBody2D":
			return {}
		return _sentence(_receiver_object(owner_name, context),
			"Is jumping" if operator == " < " else "Is falling", {})
	return {}


## M41. The movement reading of a "is this number below / above zero" test, for the picked rows that
## ask it that way. {} whenever the shape is not a 2D body's vertical speed, which is the caller's cue
## to keep the reading it already had.
static func movement_words(value: String, operator: String, context: Dictionary) -> Dictionary:
	var text: String = "%s %s 0" % [value.strip_edges(), operator]
	var movement: Dictionary = _movement_condition(text, context)
	if not movement.is_empty():
		return movement
	# M47. `enemy.get("hp") > 0` still reads as the property it asks about; every other number keeps
	# the vocabulary's own wording, which is why nothing else is tried here.
	return _object_property_condition(text, context)


## M44. Counting objects: a group's instance count, and a node's children.
static func _count_condition(text: String, context: Dictionary) -> Dictionary:
	for operator: String in [" >= ", " <= ", " != ", " == ", " > ", " < "]:
		var at: int = top_level_index(text, operator)
		if at < 0:
			continue
		var subject: String = text.substr(0, at).strip_edges()
		var compared: String = text.substr(at + operator.length()).strip_edges()
		if compared.is_empty():
			return {}
		var counted: String = _group_count_words(subject)
		if counted != subject:
			# "enemies (group) count" - the group is the OBJECT, and the count is what the row shows.
			var count_word: String = translate("count")
			var group_label: String = counted.substr(0, counted.length() - count_word.length()).strip_edges()
			return {"object": group_label, "segments": [
				{"text": count_word, "tone": "name"},
				{"text": operator, "tone": "plain"},
				{"text": expression_text(compared, context), "tone": "value"}
			]}
		var child_call: Dictionary = call_parts(subject)
		if child_call.is_empty() or str(child_call.get("method", "")) != "get_child_count":
			return {}
		if not (child_call.get("args", PackedStringArray()) as PackedStringArray).is_empty():
			return {}
		return {"object": _receiver_object(str(child_call.get("target", "")), context), "segments": [
			{"text": translate("child count"), "tone": "name"},
			{"text": operator, "tone": "plain"},
			{"text": expression_text(compared, context), "tone": "value"}
		]}
	return {}


## M44. `not items.is_empty()` as the count it asks about, so the two emptiness tests read as one
## pair (`items' count = 0` / `items' count > 0`) rather than as a sentence wearing a NOT mark.
static func _not_empty_reading(text: String, context: Dictionary) -> Dictionary:
	if not text.begins_with("not "):
		return {}
	var call: Dictionary = call_parts(text.substr(4).strip_edges())
	if call.is_empty() or str(call.get("method", "")) != "is_empty":
		return {}
	if not (call.get("args", PackedStringArray()) as PackedStringArray).is_empty():
		return {}
	var receiver: String = str(call.get("target", "")).strip_edges()
	if receiver.is_empty():
		return {}
	return {"object": "", "segments": [
		{"text": "%s' %s > 0" % [expression_text(receiver, context), translate("count")], "tone": "value"}
	]}


## M47. `enemy.get("hp") > 0` reads as the property it asks about, under the object that owns it.
static func _object_property_condition(text: String, context: Dictionary) -> Dictionary:
	for operator: String in [" >= ", " <= ", " != ", " == ", " > ", " < "]:
		var at: int = top_level_index(text, operator)
		if at < 0:
			continue
		var call: Dictionary = call_parts(text.substr(0, at).strip_edges())
		if call.is_empty() or str(call.get("method", "")) != "get":
			return {}
		var arguments: PackedStringArray = call.get("args", PackedStringArray())
		if arguments.size() != 1 or not _is_string_literal(arguments[0]):
			return {}
		var property_name: String = _unquote(arguments[0])
		var receiver: String = str(call.get("target", "")).strip_edges()
		if not is_identifier(property_name) or receiver.is_empty():
			return {}
		return {"object": _receiver_object(receiver, context), "segments": [
			{"text": property_name, "tone": "name"},
			{"text": operator, "tone": "plain"},
			{"text": expression_text(text.substr(at + operator.length()), context), "tone": "value"}
		]}
	return {}


## The object a receiver names: the script's own object for a bare or `self` call, the last path
## segment for a `$Node` / `%Node` reference, and the receiver as written for anything else.
static func _receiver_object(receiver: String, context: Dictionary) -> String:
	var text: String = receiver.strip_edges()
	if text.is_empty() or text == "self":
		return script_object(context)
	return object_of_reference(text)


## M40/M41. The engine class an object label is known to be - the sheet's own object map first (an
## @onready node's declared type, the pack's host), then the script's own class for its own object,
## then the label itself when it names a class. "" when nothing is known, which is the cue to keep
## the general reading rather than guess a class-specific one.
static func object_class_of(object_label: String, context: Dictionary) -> String:
	var label: String = object_label.strip_edges()
	if label.is_empty():
		return str(context.get("self_class", ""))
	var classes: Dictionary = context.get("object_classes", {})
	var known: String = str(classes.get(label, ""))
	if not known.is_empty():
		return known
	if label == script_object(context) or label == OBJECT_SYSTEM:
		return str(context.get("self_class", ""))
	return label if ClassDB.class_exists(label) else ""


## True when a known class IS one of `bases` (its own name or a subclass of one).
static func _class_is_any(class_name_str: String, bases: PackedStringArray) -> bool:
	var bare: String = class_name_str.strip_edges()
	if bare.is_empty() or not ClassDB.class_exists(bare):
		return false
	for base: String in bases:
		if bare == base or ClassDB.is_parent_class(bare, base):
			return true
	return false


## `randf() < 0.3` as the event-sheet chance condition. Only a literal probability is claimed - a
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
	# state, so the reading says which - the same distinction a trigger and a check already draw.
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
## Keyboard rows a reader knows. `this_event` marks the InputEvent forms, which ask about the one
## event the handler was handed rather than about the device's live state.
static func input_phase_sentence(action_value: String, pressed: bool, this_event: bool) -> Dictionary:
	var shown: String = strip_action_name(action_value)
	if shown.is_empty():
		return {}
	# Four whole templates rather than one built by concatenation: a locale translates a SENTENCE, and
	# a key stitched together at run time is a key no CSV can ever hold.
	var template: String = "On {action} pressed" if pressed else "On {action} released"
	if this_event:
		template = "On {action} pressed (this event)" if pressed else "On {action} released (this event)"
	# Q8. Same device rule as the live-state reading above: the project's own bindings choose the object.
	return _sentence(input_action_object(action_value), template, {"action": [shown, "value"]})


## N9. `KEY_X` / `MOUSE_BUTTON_LEFT` as the key or button a reader would say. Only a bare engine
## constant is claimed: a computed keycode has no letter to print.
static func _key_sentence(object_name: String, prefix: String, constant: String,
		template: String) -> Dictionary:
	var bare: String = constant.strip_edges()
	if not bare.begins_with(prefix) or not is_identifier(bare):
		return {}
	var named: String = bare.substr(prefix.length())
	if named.is_empty():
		return {}
	# A single letter or digit stays the character it is; a word key reads as the word ("SPACE" is
	# Space), and a mouse button reads in the lower case it is written in.
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


## The event-sheet reading of one call, or "" when the head is not in the curated table.
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
	# A no-argument `get_thing()` is a PROPERTY READ wearing a call's clothes: an event sheet shows the
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
## Q5 widened this from the one `.0` case to every literal a person writes differently from GDScript -
## padding zeros, grouped thousands, exponents and the famous constants - in one walk of the text.
static func _tidy_numbers(text: String) -> String:
	return number_lens(text)


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
## user typed, and an event sheet shows it as one ("jump" is down). Kept quoted, the name lens also
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
	# M25. An ENGINE property of the script's own object belongs to that object, exactly as an event
	# sheet draws Sprite > Set X. A plain script variable is not one of these, and stays with System.
	if is_engine_property(head, context):
		return [script_object(context), engine_member_name(text)]
	if dot_at <= 0:
		return [self_object, _member_word(text)]
	var object_name: String = head
	if object_name == "self":
		object_name = script_object(context)
	# M47. `$Enemies/Boss` is the object `Boss` - the name a reader sees in the scene tree.
	return [object_of_reference(object_name), _member_word(text.substr(dot_at + 1))]


## M43. The event-sheet word for a member of ANOTHER object - only the renamed ones. The axis rule
## that `engine_member_name` also applies belongs to the script's own object, where the sheet knows
## the member IS the node's place; on someone else's `position.x` it would drop a segment a reader
## needs.
static func _member_word(chain: String) -> String:
	return translate(str(MEMBER_WORDS[chain])) if MEMBER_WORDS.has(chain) else chain


## M25. True when `name` is a property the ENGINE reports on the object this script is - the set is
## handed in by the caller (`engine_properties`), because only the caller can ask ClassDB.
static func is_engine_property(property_name: String, context: Dictionary) -> bool:
	var properties: Dictionary = context.get("engine_properties", {})
	return properties.has(property_name.strip_edges())


## M25. What an engine property chain is CALLED on the row: an event sheet writes an object's place as X
## and Y, so `position.x` reads X. Everything else keeps its chain and the possessive lens spells it.
static func engine_member_name(chain: String) -> String:
	var parts: PackedStringArray = chain.split(".", false)
	if parts.size() == 2 and (parts[0] == "position" or parts[0] == "global_position"):
		var axis: String = parts[1].to_lower()
		if axis == "x" or axis == "y" or axis == "z":
			return axis.to_upper()
	# M43. An event-sheet object has an ANGLE. `rotation` is the same angle in radians, and saying so is
	# the one Godot fact worth keeping - the two numbers are not interchangeable.
	if MEMBER_WORDS.has(chain):
		return translate(str(MEMBER_WORDS[chain]))
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
	# R31. The editor's undo history, declared as what it is. A reader who sees "Local ur = ..." with no
	# type cannot tell that `ur` is something they may call actions on; "Local object ur" says it.
	if UNDO_HISTORY_CALLS.has(text):
		return "Object"
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
	# `substr` is left() from zero and mid() anywhere else, and a config read says whether it has a
	# fallback. Everything else below is one method, one pattern.
	var shaped: String = _shaped_receiver_idiom(receiver, method, arguments)
	if not shaped.is_empty():
		return shaped
	var pattern: String = str(RECEIVER_IDIOMS.get(chain, RECEIVER_IDIOMS.get(method, "")))
	if MEASURED_IDIOMS.has(method):
		var forms: Array = MEASURED_IDIOMS[method]
		var own_place: bool = OWN_POSITION_NAMES.has(receiver.trim_prefix("self."))
		pattern = str(forms[0] if own_place else forms[1])
	# M47. `enemy.get("hp")` names a property, and an event sheet shows the property, never the lookup.
	if method == "get" and arguments.size() == 1 and _is_string_literal(arguments[0]):
		var property_name: String = _unquote(arguments[0])
		if is_identifier(property_name):
			return "%s's %s" % [receiver, property_name]
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
static func _shaped_receiver_idiom(receiver: String, method: String,
		arguments: PackedStringArray) -> String:
	if method == "substr" and arguments.size() == 2:
		if arguments[0].strip_edges() == "0":
			return "left(%s, %s)" % [receiver, arguments[1]]
		return "mid(%s, %s, %s)" % [receiver, arguments[0], arguments[1]]
	# `cfg.get_value(section, key)` is the read-an-item-from-storage expression; the section is a
	# GDScript filing detail the Storage object already implies, so only the KEY is in the sentence.
	if method == "get_value" and arguments.size() == 2:
		return _fill(translate("item {key}"), {"key": arguments[1]})
	if method == "get_value" and arguments.size() == 3:
		return _fill(translate("item {key} (default {fallback})"),
			{"key": arguments[1], "fallback": arguments[2]})
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


# ── Q5 / Q6 / Q7 / Q8 / Q11 - the reading words batch six added ─────────────────
#
# Five readings that all share one rule: the FILE never moves. Every function below answers with
# words for a value the row already holds, so the byte round-trip and the emitted GDScript are the
# same before and after. Kept in one block, apart from the shapes above, because each of them is a
# lens over a value rather than a new statement shape.
#
#   Q5  numbers        300.0 -> 300, 1_000_000 -> 1,000,000, 1e3 -> 1000, 1.5707963 -> π/2
#   Q6  lists and text items.append(x) -> Push back x to items - the List module's own sentence
#   Q7  deferred       call_deferred("reset") -> Call Reset (at end of frame)
#   Q8  project names  layer 2 -> "Enemies", and an action's device chooses its object
#   Q11 enums          process_mode = 3 -> Set process mode to Always


## Q5. The constants a reader recognises on sight, as [value, words]. Every entry is checked for a
## near-EXACT hit against a long spelling, so nothing here can claim a number that merely looks close.
const NUMBER_CONSTANTS: Array = [
	[TAU, "τ"], [PI, "π"], [PI / 2.0, "π/2"], [PI / 3.0, "π/3"], [PI / 4.0, "π/4"],
	[1.4142135623730951, "√2"], [1.7320508075688772, "√3"]
]
## Q5. How close a written number must be to a constant before it reads as one, and how many decimals
## it must carry. `3.14` stays 3.14: two decimals is a number somebody chose, not an attempt at π.
const CONSTANT_TOLERANCE: float = 1e-6
const CONSTANT_MIN_DECIMALS: int = 5
## Q5. Below this an integer keeps its digits: 1000 is a number a reader reads at a glance, and
## grouping the short ones would put separators into years, ids and sizes for nothing.
const GROUPING_FROM: int = 10000
## Q5. What separates the groups of three.
const THOUSANDS_SEPARATOR := ","

## Q5. The 0..1 members the ENGINE treats as a fraction. Anything else is opted in by the project's
## own `@export_range(0, 1)`, which the caller hands in as `percent_members`.
const FRACTION_MEMBERS: PackedStringArray = ["modulate.a", "self_modulate.a"]

## Q6. The list steps that have one settled sentence in the List module, keyed by the Godot method.
## The sentence is the module ACE's own display text word for word - a typed line and the picked row
## must read the same, which is the whole point of one grammar.
const LIST_STEPS: Dictionary = {
	"append": "Push back {value} to {name}",
	"push_back": "Push back {value} to {name}",
	"push_front": "Push front {value} to {name}",
	"pop_back": "Pop back of {name}",
	"pop_front": "Pop front of {name}",
	"clear": "Clear {name}",
	"sort": "Sort {name}",
	"shuffle": "Shuffle {name}",
	"reverse": "Reverse {name}"
}

## Q6. The declared types that make `erase` a LIST step ("Delete value") rather than a table one
## ("Delete key"). A table is the default because a picked Delete Key row carries no declaration to
## read, and a list says so with its own type.
const LIST_TYPES: PackedStringArray = [
	"Array", "PackedStringArray", "PackedInt32Array", "PackedInt64Array",
	"PackedFloat32Array", "PackedFloat64Array", "PackedVector2Array", "PackedVector3Array",
	"PackedColorArray", "PackedByteArray"
]

## Q8. The two physics dimensions, and the project-settings key their layer names live under.
const PHYSICS_DIMENSION_2D := "2d_physics"
const PHYSICS_DIMENSION_3D := "3d_physics"
## Q8. The classes whose collision knobs are the 3D ones. Everything else reads the 2D names, which is
## what a 2D project wants and what an unknown class can honestly say.
const PHYSICS_3D_CLASSES: PackedStringArray = ["Node3D"]


## Q5. One numeric literal in the words a person writes it in, or "" when the text is not one or is
## already written that way.
##
##   300.0      300          a trailing `.0` is a GDScript type cue
##   0.50       0.5          a trailing zero is padding
##   1_000_000  1,000,000    thousands grouped, from five digits up
##   1e3        1000         an exponent is a spelling, not a quantity
##   1.5707963  π/2          the constants a reader recognises
##
## Display only, and deliberately narrow: a literal that is none of these comes back "".
static func number_words(literal: String) -> String:
	var text: String = literal.strip_edges()
	if text.is_empty():
		return ""
	var sign_text: String = ""
	if text.begins_with("-") or text.begins_with("+"):
		sign_text = "-" if text.begins_with("-") else ""
		text = text.substr(1)
	var bare: String = text.replace("_", "")
	if bare.is_empty() or not bare[0].is_valid_int():
		return ""
	# A hex or binary literal is a BIT PATTERN. Rewriting one as a decimal would hide the very thing
	# its spelling was chosen to show.
	if bare.begins_with("0x") or bare.begins_with("0b"):
		return ""
	var digits: String = bare
	if bare.to_lower().contains("e"):
		# An exponent spells a quantity the long way round; a value too big to write out keeps it, and
		# so does one with a fraction, which the long spelling would only make harder to read.
		# Checked before the validity gate below, because `is_valid_float` does not accept `1e3`.
		var value: float = bare.to_float()
		if value == 0.0 or absf(value) >= 1e15 or value != floorf(value):
			return ""
		digits = String.num_int64(int(value))
		if absi(digits.to_int()) >= GROUPING_FROM:
			digits = _grouped_digits(digits)
		return "%s%s" % [sign_text, digits]
	if not bare.is_valid_float() and not bare.is_valid_int():
		return ""
	var named: String = _constant_number_words(bare)
	if not named.is_empty():
		return "%s%s" % [sign_text, named]
	if digits.contains("."):
		digits = digits.rstrip("0")
		if digits.ends_with("."):
			digits = digits.substr(0, digits.length() - 1)
		if digits.is_empty():
			digits = "0"
	var whole: String = digits
	var fraction: String = ""
	var point_at: int = digits.find(".")
	if point_at >= 0:
		whole = digits.substr(0, point_at)
		fraction = digits.substr(point_at)
	if whole.is_valid_int() and absi(whole.to_int()) >= GROUPING_FROM:
		whole = _grouped_digits(whole)
	var shown: String = "%s%s%s" % [sign_text, whole, fraction]
	return "" if shown == literal.strip_edges() else shown


## Q5. The constant a long decimal is spelling out, or "" when it is not spelling one. The decimal
## count gate is what keeps a short, deliberate number from claiming a constant it never meant.
static func _constant_number_words(bare: String) -> String:
	var point_at: int = bare.find(".")
	if point_at < 0 or bare.length() - point_at - 1 < CONSTANT_MIN_DECIMALS:
		return ""
	var value: float = bare.to_float()
	for entry: Array in NUMBER_CONSTANTS:
		if absf(value - float(entry[0])) <= CONSTANT_TOLERANCE:
			return str(entry[1])
	return ""


## Q5. `1000000` -> `1,000,000`. The separator is a glyph rather than a word, so it stays out of the
## translation catalog for the same reason π and ≥ do: a catalog row holds a SENTENCE, and a single
## punctuation mark keyed on itself is a row no translator can read.
static func _grouped_digits(whole: String) -> String:
	var separator: String = THOUSANDS_SEPARATOR
	var out: String = ""
	var counted: int = 0
	for index: int in range(whole.length() - 1, -1, -1):
		if counted > 0 and counted % 3 == 0:
			out = separator + out
		out = whole[index] + out
		counted += 1
	return out


## Q5. Rewrites every numeric literal OUTSIDE a string with the words a person writes it in. Walks the
## text rather than running a regex over it, because `"res://a/1000000.png"` inside quotes and the
## `2` of a `sprite2` identifier both have to come through untouched.
static func number_lens(text: String) -> String:
	var out: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if character == "\"" or character == "'":
			var end_at: int = _string_end(text, index)
			out += text.substr(index, end_at - index + 1)
			index = end_at + 1
			continue
		if not character.is_valid_int():
			out += character
			index += 1
			continue
		# A digit that follows a name character or a dot belongs to something else - `sprite2`, a
		# member chain, a version string - and is not a literal this lens may touch.
		var previous: String = "" if out.is_empty() else out[out.length() - 1]
		var literal_start: bool = previous.is_empty() or not (
			previous.is_valid_identifier() or previous.is_valid_int() or previous == "." or previous == "_")
		var end_index: int = index
		while end_index < text.length() and _is_number_character(text, end_index):
			end_index += 1
		var literal: String = text.substr(index, end_index - index)
		if literal_start:
			var shown: String = number_words(literal)
			out += shown if not shown.is_empty() else literal
		else:
			out += literal
		index = end_index
	return out


## Q5. Whether the character at `at` still belongs to a numeric literal - digits, the underscore
## separator, a decimal point, and the `e` of an exponent with its sign.
static func _is_number_character(text: String, at: int) -> bool:
	var character: String = text[at]
	if character.is_valid_int() or character == "_":
		return true
	if character == ".":
		return at + 1 < text.length() and text[at + 1].is_valid_int()
	if character == "e" or character == "E":
		if at + 1 >= text.length():
			return false
		var next_character: String = text[at + 1]
		if next_character.is_valid_int():
			return true
		return (next_character == "-" or next_character == "+") and at + 2 < text.length() and text[at + 2].is_valid_int()
	if (character == "-" or character == "+") and at > 0:
		return (text[at - 1] == "e" or text[at - 1] == "E") and at + 1 < text.length() and text[at + 1].is_valid_int()
	return false


## Q5. True when this member is a 0..1 slot the sheet shows as a percentage - one the engine treats as
## a fraction, or one the project's own `@export_range(0, 1)` marked as one.
static func is_fraction_member(chain: String, member: String, context: Dictionary) -> bool:
	if FRACTION_MEMBERS.has(chain.strip_edges().trim_prefix("self.")):
		return true
	return (context.get("percent_members", {}) as Dictionary).has(member.strip_edges())


## Q11. The enum member a number stands for, or "" when nothing says it stands for one.
##
##   process_mode = 3     Always     (the ENGINE's own enum hint for the property)
##   dir = 2              LEFT       (a variable the sheet declared with a script enum as its type)
##
## Both sides are handed in through `context` by the caller, which is the only side able to ask
## ClassDB and to walk the sheet.
static func enum_value_words(object_name: String, target: String, member: String, value: String,
		context: Dictionary) -> String:
	var number: String = value.strip_edges()
	if not number.is_valid_int():
		return ""
	var index: int = number.to_int()
	var bare_member: String = member.strip_edges()
	var bare_target: String = target.strip_edges().trim_prefix("self.")
	# The ENGINE's enum. On the script's OWN object the member must be one the engine really reports
	# (a sheet variable that happens to share a property's name is the sheet's, not the node's); on
	# another object the class it is known to be answers instead.
	var owned_by_self: bool = bare_target == bare_member
	if not owned_by_self or is_engine_property(bare_member, context):
		var hint_string: String = engine_enum_hint(object_class_of(object_name, context), bare_member)
		if not hint_string.is_empty():
			var named: String = enum_hint_member(hint_string, index)
			if not named.is_empty():
				return named
	# The SHEET's own enum, when the variable was declared with one as its type.
	var declared: Dictionary = context.get("variable_enum_types", {})
	var enum_name: String = str(declared.get(bare_member, ""))
	if enum_name.is_empty():
		return ""
	var members: Dictionary = (context.get("enum_values", {}) as Dictionary).get(enum_name, {})
	return str(members.get(index, ""))


## Q11. {ClassName: {property: enum hint string}} - the one impurity in this file besides the
## translation catalog, and for the same reason: a row builder asks the question of every assignment
## it draws, and a Node subclass's property list is hundreds of entries long. Engine reflection never
## changes within a session, so the answer is safe to keep.
static var _enum_hint_cache: Dictionary = {}


## Q11. The enum hint string the ENGINE reports for one property of one class, or "" when the property
## is not an enum, the class is not one ClassDB knows, or either name is blank.
static func engine_enum_hint(class_name_str: String, property_name: String) -> String:
	var bare: String = class_name_str.strip_edges()
	if bare.is_empty() or property_name.strip_edges().is_empty() or not ClassDB.class_exists(bare):
		return ""
	if not _enum_hint_cache.has(bare):
		var hints: Dictionary = {}
		for entry: Dictionary in ClassDB.class_get_property_list(bare):
			if int(entry.get("hint", 0)) != PROPERTY_HINT_ENUM:
				continue
			var found: String = str(entry.get("name", ""))
			if not found.is_empty():
				hints[found] = str(entry.get("hint_string", ""))
		_enum_hint_cache[bare] = hints
	return str((_enum_hint_cache[bare] as Dictionary).get(property_name.strip_edges(), ""))


## Q11. The member an engine enum hint string names for `index`, or "" when it names none. Godot writes
## the hint as `Inherit,Pausable,When Paused,Always,Disabled`, and an entry may pin its own number
## (`Nearest:1`), so the position is only the answer while nothing said otherwise.
static func enum_hint_member(hint_string: String, index: int) -> String:
	var next_value: int = 0
	for entry: String in hint_string.split(",", false):
		var text: String = entry.strip_edges()
		if text.is_empty():
			continue
		var colon_at: int = text.rfind(":")
		var member: String = text
		if colon_at > 0 and text.substr(colon_at + 1).strip_edges().is_valid_int():
			member = text.substr(0, colon_at).strip_edges()
			next_value = text.substr(colon_at + 1).strip_edges().to_int()
		if next_value == index:
			return member
		next_value += 1
	return ""


## Q8. The project's name for one physics layer (`layer_names/2d_physics/layer_2`), or "" when the
## project never named it. Read live rather than cached: a layer renamed in Project Settings a minute
## ago must read by its new name without an editor restart.
static func physics_layer_name(layer_number: int, dimension: String) -> String:
	if layer_number < 1 or layer_number > 32:
		return ""
	return str(ProjectSettings.get_setting(
		"layer_names/%s/layer_%d" % [dimension, layer_number], "")).strip_edges()


## Q8. Every layer a MASK holds, in the project's own words, as `"World", "Player"` - or "" when the
## mask names no layer the project named. A mask mixing named and anonymous layers still reads, with
## the unnamed ones by their number, because hiding half a mask would be worse than mixing.
static func physics_layer_words(mask: int, dimension: String) -> String:
	if mask <= 0:
		return ""
	var named_any: bool = false
	var parts: PackedStringArray = PackedStringArray()
	for bit: int in 32:
		if not bool((mask >> bit) & 1):
			continue
		var layer_name: String = physics_layer_name(bit + 1, dimension)
		if layer_name.is_empty():
			parts.append(str(bit + 1))
			continue
		named_any = true
		parts.append("\"%s\"" % layer_name)
	return ", ".join(parts) if named_any else ""


## Q8. Which set of layer names an object's collision knobs read from - a 3D node names 3D layers.
static func physics_dimension_of(object_name: String, context: Dictionary) -> String:
	var known_class: String = object_class_of(object_name, context)
	return PHYSICS_DIMENSION_3D if _class_is_any(known_class, PHYSICS_3D_CLASSES) else PHYSICS_DIMENSION_2D


## Q8. The event-sheet object an input action belongs to, decided by the DEVICES the project bound it
## to: mouse buttons only make it a Mouse row, gamepad only a Gamepad row, anything else Keyboard.
## The object column then tells the truth about where the input comes from.
static func input_action_object(action_value: String) -> String:
	var bare: String = _unquote(action_value.strip_edges().trim_prefix("&"))
	if bare.is_empty():
		return OBJECT_KEYBOARD
	var setting: Variant = ProjectSettings.get_setting("input/%s" % bare, null)
	if not (setting is Dictionary):
		return OBJECT_KEYBOARD
	var events: Variant = (setting as Dictionary).get("events", null)
	if not (events is Array) or (events as Array).is_empty():
		return OBJECT_KEYBOARD
	var mouse_only: bool = true
	var pad_only: bool = true
	for event: Variant in (events as Array):
		var is_mouse: bool = event is InputEventMouseButton
		var is_pad: bool = event is InputEventJoypadButton or event is InputEventJoypadMotion
		mouse_only = mouse_only and is_mouse
		pad_only = pad_only and is_pad
	if mouse_only:
		return OBJECT_MOUSE
	if pad_only:
		return OBJECT_GAMEPAD
	return OBJECT_KEYBOARD
