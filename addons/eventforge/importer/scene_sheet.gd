# EventForge - a whole SCENE opened as one sheet (P4).
#
# An event sheet belongs to a layout; a Godot scene has several scripts, one per node that carries
# one. Opening the scene builds the reading of the whole layout in one place: the scene's own bar,
# then every script the scene uses - in tree order, each under its own object bar - with the rows the
# ordinary opened-script reading already produces beneath it.
#
# THE SCENE FILE IS NEVER TOUCHED, AND NOTHING IS EVER EMITTED FOR IT. The composite sheet is read
# only and stays that way: it has no single file to compile back to, so Save has nothing to write and
# the preview banner offers no unlock. Editing happens per script - double-click an object bar and
# that file opens as its own sheet, exactly as it would from the FileSystem.
#
# Every member sheet is held on the composite (`__scene_members`), because the rows reference those
# resources for their whole lifetime: dropping them would leave the view pointing at freed sheets.
@tool
class_name EventSheetSceneSheet
extends RefCounted

## The scene a composite sheet was built from, and the per-script members under it.
const SCENE_PATH_META: String = "__scene_sheet_path"
const MEMBERS_META: String = "__scene_members"
## Stamped on each MEMBER sheet, so its Include bar reads as the object bar of the node that carries
## it ("HUD a CanvasLayer") rather than as the script's own identity.
const OBJECT_BAR_META: String = "__scene_object_bar"


## The composite sheet for one .tscn, with every script already read. Null when the file cannot be
## read. Used by anything that wants the whole answer at once (tests, headless); the editor opens the
## shell first and reads one script per frame, so a big scene never freezes it.
static func build(scene_path: String) -> EventSheetResource:
	var sheet: EventSheetResource = build_shell(scene_path)
	if sheet == null:
		return null
	while load_next_member(sheet):
		pass
	return sheet


## The composite with its members LISTED but not yet read: the scene bar and every object bar paint
## immediately, and each script's rows arrive as it is read.
static func build_shell(scene_path: String) -> EventSheetResource:
	var path: String = scene_path.strip_edges()
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var sheet := EventSheetResource.new()
	sheet.read_only = true
	sheet.set_meta(SCENE_PATH_META, path)
	var members: Array = []
	var seen: Dictionary = {}
	for entry: Variant in EventSheetSceneConnections.nodes_of_scene(path):
		var node: Dictionary = entry
		var script_path: String = str(node.get("script_path", ""))
		if script_path.is_empty() or not FileAccess.file_exists(script_path):
			continue
		# One script, one reading: a scene using the same script on three nodes says so on the bar
		# rather than repeating every row three times.
		if seen.has(script_path):
			var already: Dictionary = members[int(seen[script_path])]
			already["instances"] = int(already.get("instances", 1)) + 1
			continue
		seen[script_path] = members.size()
		members.append({
			"node": str(node.get("name", "")),
			"node_path": str(node.get("path", "")),
			"type": str(node.get("type", "")),
			"script_path": script_path,
			"instances": 1,
			"sheet": null
		})
	sheet.set_meta(MEMBERS_META, members)
	sheet.set_meta("__scene_root_type", _root_type(path))
	return sheet


## Reads the next script of the scene. True while there is still one left after this, so a caller can
## drive it one per frame; false when the scene is fully read.
static func load_next_member(sheet: EventSheetResource) -> bool:
	if sheet == null:
		return false
	var scene_path: String = scene_path_of(sheet)
	var members: Array = members_of(sheet)
	for entry: Variant in members:
		var member: Dictionary = entry
		if not _is_unread(member):
			continue
		var member_sheet: EventSheetResource = _import_member(str(member.get("script_path", "")), scene_path,
			str(member.get("node", "")), str(member.get("type", "")), int(member.get("instances", 1)))
		member["sheet"] = member_sheet
		# A script that cannot be read is marked read anyway: leaving it unread would hand the caller
		# the same member forever, and a driver that reads one per frame would never stop.
		member["unreadable"] = member_sheet == null
		return pending_members(sheet) > 0
	return false


## How many scripts of the scene are still unread - what the progress strip counts.
static func pending_members(sheet: EventSheetResource) -> int:
	var pending: int = 0
	for entry: Variant in members_of(sheet):
		if _is_unread(entry as Dictionary):
			pending += 1
	return pending


static func _is_unread(member: Dictionary) -> bool:
	return member.get("sheet") == null and not bool(member.get("unreadable", false))


## True for a sheet built by this module. The dock asks before every write path: a composite sheet
## has no file of its own, so Save, Save As and the preview unlock are all refused on it.
static func is_scene_sheet(sheet: EventSheetResource) -> bool:
	return sheet != null and sheet.has_meta(SCENE_PATH_META)


static func scene_path_of(sheet: EventSheetResource) -> String:
	return str(sheet.get_meta(SCENE_PATH_META, "")) if sheet != null else ""


## The per-script members, in tree order: {node, node_path, type, script_path, instances, sheet}.
static func members_of(sheet: EventSheetResource) -> Array:
	return (sheet.get_meta(MEMBERS_META, []) as Array) if sheet != null else []


## The class of the scene's root node, for the scene bar.
static func root_type_of(sheet: EventSheetResource) -> String:
	return str(sheet.get_meta("__scene_root_type", "")) if sheet != null else ""


## The node the object bar of ONE member names, as {node, type, script_path, instances}, or {} for a
## sheet opened on its own.
static func object_bar_of(sheet: EventSheetResource) -> Dictionary:
	return (sheet.get_meta(OBJECT_BAR_META, {}) as Dictionary) if sheet != null else {}


## One script of the scene, read exactly as opening that file would read it.
static func _import_member(script_path: String, scene_path: String, node_name: String,
		node_type: String, instances: int = 1) -> EventSheetResource:
	var previous_scope: String = EventSheetSceneConnections.scene_scope
	EventSheetSceneConnections.scene_scope = scene_path
	var member: EventSheetResource = GDScriptImporter.new().import_external(script_path)
	EventSheetSceneConnections.scene_scope = previous_scope
	if member == null:
		return null
	member.read_only = true
	member.set_meta(OBJECT_BAR_META, {
		"node": node_name,
		"type": node_type,
		"script_path": script_path,
		"instances": instances
	})
	return member


static func _root_type(scene_path: String) -> String:
	var nodes: Array = EventSheetSceneConnections.nodes_of_scene(scene_path)
	if nodes.is_empty():
		return ""
	return str((nodes[0] as Dictionary).get("type", ""))
