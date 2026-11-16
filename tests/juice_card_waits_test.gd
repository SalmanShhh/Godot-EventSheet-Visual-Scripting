# Godot EventSheets - Hold that waits for one card, the cards for sound and device, Autoplay.
#
# THE ONE THING THIS FILE IS ABOUT: the plan the Inspector draws, the length a row can wait for and
# the walk itself read ONE function, so a Hold that waits for a named card moves all three together.
# Autoplay is an ordinary export that is not saved while it is off, so an old scene stays the bytes
# it was.
#
# Play Juice And Wait waiting for the cards to finish needs a running tree and a clock, which the
# suite does not have: it is proven by a scene-tree harness instead (measured before the change:
# a 0.3 s shake returned after 0 ms).
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SCHEMA_PATH: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const PACK: String = "res://eventsheet_addons/juice/juice_player.gd"

const TEST_NAME: String = "juice_card_waits"


static func run() -> bool:
	var ok: bool = true
	ok = _waits_for_pins() and ok
	ok = _kind_pins() and ok
	ok = _autoplay_pins() and ok
	ok = _search_pins() and ok
	return ok


static func _pack() -> Script:
	return load(PACK) as Script


static func _list() -> Array:
	return [
		{"verb": "shake", "amount": 0.4, "seconds": 0.2, "label": "Quick"},
		{"verb": "tween_property", "effect": "rotation", "amount": 1.0, "seconds": 0.5, "label": "Slow"},
		{"verb": "hold_until", "seconds": 0.0, "waits_for": "Quick"},
		{"verb": "flash", "amount": 1.0, "seconds": 0.1, "label": "After"}
	]


## A Hold that names a card waits for that card, not for the slowest one above it.
static func _waits_for_pins() -> bool:
	var list: Array = _list()
	var plan: Array = _pack().call("schedule_of", list)
	var flash_at: float = -1.0
	for entry: Variant in plan:
		if str(((entry as Dictionary).get("card") as Dictionary).get("label", "")) == "After":
			flash_at = snappedf(float((entry as Dictionary).get("at", 0.0)), 0.001)
	var unnamed: Array = _list()
	(unnamed[2] as Dictionary).erase("waits_for")
	var stale: Array = _list()
	(stale[2] as Dictionary)["waits_for"] = "Nothing of that name"
	var delayed: Array = _list()
	(delayed[0] as Dictionary)["label"] = "Quick"
	return SUPPORT.pins(TEST_NAME, [
		["a Hold waiting for Quick lets the card under it start when Quick ends", flash_at, 0.2],
		["the length still counts the slower card that runs on beside it",
			snappedf(float(_pack().call("duration_of", list)), 0.001), 0.5],
		["a Hold that names nothing waits for the slowest card, as before",
			snappedf(float(_pack().call("duration_of", unnamed)), 0.001), 0.6],
		["a name that is no card above waits for the slowest, as before",
			snappedf(float(_pack().call("duration_of", stale)), 0.001), 0.6],
		["what the walk waits for at that Hold is what is left of Quick",
			snappedf(float(_pack().call("left_above", list, 2)), 0.001), 0.2],
		["and with no name, what is left of the slowest",
			snappedf(float(_pack().call("left_above", unnamed, 2)), 0.001), 0.5],
		["the card name a Hold is asked for is the card's label, or its word when it has none",
			[_pack().call("card_label", {"verb": "shake", "label": " Big "}), _pack().call("card_label", {"verb": "shake"})], ["Big", "shake"]]
	])


## The cards that stop a sound, fade a bus and rumble the hand are in the Add box, each in its family, and
## the running game files them under the same families (a muted family silences them).
static func _kind_pins() -> bool:
	var schema: Dictionary = load(SCHEMA_PATH).call("schema")
	var families: Dictionary = {}
	var runtime: Dictionary = {}
	var family_table: Dictionary = _pack().get_script_constant_map().get("CATEGORY_OF")
	for word: String in ["stop_sound", "fade_bus", "vibrate"]:
		families[word] = str(EventSheetCardSchemas.kind_entry(schema, word).get("category", "(none)"))
		runtime[word] = str(family_table.get(word, "(none)"))
	var expected: Dictionary = {"stop_sound": "audio", "fade_bus": "audio", "vibrate": "device"}
	var editor_words: Dictionary = {}
	for word: String in ["stop_sound", "fade_bus", "vibrate"]:
		editor_words[word] = str(_pack().call("editor_kind", word)).begins_with("skipped:")
	return SUPPORT.pins(TEST_NAME, [
		["the three new cards are in the Add box, each in its family", families, expected],
		["and the running game files them the same way", runtime, expected],
		["the editor says it skips them rather than faking them", editor_words, {"stop_sound": true, "fade_bus": true, "vibrate": true}]
	])


## Autoplay: off by default, not written into a scene while off, plays once at strength 1.
static func _autoplay_pins() -> bool:
	var player: Node = _pack().new()
	var found: bool = false
	var default_value: Variant = null
	for property: Dictionary in player.get_property_list():
		if str(property.get("name")) == "autoplay":
			found = int(property.get("usage")) & PROPERTY_USAGE_STORAGE != 0
			default_value = player.get("autoplay")
	var root: Node = Node.new()
	root.add_child(player)
	player.owner = root
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	var path: String = SUPPORT.own_path("juice_card_waits_autoplay.tscn")
	ResourceSaver.save(packed, path)
	var text: String = FileAccess.get_file_as_string(path)
	root.free()
	return SUPPORT.pins(TEST_NAME, [
		["the player has an Autoplay box", found, true],
		["it starts off", default_value, false],
		["and while off it is not written into the scene", text.contains("autoplay"), false]
	])


## "wait" in the Add box finds the two cards that wait: the search reads a kind's own search words.
static func _search_pins() -> bool:
	var schema: Dictionary = load(SCHEMA_PATH).call("schema")
	var found: PackedStringArray = PackedStringArray()
	for entry: Variant in EventSheetCardSchemas.kinds_of(schema):
		var words: String = " ".join(PackedStringArray((entry as Dictionary).get("search", PackedStringArray())))
		if words.to_lower().contains("wait"):
			found.append(str((entry as Dictionary).get("kind", "")))
	found.sort()
	return SUPPORT.pins(TEST_NAME, [
		["searching wait finds Hold and Pause", found, PackedStringArray(["hold_until", "pause"])]
	])
