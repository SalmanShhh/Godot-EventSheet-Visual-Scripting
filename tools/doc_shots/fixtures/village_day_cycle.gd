extends Node2D

@export var chest: Node2D

signal gem_collected
signal on_quest_completed
signal reached_flag
signal died
signal on_phase_changed

var __onceever_u1: int = -1


func __once_ever_u1(key: String) -> bool:
	if __onceever_u1 == -1:
		var __cfg: ConfigFile = ConfigFile.new()
		__cfg.load("user://remembered.cfg")
		__onceever_u1 = 1 if bool(__cfg.get_value("OnceEver", key, false)) else 0
	if __onceever_u1 == 1:
		return false
	__onceever_u1 = 1
	var __save: ConfigFile = ConfigFile.new()
	__save.load("user://remembered.cfg")
	__save.set_value("OnceEver", key, true)
	__save.save("user://remembered.cfg")
	return true


func _ready() -> void:
	gem_collected.connect(_on_gem_collected)
	on_quest_completed.connect(_on_on_quest_completed)
	reached_flag.connect(_on_reached_flag)
	died.connect(_on_died)
	on_phase_changed.connect(_on_on_phase_changed)
	$Quests.start_quest(load("res://quests/herbalist.tres"))
	$Phases.cycle_phases("day,night", 60.0)


func _on_gem_collected() -> void:
	$Quests.advance_objective("herbalist", "gems", 1)


func _on_on_quest_completed() -> void:
	open_door()


func _on_reached_flag() -> void:
	if __once_ever_u1("first_flag_hint"):
		$CheckpointBehavior.set_checkpoint_here()


func _on_died() -> void:
	$CheckpointBehavior.respawn()


func _process(_delta: float) -> void:
	if ([global_position.distance_to(chest.global_position), absf(global_position.x - chest.global_position.x), absf(global_position.y - chest.global_position.y), absf(global_position.x - chest.global_position.x) + absf(global_position.y - chest.global_position.y), maxf(absf(global_position.x - chest.global_position.x), absf(global_position.y - chest.global_position.y))][3]) <= maxf(48.0, 0.0):
		$InteractionBehavior.focus_nearest("interactable", 48.0)


func _on_on_phase_changed() -> void:
	spawn_wolves()


func open_door() -> void:
	print("door open")


func spawn_wolves() -> void:
	print("wolves")
