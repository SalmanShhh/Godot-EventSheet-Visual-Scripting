# Godot EventSheets - bring every bundled theme preset forward onto the current token set.
#
# A preset is a .tres written against the tokens that existed the day it was saved. When a new family
# of tokens ships, an older preset silently keeps the plugin's own defaults for them - which is
# exactly wrong on a pale theme, where dark chips and near-black stripes end up on white paper.
#
# This walks every bundled preset and re-derives the reading / chrome / Manual tokens from the tokens
# that preset already sets, through the one shared rule (EventSheetThemeDerivation). Idempotent: run
# it again after adding a token and every preset picks the new one up in its own colours.
#   <godot> --headless --path . --script tools/backfill_theme_tokens.gd
@tool
extends SceneTree

const THEME_DIRS: Array[String] = [
	"res://demo/themes",
	"res://addons/eventsheet/themes"
]


func _init() -> void:
	var updated: int = 0
	for dir_path: String in THEME_DIRS:
		for file_name: String in DirAccess.get_files_at(dir_path):
			if not file_name.ends_with(".tres"):
				continue
			var path: String = "%s/%s" % [dir_path, file_name]
			var style: EventSheetEditorStyle = load(path) as EventSheetEditorStyle
			if style == null:
				print("[backfill_theme_tokens] skip (not an editor style): %s" % path)
				continue
			EventSheetThemeDerivation.fill_derived_tokens(style)
			var error: Error = ResourceSaver.save(style, path)
			print("[backfill_theme_tokens] %s (%d)" % [path, error])
			updated += 1
	print("[backfill_theme_tokens] presets brought forward: %d" % updated)
	quit(0)
