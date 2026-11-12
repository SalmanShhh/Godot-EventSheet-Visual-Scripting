@tool
class_name EventSheetObjectMarks
extends RefCounted

# The marks a reader has put on an object: "this is a secret", "this is water", and which key a door
# wants. They are authoring metadata about how the sheet treats the object, kept in the per-project
# editor store, so they never reach the emitted bytes. The canvas drop reads them before it offers the
# secrets-counter, water or door events.

const SECRET_META_SECTION := "eventsheets"
const SECRET_META_KEY := "object_secret_flags"

## The second mark, kept in its own store beside the first: this area is WATER. Same reasoning,
## same place - it says how the sheet treats the object, and the game never reads it, so it must not
## reach the emitted bytes.
const WATER_META_KEY := "object_water_flags"

static var _secret_flags: Dictionary = {}
static var _secret_flags_loaded: bool = false
static var _water_flags: Dictionary = {}
static var _water_flags_loaded: bool = false


## The store key for one object: the file that names it plus its label, so two sheets with an
## object of the same name mark their own.
static func secret_key(source_path: String, object_label: String) -> String:
	return "%s::%s" % [source_path.strip_edges(), object_label.strip_edges()]


## True when the reader has marked this object a secret - the flag the canvas drop reads before it
## offers the secrets-counter event.
static func is_secret(source_path: String, object_label: String) -> bool:
	_ensure_secret_flags()
	return bool(_secret_flags.get(secret_key(source_path, object_label), false))


## Marks (or unmarks) an object a secret and remembers it for the project.
static func set_secret(source_path: String, object_label: String, marked: bool) -> void:
	_ensure_secret_flags()
	var key: String = secret_key(source_path, object_label)
	if marked:
		_secret_flags[key] = true
	else:
		_secret_flags.erase(key)
	var settings: Object = EventSheetEditorSettings.current()
	if settings != null:
		settings.call("set_project_metadata", SECRET_META_SECTION, SECRET_META_KEY, _secret_flags)


## Tests only: a clean slate (also marks the store loaded so persistence stays untouched).
static func reset_secret_flags_for_tests() -> void:
	_secret_flags = {}
	_secret_flags_loaded = true


static func _ensure_secret_flags() -> void:
	if _secret_flags_loaded:
		return
	_secret_flags_loaded = true
	var settings: Object = EventSheetEditorSettings.current()
	if settings == null:
		return
	var stored: Variant = settings.call("get_project_metadata", SECRET_META_SECTION, SECRET_META_KEY, {})
	if stored is Dictionary:
		_secret_flags = (stored as Dictionary).duplicate()


## True when the reader has marked this area water - the flag the canvas drop reads before it
## offers the two rows that raise and lower the sheet's own in-water flag.
static func is_water(source_path: String, object_label: String) -> bool:
	_ensure_water_flags()
	return bool(_water_flags.get(secret_key(source_path, object_label), false))


## Marks (or unmarks) an area water and remembers it for the project. The key shape is the
## secret mark's - file plus label - so two sheets naming the same area mark their own.
static func set_water(source_path: String, object_label: String, marked: bool) -> void:
	_ensure_water_flags()
	var key: String = secret_key(source_path, object_label)
	if marked:
		_water_flags[key] = true
	else:
		_water_flags.erase(key)
	var settings: Object = EventSheetEditorSettings.current()
	if settings != null:
		settings.call("set_project_metadata", SECRET_META_SECTION, WATER_META_KEY, _water_flags)


## Tests only: a clean slate (also marks the store loaded so persistence stays untouched).
static func reset_water_flags_for_tests() -> void:
	_water_flags = {}
	_water_flags_loaded = true


static func _ensure_water_flags() -> void:
	if _water_flags_loaded:
		return
	_water_flags_loaded = true
	var settings: Object = EventSheetEditorSettings.current()
	if settings == null:
		return
	var stored: Variant = settings.call("get_project_metadata", SECRET_META_SECTION, WATER_META_KEY, {})
	if stored is Dictionary:
		_water_flags = (stored as Dictionary).duplicate()


const NEEDS_KEY_META_KEY := "object_needs_key"

static var _needs_key: Dictionary = {}
static var _needs_key_loaded: bool = false


## The key the reader said this door wants, or "" when they have not said. The canvas drop reads it
## before it offers the door event, and it is what that event is written with.
static func needs_key_of(source_path: String, object_label: String) -> String:
	_ensure_needs_key()
	return str(_needs_key.get(secret_key(source_path, object_label), ""))


## Records (or clears, with an empty name) the key a door wants, and remembers it for the project.
static func set_needs_key(source_path: String, object_label: String, key_name: String) -> void:
	_ensure_needs_key()
	var key: String = secret_key(source_path, object_label)
	var wanted: String = key_name.strip_edges()
	if wanted.is_empty():
		_needs_key.erase(key)
	else:
		_needs_key[key] = wanted
	var settings: Object = EventSheetEditorSettings.current()
	if settings != null:
		settings.call("set_project_metadata", SECRET_META_SECTION, NEEDS_KEY_META_KEY, _needs_key)


## Tests only: a clean slate (also marks the store loaded so persistence stays untouched).
static func reset_needs_key_for_tests() -> void:
	_needs_key = {}
	_needs_key_loaded = true


static func _ensure_needs_key() -> void:
	if _needs_key_loaded:
		return
	_needs_key_loaded = true
	var settings: Object = EventSheetEditorSettings.current()
	if settings == null:
		return
	var stored: Variant = settings.call("get_project_metadata", SECRET_META_SECTION, NEEDS_KEY_META_KEY, {})
	if stored is Dictionary:
		_needs_key = (stored as Dictionary).duplicate()
