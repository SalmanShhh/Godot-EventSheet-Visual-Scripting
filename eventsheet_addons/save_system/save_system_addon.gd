## @ace_tags(persistence)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/save_system/icon.svg")
class_name SaveSystemAddon
extends Node
## Slot-based persistence as the SaveSystem autoload: every sheet saves and loads values by name, each slot is its own file, and the location, format, and encryption are set once in the Inspector. Save Game fires On Before Save so every sheet writes its own piece, and Load Game fires On After Load so every sheet reads it back.

## @ace_trigger
## @ace_name("On Save Written")
## @ace_category("Save System")
signal save_written(slot_index: int)
## @ace_trigger
## @ace_name("On Before Save")
## @ace_category("Save System")
signal before_save(slot_index: int)
## @ace_trigger
## @ace_name("On After Load")
## @ace_category("Save System")
signal after_load(slot_index: int)

var autosave_accumulator: float = 0.0
## Seconds between autosaves (0 = off). Fires On Before Save first.
@export_range(0, 600, 1) var autosave_interval: float = 0.0
## Non-empty = encrypted saves (keep the key out of screenshots!).
@export var encryption_key: String = ""
## {slot} becomes the slot number.
@export var file_pattern: String = "save_{slot}.cfg"
## config = ConfigFile (Godot-native), json = readable text, binary = compact store_var, csv = spreadsheet rows, ini = portable [section] key=value, xml = structured <entry> tags. All six preserve exact types.
@export_enum("config", "json", "binary", "csv", "ini", "xml") var format: String = "config"
## Nodes in this group (and their behaviors) auto-save via save_state()/load_state() on Save Game / Load Game.
@export var persist_group: String = "persist"
## Where save files live.
@export var save_directory: String = "user://"
## ConfigFile section / JSON namespace for values.
@export var section: String = "save"
## Active save slot (each slot is its own file).
@export_group("Save System")
@export_range(0, 9, 1) var slot: int = 0

func _open_read(path: String) -> FileAccess:
	return FileAccess.open_encrypted_with_pass(path, FileAccess.READ, encryption_key) if not encryption_key.is_empty() else FileAccess.open(path, FileAccess.READ)
func _open_write(path: String) -> FileAccess:
	return FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, encryption_key) if not encryption_key.is_empty() else FileAccess.open(path, FileAccess.WRITE)
# JSON has no integer type - JSON.parse reloads every number as a float (even 5
# becomes 5.0, and a 64-bit int loses precision), and it cannot hold Vector2/Color.
# So ints and non-JSON-native Variants travel as a one-key wrapper and come back
# through str_to_var, keeping their exact type. Floats/strings/bools stay bare so
# the file is still readable. The key is long and namespaced so a real one-key user
# dictionary is extremely unlikely to be mistaken for a wrapped value.
const VAR_WRAPPER_KEY: String = "__eventsheet_var"
# _read_all sets _last_read_ok = false when a slot file EXISTS but cannot be read
# (bad decrypt key, corrupt JSON, truncated binary). Writers check the flag and
# refuse to overwrite a slot they could not read, so a failed read never wipes a
# good save on the next write or autosave. A genuinely absent file reads as OK.
var _last_read_ok: bool = true

func _process(delta: float) -> void:
	if autosave_interval <= 0.0:
		return
	autosave_accumulator += delta
	if autosave_accumulator >= autosave_interval:
		autosave_accumulator = 0.0
		save_game()

## @ace_action
## @ace_name("Save Value")
## @ace_category("Save System")
## @ace_description("Writes ANY value (number, text, Vector2, Color, Dictionary…) under the key.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_value({key}, {value})")
func save_value(key: String, value) -> void:
	var data: Dictionary = _read_all()
	if not _last_read_ok:
		push_error("Save System: slot %d exists but could not be read - refusing to overwrite it." % slot)
		return
	data[key] = value
	_write_all(data)

## @ace_expression
## @ace_name("Load Value")
## @ace_category("Save System")
## @ace_description("Reads any value (your default when missing).")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.load_value({key}, {default_value})")
func load_value(key: String, default_value) -> Variant:
	return _read_all().get(key, default_value)

## @ace_action
## @ace_name("Save Number")
## @ace_category("Save System")
## @ace_description("Writes a number under the key (active slot).")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_number({key}, {value})")
func save_number(key: String, value: float) -> void:
	save_value(key, value)

## @ace_expression
## @ace_name("Load Number")
## @ace_category("Save System")
## @ace_description("Reads a number (0 when missing).")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.load_number({key})")
func load_number(key: String) -> float:
	return float(load_value(key, 0.0))

## @ace_action
## @ace_name("Save Text")
## @ace_category("Save System")
## @ace_description("Writes a string under the key (active slot).")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_text({key}, {value})")
func save_text(key: String, value: String) -> void:
	save_value(key, value)

## @ace_expression
## @ace_name("Load Text")
## @ace_category("Save System")
## @ace_description("Reads a string ("" when missing).")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.load_text({key})")
func load_text(key: String) -> String:
	return str(load_value(key, ""))

## @ace_condition
## @ace_name("Has Save Key")
## @ace_category("Save System")
## @ace_description("Whether the key exists in the active slot.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.has_save_key({key})")
func has_save_key(key: String) -> bool:
	return _read_all().has(key)

## @ace_expression
## @ace_name("Read All")
## @ace_category("Save System")
## @ace_description("Reads the whole active slot as one Dictionary (every saved key and value).")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.read_all()")
func read_all() -> Dictionary:
	return _read_all()

## @ace_expression
## @ace_name("List Save Keys")
## @ace_category("Save System")
## @ace_description("The keys stored in the active slot (loop them to read a whole save).")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_keys()")
func save_keys() -> Array:
	return _read_all().keys()

## @ace_expression
## @ace_name("Read Save File")
## @ace_category("Save System")
## @ace_description("Reads ANY save file at a path in the given format (config/json/binary/csv/ini/xml; blank = the active format) and returns its Dictionary.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.read_file({path}, {file_format})")
func read_file(path: String, file_format: String) -> Dictionary:
	return _read_path(path, file_format if not file_format.is_empty() else format)

## @ace_expression
## @ace_name("Save File Format")
## @ace_category("Save System")
## @ace_description("Detects the format of the save file at the path (config/json/binary/csv/ini/xml), or "" when it is missing or unrecognised. Feed it to Read Save File.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_file_format({path})")
func save_file_format(path: String) -> String:
	return _detect_format(path)

## @ace_condition
## @ace_name("Save File Is Format")
## @ace_category("Save System")
## @ace_description("Whether the save file at the path is the given format (config/json/binary/csv/ini/xml).")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_file_is_format({path}, {expected_format})")
func save_file_is_format(path: String, expected_format: String) -> bool:
	return _detect_format(path) == expected_format

## @ace_condition
## @ace_name("Save Format Is")
## @ace_category("Save System")
## @ace_description("Whether the active save format (the Inspector format property) equals the given one.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_format_is({expected_format})")
func save_format_is(expected_format: String) -> bool:
	return format == expected_format

## @ace_action
## @ace_name("Delete Slot")
## @ace_category("Save System")
## @ace_description("Removes the active slot's save file.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.delete_slot()")
func delete_slot() -> void:
	if FileAccess.file_exists(_slot_path()):
		DirAccess.remove_absolute(_slot_path())

## @ace_action
## @ace_featured
## @ace_name("Save Game")
## @ace_category("Save System")
## @ace_description("Broadcasts On Before Save (every sheet writes its state), snapshots every node in the persist group, then fires On Save Written.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_game()")
func save_game() -> void:
	before_save.emit(slot)
	var data: Dictionary = _read_all()
	if not _last_read_ok:
		push_error("Save System: slot %d exists but could not be read - refusing to overwrite it." % slot)
		return
	var persisted: Dictionary = _collect_group_state(persist_group)
	if not persisted.is_empty():
		data["__persist"] = persisted
	if _write_all(data):
		save_written.emit(slot)

## @ace_action
## @ace_featured
## @ace_name("Load Game")
## @ace_category("Save System")
## @ace_description("Restores every persist-group snapshot, then broadcasts On After Load so every sheet reads its state back.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.load_game()")
func load_game() -> void:
	var data: Dictionary = _read_all()
	if data.get("__persist", null) is Dictionary:
		_apply_states(data["__persist"] as Dictionary)
	after_load.emit(slot)

## @ace_action
## @ace_name("Save Node State")
## @ace_category("Save System")
## @ace_description("Snapshots a node and its behaviors (any child with save_state) under the key.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_node_state({node}, {key})")
func save_node_state(node: Node, key: String) -> void:
	save_value(key, _collect_node_state(node))

## @ace_action
## @ace_name("Load Node State")
## @ace_category("Save System")
## @ace_description("Restores a node and its behaviors from the key's snapshot.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.load_node_state({node}, {key})")
func load_node_state(node: Node, key: String) -> void:
	var states: Variant = load_value(key, {})
	if states is Dictionary:
		_apply_node_state(node, states as Dictionary)

## @ace_action
## @ace_name("Save Group State")
## @ace_category("Save System")
## @ace_description("Snapshots every node in the scene-tree group (and their behaviors) under the key.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_group_state({group}, {key})")
func save_group_state(group: String, key: String) -> void:
	save_value(key, _collect_group_state(group))

## @ace_action
## @ace_name("Load Group State")
## @ace_category("Save System")
## @ace_description("Restores the group snapshot saved under the key (nodes matched by scene path).")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.load_group_state({key})")
func load_group_state(key: String) -> void:
	var states: Variant = load_value(key, {})
	if states is Dictionary:
		_apply_states(states as Dictionary)

## @ace_action
## @ace_name("Save Singleton State")
## @ace_category("Save System")
## @ace_description("Snapshots an autoload addon (Currency Ledger, Upgrades, Prestige...) by its autoload name.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_singleton_state({singleton_name}, {key})")
func save_singleton_state(singleton_name: String, key: String) -> void:
	save_value(key, _collect_node_state(get_node_or_null("/root/" + singleton_name)))

## @ace_action
## @ace_name("Load Singleton State")
## @ace_category("Save System")
## @ace_description("Restores an autoload addon's snapshot from the key.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.load_singleton_state({singleton_name}, {key})")
func load_singleton_state(singleton_name: String, key: String) -> void:
	var states: Variant = load_value(key, {})
	if states is Dictionary:
		_apply_node_state(get_node_or_null("/root/" + singleton_name), states as Dictionary)

## @ace_condition
## @ace_name("Slot Exists")
## @ace_category("Save System")
## @ace_description("Whether the slot has a save file.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.slot_exists({slot_index})")
func slot_exists(slot_index: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot_index))

## @ace_expression
## @ace_name("List Slots")
## @ace_category("Save System")
## @ace_description("Slot numbers that have save files (for menus).")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.list_slots()")
func list_slots() -> Array:
	var found: Array = []
	for candidate: int in range(100):
		if FileAccess.file_exists(_slot_path(candidate)):
			found.append(candidate)
	return found

## @ace_expression
## @ace_name("Slot Modified Time")
## @ace_category("Save System")
## @ace_description("Unix mtime of the slot's file (0 when missing).")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.slot_modified_time({slot_index})")
func slot_modified_time(slot_index: int) -> int:
	return FileAccess.get_modified_time(_slot_path(slot_index)) if FileAccess.file_exists(_slot_path(slot_index)) else 0

func _slot_path(target_slot: int = -1) -> String:
	var chosen: int = slot if target_slot < 0 else target_slot
	return save_directory.path_join(file_pattern.replace("{slot}", str(chosen)))

func _to_jsonable(value) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_INT:
			return {VAR_WRAPPER_KEY: var_to_str(value)}
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key: Variant in (value as Dictionary).keys():
				out[str(key)] = _to_jsonable((value as Dictionary)[key])
			return out
		TYPE_ARRAY:
			var items: Array = []
			for item: Variant in (value as Array):
				items.append(_to_jsonable(item))
			return items
		_:
			return {VAR_WRAPPER_KEY: var_to_str(value)}

func _from_jsonable(value) -> Variant:
	if value is Dictionary:
		var dict: Dictionary = value
		if dict.size() == 1 and dict.has(VAR_WRAPPER_KEY):
			return str_to_var(str(dict[VAR_WRAPPER_KEY]))
		var out: Dictionary = {}
		for key: Variant in dict.keys():
			out[key] = _from_jsonable(dict[key])
		return out
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_from_jsonable(item))
		return items
	return value

func _read_all() -> Dictionary:
	return _read_path(_slot_path(), format)

func _read_path(path: String, fmt: String) -> Dictionary:
	# Reads any save file at `path` in `fmt` (the same six backends). Reused by the
	# active-slot read and by Read Save File, so tooling can open a file from anywhere.
	_last_read_ok = true
	if not FileAccess.file_exists(path):
		return {}
	if fmt == "json":
		var file: FileAccess = _open_read(path)
		if file == null:
			_last_read_ok = false
			return {}
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			_last_read_ok = false
			return {}
		return _from_jsonable((parsed as Dictionary).get(section, {}))
	if fmt == "binary":
		var file: FileAccess = _open_read(path)
		if file == null:
			_last_read_ok = false
			return {}
		var parsed: Variant = file.get_var()
		if not parsed is Dictionary:
			_last_read_ok = false
			return {}
		return (parsed as Dictionary).get(section, {})
	if fmt == "csv":
		var file: FileAccess = _open_read(path)
		if file == null:
			_last_read_ok = false
			return {}
		var data: Dictionary = {}
		while not file.eof_reached():
			var row: PackedStringArray = file.get_csv_line()
			if row.size() < 2 or row[0].is_empty():
				continue
			var parsed: Variant = str_to_var(row[1])
			# Hand-authored cells (bare words) parse to null - keep them as raw text.
			data[row[0]] = parsed if parsed != null or row[1] == "null" else row[1]
		return data
	if fmt == "ini":
		var file: FileAccess = _open_read(path)
		if file == null:
			_last_read_ok = false
			return {}
		var data: Dictionary = {}
		# Read only keys under our [section]; an empty section reads every key.
		var in_section: bool = section.is_empty()
		while not file.eof_reached():
			var line: String = file.get_line().strip_edges()
			if line.is_empty() or line.begins_with(";") or line.begins_with("#"):
				continue
			if line.begins_with("[") and line.ends_with("]"):
				in_section = line.substr(1, line.length() - 2) == section or section.is_empty()
				continue
			var eq: int = line.find("=")
			if not in_section or eq < 0:
				continue
			var ini_key: String = line.substr(0, eq).strip_edges()
			var raw: String = line.substr(eq + 1).strip_edges()
			var parsed: Variant = str_to_var(raw)
			data[ini_key] = parsed if parsed != null or raw == "null" else raw
		return data
	if fmt == "xml":
		var file: FileAccess = _open_read(path)
		if file == null:
			_last_read_ok = false
			return {}
		var parser: XMLParser = XMLParser.new()
		if parser.open_buffer(file.get_as_text().to_utf8_buffer()) != Error.OK:
			_last_read_ok = false
			return {}
		var data: Dictionary = {}
		# XMLParser resolves &amp;/&lt;/&gt; itself, so the text is ready for str_to_var.
		var pending_key: String = ""
		while parser.read() == Error.OK:
			var node_type: int = parser.get_node_type()
			if node_type == XMLParser.NODE_ELEMENT and parser.get_node_name() == "entry":
				pending_key = parser.get_named_attribute_value_safe("key")
				if parser.is_empty():
					data[pending_key] = ""
					pending_key = ""
			elif node_type == XMLParser.NODE_TEXT and not pending_key.is_empty():
				var raw: String = parser.get_node_data()
				var parsed: Variant = str_to_var(raw)
				data[pending_key] = parsed if parsed != null or raw == "null" else raw
				pending_key = ""
			elif node_type == XMLParser.NODE_ELEMENT_END and parser.get_node_name() == "entry" and not pending_key.is_empty():
				data[pending_key] = ""
				pending_key = ""
		return data
	var config: ConfigFile = ConfigFile.new()
	var load_err: Error = config.load(path) if encryption_key.is_empty() else config.load_encrypted_pass(path, encryption_key)
	if load_err != Error.OK:
		_last_read_ok = false
		return {}
	var data: Dictionary = {}
	for key: String in config.get_section_keys(section) if config.has_section(section) else PackedStringArray():
		data[key] = config.get_value(section, key)
	return data

func _xml_escape(text: String) -> String:
	# XML entities on write; XMLParser un-escapes on read.
	return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")

func _detect_format(path: String) -> String:
	# Best-effort format detection for a save file. The extension is authoritative for
	# the pack's own files (config and ini are otherwise identical on disk); an unknown
	# extension sniffs the first bytes. Returns "" when the file is missing or unclear.
	if not FileAccess.file_exists(path):
		return ""
	match path.get_extension().to_lower():
		"cfg":
			return "config"
		"ini":
			return "ini"
		"json":
			return "json"
		"csv":
			return "csv"
		"xml":
			return "xml"
		"sav":
			return "binary"
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return ""
	if bytes.slice(0, mini(256, bytes.size())).find(0) != -1:
		return "binary"
	var text: String = bytes.get_string_from_utf8().strip_edges()
	if text.begins_with("<"):
		return "xml"
	if text.begins_with("{"):
		return "json"
	if text.begins_with("["):
		# config and ini both open with a [section]; content alone cannot tell them apart.
		return "config"
	if text.contains(","):
		return "csv"
	return ""

func _write_all(data: Dictionary) -> bool:
	# Atomic write: every backend writes a .tmp sibling then renames it over the slot,
	# so a crash mid-write leaves the previous good save intact, never a half-file.
	var path: String = _slot_path()
	var tmp: String = path + ".tmp"
	if format == "json":
		var file: FileAccess = _open_write(tmp)
		if file == null:
			return false
		file.store_string(JSON.stringify({section: _to_jsonable(data)}, "\t"))
		var write_ok: bool = file.get_error() == Error.OK
		file.close()
		if not write_ok:
			return false
	elif format == "binary":
		var file: FileAccess = _open_write(tmp)
		if file == null:
			return false
		file.store_var({section: data})
		var write_ok: bool = file.get_error() == Error.OK
		file.close()
		if not write_ok:
			return false
	elif format == "csv":
		var file: FileAccess = _open_write(tmp)
		if file == null:
			return false
		# var_to_str escapes newlines inside strings, so the only real newlines are the
		# ones it pretty-prints between container elements - stripping those keeps each
		# value on one CSV row without a second escape layer to conflict with str_to_var.
		for key: Variant in data.keys():
			file.store_csv_line(PackedStringArray([str(key), var_to_str(data[key]).replace("\n", "")]))
		var write_ok: bool = file.get_error() == Error.OK
		file.close()
		if not write_ok:
			return false
	elif format == "ini":
		var file: FileAccess = _open_write(tmp)
		if file == null:
			return false
		# A plain, portable [section] + key=value INI; var_to_str keeps each value
		# on one line and exact-typed, so other INI tools can read the structure.
		file.store_line("[%s]" % section)
		for key: Variant in data.keys():
			file.store_line("%s=%s" % [str(key), var_to_str(data[key]).replace("\n", "")])
		var write_ok: bool = file.get_error() == Error.OK
		file.close()
		if not write_ok:
			return false
	elif format == "xml":
		var file: FileAccess = _open_write(tmp)
		if file == null:
			return false
		file.store_line("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
		file.store_line("<save section=\"%s\">" % _xml_escape(section))
		for key: Variant in data.keys():
			file.store_line("\t<entry key=\"%s\">%s</entry>" % [_xml_escape(str(key)), _xml_escape(var_to_str(data[key]).replace("\n", ""))])
		file.store_line("</save>")
		var write_ok: bool = file.get_error() == Error.OK
		file.close()
		if not write_ok:
			return false
	else:
		var config: ConfigFile = ConfigFile.new()
		for key: Variant in data.keys():
			config.set_value(section, str(key), data[key])
		var err: Error = config.save(tmp) if encryption_key.is_empty() else config.save_encrypted_pass(tmp, encryption_key)
		if err != Error.OK:
			return false
	return DirAccess.rename_absolute(tmp, path) == Error.OK

func _collect_node_state(node: Node) -> Dictionary:
	# The save-state seam: any node (or behavior child) exposing save_state() ->
	# Dictionary and load_state(state) participates - no registration, no base class.
	var states: Dictionary = {}
	if node == null:
		return states
	if node.has_method("save_state"):
		states["."] = node.save_state()
	for child: Node in node.get_children():
		if child.has_method("save_state"):
			states[str(child.name)] = child.save_state()
	return states

func _apply_node_state(node: Node, states: Dictionary) -> void:
	if node == null:
		return
	for entry: Variant in states.keys():
		var target: Node = node if str(entry) == "." else node.get_node_or_null(NodePath(str(entry)))
		if target != null and target.has_method("load_state") and states[entry] is Dictionary:
			target.load_state(states[entry] as Dictionary)

func _collect_group_state(group: String) -> Dictionary:
	var states: Dictionary = {}
	if not is_inside_tree() or group.is_empty():
		return states
	for member: Node in get_tree().get_nodes_in_group(group):
		var entry: Dictionary = _collect_node_state(member)
		if not entry.is_empty():
			states[str(member.get_path())] = entry
	return states

func _apply_states(states: Dictionary) -> void:
	for path: Variant in states.keys():
		var member: Node = get_node_or_null(NodePath(str(path)))
		if member != null and states[path] is Dictionary:
			_apply_node_state(member, states[path] as Dictionary)
		elif member == null:
			# The save holds state for a node that is not here now (renamed, re-parented,
			# or the scene is not loaded yet). Surface it rather than dropping it silently.
			push_warning("Save System: no node at %s to restore its saved state." % str(path))

# Save System: register as the SaveSystem autoload, then save from any sheet. Strategy (paths/format/encryption) lives in the Inspector; On Before Save / On After Load let every sheet contribute its own state. This pack is an event sheet - extend it by editing it.
