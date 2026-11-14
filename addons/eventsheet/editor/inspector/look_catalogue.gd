@tool
class_name EventSheetInspectorLookCatalogue
extends RefCounted

## THE CATALOGUE OF INSPECTOR LOOKS THAT ARE FILES. Every `.gd` in the plugin's own looks folder and in
## `res://eventsheet_addons/looks/` that extends EventSheetInspectorLook is one look. Everything the
## editor lists about a look (its name, hover, the types it works on, the questions it asks, the line
## it writes) is read from the file's TEXT, once, without compiling or running it. That is also what
## lets the suite check every look: an EditorProperty cannot be built outside the editor, but its
## text can be read anywhere.
##
## An entry is {id, name, label, tip, types, fields, questions, template, writes, script_path, source}:
##   id / name   the file's base name; also the word after `eventsheet:` in the marker
##   label / tip the first `##` line after `extends`, and the `##` lines that follow it
##   types       what `works_on` defaults to, split on commas ([] = any type)
##   fields      the questions in the shape the Variable window takes: [key, label, kind, default, hint, hover]
##               (the label is the question's first `##` line, or its name as written when it has none)
##   questions   the same questions with their declared type: {key, label, type_name, kind, default, doc, hover, choices}
##   template    the optional `const MARKER_TEMPLATE` text, "" for the plain positional spelling
##   preview     the optional `const PREVIEW_SENTENCE` text the preview card says, "" for none
##   also_draws  the optional `const ALSO_DRAWS_ON` types: drawn when a marker asks, never offered in the window
##   writes      an example of the line the look writes, filled with its defaults
##   source      "shipped", "project" (a project file of the same name wins) or "registered" (a path
##               `EventSheets.register_inspector_look` accepted, listed after the project's own)
##
## The marker a look writes is `eventsheet:<name>[:<value>[:<value>...]]`, one value per question in file
## order, or the template with each `{key}` replaced when the file names one.

const LOOK_LINES_PATH: String = "res://addons/eventforge/look_lines.gd"
const SHIPPED_FOLDER: String = "res://addons/eventsheet/looks"
const PROJECT_FOLDER: String = "res://eventsheet_addons/looks"
## The names the compiler and the importer already own: a marker with one of these words is carried by
## the structured attributes written before looks became files, and never by the generic spelling.
const LEGACY_WORDS: PackedStringArray = ["progress_bar", "min_max", "vector_dial", "toggle_row", "unit", "corners", "swatch_row",
	"texture_preview", "curve_editor", "table", "table_row", "cards"]
## The variable that says which types a look works on. It is a setting of the look, not a question.
const WORKS_ON: String = "works_on"
const TEMPLATE_CONSTANT: String = "MARKER_TEMPLATE"
## The optional constant that names types a look DRAWS when a marker already asks for it, without offering
## the look for them in the Variable window (a look for text that also reads an int a script already marked).
const ALSO_DRAWS_CONSTANT: String = "ALSO_DRAWS_ON"
## The optional constant holding the sentence the preview card says under a variable wearing the look.
const PREVIEW_CONSTANT: String = "PREVIEW_SENTENCE"
const VARIANT_TYPES: Dictionary = {"int": TYPE_INT, "float": TYPE_FLOAT, "bool": TYPE_BOOL, "String": TYPE_STRING,
	"StringName": TYPE_STRING_NAME, "Color": TYPE_COLOR, "Vector2": TYPE_VECTOR2, "Vector2i": TYPE_VECTOR2I,
	"Vector3": TYPE_VECTOR3, "Vector3i": TYPE_VECTOR3I, "Vector4": TYPE_VECTOR4, "Vector4i": TYPE_VECTOR4I,
	"Rect2": TYPE_RECT2, "NodePath": TYPE_NODE_PATH, "Array": TYPE_ARRAY, "Dictionary": TYPE_DICTIONARY}

static var _entries: Array[Dictionary] = []
static var _key: String = ""
static var _built: bool = false
static var _engine_properties: Dictionary = {}
static var _folders_for_tests: PackedStringArray = PackedStringArray()


## Every look, shipped ones first in name order, then the project's own. A project file with a
## shipped file's name takes that file's place.
static func entries() -> Array[Dictionary]:
	var key: String = _listing_key()
	if _built and key == _key:
		return _entries
	var by_name: Dictionary = {}
	var order: PackedStringArray = PackedStringArray()
	for folder: String in folders():
		var source: String = "shipped" if folder == SHIPPED_FOLDER else "project"
		for file_name: String in _sorted_files(folder):
			var path: String = "%s/%s" % [folder, file_name]
			var entry: Dictionary = read_look(path, FileAccess.get_file_as_string(path), source)
			if entry.is_empty():
				continue
			var look_name: String = str(entry["name"])
			if not by_name.has(look_name):
				order.append(look_name)
			by_name[look_name] = entry
	# Looks a script registered from anywhere else come last. A file in the project's own looks folder of the
	# same name still wins, so a project can always replace what an addon brought.
	for path: String in _registered_paths():
		var registered: Dictionary = read_look(path, FileAccess.get_file_as_string(path), "registered")
		if registered.is_empty():
			continue
		var registered_name: String = str(registered["name"])
		if by_name.has(registered_name) and str(by_name[registered_name]["source"]) == "project":
			continue
		if not by_name.has(registered_name):
			order.append(registered_name)
		by_name[registered_name] = registered
	var built: Array[Dictionary] = []
	for look_name: String in order:
		built.append(by_name[look_name])
	_entries = built
	_key = key
	_built = true
	return _entries


## The entry for a look name, {} when no file of that name is installed.
static func entry(look_name: String) -> Dictionary:
	for candidate: Dictionary in entries():
		if str(candidate["name"]) == look_name:
			return candidate
	return {}


## Forgets what was read, so the next question reads the folders again. The listing is also re-read
## by itself whenever a file is added, removed or saved.
static func forget() -> void:
	_built = false
	_key = ""
	_entries = []


static func folders() -> PackedStringArray:
	return _folders_for_tests if not _folders_for_tests.is_empty() else PackedStringArray([SHIPPED_FOLDER, PROJECT_FOLDER])


## Reads these folders instead of the two real ones (the suite points the second at a folder of its
## own so it never writes into the project). An empty list puts the real ones back.
static func use_folders(list: PackedStringArray) -> void:
	_folders_for_tests = list
	forget()


## The file names, the modified times of the files and nothing else: cheap enough to ask on every
## question, and it changes the moment a look is added, removed or saved.
static func _listing_key() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for folder: String in folders():
		for file_name: String in _sorted_files(folder):
			parts.append("%s/%s@%d" % [folder, file_name, FileAccess.get_modified_time("%s/%s" % [folder, file_name])])
	for path: String in _registered_paths():
		parts.append("%s@%d" % [path, FileAccess.get_modified_time(path)])
	return "|".join(parts)


## The paths `EventSheets.register_inspector_look` accepted. Read through the registry file by path, so
## the catalogue never names the public API.
static func _registered_paths() -> PackedStringArray:
	if not _folders_for_tests.is_empty():
		return PackedStringArray()
	return load("res://addons/eventsheet/api/extension_registries.gd").call("inspector_look_paths")


static func _sorted_files(folder: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(folder):
		return found
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.get_extension() == "gd":
			found.append(file_name)
	found.sort()
	return found


## One look from a file's text, {} when the file is not a look. `path` only supplies the name.
static func read_look(path: String, source: String, origin: String = "project") -> Dictionary:
	var look_name: String = path.get_file().get_basename()
	if not look_name.is_valid_identifier() or look_name == "none":
		return {}
	var lines: PackedStringArray = source.split("\n")
	var extends_at: int = -1
	for index: int in range(lines.size()):
		if lines[index].strip_edges(false, true) == "extends EventSheetInspectorLook":
			extends_at = index
			break
	if extends_at < 0:
		return {}
	var cursor: int = extends_at + 1
	while cursor < lines.size() and lines[cursor].strip_edges().is_empty():
		cursor += 1
	var doc: PackedStringArray = PackedStringArray()
	while cursor < lines.size() and lines[cursor].begins_with("##"):
		doc.append(_doc_text(lines[cursor]))
		cursor += 1
	var label: String = ""
	var tip_words: PackedStringArray = PackedStringArray()
	for doc_index: int in range(doc.size()):
		if doc_index == 0:
			label = doc[0]
		elif not doc[doc_index].is_empty():
			tip_words.append(doc[doc_index])
	if label.is_empty():
		label = look_name.capitalize()
	var types: Array = []
	var questions: Array[Dictionary] = []
	var template: String = ""
	var also_draws: Array = []
	var preview: String = ""
	var pending_doc: PackedStringArray = PackedStringArray()
	var pending_choices: Array = []
	for index: int in range(cursor, lines.size()):
		var line: String = lines[index].strip_edges(false, true)
		if line.begins_with("##"):
			pending_doc.append(_doc_text(line))
			continue
		if line.begins_with("@warning_ignore"):
			continue
		if line.begins_with("const %s" % PREVIEW_CONSTANT):
			preview = _quoted_default(_default_of(line))
			pending_doc = PackedStringArray()
			continue
		if line.begins_with("const %s" % ALSO_DRAWS_CONSTANT):
			for type_word: String in _quoted_default(_default_of(line)).split(",", false):
				also_draws.append(type_word.strip_edges())
			pending_doc = PackedStringArray()
			continue
		if line.begins_with("const %s" % TEMPLATE_CONSTANT):
			template = _quoted_default(_default_of(line))
			pending_doc = PackedStringArray()
			continue
		if line.begins_with("@export_enum(") and not line.contains(") var "):
			pending_choices = _enum_choices(line)
			continue
		if line.begins_with("@export"):
			var declaration: Dictionary = _read_declaration(line)
			if not declaration.is_empty():
				var variable_name: String = str(declaration["name"])
				if variable_name == WORKS_ON:
					for type_word: String in str(_quoted_default(str(declaration["default"]))).split(",", false):
						types.append(type_word.strip_edges())
				elif not _is_engine_property(variable_name):
					var question: Dictionary = _question(declaration, pending_doc, pending_choices)
					if not question.is_empty():
						questions.append(question)
			pending_doc = PackedStringArray()
			pending_choices = []
			continue
		pending_doc = PackedStringArray()
		pending_choices = []
	var fields: Array = []
	for question: Dictionary in questions:
		fields.append([question["key"], question["label"], question["kind"], question["default"],
			question["choices"] if str(question["kind"]) == "pick" else question["doc"], question["hover"]])
	var entry: Dictionary = {"id": look_name, "name": look_name, "label": label, "tip": " ".join(tip_words),
		"types": types, "fields": fields, "questions": questions, "template": template, "also_draws": also_draws, "preview": preview, "script_path": path, "source": origin}
	var defaults: Dictionary = {}
	for question: Dictionary in questions:
		defaults[question["key"]] = question["default"]
	entry["writes"] = "@export_custom(PROPERTY_HINT_NONE, \"%s\")" % marker_text(entry, defaults, true)
	# A shipped look that keeps Godot's own export line says THAT line, not the marker.
	if origin == "shipped" and not load(LOOK_LINES_PATH).writes_text(look_name).is_empty():
		entry["writes"] = load(LOOK_LINES_PATH).writes_text(look_name)
	return entry


## Copies a look that ships with the plugin into the project's looks folder, byte for byte. The project's
## copy then wins by name, so it is the one the Inspector draws and the one to change. Nothing is ever
## overwritten: a name already taken in the project says so and writes nothing. Returns
## {ok, path, message}, the message being the sentence to show.
static func copy_into_project(look_name: String, project_folder: String = PROJECT_FOLDER) -> Dictionary:
	var shipped: String = "%s/%s.gd" % [SHIPPED_FOLDER, look_name]
	if not look_name.is_valid_identifier() or not FileAccess.file_exists(shipped):
		return {"ok": false, "path": "", "message": EventSheetL10n.translate("Only a look that ships with the plugin can be copied.")}
	var target: String = "%s/%s.gd" % [project_folder, look_name]
	if FileAccess.file_exists(target):
		return {"ok": false, "path": target, "message": EventSheetL10n.translate("%s is already in your project, so nothing was copied.") % target}
	DirAccess.make_dir_recursive_absolute(project_folder)
	var written: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	if written == null:
		return {"ok": false, "path": target, "message": EventSheetL10n.translate("%s could not be written.") % target}
	written.store_string(FileAccess.get_file_as_string(shipped))
	written.close()
	forget()
	return {"ok": true, "path": target, "message": EventSheetL10n.translate("Copied to %s. This copy is yours to change, and it is the one the Inspector uses.") % target}


## The name a typed look name becomes: words in snake_case, the way the file will be called.
static func look_file_name(typed: String) -> String:
	return typed.strip_edges().to_snake_case()


## What stops a new look of this name and these types, as the sentence to show, or "" when nothing does.
## `types` is the list the look works on as typed ("int, float"; empty means any type).
static func new_look_problem(typed_name: String, types: String, folder: String = PROJECT_FOLDER) -> String:
	var look_name: String = look_file_name(typed_name)
	if look_name.is_empty():
		return EventSheetL10n.translate("Name the look to make it.")
	if not look_name.is_valid_identifier() or look_name == "none":
		return EventSheetL10n.translate("\"%s\" cannot be a look name.") % typed_name.strip_edges()
	if FileAccess.file_exists("%s/%s.gd" % [folder, look_name]):
		return EventSheetL10n.translate("%s.gd is already in the looks folder.") % look_name
	for word: String in types.split(",", false):
		if not _known_type(word.strip_edges()):
			return EventSheetL10n.translate("\"%s\" is not a type or a class.") % word.strip_edges()
	return ""


static func _known_type(word: String) -> bool:
	if VARIANT_TYPES.has(word) or ClassDB.class_exists(word):
		return true
	for info: Dictionary in ProjectSettings.get_global_class_list():
		if str(info.get("class", "")) == word:
			return true
	return false


## The text of a new look: the smallest one that works, a plain field that shows the value. Its name and
## hover are the first `##` lines, `works_on` is the list of types, and the three functions are the ones
## Godot's Inspector calls. It is written in the shape the compiler writes, so it opens as a sheet and
## saves back byte for byte.
static func new_look_source(typed_name: String, types: String) -> String:
	var look_name: String = look_file_name(typed_name)
	var works_on: PackedStringArray = PackedStringArray()
	for word: String in types.split(",", false):
		works_on.append(word.strip_edges())
	var lines: PackedStringArray = PackedStringArray([
		"@tool", "extends EventSheetInspectorLook", "",
		"## %s" % look_name.capitalize(),
		"## Shows the value as text. Change what it draws, and it is drawn in the Inspector.", "",
		"## The kinds of property this look can be put on.",
		"@export var works_on: String = \"%s\"" % ",".join(works_on), "",
		"var _label: Label", "", "",
		"func _look_built() -> void:",
		"\t_label = Label.new()",
		"\tadd_child(_label)", "", "",
		"func _value_shown(value: Variant) -> void:",
		"\t_label.text = str(value)", ""])
	return "\n".join(lines)


## Writes a new look into the project's looks folder and returns {ok, path, message}. Nothing is overwritten.
static func create_look(typed_name: String, types: String, folder: String = PROJECT_FOLDER) -> Dictionary:
	var problem: String = new_look_problem(typed_name, types, folder)
	if not problem.is_empty():
		return {"ok": false, "path": "", "message": problem}
	var path: String = "%s/%s.gd" % [folder, look_file_name(typed_name)]
	DirAccess.make_dir_recursive_absolute(folder)
	var written: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if written == null:
		return {"ok": false, "path": path, "message": EventSheetL10n.translate("%s could not be written.") % path}
	written.store_string(new_look_source(typed_name, types))
	written.close()
	forget()
	return {"ok": true, "path": path, "message": ""}


## Whether a look is a node that already has a property of this name (`name`, `size`, `visible`...). Such
## a variable cannot be a question: setting it from the marker would set the node's own property.
static func _is_engine_property(variable_name: String) -> bool:
	if _engine_properties.is_empty():
		for property: Dictionary in ClassDB.class_get_property_list("EditorProperty"):
			_engine_properties[str(property["name"])] = true
	return _engine_properties.has(variable_name)


static func _doc_text(line: String) -> String:
	return line.substr(2).strip_edges()


## `@export var name: Type = default` (also `@export_enum(...) var ...` and `:=`) as
## {name, type_name, default}; {} for a line that is not a plain exported variable.
static func _read_declaration(line: String) -> Dictionary:
	var at: int = line.find(" var ")
	if at < 0:
		return {}
	var rest: String = line.substr(at + 5).strip_edges()
	var name_match: RegExMatch = RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*").search(rest)
	if name_match == null:
		return {}
	var variable_name: String = name_match.get_string()
	var name_end: int = variable_name.length()
	var tail: String = rest.substr(name_end).strip_edges()
	var type_name: String = ""
	var default_text: String = ""
	if tail.begins_with(":="):
		default_text = tail.substr(2).strip_edges()
	elif tail.begins_with(":"):
		var typed: String = tail.substr(1).strip_edges()
		var equals_at: int = typed.find("=")
		type_name = (typed if equals_at < 0 else typed.left(equals_at)).strip_edges()
		default_text = "" if equals_at < 0 else typed.substr(equals_at + 1).strip_edges()
	elif tail.begins_with("="):
		default_text = tail.substr(1).strip_edges()
	default_text = _without_comment(default_text)
	if type_name.is_empty():
		type_name = _inferred_type(default_text)
	var choices: Array = _enum_choices(line) if line.begins_with("@export_enum(") else []
	return {"name": variable_name, "type_name": type_name, "default": default_text, "choices": choices}


## The text after the `=` of a constant or variable line.
static func _default_of(line: String) -> String:
	var equals_at: int = line.find("=")
	return "" if equals_at < 0 else _without_comment(line.substr(equals_at + 1).strip_edges())


static func _without_comment(text: String) -> String:
	var in_quote: bool = false
	for index: int in range(text.length()):
		if text[index] == "\"":
			in_quote = not in_quote
		elif text[index] == "#" and not in_quote:
			return text.left(index).strip_edges()
	return text


static func _quoted_default(text: String) -> String:
	var trimmed: String = text.strip_edges()
	if trimmed.length() >= 2 and trimmed.begins_with("\"") and trimmed.ends_with("\""):
		return trimmed.substr(1, trimmed.length() - 2)
	return trimmed


static func _inferred_type(default_text: String) -> String:
	if default_text == "true" or default_text == "false":
		return "bool"
	if default_text.begins_with("\""):
		return "String"
	if default_text.is_valid_int():
		return "int"
	if default_text.is_valid_float():
		return "float"
	return ""


## The words of an `@export_enum("a", "b")` annotation.
static func _enum_choices(line: String) -> Array:
	var open: int = line.find("(")
	var close: int = line.find(")")
	var choices: Array = []
	if open < 0 or close < open:
		return choices
	for part: String in line.substr(open + 1, close - open - 1).split(",", false):
		var word: String = _quoted_default(part.strip_edges())
		if not word.is_empty():
			choices.append(word)
	return choices


## One question from a declaration, {} when its type cannot be asked for in the Variable window.
static func _question(declaration: Dictionary, doc: PackedStringArray, pending_choices: Array) -> Dictionary:
	var type_name: String = str(declaration["type_name"])
	var choices: Array = declaration["choices"] if not (declaration["choices"] as Array).is_empty() else pending_choices
	var kind: String = ""
	var default_text: String = str(declaration["default"])
	match type_name:
		"int", "float":
			kind = "number"
			if not default_text.is_valid_float():
				default_text = "0"
		"bool":
			kind = "tick"
		"String", "StringName":
			kind = "pick" if not choices.is_empty() else "text"
			default_text = _quoted_default(default_text)
		_:
			return {}
	# The first `##` line is the label the window shows; the lines after it are the hint (the grey example
	# in a text box). With no `##` line the label is the name as written. The hover always says the name.
	var key: String = str(declaration["name"])
	var label: String = key
	var rest: PackedStringArray = PackedStringArray()
	for doc_index: int in range(doc.size()):
		if doc_index == 0 and not doc[0].is_empty():
			label = doc[0]
		elif not doc[doc_index].is_empty():
			rest.append(doc[doc_index])
	var hint: String = " ".join(rest)
	return {"key": key, "type_name": type_name, "kind": kind, "default": default_text if kind != "tick" else default_text == "true",
		"label": label, "doc": hint, "hover": key if hint.is_empty() else "%s\n%s" % [key, hint], "choices": choices}


## The text a value is written as inside the marker, or null when this value cannot ride a marker (it
## holds a separator or a quote), so nothing is written and the property stays a plain field.
static func value_text(question: Dictionary, value: Variant) -> Variant:
	var kind: String = str(question["kind"])
	if kind == "tick":
		return "true" if bool(value) else "false"
	var text: String
	if value is float or value is int:
		text = str(int(value)) if str(question["type_name"]) == "int" else String.num(float(value))
	else:
		text = str(value).strip_edges()
	if kind == "number":
		if text.is_empty():
			text = str(question["default"])
		if not text.is_valid_float():
			return null
		return text
	if text.contains(":") or text.contains("\"") or text.contains("\n"):
		return null
	return text


## The line a look writes for `values` (question key -> value), without its `@export_custom` wrapper.
## "" when a value cannot ride a marker. `lenient` writes the defaults of anything that cannot.
static func marker_text(look: Dictionary, values: Dictionary, lenient: bool = false) -> String:
	var written: Dictionary = {}
	var order: PackedStringArray = PackedStringArray()
	for question: Dictionary in look["questions"]:
		var key: String = str(question["key"])
		var asked: Variant = value_text(question, values.get(key, question["default"]))
		if asked == null:
			if not lenient:
				return ""
			asked = value_text(question, question["default"])
		var text: String = "" if asked == null else str(asked)
		written[key] = text
		order.append(text)
	var template: String = str(look["template"])
	var body: String
	if template.is_empty():
		body = ":".join(order)
	else:
		body = template
		for key: Variant in written:
			body = body.replace("{%s}" % key, str(written[key]))
	return "eventsheet:%s" % look["name"] if body.is_empty() else "eventsheet:%s:%s" % [look["name"], body]


## The texts a look writes after its name, for `values` (question key -> value): what the Variable
## window keeps in the variable's `look_args`. A value that cannot ride a marker is written as the
## question's default.
static func look_args(look: Dictionary, values: Dictionary) -> Array:
	var written: PackedStringArray = marker_text(look, values, true).split(":")
	return Array(written.slice(2))


## The values a marker's arguments carry, by question key: the inverse of `marker_text`. Arguments
## missing from a shorter marker take the question's default.
static func marker_values(look: Dictionary, args: Array) -> Dictionary:
	var values: Dictionary = {}
	var questions: Array = look["questions"]
	var template: String = str(look["template"])
	var pieces: Dictionary = {}
	if not template.is_empty():
		pieces = _template_values(template, str(args[0]) if args.size() > 0 else "")
	for index: int in range(questions.size()):
		var question: Dictionary = questions[index]
		var key: String = str(question["key"])
		var text: String = ""
		var has_text: bool = false
		if not template.is_empty():
			has_text = pieces.has(key)
			text = str(pieces.get(key, ""))
		elif index < args.size():
			has_text = true
			text = str(args[index])
		values[key] = _typed(question, text) if has_text else question["default"]
	return values


## The text a template was filled in as, read back by key.
static func _template_values(template: String, text: String) -> Dictionary:
	var pattern: String = ""
	var keys: PackedStringArray = PackedStringArray()
	var index: int = 0
	while index < template.length():
		var open: int = template.find("{", index)
		var close: int = template.find("}", open + 1) if open >= 0 else -1
		if open < 0 or close < 0:
			pattern += _escaped(template.substr(index))
			break
		pattern += _escaped(template.substr(index, open - index))
		keys.append(template.substr(open + 1, close - open - 1))
		pattern += "(.*?)"
		index = close + 1
	var matched: RegExMatch = RegEx.create_from_string("^%s$" % pattern).search(text)
	var found: Dictionary = {}
	if matched == null:
		return found
	for key_index: int in range(keys.size()):
		found[keys[key_index]] = matched.get_string(key_index + 1)
	return found


static func _escaped(literal: String) -> String:
	var safe: String = ""
	for character: String in literal:
		safe += ("\\" + character) if ".*+?^$()|[]{}\\".contains(character) else character
	return safe


static func _typed(question: Dictionary, text: String) -> Variant:
	match str(question["type_name"]):
		"int":
			return text.to_int()
		"float":
			return text.to_float()
		"bool":
			return text == "true"
	return text


## Whether the look can draw a property of this type, by what the Inspector says it holds.
## `object` and `property` are only asked for a class name in `works_on` (a Texture2D, a Curve).
static func accepts(look: Dictionary, type: int, object: Object = null, property: String = "") -> bool:
	var types: Array = look["types"]
	if types.is_empty():
		return true
	for type_name: Variant in types + (look.get("also_draws", []) as Array):
		var word: String = str(type_name)
		if VARIANT_TYPES.has(word):
			if type == int(VARIANT_TYPES[word]) or (word == "String" and type == TYPE_STRING_NAME):
				return true
		elif type == TYPE_OBJECT and ClassDB.class_exists(word):
			var value: Variant = object.get(property) if object != null else null
			if value == null or (value is Object and (value as Object).is_class(word)):
				return true
		elif type == TYPE_ARRAY and word.begins_with("Array"):
			return true
	return false


## A look's drawing control, built and told what the marker said. The caller adds it to the Inspector.
## Null when the file cannot be loaded as a look, or when the look says the marker's values cannot be drawn.
static func build(look: Dictionary, args: Array) -> Object:
	var script: Variant = load(str(look["script_path"]))
	if not (script is GDScript) or not (script as GDScript).can_instantiate():
		return null
	var control: Object = (script as GDScript).new()
	var values: Dictionary = marker_values(look, args)
	for question: Dictionary in look["questions"]:
		var key: String = str(question["key"])
		# A question the marker left out keeps the default the file declares, as the type it asked for.
		var value: Variant = values[key]
		control.set(key, _typed(question, str(value)) if value is String and str(question["type_name"]) != "String" else value)
	control.set("marker_args", args)
	if control.has_method("_can_draw") and not bool(control.call("_can_draw")):
		control.free()
		return null
	return control
