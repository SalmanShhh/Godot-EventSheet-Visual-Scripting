# EventSheet - reading-lens tests (M9 humanized names, M10 possessive chains, M12 NOT as a mark,
# M16 function-call chips). Every case here is a VALUE pinned from the approved reading mockup;
# the lenses are display-only, so nothing in this file touches a sheet or emitted GDScript.
@tool
class_name ViewportLensesTest
extends RefCounted


static func run() -> bool:
	var passed: bool = true
	passed = _humanized_names() and passed
	passed = _possessive_chains() and passed
	passed = _not_as_a_mark() and passed
	passed = _function_call_chips() and passed
	passed = _lenses_leave_code_alone() and passed
	return passed


## M9: a private state var reads as lowercase words; an @export knob reads with Godot's own
## Inspector capitalisation, so the sheet and the Inspector say the same thing.
static func _humanized_names() -> bool:
	var passed: bool = true
	passed = _check("private var drops its underscore",
		EventSheetViewportLenses.humanize_identifier("_coyote_timer"), "coyote timer") and passed
	passed = _check("snake_case becomes words",
		EventSheetViewportLenses.humanize_identifier("wall_jump_enabled"), "wall jump enabled") and passed
	passed = _check("multiple leading underscores drop",
		EventSheetViewportLenses.humanize_identifier("__jumps_left"), "jumps left") and passed
	passed = _check("a single word stays one word",
		EventSheetViewportLenses.humanize_identifier("sliding"), "sliding") and passed
	passed = _check("an export knob takes Inspector capitalisation",
		EventSheetViewportLenses.humanize_identifier("coyote_time", true), "Coyote Time") and passed
	passed = _check("an export knob with three words",
		EventSheetViewportLenses.humanize_identifier("wall_jump_enabled", true), "Wall Jump Enabled") and passed
	passed = _check("an export knob keeps its digits",
		EventSheetViewportLenses.humanize_identifier("max_jumps", true), "Max Jumps") and passed
	return passed


## M10: `a.b.c` reads `a's b c`, axis components read as capitals, and a two-part chain ending
## in an axis reads as the component it is rather than a possession.
static func _possessive_chains() -> bool:
	var passed: bool = true
	passed = _check("host.velocity.x",
		EventSheetViewportLenses.possessive_chain("host.velocity.x"), "host's velocity X") and passed
	passed = _check("event.relative.x",
		EventSheetViewportLenses.possessive_chain("event.relative.x"), "event's relative X") and passed
	passed = _check("event.relative.y",
		EventSheetViewportLenses.possessive_chain("event.relative.y"), "event's relative Y") and passed
	passed = _check("direction.x is a component, not a possession",
		EventSheetViewportLenses.possessive_chain("direction.x"), "direction X") and passed
	passed = _check("a two-part non-axis chain is possessive",
		EventSheetViewportLenses.possessive_chain("host.wall_normal"), "host's wall normal") and passed
	passed = _check("chains inside an expression translate, operators do not",
		EventSheetViewportLenses.possessive_in_expression("direction.x * speed + push_x"),
		"direction X * speed + push_x") and passed
	passed = _check("a float literal is not a chain",
		EventSheetViewportLenses.possessive_in_expression("push_x - 0.5"), "push_x - 0.5") and passed
	return passed


## M12: a sentence that leads with NOT loses the word (the red mark in the badge column carries
## the inversion), and a mid-sentence "is not" keeps its word, where it reads correctly.
static func _not_as_a_mark() -> bool:
	var passed: bool = true
	var leading: Dictionary = EventSheetViewportLenses.strip_leading_not("not on floor")
	passed = _check("a leading NOT is stripped from the sentence", str(leading.get("text")), "on floor") and passed
	passed = _check("a leading NOT reports the inversion", bool(leading.get("negated")), true) and passed
	var parenthesised: Dictionary = EventSheetViewportLenses.strip_leading_not("not (host.is_on_floor())")
	passed = _check("a parenthesised NOT is stripped whole",
		str(parenthesised.get("text")), "host.is_on_floor()") and passed
	passed = _check("a parenthesised NOT reports the inversion",
		bool(parenthesised.get("negated")), true) and passed
	var mid: Dictionary = EventSheetViewportLenses.strip_leading_not("host is not empty")
	passed = _check("a mid-sentence NOT keeps its word", str(mid.get("text")), "host is not empty") and passed
	passed = _check("a mid-sentence NOT draws no mark", bool(mid.get("negated")), false) and passed
	var nothing: Dictionary = EventSheetViewportLenses.strip_leading_not("on floor")
	passed = _check("a plain sentence is untouched", str(nothing.get("text")), "on floor") and passed
	passed = _check("a plain sentence draws no mark", bool(nothing.get("negated")), false) and passed
	return passed


## M16: a call reads "Call <Display Name>" with one chip per argument, named by the function's
## own parameter names when they are known.
static func _function_call_chips() -> bool:
	var passed: bool = true
	passed = _check("a snake_case function gets a display name",
		EventSheetViewportLenses.function_display_name("add_look"), "Add Look") and passed
	passed = _check("a published name wins over the derived one",
		EventSheetViewportLenses.function_display_name("do_jump", "Jump"), "Jump") and passed
	passed = _check("a named argument chip",
		EventSheetViewportLenses.call_argument_chip("x", "event.relative.x"), "x = event's relative X") and passed
	passed = _check("an unnamed argument chip is the bare value",
		EventSheetViewportLenses.call_argument_chip("", "true"), "true") and passed
	passed = _check("a named boolean argument chip",
		EventSheetViewportLenses.call_argument_chip("enabled", "true"), "enabled = true") and passed
	return passed


## The guard rail on all of it: anything that is not a plain identifier or a plain chain comes
## back byte-identical, because a half-translated expression reads worse than the code does.
static func _lenses_leave_code_alone() -> bool:
	var passed: bool = true
	passed = _check("a call is never humanized",
		EventSheetViewportLenses.humanize_identifier("host.is_on_floor()"), "host.is_on_floor()") and passed
	passed = _check("a chain holding a call is left alone",
		EventSheetViewportLenses.possessive_chain("host.get_wall_normal().x"), "host.get_wall_normal().x") and passed
	passed = _check("an expression holding a call is left alone",
		EventSheetViewportLenses.possessive_in_expression("maxf(host.velocity.x, 0.0)"),
		"maxf(host.velocity.x, 0.0)") and passed
	passed = _check("a string literal is not an identifier",
		EventSheetViewportLenses.is_identifier("\"ui_accept\""), false) and passed
	passed = _check("a name starting with a digit is not an identifier",
		EventSheetViewportLenses.is_identifier("3d_mode"), false) and passed
	passed = _check("a plain name is an identifier",
		EventSheetViewportLenses.is_identifier("_coyote_timer"), true) and passed
	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] viewport_lenses_test: %s" % label)
		return true
	print("[FAIL] viewport_lenses_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
