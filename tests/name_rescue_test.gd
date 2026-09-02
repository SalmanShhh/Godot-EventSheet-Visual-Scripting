# EventForge - the unknown-name rescues: the typo guard, the type guess, the everyday binding.
#
# Three rules pinned:
#   1. TYPO GUARD - near-name matches come back nearest first and only within two edits, so every
#      surface that offers "did you mean" before "create" offers the right names in the right
#      order, and creation never mints a typo twin.
#   2. TYPE GUESS - a new name's declared type is read from how the expression uses it, so the
#      declaration dialog opens pre-filled rather than defaulting blind.
#   3. EVERYDAY BINDING - a control named jump is offered bound to Space; a name convention says
#      nothing about is created unbound.
@tool
class_name NameRescueTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	ok = _test_near_names() and ok
	ok = _test_type_guess() and ok
	ok = _test_everyday_keys() and ok
	ok = _test_input_action_fix() and ok
	return ok


static func _test_near_names() -> bool:
	var ok: bool = true
	var known: PackedStringArray = PackedStringArray(["max_hp", "score", "mox_hp", "speed"])
	var near: PackedStringArray = EventSheetNameRescue.near_names("mx_hp", known)
	ok = _check("mx_hp finds max_hp before anything else",
		near[0] if near.size() > 0 else "", "max_hp") and ok
	ok = _check("a same-distance twin still lists (nearest set, caller's order kept)",
		near.has("mox_hp"), true) and ok
	ok = _check("a far word is not near", near.has("speed"), false) and ok
	ok = _check("a one-letter typo is nearest of all",
		EventSheetNameRescue.near_names("scor", known)[0], "score") and ok
	ok = _check("nothing near answers empty",
		EventSheetNameRescue.near_names("zzzzzz", known).is_empty(), true) and ok
	ok = _check("a one-character name never suggests (noise guard)",
		EventSheetNameRescue.near_names("x", known).is_empty(), true) and ok
	ok = _check("the limit caps the list",
		EventSheetNameRescue.near_names("mx_hp", known, 1).size(), 1) and ok
	ok = _check("the shared distance is the ordinary Levenshtein",
		EventSheetNameRescue.edit_distance("kitten", "sitting"), 3) and ok
	return ok


static func _test_type_guess() -> bool:
	var ok: bool = true
	ok = _check("compared to a decimal reads float",
		EventSheetNameRescue.guess_type_name("mana > 0.5", "mana"), "float") and ok
	ok = _check("compared to a whole number reads int",
		EventSheetNameRescue.guess_type_name("lives >= 3", "lives"), "int") and ok
	ok = _check("joined to quoted text reads String",
		EventSheetNameRescue.guess_type_name("title + \" points\"", "title"), "String") and ok
	ok = _check("compared to true reads bool",
		EventSheetNameRescue.guess_type_name("armed == true", "armed"), "bool") and ok
	ok = _check("a bare name defaults to int",
		EventSheetNameRescue.guess_type_name("combo", "combo"), "int") and ok
	ok = _check("a name the expression does not hold defaults to int",
		EventSheetNameRescue.guess_type_name("score + 1", "elsewhere"), "int") and ok
	return ok


static func _test_everyday_keys() -> bool:
	var ok: bool = true
	ok = _check("jump is offered Space", EventSheetNameRescue.suggested_key("jump"), KEY_SPACE) and ok
	ok = _check("player_jump still means jump",
		EventSheetNameRescue.suggested_key("player_jump"), KEY_SPACE) and ok
	ok = _check("pause is offered Escape", EventSheetNameRescue.suggested_key("pause"), KEY_ESCAPE) and ok
	ok = _check("an unconventional name is offered nothing",
		EventSheetNameRescue.suggested_key("frobnicate"), KEY_NONE) and ok
	return ok


## The reverse door end to end: creating "jump" through the quick fix binds Space; an
## unconventional name is created unbound. Both settings are removed on the way out - the suite
## must leave the project's Input Map exactly as it found it.
static func _test_input_action_fix() -> bool:
	var ok: bool = true
	var jump_setting: String = "input/name_rescue_test_jump"
	var plain_setting: String = "input/name_rescue_test_frob"
	ProjectSettings.set_setting(jump_setting, null)
	ProjectSettings.set_setting(plain_setting, null)
	var jump_result: Dictionary = EventSheetQuickFixes.apply("add_input_action",
		{"check": "unknown-input-action", "subject": "name_rescue_test_jump"}, {})
	ok = _check("the jump control is created", bool(jump_result.get("ok", false)), true) and ok
	var jump_value: Dictionary = ProjectSettings.get_setting(jump_setting, {})
	var jump_events: Array = jump_value.get("events", [])
	ok = _check("…wearing one binding", jump_events.size(), 1) and ok
	if jump_events.size() == 1:
		ok = _check("…and that binding is Space",
			(jump_events[0] as InputEventKey).physical_keycode, KEY_SPACE) and ok
	ok = _check("…and the answer says so",
		str(jump_result.get("message", "")).contains("bound to"), true) and ok
	var plain_result: Dictionary = EventSheetQuickFixes.apply("add_input_action",
		{"check": "unknown-input-action", "subject": "name_rescue_test_frob"}, {})
	ok = _check("an unconventional control is still created", bool(plain_result.get("ok", false)), true) and ok
	var plain_value: Dictionary = ProjectSettings.get_setting(plain_setting, {})
	ok = _check("…unbound, exactly as before",
		(plain_value.get("events", []) as Array).is_empty(), true) and ok
	ProjectSettings.set_setting(jump_setting, null)
	ProjectSettings.set_setting(plain_setting, null)
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("name_rescue_test", label, actual, expected)
