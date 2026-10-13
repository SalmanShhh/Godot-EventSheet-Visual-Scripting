# Godot EventSheets - the New Behaviour Addon dialog says a name clash while the name is typed,
# not first when Create is pressed.
@tool
class_name NewAddonPanelTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var passed: bool = true
	var host: Control = Control.new()
	var panel: EventSheetNewAddonPanel = EventSheetNewAddonPanel.new()
	panel.init(host)
	panel.open()
	passed = _check("an empty name says nothing yet", panel._name_note.text, "") and passed
	panel._name_edit.text = "Node"
	panel._name_edit.text_changed.emit("Node")
	passed = _check("a clashing name is said as it is typed",
		panel._name_note.text,
		"\"Node\" isn't a usable class name - use letters/digits/underscore starting with a letter, and not a reserved or existing class name.") and passed
	passed = _check("as a note that shows", panel._name_note.visible, true) and passed
	panel._name_edit.text = "FreshlyNamedThing"
	panel._name_edit.text_changed.emit("FreshlyNamedThing")
	passed = _check("a usable name clears the line again", panel._name_note.text, "") and passed
	passed = _check("and hides it", panel._name_note.visible, false) and passed
	host.free()
	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("new_addon_panel_test", label, actual, expected)
