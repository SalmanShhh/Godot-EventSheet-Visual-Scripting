# EventSheet - EditorParamStore
# Serializable resource that stores per-parameter editor overrides for
# ACE-driven parameters. Values stored here take precedence over ACE defaults
# but are overridden by per-row values at runtime.
#
# Key format: "<provider_id>::<ace_id>::<param_id>"
@tool
class_name EditorParamStore
extends Resource

signal override_changed(provider_id: String, ace_id: String, param_id: String, value: Variant)
signal override_removed(provider_id: String, ace_id: String, param_id: String)
signal overrides_cleared()

## Raw override map: key -> value. Serialised as part of the resource.
@export var _overrides: Dictionary = {}


## Store an override for the given parameter key.
func set_param(provider_id: String, ace_id: String, param_id: String, value: Variant) -> void:
	_overrides[make_key(provider_id, ace_id, param_id)] = value
	override_changed.emit(provider_id, ace_id, param_id, value)


## Retrieve an override, or default_value if none is stored.
func get_param(provider_id: String, ace_id: String, param_id: String, default_value: Variant = null) -> Variant:
	return _overrides.get(make_key(provider_id, ace_id, param_id), default_value)


## Returns true when an override exists for the given parameter.
func has_param(provider_id: String, ace_id: String, param_id: String) -> bool:
	return _overrides.has(make_key(provider_id, ace_id, param_id))


## Remove the override for the given parameter.
func clear_param(provider_id: String, ace_id: String, param_id: String) -> void:
	var key: String = make_key(provider_id, ace_id, param_id)
	if not _overrides.has(key):
		return
	_overrides.erase(key)
	override_removed.emit(provider_id, ace_id, param_id)


## Remove all stored overrides.
func clear_all() -> void:
	if _overrides.is_empty():
		return
	_overrides.clear()
	overrides_cleared.emit()


## Return a flat copy of all stored overrides (read-only snapshot).
func get_all_overrides() -> Dictionary:
	return _overrides.duplicate()


## Number of stored overrides.
func override_count() -> int:
	return _overrides.size()


## Public key builder used by editor/inspector integration layers.
static func make_key(provider_id: String, ace_id: String, param_id: String) -> String:
	return "%s::%s::%s" % [provider_id, ace_id, param_id]
