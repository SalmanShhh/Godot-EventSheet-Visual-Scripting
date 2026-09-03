# EventForge - the PARTICLE WORDS: seven things a game touches on an effect, and where each one lives.
#
# A particle effect is TWO objects, and that is the whole difficulty this table exists to hide. How
# many particles there are and how long each one lives belong to the NODE; how fast they set off, how
# wide they fan out, which way they fall, how big they are and what colour they are belong to a
# ParticleProcessMaterial hanging off it. A reader saying "make the sparks fall faster" should not
# have to know which of the two objects the word is on, and a row should never guess it.
#
# So the mapping is DERIVED, exactly the way the light, material, environment and sky words are. The
# table below says only what the WORDS are, which of the two objects each one lives on, and which
# spellings it can take in preference order; which of those spellings the class actually answers to is
# asked of ClassDB, and so is the value each row opens on.
#
# THE ONE THING THAT IS NOT DERIVED is the `ace_id` stem beside each spelling, and it cannot be: an
# ace_id is a compatibility promise (a sheet saved today names it forever), so it is written down
# once, frozen, and never computed from a property name the engine could rename under it.
#
# TWO WORDS ARE REALLY TWO NUMBERS. A particle's speed is a range Godot spells `initial_velocity_min`
# and `initial_velocity_max`, and its size is a range spelled `scale_min` and `scale_max` - and a row
# offering only one half of either would leave the other one wherever it happened to be, which is how
# an effect ends up with every particle at exactly one speed. So those two words carry a COMPANION:
# the second half is a field on the same row, walked by the same fade, and read back by its own
# expression.
#
# THE OWN-IT COURTESY, and why only half the words need it. A process material is a FILE, and two
# emitters pointing at the same `.tres` point at ONE object: turning the sparks red turns every
# spark in the level red. So every write to a MATERIAL word is preceded by the lines that give this
# emitter its own copy first, and then guarded by the question of whether this really is a process
# material at all - an emitter driven by somebody's particle SHADER is left completely alone, because
# gravity and spread live inside that shader and there is no property here to set. The two NODE words
# need none of that: `amount` and `lifetime` are the emitter's own and nobody else's.
#
# WHY AMOUNT DOES NOT FADE, when every other word here does. Writing `amount` makes Godot throw the
# whole particle buffer away and build a new one; walking it over half a second would do that thirty
# times, and the effect would stutter every one of them. So amount is set, read, and left alone - and
# the row says why rather than offering a fade that would quietly cost frames.
@tool
class_name EventForgeParticleWords
extends RefCounted

## The two emitter classes this vocabulary speaks for, one per dimension. Separate entries rather
## than one list, because a 2D row and a 3D row are still two rows: their hosts are GPUParticles2D
## and GPUParticles3D, and neither is the other's parent.
const HOSTS: Array[Dictionary] = [
	{"host": "GPUParticles2D", "suffix": "", "which": "2D"},
	{"host": "GPUParticles3D", "suffix": "3D", "which": "3D"}
]

## The member the effect's own settings hang in, and the class they have to be for a row to write
## through them.
const MATERIAL_MEMBER: String = "process_material"
const MATERIAL_CLASS: String = "ParticleProcessMaterial"

## Which of the two objects a word lives on. A MATERIAL word is written through the emitter's process
## material, with the own-it courtesy and the guard in front of it; a NODE word is the emitter's own
## property and needs neither.
const ON_MATERIAL: String = "material"
const ON_NODE: String = "node"

## What kind of row a word makes. A VALUE word is set to a number (or a vector) and can be read back;
## a COLOUR is a value with a colour field rather than an expression one. One builder per kind, in
## particle_aces.gd.
const KIND_VALUE: String = "value"
const KIND_COLOUR: String = "colour"

## THE OWN-IT LINES every material write is preceded by, spelled once. An emitter driving itself with
## nothing is given a plain process material, because there is nothing to copy; one driving itself
## with a material FILE is given a copy of it, so a `.tres` worn by every torch in the level never
## changes under the other torches. A material the scene already keeps inside itself has no
## `resource_path` and is nobody else's, so it is left exactly as it is - and a copy taken once has no
## path either, which is what makes a row that runs every frame take one copy and not sixty.
const OWN_LINES: String = "if %s == null:\n\t%s = %s.new()\nelif %s is %s and not %s.resource_path.is_empty():\n\t%s = %s.duplicate()\n" % [
	MATERIAL_MEMBER, MATERIAL_MEMBER, MATERIAL_CLASS, MATERIAL_MEMBER, MATERIAL_CLASS,
	MATERIAL_MEMBER, MATERIAL_MEMBER, MATERIAL_MEMBER]

## The guard every material write lives inside: an emitter driven by somebody's particle SHADER has
## none of these properties, so the row sets nothing at all rather than failing.
const GUARD_LINE: String = "if %s is %s:" % [MATERIAL_MEMBER, MATERIAL_CLASS]

## THE WORDS. One entry per thing a game touches, and for each one the spellings it can take in
## preference order, as `property -> ace_id stem`. The stems are frozen (see the header); which
## spelling the class resolves to is not written down anywhere, it is asked of ClassDB.
##
## `companion` is the second half of a word that is really a RANGE - a speed and a size each have a
## least and a most - written on the same row rather than left as a second thing to remember, walked
## by the same fade, and read back by an expression of its own.
const WORDS: Array[Dictionary] = [
	{
		"word": "gravity",
		"kind": KIND_VALUE,
		"on": ON_MATERIAL,
		"name": "Set Particle Gravity",
		"read_name": "Particle Gravity",
		"verb": "Set gravity to {value}",
		"reads": "particle gravity",
		"label": "Gravity",
		"about": "Which way the particles fall and how hard, as a direction with a length. Point it up for smoke and bubbles, leave it at nothing for sparks in space, turn it sideways for rain in a gale.",
		"fades": true,
		"featured": true,
		"spellings": {"gravity": "Gravity"}
	},
	{
		"word": "spread",
		"kind": KIND_VALUE,
		"on": ON_MATERIAL,
		"name": "Set Particle Spread",
		"read_name": "Particle Spread",
		"verb": "Set spread to {value}",
		"reads": "particle spread",
		"label": "Spread",
		"about": "How wide the particles fan out from the way the emitter is pointing, in degrees. 0 is a straight jet, 45 is a cone, 180 is every direction at once.",
		"fades": true,
		"spellings": {"spread": "Spread"}
	},
	{
		"word": "speed",
		"kind": KIND_VALUE,
		"on": ON_MATERIAL,
		"name": "Set Particle Speed",
		"read_name": "Slowest Particle Speed",
		"verb": "Set speed to {value} - {most}",
		"reads": "slowest particle speed",
		"label": "Slowest",
		"about": "How fast a new particle sets off. Both ends of the range are on this one row, because a range with only one end set is how every particle in an effect ends up at exactly one speed.",
		"fades": true,
		"featured": true,
		"companion": {
			"property": "initial_velocity_max",
			"param": "most",
			"label": "Fastest",
			"read_name": "Fastest Particle Speed",
			"reads": "fastest particle speed",
			"stem": "SpeedMost",
			"about": "The fastest a new particle sets off. Set it the same as the slowest for an effect where everything moves together."
		},
		"spellings": {"initial_velocity_min": "Speed"}
	},
	{
		"word": "size",
		"kind": KIND_VALUE,
		"on": ON_MATERIAL,
		"name": "Set Particle Size",
		"read_name": "Smallest Particle Size",
		"verb": "Set size to {value} - {most}",
		"reads": "smallest particle size",
		"label": "Smallest",
		"about": "How big a new particle is, as a multiple of the picture it is drawn with. Both ends of the range are on this one row, for the same reason speed's are.",
		"fades": true,
		"companion": {
			"property": "scale_max",
			"param": "most",
			"label": "Biggest",
			"read_name": "Biggest Particle Size",
			"reads": "biggest particle size",
			"stem": "SizeMost",
			"about": "How big the biggest new particle is. Set it the same as the smallest for an effect where everything is one size."
		},
		"spellings": {"scale_min": "Size"}
	},
	{
		"word": "colour",
		"kind": KIND_COLOUR,
		"on": ON_MATERIAL,
		"name": "Set Particle Colour",
		"read_name": "Particle Colour",
		"verb": "Set colour to {value}",
		"reads": "particle colour",
		"label": "Colour",
		"about": "The colour every particle is tinted. Multiplied with whatever picture the emitter draws with, so white leaves the picture as it is.",
		"fades": true,
		"featured": true,
		"spellings": {"color": "Colour"}
	},
	{
		"word": "lifetime",
		"kind": KIND_VALUE,
		"on": ON_NODE,
		"name": "Set Particle Lifetime",
		"read_name": "Particle Lifetime",
		"verb": "Set lifetime to {value}",
		"reads": "particle lifetime",
		"label": "Seconds",
		"about": "How many seconds one particle lasts before it goes out. Longer lifetimes with the same amount means a thinner, longer trail; shorter ones mean a denser puff.",
		"fades": true,
		"spellings": {"lifetime": "Lifetime"}
	},
	{
		"word": "amount",
		"kind": KIND_VALUE,
		"on": ON_NODE,
		"name": "Set Particle Amount",
		"read_name": "Particle Amount",
		"verb": "Set amount to {value}",
		"reads": "particle amount",
		"label": "Amount",
		"about": "How many particles the emitter keeps in the air at once. Writing it makes the engine throw the whole particle buffer away and build a new one, so it is a row to use at a moment rather than every frame - which is also why there is no fade for it.",
		"spellings": {"amount": "Amount"}
	}
]

## Per class, `property -> true`, filled the first time a class is asked about. ClassDB answers the
## same thing for the life of the process, and this is asked once per word on every descriptor build
## and once per line on every reading.
static var _properties: Dictionary = {}


## The class a word's property lives on: the process material for a material word, and the emitter
## itself for a node word. The one branch the whole two-object split reduces to.
static func class_of(word: String, host: Dictionary) -> String:
	var entry: Dictionary = word_entry(word)
	if entry.is_empty():
		return ""
	return MATERIAL_CLASS if str(entry["on"]) == ON_MATERIAL else str(host["host"])


## The property a word resolves to, or "" when the class it lives on has none of that word's
## spellings. Derived: the word says which spellings are possible, ClassDB says which of them the
## class actually has.
static func property_of(word: String, host: Dictionary) -> String:
	var entry: Dictionary = word_entry(word)
	if entry.is_empty():
		return ""
	var class_text: String = class_of(word, host)
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


## The frozen ace_id stem for one word on one host: the table's own stem, plus the dimension's suffix
## so the 2D row and the 3D row can never share an id.
static func id_stem(word: String, host: Dictionary) -> String:
	var entry: Dictionary = word_entry(word)
	var property: String = property_of(word, host)
	if entry.is_empty() or property.is_empty():
		return ""
	return "%s%s" % [str((entry["spellings"] as Dictionary).get(property, "")),
		str(host.get("suffix", ""))]


## True when a word is written through the emitter's process material rather than through the emitter
## itself - the one question that decides whether a row needs the own-it lines and the guard.
static func is_material_word(word: String) -> bool:
	var entry: Dictionary = word_entry(word)
	return not entry.is_empty() and str(entry["on"]) == ON_MATERIAL


## The value a row starts on: the ENGINE's default for the property on the class it lives on, so a
## dropped row opens where Godot opens it and a reader never meets a number nobody chose.
static func default_of(word: String, host: Dictionary) -> String:
	var property: String = property_of(word, host)
	return "" if property.is_empty() else default_literal(class_of(word, host), property)


## One property's engine default, as the text a row starts on. The factory answers colours and floats
## (rounding the float32 the answer arrives widened from); a VECTOR has to be spelled here, because
## `str(Vector3(0, -9.8, 0))` is `(0, -9.8, 0)` and that is not a thing anybody can type.
static func default_literal(class_text: String, property: String) -> String:
	var value: Variant = ClassDB.class_get_property_default_value(class_text, property)
	if value is Vector3:
		var spatial: Vector3 = value
		return "Vector3(%s, %s, %s)" % [EventForgeACEFactory.float_literal(spatial.x),
			EventForgeACEFactory.float_literal(spatial.y),
			EventForgeACEFactory.float_literal(spatial.z)]
	if value is Vector2:
		var flat: Vector2 = value
		return "Vector2(%s, %s)" % [EventForgeACEFactory.float_literal(flat.x),
			EventForgeACEFactory.float_literal(flat.y)]
	return EventForgeACEFactory.default_literal(class_text, property)


## Every word this vocabulary really resolves on one host, in table order - the one list the rows, the
## reading and the tests all walk, so none of them can drift from the others.
static func words(host: Dictionary) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for entry: Dictionary in WORDS:
		if not property_of(str(entry["word"]), host).is_empty():
			found.append(str(entry["word"]))
	return found


## THE TABLE READ BACKWARDS: the word a property IS, or "" for a property no word here means. What
## turns a hand-written `process_material.spread = 20.0` back into the sentence the picker would have
## made - the same job the light words do for `energy`, and the reason every one of these tables says
## what it means rather than only how to write it.
##
## `on` narrows the question to one of the two objects, because `amount` on an emitter and `amount`
## somewhere inside a material would otherwise be the same question with two answers.
static func word_of_property(property: String, on: String) -> String:
	var wanted: String = property.strip_edges()
	if wanted.is_empty():
		return ""
	for entry: Dictionary in WORDS:
		if str(entry["on"]) != on:
			continue
		if (entry["spellings"] as Dictionary).has(wanted):
			return str(entry["word"])
	return ""


## The sentence a row of one word reads as, with `{value}` still in it, or "" for a property that is
## not one. A word that is really a range reads as its FIRST half alone here, because a hand-written
## line writes one property and the row's own two-ended sentence would be claiming a line that is not
## there.
static func verb_of_property(property: String, on: String) -> String:
	var word: String = word_of_property(property, on)
	if word.is_empty():
		return ""
	var entry: Dictionary = word_entry(word)
	return "Set %s to {value}" % str(entry["reads"]) if entry.has("companion") \
		else str(entry["verb"])


## The sentence a COMPANION property reads as, or "" for a property that is not one - the second half
## of a range, said in its own words rather than left as the property name.
static func companion_verb_of_property(property: String) -> String:
	var wanted: String = property.strip_edges()
	for entry: Dictionary in WORDS:
		if not entry.has("companion"):
			continue
		var companion: Dictionary = entry["companion"]
		if str(companion["property"]) == wanted:
			return "Set %s to {value}" % str(companion["reads"])
	return ""


## True when a class is one these rows speak for - a GPU emitter in either dimension, or a project's
## own subclass of one. Asked through ClassDB rather than against a list, so a subclass resolves too.
static func is_emitter_class(class_text: String) -> bool:
	var text: String = class_text.strip_edges()
	if text.is_empty() or not ClassDB.class_exists(text):
		return false
	for host: Dictionary in HOSTS:
		if ClassDB.is_parent_class(text, str(host["host"])):
			return true
	return false
