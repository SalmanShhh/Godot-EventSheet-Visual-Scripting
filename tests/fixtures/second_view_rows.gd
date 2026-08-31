# The Second View pack's own verbs, written the way a sheet emits them. Opening this must hand back
# the pack's rows - the same lift every pack verb gets from its codegen template, with no machinery
# of this pack's own - and re-emit byte for byte.
extends Node2D


func _ready() -> void:
	SecondView.make_a_view("minimap", $Player, 0.25)
	SecondView.show_view_in("minimap", $HUD/Frame)
	SecondView.set_view_zoom("minimap", 0.4)
	SecondView.stop_view("minimap")
