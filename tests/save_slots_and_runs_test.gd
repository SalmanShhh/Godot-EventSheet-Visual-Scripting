# Godot EventSheets - the save-system slice a load menu, a shipped update and a New Game Plus need.
#
# Eight seams sit ON TOP of the shipped Save System pack and compose with its existing triggers
# (On Save Written / On Before Save / On After Load) rather than replacing them: slot cards read
# straight off disk, an autosave the sheet can veto, the moment between reading an old save and
# applying it, a damaged save that says a sentence, the autoload walk with no list to maintain, a
# never-save opt-out plus a weight report, a backup ring for game saves, and New Game Plus.
#
# Every verb is pinned twice - the EMITTED GDScript (a pack ships plain code, so the shape a project
# receives is part of the contract) and the RUNTIME behaviour, including the edge case the verb
# exists for. The three verbs that need a live SceneTree (Load All Addons, Addon Saves Itself, For
# Each Saveable Addon) are one-line wrappers over the duck-typed walk: the walk is driven against a
# hand-built parent here, and the wrappers are pinned for their treeless answer, because the suite
# has no scene tree to offer (run_tests.gd builds its tests before the main loop exists).
@tool
class_name SaveSlotsAndRunsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/save_system/save_system_addon.gd"
const RESOURCE_ACES := preload("res://addons/eventforge/registration/modules/resource_aces.gd")
# The tiny stateful node the addon walk is driven against: the same duck-typed save_state /
# load_state seam 27 shipped packs carry, with no base class and no registration.
const SEAM_SOURCE := """extends Node

var coins: int = 0


func save_state() -> Dictionary:
	return {"coins": coins}


func load_state(state: Dictionary) -> void:
	coins = int(state.get("coins", coins))
"""


static func run() -> bool:
	var ok: bool = true
	ok = _emitted_code_pins() and ok
	ok = _slot_cards() and ok
	ok = _autosave_moment() and ok
	ok = _migration_moment() and ok
	ok = _failures_say_a_sentence() and ok
	ok = _addon_walk() and ok
	ok = _never_save_and_report() and ok
	ok = _backup_ring() and ok
	ok = _new_game_plus() and ok
	return ok


## The emitted pack IS the deliverable: plain, dependency-free GDScript. These pin the exact
## shape a project gets - signatures, the reserved keys, the three guards that keep every new
## behaviour opt-in, and the annotation blocks the picker reads.
static func _emitted_code_pins() -> bool:
	var ok: bool = true
	var text: String = FileAccess.get_file_as_string(PACK)
	ok = _check("the pack file is on disk", text.is_empty(), false) and ok
	for pin: String in _pins():
		ok = _check("emits: %s" % pin.get_slice("\n", 0), text.contains(pin), true) and ok
	# Every new trigger reaches the PICKER with the sentence the builder wrote for it. The prose
	# above a signal is its description to the analyzer, so a lift that left the paragraph behind
	# in the block above shipped five headline triggers with nothing under their names - and the
	# emission pins above could not see it, because the prose was still in the file.
	var described: Dictionary = (EventSheetSemanticAnalyzer.new().parse_source_metadata(load(PACK)).get("signals", {}) as Dictionary)
	for signal_name: String in ["autosave_due", "save_needs_upgrade", "load_failed", "save_failed", "new_run_started"]:
		var entry: Dictionary = described.get(signal_name, {})
		ok = _check("the picker describes %s" % signal_name, str(entry.get("description", "")).begins_with("Fires "), true) and ok
	return ok


static func _pins() -> PackedStringArray:
	return PackedStringArray([
		# The five new triggers.
		"signal autosave_due(slot_index: int)",
		"signal save_needs_upgrade(save_data: Dictionary, from_version: int)",
		"signal load_failed(slot_index: int, reason: String)",
		"signal save_failed(slot_index: int, reason: String)",
		"signal new_run_started(slot_index: int, run_number: int)",
		# The two new Inspector knobs, both inert at their defaults.
		"@export_range(1, 999, 1) var save_version: int = 1",
		"@export_range(0, 50, 1) var backup_count: int = 0",
		# Reserved keys: everything the pack writes for itself is namespaced.
		"const CARD_KEY: String = \"__card\"",
		"const VERSION_KEY: String = \"__version\"",
		"const ADDONS_KEY: String = \"__addons\"",
		"const RUN_KEY: String = \"__run\"",
		# The autosave tick: the trigger REPLACES the save only when somebody is listening.
		"\t\tif autosave_due.get_connections().is_empty():\n\t\t\tsave_game()\n\t\telse:\n\t\t\tautosave_due.emit(slot)",
		# The write path: never-save keys and the version stamp are both no-ops at defaults, and the
		# stamp marks the file's SHAPE - a plain write leaves an older file's version alone.
		"\tif not _never_save.is_empty() or save_version > 1:\n\t\tdata = data.duplicate()\n\t\tfor skipped: String in _never_save:\n\t\t\tdata.erase(skipped)",
		"\t\tif save_version > 1 and (stamp_current_version or not FileAccess.file_exists(path)):\n\t\t\tdata[VERSION_KEY] = save_version",
		"func _write_all(data: Dictionary, stamp_current_version: bool = false) -> bool:",
		"\tif backup_count > 0:\n\t\t_push_backup(slot)",
		# The migration gap inside Load Game, gated on a connected handler.
		"\tvar from_version: int = int(data.get(VERSION_KEY, 1))\n\tif from_version < save_version and not save_needs_upgrade.get_connections().is_empty():\n\t\t_upgrade_applied = false\n\t\tsave_needs_upgrade.emit(data, from_version)\n\t\tif _upgrade_applied:\n\t\t\tdata = _read_all()",
		# Slot cards (#26). Playtime is banked per SLOT: added to the card's own total, never
		# stamped over it, and the count restarts when the active slot changes.
		"func set_slot_detail(detail_name: String, value: Variant) -> void:",
		"\tvar earned: float = maxf(_playtime, 0.0) if _playtime_slot == slot else 0.0\n\tcard[\"playtime\"] = float(card.get(\"playtime\", 0.0)) + earned\n\t_playtime = 0.0\n\t_playtime_slot = slot",
		"\tif _playtime_slot != slot:",
		"func slot_detail(slot_index: int, detail_name: String, fallback: Variant) -> Variant:",
		"func slot_playtime(slot_index: int) -> float:",
		"func capture_slot_thumbnail(width: int, height: int) -> void:",
		# The picture travels through the pack's OWN doors, so an encryption key covers it too.
		"\tvar out: FileAccess = _open_write(tmp)",
		"func slot_thumbnail(slot_index: int) -> Texture2D:",
		"\tvar file: FileAccess = _open_read(path)",
		"func copy_slot(from_slot: int, to_slot: int) -> void:",
		"func slot_path(slot_index: int) -> String:\n\treturn _slot_path(slot_index)",
		"## @ace_looping(slot_index)\n## @ace_name(\"For Each Saved Slot\")",
		# The autosave moment (#27). The delay is RELATIVE - it defers the beat by what was asked.
		"\tautosave_accumulator -= absf(seconds)",
		"func pause_autosave() -> void:\n\t_autosave_paused = true",
		"func resume_autosave() -> void:\n\t_autosave_paused = false\n\tautosave_accumulator = 0.0",
		"func seconds_until_autosave() -> float:\n\tif autosave_interval <= 0.0 or _autosave_paused:\n\t\treturn 0.0",
		"func autosave_is_paused() -> bool:\n\treturn _autosave_paused",
		"func can_save_now() -> bool:",
		# Migration (#28). Use Upgraded Save is the ONE write that stamps the current version.
		"func use_upgraded_save(save_data: Dictionary) -> void:",
		"\t_upgrade_applied = _write_all(save_data, true)",
		"func slot_save_version(slot_index: int) -> int:\n\treturn int(_read_path(_slot_path(slot_index), format).get(VERSION_KEY, 1))",
		# Damaged saves (#29).
		"func slot_is_readable(slot_index: int) -> bool:",
		"func last_save_problem() -> String:\n\treturn _last_problem",
		"func slot_problem(slot_index: int) -> String:",
		"func _fail_load(slot_index: int, reason: String) -> void:",
		"func _fail_save(slot_index: int, reason: String) -> void:",
		# The addon walk (#30).
		"## @ace_featured\n## @ace_name(\"Save All Addons\")",
		"func save_all_addons() -> void:\n\tsave_value(ADDONS_KEY, _collect_addon_states())",
		"func load_all_addons() -> void:",
		"func addon_saves_itself(addon_name: String) -> bool:\n\treturn _collect_addon_states().has(addon_name)",
		# The walk is handed the CURRENT SCENE so it can skip it: the game is a /root child too.
		"func _collect_addon_states() -> Dictionary:\n\treturn _collect_children_states(get_tree().root, get_tree().current_scene) if is_inside_tree() else {}",
		"\t\tif child == self or (playing != null and child == playing):",
		"## @ace_looping(addon_name)\n## @ace_name(\"For Each Saveable Addon\")",
		# Never save this, and what the save costs (#31).
		"func never_save_key(key: String) -> void:",
		"func save_size() -> int:",
		"func save_report() -> String:",
		# The backup ring (#32): the wanted bytes are read BEFORE the pre-restore push, which
		# can prune the very entry being restored - and the backup is READ BACK before the live
		# slot is replaced with it, so a damaged entry cannot destroy a good save.
		"func restore_slot_from_backup(slot_index: int, how_many_back: int) -> void:",
		"\tvar wanted: PackedByteArray = FileAccess.get_file_as_bytes(ring[how_many_back - 1])\n\tif wanted.is_empty():\n\t\t_fail_load(slot_index, \"backup %d of slot %d could not be read.\" % [how_many_back, slot_index])\n\t\treturn",
		"\tvar restored: Dictionary = _read_path(tmp, format)\n\tif not _last_read_ok or restored.is_empty():",
		"\t_push_backup(slot_index)\n\tif DirAccess.rename_absolute(tmp, _slot_path(slot_index)) != Error.OK:",
		# The ring is written atomically and error-checked like every other save, and ordered by
		# its SEQUENCE NUMBER so it cannot invert once a slot passes ten thousand writes.
		"\tif not write_ok or DirAccess.rename_absolute(tmp, backup_path) != Error.OK:",
		"func _backup_index_of(path: String) -> int:",
		"\treturn int(path.get_file().get_slice(\".\", 0))",
		"\tfound.sort_custom(func(first: String, second: String) -> bool: return _backup_index_of(first) > _backup_index_of(second))",
		"func slot_backup_count(slot_index: int) -> int:\n\treturn _backups_for(slot_index).size()",
		"## @ace_looping(backup_path)\n## @ace_name(\"For Each Backup Of Slot\")",
		# New Game Plus (#33).
		"func carry_value_into_next_run(key: String) -> void:",
		"func start_new_run(slot_index: int) -> void:",
		"\tkept[RUN_KEY] = int(previous.get(RUN_KEY, 1)) + 1",
		"func run_number() -> int:\n\treturn int(_read_all().get(RUN_KEY, 1))",
		"## @ace_display_template(\"start a new run in slot [b]{slot_index}[/b]\")"
	])


## #26 - the header a load menu shows without loading the game: named details, playtime the
## pack accumulates itself, a picture bound to the slot, Copy Slot and Slot Path.
static func _slot_cards() -> bool:
	var ok: bool = true
	var system: Node = _new_system("cards")
	system.save_value("coins", 12)
	system.set_slot_detail("chapter", "Ilsa in the deep")
	system.set_slot_detail("percent", 61)

	# The point of a card: a DIFFERENT instance reads it off disk without ever loading.
	var menu: Node = _new_system("cards")
	ok = _check("a card detail reads back off disk", str(menu.slot_detail(0, "chapter", "New game")), "Ilsa in the deep") and ok
	ok = _check("a numeric detail keeps its type", menu.slot_detail(0, "percent", 0), 61) and ok
	ok = _check("a detail the slot lacks falls back", str(menu.slot_detail(0, "hero", "nobody")), "nobody") and ok
	ok = _check("a slot with no file falls back", str(menu.slot_detail(6, "chapter", "New game")), "New game") and ok
	ok = _check("reading a card applies nothing to the game", menu.get("_playtime"), 0.0) and ok
	ok = _check("the card leaves the game's own keys alone", menu.load_value("coins", 0), 12) and ok

	# Playtime: accumulated by the pack and BANKED into the slot's card on every full save - the
	# seconds are added to the slot's own total, so a second session continues it.
	for _step: int in range(4):
		system._process(0.5)
	system.save_game()
	ok = _check("playtime is banked onto the slot", snappedf(float(menu.slot_playtime(0)), 0.01), 2.0) and ok
	for _step: int in range(2):
		system._process(0.5)
	system.save_game()
	ok = _check("a second session adds to the slot's total", snappedf(float(menu.slot_playtime(0)), 0.01), 3.0) and ok
	menu.load_game()
	ok = _check("Load Game starts this session's count at zero (the card holds the rest)", snappedf(float(menu.get("_playtime")), 0.01), 0.0) and ok
	# The edge this exists for: a menu-only instance that never loaded must not stamp its own
	# short session over hours of play.
	var fresh: Node = _new_system("cards")
	fresh.save_game()
	ok = _check("playtime never goes backwards on a slot", snappedf(float(menu.slot_playtime(0)), 0.01), 3.0) and ok
	# THE edge the per-slot counter exists for: playtime belongs to the SLOT. An instance that
	# played slot 0 for hours and then starts a new game in slot 1 must not stamp those hours onto
	# slot 1 - and must not raise slot 0's total either.
	system.slot = 2
	system._process(0.25)
	system.save_game()
	ok = _check("a new slot starts its own count", snappedf(float(menu.slot_playtime(2)), 0.01), 0.25) and ok
	ok = _check("and the slot that was played keeps its own total", snappedf(float(menu.slot_playtime(0)), 0.01), 3.0) and ok
	# The same edge without a single frame in between: seconds counted while slot 2 was active
	# belong to slot 2, so a save on slot 5 the instant after the switch banks nothing.
	system.slot = 2
	for _step: int in range(20):
		system._process(0.5)
	system.slot = 5
	system.save_game()
	ok = _check("a save straight after a slot switch banks nothing on the new slot",
		snappedf(float(menu.slot_playtime(5)), 0.01), 0.0) and ok
	system.slot = 0

	# The picture travels with the slot: read off disk, copied by Copy Slot, removed by Delete Slot.
	var thumb: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	thumb.fill(Color.RED)
	thumb.save_png(str(system.call("_thumbnail_path", 0)))
	var picture: Texture2D = system.slot_thumbnail(0)
	ok = _check("Slot Thumbnail loads the picture beside the slot", picture != null, true) and ok
	ok = _check("Slot Thumbnail keeps its size", picture.get_width() if picture != null else -1, 4) and ok
	ok = _check("Slot Thumbnail is null when the slot has none", system.slot_thumbnail(6) == null, true) and ok
	# Headless: nothing to photograph, so it warns and writes nothing rather than leaving a black PNG.
	var lonely: Node = _new_system("shotless")
	lonely.capture_slot_thumbnail(256, 144)
	ok = _check("Capture Slot Thumbnail writes nothing without a viewport", FileAccess.file_exists(str(lonely.call("_thumbnail_path", 0))), false) and ok

	# THE leak the picture must not be: with an encryption key set, a save nobody may inspect would
	# otherwise ship a readable screenshot of itself beside it. The picture goes through the pack's
	# own _open_write / _open_read doors (the emitted-code pin above holds the verb to that one), so
	# the bytes on disk are not a PNG and only the pack reads them back.
	var locked: Node = _new_system("locked")
	locked.encryption_key = "not-in-screenshots"
	var secret: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	secret.fill(Color.BLUE)
	var door: FileAccess = locked.call("_open_write", str(locked.call("_thumbnail_path", 0)))
	door.store_buffer(secret.save_png_to_buffer())
	door.close()
	var on_disk: PackedByteArray = FileAccess.get_file_as_bytes(str(locked.call("_thumbnail_path", 0)))
	# A PNG announces itself in its first four bytes; an encrypted file opens with Godot's own
	# GDEC header instead, so no image tool can open the picture beside an encrypted save.
	ok = _check("an encrypted slot's picture is not a readable PNG on disk",
		on_disk.slice(1, 4).get_string_from_ascii(), "DEC") and ok
	var unlocked: Texture2D = locked.slot_thumbnail(0)
	ok = _check("but Slot Thumbnail still reads it back", unlocked != null, true) and ok
	ok = _check("at its own size", unlocked.get_width() if unlocked != null else -1, 8) and ok

	system.copy_slot(0, 4)
	ok = _check("Copy Slot duplicates the save", FileAccess.file_exists(str(system.call("_slot_path", 4))), true) and ok
	ok = _check("Copy Slot carries the card across", str(menu.slot_detail(4, "chapter", "New game")), "Ilsa in the deep") and ok
	ok = _check("Copy Slot carries the picture across", FileAccess.file_exists(str(system.call("_thumbnail_path", 4))), true) and ok
	system.copy_slot(6, 5)
	ok = _check("copying a slot with no file is refused, not silent", str(system.last_save_problem()), "slot 6 has no save file to copy.") and ok

	ok = _check("Slot Path hands out the path the pack uses", str(system.slot_path(4)), str(system.call("_slot_path", 4))) and ok
	ok = _check("Read Save File opens what Slot Path returns", system.read_file(str(system.slot_path(0)), "").get("coins", 0), 12) and ok
	ok = _check("For Each Saved Slot walks the slots that exist", system.each_saved_slot(), system.list_slots()) and ok

	system.slot = 4
	system.delete_slot()
	ok = _check("Delete Slot takes the picture with it", FileAccess.file_exists(str(system.call("_thumbnail_path", 4))), false) and ok
	system.slot = 0

	_cleanup(system, [0, 2, 4, 5, 6])
	_cleanup(menu, [])
	_cleanup(fresh, [])
	_cleanup(lonely, [0])
	_cleanup(locked, [0])
	return ok


## #27 - the blind interval becomes a moment the sheet can veto. Nothing connected must behave
## exactly as the shipped pack always did.
static func _autosave_moment() -> bool:
	var ok: bool = true
	# With nobody listening the pack still saves itself on the interval.
	var quiet: Node = _new_system("autoquiet")
	quiet.autosave_interval = 0.5
	var quiet_saves: Array = []
	quiet.save_written.connect(func(index: int) -> void: quiet_saves.append(index))
	for _step: int in range(40):
		quiet._process(1.0 / 60.0)
	ok = _check("with no handler the autosave still writes (unchanged behaviour)", quiet_saves.size(), 1) and ok

	# With a handler the beat becomes a trigger and NOTHING is written until the sheet says so.
	var vetoed: Node = _new_system("autoveto")
	vetoed.autosave_interval = 0.5
	var due: Array = []
	var wrote: Array = []
	vetoed.autosave_due.connect(func(index: int) -> void: due.append(index))
	vetoed.save_written.connect(func(index: int) -> void: wrote.append(index))
	for _step: int in range(40):
		vetoed._process(1.0 / 60.0)
	ok = _check("On Autosave Due fires once when the clock comes round", due.size(), 1) and ok
	ok = _check("a handled autosave writes nothing by itself", wrote.size(), 0) and ok
	ok = _check("a vetoed autosave leaves no file", vetoed.slot_exists(0), false) and ok

	# Deferring pushes the next beat out BY WHAT WAS ASKED, from wherever the clock stands - the
	# verb promises to defer the beat, so a second, smaller delay can never pull the save nearer
	# than the first one put it.
	vetoed.autosave_accumulator = 0.4
	vetoed.delay_autosave_by(1.0)
	ok = _check("Delay Autosave By defers the beat by the seconds it was given", snappedf(float(vetoed.seconds_until_autosave()), 0.01), 1.1) and ok
	vetoed.delay_autosave_by(0.5)
	ok = _check("a second, smaller delay pushes it further out, never nearer", snappedf(float(vetoed.seconds_until_autosave()), 0.01), 1.6) and ok
	vetoed.resume_autosave()
	ok = _check("Resume Autosave restarts a whole interval", snappedf(float(vetoed.seconds_until_autosave()), 0.01), 0.5) and ok

	# Pausing holds the clock without losing the interval.
	vetoed.pause_autosave()
	ok = _check("Autosave Is Paused reports the hold", vetoed.autosave_is_paused(), true) and ok
	ok = _check("a paused autosave has no countdown", float(vetoed.seconds_until_autosave()), 0.0) and ok
	due.clear()
	for _step: int in range(120):
		vetoed._process(1.0 / 60.0)
	ok = _check("a paused autosave never comes due", due.size(), 0) and ok
	vetoed.resume_autosave()
	ok = _check("Resume Autosave releases the clock", vetoed.autosave_is_paused(), false) and ok

	# Safe To Save Now: a slot with no file is safe, a good file is safe, a damaged one is not.
	var guard: Node = _new_system("autosafe")
	ok = _check("a slot with no file is safe to write", guard.can_save_now(), true) and ok
	guard.save_value("hp", 10)
	ok = _check("a slot that reads back cleanly is safe to write", guard.can_save_now(), true) and ok
	guard.encryption_key = "wrongkey"
	ok = _check("a slot that cannot be read is NOT safe to write", guard.can_save_now(), false) and ok
	guard.encryption_key = ""

	_cleanup(quiet, [0])
	_cleanup(vetoed, [0])
	_cleanup(guard, [0])
	return ok


## #28 - the moment between reading an old save and applying it, where the shipped migration
## verbs (Data Is Older Than Version / Rename Field / Stamp Data Version) run.
static func _migration_moment() -> bool:
	var ok: bool = true
	# The handler below runs the SHIPPED Rename Field code, not a rewrite of it - pinned here so
	# a change to that template breaks this composition loudly.
	var rename_template: String = ""
	for descriptor: ACEDescriptor in RESOURCE_ACES.get_descriptors():
		if descriptor.ace_id == "RenameField":
			rename_template = descriptor.codegen_template
	var baked: String = rename_template.replace("{record}", "save_data").replace("{from_field}", "\"hp\"").replace("{to_field}", "\"health\"")
	ok = _check("Rename Field still bakes the guarded move-then-erase this test runs",
		baked, "if save_data.has(\"hp\"):\n\tsave_data[\"health\"] = save_data[\"hp\"]\n\tsave_data.erase(\"hp\")") and ok

	# A file written by build 1.
	var shipped: Node = _new_system("migrate")
	shipped.save_value("hp", 5)
	shipped.save_value("room", "cave")
	ok = _check("a build that never bumped the version stamps nothing", shipped.has_save_key("__version"), false) and ok
	ok = _check("an unstamped file counts as version 1", shipped.slot_save_version(0), 1) and ok

	# Build 2 opens it: the trigger fires in the gap, the rows fix the record, Use Upgraded Save
	# hands it back, and On After Load then reads the NEW shape.
	var updated: Node = _new_system("migrate")
	updated.save_version = 2
	var seen: Array = []
	var after: Array = []
	var migrate: Callable = func(save_data: Dictionary, from_version: int) -> void:
		seen.append(from_version)
		if save_data.has("hp"):
			save_data["health"] = save_data["hp"]
			save_data.erase("hp")
		updated.use_upgraded_save(save_data)
	updated.save_needs_upgrade.connect(migrate)
	updated.after_load.connect(func(index: int) -> void: after.append(updated.load_value("health", -1)))
	updated.load_game()
	ok = _check("On Save Needs Upgrade fires once, carrying the old version", seen, [1]) and ok
	ok = _check("the migrated field is on disk", updated.load_value("health", -1), 5) and ok
	ok = _check("the old field is gone", updated.has_save_key("hp"), false) and ok
	ok = _check("the untouched field survives", str(updated.load_value("room", "")), "cave") and ok
	ok = _check("Use Upgraded Save stamps the current version", updated.slot_save_version(0), 2) and ok
	ok = _check("On After Load runs AFTER the migration and reads the new shape", after, [5]) and ok

	# The edge it exists for: the stamp makes it stop firing, so a migration never runs twice.
	updated.load_game()
	ok = _check("an already-upgraded file does not fire the trigger again", seen, [1]) and ok

	# THE edge the stamp rule exists for: an ORDINARY write must not mark an un-migrated file as
	# migrated. One settings save from the main menu before the player presses Continue would
	# otherwise stamp the current version onto a v1 record, and the migration would never run.
	var pending: Node = _new_system("migrate_pending")
	pending.save_value("hp", 3)
	var opener: Node = _new_system("migrate_pending")
	opener.save_version = 2
	var pending_seen: Array = []
	opener.save_needs_upgrade.connect(func(save_data: Dictionary, from_version: int) -> void:
		pending_seen.append(from_version)
		save_data["health"] = save_data["hp"]
		save_data.erase("hp")
		opener.use_upgraded_save(save_data))
	opener.save_value("last_menu_tab", 3)
	ok = _check("a plain write leaves an older file's version where it was", opener.slot_save_version(0), 1) and ok
	opener.load_game()
	ok = _check("so the migration still fires after it", pending_seen, [1]) and ok
	ok = _check("and the field really migrated", opener.load_value("health", -1), 3) and ok
	ok = _check("only then is the file stamped", opener.slot_save_version(0), 2) and ok

	# A brand-new file IS the current shape, so it is stamped on the way out and a fresh game
	# never fires a migration at itself.
	var born: Node = _new_system("migrate_fresh")
	born.save_version = 3
	var born_seen: Array = []
	born.save_needs_upgrade.connect(func(_data: Dictionary, from_version: int) -> void: born_seen.append(from_version))
	born.save_value("coins", 1)
	ok = _check("a file this build created is stamped current", born.slot_save_version(0), 3) and ok
	born.load_game()
	ok = _check("so a fresh save never asks to be migrated", born_seen, []) and ok

	# A read that fails AFTER the upgrade is a failed load, not an empty one: without the recheck
	# every sheet would read its state back out of {} and the game would start from defaults.
	var late: Node = _new_system("migrate_late")
	late.save_value("hp", 9)
	var late_reader: Node = _new_system("migrate_late")
	late_reader.save_version = 2
	var late_loads: Array = []
	var late_failures: Array = []
	late_reader.after_load.connect(func(index: int) -> void: late_loads.append(index))
	late_reader.load_failed.connect(func(index: int, reason: String) -> void: late_failures.append(reason))
	late_reader.save_needs_upgrade.connect(func(save_data: Dictionary, _from: int) -> void:
		late_reader.use_upgraded_save(save_data)
		late_reader.encryption_key = "now-unreadable")
	late_reader.load_game()
	ok = _check("a failed read after the upgrade is reported", late_failures,
		["slot 0 could not be read back after its upgrade - it may be damaged, or the encryption key is wrong."]) and ok
	ok = _check("and On After Load does NOT fire as if all was well", late_loads, []) and ok
	late_reader.encryption_key = ""

	# Nothing connected: Load Game behaves exactly as it did before - no rewrite, no stamp.
	var untouched: Node = _new_system("migrate_quiet")
	untouched.save_value("hp", 7)
	var reader: Node = _new_system("migrate_quiet")
	reader.save_version = 4
	var quiet_loads: Array = []
	reader.after_load.connect(func(index: int) -> void: quiet_loads.append(index))
	reader.load_game()
	ok = _check("with no handler an old file still loads", quiet_loads, [0]) and ok
	ok = _check("with no handler nothing is rewritten", reader.slot_save_version(0), 1) and ok

	_cleanup(shipped, [0])
	_cleanup(updated, [])
	_cleanup(untouched, [0])
	_cleanup(reader, [])
	_cleanup(pending, [0])
	_cleanup(opener, [])
	_cleanup(born, [0])
	_cleanup(late, [0])
	_cleanup(late_reader, [])
	return ok


## #29 - the corrupt guard already refused to overwrite a damaged save; now it says so out loud.
static func _failures_say_a_sentence() -> bool:
	var ok: bool = true
	var system: Node = _new_system("damaged")
	system.save_value("coins", 100)
	ok = _check("a healthy slot has no problem to report", str(system.last_save_problem()), "") and ok
	ok = _check("a healthy slot is readable", system.slot_is_readable(0), true) and ok
	ok = _check("a healthy slot has no problem sentence", str(system.slot_problem(0)), "") and ok
	ok = _check("a slot with no file is NOT readable (pair it with Slot Exists)", system.slot_is_readable(6), false) and ok

	# A wrong key is the everyday corruption: the file exists and will not open.
	system.encryption_key = "wrongkey"
	var failures: Array = []
	var loads: Array = []
	system.load_failed.connect(func(index: int, reason: String) -> void: failures.append("%d:%s" % [index, reason]))
	system.after_load.connect(func(index: int) -> void: loads.append(index))
	system.load_game()
	ok = _check("On Load Failed fires with a readable sentence", failures,
		["0:slot 0 could not be read - it may be damaged, or the encryption key is wrong."]) and ok
	ok = _check("a failed load does NOT tell the sheets to read their state back", loads.size(), 0) and ok
	ok = _check("Last Save Problem holds the sentence", str(system.last_save_problem()),
		"slot 0 could not be read - it may be damaged, or the encryption key is wrong.") and ok
	ok = _check("Slot Is Readable turns false on the damaged slot", system.slot_is_readable(0), false) and ok
	ok = _check("Slot Problem names the cause for that one tile", str(system.slot_problem(0)),
		"it may be damaged, or the encryption key is wrong") and ok

	# A refused write is the other half: it fires On Save Failed and the good file survives.
	var refusals: Array = []
	system.save_failed.connect(func(index: int, reason: String) -> void: refusals.append(reason))
	system.save_game()
	ok = _check("On Save Failed fires when the write is refused", refusals,
		["slot 0 exists but could not be read - refusing to overwrite it (it may be damaged, or the encryption key is wrong)."]) and ok
	system.encryption_key = ""
	ok = _check("the refused write left the good save intact", system.load_value("coins", -1), 100) and ok
	ok = _check("the slot reads again once the key is right", system.slot_is_readable(0), true) and ok
	# The sentence describes the CURRENT state: a write that lands takes the banner down again,
	# rather than leaving one transient failure on screen for the rest of the session.
	system.save_game()
	ok = _check("a save that works clears the problem sentence", str(system.last_save_problem()), "") and ok

	_cleanup(system, [0])
	return ok


## #30 - every autoload that saves itself, with no hand-maintained list. The walk is the seam;
## the public verbs are one-line wrappers over it (a live /root needs a scene tree).
static func _addon_walk() -> bool:
	var ok: bool = true
	var seam: GDScript = GDScript.new()
	seam.source_code = SEAM_SOURCE
	ok = _check("the test's save_state seam compiles", seam.reload(), OK) and ok

	var root: Node = Node.new()
	var ledger: Node = seam.new()
	ledger.name = "CurrencyLedger"
	ledger.coins = 7
	root.add_child(ledger)
	var plain: Node = Node.new()
	plain.name = "SceneRoot"
	root.add_child(plain)
	var hosted: Node = Node.new()
	hosted.name = "Upgrades"
	var behavior: Node = seam.new()
	behavior.name = "UpgradeStore"
	behavior.coins = 3
	hosted.add_child(behavior)
	root.add_child(hosted)

	var system: Node = _new_system("addons")
	var states: Dictionary = system.call("_collect_children_states", root, null)
	ok = _check("the walk finds the autoload that saves itself", states.has("CurrencyLedger"), true) and ok
	ok = _check("it finds an autoload whose BEHAVIOR child saves itself", states.has("Upgrades"), true) and ok
	ok = _check("an autoload with no seam is skipped (no list to maintain, no empty rows)", states.has("SceneRoot"), false) and ok
	ok = _check("the state is keyed by autoload name", (states["CurrencyLedger"] as Dictionary)["."], {"coins": 7}) and ok
	ok = _check("a behavior child is keyed by its own name", (states["Upgrades"] as Dictionary)["UpgradeStore"], {"coins": 3}) and ok

	# THE edge: /root holds the CURRENT SCENE as well as the autoloads, and a level whose own root
	# (or whose behavior child) saves itself is entirely ordinary here. Snapshotting it as an addon
	# would key the level by NAME and pour that state into whatever scene answers to the same name
	# after a scene change - so the walk is handed the playing scene and skips it.
	var playing: Node = seam.new()
	playing.name = "GameScene"
	playing.coins = 99
	root.add_child(playing)
	var with_scene: Dictionary = system.call("_collect_children_states", root, null)
	ok = _check("without being told, the walk would take the current scene too", with_scene.has("GameScene"), true) and ok
	var addons_only: Dictionary = system.call("_collect_children_states", root, playing)
	ok = _check("the current scene is not an addon", addons_only.has("GameScene"), false) and ok
	ok = _check("and the real autoloads are still all there", addons_only.keys(), ["CurrencyLedger", "Upgrades"]) and ok

	system.call("_apply_children_states", root, {"CurrencyLedger": {".": {"coins": 42}}})
	ok = _check("restoring puts the value back on the live autoload", ledger.coins, 42) and ok
	# The edge: a save that covers an addon this build does not have must be reported, not
	# dropped in silence, and must not disturb the addons that ARE here.
	system.call("_apply_children_states", root, {"Ghost": {".": {"coins": 1}}})
	ok = _check("an addon the save knows but the build lacks leaves the others alone", ledger.coins, 42) and ok

	# The wrappers, off the tree: they answer "nothing", they do not crash, and Save All Addons
	# still writes its reserved key so a project can see the seam took part.
	system.save_all_addons()
	ok = _check("Save All Addons writes its reserved key", system.has_save_key("__addons"), true) and ok
	ok = _check("the addon snapshot is a Dictionary", system.load_value("__addons", null) is Dictionary, true) and ok
	ok = _check("For Each Saveable Addon walks nothing off the tree", system.each_saveable_addon(), []) and ok
	ok = _check("Addon Saves Itself is false off the tree", system.addon_saves_itself("CurrencyLedger"), false) and ok
	system.load_all_addons()
	ok = _check("Load All Addons off the tree changes nothing", ledger.coins, 42) and ok

	root.free()
	_cleanup(system, [0])
	return ok


## #31 - what stays out of the file, and what the file costs.
static func _never_save_and_report() -> bool:
	var ok: bool = true
	var system: Node = _new_system("report")
	ok = _check("an empty slot costs nothing", system.save_size(), 0) and ok
	system.save_value("cached_targets", "x".repeat(400))
	system.save_value("hp", 12)
	ok = _check("the temporary key is in the file to begin with", system.has_save_key("cached_targets"), true) and ok
	var fat: int = int(system.save_size())
	ok = _check("Save Size measures the file on disk", fat > 400, true) and ok

	system.never_save_key("cached_targets")
	system.save_value("hp", 13)
	ok = _check("a never-saved key is dropped on the next write", system.has_save_key("cached_targets"), false) and ok
	ok = _check("the keys you meant to keep stay", system.load_value("hp", -1), 13) and ok
	ok = _check("dropping it shrank the file", system.save_size() < fat, true) and ok
	# The edge: it is dropped whichever row wrote it - including a full Save Game.
	system.save_value("cached_targets", "x".repeat(400))
	system.save_game()
	ok = _check("Save Game cannot sneak a never-saved key back in", system.has_save_key("cached_targets"), false) and ok

	system.save_value("bag", "y".repeat(120))
	var report: String = str(system.save_report())
	ok = _check("the report opens with the slot and its size", report.begins_with("Save slot 0 - "), true) and ok
	ok = _check("the heaviest key is named first", report.get_slice("\n", 1).strip_edges().begins_with("bag"), true) and ok
	ok = _check("the report says what is deliberately absent", report.contains("never saved: cached_targets"), true) and ok

	_cleanup(system, [0])
	return ok


## #32 - a backup ring for game saves. Not about torn files (the atomic write already handles
## those) - about a save that was written perfectly and is wrong.
static func _backup_ring() -> bool:
	var ok: bool = true
	var system: Node = _new_system("ring")
	ok = _check("backups are off until you ask for them", system.slot_backup_count(0), 0) and ok
	system.save_value("v", 1)
	ok = _check("a write with backups off keeps no ring", system.slot_backup_count(0), 0) and ok

	system.backup_count = 3
	for value: int in [2, 3, 4, 5]:
		system.save_value("v", value)
	ok = _check("the ring keeps exactly Backup Count entries", system.slot_backup_count(0), 3) and ok
	ok = _check("For Each Backup Of Slot lists them newest first", system.each_backup_of_slot(0).size(), 3) and ok
	ok = _check("the slot itself still holds the newest write", system.load_value("v", -1), 5) and ok

	system.restore_slot_from_backup(0, 1)
	ok = _check("backup 1 is the save before this one", system.load_value("v", -1), 4) and ok
	# The edge the read-before-push order exists for: restoring the OLDEST entry of a full ring,
	# where backing the current file up first prunes that very entry.
	var oldest: int = int(system.slot_backup_count(0))
	system.restore_slot_from_backup(0, oldest)
	ok = _check("the oldest entry of a full ring still restores", system.load_value("v", -1), 3) and ok
	ok = _check("a restore is never one-way: the pre-restore save is in the ring", system.slot_backup_count(0), 3) and ok
	system.restore_slot_from_backup(0, 1)
	ok = _check("so the restore itself can be undone", system.load_value("v", -1), 4) and ok

	var refused: Array = []
	system.load_failed.connect(func(index: int, reason: String) -> void: refused.append(reason))
	system.restore_slot_from_backup(0, 99)
	ok = _check("asking for a backup that is not kept says so", refused, ["slot 0 has no backup 99 to restore - it keeps 3."]) and ok
	ok = _check("a refused restore leaves the slot alone", system.load_value("v", -1), 4) and ok

	# THE edge a restore must survive: a DAMAGED ring entry. A restore replaces a working save, so
	# the backup is read back before the swap - wreckage leaves the live slot exactly where it was
	# instead of destroying it in the name of safety, and says which backup was bad.
	refused.clear()
	var ring: PackedStringArray = system.call("_backups_for", 0)
	var torn: FileAccess = FileAccess.open(ring[0], FileAccess.WRITE)
	torn.store_buffer(PackedByteArray([1, 2, 3]))
	torn.close()
	system.restore_slot_from_backup(0, 1)
	ok = _check("a damaged backup is refused, by name", refused,
		["backup 1 of slot 0 is damaged (it holds no save data) - slot 0 was left alone."]) and ok
	ok = _check("and the good save is still there", system.load_value("v", -1), 4) and ok
	ok = _check("still readable, not half-replaced", system.slot_is_readable(0), true) and ok

	# The ring is ordered by its SEQUENCE NUMBER, not by name: a plain text sort puts "10000" below
	# "9999", which would invert the ring at ten thousand writes - handing "backup 1" the OLDEST
	# file and pruning the newest.
	var dir_path: String = str(system.call("_backup_dir_for", 0))
	for name: String in ["0009.s.dat", "0010.s.dat", "9999.s.dat", "10000.s.dat"]:
		var stub: FileAccess = FileAccess.open(dir_path.path_join(name), FileAccess.WRITE)
		stub.store_string("x")
		stub.close()
	var ordered: PackedStringArray = system.call("_backups_for", 0)
	ok = _check("the ring is newest-first past nine thousand nine hundred and ninety-nine",
		ordered[0].get_file(), "10000.s.dat") and ok
	ok = _check("and the next one back is the one before it", ordered[1].get_file(), "9999.s.dat") and ok
	# A .tmp is a write in flight, or the wreck of one - never an entry the ring can hand out.
	var leftover: FileAccess = FileAccess.open(dir_path.path_join("0011.s.dat.tmp"), FileAccess.WRITE)
	leftover.store_string("x")
	leftover.close()
	ok = _check("a leftover .tmp is not part of the ring", Array(system.call("_backups_for", 0)).size(), ordered.size()) and ok
	DirAccess.remove_absolute(dir_path.path_join("0011.s.dat.tmp"))

	_cleanup(system, [0])
	return ok


## #33 - wipe the slot, carry what you chose.
static func _new_game_plus() -> bool:
	var ok: bool = true
	var system: Node = _new_system("newrun")
	system.save_value("unlocked_skins", "fox,owl")
	system.save_value("coins", 500)
	system.save_value("quest", "final")
	system.set_slot_detail("chapter", "The end")
	ok = _check("a first run reads as run 1", system.run_number(), 1) and ok

	var runs: Array = []
	system.new_run_started.connect(func(index: int, number: int) -> void: runs.append("%d:%d" % [index, number]))
	system.carry_value_into_next_run("unlocked_skins")
	system.start_new_run(0)
	ok = _check("On New Run Started fires with the slot and the new number", runs, ["0:2"]) and ok
	ok = _check("the carried key survives", str(system.load_value("unlocked_skins", "")), "fox,owl") and ok
	ok = _check("everything else is wiped", system.has_save_key("coins"), false) and ok
	ok = _check("and so is the rest of it", system.has_save_key("quest"), false) and ok
	ok = _check("Run Number counts the runs", system.run_number(), 2) and ok
	ok = _check("the slot card survives the wipe, so the menu tile still reads", str(system.slot_detail(0, "chapter", "New game")), "The end") and ok
	ok = _check("the active slot is handed back after the write", system.slot, 0) and ok

	system.start_new_run(0)
	ok = _check("each new run bumps the counter again", system.run_number(), 3) and ok
	ok = _check("a carried key stays carried across runs", str(system.load_value("unlocked_skins", "")), "fox,owl") and ok

	# The edge: a slot that cannot be read must not be wiped by a reset either.
	var damaged: Node = _new_system("newrun_damaged")
	damaged.save_value("coins", 900)
	damaged.encryption_key = "wrongkey"
	var refusals: Array = []
	damaged.save_failed.connect(func(index: int, reason: String) -> void: refusals.append(reason))
	damaged.start_new_run(0)
	ok = _check("an unreadable slot is not reset", refusals,
		["slot 0 could not be read - refusing to reset it (it may be damaged, or the encryption key is wrong)."]) and ok
	damaged.encryption_key = ""
	ok = _check("its data is untouched", damaged.load_value("coins", -1), 900) and ok

	_cleanup(system, [0])
	_cleanup(damaged, [0])
	return ok


static func _new_system(name: String, fmt: String = "config") -> Node:
	var system: Node = (load(PACK) as GDScript).new()
	system.save_directory = "user://"
	system.file_pattern = "test_slots_%s_{slot}.dat" % name
	system.format = fmt
	return system


## Removes every file the section wrote (slot, picture, backup ring) and frees the instance.
## An empty slot list frees a second instance that shares another one's files.
static func _cleanup(system: Node, slots: Array) -> void:
	for index: Variant in slots:
		var path: String = str(system.call("_slot_path", int(index)))
		for extra: String in [path, path + ".png", path + ".tmp"]:
			if FileAccess.file_exists(extra):
				DirAccess.remove_absolute(extra)
		for backup: String in system.call("_backups_for", int(index)):
			DirAccess.remove_absolute(backup)
		DirAccess.remove_absolute(str(system.call("_backup_dir_for", int(index))))
	system.free()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("save_slots_and_runs_test", label, actual, expected)
