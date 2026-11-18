extends CharacterBody2D

## The player, and the one rule that makes a late jump still count.

# @ace_group(uid="ground_rules", name="Ground rules", description="Everything that decides whether the player is standing on something.")

## How long after leaving a ledge a jump is still allowed.
var coyote_time: float = 0.12

## The player walked off an edge without jumping.
signal slipped_off


func _ready() -> void:
	## The numbers this sheet is built on.
	coyote_time = 0.12
	# measured against the six-frame input buffer, do not round this
	velocity = Vector2.ZERO


## True while the ledge is still forgiving the player.
func still_forgiven(since_left_ground: float) -> bool:
	return since_left_ground < coyote_time
