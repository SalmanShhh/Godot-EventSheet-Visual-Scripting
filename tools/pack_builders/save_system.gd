# Pack builder - save_system (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Save System addon v2: slot-based persistence as an AUTOLOAD sheet - deliberately
## UN-opinionated: storage strategy (directory/pattern/section/format/encryption) is
## exported Inspector properties; the core is Variant-typed (typed Save Number/Text
## remain as conveniences - their ace_ids are API); before_save/after_load lifecycle
## signals let ANY sheet contribute state without this pack knowing it exists; slot
## metadata powers save/load menus; optional autosave. Full-state snapshots stay an
## honest non-goal (Godot serializes scenes, not "the whole game").
## THE DEEPEST EXTENSION POINT: this pack IS an event sheet - open the .tres, add
## functions, recompile, re-register.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "SaveSystem"
	sheet.host_class = "Node"
	sheet.custom_class_name = "SaveSystemAddon"
	sheet.addon_tags = PackedStringArray(["persistence"])
	sheet.variables = {
		"slot": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "Active save slot (each slot is its own file).", "range": {"min": "0", "max": "9", "step": "1"}, "group": "Save System"}},
		"save_directory": {"type": "String", "default": "user://", "exported": true,
			"attributes": {"tooltip": "Where save files live."}},
		"file_pattern": {"type": "String", "default": "save_{slot}.cfg", "exported": true,
			"attributes": {"tooltip": "{slot} becomes the slot number."}},
		"section": {"type": "String", "default": "save", "exported": true,
			"attributes": {"tooltip": "ConfigFile section / JSON namespace for values."}},
		"format": {"type": "String", "default": "config", "exported": true, "options": ["config", "json", "binary", "csv"],
			"attributes": {"tooltip": "config = ConfigFile (full Variant types), json = readable text, binary = compact store_var, csv = spreadsheet-friendly key,value rows."}},
		"persist_group": {"type": "String", "default": "persist", "exported": true,
			"attributes": {"tooltip": "Nodes in this group (and their behaviors) auto-save via save_state()/load_state() on Save Game / Load Game."}},
		"encryption_key": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "Non-empty = encrypted saves (keep the key out of screenshots!)."}},
		"autosave_interval": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "Seconds between autosaves (0 = off). Fires On Before Save first.", "range": {"min": "0", "max": "600", "step": "1"}}},
		"autosave_accumulator": {"type": "float", "default": 0.0, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Save System: register as the SaveSystem autoload, then save from any sheet. Strategy (paths/format/encryption) lives in the Inspector; On Before Save / On After Load let every sheet contribute its own state. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var helpers: RawCodeRow = RawCodeRow.new()
	helpers.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Save Written\")",
		"## @ace_category(\"Save System\")",
		"signal save_written(slot_index: int)",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Before Save\")",
		"## @ace_category(\"Save System\")",
		"signal before_save(slot_index: int)",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On After Load\")",
		"## @ace_category(\"Save System\")",
		"signal after_load(slot_index: int)",
		"",
		"func _slot_path(target_slot: int = -1) -> String:",
		"\tvar chosen: int = slot if target_slot < 0 else target_slot",
		"\treturn save_directory.path_join(file_pattern.replace(\"{slot}\", str(chosen)))",
		"",
		"func _open_read(path: String) -> FileAccess:",
		"\treturn FileAccess.open_encrypted_with_pass(path, FileAccess.READ, encryption_key) if not encryption_key.is_empty() else FileAccess.open(path, FileAccess.READ)",
		"",
		"func _open_write(path: String) -> FileAccess:",
		"\treturn FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, encryption_key) if not encryption_key.is_empty() else FileAccess.open(path, FileAccess.WRITE)",
		"",
		"# JSON cannot hold Vector2/Color/etc, and its numbers are doubles (a 64-bit int",
		"# would lose precision), so those Variants travel as a one-key wrapper and come",
		"# back through str_to_var. The key is long and namespaced so a real user dict is",
		"# extremely unlikely to be mistaken for a wrapped value.",
		"const VAR_WRAPPER_KEY: String = \"__eventsheet_var\"",
		"const JSON_SAFE_INT: int = 1 << 53",
		"",
		"func _to_jsonable(value: Variant) -> Variant:",
		"\tmatch typeof(value):",
		"\t\tTYPE_NIL, TYPE_BOOL, TYPE_FLOAT, TYPE_STRING:",
		"\t\t\treturn value",
		"\t\tTYPE_INT:",
		"\t\t\t# Ints past 2^53 (RNG state, big ids) lose precision as JSON doubles - wrap them.",
		"\t\t\treturn value if absi(value) < JSON_SAFE_INT else {VAR_WRAPPER_KEY: var_to_str(value)}",
		"\t\tTYPE_DICTIONARY:",
		"\t\t\tvar out: Dictionary = {}",
		"\t\t\tfor key: Variant in (value as Dictionary).keys():",
		"\t\t\t\tout[str(key)] = _to_jsonable((value as Dictionary)[key])",
		"\t\t\treturn out",
		"\t\tTYPE_ARRAY:",
		"\t\t\tvar items: Array = []",
		"\t\t\tfor item: Variant in (value as Array):",
		"\t\t\t\titems.append(_to_jsonable(item))",
		"\t\t\treturn items",
		"\t\t_:",
		"\t\t\treturn {VAR_WRAPPER_KEY: var_to_str(value)}",
		"",
		"func _from_jsonable(value: Variant) -> Variant:",
		"\tif value is Dictionary:",
		"\t\tvar dict: Dictionary = value",
		"\t\tif dict.size() == 1 and dict.has(VAR_WRAPPER_KEY):",
		"\t\t\treturn str_to_var(str(dict[VAR_WRAPPER_KEY]))",
		"\t\tvar out: Dictionary = {}",
		"\t\tfor key: Variant in dict.keys():",
		"\t\t\tout[key] = _from_jsonable(dict[key])",
		"\t\treturn out",
		"\tif value is Array:",
		"\t\tvar items: Array = []",
		"\t\tfor item: Variant in value:",
		"\t\t\titems.append(_from_jsonable(item))",
		"\t\treturn items",
		"\treturn value",
		"",
		"# _read_all sets _last_read_ok = false when a slot file EXISTS but cannot be read",
		"# (bad decrypt key, corrupt JSON, truncated binary). Writers check the flag and",
		"# refuse to overwrite a slot they could not read, so a failed read never wipes a",
		"# good save on the next write or autosave. A genuinely absent file reads as OK.",
		"var _last_read_ok: bool = true",
		"",
		"func _read_all() -> Dictionary:",
		"\tvar path: String = _slot_path()",
		"\t_last_read_ok = true",
		"\tif not FileAccess.file_exists(path):",
		"\t\treturn {}",
		"\tif format == \"json\":",
		"\t\tvar file: FileAccess = _open_read(path)",
		"\t\tif file == null:",
		"\t\t\t_last_read_ok = false",
		"\t\t\treturn {}",
		"\t\tvar parsed: Variant = JSON.parse_string(file.get_as_text())",
		"\t\tif not parsed is Dictionary:",
		"\t\t\t_last_read_ok = false",
		"\t\t\treturn {}",
		"\t\treturn _from_jsonable((parsed as Dictionary).get(section, {}))",
		"\tif format == \"binary\":",
		"\t\tvar file: FileAccess = _open_read(path)",
		"\t\tif file == null:",
		"\t\t\t_last_read_ok = false",
		"\t\t\treturn {}",
		"\t\tvar parsed: Variant = file.get_var()",
		"\t\tif not parsed is Dictionary:",
		"\t\t\t_last_read_ok = false",
		"\t\t\treturn {}",
		"\t\treturn (parsed as Dictionary).get(section, {})",
		"\tif format == \"csv\":",
		"\t\tvar file: FileAccess = _open_read(path)",
		"\t\tif file == null:",
		"\t\t\t_last_read_ok = false",
		"\t\t\treturn {}",
		"\t\tvar data: Dictionary = {}",
		"\t\twhile not file.eof_reached():",
		"\t\t\tvar row: PackedStringArray = file.get_csv_line()",
		"\t\t\tif row.size() < 2 or row[0].is_empty():",
		"\t\t\t\tcontinue",
		"\t\t\tvar parsed: Variant = str_to_var(row[1])",
		"\t\t\t# Hand-authored cells (bare words) parse to null - keep them as raw text.",
		"\t\t\tdata[row[0]] = parsed if parsed != null or row[1] == \"null\" else row[1]",
		"\t\treturn data",
		"\tvar config: ConfigFile = ConfigFile.new()",
		"\tvar load_err: Error = config.load(path) if encryption_key.is_empty() else config.load_encrypted_pass(path, encryption_key)",
		"\tif load_err != Error.OK:",
		"\t\t_last_read_ok = false",
		"\t\treturn {}",
		"\tvar data: Dictionary = {}",
		"\tfor key: String in config.get_section_keys(section) if config.has_section(section) else PackedStringArray():",
		"\t\tdata[key] = config.get_value(section, key)",
		"\treturn data",
		"",
		"# Atomic write: every backend writes a .tmp sibling then renames it over the slot,",
		"# so a crash mid-write leaves the previous good save intact, never a half-file.",
		"func _write_all(data: Dictionary) -> bool:",
		"\tvar path: String = _slot_path()",
		"\tvar tmp: String = path + \".tmp\"",
		"\tif format == \"json\":",
		"\t\tvar file: FileAccess = _open_write(tmp)",
		"\t\tif file == null:",
		"\t\t\treturn false",
		"\t\tfile.store_string(JSON.stringify({section: _to_jsonable(data)}, \"\\t\"))",
		"\t\tvar write_ok: bool = file.get_error() == Error.OK",
		"\t\tfile.close()",
		"\t\tif not write_ok:",
		"\t\t\treturn false",
		"\telif format == \"binary\":",
		"\t\tvar file: FileAccess = _open_write(tmp)",
		"\t\tif file == null:",
		"\t\t\treturn false",
		"\t\tfile.store_var({section: data})",
		"\t\tvar write_ok: bool = file.get_error() == Error.OK",
		"\t\tfile.close()",
		"\t\tif not write_ok:",
		"\t\t\treturn false",
		"\telif format == \"csv\":",
		"\t\tvar file: FileAccess = _open_write(tmp)",
		"\t\tif file == null:",
		"\t\t\treturn false",
		"\t\t# var_to_str escapes newlines inside strings, so the only real newlines are the",
		"\t\t# ones it pretty-prints between container elements - stripping those keeps each",
		"\t\t# value on one CSV row without a second escape layer to conflict with str_to_var.",
		"\t\tfor key: Variant in data.keys():",
		"\t\t\tfile.store_csv_line(PackedStringArray([str(key), var_to_str(data[key]).replace(\"\\n\", \"\")]))",
		"\t\tvar write_ok: bool = file.get_error() == Error.OK",
		"\t\tfile.close()",
		"\t\tif not write_ok:",
		"\t\t\treturn false",
		"\telse:",
		"\t\tvar config: ConfigFile = ConfigFile.new()",
		"\t\tfor key: Variant in data.keys():",
		"\t\t\tconfig.set_value(section, str(key), data[key])",
		"\t\tvar err: Error = config.save(tmp) if encryption_key.is_empty() else config.save_encrypted_pass(tmp, encryption_key)",
		"\t\tif err != Error.OK:",
		"\t\t\treturn false",
		"\treturn DirAccess.rename_absolute(tmp, path) == Error.OK",
		"",
		"# The save-state seam: any node (or behavior child) exposing save_state() ->",
		"# Dictionary and load_state(state) participates - no registration, no base class.",
		"func _collect_node_state(node: Node) -> Dictionary:",
		"\tvar states: Dictionary = {}",
		"\tif node == null:",
		"\t\treturn states",
		"\tif node.has_method(\"save_state\"):",
		"\t\tstates[\".\"] = node.save_state()",
		"\tfor child: Node in node.get_children():",
		"\t\tif child.has_method(\"save_state\"):",
		"\t\t\tstates[str(child.name)] = child.save_state()",
		"\treturn states",
		"",
		"func _apply_node_state(node: Node, states: Dictionary) -> void:",
		"\tif node == null:",
		"\t\treturn",
		"\tfor entry: Variant in states.keys():",
		"\t\tvar target: Node = node if str(entry) == \".\" else node.get_node_or_null(NodePath(str(entry)))",
		"\t\tif target != null and target.has_method(\"load_state\") and states[entry] is Dictionary:",
		"\t\t\ttarget.load_state(states[entry] as Dictionary)",
		"",
		"func _collect_group_state(group: String) -> Dictionary:",
		"\tvar states: Dictionary = {}",
		"\tif not is_inside_tree() or group.is_empty():",
		"\t\treturn states",
		"\tfor member: Node in get_tree().get_nodes_in_group(group):",
		"\t\tvar entry: Dictionary = _collect_node_state(member)",
		"\t\tif not entry.is_empty():",
		"\t\t\tstates[str(member.get_path())] = entry",
		"\treturn states",
		"",
		"func _apply_states(states: Dictionary) -> void:",
		"\tfor path: Variant in states.keys():",
		"\t\tvar member: Node = get_node_or_null(NodePath(str(path)))",
		"\t\tif member != null and states[path] is Dictionary:",
		"\t\t\t_apply_node_state(member, states[path] as Dictionary)",
		"\t\telif member == null:",
		"\t\t\t# The save holds state for a node that is not here now (renamed, re-parented,",
		"\t\t\t# or the scene is not loaded yet). Surface it rather than dropping it silently.",
		"\t\t\tpush_warning(\"Save System: no node at %s to restore its saved state.\" % str(path))"
	]))
	sheet.events.append(helpers)
	var autosave_tick: EventRow = EventRow.new()
	autosave_tick.trigger_provider_id = "Core"
	autosave_tick.trigger_id = "OnProcess"
	var autosave_body: RawCodeRow = RawCodeRow.new()
	autosave_body.code = "\n".join(PackedStringArray([
		"if autosave_interval <= 0.0:",
		"\treturn",
		"autosave_accumulator += delta",
		"if autosave_accumulator >= autosave_interval:",
		"\tautosave_accumulator = 0.0",
		"\tsave_game()"
	]))
	autosave_tick.actions.append(autosave_body)
	sheet.events.append(autosave_tick)
	# Variant-typed core.
	Lib.append_function(sheet, "save_value", "Save Value", "Save System", "Writes ANY value (number, text, Vector2, Color, Dictionary…) under the key.",
		[["key", "String"], ["value", "Variant"]],
		"\n".join(PackedStringArray([
			"var data: Dictionary = _read_all()",
			"if not _last_read_ok:",
			"\tpush_error(\"Save System: slot %d exists but could not be read - refusing to overwrite it.\" % slot)",
			"\treturn",
			"data[key] = value",
			"_write_all(data)"
		])))
	var load_value: EventFunction = Lib.exposed_function("load_value", "Load Value", "Save System", "Reads any value (your default when missing).", [["key", "String"], ["default_value", "Variant"]],
		"return _read_all().get(key, default_value)")
	# TYPE_MAX = the compiler's "returns Variant" sentinel.
	load_value.return_type = TYPE_MAX
	sheet.functions.append(load_value)
	# Typed conveniences (ace_ids are API - kept, now thin delegations).
	Lib.append_function(sheet, "save_number", "Save Number", "Save System", "Writes a number under the key (active slot).",
		[["key", "String"], ["value", "float"]],
		"save_value(key, value)")
	var load_number: EventFunction = Lib.exposed_function("load_number", "Load Number", "Save System", "Reads a number (0 when missing).", [["key", "String"]],
		"return float(load_value(key, 0.0))")
	load_number.return_type = TYPE_FLOAT
	sheet.functions.append(load_number)
	Lib.append_function(sheet, "save_text", "Save Text", "Save System", "Writes a string under the key (active slot).",
		[["key", "String"], ["value", "String"]],
		"save_value(key, value)")
	var load_text: EventFunction = Lib.exposed_function("load_text", "Load Text", "Save System", "Reads a string (\"\" when missing).", [["key", "String"]],
		"return str(load_value(key, \"\"))")
	load_text.return_type = TYPE_STRING
	sheet.functions.append(load_text)
	var has_key: EventFunction = Lib.exposed_function("has_save_key", "Has Save Key", "Save System", "Whether the key exists in the active slot.", [["key", "String"]],
		"return _read_all().has(key)")
	has_key.return_type = TYPE_BOOL
	sheet.functions.append(has_key)
	Lib.append_function(sheet, "delete_slot", "Delete Slot", "Save System", "Removes the active slot's save file.",
		[],
		"if FileAccess.file_exists(_slot_path()):\n\tDirAccess.remove_absolute(_slot_path())")
	# Lifecycle orchestration: other sheets contribute state via On Before Save, and
	# every node in the persist group snapshots itself automatically (save_state seam).
	Lib.append_function(sheet, "save_game", "Save Game", "Save System", "Broadcasts On Before Save (every sheet writes its state), snapshots every node in the persist group, then fires On Save Written.",
		[],
		"\n".join(PackedStringArray([
			"before_save.emit(slot)",
			"var data: Dictionary = _read_all()",
			"if not _last_read_ok:",
			"\tpush_error(\"Save System: slot %d exists but could not be read - refusing to overwrite it.\" % slot)",
			"\treturn",
			"var persisted: Dictionary = _collect_group_state(persist_group)",
			"if not persisted.is_empty():",
			"\tdata[\"__persist\"] = persisted",
			"if _write_all(data):",
			"\tsave_written.emit(slot)"
		])))
	Lib.append_function(sheet, "load_game", "Load Game", "Save System", "Restores every persist-group snapshot, then broadcasts On After Load so every sheet reads its state back.",
		[],
		"\n".join(PackedStringArray([
			"var data: Dictionary = _read_all()",
			"if data.get(\"__persist\", null) is Dictionary:",
			"\t_apply_states(data[\"__persist\"] as Dictionary)",
			"after_load.emit(slot)"
		])))
	# Targeted state verbs: the same seam, aimed at one node, one group, or a singleton.
	Lib.append_function(sheet, "save_node_state", "Save Node State", "Save System", "Snapshots a node and its behaviors (any child with save_state) under the key.",
		[["node", "Node"], ["key", "String"]],
		"save_value(key, _collect_node_state(node))")
	Lib.append_function(sheet, "load_node_state", "Load Node State", "Save System", "Restores a node and its behaviors from the key's snapshot.",
		[["node", "Node"], ["key", "String"]],
		"var states: Variant = load_value(key, {})\nif states is Dictionary:\n\t_apply_node_state(node, states as Dictionary)")
	Lib.append_function(sheet, "save_group_state", "Save Group State", "Save System", "Snapshots every node in the scene-tree group (and their behaviors) under the key.",
		[["group", "String"], ["key", "String"]],
		"save_value(key, _collect_group_state(group))")
	Lib.append_function(sheet, "load_group_state", "Load Group State", "Save System", "Restores the group snapshot saved under the key (nodes matched by scene path).",
		[["key", "String"]],
		"var states: Variant = load_value(key, {})\nif states is Dictionary:\n\t_apply_states(states as Dictionary)")
	Lib.append_function(sheet, "save_singleton_state", "Save Singleton State", "Save System", "Snapshots an autoload addon (Currency Ledger, Upgrades, Prestige...) by its autoload name.",
		[["singleton_name", "String"], ["key", "String"]],
		"save_value(key, _collect_node_state(get_node_or_null(\"/root/\" + singleton_name)))")
	Lib.append_function(sheet, "load_singleton_state", "Load Singleton State", "Save System", "Restores an autoload addon's snapshot from the key.",
		[["singleton_name", "String"], ["key", "String"]],
		"var states: Variant = load_value(key, {})\nif states is Dictionary:\n\t_apply_node_state(get_node_or_null(\"/root/\" + singleton_name), states as Dictionary)")
	# Slot metadata (save/load menus).
	var slot_exists: EventFunction = Lib.exposed_function("slot_exists", "Slot Exists", "Save System", "Whether the slot has a save file.", [["slot_index", "int"]],
		"return FileAccess.file_exists(_slot_path(slot_index))")
	slot_exists.return_type = TYPE_BOOL
	sheet.functions.append(slot_exists)
	var list_slots: EventFunction = Lib.exposed_function("list_slots", "List Slots", "Save System", "Slot numbers that have save files (for menus).", [],
		"\n".join(PackedStringArray([
			"var found: Array = []",
			"for candidate: int in range(100):",
			"\tif FileAccess.file_exists(_slot_path(candidate)):",
			"\t\tfound.append(candidate)",
			"return found"
		])))
	list_slots.return_type = TYPE_ARRAY
	sheet.functions.append(list_slots)
	var slot_time: EventFunction = Lib.exposed_function("slot_modified_time", "Slot Modified Time", "Save System", "Unix mtime of the slot's file (0 when missing).", [["slot_index", "int"]],
		"return FileAccess.get_modified_time(_slot_path(slot_index)) if FileAccess.file_exists(_slot_path(slot_index)) else 0")
	slot_time.return_type = TYPE_INT
	sheet.functions.append(slot_time)
	return Lib.save_pack(sheet, "res://eventsheet_addons/save_system/save_system_addon")
