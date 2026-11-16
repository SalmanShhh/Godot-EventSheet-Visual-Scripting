# Godot EventSheets - the words a juice card says are in all eight languages.
#
# THE ONE THING THIS FILE IS ABOUT: a card's title, its one-sentence help, its field names, the words of
# its choices and the quiet lines under it come from a schema, not from a translate() call in the editor's
# code, so the harvest tool cannot see them and a forgotten row stays English without a word. This walks the
# schema the Inspector draws and asks the translation tables for each word, in every language file.
#
# The units after a number (s, dB, px) are plain symbols and are not translated. The ten kinds the Juice
# pack derives their help sentence from its own annotations; their titles and field names are held here.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SCHEMA_PATH: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const FOLDER: String = "res://addons/eventsheet/translations/"
const LOCALES: PackedStringArray = ["de", "es", "fr", "it", "ja", "ko", "ru", "zh_CN"]
const DERIVED: PackedStringArray = ["shake", "zoom", "punch", "flash", "hitstop", "slowmo", "shockwave", "chromatic", "pulse", "hold"]

const TEST_NAME: String = "juice_card_words_translated"


static func run() -> bool:
	var words: Dictionary = _schema_words()
	var catalogs: Dictionary = {}
	for locale: String in LOCALES:
		catalogs[locale] = _read(FOLDER + locale + ".csv")
	var missing: Array = []
	for word: Variant in words:
		for locale: String in LOCALES:
			if str((catalogs[locale] as Dictionary).get(word, "")).is_empty():
				missing.append("%s: %s" % [locale, str(word).left(60)])
	var rows: Array = [
		["the schema says some words", words.size() > 100, true],
		["every word a card says has a row in all eight languages", missing.slice(0, 5), []]
	]
	var before: String = EventSheetL10n.get_locale()
	EventSheetL10n.ensure_loaded()
	EventSheetL10n.set_locale("de")
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": (load(SCHEMA_PATH) as Script).call("schema")})
	drawer.add_card("sound")
	drawer._unfolded[0] = true
	drawer._rebuild()
	var shown: PackedStringArray = PackedStringArray()
	_collect_labels(drawer._list, shown)
	rows.append(["an open Sound card names its fields in German", shown.has("Lautstärke") and not shown.has("Volume"), true])
	EventSheetL10n.set_locale(before)
	drawer.free()
	return SUPPORT.pins(TEST_NAME, rows)


static func _collect_labels(node: Node, into: PackedStringArray) -> void:
	if node is Label:
		into.append((node as Label).text)
	for child: Node in node.get_children():
		_collect_labels(child, into)


## Every word the schema says: titles, help sentences of the kinds it writes itself, field names, the words
## of its choices, the empty-field words and the group names.
static func _schema_words() -> Dictionary:
	var schema: Dictionary = (load(SCHEMA_PATH) as Script).call("schema")
	var words: Dictionary = {}
	for group: Variant in schema.get("group_order", []):
		words[str(group)] = true
	for entry: Variant in schema.get("kinds", []):
		var kind: Dictionary = entry as Dictionary
		var derived: bool = DERIVED.has(str(kind.get("kind", "")))
		words[str(kind.get("label", ""))] = true
		if not derived:
			words[str(kind.get("help", ""))] = true
		for field: Variant in kind.get("fields", []):
			var spec: Dictionary = field as Dictionary
			if not derived:
				words[str(spec.get("label", ""))] = true
			words[str(spec.get("empty", ""))] = true
			var drawer: String = str(spec.get("drawer", ""))
			if drawer.begins_with("options:"):
				for spelled: String in drawer.substr(8).split(",", false):
					words[spelled.get_slice("=", 1) if spelled.contains("=") else spelled] = true
	for derived_label: String in ["Amount", "Seconds", "Effect"]:
		words[derived_label] = true
	words.erase("")
	return words


static func _read(path: String) -> Dictionary:
	var found: Dictionary = {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return found
	file.get_csv_line()
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() >= 2:
			found[line[0]] = line[1]
	return found
