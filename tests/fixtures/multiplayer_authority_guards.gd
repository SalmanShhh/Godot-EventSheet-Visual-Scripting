# Who is allowed to run what, in the four shapes people write it: the early return and the
# whole-body wrap, each for "do I own this object" and for "am I the host". The three spellings of
# set_multiplayer_authority sit beside them, because that line is what decides the answer.
extends CharacterBody2D

var speed: float = 200.0


func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	position.x += speed * delta


func _process(_delta: float) -> void:
	if is_multiplayer_authority():
		modulate = Color.WHITE


func decide_damage() -> void:
	if not multiplayer.is_server():
		return
	hp_changed()


func award_points() -> void:
	if multiplayer.is_server():
		hp_changed()


func adopt_name() -> void:
	set_multiplayer_authority(name.to_int())


func hand_over(id: int) -> void:
	set_multiplayer_authority(id, true)


func hp_changed() -> void:
	speed = 200.0
