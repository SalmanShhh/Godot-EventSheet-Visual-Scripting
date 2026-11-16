# Godot EventSheets - setting a Juice Player's list up from an event sheet.
#
# THE ONE THING THIS FILE IS ABOUT: whatever the Inspector can put on a card, a row can put there
# too, through the rows that already ship. Set Juice Card Field reaches every key a card holds (no new
# row); its id and the line it writes stay exactly as they shipped, so a sheet written before keeps
# writing the same bytes. Every kind of card can be added from a row, the rows' own example cards are
# cards that exist, a row's change stays with the object it was made on and never reaches the saved
# scene, and a line a row wrote opens again as that row.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_card_rows"

const PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const SCHEMA: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const STEP_FIELD: String = "res://addons/eventsheet/editor/inspector/feedback_step_field.gd"

## Where the saved-scene pin writes its scene (a file of this process's own). Removed again at the end.
const SCENE_NAME: String = "juice_card_rows.tscn"

## The line Set Juice Card Field has written since it shipped. Frozen: it never changes.
const FIELD_TEMPLATE: String = "## @ace_codegen_template(\"$JuicePlayer.set_feedback_field(\"{label}\", \"{field}\", {value})\")"

## The keys the field box must offer beyond the shipped eight: the clock and the strength window the
## Timing foldout draws.
const GROWN_FIELDS: PackedStringArray = ["clock", "min_strength", "max_strength"]

## The hint a label box carries to list the labels of the player it acts on.
const LABEL_HINT: String = "juice_card_label"


static func run() -> bool:
	var pack: GDScript = load(PACK) as GDScript
	var ok: bool = SUPPORT.check(TEST_NAME, "the Juice Player script loads", pack != null, true)
	if pack == null:
		return false
	ok = _field_pins(pack) and ok
	ok = _file_pins(pack) and ok
	ok = _annotation_pins(pack) and ok
	ok = _every_kind_pins(pack) and ok
	ok = _own_copy_pins(pack) and ok
	ok = _saved_scene_pins(pack) and ok
	ok = _reopen_pins() and ok
	return ok


## Set Juice Card Field reaches any key a card holds, plus the strength window and the clock, and still
## refuses what is not a field at all.
static func _field_pins(pack: GDScript) -> bool:
	var player: Node = _player(pack, [
		{"verb": "shake", "label": "rattle", "amount": 0.4, "effect": "", "seconds": 0.5, "wobble_style": "soft"},
		{"verb": "flash", "label": "hit", "amount": 1.0, "effect": "#ffffff", "seconds": 0.1}])
	player.call("set_feedback_field", "rattle", "amount", 0.7)
	player.call("set_feedback_field", "rattle", "wobble_style", "hard")
	player.call("set_feedback_field", "hit", "min_strength", 0.5)
	player.call("set_feedback_field", "hit", "max_strength", 2.0)
	player.call("set_feedback_field", "hit", "clock", "real")
	player.call("set_feedback_field", "hit", "verb", "zoom")
	player.call("set_feedback_field", "hit", "wobble", 3.0)
	var rattle: Dictionary = (player.get("steps") as Array)[0]
	var hit: Dictionary = (player.get("steps") as Array)[1]
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["one of the shipped eight is written as before", rattle.get("amount"), 0.7],
		["a key the card holds is written", rattle.get("wobble_style"), "hard"],
		["the bottom of the strength window is written", hit.get("min_strength"), 0.5],
		["and the top", hit.get("max_strength"), 2.0],
		["and the clock", hit.get("clock"), "real"],
		["the card's kind is not a field: Replace Juice Card changes a kind", hit.get("verb"), "flash"],
		["a key no card has is refused", hit.has("wobble"), false],
	])
	player.free()
	return ok


## Save Moment File names every key of a card it cannot keep, so nothing is dropped without being said.
static func _file_pins(pack: GDScript) -> bool:
	var plain: PackedStringArray = pack.call("keys_a_file_drops",
		{"verb": "shake", "label": "kick", "active": true, "amount": 0.4, "effect": "", "seconds": 0.2})
	var timed: PackedStringArray = pack.call("keys_a_file_drops",
		{"verb": "shake", "label": "kick", "amount": 0.4, "effect": "", "seconds": 0.2, "delay": 0.05, "repeat": 3,
			"chance": 50.0, "wobble_style": "soft"})
	return SUPPORT.pins(TEST_NAME, [
		["a card a file can hold loses nothing", plain, PackedStringArray()],
		["a card with timing, a chance or a field of its own names each key it would lose", timed,
			PackedStringArray(["delay", "repeat", "chance", "wobble_style"])],
	])


## The row as the emitted pack spells it: the template byte for byte as shipped, the field box grown,
## every example card a row opens on a kind of card the Inspector has, and the label boxes hinted.
static func _annotation_pins(pack: GDScript) -> bool:
	var text: String = FileAccess.get_file_as_string(pack.resource_path)
	var field_line: String = _param_line(text, "set_feedback_field", "field")
	var not_offered: PackedStringArray = PackedStringArray()
	for key: String in GROWN_FIELDS:
		if not field_line.contains(key):
			not_offered.append(key)
	var kinds: PackedStringArray = _kind_words()
	var unknown_examples: PackedStringArray = PackedStringArray()
	for verb_name: String in ["add_feedback", "insert_feedback_before", "replace_feedback"]:
		var step_line: String = _param_line(text, verb_name, "step")
		var opened: int = step_line.find("default: {")
		if opened < 0:
			unknown_examples.append("%s has no example card" % verb_name)
			continue
		var literal: String = step_line.substr(opened + 9, step_line.find("}", opened) - opened - 8)
		var example: Variant = str_to_var(literal)
		var word: String = str((example as Dictionary).get("verb", "")) if example is Dictionary else ""
		if not kinds.has(word):
			unknown_examples.append("%s opens on \"%s\"" % [verb_name, word])
	var label_hinted: PackedStringArray = PackedStringArray()
	for verb_name: String in ["set_feedback_field", "set_feedback_timing", "set_feedback_chance", "enable_feedback",
			"disable_feedback", "remove_feedback", "move_feedback_to", "replace_feedback", "duplicate_feedback",
			"set_feedback_label", "skip_feedback_once", "jump_to_feedback", "set_loop_count"]:
		if not _param_line(text, verb_name, "label").contains("hint: %s" % LABEL_HINT):
			label_hinted.append(verb_name)
	for pair: Array in [["add_feedback", "after_label"], ["insert_feedback_before", "before_label"]]:
		if not _param_line(text, str(pair[0]), str(pair[1])).contains("hint: %s" % LABEL_HINT):
			label_hinted.append(str(pair[0]))
	return SUPPORT.pins(TEST_NAME, [
		["Set Juice Card Field writes the line it has always written", text.contains(FIELD_TEMPLATE), true],
		["its field box offers the keys the Inspector draws", not_offered, PackedStringArray()],
		["every row's example card is a card the Inspector has", unknown_examples, PackedStringArray()],
		["a label box lists the labels of the player it acts on", label_hinted, PackedStringArray()],
		["a row that names no card says so, with the player and the row", text.contains("has no juice card labelled"), true],
	])


## Every kind of card can be written into a row's step box and added by Add Juice Card, unchanged.
static func _every_kind_pins(pack: GDScript) -> bool:
	var schema: Dictionary = (load(SCHEMA) as GDScript).call("schema")
	var step_field: GDScript = load(STEP_FIELD)
	var spec: Dictionary = {"kind_key": "verb", "stripe_key": "category"}
	var lost: PackedStringArray = PackedStringArray()
	var not_added: PackedStringArray = PackedStringArray()
	var player: Node = _player(pack, [])
	var walked: int = 0
	for kind: Variant in schema.get("kinds", []):
		var card: Dictionary = EventSheetCardSchemas.new_card(spec, kind as Dictionary)
		var literal: String = str(step_field.call("step_literal", card))
		var back: Dictionary = step_field.call("parse_step", literal)
		if back != card:
			lost.append("%s: %s" % [str(card.get("verb", "")), literal])
		var before: int = int(player.call("feedback_count"))
		player.call("add_feedback", back, "")
		var list: Array = player.get("steps")
		if int(player.call("feedback_count")) != before + 1 or str((list[list.size() - 1] as Dictionary).get("verb", "")) != str(card.get("verb", "")):
			not_added.append(str(card.get("verb", "")))
		walked += 1
	player.free()
	return SUPPORT.pins(TEST_NAME, [
		["the walk reached every kind the schema holds", walked, (schema.get("kinds", []) as Array).size()],
		["every kind survives the step box byte for byte", lost, PackedStringArray()],
		["and Add Juice Card adds every kind", not_added, PackedStringArray()],
	])


## Copies of one scene share the card dictionaries; a row's change must stay with its own object.
static func _own_copy_pins(pack: GDScript) -> bool:
	var shared: Array[Dictionary] = [{"verb": "shake", "label": "kick", "amount": 0.4, "effect": "", "seconds": 0.2}]
	var first: Node = pack.new()
	var second: Node = pack.new()
	first.set("steps", shared.duplicate())
	second.set("steps", shared.duplicate())
	first.call("set_feedback_field", "kick", "amount", 0.9)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["the object a row acts on changes", ((first.get("steps") as Array)[0] as Dictionary).get("amount"), 0.9],
		["a copy of the same scene does not", ((second.get("steps") as Array)[0] as Dictionary).get("amount"), 0.4],
	])
	first.free()
	second.free()
	return ok


## A list changed while the game runs never writes the saved scene.
static func _saved_scene_pins(pack: GDScript) -> bool:
	var scene_path: String = SUPPORT.own_path(SCENE_NAME)
	var root: Node2D = Node2D.new()
	root.name = "Level"
	var player: Node = pack.new()
	player.name = "JuicePlayer"
	var typed: Array[Dictionary] = [{"verb": "shake", "label": "kick", "amount": 0.4, "effect": "", "seconds": 0.2}]
	player.set("steps", typed)
	root.add_child(player)
	player.owner = root
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, scene_path)
	root.free()
	var before: String = FileAccess.get_file_as_string(scene_path)
	var loaded: PackedScene = load(scene_path) as PackedScene
	var copy: Node = loaded.instantiate()
	var live: Node = copy.get_node("JuicePlayer")
	live.call("set_feedback_field", "kick", "amount", 0.9)
	live.call("add_feedback", {"verb": "flash", "amount": 1.0, "effect": "", "seconds": 0.1}, "")
	live.call("remove_feedback", "kick")
	copy.free()
	var after: String = FileAccess.get_file_as_string(scene_path)
	return SUPPORT.check(TEST_NAME, "the saved scene is the same bytes after rows changed the list", after == before, true)


## A line a row wrote opens again as that row, and saves back byte for byte.
static func _reopen_pins() -> bool:
	var line: String = "$JuicePlayer.set_feedback_field(\"rattle\", \"clock\", \"real\")"
	var source: String = "extends Node2D\n\n\nfunc _ready() -> void:\n\t%s\n" % line
	var sheet: EventSheetResource = SUPPORT.reopen(source)
	var read_as: String = ""
	for entry: Variant in sheet.events:
		if entry is EventRow:
			for action: Variant in (entry as EventRow).actions:
				if action is ACEAction:
					read_as = "%s/%s" % [(action as ACEAction).provider_id, (action as ACEAction).ace_id]
	return SUPPORT.pins(TEST_NAME, [
		["the line opens as Set Juice Card Field", read_as, "FeedbackPlayer/method:set_feedback_field"],
		["and saves back byte for byte", SUPPORT.reemit(source, SUPPORT.own_path("juice_card_rows.gd")), source],
	])


static func _player(pack: GDScript, list: Array) -> Node:
	var player: Node = pack.new()
	var typed: Array[Dictionary] = []
	for card: Variant in list:
		typed.append(card as Dictionary)
	player.set("steps", typed)
	return player


## The words of every kind of card the Inspector offers.
static func _kind_words() -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray()
	for kind: Variant in ((load(SCHEMA) as GDScript).call("schema") as Dictionary).get("kinds", []):
		words.append(str((kind as Dictionary).get("kind", "")))
	return words


## The `## @ace_param(<param>, ...)` line written above `func <verb_name>(` in the emitted pack.
static func _param_line(text: String, verb_name: String, param: String) -> String:
	var lines: PackedStringArray = text.split("\n")
	for index: int in range(lines.size()):
		if not lines[index].begins_with("func %s(" % verb_name):
			continue
		var walk: int = index - 1
		while walk >= 0 and lines[walk].begins_with("##"):
			if lines[walk].begins_with("## @ace_param(%s," % param):
				return lines[walk]
			walk -= 1
		return ""
	return ""
