@tool
class_name EventSheetACERegistry
extends RefCounted

var _generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
var _definitions: Array[ACEDefinition] = []
var _definitions_by_key: Dictionary = {}
var _source_objects: Array[Object] = []


func refresh_from_sources(sources: Array[Object], include_builtin: bool = true) -> void:
	_definitions.clear()
	_definitions_by_key.clear()
	_source_objects = sources.duplicate()
	if include_builtin:
		for descriptor in ACERegistry.get_all_descriptors():
			_store_definition(EventSheetACEAdapter.from_eventforge_descriptor(descriptor))
	for source_object in sources:
		if source_object == null:
			continue
		for definition in _generator.generate_from_object(source_object):
			_store_definition(definition)


func hot_reload() -> void:
	refresh_from_sources(_source_objects, true)


func get_all_definitions() -> Array[ACEDefinition]:
	return _definitions.duplicate()


func get_provider_definitions(provider_id: String) -> Array[ACEDefinition]:
	var output: Array[ACEDefinition] = []
	for definition in _definitions:
		if definition.provider_id == provider_id:
			output.append(definition)
	return output


func get_categories() -> PackedStringArray:
	var categories: PackedStringArray = PackedStringArray()
	for definition in _definitions:
		if definition.category.is_empty() or categories.has(definition.category):
			continue
		categories.append(definition.category)
	categories.sort()
	return categories


func search(query: String, category: String = "", ace_type: int = -1) -> Array[ACEDefinition]:
	var output: Array[ACEDefinition] = []
	var normalized_query: String = query.to_lower().strip_edges()
	for definition in _definitions:
		if not category.is_empty() and definition.category != category:
			continue
		if ace_type >= 0 and definition.ace_type != ace_type:
			continue
		if normalized_query.is_empty():
			output.append(definition)
			continue
		var haystack: String = definition.get_search_text().to_lower()
		var matches: bool = true
		for token in normalized_query.split(" ", false):
			if haystack.find(token) == -1:
				matches = false
				break
		if matches:
			output.append(definition)
	return output


func find_definition(provider_id: String, definition_id: String) -> ACEDefinition:
	return _definitions_by_key.get(_make_key(provider_id, definition_id), null)


func get_reflected_provider_ids() -> PackedStringArray:
	var providers: PackedStringArray = PackedStringArray()
	for definition in _definitions:
		if str(definition.metadata.get("semantic_source", "")) != "reflection":
			continue
		if providers.has(definition.provider_id):
			continue
		providers.append(definition.provider_id)
	providers.sort()
	return providers


func _store_definition(definition: ACEDefinition) -> void:
	if definition == null:
		return
	var key: String = _make_key(definition.provider_id, definition.id)
	_definitions_by_key[key] = definition
	_definitions.append(definition)


func _make_key(provider_id: String, definition_id: String) -> String:
	return "%s::%s" % [provider_id, definition_id]
