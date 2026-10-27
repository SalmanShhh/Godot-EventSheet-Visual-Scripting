# Godot EventSheets - what the behaviour library's windows say, pinned by value.
#
# The Add behaviour window (a library tile's line, the card naming what comes along, the Add button's
# words), the sentence an add leaves, the Remove from project… warning, Tidy behaviours' summary and
# button, the Welcome's kit line, the Doctor's door on the unused-packs note, and the window itself
# built over the real library: library packs listed beside the project's, and "In this project"
# hiding them.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const DIALOG := preload("res://addons/eventsheet/editor/add_behavior_dialog.gd")
const FLOW := preload("res://addons/eventsheet/editor/dock/behaviour_library_flow.gd")
const WELCOME := preload("res://addons/eventsheet/editor/dock/welcome_window.gd")
const P := "behaviour_library_windows_test"


static func run() -> bool:
	var library_pack: Dictionary = {"dir": "drawing_canvas", "state": "library"}
	var own_pack: Dictionary = {"dir": "health", "state": "project"}
	var ok: bool = SUPPORT.pins(P, [
		["a library tile says it waits in the library", DIALOG.tile_state_line("Node2D", library_pack), "Node2D · Library"],
		["a project tile says it is in the project", DIALOG.tile_state_line("Any node", own_pack), "Any node · In project"],
		["a library pack is told from a project one", [DIALOG.is_library_pack(library_pack), DIALOG.is_library_pack(own_pack)], [true, false]],
		["the card names the folders @ace_requires drags along", DIALOG.library_needs_text("drawing_canvas", EventSheetPackLibrary.LIBRARY_ROOT, "user://behaviour_library_windows_test_none"),
			"canvas_surface/\ndrawing_prefab_resource/"],
		["a pack needing nothing says so", DIALOG.library_needs_text("wrap", EventSheetPackLibrary.LIBRARY_ROOT, "user://behaviour_library_windows_test_none"),
			"Nothing else."],
		["the card marks a needed folder the project already holds", DIALOG.library_needs_text("drawing_prefab_stamp"),
			"drawing_prefab_resource/  (already in the project)"],
		["an add with what it needed", FLOW.added_sentence("Drawing Canvas", PackedStringArray(["Canvas Surface", "Drawing Prefab Resource"]), 3),
			"Added Drawing Canvas to the project, with Canvas Surface and Drawing Prefab Resource it needs. Godot imported 3 folders."],
		["an add on its own", FLOW.added_sentence("Wrap", PackedStringArray(), 1), "Added Wrap to the project. Godot imported 1 folder."],
		["three needed packs read as a list", FLOW._and_list(PackedStringArray(["A", "B", "C"])), "A, B and C"],
		["nobody using a pack warns of nothing", FLOW.remove_warning([]), {"heading": "", "lines": PackedStringArray()}],
		["two sheets using a pack", FLOW.remove_warning([{"path": "res://player.gd", "rows": 3}, {"path": "res://tiles.gd", "rows": 1}]),
			{"heading": "Used by 2 sheets", "lines": PackedStringArray(["player.gd · 3 rows", "tiles.gd · 1 row"])}],
		["a scene among the users makes them files", str(FLOW.remove_warning([{"path": "res://player.gd", "rows": 2}, {"path": "res://level.tscn", "rows": 1}])["heading"]),
			"Used by 2 files"],
		["Tidy behaviours says what it holds and what is unused", FLOW.tidy_summary(140, 133),
			"This project holds 140 behaviours. No sheet uses 133 of them. Ticked ones go to the trash and stay in the library."],
		["Tidy behaviours' button counts the ticked", FLOW.tidy_button_text(133), "Remove 133 unused"],
		["a long kit names five, then counts the rest", WELCOME.kit_list_text(PackedStringArray(["A", "B", "C", "D", "E", "F", "G"])),
			"A, B, C, D, E and 2 more"],
		["a short kit names every pack", WELCOME.kit_list_text(PackedStringArray(["A", "B"])), "A, B"],
		["the Welcome's line with nothing ticked", WELCOME.kit_summary(0), "Nothing will be added."],
		["the Welcome's line for several", WELCOME.kit_summary(9), "9 behaviours will be added (shared ones once)."],
		["the unused-packs note opens Tidy behaviours", EventSheetQuickFixes.fixes_for({"check": "unused-pack", "subject": ""}),
			[{"id": "tidy_behaviours", "label": "Tidy behaviours…", "check": "unused-pack"}]],
	])

	# A copied folder's pictures are imported before anything loads them; scripts need no import.
	var folder: String = "user://behaviour_library_windows_test_import"
	DirAccess.make_dir_recursive_absolute(folder.path_join("art"))
	for file_name: String in ["a.gd", "a.gd.uid", "art/icon.svg", "done.png", "done.png.import"]:
		FileAccess.open(folder.path_join(file_name), FileAccess.WRITE).close()
	ok = SUPPORT.check(P, "only a copied file still waiting for its import is imported by hand",
		FLOW.unimported_files(folder), PackedStringArray([folder.path_join("art/icon.svg")])) and ok
	for file_name: String in ["a.gd", "a.gd.uid", "art/icon.svg", "done.png", "done.png.import"]:
		DirAccess.remove_absolute(folder.path_join(file_name))
	DirAccess.remove_absolute(folder.path_join("art"))
	DirAccess.remove_absolute(folder)

	# The window over the real library: every library pack is listed beside the project's own, as a
	# tile that says Library, and "In this project" hides them.
	# This repository's project holds every pack, so the window is handed the library as a project
	# that holds none of them would see it.
	var dialog: ConfirmationDialog = DIALOG.new()
	var empty: Array[Dictionary] = []
	dialog._packs = EventSheetPackLibrary.combined(empty,
		EventSheetPackLibrary.packs(EventSheetPackLibrary.LIBRARY_ROOT, "user://behaviour_library_windows_test_none"))
	dialog._rebuild_list()
	var library_tiles: int = 0
	var shown_library: int = 0
	for tile: Button in dialog.tiles():
		for pack: Dictionary in dialog._packs:
			if str(pack.get("dir", "")) == str(tile.get_meta("pack_dir")) and DIALOG.is_library_pack(pack):
				library_tiles += 1
				shown_library += 1 if tile.visible else 0
	var waiting: int = EventSheetPackLibrary.folders().size()
	dialog._scope_project.button_pressed = true
	dialog._filter_shelves()
	var hidden_library: int = 0
	for tile: Button in dialog.tiles():
		for pack: Dictionary in dialog._packs:
			if str(pack.get("dir", "")) == str(tile.get_meta("pack_dir")) and DIALOG.is_library_pack(pack) and not tile.visible:
				hidden_library += 1
	ok = SUPPORT.pins(P, [
		["the library holds every shipped pack", waiting, preload("res://addons/eventforge/shipped_pack_folders.gd").FOLDERS.size()],
		["every library pack the project lacks has a tile", library_tiles, waiting],
		["All shows them", shown_library, waiting],
		["In this project hides every one of them", hidden_library, waiting],
	]) and ok
	dialog.free()
	return ok
