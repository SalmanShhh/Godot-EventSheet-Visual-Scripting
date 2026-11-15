# Godot EventSheets - the Feedback Player's row of doors wraps instead of widening the Inspector.
#
# The seven buttons under the list (Play, Stop, Skip, Restore, Debug view, Save as file, Load from file)
# used to sit in one row that asked for about 520 px, which pushed the Inspector that wide. They sit in
# Godot's wrapping row now, so the row asks for no more than its widest button.
@tool
class_name FeedbackStripWrapTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const STRIP := preload("res://addons/eventsheet/editor/inspector/feedback_player_strip.gd")


static func run() -> bool:
	var strip: VBoxContainer = STRIP.new()
	var rows: Array = strip.find_children("*", "HFlowContainer", true, false)
	var row: Control = rows[0] as Control if not rows.is_empty() else null
	var widest: float = 0.0
	var buttons: int = 0
	var total: float = 0.0
	if row != null:
		for child: Node in row.get_children():
			if child is Button:
				buttons += 1
				var wanted: float = (child as Button).get_combined_minimum_size().x
				widest = maxf(widest, wanted)
				total += wanted
	var asked: float = row.get_combined_minimum_size().x if row != null else -1.0
	strip.free()
	return SUPPORT.pins("feedback strip wrap", [
		["the doors sit in one wrapping row", rows.size(), 1],
		["all seven doors are there", buttons, 7],
		["the row asks for no more than its widest door", asked <= widest + 1.0, true],
		["and that is far less than the doors side by side", asked < total * 0.5, true],
	])
