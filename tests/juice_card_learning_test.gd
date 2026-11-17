# Godot EventSheets - learning Godot from a juice card: the Godot name under a field, the card as a
# row, and the card written as plain GDScript.
#
# THE ONE THING THIS FILE IS ABOUT: what a card teaches is true. The Godot name shown under a field
# names a class and a member Godot really has (and the class that DECLARES it: Light2D.energy, not
# PointLight2D.energy); "Show as GDScript" is the same effect written by hand, it parses on its own
# with no plugin, and it is labelled as that, not as what the card runs (the card also scales by
# strength, rolls its chance and keeps a way back); "Show as rows" is the Add Juice Card line that
# builds the same card. Every kind of card can be added from a row of the same name, and either shows a
# Godot name, a plain version, or says why it has none.
#
# The snippets for tween, hitstop and collision were also RUN outside the suite, beside the card they
# describe, and sampled per frame: rotation, time scale and the collision tick matched frame for frame.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_card_learning"

const LEARNING: String = "res://addons/eventsheet/editor/inspector/juice_card_learning.gd"
const SCHEMA: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const PACK: String = "res://eventsheet_addons/juice/juice_player.gd"

## Three cards and the code a user would write by hand for each.
const SNIPPETS: Array = [
	[{"verb": "tween_property", "effect": "rotation", "amount": 0.3, "seconds": 0.08},
		"var tween := create_tween()\ntween.tween_property(self, \"rotation\", 0.3, 0.08)"],
	[{"verb": "hitstop", "amount": 0.0, "effect": "", "seconds": 0.08},
		"var before := Engine.time_scale\nEngine.time_scale = 0.0\nawait get_tree().create_timer(0.08, true, false, true).timeout\nEngine.time_scale = before"],
	[{"verb": "collision_for", "node": NodePath("CollisionShape2D"), "seconds": 0.25},
		"var shape: CollisionShape2D = $CollisionShape2D\nshape.set_deferred(\"disabled\", true)\nawait get_tree().create_timer(0.25).timeout\nshape.set_deferred(\"disabled\", false)"],
]

## The cards that draw over the whole screen with a shader, or move the head of a list: no short plain version.
const NO_PLAIN_VERSION: PackedStringArray = ["shockwave", "chromatic", "pulse", "hold", "stop_sound", "hold_until", "loop_start", "loop_back"]


static func run() -> bool:
	var ok: bool = true
	ok = _godot_name_pins() and ok
	ok = _snippet_pins() and ok
	ok = _row_pins() and ok
	ok = _every_kind_pins() and ok
	ok = _drawer_pins() and ok
	return ok


## Where each snippet is written to be parsed on its own. Removed again at the end.
static func _paste_path() -> String:
	return SUPPORT.own_path("juice_card_learning_paste.gd")


static func _learning() -> GDScript:
	return load(LEARNING) as GDScript


static func _kinds() -> Array:
	return (load(SCHEMA) as GDScript).call("schema").get("kinds", []) as Array


## Every Godot name shown under a field is a real member, on the class that declares it.
static func _godot_name_pins() -> bool:
	var named: int = 0
	var wrong: PackedStringArray = PackedStringArray()
	var learning: GDScript = _learning()
	for kind: Variant in _kinds():
		for field: Variant in (kind as Dictionary).get("fields", []):
			var godot: String = str((field as Dictionary).get("godot", ""))
			if godot.is_empty():
				continue
			named += 1
			var owner_class: String = godot.get_slice(".", 0)
			var member: String = godot.get_slice(".", 1)
			var declared: bool = false
			for entry: Dictionary in ClassDB.class_get_property_list(owner_class, true):
				declared = declared or str(entry.get("name", "")) == member
			declared = declared or ClassDB.class_has_method(owner_class, member, true)
			if not declared:
				wrong.append(godot)
	return SUPPORT.pins(TEST_NAME, [
		["fields carry the Godot name they set", named > 20, true],
		["every one is declared on the class it names", ",".join(wrong), ""],
		["the light's brightness names the class that declares it", str(_field(_kind("light"), "energy_to").get("godot", "")), "Light2D.energy"],
		["the collision card names the shape's tick", str(_field(_kind("collision_for"), "node").get("godot", "")), "CollisionShape2D.disabled"],
		["a property's help page is found by its class and name", learning.call("help_topic", "Light2D.energy"), "class_property:Light2D:energy"],
		["a method's help page too", learning.call("help_topic", "Node.queue_free"), "class_method:Node:queue_free"],
		["a card's help entry opens the first name it has", learning.call("first_name", _kind("light")), "Light2D.energy"],
		["a card with no Godot name opens none", learning.call("first_name", _kind("loop_start")), ""],
	])


## "Show as GDScript": the same effect by hand, parsing on its own.
static func _snippet_pins() -> bool:
	var learning: GDScript = _learning()
	var rows: Array = []
	for snippet: Array in SNIPPETS:
		var card: Dictionary = snippet[0]
		var text: String = str(learning.call("as_gdscript", card))
		rows.append(["%s as GDScript" % card["verb"], text, snippet[1]])
		rows.append(["%s's code parses with no plugin" % card["verb"], _parses(text), true])
	rows.append(["the label says it is the same effect by hand, not what the card runs",
		str(learning.get_script_constant_map().get("AS_GDSCRIPT_NOTE", "")).contains("written by hand"), true])
	rows.append(["and that the card does more than the plain version",
		str(learning.get_script_constant_map().get("AS_GDSCRIPT_NOTE", "")).contains("strength"), true])
	return SUPPORT.pins(TEST_NAME, rows)


## "Show as rows": the line that adds the card, which builds the same card.
static func _row_pins() -> bool:
	var learning: GDScript = _learning()
	var card: Dictionary = {"verb": "shake", "amount": 0.4, "effect": "", "seconds": 0.2}
	var line: String = str(learning.call("as_row", card))
	var literal: String = line.get_slice(".add_feedback(", 1).rsplit(", ", true, 1)[0] if line.contains(".add_feedback(") else ""
	var field: Script = load("res://addons/eventsheet/editor/inspector/feedback_step_field.gd") as Script
	return SUPPORT.pins(TEST_NAME, [
		["a card as a row is the Add Juice Card line", line.begins_with("$JuicePlayer.add_feedback("), true],
		["and the card it builds is the card", field.call("parse_step", literal), card],
		["the pack has the row that line is", FileAccess.get_file_as_string(PACK).contains("# @ace_name(\"Add Juice Card\")"), true],
	])


## Every kind in the Add box can be added from a row, and has a plain version or a Godot name, or says it has neither.
static func _every_kind_pins() -> bool:
	var learning: GDScript = _learning()
	var lacking: PackedStringArray = PackedStringArray()
	var unparsed: PackedStringArray = PackedStringArray()
	var without_plain: PackedStringArray = PackedStringArray()
	var no_row: PackedStringArray = PackedStringArray()
	var step: Script = load("res://addons/eventsheet/editor/inspector/feedback_step_field.gd") as Script
	for kind: Variant in _kinds():
		var word: String = str((kind as Dictionary).get("kind", ""))
		var card: Dictionary = (kind as Dictionary).get("defaults", {}).duplicate()
		card["verb"] = word
		# A card that names a node is shown with one, the way a card in a scene has.
		for field: Variant in (kind as Dictionary).get("fields", []):
			if str((field as Dictionary).get("drawer", "")) == "node" and not card.has(str((field as Dictionary).get("key", ""))):
				card[str((field as Dictionary).get("key", ""))] = NodePath("Target")
		var row: String = str(learning.call("as_row", card))
		var literal: String = row.get_slice(".add_feedback(", 1).rsplit(", ", true, 1)[0]
		if (step.call("parse_step", literal) as Dictionary).get("verb", "") != word:
			no_row.append(word)
		var code: String = str(learning.call("as_gdscript", card))
		if code.is_empty():
			without_plain.append(word)
		elif not _parses(code):
			unparsed.append(word)
		var has_name: bool = not str(learning.call("first_name", kind)).is_empty()
		if code.is_empty() and not has_name and not NO_PLAIN_VERSION.has(word):
			lacking.append(word)
	without_plain.sort()
	var expected: PackedStringArray = NO_PLAIN_VERSION.duplicate()
	expected.sort()
	return SUPPORT.pins(TEST_NAME, [
		["every kind can be added from a row of its own words", ",".join(no_row), ""],
		["every plain version parses on its own", ",".join(unparsed), ""],
		["the kinds with no plain version are the screen effects and the words that move a list's head", ",".join(without_plain), ",".join(expected)],
		["a kind with neither a plain version nor a Godot name is one of those", ",".join(lacking), ""],
	])


## The card list: small print under the fields that name something in Godot, and three more entries in a card's menu
## that are greyed where there is nothing to show.
static func _drawer_pins() -> bool:
	var schema: Dictionary = (load(SCHEMA) as GDScript).call("schema")
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": schema})
	var cards: Array = [{"verb": "light", "energy_to": 3.0, "colour_to": Color(1.0, 0.6, 0.2), "seconds": 0.08}, {"verb": "shockwave", "amount": 1.0, "seconds": 0.3},
		{"verb": "loop_start"}]
	drawer.set_value(cards)
	drawer._unfolded[0] = true
	drawer._rebuild()
	var printed: PackedStringArray = PackedStringArray()
	_labels(drawer._list, printed)
	var menu: PopupMenu = PopupMenu.new()
	drawer._fill_card_menu(menu, 0)
	var shock: PopupMenu = PopupMenu.new()
	drawer._fill_card_menu(shock, 1)
	var loop: PopupMenu = PopupMenu.new()
	drawer._fill_card_menu(loop, 2)
	var rows: Array = [
		["an open Light card names what its energy sets", printed.has("Light2D.energy"), true],
		["and what its colour sets", printed.has("Light2D.color"), true],
		["the menu has the three entries", [menu.get_item_index(21) >= 0, menu.get_item_index(22) >= 0, menu.get_item_index(23) >= 0], [true, true, true]],
		["a Light card can be shown as GDScript and opened in help", [menu.is_item_disabled(menu.get_item_index(22)), menu.is_item_disabled(menu.get_item_index(23))], [false, false]],
		["a Shockwave has no plain version", shock.is_item_disabled(shock.get_item_index(22)), true],
		["and a Loop Start has neither a plain version nor a Godot name", [loop.is_item_disabled(loop.get_item_index(22)), loop.is_item_disabled(loop.get_item_index(23))], [true, true]],
		["showing it as rows is always there", loop.is_item_disabled(loop.get_item_index(21)), false],
	]
	menu.free()
	shock.free()
	loop.free()
	drawer.free()
	return SUPPORT.pins(TEST_NAME, rows)


static func _labels(node: Node, into: PackedStringArray) -> void:
	if node is Label:
		into.append((node as Label).text)
	for child: Node in node.get_children():
		_labels(child, into)


## Whether a snippet is valid GDScript with nothing of the plugin in it: parsed inside a function of a plain node.
static func _parses(body: String) -> bool:
	if body.is_empty():
		return false
	var lines: PackedStringArray = PackedStringArray()
	for line: String in body.split("\n"):
		lines.append("\t" + line)
	var path: String = _paste_path()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("extends Node2D\n\n\nfunc run() -> void:\n%s\n" % "\n".join(lines))
	file.close()
	var script: GDScript = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return script != null and script.can_instantiate()


static func _kind(word: String) -> Dictionary:
	for kind: Variant in _kinds():
		if str((kind as Dictionary).get("kind", "")) == word:
			return kind as Dictionary
	return {}


static func _field(kind: Dictionary, key: String) -> Dictionary:
	for field: Variant in kind.get("fields", []):
		if str((field as Dictionary).get("key", "")) == key:
			return field as Dictionary
	return {}
