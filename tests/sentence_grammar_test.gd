@tool
class_name SentenceGrammarTest
extends RefCounted

# Pins the event-sheet row grammar VALUES - one shape, one sentence.
#
# These strings are what a reader sees, so they are asserted literally: a shape that quietly starts
# reading differently is a regression even when nothing crashes. The grammar is static and pure, so
# every case runs without a viewport.

const CONTEXT_FPS: Dictionary = {
	"self_object": "System",
	"owner": "FPSController",
	"signals": {"jumped": "On Jumped"}
}


static func run() -> bool:
	var ok: bool = true
	ok = _statements() and ok
	ok = _conditions() and ok
	ok = _idioms() and ok
	ok = _declarations() and ok
	ok = _returns() and ok
	return ok


## The whole reading of one statement: "object ▸ sentence", so a case pins the object column too.
static func _read(code: String, context: Dictionary = CONTEXT_FPS) -> String:
	var result: Dictionary = EventSheetSentence.statement(code, context)
	if result.is_empty():
		return ""
	return "%s ▸ %s" % [str(result.get("object", "")), _joined(result)]


static func _joined(result: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (result.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	return text


static func _read_condition(expression: String) -> String:
	var result: Dictionary = EventSheetSentence.condition(expression, CONTEXT_FPS)
	if result.is_empty():
		return ""
	return "%s ▸ %s" % [str(result.get("object", "")), _joined(result)]


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] sentence_grammar_test: %s" % label)
		return true
	print("[FAIL] sentence_grammar_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


static func _statements() -> bool:
	var ok: bool = true
	ok = _check("subtract", _read("_jumps_left -= 1"), "System ▸ Subtract 1 from _jumps_left") and ok
	ok = _check("add", _read("score += wave"), "System ▸ Add wave to score") and ok
	ok = _check("multiply", _read("speed *= 2"), "System ▸ Multiply speed by 2") and ok
	ok = _check("divide", _read("speed /= 2"), "System ▸ Divide speed by 2") and ok
	ok = _check("set variable", _read("_coyote_timer = coyote_time"), "System ▸ Set _coyote_timer to coyote_time") and ok
	ok = _check("set member", _read("host.velocity.x = direction * speed"),
		"host ▸ Set velocity.x to direction * speed") and ok
	ok = _check("member add", _read("host.velocity += push"), "host ▸ Add push to velocity") and ok
	ok = _check("deferred destroy", _read("host.call_deferred(\"queue_free\")"),
		"host ▸ Destroy (at end of frame)") and ok
	ok = _check("destroy", _read("queue_free()"), "System ▸ Destroy") and ok
	ok = _check("signal with published name", _read("jumped.emit()"), "FPSController ▸ Signal On Jumped") and ok
	ok = _check("signal humanized", _read("wall_jumped.emit()"), "FPSController ▸ Signal On Wall Jumped") and ok
	ok = _check("signal already prefixed", _read("on_damaged.emit()"), "FPSController ▸ Signal On Damaged") and ok
	ok = _check("signal payload", _read("on_damaged.emit(amount, true)"),
		"FPSController ▸ Signal On Damaged amount, true") and ok
	ok = _check("wait", _read("await get_tree().create_timer(0.5).timeout"), "System ▸ ⏳ Wait 0.5 seconds") and ok
	# The sheet's own action name, always on, with the layout named the way the file is named.
	ok = _check("change scene", _read("get_tree().change_scene_to_file(\"res://menu.tscn\")"),
		"System ▸ Go to layout Menu") and ok
	# Refusals: a sentence that is almost right is worse than the code it replaced.
	ok = _check("comparison refused", _read("x == y"), "") and ok
	ok = _check("control flow refused", _read("if ready:"), "") and ok
	ok = _check("other await refused", _read("await ready_signal"), "") and ok
	ok = _check("multi-line refused", _read("x = 1\ny = 2"), "") and ok
	ok = _check("indent kept", int(EventSheetSentence.statement("\t\tscore += 1", CONTEXT_FPS).get("indent", -1)), 2) and ok
	return ok


static func _conditions() -> bool:
	var ok: bool = true
	ok = _check("bare flag", _read_condition("crouching"), "System ▸ crouching is true") and ok
	ok = _check("negated flag", _read_condition("not crouching"), "System ▸ crouching is false") and ok
	ok = _check("null check", _read_condition("host == null"), "host ▸ does not exist") and ok
	ok = _check("not null check", _read_condition("host != null"), "host ▸ exists") and ok
	ok = _check("chance", _read_condition("randf() < 0.3"), "System ▸ 30% chance") and ok
	ok = _check("key down", _read_condition("Input.is_action_pressed(&\"jump\")"), "Keyboard ▸ \"jump\" is down") and ok
	ok = _check("key pressed", _read_condition("Input.is_action_just_pressed(\"jump\")"),
		"Keyboard ▸ On \"jump\" pressed") and ok
	# An approximate comparison is a QUESTION, and the sheet has a sentence for it. The ≈ glyph
	# is still what the same call reads as inside a VALUE, where there is no question being asked.
	ok = _check("zero approx", _read_condition("is_zero_approx(direction)"),
		"System ▸ direction is about 0") and ok
	ok = _check("zero approx inside a value", EventSheetSentence.expression_text("is_zero_approx(direction)"),
		"direction ≈ 0") and ok
	ok = _check("plain comparison untouched", _read_condition("health > 0"), "") and ok
	return ok


static func _idioms() -> bool:
	var ok: bool = true
	ok = _check("maxf", EventSheetSentence.expression_text("maxf(a, b)"), "max(a, b)") and ok
	ok = _check("mini", EventSheetSentence.expression_text("mini(a, b)"), "min(a, b)") and ok
	ok = _check("equal approx", EventSheetSentence.expression_text("is_equal_approx(a, b)"), "a ≈ b") and ok
	ok = _check("move toward", EventSheetSentence.expression_text("move_toward(push_x, 0.0, fade)"),
		"push_x moved toward 0 by fade") and ok
	ok = _check("lerp", EventSheetSentence.expression_text("lerp(a, b, t)"), "a → b at t") and ok
	ok = _check("clamp", EventSheetSentence.expression_text("clamp(x, lo, hi)"), "x kept between lo and hi") and ok
	ok = _check("abs", EventSheetSentence.expression_text("abs(x)"), "|x|") and ok
	ok = _check("degrees", EventSheetSentence.expression_text("deg_to_rad(x)"), "x°") and ok
	ok = _check("nested idioms", EventSheetSentence.expression_text("maxf(_coyote_timer - delta, 0.0)"),
		"max(_coyote_timer - dt, 0)") and ok
	ok = _check("vector constructor", EventSheetSentence.expression_text("Vector3(x, y, z)"), "(x, y, z)") and ok
	ok = _check("cast dropped", EventSheetSentence.expression_text("(child as CollisionShape3D).shape"),
		"child.shape") and ok
	ok = _check("unknown call untouched", EventSheetSentence.expression_text("_gravity_dir()"), "_gravity_dir()") and ok
	ok = _check("string left alone", EventSheetSentence.expression_text("\"abs(x)\""), "\"abs(x)\"") and ok
	return ok


static func _declarations() -> bool:
	var ok: bool = true
	var typed: Dictionary = EventSheetSentence.declaration("var remaining: float = amount")
	ok = _check("declaration kind", str(typed.get("kind", "")), "declaration") and ok
	ok = _check("declaration type word", str(typed.get("type_word", "")), "number") and ok
	ok = _check("declaration name", str(typed.get("name", "")), "remaining") and ok
	ok = _check("declaration value", str(typed.get("value", "")), "amount") and ok
	ok = _check("declaration reads", _joined(typed), "Local number remaining = amount") and ok
	ok = _check("no annotation shown", _joined(EventSheetSentence.declaration("var speed: float = 3.0")),
		"Local number speed = 3") and ok
	ok = _check("inferred bool", _joined(EventSheetSentence.declaration("var on_floor := host.is_on_floor()")),
		"Local value on_floor = host.is_on_floor()") and ok
	ok = _check("inferred int", _joined(EventSheetSentence.declaration("var count := 0")),
		"Local number count = 0") and ok
	ok = _check("constant flagged", bool(EventSheetSentence.declaration("const STEP: int = 3").get("is_constant", false)),
		true) and ok
	ok = _check("not a declaration", EventSheetSentence.declaration("score += 1").is_empty(), true) and ok
	return ok


static func _returns() -> bool:
	var ok: bool = true
	var condition_context: Dictionary = CONTEXT_FPS.duplicate()
	condition_context["verb_kind"] = EventSheetSentence.VerbKind.CONDITION
	var expression_context: Dictionary = CONTEXT_FPS.duplicate()
	expression_context["verb_kind"] = EventSheetSentence.VerbKind.EXPRESSION
	ok = _check("action return", _read("return"), "System ▸ Stop event") and ok
	ok = _check("action return value", _read("return _jumps_left"), "System ▸ Return _jumps_left") and ok
	ok = _check("condition true", _read("return true", condition_context),
		"System ▸ Set return value to true") and ok
	ok = _check("condition false", _read("return false", condition_context),
		"System ▸ Set return value to false") and ok
	ok = _check("condition expression", _read("return host.is_on_floor()", condition_context),
		"System ▸ Set return value to host.is_on_floor()") and ok
	ok = _check("expression returns a value", _read("return _jumps_left", expression_context),
		"System ▸ Set return value to _jumps_left") and ok
	ok = _check("bare return in condition", _read("return", condition_context), "System ▸ Stop event") and ok
	return ok
