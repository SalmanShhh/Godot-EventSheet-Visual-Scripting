@tool
class_name EventSheetACERegistry
extends RefCounted

var _generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
var _definitions: Array[ACEDefinition] = []
var _definitions_by_key: Dictionary = {}

# ── The startup/tab-switch cache ──────────────────────────────────────────────────────────────
# Reflecting 30+ provider scripts into ~1,400 definitions costs ~200 ms, and refresh runs on
# every tab activation. Definitions are IMMUTABLE after generation (the apply path bakes
# templates into ACEAction/ACECondition COPIES, never back into a definition), so they are safe
# to share across refreshes and registry instances. Builtins never change within a session;
# script-backed sources key on path + file mtime, so SAVING a provider script self-invalidates
# its entry (no explicit invalidation calls to forget).
static var _builtin_definition_cache: Array[ACEDefinition] = []
static var _source_definition_cache: Dictionary = {}


func refresh_from_sources(sources: Array[Object], include_builtin: bool = true) -> void:
	_definitions.clear()
	_definitions_by_key.clear()
	# Extension seam: dictionary-defined ACEs (EventSheets.register_simple_ace) join every
	# refresh - session-scoped verbs with no provider script file.
	for simple_definition: ACEDefinition in EventSheets.simple_aces():
		_store_definition(simple_definition)
	if include_builtin:
		if _builtin_definition_cache.is_empty():
			for descriptor in ACERegistry.get_all_descriptors():
				_builtin_definition_cache.append(EventSheetACEAdapter.from_eventforge_descriptor(descriptor))
		for builtin_definition in _builtin_definition_cache:
			_store_definition(builtin_definition)
	for source_object in sources:
		if source_object == null:
			continue
		var cache_key: String = _source_cache_key(source_object)
		if not cache_key.is_empty() and _source_definition_cache.has(cache_key):
			for cached_definition: ACEDefinition in _source_definition_cache[cache_key]:
				_store_definition(cached_definition)
			continue
		var generated: Array[ACEDefinition] = _generator.generate_from_object(source_object)
		if not cache_key.is_empty():
			# One live entry per script: drop this path's older keys (stale mtimes) so a long
			# editing session never accumulates dead reflections.
			var path_prefix: String = cache_key.substr(0, cache_key.find("|") + 1)
			for existing_key: Variant in _source_definition_cache.keys():
				if str(existing_key).begins_with(path_prefix):
					_source_definition_cache.erase(existing_key)
			_source_definition_cache[cache_key] = generated
		for definition in generated:
			_store_definition(definition)


## Cache identity for a reflectable source: its script's path + saved mtime + byte length.
## mtime alone has SECONDS resolution, so two saves inside one second would silently serve
## stale definitions - the length catches those (a same-second save that also keeps the exact
## byte count is the accepted residual edge). "" (uncacheable) for sources without a saved
## script - those reflect fresh every time, as before.
static func _source_cache_key(source_object: Object) -> String:
	var script: Script = source_object.get_script() as Script
	if script == null or script.resource_path.is_empty():
		return ""
	var script_path: String = script.resource_path
	var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
	var byte_length: int = file.get_length() if file != null else -1
	return "%s|%d|%d" % [script_path, FileAccess.get_modified_time(script_path), byte_length]


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
	# The same provider+id can arrive through two registration channels in one build
	# (a scanned addon that is ALSO a registered autoload, or a sheet re-registering a
	# scanned script). Replace in BOTH structures: the keyed lookup already took the
	# newest, but a flat append double-listed the ACE in the picker and search.
	if _definitions_by_key.has(key):
		var existing_index: int = _definitions.find(_definitions_by_key[key])
		if existing_index >= 0:
			_definitions[existing_index] = definition
		else:
			_definitions.append(definition)
		_definitions_by_key[key] = definition
		return
	_definitions_by_key[key] = definition
	_definitions.append(definition)


func _make_key(provider_id: String, definition_id: String) -> String:
	return "%s::%s" % [provider_id, definition_id]
