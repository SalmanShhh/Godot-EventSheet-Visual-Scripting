# EventForge - the SKY WORDS: five things a game touches on the sky Godot draws for it.
#
# Godot's procedural sky is a gradient with a sun in it, and the five words below are the ones a day
# that turns into an evening actually moves: the colour straight overhead, the colour at the horizon,
# the colour of the ground below it, how big the sun's disc is, and how bright the whole sky is. Every
# one of them is a property of a ProceduralSkyMaterial, which a scene reaches through
# `environment.sky.sky_material` - three objects deep, and none of them a node.
#
# So the mapping is DERIVED, the way the light, material and environment words are: the table says
# what the WORDS are and which spellings each can take, and which of those the material really
# answers to is asked of ClassDB. The `ace_id` stems are the one thing written down and frozen.
#
# THE OWN-THE-SKY COURTESY. A sky material is a FILE as often as not, and two scenes pointing at the
# same one point at ONE object: reddening the sunset in the desert reddens it in the forest too. So
# every write below duplicates the sky material onto this environment first when it came from a file,
# and only then writes. A copy taken once has no `resource_path`, so a row running every frame takes
# one copy and not sixty.
#
# AND THE ONE THING EVERY ROW REFUSES TO DO: guess. A scene whose backdrop is a flat colour has no
# sky at all, and a scene wearing a panorama sky or somebody's own sky shader has a sky these five
# properties are not on. Every row is written as an `is ProceduralSkyMaterial` guard, so on such a
# scene it quietly does nothing rather than erroring - and the Doctor says so in words, where words
# belong, with the door that fixes it (set the backdrop to sky).
@tool
class_name EventForgeSkyWords
extends RefCounted

## The node class every row here is hosted on - the one node in a scene that holds an Environment,
## which is the only way to the sky.
const HOST: String = "WorldEnvironment"

## The three members a sky word reaches through, and the path they spell together. Written as
## constants because the reading, the rows and the Doctor all have to agree on it exactly.
const ENVIRONMENT_MEMBER: String = "environment"
const SKY_MEMBER: String = "sky"
const SKY_MATERIAL_MEMBER: String = "sky_material"
const SKY_MATERIAL_PATH: String = "%s.%s.%s" % [ENVIRONMENT_MEMBER, SKY_MEMBER, SKY_MATERIAL_MEMBER]

## The classes the two kind-swaps install, and the class the words are RESOLVED against.
const PROCEDURAL_CLASS: String = "ProceduralSkyMaterial"
const PANORAMA_CLASS: String = "PanoramaSkyMaterial"
const SKY_CLASS: String = "Sky"

## What kind of row a word makes - the same two kinds the other tables use, so one set of builders
## reads all of them.
const KIND_VALUE: String = "value"
const KIND_COLOUR: String = "colour"

## THE GUARD every row opens with: there IS a sky, and what it is drawing with is the procedural one
## these five words live on. Anything else - no sky, a panorama, somebody's shader - falls straight
## through and the row does nothing.
const GUARD_LINE: String = "if %s.%s != null and %s is %s:" % [ENVIRONMENT_MEMBER, SKY_MEMBER,
	SKY_MATERIAL_PATH, PROCEDURAL_CLASS]

## THE OWN-IT LINES, indented one step because they live inside that guard. TWO resources are written
## on the way to the material, so two are owned: the Sky (whose `sky_material` slot the copy is parked
## in) and the sky material itself. Each is copied while it still carries a `resource_path`, which is
## every resource somebody else can also be holding - a `.tres` on disk, and the embedded
## sub-resource a scene keeps inside itself (`res://sky.tscn::ProceduralSkyMaterial_k9f2e`), which is
## worn by every instance of that scene. A copy taken once has no path at all, so a row running every
## frame takes one copy and not sixty. The Environment above them is owned by the caller, with the
## same lines every other environment row opens with.
const OWN_LINES: String = "\tif not %s.%s.resource_path.is_empty():\n\t\t%s.%s = %s.%s.duplicate()\n\tif not %s.resource_path.is_empty():\n\t\t%s = %s.duplicate()\n" % [
	ENVIRONMENT_MEMBER, SKY_MEMBER, ENVIRONMENT_MEMBER, SKY_MEMBER, ENVIRONMENT_MEMBER, SKY_MEMBER,
	SKY_MATERIAL_PATH, SKY_MATERIAL_PATH, SKY_MATERIAL_PATH]

## THE WORDS. One entry per thing a game touches, and for each one the spellings it can take in
## preference order, as `property -> ace_id stem`. The stems are frozen; which spelling the material
## resolves to is asked of ClassDB.
const WORDS: Array[Dictionary] = [
	{
		"word": "sky top",
		"kind": KIND_COLOUR,
		"name": "Set Sky Top",
		"verb": "Set sky top to {value}",
		"reads": "sky top",
		"label": "Sky top",
		"about": "The colour of the sky straight overhead. Deep blue at noon, indigo at dusk, black with a hint of blue at night.",
		"featured": true,
		"spellings": {"sky_top_color": "SkyTop"}
	},
	{
		"word": "sky horizon",
		"kind": KIND_COLOUR,
		"name": "Set Sky Horizon",
		"verb": "Set sky horizon to {value}",
		"reads": "sky horizon",
		"label": "Horizon",
		"about": "The colour the sky fades to where it meets the ground. The whole of a sunset is this one colour going orange while the top goes dark.",
		"featured": true,
		"spellings": {"sky_horizon_color": "SkyHorizon"}
	},
	{
		"word": "sky ground",
		"kind": KIND_COLOUR,
		"name": "Set Sky Ground",
		"verb": "Set sky ground to {value}",
		"reads": "sky ground",
		"label": "Ground",
		"about": "The colour drawn below the horizon, under everything the level itself puts there. Brown for earth, grey-green for a moor, near-black for a night scene.",
		"spellings": {"ground_bottom_color": "SkyGround"}
	},
	{
		"word": "sun size",
		"kind": KIND_VALUE,
		"name": "Set Sun Size",
		"verb": "Set sun size to {value}",
		"reads": "sun size",
		"label": "Sun size",
		"about": "How wide the sun's disc is drawn, in degrees. Our own sun is about half a degree; a fat, low, hazy sun is several. Needs a DirectionalLight3D in the scene for there to be a sun at all.",
		"spellings": {"sun_angle_max": "SunSize"}
	},
	{
		"word": "sky energy",
		"kind": KIND_VALUE,
		"name": "Set Sky Energy",
		"verb": "Set sky energy to {value}",
		"reads": "sky energy",
		"label": "Sky energy",
		"about": "How bright the whole sky is, as a fraction: 1 is untouched. It lights the scene as well as filling the picture, so turning it down darkens everything the sky was lighting.",
		"featured": true,
		"spellings": {"energy_multiplier": "SkyEnergy"}
	}
]

## Per class, `property -> true`, filled the first time a class is asked about.
static var _properties: Dictionary = {}


## The property the procedural sky material answers a word with, or "" when it has none of that
## word's spellings.
static func property_of(word: String) -> String:
	var entry: Dictionary = word_entry(word)
	if entry.is_empty():
		return ""
	for property: String in (entry["spellings"] as Dictionary).keys():
		if has_property(PROCEDURAL_CLASS, property):
			return property
	return ""


## True when a class really carries a property, inherited ones included.
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


## The frozen ace_id stem for one word, or "" when the material answers none of its spellings.
static func id_stem(word: String) -> String:
	var entry: Dictionary = word_entry(word)
	var property: String = property_of(word)
	if entry.is_empty() or property.is_empty():
		return ""
	return str((entry["spellings"] as Dictionary).get(property, ""))


## The value a row starts on - the ENGINE's own default for that property, asked through the factory
## so a dropped row opens where Godot opens it and the float32 widening never reaches a script.
static func default_of(word: String) -> String:
	var property: String = property_of(word)
	return "" if property.is_empty() else EventForgeACEFactory.default_literal(
		PROCEDURAL_CLASS, property)


## Every word this vocabulary really resolves, in table order.
static func words() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for entry: Dictionary in WORDS:
		if not property_of(str(entry["word"])).is_empty():
			found.append(str(entry["word"]))
	return found


## THE TABLE READ BACKWARDS: the word a procedural sky property IS, or "" for one no word here means -
## what turns a hand-written `environment.sky.sky_material.sky_top_color = ...` back into the sentence
## the picker would have made.
static func word_of_property(property: String) -> String:
	var wanted: String = property.strip_edges()
	if wanted.is_empty():
		return ""
	for word: String in words():
		if property_of(word) == wanted:
			return word
	return ""


## The sentence a row of one word reads as, with `{value}` still in it. "" for a property that is not
## one of the five.
static func verb_of_property(property: String) -> String:
	var word: String = word_of_property(property)
	return "" if word.is_empty() else str(word_entry(word).get("verb", ""))


## The whole expression a READ row is: the property when there really is a procedural sky, and the
## value Godot starts a new sky material on when there is not - so a scene with a flat backdrop, a
## panorama or somebody's own sky shader answers with a number rather than reaching through a null.
static func read_expression(word: String) -> String:
	var property: String = property_of(word)
	if property.is_empty():
		return ""
	return "(%s as %s).%s if %s != null and %s.%s != null and %s is %s else %s" % [
		SKY_MATERIAL_PATH, PROCEDURAL_CLASS, property, ENVIRONMENT_MEMBER, ENVIRONMENT_MEMBER,
		SKY_MEMBER, SKY_MATERIAL_PATH, PROCEDURAL_CLASS, default_of(word)]
