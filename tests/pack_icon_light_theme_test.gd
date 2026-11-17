# EventForge - pack icons and section icons follow the editor's light or dark theme.
#
# Godot recolours an icon of ours for a light theme only when the icon's import asks for it. The
# imports the repo ships do, and so do the library's copies of the pack icons (a pack added from the
# library arrives with the import its icon has in the repo, so the first import is already in the
# editor's colours). A project that holds an icon imported without the flag gets it turned on by the
# plugin, and the library window (which draws files Godot never imports) swaps the same ink pairs itself.
#
# What a fresh install has ON DISK is the point of the shipped-sidecar rows: a rendered contrast figure
# passes whether or not the import asks for the recolour, because it simulates the recolour.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "pack_icon_light_theme_test"
const IMPORTS := preload("res://addons/eventforge/editor/pack_icon_imports.gd")
const STYLE := preload("res://tools/icon_style.gd")
const SHIPPED := preload("res://addons/eventforge/shipped_pack_folders.gd")
const LIBRARY := preload("res://addons/eventsheet/ace/pack_library.gd")
const LIFT_CACHE := preload("res://addons/eventforge/importer/lift_cache.gd")
const FLOW := preload("res://addons/eventsheet/editor/dock/behaviour_library_flow.gd")


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
	return _only_shipped_folders() and _shipped_sidecars() and _library_copy() and ok


## The plugin looks after the icons of the packs it ships and no others, and a project with no
## eventsheet_addons/ folder is silent (a missing folder is not an error to print).
static func _only_shipped_folders() -> bool:
	var root: String = SUPPORT.own_path("packs")
	for folder: String in ["big_number", "my_own_pack"]:
		DirAccess.make_dir_recursive_absolute(root + "/" + folder)
		_write(root + "/%s/icon.svg" % folder, "<svg/>")
	var scripts: PackedStringArray = PackedStringArray()
	LIFT_CACHE._collect_scripts(SUPPORT.own_path("no_such_folder"), scripts)
	var untouched: String = FileAccess.get_file_as_string(root + "/my_own_pack/icon.svg")
	return SUPPORT.pins(NAME, [
		["a shipped pack's icon is looked after, a user's own pack's is not", IMPORTS.pack_icon_paths(root), PackedStringArray([root + "/big_number/icon.svg"])],
		["a missing packs folder gives nothing", IMPORTS.pack_icon_paths(SUPPORT.own_path("no_such_folder")), PackedStringArray()],
		["a missing folder has no scripts to stamp", scripts, PackedStringArray()],
		["a user's own pack is left as it was", untouched, "<svg/>"],
	])


## Every icon a fresh install opens has its import on disk, asking for the editor's colours: the packs'
## own, the picker sections', and the behaviour library's copies (byte for byte what the pack's own
## import is, because the same path gives the same id). Their un-ignore rules are in .gitignore, or a
## clone would not have them.
static func _shipped_sidecars() -> bool:
	var missing: PackedStringArray = PackedStringArray()
	var unflagged: PackedStringArray = PackedStringArray()
	var library_missing: PackedStringArray = PackedStringArray()
	var library_differs: PackedStringArray = PackedStringArray()
	for path: String in IMPORTS.all_icon_paths():
		var sidecar: String = path + ".import"
		if not FileAccess.file_exists(sidecar):
			missing.append(path)
		elif not FileAccess.get_file_as_string(sidecar).contains(STYLE.IMPORT_FLAG):
			unflagged.append(path)
	for folder: String in SHIPPED.FOLDERS:
		for icon: String in ["icon.svg", "icon_3d.svg"]:
			var pack_icon: String = "res://eventsheet_addons/%s/%s" % [folder, icon]
			if not FileAccess.file_exists(pack_icon):
				continue
			var copy: String = "%s/%s/%s.import" % [LIBRARY.LIBRARY_ROOT, folder, icon]
			if not FileAccess.file_exists(copy):
				library_missing.append(folder + "/" + icon)
			elif FileAccess.get_file_as_string(copy) != STYLE.import_text(pack_icon):
				library_differs.append(folder + "/" + icon)
	var ignore_text: String = FileAccess.get_file_as_string("res://.gitignore")
	return SUPPORT.pins(NAME, [
		["every pack and section icon has its import beside it", missing, PackedStringArray()],
		["and each import asks for the editor's colours", unflagged, PackedStringArray()],
		["every library copy of a pack icon has the import too", library_missing, PackedStringArray()],
		["and it is the one the pack's own icon has", library_differs, PackedStringArray()],
		[".gitignore lets the library's icon imports through", ignore_text.contains("!addons/eventsheet_library/*/icon.svg.import") and ignore_text.contains("!addons/eventsheet_library/*/icon_3d.svg.import"), true],
		[".gitignore lets the packs' icon imports through", ignore_text.contains("!eventsheet_addons/*/icon.svg.import") and ignore_text.contains("!eventsheet_addons/*/icon_3d.svg.import"), true],
		["an icon sidecar is not a file Godot writes", LIBRARY.is_generated("icon.svg.import"), false],
		["any other import is", LIBRARY.is_generated("hit.wav.import"), true],
	])


## A folder copy carries the icon's import along, and an icon whose import names an imported copy that is
## not there yet is still waiting for its import.
static func _library_copy() -> bool:
	var root: String = SUPPORT.own_path("lib")
	var project: String = SUPPORT.own_path("proj")
	DirAccess.make_dir_recursive_absolute(root + "/demo_pack")
	_write(root + "/demo_pack/icon.svg", "<svg/>")
	_write(root + "/demo_pack/icon.svg.import", "[remap]
path=\"%s\"
" % SUPPORT.own_path("missing.ctex"))
	_write(root + "/demo_pack/other.png.import", "x")
	var copied: Dictionary = LIBRARY.copy_into_project(PackedStringArray(["demo_pack"]), root, project)
	var waiting: PackedStringArray = FLOW.unimported_files(project + "/demo_pack")
	var made: String = SUPPORT.own_path("made.ctex")
	_write(made, "x")
	_write(project + "/demo_pack/icon.svg.import", "[remap]
path=\"%s\"
" % made)
	return SUPPORT.pins(NAME, [
		["the copy worked", bool(copied.get("ok", false)), true],
		["the icon came with its import", FileAccess.file_exists(project + "/demo_pack/icon.svg.import"), true],
		["another import is left behind", FileAccess.file_exists(project + "/demo_pack/other.png.import"), false],
		["an icon whose imported copy is not there yet is waiting", waiting, PackedStringArray([project + "/demo_pack/icon.svg"])],
		["and not once it is", FLOW.unimported_files(project + "/demo_pack"), PackedStringArray()],
	])


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
