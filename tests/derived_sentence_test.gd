@tool
class_name DerivedSentenceTest
extends RefCounted

# Godot EventSheets - a call on the canvas follows the sentence its function was given.
#
# A `.gd` opened as a sheet reads each call through the derived reading: the verb from the function's
# name, the values beside it. When the script the call goes to carries a sentence the author wrote with
# `@ace_display_template`, the row says that sentence with the call's own values in its slots - the
# same words the picker offered, kept after the file is closed and opened again. A shipped behaviour is
# left exactly as it was read: only a script the reader wrote can move a row.

const SUPPORT := preload("res://tests/support.gd")
const DERIVED := preload("res://addons/eventsheet/editor/interaction/derived_calls.gd")
const MEMBERS := preload("res://addons/eventsheet/ace/script_members.gd")
const TWIN: String = "res://tests/fixtures/script_rows/annotated_twin.gd"
const PLAIN: String = "res://tests/fixtures/script_rows/node_thing.gd"
## A shipped behaviour whose functions carry authored sentences.
const SHIPPED: String = "res://eventsheet_addons/abilities/abilities_behavior.gd"


static func run() -> bool:
	var ok: bool = _members_keep_the_sentence()
	ok = _the_row_says_the_sentence() and ok
	ok = _nothing_else_moves() and ok
	return ok


static func _words(reading: Dictionary) -> String:
	var text: String = ""
	for piece: Variant in (reading.get("pieces", []) as Array):
		text += str((piece as Array)[0])
	return text


static func _members_keep_the_sentence() -> bool:
	MEMBERS.clear_cache()
	var read: Dictionary = MEMBERS.of_script(TWIN)
	var sentences: Dictionary = {}
	for member: Dictionary in (read["methods"] as Array):
		sentences[str(member["name"])] = str(member.get("sentence", ""))
	return SUPPORT.pins("derived_sentence_test", [
		["a function with a written sentence carries it", sentences.get("take_damage", "<missing>"), "Take {amount} damage"],
		["one without carries none", sentences.get("alive", "<missing>"), ""],
	])


static func _the_row_says_the_sentence() -> bool:
	DERIVED.clear_cache()
	var autoloads: Dictionary = {"Hero": TWIN}
	var authored: Dictionary = DERIVED.derived_pieces("Hero.take_damage(5)", {}, {}, autoloads)
	var unwritten: Dictionary = DERIVED.derived_pieces("Hero.alive()", {}, {}, autoloads)
	return SUPPORT.pins("derived_sentence_test", [
		["the call reads as the sentence with its own value in the slot", _words(authored), "Take 5 damage"],
		["the object stays the receiver", str(authored.get("object", "")), "Hero"],
		["the value is still drawn as a value", ((authored["pieces"] as Array)[1] as Array)[1], "value"],
		["the words are the plainer derived tone, never the curated one", ((authored["pieces"] as Array)[0] as Array)[1], DERIVED.TONE_DERIVED],
		["a function with no sentence reads as it always did", _words(unwritten).strip_edges(), "Alive"],
	])


static func _nothing_else_moves() -> bool:
	DERIVED.clear_cache()
	var plain: Dictionary = DERIVED.derived_pieces("Hero.take_damage(5)", {}, {}, {"Hero": PLAIN})
	var shipped_facts: Dictionary = DERIVED.method_facts({"class": "", "script_path": SHIPPED, "source": "autoload"}, "create_ability_with_cooldown")
	return SUPPORT.pins("derived_sentence_test", [
		["a function of a script with no sentence reads from its name and values", _words(plain).to_lower().begins_with("take damage"), true],
		["and is not the authored one", _words(plain).contains("Take 5 damage"), false],
		["a shipped behaviour's sentence is not used by the canvas", str(shipped_facts.get("sentence", "")), ""],
	])
