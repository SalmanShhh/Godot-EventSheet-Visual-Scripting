# Godot EventSheets - every action and condition of the Juice Player reopens as its own row.
#
# A script written by hand (or by the plugin long ago) says `$FeedbackPlayer.enable_feedback("hit")`.
# Opened, that line used to read as a plain method call. The pack teaches the reader its own lines, so it
# now reads as the pack's row: same ace id, the pack's sentence. Reading only: the bytes never move, and
# a line the pack does not know (a different node, a label that is not a plain word) reads as before.
#
# For each published action and condition the line is built from the row's own template and defaults,
# once on each node name, put into a function, reopened and re-saved. What no line can tell apart -
# expressions, triggers, the looping condition - is listed, so nothing is silently missing.
class_name JuicePlayerSpellingsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_player_spellings"
const PACK_PATH: String = "res://eventsheet_addons/juice/juice_player.gd"
const LEVEL_SCRIPT: String = "res://tests/fixtures/juice_player_spellings/level.gd"

## Rows whose line is not a statement or a question of its own: an expression is a value inside another
## row, a trigger is a signal the file connects, and the loop is a `for` over a call.
const UNREADABLE_BY_LINE: PackedStringArray = [
	"method:for_each_feedback", "signal:on_feedbacks_started", "signal:on_feedbacks_finished",
	"signal:on_feedback_signal", "signal:on_feedback_started", "signal:on_feedback_finished",
	"signal:on_feedback_skipped", "signal:on_hold_reached", "signal:on_loop",
]


## How the values of a line are written: as the row starts (its real defaults, a text with a space in it
## included), each value given as a variable (a quoted text replaced by the variable, quotes and all), and each given as a
## call with a comma inside it (a quoted text as one with a comma and a bracket inside its quotes).
const SPELLINGS: PackedStringArray = ["defaults", "variable", "comma"]
const VARIABLE_VALUE: String = "my_value"
const COMMA_VALUE: String = "Vector2(1, 2)"
const TEXT_WITH_COMMA: String = "one, (two)"


static func run() -> bool:
	var wrong: Array = []
	var asked: int = 0
	var unreadable: PackedStringArray = PackedStringArray()
	for definition: ACEDefinition in EventSheetACEGenerator.new().generate_from_script(load(PACK_PATH)):
		# The property rows (Set Strength, Add To Cooldown ...) are made from the exported variables, not
		# from the verbs, and read as the property writes they are.
		if not (definition.id.begins_with("method:") or definition.id.begins_with("signal:")):
			continue
		if definition.ace_type == ACEDefinition.ACEType.EXPRESSION or definition.ace_type == ACEDefinition.ACEType.TRIGGER \
				or definition.metadata.has("looping"):
			unreadable.append(definition.id)
			continue
		for node_name: String in ["$FeedbackPlayer", "$JuicePlayer"]:
			for spelling: String in SPELLINGS:
				asked += 1
				var written: Dictionary = _line_for(definition, node_name, spelling)
				var row: Array = _reopened(definition, str(written["line"]))
				if row != ["FeedbackPlayer", definition.id, _sentence(definition, written["values"])]:
					wrong.append([node_name, spelling, definition.id, str(written["line"]), row])
	unreadable.sort()
	var expected: PackedStringArray = PackedStringArray(UNREADABLE_BY_LINE)
	expected.append_array(PackedStringArray(_expression_ids()))
	expected.sort()
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["every action and condition, on both node names, reopens as its own row with its own sentence", wrong, []],
		["a good number of lines were asked", asked > 80, true],
		["the rows no line can tell apart are the expressions, the triggers and the loop", unreadable, expected],
	])
	return _scene_pins() and ok


## The line a row is written as: its template with the node and its values put in, and the values it used
## by parameter id (what the reopened sentence should say).
static func _line_for(definition: ACEDefinition, node: String, spelling: String) -> Dictionary:
	var template: String = str(definition.metadata.get("codegen_template", ""))
	var line: String = template.replace("{target}", node)
	var values: Dictionary = {}
	for parameter: Variant in definition.parameters:
		var entry: Dictionary = parameter as Dictionary
		var id: String = str(entry.get("id", ""))
		var value: String = _value(entry, spelling, template)
		values[id] = value
		# A variable stands where the whole quoted text stood, quotes and all.
		if value == VARIABLE_VALUE and template.contains("\"{%s}\"" % id):
			line = line.replace("\"{%s}\"" % id, value)
		else:
			line = line.replace("{%s}" % id, value)
	return {"line": line, "values": values}


## What the sentence reads as with the values the line was written with: the display template, plain.
static func _sentence(definition: ACEDefinition, values: Dictionary) -> String:
	var text: String = str(definition.metadata.get("display_template", ""))
	for parameter: Variant in definition.parameters:
		var id: String = str((parameter as Dictionary).get("id", ""))
		var value: String = str(values.get(id, ""))
		if id == "path" and value != VARIABLE_VALUE:
			value = "\"%s\"" % value
		text = text.replace("{%s}" % id, value)
	return _plain(text)


static func _plain(text: String) -> String:
	return text.replace("[b]", "").replace("[/b]", "").replace("[i]", "").replace("[/i]", "")


## [provider, ace id, sentence] of the one row the line reopens as; the bytes are checked to stay.
static func _reopened(definition: ACEDefinition, line: String) -> Array:
	var is_question: bool = definition.ace_type == ACEDefinition.ACEType.CONDITION
	var body: String = "\tif %s:\n\t\tpass\n" % line if is_question else "\t%s\n" % line
	var source: String = "extends Node2D\n\n\nfunc _ready() -> void:\n" + body
	var row: Resource = _first_row(SUPPORT.reopen(source), is_question)
	if row == null or SUPPORT.reemit(source, "user://juice_player_spellings_reemit.gd") != source:
		return ["<no row, or the bytes moved>", "", ""]
	var text: String = str(definition.metadata.get("display_template", ""))
	var params: Dictionary = row.get("params")
	for key: Variant in params.keys():
		text = text.replace("{%s}" % str(key), str(params[key]))
	for parameter: Variant in definition.parameters:
		text = text.replace("{%s}" % str((parameter as Dictionary).get("id", "")), "")
	return [str(row.get("provider_id")), str(row.get("ace_id")), _plain(text)]


static func _first_row(sheet: EventSheetResource, question: bool) -> Resource:
	for event: Variant in sheet.events:
		if event is EventRow:
			var held: Array = (event as EventRow).conditions if question else (event as EventRow).actions
			if not held.is_empty():
				return held[0] as Resource
	return null


static func _expression_ids() -> Array:
	var ids: Array = []
	for definition: ACEDefinition in EventSheetACEGenerator.new().generate_from_script(load(PACK_PATH)):
		if definition.ace_type == ACEDefinition.ACEType.EXPRESSION and definition.id.begins_with("method:"):
			ids.append(definition.id)
	return ids


## A scene that says a node called HitJuice wears the Juice Player makes a line on `$HitJuice` read as the
## pack's row; with no scene known, or a node the scene does not hold, the line reads as it did.
static func _scene_pins() -> bool:
	var source: String = "extends Node2D\n\n\nfunc _ready() -> void:\n\t$HitJuice.play(1.0)\n\t$HitJuice.enable_feedback(\"hit\")\n\t$Other.play(1.0)\n"
	EventSheetSceneConnections.clear_cache()
	var known: Array = _ids(EventSheetGDScriptImporter.new().import_external_source(source, true, LEVEL_SCRIPT))
	var unknown: Array = _ids(SUPPORT.reopen(source))
	return SUPPORT.pins(TEST_NAME, [
		["with the scene known, a node that wears the pack reads as its rows and another stays a sound",
			known, ["FeedbackPlayer:method:play", "FeedbackPlayer:method:enable_feedback", "Core:AudioPlay"]],
		["the bytes do not move", SUPPORT.reemit(source, "user://juice_player_spellings_scene_reemit.gd"), source],
		["with no scene known the lines read as before", unknown, ["Core:AudioPlay", "Core:CallMethod", "Core:AudioPlay"]],
	])


static func _ids(sheet: EventSheetResource) -> Array:
	var ids: Array = []
	for event: Variant in sheet.events:
		if event is EventRow:
			for action: Variant in (event as EventRow).actions:
				ids.append("%s:%s" % [str((action as ACEAction).provider_id), str((action as ACEAction).ace_id)])
	return ids


## The value a parameter is written with in the test line. Its starting value in the first spelling, a
## variable or a call with a comma in it for a value the template writes without quotes in the others (a text
## the template quotes is only ever text). A row that starts blank (the Juice Player to copy from) is given a
## node to name.
static func _value(entry: Dictionary, spelling: String, template: String) -> String:
	var id: String = str(entry.get("id", ""))
	var value: String = str(entry.get("default_value", ""))
	if value.is_empty() and id == "other":
		value = "$Template"
	if spelling == "defaults" or id == "other":
		return value
	if spelling == "variable":
		return VARIABLE_VALUE
	# A text the template quotes gets a comma and a bracket inside its quotes; any other value a call with a comma.
	return TEXT_WITH_COMMA if template.contains("\"{%s}\"" % id) and id != "path" else COMMA_VALUE
