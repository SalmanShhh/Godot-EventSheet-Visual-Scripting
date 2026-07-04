@tool
class_name EventSheetClassDBSource
extends RefCounted

## On-demand vocabulary for ANY Godot class, reflected from the running engine -
## the way GDScript itself keeps up with new node types. Given a class name, its
## own public methods become typed Actions (void), Conditions (bool), and
## Expressions (other returns), and its own signals become triggers - each emitting
## the same plain `{target.}member(...)` calls the curated vocabulary emits, so
## parity is untouched and a brand-new engine class works the day it ships.
##
## Deliberately conservative:
## - OWN members only (no inheritance walk) - the picker shows one tight
##   "All of <Class>" section per class, not 400 Node methods everywhere.
## - Members a CURATED builtin ACE already covers are filtered out by exact
##   codegen-template equality, so reflection never shadows the hand-tuned verbs.
## - Definitions are session-cached per class and IMMUTABLE after generation
##   (the ACEDefinition contract) - template changes bake into row copies at
##   apply time, never here.
## - Reflection is apply-time sugar over plain calls: lifting arbitrary calls
##   back stays as conservative as ever (the lossless covenant outranks lift
##   coverage).

## class name -> Array[ACEDefinition], shared for the whole session.
static var _cache: Dictionary = {}
## Every curated builtin codegen template, for the shadow filter (built once).
static var _curated_templates: Dictionary = {}

## Methods reflection never exposes: Object/Node plumbing that would only add noise.
const METHOD_SKIP := {
	"free": true, "notification": true, "to_string": true, "get_class": true,
	"is_class": true, "get_instance_id": true, "queue_free": true,
	"duplicate": true, "get_script": true, "set_script": true,
}


static func definitions_for_class(target_class: String) -> Array[ACEDefinition]:
	if _cache.has(target_class):
		return _cache[target_class]
	var output: Array[ACEDefinition] = []
	if not ClassDB.class_exists(target_class):
		# User `class_name` classes reflect the same way, from their script's own
		# member lists - a game's custom nodes are vocabulary too.
		var user_script: Script = _script_for_class(target_class)
		if user_script == null:
			_cache[target_class] = output
			return output
		_ensure_curated_templates()
		for method_info: Dictionary in user_script.get_script_method_list():
			var method_definition: ACEDefinition = _method_definition(target_class, method_info)
			if method_definition != null:
				output.append(method_definition)
		for signal_info: Dictionary in user_script.get_script_signal_list():
			var signal_trigger: ACEDefinition = _signal_definition(target_class, signal_info)
			if signal_trigger != null:
				output.append(signal_trigger)
		for property_info: Dictionary in user_script.get_script_property_list():
			output.append_array(_property_definitions(target_class, property_info))
		_cache[target_class] = output
		return output
	_ensure_curated_templates()
	for method_info: Dictionary in ClassDB.class_get_method_list(target_class, true):
		var definition: ACEDefinition = _method_definition(target_class, method_info)
		if definition != null:
			output.append(definition)
	for signal_info: Dictionary in ClassDB.class_get_signal_list(target_class, true):
		var trigger: ACEDefinition = _signal_definition(target_class, signal_info)
		if trigger != null:
			output.append(trigger)
	for property_info: Dictionary in ClassDB.class_get_property_list(target_class, true):
		output.append_array(_property_definitions(target_class, property_info))
	_cache[target_class] = output
	return output


## An editor-visible property reflects as a Set action + a Get expression, the
## same `{target.}prop` shapes the curated vocabulary and the helpers emit.
static func _property_definitions(target_class: String, property_info: Dictionary) -> Array[ACEDefinition]:
	var output: Array[ACEDefinition] = []
	var property_name: String = str(property_info.get("name", ""))
	var usage: int = int(property_info.get("usage", 0))
	if property_name.is_empty() or property_name.begins_with("_") or property_name.contains("/"):
		return output
	if usage & PROPERTY_USAGE_GROUP or usage & PROPERTY_USAGE_SUBGROUP or usage & PROPERTY_USAGE_CATEGORY:
		return output
	if not (usage & PROPERTY_USAGE_EDITOR):
		return output
	var set_template: String = "{target.}%s = {value}" % property_name
	if not _curated_templates.has(set_template):
		var setter: ACEDefinition = ACEDefinition.new()
		setter.provider_id = target_class
		setter.id = "property:set:%s" % property_name
		setter.ace_type = ACEDefinition.ACEType.ACTION
		setter.display_name = "Set %s" % property_name.capitalize()
		setter.category = "All of %s" % target_class
		setter.description = "Sets %s.%s - reflected from the engine." % [target_class, property_name]
		setter.parameters = [{
			"id": "value",
			"display_name": "Value",
			"description": "",
			"type": TYPE_STRING,
			"default_value": _default_literal_for(int(property_info.get("type", TYPE_NIL))),
			"hint": "expression",
			"options": [],
			"autocomplete": [],
		}]
		setter.icon = "action"
		setter.metadata = {"codegen_template": set_template, "reflected": true, "reflect_class": target_class}
		output.append(setter)
	var get_template: String = "{target.}%s" % property_name
	if not _curated_templates.has(get_template):
		var getter: ACEDefinition = ACEDefinition.new()
		getter.provider_id = target_class
		getter.id = "property:get:%s" % property_name
		getter.ace_type = ACEDefinition.ACEType.EXPRESSION
		getter.display_name = property_name.capitalize()
		getter.category = "All of %s" % target_class
		getter.description = "Reads %s.%s - reflected from the engine." % [target_class, property_name]
		getter.parameters = []
		getter.icon = "expression"
		getter.metadata = {"codegen_template": get_template, "reflected": true, "reflect_class": target_class}
		output.append(getter)
	return output


static func _method_definition(target_class: String, method_info: Dictionary) -> ACEDefinition:
	var method_name: String = str(method_info.get("name", ""))
	if method_name.is_empty() or method_name.begins_with("_") or METHOD_SKIP.has(method_name):
		return null
	var flags: int = int(method_info.get("flags", 0))
	if flags & METHOD_FLAG_VIRTUAL or flags & METHOD_FLAG_STATIC or flags & METHOD_FLAG_VARARG:
		return null
	var args: Array = method_info.get("args", [])
	var arg_names: Array[String] = []
	var parameters: Array = []
	for arg_info: Dictionary in args:
		var arg_name: String = str(arg_info.get("name", "arg"))
		arg_names.append("{%s}" % arg_name)
		parameters.append({
			"id": arg_name,
			"display_name": arg_name.capitalize(),
			"description": "",
			"type": TYPE_STRING,
			"default_value": _default_literal_for(int(arg_info.get("type", TYPE_NIL))),
			"hint": "expression",
			"options": [],
			"autocomplete": [],
		})
	var codegen: String = "{target.}%s(%s)" % [method_name, ", ".join(arg_names)]
	if _curated_templates.has(codegen):
		return null
	var return_type: int = int((method_info.get("return", {}) as Dictionary).get("type", TYPE_NIL))
	var ace_type: int = ACEDefinition.ACEType.ACTION
	if return_type == TYPE_BOOL:
		ace_type = ACEDefinition.ACEType.CONDITION
	elif return_type != TYPE_NIL:
		ace_type = ACEDefinition.ACEType.EXPRESSION
	var definition: ACEDefinition = ACEDefinition.new()
	definition.provider_id = target_class
	definition.id = "method:%s" % method_name
	definition.ace_type = ace_type
	definition.display_name = method_name.capitalize()
	definition.category = "All of %s" % target_class
	definition.description = "%s.%s - reflected from the engine; emits the plain call." % [target_class, method_name]
	definition.parameters = parameters
	definition.icon = "action" if ace_type == ACEDefinition.ACEType.ACTION else ("condition" if ace_type == ACEDefinition.ACEType.CONDITION else "expression")
	definition.metadata = {
		"codegen_template": codegen,
		"reflected": true,
		"reflect_class": target_class,
	}
	return definition


static func _signal_definition(target_class: String, signal_info: Dictionary) -> ACEDefinition:
	var signal_name: String = str(signal_info.get("name", ""))
	if signal_name.is_empty():
		return null
	# Signal args ride as typed PARAMETERS: applying the trigger derives the
	# handler signature from these (the same bake path every trigger takes).
	var parameters: Array = []
	for arg_info: Dictionary in signal_info.get("args", []):
		parameters.append({
			"id": str(arg_info.get("name", "arg")),
			"display_name": str(arg_info.get("name", "arg")).capitalize(),
			"description": "",
			"type": int(arg_info.get("type", TYPE_NIL)),
			"default_value": "",
			"hint": "",
			"options": [],
			"autocomplete": [],
		})
	var definition: ACEDefinition = ACEDefinition.new()
	definition.provider_id = target_class
	definition.id = "signal:%s" % signal_name
	definition.ace_type = ACEDefinition.ACEType.TRIGGER
	definition.display_name = "On %s" % signal_name.capitalize()
	definition.category = "All of %s" % target_class
	definition.description = "The %s.%s signal, reflected from the engine." % [target_class, signal_name]
	definition.parameters = parameters
	definition.icon = "trigger"
	definition.metadata = {
		"reflected": true,
		"reflect_class": target_class,
	}
	return definition


## Resolves a `class_name` to its script via the project's global class list.
static func _script_for_class(target_class: String) -> Script:
	for class_info: Dictionary in ProjectSettings.get_global_class_list():
		if str(class_info.get("class", "")) == target_class:
			return load(str(class_info.get("path", ""))) as Script
	return null


## The shadow filter's needle set: every curated builtin codegen template, exact.
static func _ensure_curated_templates() -> void:
	if not _curated_templates.is_empty():
		return
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		var template: String = str(descriptor.codegen_template).strip_edges()
		if not template.is_empty():
			_curated_templates[template] = true


## Reflected params are string expression slots; a type-shaped default keeps the
## generated call compiling before the user touches it.
static func _default_literal_for(arg_type: int) -> String:
	match arg_type:
		TYPE_INT:
			return "0"
		TYPE_FLOAT:
			return "0.0"
		TYPE_BOOL:
			return "false"
		TYPE_STRING, TYPE_STRING_NAME:
			return "\"\""
		TYPE_VECTOR2:
			return "Vector2.ZERO"
		TYPE_VECTOR3:
			return "Vector3.ZERO"
		TYPE_COLOR:
			return "Color.WHITE"
		_:
			return "null"
