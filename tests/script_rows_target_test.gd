@tool
class_name ScriptRowsTargetTest
extends RefCounted

# Godot EventSheets - a row from a script of yours acts on the real thing, not on a hidden copy.
#
# A function with no call line of its own used to bake to a call on a small copy of the class the sheet
# kept for itself, so a row from a Node script changed an object no scene held and a row from a Resource
# changed a copy nobody could see. For a script the reader wrote:
#
#   a Node script           the call goes to `$ClassName`, with an "On node" slot that can be retargeted
#   a Resource, or a        the call goes to a value the sheet names: a parameter that starts empty
#   RefCounted holding      (`null`), so the row visibly asks which one
#   variables
#   a `static func`         is called by its class's name
#
# What it must NOT do: move a shipped pack (its template-less functions keep reading as they did - the
# registry dumps are the gate for that, and one pack is spot-checked here), change what a row already
# placed compiles to (a row baked on the old call compiles to the same bytes, edited or not), or invent
# anything for a script with an authored call line.

const SUPPORT := preload("res://tests/support.gd")
const DIR: String = "res://tests/fixtures/script_rows/"
const LEGACY_COMPILE: String = "res://tests/fixtures/script_rows/legacy_compile.txt"
## A shipped Node pack and a shipped Resource pack whose functions carry no template of their own.
const SHIPPED_TEMPLATELESS: PackedStringArray = [
	"res://eventsheet_addons/canvas_surface/canvas_surface.gd",
	"res://eventsheet_addons/damage_type_set_resource/damage_type_set.gd",
]


static func run() -> bool:
	var ok: bool = _node_script()
	ok = _resource_script() and ok
	ok = _static_functions() and ok
	ok = _authored_template_wins() and ok
	ok = _shipped_pack_unmoved() and ok
	ok = _placed_rows_compile_the_same() and ok
	ok = _editing_keeps_the_old_call() and ok
	ok = _starts_on_the_node_of_the_open_scene() and ok
	return ok


static func _definitions(file: String) -> Dictionary:
	var by_id: Dictionary = {}
	for definition: ACEDefinition in EventSheetACEGenerator.new().reflect_script(load(DIR + file) as Script):
		by_id[definition.id] = definition
	return by_id


static func _template(definitions: Dictionary, ace_id: String) -> String:
	return str((definitions[ace_id] as ACEDefinition).metadata.get("codegen_template", "")) if definitions.has(ace_id) else "<missing>"


static func _param(definitions: Dictionary, ace_id: String, param_id: String) -> Dictionary:
	if not definitions.has(ace_id):
		return {}
	for entry: Variant in (definitions[ace_id] as ACEDefinition).parameters:
		if str((entry as Dictionary).get("id", "")) == param_id:
			return entry
	return {}


static func _node_script() -> bool:
	var node: Dictionary = _definitions("node_thing.gd")
	var loose: Dictionary = _definitions("loose_thing.gd")
	return SUPPORT.pins("script_rows_target_test", [
		["a Node function calls the node by its class", _template(node, "method:take_damage"), "{target}.take_damage({amount}, {from})"],
		["a condition does too", _template(node, "method:is_dead"), "{target}.is_dead()"],
		["an untyped one is an action on the node", [_template(node, "method:pick"), (node["method:pick"] as ACEDefinition).ace_type], ["{target}.pick()", ACEDefinition.ACEType.ACTION]],
		["the On node slot starts as the class", _param(node, "method:take_damage", "target").get("default_value", ""), "$ScriptRowsNodeThing"],
		["and leads the parameters", (node["method:take_damage"] as ACEDefinition).parameters[0]["id"], "target"],
		["the sentence is the name and the method's own values", (node["method:take_damage"] as ACEDefinition).metadata["display_template"], "Take Damage {amount} {from}"],
		["a script with no class name is aimed by its file name", _param(loose, "method:ping", "target").get("default_value", ""), "$LooseThing"],
		["a variable's rows were already aimed at the node", _template(node, "set:max_health"), "{target}.max_health = {value}"],
	])


static func _resource_script() -> bool:
	var resource: Dictionary = _definitions("resource_thing.gd")
	return SUPPORT.pins("script_rows_target_test", [
		["a Resource function acts on a value the sheet names", _template(resource, "method:add"), "{resource}.add({count})"],
		["so does one that answers", _template(resource, "method:total"), "{resource}.total()"],
		["a variable's reader", _template(resource, "property:amount"), "{resource}.amount"],
		["its Set", _template(resource, "set:amount"), "{resource}.amount = {value}"],
		["its Add", _template(resource, "add:amount"), "{resource}.amount += {amount}"],
		["the value starts empty so the row asks which one", _param(resource, "method:add", "resource").get("default_value", ""), "null"],
		["and it is a plain expression field, not the node chooser", _param(resource, "method:add", "resource").get("hint", ""), "expression"],
		["the sentence says which one it acts on", (resource["method:add"] as ACEDefinition).metadata["display_template"], "Add {count} on {resource}"],
		["an expression keeps its name as its sentence", (resource["method:total"] as ACEDefinition).metadata["display_template"], "Total"],
		["no row of a Resource is left on the hidden copy", _no_row_uses_the_copy(resource), true],
	])


static func _no_row_uses_the_copy(definitions: Dictionary) -> bool:
	for definition: Variant in definitions.values():
		if str((definition as ACEDefinition).metadata.get("codegen_template", "")).contains("__eventsheet_provider_"):
			return false
		if (definition as ACEDefinition).instance_backed_template() != "":
			return false
	return true


static func _static_functions() -> bool:
	var statics: Dictionary = _definitions("static_only.gd")
	var node: Dictionary = _definitions("node_thing.gd")
	return SUPPORT.pins("script_rows_target_test", [
		["a static function is called by its class's name", _template(statics, "method:clamp_score"), "ScriptRowsStaticOnly.clamp_score({value})"],
		["with no slot for an instance", (statics["method:clamp_score"] as ACEDefinition).parameters.size(), 1],
		["one that answers is an expression", (statics["method:clamp_score"] as ACEDefinition).ace_type, ACEDefinition.ACEType.EXPRESSION],
		["one that does is an action", (statics["method:reset_all"] as ACEDefinition).ace_type, ACEDefinition.ACEType.ACTION],
		["a static in a Node script is called by the class too", _template(node, "method:make_label"), "ScriptRowsNodeThing.make_label({prefix})"],
	])


static func _authored_template_wins() -> bool:
	var twin: Dictionary = _definitions("annotated_twin.gd")
	return SUPPORT.pins("script_rows_target_test", [
		["an authored sentence is kept as written", (twin["method:take_damage"] as ACEDefinition).metadata["display_template"], "Take {amount} damage"],
		["its call is still the node's", _template(twin, "method:take_damage"), "{target}.take_damage({amount})"],
		["a hidden function is not offered", twin.has("method:internal_step"), false],
	])


## A shipped pack is read as it always was: its template-less function has no template, and bakes to the
## owned instance at apply time exactly as before.
static func _shipped_pack_unmoved() -> bool:
	var rows: Array = []
	for path: String in SHIPPED_TEMPLATELESS:
		var untouched: int = 0
		var seen: int = 0
		for definition: ACEDefinition in EventSheetACEGenerator.new().reflect_script(load(path) as Script):
			if str(definition.metadata.get("source_kind", "")) != "method" or not str(definition.metadata.get("codegen_template", "")).is_empty():
				continue
			seen += 1
			if definition.instance_backed_template().begins_with("__eventsheet_provider_"):
				untouched += 1
		rows.append(["%s has template-less functions" % path.get_file(), seen > 0, true])
		rows.append(["and every one still bakes to the owned instance", untouched, seen])
	return SUPPORT.pins("script_rows_target_test", rows)


## A row baked before this change is compiled from the template on the row, never from the registry.
static func _placed_rows_compile_the_same() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_id = "OnReady"
	for spec: Array in [
			["ScriptRowsResourceThing", "method:add", "__eventsheet_provider_ScriptRowsResourceThing.add({count})", {"count": "2"}],
			["ScriptRowsNodeThing", "method:take_damage", "__eventsheet_provider_ScriptRowsNodeThing.take_damage({amount}, {from})", {"amount": "4", "from": "null"}],
			["ScriptRowsResourceThing", "set:amount", "__eventsheet_provider_ScriptRowsResourceThing.amount = {value}", {"value": "9"}]]:
		var action: ACEAction = ACEAction.new()
		action.provider_id = str(spec[0])
		action.ace_id = str(spec[1])
		action.codegen_template = str(spec[2])
		action.params = spec[3]
		event.actions.append(action)
	sheet.events.append(event)
	return SUPPORT.pins("script_rows_target_test", [
		["rows baked on the old call compile to the same bytes as before",
			str(EventSheetCompiler.compile(sheet).get("output", "")), FileAccess.get_file_as_string(LEGACY_COMPILE)],
	])


## Editing such a row keeps the call it was placed with: re-baking from today's definition would swap the
## copy for another object.
static func _editing_keeps_the_old_call() -> bool:
	var legacy: ACEAction = ACEAction.new()
	legacy.codegen_template = "__eventsheet_provider_ScriptRowsResourceThing.add({count})"
	legacy.params = {"count": "2"}
	var edited: ACEAction = ACEAction.new()
	edited.codegen_template = "{resource}.add({count})"
	edited.params = {"resource": "null", "count": "5"}
	var apply: GDScript = load("res://addons/eventsheet/editor/dock/ace_apply.gd")
	apply._keep_legacy_template(legacy, edited)
	var fresh: ACEAction = ACEAction.new()
	fresh.codegen_template = "{resource}.add({count})"
	fresh.params = {"resource": "item", "count": "1"}
	var plain: ACEAction = ACEAction.new()
	plain.codegen_template = "{resource}.add({count})"
	apply._keep_legacy_template(plain, fresh)
	return SUPPORT.pins("script_rows_target_test", [
		["an edited legacy row keeps its call", edited.codegen_template, "__eventsheet_provider_ScriptRowsResourceThing.add({count})"],
		["and the new value is the one it was given", edited.params.get("count", ""), "5"],
		["the instance slot is left off it", edited.params.has("resource"), false],
		["a row that was never on the old call is edited as ever", [fresh.codegen_template, fresh.params.get("resource", "")], ["{resource}.add({count})", "item"]],
	])


## A row starts on the node of the open scene that wears the script, when exactly one does.
static func _starts_on_the_node_of_the_open_scene() -> bool:
	var definition: ACEDefinition = _definitions("node_thing.gd")["method:take_damage"]
	var script: Script = load(DIR + "node_thing.gd") as Script
	var apply: GDScript = load("res://addons/eventsheet/editor/dock/ace_apply.gd")
	var root: Node = Node.new()
	var none: ACEDefinition = apply.aimed_at_scene(definition, root)
	var hero: Node2D = Node2D.new()
	hero.name = "Hero"
	hero.set_script(script)
	var holder: Node = Node.new()
	holder.name = "Party"
	root.add_child(holder)
	holder.add_child(hero)
	var one: ACEDefinition = apply.aimed_at_scene(definition, root)
	var second: Node2D = Node2D.new()
	second.name = "Second"
	second.set_script(script)
	root.add_child(second)
	var two: ACEDefinition = apply.aimed_at_scene(definition, root)
	root.free()
	return SUPPORT.pins("script_rows_target_test", [
		["no node wears it: the class is the start", _param({"x": none}, "x", "target").get("default_value", ""), "$ScriptRowsNodeThing"],
		["one node wears it: the row starts on that node", _param({"x": one}, "x", "target").get("default_value", ""), "$Party/Hero"],
		["two do: the class is the start again", _param({"x": two}, "x", "target").get("default_value", ""), "$ScriptRowsNodeThing"],
		["the shared definition was never written to", _param({"x": definition}, "x", "target").get("default_value", ""), "$ScriptRowsNodeThing"],
		["only the starting node moved", (one.metadata["codegen_template"] as String), "{target}.take_damage({amount}, {from})"],
	])
