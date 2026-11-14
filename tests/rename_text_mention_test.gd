# Godot EventSheets - the Rename window does not list a text in quotes as if it were rewritten.
#
# A row that says the name only inside a text in quotes (print("speed=")) reads the same after the
# rename, so the list of what is rewritten leaves it out and the mention is listed under its own heading.
@tool
class_name RenameTextMentionTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {"speed": {"type": "float", "default": "1.0"}}
	for code: String in ["print(\"speed=\")", "position.x += speed"]:
		var row: RawCodeRow = RawCodeRow.new()
		row.code = code
		sheet.events.append(row)
	var rewritten: PackedStringArray = EventSheetRenameReceipt.row_lines(sheet, "speed", "move_speed")
	var untouched: PackedStringArray = EventSheetRenameReceipt.mention_lines(sheet, "speed")
	var same_name: PackedStringArray = EventSheetRenameReceipt.row_lines(sheet, "speed", "speed")
	return SUPPORT.pins("rename text mention", [
		["a row that changes is listed with its new reading", Array(rewritten),
			["var speed → var move_speed", "position.x += speed → position.x += move_speed"]],
		["a text in quotes is not listed as a rewrite", rewritten.has("\"speed=\" → \"speed=\""), false],
		["the text that mentions the name is listed on its own", Array(untouched), ["print(\"speed=\")"]],
		["with the name not yet changed the text is still not a rewrite", same_name.size(), 2],
	])
