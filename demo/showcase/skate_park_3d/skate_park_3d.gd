class_name SkatePark3D
extends Node3D

## Everything banked so far this run.
@export var score: int = 0


func _ready() -> void:
	$Skater/Skateboard.landed_clean.connect(_on_landed_clean)
	$Skater/Skateboard.launched_off_the_lip.connect(_on_launched)
	$Skater/Skateboard.bailed.connect(_on_bailed)


func _physics_process(delta: float) -> void:
	if $Skater.is_on_floor():
		$Skater/Skateboard.roll_with_slope()
	$Skater/Skateboard.align_board_to_surface()
	if Input.is_action_just_pressed(&"ui_accept"):
		$Skater/Skateboard.push(2.0)
	if Input.is_action_just_pressed(&"ui_up"):
		$Skater/Skateboard.ollie(6.0)
	if $Skater/Skateboard.is_airborne() and Input.is_action_pressed(&"ui_right"):
		$Skater/Skateboard.spin_trick(1.0)
	if not $Skater/Skateboard.is_grinding() and $Skater/Skateboard.is_near_rail($Rail, 0.8):
		$Skater/Skateboard.start_grinding($Rail)
	if $Skater/Skateboard.is_grinding():
		$Skater/Skateboard.grind_along_rail(10.0, false)
	if $Skater/Skateboard.has_reached_the_end():
		$Skater/Skateboard.add_to_chain("grind", 250.0)
		$Skater/Skateboard.hop_off(4.5)
	$Overlay/Hud.text = "Score %d   chain %d x%d   Space push / Up ollie / Right spin" % [score, int($Skater/Skateboard.chain_score()), $Skater/Skateboard.multiplier()]


## @ace_hidden
func _on_landed_clean() -> void:
	if $Skater/Skateboard.spin_turns() >= 0.5:
		$Skater/Skateboard.add_to_chain("spin", 150.0)
	$Skater/Skateboard.bank_chain()
	score = int($Skater/Skateboard.banked_score())


## @ace_hidden
func _on_launched() -> void:
	$Skater/Skateboard.add_to_chain("air", 100.0)


## @ace_hidden
func _on_bailed() -> void:
	$Skater.global_position = Vector3(-9.0, 1.0, 0.0)
	$Skater.velocity = Vector3.ZERO

# [b]Skate Park 3D[/b] - the Skateboard 3D pack, playable. Roll With The Slope projects gravity onto the surface normal so the bank at the end carves, Align The Board To The Surface keeps the board flat on it, and leaving the bank fires On Launched Off The Lip. The rail is an ordinary Path3D. Space pushes, Up ollies, Right spins in the air.
