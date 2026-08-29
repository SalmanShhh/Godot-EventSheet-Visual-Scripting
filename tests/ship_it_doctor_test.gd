# The six ways a finished game cannot leave the building, and the section of the Doctor that says so.
#
# Every claim here is pinned by the WORDS a reader meets, because a count of findings tells nobody
# which finding moved, and because these particular sentences are the whole feature: a release check
# that says "problem detected" has not helped anybody ship anything.
#
# What is pinned:
#   1. NOTHING TO BUILD FROM, against a presets file with a preset and one without.
#   2. THE CONSOLE LINE A PLAYER WOULD SEE, including the three ways a line is already guarded (the
#      one-line spelling, the block spelling, and a comment) - the passing cases matter more than the
#      failing ones, because a check that cries wolf gets switched off.
#   3. IT STILL LOOKS LIKE A NEW PROJECT, over the two settings and over a project that named itself.
#   4. A LANGUAGE THAT IS SHORT, and the ready-to-fill CSV the missing keys come back as - byte for
#      byte, because "exportable" is a promise about a FILE.
#   5. THE FRAME, against the 16.7 ms it has to fit in, and silent with nothing measured.
#   6. WHAT GETS SAVED, as the plain list it is, obeying the band scale law - three names and a count,
#      never forty names.
#   7. THE ONE-CLICK GUARD, by what it WRITES: the row's verb and the line it compiles to afterwards,
#      and the receipt shown before it touches anything.
@tool
class_name ShipItDoctorTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	ok = _test_nothing_to_build_from() and ok
	ok = _test_a_console_line_a_player_would_see() and ok
	ok = _test_it_still_looks_like_a_new_project() and ok
	ok = _test_a_language_that_is_short() and ok
	ok = _test_the_frame_it_has_to_fit_in() and ok
	ok = _test_what_gets_saved() and ok
	ok = _test_the_one_click_guard() and ok
	ok = _test_the_chip_the_reader_presses() and ok
	return ok


## No preset section, no release. A half-written file answers the same way a missing one does, which
## is the reason the file is read as text rather than through ConfigFile.
static func _test_nothing_to_build_from() -> bool:
	var ok: bool = _check("a project with a Windows preset is not accused",
		EventSheetShipItDoctor.export_preset_findings("[preset.0]\nname=\"Windows Desktop\"\n").size(), 0)
	var found: Array[Dictionary] = EventSheetShipItDoctor.export_preset_findings("")
	ok = _check("a project with no presets file has nothing to build from", _messages(found),
		PackedStringArray(["This project has no export preset, so there is nothing to build a release from. Project > Export > Add makes one for the platform you are shipping to."])) and ok
	ok = _check("and it is a warning filed under the ship check", _checks(found),
		PackedStringArray([EventSheetShipItDoctor.CHECK_EXPORT_PRESET])) and ok
	ok = _check("a file with settings but no preset answers the same way",
		EventSheetShipItDoctor.export_preset_findings("[preset]\n").size(), 1) and ok
	return ok


## A log line an exported game still runs. The three guarded spellings are the important half.
static func _test_a_console_line_a_player_would_see() -> bool:
	var source: String = "\n".join(PackedStringArray([
		"func _ready() -> void:",
		"\tprint(\"loaded\")",
		"\tif OS.is_debug_build(): print(\"traced\")",
		"\tif OS.is_debug_build():",
		"\t\tprint(\"inside the guard\")",
		"\t\tprint_rich(\"[b]also inside[/b]\")",
		"\tprint(\"back outside\")",
		"\t# print(\"commented out\")",
		"\tpush_warning(\"a real warning\")",
	]))
	var ok: bool = _check("only the two unguarded lines are console lines a player would see",
		EventSheetShipItDoctor.unguarded_console_lines(source),
		PackedStringArray(["print(\"loaded\")", "print(\"back outside\")"]))
	var found: Array[Dictionary] = EventSheetShipItDoctor.debug_row_findings({
		"res://game/hud.gd": source,
	})
	ok = _check("the finding names the first line and counts the rest", _messages(found),
		PackedStringArray(["hud.gd writes to the console where an exported release build still runs it - first: print(\"loaded\"). 1 more like it in this file. Log (Debug Builds Only) compiles the line out of a release game."])) and ok
	ok = _check("a file whose logging is all guarded is not accused",
		EventSheetShipItDoctor.debug_row_findings({
			"res://game/quiet.gd": "func _ready() -> void:\n\tif OS.is_debug_build(): print(\"fine\")\n",
		}).size(), 0) and ok
	return ok


## The window title and the taskbar icon - the first two things anybody who is not the author sees.
static func _test_it_still_looks_like_a_new_project() -> bool:
	var ok: bool = _check("a named game with its own icon is not accused",
		EventSheetShipItDoctor.identity_findings("Cavern Runner", "res://art/icon_cavern.png").size(), 0)
	var found: Array[Dictionary] = EventSheetShipItDoctor.identity_findings("", "res://icon.svg")
	ok = _check("an unnamed project wearing the engine's icon says both", _messages(found),
		PackedStringArray([
			"The game has no name of its own yet, so the window and the built file are both called after the project template. Project Settings > Application > Config > Name.",
			"The icon is still the engine's own, so the taskbar shows Godot's logo rather than the game's. Project Settings > Application > Config > Icon.",
		])) and ok
	ok = _check("and each names the setting it is about", _subjects(found),
		PackedStringArray([EventSheetShipItDoctor.NAME_SETTING, EventSheetShipItDoctor.ICON_SETTING])) and ok
	ok = _check("a named game that never changed its icon is accused of exactly one thing",
		_subjects(EventSheetShipItDoctor.identity_findings("Cavern Runner", "res://icon.png")),
		PackedStringArray([EventSheetShipItDoctor.ICON_SETTING])) and ok
	return ok


## A catalog that has no answer for a key the game asks for, and the file the missing keys come back
## as. The CSV is pinned byte for byte: "exportable" is a promise about a FILE, not about a report.
static func _test_a_language_that_is_short() -> bool:
	var sources: Dictionary = {
		"res://game/hud.gd": "func _ready() -> void:\n\t$Label.text = tr(\"HUD_SCORE\")\n\t$Lives.text = tr(\"HUD_LIVES\")\n",
		"res://game/menu.gd": "func _ready() -> void:\n\t$Play.text = tr(\"MENU_PLAY\")\n\tvar built: String = str(\"HUD_SCORE\")\n",
	}
	var ok: bool = _check("every key the game asks for, once and sorted",
		EventSheetShipItDoctor.used_translation_keys(sources),
		PackedStringArray(["HUD_LIVES", "HUD_SCORE", "MENU_PLAY"]))
	var catalogs: Dictionary = {
		"res://i18n/de.po": PackedStringArray(["HUD_LIVES", "HUD_SCORE", "MENU_PLAY"]),
		"res://i18n/fr.po": PackedStringArray(["HUD_SCORE"]),
	}
	var used: PackedStringArray = EventSheetShipItDoctor.used_translation_keys(sources)
	var found: Array[Dictionary] = EventSheetShipItDoctor.translation_findings(used, catalogs)
	ok = _check("only the short catalog is reported, and it says which keys", _messages(found),
		PackedStringArray(["fr.po is missing 2 key(s) the game asks for, so a player reading it sees the raw key: HUD_LIVES, MENU_PLAY."])) and ok
	ok = _check("a project with no catalogs at all is not accused of a short one",
		EventSheetShipItDoctor.translation_findings(used, {}).size(), 0) and ok
	ok = _check("the missing keys come back as a translation CSV, ready to fill",
		EventSheetShipItDoctor.missing_keys_csv(used, catalogs), "keys,fr\nHUD_LIVES,\nMENU_PLAY,\n") and ok
	ok = _check("and a project whose catalogs answer everything writes no file",
		EventSheetShipItDoctor.missing_keys_csv(used, {"res://i18n/de.po": used}), "") and ok
	return ok


## What the last measured run says the rows cost, against the frame they have to fit in. A quarter of
## a frame in one file is a warning; less is reported as measured and nothing is claimed.
static func _test_the_frame_it_has_to_fit_in() -> bool:
	var ok: bool = _check("with nothing measured, nothing is said",
		EventSheetShipItDoctor.frame_budget_findings([]).size(), 0)
	var costs: Array[Dictionary] = [
		{"path": "res://game/enemies.gd", "ms": 2.0, "per_frame": 3.0},
		{"path": "res://game/hud.gd", "ms": 0.1, "per_frame": 1.0},
	]
	var found: Array[Dictionary] = EventSheetShipItDoctor.frame_budget_findings(costs)
	ok = _check("the costliest file is named with its share of the frame", _messages(found),
		PackedStringArray(["enemies.gd costs 6.00 ms of a frame in the last measured run - 36% of the 16.7 ms a 60 fps frame has."])) and ok
	ok = _check("and a third of a frame in one file is a warning", _severities(found),
		PackedStringArray(["warning"])) and ok
	ok = _check("a cheap run is reported as measured, not as a problem",
		_severities(EventSheetShipItDoctor.frame_budget_findings([
			{"path": "res://game/hud.gd", "ms": 0.1, "per_frame": 2.0},
		])), PackedStringArray(["info"])) and ok
	return ok


## The page that answers "does my save keep the coins" by reading rather than by guessing - and obeys
## the band scale law while doing it.
static func _test_what_gets_saved() -> bool:
	var ok: bool = _check("with nothing saved anywhere, there is no page",
		EventSheetShipItDoctor.what_gets_saved_findings({}).size(), 0)
	var found: Array[Dictionary] = EventSheetShipItDoctor.what_gets_saved_findings({
		"res://game/save.gd": PackedStringArray(["coins", "level"]),
		"res://game/hud.gd": PackedStringArray(["level", "best_time"]),
	})
	ok = _check("the page lists what a slot holds and where it is written from", _messages(found),
		PackedStringArray(["A save slot of this game holds 3 value(s), written from 2 script(s): best_time, coins, level. Anything not on this list is back to its starting value when a slot is loaded."])) and ok
	ok = _check("it is a note, never a warning", _severities(found), PackedStringArray(["info"])) and ok
	var many: Array[Dictionary] = EventSheetShipItDoctor.what_gets_saved_findings({
		"res://game/save.gd": PackedStringArray(["a", "b", "c", "d", "e"]),
	})
	ok = _check("and a long list names three and counts the rest", _messages(many),
		PackedStringArray(["A save slot of this game holds 5 value(s), written from 1 script(s): a, b, c and 2 more. Anything not on this list is back to its starting value when a slot is loaded."])) and ok
	return ok


## The fix, by what it WRITES. A one-click fix is only worth having if the reader can see what it did.
static func _test_the_one_click_guard() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	var noisy: ACEAction = ACEAction.new()
	noisy.ace_id = EventSheetShipItDoctor.PLAIN_LOG_ACE
	noisy.params = {"message": "\"hit\"", "level": "print"}
	event.actions.append(noisy)
	sheet.events.append(event)
	var ok: bool = _check("the receipt says what the line reads as before and after",
		EventSheetShipItDoctor.guard_receipt(sheet),
		[{"before": "print(\"hit\")", "after": "if OS.is_debug_build(): print(\"hit\")"}])
	ok = _check("one row is guarded", EventSheetShipItDoctor.guard_debug_rows(sheet), 1) and ok
	ok = _check("and it now IS the debug-builds-only verb", noisy.ace_id,
		EventSheetShipItDoctor.DEBUG_LOG_ACE) and ok
	ok = _check("compiling to the guarded line", noisy.codegen_template,
		"if OS.is_debug_build(): {level}({message})") and ok
	ok = _check("with the words the author typed untouched", noisy.params,
		{"message": "\"hit\"", "level": "print"}) and ok
	ok = _check("and running it again changes nothing",
		EventSheetShipItDoctor.guard_debug_rows(sheet), 0) and ok
	return ok


## And the chip, through the dock the reader is really pressing it in. The half above proves what the
## swap writes; this proves that pressing "Only log in debug builds" reaches it - and that a finding
## about a file somebody else has open says where to go instead of quietly replacing the tab in front
## of them and then blaming them for writing the line by hand.
static func _test_the_chip_the_reader_presses() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	var noisy: ACEAction = ACEAction.new()
	noisy.ace_id = EventSheetShipItDoctor.PLAIN_LOG_ACE
	noisy.params = {"message": "\"hit\"", "level": "print"}
	event.actions.append(noisy)
	sheet.events.append(event)
	sheet.host_class = "Node"
	sheet.external_source_path = "res://noisy.gd"

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.setup(sheet)
	var elsewhere: Dictionary = EventSheetQuickFixes.apply("guard_debug_rows",
		{"check": "ship-debug-rows", "path": "res://somebody_elses.gd"}, {"dock": dock})
	var ok: bool = _check("a finding about a file that is not open says where to go",
		elsewhere, {"ok": false,
			"message": "Open somebody_elses.gd and swap its Log rows for Log (Debug Builds Only) - double-clicking the finding opens it."})
	ok = _check("and the open sheet is left exactly as it was",
		str((dock._current_sheet.events[0] as EventRow).actions[0].get("ace_id")),
		EventSheetShipItDoctor.PLAIN_LOG_ACE) and ok

	var here: Dictionary = EventSheetQuickFixes.apply("guard_debug_rows",
		{"check": "ship-debug-rows", "path": "res://noisy.gd"}, {"dock": dock})
	ok = _check("pressing it on the sheet in front of you swaps the row and shows the line",
		here, {"ok": true,
			"message": "1 row(s) guarded. print(\"hit\") → if OS.is_debug_build(): print(\"hit\") - one Ctrl+Z takes it back."}) and ok
	ok = _check("the row really is the debug-builds-only verb now",
		str((dock._current_sheet.events[0] as EventRow).actions[0].get("ace_id")),
		EventSheetShipItDoctor.DEBUG_LOG_ACE) and ok
	ok = _check("a receipt naming forty lines names one and counts the rest",
		EventSheetQuickFixes.guard_receipt_line([
			{"before": "print(\"a\")", "after": "if OS.is_debug_build(): print(\"a\")"},
			{"before": "print(\"b\")", "after": "if OS.is_debug_build(): print(\"b\")"},
			{"before": "print(\"c\")", "after": "if OS.is_debug_build(): print(\"c\")"},
		]),
		"print(\"a\") → if OS.is_debug_build(): print(\"a\"), and 2 more like it") and ok
	ok = _check("and a sheet still opening is told apart from one with nothing to guard",
		_guard_a_read_only_sheet(), {"ok": false,
			"message": "still.gd is still opening - it reads as code until its rows have been lifted. Try again once it has finished."}) and ok
	dock.free()
	return ok


## The read-only case on its own: a `.gd` opened as a preview has not been lifted yet, so its rows
## are a wall of code and a swap would find nothing to swap.
static func _guard_a_read_only_sheet() -> Dictionary:
	var preview: EventSheetResource = EventSheetResource.new()
	preview.host_class = "Node"
	preview.external_source_path = "res://still.gd"
	preview.read_only = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.setup(preview)
	var answer: Dictionary = EventSheetQuickFixes.apply("guard_debug_rows",
		{"check": "ship-debug-rows", "path": "res://still.gd"}, {"dock": dock})
	dock.free()
	return answer


static func _messages(found: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for finding: Dictionary in found:
		out.append(str(finding.get("message", "")))
	return out


static func _checks(found: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for finding: Dictionary in found:
		out.append(str(finding.get("check", "")))
	return out


static func _severities(found: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for finding: Dictionary in found:
		out.append(str(finding.get("severity", "")))
	return out


static func _subjects(found: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for finding: Dictionary in found:
		out.append(str(finding.get("subject", "")))
	return out


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ship_it_doctor_test: %s" % label)
		return true
	print("[FAIL] ship_it_doctor_test: %s" % label)
	# Printed as ARGUMENTS rather than through `%`: these readings are full of percent signs, and a
	# format string would eat them.
	print("  expected: ", expected)
	print("  actual:   ", actual)
	return false
