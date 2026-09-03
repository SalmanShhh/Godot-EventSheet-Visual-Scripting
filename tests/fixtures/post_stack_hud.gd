# A level that puts two post effects on the screen, in a scene whose interface is on a CanvasLayer of
# its own, and never says which side of that layer the effects belong on. That is one finding about
# the scene rather than one per row, and this fixture is what says so.
extends Node2D


func _ready() -> void:
	$ScreenFx.pulse_post_effect("vignette", 0.6, 0.35)
	$ScreenFx.add_post_effect("film grain", "", 0.2)
