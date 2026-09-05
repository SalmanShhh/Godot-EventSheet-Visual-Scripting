# A HUD whose two aim lines march their dashes - one of them a shape nobody dashed.
#
# The reticle IS dashed in the scene beside this file, so its scroll is the right row. The range
# ring is not, and this sheet never turns its dashes on either, so its offset climbs for ever over a
# solid stroke. That is the whole of what the Shapes section reports, and it is invisible at run
# time: both rows compile, both run, and one of them draws nothing new.
extends Node2D


func _ready() -> void:
	$Reticle.scroll_dashes(2.0)
	$RangeRing.scroll_dashes(1.5)
