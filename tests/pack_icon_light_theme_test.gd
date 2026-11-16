# EventForge - pack icons and section icons follow the editor's light or dark theme.
#
# Godot recolours an icon of ours for a light theme only when the icon's import asks for it. The
# imports the repo ships do; a pack added to a project from the behaviour library arrives without
# one, so the plugin turns the flag on in the import the editor wrote, and the library window (which
# draws files Godot never imports) swaps the same ink pairs itself.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "pack_icon_light_theme_test"
const IMPORTS := preload("res://addons/eventforge/editor/pack_icon_imports.gd")
const STYLE := preload("res://tools/icon_style.gd")


static func run() -> bool:
	var ok: bool = true
	# The flag is turned on in an import that has it off, once, and the icon is named for a reimport.
	var svg_path: String = SUPPORT.own_path("light/icon.svg")
	var untouched_path: String = SUPPORT.own_path("light/icon_3d.svg")
	var bare_path: String = SUPPORT.own_path("light/other.svg")
	_write(svg_path, "<svg/>")
	_write(untouched_path, "<svg/>")
	_write(bare_path, "<svg/>")
	_write(svg_path + ".import", "[params]\neditor/scale_with_editor_scale=false\neditor/convert_colors_with_editor_theme=false\n")
	_write(untouched_path + ".import", STYLE.import_text(untouched_path))
	var changed: PackedStringArray = IMPORTS.follow_the_editor_theme(PackedStringArray([svg_path, untouched_path, bare_path]))
	ok = SUPPORT.pins(NAME, [
		["only the icon whose import had the flag off is named", changed, PackedStringArray([svg_path])],
		["its import follows the editor theme now", FileAccess.get_file_as_string(svg_path + ".import").contains(STYLE.IMPORT_FLAG), true],
		["and at the editor's scale", FileAccess.get_file_as_string(svg_path + ".import").contains(IMPORTS.SCALE_ON), true],
		["an import that already followed it is left as it was", FileAccess.get_file_as_string(untouched_path + ".import"), STYLE.import_text(untouched_path)],
		["an icon with no import yet is left to the editor", FileAccess.file_exists(bare_path + ".import"), false],
		["asking again names nothing", IMPORTS.follow_the_editor_theme(PackedStringArray([svg_path, untouched_path])), PackedStringArray()],
	]) and ok
	# The icons the plugin looks after are the packs' and the sections'.
	var all_paths: PackedStringArray = IMPORTS.all_icon_paths()
	ok = SUPPORT.pins(NAME, [
		["the packs' icons are listed", all_paths.has("res://eventsheet_addons/juice/icon.svg"), true],
		["the 3D icon of vector_shapes too", all_paths.has("res://eventsheet_addons/vector_shapes/icon_3d.svg"), true],
		["and the picker sections' icons", all_paths.has("res://addons/eventsheet/icons/sections/camera.svg"), true],
		["pack icons are a part of all of them", IMPORTS.pack_icon_paths().size() < all_paths.size(), true],
	]) and ok
	# The library window swaps Godot's dark inks for the light ones, for every ink there is.
	var light_inks: Dictionary = EventSheetBehaviourLibraryWindow.LIGHT_THEME_INKS
	ok = SUPPORT.pins(NAME, [
		["five inks are swapped", light_inks.size(), 5],
		["every dark ink is one of the icon inks", PackedStringArray(light_inks.keys()), PackedStringArray(STYLE.INKS)],
		["the dark theme keeps the file as it is", EventSheetBehaviourLibraryWindow.inked_for_theme("<path fill=\"#8da5f3\"/>", false), "<path fill=\"#8da5f3\"/>"],
		["the light theme swaps the 2D blue", EventSheetBehaviourLibraryWindow.inked_for_theme("<path fill=\"#8da5f3\"/>", true), "<path fill=\"#3d64dd\"/>"],
		["and the neutral grey, as a stroke too", EventSheetBehaviourLibraryWindow.inked_for_theme("<path stroke=\"#e0e0e0\"/>", true), "<path stroke=\"#5a5a5a\"/>"],
		["a headless run is never light", EventSheetBehaviourLibraryWindow.editor_is_light(), false],
	]) and ok
	return ok


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
