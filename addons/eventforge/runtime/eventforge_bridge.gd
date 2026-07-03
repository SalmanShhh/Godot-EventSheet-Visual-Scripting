# EventForge — Runtime bridge autoload
# Runtime-safe provider registry for ACE descriptors.
@tool
class_name EventForgeBridgeRuntime
extends Node

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

# Script paths registered as ACE providers from code (other plugins, tool scripts, tests).
# Static so registration works with or without the autoload instance; the editor dock
# merges these with the res://eventsheet_addons/ scan. NOTE: this is an EDITOR vocabulary
# API — exported games never need the bridge, because generated code is plain GDScript
# (instance-backed addon ACEs own a direct instance of the addon class).
static var _registered_provider_scripts: PackedStringArray = PackedStringArray()


## Registers a GDScript file as an ACE provider, exactly as if it lived in
## res://eventsheet_addons/ (class_name = provider name, @ace_* annotations honored).
func register_script_as_provider(script_path: String) -> void:
	register_provider_script(script_path)
	emit_signal("providers_changed")


## Registers a Custom Block kind from another plugin/tool in code - the sibling of
## register_script_as_provider for row kinds instead of ACEs. The instance registers
## immediately (duplicate kind_ids keep the first, exactly like the folder scan).
func register_block_kind(kind: EventSheetBlockKind) -> void:
	EventSheetBlockRegistry.register_kind(kind)
	emit_signal("providers_changed")


static func register_provider_script(script_path: String) -> void:
	var resolved: String = script_path.strip_edges()
	if resolved.is_empty() or _registered_provider_scripts.has(resolved):
		return
	_registered_provider_scripts.append(resolved)


static func unregister_provider_script(script_path: String) -> void:
	var index: int = _registered_provider_scripts.find(script_path.strip_edges())
	if index >= 0:
		_registered_provider_scripts.remove_at(index)


static func get_registered_provider_scripts() -> PackedStringArray:
	return _registered_provider_scripts.duplicate()
