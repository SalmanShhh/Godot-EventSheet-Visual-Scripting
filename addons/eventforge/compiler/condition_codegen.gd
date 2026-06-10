# EventForge — Condition code generation
# Emits GDScript boolean expressions for ACE conditions.
@tool
extends RefCounted
class_name ConditionCodegen

## Generates one condition expression from an ACE condition.
static func generate_condition(condition: ACECondition) -> String:
	if condition == null or not condition.enabled:
		return ""

	# A baked template (custom/addon ACEs) wins over the descriptor registry.
	var template: String = condition.codegen_template.strip_edges()
	if template.is_empty():
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
		if descriptor == null:
			return ""
		template = descriptor.codegen_template

	var params: Dictionary = condition.params if not condition.params.is_empty() else condition.parameters
	var output: String = ActionCodegen._apply_template(template, params)
	if condition.negated and not output.is_empty():
		return "not (%s)" % output
	return output
