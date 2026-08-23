class_name TraversalCourse3DDemo
extends Node3D

var hang_time: float = 0.0
var wall_time: float = 0.0
var race_time: float = 0.0

func _physics_process(delta: float) -> void:
	# The Climber: falls beside the tower, grabs the lip, hangs a second and mantles up.
	if not $Climber/Traversal.is_hanging():
		$Climber.velocity.y -= 9.8 * delta
	if $Climber/Traversal.is_at_a_ledge() and $Climber.velocity.y < 0.0:
		$Climber/Traversal.grab_ledge()
	if $Climber/Traversal.is_hanging():
		hang_time += delta
		if hang_time >= 1.0:
			hang_time = 0.0
			$Climber/Traversal.climb_up(0.5)
	$Climber.move_and_slide()
	if $Climber.global_position.y > 3.0 and $Climber.is_on_floor():
		$Climber.global_position = Vector3(-9.5, 4.0, 0.0)
		$Climber.velocity = Vector3.ZERO
	# The Jumper: drives into a shaft wall, slides down it, and jumps away along its normal.
	$Jumper.velocity.y -= 9.8 * delta
	if $Jumper.is_on_floor():
		$Jumper.velocity.y = 5.0
		$Jumper.velocity.z = 2.0
		wall_time = 0.0
	elif $Jumper.is_on_wall():
		$Jumper/Traversal.slide_down_wall(1.5)
		wall_time += delta
		if wall_time >= 0.35:
			wall_time = 0.0
			$Jumper/Traversal.wall_jump(6.0, 4.5)
	$Jumper.move_and_slide()
	# The Ladder Bot: the marked Area3D is the ladder, and the climb axis is held for it.
	$LadderBot.velocity.y -= 9.8 * delta
	if $LadderBot/Traversal.is_on_ladder():
		$LadderBot/Traversal.climb_ladder(2.5)
	$LadderBot.move_and_slide()
	if $LadderBot.global_position.y > 4.5:
		$LadderBot.global_position = Vector3(8.0, 0.9, 0.0)
		$LadderBot.velocity = Vector3.ZERO
	# The Vaulter: walks at the low block until the knee probe finds it and the chest probe
	# does not, then throws itself over in four tenths of a second.
	$Vaulter.velocity.y -= 9.8 * delta
	$Vaulter.velocity.x = 1.6
	if $Vaulter/Traversal.is_at_vaultable():
		$Vaulter/Traversal.vault_over(0.4)
	$Vaulter.move_and_slide()
	if $Vaulter.global_position.x > 7.0:
		$Vaulter.global_position = Vector3(1.0, 0.9, 6.0)
		$Vaulter.velocity = Vector3.ZERO
	# The Diver and the Stone, dropped together every six seconds: only the Diver falls into
	# the marked pool, where Swim trades gravity for drag and Float pushes it back up by how
	# deep it is.
	race_time += delta
	$Diver.velocity.y -= 9.8 * delta
	$Stone.velocity.y -= 9.8 * delta
	if $Diver/Traversal.is_in_water():
		$Diver/Traversal.swim(20.0, 10.0)
		$Diver/Traversal.float_in_water(12.0)
	$Diver.move_and_slide()
	$Stone.move_and_slide()
	if race_time >= 6.0:
		race_time = 0.0
		$Diver.global_position = Vector3(13.0, 8.0, 4.0)
		$Diver.velocity = Vector3.ZERO
		$Stone.global_position = Vector3(13.0, 8.0, 9.0)
		$Stone.velocity = Vector3.ZERO

func _ready() -> void:
	# The Ladder Bot has no keyboard: the kit's AI seam holds the climb axis for it, the
	# same way a driver or a sheet would hold an up key.
	$LadderBot/Traversal.ai_controlled = true
	$LadderBot/Traversal.ai_climb_axis = 1.0

func _process(delta: float) -> void:
	$HUD/Readout.text = "climber hanging: %s   jumper wall sliding: %s   bot on ladder: %s   diver depth: %.2f" % [
		str($Climber/Traversal.is_hanging()), str($Jumper/Traversal.is_wall_sliding()),
		str($LadderBot/Traversal.is_on_ladder()), $Diver/Traversal.water_depth()]

# [b]Traversal Course 3D[/b] - the same five moves as the 2D course, in metres on a CharacterBody3D, with no controller pack anywhere. The sheet writes the two lines a mover writes - gravity and move_and_slide - and Traversal Kit 3D writes everything between them: the Climber grabs the tower's lip and mantles onto it, the Jumper wall jumps across the shaft (the push follows the wall's own normal), the Ladder Bot climbs a marked Area3D, the Vaulter throws itself over the low block, and the Diver and the Stone fall together - the Diver into a marked pool where Swim and Float hold it near the surface.
