## @ace_tags(persistence)
@icon("res://eventsheet_addons/behavior.svg")
class_name SaveSystemAddon
extends Node

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
@export_enum("config", "json") var format: String = "config"
## Where save files live.
@export var save_directory: String = "user://"
## ConfigFile section / JSON namespace for values.
@export var section: String = "save"
## Active save slot (each slot is its own file).
@export_group("Save System")
@export_range(0, 9, 1) var slot: int = 0

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
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("SaveSystem.save_value({key}, {value})")
func save_value(key: String, value) -> void:
	var data: Dictionary = _read_all()
	data[key] = value
	_write_all(data)

## @ace_expression
## @ace_name("Load Value")
## @ace_category("Save System")
## @ace_description("Reads any value (your default when missing).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("SaveSystem.load_value({key}, {default_value})")
func load_value(key: String, default_value) -> Variant:
	return _read_all().get(key, default_value)

## @ace_action
## @ace_name("Save Number")
## @ace_category("Save System")
## @ace_description("Writes a number under the key (active slot).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("SaveSystem.save_number({key}, {value})")
func save_number(key: String, value: float) -> void:
	save_value(key, value)

## @ace_expression
## @ace_name("Load Number")
## @ace_category("Save System")
## @ace_description("Reads a number (0 when missing).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("SaveSystem.load_number({key})")
func load_number(key: String) -> float:
	return float(load_value(key, 0.0))

## @ace_action
## @ace_name("Save Text")
## @ace_category("Save System")
## @ace_description("Writes a string under the key (active slot).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("SaveSystem.save_text({key}, {value})")
func save_text(key: String, value: String) -> void:
	save_value(key, value)

## @ace_expression
## @ace_name("Load Text")
## @ace_category("Save System")
## @ace_description("Reads a string ("" when missing).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("SaveSystem.load_text({key})")
func load_text(key: String) -> String:
	return str(load_value(key, ""))

## @ace_condition
## @ace_name("Has Save Key")
## @ace_category("Save System")
## @ace_description("Whether the key exists in the active slot.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("SaveSystem.has_save_key({key})")
func has_save_key(key: String) -> bool:
	return _read_all().has(key)

## @ace_action
## @ace_name("Delete Slot")
## @ace_category("Save System")
## @ace_description("Removes the active slot's save file.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("SaveSystem.delete_slot()")
func delete_slot() -> void:
	if FileAccess.file_exists(_slot_path()):
		DirAccess.remove_absolute(_slot_path())

## @ace_action
## @ace_name("Save Game")
## @ace_category("Save System")
## @ace_description("Broadcasts On Before Save (every sheet writes its state), then On Save Written.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("SaveSystem.save_game()")
func save_game() -> void:
	before_save.emit(slot)
	var data: Dictionary = _read_all()
	if _write_all(data):
		save_written.emit(slot)

## @ace_action
## @ace_name("Load Game")
## @ace_category("Save System")
## @ace_description("Broadcasts On After Load - every sheet reads its state back.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("SaveSystem.load_game()")
func load_game() -> void:
	after_load.emit(slot)

## @ace_condition
## @ace_name("Slot Exists")
## @ace_category("Save System")
## @ace_description("Whether the slot has a save file.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("SaveSystem.slot_exists({slot_index})")
func slot_exists(slot_index: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot_index))

## @ace_expression
## @ace_name("List Slots")
## @ace_category("Save System")
## @ace_description("Slot numbers that have save files (for menus).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
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
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("SaveSystem.slot_modified_time({slot_index})")
func slot_modified_time(slot_index: int) -> int:
	return FileAccess.get_modified_time(_slot_path(slot_index)) if FileAccess.file_exists(_slot_path(slot_index)) else 0

func _slot_path(target_slot: int = -1) -> String:
	var chosen: int = slot if target_slot < 0 else target_slot
	return save_directory.path_join(file_pattern.replace("{slot}", str(chosen)))

func _read_all() -> Dictionary:
	# Format-agnostic backends: everything above reads/writes one Dictionary.
	var path: String = _slot_path()
	if format == "json":
		var file: FileAccess = FileAccess.open_encrypted_with_pass(path, FileAccess.READ, encryption_key) if not encryption_key.is_empty() else FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {}
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		return (parsed as Dictionary).get(section, {}) if parsed is Dictionary else {}
	var config: ConfigFile = ConfigFile.new()
	if encryption_key.is_empty():
		config.load(path)
	else:
		config.load_encrypted_pass(path, encryption_key)
	var data: Dictionary = {}
	for key: String in config.get_section_keys(section) if config.has_section(section) else PackedStringArray():
		data[key] = config.get_value(section, key)
	return data

func _write_all(data: Dictionary) -> bool:
	var path: String = _slot_path()
	if format == "json":
		var file: FileAccess = FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, encryption_key) if not encryption_key.is_empty() else FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return false
		file.store_string(JSON.stringify({section: data}, "\t"))
		if file.get_error() != Error.OK:
			return false
		file.close()
		return true
	else:
		var config: ConfigFile = ConfigFile.new()
		for key: Variant in data.keys():
			config.set_value(section, str(key), data[key])
		var err: Error
		if encryption_key.is_empty():
			err = config.save(path)
		else:
			err = config.save_encrypted_pass(path, encryption_key)
		if err != Error.OK:
			return false
		return true

# Save System: register as the SaveSystem autoload, then save from any sheet. Strategy (paths/format/encryption) lives in the Inspector; On Before Save / On After Load let every sheet contribute its own state. This pack is an event sheet - extend it by editing it.
