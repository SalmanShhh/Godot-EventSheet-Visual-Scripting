extends CharacterBody2D

var health: int = 100


func _ready() -> void:
	health = 100


func _process(delta: float) -> void:
	$Label.text = str(health)


func _physics_process(delta: float) -> void:
	move_and_slide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		$Sound.play()


func _exit_tree() -> void:
	print("bye")
