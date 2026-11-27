class_name SkatePark
extends Node2D
## [b]Skate Park[/b] - the Skateboard pack, playable. The slope hands you speed (Roll With The Slope projects gravity along the floor), the rail across the middle is an ordinary Path2D you snap to, and the quarterpipe at the end gives back what the drop gave you. Left/Right steer the balance, Space pushes, Up ollies, and holding Right in the air spins. Nothing here does skating math - every row is a Skateboard row.

@onready var skateboard: SkateboardMovement = $Skater/Skateboard
@onready var hud_kit: HudKitBehavior = $Hud/HudKit
@onready var checkpoint: CheckpointBehavior = $Skater/Checkpoint

## Everything banked so far this run.
@export var score: int = 0


func _ready() -> void:
	skateboard.landed_clean.connect(_on_landed_clean)
	skateboard.bailed.connect(_on_bailed)


func _physics_process(_delta: float) -> void:
	if $Skater.is_on_floor():
		skateboard.roll_with_slope()
	if Input.is_action_just_pressed(&"ui_accept"):
		skateboard.push(40.0)
	if Input.is_action_just_pressed(&"ui_up"):
		skateboard.ollie(420.0)
	if skateboard.is_airborne() and Input.is_action_pressed(&"ui_right"):
		skateboard.spin_trick(1.0)
	if not skateboard.is_grinding() and skateboard.is_near_rail($Rail, 16.0):
		skateboard.start_grinding($Rail)
	if skateboard.is_grinding():
		skateboard.grind_along_rail(320.0, false)
		skateboard.steer_balance(Input.get_axis("ui_left", "ui_right"))
	if skateboard.has_reached_the_end():
		skateboard.add_to_chain("grind", 250.0)
		skateboard.hop_off(260.0)
	$Hud.text = "Score %d   chain %d x%d   Space push / Up ollie / Right spin" % [score, int(skateboard.chain_score()), skateboard.multiplier()]
	hud_kit.set_needle("BalanceMeter", skateboard.balance(), 0.6)


# @ace_hidden
func _on_landed_clean() -> void:
	if skateboard.spin_turns() >= 0.5:
		skateboard.add_to_chain("spin", 150.0)
	skateboard.bank_chain()
	score = int(skateboard.banked_score())


# @ace_hidden
func _on_bailed() -> void:
	checkpoint.respawn()
	$Skater.velocity = Vector2.ZERO
	$Skater.rotation = 0.0
