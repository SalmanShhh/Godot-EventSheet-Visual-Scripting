# Godot EventSheets - a card of your own: a script that extends JuiceCard, kept in the list as data.
#
# THE ONE THING THIS FILE IS ABOUT: a card of your own is one more dictionary in the same list, naming its
# script by the address of its file and holding its values as keys named after the script's exports. So the
# list keeps its saved type forever, the card copies and pastes as text, and a row can address it by its
# label. The script is written to a real file: the analyzer and `load()` read a script off disk, and one
# built from a string in memory would pass for the wrong reason.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NEW_PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const OLD_PACK: String = "res://eventsheet_addons/juice/feedback_player.gd"
const BASE_PATH: String = "res://eventsheet_addons/juice/juice_card.gd"
const EXAMPLE_PATH: String = "res://eventsheet_addons/juice/screen_flash_card.gd"
const OWN_PATH: String = "res://addons/eventsheet/editor/inspector/juice_own_cards.gd"
const WORLD_PATH: String = "res://addons/eventsheet/editor/inspector/juice_world_preview.gd"
const STRIP_PATH: String = "res://addons/eventsheet/editor/inspector/feedback_player_strip.gd"

const TEST_NAME: String = "juice_card_of_your_own"


static func run() -> bool:
	var ok: bool = true
	ok = _base_pins() and ok
	ok = _play_pins() and ok
	ok = _door_pins() and ok
	ok = _row_pins() and ok
	ok = _host_pins() and ok
	ok = _list_pins() and ok
	ok = _preview_pins() and ok
	ok = _sheet_pins() and ok
	return ok


static func _pack() -> Script:
	return load(NEW_PACK if ResourceLoader.exists(NEW_PACK) else OLD_PACK) as Script


## Writes a card script to a file the test owns and loads it fresh. `body` is everything after the extends line.
static func _card_script(file_name: String, tool_script: bool, body: String) -> String:
	var path: String = SUPPORT.own_path(file_name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("%sextends \"%s\"\n\n%s" % ["@tool\n" if tool_script else "", BASE_PATH, body])
	file.close()
	ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	return path


static func _base_pins() -> bool:
	var exists: bool = ResourceLoader.exists(BASE_PATH)
	var base: Script = load(BASE_PATH) as Script if exists else null
	var methods: PackedStringArray = PackedStringArray()
	if base != null:
		for listed: Dictionary in base.get_script_method_list():
			if str(listed.get("name")) in ["play", "length", "stop", "restore"]:
				methods.append(str(listed.get("name")))
	methods.sort()
	return SUPPORT.pins(TEST_NAME, [
		["the pack ships a JuiceCard base", exists, true],
		["it is a Resource with the four doors a card answers", [str(base.get_global_name()) if base != null else "", methods],
			["JuiceCard", PackedStringArray(["length", "play", "restore", "stop"])]],
		["it is a plain script, never a tool one", base.is_tool() if base != null else true, false]
	])


## A card of your own, written to disk, played from the list: its values arrive on its exports and its own play
## runs, and a class called Pause is still a card of yours, not the Pause word.
static func _play_pins() -> bool:
	var path: String = _card_script("juice_own_card_a.gd", false,
		"@export var word: String = \"\"\n@export var times: int = 1\n\n\nfunc play(target: Node, _strength: float) -> void:\n\ttarget.set_meta(&\"heard\", word + str(times))\n")
	var host: Node2D = Node2D.new()
	var player: Node = _pack().new()
	host.add_child(player)
	player.set("host", host)
	player.set("steps", _typed([{"verb": "Pause", "card_script": path, "word": "boom", "times": 3, "label": "Mine", "seconds": 5.0}]))
	player.call("play", 1.0)
	var heard: String = str(host.get_meta(&"heard", ""))
	var waited: bool = bool(player.get("playing"))
	host.free()
	var pack: Script = _pack()
	var plain: Dictionary = {"verb": "Pause", "seconds": 5.0}
	var yours: Dictionary = {"verb": "Pause", "card_script": path}
	return SUPPORT.pins(TEST_NAME, [
		["its value arrives on its export and its play runs", heard, "boom3"],
		["a card whose class is called Pause is still a card of yours, not the Pause word", waited, false],
		["the word a card is played under is its script, not its class", [pack.call("word_of", yours), pack.call("word_of", plain)], ["yours", "pause"]],
		["a card whose script is gone is said to be missing and does nothing", pack.call("own_card_of", {"card_script": "res://not_a_card_at_all.gd"}) == null, true]
	])


## How long a card of your own takes, and the two doors that end it: Stop Juice and Restore Initial Values.
static func _door_pins() -> bool:
	var timed: String = _card_script("juice_own_card_b.gd", false,
		"@export var seconds: float = 0.5\n")
	var told: String = _card_script("juice_own_card_c.gd", false,
		"func length() -> float:\n\treturn 2.0\n\n\nfunc stop() -> void:\n\tplayer.get_parent().set_meta(&\"door\", str(player.get_parent().get_meta(&\"door\", \"\")) + \"stop \")\n\n\nfunc restore() -> void:\n\tplayer.get_parent().set_meta(&\"door\", str(player.get_parent().get_meta(&\"door\", \"\")) + \"restore\")\n")
	var pack: Script = _pack()
	var host: Node2D = Node2D.new()
	var player: Node = pack.new()
	host.add_child(player)
	player.set("host", host)
	player.set("steps", _typed([{"verb": "Cut", "card_script": told, "label": "Cut"}]))
	player.call("play", 1.0)
	player.call("stop")
	player.call("restore")
	var doors: String = str(host.get_meta(&"door", ""))
	host.free()
	return SUPPORT.pins(TEST_NAME, [
		["a card that exports seconds is that long without writing length", pack.call("card_length", {"verb": "Flash", "card_script": timed}), 0.5],
		["a card that writes length says its own", pack.call("card_length", {"verb": "Cut", "card_script": told}), 2.0],
		["the list is as long as its cards", pack.call("duration_of", [{"verb": "A", "card_script": timed}, {"verb": "B", "card_script": told}]), 2.0],
		["Stop Juice tells a card that is still going, and Restore Initial Values tells it to put things back", doors, "stop restore"]
	])


## Set Juice Card Field reaches every key a card holds, and refuses the two that make it that card.
static func _row_pins() -> bool:
	var path: String = _card_script("juice_own_card_d.gd", false,
		"@export var amount_of: int = 1\n@export var colour: Color = Color.WHITE\n")
	var player: Node = _pack().new()
	player.set("steps", _typed([
		{"verb": "Mine", "card_script": path, "amount_of": 1, "colour": Color.WHITE, "label": "Mine"},
		{"verb": "shake", "amount": 1.0, "seconds": 0.2, "label": "Shake"}
	]))
	player.call("set_feedback_field", "Mine", "amount_of", 7)
	player.call("set_feedback_field", "Mine", "colour", Color.RED)
	player.call("set_feedback_field", "Mine", "verb", "pause")
	player.call("set_feedback_field", "Mine", "card_script", "res://other.gd")
	player.call("set_feedback_field", "Mine", "nothing_here", 1)
	player.call("set_feedback_field", "Shake", "delay", 0.3)
	player.call("add_feedback", {"verb": "Mine", "card_script": path, "label": "Added"}, "")
	var added: Dictionary = (player.get("steps") as Array)[2] as Dictionary
	var card: Dictionary = (player.get("steps") as Array)[0] as Dictionary
	var shake: Dictionary = (player.get("steps") as Array)[1] as Dictionary
	player.free()
	return SUPPORT.pins(TEST_NAME, [
		["a key the card holds is written", [card.get("amount_of"), card.get("colour")], [7, Color.RED]],
		["the word and the script of a card are left alone", [card.get("verb"), card.get("card_script")], ["Mine", path]],
		["a key no card holds is not invented", card.has("nothing_here"), false],
		["a row that adds a card of yours adds it as it is, with none of a moment file's four keys", added.keys(), ["verb", "card_script", "label"]],
		["the eight shipped names still reach a card that did not hold them yet", shake.get("delay"), 0.3]
	])


## A sheet may extend a class of the project that extends Resource: its host is recognised as data. The
## example card is such a class, two bases down.
static func _host_pins() -> bool:
	var project_resource: String = ""
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("base")) == "Resource":
			project_resource = str(entry.get("class"))
			break
	return SUPPORT.pins(TEST_NAME, [
		["the project has a class extending Resource to ask about", project_resource.is_empty(), false],
		["a sheet extending it is a resource sheet", EventSheetScriptIntent.is_resource_host(project_resource), true],
		["and its members read as fields", EventSheetVariableSentence.is_resource_host(project_resource), true],
		["a class two bases down reaches Resource too", [EventSheetScriptIntent.is_resource_host("ScreenFlashCard"), EventSheetVariableSentence.is_resource_host("ScreenFlashCard")], [true, true]],
		["a name nobody has heard of is not a resource", EventSheetScriptIntent.is_resource_host("NoSuchClassAnywhere"), false],
		["a node class is not", [EventSheetScriptIntent.is_resource_host("Node2D"), EventSheetVariableSentence.is_resource_host("Node2D")], [false, false]]
	])


## The Add box lists the project's cards under Yours, named from the class, with the fields its exports make;
## a saved card is found by its script; the list keeps the type it was saved with.
static func _list_pins() -> bool:
	var own: Script = load(OWN_PATH) as Script
	own.call("reset")
	var kinds: Array = own.call("kinds")
	var entry: Dictionary = {}
	for each: Variant in kinds:
		if str((each as Dictionary).get("kind")) == "ScreenFlashCard":
			entry = each as Dictionary
	var field_keys: PackedStringArray = PackedStringArray()
	var seconds_hint: String = ""
	for field: Variant in entry.get("fields", []):
		field_keys.append(str((field as Dictionary).get("key")))
		if str((field as Dictionary).get("key")) == "seconds":
			seconds_hint = str(((field as Dictionary).get("spec", {}) as Dictionary).get("hint_string", ""))
	var schema: Dictionary = (load("res://addons/eventsheet/editor/inspector/feedback_card_schema.gd") as Script).call("schema")
	var headings: Dictionary = {}
	for group: Variant in EventSheetCardSchemas.kinds_by_category(schema):
		var labels: PackedStringArray = PackedStringArray()
		for each: Variant in (group as Dictionary).get("kinds", []):
			labels.append(str((each as Dictionary).get("label")))
		headings[str((group as Dictionary).get("name"))] = labels
	var spec: Dictionary = {"kind_key": "verb"}
	var made: Dictionary = EventSheetCardSchemas.new_card(spec, entry)
	var renamed: Dictionary = {"verb": "AnOldName", "card_script": made.get("card_script"), "seconds": 0.3}
	var found: Dictionary = own.call("entry_for", renamed)
	var pasted: Array = EventSheetCardSchemas.cards_from_text(EventSheetCardSchemas.cards_to_text([made]))
	var steps_hint: String = ""
	var hint_player: Node = _pack().new()
	for property: Dictionary in hint_player.get_property_list():
		if str(property.get("name")) == "steps":
			steps_hint = str(property.get("hint_string"))
	hint_player.free()
	var made_player: Node = _pack().new()
	var steps_type: int = -1
	for property: Dictionary in made_player.get_property_list():
		if str(property.get("name")) == "steps":
			steps_type = int(property.get("type"))
	var steps_value: Array = made_player.get("steps") as Array
	var steps_element: int = steps_value.get_typed_builtin()
	made_player.free()
	return SUPPORT.pins(TEST_NAME, [
		["the project's own cards are read from its classes", entry.is_empty(), false],
		["named from the class, with a closing Card dropped", entry.get("label"), "Screen Flash"],
		["in the family of the ones you wrote", entry.get("category"), "yours"],
		["with the help line written under the class", entry.get("help"), "Flashes the whole screen a colour."],
		["and a field for each export, named as written", field_keys, PackedStringArray(["colour", "seconds"])],
		["a field whose export hint carries a unit hands Godot's own editor that hint, which draws the unit after the number", seconds_hint.contains("suffix:s"), true],
		["the Add box has a Yours heading holding it", (headings.get("Yours", PackedStringArray()) as PackedStringArray).has("Screen Flash"), true],
		["Yours comes after the families that ship", str(headings.keys()[headings.keys().size() - 1]), "Yours"],
		["a new card names its script first and starts with the values its exports start with",
			[made.get("verb"), str(made.get("card_script")).begins_with("uid://"), made.get("seconds")], ["ScreenFlashCard", true, 0.1]],
		["a saved card is found by its script even when its class was renamed", found.get("kind"), "ScreenFlashCard"],
		["a card copied as text arrives with every key", pasted, [made]],
		["the list keeps the type and the hint it was saved with forever", [steps_type, steps_element, steps_hint],
			[TYPE_ARRAY, TYPE_DICTIONARY, "eventsheet:cards:kind=verb,schema=feedback_steps,stripes=category"]]
	])


## A card of yours that is a tool script is played by the editor's preview and told to put things back; one that
## is not says why it is not shown.
static func _preview_pins() -> bool:
	var tool_path: String = _card_script("juice_own_card_e.gd", true,
		"func play(target: Node, _strength: float) -> void:\n\ttarget.set_meta(&\"tool\", \"played\")\n\n\nfunc restore() -> void:\n\tplayer.get_parent().set_meta(&\"tool\", \"restored\")\n")
	var plain_path: String = _card_script("juice_own_card_f.gd", false,
		"func play(target: Node, _strength: float) -> void:\n\ttarget.set_meta(&\"tool\", \"never\")\n")
	var world: Script = load(WORLD_PATH) as Script
	var strip: Script = load(STRIP_PATH) as Script
	var host: Node2D = Node2D.new()
	var player: Node = _pack().new()
	host.add_child(player)
	var state: Dictionary = {"player": player}
	var tool_card: Dictionary = {"verb": "Tool", "card_script": tool_path}
	var plain_card: Dictionary = {"verb": "Plain", "card_script": plain_path}
	world.call("step", tool_card, world.call("node_of", player, tool_card, host), 0.0, 1.0, state, 0)
	var played: String = str(host.get_meta(&"tool", ""))
	world.call("step", tool_card, host, 0.5, 1.0, state, 0)
	world.call("finish", state)
	var restored: String = str(host.get_meta(&"tool", ""))
	var said_tool: String = str(strip.call("what_editor_does", tool_card, _pack()))
	var said_plain: String = str(strip.call("what_editor_does", plain_card, _pack()))
	host.free()
	return SUPPORT.pins(TEST_NAME, [
		["the preview handles a tool card and leaves a plain one", [world.call("handles", tool_card), world.call("handles", plain_card)], [true, false]],
		["a tool card is played at its turn, once", played, "played"],
		["and told to put things back when the pass is over", restored, "restored"],
		["Debug view says a tool card is played", said_tool, "played"],
		["and says why a plain one is not shown", said_plain.begins_with("not shown in the editor: ") and said_plain.contains("@tool"), true]
	])


## The example card is a Custom Resource sheet, and the same card written by hand as GDScript opens as one too:
## both are the plain script a person would write, and both save back byte for byte.
static func _sheet_pins() -> bool:
	var shipped: String = FileAccess.get_file_as_string(EXAMPLE_PATH)
	var by_hand: String = "class_name ScreenFlashByHand
extends JuiceCard
## Flashes the whole screen a colour.

## The colour to flash.
@export var colour: Color = Color.WHITE
## How long the flash lasts.
@export_range(0.0, 2.0, 0.01, \"suffix:s\") var seconds: float = 0.1


func play(target: Node, strength: float) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(colour, strength)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	target.add_child(layer)
	await target.get_tree().create_timer(seconds).timeout
	layer.queue_free()


func length() -> float:
	return seconds
"
	var opened: EventSheetResource = SUPPORT.reopen(shipped, true, EXAMPLE_PATH)
	var hand_opened: EventSheetResource = SUPPORT.reopen(by_hand, true, SUPPORT.own_path("by_hand_card.gd"))
	return SUPPORT.pins(TEST_NAME, [
		["the example card opens as a Custom Resource sheet extending JuiceCard",
			[opened.host_class, EventSheetScriptIntent.of_sheet(opened) == EventSheetScriptIntent.Intent.CUSTOM_RESOURCE], ["JuiceCard", true]],
		["and saves back byte for byte", SUPPORT.reemit(shipped, EXAMPLE_PATH) == shipped, true],
		["the same card written by hand opens as one too", [hand_opened.host_class, EventSheetScriptIntent.of_sheet(hand_opened) == EventSheetScriptIntent.Intent.CUSTOM_RESOURCE], ["JuiceCard", true]],
		["and also saves back byte for byte", SUPPORT.reemit(by_hand, SUPPORT.own_path("by_hand_card.gd")) == by_hand, true],
		["the example carries nothing of the plugin but its version line", shipped.replace("# @ace_version(1.0.0)", "").contains("@ace_"), false]
	])


static func _typed(list: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	for entry: Variant in list:
		typed.append(entry as Dictionary)
	return typed
