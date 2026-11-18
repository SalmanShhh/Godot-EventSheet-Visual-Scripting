extends Area2D

var score: int = 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemies"):
		return
	body.queue_free()
	score += 1
