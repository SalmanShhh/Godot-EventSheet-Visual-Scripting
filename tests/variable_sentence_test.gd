# Godot EventSheets - the ONE sentence a variable reads with, everywhere.
#
# `<scope> <type> <name> = <value>`. Pins the VALUES, not counts: the chip for every scope, the type
# word for every shape a reader meets, and the colour half of the row - the swatch that is always
# there, the word or hex beside it, and the write-back that keeps the spelling the line already used
# (`Color.RED`, `Color("#ff9b3c")`, `Color(1, 0.6, 0.2)`), because a colour edit must move the colour
# and not one byte more.
@tool
class_name VariableSentenceTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true

	# ── The chip: scope word first, then the type in plain words ──
	ok = _check("an instance variable", EventSheetVariableSentence.chip_text(
		EventSheetVariableSentence.SCOPE_INSTANCE, "number"), "Instance number") and ok
	ok = _check("a global", EventSheetVariableSentence.chip_text(
		EventSheetVariableSentence.SCOPE_GLOBAL, "whole number"), "Global whole number") and ok
	ok = _check("a local", EventSheetVariableSentence.chip_text(
		EventSheetVariableSentence.SCOPE_LOCAL, "text"), "Local text") and ok
	ok = _check("a constant", EventSheetVariableSentence.chip_text(
		EventSheetVariableSentence.SCOPE_CONSTANT, "number"), "Constant number") and ok
	ok = _check("a static", EventSheetVariableSentence.chip_text(
		EventSheetVariableSentence.SCOPE_STATIC, "number"), "Static number") and ok
	ok = _check("a Resource script's member is a Field", EventSheetVariableSentence.chip_text(
		EventSheetVariableSentence.SCOPE_FIELD, "number"), "Field number") and ok
	ok = _check("a scope nothing settles keeps the bare type",
		EventSheetVariableSentence.chip_text("", "boolean"), "boolean") and ok

	# ── Which scope a member HAS ──
	ok = _check("const wins over everything",
		EventSheetVariableSentence.member_scope(true, true, true, true),
		EventSheetVariableSentence.SCOPE_CONSTANT) and ok
	ok = _check("a static var is Static",
		EventSheetVariableSentence.member_scope(false, true, true, false),
		EventSheetVariableSentence.SCOPE_STATIC) and ok
	ok = _check("a member of an autoload is Global",
		EventSheetVariableSentence.member_scope(false, false, true, false),
		EventSheetVariableSentence.SCOPE_GLOBAL) and ok
	ok = _check("a member of a Resource script is a Field",
		EventSheetVariableSentence.member_scope(false, false, false, true),
		EventSheetVariableSentence.SCOPE_FIELD) and ok
	ok = _check("everything else is an Instance variable",
		EventSheetVariableSentence.member_scope(false, false, false, false),
		EventSheetVariableSentence.SCOPE_INSTANCE) and ok
	ok = _check("a StatSheet script keeps Fields",
		EventSheetVariableSentence.is_resource_host("Resource"), true) and ok
	ok = _check("a CharacterBody2D script keeps Instance variables",
		EventSheetVariableSentence.is_resource_host("CharacterBody2D"), false) and ok

	# ── The type words ──
	ok = _check("a declared float is a number", ViewportRowBuilder.friendly_type_word("float"), "number") and ok
	ok = _check("a declared int is a whole number", ViewportRowBuilder.friendly_type_word("int"), "whole number") and ok
	ok = _check("a String is text", ViewportRowBuilder.friendly_type_word("String"), "text") and ok
	ok = _check("a bool is a boolean", ViewportRowBuilder.friendly_type_word("bool"), "boolean") and ok
	ok = _check("a Vector2 is a vector", ViewportRowBuilder.friendly_type_word("Vector2"), "vector") and ok
	ok = _check("a Color is a color", ViewportRowBuilder.friendly_type_word("Color"), "color") and ok
	ok = _check("a typed Array says what it holds",
		ViewportRowBuilder.friendly_type_word("Array[String]"), "list of text") and ok
	ok = _check("a Dictionary is a table", ViewportRowBuilder.friendly_type_word("Dictionary"), "table") and ok
	ok = _check("a Node class is an object", ViewportRowBuilder.friendly_type_word("Node2D"), "object") and ok
	ok = _check("a PackedScene is a scene", ViewportRowBuilder.friendly_type_word("PackedScene"), "scene") and ok
	ok = _check("an undeclared type is any", ViewportRowBuilder.friendly_type_word("Variant"), "any") and ok
	ok = _check("a class the author wrote keeps its own name",
		ViewportRowBuilder.friendly_type_word("StatSheet"), "StatSheet") and ok

	# ── Colours: always a swatch, and the word or the hex beside it ──
	ok = _check("a colour anybody names reads as its word",
		EventSheetVariableSentence.color_text(Color.WHITE), "white") and ok
	ok = _check("every other colour reads as its hex",
		EventSheetVariableSentence.color_text(Color(1.0, 0.607843, 0.235294)), "#ff9b3c") and ok
	ok = _check("a translucent colour keeps its alpha in the hex",
		EventSheetVariableSentence.hex_text(Color(1, 0, 0, 0.5)), "#ff000080") and ok

	# An UNDECLARED colour is still a colour: `var tint := Color.WHITE` gets the swatch too.
	var inferred_colour := LocalVariable.new()
	inferred_colour.name = "tint"
	inferred_colour.type_name = ""
	inferred_colour.default_value = "Color.WHITE"
	inferred_colour.expression_default = true
	var inferred_facts: Dictionary = EventSheetSettingFacts.facts(inferred_colour)
	ok = _check("an undeclared Color.WHITE still carries the swatch",
		inferred_facts.get("swatch") is Color and (inferred_facts["swatch"] as Color).is_equal_approx(Color.WHITE),
		true) and ok
	ok = _check("…and reads as its word", str(inferred_facts.get("value_text", "")), "white") and ok
	ok = _check("…with the hex as its note", str(inferred_facts.get("note", "")), "#ffffff") and ok
	var call_variable := LocalVariable.new()
	call_variable.name = "shifted"
	call_variable.default_value = "Color.from_hsv(0.5, 1, 1)"
	call_variable.expression_default = true
	ok = _check("a Color CALL is not a colour word, so it gets no swatch",
		EventSheetSettingFacts.facts(call_variable).get("swatch") == null, true) and ok

	# ── The write-back keeps the spelling the line already used ──
	ok = _check("a named constant stays a named constant",
		EventSheetVariableSentence.color_literal_in_spelling(Color.RED, "Color.WHITE"), "Color.RED") and ok
	ok = _check("…and falls back to hex when the new colour has no name",
		EventSheetVariableSentence.color_literal_in_spelling(Color(1.0, 0.607843, 0.235294), "Color.WHITE"),
		"Color(\"#ff9b3c\")") and ok
	ok = _check("a hex string stays a hex string",
		EventSheetVariableSentence.color_literal_in_spelling(Color.RED, "Color(\"#ffffff\")"),
		"Color(\"#ff0000\")") and ok
	ok = _check("numbers stay numbers",
		EventSheetVariableSentence.color_literal_in_spelling(Color(1, 0.6, 0.2), "Color(0.1, 0.2, 0.3)"),
		"Color(1, 0.6, 0.2)") and ok
	ok = _check("…and a four-argument literal keeps its four",
		EventSheetVariableSentence.color_literal_in_spelling(Color(1, 1, 1), "Color(0.1, 0.2, 0.3, 1)"),
		"Color(1, 1, 1, 1)") and ok
	ok = _check("a colour that is not opaque always spells its alpha",
		EventSheetVariableSentence.color_literal_in_spelling(Color(1, 0, 0, 0.5), "Color(0.1, 0.2, 0.3)"),
		"Color(1, 0, 0, 0.5)") and ok
	# A four-argument literal is the one spelling the engine's own parser reads back, so that is the
	# one the round-trip is pinned on; the three-argument form is checked as TEXT above.
	var round_tripped: Variant = str_to_var(EventSheetVariableSentence.color_literal_in_spelling(
		Color(0.25, 0.5, 0.75), "Color(0, 0, 0, 1)"))
	ok = _check("the write-back round-trips through the engine's own parser",
		round_tripped is Color and (round_tripped as Color).is_equal_approx(Color(0.25, 0.5, 0.75)), true) and ok

	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("variable_sentence_test", label, actual, expected)
