extends "res://tests/fixtures/opened_script_structure_base.gd"

var hp: int = 10
var seconds_left: int = 3


#region Movement
func _ready() -> void:
	super._ready()
	$SpawnTimer.wait_time = 2.0
	$SpawnTimer.timeout.connect(_spawn)
	$SpawnTimer.start()
	$OnceTimer.wait_time = 5.0
	$OnceTimer.one_shot = true
	$OnceTimer.timeout.connect(_expire)


func _physics_process(delta: float) -> void:
	# velocity.x = 0.0
	# TODO: add coyote time
	hp += 1
	# if hp <= 0: hp = 10
#endregion


#region Combat
func take_damage(amount: int) -> void:
	super.take_damage(amount)
	hp -= amount


#region Death
func die() -> void:
	hp = 0
#endregion
#endregion


func _spawn() -> void:
	hp += 1


func _expire() -> void:
	hp = 0


func _blink() -> void:
	while true:
		await get_tree().create_timer(0.5).timeout
		visible = not visible
