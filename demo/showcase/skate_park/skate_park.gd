class_name SkatePark
extends Node2D

## Everything banked so far this run.
@export var score: int = 0


func _ready() -> void:
	$Skater/Skateboard.landed_clean.connect(_on_landed_clean)
	$Skater/Skateboard.bailed.connect(_on_bailed)


func _physics_process(delta: float) -> void:
	if $Skater.is_on_floor():
		$Skater/Skateboard.roll_with_slope()
	if Input.is_action_just_pressed(&"ui_accept"):
		$Skater/Skateboard.push(40.0)
	if Input.is_action_just_pressed(&"ui_up"):
		$Skater/Skateboard.ollie(420.0)
	if $Skater/Skateboard.is_airborne() and Input.is_action_pressed(&"ui_right"):
		$Skater/Skateboard.spin_trick(1.0)
	if not $Skater/Skateboard.is_grinding() and $Skater/Skateboard.is_near_rail($Rail, 16.0):
		$Skater/Skateboard.start_grinding($Rail)
	if $Skater/Skateboard.is_grinding():
		$Skater/Skateboard.grind_along_rail(320.0, false)
		$Skater/Skateboard.steer_balance(Input.get_axis("ui_left", "ui_right"))
	if $Skater/Skateboard.has_reached_the_end():
		$Skater/Skateboard.add_to_chain("grind", 250.0)
		$Skater/Skateboard.hop_off(260.0)
	$Hud.text = "Score %d   chain %d x%d   Space push / Up ollie / Right spin" % [score, int($Skater/Skateboard.chain_score()), $Skater/Skateboard.multiplier()]
	$Hud/HudKit.set_needle("BalanceMeter", $Skater/Skateboard.balance(), 0.6)


## @ace_hidden
func _on_landed_clean() -> void:
	if $Skater/Skateboard.spin_turns() >= 0.5:
		$Skater/Skateboard.add_to_chain("spin", 150.0)
	$Skater/Skateboard.bank_chain()
	score = int($Skater/Skateboard.banked_score())


## @ace_hidden
func _on_bailed() -> void:
	$Skater/Checkpoint.respawn()
	$Skater.velocity = Vector2.ZERO
	$Skater.rotation = 0.0

# [b]Skate Park[/b] - the Skateboard pack, playable. The slope hands you speed (Roll With The Slope projects gravity along the floor), the rail across the middle is an ordinary Path2D you snap to, and the quarterpipe at the end gives back what the drop gave you. Left/Right steer the balance, Space pushes, Up ollies, and holding Right in the air spins. Nothing here does skating math - every row is a Skateboard row.
