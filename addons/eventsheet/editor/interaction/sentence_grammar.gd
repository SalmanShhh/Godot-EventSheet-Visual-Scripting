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
## R26 / R29. Fingers, gestures and the handheld sensors are the event-sheet Touch object's, the same
## object its On touch start and Compare acceleration rows already live under.
const OBJECT_TOUCH := "Touch"
## N7. Saving, files and JSON belong to three objects of their own - Local Storage, JSON and AJAX.
## Hand-written ConfigFile / JSON / FileAccess code reads under the same three names, so the rows a
## reader already recognises are the rows they see here.
## S5. Spelled in full: Local Storage is the name the object goes by, and the shortened one sent a
## reader looking for an object their sheet does not have.
const OBJECT_STORAGE := "Local Storage"
const OBJECT_JSON := "JSON"
const OBJECT_FILE := "File"
## U6. A web request and its answer are one object in the sheet's words, exactly as saving is Local
## Storage's and a message is Multiplayer's.
const OBJECT_AJAX := "AJAX"
## S10. Godot's high-level networking is one object in the sheet's words - the one the messages, the
## host question and the peer id all read under, exactly as Storage owns the save rows above.
const OBJECT_MULTIPLAYER := "Multiplayer"

## N8. The methods and properties that can carry behaviour words at all. Checked BEFORE the object's
## class is resolved, so an ordinary call or assignment - which is most of them - never pays for a
## class lookup it cannot use, and so the whole set of lines these words may claim reads in one place.
const BEHAVIOUR_METHODS: PackedStringArray = [
	"apply_impulse", "apply_central_impulse", "apply_force", "apply_central_force",
	"make_current", "restart"
]
const BEHAVIOUR_MEMBERS: PackedStringArray = [
	"linear_velocity", "angular_velocity", "emitting", "zoom", "position_smoothing_enabled"
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
	# N7 / U6 - the JSON object's two verbs, and a file handle's whole contents. The two JSON verbs are
	# spelled the way the sheet's own JSON object spells them, so a typed line and the picked row read
	# alike and a reader who knows one knows the other.
	"JSON.parse_string": "JSON.Parse({0})",
	"JSON.stringify": "JSON.ToString({0})",
	"get_as_text": "{receiver}'s contents",
	# U6. The bytes a finished request hands back, read back as the AJAX object's own value: what the
	# line actually names is the answer that just arrived, and that answer has a name on the sheet.
	"get_string_from_utf8": "AJAX.LastData",
	# V2 - the two things a List is asked, under the expression names the List object publishes
	"get_item_text": "{receiver}.ItemText({0})",
	"get_selected_id": "{receiver}.SelectedIndex",
	# N9 - the analogue reads belong to the pad
	"Input.get_action_strength": "strength of {0}",
	"Input.get_action_raw_strength": "raw strength of {0}"
}

## R24. The Gamepad object's axis names, by the constant a line writes. Used by the controls block at
## the end of this file.
const CONTROLS_AXIS_WORDS: Dictionary = {
	"JOY_AXIS_LEFT_X": "Left analog X",
	"JOY_AXIS_LEFT_Y": "Left analog Y",
	"JOY_AXIS_RIGHT_X": "Right analog X",
	"JOY_AXIS_RIGHT_Y": "Right analog Y",
	"JOY_AXIS_TRIGGER_LEFT": "Left trigger",
	"JOY_AXIS_TRIGGER_RIGHT": "Right trigger"
}

## R29. The four sensors a handheld device has, in the Touch object's words. They are whole
## expressions with nothing to fill in, which is why they are a plain table rather than an idiom.
const CONTROLS_SENSOR_WORDS: Dictionary = {
	"Input.get_accelerometer()": "acceleration",
	"Input.get_gravity()": "gravity",
	"Input.get_gyroscope()": "rotation rate",
	"Input.get_magnetometer()": "magnetic field"
}

## R25. The whole-expression reads about the gamepads themselves.
const CONTROLS_GAMEPAD_WORDS: Dictionary = {
	"Input.get_connected_joypads().size()": "gamepad count",
	"Input.get_connected_joypads()": "connected gamepads"
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
	# R3. A line broken with a trailing `\` is ONE statement, and a chained tween is the shape that
	# writes it that way most often. Joining first is what lets the rest of the grammar see it at all.
	if code.contains("\n"):
		code = join_continuations(code)
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
	# T8. A line that picks an instance and names it is ONE picking row, not a declaration whose value
	# happens to be a list step: the sheet's word for what it does is Pick, and the name it filled is
	# said after it. Ahead of the declaration reading, which would show the GDScript as the value.
	var picked: Dictionary = picking_statement(text, context)
	if not picked.is_empty():
		return _with_indent(picked, indent)
	if keyword == "var" or keyword == "const":
		return _with_indent(_declaration_statement(text, keyword, context), indent)
	# S1. Switching state is the FSM behavior's one action, and it is written two ways - through the
	# transition function, or straight onto the variable. Ahead of the assignment and the call
	# readings, either of which would describe the spelling instead of the step.
	var switched: Dictionary = _state_machine_statement(text, context)
	if not switched.is_empty():
		return _with_indent(switched, indent)
	# S4. A countdown is a shape several lines make together, so it is claimed ahead of the arithmetic
	# and the plain Set, both of which would describe one line of it correctly and the pattern not at all.
	var countdown: Dictionary = _countdown_statement(text, context)
	if not countdown.is_empty():
		return _with_indent(countdown, indent)
	# S6. Letting go of a reference is its own event-sheet step, and reads as one rather than as a Set
	# to a value nobody puts anywhere.
	var forgotten: Dictionary = _forget_statement(text, context)
	if not forgotten.is_empty():
		return _with_indent(forgotten, indent)
	# ── S8 / S9 / S10 / S15 ─────────────────────────────────────────────────────────────────────
	# The four patterns whose lines several other readings would each claim half of: a background
	# load is an assignment-free call, a movement step is arithmetic on `velocity`, a message is a
	# call on a function name, and a path step is an assignment. Each is recognised WHOLE or not at
	# all, so it goes ahead of the compound / assignment / call split below.
	var systems: Dictionary = godot_systems_statement(text, context)
	if not systems.is_empty():
		return _with_indent(systems, indent)
	# ── T1 / T2 / T3 / T4 ───────────────────────────────────────────────────────────────────────
	# The hand-rolled behavior shapes, in the shipped behavior's own words. AFTER the readings above
	# so nothing already settled moves, and BEFORE the arithmetic below, which would describe one
	# line of a projectile correctly and the projectile not at all.
	var shape: Dictionary = behavior_shape_statement(text, context)
	if not shape.is_empty():
		return _with_indent(shape, indent)
	# ── V1 / V2 / V3 / V6 / V7 ──────────────────────────────────────────────────────────────────
	# The last reading gaps: a rigid body's settings and pushes, a form's Controls, a path walk, the
	# regular-expression words and the wait that freezes the game. Several of them are one idea
	# written as arithmetic on a property, so they go ahead of the compound / assignment split too.
	var gap: Dictionary = gap_statement(text, context)
	if not gap.is_empty():
		return _with_indent(gap, indent)
	# ── V4 / V5 ─────────────────────────────────────────────────────────────────────────────────
	# The window / render lines and the data-asset lines, each recognised WHOLE: every one of them is
	# a property write or a call that the readings below would describe as the Godot spelling it is.
	var windowed: Dictionary = window_statement(text, context)
	if not windowed.is_empty():
		return _with_indent(windowed, indent)
	var data_asset: Dictionary = data_asset_statement(text, context)
	if not data_asset.is_empty():
		return _with_indent(data_asset, indent)
	# ── T6 / T7 / T25 ───────────────────────────────────────────────────────────────────────────
	# A drag, an anchor, a solid, a jump-thru and a seed are each ONE thought a file spells as a
	# property write, so they go ahead of the assignment reading that would describe the property.
	var behaviors: Dictionary = behavior_words_statement(text, context)
	if not behaviors.is_empty():
		return _with_indent(behaviors, indent)
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
	# ── R4 / R5 / R11 ───────────────────────────────────────────────────────────────────────────
	# The questions that span MORE than one operator - a range, an angle window, a distance, an area,
	# an approximate equality, an elapsed-time check, the layout edges - before any reading that would
	# stop at the first operator it found and describe half of one.
	# ── S8 / S9 / S10 / S15 ─────────────────────────────────────────────────────────────────────
	# The four patterns' own questions, ahead of everything: each is a comparison or a predicate call
	# that the general readings below would describe as the operator it is written with rather than as
	# the one thing it asks.
	var systems: Dictionary = godot_systems_condition(text, context)
	if not systems.is_empty():
		return systems
	# ── T1 / T3 ─────────────────────────────────────────────────────────────────────────────────
	# A projectile's distance travelled and a glide's arrival are ONE question each, and the readings
	# below would describe them as the operator they happen to be written with.
	var shape: Dictionary = behavior_shape_condition(text, context)
	if not shape.is_empty():
		return shape
	# U6. Whether the request came back is the AJAX object's own question, before the comparison
	# reading below could describe it as the constant it is written against.
	var answered: Dictionary = web_condition(text, context)
	if not answered.is_empty():
		return answered
	# U10. Whether a handler is wired up is a question about the SIGNAL, not about a call's result.
	var connected: Dictionary = signal_wiring_condition(text, context)
	if not connected.is_empty():
		return connected
	# ── T12 ─────────────────────────────────────────────────────────────────────────────────────
	# What the game is running on, which is a comparison on paper and one settled question in the
	# sheet's words - and the shipped Platform Info pack's words are the ones it uses.
	var around_test: Dictionary = around_objects_condition(text, context)
	if not around_test.is_empty():
		return around_test
	# V1 / V2 / V3. The three questions the last gaps ask - whether a body is asleep, whether a check
	# box is checked, and whether a path walk has reached its end. Ahead of the range reading, which
	# would describe the end of a path as a comparison against one.
	var gap: Dictionary = gap_condition(text, context)
	if not gap.is_empty():
		return gap
	# ── T6 / T23 ────────────────────────────────────────────────────────────────────────────────
	# The drag flag and the offset overlap, ahead of the bare-boolean and the general call readings,
	# which would each describe the line rather than the question the behavior asks with it.
	var behaviors: Dictionary = behavior_words_condition(text, context)
	if not behaviors.is_empty():
		return behaviors
	# S1. Which state the machine is in is the FSM behavior's own question, and the comparison and
	# membership readings below would both answer a narrower one - `state = 2`, `state is in a list`.
	var machine_test: Dictionary = _state_machine_condition(text, context)
	if not machine_test.is_empty():
		return machine_test
	var joined: Dictionary = joined_condition(text, context)
	if not joined.is_empty():
		return joined
	var settled: Dictionary = single_condition(text, context)
	if not settled.is_empty():
		return settled
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
	# S11 / S13. Whether a sound or an animation is running is one question with one name, however the
	# script spells it - ahead of the property reading, which would show the flag instead of the words.
	var playing: Dictionary = media_condition(text, context)
	if not playing.is_empty():
		return playing
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
	# R9. The Timer behavior's own question, ahead of the general existence/comparison readings (which
	# would show `not $Timer.is_stopped()` as an operator rather than as the timer it is about).
	var timer_test: Dictionary = _timer_condition(text, context)
	if not timer_test.is_empty():
		return timer_test
	var existence: Dictionary = _existence_condition(text)
	if not existence.is_empty():
		return existence
	# S4. A countdown's own two questions, ahead of the comparison reading that would show `cooldown ≤ 0`
	# - true, and silent about the pattern the row is part of.
	var countdown_test: Dictionary = _countdown_condition(text, context)
	if not countdown_test.is_empty():
		return countdown_test
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
	# R4 / R11. A range and a pair of layout edges are ONE question written as two terms, so they are
	# claimed before the run is split - after the split each half would read as its own comparison.
	var whole: Dictionary = joined_condition(text, context)
	if not whole.is_empty():
		var whole_pieces: Array = []
		for segment: Variant in (whole.get("segments", []) as Array):
			var whole_segment: Dictionary = segment
			whole_pieces.append([str(whole_segment.get("text", "")), str(whole_segment.get("tone", "plain"))])
		return {"object": str(whole.get("object", "")), "pieces": whole_pieces,
			"pattern": str(whole.get("pattern", ""))}
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
	# R11. An event sheet has no "not on screen" either: the negation of that question IS its own
	# condition, and a reader looking for the bullet-culling row wants to find it by name.
	var outside: Dictionary = outside_layout_reading(text, context)
	if not outside.is_empty():
		return outside
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
## `context` is the sheet's own, so a value naming the script's place ("the direction from Player to
## target") reads with the object names the rest of the row uses; without one the value still reads,
## it just falls back to System the way a context-free grammar call always has.
static func declaration(code: String, context: Dictionary = {}) -> Dictionary:
	var text: String = code.strip_edges()
	var keyword: String = leading_word(text)
	if keyword != "var" and keyword != "const":
		return {}
	var parsed: Dictionary = _declaration_statement(text, keyword, context)
	return parsed


## R41. How a declaration reads as the sheet's own rows: an event sheet declares a local with a
## starting value at the top of its event and fills it in with an action, so a `var` line whose value
## has to be WORKED OUT reads as both - the Local row carrying the type's own starting value, and a
## Set action carrying the work, where the line actually sits. A line whose value already IS a value
## reads as the Local row alone, because nothing was worked out.
##
## {"value": what the Local row shows, "set_value": what the Set action shows ("" for no action)}.
static func declaration_rows(declaration: Dictionary) -> Dictionary:
	var shown: String = str(declaration.get("value", ""))
	var plain: Dictionary = {"value": shown, "set_value": ""}
	if declaration.is_empty() or bool(declaration.get("is_constant", false)):
		return plain
	var raw: String = str(declaration.get("raw_value", shown))
	if declaration_value_is_literal(raw):
		return plain
	# A type with no starting value of its own (an object, a list, a plain "value") has nothing the
	# Local row could show in place of the work, so the work stays on it.
	var starting: String = _declaration_starting_value(str(declaration.get("type_word", "")))
	if starting.is_empty():
		return plain
	return {"value": starting, "set_value": shown}


## R41. True when a declaration's value is a VALUE a reader can see - a number, a piece of text,
## true/false, a type's own constructor or constant - rather than something the event works out from
## other names. Only a lowercase name (a variable, a parameter, a call) counts as work.
static func declaration_value_is_literal(value_text: String) -> bool:
	var text: String = value_text.strip_edges()
	if text.is_empty():
		return true
	var index: int = 0
	var previous: String = ""
	while index < text.length():
		var character: String = text[index]
		if character == "\"" or character == "'":
			index = _string_end(text, index) + 1
			previous = "\""
			continue
		if not (character.is_valid_identifier() or character == "_"):
			previous = character
			index += 1
			continue
		var start: int = index
		while index < text.length():
			var next_character: String = text[index]
			if next_character.is_valid_identifier() or next_character == "_" or next_character.is_valid_int():
				index += 1
				continue
			break
		var word: String = text.substr(start, index - start)
		# A member read belongs to whatever is in front of the dot (`Color.RED` is the colour, not a
		# name of its own), so only the head of a chain is asked about.
		if previous != "." and not LITERAL_WORDS.has(word) and not word.is_valid_int():
			if word.is_empty() or word[0] != word[0].to_upper() or word[0] == "_":
				return false
		previous = "." if index < text.length() and text[index] == "." else ""
	return true


## The words a declaration's value may use and still be a plain value.
const LITERAL_WORDS: Array[String] = ["true", "false", "null", "not", "and", "or", "in", "is"]


## R41. The starting value the sheet shows for a local of this type word, or "" when the type has no
## starting value worth printing (an object, a list, a table, an unknown value).
static func _declaration_starting_value(word: String) -> String:
	if word == translate("number"):
		return "0"
	if word == translate("text"):
		return "\"\""
	if word == translate("true/false"):
		return "false"
	if word == translate("point"):
		return "0, 0"
	return ""


## A value expression with the Godot idioms replaced by their event-sheet reading and every type
## annotation dropped (M11 + M18). Returns the text unchanged when nothing is recognised.
static func expression_text(text: String, context: Dictionary = {}) -> String:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return trimmed
	# R24 / R25 / R29 - a whole controls read (a stick, a gamepad's name, a sensor) is one settled
	# phrase, ahead of the general call rewriting which would only take its arguments apart.
	var controls_value: String = controls_expression(trimmed)
	if not controls_value.is_empty():
		return controls_value
	# R9 - a Timer node's clock is the Timer behavior's own expression, tag and all.
	var timer_value: String = timer_expression(trimmed)
	if not timer_value.is_empty():
		return timer_value
	# X27 - a mission clock shown to the player is m:ss, and the arithmetic that builds it is the
	# format, not the value. Whole-expression only, and only for a clock the file actually runs as a
	# mission timer, so no ordinary division by sixty is claimed.
	var clock_text: String = minutes_seconds_expression(trimmed, context)
	if not clock_text.is_empty():
		return clock_text
	# R3 - the value a tween local is declared from is "a new tween", not a call to repeat back.
	var tween_value: String = tween_expression(trimmed)
	if not tween_value.is_empty():
		return tween_value
	# S10 - the peer id every networked script asks for, as the sheet's own Multiplayer expression.
	if trimmed == "multiplayer.get_unique_id()":
		return "%s.MyID" % OBJECT_MULTIPLAYER
	# U8 - an object's own axes are directions, not arithmetic. Whole-expression only, ahead of the
	# possessive pass which would otherwise spell out the transform a reader never has to think about.
	var faced: String = basis_direction_words(trimmed, context)
	if not faced.is_empty():
		return faced
	# U11 - a callable held in a value is the FUNCTION it names, said the way a Call row says it.
	var held: String = callable_value_words(trimmed)
	if not held.is_empty():
		return held
	# U1 - the direction between two points, decided by the whole expression rather than by any call
	# inside it, so it is asked before the innermost-first pass takes the bracket group apart.
	var vector_value: String = vector_colour_words(trimmed, context)
	if not vector_value.is_empty():
		return vector_value
	# ── V4 / V5 ─────────────────────────────────────────────────────────────────────────────────
	# A picture and a data asset are each ONE settled phrase, so they are answered before the call
	# rewriting takes the chain that fetches them apart into members that say nothing.
	var rendered: String = render_expression(trimmed)
	if not rendered.is_empty():
		return rendered
	var asset: String = data_asset_expression(trimmed)
	if not asset.is_empty():
		return asset
	var field: String = data_field_words(trimmed, context)
	if not field.is_empty():
		return field
	# S1 - the state read back out as a word, which is the FSM behavior's own expression.
	var state_value: String = state_machine_expression(trimmed, context)
	if not state_value.is_empty():
		return state_value
	# S8 - the progress array read by index, before the indexing pass could take `p[0]` apart. What
	# the file holds is untouched; only the words change.
	trimmed = loading_progress_words(trimmed, context)
	# V6 - the pattern searches and the named format, before the call rewriting could take either of
	# them apart into the arguments they are written with.
	trimmed = text_pattern_words(trimmed, context)
	# T5 / T25 / T26 - the line-of-sight test, a weighted draw, the noise and the date are each ONE
	# expression with one settled name, claimed before the call and indexing passes below could take
	# any of them apart. What the file holds is untouched; only the words change.
	trimmed = behavior_expression_words(trimmed, context)
	# U5 - the scene-tree spellings, after the node-path pass has settled `get_node("X")` into `$X` so
	# both ways of writing the same lookup read alike.
	var without_cast: String = scene_tree_words(_drop_casts(_system_words(node_lookup_text(trimmed))))
	# R7. The sheet's own expression names, before any other rewriting sees the Godot spellings they
	# are matched against. Off unless the view asked for the Familiar Words glossary.
	without_cast = familiar_expression_words(without_cast, context)
	# M31 before the call rewriting: a join is decided by the WHOLE expression's shape (is any part of
	# it text?), which the innermost-first call pass would have already taken apart.
	# A whole value wrapped in `str(...)` is the same value: an event sheet shows numbers in text without
	# a conversion, so the conversion is a GDScript chore rather than part of what the row says.
	var joined: String = _rewrite_format(_rewrite_dot_format(_string_call_value(without_cast)))
	joined = _rewrite_join(joined)
	var rewritten: String = _rewrite_calls(joined, context)
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
	if _brace_slot_regex == null:
		_brace_slot_regex = RegEx.create_from_string("\\{([0-9]+)\\}")
	var slot_regex: RegEx = _brace_slot_regex
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
		# R11. ViewportWidth and ViewportHeight are the sheet's own EXPRESSION names - words a reader
		# types into an expression field - so they are not translated, exactly as `max` is not.
		out = out.replace("get_viewport_rect().size.x", "ViewportWidth")
		out = out.replace("get_viewport_rect().size.y", "ViewportHeight")
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
	# ── V7 ──────────────────────────────────────────────────────────────────────────────────────
	# The rest of the numbers a profiling script reads. `tickcount` and `dt` are names a reader TYPES
	# into an expression field, so like `fps` above they are whole spellings and unlike it they are
	# not translated. The microsecond clock keeps its unit, because it is a different number from the
	# one `time` names and a reader who mixed them up would be out by a million.
	if out.contains("Engine.get_frames_drawn()"):
		out = out.replace("Engine.get_frames_drawn()", "tickcount")
	if out.contains("Time.get_ticks_usec()"):
		out = out.replace("Time.get_ticks_usec()", translate("now (microseconds)"))
	if out.contains("delta_time()"):
		out = out.replace("get_physics_process_delta_time()", "dt")
		out = out.replace("get_process_delta_time()", "dt")
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
	if _delta_regex == null:
		_delta_regex = RegEx.create_from_string("(?<![\\w.])delta(?![\\w])")
	var regex: RegEx = _delta_regex
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
	if _percent_slot_regex == null:
		_percent_slot_regex = RegEx.create_from_string("%[-+ 0#]*[0-9]*(?:\\.[0-9]+)?[sdfxXvc%]")
	var slot_regex: RegEx = _percent_slot_regex
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
		# U6. A RUN of indexes - `data["scores"][0]["name"]` - is one address into one table, and an
		# event sheet says an address the way it says every other chain: the head owns it and the steps
		# follow. Read step by step it comes out as three possessions of three different things, which
		# is exactly the reading a beginner cannot follow.
		var nested: Dictionary = _nested_index_run(text, index)
		if not nested.is_empty():
			out += str(nested.get("text", ""))
			index = int(nested.get("end", close_at + 1))
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


## U6. The run of two or more indexes starting at `open_at`, as {"text", "end"} - the possessive
## address it reads as and where the run stopped - or {} when there is no run to read.
##
## Every step must be a LITERAL: a key worked out at run time is a value the row has to show as the
## expression it is, and folding it into an address would print a name the file never writes. A single
## index is left alone, because M31's `inventory's "potion"` is already the sentence for that.
static func _nested_index_run(text: String, open_at: int) -> Dictionary:
	var steps: PackedStringArray = PackedStringArray()
	var cursor: int = open_at
	while cursor < text.length() and text[cursor] == "[":
		var close_at: int = closing_paren(text, cursor)
		if close_at < 0:
			return {}
		var key: String = text.substr(cursor + 1, close_at - cursor - 1).strip_edges()
		if key.is_empty():
			return {}
		if _is_string_literal(key):
			steps.append(_unquote(key.trim_prefix("&")))
		elif key.is_valid_int():
			steps.append(key)
		else:
			return {}
		cursor = close_at + 1
	if steps.size() < 2:
		return {}
	return {"text": "'s %s" % " ".join(steps), "end": cursor}


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
		# U10. A signal held in a variable is a signal, and the Local row says so - the sheet's own word
		# for the thing, not Godot's type name.
		"Signal":
			return translate("signal")
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
		"Image", "Texture", "Texture2D", "ViewportTexture", "ImageTexture":
			# V5. A screenshot and a rendered viewport are both a PICTURE to a reader. Which of
			# Godot's two spellings holds it is a fact about the API, not about the row.
			return translate("image")
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
	# R3. Waiting on a tween is waiting for the animation to end, which is the whole thought - the
	# local's name adds nothing a reader of the rows above does not already have.
	if body.ends_with(".finished") and is_tween_local(body.substr(0, body.length() - 9), context):
		return _sentence(OBJECT_SYSTEM, "⏳ Wait for tween to finish", {})
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
static func _declaration_statement(text: String, keyword: String, context: Dictionary = {}) -> Dictionary:
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
		"value": expression_text(value_text, context),
		# R41 - the value exactly as the file wrote it, which is what decides whether the declaration
		# is a starting value the Local row can carry on its own or a value the event has to work out.
		"raw_value": value_text,
		"segments": [
			{"text": "%s %s" % [translate("Local"), type_word(declared_type)], "tone": "plain"},
			{"text": " %s = " % name_text, "tone": "name"},
			{"text": expression_text(value_text, context), "tone": "value"}
		]
	}


## S4. The countdown sentences, for a number this file counts down by a per-frame delta AND asks
## about against zero somewhere - the two halves that make it a countdown rather than a subtraction.
## Which numbers those are is a whole-file question, answered once per rebuild and handed in as
## `countdown_variables`; with no such fact in the context nothing here fires and every line keeps the
## arithmetic reading it has today.
##
##   cooldown -= delta                                  Player ▸ Count down cooldown (by dt)
##   invincible_for = max(0.0, invincible_for - delta)   Player ▸ Count down invincible for (never below 0)
##   cooldown = 0.5                                      Player ▸ Start cooldown for 0.5 seconds
##
## The object is the script's own, because a countdown is a piece of that object's state - the same
## object the Start and the has-run-out question below name, so the three rows read as one idea.
static func _countdown_statement(text: String, context: Dictionary) -> Dictionary:
	var countdowns: Dictionary = context.get("countdown_variables", {})
	if countdowns.is_empty():
		return {}
	var step: Dictionary = EventSheetPatternReadings.countdown_step(text)
	if not step.is_empty() and countdowns.has(str(step.get("name", ""))):
		var name_text: String = str(step.get("name", ""))
		var note: String = str(step.get("note", ""))
		if note.is_empty():
			note = "by dt"
		var counted: Dictionary = _sentence(script_object(context), "Count down {name}",
			{"name": [_member_word(name_text), "name"]})
		(counted["segments"] as Array).append({"text": " (%s)" % translate(note), "tone": "muted"})
		return counted
	# `cooldown = 0.5` on a countdown is the event-sheet Start: the number IS the seconds it runs for.
	var equals_at: int = top_level_index(text, " = ")
	if equals_at <= 0:
		return {}
	var target: String = text.substr(0, equals_at).strip_edges()
	var seconds: String = text.substr(equals_at + 3).strip_edges()
	if not countdowns.has(target) or not seconds.is_valid_float():
		return {}
	return _sentence(script_object(context), "Start {name} for {seconds} seconds", {
		"name": [_member_word(target), "name"],
		"seconds": [expression_text(seconds, context), "value"]
	})


## S1. The chip a hand-rolled state machine's rows wear. The behavior the sheet has for this shape is
## called FSM, and a row that switches state belongs to it whether the machine is a mounted pack or
## an enum this file writes out - which is the whole point of reading one as the other.
const STATE_MACHINE_CHIP := "FSM"


## S1. Switching state, the two ways a Godot script writes it: through the transition function
## (`change_state(State.JUMP)`) or straight onto the variable (`state = State.JUMP`). Both are the
## FSM behavior's one action, so both read as it. A call that carries anything other than one of this
## machine's own states is not a transition and keeps its own reading.
static func _state_machine_statement(text: String, context: Dictionary) -> Dictionary:
	var machine: Dictionary = context.get("state_machine", {})
	if machine.is_empty():
		return {}
	var named: String = ""
	var call: Dictionary = call_parts(text)
	if not call.is_empty() and str(call.get("target", "")).is_empty() \
			and str(call.get("method", "")) == str(machine.get("transition", "")):
		var args: PackedStringArray = call.get("args", PackedStringArray())
		if args.size() == 1:
			named = EventSheetStateMachineFacts.state_of(args[0], machine)
	if named.is_empty():
		var equals_at: int = top_level_index(text, " = ")
		if equals_at <= 0 or text.substr(0, equals_at).strip_edges() != str(machine.get("variable", "")):
			return {}
		named = EventSheetStateMachineFacts.state_of(text.substr(equals_at + 3), machine)
	if named.is_empty():
		return {}
	return _behaviour_sentence(script_object(context), STATE_MACHINE_CHIP, "Go to state {state}",
		{"state": ["\"%s\"" % named, "value"]})


## S1. The two questions a machine answers, each in one name and in a list: which state it is in now,
## and which one it was in before. `state == State.JUMP` and `state in [State.IDLE, State.RUN]` are
## the comparison and the membership a general reading would show; the FSM behavior asks them by name.
static func _state_machine_condition(text: String, context: Dictionary) -> Dictionary:
	var machine: Dictionary = context.get("state_machine", {})
	if machine.is_empty():
		return {}
	var current: String = str(machine.get("variable", ""))
	var previous: String = str(machine.get("previous", ""))
	var equals_at: int = top_level_index(text, " == ")
	if equals_at > 0:
		var asked: String = text.substr(0, equals_at).strip_edges()
		var named: String = EventSheetStateMachineFacts.state_of(text.substr(equals_at + 4), machine)
		if named.is_empty() or not (asked == current or (asked == previous and not previous.is_empty())):
			return {}
		return _behaviour_sentence(script_object(context), STATE_MACHINE_CHIP,
			"Current state is {state}" if asked == current else "Previous state is {state}",
			{"state": ["\"%s\"" % named, "value"]})
	var in_at: int = top_level_index(text, " in ")
	if in_at <= 0:
		return {}
	var subject: String = text.substr(0, in_at).strip_edges()
	if not (subject == current or (subject == previous and not previous.is_empty())):
		return {}
	var listed: PackedStringArray = EventSheetStateMachineFacts.states_of_list(
		text.substr(in_at + 4), machine)
	if listed.is_empty():
		return {}
	var quoted: PackedStringArray = PackedStringArray()
	for named_state: String in listed:
		quoted.append("\"%s\"" % named_state)
	return _behaviour_sentence(script_object(context), STATE_MACHINE_CHIP,
		"Current state in list {states}" if subject == current else "Previous state in list {states}",
		{"states": [", ".join(quoted), "value"]})


## S1. The state read back out as a WORD - `State.keys()[state]`, the line every debug label holds -
## as the FSM behavior's own expression. "" when the value is anything else.
static func state_machine_expression(text: String, context: Dictionary) -> String:
	var machine: Dictionary = context.get("state_machine", {})
	if machine.is_empty():
		return ""
	var keys_call: String = "%s.keys()[" % str(machine.get("enum_name", ""))
	if not text.begins_with(keys_call) or not text.ends_with("]"):
		return ""
	var asked: String = text.substr(keys_call.length(), text.length() - keys_call.length() - 1).strip_edges()
	var previous: String = str(machine.get("previous", ""))
	if asked == str(machine.get("variable", "")):
		return "%s.%s.CurrentState" % [script_object(context), STATE_MACHINE_CHIP]
	if not previous.is_empty() and asked == previous:
		return "%s.%s.PreviousState" % [script_object(context), STATE_MACHINE_CHIP]
	return ""


## S6. `target = null` is the event-sheet Forget: the object is not destroyed, this row simply stops
## holding on to it. Only a plain name of this file's own is claimed, because `sprite.texture = null`
## is a property being cleared, which is a Set and reads as one.
static func _forget_statement(text: String, context: Dictionary) -> Dictionary:
	var equals_at: int = top_level_index(text, " = ")
	if equals_at <= 0 or text.substr(equals_at + 3).strip_edges() != "null":
		return {}
	var target: String = text.substr(0, equals_at).strip_edges()
	if not is_identifier(target) or is_engine_property(target, context):
		return {}
	return _sentence(script_object(context), "Forget {name}", {"name": [_member_word(target), "name"]})


## S4. The two questions a countdown answers. `x <= 0` is the event-sheet "has run out", `x > 0` is
## "is running"; every other comparison against zero keeps its operator, because only these two are
## the same question the Timer and Cooldown rows already ask.
static func _countdown_condition(text: String, context: Dictionary) -> Dictionary:
	var countdowns: Dictionary = context.get("countdown_variables", {})
	if countdowns.is_empty():
		return {}
	for pair: Array in [[" <= ", "{name} has run out"], [" > ", "{name} is running"]]:
		var operator: String = str(pair[0])
		var at: int = top_level_index(text, operator)
		if at <= 0:
			continue
		var target: String = text.substr(0, at).strip_edges()
		var right: String = text.substr(at + operator.length()).strip_edges()
		if not countdowns.has(target) or (right != "0" and right != "0.0"):
			continue
		return _sentence(script_object(context), str(pair[1]), {"name": [_member_word(target), "name"]})
	return {}


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
	# S18. The camera follow is written THROUGH a call (`...lerp(...)`), so it is asked before the
	# simple-target gate turns the whole line down.
	var scrolled: Dictionary = _scroll_toward_assignment(target, assigned, context)
	if not scrolled.is_empty():
		return scrolled
	if not is_simple_target(target):
		return {}
	# R5. Writing the clock into a variable is the sheet's "Set ... to now" - the other half of the
	# cooldown idiom whose question reads "X seconds have passed since".
	var now_write: Dictionary = _now_assignment(target, assigned, context)
	if not now_write.is_empty():
		return now_write
	var split: Array = _split_object(target, context)
	var object_name: String = str(split[0])
	# U1. A colour eased toward another colour is ONE verb in the sheet's words, and the shape only
	# means that when the line reads the very member it writes.
	var eased_colour: Dictionary = colour_ease_statement(object_name, str(split[1]), assigned, context)
	if not eased_colour.is_empty():
		return eased_colour
	# N8. A property every reader knows as a BEHAVIOUR knob - a body's velocity, a camera's zoom, an
	# emitter's switch - reads in that behaviour's words, decided by the object's known class.
	var behaviour: Dictionary = _behaviour_assignment(object_name, str(split[1]), assigned, target, context)
	if not behaviour.is_empty():
		return behaviour
	# ── T10 / T11 ───────────────────────────────────────────────────────────────────────────────
	# Where an object sits in the drawing order, and how its text is styled. Both would otherwise
	# read as the engine property they are written with rather than as the one row an event sheet
	# has for them, so they are asked ahead of the plain "Set <property> to <value>" below.
	var around: Dictionary = around_objects_assignment(object_name, str(split[1]), assigned, context)
	if not around.is_empty():
		return around
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
	# R30. `n.position = n.position.snapped(...)` says `n` twice - once in the object column, once at
	# the head of the value - and the second one is noise: the row already said whose position this
	# is. The receiver comes off the value when it is the SAME receiver the target names, so the row
	# reads `n ▸ Set position to position snapped to 8, 8`.
	var shown_value: String = expression_text(_without_repeated_receiver(assigned, target), context)
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


## R30. The assigned value with the target's own receiver taken off the front of it, when the value
## starts with exactly that receiver: the object column has already said `n`, so `n.position` in the
## value is the row repeating itself. Only ever an identifier receiver a dotted target actually named -
## a target with no receiver of its own drops nothing, and neither does a value that starts somewhere
## else (`n.position = other.position` keeps the whole of `other.position`, which is the point).
static func _without_repeated_receiver(assigned: String, target: String) -> String:
	var target_text: String = target.strip_edges().trim_prefix("self.")
	var dot_at: int = target_text.find(".")
	if dot_at <= 0:
		return assigned
	var receiver: String = target_text.substr(0, dot_at)
	if not is_identifier(receiver):
		return assigned
	var value: String = assigned.strip_edges()
	var prefix: String = "%s." % receiver
	if not value.begins_with(prefix):
		return assigned
	var rest: String = value.substr(prefix.length())
	# The head of the rest must be a member name, so a value that merely STARTS with the receiver's
	# letters (`n.x + n.y`) still drops only the one prefix it was asked to, and a value whose head
	# is not a name at all is left whole.
	return rest if is_identifier(rest.split(".")[0].split("(")[0].split("[")[0].split(" ")[0]) else assigned


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
	# R8. Pausing and the game speed are two different actions in the sheet's words, and both are
	# always on: these are the names the shipped rows already carry, not a friendlier spelling.
	if bare_target == "get_tree().paused":
		if assigned == "true":
			return _sentence(OBJECT_SYSTEM, "Pause the game", {})
		if assigned == "false":
			return _sentence(OBJECT_SYSTEM, "Unpause", {})
		return {}
	if bare_target == "Engine.time_scale":
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
	# S16. Writing the material slot puts an effect on the object, or takes it off.
	if EFFECT_SLOTS.has(member):
		return _effects_assignment(object_name, assigned, context)
	# ── S11 / S13 / S14 ─────────────────────────────────────────────────────────────────────────
	# The sprite, sound and juice families, ahead of the plain member arms below: each of them is a
	# member write whose SHAPE says which verb it is, so the shape is asked first and an unrecognised
	# one falls straight through to the arms.
	var juiced: Dictionary = juice_assignment(object_name, object_class, member, owner_text, assigned, context)
	if not juiced.is_empty():
		return juiced
	var media: Dictionary = media_assignment(object_name, object_class, member, owner_text, assigned, context)
	if not media.is_empty():
		return media
	# U7. The light knobs, ahead of the arms below for the same reason: `color` on a light and `color`
	# on anything else are two different rows, and the class is what tells them apart.
	var lit: Dictionary = lighting_assignment(object_name, object_class, member, owner_text, assigned, context)
	if not lit.is_empty():
		return lit
	# U12. A video's own film, and the two knobs that say how far a sound carries.
	var played: Dictionary = long_tail_media_assignment(object_name, object_class, member, owner_text,
		assigned, context)
	if not played.is_empty():
		return played
	match member:
		"visible":
			if assigned != "true" and assigned != "false":
				return {}
			var is_layer: bool = familiar_words and _class_is_any(object_class, PackedStringArray(["CanvasLayer"]))
			var layer_label: String = "%s %s" % [object_name, translate("(layer)")] if is_layer else object_name
			# T10. Turning a whole layer off is a LAYER row, whichever of the two spellings the
			# glossary is showing, so both carry the pattern the drawing-order readings claim.
			if is_layer:
				return _patterned(_sentence(layer_label,
					"Set layer visible" if assigned == "true" else "Set layer invisible", {}), "layers")
			if _class_is_any(object_class, LAYER_CLASSES):
				return _patterned(_sentence(object_name,
					"Set visible" if assigned == "true" else "Set invisible", {}), "layers")
			return _sentence(object_name, "Set visible" if assigned == "true" else "Set invisible", {})
		"flip_h":
			# S11. A mirror driven by a TEST is the same verb with its condition said out loud - a
			# `flip_h = dir < 0` sets it either way every tick, which "Set mirrored" alone would hide.
			if assigned != "true" and assigned != "false":
				return _mirror_when(object_name, "Set mirrored when {test}", member, assigned, context)
			return _with_pattern(_sentence(object_name,
				"Set mirrored" if assigned == "true" else "Set not mirrored", {}),
				"sprite_animation", _member_line(owner_text, member, assigned))
		"flip_v":
			if assigned != "true" and assigned != "false":
				return _mirror_when(object_name, "Set flipped when {test}", member, assigned, context)
			return _with_pattern(_sentence(object_name,
				"Set flipped" if assigned == "true" else "Set not flipped", {}),
				"sprite_animation", _member_line(owner_text, member, assigned))
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


## The object every Call row belongs to, whichever function it names.
const OBJECT_FUNCTIONS := "Functions"


## S7. `commands["equip"].call()` and `commands["equip"].call(arg)` - a table of functions, called by
## the key that holds one. Claimed only for a plain table name indexed by ONE entry: a longer chain is
## an object's member and reads as one. {} for anything else, so an ordinary `.call()` keeps its code.
static func _stored_function_call(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if call.is_empty() or str(call.get("method", "")) != "call":
		return {}
	var entry: String = str(call.get("target", "")).strip_edges()
	if not entry.ends_with("]"):
		return {}
	var open_at: int = entry.find("[")
	if open_at <= 0:
		return {}
	var table: String = entry.substr(0, open_at).strip_edges()
	var key: String = entry.substr(open_at + 1, entry.length() - open_at - 2).strip_edges()
	if not is_identifier(table) or key.is_empty() or key.contains("["):
		return {}
	var stored: Dictionary = _sentence(OBJECT_FUNCTIONS, "Call the function stored in {table} {key}", {
		"table": [table, "name"],
		"key": [expression_text(key, context), "value"]
	})
	(stored["segments"] as Array).append({"text": " (%s)" % translate("a table of functions"), "tone": "muted"})
	return stored


## The call shapes with a settled sentence: destroy, emit, change scene. Anything else is left to the
## caller's own Object / Verb / parameters rendering.
static func _call_statement(text: String, context: Dictionary) -> Dictionary:
	# Checked before the plain call split, because the receiver is itself a call: `get_tree()` is not
	# an object a sentence can name, but the scene switch behind it is a settled event-sheet action.
	const SCENE_HEAD := "get_tree().change_scene_to_file("
	if text.begins_with(SCENE_HEAD) and text.ends_with(")"):
		var scene_path: String = text.substr(SCENE_HEAD.length(), text.length() - SCENE_HEAD.length() - 1)
		if not scene_path.strip_edges().is_empty():
			# R8. Go to layout is not a friendlier spelling of Godot's call - it IS the name of the
			# action the sheet's own Scene Flow rows carry, so it is always on, and the layout is named
			# the way the reader named the file. The whole path stays one hover away on the row.
			return _sentence(OBJECT_SYSTEM, "Go to layout {path}", {"path": [layout_name(scene_path), "value"]})
	# S6. `get_parent().remove_child(self)` takes an object OUT of the layout without destroying it -
	# a different thing from Destroy, and the sheet has a different word for it. Said out loud, because
	# the reader's first question about a removed object is whether it is still alive.
	if text == "get_parent().remove_child(self)":
		var removed: Dictionary = _sentence(script_object(context), "Remove from layout", {})
		(removed["segments"] as Array).append(
			{"text": " (%s)" % translate("kept alive, not destroyed"), "tone": "muted"})
		return removed
	# R8. Godot reloads the current scene; an event sheet restarts the layout.
	if text == "get_tree().reload_current_scene()":
		return _sentence(OBJECT_SYSTEM, "Restart layout", {})
	# R8. Leaving the game is one action with one name, whichever way the script spells the call.
	if text == "get_tree().quit()" or text == "get_tree().quit(0)":
		return _sentence(OBJECT_SYSTEM, "Quit game", {})
	# ── P6 ──────────────────────────────────────────────────────────────────────────────────────
	# The one-shot timer and its callback, ahead of every other call shape: the receiver is itself a
	# call, so nothing below could name it, and the sheet already has the "wait, then" this line is.
	var wait_then: Dictionary = _wait_then_statement(text, context)
	if not wait_then.is_empty():
		return wait_then
	# S7. `commands["equip"].call()` runs whatever function that table entry holds. The receiver is an
	# entry, not an object, so nothing below could name it - and the row belongs to Functions, which is
	# where every other Call row lives.
	var stored_call: Dictionary = _stored_function_call(text, context)
	if not stored_call.is_empty():
		return stored_call
	var group_call: Dictionary = _group_call_statement(text, context)
	if not group_call.is_empty():
		return group_call
	var tween: Dictionary = _tween_statement(text, context)
	if not tween.is_empty():
		return tween
	# R9. A Timer node IS the sheet's Timer behavior, so its two verbs read as that behavior's own
	# words before the generic Object ▸ Verb split can turn them into `Timer ▸ Start`.
	var timer_step: Dictionary = _timer_statement(text, context)
	if not timer_step.is_empty():
		return timer_step
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
	# ── S11 / S12 / S13 ─────────────────────────────────────────────────────────────────────────
	# The focus, dialog, mixer, seek and animation-tree calls, in the words their own objects publish.
	# Ahead of the engine verbs so `set("parameters/blend_position", v)` reads as the blend it is
	# rather than as a property named by a path.
	var media_step: Dictionary = media_call(call.duplicate().merged({"line": text}, true), context)
	if not media_step.is_empty():
		return media_step
	# ── U6 / U8 / U9 / U10 / U11 / U12 ──────────────────────────────────────────────────────────
	# The long tail's call shapes, each recognised WHOLE: a web request, a face-that, work handed to a
	# thread, the two signal steps that are actions, a signal held in a variable, a call made by name
	# and a video player's verbs. Ahead of the generic Object ▸ Verb split, which would describe every
	# one of them as the method it is written with.
	var long_tail: Dictionary = long_tail_call(call, text, context)
	if not long_tail.is_empty():
		return long_tail
	var engine_verb: Dictionary = _engine_verb_call(call, context)
	if not engine_verb.is_empty():
		return engine_verb
	# ── S16 / S17 ───────────────────────────────────────────────────────────────────────────────
	# A shader parameter is an EFFECT parameter and a tilemap cell is a TILE, in both node
	# generations. Checked here, among the curated shapes, so an unrecognised call still falls
	# through to the Object ▸ Verb chips below.
	var effect_step: Dictionary = _effects_call(method, args, target, context)
	if not effect_step.is_empty():
		return effect_step
	var tile_step: Dictionary = _tilemap_call(method, args, target, context)
	if not tile_step.is_empty():
		return tile_step
	# ── T10 / T11 / T12 ─────────────────────────────────────────────────────────────────────────
	# The drawing order, the text styling and the browser / platform actions: three families whose
	# calls the Object ▸ Verb chips below would spell as the engine method they are written with.
	var around_step: Dictionary = around_objects_call(target, method, args, context)
	if not around_step.is_empty():
		return around_step
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
	# S2. Putting an object back into a POOL is not a list step - it is the end of that object's life
	# on screen, and the sheet's word for it names the object rather than the list. Only for a list
	# this file actually drains as a pool; every other push back is still a push back.
	var pools: Dictionary = context.get("pool_variables", {})
	if pools.has(receiver) and args.size() == 1 and method in ["push_back", "push_front", "append"]:
		var returned: Dictionary = _sentence(object_of_reference(args[0].strip_edges()),
			"Return to pool", {})
		(returned["segments"] as Array).append(
			{"text": " (%s)" % translate("hidden, ticking off, back in pool"), "tone": "muted"})
		return returned
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
	# S7. `items.sort_custom(func(a, b): return a.price < b.price)` is the event-sheet Sort by, with the
	# direction said in words rather than left as an operator to decode. Only a one-line lambda
	# comparing the SAME member of both items is claimed; anything else keeps its own code.
	if method == "sort_custom" and args.size() == 1:
		var sorted_by: Dictionary = sorted_member(args[0])
		if not sorted_by.is_empty():
			values["member"] = [str(sorted_by.get("member", "")), "value"]
			var order: String = "lowest first" if bool(sorted_by.get("lowest", true)) else "highest first"
			var sorted_row: Dictionary = _sentence(str(split[0]), "Sort {name} by {member}", values)
			(sorted_row["segments"] as Array).append({"text": " (%s)" % translate(order), "tone": "muted"})
			return sorted_row
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
		# S5. A section and a key together address ONE item, and an event sheet addresses an item by one
		# name: `player/score`. Only when both are literals - a key worked out at run time keeps the two
		# apart, because joining them would show a name the file never writes.
		var addressed: String = storage_item_key(args[0], args[1])
		if not addressed.is_empty():
			return _sentence(OBJECT_STORAGE, "Set item {key} to {value}", {
				"key": [addressed, "name"],
				"value": [expression_text(args[2], context), "value"]
			})
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


## S5. The one name a section and a key address together - `"player"` + `"score"` is the item
## `player/score`. "" unless BOTH are literals, because a name assembled at run time is not a name
## this reading may print.
static func storage_item_key(section: String, key: String) -> String:
	if not _is_string_literal(section) or not _is_string_literal(key):
		return ""
	var section_text: String = _unquote(section.strip_edges().trim_prefix("&"))
	var key_text: String = _unquote(key.strip_edges().trim_prefix("&"))
	if section_text.is_empty() or key_text.is_empty():
		return ""
	return "%s/%s" % [section_text, key_text]


## The file extensions a saved game is written under. `save` and `load` are ordinary English and live
## on plenty of other classes, so a literal path naming one of these is what says "this is storage".
const STORAGE_EXTENSIONS: PackedStringArray = [".cfg", ".ini", ".json", ".save", ".dat"]


## True when a value is a literal path to a save file - the only argument a bare `save` / `load`
## may have and still be honestly readable as storage.
static func _is_config_path(value: String) -> bool:
	if not _is_string_literal(value):
		return false
	var path: String = _unquote(value.strip_edges().trim_prefix("&")).to_lower()
	# S5. The extension is what says "this is a save file", not the folder: `sprite.save(
	# "user://shot.png")` writes an image and keeps its own reading, which is why a blanket `user://`
	# rule would be exactly the confident lie this grammar refuses.
	for extension: String in STORAGE_EXTENSIONS:
		if path.ends_with(extension):
			return true
	return false


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
	# S5. A saved value read back names Local Storage in the value itself (`Local Storage.Item("x")`),
	# so the row belongs to whatever it is being PUT INTO - naming the same object twice on one row
	# reads as two objects.
	if text.begins_with("Input.get_action_strength(") or text.begins_with("Input.get_action_raw_strength("):
		return OBJECT_GAMEPAD
	# R29 - a sensor is the phone's, and the sheet's phone is the Touch object.
	if CONTROLS_SENSOR_WORDS.has(text):
		return OBJECT_TOUCH
	# R24 / R25 - the sticks and the pads themselves belong to the Gamepad object.
	if text.begins_with("Input.get_joy_") or text.begins_with("Input.is_joy_") \
			or text.begins_with("Input.get_connected_joypads"):
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
		# S9. What the row DOES is switch a collision off, and the movement behaviors say exactly that.
		# The layers a body is ON keep the neutral wording, because joining a layer and colliding with
		# one are two different things and one sentence for both would say neither.
		if method == "set_collision_mask_value":
			var mask_template: String = "Enable collisions with {layer}" if switch == "true" else "Disable collisions with {layer}"
			return _sentence(object_name, mask_template, {"layer": [layer_shown, "value"]})
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
	# S18. The camera page of the sheet says "Make current"; that is the row's name, not a friendlier
	# spelling of Godot's call.
	if method == "make_current" and _class_is_any(known_class, CAMERA_CLASSES):
		return _patterned(_sentence(object_name, "Make current", {}), "camera")
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
		return _patterned(_sentence(object_name, "Set zoom to {percent}",
			{"percent": [percent, "value"]}), "camera")
	# S18. Smoothing is a switch on the camera page, so it reads as one - never as a property write.
	if member == "position_smoothing_enabled" and _class_is_any(known_class, CAMERA_CLASSES):
		if value != "true" and value != "false":
			return {}
		return _patterned(_sentence(object_name, "Set smoothing {state}",
			{"state": [translate("on") if value == "true" else translate("off"), "name"]}), "camera")
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
			# S13. The player is the object the row acts on, exactly as the lines around it are: a
			# sound's file, pitch, bus and volume are all set on the same named player, and filing the
			# Play under a different object split one thought across two column entries.
			if _class_is_any(object_class, AUDIO_CLASSES):
				return _with_pattern(_sentence(object_name, "Play sound", {}), "sound",
					"%s.play()" % receiver)
		"stop":
			if not arguments.is_empty():
				return {}
			if _class_is_any(object_class, ANIMATION_CLASSES):
				return _sentence(object_name, "Stop animation", {})
			if _class_is_any(object_class, AUDIO_CLASSES):
				return _with_pattern(_sentence(object_name, "Stop sound", {}), "sound",
					"%s.stop()" % receiver)
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


## R3. The words an event sheet uses for the thing a property is animated ALONG - a tween's own
## property path spelled the way the sheet spells that property everywhere else.
const TWEEN_PROPERTY_WORDS: Dictionary = {
	"modulate:a": "opacity",
	"self_modulate:a": "opacity",
	"modulate": "colour",
	"scale": "size",
	"scale:x": "size X",
	"scale:y": "size Y",
	"rotation": "angle",
	"rotation_degrees": "angle",
	"global_position": "position"
}

## R3. The curve shape a `set_trans` names, in plain words.
const TWEEN_TRANSITION_WORDS: Dictionary = {
	"Tween.TRANS_LINEAR": "Linear",
	"Tween.TRANS_SINE": "Sine",
	"Tween.TRANS_QUAD": "Quad",
	"Tween.TRANS_CUBIC": "Cubic",
	"Tween.TRANS_QUART": "Quart",
	"Tween.TRANS_QUINT": "Quint",
	"Tween.TRANS_EXPO": "Expo",
	"Tween.TRANS_ELASTIC": "Elastic",
	"Tween.TRANS_CIRC": "Circ",
	"Tween.TRANS_BACK": "Back",
	"Tween.TRANS_BOUNCE": "Bounce",
	"Tween.TRANS_SPRING": "Spring"
}

## R3. Which end of the curve a `set_ease` puts the slow part on. The word here PICKS the catalog
## phrase (`ease = {curve} out`) rather than being shown on its own.
const TWEEN_EASE_WORDS: Dictionary = {
	"Tween.EASE_IN": "in",
	"Tween.EASE_OUT": "out",
	"Tween.EASE_IN_OUT": "in-out",
	"Tween.EASE_OUT_IN": "out-in"
}

## R3. The two calls that hand back a brand new tween. A local holding one of these is the chain's
## name, which is how the rows below it know they belong together.
const TWEEN_MAKERS: Array[String] = [
	"create_tween()", "get_tree().create_tween()", "self.create_tween()"
]


## R3 / M32. A tween chain reads as ONE Tween action per `tween_*` step, on the object being tweened,
## in the sheet's own Tween words: `Player ▸ Tween position to target in 0.5 seconds` with the easing
## as a chip and the sequencing said quietly. {} for anything that is not a step of a chain this file
## can prove - a tween held somewhere the reading cannot see keeps its plain call reading.
static func _tween_statement(text: String, context: Dictionary) -> Dictionary:
	var parts: Dictionary = tween_chain_parts(text, context)
	if parts.is_empty():
		return {}
	var method: String = str(parts.get("method", ""))
	var arguments: PackedStringArray = parts.get("args", PackedStringArray())
	var object_name: String = script_object(context)
	match method:
		"kill":
			return _sentence(object_name, "Stop tween", {})
		"set_parallel":
			return _sentence(object_name, "Tween the next steps at the same time", {})
		"set_loops":
			if arguments.is_empty():
				return _sentence(object_name, "Tween repeat forever", {})
			return _sentence(object_name, "Tween repeat {count} times", {
				"count": [expression_text(arguments[0], context), "value"]
			})
		"tween_interval":
			if arguments.is_empty():
				return {}
			return _sentence(object_name, "Tween wait {seconds} seconds", {
				"seconds": [expression_text(arguments[0], context), "value"]
			})
		"tween_callback":
			if arguments.is_empty():
				return {}
			return _sentence(object_name, "Tween then {action}", {
				"action": [tween_callback_words(arguments[0], context), "name"]
			})
		"tween_property":
			return _tween_property_sentence(text, parts, context)
		"tween_method":
			# S16 - the one `tween_method` shape with a sentence: an effect parameter driven over
			# time. Anything else keeps its code, because a lambda can do anything.
			return _tween_effect_sentence(arguments, context)
	return {}


## R3. The Tween Property row itself: the tweened object, the sheet's word for the property, the
## value, the seconds, then the easing chip and the sequencing note the chain earned.
static func _tween_property_sentence(text: String, parts: Dictionary, context: Dictionary) -> Dictionary:
	var arguments: PackedStringArray = parts.get("args", PackedStringArray())
	if arguments.size() < 4:
		return {}
	var object_name: String = arguments[0].strip_edges()
	if object_name == "self" or object_name.is_empty():
		object_name = script_object(context)
	else:
		object_name = object_of_reference(object_name)
	var reading: Dictionary = _sentence(object_name, "Tween {property} to {value} in {duration} seconds", {
		"property": [tween_property_word(_unquote(arguments[1])), "name"],
		"value": [expression_text(arguments[2], context), "value"],
		"duration": [expression_text(arguments[3], context), "value"]
	})
	var easing: String = tween_easing_words(str(parts.get("modifiers", "")))
	if not easing.is_empty():
		(reading["segments"] as Array).append({"text": " ", "tone": "plain"})
		(reading["segments"] as Array).append({"text": easing, "tone": "chip"})
	var note: String = tween_sequence_note(text, context)
	if not note.is_empty():
		(reading["segments"] as Array).append({"text": " ", "tone": "plain"})
		(reading["segments"] as Array).append({"text": note, "tone": "muted"})
	# R3 - what the SAME line said about the chain before it got to this step. `create_tween()
	# .set_loops(3).tween_property(...)` is one row, the property step, wearing `repeat 3 times`:
	# the chain call is a setting on the step, not a row that swallows it.
	for chain_note: String in tween_chain_notes(parts):
		(reading["segments"] as Array).append({"text": " ", "tone": "plain"})
		(reading["segments"] as Array).append({"text": chain_note, "tone": "muted"})
	return reading


## R3. The muted notes a step earned from the chain calls written BEFORE it on its own line:
## `repeat 3 times` / `repeat forever` from `set_loops`, `(at the same time)` from `set_parallel`.
## Empty for a step written on a line of its own, which is every chain that names its tween.
static func tween_chain_notes(parts: Dictionary) -> PackedStringArray:
	var notes: PackedStringArray = PackedStringArray()
	if bool(parts.get("parallel", false)):
		notes.append(translate("(at the same time)"))
	if not bool(parts.get("loops_named", false)):
		return notes
	var count: String = str(parts.get("loops", "")).strip_edges()
	if count.is_empty() or count == "0":
		# `set_loops()` and `set_loops(0)` are both Godot's forever.
		notes.append(translate("repeat forever"))
	else:
		notes.append(_fill(translate("repeat {count} times"), {"count": count}))
	return notes


## R3. The step a tween line takes, as {local, method, args, modifiers}, or {} when the line is not a
## step of a tween chain this file can prove. `local` is "" for the one-line `create_tween().…` form.
##
## The receiver must either MAKE a tween on the spot or be a local the file declared from one
## (`tween_locals`): a tween reached through a field or a function result cannot prove it is a tween,
## and a Tween sentence over something that is not one would be a confident lie.
static func tween_chain_parts(text: String, context: Dictionary) -> Dictionary:
	# The calls that ARE a step - the row a reader gets one of. Everything else on the line is a
	# setting ON that step (the easing tail) or on the chain around it (the two below).
	const PRIMARY_STEPS: Array[String] = [
		"tween_property", "tween_callback", "tween_interval", "tween_method", "kill"
	]
	## R3. The two calls that say something about the CHAIN rather than about one step of it. Written
	## on their own line they are a row; written in the middle of a one-line chain they are a note on
	## the step that follows, which is why the walk keeps them rather than reading them instead of it.
	const CHAIN_STEPS: Array[String] = ["set_loops", "set_parallel"]
	var body: String = text.strip_edges()
	if not body.ends_with(")"):
		return {}
	var chain: Dictionary = _dotted_chain(body, context)
	if chain.is_empty():
		return {}
	var calls: Array = chain.get("calls", [])
	var local_name: String = str(chain.get("local", ""))
	var loops: String = ""
	var loops_named: bool = false
	var parallel: bool = false
	for call_index: int in calls.size():
		var call: Dictionary = calls[call_index]
		var name: String = str(call.get("name", ""))
		if PRIMARY_STEPS.has(name):
			return {
				"local": local_name,
				"method": name,
				"args": _split_arguments(str(call.get("args", ""))),
				"modifiers": body.substr(int(call.get("end", body.length()))),
				"loops": loops,
				"loops_named": loops_named,
				"parallel": parallel
			}
		if name == "set_loops":
			loops_named = true
			var loop_arguments: PackedStringArray = _split_arguments(str(call.get("args", "")))
			loops = loop_arguments[0] if not loop_arguments.is_empty() else ""
		elif name == "set_parallel":
			parallel = true
	# No step of its own on this line: the chain call IS the row, exactly as it was before one-line
	# chains were walked (`t.set_loops(3)` on its own line reads `Tween repeat 3 times`).
	for call_index: int in calls.size():
		var call: Dictionary = calls[call_index]
		var name: String = str(call.get("name", ""))
		if not CHAIN_STEPS.has(name):
			continue
		return {
			"local": local_name,
			"method": name,
			"args": _split_arguments(str(call.get("args", ""))),
			"modifiers": body.substr(int(call.get("end", body.length())))
		}
	return {}


## R3. One line of dotted calls off a receiver this file can PROVE holds a tween, as
## {"local", "calls": [{name, args, end}]}. `local` is "" for the `create_tween().…` form, which
## makes its tween on the spot. {} when the receiver is not a proven tween or the line is not a
## clean run of `.name(...)` calls - a Tween sentence over something that is not one would be a
## confident lie, and half a parse is not a fact either.
static func _dotted_chain(body: String, context: Dictionary) -> Dictionary:
	var index: int = -1
	var local_name: String = ""
	for maker: String in TWEEN_MAKERS:
		if body.begins_with(maker + "."):
			index = maker.length()
			break
	if index < 0:
		var dot_at: int = body.find(".")
		if dot_at <= 0:
			return {}
		var head: String = body.substr(0, dot_at)
		if not is_tween_local(head, context):
			return {}
		local_name = head
		index = dot_at
	var calls: Array = []
	while index < body.length():
		# A statement written across lines with a trailing `\` joins with a SPACE before the next
		# call, so the walk steps over whitespace between the links of the chain.
		while index < body.length() and (body[index] == " " or body[index] == "\t"):
			index += 1
		if index >= body.length():
			break
		if body[index] != ".":
			return {}
		var open_at: int = body.find("(", index)
		if open_at < 0:
			return {}
		var name: String = body.substr(index + 1, open_at - index - 1)
		if not is_identifier(name):
			return {}
		var close_at: int = closing_paren(body, open_at)
		if close_at < 0:
			return {}
		calls.append({
			"name": name,
			"args": body.substr(open_at + 1, close_at - open_at - 1),
			"end": close_at + 1
		})
		index = close_at + 1
	if calls.is_empty():
		return {}
	return {"local": local_name, "calls": calls}


## R3. True when `name` is a local this file declared from `create_tween()`. The pre-pass that
## collected them hands the set in on the context; without it nothing is claimed.
static func is_tween_local(name: String, context: Dictionary) -> bool:
	var locals: Variant = context.get("tween_locals", {})
	if not (locals is Dictionary):
		return false
	return (locals as Dictionary).has(name.strip_edges())


## R3. `ease = Sine out` from the `.set_trans(...).set_ease(...)` tail a tween step wears, "" when the
## tail names neither. Only the constants the table knows are read: an easing computed at runtime is
## not a fact a chip may state.
static func tween_easing_words(modifiers: String) -> String:
	var curve: String = str(TWEEN_TRANSITION_WORDS.get(_tween_modifier_argument(modifiers, "set_trans"), ""))
	var end_word: String = str(TWEEN_EASE_WORDS.get(_tween_modifier_argument(modifiers, "set_ease"), ""))
	# Each spelling is its own whole phrase in the catalog rather than a word glued to a word: a
	# translator needs the sentence, and "out" on its own is not one.
	if curve.is_empty() and end_word.is_empty():
		return ""
	if curve.is_empty():
		return translate("ease = %s" % end_word)
	if end_word.is_empty():
		return _fill(translate("ease = {curve}"), {"curve": curve})
	return _fill(translate("ease = {curve} %s" % end_word), {"curve": curve})


## The single argument of `.<name>(...)` inside a chained tail, or "" when the tail has no such call.
static func _tween_modifier_argument(modifiers: String, name: String) -> String:
	var marker: String = ".%s(" % name
	var at: int = modifiers.find(marker)
	if at < 0:
		return ""
	var open_at: int = at + marker.length() - 1
	var close_at: int = closing_paren(modifiers, open_at)
	if close_at < 0:
		return ""
	return modifiers.substr(open_at + 1, close_at - open_at - 1).strip_edges()


## R3. The sheet's word for the property a tween animates - `modulate:a` is opacity, `scale` is size,
## `rotation` is the angle. Anything the table does not name keeps its own spelling.
static func tween_property_word(path: String) -> String:
	var bare: String = path.strip_edges()
	return translate(str(TWEEN_PROPERTY_WORDS[bare])) if TWEEN_PROPERTY_WORDS.has(bare) else bare


## R3. What `tween_callback(queue_free)` DOES, in the words the sheet uses for that step: the callable
## reads as the action it names. A lambda has no name to give, so it reads as the sheet's own word for
## a step written inline.
static func tween_callback_words(callable_text: String, context: Dictionary) -> String:
	var text: String = callable_text.strip_edges()
	if text.begins_with("func("):
		return translate("this step")
	var called: Dictionary = _call_statement("%s()" % text, context) if is_simple_target(text) else {}
	if not called.is_empty():
		var words: String = ""
		for segment: Variant in called.get("segments", []):
			words += str((segment as Dictionary).get("text", ""))
		var trimmed: String = words.strip_edges()
		if not trimmed.is_empty():
			return trimmed
	return text


## R3. `(after the previous)` / `(at the same time)` - where this step sits in its chain, when the
## pre-pass over the file could say so for certain. "" otherwise, and the row claims nothing.
static func tween_sequence_note(text: String, context: Dictionary) -> String:
	var notes: Variant = context.get("tween_notes", {})
	if not (notes is Dictionary):
		return ""
	var note: String = str((notes as Dictionary).get(tween_note_key(text), ""))
	if note == "after":
		return translate("(after the previous)")
	if note == "parallel":
		return translate("(at the same time)")
	return ""


## R3. One statement written across several lines with a trailing `\`, joined back into the one line
## it is. The leading indent of the FIRST line is kept, so the row still sits where the file puts it;
## everything a continuation adds is folded onto the end with a single space.
static func join_continuations(code: String) -> String:
	var lines: PackedStringArray = code.split("\n")
	var joined: String = ""
	for index: int in lines.size():
		var line: String = lines[index]
		if joined.is_empty():
			joined = line.rstrip(" \t")
		else:
			joined += " " + line.strip_edges()
		if not joined.ends_with("\\"):
			# Only a run that is entirely continuations may join; anything else is left as it was.
			return code if index < lines.size() - 1 else joined
		joined = joined.substr(0, joined.length() - 1).rstrip(" \t")
	return joined


## R3. The key a tween step is looked up under in the chain map - the statement with its whitespace
## settled, so the pre-pass over the file and the row being drawn agree on what "the same line" is.
static func tween_note_key(text: String) -> String:
	var settled: String = join_continuations(text) if text.contains("\n") else text
	settled = settled.replace("\t", " ")
	while settled.contains("  "):
		settled = settled.replace("  ", " ")
	return settled.strip_edges()


## R3. "a new tween" for the calls that make one, "" for anything else. A local declared from one of
## these reads `Local object t = a new tween` rather than repeating the GDScript call.
static func tween_expression(text: String) -> String:
	return translate("a new tween") if TWEEN_MAKERS.has(text.strip_edges()) else ""


## R9. The Timer behavior's own words for a Timer NODE. Every event sheet says `Start timer "tag" for
## X seconds (once / regular)` and `Stop timer "tag"`; Godot says the same thing with a child node and
## two method calls, so the node's name is the tag and the object is the script's own object - the
## timer belongs to it, exactly as a behavior does.
##
## {} for anything but a plain `$Node` / `%Node` receiver: a timer held in a variable cannot prove its
## tag, and a reading that guesses one would be a confident lie. Those keep their call reading.
static func _timer_statement(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if call.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	if method != "start" and method != "stop":
		return {}
	var tag: String = timer_tag(str(call.get("target", "")))
	if tag.is_empty():
		return {}
	var object_name: String = script_object(context)
	if method == "stop":
		return _sentence(object_name, "Stop timer {timer}", {"timer": ["\"%s\"" % tag, "value"]})
	var args: PackedStringArray = call.get("args", PackedStringArray())
	var values: Dictionary = {"timer": ["\"%s\"" % tag, "value"]}
	var mode: String = timer_mode_words(tag, context)
	if args.is_empty():
		if mode.is_empty():
			return _sentence(object_name, "Start timer {timer}", values)
		values["mode"] = [mode, "muted"]
		return _sentence(object_name, "Start timer {timer} {mode}", values)
	values["seconds"] = [expression_text(args[0], context), "value"]
	if mode.is_empty():
		return _sentence(object_name, "Start timer {timer} for {seconds} seconds", values)
	values["mode"] = [mode, "muted"]
	return _sentence(object_name, "Start timer {timer} for {seconds} seconds {mode}", values)


## R9. `$Timer.time_left` is the Timer behavior's clock: `Timer.CurrentTime("Timer")`. Claimed only
## when the WHOLE value is that read on a named node, so nothing inside a larger sum is rewritten
## halfway. "" when the value is something else.
static func timer_expression(text: String) -> String:
	var trimmed: String = text.strip_edges()
	if not trimmed.ends_with(".time_left"):
		return ""
	var tag: String = timer_tag(trimmed.substr(0, trimmed.length() - 10))
	if tag.is_empty():
		return ""
	return "Timer.CurrentTime(\"%s\")" % tag


## R9. `$Timer.is_stopped()` asks the Timer behavior's own question. The sheet words it the way a
## reader thinks about a timer - is it running - so the negated spelling, which is what scripts
## actually write, reads positively and the bare one says stopped. "" for anything else.
static func _timer_condition(text: String, context: Dictionary) -> Dictionary:
	var trimmed: String = text.strip_edges()
	var running: bool = trimmed.begins_with("not ")
	if running:
		trimmed = trimmed.substr(4).strip_edges()
	if not trimmed.ends_with(".is_stopped()"):
		return {}
	var tag: String = timer_tag(trimmed.substr(0, trimmed.length() - 13))
	if tag.is_empty():
		return {}
	var object_name: String = script_object(context)
	var values: Dictionary = {"timer": ["\"%s\"" % tag, "value"]}
	if running:
		return _sentence(object_name, "Is timer {timer} running", values)
	return _sentence(object_name, "Is timer {timer} stopped", values)


## R9. The tag a Timer node reads under - its own name. Only a `$Path/To/Timer` or `%Unique` receiver
## answers; "" for everything else, which is what keeps the reading honest.
static func timer_tag(receiver: String) -> String:
	var text: String = receiver.strip_edges()
	if not (text.begins_with("$") or text.begins_with("%")):
		return ""
	var bare: String = text.substr(1).strip_edges().trim_prefix("\"").trim_suffix("\"")
	var last: String = bare.get_file() if bare.contains("/") else bare
	return last if is_identifier(last) else ""


## R9. `(once)` / `(regular)` - which of the Timer behavior's two modes this tag runs in, when the
## file (or the scene) said so. "" when nothing did, and the row simply does not claim a mode.
static func timer_mode_words(tag: String, context: Dictionary) -> String:
	var modes: Variant = context.get("timer_modes", {})
	if not (modes is Dictionary):
		return ""
	if not (modes as Dictionary).has(tag):
		return ""
	return translate("(once)") if bool((modes as Dictionary)[tag]) else translate("(regular)")


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
	# S6. `is_instance_valid(target)` asks exactly what `target != null` asks, only more carefully, so
	# it reads in the same word. One argument only: the call takes no other shape.
	var call: Dictionary = call_parts(text)
	if str(call.get("method", "")) == "is_instance_valid" and str(call.get("target", "")).is_empty():
		var checked: PackedStringArray = call.get("args", PackedStringArray())
		if checked.size() == 1 and is_simple_target(checked[0].strip_edges()):
			return _sentence(object_of_reference(checked[0].strip_edges()), "exists", {})
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
	# S7. `items.has(sword)` asks the same question `sword in items` asks, so it reads the same words -
	# a reader should never have to know that a list answers to two spellings of one question. The
	# receiver must be a plain name of this file: `get_tree().has(x)` is not a list.
	var call: Dictionary = call_parts(text)
	if str(call.get("method", "")) == "has":
		var holder: String = str(call.get("target", "")).strip_edges()
		var wanted: PackedStringArray = call.get("args", PackedStringArray())
		if is_identifier(holder) and wanted.size() == 1 and not is_engine_property(holder, context):
			if LIST_TYPES.has(_declared_type_of(holder, context)):
				return _sentence(OBJECT_SYSTEM, "{list} contains {value}", {
					"list": [holder, "name"],
					"value": [expression_text(wanted[0], context), "value"]
				})
			return _sentence(OBJECT_SYSTEM, "{table} has key {key}", {
				"table": [holder, "name"],
				"key": [expression_text(wanted[0], context), "value"]
			})
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
	# S5. `cfg.load("user://save.cfg") != OK` is how a Godot script asks whether there is a save file
	# to read, and that IS the question - the error code is Godot's way of answering it, not something
	# the row has to say. Both directions read, each in its own words, so neither needs a mark to
	# decode.
	for pair: Array in [[" != ", "save file is missing"], [" == ", "save file exists"]]:
		var operator: String = str(pair[0])
		var at: int = top_level_index(text, operator)
		if at <= 0 or text.substr(at + operator.length()).strip_edges() != "OK":
			continue
		var loaded: Dictionary = call_parts(text.substr(0, at).strip_edges())
		if str(loaded.get("method", "")) != "load":
			continue
		var loaded_args: PackedStringArray = loaded.get("args", PackedStringArray())
		if loaded_args.size() != 1 or not _is_config_path(loaded_args[0]):
			continue
		var asked: Dictionary = _sentence(OBJECT_STORAGE, str(pair[1]), {})
		(asked["segments"] as Array).append(
			{"text": " (%s)" % file_name_value(loaded_args[0], context), "tone": "muted"})
		return asked
	var call: Dictionary = call_parts(text)
	if call.is_empty():
		return {}
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	if str(call.get("method", "")) == "has_section_key" and arguments.size() == 2:
		# S5. Addressed as the one item it is, exactly as Set item and Item() address it.
		var addressed: String = storage_item_key(arguments[0], arguments[1])
		if not addressed.is_empty():
			return _sentence(OBJECT_STORAGE, "has item {key}", {"key": [addressed, "name"]})
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
## R10 renamed the ceiling: an event sheet says TOUCHING a ceiling, which is what a head bump is.
const BODY_STATE_WORDS: Dictionary = {
	"is_on_floor": "Is on floor",
	"is_on_wall": "Is by wall",
	"is_on_ceiling": "Is touching ceiling"
}


static func _body_state_condition(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if call.is_empty() or not (call.get("args", PackedStringArray()) as PackedStringArray).is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	if not BODY_STATE_WORDS.has(method):
		return {}
	var object_name: String = _receiver_object(str(call.get("target", "")), context)
	# R10. The platform words belong to a BODY. A known engine class that is not one keeps the plain
	# reading; an unknown class (a `class_name` of the project's own) still gets the words, because
	# these three questions exist nowhere else in Godot.
	var body_class: String = object_class_of(object_name, context)
	if ClassDB.class_exists(body_class) and not _class_is_any(body_class, CHARACTER_BODY_CLASSES):
		return {}
	return _sentence(object_name, str(BODY_STATE_WORDS[method]), {})


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


## M41/R10. `velocity.y < 0` is the event-sheet "Is jumping" and `velocity.x != 0` its "Is moving" -
## but only on a BODY. A projectile's vertical speed is not a jump, so a known class that is not a
## CharacterBody keeps the comparison it wrote.
##
## The words follow the AXIS, never the sign: in 2D Y grows downward, so a negative vertical speed is
## going up, and in 3D the very same test means falling.
static func _movement_condition(text: String, context: Dictionary) -> Dictionary:
	for operator: String in [" != ", " < ", " > "]:
		var at: int = top_level_index(text, operator)
		if at < 0:
			continue
		if text.substr(at + operator.length()).strip_edges() != "0":
			return {}
		var subject: String = text.substr(0, at).strip_edges().trim_prefix("self.")
		var member: String = ""
		for candidate: String in ["velocity.y", "velocity.x"]:
			if subject.ends_with(candidate):
				member = candidate
		if member.is_empty():
			return {}
		var owner_name: String = subject.substr(0, maxi(subject.length() - member.length() - 1, 0))
		var object_name: String = _receiver_object(owner_name, context)
		var body_class: String = object_class_of(object_name, context)
		if not _class_is_any(body_class, CHARACTER_BODY_CLASSES):
			return {}
		if member == "velocity.x":
			return _sentence(object_name, "Is moving", {}) if operator == " != " else {}
		if operator == " != ":
			return {}
		var y_grows_up: bool = _class_is_any(body_class, PackedStringArray(["CharacterBody3D"]))
		var going_up: bool = (operator == " > ") if y_grows_up else (operator == " < ")
		return _sentence(object_name, "Is jumping" if going_up else "Is falling", {})
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
	# R24 - the exact-match spelling carries a second argument, so it is claimed before the one-argument
	# reads below ever see it.
	var controls: Dictionary = controls_condition(text)
	if not controls.is_empty():
		return controls
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
static func _rewrite_calls(text: String, context: Dictionary = {}) -> String:
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
		var inner: String = _rewrite_calls(text.substr(index + 1, close_at - index - 1), context)
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
		var replacement: String = _idiom_for(head, arguments, context)
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
static func _idiom_for(head: String, arguments: PackedStringArray, context: Dictionary = {}) -> String:
	if head.is_empty():
		return ""
	# R7. Under the Familiar Words glossary the length question is already answered - `len(x)` is the
	# sheet's own name for it, written by the pass above - and the count spelling would undo it.
	if head == "len" and arguments.size() == 1 and bool(context.get("familiar_words", false)):
		return "len(%s)" % arguments[0]
	# T11. `tr("HELLO")` is not a call a reader thinks about: the text is TRANSLATED, which is the
	# word the sheet's own translation rows already use for it.
	if (head == "tr" or head == "atr") and arguments.size() == 1:
		return "%s %s" % [translate("translated"), arguments[0]]
	if VECTOR_CONSTRUCTORS.has(head):
		return "(%s)" % ", ".join(arguments)
	# U1 - a colour built from its channels reads as the colour, with the alpha as opacity.
	if head == "Color":
		return colour_constructor_words(arguments)
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
	if _leading_word_regex == null:
		_leading_word_regex = RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*")
	var found: RegExMatch = _leading_word_regex.search(text)
	return found.get_string(0) if found != null else ""


## True when `text` is a plain identifier - the only thing a declaration row may name.
static func is_identifier(text: String) -> bool:
	if _identifier_regex == null:
		_identifier_regex = RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*$")
	return _identifier_regex.search(text) != null


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
	# R40. Under Familiar Words a GLOBAL drops its autoload's name: `System ▸ Set Score to 10`, not
	# `Game ▸ Set Score to 10`. In the sheet a global is just a value the whole project shares, and
	# System is the object the sheet already files shared things under; which autoload happens to hold
	# it is a Godot fact, not a reading. With Familiar Words off it stays `Game ▸ …`, because that is
	# the honest spelling of what the line actually says.
	var familiar_global: String = familiar_global_object(object_name, context)
	if not familiar_global.is_empty():
		return [familiar_global, _member_word(text.substr(dot_at + 1))]
	# M47. `$Enemies/Boss` is the object `Boss` - the name a reader sees in the scene tree.
	return [object_of_reference(object_name), _member_word(text.substr(dot_at + 1))]


## R40. OBJECT_SYSTEM when `object_name` is one of the project's autoloads AND Familiar Words is on,
## "" otherwise - the one question the prefix-free global reading asks, kept in its own function so
## the rule is in a single place and reads as one sentence.
##
## The autoload list is cached because this is asked once per row of every sheet, and ProjectSettings
## does not change on its own; the editor clears the cache (clear_autoload_cache) when it registers a
## new one, which is the only moment inside a session that it can go stale.
static func familiar_global_object(object_name: String, context: Dictionary) -> String:
	if not bool(context.get("familiar_words", false)):
		return ""
	return OBJECT_SYSTEM if _autoload_names().has(object_name) else ""


## Forgets the cached autoload list. Called when the editor registers a new autoload, so a global
## added a moment ago reads as a global straight away.
static func clear_autoload_cache() -> void:
	_cached_autoload_names = {}
	_autoload_cache_filled = false


static var _cached_autoload_names: Dictionary = {}
static var _autoload_cache_filled: bool = false


static func _autoload_names() -> Dictionary:
	if _autoload_cache_filled:
		return _cached_autoload_names
	_autoload_cache_filled = true
	_cached_autoload_names = {}
	for property_info: Dictionary in ProjectSettings.get_property_list():
		var setting: String = str(property_info.get("name", ""))
		if not setting.begins_with("autoload/"):
			continue
		var singleton: String = setting.trim_prefix("autoload/").strip_edges()
		if not singleton.is_empty():
			_cached_autoload_names[singleton] = true
	return _cached_autoload_names


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
	# R3. A tween is an object a reader may call Tween steps on, so the local holding one says so.
	if TWEEN_MAKERS.has(text):
		return "Object"
	# ── V4 / V5 ─────────────────────────────────────────────────────────────────────────────────
	# A picture, a rendered viewport, and a data asset the line itself named the type of. All three
	# are declarations whose type is written plainly in the value, which is the whole test here.
	if SCREENSHOT_EXPRESSIONS.has(text):
		return "Image"
	if text.ends_with(".get_texture()"):
		return "Texture2D"
	var as_at: int = top_level_index(text, " as ")
	if as_at > 0 and not data_asset_expression(text).is_empty():
		var cast: String = text.substr(as_at + 4).strip_edges()
		if is_identifier(cast):
			return cast
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


## S7. The two parameters and the body of a ONE-LINE lambda, as [first, second, body], or [] for
## anything else. A lambda written over two lines keeps its Script block: a sentence may only stand
## for a shape it can see whole.
static func one_line_lambda(text: String) -> Array:
	var body: String = text.strip_edges()
	if not body.begins_with("func(") or body.contains("\n"):
		return []
	var close_at: int = closing_paren(body, 4)
	if close_at < 0:
		return []
	var names: PackedStringArray = split_top_level(body.substr(5, close_at - 5), ", ")
	if names.size() != 2 or not is_identifier(names[0]) or not is_identifier(names[1]):
		return []
	var rest: String = body.substr(close_at + 1).strip_edges()
	if not rest.begins_with(":"):
		return []
	rest = rest.substr(1).strip_edges()
	if not rest.begins_with("return "):
		return []
	return [names[0], names[1], rest.substr(7).strip_edges()]


## S7. The member a one-line `reduce` adds up - `func(acc, i): return acc + i.price` totals `price`.
## Either order of the sum is read, because both are written. "" when the body adds anything else.
static func _summed_member(text: String) -> String:
	var parts: Array = one_line_lambda(text)
	if parts.is_empty():
		return ""
	var running: String = str(parts[0])
	var item: String = str(parts[1])
	var body: String = str(parts[2])
	var plus_at: int = top_level_index(body, " + ")
	if plus_at <= 0:
		return ""
	var left: String = body.substr(0, plus_at).strip_edges()
	var right: String = body.substr(plus_at + 3).strip_edges()
	var member: String = ""
	if left == running:
		member = right
	elif right == running:
		member = left
	else:
		return ""
	var prefix: String = "%s." % item
	if not member.begins_with(prefix):
		return ""
	var name_text: String = member.substr(prefix.length())
	return name_text if is_identifier(name_text) else ""


## S7. What a one-line `sort_custom` sorts by, as {member, lowest} - `func(a, b): return a.price <
## b.price` sorts by `price`, lowest first. {} when the two sides do not compare the SAME member of
## the two items, which is the only shape that can honestly be read as "sort by".
static func sorted_member(text: String) -> Dictionary:
	var parts: Array = one_line_lambda(text)
	if parts.is_empty():
		return {}
	var first: String = str(parts[0])
	var second: String = str(parts[1])
	var body: String = str(parts[2])
	for operator: String in [" < ", " > "]:
		var at: int = top_level_index(body, operator)
		if at <= 0:
			continue
		var left: String = body.substr(0, at).strip_edges()
		var right: String = body.substr(at + operator.length()).strip_edges()
		var member: String = _member_of(left, first)
		if member.is_empty() or member != _member_of(right, second):
			return {}
		return {"member": member, "lowest": operator == " < "}
	return {}


## `a.price` read against the item name `a` -> `price`; anything else -> "".
static func _member_of(text: String, item: String) -> String:
	var prefix: String = "%s." % item
	if not text.begins_with(prefix):
		return ""
	var name_text: String = text.substr(prefix.length())
	return name_text if is_identifier(name_text) else ""


## How many `{N}` argument slots a pattern names, so an idiom can never quietly drop an argument.
static func _slot_count(pattern: String) -> int:
	var found: int = 0
	while pattern.contains("{%d}" % found):
		found += 1
	return found


## N6/N7. The receiver idioms whose reading is decided by the argument list.
static func _shaped_receiver_idiom(receiver: String, method: String,
		arguments: PackedStringArray) -> String:
	# U1 - the vector and colour operations, ahead of the general tables: `normalized` and `length`
	# both have entries there, and the words below are the ones a reader was promised.
	var vector_colour: String = vector_colour_receiver_words(receiver, method, arguments)
	if not vector_colour.is_empty():
		return vector_colour
	# U4 / U5 - making a value and looking a node up, ahead of the `get_thing()` property rule below,
	# which would otherwise read `enemy.get_path()` as the bare member `path`.
	var data_scene: String = data_scene_receiver_words(receiver, method, arguments)
	if not data_scene.is_empty():
		return data_scene
	if method == "substr" and arguments.size() == 2:
		if arguments[0].strip_edges() == "0":
			return "left(%s, %s)" % [receiver, arguments[1]]
		return "mid(%s, %s, %s)" % [receiver, arguments[0], arguments[1]]
	# `cfg.get_value(section, key)` is the read-an-item-from-storage expression; the section is a
	# GDScript filing detail the Storage object already implies, so only the KEY is in the sentence.
	# S5. Addressed as one item when the section and the key are both literals, the way the Set item row
	# above addresses it, so the write and the read of one saved value name the same thing.
	if method == "get_value" and arguments.size() >= 2 and arguments.size() <= 3:
		var addressed: String = storage_item_key(arguments[0], arguments[1])
		var item_name: String = "\"%s\"" % addressed if not addressed.is_empty() else arguments[1]
		var read_back: String = _fill(translate("{object}.Item({key})"),
			{"object": translate(OBJECT_STORAGE), "key": item_name})
		if arguments.size() == 2:
			return read_back
		return "%s (%s)" % [read_back, _fill(translate("or {fallback}"), {"fallback": arguments[2]})]
	# ── S7 ──────────────────────────────────────────────────────────────────────────────────────
	# The three list and table READS an event sheet has words for and a Godot script writes as calls.
	# `stats.get("hp", 100)` is the table entry with what to use when it is missing; `items.slice(0, 3)`
	# is the first few of a list; a one-line `reduce` that adds one member up is a total. Each is
	# claimed only in the exact shape shown, so anything richer keeps its own code.
	if method == "get" and arguments.size() == 2:
		return _fill(translate("{table} {key} (or {fallback} when missing)"),
			{"table": receiver, "key": arguments[0], "fallback": arguments[1]})
	if method == "slice" and arguments.size() == 2 and arguments[0].strip_edges() == "0":
		return _fill(translate("the first {count} of {list}"),
			{"count": arguments[1], "list": receiver})
	if method == "reduce" and arguments.size() == 2 and arguments[1].strip_edges() in ["0", "0.0"]:
		var summed: String = _summed_member(arguments[0])
		if not summed.is_empty():
			return _fill(translate("the sum of {member} over {list}"),
				{"member": summed, "list": receiver})
	# R30. `position.snapped(Vector2(8, 8))` is the grid a value is pulled onto, and a grid reads as
	# its numbers: `position snapped to 8, 8`. The same words the free-function spelling
	# `snapped(x, 8)` already reads, so the two never disagree. The vector prettifier has turned the
	# argument into `(8, 8)` by the time this is asked, and the brackets only ever held it.
	if method in ["snapped", "snappedf", "snappedi"] and arguments.size() == 1:
		return "%s snapped to %s" % [receiver, _unwrapped_group(arguments[0])]
	# ── S16 ─────────────────────────────────────────────────────────────────────────────────────
	# Reading a shader parameter is asking an object about one of its effect parameters, so the
	# material slot comes off the front the same way it does on the write.
	if method == "get_shader_parameter" and arguments.size() == 1:
		var wearer: String = receiver
		for slot: String in EFFECT_SLOTS:
			if wearer.ends_with(".%s" % slot):
				wearer = wearer.substr(0, wearer.length() - slot.length() - 1)
				break
		return _fill(translate("{object}'s effect parameter {name}"),
			{"object": wearer, "name": arguments[0]})
	# ── S17 ─────────────────────────────────────────────────────────────────────────────────────
	# The three tilemap questions, under the names the sheet's own tilemap expressions carry. The
	# older node spelling names its layer first; the answer is about the CELL either way.
	if TILEMAP_EXPRESSION_WORDS.has(method) and arguments.size() >= 1 and arguments.size() <= 2:
		return "%s.%s(%s)" % [receiver, str(TILEMAP_EXPRESSION_WORDS[method]),
			arguments[arguments.size() - 1]]
	return ""


## One pair of brackets that wraps the WHOLE text, taken off - `(8, 8)` is `8, 8`. Anything else is
## returned as it came, including `(a) + (b)`, where the leading bracket closes long before the end.
static func _unwrapped_group(text: String) -> String:
	var body: String = text.strip_edges()
	if not (body.begins_with("(") and body.ends_with(")")):
		return body
	return body.substr(1, body.length() - 2).strip_edges() if closing_paren(body, 0) == body.length() - 1 else body


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


# ── R24-R29 - the controls block: analog, gamepads by number, sensors ────────────────────────────
#
# Everything here reads a value or a check the Gamepad and Touch objects already have a sentence for.
# The rest of the input vocabulary (rebinding, simulated input, the pointer, the gesture branches)
# reads through its own ACEs, whose templates are the exact bytes hand-written Godot writes - so the
# importer lifts them and the row shows the sentence without a word of grammar here.
#
# Kept in one block, with its own tables, so it can be read and changed as one thing.


## A value expression in the controls vocabulary, "" when it is not one. Whole-expression shapes only:
## a fragment of a bigger sum is rewritten by the ordinary call pass, which already leaves what it
## does not recognise alone.
static func controls_expression(text: String) -> String:
	var trimmed: String = text.strip_edges()
	if CONTROLS_SENSOR_WORDS.has(trimmed):
		return translate(str(CONTROLS_SENSOR_WORDS[trimmed]))
	if CONTROLS_GAMEPAD_WORDS.has(trimmed):
		return translate(str(CONTROLS_GAMEPAD_WORDS[trimmed]))
	var call: Dictionary = call_parts(trimmed)
	if call.is_empty() or str(call.get("target", "")) != "Input":
		return ""
	var method: String = str(call.get("method", ""))
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	# The stick read, in the Gamepad object's own words for the axis and with the device read as the
	# gamepad number the sheet counts from 0.
	if method == "get_joy_axis" and arguments.size() == 2:
		var axis_words: String = controls_axis_words(arguments[1])
		if axis_words.is_empty():
			return ""
		return _fill(translate("axis {axis} of gamepad {device}"),
			{"axis": axis_words, "device": arguments[0].strip_edges()})
	if method == "get_joy_name" and arguments.size() == 1:
		return _fill(translate("name of gamepad {device}"), {"device": arguments[0].strip_edges()})
	if method == "is_joy_known" and arguments.size() == 1:
		return _fill(translate("gamepad {device} is recognized"), {"device": arguments[0].strip_edges()})
	return ""


## The Gamepad object's word for an axis constant, "" when the line names something computed (which
## has no word to print).
static func controls_axis_words(constant: String) -> String:
	var bare: String = constant.strip_edges()
	return str(CONTROLS_AXIS_WORDS.get(bare, "")) if CONTROLS_AXIS_WORDS.has(bare) else ""


## The controls conditions the ordinary input reading does not claim. Today that is the exact-match
## spelling: `Input.is_action_pressed("accelerate", true)` carries a second argument the input path
## refuses, and the bare `true` is the one flag in this vocabulary that means nothing to a reader
## until it is spelled out.
static func controls_condition(text: String) -> Dictionary:
	var call: Dictionary = call_parts(text.strip_edges())
	if call.is_empty() or str(call.get("target", "")) != "Input":
		return {}
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	if str(call.get("method", "")) != "is_action_pressed" or arguments.size() != 2:
		return {}
	if arguments[1].strip_edges() != "true":
		return {}
	var shown: String = strip_action_name(arguments[0])
	if shown.is_empty():
		return {}
	return _sentence(OBJECT_GAMEPAD, "Is button down {action} (exact match)",
		{"action": [shown, "value"]})


# ── R4 / R5 / R7 / R10 / R11 - the reading words batch seven added ──────────────
#
# Seven readings that share one rule with every batch before them: the FILE never moves. Each
# function below answers with words for values the row already holds, so the byte round-trip and the
# emitted GDScript are the same before and after. Kept in one block, apart from the shapes above,
# because each is a QUESTION spanning more than the one operator a general comparison reading would
# stop at.
#
#   R4  ranges     x >= 0 and x <= width                     x is between 0 and width
#       angles     abs(angle_difference(a, b)) < deg_to_rad(10)  a is within 10° of b
#       distance   position.distance_to(t) < 100             is within 100 of t
#       areas      Rect2(0, 0, 640, 360).has_point(position) is inside area 0, 0 - 640 × 360
#       about      is_equal_approx(speed, 0.0)               speed is about 0
#   R5  elapsed    Time.get_ticks_msec() - t > 500           0.5 seconds have passed since t
#               and its write            t = Time.get_ticks_msec()   Set t to now
#   R7  names      the sheet's own expression names, under Familiar Words only
#   R11 bounds     position.x < 0 or position.x > <width>    Is outside layout (left or right)


## R10. The classes the platform words belong to. A projectile's `velocity.y < 0` is not "jumping",
## and a plain Node2D has no floor to stand on.
const CHARACTER_BODY_CLASSES: PackedStringArray = ["CharacterBody2D", "CharacterBody3D"]

## R4. The comparisons a range is built out of, longest spelling first so `>=` is never read as `>`.
const RANGE_OPERATORS: PackedStringArray = [" >= ", " <= ", " > ", " < "]

## R5. The two clocks a script reads "now" from, and whether the number they hand back is in
## milliseconds. Both read as the same sentence; the wall clock says so, because it survives a
## restart and the run clock does not.
const CLOCK_CALLS: Dictionary = {
	"Time.get_ticks_msec()": true,
	"Time.get_unix_time_from_system()": false
}

## R11. The two spellings of "the rectangle the player can see", so an edge test reads the same
## whichever one the script happens to use.
const VIEWPORT_RECTS: PackedStringArray = [
	"get_viewport_rect()", "get_viewport().get_visible_rect()", "get_window().get_visible_rect()"
]


## R4 / R11. The readings that span a WHOLE run of terms - a range is two comparisons joined by
## `and`, an off-screen test is two edges joined by `or` - claimed before the run is ever split into
## conjuncts. {} when the expression is not one of them, which is the caller's cue to carry on.
static func joined_condition(text: String, context: Dictionary) -> Dictionary:
	var bare: String = stripped_parens(text)
	# S17. The tile-data question is a guard AND the question it guards, so it is claimed before the
	# run is split - after the split the guard would read as "data exists" beside it.
	var tile: Dictionary = _tile_data_condition(bare, context)
	if not tile.is_empty():
		return tile
	# The angle window first: both of its terms wrap the SAME value, which the plain range reading
	# would happily claim and then print the wrapping arithmetic as the thing being asked about.
	var angles: Dictionary = _between_angles_condition(bare, context)
	if not angles.is_empty():
		return angles
	var between: Dictionary = _between_condition(bare, context)
	if not between.is_empty():
		return between
	# X21 / X26. Two questions written as a run of terms that mean nothing apart: a roll that is
	# either won or guaranteed, and a health threshold guarded by the phase the fight is in. Claimed
	# before the run is split, because after the split each half reads as a true and useless fact.
	var pity: Dictionary = _pity_condition(bare, context)
	if not pity.is_empty():
		return pity
	var phase: Dictionary = _boss_phase_condition(bare, context)
	if not phase.is_empty():
		return phase
	return _layout_bounds_condition(bare, context)


## X21. The object a pity roll belongs to: the randomness pack, whose seeded generator makes the
## same run of rolls replay identically - which is the whole reason a pity system can be tested.
const PITY_OBJECT := "AdvancedRandom"


## X21. The pity roll's own question. Which conditions are one is a whole-file question - a counter
## fed per roll, a chance grown out of it, this roll-or-cap test and a reset on the win - answered
## once per rebuild and handed in as `pity_rolls`; with no such fact nothing here fires and the
## `or` run keeps the two comparisons it reads as today.
##
##   if pity >= pity_cap or randf() < chance:
##       AdvancedRandom ▸ Rolled with pity (chance, guaranteed at pity cap)
static func _pity_condition(text: String, context: Dictionary) -> Dictionary:
	var rolls: Dictionary = context.get("pity_rolls", {})
	if rolls.is_empty() or not rolls.has(text):
		return {}
	var roll: Dictionary = rolls[text]
	var reading: Dictionary = _sentence(PITY_OBJECT, "Rolled with pity", {})
	(reading["segments"] as Array).append({
		"text": " (%s, %s %s)" % [_member_word(str(roll.get("chance", ""))),
			translate("guaranteed at"), _member_word(str(roll.get("cap", "")))],
		"tone": "muted"
	})
	reading["pattern"] = "pity"
	return reading


## X27. The m:ss a mission clock is SHOWN as. Dividing by sixty, taking the remainder and joining the
## two with a colon is one idea with a name every player knows, and spelling the arithmetic out tells
## a reader how it is done rather than what it says. "" for any other expression, and for every
## expression at all in a file that runs no mission clock.
static func minutes_seconds_expression(text: String, context: Dictionary) -> String:
	var timers: Dictionary = context.get("mission_timers", {})
	if timers.is_empty():
		return ""
	for name_text: String in timers:
		if not EventSheetPatternReadings.is_minutes_seconds(text, name_text):
			continue
		return "%s %s" % [_member_word(name_text), translate("as minutes:seconds")]
	return ""


## X26. The phase ladder's own question. `phase == 1 and hp <= max_hp * 0.6` is one idea - phase 2
## starts here, and it starts once - and the guard IS the once, which is why the row says so instead
## of showing the bookkeeping. Which conditions are one is answered from the whole file and handed in
## as `boss_phase_steps`; with no such fact nothing here fires.
static func _boss_phase_condition(text: String, context: Dictionary) -> Dictionary:
	var steps: Dictionary = context.get("boss_phase_steps", {})
	if steps.is_empty() or not steps.has(text):
		return {}
	var step: Dictionary = steps[text]
	var reading: Dictionary = _sentence(script_object(context), "Phase {phase} starts",
		{"phase": [str(step.get("into", "")), "value"]})
	var percent: String = str(step.get("percent", ""))
	var limit: String = "%s%%" % percent if not percent.is_empty() else str(step.get("threshold", ""))
	(reading["segments"] as Array).append({
		"text": " (%s ≤ %s, %s)" % [_member_word(str(step.get("subject", "hp"))), limit,
			translate("once")],
		"tone": "muted"
	})
	reading["pattern"] = "boss_phases"
	return reading


## R4 / R5 / R11. The readings a SINGLE term settles: an angle window, a distance, an area, an
## approximate equality, an elapsed-time check and the on-screen question.
static func single_condition(text: String, context: Dictionary) -> Dictionary:
	var bare: String = stripped_parens(text)
	var within_angle: Dictionary = _within_angle_condition(bare, context)
	if not within_angle.is_empty():
		return within_angle
	var clockwise: Dictionary = _clockwise_condition(bare, context)
	if not clockwise.is_empty():
		return clockwise
	var distance: Dictionary = _within_distance_condition(bare, context)
	if not distance.is_empty():
		return distance
	var area: Dictionary = _inside_area_condition(bare, context)
	if not area.is_empty():
		return area
	var about: Dictionary = _about_condition(bare, context)
	if not about.is_empty():
		return about
	var elapsed: Dictionary = _elapsed_condition(bare, context)
	if not elapsed.is_empty():
		return elapsed
	return _on_screen_condition(bare, context)


## An expression with the brackets that only wrap the WHOLE of it removed.
static func stripped_parens(text: String) -> String:
	var out: String = text.strip_edges()
	while out.begins_with("(") and closing_paren(out, 0) == out.length() - 1:
		out = out.substr(1, out.length() - 2).strip_edges()
	return out


## ONE comparison as [left, operator, right] - the operator without its spaces - or [] when the text
## is not exactly one. Only the four ordering operators are claimed: `==` and `!=` are questions the
## readings above already answer.
static func _comparison_parts(text: String) -> Array:
	for operator: String in RANGE_OPERATORS:
		var at: int = top_level_index(text, operator)
		if at <= 0:
			continue
		var left: String = text.substr(0, at).strip_edges()
		var right: String = text.substr(at + operator.length()).strip_edges()
		if left.is_empty() or right.is_empty():
			return []
		return [left, operator.strip_edges(), right]
	return []


## R4. The object, the word and the tone a SUBJECT reads under. An engine property or a member chain
## belongs to the object that owns it and reads as a name; a variable the sheet declares belongs to
## the script's own object; anything else is a value, and the row files under System the way the
## sheet's own Compare row does.
static func _subject_words(subject: String, context: Dictionary) -> Array:
	var text: String = subject.strip_edges().trim_prefix("self.")
	if not is_simple_target(text):
		return [OBJECT_SYSTEM, expression_text(text, context), "value"]
	var head: String = text.split(".", false)[0] if text.contains(".") else text
	if is_engine_property(head, context) or text.contains("."):
		var split: Array = _split_object(text, context)
		return [str(split[0]), str(split[1]), "name"]
	var declared: Dictionary = context.get("variable_types", {})
	if declared.has(text):
		return [str(context.get("self_object", OBJECT_SYSTEM)), text, "name"]
	return [OBJECT_SYSTEM, text, "value"]


## R4. The event-sheet Is Between Values condition, in all four spellings a script writes it: both
## operand orders, strict or not, and the `in range(a, b)` form whose top bound is one less than the
## number written. The note says which end is exclusive, because a range that quietly drops its top
## value is the oldest off-by-one in games.
static func _between_condition(text: String, context: Dictionary) -> Dictionary:
	var counted: Dictionary = _range_membership(text, context)
	if not counted.is_empty():
		return counted
	if top_level_index(text, " or ") >= 0 or top_level_index(text, " and ") < 0:
		return {}
	var parts: PackedStringArray = split_top_level(text, " and ")
	if parts.size() != 2:
		return {}
	var first: Array = _comparison_parts(stripped_parens(parts[0]))
	var second: Array = _comparison_parts(stripped_parens(parts[1]))
	if first.is_empty() or second.is_empty():
		return {}
	var subject: String = _shared_subject(first, second)
	if subject.is_empty():
		return {}
	var lower: Array = _bound_of(first, subject, true)
	var upper: Array = _bound_of(second, subject, false)
	if lower.is_empty() or upper.is_empty():
		# The two terms may be written the other way round: `x <= width and x >= 0` asks the same thing.
		lower = _bound_of(second, subject, true)
		upper = _bound_of(first, subject, false)
	if lower.is_empty() or upper.is_empty():
		return {}
	return _range_sentence(subject, str(lower[0]), str(upper[0]), bool(lower[1]), bool(upper[1]), context)


## R4. `level in range(3, 6)` is a range whose top is 5: Godot's range STOPS before its second
## number, and a reading that showed 6 would name a value the branch never accepts.
static func _range_membership(text: String, context: Dictionary) -> Dictionary:
	var at: int = top_level_index(text, " in ")
	if at <= 0:
		return {}
	var subject: String = text.substr(0, at).strip_edges()
	var call: Dictionary = call_parts(text.substr(at + 4).strip_edges())
	if call.is_empty() or str(call.get("method", "")) != "range":
		return {}
	if not str(call.get("target", "")).is_empty():
		return {}
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	if arguments.size() != 2 or subject.is_empty():
		return {}
	return _range_sentence(subject, arguments[0].strip_edges(), _one_less(arguments[1]), false, false, context)


## The number one below a bound: the literal itself when the file wrote one, and the arithmetic
## otherwise, so the reading never invents a value the code does not hold.
static func _one_less(value: String) -> String:
	var text: String = value.strip_edges()
	if text.is_valid_int():
		return str(text.to_int() - 1)
	return "%s - 1" % text


## R4. The value BOTH terms of a range ask about. Compared as written: a range is two questions about
## one name, and two different spellings of the same value are two different questions to a reader.
static func _shared_subject(first: Array, second: Array) -> String:
	for candidate: String in [str(first[0]), str(first[2])]:
		if candidate == str(second[0]) or candidate == str(second[2]):
			return candidate
	return ""


## R4. One term of a range as [bound, strict], or [] when it is not the end asked for. A term with
## the subject on the RIGHT asks the same question with the operator flipped (`0 < hp` IS `hp > 0`).
static func _bound_of(parts: Array, subject: String, lower_end: bool) -> Array:
	var operator: String = str(parts[1])
	var bound: String = ""
	if str(parts[0]) == subject:
		bound = str(parts[2])
	elif str(parts[2]) == subject:
		bound = str(parts[0])
		operator = {">": "<", ">=": "<=", "<": ">", "<=": ">="}.get(operator, "")
	else:
		return []
	var asks_lower: bool = operator == ">" or operator == ">="
	if asks_lower != lower_end:
		return []
	return [bound, operator == ">" or operator == "<"]


## R4. The finished Is Between reading, with the note that says which end the branch leaves out.
static func _range_sentence(subject: String, low: String, high: String, strict_low: bool,
		strict_high: bool, context: Dictionary) -> Dictionary:
	var words: Array = _subject_words(subject, context)
	var reading: Dictionary = _sentence(str(words[0]), "{value} is between {low} and {high}", {
		"value": [str(words[1]), str(words[2])],
		"low": [expression_text(low, context), "value"],
		"high": [expression_text(high, context), "value"]
	})
	var note: String = _range_note(strict_low, strict_high)
	if not note.is_empty():
		(reading["segments"] as Array).append({"text": " %s" % note, "tone": "plain"})
	return reading


## R4. Which end of a range the branch does not accept, in the sheet's words. "" when both ends count,
## which is the shape most rows are and the one that needs no note at all.
static func _range_note(strict_low: bool, strict_high: bool) -> String:
	if strict_low and strict_high:
		return translate("(exclusive)")
	if strict_high:
		return translate("(exclusive top)")
	if strict_low:
		return translate("(exclusive bottom)")
	return ""


## R4. An angle as the DEGREES a reader thinks in. `deg_to_rad(10)` is exactly ten degrees, and a
## bare radian literal is converted; the radians the file holds stay one hover away on the row.
## "" when the value is neither, which refuses the whole angle reading rather than guess at it.
static func _angle_degrees(value: String) -> String:
	var text: String = value.strip_edges()
	var call: Dictionary = call_parts(text)
	if not call.is_empty() and str(call.get("method", "")) == "deg_to_rad":
		var arguments: PackedStringArray = call.get("args", PackedStringArray())
		if arguments.size() == 1 and not arguments[0].strip_edges().is_empty():
			return "%s°" % number_lens(arguments[0].strip_edges())
	if text.is_valid_float():
		return "%s°" % number_lens(String.num(rad_to_deg(text.to_float()), 4))
	# U1. A quarter turn is written `PI / 2`, never `1.5708`, so the two constants a rotation is spelled
	# with are resolved here as well. Only the plain forms - a constant on its own, or one multiplied or
	# divided by a number - which is every way a fixed turn is actually written.
	return _turn_constant_degrees(text)


## U1. `PI`, `TAU / 4`, `-PI / 2`, `2 * PI` in degrees, or "" when the value is anything a reader
## would not recognise as a fixed turn. Anything with a name in it is left as the expression it is:
## `PI / sides` is not a number the row can show.
static func _turn_constant_degrees(text: String) -> String:
	const TURNS: Dictionary = {"PI": 180.0, "TAU": 360.0}
	var body: String = text.strip_edges()
	var sign_factor: float = 1.0
	if body.begins_with("-"):
		sign_factor = -1.0
		body = body.substr(1).strip_edges()
	for operator: String in [" / ", " * "]:
		var at: int = top_level_index(body, operator)
		if at < 0:
			continue
		var left: String = body.substr(0, at).strip_edges()
		var right: String = body.substr(at + 3).strip_edges()
		if TURNS.has(left) and right.is_valid_float() and right.to_float() != 0.0:
			var turn: float = float(TURNS[left])
			return "%s°" % number_lens(String.num(sign_factor * (turn / right.to_float()
				if operator == " / " else turn * right.to_float()), 4))
		if operator == " * " and TURNS.has(right) and left.is_valid_float():
			return "%s°" % number_lens(String.num(sign_factor * float(TURNS[right]) * left.to_float(), 4))
		return ""
	return "%s°" % number_lens(String.num(sign_factor * float(TURNS[body]), 4)) if TURNS.has(body) else ""


## R4. The subject of an ANGLE question. `rotation` is that object's angle, and inside a sentence
## that already says degrees the radians warning the general member word carries would be noise.
static func _angle_subject_words(subject: String, context: Dictionary) -> Array:
	var words: Array = _subject_words(subject, context)
	var bare: String = subject.strip_edges().trim_prefix("self.")
	if bare == "rotation" or bare == "rotation_degrees" or bare.ends_with(".rotation") or bare.ends_with(".rotation_degrees"):
		words[1] = translate("angle")
		words[2] = "name"
	return words


## R4. `abs(angle_difference(rotation, target_angle)) < deg_to_rad(10)` - the event-sheet Is Within
## Angle condition, which is how a reader asks "am I facing it yet". Both of Godot's absolute-value
## spellings count, and the limit must be an angle the reading can honestly show in degrees.
static func _within_angle_condition(text: String, context: Dictionary) -> Dictionary:
	var parts: Array = _comparison_parts(text)
	if parts.is_empty() or not (str(parts[1]) == "<" or str(parts[1]) == "<="):
		return {}
	var outer: Dictionary = call_parts(str(parts[0]))
	if outer.is_empty() or not (str(outer.get("method", "")) in ["abs", "absf"]):
		return {}
	var outer_arguments: PackedStringArray = outer.get("args", PackedStringArray())
	if outer_arguments.size() != 1:
		return {}
	var inner: Dictionary = call_parts(outer_arguments[0].strip_edges())
	if inner.is_empty() or str(inner.get("method", "")) != "angle_difference":
		return {}
	var pair: PackedStringArray = inner.get("args", PackedStringArray())
	if pair.size() != 2:
		return {}
	var limit: String = _angle_degrees(str(parts[2]))
	if limit.is_empty():
		return {}
	var words: Array = _angle_subject_words(pair[0], context)
	return _sentence(str(words[0]), "{value} is within {limit} of {target}", {
		"value": [str(words[1]), str(words[2])],
		"limit": [limit, "value"],
		"target": [expression_text(pair[1], context), "value"]
	})


## R4. `wrapf(a, 0, TAU) > deg_to_rad(30) and wrapf(a, 0, TAU) < deg_to_rad(60)` - one angle window,
## in degrees. The `fmod` spelling of the same wrap counts, and both terms must wrap the SAME value:
## two different angles compared to two bounds is two questions, not a window.
static func _between_angles_condition(text: String, context: Dictionary) -> Dictionary:
	if top_level_index(text, " and ") < 0:
		return {}
	var parts: PackedStringArray = split_top_level(text, " and ")
	if parts.size() != 2:
		return {}
	var first: Array = _comparison_parts(stripped_parens(parts[0]))
	var second: Array = _comparison_parts(stripped_parens(parts[1]))
	if first.is_empty() or second.is_empty():
		return {}
	if str(first[1]) == "<" or str(first[1]) == "<=":
		var swap: Array = first
		first = second
		second = swap
	if not (str(first[1]) == ">" or str(first[1]) == ">="):
		return {}
	if not (str(second[1]) == "<" or str(second[1]) == "<="):
		return {}
	var subject: String = _wrapped_angle_subject(str(first[0]))
	if subject.is_empty() or subject != _wrapped_angle_subject(str(second[0])):
		return {}
	var low: String = _angle_degrees(str(first[2]))
	var high: String = _angle_degrees(str(second[2]))
	if low.is_empty() or high.is_empty():
		return {}
	var words: Array = _angle_subject_words(subject, context)
	return _sentence(str(words[0]), "{value} is between angles {low} and {high}", {
		"value": [str(words[1]), str(words[2])],
		"low": [low, "value"],
		"high": [high, "value"]
	})


## R4. The angle a `wrapf(a, 0, TAU)` / `fmod(a, TAU)` term is really asking about, or "" when the
## term is not one of those wraps. Wrapping is the GDScript chore of keeping an angle in one turn;
## the QUESTION is about the angle itself.
static func _wrapped_angle_subject(text: String) -> String:
	var call: Dictionary = call_parts(text.strip_edges())
	if call.is_empty() or not str(call.get("target", "")).is_empty():
		return ""
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	var method: String = str(call.get("method", ""))
	if (method == "wrapf" or method == "wrapi") and arguments.size() == 3:
		return arguments[0].strip_edges()
	if (method == "fmod" or method == "fposmod") and arguments.size() == 2:
		return arguments[0].strip_edges()
	return ""


## R4. `angle_difference(a, b) > 0` - which side of an angle another one is on, in the sheet's words.
## The first angle named is the subject, exactly as the row reads.
static func _clockwise_condition(text: String, context: Dictionary) -> Dictionary:
	var parts: Array = _comparison_parts(text)
	if parts.is_empty() or not (str(parts[1]) == ">" or str(parts[1]) == ">="):
		return {}
	if not str(parts[2]).strip_edges().is_valid_float() or str(parts[2]).strip_edges().to_float() != 0.0:
		return {}
	var call: Dictionary = call_parts(str(parts[0]))
	if call.is_empty() or str(call.get("method", "")) != "angle_difference":
		return {}
	var pair: PackedStringArray = call.get("args", PackedStringArray())
	if pair.size() != 2:
		return {}
	var words: Array = _angle_subject_words(pair[0], context)
	return _sentence(str(words[0]), "{value} is clockwise from {other}", {
		"value": [str(words[1]), str(words[2])],
		"other": [expression_text(pair[1], context), "value"]
	})


## R4. `position.distance_to(target) < 100` - the event-sheet Is Within condition. The squared
## spelling asks the same question (it is the same test without the square root), so it reads the
## same, but only when the radius it compares against is honestly the radius squared.
static func _within_distance_condition(text: String, context: Dictionary) -> Dictionary:
	var parts: Array = _comparison_parts(text)
	if parts.is_empty() or not (str(parts[1]) == "<" or str(parts[1]) == "<="):
		return {}
	var call: Dictionary = call_parts(str(parts[0]))
	if call.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	if arguments.size() != 1:
		return {}
	var radius: String = ""
	if method == "distance_to":
		radius = str(parts[2])
	elif method == "distance_squared_to":
		radius = _square_root_of(str(parts[2]))
	if radius.is_empty():
		return {}
	var receiver: String = str(call.get("target", "")).strip_edges().trim_prefix("self.")
	var values: Dictionary = {
		"distance": [expression_text(radius, context), "value"],
		"other": [expression_text(arguments[0], context), "value"]
	}
	# A distance measured FROM an object's own place is that object's distance, and the row names it
	# in the object column rather than saying "position" in the middle of the sentence.
	for own_place: String in OWN_POSITION_NAMES:
		if receiver != own_place and not receiver.ends_with(".%s" % own_place):
			continue
		var owner_text: String = "" if receiver == own_place else receiver.substr(0, receiver.length() - own_place.length() - 1)
		return _sentence(_receiver_object(owner_text, context), "is within {distance} of {other}", values)
	var words: Array = _subject_words(receiver, context)
	values["value"] = [str(words[1]), str(words[2])]
	return _sentence(str(words[0]), "{value} is within {distance} of {other}", values)


## R4. The radius behind a SQUARED distance test: `r * r` is r, and a literal square is its own root
## when the root is a whole number. "" for anything else, which keeps the comparison as written
## rather than printing a radius nobody wrote.
static func _square_root_of(value: String) -> String:
	var text: String = stripped_parens(value)
	var at: int = top_level_index(text, " * ")
	if at > 0:
		var left: String = text.substr(0, at).strip_edges()
		var right: String = text.substr(at + 3).strip_edges()
		return left if left == right else ""
	if not text.is_valid_float():
		return ""
	var root: float = sqrt(text.to_float())
	return str(int(root)) if is_equal_approx(root, float(int(root))) else ""


## R4. `Rect2(0, 0, 640, 360).has_point(position)` and `zone.overlaps_point(position)` - the
## event-sheet Is Inside Area condition, with the rectangle drawn the way a reader reads a rectangle
## (corner, then size) rather than as the constructor it is.
static func _inside_area_condition(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = _tail_call(text)
	if call.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	if arguments.size() != 1 or not (method == "has_point" or method == "overlaps_point"):
		return {}
	var receiver: String = str(call.get("target", "")).strip_edges()
	var area: String = ""
	if method == "has_point":
		area = _area_words(receiver)
	elif is_simple_target(receiver):
		area = object_of_reference(receiver)
	if area.is_empty():
		return {}
	var point: String = arguments[0].strip_edges().trim_prefix("self.")
	var values: Dictionary = {"area": [area, "value"]}
	for own_place: String in OWN_POSITION_NAMES:
		if point != own_place and not point.ends_with(".%s" % own_place):
			continue
		var owner_text: String = "" if point == own_place else point.substr(0, point.length() - own_place.length() - 1)
		return _sentence(_receiver_object(owner_text, context), "is inside area {area}", values)
	var words: Array = _subject_words(point, context)
	values["value"] = [str(words[1]), str(words[2])]
	return _sentence(str(words[0]), "{value} is inside area {area}", values)


## R4. A rectangle or a box as the reader's own shorthand: `Rect2(0, 0, 640, 360)` is the corner and
## then the size, `0, 0 - 640 × 360`. "" when the receiver is not one of those constructors, because
## a computed rectangle has no corners a row could print.
static func _area_words(receiver: String) -> String:
	var call: Dictionary = call_parts(receiver.strip_edges())
	if call.is_empty() or not str(call.get("target", "")).is_empty():
		return ""
	var kind: String = str(call.get("method", ""))
	if not (kind == "Rect2" or kind == "Rect2i" or kind == "AABB"):
		return ""
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	var shown: PackedStringArray = PackedStringArray()
	for argument: String in arguments:
		shown.append(number_lens(argument.strip_edges()))
	if shown.size() == 2:
		return "%s - %s" % [shown[0], shown[1]]
	if shown.size() == 4:
		return "%s, %s - %s × %s" % [shown[0], shown[1], shown[2], shown[3]]
	if shown.size() == 6:
		return "%s, %s, %s - %s × %s × %s" % [shown[0], shown[1], shown[2], shown[3], shown[4], shown[5]]
	return ""


## R4. The three ways a script asks "are these near enough": Godot's two approximate comparisons and
## the hand-written epsilon. All of them read as the sheet's `is about`, because a reader who wrote
## any of them meant exactly that.
static func _about_condition(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if not call.is_empty():
		var method: String = str(call.get("method", ""))
		var receiver: String = str(call.get("target", "")).strip_edges()
		var arguments: PackedStringArray = call.get("args", PackedStringArray())
		if method == "is_equal_approx" and receiver.is_empty() and arguments.size() == 2:
			return _about_sentence(arguments[0], arguments[1], context)
		if method == "is_equal_approx" and not receiver.is_empty() and arguments.size() == 1:
			return _about_sentence(receiver, arguments[0], context)
		if method == "is_zero_approx" and receiver.is_empty() and arguments.size() == 1:
			return _about_sentence(arguments[0], "0", context)
	var parts: Array = _comparison_parts(text)
	if parts.is_empty() or str(parts[1]) != "<":
		return {}
	var epsilon: String = str(parts[2]).strip_edges()
	# A tolerance is a SMALL number by definition. A bigger one is a real comparison the reader means
	# as a comparison, and the sheet's Is Within condition already reads that.
	if not epsilon.is_valid_float() or absf(epsilon.to_float()) >= 0.1:
		return {}
	var difference: Dictionary = call_parts(str(parts[0]))
	if difference.is_empty() or not (str(difference.get("method", "")) in ["abs", "absf"]):
		return {}
	var inner: PackedStringArray = difference.get("args", PackedStringArray())
	if inner.size() != 1:
		return {}
	var subtraction: String = stripped_parens(inner[0])
	var minus_at: int = top_level_index(subtraction, " - ")
	if minus_at <= 0:
		return {}
	return _about_sentence(subtraction.substr(0, minus_at), subtraction.substr(minus_at + 3), context)


## R4. The finished `is about` reading. A body's speed gets the extra half-sentence it deserves:
## `is_zero_approx(velocity.length())` is the question "has it stopped", and saying so costs nothing.
static func _about_sentence(subject: String, other: String, context: Dictionary) -> Dictionary:
	var bare: String = subject.strip_edges().trim_prefix("self.")
	var speed_call: Dictionary = call_parts(bare)
	var is_speed: bool = false
	var words: Array = []
	if not speed_call.is_empty() and str(speed_call.get("method", "")) == "length":
		var receiver: String = str(speed_call.get("target", "")).strip_edges().trim_prefix("self.")
		if receiver == "velocity" or receiver.ends_with(".velocity"):
			is_speed = true
			var owner_text: String = "" if receiver == "velocity" else receiver.substr(0, receiver.length() - "velocity".length() - 1)
			words = [_receiver_object(owner_text, context), translate("speed"), "name"]
	if words.is_empty():
		words = _subject_words(bare, context)
	var values: Dictionary = {
		"value": [str(words[1]), str(words[2])],
		"other": [expression_text(other, context), "value"]
	}
	if is_speed:
		return _sentence(str(words[0]), "{value} is about {other} (not moving)", values)
	return _sentence(str(words[0]), "{value} is about {other}", values)


## The receiver / method / arguments split of a call whose RECEIVER may itself be a call:
## `Rect2(0, 0, 640, 360).has_point(position)` is one `has_point` on a rectangle, which `call_parts`
## refuses because it wants a plain receiver. {} when the text is not a call on something.
static func _tail_call(text: String) -> Dictionary:
	var trimmed: String = text.strip_edges()
	if not trimmed.ends_with(")"):
		return {}
	var depth: int = 0
	var index: int = trimmed.length() - 1
	var open_at: int = -1
	while index >= 0:
		var character: String = trimmed[index]
		if character == ")":
			depth += 1
		elif character == "(":
			depth -= 1
			if depth == 0:
				open_at = index
				break
		index -= 1
	if open_at <= 0:
		return {}
	var head: String = trimmed.substr(0, open_at).strip_edges()
	var dot_at: int = head.rfind(".")
	if dot_at < 0:
		return {}
	var method: String = head.substr(dot_at + 1).strip_edges()
	if not is_identifier(method):
		return {}
	return {
		"target": head.substr(0, dot_at).strip_edges(),
		"method": method,
		"args": _split_arguments(trimmed.substr(open_at + 1, trimmed.length() - open_at - 2))
	}


## R5. `Time.get_ticks_msec() - last_shot > 500` - the cooldown-by-timestamp every jam script has,
## as the sheet's own "X seconds have passed since". Milliseconds become seconds, so nobody has to
## know what a tick is or do the division in their head; the wall-clock spelling says so, because
## that number keeps counting while the game is closed.
static func _elapsed_condition(text: String, context: Dictionary) -> Dictionary:
	var parts: Array = _comparison_parts(text)
	if parts.is_empty() or not (str(parts[1]) == ">" or str(parts[1]) == ">="):
		return {}
	var difference: String = stripped_parens(str(parts[0]))
	var minus_at: int = top_level_index(difference, " - ")
	if minus_at <= 0:
		return {}
	var clock: String = difference.substr(0, minus_at).strip_edges()
	if not CLOCK_CALLS.has(clock):
		return {}
	var since: String = difference.substr(minus_at + 3).strip_edges()
	var amount: String = str(parts[2]).strip_edges()
	if since.is_empty() or amount.is_empty():
		return {}
	var in_milliseconds: bool = bool(CLOCK_CALLS[clock])
	var seconds: String = amount
	if in_milliseconds:
		# Only a literal is divided. Turning `cooldown_ms` into "cooldown ms / 1000 seconds" would be a
		# sentence about arithmetic, which is exactly what this reading exists to remove.
		if not amount.is_valid_float():
			return {}
		seconds = number_lens(String.num(amount.to_float() / 1000.0, 4))
	var words: Array = _subject_words(since, context)
	var values: Dictionary = {
		"seconds": [seconds, "value"],
		"since": [str(words[1]), str(words[2])]
	}
	if in_milliseconds:
		return _sentence(OBJECT_SYSTEM, "{seconds} seconds have passed since {since}", values)
	return _sentence(OBJECT_SYSTEM, "{seconds} seconds have passed since {since} (clock time)", values)


## R5. `last_shot = Time.get_ticks_msec()` - writing the clock into a variable is the sheet's
## "Set ... to now". {} for every other value, which keeps the plain Set the caller already reads.
static func _now_assignment(target: String, assigned: String, context: Dictionary) -> Dictionary:
	var clock: String = assigned.strip_edges()
	if not CLOCK_CALLS.has(clock):
		return {}
	# T26. The wall clock now has a NAME of its own in the sheet - the Date object's `Now` - so the row
	# says that rather than a word for it, and the whole Date family reads alike. The run clock keeps
	# this sentence, because there is no Date expression for a number that restarts with the game.
	if not bool(CLOCK_CALLS[clock]):
		return {}
	var split: Array = _split_object(target, context)
	var values: Dictionary = {"name": [str(split[1]), "name"]}
	if bool(CLOCK_CALLS[clock]):
		return _sentence(str(split[0]), "Set {name} to now", values)
	return _sentence(str(split[0]), "Set {name} to now (clock time)", values)


## R8. The LAYOUT a scene path names, as the reader named the file: `res://levels/level_2.tscn` is
## `Level 2`. The folder and the extension are Godot's filing, never part of what the row does, and
## the whole path stays one hover away. A path that is not a literal keeps whatever it is.
static func layout_name(scene_path: String) -> String:
	var text: String = scene_path.strip_edges()
	if not _is_string_literal(text):
		return text
	var file_name: String = _unquote(text.trim_prefix("&")).get_file().get_basename()
	return file_name.capitalize() if not file_name.is_empty() else text


## R11. `position.x < 0 or position.x > get_viewport_rect().size.x` - the event-sheet Is Outside
## Layout condition. Two edges of the same axis collapse into the one question they ask together, and
## a single edge says which side it watches, because "outside on the left" is a different bug from
## "outside on the right".
static func _layout_bounds_condition(text: String, context: Dictionary) -> Dictionary:
	var parts: PackedStringArray = PackedStringArray([text])
	if top_level_index(text, " or ") >= 0:
		parts = split_top_level(text, " or ")
	if parts.size() > 2 or top_level_index(text, " and ") >= 0:
		return {}
	var edges: Array = []
	for part: String in parts:
		var edge: Dictionary = _layout_edge(stripped_parens(part), context)
		if edge.is_empty():
			return {}
		edges.append(edge)
	var first: Dictionary = edges[0]
	var note: String = _edge_note(str(first["axis"]), str(first["side"]))
	if edges.size() == 2:
		var second: Dictionary = edges[1]
		if str(second["object"]) != str(first["object"]) or str(second["axis"]) != str(first["axis"]):
			return {}
		if str(second["side"]) == str(first["side"]):
			return {}
		note = _edge_note(str(first["axis"]), "both")
	var reading: Dictionary = _sentence(str(first["object"]), "Is outside layout", {})
	if not note.is_empty():
		(reading["segments"] as Array).append({"text": " %s" % note, "tone": "plain"})
	return reading


## R11. ONE edge test as {object, axis, side}, or {} when the term is not one. Only a comparison of an
## object's own place against 0 or against the viewport's matching side is claimed: a test against
## some other number is a comparison the reader means as a comparison.
static func _layout_edge(text: String, context: Dictionary) -> Dictionary:
	var parts: Array = _comparison_parts(text)
	if parts.is_empty():
		return {}
	var place: String = str(parts[0]).strip_edges().trim_prefix("self.")
	var dot_at: int = place.rfind(".")
	if dot_at <= 0:
		return {}
	var axis: String = place.substr(dot_at + 1).to_lower()
	if not (axis == "x" or axis == "y"):
		return {}
	var chain: String = place.substr(0, dot_at)
	var owner_text: String = ""
	var is_place: bool = false
	for own_place: String in OWN_POSITION_NAMES:
		if chain == own_place:
			is_place = true
		elif chain.ends_with(".%s" % own_place):
			is_place = true
			owner_text = chain.substr(0, chain.length() - own_place.length() - 1)
	if not is_place:
		return {}
	var operator: String = str(parts[1])
	var bound: String = str(parts[2]).strip_edges()
	# Strictly PAST the edge, both ways. `position.x <= 0` accepts the pixel column the edge itself is,
	# which is a comparison the author meant as a comparison, and reading it as "outside" would be a
	# sentence about a place the object still occupies.
	var side: String = ""
	if operator == "<" and bound.is_valid_float() and bound.to_float() == 0.0:
		side = "low"
	elif operator == ">" and _is_viewport_extent(bound, axis):
		side = "high"
	if side.is_empty():
		return {}
	return {"object": _receiver_object(owner_text, context), "axis": axis, "side": side}


## R11. True when a bound IS the layout's own width or height. The system-words lens has usually
## already renamed the call by the time a reading sees it, so both spellings are accepted.
static func _is_viewport_extent(bound: String, axis: String) -> bool:
	var text: String = bound.strip_edges()
	var named: String = "ViewportWidth" if axis == "x" else "ViewportHeight"
	if text == named:
		return true
	for rect: String in VIEWPORT_RECTS:
		if text == "%s.size.%s" % [rect, axis] or text == "%s.end.%s" % [rect, axis]:
			return true
	return false


## R11. Which side of the layout an edge watches, in the sheet's words.
static func _edge_note(axis: String, side: String) -> String:
	if axis == "x":
		if side == "both":
			return translate("(left or right)")
		return translate("(left)") if side == "low" else translate("(right)")
	if side == "both":
		return translate("(top or bottom)")
	return translate("(top)") if side == "low" else translate("(bottom)")


## R11. `get_viewport().get_visible_rect().has_point(global_position)` - the event-sheet Is On-Screen
## condition, which is the question a culling or a spawn guard is really asking.
static func _on_screen_condition(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = _tail_call(text)
	if call.is_empty() or str(call.get("method", "")) != "has_point":
		return {}
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	if arguments.size() != 1 or not VIEWPORT_RECTS.has(str(call.get("target", "")).strip_edges()):
		return {}
	return _sentence(_point_object(arguments[0], context), "Is on-screen", {})


## R11. `not get_viewport_rect().has_point(position)` is not a mark on a reading: an event sheet has
## its own Is Outside Layout condition, and that is the row a reader wants to see. {} for anything
## else, which lets the general negation carry on drawing its ✕.
static func outside_layout_reading(text: String, context: Dictionary) -> Dictionary:
	if not text.begins_with("not "):
		return {}
	var on_screen: Dictionary = _on_screen_condition(stripped_parens(text.substr(4)), context)
	if on_screen.is_empty():
		return {}
	return _sentence(str(on_screen.get("object", "")), "Is outside layout", {})


## The object a POINT belongs to: the script's own object for its own place, the named object for
## somebody else's, and System for a point that is nobody's in particular.
static func _point_object(point: String, context: Dictionary) -> String:
	var text: String = point.strip_edges().trim_prefix("self.")
	for own_place: String in OWN_POSITION_NAMES:
		if text == own_place:
			return script_object(context)
		if text.ends_with(".%s" % own_place):
			return _receiver_object(text.substr(0, text.length() - own_place.length() - 1), context)
	return str(_subject_words(text, context)[0])


## R7. The sheet's own EXPRESSION NAMES - the words a reader types into an expression field - for the
## view that has the Familiar Words glossary on. Godot's spelling stays one hover away on the row,
## and with the glossary off nothing here runs at all.
##
## Nothing in this table is translated, for the same reason `max` and `min` are not: these are
## identifiers a reader TYPES, and a translated identifier is one nobody can type. Each entry is one
## exact shape with one exact name, and a shape that does not match exactly is left as the code it is.
##
## `lerp`, `clamp`, `abs`, `floor`, `ceil`, `round`, `sqrt`, `min` and `max` are deliberately absent:
## the two vocabularies spell those the same, so there is nothing to rename.
const FAMILIAR_EXPRESSION_PATTERNS: Array = [
	# distance(a, b) / angle(a, b) - measured between two OBJECTS, which is how a sheet asks it
	["([A-Za-z_][A-Za-z0-9_.]*)\\.(?:global_)?position\\.distance_to\\(([A-Za-z_][A-Za-z0-9_.]*)\\.(?:global_)?position\\)", "distance($1, $2)"],
	["([A-Za-z_][A-Za-z0-9_.]*)\\.get_angle_to\\(([A-Za-z_][A-Za-z0-9_.]*)\\.(?:global_)?position\\)", "angle($1, $2)"],
	["([A-Za-z_][A-Za-z0-9_.]*)\\.get_angle_to\\(([A-Za-z_][A-Za-z0-9_.]*)\\)", "angle($1, $2)"],
	# text: tokenat before split's own reading, left before mid (a substr from 0 IS left)
	["([A-Za-z_][A-Za-z0-9_.]*)\\.split\\((\"[^\"]*\")\\)\\[([^\\[\\]]+)\\]", "tokenat($1, $3, $2)"],
	["\"%0([0-9]+)d\"\\s*%\\s*([A-Za-z_][A-Za-z0-9_.]*)", "zeropad($2, $1)"],
	["([A-Za-z_][A-Za-z0-9_.]*)\\.substr\\(0,\\s*([^(),]+)\\)", "left($1, $2)"],
	["([A-Za-z_][A-Za-z0-9_.]*)\\.substr\\(([^(),]+),\\s*([^(),]+)\\)", "mid($1, $2, $3)"],
	# len(x) - the answer to the length question, for text and for lists alike (R7 settles it)
	["([A-Za-z_][A-Za-z0-9_.]*)\\.(?:length|size)\\(\\)", "len($1)"],
	# the numbers a sheet reads by name
	["Engine\\.get_process_frames\\(\\)", "tickcount"],
	# V6 - the two text calls whose sheet spelling is a word rather than a method
	["str\\(([A-Za-z_][A-Za-z0-9_.]*)\\)\\.pad_zeros\\(([0-9]+)\\)", "zeropad($1, $2)"],
	["([A-Za-z_][A-Za-z0-9_.]*)\\.pad_zeros\\(([0-9]+)\\)", "zeropad($1, $2)"],
	["([A-Za-z_][A-Za-z0-9_.]*)\\.capitalize\\(\\)", "capitalised $1"],
	["randi_range\\(([^(),]+),\\s*([^(),]+)\\)", "random($1, $2)"],
	["randf_range\\(([^(),]+),\\s*([^(),]+)\\)", "random($1, $2)"],
	["randi\\(\\)\\s*%\\s*([A-Za-z_][A-Za-z0-9_.]*)", "random($1)"],
	["\\[([^\\[\\]()]*)\\]\\.pick_random\\(\\)", "choose($1)"]
]


## R7 / R6. A value expression in the sheet's own expression names. Returns the text unchanged with
## the Familiar Words glossary off, which is how it ships, so the reading costs nothing until a
## reader asks for it.
static func familiar_expression_words(text: String, context: Dictionary) -> String:
	if not bool(context.get("familiar_words", false)) or text.is_empty():
		return text
	var out: String = text
	for entry: Array in _familiar_patterns():
		if out.length() > 400:
			break
		out = (entry[0] as RegEx).sub(out, str(entry[1]), true)
	return _color_names(out)


## The table compiled once for the whole session. A row is rewritten on every rebuild of every view
## that has the glossary on, and compiling a dozen patterns per value would cost more than the whole
## reading does. Filled by this function alone, so a half-built table can never be handed out.
static var _compiled_familiar_patterns: Array = []

## The grammar's other matchers, likewise compiled once. Each of these is asked of every word or
## every value of every row, and building the pattern cost far more than running it.
static var _brace_slot_regex: RegEx = null
static var _percent_slot_regex: RegEx = null
static var _delta_regex: RegEx = null
static var _leading_word_regex: RegEx = null
static var _identifier_regex: RegEx = null
static var _color_constant_regex: RegEx = null


static func _familiar_patterns() -> Array:
	if not _compiled_familiar_patterns.is_empty():
		return _compiled_familiar_patterns
	var compiled: Array = []
	for entry: Array in FAMILIAR_EXPRESSION_PATTERNS:
		var pattern: RegEx = RegEx.create_from_string(str(entry[0]))
		if pattern != null:
			compiled.append([pattern, str(entry[1])])
	_compiled_familiar_patterns = compiled
	return _compiled_familiar_patterns


## R7. `Color.RED` as the colour a reader would say. Only Godot's own SCREAMING_CASE constants are
## renamed, and only under the glossary - everywhere else the constant is one exact spelling somebody
## typed.
static func _color_names(text: String) -> String:
	if not text.contains("Color."):
		return text
	if _color_constant_regex == null:
		_color_constant_regex = RegEx.create_from_string("Color\\.([A-Z][A-Z0-9_]*)")
	var pattern: RegEx = _color_constant_regex
	if pattern == null:
		return text
	var out: String = text
	for found: RegExMatch in pattern.search_all(text):
		out = out.replace(found.get_string(0), found.get_string(1).capitalize().to_lower())
	return out


# ── S16 / S17 / S18: effects, tilemaps and the camera ────────────────────────────
#
# Three families of line every 2D game writes, and three families of row the sheet already has words
# for. A ShaderMaterial parameter IS an effect parameter; a TileMap cell IS a tile at a cell; a
# Camera2D limit IS a scroll limit. Each reading below claims its shape exactly - the strictness at
# the top of this file applies here too - and carries a "pattern" key so the pattern registry can be
# filled from the readings themselves rather than from a second, drifting set of matchers.


## S16. The property slots an effect is worn in. A ShaderMaterial hangs off one of these, so the row
## belongs to the OBJECT wearing it: a reader thinks "the sprite is flashing", never "the sprite's
## material's uniform is 1".
const EFFECT_SLOTS: PackedStringArray = ["material", "material_override", "material_overlay"]

## S17. The tilemap questions a reader types into an expression field, by the Godot method that asks
## them. These are NAMES a reader spells, exactly like `max` and `min`, which is why they keep the
## call shape rather than being turned into prose.
const TILEMAP_EXPRESSION_WORDS: Dictionary = {
	"get_cell_source_id": "TileAt",
	"local_to_map": "PositionToTile",
	"map_to_local": "TileToPosition"
}


## The reading with the pattern it is an instance of written on it. The row builder reads this key to
## claim the pattern once per event; nothing about the row itself changes.
static func _patterned(reading: Dictionary, pattern: String) -> Dictionary:
	if reading.is_empty():
		return reading
	reading["pattern"] = pattern
	return reading


## S16. The object an effect line is ABOUT: `sprite.material` is the sprite, a bare `material` is the
## script's own object, and a local holding the material is itself the nearest name a reader has.
static func effects_object(receiver: String, context: Dictionary) -> String:
	var text: String = receiver.strip_edges().trim_prefix("self.")
	for slot: String in EFFECT_SLOTS:
		if text == slot:
			return script_object(context)
		if text.ends_with(".%s" % slot):
			text = text.substr(0, text.length() - slot.length() - 1)
			break
	return _receiver_object(text, context)


## S16. The effect parameter a call names, without the quoting or the StringName mark the GDScript
## needed: `&"flash"` and `"flash"` are the same parameter, and a reader means `flash` by both.
static func effect_parameter_name(argument: String) -> String:
	var text: String = argument.strip_edges().trim_prefix("&")
	if _is_string_literal(text):
		return _unquote(text)
	return text


## S16. `sprite.material.set_shader_parameter("flash", 1.0)` -> `sprite ▸ Set effect parameter flash
## to 1`. Only the two-argument call is claimed, which is the only shape the method has.
static func _effects_call(method: String, args: PackedStringArray, receiver: String,
		context: Dictionary) -> Dictionary:
	# `tween_method` lives on exactly one class, so a tween holding an effect lambda says what it is
	# without the chain having to be proved first - which matters, because the tween a hit-flash uses
	# is usually a field declared far from the line that drives it.
	if method == "tween_method":
		return _tween_effect_sentence(args, context)
	if method != "set_shader_parameter" or args.size() != 2:
		return {}
	if receiver.strip_edges().is_empty():
		return {}
	return _patterned(_sentence(effects_object(receiver, context),
		"Set effect parameter {name} to {value}", {
			"name": [effect_parameter_name(args[0]), "name"],
			"value": [expression_text(args[1], context), "value"]
		}), "effects")


## S16. Writing the material slot is putting an effect ON an object or taking it OFF again:
## `sprite.material = null` is Remove effect, and a shader resource is the effect it is named after.
static func _effects_assignment(object_name: String, assigned: String, context: Dictionary) -> Dictionary:
	var value: String = assigned.strip_edges()
	if value == "null":
		return _patterned(_sentence(object_name, "Remove effect", {}), "effects")
	var named: String = effect_resource_name(value)
	if named.is_empty():
		return {}
	return _patterned(_sentence(object_name, "Set effect to {name}",
		{"name": [named, "value"]}), "effects")


## S16. The name an effect resource goes by - the file it lives in, without the folder it is filed
## under or the extension Godot needs. A plain variable is already a name; anything else is "" so the
## row keeps the plain property write rather than inventing a name for it.
static func effect_resource_name(value: String) -> String:
	var text: String = value.strip_edges()
	for head: String in ["preload(", "load("]:
		if not text.begins_with(head) or not text.ends_with(")"):
			continue
		var inner: String = text.substr(head.length(), text.length() - head.length() - 1).strip_edges()
		if not _is_string_literal(inner):
			return ""
		return _unquote(inner).get_file().get_basename()
	return text if is_identifier(text) else ""


## S16. `tween_method(func(v): mat.set_shader_parameter("dissolve", v), 0.0, 1.0, 0.5)` is the one
## shape the sheet has a sentence for: an effect parameter driven from one value to another over
## time. The row belongs to the material the lambda writes, because that is what is changing.
static func _tween_effect_sentence(arguments: PackedStringArray, context: Dictionary) -> Dictionary:
	if arguments.size() != 4:
		return {}
	var lambda: Dictionary = effect_lambda_parts(arguments[0], context)
	if lambda.is_empty():
		return {}
	return _patterned(_sentence(str(lambda.get("object", "")),
		"Tween effect parameter {name} from {from} to {to} in {seconds} seconds", {
			"name": [str(lambda.get("name", "")), "name"],
			"from": [expression_text(arguments[1], context), "value"],
			"to": [expression_text(arguments[2], context), "value"],
			"seconds": [expression_text(arguments[3], context), "value"]
		}), "effects")


## S16. `func(v): mat.set_shader_parameter("dissolve", v)` -> {object, name}, or {} when the lambda
## does anything else. The lambda's own parameter must be exactly what the call hands over: a body
## that computes something on the way is not a plain tween of that parameter, and no one sentence
## could say what it does.
static func effect_lambda_parts(text: String, context: Dictionary) -> Dictionary:
	var body: String = text.strip_edges()
	if not body.begins_with("func("):
		return {}
	var params_end: int = closing_paren(body, 4)
	if params_end < 0:
		return {}
	var parameter: String = body.substr(5, params_end - 5).strip_edges()
	var colon_at: int = parameter.find(":")
	if colon_at >= 0:
		parameter = parameter.substr(0, colon_at).strip_edges()
	if not is_identifier(parameter):
		return {}
	var rest: String = body.substr(params_end + 1).strip_edges()
	if not rest.begins_with(":"):
		return {}
	var call: Dictionary = call_parts(rest.substr(1).strip_edges())
	if call.is_empty() or str(call.get("method", "")) != "set_shader_parameter":
		return {}
	var call_args: PackedStringArray = call.get("args", PackedStringArray())
	if call_args.size() != 2 or call_args[1].strip_edges() != parameter:
		return {}
	var receiver: String = str(call.get("target", ""))
	if receiver.strip_edges().is_empty():
		return {}
	return {"object": effects_object(receiver, context), "name": effect_parameter_name(call_args[0])}


## S17. The tilemap verbs. Both node generations answer here: the layer-per-node spelling (4.3+) takes
## the cell first, the older one names the layer in front of it, and the reading is the same sentence
## with the layer said quietly at the end.
static func _tilemap_call(method: String, args: PackedStringArray, receiver: String,
		context: Dictionary) -> Dictionary:
	if receiver.strip_edges().is_empty():
		return {}
	var object_name: String = _receiver_object(receiver, context)
	if method == "set_cell" and (args.size() == 3 or args.size() == 4):
		var layered: bool = args.size() == 4
		var offset: int = 1 if layered else 0
		var reading: Dictionary = _sentence(object_name, "Set tile at {cell} to {atlas}", {
			"cell": [expression_text(args[offset], context), "value"],
			"atlas": [_unwrapped_group(expression_text(args[offset + 2], context)), "value"]
		})
		_append_note(reading, _tilemap_note(args[0] if layered else "",
			expression_text(args[offset + 1], context)))
		return _patterned(reading, "tilemap")
	if method == "erase_cell" and (args.size() == 1 or args.size() == 2):
		var layered_erase: bool = args.size() == 2
		var erase_reading: Dictionary = _sentence(object_name, "Erase tile at {cell}", {
			"cell": [expression_text(args[1 if layered_erase else 0], context), "value"]
		})
		_append_note(erase_reading, _tilemap_note(args[0] if layered_erase else "", ""))
		return _patterned(erase_reading, "tilemap")
	return {}


## S17. The quiet half of a tilemap row: which layer the cell is on and which tileset the tile came
## from. Both are numbers a reader only wants when something is wrong, so they sit behind the
## sentence rather than inside it. "" when the line names neither.
static func _tilemap_note(layer: String, tileset: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if not layer.strip_edges().is_empty():
		parts.append(_fill(translate("layer {n}"), {"n": layer.strip_edges()}))
	if not tileset.strip_edges().is_empty():
		parts.append(_fill(translate("tileset {id}"), {"id": tileset.strip_edges()}))
	return "" if parts.is_empty() else "(%s)" % " · ".join(parts)


## A muted aside appended to a reading, the way a range says which end it leaves out.
static func _append_note(reading: Dictionary, note: String) -> void:
	if reading.is_empty() or note.strip_edges().is_empty():
		return
	(reading["segments"] as Array).append({"text": " %s" % note, "tone": "muted"})


## S17. `if data and data.get_custom_data("solid")` - the tile's own data, asked about the cell the
## data came from. Both spellings answer: the local a line above filled from `get_cell_tile_data`
## (the file's own facts say which local that is), and the whole thing written out in one expression,
## which is what the picked row writes.
static func _tile_data_condition(text: String, context: Dictionary) -> Dictionary:
	var and_at: int = top_level_index(text, " and ")
	if and_at < 0:
		return {}
	var guard: String = text.substr(0, and_at).strip_edges()
	var asked: String = text.substr(and_at + 5).strip_edges()
	var dot_at: int = asked.rfind(".get_custom_data(")
	if dot_at <= 0 or not asked.ends_with(")"):
		return {}
	var holder: String = asked.substr(0, dot_at).strip_edges()
	var key: String = asked.substr(dot_at + 17, asked.length() - dot_at - 18).strip_edges()
	if not _is_string_literal(key):
		return {}
	# The guard must be about the SAME thing the question is asked of, however it is spelled.
	var guarded: String = guard.trim_suffix(" != null").strip_edges()
	if guarded != holder:
		return {}
	var tile: Dictionary = tile_data_source(holder, context)
	if tile.is_empty():
		return {}
	return _patterned(_sentence(str(tile.get("object", "")), "tile at {cell} has {name} set", {
		"cell": [expression_text(str(tile.get("cell", "")), context), "value"],
		"name": [_unquote(key), "name"]
	}), "tilemap")


## S17. Where a tile-data value came from, as {object, cell} - either a local the file filled from
## `get_cell_tile_data` (looked up in the facts the sheet gathered once) or the call written out in
## place. {} when the holder cannot be proved to be a tile's data, which keeps the plain reading.
static func tile_data_source(holder: String, context: Dictionary) -> Dictionary:
	var text: String = holder.strip_edges()
	if is_identifier(text):
		var known: Dictionary = context.get("tile_data_locals", {})
		return (known.get(text, {}) as Dictionary).duplicate() if known.has(text) else {}
	return tile_data_call_parts(text, context)


## S17. `tilemap.get_cell_tile_data(0, cell)` -> {object, cell}, for both node generations. {} for
## anything else.
static func tile_data_call_parts(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text.strip_edges())
	if call.is_empty() or str(call.get("method", "")) != "get_cell_tile_data":
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if args.is_empty() or args.size() > 2:
		return {}
	var receiver: String = str(call.get("target", ""))
	if receiver.strip_edges().is_empty():
		return {}
	return {
		"object": _receiver_object(receiver, context),
		"cell": args[args.size() - 1].strip_edges()
	}


## S18. `camera.global_position = camera.global_position.lerp(target.global_position, 5 * delta)` is
## the follow every 2D game writes, and the sheet says it in one row: scroll toward a thing, at a
## rate, per second. Claimed only on a camera and only when the rate is a plain per-second one - a
## lerp with a bare constant is frame-rate dependent and reads as the arithmetic it is.
static func _scroll_toward_assignment(target: String, assigned: String, context: Dictionary) -> Dictionary:
	if not OWN_POSITION_NAMES.has(_trailing_member(target)):
		return {}
	var object_name: String = _receiver_object(_owner_of(target), context)
	if not _class_is_any(object_class_of(object_name, context), CAMERA_CLASSES):
		return {}
	var call: Dictionary = call_parts(assigned.strip_edges())
	if call.is_empty() or str(call.get("method", "")) != "lerp":
		return {}
	if str(call.get("target", "")).strip_edges() != target.strip_edges():
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if args.size() != 2:
		return {}
	var rate: String = _per_second_factor(args[1])
	if rate.is_empty():
		return {}
	var followed: String = args[0].strip_edges()
	if OWN_POSITION_NAMES.has(_trailing_member(followed)):
		followed = _owner_of(followed)
	if followed.is_empty():
		return {}
	var reading: Dictionary = _sentence(object_name, "Scroll toward {target} at {rate}", {
		"target": [expression_text(followed, context), "value"],
		"rate": [expression_text(rate, context), "value"]
	})
	_append_note(reading, translate("(per second)"))
	return _patterned(reading, "camera")


## The member at the end of a dotted target (`camera.global_position` -> "global_position"), and the
## part in front of it. Two one-line helpers so the follow reading above reads as one sentence.
static func _trailing_member(text: String) -> String:
	var bare: String = text.strip_edges().trim_prefix("self.")
	var dot_at: int = bare.rfind(".")
	return bare if dot_at < 0 else bare.substr(dot_at + 1)


## The part of a dotted name in front of its last member, "" when there is none.
static func _owner_of(text: String) -> String:
	var bare: String = text.strip_edges().trim_prefix("self.")
	var dot_at: int = bare.rfind(".")
	return "" if dot_at < 0 else bare.substr(0, dot_at)


## S18. The spellings of "this frame's slice of a second". The picked row writes the call because a
## `delta` parameter is not in scope everywhere a row can be dropped; a typed line usually names the
## parameter. Both mean the same thing, so both read the same.
const PER_SECOND_NAMES: PackedStringArray = [
	"delta", "_delta", "get_process_delta_time()", "get_physics_process_delta_time()"
]


## S18. The rate out of `5 * delta` / `delta * 5`, or "" when the factor is not per-second at all.
static func _per_second_factor(value: String) -> String:
	var text: String = value.strip_edges()
	var at: int = top_level_index(text, " * ")
	if at < 0:
		return ""
	var left: String = text.substr(0, at).strip_edges()
	var right: String = text.substr(at + 3).strip_edges()
	if PER_SECOND_NAMES.has(right):
		return left
	if PER_SECOND_NAMES.has(left):
		return right
	return ""


# ── S8 / S9 / S10 / S15 - the Godot systems patterns ────────────────────────────
#
# Four shapes a script makes out of SEVERAL lines together, each of which an event sheet already has
# rows for: loading a layout in the background, the movement math a body block is built from, the
# high-level multiplayer messages, and a navigation agent's path.
#
# What one line cannot know on its own - which local holds the progress array, which local holds a
# nav agent, which function is a message - is gathered once per rebuild by the reading rows and
# handed in through `context`, exactly as the tween chains and the timer modes already are. With
# those facts absent every reading here simply does not fire, so the grammar stays usable on its own
# and a sheet that says nothing about a pattern never reads as one.


## S8. The four ResourceLoader spellings the background-loading idiom is made of, and the constant
## that answers "is it there yet".
const LOAD_REQUEST_HEAD := "ResourceLoader.load_threaded_request("
const LOAD_GET_HEAD := "ResourceLoader.load_threaded_get("
const LOAD_STATUS_HEAD := "ResourceLoader.load_threaded_get_status("
const SCENE_PACKED_HEAD := "get_tree().change_scene_to_packed("
const LOADED_CONSTANT := "ResourceLoader.THREAD_LOAD_LOADED"

## S15. What a navigation agent IS. Matched through ClassDB, so a subclass of either answers alike.
const NAV_AGENT_CLASSES: PackedStringArray = ["NavigationAgent2D", "NavigationAgent3D"]

## S10. The two `@rpc` mode words that change what a message DOES, in the sheet's own phrasing. A
## mode the annotation leaves out is Godot's default, which is what the muted note then says.
const RPC_MODE_WORDS: Dictionary = {
	"any_peer": "from any peer",
	"authority": "from the owner",
	"call_local": "runs here too",
	"call_remote": "remote only",
	"reliable": "reliable",
	"unreliable": "unreliable",
	"unreliable_ordered": "unreliable, in order"
}


## S8. The layout a background-load call names: a path literal is named the way the file is named,
## a variable the sheet declared from a literal is followed to that literal, and anything else keeps
## the expression it is - a reading may not invent a layout nobody can point at.
static func loading_layout_name(value: String, context: Dictionary) -> String:
	var text: String = value.strip_edges()
	if _is_string_literal(text):
		return layout_name(text)
	var paths: Dictionary = context.get("loading_paths", {})
	if paths.has(text):
		return layout_name(str(paths[text]))
	return expression_text(text, context)


## S8. `ResourceLoader.load_threaded_request(path)` and the `change_scene_to_packed(load_threaded_get
## (path))` pair, as the two System actions an event sheet writes for them.
static func _background_loading_statement(text: String, context: Dictionary) -> Dictionary:
	if text.begins_with(LOAD_REQUEST_HEAD) and text.ends_with(")"):
		var requested: PackedStringArray = _split_arguments(
			text.substr(LOAD_REQUEST_HEAD.length(), text.length() - LOAD_REQUEST_HEAD.length() - 1))
		if requested.size() >= 1 and not requested[0].strip_edges().is_empty():
			return _sentence(OBJECT_SYSTEM, "Load layout {path} in the background",
				{"path": [loading_layout_name(requested[0], context), "value"]})
	if text.begins_with(SCENE_PACKED_HEAD) and text.ends_with(")"):
		var inner: String = text.substr(
			SCENE_PACKED_HEAD.length(), text.length() - SCENE_PACKED_HEAD.length() - 1).strip_edges()
		if inner.begins_with(LOAD_GET_HEAD) and inner.ends_with(")"):
			var got: String = inner.substr(
				LOAD_GET_HEAD.length(), inner.length() - LOAD_GET_HEAD.length() - 1).strip_edges()
			if not got.is_empty():
				return _sentence(OBJECT_SYSTEM, "Go to layout {path}",
					{"path": [loading_layout_name(got, context), "value"]})
	return {}


## S8. `st == ResourceLoader.THREAD_LOAD_LOADED` - the question the whole status enum is asked for.
## The path comes from the local the status was read into, so the row names the layout rather than
## the variable somebody happened to call `st`.
static func _background_loading_condition(text: String, context: Dictionary) -> Dictionary:
	var equals_at: int = top_level_index(text, " == ")
	if equals_at <= 0 or text.substr(equals_at + 4).strip_edges() != LOADED_CONSTANT:
		return {}
	var left: String = text.substr(0, equals_at).strip_edges()
	var path_text: String = ""
	var statuses: Dictionary = context.get("loading_status", {})
	if statuses.has(left):
		path_text = str(statuses[left])
	elif left.begins_with(LOAD_STATUS_HEAD) and left.ends_with(")"):
		var asked: PackedStringArray = _split_arguments(
			left.substr(LOAD_STATUS_HEAD.length(), left.length() - LOAD_STATUS_HEAD.length() - 1))
		if asked.size() >= 1:
			path_text = asked[0]
	if path_text.strip_edges().is_empty():
		return {}
	return _sentence(OBJECT_SYSTEM, "layout {path} has finished loading",
		{"path": [loading_layout_name(path_text, context), "value"]})


## S8. The progress array read by index, as the one expression an event sheet has for it. Claimed
## only for a local the file itself passed to `load_threaded_get_status`, and never inside a string.
static func loading_progress_words(text: String, context: Dictionary) -> String:
	var progress: Dictionary = context.get("loading_progress", {})
	if progress.is_empty() or not text.contains("[") or text.contains("\""):
		return text
	var out: String = text
	for name_text: Variant in progress:
		out = out.replace("%s[0]" % str(name_text), "System.LoadingProgress")
	return out


## S9. True when the script this row belongs to IS a character body - the only thing whose `velocity`
## is the movement a behavior would own. A plain Node2D's `velocity` is just a variable somebody
## declared, and reading it as gravity would be a guess.
static func is_character_body(context: Dictionary) -> bool:
	return _class_is_any(str(context.get("self_class", "")).strip_edges(), CHARACTER_BODY_CLASSES)


## S9. The rate out of a `<rate> * delta` (or `delta * <rate>`) product - the per-second spelling of
## every movement step. "" when the expression is not scaled by the frame time at all, which is what
## keeps a plain `velocity.y += 10` from reading as gravity.
static func per_second_factor(value: String) -> String:
	var text: String = value.strip_edges()
	while text.begins_with("(") and closing_paren(text, 0) == text.length() - 1:
		text = text.substr(1, text.length() - 2).strip_edges()
	var times_at: int = top_level_index(text, " * ")
	if times_at <= 0:
		return ""
	var left: String = text.substr(0, times_at).strip_edges()
	var right: String = text.substr(times_at + 3).strip_edges()
	if right == "delta":
		return left
	if left == "delta":
		return right
	return ""


## S9. The axis a `velocity.x` style target names, or "" when the target is not one axis of the
## body's own velocity.
static func velocity_axis(target: String) -> String:
	var text: String = target.strip_edges().trim_prefix("self.")
	if not text.begins_with("velocity."):
		return ""
	var axis: String = text.substr(9)
	return axis if axis in ["x", "y", "z"] else ""


## S9. The movement math a hand-rolled controller is made of, in the movement behaviors' own words.
## Claimed only on a character body, and only where the whole shape is recognised: a `move_toward`
## that accelerates something else, or a rotation eased toward an angle without the frame time, keeps
## the code it is.
static func _movement_statement(text: String, context: Dictionary) -> Dictionary:
	if not is_character_body(context):
		return {}
	var object_name: String = script_object(context)
	var grows_at: int = top_level_index(text, " += ")
	if grows_at > 0:
		var grown: String = text.substr(0, grows_at).strip_edges().trim_prefix("self.")
		var pull: String = per_second_factor(text.substr(grows_at + 4))
		if grown == "velocity.y" and not pull.is_empty():
			return _sentence(object_name, "Apply gravity {gravity} (per second)",
				{"gravity": [expression_text(pull, context), "value"]})
	if text == "move_and_slide()" or text == "self.move_and_slide()":
		return _sentence(object_name, "Move (and slide along what it hits)", {})
	var call: Dictionary = call_parts(text)
	if not call.is_empty() and str(call.get("method", "")) == "add_collision_exception_with":
		var ignored: PackedStringArray = call.get("args", PackedStringArray())
		if ignored.size() == 1 and str(call.get("target", "")).strip_edges() in ["", "self"]:
			return _sentence(object_name, "Ignore collisions with {other}",
				{"other": [expression_text(ignored[0], context), "value"]})
	var assign_at: int = top_level_index(text, " = ")
	if assign_at <= 0:
		return {}
	var target: String = text.substr(0, assign_at).strip_edges().trim_prefix("self.")
	var value: String = text.substr(assign_at + 3).strip_edges()
	var axis: String = velocity_axis(target)
	if not axis.is_empty() and value.begins_with("move_toward(") and value.ends_with(")"):
		var toward: PackedStringArray = _split_arguments(value.substr(12, value.length() - 13))
		var rate: String = per_second_factor(toward[2]) if toward.size() == 3 else ""
		if toward.size() == 3 and toward[0].strip_edges().trim_prefix("self.") == target and not rate.is_empty():
			return _sentence(object_name, "Accelerate {axis} toward {target} at {rate} (per second)", {
				"axis": [axis, "name"],
				"target": [expression_text(toward[1], context), "value"],
				"rate": [expression_text(rate, context), "value"]
			})
	if target == "velocity" and value.begins_with("velocity.limit_length(") and value.ends_with(")"):
		var limit: String = value.substr(22, value.length() - 23).strip_edges()
		if not limit.is_empty():
			return _sentence(object_name, "Limit speed to {value}",
				{"value": [expression_text(limit, context), "value"]})
	if target == "rotation" and value.begins_with("lerp_angle(") and value.ends_with(")"):
		var eased: PackedStringArray = _split_arguments(value.substr(11, value.length() - 12))
		var turn_rate: String = per_second_factor(eased[2]) if eased.size() == 3 else ""
		if eased.size() == 3 and eased[0].strip_edges().trim_prefix("self.") == "rotation" and not turn_rate.is_empty():
			return _sentence(object_name, "Rotate toward {target} at {rate} (per second)", {
				"target": [expression_text(eased[1], context), "value"],
				"rate": [expression_text(turn_rate, context), "value"]
			})
	return {}


## S9. `c.get_collider().is_in_group("enemy")` - what a slide collision HIT, asked in the sheet's
## family words. The collision local is the object the row is about, exactly as the loop named it.
static func _collided_family_condition(text: String, context: Dictionary) -> Dictionary:
	const MIDDLE := ".get_collider().is_in_group("
	var split_at: int = text.find(MIDDLE)
	if split_at <= 0 or not text.ends_with(")"):
		return {}
	var receiver: String = text.substr(0, split_at).strip_edges()
	if not is_identifier(receiver):
		return {}
	var group: String = text.substr(
		split_at + MIDDLE.length(), text.length() - split_at - MIDDLE.length() - 1).strip_edges()
	if not _is_string_literal(group):
		return {}
	return _sentence(receiver, "collided object is in family {name}",
		{"name": [_unquote(group), "value"]})


## S10. The published name of a message - the function name as the picker would publish it.
static func message_name(function_name: String, context: Dictionary) -> String:
	var published: Dictionary = context.get("message_names", {})
	if published.has(function_name):
		return str(published[function_name])
	return function_words(function_name)


## S10. The muted note an `@rpc(...)` annotation reads as: its mode words in the order the annotation
## wrote them, separated the way the sheet separates a trigger's settings. "" when the annotation
## names no mode, which is Godot's own default and says nothing a reader could act on.
static func rpc_mode_words(annotation: String) -> String:
	var text: String = annotation.strip_edges()
	if not text.begins_with("@rpc"):
		return ""
	var open_at: int = text.find("(")
	if open_at < 0 or not text.ends_with(")"):
		return ""
	var words: PackedStringArray = PackedStringArray()
	for argument: String in _split_arguments(text.substr(open_at + 1, text.length() - open_at - 2)):
		var mode: String = _unquote(argument.strip_edges())
		if RPC_MODE_WORDS.has(mode):
			words.append(translate(str(RPC_MODE_WORDS[mode])))
	return " · ".join(words)


## S10. `take_damage.rpc(10)` and its two addressed twins, as the Send rows an event sheet writes.
## The payload rides as chips, named after the message's own parameters when the sheet knows them.
static func _multiplayer_statement(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if call.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	if method != "rpc" and method != "rpc_id":
		return {}
	var sent: String = str(call.get("target", "")).strip_edges()
	if not is_identifier(sent):
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	var payload: PackedStringArray = args
	var reading: Dictionary = {}
	if method == "rpc_id":
		if args.is_empty():
			return {}
		payload = args.slice(1)
		var peer: String = args[0].strip_edges()
		if peer == "1":
			reading = _sentence(OBJECT_MULTIPLAYER, "Send {name} to the host",
				{"name": [message_name(sent, context), "name"]})
		else:
			reading = _sentence(OBJECT_MULTIPLAYER, "Send {name} to {peer}", {
				"name": [message_name(sent, context), "name"],
				"peer": [expression_text(peer, context), "value"]
			})
	else:
		reading = _sentence(OBJECT_MULTIPLAYER, "Send {name} to everyone",
			{"name": [message_name(sent, context), "name"]})
	var names: PackedStringArray = (context.get("message_params", {}) as Dictionary).get(
		sent, PackedStringArray())
	for index: int in payload.size():
		var shown: String = expression_text(payload[index], context)
		if index < names.size():
			shown = "%s = %s" % [str(names[index]), shown]
		(reading["segments"] as Array).append({"text": "   ", "tone": "plain"})
		(reading["segments"] as Array).append({"text": shown, "tone": "chip"})
	return reading


## S10. The two questions Godot's high-level multiplayer answers, in the words the sheet's own
## Multiplayer object uses for them.
static func _multiplayer_condition(text: String, _context: Dictionary) -> Dictionary:
	if text == "multiplayer.is_server()":
		return _sentence(OBJECT_MULTIPLAYER, "Is host", {})
	if text == "is_multiplayer_authority()" or text == "self.is_multiplayer_authority()":
		return _sentence(OBJECT_MULTIPLAYER, "Owns this object", {})
	return {}


## S15. The place a nav target names. `player.global_position` is the object `player`, because the
## row already says the path is going TO it.
static func navigation_place(value: String, context: Dictionary) -> String:
	var text: String = value.strip_edges()
	for member: String in OWN_POSITION_NAMES:
		var suffix: String = ".%s" % member
		if text.ends_with(suffix) and is_identifier(text.substr(0, text.length() - suffix.length())):
			return text.substr(0, text.length() - suffix.length())
	return expression_text(text, context)


## S15. A NavigationAgent on a body, in the Pathfinding words: the destination, the step toward the
## next waypoint, and - when the file wires the avoidance callback - the note that says so.
static func _navigation_statement(text: String, context: Dictionary) -> Dictionary:
	var agents: Dictionary = context.get("nav_agents", {})
	if agents.is_empty():
		return {}
	var assign_at: int = top_level_index(text, " = ")
	if assign_at <= 0:
		return {}
	var object_name: String = script_object(context)
	var target: String = text.substr(0, assign_at).strip_edges().trim_prefix("self.")
	var value: String = text.substr(assign_at + 3).strip_edges()
	var dot_at: int = target.find(".")
	if dot_at > 0 and agents.has(target.substr(0, dot_at)) and target.substr(dot_at + 1) == "target_position":
		return _sentence(object_name, "Find path to {target}",
			{"target": [navigation_place(value, context), "value"]})
	if target != "velocity":
		return {}
	# `global_position.direction_to(next) * speed` - the one step a path walk is made of. Claimed only
	# when `next` is the waypoint the file itself read out of the agent.
	var times_at: int = top_level_index(value, " * ")
	if times_at <= 0:
		return {}
	var direction: String = value.substr(0, times_at).strip_edges()
	var speed: String = value.substr(times_at + 3).strip_edges()
	const TOWARD := ".direction_to("
	var toward_at: int = direction.find(TOWARD)
	if toward_at <= 0 or not direction.ends_with(")"):
		return {}
	if not OWN_POSITION_NAMES.has(direction.substr(0, toward_at).strip_edges()):
		return {}
	var waypoint: String = direction.substr(
		toward_at + TOWARD.length(), direction.length() - toward_at - TOWARD.length() - 1).strip_edges()
	if not (context.get("nav_waypoints", {}) as Dictionary).has(waypoint):
		return {}
	var template: String = "Move along path at {speed} (avoiding others)" if bool(
		context.get("nav_avoidance", false)) else "Move along path at {speed}"
	return _sentence(object_name, template, {"speed": [expression_text(speed, context), "value"]})


## S15. `agent.is_navigation_finished()` - the Pathfinding behavior's own arrival question, about the
## object that is walking rather than about the agent node that computed the path.
static func _navigation_condition(text: String, context: Dictionary) -> Dictionary:
	const TAIL := ".is_navigation_finished()"
	if not text.ends_with(TAIL):
		return {}
	var agent: String = text.substr(0, text.length() - TAIL.length()).strip_edges()
	if not (context.get("nav_agents", {}) as Dictionary).has(agent):
		return {}
	return _sentence(script_object(context), "Has arrived", {})


## The Godot-systems reading of one STATEMENT, or {} when none of the four patterns claims it.
static func godot_systems_statement(text: String, context: Dictionary) -> Dictionary:
	var loading: Dictionary = _background_loading_statement(text, context)
	if not loading.is_empty():
		return loading
	var message: Dictionary = _multiplayer_statement(text, context)
	if not message.is_empty():
		return message
	var navigation: Dictionary = _navigation_statement(text, context)
	if not navigation.is_empty():
		return navigation
	return _movement_statement(text, context)


## The Godot-systems reading of one CONDITION, or {} when none of the four patterns claims it.
static func godot_systems_condition(text: String, context: Dictionary) -> Dictionary:
	var loaded: Dictionary = _background_loading_condition(text, context)
	if not loaded.is_empty():
		return loaded
	var networked: Dictionary = _multiplayer_condition(text, context)
	if not networked.is_empty():
		return networked
	var arrived: Dictionary = _navigation_condition(text, context)
	if not arrived.is_empty():
		return arrived
	return _collided_family_condition(text, context)


# ── S11 / S12 / S13 / S14 - the sprite, UI, sound and juice words ───────────────────────────────
#
# Four families of line that most beginner scripts are made of, read in the words the sheet's own
# Sprite / Animation / UI / Audio objects and the Juice, Sine and Flash behaviors already publish.
# Each reading also NAMES the pattern it recognised (`pattern`, with the source line as its evidence
# and the pack that could replace the shape), which the row builder hands to the pattern registry -
# the grammar stays pure and knows nothing about sheets or rows.
#
# Strictness is unchanged: every one of these is claimed only at the exact shape, and a line the
# reading cannot say honestly keeps the property write it is.

## S11. The classes whose `frame` / `texture` are a sprite's, and the ones whose parameter paths are an
## animation tree's. Matched through ClassDB, so a subclass counts as its base.
const SPRITE_CLASSES: PackedStringArray = ["Sprite2D", "Sprite3D", "AnimatedSprite2D", "AnimatedSprite3D"]
const ANIMATION_TREE_CLASSES: PackedStringArray = ["AnimationTree"]

## S11. The head every AnimationTree parameter path starts with, and the one path that is a state
## machine rather than a value.
const ANIMATION_PARAMETER_HEAD := "parameters/"
const ANIMATION_PLAYBACK_PATH := "parameters/playback"

## S14. A bob is written on the object's OWN place, which is the one an event sheet just calls
## position.
const JUICE_OWN_POSITION: PackedStringArray = ["position", "global_position"]


## The reading with the pattern it recognised attached, for the row builder to claim. What each
## pattern is CALLED and which rows author it live with the claim (the row builder's own vocabulary
## table), so there is one place a chip's words come from. Display only: nothing here reaches
## emission, and an empty reading is returned untouched.
static func _with_pattern(reading: Dictionary, pattern: String, evidence: String,
		adoptable: String = "") -> Dictionary:
	if reading.is_empty():
		return reading
	reading["pattern"] = pattern
	reading["evidence"] = PackedStringArray([evidence.strip_edges()])
	reading["adoptable"] = adoptable
	return reading


## S11 / S13. The property writes a sprite or an audio player spells as one of its own verbs, or {}
## when the member is not one of these - which keeps the plain "Set X to Y".
##
##   sprite.frame = 3            sprite ▸ Set animation frame to 3
##   anim.speed_scale = 2.0      anim   ▸ Set animation speed to 2
##   sprite.texture = load(...)  sprite ▸ Set image to hero.png
##   sfx.pitch_scale = 1.1       sfx    ▸ Set pitch to 1.1
##   music.volume_db = linear_to_db(0.5)   music ▸ Set volume to 50%
static func media_assignment(object_name: String, object_class: String, member: String,
		owner_text: String, assigned: String, context: Dictionary) -> Dictionary:
	var value: String = assigned.strip_edges()
	var line: String = _member_line(owner_text, member, value)
	var sprite: bool = _class_is_any(object_class, SPRITE_CLASSES)
	var animation: bool = _class_is_any(object_class, ANIMATION_CLASSES)
	var audio: bool = _class_is_any(object_class, AUDIO_CLASSES)
	match member:
		"frame":
			if sprite:
				return _with_pattern(_sentence(object_name, "Set animation frame to {value}", {
					"value": [expression_text(value, context), "value"]}), "sprite_animation", line)
		"speed_scale":
			if animation:
				return _with_pattern(_sentence(object_name, "Set animation speed to {value}", {
					"value": [expression_text(value, context), "value"]}), "sprite_animation", line)
		"texture":
			if sprite:
				var image: String = _asset_file_name(value)
				if image.is_empty():
					return {}
				# The file name is CONTENT, not a name the spelling lens may respell: `jump.wav` read
				# through the name lens once came out as "jump's wav".
				return _with_pattern(_sentence(object_name, "Set image to {file}", {
					"file": [image, "plain"]}), "sprite_animation", line)
		"stream":
			if audio:
				var sound: String = _asset_file_name(value)
				if sound.is_empty():
					return {}
				return _with_pattern(_sentence(object_name, "Set sound to {file}", {
					"file": [sound, "plain"]}), "sound", line)
		"pitch_scale":
			if audio:
				return _with_pattern(_sentence(object_name, "Set pitch to {value}", {
					"value": [expression_text(value, context), "value"]}), "sound", line)
		"bus":
			if audio and _is_string_literal(value):
				return _with_pattern(_sentence(object_name, "Set bus to {bus}", {
					"bus": [_unquote(value), "name"]}), "sound", line)
		"volume_db":
			if audio:
				return _with_pattern(_volume_sentence(object_name, "Set volume to {value}", value, context),
					"sound", line)
	return {}


## S11 / S13. The FILE an image or a sound is set from, named the way a reader names it - the file
## itself, with the folders and the loading call that fetched it left off. "" when the value is not a
## literal path, which keeps the plain property write: an image chosen at runtime has no file to name.
static func _asset_file_name(value: String) -> String:
	var text: String = value.strip_edges()
	for head: String in ["load(", "preload("]:
		if text.begins_with(head) and text.ends_with(")") \
				and closing_paren(text, head.length() - 1) == text.length() - 1:
			text = text.substr(head.length(), text.length() - head.length() - 1).strip_edges()
			break
	if not _is_string_literal(text):
		return ""
	var path: String = _unquote(text.trim_prefix("&"))
	return path.substr(path.rfind("/") + 1)


## S11. `flip_h = dir < 0` - the mirror verb with the test that decides it, which is the whole of what
## the line does. Only a real TEST is claimed: a mirror set from another flag reads as the plain write
## it is, because "when muted" would say something the line does not.
static func _mirror_when(object_name: String, template: String, member: String, assigned: String,
		context: Dictionary) -> Dictionary:
	var test: String = assigned.strip_edges()
	if _comparison_parts(test).is_empty() and top_level_index(test, " == ") < 0 \
			and top_level_index(test, " != ") < 0:
		return {}
	return _with_pattern(_sentence(object_name, template, {
		"test": [comparison_symbols(expression_text(test, context)), "value"]}),
		"sprite_animation", _member_line("", member, test))


## The source line a member write came from, for the evidence a pattern claim carries.
static func _member_line(owner_text: String, member: String, value: String) -> String:
	var target: String = member if owner_text.is_empty() else "%s.%s" % [owner_text, member]
	return "%s = %s" % [target, value]


## S13 / S12. One loudness in the words a mixer uses: a plain fraction is the percentage a reader set,
## anything else is the 0-to-1 setting it is. `linear_to_db` is the conversion Godot needs and the
## reader does not, so it never appears in the sentence; a raw decibel number keeps its unit.
static func _volume_sentence(object_name: String, template: String, value: String,
		context: Dictionary, slots: Dictionary = {}) -> Dictionary:
	var level: String = _linear_volume(value)
	var values: Dictionary = slots.duplicate()
	if level.is_empty():
		values["value"] = [expression_text(value, context), "value"]
		return _sentence(object_name, "%s dB" % template, values)
	if level.is_valid_float():
		values["value"] = [_percent_words(level, context), "value"]
		return _sentence(object_name, template, values)
	values["value"] = [expression_text(level, context), "value"]
	var reading: Dictionary = _sentence(object_name, template, values)
	(reading["segments"] as Array).append({"text": " %s" % translate("(0 to 1)"), "tone": "muted"})
	return reading


## The 0-to-1 level inside a `linear_to_db(...)`, or "" when the value is not one.
static func _linear_volume(value: String) -> String:
	const HEAD := "linear_to_db("
	var text: String = value.strip_edges()
	if not text.begins_with(HEAD) or not text.ends_with(")"):
		return ""
	if closing_paren(text, HEAD.length() - 1) != text.length() - 1:
		return ""
	return text.substr(HEAD.length(), text.length() - HEAD.length() - 1).strip_edges()


## S14. The juice snippets written as an assignment: a camera shake, a sine bob and the squash that
## eases back to normal size. Each is claimed only at its exact shape, and each says the WHAT in the
## behavior's own words with the arithmetic as a muted note.
static func juice_assignment(object_name: String, object_class: String, member: String,
		owner_text: String, assigned: String, context: Dictionary) -> Dictionary:
	var value: String = assigned.strip_edges()
	var line: String = _member_line(owner_text, member, value)
	if member == "offset" and _class_is_any(object_class, CAMERA_CLASSES):
		var amount: String = _random_offset_amount(value)
		if amount.is_empty():
			return {}
		var shake: Dictionary = _sentence(object_name, "Shake by {amount}", {
			"amount": [expression_text(amount, context), "value"]})
		(shake["segments"] as Array).append({
			"text": " %s" % translate("random offset this tick"), "tone": "muted"})
		return _with_pattern(shake, "juice", line, "juice")
	if (member == "y" or member == "x") and JUICE_OWN_POSITION.has(owner_text):
		var wave: Array = _sine_wave_parts(value)
		if wave.is_empty():
			return {}
		# A bob is written on the script's OWN place, so the row belongs to that object by name - the
		# receiver here is the word `position`, which is not an object anybody could point at.
		var bob: Dictionary = _sentence(script_object(context), "Bob {axis}", {"axis": [member, "name"]})
		(bob["segments"] as Array).append({"text": " %s · %s %s · %s %s" % [
			translate("sine"), translate("magnitude"), number_words(str(wave[1])),
			number_words(str(wave[0])), translate("per second")], "tone": "muted"})
		return _with_pattern(bob, "juice", line, "sine")
	if member == "scale" and owner_text.is_empty():
		var rate: String = _ease_to_one_rate(value)
		if rate.is_empty():
			return {}
		var eased: Dictionary = _sentence(object_name, "Ease size back to normal at {rate}", {
			"rate": [expression_text(rate, context), "value"]})
		(eased["segments"] as Array).append({"text": " %s" % translate("per second"), "tone": "muted"})
		return _with_pattern(eased, "juice", line, "juice")
	return {}


## S14. The shake amount in `Vector2(randf_range(-s, s), randf_range(-s, s))`, or "" when the value is
## anything else. Both axes must be the SAME random range: a shake with two different amounts is two
## numbers, and printing one of them would be a lie.
static func _random_offset_amount(value: String) -> String:
	var text: String = value.strip_edges()
	var open_at: int = text.find("(")
	if open_at <= 0 or not text.ends_with(")"):
		return ""
	if not VECTOR_CONSTRUCTORS.has(text.substr(0, open_at)):
		return ""
	var axes: PackedStringArray = _split_arguments(text.substr(open_at + 1, text.length() - open_at - 2))
	if axes.size() < 2:
		return ""
	var amount: String = ""
	for axis: String in axes:
		var axis_amount: String = _symmetric_random_amount(axis.strip_edges())
		if axis_amount.is_empty():
			return ""
		if amount.is_empty():
			amount = axis_amount
		elif amount != axis_amount:
			return ""
	return amount


## The `s` in `randf_range(-s, s)`, or "" when the call is not that symmetric shape.
static func _symmetric_random_amount(text: String) -> String:
	const HEAD := "randf_range("
	if not text.begins_with(HEAD) or not text.ends_with(")"):
		return ""
	var arguments: PackedStringArray = _split_arguments(
		text.substr(HEAD.length(), text.length() - HEAD.length() - 1))
	if arguments.size() != 2:
		return ""
	var low: String = arguments[0].strip_edges()
	var high: String = arguments[1].strip_edges()
	if not low.begins_with("-"):
		return ""
	return high if low.substr(1).strip_edges() == high else ""


## S14. `base_y + sin(t * 3.0) * 8.0` as [frequency, magnitude], or [] when the value is not a bob.
static func _sine_wave_parts(value: String) -> Array:
	var plus_at: int = top_level_index(value, " + ")
	if plus_at <= 0:
		return []
	var wave: String = value.substr(plus_at + 3).strip_edges()
	var times_at: int = top_level_index(wave, " * ")
	if times_at <= 0:
		return []
	var sine: String = wave.substr(0, times_at).strip_edges()
	var magnitude: String = wave.substr(times_at + 3).strip_edges()
	const HEAD := "sin("
	if not sine.begins_with(HEAD) or not sine.ends_with(")"):
		return []
	var inner: String = sine.substr(HEAD.length(), sine.length() - HEAD.length() - 1).strip_edges()
	var rate_at: int = top_level_index(inner, " * ")
	if rate_at <= 0:
		return []
	return [inner.substr(rate_at + 3).strip_edges(), magnitude]


## S14. The `10` in `scale.lerp(Vector2.ONE, 10 * delta)`, or "" when the value eases somewhere other
## than back to normal size.
static func _ease_to_one_rate(value: String) -> String:
	const HEAD := "scale.lerp("
	var text: String = value.strip_edges()
	if not text.begins_with(HEAD) or not text.ends_with(")"):
		return ""
	var arguments: PackedStringArray = _split_arguments(
		text.substr(HEAD.length(), text.length() - HEAD.length() - 1))
	if arguments.size() != 2:
		return ""
	var destination: String = arguments[0].strip_edges()
	if destination != "Vector2.ONE" and destination != "Vector3.ONE":
		return ""
	var weight: String = arguments[1].strip_edges()
	var times_at: int = top_level_index(weight, " * ")
	if times_at <= 0 or weight.substr(times_at + 3).strip_edges() != "delta":
		return ""
	return weight.substr(0, times_at).strip_edges()


## S11 / S12 / S13. The calls these families spell as one of their own verbs, or {} to keep the
## ordinary Object ▸ Verb reading.
##
##   resume_button.grab_focus()          resume button ▸ Set focus
##   game_over.popup_centered()          game over ▸ Show dialog (centred)
##   music.seek(12.0)                    music ▸ Seek to 12 seconds
##   anim_tree.set("parameters/x", v)    anim tree ▸ Set blend x to v
##   anim_tree["parameters/playback"].travel("Hurt")   anim tree ▸ Travel to animation state Hurt
##   AudioServer.set_bus_volume_db(0, linear_to_db(v)) Audio ▸ Set master volume to v (0 to 1)
static func media_call(call: Dictionary, context: Dictionary) -> Dictionary:
	var method: String = str(call.get("method", ""))
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	var receiver: String = str(call.get("target", ""))
	var line: String = str(call.get("line", ""))
	if receiver == "AudioServer" and method == "set_bus_volume_db" and arguments.size() == 2:
		return _with_pattern(_bus_volume_sentence(arguments, context), "ui", line)
	var object_name: String = _receiver_object(receiver, context)
	var object_class: String = object_class_of(object_name, context)
	match method:
		"grab_focus":
			if arguments.is_empty():
				return _with_pattern(_sentence(object_name, "Set focus", {}), "ui", line)
		"popup_centered", "popup_centered_ratio", "popup_centered_clamped":
			var dialog: Dictionary = _sentence(object_name, "Show dialog", {})
			(dialog["segments"] as Array).append({"text": " %s" % translate("(centred)"), "tone": "muted"})
			return _with_pattern(dialog, "ui", line)
		"seek":
			if arguments.size() == 1 and _class_is_any(object_class, AUDIO_CLASSES):
				return _with_pattern(_sentence(object_name, "Seek to {seconds} seconds", {
					"seconds": [number_words(arguments[0].strip_edges()), "value"]}), "sound", line)
		"set":
			if arguments.size() == 2 and _class_is_any(object_class, ANIMATION_TREE_CLASSES):
				var blended: String = _animation_parameter_name(arguments[0])
				if not blended.is_empty():
					return _with_pattern(_sentence(object_name, "Set blend {name} to {value}", {
						"name": [blended, "name"],
						"value": [expression_text(arguments[1], context), "value"]}),
						"sprite_animation", line)
		"travel":
			if arguments.size() == 1:
				var machine: String = _animation_playback_receiver(receiver)
				if not machine.is_empty():
					return _with_pattern(_sentence(_receiver_object(machine, context),
						"Travel to animation state {state}", {
							"state": [_unquote(arguments[0].strip_edges()), "value"]}),
						"sprite_animation", line)
	return {}


## S12. `AudioServer.set_bus_volume_db(0, linear_to_db(v))` in the mixer's words. Bus 0 is the master
## bus every project has; a bus looked up by name says that name instead.
static func _bus_volume_sentence(arguments: PackedStringArray, context: Dictionary) -> Dictionary:
	var bus: String = arguments[0].strip_edges()
	if bus == "0":
		return _volume_sentence(OBJECT_AUDIO, "Set master volume to {value}", arguments[1], context)
	var named: String = _bus_index_name(bus)
	if named.is_empty():
		return {}
	return _volume_sentence(OBJECT_AUDIO, "Set {bus} volume to {value}", arguments[1], context,
		{"bus": [named, "name"]})


## The bus a `AudioServer.get_bus_index("SFX")` names, or "" when the index is computed some other way.
static func _bus_index_name(expression: String) -> String:
	const HEAD := "AudioServer.get_bus_index("
	var text: String = expression.strip_edges()
	if not text.begins_with(HEAD) or not text.ends_with(")"):
		return ""
	var inner: String = text.substr(HEAD.length(), text.length() - HEAD.length() - 1).strip_edges()
	return _unquote(inner) if _is_string_literal(inner) else ""


## S11. The blend name in `"parameters/blend_position"` - the last leg of the path, in words - or ""
## when the path is not a parameter path or names the state machine rather than a value.
static func _animation_parameter_name(argument: String) -> String:
	var text: String = argument.strip_edges()
	if not _is_string_literal(text):
		return ""
	var path: String = _unquote(text)
	if not path.begins_with(ANIMATION_PARAMETER_HEAD) or path == ANIMATION_PLAYBACK_PATH:
		return ""
	return path.substr(path.rfind("/") + 1).replace("_", " ")


## S11. The animation tree in `anim_tree["parameters/playback"]` - or in the `get(...)` spelling the
## sheet's own Travel To State row writes, where the tree is the object the row already acts on.
## "self" when the script IS the tree, "" when the receiver is anything else: a `travel` on something
## that is not a state machine keeps its own reading.
static func _animation_playback_receiver(receiver: String) -> String:
	var text: String = receiver.strip_edges()
	const GET_TAIL := ".get(\"%s\")" % ANIMATION_PLAYBACK_PATH
	if text == "get(\"%s\")" % ANIMATION_PLAYBACK_PATH:
		return "self"
	if text.ends_with(GET_TAIL):
		return text.substr(0, text.length() - GET_TAIL.length())
	var open_at: int = text.find("[")
	if open_at <= 0 or not text.ends_with("]"):
		return ""
	var key: String = text.substr(open_at + 1, text.length() - open_at - 2).strip_edges()
	if not _is_string_literal(key) or _unquote(key) != ANIMATION_PLAYBACK_PATH:
		return ""
	return text.substr(0, open_at)


## S11 / S13. "Is playing" - the one question a sprite, an animation player and an audio player all
## answer, whether the script asks it as a call or as a flag. {} for anything else.
static func media_condition(text: String, context: Dictionary) -> Dictionary:
	var bare: String = text.strip_edges()
	var receiver: String = ""
	if bare.ends_with(".is_playing()"):
		receiver = bare.substr(0, bare.length() - 13)
	elif bare.ends_with(".playing"):
		receiver = bare.substr(0, bare.length() - 8)
	if receiver.is_empty() or not is_identifier(receiver):
		return {}
	var object_name: String = _receiver_object(receiver, context)
	var object_class: String = object_class_of(object_name, context)
	var audio: bool = _class_is_any(object_class, AUDIO_CLASSES)
	# U12. A video answers the same question, and it answers it under the Video object every one of
	# its other rows belongs to.
	if _class_is_any(object_class, VIDEO_CLASSES):
		return _with_pattern(_sentence(OBJECT_VIDEO, "Is playing", {}), "ui", bare)
	if not audio and not _class_is_any(object_class, ANIMATION_CLASSES) \
			and not _class_is_any(object_class, SPRITE_CLASSES):
		return {}
	return _with_pattern(_sentence(object_name, "Is playing", {}), "sound" if audio else "sprite_animation", bare)


# ── T1 / T2 / T3 / T4: the hand-rolled BEHAVIOR shapes ────────────────────────────────────────────
# A projectile, a turret, a glide, a spin, a wrap, a clamp, a pin and a fade are each a behavior that
# already ships as a pack, and the pack's words are what the arithmetic is doing. The recognisers
# live in their own file (EventSheetBehaviorShapes) because each is a SHAPE rather than a statement;
# these three functions are the whole of their contact with the grammar, so nothing already settled
# here can move and the readings can be pinned on their own.


## The one sentence a behavior shape reads as, with the behavior's name as the row's chip. Public so
## the shape readings can build a row exactly as the behaviour readings above do.
static func behaviour_sentence_of(object_name: String, chip: String, template: String,
		values: Dictionary) -> Dictionary:
	return _behaviour_sentence(object_name, chip, template, values)


## The behavior-shape reading of one STATEMENT, or {} when no shape claims it.
static func behavior_shape_statement(text: String, context: Dictionary) -> Dictionary:
	return EventSheetBehaviorShapes.statement(text, context)


## The behavior-shape reading of one CONDITION, or {} when no shape claims it.
static func behavior_shape_condition(text: String, context: Dictionary) -> Dictionary:
	return EventSheetBehaviorShapes.condition(text, context)
# ── U6 / U7 - web requests and lights ───────────────────────────────────────────────────────────
#
# Two families of line a finished game has and a first script does not: a request to a server, and
# the lights a scene is lit with. Each reads in the words the sheet's own objects publish - the AJAX
# and JSON objects a reader coming from another event-sheet editor already knows, and the Light
# rows - and each claims the pattern it is an instance of.
#
# Same strictness as every reading above: the exact shape or nothing. `request` and `energy` are
# ordinary words that live on plenty of other classes, so both families are gated on the receiver's
# KNOWN class and a line whose object the sheet cannot name keeps the property write it is.


## U6. The node class whose `request` is a web request.
const HTTP_CLASSES: PackedStringArray = ["HTTPRequest"]

## U6. Both spellings of the POST verb a request's method argument may be written with.
const HTTP_POST_METHODS: PackedStringArray = ["HTTPClient.METHOD_POST", "METHOD_POST"]

## U6. Both spellings of the constant a finished request's result is compared against.
const HTTP_SUCCESS_CONSTANTS: PackedStringArray = ["HTTPRequest.RESULT_SUCCESS", "RESULT_SUCCESS"]


## U6. The two AJAX steps: `http.request(url)` asks a server for something, and the same call carrying
## the POST verb and a body sends something to it. What a post SENDS is what a reader wants first and
## where it goes second, which is why the two have different sentences rather than one with a note.
static func web_call(call: Dictionary, context: Dictionary) -> Dictionary:
	var method: String = str(call.get("method", ""))
	if method != "request" and method != "request_raw":
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if args.is_empty():
		return {}
	var object_name: String = _receiver_object(str(call.get("target", "")), context)
	if not _class_is_any(object_class_of(object_name, context), HTTP_CLASSES):
		return {}
	var line: String = str(call.get("line", ""))
	var url: String = expression_text(args[0], context)
	if args.size() < 3:
		return _with_pattern(_sentence(OBJECT_AJAX, "Request {url}", {"url": [url, "value"]}), "ajax", line)
	# A request that names a verb reads as a post only when the verb IS post. Any other verb is a shape
	# this reading has no sentence for, so the line keeps the call it is rather than being renamed.
	if not HTTP_POST_METHODS.has(args[2].strip_edges()):
		return {}
	if args.size() < 4:
		return _with_pattern(_sentence(OBJECT_AJAX, "Post to {url}", {"url": [url, "value"]}), "ajax", line)
	return _with_pattern(_sentence(OBJECT_AJAX, "Post {data} to {url}", {
		"data": [expression_text(args[3], context), "value"],
		"url": [url, "value"]
	}), "ajax", line)


## U6. `result != HTTPRequest.RESULT_SUCCESS` is the sheet's request-succeeded question asked the
## other way round, so it reads as that question with `not` in front of it - which the canvas draws as
## the ✕ every inverted condition already carries. Only a bare name on the left is claimed: a result
## worked out from something else is not the answer this question is about.
static func web_condition(text: String, context: Dictionary) -> Dictionary:
	var bare: String = text.strip_edges()
	for operator: String in [" == ", " != "]:
		var at: int = top_level_index(bare, operator)
		if at <= 0:
			continue
		if not HTTP_SUCCESS_CONSTANTS.has(bare.substr(at + operator.length()).strip_edges()):
			continue
		if not is_identifier(bare.substr(0, at).strip_edges()):
			continue
		var asked: Dictionary = _sentence(OBJECT_AJAX, "request succeeded", {})
		if operator == " == ":
			return _with_pattern(asked, "ajax", bare)
		var negated: Array = [{"text": "%s " % translate("not"), "tone": "plain"}]
		negated.append_array(asked.get("segments", []) as Array)
		return _with_pattern({"object": OBJECT_AJAX, "segments": negated}, "ajax", bare)
	return {}


## U7. The classes whose knobs read as the sheet's Light rows, in both node generations.
const LIGHT_CLASSES: PackedStringArray = ["Light2D", "Light3D"]

## U7. The two spellings each light knob has: a 2D light says `energy` and `color`, a 3D one says
## `light_energy` and `light_color`, and both mean the one row.
const LIGHT_ENERGY_MEMBERS: PackedStringArray = ["energy", "light_energy"]
const LIGHT_COLOUR_MEMBERS: PackedStringArray = ["color", "light_color"]

## U7. The class a whole layer's tint is written on, and the environment member the world's ambient
## light is. Neither belongs to a light anybody can point at, so both read under System.
const LAYER_TINT_CLASSES: PackedStringArray = ["CanvasModulate"]
const AMBIENT_LIGHT_MEMBER := "ambient_light_energy"


## U7. The light knobs, in the words the sheet's own Light rows publish. Brightness is a percentage,
## because that is how a reader sets it and how every other 0-to-1 setting on the sheet already reads.
static func lighting_assignment(object_name: String, object_class: String, member: String,
		owner_text: String, assigned: String, context: Dictionary) -> Dictionary:
	var value: String = assigned.strip_edges()
	var line: String = _member_line(owner_text, member, value)
	# A whole layer's tint and the world's ambient light are settings of the LAYOUT, so they read
	# under System exactly as the other layout rows do, with Godot's own spelling one hover away.
	if member == "color" and _class_is_any(object_class, LAYER_TINT_CLASSES):
		var tint: Dictionary = _sentence(OBJECT_SYSTEM, "Set layer tint to {value}",
			{"value": [expression_text(value, context), "value"]})
		(tint["segments"] as Array).append({"text": " %s" % _class_note(object_class), "tone": "muted"})
		return _with_pattern(tint, "lighting", line)
	if member == AMBIENT_LIGHT_MEMBER and owner_text.ends_with("environment"):
		return _with_pattern(_sentence(OBJECT_SYSTEM, "Set ambient light to {value}",
			{"value": [_percent_words(value, context), "value"]}), "lighting", line)
	if not _class_is_any(object_class, LIGHT_CLASSES):
		return {}
	if LIGHT_ENERGY_MEMBERS.has(member):
		return _with_pattern(_sentence(object_name, "Set light energy to {value}",
			{"value": [_percent_words(value, context), "value"]}), "lighting", line)
	if LIGHT_COLOUR_MEMBERS.has(member):
		return _with_pattern(_sentence(object_name, "Set light colour to {value}",
			{"value": [expression_text(value, context), "value"]}), "lighting", line)
	if member == "enabled" and (value == "true" or value == "false"):
		return _with_pattern(_sentence(object_name,
			"Set light on" if value == "true" else "Set light off", {}), "lighting", line)
	if member == "shadow_enabled" and (value == "true" or value == "false"):
		return _with_pattern(_sentence(object_name,
			"Set shadows on" if value == "true" else "Set shadows off", {}), "lighting", line)
	return {}


## Godot's own spelling for a row whose sentence renamed it, said quietly after the words. Never
## translated: it is the class name the engine uses, which is exactly what makes it useful here.
static func _class_note(object_class: String) -> String:
	return object_class.strip_edges()


# ── U8 / U9 / U10 / U11 / U12 - 3D, background work, signals, functions, media ──────────────────
#
# The rest of the long tail. Every one of these is a line a finished game writes and a first script
# does not, and every one of them already HAS a sentence somewhere on the sheet - the FPS Controller
# pack's mouse look, Run In Background's one word for work handed off the main thread, the Wire /
# Unwire pair for the signal steps that are actions rather than events, the Call row's own words for
# a call made by name, and the Video object's verbs. The readings here say those sentences.


## U8. The behavior whose words the mouse-look block is already written in, so a reader offered an
## adoption is offered the pack that ships the shape rather than a rewrite of it.
const FPS_LOOK_PACK := "fps_controller"

## U8. The three directions an object's own axes point in, by the basis member each one is. `-z` is
## forward because that is the way Godot's cameras face; the sheet says the direction, not the axis.
const BASIS_DIRECTION_WORDS: Dictionary = {
	"-basis.z": "forward", "basis.x": "right", "basis.y": "up"
}

## U8. The transforms a basis may be reached through. Both spellings name the same three directions.
const BASIS_TRANSFORMS: PackedStringArray = ["global_transform", "transform"]

## U9. The behavior whose sentence a hand-written thread is already written in.
const BACKGROUND_PACK := "background_runner"

## U9. The pool the engine keeps for short jobs, and the two waits that join a job back up.
const WORKER_POOL := "WorkerThreadPool"
const WORKER_WAITS: PackedStringArray = ["wait_for_task_completion", "wait_for_group_task_completion"]

## U10. The connection flag whose whole meaning is WHEN the handler runs.
const DEFERRED_CONNECT_FLAGS: PackedStringArray = ["CONNECT_DEFERRED", "Object.CONNECT_DEFERRED"]

## U12. A video player is the sheet's Video object, whatever the node in the scene is called - the
## same way every save row is Local Storage's whichever file it writes.
const OBJECT_VIDEO := "Video"

## U12. The class whose stream, play and finished are the Video object's.
const VIDEO_CLASSES: PackedStringArray = ["VideoStreamPlayer"]

## U12. The two classes a sound is heard FROM a place in, and the two knobs that say how far it
## carries. A non-positional player has neither, which is why the pair is gated on the class.
const POSITIONAL_AUDIO_CLASSES: PackedStringArray = ["AudioStreamPlayer2D", "AudioStreamPlayer3D"]


## U8. `look_at(p, Vector3.UP)` - the one 3D call whose whole meaning is "face that". The up vector is
## Godot's bookkeeping, not part of what the row says, and a place belongs to the object whose place
## it is, so `target.global_position` reads as `target`.
##
## The UP VECTOR is what says this is the 3D call: a one-argument `look_at(p)` turns a 2D object to an
## angle, which is a different sentence the sheet already has (`Set angle toward p`), so only the
## two-argument spelling is claimed here.
static func spatial_call(call: Dictionary, context: Dictionary) -> Dictionary:
	if str(call.get("method", "")) != "look_at":
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if args.size() != 2:
		return {}
	var receiver: String = str(call.get("target", "")).strip_edges()
	if not receiver.is_empty() and not is_simple_target(receiver):
		return {}
	var object_name: String = _receiver_object(receiver, context)
	return _with_pattern(_sentence(object_name, "Look at {place}", {
		"place": [_place_owner(args[0], context), "value"]}), "fps_look", str(call.get("line", "")),
		FPS_LOOK_PACK)


## U8. The object a PLACE belongs to: an event-sheet object has a position, so `target.global_position`
## is just `target`. A place that is not an object's own keeps the expression it is.
static func _place_owner(value: String, context: Dictionary) -> String:
	var text: String = value.strip_edges()
	for place: String in OWN_POSITION_NAMES:
		var suffix: String = ".%s" % place
		if not text.ends_with(suffix):
			continue
		var owner_text: String = text.substr(0, text.length() - suffix.length()).strip_edges()
		if is_simple_target(owner_text):
			return object_of_reference(owner_text)
	return expression_text(text, context)


## U8. `-global_transform.basis.z` as the direction it IS. Whole-expression only: a basis member in
## the middle of a longer sum is arithmetic a reader follows as arithmetic, and renaming half of it
## would leave a sentence nobody could check against the code.
static func basis_direction_words(text: String, context: Dictionary) -> String:
	var bare: String = text.strip_edges()
	for suffix: String in BASIS_DIRECTION_WORDS.keys():
		var tail: String = str(suffix)
		var negated: bool = tail.begins_with("-")
		var member: String = tail.trim_prefix("-")
		var head: String = bare.substr(1).strip_edges() if negated and bare.begins_with("-") else bare
		if negated != bare.begins_with("-"):
			continue
		var owner_text: String = _basis_owner(head, member)
		if owner_text.is_empty():
			continue
		var object_name: String = script_object(context) if owner_text == "self" \
			else object_of_reference(owner_text)
		return "%s's %s" % [object_name, translate(str(BASIS_DIRECTION_WORDS[suffix]))]
	return ""


## U8. The object a `<owner>.<transform>.basis.<axis>` read belongs to - "self" when the script wrote
## it about its own axes - or "" when the text is not that read at all.
static func _basis_owner(text: String, member: String) -> String:
	for transform: String in BASIS_TRANSFORMS:
		var tail: String = "%s.%s" % [transform, member]
		if text == tail:
			return "self"
		if text.ends_with(".%s" % tail):
			var owner_text: String = text.substr(0, text.length() - tail.length() - 1).strip_edges()
			if is_simple_target(owner_text):
				return owner_text
	if text == member:
		return "self"
	return ""


## U9. The steps that hand work to a thread, and the ones that wait for it back. Both the plain Thread
## spelling and the worker pool's read as the one sentence the Run In Background behavior publishes,
## because what a reader needs to know is the same in both: which function left the main thread.
static func background_statement(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if call.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	var receiver: String = str(call.get("target", "")).strip_edges()
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if receiver == WORKER_POOL:
		if WORKER_WAITS.has(method) and args.size() <= 1:
			return _with_pattern(_background_wait(), "background", text, BACKGROUND_PACK)
		if method == "add_task" and args.size() >= 1:
			return _background_run(args[0], "", context, text)
		if method == "add_group_task" and args.size() >= 2:
			return _background_run(args[0], args[1].strip_edges(), context, text)
		return {}
	if not is_identifier(receiver):
		return {}
	# `wait_to_finish` is a Thread's and nothing else's, so the name alone says what the row is.
	if method == "wait_to_finish" and args.is_empty():
		return _with_pattern(_background_wait(), "background", text, BACKGROUND_PACK)
	# `start` is not: plenty of objects start. A bound callable is what says the argument is WORK
	# rather than a number, so only that spelling is claimed on an ordinary receiver.
	if method != "start" or args.size() != 1 or not args[0].contains(".bind("):
		return {}
	return _background_run(args[0], "", context, text)


## U9. The one sentence for waiting on work that left the main thread, with the hourglass every wait
## on the sheet already carries.
static func _background_wait() -> Dictionary:
	var reading: Dictionary = _sentence(OBJECT_SYSTEM, "Wait for it to finish", {})
	(reading["segments"] as Array).insert(0, {"text": "⏳ ", "tone": "plain"})
	return reading


## U9. `Run <verb> in the background`, with the count a group job repeats and one chip per value the
## job was handed. The chips are named by the CALLEE's own parameter names when the sheet knows them,
## exactly as a signal's payload chips are.
static func _background_run(callable_value: String, count: String, context: Dictionary,
		line: String) -> Dictionary:
	var bound: Dictionary = _bound_callable_parts(callable_value)
	if bound.is_empty():
		return {}
	var function_name: String = str(bound.get("name", ""))
	var reading: Dictionary = _sentence(OBJECT_SYSTEM, "Run {name} in the background",
		{"name": [function_words(function_name), "name"]})
	var segments: Array = reading.get("segments", [])
	if not count.is_empty():
		segments.append({"text": " ", "tone": "plain"})
		segments.append({"text": expression_text(count, context), "tone": "value"})
		segments.append({"text": " %s" % translate("times"), "tone": "plain"})
	for chip: String in _bound_argument_chips(function_name, bound.get("args", PackedStringArray()), context):
		segments.append({"text": "   ", "tone": "plain"})
		segments.append({"text": chip, "tone": "chip"})
	return _with_pattern(reading, "background", line, BACKGROUND_PACK)


## A callable written as a function name, with or without the values bound to it, as
## {"name", "args"} - or {} when the value is not a callable this grammar can name.
static func _bound_callable_parts(value: String) -> Dictionary:
	var text: String = value.strip_edges().trim_prefix("self.")
	if is_identifier(text):
		return {"name": text, "args": PackedStringArray()}
	const BIND := ".bind("
	if not text.ends_with(")"):
		return {}
	var bind_at: int = text.rfind(BIND)
	if bind_at <= 0 or closing_paren(text, bind_at + BIND.length() - 1) != text.length() - 1:
		return {}
	var head: String = text.substr(0, bind_at).strip_edges().trim_prefix("self.")
	if not is_identifier(head):
		return {}
	return {
		"name": head,
		"args": _split_arguments(
			text.substr(bind_at + BIND.length(), text.length() - bind_at - BIND.length() - 1))
	}


## The chips a bound call shows: `amount = 5` where the sheet knows the callee's parameter names, and
## the bare value where it does not. Never a guessed name - an unnamed chip is honest, a wrong one is not.
static func _bound_argument_chips(function_name: String, args: PackedStringArray,
		context: Dictionary) -> PackedStringArray:
	var declared: Variant = (context.get("function_params", {}) as Dictionary).get(function_name, PackedStringArray())
	var names: PackedStringArray = PackedStringArray()
	if declared is PackedStringArray:
		names = declared
	elif declared is Array:
		for entry: Variant in (declared as Array):
			names.append(str(entry))
	var chips: PackedStringArray = PackedStringArray()
	for index: int in range(args.size()):
		var shown: String = expression_text(args[index], context)
		chips.append("%s = %s" % [names[index], shown] if index < names.size() else shown)
	return chips


## U10. Wiring a handler up and taking it down are ACTIONS, not events, and the sheet's word pair for
## them is Wire / Unwire. A deferred connection says WHEN the handler runs as a chip, because that is
## the whole of what the flag changes.
static func signal_wiring_statement(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if call.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	if method != "connect" and method != "disconnect":
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if args.is_empty() or args.size() > 2:
		return {}
	var wired: Dictionary = _signal_reference(str(call.get("target", "")), context)
	if wired.is_empty():
		return {}
	var handler: Dictionary = _bound_callable_parts(args[0])
	if handler.is_empty():
		return {}
	var template: String = "Wire {signal} to {handler}" if method == "connect" \
		else "Unwire {signal} from {handler}"
	var reading: Dictionary = _sentence(str(wired.get("object", "")), template, {
		"signal": [str(wired.get("trigger", "")), "name"],
		"handler": [function_words(str(handler.get("name", ""))), "name"]
	})
	var segments: Array = reading.get("segments", [])
	for chip: String in _bound_argument_chips(str(handler.get("name", "")),
			handler.get("args", PackedStringArray()), context):
		segments.append({"text": "   ", "tone": "plain"})
		segments.append({"text": chip, "tone": "chip"})
	if method == "connect" and args.size() == 2:
		if not DEFERRED_CONNECT_FLAGS.has(args[1].strip_edges()):
			return {}
		segments.append({"text": "   ", "tone": "plain"})
		segments.append({"text": translate("at end of frame"), "tone": "chip"})
	return reading


## U10. `died.is_connected(_on_died)` - the same words the Wire row uses, asked as a question.
static func signal_wiring_condition(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text.strip_edges())
	if call.is_empty() or str(call.get("method", "")) != "is_connected":
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if args.size() != 1:
		return {}
	var wired: Dictionary = _signal_reference(str(call.get("target", "")), context)
	var handler: Dictionary = _bound_callable_parts(args[0])
	if wired.is_empty() or handler.is_empty():
		return {}
	return _sentence(str(wired.get("object", "")), "{signal} is wired to {handler}", {
		"signal": [str(wired.get("trigger", "")), "name"],
		"handler": [function_words(str(handler.get("name", ""))), "name"]
	})


## U10. The signal a receiver names, as {"object", "trigger"} - the object it belongs to and the
## trigger name a reader sees in the picker - or {} when the receiver does not name one.
static func _signal_reference(receiver: String, context: Dictionary) -> Dictionary:
	var text: String = receiver.strip_edges().trim_prefix("self.")
	if text.is_empty():
		return {}
	var owner_text: String = ""
	var signal_name: String = text
	var dot_at: int = text.rfind(".")
	if dot_at > 0:
		owner_text = text.substr(0, dot_at).strip_edges()
		signal_name = text.substr(dot_at + 1).strip_edges()
		if not is_simple_target(owner_text):
			return {}
	if not is_identifier(signal_name):
		return {}
	var object_name: String = script_object(context) if owner_text.is_empty() \
		else object_of_reference(owner_text)
	return {"object": object_name, "trigger": trigger_name_of(signal_name, context)}


## U10. `sig.emit(10)` where `sig` is a variable holding a signal: an event sheet FIRES the signal a
## name holds, and the name is the whole of what it can say - which signal it is was decided wherever
## the variable was filled in. Gated on the sheet's own declared type, never guessed.
static func stored_signal_statement(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text.strip_edges())
	if call.is_empty() or str(call.get("method", "")) != "emit":
		return {}
	var holder: String = str(call.get("target", "")).strip_edges().trim_prefix("self.")
	if not is_identifier(holder):
		return {}
	if str((context.get("variable_types", {}) as Dictionary).get(holder, "")) != "Signal":
		return {}
	var reading: Dictionary = _sentence(OBJECT_SYSTEM, "Fire {name}", {"name": [holder, "name"]})
	var segments: Array = reading.get("segments", [])
	for value: String in (call.get("args", PackedStringArray()) as PackedStringArray):
		segments.append({"text": "   ", "tone": "plain"})
		segments.append({"text": expression_text(value, context), "tone": "chip"})
	return reading


## U11. `call("heal", 5)` and `callv("heal", [5, self])` - the same Call row every other call reads
## as, with the muted note that says how it was reached. Only a LITERAL name is claimed: a name worked
## out at run time names no function this row could print.
static func call_by_name_statement(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text.strip_edges())
	if call.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	if method != "call" and method != "callv":
		return {}
	if not str(call.get("target", "")).strip_edges().trim_prefix("self.").is_empty():
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if args.is_empty() or not _is_string_literal(args[0]):
		return {}
	var function_name: String = _unquote(args[0].strip_edges().trim_prefix("&"))
	if not is_identifier(function_name):
		return {}
	var values: PackedStringArray = PackedStringArray()
	if method == "call":
		values = args.slice(1)
	elif args.size() == 2:
		var listed: String = args[1].strip_edges()
		if not listed.begins_with("[") or not listed.ends_with("]"):
			return {}
		values = _split_arguments(listed.substr(1, listed.length() - 2))
	elif args.size() > 2:
		return {}
	var reading: Dictionary = _sentence(OBJECT_FUNCTIONS, "Call {name}",
		{"name": [function_words(function_name), "name"]})
	var segments: Array = reading.get("segments", [])
	for chip: String in _bound_argument_chips(function_name, values, context):
		segments.append({"text": "   ", "tone": "plain"})
		segments.append({"text": chip, "tone": "chip"})
	segments.append({"text": " %s" % translate(
		"by name" if method == "call" else "by name, with a list"), "tone": "muted"})
	return reading


## U11. `Callable(self, "heal")` as the value it is - the function itself, under the name the sheet
## calls it by. "" for every other spelling, which keeps the expression exactly as written.
static func callable_value_words(text: String) -> String:
	const HEAD := "Callable("
	var bare: String = text.strip_edges()
	if not bare.begins_with(HEAD) or not bare.ends_with(")"):
		return ""
	if closing_paren(bare, HEAD.length() - 1) != bare.length() - 1:
		return ""
	var args: PackedStringArray = _split_arguments(bare.substr(HEAD.length(), bare.length() - HEAD.length() - 1))
	if args.size() != 2 or not _is_string_literal(args[1]):
		return ""
	var function_name: String = _unquote(args[1].strip_edges().trim_prefix("&"))
	if not is_identifier(function_name):
		return ""
	return "%s %s" % [translate("the function"), function_words(function_name)]


## U12. The video and positional-sound knobs, in the words their own objects publish. A video player
## is the Video object; how far a sound carries is a hearing distance and how fast it fades is a
## falloff, which are the two words a reader sets them by.
static func long_tail_media_assignment(object_name: String, object_class: String, member: String,
		owner_text: String, assigned: String, context: Dictionary) -> Dictionary:
	var value: String = assigned.strip_edges()
	var line: String = _member_line(owner_text, member, value)
	if member == "stream" and _class_is_any(object_class, VIDEO_CLASSES):
		var film: String = _asset_file_name(value)
		if film.is_empty():
			return {}
		return _with_pattern(_sentence(OBJECT_VIDEO, "Set video to {file}", {"file": [film, "plain"]}),
			"ui", line)
	if not _class_is_any(object_class, POSITIONAL_AUDIO_CLASSES):
		return {}
	if member == "max_distance":
		return _with_pattern(_sentence(object_name, "Set hearing distance to {value}",
			{"value": [expression_text(value, context), "value"]}), "sound", line)
	if member == "attenuation" or member == "unit_size":
		return _with_pattern(_sentence(object_name, "Set falloff to {value}",
			{"value": [expression_text(value, context), "value"]}), "sound", line)
	return {}


## U12. A video player's verbs, under the Video object every one of its rows belongs to.
static func long_tail_media_call(call: Dictionary, context: Dictionary) -> Dictionary:
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if not args.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	if method != "play" and method != "pause" and method != "stop":
		return {}
	var object_name: String = _receiver_object(str(call.get("target", "")), context)
	if not _class_is_any(object_class_of(object_name, context), VIDEO_CLASSES):
		return {}
	var verb: String = "Play"
	if method == "pause":
		verb = "Pause"
	elif method == "stop":
		verb = "Stop"
	return _with_pattern(_sentence(OBJECT_VIDEO, verb, {}), "ui", str(call.get("line", "")))


## U8. `rotate_y(-event.relative.x * sens)` as {"amount"} - the body's half of a mouse look - or {}
## when the line turns nothing. A receiver is allowed: plenty of scripts turn a pivot rather than the
## body itself.
static func mouse_look_turn_parts(text: String) -> Dictionary:
	var call: Dictionary = call_parts(text.strip_edges())
	if call.is_empty() or str(call.get("method", "")) != "rotate_y":
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if args.size() != 1:
		return {}
	return {"amount": args[0].strip_edges(), "object": str(call.get("target", "")).strip_edges()}


## U8. `cam.rotate_x(-event.relative.y * sens)` as {"camera", "amount"} - the camera's half - or {}.
## The camera must be NAMED: a look that pitches the body itself is a different shape.
static func mouse_look_pitch_parts(text: String) -> Dictionary:
	var call: Dictionary = call_parts(text.strip_edges())
	if call.is_empty() or str(call.get("method", "")) != "rotate_x":
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	var camera: String = str(call.get("target", "")).strip_edges()
	if args.size() != 1 or not is_simple_target(camera) or camera.is_empty():
		return {}
	return {"camera": camera, "amount": args[0].strip_edges()}


## U8. The `1.2` in `cam.rotation.x = clamp(cam.rotation.x, -1.2, 1.2)`, or "" when the line is not
## that clamp on that camera. Only a SYMMETRIC clamp is claimed: two different limits are two numbers,
## and printing one of them as `±` would be a lie.
static func mouse_look_clamp_limit(text: String, camera: String) -> String:
	var bare: String = text.strip_edges()
	var head: String = "%s.rotation.x" % camera
	var at: int = top_level_index(bare, " = ")
	if at <= 0 or bare.substr(0, at).strip_edges() != head:
		return ""
	var call: Dictionary = call_parts(bare.substr(at + 3).strip_edges())
	if call.is_empty() or not str(call.get("target", "")).is_empty():
		return ""
	if str(call.get("method", "")) != "clamp" and str(call.get("method", "")) != "clampf":
		return ""
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if args.size() != 3 or args[0].strip_edges() != head:
		return ""
	var low: String = args[1].strip_edges()
	var high: String = args[2].strip_edges()
	if not low.begins_with("-") or low.substr(1).strip_edges() != high:
		return ""
	return high


## U8. What the muted note beside a Mouse look row says: how far the turn goes, which object the
## up-and-down happens on, and how far it may go. The pieces are the file's own values, so a reader
## can check the row against the code without opening it.
static func mouse_look_note(turn: Dictionary, pitch: Dictionary, clamp_limit: String,
		context: Dictionary) -> String:
	var pieces: PackedStringArray = PackedStringArray([
		"%s %s" % [translate("turn by"), expression_text(str(turn.get("amount", "")), context)],
		"%s %s" % [translate("look up/down on"), object_of_reference(str(pitch.get("camera", "")))]
	])
	if not clamp_limit.is_empty():
		pieces.append("%s ±%s" % [translate("clamped"), clamp_limit])
	return ", ".join(pieces)


## U12. Two adjacent volume writes driven by ONE fraction as {"text"} - the crossfade they are - or
## {} when they are two unrelated volumes. `1 - t` on one fader and `t` on the other is the whole of
## what makes it one action, in either order.
static func crossfade_parts(first: String, second: String, context: Dictionary) -> Dictionary:
	var down: Dictionary = _volume_write_parts(first)
	var up: Dictionary = _volume_write_parts(second)
	if down.is_empty() or up.is_empty():
		return {}
	var fading_in: String = str(up.get("level", ""))
	if fading_in.is_empty() or _one_minus_of(str(down.get("level", ""))) != fading_in:
		return {}
	return {"text": _fill(translate("Crossfade {from} → {to} by {amount}"), {
		"from": _spaced_name(str(down.get("object", ""))),
		"to": _spaced_name(str(up.get("object", ""))),
		"amount": expression_text(fading_in, context)
	})}


## A snake_case name as the words it is - `music_a` is `music a`. An event sheet names a thing the
## way a person says it; the underscore is a language's spelling of a space.
static func _spaced_name(identifier: String) -> String:
	return identifier.strip_edges().replace("_", " ")


## U12. `music_a.volume_db = linear_to_db(1.0 - t)` as {"object", "level"}, or {} for any other line.
## The conversion is Godot's and never part of what a row says, so a raw decibel write is not one of
## these: two numbers on a scale a reader does not set by hand cannot be a crossfade.
static func _volume_write_parts(text: String) -> Dictionary:
	var bare: String = text.strip_edges()
	var at: int = top_level_index(bare, " = ")
	if at <= 0:
		return {}
	var target: String = bare.substr(0, at).strip_edges().trim_prefix("self.")
	if not target.ends_with(".volume_db"):
		return {}
	var object_text: String = target.substr(0, target.length() - 10).strip_edges()
	if not is_simple_target(object_text) or object_text.is_empty():
		return {}
	var level: String = _linear_volume(bare.substr(at + 3).strip_edges())
	if level.is_empty():
		return {}
	return {"object": object_text, "level": level}


## U12. The `t` in `1.0 - t`, or "" when the value is not one minus something.
static func _one_minus_of(value: String) -> String:
	var at: int = top_level_index(value, " - ")
	if at <= 0:
		return ""
	var whole: String = value.substr(0, at).strip_edges()
	if whole != "1" and whole != "1.0":
		return ""
	return value.substr(at + 3).strip_edges()


## The long tail's call readings in one place, tried in the order that recognises each whole shape
## before a narrower one could claim half of it. {} when none of them says anything, which is what
## keeps every other call exactly as it reads today.
static func long_tail_call(call: Dictionary, text: String, context: Dictionary) -> Dictionary:
	var traced: Dictionary = call.duplicate().merged({"line": text}, true)
	var requested: Dictionary = web_call(traced, context)
	if not requested.is_empty():
		return requested
	var faced: Dictionary = spatial_call(traced, context)
	if not faced.is_empty():
		return faced
	var threaded: Dictionary = background_statement(text, context)
	if not threaded.is_empty():
		return threaded
	var wired: Dictionary = signal_wiring_statement(text, context)
	if not wired.is_empty():
		return wired
	var fired: Dictionary = stored_signal_statement(text, context)
	if not fired.is_empty():
		return fired
	var named: Dictionary = call_by_name_statement(text, context)
	if not named.is_empty():
		return named
	return long_tail_media_call(traced, context)


# ── T10 / T11 / T12 - the things AROUND objects: layers and Z order, text, the browser ───────────
#
# Three families of line every project writes ABOUT an object rather than about its behaviour: where
# it sits in the drawing order, how its text is styled, and what it asks of the machine it runs on.
# An event sheet has one settled row for each - Move to layer, Set font size, Go to URL - and Godot
# spreads the same three over z_index / CanvasLayer, theme overrides / LabelSettings, and OS /
# DisplayServer. Every reading below claims its exact shape, carries the pattern it is an instance
# of, and is display-only: the file is untouched, so the byte round-trip cannot move.


## T12. The two objects the platform words live under. An event sheet files "open a link" and "copy
## text" under the Browser, and "what am I running on" under the platform information the shipped
## Platform Info pack answers - which is where a reader looks for either of them.
const OBJECT_BROWSER := "Browser"
const OBJECT_PLATFORM := "Platform"

## T10. The classes that ARE a layer. A CanvasLayer's `layer` number is a drawing order and its
## `visible` switch turns a whole layer off; neither is true of a node that merely has the words.
const LAYER_CLASSES: PackedStringArray = ["CanvasLayer"]

## T11. The alignment constants, by the word an event sheet spells them with.
const HORIZONTAL_ALIGNMENT_WORDS: Dictionary = {
	"HORIZONTAL_ALIGNMENT_LEFT": "left", "HORIZONTAL_ALIGNMENT_CENTER": "centre",
	"HORIZONTAL_ALIGNMENT_RIGHT": "right", "HORIZONTAL_ALIGNMENT_FILL": "justified"
}

## T11. The vertical alignment constants, by the same words.
const VERTICAL_ALIGNMENT_WORDS: Dictionary = {
	"VERTICAL_ALIGNMENT_TOP": "top", "VERTICAL_ALIGNMENT_CENTER": "middle",
	"VERTICAL_ALIGNMENT_BOTTOM": "bottom", "VERTICAL_ALIGNMENT_FILL": "justified"
}

## T11. The theme colour slots an event sheet has a sentence for, as {slot: the row's words}. A slot
## outside this table keeps the plain call: inventing a sentence for an unknown theme key would be
## guessing at what the project's own theme calls it.
const TEXT_COLOUR_SLOTS: Dictionary = {
	"font_color": "Set font colour to {value}",
	"font_outline_color": "Set outline colour to {value}",
	"font_shadow_color": "Set shadow colour to {value}"
}

## T11. The LabelSettings members a Text row has words for, as {member: the row's words}. Written
## through the settings resource (`label.label_settings.font`), which is the other way a project
## styles a label.
const LABEL_SETTINGS_MEMBERS: Dictionary = {
	"label_settings.font": "Set font to {value}",
	"label_settings.font_size": "Set font size to {value}",
	"label_settings.font_color": "Set font colour to {value}",
	"label_settings.outline_color": "Set outline colour to {value}"
}

## T12. The feature tags the shipped Platform Info pack has a whole condition for, in that pack's own
## words - so a hand-written `OS.has_feature("web")` and the picked row read the same sentence.
const PLATFORM_FEATURE_WORDS: Dictionary = {
	"mobile": "Is on mobile", "pc": "Is on desktop", "web": "Is on web"
}

## T12. The window modes that ARE the fullscreen switch, in both of Godot's spellings.
const FULLSCREEN_MODES: PackedStringArray = [
	"WINDOW_MODE_FULLSCREEN", "WINDOW_MODE_EXCLUSIVE_FULLSCREEN"
]


## The constant a value names, without the class in front of it: a script writes `AUTOWRAP_WORD` and
## a `@tool` script the qualified `TextServer.AUTOWRAP_WORD`, and both mean the same member.
static func unqualified_constant(value: String) -> String:
	var text: String = value.strip_edges()
	var dot_at: int = text.rfind(".")
	return text if dot_at < 0 else text.substr(dot_at + 1)


## T10. The name of the layer a node is moved into: the last segment of a `$"../FX"` path, or the
## variable that holds it. Never a guess - a value that is neither keeps the text it was written as.
static func drawing_layer_name(value: String) -> String:
	var text: String = value.strip_edges()
	if text.begins_with("$") or text.begins_with("%"):
		return object_of_reference(text)
	return text


## T11. The name a font is known by: the file it lives in, without the folder Godot files it under.
## A value that is not a loaded file reads as itself, which is what a variable already is.
static func font_file_words(value: String, context: Dictionary) -> String:
	var text: String = value.strip_edges()
	for head: String in ["preload(", "load("]:
		if not text.begins_with(head) or not text.ends_with(")"):
			continue
		var inner: String = text.substr(head.length(), text.length() - head.length() - 1).strip_edges()
		if _is_string_literal(inner):
			return _unquote(inner).get_file()
	return expression_text(text, context)


## T11. The word an alignment is spelled with, or "" when the value is neither one of the constants
## nor the number that names one. The plain number answers too, because that is how the Inspector
## writes it back into a script and a reader means the same thing by both.
static func _alignment_word(value: String, words: Dictionary) -> String:
	var bare: String = unqualified_constant(value)
	if words.has(bare):
		return translate(str(words[bare]))
	if not bare.is_valid_int():
		return ""
	var index: int = bare.to_int()
	var spellings: Array = words.values()
	return translate(str(spellings[index])) if index >= 0 and index < spellings.size() else ""


## T10. The muted aside a Set Z order row carries: whether the number the file wrote counts from the
## object's parent or from the layer. Only said when the FILE says it - `z_as_relative` is written on
## a line of its own, so the answer is gathered once per rebuild and handed over as a fact.
static func _z_order_note(object_name: String, context: Dictionary) -> String:
	var relative: Dictionary = context.get("z_order_relative", {})
	if not relative.has(object_name):
		return ""
	return "(%s)" % translate("relative" if bool(relative[object_name]) else "absolute")


## T10. The reading of one layer / Z-order ASSIGNMENT, or {} when the property is neither.
static func _layers_assignment(object_name: String, member: String, assigned: String,
		context: Dictionary) -> Dictionary:
	var value: String = assigned.strip_edges()
	match member:
		"z_index":
			var reading: Dictionary = _patterned(_sentence(object_name, "Set Z order to {value}",
				{"value": [expression_text(value, context), "value"]}), "layers")
			_append_note(reading, _z_order_note(object_name, context))
			return reading
		"z_as_relative":
			if value != "true" and value != "false":
				return {}
			return _patterned(_sentence(object_name, "Set Z order relative to the layer"
				if value == "true" else "Set Z order absolute", {}), "layers")
		"layer":
			# Only on something that IS a layer: a plain node with a `layer` number of its own is
			# holding a number, and reading that as a drawing order would be inventing one.
			if not _class_is_any(object_class_of(object_name, context), LAYER_CLASSES):
				return {}
			return _patterned(_sentence(object_name, "Set layer order to {value}",
				{"value": [expression_text(value, context), "value"]}), "layers")
	return {}


## T11. The reading of one text-styling ASSIGNMENT, or {} when the property is not one.
static func _text_assignment(object_name: String, member: String, assigned: String,
		context: Dictionary) -> Dictionary:
	var value: String = assigned.strip_edges()
	if LABEL_SETTINGS_MEMBERS.has(member):
		var shown: String = font_file_words(value, context) if member == "label_settings.font" \
			else expression_text(value, context)
		return _patterned(_sentence(object_name, str(LABEL_SETTINGS_MEMBERS[member]),
			{"value": [shown, "value"]}), "text")
	match member:
		"horizontal_alignment":
			var horizontal: String = _alignment_word(value, HORIZONTAL_ALIGNMENT_WORDS)
			if horizontal.is_empty():
				return {}
			return _patterned(_sentence(object_name, "Set horizontal alignment to {value}",
				{"value": [horizontal, "name"]}), "text")
		"vertical_alignment":
			var vertical: String = _alignment_word(value, VERTICAL_ALIGNMENT_WORDS)
			if vertical.is_empty():
				return {}
			return _patterned(_sentence(object_name, "Set vertical alignment to {value}",
				{"value": [vertical, "name"]}), "text")
		"autowrap_mode":
			var wrap: String = unqualified_constant(value)
			if not wrap.begins_with("AUTOWRAP_"):
				return {}
			return _patterned(_sentence(object_name, "Set word wrap off"
				if wrap == "AUTOWRAP_OFF" else "Set word wrap on", {}), "text")
	return {}


## T10. The reading of one layer / Z-order CALL, or {} when the call is neither.
static func _layers_call(object_name: String, method: String, args: PackedStringArray,
		context: Dictionary) -> Dictionary:
	if method == "move_to_front" and args.is_empty():
		return _patterned(_sentence(object_name, "Move to top of layer", {}), "layers")
	if method == "move_to_back" and args.is_empty():
		return _patterned(_sentence(object_name, "Move to bottom of layer", {}), "layers")
	# `reparent(node)` moves an object under another parent, and in a 2D scene that parent IS the
	# layer it draws on. The optional second argument only says whether the world position is kept.
	if method == "reparent" and (args.size() == 1 or args.size() == 2):
		var into: String = drawing_layer_name(args[0])
		if into.is_empty():
			return {}
		return _patterned(_sentence(object_name, "Move to layer {layer}",
			{"layer": [into, "name"]}), "layers")
	if method == "set_layer" and args.size() == 1 \
			and _class_is_any(object_class_of(object_name, context), LAYER_CLASSES):
		return _patterned(_sentence(object_name, "Set layer order to {value}",
			{"value": [expression_text(args[0], context), "value"]}), "layers")
	return {}


## T11. The reading of one text-styling CALL, or {} when the call is not one. Only the two-argument
## override shapes are claimed, which is the only form those methods have.
static func _text_call(object_name: String, method: String, args: PackedStringArray,
		context: Dictionary) -> Dictionary:
	if args.size() != 2:
		return {}
	var slot: String = effect_parameter_name(args[0])
	if method == "add_theme_font_size_override" and slot == "font_size":
		return _patterned(_sentence(object_name, "Set font size to {value}",
			{"value": [expression_text(args[1], context), "value"]}), "text")
	if method == "add_theme_color_override" and TEXT_COLOUR_SLOTS.has(slot):
		return _patterned(_sentence(object_name, str(TEXT_COLOUR_SLOTS[slot]),
			{"value": [expression_text(args[1], context), "value"]}), "text")
	if method == "add_theme_font_override" and slot == "font":
		return _patterned(_sentence(object_name, "Set font to {value}",
			{"value": [font_file_words(args[1], context), "value"]}), "text")
	return {}


## T12. The reading of one browser / platform CALL, or {} when the call is neither. The receiver is
## the engine service the call is spelled on, so the row is filed under the OBJECT an event sheet
## keeps the action under rather than under `OS` or `DisplayServer`.
static func _platform_call(target: String, method: String, args: PackedStringArray,
		context: Dictionary) -> Dictionary:
	if target == "OS":
		if method == "shell_open" and args.size() == 1:
			return _patterned(_sentence(OBJECT_BROWSER, "Go to URL {url}",
				{"url": [expression_text(args[0], context), "value"]}), "platform")
		if method == "alert" and (args.size() == 1 or args.size() == 2):
			return _patterned(_sentence(OBJECT_BROWSER, "Alert {message}",
				{"message": [expression_text(args[0], context), "value"]}), "platform")
	if target == "DisplayServer":
		if method == "clipboard_set" and args.size() == 1:
			return _patterned(_sentence(OBJECT_BROWSER, "Copy {value} to clipboard",
				{"value": [expression_text(args[0], context), "value"]}), "platform")
		if method == "window_set_mode" and (args.size() == 1 or args.size() == 2):
			var mode: String = unqualified_constant(args[0])
			if FULLSCREEN_MODES.has(mode):
				return _patterned(_sentence(OBJECT_BROWSER, "Request fullscreen", {}), "platform")
			if mode == "WINDOW_MODE_WINDOWED":
				return _patterned(_sentence(OBJECT_BROWSER, "Leave fullscreen", {}), "platform")
	if target == "Input" and method == "vibrate_handheld" and args.size() == 1:
		return _patterned(_sentence(OBJECT_BROWSER, "Vibrate for {milliseconds} ms",
			{"milliseconds": [expression_text(args[0], context), "value"]}), "platform")
	return {}


## T12. The reading of one platform QUESTION, or {} when the expression asks something else.
static func _platform_condition(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if not call.is_empty() and str(call.get("target", "")) == "OS" \
			and str(call.get("method", "")) == "has_feature":
		var args: PackedStringArray = call.get("args", PackedStringArray())
		if args.size() == 1 and _is_string_literal(args[0]):
			var tag: String = _unquote(args[0])
			# The editor tag is already the sheet's own "running in the editor" question, and that
			# reading owns it: two sentences for one line would be one too many.
			if tag == "editor":
				return {}
			if PLATFORM_FEATURE_WORDS.has(tag):
				return _patterned(_sentence(OBJECT_PLATFORM,
					str(PLATFORM_FEATURE_WORDS[tag]), {}), "platform")
			return _patterned(_sentence(OBJECT_PLATFORM, "Has feature tag {tag}",
				{"tag": [_quoted(args[0]), "value"]}), "platform")
	var equals_at: int = top_level_index(text, " == ")
	if equals_at <= 0:
		return {}
	var left: String = text.substr(0, equals_at).strip_edges()
	var right: String = text.substr(equals_at + 4).strip_edges()
	if left != "OS.get_name()" or not _is_string_literal(right):
		return {}
	return _patterned(_sentence(OBJECT_PLATFORM, "Is {platform}",
		{"platform": [_unquote(right), "name"]}), "platform")


## T10 / T11. The around-objects reading of one ASSIGNMENT, or {} when neither family claims it.
static func around_objects_assignment(object_name: String, member: String, assigned: String,
		context: Dictionary) -> Dictionary:
	var layered: Dictionary = _layers_assignment(object_name, member, assigned, context)
	if not layered.is_empty():
		return layered
	return _text_assignment(object_name, member, assigned, context)


## T10 / T11 / T12. The around-objects reading of one CALL, or {} when no family claims it.
static func around_objects_call(target: String, method: String, args: PackedStringArray,
		context: Dictionary) -> Dictionary:
	var platform: Dictionary = _platform_call(target, method, args, context)
	if not platform.is_empty():
		return platform
	# T10. Godot has `move_to_front()` and no opposite, so the other end of the drawing order is
	# written as "first among my parent's children" - which is the same one action, said the long way.
	if target == "get_parent()" and method == "move_child" and args.size() == 2 \
			and args[0].strip_edges() == "self" and args[1].strip_edges() == "0":
		return _patterned(_sentence(script_object(context), "Move to bottom of layer", {}), "layers")
	var object_name: String = _receiver_object(target, context)
	var styled: Dictionary = _text_call(object_name, method, args, context)
	if not styled.is_empty():
		return styled
	return _layers_call(object_name, method, args, context)


## T12. The around-objects reading of one CONDITION, or {} when nothing claims it.
static func around_objects_condition(text: String, context: Dictionary) -> Dictionary:
	return _platform_condition(text, context)


# ── T8 - picking: WHICH instances a row is about ─────────────────────────────────────────────────
#
# An event sheet says "which instances" with a pick: nearest, farthest, random, by comparison, top,
# bottom, by UID. A Godot script says the same things to a list of nodes - `pick_random()`, a
# `filter` lambda, `back()`, `instance_from_id()` - and each of those lines both PICKS and NAMES what
# it picked, which is why the row says the pick and then, muted, the name it filled.
#
# A pick is only read when the family it picks from is KNOWN: the list was declared from a group, or
# the variable carries the type. Reading "Pick a random enemies" off a list nobody said the kind of
# would be inventing an object type, so the line keeps its own words instead.


## T8. The list steps that ARE a pick, as {method: the row's words}. `filter` and `instance_from_id`
## carry a value of their own and are read out separately.
const PICK_METHODS: Dictionary = {
	"pick_random": "Pick a random {family}",
	"back": "Pick top {family}",
	"front": "Pick bottom {family}"
}


## T8. The family word a type or a group name goes by - the name a reader would say out loud, which
## is the class as written and a group spelled the way the picker spells a published name.
static func family_word_of(name_text: String) -> String:
	var bare: String = name_text.strip_edges()
	if bare.is_empty():
		return ""
	# `Array[Enemy]` names the family its members are.
	if bare.begins_with("Array[") and bare.ends_with("]"):
		bare = bare.substr(6, bare.length() - 7).strip_edges()
	if not is_identifier(bare):
		return ""
	return bare if bare == bare.capitalize().replace(" ", "") else function_words(bare)


## T8. The family a list holds, from what the FILE said when the list was made: a list built from a
## group is that group's family. "" when the file never said, which is the cue not to read a pick.
static func family_of_list(receiver: String, context: Dictionary) -> String:
	var lists: Dictionary = context.get("family_lists", {})
	return str(lists.get(receiver.strip_edges(), ""))


## T8. The one parameter and the body of a single-argument one-line lambda, as [name, body], or []
## for anything else. `one_line_lambda` above reads the two-parameter shape a `reduce` is written in;
## a `filter` test takes exactly one, and a sentence may only stand for a shape it can see whole.
static func _one_argument_lambda(text: String) -> Array:
	var body: String = text.strip_edges()
	if not body.begins_with("func(") or body.contains("\n"):
		return []
	var close_at: int = closing_paren(body, 4)
	if close_at < 0:
		return []
	var parameter: String = body.substr(5, close_at - 5).strip_edges()
	var colon_at: int = parameter.find(":")
	if colon_at >= 0:
		parameter = parameter.substr(0, colon_at).strip_edges()
	if not is_identifier(parameter):
		return []
	var rest: String = body.substr(close_at + 1).strip_edges()
	if not rest.begins_with(":"):
		return []
	rest = rest.substr(1).strip_edges()
	if not rest.begins_with("return "):
		return []
	return [parameter, rest.substr(7).strip_edges()]


## T8. The `var name[: Type] = value` a pick is written into, as {name, type, value}, or {} when the
## line declares nothing. Both spellings of the declaration answer.
static func _picked_declaration(text: String) -> Dictionary:
	var body: String = text.strip_edges()
	var keyword: String = leading_word(body)
	if keyword != "var" and keyword != "const":
		return {}
	body = body.substr(keyword.length()).strip_edges()
	var type_text: String = ""
	var value: String = ""
	var name_text: String = ""
	for separator: String in [" := ", " = "]:
		var at: int = top_level_index(body, separator)
		if at <= 0:
			continue
		name_text = body.substr(0, at).strip_edges()
		value = body.substr(at + separator.length()).strip_edges()
		break
	if name_text.is_empty() or value.is_empty():
		return {}
	var colon_at: int = name_text.find(":")
	if colon_at >= 0:
		type_text = name_text.substr(colon_at + 1).strip_edges()
		name_text = name_text.substr(0, colon_at).strip_edges()
	if not is_identifier(name_text):
		return {}
	return {"name": name_text, "type": type_text, "value": value}


## T8. The pick a VALUE is, or {} when the value picks nothing this reading can name.
static func _pick_reading(value: String, declared_family: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(value)
	if call.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	var receiver: String = str(call.get("target", "")).strip_edges()
	var args: PackedStringArray = call.get("args", PackedStringArray())
	# The UID pick names no list at all - the number IS the instance - so the family can only come
	# from the type the variable carries, and "object" is the honest word when it carries none.
	if method == "instance_from_id" and receiver.is_empty() and args.size() == 1:
		var uid_family: String = declared_family if not declared_family.is_empty() else translate("object")
		return _sentence(OBJECT_SYSTEM, "Pick {family} by UID {uid}", {
			"family": [uid_family, "name"],
			"uid": [expression_text(args[0], context), "value"]})
	var family: String = family_of_list(receiver, context)
	if family.is_empty():
		family = declared_family
	if family.is_empty():
		return {}
	if PICK_METHODS.has(method) and args.is_empty():
		return _sentence(OBJECT_SYSTEM, str(PICK_METHODS[method]), {"family": [family, "name"]})
	if method == "filter" and args.size() == 1:
		var lambda: Array = _one_argument_lambda(args[0])
		if lambda.is_empty():
			return {}
		# The lambda's own parameter is a name only that lambda knows, so the test is shown the way a
		# picking row shows it: about the member, not about the loop variable.
		var test: String = str(lambda[1])
		var prefix: String = "%s." % str(lambda[0])
		if test.begins_with(prefix):
			test = test.substr(prefix.length())
		return _sentence(OBJECT_SYSTEM, "Pick {family} where {test}", {
			"family": [family, "name"], "test": [expression_text(test, context), "value"]})
	return {}


## T8. The reading of one line that picks - a list step or a UID lookup written into a name - or {}
## when the line picks nothing. The row says the pick, then the name it filled, muted, because the
## reader's next question about a picked instance is what it is called from here on.
static func picking_statement(text: String, context: Dictionary) -> Dictionary:
	var declared: Dictionary = _picked_declaration(text)
	if declared.is_empty():
		return {}
	var reading: Dictionary = _pick_reading(str(declared.get("value", "")),
		family_word_of(str(declared.get("type", ""))), context)
	if reading.is_empty():
		return {}
	_append_note(reading, "→ %s" % str(declared.get("name", "")).replace("_", " "))
	return _patterned(reading, "picking")


# ── V1 / V2 / V3 / V6 / V7 - the last reading gaps batch eleven closed ──────────────────────────
#
# Five families of line a finished Godot game is full of and an event sheet already has words for:
#
#   V1  a RigidBody IS the Physics behavior - mass, gravity scale, the material's friction and
#       elasticity, the four apply_* pushes, velocity, immovable, sleeping, damping, the joints and
#       an Area's world gravity
#   V2  the Controls a menu is made of, under the object words a form has: Text input, List,
#       Check box, File chooser, Tabs, and the two formatted-text verbs
#   V3  a PathFollow is the Follow a Path behavior - move along, has reached the end, go to start,
#       looping and rotate with path
#   V6  the text a HUD is written with: a format string as the sheet's join, `.format({})` with its
#       names said out loud, and the regular-expression words
#   V7  the numbers a profiling script reads by name, and the one wait that freezes the game
#
# Everything here is display only, every reading is claimed at its exact shape, and every one of
# them carries the pattern it recognised so the registry hears about it without this file knowing
# what a sheet is. A line these cannot say honestly keeps the property write or the call it is.

## V6. Text and regular expressions are one object in the sheet's words, the way saving is Local
## Storage's and the messages are Multiplayer's.
const OBJECT_TEXT := "Text"

## V1. The areas whose `gravity` is the world's, rather than a number of their own.
const PHYSICS_AREA_CLASSES: PackedStringArray = ["Area2D", "Area3D"]

## V1. The joint nodes named by what the joint DOES, in both node generations. A pin turns, a spring
## holds a distance, a groove slides.
const JOINT_KIND_WORDS: Dictionary = {
	"PinJoint2D": "revolute", "PinJoint3D": "revolute", "HingeJoint3D": "revolute",
	"DampedSpringJoint2D": "distance",
	"GrooveJoint2D": "prismatic", "SliderJoint3D": "prismatic"
}

## V1. The rigid-body members with one settled Physics sentence each. `gravity_scale`, `freeze` and
## the material knobs are shaped rather than templated, so they are not in the table.
const PHYSICS_MEMBER_TEMPLATES: Dictionary = {
	"mass": "Set mass to {value}",
	"linear_damp": "Set linear damping to {value}",
	"angular_damp": "Set angular damping to {value}"
}

## V1. The pushes an event sheet spells with an offset. The one-argument impulse and force are
## already the Physics behavior's own words further up this file; these are the shapes that had none.
const PHYSICS_PUSH_TEMPLATES: Dictionary = {
	"apply_impulse": ["", "Apply impulse {value} at {offset}"],
	"apply_force": ["", "Apply force {value} at {offset}"],
	"apply_torque": ["Apply torque {value}", ""],
	"apply_torque_impulse": ["Apply torque impulse {value}", ""]
}

## V3. The nodes that walk a path, and the resources that hold one.
const PATH_FOLLOW_CLASSES: PackedStringArray = ["PathFollow2D", "PathFollow3D"]
const PATH_CURVE_CLASSES: PackedStringArray = ["Curve2D", "Curve3D"]

## V2. The Controls filed under each object word a form has. Matched through ClassDB, so a subclass
## of any of them answers alike.
const TEXT_INPUT_CLASSES: PackedStringArray = ["LineEdit", "TextEdit"]
const LIST_CLASSES: PackedStringArray = ["ItemList", "OptionButton", "Tree"]
const CHECK_CLASSES: PackedStringArray = ["CheckBox", "CheckButton"]
const FILE_DIALOG_CLASSES: PackedStringArray = ["FileDialog"]
const TABS_CLASSES: PackedStringArray = ["TabContainer", "TabBar"]
const RICH_TEXT_CLASSES: PackedStringArray = ["RichTextLabel"]

## V2. The list steps, in the words the List object publishes. `clear` is shaped (it takes nothing),
## so it is not in the table.
const LIST_CONTROL_TEMPLATES: Dictionary = {
	"add_item": "Add item {value}",
	"remove_item": "Remove item {value}",
	"select": "Select item {value}"
}

## V7. The waits that stop the whole game while they run, and how many of one second each counts in.
const BLOCKING_WAIT_CALLS: Dictionary = {"OS.delay_msec": 1000.0, "OS.delay_usec": 1000000.0}


## The event-sheet reading of one statement in the five families above, or {} to let the rest of the
## grammar carry on. Asked ahead of the compound / assignment / call split, because several of these
## are one idea written as arithmetic on a property.
static func gap_statement(text: String, context: Dictionary) -> Dictionary:
	var waited: Dictionary = _blocking_wait_statement(text, context)
	if not waited.is_empty():
		return waited
	var moved: Dictionary = _path_move_statement(text, context)
	if not moved.is_empty():
		return moved
	var assign_at: int = top_level_index(text, " = ")
	if assign_at > 0:
		var target: String = text.substr(0, assign_at).strip_edges()
		var assigned: String = text.substr(assign_at + 3).strip_edges()
		if not is_simple_target(target) or assigned.is_empty():
			return {}
		return _gap_assignment(target, assigned, context)
	return _gap_call(text, context)


## The event-sheet reading of one QUESTION in the five families, or {} to let the rest carry on.
static func gap_condition(text: String, context: Dictionary) -> Dictionary:
	var bare: String = text.strip_edges()
	var reached: Dictionary = _path_end_condition(bare, context)
	if not reached.is_empty():
		return reached
	var flag: String = bare.trim_prefix("self.")
	var negated: bool = flag.begins_with("not ")
	if negated:
		flag = flag.substr(4).strip_edges().trim_prefix("self.")
	if not is_simple_target(flag):
		return {}
	var dot_at: int = flag.rfind(".")
	var member: String = flag if dot_at < 0 else flag.substr(dot_at + 1)
	var owner_text: String = "" if dot_at < 0 else flag.substr(0, dot_at)
	var object_name: String = _receiver_object(owner_text, context)
	var object_class: String = object_class_of(object_name, context)
	if _class_is_any(object_class, BODY_CLASSES):
		if member == "sleeping":
			return _with_pattern(_behaviour_sentence(object_name, "Physics",
				"Is awake" if negated else "Is sleeping", {}), "physics", bare)
		if member == "freeze":
			return _with_pattern(_behaviour_sentence(object_name, "Physics",
				"Is not immovable" if negated else "Is immovable", {}), "physics", bare)
	if member == "button_pressed" and _class_is_any(object_class, CHECK_CLASSES):
		return _with_pattern(_behaviour_sentence(object_name, "Check box",
			"Is not checked" if negated else "Is checked", {}), "ui", bare)
	return {}


## V7. `OS.delay_msec(500)` is a wait every event sheet has a row for - and the one difference that
## matters is said out loud, because a reader who has met the sheet's own Wait would never guess this
## one stops the game dead while it counts.
static func _blocking_wait_statement(text: String, context: Dictionary) -> Dictionary:
	var trimmed: String = text.strip_edges()
	for head: String in BLOCKING_WAIT_CALLS:
		var opening: String = "%s(" % head
		if not trimmed.begins_with(opening) or not trimmed.ends_with(")"):
			continue
		if closing_paren(trimmed, opening.length() - 1) != trimmed.length() - 1:
			continue
		var amount: String = trimmed.substr(opening.length(),
			trimmed.length() - opening.length() - 1).strip_edges()
		if amount.is_empty() or not amount.is_valid_float():
			continue
		var counted: String = String.num(
			amount.to_float() / float(BLOCKING_WAIT_CALLS[head]), 6).rstrip("0").rstrip(".")
		var seconds: String = number_lens("0" if counted.is_empty() else counted)
		var waited: Dictionary = _sentence(OBJECT_SYSTEM, "Wait {seconds} seconds", {
			"seconds": [seconds, "value"]})
		(waited["segments"] as Array).append({
			"text": " ⚠ %s" % translate("blocks the game"), "tone": "muted"})
		return waited
	return {}


## V3. `follow.progress += speed * delta` is the whole of "move along this path at that speed", and
## the sheet's Follow a Path behavior says exactly that. Only a step scaled by the frame time counts:
## a jump of a fixed number of pixels is a jump, and calling it a speed would be wrong on every
## machine that runs the game at another rate.
static func _path_move_statement(text: String, context: Dictionary) -> Dictionary:
	var trimmed: String = text.strip_edges()
	var plus_at: int = top_level_index(trimmed, " += ")
	if plus_at <= 0:
		return {}
	var target: String = trimmed.substr(0, plus_at).strip_edges().trim_prefix("self.")
	var amount: String = trimmed.substr(plus_at + 4).strip_edges()
	if not target.ends_with("progress") or amount.is_empty():
		return {}
	var owner_text: String = target.substr(0, maxi(target.length() - 8, 0)).trim_suffix(".")
	if not _walks_a_path(owner_text, context):
		return {}
	var times_at: int = top_level_index(amount, " * ")
	if times_at <= 0:
		return {}
	var speed: String = amount.substr(0, times_at).strip_edges()
	if not EventSheetPatternReadings.is_delta_value(amount.substr(times_at + 3)):
		return {}
	return _with_pattern(_behaviour_sentence(script_object(context), "Follow a Path",
		"Move along path at {speed}", {"speed": [expression_text(speed, context), "value"]}),
		"path", trimmed, "follow_path")


## V3. `follow.progress_ratio >= 1.0` is the one question a path walk asks. Only the far end counts -
## a ratio compared against a half is a comparison, and the sheet has no word that would be true of it.
static func _path_end_condition(text: String, context: Dictionary) -> Dictionary:
	var parts: Array = _comparison_parts(text)
	if parts.is_empty() or (str(parts[1]) != ">=" and str(parts[1]) != ">"):
		return {}
	var left: String = str(parts[0]).strip_edges().trim_prefix("self.")
	var right: String = str(parts[2]).strip_edges().trim_suffix(":").strip_edges()
	if not left.ends_with("progress_ratio") or not right.is_valid_float() or right.to_float() < 1.0:
		return {}
	var owner_text: String = left.substr(0, maxi(left.length() - 14, 0)).trim_suffix(".")
	if not _walks_a_path(owner_text, context):
		return {}
	return _with_pattern(_behaviour_sentence(script_object(context), "Follow a Path",
		"Has reached the end", {}), "path", text.strip_edges(), "follow_path")


## True when a receiver is a path follower - the class the sheet knows it by, or the script's own
## class when the line names no receiver at all.
static func _walks_a_path(owner_text: String, context: Dictionary) -> bool:
	return _class_is_any(object_class_of(_receiver_object(owner_text, context), context),
		PATH_FOLLOW_CLASSES)


## The property writes of the five families, or {} to keep the plain Set. Every arm is gated on the
## object's KNOWN class (or on a local this file declared as a physics material), so a member name
## that means something else on something else keeps its own reading.
static func _gap_assignment(target: String, assigned: String, context: Dictionary) -> Dictionary:
	var bare: String = target.strip_edges().trim_prefix("self.")
	var dot_at: int = bare.rfind(".")
	var member: String = bare if dot_at < 0 else bare.substr(dot_at + 1)
	var owner_text: String = "" if dot_at < 0 else bare.substr(0, dot_at)
	var object_name: String = _receiver_object(owner_text, context)
	var object_class: String = object_class_of(object_name, context)
	var line: String = _member_line(owner_text, member, assigned)
	var physics: Dictionary = _physics_assignment(object_name, object_class, member, owner_text,
		assigned, line, context)
	if not physics.is_empty():
		return physics
	var walked: Dictionary = _path_assignment(object_class, member, assigned, line, context)
	if not walked.is_empty():
		return walked
	return _control_assignment(object_name, object_class, member, assigned, line, context)


## V1. The Physics behavior's settings, whichever half of the body they are written on: the body's
## own members, and the two knobs that live on the physics material a `PhysicsMaterial.new()` put in
## a variable of this file.
static func _physics_assignment(object_name: String, object_class: String, member: String,
		owner_text: String, assigned: String, line: String, context: Dictionary) -> Dictionary:
	var materials: Dictionary = context.get("physics_materials", {})
	# The slot the body keeps its material in is a material by name, whoever owns it - which is what
	# the sheet's own Set friction row writes, so a picked row and a typed one read alike.
	var material_slot: bool = owner_text == "physics_material_override" \
		or owner_text.ends_with(".physics_material_override")
	if not owner_text.is_empty() and (material_slot or materials.has(owner_text)):
		# The material is the body's surface, so the row belongs to the object a reader can point at
		# rather than to the variable that happens to hold the resource.
		if member == "friction":
			return _with_pattern(_behaviour_sentence(script_object(context), "Physics",
				"Set friction to {value}", {"value": [expression_text(assigned, context), "value"]}),
				"physics", line)
		if member == "bounce":
			return _with_pattern(_behaviour_sentence(script_object(context), "Physics",
				"Set elasticity to {value}", {"value": [expression_text(assigned, context), "value"]}),
				"physics", line)
		return {}
	if _class_is_any(object_class, PHYSICS_AREA_CLASSES) and member == "gravity":
		return _with_pattern(_behaviour_sentence(object_name, "Physics", "Set world gravity to {value}",
			{"value": [expression_text(assigned, context), "value"]}), "physics", line)
	if not _class_is_any(object_class, BODY_CLASSES):
		return {}
	if PHYSICS_MEMBER_TEMPLATES.has(member):
		return _with_pattern(_behaviour_sentence(object_name, "Physics",
			str(PHYSICS_MEMBER_TEMPLATES[member]),
			{"value": [expression_text(assigned, context), "value"]}), "physics", line)
	match member:
		"gravity_scale":
			# The number as WRITTEN, not as a percentage of normal gravity: the sheet's own Set
			# gravity scale row shows the value its field holds, and a line that read one way when it
			# was typed and another when it was picked would be the drift these readings exist to
			# prevent. 1 is normal gravity, 0 floats - which is what the row's own description says.
			return _with_pattern(_behaviour_sentence(object_name, "Physics",
				"Set gravity scale to {value}",
				{"value": [expression_text(assigned, context), "value"]}), "physics", line)
		"freeze":
			if assigned != "true" and assigned != "false":
				return {}
			return _with_pattern(_behaviour_sentence(object_name, "Physics",
				"Set immovable" if assigned == "true" else "Set movable", {}), "physics", line)
		"physics_material_override":
			return _with_pattern(_behaviour_sentence(object_name, "Physics",
				"Use physics material {value}",
				{"value": [expression_text(assigned, context), "value"]}), "physics", line)
	return {}


## V3. The two switches a path walk has, and the place along the path it is put back to.
static func _path_assignment(object_class: String, member: String, assigned: String, line: String,
		context: Dictionary) -> Dictionary:
	if not _class_is_any(object_class, PATH_FOLLOW_CLASSES):
		return {}
	var object_name: String = script_object(context)
	if member == "loop" or member == "rotates":
		if assigned != "true" and assigned != "false":
			return {}
		var template: String = "Set looping {state}" if member == "loop" else "Set rotate with path {state}"
		return _with_pattern(_behaviour_sentence(object_name, "Follow a Path", template,
			{"state": [translate("on") if assigned == "true" else translate("off"), "name"]}),
			"path", line, "follow_path")
	if member != "progress":
		return {}
	if assigned.is_valid_float() and assigned.to_float() == 0.0:
		return _with_pattern(_behaviour_sentence(object_name, "Follow a Path", "Go to start", {}),
			"path", line, "follow_path")
	return _with_pattern(_behaviour_sentence(object_name, "Follow a Path",
		"Set distance along path to {value}",
		{"value": [expression_text(assigned, context), "value"]}), "path", line, "follow_path")


## V2. The property writes a form makes, under the object word each Control goes by. A tooltip is the
## one that belongs to every Control there is, so it is asked last and without a class of its own.
static func _control_assignment(object_name: String, object_class: String, member: String,
		assigned: String, line: String, context: Dictionary) -> Dictionary:
	var shown: String = expression_text(assigned, context)
	if _class_is_any(object_class, TEXT_INPUT_CLASSES):
		if member == "text":
			return _with_pattern(_behaviour_sentence(object_name, "Text input", "Set text to {value}",
				{"value": [shown, "value"]}), "ui", line)
		if member == "placeholder_text":
			return _with_pattern(_behaviour_sentence(object_name, "Text input",
				"Set placeholder to {value}", {"value": [shown, "value"]}), "ui", line)
	if member == "text" and _class_is_any(object_class, RICH_TEXT_CLASSES):
		return _with_pattern(_sentence(object_name, "Set formatted text to {value}",
			{"value": [shown, "value"]}), "ui", line)
	if member == "current_tab" and _class_is_any(object_class, TABS_CLASSES):
		return _with_pattern(_behaviour_sentence(object_name, "Tabs", "Switch to tab {value}",
			{"value": [shown, "value"]}), "ui", line)
	if member == "button_pressed" and _class_is_any(object_class, CHECK_CLASSES):
		if assigned != "true" and assigned != "false":
			return {}
		return _with_pattern(_behaviour_sentence(object_name, "Check box",
			"Set checked" if assigned == "true" else "Set unchecked", {}), "ui", line)
	if member == "tooltip_text" and _class_is_any(object_class, PackedStringArray(["Control"])):
		return _with_pattern(_sentence(object_name, "Set tooltip to {value}",
			{"value": [shown, "value"]}), "ui", line)
	return {}


## The calls of the five families, or {} to keep the ordinary Object / Verb reading.
static func _gap_call(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if call.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	var receiver: String = str(call.get("target", ""))
	var line: String = text.strip_edges()
	var joint: Dictionary = _joint_call(method, arguments, line, context)
	if not joint.is_empty():
		return joint
	var object_name: String = _receiver_object(receiver, context)
	var object_class: String = object_class_of(object_name, context)
	var pushed: Dictionary = _physics_push_call(object_name, object_class, method, arguments, line,
		context)
	if not pushed.is_empty():
		return pushed
	if method == "add_point" and arguments.size() == 1 and _class_is_any(object_class, PATH_CURVE_CLASSES):
		return _with_pattern(_behaviour_sentence(script_object(context), "Follow a Path",
			"Add path point {value}", {"value": [expression_text(arguments[0], context), "value"]}),
			"path", line, "follow_path")
	var typed: Dictionary = _pattern_call(method, arguments, receiver, line, context)
	if not typed.is_empty():
		return typed
	return _control_call(object_name, object_class, method, arguments, line, context)


## V1. The pushes with an offset, and the two spins. The one-argument impulse and force are already
## the Physics behavior's words further up this file, so claiming them again here would say the same
## sentence twice with two chances to drift apart.
static func _physics_push_call(object_name: String, object_class: String, method: String,
		arguments: PackedStringArray, line: String, context: Dictionary) -> Dictionary:
	if not PHYSICS_PUSH_TEMPLATES.has(method) or not _class_is_any(object_class, BODY_CLASSES):
		return {}
	var forms: Array = PHYSICS_PUSH_TEMPLATES[method]
	if arguments.size() == 1 and not str(forms[0]).is_empty():
		return _with_pattern(_behaviour_sentence(object_name, "Physics", str(forms[0]),
			{"value": [expression_text(arguments[0], context), "value"]}), "physics", line)
	if arguments.size() == 2 and not str(forms[1]).is_empty():
		return _with_pattern(_behaviour_sentence(object_name, "Physics", str(forms[1]), {
			"value": [expression_text(arguments[0], context), "value"],
			"offset": [expression_text(arguments[1], context), "value"]}), "physics", line)
	return {}


## V1. `add_child(PinJoint2D.new())` is the sheet's Create joint action, named by what the joint does
## rather than by the node class it is built from.
static func _joint_call(method: String, arguments: PackedStringArray, line: String,
		context: Dictionary) -> Dictionary:
	if method != "add_child" or arguments.size() != 1:
		return {}
	var kind: String = joint_kind_words(arguments[0])
	if kind.is_empty():
		return {}
	return _with_pattern(_sentence(script_object(context), "Create {kind} joint",
		{"kind": [kind, "name"]}), "physics", line)


## V1. The joint a `PinJoint2D.new()` builds, in the sheet's own word for it, or "" for anything else.
static func joint_kind_words(value: String) -> String:
	var text: String = value.strip_edges()
	if not text.ends_with(".new()"):
		return ""
	var built: String = text.substr(0, text.length() - 6).strip_edges()
	return translate(str(JOINT_KIND_WORDS[built])) if JOINT_KIND_WORDS.has(built) else ""


## V6. `rx.compile("\\d+")` is the row that gives a pattern its pattern, and the sheet says so with
## the regular expression spelled the way a reader wrote it rather than the way GDScript escapes it.
static func _pattern_call(method: String, arguments: PackedStringArray, receiver: String,
		line: String, context: Dictionary) -> Dictionary:
	if method != "compile" or arguments.size() != 1:
		return {}
	var holder: String = receiver.strip_edges()
	var patterns: Dictionary = context.get("pattern_variables", {})
	if holder.is_empty() or not patterns.has(holder):
		return {}
	var written: Dictionary = _sentence(OBJECT_TEXT, "Set pattern {name} to {value}", {
		"name": [holder, "name"],
		"value": [pattern_literal_words(arguments[0]), "value"]})
	(written["segments"] as Array).append({
		"text": " %s" % translate("regular expression"), "tone": "muted"})
	return _with_pattern(written, "text_format", line)


## V6. A regular-expression literal as the reader typed it: GDScript needs `"\\d+"` to hold `\d+`,
## and the doubled backslash is the language's, never part of the pattern. Anything that is not a
## plain literal keeps whatever it is.
static func pattern_literal_words(value: String) -> String:
	var text: String = value.strip_edges()
	if not _is_string_literal(text):
		return text
	return "\"%s\"" % _unquote(text).replace("\\\\", "\\")


## V2. The verbs a form's Controls publish: the list steps, the two formatted-text ones, and opening
## a file chooser.
static func _control_call(object_name: String, object_class: String, method: String,
		arguments: PackedStringArray, line: String, context: Dictionary) -> Dictionary:
	if _class_is_any(object_class, LIST_CLASSES):
		if LIST_CONTROL_TEMPLATES.has(method) and arguments.size() == 1:
			return _with_pattern(_behaviour_sentence(object_name, "List",
				str(LIST_CONTROL_TEMPLATES[method]),
				{"value": [expression_text(arguments[0], context), "value"]}), "ui", line)
		if method == "clear" and arguments.is_empty():
			return _with_pattern(_behaviour_sentence(object_name, "List", "Clear", {}), "ui", line)
	if method == "append_text" and arguments.size() == 1 and _class_is_any(object_class, RICH_TEXT_CLASSES):
		return _with_pattern(_sentence(object_name, "Append formatted text {value}",
			{"value": [expression_text(arguments[0], context), "value"]}), "ui", line)
	if _class_is_any(object_class, FILE_DIALOG_CLASSES) and arguments.is_empty() \
			and (method == "popup_centered" or method == "popup" or method == "show"):
		return _with_pattern(_behaviour_sentence(object_name, "File chooser", "Open", {}), "ui", line)
	return {}


## V6. The text words a VALUE reads in: the named format, the pattern searches and the match itself.
## Returns the text unchanged when nothing is recognised, which is how most values leave it.
static func text_pattern_words(text: String, context: Dictionary) -> String:
	var trimmed: String = text.strip_edges()
	if trimmed == "RegEx.new()":
		return translate("a pattern")
	var out: String = _format_with_names(trimmed)
	var matches: Dictionary = context.get("match_variables", {})
	for holder: String in matches:
		out = out.replace("%s.get_string()" % holder, translate("the match"))
	var patterns: Dictionary = context.get("pattern_variables", {})
	if patterns.is_empty():
		return out
	var call: Dictionary = call_parts(out)
	if call.is_empty():
		return out
	var pattern_name: String = str(call.get("target", "")).strip_edges()
	if not patterns.has(pattern_name):
		return out
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	match str(call.get("method", "")):
		"search":
			if arguments.size() == 1:
				return _fill(translate("first match of {pattern} in {text}"),
					{"pattern": pattern_name, "text": arguments[0].strip_edges()})
		"search_all":
			if arguments.size() == 1:
				return _fill(translate("all matches of {pattern} in {text}"),
					{"pattern": pattern_name, "text": arguments[0].strip_edges()})
		"sub":
			if arguments.size() >= 2:
				return _fill(translate("replace matches of {pattern} in {text} with {value}"), {
					"pattern": pattern_name, "text": arguments[0].strip_edges(),
					"value": arguments[1].strip_edges()})
	return out


## V6. `"{a} vs {b}".format({"a": p1, "b": p2})` with its names said out loud - the one format
## spelling the numbered unroll further up this file cannot take apart, because its slots are words.
## Claimed only when every key the call handed it is a slot the pattern names: a half-filled format
## would show a reader a value under the wrong name.
static func _format_with_names(text: String) -> String:
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
	var inner: String = trimmed.substr(head_at + HEAD.length(),
		trimmed.length() - head_at - HEAD.length() - 1).strip_edges()
	if not inner.begins_with("{") or not inner.ends_with("}"):
		return text
	var named: PackedStringArray = PackedStringArray()
	var body: String = pattern.substr(1, pattern.length() - 2)
	for entry: String in _split_arguments(inner.substr(1, inner.length() - 2)):
		var colon_at: int = top_level_index(entry, ": ")
		if colon_at <= 0:
			return text
		var key: String = entry.substr(0, colon_at).strip_edges()
		if not _is_string_literal(key):
			return text
		var slot: String = _unquote(key)
		if not body.contains("{%s}" % slot):
			return text
		named.append("%s = %s" % [slot, entry.substr(colon_at + 2).strip_edges()])
	if named.is_empty():
		return text
	return "%s %s %s" % [pattern, translate("with"), ", ".join(named)]
# ── V4 / V5 - the data-asset words and the window / render / screenshot words ───────────────────
#
# Two more families of line a plain Godot script is made of, read in words the sheet already
# publishes: the Files section of the Resources vocabulary says "data asset", and the Game Window
# vocabulary says fullscreen / vsync / max FPS. Both are display only - nothing here reaches
# emission, and a line whose exact shape is not one of these keeps the property write or the call it
# already reads as.

## V5. The object every window row belongs to. Its own noun, because a window is a thing a game has
## rather than a service the System object performs.
const OBJECT_WINDOW := "Window"

## V5. What each window mode says as a fullscreen switch. The two fullscreen spellings are one
## question with one extra fact; the two size spellings are their own verbs.
const WINDOW_MODE_WORDS: Dictionary = {
	"Window.MODE_FULLSCREEN": "Set fullscreen on",
	"Window.MODE_EXCLUSIVE_FULLSCREEN": "Set fullscreen on (exclusive)",
	"Window.MODE_WINDOWED": "Set fullscreen off",
	"Window.MODE_MAXIMIZED": "Maximize",
	"Window.MODE_MINIMIZED": "Minimize"
}

## V5. The vsync modes, as the on/off an options menu offers.
const WINDOW_VSYNC_WORDS: Dictionary = {
	"DisplayServer.VSYNC_DISABLED": "Set vsync off",
	"DisplayServer.VSYNC_ENABLED": "Set vsync on",
	"DisplayServer.VSYNC_ADAPTIVE": "Set vsync on (adaptive)",
	"DisplayServer.VSYNC_MAILBOX": "Set vsync on (mailbox)"
}

## V5. The anti-aliasing levels in the words a settings screen offers, by the constant the line
## writes. Both the viewport spelling and the rendering-server spelling of each level.
const ANTI_ALIASING_WORDS: Dictionary = {
	"Viewport.MSAA_DISABLED": "off",
	"Viewport.MSAA_2X": "2×",
	"Viewport.MSAA_4X": "4×",
	"Viewport.MSAA_8X": "8×",
	"RenderingServer.VIEWPORT_MSAA_DISABLED": "off",
	"RenderingServer.VIEWPORT_MSAA_2X": "2×",
	"RenderingServer.VIEWPORT_MSAA_4X": "4×",
	"RenderingServer.VIEWPORT_MSAA_8X": "8×"
}

## V5. The two members that carry an anti-aliasing level on a viewport.
const ANTI_ALIASING_MEMBERS: PackedStringArray = ["msaa_2d", "msaa_3d"]

## V5. The image-writing calls. `save_png` is the one every screenshot line uses; the others are the
## same step with another file format on the end of it.
const IMAGE_SAVE_METHODS: PackedStringArray = ["save_png", "save_jpg", "save_webp", "save_exr"]

## V5. The whole expression a screenshot IS, in the two spellings a script writes it in. Matched
## before any other rewriting sees it, because every pass below would take the chain apart into
## members that answer nothing.
const SCREENSHOT_EXPRESSIONS: PackedStringArray = [
	"get_viewport().get_texture().get_image()",
	"get_window().get_texture().get_image()"
]

## V4. The file extensions a data asset is saved under.
const DATA_ASSET_EXTENSIONS: PackedStringArray = ["tres", "res"]


## V5. The window, render and screenshot reading of one STATEMENT, or {} when the line is none of
## them. Every shape is claimed WHOLE or not at all:
##
##   get_window().size = Vector2i(1280, 720)     Window ▸ Set size to 1280 × 720
##   get_window().title = "My Game"              Window ▸ Set title to "My Game"
##   get_window().mode = Window.MODE_FULLSCREEN  Window ▸ Set fullscreen on
##   DisplayServer.window_set_vsync_mode(...)    Window ▸ Set vsync on
##   Engine.max_fps = 60                         System ▸ Set max FPS to 60
##   get_viewport().msaa_2d = Viewport.MSAA_4X   System ▸ Set anti-aliasing to 4×
##   img.save_png("user://shot.png")             System ▸ Save image img as shot.png
static func window_statement(text: String, context: Dictionary) -> Dictionary:
	var line: String = text.strip_edges()
	var vsync: Dictionary = _vsync_statement(line)
	if not vsync.is_empty():
		return vsync
	var saved: Dictionary = _image_save_statement(line, context)
	if not saved.is_empty():
		return saved
	var assign_at: int = top_level_index(line, " = ")
	if assign_at <= 0:
		return {}
	var target: String = line.substr(0, assign_at).strip_edges()
	var value: String = line.substr(assign_at + 3).strip_edges()
	if target == "Engine.max_fps":
		return _with_pattern(_sentence(OBJECT_SYSTEM, "Set max FPS to {value}",
			{"value": [expression_text(value, context), "value"]}), "window", line)
	var member: String = _window_member(target)
	if not member.is_empty():
		return _window_member_statement(member, value, line, context)
	var viewport_member: String = _viewport_member(target)
	if ANTI_ALIASING_MEMBERS.has(viewport_member) and ANTI_ALIASING_WORDS.has(value):
		return _with_pattern(_sentence(OBJECT_SYSTEM, "Set anti-aliasing to {value}",
			{"value": [translate(str(ANTI_ALIASING_WORDS[value])), "value"]}), "window", line)
	return {}


## V5. One `get_window().<member> = <value>` line, in the Game Window vocabulary's own words.
static func _window_member_statement(member: String, value: String, line: String,
		context: Dictionary) -> Dictionary:
	if member == "mode":
		if not WINDOW_MODE_WORDS.has(value):
			return {}
		return _with_pattern(_sentence(OBJECT_WINDOW, str(WINDOW_MODE_WORDS[value]), {}), "window", line)
	if member == "size":
		var pair: String = _dimension_pair(value)
		if pair.is_empty():
			return {}
		return _with_pattern(_sentence(OBJECT_WINDOW, "Set size to {value}",
			{"value": [pair, "value"]}), "window", line)
	if member == "title":
		return _with_pattern(_sentence(OBJECT_WINDOW, "Set title to {value}",
			{"value": [expression_text(value, context), "value"]}), "window", line)
	if member == "position":
		return _with_pattern(_sentence(OBJECT_WINDOW, "Set position to {value}",
			{"value": [expression_text(value, context), "value"]}), "window", line)
	if member == "always_on_top":
		return _with_pattern(_sentence(OBJECT_WINDOW, "Set always on top to {value}",
			{"value": [expression_text(value, context), "value"]}), "window", line)
	return {}


## V5. `Vector2i(1280, 720)` as the size a reader says out loud. "" when the value is anything else,
## which keeps the plain reading rather than promising a size the line does not spell.
static func _dimension_pair(value: String) -> String:
	var call: Dictionary = call_parts(value.strip_edges())
	if call.is_empty() or not str(call.get("target", "")).is_empty():
		return ""
	if not VECTOR_CONSTRUCTORS.has(str(call.get("method", ""))):
		return ""
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if args.size() != 2:
		return ""
	return "%s × %s" % [args[0].strip_edges(), args[1].strip_edges()]


## V5. The member a `get_window().x` / `get_tree().root.x` target names, or "" when the target is not
## a window property at all.
static func _window_member(target: String) -> String:
	for head: String in ["get_window().", "get_tree().root."]:
		if target.begins_with(head):
			var member: String = target.substr(head.length())
			return member if is_identifier(member) else ""
	return ""


## V5. The member a `get_viewport().x` target names, or "" for anything else.
static func _viewport_member(target: String) -> String:
	const HEAD := "get_viewport()."
	if not target.begins_with(HEAD):
		return ""
	var member: String = target.substr(HEAD.length())
	return member if is_identifier(member) else ""


## V5. `DisplayServer.window_set_vsync_mode(...)` in the on/off an options menu offers. Both the bare
## constant a hand-written line passes and the `A if flag else B` the Set VSync action writes.
static func _vsync_statement(line: String) -> Dictionary:
	const HEAD := "DisplayServer.window_set_vsync_mode("
	if not line.begins_with(HEAD) or not line.ends_with(")"):
		return {}
	var inner: String = line.substr(HEAD.length(), line.length() - HEAD.length() - 1).strip_edges()
	var first_comma: int = top_level_index(inner, ", ")
	if first_comma > 0:
		inner = inner.substr(0, first_comma).strip_edges()
	if WINDOW_VSYNC_WORDS.has(inner):
		return _with_pattern(_sentence(OBJECT_WINDOW, str(WINDOW_VSYNC_WORDS[inner]), {}), "window", line)
	# The picked row writes the switch as a ternary. Read as the toggle it is, with the flag named.
	var branches: Array = value_branches(inner)
	if branches.size() != 2:
		return {}
	var when_true: String = str((branches[0] as Dictionary).get("code", "")).strip_edges()
	var when_false: String = str((branches[1] as Dictionary).get("code", "")).strip_edges()
	var flag: String = str((branches[0] as Dictionary).get("condition", "")).strip_edges()
	if when_true != "DisplayServer.VSYNC_ENABLED" or when_false != "DisplayServer.VSYNC_DISABLED":
		return {}
	if flag == "true":
		return _with_pattern(_sentence(OBJECT_WINDOW, "Set vsync on", {}), "window", line)
	if flag == "false":
		return _with_pattern(_sentence(OBJECT_WINDOW, "Set vsync off", {}), "window", line)
	return _with_pattern(_sentence(OBJECT_WINDOW, "Set vsync to {value}",
		{"value": [flag, "value"]}), "window", line)


## V5. `img.save_png("user://shot.png")` - the step that writes a picture to a file, with the file
## named the way every other file row names one.
static func _image_save_statement(line: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(line)
	if call.is_empty():
		return {}
	if not IMAGE_SAVE_METHODS.has(str(call.get("method", ""))):
		return {}
	var receiver: String = str(call.get("target", "")).strip_edges()
	if not is_identifier(receiver):
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if args.size() < 1:
		return {}
	return _with_pattern(_sentence(OBJECT_SYSTEM, "Save image {name} as {value}", {
		"name": [receiver, "name"],
		"value": [bare_file_name(args[0], context), "value"]
	}), "window", line)


## V5 / V4. A path literal as just its file name, unquoted - what a row means when it says WHERE
## something went. Anything that is not a plain literal keeps its own expression reading.
static func bare_file_name(path_value: String, context: Dictionary) -> String:
	if not _is_string_literal(path_value):
		return expression_text(path_value, context)
	var path: String = _unquote(path_value.strip_edges())
	var slash_at: int = path.rfind("/")
	return path.substr(slash_at + 1) if slash_at >= 0 else path


## V5. The whole-expression readings of the render family: a screenshot, and one SubViewport's
## picture. "" when the text is neither, so every other expression is rewritten exactly as before.
static func render_expression(text: String) -> String:
	var trimmed: String = text.strip_edges()
	if SCREENSHOT_EXPRESSIONS.has(trimmed):
		return translate("a screenshot")
	const TAIL := ".get_texture()"
	if not trimmed.ends_with(TAIL):
		return ""
	var source: String = trimmed.substr(0, trimmed.length() - TAIL.length()).strip_edges()
	if source.begins_with("$"):
		source = source.substr(1)
		var slash_at: int = source.rfind("/")
		if slash_at >= 0:
			source = source.substr(slash_at + 1)
	if not is_identifier(source):
		return ""
	return "%s %s" % [source, translate("rendered as an image")]


## V4. The data-asset reading of one STATEMENT, or {} when the line is not one:
##
##   ResourceSaver.save(stats, "res://data/slime.tres")   System ▸ Save data asset stats as slime.tres
static func data_asset_statement(text: String, context: Dictionary) -> Dictionary:
	var line: String = text.strip_edges()
	var call: Dictionary = call_parts(line)
	if call.is_empty() or str(call.get("target", "")) != "ResourceSaver" \
			or str(call.get("method", "")) != "save":
		return {}
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if args.size() < 2:
		return {}
	return _with_pattern(_sentence(OBJECT_SYSTEM, "Save data asset {name} as {value}", {
		"name": [expression_text(args[0], context), "name"],
		"value": [bare_file_name(args[1], context), "value"]
	}), "data_asset", line)


## V4. `load("res://data/slime.tres") as EnemyStats` - the whole value, as the asset it fetches.
## "" for a load of anything that is not a data asset (a scene, a texture, an expression), which
## keeps the call reading those already have.
static func data_asset_expression(text: String) -> String:
	var trimmed: String = text.strip_edges()
	# `X as Type` is the same value with a promise about it; the promise is the row's chip, never
	# part of what the row says.
	var as_at: int = top_level_index(trimmed, " as ")
	if as_at > 0:
		trimmed = trimmed.substr(0, as_at).strip_edges()
	var call: Dictionary = call_parts(trimmed)
	if call.is_empty() or not str(call.get("target", "")).is_empty():
		return ""
	var head: String = str(call.get("method", ""))
	if head != "load" and head != "preload":
		return ""
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if args.size() != 1 or not _is_string_literal(args[0]):
		return ""
	var path: String = _unquote(args[0].strip_edges())
	if not DATA_ASSET_EXTENSIONS.has(path.get_extension()):
		return ""
	return "%s %s" % [translate("the data asset"), path.get_file()]


## V4. `stats.hp` where `stats` is a field holding a data asset - the possessive an event sheet says
## a record's field with. "" when the receiver is not a declared data asset, so an ordinary member
## read keeps the chain it is.
static func data_field_words(text: String, context: Dictionary) -> String:
	var trimmed: String = text.strip_edges()
	var dot_at: int = trimmed.find(".")
	if dot_at <= 0:
		return ""
	var receiver: String = trimmed.substr(0, dot_at)
	var field: String = trimmed.substr(dot_at + 1)
	if not is_identifier(receiver) or not is_identifier(field):
		return ""
	if not is_data_asset_type(_declared_type_of(receiver, context)):
		return ""
	return "%s's %s" % [receiver, field]


## V4. True when a declared type IS a data asset - Resource itself, any engine Resource subclass, or
## a project class the class list says extends one. A name nobody declared is not one.
static func is_data_asset_type(type_name: String) -> bool:
	var bare: String = type_name.strip_edges()
	if bare.is_empty():
		return false
	if bare == "Resource":
		return true
	if ClassDB.class_exists(bare):
		return ClassDB.is_parent_class(bare, "Resource")
	return _project_class_is_resource(bare)


## V4. Whether one of the PROJECT's own `class_name` scripts extends a Resource, walked through the
## global class list Godot already keeps (so no script is loaded to answer it). The walk follows the
## chain of project classes until it reaches an engine class, and gives up on a cycle.
static func _project_class_is_resource(class_name_str: String) -> bool:
	var bases: Dictionary = {}
	for entry: Variant in ProjectSettings.get_global_class_list():
		var described: Dictionary = entry
		bases[str(described.get("class", ""))] = str(described.get("base", ""))
	var current: String = class_name_str
	for _step: int in range(32):
		if not bases.has(current):
			return ClassDB.class_exists(current) and ClassDB.is_parent_class(current, "Resource")
		var base: String = str(bases[current])
		if base.is_empty() or base == current:
			return false
		current = base
	return false
# ── Batch 9: the behaviors a hand-rolled script writes, in the behavior's own words ────────────────
# T5 / T6 / T7 / T23 / T25 / T26. Each shape below is one a reader of event sheets already has a name
# for - line of sight, dragging, an anchor, a solid, a jump-thru, an overlap at an offset, a weighted
# choice, a seed, the date. The lines stay exactly as the file holds them; only the words change, and
# every event holding one claims its pattern beside the source lines that are its evidence, so the
# chip and the Manual read one set of facts rather than each re-deriving them.


## T5. What a line-of-sight test is cast with. Matched through ClassDB, so a subclass answers alike.
const SIGHT_RAY_CLASSES: PackedStringArray = ["RayCast2D", "RayCast3D"]

## T6. The anchor presets an event sheet has a corner name for, by the constant a line writes. The
## engine's own spelling is what a reader typed; the word beside it is where the thing ends up.
const ANCHOR_PRESET_WORDS: Dictionary = {
	"PRESET_TOP_LEFT": "top left", "PRESET_TOP_RIGHT": "top right",
	"PRESET_BOTTOM_LEFT": "bottom left", "PRESET_BOTTOM_RIGHT": "bottom right",
	"PRESET_CENTER_TOP": "centre top", "PRESET_CENTER_BOTTOM": "centre bottom",
	"PRESET_CENTER_LEFT": "centre left", "PRESET_CENTER_RIGHT": "centre right",
	"PRESET_CENTER": "centre", "PRESET_FULL_RECT": "full rect",
	"PRESET_LEFT_WIDE": "left edge", "PRESET_RIGHT_WIDE": "right edge",
	"PRESET_TOP_WIDE": "top edge", "PRESET_BOTTOM_WIDE": "bottom edge",
	"PRESET_VCENTER_WIDE": "middle row", "PRESET_HCENTER_WIDE": "middle column"
}

## T6. The side each anchor and each margin property names, so a write reads as the edge it moves.
const ANCHOR_SIDE_WORDS: Dictionary = {
	"anchor_left": "left", "anchor_top": "top", "anchor_right": "right", "anchor_bottom": "bottom"
}
const MARGIN_SIDE_WORDS: Dictionary = {
	"offset_left": "left", "offset_top": "top", "offset_right": "right", "offset_bottom": "bottom"
}

## T6. The object the drag rows and the anchor rows are filed under - the two behaviors a reader of
## event sheets reaches for when a thing is picked up with the pointer or pinned to a corner.
const BEHAVIOR_DRAG_DROP := "Drag & Drop"
const BEHAVIOR_ANCHOR := "Anchor"
## T7. What a body IS to the others. Neither is a pack: they are what a Godot body already does, and
## naming them is the whole of the reading.
const BEHAVIOR_SOLID := "Solid"
const BEHAVIOR_JUMP_THRU := "Jump-thru"
## T25. The object the seeds and the noise are filed under, in the shipped pack's own name.
const OBJECT_ADVANCED_RANDOM := "Advanced Random"

## T25. The noise a FastNoiseLite hands back, by the call that reads it. The number of dimensions is
## the tail; the head is the noise TYPE, which the file states separately.
const NOISE_CALL_DIMENSIONS: Dictionary = {
	"get_noise_1d": "1d", "get_noise_2d": "2d", "get_noise_3d": "3d"
}

## T25. The noise types the Advanced Random object has a word for, by the constant a line writes. A
## file that never states one is read with the plain `Noise` head, because Godot's own default is a
## smoothed simplex and printing a name nobody wrote would be a guess.
const NOISE_TYPE_WORDS: Dictionary = {
	"TYPE_PERLIN": "Perlin", "TYPE_SIMPLEX": "Simplex", "TYPE_SIMPLEX_SMOOTH": "Simplex",
	"TYPE_CELLULAR": "Cellular", "TYPE_VALUE": "Value", "TYPE_VALUE_CUBIC": "ValueCubic"
}

## T26. The Date object's whole-expression reads, by the `Time` call each is written as.
## The field spellings come FIRST: a row picked out of the Date section writes the whole call with the
## field on the end, and replacing the call alone would leave `Date.Now.hour` behind.
const DATE_CALL_WORDS: Dictionary = {
	"Time.get_datetime_dict_from_system().hour": "Date.Hour",
	"Time.get_datetime_dict_from_system().minute": "Date.Minute",
	"Time.get_datetime_dict_from_system().second": "Date.Second",
	"Time.get_datetime_dict_from_system().year": "Date.Year",
	"Time.get_datetime_dict_from_system().month": "Date.Month",
	"Time.get_datetime_dict_from_system().day": "Date.Day",
	"Time.get_datetime_dict_from_system().weekday": "Date.Weekday",
	"Time.get_unix_time_from_system()": "Date.Now",
	"Time.get_date_string_from_system()": "Date.Today",
	"Time.get_time_string_from_system()": "Date.TimeString"
}

## T6. The three spellings of "where the pointer is", so a drag reads the same whichever one a file
## happens to use.
const MOUSE_POSITION_CALLS: PackedStringArray = [
	"get_global_mouse_position()", "get_viewport().get_mouse_position()", "get_local_mouse_position()"
]

## T7. The shapes a body's Solid is made of.
const COLLISION_SHAPE_CLASSES: PackedStringArray = [
	"CollisionShape2D", "CollisionShape3D", "CollisionPolygon2D", "CollisionPolygon3D"
]

## T26. The fields of a datetime dictionary, as the Date object's own expressions. Only a local the
## file filled FROM the system clock is read this way - `enemy.hour` is somebody's own property.
const DATE_FIELD_WORDS: Dictionary = {
	"hour": "Date.Hour", "minute": "Date.Minute", "second": "Date.Second",
	"year": "Date.Year", "month": "Date.Month", "day": "Date.Day", "weekday": "Date.Weekday"
}


## T5 / T25 / T26. The whole-expression reads the Line of Sight, Advanced Random and Date words own,
## applied to a VALUE before any other rewriting sees the Godot spellings they are matched against.
## Returns the text unchanged when the file states none of the facts these words are built on.
static func behavior_expression_words(text: String, context: Dictionary) -> String:
	var out: String = _date_words(text, context)
	out = _weighted_choice_words(out)
	out = _noise_words(out, context)
	return _line_of_sight_words(out, context)


## T26. `Time.get_*_from_system()` and the fields read out of a datetime dictionary, in the Date
## object's words.
static func _date_words(text: String, context: Dictionary) -> String:
	var out: String = text
	for call_text: String in DATE_CALL_WORDS:
		if out.contains(call_text):
			out = out.replace(call_text, str(DATE_CALL_WORDS[call_text]))
	var clocks: Dictionary = context.get("datetime_locals", {})
	if clocks.is_empty() or not out.contains("."):
		return out
	for local_name: Variant in clocks:
		for field: Variant in DATE_FIELD_WORDS:
			out = replace_whole_token(out, "%s.%s" % [str(local_name), str(field)],
				str(DATE_FIELD_WORDS[field]))
	return out


## T25. `["coin", "gem"][rng.rand_weighted([70, 20])]` - a list indexed by a weighted draw is ONE
## thought, and an event sheet writes it as one: each choice with the weight that is its own. Claimed
## only when both lists are literal and the same length, because a half-paired reading would show a
## reader an odds table that is not the one the file states.
static func _weighted_choice_words(text: String) -> String:
	const DRAW := ".rand_weighted("
	var whole: String = text.strip_edges()
	if not whole.contains(DRAW) or not whole.begins_with("[") or not whole.ends_with("]"):
		return text
	var choices_end: int = closing_bracket(whole, 0)
	if choices_end < 0 or whole.length() <= choices_end + 1 or whole[choices_end + 1] != "[":
		return text
	if closing_bracket(whole, choices_end + 1) != whole.length() - 1:
		return text
	var choices: PackedStringArray = split_top_level(whole.substr(1, choices_end - 1), ",")
	var draw: String = whole.substr(choices_end + 2, whole.length() - choices_end - 3).strip_edges()
	var weights_at: int = draw.find(DRAW)
	if weights_at <= 0 or not draw.ends_with(")"):
		return text
	var inside: String = draw.substr(weights_at + DRAW.length(),
		draw.length() - weights_at - DRAW.length() - 1).strip_edges()
	if not inside.begins_with("[") or not inside.ends_with("]"):
		return text
	var weights: PackedStringArray = split_top_level(inside.substr(1, inside.length() - 2), ",")
	if weights.size() != choices.size() or choices.is_empty():
		return text
	var pairs: PackedStringArray = PackedStringArray()
	for index: int in choices.size():
		pairs.append("%s %s" % [choices[index].strip_edges(), weights[index].strip_edges()])
	return "%s(%s)" % [translate("choose weighted"), ", ".join(pairs)]


## T25. `noise.get_noise_2d(x, y)` as the Advanced Random object's own expression, with the noise TYPE
## in the name when the file states one. Only a local the file made a FastNoiseLite in is claimed.
static func _noise_words(text: String, context: Dictionary) -> String:
	var locals: Dictionary = context.get("noise_locals", {})
	if locals.is_empty() or not text.contains(".get_noise_"):
		return text
	var out: String = text
	var noise_type: String = str(context.get("noise_type", "")).strip_edges()
	for local_name: Variant in locals:
		for call_name: Variant in NOISE_CALL_DIMENSIONS:
			var head: String = "%s.%s(" % [str(local_name), str(call_name)]
			if not out.contains(head):
				continue
			out = out.replace(head, "AdvancedRandom.%s%s(" % [
				noise_type if not noise_type.is_empty() else "Noise",
				str(NOISE_CALL_DIMENSIONS[call_name])])
	return out


## T5. `not ray.is_colliding() or ray.get_collider() == t` - the whole test a hand-rolled line-of-sight
## function ends with, as the ONE condition the Line of Sight behavior publishes. Only a ray the file
## itself declared is claimed, and the range is named only when the file guards on one.
static func _line_of_sight_words(text: String, context: Dictionary) -> String:
	var rays: Dictionary = context.get("sight_rays", {})
	if rays.is_empty() or not text.contains("is_colliding()"):
		return text
	var parts: PackedStringArray = split_top_level(text.strip_edges(), " or ")
	if parts.size() != 2:
		return text
	const COLLIDING := ".is_colliding()"
	var negated: String = parts[0].strip_edges()
	if not negated.begins_with("not ") or not negated.ends_with(COLLIDING):
		return text
	var ray: String = negated.substr(4, negated.length() - 4 - COLLIDING.length()).strip_edges()
	if not rays.has(ray):
		return text
	var hit: String = parts[1].strip_edges()
	var hit_at: int = top_level_index(hit, " == ")
	if hit_at < 0 or hit.substr(0, hit_at).strip_edges() != "%s.get_collider()" % ray:
		return text
	var words: String = translate("{object} has line of sight to {target}") \
		.replace("{object}", script_object(context)) \
		.replace("{target}", hit.substr(hit_at + 4).strip_edges())
	var sight_range: String = str(context.get("sight_range", "")).strip_edges()
	if sight_range.is_empty():
		return words
	return "%s (%s %s)" % [words, translate("within"), sight_range]


## The index at which the bracketed group `text` opens at `open_at` closes, or -1 when it never does.
## Quote-aware, so a `"]"` inside a literal never closes a list.
static func closing_bracket(text: String, open_at: int) -> int:
	var depth: int = 0
	var quote: String = ""
	for index: int in range(open_at, text.length()):
		var character: String = text[index]
		if not quote.is_empty():
			if character == quote:
				quote = ""
			continue
		if character == "\"" or character == "'":
			quote = character
			continue
		if character == "[":
			depth += 1
		elif character == "]":
			depth -= 1
			if depth == 0:
				return index
	return -1


## `needle` replaced by `replacement` wherever it stands as a WHOLE token - never inside a longer
## name and never as the tail of a longer dotted path, which is what keeps `now.hour` a clock and
## `tomorrow.now.hour` somebody else's property.
static func replace_whole_token(text: String, needle: String, replacement: String) -> String:
	if not text.contains(needle):
		return text
	var pattern: RegEx = RegEx.create_from_string(
		"(?<![\\w.])%s(?![\\w])" % needle.replace(".", "\\."))
	if pattern == null:
		return text
	return pattern.sub(text, replacement, true)


## T6 / T7 / T25. The behaviors' reading of one STATEMENT, or {} when none of them claims it. Called
## from `statement()` ahead of the compound / assignment / call split, because each shape below is a
## whole thought that the general readings would each describe one property write of.
static func behavior_words_statement(text: String, context: Dictionary) -> Dictionary:
	var dragged: Dictionary = _drag_drop_statement(text, context)
	if not dragged.is_empty():
		return dragged
	var anchored: Dictionary = _anchor_statement(text, context)
	if not anchored.is_empty():
		return anchored
	var solid: Dictionary = _solid_statement(text, context)
	if not solid.is_empty():
		return solid
	return _advanced_random_statement(text, context)


## T5 / T6 / T23. The behaviors' reading of one CONDITION, or {} when none of them claims it.
static func behavior_words_condition(text: String, context: Dictionary) -> Dictionary:
	var dragging: Dictionary = _drag_drop_condition(text, context)
	if not dragging.is_empty():
		return dragging
	return _overlap_offset_condition(text, context)


## T6. The three steps a hand-rolled drag is written as: the flag going up, the grab offset being
## remembered, and the follow that keeps it. Every one is claimed only for a name this file itself
## proved is part of a drag, so an ordinary boolean is never dressed up as one.
static func _drag_drop_statement(text: String, context: Dictionary) -> Dictionary:
	var at: int = top_level_index(text, " = ")
	if at <= 0:
		return {}
	var target: String = text.substr(0, at).strip_edges().trim_prefix("self.")
	var value: String = text.substr(at + 3).strip_edges()
	var object_name: String = script_object(context)
	var flags: Dictionary = context.get("drag_flags", {})
	if flags.has(target):
		if value == "true":
			return _sentence(object_name, "%s ▸ Start dragging" % BEHAVIOR_DRAG_DROP, {})
		if value == "false":
			return _sentence(object_name, "%s ▸ Drop" % BEHAVIOR_DRAG_DROP, {})
		return {}
	var offsets: Dictionary = context.get("drag_offsets", {})
	if offsets.has(target) and is_grab_offset_value(value):
		return _sentence(object_name, "%s ▸ Remember the grab offset" % BEHAVIOR_DRAG_DROP, {})
	if not OWN_POSITION_NAMES.has(target):
		return {}
	var plus_at: int = top_level_index(value, " + ")
	if plus_at <= 0 or not MOUSE_POSITION_CALLS.has(value.substr(0, plus_at).strip_edges()):
		return {}
	if not offsets.has(value.substr(plus_at + 3).strip_edges()):
		return {}
	return _sentence(object_name,
		"%s ▸ Follow the cursor (keeping the grab offset)" % BEHAVIOR_DRAG_DROP, {})


## T6. True when a value IS the gap between where a thing is and where the pointer is - the one
## number a drag has to remember for the thing not to jump under the cursor.
static func is_grab_offset_value(value: String) -> bool:
	var minus_at: int = top_level_index(value, " - ")
	if minus_at <= 0:
		return false
	if not OWN_POSITION_NAMES.has(value.substr(0, minus_at).strip_edges()):
		return false
	return MOUSE_POSITION_CALLS.has(value.substr(minus_at + 3).strip_edges())


## T6. `if dragging:` - with the file's own drag proved, the flag is the Drag & Drop behavior's own
## question rather than a boolean nobody named.
static func _drag_drop_condition(text: String, context: Dictionary) -> Dictionary:
	var flags: Dictionary = context.get("drag_flags", {})
	if flags.is_empty():
		return {}
	var bare: String = text.strip_edges().trim_prefix("self.")
	if flags.has(bare):
		return _sentence(script_object(context), "%s ▸ Is dragging" % BEHAVIOR_DRAG_DROP, {})
	if bare.begins_with("not ") and flags.has(bare.substr(4).strip_edges()):
		return _sentence(script_object(context), "%s ▸ Is not dragging" % BEHAVIOR_DRAG_DROP, {})
	return {}


## T6. Where a Control ends up when the window changes size, in the Anchor behavior's words: the
## preset by the corner it names, and a single anchor or margin write by the edge it moves.
static func _anchor_statement(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if not call.is_empty():
		var method: String = str(call.get("method", ""))
		var arguments: PackedStringArray = call.get("args", PackedStringArray())
		if method in ["set_anchors_preset", "set_anchors_and_offsets_preset"] and arguments.size() >= 1:
			var preset: String = arguments[0].strip_edges()
			var dot_at: int = preset.rfind(".")
			if dot_at >= 0:
				preset = preset.substr(dot_at + 1)
			if not ANCHOR_PRESET_WORDS.has(preset):
				return {}
			return _sentence(_receiver_object(str(call.get("target", "")), context),
				"%s ▸ Anchor to {corner} (of the window)" % BEHAVIOR_ANCHOR,
				{"corner": [translate(str(ANCHOR_PRESET_WORDS[preset])), "value"]})
		return {}
	var at: int = top_level_index(text, " = ")
	if at <= 0:
		return {}
	var target: String = text.substr(0, at).strip_edges().trim_prefix("self.")
	var value: String = expression_text(text.substr(at + 3).strip_edges(), context)
	var member: String = target
	var owner_name: String = ""
	var dot_at: int = target.rfind(".")
	if dot_at > 0:
		owner_name = target.substr(0, dot_at)
		member = target.substr(dot_at + 1)
	var object_name: String = _receiver_object(owner_name, context)
	if ANCHOR_SIDE_WORDS.has(member):
		return _sentence(object_name, "%s ▸ Set {side} anchor to {value}" % BEHAVIOR_ANCHOR, {
			"side": [translate(str(ANCHOR_SIDE_WORDS[member])), "value"],
			"value": [value, "value"]
		})
	if MARGIN_SIDE_WORDS.has(member):
		return _sentence(object_name, "%s ▸ Set {side} margin to {value}" % BEHAVIOR_ANCHOR, {
			"side": [translate(str(MARGIN_SIDE_WORDS[member])), "value"],
			"value": [value, "value"]
		})
	return {}


## T7. What a body is to the others: a shape switched off is the Solid going away, a one-way shape is
## the Jump-thru, and a collision layer is the layer the Solid is on. The rows belong to the OBJECT,
## never to the collision shape hanging under it - the shape is Godot's filing, and a reader looks for
## the platform.
static func _solid_statement(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if not call.is_empty():
		var arguments: PackedStringArray = call.get("args", PackedStringArray())
		if str(call.get("method", "")) != "set_collision_layer_value" or arguments.size() != 2:
			return {}
		var index_text: String = arguments[0].strip_edges()
		var on: String = arguments[1].strip_edges()
		if not index_text.is_valid_int() or (on != "true" and on != "false"):
			return {}
		var layer_words: String = solid_layer_words(index_text.to_int(), context)
		var template: String = "%s ▸ On layer {layer}" % BEHAVIOR_SOLID if on == "true" \
			else "%s ▸ Not on layer {layer}" % BEHAVIOR_SOLID
		return _sentence(_receiver_object(str(call.get("target", "")), context), template,
			{"layer": [layer_words, "value"]})
	var at: int = top_level_index(text, " = ")
	if at <= 0:
		return {}
	var target: String = text.substr(0, at).strip_edges().trim_prefix("self.")
	var value: String = text.substr(at + 3).strip_edges()
	if value != "true" and value != "false":
		return {}
	var member: String = target
	var owner_name: String = ""
	var dot_at: int = target.rfind(".")
	if dot_at > 0:
		owner_name = target.substr(0, dot_at)
		member = target.substr(dot_at + 1)
	# The shape is a child of the thing the row is about, so the row says the thing. A shape reached
	# through some OTHER object keeps that object's name, because then it is not this one's shape.
	var object_name: String = script_object(context) if is_own_child_reference(owner_name) \
		else _receiver_object(owner_name, context)
	if member == "one_way_collision":
		var jump_thru: String = "%s ▸ Set enabled (one-way: solid from above only)" % BEHAVIOR_JUMP_THRU \
			if value == "true" else "%s ▸ Set disabled" % BEHAVIOR_JUMP_THRU
		return _sentence(object_name, jump_thru, {})
	if member != "disabled" or not is_collision_shape_reference(owner_name, context):
		return {}
	var solid: String = "%s ▸ Set disabled" % BEHAVIOR_SOLID if value == "true" \
		else "%s ▸ Set enabled" % BEHAVIOR_SOLID
	return _sentence(object_name, solid, {})


## T7. True when a receiver names a node UNDER this script's own node - a `$Shape` path or nothing at
## all. Those two are the file talking about itself; anything else names somebody else.
static func is_own_child_reference(receiver: String) -> bool:
	var text: String = receiver.strip_edges()
	return text.is_empty() or text == "self" or text.begins_with("$") or text.begins_with("%")


## T7. True when a receiver is a collision shape - its own class where the sheet knows one, else the
## name a `$CollisionShape2D` path spells out. A plain `disabled` on anything else is an ordinary
## property and reads as one.
static func is_collision_shape_reference(receiver: String, context: Dictionary) -> bool:
	var text: String = receiver.strip_edges()
	if text.is_empty():
		return false
	var known: String = object_class_of(object_of_reference(text), context)
	if not known.is_empty():
		return _class_is_any(known, COLLISION_SHAPE_CLASSES)
	for shape_class: String in COLLISION_SHAPE_CLASSES:
		if text.contains(shape_class):
			return true
	return false


## T7. The name the project gave a physics layer, with its number after it - `World (layer 1)`. A
## project that never named the layer says the number alone, because inventing a name would be a
## guess about somebody else's setup.
static func solid_layer_words(index: int, context: Dictionary) -> String:
	var dimension: String = "3d_physics" if str(context.get("self_class", "")).contains("3D") \
		else "2d_physics"
	var named: String = physics_layer_name(index, dimension)
	if named.is_empty():
		return str(index)
	return "%s (%s %d)" % [named, translate("layer"), index]


## T25. The seed rows the Advanced Random object publishes. `hash("level-1")` is Godot's way of
## turning a name into a number, so the row shows the NAME, which is what the author chose.
static func _advanced_random_statement(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text)
	if not call.is_empty():
		var method: String = str(call.get("method", ""))
		var arguments: PackedStringArray = call.get("args", PackedStringArray())
		if method == "randomize" and arguments.is_empty():
			return _sentence(OBJECT_ADVANCED_RANDOM, "Randomize seed", {})
		if method != "seed" or arguments.size() != 1 or not str(call.get("target", "")).is_empty():
			return {}
		return _sentence(OBJECT_ADVANCED_RANDOM, "Set seed to {seed}",
			{"seed": [seed_words(arguments[0], context), "value"]})
	var at: int = top_level_index(text, " = ")
	if at <= 0:
		return {}
	var target: String = text.substr(0, at).strip_edges().trim_prefix("self.")
	var dot_at: int = target.rfind(".")
	if dot_at <= 0:
		return {}
	var owner_name: String = target.substr(0, dot_at)
	var member: String = target.substr(dot_at + 1)
	if member == "noise_type" and (context.get("noise_locals", {}) as Dictionary).has(owner_name):
		var constant_name: String = text.substr(at + 3).strip_edges()
		var last_dot: int = constant_name.rfind(".")
		if last_dot >= 0:
			constant_name = constant_name.substr(last_dot + 1)
		if not NOISE_TYPE_WORDS.has(constant_name):
			return {}
		return _sentence(OBJECT_ADVANCED_RANDOM, "Set noise type to {type}",
			{"type": [str(NOISE_TYPE_WORDS[constant_name]), "value"]})
	if member != "seed" or not (context.get("random_locals", {}) as Dictionary).has(owner_name):
		return {}
	return _sentence(OBJECT_ADVANCED_RANDOM, "Set seed to {seed}",
		{"seed": [seed_words(text.substr(at + 3), context), "value"]})


## T25. A seed value as the author wrote it: the name inside a `hash(...)` when there is one, because
## that is the thing a reader recognises, and the plain value otherwise.
static func seed_words(value: String, context: Dictionary) -> String:
	var text: String = value.strip_edges()
	if text.begins_with("hash(") and text.ends_with(")") and closing_paren(text, 4) == text.length() - 1:
		return expression_text(text.substr(5, text.length() - 6), context)
	return expression_text(text, context)


## T23. `test_move(transform, Vector2(0, 1))` and the test-only `move_and_collide` twin - the "is
## there ground just below me" question, in the words an event sheet asks it with. Only a TEST is
## claimed: a `move_and_collide` that actually moves the body is a step, not a question.
static func _overlap_offset_condition(text: String, context: Dictionary) -> Dictionary:
	var call: Dictionary = call_parts(text.strip_edges().trim_prefix("not "))
	if call.is_empty():
		return {}
	var method: String = str(call.get("method", ""))
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	var offset: String = ""
	if method == "test_move" and arguments.size() >= 2:
		offset = arguments[1].strip_edges()
	elif method == "move_and_collide" and arguments.size() >= 2 and arguments[1].strip_edges() == "true":
		offset = arguments[0].strip_edges()
	if offset.is_empty():
		return {}
	var object_name: String = _receiver_object(str(call.get("target", "")), context)
	var template: String = "Is not overlapping at offset {offset} (a solid)" \
		if text.strip_edges().begins_with("not ") else "Is overlapping at offset {offset} (a solid)"
	return _sentence(object_name, template, {"offset": [expression_text(offset, context), "value"]})


## T23. The object a `for a in x.get_overlapping_areas()` loop is walking the overlaps OF, or "" when
## the collection is anything else. What turns the loop's own row into `For each a overlapping Player`.
static func overlap_collection_source(collection: String) -> String:
	var text: String = collection.strip_edges()
	for method: String in ["get_overlapping_areas", "get_overlapping_bodies"]:
		var tail: String = ".%s()" % method
		if not text.ends_with(tail):
			continue
		var owner_name: String = text.substr(0, text.length() - tail.length()).strip_edges()
		if owner_name.is_empty():
			return ""
		return object_of_reference(owner_name)
	return ""
# ── U1: vectors and colours read as words ────────────────────────────────────────
#
# The two value types every game line touches. A beginner reads `normalized()` and `darkened(0.2)`
# as code, so each operation gets the word an event sheet already has for it, and Godot's own
# spelling stays one hover away on the row. Nothing here decides what is emitted: every shape below
# is claimed exactly or not at all, and the value the row holds is untouched.


## U1. The colour channels that name a colour anybody says out loud, so `Color(1, 0, 0, 0.5)` reads
## "red at 50% opacity" rather than four numbers. Only the colours a reader would name are here; any
## other mix keeps its channels, which is the honest answer.
const COLOUR_CHANNEL_WORDS: Dictionary = {
	"1, 0, 0": "red", "0, 1, 0": "green", "0, 0, 1": "blue",
	"1, 1, 1": "white", "0, 0, 0": "black", "1, 1, 0": "yellow",
	"0, 1, 1": "cyan", "1, 0, 1": "magenta"
}

## U1. The speeds an event sheet has ONE word for. `velocity.length()` is the speed - a reader asks
## "how fast", never "how long is the velocity vector".
const SPEED_RECEIVERS: PackedStringArray = ["velocity", "linear_velocity"]


## U1. A whole vector or colour expression that has its own settled sentence, or "" when the text is
## anything else. Asked BEFORE the general call rewriting, because the shape here is decided by the
## expression as a whole - the innermost-first pass would have taken the bracket group apart first.
static func vector_colour_words(text: String, context: Dictionary) -> String:
	return _direction_between_words(text, context)


## U1. `(a.position - b.position).normalized()` is the one thing every chase line means: the
## direction from B to A. Claimed only when the bracket group is exactly one subtraction and the whole
## expression is that group normalized, so `(a - b + c).normalized()` keeps its own code.
static func _direction_between_words(text: String, context: Dictionary) -> String:
	const TAIL := ").normalized()"
	var trimmed: String = text.strip_edges()
	if not trimmed.begins_with("(") or not trimmed.ends_with(TAIL):
		return ""
	if closing_paren(trimmed, 0) != trimmed.length() - TAIL.length():
		return ""
	var inner: String = trimmed.substr(1, trimmed.length() - TAIL.length() - 1)
	var minus_at: int = top_level_index(inner, " - ")
	if minus_at <= 0:
		return ""
	var to_point: String = inner.substr(0, minus_at).strip_edges()
	var from_point: String = inner.substr(minus_at + 3).strip_edges()
	if to_point.is_empty() or from_point.is_empty():
		return ""
	return _fill(translate("the direction from {from} to {to}"),
		{"from": _point_object(from_point, context), "to": _point_object(to_point, context)})


## U1. The vector and colour methods whose reading needs the receiver, in the words the sheet has for
## each operation. "" for anything not claimed exactly, so the general tables still answer.
static func vector_colour_receiver_words(receiver: String, method: String,
		arguments: PackedStringArray) -> String:
	match method:
		"normalized":
			if arguments.is_empty():
				return _fill(translate("unit vector of {value}"), {"value": receiver})
		"length":
			if arguments.is_empty() and SPEED_RECEIVERS.has(receiver.trim_prefix("self.")):
				return translate("the speed")
		"dot":
			if arguments.size() == 1:
				return _fill(translate("how much {a} points along {b} (-1 to 1)"),
					{"a": receiver, "b": arguments[0]})
		"rotated":
			if arguments.size() == 1:
				# The innermost-first call pass has already read a `deg_to_rad(45)` argument as "45°",
				# so a value that arrives in degrees is taken as it stands.
				var degrees: String = arguments[0].strip_edges() if arguments[0].strip_edges().ends_with("°") \
					else _angle_degrees(arguments[0])
				if not degrees.is_empty():
					return _fill(translate("{value} turned {angle}"),
						{"value": receiver, "angle": degrees})
		"darkened", "lightened":
			if arguments.size() == 1 and arguments[0].strip_edges().is_valid_float():
				var shade: String = translate("darker" if method == "darkened" else "lighter")
				return "%s, %s %s" % [receiver, _percent_words(arguments[0], {}), shade]
		"from_hsv":
			if receiver == "Color":
				return _colour_from_hsv_words(arguments)
		"from_string":
			if receiver == "Color" and arguments.size() >= 1:
				return _fill(translate("colour from {value}"), {"value": arguments[0]})
	return ""


## U1. `Color.from_hsv(0.3, 1, 1)` as the colour it describes. Full brightness is what a reader
## assumes, so only the channels that say something appear.
static func _colour_from_hsv_words(arguments: PackedStringArray) -> String:
	if arguments.size() < 1 or arguments.size() > 4:
		return ""
	for argument: String in arguments:
		if not argument.strip_edges().is_valid_float():
			return ""
	var words: String = _fill(translate("colour from hue {hue}"),
		{"hue": _percent_words(arguments[0], {})})
	if arguments.size() >= 2:
		words += ", " + (translate("full saturation") if arguments[1].strip_edges().to_float() >= 1.0
			else _fill(translate("{amount} saturation"), {"amount": _percent_words(arguments[1], {})}))
	if arguments.size() >= 3 and arguments[2].strip_edges().to_float() < 1.0:
		words += ", " + _fill(translate("{amount} brightness"),
			{"amount": _percent_words(arguments[2], {})})
	return words


## U1. `Color(1, 0, 0, 0.5)` as the colour anybody would say out loud, with its alpha as the opacity
## percentage an event sheet writes. A mix nobody has a word for keeps its channels.
static func colour_constructor_words(arguments: PackedStringArray) -> String:
	if arguments.size() < 3 or arguments.size() > 4:
		return ""
	for argument: String in arguments:
		if not argument.strip_edges().is_valid_float():
			return ""
	var channels: PackedStringArray = PackedStringArray()
	for index: int in 3:
		channels.append(number_lens(arguments[index].strip_edges()))
	var key: String = ", ".join(channels)
	var name_word: String = str(COLOUR_CHANNEL_WORDS.get(key, ""))
	var words: String = translate(name_word) if not name_word.is_empty() else key
	if arguments.size() == 4 and arguments[3].strip_edges().to_float() < 1.0:
		words += " " + _fill(translate("at {amount} opacity"),
			{"amount": _percent_words(arguments[3], {})})
	return words


## U1. `modulate = modulate.lerp(target, rate * delta)` is the one easing line every fade writes, and
## an event sheet says it in one verb. {} unless the assignment eases the SAME member it reads, which
## is what makes it an ease rather than a plain blend.
static func colour_ease_statement(object_name: String, member: String, assigned: String,
		context: Dictionary) -> Dictionary:
	if member != "modulate" and member != "self_modulate":
		return {}
	var call: Dictionary = call_parts(assigned.strip_edges())
	if call.is_empty() or str(call.get("method", "")) != "lerp":
		return {}
	if str(call.get("target", "")).strip_edges().trim_prefix("self.") != member:
		return {}
	var arguments: PackedStringArray = call.get("args", PackedStringArray())
	if arguments.size() != 2:
		return {}
	var rate: String = per_second_factor(arguments[1])
	if rate.is_empty():
		return {}
	return _sentence(object_name, "Ease colour toward {colour} at {rate}", {
		"colour": [expression_text(arguments[0], context), "value"],
		"rate": [expression_text(rate, context), "value"]
	})


# ── U4 / U5: data types and the scene tree, in one word each ─────────────────────
#
# The idioms a Godot script reaches for when it makes a value or looks something up. Each is one word
# in an event sheet, and every one of them was reading as the call it is. Display only, like the rest
# of this file: nothing here decides what is emitted.


## U4 / U5. The lookups and the makers whose reading needs the receiver. "" for anything not claimed
## exactly, so the general tables above still answer.
static func data_scene_receiver_words(receiver: String, method: String,
		arguments: PackedStringArray) -> String:
	match method:
		# U4. `Stats.new()` makes one of a type the file declares; only a Type-cased name is claimed,
		# because `handler.new()` on a variable is a call whose result nobody can name.
		"new":
			if arguments.is_empty() and is_identifier(receiver) and receiver == receiver.capitalize().replace(" ", ""):
				return _fill(translate("a new {type}"), {"type": receiver})
		# U4. A copy is a copy whether it is a resource, a node or a list. `duplicate(true)` is the
		# deep copy, which is still a copy - the flag is Godot's business, not the row's.
		"duplicate":
			if arguments.is_empty() or (arguments.size() == 1 and arguments[0].strip_edges() in ["true", "false"]):
				return _fill(translate("a copy of {value}"), {"value": receiver})
		# U5. A node's path, said the way a sheet says whose it is.
		"get_path":
			if arguments.is_empty():
				return _fill(translate("{object}'s path"), {"object": receiver})
		# U5. `find_child("HUD")` is the child named HUD. Only a literal name is claimed: a computed
		# one has nothing to show, and the search flags say how Godot looks rather than what it found.
		"find_child":
			if arguments.size() == 1 and _is_string_literal(arguments[0]):
				return _fill(translate("{object}'s child named {name}"),
					{"object": receiver, "name": _unquote(arguments[0])})
	return ""


## U5. The scene-tree spellings that are one word in an event sheet, on a whole value. Run after the
## node-path pass, so a `get_node("Boss")` has already become `$Boss` and both spellings answer alike.
static func scene_tree_words(text: String) -> String:
	if not text.contains("current_scene") and not text.contains("find_child(") and not text.contains("%"):
		return text
	var out: String = text
	if out.contains("%"):
		out = _unique_name_words(out)
	# The layout, and a node looked up inside it. The named form first: `the layout.$Boss` would read
	# as plumbing, and "Boss in the layout" is what the row is actually about.
	if out.contains("current_scene"):
		if _scene_node_regex == null:
			_scene_node_regex = RegEx.create_from_string(
				"get_tree\\(\\)\\.current_scene\\.\\$([A-Za-z_][A-Za-z0-9_/]*)")
		if _scene_node_regex != null:
			for found: RegExMatch in _scene_node_regex.search_all(out):
				out = out.replace(found.get_string(0), _fill(translate("{name} in the layout"),
					{"name": found.get_string(1)}))
		out = out.replace("get_tree().current_scene", translate("the layout"))
	# A receiver-less `find_child("HUD")` is the script's own child, and the object column has already
	# said whose - so the row says "the child named HUD" with nobody's name repeated in it.
	if out.contains("find_child("):
		if _find_child_regex == null:
			_find_child_regex = RegEx.create_from_string("(^|[^A-Za-z0-9_.$])find_child\\(&?\"([^\"]+)\"\\)")
		if _find_child_regex != null:
			for found: RegExMatch in _find_child_regex.search_all(out):
				out = out.replace(found.get_string(0), "%s%s" % [found.get_string(1),
					_fill(translate("the child named {name}"), {"name": found.get_string(2)})])
	return out


## U5. A node addressed by its unique name IS that object, so the row says the object with the way it
## was addressed as the aside it is.
##
## Quote-aware and value-start only, because `%` is three different things in GDScript: `%HealthBar`
## is the node, `"%d"` inside a literal is a format specifier somebody wrote, and `a % b` is the
## remainder. Only a `%` that begins a value and is followed straight away by a name is the node.
static func _unique_name_words(text: String) -> String:
	var out: String = ""
	var index: int = 0
	var value_start: bool = true
	while index < text.length():
		var character: String = text[index]
		if character == "\"" or character == "'":
			var quote_end: int = _string_end(text, index)
			out += text.substr(index, quote_end - index + 1)
			index = quote_end + 1
			value_start = false
			continue
		if character == "%" and value_start and index + 1 < text.length() \
				and (text[index + 1].is_valid_identifier() and not text[index + 1].is_valid_int()):
			var name_end: int = index + 1
			while name_end < text.length() and (text[name_end].is_valid_identifier() or text[name_end].is_valid_int()):
				name_end += 1
			out += "%s (%s)" % [text.substr(index + 1, name_end - index - 1), translate("unique name")]
			index = name_end
			value_start = false
			continue
		out += character
		# A value may start at the beginning, after an operator, or after an opening bracket or comma.
		value_start = character in [" ", "(", "[", ",", "=", "+", "-", "*", "/", ":"]
		index += 1
	return out


## The scene-tree matchers, compiled once for the session like the grammar's others.
static var _scene_node_regex: RegEx = null
static var _find_child_regex: RegEx = null


# ── U3: a note on a row ──────────────────────────────────────────────────────────
#
# A note on one action is how a sheet comments a single step, and a trailing `# ...` is how GDScript
# writes exactly that. It was already in the file; showing it costs nothing and the bytes never move.


## U3. The words a note carries when it is about work still to do. A comment line that opens with one
## of these belongs to the statement under it and is worth counting; every other comment line is a
## comment row of its own, which is what it has always been.
const TASK_NOTE_MARKERS: PackedStringArray = ["TODO", "FIXME", "HACK", "NOTE"]


## U3. One statement split from its trailing note, as [code, note]. The note is "" when the line has
## none, and the code is returned untouched in that case.
##
## Quote-aware, because a `#` inside a string literal is content somebody typed. Whitespace before the
## `#` is required for the same reason: `"#ff0000"` has already been skipped as a literal, but a bare
## `#` glued to the end of an expression is not the shape a note is written in.
static func trailing_comment(text: String) -> PackedStringArray:
	if not text.contains("#"):
		return PackedStringArray([text, ""])
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if character == "\"" or character == "'":
			index = _string_end(text, index) + 1
			continue
		if character == "#" and index > 0 and text[index - 1] in [" ", "\t"]:
			var code: String = text.substr(0, index).rstrip(" \t")
			var note: String = text.substr(index + 1).strip_edges()
			return PackedStringArray([text, ""]) if code.strip_edges().is_empty() or note.is_empty() \
				else PackedStringArray([code, note])
		index += 1
	return PackedStringArray([text, ""])


## U3. The marker a comment opens with ("TODO", "FIXME", …), or "" when it opens with none. The
## marker may be followed by a colon or by nothing at all, which is how both spellings are written.
static func task_note_marker(comment: String) -> String:
	var text: String = comment.strip_edges().trim_prefix("#").strip_edges()
	for marker: String in TASK_NOTE_MARKERS:
		if text == marker or text.begins_with("%s " % marker) or text.begins_with("%s:" % marker):
			return marker
	return ""


# ── U2: match PATTERNS read as the conditions they are ───────────────────────────
#
# Pattern matching is Godot's nicest control flow and a beginner's scariest cell. A match on plain
# values already reads as the Else-if chain it is (M37); these are the four patterns that say
# something a plain value cannot - a list of a certain shape, a table with certain entries, a name
# bound to whatever arrived, and that name with a guard on it. Each reads as the question it asks,
# with the names it binds as chips, and every arm keeps the exact bytes it was lifted from.


## U2. One `match` arm as the condition it is, or {} when the pattern is not one this reading claims.
##
## Returns {"text": the condition sentence ("" for an Else), "chips": the names the arm binds,
## "is_else": true when the arm matches whatever is left}. Strict on purpose: a nested pattern, an
## open-ended `..`, or anything with a call in it keeps the pattern text it was written as.
static func match_pattern_reading(subject: String, pattern: String, context: Dictionary) -> Dictionary:
	var text: String = pattern.strip_edges()
	var subject_words: String = subject.strip_edges()
	if text.is_empty() or subject_words.is_empty():
		return {}
	if text == "_":
		return {"text": "", "chips": PackedStringArray(), "is_else": true}
	if text.begins_with("[") and text.ends_with("]"):
		return _list_pattern_reading(subject_words, text.substr(1, text.length() - 2))
	if text.begins_with("{") and text.ends_with("}"):
		return _table_pattern_reading(subject_words, text.substr(1, text.length() - 2))
	if text.begins_with("var "):
		return _binding_pattern_reading(subject_words, text.substr(4), context)
	return {}


## U2. `["move", var x, var y]` - a list of a known length whose leading entries are known values.
## The bound names are chips, because they are what the arm's actions may then use.
static func _list_pattern_reading(subject: String, inner: String) -> Dictionary:
	var terms: PackedStringArray = split_top_level(inner, ", ")
	if terms.is_empty():
		return {}
	var leading: PackedStringArray = PackedStringArray()
	var chips: PackedStringArray = PackedStringArray()
	for term: String in terms:
		var entry: String = term.strip_edges()
		if entry.is_empty() or entry == "..":
			return {}
		if entry.begins_with("var "):
			var bound: String = entry.substr(4).strip_edges()
			if not is_identifier(bound):
				return {}
			chips.append(bound)
			continue
		# A known value AFTER a bound name has nothing to lead with, so the arm keeps its own text
		# rather than being described as starting with something it does not start with.
		if not chips.is_empty() or not _is_pattern_value(entry):
			return {}
		leading.append(entry)
	var count_words: String = _fill(translate("{subject} is a list of {count}"),
		{"subject": subject, "count": str(terms.size())})
	if leading.is_empty():
		return {"text": count_words, "chips": chips, "is_else": false}
	return {
		"text": "%s %s" % [count_words, _fill(translate("starting {values}"),
			{"values": ", ".join(leading)})],
		"chips": chips, "is_else": false
	}


## U2. `{"type": "hit", "amount": var a}` - a table with certain entries. An entry with a known value
## is part of the question; an entry that binds a name is a chip reading `key → name`, because what
## the arm gets out of the table is the other half of what the pattern says.
static func _table_pattern_reading(subject: String, inner: String) -> Dictionary:
	var entries: PackedStringArray = split_top_level(inner, ", ")
	if entries.is_empty():
		return {}
	var clauses: PackedStringArray = PackedStringArray()
	var chips: PackedStringArray = PackedStringArray()
	for term: String in entries:
		var entry: String = term.strip_edges()
		if entry.is_empty() or entry == "..":
			return {}
		var colon_at: int = top_level_index(entry, ": ")
		if colon_at < 0:
			# A bare key asks only that the table HAS it, which is a question worth reading.
			if not _is_pattern_value(entry):
				return {}
			clauses.append(_fill(translate("has {key}"), {"key": _pattern_key_words(entry)}))
			continue
		var key: String = entry.substr(0, colon_at).strip_edges()
		var value: String = entry.substr(colon_at + 2).strip_edges()
		if not _is_pattern_value(key):
			return {}
		if value.begins_with("var "):
			var bound: String = value.substr(4).strip_edges()
			if not is_identifier(bound):
				return {}
			chips.append("%s → %s" % [_pattern_key_words(key), bound])
			continue
		if not _is_pattern_value(value):
			return {}
		clauses.append("%s = %s" % [_pattern_key_words(key), value])
	var table_words: String = _fill(translate("{subject} is a table"), {"subject": subject})
	if clauses.is_empty():
		return {"text": table_words, "chips": chips, "is_else": false}
	return {
		"text": "%s %s" % [table_words, _fill(translate("with {clauses}"),
			{"clauses": (" %s " % translate("and")).join(clauses)})],
		"chips": chips, "is_else": false
	}


## U2. `var other` and `var other when other is String`. A bare binding matches whatever is left, so
## it reads as the Else it is with the name it binds beside it; a guard IS the question the arm asks,
## read through the ordinary condition grammar with the bound name standing for the subject - which is
## what it stands for.
static func _binding_pattern_reading(subject: String, rest: String, context: Dictionary) -> Dictionary:
	var body: String = rest.strip_edges()
	var when_at: int = top_level_index(body, " when ")
	if when_at < 0:
		return {} if not is_identifier(body) else {
			"text": "", "chips": PackedStringArray([body]), "is_else": true
		}
	var bound: String = body.substr(0, when_at).strip_edges()
	var guard: String = body.substr(when_at + 6).strip_edges()
	if not is_identifier(bound) or guard.is_empty():
		return {}
	var subject_guard: String = _with_subject(guard, bound, subject)
	# A guard that asks only what KIND of value arrived reads as the sheet's own type words - `event is
	# text`, not `event is a String` - because in a match arm the type IS the whole question.
	var kind_at: int = top_level_index(subject_guard, " is ")
	if kind_at > 0:
		var kind_name: String = subject_guard.substr(kind_at + 4).strip_edges()
		var kind_word: String = type_word(kind_name)
		if is_identifier(kind_name) and not kind_word.is_empty() and kind_word != kind_name:
			return {
				"text": "%s %s %s" % [subject_guard.substr(0, kind_at).strip_edges(),
					translate("is"), kind_word],
				"chips": PackedStringArray([bound]), "is_else": false
			}
	var reading: Dictionary = condition_pieces(subject_guard, context)
	var text: String = ""
	for piece: Variant in (reading.get("pieces", []) as Array):
		text += str((piece as Array)[0])
	text = text.strip_edges()
	if text.is_empty():
		return {}
	# The condition grammar hands the OBJECT back separately, for a column this arm has no room for -
	# so the arm says it, exactly where a reader looks for the thing being asked about.
	var object_label: String = str(reading.get("object", "")).strip_edges()
	if not object_label.is_empty() and not text.begins_with(object_label):
		text = "%s %s" % [object_label, text]
	return {"text": text, "chips": PackedStringArray([bound]), "is_else": false}


## U2. The guard with the bound name replaced by what it is bound TO, so `other is String` on a match
## over `event` reads "event is text" - the row names the value a reader can see rather than a name
## the pattern invented one line ago. Whole words only, and never inside a string literal.
static func _with_subject(guard: String, bound: String, subject: String) -> String:
	var out: String = ""
	var index: int = 0
	while index < guard.length():
		var character: String = guard[index]
		if character == "\"" or character == "'":
			var quote_end: int = _string_end(guard, index)
			out += guard.substr(index, quote_end - index + 1)
			index = quote_end + 1
			continue
		if not (character.is_valid_identifier() and not character.is_valid_int()):
			out += character
			index += 1
			continue
		var word_end: int = index
		while word_end < guard.length() and (guard[word_end].is_valid_identifier() or guard[word_end].is_valid_int()):
			word_end += 1
		var word: String = guard.substr(index, word_end - index)
		var follows_dot: bool = index > 0 and guard[index - 1] == "."
		out += subject if word == bound and not follows_dot else word
		index = word_end
	return out


## U2. A value a pattern may test against: a piece of text, a number, true/false/null, or a named
## constant. Anything with a call or an operator in it is doing work, and a pattern arm that does work
## says more than the reading can.
static func _is_pattern_value(text: String) -> bool:
	var value: String = text.strip_edges()
	if value.is_empty() or value.contains("(") or value.contains("[") or value.contains(".."):
		return false
	if _is_string_literal(value):
		return true
	if value.is_valid_float() or (value.begins_with("-") and value.substr(1).is_valid_float()):
		return true
	if value in ["true", "false", "null"]:
		return true
	for piece: String in value.split("."):
		if not is_identifier(piece):
			return false
	return true


## U2. A table key as a reader says it: `"type"` is the entry called type, and the quotes are GDScript
## asking for a piece of text rather than anything the row is about.
static func _pattern_key_words(key: String) -> String:
	var text: String = key.strip_edges()
	return _unquote(text) if _is_string_literal(text) else text
