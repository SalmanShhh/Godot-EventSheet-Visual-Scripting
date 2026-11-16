# Godot EventSheets - the juice cards that point at other nodes and at the world.
#
# THE ONE THING THIS FILE IS ABOUT: a card that points at a node keeps the way to it as a NodePath
# relative to the player, the editor draws it with Godot's pickers and says in quiet amber when the path
# finds nothing, and the running list does what the card says or says once why it did not. The suite has
# no scene tree and no clock, so what is pinned here is what needs neither: the vocabulary, the saved
# shape, the words each card plays by, the refusals, and the pushes that need no physics step. What the
# cards DO over time is proven by a game run.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SCHEMA_PATH: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const FIELDS_PATH: String = "res://addons/eventsheet/editor/inspector/juice_card_fields.gd"
const PACK: String = "res://eventsheet_addons/juice/juice_player.gd"

const TEST_NAME: String = "juice_world_cards"

## Every kind this build adds, and the family each one belongs to.
const NEW_KINDS: Dictionary = {
	"particles": "scene", "spawn_scene": "scene", "push": "scene", "force_for_a_time": "scene",
	"gravity_for_a_time": "scene", "freeze_body": "scene", "animation": "transform",
	"sprite_animation": "transform", "show_hide": "transform", "squash_stretch": "transform",
	"punch_position": "transform", "punch_rotation": "transform", "pop": "transform", "fade": "transform",
	"grab_focus": "transform", "count_to": "transform", "reveal_text": "transform",
	"fill_bar": "transform", "shader_value": "transform", "call_method": "signal"
}


static func run() -> bool:
	var ok: bool = true
	ok = _vocabulary_pins() and ok
	ok = _saved_shape_pins() and ok
	ok = _runtime_pins() and ok
	ok = _drawer_pins() and ok
	ok = _menu_pins() and ok
	ok = _words_pins() and ok
	ok = _enter_pins() and ok
	return ok


static func _pack() -> Script:
	return load(PACK) as Script


static func _kinds() -> Array:
	return (load(SCHEMA_PATH) as Script).call("schema").get("kinds")


static func _kind(word: String) -> Dictionary:
	for entry: Variant in _kinds():
		if str((entry as Dictionary).get("kind", "")) == word:
			return entry as Dictionary
	return {}


## The vocabulary: every new word is a kind, belongs to the family the board gives it, is one the pack plays
## itself, and says in the Debug view why the editor does not play it.
static func _vocabulary_pins() -> bool:
	var rows: Array = []
	var pack_words: PackedStringArray = _pack().get_script_constant_map().get("WORLD_WORDS")
	var families: Dictionary = _pack().get_script_constant_map().get("CATEGORY_OF")
	for word: Variant in NEW_KINDS:
		var entry: Dictionary = _kind(str(word))
		rows.append(["%s is a kind of card" % word, not entry.is_empty(), true])
		rows.append(["%s is in the family the board draws" % word, families.get(word, ""), NEW_KINDS[word]])
		rows.append(["%s reads the same family in the Inspector" % word, str(entry.get("category", "")), NEW_KINDS[word]])
		rows.append(["%s is played by the player itself (a moment file cannot hold it)" % word, pack_words.has(str(word)) or word == "call_method", true])
	rows.append(["a card that starts a physics shove is skipped in the editor and says so",
		str(_pack().call("editor_kind", "push")).begins_with("skipped:"), true])
	rows.append(["Spawn Scene is skipped in the editor and says so",
		str(_pack().call("editor_kind", "spawn_scene")).begins_with("skipped:"), true])
	rows.append(["the eight shipped field keys of Set Juice Card Field did not move",
		Array(_pack().get_script_constant_map().get("FIELD_KEYS")),
		["amount", "effect", "seconds", "delay", "interval", "repeat", "chance", "loops"]])
	return SUPPORT.pins(TEST_NAME, rows)


## What a card is saved as: a NodePath stays a NodePath through a saved scene, and an older Tween Property
## card (one number on this object) is still the card it was.
static func _saved_shape_pins() -> bool:
	var holder: Node = Node.new()
	holder.set_script(_pack())
	var list: Array[Dictionary] = [
		{"verb": "particles", "node": NodePath("../Sparks"), "do": "restart", "seconds": 0.4},
		{"verb": "tween_property", "effect": "rotation", "amount": 1.0, "seconds": 0.2}
	]
	holder.set("steps", list)
	var scene: PackedScene = PackedScene.new()
	scene.pack(holder)
	var path: String = SUPPORT.own_path("juice_world_cards.tscn")
	ResourceSaver.save(scene, path)
	var text: String = FileAccess.get_file_as_string(path)
	var reloaded: Node = (load(path) as PackedScene).instantiate()
	var back: Array = reloaded.get("steps")
	var rows: Array = [
		["the saved scene holds the path as a NodePath", text.contains("NodePath(\"../Sparks\")"), true],
		["the card reads back with its path", (back[0] as Dictionary).get("node"), NodePath("../Sparks")],
		["the path is still a NodePath, not text", (back[0] as Dictionary).get("node") is NodePath, true],
		["an older Tween Property card reads back exactly", back[1], list[1]],
		["an older Tween Property card is not the whole card", _pack().call("_is_whole_tween", list[1]), false],
		["a Tween Property card that names a node is the whole card", _pack().call("_is_whole_tween", {"verb": "tween_property", "node": NodePath("../A")}), true],
		["a typed To makes it the whole card", _pack().call("_is_whole_tween", {"verb": "tween_property", "to": Color.RED}), true]
	]
	holder.free()
	reloaded.free()
	return SUPPORT.pins(TEST_NAME, rows)


## What the running list does without a tree: a missing node is said once and tells On Juice Card Skipped; a
## push on a character body adds to its velocity once; a player will not play itself or one that plays it.
static func _runtime_pins() -> bool:
	var player: Node = Node.new()
	player.set_script(_pack())
	var skipped: Array = []
	player.connect("on_feedback_skipped", func(label: String, why: String) -> void: skipped.append([label, why]))
	var lost: Dictionary = {"verb": "particles", "node": NodePath("../Nowhere"), "label": "Burst"}
	player.call("_do_step", lost, 1.0)
	player.call("_do_step", lost, 1.0)
	var body: CharacterBody2D = CharacterBody2D.new()
	body.name = "Body"
	player.add_child(body)
	player.call("_do_step", {"verb": "push", "body": NodePath("Body"), "direction": "fixed", "x": 0.0, "y": -1.0, "speed": 300.0}, 0.5)
	var scaled: Vector2 = body.velocity
	body.velocity = Vector2.ZERO
	player.call("_do_step", {"verb": "push", "body": NodePath("Body"), "direction": "fixed", "x": 3.0, "y": 0.0, "speed": 100.0, "scaled": false}, 0.5)
	var plain: Vector2 = body.velocity
	var other: Node = Node.new()
	other.set_script(_pack())
	other.set("playing", true)
	(other.get("_nested") as Array).append(player)
	var rows: Array = [
		["a card whose node is missing tells On Juice Card Skipped each time", skipped.size(), 2],
		["and says why", skipped[0], ["Burst", "target missing"]],
		["but names the missing node once", (player.get("_told_cards") as Dictionary).keys(), ["Burst"]],
		["a push is scaled by the strength of the play", scaled, Vector2(0.0, -150.0)],
		["a push can be left unscaled and is added to the velocity", plain, Vector2(100.0, 0.0)],
		["a player does not play itself", player.call("_player_to_play", {"verb": "play_player", "player": NodePath(".")}, ""), null],
		["a player does not play one that is playing it", player.call("_plays_through", other, player, 0), true],
		["a player that is not playing is not a cycle", player.call("_plays_through", player, other, 0), false],
		["a plain number on a card is a number", player.call("_number_from", " 12.5 "), 12.5],
		["a name that is nowhere is no number", player.call("_number_from", "Nothing.here"), null]
	]
	other.free()
	player.free()
	return SUPPORT.pins(TEST_NAME, rows)


## The drawer: every new kind adds, opens and draws its fields without a scene, and a node field says in
## amber when its path finds nothing.
static func _drawer_pins() -> bool:
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": (load(SCHEMA_PATH) as Script).call("schema")})
	var rows: Array = []
	var parent: Node = Node.new()
	var player: Node = Node.new()
	player.set_script(_pack())
	player.name = "Player"
	parent.add_child(player)
	var sparks: Node = Node.new()
	sparks.name = "Sparks"
	parent.add_child(sparks)
	drawer.set_edited_object(player)
	for word: Variant in NEW_KINDS:
		drawer.add_card(str(word))
	var drawn: int = 0
	for index: int in range(drawer.get_value().size()):
		drawer._unfolded[index] = true
	drawer._rebuild()
	for index: int in range(drawer.get_value().size()):
		drawn += 1 if drawer._lines.has(index) else 0
	rows.append(["every new kind adds and opens as a card", drawn, NEW_KINDS.size()])
	var fields: Script = load(FIELDS_PATH) as Script
	var near: Dictionary = {"node": NodePath("../Sparks")}
	var gone: Dictionary = {"node": NodePath("../Smoke")}
	rows.append(["a path that finds a node has nothing to say", fields.call("missing_note", player, near, "node"), ""])
	rows.append(["a path that finds nothing says which node is not there", fields.call("missing_note", player, gone, "node"), "Smoke is not under this object any more."])
	rows.append(["a card that names no node has nothing to say", fields.call("missing_note", player, {}, "node"), ""])
	sparks.name = "Embers"
	rows.append(["a node renamed after the pick is reported until the path follows it", fields.call("missing_note", player, near, "node"), "Sparks is not under this object any more."])
	rows.append(["a card with no node acts on the object the player is under", fields.call("target_of", player, {}, "node"), parent])
	var tween: Dictionary = _kind("tween_property")
	var field_keys: Array = []
	for field: Variant in tween.get("fields"):
		field_keys.append(str((field as Dictionary).get("key", "")))
	rows.append(["a Tween Property card keeps its Property key as the word it always stored", field_keys.has("effect"), true])
	rows.append(["and gains the keys of the whole card", field_keys.has("node") and field_keys.has("to") and field_keys.has("trans") and field_keys.has("back"), true])
	drawer.free()
	player.free()
	sparks.free()
	parent.free()
	return SUPPORT.pins(TEST_NAME, rows)


## The card menu shows the keys that do the same from the list, beside Cut, Copy, Paste, Duplicate and Remove.
static func _menu_pins() -> bool:
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": (load(SCHEMA_PATH) as Script).call("schema")})
	var popup: PopupMenu = PopupMenu.new()
	drawer._fill_card_menu(popup)
	var hints: Dictionary = {}
	for index: int in range(popup.item_count):
		hints[popup.get_item_text(index)] = popup.get_item_accelerator(index)
	var rows: Array = []
	for word: String in ["Duplicate", "Cut", "Copy", "Paste", "Remove"]:
		rows.append(["the menu shows a key beside %s" % word, int(hints.get(word, 0)) != 0, true])
	rows.append(["the others show none", int(hints.get("Paste over", 0)) + int(hints.get("Move to top", 0)) + int(hints.get("Move to bottom", 0)), 0])
	rows.append(["Move up and Move down show the keys that walk the selection", [OS.get_keycode_string(hints.get("Move up", 0)), OS.get_keycode_string(hints.get("Move down", 0))], ["Alt+Up", "Alt+Down"]])
	popup.free()
	drawer.free()
	return SUPPORT.pins(TEST_NAME, rows)


## A node field shows the node's name as the Scene dock does, whatever the path to it looks like, and its
## path in the tooltip; the Reveal Text card is a speed in letters a second that sets the card's length.
static func _words_pins() -> bool:
	var fields: Script = load(FIELDS_PATH) as Script
	var parent: Node = Node.new()
	parent.name = "Actor"
	var player: Node = Node.new()
	player.set_script(_pack())
	player.name = "Player"
	parent.add_child(player)
	var label: Label = Label.new()
	label.name = "Banner"
	label.text = "Hello there world"
	parent.add_child(label)
	var kinds: Script = load("res://addons/eventsheet/editor/inspector/juice_card_kinds.gd") as Script
	var card: Dictionary = {"node": NodePath("../Banner"), "speed": 34.0}
	var rows: Array = [
		["a parent shows its name, not two dots", fields.call("node_words", player, {"node": NodePath("..")}, "node", ""), "Actor"],
		["the player itself shows its name", fields.call("node_words", player, {"node": NodePath(".")}, "node", ""), "Player"],
		["a sibling shows its name", fields.call("node_words", player, {"node": NodePath("../Banner")}, "node", ""), "Banner"],
		["a node that is gone shows its last name", fields.call("node_words", player, {"node": NodePath("../Smoke")}, "node", ""), "Smoke"],
		["picking the label sets the length from its letters", kinds.call("reveal_length", card, label), {"seconds": 0.5}],
		["a new speed sets the length again", kinds.call("reveal_length_for_speed", card, player, 17.0), {"seconds": 1.0}],
		["the property picker's answer, with its leading colon, is the plain property name", fields.call("property_text", NodePath(":modulate")), "modulate"],
		["a card that has a preview in the editor says it is played", _pack().call("editor_kind", "particles"), "felt"]
	]
	label.free()
	player.free()
	parent.free()
	return SUPPORT.pins(TEST_NAME, rows)


## Enter in the Add box's search adds the first card it found.
static func _enter_pins() -> bool:
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": (load(SCHEMA_PATH) as Script).call("schema")})
	drawer._on_add_pressed()
	drawer._add_filter.text = "tween"
	drawer._fill_add_tree()
	drawer._add_filter.text_submitted.emit("tween")
	var added: Array = drawer.get_value()
	var rows: Array = [["Enter adds the first card the search found", [added.size(), (added[0] as Dictionary).get("verb") if added.size() > 0 else ""], [1, "tween_property"]]]
	drawer.free()
	return SUPPORT.pins(TEST_NAME, rows)
