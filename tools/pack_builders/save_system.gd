# Pack builder — save_system (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

## Save System addon v2: slot-based persistence as an AUTOLOAD sheet — deliberately
## UN-opinionated: storage strategy (directory/pattern/section/format/encryption) is
## exported Inspector properties; the core is Variant-typed (typed Save Number/Text
## remain as conveniences — their ace_ids are API); before_save/after_load lifecycle
## signals let ANY sheet contribute state without this pack knowing it exists; slot
## metadata powers save/load menus; optional autosave. Full-state snapshots stay an
## honest non-goal (Godot serializes scenes, not "the whole game").
## THE DEEPEST EXTENSION POINT: this pack IS an event sheet — open the .tres, add
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
		"format": {"type": "String", "default": "config", "exported": true, "options": ["config", "json"]},
		"encryption_key": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "Non-empty = encrypted saves (keep the key out of screenshots!)."}},
		"autosave_interval": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "Seconds between autosaves (0 = off). Fires On Before Save first.", "range": {"min": "0", "max": "600", "step": "1"}}},
		"autosave_accumulator": {"type": "float", "default": 0.0, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Save System: register as the SaveSystem autoload, then save from any sheet. Strategy (paths/format/encryption) lives in the Inspector; On Before Save / On After Load let every sheet contribute its own state. This pack is an event sheet — extend it by editing it."
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
		"# Format-agnostic backends: everything above reads/writes one Dictionary.",
		"func _read_all() -> Dictionary:",
		"\tvar path: String = _slot_path()",
		"\tif format == \"json\":",
		"\t\tvar file: FileAccess = FileAccess.open_encrypted_with_pass(path, FileAccess.READ, encryption_key) if not encryption_key.is_empty() else FileAccess.open(path, FileAccess.READ)",
		"\t\tif file == null:",
		"\t\t\treturn {}",
		"\t\tvar parsed: Variant = JSON.parse_string(file.get_as_text())",
		"\t\treturn (parsed as Dictionary).get(section, {}) if parsed is Dictionary else {}",
		"\tvar config: ConfigFile = ConfigFile.new()",
		"\tif encryption_key.is_empty():",
		"\t\tconfig.load(path)",
		"\telse:",
		"\t\tconfig.load_encrypted_pass(path, encryption_key)",
		"\tvar data: Dictionary = {}",
		"\tfor key: String in config.get_section_keys(section) if config.has_section(section) else PackedStringArray():",
		"\t\tdata[key] = config.get_value(section, key)",
		"\treturn data",
		"",
		"func _write_all(data: Dictionary) -> bool:",
		"\tvar path: String = _slot_path()",
		"\tif format == \"json\":",
		"\t\tvar file: FileAccess = FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, encryption_key) if not encryption_key.is_empty() else FileAccess.open(path, FileAccess.WRITE)",
		"\t\tif file == null:",
		"\t\t\treturn false",
		"\t\tfile.store_string(JSON.stringify({section: data}, \"\\t\"))",
		"\t\tif file.get_error() != Error.OK:",
		"\t\t\treturn false",
		"\t\tfile.close()",
		"\t\treturn true",
		"\telse:",
		"\t\tvar config: ConfigFile = ConfigFile.new()",
		"\t\tfor key: Variant in data.keys():",
		"\t\t\tconfig.set_value(section, str(key), data[key])",
		"\t\tvar err: Error",
		"\t\tif encryption_key.is_empty():",
		"\t\t\terr = config.save(path)",
		"\t\telse:",
		"\t\t\terr = config.save_encrypted_pass(path, encryption_key)",
		"\t\tif err != Error.OK:",
		"\t\t\treturn false",
		"\t\treturn true"
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
		"var data: Dictionary = _read_all()\ndata[key] = value\n_write_all(data)")
	var load_value: EventFunction = Lib.exposed_function("load_value", "Load Value", "Save System", "Reads any value (your default when missing).", [["key", "String"], ["default_value", "Variant"]],
		"return _read_all().get(key, default_value)")
	# TYPE_MAX = the compiler's "returns Variant" sentinel.
	load_value.return_type = TYPE_MAX
	sheet.functions.append(load_value)
	# Typed conveniences (ace_ids are API — kept, now thin delegations).
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
	# Lifecycle orchestration: other sheets contribute state via On Before Save.
	Lib.append_function(sheet, "save_game", "Save Game", "Save System", "Broadcasts On Before Save (every sheet writes its state), then On Save Written.",
		[],
		"before_save.emit(slot)\nvar data: Dictionary = _read_all()\nif _write_all(data):\n\tsave_written.emit(slot)")
	Lib.append_function(sheet, "load_game", "Load Game", "Save System", "Broadcasts On After Load — every sheet reads its state back.",
		[],
		"after_load.emit(slot)")
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
