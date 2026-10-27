# Godot EventSheets - the behaviour library: packs waiting in a folder Godot cannot see, copied into
# a project one folder at a time.
#
# Pinned by VALUE against a small library and a small project written under user:// for the run, so
# the rules are the rules the editor runs (every EventSheetPackLibrary function takes its folders as
# parameters) and a pin never moves when a real pack does:
#
#   * what a pack drags along is read from `@ace_requires` - a class name is the folder declaring it,
#     `pack:x` is folder x, an engine class brings nothing - transitively, each folder once;
#   * a folder the project already holds is never overwritten, and Godot's own import files are not
#     copied;
#   * "used by" counts the lines that name a pack's class, the node its rows reach or its folder;
#   * the Welcome's kits are the tags at least four packs share, one kit per distinct set of packs;
#   * the picker's library search reads each member's `@ace_name` and never offers a pack the
#     project holds.
#
# And against the real tree: the library carries its `.gdignore`, and it is the shipped packs byte
# for byte (tools/build_library.gd's own gate, asked here so the suite fails on a stale library).
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const LIBRARY_BUILD := preload("res://tools/build_library.gd")
const SHIPPED := preload("res://addons/eventforge/shipped_pack_folders.gd")
const P := "behaviour_library_test"
const ROOT := "user://behaviour_library_test"
const LIB := ROOT + "/library"
const PROJECT := ROOT + "/project"


static func run() -> bool:
	_clear(ROOT)
	EventSheetPackLibrary.forget()
	_write(LIB.path_join(".gdignore"), "")
	_write(LIB.path_join("painter/painter.gd"), "## @ace_requires(Surface, Node2D)\n## @ace_tags(drawing, visual)\n## @ace_name(\"Painter\")\nclass_name Painter\nextends Node\n## Paints onto a surface. More words.\n\n## @ace_action\n## @ace_name(\"Splash Paint\")\n## @ace_codegen_template(\"$Painter.splash()\")\nfunc splash() -> void:\n\tpass\n")
	_write(LIB.path_join("painter/painter.gd.uid"), "uid://painter1\n")
	_write(LIB.path_join("painter/icon.svg.import"), "[remap]\n")
	_write(LIB.path_join("surface/surface.gd"), "## @ace_requires(pack:brushes)\n## @ace_tags(drawing, visual)\nclass_name Surface\nextends Node2D\n")
	_write(LIB.path_join("brushes/brushes.gd"), "## @ace_tags(drawing, visual)\nclass_name BrushSet\nextends Node\n")
	_write(LIB.path_join("palette/palette.gd"), "## @ace_tags(drawing, visual)\nclass_name Palette\nextends Resource\n")
	_write(LIB.path_join("stamp/stamp.gd"), "## @ace_tags(drawing, visual, stamp)\nclass_name Stamp\nextends Node\n")
	_write(LIB.path_join("runner/runner.gd"), "## @ace_tags(movement)\nclass_name Runner\nextends Node\n\n## @ace_condition\n## @ace_name(\"Is Dashing\")\nfunc is_dashing() -> bool:\n\treturn false\n")
	_write(PROJECT.path_join("eventsheet_addons/brushes/brushes.gd"), "# the project's own copy\n")
	_write(PROJECT.path_join("player.gd"), "extends Node\nvar p: Painter = null\nfunc _ready() -> void:\n\t$Painter.splash()\n\tprint(\"no\")\n\t%Painter.splash()\n")
	_write(PROJECT.path_join("level.tscn"), "[ext_resource path=\"res://eventsheet_addons/painter/painter.gd\"]\n")
	var packs_dir: String = PROJECT.path_join("eventsheet_addons")

	var ok: bool = SUPPORT.pins(P, [
		["a library is a folder holding .gdignore", EventSheetPackLibrary.exists(LIB), true],
		["a folder without .gdignore is no library", EventSheetPackLibrary.exists(PROJECT), false],
		["the library's folders, sorted", EventSheetPackLibrary.folders(LIB),
			PackedStringArray(["brushes", "painter", "palette", "runner", "stamp", "surface"])],
		["@ace_requires entries across a folder, in file order", EventSheetPackLibrary.requirement_entries(LIB.path_join("painter")),
			PackedStringArray(["Surface", "Node2D"])],
		["what a pack needs: the class's folder, then what that folder names, never an engine class",
			EventSheetPackLibrary.needs("painter", LIB), PackedStringArray(["surface", "brushes"])],
		["a pack needing nothing drags nothing", EventSheetPackLibrary.needs("runner", LIB), PackedStringArray()],
		["adding leaves out a folder the project already holds",
			EventSheetPackLibrary.folders_to_add("painter", LIB, packs_dir), PackedStringArray(["painter", "surface"])],
	])

	var copied: Dictionary = EventSheetPackLibrary.copy_into_project(PackedStringArray(["painter", "brushes"]), LIB, packs_dir)
	ok = SUPPORT.pins(P, [
		["the copy says what it copied and what it kept", [copied["ok"], copied["copied"], copied["kept"]],
			[true, PackedStringArray(["painter"]), PackedStringArray(["brushes"])]],
		["a folder already there is never overwritten",
			FileAccess.get_file_as_string(packs_dir.path_join("brushes/brushes.gd")), "# the project's own copy\n"],
		["the copy carries the script and its sidecar, not Godot's import file",
			[FileAccess.file_exists(packs_dir.path_join("painter/painter.gd")),
				FileAccess.get_file_as_string(packs_dir.path_join("painter/painter.gd.uid")),
				FileAccess.file_exists(packs_dir.path_join("painter/icon.svg.import"))],
			[true, "uid://painter1\n", false]],
		["a folder the library lacks is refused by name",
			EventSheetPackLibrary.copy_into_project(PackedStringArray(["nowhere"]), LIB, packs_dir)["ok"], false],
		["the trash never takes a path that leaves the packs folder",
			EventSheetPackLibrary.send_to_trash("../player.gd", packs_dir), ERR_INVALID_PARAMETER],
		["the trash says when there is no such folder", EventSheetPackLibrary.send_to_trash("ghost", packs_dir), ERR_DOES_NOT_EXIST],
	]) and ok

	# A project pack nobody uses that reads the project's own Brushes: both are unused, together.
	_write(packs_dir.path_join("brush_user/brush_user.gd"), "class_name BrushUser\nextends Node\nvar brushes: BrushSet = null\n")
	_write(packs_dir.path_join("brushes/brushes.gd"), "class_name BrushSet\nextends Resource\n")
	var corpus: Array[Dictionary] = EventSheetPackLibrary.usage_corpus(PROJECT)
	var tidy_lines: PackedStringArray = PackedStringArray()
	for row: Dictionary in EventSheetPackLibrary.tidy_rows([{"dir": "brush_user", "name": "Brush User"},
			{"dir": "brushes", "name": "Brushes"}, {"dir": "painter", "name": "Painter"}], corpus, LIB, packs_dir):
		tidy_lines.append("%s: %s%s" % [row["name"], EventSheetPackLibrary.used_by_text(row["users"]),
			"" if bool(row["in_library"]) else " (own)"])
	ok = SUPPORT.check(P, "Tidy: a pack read only by a pack nothing uses is unused too, and a used one names its files",
		tidy_lines, PackedStringArray(["Brush User: unused (own)", "Brushes: unused", "Painter: used by level.tscn, player.gd"])) and ok
	var painter_users: Array[Dictionary] = EventSheetPackLibrary.users("painter", corpus, packs_dir)
	var shown: Array = []
	for entry: Dictionary in painter_users:
		shown.append("%s:%d" % [str(entry["path"]).get_file(), int(entry["rows"])])
	ok = SUPPORT.pins(P, [
		["a sheet's rows naming the class or its node, and a scene naming the folder", shown, ["level.tscn:1", "player.gd:3"]],
		["nobody uses a pack nothing names", EventSheetPackLibrary.users("brush_user", corpus, packs_dir).size(), 0],
		["the Tidy line for an unused pack", EventSheetPackLibrary.used_by_text([]), "unused"],
		["the Tidy line for a used one names the files", EventSheetPackLibrary.used_by_text(painter_users), "used by level.tscn, player.gd"],
	]) and ok

	var library_packs: Array[Dictionary] = EventSheetPackLibrary.packs(LIB, packs_dir)
	var states: Dictionary = {}
	for pack: Dictionary in library_packs:
		states[str(pack["dir"])] = str(pack["state"])
	var kit_lines: PackedStringArray = PackedStringArray()
	for kit: Dictionary in EventSheetPackLibrary.kits(library_packs):
		kit_lines.append("%s: %s" % [kit["tag"], ", ".join(kit["names"])])
	var found: PackedStringArray = PackedStringArray()
	for hit: Dictionary in EventSheetPackLibrary.search("dash", LIB, packs_dir):
		found.append("%s · %s" % [hit["name"], hit["said"]])
	ok = SUPPORT.pins(P, [
		["a library pack the project holds is marked so", [states.get("painter"), states.get("runner")], ["project", "library"]],
		["kits: a tag four packs share, once for the same four (drawing and visual are one kit), never a data pack", kit_lines,
			PackedStringArray(["drawing: Brushes, Painter, Stamp, Surface"])],
		["the library search reads an action's name", found, PackedStringArray(["Runner · Is Dashing"])],
		["the library search never offers what the project holds", EventSheetPackLibrary.search("splash", LIB, packs_dir).size(), 0],
		["the folders every kit copies, once each, minus what is there",
			EventSheetPackLibrary.kit_folders(EventSheetPackLibrary.kits(library_packs), LIB, packs_dir),
			PackedStringArray(["surface", "stamp"])],
	]) and ok

	# The editor's two-step copy: everything but the scripts first, then the scripts.
	_write(LIB.path_join("runner/icon.svg"), "<svg/>")
	_write(LIB.path_join("runner/runner.gd.uid"), "uid://runner1\n")
	EventSheetPackLibrary.copy_into_project(PackedStringArray(["runner"]), LIB, packs_dir, true)
	var first_step: Array = [FileAccess.file_exists(packs_dir.path_join("runner/icon.svg")),
		FileAccess.file_exists(packs_dir.path_join("runner/runner.gd")), FileAccess.file_exists(packs_dir.path_join("runner/runner.gd.uid"))]
	EventSheetPackLibrary.copy_scripts(PackedStringArray(["runner"]), LIB, packs_dir)
	ok = SUPPORT.pins(P, [
		["the first step copies the pictures and holds the scripts back", first_step, [true, false, false]],
		["the second step brings the scripts and their uid", [FileAccess.file_exists(packs_dir.path_join("runner/runner.gd")),
			FileAccess.get_file_as_string(packs_dir.path_join("runner/runner.gd.uid"))], [true, "uid://runner1\n"]],
	]) and ok

	# The real library, beside the plugin.
	ok = SUPPORT.pins(P, [
		["the plugin carries its library, invisible to Godot", EventSheetPackLibrary.exists(), true],
		["the library is the shipped packs, byte for byte (run tools/build_library.gd)",
			LIBRARY_BUILD.drift(LIBRARY_BUILD.SOURCE_ROOT, EventSheetPackLibrary.LIBRARY_ROOT, PackedStringArray(SHIPPED.FOLDERS), false),
			PackedStringArray()],
		["the mirror gate names a stale file", LIBRARY_BUILD.drift(LIB, PROJECT, PackedStringArray(["painter"]), false).has("painter/painter.gd"), true],
	]) and ok
	_clear(ROOT)
	EventSheetPackLibrary.forget()
	return ok


static func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for child: String in DirAccess.get_directories_at(path):
		_clear(path.path_join(child))
	DirAccess.remove_absolute(path)
