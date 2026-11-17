# Godot EventSheets - the Light card's start values, the named layers of Collision Layer For A Time, and
# a Bus Effect card that takes off the effect it added.
#
# THE ONE THING THIS FILE IS ABOUT: three small promises the cards make. A Light card can say where it
# begins (energy and colour), and a card that says nothing begins where the light is, so every saved card
# plays as it did. A collision layer is picked from the names the project gave its layers, and a layer
# nobody named shows its number. A bus effect card that had to ADD an effect (the bus lacked one) takes it
# off again when the last card holding it is done, and forgets where the bus rested, so the bus layout is
# what it was before the card.
#
# The bus part runs on the real audio server (it works with no sound device) on a bus of its own made
# for the test and removed at the end.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_card_light_layers_bus"

const PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const SCHEMA: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const SCENE_KINDS: String = "res://addons/eventsheet/editor/inspector/juice_scene_kinds.gd"
const BUS_NAME: String = "JuiceCardTestBus"


static func run() -> bool:
	var ok: bool = true
	ok = _light_pins() and ok
	ok = _layer_pins() and ok
	ok = _bus_pins() and ok
	ok = _drawer_pins() and ok
	return ok


## The Light card says where it begins, and says "from where it is" until it is told.
static func _light_pins() -> bool:
	var kind: Dictionary = _kind("light")
	var keys: PackedStringArray = PackedStringArray()
	for field: Variant in kind.get("fields", []):
		keys.append(str((field as Dictionary).get("key", "")))
	var start: Dictionary = kind.get("defaults", {})
	var energy_from: Dictionary = _field(kind, "energy_from")
	var colour_from: Dictionary = _field(kind, "colour_from")
	var script: GDScript = load(PACK)
	return SUPPORT.pins(TEST_NAME, [
		["the card has a start for the energy and a start for the colour, each before its end", ",".join(keys).contains("energy_from,energy_to") and ",".join(keys).contains("colour_from,colour_to"), true],
		["the energy start is a box that can be left alone", str(energy_from.get("drawer", "")), "optional"],
		["the colour start is a box that can be left alone", str(colour_from.get("drawer", "")), "optional_color"],
		["each says what leaving it alone means", [str(energy_from.get("empty", "")), str(colour_from.get("empty", ""))], ["From where it is", "From where it is"]],
		["a new card stores neither start, so a saved card plays as it did", [start.has("energy_from"), start.has("colour_from")], [false, false]],
		["the pack knows the two keys", _text(PACK).contains("card.has(\"energy_from\")") and _text(PACK).contains("card.has(\"colour_from\")"), true],
		["a card with a start is no longer than one without", script.call("card_length", {"verb": "light", "seconds": 0.08, "back": true, "back_seconds": 0.2, "energy_from": 0.0}), 0.28],
	])


## The layer is picked from the project's names; a layer nobody named is its number.
static func _layer_pins() -> bool:
	var kinds: Script = load(SCENE_KINDS) as Script
	var kind: Dictionary = _kind("collision_layer_for")
	var layer: Dictionary = _field(kind, "layer")
	var setting: String = "layer_names/2d_physics/layer_3"
	var before: Variant = ProjectSettings.get_setting(setting, "")
	ProjectSettings.set_setting(setting, "Walls")
	var named: String = str(kinds.call("layer_words", "2d_physics", 3))
	var unnamed: String = str(kinds.call("layer_words", "2d_physics", 4))
	var three_d: String = str(kinds.call("layer_words", "3d_physics", 3))
	ProjectSettings.set_setting(setting, before)
	var words: PackedStringArray = kinds.call("layer_choices", "2d_physics")
	return SUPPORT.pins(TEST_NAME, [
		["the layer is picked from a list", str(layer.get("drawer", "")), "layer_pick"],
		["a layer the project named reads its name with its number", named, "3 - Walls"],
		["a layer nobody named reads its number", unnamed, "4"],
		["the 3D layers are asked of the 3D names, not the 2D ones", three_d, "3"],
		["the list offers all thirty-two layers", words.size(), 32],
		["a new card still starts on layer 1 with the mask", [(kind.get("defaults", {}) as Dictionary).get("layer"), (kind.get("defaults", {}) as Dictionary).get("part")], [1, "mask"]],
	])


## An effect the card added comes off again; one the project put there stays; two cards share it.
static func _bus_pins() -> bool:
	var script: GDScript = load(PACK)
	AudioServer.add_bus()
	var index: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, BUS_NAME)
	var player: Node = script.new() as Node
	var mix: GDScript = load("res://eventsheet_addons/bus_mix.gd") as GDScript
	var resting_before: bool = Engine.has_meta(mix.get_script_constant_map()["RESTING_META"]) and (Engine.get_meta(mix.get_script_constant_map()["RESTING_META"]) as Dictionary).has(BUS_NAME)
	# The card with no scene tree to count in writes at once and gives back at once, which is what runs the way back.
	var card: Dictionary = {"verb": "bus_effect", "bus": BUS_NAME, "how": "muffle", "to": 400.0, "seconds": 0.5, "back_seconds": 0.2}
	var count_before: int = AudioServer.get_bus_effect_count(index)
	script.call("_bus_hold", BUS_NAME, "muffle")
	var added: int = AudioServer.get_bus_effect_count(index)
	var added_is_lowpass: bool = added > 0 and AudioServer.get_bus_effect(index, added - 1) is AudioEffectLowPassFilter
	script.call("_bus_hold", BUS_NAME, "muffle")
	var two_holds: int = AudioServer.get_bus_effect_count(index)
	script.call("_bus_let_go", BUS_NAME, "muffle")
	var after_one: int = AudioServer.get_bus_effect_count(index)
	script.call("_bus_let_go", BUS_NAME, "muffle")
	var after_both: int = AudioServer.get_bus_effect_count(index)
	var resting_after: bool = Engine.has_meta(mix.get_script_constant_map()["RESTING_META"]) and (Engine.get_meta(mix.get_script_constant_map()["RESTING_META"]) as Dictionary).has(BUS_NAME)
	# An effect the project put on the bus itself is never taken off.
	var own: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
	AudioServer.add_bus_effect(index, own)
	script.call("_bus_hold", BUS_NAME, "muffle")
	script.call("_bus_let_go", BUS_NAME, "muffle")
	var kept: int = AudioServer.get_bus_effect_count(index)
	var kept_is_own: bool = AudioServer.get_bus_effect(index, 0) == own
	player.free()
	AudioServer.remove_bus(index)
	return SUPPORT.pins(TEST_NAME, [
		["the bus started with no effect", count_before, 0],
		["a card on a bus with no low-pass adds one at its end", [added, added_is_lowpass], [1, true]],
		["a second card holding the same effect adds none", two_holds, 1],
		["the first to let go leaves it, the other still needs it", after_one, 1],
		["the last to let go takes it off, and the bus has no effect again", after_both, 0],
		["where the bus rested is forgotten, as it was before the card", [resting_before, resting_after], [false, false]],
		["an effect the project put there itself stays", [kept, kept_is_own], [1, true]],
		["the card still takes the way back like any other", str(card.get("how", "")), "muffle"],
	])


## The boxes themselves, drawn by the card list: leaving a start alone stores nothing, typing one stores a number,
## and a layer is picked from the thirty-two.
static func _drawer_pins() -> bool:
	var schema: Dictionary = (load(SCHEMA) as GDScript).call("schema")
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": schema})
	var cards: Array = [{"verb": "light", "energy_to": 3.0, "colour_to": Color(1.0, 0.6, 0.2), "seconds": 0.08}, {"verb": "collision_layer_for", "layer": 3, "part": "mask", "on": false, "seconds": 0.5}]
	drawer.set_value(cards)
	drawer._unfolded[0] = true
	drawer._unfolded[1] = true
	drawer._rebuild()
	var edits: Array = []
	var buttons: Array = []
	var pickers: Array = []
	var choices: Array = []
	_collect(drawer._list, edits, buttons, pickers, choices)
	var from_box: LineEdit = null
	for edit: Variant in edits:
		if (edit as LineEdit).placeholder_text == "From where it is":
			from_box = edit as LineEdit
	var colour_start: Button = null
	for button: Variant in buttons:
		if (button as Button).text == "From where it is":
			colour_start = button as Button
	var layer_box: OptionButton = null
	for choice: Variant in choices:
		if (choice as OptionButton).item_count == 32:
			layer_box = choice as OptionButton
	var untouched: Dictionary = (drawer.get_value()[0] as Dictionary).duplicate()
	if from_box != null:
		from_box.text = "0.5"
		from_box.text_changed.emit("0.5")
	var typed: Dictionary = (drawer.get_value()[0] as Dictionary).duplicate()
	var seen: Array = [typed.get("energy_from")]
	var cleared_box: Dictionary = {}
	drawer._rebuild()
	edits.clear()
	buttons.clear()
	pickers.clear()
	choices.clear()
	_collect(drawer._list, edits, buttons, pickers, choices)
	for edit: Variant in edits:
		if (edit as LineEdit).placeholder_text == "From where it is":
			(edit as LineEdit).text = ""
			(edit as LineEdit).text_changed.emit("")
	cleared_box = (drawer.get_value()[0] as Dictionary).duplicate()
	var layer_before: int = int((drawer.get_value()[1] as Dictionary).get("layer", 0))
	if layer_box != null:
		layer_box.item_selected.emit(6)
	var layer_after: int = int((drawer.get_value()[1] as Dictionary).get("layer", 0))
	var rows: Array = [
		["the energy start is an empty box that says it begins where the light is", from_box != null, true],
		["the colour start is a button that says the same", colour_start != null, true],
		["a card nobody touched stores neither start", [untouched.has("energy_from"), untouched.has("colour_from")], [false, false]],
		["typing a number stores it as a number", seen, [0.5]],
		["clearing the box takes the key off again", cleared_box.has("energy_from"), false],
		["the layer is a list of thirty-two", layer_box != null, true],
		["it shows the card's own layer", [layer_box.get_selected_id() if layer_box != null else -1], [2]],
		["picking the seventh writes the number 7", [layer_before, layer_after], [3, 7]],
	]
	drawer.free()
	return SUPPORT.pins(TEST_NAME, rows)


static func _collect(node: Node, edits: Array, buttons: Array, pickers: Array, choices: Array) -> void:
	if node is LineEdit:
		edits.append(node)
	elif node is OptionButton:
		choices.append(node)
	elif node is ColorPickerButton:
		pickers.append(node)
	elif node is Button:
		buttons.append(node)
	for child: Node in node.get_children():
		_collect(child, edits, buttons, pickers, choices)


static func _kind(word: String) -> Dictionary:
	var schema: Dictionary = (load(SCHEMA) as GDScript).call("schema")
	for kind: Variant in schema.get("kinds", []):
		if str((kind as Dictionary).get("kind", "")) == word:
			return kind as Dictionary
	return {}


static func _field(kind: Dictionary, key: String) -> Dictionary:
	for field: Variant in kind.get("fields", []):
		if str((field as Dictionary).get("key", "")) == key:
			return field as Dictionary
	return {}


static func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)
