# Godot EventSheets - a node dragged from Godot's Scene dock onto the sheet starts an event on it.
#
# The Scene dock sends {type: "nodes", nodes: [NodePath...]}, paths from the tree's root, never nodes.
# Dropped on a param value it fills that param; dropped anywhere else it is the same gesture as the
# same object dragged off the Objects list - so the canvas emits the very signal an Objects-list drag
# emits, with the label that object has there (the sheet's own name for it, else the node's name),
# and the group and needs_key offers read the same node. Pinned with a synthetic payload and a scene
# built in memory; a real drag in the editor is the proof of the gesture itself.
@tool
class_name SceneDockDropTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const OFFERS := preload("res://addons/eventsheet/editor/dock/scene_node_offers.gd")
const P := "scene_dock_drop_test"
const SHEET_PATH := "user://scene_dock_drop_hero.gd"


static func run() -> bool:
	var level: Node = Node.new()
	level.name = "Level"
	var player: Node2D = Node2D.new()
	player.name = "Player"
	level.add_child(player)
	var spring: Node = Node.new()
	spring.name = "Spring"
	spring.add_to_group("secret", true)
	level.add_child(spring)
	var drag: Dictionary = {"type": "nodes", "nodes": ["/root/Level/Player"]}

	# The sheet that already uses the node under a name of its own.
	var file: FileAccess = FileAccess.open(SHEET_PATH, FileAccess.WRITE)
	file.store_string("extends Node2D\n\n@onready var hero: Node2D = $Player\n")
	file.close()
	var hero_sheet: EventSheetResource = EventSheetGDScriptImporter.new().import_external(SHEET_PATH)
	DirAccess.remove_absolute(SHEET_PATH)

	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.drop_scene_root = level
	var landed: Array = []
	viewport.object_bar_dropped.connect(func(label: String, target: Resource, lane: bool) -> void:
		landed.append([label, target, lane]))
	var accepted: Array = [
		viewport._can_drop_data(Vector2(10, 10), drag),
		viewport._can_drop_data(Vector2(10, 10), {"type": "nodes", "nodes": ["/root/Level/NoSuchNode"]}),
		viewport._can_drop_data(Vector2(10, 10), {"type": "something_else"}),
	]
	viewport._drop_data(Vector2(10, 10), drag)
	viewport._drop_data(Vector2(10, 10), {"type": EventSheetObjectsPanel.DRAG_TYPE, "label": "Player"})
	viewport._drop_data(Vector2(10, 10), {"type": "nodes", "nodes": ["/root/Level/Spring"]})
	viewport.set_sheet(hero_sheet)
	viewport._drop_data(Vector2(10, 10), drag)
	var spring_offer: String = OFFERS.offer_for(OFFERS.node_for_dragged_path(level, "/root/Level/Spring"))
	var table: Array = [
		["a Scene-dock node is welcome on the canvas, one the scene lacks and other drags are not", accepted, [true, false, false]],
		["its drop emits what the same object dragged from the Objects list emits", landed[0], landed[1]],
		["...with the node's name as the label, landing as a new event, not in an action lane", [landed[0][0], landed[0][1], landed[0][2]], ["Player", null, false]],
		["a node the sheet already names differently is dropped as the name the sheet uses", landed[3][0], "hero"],
		["the secret group's offer reads the node the path names", [landed[2][0], spring_offer], ["Spring", "secret"]],
		["a path is read from the scene root down, whatever its start", [
			OFFERS.node_for_dragged_path(level, "/root/@EditorNode@1/Level/Player") == player,
			OFFERS.node_for_dragged_path(level, "Player") == player,
			OFFERS.node_for_dragged_path(level, "/root/Level") == level,
			OFFERS.node_for_dragged_path(level, "/root/Level/Gone") == null], [true, true, true, true]],
		["with no scene to read it against the path's last name is the label", OFFERS.object_label_for_drag(drag, null, null), "Player"],
		["an Object-valued nodes payload is a behaviour drag, not a path drag", OFFERS.dragged_path({"type": "nodes", "nodes": [player]}), ""],
	]
	viewport.free()
	level.free()
	return SUPPORT.pins(P, table)
