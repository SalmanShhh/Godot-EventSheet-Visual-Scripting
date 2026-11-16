# Godot EventSheets - the two doors between a Juice Player's rows and its cards (editor-only, loaded by path).
#
# The rows that play a Juice Player live in a sheet, the cards they play live on a node in a scene, and a
# person debugging a beat has to go from one to the other by hand. These are the two doors:
#
#   "Show its cards"        a menu entry on the action of a row that plays a player. It opens the scene the
#                           sheet runs in, selects that player and leaves the Inspector on its list.
#   "Find what plays this"  the strip under a player's list asks which sheets of the project play it, and
#                           offers each one to open.
#
# Neither draws anything in a sheet row: the entry is part of the row's menu, which is where an action's
# own commands already are, and the strip is Inspector chrome. The dock loads this file by path at the
# right-click, so the first open of the editor does not compile it.
#
# No class_name on purpose: Create Node lists every named class, and an editor-only helper has no business there.
@tool
extends RefCounted

## The menu id of the entry. Far above the dock's own numbering, so its dispatcher never meets it.
const MENU_ID: int = 9702

## The providers a Juice Player's rows come from: the pack's own name and the old one.
const PROVIDERS: PackedStringArray = ["JuicePlayer", "FeedbackPlayer"]

## The name the workspace goes by in the editor's row of main screens.
const MAIN_SCREEN: String = "EventSheet"

## The rows that play the list on the node the row names.
const PLAY_IDS: PackedStringArray = ["play", "play_and_wait", "play_backwards"]


## Whether a row plays a Juice Player of the scene its sheet runs in. The filter of the row menu's entry.
static func offers_for_row(row: Resource) -> bool:
	return not player_for_row(row).is_empty()


## The entry's action: shows the cards of the player the row plays.
static func show_for_row(row: Resource) -> void:
	var dock: Object = load("res://addons/eventsheet/api/eventsheets.gd").get("_dock")
	var player_name: String = player_for_row(row)
	if dock != null and not player_name.is_empty():
		show_cards(dock as Control, player_name)


## The player a row plays: through an action it holds, or through the lines of code it is made of.
static func player_for_row(row: Resource) -> String:
	var dock: Object = load("res://addons/eventsheet/api/eventsheets.gd").get("_dock")
	if dock == null or row == null:
		return ""
	var players: PackedStringArray = players_of_sheet(dock.get("_current_sheet") as EventSheetResource)
	if row is EventRow:
		for action: Variant in (row as EventRow).actions:
			var found: String = player_name_of(action as Resource, players)
			if not found.is_empty():
				return found
	elif row is RawCodeRow:
		for named: String in names_in_code(str((row as RawCodeRow).code)):
			if players.has(named):
				return named
	return ""


## The nodes a block of code plays, in the order it plays them: every `$Name.play(`, `$Name.play_and_wait(` and
## `$Name.play_backwards(` it holds.
static func names_in_code(code: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for line: String in code.split("\n"):
		var written: String = line.strip_edges().trim_prefix("await ").strip_edges()
		var named: String = _node_of_call(written)
		var verb: String = written.substr(written.find(".") + 1).get_slice("(", 0) if written.contains(".") else ""
		if not named.is_empty() and PLAY_IDS.has(verb) and not names.has(named):
			names.append(named)
	return names


## Adds the entry to the action menu when the right-clicked action plays a player, and takes it away
## again when it does not, so no other action carries a command it cannot use. The listener is connected
## once, on the first time the entry is offered. The row menu carries the same entry, registered by the door file.
static func refresh(dock: Control, menu: PopupMenu) -> void:
	var existing: int = menu.get_item_index(MENU_ID)
	if existing >= 0:
		menu.remove_item(existing)
	var action: Resource = dock._row_edit_ops._context_ace_resource("action")
	var player_name: String = player_name_of(action, players_of_sheet(dock._current_sheet))
	if player_name.is_empty():
		return
	menu.add_item(EventSheetL10n.translate("Show its cards"), MENU_ID)
	menu.set_item_tooltip(menu.get_item_index(MENU_ID),
		EventSheetL10n.translate("Opens the scene this sheet runs in and selects the Juice Player this row plays, so its cards are in the Inspector."))
	menu.set_item_metadata(menu.get_item_index(MENU_ID), player_name)
	if not menu.has_meta(&"juice_show_cards_wired"):
		menu.set_meta(&"juice_show_cards_wired", true)
		menu.id_pressed.connect(func(id: int) -> void:
			if id == MENU_ID:
				var at: int = menu.get_item_index(MENU_ID)
				if at >= 0:
					show_cards(dock, str(menu.get_item_metadata(at))))


## The Juice Players the scene this sheet runs in holds, by name. Empty when no scene runs the sheet.
static func players_of_sheet(sheet: EventSheetResource) -> PackedStringArray:
	var script_path: String = str(sheet.external_source_path) if sheet != null else ""
	var scenes: PackedStringArray = EventSheetSceneReplication.scenes_using(script_path) if not script_path.is_empty() else PackedStringArray()
	if scenes.is_empty():
		return PackedStringArray()
	return load("res://addons/eventsheet/editor/interaction/juice_card_targets.gd").call("players_in_scene", scenes[0])


## The name of the node a row plays, or empty when the row does not play a Juice Player. A row of the pack
## keeps the node it addresses in its call (`$HitJuice.play(1.0)`). A line written by hand reopens as a
## plainer row that keeps the node in its own words, so that one counts only when the scene the sheet runs in
## holds a Juice Player of that name: the scene is the evidence, never the spelling.
static func player_name_of(action: Resource, players: PackedStringArray = PackedStringArray()) -> String:
	if action == null:
		return ""
	if PROVIDERS.has(str(action.get("provider_id"))) and PLAY_IDS.has(str(action.get("ace_id"))):
		return _node_of_call(str(action.get("codegen_template")))
	var params: Variant = action.get("params")
	if not (params is Dictionary):
		return ""
	var spoken: String = str((params as Dictionary).get("signal_expression", ""))
	if spoken.is_empty():
		spoken = "%s.play" % str((params as Dictionary).get("target", ""))
	var name: String = _node_of_call(spoken)
	var verb: String = spoken.substr(spoken.find(".") + 1).get_slice("(", 0) if spoken.contains(".") else ""
	return name if players.has(name) and PLAY_IDS.has(verb) else ""


## The node a call is made on: `$HitJuice.play(1.0)` and `await $HitJuice.play_and_wait(1.0)` both say HitJuice.
static func _node_of_call(call_text: String) -> String:
	var call: String = call_text.strip_edges()
	if call.begins_with("await "):
		call = call.trim_prefix("await ").strip_edges()
	if not call.begins_with("$") or not call.contains("."):
		return ""
	return call.trim_prefix("$").get_slice(".", 0)


## Opens the scene the sheet runs in (unless it is the one open) and selects the player named, so the
## Inspector shows its cards. Says in the status line what it could not do.
static func show_cards(dock: Control, player_name: String) -> void:
	var sheet: EventSheetResource = dock._current_sheet
	var script_path: String = str(sheet.external_source_path) if sheet != null else ""
	var scenes: PackedStringArray = EventSheetSceneReplication.scenes_using(script_path) if not script_path.is_empty() else PackedStringArray()
	if scenes.is_empty():
		dock._set_status(EventSheetL10n.translate("No scene runs this sheet, so there is no list to show."))
		return
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if scene_root == null or scene_root.scene_file_path != scenes[0]:
		EditorInterface.open_scene_from_path(scenes[0])
		scene_root = EditorInterface.get_edited_scene_root()
	var player: Node = null
	if scene_root != null:
		player = scene_root if scene_root.name == player_name else scene_root.find_child(player_name, true, false)
	if player == null:
		dock._set_status(EventSheetL10n.translate("%s has no node called %s.") % [scenes[0].get_file(), player_name])
		return
	# The dock follows a node picked in the Scene dock and offers to filter the sheet to it. This pick is ours,
	# so the follow is told to treat its echo as ours: the line the reader sees is the true one, and no offer
	# (and no filter) appears.
	var link: Object = dock.call("_ensure_scene_link")
	var label: String = str(link.call("object_label_for_node", EventSheetViewportReadingRows.object_census(sheet), str(player.name), player.get_class()))
	if not label.is_empty():
		link.set("_driven_label", label)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(player)
	EditorInterface.edit_node(player)
	dock._set_status(EventSheetL10n.translate("Showing the cards of %s.") % player_name)


## The sheets of the project that play a player of this name, in path order.
static func sheets_playing(player_name: String) -> PackedStringArray:
	return sheets_in(EventSheetProjectDoctor._project_scripts(), player_name)


## The paths among `corpus` whose code plays the player called `player_name`. Pure over a list of paths, so a
## test can hand it one.
static func sheets_in(corpus: PackedStringArray, player_name: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if player_name.strip_edges().is_empty():
		return found
	var call: String = "$%s." % player_name
	for path: String in corpus:
		if FileAccess.get_file_as_string(path).contains(call + "play"):
			found.append(path)
	return found


## Opens one of those sheets in the editor. The workspace is brought forward first, which is what builds it
## the first time, so the sheet is taken whether or not the workspace was ever opened. True when the editor
## took the sheet.
static func open_sheet(path: String) -> bool:
	EditorInterface.set_main_screen_editor(MAIN_SCREEN)
	return bool(load("res://addons/eventsheet/api/eventsheets.gd").call("open_sheet", path))
