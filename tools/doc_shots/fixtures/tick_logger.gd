extends Timer


func _ready() -> void:
	print("ready")


func _process(_delta: float) -> void:
	print("tick")


func _on_timeout() -> void:
	print("timeout")
