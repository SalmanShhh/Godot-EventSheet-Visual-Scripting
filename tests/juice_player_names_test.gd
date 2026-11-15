# Godot EventSheets - the node is a JuicePlayer, the old name FeedbackPlayer still works, and no row moves.
#
# THE SHAPE: the code lives in `juice_player.gd` (`class_name JuicePlayer`); `feedback_player.gd`
# keeps its path and uid and holds only `class_name FeedbackPlayer extends JuicePlayer`. So an old
# node IS a JuicePlayer, a new node is NOT a FeedbackPlayer, and the rows the pack publishes keep
# their provider id, their ids and their templates. Only the "On node" starting value of the node
# rows moves, to `$JuicePlayer`, because that is what a node added from Create Node is called.
#
# The class names are asked through a small script built at run time, so this file still PARSES on
# a tree where JuicePlayer does not exist yet, and fails by its pins instead of by a parse error.
class_name JuicePlayerNamesTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_player_names"
const NEW_PATH: String = "res://eventsheet_addons/juice/juice_player.gd"
const OLD_PATH: String = "res://eventsheet_addons/juice/feedback_player.gd"

## How many rows the pack publishes, and how many of them start on a node.
const DEFINITIONS: int = 79
const NODE_ROWS: int = 71


static func run() -> bool:
	var ok: bool = _class_pins()
	ok = _row_pins() and ok
	return ok


static func _class_pins() -> bool:
	var classes: Dictionary = {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		classes[str(entry.get("class", ""))] = [str(entry.get("base", "")), str(entry.get("path", ""))]
	var answers: Array = [["no JuicePlayer file"], ["no JuicePlayer file"]]
	if ResourceLoader.exists(NEW_PATH):
		var old_node: Node = (load(OLD_PATH) as GDScript).new()
		var new_node: Node = (load(NEW_PATH) as GDScript).new()
		answers = [[_is(old_node, "JuicePlayer"), _is(old_node, "FeedbackPlayer")],
			[_is(new_node, "JuicePlayer"), _is(new_node, "FeedbackPlayer")]]
		old_node.free()
		new_node.free()
	return SUPPORT.pins(TEST_NAME, [
		["JuicePlayer is a Node class in its own file", classes.get("JuicePlayer", []), ["Node", NEW_PATH]],
		["FeedbackPlayer stays at its path and extends it", classes.get("FeedbackPlayer", []), ["JuicePlayer", OLD_PATH]],
		["an old node is both", answers[0], [true, true]],
		["a new node is a JuicePlayer and not a FeedbackPlayer", answers[1], [true, false]],
		# Create Node shows the first doc comment of the file as the class description, so the old name's
		# file carries no annotation header above it: just the sentence that says what it is.
		["the old name is a stub that says what it is", FileAccess.get_file_as_string(OLD_PATH),
			"@icon(\"res://eventsheet_addons/juice/icon.svg\")
class_name FeedbackPlayer
extends JuicePlayer
## The old name of Juice Player. Kept so projects made before version 0.21.0 keep working. Use Juice Player.
"],
	])


static func _row_pins() -> bool:
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	var published: Array[ACEDefinition] = [] as Array[ACEDefinition]
	if ResourceLoader.exists(NEW_PATH):
		published = generator.generate_from_script(load(NEW_PATH))
	var providers: Dictionary = {}
	var aimed: Dictionary = {}
	var play_template: String = ""
	for definition: ACEDefinition in published:
		providers[definition.provider_id] = true
		if definition.id == "method:play":
			play_template = str(definition.metadata.get("codegen_template", ""))
		for parameter: Variant in definition.parameters:
			if parameter is Dictionary and str((parameter as Dictionary).get("id", "")) == "target":
				aimed[str((parameter as Dictionary).get("default_value", ""))] = int(aimed.get(str((parameter as Dictionary).get("default_value", "")), 0)) + 1
	return SUPPORT.pins(TEST_NAME, [
		["the new file publishes every row", published.size(), DEFINITIONS],
		["every row keeps the old provider id", providers.keys(), ["FeedbackPlayer"]],
		["a template does not move", play_template, "{target}.play({at_strength})"],
		["every node row starts on the node Create Node makes", aimed, {"$JuicePlayer": NODE_ROWS}],
		["the old name publishes nothing of its own, so no row doubles",
			generator.generate_from_script(load(OLD_PATH)).size() if ResourceLoader.exists(NEW_PATH) else -1, 0],
	])


## `node is <global_name>`, asked without naming the class in this file.
static func _is(node: Object, global_name: String) -> bool:
	var asker: GDScript = GDScript.new()
	asker.source_code = "static func ask(n: Object) -> bool:\n\treturn n is %s\n" % global_name
	if asker.reload() != OK:
		return false
	return bool(asker.call("ask", node))
