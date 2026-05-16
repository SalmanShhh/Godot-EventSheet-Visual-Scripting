# EventForge — Action code generation
# Emits GDScript statements for ACE actions.
@tool
extends RefCounted
class_name ActionCodegen

## Generates one action statement from an ACE action.
static func generate_action(action: ACEAction) -> String:
	return str(generate_action_slice(action).get("statement", ""))

## Generates one action statement from the first translation-matrix slice.
static func generate_action_slice(action: ACEAction) -> Dictionary:
	var result: Dictionary = {
		"supported": false,
		"statement": "",
		"warning": ""
	}
	if action == null or not action.enabled:
		result["supported"] = true
		return result

	var params: Dictionary = _get_params(action)
	match action.ace_id:
		"SetVar":
			var var_name: String = str(params.get("var_name", "")).strip_edges()
			var value: String = str(params.get("value", "")).strip_edges()
			if var_name.is_empty() or value.is_empty():
				result["warning"] = "Action Core::SetVar has invalid parameters and was skipped"
				return result
			result["supported"] = true
			result["statement"] = "%s = %s" % [var_name, value]
			return result
		"PrintLog":
			var message: String = str(params.get("message", "")).strip_edges()
			if message.is_empty():
				result["warning"] = "Action Core::PrintLog has invalid parameters and was skipped"
				return result
			result["supported"] = true
			result["statement"] = "print(%s)" % message
			return result
		_:
			result["warning"] = "Unsupported action in first translation-matrix slice: %s::%s" % [
				action.provider_id,
				action.ace_id
			]
			return result

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
