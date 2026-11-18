# Godot EventSheets - the options example keeps its key hints with the play area, and its panel as tall as it is.
#
# The key hints stand at the foot of the play area, children of it, one line each (F5 Quick save, F9 Quick load,
# Tab Options), so a fullscreen window shows them beside the game and not at the bottom edge of the screen. The
# options panel is titled Options, shows the volume as a number beside the slider, and heads its controls with
# the words control, keyboard and pad. It grows from its middle to fit what it holds, so no empty band is left
# under the Back button. The player and the coins are areas, so "overlapping" is the engine's own test.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "options_example_layout_test"
const SCENE := "res://demo/showcase/options_and_quick_save/options_and_quick_save.tscn"


static func run() -> bool:
	var packed: PackedScene = load(SCENE) as PackedScene
	if packed == null:
		return SUPPORT.check(P, "the scene loads", false, true)
	var root: Node = packed.instantiate()
	var hints: Node = root.find_child("Hints", true, false)
	var panel: Control = root.find_child("OptionsPanel", true, false) as Control
	var ok: bool = SUPPORT.check(P, "the hint lines are a child of the play area", hints.get_parent().name if hints != null else "", &"GameScreen")
	var hint_words: PackedStringArray = PackedStringArray()
	for hint: Node in hints.get_children():
		hint_words.append((hint as Label).text)
	ok = SUPPORT.check(P, "one hint line each for quick save, quick load and the options", hint_words, PackedStringArray(["F5 Quick save", "", "Tab Options"])) and ok
	ok = SUPPORT.pins(P, [
		["the options panel is titled in title case", (root.find_child("OptionsTitle", true, false) as Label).text, "Options"],
		["the volume number stands beside the slider", (root.find_child("VolumeValue", true, false) as Label).text, "80"],
		["the controls header names its three columns", _words_under(root.find_child("ControlsHeader", true, false)), PackedStringArray(["control", "keyboard", "pad", ""])],
		["the player is an area", root.find_child("Player", true, false) is Area2D, true],
		["every coin is an area in the coins group", _coins_are_areas(root), true],
		["the only extra control is no longer drawn: no Open options row", root.find_child("open_options_row", true, false) == null, true],
	]) and ok
	ok = SUPPORT.check(P, "the panel grows both ways from the middle", panel.grow_vertical, Control.GROW_DIRECTION_BOTH) and ok
	ok = SUPPORT.check(P, "and carries no fixed height of its own", panel.offset_bottom - panel.offset_top < 8.0, true) and ok
	root.free()
	return ok


static func _words_under(row: Node) -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray()
	for child: Node in row.get_children():
		words.append((child as Label).text if child is Label else "")
	return words


static func _coins_are_areas(root: Node) -> bool:
	var coins: Node = root.find_child("Coins", true, false)
	for coin: Node in coins.get_children():
		if not (coin is Area2D) or not coin.is_in_group("coins"):
			return false
	return coins.get_child_count() == 3
