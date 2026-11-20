# EventSheets - a colour the Theme Editor offers is a colour something draws with.
#
# A theme token nothing reads is a swatch that does nothing: the user changes it and sees no change.
# Two families (the pattern chip's plate and word, the Inspector note's panel and words) had lost their
# last reader without anyone noticing, because the contrast gate went on measuring them. They are
# retired (kept as stored values so a saved theme still loads and saves whole), and this test keeps the
# whole class of fault from coming back:
#
#   * every colour token a theme resource OFFERS (an `@export`, not `@export_storage`) has a reader -
#     a script outside the theme plumbing that names it, or a function of its own class that reads it
#     and is called from such a script (the Manual's `resolve_*` accessors are the second kind);
#   * a theme file that still carries a retired token loads and saves with every value kept.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "theme_tokens_have_readers_test"

## The theme resources whose tokens the Theme Editor offers.
const THEME_FOLDER: String = "res://addons/eventsheet/theme"
## Files that define, derive, list or measure tokens: naming a token there is not reading it.
const PLUMBING: PackedStringArray = [
	"editor_theme_deriver.gd", "event_sheet_theme_derivation.gd", "theme_contrast_pairs.gd", "theme_files.gd",
	"theme_choices.gd", "event_sheet_theme_presets.gd", "light_colors.gd", "theme_editor_dialog.gd",
	"sheet_look_memory.gd",
]
const SKIPPED_FOLDERS: PackedStringArray = ["res://addons/eventsheet/help", "res://addons/eventsheet_library"]
const RETIRED: PackedStringArray = [
	"pattern_chip_background_color", "pattern_chip_foreground_color",
	"drawer_info_background_color", "drawer_info_border_color", "drawer_info_text_color",
]


static func run() -> bool:
	var token_class: String = "class_name Style\nextends Resource\n\n@export var drawn: Color = Color.RED\n@export var dead: Color = Color.RED\n" \
		+ "@export_storage var stored: Color = Color.RED\n@export var via: Color = Color.RED\n\n\nfunc resolve_via() -> Color:\n\treturn via\n"
	var reader: String = "func paint() -> void:\n\tdraw(style.drawn)\n\tdraw(Style.resolve_via())\n"
	var ok: bool = SUPPORT.pins(P, [
		["a colour a script outside the plumbing names is read, a colour nothing names is not, a stored one is not offered",
			unread_offered({"res://t/style.gd": token_class, "res://t/draw.gd": reader}, ["style.gd"]), PackedStringArray(["dead"])],
		["naming a colour in plumbing is not reading it",
			unread_offered({"res://t/style.gd": token_class, "res://t/derive.gd": "func f() -> void:\n\tstyle.drawn = a\n\tstyle.dead = b\n\tstyle.via = c\n"},
				["style.gd"], ["derive.gd"]), PackedStringArray(["drawn", "dead", "via"])],
		["a colour read only by a function nothing calls is not read",
			unread_offered({"res://t/style.gd": token_class, "res://t/draw.gd": "func paint() -> void:\n\tdraw(style.drawn)\n"}, ["style.gd"]),
			PackedStringArray(["dead", "via"])],
	])
	var texts: Dictionary = {}
	_gather("res://addons", texts)
	var definitions: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(THEME_FOLDER):
		if file.ends_with(".gd") and not PLUMBING.has(file):
			definitions.append(file)
	var found: PackedStringArray = unread_offered(texts, definitions, PLUMBING)
	ok = SUPPORT.check(P, "every colour the Theme Editor offers has a reader", found, PackedStringArray()) and ok
	ok = _retired_tokens_survive() and ok
	ok = _old_theme_file() and ok
	return ok


## The offered colour tokens (names) of the `definitions` files that nothing reads. `texts` maps path to text.
static func unread_offered(texts: Dictionary, definitions: PackedStringArray, plumbing: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var offered: RegEx = RegEx.create_from_string("(?m)^@export(?:\\([^)]*\\))? var (\\w+)\\s*:\\s*Color")
	for path: String in texts:
		if not definitions.has(path.get_file()):
			continue
		var text: String = str(texts[path])
		for token: RegExMatch in offered.search_all(text):
			var name: String = token.get_string(1)
			if not _is_read(name, path, text, texts, definitions, plumbing):
				out.append(name)
	return out


static func _is_read(name: String, own_path: String, own_text: String, texts: Dictionary, definitions: PackedStringArray, plumbing: PackedStringArray) -> bool:
	var word: RegEx = RegEx.create_from_string("\\b" + name + "\\b")
	for path: String in texts:
		var file: String = path.get_file()
		if path == own_path or definitions.has(file) or plumbing.has(file):
			continue
		if word.search(str(texts[path])) != null:
			return true
	# Read inside its own class by a function that something else calls.
	for accessor: RegExMatch in RegEx.create_from_string("(?m)^func (\\w+)\\([^\\n]*\\n((?:\\t[^\\n]*\\n|\\n)+)").search_all(own_text):
		if word.search(accessor.get_string(2)) == null:
			continue
		var call: RegEx = RegEx.create_from_string("\\b" + accessor.get_string(1) + "\\(")
		for path: String in texts:
			var file: String = path.get_file()
			if path == own_path or definitions.has(file) or plumbing.has(file):
				continue
			if call.search(str(texts[path])) != null:
				return true
	return false


static func _gather(folder: String, into: Dictionary) -> void:
	if SKIPPED_FOLDERS.has(folder):
		return
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			into[folder + "/" + file] = FileAccess.get_file_as_string(folder + "/" + file)
	for sub: String in DirAccess.get_directories_at(folder):
		_gather(folder + "/" + sub, into)


## A theme saved while the chip and the note panel still had colours loads and saves with every value.
static func _retired_tokens_survive() -> bool:
	var chrome: EventSheetChromeStyle = EventSheetChromeStyle.new()
	chrome.drawer_info_text_color = Color(0.9, 0.1, 0.1, 1.0)
	chrome.drawer_info_background_color = Color(0.1, 0.9, 0.1, 0.5)
	var reading: EventSheetReadingStyle = EventSheetReadingStyle.new()
	reading.pattern_chip_background_color = Color(0.2, 0.3, 0.4, 1.0)
	var chrome_path: String = SUPPORT.own_path("retired_chrome.tres")
	var reading_path: String = SUPPORT.own_path("retired_reading.tres")
	var saved: bool = ResourceSaver.save(chrome, chrome_path) == OK and ResourceSaver.save(reading, reading_path) == OK
	var chrome_back: EventSheetChromeStyle = ResourceLoader.load(chrome_path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetChromeStyle
	var reading_back: EventSheetReadingStyle = ResourceLoader.load(reading_path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetReadingStyle
	return SUPPORT.pins(P + ": retired", [
		["the files are written", saved, true],
		["a retired note colour comes back from a saved theme", chrome_back.drawer_info_text_color if chrome_back != null else Color.BLACK, Color(0.9, 0.1, 0.1, 1.0)],
		["and its panel colour", chrome_back.drawer_info_background_color if chrome_back != null else Color.BLACK, Color(0.1, 0.9, 0.1, 0.5)],
		["a retired chip colour comes back too", reading_back.pattern_chip_background_color if reading_back != null else Color.BLACK, Color(0.2, 0.3, 0.4, 1.0)],
		["the retired names are the ones this test says they are", RETIRED.size(), 5],
	])


## A whole theme file written before the retirement (it names the chip and the note colours) loads, keeps
## those values and saves them again.
static func _old_theme_file() -> bool:
	var loaded: EventSheetEditorStyle = ResourceLoader.load("res://tests/fixtures/theme_with_retired_tokens.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetEditorStyle
	if loaded == null:
		return SUPPORT.check(P, "an old theme file loads", false, true)
	var path: String = SUPPORT.own_path("old_theme_again.tres")
	var saved: bool = ResourceSaver.save(loaded, path) == OK
	var again: EventSheetEditorStyle = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetEditorStyle
	var note: Color = Color(0.8884314, 0.8995137, 0.92167854, 1.0)
	var word: Color = Color(0.59382546, 0.6100869, 0.6426098, 1.0)
	return SUPPORT.pins(P + ": old file", [
		["an old theme file keeps its retired note colour", loaded.get_chrome_style().drawer_info_text_color.is_equal_approx(note), true],
		["and its retired chip colour", loaded.get_reading_style().pattern_chip_foreground_color.is_equal_approx(word), true],
		["it saves again", saved, true],
		["and the saved copy keeps both", [again.get_chrome_style().drawer_info_text_color.is_equal_approx(note),
			again.get_reading_style().pattern_chip_foreground_color.is_equal_approx(word)], [true, true]],
	])
