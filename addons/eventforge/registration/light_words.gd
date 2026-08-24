# EventForge - the LIGHT WORDS: five things a game touches, and the property each node really has.
#
# A light has five knobs a game reaches for - how bright, what colour, how far, on or off, shadows
# or not - and Godot spells every one of them differently depending on which light you picked.
# Brightness is `energy` on a 2D light and `light_energy` on a 3D one; reach is `texture_scale`,
# `omni_range` or `spot_range`; on/off is `enabled` in 2D and `visible` in 3D, because a Light3D has
# no `enabled` at all. A reader should not have to know that, and a row should never guess it.
#
# So the mapping is DERIVED. The table below says only what the WORDS are and which spellings each
# word can take, in preference order; which of those spellings a given light actually answers to is
# asked of ClassDB, class by class. Add a light class to CLASSES and its rows resolve themselves;
# nothing here has to be kept in step with the engine by hand.
#
# The one thing that is NOT derived is the `ace_id` stem beside each spelling, and it cannot be: an
# ace_id is a compatibility promise (a sheet saved today names it forever), so it is written down
# once, frozen, and never computed from a class name that the engine could rename under it.
@tool
class_name EventForgeLightWords
extends RefCounted

## The light classes this vocabulary speaks for, grouped by the dimension they live in. The
## dimensions are separate lists rather than one, because that is the one split the words really
## have: `shadow_enabled` is spelled the same in both, and a 2D row and a 3D row are still two rows
## (their hosts are Light2D and Light3D, and neither is the other's parent).
const CLASSES_2D: PackedStringArray = ["PointLight2D", "DirectionalLight2D"]
const CLASSES_3D: PackedStringArray = ["OmniLight3D", "SpotLight3D", "DirectionalLight3D"]

## The root of each dimension, and the most general host a row of that dimension can have.
const ROOT_2D: String = "Light2D"
const ROOT_3D: String = "Light3D"

## What kind of row a word makes. A VALUE word is set to a number and can be read back; a SWITCH is
## turned on or off and can be asked about; a COLOUR is a value with a colour field rather than an
## expression one. One builder per kind, in light_node_aces.gd.
const KIND_VALUE: String = "value"
const KIND_COLOUR: String = "colour"
const KIND_SWITCH: String = "switch"

## THE WORDS. One entry per thing a game touches, and for each one the spellings it can take in
## preference order, as `property -> ace_id stem`. Preference order is what makes `enabled` beat
## `visible` on a 2D light: both exist there, and `enabled` is the one that means "lit" rather than
## "drawn". The stems are frozen (see the header); the property a given class resolves to is not
## written down anywhere, it is asked of ClassDB.
const WORDS: Array[Dictionary] = [
	{
		"word": "brightness",
		"kind": KIND_VALUE,
		"name": "Set Brightness",
		"verb": "Set brightness to {value}",
		"reads": "brightness",
		"about": "How bright the light is, as a fraction: 0.5 is half, 2.0 is double.",
		"fades": true,
		"spellings": {"energy": "Brightness", "light_energy": "Brightness3D"}
	},
	{
		"word": "colour",
		"kind": KIND_COLOUR,
		"name": "Set Colour",
		"verb": "Set colour to {value}",
		"reads": "colour",
		"about": "The colour the light casts.",
		"spellings": {"color": "Colour", "light_color": "Colour3D"}
	},
	{
		"word": "reach",
		"kind": KIND_VALUE,
		"name": "Set Reach",
		"verb": "Set reach to {value}",
		"reads": "reach",
		"about": "How far the light gets: a scale for a 2D light's texture, metres for a 3D one.",
		"spellings": {"texture_scale": "Reach", "omni_range": "ReachOmni", "spot_range": "ReachSpot"}
	},
	{
		"word": "cone angle",
		"kind": KIND_VALUE,
		"name": "Set Cone Angle",
		"verb": "Set cone angle to {value}",
		"reads": "cone angle",
		"about": "How wide the spot's cone opens, in degrees from its centre line.",
		"spellings": {"spot_angle": "ConeAngle"}
	},
	{
		"word": "on",
		"kind": KIND_SWITCH,
		"on_name": "Turn On",
		"off_name": "Turn Off",
		"asks": "Is On",
		"on_verb": "Turn on",
		"off_verb": "Turn off",
		"ask_verb": "Is on",
		"about": "Whether the light is lit. A 2D light switches with `enabled`; a 3D light has no such property, so it switches with `visible`.",
		"spellings": {"enabled": "Lit", "visible": "Lit3D"}
	},
	{
		"word": "shadows",
		"kind": KIND_SWITCH,
		"on_name": "Turn Shadows On",
		"off_name": "Turn Shadows Off",
		"asks": "Is Casting Shadows",
		"on_verb": "Turn shadows on",
		"off_verb": "Turn shadows off",
		"ask_verb": "Is casting shadows",
		"about": "Whether the light casts shadows - the cheapest lighting switch there is.",
		"spellings": {"shadow_enabled": "Shadows"}
	}
]

## The suffix a 3D row's id stem takes when its property is spelled the SAME in both dimensions.
## `shadow_enabled` is the only such spelling today: both dimensions answer to it, and the two rows
## are still two rows, so one of them has to say which it is.
const DIMENSION_3D_SUFFIX: String = "3D"

## Per class, `property -> true`, filled the first time a class is asked about. ClassDB answers the
## same thing for the life of the process, and this is asked once per word per class on every
## descriptor build and once per line on every lift.
static var _properties: Dictionary = {}


## The property one class answers a word with, or "" when it has none of that word's spellings (a
## DirectionalLight2D has no reach, and no row offers it one). Derived: the word says which
## spellings are possible, ClassDB says which of them this class actually has.
static func property_of(class_text: String, word: String) -> String:
	var entry: Dictionary = word_entry(word)
	if entry.is_empty() or class_text.strip_edges().is_empty():
		return ""
	for property: String in (entry["spellings"] as Dictionary).keys():
		if has_property(class_text, property):
			return property
	return ""


## True when a class really carries a property, inherited ones included. The one question the whole
## word map is derived from.
static func has_property(class_text: String, property: String) -> bool:
	if not _properties.has(class_text):
		var names: Dictionary = {}
		for described: Dictionary in ClassDB.class_get_property_list(class_text, false):
			names[str(described.get("name", ""))] = true
		_properties[class_text] = names
	return bool((_properties[class_text] as Dictionary).get(property, false))


## The word entry by its word, or {}.
static func word_entry(word: String) -> Dictionary:
	for entry: Dictionary in WORDS:
		if str(entry["word"]) == word:
			return entry
	return {}


## Every light class this vocabulary speaks for, both dimensions, in reading order.
static func classes() -> PackedStringArray:
	var all: PackedStringArray = PackedStringArray(CLASSES_2D)
	all.append_array(CLASSES_3D)
	return all


## True when a class IS a light - the gate every scene fact and every lift guard asks. Answered
## through ClassDB rather than against the list above, so a light class the engine adds (or one a
## project subclasses) is still a light.
static func is_light_class(class_text: String) -> bool:
	var text: String = class_text.strip_edges()
	if text.is_empty() or not ClassDB.class_exists(text):
		return false
	return ClassDB.is_parent_class(text, ROOT_2D) or ClassDB.is_parent_class(text, ROOT_3D)


## The word a reader uses for a light class in one plain word: point, directional, omni or spot.
## Read off the class name itself rather than kept as a fifth table.
static func kind_word(class_text: String) -> String:
	var text: String = class_text.strip_edges()
	for kind: String in ["Point", "Directional", "Omni", "Spot"]:
		if text.begins_with(kind):
			return kind.to_lower()
	return "light"


## Every ROW one word makes, as `{property, id_stem, host, classes}` - one per distinct property the
## word resolves to within one dimension, hosted on the most general class of that dimension that
## resolves it. `texture_scale` is only PointLight2D's, so its host is PointLight2D; `energy` is
## every 2D light's, so its host is Light2D. Empty for a word no class in the dimension answers.
static func rows_of(word: String, dimension_classes: PackedStringArray, root: String) -> Array[Dictionary]:
	var entry: Dictionary = word_entry(word)
	var rows: Array[Dictionary] = []
	if entry.is_empty():
		return rows
	var by_property: Dictionary = {}
	for class_text: String in dimension_classes:
		var property: String = property_of(class_text, word)
		if property.is_empty():
			continue
		if not by_property.has(property):
			by_property[property] = PackedStringArray()
		var holders: PackedStringArray = by_property[property]
		holders.append(class_text)
		by_property[property] = holders
	for property: String in by_property.keys():
		var holders: PackedStringArray = by_property[property]
		rows.append({
			"property": property,
			"id_stem": _stem_of(entry, property, root),
			"host": _host_of(holders, root),
			"classes": holders
		})
	return rows


## The id stem the table froze for one spelling of one word, plus the 3D suffix when that spelling
## is the answer in BOTH dimensions and the two rows would otherwise share an id.
static func _stem_of(entry: Dictionary, property: String, root: String) -> String:
	var stem: String = str((entry["spellings"] as Dictionary).get(property, ""))
	if stem.is_empty() or root != ROOT_3D:
		return stem
	for class_text: String in CLASSES_2D:
		if property_of(class_text, str(entry["word"])) == property:
			return stem + DIMENSION_3D_SUFFIX
	return stem


## The most general host for a set of classes: the one that is a parent of all of them, walked up
## from the first and stopped at the dimension's own root so a 2D row can never be hosted on Node.
static func _host_of(holders: PackedStringArray, root: String) -> String:
	if holders.is_empty():
		return root
	var candidate: String = holders[0]
	while candidate != root and not candidate.is_empty():
		var covers_all: bool = true
		for holder: String in holders:
			covers_all = covers_all and ClassDB.is_parent_class(holder, candidate)
		if covers_all:
			return candidate
		candidate = ClassDB.get_parent_class(candidate)
	return root
