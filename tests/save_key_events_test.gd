# Godot EventSheets - the Save System's per-key half: outcomes, removal, the write window, and
# the counted reads.
#
# The shape under test is the KIND decision, not just the code. Something that HAPPENS is a
# trigger backed by a real signal, and the key it is about travels as the signal's own argument -
# so one signal serves every key, the row reads `key`, and nothing has to remember to check a
# "last saved key" variable afterwards. Something you CHECK is a condition (Is Saving, Is Loading,
# Save Key Is) and a value is an expression (Save Key Count, Save Key At).
#
# Every verb is pinned twice, the way the rest of the save suite is: the EMITTED GDScript (a pack
# ships plain code, so the shape a project receives is part of the contract) and the RUNTIME
# behaviour, including the edge case each blurb promises:
#   - On Key Saved does NOT fire for a key Never Save This Key held back, because that key never
#     reached the file - the one lie the trigger exists to prevent;
#   - Remove Save Key with nothing to remove raises On Save Key Missing rather than succeeding;
#   - Clear Slot Keys keeps the slot card, the version stamp and the run counter, and reports one
#     On Key Removed per key it actually emptied;
#   - Is Saving survives a NESTED write started by an On Before Save handler (the reason the
#     window is counted rather than flagged);
#   - Save Key At refuses an out-of-range position with "" instead of faulting.
@tool
class_name SaveKeyEventsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/save_system/save_system_addon.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _emitted_code_pins() and ok
	ok = _key_saved_trigger() and ok
	ok = _removal_and_missing() and ok
	ok = _clear_slot_keys() and ok
	ok = _check_save_key() and ok
	ok = _busy_windows() and ok
	ok = _key_reads() and ok
	return ok


## The emitted pack IS the deliverable. These pin the exact shape a project gets: the four
## signals with the key as their first argument, the verbs' signatures, and the three guards
## that make the new behaviour honest (the never-saved key, the per-key clear report, and the
## counted write window).
static func _emitted_code_pins() -> bool:
	var ok: bool = true
	var text: String = FileAccess.get_file_as_string(PACK)
	ok = _check("the pack file is on disk", text.is_empty(), false) and ok
	for pin: String in _pins():
		ok = _check("emits: %s" % pin.get_slice("\n", 0), text.contains(pin), true) and ok
	# The prose above a signal is its description to the analyzer, which is what the picker shows
	# under the trigger's name. A lift that left the paragraph behind would ship four headline
	# triggers with nothing under them, and the emission pins above could not see it.
	var described: Dictionary = (EventSheetSemanticAnalyzer.new().parse_source_metadata(load(PACK)).get("signals", {}) as Dictionary)
	for signal_name: String in ["key_saved", "key_loaded", "key_removed", "save_key_missing"]:
		var entry: Dictionary = described.get(signal_name, {})
		ok = _check("the picker describes %s" % signal_name, str(entry.get("description", "")).begins_with("Fires "), true) and ok
	return ok


static func _pins() -> PackedStringArray:
	return PackedStringArray([
		# Four plain signals, each carrying the key it is about as captured context.
		"signal key_saved(key: String, slot_index: int)",
		"signal key_loaded(key: String, slot_index: int)",
		"signal key_removed(key: String, slot_index: int)",
		"signal save_key_missing(key: String, slot_index: int)",
		"## @ace_trigger\n## @ace_name(\"On Key Saved\")",
		"## @ace_trigger\n## @ace_name(\"On Key Loaded\")",
		"## @ace_trigger\n## @ace_name(\"On Key Removed\")",
		"## @ace_trigger\n## @ace_name(\"On Save Key Missing\")",
		# The save seam: one write, both outcomes, and the never-saved key that must not claim it
		# landed.
		"\tif not _never_save.has(key):\n\t\tkey_saved.emit(key, slot)",
		# Removal, and the missing half of it.
		"func remove_save_key(key: String) -> void:",
		"\tif not data.has(key):\n\t\tsave_key_missing.emit(key, slot)\n\t\treturn",
		"\tif _write_all(data):\n\t\tkey_removed.emit(key, slot)",
		"## @ace_display_template(\"forget [b]{key}[/b] from this slot\")",
		# Clearing keeps the pack's reserved keys and reports one outcome per emptied key.
		"func clear_slot_keys() -> void:",
		"\t\tif str(stored) == CARD_KEY or str(stored) == VERSION_KEY or str(stored) == RUN_KEY:",
		"\tfor gone: String in removed:\n\t\tkey_removed.emit(gone, slot)",
		# The question a row asks, answered as a row.
		"func check_save_key(key: String) -> void:",
		"\tif data.has(key):\n\t\tkey_loaded.emit(key, slot)\n\telse:\n\t\tsave_key_missing.emit(key, slot)",
		# The write and load windows, counted rather than flagged, and the doors that open them.
		"var _write_depth: int = 0",
		"var _load_depth: int = 0",
		"func is_saving() -> bool:\n\treturn _write_depth > 0",
		"func is_loading() -> bool:\n\treturn _load_depth > 0",
		"func _write_all(data: Dictionary, stamp_current_version: bool = false) -> bool:",
		"\tvar written: bool = _write_file(data, stamp_current_version)",
		"func save_game() -> void:\n\t_write_depth += 1\n\t_run_save_game()\n\t_write_depth -= 1",
		"func load_game() -> void:\n\t_load_depth += 1\n\t_run_load_game()\n\t_load_depth -= 1",
		# The comparison and the two counted reads.
		"func save_key_is(key: String, value: Variant) -> bool:\n\treturn _read_all().get(key, null) == value",
		"func save_key_count() -> int:\n\treturn _read_all().size()",
		"func save_key_at(index: int) -> String:",
		"\treturn str(keys[index]) if index >= 0 and index < keys.size() else \"\""
	])


## On Key Saved fires once per landed write, carrying the key and the slot - and stays silent for
## a key Never Save This Key dropped on the way to the file.
static func _key_saved_trigger() -> bool:
	var ok: bool = true
	var system: Node = _new_system("saved")
	var seen: PackedStringArray = PackedStringArray()
	system.key_saved.connect(func(key: String, slot_index: int) -> void: seen.append("%s@%d" % [key, slot_index]))

	system.save_value("coins", 42)
	ok = _check("On Key Saved carries the key and the slot", ", ".join(seen), "coins@3") and ok
	system.save_text("hero", "Ilsa")
	ok = _check("the typed conveniences raise it too", ", ".join(seen), "coins@3, hero@3") and ok

	# The edge case the blurb promises: a key held back never reached the file, so claiming it
	# saved would be exactly the lie this trigger exists to prevent.
	system.never_save_key("temp")
	system.save_value("temp", 1)
	ok = _check("a Never Save This Key key raises nothing", ", ".join(seen), "coins@3, hero@3") and ok
	ok = _check("and it really is not in the file", system.has_save_key("temp"), false) and ok

	_cleanup(system)
	return ok


## Remove Save Key takes exactly one key out, and says which of the two things happened.
static func _removal_and_missing() -> bool:
	var ok: bool = true
	var system: Node = _new_system("remove")
	var removed: PackedStringArray = PackedStringArray()
	var missing: PackedStringArray = PackedStringArray()
	system.key_removed.connect(func(key: String, slot_index: int) -> void: removed.append("%s@%d" % [key, slot_index]))
	system.save_key_missing.connect(func(key: String, slot_index: int) -> void: missing.append("%s@%d" % [key, slot_index]))

	system.save_value("tutorial_seen", true)
	system.save_value("coins", 7)
	system.remove_save_key("tutorial_seen")
	ok = _check("On Key Removed names the key that left", ", ".join(removed), "tutorial_seen@3") and ok
	ok = _check("the key is gone", system.has_save_key("tutorial_seen"), false) and ok
	ok = _check("and its neighbour is untouched", system.load_value("coins", -1), 7) and ok

	# Removing what was never there is not a failure and not a success - it is the missing row.
	system.remove_save_key("tutorial_seen")
	ok = _check("removing an absent key raises On Save Key Missing", ", ".join(missing), "tutorial_seen@3") and ok
	ok = _check("and raises no second removal", ", ".join(removed), "tutorial_seen@3") and ok

	_cleanup(system)
	return ok


## Clear Slot Keys empties what the GAME wrote, keeps what the PACK wrote, and reports one
## outcome per key rather than a single slot-wide event a handler has to decode.
static func _clear_slot_keys() -> bool:
	var ok: bool = true
	var system: Node = _new_system("clear")
	var removed: PackedStringArray = PackedStringArray()
	system.key_removed.connect(func(key: String, _slot_index: int) -> void: removed.append(key))

	system.save_value("coins", 7)
	system.save_value("level", "cavern")
	system.set_slot_detail("chapter", "Ilsa in the deep")
	system.clear_slot_keys()

	var reported: Array = Array(removed)
	reported.sort()
	ok = _check("one On Key Removed per emptied key", ", ".join(PackedStringArray(reported)), "coins, level") and ok
	ok = _check("the game's keys are gone", system.has_save_key("coins"), false) and ok
	ok = _check("the file itself stays", system.slot_exists(3), true) and ok
	ok = _check("and so does the slot card a load menu reads", str(system.slot_detail(3, "chapter", "none")), "Ilsa in the deep") and ok

	# Nothing to empty is not a write, and not a report.
	removed.clear()
	system.clear_slot_keys()
	ok = _check("clearing an already-empty slot reports nothing", ", ".join(removed), "") and ok

	_cleanup(system)
	return ok


## Check Save Key is the ACTION that asks; the answer comes back as one of two rows, so a silent
## default becomes a first-run seed.
static func _check_save_key() -> bool:
	var ok: bool = true
	var system: Node = _new_system("ask")
	var answers: PackedStringArray = PackedStringArray()
	system.key_loaded.connect(func(key: String, slot_index: int) -> void: answers.append("found %s@%d" % [key, slot_index]))
	system.save_key_missing.connect(func(key: String, slot_index: int) -> void: answers.append("missing %s@%d" % [key, slot_index]))

	system.save_value("high_score", 1200)
	system.check_save_key("high_score")
	ok = _check("a stored key answers On Key Loaded", ", ".join(answers), "found high_score@3") and ok
	system.check_save_key("best_time")
	ok = _check("an absent key answers On Save Key Missing", ", ".join(answers), "found high_score@3, missing best_time@3") and ok

	# The seed, which is the whole point: the handler writes the default once and the next ask
	# finds it.
	system.save_number("best_time", 0.0)
	system.check_save_key("best_time")
	ok = _check("and the seeded key answers found from then on", ", ".join(answers),
		"found high_score@3, missing best_time@3, found best_time@3") and ok

	_cleanup(system)
	return ok


## Is Saving / Is Loading are honest about what this pack is: the write is synchronous, so they
## are true inside the window and nowhere else. The window is COUNTED, so a nested write started
## by an On Before Save handler cannot close the outer one behind its back.
static func _busy_windows() -> bool:
	var ok: bool = true
	var system: Node = _new_system("busy")
	ok = _check("nothing is in flight at rest", system.is_saving(), false) and ok
	ok = _check("and nothing is loading either", system.is_loading(), false) and ok

	var during_save: Array = ["(the handler never ran)", "(the handler never ran)"]
	system.before_save.connect(func(_slot_index: int) -> void:
		during_save[0] = "saving=%s loading=%s" % [system.is_saving(), system.is_loading()]
		# A sheet contributing its own state during the broadcast opens a SECOND window inside
		# the first. A plain bool would close the outer one when this inner write finished.
		system.save_value("contributed", 1)
		during_save[1] = "saving=%s" % system.is_saving())
	system.save_game()
	ok = _check("Is Saving is true inside On Before Save", str(during_save[0]), "saving=true loading=false") and ok
	ok = _check("and a nested write does not close the outer window", str(during_save[1]), "saving=true") and ok
	ok = _check("the window closes when Save Game returns", system.is_saving(), false) and ok
	ok = _check("the contributed key really was written", system.load_value("contributed", -1), 1) and ok

	var during_load: Array = ["(the handler never ran)"]
	system.after_load.connect(func(_slot_index: int) -> void:
		during_load[0] = "loading=%s saving=%s" % [system.is_loading(), system.is_saving()])
	system.load_game()
	ok = _check("Is Loading is true inside On After Load", str(during_load[0]), "loading=true saving=false") and ok
	ok = _check("and the load window closes too", system.is_loading(), false) and ok

	_cleanup(system)
	return ok


## The counted and indexed reads a loop cannot give you, and the comparison that needs no
## variable in between.
static func _key_reads() -> bool:
	var ok: bool = true
	var system: Node = _new_system("reads")
	system.save_value("alpha", 1)
	system.save_text("beta", "two")

	ok = _check("Save Key Count counts what the slot holds", system.save_key_count(), 2) and ok
	ok = _check("Save Key At agrees with List Save Keys", str(system.save_key_at(0)), str(system.save_keys()[0])) and ok
	var indexed: Array = [str(system.save_key_at(0)), str(system.save_key_at(1))]
	indexed.sort()
	ok = _check("and the positions cover every key", ", ".join(PackedStringArray(indexed)), "alpha, beta") and ok
	# The edge case: a position past the end (or before the start) is an empty string, never a
	# fault - a paged list asks for row 20 of a 12-key slot as a matter of course.
	ok = _check("a position past the end reads empty", str(system.save_key_at(2)), "") and ok
	ok = _check("and so does a negative one", str(system.save_key_at(-1)), "") and ok

	ok = _check("Save Key Is compares the stored value", system.save_key_is("beta", "two"), true) and ok
	ok = _check("a different value does not match", system.save_key_is("beta", "three"), false) and ok
	ok = _check("a number keeps its type through the file", system.save_key_is("alpha", 1), true) and ok
	ok = _check("and a key the slot never held matches nothing", system.save_key_is("ghost", "two"), false) and ok

	_cleanup(system)
	return ok


## A pack instance on its own file pattern and its own slot, so these sections never touch a real
## save or another test's files.
static func _new_system(tag: String) -> Node:
	var system: Node = (load(PACK) as GDScript).new()
	system.save_directory = "user://"
	system.file_pattern = "test_keys_%s_{slot}.dat" % tag
	system.slot = 3
	return system


static func _cleanup(system: Node) -> void:
	var path: String = str(system.call("_slot_path", 3))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	system.free()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("save_key_events_test", label, actual, expected)
