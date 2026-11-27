class_name QuestFsm
extends Node2D
## [b]Quest & Inventory FSM[/b] - a self-driving quest engine (no input): an enum+match state machine walks OFFERED -> ACTIVE -> COMPLETE, a reused grant_item() function fills a Dictionary inventory + Array quest log and emits signals, and signal: triggers spring/tween the icon on every beat. Proves the sheet compiles real software logic - collections, signals, functions, match - not just movement.

# Nodes this sheet calls, declared once with their type.
@onready var spring_behavior: SpringBehavior = $Icon/SpringBehavior
@onready var tween_behavior: TweenBehavior = $Icon/TweenBehavior

## How far the quest has come, from first offered to handed in.
enum QuestState {
	## The quest is on the table; the next beat accepts it.
	OFFERED,
	## The quest is accepted and each beat grants gold until the log holds three entries.
	ACTIVE,
	## The log is full and the quest is finished.
	COMPLETE,
}

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
	if __every_quest >= 1.0:
		__every_quest = fmod(__every_quest, 1.0)
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

func _on_item_collected(_id: String) -> void:
	spring_behavior.spring_host_scale(1.0)
	spring_behavior.add_impulse("__scale", 6.0)

func _on_quest_advanced(_phase: int) -> void:
	tween_behavior.tween_rotation($Icon.rotation_degrees + 120.0, 0.4)
	spring_behavior.spring_host_scale(1.6)

# @ace_hidden
func grant_item(id: String, qty: int) -> void:
	inventory[id] = inventory.get(id, 0) + qty
	quest_log.append(id)
	item_collected.emit(id)
