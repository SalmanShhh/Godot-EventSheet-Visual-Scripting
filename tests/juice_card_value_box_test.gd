# Godot EventSheets - the value box of Set Juice Card Field is the box the chosen field's own kind of value needs.
#
# THE ONE THING THIS FILE IS ABOUT: the row that writes one value on one card used to ask for it in a plain box
# whatever the field was. The Inspector draws a number for an amount, a colour for a colour, a file for a sound, a
# node for a node, a tick for a tick and the card's own words for a choice, so the row's box says the same thing
# the card does, read off the same description of the card. Nothing about the row itself changes: its id, its
# template and a row saved before this all stay as they were, and a value the typed box cannot show (a variable, a
# sum) leaves the plain box in place.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const FINDER_PATH: String = "res://addons/eventsheet/editor/dock/juice_card_field_names.gd"
const VALUE_HINT: String = "juice_card_value"
const TEST_NAME: String = "juice_card_value_box"


static func run() -> bool:
	var finder: Script = load(FINDER_PATH) as Script
	var text: String = FileAccess.get_file_as_string(PACK)
	var sound: Dictionary = {"verb": "sound", "stream": "uid://bnosuchsound", "volume_db": -3.0, "heard_from": "here"}
	var shake: Dictionary = {"verb": "shake", "amount": 0.4, "seconds": 0.5, "fade_out": true}
	var tween: Dictionary = {"verb": "tween_property", "amount": 1.0, "seconds": 0.2, "to": Color.RED}
	return SUPPORT.pins(TEST_NAME, [
		["an amount is a number", str((finder.call("kind_in", shake, "amount") as Dictionary).get("kind")), "number"],
		["a length is a number", str((finder.call("kind_in", sound, "volume_db") as Dictionary).get("kind")), "number"],
		["a tick is a tick", str((finder.call("kind_in", shake, "fade_out") as Dictionary).get("kind")), "bool"],
		["a sound's stream is a file", str((finder.call("kind_in", sound, "stream") as Dictionary).get("kind")), "file"],
		["a shake's curve is a file", str((finder.call("kind_in", shake, "curve") as Dictionary).get("kind")), "file"],
		["a choice lists the card's own words", (finder.call("kind_in", sound, "heard_from") as Dictionary), {"kind": "choice", "choices": ["here", "everywhere"]}],
		["a card's clock is a choice too", (finder.call("kind_in", shake, "clock") as Dictionary).get("choices"), ["game", "real"]],
		["a value the drawer does not name takes the kind of the value the card holds", str((finder.call("kind_in", tween, "to") as Dictionary).get("kind")), "colour"],
		["a key no card has is not known", str((finder.call("kind_in", shake, "nothing_here") as Dictionary).get("kind")), ""],
		["the row's value box carries the hint that draws it", _param_line(text, "set_feedback_field", "value").contains("hint: %s" % VALUE_HINT), true],
		["and the row writes the line it has always written", text.contains("# @ace_codegen_template(\"$JuicePlayer.set_feedback_field({label}, {field}, {value})\")") \
			or text.contains("set_feedback_field(\"{label}\", \"{field}\", {value})"), true],
		["a sheet that finds no scene knows no kind", str((finder.call("value_kind", "", "$HitJuice", "shake", "amount") as Dictionary).get("kind")), ""],
	])


## The `@ace_param` line of one parameter of one verb, from the pack as it is on disk.
static func _param_line(text: String, verb_name: String, param: String) -> String:
	var lines: PackedStringArray = text.split("\n")
	var at: int = -1
	for index: int in range(lines.size()):
		if lines[index].strip_edges().begins_with("func %s(" % verb_name):
			at = index
			break
	if at < 0:
		return ""
	for back: int in range(at - 1, maxi(at - 40, 0), -1):
		var line: String = lines[back].strip_edges()
		if line.begins_with("# @ace_param(%s" % param):
			return line
		if not line.begins_with("#"):
			break
	return ""
