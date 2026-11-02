@tool
class_name EventSheetRuntimeErrorLocator
extends RefCounted

# Which open sheet, and which row of it, a failure in the running game belongs to.
#
# The game reports an error as a file and a line of the script that crashed. Only the sheet that wrote
# that file can say which row wrote that line, through the compiler's source map. The map used to be
# read from the Code panel, so it existed only while that panel was open and only for the tab on
# screen: an error from any other sheet, or with the panel closed, got its sentence and no address.
#
# This is the join without the panel. It finds the open tab whose output file the error names, computes
# the source map on demand (a compile that writes nothing), and keeps it for as long as the file it was
# computed for is the same bytes, so a game that fails every frame costs one compile, not sixty a second.
# NOTHING in the emitted game changes to make this work: the file and the line are all the engine
# already says, and the map is the editor's own record of what it wrote.

const SHEET_COMPILER_PATH := "res://addons/eventforge/compiler/sheet_compiler.gd"

## {output path: {"stamp": String, "map": Array, "stale": bool}} - the map last computed for a file,
## good while the file's modified time and the sheet's unsaved state are what they were.
static var _maps: Dictionary = {}


## The file a sheet's script is written to: its own path for a .gd sheet, the generated script beside
## it for a .tres one. "" for a sheet that was never saved, which has no file a game could run.
static func output_path_of(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	if not sheet.external_source_path.is_empty():
		return sheet.external_source_path
	if sheet.resource_path.is_empty():
		return ""
	return load(SHEET_COMPILER_PATH)._resolve_output_path(sheet, "")


## The index of the open tab whose script the error names, or -1. A whole-path match wins; failing
## that, a file name that only one tab has. `tabs` is the dock's list of {sheet, ...}.
static func tab_for(tabs: Array, wanted_path: String) -> int:
	var wanted: String = wanted_path.strip_edges()
	if wanted.is_empty():
		return -1
	for index: int in range(tabs.size()):
		var tab_sheet: EventSheetResource = (tabs[index] as Dictionary).get("sheet") as EventSheetResource
		if output_path_of(tab_sheet) == wanted:
			return index
	var by_name: int = -1
	for index: int in range(tabs.size()):
		var tab_sheet: EventSheetResource = (tabs[index] as Dictionary).get("sheet") as EventSheetResource
		var written: String = output_path_of(tab_sheet)
		if not written.is_empty() and written.get_file() == wanted.get_file():
			if by_name >= 0:
				return -1
			by_name = index
	return by_name


## The source map for what a sheet's file holds, as {"map": Array, "stale": bool}. `stale` is true when
## the sheet's code is no longer the file the game ran (unsaved edits): a line number of the old file
## would point at the wrong row, so the caller keeps the sentence and offers no row. Cached per file
## modified time and unsaved state.
static func source_map_for(sheet: EventSheetResource, unsaved: bool) -> Dictionary:
	var path: String = output_path_of(sheet)
	var modified: int = FileAccess.get_modified_time(path) if not path.is_empty() and FileAccess.file_exists(path) else 0
	var stamp: String = "%d|%s|%d" % [modified, str(unsaved), sheet.get_instance_id() if sheet != null else 0]
	var cached: Dictionary = _maps.get(path, {})
	if not cached.is_empty() and str(cached.get("stamp", "")) == stamp:
		return cached
	var compiled: Dictionary = load(SHEET_COMPILER_PATH).echo(sheet)
	var stale: bool = false
	if modified != 0:
		# The file the game ran is the file on disk; the map describes the sheet as it is now.
		stale = FileAccess.get_file_as_string(path) != str(compiled.get("output", ""))
	var built: Dictionary = {"stamp": stamp, "map": compiled.get("source_map", []), "stale": stale}
	_maps[path] = built
	return built


## Forgets every map. A test's way back to a clean slate.
static func clear() -> void:
	_maps.clear()
