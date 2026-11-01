@tool
class_name PositionAxisReadingTest
extends RefCounted

# Pins the words a write to a node's place reads in. A place measured from the parent node reads
# "Set X / Y / Z" (2D, 3D and UI nodes alike) and a place in the world reads "Set world X / Y / Z";
# the hover on either says which one it is and names the other. Every other member keeps its words.
# The last gate ties the importer to the reading: an imported Set Position is a write to the WORLD
# place, so it reads "Set world X" with no help from the importer's own table.

const SUPPORT := preload("res://tests/support.gd")
const NAME := "position_axis_reading_test"


static func run() -> bool:
	var other: Dictionary = {"self_object": "Player", "script_object": "Player"}
	var own: Dictionary = {"self_object": "Player", "script_object": "Player",
		"engine_properties": {"position": true, "global_position": true, "z_index": true}}
	var ok: bool = SUPPORT.pins(NAME, [
		["2D local y on another node", _read("$Tree.position.y = -8", other), "Tree ▸ Set Y to -8"],
		["2D local x on another node", _read("$Tree.position.x = 5", other), "Tree ▸ Set X to 5"],
		["a named node's y", _read("awning.position.y = -8", other), "awning ▸ Set Y to -8"],
		["the script's own local x", _read("position.x = 5", own), "Player ▸ Set X to 5"],
		["2D world y on another node", _read("$Tree.global_position.y = 1", other),
			"Tree ▸ Set world Y to 1"],
		["2D world x on the script's own node", _read("global_position.x = 3", own),
			"Player ▸ Set world X to 3"],
		["3D local z", _read("$Crate.position.z = 4", other), "Crate ▸ Set Z to 4"],
		["3D world z", _read("$Crate.global_position.z = 4", other), "Crate ▸ Set world Z to 4"],
		["UI local x", _read("$Panel.position.x = 10", {"self_object": "Menu", "script_object": "Menu",
			"object_classes": {"Panel": "Control"}}), "Panel ▸ Set X to 10"],
		["UI world y", _read("$Panel.global_position.y = 10", {"self_object": "Menu", "script_object": "Menu",
			"object_classes": {"Panel": "Control"}}), "Panel ▸ Set world Y to 10"],
		["z_index stays as written", _read("$Tree.z_index = 4", other), "Tree ▸ Set z_index to 4"],
		["the whole position stays", _read("$Tree.position = Vector2(1, 2)", other),
			"Tree ▸ Set position to (1, 2)"],
		["the hover on a local axis names the parent node and the world word",
			EventSheetSentence.axis_hover("Y"),
			"Y is measured from the parent node. Set world Y to place it in the world instead."],
		["the hover on a world axis names the local word",
			EventSheetSentence.axis_hover("world X"),
			"world X is the place in the world, whatever the parent node does. Set X to place it relative to the parent node instead."],
		["a whole local cell carries the local hover", EventSheetSentence.axis_hover_of_cell("Set Z to 4"),
			EventSheetSentence.axis_hover("Z")],
		["a whole world cell carries the world hover", EventSheetSentence.axis_hover_of_cell("Set world Y to 1"),
			EventSheetSentence.axis_hover("world Y")],
		["a cell that is not an axis write has none", EventSheetSentence.axis_hover_of_cell("Set z_index to 4"), ""],
		["other text has no axis hover", EventSheetSentence.axis_hover("Score"), ""],
	])
	return _imported_row_reads_world() and ok


## An imported Set Position, compiled to its GDScript and read back through the grammar.
static func _imported_row_reads_world() -> bool:
	var imported: Dictionary = EventSheetForeignImporter.import_sheet({"name": "Fixture", "events": [
		{"eventType": "block", "conditions": [], "children": [], "actions": [
			{"objectClass": "Player", "id": "set-position", "parameters": {"X": "10", "Y": "20"}}]}]},
		{"Player": {"kind": "Sprite", "node": "$Player"}})
	var emitted: String = str(SheetCompiler.compile(
		imported["sheet"] as EventSheetResource, "", true)["output"])
	var set_y: Dictionary = EventSheetForeignImporter.import_sheet({"name": "Fixture", "events": [
		{"eventType": "block", "conditions": [], "children": [], "actions": [
			{"objectClass": "Player", "id": "set-y", "parameters": {"Y": "20"}},
			{"objectClass": "Player", "id": "set-x", "parameters": {"X": "7"}}]}]},
		{"Player": {"kind": "Sprite", "node": "$Player"}})
	var emitted_axes: String = str(SheetCompiler.compile(
		set_y["sheet"] as EventSheetResource, "", true)["output"])
	var line: String = "$Player.global_position = Vector2(10, 20)"
	var axis_line: String = "$Player.%s = 20" % str(EventSheetForeignACEMap.OBJECT_PROPERTIES["Y"])
	var other: Dictionary = {"self_object": "Player", "script_object": "Player"}
	return SUPPORT.pins(NAME, [
		["the importer writes the world place", emitted.contains(line), true],
		["an imported whole position reads Set world position", _read(line, other),
			"Player ▸ Set world position to (10, 20)"],
		["an imported Set Y writes the world axis", emitted_axes.contains("$Player.global_position.y = 20"), true],
		["an imported Set X writes the world axis", emitted_axes.contains("$Player.global_position.x = 7"), true],
		["an expression naming Sword.X reads the world axis",
			EventSheetForeignACEMap.field_expression("Sword.X + 1", {"Sword": "$Sword"}, false),
			"$Sword.global_position.x + 1"],
		["an expression naming Sword.Y reads the world axis",
			EventSheetForeignACEMap.field_expression("Sword.Y", {"Sword": "$Sword"}, false),
			"$Sword.global_position.y"],
		["an imported Y round trips to a row that reads Set world Y", _read(axis_line, other),
			"Player ▸ Set world Y to 20"],
	])


static func _read(code: String, context: Dictionary) -> String:
	var reading: Dictionary = EventSheetSentence.statement(code, context)
	var text: String = ""
	for segment: Variant in (reading.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	return "%s ▸ %s" % [str(reading.get("object", "")), text.strip_edges()]
