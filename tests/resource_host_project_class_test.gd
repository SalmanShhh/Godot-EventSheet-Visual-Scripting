# Godot EventSheets - a sheet may extend a class of the project that extends Resource.
#
# THE ONE THING THIS FILE IS ABOUT: the engine's own class list knows AudioStream and Texture2D are data
# assets, but a class the project wrote (a card base, a stat block) is known only to the project's list of
# global classes. A sheet that extends one is a data asset too, and its members are fields of that asset,
# not variables of an object in a scene. Before this, such a sheet fell back to a plain Resource host.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME: String = "resource_host_project_class"


static func run() -> bool:
	var project_resource: String = ""
	var project_node: String = ""
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if project_resource.is_empty() and str(entry.get("base")) == "Resource":
			project_resource = str(entry.get("class"))
		if project_node.is_empty() and str(entry.get("base")) in ["Node", "Node2D", "CharacterBody2D"]:
			project_node = str(entry.get("class"))
	return SUPPORT.pins(TEST_NAME, [
		["the project has a class that extends Resource to ask about", project_resource.is_empty(), false],
		["a sheet extending it is a Custom Resource sheet", EventSheetScriptIntent.is_resource_host(project_resource), true],
		["and its members read as fields", EventSheetVariableSentence.is_resource_host(project_resource), true],
		["a class of the project that extends a node is not a resource", [project_node.is_empty(), EventSheetScriptIntent.is_resource_host(project_node)], [false, false]],
		["a name nobody has heard of is not a resource", [EventSheetScriptIntent.is_resource_host("NoSuchClassAnywhere"), EventSheetVariableSentence.is_resource_host("NoSuchClassAnywhere")], [false, false]],
		["the engine's own answers are unchanged", [EventSheetScriptIntent.is_resource_host("Resource"), EventSheetScriptIntent.is_resource_host("AudioStream"), EventSheetScriptIntent.is_resource_host("Node")], [true, true, false]]
	])
