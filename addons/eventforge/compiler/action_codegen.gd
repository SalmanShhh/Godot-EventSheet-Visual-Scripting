# EventForge — Action code generation
# Emits GDScript statements for ACE actions.
@tool
extends RefCounted
class_name ActionCodegen

## Generates one action statement from an ACE action.
static func generate_action(action: ACEAction) -> String:
	if action == null or not action.enabled:
		return ""

	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(action.provider_id, action.ace_id)
	if descriptor == null:
		return ""

	return _apply_template(descriptor.codegen_template, _get_params(action))

## Applies `{param}` and optional `{, param}` substitutions.
static func _apply_template(template: String, params: Dictionary) -> String:
	var output: String = template
	var keys: Array = params.keys()
	keys.sort()

	for key: Variant in keys:
		var key_name: String = str(key)
		var value: String = str(params[key])
		var optional_token: String = "{, %s}" % key_name
		if output.contains(optional_token):
			if value.is_empty():
				output = output.replace(optional_token, "")
			else:
				output = output.replace(optional_token, ", %s" % value)
		output = output.replace("{%s}" % key_name, value)

	while output.contains("{,"):
		var start: int = output.find("{,")
		var finish: int = output.find("}", start)
		if finish == -1:
			break
		output = output.substr(0, start) + output.substr(finish + 1)

	return output

## Returns action params while preserving backwards compatibility with the first PR scaffold.
static func _get_params(action: ACEAction) -> Dictionary:
	if not action.params.is_empty():
		return action.params
	return action.parameters
