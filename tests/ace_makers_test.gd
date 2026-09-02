# EventForge - THE MAKERS BUILD THE SAME DESCRIPTOR THE LONG FORM DOES.
#
# `F.act` / `F.cond` / `F.expr` / `F.trig` and the descriptor's chained `.param(...)` family are a
# terser way to WRITE a verb, and nothing else: they compile to `make_descriptor` and `make_param`,
# which stay forever because every shipped ace_id, template and parameter default is a compatibility
# promise. This test is the proof of that claim, and it is deliberately paranoid about the shape of
# the proof:
#
#   - every pin builds ONE verb BOTH WAYS and compares them FIELD BY FIELD, walking the property
#     list rather than naming the fields, so a field added to ACEDescriptor tomorrow is compared the
#     day it exists instead of quietly falling outside the test;
#   - the parameters are compared the same way, including the legacy aliases (`name`, `desc`,
#     `initial_value`, `initialValue`) that the dialogs and the importer still read - a maker that
#     filled `id` and forgot `name` would look right in a picker and lose the row on save;
#   - the DEFAULT VALUE is compared with its own type, not through `str()`, because a default stored
#     as the float 1.0 where the long form stored the text "1.0" prints identically in every dump and
#     still changes what a dialog hands the compiler.
#
# The verbs pinned here are shapes, not vocabulary: an action carrying help and hinted fields, a
# condition with a host class and a loop, an expression with no fields at all, a trigger hanging off
# a signal, and the three parameter kinds the chain spells (typed, fixed dropdown, suggesting).
@tool
class_name ACEMakersTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const F := preload("res://addons/eventforge/registration/ace_factory.gd")
const NAME := "ace_makers_test"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _pin_action() and all_passed
	all_passed = _pin_condition() and all_passed
	all_passed = _pin_expression() and all_passed
	all_passed = _pin_trigger() and all_passed
	all_passed = _pin_parameter_kinds() and all_passed
	all_passed = _pin_inferred_types() and all_passed
	return all_passed


## An ACTION with help and two hinted fields - the everyday shape, and the one most of the builtin
## vocabulary is written in.
static func _pin_action() -> bool:
	var long_form: ACEDescriptor = F.make_descriptor("Core", "SetNodeName", "Set Node Name", ACEDescriptor.ACEType.ACTION, "{target}.name = {name}", "", [
		F.make_param("target", "String", "self", "Target", "Node to rename.", "expression"),
		F.make_param("name", "String", "\"Renamed\"", "Name", "New node name.", "expression")
	], "Nodes", "rename [i]{target}[/i] to [b]{name}[/b]").described("Renames a node at runtime, handy for tracking or finding it later.")
	var terse: ACEDescriptor = F.act("SetNodeName", "Set Node Name", "{target}.name = {name}", "Nodes", "rename [i]{target}[/i] to [b]{name}[/b]", "Renames a node at runtime, handy for tracking or finding it later.").param("target", "self", "Target", "Node to rename.", "expression").param("name", "\"Renamed\"", "Name", "New node name.", "expression")
	return _same_descriptor("an action with help and two hinted fields", long_form, terse)


## A CONDITION carrying a HOST CLASS and a loop declaration - the chained calls that survive the
## terser form unchanged.
static func _pin_condition() -> bool:
	var long_form: ACEDescriptor = F.make_descriptor("Core", "ForEachChildOf", "For Each Child", ACEDescriptor.ACEType.CONDITION, "{target}.get_children()", "", [
		F.make_param("target", "String", "self", "Of", "The node whose children the actions run once for.", "scene_node")
	], "Nodes: Hierarchy", "for each child of [i]{target}[/i]", "Node2D").described("Runs this event's actions once per direct child of a node.").looping("child")
	var terse: ACEDescriptor = F.cond("ForEachChildOf", "For Each Child", "{target}.get_children()", "Nodes: Hierarchy", "for each child of [i]{target}[/i]", "Runs this event's actions once per direct child of a node.", "Node2D").param("target", "self", "Of", "The node whose children the actions run once for.", "scene_node").looping("child")
	return _same_descriptor("a condition with a host class and a loop", long_form, terse)


## An EXPRESSION with no fields at all and no reads-as sentence, so the blank-falls-back-to-the-label
## rule is pinned on both routes rather than assumed to be the same rule.
static func _pin_expression() -> bool:
	var long_form: ACEDescriptor = F.make_descriptor("Core", "GetSceneRoot", "Current Scene Root", ACEDescriptor.ACEType.EXPRESSION, "get_tree().current_scene", "", [], "Nodes").described("Returns the root node of the currently running scene.")
	var terse: ACEDescriptor = F.expr("GetSceneRoot", "Current Scene Root", "get_tree().current_scene", "Nodes", "", "Returns the root node of the currently running scene.")
	return _same_descriptor("an expression with no fields and no sentence", long_form, terse)


## A TRIGGER hanging off a Godot signal, carrying the payload parameter the engine fills in. The
## maker takes the signal where the other three take a template, which is the one place the four
## differ in shape.
static func _pin_trigger() -> bool:
	var long_form: ACEDescriptor = F.make_descriptor("Core", "OnFirstOverlap", "On First Overlap", ACEDescriptor.ACEType.TRIGGER, "", "body_entered", [
		F.make_param("body", "Node", "", "", "The body that arrived.")
	], "Collisions", "On first overlap", "Area2D").described("Runs when something moves into an empty area.").featured()
	var terse: ACEDescriptor = F.trig("OnFirstOverlap", "On First Overlap", "body_entered", "Collisions", "On first overlap", "Runs when something moves into an empty area.", "Area2D").param_built(F.make_param("body", "Node", "", "", "The body that arrived.")).featured()
	return _same_descriptor("a trigger with a signal and a payload field", long_form, terse)


## The three parameter kinds the chain spells beside the plain one: a type named outright, a fixed
## dropdown of key-and-label choices, and an editable combo that suggests.
static func _pin_parameter_kinds() -> bool:
	var long_form: ACEDescriptor = F.make_descriptor("Core", "PinnedKinds", "Pinned Kinds", ACEDescriptor.ACEType.ACTION, "{where}.set_level({level}, {action})", "", [
		F.make_param("where", "Node", "self", "Where", "The node it happens on.", "scene_node"),
		F.make_param("level", "String", "push_warning", "Level", "How loud it is.", "", [{"key": "push_warning", "label": "Warning"}, {"key": "push_error", "label": "Error"}]),
		F.make_param("action", "String", "\"jump\"", "Action", "The input action.", "input_action", [], ["\"ui_accept\"", "\"jump\""] as Array[String])
	], "Debug", "say {level} on {where}").described("A shape, not a verb.")
	var terse: ACEDescriptor = F.act("PinnedKinds", "Pinned Kinds", "{where}.set_level({level}, {action})", "Debug", "say {level} on {where}", "A shape, not a verb.").param_typed("Node", "where", "self", "Where", "The node it happens on.", "scene_node").param_choice("level", "push_warning", "Level", "How loud it is.", [{"key": "push_warning", "label": "Warning"}, {"key": "push_error", "label": "Error"}]).param_suggesting("action", "\"jump\"", "Action", "The input action.", ["\"ui_accept\"", "\"jump\""] as Array[String], "input_action")
	return _same_descriptor("the typed, dropdown and suggesting parameter kinds", long_form, terse)


## What a default says its own type is, pinned as VALUES: text is a String field - the type every
## GDScript-expression parameter is in, because an expression's default IS its text - and the three
## literal kinds name themselves. This is the one rule `.param(...)` applies that `.param_typed(...)`
## states out loud.
static func _pin_inferred_types() -> bool:
	var descriptor: ACEDescriptor = F.act("Inferred", "Inferred", "noop()").param("text", "\"hello\"").param("flag", true).param("count", 3).param("amount", 1.5).param("expression_default", "Vector2.ZERO")
	var types: Array[String] = []
	for parameter: ACEParam in descriptor.params:
		types.append(parameter.type_name)
	return SUPPORT.pins(NAME, [
		["a default's own type names the field", types, ["String", "bool", "int", "float", "String"] as Array[String]],
		["a default is stored exactly as it was written", descriptor.params[3].default_value, 1.5],
	])


## Two descriptors compared FIELD BY FIELD off the property list, then parameter by parameter the
## same way. Returns true when nothing differs; prints one line per field that does.
static func _same_descriptor(label: String, long_form: ACEDescriptor, terse: ACEDescriptor) -> bool:
	var differences: PackedStringArray = _property_differences(long_form, terse, ["params"])
	if long_form.params.size() != terse.params.size():
		differences.append("params.size(): %d vs %d" % [long_form.params.size(), terse.params.size()])
	else:
		for index: int in range(long_form.params.size()):
			for difference: String in _property_differences(long_form.params[index], terse.params[index], []):
				differences.append("params[%d].%s" % [index, difference])
	for difference: String in differences:
		print("  makers: %s -> %s" % [label, difference])
	return SUPPORT.check(NAME, "%s builds identically both ways" % label, differences.size(), 0)


## Every storage property of two resources of one class, compared by VALUE and with its own type -
## `1.0` and `"1.0"` are a difference here, which is the whole point. `skipped` names the properties
## the caller compares itself.
static func _property_differences(left: Object, right: Object, skipped: Array[String]) -> PackedStringArray:
	var differences: PackedStringArray = PackedStringArray()
	for info: Dictionary in left.get_property_list():
		var property: String = str(info.get("name", ""))
		if skipped.has(property) or int(info.get("usage", 0)) & PROPERTY_USAGE_STORAGE == 0:
			continue
		var mine: Variant = left.get(property)
		var theirs: Variant = right.get(property)
		if typeof(mine) != typeof(theirs) or mine != theirs:
			differences.append("%s: %s vs %s" % [property, var_to_str(mine), var_to_str(theirs)])
	return differences
