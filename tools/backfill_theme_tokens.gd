# Godot EventSheets - bring every bundled theme preset forward onto the current token set.
#
# A preset is a .tres written against the tokens that existed the day it was saved. When a new family
# of tokens ships, an older preset silently keeps the plugin's own defaults for them - which is
# exactly wrong on a pale theme, where dark chips and near-black stripes end up on white paper.
#
# This walks every bundled preset and derives the reading / chrome / Manual tokens from the tokens
# that preset already sets, through the one shared rule (EventSheetThemeDerivation). Idempotent: run
# it again after adding a token and every preset picks the new one up in its own colours.
#   <godot> --headless --path . --script tools/backfill_theme_tokens.gd
#
# It only fills tokens the preset FILE does not already state. That word "backfill" is load-bearing:
# High Contrast picks its minimap hues and its Project bar note by hand, for readers who need them
# separable, and an earlier pass that applied the rule unconditionally flattened all of them back
# into the general derivation. A stated token is an opinion; the rule only decides what "no opinion"
# looks like.
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
			var filled: int = _fill_unstated(style, path)
			var error: Error = ResourceSaver.save(style, path)
			print("[backfill_theme_tokens] %s: %d token(s) filled (%d)" % [path, filled, error])
			updated += 1
	print("[backfill_theme_tokens] presets brought forward: %d" % updated)
	quit(0)


## Writes the derived value of every reading / chrome / Manual token the file leaves unstated, and
## reports how many it filled. Tokens the preset states are left exactly as the designer wrote them.
func _fill_unstated(style: EventSheetEditorStyle, path: String) -> int:
	var stated_by_script: Dictionary = {}
	for block: Dictionary in EventSheetThemePresets.stated_tokens(path):
		var script_name: String = str(block.get("script"))
		var seen: Array = stated_by_script.get(script_name, [] as Array)
		seen.append_array(block.get("tokens", []))
		stated_by_script[script_name] = seen
	var derived: EventSheetEditorStyle = EventSheetThemeDerivation.fill_derived_tokens(style.duplicate(true))
	var filled: int = 0
	var sections: Array[Array] = [
		["event_sheet_reading_style.gd", style.get_reading_style(), derived.get_reading_style()],
		["event_sheet_chrome_style.gd", style.get_chrome_style(), derived.get_chrome_style()],
		["event_sheet_manual_style.gd", style.get_manual_style(), derived.get_manual_style()],
	]
	for section: Array in sections:
		var stated: Array = stated_by_script.get(str(section[0]), [] as Array)
		var target: Resource = section[1]
		var source: Resource = section[2]
		for token: Dictionary in EventSheetThemeEditor.editable_tokens(target):
			var token_name: String = str(token.get("name"))
			if stated.has(token_name) or target.get(token_name) == source.get(token_name):
				continue
			target.set(token_name, source.get(token_name))
			filled += 1
	return filled
