## A clickable grid-snapping marker: it highlights under the cursor, selects on click and can be
## baked onto the grid from the Inspector.
@tool
extends Area2D

@export_tool_button("Bake", "Bake") var bake = _bake

var p: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	Input.joy_connection_changed.connect(_on_pad)
	create_tween().set_loops(3).tween_property(self, "position", p, 0.5)


func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		select()


func _on_mouse_entered() -> void:
	highlight()


func _on_pad(device: int, connected: bool) -> void:
	refresh(device, connected)


func _bake() -> void:
	for n in get_children():
		n.position = n.position.snapped(Vector2(8, 8))


func select() -> void:
	pass


func highlight() -> void:
	pass


func refresh(_device: int, _connected: bool) -> void:
	pass
