# EventForge — Built-in ACE descriptors
# Provides the minimum Core ACE surface for Phase 1.
@tool
extends RefCounted
class_name EventForgeBuiltinACEs

## Returns the minimum built-in ACE descriptor set for Phase 1.
static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# Triggers
	descriptors.append(_make_descriptor("Core", "OnReady", "On Ready", ACEDescriptor.ACEType.TRIGGER, "", "ready", [], "System"))
	descriptors.append(_make_descriptor("Core", "OnProcess", "On Process", ACEDescriptor.ACEType.TRIGGER, "", "_process", [], "System"))
	descriptors.append(_make_descriptor("Core", "OnPhysicsProcess", "On Physics Process", ACEDescriptor.ACEType.TRIGGER, "", "_physics_process", [], "System"))
	descriptors.append(_make_descriptor("Core", "OnBodyEntered", "On Body Entered", ACEDescriptor.ACEType.TRIGGER, "", "body_entered", [_make_param("body", "Node")], "Signals"))
	descriptors.append(_make_descriptor("Core", "OnSignal", "On Signal", ACEDescriptor.ACEType.TRIGGER, "", "", [_make_param("target_node", "NodePath"), _make_param("signal_name", "String")], "Signals"))

	# Conditions
	descriptors.append(_make_descriptor("Core", "CompareVar", "Compare Variable", ACEDescriptor.ACEType.CONDITION, "{var_name} {op} {value}", "", [_make_param("var_name", "String"), _make_param("op", "String"), _make_param("value", "String")], "Variables"))
	descriptors.append(_make_descriptor("Core", "IsOnFloor", "Is On Floor", ACEDescriptor.ACEType.CONDITION, "is_on_floor()", "", [], "Node"))
	descriptors.append(_make_descriptor("Core", "HasGroupMember", "Has Group Member", ACEDescriptor.ACEType.CONDITION, "is_in_group({group})", "", [_make_param("group", "String")], "Node"))

	# Actions
	descriptors.append(_make_descriptor("Core", "SetVar", "Set Variable", ACEDescriptor.ACEType.ACTION, "{var_name} = {value}", "", [_make_param("var_name", "String"), _make_param("value", "String")], "Variables"))
	descriptors.append(_make_descriptor("Core", "AddVar", "Add Variable", ACEDescriptor.ACEType.ACTION, "{var_name} += {amount}", "", [_make_param("var_name", "String"), _make_param("amount", "String")], "Variables"))
	descriptors.append(_make_descriptor("Core", "PrintLog", "Print Log", ACEDescriptor.ACEType.ACTION, "print({message})", "", [_make_param("message", "String")], "Debug"))
	descriptors.append(_make_descriptor("Core", "QueueFree", "Queue Free", ACEDescriptor.ACEType.ACTION, "queue_free()", "", [], "Node"))
	descriptors.append(_make_descriptor("Core", "EmitSignal", "Emit Signal", ACEDescriptor.ACEType.ACTION, "emit_signal({signal_name}{, args})", "", [_make_param("signal_name", "String"), _make_param("args", "String", "")], "Node"))

	# Expressions
	descriptors.append(_make_descriptor("Core", "GetVar", "Get Variable", ACEDescriptor.ACEType.EXPRESSION, "{var_name}", "", [_make_param("var_name", "String")], "Variables"))
	descriptors.append(_make_descriptor("Core", "GetDelta", "Get Delta", ACEDescriptor.ACEType.EXPRESSION, "delta", "", [], "System"))

	return descriptors

## Creates an ACE descriptor instance.
static func _make_descriptor(provider_id: String, ace_id: String, display_name: String, ace_type: int, codegen_template: String, signal_name: String = "", params: Array[ACEParam] = [], category: String = "") -> ACEDescriptor:
	var descriptor: ACEDescriptor = ACEDescriptor.new()
	descriptor.provider_id = provider_id
	descriptor.ace_id = ace_id
	descriptor.display_name = display_name
	descriptor.ace_type = ace_type
	descriptor.category = category
	descriptor.codegen_template = codegen_template
	descriptor.signal_name = signal_name
	descriptor.params = params
	return descriptor

## Creates an ACE parameter instance.
static func _make_param(param_id: String, type_name: String, default_value: Variant = "") -> ACEParam:
	var parameter: ACEParam = ACEParam.new()
	parameter.id = param_id
	parameter.name = param_id
	parameter.type_name = type_name
	parameter.default_value = default_value
	return parameter
