# Godot EventSheets - the Inspector preview marks the default choice of a Toggle buttons look.
#
# A default typed as a bare word (normal) is how the code line reads it, so the preview must read it
# the same way and show that button chosen, instead of leaving every button unselected.
@tool
class_name PreviewToggleDefaultTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var card := EventSheetInspectorPreviewCard.new()
	var attributes: Dictionary = {"drawer": "toggle_row", "toggle_options": ["easy", "normal", "hard"]}
	var rows: Array = []
	for default_text: String in ["normal", "\"hard\"", "0", " easy "]:
		var widget: Control = card._build_widget("String", default_text, attributes)
		rows.append([default_text, (widget as EventSheetDrawerWidgets.DrawerToggleRow).get_value()])
	card.free()
	return SUPPORT.pins("preview toggle default", [
		["a bare word is the chosen button", rows[0][1], "normal"],
		["a quoted word is the chosen button", rows[1][1], "hard"],
		["a number picks by place", rows[2][1], "easy"],
		["spaces around the word are ignored", rows[3][1], "easy"],
	])
