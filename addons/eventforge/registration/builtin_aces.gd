# EventForge — Built-in ACE descriptors
# Provides the minimum Core ACE surface for Phase 1.
@tool
extends RefCounted
class_name EventForgeBuiltinACEs

## Returns the minimum built-in ACE descriptor set for Phase 1.
static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# Triggers
	descriptors.append(_make_descriptor("Core", "OnReady", "On Ready", ACEDescriptor.ACEType.TRIGGER, "", "ready", [], "Run Context", "Run on ready"))
	descriptors.append(_make_descriptor("Core", "OnProcess", "Every Tick", ACEDescriptor.ACEType.TRIGGER, "", "_process", [], "Run Context", "Run every tick"))
	descriptors.append(_make_descriptor("Core", "OnPhysicsProcess", "On Physics Process", ACEDescriptor.ACEType.TRIGGER, "", "_physics_process", [], "Run Context", "Run on physics process"))
	descriptors.append(_make_descriptor("Core", "OnBodyEntered", "On Body Entered", ACEDescriptor.ACEType.TRIGGER, "", "body_entered", [_make_param("body", "Node")], "Signals / Scene", "On body entered {body}"))
	descriptors.append(_make_descriptor("Core", "OnSignal", "On Signal", ACEDescriptor.ACEType.TRIGGER, "", "", [_make_param("signal_name", "String", "eventforge_signal", "Signal Name", "Signal to listen for.")], "Signals / Scene", "On signal {signal_name}"))

	# Conditions
	descriptors.append(_make_descriptor("Core", "Always", "Always", ACEDescriptor.ACEType.CONDITION, "true", "", [], "General Conditions", "Always"))
	descriptors.append(_make_descriptor("Core", "IsOnFloor", "Is On Floor", ACEDescriptor.ACEType.CONDITION, "is_on_floor()", "", [], "General Conditions", "Is on floor"))
	descriptors.append(_make_descriptor("Core", "HasGroupMember", "Has Group Member", ACEDescriptor.ACEType.CONDITION, "is_in_group({group})", "", [_make_param("group", "String", "", "Group", "Group name to test.")], "General Conditions", "In group {group}"))
	descriptors.append(_make_descriptor("Core", "CompareVar", "Compare Variable", ACEDescriptor.ACEType.CONDITION, "{var_name} {op} {value}", "", [_make_param("var_name", "String", "var", "Variable", "Variable name to compare."), _make_param("op", "String", "==", "Operator", "Comparison operator."), _make_param("value", "String", "0", "Value", "Comparison value.")], "Variables", "{var_name} {op} {value}"))

	# Actions
	descriptors.append(_make_descriptor("Core", "SetVar", "Set Variable", ACEDescriptor.ACEType.ACTION, "{var_name} = {value}", "", [_make_param("var_name", "String", "var", "Variable", "Variable name to set."), _make_param("value", "String", "0", "Value", "Value to assign.")], "Variables", "Set variable {var_name} to {value}"))
	descriptors.append(_make_descriptor("Core", "AddVar", "Add Variable", ACEDescriptor.ACEType.ACTION, "{var_name} += {amount}", "", [_make_param("var_name", "String", "var", "Variable", "Variable name to increment."), _make_param("amount", "String", "1", "Amount", "Amount to add.")], "Variables", "Add {amount} to {var_name}"))
	descriptors.append(_make_descriptor("Core", "PrintLog", "Print Log", ACEDescriptor.ACEType.ACTION, "print({message})", "", [_make_param("message", "String", "\"TODO\"", "Message", "Message to print.")], "General Actions", "Print {message}"))
	descriptors.append(_make_descriptor("Core", "QueueFree", "Queue Free", ACEDescriptor.ACEType.ACTION, "queue_free()", "", [], "General Actions", "Queue free"))
	descriptors.append(_make_descriptor("Core", "EmitSignal", "Emit Signal", ACEDescriptor.ACEType.ACTION, "emit_signal({signal_name}{, args})", "", [_make_param("signal_name", "String", "signal", "Signal Name", "Signal to emit."), _make_param("args", "String", "", "Arguments", "Optional signal arguments.")], "Signals / Scene", "Emit signal {signal_name}"))

	# Expressions
	descriptors.append(_make_descriptor("Core", "GetVar", "Get Variable", ACEDescriptor.ACEType.EXPRESSION, "{var_name}", "", [_make_param("var_name", "String", "var", "Variable", "Variable to read.")], "Variables", "{var_name}"))
	descriptors.append(_make_descriptor("Core", "GetDelta", "Get Delta", ACEDescriptor.ACEType.EXPRESSION, "delta", "", [], "General Expressions", "delta"))

	return descriptors

## Creates an ACE descriptor instance.
static func _make_descriptor(provider_id: String, ace_id: String, display_name: String, ace_type: int, codegen_template: String, signal_name: String = "", params: Array[ACEParam] = [], category: String = "", display_text: String = "") -> ACEDescriptor:
	var descriptor: ACEDescriptor = ACEDescriptor.new()
	descriptor.provider_id = provider_id
	descriptor.ace_id = ace_id
	descriptor.display_name = display_name
	descriptor.list_name = display_name
	descriptor.display_text = display_text if not display_text.is_empty() else display_name
	descriptor.category = category
	descriptor.ace_type = ace_type
	descriptor.codegen_template = codegen_template
	descriptor.signal_name = signal_name
	descriptor.params = params
	return descriptor

## Creates an ACE parameter instance.
static func _make_param(param_id: String, type_name: String, default_value: Variant = "", display_name: String = "", description: String = "") -> ACEParam:
	var parameter: ACEParam = ACEParam.new()
	parameter.id = param_id
	parameter.name = param_id
	parameter.display_name = display_name if not display_name.is_empty() else param_id
	parameter.description = description
	parameter.desc = description
	parameter.type_name = type_name
	parameter.default_value = default_value
	parameter.initial_value = default_value
	parameter.initialValue = default_value
	return parameter
