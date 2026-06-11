# EventForge — Built-in ACE registry
# Concatenates the per-vocabulary modules (registration/modules/) IN ORDER — order is
# part of stability (the lifter tries reverse templates in registry order). See
# ace_factory.gd for the module contract; ace_ids/templates are API (compatibility
# covenant: hide with @ace_hidden, never rename).
@tool
extends RefCounted
class_name EventForgeBuiltinACEs

const COMPARISON_OPERATORS: Array[String] = EventForgeACEFactory.COMPARISON_OPERATORS

## Every built-in descriptor, module by module.
static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	descriptors.append_array(EventForgeAudioACEs.get_descriptors())
	descriptors.append_array(EventForgeCoreACEs.get_descriptors())
	descriptors.append_array(EventForgeSystemACEs.get_descriptors())
	descriptors.append_array(EventForgeDeviceACEs.get_descriptors())
	descriptors.append_array(EventForge3DACEs.get_descriptors())
	descriptors.append_array(EventForgeCollectionACEs.get_descriptors())
	return descriptors

# ── Legacy helper API (kept for external callers; the modules use the factory) ──

static func _input_action_options() -> Array[String]:
	return EventForgeACEFactory.input_action_options()

static func _default_input_action() -> String:
	return EventForgeACEFactory.default_input_action()

static func _make_descriptor(provider_id: String, ace_id: String, display_name: String, ace_type: int, codegen_template: String, signal_name: String = "", params: Array[ACEParam] = [], category: String = "", display_text: String = "", node_type: String = "") -> ACEDescriptor:
	return EventForgeACEFactory.make_descriptor(provider_id, ace_id, display_name, ace_type, codegen_template, signal_name, params, category, display_text, node_type)

static func _make_param(param_id: String, type_name: String, default_value: Variant = "", display_name: String = "", description: String = "", hint: String = "", options: Array[String] = []) -> ACEParam:
	return EventForgeACEFactory.make_param(param_id, type_name, default_value, display_name, description, hint, options)
