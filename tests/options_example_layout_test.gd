# Godot EventSheets - the options example keeps its key hints with the play area, and its panel as tall as it is.
#
# The hint line stands at the foot of the play area, a child of it, so a fullscreen window shows it beside the
# game and not at the bottom edge of the screen. The options panel grows from its middle to fit what it
# holds, so no empty band is left under the Back button.
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
	var hints: Node = root.find_child("HintLabel", true, false)
	var panel: Control = root.find_child("OptionsPanel", true, false) as Control
	var ok: bool = SUPPORT.check(P, "the hint line is a child of the play area", hints.get_parent().name if hints != null else "", &"GameScreen")
	ok = SUPPORT.check(P, "the panel grows both ways from the middle", panel.grow_vertical, Control.GROW_DIRECTION_BOTH) and ok
	ok = SUPPORT.check(P, "and carries no fixed height of its own", panel.offset_bottom - panel.offset_top < 8.0, true) and ok
	root.free()
	return ok
