# Godot EventSheets - the tutorials read in the reader's language where the Start window and the Manual show them.
#
# A tutorial's title and its one-line lead are data in doc_tutorials.gd, and the English text is the key of
# a row in every translation file. So that none is ever shown in English in a translated editor by
# accident, every title and every lead has a filled row in all eight languages and a row in the template,
# the minutes and step lines have theirs, the Start window, the Manual's tree, a tutorial's own page and
# the Manual's search all say the same title, and a title typed in either language finds the tutorial.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "tutorial_titles_translated_test"
const FOLDER := "res://addons/eventsheet/translations"
const LOCALES: Array[String] = ["de", "es", "fr", "it", "ja", "ko", "ru", "zh_CN"]
const LINE_KEYS: Array[String] = ["%d min", "%d min · last step", "%d min · step %d of %d", "%s · step %d of %d",
	"Next ▶", "Learning paths"]


static func run() -> bool:
	var ok: bool = true
	var keys: Array[String] = []
	for entry: Dictionary in EventSheetDocTutorials.tutorials():
		keys.append(str(entry.get("title", "")))
		keys.append(str(entry.get("lead", "")))
	keys.append_array(LINE_KEYS)
	var files: Array[String] = ["TEMPLATE"]
	files.append_array(LOCALES)
	var rows: Array = []
	for file_name: String in files:
		var table: Dictionary = _read(file_name)
		var missing: PackedStringArray = PackedStringArray()
		for key: String in keys:
			var cell: String = str(table.get(key, "<no row>"))
			# The template carries the key with an empty cell; a language carries the words.
			if (file_name == "TEMPLATE" and cell == "<no row>") or (file_name != "TEMPLATE" and cell.strip_edges().is_empty()) \
					or (file_name != "TEMPLATE" and cell == "<no row>"):
				missing.append(key.left(40))
		rows.append(["%s has a row for every tutorial title, lead and line (missing: %s)" % [file_name, ", ".join(missing)], missing.size(), 0])
	EventSheetL10n.rescan()
	for locale: String in LOCALES:
		EventSheetL10n.set_locale(locale)
		var first: Dictionary = EventSheetDocTutorials.tutorials()[0]
		var shown: String = EventSheetDocTutorials.title_of(first)
		rows.append(["%s: the first tutorial's title is not the English one" % locale, shown != str(first.get("title", "")), true])
		var page: Array[Dictionary] = EventSheetDocTutorials.step_blocks(str(first.get("id", "")), 0)
		rows.append(["%s: the tutorial's own page is headed by the same title" % locale, str(page[0].get("text", "")), shown])
		# Every button a step card draws is said in the language, the Next one beside Back and Skip.
		for block: Dictionary in page:
			for item: Variant in (block.get("items", []) as Array):
				var label: String = str((item as Dictionary).get("label", ""))
				rows.append(["%s: the step card's '%s' button has a row of its own" % [locale, label],
					EventSheetL10n.translate(label) != label, true])
		rows.append(["%s: the Manual's contents list says Learning paths in the language" % locale,
			EventSheetL10n.translate(EventSheetDocTracks.PAGE_TITLE) != EventSheetDocTracks.PAGE_TITLE, true])
		var listed: Array[Dictionary] = EventSheetDocTutorials.list_blocks()
		rows.append(["%s: the list page says the same title" % locale, str(listed[2].get("text", "")), shown])
		rows.append(["%s: the Manual's tree says the same title" % locale,
			EventSheetDocReference.title_for(EventSheetDocReference.KIND_TUTORIAL, str(first.get("id", ""))), shown])
		var found_local: bool = _finds(shown.to_lower(), str(first.get("id", "")))
		var found_english: bool = _finds("your first event", str(first.get("id", "")))
		rows.append(["%s: the Manual's search finds the tutorial by the translated title" % locale, found_local, true])
		rows.append(["%s: and still by the English one" % locale, found_english, true])
	EventSheetL10n.set_locale("en")
	rows.append(["English stays what it is", EventSheetDocTutorials.title_of(EventSheetDocTutorials.tutorials()[0]), "Your first event"])
	rows.append(["a title with no row reads in English, never as a key", EventSheetDocTutorials.title_of({"title": "A tutorial added later"}), "A tutorial added later"])
	return SUPPORT.pins(P, rows) and ok


static func _finds(query: String, tutorial_id: String) -> bool:
	for hit: Dictionary in EventSheetDocSearch.search_all(query):
		if str(hit.get("doc_id", "")) == EventSheetDocTutorials.doc_id(tutorial_id):
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
