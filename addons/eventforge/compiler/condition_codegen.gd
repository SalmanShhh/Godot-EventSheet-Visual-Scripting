# EventForge — Condition code generation
# Emits GDScript boolean expressions for ACE conditions.
@tool
extends RefCounted
class_name ConditionCodegen

## Generates one condition expression from an ACE condition.
static func generate_condition(condition: ACECondition) -> String:
	return str(generate_condition_slice(condition).get("expression", ""))

## Generates one condition expression from the first translation-matrix slice.
static func generate_condition_slice(condition: ACECondition) -> Dictionary:
	var result: Dictionary = {
		"supported": false,
		"expression": "",
		"warning": ""
	}
	if condition == null or not condition.enabled:
		result["supported"] = true
		return result

	match condition.ace_id:
		"Always":
			result["supported"] = true
			result["expression"] = "true"
		"CompareVar":
			var compare_expression: String = _generate_compare_var(_get_params(condition))
			if compare_expression.is_empty():
				result["warning"] = "Condition %s::%s has invalid parameters and was skipped" % [
					condition.provider_id,
					condition.ace_id
				]
				return result
			result["supported"] = true
			result["expression"] = compare_expression
		_:
			result["warning"] = "Unsupported condition in first translation-matrix slice: %s::%s" % [
				condition.provider_id,
				condition.ace_id
			]
			return result

	var output: String = str(result.get("expression", ""))
	if condition.negated and not output.is_empty():
		result["expression"] = "not (%s)" % output
	return result

static func _generate_compare_var(params: Dictionary) -> String:
	var var_name: String = str(params.get("var_name", "")).strip_edges()
	var operator: String = str(params.get("op", "")).strip_edges()
	var value: String = str(params.get("value", "")).strip_edges()
	if var_name.is_empty() or value.is_empty():
		return ""
	if not EventForgeBuiltinACEs.COMPARISON_OPERATORS.has(operator):
		return ""
	return "%s %s %s" % [var_name, operator, value]

## Returns condition params while preserving backwards compatibility with early Phase 1 .tres files.
static func _get_params(condition: ACECondition) -> Dictionary:
	if not condition.params.is_empty():
		return condition.params
	return condition.parameters
