# Godot EventSheets - Stat Forge: a state saved by an older version still loads, and saves back unchanged.
#
# A buff and a threshold rule are small classes inside the behaviour now, but the state they are saved
# in is the same record it always was. This loads a state written in the old form (as text, parsed),
# pins what the behaviour reads out of it, and pins that saving it again gives the identical text.
@tool
class_name StatForgeSavedStateTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "stat_forge_saved_state_test"
const PACK: String = "res://eventsheet_addons/stat_forge/stat_forge_behavior.gd"

## A state exactly as the behaviour saved it before its buffs and rules became classes: a base, three
## buffs (one switched off, one paused mid-countdown) and one spent one-shot rule.
const OLD_FORM: String = "{\"bases\":{\"hp\":100.0},\"buffs\":{\"cap\":{\"active\":false,\"duration\":5.0,\"mode\":\"override\",\"paused\":false,\"source\":\"\",\"stat\":\"hp\",\"tags\":[],\"time_left\":5.0,\"value\":50.0},\"haste\":{\"active\":true,\"duration\":10.0,\"mode\":\"multiply\",\"paused\":true,\"source\":\"spell\",\"stat\":\"speed\",\"tags\":[\"aura\"],\"time_left\":10.0,\"value\":1.5},\"ring\":{\"active\":true,\"duration\":0.0,\"mode\":\"add\",\"paused\":false,\"source\":\"shop\",\"stat\":\"hp\",\"tags\":[\"gear\",\"magic\"],\"time_left\":-1.0,\"value\":20.0}},\"last_totals\":{\"hp\":120.0},\"rules\":{\"low\":{\"armed\":true,\"direction\":\"falling\",\"repeating\":false,\"stat\":\"hp\",\"value\":60.0}}}"


static func run() -> bool:
	var script: GDScript = load(PACK) as GDScript
	var forge: Node = script.new() as Node
	forge.call("load_state", JSON.parse_string(OLD_FORM) as Dictionary)
	var rows: Array = [
		["the buffs are read back", [forge.call("buff_count"), forge.call("has_buff", "ring"), forge.call("buff_value", "haste"), forge.call("buff_time_left", "cap")], [3, true, 1.5, 5.0]],
		["the tags and the switch are read back", [forge.call("buff_count_with_tag", "gear"), forge.call("buff_is_active", "cap"), forge.call("buff_is_active", "ring")], [1, false, true]],
		["the total follows them", forge.call("stat_total", "hp"), 120.0],
		["saving it again gives the same text", JSON.stringify(forge.call("save_state")), OLD_FORM],
	]
	forge.free()
	return SUPPORT.pins(NAME, rows)
