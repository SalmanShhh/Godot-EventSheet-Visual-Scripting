# Godot EventSheets - editor-string extraction for translators (dev tool, headless-safe).
#
# Builds the live dock, walks every Control it created, and writes a ready-to-fill CSV of the
# strings a translator would see: add your locale's column header and fill the second column.
#   "$GODOT" --headless --path . --script tools/extract_editor_strings.gd
# Output: res://eventsheet_translations/eventsheet_editor_strings.template.csv
#
# THE WALK ITSELF lives in tools/harvest_translations.gd, with the two derived sources beside it.
# It stayed a command of its own because the shipped translating guide names this one by name and a
# translator following it should not have to read about a harvest they are not running - and because
# the two commands answer different questions. The harvest writes the rows the plugin OWES; this
# writes everything a walk can SEE, which is the wider, noisier list a person starting a new
# language wants in front of them. Neither is the other's dry run.
extends SceneTree

const HARVEST := preload("res://tools/harvest_translations.gd")
const OUT_DIR := "res://eventsheet_translations"


func _init() -> void:
	var keys: PackedStringArray = HARVEST.walked_controls(self).keys
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var out_path: String = "%s/eventsheet_editor_strings.template.csv" % OUT_DIR
	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	file.store_csv_line(PackedStringArray(["keys", "your_locale_code_here"]))
	for key: String in keys:
		file.store_csv_line(PackedStringArray([key, ""]))
	file.close()
	print("extracted %d strings -> %s" % [keys.size(), out_path])
	quit(0)
