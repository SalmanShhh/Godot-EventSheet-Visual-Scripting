# EventSheet - the saved colour palette (the event-sheet swatch shelf). Colours a user saves in the
# inline swatch picker persist per project and reappear in every picker session - the third
# time a team colour is needed, it is one click on the shelf, not a re-pick.
#
# Persistence is EDITOR PROJECT METADATA (per-user, per-project, never committed) via the
# export-safe singleton pattern; outside the editor (headless tests) the store is a plain
# in-memory list, which is exactly what the tests exercise.
@tool
class_name EventSheetColorPresets
extends RefCounted

const MAX_PRESETS: int = 30
const _META_SECTION: String = "eventsheets"
const _META_KEY: String = "color_presets"

static var _cache: Array = []
static var _loaded: bool = false


## Saves a colour onto the shelf (dedupe by exact value, newest kept, capped).
static func add(color: Color) -> void:
	_ensure_loaded()
	var html: String = color.to_html(true)
	_cache.erase(html)
	_cache.append(html)
	while _cache.size() > MAX_PRESETS:
		_cache.pop_front()
	_save()


## Removes a colour from the shelf (a picker's right-click-remove mirrors here).
static func remove(color: Color) -> void:
	_ensure_loaded()
	_cache.erase(color.to_html(true))
	_save()


## The saved shelf, oldest first (the order pickers show their preset row).
static func all() -> PackedColorArray:
	_ensure_loaded()
	var out: PackedColorArray = PackedColorArray()
	for html: Variant in _cache:
		out.append(Color.from_string(str(html), Color.WHITE))
	return out


## Tests only: a clean slate (also marks the store loaded so persistence stays untouched).
static func reset_for_tests() -> void:
	_cache = []
	_loaded = true


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var settings: Object = EventSheetEditorSettings.current()
	if settings == null:
		return
	var stored: Variant = settings.call("get_project_metadata", _META_SECTION, _META_KEY, [])
	if stored is Array:
		_cache = (stored as Array).duplicate()


static func _save() -> void:
	var settings: Object = EventSheetEditorSettings.current()
	if settings != null:
		settings.call("set_project_metadata", _META_SECTION, _META_KEY, _cache)
