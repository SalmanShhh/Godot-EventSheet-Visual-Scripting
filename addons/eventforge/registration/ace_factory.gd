# EventForge — Shared descriptor factory for builtin/module ACE vocabularies.
#
# THE MODULE CONTRACT (see modules/): each vocabulary lives in its own file exposing
# `static func get_descriptors() -> Array[ACEDescriptor]`, built through this factory.
# EventForgeBuiltinACEs concatenates the modules. Why this shape:
#   - each C3-equivalent "addon" (Audio, Keyboard, …) is one readable, documented file;
#   - a module can ship standalone (copy the file + factory into another project) or be
#     curated into packs without dragging the whole builtin list along;
#   - the compatibility covenant stays easy to audit: ace_ids and templates are grep-able
#     per module, and moving a descriptor between files never changes its identity.
@tool
extends RefCounted
class_name EventForgeACEFactory

## Builds a descriptor. Mirrors EventForgeBuiltinACEs._make_descriptor exactly (incl. the
## legacy alias fields) — ace_ids, templates and display text are API (compatibility
## covenant); the factory only changes where descriptors are AUTHORED, never what they bake.
static func make_descriptor(provider_id: String, ace_id: String, display_name: String, ace_type: int, codegen_template: String, signal_name: String = "", params: Array[ACEParam] = [], category: String = "", display_text: String = "", node_type: String = "") -> ACEDescriptor:
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
	descriptor.node_type = node_type
	descriptor.nodeType = node_type
	return descriptor

## Builds a parameter. `hint` selects the dialog field ("expression" = ƒx button,
## "key_capture" = press-a-key, "audio_path" = path + preview ▶, "color", …);
## `options` makes it a dropdown. Mirrors EventForgeBuiltinACEs._make_param exactly.
static func make_param(param_id: String, type_name: String, default_value: Variant = "", display_name: String = "", description: String = "", hint: String = "", options: Array[String] = []) -> ACEParam:
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
	parameter.hint = hint
	parameter.options = options.duplicate()
	return parameter
