# Godot EventSheets - what the behaviour library's windows say, pinned by value.
#
# The Behaviour library window (a row's line naming what comes along, the one line said after an add),
# the sentence an add leaves, the Remove from project… warning, Tidy behaviours' summary and
# button, the Welcome's kit line, the Doctor's door on the unused-packs note, and the window itself
# built over the real library: the packs the project lacks listed, "In this project" listing the
# held ones instead, and the one button's words for each.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const DIALOG := preload("res://addons/eventsheet/editor/behaviour_library_window.gd")
const FLOW := preload("res://addons/eventsheet/editor/dock/behaviour_library_flow.gd")
const WELCOME := preload("res://addons/eventsheet/editor/dock/welcome_window.gd")
const P := "behaviour_library_windows_test"


static func run() -> bool:
	var library_pack: Dictionary = {"dir": "drawing_canvas", "state": "library"}
	var own_pack: Dictionary = {"dir": "health", "state": "project"}
	var ok: bool = SUPPORT.pins(P, [
		["a row names what else the pack brings, in names", DIALOG.needs_line("drawing_canvas", EventSheetPackLibrary.LIBRARY_ROOT, "user://behaviour_library_windows_test_none"),
			"Also adds Canvas Surface and Drawing Prefab Resource."],
		["a pack needing nothing says so on its row", DIALOG.needs_line("wrap", EventSheetPackLibrary.LIBRARY_ROOT, "user://behaviour_library_windows_test_none"),
			"Nothing else comes with it."],
		["a needed folder the project holds is not listed again", DIALOG.needs_line("drawing_prefab_stamp"), "Nothing else comes with it."],
		["after an add the window says where it goes next", DIALOG.added_next_step(),
			"Now add it with Add Child Node (Ctrl+A) under the node it should act on."],
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
		["nobody using a pack warns of nothing", FLOW.remove_warning([]), {"heading": "", "lines": PackedStringArray(), "after": ""}],
		["two sheets using a pack", FLOW.remove_warning([{"path": "res://player.gd", "rows": 3}, {"path": "res://tiles.gd", "rows": 1}]),
			{"heading": "Used by 2 sheets", "lines": PackedStringArray(["player.gd · 3 rows", "tiles.gd · 1 row"]),
				# What is true of a .gd sheet too: no row is marked missing and no check lists them.
				"after": "Those rows stay as written, and they need it back to run."}],
		["a scene among the users makes them files", str(FLOW.remove_warning([{"path": "res://player.gd", "rows": 2}, {"path": "res://level.tscn", "rows": 1}])["heading"]),
			"Used by 2 files"],
		["Tidy behaviours says what it holds and what is unused", FLOW.tidy_summary(140, 133),
			"This project holds 140 behaviours. No sheet uses 133 of them. Ticked ones go to the trash and stay in the library."],
		["Tidy behaviours' button counts the ticked", FLOW.tidy_button_text(133), "Remove 133 unused"],
		["a long kit names five, then counts the rest", WELCOME.kit_list_text(PackedStringArray(["A", "B", "C", "D", "E", "F", "G"])),
			"A, B, C, D, E and 2 more"],
		["a short kit names every pack", WELCOME.kit_list_text(PackedStringArray(["A", "B"])), "A, B"],
		["the Welcome's line with nothing ticked", WELCOME.kit_summary(0), "Nothing will be added."],
		# A kit is titled as a kind of game, never shown as the bare tag; a tag with no title is not offered.
		["the Welcome's kits are titled, and an untitled tag is not offered",
			WELCOME.titled_kits([{"tag": "3d", "dirs": PackedStringArray(["a", "b", "c", "d"])},
				{"tag": "resource", "dirs": PackedStringArray(["a", "b", "c", "d"])},
				{"tag": "idle", "dirs": PackedStringArray(["e", "f", "g", "h"])}]).map(func(kit: Dictionary) -> Array:
					return [kit["tag"], kit["title"]]),
			[["3d", "A 3D game"], ["idle", "An idle or clicker game"]]],
		# The window fits a 1600x1100 editor: content 1200 tall with 1000 of room gives up 200 of the
		# kits' 220, and never more than down to the shortest.
		["the kits' scroll gives up what the window stands too tall", WELCOME.kit_scroll_height(1000.0, 1200.0, 220.0, 72.0), 72.0],
		["it gives up only that much", WELCOME.kit_scroll_height(1000.0, 1100.0, 220.0, 72.0), 120.0],
		["a window that fits keeps its kits' full height", WELCOME.kit_scroll_height(1000.0, 900.0, 220.0, 72.0), 220.0],
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

	# The window over the real library, handed the library as a project that holds none of them would
	# see it: every pack is a row, the button adds, and "In this project" lists nothing to add.
	var dialog: ConfirmationDialog = DIALOG.new()
	var empty: Array[Dictionary] = []
	dialog._packs = EventSheetPackLibrary.combined(empty,
		EventSheetPackLibrary.packs(EventSheetPackLibrary.LIBRARY_ROOT, "user://behaviour_library_windows_test_none"))
	dialog._rebuild_list()
	var waiting: int = EventSheetPackLibrary.folders().size()
	var listed: int = dialog.rows().size()
	var first_pack: String = str(dialog.rows()[0].get_meta("pack_dir")) if listed > 0 else ""
	var add_words: Array = [dialog.get_ok_button().text, dialog.get_ok_button().disabled]
	var needs_on_row: bool = false
	for label: Node in dialog.rows()[0].find_children("*", "Label", true, false):
		needs_on_row = needs_on_row or (label as Label).text.begins_with("Also adds") or (label as Label).text == "Nothing else comes with it."
	dialog._search.text = "zzz-no-such-pack"
	dialog._filter()
	var hidden_by_search: int = dialog.rows().filter(func(row: Button) -> bool: return not row.visible).size()
	var empty_words: String = dialog._no_match.text
	dialog._search.text = ""
	dialog._scope_held.button_pressed = true
	dialog._selected_dir = ""
	dialog._rebuild_list()
	# The held scope lists the packs marked "project" - none, here.
	var held_rows: int = dialog.rows().size()
	var remove_words: String = dialog.get_ok_button().text
	ok = SUPPORT.pins(P, [
		["the library holds every shipped pack", waiting, preload("res://addons/eventforge/shipped_pack_folders.gd").FOLDERS.size()],
		["every library pack the project lacks has a row", listed, waiting],
		["the first row is selected, so the button has something to act on", [first_pack.is_empty(), add_words], [false, ["Add to project", false]]],
		["a row says what else comes with its pack", needs_on_row, true],
		["a search that matches nothing hides every row and says so", [hidden_by_search, empty_words], [waiting, "No behaviour here matches that."]],
		["In this project lists none of them (none is held)", held_rows, 0],
		["its button says Remove from project…", remove_words, "Remove from project…"],
	]) and ok
	dialog.free()
	ok = _test_adding_under_a_node() and ok
	return ok


## What Godot's Create Node window hands back lands under the node: a behaviour's script path becomes
## the pack's node, a built-in type name becomes that node, and a node that is not in the scene is said
## in the status line with nothing added.
static func _test_adding_under_a_node() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	var host: Node2D = Node2D.new()
	host.name = "Player"
	dock.add_behaviour_node(host, "res://eventsheet_addons/sine/sine_behavior.gd")
	dock.add_behaviour_node(host, "Timer")
	dock.add_behaviour_node(host, "SineBehavior")
	var kids: Array = host.get_children().map(func(child: Node) -> Array:
		return [str(child.name), child.get_class(), child.get_script() != null, child.owner == host])
	dock.open_add_behavior_dialog("Ghost")
	var said: String = dock._status_label.text.trim_prefix("⚠  ")
	var pins: Array = [
		["a behaviour's script path becomes its node under the object", kids[0], ["Sine", "Node", true, true]],
		["a built-in type name becomes that node", kids[1], ["Timer", "Timer", false, true]],
		["a script class named by its class_name is found too", kids[2][1], "Node"],
		["a node that is not in the open scene is said, and nothing is added", said,
			"Ghost is not in the open scene, so there is nothing to add a behaviour to. Open its scene first."],
	]
	host.free()
	dock.free()
	return SUPPORT.pins(P, pins)
