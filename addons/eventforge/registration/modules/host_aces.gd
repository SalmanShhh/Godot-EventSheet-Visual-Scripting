# EventForge module - Host (behaviour-only): the parent node a behaviour is attached to.
#
# A behaviour sheet binds to its parent as `host` - the compiler synthesizes `var host: <Host> = null`
# plus the _enter_tree that assigns it. These two ACEs make that binding first-class, pickable vocabulary:
# read the host node, and guard access to it. They emit the LITERAL `host` var, so they are BEHAVIOUR-ONLY
# by design (a plain event sheet has no `host`); the picker hides them off a non-behaviour sheet via
# EventSheetACEPicker.host_ace_hidden (fed set_behavior_mode_provider by the dock). ace_ids/templates are
# API once shipped. Module contract: see ace_factory.gd.
@tool
class_name EventForgeHostACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Behavior"


static func get_descriptors() -> Array[ACEDescriptor]:
	var d: Array[ACEDescriptor] = []
	d.append(F.make_descriptor("Core", "BehaviorHost", "Host", ACEDescriptor.ACEType.EXPRESSION, "host", "", [], CAT, "host")
		.described("The parent node this behavior is attached to (its host) - the object your behavior reads and acts on."))
	d.append(F.make_descriptor("Core", "BehaviorHostValid", "Host Is Valid", ACEDescriptor.ACEType.CONDITION, "is_instance_valid(host)", "", [], CAT, "host is valid")
		.described("True when this behavior has a live host - the parent it acts on still exists. Guard host access with it before the host is bound or after it is freed."))
	return d


static func section_descriptions() -> Dictionary:
	return {CAT: "The parent node a behavior is attached to (its host). Read it or guard it - a behavior sheet binds the host automatically as it enters the tree. These read the literal host, so they belong to behavior sheets only."}
