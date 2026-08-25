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
## Fires when the autosave clock comes round, INSTEAD of saving - so the conditions on
## this event decide whether now is a good moment (mid boss phase, mid scene change,
## mid death animation). With nothing connected the pack saves itself on the interval,
## exactly as it always did, so an existing project does not change behaviour.
## @ace_trigger
## @ace_name("On Autosave Due")
## @ace_category("Save System")
signal autosave_due(slot_index: int)
## Fires inside Load Game when the file on disk was written by an older Save Version,
## BEFORE anything reads it - so migration rows (Data Is Older Than Version, Rename
## Field, Stamp Data Version) rewrite the record in the gap. Hand it back with Use
## Upgraded Save. Nothing connected? Load Game behaves exactly as it does today.
## @ace_trigger
## @ace_name("On Save Needs Upgrade")
## @ace_category("Save System")
signal save_needs_upgrade(save_data: Dictionary, from_version: int)
## Fires when Load Game meets a file it cannot read - a wrong encryption key, a
## truncated write from an older build, a hand-edited JSON. The reason is a plain
## sentence, ready to drop straight into a label.
## @ace_trigger
## @ace_name("On Load Failed")
## @ace_category("Save System")
signal load_failed(slot_index: int, reason: String)
## Fires when a write is refused or fails - the moment a player needs to hear "your
## progress was NOT saved" instead of nothing at all.
## @ace_trigger
## @ace_name("On Save Failed")
## @ace_category("Save System")
signal save_failed(slot_index: int, reason: String)
## Fires when Start New Run has written the fresh slot - where the NG+ banner, the
## difficulty curve and the seeded map generation hang, instead of on whichever button
## happened to be pressed.
## @ace_trigger
## @ace_name("On New Run Started")
## @ace_category("Save System")
signal new_run_started(slot_index: int, run_number: int)
## Fires when one key's value has landed on disk - Save Value, Save Number and Save Text
## all raise it, with the key that was written as the row's own captured value. A key held
## back by Never Save This Key never raises it, because it never reached the file.
## @ace_trigger
## @ace_name("On Key Saved")
## @ace_category("Save System")
signal key_saved(key: String, slot_index: int)
## Fires when Check Save Key finds the key in the slot - the found half of that question,
## answered as a row instead of a value somebody has to remember to test.
## @ace_trigger
## @ace_name("On Key Loaded")
## @ace_category("Save System")
signal key_loaded(key: String, slot_index: int)
## Fires when Remove Save Key has taken the key out of the file, and once per key that
## Clear Slot Keys emptied out of it.
## @ace_trigger
## @ace_name("On Key Removed")
## @ace_category("Save System")
signal key_removed(key: String, slot_index: int)
## Fires when a key was asked for and the slot does not hold it - Check Save Key, or a
## Remove Save Key with nothing to remove. This is where a first run seeds its default
## once, instead of quietly defaulting forever.
## @ace_trigger
## @ace_name("On Save Key Missing")
## @ace_category("Save System")
signal save_key_missing(key: String, slot_index: int)

## Where save files live.
@export var save_directory: String = "user://"
## {slot} becomes the slot number.
@export var file_pattern: String = "save_{slot}.cfg"
## ConfigFile section / JSON namespace for values.
@export var section: String = "save"
## config = ConfigFile (Godot-native), json = readable text, binary = compact store_var, csv = spreadsheet rows, ini = portable [section] key=value, xml = structured <entry> tags. All six preserve exact types.
@export_enum("config", "json", "binary", "csv", "ini", "xml") var format: String = "config"
## Nodes in this group (and their behaviors) auto-save via save_state()/load_state() on Save Game / Load Game.
@export var persist_group: String = "persist"
## Non-empty = encrypted saves (keep the key out of screenshots!).
@export var encryption_key: String = ""
## Seconds between autosaves (0 = off). Fires On Before Save first.
@export_range(0, 600, 1) var autosave_interval: float = 0.0
## The save shape number THIS build writes. Bump it whenever your saved data changes shape, and Load Game fires On Save Needs Upgrade for every older file so migration rows can fix it before anything reads it. 1 = nothing to migrate yet (and nothing is stamped, so files stay exactly as they were).
@export_range(1, 999, 1) var save_version: int = 1
## How many earlier versions of each slot to keep (0 = off). Every write copies the slot's previous bytes into a ring beside the save, so Restore Slot From Backup can go back to a save that was written perfectly and is simply wrong.
@export_range(0, 50, 1) var backup_count: int = 0
var autosave_accumulator: float = 0.0
## Active save slot (each slot is its own file).
@export_group("Save System")
@export_range(0, 9, 1) var slot: int = 0

# Reserved keys. Everything the pack writes for itself lives under a "__" name so it
# cannot collide with a game's own keys: __persist (the scene-tree snapshot), __card
# (the load-menu header), __version (which build wrote the file), __addons (the
# autoload snapshot) and __run (the New Game Plus counter).
const CARD_KEY: String = "__card"
const VERSION_KEY: String = "__version"
const ADDONS_KEY: String = "__addons"
const RUN_KEY: String = "__run"
const READ_OPEN_PROBLEM: String = "the file could not be opened (a wrong encryption key is the usual cause)"
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
# Why the last read failed, as a plain sentence ("" when it worked). The triggers wrap
# it into a player-facing line; Slot Problem hands it to a menu tile.
var _last_read_problem: String = ""
# The last failure of ANY kind, kept for Last Save Problem.
var _last_problem: String = ""
# Seconds counted since this slot's playtime was last banked into its card, so nobody has
# to wire a timer for it. Playtime belongs to the SLOT, not to this object: the count
# restarts whenever the ACTIVE SLOT changes, so a menu instance that never loaded a game
# cannot stamp its own session onto a slot it merely wrote a card line to, and banking ADDS
# the session to the card's own total instead of overwriting (or ratcheting) it.
var _playtime: float = 0.0
var _playtime_slot: int = -1
var _autosave_paused: bool = false
# Keys Never Save This Key has excluded, dropped on the way to the file whichever row
# wrote them, and keys Carry Value Into Next Run keeps through Start New Run.
var _never_save: PackedStringArray = PackedStringArray()
var _carried: PackedStringArray = PackedStringArray()
# Set by Use Upgraded Save so Load Game knows to pick the migrated record back up.
var _upgrade_applied: bool = false
func _backups_for(target_slot: int) -> PackedStringArray:
	var found: Array = []
	var dir_path: String = _backup_dir_for(target_slot)
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return PackedStringArray()
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		# A .tmp is a write in flight, or the wreck of one - never part of the ring.
		if not dir.current_is_dir() and not entry.ends_with(".tmp"):
			found.append(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	# Newest first, by SEQUENCE NUMBER rather than by name: a plain text sort puts "10000"
	# below "9999", so a slot past ten thousand writes would invert its own ring - handing
	# Restore Slot From Backup the oldest file while the prune deleted the newest.
	found.sort_custom(func(first: String, second: String) -> bool: return _backup_index_of(first) > _backup_index_of(second))
	return PackedStringArray(found)

## Runs this event's actions once per slot that has a save file - the load menu, as
## one row. Read the current one as `slot_index`, then fill the tile with Slot Detail
## and Slot Playtime (both read straight off disk, nothing is loaded).
## @ace_looping(slot_index)
## @ace_name("For Each Saved Slot")
## @ace_category("Save System")
func each_saved_slot() -> Array:
	return list_slots()
## Runs this event's actions once per autoload that saves itself, so a debug panel can
## list exactly what the save covers - and, by its absence, what quietly does not. Read
## the current one as `addon_name`.
## @ace_looping(addon_name)
## @ace_name("For Each Saveable Addon")
## @ace_category("Save System")
func each_saveable_addon() -> Array:
	return _collect_addon_states().keys()
## Runs this event's actions once per kept backup of the slot, newest first. Read the
## current one as `backup_path` - a real file path, so File Size (bytes) and Read Save
## File work on it, and its position in the loop is the "how many back" number.
## @ace_looping(backup_path)
## @ace_name("For Each Backup Of Slot")
## @ace_category("Save System")
func each_backup_of_slot(slot_index: int) -> Array:
	var found: Array = []
	for backup_path: String in _backups_for(slot_index):
		found.append(backup_path)
	return found

# The save and load windows, counted rather than flagged. This pack writes synchronously
# (a .tmp, then a rename), so a window is short - but an On Before Save handler that saves
# a key of its own opens a second one INSIDE it, and a plain bool would close the outer
# window when the inner write finished. Is Saving and Is Loading read these.
var _write_depth: int = 0
var _load_depth: int = 0

func _process(delta: float) -> void:
	if _playtime_slot != slot:
		# The active slot changed. Whatever was counted belongs to the slot that was active and
		# was banked by its last save, so the new slot starts its own count at zero.
		_playtime_slot = slot
		_playtime = 0.0
	_playtime += delta
	if autosave_interval <= 0.0 or _autosave_paused:
		return
	autosave_accumulator += delta
	if autosave_accumulator >= autosave_interval:
		autosave_accumulator = 0.0
		# The blind interval becomes a MOMENT the sheet can veto: with a handler connected
		# the trigger fires instead of saving and the event's conditions decide. With none
		# connected the pack saves itself, exactly as it did before.
		if autosave_due.get_connections().is_empty():
			save_game()
		else:
			autosave_due.emit(slot)

## @ace_action
## @ace_name("Save Value")
## @ace_category("Save System")
## @ace_description("Writes ANY value (number, text, Vector2, Color, Dictionary…) under the key.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_value({key}, {value})")
func save_value(key: String, value: Variant) -> void:
	var data: Dictionary = _read_all()
	if not _last_read_ok:
		_fail_save(slot, "slot %d exists but could not be read - refusing to overwrite it (%s)." % [slot, _last_read_problem])
		return
	data[key] = value
	if not _write_all(data):
		_fail_save(slot, "slot %d could not be written - is the save folder writable?" % slot)
		return
	# The write landed. A key on the Never Save This Key list was dropped on the way to the
	# file, so the file is fine but THIS key is not in it - saying it saved would be the one
	# lie On Key Saved exists to prevent.
	if not _never_save.has(key):
		key_saved.emit(key, slot)

## @ace_expression
## @ace_name("Load Value")
## @ace_category("Save System")
## @ace_description("Reads any value (your default when missing).")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.load_value({key}, {default_value})")
func load_value(key: String, default_value: Variant) -> Variant:
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
## @ace_description("Removes the active slot's save file (and its slot picture, which lives beside it).")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.delete_slot()")
func delete_slot() -> void:
	if FileAccess.file_exists(_slot_path()):
		DirAccess.remove_absolute(_slot_path())
	if FileAccess.file_exists(_thumbnail_path()):
		DirAccess.remove_absolute(_thumbnail_path())

## @ace_action
## @ace_featured
## @ace_name("Save Game")
## @ace_category("Save System")
## @ace_description("Broadcasts On Before Save (every sheet writes its state), snapshots every node in the persist group, stamps the slot card, then fires On Save Written (or On Save Failed).")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_game()")
func save_game() -> void:
	_write_depth += 1
	_run_save_game()
	_write_depth -= 1

## @ace_action
## @ace_featured
## @ace_name("Load Game")
## @ace_category("Save System")
## @ace_description("Reads the slot, gives migration rows their moment (On Save Needs Upgrade) when an older build wrote it, restores every persist-group snapshot, then broadcasts On After Load. A file it cannot read fires On Load Failed instead.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.load_game()")
func load_game() -> void:
	_load_depth += 1
	_run_load_game()
	_load_depth -= 1

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

## @ace_action
## @ace_name("Set Slot Detail")
## @ace_category("Save System")
## @ace_description("Writes one line of the active slot's card - the header a load menu reads without ever calling Load Game (chapter, hero name, percent, difficulty...). Playtime rides along automatically.")
## @ace_display_template("remember [b]{detail_name}[/b] = [b]{value}[/b] on this slot")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.set_slot_detail({detail_name}, {value})")
func set_slot_detail(detail_name: String, value: Variant) -> void:
	var data: Dictionary = _read_all()
	if not _last_read_ok:
		_fail_save(slot, "slot %d exists but could not be read - refusing to overwrite it (%s)." % [slot, _last_read_problem])
		return
	var card: Dictionary = _card_of(data)
	card[detail_name] = value
	_bank_playtime(card)
	data[CARD_KEY] = card
	if not _write_all(data):
		_fail_save(slot, "slot %d could not be written - is the save folder writable?" % slot)

## @ace_expression
## @ace_name("Slot Detail")
## @ace_category("Save System")
## @ace_description("Reads one card field of any slot straight off disk (your fallback when that slot has no such detail). Nothing is loaded and nothing is applied - safe to call for every tile of a load menu.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.slot_detail({slot_index}, {detail_name}, {fallback})")
func slot_detail(slot_index: int, detail_name: String, fallback: Variant) -> Variant:
	var card: Variant = _read_path(_slot_path(slot_index), format).get(CARD_KEY, {})
	return (card as Dictionary).get(detail_name, fallback) if card is Dictionary else fallback

## @ace_expression
## @ace_name("Slot Playtime")
## @ace_category("Save System")
## @ace_description("Seconds played on that slot, accumulated by this pack and stamped on every save (0 when the slot has none). Feed it to Format Time for a 4h12m tile.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.slot_playtime({slot_index})")
func slot_playtime(slot_index: int) -> float:
	return float(_card_of(_read_path(_slot_path(slot_index), format)).get("playtime", 0.0))

## @ace_action
## @ace_name("Capture Slot Thumbnail")
## @ace_category("Save System")
## @ace_description("Photographs the viewport, shrinks it to tile size and writes it beside the active slot's file, so the picture travels with the save - Copy Slot brings it along, Delete Slot takes it away, and an encryption key covers the picture exactly as it covers the save. Hide your pause menu first.")
## @ace_display_template("photograph this slot at [b]{width}[/b] x [b]{height}[/b]")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.capture_slot_thumbnail({width}, {height})")
func capture_slot_thumbnail(width: int, height: int) -> void:
	if not is_inside_tree() or get_viewport() == null:
		# A headless run has nothing to photograph: warn and keep the old picture rather
		# than leaving a black PNG beside the save.
		push_warning("Save System: there is no viewport to photograph - the slot keeps its previous picture.")
		return
	var shot: Image = get_viewport().get_texture().get_image()
	if shot == null:
		push_warning("Save System: the viewport has not drawn a frame yet - the slot keeps its previous picture.")
		return
	shot.resize(maxi(width, 1), maxi(height, 1), Image.INTERPOLATE_LANCZOS)
	var picture_bytes: PackedByteArray = shot.save_png_to_buffer()
	if picture_bytes.is_empty():
		push_warning("Save System: the picture could not be encoded - the slot keeps its previous one.")
		return
	# The picture goes through the SAME door as the save, so an encryption key covers it too: a
	# save nobody may inspect must not ship a readable screenshot of itself beside it. Written to
	# a .tmp and renamed like every save, so a crash leaves the old picture, never half a new one.
	var tmp: String = _thumbnail_path(slot) + ".tmp"
	var out: FileAccess = _open_write(tmp)
	if out == null:
		push_warning("Save System: the slot picture could not be written - the slot keeps its previous one.")
		return
	out.store_buffer(picture_bytes)
	var write_ok: bool = out.get_error() == Error.OK
	out.close()
	if not write_ok or DirAccess.rename_absolute(tmp, _thumbnail_path(slot)) != Error.OK:
		DirAccess.remove_absolute(tmp)
		push_warning("Save System: the slot picture could not be written - the slot keeps its previous one.")

## @ace_expression
## @ace_name("Slot Thumbnail")
## @ace_category("Save System")
## @ace_description("The picture saved beside that slot, ready to drop into a TextureRect (null when the slot has none). Read off disk, so a load menu never loads a game to draw its tiles.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.slot_thumbnail({slot_index})")
func slot_thumbnail(slot_index: int) -> Texture2D:
	var path: String = _thumbnail_path(slot_index)
	if not FileAccess.file_exists(path):
		return null
	# Read through the same door it was written (encrypted when a key is set) and decoded from
	# the bytes, never through load(): a save picture lives in user://, which the resource
	# importer never sees.
	var file: FileAccess = _open_read(path)
	if file == null:
		return null
	var picture: Image = Image.new()
	if picture.load_png_from_buffer(file.get_buffer(file.get_length())) != Error.OK:
		return null
	return ImageTexture.create_from_image(picture)

## @ace_action
## @ace_name("Copy Slot")
## @ace_category("Save System")
## @ace_description("Duplicates one slot's save file (and its picture) onto another slot - branching a save as one row. The destination is overwritten.")
## @ace_display_template("copy slot [b]{from_slot}[/b] onto slot [b]{to_slot}[/b]")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.copy_slot({from_slot}, {to_slot})")
func copy_slot(from_slot: int, to_slot: int) -> void:
	var source: String = _slot_path(from_slot)
	if not FileAccess.file_exists(source):
		_fail_save(to_slot, "slot %d has no save file to copy." % from_slot)
		return
	DirAccess.make_dir_recursive_absolute(_slot_path(to_slot).get_base_dir())
	if DirAccess.copy_absolute(source, _slot_path(to_slot)) != Error.OK:
		_fail_save(to_slot, "slot %d could not be copied to slot %d." % [from_slot, to_slot])
		return
	if FileAccess.file_exists(_thumbnail_path(from_slot)):
		DirAccess.copy_absolute(_thumbnail_path(from_slot), _thumbnail_path(to_slot))
	_last_problem = ""

## @ace_expression
## @ace_name("Slot Path")
## @ace_category("Save System")
## @ace_description("Where that slot's file lives (built from the Save Directory and File Pattern properties). Feed it to Read Save File, File Size or Copy File - the paths the pack uses are no longer private.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.slot_path({slot_index})")
func slot_path(slot_index: int) -> String:
	return _slot_path(slot_index)

## @ace_action
## @ace_name("Delay Autosave By")
## @ace_category("Save System")
## @ace_description("Pushes the next autosave out by this many seconds. The beat is deferred, never dropped - use it in the not-now branch of On Autosave Due.")
## @ace_display_template("put the autosave off for [b]{seconds}[/b] more seconds")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.delay_autosave_by({seconds})")
func delay_autosave_by(seconds: float) -> void:
	# Relative, because the verb promises to DEFER the beat: setting the clock absolutely
	# would push a mid-interval save out by far more than was asked, and a second, SMALLER
	# delay would then pull the save nearer than the first one put it.
	autosave_accumulator -= absf(seconds)

## @ace_action
## @ace_name("Pause Autosave")
## @ace_category("Save System")
## @ace_description("Stops the autosave clock without losing the interval - for a boss fight, a cutscene, or a scene transition. Resume Autosave starts it again.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.pause_autosave()")
func pause_autosave() -> void:
	_autosave_paused = true

## @ace_action
## @ace_name("Resume Autosave")
## @ace_category("Save System")
## @ace_description("Starts the autosave clock again after Pause Autosave, from a fresh interval.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.resume_autosave()")
func resume_autosave() -> void:
	_autosave_paused = false
	autosave_accumulator = 0.0

## @ace_expression
## @ace_name("Seconds Until Autosave")
## @ace_category("Save System")
## @ace_description("How long until the next autosave beat - for a countdown pip in the corner. 0 when autosave is off or paused.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.seconds_until_autosave()")
func seconds_until_autosave() -> float:
	if autosave_interval <= 0.0 or _autosave_paused:
		return 0.0
	return maxf(autosave_interval - autosave_accumulator, 0.0)

## @ace_condition
## @ace_name("Autosave Is Paused")
## @ace_category("Save System")
## @ace_description("Whether Pause Autosave is currently holding the clock.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.autosave_is_paused()")
func autosave_is_paused() -> bool:
	return _autosave_paused

## @ace_condition
## @ace_name("Safe To Save Now")
## @ace_category("Save System")
## @ace_description("Whether writing the active slot right now would lose nothing: the slot either has no file yet, or its file reads back cleanly. Guard Save Game with it (and read it inside On Autosave Due before you commit to a write).")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.can_save_now()")
func can_save_now() -> bool:
	if not FileAccess.file_exists(_slot_path()):
		return true
	_read_all()
	return _last_read_ok

## @ace_action
## @ace_name("Use Upgraded Save")
## @ace_category("Save System")
## @ace_description("Writes the record the migration rows just fixed back to the slot, stamped with the current Save Version, and lets Load Game carry on with it. Run it once at the end of On Save Needs Upgrade - the stamp makes the trigger stop firing for that file.")
## @ace_display_template("use [b]{save_data}[/b] as the save from here on")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.use_upgraded_save({save_data})")
func use_upgraded_save(save_data: Dictionary) -> void:
	# THE deliberate stamp: an ordinary write leaves an older file's version alone, so this is
	# the one call that says "this record is the current shape now" and makes the trigger stop
	# firing for that file.
	_upgrade_applied = _write_all(save_data, true)
	if not _upgrade_applied:
		_fail_save(slot, "the upgraded save for slot %d could not be written." % slot)

## @ace_expression
## @ace_name("Slot Save Version")
## @ace_category("Save System")
## @ace_description("Which Save Version wrote that slot's file. A file with no stamp counts as 1, so saves written before you ever bumped the number still answer.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.slot_save_version({slot_index})")
func slot_save_version(slot_index: int) -> int:
	return int(_read_path(_slot_path(slot_index), format).get(VERSION_KEY, 1))

## @ace_condition
## @ace_name("Slot Is Readable")
## @ace_category("Save System")
## @ace_description("Whether that slot's file opens and parses. A slot with NO file reads as false, so pair it with Slot Exists to tell a slot with no save yet apart from a damaged one.")
## @ace_display_template("slot [b]{slot_index}[/b] can be read")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.slot_is_readable({slot_index})")
func slot_is_readable(slot_index: int) -> bool:
	if not FileAccess.file_exists(_slot_path(slot_index)):
		return false
	_read_path(_slot_path(slot_index), format)
	return _last_read_ok

## @ace_expression
## @ace_name("Last Save Problem")
## @ace_category("Save System")
## @ace_description("The last save or load failure as one readable sentence ("" when both worked). Show it in a label, or log it.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.last_save_problem()")
func last_save_problem() -> String:
	return _last_problem

## @ace_expression
## @ace_name("Slot Problem")
## @ace_category("Save System")
## @ace_description("What is wrong with that slot's file, as one readable sentence ("" when it reads fine or does not exist) - the tooltip for a greyed-out Continue button.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.slot_problem({slot_index})")
func slot_problem(slot_index: int) -> String:
	_read_path(_slot_path(slot_index), format)
	return _last_read_problem

## @ace_action
## @ace_featured
## @ace_name("Save All Addons")
## @ace_category("Save System")
## @ace_description("Snapshots every autoload that exposes the save_state seam - Currency Ledger, Upgrades, Prestige, Skin Vault, StatForge and anything you wrote - each under its own autoload name. There is no list to maintain: install a pack, register it, and it is in the save.")
## @ace_display_template("save every addon that saves itself")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_all_addons()")
func save_all_addons() -> void:
	save_value(ADDONS_KEY, _collect_addon_states())

## @ace_action
## @ace_name("Load All Addons")
## @ace_category("Save System")
## @ace_description("Restores every autoload snapshot Save All Addons wrote, matched by autoload name. An addon the save knows but this build does not have is reported, never dropped in silence.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.load_all_addons()")
func load_all_addons() -> void:
	var states: Variant = load_value(ADDONS_KEY, {})
	if states is Dictionary and is_inside_tree():
		_apply_children_states(get_tree().root, states as Dictionary)

## @ace_condition
## @ace_name("Addon Saves Itself")
## @ace_category("Save System")
## @ace_description("Whether that autoload takes part in Save All Addons (it exposes save_state, itself or through a behavior child). Invert it to catch the pack somebody forgot to give a save seam.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.addon_saves_itself({addon_name})")
func addon_saves_itself(addon_name: String) -> bool:
	return _collect_addon_states().has(addon_name)

## @ace_action
## @ace_name("Never Save This Key")
## @ace_category("Save System")
## @ace_description("Keeps this key out of every save from now on - cached node lists, scratch buffers, totals you recompute. It is dropped on the way to the file whichever row wrote it, and an already-saved copy disappears on the next write.")
## @ace_display_template("never put [b]{key}[/b] in a save")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.never_save_key({key})")
func never_save_key(key: String) -> void:
	if not _never_save.has(key):
		_never_save.append(key)

## @ace_expression
## @ace_name("Save Size")
## @ace_category("Save System")
## @ace_description("How many bytes the active slot's file takes on disk (0 when there is none) - the number nobody sees until a player reports a 40MB save.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_size()")
func save_size() -> int:
	return FileAccess.get_file_as_bytes(_slot_path()).size() if FileAccess.file_exists(_slot_path()) else 0

## @ace_expression
## @ace_name("Save Report")
## @ace_category("Save System")
## @ace_description("A plain-text breakdown of the active save: total bytes, key count, then the heaviest keys in order. Log it, or show it in a debug overlay when a player reports a save that will not stop growing. The total is the real size of the file on disk; the per-key numbers are relative WEIGHTS (each value written out as text, measured in characters), so they rank the keys against one another rather than adding up to the total.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_report()")
func save_report() -> String:
	var data: Dictionary = _read_all()
	var lines: PackedStringArray = PackedStringArray(["Save slot %d - %d bytes in %d keys" % [slot, save_size(), data.size()]])
	var weights: Array = []
	for key: Variant in data.keys():
		weights.append({"key": str(key), "bytes": var_to_str(data[key]).length()})
	weights.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return int(first["bytes"]) > int(second["bytes"]))
	for entry: Dictionary in weights:
		lines.append("\t%s  %d" % [str(entry["key"]), int(entry["bytes"])])
	if not _never_save.is_empty():
		lines.append("never saved: %s" % ", ".join(_never_save))
	return "\n".join(lines)

## @ace_action
## @ace_name("Restore Slot From Backup")
## @ace_category("Save System")
## @ace_description("Puts an earlier version of the slot back (1 = the save before this one, 2 = the one before that). The CURRENT file is backed up first, so a restore is never a one-way door. Needs Backup Count above 0.")
## @ace_display_template("put slot [b]{slot_index}[/b] back to backup [b]{how_many_back}[/b]")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.restore_slot_from_backup({slot_index}, {how_many_back})")
func restore_slot_from_backup(slot_index: int, how_many_back: int) -> void:
	var ring: PackedStringArray = _backups_for(slot_index)
	if how_many_back < 1 or how_many_back > ring.size():
		_fail_load(slot_index, "slot %d has no backup %d to restore - it keeps %d." % [slot_index, how_many_back, ring.size()])
		return
	# Read the wanted bytes BEFORE backing the current file up: that push can prune the
	# oldest ring entry, which may be the very one being restored.
	var wanted: PackedByteArray = FileAccess.get_file_as_bytes(ring[how_many_back - 1])
	if wanted.is_empty():
		_fail_load(slot_index, "backup %d of slot %d could not be read." % [how_many_back, slot_index])
		return
	# Restored through the same .tmp-then-rename the six write backends use, so a crash
	# mid-restore leaves the current save intact rather than a half file.
	var tmp: String = _slot_path(slot_index) + ".tmp"
	var out: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if out == null:
		_fail_load(slot_index, "slot %d could not be written while restoring its backup." % slot_index)
		return
	out.store_buffer(wanted)
	var write_ok: bool = out.get_error() == Error.OK
	out.close()
	if not write_ok:
		DirAccess.remove_absolute(tmp)
		_fail_load(slot_index, "slot %d could not be written while restoring its backup." % slot_index)
		return
	# A backup is bytes on disk like any other file, and a restore REPLACES a working save with
	# them - so it is read BACK before it is trusted. An entry that will not parse, or that
	# parses to nothing, leaves the live slot exactly where it was instead of destroying it in
	# the name of safety (the ring only ever holds saves that were overwritten, so an entry
	# holding no keys is wreckage, not a save somebody wants back).
	var restored: Dictionary = _read_path(tmp, format)
	if not _last_read_ok or restored.is_empty():
		var damage: String = _last_read_problem if not _last_read_ok else "it holds no save data"
		DirAccess.remove_absolute(tmp)
		_fail_load(slot_index, "backup %d of slot %d is damaged (%s) - slot %d was left alone." % [how_many_back, slot_index, damage, slot_index])
		return
	_push_backup(slot_index)
	if DirAccess.rename_absolute(tmp, _slot_path(slot_index)) != Error.OK:
		_fail_load(slot_index, "slot %d could not be replaced by its backup." % slot_index)
		return
	_last_problem = ""

## @ace_expression
## @ace_name("Slot Backup Count")
## @ace_category("Save System")
## @ace_description("How many earlier versions of that slot are kept right now (0 when backups are off or nothing has been overwritten yet).")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.slot_backup_count({slot_index})")
func slot_backup_count(slot_index: int) -> int:
	return _backups_for(slot_index).size()

## @ace_action
## @ace_name("Carry Value Into Next Run")
## @ace_category("Save System")
## @ace_description("Marks one key to survive Start New Run - unlocked skins, a best time, the settings. Everything not marked is wiped. Marks last for the session, so declare them right before the reset.")
## @ace_display_template("carry [b]{key}[/b] into the next run")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.carry_value_into_next_run({key})")
func carry_value_into_next_run(key: String) -> void:
	if not _carried.has(key):
		_carried.append(key)

## @ace_action
## @ace_name("Start New Run")
## @ace_category("Save System")
## @ace_description("Wipes the slot and writes back ONLY the carried keys, its slot card, and a run counter one higher than before, then fires On New Run Started. New Game Plus, a chapter reset, a seasonal wipe, or the Reset Progress button that must keep the settings.")
## @ace_display_template("start a new run in slot [b]{slot_index}[/b]")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.start_new_run({slot_index})")
func start_new_run(slot_index: int) -> void:
	var previous: Dictionary = _read_path(_slot_path(slot_index), format)
	if not _last_read_ok:
		_fail_save(slot_index, "slot %d could not be read - refusing to reset it (%s)." % [slot_index, _last_read_problem])
		return
	var kept: Dictionary = {}
	for key: String in _carried:
		if previous.has(key):
			kept[key] = previous[key]
	kept[RUN_KEY] = int(previous.get(RUN_KEY, 1)) + 1
	if previous.get(CARD_KEY, null) is Dictionary:
		kept[CARD_KEY] = previous[CARD_KEY]
	# The carried keys came out of the OLD file, so the new run holds the old shape: its stamp
	# travels with them and a pending migration still runs on the next load.
	if previous.has(VERSION_KEY):
		kept[VERSION_KEY] = previous[VERSION_KEY]
	# _write_all always writes the ACTIVE slot, so the target is borrowed and handed
	# straight back - the trigger fires with the sheet's normal active slot restored.
	var previous_slot: int = slot
	slot = slot_index
	var written: bool = _write_all(kept)
	slot = previous_slot
	if written:
		new_run_started.emit(slot_index, int(kept[RUN_KEY]))
	else:
		_fail_save(slot_index, "slot %d could not be written for the new run." % slot_index)

## @ace_expression
## @ace_name("Run Number")
## @ace_category("Save System")
## @ace_description("1 on a fresh save, 2 after the first New Game Plus, and so on - the number every NG+ banner, difficulty curve and you-have-beaten-this-N-times line is really asking for.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.run_number()")
func run_number() -> int:
	return int(_read_all().get(RUN_KEY, 1))

## @ace_action
## @ace_name("Remove Save Key")
## @ace_category("Save System")
## @ace_description("Takes one key out of the active slot and rewrites the file, then fires On Key Removed. A key the slot does not hold fires On Save Key Missing instead. Never Save This Key blocks a key forever; this removes the one copy that is already there.")
## @ace_display_template("forget [b]{key}[/b] from this slot")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.remove_save_key({key})")
func remove_save_key(key: String) -> void:
	var data: Dictionary = _read_all()
	if not _last_read_ok:
		_fail_save(slot, "slot %d exists but could not be read - refusing to overwrite it (%s)." % [slot, _last_read_problem])
		return
	if not data.has(key):
		save_key_missing.emit(key, slot)
		return
	data.erase(key)
	if _write_all(data):
		key_removed.emit(key, slot)
	else:
		_fail_save(slot, "%s could not be removed from slot %d - is the save folder writable?" % [key, slot])

## @ace_action
## @ace_name("Clear Slot Keys")
## @ace_category("Save System")
## @ace_description("Empties the active slot of everything the game saved, and fires On Key Removed once per key. The file itself stays, and so do its slot card, its version stamp, its run number and its backups - the reset-profile button that does not cost the player their save file.")
## @ace_display_template("forget everything this slot saved")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.clear_slot_keys()")
func clear_slot_keys() -> void:
	var data: Dictionary = _read_all()
	if not _last_read_ok:
		_fail_save(slot, "slot %d could not be read - refusing to clear it (%s)." % [slot, _last_read_problem])
		return
	var kept: Dictionary = {}
	var removed: Array = []
	for stored: Variant in data.keys():
		# The pack's own reserved keys stay: the card a load menu reads without loading, the
		# stamp a migration needs, and the run counter. Everything the game wrote goes.
		if str(stored) == CARD_KEY or str(stored) == VERSION_KEY or str(stored) == RUN_KEY:
			kept[stored] = data[stored]
		else:
			removed.append(str(stored))
	if removed.is_empty():
		return
	if not _write_all(kept):
		_fail_save(slot, "slot %d could not be cleared - is the save folder writable?" % slot)
		return
	# Emitted only once the file is on disk, and once per key, so a handler watching one key
	# hears about that key rather than about a slot-wide event it has to decode.
	for gone: String in removed:
		key_removed.emit(gone, slot)

## @ace_action
## @ace_name("Check Save Key")
## @ace_category("Save System")
## @ace_description("Asks the slot whether it holds the key and answers with a row: On Key Loaded when it does, On Save Key Missing when it does not. The row that turns a silent default into a first-run seed.")
## @ace_display_template("ask whether [b]{key}[/b] is saved")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.check_save_key({key})")
func check_save_key(key: String) -> void:
	var data: Dictionary = _read_all()
	if not _last_read_ok:
		_fail_load(slot, "slot %d could not be read - %s." % [slot, _last_read_problem])
		return
	if data.has(key):
		key_loaded.emit(key, slot)
	else:
		save_key_missing.emit(key, slot)

## @ace_condition
## @ace_name("Is Saving")
## @ace_category("Save System")
## @ace_description("Whether a write is in flight right now - inside On Before Save, a Save All Addons sweep, or an autosave. Guard a second write with it, or hold a quit until it clears.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.is_saving()")
func is_saving() -> bool:
	return _write_depth > 0

## @ace_condition
## @ace_name("Is Loading")
## @ace_category("Save System")
## @ace_description("Whether a load is in flight right now - the read, the migration gap and the On After Load broadcast are all inside it. Rows that must not fight the restore can stand aside while it is true.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.is_loading()")
func is_loading() -> bool:
	return _load_depth > 0

## @ace_condition
## @ace_name("Save Key Is")
## @ace_category("Save System")
## @ace_description("Whether the stored key equals this value, without loading it into a variable first. A key the slot does not hold never equals anything, so a missing key reads as false.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_key_is({key}, {value})")
func save_key_is(key: String, value: Variant) -> bool:
	return _read_all().get(key, null) == value

## @ace_expression
## @ace_name("Save Key Count")
## @ace_category("Save System")
## @ace_description("How many keys the active slot holds - the number a save inspector puts in its header. Counts exactly what List Save Keys lists, the pack's own reserved keys included.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_key_count()")
func save_key_count() -> int:
	return _read_all().size()

## @ace_expression
## @ace_name("Save Key At")
## @ace_category("Save System")
## @ace_description("The key at this position in the active slot, for a numbered or paged list ("" when the position is past the end). Loop List Save Keys instead when you just want them all.")
## @ace_icon("res://eventsheet_addons/save_system/icon.svg")
## @ace_codegen_template("SaveSystem.save_key_at({index})")
func save_key_at(index: int) -> String:
	var keys: Array = _read_all().keys()
	return str(keys[index]) if index >= 0 and index < keys.size() else ""

func _slot_path(target_slot: int = -1) -> String:
	var chosen: int = slot if target_slot < 0 else target_slot
	return save_directory.path_join(file_pattern.replace("{slot}", str(chosen)))

func _thumbnail_path(target_slot: int = -1) -> String:
	# The slot's picture lives beside the slot file, so it travels with the save, Copy Slot
	# takes it along and Delete Slot takes it away.
	return _slot_path(target_slot) + ".png"

func _to_jsonable(value: Variant) -> Variant:
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

func _from_jsonable(value: Variant) -> Variant:
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

func _read_failed(reason: String) -> Dictionary:
	_last_read_ok = false
	_last_read_problem = reason
	return {}

func _fail_save(slot_index: int, reason: String) -> void:
	# One place for every failure: it becomes a plain sentence a label can show, it still
	# reaches the Output panel for the developer, and it fires the matching trigger so the
	# sheet can tell the player. push_error alone was a developer-only channel.
	_last_problem = reason
	push_error("Save System: %s" % reason)
	save_failed.emit(slot_index, reason)

func _fail_load(slot_index: int, reason: String) -> void:
	_last_problem = reason
	push_error("Save System: %s" % reason)
	load_failed.emit(slot_index, reason)

func _card_of(data: Dictionary) -> Dictionary:
	# The slot card: the small header a load menu reads WITHOUT loading the game (chapter,
	# hero, percent, playtime). A copy, so editing it never touches the record in place.
	var card: Variant = data.get(CARD_KEY, {})
	return (card as Dictionary).duplicate() if card is Dictionary else {}

func _bank_playtime(card: Dictionary) -> Dictionary:
	# Adds the seconds counted since the last bank onto the card's OWN total and starts a fresh
	# count. The card carries the slot's real playtime, so a second instance writing the same
	# slot adds to it rather than replacing it, and a slot nobody played gains nothing. Seconds
	# counted while ANOTHER slot was active are dropped here rather than banked: they belong to
	# that slot, and a save straight after a slot switch would otherwise pour them into this one.
	var earned: float = maxf(_playtime, 0.0) if _playtime_slot == slot else 0.0
	card["playtime"] = float(card.get("playtime", 0.0)) + earned
	_playtime = 0.0
	_playtime_slot = slot
	return card

func _backup_dir_for(target_slot: int) -> String:
	# The backup ring for game saves, modelled on the editor's own ring for sheet files:
	# one folder per slot, zero-padded sequence names so lexicographic order IS age order
	# (timestamps collide on same-second saves), newest first, pruned to backup_count.
	# Atomic writes already make a TORN file impossible - this is for a save that was
	# written perfectly and is wrong (a bug that zeroed the wallet, a mis-sold item).
	return save_directory.path_join("save_backups").path_join("slot_%d" % (slot if target_slot < 0 else target_slot))

func _backup_index_of(path: String) -> int:
	# The sequence number in front of a ring entry's name ("0007.save_0.dat" -> 7).
	return int(path.get_file().get_slice(".", 0))

func _push_backup(target_slot: int) -> String:
	var chosen: int = slot if target_slot < 0 else target_slot
	var source: String = _slot_path(chosen)
	if backup_count <= 0 or not FileAccess.file_exists(source):
		return ""
	var dir_path: String = _backup_dir_for(chosen)
	DirAccess.make_dir_recursive_absolute(dir_path)
	var existing: PackedStringArray = _backups_for(chosen)
	var current_bytes: PackedByteArray = FileAccess.get_file_as_bytes(source)
	var next_index: int = 1
	if not existing.is_empty():
		# Identical to the newest entry: nothing new to protect, so the ring does not churn.
		if FileAccess.get_file_as_bytes(existing[0]) == current_bytes:
			return existing[0]
		next_index = _backup_index_of(existing[0]) + 1
	var backup_path: String = dir_path.path_join("%04d.%s" % [next_index, source.get_file()])
	# Written through the same .tmp-then-rename the six save backends use, and error-checked
	# like them: an entry left SHORT by a crash or a full disk is the one file Restore Slot
	# From Backup would otherwise copy over a perfectly good save.
	var tmp: String = backup_path + ".tmp"
	var out: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if out == null:
		return ""
	# Raw bytes, so an encrypted save stays encrypted in the ring and restores as itself.
	out.store_buffer(current_bytes)
	var write_ok: bool = out.get_error() == Error.OK
	out.close()
	if not write_ok or DirAccess.rename_absolute(tmp, backup_path) != Error.OK:
		DirAccess.remove_absolute(tmp)
		return ""
	var all_backups: PackedStringArray = _backups_for(chosen)
	for index: int in range(backup_count, all_backups.size()):
		DirAccess.remove_absolute(all_backups[index])
	return backup_path

func _read_all() -> Dictionary:
	return _read_path(_slot_path(), format)

func _read_path(path: String, fmt: String) -> Dictionary:
	# Reads any save file at `path` in `fmt` (the same six backends). Reused by the
	# active-slot read and by Read Save File, so tooling can open a file from anywhere.
	_last_read_ok = true
	_last_read_problem = ""
	if not FileAccess.file_exists(path):
		return {}
	if fmt == "json":
		var file: FileAccess = _open_read(path)
		if file == null:
			return _read_failed(READ_OPEN_PROBLEM)
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			return _read_failed("the file is not valid JSON")
		return _from_jsonable((parsed as Dictionary).get(section, {}))
	if fmt == "binary":
		var file: FileAccess = _open_read(path)
		if file == null:
			return _read_failed(READ_OPEN_PROBLEM)
		var parsed: Variant = file.get_var()
		if not parsed is Dictionary:
			return _read_failed("the file is not a binary save")
		return (parsed as Dictionary).get(section, {})
	if fmt == "csv":
		var file: FileAccess = _open_read(path)
		if file == null:
			return _read_failed(READ_OPEN_PROBLEM)
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
			return _read_failed(READ_OPEN_PROBLEM)
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
			return _read_failed(READ_OPEN_PROBLEM)
		var parser: XMLParser = XMLParser.new()
		if parser.open_buffer(file.get_as_text().to_utf8_buffer()) != Error.OK:
			return _read_failed("the file is not valid XML")
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
		return _read_failed("it may be damaged, or the encryption key is wrong")
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

func _write_file(data: Dictionary, stamp_current_version: bool = false) -> bool:
	# Atomic write: every backend writes a .tmp sibling then renames it over the slot,
	# so a crash mid-write leaves the previous good save intact, never a half-file.
	# Reached through _write_all, which is the door that opens and closes the write window.
	var path: String = _slot_path()
	var tmp: String = path + ".tmp"
	# Two facts get applied on the way out, both no-ops at their defaults so a project
	# that uses neither writes byte-identical files to the ones it wrote before:
	# keys marked Never Save This Key are dropped whichever row wrote them, and a build
	# past Save Version 1 stamps which SHAPE the file holds (no stamp = version 1).
	if not _never_save.is_empty() or save_version > 1:
		data = data.duplicate()
		for skipped: String in _never_save:
			data.erase(skipped)
		# The stamp says what shape the FILE is in, never which build last touched it. An
		# ordinary write passes an older save through with its shape unchanged, so it keeps
		# its own stamp and On Save Needs Upgrade still fires for it - otherwise one settings
		# write from the menu would mark an un-migrated file as migrated, permanently. Only a
		# brand-new file (current by definition) and the record Use Upgraded Save just fixed
		# carry this build's version.
		if save_version > 1 and (stamp_current_version or not FileAccess.file_exists(path)):
			data[VERSION_KEY] = save_version
	if backup_count > 0:
		_push_backup(slot)
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
	if DirAccess.rename_absolute(tmp, path) != Error.OK:
		return false
	# Last Save Problem describes the CURRENT state, not the first thing that ever went wrong:
	# a write that landed clears it, so a "your progress was NOT saved" banner comes down.
	_last_problem = ""
	return true

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

func _collect_children_states(parent: Node, playing: Node = null) -> Dictionary:
	# The autoload walk: every /root child answering save_state (itself or through a behavior
	# child) is in the save, keyed by its autoload name. Duck-typed exactly like the
	# persist-group walk, so installing a pack and registering it IS the whole "add it to
	# the save" step - there is no list here to fall out of date. Split from the public
	# verbs so the walk itself can be driven against any parent.
	var states: Dictionary = {}
	if parent == null:
		return states
	# `playing` is the CURRENT SCENE. It is a /root child like the autoloads, but it is the
	# GAME, not an addon: its state belongs to the persist group, keyed by node PATH.
	# Snapshotting it here would key the level by its NAME and pour that state into whatever
	# scene answers to the same name next, and would list the level as an addon in For Each
	# Saveable Addon.
	for child: Node in parent.get_children():
		if child == self or (playing != null and child == playing):
			continue
		var entry: Dictionary = _collect_node_state(child)
		if not entry.is_empty():
			states[str(child.name)] = entry
	return states

func _apply_children_states(parent: Node, states: Dictionary) -> void:
	if parent == null:
		return
	for addon_name: Variant in states.keys():
		var addon: Node = parent.get_node_or_null(NodePath(str(addon_name)))
		if addon == null:
			# The save covers an addon this build does not have (removed, renamed, or not
			# registered yet). Say so rather than dropping its state in silence.
			push_warning("Save System: no autoload named %s to restore its saved state." % str(addon_name))
			continue
		if states[addon_name] is Dictionary:
			_apply_node_state(addon, states[addon_name] as Dictionary)

func _collect_addon_states() -> Dictionary:
	return _collect_children_states(get_tree().root, get_tree().current_scene) if is_inside_tree() else {}

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

func _write_all(data: Dictionary, stamp_current_version: bool = false) -> bool:
	# Every write goes through this door, so Is Saving covers the whole window - which is
	# exactly where a second writer, a Save All Addons sweep, or a quit button does damage.
	_write_depth += 1
	var written: bool = _write_file(data, stamp_current_version)
	_write_depth -= 1
	return written

func _run_save_game() -> void:
	# Save Game's body, held one call away so the whole broadcast - On Before Save included -
	# sits inside the write window, without threading a flag through its early returns.
	before_save.emit(slot)
	var data: Dictionary = _read_all()
	if not _last_read_ok:
		_fail_save(slot, "slot %d exists but could not be read - refusing to overwrite it (%s)." % [slot, _last_read_problem])
		return
	var persisted: Dictionary = _collect_group_state(persist_group)
	if not persisted.is_empty():
		data["__persist"] = persisted
	# The slot card rides along on every full save, so a load menu can show playtime even in a
	# game that never calls Set Slot Detail. The seconds are ADDED to the slot's own total, so
	# two instances writing the same slot never overwrite each other's hours.
	var card: Dictionary = _bank_playtime(_card_of(data))
	data[CARD_KEY] = card
	if _write_all(data):
		save_written.emit(slot)
	else:
		_fail_save(slot, "slot %d could not be written - is the save folder writable?" % slot)

func _run_load_game() -> void:
	# Load Game's body, held one call away for the same reason: Is Loading stays true across
	# the read, the migration gap and the On After Load broadcast, so a row that fires during
	# the restore can tell it is looking at a game mid-load.
	var data: Dictionary = _read_all()
	if not _last_read_ok:
		_fail_load(slot, "slot %d could not be read - %s." % [slot, _last_read_problem])
		return
	# The migration seam: a file written by an older Save Version is handed to the sheet
	# BEFORE anything reads it, and Use Upgraded Save writes the fixed record back. With
	# no handler connected none of this runs, so an existing project is untouched.
	var from_version: int = int(data.get(VERSION_KEY, 1))
	if from_version < save_version and not save_needs_upgrade.get_connections().is_empty():
		_upgrade_applied = false
		save_needs_upgrade.emit(data, from_version)
		if _upgrade_applied:
			data = _read_all()
			if not _last_read_ok:
				# The one path that could report success on a FAILED read: every sheet would then
				# read its state back out of an empty record and the game would quietly start from
				# defaults with nothing said.
				_fail_load(slot, "slot %d could not be read back after its upgrade - %s." % [slot, _last_read_problem])
				return
	# A clean read is the load working: the sentence from an earlier failure comes down.
	_last_problem = ""
	# This session's count starts here; the card already holds every second banked before it.
	_playtime = 0.0
	_playtime_slot = slot
	if data.get("__persist", null) is Dictionary:
		_apply_states(data["__persist"] as Dictionary)
	after_load.emit(slot)

# Save System: register as the SaveSystem autoload, then save from any sheet. Strategy (paths/format/encryption) lives in the Inspector; On Before Save / On After Load let every sheet contribute its own state. This pack is an event sheet - extend it by editing it.
