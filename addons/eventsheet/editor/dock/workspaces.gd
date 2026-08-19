@tool
class_name EventSheetWorkspaces
extends RefCounted
# SCENE WORKSPACES (V15) - the unit of work is the scene, so open it as one.
#
# "Open its sheets" on a scene opens the scene-as-sheet and every script in it, in tree order, as
# one named tab group. The group is remembered as a WORKSPACE (Sheet ▸ Workspaces ▸ Level 1), so
# coming back to that scene is one click rather than five openings, and switching scenes switches
# the group. Tabs stay individually closable - a workspace is a way of opening, never a cage.
#
# The membership is read out of the .tscn's own node order, which is the order the Scene dock shows
# and the order the scene-as-sheet already reads its members in - so a workspace and the composite
# sheet can never disagree about what the scene holds. Nothing is written into the project: the
# named groups live in the editor's own per-project metadata, beside the fold and zoom memories.

const META_SECTION := "eventsheets"
const META_KEY := "workspaces"

## Headless twin of the editor metadata store, so the whole shape is testable without an editor.
static var _memory: Dictionary = {}


## The name a scene's workspace gets: the scene's own file name read as words, so `level_1.tscn`
## is `Level 1`.
static func name_for_scene(scene_path: String) -> String:
	var base: String = scene_path.strip_edges().get_file().get_basename().strip_edges()
	return base.capitalize() if not base.is_empty() else "Workspace"


## Everything "Open its sheets" opens for one scene: the scene itself first (it is the sheet that
## reads the whole layout in one place), then one entry per distinct script in tree order. A script
## used on three nodes is one member, exactly as the scene-as-sheet reads it.
static func members_of_scene(scene_path: String) -> PackedStringArray:
	var members: PackedStringArray = PackedStringArray()
	var path: String = scene_path.strip_edges()
	if path.is_empty() or not FileAccess.file_exists(path):
		return members
	members.append(path)
	var seen: Dictionary = {}
	for entry: Variant in EventSheetSceneConnections.nodes_of_scene(path):
		var script_path: String = str((entry as Dictionary).get("script_path", "")).strip_edges()
		if script_path.is_empty() or seen.has(script_path) or not FileAccess.file_exists(script_path):
			continue
		seen[script_path] = true
		members.append(script_path)
	return members


## Every remembered workspace, name -> `{"scene": String, "paths": PackedStringArray}`.
static func all_workspaces() -> Dictionary:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var stored: Variant = EditorInterface.get_editor_settings().get_project_metadata(META_SECTION, META_KEY, {})
		if stored is Dictionary:
			return (stored as Dictionary).duplicate(true)
	return _memory.duplicate(true)


## The remembered names, sorted, so the menu lists them the same way every time.
static func workspace_names() -> PackedStringArray:
	var names: Array = all_workspaces().keys()
	names.sort()
	var out: PackedStringArray = PackedStringArray()
	for entry: Variant in names:
		out.append(str(entry))
	return out


static func workspace(name: String) -> Dictionary:
	var found: Variant = all_workspaces().get(name.strip_edges(), {})
	return (found as Dictionary) if found is Dictionary else {}


## The paths one workspace holds, in the order it opens them.
static func paths_of(name: String) -> PackedStringArray:
	var stored: Variant = workspace(name).get("paths", PackedStringArray())
	if stored is PackedStringArray:
		return stored as PackedStringArray
	var out: PackedStringArray = PackedStringArray()
	if stored is Array:
		for entry: Variant in (stored as Array):
			out.append(str(entry))
	return out


## Remembers a scene as a named workspace. An empty scene, or one with nothing in it to open, is
## not remembered - a workspace that opens nothing is worse than no workspace.
static func remember_scene(scene_path: String) -> String:
	var members: PackedStringArray = members_of_scene(scene_path)
	if members.is_empty():
		return ""
	var name: String = name_for_scene(scene_path)
	var stored: Dictionary = all_workspaces()
	stored[name] = {"scene": scene_path.strip_edges(), "paths": members}
	_write(stored)
	return name


## Forgets a workspace. False when there was nothing under that name.
static func forget(name: String) -> bool:
	var stored: Dictionary = all_workspaces()
	if not stored.has(name.strip_edges()):
		return false
	stored.erase(name.strip_edges())
	_write(stored)
	return true


static func _write(stored: Dictionary) -> void:
	_memory = stored.duplicate(true)
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_editor_settings().set_project_metadata(META_SECTION, META_KEY, stored)
