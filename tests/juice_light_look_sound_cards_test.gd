# Godot EventSheets - the Light card, the Scene Look card and the Bus Effect card.
#
# THE ONE THING THIS FILE IS ABOUT: each card moves a value Godot really has, reads the right name
# for the class in front of it (a 2D light's `energy`, a 3D light's `light_energy`), works on the
# scene's own copy of the look so a shared file is never changed, and, for sound, holds an effect of a
# bus and gives it back. The look card's choices come from the same word tables the shipped environment
# and lens rows are built from, so the two can never offer different things, and the switch each value
# needs (the glow's tick, the colour adjustments' tick) is the one those tables name.
#
# Measured outside the suite on a running tree: a light walked to 3 and back lands on its rest value
# exactly, two loads of one Environment file are ONE object (so writing it changes every scene that
# uses it), the copy swapped in and out leaves the file's bytes alone, and a bus effect switched on
# for a time and off again leaves every other effect on the bus where it was.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_light_look_sound_cards"

const PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const SCHEMA: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const ENVIRONMENT_WORDS: String = "res://addons/eventforge/registration/environment_words.gd"
const CAMERA_WORDS: String = "res://addons/eventforge/registration/camera_attribute_words.gd"

## Each light class and the three names a card reads on it: how bright, what colour, on or off.
const LIGHTS: Array = [
	["PointLight2D", "energy", "color", "enabled"],
	["DirectionalLight2D", "energy", "color", "enabled"],
	["OmniLight3D", "light_energy", "light_color", "visible"],
	["SpotLight3D", "light_energy", "light_color", "visible"],
	["DirectionalLight3D", "light_energy", "light_color", "visible"],
]


static func run() -> bool:
	var ok: bool = true
	ok = _godot_pins() and ok
	ok = _light_pins() and ok
	ok = _look_pins() and ok
	ok = _bus_pins() and ok
	return ok


## What Godot 4.7 has and has not.
static func _godot_pins() -> bool:
	var settings: PackedStringArray = PackedStringArray()
	for entry: Dictionary in ProjectSettings.get_property_list():
		var named: String = str(entry.get("name", ""))
		if named.contains("glow") and named.contains("2d"):
			settings.append(named)
	return SUPPORT.pins(TEST_NAME, [
		["no 2D light has a range", ClassDB.class_has_method("PointLight2D", "set_range"), false],
		["a 3D light has no enabled tick", ClassDB.class_has_method("Light3D", "set_enabled"), false],
		["Godot has no white balance on the Environment", ClassDB.class_has_method("Environment", "set_white_balance"), false],
		["and no post-processing volume node", ClassDB.class_exists("PostProcessVolume"), false],
		["no project setting turns 2D glow on", ",".join(settings), ""],
		["2D glow comes from a WorldEnvironment in Canvas mode", Environment.BG_CANVAS, 3],
		["colour adjustments start switched off", Environment.new().adjustment_enabled, false],
		["the audio server can switch one effect of a bus", ClassDB.class_has_method("AudioServer", "set_bus_effect_enabled"), true],
	])


## One card for every light, reading the right names for the class in front of it.
static func _light_pins() -> bool:
	var kind: Dictionary = _kind("light")
	var script: GDScript = load(PACK)
	var start: Dictionary = kind.get("defaults", {})
	var plain: Node = Node.new()
	var rows: Array = [
		["the Light card is in the Add box", str(kind.get("label", "")), "Light"],
		["it is a Scene card", str(kind.get("category", "")), "scene"],
		["a new Light card flares to 3", start.get("energy_to"), 3.0],
		["towards orange", start.get("colour_to"), Color(1.0, 0.6, 0.2)],
		["over 0.08 s", start.get("seconds"), 0.08],
		["and goes back by itself, over 0.2 s", [start.get("back"), start.get("back_seconds")], [true, 0.2]],
		["it accepts the two light families", ",".join(PackedStringArray(kind.get("accepts", []))), "Light2D,Light3D"],
		["the pack answers which names a light uses", _has(script, "light_properties"), true],
		["a node that is no light has none", (script.call("light_properties", plain) as Dictionary).is_empty(), true],
		["it takes its back time on top of the time it flares", script.call("card_length", {"verb": "light", "seconds": 0.08, "back": true, "back_seconds": 0.2}), 0.28],
		["and no more when it does not go back", script.call("card_length", {"verb": "light", "seconds": 0.08, "back": false, "back_seconds": 0.2}), 0.08],
	]
	plain.free()
	for light: Array in LIGHTS:
		var node: Node = ClassDB.instantiate(str(light[0])) as Node
		var names: Dictionary = script.call("light_properties", node)
		rows.append(["%s: brightness is %s" % [light[0], light[1]], str(names.get("energy", "")), light[1]])
		rows.append(["%s: colour is %s" % [light[0], light[2]], str(names.get("colour", "")), light[2]])
		rows.append(["%s: on and off is %s" % [light[0], light[3]], str(names.get("on", "")), light[3]])
		for property: String in [str(light[1]), str(light[2]), str(light[3])]:
			rows.append(["%s really has %s" % [light[0], property], property in node, true])
		node.free()
	return SUPPORT.pins(TEST_NAME, rows)


## One look card; its choices are the glow and the values the shipped rows can fade, by their Godot names.
static func _look_pins() -> bool:
	var kind: Dictionary = _kind("scene_look")
	var offered: PackedStringArray = PackedStringArray()
	var choice: String = str(_field(kind, "property").get("drawer", ""))
	if choice.begins_with("options:"):
		for pair: String in choice.trim_prefix("options:").split(","):
			offered.append(pair.get_slice("=", 0))
	var fading: PackedStringArray = PackedStringArray(["glow_intensity"])
	for path: String in [ENVIRONMENT_WORDS, CAMERA_WORDS]:
		for word: Variant in (load(path) as GDScript).get_script_constant_map().get("WORDS", []):
			var entry: Dictionary = word as Dictionary
			if bool(entry.get("fades", false)) and str(entry.get("kind", "")) == "value":
				for property: Variant in (entry.get("spellings", {}) as Dictionary).keys():
					fading.append(str(property))
	var environment: Environment = Environment.new()
	var lens: CameraAttributesPractical = CameraAttributesPractical.new()
	var missing: PackedStringArray = PackedStringArray()
	for property: String in offered:
		if not (property in environment) and not (property in lens):
			missing.append(property)
	# The switch each value needs is the one the word tables name, so the pack's small list can never drift from them.
	var script: GDScript = load(PACK)
	var disagree: PackedStringArray = PackedStringArray()
	for path: String in [ENVIRONMENT_WORDS, CAMERA_WORDS]:
		for word: Variant in (load(path) as GDScript).get_script_constant_map().get("WORDS", []):
			var entry: Dictionary = word as Dictionary
			if not entry.has("turns_on"):
				continue
			for property: Variant in (entry.get("spellings", {}) as Dictionary).keys():
				if str(script.call("look_switch_of", str(property))) != str(entry["turns_on"]):
					disagree.append("%s needs %s" % [property, entry["turns_on"]])
	var start: Dictionary = kind.get("defaults", {})
	return SUPPORT.pins(TEST_NAME, [
		["one Scene Look card, not four", str(kind.get("label", "")), "Scene Look"],
		["it is a Screen card", str(kind.get("category", "")), "screen"],
		["it offers the glow and every value of the environment and the lens the shipped rows can fade", ",".join(offered), ",".join(fading)],
		["every choice is a real Environment or camera attributes property", ",".join(missing), ""],
		["a new card turns the glow up", str(start.get("property", "")), "glow_intensity"],
		["to 2, over 0.1 s, and back over 0.3 s", [start.get("to"), start.get("seconds"), start.get("back_seconds")], [2.0, 0.1, 0.3]],
		["its help names the WorldEnvironment in Canvas mode for 2D", str(kind.get("help", "")).contains("Canvas"), true],
		["and never a project setting that does not exist", str(kind.get("help", "")).contains("project setting"), false],
		["it takes its back time on top of its walk", script.call("card_length", {"verb": "scene_look", "seconds": 0.1, "back_seconds": 0.3}), 0.4],
		["the switch of a glow value is the glow tick", script.call("look_switch_of", "glow_bloom"), "glow_enabled"],
		["and a volumetric fog value is not mistaken for the plain fog", script.call("look_switch_of", "volumetric_fog_density"), "volumetric_fog_enabled"],
		["exposure needs no switch", script.call("look_switch_of", "tonemap_exposure"), ""],
		["the pack's switches are the ones the word tables name", ",".join(disagree), ""],
		["it is never previewed in the editor (it would write the scene's look)", str(script.call("editor_kind", "scene_look")).begins_with("skipped:"), true],
	])


## The bus card reuses the shipped sweeps and the effect switch; no second mechanism.
static func _bus_pins() -> bool:
	var kind: Dictionary = _kind("bus_effect")
	var how: String = str(_field(kind, "how").get("drawer", ""))
	var start: Dictionary = kind.get("defaults", {})
	var script: GDScript = load(PACK)
	return SUPPORT.pins(TEST_NAME, [
		["the Bus Effect card is in the Add box", str(kind.get("label", "")), "Bus Effect For A Time"],
		["it is a Sound card", str(kind.get("category", "")), "audio"],
		["its four ways are the shipped ones", how, "options:muffle=Muffle,dive=Dive,wash=Wash,switch=Switch an effect on"],
		["a new card muffles the Master bus", [start.get("bus"), start.get("how")], ["Master", "muffle"]],
		["down to 400 Hz, for half a second, and back over 0.2 s", [start.get("to"), start.get("seconds"), start.get("back_seconds")], [400.0, 0.5, 0.2]],
		["a muffle is held between 20 and 20500 Hz", [script.call("bus_value_for", "muffle", 5.0), script.call("bus_value_for", "muffle", 90000.0)], [20.0, 20500.0]],
		["a dive is held between -80 and 24 dB, so a number meant for a muffle cannot turn a bus up by 400", [script.call("bus_value_for", "dive", 400.0), script.call("bus_value_for", "dive", -200.0)], [24.0, -80.0]],
		["a wash is a share from 0 to 1", [script.call("bus_value_for", "wash", 3.0), script.call("bus_value_for", "wash", -1.0)], [1.0, 0.0]],
		["it takes its back time on top of the time it holds", script.call("card_length", {"verb": "bus_effect", "seconds": 0.5, "back_seconds": 0.2}), 0.7],
		["it is never previewed in the editor (the editor's buses are the project's)", str(script.call("editor_kind", "bus_effect")).begins_with("skipped:"), true],
	])


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


## Whether a script declares a function (a GDScript resource's own has_method asks about the resource).
static func _has(script: GDScript, method: String) -> bool:
	for info: Dictionary in script.get_script_method_list():
		if str(info.get("name", "")) == method:
			return true
	return false
