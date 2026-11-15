# Godot EventSheets - one catalog per project folder, and the table that reads them in pages.
#
# A big game's text does not fit one strings.csv a translator can open, so a own_folder target writes
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
static var own_project: String = SUPPORT.own_path("eventforge_catalogs_project")
static var own_folder: String = SUPPORT.own_path("eventforge_catalogs_i18n")
static var own_single: String = SUPPORT.own_path("eventforge_catalogs_single.csv")
static var own_returned: String = SUPPORT.own_path("eventforge_catalogs_returned.csv")
static var table_file: String = SUPPORT.own_path("eventforge_catalogs_table.csv")
static var hand_project: String = SUPPORT.own_path("eventforge_hand_made_project")
static var hand_folder: String = SUPPORT.own_path("eventforge_hand_made_i18n")
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
	all_passed = _run_no_em_dash() and all_passed
	_clean()
	return all_passed


## The no-em-dash house rule covers translation catalogs too: every shipped .csv (the nine language
## files, the word tables and the packs' own catalogs) uses a plain " - " or the language's own plain
## punctuation.
static func _run_no_em_dash() -> bool:
	var em_dash: String = String.chr(0x2014)
	var dashed: PackedStringArray = PackedStringArray()
	for root: String in ["res://addons/eventsheet", "res://eventsheet_addons"]:
		for path: String in _csv_files(root):
			if FileAccess.get_file_as_string(path).contains(em_dash):
				dashed.append(path)
	return SUPPORT.pins(NAME, [["no shipped translation catalog holds an em-dash", ", ".join(dashed), ""]])


static func _csv_files(folder: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".csv"):
			found.append(folder.path_join(file))
	for sub: String in DirAccess.get_directories_at(folder):
		found.append_array(_csv_files(folder.path_join(sub)))
	return found


static func _run_folders() -> bool:
	_write(own_project + "/main.gd", "extends Node\n\n\nfunc _ready() -> void:\n\t$Play.text = tr(\"Play\")\n")
	_write(own_project + "/ui/shop.gd", "extends Node\n\n\nfunc _ready() -> void:\n\t$Buy.text = tr(\"Buy\")\n")
	_write(own_project + "/dialogue/chapter_03/inn.gd",
		"extends Node\n\n\nfunc _ready() -> void:\n\t# The innkeeper, a little tired.\n\t$Line.text = tr(\"Welcome, traveller.\")\n")
	# The project grew out of the strings.csv the studio wrote, and Buy was finished in it before the split.
	_write(own_folder + "/strings.csv", "keys,en,fr,notes\nBuy,Buy,Acheter,shop.gd:5\n")
	var scan: Script = EventSheetTranslationScan
	var outcome: Dictionary = scan.extract(own_project, own_folder)
	var single: Dictionary = scan.extract(own_project, own_single)
	var shop_said_in: String = FileAccess.get_file_as_string(own_folder + "/strings.csv")
	var all_passed: bool = SUPPORT.pins(NAME, [
		["a folder target writes one catalog per project folder", scan.catalog_files(own_folder),
			PackedStringArray([own_folder + "/dialogue/chapter_03.csv", own_folder + "/strings.csv"])],
		["the dialogue key lands in its folder's catalog, with where it is said",
			FileAccess.get_file_as_string(own_folder + "/dialogue/chapter_03.csv"),
			"keys,en,notes\n\"Welcome, traveller.\",\"Welcome, traveller.\",\"inn.gd:6 - The innkeeper, a little tired.\"\n"],
		["a key strings.csv already held stays there, finished cell and all - ui.csv is never made for it",
			shop_said_in, "keys,en,fr,notes\nPlay,Play,,main.gd:5\nBuy,Buy,Acheter,shop.gd:5\n"],
		["the outcome counts every catalog it wrote", str(outcome.get("message", "")),
			"3 key(s) in 2 catalog(s) under %s - 2 new, 1 already translated and kept." % own_folder],
		["a .csv target is still the one file it always was", scan.catalog_files(own_single), PackedStringArray([own_single])],
		["holding every key", int(single.get("keys", 0)), 3],
		["where a project with no strings.csv starts", scan.default_catalog_target(), "res://i18n"],
		["the top of the project is strings.csv", scan.folder_catalog("res://main.gd", "res://", "res://i18n"), "res://i18n/strings.csv"],
		["a nested folder is its path", scan.folder_catalog("res://dialogue/chapter_03/inn.gd", "res://", "res://i18n/"),
			"res://i18n/dialogue/chapter_03.csv"],
	])
	# Coverage sums the folder; a file without the fr column counts its lines as missing in fr.
	var french: Dictionary = {}
	for entry: Variant in scan.coverage(own_folder):
		if str((entry as Dictionary).get("locale", "")) == "fr":
			french = entry
	# A returned file lands each line in whichever catalog holds it; a file nothing landed in is
	# left byte for byte as it was.
	_write(own_returned, "keys,fr\n\"Welcome, traveller.\",\"Bienvenue, voyageur.\"\nNobody says this,Personne\n")
	var before_strings: String = FileAccess.get_file_as_string(own_folder + "/strings.csv")
	var imported: Dictionary = scan.import_catalog(own_returned, own_folder)
	var after_strings: String = FileAccess.get_file_as_string(own_folder + "/strings.csv")
	var after_dialogue: String = FileAccess.get_file_as_string(own_folder + "/dialogue/chapter_03.csv")
	var pseudo: Dictionary = EventSheetGameCatalog.write_pseudo_column(own_folder)
	all_passed = SUPPORT.pins(NAME, [
		["coverage over the folder counts every line", [int(french.get("total", 0)), int(french.get("covered", 0))], [3, 1]],
		["the returned line lands in the dialogue catalog", after_dialogue,
			"keys,en,notes,fr\n\"Welcome, traveller.\",\"Welcome, traveller.\",\"inn.gd:6 - The innkeeper, a little tired.\",\"Bienvenue, voyageur.\"\n"],
		["a key no catalog holds is reported", imported.get("unknown", PackedStringArray()), PackedStringArray(["Nobody says this"])],
		["and the catalog nothing landed in is untouched", after_strings, before_strings],
		["the pseudo column is written into every catalog of the folder", int(pseudo.get("rows", 0)), 3],
		["a batch of pseudo text is the one-at-a-time text", EventSheetGameCatalog.pseudolocalize_all(PackedStringArray(["Play", ""])),
			PackedStringArray([EventSheetGameCatalog.pseudolocalize("Play"), ""])],
	]) and all_passed
	return all_passed


# A hand-made catalog under the folder is read but never written: a new key its folder says goes to
# a studio catalog beside it, and every step names the hand-made ones it left alone.
static func _run_hand_made() -> bool:
	_write(hand_project + "/main.gd", "extends Node\n\n\nfunc _ready() -> void:\n\t$Play.text = tr(\"Play\")\n\t$Quit.text = tr(\"Quit\")\n")
	_write(hand_project + "/ui/shop.gd", "extends Node\n\n\nfunc _ready() -> void:\n\t$Buy.text = tr(\"Buy\")\n\t$Sell.text = tr(\"Sell\")\n")
	_write(hand_folder + "/ui.csv", HAND_UI)
	_write(hand_folder + "/strings.csv", HAND_STRINGS)
	var scan: Script = EventSheetTranslationScan
	var editor: EventSheetEditor = EventSheetEditor.new()
	var studio: EventSheetTranslationStudio = editor._translation_studio
	studio._build_window()
	studio.scan_folder = hand_project
	studio.catalog_target = hand_folder
	# Before the first Find text every catalog is hand-made: adding a language and the fake column
	# write nothing, fail nothing, and name the catalogs they left alone.
	var first_add: Dictionary = studio.run_add_language("de")
	var first_pseudo: Dictionary = EventSheetGameCatalog.write_pseudo_column(hand_folder)
	var first_card: Label = (studio._results["add"] as EventSheetPopupUI.ResultCard).lines_box.get_child(0).get_child(1) as Label
	var all_passed: bool = SUPPORT.pins(NAME, [
		["with only hand-made catalogs, a new language writes nothing and says why",
			[first_add.get("ok"), first_add.get("left_alone"), str(first_add.get("message", ""))],
			[true, PackedStringArray([hand_folder + "/strings.csv", hand_folder + "/ui.csv"]),
				"Wrote nothing: every catalog in %s was made by hand. Find text makes one beside them. 2 hand-made catalog(s) left as they were: %s/strings.csv, %s/ui.csv."
				% [hand_folder, hand_folder, hand_folder]]],
		["...and its card names them instead of announcing a column", [(studio._results["add"] as EventSheetPopupUI.ResultCard).lines_box.get_child_count(), first_card.text],
			[1, "2 catalogs here were made by hand, so nothing was written to them: strings.csv, ui.csv."]],
		["the fake column does the same", [first_pseudo.get("ok"), first_pseudo.get("left_alone")],
			[true, PackedStringArray([hand_folder + "/strings.csv", hand_folder + "/ui.csv"])]],
		["and both left the hand-made catalogs as written", [FileAccess.get_file_as_string(hand_folder + "/ui.csv"),
			FileAccess.get_file_as_string(hand_folder + "/strings.csv")], [HAND_UI, HAND_STRINGS]],
	])
	# Notes off: folder mode still writes the notes column, the mark the studio knows its own by.
	var outcome: Dictionary = scan.extract(hand_project, hand_folder, false)
	var again: Dictionary = studio.run_extract()
	var card: PackedStringArray = PackedStringArray()
	for row: Node in (studio._results["find"] as EventSheetPopupUI.ResultCard).lines_box.get_children():
		card.append((row.get_child(1) as Label).text)
	all_passed = SUPPORT.pins(NAME, [
		["the hand-made catalogs are byte for byte as written", [FileAccess.get_file_as_string(hand_folder + "/ui.csv"),
			FileAccess.get_file_as_string(hand_folder + "/strings.csv")], [HAND_UI, HAND_STRINGS]],
		["a new key their folders say goes to a studio catalog beside each", scan.catalog_files(hand_folder), PackedStringArray([
			hand_folder + "/strings.csv", hand_folder + "/strings.extracted.csv", hand_folder + "/ui.csv", hand_folder + "/ui.extracted.csv"])],
		["holding only the keys no catalog had, with the notes column", [FileAccess.get_file_as_string(hand_folder + "/ui.extracted.csv"),
			FileAccess.get_file_as_string(hand_folder + "/strings.extracted.csv")],
			["keys,en,notes\nSell,Sell,shop.gd:6\n", "keys,en,notes\nQuit,Quit,main.gd:6\n"]],
		["the outcome names every hand-made catalog it left alone", outcome.get("left_alone", PackedStringArray()),
			PackedStringArray([hand_folder + "/strings.csv", hand_folder + "/ui.csv"])],
		["and says so", str(outcome.get("message", "")),
			"2 key(s) in 2 catalog(s) under %s - 2 new, 0 already translated and kept. 2 hand-made catalog(s) left as they were: %s/strings.csv, %s/ui.csv."
			% [hand_folder, hand_folder, hand_folder]],
		["a second Find text finds its own catalogs again and adds nothing", [int(again.get("added", -1)), int(again.get("keys", 0))], [0, 2]],
		["the result card names every hand-made catalog", card[card.size() - 1],
			"2 catalogs here were made by hand, so nothing was written to them: strings.csv, ui.csv."],
		["the studio's own catalog is recognised, a Godot one is not",
			[scan.is_studio_catalog(hand_folder + "/ui.extracted.csv"), scan.is_studio_catalog(hand_folder + "/ui.csv")], [true, false]],
		["a hand-made strings.csv does not make the project a one-file target", scan.default_catalog_target(hand_folder), hand_folder],
		["a studio-made one does", scan.default_catalog_target(own_folder), own_folder + "/strings.csv"],
	]) and all_passed
	# A one-file sweep with notes off writes Godot's plain shape, which the studio reads as hand-made:
	# it is never rewritten, and the project starts in folder mode beside it.
	DirAccess.make_dir_recursive_absolute(hand_project + "/plain")
	scan.extract(hand_project, hand_project + "/plain/strings.csv", false)
	all_passed = SUPPORT.pins(NAME, [
		["a notes-off one-file catalog is Godot's plain shape", FileAccess.get_file_as_string(hand_project + "/plain/strings.csv"),
			"keys,en
Play,Play
Quit,Quit
Buy,Buy
Sell,Sell
"],
		["so the studio treats it as hand-made and starts the folder", scan.default_catalog_target(hand_project + "/plain"), hand_project + "/plain"],
	]) and all_passed
	# Bringing a file back, adding a language and the fake column write only the studio's catalogs.
	_write(own_returned, "keys,fr\nSell,Vendre\nBuy,Acheter encore\n")
	var imported: Dictionary = scan.import_catalog(own_returned, hand_folder)
	var added: Dictionary = scan.add_locale(hand_folder, "de")
	var pseudo: Dictionary = EventSheetGameCatalog.write_pseudo_column(hand_folder)
	var view: VBoxContainer = load(VIEW_PATH).new()
	view.show_catalogs(scan.catalog_files(hand_folder), hand_folder)
	all_passed = SUPPORT.pins(NAME, [
		["after all three the hand-made catalogs are still byte for byte as written",
			[FileAccess.get_file_as_string(hand_folder + "/ui.csv"), FileAccess.get_file_as_string(hand_folder + "/strings.csv")], [HAND_UI, HAND_STRINGS]],
		["the returned line lands in the studio catalog", FileAccess.get_file_as_string(hand_folder + "/ui.extracted.csv"),
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
	_write(table_file, "keys,en,fr,qps,notes\r\nPlay,Play,Jouer,[Pláý],main.gd:5\r\n\r\n\"Yes, please\",\"Yes, please\",,,\r\nQuit,Quit\r\n")
	var table: RefCounted = load(TABLE_PATH).new()
	var opened: Dictionary = table.open(table_file)
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
			"Saved the fr line for \"Yes, please\" in %s." % table_file.get_file()],
		["only that line changes, quoted where it must be, Windows endings kept", FileAccess.get_file_as_string(table_file),
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
	view.show_catalogs(EventSheetTranslationScan.catalog_files(own_folder), own_folder, own_folder + "/strings.csv")
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
		["the chosen catalog is the one on show", view.table.path, own_folder + "/strings.csv"],
		["the status line says which lines are on screen", first_status, "Lines 1 to 1 of 2 · in strings.csv"],
		["missing only counts each language's gaps by its name", missing_status, "Missing only: 1 French lines · in strings.csv"],
		["search counts the lines that hold the text", search_status, "1 of 2 lines hold \"play\" · in strings.csv"],
		["next and previous open the line they land on, wrapping at the ends", opened, [0, 1, 0]],
	])
	view.show_catalogs(PackedStringArray(), own_project + "/no_catalog_yet")
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
	for root: String in [own_project, own_folder, hand_project, hand_folder]:
		for path: String in EventSheetTranslationScan.files_under(root, ["gd", "csv", "translation"]):
			DirAccess.remove_absolute(path)
	for path: String in [own_single, own_returned, table_file]:
		DirAccess.remove_absolute(path)
