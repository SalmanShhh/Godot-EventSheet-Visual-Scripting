# Godot EventSheets - the Sound card, the family a card belongs to, and what a new card starts with.
#
# THE ONE THING THIS FILE IS ABOUT: a card added in the Inspector must do something the moment it
# is played, and must belong to the same family in the Inspector and in the game. A new Hitstop card
# used to freeze nothing (its amount is the time scale it freezes to, and it started at 1), a family
# switch that muted the waits shortened the whole beat, and there was no card for a sound.
#
# The pack is reached by path, the new file first: the code lives in `juice_player.gd` and the old
# `feedback_player.gd` only extends it, so a pin written against either file asks the same code.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SCHEMA_PATH: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const NEW_PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const OLD_PACK: String = "res://eventsheet_addons/juice/feedback_player.gd"

const TEST_NAME: String = "juice_sound_card"

## The two grounds a family tile sits on: the card line (a LineEdit's normal box) in Godot's own
## dark and light editor themes, read from the 4.7 default presets.
const DARK_CARD_LINE: Color = Color("#1c1c1c")
const LIGHT_CARD_LINE: Color = Color("#f5f5f5")


static func run() -> bool:
	var ok: bool = true
	ok = _storage_pins() and ok
	ok = _tile_pins() and ok
	ok = _sound_card_pins() and ok
	ok = _sound_runtime_pins() and ok
	ok = _seed_pins() and ok
	ok = _family_pins() and ok
	return ok


static func _pack() -> Script:
	return load(NEW_PACK if ResourceLoader.exists(NEW_PACK) else OLD_PACK) as Script


static func _schema() -> Dictionary:
	return load(SCHEMA_PATH).call("schema")


static func _kind(word: String) -> Dictionary:
	return EventSheetCardSchemas.kind_entry(_schema(), word)


static func _new_card(word: String) -> Dictionary:
	return EventSheetCardSchemas.new_card({"kind_key": "verb", "stripe_key": "category"}, _kind(word))


static func _constant(constant_name: String) -> Variant:
	var script: Script = _pack()
	while script != null:
		var map: Dictionary = script.get_script_constant_map()
		if map.has(constant_name):
			return map[constant_name]
		script = script.get_base_script()
	return null


## How the list is saved never moves: the type, the hint, and what an old card reads back as.
static func _storage_pins() -> bool:
	var player: Node = _pack().new()
	var hint: String = ""
	var typed: int = -1
	for property: Dictionary in player.get_property_list():
		if str(property.get("name")) == "steps":
			hint = str(property.get("hint_string"))
			typed = int(property.get("type"))
	player.free()
	return SUPPORT.pins(TEST_NAME, [
		["the list is still a typed array of dictionaries", typed, TYPE_ARRAY],
		["the list keeps its marker, word for word", hint, "eventsheet:cards:kind=verb,schema=feedback_steps,stripes=category"]
	])


## One family per word, the same in the Inspector and in the game, and a muted family never takes a
## wait out of the beat.
static func _family_pins() -> bool:
	var families: Variant = _constant("CATEGORY_OF")
	var table: Dictionary = families if families is Dictionary else {}
	var player: Node = _pack().new()
	player.call("mute_feedback_category", "pause", true)
	var pause_refused: String = str(player.call("_why_not", {"verb": "pause", "seconds": 0.2}, 1.0, 0))
	var hold_refused: String = str(player.call("_why_not", {"verb": "hold_until", "seconds": 0.0}, 1.0, 1))
	var hitstop_refused: String = str(player.call("_why_not", {"verb": "hitstop", "amount": 0.0, "seconds": 0.08}, 1.0, 2))
	player.free()
	return SUPPORT.pins(TEST_NAME, [
		["a muted pause family still waits on a Pause card", pause_refused, ""],
		["and on a Hold card", hold_refused, ""],
		["while the hitstop it holds is still muted", hitstop_refused, "muted"],
		["Tween Property is an Object-family card in the game", str(table.get("tween_property", "")), "transform"],
		["and in the Inspector", str(_kind("tween_property").get("category", "")), "transform"],
		["the card that plays another player is a Flow-family card in the Inspector too",
			str(_kind("play_player").get("category", "")), str(table.get("play_player", "?"))]

	])


## A card added in the Inspector is felt when it plays. The numbers were measured on a running tree:
## a Hitstop card at amount 1 and 0 s left the time scale at 1, and at amount 0 and 0 s the freeze
## began and ended inside one frame; amount 0 for 0.08 s held the time scale at 0 for 73 ms. A Slowmo
## card at amount 1 never slowed anything, and a Zoom card at amount 1 zoomed the camera OUT to its
## floor (zoom 0.2), because the amount is a percentage.
static func _seed_pins() -> bool:
	var hitstop: Dictionary = _new_card("hitstop")
	var slowmo: Dictionary = _new_card("slowmo")
	var zoom: Dictionary = _new_card("zoom")
	return SUPPORT.pins(TEST_NAME, [
		["a new Hitstop card freezes time completely", float(hitstop.get("amount", -1.0)), 0.0],
		["and for long enough to be felt", float(hitstop.get("seconds", 0.0)) >= 0.05, true],
		["a new Slowmo card slows time", float(slowmo.get("amount", 1.0)) < 1.0, true],
		["and holds it for a while", float(slowmo.get("seconds", 0.0)) > 0.0, true],
		["a new Zoom card zooms in a little, not out to the floor", float(zoom.get("amount", 0.0)) > 100.0, true],
		["a new card still holds exactly the keys a moment file's step holds",
			_sorted_keys(hitstop), EventSheetMomentFile.STEP_KEYS]
	])


static func _sorted_keys(card: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in card:
		keys.append(str(key))
	keys.sort()
	return keys


## The Sound card: its fields, its length, and what a play of it is made of.
static func _sound_runtime_pins() -> bool:
	var script: Script = _pack()
	var has_settings: bool = _has_static(script, "sound_settings")
	var has_length: bool = _has_static(script, "card_length")
	var low: Dictionary = {}
	var high: Dictionary = {}
	var still: Dictionary = {}
	var length: float = -1.0
	var card: Dictionary = {"verb": "sound", "stream": _beep_path(), "volume_db": -6.0, "volume_spread_db": 2.0,
		"pitch": 1.0, "pitch_spread": 0.2, "bus": "Master", "follows_strength": false}
	if has_settings:
		low = script.call("sound_settings", card, 1.0, 0.0, 0.0)
		high = script.call("sound_settings", card, 1.0, 1.0, 1.0)
		var following: Dictionary = card.duplicate()
		following["follows_strength"] = true
		still = script.call("sound_settings", following, 0.5, 0.5, 1.0)
	if has_length:
		var faster: Dictionary = card.duplicate()
		faster["pitch"] = 2.0
		faster["pitch_spread"] = 0.0
		length = snappedf(float(script.call("card_length", faster)), 0.001)
	return SUPPORT.pins(TEST_NAME, [
		["the Sound card belongs to the family the Mute row already offers", str(_constant_table("CATEGORY_OF").get("sound", "")), "audio"],
		["the pack publishes the one function the game and the editor both read", has_settings, true],
		["the lowest roll lands on the bottom of the pitch spread", snappedf(float(low.get("pitch_scale", 0.0)), 0.001), 0.8],
		["the highest roll lands on the top of it", snappedf(float(high.get("pitch_scale", 0.0)), 0.001), 1.2],
		["the volume spread goes both ways", [snappedf(float(low.get("volume_db", 0.0)), 0.001), snappedf(float(high.get("volume_db", 0.0)), 0.001)], [-8.0, -4.0]],
		["a sound that follows the strength is quieter at half strength", float(still.get("volume_db", 0.0)) < -6.0, true],
		["a half-second sound at double pitch lasts a quarter second", length, 0.25],
		["a moment file cannot hold a sound, so Save as file names it", bool(script.call("_is_own_word", "sound")), true]
	])


static func _has_static(script: Script, method: String) -> bool:
	for listed: Dictionary in script.get_script_method_list():
		if str(listed.get("name")) == method:
			return true
	return false


## A half second of silence written to a file the test owns, so the length is a real stream's.
static func _beep_path() -> String:
	var path: String = SUPPORT.own_path("juice_sound_card_beep.tres")
	if not ResourceLoader.exists(path):
		var wav: AudioStreamWAV = AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(22050)
		wav.data = bytes
		ResourceSaver.save(wav, path)
	return path


static func _constant_table(constant_name: String) -> Dictionary:
	var value: Variant = _constant(constant_name)
	return value if value is Dictionary else {}


## The Sound card in the Inspector: its fields in the order the card draws them, the words it reads in,
## and what it keeps. A picked file is kept as text, a choice keeps its word and shows its words, and
## a field that starts empty stores nothing until it is touched.
static func _sound_card_pins() -> bool:
	var entry: Dictionary = _kind("sound")
	var keys: PackedStringArray = PackedStringArray()
	var note_field: Dictionary = {}
	var heard_field: Dictionary = {}
	var delay_field: Dictionary = {}
	for field: Variant in EventSheetCardSchemas.fields_of(entry):
		var described: Dictionary = field as Dictionary
		var drawn: String = str(described.get("drawer", ""))
		if drawn != "note" and drawn != "custom":
			keys.append(str(described.get("key", "")))
		if str(described.get("key", "")) == "sound_missing":
			note_field = described
		if str(described.get("key", "")) == "heard_from":
			heard_field = described
		if str(described.get("key", "")) == "delay":
			delay_field = described
	var fresh: Dictionary = _new_card("sound")
	var with_sound: Dictionary = fresh.duplicate()
	var stored_uid: String = ResourceUID.id_to_text(ResourceLoader.get_resource_uid("res://eventsheet_addons/juice/icon.svg"))
	with_sound["stream"] = stored_uid
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"schema_dict": _schema(), "kind_key": "verb", "stripe_key": "category"})
	drawer.set_value([fresh])
	var heard_row: Control = drawer._build_field(0, fresh, heard_field)
	var choice: OptionButton = heard_row.find_children("*", "OptionButton", true, false)[0] as OptionButton
	var shown: String = choice.get_item_text(choice.selected)
	choice.select(1)
	choice.item_selected.emit(1)
	var delay_row: Control = drawer._build_field(0, fresh, delay_field)
	var delay_box: SpinBox = delay_row.find_children("*", "SpinBox", true, false)[0] as SpinBox
	var after_reading: Dictionary = drawer.get_value()[0] as Dictionary
	var kept: Dictionary = (drawer.get_value()[0] as Dictionary).duplicate()
	drawer.set_value([with_sound])
	drawer._unfolded[0] = true
	drawer._rebuild()
	var rebuilt: Dictionary = drawer.get_value()[0] as Dictionary
	var wav_path: String = SUPPORT.own_path("juice_sound_card_ref.tres")
	ResourceSaver.save(AudioStreamWAV.new(), wav_path)
	var inside: AudioStreamWAV = AudioStreamWAV.new()
	var result: bool = SUPPORT.pins(TEST_NAME, [
		["the Add box offers a Sound card", str(entry.get("label", "")), "Sound"],
		["it is a Sound-family card", str(entry.get("category", "")), "audio"],
		["its fields, in the order the card draws them", keys,
			PackedStringArray(["stream", "volume_db", "volume_spread_db", "pitch", "pitch_spread", "bus", "heard_from", "follows_strength", "delay"])],
		["a new Sound card holds its settings and no delay until one is typed",
			_sorted_keys(fresh), PackedStringArray(["bus", "follows_strength", "heard_from", "pitch", "pitch_spread", "stream", "verb", "volume_db", "volume_spread_db"])],
		["a choice shows its words and not the word the card keeps", shown, "This object"],
		["and writes the word the card keeps", str((drawer.get_value()[0] as Dictionary).get("heard_from", "")), "here"],
		["a delay box reads 0 off a card that holds none", delay_box.value, 0.0],
		["and reading it stored nothing", after_reading.has("delay"), false],
		["opening a card leaves a stored sound exactly as it was", str(rebuilt.get("stream", "")), stored_uid],
		["a card with no sound says so in a note", EventSheetCardSchemas.field_visible(note_field, fresh), true],
		["and a card with one says nothing", EventSheetCardSchemas.field_visible(note_field, with_sound), false],
		["a picked file is kept as its path when it has no uid", EventSheetCardSchemas.resource_reference(load(wav_path) as Resource), wav_path],
		["a resource that lives inside a scene cannot be kept as text", EventSheetCardSchemas.resource_reference(inside), ""],
		["and a cleared pick keeps nothing", EventSheetCardSchemas.resource_reference(null), ""]
	])
	kept.clear()
	heard_row.free()
	delay_row.free()
	drawer.free()
	return result


## Each family has a colour for a dark editor and one for a light editor, and each reads 3:1 on the
## card line it sits on. The tile belongs to the Juice Player's list only: a Drawing Prefab draws none.
## The Add box says Sound, Scene, Object, Device, Camera, Screen, Time and Flow, in that order, while
## the words a card is saved and muted by are the ones they always were.
static func _tile_pins() -> bool:
	var schema: Dictionary = _schema()
	var dark: Dictionary = schema.get("stripes") if schema.get("stripes") is Dictionary else {}
	var light: Dictionary = schema.get("stripes_light") if schema.get("stripes_light") is Dictionary else {}
	var weak: PackedStringArray = PackedStringArray()
	for family: Variant in dark:
		if EventSheetEditorThemeDeriver.contrast_ratio(Color(str(dark[family])), DARK_CARD_LINE) < 3.0:
			weak.append("dark " + str(family))
		if not light.has(family) or EventSheetEditorThemeDeriver.contrast_ratio(Color(str(light[family])), LIGHT_CARD_LINE) < 3.0:
			weak.append("light " + str(family))
	var headings: PackedStringArray = PackedStringArray()
	var contents: Dictionary = {}
	for group: Variant in EventSheetCardSchemas.kinds_by_category(schema):
		var heading: String = str((group as Dictionary).get("name", ""))
		headings.append(heading)
		var labels: PackedStringArray = PackedStringArray()
		for entry: Variant in (group as Dictionary).get("kinds", []):
			labels.append(str((entry as Dictionary).get("label", "")))
		contents[heading] = labels
	var prefab_schema: Dictionary = {"kinds": [{"kind": "a", "category": "x", "label": "A"}]}
	var on_light: Color = EventSheetCardSchemas.tile_color(schema, "scene", true)
	var on_dark: Color = EventSheetCardSchemas.tile_color(schema, "scene", false)
	return SUPPORT.pins(TEST_NAME, [
		["the juice list asks for a family tile", bool(schema.get("tiles", false)), true],
		["a list that does not ask draws none", EventSheetCardSchemas.tiles_wanted(prefab_schema), false],
		["every family reads 3:1 on its card line in both editor themes", weak, PackedStringArray()],
		["the Sound family is one of them", dark.has("audio") and light.has("audio"), true],
		["a light editor draws the light colour and a dark one the dark", [on_light.to_html(false), on_dark.to_html(false)], ["a88a2f", "f2c744"]],
		["the Add box headings, in order", headings, PackedStringArray(["Sound", "Scene", "Object", "Device", "Camera", "Screen", "Time", "Flow"])],
		["Loop and signal cards share the Flow heading", contents.get("Flow"),
			PackedStringArray(["Loop Start", "Loop Back", "Emit Signal", "Play Player", "Call Method"])],
		["Tween Property sits with the Object cards", (contents.get("Object") as PackedStringArray).has("Tween Property"), true],
		["a card is still saved and muted by the family word it always was", str(_kind("shake").get("category", "")), "camera"]
	])
