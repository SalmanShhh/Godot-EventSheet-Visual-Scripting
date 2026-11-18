# Godot EventSheets - a Juice card edit does a bounded amount of work, however big the project is.
#
# Every edit of a Juice card used to read the project's whole class list again to find the cards the project wrote for
# itself (a few milliseconds on a project of two thousand classes, and growing with it), and the strip under the list worked
# out the beat again after each of the two signals one edit sends. The project's own cards are now read once and kept until a
# script file is added, removed or saved, and the strip works its lines out only when the list or the Loop tick moved. This
# pins the count of reads, which does not depend on the machine: an edit opens no card script and reads no class list.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SCHEMA_PATH := "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const OWN_PATH := "res://addons/eventsheet/editor/inspector/juice_own_cards.gd"
const STRIP_PATH := "res://addons/eventsheet/editor/inspector/feedback_player_strip.gd"
const P := "juice_card_edit_bounded_work_test"


static func _cards(count: int) -> Array:
	var cards: Array = []
	for index: int in count:
		cards.append({"verb": ["shake", "flash", "pulse", "hitstop"][index % 4], "amount": 0.5, "seconds": 0.1 + float(index % 5) * 0.05})
	return cards


static func run() -> bool:
	var own: GDScript = load(OWN_PATH) as GDScript
	var schema: Dictionary = (load(SCHEMA_PATH) as GDScript).call("schema")
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"kind_key": "verb", "schema_dict": schema})
	own.call("reset")
	drawer.set_value(_cards(40))
	var scans: int = int(own.get("scans"))
	var read: int = int(own.get("files_read"))
	drawer.write_card_key(3, "seconds", 0.42)
	drawer.select_card(5)
	drawer.duplicate_selected()
	drawer.select_card(7)
	drawer.remove_selected()
	drawer.paste_after_selection(EventSheetCardSchemas.cards_to_text([_cards(1)[0]]))
	drawer.move_card(0, 4)
	drawer.add_first_kind()
	drawer.set_value(_cards(40))
	var rows: Array = [
		["edits of every sort read the project's classes no more times", int(own.get("scans")) - scans, 0],
		["and open no card script", int(own.get("files_read")) - read, 0],
	]
	# What was read is kept until it is dropped, and dropping it is what a changed script does.
	var kept: Array = own.call("kinds")
	var after_kept: int = int(own.get("scans"))
	own.call("kinds")
	own.call("entry_for", {"verb": "shake"})
	rows.append(["asking again reads nothing", int(own.get("scans")) - after_kept, 0])
	own.call("reset")
	own.call("kinds")
	rows.append(["dropping what was read makes the next ask read once", int(own.get("scans")) - after_kept, 1])
	rows.append(["and what it finds is what it found", own.call("kinds"), kept])
	drawer.free()
	var ok: bool = SUPPORT.pins(P, rows)
	return strip_pins() and ok


## The strip works the beat out when the list or the Loop tick moved, and only then.
static func strip_pins() -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = "@tool\nextends Node\nvar steps: Array = []\nvar loop: bool = false\nvar moment_file: Resource = null\n"
	script.reload()
	var player: Node = script.new() as Node
	player.set("steps", _cards(4))
	var strip: Control = (load(STRIP_PATH) as GDScript).new(player, null) as Control
	var head: Label = strip.get("_head") as Label
	var first: String = head.text
	head.text = "left as it was"
	strip.call("refresh")
	var same: String = head.text
	player.set("steps", _cards(5))
	strip.call("refresh")
	var moved: String = head.text
	head.text = "left again"
	player.set("loop", true)
	strip.call("refresh")
	var looped: String = head.text
	strip.free()
	player.free()
	return SUPPORT.pins(P, [
		["the head says how many cards the list holds", first.begins_with("4 juice cards"), true],
		["a refresh with the list and the Loop tick as they were works nothing out", same, "left as it was"],
		["a changed list is worked out", moved.begins_with("5 juice cards"), true],
		["and so is a changed Loop tick", looped.begins_with("5 juice cards"), true],
	])
