class_name TraversalCourse3DDemo
extends Node3D
## [b]Traversal Course 3D[/b] - the same five moves as the 2D course, in metres on a CharacterBody3D, with no controller pack anywhere. The sheet writes the two lines a mover writes - gravity and move_and_slide - and Traversal Kit 3D writes everything between them: the Climber grabs the tower's lip and mantles onto it, the Jumper wall jumps across the shaft (the push follows the wall's own normal), the Ladder Bot climbs a marked Area3D, the Vaulter throws itself over the low block, and the Diver and the Stone fall together - the Diver into a marked pool where Swim and Float hold it near the surface.

@onready var traversal: TraversalKit3D = $Climber/Traversal
@onready var jumper_traversal: TraversalKit3D = $Jumper/Traversal
@onready var ladder_bot_traversal: TraversalKit3D = $LadderBot/Traversal
@onready var vaulter_traversal: TraversalKit3D = $Vaulter/Traversal
@onready var diver_traversal: TraversalKit3D = $Diver/Traversal

var hang_time: float = 0.0
var wall_time: float = 0.0
var race_time: float = 0.0

func _physics_process(delta: float) -> void:
	# The Climber: falls beside the tower, grabs the lip, hangs a second and mantles up.
	if not traversal.is_hanging():
		$Climber.velocity.y -= 9.8 * delta
	if traversal.is_at_a_ledge() and $Climber.velocity.y < 0.0:
		traversal.grab_ledge()
	if traversal.is_hanging():
		hang_time += delta
		if hang_time >= 1.0:
			hang_time = 0.0
			traversal.climb_up(0.5)
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
		jumper_traversal.slide_down_wall(1.5)
		wall_time += delta
		if wall_time >= 0.35:
			wall_time = 0.0
			jumper_traversal.wall_jump(6.0, 4.5)
	$Jumper.move_and_slide()
	# The Ladder Bot: the marked Area3D is the ladder, and the climb axis is held for it.
	$LadderBot.velocity.y -= 9.8 * delta
	if ladder_bot_traversal.is_on_ladder():
		ladder_bot_traversal.climb_ladder(2.5)
	$LadderBot.move_and_slide()
	if $LadderBot.global_position.y > 4.5:
		$LadderBot.global_position = Vector3(8.0, 0.9, 0.0)
		$LadderBot.velocity = Vector3.ZERO
	# The Vaulter: walks at the low block until the knee probe finds it and the chest probe
	# does not, then throws itself over in four tenths of a second.
	$Vaulter.velocity.y -= 9.8 * delta
	$Vaulter.velocity.x = 1.6
	if vaulter_traversal.is_at_vaultable():
		vaulter_traversal.vault_over(0.4)
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
	if diver_traversal.is_in_water():
		diver_traversal.swim(20.0, 10.0)
		diver_traversal.float_in_water(12.0)
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
	ladder_bot_traversal.ai_controlled = true
	ladder_bot_traversal.ai_climb_axis = 1.0

func _process(_delta: float) -> void:
	$HUD/Readout.text = "climber hanging: %s   jumper wall sliding: %s   bot on ladder: %s   diver depth: %.2f" % [
		str(traversal.is_hanging()), str(jumper_traversal.is_wall_sliding()),
		str(ladder_bot_traversal.is_on_ladder()), diver_traversal.water_depth()]
