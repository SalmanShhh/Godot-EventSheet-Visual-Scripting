class_name QuestFsm
extends Node2D

enum QuestState { OFFERED, ACTIVE, COMPLETE }

signal item_collected(id: String)
signal quest_advanced(phase: int)

## 0=OFFERED, 1=ACTIVE, 2=COMPLETE.
@export var quest_state: int = 0
@export var inventory: Dictionary = {}
@export var quest_log: Array = []
@export var tick: int = 0
var __every_quest: float = 0.0


func _ready() -> void:
	item_collected.connect(_on_item_collected)
	quest_advanced.connect(_on_quest_advanced)


func _process(delta: float) -> void:
	__every_quest += delta
	if __every_quest >= maxf(1.0, 0.001):
		__every_quest = fmod(__every_quest, maxf(1.0, 0.001))
		tick += 1
		match quest_state:
			QuestState.OFFERED:
				quest_state = QuestState.ACTIVE
				quest_advanced.emit(quest_state)
			QuestState.ACTIVE:
				grant_item("gold", 3)
				if quest_log.size() >= 3:
					quest_state = QuestState.COMPLETE
					quest_advanced.emit(quest_state)
			_:
				pass
	$Screen.text = "QUEST: %s
	items: %d   log: %d
	t = %d" % [["OFFERED", "ACTIVE", "COMPLETE"][quest_state], inventory.size(), quest_log.size(), tick]


func _on_item_collected(id: String) -> void:
	$Icon/SpringBehavior.spring_host_scale(1.0)
	$Icon/SpringBehavior.add_impulse("__scale", 6.0)


func _on_quest_advanced(phase: int) -> void:
	$Icon/TweenBehavior.tween_rotation($Icon.rotation_degrees + 120.0, 0.4)
	$Icon/SpringBehavior.spring_host_scale(1.6)


## @ace_hidden
func grant_item(id: String, qty: int) -> void:
	inventory[id] = inventory.get(id, 0) + qty
	quest_log.append(id)
	item_collected.emit(id)

# [b]Quest & Inventory FSM[/b] — a self-driving quest engine (no input): an enum+match state machine walks OFFERED -> ACTIVE -> COMPLETE, a reused grant_item() function fills a Dictionary inventory + Array quest log and emits signals, and signal: triggers spring/tween the icon on every beat. Proves the sheet compiles real software logic — collections, signals, functions, match — not just movement.
