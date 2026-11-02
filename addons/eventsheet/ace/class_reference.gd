@tool
class_name EventSheetClassReference
extends RefCounted

# What Godot itself says about the types ClassDB cannot reflect.
#
# ClassDB answers for every engine CLASS (Node2D, AnimatedSprite2D, Input), live, including a
# project's own extensions. It answers nothing for the built-in VALUE types - Vector2, Color,
# String, Rect2, Array - because those are not classes, and it carries no prose at all. The engine
# does publish both, through `--dump-extension-api-with-docs`: every built-in type with its members,
# methods (arguments, defaults, return type), constants and the class reference's own words, plus the
# global enums (Key, MouseButton...) and the utility functions. This file asks the running editor's
# own binary for that dump ONCE, reduces it to what completion reads, and keeps the result in the
# project's user folder keyed by the engine build - so the answer is Godot's, never a hand table, and
# a new engine version is a new file by itself.
#
# DEGRADING QUIETLY. The dump needs the engine binary and a few seconds. Until the file exists (first
# run, a headless tool, a build with no way to launch itself) every question here answers with
# nothing: a list of an engine class still works from ClassDB and merely has no description line,
# and a built-in value type simply offers nothing. Nothing here ever raises or blocks the UI: the
# build runs on a thread, and asking never starts it.

## The reduced file's schema version. Bumped when the shape below changes, so an older file is
## rebuilt rather than misread.
const SCHEMA := 2

## Where the reduced files live. Overridable so a test never touches the project's own cache.
static var cache_directory: String = "user://eventsheet_class_reference"

## Built-in type name -> {"members": [...], "methods": [...], "constants": [...]}; empty until loaded.
static var _builtins: Dictionary = {}
## Global enum name -> [{"n": name, "v": value, "d": description}], and each constant's enum.
static var _enums: Dictionary = {}
static var _enum_of_constant: Dictionary = {}
## Utility function name -> {"a": [...], "r": return type, "va": vararg, "d": description}.
static var _utilities: Dictionary = {}
## "Class" -> {"p"|"m"|"s"|"c": {member: description}}; loaded on the first description asked for.
static var _docs: Dictionary = {}
static var _docs_loaded: bool = false
static var _loaded: bool = false
static var _thread: Thread = null
static var _build_started: bool = false
static var _next_look: int = 0


## True once the built-in types are known.
static func ready() -> bool:
	_ensure_loaded()
	return not _builtins.is_empty()


## Forgets everything held in memory (the file stays). A test or a tool calls it between fixtures.
static func reset() -> void:
	_builtins = {}
	_enums = {}
	_enum_of_constant = {}
	_utilities = {}
	_docs = {}
	_docs_loaded = false
	_loaded = false
	_next_look = 0


## True when `type_name` is a built-in value type this reference knows (Vector2, Color, String...).
static func has_builtin(type_name: String) -> bool:
	_ensure_loaded()
	return _builtins.has(type_name)


## The names of every built-in value type, in the engine's own order.
static func builtin_names() -> PackedStringArray:
	_ensure_loaded()
	return PackedStringArray(_builtins.keys())


## One built-in type's data: {"members": [{n, t, d}], "methods": [{n, r, s, va, a: [{n, t, v}], d}],
## "constants": [{n, t, d}]} or {} for a type this does not know.
static func builtin(type_name: String) -> Dictionary:
	_ensure_loaded()
	return _builtins.get(type_name, {})


## The global enums, {name: [{n, v, d}]}. Empty until the reference is loaded.
static func global_enums() -> Dictionary:
	_ensure_loaded()
	return _enums


## The enum a global constant (KEY_SPACE) belongs to, "" when it is no global enum value.
static func enum_of(constant_name: String) -> String:
	_ensure_loaded()
	return str(_enum_of_constant.get(constant_name, ""))


## One utility function (lerp, clamp, print...), {} when unknown.
static func utility(function_name: String) -> Dictionary:
	_ensure_loaded()
	return _utilities.get(function_name, {})


## The class reference's one-line description of a member, first sentence, translated when the
## editor's language has it. `kind` is "p" property, "m" method, "s" signal, "c" constant; the type
## may be a built-in value type or an engine class. "" when the reference has nothing (not built yet,
## or the member is undocumented).
static func describe(owner: String, kind: String, member_name: String) -> String:
	_ensure_loaded()
	var raw: String = ""
	if _builtins.has(owner):
		var data: Dictionary = _builtins[owner]
		var list_key: String = {"p": "members", "m": "methods", "c": "constants"}.get(kind, "")
		for item: Variant in data.get(list_key, []):
			if (item as Dictionary).get("n", "") == member_name:
				raw = str((item as Dictionary).get("d", ""))
				break
	else:
		_ensure_docs()
		raw = str(((_docs.get(owner, {}) as Dictionary).get(kind, {}) as Dictionary).get(member_name, ""))
	return first_sentence(translate_doc(raw))


## The brief description of a whole class, "" when unknown.
static func describe_class(class_name_text: String) -> String:
	_ensure_loaded()
	if _builtins.has(class_name_text):
		return first_sentence(translate_doc(str((_builtins[class_name_text] as Dictionary).get("d", ""))))
	_ensure_docs()
	return first_sentence(translate_doc(str((_docs.get(class_name_text, {}) as Dictionary).get("b", ""))))


## A global enum value's description.
static func describe_enum_value(constant_name: String) -> String:
	_ensure_loaded()
	var enum_name: String = enum_of(constant_name)
	for item: Variant in _enums.get(enum_name, []):
		if (item as Dictionary).get("n", "") == constant_name:
			return first_sentence(translate_doc(str((item as Dictionary).get("d", ""))))
	return ""


## A utility function's description.
static func describe_utility(function_name: String) -> String:
	return first_sentence(translate_doc(str(utility(function_name).get("d", ""))))


## The editor's own translation of a documentation text when its language has one, else the text.
## Only asked for a language that is not English, so the common path costs nothing.
static func translate_doc(text: String) -> String:
	if text.is_empty() or TranslationServer.get_tool_locale().begins_with("en"):
		return text
	var domain: TranslationDomain = TranslationServer.get_or_add_domain("godot.documentation")
	if domain == null:
		return text
	var translated: String = str(domain.translate(StringName(text)))
	return translated if not translated.is_empty() else text


## The first sentence of a class-reference text, its markup read as plain words: `[param name]`,
## `[member x]`, `[Vector2]` and `[code]..[/code]` become the bare word, bold and italics vanish.
static func first_sentence(raw: String) -> String:
	if raw.is_empty():
		return ""
	var text: String = raw.strip_edges()
	var cut: int = text.find("[codeblock")
	if cut >= 0:
		text = text.substr(0, cut)
	text = text.get_slice("\n", 0).strip_edges()
	text = _plain(text)
	var stop: int = 0
	while true:
		stop = text.find(". ", stop)
		if stop < 0:
			break
		# A sentence ends at ". " unless the dot belongs to an abbreviation (e.g.) or a number.
		var before: String = text.substr(maxi(0, stop - 4), 4)
		if before.ends_with("e.g") or before.ends_with("i.e") or before.ends_with("etc"):
			stop += 2
			continue
		text = text.substr(0, stop + 1)
		break
	return text.strip_edges()


static func _plain(text: String) -> String:
	var plain: String = ""
	var index: int = 0
	while index < text.length():
		var open: int = text.find("[", index)
		if open < 0:
			plain += text.substr(index)
			break
		plain += text.substr(index, open - index)
		var close: int = text.find("]", open)
		if close < 0:
			plain += text.substr(open)
			break
		var tag: String = text.substr(open + 1, close - open - 1)
		var space: int = tag.find(" ")
		var head: String = tag if space < 0 else tag.substr(0, space)
		if head in ["code", "b", "i", "u", "s", "kbd", "center", "/code", "/b", "/i", "/u", "/s", "/kbd", "/center", "/url", "/color", "/font", "/img"]:
			pass
		elif head in ["param", "member", "method", "constant", "signal", "enum", "annotation", "theme_item", "constructor", "operator"] and space > 0:
			plain += tag.substr(space + 1).get_slice(".", 1) if tag.find(".") > 0 and head != "param" else tag.substr(space + 1)
		elif head.begins_with("url") or head.begins_with("color") or head.begins_with("font") or head.begins_with("img"):
			pass
		elif head.begins_with("/") or head == "br" or head == "lb" or head == "rb":
			plain += "[" if head == "lb" else ("]" if head == "rb" else "")
		else:
			# [Vector2], [Node.name] and the like name a type or member: say the word.
			plain += tag.get_slice(".", tag.get_slice_count(".") - 1) if tag.find(".") > 0 and tag.find(" ") < 0 else tag
		index = close + 1
	return plain


# ── Loading and building ──────────────────────────────────────────────────────────────────


static func _file_stem() -> String:
	return "%s/%s" % [cache_directory, str(Engine.get_version_info().get("hash", "dev")).substr(0, 10)]


static func reference_path() -> String:
	return _file_stem() + ".reference.json"


static func docs_path() -> String:
	return _file_stem() + ".docs.json"


static func _ensure_loaded() -> void:
	if _loaded:
		return
	if _thread != null and not _thread.is_alive():
		_thread.wait_to_finish()
		_thread = null
	# Looking for a file that is not there costs a disk hit, so a miss is not re-asked on every key.
	var now: int = Time.get_ticks_msec()
	if now < _next_look:
		return
	_next_look = now + 1500
	var data: Dictionary = _read_json(reference_path())
	if int(data.get("schema", 0)) != SCHEMA:
		return
	_loaded = true
	_builtins = data.get("builtins", {})
	_enums = data.get("enums", {})
	_utilities = data.get("utilities", {})
	for enum_name: Variant in _enums.keys():
		for item: Variant in _enums[enum_name]:
			_enum_of_constant[str((item as Dictionary).get("n", ""))] = str(enum_name)


static func _ensure_docs() -> void:
	if _docs_loaded:
		return
	var data: Dictionary = _read_json(docs_path())
	if int(data.get("schema", 0)) != SCHEMA:
		return
	_docs_loaded = true
	_docs = data.get("classes", {})


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


## Starts building the reference on a thread unless it exists or is already being built. Safe to call
## on every open of a field: it answers immediately either way, and does nothing in a headless run.
static func request_build() -> void:
	if _build_started or _loaded or FileAccess.file_exists(reference_path()):
		return
	if DisplayServer.get_name() == "headless":
		return
	_build_started = true
	_thread = Thread.new()
	_thread.start(build_blocking)


## Builds the reference now and returns true when the files exist afterwards. Runs the engine binary's
## own dump in a temporary folder, reduces it, writes the two files and loads them. A tool or a test
## calls this directly; the editor goes through request_build.
static func build_blocking() -> bool:
	if FileAccess.file_exists(reference_path()) and FileAccess.file_exists(docs_path()):
		reset()
		return true
	var dump_folder: String = ProjectSettings.globalize_path("user://").path_join("class_reference_dump_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(dump_folder)
	var executable: String = OS.get_executable_path()
	var output: Array = []
	var exit_code: int = -1
	if OS.get_name() == "Windows":
		exit_code = OS.execute("cmd", ["/c", "cd /d \"%s\" && \"%s\" --headless --dump-extension-api-with-docs" % [dump_folder, executable]], output)
	else:
		exit_code = OS.execute("sh", ["-c", "cd '%s' && '%s' --headless --dump-extension-api-with-docs" % [dump_folder, executable]], output)
	var dump_path: String = dump_folder.path_join("extension_api.json")
	var built: bool = false
	if exit_code == 0 and FileAccess.file_exists(dump_path):
		var file: FileAccess = FileAccess.open(dump_path, FileAccess.READ)
		var dump: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
		if dump is Dictionary:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_directory))
			built = _write_reduced(dump as Dictionary)
	DirAccess.remove_absolute(dump_path)
	DirAccess.remove_absolute(dump_folder)
	reset()
	return built


static func _write_reduced(dump: Dictionary) -> bool:
	var builtins: Dictionary = {}
	for type_entry: Variant in dump.get("builtin_classes", []):
		var type_data: Dictionary = type_entry as Dictionary
		var type_name: String = str(type_data.get("name", ""))
		# The primitives with no members of their own add nothing to a member list.
		if type_name in ["bool", "int", "float", "Nil"]:
			continue
		var members: Array = []
		for member: Variant in type_data.get("members", []):
			members.append({"n": member.get("name", ""), "t": member.get("type", ""), "d": member.get("description", "")})
		var constants: Array = []
		for constant: Variant in type_data.get("constants", []):
			constants.append({"n": constant.get("name", ""), "t": constant.get("type", ""), "d": constant.get("description", "")})
		var methods: Array = []
		for method: Variant in type_data.get("methods", []):
			var arguments: Array = []
			for argument: Variant in method.get("arguments", []):
				arguments.append({"n": argument.get("name", ""), "t": argument.get("type", ""), "v": argument.get("default_value", "")})
			methods.append({"n": method.get("name", ""), "r": (method.get("return_type", "")),
				"s": bool(method.get("is_static", false)), "va": bool(method.get("is_vararg", false)),
				"a": arguments, "d": method.get("description", "")})
		builtins[type_name] = {"members": members, "constants": constants, "methods": methods,
			"d": type_data.get("brief_description", "")}
	var enums: Dictionary = {}
	for enum_entry: Variant in dump.get("global_enums", []):
		var values: Array = []
		for value: Variant in (enum_entry as Dictionary).get("values", []):
			values.append({"n": value.get("name", ""), "v": value.get("value", 0), "d": value.get("description", "")})
		enums[str((enum_entry as Dictionary).get("name", ""))] = values
	var utilities: Dictionary = {}
	for utility_entry: Variant in dump.get("utility_functions", []):
		var utility_arguments: Array = []
		for argument: Variant in (utility_entry as Dictionary).get("arguments", []):
			utility_arguments.append({"n": argument.get("name", ""), "t": argument.get("type", ""), "v": argument.get("default_value", "")})
		utilities[str((utility_entry as Dictionary).get("name", ""))] = {"a": utility_arguments,
			"r": (utility_entry as Dictionary).get("return_type", ""),
			"va": bool((utility_entry as Dictionary).get("is_vararg", false)),
			"d": (utility_entry as Dictionary).get("description", "")}
	var docs: Dictionary = {}
	for class_entry: Variant in dump.get("classes", []):
		var class_data: Dictionary = class_entry as Dictionary
		var class_docs: Dictionary = {"b": class_data.get("brief_description", ""), "p": {}, "m": {}, "s": {}, "c": {}}
		for pair: Array in [["properties", "p"], ["methods", "m"], ["signals", "s"], ["constants", "c"]]:
			for item: Variant in class_data.get(pair[0], []):
				var description: String = str((item as Dictionary).get("description", ""))
				if not description.is_empty():
					(class_docs[pair[1]] as Dictionary)[str((item as Dictionary).get("name", ""))] = description
		docs[str(class_data.get("name", ""))] = class_docs
	return _write_json(reference_path(), {"schema": SCHEMA, "builtins": builtins, "enums": enums, "utilities": utilities}) \
		and _write_json(docs_path(), {"schema": SCHEMA, "classes": docs})


## Written beside its target and moved into place, so a second process reading while this one writes
## sees the old file or the whole new one, never half of it.
static func _write_json(path: String, data: Dictionary) -> bool:
	var temporary: String = "%s.%d.tmp" % [path, OS.get_process_id()]
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(temporary, path) == OK
