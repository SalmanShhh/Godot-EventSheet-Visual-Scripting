@tool
class_name ScriptReaderTest
extends RefCounted

# Godot EventSheets - a class under "Your classes" is read the way a registered script is read.
#
# One reading for a script of yours, whichever door it comes in by: the generator's. What the old door
# published must stay true - every id still resolves (the two property ids as hidden, deprecated
# aliases that carry the old call and point at their successor), a row already placed compiles to the
# same bytes and keeps its call when edited, a side-file entry written against an old id still finds
# its verb, and a function the script hides stays resolvable but is not offered.

const SUPPORT := preload("res://tests/support.gd")
const READER := preload("res://addons/eventsheet/ace/script_reader.gd")
const DIR: String = "res://tests/fixtures/script_rows/"


static func run() -> bool:
	var ok: bool = _one_reading()
	ok = _old_ids_resolve() and ok
	ok = _hidden_members() and ok
	ok = _side_file() and ok
	ok = _placed_rows() and ok
	return ok


static func _read(file: String, class_text: String, prefix: String = "") -> Dictionary:
	var by_id: Dictionary = {}
	for definition: ACEDefinition in READER.definitions_for(class_text, load(DIR + file) as Script, prefix):
		by_id[definition.id] = definition
	return by_id


static func _one_reading() -> bool:
	var read: Dictionary = _read("node_thing.gd", "ScriptRowsNodeThing")
	var registered: Dictionary = {}
	for definition: ACEDefinition in EventSheetACEGenerator.new().reflect_script(load(DIR + "node_thing.gd") as Script):
		registered[definition.id] = definition
	var same_name: bool = true
	var same_call: bool = true
	for ace_id: String in ["method:take_damage", "method:is_dead", "method:get_health", "property:max_health", "set:max_health"]:
		same_name = same_name and (read[ace_id] as ACEDefinition).display_name == (registered[ace_id] as ACEDefinition).display_name
		same_call = same_call and str((read[ace_id] as ACEDefinition).metadata["codegen_template"]) == str((registered[ace_id] as ACEDefinition).metadata["codegen_template"])
	return SUPPORT.pins("script_reader_test", [
		["a function reads under the same name as a registered script's", same_name, true],
		["and makes the same call", same_call, true],
		["a condition is named without its Is", (read["method:is_dead"] as ACEDefinition).display_name, "Dead"],
		["an untyped function is an action", (read["method:pick"] as ACEDefinition).ace_type, ACEDefinition.ACEType.ACTION],
		["the verbs are flagged as reflected from the class", [(read["method:pick"] as ACEDefinition).metadata["reflected"], (read["method:pick"] as ACEDefinition).metadata["reflect_class"]], [true, "ScriptRowsNodeThing"]],
		["they publish under the class card's name", (read["method:pick"] as ACEDefinition).provider_id, "ScriptRowsNodeThing"],
		["an Add and a Subtract come with a number", [read.has("add:max_health"), read.has("subtract:max_health"), read.has("add:label_text")], [true, true, false]],
		["a global is called by its name", str((_read("node_thing.gd", "ScriptRowsNodeThing", "Hero")["method:take_damage"] as ACEDefinition).metadata["codegen_template"]), "Hero.take_damage({amount}, {from})"],
	])


static func _old_ids_resolve() -> bool:
	var read: Dictionary = _read("node_thing.gd", "ScriptRowsNodeThing")
	var getter: ACEDefinition = read["property:get:max_health"]
	var setter: ACEDefinition = read["property:set:max_health"]
	var autoload_getter: ACEDefinition = _read("node_thing.gd", "ScriptRowsNodeThing", "Hero")["property:get:max_health"]
	return SUPPORT.pins("script_reader_test", [
		["the old reader id still resolves, with the old call", str(getter.metadata["codegen_template"]), "{target.}max_health"],
		["the old writer id too", str(setter.metadata["codegen_template"]), "{target.}max_health = {value}"],
		["as an expression and an action", [getter.ace_type, setter.ace_type], [ACEDefinition.ACEType.EXPRESSION, ACEDefinition.ACEType.ACTION]],
		["the writer keeps its one value slot", setter.parameters.map(func(entry: Dictionary) -> String: return str(entry["id"])), ["value"]],
		["both are not offered", [getter.metadata["deprecated"], setter.metadata["deprecated"]], [true, true]],
		["and say where they went", [(getter.metadata["successor"] as Dictionary)["id"], (setter.metadata["successor"] as Dictionary)["id"]], ["property:max_health", "set:max_health"]],
		["a global's alias calls the singleton as it did", str(autoload_getter.metadata["codegen_template"]), "Hero.max_health"],
		["an id that never changed has no alias", read.has("method:take_damage:alias"), false],
		["the ids an id used to have", [Array(READER.legacy_ids_for("property:max_health")), Array(READER.legacy_ids_for("set:max_health")), Array(READER.legacy_ids_for("method:go"))], [["property:get:max_health"], ["property:set:max_health"], []]],
	])


static func _hidden_members() -> bool:
	var read: Dictionary = _read("annotated_twin.gd", "ScriptRowsAnnotatedTwin")
	var hidden: ACEDefinition = read["method:internal_step"]
	var shown: ACEDefinition = read["method:take_damage"]
	return SUPPORT.pins("script_reader_test", [
		["a function the script hides is still there for rows already placed", read.has("method:internal_step"), true],
		["and marked as not offered", [hidden.metadata.get("hidden_member", false), hidden.metadata.get("deprecated", false)], [true, true]],
		["an ordinary one is offered", shown.metadata.get("deprecated", false), false],
		["the authored name and sentence read as written", [shown.display_name, shown.metadata["display_template"]], ["Hurt", "Take {amount} damage"]],
		["and are marked as authored, facet by facet", shown.metadata["authored"], {"name": true, "category": true, "sentence": true}],
	])


## The project's side file may refine only what the script did not say itself, and an entry written
## against an old id still finds its verb.
static func _side_file() -> bool:
	var read: Dictionary = _read("annotated_twin.gd", "ScriptRowsAnnotatedTwin")
	var catalog: EventSheetVocabularyCatalog = EventSheetVocabularyCatalog.new()
	EventSheetVocabularyCatalog._cache = catalog
	EventSheetVocabularyCatalog._loaded = true
	EventSheetVocabularyCatalog._cache_signature = EventSheetVocabularyCatalog._file_signature()
	catalog.overrides = {
		"ScriptRowsAnnotatedTwin::method:take_damage": {"display_name": "Renamed", "category": "Moved"},
		"ScriptRowsAnnotatedTwin::property:get:max_health": {"display_name": "Total Health", "category": "Stats"},
	}
	var applied: Dictionary = {}
	for definition: ACEDefinition in EventSheetVocabularyCatalog.apply(read.values()):
		applied[definition.id] = definition
	var edits: Array = EventSheetVocabularyCatalog.bake_edits_for("ScriptRowsAnnotatedTwin")
	var members: Array = edits.map(func(edit: Dictionary) -> String: return "%s:%s" % [edit["source_kind"], edit["member"]])
	members.sort()
	var ids: Array = [EventSheetVocabularyCatalog.member_from_ace_id("property:max_health"), EventSheetVocabularyCatalog.member_from_ace_id("add:max_health")]
	EventSheetVocabularyCatalog._cache = null
	EventSheetVocabularyCatalog._loaded = false
	return SUPPORT.pins("script_reader_test", [
		["an authored name and category outrank the side file", [(applied["method:take_damage"] as ACEDefinition).display_name, (applied["method:take_damage"] as ACEDefinition).category], ["Hurt", "Fighting"]],
		["an entry written against the old reader id refines the new one", [(applied["property:max_health"] as ACEDefinition).display_name, (applied["property:max_health"] as ACEDefinition).category], ["Total Health", "Stats"]],
		["the alias itself is never refined", (applied["property:get:max_health"] as ACEDefinition).display_name, "Max Health"],
		["a rename bakes into the script once, for the property", members, ["method:take_damage", "property:max_health"]],
		["the new ids name their member", ids, [{"source_kind": "property", "member": "max_health"}, {"source_kind": "property", "member": "max_health"}]],
	])


## A row placed from the old door compiles from the call baked on it, never from today's reading.
static func _placed_rows() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "ScriptRowsNodeThing"
	action.ace_id = "property:set:max_health"
	action.codegen_template = "{target.}max_health = {value}"
	action.params = {"value": "50"}
	event.actions.append(action)
	sheet.events.append(event)
	var output: String = str(EventSheetCompiler.compile(sheet).get("output", ""))
	var apply: GDScript = load("res://addons/eventsheet/editor/dock/ace_apply.gd")
	var edited: ACEAction = ACEAction.new()
	edited.codegen_template = "{target}.max_health = {value}"
	edited.params = {"target": "$ScriptRowsNodeThing", "value": "75"}
	apply._keep_legacy_template(action, edited)
	return SUPPORT.pins("script_reader_test", [
		["a row from the old door still compiles to the plain assignment", output.contains("\n\tmax_health = 50\n"), true],
		["editing it keeps the call it was placed with", edited.codegen_template, "{target.}max_health = {value}"],
		["and its target stays as the row had it", edited.params.has("target"), true],
	])
