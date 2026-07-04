@tool
class_name EventSheetACEAnnotationStub
extends RefCounted

## Builds copy-ready provider-authoring stubs from an existing ACEDefinition, so an
## author can learn either dialect by example: right-click any ACE in the picker,
## paste the stub into a provider script, and edit. Two flavors: the ## @ace_*
## comment dialect and the typed _eventforge_register registrar.

## Widget-hint string -> EventForgeRegistrar constant name, for readable registrar stubs.
const HINT_CONSTANTS := {
	"expression": "EXPRESSION",
	"variable_reference": "VARIABLE",
	"color": "COLOR",
	"key_capture": "KEY_CAPTURE",
	"audio_path": "AUDIO_PATH",
	"scene_path": "SCENE_PATH",
	"animation_reference": "ANIMATION",
	"signal_reference": "SIGNAL_REFERENCE",
	"method_reference": "METHOD_REFERENCE",
	"property_reference": "PROPERTY_REFERENCE"
}


static func comment_stub(definition: ACEDefinition) -> String:
	if definition == null:
		return ""
	var lines: Array[String] = []
	if not definition.description.is_empty():
		lines.append("## %s" % definition.description)
	lines.append("## @ace_%s" % _type_keyword(definition.ace_type))
	if not definition.display_name.is_empty():
		lines.append("## @ace_name(\"%s\")" % definition.display_name)
	if not definition.category.is_empty():
		lines.append("## @ace_category(\"%s\")" % definition.category)
	var codegen_template: String = str(definition.metadata.get("codegen_template", ""))
	if not codegen_template.is_empty():
		lines.append("## @ace_codegen_template(\"%s\")" % codegen_template.replace("\"", "\\\""))
	for parameter in _dialog_parameters(definition):
		var spec_parts: Array[String] = []
		var hint_value: String = str(parameter.get("hint", ""))
		if not hint_value.is_empty():
			spec_parts.append("hint: %s" % hint_value)
		var option_keys: Array = _option_keys(parameter)
		if not option_keys.is_empty():
			spec_parts.append("options: %s" % "|".join(PackedStringArray(option_keys)))
		if not spec_parts.is_empty():
			lines.append("## @ace_param(%s, %s)" % [str(parameter.get("id", "")), ", ".join(spec_parts)])
	lines.append(_member_line(definition))
	return "\n".join(lines)


static func registrar_stub(definition: ACEDefinition) -> String:
	if definition == null:
		return ""
	var lines: Array[String] = []
	lines.append("static func _eventforge_register(reg: EventForgeRegistrar) -> void:")
	var chain: Array[String] = ["\treg.%s(\"%s\")" % [_type_keyword(definition.ace_type), _member_name(definition)]]
	if not definition.display_name.is_empty():
		chain.append(".name(\"%s\")" % definition.display_name)
	if not definition.category.is_empty():
		chain.append(".category(\"%s\")" % definition.category)
	if not definition.description.is_empty():
		chain.append(".description(\"%s\")" % definition.description.replace("\"", "\\\""))
	var codegen_template: String = str(definition.metadata.get("codegen_template", ""))
	if not codegen_template.is_empty():
		chain.append(".template(\"%s\")" % codegen_template.replace("\"", "\\\""))
	for parameter in _dialog_parameters(definition):
		var spec_parts: Array[String] = []
		var hint_value: String = str(parameter.get("hint", ""))
		if not hint_value.is_empty():
			if HINT_CONSTANTS.has(hint_value):
				spec_parts.append("\"hint\": EventForgeRegistrar.%s" % HINT_CONSTANTS[hint_value])
			else:
				spec_parts.append("\"hint\": \"%s\"" % hint_value)
		var option_keys: Array = _option_keys(parameter)
		if not option_keys.is_empty():
			var quoted: Array[String] = []
			for option_key in option_keys:
				quoted.append("\"%s\"" % str(option_key))
			spec_parts.append("\"options\": [%s]" % ", ".join(quoted))
		if not spec_parts.is_empty():
			chain.append(".param(\"%s\", {%s})" % [str(parameter.get("id", "")), ", ".join(spec_parts)])
	lines.append(" \\\n\t\t".join(chain))
	return "\n".join(lines)


static func _type_keyword(ace_type: int) -> String:
	match ace_type:
		ACEDefinition.ACEType.CONDITION:
			return "condition"
		ACEDefinition.ACEType.EXPRESSION:
			return "expression"
		ACEDefinition.ACEType.TRIGGER:
			return "trigger"
		_:
			return "action"


## The member declaration under the annotations: a signal for triggers, a typed
## func skeleton otherwise (params from the definition, return type from the kind).
static func _member_line(definition: ACEDefinition) -> String:
	var member_name: String = _member_name(definition)
	if definition.ace_type == ACEDefinition.ACEType.TRIGGER:
		var signal_args: Array[String] = []
		for parameter in _dialog_parameters(definition):
			signal_args.append(_typed_param(parameter))
		if signal_args.is_empty():
			return "signal %s" % member_name
		return "signal %s(%s)" % [member_name, ", ".join(signal_args)]
	var func_args: Array[String] = []
	for parameter in _dialog_parameters(definition):
		func_args.append(_typed_param(parameter))
	var return_text: String = "void"
	if definition.ace_type == ACEDefinition.ACEType.CONDITION:
		return_text = "bool"
	elif definition.ace_type == ACEDefinition.ACEType.EXPRESSION:
		return_text = "Variant"
	return "func %s(%s) -> %s:\n\tpass" % [member_name, ", ".join(func_args), return_text]


static func _typed_param(parameter: Dictionary) -> String:
	var parameter_name: String = str(parameter.get("id", "value"))
	var parameter_type: int = int(parameter.get("type", TYPE_NIL))
	if parameter_type == TYPE_NIL or parameter_type == TYPE_MAX:
		return parameter_name
	return "%s: %s" % [parameter_name, type_string(parameter_type)]


## Snake-case member name from the definition id ("method:heal" -> heal, "AddVar" -> add_var).
static func _member_name(definition: ACEDefinition) -> String:
	var raw_id: String = definition.id
	var colon_index: int = raw_id.rfind(":")
	if colon_index != -1:
		raw_id = raw_id.substr(colon_index + 1)
	return raw_id.to_snake_case()


## Parameters the params dialog would show: the injected optional "target" is
## plumbing, not vocabulary, so stubs skip it.
static func _dialog_parameters(definition: ACEDefinition) -> Array:
	var output: Array = []
	for parameter in definition.parameters:
		if parameter is Dictionary and str((parameter as Dictionary).get("id", "")) != "target":
			output.append(parameter)
	return output


static func _option_keys(parameter: Dictionary) -> Array:
	var output: Array = []
	for option_entry in parameter.get("options", []):
		if option_entry is Dictionary:
			output.append(str((option_entry as Dictionary).get("key", "")))
	return output
