## A clickable, tweened, snap-to-grid object whose input, animation and Inspector button are the
## subject: the four readings batch seven added, each on the shape a real script writes it in.
@tool
class_name Snapper
extends Area2D

@export_tool_button("Bake", "Bake") var bake = _bake


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
