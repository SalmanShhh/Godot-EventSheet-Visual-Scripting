# EventForge — Runtime bridge autoload
# Runtime-safe provider registry for ACE descriptors.
@tool
extends Node
class_name EventForgeBridgeRuntime

signal providers_changed

var _providers: Dictionary = {}

## Registers a provider and its descriptors.
func register_provider(provider: Object, descriptors: Array) -> void:
	if provider == null:
		push_warning("[EventForgeBridge] register_provider received null provider")
		return

	var provider_id: String = ""
	if provider.has_method("get_provider_id"):
		provider_id = str(provider.call("get_provider_id"))
	else:
		provider_id = str(provider.get("provider_id"))

	if provider_id.is_empty():
		provider_id = str(provider.get_instance_id())

	_providers[provider_id] = descriptors.duplicate()
	emit_signal("providers_changed")

## Unregisters a provider by ID.
func unregister_provider(provider_id: String) -> void:
	if _providers.erase(provider_id):
		emit_signal("providers_changed")

## Returns all descriptors currently registered by all providers.
func get_all_descriptors() -> Array:
	var output: Array = []
	for provider_id: Variant in _providers.keys():
		var entries: Array = _providers.get(provider_id, [])
		for entry: Variant in entries:
			output.append(entry)
	return output

## Returns descriptors filtered by ACE type.
func get_descriptors_by_type(ace_type: int) -> Array:
	var output: Array = []
	for descriptor: Variant in get_all_descriptors():
		if descriptor is ACEDescriptor and descriptor.ace_type == ace_type:
			output.append(descriptor)
	return output

## Registers a script provider path (Phase 3 placeholder).
func register_script_as_provider(script_path: String) -> void:
	push_warning("[EventForgeBridge] register_script_as_provider not yet implemented (Phase 3): %s" % script_path)
