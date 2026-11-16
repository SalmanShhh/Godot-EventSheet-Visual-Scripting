# Pack builder - juice_card (the base of a juice card of your own; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## JuiceCard: the one script a card of your own extends.
##
## A Juice Player plays the cards in its list, and the cards that ship are words the player knows. A
## card of your own is a script that extends this one: its exported variables are the card's fields,
## its `play` is what happens when the list reaches it, and the Add card box lists it by itself, under
## "Yours", as soon as the project knows the class.
##
## Only `play` has to be written. `length` says how long the card takes so a Hold and the length of the
## list can wait for it, `stop` cuts it short when the list is stopped, and `restore` puts back what it
## changed. A card that holds a `seconds` export is that long without writing `length` at all.
##
## It is a plain script and never a tool script: a card runs in the game. The editor's Play button runs
## a card of yours only when its own script is marked as a tool script, which is Godot's rule for any
## script that runs in the editor.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "JuiceCard"
	sheet.class_description = "The base of a juice card of your own. Write a script that extends JuiceCard, export the values you want on the card, and write play(target, strength): the Juice Player lists the script in its Add card box under Yours and plays it when the list reaches it. length, stop and restore are optional."
	var body: RawCodeRow = RawCodeRow.new()
	body.code = "\n".join(_lines())
	sheet.events.append(body)
	return Lib.save_pack(sheet, "res://eventsheet_addons/juice/juice_card")


static func _lines() -> PackedStringArray:
	return PackedStringArray([
		"## The Juice Player playing this card, set just before `play` runs. Find a NodePath export with it.",
		"var player: Node = null",
		"",
		"## What the card does when the list reaches it. `target` is the object the Juice Player is under, and",
		"## `strength` is the strength of this play (the row's strength times the player's own). Write a card's",
		"## wait with `await` as in any other function: the player does not stop for it, and `length` says how",
		"## long it lasts.",
		"func play(_target: Node, _strength: float) -> void:",
		"\tpass",
		"",
		"## How long the card takes, in seconds, so a Hold card and the length of the list can wait for it. A",
		"## card that exports a number called seconds is that long unless it says otherwise.",
		"func length() -> float:",
		"\tvar named: Variant = get(&\"seconds\")",
		"\treturn maxf(float(named), 0.0) if named is float or named is int else 0.0",
		"",
		"## Called when the list is stopped, so a card that is still going can end now.",
		"func stop() -> void:",
		"\tpass",
		"",
		"## Called when the player is asked to put things back, so a card can undo what it changed.",
		"func restore() -> void:",
		"\tpass"
	])
