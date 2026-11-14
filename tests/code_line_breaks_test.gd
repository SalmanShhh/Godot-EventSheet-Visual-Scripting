# Godot EventSheets - the Variable window's code line breaks after a comma or an opening bracket.
#
# The line the window READS (the strip's IN CODE text) is the true code, byte for byte. The line it DRAWS is
# a copy with a zero-width space after each comma, bracket, colon and equals sign that has no space after it, so a long
# quoted hint wraps there instead of in the middle of a word, and a preview of many columns scrolls inside
# its card instead of widening the window.
@tool
class_name CodeLineBreaksTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const BREAK_HINTS := preload("res://addons/eventsheet/editor/inspector/break_hints.gd")


static func run() -> bool:
	var line: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table:item=String,count=int\") var d: Array = []"
	var drawn: String = BREAK_HINTS.after_separators(line)
	var zero: String = String.chr(0x200B)
	var dialog: EventSheetVariableDialog = EventSheetVariableDialog.new()
	var host: Control = Control.new()
	dialog.init_dialog(host)
	dialog.open_for_edit("global", {}, "hp", "int", "100", false, "Add variable")
	var read_line: String = dialog._help_strip.in_code_value.text
	var drawn_line: String = dialog._code_drawn.text
	var twin: Array = [dialog._help_strip.in_code_value.visible, dialog._code_drawn.visible,
		dialog._code_drawn.autowrap_mode, dialog._code_drawn.get_parent() == dialog._help_strip.in_code_row]
	var scrolls: bool = dialog._inspector_preview_card.find_children("*", "ScrollContainer", true, false).size() > 0
	host.free()
	return SUPPORT.pins("code line breaks", [
		["with the breaks taken out the drawn line is the true line", drawn.replace(zero, ""), line],
		["a break point follows a comma, bracket, colon and equals sign that has no space after it", drawn.count(zero), 7],
		["a comma already followed by a space gets none", BREAK_HINTS.after_separators("a, b"), "a, b"],
		["a line without separators is untouched", BREAK_HINTS.after_separators("var hp: int = 100"), "var hp: int = 100"],
		["the window reads the true line", read_line, "@export var hp: int = 100"],
		["and draws the same line", drawn_line.replace(zero, ""), read_line],
		["the true line is hidden and its twin shown, wrapping, in the same row", twin,
			[false, true, TextServer.AUTOWRAP_WORD_SMART, true]],
		["the preview card scrolls sideways inside itself", scrolls, true],
	])
