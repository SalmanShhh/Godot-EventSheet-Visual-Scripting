# EventForge — ACE registry
# Combines built-in ACE descriptors with runtime registered providers.
@tool
extends RefCounted
class_name ACERegistry

## Returns built-in descriptors.
static func get_builtin_descriptors() -> Array[ACEDescriptor]:
	return EventForgeBuiltinACEs.get_descriptors()

## Returns descriptors for a provider including built-ins and runtime descriptors.
static func get_provider_descriptors(provider_id: String) -> Array[ACEDescriptor]:
	var output: Array[ACEDescriptor] = []

	for descriptor: ACEDescriptor in get_builtin_descriptors():
		if descriptor.provider_id == provider_id:
			output.append(descriptor)

	var bridge: Node = _get_bridge()
	if bridge != null and bridge.has_method("get_all_descriptors"):
		for descriptor: Variant in bridge.call("get_all_descriptors"):
			if descriptor is ACEDescriptor and descriptor.provider_id == provider_id:
				output.append(descriptor)

	return output

## Finds a descriptor by provider and ACE ID.
static func find_descriptor(provider_id: String, ace_id: String) -> ACEDescriptor:
	for descriptor: ACEDescriptor in get_provider_descriptors(provider_id):
		if descriptor.ace_id == ace_id:
			return descriptor
	return null

## Fetches the EventForgeBridge autoload if available.
static func _get_bridge() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop
		var root: Node = tree.root
		if root != null and root.has_node("EventForgeBridge"):
			return root.get_node("EventForgeBridge")
	return null
