# Godot EventSheets - WHAT A DOCUMENTATION PICTURE SHOWS, written down as a few short hashes (dev tool).
#
# A picture goes stale when the thing it shows changes, not when a file it was once drawn from is
# touched (the sheet canvas files change several times a day for reasons no picture can show). So each
# picture records, when it is taken, one hash per thing that decides what is in its frame, and a test
# computes them again and compares:
#
#   reading  the words of every row of the sheet(s) the picture opens, written by the same writer the
#            reading dump uses (object word, lane, segments, chip marks)
#   look     every colour and metric of the default sheet look for the dark editor base
#   icons    the bytes of the icon files the picture shows (a list in the shot, or "sections")
#   files    the bytes of source files the shot lists. COARSE: any edit to them moves it, shown or not;
#            used for a menu or a window nothing here can build without an editor
#   godot    the engine's version string, so an engine upgrade turns every picture stale once
#   png      the picture file's own bytes, so a picture replaced without its entry is caught
#
# WHAT IT CANNOT SEE: a change that reaches the pixels without reaching any of these (a stylebox
# margin in a window, the editor theme of a newer Godot), and a menu or window whose texts only an
# editor can build. A picture whose shot lists `files` is marked coarse in its entry.
#
# No class_name: this is a tool and stays out of the boot path.
@tool
extends RefCounted

const LINES := preload("res://tools/reading_lines.gd")

## Where a list of shots lives unless a caller says otherwise.
const DEFAULT_LIST: String = "res://tools/doc_shots/shots.json"


## Every sheet a shot opens: its own `source`, and the `source` of each of its parts.
static func sources_of(shot: Dictionary) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if shot.has("source"):
		found.append(str(shot["source"]))
	for part: Variant in shot.get("parts", []):
		var path: String = str((part as Dictionary).get("source", ""))
		if not path.is_empty() and not found.has(path):
			found.append(path)
	return found


## The fingerprint of a shot: every field that applies to it. `png_path` is the picture it describes.
static func of_shot(shot: Dictionary, png_path: String) -> Dictionary:
	var result: Dictionary = {"godot": Engine.get_version_info()["string"], "look": look()}
	var sources: PackedStringArray = sources_of(shot)
	if not sources.is_empty():
		result["reading"] = reading(sources)
	if shot.has("icons"):
		result["icons"] = icons(shot["icons"])
	if shot.has("files"):
		result["files"] = files(shot["files"])
		result["coarse"] = true
	if FileAccess.file_exists(png_path):
		result["png"] = FileAccess.get_sha256(png_path)
	return result


## The words of every row of each sheet, as one hash.
static func reading(sources: PackedStringArray) -> String:
	var text: String = ""
	for path: String in sources:
		var sheet: EventSheetResource = null
		match path.get_extension():
			"tres":
				sheet = _load_stashed(path)
			"tscn":
				sheet = EventSheetSceneSheet.build(path)
			_:
				sheet = EventSheetGDScriptImporter.new().import_external(path)
		if sheet == null:
			text += "%s: does not open as a sheet\n" % path
			continue
		text += LINES.text(LINES.readings_of_sheet(sheet, path))
	return text.sha256_text()


## Every colour and metric of the default look, drawn for the dark editor base.
static func look() -> String:
	var style: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE)
	return _dump(style).sha256_text()


## The bytes of the listed icon files, in the order listed; "sections" stands for every section icon.
static func icons(listed: Variant) -> String:
	var paths: PackedStringArray = PackedStringArray()
	for entry: Variant in (listed as Array):
		if str(entry) == "sections":
			var directory: DirAccess = DirAccess.open("res://addons/eventsheet/icons/sections")
			var names: PackedStringArray = directory.get_files() if directory != null else PackedStringArray()
			names.sort()
			for name: String in names:
				if name.get_extension() == "svg":
					paths.append("res://addons/eventsheet/icons/sections".path_join(name))
		else:
			paths.append(str(entry))
	return _hash_files(paths)


## The bytes of the listed source files.
static func files(listed: Variant) -> String:
	var paths: PackedStringArray = PackedStringArray()
	for entry: Variant in (listed as Array):
		paths.append(str(entry))
	return _hash_files(paths)


static func _hash_files(paths: PackedStringArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for path: String in paths:
		context.update(path.to_utf8_buffer())
		context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()


## A resource written down property by property, sorted, nested resources included, with no path and no
## id in it, so the same look gives the same text on every machine.
static func _dump(value: Variant, depth: int = 0) -> String:
	if depth > 8:
		return "..."
	if value is Resource:
		var resource: Resource = value
		var rows: PackedStringArray = PackedStringArray()
		for property: Dictionary in resource.get_property_list():
			if (int(property["usage"]) & PROPERTY_USAGE_STORAGE) == 0:
				continue
			if str(property["name"]) in ["script", "resource_path", "resource_name"]:
				continue
			rows.append("%s=%s" % [property["name"], _dump(resource.get(str(property["name"])), depth + 1)])
		rows.sort()
		return "{%s}" % ";".join(rows)
	if value is Array:
		var items: PackedStringArray = PackedStringArray()
		for item: Variant in value:
			items.append(_dump(item, depth + 1))
		return "[%s]" % ",".join(items)
	if value is Dictionary:
		var keys: Array = (value as Dictionary).keys()
		keys.sort()
		var pairs: PackedStringArray = PackedStringArray()
		for key: Variant in keys:
			pairs.append("%s:%s" % [var_to_str(key), _dump(value[key], depth + 1)])
		return "{%s}" % ",".join(pairs)
	return var_to_str(value)


## A sheet resource, read from the file or, when it is kept as `<name>.tres.txt`, from a copy of that text.
static func _load_stashed(path: String) -> EventSheetResource:
	if FileAccess.file_exists(path):
		return load(path) as EventSheetResource
	if not FileAccess.file_exists(path + ".txt"):
		return null
	var probe: String = "user://doc_shots_probe.tres"
	var copy: FileAccess = FileAccess.open(probe, FileAccess.WRITE)
	copy.store_string(FileAccess.get_file_as_string(path + ".txt"))
	copy.close()
	return ResourceLoader.load(probe, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource
