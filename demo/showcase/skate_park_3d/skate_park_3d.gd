class_name SkatePark3D
extends Node3D
## [b]Skate Park 3D[/b] - the Skateboard 3D pack, playable. Roll With The Slope projects gravity onto the surface normal so the bank at the end carves, Align The Board To The Surface keeps the board flat on it, and leaving the bank fires On Launched Off The Lip. The rail is an ordinary Path3D. Space pushes, Up ollies, Right spins in the air.

# Nodes this sheet calls, declared once with their type.
@onready var skateboard: Skateboard3DMovement = $Skater/Skateboard

## Everything banked so far this run.
@export var score: int = 0


func _ready() -> void:
	skateboard.landed_clean.connect(_on_landed_clean)
	skateboard.launched_off_the_lip.connect(_on_launched)
	skateboard.bailed.connect(_on_bailed)


func _physics_process(_delta: float) -> void:
	if $Skater.is_on_floor():
		skateboard.roll_with_slope()
	skateboard.align_board_to_surface()
	if Input.is_action_just_pressed(&"ui_accept"):
		skateboard.push(2.0)
	if Input.is_action_just_pressed(&"ui_up"):
		skateboard.ollie(6.0)
	if skateboard.is_airborne() and Input.is_action_pressed(&"ui_right"):
		skateboard.spin_trick(1.0)
	if not skateboard.is_grinding() and skateboard.is_near_rail($Rail, 0.8):
		skateboard.start_grinding($Rail)
	if skateboard.is_grinding():
		skateboard.grind_along_rail(10.0, false)
	if skateboard.has_reached_the_end():
		skateboard.add_to_chain("grind", 250.0)
		skateboard.hop_off(4.5)
	$Overlay/Hud.text = "Score %d   chain %d x%d   Space push / Up ollie / Right spin" % [score, int(skateboard.chain_score()), skateboard.multiplier()]


# @ace_hidden
func _on_landed_clean() -> void:
	if skateboard.spin_turns() >= 0.5:
		skateboard.add_to_chain("spin", 150.0)
	skateboard.bank_chain()
	score = int(skateboard.banked_score())


# @ace_hidden
func _on_launched() -> void:
	skateboard.add_to_chain("air", 100.0)


# @ace_hidden
func _on_bailed() -> void:
	$Skater.global_position = Vector3(-9.0, 1.0, 0.0)
	$Skater.velocity = Vector3.ZERO
