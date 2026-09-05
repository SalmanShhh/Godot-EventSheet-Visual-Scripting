# The same undashed ring, with the row that answers for it: a Set Dashes before the scroll.
#
# Set Dashes always turns the dashes on, so the shape has a pattern to march however its Inspector
# was left - and the Shapes section says nothing at all about this sheet. The passing case matters
# more than the failing one: a check that spoke here would be a check somebody switched off.
extends Node2D


func _ready() -> void:
	$RangeRing.set_dashes(16, 0.4, "round")
	$RangeRing.scroll_dashes(1.5)
	$Reticle.scroll_dashes(0.0)
