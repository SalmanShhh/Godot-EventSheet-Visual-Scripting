# The same level with the one row that settles it: the post stack is drawn under the interface layer,
# so the health bar stays sharp however far the vignette goes. Nothing here is a finding.
extends Node2D


func _ready() -> void:
	$ScreenFx.draw_post_effects_below($Hud)
	$ScreenFx.pulse_post_effect("vignette", 0.6, 0.35)
