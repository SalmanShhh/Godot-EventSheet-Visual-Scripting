# EventForge - Condition code generation
# Emits GDScript boolean expressions for ACE conditions.
@tool
class_name ConditionCodegen
extends RefCounted


## Generates one condition expression from an ACE condition.
static func generate_condition(condition: ACECondition, host_default: String = "") -> String:
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
	# Fold the behavior-mode host accessor into {host.}/{host} templates (e.g. {host.}is_on_floor()
	# -> host.is_on_floor()) BEFORE the negation wrap, so a negated host condition becomes
	# `not (host.is_on_floor())`. Empty host_default leaves the call bare (byte-stable, non-behavior).
	if not host_default.strip_edges().is_empty() and (template.contains("{host.}") or template.contains("{host}")) and not params.has("host"):
		params = params.duplicate()
		params["host"] = host_default
	var output: String = ActionCodegen._apply_template(template, params)
	# Stateful conditions (Every X Seconds, Trigger Once) have no meaningful inverse: their state must
	# advance exactly when the term passes, so a `not (...)` header would fire it in the wrong branch
	# (the compiler also warns). Keyed on the member - Trigger Once has no on-true rebase, but every
	# stateful condition owns a member declaration.
	if condition.negated and condition.member_declaration.is_empty() and not output.is_empty():
		return "not (%s)" % output
	return output
