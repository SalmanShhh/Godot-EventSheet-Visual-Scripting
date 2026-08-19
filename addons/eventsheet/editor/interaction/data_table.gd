@tool
class_name EventSheetDataTable
extends RefCounted

# V4. A .tres opened as a TABLE, and a folder of .tres opened as ONE grid.
#
# A data asset is a row of values: one column per exported field of the Resource script behind it.
# That is a table, and a designer edits a table in a grid rather than one file at a time in the
# Inspector. This module is the whole model behind that view - what the columns are, what each asset
# holds, how an edited value goes back to disk, and how a new asset is born.
#
# NOTHING here draws. Every function is static and takes plain paths, so a test can pin the values a
# grid would show, and the byte-stability promise below, without an editor.
#
# THE PROMISE THIS RESTS ON: opening a .tres as a table and saving it with nothing edited writes the
# file back BYTE-IDENTICALLY. A table view that quietly reformats a designer's assets would show up
# as a diff in every commit, and the whole point of the view is that it is safe to open. So a save
# with no change asked for does not touch the file at all, and a save WITH a change goes through
# ResourceSaver on the loaded resource - the same writer the Inspector uses.

## The extensions a data asset is saved under.
const ASSET_EXTENSIONS: PackedStringArray = ["tres", "res"]


## True when a path is a data asset this view can open: a .tres whose resource is a Resource with a
## script that declares exported fields, and NOT one of the plugin's own sheet resources (those are
## already sheets, and open as one).
static func is_data_asset(path: String) -> bool:
	if not ASSET_EXTENSIONS.has(path.get_extension().to_lower()):
		return false
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	if resource == null or resource is EventSheetResource:
		return false
	return resource.get_script() != null and not columns_of(resource).is_empty()


## Every .tres in a folder that is a data asset, in the folder's own order. Not recursive: a folder
## of content is one level deep, and walking into subfolders would silently mix two tables.
static func folder_assets(directory: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(directory):
		return found
	for file_name: String in DirAccess.get_files_at(directory):
		var bare: String = file_name.trim_suffix(".remap")
		if not ASSET_EXTENSIONS.has(bare.get_extension().to_lower()):
			continue
		var path: String = directory.path_join(bare)
		if is_data_asset(path):
			found.append(path)
	return found


## True when a folder holds at least two assets of ONE type - the case that opens as a grid rather
## than as a single asset's table. A folder of mixed types is not one table, and saying it was would
## put a column on a row that has no such field.
static func is_one_type_folder(directory: String) -> bool:
	return not folder_type(directory).is_empty()


## The class name every asset in a folder shares, or "" when the folder is empty or mixed.
static func folder_type(directory: String) -> String:
	var shared: String = ""
	var assets: PackedStringArray = folder_assets(directory)
	if assets.is_empty():
		return ""
	for path: String in assets:
		var named: String = type_name_of(path)
		if named.is_empty():
			return ""
		if shared.is_empty():
			shared = named
		elif shared != named:
			return ""
	return shared


## The class name of the script behind one asset ("EnemyStats"), or "" when it has no named script.
static func type_name_of(path: String) -> String:
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	if resource == null:
		return ""
	var script: Script = resource.get_script() as Script
	if script == null:
		return ""
	var named: String = str(script.get_global_name())
	return named if not named.is_empty() else str(script.resource_path).get_file().get_basename()


## The type name the way the head bar says it out loud ("EnemyStats" -> "Enemy Stats").
static func type_words(path: String) -> String:
	return type_name_of(path).capitalize()


## The COLUMNS of the table an asset opens as: one entry per exported field, in declaration order,
## as {name, type, hint, hint_string, words}. `words` is the field name the way a designer reads it,
## which is the header the grid draws.
##
## Only the script's OWN exported properties are columns: `resource_name` / `resource_path` and the
## rest of Resource's built-in surface are Godot bookkeeping rather than the designer's data.
static func columns_of(resource: Resource) -> Array:
	var columns: Array = []
	if resource == null:
		return columns
	var script: Script = resource.get_script() as Script
	if script == null:
		return columns
	for entry: Variant in script.get_script_property_list():
		var property: Dictionary = entry
		var usage: int = int(property.get("usage", 0))
		if (usage & PROPERTY_USAGE_STORAGE) == 0 or (usage & PROPERTY_USAGE_EDITOR) == 0:
			continue
		var field: String = str(property.get("name", ""))
		if field.is_empty() or field.begins_with("_") or field.contains("/"):
			continue
		columns.append({
			"name": field,
			"type": int(property.get("type", TYPE_NIL)),
			"hint": int(property.get("hint", PROPERTY_HINT_NONE)),
			"hint_string": str(property.get("hint_string", "")),
			"words": field.capitalize()
		})
	return columns


## The columns of the asset at a path, so a caller with only a path never has to load it itself.
static func columns_at(path: String) -> Array:
	return columns_of(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE))


## ONE asset as a row: {path, name, values} where `values` is {field: value}. `name` is the file
## name without its extension, which is what the grid's first column shows and what a reader calls
## the asset ("slime", not "res://data/slime.tres").
static func asset_row(path: String) -> Dictionary:
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	if resource == null:
		return {}
	var values: Dictionary = {}
	for entry: Variant in columns_of(resource):
		var column: Dictionary = entry
		values[str(column.get("name", ""))] = resource.get(str(column.get("name", "")))
	return {"path": path, "name": path.get_file().get_basename(), "values": values}


## A whole folder as a grid: the shared columns once, then one row per asset. {} when the folder is
## not one type, because a grid with a column half its rows do not have is a lie about the data.
static func folder_grid(directory: String) -> Dictionary:
	var type_named: String = folder_type(directory)
	if type_named.is_empty():
		return {}
	var assets: PackedStringArray = folder_assets(directory)
	var rows: Array = []
	for path: String in assets:
		var row: Dictionary = asset_row(path)
		if not row.is_empty():
			rows.append(row)
	return {
		"type": type_named,
		"words": type_named.capitalize(),
		"folder": directory,
		"columns": columns_at(assets[0]),
		"rows": rows
	}


## Writes ONE edited field back to the asset on disk. Returns {ok, changed, message}.
##
## `changed` is false - and the file is NOT touched - when the value on disk already equals the one
## asked for. That is what makes opening a table and saving it byte-identical: a view that re-saves
## everything it showed would rewrite a designer's whole folder the moment they looked at it.
static func write_field(path: String, field: String, value: Variant) -> Dictionary:
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	if resource == null:
		return {"ok": false, "changed": false, "message": "There is no data asset at %s." % path}
	var known: bool = false
	for entry: Variant in columns_of(resource):
		if str((entry as Dictionary).get("name", "")) == field:
			known = true
			break
	if not known:
		return {"ok": false, "changed": false,
			"message": "%s has no field called %s." % [path.get_file(), field]}
	if _same_value(resource.get(field), value):
		return {"ok": true, "changed": false, "message": ""}
	resource.set(field, value)
	var error: int = ResourceSaver.save(resource, path)
	if error != OK:
		return {"ok": false, "changed": false,
			"message": "Could not write %s (error %d)." % [path.get_file(), error]}
	return {"ok": true, "changed": true, "message": ""}


## A NEW asset of the same type, beside the ones already there: a new row of the grid. The name is
## suffixed rather than overwritten, exactly as Create New > Event Sheet suffixes a sheet.
## Returns {ok, path, message}.
static func new_asset(directory: String, type_named: String, base_name: String = "") -> Dictionary:
	var script: Script = _script_of_class(type_named)
	# A grid's new row is a row of the SAME type as the ones already there, so the type the folder
	# already holds answers even when the project's class list does not (an unnamed script, a type
	# declared since the last scan).
	if script == null:
		for path: String in folder_assets(directory):
			var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
			if resource != null and type_name_of(path) == type_named:
				script = resource.get_script() as Script
				break
	if script == null:
		return {"ok": false, "path": "",
			"message": "There is no data type called %s in this project." % type_named}
	var made: Variant = script.new()
	if not (made is Resource):
		return {"ok": false, "path": "", "message": "%s is not a data type." % type_named}
	var stem: String = base_name.strip_edges().to_snake_case()
	if stem.is_empty():
		stem = type_named.to_snake_case()
	var path: String = directory.path_join("%s.tres" % stem)
	var suffix: int = 2
	while FileAccess.file_exists(path):
		path = directory.path_join("%s-%d.tres" % [stem, suffix])
		suffix += 1
	var error: int = ResourceSaver.save(made as Resource, path)
	if error != OK:
		return {"ok": false, "path": path,
			"message": "Could not write %s (error %d)." % [path.get_file(), error]}
	return {"ok": true, "path": path, "message": "Added %s." % path.get_file()}


## What the confirm before deleting a row says. Deleting an asset is deleting a FILE, and a row that
## other assets or scenes point at leaves a hole - so the question names the file rather than the row.
static func delete_confirm_text(path: String) -> String:
	return "Delete %s? The file is removed from the project, and anything pointing at it is left empty." % path.get_file()


## Removes one asset from disk - the grid's delete-row, done only after the confirm above.
## Returns {ok, message}.
static func delete_asset(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "message": "There is no file at %s." % path}
	var error: int = DirAccess.remove_absolute(path)
	if error != OK:
		return {"ok": false, "message": "Could not delete %s (error %d)." % [path.get_file(), error]}
	return {"ok": true, "message": "Deleted %s." % path.get_file()}


## The tab title a table opens under: the asset's own name, or the folder's.
static func tab_title(path: String) -> String:
	if DirAccess.dir_exists_absolute(path):
		return path.trim_suffix("/").get_file()
	return path.get_file()


## True when a value on disk already equals the one an edit asks for, compared by Godot's own
## equality so a float typed as "8" and the 8.0 stored do not read as a change.
static func _same_value(stored: Variant, asked: Variant) -> bool:
	if typeof(stored) == typeof(asked):
		return stored == asked
	if (stored is float or stored is int) and (asked is float or asked is int):
		return is_equal_approx(float(stored), float(asked))
	return false


## The script behind a project `class_name`, or null when the project has no such class.
static func _script_of_class(class_name_str: String) -> Script:
	for entry: Variant in ProjectSettings.get_global_class_list():
		var described: Dictionary = entry
		if str(described.get("class", "")) != class_name_str:
			continue
		var loaded: Resource = ResourceLoader.load(str(described.get("path", "")))
		return loaded as Script
	return null
