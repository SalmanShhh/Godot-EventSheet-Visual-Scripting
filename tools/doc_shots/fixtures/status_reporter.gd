extends Area2D


func _ready() -> void:
	$Timer.timeout.connect(_on_timeout)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	print("game started")


func _process(_delta: float) -> void:
	push_warning("low health")


func _on_timeout() -> void:
	print("wave spawns")


func _on_body_entered(_body: Node) -> void:
	push_warning("hit taken")


func _on_area_entered(_area: Area2D) -> void:
	print("pickup")
