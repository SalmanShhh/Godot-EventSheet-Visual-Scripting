# EventForge - the lighting spellings people wrote before this plugin existed.
#
# Most lit games are older than the sheet that opens them, so every light row has to be readable
# BACKWARDS out of hand-written GDScript: `$Torch.energy = 1.2`, `torch.light_energy = 0.5`,
# `get_node("Lantern").shadow_enabled = true`, the one-line tween a fade is, and the bare
# `energy = 1.2` a sheet attached to the light ITSELF writes - "On node" is optional, so a receiver
# that is not there is a spelling too, and the commonest one. Each match hands back the exact
# template it matched, so the row re-emits the author's own bytes rather than a canonical spelling
# of them.
#
# THE GATE, and the reason this family has a guard at all: a line only becomes a light row when the
# ATTACHED SCENE (or the file's own typed declaration) says the node it names really is a light -
# and for a line that names no node, that the node the SHEET is on is one. `.enabled = false` is a
# sentence half the objects in a game can say, and claiming it for a light would relabel somebody's
# door. A node whose class cannot be established stays a script block with the usual Adopt offer -
# the row never guesses, and a reader can always check the claim against the scene in front of them.
#
# Everything here is TABLE ENTRIES (see EventForgeLiftTable): one pattern per property, the captures
# that are values, and the spelling stored by splicing those captures out of the author's own line.
# And nothing is written per property: the entries are built from the same word map the rows are
# built from, so a light class the engine adds is recognised on the strength of ClassDB knowing it.
@tool
class_name EventForgeLightingLift
extends RefCounted

const W := preload("res://addons/eventforge/registration/light_words.gd")

## The node spellings a row can address a light by. All four are the author's own text and ride back
## out untouched: the row shows the light it names, so `target` IS a value, and which of the four
## spellings was used is part of the line rather than part of the sentence.
const NODE_TEXT: String = "\\$[A-Za-z_][A-Za-z0-9_/]*|%[A-Za-z_][A-Za-z0-9_]*"\
	+ "|get_node\\(\"[A-Za-z_][A-Za-z0-9_/]*\"\\)|[A-Za-z_][A-Za-z0-9_]*"

## The call a fade is written as - the one spelling that names no property of its own.
const FADE_CALL: String = "tween_property"

## The value a row's receiver carries when the line names no node - "On node", left blank, which is
## what every shipped node-scoped descriptor opens on and what its own description tells the author
## to leave there. A blank receiver means the node the SHEET is on, so `energy = 1.2` on a sheet
## attached to a torch is the same row as `$Torch.energy = 1.2` on the sheet beside it.
const BLANK_RECEIVER: Dictionary = {"target": ""}

## The two lighting nodes that are not lights, and the member the World rows all write
## through. A darkness line and a light's colour line are spelled identically (`X.color = ...`), so
## which of them a line IS depends entirely on what the scene says X is - which is exactly what the
## guard below asks, and why neither can be claimed without it.
const DARKNESS_HOST: String = "CanvasModulate"
const WORLD_HOST: String = "WorldEnvironment"
const ENVIRONMENT_MEMBER: String = "environment"

## The sample node one class is given in a generated fixture, so every entry can write a line whose
## target really is a node of the kind that entry is about. Doubles as the fixture's whole scene:
## `lift_fixture_context` notes exactly these.
const FIXTURE_NODES: Dictionary = {
	"PointLight2D": "Torch",
	"DirectionalLight2D": "Moonlight",
	"OmniLight3D": "Bulb",
	"SpotLight3D": "Flashlight",
	"DirectionalLight3D": "Sun",
	DARKNESS_HOST: "Level",
	WORLD_HOST: "World"
}

## What a generated fixture sets a light to. One per kind of field, because a colour is written as a
## colour and everything else as a number.
const FIXTURE_VALUE: String = "1.2"
const FIXTURE_COLOUR: String = "Color(\"ffd9a1\")"
const FIXTURE_SECONDS: String = "0.5"

## Node reference -> class, for the file being lifted: every node of its scenes, plus every variable
## it declares that a class can be put to. Filled once per lift from the scene and the source, for
## the same reason the multiplayer table's peer variables are: a `torch.energy = 1.2` line cannot say
## on its own whether `torch` is a light or somebody's campfire counter.
static var target_classes: Dictionary = {}

## The declaration shapes a class can be read off: `@onready var torch: PointLight2D = $Torch`,
## `@export var lamp: OmniLight3D`, `@onready var torch := $Torch`. The type wins when there is one;
## otherwise the node the variable holds is looked up in the scene.
static var _declaration: RegEx = null

## The entries and their prefilter, built once for the life of the session: these run on every
## statement of every opened file, and rebuilding the table per line was the whole cost of it.
static var _entries: Array[Dictionary] = []
static var _marks: PackedStringArray = PackedStringArray()


## Records what the file being lifted can name, and what each of those names is. Called at the start
## of every lift; a file with no scene and no typed declarations simply leaves every guard with
## nothing to say yes to.
static func note_source(source: String, script_path: String) -> void:
	target_classes = EventSheetSceneLights.classes_for_script(script_path).duplicate()
	if _declaration == null:
		_declaration = RegEx.create_from_string("(?m)^[ \\t]*(?:@onready[ \\t]+|@export[ \\t]+)?"\
			+ "var[ \\t]+(?<name>[A-Za-z_][A-Za-z0-9_]*)[ \\t]*"\
			+ "(?::[ \\t]*(?<type>[A-Za-z_][A-Za-z0-9_]*)[ \\t]*)?(?::?=[ \\t]*(?<value>[^\\n]+))?$")
	for hit: RegExMatch in _declaration.search_all(source):
		var declared: String = hit.get_string("type").strip_edges()
		if declared.is_empty():
			declared = str(target_classes.get(
				EventSheetSceneLights.reference_key(hit.get_string("value")), ""))
		if addresses(declared):
			target_classes[hit.get_string("name")] = declared


## True when a class is one this vocabulary has rows for: any light, the CanvasModulate darkness
## sits on, or the WorldEnvironment the atmosphere rows write through. The gate on which declared
## variables are worth remembering - a `var speed: float` is nobody's light.
static func addresses(class_text: String) -> bool:
	var text: String = class_text.strip_edges()
	if W.is_light_class(text):
		return true
	if not ClassDB.class_exists(text):
		return false
	return ClassDB.is_parent_class(text, DARKNESS_HOST) or ClassDB.is_parent_class(text, WORLD_HOST)


## The row one statement means, or {} when no spelling claims it. `line` is a single statement,
## already dedented by the lifter.
static func match_line(line: String) -> Dictionary:
	var text: String = line.strip_edges()
	var entries: Array[Dictionary] = lift_entries()
	var possible: bool = false
	for mark: String in _marks:
		possible = possible or text.contains(mark)
	if not possible:
		return {}
	return EventForgeLiftTable.match_line(entries, text)


## Every lighting spelling, as table entries. Built from the word map rather than written out: one
## entry per property a word resolves to (two for a switch, because on and off are two rows), plus
## the tween for a word a light can be faded on. Alongside them, the fragments a line must contain
## for any of them to be worth trying - the property names themselves, so the prefilter can never
## drift from the table it guards.
static func lift_entries() -> Array[Dictionary]:
	if not _entries.is_empty():
		return _entries
	var entries: Array[Dictionary] = []
	var marks: PackedStringArray = PackedStringArray([FADE_CALL])
	for word: Dictionary in W.WORDS:
		for dimension: Array in [[W.CLASSES_2D, W.ROOT_2D], [W.CLASSES_3D, W.ROOT_3D]]:
			for row: Dictionary in W.rows_of(str(word["word"]), dimension[0], str(dimension[1])):
				if not marks.has(str(row["property"])):
					marks.append(str(row["property"]))
				if str(word["kind"]) == W.KIND_SWITCH:
					entries.append(_switch_entry(row, true))
					entries.append(_switch_entry(row, false))
					continue
				entries.append(_value_entry(word, row))
				if bool(word.get("fades", false)):
					entries.append(_fade_entry(row))
	entries.append_array(_scene_object_entries())
	for mark: String in ["color", ENVIRONMENT_MEMBER]:
		if not marks.has(mark):
			marks.append(mark)
	_entries = entries
	_marks = marks
	return _entries


## The two nodes that are not lights. The darkness pair writes a CanvasModulate's colour;
## the World rows all write a property of the environment a WorldEnvironment holds, which is why
## every one of their patterns goes through `.environment.` and none of them can be confused with a
## light. Written out rather than derived, because these are not a WORD map with spellings per
## class: each is one property with one plain sentence, and there is only one class to ask.
static func _scene_object_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = [
		_object_entry("DarknessSet", DARKNESS_HOST, "color", FIXTURE_COLOUR),
		_tween_entry("DarknessFade", DARKNESS_HOST, "", "color", FIXTURE_COLOUR)
	]
	for switch: Array in [["WorldFogOn", "fog_enabled", "true"], ["WorldFogOff", "fog_enabled", "false"],
			["WorldGlowOn", "glow_enabled", "true"], ["WorldGlowOff", "glow_enabled", "false"]]:
		entries.append(_switch_of(str(switch[0]), WORLD_HOST, _through_environment(str(switch[1])),
			str(switch[2])))
	entries.append(_object_entry("WorldSetFogThickness", WORLD_HOST,
		_through_environment("fog_density"), FIXTURE_VALUE))
	entries.append(_object_entry("WorldSetAmbientLight", WORLD_HOST,
		_through_environment("ambient_light_energy"), FIXTURE_VALUE))
	entries.append(_tween_entry("WorldFadeGlow", WORLD_HOST, ".%s" % ENVIRONMENT_MEMBER,
		"glow_intensity", FIXTURE_VALUE))
	entries.append(_own_environment_entry())
	return entries


## The one atmosphere row that is not a knob, and the one the Doctor writes on a reader's
## behalf. `environment = environment.duplicate()` gives a scene its own copy of an environment other
## scenes load; a sheet that has taken that step is never told to take it again, which only works if
## the line reads back as the row that wrote it. Both halves name the SAME node, so the second
## mention is matched under its own capture and left out of `params` - it is part of the spelling,
## and a line copying one world into a different one is nobody's row.
static func _own_environment_entry() -> Dictionary:
	return {
		"id": "%s_%s_own" % [ENVIRONMENT_MEMBER, WORLD_HOST.to_lower()],
		"ace_id": "WorldOwnEnvironment",
		"pattern": "^%s%s = %s%s\\.duplicate\\(\\)$" % [_receiver(), ENVIRONMENT_MEMBER,
			_receiver("holder"), ENVIRONMENT_MEMBER],
		"params": ["target"],
		"defaults": BLANK_RECEIVER,
		"guard": Callable(EventForgeLightingLift, "_copies_its_own_world"),
		"shape": "%s%s = %s%s.duplicate()" % [
			EventForgeLiftTable.optional_prefix_slot("target"), ENVIRONMENT_MEMBER,
			EventForgeLiftTable.optional_prefix_slot("target"), ENVIRONMENT_MEMBER],
		"slots": {"target": _fixture_node(WORLD_HOST)}
	}


## True when a line gives ONE WorldEnvironment its own copy of its own environment. Two questions,
## because the row is only that row when both hold: the same node on both sides of the `=`, and a
## node the scene says really is a WorldEnvironment.
static func _copies_its_own_world(captures: Dictionary) -> bool:
	if str(captures.get("target", "")).strip_edges() != str(captures.get("holder", "")).strip_edges():
		return false
	return _target_is(captures, WORLD_HOST)


## One property reached THROUGH the environment - the shape every World row's line has.
static func _through_environment(property: String) -> String:
	return "%s.%s" % [ENVIRONMENT_MEMBER, property]


## A member path as a PATTERN reads it. A World row reaches through `environment.`, and an unescaped
## dot in a regex matches any character at all - so without this, `fog_density` would also be claimed
## off a line that spelled the reach some other way.
static func _literal(member_path: String) -> String:
	return member_path.replace(".", "\\.")


## The receiver a node-scoped line opens with, as one OPTIONAL capture. Optional because "On node" is
## an optional field on every one of these rows: leave it blank and the line is the bare member
## operation, `energy = 1.2`, which is the commonest shape a lit sheet writes and has to read back as
## the row that wrote it. `name` is the capture, so a line naming the same node twice can be matched
## with one group per mention and the guard asked whether they agree.
static func _receiver(name: String = "target") -> String:
	return "(?:(?<%s>%s)\\.)?" % [name, NODE_TEXT]


## `<node>.<property> = <anything>` on a node the scene says is `host_class`, or the same line with
## the receiver left off, on a sheet attached to a node of that class.
static func _object_entry(ace_id: String, host_class: String, property: String, sample: String) -> Dictionary:
	return {
		"id": "%s_%s_set" % [property.replace(".", "_"), host_class.to_lower()],
		"ace_id": ace_id,
		"pattern": "^%s%s = (?<value>.+)$" % [_receiver(), _literal(property)],
		"params": ["target", "value"],
		"defaults": BLANK_RECEIVER,
		"guard": _guard_of(host_class),
		"shape": "%s%s = {value}" % [EventForgeLiftTable.optional_prefix_slot("target"), property],
		"slots": {"target": _fixture_node(host_class), "value": sample}
	}


## `<node>.<property> = true` / `= false` - a switch, whose two answers are two rows.
static func _switch_of(ace_id: String, host_class: String, property: String, written: String) -> Dictionary:
	return {
		"id": "%s_%s_%s" % [property.replace(".", "_"), host_class.to_lower(), written],
		"ace_id": ace_id,
		"pattern": "^%s%s = %s$" % [_receiver(), _literal(property), written],
		"params": ["target"],
		"defaults": BLANK_RECEIVER,
		"guard": _guard_of(host_class),
		"shape": "%s%s = %s" % [EventForgeLiftTable.optional_prefix_slot("target"), property, written],
		"slots": {"target": _fixture_node(host_class)}
	}


## The one-line tween a fade is, for a node that is not a light. `reach` is what sits between the
## node and the tweened property (`.environment` for the World rows, nothing for darkness), and the
## VALUE capture is greedy so a `Color(0.3, 0.3, 0.36)` with commas in it is still one value.
static func _tween_entry(ace_id: String, host_class: String, reach: String, property: String,
		sample: String) -> Dictionary:
	return {
		"id": "%s_%s_fade" % [property, host_class.to_lower()],
		"ace_id": ace_id,
		"pattern": "^create_tween\\(\\)\\.tween_property\\((?<target>[^,]+)%s, \"%s\", "\
			% [_literal(reach), property] + "(?<value>.+), (?<seconds>[^,)]+)\\)$",
		"params": ["target", "value", "seconds"],
		"guard": _guard_of(host_class),
		"shape": "create_tween().tween_property({target}%s, \"%s\", {value}, {seconds})" % [reach, property],
		"slots": {"target": _fixture_node(host_class), "value": sample, "seconds": FIXTURE_SECONDS}
	}


## The sample node one class answers to in a generated fixture.
static func _fixture_node(host_class: String) -> String:
	return "$%s" % str(FIXTURE_NODES.get(host_class, "Torch"))


## `<light>.energy = 1.2` - the property this class answers the word with, set to anything.
static func _value_entry(word: Dictionary, row: Dictionary) -> Dictionary:
	var property: String = str(row["property"])
	return {
		"id": _entry_id(row, "set"),
		"ace_id": "LightSet%s" % str(row["id_stem"]),
		"pattern": "^%s%s = (?<value>.+)$" % [_receiver(), property],
		"params": ["target", "value"],
		"defaults": BLANK_RECEIVER,
		"guard": _guard_for(row),
		"shape": "%s%s = {value}" % [EventForgeLiftTable.optional_prefix_slot("target"), property],
		"slots": {
			"target": _fixture_target(row),
			"value": FIXTURE_COLOUR if str(word["kind"]) == W.KIND_COLOUR else FIXTURE_VALUE
		}
	}


## `<light>.enabled = false` - a switch, whose two answers are two rows. The value is not a param:
## which of the two rows this is IS the answer, so there is nothing left for the row to show.
static func _switch_entry(row: Dictionary, turned_on: bool) -> Dictionary:
	var property: String = str(row["property"])
	var written: String = "true" if turned_on else "false"
	return {
		"id": _entry_id(row, written),
		"ace_id": "Light%s%s" % [str(row["id_stem"]), "On" if turned_on else "Off"],
		"pattern": "^%s%s = %s$" % [_receiver(), property, written],
		"params": ["target"],
		"defaults": BLANK_RECEIVER,
		"guard": _guard_for(row),
		"shape": "%s%s = %s" % [EventForgeLiftTable.optional_prefix_slot("target"), property, written],
		"slots": {"target": _fixture_target(row)}
	}


## `create_tween().tween_property($Lantern, "energy", 1.0, 0.5)` - the one-line tween a fade is. The
## quoted property name is not a value either: it is the word the row already says.
static func _fade_entry(row: Dictionary) -> Dictionary:
	var property: String = str(row["property"])
	return {
		"id": _entry_id(row, "fade"),
		"ace_id": "LightFade%s" % str(row["id_stem"]),
		"pattern": "^create_tween\\(\\)\\.tween_property\\((?<target>[^,]+), \"%s\", (?<value>[^,]+),"\
			% property + " (?<seconds>.+)\\)$",
		"params": ["target", "value", "seconds"],
		"guard": _guard_for(row),
		"shape": "create_tween().tween_property({target}, \"%s\", {value}, {seconds})" % property,
		"slots": {"target": _fixture_target(row), "value": FIXTURE_VALUE, "seconds": FIXTURE_SECONDS}
	}


## An entry's own name, for the harness and for the printout it doubles as: the property, the class
## that answers to it, and what the line does with it. The class is part of it because one property
## can be two entries - `shadow_enabled` is both dimensions' answer, and the two rows are two rows.
static func _entry_id(row: Dictionary, doing: String) -> String:
	return "%s_%s_%s" % [str(row["property"]), str(row["host"]).to_lower(), doing]


## One row's guard: the target names a node the scene (or a typed declaration) says is a light of
## this row's own host class. Bound rather than written per entry, because the question is the same
## one every time and only the class changes.
static func _guard_for(row: Dictionary) -> Callable:
	return _guard_of(str(row["host"]))


## The same guard for a class named directly - what the darkness and World entries bind, since they
## have one class each rather than a row per spelling.
static func _guard_of(host_class: String) -> Callable:
	return Callable(EventForgeLightingLift, "_target_is").bind(host_class)


## True when the line's target really is a light of `host_class`. The whole of the "never guess"
## promise: an unknown name, a name the scenes do not carry, and a name that is some other kind of
## node all answer false, and the line stays the script block it was.
##
## A line that names NO node is asking about the node the sheet is on, which is the same question
## asked of the same map under the `self` spelling: `energy = 1.2` in a file attached to a torch is a
## light row, and the identical line in a file attached to anything else is somebody's variable.
static func _target_is(captures: Dictionary, host_class: String) -> bool:
	var written: String = str(captures.get("target", "")).strip_edges()
	var named: String = EventSheetSceneLights.SELF_REFERENCE if written.is_empty() \
		else EventSheetSceneLights.reference_key(written)
	if named.is_empty():
		return false
	var found: String = str(target_classes.get(named, ""))
	return not found.is_empty() and ClassDB.is_parent_class(found, host_class)


## The node a generated fixture line points at: one of this row's own classes, by the sample name
## `lift_fixture_context` notes for it.
static func _fixture_target(row: Dictionary) -> String:
	return _fixture_node(str(row["classes"][0]))


## The scene a GENERATED fixture cannot have: the harness builds `$Torch.energy = 1.2` out of the
## entry itself, with no project around it to have put a light in a scene. Called once per family
## before its entries are probed (see EventForgeLiftTable.FIXTURE_CONTEXT_METHOD).
static func lift_fixture_context() -> void:
	target_classes = {}
	for class_text: String in FIXTURE_NODES.keys():
		target_classes[str(FIXTURE_NODES[class_text])] = class_text
