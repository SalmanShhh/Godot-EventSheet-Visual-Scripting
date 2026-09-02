# The %Name as a word the sheet speaks - the index, the picker section, the lift and the door.
#
# Godot's scene-unique mark is the engine's own answer to "this one node, wherever it moves to", and
# everything measured here is that mark becoming something the editor can offer instead of something
# somebody has to type:
#
#   the INDEX - the marked nodes of a real fixture scene, by value, with the class the scene text
#   said each one is, and the refusal for a name no scene carries;
#   the PICKER - the `%names` section's entries, and the vocabulary one picked name offers, with the
#   node already answered and the SHARED cached definition left untouched;
#   the LIFT - a statement written on a `%Name` receiver reading as a row on that object, and the
#   same statement on a name nothing can place staying honest code;
#   the ROUND TRIP - a fresh row picked on a `%name` emitting the same `%Name.member()` line back,
#   byte for byte;
#   the DOOR - what may be marked and what may not, the words it wears, and the `$Path` a parameter
#   field has to be holding for it to appear at all.
@tool
class_name SceneUniqueNamesTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

## The fixture scene that already carries a marked node: `Aura`, a Sprite2D, beside an unmarked
## `Plain` of the same class. Reused rather than duplicated, because a second scene saying the same
## thing is a second scene to keep in step.
const BOSS_SCRIPT: String = "res://tests/fixtures/effect_scene_boss.gd"
const BOSS_SCENE: String = "res://tests/fixtures/effect_scene_boss.tscn"

## A HUD with TWO marked nodes and every row written on one of them - the shape the whole feature is
## for, and the one the round trip is measured on.
const HUD_SCRIPT: String = "res://tests/fixtures/unique_names_hud.gd"

## One script run by TWO scenes that mark the same `%Bar` as different classes - the shape nothing
## reported before, because the first scene in order simply won.
const DISAGREE_SCRIPT: String = "res://tests/fixtures/unique_names_disagree.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_index() and ok
	ok = _test_the_picker_section() and ok
	ok = _test_the_offered_vocabulary() and ok
	ok = _test_the_lift() and ok
	ok = _test_the_round_trip() and ok
	ok = _test_the_door() and ok
	return ok


## THE INDEX. The scene text is the only authority, so the pin is the whole list: `Aura` is in it
## because the scene marked it, `Plain` and the root `Boss` are not because it did not.
static func _test_the_index() -> bool:
	EventSheetSceneLights.clear_cache()
	EventSheetSceneConnections.clear_cache()
	var read: Array[String] = []
	for node: Dictionary in EventSheetSceneUniqueNames.for_script(BOSS_SCRIPT):
		read.append("%s %s %s" % [str(node["reference"]), str(node["class"]), str(node["path"])])
	var ok: bool = _check("only the marked node is a %name", read, ["%Aura Sprite2D Aura"])
	ok = _check("both spellings resolve to the class the scene said",
		"%s|%s" % [
			EventSheetSceneUniqueNames.class_of(BOSS_SCRIPT, "%Aura"),
			EventSheetSceneUniqueNames.class_of(BOSS_SCRIPT, "Aura"),
		], "Sprite2D|Sprite2D") and ok
	ok = _check("a name no scene carries is not guessed at",
		EventSheetSceneUniqueNames.class_of(BOSS_SCRIPT, "%HealthBar"), "") and ok
	ok = _check("a script no scene uses has no names",
		EventSheetSceneUniqueNames.for_script("res://tests/fixtures/nothing_uses_this.gd").size(), 0) and ok
	# TWO SCENES, ONE %NAME, TWO CLASSES. One script may run in more than one scene, and each may mark
	# a `%Bar` - a ProgressBar in the wide layout, a Label in the compact one beside it. The name is
	# listed once (the sheet can only speak one of them) and its CLASS is nobody's to give: adopting
	# the first scene's would offer a row written in ProgressBar's vocabulary for a sheet whose other
	# scene has a Label there, and would do it silently. `%ScoreLabel`, which both scenes agree is a
	# Label, is unaffected - the refusal is per name, not per script.
	var disagreeing: Array[String] = []
	for node: Dictionary in EventSheetSceneUniqueNames.for_script(DISAGREE_SCRIPT):
		disagreeing.append("%s %s" % [str(node["reference"]), str(node["class"])])
	ok = _check("a name two scenes answer differently is typed by neither", disagreeing,
		["%Bar ", "%ScoreLabel Label"]) and ok
	ok = _check("and the class map says the same",
		EventSheetSceneUniqueNames.class_of(DISAGREE_SCRIPT, "%Bar"), "") and ok
	ok = _check("while a name they agree about still answers",
		EventSheetSceneUniqueNames.class_of(DISAGREE_SCRIPT, "%ScoreLabel"), "Label") and ok
	ok = _check("so the picker offers the one it can place and not the one it cannot",
		_picker_labels(DISAGREE_SCRIPT), ["%ScoreLabel   Label"]) and ok
	# The mark is a bare flag on the node's own header line, which the quoted attribute reader walks
	# straight past - so the reading of that spelling is pinned where it is made.
	ok = _check("the bare flag spelling is what the scene file writes", "%s|%s|%s" % [
			EventSheetSceneConnections.flag_attribute(
				"[node name=\"Aura\" type=\"Sprite2D\" parent=\".\" unique_name_in_owner=true]",
				EventSheetSceneUniqueNames.MARK_ATTRIBUTE),
			EventSheetSceneConnections.flag_attribute(
				"[node name=\"Plain\" type=\"Sprite2D\" parent=\".\"]",
				EventSheetSceneUniqueNames.MARK_ATTRIBUTE),
			EventSheetSceneUniqueNames.is_marked({"unique": true}),
		], "true|false|true") and ok
	return ok


## The labels the picker's %names section shows for one script, in order.
static func _picker_labels(script_path: String) -> Array[String]:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = script_path
	var read: Array[String] = []
	for value: Variant in ACEPickerDialog.unique_names_page_content(sheet).get("entries", []):
		read.append(str((value as Dictionary)["label"]))
	return read


## THE PICKER SECTION. What the object page offers, exactly as it offers it - the label a reader
## scans, and the metadata the pick is dispatched on.
static func _test_the_picker_section() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = BOSS_SCRIPT
	var content: Dictionary = ACEPickerDialog.unique_names_page_content(sheet)
	var read: Array[String] = []
	for value: Variant in content.get("entries", []):
		var entry: Dictionary = value
		read.append("%s :: %s" % [str(entry["label"]), str(entry["metadata"])])
	var ok: bool = _check("the section lists the mark, its class and the scope it dispatches",
		read, ["%Aura   Sprite2D :: unique:Aura|Sprite2D"])
	var hud: EventSheetResource = EventSheetResource.new()
	hud.external_source_path = HUD_SCRIPT
	var hud_read: Array[String] = []
	for value: Variant in ACEPickerDialog.unique_names_page_content(hud).get("entries", []):
		hud_read.append(str((value as Dictionary)["label"]))
	ok = _check("both marks of a scene are listed, in scene order, with their classes",
		hud_read, ["%HealthBar   ProgressBar", "%ScoreLabel   Label"]) and ok
	ok = _check("a sheet with no file behind it has no section",
		ACEPickerDialog.unique_names_page_content(EventSheetResource.new()).is_empty(), true) and ok
	ok = _check("and neither has no sheet at all",
		ACEPickerDialog.unique_names_page_content(null).is_empty(), true) and ok
	return ok


## THE VOCABULARY one picked name offers. The class's own members, with the node answered - and the
## shared cached definition the reflection handed back left exactly as it was, because an
## ACEDefinition is shared across every tab for the session.
static func _test_the_offered_vocabulary() -> bool:
	var offered: Array[ACEDefinition] = ACEPickerDialog.unique_node_definitions("Aura", "Sprite2D")
	var found: ACEDefinition = null
	for definition: ACEDefinition in offered:
		if definition.id == "property:set:flip_h":
			found = definition
			break
	var ok: bool = _check("the picked node offers its class's own properties", found != null, true)
	if found == null:
		return false
	var target: Dictionary = {}
	for value: Variant in found.parameters:
		var parameter: Dictionary = value
		if str(parameter.get("id", "")) == "target":
			target = parameter
	ok = _check("with the node already answered in the shipped On node parameter", "%s|%s|%s" % [
			str(target.get("default_value", "")), str(target.get("hint", "")),
			str(found.metadata.get(ACEPickerDialog.SCENE_TARGET_META, ""))
		], "%Aura|expression|%Aura") and ok
	ok = _check("the row it makes is the ordinary retargetable one",
		str(found.metadata.get("codegen_template", "")), "{target.}flip_h = {value}") and ok
	# The definition the reflection caches is shared for the session; stamping one row's node onto it
	# would put that node on every other sheet's rows too.
	var shared: Array[ACEDefinition] = EventSheetClassDBSource.definitions_for_class("Sprite2D")
	var shared_has_target: bool = false
	for definition: ACEDefinition in shared:
		if definition.id != "property:set:flip_h":
			continue
		for value: Variant in definition.parameters:
			if str((value as Dictionary).get("id", "")) == "target":
				shared_has_target = true
	ok = _check("and the shared definition it was copied from is untouched", shared_has_target, false) and ok
	ok = _check("a name or a class nothing said is offered nothing",
		ACEPickerDialog.unique_node_definitions("Aura", "").size()
			+ ACEPickerDialog.unique_node_definitions("", "Sprite2D").size(), 0) and ok
	return ok


## THE LIFT. A statement written on a `%Name` receiver is the one receiver shape the derived layer
## could not answer for, because nothing told it what class the sigil meant. The scene does.
static func _test_the_lift() -> bool:
	var context: Dictionary = {"self_class": "Node2D", "self_script_path": ""}
	var class_map: Dictionary = {"%Aura": "Sprite2D", "Aura": "Sprite2D"}
	var reading: Dictionary = EventSheetDerivedCalls.derived_pieces(
		"%Aura.set_flip_h(true)", context, class_map, {})
	var ok: bool = _check("a call on a %name reads as a row on that object", "%s|%s|%s" % [
			str(reading.get("object", "")), str(reading.get("class", "")), str(reading.get("method", ""))
		], "Aura|Sprite2D|set_flip_h")
	ok = _check("the receiver is placed by the scene rather than by a declaration",
		str(reading.get("source", "")), EventSheetDerivedCalls.SOURCE_NODE) and ok
	# A property no curated word map claims, deliberately: a map that HAS words for a property wins
	# outright and never reaches the derived layer, so pinning one of those would measure the map.
	var written: Dictionary = EventSheetDerivedProperties.derived_reading(
		EventSheetSentence.statement("%Aura.hframes = 4", context), context, class_map, {})
	ok = _check("and so does a write to one of its properties", "%s|%s" % [
			str(written.get("class", "")), str(written.get("property", ""))
		], "Sprite2D|hframes") and ok
	# The refusal is the load-bearing half: a `%name` no scene can place keeps the plain reading it
	# already had rather than being dressed as a class nobody said it was.
	ok = _check("a %name the scene cannot resolve is left as honest code",
		EventSheetDerivedCalls.derived_pieces("%HealthBar.set_flip_h(true)", context, class_map, {}).is_empty(),
		true) and ok
	ok = _check("and a property the class does not have is somebody else's",
		EventSheetDerivedCalls.receiver_facts("%Aura", context, class_map, {}).get("class", ""),
		"Sprite2D") and ok
	return ok


## THE ROUND TRIP. A row picked on a `%name` emits the same line the reading above lifts, so opening
## a file the picker wrote and picking a row on the same node produce the same bytes.
static func _test_the_round_trip() -> bool:
	var offered: Array[ACEDefinition] = ACEPickerDialog.unique_node_definitions("Aura", "Sprite2D")
	var emitted: Array[String] = []
	for definition: ACEDefinition in offered:
		if definition.id != "property:set:flip_h" and definition.id != "method:set_flip_h":
			continue
		var values: Dictionary = {"target": "%Aura"}
		for value: Variant in definition.parameters:
			var parameter: Dictionary = value
			var parameter_id: String = str(parameter.get("id", ""))
			if parameter_id != "target":
				values[parameter_id] = "true"
		emitted.append(ActionCodegen.generate_action(
			_action_of(definition, values)).strip_edges())
	emitted.sort()
	var ok: bool = _check("a fresh row on a %name emits that same %Name line back", emitted,
		["%Aura.flip_h = true", "%Aura.set_flip_h(true)"])
	# Clearing the node is the way back to a row on this node, and it must leave the line bare rather
	# than leaving a dangling sigil behind.
	var bare: ACEDefinition = null
	for definition: ACEDefinition in offered:
		if definition.id == "property:set:flip_h":
			bare = definition
	ok = _check("clearing the node writes the row on this node instead",
		ActionCodegen.generate_action(_action_of(bare, {"target": "", "value": "true"})).strip_edges(),
		"flip_h = true") and ok
	# And the standing contract, on a real file whose rows all sit on `%names`: opening it and saving
	# it untouched reproduces it byte for byte. The reading is a VIEW over unchanged rows, so this is
	# structural - which is exactly why it is worth measuring rather than assuming.
	ok = _check("a whole HUD written on %names saves back byte-identically",
		EventSheets.round_trips(FileAccess.get_file_as_string(HUD_SCRIPT)), true) and ok
	return ok


## One picked row as the sheet stores it: the definition's own baked template and the values that
## were answered. The compiler is then asked exactly what it is asked for a row somebody added.
static func _action_of(definition: ACEDefinition, values: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = definition.provider_id
	action.ace_id = definition.id
	action.codegen_template = str(definition.metadata.get("codegen_template", ""))
	action.params = values
	return action


## THE DOOR. One click gives a node reached by path Godot's own mark. It is a SCENE edit, so what it
## may touch is the load-bearing half - and outside the editor it writes the property directly, which
## is what lets the refusals be measured here at all.
static func _test_the_door() -> bool:
	var root: Node = Node.new()
	root.name = "Level"
	var branch: Node = Node.new()
	branch.name = "UI"
	root.add_child(branch)
	branch.owner = root
	var deep: Node = Node.new()
	deep.name = "HealthBar"
	branch.add_child(deep)
	deep.owner = root
	var foreign: Node = Node.new()
	foreign.name = "Inside"
	branch.add_child(foreign)
	var ok: bool = _check("what the door may mark, and what it may not", "%s|%s|%s|%s|%s" % [
			EventSheetUniqueNameDoor.can_mark(root, "UI/HealthBar"),
			EventSheetUniqueNameDoor.can_mark(root, "."),
			EventSheetUniqueNameDoor.can_mark(root, "UI/Inside"),
			EventSheetUniqueNameDoor.can_mark(root, "UI/Missing"),
			EventSheetUniqueNameDoor.can_mark(null, "UI/HealthBar"),
		], "true|false|false|false|false")
	ok = _check("the words it wears name the node it is about",
		EventSheetUniqueNameDoor.offer_text("HealthBar"), "Make %HealthBar unique") and ok
	ok = _check("the mark lands on the node and hands back the %name",
		EventSheetUniqueNameDoor.mark(root, "UI/HealthBar"), "%HealthBar") and ok
	ok = _check("the node now carries Godot's own mark", deep.unique_name_in_owner, true) and ok
	ok = _check("and a node already marked is offered nothing more",
		EventSheetUniqueNameDoor.mark(root, "UI/HealthBar"), "") and ok
	# What a parameter field has to be holding for the door to appear: a path reference, in either
	# spelling, and nothing else.
	var read: Array[String] = []
	for text: String in ["$UI/HealthBar", "$\"UI/Health Bar\"", "%HealthBar", "$/root/Main",
			"get_node(\"UI\")", "42", ""]:
		read.append("%s -> %s" % [text, EventSheetUniqueNameDoor.path_in_reference(text)])
	ok = _check("only a path reference has a node behind it", read, [
		"$UI/HealthBar -> UI/HealthBar",
		"$\"UI/Health Bar\" -> UI/Health Bar",
		"%HealthBar -> ",
		"$/root/Main -> ",
		"get_node(\"UI\") -> ",
		"42 -> ",
		" -> ",
	]) and ok
	ok = _check("the %name is the last segment of that path",
		EventSheetUniqueNameDoor.node_name_of_path("UI/Bars/HealthBar"), "HealthBar") and ok
	root.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.pin_value("scene_unique_names_test", label, actual, expected)
