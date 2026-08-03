# EventSheet - per-project ACE usage counts (the ghost row's learn-as-you-type memory).
# Every successful apply bumps the definition's counter, and the counters feed two things:
# the ghost row's suggestion chips (your most-used verbs, one click before you type) and the
# quick-add ranking's tie-break (at equal match quality, the verb you actually use wins).
#
# Persistence is EDITOR PROJECT METADATA (per-user, per-project, never committed to the repo)
# via the export-safe singleton pattern; outside the editor (headless tests, harnesses) the
# store is a plain in-memory map, which is exactly what the tests exercise.
@tool
class_name EventSheetAceUsageStats
extends RefCounted

# The store stays bounded: when it outgrows MAX_ENTRIES, only the most-used TRIM_TO survive.
# Rarely-used verbs falling off the tail is the intended forgetting - the ranking only needs
# the habits, not a full history.
const MAX_ENTRIES: int = 400
const TRIM_TO: int = 200
const _META_SECTION: String = "eventsheets"
const _META_KEY: String = "ace_usage_counts"

static var _cache: Dictionary = {}
static var _loaded: bool = false


## Bumps the definition's usage counter (any successful apply path: picker, quick-add bar,
## ghost row, replace flows - each is the user choosing this verb again).
static func record(provider_id: String, ace_id: String) -> void:
	if provider_id.is_empty() and ace_id.is_empty():
		return
	_ensure_loaded()
	var key: String = _key(provider_id, ace_id)
	_cache[key] = int(_cache.get(key, 0)) + 1
	if _cache.size() > MAX_ENTRIES:
		_trim()
	_save()


## How often this definition has been applied in this project (0 = never / forgotten).
static func count_for(provider_id: String, ace_id: String) -> int:
	_ensure_loaded()
	return int(_cache.get(_key(provider_id, ace_id), 0))


## Tests only: a clean slate (also marks the store loaded so persistence stays untouched).
static func reset_for_tests() -> void:
	_cache = {}
	_loaded = true


static func _key(provider_id: String, ace_id: String) -> String:
	return "%s::%s" % [provider_id, ace_id]


## Keeps the TRIM_TO most-used entries. Count desc then key asc, so the survivors are
## deterministic even among equal counts.
static func _trim() -> void:
	var keys: Array = _cache.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		var count_a: int = int(_cache[a])
		var count_b: int = int(_cache[b])
		if count_a != count_b:
			return count_a > count_b
		return str(a) < str(b))
	var trimmed: Dictionary = {}
	for index: int in range(mini(TRIM_TO, keys.size())):
		trimmed[keys[index]] = _cache[keys[index]]
	_cache = trimmed


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
