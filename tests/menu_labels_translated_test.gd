# Godot EventSheets - Every word a menu shows has a translation row.
#
# A menu item added with a plain English label is translated by Godot when a translation row holds
# it, so a label with no row stays English in every language. The editor's scripts are swept for menu
# items added with a literal label, and each label that holds a word must be a row in the bundled
# translations. A label that is only a pattern of other values ("%s - %s") holds no word.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "menu_labels_translated_test"
const EDITOR_DIR := "res://addons/eventsheet/editor/"
const ONE_LANGUAGE := "res://addons/eventsheet/translations/de.csv"
const ITEM_PATTERN := "add_(?:item|check_item|radio_check_item|submenu_item|submenu_node_item|icon_item|icon_check_item)\\((?:[^,\"()]*,\\s*)?\"((?:[^\"\\\\]|\\\\.)*)\""


static func run() -> bool:
	var rows: Dictionary = {}
	var csv: FileAccess = FileAccess.open(ONE_LANGUAGE, FileAccess.READ)
	while csv != null and not csv.eof_reached():
		var line: PackedStringArray = csv.get_csv_line()
		if not line.is_empty():
			rows[line[0]] = true
	var pattern: RegEx = RegEx.create_from_string(ITEM_PATTERN)
	var word: RegEx = RegEx.create_from_string("[A-Za-z]{2,}")
	var missing: Array[String] = []
	for path: String in _scripts(EDITOR_DIR):
		for source_line: String in FileAccess.get_file_as_string(path).split("\n"):
			if source_line.contains("translate("):
				continue
			for found: RegExMatch in pattern.search_all(source_line):
				var label: String = found.get_string(1).replace("\\\"", "\"")
				if word.search(label.replace("%s", "").replace("%d", "")) == null or rows.has(label) or missing.has(label):
					continue
				missing.append(label)
	missing.sort()
	return SUPPORT.check(P, "every menu label has a translation row", missing, [])


static func _scripts(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".gd"):
			out.append(dir_path.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(dir_path):
		out.append_array(_scripts(dir_path.path_join(sub)))
	return out
