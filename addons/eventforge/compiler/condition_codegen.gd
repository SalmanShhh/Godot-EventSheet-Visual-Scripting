# EventForge — Condition code generation
@tool
extends RefCounted
class_name ConditionCodegen

## Generates one condition expression from an ACE condition.
static func generate_condition(condition: ACECondition) -> String:
if condition == null or not condition.enabled:
return ""
var descriptor: ACEDescriptor = ACERegistry.find_descriptor(condition.provider_id, condition.ace_id)
if descriptor == null:
return ""
var output: String = ActionCodegen._apply_template(descriptor.codegen_template, condition.parameters)
if condition.negated and not output.is_empty():
return "not (%s)" % output
return output
