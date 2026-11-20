# Godot EventSheets - the Manual's dividers and fixed words, and the Start window's shelf headings, read in the
# reader's language.
#
# A divider is drawn in capitals, and the translation catalog is keyed by the English words as written, so a
# divider built by upper-casing the English first never found its row and stayed English in every language.
# The words are now translated first and the capitals come after. This pins that for every divider the
# Manual's contents list draws, every shelf heading the Start window draws, the Manual home page's headings,
# door labels and lines, and the "Open online" button, in all eight languages, and pins that every one of those
# words has a filled row in each language file and a row in the template.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "manual_dividers_translated_test"
const FOLDER := "res://addons/eventsheet/translations"
const LOCALES: Array[String] = ["de", "es", "fr", "it", "ja", "ko", "ru", "zh_CN"]

## The fixed words of the Manual's chrome that are not a page of the corpus.
const FIXED_WORDS: Array[String] = ["Open online", "Opens the page you are reading in your browser, pinned to the version you installed.",
	"Opens the project's source repository in your browser.",
	"This is the editor's own project - open its source as sheets", "Walks this tutorial step by step, in the sheet you have open.",
	"Copy to the clipboard", "Copy these rows as shareable snippet text.", "Jump to \"%s\".",
	"Off means the Start page only opens from Sheet ▸ Start page."]


static func run() -> bool:
	var words: Array[String] = _divider_words()
	for row: Array in EventSheetDocReference.HOME_START_HERE + EventSheetDocReference.HOME_LOOK_UP:
		words.append(str(row[0]))
	for block: Dictionary in EventSheetDocReference.home_blocks():
		for key: String in ["text", "bbcode"]:
			if block.has(key):
				words.append(str(block[key]))
	words.append_array(FIXED_WORDS)
	words.append_array(["Start here", "Look something up"])
	var files: Array[String] = ["TEMPLATE"]
	files.append_array(LOCALES)
	var rows: Array = []
	var tables: Dictionary = {}
	for file_name: String in files:
		tables[file_name] = _read(file_name)
	for file_name: String in files:
		var table: Dictionary = tables[file_name]
		var missing: PackedStringArray = PackedStringArray()
		for word: String in _unique_english(words):
			var cell: String = str(table.get(word, "<no row>"))
			if cell == "<no row>" or (file_name != "TEMPLATE" and cell.strip_edges().is_empty()):
				missing.append(word.left(40))
		rows.append(["%s has a row for every divider and fixed word (missing: %s)" % [file_name, ", ".join(missing)], missing.size(), 0])
	EventSheetL10n.rescan()
	EventSheetL10n.ensure_loaded()
	for locale: String in LOCALES:
		EventSheetL10n.set_locale(locale)
		for title: String in _divider_words():
			var shown: String = EventSheetDocBrowser.group_label(title)
			var translated: String = str((tables[locale] as Dictionary).get(title, "")).to_upper()
			rows.append(["%s: the Manual's divider '%s' is the translated words in capitals" % [locale, title.left(30)], shown, translated])
			# A word that is the same in the language ("Manual" in Spanish) is allowed to look the same.
			var same_word: bool = str((tables[locale] as Dictionary).get(title, "")) == title
			rows.append(["%s: and it is not the English capitals unless the language spells it the same ('%s')" % [locale, title.left(30)],
				shown != title.to_upper() or same_word, true])
			rows.append(["%s: the Start window heading for '%s' is built the same way" % [locale, title.left(30)],
				EventSheetStartPage.shelf_heading(title), translated])
		var table: Dictionary = tables[locale]
		var trail: String = EventSheetDocBrowser.breadcrumb_text(PackedStringArray(["Manual", "Documentation index", "A guide's own title"]))
		rows.append(["%s: the trail above a page says its fixed crumbs in the language and leaves a guide's title alone" % locale, trail,
			" ▸ ".join(PackedStringArray([str(table.get("Manual", "")), str(table.get("Documentation index", "")), "A guide's own title"]))])
		rows.append(["%s: the Start window's shelf chips are the translated first words" % locale,
			EventSheetL10n.translate("Project-wide (autoloads)").get_slice(" (", 0), str(table.get("Project-wide (autoloads)", "")).get_slice(" (", 0)])
		var home: Array[Dictionary] = EventSheetDocReference.home_blocks()
		rows.append(["%s: the Manual home page heading is translated" % locale, str(home[0].get("text", "")) != "Documentation index", true])
		for block: Dictionary in home:
			for item: Variant in (block.get("items", []) as Array):
				var label: String = str((item as Dictionary).get("label", ""))
				rows.append(["%s: the home page door '%s' is not English" % [locale, label], label != "" and _is_english_door(label), false])
	EventSheetL10n.set_locale("en")
	rows.append(["English keeps its capitals", EventSheetDocBrowser.group_label("Learn by doing"), "LEARN BY DOING"])
	rows.append(["a divider with no row reads in English capitals, never as a key", EventSheetDocBrowser.group_label("A group added later"), "A GROUP ADDED LATER"])
	rows.append(["the Start window keeps English capitals in English", EventSheetStartPage.shelf_heading("Your project"), "YOUR PROJECT"])
	return SUPPORT.pins(P, rows)


## Every divider the Manual's contents list draws: the Manual, the corpus groups, and the two reference branches.
static func _divider_words() -> Array[String]:
	var found: Array[String] = [EventSheetDocReference.MANUAL_TITLE, EventSheetDocReference.SECTION_TREE_TITLE,
		EventSheetDocReference.PACK_TREE_TITLE, EventSheetStartPage.SHELF_YOUR_PROJECT]
	for group: Dictionary in EventSheetDocLibrary.groups():
		found.append(str(group.get("title", "")))
	return found


static func _unique_english(words: Array[String]) -> Array[String]:
	var seen: Dictionary = {}
	var found: Array[String] = []
	for word: String in words:
		if not word.is_empty() and not seen.has(word):
			seen[word] = true
			found.append(word)
	return found


## Whether a door label is one of the English spellings the home page started with.
static func _is_english_door(label: String) -> bool:
	for row: Array in EventSheetDocReference.HOME_START_HERE + EventSheetDocReference.HOME_LOOK_UP:
		if str(row[0]) == label:
			return true
	return false


## One translation file as {key: cell}.
static func _read(file_name: String) -> Dictionary:
	var table: Dictionary = {}
	var file: FileAccess = FileAccess.open("%s/%s.csv" % [FOLDER, file_name], FileAccess.READ)
	if file == null:
		return table
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() >= 1 and not line[0].is_empty():
			table[line[0]] = line[1] if line.size() > 1 else ""
	return table
