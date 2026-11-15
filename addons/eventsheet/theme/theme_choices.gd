# Godot EventSheets - two small decisions about which theme colours and which menu entry apply.
#
# DELIBERATELY NO `class_name`: callers load it by path at the moment they ask, so the first open of
# the workspace does not compile it.
@tool
extends RefCounted


## Whether the script editor's colours may paint the code beside a variable row on a sheet whose rows are
## `sheet_ground`, in an editor whose base colour is `editor_base`: only when both are the same brightness
## (a light sheet theme in a dark editor keeps its own colours, or the code would be unreadable). With no
## editor (a clear base) there are no editor colours to use.
static func use_editor_colours(sheet_ground: Color, editor_base: Color) -> bool:
	if editor_base.a <= 0.0 or sheet_ground.a <= 0.0:
		return editor_base.a > 0.0 and sheet_ground.a <= 0.0
	return EventSheetEditorThemeDeriver.is_light_base(sheet_ground) == EventSheetEditorThemeDeriver.is_light_base(editor_base)


## Which theme menu entry to tick. `paths` is each entry's stored path ("" is Match Editor). No theme on
## the sheet ticks Match Editor; a theme from a file ticks its entry; a theme with no file (the copy
## Apply To Current Sheet writes into the sheet) is none of the entries, so nothing is ticked.
static func menu_index_for(active_path: String, has_style: bool, paths: Array) -> int:
	if not has_style:
		return 0
	if active_path.is_empty():
		return -1
	for i in range(paths.size()):
		if str(paths[i]) == active_path:
			return i
	return 0
