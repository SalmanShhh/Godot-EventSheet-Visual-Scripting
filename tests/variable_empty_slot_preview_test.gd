# Godot EventSheets - a node or resource slot left empty previews the line the save writes.
#
# The variable window's IN CODE line is built from a preview row. An empty code value (a node or
# resource slot with nothing picked) reached it as an empty string, so the window promised
# `@export var falloff: Curve = ""` - code that does not parse - while the save wrote the slot with
# no value at all. The preview now says what the save writes.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "variable_empty_slot_preview_test"


static func run() -> bool:
	var host: Node = Node.new()
	var dialog: VariableDialog = VariableDialog.new()
	dialog.init_dialog(host)
	dialog.set_sheet_provider(func() -> Variant: return null)
	var lines: Dictionary = {}
	for slot: Array in [["falloff", "Curve"], ["target", "Node2D"], ["icon", "Texture2D"]]:
		dialog.open_for_edit("tree", {"editing": true}, str(slot[0]), str(slot[1]), "", false, "Edit", false, true)
		lines[slot[0]] = dialog.code_line_text()
	host.free()
	return SUPPORT.check(TEST_NAME, "an empty slot previews no value", lines, {
		"falloff": "@export var falloff: Curve",
		"target": "@export var target: Node2D",
		"icon": "@export var icon: Texture2D",
	})
