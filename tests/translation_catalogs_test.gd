# Godot EventSheets - one catalog per project folder, and the table that reads them in pages.
#
# A big game's text does not fit one strings.csv a translator can open, so a FOLDER target writes
# one catalog per folder of the project (dialogue/chapter_03.csv, ui.csv) - while a project that
# already has its one strings.csv keeps it, unchanged, and a key that already lives in a catalog is
# never moved out of it. The catalogs are then read by a table model that splits a row only when it
# is looked at, and shown by a view that draws only the rows on screen. Everything below is driven
# through the functions the Translation Studio's buttons call, and asserted on the FILES they write.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "translation_catalogs_test"
const TABLE_PATH := "res://addons/eventsheet/editor/translation_table.gd"
const VIEW_PATH := "res://addons/eventsheet/editor/dock/translation_table_view.gd"
const PROJECT := "user://eventforge_catalogs_project"
const FOLDER := "user://eventforge_catalogs_i18n"
const SINGLE := "user://eventforge_catalogs_single.csv"
const RETURNED := "user://eventforge_catalogs_returned.csv"
const TABLE_FILE := "user://eventforge_catalogs_table.csv"
const HAND_PROJECT := "user://eventforge_hand_made_project"
const HAND_FOLDER := "user://eventforge_hand_made_i18n"
## Godot's own catalog shape, written by hand: keys plus languages, Windows line endings, a quoted
## cell the codec would not have quoted. Any rewrite at all would change at least one byte.
const HAND_UI := "keys,en,fr\r\nBuy,Buy,Acheter\r\n\"Refund\",Refund,Rembourser\r\n"
const HAND_STRINGS := "keys,en\nPlay,Play\n"


static func run() -> bool:
	_clean()
	var all_passed: bool = _run_folders()
	all_passed = _run_hand_made() and all_passed
	all_passed = _run_table() and all_passed
	all_passed = _run_view() and all_passed
	_clean()
	return all_passed


static func _run_folders() -> bool:
	_write(PROJECT + "/main.gd", "extends Node\n\n\nfunc _ready() -> void:\n\t$Play.text = tr(\"Play\")\n")
	_write(PROJECT + "/ui/shop.gd", "extends Node\n\n\nfunc _ready() -> void:\n\t$Buy.text = tr(\"Buy\")\n")
	_write(PROJECT + "/dialogue/chapter_03/inn.gd",
		"extends Node\n\n\nfunc _ready() -> void:\n\t# The innkeeper, a little tired.\n\t$Line.text = tr(\"Welcome, traveller.\")\n")
	# The project grew out of the strings.csv the studio wrote, and Buy was finished in it before the split.
	_write(FOLDER + "/strings.csv", "keys,en,fr,notes\nBuy,Buy,Acheter,shop.gd:5\n")
	var scan: Script = EventSheetTranslationScan
	var outcome: Dictionary = scan.extract(PROJECT, FOLDER)
	var single: Dictionary = scan.extract(PROJECT, SINGLE)
	var shop_said_in: String = FileAccess.get_file_as_string(FOLDER + "/strings.csv")
	var all_passed: bool = SUPPORT.pins(NAME, [
		["a folder target writes one catalog per project folder", scan.catalog_files(FOLDER),
			PackedStringArray([FOLDER + "/dialogue/chapter_03.csv", FOLDER + "/strings.csv"])],
		["the dialogue key lands in its folder's catalog, with where it is said",
			FileAccess.get_file_as_string(FOLDER + "/dialogue/chapter_03.csv"),
			"keys,en,notes\n\"Welcome, traveller.\",\"Welcome, traveller.\",\"inn.gd:6 - The innkeeper, a little tired.\"\n"],
		["a key strings.csv already held stays there, finished cell and all - ui.csv is never made for it",
			shop_said_in, "keys,en,fr,notes\nPlay,Play,,main.gd:5\nBuy,Buy,Acheter,shop.gd:5\n"],
		["the outcome counts every catalog it wrote", str(outcome.get("message", "")),
			"3 key(s) in 2 catalog(s) under %s - 2 new, 1 already translated and kept." % FOLDER],
		["a .csv target is still the one file it always was", scan.catalog_files(SINGLE), PackedStringArray([SINGLE])],
		["holding every key", int(single.get("keys", 0)), 3],
		["where a project with no strings.csv starts", scan.default_catalog_target(), "res://i18n"],
		["the top of the project is strings.csv", scan.folder_catalog("res://main.gd", "res://", "res://i18n"), "res://i18n/strings.csv"],
		["a nested folder is its path", scan.folder_catalog("res://dialogue/chapter_03/inn.gd", "res://", "res://i18n/"),
			"res://i18n/dialogue/chapter_03.csv"],
	])
	# Coverage sums the folder; a file without the fr column counts its lines as missing in fr.
	var french: Dictionary = {}
	for entry: Variant in scan.coverage(FOLDER):
		if str((entry as Dictionary).get("locale", "")) == "fr":
			french = entry
	# A returned file lands each line in whichever catalog holds it; a file nothing landed in is
	# left byte for byte as it was.
	_write(RETURNED, "keys,fr\n\"Welcome, traveller.\",\"Bienvenue, voyageur.\"\nNobody says this,Personne\n")
	var before_strings: String = FileAccess.get_file_as_string(FOLDER + "/strings.csv")
	var imported: Dictionary = scan.import_catalog(RETURNED, FOLDER)
	var after_strings: String = FileAccess.get_file_as_string(FOLDER + "/strings.csv")
	var after_dialogue: String = FileAccess.get_file_as_string(FOLDER + "/dialogue/chapter_03.csv")
	# Godot's importer puts each language's .translation beside its CSV; registering walks down.
	_write(FOLDER + "/dialogue/chapter_03.fr.translation", "x")
	_write(FOLDER + "/strings.fr.translation", "x")
	var registered_before: PackedStringArray = EventSheetGameCatalog.registered_translations()
	var registered: Dictionary = EventSheetGameCatalog.register_catalogs(FOLDER, false)
	ProjectSettings.set_setting(EventSheetGameCatalog.TRANSLATIONS_SETTING, registered_before)
	var pseudo: Dictionary = EventSheetGameCatalog.write_pseudo_column(FOLDER)
	all_passed = SUPPORT.pins(NAME, [
		["coverage over the folder counts every line", [int(french.get("total", 0)), int(french.get("covered", 0))], [3, 1]],
		["the returned line lands in the dialogue catalog", after_dialogue,
			"keys,en,notes,fr\n\"Welcome, traveller.\",\"Welcome, traveller.\",\"inn.gd:6 - The innkeeper, a little tired.\",\"Bienvenue, voyageur.\"\n"],
		["a key no catalog holds is reported", imported.get("unknown", PackedStringArray()), PackedStringArray(["Nobody says this"])],
		["and the catalog nothing landed in is untouched", after_strings, before_strings],
		["registering finds the .translation files in every folder", registered.get("added", PackedStringArray()),
			PackedStringArray([FOLDER + "/dialogue/chapter_03.fr.translation", FOLDER + "/strings.fr.translation"])],
		["the pseudo column is written into every catalog of the folder", int(pseudo.get("rows", 0)), 3],
		["a batch of pseudo text is the one-at-a-time text", EventSheetGameCatalog.pseudolocalize_all(PackedStringArray(["Play", ""])),
			PackedStringArray([EventSheetGameCatalog.pseudolocalize("Play"), ""])],
	]) and all_passed
	return all_passed


# A hand-made catalog under the folder is read but never written: a new key its folder says goes to
# a studio catalog beside it, and every step names the hand-made ones it left alone.
static func _run_hand_made() -> bool:
	_write(HAND_PROJECT + "/main.gd", "extends Node\n\n\nfunc _ready() -> void:\n\t$Play.text = tr(\"Play\")\n\t$Quit.text = tr(\"Quit\")\n")
	_write(HAND_PROJECT + "/ui/shop.gd", "extends Node\n\n\nfunc _ready() -> void:\n\t$Buy.text = tr(\"Buy\")\n\t$Sell.text = tr(\"Sell\")\n")
	_write(HAND_FOLDER + "/ui.csv", HAND_UI)
	_write(HAND_FOLDER + "/strings.csv", HAND_STRINGS)
	var scan: Script = EventSheetTranslationScan
	var editor: EventSheetEditor = EventSheetEditor.new()
	var studio: EventSheetTranslationStudio = editor._translation_studio
	studio._build_window()
	studio.scan_folder = HAND_PROJECT
	studio.catalog_target = HAND_FOLDER
	# Notes off: folder mode still writes the notes column, the mark the studio knows its own by.
	var outcome: Dictionary = scan.extract(HAND_PROJECT, HAND_FOLDER, false)
	var again: Dictionary = studio.run_extract()
	var card: PackedStringArray = PackedStringArray()
	for row: Node in (studio._results["find"] as EventSheetPopupUI.ResultCard).lines_box.get_children():
		card.append((row.get_child(1) as Label).text)
	var all_passed: bool = SUPPORT.pins(NAME, [
		["the hand-made catalogs are byte for byte as written", [FileAccess.get_file_as_string(HAND_FOLDER + "/ui.csv"),
			FileAccess.get_file_as_string(HAND_FOLDER + "/strings.csv")], [HAND_UI, HAND_STRINGS]],
		["a new key their folders say goes to a studio catalog beside each", scan.catalog_files(HAND_FOLDER), PackedStringArray([
			HAND_FOLDER + "/strings.csv", HAND_FOLDER + "/strings.extracted.csv", HAND_FOLDER + "/ui.csv", HAND_FOLDER + "/ui.extracted.csv"])],
		["holding only the keys no catalog had, with the notes column", [FileAccess.get_file_as_string(HAND_FOLDER + "/ui.extracted.csv"),
			FileAccess.get_file_as_string(HAND_FOLDER + "/strings.extracted.csv")],
			["keys,en,notes\nSell,Sell,shop.gd:6\n", "keys,en,notes\nQuit,Quit,main.gd:6\n"]],
		["the outcome names every hand-made catalog it left alone", outcome.get("left_alone", PackedStringArray()),
			PackedStringArray([HAND_FOLDER + "/strings.csv", HAND_FOLDER + "/ui.csv"])],
		["and says so", str(outcome.get("message", "")),
			"2 key(s) in 2 catalog(s) under %s - 2 new, 0 already translated and kept. 2 hand-made catalog(s) left as they were: %s/strings.csv, %s/ui.csv."
			% [HAND_FOLDER, HAND_FOLDER, HAND_FOLDER]],
		["a second Find text finds its own catalogs again and adds nothing", [int(again.get("added", -1)), int(again.get("keys", 0))], [0, 2]],
		["the result card names every hand-made catalog", card[card.size() - 1],
			"2 catalogs here were made by hand, so nothing was written to them: strings.csv, ui.csv."],
		["the studio's own catalog is recognised, a Godot one is not",
			[scan.is_studio_catalog(HAND_FOLDER + "/ui.extracted.csv"), scan.is_studio_catalog(HAND_FOLDER + "/ui.csv")], [true, false]],
		["a hand-made strings.csv does not make the project a one-file target", scan.default_catalog_target(HAND_FOLDER), HAND_FOLDER],
		["a studio-made one does", scan.default_catalog_target(FOLDER), FOLDER + "/strings.csv"],
	])
	# Bringing a file back, adding a language and the fake column write only the studio's catalogs.
	_write(RETURNED, "keys,fr\nSell,Vendre\nBuy,Acheter encore\n")
	var imported: Dictionary = scan.import_catalog(RETURNED, HAND_FOLDER)
	var added: Dictionary = scan.add_locale(HAND_FOLDER, "de")
	var pseudo: Dictionary = EventSheetGameCatalog.write_pseudo_column(HAND_FOLDER)
	var view: VBoxContainer = load(VIEW_PATH).new()
	view.show_catalogs(scan.catalog_files(HAND_FOLDER), HAND_FOLDER)
	all_passed = SUPPORT.pins(NAME, [
		["after all three the hand-made catalogs are still byte for byte as written",
			[FileAccess.get_file_as_string(HAND_FOLDER + "/ui.csv"), FileAccess.get_file_as_string(HAND_FOLDER + "/strings.csv")], [HAND_UI, HAND_STRINGS]],
		["the returned line lands in the studio catalog", FileAccess.get_file_as_string(HAND_FOLDER + "/ui.extracted.csv"),
			"keys,en,notes,fr,de,qps\nSell,Sell,shop.gd:6,Vendre,,%s\n" % EventSheetGameCatalog.pseudolocalize("Sell")],
		["a line a hand-made catalog holds is not reported as in no script", imported.get("unknown", PackedStringArray()), PackedStringArray()],
		["each step names the catalogs it left alone", [imported.get("left_alone"), added.get("left_alone"), pseudo.get("left_alone")],
			[outcome.get("left_alone"), outcome.get("left_alone"), outcome.get("left_alone")]],
		["the picker says a studio catalog beside a hand-made one holds that folder's text", view._picker.get_item_tooltip(3),
			"The text the files in res://ui/ say."],
	]) and all_passed
	view.free()
	editor.free()
	return all_passed


static func _run_table() -> bool:
	# CRLF, a quoted cell holding the separator, a blank line, a pseudo column and a short row.
	_write(TABLE_FILE, "keys,en,fr,qps,notes\r\nPlay,Play,Jouer,[Pláý],main.gd:5\r\n\r\n\"Yes, please\",\"Yes, please\",,,\r\nQuit,Quit\r\n")
	var table: RefCounted = load(TABLE_PATH).new()
	var opened: Dictionary = table.open(TABLE_FILE)
	var all_passed: bool = SUPPORT.pins(NAME, [
		["the table reads every line, blank ones skipped", int(opened.get("rows", 0)), 3],
		["a pseudo column is never offered as a language", table.languages, PackedStringArray(["en", "fr"])],
		["a quoted separator stays inside its cell", table.key(1), "Yes, please"],
		["a short row pads its missing cells", table.cells(2), PackedStringArray(["Quit", "Quit", "", "", ""])],
		["search ignores case and names rows, not hits", table.rows_containing("PLEASE"), PackedInt32Array([1])],
		["missing only names the lines a language still needs", table.missing_rows(), PackedInt32Array([1, 2])],
		["no search and no filter is every row, never a list of them", table.shown("", "all").get("every", false), true],
		["search and missing only together", table.shown("qu", "missing").get("rows", PackedInt32Array()), PackedInt32Array([2])],
	])
	var saved: Dictionary = table.set_cell(1, "fr", "Oui, s'il vous plaît")
	all_passed = SUPPORT.pins(NAME, [
		["a cell edit says what it saved", str(saved.get("message", "")),
			"Saved the fr line for \"Yes, please\" in %s." % TABLE_FILE.get_file()],
		["only that line changes, quoted where it must be, Windows endings kept", FileAccess.get_file_as_string(TABLE_FILE),
			"keys,en,fr,qps,notes\r\nPlay,Play,Jouer,[Pláý],main.gd:5\r\n\r\n\"Yes, please\",\"Yes, please\",\"Oui, s'il vous plaît\",,\r\nQuit,Quit\r\n"],
		["the next line is still found after the edit moved it", table.key(2), "Quit"],
		["and the missing list is worked out again", table.missing_rows(), PackedInt32Array([2])],
		["a column the catalog does not have is refused", bool(table.set_cell(0, "de", "Spielen").get("ok", true)), false],
	]) and all_passed
	return all_passed


static func _run_view() -> bool:
	var view: VBoxContainer = load(VIEW_PATH).new()
	var opened: Array = []
	view.line_opened.connect(func(row: int) -> void: opened.append(row))
	view.show_catalogs(EventSheetTranslationScan.catalog_files(FOLDER), FOLDER, FOLDER + "/strings.csv")
	var first_status: String = view.status_text()
	view.set_filter("missing")
	var missing_status: String = view.status_text()
	view.set_search("play")
	var search_status: String = view.status_text()
	view.set_search("")
	view.set_filter("all")
	view.step_line(1)
	view.step_line(-1)
	view.step_line(-1)
	var all_passed: bool = SUPPORT.pins(NAME, [
		["the picker names each catalog by its place in the folder", [view._picker.get_item_text(0), view._picker.get_item_text(1)],
			["dialogue/chapter_03.csv", "strings.csv"]],
		["and describes what it holds", view._picker.get_item_tooltip(0), "The text the files in res://dialogue/chapter_03/ say."],
		["the chosen catalog is the one on show", view.table.path, FOLDER + "/strings.csv"],
		["the status line says which lines are on screen", first_status, "Lines 1 to 1 of 2 · in strings.csv"],
		["missing only counts each language's gaps by its name", missing_status, "Missing only: 1 French lines · in strings.csv"],
		["search counts the lines that hold the text", search_status, "1 of 2 lines hold \"play\" · in strings.csv"],
		["next and previous open the line they land on, wrapping at the ends", opened, [0, 1, 0]],
	])
	view.show_catalogs(PackedStringArray(), PROJECT + "/no_catalog_yet")
	all_passed = SUPPORT.check(NAME, "a project with no catalog yet names no file", view.status_text(),
		"No lines yet - Find text fills it.") and all_passed
	view.free()
	return all_passed


static func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _clean() -> void:
	for root: String in [PROJECT, FOLDER, HAND_PROJECT, HAND_FOLDER]:
		for path: String in EventSheetTranslationScan.files_under(root, ["gd", "csv", "translation"]):
			DirAccess.remove_absolute(path)
	for path: String in [SINGLE, RETURNED, TABLE_FILE]:
		DirAccess.remove_absolute(path)
