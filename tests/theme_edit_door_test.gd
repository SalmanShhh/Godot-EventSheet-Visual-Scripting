# Godot EventSheets - A theme file in the FileSystem dock has a right-click door to the Theme Editor.
#
# The entry is offered for one theme file and nothing else, decided by the file's own first line without
# loading it. Double-clicking a theme is not claimed: the Inspector keeps editing it as it always did, and
# a sheet's own theme shown in the Inspector never pulls the editor into the sheet workspace.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "theme_edit_door_test"
const THEME_FILES := "res://addons/eventsheet/theme/theme_files.gd"
const STARTER := "res://addons/eventsheet/themes/editor_native_theme.tres"


static func run() -> bool:
	var files: GDScript = load(THEME_FILES)
	var filesystem: int = EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM
	var script_editor: int = EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR
	var plain: String = SUPPORT.own_path("door_plain.tres")
	var file: FileAccess = FileAccess.open(plain, FileAccess.WRITE)
	file.store_string("[gd_resource type=\"Resource\" format=3]\n\n[resource]\n")
	file.close()
	var own: String = SUPPORT.own_path("door_theme.tres")
	ResourceSaver.save(EventSheetThemeEditor.duplicate_style(null), own)
	return SUPPORT.pins(P, [
		["a starter theme is a theme file", files.is_theme_file(STARTER), true],
		["a theme the project saved is one", files.is_theme_file(own), true],
		["a resource that is not a theme is not", files.is_theme_file(plain), false],
		["a script is not", files.is_theme_file("res://addons/eventsheet/theme/theme_files.gd"), false],
		["a missing file is not", files.is_theme_file("res://no_such_theme.tres"), false],
		["the FileSystem offers the door for one theme file", EventSheetContextMenu.should_offer_edit_theme(filesystem, PackedStringArray([STARTER])), true],
		["not for two files", EventSheetContextMenu.should_offer_edit_theme(filesystem, PackedStringArray([STARTER, own])), false],
		["not for a file that is no theme", EventSheetContextMenu.should_offer_edit_theme(filesystem, PackedStringArray([plain])), false],
		["not in the script editor", EventSheetContextMenu.should_offer_edit_theme(script_editor, PackedStringArray([STARTER])), false],
		["the plugin does not claim a theme for double-click", EventForgePlugin.is_event_sheet_resource(EventSheetThemeEditor.duplicate_style(null)), false],
	])
