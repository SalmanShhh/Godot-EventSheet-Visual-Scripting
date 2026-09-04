# EventForge - the CAMERA ATTRIBUTE WORDS: what a lens does, and the property each one really is.
#
# A camera has a second resource hanging off it that decides two things no other property does: how
# much light it lets in, and how far away the picture stops being sharp. Godot keeps both on a
# CameraAttributes resource, and hangs that resource off TWO different nodes with two different
# spellings - `Camera3D.attributes` for one camera, `WorldEnvironment.camera_attributes` for every
# camera that has none of its own. A reader should not have to know which of the two words their
# scene uses, and a row should never guess it.
#
# So the mapping is DERIVED, exactly the way the light, material, environment and sky words are. The
# table below says only what the WORDS are and which spellings each word can take, in preference
# order; which of those spellings the attributes class actually answers to is asked of ClassDB, and
# so is the value each row opens on. The two HOSTS are a list rather than a branch, so a word is
# written once and lands on both nodes.
#
# THE ONE THING THAT IS NOT DERIVED is the `ace_id` stem beside each spelling, and it cannot be: an
# ace_id is a compatibility promise (a sheet saved today names it forever), so it is written down
# once, frozen, and never computed from a property name the engine could rename under it.
#
# THE OWN-IT COURTESY, and the one class it always reaches for. A CameraAttributes is a FILE, and two
# cameras pointing at the same `.tres` are pointing at ONE object: dimming the lens on the cutscene
# camera dims it on the gameplay camera as well. So every write below is preceded by the lines that
# give this node its own copy first - a plain CameraAttributesPractical when the slot is holding
# nothing, and a duplicate of whatever it is holding when that came from a file.
#
# PRACTICAL, NEVER PHYSICAL, and that is a decision rather than an oversight. Godot ships two
# attribute resources: the Practical one, whose blur is written in metres and whose exposure is a
# plain multiplier, and the Physical one, whose blur comes out of a focal length and an f-stop and
# whose exposure comes out of an aperture and a shutter speed. A row that made a Physical one would
# be handing a reader four photography numbers to answer a question they asked in one word. So a slot
# holding nothing is given a Practical - and a slot a person deliberately filled with a Physical is
# LEFT ALONE: the duplicate keeps whatever class it was, the words that only a Practical has are
# written inside a guard that asks, and the ordinary property row is still there for anyone who knows
# what f/16 means.
#
# WHAT ONLY WORKS ON FORWARD+, said out loud. Auto exposure - the lens opening up when the player
# walks into a cave and closing again outside - is a Forward+ feature: on Mobile and on Compatibility
# the flag is set, the renderer ignores it, and nothing errors. The rows of that word say so in their
# own words, and the Doctor's ship-it section says it once more for a project whose rendering method
# is not Forward+.
@tool
class_name EventForgeCameraAttributeWords
extends RefCounted

## The two nodes that can carry a CameraAttributes, each with the member it carries it in and the
## suffix its rows' frozen ids take. A list rather than a branch: a word is written once and both
## hosts resolve it. The Camera3D entry is first and takes the bare stem, because it is the node a
## reader points at when they say "the camera".
const HOSTS: Array[Dictionary] = [
	{"host": "Camera3D", "member": "attributes", "suffix": "", "which": "this camera"},
	{"host": "WorldEnvironment", "member": "camera_attributes", "suffix": "World",
		"which": "every camera that has none of its own"}
]

## The class the words are RESOLVED against and the DEFAULTS are asked of - the concrete attributes
## Godot hands a camera that has none, and the only one that can be asked for a starting value.
const ATTRIBUTES_CLASS: String = "CameraAttributesPractical"

## The class a slot holding nothing at all is given, so a row on a bare camera writes a lens rather
## than reaching through a null. The same class, named separately because the two are two different
## decisions that happen to agree.
const FALLBACK_CLASS: String = "CameraAttributesPractical"

## The class every Practical-only line is guarded by, so a person who deliberately fitted a Physical
## lens keeps it and the rows that cannot speak to it quietly say nothing.
const PRACTICAL_CLASS: String = "CameraAttributesPractical"

## What kind of row a word makes. A VALUE word is set to a number and can be read back; a SWITCH is
## turned on or off and can be asked about, and carries whatever companion properties are the same
## decision. One builder per kind, in focus_and_exposure_aces.gd.
const KIND_VALUE: String = "value"
const KIND_SWITCH: String = "switch"

## The depth-of-field properties the two focus rows write. Not words of their own - "focus on that
## crate" is one sentence, and these are the three numbers it becomes - so they are named here where
## the rows and the reading can both reach them rather than spelled twice.
const FOCUS_ENABLED: String = "dof_blur_far_enabled"
const FOCUS_DISTANCE: String = "dof_blur_far_distance"
const FOCUS_TRANSITION: String = "dof_blur_far_transition"
const FOCUS_AMOUNT: String = "dof_blur_amount"

## THE WORDS. One entry per thing a game touches, and for each one the spellings it can take in
## preference order, as `property -> ace_id stem`. The stems are frozen (see the header); which
## spelling the attributes class resolves to is not written down anywhere, it is asked of ClassDB.
##
## `companions` are the properties that are the SAME decision as the word, written on the same row
## rather than left as three more things to remember - how fast the lens adjusts, and the least and
## most light it will adjust between. A companion marked `practical` is one only the Practical
## resource has, so its write goes inside the guard rather than beside it.
##
## `reads_on` and `reads_off` are what a HAND-WRITTEN `attributes.auto_exposure_enabled = true` reads
## as. They are written down rather than built out of the word because they are user-facing sentences
## a catalog has to be able to hold, and they keep the shape every other switch in the vocabulary
## reads in.
const WORDS: Array[Dictionary] = [
	{
		"word": "camera exposure",
		"kind": KIND_VALUE,
		"name": "Set Camera Exposure",
		"read_name": "Camera Exposure",
		"verb": "Set camera exposure to {value}",
		"reads": "camera exposure",
		"label": "Exposure",
		"about": "How much light the lens lets in: 1 is untouched, 2 is twice as bright, 0.5 is half. Different from the world's exposure, which is applied to the finished picture - this one belongs to the camera, so two cameras in one scene can see the same room differently.",
		"fades": true,
		"featured": true,
		"spellings": {"exposure_multiplier": "Exposure"}
	},
	{
		"word": "auto exposure",
		"kind": KIND_SWITCH,
		"on_name": "Turn Auto Exposure On",
		"off_name": "Turn Auto Exposure Off",
		"asks": "Is Auto Exposure On",
		"on_verb": "Turn auto exposure on, {speed} a second",
		"off_verb": "Turn auto exposure off",
		"ask_verb": "auto exposure is on",
		"reads_on": "Set auto exposure on",
		"reads_off": "Set auto exposure off",
		"about": "Lets the lens open and close by itself with how bright the picture is - the eye adjusting when the player walks out of a cave. Forward+ only: on Mobile and Compatibility the row does nothing rather than erroring.",
		"off_about": "Puts the lens back under the sheet's control, at whatever exposure it had drifted to. Forward+ only: on Mobile and Compatibility the row does nothing rather than erroring.",
		"ask_about": "True while the lens is adjusting itself to how bright the picture is.",
		"forward_plus": true,
		"companions": [
			{
				"property": "auto_exposure_speed",
				"param": "speed",
				"label": "Speed",
				"about": "How fast the lens adjusts, as a share of the way there each second. Small numbers take their time; large ones snap."
			},
			{
				"property": "auto_exposure_min_sensitivity",
				"param": "least",
				"label": "Least light",
				"practical": true,
				"about": "The dimmest the lens will let the picture get, in ISO. 0 leaves the bottom end open."
			},
			{
				"property": "auto_exposure_max_sensitivity",
				"param": "most",
				"label": "Most light",
				"practical": true,
				"about": "The brightest the lens will let the picture get, in ISO. Lower it to stop a dark room washing out."
			}
		],
		"spellings": {"auto_exposure_enabled": "AutoExposure"}
	}
]

## Per class, `property -> true`, filled the first time a class is asked about. ClassDB answers the
## same thing for the life of the process, and this is asked once per word on every descriptor build
## and once per line on every reading.
static var _properties: Dictionary = {}


## The property the attributes class answers a word with, or "" when it has none of that word's
## spellings. Derived: the word says which spellings are possible, ClassDB says which of them the
## class actually has.
static func property_of(word: String) -> String:
	var entry: Dictionary = word_entry(word)
	if entry.is_empty():
		return ""
	for property: String in (entry["spellings"] as Dictionary).keys():
		if has_property(ATTRIBUTES_CLASS, property):
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


## The frozen ace_id stem for one word on one host: the table's own stem, plus the host's suffix so
## the camera's row and the world's row can never share an id.
static func id_stem(word: String, host: Dictionary) -> String:
	var entry: Dictionary = word_entry(word)
	var property: String = property_of(word)
	if entry.is_empty() or property.is_empty():
		return ""
	return "%s%s" % [str((entry["spellings"] as Dictionary).get(property, "")),
		str(host.get("suffix", ""))]


## The value a row starts on: the ENGINE's default for the property, asked of ClassDB through the
## factory so a dropped row opens where Godot opens it and a reader never meets a number nobody
## chose.
static func default_of(word: String) -> String:
	var property: String = property_of(word)
	return "" if property.is_empty() else default_literal(property)


## One attributes property's engine default, as the text a row starts on. Asked through the factory
## rather than of ClassDB directly, because the answer arrives as a float32 widened to a double and a
## row must not open on `0.40000000596046` when the engine's own number is four tenths.
static func default_literal(property: String) -> String:
	return EventForgeACEFactory.default_literal(ATTRIBUTES_CLASS, property)


## Every word this vocabulary really resolves, in table order - the one list the rows, the reading
## and the tests all walk, so none of them can drift from the others.
static func words() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for entry: Dictionary in WORDS:
		if not property_of(str(entry["word"])).is_empty():
			found.append(str(entry["word"]))
	return found


## THE LINES every write is preceded by - the own-it courtesy for one host, spelled once. A slot
## holding nothing is given a Practical, because there is nothing to copy; one holding a FILE is
## given its own copy of it, whichever class that file is. An attributes resource the scene already
## keeps inside itself has no `resource_path` and is nobody else's, so it is left exactly as it is -
## and a copy taken once has no path either, which is what makes a row that runs every frame take one
## copy and not sixty.
static func own_lines(host: Dictionary) -> String:
	var member: String = str(host["member"])
	return "if %s == null:\n\t%s = %s.new()\nelif not %s.resource_path.is_empty():\n\t%s = %s.duplicate()\n" % [
		member, member, FALLBACK_CLASS, member, member, member]


## The guard a Practical-only line lives inside: the line runs on the lens a row would have made, and
## says nothing at all on one somebody deliberately fitted themselves.
static func practical_guard(host: Dictionary) -> String:
	return "if %s is %s:" % [str(host["member"]), PRACTICAL_CLASS]


## THE TABLE READ BACKWARDS: the word an attributes property IS, or "" for a property no word here
## means. What turns a hand-written `attributes.exposure_multiplier = 2.0` back into the sentence the
## picker would have made - the same job the light words do for `energy` and the environment words do
## for `fog_height`, and the reason every one of these tables says what it means rather than only how
## to write it.
static func word_of_property(property: String) -> String:
	var wanted: String = property.strip_edges()
	if wanted.is_empty():
		return ""
	for word: String in words():
		if property_of(word) == wanted:
			return word
	return ""


## The sentence a row of one word reads as, with `{value}` still in it - what the reading uses so a
## typed line and a picked row say exactly the same thing. "" for a word that is not one.
static func verb_of_property(property: String) -> String:
	var word: String = word_of_property(property)
	return "" if word.is_empty() else str(word_entry(word).get("verb", ""))


## The two sentences a SWITCH word READS as, on and off, or [] for a property that is not one.
static func switch_readings_of_property(property: String) -> Array:
	var word: String = word_of_property(property)
	if word.is_empty():
		return []
	var entry: Dictionary = word_entry(word)
	if str(entry["kind"]) != KIND_SWITCH:
		return []
	return [str(entry["reads_on"]), str(entry["reads_off"])]


## The sentence a COMPANION property reads as, or "" for a property that is not one. A companion is
## not a word of its own - nobody says "set the auto exposure speed" as a sentence about the game -
## but a file that writes one by hand still deserves better than the property name, so each carries
## the sentence its own field is labelled with.
static func companion_verb_of_property(property: String) -> String:
	var wanted: String = property.strip_edges()
	for entry: Dictionary in WORDS:
		for companion: Variant in (entry.get("companions", []) as Array):
			var field: Dictionary = companion
			if str(field["property"]) == wanted:
				return "Set %s to {value}" % str(field["label"]).to_lower()
	return ""


## The sentence a FOCUS property reads as, or "" for a property that is not one. The three depth-of-
## field properties the two focus rows write, read back in the words those rows are said in - so a
## hand-written `attributes.dof_blur_far_distance = 12.0` says "Set focus distance to 12.0" rather
## than naming a Godot property nobody outside a camera menu has met.
static func focus_verb_of_property(property: String) -> String:
	match property.strip_edges():
		FOCUS_DISTANCE:
			return "Set focus distance to {value}"
		FOCUS_TRANSITION:
			return "Set focus falloff to {value}"
		FOCUS_AMOUNT:
			return "Set blur amount to {value}"
		_:
			return ""


## The two sentences the focus SWITCH reads as, on and off, or [] for a property that is not it.
static func focus_switch_readings(property: String) -> Array:
	return ["Set focus blur on", "Set focus blur off"] if property.strip_edges() == FOCUS_ENABLED \
		else []


## Every LINE FRAGMENT this vocabulary emits that only does anything on Forward+, paired with the
## plain word a reader knows it by - `["attributes.auto_exposure_enabled", "auto exposure"]`. THE one
## table the Doctor's renderer note reads for the lens, derived from the word table rather than
## written a second time, so a note can never name a row this file has stopped publishing. One pair
## per host, because the two nodes spell the same word differently.
static func forward_plus_reasons() -> Array[Array]:
	var found: Array[Array] = []
	for entry: Dictionary in WORDS:
		if not bool(entry.get("forward_plus", false)):
			continue
		var property: String = property_of(str(entry["word"]))
		if property.is_empty():
			continue
		for host: Dictionary in HOSTS:
			found.append(["%s.%s" % [str(host["member"]), property], str(entry["word"])])
	return found


## True when a member is one of the two slots a CameraAttributes hangs in - the whole gate the
## reading asks before it claims a line, because `exposure_multiplier` on its own could be anybody's.
static func is_attributes_member(member: String) -> bool:
	var wanted: String = member.strip_edges()
	for host: Dictionary in HOSTS:
		if wanted == str(host["member"]):
			return true
	return false
