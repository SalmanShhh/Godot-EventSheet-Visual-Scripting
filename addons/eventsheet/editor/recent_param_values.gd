# EventSheet - recent parameter values (the C3 "I keep typing the same thing" fix).
# Remembers the last few values COMMITTED for each parameter (keyed provider::ace::param) across
# the whole project, and serves them to the param dialogs' suggestion combos - so the third time
# an action needs "jump" or "res://sfx/hit.ogg", it is one pick instead of a retype.
#
# Persistence is EDITOR PROJECT METADATA (per-user, per-project, never committed to the repo) via
# the export-safe singleton pattern; outside the editor (headless tests, harnesses) the store is
# a plain in-memory ring, which is exactly what the tests exercise.
@tool
class_name EventSheetRecentParamValues
extends RefCounted

const MAX_RECENT: int = 5
const _META_SECTION: String = "eventsheets"
const _META_KEY: String = "recent_param_values"

static var _cache: Dictionary = {}
static var _loaded: bool = false


## Records a committed value at the FRONT of its parameter's ring (dedup by exact text, cap 5).
## Empty and whitespace-only values never record - an untouched optional field is not a habit.
static func record(provider_id: String, ace_id: String, param_id: String, value: String) -> void:
	var text: String = value.strip_edges()
	if text.is_empty():
		return
	_ensure_loaded()
	var key: String = _key(provider_id, ace_id, param_id)
	var ring: Array = _cache.get(key, [])
	ring.erase(text)
	ring.push_front(text)
	if ring.size() > MAX_RECENT:
		ring.resize(MAX_RECENT)
	_cache[key] = ring
	_save()


## The parameter's recent values, most recent first (empty when it has no history).
static func recent_for(provider_id: String, ace_id: String, param_id: String) -> PackedStringArray:
	_ensure_loaded()
	var out: PackedStringArray = PackedStringArray()
	for value: Variant in _cache.get(_key(provider_id, ace_id, param_id), []):
		out.append(str(value))
	return out


## Tests only: a clean slate (also marks the store loaded so persistence stays untouched).
static func reset_for_tests() -> void:
	_cache = {}
	_loaded = true


static func _key(provider_id: String, ace_id: String, param_id: String) -> String:
	return "%s::%s::%s" % [provider_id, ace_id, param_id]


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var settings: Object = _editor_settings()
	if settings == null:
		return
	var stored: Variant = settings.call("get_project_metadata", _META_SECTION, _META_KEY, {})
	if stored is Dictionary:
		_cache = (stored as Dictionary).duplicate(true)


static func _save() -> void:
	var settings: Object = _editor_settings()
	if settings != null:
		settings.call("set_project_metadata", _META_SECTION, _META_KEY, _cache)


## Export-safe editor access (the palette's pattern): never NAME the editor-only class.
static func _editor_settings() -> Object:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_editor_settings"):
		return null
	return editor_interface.call("get_editor_settings")
