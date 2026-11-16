# Godot EventSheets - what a script sheet remembers about how it looks.
#
# A sheet saved as a `.gd` file is plain GDScript: nothing about its theme, its lane split, its column
# widths or its density may be written into it, or the file would stop being the code a person wrote.
# So the choices made for such a sheet are kept here instead, in the project's own editor metadata,
# one small record per script path, and put back on the sheet when it is opened again.
#
# DELIBERATELY NO `class_name`: callers load it by path at the moment they ask, so the first open of
# the workspace does not compile it.
@tool
extends RefCounted


const META_SECTION := "eventsheets"
const META_KEY := "sheet_looks"

## The record's keys. `theme` and `density` are file paths; the rest are numbers.
const KEY_THEME := "theme"
const KEY_DENSITY := "density"
const KEY_LANE_RATIO := "lane_ratio"
const KEY_CONDITION_COLUMN := "condition_column"
const KEY_ACTION_COLUMN := "action_column"

## Where the records live when there is no editor (a headless run, a test): the session.
static var _session: Dictionary = {}


## Whether a sheet at this path is plain script (its look cannot live in the file).
static func is_script_sheet(path: String) -> bool:
	return path.get_extension() == "gd"


static func _all() -> Dictionary:
	var settings: Object = EventSheetEditorSettings.current()
	if settings == null:
		return _session
	var stored: Variant = settings.call("get_project_metadata", META_SECTION, META_KEY, {})
	return stored if stored is Dictionary else {}


static func _write(all: Dictionary) -> void:
	var settings: Object = EventSheetEditorSettings.current()
	if settings == null:
		_session = all
	else:
		settings.call("set_project_metadata", META_SECTION, META_KEY, all)


## The record kept for one script path, empty when nothing was chosen for it.
static func record_for(path: String) -> Dictionary:
	var record: Variant = _all().get(path, {})
	return record if record is Dictionary else {}


## Keeps one choice for a script path.
static func remember(path: String, key: String, value: Variant) -> void:
	if path.is_empty():
		return
	var all: Dictionary = _all().duplicate()
	var record: Dictionary = record_for(path).duplicate()
	record[key] = value
	all[path] = record
	_write(all)


## Lets go of one kept choice for a script path.
static func erase(path: String, key: String) -> void:
	var record: Dictionary = record_for(path).duplicate()
	if record.erase(key):
		var all: Dictionary = _all().duplicate()
		all[path] = record
		_write(all)


## Lets go of everything kept for a script path (the sheet goes back to Match Editor).
static func forget(path: String) -> void:
	var all: Dictionary = _all().duplicate()
	if all.erase(path):
		_write(all)


## Puts a script's remembered look on its sheet when the sheet has none of its own. True when it wore one.
static func restore(sheet: EventSheetResource, path: String) -> bool:
	if sheet == null or sheet.editor_style != null or not is_script_sheet(path):
		return false
	var record: Dictionary = record_for(path)
	if record.is_empty():
		return false
	var style: EventSheetEditorStyle = null
	var theme_path: String = str(record.get(KEY_THEME, ""))
	if not theme_path.is_empty() and ResourceLoader.exists(theme_path):
		style = load(theme_path) as EventSheetEditorStyle
	var density_path: String = str(record.get(KEY_DENSITY, ""))
	var density: EventSheetDensityStyle = null
	if not density_path.is_empty() and ResourceLoader.exists(density_path):
		density = load(density_path) as EventSheetDensityStyle
	var numbers: bool = record.has(KEY_LANE_RATIO) or record.has(KEY_CONDITION_COLUMN) or record.has(KEY_ACTION_COLUMN)
	if style == null and density == null and not numbers:
		return false
	if density != null:
		style = (style.duplicate(true) as EventSheetEditorStyle) if style != null \
			else EventSheetEditorThemeDeriver.default_style().duplicate(true) as EventSheetEditorStyle
		density.apply_to(style)
	elif style == null:
		style = EventSheetEditorThemeDeriver.promoted_default_style()
	var event_style: EventSheetEventStyle = style.get_event_style()
	if record.has(KEY_LANE_RATIO):
		event_style.condition_lane_ratio = float(record[KEY_LANE_RATIO])
	if record.has(KEY_CONDITION_COLUMN):
		event_style.condition_object_column_width = int(record[KEY_CONDITION_COLUMN])
	if record.has(KEY_ACTION_COLUMN):
		event_style.action_object_column_width = int(record[KEY_ACTION_COLUMN])
	sheet.editor_style = style
	return true
