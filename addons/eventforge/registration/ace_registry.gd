# EventForge — ACE registry
# Combines built-in ACE descriptors with runtime registered providers.
@tool
extends RefCounted
class_name ACERegistry

## Returns built-in descriptors.
static func get_builtin_descriptors() -> Array[ACEDescriptor]:
	return EventForgeBuiltinACEs.get_descriptors()

## Returns all descriptors from built-in and runtime providers.
static func get_all_descriptors() -> Array[ACEDescriptor]:
	var output: Array[ACEDescriptor] = []
	for descriptor: ACEDescriptor in get_builtin_descriptors():
		var normalized_builtin: ACEDescriptor = _normalize_descriptor(descriptor)
		if normalized_builtin != null:
			output.append(normalized_builtin)

	var bridge: Node = _get_bridge()
	if bridge != null and bridge.has_method("get_all_descriptors"):
		for entry: Variant in bridge.call("get_all_descriptors"):
			var normalized_runtime: ACEDescriptor = _normalize_descriptor(entry)
			if normalized_runtime != null:
				output.append(normalized_runtime)

	return output

## Returns descriptors for a provider including built-ins and runtime descriptors.
static func get_provider_descriptors(provider_id: String) -> Array[ACEDescriptor]:
	var output: Array[ACEDescriptor] = []
	for descriptor: ACEDescriptor in get_all_descriptors():
		if descriptor.provider_id == provider_id:
			output.append(descriptor)

	return output

## Finds a descriptor by provider and ACE ID.
static func find_descriptor(provider_id: String, ace_id: String) -> ACEDescriptor:
	for descriptor: ACEDescriptor in get_all_descriptors():
		if descriptor.provider_id != provider_id:
			continue
		if descriptor.ace_id == ace_id:
			return descriptor
	return null

## Public adapter for converting custom metadata dictionaries to ACEDescriptor.
static func normalize_descriptor(entry: Variant) -> ACEDescriptor:
	return _normalize_descriptor(entry)

## Fetches the EventForgeBridge autoload if available.
static func _get_bridge() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop
		var root: Node = tree.root
		if root != null and root.has_node("EventForgeBridge"):
			return root.get_node("EventForgeBridge")
	return null

## Normalizes ACEDescriptor or dictionary metadata into a descriptor.
static func _normalize_descriptor(entry: Variant) -> ACEDescriptor:
	if entry is ACEDescriptor:
		var descriptor: ACEDescriptor = entry
		_apply_descriptor_aliases(descriptor)
		return descriptor
	if not (entry is Dictionary):
		return null

	var data: Dictionary = entry
	var descriptor_from_dict: ACEDescriptor = ACEDescriptor.new()
	descriptor_from_dict.provider_id = str(data.get("provider_id", data.get("providerId", "Custom")))
	descriptor_from_dict.ace_id = str(data.get("ace_id", data.get("aceId", data.get("id", ""))))
	descriptor_from_dict.ace_type = _normalize_ace_type(data.get("ace_type", data.get("aceType", data.get("type", "action"))))
	descriptor_from_dict.display_name = str(data.get("display_name", data.get("displayName", data.get("name", ""))))
	descriptor_from_dict.list_name = str(data.get("list_name", data.get("listName", descriptor_from_dict.display_name)))
	descriptor_from_dict.listName = descriptor_from_dict.list_name
	descriptor_from_dict.display_text = str(data.get("display_text", data.get("displayText", descriptor_from_dict.list_name)))
	descriptor_from_dict.displayText = descriptor_from_dict.display_text
	descriptor_from_dict.description = str(data.get("description", data.get("desc", "")))
	descriptor_from_dict.category = str(data.get("category", "Custom ACEs"))
	descriptor_from_dict.node_type = str(data.get("node_type", data.get("nodeType", "")))
	descriptor_from_dict.nodeType = descriptor_from_dict.node_type
	descriptor_from_dict.signal_name = str(data.get("signal_name", data.get("signalName", "")))
	descriptor_from_dict.codegen_template = str(data.get("codegen_template", data.get("codegenTemplate", "")))
	descriptor_from_dict.params = _normalize_params(data.get("params", []))
	_apply_descriptor_aliases(descriptor_from_dict)
	return descriptor_from_dict

static func _normalize_ace_type(value: Variant) -> int:
	if value is int:
		return int(value)
	var text: String = str(value).to_lower()
	match text:
		"trigger", "run_context", "run-context", "run":
			return ACEDescriptor.ACEType.TRIGGER
		"condition":
			return ACEDescriptor.ACEType.CONDITION
		"expression":
			return ACEDescriptor.ACEType.EXPRESSION
		_:
			return ACEDescriptor.ACEType.ACTION

static func _normalize_params(raw_params: Variant) -> Array[ACEParam]:
	var output: Array[ACEParam] = []
	if not (raw_params is Array):
		return output
	for entry: Variant in raw_params:
		if entry is ACEParam:
			var existing: ACEParam = entry
			_apply_param_aliases(existing)
			output.append(existing)
			continue
		if not (entry is Dictionary):
			continue
		var data: Dictionary = entry
		var param: ACEParam = ACEParam.new()
		param.id = str(data.get("id", ""))
		param.name = str(data.get("name", param.id))
		param.display_name = str(data.get("display_name", data.get("displayName", param.name)))
		var raw_description: String = str(data.get("description", ""))
		var raw_desc: String = str(data.get("desc", ""))
		var final_desc: String = raw_description if not raw_description.is_empty() else raw_desc
		param.description = final_desc
		param.desc = final_desc
		param.type_name = str(data.get("type_name", data.get("typeName", data.get("type", "String"))))
		param.default_value = data.get("default_value", data.get("defaultValue", data.get("initial_value", data.get("initialValue", ""))))
		param.initial_value = data.get("initial_value", data.get("initialValue", param.default_value))
		param.initialValue = param.initial_value
		param.hint = str(data.get("hint", ""))
		var options_data: Variant = data.get("options", [])
		if options_data is Array:
			for option: Variant in options_data:
				param.options.append(str(option))
		_apply_param_aliases(param)
		output.append(param)
	return output

static func _apply_descriptor_aliases(descriptor: ACEDescriptor) -> void:
	if descriptor.list_name.is_empty():
		descriptor.list_name = descriptor.listName
	if descriptor.list_name.is_empty():
		descriptor.list_name = descriptor.display_name
	if descriptor.listName.is_empty():
		descriptor.listName = descriptor.list_name
	if descriptor.display_text.is_empty():
		descriptor.display_text = descriptor.displayText
	if descriptor.display_text.is_empty():
		descriptor.display_text = descriptor.list_name
	if descriptor.displayText.is_empty():
		descriptor.displayText = descriptor.display_text
	if descriptor.category.is_empty():
		descriptor.category = "Custom ACEs"
	# node_type / nodeType alias sync: snake_case takes priority.
	# If node_type is empty, copy from nodeType; if nodeType is empty, copy from node_type.
	# When both are non-empty they are treated as already reconciled and left unchanged.
	if descriptor.node_type.is_empty():
		descriptor.node_type = descriptor.nodeType
	if descriptor.nodeType.is_empty():
		descriptor.nodeType = descriptor.node_type

static func _apply_param_aliases(param: ACEParam) -> void:
	if param.display_name.is_empty():
		param.display_name = param.name
	if param.description.is_empty():
		param.description = param.desc
	if param.desc.is_empty():
		param.desc = param.description
	var resolved_initial: Variant = param.get_initial_value()
	param.initial_value = resolved_initial
	param.initialValue = resolved_initial
