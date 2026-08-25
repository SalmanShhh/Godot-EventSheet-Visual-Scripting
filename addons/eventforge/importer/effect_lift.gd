# EventForge - the shader spellings people wrote before this plugin existed.
#
# A project with effects in it already has these lines, and every one of them has to open as the row
# it means and save back as the author's own bytes:
#
#     material.set_shader_parameter(&"dissolve", 0.7)
#     $Sprite.material.set_shader_parameter("amount", x)
#     create_tween().tween_method(func(v): material.set_shader_parameter(&"dissolve", v), 0.0, 1.0, 0.8)
#     material = material.duplicate()
#
# The receiver may be missing (a sheet attached to the node itself), a `$` path, a `%` unique name,
# a `get_node()` call or the variable the node was held in; the name may be a StringName or a plain
# string. None of that is part of the sentence, so none of it is a value - which is exactly why it
# rides back out untouched.
#
# THE GATE is the project, twice over. A line becomes a DIAL row only when the attached scene says
# the node it names wears a material AND that material's shader really declares the dial. Both
# questions are asked of EventSheetSceneEffects, which walks the one chain there is
# (scene -> material -> shader), and a line that fails either stays exactly what it already was: the
# shipped free-string row, which is the honest reading of a name nothing can confirm. That is the
# whole promise - a dial row is evidence the shader has that dial, and it is never a guess.
#
# Everything here is TABLE ENTRIES (see EventForgeLiftTable), so the harness generates a fixture line
# per entry and asserts the byte round-trip without one being written by hand.
@tool
class_name EventForgeEffectLift
extends RefCounted

const V := preload("res://addons/eventforge/registration/modules/effect_dial_aces.gd")

## The value a row's receiver carries when the line names no node - "On node", left blank, which is
## what every node-scoped row opens on. A blank receiver means the node the SHEET is on, so
## `material.set_shader_parameter(&"dissolve", 0.7)` on a sheet attached to the sprite is the same
## row as the `$Sprite.` spelling on the sheet beside it.
const BLANK_RECEIVER: Dictionary = {"target": ""}

## The fragments a line must contain for any entry here to be worth trying. Every spelling this
## family knows reaches through `material`, so one word rules out almost every line in a project
## before a pattern is compiled at all.
const MARK: String = "material"

## What a generated fixture points at, and what it turns. Both are real files in this repository's
## own test corpus, so the harness's line is a line that would lift in a project too.
const FIXTURE_NODE: String = "$Aura"
const FIXTURE_DIAL: String = "glow"
const FIXTURE_SHADER: String = "res://tests/fixtures/effect_glow.gdshader"

## Node reference -> the wearing node it names, for the file being lifted: every material-wearing
## node of its scenes, plus every variable the file declares that holds one. Filled once per lift,
## for the same reason the lighting table fills its own map - a `sprite.material.…` line cannot say
## on its own whether `sprite` is a node in the scene or somebody's own variable.
static var wearers: Dictionary = {}

## The entries, built once for the life of the session: these run on every statement of every opened
## file, and rebuilding the table per line is the whole cost of a matcher.
static var _entries: Array[Dictionary] = []


## Records what the file being lifted can name. Called at the start of every lift; a file whose
## script no scene runs simply leaves every guard with nothing to say yes to.
static func note_source(source: String, script_path: String) -> void:
	wearers = EventSheetSceneEffects.wearers_of_script(script_path).duplicate()
	for declaration: Dictionary in EventSheetSceneLights.declarations(source):
		var held: Variant = wearers.get(str(declaration["value_key"]), null)
		if held != null:
			wearers[str(declaration["name"])] = held


## The row one statement means, or {} when no spelling claims it. `line` is a single statement,
## already dedented by the lifter.
static func match_line(line: String) -> Dictionary:
	var text: String = line.strip_edges()
	if not text.contains(MARK):
		return {}
	return EventForgeLiftTable.match_line(lift_entries(), text)


## Every shader spelling, as table entries. Four, because there are four shapes: turning a dial,
## walking one over time, giving a node its own material, and the two questions those share.
static func lift_entries() -> Array[Dictionary]:
	if _entries.is_empty():
		_entries = [_set_entry(), _fade_entry(), _own_entry()]
	return _entries


## `<node>.material.set_shader_parameter(&"dissolve", 0.7)`, with or without the receiver and with
## the name written either way round. The `&` and the quotes are scenery: the row's value is the
## NAME, so a StringName spelling and a plain-string one are the same row and each saves back as
## itself.
static func _set_entry() -> Dictionary:
	return {
		"id": "set_shader_parameter",
		"ace_id": "EffectSetDial",
		"pattern": "^%s%s\\.%s\\(&?\"(?<dial>[A-Za-z_][A-Za-z0-9_]*)\", (?<value>.+)\\)$" % [
			EventForgeLiftTable.receiver(), V.MATERIAL_MEMBER, V.SET_CALL],
		"params": ["target", V.DIAL_PARAM, "value"],
		"defaults": BLANK_RECEIVER,
		"guard": Callable(EventForgeEffectLift, "_turns_a_declared_dial"),
		"shape": "%s%s.%s(&\"{%s}\", {value})" % [
			EventForgeLiftTable.optional_prefix_slot("target"), V.MATERIAL_MEMBER, V.SET_CALL,
			V.DIAL_PARAM],
		"slots": {"target": FIXTURE_NODE, V.DIAL_PARAM: FIXTURE_DIAL, "value": "0.7"}
	}


## The one-line tween a fade is. The lambda's own argument name is the author's (`v`, `value`, `t`),
## so it is matched twice - once where it is declared and once where it is used - and left out of the
## params, which is what carries it back out unchanged. The guard checks the two agree: a lambda that
## takes one name and passes a different one is somebody else's line.
static func _fade_entry() -> Dictionary:
	return {
		"id": "tween_method_shader_parameter",
		"ace_id": "EffectFadeDial",
		"pattern": "^create_tween\\(\\)\\.tween_method\\(func\\((?<lambda>[A-Za-z_][A-Za-z0-9_]*)\\): "\
			+ "%s%s\\.%s\\(&?\"(?<dial>[A-Za-z_][A-Za-z0-9_]*)\", (?<passed>[A-Za-z_][A-Za-z0-9_]*)\\), "\
				% [EventForgeLiftTable.receiver(), V.MATERIAL_MEMBER, V.SET_CALL]\
			+ "(?<from>[^,]+), (?<to>[^,]+), (?<seconds>[^,)]+)\\)$",
		"params": ["target", V.DIAL_PARAM, "from", "to", "seconds"],
		"defaults": BLANK_RECEIVER,
		"guard": Callable(EventForgeEffectLift, "_fades_a_declared_dial"),
		"shape": "create_tween().tween_method(func(v): %s%s.%s(&\"{%s}\", v), {from}, {to}, {seconds})" % [
			EventForgeLiftTable.optional_prefix_slot("target"), V.MATERIAL_MEMBER, V.SET_CALL,
			V.DIAL_PARAM],
		"slots": {"target": FIXTURE_NODE, V.DIAL_PARAM: FIXTURE_DIAL, "from": "0.0", "to": "1.0",
			"seconds": "0.8"}
	}


## `material = material.duplicate()` - the row that gives one node its own copy before anything turns
## a dial on it. Both halves name the SAME node, so the second mention is matched under its own
## capture and left out of the params: a line copying one node's material onto another is nobody's row.
static func _own_entry() -> Dictionary:
	return {
		"id": "material_duplicate",
		"ace_id": "EffectOwnMaterial",
		"pattern": "^%s%s = %s%s\\.duplicate\\(\\)$" % [EventForgeLiftTable.receiver(),
			V.MATERIAL_MEMBER, EventForgeLiftTable.receiver("holder"), V.MATERIAL_MEMBER],
		"params": ["target"],
		"defaults": BLANK_RECEIVER,
		"guard": Callable(EventForgeEffectLift, "_copies_its_own_material"),
		"shape": "%s%s = %s%s.duplicate()" % [
			EventForgeLiftTable.optional_prefix_slot("target"), V.MATERIAL_MEMBER,
			EventForgeLiftTable.optional_prefix_slot("target"), V.MATERIAL_MEMBER],
		"slots": {"target": FIXTURE_NODE}
	}


## True when the line's target wears a material whose shader declares the dial it names. Both halves,
## because either one alone would claim a line it cannot stand behind: a node with no material makes
## every dial row a call on null, and a name the shader has never heard of is the silent failure this
## whole vocabulary exists to end.
static func _turns_a_declared_dial(captures: Dictionary) -> bool:
	var wearer: Dictionary = wearer_of(str(captures.get("target", "")))
	if wearer.is_empty():
		return false
	return EventForgeShaderUniforms.declares(str(wearer.get("shader_path", "")),
		str(captures.get(V.DIAL_PARAM, "")))


## The same question for a fade, with the lambda's own argument checked as well.
static func _fades_a_declared_dial(captures: Dictionary) -> bool:
	if str(captures.get("lambda", "")) != str(captures.get("passed", "")):
		return false
	return _turns_a_declared_dial(captures)


## True when a line gives ONE node its own copy of its own material: the same node on both sides of
## the `=`, and a node the scene says really wears one.
static func _copies_its_own_material(captures: Dictionary) -> bool:
	if str(captures.get("target", "")).strip_edges() != str(captures.get("holder", "")).strip_edges():
		return false
	return not wearer_of(str(captures.get("target", ""))).is_empty()


## The wearing node one written reference names, or {} for a name the scenes do not carry. A line
## that names NO node is asking about the node the sheet is on, which is the same question asked of
## the same map under the `self` spelling.
static func wearer_of(written: String) -> Dictionary:
	var text: String = written.strip_edges()
	var named: String = EventSheetSceneLights.SELF_REFERENCE if text.is_empty() \
		else EventSheetSceneLights.reference_key(text)
	return wearers.get(named, {}) if not named.is_empty() else {}


## The scene a GENERATED fixture cannot have: the harness builds its line out of the entry itself,
## with no project around it to have put a material on a node. Pointed at this repository's own
## fixture shader, so the line the harness writes is one a real project would lift.
## (See EventForgeLiftTable.FIXTURE_CONTEXT_METHOD.)
static func lift_fixture_context() -> void:
	wearers = {FIXTURE_NODE.substr(1): {"shader_path": FIXTURE_SHADER}}
