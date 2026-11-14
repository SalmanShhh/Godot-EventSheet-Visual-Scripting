@tool
extends RefCounted

# Which scenes and resources of the project store a value for one exported variable of a script, and
# (for a rename) the same files with only the variable's NAME changed.
#
# A scene stores an Inspector value under the variable's name: `speed = 300.0` on the node that wears
# the script. After the variable is renamed Godot finds no `speed` on the script, drops the value without
# a word, and the next save of the scene removes it from the file. This reads the text of every `.tscn`
# and `.tres` under the project (it loads nothing: no scene is instantiated, no script is run) and finds
# the property lines that belong to a node or resource whose script is the one named - matched by its
# path AND by its uid - following a node through the scene it instances (an inherited scene) and through
# sub-resources.
#
# What a rename rewrites is the key at the start of a property line and nothing else: the value text
# after it is never read as a value and never printed again, so what a scene stored is copied byte for
# byte. A file this cannot rewrite with certainty is not rewritten; it is listed with the reason and
# what to do, and left exactly as it is.
#
# Loaded by path when the rename window opens, when a variable is about to be deleted and when a rename
# is confirmed, so the editor start does not compile it.

const TEXT_EXTENSIONS: PackedStringArray = ["tscn", "tres"]
const BINARY_EXTENSIONS: PackedStringArray = ["scn", "res"]
## How many scenes deep an inherited scene is followed. A scene that instances itself is a loop, not depth.
const MAX_INHERITANCE_DEPTH: int = 24
const SMALL_PROMPT_PATH: String = "res://addons/eventsheet/editor/small_prompt.gd"
const SHEET_COMPILER_PATH: String = "res://addons/eventforge/compiler/sheet_compiler.gd"

## The folders looked through. A test points it at a folder of its own; the editor leaves it alone.
static var roots: PackedStringArray = PackedStringArray(["res://"])


## Looks through the project. `scripts` is [{"path": "res://x.gd", "uid": "uid://..."}], either half
## may be empty. With `new_name` empty nothing is prepared to be written: the result only says where a
## value is stored. `open_unsaved` names the files open in the editor with changes not saved yet.
##
## Returns:
##   edits     {path: {"before": text, "after": text}} - files the rename rewrites (only with a new name)
##   counts    {path: values} - how many values each file stores, rewritten or not
##   unchanged [{"path", "why"}] - files that store a value but are not rewritten, and what to do
##   looked    how many scene and resource files were read
static func scan(scripts: Array, old_name: String, new_name: String,
		open_unsaved: PackedStringArray = PackedStringArray()) -> Dictionary:
	var result: Dictionary = {"edits": {}, "counts": {}, "unchanged": [], "looked": 0}
	if old_name.strip_edges().is_empty() or scripts.is_empty():
		return result
	var context: Dictionary = {"scripts": scripts, "memo": {}, "busy": {}}
	var text_files: PackedStringArray = PackedStringArray()
	var binary_files: PackedStringArray = PackedStringArray()
	for root: String in roots:
		_collect(root, text_files, binary_files)
	text_files.sort()
	binary_files.sort()
	var marker: String = "\n%s = " % old_name
	for path: String in text_files:
		result["looked"] = int(result["looked"]) + 1
		var text: String = FileAccess.get_file_as_string(path)
		# A property line starts its line; a file with no such line stores no value under this name.
		if not ("\n" + text).contains(marker):
			continue
		var found: Dictionary = _values_in(_analyse(path, context), old_name, new_name)
		var values: int = int(found["values"])
		if values == 0:
			continue
		result["counts"][path] = values
		var why: String = str(found["why"])
		if why.is_empty() and open_unsaved.has(path):
			why = EventSheetL10n.translate("it is open with changes you have not saved - save or close it, then rename again")
		if why.is_empty() and FileAccess.get_file_as_bytes(path) != text.to_utf8_buffer():
			why = EventSheetL10n.translate("it is not plain UTF-8 text - open it and type the value in again under the new name")
		if not why.is_empty():
			result["unchanged"].append({"path": path, "why": why})
		elif not new_name.is_empty() and str(found["after"]) != text:
			result["edits"][path] = {"before": text, "after": str(found["after"])}
	# A binary scene or resource cannot be read as text. Its bytes still say whether it could hold a value:
	# the variable's name and the script's path (or uid) both appear in it.
	for path: String in binary_files:
		result["looked"] = int(result["looked"]) + 1
		if _binary_may_store(path, scripts, old_name):
			result["counts"][path] = 1
			result["unchanged"].append({"path": path,
				"why": EventSheetL10n.translate("it is in Godot's binary format - open it and type the value in again under the new name")})
	return result


## How many scene and resource files a scan reads, for the line that says it is looking.
static func file_count() -> int:
	var text_files: PackedStringArray = PackedStringArray()
	var binary_files: PackedStringArray = PackedStringArray()
	for root: String in roots:
		_collect(root, text_files, binary_files)
	return text_files.size() + binary_files.size()


## The scripts a sheet's variables are stored under: the script file the sheet is opened from, or the
## script a `.tres` sheet compiles to, each with the uid Godot knows it by.
static func scripts_of(sheet: EventSheetResource) -> Array:
	var scripts: Array = []
	if sheet == null:
		return scripts
	var path: String = sheet.external_source_path
	if path.is_empty() and not sheet.resource_path.is_empty():
		path = load(SHEET_COMPILER_PATH)._resolve_output_path(sheet, "")
	if path.is_empty():
		return scripts
	var uid: String = ""
	var id: int = ResourceLoader.get_resource_uid(path)
	if id != ResourceUID.INVALID_ID:
		uid = ResourceUID.id_to_text(id)
	scripts.append({"path": path, "uid": uid})
	return scripts


## True when the sheet declares an exported variable of this name: the only kind a scene stores a value for.
static func is_exported_variable(sheet: EventSheetResource, variable_name: String) -> bool:
	for entry: Dictionary in EventSheetVariableOwners.member_rows(sheet):
		if str(entry.get("name", "")) == variable_name and bool(entry.get("inspector", false)):
			return true
	return false


## The scenes and resources that store a value for a sheet's exported variable, from the sheet the
## dock has open: {} when the variable is not exported or the sheet has no script file yet. Files open
## in the editor with unsaved changes are named so they are left alone.
static func stored_for(dock: Control, variable_name: String, new_name: String) -> Dictionary:
	var sheet: EventSheetResource = dock._current_sheet
	if sheet == null or not is_exported_variable(sheet, variable_name):
		return {}
	var scripts: Array = scripts_of(sheet)
	if scripts.is_empty():
		return {}
	var unsaved: PackedStringArray = PackedStringArray()
	if Engine.is_editor_hint():
		unsaved = EditorInterface.get_unsaved_scenes()
	return scan(scripts, variable_name, new_name, unsaved)


## The files a rename will write, as the funnel's {path: {"before", "after"}}.
static func edits_of(scenes: Dictionary) -> Dictionary:
	return scenes.get("edits", {})


## Display name of a project file for the lists: its path without the res:// start.
static func shown(path: String) -> String:
	return path.trim_prefix("res://")


## What the status line adds after a rename: how many values moved with it, and the files that did not.
static func status_tail(scenes: Dictionary) -> String:
	var edits: Dictionary = scenes.get("edits", {})
	var counts: Dictionary = scenes.get("counts", {})
	var parts: PackedStringArray = PackedStringArray()
	if not edits.is_empty():
		var values: int = 0
		for path: Variant in edits:
			values += int(counts.get(path, 0))
		parts.append(EventSheetL10n.translate("%d value(s) in %d scene(s) kept under the new name - Ctrl+Z puts them back.") % [values, edits.size()])
	var unchanged: Array = scenes.get("unchanged", [])
	if not unchanged.is_empty():
		var names: PackedStringArray = PackedStringArray()
		for entry: Dictionary in unchanged:
			names.append(shown(str(entry["path"])))
		parts.append(EventSheetL10n.translate("Not changed, open each one and type its value in again under the new name: %s.") % ", ".join(names))
	return " ".join(parts)


## Asked before a delete takes an exported variable out: when scenes store a value for it, says how many
## and which ones in the small question every other question in the editor uses, and holds the delete
## until the reader answers. Returns true when it asked (the caller stops; `proceed` runs on "Delete
## anyway"), false when nothing needs saying and the delete may go ahead. Nothing in a scene is written.
static func guard_delete(dock: Control, resources: Array, proceed: Callable) -> bool:
	var names: PackedStringArray = PackedStringArray()
	for resource: Variant in resources:
		if resource is LocalVariable and not str((resource as LocalVariable).name).is_empty() \
				and (resource as LocalVariable).exported:
			names.append(str((resource as LocalVariable).name))
	if names.is_empty() or not Engine.is_editor_hint():
		return false
	var scripts: Array = scripts_of(dock._current_sheet)
	if scripts.is_empty():
		return false
	var places: Array = []
	var files: Dictionary = {}
	for variable_name: String in names:
		var found: Dictionary = scan(scripts, variable_name, "")
		for path: Variant in found["counts"]:
			files[path] = true
			places.append([shown(str(path)), EventSheetL10n.translate("%d value(s)") % int(found["counts"][path])])
	if files.is_empty():
		return false
	var asked: PackedStringArray = PackedStringArray()
	asked.append_array(names)
	load(SMALL_PROMPT_PATH).open(dock, {
		"title": EventSheetL10n.translate("Scenes store a value for %s") % ", ".join(asked),
		"say": EventSheetL10n.translate("%d scene or resource file(s) store a value for it. Deleting it makes Godot drop those values the next time each one is saved.") % files.size(),
		"list": places,
		"note": EventSheetL10n.translate("Nothing in those files is changed by deleting. To keep the values, cancel and use Rename instead: it carries them along."),
		"glyph": "!",
		"main": EventSheetL10n.translate("Keep the variable"),
		"danger": EventSheetL10n.translate("Delete anyway"),
		"on_danger": proceed,
	})
	return true


## Writes the files one edit reached ({path: text}), each one backed up first the way a sheet save backs
## up its file, each through a temporary file and a rename so a crash or a full disk leaves it as it
## was. When one cannot be written, the files already written are put back and the path that failed is
## returned; "" means every file landed. Open scenes are then read again from disk so a later save of
## the open scene cannot write the old name back over this one.
static func write_all(texts: Dictionary) -> String:
	var written: Dictionary = {}
	for path: Variant in texts:
		var previous: String = FileAccess.get_file_as_string(str(path)) if FileAccess.file_exists(str(path)) else ""
		EventSheetBackups.backup_sheet(str(path))
		if not load(SHEET_COMPILER_PATH)._write_output_if_changed(str(path), str(texts[path])):
			for done: Variant in written:
				load(SHEET_COMPILER_PATH)._write_output_if_changed(str(done), str(written[done]))
			return str(path)
		written[path] = previous
	if Engine.is_editor_hint():
		var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
		var open_scenes: PackedStringArray = PackedStringArray()
		for path: Variant in texts:
			if EditorInterface.get_open_scenes().has(str(path)):
				open_scenes.append(str(path))
		if file_system != null:
			file_system.scan()
		if not open_scenes.is_empty() and file_system != null:
			# An open scene is read again once the editor has read the files that changed (the script
			# first), so it comes back with its values under the new name rather than with the old
			# script's idea of them. Not inside the undo step being recorded: a reload there clears it.
			file_system.filesystem_changed.connect(func() -> void:
				for scene: String in open_scenes:
					EditorInterface.reload_scene_from_path.call_deferred(scene), CONNECT_ONE_SHOT)
	return ""


## Every text and binary scene/resource file under a folder, never entering a folder that starts with a
## dot (.godot holds Godot's own copies) or one the engine itself ignores.
static func _collect(directory_path: String, text_files: PackedStringArray, binary_files: PackedStringArray) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null or FileAccess.file_exists(directory_path.path_join(".gdignore")):
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var full_path: String = directory_path.path_join(entry)
			if directory.current_is_dir():
				_collect(full_path, text_files, binary_files)
			else:
				var extension: String = entry.get_extension().to_lower()
				if TEXT_EXTENSIONS.has(extension):
					text_files.append(full_path)
				elif BINARY_EXTENSIONS.has(extension):
					binary_files.append(full_path)
		entry = directory.get_next()
	directory.list_dir_end()


static func _binary_may_store(path: String, scripts: Array, old_name: String) -> bool:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty() or not _bytes_contain(bytes, old_name.to_utf8_buffer()):
		return false
	for script: Variant in scripts:
		for needle: String in [str((script as Dictionary).get("path", "")), str((script as Dictionary).get("uid", ""))]:
			if not needle.is_empty() and _bytes_contain(bytes, needle.to_utf8_buffer()):
				return true
	return false


static func _bytes_contain(bytes: PackedByteArray, needle: PackedByteArray) -> bool:
	if needle.is_empty() or bytes.size() < needle.size():
		return false
	var first: int = needle[0]
	var at: int = bytes.find(first)
	while at >= 0 and at <= bytes.size() - needle.size():
		var same: bool = true
		for offset: int in range(1, needle.size()):
			if bytes[at + offset] != needle[offset]:
				same = false
				break
		if same:
			return true
		at = bytes.find(first, at + 1)
	return false


## Reads a scene or resource file into its sections. Each section is {"tag", "header", "props":
## [{"key", "line"}], "script": the text after `script = `, "ours", "path"}; the file also carries its
## ext_resource table and its lines. `ours` is filled in by _analyse.
static func _parse(text: String) -> Dictionary:
	var lines: PackedStringArray = text.split("\n")
	var ext: Dictionary = {}
	var sections: Array = []
	var depth: int = 0
	var in_string: bool = false
	for index: int in range(lines.size()):
		var line: String = lines[index]
		if depth == 0 and not in_string and line.begins_with("["):
			var section: Dictionary = {"tag": _tag_of(line), "header": line, "props": [], "script": "", "ours": false, "path": ""}
			if section["tag"] == "ext_resource":
				ext[_attr(line, "id")] = {"type": _attr(line, "type"), "path": _attr(line, "path"), "uid": _attr(line, "uid")}
			sections.append(section)
			continue
		if depth == 0 and not in_string and not sections.is_empty():
			var at: int = line.find(" = ")
			if at > 0:
				var key: String = line.substr(0, at)
				(sections[sections.size() - 1]["props"] as Array).append({"key": key, "line": index})
				if key == "script":
					sections[sections.size() - 1]["script"] = line.substr(at + 3).strip_edges()
		var state: Array = _advance(line, depth, in_string)
		depth = int(state[0])
		in_string = bool(state[1])
	return {"lines": lines, "ext": ext, "sections": sections}


## How one line leaves the bracket depth and the quote state a value is in. A line whose quotes and
## brackets visibly balance (almost all of them) leaves both alone without a walk over its characters.
static func _advance(line: String, depth: int, in_string: bool) -> Array:
	var balanced: bool = line.count("[") + line.count("{") + line.count("(") \
		== line.count("]") + line.count("}") + line.count(")")
	if not in_string and balanced and (line.find("\"") < 0 or (line.count("\\\"") == 0 and line.count("\"") % 2 == 0)):
		return [depth, in_string]
	var quoted: bool = in_string
	var level: int = depth
	var index: int = 0
	var length: int = line.length()
	while index < length:
		var character: String = line[index]
		if quoted:
			if character == "\\":
				index += 1
			elif character == "\"":
				quoted = false
		elif character == "\"":
			quoted = true
		elif character == "[" or character == "{" or character == "(":
			level += 1
		elif character == "]" or character == "}" or character == ")":
			level -= 1
		index += 1
	return [maxi(level, 0), quoted]


static func _tag_of(header: String) -> String:
	var end: int = header.find(" ")
	var close: int = header.find("]")
	if end < 0 or (close >= 0 and close < end):
		end = close
	return header.substr(1, end - 1) if end > 1 else ""


## `key="value"` or `key=ExtResource("value")` out of a section header; "" when absent.
static func _attr(header: String, key: String) -> String:
	for marker: String in [" %s=\"" % key, " %s=ExtResource(\"" % key, " %s=SubResource(\"" % key]:
		var start: int = header.find(marker)
		if start >= 0:
			start += marker.length()
			var end: int = header.find("\"", start)
			if end > start:
				return header.substr(start, end - start)
	return ""


## Fills in, for every section of one file, whether it belongs to a node or resource wearing one of the
## scripts. Memoised per file; a scene reached while it is being read (an instance loop) answers "no".
static func _analyse(path: String, context: Dictionary, depth: int = 0) -> Dictionary:
	var memo: Dictionary = context["memo"]
	if memo.has(path):
		return memo[path]
	var empty: Dictionary = {"lines": PackedStringArray(), "ext": {}, "sections": [], "node_ours": {}}
	var busy: Dictionary = context["busy"]
	if busy.has(path) or depth > MAX_INHERITANCE_DEPTH or not FileAccess.file_exists(path):
		return empty
	busy[path] = true
	var parsed: Dictionary = _parse(FileAccess.get_file_as_string(path))
	var ext: Dictionary = parsed["ext"]
	var node_ours: Dictionary = {}
	var node_scene: Dictionary = {}
	for section: Dictionary in parsed["sections"]:
		var tag: String = section["tag"]
		if tag == "node":
			var name: String = _attr(section["header"], "name")
			var parent: String = _attr(section["header"], "parent")
			var node_path: String = "."
			if not parent.is_empty():
				node_path = name if parent == "." else "%s/%s" % [parent, name]
			section["path"] = node_path
			var own: String = _script_id(section["script"])
			var instance: String = _attr(section["header"], "instance")
			var ours: bool = false
			var scene_path: String = ""
			if instance != "" and ext.has(instance):
				scene_path = _scene_of(ext[instance])
				node_scene[node_path] = scene_path
			if not own.is_empty():
				ours = _is_ours(ext.get(own, {}), context["scripts"])
			elif not scene_path.is_empty():
				ours = bool((_analyse(scene_path, context, depth + 1)["node_ours"] as Dictionary).get(".", false))
			elif _attr(section["header"], "type").is_empty():
				ours = _inherited_ours(node_path, node_scene, context, depth)
			section["ours"] = ours
			node_ours[node_path] = ours
		elif tag == "sub_resource" or tag == "resource":
			var script_id: String = _script_id(section["script"])
			section["ours"] = not script_id.is_empty() and _is_ours(ext.get(script_id, {}), context["scripts"])
	var analysis: Dictionary = {"lines": parsed["lines"], "ext": ext, "sections": parsed["sections"], "node_ours": node_ours}
	busy.erase(path)
	memo[path] = analysis
	return analysis


## A node a scene overrides without saying what it is: its script is the one of the node it overrides,
## found in the scene the nearest instance above it (or the scene this one inherits) brings in.
static func _inherited_ours(node_path: String, node_scene: Dictionary, context: Dictionary, depth: int) -> bool:
	var cursor: String = node_path
	while cursor != ".":
		var cut: int = cursor.rfind("/")
		cursor = cursor.substr(0, cut) if cut >= 0 else "."
		if node_scene.has(cursor):
			var remainder: String = node_path.trim_prefix(cursor + "/") if cursor != "." else node_path
			return bool((_analyse(str(node_scene[cursor]), context, depth + 1)["node_ours"] as Dictionary).get(remainder, false))
	return false


## The id inside `ExtResource("1_ab")`; "" for anything else (a script written inline, no script at all).
static func _script_id(expression: String) -> String:
	if not expression.begins_with("ExtResource(\""):
		return ""
	var end: int = expression.find("\"", 13)
	return expression.substr(13, end - 13) if end > 13 else ""


## True when an ext_resource is one of the scripts, by the path it names or by its uid.
static func _is_ours(resource: Dictionary, scripts: Array) -> bool:
	if resource.is_empty() or str(resource.get("type", "")) != "Script":
		return false
	for script: Variant in scripts:
		var entry: Dictionary = script
		var path: String = str(entry.get("path", ""))
		var uid: String = str(entry.get("uid", ""))
		if not path.is_empty() and path == str(resource.get("path", "")):
			return true
		if not uid.is_empty() and uid == str(resource.get("uid", "")):
			return true
	return false


## The scene file an ext_resource names: its path when that file exists, else the file its uid names now.
static func _scene_of(resource: Dictionary) -> String:
	var path: String = str(resource.get("path", ""))
	if not path.is_empty() and FileAccess.file_exists(path):
		return path
	var uid: String = str(resource.get("uid", ""))
	if not uid.is_empty():
		var id: int = ResourceUID.text_to_id(uid)
		if id != ResourceUID.INVALID_ID and ResourceUID.has_id(id):
			return ResourceUID.get_id_path(id)
	return path


## The property lines of one analysed file that store a value for the variable: how many, the file's text
## with the key renamed on exactly those lines, and a reason when it cannot be done with certainty.
static func _values_in(analysis: Dictionary, old_name: String, new_name: String) -> Dictionary:
	var lines: PackedStringArray = (analysis["lines"] as PackedStringArray).duplicate()
	var values: int = 0
	var why: String = ""
	for section: Dictionary in analysis["sections"]:
		if not bool(section.get("ours", false)):
			continue
		var holds_new: bool = false
		var hits: Array[int] = []
		for property: Dictionary in section["props"]:
			if str(property["key"]) == old_name:
				hits.append(int(property["line"]))
			elif not new_name.is_empty() and str(property["key"]) == new_name:
				holds_new = true
		if hits.is_empty():
			continue
		values += hits.size()
		if holds_new:
			why = EventSheetL10n.translate("it already stores a value under the name %s - open it and decide which value to keep") % new_name
		for line_index: int in hits:
			lines[line_index] = new_name + lines[line_index].substr(old_name.length())
	return {"values": values, "why": why, "after": "\n".join(lines)}
