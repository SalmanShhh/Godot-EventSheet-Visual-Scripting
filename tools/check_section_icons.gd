# EventForge - does every builtin picker section's icon EXIST in the editor theme?
#
# The picker draws each builtin section header with an editor-theme icon resolved by name
# (ACEPickerDialog.category_icon_name). The suite proves every live category resolves SOME name, but
# it runs headless, where there is no editor theme to ask, so a name the theme does not carry looks
# exactly like one it does - and the header silently goes text-only. This tool runs INSIDE a real
# editor and asks the theme itself, once per live builtin category.
#
# Run NON-headless AND in editor mode (a plain --script run has no editor theme at all):
#   godot --editor --path . --script tools/check_section_icons.gd
#
# Prints one line per miss (add `-- --list` to print every category's resolved name too), then
# `section icons: N checked, M missing`; exit 1 on any miss.
@tool
extends SceneTree

var _frames: int = 0


func _init() -> void:
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	# The editor theme is not built during _init; a few frames in, it is.
	if _frames < 4:
		return
	process_frame.disconnect(_on_frame)
	quit(_check())


## Asks the live editor theme for every builtin category's resolved icon name. Returns the exit code.
func _check() -> int:
	var editor_theme: Theme = EditorInterface.get_editor_theme()
	if editor_theme == null or editor_theme.get_icon_list("EditorIcons").is_empty():
		print("section icons: no editor theme - run with --editor and without --headless")
		return 1
	var categories: Dictionary = {}
	for entry: Variant in ACERegistry.get_builtin_descriptors():
		categories[str(entry.get("category"))] = true
	var names: Array = categories.keys()
	names.sort()
	var listing: bool = "--list" in OS.get_cmdline_user_args()
	var checked: int = 0
	var missing: int = 0
	for category: String in names:
		if category.is_empty() or category in ACEPickerDialog.UNMAPPED_ICON_CATEGORIES:
			continue
		checked += 1
		var icon_name: String = ACEPickerDialog.category_icon_name(category)
		if listing:
			print("  \"%s\" -> %s" % [category, icon_name])
		if icon_name.is_empty():
			missing += 1
			print("  [MISS] \"%s\" resolves to no icon name" % category)
		elif not editor_theme.has_icon(icon_name, "EditorIcons"):
			missing += 1
			print("  [MISS] \"%s\" -> %s, which the editor theme does not carry" % [category, icon_name])
	print("section icons: %d checked, %d missing" % [checked, missing])
	return 1 if missing > 0 else 0
