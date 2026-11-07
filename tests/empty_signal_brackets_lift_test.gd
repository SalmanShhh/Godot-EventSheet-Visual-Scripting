# A signal declared with empty brackets (`signal done()`) opens as a signal row, remembers the brackets
# and writes them back; a signal made in the sheet with no values is still written without them.
@tool
class_name EmptySignalBracketsLiftTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SOURCE := """extends Node

signal game_finished()
signal hit
signal scored(points: int)


func finish() -> void:
	game_finished.emit()
"""


static func run() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE)
	var signals: Dictionary = {}
	for row: Variant in sheet.events:
		if row is SignalRow:
			signals[(row as SignalRow).signal_name] = row
	ok = SUPPORT.check("empty_signal_brackets_lift_test", "all three signals open as signal rows", signals.keys(), ["game_finished", "hit", "scored"]) and ok
	var finished: SignalRow = signals.get("game_finished") as SignalRow
	ok = SUPPORT.check("empty_signal_brackets_lift_test", "the brackets are remembered", finished.empty_brackets if finished != null else null, true) and ok
	var plain: SignalRow = signals.get("hit") as SignalRow
	ok = SUPPORT.check("empty_signal_brackets_lift_test", "a bare signal keeps no brackets", plain.empty_brackets if plain != null else null, false) and ok
	ok = SUPPORT.check("empty_signal_brackets_lift_test", "the file is written back byte for byte", SUPPORT.reemit(SOURCE, "user://empty_signal_brackets_out.gd"), SOURCE) and ok
	var made: SignalRow = SignalRow.new()
	made.signal_name = "made_here"
	ok = SUPPORT.check("empty_signal_brackets_lift_test", "a signal made in the sheet is written without brackets", "\n".join(EventSheetBlockRegistry.get_kind("signal").emit_lines(made)), "signal made_here") and ok
	return ok
