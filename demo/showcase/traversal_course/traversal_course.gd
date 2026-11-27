class_name TraversalCourseDemo
extends Node2D
## [b]Traversal Course[/b] - the Traversal Kit on a CharacterBody2D, one move per station. Arrow keys run and jump (Platformer movement), and the kit does the rest: walk off the tower to hang from the lip and press Space to mantle, or Down to drop; press into the shaft walls to slide down them; stand on the ladder and hold Up; walk into the low block and press Space to vault it; swim in the pool. The kit writes velocity and Platformer movement does the moving, so both packs stack on the same body. Four actors run the same rows on a loop with no input at all: the Climber grabs and mantles, the Jumper wall-jumps up the shaft, and the Diver and the Stone fall together - one into the water, one beside it.

# Nodes this sheet calls, declared once with their type.
@onready var movement: PlatformerMovement = $Jumper/Movement
@onready var traversal: TraversalKit = $Player/Traversal
@onready var player_movement: PlatformerMovement = $Player/Movement
@onready var climber_traversal: TraversalKit = $Climber/Traversal
@onready var climber_movement: PlatformerMovement = $Climber/Movement
@onready var jumper_traversal: TraversalKit = $Jumper/Traversal
@onready var diver_traversal: TraversalKit = $Diver/Traversal

var hang_time: float = 0.0
var wall_time: float = 0.0
var race_time: float = 0.0

func _ready() -> void:
	# The Jumper drives itself into the shaft: the movement pack's AI seam is held like a
	# key, and every wall jump turns it around to follow the push.
	movement.ai_move_axis = 1.0

func _physics_process(delta: float) -> void:
	# The player: every verb the kit publishes, on the arrow keys and Space.
	if traversal.is_hanging():
		if Input.is_action_just_pressed("ui_accept"):
			traversal.climb_up(0.3)
		elif Input.is_action_pressed("ui_down"):
			traversal.drop()
	elif traversal.is_at_a_ledge() and player_movement.is_falling():
		traversal.grab_ledge()
	if $Player.is_on_wall() and player_movement.is_falling():
		traversal.slide_down_wall(60.0)
	if traversal.is_on_ladder() and Input.is_action_pressed("ui_up"):
		traversal.climb_ladder(120.0)
	if traversal.is_at_vaultable() and Input.is_action_just_pressed("ui_accept"):
		traversal.vault_over(0.4)
	if traversal.is_in_water():
		traversal.swim(20.0, 10.0)
	# The Climber: falls beside the tower, grabs the lip, hangs a second, mantles onto the
	# top - then starts again from the drop point.
	if climber_traversal.is_at_a_ledge() and climber_movement.is_falling():
		climber_traversal.grab_ledge()
	if climber_traversal.is_hanging():
		hang_time += delta
		if hang_time >= 1.0:
			hang_time = 0.0
			climber_traversal.climb_up(0.4)
	if $Climber.global_position.y < 420.0 and $Climber.is_on_floor():
		$Climber.global_position = Vector2(258.0, 330.0)
		$Climber.velocity = Vector2.ZERO
	# The Jumper: jumps off the floor into the shaft, slides down whichever wall it lands
	# on, and wall jumps AWAY from it - the push follows the wall's own normal, so it
	# crosses to the other wall without being told which side it was on.
	if $Jumper.is_on_floor():
		# Landed: aim back at the shaft before the next hop, so it can never wander off.
		movement.ai_move_axis = signf(660.0 - $Jumper.global_position.x)
		movement.jump()
		wall_time = 0.0
	elif $Jumper.is_on_wall():
		jumper_traversal.slide_down_wall(60.0)
		wall_time += delta
		if wall_time >= 0.35:
			wall_time = 0.0
			jumper_traversal.wall_jump(300.0, 500.0)
			movement.ai_move_axis = signf($Jumper.velocity.x)
	else:
		wall_time = 0.0
	# The Diver and the Stone: dropped from the same height every six seconds, one over the
	# pool and one beside it. Swim trades gravity for the water's own pull and drag, so the
	# Diver is still sinking long after the Stone has landed.
	race_time += delta
	if diver_traversal.is_in_water():
		diver_traversal.swim(20.0, 10.0)
	if race_time >= 6.0:
		race_time = 0.0
		$Diver.global_position = Vector2(1120.0, 200.0)
		$Diver.velocity = Vector2.ZERO
		$Stone.global_position = Vector2(1290.0, 200.0)
		$Stone.velocity = Vector2.ZERO

func _process(_delta: float) -> void:
	$HUD/Readout.text = "climber hanging: %s   jumper wall sliding: %s   diver in water: %s   depth: %.0f" % [
		str(climber_traversal.is_hanging()), str(jumper_traversal.is_wall_sliding()),
		str(diver_traversal.is_in_water()), diver_traversal.water_depth()]
