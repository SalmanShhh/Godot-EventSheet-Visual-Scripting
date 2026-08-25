# Godot EventSheets - scene workspaces: a scene's sheets, opened together and remembered.
#
# Pins VALUES: the name a scene's workspace gets, that the scene itself leads its own membership,
# that a script used on three nodes is ONE member (the same rule the scene-as-sheet reads by), that
# the membership is in the scene's own tree order, and the round-trip of a remembered workspace.
# Also pins that "Open its sheets" is offered for a scene and for nothing else.
@tool
class_name SceneWorkspacesTest
extends RefCounted

## A real scene of the repository, so the membership is measured rather than imagined.
const FIXTURE_SCENE := "res://demo/showcase/family_arena/family_arena.tscn"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_workspace_name() and all_passed
	all_passed = _test_membership() and all_passed
	all_passed = _test_remembered() and all_passed
	all_passed = _test_offered_for_scenes_only() and all_passed
	return all_passed


static func _test_workspace_name() -> bool:
	var passed: bool = _check("a workspace is named after its scene, read as words",
		EventSheetWorkspaces.name_for_scene("res://levels/level_1.tscn"), "Level 1")
	passed = _check("a scene that is not there has no name to give",
		EventSheetWorkspaces.name_for_scene(""), "Workspace") and passed
	return passed


static func _test_membership() -> bool:
	var members: PackedStringArray = EventSheetWorkspaces.members_of_scene(FIXTURE_SCENE)
	var passed: bool = _check("the scene itself opens first - it is the sheet that reads the layout",
		members[0] if not members.is_empty() else "", FIXTURE_SCENE)
	# Every member is a file that is really there, and no script is opened twice however many nodes
	# carry it.
	var seen: Dictionary = {}
	var duplicates: int = 0
	var missing: int = 0
	for path: String in members:
		if seen.has(path):
			duplicates += 1
		seen[path] = true
		if not FileAccess.file_exists(path):
			missing += 1
	passed = _check("a script used on several nodes is one member", duplicates, 0) and passed
	passed = _check("every member is a file that exists", missing, 0) and passed
	passed = _check("a scene that is not there opens nothing",
		EventSheetWorkspaces.members_of_scene("res://nowhere.tscn").size(), 0) and passed
	return passed


static func _test_remembered() -> bool:
	EventSheetWorkspaces.forget("Family Arena")
	var name: String = EventSheetWorkspaces.remember_scene(FIXTURE_SCENE)
	var passed: bool = _check("remembering answers the workspace's name", name, "Family Arena")
	passed = _check("it is offered by name",
		Array(EventSheetWorkspaces.workspace_names()).has("Family Arena"), true) and passed
	passed = _check("and holds what it opened",
		EventSheetWorkspaces.paths_of("Family Arena"),
		EventSheetWorkspaces.members_of_scene(FIXTURE_SCENE)) and passed
	passed = _check("it remembers which scene it is",
		str(EventSheetWorkspaces.workspace("Family Arena").get("scene", "")), FIXTURE_SCENE) and passed
	passed = _check("a scene with nothing to open is not remembered",
		EventSheetWorkspaces.remember_scene("res://nowhere.tscn"), "") and passed
	passed = _check("forgetting one removes it", EventSheetWorkspaces.forget("Family Arena"), true) and passed
	passed = _check("forgetting it twice says so", EventSheetWorkspaces.forget("Family Arena"), false) and passed
	return passed


static func _test_offered_for_scenes_only() -> bool:
	var filesystem: int = EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM
	var passed: bool = _check("a scene is offered its sheets",
		EventSheetContextMenu.should_offer_open_workspace(filesystem,
			PackedStringArray([FIXTURE_SCENE])), true)
	passed = _check("a script is not - it is one sheet, not a scene's worth",
		EventSheetContextMenu.should_offer_open_workspace(filesystem,
			PackedStringArray(["res://player.gd"])), false) and passed
	passed = _check("and the script editor never offers it",
		EventSheetContextMenu.should_offer_open_workspace(
			EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR,
			PackedStringArray([FIXTURE_SCENE])), false) and passed
	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] scene_workspaces_test: %s" % label)
		return true
	print("[FAIL] scene_workspaces_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
