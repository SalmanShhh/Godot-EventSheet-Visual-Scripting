class_name TraversalCourseDemo
extends Node2D

var hang_time: float = 0.0
var race_time: float = 0.0
var wall_time: float = 0.0

func _ready() -> void:
	# The Jumper drives itself into the shaft: the movement pack's AI seam is held like a
	# key, and every wall jump turns it around to follow the push.
	$Jumper/Movement.ai_move_axis = 1.0

func _physics_process(delta: float) -> void:
	# The player: every verb the kit publishes, on the arrow keys and Space.
	if $Player/Traversal.is_hanging():
		if Input.is_action_just_pressed("ui_accept"):
			$Player/Traversal.climb_up(0.3)
		elif Input.is_action_pressed("ui_down"):
			$Player/Traversal.drop()
	elif $Player/Traversal.is_at_a_ledge() and $Player/Movement.is_falling():
		$Player/Traversal.grab_ledge()
	if $Player.is_on_wall() and $Player/Movement.is_falling():
		$Player/Traversal.slide_down_wall(60.0)
	if $Player/Traversal.is_on_ladder() and Input.is_action_pressed("ui_up"):
		$Player/Traversal.climb_ladder(120.0)
	if $Player/Traversal.is_at_vaultable() and Input.is_action_just_pressed("ui_accept"):
		$Player/Traversal.vault_over(0.4)
	if $Player/Traversal.is_in_water():
		$Player/Traversal.swim(20.0, 10.0)
	# The Climber: falls beside the tower, grabs the lip, hangs a second, mantles onto the
	# top - then starts again from the drop point.
	if $Climber/Traversal.is_at_a_ledge() and $Climber/Movement.is_falling():
		$Climber/Traversal.grab_ledge()
	if $Climber/Traversal.is_hanging():
		hang_time += delta
		if hang_time >= 1.0:
			hang_time = 0.0
			$Climber/Traversal.climb_up(0.4)
	if $Climber.global_position.y < 420.0 and $Climber.is_on_floor():
		$Climber.global_position = Vector2(258.0, 330.0)
		$Climber.velocity = Vector2.ZERO
	# The Jumper: jumps off the floor into the shaft, slides down whichever wall it lands
	# on, and wall jumps AWAY from it - the push follows the wall's own normal, so it
	# crosses to the other wall without being told which side it was on.
	if $Jumper.is_on_floor():
		# Landed: aim back at the shaft before the next hop, so it can never wander off.
		$Jumper/Movement.ai_move_axis = signf(660.0 - $Jumper.global_position.x)
		$Jumper/Movement.jump()
		wall_time = 0.0
	elif $Jumper.is_on_wall():
		$Jumper/Traversal.slide_down_wall(60.0)
		wall_time += delta
		if wall_time >= 0.35:
			wall_time = 0.0
			$Jumper/Traversal.wall_jump(300.0, 500.0)
			$Jumper/Movement.ai_move_axis = signf($Jumper.velocity.x)
	else:
		wall_time = 0.0
	# The Diver and the Stone: dropped from the same height every six seconds, one over the
	# pool and one beside it. Swim trades gravity for the water's own pull and drag, so the
	# Diver is still sinking long after the Stone has landed.
	race_time += delta
	if $Diver/Traversal.is_in_water():
		$Diver/Traversal.swim(20.0, 10.0)
	if race_time >= 6.0:
		race_time = 0.0
		$Diver.global_position = Vector2(1120.0, 200.0)
		$Diver.velocity = Vector2.ZERO
		$Stone.global_position = Vector2(1290.0, 200.0)
		$Stone.velocity = Vector2.ZERO

func _process(delta: float) -> void:
	$HUD/Readout.text = "climber hanging: %s   jumper wall sliding: %s   diver in water: %s   depth: %.0f" % [
		str($Climber/Traversal.is_hanging()), str($Jumper/Traversal.is_wall_sliding()),
		str($Diver/Traversal.is_in_water()), $Diver/Traversal.water_depth()]

# [b]Traversal Course[/b] - the Traversal Kit on a CharacterBody2D, one move per station. Arrow keys run and jump (Platformer movement), and the kit does the rest: walk off the tower to hang from the lip and press Space to mantle, or Down to drop; press into the shaft walls to slide down them; stand on the ladder and hold Up; walk into the low block and press Space to vault it; swim in the pool. The kit writes velocity and Platformer movement does the moving, so both packs stack on the same body. Four actors run the same rows on a loop with no input at all: the Climber grabs and mantles, the Jumper wall-jumps up the shaft, and the Diver and the Stone fall together - one into the water, one beside it.
