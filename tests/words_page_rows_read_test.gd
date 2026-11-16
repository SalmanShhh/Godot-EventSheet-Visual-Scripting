# Godot EventSheets - Every row on the Words page changes a word the editor shows.
#
# A row whose word nothing reads is a control that does nothing: a reader types a new word, and no
# row, menu or window says it. The page's rows are read off the page itself, and each key must be
# read somewhere in the editor through the Words table (`EventSheetWords.word("key")`, a callback
# word, or a file that names the key as the one it reads). The page and its own preview are not
# readers.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "words_page_rows_read_test"
## The files that only describe or list the words, so a key named there is not a reader.
const NOT_READERS: Array[String] = [
	"res://addons/eventsheet/editor/words.gd",
	"res://addons/eventsheet/editor/words_settings_dialog.gd",
	"res://addons/eventsheet/editor/docs/doc_editor_words.gd",
]


static func run() -> bool:
	var page: EventSheetWordsSettingsDialog = EventSheetWordsSettingsDialog.new()
	var shown: Array[String] = []
	for row_key: String in page._rows:
		var key: String = row_key.get_slice("|", 0)
		if not shown.has(key):
			shown.append(key)
	page.free()
	var sources: PackedStringArray = PackedStringArray()
	for path: String in _scripts("res://addons/"):
		if not NOT_READERS.has(path):
			sources.append(FileAccess.get_file_as_string(path))
	var all_source: String = "\n".join(sources)
	var unread: Array[String] = []
	for key: String in shown:
		var read: bool = (all_source.contains("word(\"%s\")" % key) or all_source.contains("callback_word(\"%s\"" % key)
			or all_source.contains("word_for(\"%s\"" % key) or all_source.contains("WORD_KEY := \"%s\"" % key))
		if not read:
			unread.append(key)
	var ok: bool = SUPPORT.check(P, "the page shows rows", shown.is_empty(), false)
	ok = SUPPORT.check(P, "every row on the page is read by the editor", unread, []) and ok
	# The keys themselves stay: a reader's choice for each is saved in their editor settings.
	ok = SUPPORT.check(P, "no saved key is removed from the table",
		[EventSheetWords.WORDS.has("layout"), EventSheetWords.WORDS.has("workspace")], [true, true]) and ok
	return ok


static func _scripts(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".gd"):
			out.append(dir_path.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(dir_path):
		out.append_array(_scripts(dir_path.path_join(sub)))
	return out
