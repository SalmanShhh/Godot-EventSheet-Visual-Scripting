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
		["other text has no axis hover", EventSheetSentence.axis_hover("Score"), ""],
	])
	return _hover_follows_the_row_data() and _imported_row_reads_world() and ok


## The hover is decided from the action's own data (the member path it writes), never from the words on
## its row: a script variable called X or Y reads "Set X to 5" too and must get no hint.
static func _hover_follows_the_row_data() -> bool:
	return SUPPORT.pins(NAME, [
		["a raw local axis write carries the local hover", EventSheetSentence.axis_hover_of_action(_raw("$Tree.position.z = 4")),
			EventSheetSentence.axis_hover("Z")],
		["a raw world axis write carries the world hover", EventSheetSentence.axis_hover_of_action(_raw("global_position.y = 1")),
			EventSheetSentence.axis_hover("world Y")],
		["a Set Property row on position.x carries the local hover",
			EventSheetSentence.axis_hover_of_action(_set_property("$Sword", "position.x", "3")), EventSheetSentence.axis_hover("X")],
		["a script variable named X gets no hint", EventSheetSentence.axis_hover_of_action(_raw("X = 5")), ""],
		["a script variable named Y gets no hint", EventSheetSentence.axis_hover_of_action(_raw("Y = 5")), ""],
		["a variable named my_position.x style member gets no hint", EventSheetSentence.axis_hover_of_action(_raw("my_position.x = 5")), ""],
		["a Set Property row on a variable named X gets no hint",
			EventSheetSentence.axis_hover_of_action(_set_property("$Sword", "X", "3")), ""],
		["a compound write does not read Set X, so it has no hint", EventSheetSentence.axis_hover_of_action(_raw("position.x += 3")), ""],
		["z_index has no hint", EventSheetSentence.axis_hover_of_action(_raw("$Tree.z_index = 4")), ""],
		["the whole position has no hint", EventSheetSentence.axis_hover_of_action(_raw("position = Vector2(1, 2)")), ""],
		["no action has no hint", EventSheetSentence.axis_hover_of_action(null), ""],
		["a rectangle's corner gets no hint", EventSheetSentence.axis_hover_of_action(
			_raw("area.position.x = 0"), {"area": "Rect2"}), ""],
		["an input event's place gets no hint", EventSheetSentence.axis_hover_of_action(
			_raw("click.position.y = 0"), {"click": "InputEventMouseButton"}), ""],
		["a variable typed as a node keeps the hint", EventSheetSentence.axis_hover_of_action(
			_raw("sword.position.y = 0"), {"sword": "Node2D"}), EventSheetSentence.axis_hover("Y")],
		["a variable typed with the project's own class keeps the hint", EventSheetSentence.axis_hover_of_action(
			_raw("sword.position.y = 0"), {"sword": "SwordPickup"}), EventSheetSentence.axis_hover("Y")],
		["a node path that names the parent names it in the hover",
			EventSheetSentence.axis_hover_of_action(_raw("$Player/Sword.position.y = -8")),
			"Y is measured from the parent node, Player. Set world Y to place it in the world instead."],
		["the world hover names the parent too",
			EventSheetSentence.axis_hover_of_action(_raw("$Player/Sword.global_position.y = 300")),
			"world Y is the place in the world, whatever the parent node, Player, does. Set Y to place it relative to Player instead."],
		["a path that climbs names no parent", EventSheetSentence.parent_named_by("$\"../Sword\""), ""],
		["a bare node names no parent", EventSheetSentence.parent_named_by("$Sword"), ""],
		["a rectangle's corner keeps its own words on the row",
			_read("area.position.x = 0", {"self_object": "Player", "script_object": "Player",
				"variable_value_types": {"area": "Rect2"}}), "area ▸ Set position.x to 0"],
	])


static func _raw(code: String) -> RawCodeRow:
	var row: RawCodeRow = RawCodeRow.new()
	row.code = code
	return row


static func _set_property(target: String, property: String, value: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.ace_id = "SetProperty"
	action.params = {"target": target, "property": property, "value": value}
	return action


## An imported Set Position, compiled to its GDScript and read back through the grammar.
static func _imported_row_reads_world() -> bool:
	var imported: Dictionary = EventSheetForeignImporter.import_sheet({"name": "Fixture", "events": [
		{"eventType": "block", "conditions": [], "children": [], "actions": [
			{"objectClass": "Player", "id": "set-position", "parameters": {"X": "10", "Y": "20"}}]}]},
		{"Player": {"kind": "Sprite", "node": "$Player"}})
	var emitted: String = str(EventSheetCompiler.compile(
		imported["sheet"] as EventSheetResource, "", true)["output"])
	var set_y: Dictionary = EventSheetForeignImporter.import_sheet({"name": "Fixture", "events": [
		{"eventType": "block", "conditions": [], "children": [], "actions": [
			{"objectClass": "Player", "id": "set-y", "parameters": {"Y": "20"}},
			{"objectClass": "Player", "id": "set-x", "parameters": {"X": "7"}}]}]},
		{"Player": {"kind": "Sprite", "node": "$Player"}})
	var emitted_axes: String = str(EventSheetCompiler.compile(
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
		["the importer reads a distance between two objects in the world",
			str(EventSheetForeignACEMap.translate_expression("distance(Sword, Player)")["text"]),
			"Sword.global_position.distance_to(Player.global_position)"],
		["the importer reads an angle between two objects in the world, in degrees",
			str(EventSheetForeignACEMap.translate_expression("angle(Sword, Player)")["text"]),
			"rad_to_deg(Sword.global_position.angle_to_point(Player.global_position))"],
		["an imported lowercase set-y parameter (as the editor writes it) maps too", _imported_axis_emission("set-y", "y", "20"),
			"$Player.global_position.y = 20"],
		["an imported lowercase set-x parameter maps too", _imported_axis_emission("set-x", "x", "7"),
			"$Player.global_position.x = 7"],
		["an imported move at angle steps the world place", _imported_step_emission(),
			"$Player.global_position += Vector2.RIGHT.rotated(deg_to_rad(90)) * 10"],
	])


## One imported Set X / Set Y action, compiled, returning the line it wrote ("" when it wrote none).
static func _imported_axis_emission(row_id: String, parameter: String, value: String) -> String:
	var imported: Dictionary = EventSheetForeignImporter.import_sheet({"name": "Fixture", "events": [
		{"eventType": "block", "conditions": [], "children": [], "actions": [
			{"objectClass": "Player", "id": row_id, "parameters": {parameter: value}}]}]},
		{"Player": {"kind": "Sprite", "node": "$Player"}})
	var emitted: String = str(EventSheetCompiler.compile(imported["sheet"] as EventSheetResource, "", true)["output"])
	for line: String in emitted.split("\n"):
		if line.strip_edges().begins_with("$Player."):
			return line.strip_edges()
	return ""


## One imported Move At Angle, compiled, returning the line it wrote ("" when it wrote none). The angle
## is a direction in the level, so the step lands on the world place whatever the parent is turned to.
static func _imported_step_emission() -> String:
	var imported: Dictionary = EventSheetForeignImporter.import_sheet({"name": "Fixture", "events": [
		{"eventType": "block", "conditions": [], "children": [], "actions": [
			{"objectClass": "Player", "id": "move-at-angle", "parameters": {"Angle": "90", "Distance": "10"}}]}]},
		{"Player": {"kind": "Sprite", "node": "$Player"}})
	var emitted: String = str(EventSheetCompiler.compile(imported["sheet"] as EventSheetResource, "", true)["output"])
	for line: String in emitted.split("\n"):
		if line.strip_edges().begins_with("$Player."):
			return line.strip_edges()
	return ""


static func _read(code: String, context: Dictionary) -> String:
	var reading: Dictionary = EventSheetSentence.statement(code, context)
	var text: String = ""
	for segment: Variant in (reading.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	return "%s ▸ %s" % [str(reading.get("object", "")), text.strip_edges()]
